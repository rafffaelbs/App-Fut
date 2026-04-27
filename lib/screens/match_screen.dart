import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../utils/player_identity.dart';

// --- WIDGET IMPORTS ---
import '../widgets/match/match_scoreboard.dart';
import '../widgets/match/player_field_slot.dart';

class MatchScreen extends StatefulWidget {
  final String tournamentName;
  final String tournamentId;
  final int totalPlayers;
  final String groupId;

  const MatchScreen({
    super.key,
    required this.tournamentName,
    required this.tournamentId,
    required this.totalPlayers,
    required this.groupId,
  });

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- DATA ---
  List<Map<String, dynamic>> allSavedPlayers = [];
  List<Map<String, dynamic>> presentPlayers = [];

  // Teams (X players max, NO fixed goalkeepers)
  List<Map<String, dynamic>> teamRed = [];
  List<Map<String, dynamic>> teamWhite = [];

  // Match State
  int scoreRed = 0;
  int scoreWhite = 0;
  int redWinStreak = 0; 
  int whiteWinStreak = 0;
  bool isMatchRunning = false;
  bool isOvertime = false;
  Timer? _matchTimer;

  // Timer Variables
  int _secondsPlayedBeforePause = 0;
  DateTime? _lastStartTime;

  int get totalSecondsElapsed {
    if (!isMatchRunning || _lastStartTime == null) {
      return _secondsPlayedBeforePause;
    }
    return _secondsPlayedBeforePause +
        DateTime.now().difference(_lastStartTime!).inSeconds;
  }

