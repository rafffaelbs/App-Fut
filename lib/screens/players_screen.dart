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
      final normalized = ensurePlayerIds(loaded);
      setState(() {
        players = normalized;
        players.sort(
          (a, b) => (a['name'] as String).toLowerCase().compareTo(
            (b['name'] as String).toLowerCase(),
          ),
        );
      });
    }
    
    // Após carregar, força a atualização das notas SofaScore e salva
    await _calculateDynamicRatings();
    setState(() => isLoading = false);
  }

  // --- MOTOR SOFASCORE DINÂMICO PARA ELENCO ---
  Future<void> _calculateDynamicRatings() async {
    final prefs = await SharedPreferences.getInstance();
    final String sessionsKey = 'sessions_${widget.groupId}';
    
    if (!prefs.containsKey(sessionsKey)) {
      // Se não há sessões, garante que todos tenham nota 5.0
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
        if (match['players']['gk_red'] != null) processPlayer(match['players']['gk_red'], redStatus, scoreWhite);
        if (match['players']['gk_white'] != null) processPlayer(match['players']['gk_white'], whiteStatus, scoreRed);

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
            double nota = 5.0 + (performance * 2.0); // O multiplicador mágico
            players[i]['rating'] = nota.clamp(0.0, 10.0);
          } else {
            players[i]['rating'] = 5.0;
          }
        } else {
          players[i]['rating'] = 5.0; // Padrão se não tiver jogos
        }
      }
    });

    await _savePlayers(); // Salva a nota dinâmica para que outras telas possam usar
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
        'rating': 5.0, // <-- Removemos a nota manual. Todo mundo começa com 5.0.
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

  // ── ICON PICKER BOTTOM SHEET ────────────────────────────────
  void _showIconPicker({
    required void Function(String) onSelected,
    String? currentIcon,
  }) {
    final List<String> takenIcons = players
        .map((p) => p['icon'] as String?)
        .where((icon) => icon != null && icon != currentIcon)
        .cast<String>()
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.headerBlue,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                "Escolher Ícone",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 400,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: (_availableIcons.length / 4).ceil(),
                  itemBuilder: (ctx, rowIndex) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: List.generate(4, (colIndex) {
                          final iconIndex = rowIndex * 4 + colIndex;
                          if (iconIndex >= _availableIcons.length) {
                            return const Expanded(child: SizedBox());
                          }

                          final path = _availableIcons[iconIndex];
                          final bool selected = currentIcon == path;
                          final bool isTaken = takenIcons.contains(path);

                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: colIndex < 3 ? 12 : 0,
                              ),
                              child: GestureDetector(
                                onTap: isTaken
                                    ? null
                                    : () {
                                        onSelected(path);
                                        Navigator.pop(ctx);
                                      },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: selected
                                        ? AppColors.accentBlue.withValues(
                                            alpha: 0.25,
                                          )
                                        : (isTaken
                                              ? Colors.black26
                                              : AppColors.deepBlue.withValues(
                                                  alpha: 0.6,
                                                )),
                                    border: Border.all(
                                      color: selected
                                          ? AppColors.accentBlue
                                          : (isTaken
                                                ? Colors.transparent
                                                : Colors.white12),
                                      width: selected ? 2 : 1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: Opacity(
                                    opacity: isTaken ? 0.2 : 1.0,
                                    child: Image.asset(
                                      path,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.person_outline,
                                        color: Colors.white38,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── ADD PLAYER DIALOG ───────────────────────────────────────
  void _showAddPlayerDialog() {
    final TextEditingController controller = TextEditingController();
    String? selectedIcon;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: AppColors.headerBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Novo Jogador',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Icon selector
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          _showIconPicker(
                            currentIcon: selectedIcon,
                            onSelected: (path) {
                              setStateDialog(() => selectedIcon = path);
                            },
                          );
                        },
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.deepBlue,
                                border: Border.all(
                                  color: AppColors.accentBlue.withValues(
                                    alpha: 0.4,
                                  ),
                                  width: 1.5,
                                ),
                              ),
                              child: selectedIcon != null
                                  ? ClipOval(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Image.asset(
                                          selectedIcon!,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, _, _) => const Icon(
                                            Icons.person_outline,
                                            color: Colors.white38,
                                            size: 32,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_outline,
                                      color: Colors.white38,
                                      size: 32,
                                    ),
                            ),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.accentBlue,
                              ),
                              child: const Icon(
                                Icons.add,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        "Toque para escolher ícone",
                        style: TextStyle(color: Colors.white30, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Name field
                    TextField(
                      controller: controller,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: "Nome do jogador",
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: AppColors.deepBlue.withValues(alpha: 0.6),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: AppColors.accentBlue.withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(color: Colors.white38),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (controller.text.trim().isNotEmpty) {
                                _addNewPlayer(
                                  controller.text.trim(),
                                  selectedIcon,
                                );
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Salvar',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── RATING COLOR ────────────────────────────────────────────
  Color _ratingColor(double rating) {
    if (rating >= 8.0) return const Color(0xFF4CAF50);
    if (rating >= 6.0) return Colors.amber;
    if (rating >= 4.0) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  // ── RATING LABEL ────────────────────────────────────────────
  String _ratingLabel(double rating) {
    if (rating >= 9.0) return 'Elite';
    if (rating >= 7.5) return 'Ótimo';
    if (rating >= 6.0) return 'Bom';
    if (rating >= 4.0) return 'Regular';
    return 'Iniciante';
  }

  // ── PLAYER CARD ─────────────────────────────────────────────
  Widget _buildPlayerCard(int index) {
    final player = players[index];
    final String name = player['name'] ?? '';
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final double rating = player['rating'] != null
        ? (player['rating'] as num).toDouble()
        : 5.0;
    final String? iconPath = player['icon'];
    final Color rColor = _ratingColor(rating);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
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
            // ── Avatar with icon-change tap ──────────────────
            GestureDetector(
              onTap: () {
                _showIconPicker(
                  currentIcon: iconPath,
                  onSelected: (path) => _updatePlayerIcon(index, path),
                );
              },
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.deepBlue,
                      border: Border.all(
                        color: rColor.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: iconPath != null
                        ? ClipOval(
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Image.asset(
                                iconPath,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => Center(
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              initial,
                              style: TextStyle(
                                color: rColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                  ),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentBlue,
                      border: Border.all(
                        color: AppColors.headerBlue,
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(Icons.edit, size: 9, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // ── Name + rating bar ────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Mini progress bar
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: rating / 10.0,
                            minHeight: 4,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              rColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _ratingLabel(rating),
                        style: TextStyle(
                          color: rColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // ── Rating badge ─────────────────────────────────
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: rColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: rColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    rating.toStringAsFixed(1),
                    style: TextStyle(
                      color: rColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                  Text(
                    "/10",
                    style: TextStyle(
                      color: rColor.withValues(alpha: 0.5),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // ── Delete ───────────────────────────────────────
            GestureDetector(
              onTap: () => _confirmDelete(index, name),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                  size: 17,
                ),
              ),
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(int index, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Remover jogador?',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          'Tem certeza que deseja remover "$name"?',
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _removePlayer(index);
            },
            child: const Text(
              'Remover',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.accentBlue,
                strokeWidth: 2,
              ),
            )
          : players.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.group_outlined, size: 48, color: Colors.white12),
                  const SizedBox(height: 12),
                  const Text(
                    "Nenhum jogador no elenco.",
                    style: TextStyle(color: Colors.white30, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Toque em + para adicionar.",
                    style: TextStyle(color: Colors.white24, fontSize: 12),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: players.length,
              itemBuilder: (context, index) => _buildPlayerCard(index),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accentBlue,
        elevation: 4,
        onPressed: _showAddPlayerDialog,
        child: const Icon(
          Icons.person_add_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
