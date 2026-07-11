import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'player_identity.dart';
import 'rating_calculator.dart';

/// Utilitário para agregar todo o histórico de partidas de um grupo.
Future<List<dynamic>> getAllGroupMatches(String groupId) async {
  final prefs = await SharedPreferences.getInstance();
  final String sessionsKey = 'sessions_$groupId';
  final List<dynamic> allHistory = [];

  if (prefs.containsKey(sessionsKey)) {
    final List<dynamic> sessions = jsonDecode(prefs.getString(sessionsKey)!);
    for (final session in sessions) {
      final String? tId = session['id'];
      final String? sessionTimestamp = session['timestamp'];
      if (tId == null) continue;

      final String historyKey = 'match_history_$tId';
      if (!prefs.containsKey(historyKey)) continue;

      final List<dynamic> history = jsonDecode(prefs.getString(historyKey)!);
      if (sessionTimestamp != null) {
        for (final match in history) {
          if (match is Map) {
            match['session_date'] = sessionTimestamp;
          }
        }
      }
      allHistory.addAll(history);
    }
  }

  // Lógica para filtrar APENAS a temporada atual
  final String seasonsConfigKey = 'seasons_$groupId';
  if (prefs.containsKey(seasonsConfigKey)) {
    final List<dynamic> seasonsConfig = jsonDecode(prefs.getString(seasonsConfigKey)!);
    final now = DateTime.now();
    String? currentTemporadaId;
    
    for (var season in seasonsConfig) {
      if (season['startDate'] == null || season['endDate'] == null) continue;
      try {
        DateTime start = DateTime.parse(season['startDate']);
        DateTime end = DateTime.parse(season['endDate']).add(const Duration(days: 1));
        if (now.isAfter(start.subtract(const Duration(seconds: 1))) && now.isBefore(end)) {
          currentTemporadaId = (season['isPreSeason'] == true && season['parentSeasonId'] != null)
              ? season['parentSeasonId']
              : season['id'];
          break;
        }
      } catch (_) {}
    }

    if (currentTemporadaId == null && seasonsConfig.isNotEmpty) {
      currentTemporadaId = seasonsConfig[0]['id'];
    }

    if (currentTemporadaId != null) {
      // Retorna apenas partidas cuja data caia na Temporada Atual (Main ou Pre)
      final filtered = allHistory.where((match) {
        String sessionDate = match['session_date'] ?? match['date'] ?? '';
        if (sessionDate.isEmpty) return false;
        try {
          DateTime dt = DateTime.parse(sessionDate);
          for (var season in seasonsConfig) {
            if (season['startDate'] == null || season['endDate'] == null) continue;
            DateTime start = DateTime.parse(season['startDate']);
            DateTime end = DateTime.parse(season['endDate']).add(const Duration(days: 1));
            if (dt.isAfter(start.subtract(const Duration(seconds: 1))) && dt.isBefore(end)) {
              String sId = (season['isPreSeason'] == true && season['parentSeasonId'] != null)
                  ? season['parentSeasonId']
                  : season['id'];
              return sId == currentTemporadaId;
            }
          }
        } catch (_) {}
        return false;
      }).toList();

      filtered.sort((a, b) {
        String dateA = (a as Map)['session_date'] ?? a['date'] ?? '';
        String dateB = (b as Map)['session_date'] ?? b['date'] ?? '';
        return dateA.compareTo(dateB);
      });
      return filtered;
    }
  }

  allHistory.sort((a, b) {
    String dateA = (a as Map)['session_date'] ?? a['date'] ?? '';
    String dateB = (b as Map)['session_date'] ?? b['date'] ?? '';
    return dateA.compareTo(dateB);
  });
  return allHistory;
}

