import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/models/player_model.dart';
import 'package:app_do_fut/models/match_model.dart';
import 'package:app_do_fut/models/season_model.dart';
import 'package:app_do_fut/app/app_services.dart';
import 'package:app_do_fut/screens/player_detail.dart';
import 'package:app_do_fut/services/group_bootstrap.dart';
import 'package:app_do_fut/theme/app_theme.dart';
import 'package:app_do_fut/utils/rating_calculator.dart';
import 'package:app_do_fut/services/avatar_style_manager.dart';
import 'package:app_do_fut/widgets/shared/ranking_player_bits.dart';
import 'package:app_do_fut/widgets/shared/stars_badge.dart';
import 'package:app_do_fut/widgets/stats/duos_donut.dart';
import 'package:app_do_fut/widgets/stats/evolution_chart.dart';
import 'package:app_do_fut/widgets/stats/full_ranking_sheet.dart';
import 'package:app_do_fut/widgets/stats/stat_board_card.dart';
import 'package:app_do_fut/widgets/stats/stat_row.dart';
import 'package:app_do_fut/widgets/stats/team_stats_view.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────
// Paleta da tela de Estatísticas — alinhada ao AppColors (padrão do app).
// Mantém os mesmos nomes (_Vs.xxx) usados no resto do arquivo para não
// precisar tocar em cada um dos usos individualmente.
// ─────────────────────────────────────────────────────────────────────────
class _Vs {
  static const bg = AppColors.deepBlue;
  static const panel = AppColors.headerBlue;
  static const header = AppColors.headerBlue;
  static const border = Color(0xFF1E3A6E); // tom intermediário entre headerBlue e accentBlue
  static const accent = AppColors.accentBlue;
  static const accentLight = AppColors.highlightBlue;
  static const textMuted = Colors.white54;
  static const text = AppColors.textWhite;
  static const textStrong = Colors.white70;
  static const good = AppColors.highlightGreen;
  static const warn = Color(0xFFFACC15);
  static const bad = Color(0xFFF48771);
  static const gold = Color(0xFFFFD700);
  static const silver = Color(0xFFC0C0C0);
  static const bronze = Color(0xFFCD7F32);
}

enum StatKey {
  notaMedia,
  ga,
  matches,
  goals,
  assists,
  ved,
  cards,
  hatTricks,
  clutchGoals,
  comebackGoals,
  gkWins,
  gkCleanSheets,
  gkGoalsConcededAvg,
  gkRating,
  formLast10,
}

class _ColDef {
  final StatKey key;
  final String label;
  final String help;
  const _ColDef(this.key, this.label, this.help);
}

const List<_ColDef> _cols = [
  _ColDef(StatKey.notaMedia, 'Nota Média', 'Média das notas das partidas no período'),
  _ColDef(StatKey.ga, 'G+A', 'Gols + Assistências'),
  _ColDef(StatKey.matches, 'PJ', 'Partidas Jogadas'),
  _ColDef(StatKey.goals, 'G', 'Gols'),
  _ColDef(StatKey.assists, 'A', 'Assistências'),
  _ColDef(StatKey.ved, 'V/E/D', 'Vitórias / Empates / Derrotas (Ordena por vitórias)'),
  _ColDef(StatKey.cards, 'C', 'Cartões (Amarelos + Vermelhos)'),
  _ColDef(StatKey.hatTricks, 'HT', 'Hat Tricks'),
];

// ─────────────────────────────────────────────────────────────────────────
// Aggregated stats per player
// ─────────────────────────────────────────────────────────────────────────
class PlayerStatsAgg {
  final PlayerModel player;
  int matches = 0;
  int goals = 0;
  int assists = 0;
  int wins = 0;
  int draws = 0;
  int losses = 0;
  int ownGoals = 0;
  int yellowCards = 0;
  int redCards = 0;
  int hatTricks = 0;
  int clutchGoals = 0;
  int comebackGoals = 0;

  // Goalkeeper
  int gkGames = 0;
  int gkWins = 0;
  int gkCleanSheets = 0;
  int gkGoalsConceded = 0;
  double gkRating = 0.0;

  final List<double> matchRatings = [];

  PlayerStatsAgg(this.player);

  int get ga => goals + assists;
  int get cards => yellowCards + redCards;
  double get winRate => matches > 0 ? (wins / matches) * 100 : 0.0;
  double get gkGoalsConcededAvg => gkGames > 0 ? gkGoalsConceded / gkGames : 0.0;

  double get formLast10 {
    if (matchRatings.isEmpty) return player.rating ?? 6.0;
    final last = matchRatings.length > 10
        ? matchRatings.sublist(matchRatings.length - 10)
        : matchRatings;
    return last.reduce((a, b) => a + b) / last.length;
  }

  double get overallRating {
    if (matchRatings.isEmpty) return player.rating ?? 6.0;
    return matchRatings.reduce((a, b) => a + b) / matchRatings.length;
  }

  double statValue(StatKey k) {
    switch (k) {
      case StatKey.ga:
        return ga.toDouble();
      case StatKey.matches:
        return matches.toDouble();
      case StatKey.goals:
        return goals.toDouble();
      case StatKey.assists:
        return assists.toDouble();
      case StatKey.ved:
        return wins.toDouble();
      case StatKey.cards:
        return cards.toDouble();
      case StatKey.hatTricks:
        return hatTricks.toDouble();
      case StatKey.clutchGoals:
        return clutchGoals.toDouble();
      case StatKey.comebackGoals:
        return comebackGoals.toDouble();
      case StatKey.gkWins:
        return gkWins.toDouble();
      case StatKey.gkCleanSheets:
        return gkCleanSheets.toDouble();
      case StatKey.gkGoalsConcededAvg:
        return gkGoalsConcededAvg;
      case StatKey.gkRating:
        return gkRating;
      case StatKey.notaMedia:
        return overallRating;
      case StatKey.formLast10:
        return formLast10;
    }
  }
}

class DuoStat {
  final String p1Id;
  final String p2Id;
  final int count;
  const DuoStat(this.p1Id, this.p2Id, this.count);
}

class SeasonStatsScreen extends StatefulWidget {
  final String groupId;

  const SeasonStatsScreen({super.key, required this.groupId});

  @override
  State<SeasonStatsScreen> createState() => _SeasonStatsScreenState();
}

class _SeasonStatsScreenState extends State<SeasonStatsScreen> {
  bool isLoading = true;
  List<MatchModel> _allMatches = [];
  List<PlayerModel> _allPlayers = [];
  List<SeasonModel> _allSeasons = [];
  List<PlayerStatsAgg> stats = [];
  List<DuoStat> dynamicDuos = [];
  int _statsTab = 0; // 0 = Individual, 1 = Times & Parcerias

  // Filtro
  String _selectedPeriodKey = 'all'; // 'all', 'last', 'month', 'year', 'custom', or seasonId
  DateTime? _customFrom;
  DateTime? _customTo;

  // Mapas no formato de GroupBootstrap.playerSnapshotMap (RankName/RankAvatar)
  Map<String, Map<String, dynamic>> _playerMaps = {};
  List<Map<String, dynamic>> _playerMapList = [];
  DateTime _now = DateTime.now();

