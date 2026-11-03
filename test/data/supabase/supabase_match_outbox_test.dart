import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_do_fut/data/supabase/supabase_match_outbox.dart';
import 'package:app_do_fut/domain/repositories/matches_repository.dart';
import 'package:app_do_fut/models/match_event_model.dart';
import 'package:app_do_fut/models/match_model.dart';

class FakeMatchesRepository implements MatchesRepository {
  final List<Map<String, dynamic>> savedCalls = [];
  bool shouldThrow = false;
  String errorMessage = 'Network error';
  Object? customException;
  Object? Function(String matchId, int callIndex)? onSave;
  Future<void> Function(String matchId, int callIndex)? beforeSave;

  @override
  Future<void> savePendingMatch({
    required String matchId,
    required Map<String, dynamic> match,
    required List<Map<String, dynamic>> lineups,
    required List<Map<String, dynamic>> events,
    bool isRetry = false,
  }) async {
    if (beforeSave != null) {
      await beforeSave!(matchId, savedCalls.length);
    }
    if (onSave != null) {
      final exc = onSave!(matchId, savedCalls.length);
      if (exc != null) {
        throw exc;
      }
    }
    if (customException != null) {
      throw customException!;
    }
    if (shouldThrow) {
      throw Exception(errorMessage);
    }
    savedCalls.add({
      'matchId': matchId,
      'match': match,
      'lineups': lineups,
      'events': events,
      'isRetry': isRetry,
    });
  }

  @override
  Future<List<MatchModel>> getMatchesBySession(String sessionId) async => [];

  @override
  Future<List<MatchModel>> getMatchesByGroup(String groupId) async => [];

