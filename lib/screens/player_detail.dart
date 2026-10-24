import 'dart:convert';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/season_model.dart';
import '../models/player_badge_model.dart';
import '../repositories/supabase_service.dart';
import '../config/supabase_config.dart';
import '../utils/constants.dart';
import '../utils/player_identity.dart';
import '../utils/overall_calculator.dart';
import '../utils/rating_calculator.dart';
import '../utils/stats_calculator.dart';
import '../widgets/player/fifa_card.dart';
import '../widgets/shared/icon_picker_modal.dart';
import 'player_comparison_screen.dart';

class PlayerDetailScreen extends StatefulWidget {
  final String groupId;
  final String playerId;
  final String? initialPlayerName;
  final String? playerIcon;
  final String? tournamentId;

  const PlayerDetailScreen({
    super.key,
    required this.groupId,
    required this.playerId,
    this.initialPlayerName,
    this.playerIcon,
    this.tournamentId,
  });

  @override
  State<PlayerDetailScreen> createState() => _PlayerDetailScreenState();
}

class _PlayerDetailScreenState extends State<PlayerDetailScreen> {
  bool isLoading = true;
  int? rankPosition;
  int totalPlayers = 0;
  String playerName = '';
  String? resolvedIcon;
  String? _pendingIcon;
  bool _isSavingIcon = false;
  String? _creatorId;
  String? _goalSoundUrl;
  bool _isSavingAudio = false;

  bool get _canEditProfile {
    if (_isAdmin) return true;
    final currentUserId = SupabaseConfig.currentUserId;
    return currentUserId != null && _creatorId != null && currentUserId == _creatorId;
  }

  // ── Filtro de período ────────────────────────────────────────
  // Afeta TODOS os dados da tela (nota, ranking, stats, gráfico, avançadas).
  List<dynamic> _rawHistory = []; // histórico completo, sem filtro
  List<SeasonModel> _allSeasons = [];
  String _selectedPeriodKey =
      'all'; // 'all'|'last'|'month'|'year'|'custom'|seasonId
  DateTime? _customFrom;
  DateTime? _customTo;

  // ── Gráfico ──────────────────────────────────────────────────
  List<dynamic> _allHistory = []; // histórico já filtrado (usado na tela toda)
  String _chartMetric = 'Nota'; // 'Nota' ou 'G+A' (Gols/Assistências)
  String _chartPeriod = 'Sessão';
  bool _chartAccumulated = false; // dia a dia (false) ou acumulado (true)
  List<Map<String, dynamic>> _chartData = [];

  Map<String, dynamic> playerStats = {
    'name': '',
    'goals': 0,
    'assists': 0,
    'ga': 0,
    'games': 0,
    'wins': 0,
    'draws': 0,
    'losses': 0,
    'nota': kRatingBase,
    'yellow': 0,
    'red': 0,
  };

  Map<String, dynamic> advancedStats = {};
  List<Map<String, dynamic>> manualBadges = [];
  List<Map<String, dynamic>> _allPlayers = [];

  bool _showRadarChart = true;
  bool _isAdmin = false;

  /// Atributos da comunidade (PAC/SHO/PAS/DRI/DEF/PHY + override).
  CommunityAttributes _community = CommunityAttributes.empty;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadPlayerDetails();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await SupabaseService.instance.groupMembers
        .isCurrentUserAdmin(widget.groupId);
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showRadarChart = prefs.getBool('show_radar_chart') ?? true;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CARREGAMENTO PRINCIPAL
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadPlayerDetails() async {
    List<Map<String, dynamic>> players = [];
    try {
      final fetched = await SupabaseService.instance.players.getPlayersByGroup(
        widget.groupId,
      );
      players = fetched
          .map(
            (j) => {
              'id': j.id,
              'name': j.name,
              'icon': j.avatarUrl,
              'creator_id': j.creatorId,
              'goal_sound_url': j.goalSoundUrl,
              'manual_badges': j.manualBadges.map((b) => b.toMap()).toList(),
              'community': j.community,
            },
          )
          .toList();
    } catch (_) {}

    if (players.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final String playersKey = 'players_${widget.groupId}';
      if (prefs.containsKey(playersKey)) {
        players = ensurePlayerIds(
          List<Map<String, dynamic>>.from(
            jsonDecode(prefs.getString(playersKey)!),
          ),
        );
      }
    }

    final Map<String, dynamic>? player = players.firstWhere(
      (p) => (p['id'] ?? '').toString() == widget.playerId,
      orElse: () => {},
    );

    final String? icon = widget.playerIcon ?? player?['icon'] as String?;
    final String resolvedName =
        (player?['name'] ?? widget.initialPlayerName ?? '').toString();

    if (player?['manual_badges'] != null) {
      manualBadges = List<Map<String, dynamic>>.from(player!['manual_badges']);

      // Update with latest templates if available
      final prefs = await SharedPreferences.getInstance();
      final String cbKey = 'custom_badges_${widget.groupId}';
      if (prefs.containsKey(cbKey)) {
        final List<Map<String, dynamic>> templates =
            List<Map<String, dynamic>>.from(
              jsonDecode(prefs.getString(cbKey)!),
            );
        for (var i = 0; i < manualBadges.length; i++) {
          final badgeId = manualBadges[i]['id'];
          Map<String, dynamic>? tpl;

          if (badgeId != null) {
            tpl = templates.firstWhereOrNull((t) => t['id'] == badgeId);
          } else {
            // Legacy fallback: match by title or icon
            tpl = templates.firstWhereOrNull(
              (t) =>
                  t['title'] == manualBadges[i]['title'] ||
                  t['icon'] == manualBadges[i]['icon'],
            );
          }

          if (tpl != null) {
            manualBadges[i]['id'] = tpl['id'];
            manualBadges[i]['title'] = tpl['title'];
            manualBadges[i]['icon'] = tpl['icon'];
          }
        }
      }
    }

    final List<dynamic> rawHistory = await getAllGroupMatches(widget.groupId);

    List<SeasonModel> seasons = [];
    try {
      seasons = await SupabaseService.instance.seasons.getSeasons(
        widget.groupId,
      );
    } catch (_) {}

    // Filtro padrão: temporada ativa (igual à tela de estatísticas do grupo).
    // Se não houver temporadas cadastradas, mostra o histórico completo.
    String defaultPeriodKey = 'all';
    if (seasons.isNotEmpty) {
      final activeSeason =
          seasons.firstWhereOrNull((s) => s.isActive) ?? seasons.first;
      defaultPeriodKey = activeSeason.id;
    }

    _community =
        (player?['community'] as CommunityAttributes?) ?? CommunityAttributes.empty;

    _rawHistory = rawHistory;
    _allSeasons = seasons;
    _allPlayers = players;
    resolvedIcon = icon;
    playerName = resolvedName;
    _creatorId = player?['creator_id']?.toString();
    _goalSoundUrl = player?['goal_sound_url']?.toString();
    _selectedPeriodKey = defaultPeriodKey;

    _applyFilter();
    setState(() => isLoading = false);
  }

  // ─────────────────────────────────────────────────────────────
  // FILTRO DE PERÍODO — recalcula TODOS os dados da tela
  // ─────────────────────────────────────────────────────────────
  List<dynamic> _computeFilteredHistory() {
    if (_rawHistory.isEmpty) return [];

    DateTime? parseDate(dynamic m) {
      if (m is! Map) return null;
      final raw = m['session_date'] ?? m['date'];
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString());
    }

    if (_selectedPeriodKey == 'all') return _rawHistory;

    if (_selectedPeriodKey == 'last') {
      final sorted = List<dynamic>.from(_rawHistory)
        ..sort(
          (a, b) => (parseDate(a) ?? DateTime(0)).compareTo(
            parseDate(b) ?? DateTime(0),
          ),
        );
      final dynamic lastMatch = sorted.last;
      final dynamic lastSessionId = (lastMatch as Map)['sessionId'];
      if (lastSessionId == null) return [lastMatch];
      return sorted
          .where((m) => (m as Map)['sessionId'] == lastSessionId)
          .toList();
    }

    if (_selectedPeriodKey == 'month') {
      final now = DateTime.now();
      return _rawHistory.where((m) {
        final d = parseDate(m);
        return d != null && d.year == now.year && d.month == now.month;
      }).toList();
    }

    if (_selectedPeriodKey == 'year') {
      final now = DateTime.now();
      return _rawHistory.where((m) {
        final d = parseDate(m);
        return d != null && d.year == now.year;
      }).toList();
    }

    if (_selectedPeriodKey == 'custom') {
      if (_customFrom == null || _customTo == null) return _rawHistory;
      final endInclusive = DateTime(
        _customTo!.year,
        _customTo!.month,
        _customTo!.day,
        23,
        59,
        59,
      );
      return _rawHistory.where((m) {
        final d = parseDate(m);
        return d != null &&
            !d.isBefore(_customFrom!) &&
            !d.isAfter(endInclusive);
      }).toList();
    }

    // Filtro por temporada
    final season = _allSeasons.firstWhereOrNull(
      (s) => s.id == _selectedPeriodKey,
    );
    if (season != null && season.startDate != null) {
      final from = season.startDate!;
      final to = season.endDate != null
          ? DateTime(
              season.endDate!.year,
              season.endDate!.month,
              season.endDate!.day,
              23,
              59,
              59,
            )
          : DateTime.now();
      return _rawHistory.where((m) {
        final d = parseDate(m);
        return d != null && !d.isBefore(from) && !d.isAfter(to);
      }).toList();
    }

