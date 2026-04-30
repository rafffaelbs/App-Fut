import 'dart:convert';
import 'dart:io';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/screens/expanded_ranking_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/player_identity.dart';
import '../utils/rating_calculator.dart';

class GroupRankingScreen extends StatefulWidget {
  final String groupId;

  const GroupRankingScreen({super.key, required this.groupId});

  @override
  State<GroupRankingScreen> createState() => _GroupRankingScreenState();
}

class _GroupRankingScreenState extends State<GroupRankingScreen> {
  List<Map<String, dynamic>> _globalLeaderboard = [];
  bool _isLoading = true;
  bool _isSharing = false;

  final ScreenshotController _screenshotController = ScreenshotController();

  List<dynamic> _allSessions = [];
  List<Map<String, dynamic>> _seasons = [];
  Map<String, dynamic> _playersMap = {};

  String _filterType = 'Mês Atual'; // Mês Atual, Temporada, Geral
  String? _selectedSeasonId;

  // Top 3 lists
  List<Map<String, dynamic>> _topNota = [];
  List<Map<String, dynamic>> _topGA = [];
  List<Map<String, dynamic>> _topGoals = [];
  List<Map<String, dynamic>> _topAssists = [];

  // Gráfico de Evolução (Média geral por sessão)
  List<Map<String, dynamic>> _chartData = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Players for Icons
    final String playersKey = 'players_${widget.groupId}';
    if (prefs.containsKey(playersKey)) {
      final List<dynamic> pList = jsonDecode(prefs.getString(playersKey)!);
      for (var p in pList) {
        _playersMap[p['id'].toString()] = p;
      }
    }

    // Load Seasons
    final String seasonsKey = 'seasons_${widget.groupId}';
    if (prefs.containsKey(seasonsKey)) {
      final List<dynamic> sList = jsonDecode(prefs.getString(seasonsKey)!);
      _seasons = List<Map<String, dynamic>>.from(sList);
      if (_seasons.isNotEmpty) {
        _selectedSeasonId = _seasons.first['id'];
      }
    }

    // Load Sessions
    final String sessionsKey = 'sessions_${widget.groupId}';
    if (prefs.containsKey(sessionsKey)) {
      _allSessions = jsonDecode(prefs.getString(sessionsKey)!);
    }

