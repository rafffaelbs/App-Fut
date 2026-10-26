import '../models/match_model.dart';
import 'player_identity.dart';

/// Representação normalizada e leve de uma partida finalizada para cálculo de fila/banco.
class FinishedMatchInfo {
  final String id;
  final DateTime endTime;
  final Set<String> playerIds;

  const FinishedMatchInfo({
    required this.id,
    required this.endTime,
    required this.playerIds,
  });

  /// Constrói a partir de um [MatchModel].
  factory FinishedMatchInfo.fromMatchModel(MatchModel match) {
    DateTime end = match.endTime ??
        (match.startTime != null && match.durationSeconds != null
            ? match.startTime!.add(Duration(seconds: match.durationSeconds!))
            : match.startTime ?? DateTime.now());

    final ids = <String>{};
    for (final lineup in match.lineups) {
      if (lineup.playerId.trim().isNotEmpty) {
        ids.add(lineup.playerId);
      }
    }
    if (ids.isEmpty && match.customPlayers != null) {
      for (final p in match.customPlayers!.red) {
        final pid = p.id.isNotEmpty ? p.id : p.name;
        if (pid.isNotEmpty) ids.add(pid);
      }
      for (final p in match.customPlayers!.white) {
        final pid = p.id.isNotEmpty ? p.id : p.name;
        if (pid.isNotEmpty) ids.add(pid);
      }
      if (match.customPlayers!.gkRed != null) {
        final p = match.customPlayers!.gkRed!;
        final pid = p.id.isNotEmpty ? p.id : p.name;
        if (pid.isNotEmpty) ids.add(pid);
      }
      if (match.customPlayers!.gkWhite != null) {
        final p = match.customPlayers!.gkWhite!;
        final pid = p.id.isNotEmpty ? p.id : p.name;
        if (pid.isNotEmpty) ids.add(pid);
      }
    }

    return FinishedMatchInfo(
      id: match.id,
      endTime: end,
      playerIds: ids,
    );
  }

  /// Constrói a partir do mapa JSON legado (`match_history_` salvo em SharedPreferences).
  factory FinishedMatchInfo.fromMap(Map<String, dynamic> map) {
    final String id = map['match_id']?.toString() ??
        map['id']?.toString() ??
        '';

    DateTime end = DateTime.tryParse(map['date']?.toString() ?? '') ??
        DateTime.tryParse(map['end_time']?.toString() ?? '') ??
        DateTime.tryParse(map['start_time']?.toString() ?? '') ??
        DateTime.now();

    final ids = <String>{};
    void extractPlayers(dynamic list) {
      if (list is List) {
        for (final p in list) {
          final pid = playerIdFromObject(p);
          if (pid.isNotEmpty) ids.add(pid);
        }
      }
    }

    if (map['players'] is Map) {
      final pMap = map['players'] as Map;
      extractPlayers(pMap['red']);
      extractPlayers(pMap['white']);
      if (pMap['gk_red'] != null) {
        final pid = playerIdFromObject(pMap['gk_red']);
        if (pid.isNotEmpty) ids.add(pid);
      }
      if (pMap['gk_white'] != null) {
        final pid = playerIdFromObject(pMap['gk_white']);
        if (pid.isNotEmpty) ids.add(pid);
      }
    }

    return FinishedMatchInfo(
      id: id,
      endTime: end,
      playerIds: ids,
    );
  }
}

/// Estatísticas de espera/banco de um jogador.
class WaitingBenchStats {
  /// Se o jogador participou de pelo menos uma partida encerrada na pelada atual.
  final bool hasPlayed;

  /// Horário de término da última partida em que participou (ou de início da pelada se nunca jogou).
  final DateTime? waitingSince;

  /// Quantas partidas se encerraram após a última participação dele (ou desde o início).
  final int completedMatchesSinceLastPlayed;

  const WaitingBenchStats({
    required this.hasPlayed,
    required this.waitingSince,
    required this.completedMatchesSinceLastPlayed,
  });

