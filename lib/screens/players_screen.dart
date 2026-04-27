import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_colors.dart';
import 'player_detail.dart';
import '../utils/player_identity.dart';

class PlayersScreen extends StatefulWidget {
  final String groupId;

  const PlayersScreen({super.key, required this.groupId});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  static const Uuid _uuid = Uuid();
  List<Map<String, dynamic>> players = [];
  bool isLoading = true;
  String _groupBy = 'A-Z'; // Pode ser 'A-Z' ou 'Nível'

  String get _storageKey => 'players_${widget.groupId}';

  static const List<String> _availableIcons = [
    'assets/players_icons/adriano.png',
    'assets/players_icons/arrascaeta.png',
    'assets/players_icons/balota.png',
    'assets/players_icons/bellingham.webp',
    'assets/players_icons/bruyne.png',
    'assets/players_icons/courtois.png',
    'assets/players_icons/cr7.png',
    'assets/players_icons/depay.png',
    'assets/players_icons/drogba.png',
    'assets/players_icons/dybala.png',
    'assets/players_icons/gullit.png',
    'assets/players_icons/haaland.png',
    'assets/players_icons/ibra.png',
    'assets/players_icons/kaka.png',
    'assets/players_icons/kroos.png',
    'assets/players_icons/love.png',
    'assets/players_icons/maldini.png',
    'assets/players_icons/maradona.png',
    'assets/players_icons/mbappe.png',
    'assets/players_icons/messi.png',
    'assets/players_icons/modric.png',
    'assets/players_icons/mouse_hunter.png',
    'assets/players_icons/neuer.png',
    'assets/players_icons/neymar.png',
    'assets/players_icons/ozil.png',
    'assets/players_icons/pele.png',
    'assets/players_icons/pique.png',
    'assets/players_icons/pirlo.png',
    'assets/players_icons/pogba.webp',
    'assets/players_icons/puyol.png',
    'assets/players_icons/ramos.png',
    'assets/players_icons/ribery.png',
    'assets/players_icons/robben.png',
    'assets/players_icons/ronaldinho.png',
    'assets/players_icons/ronaldo.png',
    'assets/players_icons/seedorf.png',
    'assets/players_icons/vegetti.png',
    'assets/players_icons/vini.png',
    'assets/players_icons/xavi.png',
    'assets/players_icons/zidane.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? playersString = prefs.getString(_storageKey);
    
    if (playersString != null) {
      final loaded = List<Map<String, dynamic>>.from(jsonDecode(playersString));
      setState(() {
        players = ensurePlayerIds(loaded);
      });
    }
    
    await _calculateDynamicRatings();
    setState(() => isLoading = false);
  }

