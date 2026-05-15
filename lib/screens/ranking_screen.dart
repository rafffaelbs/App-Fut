import 'dart:convert';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/screens/player_detail.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../utils/player_identity.dart';
import '../utils/rating_calculator.dart';

class RankingScreen extends StatefulWidget {
  final String groupId;
  final String tournamentId;

  const RankingScreen({
    super.key,
    required this.groupId,
    required this.tournamentId,
  });

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  List<Map<String, dynamic>> leaderboard = [];
  List<Map<String, dynamic>> gkLeaderboard = [];
  bool _showGkRanking = false;
  bool isLoading = true;
  bool _isSharingScreenshot = false;

  String _sortColumn = 'ga';
  bool _sortDescending = true;

  final ScreenshotController _screenshotController = ScreenshotController();

  // Opções do dropdown de ordenação do pódio
  static const List<Map<String, String>> _sortOptions = [
    {'value': 'ga', 'label': 'G+A'},
    {'value': 'nota', 'label': 'Nota'},
    {'value': 'goals', 'label': 'Gols'},
    {'value': 'assists', 'label': 'Assistências'},
    {'value': 'wins', 'label': 'Vitórias'},
    {'value': 'games', 'label': 'Jogos'},
  ];

  String _gkSortColumn = 'nota';
  bool _gkSortDescending = true;

  static const List<Map<String, String>> _gkSortOptions = [
    {'value': 'nota', 'label': 'Nota'},
    {'value': 'games', 'label': 'Jogos'},
    {'value': 'clean_sheets', 'label': 'Clean Sheets'},
    {'value': 'conceded', 'label': 'Gols Sofridos'},
    {'value': 'goals', 'label': 'Gols'},
    {'value': 'assists', 'label': 'Assistências'},
  ];

  @override
  void initState() {
    super.initState();
    _calculateRankings();
  }

  // ─────────────────────────────────────────────────────────────
  // LÓGICA DE NEGÓCIO
  // ─────────────────────────────────────────────────────────────

