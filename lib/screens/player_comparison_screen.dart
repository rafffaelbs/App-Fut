import 'dart:convert';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/player_identity.dart';
import '../utils/rating_calculator.dart';
import '../utils/stats_calculator.dart';

class PlayerComparisonScreen extends StatefulWidget {
  final String groupId;
  final String player1Id;
  final String player2Id;

  const PlayerComparisonScreen({
    super.key,
    required this.groupId,
    required this.player1Id,
    required this.player2Id,
  });

  @override
  State<PlayerComparisonScreen> createState() => _PlayerComparisonScreenState();
}

class _PlayerComparisonScreenState extends State<PlayerComparisonScreen> {
  bool isLoading = true;
  Map<String, dynamic> player1 = {};
  Map<String, dynamic> player2 = {};
  Map<String, dynamic> stats1 = {};
  Map<String, dynamic> stats2 = {};
  Map<String, dynamic> adv1 = {};
  Map<String, dynamic> adv2 = {};

  int p1WinsH2h = 0;
  int p2WinsH2h = 0;
  int h2hDraws = 0;
  int h2hTotal = 0;

  bool _showRadarChart = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String playersKey = 'players_${widget.groupId}';
    
    bool showRadar = prefs.getBool('show_radar_chart') ?? true;

    List<Map<String, dynamic>> allPlayers = [];
    if (prefs.containsKey(playersKey)) {
      allPlayers = ensurePlayerIds(List<Map<String, dynamic>>.from(jsonDecode(prefs.getString(playersKey)!)));
    }

    final p1 = allPlayers.firstWhere((p) => (p['id'] ?? '').toString() == widget.player1Id, orElse: () => {});
    final p2 = allPlayers.firstWhere((p) => (p['id'] ?? '').toString() == widget.player2Id, orElse: () => {});

    final List<dynamic> allHistory = await getAllGroupMatches(widget.groupId);
    final globalStats = calculateGlobalStats(allHistory);

    Map<String, dynamic> st1 = globalStats[widget.player1Id] ?? {'games': 0, 'goals': 0, 'assists': 0, 'ga': 0, 'wins': 0, 'draws': 0, 'losses': 0, 'yellow': 0, 'red': 0, 'nota': kRatingBase};
    Map<String, dynamic> st2 = globalStats[widget.player2Id] ?? {'games': 0, 'goals': 0, 'assists': 0, 'ga': 0, 'wins': 0, 'draws': 0, 'losses': 0, 'yellow': 0, 'red': 0, 'nota': kRatingBase};

    final a1 = _calcAdvStats(widget.player1Id, allHistory);
    final a2 = _calcAdvStats(widget.player2Id, allHistory);

    int p1W = 0, p2W = 0, drw = 0, tot = 0;
    for (final match in allHistory) {
      final redPlayers = [...(match['players']['red'] ?? []), match['players']['gk_red']].where((p) => p != null).toList();
      final whitePlayers = [...(match['players']['white'] ?? []), match['players']['gk_white']].where((p) => p != null).toList();

      final bool p1InRed = redPlayers.any((p) => playerIdFromObject(p) == widget.player1Id);
      final bool p1InWhite = whitePlayers.any((p) => playerIdFromObject(p) == widget.player1Id);
      final bool p2InRed = redPlayers.any((p) => playerIdFromObject(p) == widget.player2Id);
      final bool p2InWhite = whitePlayers.any((p) => playerIdFromObject(p) == widget.player2Id);

      if ((p1InRed && p2InWhite) || (p1InWhite && p2InRed)) {
        tot++;
        final int scoreRed = match['scoreRed'] ?? 0;
        final int scoreWhite = match['scoreWhite'] ?? 0;
        
        if (scoreRed > scoreWhite) {
          if (p1InRed) p1W++; else p2W++;
        } else if (scoreWhite > scoreRed) {
          if (p1InWhite) p1W++; else p2W++;
        } else {
          drw++;
        }
      }
    }

