import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/supabase_service.dart';
import '../models/player_model.dart';
import '../utils/stats_calculator.dart';
import '../utils/rating_calculator.dart';
import '../utils/overall_calculator.dart';

enum BootstrapStatus { idle, loading, ready, offline }

/// Carga inicial do grupo ("puxar o essencial da nuvem ao entrar no app").
///
/// Baixa em paralelo elenco, peladas e histórico, calcula as notas UMA vez e
/// grava tudo localmente. Durante a pelada a tela da partida só lê esse
/// snapshot (zero rede pra abrir, sortear ou finalizar). A próxima
/// atualização de notas só acontece na próxima entrada no grupo.
class GroupBootstrap {
  GroupBootstrap._();
  static final GroupBootstrap instance = GroupBootstrap._();

  final ValueNotifier<BootstrapStatus> status =
      ValueNotifier<BootstrapStatus>(BootstrapStatus.idle);

  final Map<String, DateTime> _lastRun = {};
  Future<bool>? _running;

  /// Mapa de jogador usado pela tela da partida (snapshot local).
  ///
  /// `rating` continua sendo a nota do app (0-10, usada nas estatísticas);
  /// `overall` (0-99) é a força que a partida usa em TUDO: tile, média do
  /// time, sorteio, draft e entrada/saída de times. Os `community_*` vão
  /// junto para o overall poder ser recalculado se preciso.
  static Map<String, dynamic> playerSnapshotMap(PlayerModel p, double nota) {
    final overall = calculateOverall(appRating10: nota, community: p.community);
    return {
      'id': p.id,
      'name': p.displayName,
      'icon': p.icon,
      'rating': nota,
      'overall': overall,
      'goal_sound_url': p.goalSoundUrl,
      'name_effect': p.nameEffectFull ?? p.nameEffect,
      'monthly_highlight': p.monthlyHighlight,
      'manual_badges': p.manualBadges.map((b) => b.toMap()).toList(),
      'advanced_stats': p.advancedStats,
      'craque_mes_count': p.craqueDoMesCount,
      ...p.communityToMap(),
    };
  }

  /// Já existe snapshot local utilizável (elenco com notas E overall) deste
  /// grupo? Snapshots antigos (sem `overall`) contam como inexistentes, para
  /// forçar uma recarga e a tela da partida nunca cair na nota do app.
  static Future<bool> hasLocalSnapshot(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('players_$groupId');
    if (raw == null) return false;
    try {
      final list = jsonDecode(raw) as List;
      if (list.isEmpty) return false;
      final first = list.first;
      return first is Map && first['overall'] != null;
    } catch (_) {
      return false;
    }
  }

  /// Retorna true se atualizou com dados da rede, false se ficou no local.
  /// [force] ignora o intervalo mínimo de 5 minutos entre cargas.
  Future<bool> prefetch(String groupId, {bool force = false}) {
    if (groupId.isEmpty) return Future.value(false);
    final last = _lastRun[groupId];
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 5)) {
      return Future.value(true);
    }
    return _running ??= _run(groupId).whenComplete(() => _running = null);
  }

  Future<bool> _run(String groupId) async {
    status.value = BootstrapStatus.loading;
    try {
      final svc = SupabaseService.instance;
      final players = await svc.players.getPlayersByGroup(groupId);
      if (players.isEmpty) {
        status.value = BootstrapStatus.offline;
        return false;
      }

      // Em paralelo: peladas (já cacheia cada uma) e histórico do grupo.
      final results = await Future.wait<dynamic>([
        _swallow(svc.sessions.getSessionsByGroup(groupId)),
        getAllGroupMatches(groupId),
      ]);
      final history = results[1] as List<dynamic>;

      // Conta pesada fora da thread da UI (no web roda inline).
      final Map<String, double> notas =
          history.isEmpty ? {} : await compute(_computeRatings, history);

      final list = players.map<Map<String, dynamic>>((p) {
        final nota = notas[p.id] ?? p.rating ?? kRatingBase;
        return playerSnapshotMap(p, nota);
      }).toList();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('players_$groupId', jsonEncode(list));
      await prefs.setString(
          'ratings_snapshot_at_$groupId', DateTime.now().toIso8601String());

      _lastRun[groupId] = DateTime.now();
      status.value = BootstrapStatus.ready;
      return true;
    } catch (e) {
      debugPrint('GroupBootstrap($groupId) falhou, seguindo com dados locais: $e');
      status.value = BootstrapStatus.offline;
      return false;
    }
  }
}

Future<void> _swallow(Future<dynamic> f) async {
  try {
    await f;
  } catch (_) {}
}

Map<String, double> _computeRatings(List<dynamic> history) {
  final stats = calculateGlobalStats(history);
  final out = <String, double>{};
  stats.forEach((pid, v) {
    final nota = v['nota'];
    if (nota is num) out[pid] = nota.toDouble();
  });
  return out;
}
