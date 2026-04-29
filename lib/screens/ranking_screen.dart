import 'dart:convert';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/screens/player_detail.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/player_identity.dart';
import '../utils/rating_calculator.dart';

class RankingScreen extends StatefulWidget {
  final String groupId;
  final String tournamentId;

  const RankingScreen({
    super.key,
    required this.groupId,
    required this.tournamentId,
  });

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  List<Map<String, dynamic>> leaderboard = [];
  bool isLoading = true;

  String _sortColumn = 'ga';
  bool _sortDescending = true;

  @override
  void initState() {
    super.initState();
    _calculateRankings();
  }

  // ─────────────────────────────────────────────────────────────
  // LÓGICA DE NEGÓCIO
  // ─────────────────────────────────────────────────────────────

  Future<void> _calculateRankings() async {
    final prefs = await SharedPreferences.getInstance();
    final String historyKey = 'match_history_${widget.tournamentId}';

    if (!prefs.containsKey(historyKey)) {
      setState(() => isLoading = false);
      return;
    }

    final List<dynamic> history = jsonDecode(prefs.getString(historyKey)!);
    final Map<String, Map<String, dynamic>> stats = {};

    for (final match in history) {
      final int scoreRed   = match['scoreRed']   ?? 0;
      final int scoreWhite = match['scoreWhite'] ?? 0;
      final int redStatus  = scoreRed > scoreWhite  ? 1 : (scoreRed == scoreWhite  ? 0 : -1);
      final int whiteStatus = scoreWhite > scoreRed ? 1 : (scoreRed == scoreWhite  ? 0 : -1);

      // Coleta eventos de cada jogador nesta partida
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

        stats.putIfAbsent(playerId, () => {
          'id': playerId,
          'name': playerName,
          'goals': 0,
          'assists': 0,
          'games': 0,
          'wins': 0,
          'draws': 0,
          'losses': 0,
          'sum_ratings': 0.0,
        });
        if (playerName.isNotEmpty) stats[playerId]!['name'] = playerName;

        stats[playerId]!['games'] = (stats[playerId]!['games'] as int) + 1;

        if (status == 1)       stats[playerId]!['wins']   = (stats[playerId]!['wins']   as int) + 1;
        else if (status == -1) stats[playerId]!['losses'] = (stats[playerId]!['losses'] as int) + 1;
        else                   stats[playerId]!['draws']  = (stats[playerId]!['draws']  as int) + 1;

        final int g  = matchPlayerEvents[playerId]?['g']  ?? 0;
        final int a  = matchPlayerEvents[playerId]?['a']  ?? 0;
        final int og = matchPlayerEvents[playerId]?['og'] ?? 0;
        final int yc = matchPlayerEvents[playerId]?['yc'] ?? 0;
        final int rc = matchPlayerEvents[playerId]?['rc'] ?? 0;

        stats[playerId]!['goals']   = (stats[playerId]!['goals']   as int) + g;
        stats[playerId]!['assists'] = (stats[playerId]!['assists'] as int) + a;

        final double matchRating = calculateMatchRating(
          status: status, goals: g, assists: a,
          ownGoals: og, teamGoals: scored, conceded: conceded, yellow: yc, red: rc,
          teamWinStreak: 0,
        );
        stats[playerId]!['sum_ratings'] =
            (stats[playerId]!['sum_ratings'] as double) + matchRating;
      }

      if (match['players']['red'] != null) {
        for (final p in match['players']['red']) processPlayer(p, redStatus, scoreRed, scoreWhite);
      }
      if (match['players']['white'] != null) {
        for (final p in match['players']['white']) processPlayer(p, whiteStatus, scoreWhite, scoreRed);
      }
    }

    // Monta a lista — ranking_screen NÃO exige mínimo de jogos
    final List<Map<String, dynamic>> sortedList = [];
    stats.forEach((id, data) {
      final int games       = data['games'] as int;
      final double sumRatings = data['sum_ratings'] as double;
      final int g           = data['goals'] as int;
      final int a           = data['assists'] as int;

      if (games > 0) {
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
      leaderboard = sortedList;
      isLoading   = false;
    });
  }

  void _applySorting(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      int cmp = 0;

      switch (_sortColumn) {
        case 'ga':        cmp = (a['ga']      as num).compareTo(b['ga']      as num); break;
        case 'goals':     cmp = (a['goals']   as num).compareTo(b['goals']   as num); break;
        case 'nota':      cmp = (a['nota']    as num).compareTo(b['nota']    as num); break;
        case 'assists':   cmp = (a['assists'] as num).compareTo(b['assists'] as num); break;
        case 'wins':      cmp = (a['wins']    as num).compareTo(b['wins']    as num); break;
        case 'games':     cmp = (a['games']   as num).compareTo(b['games']   as num); break;
        default:          cmp = (a[_sortColumn] as num).compareTo(b[_sortColumn] as num);
      }

      // Desempates em cascata
      if (cmp == 0 && _sortColumn != 'ga')    cmp = (a['ga']   as num).compareTo(b['ga']   as num);
      if (cmp == 0 && _sortColumn != 'goals') cmp = (a['goals'] as num).compareTo(b['goals'] as num);
      if (cmp == 0 && _sortColumn != 'nota')  cmp = (a['nota']  as num).compareTo(b['nota']  as num);

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
      final copy = List<Map<String, dynamic>>.from(leaderboard);
      _applySorting(copy);
      leaderboard = copy;
    });
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS AUXILIARES
  // ─────────────────────────────────────────────────────────────

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
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
        title: const Text('Ranking da Pelada', style: TextStyle(color: AppColors.textWhite)),
        centerTitle: true,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : leaderboard.isEmpty
              ? const Center(
                  child: Text('Sem jogadores registrados.', style: TextStyle(color: Colors.white54)),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  primary: true,
                  physics: const ClampingScrollPhysics(),
                  child: SingleChildScrollView(
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
                            const DataColumn(label: Text('#', style: TextStyle(color: Colors.white24, fontSize: 11))),
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
                          rows: List<DataRow>.generate(leaderboard.length, (index) {
                            final player = leaderboard[index];
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
                                      tournamentId:      widget.tournamentId,
                                      playerId:          player['id'].toString(),
                                      initialPlayerName: player['name'],
                                    ),
                                  ),
                                );
                              },
                              cells: [
                                DataCell(_rankCell(index)),
                                DataCell(Text(
                                  player['name'],
                                  style: TextStyle(
                                    color:      index < 3 ? Colors.white : Colors.white60,
                                    fontWeight: index < 3 ? FontWeight.w600 : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                )),
                                DataCell(Text((player['nota'] as double).toStringAsFixed(1), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w600, fontSize: 13))),
                                DataCell(Text('${player['ga']}',    style: const TextStyle(color: AppColors.highlightGreen, fontWeight: FontWeight.w600, fontSize: 13))),
                                DataCell(Text('${player['goals']}', style: const TextStyle(color: Colors.white60, fontSize: 13))),
                                DataCell(Text('${player['assists']}', style: const TextStyle(color: Colors.white60, fontSize: 13))),
                                DataCell(Text('${player['wins']}',    style: const TextStyle(color: Colors.greenAccent,  fontSize: 13))),
                                DataCell(Text('${player['draws']}',   style: const TextStyle(color: Colors.orangeAccent, fontSize: 13))),
                                DataCell(Text('${player['losses']}',  style: const TextStyle(color: Colors.redAccent,    fontSize: 13))),
                                DataCell(Text('${player['games']}',   style: const TextStyle(color: Colors.white30,      fontSize: 12))),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}