  // --- MOTOR SOFASCORE DINÂMICO PARA ELENCO (Omitido as partes inalteradas para poupar espaço) ---
  Future<void> _calculateDynamicRatings() async {
    final prefs = await SharedPreferences.getInstance();
    final String sessionsKey = 'sessions_${widget.groupId}';
    
    if (!prefs.containsKey(sessionsKey)) {
      setState(() {
        for (var p in players) p['rating'] = 5.0;
      });
      await _savePlayers();
      return;
    }

    final List<dynamic> allSessions = jsonDecode(prefs.getString(sessionsKey)!);
    final Map<String, Map<String, dynamic>> globalStats = {};

    for (var session in allSessions) {
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

          globalStats.putIfAbsent(playerId, () => {'goals': 0, 'assists': 0, 'own_goals': 0, 'games': 0, 'wins': 0, 'draws': 0, 'losses': 0, 'goals_conceded': 0, 'clean_sheets': 0});
          
          globalStats[playerId]!['games'] = (globalStats[playerId]!['games'] as int) + 1;
          globalStats[playerId]!['goals_conceded'] = (globalStats[playerId]!['goals_conceded'] as int) + goalsConceded;
          if (goalsConceded == 0) globalStats[playerId]!['clean_sheets'] = (globalStats[playerId]!['clean_sheets'] as int) + 1;

          if (status == 1) globalStats[playerId]!['wins'] = (globalStats[playerId]!['wins'] as int) + 1;
          else if (status == -1) globalStats[playerId]!['losses'] = (globalStats[playerId]!['losses'] as int) + 1;
          else globalStats[playerId]!['draws'] = (globalStats[playerId]!['draws'] as int) + 1;
        }

        if (match['players']['red'] != null) for (var p in match['players']['red']) processPlayer(p, redStatus, scoreWhite);
        if (match['players']['white'] != null) for (var p in match['players']['white']) processPlayer(p, whiteStatus, scoreRed);
        if (match['players']['gk_red'] != null) processPlayer(match['players']['gk_red'], redStatus, scoreWhite);
        if (match['players']['gk_white'] != null) processPlayer(match['players']['gk_white'], whiteStatus, scoreRed);

        if (match['events'] != null) {
          for (var event in match['events']) {
            final scorerId = eventPlayerId(event, 'player');
            if (event['type'] == 'goal') {
              if (globalStats.containsKey(scorerId)) globalStats[scorerId]!['goals'] = (globalStats[scorerId]!['goals'] as int) + 1;
              final assistId = eventPlayerId(event, 'assist');
              if (assistId.isNotEmpty && globalStats.containsKey(assistId)) globalStats[assistId]!['assists'] = (globalStats[assistId]!['assists'] as int) + 1;
            } else if (event['type'] == 'own_goal') {
              if (globalStats.containsKey(scorerId)) globalStats[scorerId]!['own_goals'] = (globalStats[scorerId]!['own_goals'] as int) + 1;
            }
          }
        }
      }
    }

    setState(() {
      for (var i = 0; i < players.length; i++) {
        String pId = (players[i]['id'] ?? '').toString();
        if (globalStats.containsKey(pId)) {
          var data = globalStats[pId]!;
          int games = data['games'] as int;
          if (games > 0) {
            double resultImpact = ((data['wins'] as int) * 1.0) + ((data['draws'] as int) * 0.5) + ((data['losses'] as int) * -0.5);
            double attackImpact = ((data['goals'] as int) * 0.8) + ((data['assists'] as int) * 0.3) + ((data['own_goals'] as int) * -0.8);
            double defenseImpact = 0.0;
            if (games >= 5) {
              defenseImpact = ((data['clean_sheets'] as int) * 0.5) + ((data['goals_conceded'] as int) * -0.15);
            }
            double performance = (resultImpact + attackImpact + defenseImpact) / games;
            double nota = 5.0 + (performance * 2.0); 
            players[i]['rating'] = nota.clamp(0.0, 10.0);
          } else {
            players[i]['rating'] = 5.0;
          }
        } else {
          players[i]['rating'] = 5.0;
        }
      }
    });

    await _savePlayers(); 
  }

  Future<void> _savePlayers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(players));
  }

  void _addNewPlayer(String name, String? iconPath) {
    setState(() {
      players.add({
        'id': _uuid.v4(),
        'name': name,
        'rating': 5.0,
        'icon': iconPath,
      });
    });
    _savePlayers();
  }

  void _removePlayer(int index) {
    setState(() => players.removeAt(index));
    _savePlayers();
  }

  void _updatePlayerIcon(int index, String iconPath) {
    setState(() => players[index]['icon'] = iconPath);
    _savePlayers();
  }

  // ── RATING COLOR ────────────────────────────────────────────
  Color _ratingColor(double rating) {
    if (rating >= 8.0) return const Color(0xFF4CAF50);
    if (rating >= 6.0) return Colors.amber;
    if (rating >= 4.0) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  String _ratingLabel(double rating) {
    if (rating >= 9.0) return 'Elite';
    if (rating >= 7.5) return 'Ótimo';
    if (rating >= 6.0) return 'Bom';
    if (rating >= 4.0) return 'Regular';
    return 'Iniciante';
  }

  // ── UI COMPONENTS ─────────────────────────────────────────────
  
  Widget _buildGroupingToggle() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _groupBy = 'A-Z'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _groupBy == 'A-Z' ? AppColors.accentBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text("Alfabética (A-Z)", style: TextStyle(color: _groupBy == 'A-Z' ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _groupBy = 'Nível'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _groupBy == 'Nível' ? AppColors.accentBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text("Por Nível", style: TextStyle(color: _groupBy == 'Nível' ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12, left: 4),
      child: Row(
        children: [
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: Colors.white12)),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(int index) {
    final player = players[index];
    final String name = player['name'] ?? '';
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final double rating = player['rating'] != null ? (player['rating'] as num).toDouble() : 5.0;
    final String? iconPath = player['icon'];
    final Color rColor = _ratingColor(rating);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlayerDetailScreen(
                  groupId: widget.groupId,
                  playerId: (player['id'] ?? '').toString(),
                  initialPlayerName: name,
                  playerIcon: iconPath,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.deepBlue,
                  radius: 26,
                  child: iconPath != null
                      ? ClipOval(child: Padding(padding: const EdgeInsets.all(6), child: Image.asset(iconPath, fit: BoxFit.contain)))
                      : Text(initial, style: TextStyle(color: rColor, fontWeight: FontWeight.bold, fontSize: 20)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: rating / 10.0,
                                minHeight: 4,
                                backgroundColor: Colors.white10,
                                valueColor: AlwaysStoppedAnimation<Color>(rColor.withValues(alpha: 0.7)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(_ratingLabel(rating), style: TextStyle(color: rColor, fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: rColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: rColor.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(rating.toStringAsFixed(1), style: TextStyle(color: rColor, fontSize: 13, fontWeight: FontWeight.bold, height: 1)),
                      Text("/10", style: TextStyle(color: rColor.withValues(alpha: 0.5), fontSize: 9)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _removePlayer(index),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 17),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> listItems = [];
    
    if (!isLoading && players.isNotEmpty) {
      listItems.add(_buildGroupingToggle());

      if (_groupBy == 'A-Z') {
        players.sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));
        String currentLetter = '';
        for (int i = 0; i < players.length; i++) {
          String letter = (players[i]['name'] as String)[0].toUpperCase();
          if (letter != currentLetter) {
            listItems.add(_buildSectionHeader(letter));
            currentLetter = letter;
          }
          listItems.add(_buildPlayerCard(i));
        }
      } else {
        players.sort((a, b) {
          double rA = a['rating'] ?? 5.0;
          double rB = b['rating'] ?? 5.0;
          return rB.compareTo(rA); // Os melhores primeiro
        });
        String currentLevel = '';
        for (int i = 0; i < players.length; i++) {
          String level = _ratingLabel(players[i]['rating'] ?? 5.0);
          if (level != currentLevel) {
            listItems.add(_buildSectionHeader(level));
            currentLevel = level;
          }
          listItems.add(_buildPlayerCard(i));
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentBlue))
          : players.isEmpty
          ? const Center(child: Text("Nenhum jogador no elenco.", style: TextStyle(color: Colors.white54)))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: listItems,
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accentBlue,
        onPressed: () { /* Manter lógica anterior do Add Player Dialog */ },
        child: const Icon(Icons.person_add_rounded, color: Colors.white),
      ),
    );
  }
}
