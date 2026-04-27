import 'dart:convert';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/screens/player_detail.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/player_identity.dart';

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

  @override
  void initState() {
    super.initState();
    _calculateRankings();
  }

Future<void> _calculateRankings() async {
    final prefs = await SharedPreferences.getInstance();
    final String historyKey = 'match_history_${widget.tournamentId}';

    if (!prefs.containsKey(historyKey)) {
      setState(() => isLoading = false);
      return;
    }

    final List<dynamic> history = jsonDecode(prefs.getString(historyKey)!);
    final Map<String, Map<String, dynamic>> stats = {};

    for (var match in history) {
      int scoreRed = match['scoreRed'] ?? 0;
      int scoreWhite = match['scoreWhite'] ?? 0;

      int redStatus = scoreRed > scoreWhite ? 1 : (scoreRed == scoreWhite ? 0 : -1);
      int whiteStatus = scoreWhite > scoreRed ? 1 : (scoreRed == scoreWhite ? 0 : -1);

      final Set<String> processed = {};

      void processPlayer(dynamic playerObj, int status, int goalsConceded) {
        if (playerObj == null) return;
        final String playerId = playerIdFromObject(playerObj);
        if (playerId.isEmpty) return;
        if (processed.contains(playerId)) return;
        processed.add(playerId);
        
        final String playerName = (playerObj['name'] ?? '').toString();

        stats.putIfAbsent(
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
        if (playerName.isNotEmpty) stats[playerId]!['name'] = playerName;

        stats[playerId]!['games'] = (stats[playerId]!['games'] as int) + 1;
        stats[playerId]!['goals_conceded'] = (stats[playerId]!['goals_conceded'] as int) + goalsConceded;
        
        if (goalsConceded == 0) {
          stats[playerId]!['clean_sheets'] = (stats[playerId]!['clean_sheets'] as int) + 1;
        }

        if (status == 1) stats[playerId]!['wins'] = (stats[playerId]!['wins'] as int) + 1;
        else if (status == -1) stats[playerId]!['losses'] = (stats[playerId]!['losses'] as int) + 1;
        else stats[playerId]!['draws'] = (stats[playerId]!['draws'] as int) + 1;
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
            if (stats.containsKey(scorerId)) {
              stats[scorerId]!['goals'] = (stats[scorerId]!['goals'] as int) + 1;
            }
            final assistId = eventPlayerId(event, 'assist');
            if (assistId.isNotEmpty && stats.containsKey(assistId)) {
              stats[assistId]!['assists'] = (stats[assistId]!['assists'] as int) + 1;
            }
          } else if (event['type'] == 'own_goal') {
            if (stats.containsKey(scorerId)) {
              stats[scorerId]!['own_goals'] = (stats[scorerId]!['own_goals'] as int) + 1;
            }
          }
        }
      }
    }

    List<Map<String, dynamic>> sortedList = [];

    stats.forEach((id, data) {
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
        
        // Fator Defensivo (Ativado desde o 1º jogo na sessão atual para refletir o dia)
        double defenseImpact = (cleanSheets * 0.5) + (conceded * -0.15);

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

    sortedList.sort((a, b) {
      int compareNota = (b['nota'] as double).compareTo(a['nota'] as double);
      if (compareNota != 0) return compareNota;
      return (b['ga'] as int).compareTo(a['ga'] as int);
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
                        showCheckboxColumn: false,
                        headingRowColor: WidgetStateProperty.all(
                          AppColors.headerBlue,
                        ),
                        dataRowColor: WidgetStateProperty.all(
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
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PlayerDetailScreen(
                                        groupId: widget.groupId,
                                        tournamentId: widget.tournamentId,
                                        playerId: player['id'],
                                        initialPlayerName: player['name'],
                                      ),
                                    ),
                                  );
                                },
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