  Future<void> _calculateRankings() async {
    final prefs = await SharedPreferences.getInstance();
    final String historyKey = 'match_history_${widget.tournamentId}';

    if (!prefs.containsKey(historyKey)) {
      setState(() => isLoading = false);
      return;
    }

    // Carrega ícones do banco de jogadores salvos e cria mapa de normalização (Nome -> ID Real)
    final Map<String, String?> iconMap = {};
    final Map<String, String> nameToIdMap = {};
    final Map<String, String> idToNameMap = {};

    final String? dbData = prefs.getString('players_${widget.groupId}');
    if (dbData != null) {
      final List<dynamic> dbPlayers = jsonDecode(dbData);
      for (final p in dbPlayers) {
        final String pid = playerIdFromObject(p as Map<String, dynamic>);
        final String name = (p['name'] ?? '').toString();
        if (pid.isNotEmpty) {
          iconMap[pid] = p['icon'] as String?;
          if (name.isNotEmpty) {
            nameToIdMap[name] = pid;
            idToNameMap[pid] = name;
          }
        }
      }
    }

    final List<dynamic> history = jsonDecode(prefs.getString(historyKey)!);
    final Map<String, Map<String, dynamic>> stats = {};
    final Map<String, Map<String, dynamic>> gkStats = {};

    for (final match in history) {
      final int scoreRed = match['scoreRed'] ?? 0;
      final int scoreWhite = match['scoreWhite'] ?? 0;
      final int redStatus = scoreRed > scoreWhite
          ? 1
          : (scoreRed == scoreWhite ? 0 : -1);
      final int whiteStatus = scoreWhite > scoreRed
          ? 1
          : (scoreRed == scoreWhite ? 0 : -1);

      final Map<String, String> eventPlayerNames = {};
      final Map<String, Map<String, int>> matchPlayerEvents = {};
      if (match['events'] != null) {
        for (final ev in match['events']) {
          String pid = eventPlayerId(ev, 'player');
          String astId = eventPlayerId(ev, 'assist');
          final String type = ev['type'];

          if (pid.isNotEmpty && ev['player'] != null) {
            eventPlayerNames[pid] = ev['player'].toString();
          }
          if (astId.isNotEmpty && ev['assist'] != null) {
            eventPlayerNames[astId] = ev['assist'].toString();
          }

          // Normalização de eventos (se o ID for o nome, tenta achar o ID real)
          if (nameToIdMap.containsKey(pid)) pid = nameToIdMap[pid]!;
          if (nameToIdMap.containsKey(astId)) astId = nameToIdMap[astId]!;

          if (pid.isNotEmpty) {
            matchPlayerEvents.putIfAbsent(
              pid,
              () => {'g': 0, 'a': 0, 'og': 0, 'yc': 0, 'rc': 0},
            );
            if (type == 'goal')
              matchPlayerEvents[pid]!['g'] = matchPlayerEvents[pid]!['g']! + 1;
            if (type == 'own_goal')
              matchPlayerEvents[pid]!['og'] =
                  matchPlayerEvents[pid]!['og']! + 1;
            if (type == 'yellow_card')
              matchPlayerEvents[pid]!['yc'] =
                  matchPlayerEvents[pid]!['yc']! + 1;
            if (type == 'red_card')
              matchPlayerEvents[pid]!['rc'] =
                  matchPlayerEvents[pid]!['rc']! + 1;
          }
          if (astId.isNotEmpty) {
            matchPlayerEvents.putIfAbsent(
              astId,
              () => {'g': 0, 'a': 0, 'og': 0, 'yc': 0, 'rc': 0},
            );
            if (type == 'goal')
              matchPlayerEvents[astId]!['a'] =
                  matchPlayerEvents[astId]!['a']! + 1;
          }
        }
      }

      final Set<String> processed = {};

      void processPlayer(
        dynamic playerObj,
        int status,
        int scored,
        int conceded, {
        bool isGk = false,
      }) {
        if (playerObj == null) return;
        String playerId = playerIdFromObject(playerObj);
        final String playerName = (playerObj['name'] ?? '').toString();

        // Normalização: se o ID no histórico for igual ao nome, tenta ver se esse jogador agora tem um ID real
        if (playerId == playerName && nameToIdMap.containsKey(playerName)) {
          playerId = nameToIdMap[playerName]!;
        }

        if (playerId.isEmpty || processed.contains(playerId)) return;
        processed.add(playerId);

        stats.putIfAbsent(
          playerId,
          () => {
            'id': playerId,
            'name': playerName,
            'goals': 0,
            'assists': 0,
            'games': 0,
            'wins': 0,
            'draws': 0,
            'losses': 0,
            'ratings': <double>[],
          },
        );
        if (playerName.isNotEmpty) stats[playerId]!['name'] = playerName;

        final int g = matchPlayerEvents[playerId]?['g'] ?? 0;
        final int a = matchPlayerEvents[playerId]?['a'] ?? 0;
        final int og = matchPlayerEvents[playerId]?['og'] ?? 0;
        final int yc = matchPlayerEvents[playerId]?['yc'] ?? 0;
        final int rc = matchPlayerEvents[playerId]?['rc'] ?? 0;

        stats[playerId]!['goals'] = (stats[playerId]!['goals'] as int) + g;
        stats[playerId]!['assists'] = (stats[playerId]!['assists'] as int) + a;

        if (!isGk) {
          stats[playerId]!['games'] = (stats[playerId]!['games'] as int) + 1;
          if (status == 1)
            stats[playerId]!['wins'] = (stats[playerId]!['wins'] as int) + 1;
          else if (status == -1)
            stats[playerId]!['losses'] =
                (stats[playerId]!['losses'] as int) + 1;
          else
            stats[playerId]!['draws'] = (stats[playerId]!['draws'] as int) + 1;

          final double matchRating = calculateMatchRating(
            status: status,
            goals: g,
            assists: a,
            ownGoals: og,
            teamGoals: scored,
            conceded: conceded,
            yellow: yc,
            red: rc,
            teamWinStreak: 0,
          );
          (stats[playerId]!['ratings'] as List<double>).add(matchRating);
        } else {
          gkStats.putIfAbsent(
            playerId,
            () => {
              'id': playerId,
              'name': playerName,
              'gk_games': 0,
              'gk_wins': 0,
              'gk_draws': 0,
              'gk_losses': 0,
              'gk_conceded': 0,
              'gk_clean_sheets': 0,
              'gk_goals': 0,
              'gk_assists': 0,
              'gk_ratings': <double>[],
            },
          );
          if (playerName.isNotEmpty) gkStats[playerId]!['name'] = playerName;

          gkStats[playerId]!['gk_games'] =
              (gkStats[playerId]!['gk_games'] as int) + 1;
          gkStats[playerId]!['gk_conceded'] =
              (gkStats[playerId]!['gk_conceded'] as int) + conceded;
          if (conceded == 0) {
            gkStats[playerId]!['gk_clean_sheets'] =
                (gkStats[playerId]!['gk_clean_sheets'] as int) + 1;
          }
          gkStats[playerId]!['gk_goals'] =
              (gkStats[playerId]!['gk_goals'] as int) + g;
          gkStats[playerId]!['gk_assists'] =
              (gkStats[playerId]!['gk_assists'] as int) + a;
          if (status == 1)
            gkStats[playerId]!['gk_wins'] =
                (gkStats[playerId]!['gk_wins'] as int) + 1;
          else if (status == -1)
            gkStats[playerId]!['gk_losses'] =
                (gkStats[playerId]!['gk_losses'] as int) + 1;
          else
            gkStats[playerId]!['gk_draws'] =
                (gkStats[playerId]!['gk_draws'] as int) + 1;

          final double gkRating = calculateGkMatchRating(
            status: status,
            goals: g,
            assists: a,
            conceded: conceded,
            yellow: yc,
            red: rc,
            teamWinStreak: 0,
          );
          (gkStats[playerId]!['gk_ratings'] as List<double>).add(gkRating);
        }
      }

      if (match['players']['red'] != null) {
        for (final p in match['players']['red'])
          processPlayer(p, redStatus, scoreRed, scoreWhite);
      }
      if (match['players']['white'] != null) {
        for (final p in match['players']['white'])
          processPlayer(p, whiteStatus, scoreWhite, scoreRed);
      }
      if (match['players']['gk_red'] != null) {
        processPlayer(
          match['players']['gk_red'],
          redStatus,
          scoreRed,
          scoreWhite,
          isGk: true,
        );
      }
      if (match['players']['gk_white'] != null) {
        processPlayer(
          match['players']['gk_white'],
          whiteStatus,
          scoreWhite,
          scoreRed,
          isGk: true,
        );
      }

      // Process players who have events but weren't in the official lineup
      for (final playerId in matchPlayerEvents.keys) {
        if (!processed.contains(playerId)) {
          final events = matchPlayerEvents[playerId]!;
          final String playerName =
              idToNameMap[playerId] ??
              eventPlayerNames[playerId] ??
              'Desconhecido';

          stats.putIfAbsent(
            playerId,
            () => {
              'id': playerId,
              'name': playerName,
              'goals': 0,
              'assists': 0,
              'games': 0,
              'wins': 0,
              'draws': 0,
              'losses': 0,
              'ratings': <double>[],
            },
          );
          if (playerName != 'Desconhecido')
            stats[playerId]!['name'] = playerName;

          stats[playerId]!['games'] = (stats[playerId]!['games'] as int) + 1;

          final int g = events['g'] ?? 0;
          final int a = events['a'] ?? 0;
          final int og = events['og'] ?? 0;
          final int yc = events['yc'] ?? 0;
          final int rc = events['rc'] ?? 0;

          stats[playerId]!['goals'] = (stats[playerId]!['goals'] as int) + g;
          stats[playerId]!['assists'] =
              (stats[playerId]!['assists'] as int) + a;

          // Do not calculate or add a matchRating here to preserve their current Nota
        }
      }
    }

    final List<Map<String, dynamic>> sortedList = [];
    stats.forEach((id, data) {
      final int games = data['games'] as int;
      final int g = data['goals'] as int;
      final int a = data['assists'] as int;

      if (games > 0) {
        sortedList.add({
          'id': id,
          'name': data['name'],
          'icon': iconMap[id], // ← ícone do banco de jogadores
          'goals': g,
          'assists': a,
          'ga': g + a,
          'games': games,
          'wins': data['wins'],
          'draws': data['draws'],
          'losses': data['losses'],
          // Ranking da pelada usa média simples (useBayesian: false)
          'nota': calculateFinalRating(
            ratings: data['ratings'] as List<double>,
            useBayesian: false,
          ),
        });
      }
    });

    _applySorting(sortedList);

    final List<Map<String, dynamic>> sortedGkList = [];
    gkStats.forEach((id, data) {
      final int games = data['gk_games'] as int;
      if (games > 0) {
        sortedGkList.add({
          'id': id,
          'name': data['name'],
          'icon': iconMap[id],
          'games': games,
          'conceded': data['gk_conceded'],
          'clean_sheets': data['gk_clean_sheets'],
          'goals': data['gk_goals'],
          'assists': data['gk_assists'],
          'wins': data['gk_wins'],
          'draws': data['gk_draws'],
          'losses': data['gk_losses'],
          'nota': calculateFinalRating(
            ratings: data['gk_ratings'] as List<double>,
            useBayesian: false,
          ),
        });
      }
    });
    _applyGkSorting(sortedGkList);

    setState(() {
      leaderboard = sortedList;
      gkLeaderboard = sortedGkList;
      isLoading = false;
    });
  }

