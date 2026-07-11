import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'player_identity.dart';
import 'rating_calculator.dart';

class SiteDataGenerator {
  /// Gera o pacote de dados `site_data` contendo estatísticas pré-calculadas
  /// para o site society.
  static Future<Map<String, dynamic>> generate(SharedPreferences prefs) async {
    // 1. Encontrar o groupId (pega o primeiro disponível se houver vários)
    final keys = prefs.getKeys();
    String? groupId;
    for (String key in keys) {
      if (key.startsWith('app_groups')) {
        final groups = jsonDecode(prefs.getString(key) ?? '[]');
        if (groups.isNotEmpty) {
          groupId = groups[0]['id'];
          break;
        }
      }
    }
    
    // Fallback: tentar extrair de players_
    if (groupId == null) {
      for (String key in keys) {
        if (key.startsWith('players_grupo_')) {
          groupId = key.replaceFirst('players_', '');
          break;
        }
      }
    }

    if (groupId == null) return {};

    // 2. Carregar sessões e seasons config
    List<dynamic> sessions = [];
    final String sessionsKey = 'sessions_$groupId';
    if (prefs.containsKey(sessionsKey)) {
      sessions = jsonDecode(prefs.getString(sessionsKey)!);
    }
    
    List<dynamic> seasonsConfig = [];
    final String seasonsConfigKey = 'seasons_$groupId';
    if (prefs.containsKey(seasonsConfigKey)) {
      seasonsConfig = jsonDecode(prefs.getString(seasonsConfigKey)!);
    }

    // 3. Carregar Histórico de todas as partidas
    List<dynamic> allHistory = [];
    Map<String, List<dynamic>> historyBySession = {};
    for (final session in sessions) {
      final String? tId = session['id'];
      final String? sessionTimestamp = session['timestamp'];
      if (tId == null) continue;

      final String historyKey = 'match_history_$tId';
      if (!prefs.containsKey(historyKey)) continue;

      final List<dynamic> history = jsonDecode(prefs.getString(historyKey)!);
      for (final match in history) {
        if (match is Map) {
          match['session_date'] = sessionTimestamp;
        }
      }
      historyBySession[tId] = history;
      allHistory.addAll(history);
    }

    // 4. Carregar Jogadores Base
    final String playersKey = 'players_$groupId';
    List<Map<String, dynamic>> basePlayers = [];
    if (prefs.containsKey(playersKey)) {
      basePlayers = ensurePlayerIds(
        List<Map<String, dynamic>>.from(jsonDecode(prefs.getString(playersKey)!)),
      );
    }
    Map<String, Map<String, dynamic>> playersMap = {};
    for (var p in basePlayers) {
      playersMap[p['id'].toString()] = p;
    }

    // 5. Calcular estatísticas globais e avançadas para cada jogador
    // Sort allHistory chronologically to ensure EMA and Elo calculations are correct
    allHistory.sort((a, b) {
      String dateA = (a as Map)['session_date'] ?? a['date'] ?? '';
      String dateB = (b as Map)['session_date'] ?? b['date'] ?? '';
      return dateA.compareTo(dateB);
    });

    Map<String, Map<String, dynamic>> sitePlayers = {};
    _calculateGlobalAndAdvancedStats(allHistory, sitePlayers, playersMap, seasonsConfig);

    // 6. Resumo das Sessões (Dias de pelada)
    List<Map<String, dynamic>> siteSessions = [];
    for (final session in sessions) {
      final String? tId = session['id'];
      if (tId == null) continue;
      final history = historyBySession[tId] ?? [];
      
      int totalGoals = 0;
      int biggestMargin = 0;
      String biggestWin = "-";
      double sumRatings = 0;
      int ratingCount = 0;
      
      Map<String, double> sessionPlayerRatings = {};
      Map<String, int> sessionPlayerGoals = {};
      Map<String, int> sessionPlayerAssists = {};
      
      for (final match in history) {
        int scoreR = match['scoreRed'] ?? 0;
        int scoreW = match['scoreWhite'] ?? 0;
        totalGoals += scoreR + scoreW;
        
        int margin = (scoreR - scoreW).abs();
        if (margin > biggestMargin) {
          biggestMargin = margin;
          biggestWin = scoreR > scoreW ? "$scoreR x $scoreW" : "$scoreW x $scoreR";
        }

        // Ratings and MVP logic for session
        final int redStatus = scoreR > scoreW ? 1 : (scoreR == scoreW ? 0 : -1);
        final int whiteStatus = scoreW > scoreR ? 1 : (scoreR == scoreW ? 0 : -1);

        Map<String, Map<String, int>> matchPlayerEvents = {};
        if (match['events'] != null) {
          for (final ev in match['events']) {
            final String pid = eventPlayerId(ev, 'player');
            final String astId = eventPlayerId(ev, 'assist');
            final String type = ev['type'];
            
            if (pid.isNotEmpty) {
              matchPlayerEvents.putIfAbsent(pid, () => {'g': 0, 'a': 0, 'og': 0, 'yc': 0, 'rc': 0});
              if (type == 'goal') {
                matchPlayerEvents[pid]!['g'] = matchPlayerEvents[pid]!['g']! + 1;
                sessionPlayerGoals[pid] = (sessionPlayerGoals[pid] ?? 0) + 1;
              }
              if (type == 'own_goal') matchPlayerEvents[pid]!['og'] = matchPlayerEvents[pid]!['og']! + 1;
              if (type == 'yellow_card') matchPlayerEvents[pid]!['yc'] = matchPlayerEvents[pid]!['yc']! + 1;
              if (type == 'red_card') matchPlayerEvents[pid]!['rc'] = matchPlayerEvents[pid]!['rc']! + 1;
            }
            if (astId.isNotEmpty) {
              matchPlayerEvents.putIfAbsent(astId, () => {'g': 0, 'a': 0, 'og': 0, 'yc': 0, 'rc': 0});
              if (type == 'goal') {
                matchPlayerEvents[astId]!['a'] = matchPlayerEvents[astId]!['a']! + 1;
                sessionPlayerAssists[astId] = (sessionPlayerAssists[astId] ?? 0) + 1;
              }
            }
          }
        }

        void processPlayer(dynamic pObj, int status, int scored, int conceded) {
          if (pObj == null) return;
          String pId = playerIdFromObject(pObj);
          if (pId.isEmpty) return;
          
          final g = matchPlayerEvents[pId]?['g'] ?? 0;
          final a = matchPlayerEvents[pId]?['a'] ?? 0;
          final og = matchPlayerEvents[pId]?['og'] ?? 0;
          final yc = matchPlayerEvents[pId]?['yc'] ?? 0;
          final rc = matchPlayerEvents[pId]?['rc'] ?? 0;
          
          double rating = calculateMatchRating(
            status: status, goals: g, assists: a, ownGoals: og, 
            teamGoals: scored, conceded: conceded, yellow: yc, red: rc, teamWinStreak: 0
          );
          
          sumRatings += rating;
          ratingCount++;
        }

        if (match['players'] != null) {
          for (final p in match['players']['red'] ?? []) processPlayer(p, redStatus, scoreR, scoreW);
          for (final p in match['players']['white'] ?? []) processPlayer(p, whiteStatus, scoreW, scoreR);
          processPlayer(match['players']['gk_red'], redStatus, scoreR, scoreW);
          processPlayer(match['players']['gk_white'], whiteStatus, scoreW, scoreR);
        }
      }
      
      // MVP do dia (maior G+A)
      String mvpId = "";
      int maxGA = -1;
      sessionPlayerGoals.forEach((id, g) {
        int a = sessionPlayerAssists[id] ?? 0;
        if (g + a > maxGA) {
          maxGA = g + a;
          mvpId = id;
        }
      });
      
      siteSessions.add({
        ...session,
        'matchesCount': history.length,
        'totalGoals': totalGoals,
        'avgGoals': history.isNotEmpty ? (totalGoals / history.length).toStringAsFixed(1) : "0",
        'biggestWin': biggestWin,
        'avgRating': ratingCount > 0 ? (sumRatings / ratingCount).toStringAsFixed(1) : "0",
        'mvpId': mvpId,
        'mvpName': playersMap[mvpId]?['name'] ?? '',
        'mvpIcon': playersMap[mvpId]?['icon'] ?? '',
      });
    }

    Map<String, dynamic> liveData = {'active_session': false};
    for (final session in sessions) {
      if (session['status'] == 'Em Andamento') {
        final String tId = session['id'];
        final int playerCount = session['jogadores'] ?? 5;
        
        List<dynamic> teamRed = [];
        List<dynamic> teamWhite = [];
        List<dynamic> presentPlayers = [];
        
        if (prefs.containsKey('team_red_$tId')) {
          teamRed = jsonDecode(prefs.getString('team_red_$tId')!);
        }
        if (prefs.containsKey('team_white_$tId')) {
          teamWhite = jsonDecode(prefs.getString('team_white_$tId')!);
        }
        if (prefs.containsKey('present_players_$tId')) {
          presentPlayers = jsonDecode(prefs.getString('present_players_$tId')!);
        }

        Set<String> activeIds = {};
        for (var p in teamRed) activeIds.add(playerIdFromObject(p));
        for (var p in teamWhite) activeIds.add(playerIdFromObject(p));

        List<String> waitingIds = [];
        for (var p in presentPlayers) {
          final id = playerIdFromObject(p);
          if (!activeIds.contains(id)) waitingIds.add(id);
        }

        List<List<String>> queues = [];
        for (int i = 0; i < waitingIds.length; i += playerCount) {
          int end = (i + playerCount < waitingIds.length) ? i + playerCount : waitingIds.length;
          queues.add(waitingIds.sublist(i, end));
        }

        liveData = {
          'active_session': true,
          'mode_format': playerCount <= 5 ? 'futsal' : 'society',
          'player_count_per_team': playerCount,
          'active_teams': {
            'red': teamRed.map((p) => playerIdFromObject(p)).toList(),
            'white': teamWhite.map((p) => playerIdFromObject(p)).toList(),
          },
          'queues': queues,
        };
        break;
      }
    }

    return {
      'players': sitePlayers.values.toList(),
      'sessions': siteSessions,
      'seasons_config': seasonsConfig,
      'live_session': jsonEncode(liveData),
      'rating_rules': {
        'base': kRatingBase,
        'goal': kWeightGoal,
        'assist': kWeightAssist,
        'win': kResultImpactWin,
        'loss': kResultImpactLoss,
        'yellow': kWeightYellowCard,
        'red': kWeightRedCard,
        'own_goal': kWeightOwnGoal,
      }
    };
  }

