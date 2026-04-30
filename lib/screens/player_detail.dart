import 'dart:convert';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/player_identity.dart';
import '../utils/rating_calculator.dart';
import '../utils/stats_calculator.dart';
import '../widgets/shared/icon_picker_modal.dart';
import 'player_comparison_screen.dart';

class PlayerDetailScreen extends StatefulWidget {
  final String groupId;
  final String playerId;
  final String? initialPlayerName;
  final String? playerIcon;
  final String? tournamentId;

  const PlayerDetailScreen({
    super.key,
    required this.groupId,
    required this.playerId,
    this.initialPlayerName,
    this.playerIcon,
    this.tournamentId,
  });

  @override
  State<PlayerDetailScreen> createState() => _PlayerDetailScreenState();
}

class _PlayerDetailScreenState extends State<PlayerDetailScreen> {
  bool isLoading = true;
  int? rankPosition;
  int totalPlayers = 0;
  String playerName = '';
  String? resolvedIcon;

  // ── Gráfico ──────────────────────────────────────────────────
  List<dynamic> _allHistory = [];
  String _chartMetric = 'Nota';
  String _chartPeriod = 'Sessão';
  List<Map<String, dynamic>> _chartData = [];

  Map<String, dynamic> playerStats = {
    'name': '', 'goals': 0, 'assists': 0, 'ga': 0, 'games': 0,
    'wins': 0, 'draws': 0, 'losses': 0, 'nota': kRatingBase,
    'yellow': 0, 'red': 0,
  };

  Map<String, dynamic> advancedStats = {};
  List<Map<String, dynamic>> manualBadges = [];
  List<Map<String, dynamic>> _allPlayers = [];



  @override
  void initState() {
    super.initState();
    _loadPlayerDetails();
  }

  // ─────────────────────────────────────────────────────────────
  // CARREGAMENTO PRINCIPAL
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadPlayerDetails() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load all players to find specific player and check taken icons
    final String playersKey = 'players_${widget.groupId}';
    List<Map<String, dynamic>> players = [];
    if (prefs.containsKey(playersKey)) {
      players = ensurePlayerIds(List<Map<String, dynamic>>.from(jsonDecode(prefs.getString(playersKey)!)));
    }
    
    final Map<String, dynamic>? player = players.firstWhere(
      (p) => (p['id'] ?? '').toString() == widget.playerId,
      orElse: () => {},
    );
    
    final String? icon = widget.playerIcon ?? player?['icon'] as String?;
    final String resolvedName = (player?['name'] ?? widget.initialPlayerName ?? '').toString();

    if (player?['manual_badges'] != null) {
      manualBadges = List<Map<String, dynamic>>.from(player!['manual_badges']);
    }

    final List<dynamic> allHistory = await getAllGroupMatches(widget.groupId);
    final globalStats = calculateGlobalStats(allHistory);

    final List<Map<String, dynamic>> leaderboard = globalStats.values
        .where((data) => (data['games'] as int) >= kMinGamesForGlobalRanking)
        .toList();
    leaderboard.sort((a, b) => (b['nota'] as double).compareTo(a['nota'] as double));

    final int index = leaderboard.indexWhere((p) => (p['id'] as String) == widget.playerId);
    final Map<String, dynamic> advStats = _calculateAdvancedStats(allHistory);

    setState(() {
      _allHistory  = allHistory;
      _allPlayers  = players;
      resolvedIcon = icon;
      playerName   = resolvedName;
      totalPlayers = leaderboard.length;
      advancedStats = advStats;

      if (index >= 0) {
        rankPosition = index + 1;
        playerStats  = leaderboard[index];
      } else {
        if (globalStats.containsKey(widget.playerId)) {
          playerStats = globalStats[widget.playerId]!;
        } else {
          playerStats['id']   = widget.playerId;
          playerStats['name'] = resolvedName;
          playerStats['nota'] = kRatingBase;
        }
      }
    });

