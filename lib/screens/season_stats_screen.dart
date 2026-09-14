import 'dart:async';
import 'dart:math';
import 'package:app_do_fut/models/player_model.dart';
import 'package:app_do_fut/models/match_model.dart';
import 'package:app_do_fut/models/season_model.dart';
import 'package:app_do_fut/repositories/supabase_service.dart';
import 'package:app_do_fut/screens/player_detail.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────
// Paleta "VS Code Dark" — espelha exatamente PlayerStats.tsx
// ─────────────────────────────────────────────────────────────────────────
class _Vs {
  static const bg = Color(0xFF1E1E1E);
  static const panel = Color(0xFF252526);
  static const header = Color(0xFF2D2D30);
  static const border = Color(0xFF3E3E42);
  static const accent = Color(0xFF007ACC);
  static const accentLight = Color(0xFF4FC3F7);
  static const rowHover = Color(0xFF2A2D2E);
  static const textMuted = Color(0xFF858585);
  static const text = Color(0xFFD4D4D4);
  static const textStrong = Color(0xFFCCCCCC);
  static const good = Color(0xFF89D185);
  static const warn = Color(0xFFFACC15);
  static const bad = Color(0xFFF48771);
  static const gold = Color(0xFFFFD700);
  static const silver = Color(0xFFC0C0C0);
  static const bronze = Color(0xFFCD7F32);
}

const List<Color> _chartColors = [
  Color(0xFFFF5733),
  Color(0xFF4FC3F7),
  Color(0xFF33FF8C),
  Color(0xFFF033FF),
  Color(0xFFFF33A1),
  Color(0xFFF0FF33),
  Color(0xFFFF8C33),
  Color(0xFF33FFF0),
  Color(0xFF8C33FF),
  Color(0xFF33FF57),
];

enum StatKey {
  ga,
  matches,
  goals,
  assists,
  ved,
  cards,
  hatTricks,
  clutchGoals,
  gkWins,
  gkCleanSheets,
  gkGoalsConcededAvg,
  gkNota,
  formLast10,
}

class _ColDef {
  final StatKey key;
  final String label;
  final String help;
  const _ColDef(this.key, this.label, this.help);
}

const List<_ColDef> _cols = [
  _ColDef(StatKey.ga, 'G+A', 'Gols + Assistências'),
  _ColDef(StatKey.matches, 'PJ', 'Partidas Jogadas'),
  _ColDef(StatKey.goals, 'G', 'Gols'),
  _ColDef(StatKey.assists, 'A', 'Assistências'),
  _ColDef(StatKey.ved, 'V/E/D', 'Vitórias / Empates / Derrotas (Ordena por vitórias)'),
  _ColDef(StatKey.cards, 'C', 'Cartões (Amarelos + Vermelhos)'),
  _ColDef(StatKey.hatTricks, 'HT', 'Hat Tricks'),
  _ColDef(StatKey.formLast10, 'Forma', 'Média das últimas 10 partidas'),
];

// ─────────────────────────────────────────────────────────────────────────
// Estatísticas agregadas por jogador
// ─────────────────────────────────────────────────────────────────────────
class PlayerStatsAgg {
  final PlayerModel jogador;
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

  // Goleiro
  int gkGames = 0;
  int gkWins = 0;
  int gkCleanSheets = 0;
  int gkGoalsConceded = 0;
  double gkNota = 0.0;

  final List<double> matchRatings = [];

  PlayerStatsAgg(this.jogador);

  int get ga => goals + assists;
  int get cards => yellowCards + redCards;
  double get winRate => matches > 0 ? (wins / matches) * 100 : 0.0;
  double get gkGoalsConcededAvg => gkGames > 0 ? gkGoalsConceded / gkGames : 0.0;

  double get formLast10 {
    if (matchRatings.isEmpty) return jogador.rating ?? 6.0;
    final last = matchRatings.length > 10
        ? matchRatings.sublist(matchRatings.length - 10)
        : matchRatings;
    return last.reduce((a, b) => a + b) / last.length;
  }

  double get overallRating {
    if (matchRatings.isEmpty) return jogador.rating ?? 6.0;
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
      case StatKey.gkWins:
        return gkWins.toDouble();
      case StatKey.gkCleanSheets:
        return gkCleanSheets.toDouble();
      case StatKey.gkGoalsConcededAvg:
        return gkGoalsConcededAvg;
      case StatKey.gkNota:
        return gkNota;
      case StatKey.formLast10:
        return formLast10;
    }
  }
}