    return _rawHistory;
  }

  void _applyFilter() {
    final List<dynamic> filtered = _computeFilteredHistory();
    final globalStats = calculateGlobalStats(filtered);

    final List<Map<String, dynamic>> leaderboard = globalStats.values
        .where((data) => (data['games'] as int) >= kMinGamesForGlobalRanking)
        .toList();
    leaderboard.sort(
      (a, b) => (b['nota'] as double).compareTo(a['nota'] as double),
    );

    final int index = leaderboard.indexWhere(
      (p) => (p['id'] as String) == widget.playerId,
    );
    final Map<String, dynamic> advStats = _calculateAdvancedStats(filtered);

    setState(() {
      _allHistory = filtered;
      totalPlayers = leaderboard.length;
      advancedStats = advStats;

      if (index >= 0) {
        rankPosition = index + 1;
        playerStats = leaderboard[index];
      } else if (globalStats.containsKey(widget.playerId)) {
        rankPosition = null;
        playerStats = globalStats[widget.playerId]!;
      } else {
        rankPosition = null;
        playerStats = {
          'id': widget.playerId,
          'name': playerName,
          'nota': kRatingBase,
          'goals': 0,
          'assists': 0,
          'ga': 0,
          'games': 0,
          'wins': 0,
          'draws': 0,
          'losses': 0,
          'yellow': 0,
          'red': 0,
        };
      }
    });

    _calculateChartData();
  }

  void _onFilterChanged(String key) {
    setState(() => _selectedPeriodKey = key);
    _applyFilter();
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
              primary: AppColors.accentBlue,
              surface: AppColors.headerBlue,
            ),
          ),
          child: child!,
        );
      },
    );
    if (range != null) {
      _customFrom = range.start;
      _customTo = range.end;
      _onFilterChanged('custom');
    }
  }

  Widget _buildFilterBar() {
    final standardOpts = [
      {'id': 'last', 'label': 'Última Pelada'},
      {'id': 'month', 'label': 'Mês'},
      {'id': 'year', 'label': 'Ano'},
      {'id': 'all', 'label': 'Tudo'},
      {'id': 'custom', 'label': 'Personalizado'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.headerBlue,
            border: Border.all(color: Colors.white10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_allSeasons.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.deepBlue,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _allSeasons.any((s) => s.id == _selectedPeriodKey)
                          ? _selectedPeriodKey
                          : null,
                      hint: const Text(
                        'Temporadas',
                        style: TextStyle(
                          color: AppColors.accentBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      dropdownColor: AppColors.deepBlue,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: AppColors.accentBlue,
                        size: 18,
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      items: _allSeasons.map((s) {
                        return DropdownMenuItem<String>(
                          value: s.id,
                          child: Text('Temporada: ${s.name}'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) _onFilterChanged(val);
                      },
                    ),
                  ),
                ),
                Container(width: 1, height: 20, color: Colors.white10),
              ],
              ...standardOpts.map((o) {
                final bool isSelected = _selectedPeriodKey == o['id'];
                return GestureDetector(
                  onTap: () async {
                    if (o['id'] == 'custom') {
                      await _pickCustomRange();
                    } else {
                      _onFilterChanged(o['id']!);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentBlue
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      o['label']!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.white70,
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
              color: AppColors.headerBlue,
              border: Border.all(color: Colors.white10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'PERÍODO: ',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _customFrom != null
                      ? DateFormat('dd/MM/yyyy').format(_customFrom!)
                      : 'Início',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const Text(
                  ' até ',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  _customTo != null
                      ? DateFormat('dd/MM/yyyy').format(_customTo!)
                      : 'Fim',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _pickCustomRange,
                  child: const Icon(
                    Icons.edit_calendar,
                    size: 16,
                    color: AppColors.accentBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CÁLCULO DOS DADOS DO GRÁFICO
  // ─────────────────────────────────────────────────────────────

  void _calculateChartData() {
    if (_allHistory.isEmpty) return;

    final String myId = widget.playerId;
    final Map<String, Map<String, dynamic>> grouped = {};

    for (final match in _allHistory) {
      final List<dynamic> redPlayers = [
        ...(match['players']['red'] ?? []),
        match['players']['gk_red'],
      ].where((p) => p != null).toList();

      final List<dynamic> whitePlayers = [
        ...(match['players']['white'] ?? []),
        match['players']['gk_white'],
      ].where((p) => p != null).toList();

      final bool inRed = redPlayers.any((p) => playerIdFromObject(p) == myId);
      final bool inWhite = whitePlayers.any(
        (p) => playerIdFromObject(p) == myId,
      );
      if (!inRed && !inWhite) continue;

      final String myTeam = inRed ? 'red' : 'white';
      final int scoreRed = match['scoreRed'] ?? 0;
      final int scoreWhite = match['scoreWhite'] ?? 0;
      final int conceded = inRed ? scoreWhite : scoreRed;
      final int scored = inRed ? scoreRed : scoreWhite;

      int myTeamResult = 0;
      if (scoreRed != scoreWhite) {
        myTeamResult =
            (myTeam == 'red' && scoreRed > scoreWhite) ||
                (myTeam == 'white' && scoreWhite > scoreRed)
            ? 1
            : -1;
      }

      // Grouping key (session or month)
      final String rawDate =
          match['session_date'] ??
          match['date'] ??
          DateTime.now().toIso8601String();
      final DateTime dt = DateTime.parse(rawDate);
      final String groupKey = _chartPeriod == 'Mês'
          ? '${dt.month.toString().padLeft(2, '0')}/${dt.year.toString().substring(2)}'
          : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';

      grouped.putIfAbsent(
        groupKey,
        () => {
          'goals': 0,
          'assists': 0,
          'own_goals': 0,
          'games': 0,
          'yellow': 0,
          'red': 0,
          'wins': 0,
          'draws': 0,
          'losses': 0,
          'goals_conceded': 0,
          'ratings': <double>[],
          'date': dt,
        },
      );

      grouped[groupKey]!['games'] += 1;
      grouped[groupKey]!['goals_conceded'] += conceded;

      if (myTeamResult == 1)
        grouped[groupKey]!['wins'] += 1;
      else if (myTeamResult == -1)
        grouped[groupKey]!['losses'] += 1;
      else
        grouped[groupKey]!['draws'] += 1;

      int g = 0, a = 0, og = 0, yc = 0, rc = 0;
      if (match['events'] != null) {
        for (final ev in match['events']) {
          final String scorerId = eventPlayerId(ev, 'player');
          final String assistId = eventPlayerId(ev, 'assist');
          if (ev['type'] == 'goal') {
            if (scorerId == myId) g++;
            if (assistId == myId) a++;
          } else if (ev['type'] == 'own_goal' && scorerId == myId)
            og++;
          else if (ev['type'] == 'yellow_card' && scorerId == myId)
            yc++;
          else if (ev['type'] == 'red_card' && scorerId == myId)
            rc++;
        }
      }

      grouped[groupKey]!['goals'] += g;
      grouped[groupKey]!['assists'] += a;
      grouped[groupKey]!['own_goals'] += og;
      grouped[groupKey]!['yellow'] += yc;
      grouped[groupKey]!['red'] += rc;

      final double matchRating = calculateMatchRating(
        status: myTeamResult,
        goals: g,
        assists: a,
        ownGoals: og,
        teamGoals: scored,
        conceded: conceded,
        yellow: yc,
        red: rc,
        teamWinStreak: 0,
      );
      (grouped[groupKey]!['ratings'] as List<double>).add(matchRating);
    }

    final List<Map<String, dynamic>> chartList = [];
    grouped.forEach((key, data) {
      final int games = data['games'] as int;
      final double avgNota = calculateFinalRating(
        ratings: data['ratings'] as List<double>,
      );

      chartList.add({
        'label': key,
        'date': data['date'],
        'games': games,
        'Nota': avgNota,
        'Gols': data['goals'],
        'Assistências': data['assists'],
        'G+A': (data['goals'] as int) + (data['assists'] as int),
      });
    });

    chartList.sort(
      (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
    );
    setState(() {
      _chartData = chartList;
    });
  }

  // ─────────────────────────────────────────────────────────────
  // ESTATÍSTICAS AVANÇADAS
  // ─────────────────────────────────────────────────────────────

  Map<String, dynamic> _calculateAdvancedStats(List<dynamic> allHistory) {
    final Map<String, int> assistsGiven = {};
    final Map<String, int> assistsReceived = {};
    final Map<String, int> gamesWith = {};
    final Map<String, int> winsWith = {};
    final Map<String, int> lossesWith = {};
    final Map<String, int> gamesAgainst = {};
    final Map<String, int> winsAgainst = {};
    final Map<String, int> lossesAgainst = {};
    final Map<String, int> drawsAgainst = {};
    int hatTricks = 0;
    int cleanSheets = 0;
    int ownGoals = 0;
    int clutchGoals =
        0; // gols decisivos nos minutos finais (ver rating_calculator)
    int comebackGoals = 0; // gols da virada
    int currentUnbeatenStreak = 0;
    int maxUnbeatenStreak = 0;
    int biggestWinMargin = 0;
    String biggestWinScore = "-";
    int biggestLossMargin = 0;
    String biggestLossScore = "-";
    int totalTeamGoalsWhenPlaying = 0;

    final Map<String, String> playerNamesMap = {};
    final String myId = widget.playerId;

    final List<dynamic> sortedHistory = List.from(allHistory);
    sortedHistory.sort((a, b) {
      DateTime da =
          DateTime.tryParse(a['date'] ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      DateTime db =
          DateTime.tryParse(b['date'] ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return da.compareTo(db);
    });

    for (final match in sortedHistory) {
      final List<dynamic> redPlayers = [
        ...(match['players']['red'] ?? []),
        match['players']['gk_red'],
      ].where((p) => p != null).toList();

      final List<dynamic> whitePlayers = [
        ...(match['players']['white'] ?? []),
        match['players']['gk_white'],
      ].where((p) => p != null).toList();

      void registerName(dynamic p) {
        final String id = playerIdFromObject(p);
        if (id.isNotEmpty && !playerNamesMap.containsKey(id)) {
          playerNamesMap[id] = (p['name'] ?? '').toString();
        }
      }

      redPlayers.forEach(registerName);
      whitePlayers.forEach(registerName);

      final bool inRed = redPlayers.any((p) => playerIdFromObject(p) == myId);
      final bool inWhite = whitePlayers.any(
        (p) => playerIdFromObject(p) == myId,
      );
      if (!inRed && !inWhite) continue;

      final String myTeam = inRed ? 'red' : 'white';
      final int scoreRed = match['scoreRed'] ?? 0;
      final int scoreWhite = match['scoreWhite'] ?? 0;

      int myTeamResult = 0;
      int myTeamGoals = myTeam == 'red' ? scoreRed : scoreWhite;
      int opponentGoals = myTeam == 'red' ? scoreWhite : scoreRed;

      totalTeamGoalsWhenPlaying += myTeamGoals;

      if (myTeamGoals > opponentGoals)
        myTeamResult = 1;
      else if (myTeamGoals < opponentGoals)
        myTeamResult = -1;

      if (opponentGoals == 0) cleanSheets++;

      if (myTeamResult == 1) {
        int margin = myTeamGoals - opponentGoals;
        if (margin > biggestWinMargin) {
          biggestWinMargin = margin;
          biggestWinScore = "$myTeamGoals x $opponentGoals";
        }
      }

      if (myTeamResult == -1) {
        int margin = opponentGoals - myTeamGoals;
        if (margin > biggestLossMargin) {
          biggestLossMargin = margin;
          biggestLossScore = "$opponentGoals x $myTeamGoals";
        }
      }

      if (myTeamResult >= 0) {
        currentUnbeatenStreak++;
        if (currentUnbeatenStreak > maxUnbeatenStreak)
          maxUnbeatenStreak = currentUnbeatenStreak;
      } else {
        currentUnbeatenStreak = 0;
      }

      final List<dynamic> teammates = myTeam == 'red'
          ? redPlayers
          : whitePlayers;
      final List<dynamic> opponents = myTeam == 'red'
          ? whitePlayers
          : redPlayers;

      for (final t in teammates) {
        final String tId = playerIdFromObject(t);
        if (tId == myId || tId.isEmpty) continue;
        gamesWith[tId] = (gamesWith[tId] ?? 0) + 1;
        if (myTeamResult == 1) winsWith[tId] = (winsWith[tId] ?? 0) + 1;
        if (myTeamResult == -1) lossesWith[tId] = (lossesWith[tId] ?? 0) + 1;
      }

      for (final o in opponents) {
        final String oId = playerIdFromObject(o);
        if (oId == myId || oId.isEmpty) continue;
        gamesAgainst[oId] = (gamesAgainst[oId] ?? 0) + 1;
        if (myTeamResult == 1) winsAgainst[oId] = (winsAgainst[oId] ?? 0) + 1;
        if (myTeamResult == -1)
          lossesAgainst[oId] = (lossesAgainst[oId] ?? 0) + 1;
        if (myTeamResult == 0) drawsAgainst[oId] = (drawsAgainst[oId] ?? 0) + 1;
      }

      // Gols decisivos (clutch) e gols da virada, usando a mesma detecção
      // do rating_calculator. O histórico salva o time do evento no campo
      // 'time' (legado) e o horário real no campo 'minute'.
      if (match['events'] != null) {
        final List<dynamic> rawEvents = match['events'];
        final List<Map<String, dynamic>> feEvents = rawEvents
            .map<Map<String, dynamic>>((ev) {
              final String teamCode = (ev['time'] ?? '').toString();
              return {
                'type': ev['type'],
                'team': teamCode == 'red' ? 'Vermelho' : 'Branco',
                'time': (ev['minute'] ?? '00:00').toString(),
              };
            })
            .toList();
        final GoalContext special = findSpecialGoals(feEvents);
        if (special.clutchGoalIndex >= 0 &&
            eventPlayerId(rawEvents[special.clutchGoalIndex], 'player') ==
                myId) {
          clutchGoals++;
        }
        if (special.comebackGoalIndex >= 0 &&
            eventPlayerId(rawEvents[special.comebackGoalIndex], 'player') ==
                myId) {
          comebackGoals++;
        }
      }

      int goalsInThisMatch = 0;
      if (match['events'] != null) {
        for (final ev in match['events']) {
          if (ev['type'] == 'own_goal' && eventPlayerId(ev, 'player') == myId) {
            ownGoals++;
          }
          if (ev['type'] != 'goal') continue;
          final String scorerId = eventPlayerId(ev, 'player');
          final String assistId = eventPlayerId(ev, 'assist');
          if (scorerId == myId) {
            goalsInThisMatch++;
            if (assistId.isNotEmpty && assistId != myId) {
              assistsReceived[assistId] = (assistsReceived[assistId] ?? 0) + 1;
            }
          }
          if (assistId == myId && scorerId != myId && scorerId.isNotEmpty) {
            assistsGiven[scorerId] = (assistsGiven[scorerId] ?? 0) + 1;
          }
        }
      }
      if (goalsInThisMatch >= 3) hatTricks++;
    }

    Map<String, dynamic> findMax(
      Map<String, int> map, {
      Map<String, int>? ratioBaseMap,
      int minBase = 0,
    }) {
      if (map.isEmpty) return {'name': '-', 'count': 0};

      final candidates = map.entries.where((e) {
        if (ratioBaseMap == null) return e.value > 0;
        return (ratioBaseMap[e.key] ?? 0) >= minBase && e.value > 0;
      }).toList();

      if (candidates.isEmpty) return {'name': '-', 'count': 0};

      candidates.sort((a, b) {
        if (ratioBaseMap != null) {
          double ratioA = a.value / ratioBaseMap[a.key]!;
          double ratioB = b.value / ratioBaseMap[b.key]!;
          if (ratioB != ratioA) return ratioB.compareTo(ratioA);
          return ratioBaseMap[b.key]!.compareTo(
            ratioBaseMap[a.key]!,
          ); // Desempate: mais jogos
        }
        return b.value.compareTo(a.value);
      });

      final topId = candidates.first.key;
      return {
        'name': playerNamesMap[topId] ?? 'Desconhecido',
        'count': candidates.first.value,
        'base': ratioBaseMap?[topId] ?? 0,
      };
    }

    return {
      'topAssisted': findMax(assistsGiven),
      'topAssister': findMax(assistsReceived),
      'mostPlayedWith': findMax(gamesWith),
      'mostWinsWith': findMax(winsWith, ratioBaseMap: gamesWith, minBase: 5),
      'mostLossesWith': findMax(
        lossesWith,
        ratioBaseMap: gamesWith,
        minBase: 5,
      ),
      'mostPlayedAgainst': findMax(gamesAgainst),
      'mostWinsAgainst': findMax(
        winsAgainst,
        ratioBaseMap: gamesAgainst,
        minBase: 5,
      ),
      'mostLossesAgainst': findMax(
        lossesAgainst,
        ratioBaseMap: gamesAgainst,
        minBase: 5,
      ),
      'mostDrawsAgainst': findMax(drawsAgainst),
      'hatTricks': hatTricks,
      'cleanSheets': cleanSheets,
      'ownGoals': ownGoals,
      'clutchGoals': clutchGoals,
      'comebackGoals': comebackGoals,
      'biggestWinScore': biggestWinScore,
      'biggestLossScore': biggestLossScore,
      'maxUnbeatenStreak': maxUnbeatenStreak,
      'currentUnbeatenStreak': currentUnbeatenStreak,
      'totalTeamGoals': totalTeamGoalsWhenPlaying,
    };
  }

  // ─────────────────────────────────────────────────────────────
  // PERSISTÊNCIA
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _loadPlayer(SharedPreferences prefs) async {
    final String playersKey = 'players_${widget.groupId}';
    if (!prefs.containsKey(playersKey)) return null;
    final List<Map<String, dynamic>> players = ensurePlayerIds(
      List<Map<String, dynamic>>.from(jsonDecode(prefs.getString(playersKey)!)),
    );
    for (final player in players) {
      if ((player['id'] ?? '').toString() == widget.playerId) return player;
    }
    return null;
  }

  Future<void> _savePlayerName(String newName) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = 'players_${widget.groupId}';
    if (!prefs.containsKey(key)) return;
    final players = ensurePlayerIds(
      List<Map<String, dynamic>>.from(jsonDecode(prefs.getString(key)!)),
    );
    final int index = players.indexWhere(
      (p) => (p['id'] ?? '').toString() == widget.playerId,
    );
    if (index == -1) return;
    players[index]['name'] = newName;
    await prefs.setString(key, jsonEncode(players));
    setState(() {
      playerName = newName;
      playerStats['name'] = newName;
    });
  }

  Future<void> _savePlayerIcon(String iconPath) async {
    setState(() => _isSavingIcon = true);
    try {
      // 1. Persistir no Supabase
      await SupabaseService.instance.players.setPlayerIcon(
        playerId: widget.playerId,
        iconPath: iconPath,
      );

      // 2. Persistir no cache local
      final prefs = await SharedPreferences.getInstance();
      final String key = 'players_${widget.groupId}';
      if (prefs.containsKey(key)) {
        final players = ensurePlayerIds(
          List<Map<String, dynamic>>.from(jsonDecode(prefs.getString(key)!)),
        );
        final int index = players.indexWhere(
          (p) => (p['id'] ?? '').toString() == widget.playerId,
        );
        if (index != -1) {
          players[index]['icon'] = iconPath;
          await prefs.setString(key, jsonEncode(players));
        }
      }

      setState(() {
        resolvedIcon = iconPath;
        _pendingIcon = null;
        _isSavingIcon = false;
        final idx = _allPlayers.indexWhere((p) => p['id'] == widget.playerId);
        if (idx != -1) _allPlayers[idx]['icon'] = iconPath;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ícone atualizado com sucesso!")),
        );
      }
    } catch (e) {
      setState(() => _isSavingIcon = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar ícone: $e")),
        );
      }
    }
  }

  Future<void> _saveGoalSound(String? audioFile) async {
    setState(() => _isSavingAudio = true);
    try {
      final updated = await SupabaseService.instance.players.setGoalSound(
        playerId: widget.playerId,
        audioFileName: audioFile,
        groupId: widget.groupId,
      );

      setState(() {
        _goalSoundUrl = updated.goalSoundUrl;
        _isSavingAudio = false;
        final idx = _allPlayers.indexWhere((p) => p['id'] == widget.playerId);
        if (idx != -1) _allPlayers[idx]['goal_sound_url'] = updated.goalSoundUrl;
      });

      // Atualiza o snapshot local em SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final key = 'players_${widget.groupId}';
        final raw = prefs.getString(key);
        if (raw != null) {
          final list = List<Map<String, dynamic>>.from(jsonDecode(raw));
          final idx = list.indexWhere((p) => p['id'] == widget.playerId);
          if (idx != -1) {
            list[idx]['goal_sound_url'] = updated.goalSoundUrl;
            await prefs.setString(key, jsonEncode(list));
          }
        }
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              audioFile != null
                  ? "Som de gol salvo: ${getGoalAudioLabel(audioFile)}"
                  : "Som de gol redefinido para o padrão",
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSavingAudio = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar som de gol: $e")),
        );
      }
    }
  }

  void _showAudioPickerModal() {
    if (!_canEditProfile) return;
    String? playingFile;
    final localPlayer = AudioPlayer();
    StreamSubscription? completeSub;
    final List<String> selectedFiles =
        List<String>.from(parseGoalSounds(_goalSoundUrl));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
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
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  "Escolher Som de Gol",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Toque nos sons na ordem desejada para criar um loop de gols (1º gol, 2º gol...).",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                if (selectedFiles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.deepBlue.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Sequência do Loop (${selectedFiles.length} ${selectedFiles.length == 1 ? 'som' : 'sons'}):",
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (int i = 0; i < selectedFiles.length; i++)
                              Chip(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                backgroundColor: Colors.amber.withValues(alpha: 0.2),
                                side: const BorderSide(color: Colors.amber, width: 0.8),
                                label: Text(
                                  "${i + 1}º ${getGoalAudioLabel(selectedFiles[i])}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                deleteIcon: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.amber,
                                ),
                                onDeleted: () {
                                  setModalState(() {
                                    selectedFiles.removeAt(i);
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: availableGoalAudios.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (c, idx) {
                      final item = availableGoalAudios[idx];
                      final file = item['file']!;
                      final label = item['label']!;
                      final orderIndex = selectedFiles.indexOf(file);
                      final isSelected = orderIndex != -1;
                      final isPlayingThis = playingFile == file;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: IconButton(
                          icon: Icon(
                            isPlayingThis ? Icons.stop_circle : Icons.play_circle_fill,
                            color: Colors.amber,
                            size: 28,
                          ),
                          onPressed: () async {
                            if (isPlayingThis) {
                              await localPlayer.stop();
                              setModalState(() => playingFile = null);
                            } else {
                              await localPlayer.stop();
                              setModalState(() => playingFile = file);
                              completeSub?.cancel();
                              completeSub =
                                  localPlayer.onPlayerComplete.listen((_) {
                                if (ctx.mounted) {
                                  setModalState(() => playingFile = null);
                                }
                              });
                              await localPlayer.play(AssetSource('audio/$file'));
                            }
                          },
                        ),
                        title: Text(
                          label,
                          style: TextStyle(
                            color: isSelected ? Colors.amber : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          file,
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: isSelected
                              ? Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: Colors.amber,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    "${orderIndex + 1}º",
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.add_circle,
                                  color: Colors.amber,
                                  size: 28,
                                ),
                          tooltip: isSelected
                              ? "Remover do loop"
                              : "Adicionar ao loop",
                          onPressed: () {
                            setModalState(() {
                              if (isSelected) {
                                selectedFiles.remove(file);
                              } else {
                                selectedFiles.add(file);
                              }
                            });
                          },
                        ),
                        onTap: () {
                          setModalState(() {
                            if (isSelected) {
                              selectedFiles.remove(file);
                            } else {
                              selectedFiles.add(file);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check, size: 20),
                    label: Text(
                      selectedFiles.isEmpty
                          ? "Usar Som Padrão"
                          : selectedFiles.length == 1
                              ? "Salvar Som Selecionado"
                              : "Salvar Loop (${selectedFiles.length} Sons)",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _saveGoalSound(formatGoalSounds(selectedFiles));
                    },
                  ),
                ),
                if (_goalSoundUrl != null && _goalSoundUrl!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text("Redefinir para Padrão"),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _saveGoalSound(null);
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ).whenComplete(() async {
      await completeSub?.cancel();
      try {
        await localPlayer.stop();
        await localPlayer.dispose();
      } catch (_) {}
    });
  }


  Future<void> _saveManualBadge(String? id, String icon, String title) async {
    final prefs = await SharedPreferences.getInstance();
    final String playersKey = 'players_${widget.groupId}';

    // Update local cache
    if (prefs.containsKey(playersKey)) {
      final List<Map<String, dynamic>> loadedPlayers =
          List<Map<String, dynamic>>.from(
            jsonDecode(prefs.getString(playersKey)!),
          );
      final int index = loadedPlayers.indexWhere(
        (p) => (p['id'] ?? '').toString() == widget.playerId,
      );

      if (index != -1) {
        loadedPlayers[index]['manual_badges'] ??= [];
        loadedPlayers[index]['manual_badges'].add({
          'id': id,
          'icon': icon,
          'title': title,
        });
        await prefs.setString(playersKey, jsonEncode(loadedPlayers));
      }
    }

    setState(() {
      manualBadges.add({'id': id, 'icon': icon, 'title': title});
    });

    // Update in Supabase
    try {
      final player = await SupabaseService.instance.players.getPlayerById(
        widget.playerId,
      );
      if (player != null) {
        // Need to add it to their existing badges to be safe
        final updatedBadges = List.of(player.manualBadges);
        updatedBadges.add(PlayerBadgeModel(id: id, icon: icon, title: title));
        final updatedPlayer = player.copyWith(manualBadges: updatedBadges);
        await SupabaseService.instance.players.updatePlayer(updatedPlayer);
      }
    } catch (e) {
      debugPrint("Error updating badge in Supabase: $e");
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BADGES AUTOMÁTICOS
  // ─────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _generateAutomaticBadges() {
    final int games = playerStats['games'] ?? 0;
    final int goals = playerStats['goals'] ?? 0;
    final int assists = playerStats['assists'] ?? 0;
    final int yellow = playerStats['yellow'] ?? 0;
    final int red = playerStats['red'] ?? 0;
    final int wins = playerStats['wins'] ?? 0;
    final int hatTricks = advancedStats['hatTricks'] ?? 0;

    final List<Map<String, dynamic>> badges = [];

    if (games >= 50)
      badges.add({
        'icon': 'assets/icons/legendario.png',
        'title': 'Lenda',
        'desc': '50+ Jogos',
        'color': Colors.amber,
      });
    else if (games >= 20)
      badges.add({
        'icon': 'assets/icons/veterano.png',
        'title': 'Veterano',
        'desc': '20+ Jogos',
        'color': Colors.blueAccent,
      });

    if (goals >= 100)
      badges.add({
        'icon': 'assets/icons/rei_do_gol.png',
        'title': 'Rei do Gol',
        'desc': '100+ Gols',
        'color': Colors.orangeAccent,
      });
    else if (goals >= 50)
      badges.add({
        'icon': 'assets/icons/artilheiro.png',
        'title': 'Artilheiro',
        'desc': '50+ Gols',
        'color': Colors.greenAccent,
      });

    if (assists >= 50)
      badges.add({
        'icon': 'assets/icons/mago.png',
        'title': 'Mago',
        'desc': '50+ Assist.',
        'color': Colors.purpleAccent,
      });
    else if (assists >= 20)
      badges.add({
        'icon': 'assets/icons/garçom.png',
        'title': 'Garçom',
        'desc': '20+ Assist.',
        'color': Colors.lightBlue,
      });

    if (yellow + red >= 10)
      badges.add({
        'icon': 'assets/icons/açogueiro.png',
        'title': 'Açougueiro',
        'desc': '10+ Cartões',
        'color': Colors.redAccent,
      });

    if (games >= 20 && wins / games > 0.6)
      badges.add({
        'icon': 'assets/icons/talismã.png',
        'title': 'Talismã',
        'desc': '>60% Vitórias',
        'color': Colors.green,
      });

    if (hatTricks >= 5)
      badges.add({
        'icon': 'assets/icons/dono_da_bola.png',
        'title': 'Dono da Bola',
        'desc': '5+ Hat-Tricks',
        'color': Colors.yellow,
      });

    return badges;
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS VISUAIS
  // ─────────────────────────────────────────────────────────────

  String _sg(double v) => v >= 0 ? '+${v.toStringAsFixed(1)}' : v.toStringAsFixed(1);

  void _showRatingBreakdown() {
    final double nota = (playerStats['nota'] ?? kRatingBase) as double;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text(
          'Composição da Nota do App',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cada partida começa com a Nota Base (${kRatingBase.toStringAsFixed(1)}) e recebe ajustes pelo que você fez em campo. A nota exibida é a média das suas últimas $kFormWindowGames partidas (com menos de $kFormAnchorGames jogos, ela é puxada para a base).',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildBreakdownRow('Nota Base', kRatingBase.toStringAsFixed(1), Colors.white),
              _buildBreakdownRow('Gol feito', _sg(kWeightGoal), AppColors.accentBlue),
              _buildBreakdownRow('Assistência', _sg(kWeightAssist), AppColors.accentBlue),
              _buildBreakdownRow('Vitória', _sg(kResultImpactWin), AppColors.accentBlue),
              _buildBreakdownRow('Derrota', _sg(kResultImpactLoss), Colors.redAccent),
              _buildBreakdownRow('Sequência de vitórias (2 / 3+)', '${_sg(kStreakBonus2Wins)} / ${_sg(kStreakBonus3PlusWins)}', AppColors.accentBlue),
              _buildBreakdownRow('Saldo de gols (por gol)', '±${kGoalDiffImpact.toStringAsFixed(1)}', Colors.white70),
              _buildBreakdownRow('Clean sheet', _sg(kBonusCleanSheet), AppColors.accentBlue),
              _buildBreakdownRow('Gol sofrido (por gol)', _sg(kWeightConceded), Colors.redAccent),
              _buildBreakdownRow('Hat-trick (3+ gols)', _sg(kBonusHatTrick), AppColors.accentBlue),
              _buildBreakdownRow('3+ assistências', _sg(kBonusPlaymaker), AppColors.accentBlue),
              _buildBreakdownRow('Gol da virada', _sg(kBonusComebackGoal), AppColors.accentBlue),
              _buildBreakdownRow('Gol decisivo (fim de jogo)', _sg(kBonusClutchGoal), AppColors.accentBlue),
              _buildBreakdownRow('Cartão amarelo', _sg(kWeightYellowCard), Colors.yellow),
              _buildBreakdownRow('Cartão vermelho', _sg(kWeightRedCard), Colors.redAccent),
              _buildBreakdownRow('Gol contra', _sg(kWeightOwnGoal), Colors.redAccent),
              const Divider(color: Colors.white24, height: 24),
              Text(
                '* Gols e assistências extras na mesma partida valem ${(kDiminishingDecay * 100).round()}% do anterior. Vitória de time mais fraco vale mais; de time favorito, menos.',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Sua Nota Atual: ${nota.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: AppColors.accentBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Entendi',
              style: TextStyle(color: AppColors.accentBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 9.0) return Colors.purpleAccent;
    if (rating >= 8.0) return Colors.green[700]!;
    if (rating >= 7.0) return Colors.green;
    if (rating >= 6.0) return Colors.lightGreenAccent;
    if (rating >= 5.0) return Colors.yellow;
    if (rating >= 4.0) return Colors.orange;
    return Colors.red;
  }

  String _formatAdvStat(dynamic stat, String suffix, {int total = 0}) {
    if (stat == null || stat['count'] == 0) return '-';
    int count = stat['count'];
    if (total > 0) {
      double pct = (count / total) * 100;
      return '${stat['name']}\n($count $suffix - ${pct.toStringAsFixed(1)}%)';
    }
    return '${stat['name']}\n($count $suffix)';
  }

  // ─────────────────────────────────────────────────────────────
  // DIÁLOGOS
  // ─────────────────────────────────────────────────────────────

  Future<void> _showEditNameDialog() async {
    final controller = TextEditingController(text: playerName);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text(
          'Editar jogador',
          style: TextStyle(color: AppColors.textWhite),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Nome',
            labelStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              await _savePlayerName(newName);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text(
              'Salvar',
              style: TextStyle(
                color: AppColors.accentBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCompareModal() {
    // Filter out the current player
    final List<Map<String, dynamic>> rivals = _allPlayers
        .where((p) => (p['id'] ?? '').toString() != widget.playerId)
        .toList();

    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.deepBlue,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredRivals = rivals.where((r) {
            final name = (r['name'] ?? '').toString().toLowerCase();
            return name.contains(searchQuery.toLowerCase());
          }).toList();

          return FractionallySizedBox(
            heightFactor: 0.8,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Comparar com...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Selecione um jogador do grupo para iniciar o X1.',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (val) {
                      setModalState(() {
                        searchQuery = val;
                      });
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Pesquisar nome...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white54,
                      ),
                      filled: true,
                      fillColor: AppColors.headerBlue,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredRivals.length,
                      itemBuilder: (context, index) {
                        final rival = filteredRivals[index];
                        final String rivalId = (rival['id'] ?? '').toString();
                        final String rivalName =
                            (rival['name'] ?? 'Desconhecido').toString();
                        final String? rivalIcon = rival['icon'];
                        final String initial = rivalName.isNotEmpty
                            ? rivalName[0].toUpperCase()
                            : '?';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.headerBlue,
                            radius: 18,
                            child: rivalIcon != null
                                ? ClipOval(
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: Image.asset(
                                        rivalIcon,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  )
                                : Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                          title: Text(
                            rivalName,
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.white38,
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PlayerComparisonScreen(
                                  groupId: widget.groupId,
                                  player1Id: widget.playerId,
                                  player2Id: rivalId,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddManualBadgeDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final String key = 'custom_badges_${widget.groupId}';
    List<Map<String, dynamic>> availableCustomBadges = [];

    if (prefs.containsKey(key)) {
      availableCustomBadges = List<Map<String, dynamic>>.from(
        jsonDecode(prefs.getString(key)!),
      );
    }

    if (availableCustomBadges.isEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: AppColors.headerBlue,
          title: const Text(
            'Nenhum Troféu Disponível',
            style: TextStyle(color: Colors.amber),
          ),
          content: const Text(
            "Você precisa criar troféus na 'Fábrica de Troféus' antes de entregá-los.",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.deepBlue,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Entregar Prêmio',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Selecione o troféu que este jogador conquistou:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: availableCustomBadges.length,
                itemBuilder: (context, i) {
                  final badge = availableCustomBadges[i];
                  String? claimedByName;
                  for (final p in _allPlayers) {
                    final pBadges = p['manual_badges'] as List<dynamic>? ?? [];
                    for (final b in pBadges) {
                      if (b is Map &&
                          b['id'] == badge['id'] &&
                          p['id'] != widget.playerId) {
                        claimedByName = p['name']?.toString();
                        break;
                      }
                    }
                    if (claimedByName != null) break;
                  }

                  final bool isClaimed = claimedByName != null;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: ColorFiltered(
                          colorFilter: isClaimed
                              ? const ColorFilter.matrix([
                                  0.2126,
                                  0.7152,
                                  0.0722,
                                  0,
                                  0,
                                  0.2126,
                                  0.7152,
                                  0.0722,
                                  0,
                                  0,
                                  0.2126,
                                  0.7152,
                                  0.0722,
                                  0,
                                  0,
                                  0,
                                  0,
                                  0,
                                  1,
                                  0,
                                ])
                              : const ColorFilter.mode(
                                  Colors.transparent,
                                  BlendMode.multiply,
                                ),
                          child: Image.asset(
                            badge['icon'],
                            errorBuilder: (c, e, s) => const Icon(
                              Icons.emoji_events,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      badge['title'],
                      style: TextStyle(
                        color: isClaimed ? Colors.white38 : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      isClaimed
                          ? 'Resgatado por $claimedByName'
                          : badge['desc'],
                      style: TextStyle(
                        color: isClaimed
                            ? Colors.redAccent.withOpacity(0.8)
                            : Colors.white54,
                        fontSize: 12,
                        fontStyle: isClaimed
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                    onTap: isClaimed
                        ? null
                        : () {
                            _saveManualBadge(
                              badge['id'],
                              badge['icon'],
                              badge['title'],
                            );
                            Navigator.pop(ctx);
                          },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRemoveManualBadgeDialog(int index, String? badgeId) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text(
          'Remover Prêmio?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Deseja tirar este prêmio do jogador?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);

              // 1. Atualiza estado local imediatamente
              setState(() {
                manualBadges.removeAt(index);
              });

              // 2. Persiste no Supabase — remove por ID se disponível
              try {
                final player = await SupabaseService.instance.players
                    .getPlayerById(widget.playerId);
                if (player != null) {
                  List<PlayerBadgeModel> updatedBadges;
                  if (badgeId != null) {
                    updatedBadges = player.manualBadges
                        .where((b) => b.id != badgeId)
                        .toList();
                  } else {
                    // Fallback por índice se não houver ID
                    updatedBadges = List.of(player.manualBadges);
                    if (index >= 0 && index < updatedBadges.length) {
                      updatedBadges.removeAt(index);
                    }
                  }
                  final updatedPlayer =
                      player.copyWith(manualBadges: updatedBadges);
                  await SupabaseService.instance.players
                      .updatePlayer(updatedPlayer);
                }
              } catch (e) {
                debugPrint("Error removing badge from Supabase: $e");
              }

              // 3. Atualiza cache local SharedPreferences
              try {
                final prefs = await SharedPreferences.getInstance();
                final String playersKey = 'players_${widget.groupId}';
                if (prefs.containsKey(playersKey)) {
                  final List<Map<String, dynamic>> loadedPlayers =
                      List<Map<String, dynamic>>.from(
                        jsonDecode(prefs.getString(playersKey)!),
                      );
                  final int pIndex = loadedPlayers.indexWhere(
                    (p) => (p['id'] ?? '').toString() == widget.playerId,
                  );
                  if (pIndex != -1) {
                    final List badges = List.from(
                        loadedPlayers[pIndex]['manual_badges'] ?? []);
                    if (badgeId != null) {
                      badges.removeWhere((b) => b is Map && b['id'] == badgeId);
                    } else if (index >= 0 && index < badges.length) {
                      badges.removeAt(index);
                    }
                    loadedPlayers[pIndex]['manual_badges'] = badges;
                    await prefs.setString(playersKey, jsonEncode(loadedPlayers));
                  }
                }
              } catch (e) {
                debugPrint("Error updating local cache: $e");
              }
            },
            child: const Text(
              'Remover',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS DE CONTEÚDO
  // ─────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────
  // Transforma _chartData em série "dia a dia" ou "acumulada"
  // ─────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _seriesFor(List<String> keys) {
    if (!_chartAccumulated) return _chartData;

    final List<Map<String, dynamic>> result = [];
    final Map<String, num> running = {for (final k in keys) k: 0};
    int runningGames = 0;
    double runningRatingSum = 0; // soma ponderada por jogos (para Nota)

    for (final item in _chartData) {
      final Map<String, dynamic> acc = Map<String, dynamic>.from(item);
      for (final k in keys) {
        if (k == 'Nota') continue; // tratado à parte abaixo
        running[k] = (running[k] ?? 0) + (item[k] as num);
        acc[k] = running[k];
      }
      if (keys.contains('Nota')) {
        final int games = (item['games'] as int?) ?? 1;
        final double nota = (item['Nota'] as num).toDouble();
        runningRatingSum += nota * games;
        runningGames += games;
        acc['Nota'] = runningGames == 0
            ? nota
            : (runningRatingSum / runningGames);
      }
      result.add(acc);
    }
    return result;
  }

  Widget _buildEvolutionChart() {
    if (_chartData.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Jogue mais partidas para ver o gráfico.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final bool isNota = _chartMetric == 'Nota';
    final List<String> keys = isNota
        ? ['Nota']
        : ['G+A', 'Gols', 'Assistências'];
    final List<Map<String, dynamic>> series = _seriesFor(keys);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho do gráfico
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_graph, color: AppColors.accentBlue),
                  SizedBox(width: 8),
                  Text(
                    'Evolução',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.deepBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _chartPeriod,
                    dropdownColor: AppColors.deepBlue,
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white54,
                      size: 16,
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    items: ['Sessão', 'Mês']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _chartPeriod = v);
                        _calculateChartData();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Seletor de métrica + toggle acumulado
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Nota', 'G+A'].map((metric) {
                      final bool isSelected = _chartMetric == metric;
                      final String label = metric == 'G+A'
                          ? 'Gols e Assistências'
                          : metric;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _chartMetric = metric);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.accentBlue.withOpacity(0.2)
                                  : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.accentBlue
                                    : Colors.white24,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.accentBlue
                                    : Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () =>
                    setState(() => _chartAccumulated = !_chartAccumulated),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 22,
                      width: 22,
                      child: Checkbox(
                        value: _chartAccumulated,
                        activeColor: AppColors.accentBlue,
                        checkColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (v) =>
                            setState(() => _chartAccumulated = v ?? false),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Acumulado',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Gráfico
          SizedBox(
            height: 220,
            child: isNota
                ? _buildSingleLineChart(series)
                : _buildGoalsAssistsChart(series),
          ),

          if (!isNota) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendDot('G+A', AppColors.highlightBlue),
                const SizedBox(width: 16),
                _buildLegendDot('Gols', AppColors.highlightGreen),
                const SizedBox(width: 16),
                _buildLegendDot('Assistências', Colors.amberAccent),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildSingleLineChart(List<Map<String, dynamic>> series) {
    final List<FlSpot> spots = [];
    double maxY = kMaxRating;
    double minY = kMinRating;

    for (int i = 0; i < series.length; i++) {
      final double value = (series[i]['Nota'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), value));
    }

    const Color lineColor = Colors.amber;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        minX: 0,
        maxX: (spots.length - 1).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2.0,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Colors.white10, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, _) => Text(
                value.toStringAsFixed(1),
                style: const TextStyle(color: Colors.white54, fontSize: 10),
                textAlign: TextAlign.right,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, _) {
                final int i = value.toInt();
                if (i < 0 || i >= series.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    series[i]['label'],
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lineColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 4,
                color: lineColor,
                strokeWidth: 1.5,
                strokeColor: AppColors.headerBlue,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withOpacity(0.15),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              return LineTooltipItem(
                '${series[spot.x.toInt()]['label']}\n',
                const TextStyle(color: Colors.white70, fontSize: 10),
                children: [
                  TextSpan(
                    text: spot.y.toStringAsFixed(1),
                    style: const TextStyle(
                      color: lineColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildGoalsAssistsChart(List<Map<String, dynamic>> series) {
    List<FlSpot> spotsFor(String key) => [
      for (int i = 0; i < series.length; i++)
        FlSpot(i.toDouble(), (series[i][key] as num).toDouble()),
    ];

    final List<FlSpot> gaSpots = spotsFor('G+A');
    final List<FlSpot> golsSpots = spotsFor('Gols');
    final List<FlSpot> assistSpots = spotsFor('Assistências');

    double maxY = 0;
    for (final s in [...gaSpots, ...golsSpots, ...assistSpots]) {
      if (s.y > maxY) maxY = s.y;
    }
    maxY = (maxY + 2).ceilToDouble();

    Widget label(double value) => Text(
      value.toInt().toString(),
      style: const TextStyle(color: Colors.white54, fontSize: 10),
      textAlign: TextAlign.right,
    );

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        minX: 0,
        maxX: (series.length - 1).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1.0,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Colors.white10, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, _) => label(value),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, _) {
                final int i = value.toInt();
                if (i < 0 || i >= series.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    series[i]['label'],
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: golsSpots,
            isCurved: true,
            color: AppColors.highlightGreen,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 3,
                color: AppColors.highlightGreen,
                strokeWidth: 1,
                strokeColor: AppColors.headerBlue,
              ),
            ),
          ),
          LineChartBarData(
            spots: assistSpots,
            isCurved: true,
            color: Colors.amberAccent,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 3,
                color: Colors.amberAccent,
                strokeWidth: 1,
                strokeColor: AppColors.headerBlue,
              ),
            ),
          ),
          LineChartBarData(
            spots: gaSpots,
            isCurved: true,
            color: AppColors.highlightBlue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.highlightBlue.withOpacity(0.10),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              final String key = spot.barIndex == 0
                  ? 'Gols'
                  : spot.barIndex == 1
                  ? 'Assistências'
                  : 'G+A';
              final Color color = spot.barIndex == 0
                  ? AppColors.highlightGreen
                  : spot.barIndex == 1
                  ? Colors.amberAccent
                  : AppColors.highlightBlue;
              return LineTooltipItem(
                '${series[spot.x.toInt()]['label']}\n',
                const TextStyle(color: Colors.white70, fontSize: 10),
                children: [
                  TextSpan(
                    text: '$key: ${spot.y.toInt()}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildBadgesSection() {
    final List<Map<String, dynamic>> allAutoBadges = _generateAutomaticBadges();
    final List<Map<String, dynamic>> autoBadges = allAutoBadges
        .take(3)
        .toList();
    final bool hasMoreBadges = allAutoBadges.length > 3;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.emoji_events, color: Colors.amber),
                  SizedBox(width: 8),
                  Text(
                    'Sala de Troféus',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (hasMoreBadges)
                    TextButton(
                      onPressed: () => _showAllBadgesModal(allAutoBadges),
                      child: const Text(
                        'Ver Todas',
                        style: TextStyle(
                          color: AppColors.accentBlue,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (_isAdmin)
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: AppColors.accentBlue,
                      ),
                      tooltip: 'Dar Prêmio Manual',
                      onPressed: _showAddManualBadgeDialog,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (autoBadges.isEmpty && manualBadges.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Nenhuma conquista ainda. Continue jogando!',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
            )
          else ...[
            if (manualBadges.isNotEmpty) ...[
              const Text(
                'Prêmios Especiais',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: manualBadges.length,
                  itemBuilder: (_, i) => SizedBox(
                    width: 85,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _buildBadgeCard(
                        manualBadges[i],
                        isManual: true,
                        index: i,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (autoBadges.isNotEmpty) ...[
              const Text(
                'Conquistas Automáticas',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: autoBadges.length,
                  itemBuilder: (_, i) => SizedBox(
                    width: 85,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _buildBadgeCard(autoBadges[i], isManual: false),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _showAllBadgesModal(List<Map<String, dynamic>> allBadges) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.deepBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Todas as Conquistas',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: allBadges.length,
                itemBuilder: (context, index) =>
                    _buildBadgeCard(allBadges[index], isManual: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeCard(
    Map<String, dynamic> badge, {
    required bool isManual,
    int? index,
  }) {
    final Color badgeColor = isManual
        ? Colors.amber
        : (badge['color'] as Color? ?? Colors.blueAccent);
    return GestureDetector(
      onLongPress: () {
        if (isManual && index != null && _isAdmin) {
          _showRemoveManualBadgeDialog(index, badge['id']?.toString());
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: badgeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: badgeColor.withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 35,
                width: 35,
                child: Image.asset(
                  badge['icon'],
                  errorBuilder: (_, __, ___) => Icon(
                    isManual ? Icons.star : Icons.emoji_events,
                    color: isManual ? Colors.amber : badgeColor,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                badge['title'],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (!isManual)
                Text(
                  badge['desc'],
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statValue(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultColumn(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvStatRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.deepBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.deepBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRadarChart() {
    final int games = playerStats['games'] ?? 0;
    if (games == 0) return const SizedBox();

    final int goals = playerStats['goals'] ?? 0;
    final int assists = playerStats['assists'] ?? 0;
    final int cleanSheets = advancedStats['cleanSheets'] ?? 0;
    final int teamGoals = advancedStats['totalTeamGoals'] ?? 0;
    final int wins = playerStats['wins'] ?? 0;
    final int draws = playerStats['draws'] ?? 0;

    double attackScore = (goals / games) * 100;
    if (attackScore > 100) attackScore = 100;

    double visionScore = (assists / games) * 100;
    if (visionScore > 100) visionScore = 100;

    double defenseScore = (cleanSheets / games) * 200;
    if (defenseScore > 100) defenseScore = 100;

    double tacticScore = 0;
    if (teamGoals > 0) {
      int indirectGoals = teamGoals - goals - assists;
      if (indirectGoals < 0) indirectGoals = 0;
      tacticScore = (indirectGoals / teamGoals) * 100;
    }

    double ganaScore = 0;
    if (games > 0) ganaScore = ((wins * 3 + draws * 1) / (games * 3)) * 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.radar, color: AppColors.accentBlue),
                  SizedBox(width: 8),
                  Text(
                    'Perfil do Jogador',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(
                  Icons.info_outline,
                  color: Colors.white54,
                  size: 20,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.deepBlue,
                      title: const Text(
                        'Entenda o Gráfico',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      content: const Text(
                        'Ataque: Média de Gols por jogo.\n\n'
                        'Visão: Média de Assistências por jogo.\n\n'
                        'Defesa: Frequência de jogos sem sofrer gol (Clean Sheets).\n\n'
                        'Tática: Porcentagem de gols do time sem sua participação direta.\n\n'
                        'Gana: Taxa de vitórias e empates (Aproveitamento).',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Entendi',
                            style: TextStyle(color: AppColors.accentBlue),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: RadarChart(
              RadarChartData(
                tickCount: 5,
                ticksTextStyle: const TextStyle(color: Colors.transparent),
                tickBorderData: const BorderSide(color: Colors.white12),
                gridBorderData: const BorderSide(
                  color: Colors.white24,
                  width: 1.5,
                ),
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                radarBorderData: const BorderSide(color: Colors.transparent),
                getTitle: (index, angle) {
                  final text = [
                    'Ataque',
                    'Visão',
                    'Defesa',
                    'Tática',
                    'Gana',
                  ][index];
                  return RadarChartTitle(text: text, angle: angle);
                },
                dataSets: [
                  RadarDataSet(
                    fillColor: AppColors.accentBlue.withValues(alpha: 0.4),
                    borderColor: AppColors.accentBlue,
                    entryRadius: 3,
                    dataEntries: [
                      RadarEntry(value: attackScore),
                      RadarEntry(value: visionScore),
                      RadarEntry(value: defenseScore),
                      RadarEntry(value: tacticScore),
                      RadarEntry(value: ganaScore),
                    ],
                  ),
                ],
              ),
              swapAnimationDuration: const Duration(milliseconds: 150),
              swapAnimationCurve: Curves.linear,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────
  // ÍCONE
  // ─────────────────────────────────────────────────────────────
  void _openIconPicker() {
    if (!_canEditProfile) return;
    final effectiveIcon = _pendingIcon ?? resolvedIcon;
    final List<String> takenIcons = _allPlayers
        .map((p) => p['icon'] as String?)
        .where((icon) => icon != null && icon != effectiveIcon)
        .cast<String>()
        .toList();
    showIconPickerModal(
      context: context,
      takenIcons: takenIcons,
      currentIcon: effectiveIcon,
      onSelected: (path) {
        setState(() => _pendingIcon = path);
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // NOTA DO APP + COMPOSIÇÃO DO OVERALL
  // ─────────────────────────────────────────────────────────────
  Widget _statTile(String label, String value, {Color? color}) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.deepBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  Widget _overallRow(String label, String detail, String value,
      {Color valueColor = Colors.white, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: bold ? 18 : 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallSection(double nota, int overall) {
    final int games = playerStats['games'] ?? 0;
    final int wins = playerStats['wins'] ?? 0;
    final int draws = playerStats['draws'] ?? 0;
    final int losses = playerStats['losses'] ?? 0;
    final int goals = playerStats['goals'] ?? 0;
    final int assists = playerStats['assists'] ?? 0;
    final int yellow = playerStats['yellow'] ?? 0;
    final int red = playerStats['red'] ?? 0;

    final double app100 = appRatingTo100(nota);
    final double? comm = _community.communityRating;
    final double commUsed = comm ?? kCommunityNeutral;
    final Color notaColor = _getRatingColor(nota);

    String commDetail;
    if (_community.ratingOverride != null) {
      commDetail = 'Valor informado diretamente pelo admin';
    } else if (_community.average != null) {
      commDetail = 'Média simples dos 6 atributos (PAC, SHO, PAS, DRI, DEF, PHY)';
    } else {
      commDetail = 'Ainda sem avaliação da comunidade: usando ${kCommunityNeutral.round()} (neutro)';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Nota do App ─────────────────────────────────
          Row(
            children: [
              const Icon(Icons.analytics, color: AppColors.accentBlue),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Nota do App',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _showRatingBreakdown,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: notaColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${nota.toStringAsFixed(1)} / 10',
                        style: const TextStyle(
                          color: AppColors.headerBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.info_outline,
                          size: 14, color: AppColors.headerBlue),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Calculada automaticamente a partir dos números coletados nas partidas do período selecionado: resultados (vitórias, empates, derrotas), gols, assistências, cartões, gols contra, clean sheets, hat-tricks, gols da virada e gols decisivos.',
            style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statTile('Jogos', '$games'),
              _statTile('Vitórias', '$wins', color: Colors.greenAccent),
              _statTile('Empates', '$draws'),
              _statTile('Derrotas', '$losses', color: Colors.redAccent),
              _statTile('Gols', '$goals'),
              _statTile('Assistências', '$assists', color: Colors.amber),
              _statTile('Gols contra', '${advancedStats['ownGoals'] ?? 0}'),
              _statTile('Amarelos', '$yellow', color: Colors.yellow),
              _statTile('Vermelhos', '$red', color: Colors.redAccent),
              _statTile('Clean sheets', '${advancedStats['cleanSheets'] ?? 0}'),
              _statTile('Hat-tricks', '${advancedStats['hatTricks'] ?? 0}'),
              _statTile('Gols da virada', '${advancedStats['comebackGoals'] ?? 0}'),
              _statTile('Gols decisivos', '${advancedStats['clutchGoals'] ?? 0}'),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _showRatingBreakdown,
              icon: const Icon(Icons.help_outline, size: 16),
              label: const Text('Ver quanto vale cada número'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentBlue,
                padding: const EdgeInsets.symmetric(horizontal: 0),
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 20),

          // ── Composição do Overall ───────────────────────
          const Row(
            children: [
              Icon(Icons.military_tech, color: Colors.amber),
              SizedBox(width: 8),
              Text(
                'Como o Overall é calculado',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _overallRow(
            'Nota do App × ${(kOverallAppWeight * 100).round()}%',
            'Nota do App (${nota.toStringAsFixed(1)}) × 10 = ${app100.toStringAsFixed(0)}',
            (app100 * kOverallAppWeight).toStringAsFixed(1),
          ),
          _overallRow(
            'Nota da Comunidade × ${(kOverallCommunityWeight * 100).round()}%',
            commDetail,
            (commUsed * kOverallCommunityWeight).toStringAsFixed(1),
          ),
          const Divider(color: Colors.white12, height: 16),
          _overallRow(
            'Overall',
            'Arredondado, de 0 a $kOverallMax',
            '$overall',
            valueColor: AppColors.highlightGreen,
            bold: true,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ADMIN: EDITAR ATRIBUTOS DA COMUNIDADE
  // ─────────────────────────────────────────────────────────────
  Future<void> _showEditCommunityDialog() async {
    if (!_isAdmin) return;

    final Map<String, TextEditingController> ctrls = {
      for (final k in kAttributeKeys)
        k: TextEditingController(text: _community.valueOf(k)?.toString() ?? ''),
    };
    final overrideCtrl = TextEditingController(
      text: _community.ratingOverride != null
          ? _community.ratingOverride!.toString()
          : '',
    );
    final double nota = (playerStats['nota'] ?? kRatingBase) as double;
    bool saving = false;
    String? errorText;

    // Lê o formulário. Retorna null (e preenche errorText) se houver valor inválido.
    CommunityAttributes? readForm(void Function(String?) setError) {
      final Map<String, int?> vals = {};
      for (final k in kAttributeKeys) {
        final txt = ctrls[k]!.text.trim();
        if (txt.isEmpty) {
          vals[k] = null;
          continue;
        }
        final v = int.tryParse(txt);
        if (v == null || v < 0 || v > 100) {
          setError('${kAttributeLabels[k]}: use um número inteiro de 0 a 100.');
          return null;
        }
        vals[k] = v;
      }
      double? ov;
      final ovTxt = overrideCtrl.text.trim().replaceAll(',', '.');
      if (ovTxt.isNotEmpty) {
        ov = double.tryParse(ovTxt);
        if (ov == null || ov < 0 || ov > 100) {
          setError('Nota da comunidade (override): use um valor de 0 a 100.');
          return null;
        }
      }
      setError(null);
      return CommunityAttributes(
        pac: vals['pac'],
        sho: vals['sho'],
        pas: vals['pas'],
        dri: vals['dri'],
        def: vals['def'],
        phy: vals['phy'],
        ratingOverride: ov,
      );
    }

    InputDecoration deco(String label, {String? hint}) => InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
          hintStyle: const TextStyle(color: Colors.white24),
          filled: true,
          fillColor: AppColors.deepBlue.withValues(alpha: 0.6),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: AppColors.accentBlue.withValues(alpha: 0.7),
            ),
          ),
        );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.headerBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            // Prévia ao vivo (sem salvar nada)
            String preview = '';
            String? ignored;
            final draft = readForm((e) => ignored = e);
            if (draft != null) {
              final c = draft.communityRating;
              final ov = calculateOverall(appRating10: nota, community: draft);
              preview = c != null
                  ? 'Nota da Comunidade: ${c.toStringAsFixed(1)}  →  Overall: $ov'
                  : 'Preencha os 6 atributos (ou o override) para calcular a Nota da Comunidade. Overall agora: $ov';
            }

            Widget field(String k) => Expanded(
                  child: TextField(
                    controller: ctrls[k],
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: deco('${kAttributeLabels[k]} · ${kAttributeDescriptions[k]}'),
                    onChanged: (_) => setModal(() {}),
                  ),
                );

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Atributos da comunidade · $playerName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Valores de 0 a 100. A Nota da Comunidade é a média dos 6 atributos.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [field('pac'), const SizedBox(width: 10), field('dri')]),
                    const SizedBox(height: 10),
                    Row(children: [field('sho'), const SizedBox(width: 10), field('def')]),
                    const SizedBox(height: 10),
                    Row(children: [field('pas'), const SizedBox(width: 10), field('phy')]),
                    const SizedBox(height: 10),
                    TextField(
                      controller: overrideCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: deco(
                        'Nota da Comunidade (override, opcional)',
                        hint: 'Se preenchida, substitui a média',
                      ),
                      onChanged: (_) => setModal(() {}),
                    ),
                    const SizedBox(height: 12),
                    if (preview.isNotEmpty)
                      Text(
                        preview,
                        style: const TextStyle(
                          color: AppColors.highlightGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          errorText!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: saving
                              ? null
                              : () {
                                  for (final c in ctrls.values) {
                                    c.clear();
                                  }
                                  overrideCtrl.clear();
                                  setModal(() {});
                                },
                          child: const Text('Limpar',
                              style: TextStyle(color: Colors.redAccent)),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: saving ? null : () => Navigator.pop(ctx),
                          child: const Text('Cancelar',
                              style: TextStyle(color: Colors.white54)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  final attrs = readForm((e) => errorText = e);
                                  if (attrs == null) {
                                    setModal(() {});
                                    return;
                                  }
                                  setModal(() => saving = true);
                                  try {
                                    final updated = await SupabaseService
                                        .instance.players
                                        .setCommunityAttributes(
                                      groupId: widget.groupId,
                                      playerId: widget.playerId,
                                      attributes: attrs,
                                    );
                                    if (mounted) {
                                      setState(() => _community = updated.community);
                                    }
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (e) {
                                    errorText = 'Erro ao salvar: $e';
                                    setModal(() => saving = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentBlue,
                            foregroundColor: Colors.white,
                          ),
                          child: saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Salvar'),
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

    // O Future do sheet completa ao dar pop, mas os TextFields seguem na árvore
    // durante a animação de saída: descartar já causa "controller used after
    // being disposed". Espera a animação terminar.
    Future.delayed(const Duration(milliseconds: 500), () {
      for (final c in ctrls.values) {
        c.dispose();
      }
      overrideCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final int wins = playerStats['wins'] ?? 0;
    final int draws = playerStats['draws'] ?? 0;
    final int losses = playerStats['losses'] ?? 0;
    final int totalResults = wins + draws + losses;
    final double nota = (playerStats['nota'] ?? kRatingBase) as double;
    final String displayName = playerName.isNotEmpty
        ? playerName
        : (widget.initialPlayerName ?? 'Jogador');
    final int overall = calculateOverall(appRating10: nota, community: _community);

    final int goals = playerStats['goals'] ?? 0;
    final int assists = playerStats['assists'] ?? 0;

    double aproveitamento = 0;
    if (totalResults > 0) {
      aproveitamento = ((wins * 3 + draws * 1) / (totalResults * 3)) * 100;
    }
    String aproveitamentoStr = totalResults > 0
        ? '${aproveitamento.toStringAsFixed(1)}%'
        : '-';

    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
        centerTitle: true,
        elevation: 0,
        title: Text(
          displayName,
          style: const TextStyle(color: AppColors.textWhite),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentBlue),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Card FIFA do jogador ────────────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.headerBlue,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10, width: 1),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 240,
                          child: FifaCard(
                            name: displayName,
                            iconPath: _pendingIcon ?? resolvedIcon,
                            overall: overall,
                            attributes: _community,
                            onIconTap: _canEditProfile ? _openIconPicker : null,
                          ),
                        ),
                        if (_pendingIcon != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: _isSavingIcon
                                    ? null
                                    : () => _savePlayerIcon(_pendingIcon!),
                                icon: _isSavingIcon
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                      )
                                    : const Icon(Icons.check, size: 18),
                                label: Text(
                                  _isSavingIcon ? "Salvando..." : "Salvar Ícone",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: _isSavingIcon
                                    ? null
                                    : () => setState(() => _pendingIcon = null),
                                child: const Text(
                                  "Cancelar",
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (_canEditProfile && _pendingIcon == null)
                              OutlinedButton.icon(
                                onPressed: _openIconPicker,
                                icon: const Icon(Icons.photo_camera_front, size: 16),
                                label: const Text('Mudar foto'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(color: Colors.white24),
                                ),
                              ),
                            OutlinedButton.icon(
                              onPressed: _showEditNameDialog,
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Editar nome'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(color: Colors.white24),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _showCompareModal,
                              icon: const Icon(Icons.compare_arrows, size: 16),
                              label: const Text('Comparar'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.highlightGreen,
                                side: const BorderSide(
                                  color: AppColors.highlightGreen,
                                ),
                              ),
                            ),
                            // Só admins veem o botão de editar os atributos.
                            if (_isAdmin)
                              OutlinedButton.icon(
                                onPressed: _showEditCommunityDialog,
                                icon: const Icon(Icons.tune, size: 16),
                                label: const Text('Atributos'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.amber,
                                  side: const BorderSide(color: Colors.amber),
                                ),
                              ),
                          ],
                        ),
                        if (_canEditProfile) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.deepBlue.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.music_note, color: Colors.amber, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Som de Gol",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        getGoalAudioLabel(_goalSoundUrl),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _isSavingAudio
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.amber,
                                        ),
                                      )
                                    : TextButton.icon(
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.amber,
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                        ),
                                        icon: const Icon(Icons.edit, size: 14),
                                        label: const Text("Alterar", style: TextStyle(fontSize: 12)),
                                        onPressed: _showAudioPickerModal,
                                      ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          rankPosition != null
                              ? 'Ranking Histórico Geral: #$rankPosition / $totalPlayers'
                              : 'Em Avaliação (Estreante)',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  _buildFilterBar(),

                  const SizedBox(height: 16),
                  _buildOverallSection(nota, overall),

                  const SizedBox(height: 16),
                  _buildBadgesSection(),

                  const SizedBox(height: 16),
                  _buildEvolutionChart(),

                  const SizedBox(height: 16),

                  // ── Estatísticas ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.headerBlue,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _statValue(
                              'G+A',
                              '${playerStats['ga'] ?? 0}',
                              AppColors.highlightGreen,
                            ),
                            _statValue(
                              'Gols',
                              '${playerStats['goals'] ?? 0}',
                              AppColors.textWhite,
                            ),
                            _statValue(
                              'Assistências',
                              '${playerStats['assists'] ?? 0}',
                              Colors.amber,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            _resultColumn('Vitórias', wins, Colors.greenAccent),
                            _resultColumn(
                              'Empates',
                              draws,
                              Colors.grey.shade300,
                            ),
                            _resultColumn('Derrotas', losses, Colors.redAccent),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            height: 14,
                            child: Row(
                              children: totalResults == 0
                                  ? const [
                                      Expanded(
                                        child: ColoredBox(
                                          color: Color(0x334CAF50),
                                        ),
                                      ),
                                      Expanded(
                                        child: ColoredBox(
                                          color: Color(0x33424242),
                                        ),
                                      ),
                                      Expanded(
                                        child: ColoredBox(
                                          color: Color(0x33F44336),
                                        ),
                                      ),
                                    ]
                                  : [
                                      Expanded(
                                        flex: wins == 0 ? 1 : wins,
                                        child: const ColoredBox(
                                          color: Colors.green,
                                        ),
                                      ),
                                      Expanded(
                                        flex: draws == 0 ? 1 : draws,
                                        child: const ColoredBox(
                                          color: Colors.black54,
                                        ),
                                      ),
                                      Expanded(
                                        flex: losses == 0 ? 1 : losses,
                                        child: const ColoredBox(
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Estatísticas Avançadas ────────────────────────────
                  if (_showRadarChart) _buildRadarChart(),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.headerBlue,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.psychology, color: AppColors.accentBlue),
                            SizedBox(width: 8),
                            Text(
                              'Estatísticas Avançadas',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildAdvStatRow(
                          'Aproveitamento',
                          aproveitamentoStr,
                          Icons.pie_chart,
                          Colors.purpleAccent,
                        ),
                        _buildAdvStatRow(
                          'Hat-Tricks (3 Gols/Jogo)',
                          '${advancedStats['hatTricks'] ?? 0} marcados',
                          Icons.whatshot,
                          Colors.orangeAccent,
                        ),
                        _buildAdvStatRow(
                          'Gols Clutch (Decisivos)',
                          '${advancedStats['clutchGoals'] ?? 0} nos minutos finais',
                          Icons.bolt,
                          Colors.amberAccent,
                        ),
                        _buildAdvStatRow(
                          'Gols da Virada',
                          '${advancedStats['comebackGoals'] ?? 0} colocaram o time na frente',
                          Icons.trending_up,
                          AppColors.highlightGreen,
                        ),
                        _buildAdvStatRow(
                          'Sequência Atual Sem Perder',
                          '${advancedStats['currentUnbeatenStreak'] ?? 0} jogos',
                          Icons.local_fire_department,
                          Colors.deepOrangeAccent,
                        ),
                        _buildAdvStatRow(
                          'Faltas Graves',
                          '${playerStats['yellow'] ?? 0} Amarelos / ${playerStats['red'] ?? 0} Vermelhos',
                          Icons.style,
                          Colors.redAccent,
                        ),
                        _buildAdvStatRow(
                          'Clean Sheets',
                          '${advancedStats['cleanSheets'] ?? 0} jogos sem tomar gol',
                          Icons.shield,
                          Colors.blueAccent,
                        ),
                        _buildAdvStatRow(
                          'Gols Contra',
                          '${advancedStats['ownGoals'] ?? 0} marcados',
                          Icons.error_outline,
                          Colors.red,
                        ),
                        _buildAdvStatRow(
                          'Maior Sequência Invicta',
                          '${advancedStats['maxUnbeatenStreak'] ?? 0} jogos',
                          Icons.local_fire_department,
                          Colors.orange,
                        ),
                        _buildAdvStatRow(
                          'Maior Goleada a Favor',
                          '${advancedStats['biggestWinScore'] ?? "-"}',
                          Icons.sentiment_very_satisfied,
                          Colors.greenAccent,
                        ),
                        _buildAdvStatRow(
                          'Maior Derrota',
                          '${advancedStats['biggestLossScore'] ?? "-"}',
                          Icons.sentiment_very_dissatisfied,
                          Colors.redAccent,
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        const Text(
                          'Curiosidades e Rivalidades',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1.15,
                          children: [
                            _buildGridCard(
                              'Garçom Favorito',
                              _formatAdvStat(
                                advancedStats['topAssister'],
                                'gols seus',
                                total: goals,
                              ),
                              Icons.handshake,
                              Colors.amber,
                            ),
                            _buildGridCard(
                              'Mais Assistiu',
                              _formatAdvStat(
                                advancedStats['topAssisted'],
                                'suas assist.',
                                total: assists,
                              ),
                              Icons.sports_soccer,
                              Colors.greenAccent,
                            ),
                            _buildGridCard(
                              'Mais Jogou Junto',
                              _formatAdvStat(
                                advancedStats['mostPlayedWith'],
                                'jogos',
                                total: totalResults,
                              ),
                              Icons.people,
                              Colors.white,
                            ),
                            _buildGridCard(
                              'Mais Venceu Junto',
                              _formatAdvStat(
                                advancedStats['mostWinsWith'],
                                'vitórias',
                                total:
                                    advancedStats['mostWinsWith']['base'] ?? 0,
                              ),
                              Icons.thumb_up,
                              Colors.green,
                            ),
                            _buildGridCard(
                              'Mais Perdeu Junto',
                              _formatAdvStat(
                                advancedStats['mostLossesWith'],
                                'derrotas',
                                total:
                                    advancedStats['mostLossesWith']['base'] ??
                                    0,
                              ),
                              Icons.thumb_down,
                              Colors.redAccent,
                            ),
                            _buildGridCard(
                              'Maior Rival',
                              _formatAdvStat(
                                advancedStats['mostPlayedAgainst'],
                                'jogos contra',
                                total: totalResults,
                              ),
                              Icons.local_fire_department,
                              Colors.orange,
                            ),
                            _buildGridCard(
                              'Maior Freguês',
                              _formatAdvStat(
                                advancedStats['mostWinsAgainst'],
                                'vitórias',
                                total:
                                    advancedStats['mostWinsAgainst']['base'] ??
                                    0,
                              ),
                              Icons.mood,
                              Colors.blueAccent,
                            ),
                            _buildGridCard(
                              'Carrasco',
                              _formatAdvStat(
                                advancedStats['mostLossesAgainst'],
                                'derrotas',
                                total:
                                    advancedStats['mostLossesAgainst']['base'] ??
                                    0,
                              ),
                              Icons.mood_bad,
                              Colors.red,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