  // Ranking Geral
  bool _showGkRanking = false;
  String _rankSortKey = 'ga';
  bool _rankSortDescending = true;
  String _gkRankSortKey = 'nota';
  bool _gkRankSortDescending = true;

  static const List<Map<String, String>> _fieldSortOptions = [
    {'value': 'ga', 'label': 'G+A (Gols + Assistências)'},
    {'value': 'nota', 'label': 'Nota Média'},
    {'value': 'goals', 'label': 'Gols'},
    {'value': 'assists', 'label': 'Assistências'},
    {'value': 'wins', 'label': 'Vitórias'},
    {'value': 'matches', 'label': 'Partidas Jogadas'},
    {'value': 'cards', 'label': 'Cartões'},
    {'value': 'hatTricks', 'label': 'Hat Tricks'},
  ];

  static const List<Map<String, String>> _gkSortOptions = [
    {'value': 'nota', 'label': 'Nota Média'},
    {'value': 'clean_sheets', 'label': 'Clean Sheets'},
    {'value': 'wins', 'label': 'Vitórias'},
    {'value': 'matches', 'label': 'Jogos'},
    {'value': 'conceded', 'label': 'Média Gols Sofridos'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      // As 3 buscas são independentes entre si -- rodar em paralelo em vez
      // de sequencialmente (await, await, await) corta a espera de
      // "soma dos 3 tempos" pra "o tempo do mais lento dos 3".
      final results = await Future.wait([
        AppServices.instance.matches.getMatchesByGroup(widget.groupId),
        AppServices.instance.players.getPlayersByGroup(widget.groupId),
        AppServices.instance.seasons.getSeasons(widget.groupId),
      ]);

      final matchesList = results[0] as List<MatchModel>;
      final playersList = results[1] as List<PlayerModel>;
      final seasonsList = results[2] as List<SeasonModel>;

      matchesList.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      _allMatches = matchesList;
      _allPlayers = playersList;
      _allSeasons = seasonsList;
      _now = DateTime.now();
      _playerMapList = [
        for (final p in playersList)
          GroupBootstrap.playerSnapshotMap(p, p.rating ?? kRatingBase),
      ];
      _playerMaps = {for (final m in _playerMapList) m['id'] as String: m};

      // If there's an active season, set it as the default
      if (seasonsList.isNotEmpty) {
        final activeSeason = seasonsList.firstWhere(
          (s) => s.isActive,
          orElse: () => seasonsList.first,
        );
        _selectedPeriodKey = activeSeason.id;
      }

      _recomputeStats();
    } catch (e) {
      debugPrint('Error loading stats: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  List<MatchModel> get _filteredPartidas {
    if (_allMatches.isEmpty) return [];

    if (_selectedPeriodKey == 'all') {
      return _allMatches;
    }

    if (_selectedPeriodKey == 'last') {
      final lastSessionId = _allMatches.last.sessionId;
      return _allMatches.where((p) => p.sessionId == lastSessionId).toList();
    }

    if (_selectedPeriodKey == 'month') {
      final now = DateTime.now();
      return _allMatches
          .where((p) =>
              p.timestamp.year == now.year && p.timestamp.month == now.month)
          .toList();
    }

    if (_selectedPeriodKey == 'year') {
      final now = DateTime.now();
      return _allMatches.where((p) => p.timestamp.year == now.year).toList();
    }

    if (_selectedPeriodKey == 'custom') {
      if (_customFrom == null || _customTo == null) return _allMatches;
      final endInclusive = DateTime(
        _customTo!.year,
        _customTo!.month,
        _customTo!.day,
        23,
        59,
        59,
      );
      return _allMatches
          .where((p) =>
              !p.timestamp.isBefore(_customFrom!) &&
              !p.timestamp.isAfter(endInclusive))
          .toList();
    }

    // Filtro por Season ID
    final season = _allSeasons.firstWhere(
      (s) => s.id == _selectedPeriodKey,
      orElse: () => SeasonModel(id: '', groupId: '', name: ''),
    );
    if (season.id.isNotEmpty && season.startDate != null) {
      final from = season.startDate!;
      final to = season.endDate != null
          ? DateTime(season.endDate!.year, season.endDate!.month, season.endDate!.day, 23, 59, 59)
          : DateTime.now();
      return _allMatches
          .where((p) => !p.timestamp.isBefore(from) && !p.timestamp.isAfter(to))
          .toList();
    }

    return _allMatches;
  }

  void _recomputeStats() {
    final map = <String, PlayerStatsAgg>{};
    final playersMap = <String, PlayerModel>{};
    for (final j in _allPlayers) {
      map[j.id] = PlayerStatsAgg(j);
      playersMap[j.id] = j;
    }

    final activeMatches = _filteredPartidas;
    final Map<String, int> duosMap = {};

    for (final p in activeMatches) {
      final redWin = p.scoreRed > p.scoreWhite;
      final whiteWin = p.scoreWhite > p.scoreRed;

      final matchGoals = <String, int>{};
      final matchAssists = <String, int>{};
      final matchOwnGoals = <String, int>{};
      final matchYellow = <String, int>{};
      final matchRed = <String, int>{};

      int runningRed = 0;
      int runningWhite = 0;
      final int durationMin = p.resolvedDurationSeconds != null ? (p.resolvedDurationSeconds! ~/ 60) : 7;

      for (final ev in p.events) {
        if (ev.isGoal && ev.playerId.isNotEmpty) {
          map.putIfAbsent(ev.playerId, () => PlayerStatsAgg(playersMap[ev.playerId] ?? PlayerModel(id: ev.playerId, name: ev.playerId)));
          map[ev.playerId]?.goals += 1;
          matchGoals[ev.playerId] = (matchGoals[ev.playerId] ?? 0) + 1;

          // Parceria de duplas
          if (ev.assistJogadorId != null &&
              ev.assistJogadorId!.isNotEmpty &&
              ev.assistJogadorId != ev.playerId) {
            final id1 = ev.playerId.compareTo(ev.assistJogadorId!) < 0
                ? ev.playerId
                : ev.assistJogadorId!;
            final id2 = ev.playerId.compareTo(ev.assistJogadorId!) < 0
                ? ev.assistJogadorId!
                : ev.playerId;
            final duoKey = '$id1|$id2';
            duosMap[duoKey] = (duosMap[duoKey] ?? 0) + 1;
          }

          // Gol decisivo (desempate no último minuto)
          final isRed = p.lineups.any((l) => l.playerId == ev.playerId && l.isTeamA) ||
              (ev.team?.toLowerCase().contains('red') ?? false);
          final tied = runningRed == runningWhite;
          if (isRed) {
            runningRed++;
          } else {
            runningWhite++;
          }

          if (tied && ev.minute != null && ev.minute!.isNotEmpty) {
            final minStr = ev.minute!.split(':').first;
            final minVal = int.tryParse(minStr);
            if (minVal != null && minVal >= (durationMin - 1)) {
              map[ev.playerId]?.clutchGoals += 1;
            }
          }
        }
        if (ev.isGoal && ev.assistJogadorId != null && ev.assistJogadorId!.isNotEmpty) {
          map.putIfAbsent(ev.assistJogadorId!, () => PlayerStatsAgg(playersMap[ev.assistJogadorId!] ?? PlayerModel(id: ev.assistJogadorId!, name: ev.assistJogadorId!)));
          map[ev.assistJogadorId!]?.assists += 1;
          matchAssists[ev.assistJogadorId!] =
              (matchAssists[ev.assistJogadorId!] ?? 0) + 1;
        }
        if (ev.isOwnGoal && ev.playerId.isNotEmpty) {
          map.putIfAbsent(ev.playerId, () => PlayerStatsAgg(playersMap[ev.playerId] ?? PlayerModel(id: ev.playerId, name: ev.playerId)));
          map[ev.playerId]?.ownGoals += 1;
          matchOwnGoals[ev.playerId] = (matchOwnGoals[ev.playerId] ?? 0) + 1;
        }
        if (ev.isYellowCard && ev.playerId.isNotEmpty) {
          map.putIfAbsent(ev.playerId, () => PlayerStatsAgg(playersMap[ev.playerId] ?? PlayerModel(id: ev.playerId, name: ev.playerId)));
          map[ev.playerId]?.yellowCards += 1;
          matchYellow[ev.playerId] = (matchYellow[ev.playerId] ?? 0) + 1;
        }
        if (ev.isRedCard && ev.playerId.isNotEmpty) {
          map.putIfAbsent(ev.playerId, () => PlayerStatsAgg(playersMap[ev.playerId] ?? PlayerModel(id: ev.playerId, name: ev.playerId)));
          map[ev.playerId]?.redCards += 1;
          matchRed[ev.playerId] = (matchRed[ev.playerId] ?? 0) + 1;
        }
      }

      matchGoals.forEach((id, count) {
        if (count >= 3) map[id]?.hatTricks += 1;
      });

      // Detecção de Gols da Virada
      final feEvents = p.events.map<Map<String, dynamic>>((ev) {
        final isRed = p.lineups.any((l) => l.playerId == ev.playerId && l.isRed) ||
            (ev.team?.toLowerCase().contains('red') ?? false) ||
            (ev.team?.toLowerCase().contains('vermelho') ?? false);
        return {
          'type': ev.eventType,
          'team': isRed ? 'Vermelho' : 'Branco',
          'time': ev.minute ?? '00:00',
          'playerId': ev.playerId,
        };
      }).toList();

      final GoalContext special = findSpecialGoals(feEvents);
      if (special.comebackGoalIndex >= 0 &&
          special.comebackGoalIndex < feEvents.length) {
        final pid = feEvents[special.comebackGoalIndex]['playerId'];
        if (pid != null && pid.isNotEmpty) {
          map[pid]?.comebackGoals += 1;
        }
      }

      for (final e in p.lineups) {
        map.putIfAbsent(e.playerId, () => PlayerStatsAgg(e.player ?? playersMap[e.playerId] ?? PlayerModel(id: e.playerId, name: e.playerId)));
        final s = map[e.playerId]!;

        if (e.isGoalkeeper) {
          s.gkGames += 1;
          if ((e.isRed && redWin) || (e.isWhite && whiteWin)) s.gkWins += 1;
          final conceded = e.isRed ? p.scoreWhite : p.scoreRed;
          s.gkGoalsConceded += conceded;
          if (conceded == 0) s.gkCleanSheets += 1;
          s.gkRating = e.rating ?? s.gkRating;
        } else {
          s.matches += 1;
          final won = (e.isRed && redWin) || (e.isWhite && whiteWin);
          final isDraw = !redWin && !whiteWin;

          if (won) {
            s.wins += 1;
          } else if (isDraw) {
            s.draws += 1;
          } else {
            s.losses += 1;
          }

          final status = won ? 1 : (isDraw ? 0 : -1);
          final teamGoals = e.isRed ? p.scoreRed : p.scoreWhite;
          final conceded = e.isRed ? p.scoreWhite : p.scoreRed;

          final rating = e.rating ??
              _calculateMatchRating(
                status: status,
                goals: matchGoals[e.playerId] ?? 0,
                assists: matchAssists[e.playerId] ?? 0,
                ownGoals: matchOwnGoals[e.playerId] ?? 0,
                teamGoals: teamGoals,
                conceded: conceded,
                yellow: matchYellow[e.playerId] ?? 0,
                red: matchRed[e.playerId] ?? 0,
              );
          s.matchRatings.add(rating);
        }
      }
    }

    final parsedDuos = duosMap.entries.map((e) {
      final parts = e.key.split('|');
      return DuoStat(parts[0], parts[1], e.value);
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    if (!mounted) return; // usuário já saiu da tela enquanto calculava
    setState(() {
      stats = map.values.where((s) => s.matches > 0 || s.gkGames > 0).toList();
      dynamicDuos = parsedDuos;
    });
  }

  double _calculateMatchRating({
    required int status,
    required int goals,
    required int assists,
    required int ownGoals,
    required int teamGoals,
    required int conceded,
    required int yellow,
    required int red,
  }) {
    const base = 6.0;
    double r = base;
    r += goals * 1.0;
    r += assists * 0.8;
    r += ownGoals * -1.0;
    r += yellow * -0.5;
    r += red * -1.5;
    if (status == 1) r += 0.8;
    if (status == -1) r += -0.5;
    r += teamGoals * 0.1;
    if (conceded == 0) r += 0.2;
    return r;
  }

  void _openPlayer(PlayerStatsAgg s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerDetailScreen(
          groupId: widget.groupId,
          playerId: s.player.id,
          initialPlayerName: s.player.name,
          playerIcon: s.player.avatarUrl,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PERIOD / SEASON FILTER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    final standardOpts = [
      {'id': 'last', 'label': 'Última Pelada'},
      {'id': 'month', 'label': 'Mês'},
      {'id': 'year', 'label': 'Ano'},
      {'id': 'all', 'label': 'Todo o Histórico'},
      {'id': 'custom', 'label': 'Personalizado'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estatísticas dos Jogadores',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Classificação geral, pódios e histórico',
                    style: TextStyle(color: _Vs.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: _Vs.accentLight),
              tooltip: 'Recarregar',
              onPressed: _loadData,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _Vs.bg,
            border: Border.all(color: _Vs.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_allSeasons.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _Vs.panel,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _Vs.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _allSeasons.any((s) => s.id == _selectedPeriodKey)
                          ? _selectedPeriodKey
                          : null,
                      hint: const Text(
                        'Temporadas',
                        style: TextStyle(color: _Vs.accentLight, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      dropdownColor: _Vs.panel,
                      icon: const Icon(Icons.arrow_drop_down, color: _Vs.accentLight, size: 18),
                      style: const TextStyle(color: _Vs.text, fontSize: 12),
                      items: _allSeasons.map((s) {
                        return DropdownMenuItem<String>(
                          value: s.id,
                          child: Text('Temporada: ${s.name}'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedPeriodKey = val);
                          _recomputeStats();
                        }
                      },
                    ),
                  ),
                ),
                Container(width: 1, height: 20, color: _Vs.border),
              ],
              ...standardOpts.map((o) {
                final isSelected = _selectedPeriodKey == o['id'];
                return GestureDetector(
                  onTap: () async {
                    if (o['id'] == 'custom') {
                      await _pickCustomRange();
                    }
                    setState(() => _selectedPeriodKey = o['id']!);
                    _recomputeStats();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? _Vs.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      o['label']!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : _Vs.textStrong,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        if (_selectedPeriodKey == 'custom') ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _Vs.bg,
              border: Border.all(color: _Vs.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('PERÍODO: ', style: TextStyle(color: _Vs.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                Text(
                  _customFrom != null ? DateFormat('dd/MM/yyyy').format(_customFrom!) : 'Início',
                  style: const TextStyle(color: _Vs.text, fontSize: 12),
                ),
                const Text(' até ', style: TextStyle(color: _Vs.textMuted, fontSize: 12)),
                Text(
                  _customTo != null ? DateFormat('dd/MM/yyyy').format(_customTo!) : 'Fim',
                  style: const TextStyle(color: _Vs.text, fontSize: 12),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _pickCustomRange,
                  child: const Icon(Icons.edit_calendar, size: 16, color: _Vs.accentLight),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: (_customFrom != null && _customTo != null)
          ? DateTimeRange(start: _customFrom!, end: _customTo!)
          : null,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _Vs.accent,
              surface: _Vs.panel,
            ),
          ),
          child: child!,
        );
      },
    );
    if (range != null) {
      _customFrom = range.start;
      _customTo = range.end;
    }
  }


  // ─────────────────────────────────────────────────────────────────────────
  // RANKING GERAL (TOP 3 PÓDIO + TOP 4-8 + MODAL COMPLETO)
  // ─────────────────────────────────────────────────────────────────────────
  List<PlayerStatsAgg> _getSortedStats({required bool isGk}) {
    final list = stats.where((s) => isGk ? s.gkGames > 0 : s.matches > 0).toList();
    final sortKey = isGk ? _gkRankSortKey : _rankSortKey;
    final descending = isGk ? _gkRankSortDescending : _rankSortDescending;

    list.sort((a, b) {
      int cmp = 0;
      switch (sortKey) {
        case 'ga':
          cmp = a.ga.compareTo(b.ga);
          if (cmp == 0) cmp = a.overallRating.compareTo(b.overallRating);
          break;
        case 'nota':
          final rA = isGk ? (a.gkRating > 0 ? a.gkRating : a.overallRating) : a.overallRating;
          final rB = isGk ? (b.gkRating > 0 ? b.gkRating : b.overallRating) : b.overallRating;
          cmp = rA.compareTo(rB);
          if (cmp == 0) cmp = a.wins.compareTo(b.wins);
          break;
        case 'goals':
          cmp = a.goals.compareTo(b.goals);
          if (cmp == 0) cmp = a.assists.compareTo(b.assists);
          break;
        case 'assists':
          cmp = a.assists.compareTo(b.assists);
          if (cmp == 0) cmp = a.goals.compareTo(b.goals);
          break;
        case 'wins':
          final wA = isGk ? a.gkWins : a.wins;
          final wB = isGk ? b.gkWins : b.wins;
          cmp = wA.compareTo(wB);
          break;
        case 'matches':
          final mA = isGk ? a.gkGames : a.matches;
          final mB = isGk ? b.gkGames : b.matches;
          cmp = mA.compareTo(mB);
          break;
        case 'cards':
          cmp = a.cards.compareTo(b.cards);
          break;
        case 'hatTricks':
          cmp = a.hatTricks.compareTo(b.hatTricks);
          break;
        case 'clean_sheets':
          cmp = a.gkCleanSheets.compareTo(b.gkCleanSheets);
          break;
        case 'conceded':
          cmp = a.gkGoalsConcededAvg.compareTo(b.gkGoalsConcededAvg);
          return descending ? cmp : -cmp; // Menos gols sofridos é melhor
      }
      return descending ? -cmp : cmp;
    });

    return list;
  }

  String _getPrimaryMetricValue(PlayerStatsAgg s, bool isGk) {
    final sortKey = isGk ? _gkRankSortKey : _rankSortKey;
    switch (sortKey) {
      case 'ga':
        return '${s.ga}';
      case 'nota':
        final r = isGk ? (s.gkRating > 0 ? s.gkRating : s.overallRating) : s.overallRating;
        return r.toStringAsFixed(1);
      case 'goals':
        return '${s.goals}';
      case 'assists':
        return '${s.assists}';
      case 'wins':
        return '${isGk ? s.gkWins : s.wins}';
      case 'matches':
        return '${isGk ? s.gkGames : s.matches}';
      case 'cards':
        return '${s.cards}';
      case 'hatTricks':
        return '${s.hatTricks}';
      case 'clean_sheets':
        return '${s.gkCleanSheets}';
      case 'conceded':
        return s.gkGoalsConcededAvg.toStringAsFixed(2);
      default:
        return '${s.ga}';
    }
  }

  String _getPrimaryMetricLabel(bool isGk) {
    final sortKey = isGk ? _gkRankSortKey : _rankSortKey;
    switch (sortKey) {
      case 'ga':
        return 'G+A';
      case 'nota':
        return 'Nota Média';
      case 'goals':
        return 'Gols';
      case 'assists':
        return 'Assist.';
      case 'wins':
        return 'Vitórias';
      case 'matches':
        return 'Partidas';
      case 'cards':
        return 'Cartões';
      case 'hatTricks':
        return 'Hat Tricks';
      case 'clean_sheets':
        return 'Clean Sheets';
      case 'conceded':
        return 'Gols Sofridos';
      default:
        return 'G+A';
    }
  }

  Widget _buildGeneralRankingSection() {
    final hasGk = stats.any((s) => s.gkGames > 0);
    final sorted = _getSortedStats(isGk: _showGkRanking);
    final top3 = sorted.take(3).toList();
    final top4to8 = sorted.length > 3 ? sorted.sublist(3, sorted.length.clamp(3, 8)) : <PlayerStatsAgg>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabeçalho da seção com título e alternador de goleiros
        Row(
          children: [
            const Text(
              '🏆',
              style: TextStyle(fontSize: 22),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Classificação Geral',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (hasGk)
              Container(
                decoration: BoxDecoration(
                  color: _Vs.panel,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _Vs.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                      onTap: () => setState(() => _showGkRanking = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        color: !_showGkRanking ? _Vs.accent : Colors.transparent,
                        child: Text(
                          'Linha',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: !_showGkRanking ? FontWeight.bold : FontWeight.normal,
                            color: !_showGkRanking ? Colors.white : _Vs.textMuted,
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                      onTap: () => setState(() => _showGkRanking = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        color: _showGkRanking ? _Vs.accent : Colors.transparent,
                        child: Text(
                          'Goleiros',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: _showGkRanking ? FontWeight.bold : FontWeight.normal,
                            color: _showGkRanking ? Colors.white : _Vs.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Filtro de ordenação
        Row(
          children: [
            const Text(
              'ORDENAR POR:',
              style: TextStyle(
                color: _Vs.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: _Vs.panel,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _Vs.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _showGkRanking ? _gkRankSortKey : _rankSortKey,
                    dropdownColor: _Vs.panel,
                    isDense: true,
                    style: const TextStyle(color: _Vs.text, fontSize: 12),
                    icon: const Icon(Icons.arrow_drop_down, color: _Vs.accentLight, size: 20),
                    items: (_showGkRanking ? _gkSortOptions : _fieldSortOptions).map((opt) {
                      return DropdownMenuItem<String>(
                        value: opt['value'],
                        child: Text(opt['label']!),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          if (_showGkRanking) {
                            _gkRankSortKey = val;
                          } else {
                            _rankSortKey = val;
                          }
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                setState(() {
                  if (_showGkRanking) {
                    _gkRankSortDescending = !_gkRankSortDescending;
                  } else {
                    _rankSortDescending = !_rankSortDescending;
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _Vs.panel,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _Vs.border),
                ),
                child: Icon(
                  (_showGkRanking ? _gkRankSortDescending : _rankSortDescending)
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  size: 16,
                  color: _Vs.accentLight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Pódio Top 3
        if (sorted.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _Vs.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _Vs.border),
            ),
            child: const Center(
              child: Text(
                'Nenhum dado encontrado para o período selecionado.',
                style: TextStyle(color: _Vs.textMuted, fontSize: 13),
              ),
            ),
          )
        else ...[
          Container(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
            decoration: BoxDecoration(
              color: _Vs.panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _Vs.border),
            ),
            child: _buildGeneralPodium(top3, isGk: _showGkRanking),
          ),

          // Top 4 a 8
          if (top4to8.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildGeneralTop4To8(top4to8, isGk: _showGkRanking),
          ],

          // Botão "Ver Ranking Completo"
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _Vs.accentLight,
              side: const BorderSide(color: _Vs.accentLight),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _showFullRankingModal(isGk: _showGkRanking),
            icon: const Icon(Icons.format_list_numbered, size: 18),
            label: Text(
              'Ver Ranking Completo (${sorted.length} jogadores)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGeneralPodium(List<PlayerStatsAgg> top, {bool isGk = false}) {
    PlayerStatsAgg? at(int i) => top.length > i ? top[i] : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _generalPodiumSlot(at(1), 2, 72, _Vs.silver, isGk)),
        Expanded(child: _generalPodiumSlot(at(0), 1, 104, _Vs.gold, isGk)),
        Expanded(child: _generalPodiumSlot(at(2), 3, 52, _Vs.bronze, isGk)),
      ],
    );
  }

  Widget _generalPodiumSlot(
    PlayerStatsAgg? s,
    int position,
    double barHeight,
    Color medal,
    bool isGk,
  ) {
    if (s == null) return const SizedBox.shrink();

    final bool first = position == 1;
    final playerMap = _mapFor(s.player);
    final cosmetic = cosmeticOfMap(playerMap);
    final nota = isGk ? (s.gkRating > 0 ? s.gkRating : s.overallRating) : s.overallRating;
    final metric = _getPrimaryMetricValue(s, isGk);
    final metricLabel = _getPrimaryMetricLabel(isGk);

    return GestureDetector(
      onTap: () => _openPlayer(s),
      onLongPress: () => showPlayerCardPeek(context, playerMap),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          RankAvatar(
            player: playerMap,
            size: first ? 56 : 44,
            glow: first,
            contextType: AvatarContext.stats,
          ),
          if (cosmetic.stars > 0) ...[
            const SizedBox(height: 2),
            StarsBadge(stars: cosmetic.stars, compact: true, size: 12),
          ],
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: RankName(
              player: playerMap,
              showStars: false,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: first ? 13 : 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(metric, style: AppTheme.number(fontSize: first ? 20 : 18)),
          Text(
            metricLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _Vs.textMuted, fontSize: 10),
          ),
          if (!isGk) ...[
            const SizedBox(height: 4),
            GoalsAssistsText(goals: s.goals, assists: s.assists),
          ],
          if (s.cards > 0 || s.hatTricks > 0) ...[
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: [
                if (s.yellowCards > 0)
                  Text('🟨${s.yellowCards}', style: const TextStyle(fontSize: 10, color: _Vs.textMuted)),
                if (s.redCards > 0)
                  Text('🟥${s.redCards}', style: const TextStyle(fontSize: 10, color: _Vs.textMuted)),
                if (s.hatTricks > 0)
                  Text('🎩${s.hatTricks}', style: const TextStyle(fontSize: 10, color: _Vs.accentLight, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
          const SizedBox(height: 6),
          RatingPill(rating: nota, fontSize: first ? 13 : 11),
          const SizedBox(height: 6),
          Text(
            '${isGk ? s.gkGames : s.matches} ${isGk ? 'jogos' : 'partidas'}',
            style: const TextStyle(color: _Vs.textMuted, fontSize: 10),
          ),
          WdlText(
            wins: isGk ? s.gkWins : s.wins,
            draws: isGk ? 0 : s.draws,
            losses: isGk ? 0 : s.losses,
            fontSize: 10,
          ),
          const SizedBox(height: 6),
          Container(
            height: barHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [medal.withValues(alpha: 0.22), medal.withValues(alpha: 0.0)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(top: BorderSide(color: medal, width: 2)),
            ),
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 8),
            child: Text('$positionº', style: AppTheme.number(fontSize: 20, color: medal)),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralTop4To8(List<PlayerStatsAgg> items, {bool isGk = false}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: List.generate(items.length, (i) {
        final s = items[i];
        final playerMap = _mapFor(s.player);
        final int games = isGk ? s.gkGames : s.matches;
        final String metric = _getPrimaryMetricValue(s, isGk);
        final String metricLabel = _getPrimaryMetricLabel(isGk);
        final double nota = isGk ? (s.gkRating > 0 ? s.gkRating : s.overallRating) : s.overallRating;

        return GestureDetector(
          onTap: () => _openPlayer(s),
          onLongPress: () => showPlayerCardPeek(context, playerMap),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _Vs.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _Vs.border),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${i + 4}º',
                    style: AppTheme.number(fontSize: 14, color: _Vs.textMuted),
                  ),
                ),
                RankAvatar(
                  player: playerMap,
                  size: 40,
                  contextType: AvatarContext.stats,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RankName(player: playerMap),
                      const SizedBox(height: 3),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (!isGk)
                            Text(
                              '⚽ ${s.goals} · 👟 ${s.assists} · ',
                              style: const TextStyle(
                                color: _Vs.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          if (s.yellowCards > 0)
                            Text(
                              '🟨 ${s.yellowCards} · ',
                              style: const TextStyle(
                                color: _Vs.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          if (s.redCards > 0)
                            Text(
                              '🟥 ${s.redCards} · ',
                              style: const TextStyle(
                                color: _Vs.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          if (s.hatTricks > 0)
                            Text(
                              '🎩 ${s.hatTricks} HT · ',
                              style: const TextStyle(
                                color: _Vs.accentLight,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          Text(
                            '$games ${games == 1 ? 'partida' : 'partidas'} · ',
                            style: const TextStyle(
                              color: _Vs.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          WdlText(
                            wins: isGk ? s.gkWins : s.wins,
                            draws: isGk ? 0 : s.draws,
                            losses: isGk ? 0 : s.losses,
                            fontSize: 11,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(metric, style: AppTheme.number(fontSize: 18)),
                    Text(
                      metricLabel,
                      style: const TextStyle(color: _Vs.textMuted, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                RatingPill(rating: nota, fontSize: 12),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _showFullRankingModal({bool isGk = false}) {
    final sortKey = isGk ? _gkRankSortKey : _rankSortKey;
    StatKey statKey;
    switch (sortKey) {
      case 'ga':
        statKey = StatKey.ga;
        break;
      case 'nota':
        statKey = StatKey.notaMedia;
        break;
      case 'goals':
        statKey = StatKey.goals;
        break;
      case 'assists':
        statKey = StatKey.assists;
        break;
      case 'wins':
        statKey = StatKey.ved;
        break;
      case 'matches':
        statKey = StatKey.matches;
        break;
      case 'cards':
        statKey = StatKey.cards;
        break;
      case 'hatTricks':
        statKey = StatKey.hatTricks;
        break;
      case 'clean_sheets':
        statKey = StatKey.gkCleanSheets;
        break;
      case 'conceded':
        statKey = StatKey.gkGoalsConcededAvg;
        break;
      default:
        statKey = isGk ? StatKey.gkRating : StatKey.ga;
    }
    _showFullTable(
      initialSort: statKey,
      title: isGk ? 'Ranking de Goleiros' : 'Ranking Geral da Temporada',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PÓDIOS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPodiumSection({
    required String title,
    String? subtitle,
    required StatKey key,
    required String label,
    bool isGoalkeeper = false,
    bool isFloat = false,
  }) {
    final filteredList = stats.where((s) {
      if (isGoalkeeper) return s.gkGames > 0;
      return s.matches > 0;
    }).toList();

    final sorted = List<PlayerStatsAgg>.from(filteredList)
      ..sort((a, b) => b.statValue(key).compareTo(a.statValue(key)));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _Vs.panel,
        border: Border.all(color: _Vs.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _Vs.textMuted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const Divider(color: _Vs.border, height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildPodium(sorted, key, label, isFloat),
          ),
          const Divider(color: _Vs.border, height: 1),
          Material(
            color: _Vs.bg,
            child: InkWell(
              onTap: () => _showFullTable(initialSort: key, title: title),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.list, size: 16, color: _Vs.textStrong),
                    SizedBox(width: 8),
                    Text(
                      'Ver todos',
                      style: TextStyle(color: _Vs.textStrong, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodium(List<PlayerStatsAgg> sorted, StatKey key, String label, bool isFloat) {
    if (sorted.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('Sem dados suficientes',
              style: TextStyle(color: _Vs.textMuted, fontSize: 13)),
        ),
      );
    }

    final top3 = sorted.take(3).toList();
    final order = <PlayerStatsAgg?>[
      top3.length > 1 ? top3[1] : null,
      top3.isNotEmpty ? top3[0] : null,
      top3.length > 2 ? top3[2] : null,
    ];
    const places = [2, 1, 3];
    const heights = [70.0, 96.0, 56.0];
    const colors = [_Vs.silver, _Vs.gold, _Vs.bronze];
    const avatarSizes = [56.0, 76.0, 56.0];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (idx) {
          final s = order[idx];
          if (s == null) return const Expanded(child: SizedBox());

          final place = places[idx];
          final color = colors[idx];

          return Expanded(
            child: GestureDetector(
              onTap: () => _openPlayer(s),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      RankAvatar(
                        player: _mapFor(s.player),
                        size: avatarSizes[idx],
                        glow: place == 1,
                        contextType: AvatarContext.stats,
                      ),
                      Positioned(
                        top: place == 1 ? -22 : -8,
                        right: place == 1 ? null : -6,
                        child: Icon(
                          place == 1 ? Icons.emoji_events : Icons.military_tech,
                          color: color,
                          size: place == 1 ? 26 : 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: RankName(
                      player: _mapFor(s.player),
                      showStars: false,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(color: _Vs.textMuted, fontSize: 10),
                  ),
                  Text(
                    isFloat ? s.statValue(key).toStringAsFixed(2) : s.statValue(key).toStringAsFixed(0),
                    style: const TextStyle(
                      color: _Vs.good,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: heights[idx],
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                      border: Border.all(color: _Vs.border),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [color.withValues(alpha: 0.18), Colors.transparent],
                      ),
                    ),
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '$place\u00ba',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // QUADROS (Gols Contra, Nota Média, Taxa de Vitórias, Duplas Dinâmicas)
  // ─────────────────────────────────────────────────────────────────────────
  Map<String, dynamic> _mapFor(PlayerModel p) =>
      _playerMaps[p.id] ??
      GroupBootstrap.playerSnapshotMap(p, p.rating ?? kRatingBase);

  Map<String, dynamic> _mapForId(String id) =>
      _playerMaps[id] ?? {'id': id, 'name': id};

  void _openPlayerById(StatRow row) {
    for (final s in stats) {
      if (s.player.id == row.player['id']) {
        _openPlayer(s);
        return;
      }
    }
  }

  List<StatRow> _ownGoalsRows() {
    final l = stats.where((s) => s.ownGoals > 0).toList()
      ..sort((a, b) => b.ownGoals.compareTo(a.ownGoals));
    return [
      for (final s in l)
        StatRow(
          player: _mapFor(s.player),
          primary: '${s.ownGoals}',
          secondary: s.ownGoals == 1 ? 'gol contra' : 'gols contra',
          tieValue: s.ownGoals,
        ),
    ];
  }

  List<StatRow> _avgRatingRows() {
    final l = stats.where((s) => s.matches >= 5).toList()
      ..sort((a, b) => b.formLast10.compareTo(a.formLast10));
    return [
      for (final s in l)
        StatRow(
          player: _mapFor(s.player),
          primary: s.formLast10.toStringAsFixed(2),
          primaryColor: AppColors.ratingPill(s.formLast10),
          secondary: '${s.matches} partidas',
          tieValue: double.parse(s.formLast10.toStringAsFixed(2)),
        ),
    ];
  }

  List<StatRow> _winRateRows() {
    final l = stats.where((s) => s.matches >= 10).toList()
      ..sort((a, b) => b.winRate.compareTo(a.winRate));
    return [
      for (final s in l)
        StatRow(
          player: _mapFor(s.player),
          primary: '${s.winRate.toStringAsFixed(1)}%',
          primaryColor: AppColors.success,
          secondary: '${s.wins}V em ${s.matches}',
          tieValue: double.parse(s.winRate.toStringAsFixed(1)),
        ),
    ];
  }

  List<StatRow> _duoRows() => [
        for (final d in dynamicDuos)
          StatRow(
            player: _mapForId(d.p1Id),
            player2: _mapForId(d.p2Id),
            primary: '${d.count}',
            secondary: d.count == 1 ? 'gol' : 'gols',
            tieValue: d.count,
          ),
      ];

  Widget _buildBoards() {
    final wide = MediaQuery.of(context).size.width >= 600;

    final ownGoals = _ownGoalsRows();
    final rating = _avgRatingRows();
    final winRate = _winRateRows();
    final duoRows = _duoRows();

    Widget ownGoalsCard(bool fill) => StatBoardCard(
          title: 'Quadro de Gols Contra',
          rows: ownGoals,
          emptyText: 'Nenhum gol contra registrado.',
          fillHeight: fill,
          onTapRow: _openPlayerById,
          onMore: () => showFullRanking(context,
              title: 'Quadro de Gols Contra', rows: ownGoals, onTapRow: _openPlayerById),
        );
    Widget ratingCard(bool fill) => StatBoardCard(
          title: 'Nota média recebida',
          subtitle: 'Escala 0–10 · mín. 5 partidas',
          rows: rating,
          emptyText: 'Mínimo 5 partidas para qualificação.',
          fillHeight: fill,
          onTapRow: _openPlayerById,
          onMore: () => showFullRanking(context,
              title: 'Nota média recebida',
              rows: rating,
              footer: 'Jogadores com menos de 5 partidas não entram.',
              onTapRow: _openPlayerById),
        );
    Widget winRateCard(bool fill) => StatBoardCard(
          title: 'Taxa de Vitórias',
          subtitle: 'Mín. 10 partidas',
          rows: winRate,
          emptyText: 'Mínimo 10 partidas para qualificação.',
          fillHeight: fill,
          onTapRow: _openPlayerById,
          onMore: () => showFullRanking(context,
              title: 'Taxa de Vitórias',
              rows: winRate,
              footer: 'Jogadores com menos de 10 partidas não entram.',
              onTapRow: _openPlayerById),
        );
    Widget duosCard(bool fill) => DuosDonutCard(
          duos: [
            for (final d in dynamicDuos)
              DuoSlice(_mapForId(d.p1Id)['name'].toString(),
                  _mapForId(d.p2Id)['name'].toString(), d.count),
          ],
          fillHeight: fill,
          onMore: () => showFullRanking(context,
              title: 'Duplas Dinâmicas',
              rows: duoRows,
              footer: 'A rosca mostra só as 5 primeiras.'),
        );

    if (!wide) {
      return Column(
        children: [
          ownGoalsCard(false),
          const SizedBox(height: 16),
          ratingCard(false),
          const SizedBox(height: 16),
          winRateCard(false),
          const SizedBox(height: 16),
          duosCard(false),
        ],
      );
    }
    Widget pair(Widget a, Widget b) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: a),
              const SizedBox(width: 16),
              Expanded(child: b),
            ],
          ),
        );
    return Column(
      children: [
        pair(ownGoalsCard(true), ratingCard(true)),
        const SizedBox(height: 16),
        pair(winRateCard(true), duosCard(true)),
      ],
    );
  }

  void _showFullTable({required StatKey initialSort, required String title}) {
    showDialog(
      context: context,
      builder: (ctx) => _FullStatsTableDialog(
        title: title,
        stats: stats,
        initialSort: initialSort,
        playerMaps: _playerMaps,
        onSelectPlayer: (s) {
          Navigator.pop(ctx);
          _openPlayer(s);
        },
      ),
    );
  }

  Widget _buildViewTypeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: _Vs.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Vs.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _statsTab = 0),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _statsTab == 0 ? _Vs.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person,
                      size: 18,
                      color: _statsTab == 0 ? Colors.white : _Vs.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Individual',
                      style: TextStyle(
                        color: _statsTab == 0 ? Colors.white : _Vs.textMuted,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _statsTab = 1),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _statsTab == 1 ? _Vs.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.groups_rounded,
                      size: 18,
                      color: _statsTab == 1 ? Colors.white : _Vs.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Times & Parcerias',
                      style: TextStyle(
                        color: _statsTab == 1 ? Colors.white : _Vs.textMuted,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComicTrophiesSection() {
    // 1. Inimigo do Gol (mais partidas com 0 gols)
    final zeroGoalPlayers = stats.where((s) => s.matches > 0 && s.goals == 0).toList()
      ..sort((a, b) => b.matches.compareTo(a.matches));
    final inimigo = zeroGoalPlayers.isNotEmpty ? zeroGoalPlayers.first : null;

    // 2. Pé Torto / Traidor (mais gols contra)
    final ownGoalPlayers = stats.where((s) => s.ownGoals > 0).toList()
      ..sort((a, b) => b.ownGoals.compareTo(a.ownGoals));
    final peTorto = ownGoalPlayers.isNotEmpty ? ownGoalPlayers.first : null;

    // 3. Açougueiro / Xerife (mais cartões)
    final cardPlayers = stats.where((s) => (s.yellowCards + s.redCards) > 0).toList()
      ..sort((a, b) => (b.yellowCards + b.redCards).compareTo(a.yellowCards + a.redCards));
    final acougueiro = cardPlayers.isNotEmpty ? cardPlayers.first : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Vs.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Vs.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🎭', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Troféus da Resenha',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Estatísticas descontraídas pós-jogo',
                    style: TextStyle(color: _Vs.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildComicTile(
            emoji: '🛑',
            title: 'Inimigo do Gol (Seca)',
            description: inimigo != null
                ? '${inimigo.player.name} (${inimigo.matches} ${inimigo.matches == 1 ? 'partida' : 'partidas'} na seca)'
                : 'Nenhum jogador na seca! Todo mundo marcou 🎉',
            color: Colors.orangeAccent,
          ),
          const Divider(color: Colors.white10, height: 16),
          _buildComicTile(
            emoji: '🤡',
            title: 'Pé Torto / Traidor',
            description: peTorto != null
                ? '${peTorto.player.name} (${peTorto.ownGoals} ${peTorto.ownGoals == 1 ? 'gol contra' : 'gols contra'})'
                : 'Ninguém marcou contra! Pontaria calibrada 🎯',
            color: Colors.redAccent,
          ),
          const Divider(color: Colors.white10, height: 16),
          _buildComicTile(
            emoji: '🥩',
            title: 'Açougueiro / Xerife',
            description: acougueiro != null
                ? '${acougueiro.player.name} (${acougueiro.cards} ${acougueiro.cards == 1 ? 'cartão' : 'cartões'})'
                : 'Pelada da paz! Nenhum cartão tomado 🕊️',
            color: Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildComicTile({
    required String emoji,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: _Vs.accent));
    }

    final hasGkData = stats.any((s) => s.gkGames > 0);

    return Scaffold(
      backgroundColor: _Vs.bg,
      body: RefreshIndicator(
        color: _Vs.accent,
        backgroundColor: _Vs.panel,
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _buildFilterBar(),
            const SizedBox(height: 12),
            _buildViewTypeToggle(),
            const SizedBox(height: 16),

            if (_statsTab == 1) ...[
              TeamStatsView(
                players: _allPlayers,
                matches: _filteredPartidas,
                playerMaps: _playerMaps,
              ),
            ] else ...[
              // 1. Rankings (General Ranking com Pódio Top 3, Top 4-8 e Ver Todos)
              _buildGeneralRankingSection(),
              const SizedBox(height: 24),

              // Divisor: Desempenho Geral & Quadros
              const Divider(color: _Vs.border),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.insights, color: _Vs.accentLight, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Desempenho Geral & Quadros',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Evolução de Desempenho (6 meses fixos, ignora o filtro de período)
              EvolutionChartCard(
                players: _playerMapList,
                matches: _allMatches,
                now: _now,
              ),
              const SizedBox(height: 16),

              // Quadros: Gols Contra, Nota Média, Taxa de Vitórias, Duplas
              _buildBoards(),
              const SizedBox(height: 24),

              // Divisor: Troféus da Resenha
              const Divider(color: _Vs.border),
              const SizedBox(height: 12),
              _buildComicTrophiesSection(),
              const SizedBox(height: 24),

              // Divisor: Pódios por Categoria
              const Divider(color: _Vs.border),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.military_tech, color: _Vs.accentLight, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Pódios por Categoria',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Pódios Principais
              _buildPodiumSection(
                title: 'Gols + Assistências',
                key: StatKey.ga,
                label: 'G+A',
              ),
              _buildPodiumSection(
                title: 'Artilharia',
                key: StatKey.goals,
                label: 'Gols',
              ),
              _buildPodiumSection(
                title: 'Assistências',
                key: StatKey.assists,
                label: 'Assist.',
              ),
              _buildPodiumSection(
                title: 'Mais Partidas Jogadas',
                key: StatKey.matches,
                label: 'Partidas',
              ),
              _buildPodiumSection(
                title: 'Mais Cartões',
                key: StatKey.cards,
                label: 'Cartões',
              ),
              _buildPodiumSection(
                title: 'Hat Tricks',
                key: StatKey.hatTricks,
                label: 'HT',
              ),
              _buildPodiumSection(
                title: 'Gols Decisivos',
                subtitle: 'Gols de desempate no último minuto da partida',
                key: StatKey.clutchGoals,
                label: 'Decisivos',
              ),
              _buildPodiumSection(
                title: 'Gols da Virada',
                subtitle: 'Gols que colocaram o time na frente após estar perdendo',
                key: StatKey.comebackGoals,
                label: 'Viradas',
              ),

              // Goalkeepers (Walls)
              if (hasGkData) ...[
                const SizedBox(height: 12),
                const Divider(color: _Vs.border),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Text('🧤', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Text(
                      'Paredões (Goleiros)',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildPodiumSection(
                  title: 'Luva de Ouro (Nota)',
                  key: StatKey.gkRating,
                  label: 'Nota',
                  isGoalkeeper: true,
                  isFloat: true,
                ),
                _buildPodiumSection(
                  title: 'Mais Vitórias (Goleiros)',
                  key: StatKey.gkWins,
                  label: 'Vitórias',
                  isGoalkeeper: true,
                ),
                _buildPodiumSection(
                  title: 'Clean Sheets',
                  key: StatKey.gkCleanSheets,
                  label: 'Clean Sheets',
                  isGoalkeeper: true,
                ),
                _buildPodiumSection(
                  title: 'Gols Sofridos (Média)',
                  key: StatKey.gkGoalsConcededAvg,
                  label: 'Gols/Jogo',
                  isGoalkeeper: true,
                  isFloat: true,
                ),
              ],
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// DIÁLOGO "VER TODOS" COM TABELA COMPLETA ORDENÁVEL
// ─────────────────────────────────────────────────────────────────────────
class _FullStatsTableDialog extends StatefulWidget {
  final String title;
  final List<PlayerStatsAgg> stats;
  final StatKey initialSort;
  final Map<String, Map<String, dynamic>> playerMaps;
  final void Function(PlayerStatsAgg) onSelectPlayer;

  const _FullStatsTableDialog({
    required this.title,
    required this.stats,
    required this.initialSort,
    required this.playerMaps,
    required this.onSelectPlayer,
  });

  @override
  State<_FullStatsTableDialog> createState() => _FullStatsTableDialogState();
}

class _FullStatsTableDialogState extends State<_FullStatsTableDialog> {
  late StatKey _sortKey;
  bool _desc = true;

  @override
  void initState() {
    super.initState();
    _sortKey = widget.initialSort;
  }

  void _toggleSort(StatKey key) {
    setState(() {
      if (_sortKey == key) {
        _desc = !_desc;
      } else {
        _sortKey = key;
        _desc = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<PlayerStatsAgg>.from(widget.stats)
      ..sort((a, b) => _desc
          ? b.statValue(_sortKey).compareTo(a.statValue(_sortKey))
          : a.statValue(_sortKey).compareTo(b.statValue(_sortKey)));

    return Dialog(
      backgroundColor: _Vs.panel,
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: _Vs.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.table_chart, color: _Vs.accentLight, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tabela: ${widget.title}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: _Vs.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: _Vs.border, height: 1),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(_Vs.header),
                    dataRowColor: WidgetStateProperty.all(_Vs.panel),
                    columnSpacing: 16,
                    columns: [
                      const DataColumn(
                        label: Text('#', style: TextStyle(color: _Vs.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const DataColumn(
                        label: Text('Jogador', style: TextStyle(color: _Vs.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      ..._cols.map(
                        (c) => DataColumn(
                          label: InkWell(
                            onTap: () => _toggleSort(c.key),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  c.label,
                                  style: TextStyle(
                                    color: _sortKey == c.key ? _Vs.accentLight : _Vs.textMuted,
                                    fontWeight: _sortKey == c.key ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  _sortKey != c.key
                                      ? Icons.unfold_more
                                      : (_desc ? Icons.arrow_downward : Icons.arrow_upward),
                                  size: 12,
                                  color: _sortKey == c.key ? _Vs.accentLight : _Vs.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    rows: sorted.asMap().entries.map((entry) {
                      final i = entry.key;
                      final s = entry.value;
                      final playerMap = widget.playerMaps[s.player.id] ?? {
                        'id': s.player.id,
                        'name': s.player.name,
                        'icon': s.player.avatarUrl,
                        'rating': s.overallRating,
                      };
                      return DataRow(
                        onSelectChanged: (_) => widget.onSelectPlayer(s),
                        cells: [
                          DataCell(Text('${i + 1}', style: const TextStyle(color: _Vs.textMuted, fontSize: 12))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RankAvatar(
                                  player: playerMap,
                                  size: 26,
                                  contextType: AvatarContext.stats,
                                ),
                                const SizedBox(width: 8),
                                Text(s.player.name, style: const TextStyle(color: _Vs.text, fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          ..._cols.map((c) {
                            if (c.key == StatKey.notaMedia) {
                              return DataCell(
                                RatingPill(rating: s.overallRating, fontSize: 11),
                              );
                            }
                            if (c.key == StatKey.ved) {
                              return DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${s.wins}', style: const TextStyle(color: _Vs.good, fontWeight: FontWeight.bold, fontSize: 12)),
                                    const Text(' / ', style: TextStyle(color: _Vs.textMuted, fontSize: 12)),
                                    Text('${s.draws}', style: const TextStyle(color: _Vs.warn, fontWeight: FontWeight.bold, fontSize: 12)),
                                    const Text(' / ', style: TextStyle(color: _Vs.textMuted, fontSize: 12)),
                                    Text('${s.losses}', style: const TextStyle(color: _Vs.bad, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                              );
                            }
                            if (c.key == StatKey.cards) {
                              return DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${s.cards}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                    if (s.cards > 0) ...[
                                      const SizedBox(width: 4),
                                      Text('(🟨${s.yellowCards} 🟥${s.redCards})', style: const TextStyle(color: _Vs.textMuted, fontSize: 10)),
                                    ],
                                  ],
                                ),
                              );
                            }
                            if (c.key == StatKey.hatTricks) {
                              return DataCell(
                                Text(
                                  '${s.hatTricks}',
                                  style: TextStyle(
                                    color: s.hatTricks > 0 ? Colors.amber : _Vs.textStrong,
                                    fontWeight: s.hatTricks > 0 ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }
                            final v = s.statValue(c.key);
                            return DataCell(
                              Text(
                                v.toStringAsFixed(0),
                                style: TextStyle(
                                  color: _sortKey == c.key ? Colors.white : _Vs.textStrong,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
