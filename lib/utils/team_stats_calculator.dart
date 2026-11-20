import '../models/match_model.dart';
import '../models/player_model.dart';

/// Estatísticas agregadas de uma formação ou grupo de jogadores jogando juntos.
class TeamStats {
  final List<String> playerIds;
  final int matches;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final int cleanSheets;
  final Map<String, int> playerGoals;
  final List<MatchModel> matchesList;

  const TeamStats({
    required this.playerIds,
    this.matches = 0,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
    this.cleanSheets = 0,
    this.playerGoals = const {},
    this.matchesList = const [],
  });

  factory TeamStats.empty(List<String> playerIds) {
    return TeamStats(
      playerIds: List<String>.from(playerIds)..sort(),
      matches: 0,
      wins: 0,
      draws: 0,
      losses: 0,
      goalsFor: 0,
      goalsAgainst: 0,
      cleanSheets: 0,
      playerGoals: const {},
      matchesList: const [],
    );
  }

  int get goalDiff => goalsFor - goalsAgainst;

  double get winRate => matches > 0 ? (wins / matches) * 100 : 0.0;

  double get goalsForAvg => matches > 0 ? goalsFor / matches : 0.0;

  double get goalsAgainstAvg => matches > 0 ? goalsAgainst / matches : 0.0;

  int get points => (wins * 3) + draws;

  double get pointsPct => matches > 0 ? (points / (matches * 3)) * 100 : 0.0;

  String? get topScorerId {
    if (playerGoals.isEmpty) return null;
    var maxG = -1;
    String? bestId;
    playerGoals.forEach((id, g) {
      if (g > maxG) {
        maxG = g;
        bestId = id;
      }
    });
    return maxG > 0 ? bestId : null;
  }

  int get topScorerGoals {
    if (playerGoals.isEmpty) return 0;
    var maxG = 0;
    playerGoals.forEach((_, g) {
      if (g > maxG) maxG = g;
    });
    return maxG;
  }
}

/// Estatística de rivalidade (confronto direto) entre 2 jogadores quando jogam em times opostos.
class RivalryStat {
  final String player1Id;
  final String player2Id;
  final int matchesAgainst;
  final int p1Wins;
  final int p2Wins;
  final int draws;
  final int p1Goals;
  final int p2Goals;

  const RivalryStat({
    required this.player1Id,
    required this.player2Id,
    required this.matchesAgainst,
    required this.p1Wins,
    required this.p2Wins,
    required this.draws,
    this.p1Goals = 0,
    this.p2Goals = 0,
  });

  bool get isTied => p1Wins == p2Wins;

  String? get leaderId {
    if (p1Wins > p2Wins) return player1Id;
    if (p2Wins > p1Wins) return player2Id;
    return null;
  }

  int get leaderWins {
    if (p1Wins > p2Wins) return p1Wins;
    if (p2Wins > p1Wins) return p2Wins;
    return p1Wins;
  }

  int get leaderLosses {
    if (p1Wins > p2Wins) return p2Wins;
    if (p2Wins > p1Wins) return p1Wins;
    return p2Wins;
  }
}

class TeamStatsCalculator {
  TeamStatsCalculator._();