    setState(() {
      player1 = p1;
      player2 = p2;
      stats1 = st1;
      stats2 = st2;
      adv1 = a1;
      adv2 = a2;
      p1WinsH2h = p1W;
      p2WinsH2h = p2W;
      h2hDraws = drw;
      h2hTotal = tot;
      _showRadarChart = showRadar;
      isLoading = false;
    });
  }

  Map<String, dynamic> _calcAdvStats(String playerId, List<dynamic> allHistory) {
    int cleanSheets = 0;
    int ownGoals = 0;
    int teamGoals = 0;

    for (final match in allHistory) {
      final List<dynamic> redPlayers = [...(match['players']['red'] ?? []), match['players']['gk_red']].where((p) => p != null).toList();
      final List<dynamic> whitePlayers = [...(match['players']['white'] ?? []), match['players']['gk_white']].where((p) => p != null).toList();

      final bool inRed = redPlayers.any((p) => playerIdFromObject(p) == playerId);
      final bool inWhite = whitePlayers.any((p) => playerIdFromObject(p) == playerId);
      if (!inRed && !inWhite) continue;

      final String myTeam = inRed ? 'red' : 'white';
      final int scoreRed = match['scoreRed'] ?? 0;
      final int scoreWhite = match['scoreWhite'] ?? 0;

      int myTeamGoals = myTeam == 'red' ? scoreRed : scoreWhite;
      teamGoals += myTeamGoals;

      int opponentGoals = myTeam == 'red' ? scoreWhite : scoreRed;
      if (opponentGoals == 0) cleanSheets++;

      if (match['events'] != null) {
        for (final ev in match['events']) {
          if (ev['type'] == 'own_goal' && eventPlayerId(ev, 'player') == playerId) {
            ownGoals++;
          }
        }
      }
    }
    return {'cleanSheets': cleanSheets, 'ownGoals': ownGoals, 'teamGoals': teamGoals};
  }

  double _getRadarScore(int games, int goals, int assists, int cleanSheets, int yellow, int red, int ownGoals, int wins, int draws, int teamGoals, int metricIndex) {
    if (games == 0) return 0;
    
    switch (metricIndex) {
      case 0: // Ataque
        return ((goals / games) * 100).clamp(0, 100);
      case 1: // Visão
        return ((assists / games) * 100).clamp(0, 100);
      case 2: // Defesa
        return ((cleanSheets / games) * 200).clamp(0, 100);
      case 3: // Tática
        if (teamGoals > 0) {
          int indirectGoals = teamGoals - goals - assists;
          if (indirectGoals < 0) indirectGoals = 0;
          return ((indirectGoals / teamGoals) * 100).clamp(0, 100);
        }
        return 0;
      case 4: // Gana
        return (((wins * 3 + draws * 1) / (games * 3)) * 100).clamp(0, 100);
      default:
        return 0;
    }
  }

  Widget _buildPlayerHeader(Map<String, dynamic> player, Color color, MainAxisAlignment alignment) {
    final String name = player['name'] ?? 'Desconhecido';
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final String? icon = player['icon'];

    return Row(
      mainAxisAlignment: alignment,
      children: [
        if (alignment == MainAxisAlignment.start) ...[
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.deepBlue,
            child: icon != null 
              ? ClipOval(child: Padding(padding: const EdgeInsets.all(4), child: Image.asset(icon, fit: BoxFit.contain)))
              : Text(initial, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
        ] else ...[
          Expanded(child: Text(name, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.deepBlue,
            child: icon != null 
              ? ClipOval(child: Padding(padding: const EdgeInsets.all(4), child: Image.asset(icon, fit: BoxFit.contain)))
              : Text(initial, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ]
      ],
    );
  }

  Widget _buildComparisonRow(String title, num val1, num val2, {bool invertWinner = false, bool isDouble = false}) {
    Color color1 = Colors.white70;
    Color color2 = Colors.white70;
    FontWeight weight1 = FontWeight.normal;
    FontWeight weight2 = FontWeight.normal;

    if (val1 != val2) {
      final bool p1Wins = invertWinner ? val1 < val2 : val1 > val2;
      if (p1Wins) {
        color1 = AppColors.highlightGreen;
        weight1 = FontWeight.bold;
      } else {
        color2 = AppColors.highlightGreen;
        weight2 = FontWeight.bold;
      }
    }

    String str1 = isDouble ? val1.toStringAsFixed(1) : val1.toString();
    String str2 = isDouble ? val2.toStringAsFixed(1) : val2.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(str1, style: TextStyle(color: color1, fontSize: 16, fontWeight: weight1), textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center)),
          Expanded(child: Text(str2, style: TextStyle(color: color2, fontSize: 16, fontWeight: weight2), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.deepBlue,
        body: Center(child: CircularProgressIndicator(color: AppColors.accentBlue)),
      );
    }

    final Color colorP1 = Colors.blueAccent;
    final Color colorP2 = Colors.orangeAccent;

    // Calc Radar Scores P1
    final p1Scores = List.generate(5, (i) => _getRadarScore(
      stats1['games'] ?? 0, stats1['goals'] ?? 0, stats1['assists'] ?? 0,
      adv1['cleanSheets'] ?? 0, stats1['yellow'] ?? 0, stats1['red'] ?? 0,
      adv1['ownGoals'] ?? 0, stats1['wins'] ?? 0, stats1['draws'] ?? 0, adv1['teamGoals'] ?? 0, i,
    ));

    // Calc Radar Scores P2
    final p2Scores = List.generate(5, (i) => _getRadarScore(
      stats2['games'] ?? 0, stats2['goals'] ?? 0, stats2['assists'] ?? 0,
      adv2['cleanSheets'] ?? 0, stats2['yellow'] ?? 0, stats2['red'] ?? 0,
      adv2['ownGoals'] ?? 0, stats2['wins'] ?? 0, stats2['draws'] ?? 0, adv2['teamGoals'] ?? 0, i,
    ));

    double aprov1 = 0, aprov2 = 0;
    int g1 = stats1['games'] ?? 0;
    int g2 = stats2['games'] ?? 0;
    if (g1 > 0) aprov1 = (((stats1['wins'] ?? 0) * 3 + (stats1['draws'] ?? 0) * 1) / (g1 * 3)) * 100;
    if (g2 > 0) aprov2 = (((stats2['wins'] ?? 0) * 3 + (stats2['draws'] ?? 0) * 1) / (g2 * 3)) * 100;

    double gaPg1 = g1 > 0 ? (stats1['ga'] ?? 0) / g1 : 0;
    double gaPg2 = g2 > 0 ? (stats2['ga'] ?? 0) / g2 : 0;

    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        title: const Text('X1 - Comparação', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Head-to-Head Header
            Row(
              children: [
                Expanded(child: _buildPlayerHeader(player1, colorP1, MainAxisAlignment.start)),
                const Text(' VS ', style: TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                Expanded(child: _buildPlayerHeader(player2, colorP2, MainAxisAlignment.end)),
              ],
            ),
            const SizedBox(height: 32),

            // Radar Chart Overlap
            if (_showRadarChart) ...[
              Container(
                height: 250,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.headerBlue, borderRadius: BorderRadius.circular(18)),
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
                      return RadarChartTitle(text: text, angle: angle);
                    },
                    dataSets: [
                      RadarDataSet(
                        fillColor: colorP1.withValues(alpha: 0.4),
                        borderColor: colorP1,
                        entryRadius: 3,
                        dataEntries: p1Scores.map((s) => RadarEntry(value: s)).toList(),
                      ),
                      RadarDataSet(
                        fillColor: colorP2.withValues(alpha: 0.4),
                        borderColor: colorP2,
                        entryRadius: 3,
                        dataEntries: p2Scores.map((s) => RadarEntry(value: s)).toList(),
                      )
                    ],
                  ),
                  swapAnimationDuration: const Duration(milliseconds: 150),
                  swapAnimationCurve: Curves.linear,
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Comparativo Numérico
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.headerBlue, borderRadius: BorderRadius.circular(18)),
              child: Column(
                children: [
                  const Text('Estatísticas Frente a Frente', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(color: Colors.white12, height: 24),
                  
                  if (h2hTotal > 0) ...[
                    const Text('Confronto Direto', style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildComparisonRow('Vitórias Diretas', p1WinsH2h, p2WinsH2h),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text('Empates: $h2hDraws / Total: $h2hTotal confrontos', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ),
                    const Divider(color: Colors.white12, height: 16),
                  ],
                  
                  _buildComparisonRow('Jogos Totais', stats1['games'] ?? 0, stats2['games'] ?? 0),
                  _buildComparisonRow('Nota Média',  stats1['nota'] ?? 0,  stats2['nota'] ?? 0, isDouble: true),
                  _buildComparisonRow('Aproveitamento (%)', aprov1, aprov2, isDouble: true),
                  _buildComparisonRow('Participações (G+A)', stats1['ga'] ?? 0, stats2['ga'] ?? 0),
                  _buildComparisonRow('G+A / Jogo', gaPg1, gaPg2, isDouble: true),
                  _buildComparisonRow('Gols',        stats1['goals'] ?? 0, stats2['goals'] ?? 0),
                  _buildComparisonRow('Assistências',stats1['assists'] ?? 0, stats2['assists'] ?? 0),
                  _buildComparisonRow('Vitórias',    stats1['wins'] ?? 0, stats2['wins'] ?? 0),
                  _buildComparisonRow('Clean Sheets',adv1['cleanSheets'] ?? 0, adv2['cleanSheets'] ?? 0),
                  _buildComparisonRow('Gols Contra', adv1['ownGoals'] ?? 0, adv2['ownGoals'] ?? 0, invertWinner: true),
                  _buildComparisonRow('Faltas Graves (A+V)', 
                    (stats1['yellow'] ?? 0) + (stats1['red'] ?? 0), 
                    (stats2['yellow'] ?? 0) + (stats2['red'] ?? 0), invertWinner: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
