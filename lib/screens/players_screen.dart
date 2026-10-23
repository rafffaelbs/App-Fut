import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../repositories/supabase_service.dart';
import '../utils/player_identity.dart';
import '../utils/rating_calculator.dart';
import '../utils/stats_calculator.dart';
import '../widgets/shared/icon_picker_modal.dart';
import '../utils/overall_calculator.dart';
import '../widgets/player/fifa_card.dart';
import '../widgets/shared/player_avatar_frame.dart';
import 'player_detail.dart';

class PlayersScreen extends StatefulWidget {
  final String groupId;

  const PlayersScreen({super.key, required this.groupId});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {

  List<Map<String, dynamic>> players = [];
  bool isLoading = true;
  String _groupBy = 'A-Z';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final isAdmin = await SupabaseService.instance.groupMembers.isCurrentUserAdmin(widget.groupId);
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  // ─────────────────────────────────────────────────────────────
  // LÓGICA DE NEGÓCIO
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadPlayers() async {
    setState(() => isLoading = true);

    try {
      final fetchedJogadores = await SupabaseService.instance.players.getPlayersByGroup(widget.groupId);
      
      final List<Map<String, dynamic>> mappedPlayers = fetchedJogadores.map((j) => {
        'id': j.id,
        'name': j.name,
        'icon': j.avatarUrl,
        'rating': kRatingBase,
        'totalGames': 0,
        'community': j.community,
        'name_effect': j.nameEffectFull ?? j.nameEffect,
        'monthly_highlight': j.monthlyHighlight,
        'manual_badges': j.manualBadges.map((b) => b.toMap()).toList(),
        'advanced_stats': j.advancedStats,
        'craque_mes_count': j.craqueDoMesCount,
      }).toList();
      
      if (!mounted) return;
      setState(() {
        players = mappedPlayers;
      });

      await _calculateDynamicRatings();
    } catch (e) {
      debugPrint("Error loading players: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _calculateDynamicRatings() async {
    // Note: getAllGroupMatches may still be fetching from SharedPreferences until refactored.
    // If it's refactored, it will fetch from Supabase.
    final List<dynamic> allHistory = await getAllGroupMatches(widget.groupId);

    if (allHistory.isEmpty) {
      if (mounted) {
        setState(() {
          for (final p in players) {
            p['rating']     = kRatingBase;
            p['totalGames'] = 0;
          }
        });
      }
      return;
    }

    final Map<String, Map<String, dynamic>> globalStats = calculateGlobalStats(allHistory);

    if (mounted) {
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
    }
  }

  Future<void> _addNewPlayer(String name, double rating, String? iconPath) async {
    setState(() => isLoading = true);
    try {
      await SupabaseService.instance.players.createGhostPlayer(
        groupId: widget.groupId,
        name: name,
        avatarUrl: iconPath,
      );
      await _loadPlayers();
    } catch(e) {
      debugPrint("Error adding player: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _removePlayer(int index) async {
    final player = players[index];
    setState(() => isLoading = true);
    try {
      await SupabaseService.instance.players.removePlayerFromGroup(
        groupId: widget.groupId,
        playerId: player['id'].toString(),
      );
      await _loadPlayers();
    } catch(e) {
      debugPrint("Error removing player: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao remover: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS
  // ─────────────────────────────────────────────────────────────

  Widget _buildGroupingToggle() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
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
            color: active ? AppColors.accentBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? AppColors.textWhite : AppColors.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 12, left: 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: AppColors.borderSubtle, thickness: 1)),
        ],
      ),
    );
  }

  int _overallOf(Map<String, dynamic> player) {
    final double rating = ((player['rating'] ?? kRatingBase) as num).toDouble();
    return calculateOverall(
      appRating10: rating,
      community: player['community'] as CommunityAttributes?,
    );
  }

  Widget _buildPlayerCard(int index) {
    final player = players[index];
    final String name = player['name'] ?? '';
    final String? iconPath = player['icon'];
    final frame = resolvePlayerFrame(player);

    return FifaCard(
      name: name,
      iconPath: iconPath,
      overall: _overallOf(player),
      attributes: player['community'] as CommunityAttributes?,
      frame: frame,
      // O "x" só aparece para admins; quem não é admin nem vê o botão.
      onRemove: _isAdmin ? () => _removePlayer(index) : null,
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
        ).then((_) {
          // Admin pode ter editado os atributos no perfil: recarrega o elenco.
          if (mounted) _loadPlayers();
        });
      },
    );
  }

  Widget _buildCardsGrid(List<int> indexes) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 14,
      childAspectRatio: FifaCard.designWidth / FifaCard.designHeight,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: indexes.map(_buildPlayerCard).toList(),
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
              backgroundColor: AppColors.surfaceElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.borderSubtle),
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
                        color: AppColors.textWhite,
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
                                  color: AppColors.borderSubtle,
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
                                            color: AppColors.textDim,
                                            size: 32,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_outline,
                                      color: AppColors.textDim,
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
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Name field
                    TextField(
                      controller: controller,
                      style: const TextStyle(color: AppColors.textWhite, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: "Nome do jogador",
                        hintStyle: const TextStyle(color: AppColors.textDim),
                        filled: true,
                        fillColor: AppColors.deepBlue,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.borderSubtle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.accentBlue,
                            width: 1.5,
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
                              style: TextStyle(color: AppColors.textMuted),
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
        List<int> bucket = [];
        void flush() {
          if (bucket.isNotEmpty) listItems.add(_buildCardsGrid(bucket));
          bucket = [];
        }

        for (int i = 0; i < players.length; i++) {
          final String letter = (players[i]['name'] as String)[0].toUpperCase();
          if (letter != currentLetter) {
            flush();
            listItems.add(_buildSectionHeader(letter));
            currentLetter = letter;
          }
          bucket.add(i);
        }
        flush();
      } else {
        // Por nível: agrupa pela faixa do Overall (Elite / Ouro / Prata / Bronze)
        // e ordena do maior pro menor Overall.
        players.sort((a, b) => _overallOf(b).compareTo(_overallOf(a)));

        CardTier? currentTier;
        List<int> bucket = [];
        void flush() {
          if (bucket.isNotEmpty) listItems.add(_buildCardsGrid(bucket));
          bucket = [];
        }

        for (int i = 0; i < players.length; i++) {
          final tier = cardTierFor(_overallOf(players[i]));
          if (tier != currentTier) {
            flush();
            listItems.add(_buildSectionHeader(cardTierLabel(tier)));
            currentTier = tier;
          }
          bucket.add(i);
        }
        flush();
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
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              backgroundColor: AppColors.accentBlue,
              onPressed:       _showAddPlayerDialog,
              child:           const Icon(Icons.person_add_rounded, color: Colors.white),
            )
          : null,
    );
  }
}
