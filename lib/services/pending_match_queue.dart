import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/supabase_service.dart';

/// Fila ("outbox") de partidas finalizadas que ainda não subiram pro Supabase.
///
/// Por que existe: antes, "Finalizar partida" esperava 3 inserts em sequência
/// (matches -> match_lineups -> match_events) + recarregar o histórico inteiro
/// do grupo antes de mostrar o próximo time. Agora a partida é gravada
/// localmente (1 escrita rápida), a UI segue na hora, e este serviço envia em
/// segundo plano, com retry automático se a rede falhar. O envio é idempotente
/// (o id da partida é gerado no app), então tentar de novo não duplica nada.
class PendingMatchQueue {
  PendingMatchQueue._();
  static final PendingMatchQueue instance = PendingMatchQueue._();

  static const _prefsKey = 'pending_matches_v1';

  /// Quantidade de partidas aguardando envio (a UI mostra um selo quando > 0).
  final ValueNotifier<int> pending = ValueNotifier<int>(0);

  /// Último erro de envio (null quando está tudo certo).
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  bool _flushing = false;
  Timer? _retryTimer;
  int _retryDelaySeconds = 5;

  List<Map<String, dynamic>> _read(SharedPreferences prefs) {
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

  Future<void> _write(
      SharedPreferences prefs, List<Map<String, dynamic>> jobs) async {
    await prefs.setString(_prefsKey, jsonEncode(jobs));
    pending.value = jobs.length;
  }

  /// Lê a fila direto do armazenamento local (sem rede). Usado pelos
  /// repositórios pra mostrar partidas ainda não enviadas no Histórico,
  /// Ranking e Estatísticas.
  static Future<List<Map<String, dynamic>>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    return instance._read(prefs);
  }

  /// Guarda a partida localmente e dispara o envio em segundo plano.
  /// [job] precisa ter: match_id, match (payload da tabela matches),
  /// lineups e events (listas de maps, sem match_id).
  Future<void> enqueue(Map<String, dynamic> job) async {
    final prefs = await SharedPreferences.getInstance();
    final jobs = _read(prefs)..add({...job, 'attempts': 0});
    await _write(prefs, jobs);
    // Espera um instante antes de subir: primeiro a súmula é guardada e os
    // próximos times aparecem; só depois a rede entra em ação.
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 2), flush);
  }

  /// Tenta enviar tudo que está pendente, na ordem. Seguro chamar várias vezes.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      pending.value = _read(prefs).length;

      while (true) {
        final jobs = _read(prefs);
        if (jobs.isEmpty) break;
        final job = jobs.first;
        final matchId = job['match_id'].toString();
        final attempts = (job['attempts'] as num?)?.toInt() ?? 0;

        try {
          await SupabaseService.instance.matches.savePendingMatch(
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
          debugPrint('PendingMatchQueue: falha ao enviar $matchId: $e');
          final fresh = _read(prefs);
          for (final j in fresh) {
            if (j['match_id'].toString() == matchId) {
              j['attempts'] = attempts + 1;
            }
          }
          await _write(prefs, fresh);
          lastError.value = e.toString();
          _scheduleRetry();
          break;
        }
      }
    } finally {
      _flushing = false;
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: _retryDelaySeconds), flush);
    // Backoff até 60s pra não martelar a rede.
    _retryDelaySeconds = (_retryDelaySeconds * 2).clamp(5, 60);
  }
}
