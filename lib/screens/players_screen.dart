import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../repositories/supabase_service.dart';
import '../utils/player_identity.dart';
import '../utils/rating_calculator.dart';
import '../utils/stats_calculator.dart';
import '../widgets/shared/icon_picker_modal.dart';
import '../utils/overall_calculator.dart';
import '../widgets/player/fifa_card.dart';
import '../theme/app_theme.dart';
import '../widgets/shared/player_avatar_frame.dart';
import '../widgets/shared/ranking_player_bits.dart';
import 'player_detail.dart';

enum _RosterFilter { all, legendary, platinum, gold, silver, bronze, effects }

enum _RosterSort { ovr, name, rating, games }

const _filterLabels = {
  _RosterFilter.all: 'Todos',
  _RosterFilter.legendary: 'Lendária',
  _RosterFilter.platinum: 'Platina',
  _RosterFilter.gold: 'Ouro',
  _RosterFilter.silver: 'Prata',
  _RosterFilter.bronze: 'Bronze',
  _RosterFilter.effects: 'Com efeitos',
};

const _sortLabels = {
  _RosterSort.ovr: 'OVR',
  _RosterSort.name: 'Nome',
  _RosterSort.rating: 'Nota média',
  _RosterSort.games: 'Jogos',
};

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
  String _query = '';
  _RosterFilter _filter = _RosterFilter.all;
  _RosterSort _sort = _RosterSort.ovr;
  bool _grid = true;

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

  Future<void> _confirmRemove(Map<String, dynamic> player) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Remover jogador?',
            style: TextStyle(color: AppColors.textWhite)),
        content: Text(
          '${player['name']} sai do elenco do grupo.',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) await _removePlayer(player);
  }

  Future<void> _removePlayer(Map<String, dynamic> player) async {
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
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          _toggleOption('Alfabética (A–Z)', 'A-Z'),
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        style: const TextStyle(color: AppColors.textWhite, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Buscar jogador',
          hintStyle: const TextStyle(color: AppColors.textDim),
          prefixIcon: const Icon(Icons.search, color: AppColors.textDim),
          filled: true,
          fillColor: AppColors.headerBlue,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.borderSubtle),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.borderFocused),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final f in _RosterFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_filterLabels[f]!),
                selected: _filter == f,
                onSelected: (_) => setState(() => _filter = f),
                showCheckmark: false,
                backgroundColor: AppColors.surfaceSubtle,
                selectedColor: AppColors.accentBlue,
                side: const BorderSide(color: AppColors.borderSubtle),
                labelStyle: TextStyle(
                  color: _filter == f ? AppColors.textWhite : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSortBar(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Row(
        children: [
          Text('$count jogadores',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const Spacer(),
          PopupMenuButton<_RosterSort>(
            tooltip: 'Ordenar por',
            color: AppColors.surfaceElevated,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => [
              for (final o in _RosterSort.values)
                PopupMenuItem(
                  value: o,
                  child: Text(_sortLabels[o]!,
                      style: const TextStyle(color: AppColors.textPrimary)),
                ),
            ],
            child: Row(
              children: [
                const Icon(Icons.sort_rounded, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(_sortLabels[_sort]!,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(width: 8),
              ],
            ),
          ),
          IconButton(
            tooltip: _grid ? 'Ver em lista' : 'Ver em grade',
            icon: Icon(_grid ? Icons.view_list_rounded : Icons.grid_view_rounded,
                color: AppColors.textMuted),
            onPressed: () => setState(() => _grid = !_grid),
          ),
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

  bool _matches(Map<String, dynamic> p) {
    if (_query.isNotEmpty &&
        !(p['name'] as String).toLowerCase().contains(_query)) {
      return false;
    }
    switch (_filter) {
      case _RosterFilter.all:
        return true;
      case _RosterFilter.legendary:
        return tierForOverall(_overallOf(p)) == CardTier.legendary;
      case _RosterFilter.platinum:
        return tierForOverall(_overallOf(p)) == CardTier.platinum;
      case _RosterFilter.gold:
        return tierForOverall(_overallOf(p)) == CardTier.gold;
      case _RosterFilter.silver:
        return tierForOverall(_overallOf(p)) == CardTier.silver;
      case _RosterFilter.bronze:
        return tierForOverall(_overallOf(p)) == CardTier.bronze;
      case _RosterFilter.effects:
        return cosmeticOfMap(p).frame != null;
    }
  }

  int _compare(Map<String, dynamic> a, Map<String, dynamic> b) {
    switch (_sort) {
      case _RosterSort.ovr:
        return _overallOf(b).compareTo(_overallOf(a));
      case _RosterSort.name:
        return (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase());
      case _RosterSort.rating:
        return ((b['rating'] ?? 0) as num).compareTo((a['rating'] ?? 0) as num);
      case _RosterSort.games:
        return ((b['totalGames'] ?? 0) as num).compareTo((a['totalGames'] ?? 0) as num);
    }
  }

  void _openPlayer(Map<String, dynamic> player) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerDetailScreen(
          groupId: widget.groupId,
          playerId: (player['id'] ?? '').toString(),
          initialPlayerName: player['name'] ?? '',
          playerIcon: player['icon'],
        ),
      ),
    ).then((_) {
      // Admin pode ter editado os atributos no perfil: recarrega o elenco.
      if (mounted) _loadPlayers();
    });
  }

  /// Menu ⋮ (só admin): remover exige confirmação.
  Widget _removeMenu(Map<String, dynamic> player) {
    return PopupMenuButton<String>(
      tooltip: 'Mais ações',
      padding: EdgeInsets.zero,
      color: AppColors.surfaceElevated,
      icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textMuted),
      onSelected: (_) => _confirmRemove(player),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'remove',
          child: Text('Remover do elenco', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    );
  }

  Widget _buildPlayerCard(Map<String, dynamic> player) {
    final card = FifaCard(
      name: player['name'] ?? '',
      iconPath: player['icon'],
      overall: _overallOf(player),
      attributes: player['community'] as CommunityAttributes?,
      frame: resolvePlayerFrame(player),
      onTap: () => _openPlayer(player),
    );
    if (!_isAdmin) return card;
    return GestureDetector(
      onLongPress: () => _confirmRemove(player),
      child: Stack(
        children: [
          Positioned.fill(child: card),
          Positioned(
            top: 0,
            right: 0,
            width: 32,
            height: 32,
            child: _removeMenu(player),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(Map<String, dynamic> player) {
    final overall = _overallOf(player);
    final games = (player['totalGames'] ?? 0) as int;
    final rating = ((player['rating'] ?? kRatingBase) as num).toDouble();
    return InkWell(
      onTap: () => _openPlayer(player),
      onLongPress: _isAdmin ? () => _confirmRemove(player) : null,
      child: Container(
        height: 64,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.headerBlue,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            RankAvatar(player: player, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RankName(player: player),
                  const SizedBox(height: 2),
                  Text(
                    '$games ${games == 1 ? 'jogo' : 'jogos'} · nota ${rating.toStringAsFixed(1)}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '$overall',
              style: AppTheme.number(
                fontSize: 22,
                color: overallColor(overall),
              ),
            ),
            if (_isAdmin) _removeMenu(player),
          ],
        ),
      ),
    );
  }

  /// Cabeçalho fixo (letra ou nível) seguido do conteúdo do grupo.
  /// Header sem `pinned`: header fixo gera SliverGeometry inválida (layoutExtent >
  /// paintExtent) no Flutter 3.44 e derruba a semântica, sumindo com as cartas.
  List<Widget> _buildGroupSlivers(String title, List<Map<String, dynamic>> group) {
    return [
        SliverPersistentHeader(
          pinned: false,
          delegate: _SectionHeaderDelegate(title),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: _grid
              ? SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 14,
                    childAspectRatio: FifaCard.designWidth / FifaCard.designHeight,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _buildPlayerCard(group[i]),
                    childCount: group.length,
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _buildPlayerRow(group[i]),
                    childCount: group.length,
                  ),
                ),
        ),
    ];
  }

  /// Filtra, ordena e agrupa sem mexer na lista original.
  List<MapEntry<String, List<Map<String, dynamic>>>> _groups() {
    final list = players.where(_matches).toList()..sort(_compare);
    final groups = <String, List<Map<String, dynamic>>>{};
    if (_groupBy == 'A-Z') {
      for (final p in list) {
        final name = p['name'] as String;
        final letter = name.isEmpty ? '#' : name[0].toUpperCase();
        groups.putIfAbsent(letter, () => []).add(p);
      }
      return groups.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    }
    for (final p in list) {
      final tier = tierForOverall(_overallOf(p));
      groups.putIfAbsent(cardTierLabel(tier), () => []).add(p);
    }
    const order = ['Lendária', 'Platina', 'Ouro', 'Prata', 'Bronze'];
    return groups.entries.toList()
      ..sort((a, b) => order.indexOf(a.key).compareTo(order.indexOf(b.key)));
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
    final groups = (!isLoading && players.isNotEmpty)
        ? _groups()
        : <MapEntry<String, List<Map<String, dynamic>>>>[];
    final total = groups.fold<int>(0, (n, g) => n + g.value.length);

    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentBlue))
          : players.isEmpty
              ? const Center(child: Text('Nenhum jogador no elenco.', style: TextStyle(color: AppColors.textMuted)))
              : Column(
                  children: [
                    _buildGroupingToggle(),
                    _buildSearchBar(),
                    _buildFilterChips(),
                    _buildSortBar(total),
                    Expanded(
                      child: total == 0
                          ? const Center(
                              child: Text('Nenhum jogador encontrado.',
                                  style: TextStyle(color: AppColors.textMuted)),
                            )
                          : CustomScrollView(
                              slivers: [
                                for (final g in groups) ..._buildGroupSlivers(g.key, g.value),
                                // Margem para o botão flutuante não cobrir as cartas.
                                const SliverToBoxAdapter(child: SizedBox(height: 100)),
                              ],
                            ),
                    ),
                  ],
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

class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  _SectionHeaderDelegate(this.title);

  @override
  double get minExtent => 40;
  @override
  double get maxExtent => 40;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.deepBlue,
      padding: const EdgeInsets.symmetric(horizontal: 20),
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

  @override
  bool shouldRebuild(_SectionHeaderDelegate old) => old.title != title;
}