class DuoStat {
  final String p1Name;
  final String p2Name;
  final int count;
  const DuoStat(this.p1Name, this.p2Name, this.count);
}

class SeasonStatsScreen extends StatefulWidget {
  final String groupId;

  const SeasonStatsScreen({super.key, required this.groupId});

  @override
  State<SeasonStatsScreen> createState() => _SeasonStatsScreenState();
}

class _SeasonStatsScreenState extends State<SeasonStatsScreen> {
  bool isLoading = true;
  List<MatchModel> _allPartidas = [];
  List<PlayerModel> _allJogadores = [];
  List<SeasonModel> _allSeasons = [];
  List<PlayerStatsAgg> stats = [];
  List<DuoStat> dynamicDuos = [];

  // Filtro
  String _selectedPeriodKey = 'all'; // 'all', 'last', 'month', 'year', 'custom', or seasonId
  DateTime? _customFrom;
  DateTime? _customTo;

  // Chart state
  String _chartMetric = 'ga'; // 'ga', 'goals', 'assists'
  bool _chartGroupByDate = false;
  int? _animationIndex;
  bool _isPlaying = false;
  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final partidas =
          await SupabaseService.instance.partidas.getPartidasPorGrupo(widget.groupId);
      final jogadores =
          await SupabaseService.instance.jogadores.getJogadoresDoGrupo(widget.groupId);
      final temporadas =
          await SupabaseService.instance.seasons.getTemporadas(widget.groupId);

      partidas.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      _allPartidas = partidas;
      _allJogadores = jogadores;
      _allSeasons = temporadas;

