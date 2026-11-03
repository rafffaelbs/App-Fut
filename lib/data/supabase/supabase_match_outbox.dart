import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/matches_repository.dart';
import '../../domain/services/match_outbox.dart';

const _permanentPostgrestCodes = {'23503', '23502', '23514', '22P02'};

/// Retorna true SOMENTE para PostgrestException com code em {'23503','23502','23514','22P02'}.
/// Retorna false para tudo o resto: SocketException, TimeoutException, ClientException,
/// erros HTTP, 5xx, 401/JWT expirado, 42501 (permissão negada/RLS), 23505 (duplicada) e qualquer erro desconhecido.
bool isPermanentOutboxError(Object error) {
  if (error is PostgrestException) {
    final code = error.code;
    return code != null && _permanentPostgrestCodes.contains(code);
  }
  return false;
}

/// Fila ("outbox") de partidas finalizadas que ainda não subiram pro Supabase.
///
/// Por que existe: antes, "Finalizar partida" esperava 3 inserts em sequência
/// (matches -> match_lineups -> match_events) + recarregar o histórico inteiro
/// do grupo antes de mostrar o próximo time. Agora a partida é gravada
/// localmente (1 escrita rápida), a UI segue na hora, e este serviço envia em
/// segundo plano, com retry automático se a rede falhar. O envio é idempotente
/// (o id da partida é gerado no app), então tentar de novo não duplica nada.
class SupabaseMatchOutbox implements MatchOutbox {
  final MatchesRepository _matchesRepository;

  SupabaseMatchOutbox({required MatchesRepository matchesRepository})
      : _matchesRepository = matchesRepository;

  static const _prefsKey = 'pending_matches_v1';

  /// Quantidade de partidas aguardando envio (a UI mostra um selo quando > 0).
  @override
  final ValueNotifier<int> pending = ValueNotifier<int>(0);

  /// Quantidade de partidas na fila com erro permanente (status 'failed').
  @override
  final ValueNotifier<int> failed = ValueNotifier<int>(0);

  /// Último erro de envio (null quando está tudo certo).
  @override
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  bool _flushing = false;
  Timer? _retryTimer;
  int _retryDelaySeconds = 5;

  @visibleForTesting
  Timer? get retryTimer => _retryTimer;

  static List<Map<String, dynamic>> _readFromPrefs(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<Map<String, dynamic>> _read(SharedPreferences prefs) =>
      _readFromPrefs(prefs);

  void _updateCounts(List<Map<String, dynamic>> jobs) {
    pending.value = jobs.where((j) => j['status'] != 'failed').length;
    failed.value = jobs.where((j) => j['status'] == 'failed').length;
  }

  Future<void> _write(
      SharedPreferences prefs, List<Map<String, dynamic>> jobs) async {
    await prefs.setString(_prefsKey, jsonEncode(jobs));
    _updateCounts(jobs);
  }

  /// Lê a fila direto do armazenamento local (sem rede). Usado pelos
  /// repositórios pra mostrar partidas ainda não enviadas no Histórico,
  /// Ranking e Estatísticas. NÃO inclui jobs com status 'failed'.
  static Future<List<Map<String, dynamic>>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    return _readFromPrefs(prefs)
        .where((j) => j['status'] != 'failed')
        .toList();
  }