    _calculateGlobalRankings();
  }

  bool _isSessionInFilter(dynamic session) {
    if (_filterType == 'Geral') return true;

    final DateTime date = session['timestamp'] != null
        ? DateTime.parse(session['timestamp'])
        : DateTime.now();

    if (_filterType == 'Mês Atual') {
      final now = DateTime.now();
      return date.year == now.year && date.month == now.month;
    }

    if (_filterType == 'Temporada') {
      if (_selectedSeasonId == null) return false;
      final seasonDef = _seasons.firstWhere((s) => s['id'] == _selectedSeasonId, orElse: () => {});
      if (seasonDef.isEmpty) return false;
      
      final DateTime start = DateTime.parse(seasonDef['startDate']);
      final DateTime end = DateTime.parse(seasonDef['endDate']);
      // A sessão tem que estar entre start e end, ignorando as horas finais (usamos isBefore/isAfter ou limites)
      return (date.isAfter(start.subtract(const Duration(days: 1))) && 
              date.isBefore(end.add(const Duration(days: 1))));
    }

    return true;
  }

  void _calculateGlobalRankings() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, Map<String, dynamic>> globalStats = {};

    // Dados para o gráfico
    final Map<String, List<double>> sessionRatings = {};

    for (final session in _allSessions) {
      if (!_isSessionInFilter(session)) continue;

      final String tournamentId = session['id'];
      final String historyKey   = 'match_history_$tournamentId';
      if (!prefs.containsKey(historyKey)) continue;

      final List<dynamic> history = jsonDecode(prefs.getString(historyKey)!);

      final DateTime sessionDate = session['timestamp'] != null
          ? DateTime.parse(session['timestamp'])
          : DateTime.now();
      final String sessionLabel = '${sessionDate.day.toString().padLeft(2,'0')}/${sessionDate.month.toString().padLeft(2,'0')}';
      sessionRatings.putIfAbsent(sessionLabel, () => []);

      for (final match in history) {
        final int scoreRed    = match['scoreRed']   ?? 0;
        final int scoreWhite  = match['scoreWhite'] ?? 0;
        final int redStatus   = scoreRed > scoreWhite  ? 1 : (scoreRed == scoreWhite  ? 0 : -1);
        final int whiteStatus = scoreWhite > scoreRed  ? 1 : (scoreRed == scoreWhite  ? 0 : -1);

        final Map<String, Map<String, int>> matchPlayerEvents = {};
        if (match['events'] != null) {
          for (final ev in match['events']) {
            final String pid   = eventPlayerId(ev, 'player');
            final String astId = eventPlayerId(ev, 'assist');
            final String type  = ev['type'];

            if (pid.isNotEmpty) {
              matchPlayerEvents.putIfAbsent(pid, () => {'g': 0, 'a': 0, 'og': 0, 'yc': 0, 'rc': 0});
              if (type == 'goal')        matchPlayerEvents[pid]!['g']  = matchPlayerEvents[pid]!['g']!  + 1;
              if (type == 'own_goal')    matchPlayerEvents[pid]!['og'] = matchPlayerEvents[pid]!['og']! + 1;
              if (type == 'yellow_card') matchPlayerEvents[pid]!['yc'] = matchPlayerEvents[pid]!['yc']! + 1;
              if (type == 'red_card')    matchPlayerEvents[pid]!['rc'] = matchPlayerEvents[pid]!['rc']! + 1;
            }
            if (astId.isNotEmpty) {
              matchPlayerEvents.putIfAbsent(astId, () => {'g': 0, 'a': 0, 'og': 0, 'yc': 0, 'rc': 0});
              if (type == 'goal') matchPlayerEvents[astId]!['a'] = matchPlayerEvents[astId]!['a']! + 1;
            }
          }
        }

        final Set<String> processed = {};

        void processPlayer(dynamic playerObj, int status, int scored, int conceded) {
          if (playerObj == null) return;
          final String playerId = playerIdFromObject(playerObj);
          if (playerId.isEmpty || processed.contains(playerId)) return;
          processed.add(playerId);

          final String playerName = (playerObj['name'] ?? '').toString();

          globalStats.putIfAbsent(playerId, () => {
            'id':         playerId,
            'name':       playerName,
            'goals':      0,
            'assists':    0,
            'games':      0,
            'wins':       0,
            'draws':      0,
            'losses':     0,
            'ratings':     <double>[],
          });
          if (playerName.isNotEmpty) globalStats[playerId]!['name'] = playerName;

          globalStats[playerId]!['games'] = (globalStats[playerId]!['games'] as int) + 1;

          if (status == 1)       globalStats[playerId]!['wins']   = (globalStats[playerId]!['wins']   as int) + 1;
          else if (status == -1) globalStats[playerId]!['losses'] = (globalStats[playerId]!['losses'] as int) + 1;
          else                   globalStats[playerId]!['draws']  = (globalStats[playerId]!['draws']  as int) + 1;

          final int g  = matchPlayerEvents[playerId]?['g']  ?? 0;
          final int a  = matchPlayerEvents[playerId]?['a']  ?? 0;
          final int og = matchPlayerEvents[playerId]?['og'] ?? 0;
          final int yc = matchPlayerEvents[playerId]?['yc'] ?? 0;
          final int rc = matchPlayerEvents[playerId]?['rc'] ?? 0;

          globalStats[playerId]!['goals']   = (globalStats[playerId]!['goals']   as int) + g;
          globalStats[playerId]!['assists'] = (globalStats[playerId]!['assists'] as int) + a;

          final double matchRating = calculateMatchRating(
            status: status, goals: g, assists: a,
            ownGoals: og, teamGoals: scored, conceded: conceded, yellow: yc, red: rc,
            teamWinStreak: 0,
          );
          (globalStats[playerId]!['ratings'] as List<double>).add(matchRating);
          
          sessionRatings[sessionLabel]!.add(matchRating);
        }

        if (match['players']['red']   != null) for (final p in match['players']['red'])   processPlayer(p, redStatus,   scoreRed, scoreWhite);
        if (match['players']['white'] != null) for (final p in match['players']['white']) processPlayer(p, whiteStatus, scoreWhite, scoreRed);
        if (match['players']['gk_red']   != null) processPlayer(match['players']['gk_red'],   redStatus,   scoreRed, scoreWhite);
        if (match['players']['gk_white'] != null) processPlayer(match['players']['gk_white'], whiteStatus, scoreWhite, scoreRed);
      }
    }

    final List<Map<String, dynamic>> sortedList = [];
    globalStats.forEach((id, data) {
      final int games       = data['games'] as int;
      final int g           = data['goals']   as int;
      final int a           = data['assists'] as int;

      if (games >= kMinGamesForGlobalRanking) {
        sortedList.add({
          'id':      id,
          'name':    data['name'],
          'goals':   g,
          'assists': a,
          'ga':      g + a,
          'games':   games,
          'wins':    data['wins'],
          'draws':   data['draws'],
          'losses':  data['losses'],
          'nota':    calculateFinalRating(ratings: data['ratings'] as List<double>),
        });
      }
    });

    _globalLeaderboard = List.from(sortedList);

    // Calcular Tops
    _topNota = List.from(_globalLeaderboard)..sort((a, b) => (b['nota'] as num).compareTo(a['nota'] as num));
    _topGA = List.from(_globalLeaderboard)..sort((a, b) {
      int cmp = (b['ga'] as num).compareTo(a['ga'] as num);
      if (cmp == 0) cmp = (b['goals'] as num).compareTo(a['goals'] as num);
      return cmp;
    });
    _topGoals = List.from(_globalLeaderboard)..sort((a, b) => (b['goals'] as num).compareTo(a['goals'] as num));
    _topAssists = List.from(_globalLeaderboard)..sort((a, b) => (b['assists'] as num).compareTo(a['assists'] as num));

    // Pegar apenas top 3
    if (_topNota.length > 3) _topNota = _topNota.sublist(0, 3);
    if (_topGA.length > 3) _topGA = _topGA.sublist(0, 3);
    if (_topGoals.length > 3) _topGoals = _topGoals.sublist(0, 3);
    if (_topAssists.length > 3) _topAssists = _topAssists.sublist(0, 3);

    // Gráfico de Evolução Média
    _chartData = [];
    sessionRatings.forEach((label, ratings) {
      if (ratings.isNotEmpty) {
        double avg = ratings.reduce((a, b) => a + b) / ratings.length;
        _chartData.add({'label': label, 'avg': avg});
      }
    });

    setState(() {
      _isLoading = false;
    });
  }

  void _onFilterChanged(String newFilter) {
    setState(() {
      _filterType = newFilter;
      _isLoading = true;
    });
    _calculateGlobalRankings();
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS
  // ─────────────────────────────────────────────────────────────

  Widget _buildFilterToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.headerBlue.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: ['Mês Atual', 'Temporada', 'Geral'].map((filter) {
          final bool active = _filterType == filter;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onFilterChanged(filter),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? AppColors.accentBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    filter,
                    style: TextStyle(
                      color: active ? Colors.white : Colors.white54,
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSeasonSelector() {
    if (_filterType != 'Temporada') return const SizedBox.shrink();

    if (_seasons.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Center(child: Text('Nenhuma temporada cadastrada no Menu (Engrenagem).', style: TextStyle(color: Colors.white54))),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.headerBlue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: _selectedSeasonId,
            dropdownColor: AppColors.deepBlue,
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            items: _seasons.map((s) => DropdownMenuItem<String>(
                  value: s['id'],
                  child: Text(s['name']),
                )).toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _selectedSeasonId = v;
                  _isLoading = true;
                });
                _calculateGlobalRankings();
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTop3Card({
    required String title,
    required List<Map<String, dynamic>> players,
    required String metric,
    required String sortColumn,
    required Color highlightColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: highlightColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: highlightColor, fontSize: 16, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () {
                  if (_globalLeaderboard.isEmpty) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ExpandedRankingScreen(
                        groupId: widget.groupId,
                        title: title,
                        initialSortColumn: sortColumn,
                        leaderboard: _globalLeaderboard,
                        playersMap: _playersMap,
                      ),
                    ),
                  );
                },
                child: const Row(
                  children: [
                    Text('Ver Todos', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Icon(Icons.chevron_right, color: Colors.white54, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (players.isEmpty)
            const Center(child: Text('Sem dados.', style: TextStyle(color: Colors.white30)))
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (players.length > 1) _buildPodiumAvatar(players[1], 2, metric, highlightColor),
                if (players.isNotEmpty) _buildPodiumAvatar(players[0], 1, metric, highlightColor),
                if (players.length > 2) _buildPodiumAvatar(players[2], 3, metric, highlightColor),
              ],
            )
        ],
      ),
    );
  }

  Widget _buildPodiumAvatar(Map<String, dynamic> player, int position, String metric, Color highlight) {
    Color borderColor;
    double radius;
    if (position == 1) { borderColor = Colors.amber; radius = 32; } 
    else if (position == 2) { borderColor = Colors.grey[400]!; radius = 26; } 
    else { borderColor = const Color(0xFFCD7F32); radius = 26; } // Bronze

    final String? iconPath = _playersMap[player['id']]?['icon'];
    String valText = '';
    if (metric == 'nota') valText = (player['nota'] as double).toStringAsFixed(1);
    else valText = player[metric].toString();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: position == 1 ? 3 : 2),
              ),
              child: CircleAvatar(
                radius: radius,
                backgroundColor: AppColors.deepBlue,
                child: iconPath != null 
                  ? ClipOval(child: Padding(padding: EdgeInsets.all(position == 1 ? 8.0 : 6.0), child: Image.asset(iconPath)))
                  : const Icon(Icons.person, color: Colors.white38),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${position}º',
                style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          player['name'].split(' ')[0], 
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          valText,
          style: TextStyle(color: highlight, fontSize: 14, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _buildEvolutionChart() {
    if (_chartData.isEmpty) return const SizedBox.shrink();

    final List<FlSpot> spots = [];
    double minY = kMaxRating;
    double maxY = 0;

    for (int i = 0; i < _chartData.length; i++) {
      double val = _chartData[i]['avg'];
      spots.add(FlSpot(i.toDouble(), val));
      if (val < minY) minY = val;
      if (val > maxY) maxY = val;
    }

    if (minY > 0.5) minY -= 0.5;
    if (maxY < 9.5) maxY += 0.5;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Evolução Média da Pelada (Nota)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: Colors.white10, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (v, meta) => Text(v.toStringAsFixed(1), style: const TextStyle(color: Colors.white54, fontSize: 10)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, meta) {
                        int index = v.toInt();
                        if (index < 0 || index >= _chartData.length) return const SizedBox.shrink();
                        return Text(_chartData[index]['label'], style: const TextStyle(color: Colors.white54, fontSize: 10));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.amber,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: Colors.amber.withValues(alpha: 0.15)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      body: SafeArea(
        child: Column(
          children: [
            _buildFilterToggle(),
            _buildSeasonSelector(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accentBlue))
                  : Screenshot(
                      controller: _screenshotController,
                      child: Container(
                        color: AppColors.deepBlue,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              if (_globalLeaderboard.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Text('Nenhum jogo registrado nesse período.', style: TextStyle(color: Colors.white54)),
                                )
                              else ...[
                                _buildTop3Card(title: 'Os Melhores', players: _topNota, metric: 'nota', sortColumn: 'nota', highlightColor: Colors.amber),
                                _buildTop3Card(title: 'Part. Ofensivas (G+A)', players: _topGA, metric: 'ga', sortColumn: 'ga', highlightColor: AppColors.highlightGreen),
                                _buildTop3Card(title: 'Artilheiros', players: _topGoals, metric: 'goals', sortColumn: 'goals', highlightColor: Colors.blueAccent),
                                _buildTop3Card(title: 'Garçons (Assist.)', players: _topAssists, metric: 'assists', sortColumn: 'assists', highlightColor: Colors.deepPurpleAccent),
                                _buildEvolutionChart(),
                              ],
                              const SizedBox(height: 30),
                            ],
                          ),
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accentBlue,
        onPressed: _isSharing ? null : _shareRanking,
        child: _isSharing
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.share, color: Colors.white),
      ),
    );
  }

  Future<void> _shareRanking() async {
    setState(() => _isSharing = true);
    try {
      final imageFile = await _screenshotController.capture(delay: const Duration(milliseconds: 10));
      if (imageFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        final imagePath = await File('${directory.path}/ranking.png').create();
        await imagePath.writeAsBytes(imageFile);
        await Share.shareXFiles([XFile(imagePath.path)], text: 'Confira o Ranking da Pelada!');
      }
    } catch (e) {
      debugPrint('Erro ao compartilhar: \$e');
    } finally {
      setState(() => _isSharing = false);
    }
  }
}
