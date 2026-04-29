import 'dart:convert';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/player_identity.dart';
import '../utils/rating_calculator.dart';
import 'package:app_do_fut/screens/player_detail.dart';

class GroupRankingScreen extends StatefulWidget {
  final String groupId;

  const GroupRankingScreen({super.key, required this.groupId});

  @override
  State<GroupRankingScreen> createState() => _GroupRankingScreenState();
}

class _GroupRankingScreenState extends State<GroupRankingScreen> {
  List<Map<String, dynamic>> globalLeaderboard = [];
  bool isLoading = true;

  List<dynamic> _allSessions = [];
  List<String> _availableFilters = ['Todos'];
  String _selectedFilter = 'Todos';

  String _sortColumn = 'ga';
  bool _sortDescending = true;

  static const Map<int, String> _monthNames = {
    1: 'Janeiro',  2: 'Fevereiro', 3: 'Março',    4: 'Abril',
    5: 'Maio',     6: 'Junho',     7: 'Julho',     8: 'Agosto',
    9: 'Setembro', 10: 'Outubro',  11: 'Novembro', 12: 'Dezembro',
  };

  @override
  void initState() {
    super.initState();
    _loadDataAndFilters();
  }

  // ─────────────────────────────────────────────────────────────
  // LÓGICA DE NEGÓCIO
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadDataAndFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final String sessionsKey = 'sessions_${widget.groupId}';

    if (prefs.containsKey(sessionsKey)) {
      _allSessions = jsonDecode(prefs.getString(sessionsKey)!);

      final Set<String> uniqueMonths = {};
      for (final session in _allSessions) {
        final DateTime date = session['timestamp'] != null
            ? DateTime.parse(session['timestamp'])
            : DateTime.now();
        uniqueMonths.add('${date.month.toString().padLeft(2, '0')}/${date.year}');
      }

      final List<String> sortedMonths = uniqueMonths.toList()
        ..sort((a, b) {
          final List<String> ap = a.split('/'), bp = b.split('/');
          final int aVal = int.parse(ap[1]) * 100 + int.parse(ap[0]);
          final int bVal = int.parse(bp[1]) * 100 + int.parse(bp[0]);
          return bVal.compareTo(aVal);
        });

      _availableFilters = ['Todos', ...sortedMonths];
    }