  /// Guarda a partida localmente e dispara o envio em segundo plano.
  /// [job] precisa ter: match_id, match (payload da tabela matches),
  /// lineups e events (listas de maps, sem match_id).
  @override
  Future<void> enqueue(Map<String, dynamic> job) async {
    final prefs = await SharedPreferences.getInstance();
    final jobs = _read(prefs)..add({...job, 'attempts': 0, 'permanent_failures': 0});
    await _write(prefs, jobs);
    // Espera um instante antes de subir: primeiro a súmula é guardada e os
    // próximos times aparecem; só depois a rede entra em ação.
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 2), flush);
  }

  /// Tenta enviar tudo que está pendente, na ordem. Seguro chamar várias vezes.
  @override
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _updateCounts(_read(prefs));

      while (true) {
        final jobs = _read(prefs);
        final jobIndex = jobs.indexWhere((j) => j['status'] != 'failed');
        if (jobIndex == -1) break;

        final job = jobs[jobIndex];
        final matchId = job['match_id'].toString();
        final attempts = (job['attempts'] as num?)?.toInt() ?? 0;
        final permanentFailures =
            (job['permanent_failures'] as num?)?.toInt() ?? 0;

        try {
          await _matchesRepository.savePendingMatch(
            matchId: matchId,
            match: Map<String, dynamic>.from(job['match'] as Map),
            lineups: (job['lineups'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
            events: (job['events'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
            // Se uma tentativa anterior morreu no meio, limpa o que ficou
            // pela metade antes de reinserir (evita lineup/evento duplicado).
            isRetry: attempts > 0,
          ).timeout(const Duration(seconds: 25));

          final fresh = _read(prefs)
            ..removeWhere((j) => j['match_id'].toString() == matchId);
          await _write(prefs, fresh);
          lastError.value = null;
          _retryDelaySeconds = 5;
        } catch (e) {
          debugPrint('SupabaseMatchOutbox: falha ao enviar $matchId: $e');
          final isPermanent = isPermanentOutboxError(e);

          if (isPermanent) {
            final newPermanentFailures = permanentFailures + 1;
            if (newPermanentFailures >= 2) {
              String? errorCode;
              String? errorMsg;
              if (e is PostgrestException) {
                errorCode = e.code;
                errorMsg = e.message;
              } else {
                errorMsg = e.toString();
              }
              final fresh = _read(prefs);
              for (final j in fresh) {
                if (j['match_id'].toString() == matchId) {
                  j['permanent_failures'] = newPermanentFailures;
                  j['status'] = 'failed';
                  if (errorCode != null && errorCode.isNotEmpty) {
                    j['error_code'] = errorCode;
                  }
                  j['error_message'] = errorMsg;
                  j['failed_at'] = DateTime.now().toIso8601String();
                }
              }
              await _write(prefs, fresh);
              lastError.value = e.toString();
              // NÃO dê break: continue o while com o próximo job que não esteja failed
              continue;
            } else {
              // 1ª falha permanente consecutiva: retry no backoff como hoje
              final fresh = _read(prefs);
              for (final j in fresh) {
                if (j['match_id'].toString() == matchId) {
                  j['permanent_failures'] = newPermanentFailures;
                  j['attempts'] = attempts + 1;
                }
              }
              await _write(prefs, fresh);
              lastError.value = e.toString();
              _scheduleRetry();
              break;
            }
          } else {
            // Erro NÃO permanente: zera permanent_failures, incrementa attempts, break
            final fresh = _read(prefs);
            for (final j in fresh) {
              if (j['match_id'].toString() == matchId) {
                j['permanent_failures'] = 0;
                j['attempts'] = attempts + 1;
              }
            }
            await _write(prefs, fresh);
            lastError.value = e.toString();
            _scheduleRetry();
            break;
          }
        }
      }
    } finally {
      _flushing = false;
    }
  }

  @override
  Future<void> refreshCounts() async {
    final prefs = await SharedPreferences.getInstance();
    _updateCounts(_read(prefs));
  }

  @override
  Future<List<Map<String, dynamic>>> failedJobs() async {
    final prefs = await SharedPreferences.getInstance();
    final jobs = _read(prefs);
    _updateCounts(jobs);
    return jobs.where((j) => j['status'] == 'failed').toList();
  }

  @override
  Future<void> retryFailed(String matchId) async {
    final prefs = await SharedPreferences.getInstance();
    final jobs = _read(prefs);
    bool found = false;
    for (final j in jobs) {
      if (j['match_id'].toString() == matchId && j['status'] == 'failed') {
        j.remove('status');
        j['permanent_failures'] = 0;
        final currentAttempts = (j['attempts'] as num?)?.toInt() ?? 0;
        j['attempts'] = math.max(currentAttempts, 1);
        j.remove('error_code');
        j.remove('error_message');
        j.remove('failed_at');
        j.remove('last_attempt_at');
        found = true;
      }
    }
    if (found) {
      await _write(prefs, jobs);
      if (_flushing) {
        if (_retryTimer == null || !_retryTimer!.isActive) {
          _scheduleRetry();
        }
      } else {
        await flush();
      }
    }
  }

  @override
  Future<void> discardFailed(String matchId) async {
    final prefs = await SharedPreferences.getInstance();
    final jobs = _read(prefs);
    final countBefore = jobs.length;
    jobs.removeWhere((j) =>
        j['match_id'].toString() == matchId && j['status'] == 'failed');
    if (jobs.length != countBefore) {
      await _write(prefs, jobs);
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: _retryDelaySeconds), flush);
    // Backoff até 60s pra não martelar a rede.
    _retryDelaySeconds = (_retryDelaySeconds * 2).clamp(5, 60);
  }
}