    _calculateChartData();
    setState(() => isLoading = false);
  }

  // ─────────────────────────────────────────────────────────────
  // CÁLCULO DOS DADOS DO GRÁFICO
  // ─────────────────────────────────────────────────────────────

  void _calculateChartData() {
    if (_allHistory.isEmpty) return;

    final String myId = widget.playerId;
    final Map<String, Map<String, dynamic>> grouped = {};

    for (final match in _allHistory) {
      final List<dynamic> redPlayers = [
        ...(match['players']['red'] ?? []),
        match['players']['gk_red'],
      ].where((p) => p != null).toList();

      final List<dynamic> whitePlayers = [
        ...(match['players']['white'] ?? []),
        match['players']['gk_white'],
      ].where((p) => p != null).toList();

      final bool inRed   = redPlayers.any((p)   => playerIdFromObject(p) == myId);
      final bool inWhite = whitePlayers.any((p) => playerIdFromObject(p) == myId);
      if (!inRed && !inWhite) continue;

      final String myTeam  = inRed ? 'red' : 'white';
      final int scoreRed   = match['scoreRed']   ?? 0;
      final int scoreWhite = match['scoreWhite'] ?? 0;
      final int conceded   = inRed ? scoreWhite : scoreRed;
      final int scored     = inRed ? scoreRed : scoreWhite;

      int myTeamResult = 0;
      if (scoreRed != scoreWhite) {
        myTeamResult = (myTeam == 'red' && scoreRed > scoreWhite) ||
                (myTeam == 'white' && scoreWhite > scoreRed)
            ? 1
            : -1;
      }

      // Chave de agrupamento (sessão ou mês)
      final String rawDate = match['session_date'] ?? match['date'] ?? DateTime.now().toIso8601String();
      final DateTime dt   = DateTime.parse(rawDate);
      final String groupKey = _chartPeriod == 'Mês'
          ? '${dt.month.toString().padLeft(2, '0')}/${dt.year.toString().substring(2)}'
          : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';

      grouped.putIfAbsent(groupKey, () => {
        'goals': 0, 'assists': 0, 'own_goals': 0, 'games': 0,
        'yellow': 0, 'red': 0,
        'wins': 0, 'draws': 0, 'losses': 0,
        'goals_conceded': 0, 'ratings': <double>[], 'date': dt,
      });

      grouped[groupKey]!['games']         += 1;
      grouped[groupKey]!['goals_conceded'] += conceded;

      if (myTeamResult == 1)       grouped[groupKey]!['wins']   += 1;
      else if (myTeamResult == -1) grouped[groupKey]!['losses'] += 1;
      else                         grouped[groupKey]!['draws']  += 1;

      int g = 0, a = 0, og = 0, yc = 0, rc = 0;
      if (match['events'] != null) {
        for (final ev in match['events']) {
          final String scorerId = eventPlayerId(ev, 'player');
          final String assistId = eventPlayerId(ev, 'assist');
          if (ev['type'] == 'goal') {
            if (scorerId == myId) g++;
            if (assistId == myId) a++;
          } else if (ev['type'] == 'own_goal'    && scorerId == myId) og++;
          else if   (ev['type'] == 'yellow_card'  && scorerId == myId) yc++;
          else if   (ev['type'] == 'red_card'     && scorerId == myId) rc++;
        }
      }

      grouped[groupKey]!['goals']   += g;
      grouped[groupKey]!['assists'] += a;
      grouped[groupKey]!['own_goals'] += og;
      grouped[groupKey]!['yellow']  += yc;
      grouped[groupKey]!['red']     += rc;

      final double matchRating = calculateMatchRating(
        status: myTeamResult, goals: g, assists: a,
        ownGoals: og, teamGoals: scored, conceded: conceded, yellow: yc, red: rc,
        teamWinStreak: 0,
      );
      (grouped[groupKey]!['ratings'] as List<double>).add(matchRating);
    }

    final List<Map<String, dynamic>> chartList = [];
    grouped.forEach((key, data) {
      final int games         = data['games'] as int;
      final double avgNota    = calculateFinalRating(ratings: data['ratings'] as List<double>);

      chartList.add({
        'label':        key,
        'date':         data['date'],
        'Nota':         avgNota,
        'Gols':         data['goals'],
        'Assistências': data['assists'],
        'G+A':          (data['goals'] as int) + (data['assists'] as int),
      });
    });

    chartList.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    setState(() { _chartData = chartList; });
  }

  // ─────────────────────────────────────────────────────────────
  // ESTATÍSTICAS AVANÇADAS
  // ─────────────────────────────────────────────────────────────

  Map<String, dynamic> _calculateAdvancedStats(List<dynamic> allHistory) {
    final Map<String, int> assistsGiven     = {};
    final Map<String, int> assistsReceived  = {};
    final Map<String, int> gamesWith        = {};
    final Map<String, int> winsWith         = {};
    final Map<String, int> lossesWith       = {};
    final Map<String, int> winsAgainst      = {};
    final Map<String, int> lossesAgainst    = {};
    final Map<String, int> drawsAgainst     = {};
    int hatTricks = 0;
    int cleanSheets = 0;
    int ownGoals = 0;
    int currentUnbeatenStreak = 0;
    int maxUnbeatenStreak = 0;
    int biggestWinMargin = 0;
    String biggestWinScore = "-";
    int biggestLossMargin = 0;
    String biggestLossScore = "-";

    final Map<String, String> playerNamesMap = {};
    final String myId = widget.playerId;

    final List<dynamic> sortedHistory = List.from(allHistory);
    sortedHistory.sort((a, b) {
      DateTime da = DateTime.tryParse(a['date'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      DateTime db = DateTime.tryParse(b['date'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return da.compareTo(db);
    });

    for (final match in sortedHistory) {
      final List<dynamic> redPlayers = [
        ...(match['players']['red'] ?? []),
        match['players']['gk_red'],
      ].where((p) => p != null).toList();

      final List<dynamic> whitePlayers = [
        ...(match['players']['white'] ?? []),
        match['players']['gk_white'],
      ].where((p) => p != null).toList();

      void registerName(dynamic p) {
        final String id = playerIdFromObject(p);
        if (id.isNotEmpty && !playerNamesMap.containsKey(id)) {
          playerNamesMap[id] = (p['name'] ?? '').toString();
        }
      }
      redPlayers.forEach(registerName);
      whitePlayers.forEach(registerName);

      final bool inRed   = redPlayers.any((p)   => playerIdFromObject(p) == myId);
      final bool inWhite = whitePlayers.any((p) => playerIdFromObject(p) == myId);
      if (!inRed && !inWhite) continue;

      final String myTeam = inRed ? 'red' : 'white';
      final int scoreRed   = match['scoreRed']   ?? 0;
      final int scoreWhite = match['scoreWhite'] ?? 0;

      int myTeamResult = 0;
      int myTeamGoals = myTeam == 'red' ? scoreRed : scoreWhite;
      int opponentGoals = myTeam == 'red' ? scoreWhite : scoreRed;
      
      if (myTeamGoals > opponentGoals) myTeamResult = 1;
      else if (myTeamGoals < opponentGoals) myTeamResult = -1;

      if (opponentGoals == 0) cleanSheets++;

      if (myTeamResult == 1) {
        int margin = myTeamGoals - opponentGoals;
        if (margin > biggestWinMargin) {
          biggestWinMargin = margin;
          biggestWinScore = "$myTeamGoals x $opponentGoals";
        }
      }

      if (myTeamResult == -1) {
        int margin = opponentGoals - myTeamGoals;
        if (margin > biggestLossMargin) {
          biggestLossMargin = margin;
          biggestLossScore = "$opponentGoals x $myTeamGoals";
        }
      }

      if (myTeamResult >= 0) {
        currentUnbeatenStreak++;
        if (currentUnbeatenStreak > maxUnbeatenStreak) maxUnbeatenStreak = currentUnbeatenStreak;
      } else {
        currentUnbeatenStreak = 0;
      }

      final List<dynamic> teammates = myTeam == 'red' ? redPlayers  : whitePlayers;
      final List<dynamic> opponents = myTeam == 'red' ? whitePlayers : redPlayers;

      for (final t in teammates) {
        final String tId = playerIdFromObject(t);
        if (tId == myId || tId.isEmpty) continue;
        gamesWith[tId]  = (gamesWith[tId]  ?? 0) + 1;
        if (myTeamResult ==  1) winsWith[tId]   = (winsWith[tId]   ?? 0) + 1;
        if (myTeamResult == -1) lossesWith[tId] = (lossesWith[tId] ?? 0) + 1;
      }

      for (final o in opponents) {
        final String oId = playerIdFromObject(o);
        if (oId == myId || oId.isEmpty) continue;
        if (myTeamResult ==  1) winsAgainst[oId]   = (winsAgainst[oId]   ?? 0) + 1;
        if (myTeamResult == -1) lossesAgainst[oId] = (lossesAgainst[oId] ?? 0) + 1;
        if (myTeamResult ==  0) drawsAgainst[oId]  = (drawsAgainst[oId]  ?? 0) + 1;
      }

      int goalsInThisMatch = 0;
      if (match['events'] != null) {
        for (final ev in match['events']) {
          if (ev['type'] == 'own_goal' && eventPlayerId(ev, 'player') == myId) {
             ownGoals++;
          }
          if (ev['type'] != 'goal') continue;
          final String scorerId = eventPlayerId(ev, 'player');
          final String assistId = eventPlayerId(ev, 'assist');
          if (scorerId == myId) {
            goalsInThisMatch++;
            if (assistId.isNotEmpty && assistId != myId) {
              assistsReceived[assistId] = (assistsReceived[assistId] ?? 0) + 1;
            }
          }
          if (assistId == myId && scorerId != myId && scorerId.isNotEmpty) {
            assistsGiven[scorerId] = (assistsGiven[scorerId] ?? 0) + 1;
          }
        }
      }
      if (goalsInThisMatch >= 3) hatTricks++;
    }

    Map<String, dynamic> findMax(Map<String, int> map) {
      if (map.isEmpty) return {'name': '-', 'count': 0};
      final entries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final String topId = entries.first.key;
      return {'name': playerNamesMap[topId] ?? 'Desconhecido', 'count': entries.first.value};
    }

    return {
      'topAssisted':       findMax(assistsGiven),
      'topAssister':       findMax(assistsReceived),
      'mostPlayedWith':    findMax(gamesWith),
      'mostWinsWith':      findMax(winsWith),
      'mostLossesWith':    findMax(lossesWith),
      'mostWinsAgainst':   findMax(winsAgainst),
      'mostLossesAgainst': findMax(lossesAgainst),
      'mostDrawsAgainst':  findMax(drawsAgainst),
      'hatTricks':         hatTricks,
      'cleanSheets':       cleanSheets,
      'ownGoals':          ownGoals,
      'biggestWinScore':   biggestWinScore,
      'biggestLossScore':  biggestLossScore,
      'maxUnbeatenStreak': maxUnbeatenStreak,
    };
  }

  // ─────────────────────────────────────────────────────────────
  // PERSISTÊNCIA
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _loadPlayer(SharedPreferences prefs) async {
    final String playersKey = 'players_${widget.groupId}';
    if (!prefs.containsKey(playersKey)) return null;
    final List<Map<String, dynamic>> players =
        ensurePlayerIds(List<Map<String, dynamic>>.from(jsonDecode(prefs.getString(playersKey)!)));
    for (final player in players) {
      if ((player['id'] ?? '').toString() == widget.playerId) return player;
    }
    return null;
  }

  Future<void> _savePlayerName(String newName) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = 'players_${widget.groupId}';
    if (!prefs.containsKey(key)) return;
    final players = ensurePlayerIds(List<Map<String, dynamic>>.from(jsonDecode(prefs.getString(key)!)));
    final int index = players.indexWhere((p) => (p['id'] ?? '').toString() == widget.playerId);
    if (index == -1) return;
    players[index]['name'] = newName;
    await prefs.setString(key, jsonEncode(players));
    setState(() { playerName = newName; playerStats['name'] = newName; });
  }

  Future<void> _savePlayerIcon(String iconPath) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = 'players_${widget.groupId}';
    if (!prefs.containsKey(key)) return;
    final players = ensurePlayerIds(List<Map<String, dynamic>>.from(jsonDecode(prefs.getString(key)!)));
    final int index = players.indexWhere((p) => (p['id'] ?? '').toString() == widget.playerId);
    if (index == -1) return;
    players[index]['icon'] = iconPath;
    await prefs.setString(key, jsonEncode(players));
    setState(() { 
      resolvedIcon = iconPath; 
      _allPlayers = players; // Update stored list for takenIcons logic
    });
  }

  Future<void> _saveManualBadge(String icon, String title) async {
    final prefs = await SharedPreferences.getInstance();
    final String playersKey = 'players_${widget.groupId}';
    if (!prefs.containsKey(playersKey)) return;

    final List<Map<String, dynamic>> loadedPlayers =
        List<Map<String, dynamic>>.from(jsonDecode(prefs.getString(playersKey)!));
    final int index = loadedPlayers.indexWhere((p) => (p['id'] ?? '').toString() == widget.playerId);

    if (index != -1) {
      loadedPlayers[index]['manual_badges'] ??= [];
      loadedPlayers[index]['manual_badges'].add({'icon': icon, 'title': title});
      await prefs.setString(playersKey, jsonEncode(loadedPlayers));
      setState(() { manualBadges.add({'icon': icon, 'title': title}); });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BADGES AUTOMÁTICOS
  // ─────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _generateAutomaticBadges() {
    final int games    = playerStats['games']   ?? 0;
    final int goals    = playerStats['goals']   ?? 0;
    final int assists  = playerStats['assists'] ?? 0;
    final int yellow   = playerStats['yellow']  ?? 0;
    final int red      = playerStats['red']     ?? 0;
    final int wins     = playerStats['wins']    ?? 0;
    final int hatTricks = advancedStats['hatTricks'] ?? 0;

    final List<Map<String, dynamic>> badges = [];

    if (games >= 50)       badges.add({'icon': '🏟️', 'title': 'Lenda',      'desc': '50+ Jogos',        'color': Colors.amber});
    else if (games >= 20)  badges.add({'icon': '🏃',  'title': 'Veterano',   'desc': '20+ Jogos',        'color': Colors.blueAccent});

    if (goals >= 100)      badges.add({'icon': '👑',  'title': 'Rei do Gol', 'desc': '100+ Gols',        'color': Colors.orangeAccent});
    else if (goals >= 50)  badges.add({'icon': '⚽',  'title': 'Artilheiro', 'desc': '50+ Gols',         'color': Colors.greenAccent});

    if (assists >= 50)     badges.add({'icon': '🎩',  'title': 'Mago',       'desc': '50+ Assist.',      'color': Colors.purpleAccent});
    else if (assists >= 20) badges.add({'icon': '🤝', 'title': 'Garçom',     'desc': '20+ Assist.',      'color': Colors.lightBlue});

    if (yellow + red >= 10) badges.add({'icon': '🔪', 'title': 'Açougueiro', 'desc': '10+ Cartões',      'color': Colors.redAccent});

    if (games >= 20 && wins / games > 0.6)
      badges.add({'icon': '🍀', 'title': 'Talismã', 'desc': '>60% Vitórias', 'color': Colors.green});

    if (hatTricks >= 5)
      badges.add({'icon': '🎭', 'title': 'Dono da Bola', 'desc': '5+ Hat-Tricks', 'color': Colors.yellow});

    return badges;
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS VISUAIS
  // ─────────────────────────────────────────────────────────────

  Color _getRatingColor(double rating) {
    if (rating >= 9.0) return Colors.purpleAccent;
    if (rating >= 8.0) return Colors.green[700]!;
    if (rating >= 7.0) return Colors.green;
    if (rating >= 6.0) return Colors.lightGreenAccent;
    if (rating >= 5.0) return Colors.yellow;
    if (rating >= 4.0) return Colors.orange;
    return Colors.red;
  }

  String _formatAdvStat(dynamic stat, String suffix, {int total = 0}) {
    if (stat == null || stat['count'] == 0) return '-';
    int count = stat['count'];
    if (total > 0) {
      double pct = (count / total) * 100;
      return '${stat['name']} ($count $suffix - ${pct.toStringAsFixed(1)}%)';
    }
    return '${stat['name']} ($count $suffix)';
  }

  // ─────────────────────────────────────────────────────────────
  // DIÁLOGOS
  // ─────────────────────────────────────────────────────────────

  Future<void> _showEditNameDialog() async {
    final controller = TextEditingController(text: playerName);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title:   const Text('Editar jogador', style: TextStyle(color: AppColors.textWhite)),
        content: TextField(
          controller: controller,
          style:      const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Nome', labelStyle: TextStyle(color: Colors.white54)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              await _savePlayerName(newName);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Salvar', style: TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCompareModal() {
    // Filter out the current player
    final List<Map<String, dynamic>> rivals = _allPlayers
        .where((p) => (p['id'] ?? '').toString() != widget.playerId)
        .toList();

    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.deepBlue,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredRivals = rivals.where((r) {
            final name = (r['name'] ?? '').toString().toLowerCase();
            return name.contains(searchQuery.toLowerCase());
          }).toList();

          return FractionallySizedBox(
            heightFactor: 0.8,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Comparar com...', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Selecione um jogador do grupo para iniciar o X1.', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (val) {
                      setModalState(() {
                        searchQuery = val;
                      });
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Pesquisar nome...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: AppColors.headerBlue,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredRivals.length,
                      itemBuilder: (context, index) {
                        final rival = filteredRivals[index];
                        final String rivalId = (rival['id'] ?? '').toString();
                        final String rivalName = (rival['name'] ?? 'Desconhecido').toString();
                        final String? rivalIcon = rival['icon'];
                        final String initial = rivalName.isNotEmpty ? rivalName[0].toUpperCase() : '?';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.headerBlue,
                            radius: 18,
                            child: rivalIcon != null
                                ? ClipOval(child: Padding(padding: const EdgeInsets.all(2), child: Image.asset(rivalIcon, fit: BoxFit.contain)))
                                : Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          title: Text(rivalName, style: const TextStyle(color: Colors.white)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PlayerComparisonScreen(
                                  groupId: widget.groupId,
                                  player1Id: widget.playerId,
                                  player2Id: rivalId,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Future<void> _showAddManualBadgeDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final String key = 'custom_badges_${widget.groupId}';
    List<Map<String, dynamic>> availableCustomBadges = [];

    if (prefs.containsKey(key)) {
      availableCustomBadges = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString(key)!));
    }

    if (availableCustomBadges.isEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: AppColors.headerBlue,
          title:   const Text('Nenhum Troféu Disponível', style: TextStyle(color: Colors.amber)),
          content: const Text(
            "Você precisa criar troféus na 'Fábrica de Troféus' antes de entregá-los.",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK', style: TextStyle(color: Colors.white)))],
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor:  AppColors.deepBlue,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Entregar Prêmio', style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Selecione o troféu que este jogador conquistou:', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: availableCustomBadges.length,
                itemBuilder: (context, i) {
                  final badge = availableCustomBadges[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Image.asset(badge['icon'], errorBuilder: (c, e, s) => const Icon(Icons.emoji_events, color: Colors.amber)),
                      ),
                    ),
                    title:    Text(badge['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(badge['desc'],  style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    onTap:    () { _saveManualBadge(badge['icon'], badge['title']); Navigator.pop(ctx); },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRemoveManualBadgeDialog(int index) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title:   const Text('Remover Prêmio?', style: TextStyle(color: Colors.white)),
        content: const Text('Deseja tirar este prêmio do jogador?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              final String playersKey = 'players_${widget.groupId}';
              final List<Map<String, dynamic>> loadedPlayers =
                  List<Map<String, dynamic>>.from(jsonDecode(prefs.getString(playersKey)!));
              final int pIndex = loadedPlayers.indexWhere((p) => (p['id'] ?? '').toString() == widget.playerId);
              if (pIndex != -1) {
                loadedPlayers[pIndex]['manual_badges'].removeAt(index);
                await prefs.setString(playersKey, jsonEncode(loadedPlayers));
                setState(() { manualBadges.removeAt(index); });
              }
            },
            child: const Text('Remover', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }



  // ─────────────────────────────────────────────────────────────
  // WIDGETS DE CONTEÚDO
  // ─────────────────────────────────────────────────────────────

  Widget _buildEvolutionChart() {
    if (_chartData.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Jogue mais partidas para ver o gráfico.', style: TextStyle(color: Colors.white54))),
      );
    }

    final List<FlSpot> spots = [];
    double maxY = 0;
    double minY = _chartMetric == 'Nota' ? kMaxRating : 0;

    for (int i = 0; i < _chartData.length; i++) {
      final double value = (_chartData[i][_chartMetric] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), value));
      if (value > maxY) maxY = value;
      if (value < minY) minY = value;
    }

    if (_chartMetric == 'Nota') {
      maxY = kMaxRating;
      minY = minY < kMinRating ? minY : kMinRating;
    } else {
      maxY = (maxY + 2).ceilToDouble();
      minY = 0;
    }

    final Color lineColor = _chartMetric == 'Nota'
        ? Colors.amber
        : _chartMetric == 'Gols'
            ? AppColors.textWhite
            : _chartMetric == 'G+A'
                ? AppColors.highlightGreen
                : AppColors.accentBlue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.headerBlue, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho do gráfico
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(children: [
                Icon(Icons.auto_graph, color: AppColors.accentBlue),
                SizedBox(width: 8),
                Text('Evolução', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(color: AppColors.deepBlue, borderRadius: BorderRadius.circular(8)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _chartPeriod,
                    dropdownColor: AppColors.deepBlue,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 16),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    items: ['Sessão', 'Mês']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _chartPeriod = v);
                        _calculateChartData();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Seletor de métrica
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Nota', 'G+A', 'Gols', 'Assistências'].map((metric) {
                final bool isSelected = _chartMetric == metric;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () { setState(() => _chartMetric = metric); _calculateChartData(); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color:  isSelected ? AppColors.accentBlue.withValues(alpha: 0.2) : Colors.transparent,
                        border: Border.all(color: isSelected ? AppColors.accentBlue : Colors.white24),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        metric,
                        style: TextStyle(
                          color:      isSelected ? AppColors.accentBlue : Colors.white54,
                          fontSize:   12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Linha do gráfico
          SizedBox(
            height: 200,
            child: LineChart(LineChartData(
              minY: minY, maxY: maxY, minX: 0, maxX: (spots.length - 1).toDouble(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _chartMetric == 'Nota' ? 2.0 : 1.0,
                getDrawingHorizontalLine: (_) => const FlLine(color: Colors.white10, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, _) => Text(
                      _chartMetric == 'Nota' ? value.toStringAsFixed(1) : value.toInt().toString(),
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: 1,
                    getTitlesWidget: (value, _) {
                      final int i = value.toInt();
                      if (i < 0 || i >= _chartData.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_chartData[i]['label'], style: const TextStyle(color: Colors.white54, fontSize: 9)),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: lineColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 4, color: lineColor,
                      strokeWidth: 1.5, strokeColor: AppColors.headerBlue,
                    ),
                  ),
                  belowBarData: BarAreaData(show: true, color: lineColor.withValues(alpha: 0.15)),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                    return LineTooltipItem(
                      '${_chartData[spot.x.toInt()]['label']}\n',
                      const TextStyle(color: Colors.white70, fontSize: 10),
                      children: [TextSpan(
                        text: _chartMetric == 'Nota'
                            ? spot.y.toStringAsFixed(1)
                            : spot.y.toInt().toString(),
                        style: TextStyle(color: lineColor, fontWeight: FontWeight.bold, fontSize: 14),
                      )],
                    );
                  }).toList(),
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesSection() {
    final List<Map<String, dynamic>> allAutoBadges = _generateAutomaticBadges();
    final List<Map<String, dynamic>> autoBadges = allAutoBadges.take(3).toList();
    final bool hasMoreBadges = allAutoBadges.length > 3;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.headerBlue, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(children: [
                Icon(Icons.emoji_events, color: Colors.amber),
                SizedBox(width: 8),
                Text('Sala de Troféus', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
              Row(
                children: [
                  if (hasMoreBadges)
                    TextButton(
                      onPressed: () => _showAllBadgesModal(allAutoBadges),
                      child: const Text('Ver Todas', style: TextStyle(color: AppColors.accentBlue, fontSize: 12)),
                    ),
                  IconButton(
                    icon:    const Icon(Icons.add_circle_outline, color: AppColors.accentBlue),
                    tooltip: 'Dar Prêmio Manual',
                    onPressed: _showAddManualBadgeDialog,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (autoBadges.isEmpty && manualBadges.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('Nenhuma conquista ainda. Continue jogando!', style: TextStyle(color: Colors.white38))),
            )
          else ...[
            if (manualBadges.isNotEmpty) ...[
              const Text('Prêmios Especiais', style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: manualBadges.length,
                  itemBuilder: (_, i) => SizedBox(width: 85, child: Padding(padding: const EdgeInsets.only(right: 12), child: _buildBadgeCard(manualBadges[i], isManual: true, index: i))),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (autoBadges.isNotEmpty) ...[
              const Text('Conquistas Automáticas', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: autoBadges.length,
                  itemBuilder: (_, i) => SizedBox(width: 85, child: Padding(padding: const EdgeInsets.only(right: 12), child: _buildBadgeCard(autoBadges[i], isManual: false))),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _showAllBadgesModal(List<Map<String, dynamic>> allBadges) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.deepBlue,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Todas as Conquistas', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: allBadges.length,
                itemBuilder: (context, index) => _buildBadgeCard(allBadges[index], isManual: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeCard(Map<String, dynamic> badge, {required bool isManual, int? index}) {
    final Color badgeColor = isManual ? Colors.amber : (badge['color'] as Color? ?? Colors.blueAccent);
    return GestureDetector(
      onLongPress: () { if (isManual && index != null) _showRemoveManualBadgeDialog(index); },
      child: Container(
        decoration: BoxDecoration(
          color:        badgeColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: badgeColor.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isManual)
                SizedBox(
                  height: 35, width: 35,
                  child: Image.asset(badge['icon'], errorBuilder: (_, __, ___) => const Icon(Icons.star, color: Colors.amber)),
                )
              else
                Text(badge['icon'], style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 6),
              Text(
                badge['title'],
                textAlign: TextAlign.center,
                style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (!isManual)
                Text(badge['desc'], style: const TextStyle(color: Colors.white54, fontSize: 8)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statValue(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(children: [
        Text(value, style: TextStyle(color: valueColor, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _resultColumn(String label, int value, Color color) {
    return Expanded(
      child: Column(children: [
        Text('$value', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildAdvStatRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.deepBlue, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                Text(value, style: const TextStyle(color: Colors.white,   fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.deepBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildRadarChart() {
    final int games = playerStats['games'] ?? 0;
    if (games == 0) return const SizedBox();

    final int goals = playerStats['goals'] ?? 0;
    final int assists = playerStats['assists'] ?? 0;
    final int cleanSheets = advancedStats['cleanSheets'] ?? 0;
    final int yellow = playerStats['yellow'] ?? 0;
    final int red = playerStats['red'] ?? 0;
    final int ownGoals = advancedStats['ownGoals'] ?? 0;
    final int wins = playerStats['wins'] ?? 0;
    final int draws = playerStats['draws'] ?? 0;

    double attackScore = (goals / games) * 100;
    if (attackScore > 100) attackScore = 100;

    double visionScore = (assists / games) * 100;
    if (visionScore > 100) visionScore = 100;

    double defenseScore = (cleanSheets / games) * 200;
    if (defenseScore > 100) defenseScore = 100;

    double tacticScore = 100.0 - (yellow * 5) - (red * 20) - (ownGoals * 15);
    if (tacticScore < 0) tacticScore = 0;

    double ganaScore = 0;
    if (games > 0) ganaScore = ((wins * 3 + draws * 1) / (games * 3)) * 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.headerBlue, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(children: [
                Icon(Icons.radar, color: AppColors.accentBlue),
                SizedBox(width: 8),
                Text('Perfil do Jogador', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.white54, size: 20),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.deepBlue,
                      title: const Text('Entenda o Gráfico', style: TextStyle(color: Colors.white, fontSize: 18)),
                      content: const Text(
                        'Ataque: Média de Gols por jogo.\n\n'
                        'Visão: Média de Assistências por jogo.\n\n'
                        'Defesa: Frequência de jogos sem sofrer gol (Clean Sheets).\n\n'
                        'Tática: Cai se o jogador levar muitos cartões ou fizer gols contra.\n\n'
                        'Gana: Taxa de vitórias e empates (Aproveitamento).',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Entendi', style: TextStyle(color: AppColors.accentBlue)),
                        ),
                      ],
                    ),
                  );
                },
              )
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: RadarChart(
              RadarChartData(
                tickCount: 5,
                ticksTextStyle: const TextStyle(color: Colors.transparent),
                tickBorderData: const BorderSide(color: Colors.white12),
                gridBorderData: const BorderSide(color: Colors.white24, width: 1.5),
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                radarBorderData: const BorderSide(color: Colors.transparent),
                getTitle: (index, angle) {
                  final text = ['Ataque', 'Visão', 'Defesa', 'Tática', 'Gana'][index];
                  return RadarChartTitle(
                    text: text,
                    angle: angle,
                  );
                },
                dataSets: [
                  RadarDataSet(
                    fillColor: AppColors.accentBlue.withValues(alpha: 0.4),
                    borderColor: AppColors.accentBlue,
                    entryRadius: 3,
                    dataEntries: [
                      RadarEntry(value: attackScore),
                      RadarEntry(value: visionScore),
                      RadarEntry(value: defenseScore),
                      RadarEntry(value: tacticScore),
                      RadarEntry(value: ganaScore),
                    ],
                  )
                ],
              ),
              swapAnimationDuration: const Duration(milliseconds: 150),
              swapAnimationCurve: Curves.linear,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final int wins      = playerStats['wins']   ?? 0;
    final int draws     = playerStats['draws']  ?? 0;
    final int losses    = playerStats['losses'] ?? 0;
    final int totalResults = wins + draws + losses;
    final double nota   = (playerStats['nota'] ?? kRatingBase) as double;
    final String displayName = playerName.isNotEmpty ? playerName : (widget.initialPlayerName ?? 'Jogador');
    final String initial     = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final Color ratingColor  = _getRatingColor(nota);
    
    final int goals = playerStats['goals'] ?? 0;
    final int assists = playerStats['assists'] ?? 0;

    double aproveitamento = 0;
    if (totalResults > 0) {
      aproveitamento = ((wins * 3 + draws * 1) / (totalResults * 3)) * 100;
    }
    String aproveitamentoStr = totalResults > 0 ? '${aproveitamento.toStringAsFixed(1)}%' : '-';

    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
        centerTitle: true,
        elevation: 0,
        title: Text(displayName, style: const TextStyle(color: AppColors.textWhite)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Cartão do jogador ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.headerBlue,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10, width: 1),
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            final List<String> takenIcons = _allPlayers
                                .map((p) => p['icon'] as String?)
                                .where((icon) => icon != null && icon != resolvedIcon)
                                .cast<String>()
                                .toList();
                            showIconPickerModal(
                              context: context,
                              takenIcons: takenIcons,
                              currentIcon: resolvedIcon,
                              onSelected: (path) => _savePlayerIcon(path),
                            );
                          },
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: AppColors.deepBlue,
                                child: resolvedIcon != null
                                    ? ClipOval(child: Padding(padding: const EdgeInsets.all(6), child: Image.asset(resolvedIcon!, fit: BoxFit.contain)))
                                    : Text(initial, style: const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold, fontSize: 26)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color:        ratingColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border:       Border.all(color: AppColors.headerBlue, width: 2),
                                ),
                                child: Text(nota.toStringAsFixed(1), style: const TextStyle(color: AppColors.headerBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(displayName, style: const TextStyle(color: AppColors.textWhite, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _showEditNameDialog,
                              icon:  const Icon(Icons.edit, size: 16),
                              label: const Text('Editar nome'),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24)),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: _showCompareModal,
                              icon:  const Icon(Icons.compare_arrows, size: 16),
                              label: const Text('Comparar'),
                              style: OutlinedButton.styleFrom(foregroundColor: AppColors.highlightGreen, side: const BorderSide(color: AppColors.highlightGreen)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          rankPosition != null
                              ? 'Ranking Histórico Geral: #$rankPosition / $totalPlayers'
                              : 'Em Avaliação (Estreante)',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  _buildBadgesSection(),

                  const SizedBox(height: 16),
                  _buildEvolutionChart(),

                  const SizedBox(height: 16),

                  // ── Estatísticas ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.headerBlue, borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      children: [
                        Row(children: [
                          _statValue('G+A', '${playerStats['ga'] ?? 0}', AppColors.highlightGreen),
                          _statValue('Gols', '${playerStats['goals'] ?? 0}', AppColors.textWhite),
                          _statValue('Assistências', '${playerStats['assists'] ?? 0}', Colors.amber),
                        ]),
                        const SizedBox(height: 18),
                        Row(children: [
                          _resultColumn('Vitórias', wins,   Colors.greenAccent),
                          _resultColumn('Empates',  draws,  Colors.grey.shade300),
                          _resultColumn('Derrotas', losses, Colors.redAccent),
                        ]),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            height: 14,
                            child: Row(
                              children: totalResults == 0
                                  ? const [
                                      Expanded(child: ColoredBox(color: Color(0x334CAF50))),
                                      Expanded(child: ColoredBox(color: Color(0x33424242))),
                                      Expanded(child: ColoredBox(color: Color(0x33F44336))),
                                    ]
                                  : [
                                      Expanded(flex: wins   == 0 ? 1 : wins,   child: const ColoredBox(color: Colors.green)),
                                      Expanded(flex: draws  == 0 ? 1 : draws,  child: const ColoredBox(color: Colors.black54)),
                                      Expanded(flex: losses == 0 ? 1 : losses, child: const ColoredBox(color: Colors.red)),
                                    ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Estatísticas Avançadas ────────────────────────────
                  _buildRadarChart(),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.headerBlue, borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.psychology, color: AppColors.accentBlue),
                          SizedBox(width: 8),
                          Text('Estatísticas Avançadas', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 16),
                        _buildAdvStatRow('Aproveitamento', aproveitamentoStr, Icons.pie_chart, Colors.purpleAccent),
                        _buildAdvStatRow('Hat-Tricks (3 Gols/Jogo)', '${advancedStats['hatTricks'] ?? 0} marcados', Icons.whatshot, Colors.orangeAccent),
                        _buildAdvStatRow('Faltas Graves', '${playerStats['yellow'] ?? 0} Amarelos / ${playerStats['red'] ?? 0} Vermelhos', Icons.style, Colors.redAccent),
                        _buildAdvStatRow('Clean Sheets', '${advancedStats['cleanSheets'] ?? 0} jogos sem tomar gol', Icons.shield, Colors.blueAccent),
                        _buildAdvStatRow('Gols Contra', '${advancedStats['ownGoals'] ?? 0} marcados', Icons.error_outline, Colors.red),
                        _buildAdvStatRow('Maior Sequência Invicta', '${advancedStats['maxUnbeatenStreak'] ?? 0} jogos', Icons.local_fire_department, Colors.orange),
                        _buildAdvStatRow('Maior Goleada a Favor', '${advancedStats['biggestWinScore'] ?? "-"}', Icons.sentiment_very_satisfied, Colors.greenAccent),
                        _buildAdvStatRow('Maior Derrota', '${advancedStats['biggestLossScore'] ?? "-"}', Icons.sentiment_very_dissatisfied, Colors.redAccent),
                        const Divider(color: Colors.white12, height: 24),
                        const Text('Curiosidades e Rivalidades', style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1.15,
                          children: [
                            _buildGridCard('Garçom Favorito', _formatAdvStat(advancedStats['topAssister'], 'gols seus', total: goals), Icons.handshake, Colors.amber),
                            _buildGridCard('Mais Assistiu', _formatAdvStat(advancedStats['topAssisted'], 'suas assist.', total: assists), Icons.sports_soccer, Colors.greenAccent),
                            _buildGridCard('Mais Jogou Junto', _formatAdvStat(advancedStats['mostPlayedWith'], 'jogos', total: totalResults), Icons.people, Colors.white),
                            _buildGridCard('Mais Venceu Junto', _formatAdvStat(advancedStats['mostWinsWith'], 'vitórias', total: wins), Icons.thumb_up, Colors.green),
                            _buildGridCard('Maior Freguês', _formatAdvStat(advancedStats['mostWinsAgainst'], 'vitórias', total: wins), Icons.mood, Colors.blueAccent),
                            _buildGridCard('Carrasco', _formatAdvStat(advancedStats['mostLossesAgainst'], 'derrotas', total: losses), Icons.mood_bad, Colors.red),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
