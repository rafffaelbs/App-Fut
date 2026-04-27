import 'dart:convert';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/player_identity.dart';

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
    1: 'Janeiro',
    2: 'Fevereiro',
    3: 'Março',
    4: 'Abril',
    5: 'Maio',
    6: 'Junho',
    7: 'Julho',
    8: 'Agosto',
    9: 'Setembro',
    10: 'Outubro',
    11: 'Novembro',
    12: 'Dezembro',
  };

  String _formatFilterLabel(String filter) {
    if (filter == 'Todos') return 'Histórico Geral';
    final parts = filter.split('/');
    if (parts.length != 2) return filter;
    final month = int.tryParse(parts[0]);
    final year = parts[1];
    if (month == null) return filter;
    return '${_monthNames[month] ?? parts[0]} $year';
  }

  @override
  void initState() {
    super.initState();
    _loadDataAndFilters();
  }

  Future<void> _loadDataAndFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final String sessionsKey = 'sessions_${widget.groupId}';

    if (prefs.containsKey(sessionsKey)) {
      _allSessions = jsonDecode(prefs.getString(sessionsKey)!);

      Set<String> uniqueMonths = {};
      for (var session in _allSessions) {
        DateTime date = session['timestamp'] != null
            ? DateTime.parse(session['timestamp'])
            : DateTime.now();
        uniqueMonths.add(
          "${date.month.toString().padLeft(2, '0')}/${date.year}",
        );
      }

      List<String> sortedMonths = uniqueMonths.toList()
        ..sort((a, b) {
          List<String> ap = a.split('/'), bp = b.split('/');
          int aVal = int.parse(ap[1]) * 100 + int.parse(ap[0]);
          int bVal = int.parse(bp[1]) * 100 + int.parse(bp[0]);
          return bVal.compareTo(aVal);
        });

      _availableFilters = ['Todos', ...sortedMonths];
    }

    _calculateGlobalRankings();
  }