  // Match Events Log
  List<Map<String, dynamic>> matchEvents = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadMatchState();
  }

  @override
  void dispose() {
    _matchTimer?.cancel();
    _tabController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  bool get _isReadyToStart {
    return teamRed.length == widget.totalPlayers &&
        teamWhite.length == widget.totalPlayers;
  }

  String _formatTime(int totalSeconds) {
    int min = totalSeconds ~/ 60;
    int sec = totalSeconds % 60;
    return "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
  }

  double _calculateTeamRating(List<Map<String, dynamic>> team) {
    if (team.isEmpty) return 0.0;
    double totalStars = 0.0;
    for (var player in team) {
      double rating = player['rating'] != null
          ? (player['rating'] as num).toDouble()
          : 0.0;
      totalStars += rating;
    }
    return totalStars / team.length;
  }

  // --- PERSISTENCE ---

  Future<void> _saveMatchState() async {
    final prefs = await SharedPreferences.getInstance();
    final String id = widget.tournamentId;

    await prefs.setString('present_players_$id', jsonEncode(presentPlayers));
    await prefs.setString('team_red_$id', jsonEncode(teamRed));
    await prefs.setString('team_white_$id', jsonEncode(teamWhite));
    await prefs.setInt('score_red_$id', scoreRed);
    await prefs.setInt('score_white_$id', scoreWhite);
    await prefs.setString('match_events_$id', jsonEncode(matchEvents));
    await prefs.setBool('is_overtime_$id', isOvertime);
    await prefs.setInt('seconds_played_$id', _secondsPlayedBeforePause);
    await prefs.setBool('is_running_$id', isMatchRunning);

    if (_lastStartTime != null) {
      await prefs.setString(
        'start_timestamp_$id',
        _lastStartTime!.toIso8601String(),
      );
    } else {
      await prefs.remove('start_timestamp_$id');
    }
    await prefs.setInt('red_streak_$id', redWinStreak);
    await prefs.setInt('white_streak_$id', whiteWinStreak);
  }

  Future<void> _loadMatchState() async {
    final prefs = await SharedPreferences.getInstance();
    final String id = widget.tournamentId;

    final String? dbData = prefs.getString('players_${widget.groupId}');
    if (dbData != null) {
      allSavedPlayers = ensurePlayerIds(
        List<Map<String, dynamic>>.from(jsonDecode(dbData)),
      );
    }

    setState(() {
      if (prefs.containsKey('present_players_$id')) {
        presentPlayers = ensurePlayerIds(
          List<Map<String, dynamic>>.from(
            jsonDecode(prefs.getString('present_players_$id')!),
          ),
        );
      }
      if (prefs.containsKey('team_red_$id')) {
        teamRed = ensurePlayerIds(
          List<Map<String, dynamic>>.from(
            jsonDecode(prefs.getString('team_red_$id')!),
          ),
        );
      }
      if (prefs.containsKey('team_white_$id')) {
        teamWhite = ensurePlayerIds(
          List<Map<String, dynamic>>.from(
            jsonDecode(prefs.getString('team_white_$id')!),
          ),
        );
      }
      if (prefs.containsKey('match_events_$id')) {
        matchEvents = List<Map<String, dynamic>>.from(
          jsonDecode(prefs.getString('match_events_$id')!),
        );
      }

      scoreRed = prefs.getInt('score_red_$id') ?? 0;
      scoreWhite = prefs.getInt('score_white_$id') ?? 0;
      redWinStreak = prefs.getInt('red_streak_$id') ?? 0;
      whiteWinStreak = prefs.getInt('white_streak_$id') ?? 0;
      isOvertime = prefs.getBool('is_overtime_$id') ?? false;
      _secondsPlayedBeforePause = prefs.getInt('seconds_played_$id') ?? 0;
      isMatchRunning = prefs.getBool('is_running_$id') ?? false;

      String? stamp = prefs.getString('start_timestamp_$id');
      _lastStartTime = stamp != null ? DateTime.parse(stamp) : null;

      if (isMatchRunning && _lastStartTime != null) {
        _matchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            if (totalSecondsElapsed >= 480 && !isOvertime) {
              isOvertime = true;
              try {
                _audioPlayer.play(AssetSource('audio/end.mp3'));
              } catch (e) {
                debugPrint("Audio error: \$e");
              }
            }
          });
        });
      }
    });
  }

  // --- MATCH LOGIC ---
  String _pid(Map<String, dynamic> player) => playerIdFromObject(player);

  void _startMatch() async {
    if (isMatchRunning) return;

    setState(() {
      isMatchRunning = true;
      _lastStartTime = DateTime.now();
    });

    try {
      if (totalSecondsElapsed == 0) {
        await _audioPlayer.play(AssetSource('audio/end.mp3'));
      } else {
        await _audioPlayer.play(AssetSource('audio/end.mp3'));
      }
    } catch (e) {
      debugPrint("Audio error: $e");
    }

    _saveMatchState();

    _matchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (totalSecondsElapsed >= 480 && !isOvertime) {
          isOvertime = true;
          try {
            _audioPlayer.play(AssetSource('audio/end.mp3'));
          } catch (e) {
            debugPrint("Audio error: \$e");
          }
        }
      });
    });
  }

  void _pauseMatch() {
    _matchTimer?.cancel();
    setState(() {
      isMatchRunning = false;
      if (_lastStartTime != null) {
        _secondsPlayedBeforePause += DateTime.now()
            .difference(_lastStartTime!)
            .inSeconds;
        _lastStartTime = null;
      }
    });
    _saveMatchState();
  }

  void _requestStopMatch() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text(
          "Atenção",
          style: TextStyle(color: AppColors.textWhite),
        ),
        content: const Text(
          "Deseja realmente finalizar a partida?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _finishMatch();
            },
            child: const Text(
              "Finalizar",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateScore(bool isRed, int delta) {
    setState(() {
      if (isRed) {
        scoreRed = max(0, scoreRed + delta);
      } else {
        scoreWhite = max(0, scoreWhite + delta);
      }
    });
    _saveMatchState();
  }

  // --- TEAM MANAGEMENT LOGIC ---

  void _sortearTeams() {
    if (presentPlayers.length < 2) return;

    setState(() {
      List<Map<String, dynamic>> pool = List.from(presentPlayers);
      pool.shuffle(Random());

      teamRed.clear();
      teamWhite.clear();

      for (int i = 0; i < widget.totalPlayers && pool.isNotEmpty; i++) {
        teamRed.add(pool.removeAt(0));
      }
      for (int i = 0; i < widget.totalPlayers && pool.isNotEmpty; i++) {
        teamWhite.add(pool.removeAt(0));
      }
    });
    _saveMatchState();
  }

  void _addToTeam(Map<String, dynamic> player, bool isRedTeam) {
    List<Map<String, dynamic>> target = isRedTeam ? teamRed : teamWhite;
    List<Map<String, dynamic>> other = isRedTeam ? teamWhite : teamRed;

    setState(() {
      if (target.any((p) => _pid(p) == _pid(player)) ||
          other.any((p) => _pid(p) == _pid(player))) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${player['name']} já está jogando!")),
        );
        return;
      }
      if (target.length >= widget.totalPlayers) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("O time já está cheio (Máx ${widget.totalPlayers})!"),
          ),
        );
        return;
      }
      target.add(player);
    });
    _saveMatchState();
  }

  void _removePlayerFromMatch(Map<String, dynamic> player) {
    setState(() {
      teamRed.removeWhere((p) => _pid(p) == _pid(player));
      teamWhite.removeWhere((p) => _pid(p) == _pid(player));

      // Move player to the END of presentPlayers list (queue behavior)
      final playerIndex = presentPlayers.indexWhere(
        (p) => _pid(p) == _pid(player),
      );
      if (playerIndex != -1) {
        final playerData = presentPlayers.removeAt(playerIndex);
        presentPlayers.add(playerData);
      }
    });
    _saveMatchState();
  }

  void _addPlayersToArrivalList(List<Map<String, dynamic>> selected) {
    setState(() {
      for (var p in selected) {
        if (!presentPlayers.any((e) => _pid(e) == _pid(p))) {
          presentPlayers.add(p);
        }
      }
    });
    _saveMatchState();
  }

  void _clearList() {
    _matchTimer?.cancel();
    setState(() {
      presentPlayers.clear();
      teamRed.clear();
      teamWhite.clear();
      scoreRed = 0;
      scoreWhite = 0;
      redWinStreak = 0;
      whiteWinStreak = 0;
      _secondsPlayedBeforePause = 0;
      _lastStartTime = null;
      isMatchRunning = false;
      isOvertime = false;
      matchEvents.clear();
    });
    _saveMatchState();
  }

  // --- NEW: GOALKEEPER SELECTION LOGIC ---
  void _showGoalkeeperSelectionDialog(
    bool isRedTeam,
    Function(Map<String, dynamic>) onSelected,
  ) {
    // Find all players who are in the arrival list but NOT in the line teams
    final waiting = presentPlayers.where((p) {
      final id = _pid(p);
      bool inRed = teamRed.any((t) => _pid(t) == id);
      bool inWhite = teamWhite.any((t) => _pid(t) == id);
      return !inRed && !inWhite;
    }).toList();

    if (waiting.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Não há jogadores de fora para selecionar como goleiro!",
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text(
          "Selecione o Goleiro",
          style: TextStyle(
            color: Colors.orangeAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: waiting.length,
            itemBuilder: (c, i) => ListTile(
              leading: const Icon(Icons.sports_handball, color: Colors.white54),
              title: Text(
                waiting[i]['name'],
                style: const TextStyle(color: AppColors.textWhite),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onSelected(waiting[i]);
              },
            ),
          ),
        ),
      ),
    );
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xff010a3b),
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
        title: Text(
          widget.tournamentName,
          style: const TextStyle(color: AppColors.textWhite),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          MatchScoreboard(
            scoreRed: scoreRed,
            scoreWhite: scoreWhite,
            timeString: _formatTime(totalSecondsElapsed),
            isMatchRunning: isMatchRunning,
            isOvertime: isOvertime,
            isReadyToStart: _isReadyToStart,
            redTeamRating: _calculateTeamRating(teamRed),
            whiteTeamRating: _calculateTeamRating(teamWhite),
            onUpdateScore: _updateScore,
            onStart: _startMatch,
            onPause: _pauseMatch,
            onStop: _requestStopMatch,
          ),

          _buildGoalScorers(),

          Container(
            color: AppColors.headerBlue,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.accentBlue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.accentBlue,
              tabs: const [
                Tab(text: "CHEGADA"),
                Tab(text: "PARTIDA"),
                Tab(text: "PROXIMOS"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrderArrivalTab(),
                _buildMatchTab(),
                _buildNextTeamsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              backgroundColor: AppColors.accentBlue,
              onPressed: _showActionSheet,
              child: const Icon(Icons.add, color: AppColors.textWhite),
            )
          : null,
    );
  }

  // --- GOAL SCORERS UI ---
  Widget _buildGoalScorers() {
    List<Widget> redScorers = [];
    List<Widget> whiteScorers = [];

    for (var ev in matchEvents) {
      if (ev['type'] == 'goal') {
        if (ev['team'] == 'Vermelho') {
          redScorers.add(
            Text(
              "⚽ ${ev['player']} (${ev['time']})",
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        } else {
          whiteScorers.add(
            Text(
              "⚽ ${ev['player']} (${ev['time']})",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }
      } else if (ev['type'] == 'own_goal') {
        if (ev['team'] == 'Vermelho') {
          whiteScorers.add(
            Text(
              "⚽ ${ev['player']} (GC) (${ev['time']})",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        } else {
          redScorers.add(
            Text(
              "⚽ ${ev['player']} (GC) (${ev['time']})",
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }
      }
    }

    if (redScorers.isEmpty && whiteScorers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      color: AppColors.deepBlue,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: redScorers,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: whiteScorers,
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: ARRIVAL ---
  Widget _buildOrderArrivalTab() {
    if (presentPlayers.isEmpty) {
      return const Center(
        child: Text("Lista vazia.", style: TextStyle(color: Colors.white38)),
      );
    }
    return ReorderableListView(
      padding: const EdgeInsets.all(16),
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = presentPlayers.removeAt(oldIndex);
          presentPlayers.insert(newIndex, item);
        });
        _saveMatchState();
      },
      children: [
        for (int i = 0; i < presentPlayers.length; i++)
          Container(
            key: ValueKey(_pid(presentPlayers[i])),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.headerBlue,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: ListTile(
              // --- UPDATED: SHOW PLAYER ICON OR INITIAL ---
              leading: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.deepBlue,
                    backgroundImage: presentPlayers[i]['icon'] != null
                        ? AssetImage(presentPlayers[i]['icon'])
                        : null,
                    child: presentPlayers[i]['icon'] == null
                        ? Text(
                            presentPlayers[i]['name'][0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  // Small number showing their arrival position
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppColors.accentBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      "${i + 1}",
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      presentPlayers[i]['name'],
                      style: const TextStyle(
                        color: AppColors.textWhite,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // --- UPDATED: 10-POINT RATING BADGE ---
                  if (presentPlayers[i]['rating'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        (presentPlayers[i]['rating'] as num)
                            .toDouble()
                            .toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              trailing: const Icon(Icons.more_vert, color: Colors.white24),
              onTap: () => _showChegadaOptions(presentPlayers[i]),
            ),
          ),
      ],
    );
  }

  // --- TAB 2: MATCH ---
  Widget _buildMatchTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // --- NOVO: AVISO DE SEQUÊNCIA ---
          if (redWinStreak > 0 || whiteWinStreak > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text(
                    redWinStreak > 0 ? "🔥 Sequência: $redWinStreak/3" : "",
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    whiteWinStreak > 0 ? "🔥 Sequência: $whiteWinStreak/3" : "",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          // --------------------------------
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.totalPlayers,
            itemBuilder: (context, index) {
              final redPlayer = (index < teamRed.length)
                  ? teamRed[index]
                  : null;
              final whitePlayer = (index < teamWhite.length)
                  ? teamWhite[index]
                  : null;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 70,
                child: Row(
                  children: [
                    Expanded(
                      child: PlayerFieldSlot(
                        player: redPlayer,
                        isRed: true,
                        onTap: () {
                          if (redPlayer == null) return;
                          if (isMatchRunning) {
                            _showInGameOptions(redPlayer, true);
                          } else {
                            _showRemovePopup(redPlayer);
                          }
                        },
                      ),
                    ),
                    Container(
                      width: 30,
                      alignment: Alignment.center,
                      child: const Text(
                        "VS",
                        style: TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ),
                    Expanded(
                      child: PlayerFieldSlot(
                        player: whitePlayer,
                        isRed: false,
                        onTap: () {
                          if (whitePlayer == null) return;
                          if (isMatchRunning) {
                            _showInGameOptions(whitePlayer, false);
                          } else {
                            _showRemovePopup(whitePlayer);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // --- NEW: GOALKEEPER BUTTONS ---
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (!isMatchRunning) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Inicie a partida primeiro!"),
                        ),
                      );
                      return;
                    }
                    _showGoalkeeperSelectionDialog(true, (selectedGk) {
                      _showInGameOptions(selectedGk, true);
                    });
                  },
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sports_handball,
                          color: Colors.orangeAccent,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Goleiro",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (!isMatchRunning) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Inicie a partida primeiro!"),
                        ),
                      );
                      return;
                    }
                    _showGoalkeeperSelectionDialog(false, (selectedGk) {
                      _showInGameOptions(selectedGk, false);
                    });
                  },
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white54),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sports_handball,
                          color: Colors.orangeAccent,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Goleiro",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // -------------------------------
        ],
      ),
    );
  }

  // --- TAB 3: NEXT TEAMS ---
  Widget _buildNextTeamsTab() {
    final waiting = presentPlayers.where((p) {
      final id = _pid(p);
      bool inRed = teamRed.any((t) => _pid(t) == id);
      bool inWhite = teamWhite.any((t) => _pid(t) == id);
      return !inRed && !inWhite;
    });

    if (waiting.isEmpty) {
      return const Center(
        child: Text(
          "Todos os jogadores estão jogando!",
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    // Calculate team size (both teams combined)
    final int teamSize = widget.totalPlayers;

    return ReorderableListView(
      padding: const EdgeInsets.all(16),
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final playerMoving = waiting.elementAt(oldIndex);
          presentPlayers.remove(playerMoving);

          int targetMainIndex;
          if (newIndex >= waiting.length - 1) {
            targetMainIndex = presentPlayers.length;
          } else {
            final playerAtTarget = waiting.elementAt(newIndex);
            targetMainIndex = presentPlayers.indexOf(playerAtTarget);
          }

          if (targetMainIndex > presentPlayers.length) {
            targetMainIndex = presentPlayers.length;
          }
          presentPlayers.insert(targetMainIndex, playerMoving);
        });
        _saveMatchState();
      },
      children: _buildIndividualPlayerCards(waiting, teamSize),
    );
  }

  List<Widget> _buildIndividualPlayerCards(
    Iterable<Map<String, dynamic>> waiting,
    int teamSize,
  ) {
    final List<Widget> cards = [];
    final int numCompleteTeams = waiting.length ~/ teamSize;
    final int remainingPlayers = waiting.length % teamSize;

    // Build cards for complete teams
    for (int teamIndex = 0; teamIndex < numCompleteTeams; teamIndex++) {
      final int startIndex = teamIndex * teamSize;
      final bool isFirstTeam = teamIndex == 0;

      for (int i = 0; i < teamSize; i++) {
        final playerIndex = startIndex + i;
        final isFirstPlayerInTeam = i == 0;
        final isLastPlayerInTeam = i == teamSize - 1;

        cards.add(
          _buildIndividualPlayerCard(
            waiting.elementAt(playerIndex),
            playerIndex,
            isFirstTeam: isFirstTeam,
            isFirstPlayerInTeam: isFirstPlayerInTeam,
            isLastPlayerInTeam: isLastPlayerInTeam,
            teamBatch: teamIndex + 1,
          ),
        );
      }
    }

    // Build cards for remaining players
    if (remainingPlayers > 0) {
      final int startIndex = numCompleteTeams * teamSize;
      for (int i = 0; i < remainingPlayers; i++) {
        final playerIndex = startIndex + i;
        cards.add(
          _buildIndividualPlayerCard(
            waiting.elementAt(playerIndex),
            playerIndex,
            isFirstTeam: false,
            isFirstPlayerInTeam: false,
            isLastPlayerInTeam: false,
            teamBatch: numCompleteTeams + 1,
          ),
        );
      }
    }

    return cards;
  }

  Widget _buildIndividualPlayerCard(
    Map<String, dynamic> player,
    int index, {
    required bool isFirstTeam,
    required bool isFirstPlayerInTeam,
    required bool isLastPlayerInTeam,
    required int teamBatch,
  }) {
    final iconPath = player['icon'] as String?;
    final rating = player['rating'] != null
        ? (player['rating'] as num).toDouble()
        : 0.0;

    // Calculate margins to create visual team grouping
    final EdgeInsets margin = EdgeInsets.only(
      bottom: isLastPlayerInTeam ? 16 : 4,
      top: isFirstPlayerInTeam ? (isFirstTeam ? 0 : 8) : 0,
    );

    return Container(
      key: ValueKey(_pid(player)),
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFirstTeam
              ? AppColors.accentBlue.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.05),
          width: isFirstTeam ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              backgroundColor: isFirstTeam
                  ? AppColors.accentBlue.withValues(alpha: 0.2)
                  : AppColors.deepBlue,
              backgroundImage: iconPath != null ? AssetImage(iconPath) : null,
              child: iconPath == null
                  ? Text(
                      player['name'][0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                player['name'],
                style: TextStyle(
                  color: isFirstTeam ? Colors.white : Colors.white70,
                  fontWeight: isFirstTeam ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (rating > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  rating.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.drag_handle, color: Colors.white24),
        onTap: () => _showChegadaOptions(player),
      ),
    );
  }

  // --- DIALOGS ---

  void _showChegadaOptions(Map<String, dynamic> player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.deepBlue,
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.shield, color: Colors.redAccent),
            title: const Text(
              "Add Vermelho",
              style: TextStyle(color: AppColors.textWhite),
            ),
            onTap: () {
              Navigator.pop(ctx);
              _addToTeam(player, true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.shield, color: Colors.white),
            title: const Text(
              "Add Branco",
              style: TextStyle(color: AppColors.textWhite),
            ),
            onTap: () {
              Navigator.pop(ctx);
              _addToTeam(player, false);
            },
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text(
              "Desistiu (Remover)",
              style: TextStyle(color: Colors.red),
            ),
            onTap: () => _confirmGiveUp(player),
          ),
        ],
      ),
    );
  }

  void _showRemovePopup(Map<String, dynamic> player) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text(
          "Remover?",
          style: TextStyle(color: AppColors.textWhite),
        ),
        content: Text(
          "Tirar ${player['name']} do time?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.white54),
            ),
            onPressed: () => Navigator.pop(c),
          ),
          TextButton(
            child: const Text(
              "Remover",
              style: TextStyle(color: Colors.redAccent),
            ),
            onPressed: () {
              _removePlayerFromMatch(player);
              Navigator.pop(c);
            },
          ),
        ],
      ),
    );
  }

  void _confirmGiveUp(Map<String, dynamic> player) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text(
          "Desistência",
          style: TextStyle(color: AppColors.textWhite),
        ),
        content: const Text(
          "Vai sair da lista?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.white54),
            ),
            onPressed: () => Navigator.pop(c),
          ),
          TextButton(
            child: const Text(
              "Confirmar",
              style: TextStyle(color: Colors.redAccent),
            ),
            onPressed: () {
              setState(() {
                presentPlayers.removeWhere((p) => _pid(p) == _pid(player));
                _removePlayerFromMatch(player);
              });
              _saveMatchState();
              Navigator.pop(c);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showMultiSelectDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final String? dbData = prefs.getString('players_${widget.groupId}');

    if (dbData != null) {
      setState(() {
        allSavedPlayers = List<Map<String, dynamic>>.from(jsonDecode(dbData));
      });
    }

    if (allSavedPlayers.isEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: AppColors.headerBlue,
          title: const Text(
            "Nenhum Jogador Cadastrado",
            style: TextStyle(color: Colors.redAccent),
          ),
          content: const Text(
            "Você precisa cadastrar jogadores na tela 'Jogadores' antes de adicioná-los à partida.",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    List<Map<String, dynamic>> tempSelected = [];
    final available = allSavedPlayers
        .where(
          (p) => !presentPlayers.any((present) => _pid(present) == _pid(p)),
        )
        .toList();

    // Sort available players by name alphabetically
    available.sort(
      (a, b) => (a['name'] as String).toLowerCase().compareTo(
        (b['name'] as String).toLowerCase(),
      ),
    );

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, st) => AlertDialog(
          backgroundColor: AppColors.headerBlue,
          title: const Text(
            "Adicionar Jogadores",
            style: TextStyle(color: AppColors.textWhite),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: available.isEmpty
                ? const Center(
                    child: Text(
                      "Todos os jogadores já foram adicionados!",
                      style: TextStyle(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: available.length,
                    itemBuilder: (c, i) => CheckboxListTile(
                      activeColor: AppColors.accentBlue,
                      checkColor: AppColors.textWhite,
                      title: Text(
                        available[i]['name'],
                        style: const TextStyle(color: AppColors.textWhite),
                      ),
                      value: tempSelected.contains(available[i]),
                      onChanged: (v) => st(
                        () => v!
                            ? tempSelected.add(available[i])
                            : tempSelected.remove(available[i]),
                      ),
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text(
                "Cancelar",
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            if (available.isNotEmpty)
              TextButton(
                onPressed: () {
                  _addPlayersToArrivalList(tempSelected);
                  Navigator.pop(c);
                },
                child: const Text(
                  "OK",
                  style: TextStyle(
                    color: AppColors.accentBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.headerBlue,
      builder: (c) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.person_add, color: Colors.greenAccent),
            title: const Text(
              'Adicionar',
              style: TextStyle(color: AppColors.textWhite),
            ),
            onTap: () {
              Navigator.pop(c);
              _showMultiSelectDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.shuffle, color: Colors.orangeAccent),
            title: const Text(
              'Sortear Linha',
              style: TextStyle(color: AppColors.textWhite),
            ),
            onTap: () {
              Navigator.pop(c);
              _sortearTeams();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: const Text(
              'Limpar Tudo',
              style: TextStyle(color: AppColors.textWhite),
            ),
            onTap: () {
              Navigator.pop(c);
              _clearList();
            },
          ),
        ],
      ),
    );
  }

  // --- IN-GAME EVENT LOGIC ---

  void _handleGoal(Map<String, dynamic> player, bool isRedTeam) {
    List<Map<String, dynamic>> teammates = isRedTeam
        ? List.from(teamRed)
        : List.from(teamWhite);
    teammates.removeWhere((p) => _pid(p) == _pid(player));

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text(
          "Assistência",
          style: TextStyle(
            color: AppColors.highlightBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          SimpleDialogOption(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: const Text(
              "Jogada Individual",
              style: TextStyle(color: AppColors.textWhite, fontSize: 16),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _registerEvent("goal", player, isRedTeam, assist: null);
            },
          ),
          const Divider(color: Colors.white12),

          // Field Teammates
          ...teammates
              .map(
                (teammate) => SimpleDialogOption(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 24,
                  ),
                  child: Text(
                    teammate['name'],
                    style: const TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 16,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _registerEvent(
                      "goal",
                      player,
                      isRedTeam,
                      assist: teammate['name'],
                      assistId: _pid(teammate),
                    );
                  },
                ),
              ),

          // --- NEW: GOALKEEPER ASSIST OPTION ---
          const Divider(color: Colors.white12),
          SimpleDialogOption(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: const Row(
              children: [
                Icon(
                  Icons.sports_handball,
                  color: AppColors.textWhite,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  "Goleiro",
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            onPressed: () {
              Navigator.pop(ctx); // Close assist menu
              // Open goalkeeper selection
              _showGoalkeeperSelectionDialog(isRedTeam, (selectedGk) {
                _registerEvent(
                  "goal",
                  player,
                  isRedTeam,
                  assist: selectedGk['name'],
                  assistId: _pid(selectedGk),
                );
              });
            },
          ),
          // ------------------------------------
        ],
      ),
    );
  }

  void _registerEvent(
    String type,
    Map<String, dynamic> player,
    bool isRedTeam, {
    String? assist,
    String? assistId,
  }) async {
    try {
      if (type == "goal") {
        await _audioPlayer.play(AssetSource('audio/goal.mp3'));
      } else if (type == "own_goal") {
        await _audioPlayer.play(AssetSource('audio/goal.mp3'));
      }
    } catch (e) {
      debugPrint("Audio error: $e");
    }

    setState(() {
      if (type == "goal") {
        if (isRedTeam) {
          scoreRed++;
        } else {
          scoreWhite++;
        }
      } else if (type == "own_goal") {
        if (isRedTeam) {
          scoreWhite++;
        } else {
          scoreRed++;
        }
      }

      matchEvents.add({
        "type": type,
        "playerId": _pid(player),
        "player": player['name'],
        "assistId": assistId,
        "assist": assist,
        "team": isRedTeam ? "Vermelho" : "Branco",
        "time": _formatTime(totalSecondsElapsed),
      });
    });

    _saveMatchState();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Evento registrado!"),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _showInGameOptions(Map<String, dynamic> player, bool isRedTeam) {
    // Determine if player is officially on the field (Not a Goalkeeper)
    bool isLinePlayer =
        teamRed.any((p) => _pid(p) == _pid(player)) ||
        teamWhite.any((p) => _pid(p) == _pid(player));

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.deepBlue,
      builder: (ctx) {
        return Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Ações para ${player['name']}",
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.sports_soccer,
                color: Colors.greenAccent,
              ),
              title: const Text(
                "Fez Gol",
                style: TextStyle(color: AppColors.textWhite),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _handleGoal(player, isRedTeam);
              },
            ),
            ListTile(
              leading: const Icon(Icons.error_outline, color: Colors.redAccent),
              title: const Text(
                "Gol Contra",
                style: TextStyle(color: AppColors.textWhite),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _registerEvent("own_goal", player, isRedTeam);
              },
            ),
            ListTile(
              leading: const Icon(Icons.style, color: Colors.yellowAccent),
              title: const Text(
                "Cartão Amarelo",
                style: TextStyle(color: AppColors.textWhite),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _registerEvent("yellow_card", player, isRedTeam);
              },
            ),
            ListTile(
              leading: const Icon(Icons.style, color: Colors.redAccent),
              title: const Text(
                "Cartão Vermelho",
                style: TextStyle(color: AppColors.textWhite),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _registerEvent("red_card", player, isRedTeam);
              },
            ),

            // Only allow "Substituir" for line players so we don't mess up the queue
            if (isLinePlayer) ...[
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.grey),
                title: const Text(
                  "Substituir / Remover",
                  style: TextStyle(color: AppColors.textWhite),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRemovePopup(player);
                },
              ),
            ],
          ],
        );
      },
    );
  }

  // --- END GAME LOGIC ---

void _finishMatch() async {
    _matchTimer?.cancel();

    final Map<String, dynamic> matchRecord = {
      "match_id": DateTime.now().millisecondsSinceEpoch.toString(),
      "date": DateTime.now().toIso8601String(),
      "match_duration": _formatTime(totalSecondsElapsed),
      "scoreRed": scoreRed,
      "scoreWhite": scoreWhite,
      "events": List.from(matchEvents),
      "players": {"red": List.from(teamRed), "white": List.from(teamWhite)},
    };

    final prefs = await SharedPreferences.getInstance();
    final String historyKey = 'match_history_${widget.tournamentId}';
    List<dynamic> history = [];

    try {
      if (prefs.containsKey(historyKey)) {
        history = jsonDecode(prefs.getString(historyKey)!);
      }
    } catch (e) {
      debugPrint("Corrupted history found. Wiping old history...");
      history = [];
    }

    history.add(matchRecord);
    await prefs.setString(historyKey, jsonEncode(history));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Partida salva no Histórico!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }

    // --- LÓGICA DE STREAK E SUGESTÃO DE SAÍDA ---
    bool isTie = scoreRed == scoreWhite;
    bool redWon = scoreRed > scoreWhite;
    List<Map<String, dynamic>> suggestedLeavers = [];
    String popupTitle = "";
    String popupMessage = "";
    Color popupColor = AppColors.textWhite;

    if (isTie) {
      redWinStreak = 0;
      whiteWinStreak = 0;
      suggestedLeavers.addAll(teamRed);
      suggestedLeavers.addAll(teamWhite);
      suggestedLeavers.shuffle(Random());
      popupTitle = "Empate!";
      popupMessage = "Sugestão do Sistema:\nAmbos os times saem.";
      popupColor = Colors.orangeAccent;
    } else {
      _playVictorySound();
      
      if (redWon) {
        redWinStreak++;
        whiteWinStreak = 0;
        if (redWinStreak >= 3) {
          suggestedLeavers.addAll(teamRed);
          suggestedLeavers.addAll(teamWhite);
          suggestedLeavers.shuffle(Random());
          redWinStreak = 0; // Zera a sequência
          popupTitle = "🔥 VERMELHO INVICTO!";
          popupMessage = "Vermelho ganhou 3 seguidas!\nSugestão: TODOS saem da quadra.";
          popupColor = Colors.redAccent;
        } else {
          suggestedLeavers.addAll(teamWhite);
          popupTitle = "Vitória do VERMELHO!";
          popupMessage = "Sugestão: Branco sai.\n(Sequência do Vermelho: $redWinStreak/3)";
          popupColor = Colors.redAccent;
        }
      } else {
        whiteWinStreak++;
        redWinStreak = 0;
        if (whiteWinStreak >= 3) {
          suggestedLeavers.addAll(teamRed);
          suggestedLeavers.addAll(teamWhite);
          suggestedLeavers.shuffle(Random());
          whiteWinStreak = 0; // Zera a sequência
          popupTitle = "🔥 BRANCO INVICTO!";
          popupMessage = "Branco ganhou 3 seguidas!\nSugestão: TODOS saem da quadra.";
          popupColor = Colors.white;
        } else {
          suggestedLeavers.addAll(teamRed);
          popupTitle = "Vitória do BRANCO!";
          popupMessage = "Sugestão: Vermelho sai.\n(Sequência do Branco: $whiteWinStreak/3)";
          popupColor = Colors.white;
        }
      }
    }

    if (!mounted) return;
    
    // Mostra o Popup Semi-Automático
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: Text(
          popupTitle,
          style: TextStyle(color: popupColor, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 60),
            const SizedBox(height: 16),
            Text(
              "Placar Final: $scoreRed x $scoreWhite",
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                popupMessage,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Fecha o dialog de sugestão
              _showManualExitDialog(); // Abre a escolha manual
            },
            child: const Text(
              "Alterar na Mão",
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _processMatchExit(suggestedLeavers); // Aceita a sugestão do sistema
            },
            child: const Text(
              "Confirmar >>",
              style: TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showManualExitDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text("Intervenção Manual", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Quem deve sair de campo?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text(
              "Vermelho",
              style: TextStyle(color: Colors.redAccent),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _processMatchExit(List.from(teamRed));
            },
          ),
          TextButton(
            child: const Text(
              "Branco",
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _processMatchExit(List.from(teamWhite));
            },
          ),
          TextButton(
            child: const Text(
              "Ambos",
              style: TextStyle(color: Colors.orangeAccent),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              List<Map<String, dynamic>> both = [];
              both.addAll(teamRed);
              both.addAll(teamWhite);
              both.shuffle(Random()); // Embaralha para ficar justo na fila
              _processMatchExit(both);
            },
          ),
        ],
      ),
    );
  }

  void _processMatchExit(List<Map<String, dynamic>> leavers) {
    setState(() {
      bool redIsLeaving = teamRed.any((p) => leavers.any((l) => _pid(l) == _pid(p)));
      bool whiteIsLeaving = teamWhite.any((p) => leavers.any((l) => _pid(l) == _pid(p)));
      
      if (redIsLeaving) redWinStreak = 0;
      if (whiteIsLeaving) whiteWinStreak = 0;
      
      for (var p in leavers) {
        int index = presentPlayers.indexWhere(
          (element) => _pid(element) == _pid(p),
        );
        if (index != -1) {
          var player = presentPlayers.removeAt(index);
          presentPlayers.add(player);
        }
      }

      List<Map<String, dynamic>> entering = [];
      int needed = leavers.length;

      for (var p in presentPlayers) {
        if (entering.length >= needed) break;
        final id = _pid(p);
        bool inRed = teamRed.any((t) => _pid(t) == id);
        bool inWhite = teamWhite.any((t) => _pid(t) == id);

        if (!inRed && !inWhite) entering.add(p);
      }

      teamRed.removeWhere((p) => leavers.any((l) => _pid(l) == _pid(p)));
      teamWhite.removeWhere((p) => leavers.any((l) => _pid(l) == _pid(p)));

      List<Map<String, dynamic>> pool = List.from(entering);

      while (teamRed.length < widget.totalPlayers && pool.isNotEmpty) {
        teamRed.add(pool.removeAt(0));
      }
      while (teamWhite.length < widget.totalPlayers && pool.isNotEmpty) {
        teamWhite.add(pool.removeAt(0));
      }

      isMatchRunning = false;
      isOvertime = false;
      scoreRed = 0;
      scoreWhite = 0;
      matchEvents.clear();
      _secondsPlayedBeforePause = 0;
      _lastStartTime = null;

      _saveMatchState();
      _showLeaversPopup(leavers, entering);
    });
  }

  void _showLeaversPopup(
    List<Map<String, dynamic>> leavers,
    List<Map<String, dynamic>> entering,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepBlue,
        title: const Text(
          "Saindo de Campo",
          style: TextStyle(color: Colors.redAccent),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: leavers.length,
            itemBuilder: (c, i) => ListTile(
              dense: true,
              leading: const Icon(
                Icons.arrow_downward,
                color: Colors.redAccent,
              ),
              title: Text(
                leavers[i]['name'],
                style: const TextStyle(color: Colors.redAccent, fontSize: 16),
              ),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white24),
            onPressed: () {
              Navigator.pop(ctx);
              if (entering.isNotEmpty) _showEnteringPlayersPopup(entering);
            },
            child: const Text(
              "Ver Quem Entrou >>",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _playVictorySound() async {
    List<String> sounds = [
      'audio/vitoria1.mp3',
      'audio/vitoria2.mp3',
      'audio/vitoria3.mp3',
    ];
    String randomSound = sounds[Random().nextInt(sounds.length)];
    try {
      await _audioPlayer.play(AssetSource(randomSound));
    } catch (e) {
      debugPrint("Victory sound error: $e");
    }
  }

  void _showEnteringPlayersPopup(List<Map<String, dynamic>> entering) {
    if (entering.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepBlue,
        title: const Text(
          "Entrando em Campo",
          style: TextStyle(color: Colors.greenAccent),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: entering.length,
            itemBuilder: (c, i) => ListTile(
              dense: true,
              leading: const Icon(
                Icons.arrow_upward,
                color: Colors.greenAccent,
              ),
              title: Text(
                entering[i]['name'],
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
