import 'dart:convert';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RankingScreen extends StatefulWidget {
  // --- FIX 1: ADD TOURNAMENT ID TO RANKING SCREEN ---
  final String tournamentId;

  const RankingScreen({super.key, required this.tournamentId});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  List<Map<String, dynamic>> leaderboard = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateRankings();
  }

  Future<void> _calculateRankings() async {
    final prefs = await SharedPreferences.getInstance();

    // --- FIX 2: LOOK FOR THE SPECIFIC TOURNAMENT ID ---
    final String historyKey = 'match_history_${widget.tournamentId}';

    if (!prefs.containsKey(historyKey)) {
      setState(() => isLoading = false);
      return;
    }

    final List<dynamic> history = jsonDecode(prefs.getString(historyKey)!);

    final Map<String, Map<String, int>> stats = {};

    for (var match in history) {
      int scoreRed = match['scoreRed'] ?? 0;
      int scoreWhite = match['scoreWhite'] ?? 0;

      int redStatus = scoreRed > scoreWhite
          ? 1
          : (scoreRed == scoreWhite ? 0 : -1);
      int whiteStatus = scoreWhite > scoreRed
          ? 1
          : (scoreRed == scoreWhite ? 0 : -1);

      final Set<String> processed = {};

      void processPlayer(dynamic playerObj, int status) {
        if (playerObj == null || playerObj['name'] == null) return;

        String name = playerObj['name'];
        if (processed.contains(name)) return;
        processed.add(name);

        stats.putIfAbsent(
          name,
          () => {
            'goals': 0,
            'assists': 0,
            'games': 0,
            'wins': 0,
            'draws': 0,
            'losses': 0,
          },
        );

        stats[name]!['games'] = stats[name]!['games']! + 1;

        if (status == 1)
          stats[name]!['wins'] = stats[name]!['wins']! + 1;
        else if (status == -1)
          stats[name]!['losses'] = stats[name]!['losses']! + 1;
        else
          stats[name]!['draws'] = stats[name]!['draws']! + 1;
      }

      if (match['players']['red'] != null) {
        for (var p in match['players']['red']) processPlayer(p, redStatus);
      }
      if (match['players']['white'] != null) {
        for (var p in match['players']['white']) processPlayer(p, whiteStatus);
      }

      if (match['players']['gk_red'] != null)
        processPlayer(match['players']['gk_red'], redStatus);
      if (match['players']['gk_white'] != null)
        processPlayer(match['players']['gk_white'], whiteStatus);

      if (match['events'] != null) {
        for (var event in match['events']) {
          if (event['type'] == 'goal') {
            final scorer = event['player'];
            if (stats.containsKey(scorer)) {
              stats[scorer]!['goals'] = stats[scorer]!['goals']! + 1;
            }

            final assist = event['assist'];
            if (assist != null && assist.toString().isNotEmpty) {
              if (stats.containsKey(assist)) {
                stats[assist]!['assists'] = stats[assist]!['assists']! + 1;
              }
            }
          }
        }
      }
    }

    List<Map<String, dynamic>> sortedList = [];

    stats.forEach((name, data) {
      int g = data['goals']!;
      int a = data['assists']!;
      int games = data['games']!;
      int w = data['wins']!;
      int d = data['draws']!;
      int l = data['losses']!;

      double nota = 0.0;
      if (games > 0) {
        double matchResultImpact = ((w * 1.5) + (d * 0.5) + (l * -0.5));
        double contributionImpact = ((g * 1.0) + (a * 0.7));

        nota = 5.0 + ((matchResultImpact + contributionImpact) / games);

        if (nota > 10.0) nota = 10.0;
        if (nota < 0.0) nota = 0.0;
      }

      sortedList.add({
        'name': name,
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

    sortedList.sort((a, b) {
      int compareGA = b['ga'].compareTo(a['ga']);
      if (compareGA != 0) return compareGA;
      return b['nota'].compareTo(a['nota']);
    });

    setState(() {
      leaderboard = sortedList;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
        title: const Text(
          "Ranking (G/A)",
          style: TextStyle(color: AppColors.textWhite),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : leaderboard.isEmpty
          ? const Center(
              child: Text(
                "Sem dados de partidas.",
                style: TextStyle(color: Colors.white54),
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
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(
                          AppColors.headerBlue,
                        ),
                        dataRowColor: MaterialStateProperty.all(
                          AppColors.deepBlue,
                        ),
                        columnSpacing: 16,
                        columns: const [
                          DataColumn(
                            label: Text(
                              "#",
                              style: TextStyle(
                                color: AppColors.accentBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "JOGADOR",
                              style: TextStyle(
                                color: AppColors.textWhite,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "NOTA",
                              style: TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              "G+A",
                              style: TextStyle(
                                color: AppColors.highlightGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              "GOLS",
                              style: TextStyle(color: AppColors.textWhite),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              "ASSIST",
                              style: TextStyle(color: AppColors.textWhite),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              "VIT",
                              style: TextStyle(color: Colors.greenAccent),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              "EMP",
                              style: TextStyle(color: Colors.orangeAccent),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              "DER",
                              style: TextStyle(color: Colors.redAccent),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              "JOGOS",
                              style: TextStyle(color: Colors.grey),
                            ),
                            numeric: true,
                          ),
                        ],
                        rows: List<DataRow>.generate(leaderboard.length, (
                          index,
                        ) {
                          final player = leaderboard[index];
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  "${index + 1}",
                                  style: const TextStyle(
                                    color: AppColors.accentBlue,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  player['name'],
                                  style: const TextStyle(
                                    color: AppColors.textWhite,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  player['nota'].toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  "${player['ga']}",
                                  style: const TextStyle(
                                    color: AppColors.highlightGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  "${player['goals']}",
                                  style: const TextStyle(
                                    color: AppColors.textWhite,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  "${player['assists']}",
                                  style: const TextStyle(
                                    color: AppColors.textWhite,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  "${player['wins']}",
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  "${player['draws']}",
                                  style: const TextStyle(
                                    color: Colors.orangeAccent,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  "${player['losses']}",
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  "${player['games']}",
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
