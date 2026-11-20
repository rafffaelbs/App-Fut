import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/match_model.dart';
import '../../models/player_model.dart';
import '../../utils/team_stats_calculator.dart';
import 'team_pitch_validator.dart';

class TeamStatsView extends StatefulWidget {
  final List<PlayerModel> players;
  final List<MatchModel> matches;
  final Map<String, Map<String, dynamic>> playerMaps;

  const TeamStatsView({
    super.key,
    required this.players,
    required this.matches,
    required this.playerMaps,
  });

  @override
  State<TeamStatsView> createState() => _TeamStatsViewState();
}

class _TeamStatsViewState extends State<TeamStatsView> {
  int? _filterTeamSize; // null = todos, 2 = duplas, 3 = trios, 4 = quartetos, 5 = 5+

  String _playerName(String id) {
    final p = widget.players.firstWhere(
      (pl) => pl.id == id,
      orElse: () => PlayerModel(id: id, name: id),
    );
    return p.name;
  }

  String _formatTeamNames(List<String> ids) {
    if (ids.isEmpty) return 'Time';
    return ids.map(_playerName).join(' + ');
  }

  void _showAllRivalriesModal(List<RivalryStat> rivalries) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.headerBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.sports_kabaddi, color: Colors.amber, size: 22),
                      SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Todas as Rivalidades',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Confrontos diretos: vitórias e gols contra o rival',
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: rivalries.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhuma rivalidade registrada.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.separated(
                        itemCount: rivalries.length,
                        separatorBuilder: (_, _) =>
                            const Divider(color: Colors.white10, height: 1),
                        itemBuilder: (context, index) {
                          final r = rivalries[index];
                          return _buildRivalryTile(r, rank: index + 1);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final allTeams = TeamStatsCalculator.computeExactTeams(
      widget.matches,
      minMatches: 2,
    );

    // Filtra pelo tamanho se selecionado
    final filteredTeams = allTeams.where((t) {
      if (_filterTeamSize == null) return true;
      if (_filterTeamSize == 5) return t.playerIds.length >= 5;
      return t.playerIds.length == _filterTeamSize;
    }).toList();

    // Rankings de Times
    final mostVictorious = List<TeamStats>.from(filteredTeams)
      ..sort((a, b) {
        if (b.wins != a.wins) return b.wins.compareTo(a.wins);
        return b.winRate.compareTo(a.winRate);
      });

    final topScoring = List<TeamStats>.from(filteredTeams)
      ..sort((a, b) {
        if (b.goalsForAvg != a.goalsForAvg) {
          return b.goalsForAvg.compareTo(a.goalsForAvg);
        }
        return b.goalsFor.compareTo(a.goalsFor);
      });

    final solidDefense = List<TeamStats>.from(filteredTeams)
      ..sort((a, b) {
        if (a.goalsAgainstAvg != b.goalsAgainstAvg) {
          return a.goalsAgainstAvg.compareTo(b.goalsAgainstAvg);
        }
        return b.cleanSheets.compareTo(a.cleanSheets);
      });

    final bestGoalDiff = List<TeamStats>.from(filteredTeams)
      ..sort((a, b) {
        if (b.goalDiff != a.goalDiff) return b.goalDiff.compareTo(a.goalDiff);
        return b.goalsFor.compareTo(a.goalsFor);
      });

    // Rivalidades
    final rivalries = TeamStatsCalculator.computeTopRivalries(
      widget.matches,
      minMatches: 2,
      limit: 20,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 1. Filtros de Tamanho de Time ─────────────────────────
        _buildSizeFilterChips(),
        const SizedBox(height: 16),

        // ── 2. Pódios e Rankings de Times ─────────────────────────
        _buildRankingCard(
          title: 'Times Mais Vitoriosos',
          subtitle: 'Ordenados por vitórias e aproveitamento',
          icon: Icons.emoji_events,
          iconColor: Colors.amber,
          teams: mostVictorious.take(3).toList(),
          metricBuilder: (t) => '${t.wins} vitórias (${t.winRate.toStringAsFixed(0)}%)',
        ),
        const SizedBox(height: 12),

        _buildRankingCard(
          title: 'Ataques Demolidores',
          subtitle: 'Times mais goleadores (média de gols/jogo)',
          icon: Icons.local_fire_department,
          iconColor: Colors.orangeAccent,
          teams: topScoring.take(3).toList(),
          metricBuilder: (t) => '${t.goalsForAvg.toStringAsFixed(1)} gols/jogo (${t.goalsFor} total)',
        ),
        const SizedBox(height: 12),

        _buildRankingCard(
          title: 'Muralhas Defensivas',
          subtitle: 'Menos gols sofridos por partida e clean sheets',
          icon: Icons.shield,
          iconColor: AppColors.highlightGreen,
          teams: solidDefense.take(3).toList(),
          metricBuilder: (t) =>
              '${t.goalsAgainstAvg.toStringAsFixed(1)} sofridos/jogo (${t.cleanSheets} clean sheets)',
        ),
        const SizedBox(height: 12),

        _buildRankingCard(
          title: 'Maior Saldo de Gols',
          subtitle: 'Maior diferencial positivo de gols',
          icon: Icons.trending_up,
          iconColor: AppColors.accentBlue,
          teams: bestGoalDiff.take(3).toList(),
          metricBuilder: (t) => '${t.goalDiff >= 0 ? '+' : ''}${t.goalDiff} saldo (${t.goalsFor} pró)',
        ),

        const SizedBox(height: 24),
        const Divider(color: Color(0xFF1E3A6E)),
        const SizedBox(height: 12),

        // ── 3. Quadro de Rivalidades (Frente a Frente) ─────────────
        _buildRivalriesSection(rivalries),

        const SizedBox(height: 24),
        const Divider(color: Color(0xFF1E3A6E)),
        const SizedBox(height: 12),

        // ── 4. Validador Interativo com Campo Tático ──────────────
        TeamPitchValidator(
          allPlayers: widget.players,
          matches: widget.matches,
          playerMaps: widget.playerMaps,
        ),
      ],
    );
  }

  Widget _buildSizeFilterChips() {
    final options = [
      {'label': 'Todos', 'val': null},
      {'label': 'Duplas (2)', 'val': 2},
      {'label': 'Trios (3)', 'val': 3},
      {'label': 'Quartetos (4)', 'val': 4},
      {'label': '5+ Jogadores', 'val': 5},
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final opt = options[index];
          final isSelected = _filterTeamSize == opt['val'];

          return ChoiceChip(
            selected: isSelected,
            selectedColor: AppColors.accentBlue,
            backgroundColor: AppColors.headerBlue,
            label: Text(
              opt['label'] as String,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            onSelected: (val) {
              setState(() {
                _filterTeamSize = opt['val'] as int?;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildRankingCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required List<TeamStats> teams,
    required String Function(TeamStats) metricBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E3A6E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (teams.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nenhum time atingiu o critério mínimo (2 jogos juntos).',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            )
          else
            for (var i = 0; i < teams.length; i++) ...[
              if (i > 0) const Divider(color: Colors.white10, height: 12),
              _buildTeamRow(teams[i], rank: i + 1, metricText: metricBuilder(teams[i])),
            ],
        ],
      ),
    );
  }

  Widget _buildTeamRow(TeamStats team, {required int rank, required String metricText}) {
    final colors = [Colors.amber, Colors.grey[300]!, const Color(0xFFCD7F32)];
    final badgeColor = rank <= 3 ? colors[rank - 1] : Colors.white54;

    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: badgeColor, width: 1),
          ),
          child: Text(
            '$rank',
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatTeamNames(team.playerIds),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                metricText,
                style: const TextStyle(color: AppColors.accentBlue, fontSize: 11),
              ),
            ],
          ),
        ),
        Text(
          '${team.matches} j',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildRivalriesSection(List<RivalryStat> rivalries) {
    final top3 = rivalries.take(3).toList();

    return Container(
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
              const Row(
                children: [
                  Icon(Icons.sports_kabaddi, color: Colors.amber, size: 22),
                  SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top Rivalidades',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Confrontos diretos: vitórias e gols contra o rival',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              if (rivalries.length > 3)
                TextButton(
                  onPressed: () => _showAllRivalriesModal(rivalries),
                  child: const Text(
                    'Ver Mais',
                    style: TextStyle(
                      color: AppColors.accentBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (top3.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nenhum confronto direto registrado com o filtro atual.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            )
          else
            for (var i = 0; i < top3.length; i++) ...[
              if (i > 0) const Divider(color: Colors.white10, height: 14),
              _buildRivalryTile(top3[i], rank: i + 1),
            ],
        ],
      ),
    );
  }

  Widget _buildAvatarCircle({
    required String? iconPath,
    required String name,
    required double size,
  }) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    Widget fallback() => Center(
          child: Text(
            initial,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.45,
            ),
          ),
        );

    Widget imageContent;
    if (iconPath == null || iconPath.trim().isEmpty) {
      imageContent = fallback();
    } else {
      final path = iconPath.trim();
      if (path.startsWith('http://') || path.startsWith('https://')) {
        imageContent = Image.network(
          path,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => fallback(),
        );
      } else {
        imageContent = Image.asset(
          path,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => fallback(),
        );
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.headerBlue,
        shape: BoxShape.circle,
      ),
      child: ClipOval(child: imageContent),
    );
  }

  Widget _buildRivalryTile(RivalryStat r, {required int rank}) {
    final name1 = _playerName(r.player1Id);
    final name2 = _playerName(r.player2Id);

    final p1 = widget.players.firstWhere(
      (pl) => pl.id == r.player1Id,
      orElse: () => PlayerModel(id: r.player1Id, name: name1),
    );
    final p2 = widget.players.firstWhere(
      (pl) => pl.id == r.player2Id,
      orElse: () => PlayerModel(id: r.player2Id, name: name2),
    );

    final meta1 = widget.playerMaps[r.player1Id] ?? {};
    final icon1 = (p1.avatarUrl != null && p1.avatarUrl!.isNotEmpty)
        ? p1.avatarUrl
        : (meta1['icon'] as String?);
    final meta2 = widget.playerMaps[r.player2Id] ?? {};
    final icon2 = (p2.avatarUrl != null && p2.avatarUrl!.isNotEmpty)
        ? p2.avatarUrl
        : (meta2['icon'] as String?);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Jogador 1
          Expanded(
            child: Row(
              children: [
                _buildAvatarCircle(
                  iconPath: icon1,
                  name: name1,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name1,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: r.p1Wins > r.p2Wins ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${r.p1Wins} ${r.p1Wins == 1 ? 'vitória' : 'vitórias'} no duelo',
                        style: TextStyle(
                          color: r.p1Wins > r.p2Wins ? AppColors.highlightGreen : Colors.white70,
                          fontSize: 10,
                          fontWeight: r.p1Wins > r.p2Wins ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '⚽ ${r.p1Goals} ${r.p1Goals == 1 ? 'gol' : 'gols'} contra este rival',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Placar do Confronto Direto
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.deepBlue,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1E3A6E)),
                  ),
                  child: Text(
                    '${r.p1Wins} x ${r.p2Wins}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  r.draws > 0
                      ? '${r.matchesAgainst} jogos (${r.draws}E)'
                      : '${r.matchesAgainst} jogos',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),

          // Jogador 2
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        name2,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: r.p2Wins > r.p1Wins ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${r.p2Wins} ${r.p2Wins == 1 ? 'vitória' : 'vitórias'} no duelo',
                        style: TextStyle(
                          color: r.p2Wins > r.p1Wins ? AppColors.highlightGreen : Colors.white70,
                          fontSize: 10,
                          fontWeight: r.p2Wins > r.p1Wins ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '⚽ ${r.p2Goals} ${r.p2Goals == 1 ? 'gol' : 'gols'} contra este rival',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildAvatarCircle(
                  iconPath: icon2,
                  name: name2,
                  size: 28,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
