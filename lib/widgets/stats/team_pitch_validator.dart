import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../models/match_model.dart';
import '../../models/player_model.dart';
import '../../utils/overall_calculator.dart';
import '../../utils/tactical_formation.dart';
import '../../utils/team_stats_calculator.dart';
import '../player/fifa_card.dart';

class TeamPitchValidator extends StatefulWidget {
  final List<PlayerModel> allPlayers;
  final List<MatchModel> matches;
  final Map<String, Map<String, dynamic>> playerMaps;

  const TeamPitchValidator({
    super.key,
    required this.allPlayers,
    required this.matches,
    required this.playerMaps,
  });

  @override
  State<TeamPitchValidator> createState() => _TeamPitchValidatorState();
}

class _TeamPitchValidatorState extends State<TeamPitchValidator> {
  final List<String> _selectedIds = [];
  bool _useChips = true;
  bool _isLoadingPrefs = true;
  SharedPreferences? _prefs;
  int _formationPresetIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    final bool useCards = _prefs?.getBool('pitch_use_cards') ??
        (!(_prefs?.getBool('pitch_use_chips') ?? true));
    setState(() {
      _useChips = !useCards;
      _isLoadingPrefs = false;
    });
  }

  Future<void> _toggleUseChips() async {
    final next = !_useChips;
    setState(() => _useChips = next);
    await _prefs?.setBool('pitch_use_cards', !next);
    await _prefs?.setBool('pitch_use_chips', next);
  }

  Widget _buildAvatarImage({
    required String? iconPath,
    required String name,
    required double size,
    Color fallbackColor = Colors.white,
    double? fontSize,
  }) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    Widget fallback() => Center(
          child: Text(
            initial,
            style: TextStyle(
              color: fallbackColor,
              fontWeight: FontWeight.bold,
              fontSize: fontSize ?? (size * 0.45),
            ),
          ),
        );

    if (iconPath == null || iconPath.trim().isEmpty) {
      return fallback();
    }

    final path = iconPath.trim();
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => fallback(),
      );
    }

    return Image.asset(
      path,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => fallback(),
    );
  }

  Widget _buildAvatarCircle({
    required String? iconPath,
    required String name,
    required double size,
    Color backgroundColor = AppColors.headerBlue,
    Color fallbackColor = Colors.white,
    double? fontSize,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: _buildAvatarImage(
          iconPath: iconPath,
          name: name,
          size: size,
          fallbackColor: fallbackColor,
          fontSize: fontSize,
        ),
      ),
    );
  }

  String _formatTitle(int count) {
    switch (count) {
      case 0:
      case 1:
        return 'Selecione de 2 a 11 jogadores';
      case 2:
        return 'Dupla Selecionada (2 jogadores)';
      case 3:
        return 'Trio Selecionado (3 jogadores)';
      case 4:
        return 'Quarteto Selecionado (4 jogadores)';
      case 5:
        return 'Quinteto Selecionado (5 jogadores)';
      default:
        return 'Time de $count Jogadores (Máx. 11)';
    }
  }

  void _addPlayer(String id) {
    if (_selectedIds.length >= 11 || _selectedIds.contains(id)) return;
    setState(() {
      _selectedIds.add(id);
      _formationPresetIndex = 0;
    });
  }

  void _removePlayer(String id) {
    setState(() {
      _selectedIds.remove(id);
      _formationPresetIndex = 0;
    });
  }

  void _clearAll() {
    setState(() {
      _selectedIds.clear();
      _formationPresetIndex = 0;
    });
  }

  void _openPlayerSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.headerBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final available = widget.allPlayers.where((p) {
              final inTeam = _selectedIds.contains(p.id);
              final matchesQuery = p.name.toLowerCase().contains(query.toLowerCase());
              return !inTeam && matchesQuery;
            }).toList()
              ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

            return Container(
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Adicionar ao Time',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar jogador...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: AppColors.deepBlue,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => setModalState(() => query = val),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: available.isEmpty
                        ? const Center(
                            child: Text(
                              'Nenhum jogador encontrado',
                              style: TextStyle(color: Colors.white38),
                            ),
                          )
                        : ListView.separated(
                            itemCount: available.length,
                            separatorBuilder: (_, _) =>
                                const Divider(color: Colors.white10, height: 1),
                            itemBuilder: (context, index) {
                              final p = available[index];
                              final meta = widget.playerMaps[p.id] ?? {};
                              final overall = playerOverallOf(meta).round();
                              final iconPath = (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
                                  ? p.avatarUrl
                                  : (meta['icon'] as String?);

                              return ListTile(
                                leading: _buildAvatarCircle(
                                  iconPath: iconPath,
                                  name: p.name,
                                  size: 36,
                                ),
                                title: Text(
                                  p.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.deepBlue,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.accentBlue, width: 1),
                                  ),
                                  child: Text(
                                    'OVR $overall',
                                    style: const TextStyle(
                                      color: AppColors.accentBlue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                onTap: () {
                                  _addPlayer(p.id);
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPrefs) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentBlue));
    }

    final stats = _selectedIds.length >= 2
        ? TeamStatsCalculator.evaluateCustomTeam(_selectedIds, widget.matches)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Card Superior: Cabeçalho & Seleção de Jogadores ────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.headerBlue,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E3A6E)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accentBlue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.groups_rounded,
                          color: AppColors.accentBlue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Valide as Estatísticas do Time',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Química e retrospecto de elenco',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Botão para alternar formato visual (Cards vs Chips)
                  IconButton(
                    icon: Icon(
                      _useChips ? Icons.badge_outlined : Icons.account_circle_outlined,
                      color: AppColors.accentBlue,
                      size: 22,
                    ),
                    tooltip: _useChips
                        ? 'Mudar para Cards FIFA'
                        : 'Mudar para Chips circulares',
                    onPressed: _toggleUseChips,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Contador dinâmico
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatTitle(_selectedIds.length),
                    style: const TextStyle(
                      color: AppColors.highlightGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_selectedIds.isNotEmpty)
                    InkWell(
                      onTap: _clearAll,
                      child: const Text(
                        'Limpar',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Lista de Chips dos Jogadores Selecionados
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final id in _selectedIds) ...[
                    _buildSelectedPlayerChip(id),
                  ],
                  if (_selectedIds.length < 11)
                    ActionChip(
                      avatar: const Icon(Icons.add, color: Colors.white, size: 16),
                      label: const Text(
                        'Adicionar Jogador',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      backgroundColor: AppColors.deepBlue,
                      side: const BorderSide(color: AppColors.accentBlue, width: 1),
                      onPressed: _openPlayerSelector,
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Campinho Tático (quando há 2 ou mais jogadores) ──────────
        if (_selectedIds.length >= 2) ...[
          _buildTacticalPitchCard(),
          const SizedBox(height: 16),
        ],

        // ── Resultados & Métricas do Time ────────────────────────────
        if (_selectedIds.length < 2) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.headerBlue.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: const Column(
              children: [
                Icon(Icons.touch_app_outlined, color: AppColors.accentBlue, size: 36),
                SizedBox(height: 12),
                Text(
                  'Escolha pelo menos 2 jogadores',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Adicione atletas acima para ver o retrospecto conjunto no campo tático.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ] else if (stats != null && stats.matches == 0) ...[
          // Time nunca jogou junto
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            decoration: BoxDecoration(
              color: AppColors.headerBlue,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E3A6E)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🏟️', style: TextStyle(fontSize: 36)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Esse time nunca jogou junto!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nenhuma partida foi registrada com esses atletas atuando no mesmo time no período selecionado. Uma ótima formação para testar na próxima pelada!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
        ] else if (stats != null) ...[
          // Time já jogou junto -> exibe painel completo
          _buildStatsResultCard(stats),
        ],
      ],
    );
  }

  Widget _buildSelectedPlayerChip(String playerId) {
    final player = widget.allPlayers.firstWhere(
      (p) => p.id == playerId,
      orElse: () => PlayerModel(id: playerId, name: playerId),
    );
    final meta = widget.playerMaps[playerId] ?? {};
    final iconPath = (player.avatarUrl != null && player.avatarUrl!.isNotEmpty)
        ? player.avatarUrl
        : (meta['icon'] as String?);

    return Chip(
      avatar: _buildAvatarCircle(
        iconPath: iconPath,
        name: player.name,
        size: 24,
        fontSize: 10,
      ),
      label: Text(
        player.name,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
      deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white70),
      onDeleted: () => _removePlayer(playerId),
      backgroundColor: AppColors.deepBlue,
      side: const BorderSide(color: Color(0xFF1E3A6E)),
    );
  }

  Widget _buildTacticalPitchCard() {
    final count = _selectedIds.length;
    final lineCount = count > 1 ? count - 1 : 1;
    final presets = formationPresets(lineCount);
    final activeRows = _formationPresetIndex < presets.length
        ? presets[_formationPresetIndex]
        : FormationManager.getPreferredFormation(lineCount, _prefs);

    final formationLabel = formationRowsLabel(activeRows);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A6E)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Barra de título do campo tático com seletor de formação
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stadium, color: AppColors.highlightGreen, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Disposição em Campo ($formationLabel)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: _toggleUseChips,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.deepBlue,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.accentBlue, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _useChips ? Icons.badge_outlined : Icons.account_circle_outlined,
                              color: AppColors.accentBlue,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _useChips ? 'Cards' : 'Chips',
                              style: const TextStyle(
                                color: AppColors.accentBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (presets.length > 1) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _formationPresetIndex =
                                (_formationPresetIndex + 1) % presets.length;
                          });
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.deepBlue,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.accentBlue, width: 1),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.swap_horiz, color: AppColors.accentBlue, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Formação',
                                style: TextStyle(
                                  color: AppColors.accentBlue,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Gramado tático
          Container(
            height: 240,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF184E28), // Tom de gramado elegante
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24, width: 1.5),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1B5E20), Color(0xFF144D1B)],
              ),
            ),
            child: Stack(
              children: [
                // Linhas do campo
                _buildPitchLines(),
                // Posicionamento dos jogadores
                _buildPlayersOnPitch(activeRows),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPitchLines() {
    return Positioned.fill(
      child: CustomPaint(
        painter: _PitchMarkingsPainter(),
      ),
    );
  }

  Widget _buildPlayersOnPitch(List<int> rows) {
    // Organiza os IDs selecionados por fileira
    // O primeiro jogador pode atuar como goleiro/defensor de base se o time for grande
    final players = _selectedIds.map((id) {
      return widget.allPlayers.firstWhere(
        (p) => p.id == id,
        orElse: () => PlayerModel(id: id, name: id),
      );
    }).toList();

    // Invertemos rows para que o topo seja o ataque e a base seja a defesa
    final displayRows = rows.reversed.toList();
    int playerIndex = players.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Linhas de linha (do ataque para a defesa)
          for (final count in displayRows)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (playerIndex >= 0) ...[
                    _buildPlayerFieldSlot(players[playerIndex--]),
                  ],
                ],
              ],
            ),
          // Jogador na base (goleiro ou líbero)
          if (playerIndex >= 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPlayerFieldSlot(players[playerIndex--], isGk: true),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerFieldSlot(PlayerModel player, {bool isGk = false}) {
    final meta = widget.playerMaps[player.id] ?? {};
    final overall = playerOverallOf(meta).round();
    final iconPath = (player.avatarUrl != null && player.avatarUrl!.isNotEmpty)
        ? player.avatarUrl
        : (meta['icon'] as String?);

    if (!_useChips) {
      // Exibição em card FIFA compacto
      return SizedBox(
        width: 52,
        height: 68,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: FifaCard(
            name: player.name,
            overall: overall,
            iconPath: iconPath,
            density: CardDensity.medium,
          ),
        ),
      );
    }

    // Exibição em Chip circular com foto, nome e OVR
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            _buildAvatarCircle(
              iconPath: iconPath,
              name: player.name,
              size: 38,
              fontSize: 12,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isGk ? Colors.amber[800] : AppColors.deepBlue,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white, width: 0.8),
              ),
              child: Text(
                '$overall',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Container(
          constraints: const BoxConstraints(maxWidth: 62),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            player.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsResultCard(TeamStats stats) {
    final String badgeText;
    final Color badgeColor;

    if (stats.winRate >= 70) {
      badgeText = '🔥 Time Imbatível';
      badgeColor = AppColors.highlightGreen;
    } else if (stats.winRate >= 50) {
      badgeText = '⚡ Equipe Competitiva';
      badgeColor = AppColors.accentBlue;
    } else {
      badgeText = '⚖️ Em Busca de Entrosamento';
      badgeColor = Colors.amber;
    }

    String topScorerName = 'Nenhum';
    if (stats.topScorerId != null) {
      final p = widget.allPlayers.firstWhere(
        (pl) => pl.id == stats.topScorerId,
        orElse: () => PlayerModel(id: stats.topScorerId!, name: stats.topScorerId!),
      );
      topScorerName = '${p.name} (${stats.topScorerGoals} gols)';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A6E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho do Retrospecto
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Retrospecto do Time',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${stats.matches} ${stats.matches == 1 ? 'partida disputada' : 'partidas disputadas'}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor, width: 1),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1E3A6E), height: 1),

          // Grid de Métricas Principais
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'V / E / D',
                        value: '${stats.wins} - ${stats.draws} - ${stats.losses}',
                        sub: '${stats.winRate.toStringAsFixed(0)}% vitórias',
                        color: AppColors.highlightGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Aproveitamento',
                        value: '${stats.pointsPct.toStringAsFixed(0)}%',
                        sub: '${stats.points} pts somados',
                        color: AppColors.accentBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Gols Pró (Ataque)',
                        value: '${stats.goalsFor}',
                        sub: '${stats.goalsForAvg.toStringAsFixed(1)} por partida',
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Gols Contra (Defesa)',
                        value: '${stats.goalsAgainst}',
                        sub: '${stats.goalsAgainstAvg.toStringAsFixed(1)} por partida',
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Saldo de Gols',
                        value: '${stats.goalDiff >= 0 ? '+' : ''}${stats.goalDiff}',
                        sub: stats.goalDiff >= 0 ? 'Saldo positivo' : 'Saldo negativo',
                        color: stats.goalDiff >= 0 ? AppColors.highlightGreen : Colors.redAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Clean Sheets',
                        value: '${stats.cleanSheets}',
                        sub: 'Jogos sem sofrer gol',
                        color: AppColors.highlightGreen,
                      ),
                    ),
                  ],
                ),
                if (stats.topScorerId != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.deepBlue,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E3A6E)),
                    ),
                    child: Row(
                      children: [
                        const Text('⚽', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        const Text(
                          'Artilheiro do time:',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            topScorerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Lista de Partidas em ExpansionTile
          if (stats.matchesList.isNotEmpty) ...[
            const Divider(color: Color(0xFF1E3A6E), height: 1),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(
                  'Ver Todas as Partidas (${stats.matchesList.length})',
                  style: const TextStyle(
                    color: AppColors.accentBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                iconColor: AppColors.accentBlue,
                collapsedIconColor: Colors.white54,
                children: [
                  for (final match in stats.matchesList)
                    _buildMatchHistoryRow(match),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.deepBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E3A6E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchHistoryRow(MatchModel match) {
    // Determina se o time selecionado jogou como Red ou White
    final redIds = match.lineups.where((l) => l.isRed).map((l) => l.playerId).toSet();
    final isTeamRed = _selectedIds.every(redIds.contains);

    final teamScore = isTeamRed ? match.scoreRed : match.scoreWhite;
    final oppScore = isTeamRed ? match.scoreWhite : match.scoreRed;

    final String resultLetter;
    final Color resultColor;

    if (teamScore > oppScore) {
      resultLetter = 'V';
      resultColor = AppColors.highlightGreen;
    } else if (teamScore == oppScore) {
      resultLetter = 'E';
      resultColor = Colors.amber;
    } else {
      resultLetter = 'D';
      resultColor = Colors.redAccent;
    }

    final dateStr = match.startTime != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(match.startTime!)
        : 'Partida';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: resultColor, width: 1),
                ),
                child: Text(
                  resultLetter,
                  style: TextStyle(
                    color: resultColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    isTeamRed ? 'Time Vermelho' : 'Time Branco',
                    style: TextStyle(
                      color: isTeamRed ? Colors.redAccent : Colors.white60,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            '$teamScore x $oppScore',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Desenha marcações do campinho (linha de meio de campo, círculo central, grande área)
class _PitchMarkingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Linha do meio
    final midY = size.height / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), paint);

    // Círculo central
    canvas.drawCircle(Offset(size.width / 2, midY), 24, paint);
    canvas.drawCircle(
      Offset(size.width / 2, midY),
      2,
      paint..style = PaintingStyle.fill,
    );
    paint.style = PaintingStyle.stroke;

    // Área do gol (fundo)
    final boxW = size.width * 0.44;
    final boxLeft = (size.width - boxW) / 2;
    canvas.drawRect(
      Rect.fromLTWH(boxLeft, size.height - 24, boxW, 24),
      paint,
    );

    // Pequena área
    final smallW = size.width * 0.24;
    final smallLeft = (size.width - smallW) / 2;
    canvas.drawRect(
      Rect.fromLTWH(smallLeft, size.height - 10, smallW, 10),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