  static void _calculateGlobalAndAdvancedStats(
    List<dynamic> allHistory, 
    Map<String, Map<String, dynamic>> sitePlayers,
    Map<String, Map<String, dynamic>> playersMap,
    List<dynamic> seasonsConfig
  ) {
    // Aqui fazemos uma varredura parecida com a do player_detail.dart
    // Mas para TODOS os jogadores de uma vez para otimização
    
    // Auxiliares por jogador
    Map<String, Map<String, int>> assistsGiven = {};
    Map<String, Map<String, int>> assistsReceived = {};
    Map<String, Map<String, int>> gamesWith = {};
    Map<String, Map<String, int>> winsWith = {};
    Map<String, Map<String, int>> lossesWith = {};
    Map<String, Map<String, int>> gamesAgainst = {};
    Map<String, Map<String, int>> winsAgainst = {};
    Map<String, Map<String, int>> lossesAgainst = {};
    Map<String, Map<String, int>> drawsAgainst = {};
    
    // Helpers for Temporada Logic
    String getSeasonInfo(String dateStr, {required bool returnParentId}) {
      if (dateStr.isEmpty) return 'unknown';
      try {
        DateTime dt = DateTime.parse(dateStr);
        for (var season in seasonsConfig) {
          if (season['startDate'] == null || season['endDate'] == null) continue;
          DateTime start = DateTime.parse(season['startDate']);
          DateTime end = DateTime.parse(season['endDate']).add(const Duration(days: 1));
          if (dt.isAfter(start.subtract(const Duration(seconds: 1))) && dt.isBefore(end)) {
            if (returnParentId) {
              return (season['isPreSeason'] == true && season['parentSeasonId'] != null)
                  ? season['parentSeasonId']
                  : season['id'];
            } else {
              return season['isPreSeason'] == true ? 'pre' : 'main';
            }
          }
        }
      } catch (_) {}
      return 'unknown';
    }

    String currentTemporada = '';
    Map<String, double> currentEmaRatings = {};

    for (final match in allHistory) {
      if (match is! Map) continue;
      
      String sessionDate = match['session_date'] ?? match['date'] ?? '';
      String tId = getSeasonInfo(sessionDate, returnParentId: true);
      String seasonType = getSeasonInfo(sessionDate, returnParentId: false); // 'main' or 'pre'
      String rawSeasonId = getSeasonInfo(sessionDate, returnParentId: false); // We can just use tId and seasonType
      
      if (tId != currentTemporada) {
        currentTemporada = tId;
        currentEmaRatings.clear();
      }

      final int scoreRed = match['scoreRed'] ?? 0;
      final int scoreWhite = match['scoreWhite'] ?? 0;
      
      final List<dynamic> redField = List<dynamic>.from(match['players']?['red'] ?? []);
      final dynamic gkRed = match['players']?['gk_red'];
      final List<dynamic> redPlayers = [...redField, gkRed].where((p) => p != null).toList();
      
      final List<dynamic> whiteField = List<dynamic>.from(match['players']?['white'] ?? []);
      final dynamic gkWhite = match['players']?['gk_white'];
      final List<dynamic> whitePlayers = [...whiteField, gkWhite].where((p) => p != null).toList();
      
      // Calculate Team Averages for Elo-lite
      double redSum = 0; int redCount = 0;
      for (var p in redPlayers) {
        String pid = playerIdFromObject(p);
        if (pid.isNotEmpty) {
          redSum += currentEmaRatings[pid] ?? kRatingBase;
          redCount++;
        }
      }
      double redAvg = redCount > 0 ? redSum / redCount : kRatingBase;

      double whiteSum = 0; int whiteCount = 0;
      for (var p in whitePlayers) {
        String pid = playerIdFromObject(p);
        if (pid.isNotEmpty) {
          whiteSum += currentEmaRatings[pid] ?? kRatingBase;
          whiteCount++;
        }
      }
      double whiteAvg = whiteCount > 0 ? whiteSum / whiteCount : kRatingBase;

      final int redStatus = scoreRed > scoreWhite ? 1 : (scoreRed == scoreWhite ? 0 : -1);
      final int whiteStatus = scoreWhite > scoreRed ? 1 : (scoreRed == scoreWhite ? 0 : -1);

      Map<String, Map<String, int>> matchPlayerEvents = {};
      if (match['events'] != null) {
        for (final ev in match['events']) {
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
          
          // Assists networks
          if (type == 'goal' && pid.isNotEmpty && astId.isNotEmpty && pid != astId) {
            assistsReceived.putIfAbsent(pid, () => {});
            assistsReceived[pid]![astId] = (assistsReceived[pid]![astId] ?? 0) + 1;
            
            assistsGiven.putIfAbsent(astId, () => {});
            assistsGiven[astId]![pid] = (assistsGiven[astId]![pid] ?? 0) + 1;
          }
        }
      }

      Set<String> processedThisMatch = {};

      void processPlayer(dynamic pObj, int status, int scored, int conceded, List<dynamic> teammates, List<dynamic> opponents, {bool isGk = false, required double teamAvg, required double oppAvg}) {
        String pId = playerIdFromObject(pObj);
        if (pId.isEmpty || processedThisMatch.contains(pId)) return;
        processedThisMatch.add(pId);

        sitePlayers.putIfAbsent(pId, () => {
          'id': pId,
          'name': playersMap[pId]?['name'] ?? (pObj['name'] ?? ''),
          'icon': playersMap[pId]?['icon'] ?? '',
          'games': 0, 'wins': 0, 'draws': 0, 'losses': 0,
          'goals': 0, 'assists': 0, 'yellow': 0, 'red': 0, 'own_goals': 0,
          'clean_sheets': 0, 'hat_tricks': 0, 'total_team_goals': 0,
          'biggest_win_margin': 0, 'biggest_win_score': '-',
          'biggest_loss_margin': 0, 'biggest_loss_score': '-',
          'current_unbeaten': 0, 'max_unbeaten': 0,
          'gk_stats': {'games': 0, 'wins': 0, 'goals_conceded': 0, 'clean_sheets': 0},
          'ratings': <double>[],
          'session_chart_data': <String, List<double>>{}, // date -> ratings
          'season_stats': <String, dynamic>{}, // tId -> stats
        });

        var stats = sitePlayers[pId]!;
        stats['games'] = (stats['games'] as int) + 1;
        stats['total_team_goals'] = (stats['total_team_goals'] as int) + scored;

        if (status == 1) {
          stats['wins'] = (stats['wins'] as int) + 1;
          int margin = scored - conceded;
          if (margin > (stats['biggest_win_margin'] as int)) {
            stats['biggest_win_margin'] = margin;
            stats['biggest_win_score'] = "$scored x $conceded";
          }
        } else if (status == -1) {
          stats['losses'] = (stats['losses'] as int) + 1;
          int margin = conceded - scored;
          if (margin > (stats['biggest_loss_margin'] as int)) {
            stats['biggest_loss_margin'] = margin;
            stats['biggest_loss_score'] = "$conceded x $scored";
          }
        } else {
          stats['draws'] = (stats['draws'] as int) + 1;
        }

        if (conceded == 0) stats['clean_sheets'] = (stats['clean_sheets'] as int) + 1;

        if (status >= 0) {
          stats['current_unbeaten'] = (stats['current_unbeaten'] as int) + 1;
          if ((stats['current_unbeaten'] as int) > (stats['max_unbeaten'] as int)) {
            stats['max_unbeaten'] = stats['current_unbeaten'];
          }
        } else {
          stats['current_unbeaten'] = 0;
        }

        if (isGk) {
          var gkStats = stats['gk_stats'] as Map<String, dynamic>;
          gkStats['games'] = (gkStats['games'] as int) + 1;
          if (status == 1) gkStats['wins'] = (gkStats['wins'] as int) + 1;
          gkStats['goals_conceded'] = (gkStats['goals_conceded'] as int) + conceded;
          if (conceded == 0) gkStats['clean_sheets'] = (gkStats['clean_sheets'] as int) + 1;
        }

        int g = matchPlayerEvents[pId]?['g'] ?? 0;
        int a = matchPlayerEvents[pId]?['a'] ?? 0;
        int og = matchPlayerEvents[pId]?['og'] ?? 0;
        int yc = matchPlayerEvents[pId]?['yc'] ?? 0;
        int rc = matchPlayerEvents[pId]?['rc'] ?? 0;

        stats['goals'] = (stats['goals'] as int) + g;
        stats['assists'] = (stats['assists'] as int) + a;
        stats['own_goals'] = (stats['own_goals'] as int) + og;
        stats['yellow'] = (stats['yellow'] as int) + yc;
        stats['red'] = (stats['red'] as int) + rc;

        if (g >= 3) stats['hat_tricks'] = (stats['hat_tricks'] as int) + 1;

        double matchRating = calculateMatchRating(
          status: status, goals: g, assists: a, ownGoals: og, 
          teamGoals: scored, conceded: conceded, yellow: yc, red: rc, teamWinStreak: 0,
          teamAvgRating: teamAvg, opponentAvgRating: oppAvg
        );
        (stats['ratings'] as List<double>).add(matchRating);
        
        // Update EMA for current Temporada
        double currentEma = currentEmaRatings[pId] ?? kRatingBase;
        if (!currentEmaRatings.containsKey(pId)) {
          currentEmaRatings[pId] = (matchRating * 0.5) + (kRatingBase * 0.5);
        } else {
          currentEmaRatings[pId] = (matchRating * 0.35) + (currentEma * 0.65);
        }
        // Save current EMA as active rating for the frontend
        stats['active_temporada_rating'] = currentEmaRatings[pId];

        // Season Specific Stats (Temporada)
        if (tId != 'unknown') {
          stats['season_stats'].putIfAbsent(tId, () => {
             'temporada_id': tId,
             'games': 0, 'wins': 0, 'goals': 0, 'assists': 0,
             'main_season_games': 0, 'main_season_wins': 0, 'main_season_goals': 0, 'main_season_assists': 0,
          });
          var sStats = stats['season_stats'][tId];
          sStats['games'] += 1;
          sStats['goals'] += g;
          sStats['assists'] += a;
          if (status == 1) sStats['wins'] += 1;

          if (seasonType == 'main') {
            sStats['main_season_games'] += 1;
            sStats['main_season_goals'] += g;
            sStats['main_season_assists'] += a;
            if (status == 1) sStats['main_season_wins'] += 1;
          }
        }
        
        // Chart Data group by session/date
        String sessionDate = match['session_date'] ?? match['date'] ?? '';
        if (sessionDate.isNotEmpty) {
           DateTime dt = DateTime.parse(sessionDate);
           String dtKey = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
           stats['session_chart_data'].putIfAbsent(dtKey, () => <double>[]);
           stats['session_chart_data'][dtKey].add(matchRating);
        }

        // Relacionamentos
        for (var t in teammates) {
          String tId = playerIdFromObject(t);
          if (tId.isEmpty || tId == pId) continue;
          gamesWith.putIfAbsent(pId, () => {})[tId] = (gamesWith[pId]![tId] ?? 0) + 1;
          if (status == 1) winsWith.putIfAbsent(pId, () => {})[tId] = (winsWith[pId]![tId] ?? 0) + 1;
          if (status == -1) lossesWith.putIfAbsent(pId, () => {})[tId] = (lossesWith[pId]![tId] ?? 0) + 1;
        }

        for (var o in opponents) {
          String oId = playerIdFromObject(o);
          if (oId.isEmpty || oId == pId) continue;
          gamesAgainst.putIfAbsent(pId, () => {})[oId] = (gamesAgainst[pId]![oId] ?? 0) + 1;
          if (status == 1) winsAgainst.putIfAbsent(pId, () => {})[oId] = (winsAgainst[pId]![oId] ?? 0) + 1;
          if (status == -1) lossesAgainst.putIfAbsent(pId, () => {})[oId] = (lossesAgainst[pId]![oId] ?? 0) + 1;
          if (status == 0) drawsAgainst.putIfAbsent(pId, () => {})[oId] = (drawsAgainst[pId]![oId] ?? 0) + 1;
        }
      }

      for (var p in redField) if (p != null) processPlayer(p, redStatus, scoreRed, scoreWhite, redPlayers, whitePlayers, isGk: false, teamAvg: redAvg, oppAvg: whiteAvg);
      if (gkRed != null) processPlayer(gkRed, redStatus, scoreRed, scoreWhite, redPlayers, whitePlayers, isGk: true, teamAvg: redAvg, oppAvg: whiteAvg);

      for (var p in whiteField) if (p != null) processPlayer(p, whiteStatus, scoreWhite, scoreRed, whitePlayers, redPlayers, isGk: false, teamAvg: whiteAvg, oppAvg: redAvg);
      if (gkWhite != null) processPlayer(gkWhite, whiteStatus, scoreWhite, scoreRed, whitePlayers, redPlayers, isGk: true, teamAvg: whiteAvg, oppAvg: redAvg);
    }

    // Helper para achar maior num mapa de contagem
    Map<String, dynamic> findMax(Map<String, int>? map, {Map<String, int>? ratioBaseMap, int minBase = 0}) {
      if (map == null || map.isEmpty) return {'name': '-', 'count': 0};
      
      var candidates = map.entries.where((e) {
        if (ratioBaseMap == null) return e.value > 0;
        return (ratioBaseMap[e.key] ?? 0) >= minBase && e.value > 0;
      }).toList();
      
      if (candidates.isEmpty) return {'name': '-', 'count': 0};
      
      candidates.sort((a, b) {
        if (ratioBaseMap != null) {
          double rA = a.value / ratioBaseMap[a.key]!;
          double rB = b.value / ratioBaseMap[b.key]!;
          if (rB != rA) return rB.compareTo(rA);
          return ratioBaseMap[b.key]!.compareTo(ratioBaseMap[a.key]!);
        }
        return b.value.compareTo(a.value);
      });
      
      String topId = candidates.first.key;
      String name = sitePlayers[topId]?['name'] ?? playersMap[topId]?['name'] ?? 'Desconhecido';
      return {
        'id': topId,
        'name': name,
        'count': candidates.first.value,
        'base': ratioBaseMap?[topId] ?? 0,
      };
    }

    // Finalizar cálculos para cada jogador
    sitePlayers.forEach((id, stats) {
      stats['nota'] = calculateFinalRating(ratings: stats['ratings'] as List<double>);
      stats['ga'] = (stats['goals'] as int) + (stats['assists'] as int);
      
      // Construir Advanced Stats para exportar no JSON
      stats['advanced'] = {
        'topAssisted': findMax(assistsGiven[id]),
        'topAssister': findMax(assistsReceived[id]),
        'mostPlayedWith': findMax(gamesWith[id]),
        'mostWinsWith': findMax(winsWith[id], ratioBaseMap: gamesWith[id], minBase: 5),
        'mostLossesWith': findMax(lossesWith[id], ratioBaseMap: gamesWith[id], minBase: 5),
        'mostPlayedAgainst': findMax(gamesAgainst[id]),
        'mostWinsAgainst': findMax(winsAgainst[id], ratioBaseMap: gamesAgainst[id], minBase: 5),
        'mostLossesAgainst': findMax(lossesAgainst[id], ratioBaseMap: gamesAgainst[id], minBase: 5),
        'mostDrawsAgainst': findMax(drawsAgainst[id]),
      };
      
      // Preparar Chart Data
      List<Map<String, dynamic>> chart = [];
      Map<String, List<double>> sessData = stats['session_chart_data'];
      sessData.forEach((date, rList) {
        double avg = rList.fold(0.0, (a, b) => a + b) / rList.length;
        chart.add({'date': date, 'nota': avg});
      });
      chart.sort((a, b) => a['date'].compareTo(b['date']));
      stats['evolution_chart'] = chart;
      
      // Limpar campos pesados ou não necessários no JSON final
      stats.remove('session_chart_data');
      stats.remove('ratings');
    });
  }
}
