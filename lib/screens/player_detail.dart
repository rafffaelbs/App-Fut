import 'dart:convert';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/player_identity.dart';

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

  List<dynamic> _allHistory = [];
  String _chartMetric = 'Nota'; 
  String _chartPeriod = 'Sessão'; 
  List<Map<String, dynamic>> _chartData = [];

  Map<String, dynamic> playerStats = {
    'name': '', 'goals': 0, 'assists': 0, 'ga': 0, 'games': 0,
    'wins': 0, 'draws': 0, 'losses': 0, 'nota': 7.0, 'yellow': 0, 'red': 0,
  };

  Map<String, dynamic> advancedStats = {};
  List<Map<String, dynamic>> manualBadges = [];

  @override
  void initState() {
    super.initState();
    _loadPlayerDetails();
  }

  Future<void> _loadPlayerDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic>? player = await _loadPlayer(prefs);
    final String? icon = widget.playerIcon ?? player?['icon'] as String?;
    final String resolvedName = (player?['name'] ?? widget.initialPlayerName ?? '').toString();

    if (player != null && player['manual_badges'] != null) {
      manualBadges = List<Map<String, dynamic>>.from(player['manual_badges']);
    }

    final String sessionsKey = 'sessions_${widget.groupId}';
    List<dynamic> allHistory = [];

    if (prefs.containsKey(sessionsKey)) {
      final List<dynamic> sessions = jsonDecode(prefs.getString(sessionsKey)!);
      for (var session in sessions) {
        final String? tId = session['id'];
        if (tId != null) {
          final String historyKey = 'match_history_$tId';
          if (prefs.containsKey(historyKey)) {
            allHistory.addAll(jsonDecode(prefs.getString(historyKey)!));
          }
        }
      }
    }

    final List<Map<String, dynamic>> leaderboard = _calculateAllTimeLeaderboard(allHistory);
    final int index = leaderboard.indexWhere((p) => (p['id'] as String) == widget.playerId);
    final Map<String, dynamic> advStats = _calculateAdvancedStats(allHistory);

    setState(() {
      _allHistory = allHistory; 
      resolvedIcon = icon;
      playerName = resolvedName;
      totalPlayers = leaderboard.length;
      advancedStats = advStats;
      if (index >= 0) {
        rankPosition = index + 1;
        playerStats = leaderboard[index];
      } else {
        playerStats['id'] = widget.playerId;
        playerStats['name'] = resolvedName;
        playerStats['nota'] = 7.0;
      }
    });

    _calculateChartData(); 
    setState(() => isLoading = false);
  }

  void _calculateChartData() {
    if (_allHistory.isEmpty) return;
    final myId = widget.playerId;
    Map<String, Map<String, dynamic>> grouped = {};

    for (final match in _allHistory) {
      final List<dynamic> redPlayers = [...(match['players']['red'] ?? []), match['players']['gk_red']].where((p) => p != null).toList();
      final List<dynamic> whitePlayers = [...(match['players']['white'] ?? []), match['players']['gk_white']].where((p) => p != null).toList();
      bool inRed = redPlayers.any((p) => playerIdFromObject(p) == myId);
      bool inWhite = whitePlayers.any((p) => playerIdFromObject(p) == myId);
      if (!inRed && !inWhite) continue;

      String rawDate = match['date'] ?? DateTime.now().toIso8601String();
      DateTime dt = DateTime.parse(rawDate);
      String groupKey;
      if (_chartPeriod == 'Mês') {
        groupKey = "${dt.month.toString().padLeft(2, '0')}/${dt.year.toString().substring(2)}";
      } else {
        groupKey = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}";
      }

      grouped.putIfAbsent(groupKey, () => {'goals': 0, 'assists': 0, 'own_goals': 0, 'games': 0, 'yellow': 0, 'red': 0, 'wins': 0, 'draws': 0, 'losses': 0, 'goals_conceded': 0, 'sum_ratings': 0.0, 'date': dt});

      String myTeam = inRed ? 'red' : 'white';
      int scoreRed = match['scoreRed'] ?? 0;
      int scoreWhite = match['scoreWhite'] ?? 0;
      int goalsConceded = inRed ? scoreWhite : scoreRed;
      
      int myTeamResult = 0;
      if (scoreRed != scoreWhite) {
        myTeamResult = (myTeam == 'red' && scoreRed > scoreWhite) || (myTeam == 'white' && scoreWhite > scoreRed) ? 1 : -1;
      }

      grouped[groupKey]!['games'] += 1;
      grouped[groupKey]!['goals_conceded'] += goalsConceded;
      if (myTeamResult == 1) grouped[groupKey]!['wins'] += 1;
      else if (myTeamResult == -1) grouped[groupKey]!['losses'] += 1;
      else grouped[groupKey]!['draws'] += 1;

      int g=0, a=0, og=0, yc=0, rc=0;
      if (match['events'] != null) {
        for (final ev in match['events']) {
          final String scorerId = eventPlayerId(ev, 'player');
          final String assistId = eventPlayerId(ev, 'assist');
          if (ev['type'] == 'goal') { if (scorerId == myId) g++; if (assistId == myId) a++; }
          else if (ev['type'] == 'own_goal' && scorerId == myId) og++;
          else if (ev['type'] == 'yellow_card' && scorerId == myId) yc++;
          else if (ev['type'] == 'red_card' && scorerId == myId) rc++;
        }
      }

      grouped[groupKey]!['goals'] += g; grouped[groupKey]!['assists'] += a; grouped[groupKey]!['own_goals'] += og;
      grouped[groupKey]!['yellow'] += yc; grouped[groupKey]!['red'] += rc;

      double resultImpact = myTeamResult == 1 ? 0.5 : (myTeamResult == -1 ? -0.5 : 0);
      double attackImpact = (g * 0.8) + (a * 0.4) + (og * -0.7);
      double disciplineImpact = (yc * -0.3) + (rc * -0.8);
      double defenseImpact = (goalsConceded * -0.15);

      double performance = resultImpact + attackImpact + defenseImpact + disciplineImpact;
      double matchRating = 7.0 + (performance * 2.5);
      grouped[groupKey]!['sum_ratings'] += matchRating.clamp(0.0, 10.0);
    }

    List<Map<String, dynamic>> chartList = [];
    grouped.forEach((key, data) {
      int games = data['games'];
      double avgNota = games > 0 ? data['sum_ratings'] / games : 7.0;
      chartList.add({'label': key, 'date': data['date'], 'Nota': avgNota, 'Gols': data['goals'], 'Assistências': data['assists'], 'G+A': data['goals'] + data['assists']});
    });

    chartList.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    setState(() { _chartData = chartList; });
  }

  Map<String, dynamic> _calculateAdvancedStats(List<dynamic> allHistory) {
    Map<String, int> assistsGiven = {}; Map<String, int> assistsReceived = {}; Map<String, int> gamesWith = {}; Map<String, int> winsWith = {}; Map<String, int> lossesWith = {}; Map<String, int> winsAgainst = {}; Map<String, int> lossesAgainst = {}; Map<String, int> drawsAgainst = {}; int hatTricks = 0; Map<String, String> playerNamesMap = {}; final String myId = widget.playerId;

    for (final match in allHistory) {
      final List<dynamic> redPlayers = [...(match['players']['red'] ?? []), match['players']['gk_red']].where((p) => p != null).toList();
      final List<dynamic> whitePlayers = [...(match['players']['white'] ?? []), match['players']['gk_white']].where((p) => p != null).toList();

      void registerName(dynamic p) { String id = playerIdFromObject(p); if (id.isNotEmpty && !playerNamesMap.containsKey(id)) playerNamesMap[id] = (p['name'] ?? '').toString(); }
      redPlayers.forEach(registerName); whitePlayers.forEach(registerName);

      bool inRed = redPlayers.any((p) => playerIdFromObject(p) == myId);
      bool inWhite = whitePlayers.any((p) => playerIdFromObject(p) == myId);
      if (!inRed && !inWhite) continue;

      String myTeam = inRed ? 'red' : 'white';
      int scoreRed = match['scoreRed'] ?? 0; int scoreWhite = match['scoreWhite'] ?? 0;
      int myTeamResult = 0;
      if (scoreRed != scoreWhite) myTeamResult = (myTeam == 'red' && scoreRed > scoreWhite) || (myTeam == 'white' && scoreWhite > scoreRed) ? 1 : -1;

      List<dynamic> teammates = myTeam == 'red' ? redPlayers : whitePlayers;
      List<dynamic> opponents = myTeam == 'red' ? whitePlayers : redPlayers;

      for (var t in teammates) { String tId = playerIdFromObject(t); if (tId == myId || tId.isEmpty) continue; gamesWith[tId] = (gamesWith[tId] ?? 0) + 1; if (myTeamResult == 1) winsWith[tId] = (winsWith[tId] ?? 0) + 1; if (myTeamResult == -1) lossesWith[tId] = (lossesWith[tId] ?? 0) + 1; }
      for (var o in opponents) { String oId = playerIdFromObject(o); if (oId == myId || oId.isEmpty) continue; if (myTeamResult == 1) winsAgainst[oId] = (winsAgainst[oId] ?? 0) + 1; if (myTeamResult == -1) lossesAgainst[oId] = (lossesAgainst[oId] ?? 0) + 1; if (myTeamResult == 0) drawsAgainst[oId] = (drawsAgainst[oId] ?? 0) + 1; }

      int goalsInThisMatch = 0;
      if (match['events'] != null) {
        for (var ev in match['events']) {
          if (ev['type'] != 'goal') continue;
          String scorerId = eventPlayerId(ev, 'player'); String assistId = eventPlayerId(ev, 'assist');
          if (scorerId == myId) { goalsInThisMatch++; if (assistId.isNotEmpty && assistId != myId) assistsReceived[assistId] = (assistsReceived[assistId] ?? 0) + 1; }
          if (assistId == myId && scorerId != myId && scorerId.isNotEmpty) assistsGiven[scorerId] = (assistsGiven[scorerId] ?? 0) + 1;
        }
      }
      if (goalsInThisMatch >= 3) hatTricks++;
    }

    Map<String, dynamic> findMax(Map<String, int> map) {
      if (map.isEmpty) return {'name': '-', 'count': 0};
      var entries = map.entries.toList();
      entries.sort((a, b) => b.value.compareTo(a.value));
      return {'name': playerNamesMap[entries.first.key] ?? 'Desconhecido', 'count': entries.first.value};
    }

    return {
      'topAssisted': findMax(assistsGiven), 'topAssister': findMax(assistsReceived),
      'mostPlayedWith': findMax(gamesWith), 'mostWinsWith': findMax(winsWith), 'mostLossesWith': findMax(lossesWith),
      'mostWinsAgainst': findMax(winsAgainst), 'mostLossesAgainst': findMax(lossesAgainst), 'mostDrawsAgainst': findMax(drawsAgainst),
      'hatTricks': hatTricks,
    };
  }

  List<Map<String, dynamic>> _calculateAllTimeLeaderboard(List<dynamic> allHistory) {
    final Map<String, Map<String, dynamic>> stats = {};
    for (final match in allHistory) {
      final int scoreRed = match['scoreRed'] ?? 0; final int scoreWhite = match['scoreWhite'] ?? 0;
      final int redStatus = scoreRed > scoreWhite ? 1 : (scoreRed == scoreWhite ? 0 : -1); final int whiteStatus = scoreWhite > scoreRed ? 1 : (scoreRed == scoreWhite ? 0 : -1);

      Map<String, Map<String, int>> matchPlayerEvents = {};
      if (match['events'] != null) {
        for (var ev in match['events']) {
          String pid = eventPlayerId(ev, 'player'); String astId = eventPlayerId(ev, 'assist'); String type = ev['type'];
          if (pid.isNotEmpty) { matchPlayerEvents.putIfAbsent(pid, () => {'g': 0, 'a': 0, 'og': 0, 'yc': 0, 'rc': 0}); if (type == 'goal') matchPlayerEvents[pid]!['g'] = matchPlayerEvents[pid]!['g']! + 1; if (type == 'own_goal') matchPlayerEvents[pid]!['og'] = matchPlayerEvents[pid]!['og']! + 1; if (type == 'yellow_card') matchPlayerEvents[pid]!['yc'] = matchPlayerEvents[pid]!['yc']! + 1; if (type == 'red_card') matchPlayerEvents[pid]!['rc'] = matchPlayerEvents[pid]!['rc']! + 1; }
          if (astId.isNotEmpty) { matchPlayerEvents.putIfAbsent(astId, () => {'g': 0, 'a': 0, 'og': 0, 'yc': 0, 'rc': 0}); if (type == 'goal') matchPlayerEvents[astId]!['a'] = matchPlayerEvents[astId]!['a']! + 1; }
        }
      }

      final Set<String> processed = {};
      void processPlayer(dynamic playerObj, int status, int conceded) {
        if (playerObj == null) return;
        final String playerId = playerIdFromObject(playerObj);
        if (playerId.isEmpty || processed.contains(playerId)) return;
        processed.add(playerId);

        stats.putIfAbsent(playerId, () => {'id': playerId, 'name': (playerObj['name'] ?? '').toString(), 'goals': 0, 'assists': 0, 'games': 0, 'wins': 0, 'draws': 0, 'losses': 0, 'yellow': 0, 'red': 0, 'sum_ratings': 0.0});
        stats[playerId]!['games'] = (stats[playerId]!['games'] as int) + 1;
        if (status == 1) stats[playerId]!['wins'] = (stats[playerId]!['wins'] as int) + 1; else if (status == -1) stats[playerId]!['losses'] = (stats[playerId]!['losses'] as int) + 1; else stats[playerId]!['draws'] = (stats[playerId]!['draws'] as int) + 1;

        int g = matchPlayerEvents[playerId]?['g'] ?? 0; int a = matchPlayerEvents[playerId]?['a'] ?? 0; int og = matchPlayerEvents[playerId]?['og'] ?? 0; int yc = matchPlayerEvents[playerId]?['yc'] ?? 0; int rc = matchPlayerEvents[playerId]?['rc'] ?? 0;
        stats[playerId]!['goals'] = (stats[playerId]!['goals'] as int) + g; stats[playerId]!['assists'] = (stats[playerId]!['assists'] as int) + a; stats[playerId]!['yellow'] = (stats[playerId]!['yellow'] as int) + yc; stats[playerId]!['red'] = (stats[playerId]!['red'] as int) + rc;

        double resultImpact = status == 1 ? 0.5 : (status == -1 ? -0.5 : 0);
        double attackImpact = (g * 0.8) + (a * 0.4) + (og * -0.7);
        double disciplineImpact = (yc * -0.3) + (rc * -0.8);
        double defenseImpact = (conceded * -0.15);

        double performance = resultImpact + attackImpact + defenseImpact + disciplineImpact;
        double matchRating = 7.0 + (performance * 2.5);
        stats[playerId]!['sum_ratings'] = (stats[playerId]!['sum_ratings'] as double) + matchRating.clamp(0.0, 10.0);
      }

      if (match['players']['red'] != null) for (final p in match['players']['red']) processPlayer(p, redStatus, scoreWhite);
      if (match['players']['white'] != null) for (final p in match['players']['white']) processPlayer(p, whiteStatus, scoreRed);
      if (match['players']['gk_red'] != null) processPlayer(match['players']['gk_red'], redStatus, scoreWhite);
      if (match['players']['gk_white'] != null) processPlayer(match['players']['gk_white'], whiteStatus, scoreRed);
    }

    final List<Map<String, dynamic>> sortedList = [];
    stats.forEach((id, data) {
      final int games = data['games'] as int;
      double sumRatings = data['sum_ratings'] as double;
      if (games >= 5) {
        double bayesianRating = ((5 * 7.0) + sumRatings) / (5 + games);
        double volumeBonus = (games / 10) * 0.1;
        double finalRating = (bayesianRating + volumeBonus).clamp(0.0, 10.0);

        sortedList.add({'id': id, 'name': data['name'], 'goals': data['goals'], 'assists': data['assists'], 'yellow': data['yellow'], 'red': data['red'], 'ga': (data['goals'] as int) + (data['assists'] as int), 'games': games, 'wins': data['wins'], 'draws': data['draws'], 'losses': data['losses'], 'nota': finalRating});
      }
    });

    sortedList.sort((a, b) => (b['nota'] as double).compareTo(a['nota'] as double));
    return sortedList;
  }

  Future<Map<String, dynamic>?> _loadPlayer(SharedPreferences prefs) async {
    final String playersKey = 'players_${widget.groupId}';
    if (!prefs.containsKey(playersKey)) return null;
    final List<Map<String, dynamic>> loaded = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString(playersKey)!));
    final List<Map<String, dynamic>> players = ensurePlayerIds(loaded);
    for (final player in players) if ((player['id'] ?? '').toString() == widget.playerId) return player;
    return null;
  }

  // --- GERADOR AUTOMÁTICO DE BADGES ---
  List<Map<String, dynamic>> _generateAutomaticBadges() {
    List<Map<String, dynamic>> badges = [];
    int games = playerStats['games'] ?? 0; int goals = playerStats['goals'] ?? 0; int assists = playerStats['assists'] ?? 0; int yellow = playerStats['yellow'] ?? 0; int red = playerStats['red'] ?? 0; int wins = playerStats['wins'] ?? 0; int hatTricks = advancedStats['hatTricks'] ?? 0;

    if (games >= 50) badges.add({'icon': '🏟️', 'title': 'Lenda', 'desc': '50+ Jogos', 'color': Colors.amber});
    else if (games >= 20) badges.add({'icon': '🏃', 'title': 'Veterano', 'desc': '20+ Jogos', 'color': Colors.blueAccent});
    if (goals >= 100) badges.add({'icon': '👑', 'title': 'Rei do Gol', 'desc': '100+ Gols', 'color': Colors.orangeAccent});
    else if (goals >= 50) badges.add({'icon': '⚽', 'title': 'Artilheiro', 'desc': '50+ Gols', 'color': Colors.greenAccent});
    if (assists >= 50) badges.add({'icon': '🎩', 'title': 'Mago', 'desc': '50+ Assist.', 'color': Colors.purpleAccent});
    else if (assists >= 20) badges.add({'icon': '🤝', 'title': 'Garçom', 'desc': '20+ Assist.', 'color': Colors.lightBlue});
    if (yellow + red >= 10) badges.add({'icon': '🔪', 'title': 'Açougueiro', 'desc': '10+ Cartões', 'color': Colors.redAccent});
    if (games >= 20 && (wins / games) > 0.6) badges.add({'icon': '🍀', 'title': 'Talismã', 'desc': '>60% Vitórias', 'color': Colors.green});
    if (hatTricks >= 5) badges.add({'icon': '🎭', 'title': 'Dono da Bola', 'desc': '5+ Hat-Tricks', 'color': Colors.yellow});
    return badges;
  }

  // --- UI COMPONENTS ---
  Widget _buildEvolutionChart() {
    if (_chartData.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text("Jogue mais partidas para ver o gráfico.", style: TextStyle(color: Colors.white54))));

    List<FlSpot> spots = [];
    double maxY = 0; double minY = _chartMetric == 'Nota' ? 10.0 : 0;

    for (int i = 0; i < _chartData.length; i++) {
      double value = (_chartData[i][_chartMetric] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), value));
      if (value > maxY) maxY = value; if (value < minY) minY = value;
    }

    if (_chartMetric == 'Nota') { maxY = 10.0; minY = minY < 4.0 ? minY : 4.0; } else { maxY = (maxY + 2).ceilToDouble(); minY = 0; }
    Color lineColor = AppColors.accentBlue;
    if (_chartMetric == 'Nota') lineColor = Colors.amber; if (_chartMetric == 'Gols') lineColor = AppColors.textWhite; if (_chartMetric == 'G+A') lineColor = AppColors.highlightGreen;

    return Container(
      padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.headerBlue, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(children: [Icon(Icons.auto_graph, color: AppColors.accentBlue), SizedBox(width: 8), Text("Evolução", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]),
              Container(height: 30, padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: AppColors.deepBlue, borderRadius: BorderRadius.circular(8)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _chartPeriod, dropdownColor: AppColors.deepBlue, icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 16), style: const TextStyle(color: Colors.white, fontSize: 12), items: ['Sessão', 'Mês'].map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(), onChanged: (newValue) { if (newValue != null) { setState(() => _chartPeriod = newValue); _calculateChartData(); } }))),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: ['Nota', 'G+A', 'Gols', 'Assistências'].map((metric) { bool isSelected = _chartMetric == metric; return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(onTap: () => setState(() { _chartMetric = metric; _calculateChartData(); }), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: isSelected ? AppColors.accentBlue.withValues(alpha: 0.2) : Colors.transparent, border: Border.all(color: isSelected ? AppColors.accentBlue : Colors.white24), borderRadius: BorderRadius.circular(12)), child: Text(metric, style: TextStyle(color: isSelected ? AppColors.accentBlue : Colors.white54, fontSize: 12, fontWeight: FontWeight.w600))))); }).toList()),
          ),
          const SizedBox(height: 24),
          SizedBox(height: 200, child: LineChart(LineChartData(minY: minY, maxY: maxY, minX: 0, maxX: (spots.length - 1).toDouble(), gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: _chartMetric == 'Nota' ? 2.0 : 1.0, getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1)), titlesData: FlTitlesData(show: true, rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (value, meta) => Text(_chartMetric == 'Nota' ? value.toStringAsFixed(1) : value.toInt().toString(), style: const TextStyle(color: Colors.white54, fontSize: 10), textAlign: TextAlign.right))), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: 1, getTitlesWidget: (value, meta) { if (value.toInt() < 0 || value.toInt() >= _chartData.length) return const SizedBox(); return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(_chartData[value.toInt()]['label'], style: const TextStyle(color: Colors.white54, fontSize: 9))); }))), borderData: FlBorderData(show: false), lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: lineColor, barWidth: 3, isStrokeCapRound: true, dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 4, color: lineColor, strokeWidth: 1.5, strokeColor: AppColors.headerBlue)), belowBarData: BarAreaData(show: true, color: lineColor.withValues(alpha: 0.15)))], lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipItems: (touchedSpots) { return touchedSpots.map((LineBarSpot touchedSpot) { return LineTooltipItem('${_chartData[touchedSpot.x.toInt()]['label']}\n', const TextStyle(color: Colors.white70, fontSize: 10), children: [TextSpan(text: _chartMetric == 'Nota' ? touchedSpot.y.toStringAsFixed(1) : touchedSpot.y.toInt().toString(), style: TextStyle(color: lineColor, fontWeight: FontWeight.bold, fontSize: 14))]); }).toList(); }))))),
        ],
      ),
    );
  }

  // --- NOVA SEÇÃO DE TROFÉUS (COMPATÍVEL COM ASSETS MANUAIS) ---
  Widget _buildBadgesSection() {
    List<Map<String, dynamic>> autoBadges = _generateAutomaticBadges();

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
                Text("Sala de Troféus", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
              ]),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: AppColors.accentBlue),
                tooltip: "Dar Prêmio Manual",
                onPressed: _showAddManualBadgeDialog,
              )
            ],
          ),
          const SizedBox(height: 12),
          
          if (autoBadges.isEmpty && manualBadges.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text("Nenhuma conquista ainda. Continue jogando!", style: TextStyle(color: Colors.white38))),
            )
          else ...[
            if (manualBadges.isNotEmpty) ...[
              const Text("Prêmios Especiais", style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: manualBadges.length,
                  itemBuilder: (ctx, i) => _buildBadgeCard(manualBadges[i], isManual: true, index: i),
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            if (autoBadges.isNotEmpty) ...[
              const Text("Conquistas Automáticas", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: autoBadges.length,
                  itemBuilder: (ctx, i) => _buildBadgeCard(autoBadges[i], isManual: false),
                ),
              ),
            ],
          ]
        ],
      ),
    );
  }

  Widget _buildBadgeCard(Map<String, dynamic> badge, {required bool isManual, int? index}) {
    Color badgeColor = isManual ? Colors.amber : (badge['color'] as Color? ?? Colors.blueAccent);
    
    return GestureDetector(
      onLongPress: () {
        if (isManual && index != null) _showRemoveManualBadgeDialog(index);
      },
      child: Container(
        width: 85,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isManual)
                SizedBox(
                  height: 35, width: 35,
                  child: Image.asset(
                    badge['icon'],
                    errorBuilder: (c, e, s) => const Icon(Icons.star, color: Colors.amber),
                  ),
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
          title: const Text("Nenhum Troféu Disponível", style: TextStyle(color: Colors.amber)),
          content: const Text("Você precisa criar troféus na 'Fábrica de Troféus' (ícone 🏆 na tela principal do grupo) antes de entregá-los aos jogadores.", style: TextStyle(color: Colors.white70)),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK", style: TextStyle(color: Colors.white)))],
        )
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.deepBlue,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Entregar Prêmio", style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Selecione o troféu que este jogador conquistou:", style: TextStyle(color: Colors.white70, fontSize: 14)),
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
                        padding: const EdgeInsets.all(6.0),
                        child: Image.asset(badge['icon'], errorBuilder: (c, e, s) => const Icon(Icons.emoji_events, color: Colors.amber)),
                      ),
                    ),
                    title: Text(badge['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(badge['desc'], style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    onTap: () {
                      _saveManualBadge(badge['icon'], badge['title']);
                      Navigator.pop(ctx);
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

  Future<void> _saveManualBadge(String icon, String title) async {
    final prefs = await SharedPreferences.getInstance();
    final String playersKey = 'players_${widget.groupId}';
    if (!prefs.containsKey(playersKey)) return;

    List<Map<String, dynamic>> loadedPlayers = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString(playersKey)!));
    final int index = loadedPlayers.indexWhere((p) => (p['id'] ?? '').toString() == widget.playerId);
    
    if (index != -1) {
      if (loadedPlayers[index]['manual_badges'] == null) {
        loadedPlayers[index]['manual_badges'] = [];
      }
      loadedPlayers[index]['manual_badges'].add({'icon': icon, 'title': title});
      
      await prefs.setString(playersKey, jsonEncode(loadedPlayers));
      setState(() {
        manualBadges.add({'icon': icon, 'title': title});
      });
    }
  }

  Future<void> _showRemoveManualBadgeDialog(int index) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text("Remover Prêmio?", style: TextStyle(color: Colors.white)),
        content: const Text("Deseja tirar este prêmio do jogador?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              final String playersKey = 'players_${widget.groupId}';
              List<Map<String, dynamic>> loadedPlayers = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString(playersKey)!));
              final int pIndex = loadedPlayers.indexWhere((p) => (p['id'] ?? '').toString() == widget.playerId);
              
              if (pIndex != -1) {
                loadedPlayers[pIndex]['manual_badges'].removeAt(index);
                await prefs.setString(playersKey, jsonEncode(loadedPlayers));
                setState(() {
                  manualBadges.removeAt(index);
                });
              }
            }, 
            child: const Text("Remover", style: TextStyle(color: Colors.redAccent))
          ),
        ],
      )
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 10.0) return Colors.black;
    if (rating >= 9.0) return Colors.purpleAccent;
    if (rating >= 8.0) return Colors.green[700]!; // Darker green
    if (rating >= 7.5) return Colors.green;
    if (rating >= 7.0) return Colors.lightGreenAccent; // Light green
    if (rating >= 6.0) return Colors.yellow;
    if (rating >= 5.0) return Colors.orange;
    return Colors.red; // Below 5.0
  }

  @override
  Widget build(BuildContext context) {
    final int wins = playerStats['wins'] ?? 0; final int draws = playerStats['draws'] ?? 0; final int losses = playerStats['losses'] ?? 0;
    final int totalResults = wins + draws + losses;
    final double nota = playerStats['nota'] ?? 7.0;
    final String displayName = playerName.isNotEmpty ? playerName : (widget.initialPlayerName ?? 'Jogador');
    final String initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final Color ratingColor = _getRatingColor(nota);

    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(backgroundColor: AppColors.headerBlue, iconTheme: const IconThemeData(color: AppColors.textWhite), centerTitle: true, elevation: 0, title: Text(displayName, style: const TextStyle(color: AppColors.textWhite))),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.headerBlue, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10, width: 1)),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            CircleAvatar(radius: 36, backgroundColor: AppColors.deepBlue, child: resolvedIcon != null ? ClipOval(child: Padding(padding: const EdgeInsets.all(6), child: Image.asset(resolvedIcon!, fit: BoxFit.contain))) : Text(initial, style: const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold, fontSize: 26))),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: ratingColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.headerBlue, width: 2)), child: Text(nota.toStringAsFixed(1), style: const TextStyle(color: AppColors.headerBlue, fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(displayName, style: const TextStyle(color: AppColors.textWhite, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(onPressed: _showEditNameDialog, icon: const Icon(Icons.edit, size: 16), label: const Text('Editar nome'), style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24))),
                        const SizedBox(height: 6),
                        Text(rankPosition != null ? 'Ranking Histórico Geral: #$rankPosition / $totalPlayers' : 'Em Avaliação (Estreante)', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  _buildBadgesSection(), // <-- A SALA DE TROFÉUS ENTRA AQUI
                  
                  const SizedBox(height: 16),
                  _buildEvolutionChart(),
                  
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.headerBlue, borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      children: [
                        Row(children: [_statValue('G+A', '${playerStats['ga'] ?? 0}', AppColors.highlightGreen), _statValue('Gols', '${playerStats['goals'] ?? 0}', AppColors.textWhite), _statValue('Assistências', '${playerStats['assists'] ?? 0}', Colors.amber)]),
                        const SizedBox(height: 18),
                        Row(children: [_resultColumn('Vitórias', wins, Colors.greenAccent), _resultColumn('Empates', draws, Colors.grey.shade300), _resultColumn('Derrotas', losses, Colors.redAccent)]),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            height: 14,
                            child: Row(children: totalResults == 0 ? const [Expanded(child: ColoredBox(color: Color(0x334CAF50))), Expanded(child: ColoredBox(color: Color(0x33424242))), Expanded(child: ColoredBox(color: Color(0x33F44336)))] : [Expanded(flex: wins == 0 ? 1 : wins, child: const ColoredBox(color: Colors.green)), Expanded(flex: draws == 0 ? 1 : draws, child: const ColoredBox(color: Colors.black54)), Expanded(flex: losses == 0 ? 1 : losses, child: const ColoredBox(color: Colors.red))]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.headerBlue, borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [Icon(Icons.psychology, color: AppColors.accentBlue), SizedBox(width: 8), Text("Estatísticas Avançadas", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]),
                        const SizedBox(height: 16),
                        _buildAdvStatRow("Hat-Tricks (3 Gols/Jogo)", "${advancedStats['hatTricks'] ?? 0} marcados", Icons.whatshot, Colors.orangeAccent),
                        _buildAdvStatRow("Faltas Graves", "${playerStats['yellow'] ?? 0} Amarelos / ${playerStats['red'] ?? 0} Vermelhos", Icons.style, Colors.redAccent),
                        const Divider(color: Colors.white12, height: 24),
                        _buildAdvStatRow("Garçom Favorito", _formatAdvStat(advancedStats['topAssister'], "gols seus"), Icons.handshake, Colors.amber),
                        _buildAdvStatRow("Mais Assistiu", _formatAdvStat(advancedStats['topAssisted'], "assistências suas"), Icons.sports_soccer, Colors.greenAccent),
                        const Divider(color: Colors.white12, height: 24),
                        _buildAdvStatRow("Mais Jogou Junto", _formatAdvStat(advancedStats['mostPlayedWith'], "jogos"), Icons.people, Colors.white),
                        _buildAdvStatRow("Mais Venceu Junto", _formatAdvStat(advancedStats['mostWinsWith'], "vitórias"), Icons.thumb_up, Colors.green),
                        _buildAdvStatRow("Mais Perdeu Junto", _formatAdvStat(advancedStats['mostLossesWith'], "derrotas"), Icons.thumb_down, Colors.redAccent),
                        const Divider(color: Colors.white12, height: 24),
                        _buildAdvStatRow("Maior Freguês (Contra)", _formatAdvStat(advancedStats['mostWinsAgainst'], "vitórias"), Icons.mood, Colors.blueAccent),
                        _buildAdvStatRow("Carrasco (Contra)", _formatAdvStat(advancedStats['mostLossesAgainst'], "derrotas"), Icons.mood_bad, Colors.red),
                        _buildAdvStatRow("Rival Equilibrado", _formatAdvStat(advancedStats['mostDrawsAgainst'], "empates"), Icons.balance, Colors.grey),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _formatAdvStat(dynamic stat, String suffix) {
    if (stat == null || stat['count'] == 0) return "-";
    return "${stat['name']} (${stat['count']} $suffix)";
  }

  Widget _buildAdvStatRow(String label, String value, IconData icon, Color color) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.deepBlue, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))]))]));
  }

  Widget _statValue(String label, String value, Color valueColor) {
    return Expanded(child: Column(children: [Text(value, style: TextStyle(color: valueColor, fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500))]));
  }

  Widget _resultColumn(String label, int value, Color color) {
    return Expanded(child: Column(children: [Text('$value', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600))]));
  }

  Future<void> _showEditNameDialog() async {
    final controller = TextEditingController(text: playerName);
    await showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: AppColors.headerBlue, title: const Text('Editar jogador', style: TextStyle(color: AppColors.textWhite)), content: TextField(controller: controller, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Nome', labelStyle: TextStyle(color: Colors.white54))), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))), TextButton(onPressed: () async { final newName = controller.text.trim(); if (newName.isEmpty) return; await _savePlayerName(newName); if (mounted) Navigator.pop(ctx); }, child: const Text('Salvar', style: TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold)))]));
  }

  Future<void> _savePlayerName(String newName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'players_${widget.groupId}';
    if (!prefs.containsKey(key)) return;
    final loaded = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString(key)!));
    final players = ensurePlayerIds(loaded);
    final index = players.indexWhere((p) => (p['id'] ?? '').toString() == widget.playerId);
    if (index == -1) return;
    players[index]['name'] = newName;
    await prefs.setString(key, jsonEncode(players));
    setState(() { playerName = newName; playerStats['name'] = newName; });
  }
}