  @override
  Future<MatchModel> updatePartialMatch({
    required String matchId,
    required int teamAScore,
    required int teamBScore,
    required List<MatchEventModel> events,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteMatch(String matchId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMatchesRepository fakeMatchesRepo;
  late SupabaseMatchOutbox outbox;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeMatchesRepo = FakeMatchesRepository();
    outbox = SupabaseMatchOutbox(matchesRepository: fakeMatchesRepo);
  });

  tearDown(() {
    outbox.retryTimer?.cancel();
  });

  group('SupabaseMatchOutbox', () {
    final sampleJob = {
      'match_id': 'match-uuid-1',
      'match': {
        'id': 'match-uuid-1',
        'session_id': 'session-1',
        'group_id': 'group-1',
        'score_red': 2,
        'score_white': 1,
        'played_at': '2026-10-31T20:00:00.000Z',
        'duration_seconds': 600,
      },
      'lineups': [
        {'player_id': 'p1', 'team': 'red', 'is_goalkeeper': false},
        {'player_id': 'p2', 'team': 'white', 'is_goalkeeper': true},
      ],
      'events': [
        {'player_id': 'p1', 'event_type': 'goal', 'team': 'red', 'minute': '5'},
      ],
    };

    test('enqueue grava job no SharedPreferences com attempts=0 e atualiza pending', () async {
      expect(outbox.pending.value, 0);

      await outbox.enqueue(sampleJob);

      expect(outbox.pending.value, 1);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('pending_matches_v1');
      expect(raw, isNotNull);

      final decoded = (jsonDecode(raw!) as List).cast<Map<String, dynamic>>();
      expect(decoded.length, 1);
      expect(decoded.first['match_id'], 'match-uuid-1');
      expect(decoded.first['attempts'], 0);
    });

    test('readAll lê todas as partidas pendentes salvas localmente sem rede', () async {
      final initialJobs = [
        {...sampleJob, 'attempts': 0},
        {...sampleJob, 'match_id': 'match-uuid-2', 'attempts': 1},
      ];
      SharedPreferences.setMockInitialValues({
        'pending_matches_v1': jsonEncode(initialJobs),
      });

      final pending = await SupabaseMatchOutbox.readAll();
      expect(pending.length, 2);
      expect(pending[0]['match_id'], 'match-uuid-1');
      expect(pending[1]['match_id'], 'match-uuid-2');
    });

    test('flush envia com sucesso, repassa parâmetros corretos e limpa a fila', () async {
      await outbox.enqueue(sampleJob);
      expect(outbox.pending.value, 1);

      await outbox.flush();

      expect(fakeMatchesRepo.savedCalls.length, 1);
      final call = fakeMatchesRepo.savedCalls.first;
      expect(call['matchId'], 'match-uuid-1');
      expect(call['isRetry'], false);
      expect(call['match']['score_red'], 2);
      expect(call['lineups'].length, 2);
      expect(call['events'].length, 1);

      expect(outbox.pending.value, 0);
      expect(outbox.lastError.value, isNull);

      final pendingAfter = await SupabaseMatchOutbox.readAll();
      expect(pendingAfter, isEmpty);
    });

    test('flush em caso de erro incrementa attempts, atualiza lastError e mantém na fila', () async {
      fakeMatchesRepo.shouldThrow = true;
      fakeMatchesRepo.errorMessage = 'Timeout 25s simulado';

      await outbox.enqueue(sampleJob);

      await outbox.flush();

      expect(outbox.pending.value, 1);
      expect(outbox.lastError.value, contains('Timeout 25s simulado'));

      final pendingAfter = await SupabaseMatchOutbox.readAll();
      expect(pendingAfter.length, 1);
      expect(pendingAfter.first['attempts'], 1);
    });

    test('retry subsequente repassa isRetry=true quando attempts > 0', () async {
      final retryJob = {
        ...sampleJob,
        'attempts': 1,
      };
      SharedPreferences.setMockInitialValues({
        'pending_matches_v1': jsonEncode([retryJob]),
      });

      await outbox.flush();

      expect(fakeMatchesRepo.savedCalls.length, 1);
      final call = fakeMatchesRepo.savedCalls.first;
      expect(call['isRetry'], true);
      expect(outbox.pending.value, 0);
      expect(outbox.lastError.value, isNull);
    });

    group('Cenários do Passo 4 (B5)', () {
      test('1. isPermanentOutboxError: true para 23503/23502/23514/22P02; false para 42501, 23505, SocketException, TimeoutException e Exception generico', () {
        expect(
          isPermanentOutboxError(const PostgrestException(message: 'FK', code: '23503')),
          isTrue,
        );
        expect(
          isPermanentOutboxError(const PostgrestException(message: 'Not null', code: '23502')),
          isTrue,
        );
        expect(
          isPermanentOutboxError(const PostgrestException(message: 'Check', code: '23514')),
          isTrue,
        );
        expect(
          isPermanentOutboxError(const PostgrestException(message: 'Syntax', code: '22P02')),
          isTrue,
        );

        expect(
          isPermanentOutboxError(const PostgrestException(message: 'RLS', code: '42501')),
          isFalse,
        );
        expect(
          isPermanentOutboxError(const PostgrestException(message: 'Duplicate', code: '23505')),
          isFalse,
        );
        expect(
          isPermanentOutboxError(const SocketException('Sem conexao')),
          isFalse,
        );
        expect(
          isPermanentOutboxError(TimeoutException('Tempo esgotado')),
          isFalse,
        );
        expect(
          isPermanentOutboxError(Exception('Erro generico')),
          isFalse,
        );
      });

      test('2. Erro de rede/timeout/42501 NUNCA isola a partida, por mais tentativas que tenha', () async {
        final errors = [
          const SocketException('Sem internet'),
          TimeoutException('Timeout 25s'),
          const PostgrestException(message: 'Permission denied', code: '42501'),
          const SocketException('Sem internet 2'),
          TimeoutException('Timeout 25s 2'),
        ];

        await outbox.enqueue(sampleJob);

        for (int i = 0; i < errors.length; i++) {
          fakeMatchesRepo.customException = errors[i];
          await outbox.flush();

          expect(outbox.pending.value, 1);
          expect(outbox.failed.value, 0);

          final prefs = await SharedPreferences.getInstance();
          final raw = prefs.getString('pending_matches_v1')!;
          final jobs = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
          expect(jobs.length, 1);
          expect(jobs.first['status'], isNull);
          expect(jobs.first['attempts'], i + 1);
          expect(jobs.first['permanent_failures'], 0);
        }
      });

      test('3. Erro 23503 incrementa permanent_failures mas partida nao vira failed; 2o erro 23503 marca failed e flush segue para proxima', () async {
        final job2 = {
          ...sampleJob,
          'match_id': 'match-uuid-2',
        };

        await outbox.enqueue(sampleJob);
        await outbox.enqueue(job2);

        expect(outbox.pending.value, 2);
        expect(outbox.failed.value, 0);

        // 1ª tentativa: erro 23503 no primeiro job
        fakeMatchesRepo.customException = const PostgrestException(
          message: 'violates foreign key constraint',
          code: '23503',
        );
        await outbox.flush();

        // Ainda não virou failed (permanent_failures == 1)
        expect(outbox.pending.value, 2);
        expect(outbox.failed.value, 0);
        final jobs1 = await SupabaseMatchOutbox.readAll();
        expect(jobs1.length, 2);
        expect(fakeMatchesRepo.savedCalls.length, 0);

        // 2ª tentativa: erro 23503 no job 1 e sucesso no job 2
        fakeMatchesRepo.customException = null;
        fakeMatchesRepo.onSave = (matchId, callIndex) {
          if (matchId == 'match-uuid-1') {
            return const PostgrestException(
              message: 'violates foreign key constraint',
              code: '23503',
            );
          }
          return null; // sucesso para job 2
        };

        await outbox.flush();

        // Job 1 virou failed e Job 2 foi enviado com sucesso na mesma execução
        expect(outbox.pending.value, 0);
        expect(outbox.failed.value, 1);

        expect(fakeMatchesRepo.savedCalls.length, 1);
        expect(fakeMatchesRepo.savedCalls.first['matchId'], 'match-uuid-2');

        final failedList = await outbox.failedJobs();
        expect(failedList.length, 1);
        final failedJob = failedList.first;
        expect(failedJob['match_id'], 'match-uuid-1');
        expect(failedJob['status'], 'failed');
        expect(failedJob['error_code'], '23503');
        expect(failedJob['error_message'], contains('foreign key'));
        expect(failedJob['failed_at'], isNotNull);
        expect(failedJob['permanent_failures'], 2);
      });

      test('4. Um sucesso (ou erro de rede) entre dois 23503 zera permanent_failures', () async {
        await outbox.enqueue(sampleJob);

        // 1º erro 23503: permanent_failures = 1
        fakeMatchesRepo.customException = const PostgrestException(
          message: 'FK 1',
          code: '23503',
        );
        await outbox.flush();

        var prefs = await SharedPreferences.getInstance();
        var jobs = (jsonDecode(prefs.getString('pending_matches_v1')!) as List)
            .cast<Map<String, dynamic>>();
        expect(jobs.first['permanent_failures'], 1);
        expect(jobs.first['status'], isNull);

        // Erro de rede intermediário: zera permanent_failures
        fakeMatchesRepo.customException = const SocketException('Sem internet');
        await outbox.flush();

        prefs = await SharedPreferences.getInstance();
        jobs = (jsonDecode(prefs.getString('pending_matches_v1')!) as List)
            .cast<Map<String, dynamic>>();
        expect(jobs.first['permanent_failures'], 0);
        expect(jobs.first['status'], isNull);

        // Próximo erro 23503: vai para 1 novamente, e NÃO para 2
        fakeMatchesRepo.customException = const PostgrestException(
          message: 'FK 2',
          code: '23503',
        );
        await outbox.flush();

        prefs = await SharedPreferences.getInstance();
        jobs = (jsonDecode(prefs.getString('pending_matches_v1')!) as List)
            .cast<Map<String, dynamic>>();
        expect(jobs.first['permanent_failures'], 1);
        expect(jobs.first['status'], isNull);
        expect(outbox.failed.value, 0);
      });

      test('5. readAll não devolve jobs failed, mas devolve os pendentes normais', () async {
        final jobs = [
          {...sampleJob, 'match_id': 'job-pending-1'},
          {
            ...sampleJob,
            'match_id': 'job-failed-1',
            'status': 'failed',
            'error_code': '23503',
          },
          {...sampleJob, 'match_id': 'job-pending-2'},
        ];
        SharedPreferences.setMockInitialValues({
          'pending_matches_v1': jsonEncode(jobs),
        });

        final read = await SupabaseMatchOutbox.readAll();
        expect(read.length, 2);
        expect(
          read.map((j) => j['match_id']),
          containsAll(['job-pending-1', 'job-pending-2']),
        );
        expect(read.map((j) => j['match_id']), isNot(contains('job-failed-1')));
      });

      test('6. pending e failed refletem as contagens corretas', () async {
        final jobs = [
          {...sampleJob, 'match_id': 'p1'},
          {...sampleJob, 'match_id': 'p2'},
          {...sampleJob, 'match_id': 'f1', 'status': 'failed'},
          {...sampleJob, 'match_id': 'f2', 'status': 'failed'},
          {...sampleJob, 'match_id': 'f3', 'status': 'failed'},
        ];
        SharedPreferences.setMockInitialValues({
          'pending_matches_v1': jsonEncode(jobs),
        });

        // Leitura de failedJobs sincroniza as contagens
        final failedList = await outbox.failedJobs();
        expect(failedList.length, 3);
        expect(outbox.pending.value, 2);
        expect(outbox.failed.value, 3);

        // Com erro de rede no flush, pendentes não sobem e as contagens continuam íntegras
        fakeMatchesRepo.customException = const SocketException('offline');
        await outbox.flush();
        expect(outbox.pending.value, 2);
        expect(outbox.failed.value, 3);
      });

      test('7. discardFailed remove só o job failed pedido e não mexe em pendentes normais nem em outros failed; discardFailed de não-failed não remove nada', () async {
        final jobs = [
          {...sampleJob, 'match_id': 'p1'},
          {...sampleJob, 'match_id': 'f1', 'status': 'failed'},
          {...sampleJob, 'match_id': 'f2', 'status': 'failed'},
        ];
        SharedPreferences.setMockInitialValues({
          'pending_matches_v1': jsonEncode(jobs),
        });

        // Tenta descartar um job que NÃO é failed (p1)
        await outbox.discardFailed('p1');
        var list = await outbox.failedJobs();
        expect(list.length, 2);
        var all = await SupabaseMatchOutbox.readAll();
        expect(all.length, 1);

        // Tenta descartar id inexistente
        await outbox.discardFailed('inexistente');
        list = await outbox.failedJobs();
        expect(list.length, 2);

        // Descarta f1
        await outbox.discardFailed('f1');
        list = await outbox.failedJobs();
        expect(list.length, 1);
        expect(list.first['match_id'], 'f2');

        // p1 continua lá intacto
        all = await SupabaseMatchOutbox.readAll();
        expect(all.length, 1);
        expect(all.first['match_id'], 'p1');
      });

      test('8. retryFailed devolve o job à fila normal e dispara flush', () async {
        final jobs = [
          {
            ...sampleJob,
            'match_id': 'f1',
            'status': 'failed',
            'permanent_failures': 2,
            'attempts': 2,
            'error_code': '23503',
            'error_message': 'FK error',
            'failed_at': '2026-11-02T20:00:00.000Z',
          },
        ];
        SharedPreferences.setMockInitialValues({
          'pending_matches_v1': jsonEncode(jobs),
        });

        await outbox.retryFailed('f1');

        expect(fakeMatchesRepo.savedCalls.length, 1);
        expect(fakeMatchesRepo.savedCalls.first['matchId'], 'f1');
        expect(outbox.pending.value, 0);
        expect(outbox.failed.value, 0);

        final failedList = await outbox.failedJobs();
        expect(failedList, isEmpty);
        final pendingList = await SupabaseMatchOutbox.readAll();
        expect(pendingList, isEmpty);
      });

      test('9. Job antigo (sem os campos novos) continua sendo enviado e removido em caso de sucesso, sem duplicar', () async {
        final legacyJob = {
          'match_id': 'legacy-uuid-1',
          'match': {
            'id': 'legacy-uuid-1',
            'session_id': 'session-leg',
            'group_id': 'group-leg',
            'score_red': 1,
            'score_white': 0,
            'played_at': '2026-10-30T19:00:00.000Z',
            'duration_seconds': 500,
          },
          'lineups': [
            {'player_id': 'p1', 'team': 'red', 'is_goalkeeper': false},
          ],
          'events': [],
        };
        SharedPreferences.setMockInitialValues({
          'pending_matches_v1': jsonEncode([legacyJob]),
        });

        await outbox.flush();

        expect(fakeMatchesRepo.savedCalls.length, 1);
        expect(fakeMatchesRepo.savedCalls.first['matchId'], 'legacy-uuid-1');
        expect(outbox.pending.value, 0);
        expect(outbox.failed.value, 0);

        // Nova chamada a flush não reenvia (não duplica)
        await outbox.flush();
        expect(fakeMatchesRepo.savedCalls.length, 1);
      });

      test('10. (a) Job com falha e attempts=0 chama retryFailed e depois flush: repository recebe isRetry == true', () async {
        final failedJob = {
          ...sampleJob,
          'match_id': 'f-attempts-zero',
          'status': 'failed',
          'permanent_failures': 2,
          'attempts': 0,
          'error_code': '23503',
          'error_message': 'FK error',
          'failed_at': '2026-11-02T20:00:00.000Z',
        };
        SharedPreferences.setMockInitialValues({
          'pending_matches_v1': jsonEncode([failedJob]),
        });

        await outbox.retryFailed('f-attempts-zero');

        expect(fakeMatchesRepo.savedCalls.length, 1);
        final call = fakeMatchesRepo.savedCalls.first;
        expect(call['matchId'], 'f-attempts-zero');
        expect(call['isRetry'], isTrue,
            reason: 'retryFailed deve garantir attempts >= 1 para que isRetry seja true e limpe dados parciais no Supabase');
      });

      test('11. (b) retryFailed enquanto flush já está rodando deixa o job pendente e agenda retry sem duplicar timers', () async {
        final jobNormal = {
          ...sampleJob,
          'match_id': 'in-flight-1',
          'attempts': 0,
          'permanent_failures': 0,
        };
        final jobFailed = {
          ...sampleJob,
          'match_id': 'failed-1',
          'status': 'failed',
          'permanent_failures': 2,
          'attempts': 1,
          'error_code': '23503',
        };
        SharedPreferences.setMockInitialValues({
          'pending_matches_v1': jsonEncode([jobNormal, jobFailed]),
        });

        final job1Started = Completer<void>();
        final job1Continue = Completer<void>();

        fakeMatchesRepo.beforeSave = (matchId, callIndex) async {
          if (matchId == 'in-flight-1') {
            if (!job1Started.isCompleted) {
              job1Started.complete();
            }
            await job1Continue.future;
          }
        };

        // Dispara flush para iniciar o envio do jobNormal
        final flushFuture = outbox.flush();

        // Espera jobNormal entrar no savePendingMatch
        await job1Started.future;

        // Com o flush em andamento (_flushing == true), chama retryFailed
        await outbox.retryFailed('failed-1');

        // Job deve voltar a ser pendente
        expect(outbox.pending.value, 2,
            reason: 'Ambos os jobs devem constar como pendentes');
        expect(outbox.failed.value, 0,
            reason: 'Nenhum job deve permanecer com status failed');

        // Retry deve estar agendado
        expect(outbox.retryTimer, isNotNull);
        expect(outbox.retryTimer!.isActive, isTrue,
            reason: 'Deve agendar nova tentativa sem esquecer o job');

        final timerInstance = outbox.retryTimer;

        // Chamada subsequente a retryFailed com flush ainda rodando não duplica timer
        await outbox.retryFailed('failed-1');
        expect(outbox.retryTimer, same(timerInstance),
            reason: 'Não deve duplicar ou recriar timer se já houver um ativo');

        // Libera o primeiro job para concluir
        job1Continue.complete();
        await flushFuture;

        // Verifica que o segundo job também foi processado no mesmo flush ou com isRetry == true
        expect(fakeMatchesRepo.savedCalls.length, 2);
        expect(fakeMatchesRepo.savedCalls.last['matchId'], 'failed-1');
        expect(fakeMatchesRepo.savedCalls.last['isRetry'], isTrue);
      });

      test('12. (c) Job que nunca falhou é enviado com isRetry == false na primeira tentativa', () async {
        final freshJob = {
          ...sampleJob,
          'match_id': 'fresh-match-1',
          'attempts': 0,
          'permanent_failures': 0,
        };
        SharedPreferences.setMockInitialValues({
          'pending_matches_v1': jsonEncode([freshJob]),
        });

        await outbox.flush();

        expect(fakeMatchesRepo.savedCalls.length, 1);
        final call = fakeMatchesRepo.savedCalls.first;
        expect(call['matchId'], 'fresh-match-1');
        expect(call['isRetry'], isFalse,
            reason: 'Primeira tentativa de envio de um job novo deve ter isRetry == false');
      });

      test('13. (b) refreshCounts reflete a fila gravada (pendentes normais e failed) sem chamar o repositório', () async {
        final jobNormal1 = {...sampleJob, 'match_id': 'normal-1'};
        final jobNormal2 = {...sampleJob, 'match_id': 'normal-2'};
        final jobFailed = {...sampleJob, 'match_id': 'failed-1', 'status': 'failed'};
        SharedPreferences.setMockInitialValues({
          'pending_matches_v1': jsonEncode([jobNormal1, jobNormal2, jobFailed]),
        });

        expect(outbox.pending.value, 0);
        expect(outbox.failed.value, 0);

        await outbox.refreshCounts();

        expect(outbox.pending.value, 2,
            reason: 'Deve identificar 2 jobs normais pendentes');
        expect(outbox.failed.value, 1,
            reason: 'Deve identificar 1 job com status failed');
        expect(fakeMatchesRepo.savedCalls, isEmpty,
            reason: 'refreshCounts não deve realizar nenhuma chamada ao repositório');
      });

      test('14. (d) a mesma partida não é enviada duas vezes se dois gatilhos chegam juntos', () async {
        final job = {
          ...sampleJob,
          'match_id': 'concurrent-match-1',
        };
        SharedPreferences.setMockInitialValues({
          'pending_matches_v1': jsonEncode([job]),
        });

        final saveStarted = Completer<void>();
        final allowSaveFinish = Completer<void>();

        fakeMatchesRepo.beforeSave = (matchId, callIndex) async {
          if (!saveStarted.isCompleted) {
            saveStarted.complete();
          }
          await allowSaveFinish.future;
        };

        // Primeiro gatilho dispara flush
        final flush1 = outbox.flush();

        // Aguarda início do envio no repositório (_flushing torna-se true)
        await saveStarted.future;

        // Segundo gatilho chega enquanto o primeiro ainda está processando
        final flush2 = outbox.flush();

        // Libera o salvamento do primeiro
        allowSaveFinish.complete();

        await Future.wait([flush1, flush2]);

        expect(fakeMatchesRepo.savedCalls.length, 1,
            reason: 'A partida deve ser enviada exatamente uma vez mesmo com dois gatilhos simultâneos');
      });
    });
  });
}