  /// Tempo total no banco decorrido até [now].
  Duration? durationOnBench(DateTime now) {
    if (waitingSince == null) return null;
    final diff = now.difference(waitingSince!);
    return diff.isNegative ? Duration.zero : diff;
  }
}

/// Serviço puro para cálculo de tempo e jogos no banco.
class BenchTimeCalculator {
  /// Calcula as estatísticas de banco do jogador [playerId] a partir do histórico [finishedMatches].
  ///
  /// As partidas são ordenadas cronologicamente por `endTime`.
  /// Se o jogador não jogou nenhuma partida, utiliza [sessionStartTime] como referência temporal.
  static WaitingBenchStats calculate({
    required String playerId,
    required List<FinishedMatchInfo> finishedMatches,
    DateTime? sessionStartTime,
  }) {
    if (playerId.isEmpty) {
      return WaitingBenchStats(
        hasPlayed: false,
        waitingSince: sessionStartTime,
        completedMatchesSinceLastPlayed: finishedMatches.length,
      );
    }

    // Garante ordenação cronológica crescente
    final sorted = List<FinishedMatchInfo>.from(finishedMatches)
      ..sort((a, b) => a.endTime.compareTo(b.endTime));

    int lastMatchIndex = -1;
    for (int i = sorted.length - 1; i >= 0; i--) {
      if (sorted[i].playerIds.contains(playerId)) {
        lastMatchIndex = i;
        break;
      }
    }

    if (lastMatchIndex != -1) {
      final lastMatch = sorted[lastMatchIndex];
      final gamesSince = (sorted.length - 1) - lastMatchIndex;
      return WaitingBenchStats(
        hasPlayed: true,
        waitingSince: lastMatch.endTime,
        completedMatchesSinceLastPlayed: gamesSince,
      );
    }

    // Nunca jogou nesta pelada
    return WaitingBenchStats(
      hasPlayed: false,
      waitingSince: sessionStartTime,
      completedMatchesSinceLastPlayed: sorted.length,
    );
  }

  /// Formata uma duração em string amigável: "< 1 min", "18 min", "1h20".
  static String formatDuration(Duration d) {
    if (d.inMinutes < 1) return '< 1 min';
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  /// Formata a exibição do tempo e jogos no banco seguindo as regras do app.
  ///
  /// Exemplo de exibição:
  /// - Acabou de sair (< 1 min, 0 jogos): "Acabou de sair"
  /// - 18 min e 2 jogos: "No banco há 18 min · 2 jogos"
  /// - Nunca jogou (estreia com início conhecido): "No banco há 25 min · 2 jogos (estreia)"
  /// - Nunca jogou (sem início conhecido ou 0 jogos): "Ainda não jogou" / "Ainda não jogou · 2 jogos"
  static String formatDisplay(
    WaitingBenchStats stats, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();

    if (stats.hasPlayed) {
      final duration = stats.durationOnBench(current) ?? Duration.zero;
      final games = stats.completedMatchesSinceLastPlayed;

      if (games == 0 && duration.inMinutes < 1) {
        return 'Acabou de sair';
      }

      final gamesText = games == 1 ? '1 jogo' : '$games jogos';
      if (duration.inMinutes < 1) {
        return 'No banco há < 1 min · $gamesText';
      }
      return 'No banco há ${formatDuration(duration)} · $gamesText';
    }

    // Caso de borda: jogador que ainda não jogou nenhuma partida
    final games = stats.completedMatchesSinceLastPlayed;
    if (games == 0) {
      return 'Ainda não jogou';
    }

    final gamesText = games == 1 ? '1 jogo' : '$games jogos';
    if (stats.waitingSince != null) {
      final duration = stats.durationOnBench(current);
      if (duration != null && duration.inMinutes >= 1) {
        return 'No banco há ${formatDuration(duration)} · $gamesText (estreia)';
      }
    }

    return 'Ainda não jogou · $gamesText';
  }
}