/// Processa todos os jogos e retorna um Map com as estatísticas globais de cada playerId
/// Map<String, Map<String, dynamic>> onde a chave é o playerId.
Map<String, Map<String, dynamic>> calculateGlobalStats(List<dynamic> allHistory) {
  final Map<String, Map<String, dynamic>> globalStats = {};

  for (final match in allHistory) {
    if (match is! Map) continue;
    final int scoreRed = match['scoreRed'] ?? 0;
    final int scoreWhite = match['scoreWhite'] ?? 0;
    final int redStatus = scoreRed > scoreWhite ? 1 : (scoreRed == scoreWhite ? 0 : -1);
    final int whiteStatus = scoreWhite > scoreRed ? 1 : (scoreRed == scoreWhite ? 0 : -1);

    // Coleta eventos por jogador nesta partida
    final Map<String, Map<String, int>> matchPlayerEvents = {};
    if (match['events'] != null) {
      for (final ev in match['events']) {
        if (ev is! Map) continue;
        final String pid = eventPlayerId(ev, 'player');
        final String astId = eventPlayerId(ev, 'assist');
        final String type = ev['type'];

        if (pid.isNotEmpty) {
          matchPlayerEvents.putIfAbsent(pid, () => {'g': 0, 'a': 0, 'og': 0, 'yc': 0, 'rc': 0});
          if (type == 'goal') matchPlayerEvents[pid]!['g'] = matchPlayerEvents[pid]!['g']! + 1;
          if (type == 'own_goal') matchPlayerEvents[pid]!['og'] = matchPlayerEvents[pid]!['og']! + 1;
          if (type == 'yellow_card') matchPlayerEvents[pid]!['yc'] = matchPlayerEvents[pid]!['yc']! + 1;
          if (type == 'red_card') matchPlayerEvents[pid]!['rc'] = matchPlayerEvents[pid]!['rc']! + 1;
        }
        if (astId.isNotEmpty) {
          matchPlayerEvents.putIfAbsent(astId, () => {'g': 0, 'a': 0, 'og': 0, 'yc': 0, 'rc': 0});
          if (type == 'goal') matchPlayerEvents[astId]!['a'] = matchPlayerEvents[astId]!['a']! + 1;
        }
      }
    }

    final Set<String> processed = {};
    
    // Calcula médias dos times baseadas nas notas até o momento
    final List<dynamic> redField = List<dynamic>.from(match['players']?['red'] ?? []);
    final dynamic gkRed = match['players']?['gk_red'];
    final List<dynamic> redPlayers = [...redField, gkRed].where((p) => p != null).toList();
    
    final List<dynamic> whiteField = List<dynamic>.from(match['players']?['white'] ?? []);
    final dynamic gkWhite = match['players']?['gk_white'];
    final List<dynamic> whitePlayers = [...whiteField, gkWhite].where((p) => p != null).toList();
    
    double redSum = 0; int redCount = 0;
    for (var p in redPlayers) {
      String pid = playerIdFromObject(p);
      if (pid.isNotEmpty && globalStats.containsKey(pid)) {
        redSum += calculateFinalRating(ratings: globalStats[pid]!['ratings'] as List<double>);
        redCount++;
      }
    }
    double redAvg = redCount > 0 ? redSum / redCount : kRatingBase;

    double whiteSum = 0; int whiteCount = 0;
    for (var p in whitePlayers) {
      String pid = playerIdFromObject(p);
      if (pid.isNotEmpty && globalStats.containsKey(pid)) {
        whiteSum += calculateFinalRating(ratings: globalStats[pid]!['ratings'] as List<double>);
        whiteCount++;
      }
    }
    double whiteAvg = whiteCount > 0 ? whiteSum / whiteCount : kRatingBase;

    void processPlayer(dynamic playerObj, int status, int scored, int conceded, double teamAvg, double oppAvg) {
      if (playerObj == null) return;
      final String playerId = playerIdFromObject(playerObj);
      if (playerId.isEmpty || processed.contains(playerId)) return;
      processed.add(playerId);

      globalStats.putIfAbsent(playerId, () => {
        'id': playerId,
        'games': 0, 'wins': 0, 'draws': 0, 'losses': 0,
        'goals': 0, 'assists': 0, 'yellow': 0, 'red': 0, 'ratings': <double>[],
        'name': (playerObj['name'] ?? '').toString()
      });
      
      final Map<String, dynamic> playerStats = globalStats[playerId]!;
      playerStats['games'] = (playerStats['games'] as int) + 1;
      
      if (status == 1) playerStats['wins'] = (playerStats['wins'] as int) + 1;
      else if (status == -1) playerStats['losses'] = (playerStats['losses'] as int) + 1;
      else playerStats['draws'] = (playerStats['draws'] as int) + 1;

      final int g = matchPlayerEvents[playerId]?['g'] ?? 0;
      final int a = matchPlayerEvents[playerId]?['a'] ?? 0;
      final int og = matchPlayerEvents[playerId]?['og'] ?? 0;
      final int yc = matchPlayerEvents[playerId]?['yc'] ?? 0;
      final int rc = matchPlayerEvents[playerId]?['rc'] ?? 0;

      playerStats['goals'] = (playerStats['goals'] as int) + g;
      playerStats['assists'] = (playerStats['assists'] as int) + a;
      playerStats['yellow'] = (playerStats['yellow'] as int) + yc;
      playerStats['red'] = (playerStats['red'] as int) + rc;

      final double matchRating = calculateMatchRating(
        status: status, goals: g, assists: a,
        ownGoals: og, teamGoals: scored, conceded: conceded, yellow: yc, red: rc,
        teamWinStreak: 0, teamAvgRating: teamAvg, opponentAvgRating: oppAvg
      );
      (playerStats['ratings'] as List<double>).add(matchRating);
    }

    if (match['players'] != null && match['players'] is Map) {
      if (match['players']['red'] != null) {
        for (final p in match['players']['red']) processPlayer(p, redStatus, scoreRed, scoreWhite, redAvg, whiteAvg);
      }
      if (match['players']['white'] != null) {
        for (final p in match['players']['white']) processPlayer(p, whiteStatus, scoreWhite, scoreRed, whiteAvg, redAvg);
      }
      if (match['players']['gk_red'] != null) processPlayer(match['players']['gk_red'], redStatus, scoreRed, scoreWhite, redAvg, whiteAvg);
      if (match['players']['gk_white'] != null) processPlayer(match['players']['gk_white'], whiteStatus, scoreWhite, scoreRed, whiteAvg, redAvg);
    }
  }

  // Precalcula a nota final (já usando as regras matemáticas definidas no rating_calculator)
  globalStats.forEach((id, data) {
    data['nota'] = calculateFinalRating(ratings: data['ratings'] as List<double>);
    data['ga'] = (data['goals'] as int) + (data['assists'] as int);
  });

  return globalStats;
}