  void _applyGkSorting(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      int cmp = 0;
      switch (_gkSortColumn) {
        case 'nota':
          cmp = (a['nota'] as num).compareTo(b['nota'] as num);
          break;
        case 'games':
          cmp = (a['games'] as num).compareTo(b['games'] as num);
          break;
        case 'clean_sheets':
          cmp = (a['clean_sheets'] as num).compareTo(b['clean_sheets'] as num);
          break;
        case 'conceded':
          // Menos gols sofridos é melhor
          cmp = (b['conceded'] as num).compareTo(a['conceded'] as num);
          break;
        case 'goals':
          cmp = (a['goals'] as num).compareTo(b['goals'] as num);
          break;
        case 'assists':
          cmp = (a['assists'] as num).compareTo(b['assists'] as num);
          break;
        default:
          cmp = (a[_gkSortColumn] as num).compareTo(b[_gkSortColumn] as num);
      }

      if (cmp == 0 && _gkSortColumn != 'nota')
        cmp = (a['nota'] as num).compareTo(b['nota'] as num);
      if (cmp == 0 && _gkSortColumn != 'clean_sheets')
        cmp = (a['clean_sheets'] as num).compareTo(b['clean_sheets'] as num);

      return _gkSortDescending ? -cmp : cmp;
    });
  }

  void _onGkSortChanged(String? newValue) {
    if (newValue == null) return;
    setState(() {
      if (_gkSortColumn == newValue) {
        _gkSortDescending = !_gkSortDescending;
      } else {
        _gkSortColumn = newValue;
        _gkSortDescending = true;
      }
      _applyGkSorting(gkLeaderboard);
    });
  }

  void _applySorting(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      int cmp = 0;

      switch (_sortColumn) {
        case 'ga':
          cmp = (a['ga'] as num).compareTo(b['ga'] as num);
          break;
        case 'goals':
          cmp = (a['goals'] as num).compareTo(b['goals'] as num);
          break;
        case 'nota':
          cmp = (a['nota'] as num).compareTo(b['nota'] as num);
          break;
        case 'assists':
          cmp = (a['assists'] as num).compareTo(b['assists'] as num);
          break;
        case 'wins':
          cmp = (a['wins'] as num).compareTo(b['wins'] as num);
          break;
        case 'games':
          cmp = (a['games'] as num).compareTo(b['games'] as num);
          break;
        default:
          cmp = (a[_sortColumn] as num).compareTo(b[_sortColumn] as num);
      }

      if (cmp == 0 && _sortColumn != 'ga')
        cmp = (a['ga'] as num).compareTo(b['ga'] as num);
      if (cmp == 0 && _sortColumn != 'goals')
        cmp = (a['goals'] as num).compareTo(b['goals'] as num);
      if (cmp == 0 && _sortColumn != 'nota')
        cmp = (a['nota'] as num).compareTo(b['nota'] as num);

      return _sortDescending ? -cmp : cmp;
    });
  }

  void _onSortChanged(String? newColumn) {
    if (newColumn == null) return;
    setState(() {
      _sortColumn = newColumn;
      _sortDescending = true;
      final copy = List<Map<String, dynamic>>.from(leaderboard);
      _applySorting(copy);
      leaderboard = copy;
    });
  }

  void _onColumnSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortDescending = !_sortDescending;
      } else {
        _sortColumn = column;
        _sortDescending = true;
      }
      final copy = List<Map<String, dynamic>>.from(leaderboard);
      _applySorting(copy);
      leaderboard = copy;
    });
  }

  // ─────────────────────────────────────────────────────────────
  // SCREENSHOT / SHARE
  // ─────────────────────────────────────────────────────────────

  Future<void> _shareRanking() async {
    setState(() => _isSharingScreenshot = true);
    await Future.delayed(const Duration(milliseconds: 80));

    try {
      final image = await _screenshotController.capture(pixelRatio: 2.5);
      if (image == null) return;

      final dir = await getTemporaryDirectory();
      final file = await File(
        '${dir.path}/ranking_pelada.png',
      ).writeAsBytes(image);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Ranking da Pelada 🏆⚽');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao compartilhar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharingScreenshot = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // MODAL "VER TODOS" — tabela completa com sort nas colunas
  // ─────────────────────────────────────────────────────────────

  void _showFullRankingModal() {
    // Cópia independente com sua própria ordenação
    String modalSort = _sortColumn;
    bool modalDesc = _sortDescending;
    List<Map<String, dynamic>> modalList = List<Map<String, dynamic>>.from(
      leaderboard,
    );

    void applyModalSort(StateSetter setModal) {
      modalList.sort((a, b) {
        int cmp = 0;
        switch (modalSort) {
          case 'ga':
            cmp = (a['ga'] as num).compareTo(b['ga'] as num);
            break;
          case 'goals':
            cmp = (a['goals'] as num).compareTo(b['goals'] as num);
            break;
          case 'nota':
            cmp = (a['nota'] as num).compareTo(b['nota'] as num);
            break;
          case 'assists':
            cmp = (a['assists'] as num).compareTo(b['assists'] as num);
            break;
          case 'wins':
            cmp = (a['wins'] as num).compareTo(b['wins'] as num);
            break;
          case 'games':
            cmp = (a['games'] as num).compareTo(b['games'] as num);
            break;
          default:
            cmp = (a[modalSort] as num).compareTo(b[modalSort] as num);
        }
        if (cmp == 0 && modalSort != 'ga')
          cmp = (a['ga'] as num).compareTo(b['ga'] as num);
        if (cmp == 0 && modalSort != 'goals')
          cmp = (a['goals'] as num).compareTo(b['goals'] as num);
        if (cmp == 0 && modalSort != 'nota')
          cmp = (a['nota'] as num).compareTo(b['nota'] as num);
        return modalDesc ? -cmp : cmp;
      });
      setModal(() {});
    }

    Widget colHeader(
      String label,
      String col,
      double width,
      StateSetter setModal,
    ) {
      final bool active = modalSort == col;
      return GestureDetector(
        onTap: () {
          if (modalSort == col) {
            modalDesc = !modalDesc;
          } else {
            modalSort = col;
            modalDesc = true;
          }
          applyModalSort(setModal);
        },
        child: SizedBox(
          width: width,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white54,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
              Icon(
                active
                    ? (modalDesc
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded)
                    : Icons.unfold_more_rounded,
                size: 10,
                color: active ? Colors.white70 : Colors.white24,
              ),
            ],
          ),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.deepBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.88,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scrollCtrl) {
                return Column(
                  children: [
                    // Handle + título
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.headerBlue,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Ranking Completo',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Cabeçalho das colunas
                    Container(
                      color: AppColors.headerBlue.withValues(alpha: 0.7),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 28), // posição
                          const SizedBox(width: 32), // avatar
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Jogador',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          colHeader('Nota', 'nota', 40, setModal),
                          const SizedBox(width: 8),
                          colHeader('G+A', 'ga', 40, setModal),
                          const SizedBox(width: 8),
                          colHeader('G', 'goals', 22, setModal),
                          const SizedBox(width: 2),
                          colHeader('A', 'assists', 22, setModal),
                          const SizedBox(width: 6),
                          colHeader('V', 'wins', 22, setModal),
                          const SizedBox(width: 4),
                          const Text(
                            '/',
                            style: TextStyle(
                              color: Colors.white12,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 4),
                          colHeader('E', 'draws', 22, setModal),
                          const SizedBox(width: 4),
                          const Text(
                            '/',
                            style: TextStyle(
                              color: Colors.white12,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 4),
                          colHeader('D', 'losses', 22, setModal),
                          const SizedBox(width: 8),
                          colHeader('Jgs', 'games', 28, setModal),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    // Lista
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: modalList.length,
                        itemBuilder: (_, i) {
                          final player = modalList[i];
                          final double nota = player['nota'] as double;
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlayerDetailScreen(
                                  groupId: widget.groupId,
                                  tournamentId: widget.tournamentId,
                                  playerId: player['id'].toString(),
                                  initialPlayerName: player['name'],
                                ),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: i.isOdd
                                    ? Colors.white.withValues(alpha: 0.03)
                                    : Colors.transparent,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        color: Colors.white30,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  _playerAvatar(player, radius: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      player['name'],
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Nota
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      nota.toStringAsFixed(1),
                                      style: TextStyle(
                                        color: getRatingColor(nota),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // G+A
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      '${player['ga']}',
                                      style: const TextStyle(
                                        color: AppColors.highlightGreen,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // G
                                  SizedBox(
                                    width: 22,
                                    child: Text(
                                      '${player['goals']}',
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  // A
                                  SizedBox(
                                    width: 22,
                                    child: Text(
                                      '${player['assists']}',
                                      style: const TextStyle(
                                        color: Colors.lightBlueAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // V/E/D
                                  SizedBox(
                                    width: 22,
                                    child: Text(
                                      '${player['wins']}',
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 11,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Text(
                                    '/',
                                    style: const TextStyle(
                                      color: Colors.white24,
                                      fontSize: 11,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 22,
                                    child: Text(
                                      '${player['draws']}',
                                      style: const TextStyle(
                                        color: Colors.orangeAccent,
                                        fontSize: 11,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Text(
                                    '/',
                                    style: const TextStyle(
                                      color: Colors.white24,
                                      fontSize: 11,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 22,
                                    child: Text(
                                      '${player['losses']}',
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 11,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Jogos
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      '${player['games']}',
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showFullGkRankingModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (ctx, setModalState) {
                void sort(String column) {
                  setModalState(() {
                    if (_gkSortColumn == column) {
                      _gkSortDescending = !_gkSortDescending;
                    } else {
                      _gkSortColumn = column;
                      _gkSortDescending = true;
                    }
                    _applyGkSorting(gkLeaderboard);
                  });
                  setState(() {});
                }

                return Container(
                  decoration: const BoxDecoration(
                    color: AppColors.deepBlue,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Ranking Completo (Goleiros)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Table Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.headerBlue.withValues(alpha: 0.5),
                          border: const Border(
                            bottom: BorderSide(color: Colors.white10),
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 30,
                              child: Text(
                                'Pos',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 32), // Espaço avatar
                            const Expanded(
                              child: Text(
                                'Jogador',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            _gkSortHeader(
                              'Nota',
                              'nota',
                              Colors.greenAccent,
                              sort,
                            ),
                            const SizedBox(width: 15),
                            _gkSortHeader(
                              'CS',
                              'clean_sheets',
                              Colors.blueAccent,
                              sort,
                            ),
                            const SizedBox(width: 15),
                            _gkSortHeader(
                              'GS',
                              'conceded',
                              Colors.redAccent,
                              sort,
                            ),
                            const SizedBox(width: 15),
                            _gkSortHeader('Jgs', 'games', Colors.white54, sort),
                          ],
                        ),
                      ),
                      // List
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: gkLeaderboard.length,
                          separatorBuilder: (c, i) =>
                              const Divider(color: Colors.white10, height: 1),
                          itemBuilder: (c, i) {
                            final player = gkLeaderboard[i];
                            return ListTile(
                              dense: true,
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        color: i < 3
                                            ? AppColors.accentBlue
                                            : Colors.white38,
                                        fontWeight: i < 3
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  _playerAvatar(player, radius: 14),
                                ],
                              ),
                              title: Text(
                                player['name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Nota
                                  SizedBox(
                                    width: 35,
                                    child: Text(
                                      (player['nota'] as double)
                                          .toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  // CS
                                  SizedBox(
                                    width: 25,
                                    child: Text(
                                      '${player['clean_sheets']}',
                                      style: const TextStyle(
                                        color: Colors.blueAccent,
                                        fontSize: 11,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  // GS
                                  SizedBox(
                                    width: 25,
                                    child: Text(
                                      '${player['conceded']}',
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 11,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  // Jogos
                                  SizedBox(
                                    width: 25,
                                    child: Text(
                                      '${player['games']}',
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
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
          },
        );
      },
    );
  }

  Widget _gkSortHeader(
    String label,
    String column,
    Color color,
    Function(String) onSort,
  ) {
    final bool active = _gkSortColumn == column;
    return GestureDetector(
      onTap: () => onSort(column),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            active
                ? (_gkSortDescending
                      ? Icons.arrow_drop_down
                      : Icons.arrow_drop_up)
                : Icons.unfold_more,
            size: 14,
            color: active ? Colors.white : color.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS AUXILIARES
  // ─────────────────────────────────────────────────────────────

  Widget _sortHeader(String label, String column, Color color) {
    final bool active = _sortColumn == column;
    return GestureDetector(
      onTap: () => _onColumnSort(column),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            active
                ? (_sortDescending
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded)
                : Icons.unfold_more_rounded,
            size: 11,
            color: active ? Colors.white54 : color.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }

  Widget _playerAvatar(Map<String, dynamic> p, {double radius = 24}) {
    final String? icon = p['icon'] as String?;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.headerBlue,
      backgroundImage: icon != null && icon.isNotEmpty
          ? AssetImage(icon)
          : null,
      child: (icon == null || icon.isEmpty)
          ? Text(
              (p['name'] as String).isNotEmpty
                  ? (p['name'] as String)[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.7,
              ),
            )
          : null,
    );
  }

  // ─── Pódio (Top 3) ───────────────────────────────────────────

  Widget _buildPodium(List<Map<String, dynamic>> top) {
    final p1 = top.isNotEmpty ? top[0] : null;
    final p2 = top.length > 1 ? top[1] : null;
    final p3 = top.length > 2 ? top[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _podiumSlot(p2, 2, 80, Colors.grey[300]!)),
        Expanded(child: _podiumSlot(p1, 1, 110, Colors.amber)),
        Expanded(child: _podiumSlot(p3, 3, 60, Colors.brown[300]!)),
      ],
    );
  }

  Widget _podiumSlot(
    Map<String, dynamic>? player,
    int position,
    double barHeight,
    Color accentColor,
  ) {
    if (player == null) return const SizedBox.shrink();

    final double nota = player['nota'] as double;
    final int wins = player['wins'] as int;
    final int draws = player['draws'] as int;
    final int losses = player['losses'] as int;
    final int games = player['games'] as int;
    final int goals = player['goals'] as int;
    final int assists = player['assists'] as int;
    final int ga = goals + assists;

    final String medal = position == 1 ? '🥇' : (position == 2 ? '🥈' : '🥉');

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerDetailScreen(
            groupId: widget.groupId,
            tournamentId: widget.tournamentId,
            playerId: player['id'].toString(),
            initialPlayerName: player['name'],
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _playerAvatar(player, radius: position == 1 ? 28 : 22),
          const SizedBox(height: 4),
          // Nome
          Text(
            player['name'],
            style: TextStyle(
              color: Colors.white,
              fontSize: position == 1 ? 13 : 11,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Nota
          Text(
            nota.toStringAsFixed(1),
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.bold,
              fontSize: position == 1 ? 16 : 14,
            ),
          ),
          const SizedBox(height: 4),
          // G+A com breakdown Gols/Assists
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Gols
              Text('⚽', style: TextStyle(fontSize: position == 1 ? 11 : 10)),
              Text(
                '$goals',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: position == 1 ? 12 : 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              // Assistências
              Icon(
                Icons.handshake,
                color: Colors.lightBlueAccent,
                size: position == 1 ? 12 : 10,
              ),
              Text(
                '$assists',
                style: TextStyle(
                  color: Colors.lightBlueAccent,
                  fontSize: position == 1 ? 12 : 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              // G+A total
              Text(
                'G+A $ga',
                style: TextStyle(
                  color: accentColor.withValues(alpha: 0.85),
                  fontSize: position == 1 ? 11 : 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          // W / D / L
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$wins',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '/',
                style: const TextStyle(color: Colors.white24, fontSize: 11),
              ),
              Text(
                '$draws',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '/',
                style: const TextStyle(color: Colors.white24, fontSize: 11),
              ),
              Text(
                '$losses',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            '$games jogos',
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
          const SizedBox(height: 6),
          // Degrau do pódio
          Container(
            height: barHeight,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(medal, style: const TextStyle(fontSize: 22)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGkPodium(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    final p1 = list.length > 0 ? list[0] : null;
    final p2 = list.length > 1 ? list[1] : null;
    final p3 = list.length > 2 ? list[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _gkPodiumSlot(p2, 2, 80, Colors.grey[300]!)),
        Expanded(child: _gkPodiumSlot(p1, 1, 110, Colors.amber)),
        Expanded(child: _gkPodiumSlot(p3, 3, 60, Colors.brown[300]!)),
      ],
    );
  }

  Widget _gkPodiumSlot(
    Map<String, dynamic>? player,
    int position,
    double barHeight,
    Color accentColor,
  ) {
    if (player == null) return const SizedBox.shrink();

    final double nota = player['nota'] as double;
    final int cleanSheets = player['clean_sheets'] as int;
    final int conceded = player['conceded'] as int;
    final int games = player['games'] as int;
    final int goals = player['goals'] as int;
    final int assists = player['assists'] as int;
    
    final int wins = player['wins'] as int;
    final int draws = player['draws'] as int;
    final int losses = player['losses'] as int;

    final String medal = position == 1 ? '🥇' : (position == 2 ? '🥈' : '🥉');

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerDetailScreen(
            groupId: widget.groupId,
            tournamentId: widget.tournamentId,
            playerId: player['id'].toString(),
            initialPlayerName: player['name'],
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _playerAvatar(player, radius: position == 1 ? 28 : 22),
          const SizedBox(height: 4),
          Text(
            player['name'],
            style: TextStyle(
              color: Colors.white,
              fontSize: position == 1 ? 13 : 11,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            nota.toStringAsFixed(1),
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.bold,
              fontSize: position == 1 ? 16 : 14,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('⚽', style: TextStyle(fontSize: position == 1 ? 11 : 10)),
              Text(
                '$goals',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: position == 1 ? 12 : 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.handshake,
                color: Colors.lightBlueAccent,
                size: position == 1 ? 12 : 10,
              ),
              Text(
                '$assists',
                style: TextStyle(
                  color: Colors.lightBlueAccent,
                  fontSize: position == 1 ? 12 : 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'CS $cleanSheets | GS $conceded',
                style: TextStyle(
                  color: accentColor.withValues(alpha: 0.85),
                  fontSize: position == 1 ? 11 : 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$wins',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '/',
                style: const TextStyle(color: Colors.white24, fontSize: 11),
              ),
              Text(
                '$draws',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '/',
                style: const TextStyle(color: Colors.white24, fontSize: 11),
              ),
              Text(
                '$losses',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            '$games jogos',
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
          const SizedBox(height: 6),
          Container(
            height: barHeight,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(medal, style: const TextStyle(fontSize: 22)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 4º ao 8º lugar ─────────────────────────

  Widget _buildTop4To8(List<Map<String, dynamic>> items, {bool isGk = false}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: List.generate(items.length, (i) {
        final player = items[i];
        final int pos = i + 4;
        final double nota = player['nota'] as double;
        final int goals = player['goals'] as int;
        final int assists = player['assists'] as int;
        final int ga = goals + assists;

        final int cleanSheets = isGk ? (player['clean_sheets'] ?? 0) : 0;
        final int conceded = isGk ? (player['conceded'] ?? 0) : 0;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerDetailScreen(
                groupId: widget.groupId,
                tournamentId: widget.tournamentId,
                playerId: player['id'].toString(),
                initialPlayerName: player['name'],
              ),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.headerBlue.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '$pos',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _playerAvatar(player, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    player['name'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // Nota
                Text(
                  nota.toStringAsFixed(1),
                  style: TextStyle(
                    color: getRatingColor(nota),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 10),
                // Stats
                if (isGk)
                  Row(
                    children: [
                      Text('⚽', style: TextStyle(fontSize: 10)),
                      Text(
                        '$goals',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.handshake,
                        color: Colors.lightBlueAccent,
                        size: 10,
                      ),
                      Text(
                        '$assists',
                        style: TextStyle(
                          color: Colors.lightBlueAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$cleanSheets/$conceded',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      const Text('⚽', style: TextStyle(fontSize: 11)),
                      Text(
                        '$goals',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.handshake,
                        color: Colors.lightBlueAccent,
                        size: 12,
                      ),
                      Text(
                        '$assists',
                        style: const TextStyle(
                          color: Colors.lightBlueAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($ga)',
                        style: const TextStyle(
                          color: AppColors.highlightGreen,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(width: 8),
                // V/E/D
                Text(
                  '${player['wins']}',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                  ),
                ),
                Text(
                  '/',
                  style: const TextStyle(color: Colors.white24, fontSize: 11),
                ),
                Text(
                  '${player['draws']}',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 11,
                  ),
                ),
                Text(
                  '/',
                  style: const TextStyle(color: Colors.white24, fontSize: 11),
                ),
                Text(
                  '${player['losses']}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
        title: const Text(
          'Ranking da Pelada',
          style: TextStyle(color: AppColors.textWhite),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (!isLoading && leaderboard.isNotEmpty)
            _isSharingScreenshot
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(
                      Icons.share_rounded,
                      color: AppColors.textWhite,
                    ),
                    tooltip: 'Compartilhar ranking',
                    onPressed: _shareRanking,
                  ),
        ],
      ),
      body: Column(
        children: [
          // ── Linha / Goleiros toggle ────────────────────────────
          Container(
            color: AppColors.headerBlue,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _showGkRanking = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: !_showGkRanking
                                ? AppColors.accentBlue
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Linha',
                        style: TextStyle(
                          color: !_showGkRanking
                              ? AppColors.textWhite
                              : Colors.white54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _showGkRanking = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _showGkRanking
                                ? AppColors.accentBlue
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Goleiros',
                        style: TextStyle(
                          color: _showGkRanking
                              ? AppColors.textWhite
                              : Colors.white54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _showGkRanking
                ? _buildGkRankingView()
                : _buildFieldRankingView(),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldRankingView() {
    if (leaderboard.isEmpty) {
      return const Center(
        child: Text(
          'Sem jogadores registrados.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return Screenshot(
      controller: _screenshotController,
      child: Container(
        color: AppColors.deepBlue,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: AppColors.headerBlue.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Text(
                      'Ordenar por',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sortColumn,
                          dropdownColor: AppColors.headerBlue,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white54,
                          ),
                          isDense: true,
                          items: _sortOptions
                              .map(
                                (opt) => DropdownMenuItem<String>(
                                  value: opt['value'],
                                  child: Text(opt['label']!),
                                ),
                              )
                              .toList(),
                          onChanged: _onSortChanged,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 0),
                child: _buildPodium(leaderboard.take(3).toList()),
              ),
              const SizedBox(height: 20),
              const Divider(
                color: Colors.white12,
                height: 1,
                indent: 12,
                endIndent: 12,
              ),
              const SizedBox(height: 8),
              if (leaderboard.length > 3)
                _buildTop4To8(
                  leaderboard.sublist(3, leaderboard.length.clamp(3, 8)),
                ),
              if (leaderboard.length > 8) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(
                      Icons.format_list_numbered_rounded,
                      size: 18,
                    ),
                    label: Text(
                      'Ver todos (${leaderboard.length} jogadores)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: _showFullRankingModal,
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGkRankingView() {
    if (gkLeaderboard.isEmpty) {
      return const Center(
        child: Text(
          'Sem goleiros registrados.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    final top4to8 = gkLeaderboard.skip(3).take(5).toList();

    return Screenshot(
      controller: _screenshotController,
      child: Container(
        color: AppColors.deepBlue,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: AppColors.headerBlue.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Text(
                      'Ordenar por',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _gkSortColumn,
                          dropdownColor: AppColors.headerBlue,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white54,
                          ),
                          isDense: true,
                          items: _gkSortOptions
                              .map(
                                (opt) => DropdownMenuItem<String>(
                                  value: opt['value'],
                                  child: Text(opt['label']!),
                                ),
                              )
                              .toList(),
                          onChanged: _onGkSortChanged,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 0),
                child: _buildGkPodium(gkLeaderboard.take(3).toList()),
              ),
              const SizedBox(height: 20),
              const Divider(
                color: Colors.white12,
                height: 1,
                indent: 12,
                endIndent: 12,
              ),
              const SizedBox(height: 8),
              if (gkLeaderboard.length > 3) _buildTop4To8(top4to8, isGk: true),
              if (gkLeaderboard.length > 8) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(
                      Icons.format_list_numbered_rounded,
                      size: 18,
                    ),
                    label: Text(
                      'Ver todos (${gkLeaderboard.length} goleiros)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: _showFullGkRankingModal,
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
