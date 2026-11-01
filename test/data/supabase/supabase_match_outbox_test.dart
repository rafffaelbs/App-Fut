import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_do_fut/data/supabase/supabase_match_outbox.dart';
import 'package:app_do_fut/domain/repositories/matches_repository.dart';
import 'package:app_do_fut/models/match_event_model.dart';
import 'package:app_do_fut/models/match_model.dart';

class FakeMatchesRepository implements MatchesRepository {
  final List<Map<String, dynamic>> savedCalls = [];
  bool shouldThrow = false;
  String errorMessage = 'Network error';

  @override
  Future<void> savePendingMatch({
    required String matchId,
    required Map<String, dynamic> match,
    required List<Map<String, dynamic>> lineups,
    required List<Map<String, dynamic>> events,
    bool isRetry = false,
  }) async {
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
  });
}