  /// Avalia retrospecto conjunto quando TODOS os [playerIds] selecionados jogaram no mesmo time.
  static TeamStats evaluateCustomTeam(
    List<String> playerIds,
    List<MatchModel> matches,
  ) {
    if (playerIds.isEmpty) return TeamStats.empty([]);
    final targetIds = playerIds.toSet();

    int matchesCount = 0;
    int wins = 0;
    int draws = 0;
    int losses = 0;
    int goalsFor = 0;
    int goalsAgainst = 0;
    int cleanSheets = 0;
    final Map<String, int> playerGoals = {};
    final List<MatchModel> playedMatches = [];

    for (final match in matches) {
      final redIds = match.lineups
          .where((l) => l.isRed && l.playerId.isNotEmpty)
          .map((l) => l.playerId)
          .toSet();
      final whiteIds = match.lineups
          .where((l) => l.isWhite && l.playerId.isNotEmpty)
          .map((l) => l.playerId)
          .toSet();

      final bool playedTogetherOnRed = targetIds.every(redIds.contains);
      final bool playedTogetherOnWhite = targetIds.every(whiteIds.contains);

      if (!playedTogetherOnRed && !playedTogetherOnWhite) continue;

      matchesCount++;
      playedMatches.add(match);

      final int teamScore = playedTogetherOnRed ? match.scoreRed : match.scoreWhite;
      final int oppScore = playedTogetherOnRed ? match.scoreWhite : match.scoreRed;

      goalsFor += teamScore;
      goalsAgainst += oppScore;
      if (oppScore == 0) cleanSheets++;

      if (teamScore > oppScore) {
        wins++;
      } else if (teamScore == oppScore) {
        draws++;
      } else {
        losses++;
      }

      // Gols dos membros do grupo nesta partida
      for (final ev in match.events) {
        if (ev.isGoal && targetIds.contains(ev.playerId)) {
          playerGoals[ev.playerId] = (playerGoals[ev.playerId] ?? 0) + 1;
        }
      }
    }

    final sortedList = List<String>.from(playerIds)..sort();
    return TeamStats(
      playerIds: sortedList,
      matches: matchesCount,
      wins: wins,
      draws: draws,
      losses: losses,
      goalsFor: goalsFor,
      goalsAgainst: goalsAgainst,
      cleanSheets: cleanSheets,
      playerGoals: playerGoals,
      matchesList: playedMatches,
    );
  }

  /// Calcula estatísticas dos times exatos que atuaram juntos nas partidas.
  /// Agrupa por escalações de linha (ou completas) que jogaram no mesmo lado.
  static List<TeamStats> computeExactTeams(
    List<MatchModel> matches, {
    int minMatches = 2,
    int? teamSize,
    bool excludeGoalkeepers = false,
  }) {
    // Chave do time -> estatísticas acumuladas
    final Map<String, _TeamAccumulator> teamMap = {};

    for (final match in matches) {
      // Time Vermelho
      final redPlayers = match.lineups
          .where((l) => l.isRed && l.playerId.isNotEmpty && (!excludeGoalkeepers || !l.isGoalkeeper))
          .map((l) => l.playerId)
          .toSet()
          .toList()
        ..sort();

      if (redPlayers.isNotEmpty && (teamSize == null || redPlayers.length == teamSize)) {
        final key = redPlayers.join('|');
        final acc = teamMap.putIfAbsent(key, () => _TeamAccumulator(redPlayers));
        acc.addMatch(match, isRed: true);
      }

      // Time Branco
      final whitePlayers = match.lineups
          .where((l) => l.isWhite && l.playerId.isNotEmpty && (!excludeGoalkeepers || !l.isGoalkeeper))
          .map((l) => l.playerId)
          .toSet()
          .toList()
        ..sort();

      if (whitePlayers.isNotEmpty && (teamSize == null || whitePlayers.length == teamSize)) {
        final key = whitePlayers.join('|');
        final acc = teamMap.putIfAbsent(key, () => _TeamAccumulator(whitePlayers));
        acc.addMatch(match, isRed: false);
      }
    }

    return teamMap.values
        .where((acc) => acc.matches >= minMatches)
        .map((acc) => acc.toTeamStats())
        .toList();
  }

  /// Retorna o "Melhor Time da Pelada": o conjunto de jogadores de linha que
  /// mais venceu na sessão (com desempate por saldo de gols e gols pró).
  static TeamStats? computeBestSessionTeam(List<MatchModel> sessionMatches) {
    if (sessionMatches.isEmpty) return null;

    final teams = computeExactTeams(
      sessionMatches,
      minMatches: 1,
      excludeGoalkeepers: true,
    );

    if (teams.isEmpty) return null;

    // Ordena por vitórias desc, saldo desc, gols pró desc
    teams.sort((a, b) {
      if (b.wins != a.wins) return b.wins.compareTo(a.wins);
      if (b.goalDiff != a.goalDiff) return b.goalDiff.compareTo(a.goalDiff);
      if (b.goalsFor != a.goalsFor) return b.goalsFor.compareTo(a.goalsFor);
      return b.winRate.compareTo(a.winRate);
    });

    return teams.first;
  }

