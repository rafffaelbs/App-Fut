import 'dart:convert';

import 'package:app_do_fut/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String? selectedTournamentId;
  int? rankPosition;
  int totalPlayers = 0;
  String playerName = '';
  String? resolvedIcon;

  Map<String, dynamic> playerStats = {
    'name': '',
    'goals': 0,
    'assists': 0,
    'ga': 0,
    'games': 0,
    'wins': 0,
    'draws': 0,
    'losses': 0,
    'nota': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _loadPlayerDetails();
  }

  Future<void> _loadPlayerDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tournament = widget.tournamentId ?? await _resolveTournamentId(prefs);
    final Map<String, dynamic>? player = await _loadPlayer(prefs);
    final String? icon = widget.playerIcon ?? player?['icon'] as String?;
    final String resolvedName =
        (player?['name'] ?? widget.initialPlayerName ?? '').toString();

    if (tournament == null) {
      setState(() {
        playerName = resolvedName;
        playerStats['name'] = resolvedName;
        resolvedIcon = icon;
        isLoading = false;
      });
      return;
    }

    final List<Map<String, dynamic>> leaderboard = _calculateLeaderboard(
      prefs: prefs,
      tournamentId: tournament,
    );
    final int index = leaderboard.indexWhere(
      (p) => (p['id'] as String) == widget.playerId,
    );

    setState(() {
      selectedTournamentId = tournament;
      resolvedIcon = icon;
      playerName = resolvedName;
      totalPlayers = leaderboard.length;
      if (index >= 0) {
        rankPosition = index + 1;
        playerStats = leaderboard[index];
      } else {
        playerStats['id'] = widget.playerId;
        playerStats['name'] = resolvedName;
      }
      isLoading = false;
    });
  }

  Future<String?> _resolveTournamentId(SharedPreferences prefs) async {
    final String sessionsKey = 'sessions_${widget.groupId}';
    if (!prefs.containsKey(sessionsKey)) return null;

    final List<Map<String, dynamic>> sessions = List<Map<String, dynamic>>.from(
      jsonDecode(prefs.getString(sessionsKey)!),
    );

    if (sessions.isEmpty) return null;

    final DateTime now = DateTime.now();
    final List<Map<String, dynamic>> currentMonthSessions = sessions.where((session) {
      final String? timestamp = session['timestamp'];
      if (timestamp == null) return false;
      final DateTime? date = DateTime.tryParse(timestamp);
      if (date == null) return false;
      return date.year == now.year && date.month == now.month;
    }).toList();

    currentMonthSessions.sort((a, b) {
      final DateTime da = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(1970);
      final DateTime db = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(1970);
      return db.compareTo(da);
    });

    if (currentMonthSessions.isNotEmpty) {
      return currentMonthSessions.first['id'];
    }

    sessions.sort((a, b) {
      final DateTime da = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(1970);
      final DateTime db = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(1970);
      return db.compareTo(da);
    });

    return sessions.first['id'];
  }

  Future<Map<String, dynamic>?> _loadPlayer(SharedPreferences prefs) async {
    final String playersKey = 'players_${widget.groupId}';
    if (!prefs.containsKey(playersKey)) return null;

    final List<Map<String, dynamic>> loaded = List<Map<String, dynamic>>.from(
      jsonDecode(prefs.getString(playersKey)!),
    );
    final List<Map<String, dynamic>> players = ensurePlayerIds(loaded);
    if (loaded.any((p) => p['id'] == null || p['id'].toString().trim().isEmpty)) {
      await prefs.setString(playersKey, jsonEncode(players));
    }

    for (final player in players) {
      if ((player['id'] ?? '').toString() == widget.playerId) return player;
    }
    return null;
  }

  List<Map<String, dynamic>> _calculateLeaderboard({
    required SharedPreferences prefs,
    required String tournamentId,
  }) {
    final String historyKey = 'match_history_$tournamentId';
    if (!prefs.containsKey(historyKey)) return [];

    final List<dynamic> history = jsonDecode(prefs.getString(historyKey)!);
    final Map<String, Map<String, dynamic>> stats = {};

    for (final match in history) {
      final int scoreRed = match['scoreRed'] ?? 0;
      final int scoreWhite = match['scoreWhite'] ?? 0;

      final int redStatus = scoreRed > scoreWhite ? 1 : (scoreRed == scoreWhite ? 0 : -1);
      final int whiteStatus = scoreWhite > scoreRed ? 1 : (scoreRed == scoreWhite ? 0 : -1);
      final Set<String> processed = {};

      void processPlayer(dynamic playerObj, int status) {
        if (playerObj == null) return;
        final String playerId = playerIdFromObject(playerObj);
        if (playerId.isEmpty) return;
        if (processed.contains(playerId)) return;
        processed.add(playerId);
        final String playerDisplayName = (playerObj['name'] ?? '').toString();

        stats.putIfAbsent(
          playerId,
          () => {
            'id': playerId,
            'name': playerDisplayName,
            'goals': 0,
            'assists': 0,
            'games': 0,
            'wins': 0,
            'draws': 0,
            'losses': 0,
          },
        );
        if (playerDisplayName.isNotEmpty) {
          stats[playerId]!['name'] = playerDisplayName;
        }

        stats[playerId]!['games'] = (stats[playerId]!['games'] as int) + 1;
        if (status == 1) {
          stats[playerId]!['wins'] = (stats[playerId]!['wins'] as int) + 1;
        } else if (status == -1) {
          stats[playerId]!['losses'] = (stats[playerId]!['losses'] as int) + 1;
        } else {
          stats[playerId]!['draws'] = (stats[playerId]!['draws'] as int) + 1;
        }
      }

      if (match['players']['red'] != null) {
        for (final p in match['players']['red']) {
          processPlayer(p, redStatus);
        }
      }
      if (match['players']['white'] != null) {
        for (final p in match['players']['white']) {
          processPlayer(p, whiteStatus);
        }
      }
      if (match['players']['gk_red'] != null) {
        processPlayer(match['players']['gk_red'], redStatus);
      }
      if (match['players']['gk_white'] != null) {
        processPlayer(match['players']['gk_white'], whiteStatus);
      }

      if (match['events'] != null) {
        for (final event in match['events']) {
          if (event['type'] != 'goal') continue;

          final String scorerId = eventPlayerId(event, 'player');
          if (scorerId.isNotEmpty && stats.containsKey(scorerId)) {
            stats[scorerId]!['goals'] = (stats[scorerId]!['goals'] as int) + 1;
          }

          final String assistId = eventPlayerId(event, 'assist');
          if (assistId.isNotEmpty && stats.containsKey(assistId)) {
            stats[assistId]!['assists'] = (stats[assistId]!['assists'] as int) + 1;
          }
        }
      }
    }

    final List<Map<String, dynamic>> sortedList = [];
    stats.forEach((id, data) {
      final int g = data['goals'] as int;
      final int a = data['assists'] as int;
      final int games = data['games'] as int;
      final int w = data['wins'] as int;
      final int d = data['draws'] as int;
      final int l = data['losses'] as int;

      double nota = 0.0;
      if (games > 0) {
        final double matchResultImpact = ((w * 1.5) + (d * 0.5) + (l * -0.5));
        final double contributionImpact = ((g * 1.0) + (a * 0.7));
        nota = 5.0 + ((matchResultImpact + contributionImpact) / games);
        if (nota > 10.0) nota = 10.0;
        if (nota < 0.0) nota = 0.0;
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
      final int compareGA = (b['ga'] as int).compareTo(a['ga'] as int);
      if (compareGA != 0) return compareGA;
      return (b['nota'] as double).compareTo(a['nota'] as double);
    });

    return sortedList;
  }

  @override
  Widget build(BuildContext context) {
    final int wins = playerStats['wins'] ?? 0;
    final int draws = playerStats['draws'] ?? 0;
    final int losses = playerStats['losses'] ?? 0;
    final int totalResults = wins + draws + losses;
    final String displayName = playerName.isNotEmpty ? playerName : (widget.initialPlayerName ?? 'Jogador');
    final String initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
        centerTitle: true,
        elevation: 0,
        title: const Text(
          'Detalhes do Jogador',
          style: TextStyle(color: AppColors.textWhite),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentBlue),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.headerBlue,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10, width: 1),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.deepBlue,
                          child: resolvedIcon != null
                              ? ClipOval(
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Image.asset(
                                      resolvedIcon!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Text(
                                        initial,
                                        style: const TextStyle(
                                          color: AppColors.textWhite,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 26,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Text(
                                  initial,
                                  style: const TextStyle(
                                    color: AppColors.textWhite,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 26,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: AppColors.textWhite,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _showEditNameDialog,
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Editar nome'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          rankPosition != null
                              ? 'Current Month Ranking: #$rankPosition / $totalPlayers'
                              : 'Current Month Ranking: sem dados',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        if (selectedTournamentId != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Sessao: $selectedTournamentId',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.headerBlue,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _statValue('G+A', '${playerStats['ga'] ?? 0}', AppColors.highlightGreen),
                            _statValue('Gols', '${playerStats['goals'] ?? 0}', AppColors.textWhite),
                            _statValue('Assistencias', '${playerStats['assists'] ?? 0}', Colors.amber),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            _resultColumn('Vitorias', wins, Colors.greenAccent),
                            _resultColumn('Empates', draws, Colors.grey.shade300),
                            _resultColumn('Derrotas', losses, Colors.redAccent),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            height: 14,
                            child: Row(
                              children: totalResults == 0
                                  ? const [
                                      Expanded(flex: 1, child: ColoredBox(color: Color(0x334CAF50))),
                                      Expanded(flex: 1, child: ColoredBox(color: Color(0x33424242))),
                                      Expanded(flex: 1, child: ColoredBox(color: Color(0x33F44336))),
                                    ]
                                  : [
                                      Expanded(
                                        flex: wins == 0 ? 1 : wins,
                                        child: const ColoredBox(color: Colors.green),
                                      ),
                                      Expanded(
                                        flex: draws == 0 ? 1 : draws,
                                        child: const ColoredBox(color: Colors.black54),
                                      ),
                                      Expanded(
                                        flex: losses == 0 ? 1 : losses,
                                        child: const ColoredBox(color: Colors.red),
                                      ),
                                    ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statValue(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultColumn(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditNameDialog() async {
    final controller = TextEditingController(text: playerName);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text(
          'Editar jogador',
          style: TextStyle(color: AppColors.textWhite),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Nome',
            labelStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              await _savePlayerName(newName);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text(
              'Salvar',
              style: TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
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

    setState(() {
      playerName = newName;
      playerStats['name'] = newName;
    });
  }
}