Future<void> _calculateGlobalRankings() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, Map<String, dynamic>> globalStats = {};

    for (var session in _allSessions) {
      if (_selectedFilter != 'Todos') {
        DateTime date = session['timestamp'] != null
            ? DateTime.parse(session['timestamp'])
            : DateTime.now();
        String sessionMonthYear = "${date.month.toString().padLeft(2, '0')}/${date.year}";
        if (sessionMonthYear != _selectedFilter) continue;
      }

      String tournamentId = session['id'];
      String historyKey = 'match_history_$tournamentId';
      if (!prefs.containsKey(historyKey)) continue;

      final List<dynamic> history = jsonDecode(prefs.getString(historyKey)!);

      for (var match in history) {
        int scoreRed = match['scoreRed'] ?? 0;
        int scoreWhite = match['scoreWhite'] ?? 0;
        int redStatus = scoreRed > scoreWhite ? 1 : (scoreRed == scoreWhite ? 0 : -1);
        int whiteStatus = scoreWhite > scoreRed ? 1 : (scoreRed == scoreWhite ? 0 : -1);

        final Set<String> processed = {};

        void processPlayer(dynamic playerObj, int status, int goalsConceded) {
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
              'own_goals': 0,
              'games': 0,
              'wins': 0,
              'draws': 0,
              'losses': 0,
              'goals_conceded': 0,
              'clean_sheets': 0,
            },
          );
          if (playerName.isNotEmpty) globalStats[playerId]!['name'] = playerName;

          globalStats[playerId]!['games'] = (globalStats[playerId]!['games'] as int) + 1;
          globalStats[playerId]!['goals_conceded'] = (globalStats[playerId]!['goals_conceded'] as int) + goalsConceded;
          if (goalsConceded == 0) {
            globalStats[playerId]!['clean_sheets'] = (globalStats[playerId]!['clean_sheets'] as int) + 1;
          }

          if (status == 1) globalStats[playerId]!['wins'] = (globalStats[playerId]!['wins'] as int) + 1;
          else if (status == -1) globalStats[playerId]!['losses'] = (globalStats[playerId]!['losses'] as int) + 1;
          else globalStats[playerId]!['draws'] = (globalStats[playerId]!['draws'] as int) + 1;
        }

        if (match['players']['red'] != null) {
          for (var p in match['players']['red']) processPlayer(p, redStatus, scoreWhite);
        }
        if (match['players']['white'] != null) {
          for (var p in match['players']['white']) processPlayer(p, whiteStatus, scoreRed);
        }
        if (match['players']['gk_red'] != null) {
          processPlayer(match['players']['gk_red'], redStatus, scoreWhite);
        }
        if (match['players']['gk_white'] != null) {
          processPlayer(match['players']['gk_white'], whiteStatus, scoreRed);
        }

        if (match['events'] != null) {
          for (var event in match['events']) {
            final scorerId = eventPlayerId(event, 'player');
            if (event['type'] == 'goal') {
              if (globalStats.containsKey(scorerId)) {
                globalStats[scorerId]!['goals'] = (globalStats[scorerId]!['goals'] as int) + 1;
              }
              final assistId = eventPlayerId(event, 'assist');
              if (assistId.isNotEmpty && globalStats.containsKey(assistId)) {
                globalStats[assistId]!['assists'] = (globalStats[assistId]!['assists'] as int) + 1;
              }
            } else if (event['type'] == 'own_goal') {
              if (globalStats.containsKey(scorerId)) {
                globalStats[scorerId]!['own_goals'] = (globalStats[scorerId]!['own_goals'] as int) + 1;
              }
            }
          }
        }
      }
    }

    List<Map<String, dynamic>> sortedList = [];
    globalStats.forEach((id, data) {
      int g = data['goals'] as int;
      int a = data['assists'] as int;
      int og = data['own_goals'] as int;
      int games = data['games'] as int;
      int w = data['wins'] as int;
      int d = data['draws'] as int;
      int l = data['losses'] as int;
      int conceded = data['goals_conceded'] as int;
      int cleanSheets = data['clean_sheets'] as int;

      double nota = 0.0;
      if (games > 0) {
        double resultImpact = (w * 1.0) + (d * 0.5) + (l * -0.5);
        double attackImpact = (g * 0.8) + (a * 0.3) + (og * -0.8);
        
        // Fator Defensivo com REGRA DE CORTE (5 jogos) no Ranking Histórico
        double defenseImpact = 0.0;
        if (games >= 5) {
          defenseImpact = (cleanSheets * 0.5) + (conceded * -0.15);
        }

        nota = 5.0 + ((resultImpact + attackImpact + defenseImpact) / games);
        nota = nota.clamp(0.0, 10.0);
      }

      sortedList.add({
        'id': id,
        'name': data['name'],
        'goals': g,
        'assists': a,
        'ga': g + a,
        'games': games,
        'wins': w,
        'draws': d,
        'losses': l,
        'nota': nota,
      });
    });

    _applySorting(sortedList);
    setState(() {
      globalLeaderboard = sortedList;
      isLoading = false;
    });
  }

  void _applySorting(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      int cmp = (a[_sortColumn] as int).compareTo(b[_sortColumn] as int);
      if (cmp == 0 && _sortColumn == 'ga') {
        // Tie-breaker: sort by goals if G+A is equal
        cmp = (a['goals'] as int).compareTo(b['goals'] as int);
      }
      return _sortDescending ? -cmp : cmp;
    });
  }

  void _onColumnSort(String column) {
    setState(() {
      _sortColumn == column
          ? _sortDescending = !_sortDescending
          : () {
              _sortColumn = column;
              _sortDescending = true;
            }();
      final copy = List<Map<String, dynamic>>.from(globalLeaderboard);
      _applySorting(copy);
      globalLeaderboard = copy;
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

  Widget _rankCell(int index) {
    if (index == 0) return const Text('🥇', style: TextStyle(fontSize: 16));
    if (index == 1) return const Text('🥈', style: TextStyle(fontSize: 16));
    if (index == 2) return const Text('🥉', style: TextStyle(fontSize: 16));
    return Text(
      '${index + 1}',
      style: const TextStyle(color: Colors.white30, fontSize: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      body: Column(
        children: [
          // ── FILTER BAR ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.headerBlue.withValues(alpha: 0.5),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.white30,
                  size: 13,
                ),
                const SizedBox(width: 8),
                const Text(
                  "Período",
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const Spacer(),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    dropdownColor: AppColors.headerBlue,
                    icon: const Icon(
                      Icons.expand_more_rounded,
                      color: Colors.white38,
                      size: 16,
                    ),
                    isDense: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    items: _availableFilters.map((value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(_formatFilterLabel(value)),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null && newValue != _selectedFilter) {
                        setState(() {
                          _selectedFilter = newValue;
                          isLoading = true;
                        });
                        _calculateGlobalRankings();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── TABLE ───────────────────────────────────────────
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accentBlue,
                      strokeWidth: 2,
                    ),
                  )
                : globalLeaderboard.isEmpty
                ? Center(
                    child: Text(
                      _selectedFilter == 'Todos'
                          ? "Nenhuma partida jogada neste grupo ainda."
                          : "Nenhuma partida em ${_formatFilterLabel(_selectedFilter)}.",
                      style: const TextStyle(
                        color: Colors.white30,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                dividerColor: Colors.white.withValues(
                                  alpha: 0.05,
                                ),
                              ),
                              child: DataTable(
                                headingRowHeight: 38,
                                dataRowMinHeight: 44,
                                dataRowMaxHeight: 44,
                                headingRowColor: WidgetStateProperty.all(
                                  AppColors.headerBlue.withValues(alpha: 0.7),
                                ),
                                dataRowColor: WidgetStateProperty.all(
                                  Colors.transparent,
                                ),
                                columnSpacing: 14,
                                horizontalMargin: 12,
                                border: TableBorder(
                                  horizontalInside: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.04),
                                  ),
                                ),
                                columns: [
                                  const DataColumn(
                                    label: Text(
                                      "#",
                                      style: TextStyle(
                                        color: Colors.white24,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const DataColumn(
                                    label: Text(
                                      "JOGADOR",
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: _sortHeader(
                                      "G+A",
                                      "ga",
                                      AppColors.highlightGreen,
                                    ),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: _sortHeader(
                                      "GOLS",
                                      "goals",
                                      Colors.white54,
                                    ),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: _sortHeader(
                                      "ASSIST",
                                      "assists",
                                      Colors.white54,
                                    ),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: _sortHeader(
                                      "VIT",
                                      "wins",
                                      Colors.greenAccent,
                                    ),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: _sortHeader(
                                      "EMP",
                                      "draws",
                                      Colors.orangeAccent,
                                    ),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: _sortHeader(
                                      "DER",
                                      "losses",
                                      Colors.redAccent,
                                    ),
                                  ),
                                  const DataColumn(
                                    numeric: true,
                                    label: Text(
                                      "JOGOS",
                                      style: TextStyle(
                                        color: Colors.white24,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                                rows: List<DataRow>.generate(
                                  globalLeaderboard.length,
                                  (index) {
                                    final p = globalLeaderboard[index];

                                    return DataRow(
                                      color: WidgetStateProperty.all(
                                        index.isOdd
                                            ? Colors.white.withValues(
                                                alpha: 0.02,
                                              )
                                            : Colors.transparent,
                                      ),
                                      cells: [
                                        DataCell(_rankCell(index)),
                                        DataCell(
                                          Text(
                                            p['name'],
                                            style: TextStyle(
                                              color: index < 3
                                                  ? Colors.white
                                                  : Colors.white60,
                                              fontWeight: index < 3
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            "${p['ga']}",
                                            style: const TextStyle(
                                              color: AppColors.highlightGreen,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            "${p['goals']}",
                                            style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            "${p['assists']}",
                                            style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            "${p['wins']}",
                                            style: const TextStyle(
                                              color: Colors.greenAccent,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            "${p['draws']}",
                                            style: const TextStyle(
                                              color: Colors.orangeAccent,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            "${p['losses']}",
                                            style: const TextStyle(
                                              color: Colors.redAccent,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            "${p['games']}",
                                            style: const TextStyle(
                                              color: Colors.white30,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
