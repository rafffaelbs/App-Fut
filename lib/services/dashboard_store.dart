import 'package:flutter/foundation.dart';
import 'package:app_do_fut/app/app_services.dart';
import 'package:app_do_fut/models/player_model.dart';
import 'package:app_do_fut/services/group_bootstrap.dart';
import 'package:app_do_fut/utils/dashboard_highlights.dart';
import 'package:app_do_fut/utils/rating_calculator.dart';
import 'package:app_do_fut/utils/stats_calculator.dart';

enum DashboardStatus { idle, loading, ready, error }

/// Resultado pronto da aba "Início" (somente leitura).
class DashboardData {
  final String groupId;
  final String currentMonth;
  final String previousMonth;
  final List<PlayerMonthStat> currentTop;
  final List<PlayerMonthStat> previousTop;
  final int currentMatches;
  final int previousMatches;
  final PlayerMonthStat? currentScorer;
  final PlayerMonthStat? previousScorer;
  final PlayerMonthStat? currentAssister;
  final PlayerMonthStat? previousAssister;
  final LastSessionSummary? lastSession;

  /// Jogadores com o selo manual `monthly_highlight` verdadeiro.
  final List<PlayerModel> officialCraques;

  /// Mapa de jogador (formato do ranking) por id, para avatar com moldura.
  final Map<String, Map<String, dynamic>> playerMaps;

  const DashboardData({
    required this.groupId,
    required this.currentMonth,
    required this.previousMonth,
    required this.currentTop,
    required this.previousTop,
    required this.currentMatches,
    required this.previousMatches,
    required this.currentScorer,
    required this.previousScorer,
    required this.currentAssister,
    required this.previousAssister,
    required this.lastSession,
    required this.officialCraques,
    required this.playerMaps,
  });
}

/// Guarda, fora de qualquer State, o resultado da aba "Início". Calcula UMA
/// vez por grupo depois do snapshot carregar (não recalcula ao trocar de aba).
class DashboardStore {
  DashboardStore._();
  static final DashboardStore instance = DashboardStore._();

  final ValueNotifier<DashboardStatus> status =
      ValueNotifier<DashboardStatus>(DashboardStatus.idle);

  DashboardData? data;
  String? _groupId;
  Future<void>? _running;

  /// Calcula se ainda não há resultado deste grupo. [force] recalcula.
  Future<void> ensure(String groupId, {bool force = false}) {
    if (!force && _groupId == groupId && data != null) return Future.value();
    if (_running != null && _groupId == groupId) return _running!;
    _groupId = groupId;
    data = null;
    return _running = _run(groupId).whenComplete(() => _running = null);
  }

  @visibleForTesting
  void reset() {
    data = null;
    _groupId = null;
    _running = null;
    status.value = DashboardStatus.idle;
  }

  Future<void> _run(String groupId) async {
    status.value = DashboardStatus.loading;
    try {
      // Espera a carga inicial do grupo (dedupe: reaproveita a que já roda).
      await GroupBootstrap.instance.prefetch(groupId);
      final svc = AppServices.instance;
      final history = await getAllGroupMatches(groupId);
      final sessions = await svc.sessions.getSessionsByGroup(groupId);
      final players = await svc.players.getPlayersByGroup(groupId);

      final cur = monthKeyOf(DateTime.now());
      final prev = previousMonthKey(cur);

      final result = DashboardData(
        groupId: groupId,
        currentMonth: cur,
        previousMonth: prev,
        currentTop: monthlyHighlight(history, sessions, cur),
        previousTop: monthlyHighlight(history, sessions, prev),
        currentMatches: matchesInMonth(history, sessions, cur),
        previousMatches: matchesInMonth(history, sessions, prev),
        currentScorer: topScorerOfMonth(history, sessions, cur),
        previousScorer: topScorerOfMonth(history, sessions, prev),
        currentAssister: topAssisterOfMonth(history, sessions, cur),
        previousAssister: topAssisterOfMonth(history, sessions, prev),
        lastSession: lastSessionSummary(history, sessions),
        officialCraques: players.where((p) => p.monthlyHighlight).toList(),
        playerMaps: {
          for (final p in players)
            p.id: GroupBootstrap.playerSnapshotMap(p, p.rating ?? kRatingBase),
        },
      );
      // O grupo pode ter mudado durante o cálculo.
      if (_groupId != groupId) return;
      data = result;
      status.value = DashboardStatus.ready;
    } catch (e, st) {
      debugPrint('DashboardStore($groupId) falhou: $e\n$st');
      if (_groupId == groupId) status.value = DashboardStatus.error;
    }
  }
}
