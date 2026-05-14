import 'dart:convert';
import 'dart:io';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/main.dart';
import 'package:app_do_fut/screens/player_detail.dart';
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

class _GroupRankingScreenState extends State<GroupRankingScreen>
    with RouteAware {
  List<Map<String, dynamic>> _globalLeaderboard = [];
  List<Map<String, dynamic>> _globalGkLeaderboard = [];
  bool _showGkRanking = false;
  bool _isLoading = true;
  bool _isSharing = false;

  final ScreenshotController _screenshotController = ScreenshotController();

  List<dynamic> _allSessions = [];
  List<Map<String, dynamic>> _seasons = [];
  Map<String, dynamic> _playersMap = {};

  String _filterType = 'Tudo'; // Tudo, Mês, Temporadas
  String? _selectedSeasonId;
  DateTime _selectedMonth = DateTime.now();
  int _activeTab = 0; // 0: Pódios, 1: Tabela

  String _sortColumn = 'ga';
  bool _sortDescending = true;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route observer
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when returning to this screen from another screen
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

    if (_filterType == 'Mês') {
      return date.year == _selectedMonth.year &&
          date.month == _selectedMonth.month;
    }

    if (_filterType == 'Temporadas') {
      if (_selectedSeasonId == null) return false;
      final seasonDef = _seasons.firstWhere(
        (s) => s['id'] == _selectedSeasonId,
        orElse: () => {},
      );
      if (seasonDef.isEmpty) return false;

      final DateTime start = DateTime.parse(seasonDef['startDate']);
      final DateTime end = DateTime.parse(seasonDef['endDate']);
      return (date.isAfter(start.subtract(const Duration(days: 1))) &&
          date.isBefore(end.add(const Duration(days: 1))));
    }

    return true;
  }

  void _calculateGlobalRankings() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, Map<String, dynamic>> globalStats = {};
    final Map<String, Map<String, dynamic>> globalGkStats = {};

    // Dados para o gráfico
    final Map<String, List<double>> sessionRatings = {};

    for (final session in _allSessions) {
      if (!_isSessionInFilter(session)) continue;

      final String tournamentId = session['id'];
      final String historyKey = 'match_history_$tournamentId';
      if (!prefs.containsKey(historyKey)) continue;

      final List<dynamic> history = jsonDecode(prefs.getString(historyKey)!);

      final DateTime sessionDate = session['timestamp'] != null
          ? DateTime.parse(session['timestamp'])
          : DateTime.now();
      final String sessionLabel =
          '${sessionDate.day.toString().padLeft(2, '0')}/${sessionDate.month.toString().padLeft(2, '0')}';
      sessionRatings.putIfAbsent(sessionLabel, () => []);

      for (final match in history) {
        final int scoreRed = match['scoreRed'] ?? 0;
        final int scoreWhite = match['scoreWhite'] ?? 0;
        final int redStatus = scoreRed > scoreWhite
            ? 1
            : (scoreRed == scoreWhite ? 0 : -1);
        final int whiteStatus = scoreWhite > scoreRed
            ? 1
            : (scoreRed == scoreWhite ? 0 : -1);

        final Map<String, Map<String, int>> matchPlayerEvents = {};
        if (match['events'] != null) {
          for (final ev in match['events']) {
            final String pid = eventPlayerId(ev, 'player');
            final String astId = eventPlayerId(ev, 'assist');
            final String type = ev['type'];

            if (pid.isNotEmpty) {
              matchPlayerEvents.putIfAbsent(
                pid,
                () => {'g': 0, 'a': 0, 'og': 0, 'yc': 0, 'rc': 0},
              );
              if (type == 'goal')
                matchPlayerEvents[pid]!['g'] =
                    matchPlayerEvents[pid]!['g']! + 1;
              if (type == 'own_goal')
                matchPlayerEvents[pid]!['og'] =
                    matchPlayerEvents[pid]!['og']! + 1;
              if (type == 'yellow_card')
                matchPlayerEvents[pid]!['yc'] =
                    matchPlayerEvents[pid]!['yc']! + 1;
              if (type == 'red_card')
                matchPlayerEvents[pid]!['rc'] =
                    matchPlayerEvents[pid]!['rc']! + 1;
            }
            if (astId.isNotEmpty) {
              matchPlayerEvents.putIfAbsent(
                astId,
                () => {'g': 0, 'a': 0, 'og': 0, 'yc': 0, 'rc': 0},
              );
              if (type == 'goal')
                matchPlayerEvents[astId]!['a'] =
                    matchPlayerEvents[astId]!['a']! + 1;
            }
          }
        }

        final Set<String> processed = {};

        void processPlayer(
          dynamic playerObj,
          int status,
          int scored,
          int conceded,
        ) {
          if (playerObj == null) return;
          final String playerId = playerIdFromObject(playerObj);
          if (playerId.isEmpty || processed.contains(playerId)) return;
          processed.add(playerId);

          final String playerName = (playerObj['name'] ?? '').toString();

          globalStats.putIfAbsent(
            playerId,
            () => {
              'id': playerId,
              'name': playerName,
              'goals': 0,
              'assists': 0,
              'games': 0,
              'wins': 0,
              'draws': 0,
              'losses': 0,
              'ratings': <double>[],
            },
          );
          if (playerName.isNotEmpty)
            globalStats[playerId]!['name'] = playerName;

          globalStats[playerId]!['games'] =
              (globalStats[playerId]!['games'] as int) + 1;

          if (status == 1)
            globalStats[playerId]!['wins'] =
                (globalStats[playerId]!['wins'] as int) + 1;
          else if (status == -1)
            globalStats[playerId]!['losses'] =
                (globalStats[playerId]!['losses'] as int) + 1;
          else
            globalStats[playerId]!['draws'] =
                (globalStats[playerId]!['draws'] as int) + 1;

          final int g = matchPlayerEvents[playerId]?['g'] ?? 0;
          final int a = matchPlayerEvents[playerId]?['a'] ?? 0;
          final int og = matchPlayerEvents[playerId]?['og'] ?? 0;
          final int yc = matchPlayerEvents[playerId]?['yc'] ?? 0;
          final int rc = matchPlayerEvents[playerId]?['rc'] ?? 0;

          globalStats[playerId]!['goals'] =
              (globalStats[playerId]!['goals'] as int) + g;
          globalStats[playerId]!['assists'] =
              (globalStats[playerId]!['assists'] as int) + a;

          final double matchRating = calculateMatchRating(
            status: status,
            goals: g,
            assists: a,
            ownGoals: og,
            teamGoals: scored,
            conceded: conceded,
            yellow: yc,
            red: rc,
            teamWinStreak: 0,
          );
          (globalStats[playerId]!['ratings'] as List<double>).add(matchRating);

          sessionRatings[sessionLabel]!.add(matchRating);
        }

        if (match['players']['red'] != null)
          for (final p in match['players']['red'])
            processPlayer(p, redStatus, scoreRed, scoreWhite);
        if (match['players']['white'] != null)
          for (final p in match['players']['white'])
            processPlayer(p, whiteStatus, scoreWhite, scoreRed);
        if (match['players']['gk_red'] != null)
          processPlayer(
            match['players']['gk_red'],
            redStatus,
            scoreRed,
            scoreWhite,
          );
        if (match['players']['gk_white'] != null)
          processPlayer(
            match['players']['gk_white'],
            whiteStatus,
            scoreWhite,
            scoreRed,
          );

        // Build a map of playerId -> name from events for lookup
        final Map<String, String> eventPlayerNames = {};
        if (match['events'] != null) {
          for (final ev in match['events']) {
            final String pid = eventPlayerId(ev, 'player');
            final String astId = eventPlayerId(ev, 'assist');
            if (pid.isNotEmpty && ev['player'] != null) {
              eventPlayerNames[pid] = ev['player'].toString();
            }
            if (astId.isNotEmpty && ev['assist'] != null) {
              eventPlayerNames[astId] = ev['assist'].toString();
            }
          }
        }

        // Process players who have events but weren't in the lineup
        // (e.g., goal/assist recorded for someone not officially playing)
        for (final playerId in matchPlayerEvents.keys) {
          if (!processed.contains(playerId)) {
            // Player has events but wasn't in lineup - count stats but no win/loss
            final events = matchPlayerEvents[playerId]!;
            // Try players map first, then event data, then fallback
            final String playerName =
                _playersMap[playerId]?['name'] ??
                eventPlayerNames[playerId] ??
                'Desconhecido';

            globalStats.putIfAbsent(
              playerId,
              () => {
                'id': playerId,
                'name': playerName,
                'goals': 0,
                'assists': 0,
                'games': 0,
                'wins': 0,
                'draws': 0,
                'losses': 0,
                'ratings': <double>[],
              },
            );
            if (playerName.isNotEmpty)
              globalStats[playerId]!['name'] = playerName;

            // Count games even though not in lineup (they participated via events)
            globalStats[playerId]!['games'] =
                (globalStats[playerId]!['games'] as int) + 1;

            final int g = events['g'] ?? 0;
            final int a = events['a'] ?? 0;
            final int og = events['og'] ?? 0;
            final int yc = events['yc'] ?? 0;
            final int rc = events['rc'] ?? 0;

            globalStats[playerId]!['goals'] =
                (globalStats[playerId]!['goals'] as int) + g;
            globalStats[playerId]!['assists'] =
                (globalStats[playerId]!['assists'] as int) + a;

            // No win/loss/draw since not in lineup
            // Do not calculate or add a matchRating here to preserve their current Nota
          }
        }
      }
    }

    final List<Map<String, dynamic>> sortedList = [];
    globalStats.forEach((id, data) {
      final int games = data['games'] as int;
      final int g = data['goals'] as int;
      final int a = data['assists'] as int;

      if (games >= kMinGamesForGlobalRanking) {
        sortedList.add({
          'id': id,
          'name': data['name'],
          'goals': g,
          'assists': a,
          'ga': g + a,
          'games': games,
          'wins': data['wins'],
          'draws': data['draws'],
          'losses': data['losses'],
          'nota': calculateFinalRating(
            ratings: data['ratings'] as List<double>,
          ),
        });
      }
    });

    _globalLeaderboard = List.from(sortedList);

    final List<Map<String, dynamic>> sortedGkList = [];
    globalGkStats.forEach((id, data) {
      final int games = data['gk_games'] as int;
      if (games > 0) {
        sortedGkList.add({
          'id': id,
          'name': data['name'],
          'games': games,
          'conceded': data['gk_conceded'],
          'clean_sheets': data['gk_clean_sheets'],
          'goals': data['gk_goals'],
          'assists': data['gk_assists'],
          'wins': data['gk_wins'],
          'draws': data['gk_draws'],
          'losses': data['gk_losses'],
          'nota': calculateFinalRating(
            ratings: data['gk_ratings'] as List<double>,
          ),
        });
      }
    });
    sortedGkList.sort((a, b) {
      int cmp = (b['nota'] as num).compareTo(a['nota'] as num);
      if (cmp == 0) {
        cmp = (b['clean_sheets'] as num).compareTo(a['clean_sheets'] as num);
        if (cmp == 0) {
          final double aCpg = (a['conceded'] as int) / (a['games'] as int);
          final double bCpg = (b['conceded'] as int) / (b['games'] as int);
          cmp = aCpg.compareTo(bCpg); // lower is better
        }
      }
      return cmp;
    });
    _globalGkLeaderboard = sortedGkList;

    // Calcular Tops
    _topNota = List.from(_globalLeaderboard)
      ..sort((a, b) => (b['nota'] as num).compareTo(a['nota'] as num));
    _topGA = List.from(_globalLeaderboard)
      ..sort((a, b) {
        int cmp = (b['ga'] as num).compareTo(a['ga'] as num);
        if (cmp == 0) cmp = (b['goals'] as num).compareTo(a['goals'] as num);
        return cmp;
      });
    _topGoals = List.from(_globalLeaderboard)
      ..sort((a, b) => (b['goals'] as num).compareTo(a['goals'] as num));
    _topAssists = List.from(_globalLeaderboard)
      ..sort((a, b) => (b['assists'] as num).compareTo(a['assists'] as num));

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
        children: ['Tudo', 'Mês', 'Temporadas'].map((filter) {
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

  Widget _buildMonthSelector() {
    if (_filterType != 'Mês') return const SizedBox.shrink();

    final months = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white54),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month - 1,
                );
                _isLoading = true;
              });
              _calculateGlobalRankings();
            },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.headerBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${months[_selectedMonth.month - 1]} ${_selectedMonth.year}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white54),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month + 1,
                );
                _isLoading = true;
              });
              _calculateGlobalRankings();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonSelector() {
    if (_filterType != 'Temporadas') return const SizedBox.shrink();

    if (_seasons.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Center(
          child: Text(
            'Nenhuma temporada cadastrada no Menu (Engrenagem).',
            style: TextStyle(color: Colors.white54),
          ),
        ),
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
            items: _seasons
                .map(
                  (s) => DropdownMenuItem<String>(
                    value: s['id'],
                    child: Text(s['name']),
                  ),
                )
                .toList(),
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
              Text(
                title,
                style: TextStyle(
                  color: highlightColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (players.isEmpty)
            const Center(
              child: Text(
                'Sem dados.',
                style: TextStyle(color: Colors.white30),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (players.length > 1)
                  _buildPodiumAvatar(players[1], 2, metric, highlightColor),
                if (players.isNotEmpty)
                  _buildPodiumAvatar(players[0], 1, metric, highlightColor),
                if (players.length > 2)
                  _buildPodiumAvatar(players[2], 3, metric, highlightColor),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPodiumAvatar(
    Map<String, dynamic> player,
    int position,
    String metric,
    Color highlight,
  ) {
    Color borderColor;
    double radius;
    if (position == 1) {
      borderColor = Colors.amber;
      radius = 32;
    } else if (position == 2) {
      borderColor = Colors.grey[400]!;
      radius = 26;
    } else {
      borderColor = const Color(0xFFCD7F32);
      radius = 26;
    } // Bronze

    final String? iconPath = _playersMap[player['id']]?['icon'];
    String valText = '';
    if (metric == 'nota')
      valText = (player['nota'] as double).toStringAsFixed(1);
    else
      valText = player[metric].toString();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlayerDetailScreen(
                  groupId: widget.groupId,
                  playerId: player['id'].toString(),
                  initialPlayerName: player['name'],
                ),
              ),
            );
          },
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: borderColor,
                    width: position == 1 ? 3 : 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: radius,
                  backgroundColor: AppColors.deepBlue,
                  child: iconPath != null
                      ? ClipOval(
                          child: Padding(
                            padding: EdgeInsets.all(position == 1 ? 8.0 : 6.0),
                            child: Image.asset(iconPath),
                          ),
                        )
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
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          player['name'].split(' ')[0],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          valText,
          style: TextStyle(
            color: highlight,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
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
          const Text(
            'Evolução Média da Pelada (Nota)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
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
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: Colors.white10, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (v, meta) => Text(
                        v.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, meta) {
                        int index = v.toInt();
                        if (index < 0 || index >= _chartData.length)
                          return const SizedBox.shrink();
                        return Text(
                          _chartData[index]['label'],
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
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
                    color: Colors.amber,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.amber.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _tabItem(0, 'Destaques', Icons.emoji_events),
          _tabItem(1, 'Ranking Geral', Icons.format_list_numbered),
        ],
      ),
    );
  }

  Widget _tabItem(int index, String label, IconData icon) {
    final bool active = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.accentBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? Colors.white : Colors.white38,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white38,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onColumnSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortDescending = !_sortDescending;
      } else {
        _sortColumn = column;
        _sortDescending = true;
      }
    });
  }

  Widget _sortHeader(String label, String column, Color color) {
    final bool active = _sortColumn == column;
    return GestureDetector(
      onTap: () => _onColumnSort(column),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            active
                ? (_sortDescending
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded)
                : Icons.unfold_more_rounded,
            size: 11,
            color: active ? Colors.white54 : color.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }

  Widget _buildFullTable() {
    if (_globalLeaderboard.isEmpty) return const SizedBox.shrink();

    // Ordenar dinamicamente
    final List<Map<String, dynamic>> sorted = List.from(_globalLeaderboard);
    sorted.sort((a, b) {
      int cmp = (a[_sortColumn] as num).compareTo(b[_sortColumn] as num);
      if (cmp == 0 && _sortColumn == 'ga') {
        cmp = (a['goals'] as num).compareTo(b['goals'] as num);
      }
      return _sortDescending ? -cmp : cmp;
    });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Theme(
        data: Theme.of(
          context,
        ).copyWith(dividerColor: Colors.white.withValues(alpha: 0.05)),
        child: DataTable(
          showCheckboxColumn: false,
          headingRowHeight: 40,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 52,
          columnSpacing: 16,
          horizontalMargin: 16,
          columns: [
            const DataColumn(
              label: Text(
                '#',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
            const DataColumn(
              label: Text(
                'JOGADOR',
                style: TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
            DataColumn(
              numeric: true,
              label: _sortHeader('NOTA', 'nota', Colors.amber),
            ),
            DataColumn(
              numeric: true,
              label: _sortHeader('G+A', 'ga', AppColors.highlightGreen),
            ),
            DataColumn(
              numeric: true,
              label: _sortHeader('GOLS', 'goals', Colors.white38),
            ),
            DataColumn(
              numeric: true,
              label: _sortHeader('AST', 'assists', Colors.white38),
            ),
            DataColumn(
              numeric: true,
              label: _sortHeader('VIT', 'wins', Colors.greenAccent),
            ),
            DataColumn(
              numeric: true,
              label: _sortHeader('EMP', 'draws', Colors.orangeAccent),
            ),
            DataColumn(
              numeric: true,
              label: _sortHeader('DER', 'losses', Colors.redAccent),
            ),
            DataColumn(
              numeric: true,
              label: _sortHeader('JOGOS', 'games', Colors.white24),
            ),
          ],
          rows: List<DataRow>.generate(sorted.length, (index) {
            final p = sorted[index];
            final String? icon = _playersMap[p['id']]?['icon'];
            return DataRow(
              onSelectChanged: (_) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerDetailScreen(
                      groupId: widget.groupId,
                      playerId: p['id'].toString(),
                      initialPlayerName: p['name'],
                      playerIcon: icon,
                    ),
                  ),
                );
              },
              cells: [
                DataCell(
                  Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: index < 3 ? Colors.amber : Colors.white24,
                      fontSize: 12,
                      fontWeight: index < 3
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.white10,
                        child: icon != null
                            ? ClipOval(child: Image.asset(icon))
                            : const Icon(
                                Icons.person,
                                size: 14,
                                color: Colors.white38,
                              ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        p['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Text(
                    (p['nota'] as double).toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '${p['ga']}',
                    style: const TextStyle(
                      color: AppColors.highlightGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '${p['goals']}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                DataCell(
                  Text(
                    '${p['assists']}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                DataCell(
                  Text(
                    '${p['wins']}',
                    style: const TextStyle(color: Colors.greenAccent),
                  ),
                ),
                DataCell(
                  Text(
                    '${p['draws']}',
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                ),
                DataCell(
                  Text(
                    '${p['losses']}',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
                DataCell(
                  Text(
                    '${p['games']}',
                    style: const TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildGlobalGkView() {
    if (_globalGkLeaderboard.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text(
            'Sem goleiros registrados nesse período.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _globalGkLeaderboard.length,
      itemBuilder: (context, index) {
        final gk = _globalGkLeaderboard[index];
        final double nota = (gk['nota'] as num).toDouble();
        return Card(
          color: AppColors.headerBlue,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.deepBlue,
                  child: Text(
                    gk['name'][0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.accentBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            title: Text(
              gk['name'],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nota: ${nota.toStringAsFixed(1)} | Jgs: ${gk['games']}',
                  style: const TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold),
                ),
                Text(
                  'CS: ${gk['clean_sheets']} | GS: ${gk['conceded']} | G: ${gk['goals']} | A: ${gk['assists']}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
            trailing: Text(
              '${gk['wins']}V ${gk['draws']}E ${gk['losses']}D',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _buildTabToggle(),
          _buildFilterToggle(),
          _buildMonthSelector(),
          _buildSeasonSelector(),
          // GK / Linha toggle
          Container(
            color: AppColors.headerBlue,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _showGkRanking = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: !_showGkRanking ? AppColors.accentBlue : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "Linha",
                        style: TextStyle(
                          color: !_showGkRanking ? AppColors.textWhite : Colors.white38,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _showGkRanking = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _showGkRanking ? AppColors.accentBlue : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "Goleiros",
                        style: TextStyle(
                          color: _showGkRanking ? AppColors.textWhite : Colors.white38,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accentBlue,
                    ),
                  )
                : _showGkRanking
                    ? SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Container(
                          color: AppColors.deepBlue,
                          child: _buildGlobalGkView(),
                        ),
                      )
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
                                    child: Text(
                                      'Nenhum jogo registrado nesse período.',
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                  )
                                else if (_activeTab == 0) ...[
                                  _buildTop3Card(
                                    title: 'Os Melhores',
                                    players: _topNota,
                                    metric: 'nota',
                                    sortColumn: 'nota',
                                    highlightColor: Colors.amber,
                                  ),
                                  _buildTop3Card(
                                    title: 'Part. Ofensivas (G+A)',
                                    players: _topGA,
                                    metric: 'ga',
                                    sortColumn: 'ga',
                                    highlightColor: AppColors.highlightGreen,
                                  ),
                                  _buildTop3Card(
                                    title: 'Artilheiros',
                                    players: _topGoals,
                                    metric: 'goals',
                                    sortColumn: 'goals',
                                    highlightColor: Colors.blueAccent,
                                  ),
                                  _buildTop3Card(
                                    title: 'Garçons (Assist.)',
                                    players: _topAssists,
                                    metric: 'assists',
                                    sortColumn: 'assists',
                                    highlightColor: Colors.deepPurpleAccent,
                                  ),
                                  _buildEvolutionChart(),
                                ] else
                                  _buildFullTable(),
                                const SizedBox(height: 30),
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accentBlue,
        onPressed: _isSharing ? null : _shareRanking,
        child: _isSharing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.share, color: Colors.white),
      ),
    );
  }

  Future<void> _shareRanking() async {
    setState(() => _isSharing = true);
    try {
      final imageFile = await _screenshotController.capture(
        delay: const Duration(milliseconds: 10),
      );
      if (imageFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        final imagePath = await File('${directory.path}/ranking.png').create();
        await imagePath.writeAsBytes(imageFile);
        await Share.shareXFiles([
          XFile(imagePath.path),
        ], text: 'Confira o Ranking da Pelada!');
      }
    } catch (e) {
      debugPrint('Erro ao compartilhar: \$e');
    } finally {
      setState(() => _isSharing = false);
    }
  }
}