      // Se houver uma temporada ativa, define ela como padrão
      if (temporadas.isNotEmpty) {
        final activeSeason = temporadas.firstWhere(
          (s) => s.isActive,
          orElse: () => temporadas.first,
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
    if (_allPartidas.isEmpty) return [];

    if (_selectedPeriodKey == 'all') {
      return _allPartidas;
    }

    if (_selectedPeriodKey == 'last') {
      final lastSessionId = _allPartidas.last.sessaoId;
      return _allPartidas.where((p) => p.sessaoId == lastSessionId).toList();
    }

    if (_selectedPeriodKey == 'month') {
      final now = DateTime.now();
      return _allPartidas
          .where((p) =>
              p.timestamp.year == now.year && p.timestamp.month == now.month)
          .toList();
    }

    if (_selectedPeriodKey == 'year') {
      final now = DateTime.now();
      return _allPartidas.where((p) => p.timestamp.year == now.year).toList();
    }

    if (_selectedPeriodKey == 'custom') {
      if (_customFrom == null || _customTo == null) return _allPartidas;
      final endInclusive = DateTime(
        _customTo!.year,
        _customTo!.month,
        _customTo!.day,
        23,
        59,
        59,
      );
      return _allPartidas
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
      return _allPartidas
          .where((p) => !p.timestamp.isBefore(from) && !p.timestamp.isAfter(to))
          .toList();
    }

    return _allPartidas;
  }

  void _recomputeStats() {
    final map = <String, PlayerStatsAgg>{};
    final playersMap = <String, PlayerModel>{};
    for (final j in _allJogadores) {
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
      final int durationMin = p.duracaoSegundos != null ? (p.duracaoSegundos! ~/ 60) : 7;

      for (final ev in p.eventos) {
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
          if (isRed) runningRed++; else runningWhite++;

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

      for (final e in p.escalacao) {
        map.putIfAbsent(e.playerId, () => PlayerStatsAgg(e.player ?? playersMap[e.playerId] ?? PlayerModel(id: e.playerId, name: e.playerId)));
        final s = map[e.playerId]!;

        if (e.isGoalkeeper) {
          s.gkGames += 1;
          if ((e.isRed && redWin) || (e.isWhite && whiteWin)) s.gkWins += 1;
          final conceded = e.isRed ? p.scoreWhite : p.scoreRed;
          s.gkGoalsConceded += conceded;
          if (conceded == 0) s.gkCleanSheets += 1;
          s.gkNota = e.rating ?? s.gkNota;
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
      final name1 = playersMap[parts[0]]?.name ?? parts[0];
      final name2 = playersMap[parts[1]]?.name ?? parts[1];
      return DuoStat(name1, name2, e.value);
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    setState(() {
      stats = map.values.where((s) => s.matches > 0 || s.gkGames > 0).toList();
      dynamicDuos = parsedDuos.take(5).toList();
      _animationIndex = null;
      _isPlaying = false;
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
          playerId: s.jogador.id,
          initialPlayerName: s.jogador.name,
          playerIcon: s.jogador.avatarUrl,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FILTRO DE PERÍODO / TEMPORADA
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
  // EVOLUÇÃO DE DESEMPENHO (LINE CHART & ANIMAÇÃO)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPerformanceEvolutionChart() {
    final sortedMatches = List<MatchModel>.from(_filteredPartidas)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (sortedMatches.isEmpty || _allJogadores.isEmpty) return const SizedBox.shrink();

    // Calcula acumulado por jogador
    final Map<String, int> cumulativeGA = {};
    final Map<String, int> cumulativeGoals = {};
    final Map<String, int> cumulativeAssists = {};
    for (final j in _allJogadores) {
      cumulativeGA[j.id] = 0;
      cumulativeGoals[j.id] = 0;
      cumulativeAssists[j.id] = 0;
    }

    // Lista de pontos temporais
    final List<Map<String, dynamic>> points = [];
    final Map<String, dynamic> initialPoint = {'name': 'Início'};
    for (final j in _allJogadores) initialPoint[j.id] = 0;
    points.add(initialPoint);

    if (_chartGroupByDate) {
      final Map<String, List<MatchModel>> matchesByDate = {};
      for (final m in sortedMatches) {
        final dStr = DateFormat('dd/MM').format(m.timestamp);
        matchesByDate.putIfAbsent(dStr, () => []).add(m);
      }

      matchesByDate.forEach((dateStr, matchesOnDate) {
        for (final m in matchesOnDate) {
          for (final ev in m.eventos) {
            if (ev.isGoal && ev.playerId.isNotEmpty) {
              cumulativeGoals[ev.playerId] = (cumulativeGoals[ev.playerId] ?? 0) + 1;
              cumulativeGA[ev.playerId] = (cumulativeGA[ev.playerId] ?? 0) + 1;
            }
            if (ev.isGoal && ev.assistJogadorId != null && ev.assistJogadorId!.isNotEmpty) {
              cumulativeAssists[ev.assistJogadorId!] = (cumulativeAssists[ev.assistJogadorId!] ?? 0) + 1;
              cumulativeGA[ev.assistJogadorId!] = (cumulativeGA[ev.assistJogadorId!] ?? 0) + 1;
            }
          }
        }
        final Map<String, dynamic> pt = {'name': dateStr};
        for (final j in _allJogadores) {
          pt[j.id] = _chartMetric == 'ga'
              ? (cumulativeGA[j.id] ?? 0)
              : (_chartMetric == 'goals'
                  ? (cumulativeGoals[j.id] ?? 0)
                  : (cumulativeAssists[j.id] ?? 0));
        }
        points.add(pt);
      });
    } else {
      for (int i = 0; i < sortedMatches.length; i++) {
        final m = sortedMatches[i];
        for (final ev in m.eventos) {
          if (ev.isGoal && ev.playerId.isNotEmpty) {
            cumulativeGoals[ev.playerId] = (cumulativeGoals[ev.playerId] ?? 0) + 1;
            cumulativeGA[ev.playerId] = (cumulativeGA[ev.playerId] ?? 0) + 1;
          }
          if (ev.isGoal && ev.assistJogadorId != null && ev.assistJogadorId!.isNotEmpty) {
            cumulativeAssists[ev.assistJogadorId!] = (cumulativeAssists[ev.assistJogadorId!] ?? 0) + 1;
            cumulativeGA[ev.assistJogadorId!] = (cumulativeGA[ev.assistJogadorId!] ?? 0) + 1;
          }
        }
        final Map<String, dynamic> pt = {'name': 'P${i + 1}'};
        for (final j in _allJogadores) {
          pt[j.id] = _chartMetric == 'ga'
              ? (cumulativeGA[j.id] ?? 0)
              : (_chartMetric == 'goals'
                  ? (cumulativeGoals[j.id] ?? 0)
                  : (cumulativeAssists[j.id] ?? 0));
        }
        points.add(pt);
      }
    }

    // Top 10 jogadores com pontuação > 0 na métrica selecionada
    final topPlayers = _allJogadores.where((p) {
      final total = _chartMetric == 'ga'
          ? (cumulativeGA[p.id] ?? 0)
          : (_chartMetric == 'goals'
              ? (cumulativeGoals[p.id] ?? 0)
              : (cumulativeAssists[p.id] ?? 0));
      return total > 0;
    }).toList()
      ..sort((a, b) {
        final valA = _chartMetric == 'ga'
            ? (cumulativeGA[a.id] ?? 0)
            : (_chartMetric == 'goals'
                ? (cumulativeGoals[a.id] ?? 0)
                : (cumulativeAssists[a.id] ?? 0));
        final valB = _chartMetric == 'ga'
            ? (cumulativeGA[b.id] ?? 0)
            : (_chartMetric == 'goals'
                ? (cumulativeGoals[b.id] ?? 0)
                : (cumulativeAssists[b.id] ?? 0));
        return valB.compareTo(valA);
      });

    final displayTop = topPlayers.take(10).toList();
    if (displayTop.isEmpty) return const SizedBox.shrink();

    final activePoints = _animationIndex != null
        ? points.sublist(0, min(_animationIndex!, points.length))
        : points;

    // Constrói LineChartBarData para cada jogador do Top 10
    double maxY = 1.0;
    final List<LineChartBarData> lineBars = [];
    for (int i = 0; i < displayTop.length; i++) {
      final p = displayTop[i];
      final color = _chartColors[i % _chartColors.length];
      final List<FlSpot> spots = [];
      for (int x = 0; x < activePoints.length; x++) {
        final yVal = (activePoints[x][p.id] as int? ?? 0).toDouble();
        if (yVal > maxY) maxY = yVal;
        spots.add(FlSpot(x.toDouble(), yVal));
      }
      lineBars.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Vs.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Vs.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, color: _Vs.accentLight, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Evolução de Desempenho',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Controles de métrica, agrupamento e animação
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: _Vs.bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _Vs.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _metricChip('ga', 'G+A'),
                    _metricChip('goals', 'Gols'),
                    _metricChip('assists', 'Assist.'),
                  ],
                ),
              ),
              InkWell(
                onTap: () => setState(() => _chartGroupByDate = !_chartGroupByDate),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _chartGroupByDate,
                      onChanged: (v) => setState(() => _chartGroupByDate = v ?? false),
                      activeColor: _Vs.accent,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const Text('Por data', style: TextStyle(color: _Vs.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  if (_isPlaying) {
                    _animationTimer?.cancel();
                    setState(() => _isPlaying = false);
                  } else {
                    if (_animationIndex == points.length) {
                      _animationIndex = 1;
                    }
                    setState(() => _isPlaying = true);
                    _animationTimer?.cancel();
                    _animationTimer = Timer.periodic(
                      Duration(milliseconds: _chartGroupByDate ? 300 : 150),
                      (timer) {
                        setState(() {
                          final current = _animationIndex ?? 1;
                          if (current >= points.length) {
                            _isPlaying = false;
                            timer.cancel();
                          } else {
                            _animationIndex = current + 1;
                          }
                        });
                      },
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isPlaying
                        ? const Color(0xFF2D1B1B)
                        : const Color(0xFF1A2E20),
                    border: Border.all(
                      color: _isPlaying
                          ? const Color(0xFFFF5757).withOpacity(0.3)
                          : const Color(0xFF4CAF50).withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isPlaying
                            ? Icons.stop
                            : (_animationIndex == points.length ? Icons.replay : Icons.play_arrow),
                        size: 14,
                        color: _isPlaying ? const Color(0xFFFF5757) : const Color(0xFF4CAF50),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isPlaying
                            ? 'Parar'
                            : (_animationIndex == points.length ? 'Replay' : 'Animar'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _isPlaying ? const Color(0xFFFF5757) : const Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Gráfico
          SizedBox(
            height: 260,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: max(1.0, (activePoints.length - 1).toDouble()),
                minY: 0,
                maxY: maxY + 1,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) => FlLine(color: _Vs.border.withOpacity(0.5), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: max(1.0, (maxY / 4).floorToDouble()),
                      getTitlesWidget: (val, meta) => Text(
                        val.toInt().toString(),
                        style: const TextStyle(color: _Vs.textMuted, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: max(1.0, (activePoints.length / 6).floorToDouble()),
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < activePoints.length) {
                          return Text(
                            activePoints[idx]['name']?.toString() ?? '',
                            style: const TextStyle(color: _Vs.textMuted, fontSize: 10),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: lineBars,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Chips de legenda com foto e cor
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: displayTop.asMap().entries.map((entry) {
              final idx = entry.key;
              final p = entry.value;
              final color = _chartColors[idx % _chartColors.length];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _Vs.bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _Vs.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _initials(p.name),
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      p.name,
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String key, String label) {
    final selected = _chartMetric == key;
    return GestureDetector(
      onTap: () => setState(() => _chartMetric = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? _Vs.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _Vs.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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
                      Container(
                        width: avatarSizes[idx],
                        height: avatarSizes[idx],
                        decoration: BoxDecoration(
                          color: _Vs.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _initials(s.jogador.name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
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
                  Text(
                    s.jogador.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
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
                        colors: [color.withOpacity(0.18), Colors.transparent],
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
  // 4 TABELAS AUXILIARES (Gols Contra, Nota Média, Taxa de Vitórias, Duplas)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAuxiliaryTables() {
    final ownGoalsPlayers = List<PlayerStatsAgg>.from(stats)
        .where((s) => s.ownGoals > 0)
        .toList()
      ..sort((a, b) => b.ownGoals.compareTo(a.ownGoals));

    final topRatingPlayers = List<PlayerStatsAgg>.from(stats)
        .where((s) => s.matches >= 5)
        .toList()
      ..sort((a, b) => b.formLast10.compareTo(a.formLast10));

    final topWinRatePlayers = List<PlayerStatsAgg>.from(stats)
        .where((s) => s.matches >= 10)
        .toList()
      ..sort((a, b) => b.winRate.compareTo(a.winRate));

    return Column(
      children: [
        // Gols Contra
        _buildSimpleCard(
          title: '⛔ Quadro de Gols Contra',
          child: Column(
            children: [
              _buildTableHeader(['#', 'Jogador', 'Gols Contra']),
              if (ownGoalsPlayers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nenhum gol contra registrado.', style: TextStyle(color: _Vs.textMuted, fontSize: 12)),
                )
              else
                ...ownGoalsPlayers.take(5).toList().asMap().entries.map((entry) {
                  final i = entry.key;
                  final p = entry.value;
                  return _buildTableRow(
                    index: i + 1,
                    player: p.jogador.name,
                    values: [p.ownGoals.toString()],
                    onTap: () => _openPlayer(p),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Nota Média Recebida
        _buildSimpleCard(
          title: '⭐ Nota média recebida (escala 0-10)',
          child: Column(
            children: [
              _buildTableHeader(['#', 'Jogador', 'Média', 'Partidas']),
              if (topRatingPlayers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Mínimo 5 partidas para qualificação.', style: TextStyle(color: _Vs.textMuted, fontSize: 12)),
                )
              else
                ...topRatingPlayers.take(5).toList().asMap().entries.map((entry) {
                  final i = entry.key;
                  final p = entry.value;
                  return _buildTableRow(
                    index: i + 1,
                    player: p.jogador.name,
                    values: [p.formLast10.toStringAsFixed(2), p.matches.toString()],
                    onTap: () => _openPlayer(p),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Taxa de Vitórias
        _buildSimpleCard(
          title: '🏅 Taxa de Vitórias (mín. 10 partidas)',
          child: Column(
            children: [
              _buildTableHeader(['#', 'Jogador', 'Win %', 'Vitórias', 'Partidas']),
              if (topWinRatePlayers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Mínimo 10 partidas para qualificação.', style: TextStyle(color: _Vs.textMuted, fontSize: 12)),
                )
              else
                ...topWinRatePlayers.take(5).toList().asMap().entries.map((entry) {
                  final i = entry.key;
                  final p = entry.value;
                  return _buildTableRow(
                    index: i + 1,
                    player: p.jogador.name,
                    values: ['${p.winRate.toStringAsFixed(1)}%', p.wins.toString(), p.matches.toString()],
                    isHighlightFirst: true,
                    onTap: () => _openPlayer(p),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Duplas Dinâmicas
        _buildSimpleCard(
          title: '🤝 Duplas Dinâmicas (Gols em parceria)',
          child: Column(
            children: [
              _buildTableHeader(['#', 'Jogador 1', 'Jogador 2', 'Gols']),
              if (dynamicDuos.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nenhuma parceria registrada.', style: TextStyle(color: _Vs.textMuted, fontSize: 12)),
                )
              else
                ...dynamicDuos.asMap().entries.map((entry) {
                  final i = entry.key;
                  final duo = entry.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: _Vs.border)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: i == 0 ? _Vs.gold : (i == 1 ? _Vs.silver : (i == 2 ? _Vs.bronze : _Vs.textMuted)),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(child: Text(duo.p1Name, style: const TextStyle(color: Colors.white, fontSize: 13))),
                        Expanded(child: Text(duo.p2Name, style: const TextStyle(color: Colors.white, fontSize: 13))),
                        Text('${duo.count}', style: const TextStyle(color: _Vs.good, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleCard({required String title, required Widget child}) {
    return Container(
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
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(color: _Vs.border, height: 1),
          child,
        ],
      ),
    );
  }

  Widget _buildTableHeader(List<String> titles) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: _Vs.header,
      child: Row(
        children: titles.asMap().entries.map((entry) {
          final idx = entry.key;
          final title = entry.value;
          if (idx == 0) {
            return SizedBox(
              width: 24,
              child: Text(title, style: const TextStyle(color: _Vs.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
            );
          }
          if (idx == 1) {
            return Expanded(
              child: Text(title, style: const TextStyle(color: _Vs.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
            );
          }
          return SizedBox(
            width: 70,
            child: Text(
              title,
              textAlign: TextAlign.right,
              style: const TextStyle(color: _Vs.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTableRow({
    required int index,
    required String player,
    required List<String> values,
    bool isHighlightFirst = false,
    VoidCallback? onTap,
  }) {
    final color = index == 1 ? _Vs.gold : (index == 2 ? _Vs.silver : (index == 3 ? _Vs.bronze : _Vs.textMuted));

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _Vs.border)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$index',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            Expanded(
              child: Text(player, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
            ...values.asMap().entries.map((entry) {
              final idx = entry.key;
              final val = entry.value;
              final isGreen = isHighlightFirst && idx == 0;
              return SizedBox(
                width: 70,
                child: Text(
                  val,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: isGreen ? _Vs.good : (idx == 0 ? Colors.white : _Vs.textMuted),
                    fontWeight: isGreen || idx == 0 ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  void _showFullTable({required StatKey initialSort, required String title}) {
    showDialog(
      context: context,
      builder: (ctx) => _FullStatsTableDialog(
        title: title,
        stats: stats,
        initialSort: initialSort,
        onSelectPlayer: (s) {
          Navigator.pop(ctx);
          _openPlayer(s);
        },
      ),
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
      appBar: AppBar(
        backgroundColor: _Vs.panel,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estatísticas dos Jogadores', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Classificação geral, pódios e desempenho da turma', style: TextStyle(color: _Vs.textMuted, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _Vs.accentLight),
            onPressed: _loadData,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFilterBar(),
          const SizedBox(height: 20),

          // Evolução de Desempenho
          _buildPerformanceEvolutionChart(),

          // 7 Pódios Principais
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

          // Goleiros (Paredões)
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
              key: StatKey.gkNota,
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

          const SizedBox(height: 20),
          const Divider(color: _Vs.border),
          const SizedBox(height: 20),

          // 4 Tabelas Auxiliares
          _buildAuxiliaryTables(),
          const SizedBox(height: 32),
        ],
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
  final void Function(PlayerStatsAgg) onSelectPlayer;

  const _FullStatsTableDialog({
    required this.title,
    required this.stats,
    required this.initialSort,
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
        borderRadius: BorderRadius.circular(8),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
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
                    columnSpacing: 18,
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
                      const DataColumn(
                        label: Text('Rating', style: TextStyle(color: _Vs.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    rows: sorted.asMap().entries.map((entry) {
                      final i = entry.key;
                      final s = entry.value;
                      return DataRow(
                        onSelectChanged: (_) => widget.onSelectPlayer(s),
                        cells: [
                          DataCell(Text('${i + 1}', style: const TextStyle(color: _Vs.textMuted, fontSize: 12))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: _Vs.bg,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: _Vs.border),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    s.jogador.name.isNotEmpty
                                        ? s.jogador.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(s.jogador.name, style: const TextStyle(color: _Vs.text, fontSize: 12)),
                              ],
                            ),
                          ),
                          ..._cols.map((c) {
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
                            final v = s.statValue(c.key);
                            final display = c.key == StatKey.formLast10
                                ? v.toStringAsFixed(2)
                                : v.toStringAsFixed(0);
                            return DataCell(
                              Text(
                                display,
                                style: TextStyle(
                                  color: _sortKey == c.key ? Colors.white : _Vs.textStrong,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _Vs.bg,
                                border: Border.all(color: _Vs.border),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                s.overallRating.toStringAsFixed(2),
                                style: const TextStyle(color: _Vs.good, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ),
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

