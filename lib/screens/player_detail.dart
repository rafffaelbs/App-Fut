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

  Map<String, dynamic> advancedStats = {};

  @override
  void initState() {
    super.initState();
    _loadPlayerDetails();
  }

  Future<void> _loadPlayerDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic>? player = await _loadPlayer(prefs);
    final String? icon = widget.playerIcon ?? player?['icon'] as String?;
    final String resolvedName = (player?['name'] ?? widget.initialPlayerName ?? '').toString();

    // 1. Extrai TODO o histórico de partidas do grupo
    final String sessionsKey = 'sessions_${widget.groupId}';
    List<dynamic> allHistory = [];

    if (prefs.containsKey(sessionsKey)) {
      final List<dynamic> sessions = jsonDecode(prefs.getString(sessionsKey)!);
      for (var session in sessions) {
        final String? tId = session['id'];
        if (tId != null) {
          final String historyKey = 'match_history_$tId';
          if (prefs.containsKey(historyKey)) {
            allHistory.addAll(jsonDecode(prefs.getString(historyKey)!));
          }
        }
      }
    }

    // 2. Calcula as estatísticas base
    final List<Map<String, dynamic>> leaderboard = _calculateAllTimeLeaderboard(allHistory);
    final int index = leaderboard.indexWhere(
      (p) => (p['id'] as String) == widget.playerId,
    );

    // 3. Calcula as novas estatísticas avançadas de relacionamento
    final Map<String, dynamic> advStats = _calculateAdvancedStats(allHistory);

    setState(() {
      resolvedIcon = icon;
      playerName = resolvedName;
      totalPlayers = leaderboard.length;
      advancedStats = advStats;
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

  // --- NOVA FUNÇÃO: CALCULAR RELACIONAMENTOS ---
  Map<String, dynamic> _calculateAdvancedStats(List<dynamic> allHistory) {
    Map<String, int> assistsGiven = {}; // Maior garçom de quem
    Map<String, int> assistsReceived = {}; // Quem mais tocou pra ele
    Map<String, int> gamesWith = {};
    Map<String, int> winsWith = {};
    Map<String, int> lossesWith = {};
    Map<String, int> winsAgainst = {};
    Map<String, int> lossesAgainst = {};
    Map<String, int> drawsAgainst = {};
    int hatTricks = 0;
    
    Map<String, String> playerNamesMap = {};
    final String myId = widget.playerId;

    for (final match in allHistory) {
      final List<dynamic> redPlayers = [...(match['players']['red'] ?? []), match['players']['gk_red']].where((p) => p != null).toList();
      final List<dynamic> whitePlayers = [...(match['players']['white'] ?? []), match['players']['gk_white']].where((p) => p != null).toList();

      // Mapeia nomes para ID caso precisemos exibir depois
      void registerName(dynamic p) {
        String id = playerIdFromObject(p);
        if (id.isNotEmpty && !playerNamesMap.containsKey(id)) {
          playerNamesMap[id] = (p['name'] ?? '').toString();
        }
      }
      redPlayers.forEach(registerName);
      whitePlayers.forEach(registerName);

      bool inRed = redPlayers.any((p) => playerIdFromObject(p) == myId);
      bool inWhite = whitePlayers.any((p) => playerIdFromObject(p) == myId);
      
      if (!inRed && !inWhite) continue; // Não jogou essa partida

      String myTeam = inRed ? 'red' : 'white';
      int scoreRed = match['scoreRed'] ?? 0;
      int scoreWhite = match['scoreWhite'] ?? 0;
      
      int myTeamResult = 0; // 1: Vit, -1: Der, 0: Empate
      if (scoreRed != scoreWhite) {
        myTeamResult = (myTeam == 'red' && scoreRed > scoreWhite) || (myTeam == 'white' && scoreWhite > scoreRed) ? 1 : -1;
      }

      List<dynamic> teammates = myTeam == 'red' ? redPlayers : whitePlayers;
      List<dynamic> opponents = myTeam == 'red' ? whitePlayers : redPlayers;

      // Stats Com Teammates
      for (var t in teammates) {
        String tId = playerIdFromObject(t);
        if (tId == myId || tId.isEmpty) continue;
        gamesWith[tId] = (gamesWith[tId] ?? 0) + 1;
        if (myTeamResult == 1) winsWith[tId] = (winsWith[tId] ?? 0) + 1;
        if (myTeamResult == -1) lossesWith[tId] = (lossesWith[tId] ?? 0) + 1;
      }

      // Stats Com Adversários
      for (var o in opponents) {
        String oId = playerIdFromObject(o);
        if (oId == myId || oId.isEmpty) continue;
        if (myTeamResult == 1) winsAgainst[oId] = (winsAgainst[oId] ?? 0) + 1;
        if (myTeamResult == -1) lossesAgainst[oId] = (lossesAgainst[oId] ?? 0) + 1;
        if (myTeamResult == 0) drawsAgainst[oId] = (drawsAgainst[oId] ?? 0) + 1;
      }

      // Gols e Assistências (Hat-tricks e Garçons)
      int goalsInThisMatch = 0;
      if (match['events'] != null) {
        for (var ev in match['events']) {
          if (ev['type'] != 'goal') continue;
          String scorerId = eventPlayerId(ev, 'player');
          String assistId = eventPlayerId(ev, 'assist');

          if (scorerId == myId) {
            goalsInThisMatch++;
            if (assistId.isNotEmpty && assistId != myId) {
              assistsReceived[assistId] = (assistsReceived[assistId] ?? 0) + 1;
            }
          }
          if (assistId == myId && scorerId != myId && scorerId.isNotEmpty) {
            assistsGiven[scorerId] = (assistsGiven[scorerId] ?? 0) + 1;
          }
        }
      }

      if (goalsInThisMatch >= 3) {
        hatTricks++;
      }
    }

    // Função auxiliar para achar o "Maior" de cada categoria
    Map<String, dynamic> findMax(Map<String, int> map) {
      if (map.isEmpty) return {'name': '-', 'count': 0};
      var entries = map.entries.toList();
      entries.sort((a, b) => b.value.compareTo(a.value)); // Maior pro menor
      String topId = entries.first.key;
      return {'name': playerNamesMap[topId] ?? 'Desconhecido', 'count': entries.first.value};
    }

    return {
      'topAssisted': findMax(assistsGiven),
      'topAssister': findMax(assistsReceived),
      'mostPlayedWith': findMax(gamesWith),
      'mostWinsWith': findMax(winsWith),
      'mostLossesWith': findMax(lossesWith),
      'mostWinsAgainst': findMax(winsAgainst),
      'mostLossesAgainst': findMax(lossesAgainst),
      'mostDrawsAgainst': findMax(drawsAgainst),
      'hatTricks': hatTricks,
    };
  }

  // --- STATS GERAIS DO JOGADOR ---
  List<Map<String, dynamic>> _calculateAllTimeLeaderboard(List<dynamic> allHistory) {
    final Map<String, Map<String, dynamic>> stats = {};

    for (final match in allHistory) {
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
        for (final p in match['players']['red']) processPlayer(p, redStatus);
      }
      if (match['players']['white'] != null) {
        for (final p in match['players']['white']) processPlayer(p, whiteStatus);
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

  Future<Map<String, dynamic>?> _loadPlayer(SharedPreferences prefs) async {
    final String playersKey = 'players_${widget.groupId}';
    if (!prefs.containsKey(playersKey)) return null;

    final List<Map<String, dynamic>> loaded = List<Map<String, dynamic>>.from(
      jsonDecode(prefs.getString(playersKey)!),
    );
    final List<Map<String, dynamic>> players = ensurePlayerIds(loaded);

    for (final player in players) {
      if ((player['id'] ?? '').toString() == widget.playerId) return player;
    }
    return null;
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
                              ? 'Ranking Histórico Geral: #$rankPosition / $totalPlayers'
                              : 'Ranking Histórico: sem dados',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
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
                            _statValue('Assistências', '${playerStats['assists'] ?? 0}', Colors.amber),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            _resultColumn('Vitórias', wins, Colors.greenAccent),
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
                                      Expanded(flex: wins == 0 ? 1 : wins, child: const ColoredBox(color: Colors.green)),
                                      Expanded(flex: draws == 0 ? 1 : draws, child: const ColoredBox(color: Colors.black54)),
                                      Expanded(flex: losses == 0 ? 1 : losses, child: const ColoredBox(color: Colors.red)),
                                    ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // --- NOVA SESSÃO: CURIOSIDADES E RELACIONAMENTOS ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.headerBlue,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.psychology, color: AppColors.accentBlue),
                            SizedBox(width: 8),
                            Text(
                              "Estatísticas Avançadas",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        _buildAdvStatRow("Hat-Tricks (3 Gols/Jogo)", "${advancedStats['hatTricks'] ?? 0} marcados", Icons.whatshot, Colors.orangeAccent),
                        const Divider(color: Colors.white12, height: 24),
                        
                        _buildAdvStatRow("Maior Garçom De", _formatAdvStat(advancedStats['topAssisted'], "gols"), Icons.sports_soccer, Colors.greenAccent),
                        _buildAdvStatRow("Garçom Favorito", _formatAdvStat(advancedStats['topAssister'], "passes"), Icons.handshake, Colors.amber),
                        const Divider(color: Colors.white12, height: 24),
                        
                        _buildAdvStatRow("Mais Jogou Junto", _formatAdvStat(advancedStats['mostPlayedWith'], "jogos"), Icons.people, Colors.white),
                        _buildAdvStatRow("Mais Venceu Junto", _formatAdvStat(advancedStats['mostWinsWith'], "vitórias"), Icons.thumb_up, Colors.green),
                        _buildAdvStatRow("Mais Perdeu Junto", _formatAdvStat(advancedStats['mostLossesWith'], "derrotas"), Icons.thumb_down, Colors.redAccent),
                        const Divider(color: Colors.white12, height: 24),
                        
                        _buildAdvStatRow("Maior Freguês (Contra)", _formatAdvStat(advancedStats['mostWinsAgainst'], "vitórias"), Icons.mood, Colors.blueAccent),
                        _buildAdvStatRow("Carrasco (Contra)", _formatAdvStat(advancedStats['mostLossesAgainst'], "derrotas"), Icons.mood_bad, Colors.red),
                        _buildAdvStatRow("Rival Equilibrado", _formatAdvStat(advancedStats['mostDrawsAgainst'], "empates"), Icons.balance, Colors.grey),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Helper para formatar os textos da estatística avançada
  String _formatAdvStat(dynamic stat, String suffix) {
    if (stat == null || stat['count'] == 0) return "-";
    return "${stat['name']} (${stat['count']} $suffix)";
  }

  // Layout de uma linha da estatística avançada
  Widget _buildAdvStatRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.deepBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statValue(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(color: valueColor, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
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
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
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
        title: const Text('Editar jogador', style: TextStyle(color: AppColors.textWhite)),
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
