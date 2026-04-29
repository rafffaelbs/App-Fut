import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_colors.dart';
import '../utils/player_identity.dart';
import '../utils/rating_calculator.dart';
import 'player_detail.dart';

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
  String _groupBy = 'A-Z';

  String get _storageKey => 'players_${widget.groupId}';

  static const List<String> _availableIcons = [
    'assets/players_icons/adriano.png',  'assets/players_icons/arrascaeta.png',
    'assets/players_icons/balota.png',   'assets/players_icons/bellingham.webp',
    'assets/players_icons/bruyne.png',   'assets/players_icons/courtois.png',
    'assets/players_icons/cr7.png',      'assets/players_icons/depay.png',
    'assets/players_icons/drogba.png',   'assets/players_icons/dybala.png',
    'assets/players_icons/gullit.png',   'assets/players_icons/haaland.png',
    'assets/players_icons/ibra.png',     'assets/players_icons/kaka.png',
    'assets/players_icons/kroos.png',    'assets/players_icons/love.png',
    'assets/players_icons/maldini.png',  'assets/players_icons/maradona.png',
    'assets/players_icons/mbappe.png',   'assets/players_icons/messi.png',
    'assets/players_icons/modric.png',   'assets/players_icons/mouse_hunter.png',
    'assets/players_icons/neuer.png',    'assets/players_icons/neymar.png',
    'assets/players_icons/ozil.png',     'assets/players_icons/pele.png',
    'assets/players_icons/pique.png',    'assets/players_icons/pirlo.png',
    'assets/players_icons/pogba.webp',   'assets/players_icons/puyol.png',
    'assets/players_icons/ramos.png',    'assets/players_icons/ribery.png',
    'assets/players_icons/robben.png',   'assets/players_icons/ronaldinho.png',
    'assets/players_icons/ronaldo.png',  'assets/players_icons/seedorf.png',
    'assets/players_icons/vegetti.png',  'assets/players_icons/vini.png',
    'assets/players_icons/xavi.png',     'assets/players_icons/zidane.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  // ─────────────────────────────────────────────────────────────
  // LÓGICA DE NEGÓCIO
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? playersString = prefs.getString(_storageKey);

    if (playersString != null) {
      final loaded = List<Map<String, dynamic>>.from(jsonDecode(playersString));
      setState(() { players = ensurePlayerIds(loaded); });
    }

    await _calculateDynamicRatings();
    setState(() => isLoading = false);
  }

  Future<void> _calculateDynamicRatings() async {
    final prefs = await SharedPreferences.getInstance();
    final String sessionsKey = 'sessions_${widget.groupId}';

    if (!prefs.containsKey(sessionsKey)) {
      setState(() {
        for (final p in players) {
          p['rating']     = kRatingBase;
          p['totalGames'] = 0;
        }
      });
      await _savePlayers();
      return;
    }

    final List<dynamic> allSessions = jsonDecode(prefs.getString(sessionsKey)!);
    final Map<String, Map<String, dynamic>> globalStats = {};

    for (final session in allSessions) {
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

        void processPlayer(dynamic playerObj, int status, int conceded) {
          if (playerObj == null) return;
          final String playerId = playerIdFromObject(playerObj);
          if (playerId.isEmpty || processed.contains(playerId)) return;
          processed.add(playerId);

          globalStats.putIfAbsent(playerId, () => {'games': 0, 'sum_ratings': 0.0});
          globalStats[playerId]!['games'] = (globalStats[playerId]!['games'] as int) + 1;

          final int g  = matchPlayerEvents[playerId]?['g']  ?? 0;
          final int a  = matchPlayerEvents[playerId]?['a']  ?? 0;
          final int og = matchPlayerEvents[playerId]?['og'] ?? 0;
          final int yc = matchPlayerEvents[playerId]?['yc'] ?? 0;
          final int rc = matchPlayerEvents[playerId]?['rc'] ?? 0;

          final double matchRating = calculateMatchRating(
            status: status, goals: g, assists: a,
            ownGoals: og, conceded: conceded, yellow: yc, red: rc,
          );
          globalStats[playerId]!['sum_ratings'] =
              (globalStats[playerId]!['sum_ratings'] as double) + matchRating;
        }

        if (match['players']['red']      != null) for (final p in match['players']['red'])   processPlayer(p, redStatus,   scoreWhite);
        if (match['players']['white']    != null) for (final p in match['players']['white']) processPlayer(p, whiteStatus, scoreRed);
        if (match['players']['gk_red']   != null) processPlayer(match['players']['gk_red'],   redStatus,   scoreWhite);
        if (match['players']['gk_white'] != null) processPlayer(match['players']['gk_white'], whiteStatus, scoreRed);
      }
    }

    setState(() {
      for (int i = 0; i < players.length; i++) {
        final String pId = (players[i]['id'] ?? '').toString();
        if (globalStats.containsKey(pId)) {
          final data    = globalStats[pId]!;
          final int games         = data['games'] as int;
          final double sumRatings = data['sum_ratings'] as double;
          players[i]['rating']     = calculateFinalRating(sumRatings: sumRatings, games: games);
          players[i]['totalGames'] = games;
        } else {
          players[i]['rating']     = kRatingBase;
          players[i]['totalGames'] = 0;
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
      players.add({'id': _uuid.v4(), 'name': name, 'rating': kRatingBase, 'totalGames': 0, 'icon': iconPath});
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

  // ─────────────────────────────────────────────────────────────
  // HELPERS DE COR / LABEL
  // ─────────────────────────────────────────────────────────────

  Color _ratingColor(double rating) {
    if (rating >= 9.0) return Colors.purpleAccent;
    if (rating >= 8.0) return Colors.green[700]!;
    if (rating >= 7.0) return Colors.green;
    if (rating >= 6.0) return Colors.lightGreenAccent;
    if (rating >= 5.0) return Colors.yellow;
    if (rating >= 4.0) return Colors.orange;
    return Colors.red;
  }

  String _ratingLabel(double rating, int games) {
    if (games < 5)     return 'Estreante';
    if (rating >= 8.5) return 'Elite';
    if (rating >= 7.5) return 'Ótimo';
    if (rating >= 6.0) return 'Bom';
    if (rating >= 4.5) return 'Regular';
    return 'Abaixo';
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS
  // ─────────────────────────────────────────────────────────────

  Widget _buildGroupingToggle() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _toggleOption('Alfabética (A-Z)', 'A-Z'),
          _toggleOption('Por Nível',        'Nível'),
        ],
      ),
    );
  }

  Widget _toggleOption(String label, String value) {
    final bool active = _groupBy == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _groupBy = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color:        active ? AppColors.accentBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color:      active ? Colors.white : Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
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
    final player   = players[index];
    final String name     = player['name'] ?? '';
    final String initial  = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final double rating   = player['rating'] != null ? (player['rating'] as num).toDouble() : kRatingBase;
    final int games       = player['totalGames'] ?? 0;
    final String? iconPath = player['icon'];
    final Color rColor    = _ratingColor(rating);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        AppColors.headerBlue,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlayerDetailScreen(
                  groupId:           widget.groupId,
                  playerId:          (player['id'] ?? '').toString(),
                  initialPlayerName: name,
                  playerIcon:        iconPath,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  backgroundColor: AppColors.deepBlue,
                  radius: 26,
                  child: iconPath != null
                      ? ClipOval(child: Padding(padding: const EdgeInsets.all(6), child: Image.asset(iconPath, fit: BoxFit.contain)))
                      : Text(initial, style: TextStyle(color: rColor, fontWeight: FontWeight.bold, fontSize: 20)),
                ),
                const SizedBox(width: 14),

                // Nome + barra de progresso
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
                                value:           rating / kMaxRating,
                                minHeight:       4,
                                backgroundColor: Colors.white10,
                                valueColor:      AlwaysStoppedAnimation<Color>(rColor.withValues(alpha: 0.7)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(_ratingLabel(rating, games), style: TextStyle(color: rColor, fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Badge de nota
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color:        rColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border:       Border.all(color: rColor.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(rating.toStringAsFixed(1), style: TextStyle(color: rColor, fontSize: 13, fontWeight: FontWeight.bold, height: 1)),
                      Text('/10', style: TextStyle(color: rColor.withValues(alpha: 0.5), fontSize: 9)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Botão remover
                GestureDetector(
                  onTap: () => _removePlayer(index),
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color:        Colors.redAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
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

  void _showAddPlayerDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title:   const Text('Novo Jogador', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style:      const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Nome', hintStyle: TextStyle(color: Colors.white30)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.white38))),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _addNewPlayer(controller.text.trim(), null);
                Navigator.pop(context);
              }
            },
            child: const Text('Salvar', style: TextStyle(color: AppColors.accentBlue)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final List<Widget> listItems = [];

    if (!isLoading && players.isNotEmpty) {
      listItems.add(_buildGroupingToggle());

      if (_groupBy == 'A-Z') {
        players.sort((a, b) =>
            (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));

        String currentLetter = '';
        for (int i = 0; i < players.length; i++) {
          final String letter = (players[i]['name'] as String)[0].toUpperCase();
          if (letter != currentLetter) {
            listItems.add(_buildSectionHeader(letter));
            currentLetter = letter;
          }
          listItems.add(_buildPlayerCard(i));
        }
      } else {
        players.sort((a, b) {
          final double rA = (a['rating'] ?? kRatingBase) as double;
          final double rB = (b['rating'] ?? kRatingBase) as double;
          return rB.compareTo(rA);
        });

        String currentLevel = '';
        for (int i = 0; i < players.length; i++) {
          final String level = _ratingLabel(
            (players[i]['rating'] ?? kRatingBase) as double,
            (players[i]['totalGames'] ?? 0) as int,
          );
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
              ? const Center(child: Text('Nenhum jogador no elenco.', style: TextStyle(color: Colors.white54)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: listItems,
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accentBlue,
        onPressed:       _showAddPlayerDialog,
        child:           const Icon(Icons.person_add_rounded, color: Colors.white),
      ),
    );
  }
}
