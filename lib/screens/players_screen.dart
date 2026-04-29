import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_colors.dart';
import '../utils/player_identity.dart';
import '../utils/rating_calculator.dart';
import '../utils/stats_calculator.dart';
import '../widgets/shared/icon_picker_modal.dart';
import '../widgets/player/player_card.dart';
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
    final List<dynamic> allHistory = await getAllGroupMatches(widget.groupId);

    if (allHistory.isEmpty) {
      setState(() {
        for (final p in players) {
          p['rating']     = kRatingBase;
          p['totalGames'] = 0;
        }
      });
      await _savePlayers();
      return;
    }

    final Map<String, Map<String, dynamic>> globalStats = calculateGlobalStats(allHistory);

    setState(() {
      for (int i = 0; i < players.length; i++) {
        final String pId = (players[i]['id'] ?? '').toString();
        if (globalStats.containsKey(pId)) {
          final data = globalStats[pId]!;
          players[i]['rating'] = data['nota'];
          players[i]['totalGames'] = data['games'];
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

  void _addNewPlayer(String name, double rating, String? iconPath) {
    setState(() {
      players.add({
        'id': _uuid.v4(),
        'name': name,
        'rating': rating,
        'totalGames': 0,
        'icon': iconPath
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
    final player = players[index];
    final String name = player['name'] ?? '';
    final String? iconPath = player['icon'];

    return PlayerCard(
      player: player,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerDetailScreen(
              groupId: widget.groupId,
              playerId: (player['id'] ?? '').toString(),
              initialPlayerName: name,
              playerIcon: iconPath,
            ),
          ),
        );
      },
      onRemove: () => _removePlayer(index),
    );
  }

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
                          final List<String> takenIcons = players
                              .map((p) => p['icon'] as String?)
                              .where((icon) => icon != null && icon != selectedIcon)
                              .cast<String>()
                              .toList();

                          showIconPickerModal(
                            context: context,
                            takenIcons: takenIcons,
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
                              decoration: BoxDecoration(
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
                    Center(
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
                    const SizedBox(height: 32),

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
                                  kRatingBase,
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
          final String level = getRatingLabel(
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