  /// Calcula o confronto direto (rivalidade) entre jogadores que jogaram em times opostos.
  static List<RivalryStat> computeTopRivalries(
    List<MatchModel> matches, {
    int limit = 10,
    int minMatches = 2,
  }) {
    // Par ordenado de ids -> _RivalryAccumulator
    final Map<String, _RivalryAccumulator> map = {};

    for (final match in matches) {
      final redPlayers = match.lineups
          .where((l) => l.isRed && l.playerId.isNotEmpty)
          .map((l) => l.playerId)
          .toSet();
      final whitePlayers = match.lineups
          .where((l) => l.isWhite && l.playerId.isNotEmpty)
          .map((l) => l.playerId)
          .toSet();

      final redWon = match.scoreRed > match.scoreWhite;
      final whiteWon = match.scoreWhite > match.scoreRed;
      final isDraw = match.scoreRed == match.scoreWhite;

      // Gols por jogador na partida
      final Map<String, int> matchGoals = {};
      for (final ev in match.events) {
        if (ev.isGoal && ev.playerId.isNotEmpty) {
          matchGoals[ev.playerId] = (matchGoals[ev.playerId] ?? 0) + 1;
        }
      }

      for (final p1 in redPlayers) {
        for (final p2 in whitePlayers) {
          final id1 = p1.compareTo(p2) < 0 ? p1 : p2;
          final id2 = p1.compareTo(p2) < 0 ? p2 : p1;
          final key = '$id1|$id2';

          final acc = map.putIfAbsent(key, () => _RivalryAccumulator(id1, id2));
          acc.matches++;
          if (isDraw) {
            acc.draws++;
          } else if (p1 == id1) {
            if (redWon) acc.p1Wins++;
            if (whiteWon) acc.p2Wins++;
          } else {
            if (whiteWon) acc.p1Wins++;
            if (redWon) acc.p2Wins++;
          }

          acc.p1Goals += (matchGoals[id1] ?? 0);
          acc.p2Goals += (matchGoals[id2] ?? 0);
        }
      }
    }

    final list = map.values
        .where((acc) => acc.matches >= minMatches)
        .map((acc) => acc.toRivalryStat())
        .toList();

    // Ordena por partidas jogadas contra e equilíbrio/intensidade
    list.sort((a, b) {
      if (b.matchesAgainst != a.matchesAgainst) {
        return b.matchesAgainst.compareTo(a.matchesAgainst);
      }
      return (b.p1Wins + b.p2Wins).compareTo(a.p1Wins + a.p2Wins);
    });

    return list.take(limit).toList();
  }
}

class _TeamAccumulator {
  final List<String> playerIds;
  int matches = 0;
  int wins = 0;
  int draws = 0;
  int losses = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;
  int cleanSheets = 0;
  final Map<String, int> playerGoals = {};
  final List<MatchModel> matchesList = [];

  _TeamAccumulator(this.playerIds);

  void addMatch(MatchModel match, {required bool isRed}) {
    matches++;
    matchesList.add(match);

    final teamScore = isRed ? match.scoreRed : match.scoreWhite;
    final oppScore = isRed ? match.scoreWhite : match.scoreRed;

    goalsFor += teamScore;
    goalsAgainst += oppScore;
    if (oppScore == 0) cleanSheets++;

    if (teamScore > oppScore) {
      wins++;
    } else if (teamScore == oppScore) {
      draws++;
    } else {
      losses++;
    }

    final pSet = playerIds.toSet();
    for (final ev in match.events) {
      if (ev.isGoal && pSet.contains(ev.playerId)) {
        playerGoals[ev.playerId] = (playerGoals[ev.playerId] ?? 0) + 1;
      }
    }
  }

  TeamStats toTeamStats() {
    return TeamStats(
      playerIds: playerIds,
      matches: matches,
      wins: wins,
      draws: draws,
      losses: losses,
      goalsFor: goalsFor,
      goalsAgainst: goalsAgainst,
      cleanSheets: cleanSheets,
      playerGoals: playerGoals,
      matchesList: matchesList,
    );
  }
}

class _RivalryAccumulator {
  final String player1Id;
  final String player2Id;
  int matches = 0;
  int p1Wins = 0;
  int p2Wins = 0;
  int draws = 0;
  int p1Goals = 0;
  int p2Goals = 0;

  _RivalryAccumulator(this.player1Id, this.player2Id);

  RivalryStat toRivalryStat() {
    return RivalryStat(
      player1Id: player1Id,
      player2Id: player2Id,
      matchesAgainst: matches,
      p1Wins: p1Wins,
      p2Wins: p2Wins,
      draws: draws,
      p1Goals: p1Goals,
      p2Goals: p2Goals,
    );
  }
}