    _calculateGlobalRankings();
  }

  Future<void> _calculateGlobalRankings() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, Map<String, dynamic>> globalStats = {};

    for (final session in _allSessions) {
      // Aplica filtro por mês
      if (_selectedFilter != 'Todos') {
        final DateTime date = session['timestamp'] != null
            ? DateTime.parse(session['timestamp'])
            : DateTime.now();
        final String sessionMonthYear =
            '${date.month.toString().padLeft(2, '0')}/${date.year}';
        if (sessionMonthYear != _selectedFilter) continue;
      }

      final String tournamentId = session['id'];
      final String historyKey   = 'match_history_$tournamentId';
      if (!prefs.containsKey(historyKey)) continue;

      final List<dynamic> history = jsonDecode(prefs.getString(historyKey)!);

      for (final match in history) {
        final int scoreRed    = match['scoreRed']   ?? 0;
        final int scoreWhite  = match['scoreWhite'] ?? 0;
        final int redStatus   = scoreRed > scoreWhite  ? 1 : (scoreRed == scoreWhite  ? 0 : -1);
        final int whiteStatus = scoreWhite > scoreRed  ? 1 : (scoreRed == scoreWhite  ? 0 : -1);

        // Coleta eventos por jogador nesta partida
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
            'sum_ratings': 0.0,
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
          globalStats[playerId]!['sum_ratings'] =
              (globalStats[playerId]!['sum_ratings'] as double) + matchRating;
        }

        if (match['players']['red']   != null) for (final p in match['players']['red'])   processPlayer(p, redStatus,   scoreRed, scoreWhite);
        if (match['players']['white'] != null) for (final p in match['players']['white']) processPlayer(p, whiteStatus, scoreWhite, scoreRed);
        if (match['players']['gk_red']   != null) processPlayer(match['players']['gk_red'],   redStatus,   scoreRed, scoreWhite);
        if (match['players']['gk_white'] != null) processPlayer(match['players']['gk_white'], whiteStatus, scoreWhite, scoreRed);
      }
    }

    // Ranking geral exige mínimo de jogos (kMinGamesForGlobalRanking)
    final List<Map<String, dynamic>> sortedList = [];
    globalStats.forEach((id, data) {
      final int games       = data['games'] as int;
      final double sumRatings = data['sum_ratings'] as double;
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
          'nota':    calculateFinalRating(sumRatings: sumRatings, games: games),
        });
      }
    });

    _applySorting(sortedList);
    setState(() {
      globalLeaderboard = sortedList;
      isLoading         = false;
    });
  }

  // ─────────────────────────────────────────────────────────────
  // ORDENAÇÃO
  // ─────────────────────────────────────────────────────────────

  void _applySorting(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      int cmp = (a[_sortColumn] as num).compareTo(b[_sortColumn] as num);
      if (cmp == 0 && _sortColumn == 'ga') {
        cmp = (a['goals'] as num).compareTo(b['goals'] as num);
      }
      return _sortDescending ? -cmp : cmp;
    });
  }

  void _onColumnSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortDescending = !_sortDescending;
      } else {
        _sortColumn     = column;
        _sortDescending = true;
      }
      final copy = List<Map<String, dynamic>>.from(globalLeaderboard);
      _applySorting(copy);
      globalLeaderboard = copy;
    });
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS AUXILIARES
  // ─────────────────────────────────────────────────────────────

  String _formatFilterLabel(String filter) {
    if (filter == 'Todos') return 'Histórico Geral';
    final parts = filter.split('/');
    if (parts.length != 2) return filter;
    final int? month = int.tryParse(parts[0]);
    return month != null ? '${_monthNames[month] ?? parts[0]} ${parts[1]}' : filter;
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
                ? (_sortDescending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded)
                : Icons.unfold_more_rounded,
            size: 11,
            color: active ? Colors.white54 : color.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }

  Widget _rankCell(int index) {
    if (index == 0) return const Text('🥇', style: TextStyle(fontSize: 16));
    if (index == 1) return const Text('🥈', style: TextStyle(fontSize: 16));
    if (index == 2) return const Text('🥉', style: TextStyle(fontSize: 16));
    return Text('${index + 1}', style: const TextStyle(color: Colors.white30, fontSize: 12));
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentBlue, strokeWidth: 2))
          : SingleChildScrollView(
              scrollDirection: Axis.vertical,
              primary: true,
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  // ── BARRA DE FILTRO POR MÊS ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: AppColors.headerBlue.withValues(alpha: 0.5),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _availableFilters.map((filter) {
                          final bool active = _selectedFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedFilter = filter;
                                  isLoading       = true;
                                });
                                _calculateGlobalRankings();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: active ? AppColors.accentBlue : Colors.white.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: active ? AppColors.accentBlue : Colors.white24,
                                  ),
                                ),
                                child: Text(
                                  _formatFilterLabel(filter),
                                  style: TextStyle(
                                    color:      active ? Colors.white : Colors.white60,
                                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // ── TABELA ───────────────────────────────────────────────
                  if (globalLeaderboard.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        _selectedFilter == 'Todos'
                            ? 'Nenhum jogador com ${kMinGamesForGlobalRanking}+ partidas ainda.'
                            : 'Sem dados para ${_formatFilterLabel(_selectedFilter)}.',
                        style: const TextStyle(color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      primary: false,
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.white.withValues(alpha: 0.05),
                          ),
                          child: DataTable(
                            showCheckboxColumn: false,
                            headingRowHeight: 38,
                            dataRowMinHeight: 44,
                            dataRowMaxHeight: 44,
                            headingRowColor: WidgetStateProperty.all(
                              AppColors.headerBlue.withValues(alpha: 0.7),
                            ),
                            dataRowColor: WidgetStateProperty.all(Colors.transparent),
                            columnSpacing: 14,
                            horizontalMargin: 12,
                            border: TableBorder(
                              horizontalInside: BorderSide(
                                color: Colors.white.withValues(alpha: 0.04),
                              ),
                            ),
                            columns: [
                              const DataColumn(label: Text('#',       style: TextStyle(color: Colors.white24, fontSize: 11))),
                              const DataColumn(label: Text('JOGADOR', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w600, fontSize: 11))),
                              DataColumn(numeric: true, label: _sortHeader('NOTA',  'nota',    Colors.amber)),
                              DataColumn(numeric: true, label: _sortHeader('G+A',   'ga',      AppColors.highlightGreen)),
                              DataColumn(numeric: true, label: _sortHeader('GOLS',  'goals',   Colors.white54)),
                              DataColumn(numeric: true, label: _sortHeader('ASSIST','assists', Colors.white54)),
                              DataColumn(numeric: true, label: _sortHeader('VIT',   'wins',    Colors.greenAccent)),
                              DataColumn(numeric: true, label: _sortHeader('EMP',   'draws',   Colors.orangeAccent)),
                              DataColumn(numeric: true, label: _sortHeader('DER',   'losses',  Colors.redAccent)),
                              DataColumn(numeric: true, label: _sortHeader('JOGOS', 'games',   Colors.grey)),
                            ],
                            rows: List<DataRow>.generate(globalLeaderboard.length, (index) {
                              final p = globalLeaderboard[index];
                              return DataRow(
                                color: WidgetStateProperty.all(
                                  index.isOdd
                                      ? Colors.white.withValues(alpha: 0.02)
                                      : Colors.transparent,
                                ),
                                onSelectChanged: (_) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PlayerDetailScreen(
                                        groupId:           widget.groupId,
                                        playerId:          p['id'].toString(),
                                        initialPlayerName: p['name'],
                                      ),
                                    ),
                                  );
                                },
                                cells: [
                                  DataCell(_rankCell(index)),
                                  DataCell(Text(
                                    p['name'],
                                    style: TextStyle(
                                      color:      index < 3 ? Colors.white : Colors.white60,
                                      fontWeight: index < 3 ? FontWeight.w600 : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  )),
                                  DataCell(Text((p['nota'] as double).toStringAsFixed(1), style: const TextStyle(color: Colors.amber,             fontWeight: FontWeight.w600, fontSize: 13))),
                                  DataCell(Text('${p['ga']}',      style: const TextStyle(color: AppColors.highlightGreen, fontWeight: FontWeight.w600, fontSize: 13))),
                                  DataCell(Text('${p['goals']}',   style: const TextStyle(color: Colors.white60,  fontSize: 13))),
                                  DataCell(Text('${p['assists']}', style: const TextStyle(color: Colors.white60,  fontSize: 13))),
                                  DataCell(Text('${p['wins']}',    style: const TextStyle(color: Colors.greenAccent,  fontSize: 13))),
                                  DataCell(Text('${p['draws']}',   style: const TextStyle(color: Colors.orangeAccent, fontSize: 13))),
                                  DataCell(Text('${p['losses']}',  style: const TextStyle(color: Colors.redAccent,    fontSize: 13))),
                                  DataCell(Text('${p['games']}',   style: const TextStyle(color: Colors.white30,      fontSize: 12))),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
