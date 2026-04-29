import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/screens/player_detail.dart';
import 'package:flutter/material.dart';

class ExpandedRankingScreen extends StatefulWidget {
  final String groupId;
  final String title;
  final String initialSortColumn;
  final List<Map<String, dynamic>> leaderboard;
  final Map<String, dynamic> playersMap;

  const ExpandedRankingScreen({
    super.key,
    required this.groupId,
    required this.title,
    required this.initialSortColumn,
    required this.leaderboard,
    required this.playersMap,
  });

  @override
  State<ExpandedRankingScreen> createState() => _ExpandedRankingScreenState();
}

class _ExpandedRankingScreenState extends State<ExpandedRankingScreen> {
  late List<Map<String, dynamic>> _sortedList;
  late String _sortColumn;
  bool _sortDescending = true;

  @override
  void initState() {
    super.initState();
    _sortColumn = widget.initialSortColumn;
    _sortedList = List<Map<String, dynamic>>.from(widget.leaderboard);
    _applySorting(_sortedList);
  }

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
        _sortColumn = column;
        _sortDescending = true;
      }
      _applySorting(_sortedList);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.headerBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
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
                dataRowMinHeight: 48,
                dataRowMaxHeight: 48,
                headingRowColor: WidgetStateProperty.all(AppColors.headerBlue.withValues(alpha: 0.7)),
                dataRowColor: WidgetStateProperty.all(Colors.transparent),
                columnSpacing: 14,
                horizontalMargin: 12,
                border: TableBorder(
                  horizontalInside: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
                ),
                columns: [
                  const DataColumn(label: Text('#', style: TextStyle(color: Colors.white24, fontSize: 11))),
                  const DataColumn(label: Text('JOGADOR', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w600, fontSize: 11))),
                  DataColumn(numeric: true, label: _sortHeader('NOTA', 'nota', Colors.amber)),
                  DataColumn(numeric: true, label: _sortHeader('G+A', 'ga', AppColors.highlightGreen)),
                  DataColumn(numeric: true, label: _sortHeader('GOLS', 'goals', Colors.white54)),
                  DataColumn(numeric: true, label: _sortHeader('ASSIST', 'assists', Colors.white54)),
                  DataColumn(numeric: true, label: _sortHeader('VIT', 'wins', Colors.greenAccent)),
                  DataColumn(numeric: true, label: _sortHeader('EMP', 'draws', Colors.orangeAccent)),
                  DataColumn(numeric: true, label: _sortHeader('DER', 'losses', Colors.redAccent)),
                  DataColumn(numeric: true, label: _sortHeader('JOGOS', 'games', Colors.grey)),
                ],
                rows: List<DataRow>.generate(_sortedList.length, (index) {
                  final p = _sortedList[index];
                  final String? iconPath = widget.playersMap[p['id']]?['icon'];
                  return DataRow(
                    color: WidgetStateProperty.all(index.isOdd ? Colors.white.withValues(alpha: 0.02) : Colors.transparent),
                    onSelectChanged: (_) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlayerDetailScreen(
                            groupId: widget.groupId,
                            playerId: p['id'].toString(),
                            initialPlayerName: p['name'],
                            playerIcon: iconPath,
                          ),
                        ),
                      );
                    },
                    cells: [
                      DataCell(_rankCell(index)),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (iconPath != null) ...[
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.deepBlue,
                              child: ClipOval(child: Padding(padding: const EdgeInsets.all(2), child: Image.asset(iconPath))),
                            ),
                            const SizedBox(width: 8),
                          ] else ...[
                            const CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.deepBlue,
                              child: Icon(Icons.person, size: 16, color: Colors.white54),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            p['name'],
                            style: TextStyle(
                              color: index < 3 ? Colors.white : Colors.white60,
                              fontWeight: index < 3 ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      )),
                      DataCell(Text((p['nota'] as double).toStringAsFixed(1), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w600, fontSize: 13))),
                      DataCell(Text('${p['ga']}', style: const TextStyle(color: AppColors.highlightGreen, fontWeight: FontWeight.w600, fontSize: 13))),
                      DataCell(Text('${p['goals']}', style: const TextStyle(color: Colors.white60, fontSize: 13))),
                      DataCell(Text('${p['assists']}', style: const TextStyle(color: Colors.white60, fontSize: 13))),
                      DataCell(Text('${p['wins']}', style: const TextStyle(color: Colors.greenAccent, fontSize: 13))),
                      DataCell(Text('${p['draws']}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 13))),
                      DataCell(Text('${p['losses']}', style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                      DataCell(Text('${p['games']}', style: const TextStyle(color: Colors.white30, fontSize: 12))),
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
