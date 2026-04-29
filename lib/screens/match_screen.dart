import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/player_identity.dart';

import '../widgets/match/match_scoreboard.dart';

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

class _MatchScreenState extends State<MatchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Map<String, dynamic>> allSavedPlayers = [];
  List<Map<String, dynamic>> presentPlayers = [];
  List<Map<String, dynamic>> teamRed = [];
  List<Map<String, dynamic>> teamWhite = [];

  int scoreRed = 0;
  int scoreWhite = 0;
  int redWinStreak = 0; 
  int whiteWinStreak = 0;
  bool isMatchRunning = false;
  bool isOvertime = false;
  int winLimit = 3;
  Timer? _matchTimer;

  int _secondsPlayedBeforePause = 0;
  DateTime? _lastStartTime;
  
  bool _showTacticalPitch = true;

  int get totalSecondsElapsed {
    if (!isMatchRunning || _lastStartTime == null) return _secondsPlayedBeforePause;
    return _secondsPlayedBeforePause + DateTime.now().difference(_lastStartTime!).inSeconds;
  }

  List<Map<String, dynamic>> matchEvents = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() { setState(() {}); });
    _loadMatchState();
  }

  @override
  void dispose() {
    _matchTimer?.cancel();
    _tabController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  bool get _isReadyToStart => teamRed.length == widget.totalPlayers && teamWhite.length == widget.totalPlayers;

  String _formatTime(int totalSeconds) {
    int min = totalSeconds ~/ 60;
    int sec = totalSeconds % 60;
    return "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
  }

  double _calculateTeamRating(List<Map<String, dynamic>> team) {
    if (team.isEmpty) return 0.0;
    double totalStars = 0.0;
    for (var player in team) totalStars += player['rating'] != null ? (player['rating'] as num).toDouble() : 0.0;
    return totalStars / team.length;
  }

  String _pid(Map<String, dynamic> player) => playerIdFromObject(player);

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
      await prefs.setString('start_timestamp_$id', _lastStartTime!.toIso8601String());
    } else {
      await prefs.remove('start_timestamp_$id');
    }
    
    await prefs.setInt('red_streak_$id', redWinStreak);
    await prefs.setInt('white_streak_$id', whiteWinStreak);
  }

  Future<void> _loadMatchState() async {
    final prefs = await SharedPreferences.getInstance();
    final String id = widget.tournamentId;

    _showTacticalPitch = prefs.getBool('show_tactical_pitch') ?? true;

    final String? dbData = prefs.getString('players_${widget.groupId}');
    if (dbData != null) allSavedPlayers = ensurePlayerIds(List<Map<String, dynamic>>.from(jsonDecode(dbData)));

    setState(() {
      if (prefs.containsKey('present_players_$id')) presentPlayers = ensurePlayerIds(List<Map<String, dynamic>>.from(jsonDecode(prefs.getString('present_players_$id')!)));
      if (prefs.containsKey('team_red_$id')) teamRed = ensurePlayerIds(List<Map<String, dynamic>>.from(jsonDecode(prefs.getString('team_red_$id')!)));
      if (prefs.containsKey('team_white_$id')) teamWhite = ensurePlayerIds(List<Map<String, dynamic>>.from(jsonDecode(prefs.getString('team_white_$id')!)));
      if (prefs.containsKey('match_events_$id')) matchEvents = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString('match_events_$id')!));

      int sessionWinLimit = 3;
      final sessionsData = prefs.getString('sessions_${widget.groupId}');
      if (sessionsData != null) {
        final List<dynamic> allSessions = jsonDecode(sessionsData);
        final currentSession = allSessions.firstWhere((s) => s['id'] == widget.tournamentId, orElse: () => null);
        if (currentSession != null && currentSession is Map && currentSession.containsKey('win_limit')) {
          sessionWinLimit = currentSession['win_limit'];
        }
      }
      winLimit = sessionWinLimit;

      void syncRatings(List<Map<String, dynamic>> list) {
        for (var p in list) {
          final dbPlayer = allSavedPlayers.firstWhere((dbP) => _pid(dbP) == _pid(p), orElse: () => {});
          if (dbPlayer.isNotEmpty && dbPlayer['rating'] != null) p['rating'] = dbPlayer['rating'];
        }
      }
      syncRatings(presentPlayers);
      syncRatings(teamRed);
      syncRatings(teamWhite);

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
              try { _audioPlayer.play(AssetSource('audio/end.mp3')); } catch (e) { }
            }
          });
        });
      }
    });
  }

  void _startMatch() async {
    if (isMatchRunning) return;
    setState(() { isMatchRunning = true; _lastStartTime = DateTime.now(); });
    try { await _audioPlayer.play(AssetSource('audio/end.mp3')); } catch (e) { }
    _saveMatchState();
    _matchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (totalSecondsElapsed >= 480 && !isOvertime) {
          isOvertime = true;
          try { _audioPlayer.play(AssetSource('audio/end.mp3')); } catch (e) { }
        }
      });
    });
  }

  void _pauseMatch() {
    _matchTimer?.cancel();
    setState(() {
      isMatchRunning = false;
      if (_lastStartTime != null) {
        _secondsPlayedBeforePause += DateTime.now().difference(_lastStartTime!).inSeconds;
        _lastStartTime = null;
      }
    });
    _saveMatchState();
  }

  void _requestStopMatch() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue, title: const Text("Atenção", style: TextStyle(color: AppColors.textWhite)),
        content: const Text("Deseja pausar e revisar a Súmula da partida?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () { 
            Navigator.pop(ctx); 
            _pauseMatch(); 
            _showMatchSummary(); 
          }, child: const Text("Ver Súmula", style: TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _editAssistInSummary(int eventIndex, StateSetter setSummaryState) {
    final ev = matchEvents[eventIndex];
    bool isRedTeam = ev['team'] == 'Vermelho';
    List<Map<String, dynamic>> teammates = isRedTeam ? List.from(teamRed) : List.from(teamWhite);
    
    teammates.removeWhere((p) => _pid(p) == ev['playerId']);

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text("Editar Assistência", style: TextStyle(color: AppColors.highlightBlue, fontWeight: FontWeight.bold)),
        children: [
          SimpleDialogOption(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: const Text("Jogada Individual (Remover Assist.)", style: TextStyle(color: Colors.redAccent, fontSize: 16)),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() { matchEvents[eventIndex]['assist'] = null; matchEvents[eventIndex]['assistId'] = null; });
              _saveMatchState();
              setSummaryState(() {});
            },
          ),
          const Divider(color: Colors.white12),
          ...teammates.map((teammate) => SimpleDialogOption(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: Text(teammate['name'], style: const TextStyle(color: AppColors.textWhite, fontSize: 16)),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() { matchEvents[eventIndex]['assist'] = teammate['name']; matchEvents[eventIndex]['assistId'] = _pid(teammate); });
              _saveMatchState();
              setSummaryState(() {});
            },
          )),
          const Divider(color: Colors.white12),
          SimpleDialogOption(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: const Row(children: [Icon(Icons.sports_handball, color: AppColors.textWhite, size: 20), SizedBox(width: 8), Text("Goleiro", style: TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.bold))]),
            onPressed: () {
              Navigator.pop(ctx);
              _showGoalkeeperSelectionDialog(isRedTeam, (selectedGk) {
                setState(() { matchEvents[eventIndex]['assist'] = selectedGk['name']; matchEvents[eventIndex]['assistId'] = _pid(selectedGk); });
                _saveMatchState();
                setSummaryState(() {});
              });
            },
          ),
        ],
      ),
    );
  }

  void _showMatchSummary() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.deepBlue,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Súmula", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text("$scoreRed x $scoreWhite", style: const TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.5,
                child: matchEvents.isEmpty
                    ? const Center(child: Text("Nenhum evento registrado.", style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: matchEvents.length,
                        itemBuilder: (c, i) {
                          final ev = matchEvents[i];
                          IconData icon = Icons.circle; Color iconColor = Colors.grey;
                          if (ev['type'] == 'goal') { icon = Icons.sports_soccer; iconColor = Colors.greenAccent; }
                          else if (ev['type'] == 'own_goal') { icon = Icons.error_outline; iconColor = Colors.redAccent; }
                          else if (ev['type'] == 'yellow_card') { icon = Icons.style; iconColor = Colors.yellow; }
                          else if (ev['type'] == 'red_card') { icon = Icons.style; iconColor = Colors.red; }

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: Icon(icon, color: iconColor, size: 20),
                            title: Text("${ev['player']} (${ev['team']})", style: const TextStyle(color: Colors.white)),
                            subtitle: Text(
                              ev['type'] == 'goal' ? (ev['assist'] != null ? "Assist: ${ev['assist']}" : "Individual") : "", 
                              style: const TextStyle(color: Colors.white54, fontSize: 12)
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (ev['type'] == 'goal')
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.amber, size: 20),
                                    onPressed: () => _editAssistInSummary(i, setDialogState),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      var removed = matchEvents.removeAt(i);
                                      bool isRed = removed['team'] == 'Vermelho';
                                      if (removed['type'] == 'goal') {
                                        if (isRed) scoreRed = max(0, scoreRed - 1); else scoreWhite = max(0, scoreWhite - 1);
                                      } else if (removed['type'] == 'own_goal') {
                                        if (isRed) scoreWhite = max(0, scoreWhite - 1); else scoreRed = max(0, scoreRed - 1);
                                      }
                                    });
                                    _saveMatchState();
                                    setDialogState(() {}); 
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Voltar ao Jogo", style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _finishMatch(); 
                  },
                  child: const Text("Encerrar Partida", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _updateScore(bool isRed, int delta) {
    setState(() { if (isRed) scoreRed = max(0, scoreRed + delta); else scoreWhite = max(0, scoreWhite + delta); });
    _saveMatchState();
  }

  void _sortearTeams() {
    if (presentPlayers.length < 2) return;
    setState(() {
      int needed = widget.totalPlayers * 2;
      List<Map<String, dynamic>> pool = presentPlayers.take(needed).toList();
      
      // Ordena do melhor para o pior (Draft Mode) - Assumindo nota 5.0 como base agora
      pool.sort((a, b) => ((b['rating'] ?? 5.0) as num).compareTo((a['rating'] ?? 5.0) as num));
      
      teamRed.clear(); 
      teamWhite.clear();
      double sumRed = 0; 
      double sumWhite = 0;
      
      for (var p in pool) {
        if (teamRed.length < widget.totalPlayers && teamWhite.length < widget.totalPlayers) {
          if (sumRed <= sumWhite) { 
            teamRed.add(p); 
            sumRed += ((p['rating'] ?? 5.0) as num).toDouble(); 
          } else { 
            teamWhite.add(p); 
            sumWhite += ((p['rating'] ?? 5.0) as num).toDouble(); 
          }
        } else if (teamRed.length < widget.totalPlayers) {
          teamRed.add(p); 
          sumRed += ((p['rating'] ?? 5.0) as num).toDouble();
        } else {
          teamWhite.add(p); 
          sumWhite += ((p['rating'] ?? 5.0) as num).toDouble();
        }
      }
    });
    _saveMatchState();
  }

  void _addToTeam(Map<String, dynamic> player, bool isRedTeam) {
    List<Map<String, dynamic>> target = isRedTeam ? teamRed : teamWhite;
    List<Map<String, dynamic>> other = isRedTeam ? teamWhite : teamRed;
    setState(() {
      if (target.any((p) => _pid(p) == _pid(player)) || other.any((p) => _pid(p) == _pid(player))) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${player['name']} já está jogando!"))); return; }
      if (target.length >= widget.totalPlayers) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("O time já está cheio!"))); return; }
      target.add(player);
    });
    _saveMatchState();
  }

  void _removePlayerFromMatch(Map<String, dynamic> player) {
    setState(() {
      teamRed.removeWhere((p) => _pid(p) == _pid(player));
      teamWhite.removeWhere((p) => _pid(p) == _pid(player));
      final playerIndex = presentPlayers.indexWhere((p) => _pid(p) == _pid(player));
      if (playerIndex != -1) { final playerData = presentPlayers.removeAt(playerIndex); presentPlayers.add(playerData); }
    });
    _saveMatchState();
  }

  void _addPlayersToArrivalList(List<Map<String, dynamic>> selected) {
    setState(() { for (var p in selected) if (!presentPlayers.any((e) => _pid(e) == _pid(p))) presentPlayers.add(p); });
    _saveMatchState();
  }

  void _clearList() {
    _matchTimer?.cancel();
    setState(() {
      presentPlayers.clear(); teamRed.clear(); teamWhite.clear();
      scoreRed = 0; scoreWhite = 0; redWinStreak = 0; whiteWinStreak = 0;
      _secondsPlayedBeforePause = 0; _lastStartTime = null;
      isMatchRunning = false; isOvertime = false; matchEvents.clear();
    });
    _saveMatchState();
  }

  void _showGoalkeeperSelectionDialog(bool isRedTeam, Function(Map<String, dynamic>) onSelected) {
    final waiting = presentPlayers.where((p) { final id = _pid(p); return !teamRed.any((t) => _pid(t) == id) && !teamWhite.any((t) => _pid(t) == id); }).toList();
    if (waiting.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Não há jogadores de fora para selecionar como goleiro!"))); return; }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue, title: const Text("Selecione o Goleiro", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
        content: SizedBox(width: double.maxFinite, child: ListView.builder(shrinkWrap: true, itemCount: waiting.length, itemBuilder: (c, i) => ListTile(leading: const Icon(Icons.sports_handball, color: Colors.white54), title: Text(waiting[i]['name'], style: const TextStyle(color: AppColors.textWhite)), onTap: () { Navigator.pop(ctx); onSelected(waiting[i]); }))),
      ),
    );
  }

  Map<String, dynamic> _getPlayerMatchStats(Map<String, dynamic> player, bool isRedTeam) {
    int goals = 0, assists = 0, ownGoals = 0, yellow = 0, red = 0;
    for (var ev in matchEvents) {
      if (ev['playerId'] == _pid(player)) {
        if (ev['type'] == 'goal') goals++;
        if (ev['type'] == 'own_goal') ownGoals++;
        if (ev['type'] == 'yellow_card') yellow++;
        if (ev['type'] == 'red_card') red++;
      }
      if (ev['assistId'] == _pid(player)) assists++;
    }
    int myScore = isRedTeam ? scoreRed : scoreWhite;
    int oppScore = isRedTeam ? scoreWhite : scoreRed;
    double resultImpact = myScore > oppScore ? 0.5 : (myScore < oppScore ? -0.5 : 0);
    double attackImpact = (goals * 0.8) + (assists * 0.4) + (ownGoals * -0.7);
    double disciplineImpact = (yellow * -0.3) + (red * -0.8);
    double defenseImpact = (oppScore * -0.15); 
    
    // --- NOVO FATOR E NOTA BASE 5.0 ---
    double matchRating = 5.0 + ((resultImpact + attackImpact + defenseImpact + disciplineImpact) * 3.0);
    return {'nota': matchRating.clamp(0.0, 10.0), 'goals': goals, 'assists': assists, 'ownGoals': ownGoals, 'yellow': yellow, 'red': red, 'ga': goals + assists};
  }

  Color _getRatingColor(double rating) {
    if (rating >= 10.0) return Colors.black;
    if (rating >= 9.0) return Colors.purpleAccent;
    if (rating >= 8.0) return Colors.green[700]!; 
    if (rating >= 7.5) return Colors.green;
    if (rating >= 7.0) return Colors.lightGreenAccent; 
    if (rating >= 6.0) return Colors.yellow;
    if (rating >= 5.0) return Colors.orange;
    return Colors.red; 
  }

  List<Widget> _buildEventIconsList(Map<String, dynamic> stats) {
    List<Widget> icons = [];
    for(int i=0; i<stats['goals']; i++) icons.add(const Text('⚽', style: TextStyle(fontSize: 11)));
    for(int i=0; i<stats['assists']; i++) icons.add(const Padding(padding: EdgeInsets.only(left:2), child: Icon(Icons.handshake, color: Colors.lightBlueAccent, size: 11)));
    for(int i=0; i<stats['ownGoals']; i++) icons.add(const Text('❌', style: TextStyle(fontSize: 10)));
    for(int i=0; i<stats['yellow']; i++) icons.add(Container(margin: const EdgeInsets.only(left:2), width: 7, height: 10, color: Colors.yellow));
    for(int i=0; i<stats['red']; i++) icons.add(Container(margin: const EdgeInsets.only(left:2), width: 7, height: 10, color: Colors.red));
    return icons;
  }

  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.deepBlue,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Configurações da Partida", style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            SwitchListTile(
              activeColor: AppColors.accentBlue,
              title: const Text("Mostrar Mini Campo Tático", style: TextStyle(color: Colors.white)),
              subtitle: const Text("Desative para ver apenas as listas de jogadores", style: TextStyle(color: Colors.white54, fontSize: 12)),
              value: _showTacticalPitch,
              onChanged: (val) async {
                setState(() => _showTacticalPitch = val);
                setModalState(() => _showTacticalPitch = val);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('show_tactical_pitch', val);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff010a3b),
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue, 
        iconTheme: const IconThemeData(color: AppColors.textWhite), 
        title: Text(widget.tournamentName, style: const TextStyle(color: AppColors.textWhite)), 
        centerTitle: true, 
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          )
        ],
      ),
      body: Column(
        children: [
          MatchScoreboard(scoreRed: scoreRed, scoreWhite: scoreWhite, timeString: _formatTime(totalSecondsElapsed), isMatchRunning: isMatchRunning, isOvertime: isOvertime, isReadyToStart: _isReadyToStart, redTeamRating: _calculateTeamRating(teamRed), whiteTeamRating: _calculateTeamRating(teamWhite), onUpdateScore: _updateScore, onStart: _startMatch, onPause: _pauseMatch, onStop: _requestStopMatch),
          _buildGoalScorers(),
          Container(color: AppColors.headerBlue, child: TabBar(controller: _tabController, labelColor: AppColors.accentBlue, unselectedLabelColor: Colors.grey, indicatorColor: AppColors.accentBlue, tabs: const [Tab(text: "CHEGADA"), Tab(text: "PARTIDA"), Tab(text: "PRÓXIMOS")])),
          Expanded(child: TabBarView(controller: _tabController, children: [_buildOrderArrivalTab(), _buildMatchTab(), _buildNextTeamsTab()])),
        ],
      ),
      floatingActionButton: _tabController.index == 0 ? FloatingActionButton(backgroundColor: AppColors.accentBlue, onPressed: _showActionSheet, child: const Icon(Icons.add, color: AppColors.textWhite)) : null,
    );
  }

  Widget _buildGoalScorers() {
    List<Widget> redScorers = []; List<Widget> whiteScorers = [];
    for (var ev in matchEvents) {
      if (ev['type'] == 'goal') {
        if (ev['team'] == 'Vermelho') redScorers.add(Text("⚽ ${ev['player']} (${ev['time']})", style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)));
        else whiteScorers.add(Text("⚽ ${ev['player']} (${ev['time']})", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)));
      } else if (ev['type'] == 'own_goal') {
        if (ev['team'] == 'Vermelho') whiteScorers.add(Text("⚽ ${ev['player']} (GC) (${ev['time']})", style: const TextStyle(color: Colors.white, fontSize: 13, fontStyle: FontStyle.italic)));
        else redScorers.add(Text("⚽ ${ev['player']} (GC) (${ev['time']})", style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontStyle: FontStyle.italic)));
      }
    }
    if (redScorers.isEmpty && whiteScorers.isEmpty) return const SizedBox.shrink();
    return Container(color: AppColors.deepBlue, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: redScorers)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: whiteScorers))]));
  }

  Widget _buildOrderArrivalTab() {
    if (presentPlayers.isEmpty) return const Center(child: Text("Lista vazia.", style: TextStyle(color: Colors.white38)));
    int total = presentPlayers.length; int times = total ~/ widget.totalPlayers; int sobram = total % widget.totalPlayers;
    String resumoText = "👥 $total Presentes | $times Times"; if (sobram > 0) resumoText += " | Restam $sobram";
    return ReorderableListView(
      padding: const EdgeInsets.all(16),
      header: Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: AppColors.accentBlue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.5))), child: Center(child: Text(resumoText, style: const TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold, fontSize: 14)))),
      onReorder: (oldIndex, newIndex) { setState(() { if (newIndex > oldIndex) newIndex -= 1; final item = presentPlayers.removeAt(oldIndex); presentPlayers.insert(newIndex, item); }); _saveMatchState(); },
      children: [
        for (int i = 0; i < presentPlayers.length; i++)
          Container(
            key: ValueKey(_pid(presentPlayers[i])), margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: AppColors.headerBlue, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
            child: ListTile(
              leading: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(backgroundColor: AppColors.deepBlue, backgroundImage: presentPlayers[i]['icon'] != null ? AssetImage(presentPlayers[i]['icon']) : null, child: presentPlayers[i]['icon'] == null ? Text(presentPlayers[i]['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null),
                  Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: AppColors.accentBlue, shape: BoxShape.circle), child: Text("${i + 1}", style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold))),
                ],
              ),
              title: Row(children: [Expanded(child: Text(presentPlayers[i]['name'], style: const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)), if (presentPlayers[i]['rating'] != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green.withValues(alpha: 0.3))), child: Text((presentPlayers[i]['rating'] as num).toDouble().toStringAsFixed(1), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)))]),
              trailing: const Icon(Icons.more_vert, color: Colors.white24), onTap: () => _showChegadaOptions(presentPlayers[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildMatchTab() {
    Map<String, Map<String, dynamic>> allStats = {}; String? motmPlayerId; double highestNota = -1; int highestGa = -1;
    void checkMotm(Map<String, dynamic> player, Map<String, dynamic> stats) {
      double n = stats['nota']; int ga = stats['ga'];
      if (n > highestNota) { highestNota = n; highestGa = ga; motmPlayerId = _pid(player); }
      else if (n == highestNota && n > 7.0) { if (ga > highestGa) { highestGa = ga; motmPlayerId = _pid(player); } }
    }
    for (var p in teamRed) { var s = _getPlayerMatchStats(p, true); allStats[_pid(p)] = s; checkMotm(p, s); }
    for (var p in teamWhite) { var s = _getPlayerMatchStats(p, false); allStats[_pid(p)] = s; checkMotm(p, s); }
    final List<Alignment> redAlignments = [const Alignment(-0.85, 0.0), const Alignment(-0.55, -0.65), const Alignment(-0.55, 0.65), const Alignment(-0.25, 0.0), const Alignment(-0.5, 0.0)];
    final List<Alignment> whiteAlignments = [const Alignment(0.85, 0.0), const Alignment(0.55, -0.65), const Alignment(0.55, 0.65), const Alignment(0.25, 0.0), const Alignment(0.5, 0.0)];

    return SingleChildScrollView(
      child: Column(
        children: [
          if (redWinStreak > 0 || whiteWinStreak > 0)
            Padding(padding: const EdgeInsets.only(top: 8.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [Text(redWinStreak > 0 ? "🔥 Sequência: $redWinStreak${winLimit > 0 ? '/$winLimit' : ''}" : "", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)), Text(whiteWinStreak > 0 ? "🔥 Sequência: $whiteWinStreak${winLimit > 0 ? '/$winLimit' : ''}" : "", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])),
          
          if (_showTacticalPitch)
            Container(
              margin: const EdgeInsets.all(12), 
              height: 330, 
              decoration: BoxDecoration(color: const Color(0xFF1B4332), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white30, width: 2)),
              child: Stack(
                children: [
                  Align(alignment: Alignment.center, child: Container(width: 2, color: Colors.white30)), Align(alignment: Alignment.center, child: Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white30, width: 2)))),
                  ...teamRed.asMap().entries.map((entry) => Align(alignment: redAlignments[entry.key % redAlignments.length], child: _buildPitchPlayer(entry.value, true, _pid(entry.value) == motmPlayerId, allStats[_pid(entry.value)]!))),
                  ...teamWhite.asMap().entries.map((entry) => Align(alignment: whiteAlignments[entry.key % whiteAlignments.length], child: _buildPitchPlayer(entry.value, false, _pid(entry.value) == motmPlayerId, allStats[_pid(entry.value)]!))),
                ],
              ),
            ),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: Colors.white10, width: 1)),
                  ),
                  child: Column(
                    children: [
                      const Padding(padding: EdgeInsets.only(top: 12.0, bottom: 8.0), child: Text("Linha Vermelho", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12))),
                      ...teamRed.map((p) => _buildPlayerListTile(p, true, allStats[_pid(p)]!)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Padding(padding: EdgeInsets.only(top: 12.0, bottom: 8.0), child: Text("Linha Branco", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
                    ...teamWhite.map((p) => _buildPlayerListTile(p, false, allStats[_pid(p)]!)),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
            child: Row(
              children: [
                Expanded(child: GestureDetector(onTap: () { if (!isMatchRunning) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Inicie a partida primeiro!"))); return; } _showGoalkeeperSelectionDialog(true, (selectedGk) => _confirmEventDialog("goal", selectedGk, true)); }, child: Container(height: 40, decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5))), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.sports_handball, color: Colors.redAccent, size: 16), SizedBox(width: 8), Text("Goleiro", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))])))),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(onTap: () { if (!isMatchRunning) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Inicie a partida primeiro!"))); return; } _showGoalkeeperSelectionDialog(false, (selectedGk) => _confirmEventDialog("goal", selectedGk, false)); }, child: Container(height: 40, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white54)), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.sports_handball, color: Colors.white, size: 16), SizedBox(width: 8), Text("Goleiro", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))])))),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPitchPlayer(Map<String, dynamic> player, bool isRed, bool isMotm, Map<String, dynamic> stats) {
    return GestureDetector(
      onTap: () { if (isMatchRunning) _showInGameOptions(player, isRed); else _showRemovePopup(player); },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none, alignment: Alignment.center,
            children: [
              CircleAvatar(radius: 20, backgroundColor: isRed ? Colors.redAccent : Colors.white, child: CircleAvatar(radius: 18, backgroundColor: AppColors.deepBlue, backgroundImage: player['icon'] != null ? AssetImage(player['icon']) : null, child: player['icon'] == null ? Text(player['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)) : null)),
              if (isMotm && stats['nota'] >= 7.0) const Positioned(top: -6, left: -6, child: Icon(Icons.star, color: Colors.amber, size: 16)),
              if (_buildEventIconsList(stats).isNotEmpty) Positioned(top: -5, right: -15, child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)), child: Row(mainAxisSize: MainAxisSize.min, children: _buildEventIconsList(stats)))),
              Positioned(bottom: -6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: _getRatingColor(stats['nota']), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.black87, width: 1)), child: Text(stats['nota'].toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)))),
            ],
          ),
          const SizedBox(height: 8),
          Text(player['name'].toString().split(' ')[0], style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, shadows: [Shadow(color: Colors.black, blurRadius: 2)])),
        ],
      ),
    );
  }

  Widget _buildPlayerListTile(Map<String, dynamic> player, bool isRed, Map<String, dynamic> matchStats) {
    double overallRating = player['rating'] != null ? (player['rating'] as num).toDouble() : 5.0; // Puxa do db ou base 5
    return InkWell(
      onTap: () { if (isMatchRunning) _showInGameOptions(player, isRed); else _showRemovePopup(player); },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4, left: 6, right: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: AppColors.headerBlue, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
        child: Row(
          children: [
            Container(width: 22, height: 22, alignment: Alignment.center, decoration: BoxDecoration(color: _getRatingColor(overallRating).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)), child: Text(overallRating.toStringAsFixed(1), style: TextStyle(color: _getRatingColor(overallRating), fontSize: 9, fontWeight: FontWeight.bold))),
            const SizedBox(width: 8),
            Expanded(child: Text(player['name'].toString().split(' ')[0], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            Row(mainAxisSize: MainAxisSize.min, children: _buildEventIconsList(matchStats)),
          ],
        ),
      ),
    );
  }

  Widget _buildNextTeamsTab() {
    final waiting = presentPlayers.where((p) { final id = _pid(p); return !teamRed.any((t) => _pid(t) == id) && !teamWhite.any((t) => _pid(t) == id); }).toList();
    if (waiting.isEmpty) return const Center(child: Text("Todos os jogadores estão jogando!", style: TextStyle(color: Colors.white38)));
    final int teamSize = widget.totalPlayers;
    return ReorderableListView(
      padding: const EdgeInsets.all(16),
      onReorder: (oldIndex, newIndex) { setState(() { if (newIndex > oldIndex) newIndex -= 1; final playerMoving = waiting[oldIndex]; presentPlayers.remove(playerMoving); int targetMainIndex; if (newIndex >= waiting.length - 1) { targetMainIndex = presentPlayers.length; } else { final playerAtTarget = waiting[newIndex]; targetMainIndex = presentPlayers.indexOf(playerAtTarget); } if (targetMainIndex > presentPlayers.length) targetMainIndex = presentPlayers.length; presentPlayers.insert(targetMainIndex, playerMoving); }); _saveMatchState(); },
      children: _buildIndividualPlayerCards(waiting, teamSize),
    );
  }

  List<Widget> _buildIndividualPlayerCards(List<Map<String, dynamic>> waiting, int teamSize) {
    final List<Widget> cards = [];
    final int numCompleteTeams = waiting.length ~/ teamSize;
    final int remainingPlayers = waiting.length % teamSize;
    for (int teamIndex = 0; teamIndex < numCompleteTeams; teamIndex++) {
      final int startIndex = teamIndex * teamSize;
      for (int i = 0; i < teamSize; i++) {
        final playerIndex = startIndex + i;
        cards.add(_buildIndividualPlayerCard(player: waiting[playerIndex], index: playerIndex, isCompleteTeam: true, isFirstPlayerInTeam: i == 0, isLastPlayerInTeam: i == teamSize - 1, teamBatch: teamIndex + 1));
      }
    }
    if (remainingPlayers > 0) {
      final int startIndex = numCompleteTeams * teamSize;
      for (int i = 0; i < remainingPlayers; i++) {
        final playerIndex = startIndex + i;
        cards.add(_buildIndividualPlayerCard(player: waiting[playerIndex], index: playerIndex, isCompleteTeam: false, isFirstPlayerInTeam: true, isLastPlayerInTeam: true, teamBatch: 0));
      }
    }
    return cards;
  }

  Widget _buildIndividualPlayerCard({required Map<String, dynamic> player, required int index, required bool isCompleteTeam, required bool isFirstPlayerInTeam, required bool isLastPlayerInTeam, required int teamBatch}) {
    final iconPath = player['icon'] as String?; final rating = player['rating'] != null ? (player['rating'] as num).toDouble() : 5.0; // Base 5
    Color teamColor = Colors.white12;
    if (isCompleteTeam) { if (teamBatch == 1) teamColor = AppColors.accentBlue; else if (teamBatch == 2) teamColor = Colors.orangeAccent; else if (teamBatch == 3) teamColor = Colors.purpleAccent; else teamColor = Colors.greenAccent; }
    final EdgeInsets margin = EdgeInsets.only(bottom: isLastPlayerInTeam ? 16 : 2);
    return Container(
      key: ValueKey(_pid(player)), margin: margin, decoration: BoxDecoration(color: AppColors.headerBlue, borderRadius: BorderRadius.vertical(top: isFirstPlayerInTeam ? const Radius.circular(12) : const Radius.circular(4), bottom: isLastPlayerInTeam ? const Radius.circular(12) : const Radius.circular(4)), border: Border.all(color: isCompleteTeam ? teamColor.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.05), width: isCompleteTeam ? 1.5 : 1)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(backgroundColor: isCompleteTeam ? teamColor.withValues(alpha: 0.2) : AppColors.deepBlue, backgroundImage: iconPath != null ? AssetImage(iconPath) : null, child: iconPath == null ? Text(player['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null),
            Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: isCompleteTeam ? teamColor : Colors.white30, shape: BoxShape.circle), child: Text("${index + 1}", style: const TextStyle(fontSize: 9, color: Colors.black, fontWeight: FontWeight.bold))),
          ],
        ),
        title: Row(children: [Expanded(child: Text(player['name'], style: TextStyle(color: isCompleteTeam ? Colors.white : Colors.white70, fontWeight: isCompleteTeam ? FontWeight.bold : FontWeight.normal), overflow: TextOverflow.ellipsis)), if (rating > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green.withValues(alpha: 0.3))), child: Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)))]),
        trailing: const Icon(Icons.drag_handle, color: Colors.white24), onTap: () => _showChegadaOptions(player),
      ),
    );
  }

  void _showChegadaOptions(Map<String, dynamic> player) {
    showModalBottomSheet(context: context, backgroundColor: AppColors.deepBlue, builder: (ctx) => Wrap(children: [ListTile(leading: const Icon(Icons.shield, color: Colors.redAccent), title: const Text("Add Vermelho", style: TextStyle(color: AppColors.textWhite)), onTap: () { Navigator.pop(ctx); _addToTeam(player, true); }), ListTile(leading: const Icon(Icons.shield, color: Colors.white), title: const Text("Add Branco", style: TextStyle(color: AppColors.textWhite)), onTap: () { Navigator.pop(ctx); _addToTeam(player, false); }), const Divider(color: Colors.white24), ListTile(leading: const Icon(Icons.exit_to_app, color: Colors.red), title: const Text("Desistiu (Remover)", style: TextStyle(color: Colors.red)), onTap: () => _confirmGiveUp(player))]));
  }

  void _showRemovePopup(Map<String, dynamic> player) {
    showDialog(context: context, builder: (c) => AlertDialog(backgroundColor: AppColors.headerBlue, title: const Text("Remover?", style: TextStyle(color: AppColors.textWhite)), content: Text("Tirar ${player['name']} do time?", style: const TextStyle(color: Colors.white70)), actions: [TextButton(child: const Text("Cancelar", style: TextStyle(color: Colors.white54)), onPressed: () => Navigator.pop(c)), TextButton(child: const Text("Remover", style: TextStyle(color: Colors.redAccent)), onPressed: () { _removePlayerFromMatch(player); Navigator.pop(c); })]));
  }

  void _confirmGiveUp(Map<String, dynamic> player) {
    showDialog(context: context, builder: (c) => AlertDialog(backgroundColor: AppColors.headerBlue, title: const Text("Desistência", style: TextStyle(color: AppColors.textWhite)), content: const Text("Vai sair da lista?", style: TextStyle(color: Colors.white70)), actions: [TextButton(child: const Text("Cancelar", style: TextStyle(color: Colors.white54)), onPressed: () => Navigator.pop(c)), TextButton(child: const Text("Confirmar", style: TextStyle(color: Colors.redAccent)), onPressed: () { setState(() { presentPlayers.removeWhere((p) => _pid(p) == _pid(player)); _removePlayerFromMatch(player); }); _saveMatchState(); Navigator.pop(c); Navigator.pop(context); })]));
  }

  void _showMultiSelectDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final String? dbData = prefs.getString('players_${widget.groupId}');
    if (dbData != null) setState(() { allSavedPlayers = List<Map<String, dynamic>>.from(jsonDecode(dbData)); });
    if (allSavedPlayers.isEmpty) { if (!mounted) return; showDialog(context: context, builder: (c) => AlertDialog(backgroundColor: AppColors.headerBlue, title: const Text("Nenhum Jogador Cadastrado", style: TextStyle(color: Colors.redAccent)), content: const Text("Você precisa cadastrar jogadores na tela 'Jogadores'.", style: TextStyle(color: Colors.white70)), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK", style: TextStyle(color: Colors.white)))])); return; }
    List<Map<String, dynamic>> tempSelected = []; String searchQuery = '';
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, st) {
          final available = allSavedPlayers.where((p) => !presentPlayers.any((present) => _pid(present) == _pid(p))).where((p) => p['name'].toString().toLowerCase().contains(searchQuery.toLowerCase())).toList();
          available.sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));
          
          return AlertDialog(
            backgroundColor: AppColors.headerBlue,
            title: const Text("Adicionar Jogadores", style: TextStyle(color: AppColors.textWhite)),
            contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.65,
              child: Column(
                children: [
                  TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Buscar nome...",
                      hintStyle: const TextStyle(color: Colors.white30),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: AppColors.deepBlue,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      st(() => searchQuery = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: available.isEmpty
                        ? const Center(child: Text("Nenhum jogador encontrado.", style: TextStyle(color: Colors.white54)))
                        : ListView.builder(
                            itemCount: available.length,
                            itemBuilder: (c, i) => CheckboxListTile(
                              activeColor: AppColors.accentBlue,
                              checkColor: AppColors.textWhite,
                              contentPadding: EdgeInsets.zero,
                              title: Text(available[i]['name'], style: const TextStyle(color: AppColors.textWhite)),
                              value: tempSelected.contains(available[i]),
                              onChanged: (v) => st(() => v! ? tempSelected.add(available[i]) : tempSelected.remove(available[i])),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancelar", style: TextStyle(color: Colors.redAccent))),
              TextButton(
                onPressed: () {
                  _addPlayersToArrivalList(tempSelected);
                  Navigator.pop(c);
                },
                child: const Text("OK", style: TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold)),
              )
            ],
          );
        },
      ),
    );
  }

  void _showActionSheet() {
    showModalBottomSheet(context: context, backgroundColor: AppColors.headerBlue, builder: (c) => Wrap(children: [ListTile(leading: const Icon(Icons.person_add, color: Colors.greenAccent), title: const Text('Adicionar', style: TextStyle(color: AppColors.textWhite)), onTap: () { Navigator.pop(c); _showMultiSelectDialog(); }), ListTile(leading: const Icon(Icons.balance, color: Colors.orangeAccent), title: const Text('Sorteio Nivelado', style: TextStyle(color: AppColors.textWhite)), onTap: () { Navigator.pop(c); _sortearTeams(); }), ListTile(leading: const Icon(Icons.delete_forever, color: Colors.redAccent), title: const Text('Limpar Tudo', style: TextStyle(color: AppColors.textWhite)), onTap: () { Navigator.pop(c); _clearList(); })]));
  }

  void _confirmEventDialog(String type, Map<String, dynamic> player, bool isRedTeam, {String? assist, String? assistId}) {
    String actionText = "";
    if (type == 'goal') {
      actionText = "⚽ GOL: ${player['name']}\n" + (assist != null ? "🤝 ASSIST: $assist" : "🏃‍♂️ (Jogada Individual)");
    } else if (type == 'own_goal') {
      actionText = "❌ GOL CONTRA: ${player['name']}";
    } else if (type == 'yellow_card') {
      actionText = "🟨 CARTÃO AMARELO: ${player['name']}";
    } else if (type == 'red_card') {
      actionText = "🟥 CARTÃO VERMELHO: ${player['name']}";
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text("Confirmar Evento?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(actionText, style: const TextStyle(color: Colors.white70, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBlue),
            onPressed: () {
              Navigator.pop(ctx);
              _registerEvent(type, player, isRedTeam, assist: assist, assistId: assistId);
            },
            child: const Text("Lançar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleGoal(Map<String, dynamic> player, bool isRedTeam) {
    List<Map<String, dynamic>> teammates = isRedTeam ? List.from(teamRed) : List.from(teamWhite);
    teammates.removeWhere((p) => _pid(p) == _pid(player));
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.headerBlue, title: const Text("Assistência", style: TextStyle(color: AppColors.highlightBlue, fontWeight: FontWeight.bold)),
        children: [
          SimpleDialogOption(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24), child: const Text("Jogada Individual", style: TextStyle(color: AppColors.textWhite, fontSize: 16)), onPressed: () { Navigator.pop(ctx); _confirmEventDialog("goal", player, isRedTeam, assist: null); }), const Divider(color: Colors.white12),
          ...teammates.map((teammate) => SimpleDialogOption(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24), child: Text(teammate['name'], style: const TextStyle(color: AppColors.textWhite, fontSize: 16)), onPressed: () { Navigator.pop(ctx); _confirmEventDialog("goal", player, isRedTeam, assist: teammate['name'], assistId: _pid(teammate)); })), const Divider(color: Colors.white12),
          SimpleDialogOption(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24), child: const Row(children: [Icon(Icons.sports_handball, color: AppColors.textWhite, size: 20), SizedBox(width: 8), Text("Goleiro", style: TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.bold))]), onPressed: () { Navigator.pop(ctx); _showGoalkeeperSelectionDialog(isRedTeam, (selectedGk) { _confirmEventDialog("goal", player, isRedTeam, assist: selectedGk['name'], assistId: _pid(selectedGk)); }); }),
        ],
      ),
    );
  }

  void _registerEvent(String type, Map<String, dynamic> player, bool isRedTeam, {String? assist, String? assistId}) async {
    try { if (type == "goal" || type == "own_goal") await _audioPlayer.play(AssetSource('audio/goal.mp3')); } catch (e) { }
    setState(() {
      if (type == "goal") { if (isRedTeam) scoreRed++; else scoreWhite++; } else if (type == "own_goal") { if (isRedTeam) scoreWhite++; else scoreRed++; }
      matchEvents.add({"type": type, "playerId": _pid(player), "player": player['name'], "assistId": assistId, "assist": assist, "team": isRedTeam ? "Vermelho" : "Branco", "time": _formatTime(totalSecondsElapsed)});
    });
    _saveMatchState();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Evento registrado!"), duration: Duration(seconds: 1)));
  }

  void _showInGameOptions(Map<String, dynamic> player, bool isRedTeam) {
    bool isLinePlayer = teamRed.any((p) => _pid(p) == _pid(player)) || teamWhite.any((p) => _pid(p) == _pid(player));
    showModalBottomSheet(
      context: context, backgroundColor: AppColors.deepBlue,
      builder: (ctx) {
        return Wrap(
          children: [
            Padding(padding: const EdgeInsets.all(16.0), child: Text("Ações para ${player['name']}", style: const TextStyle(color: Colors.grey))),
            ListTile(leading: const Icon(Icons.sports_soccer, color: Colors.greenAccent), title: const Text("Fez Gol", style: TextStyle(color: AppColors.textWhite)), onTap: () { Navigator.pop(ctx); _handleGoal(player, isRedTeam); }),
            ListTile(leading: const Icon(Icons.error_outline, color: Colors.redAccent), title: const Text("Gol Contra", style: TextStyle(color: AppColors.textWhite)), onTap: () { Navigator.pop(ctx); _confirmEventDialog("own_goal", player, isRedTeam); }),
            ListTile(leading: const Icon(Icons.style, color: Colors.yellowAccent), title: const Text("Cartão Amarelo", style: TextStyle(color: AppColors.textWhite)), onTap: () { Navigator.pop(ctx); _confirmEventDialog("yellow_card", player, isRedTeam); }),
            ListTile(leading: const Icon(Icons.style, color: Colors.redAccent), title: const Text("Cartão Vermelho", style: TextStyle(color: AppColors.textWhite)), onTap: () { Navigator.pop(ctx); _confirmEventDialog("red_card", player, isRedTeam); }),
            if (isLinePlayer) ...[const Divider(color: Colors.white24), ListTile(leading: const Icon(Icons.person_remove, color: Colors.grey), title: const Text("Substituir / Remover", style: TextStyle(color: AppColors.textWhite)), onTap: () { Navigator.pop(ctx); _showRemovePopup(player); })],
          ],
        );
      },
    );
  }

  void _finishMatch() async {
    _matchTimer?.cancel();
    final Map<String, dynamic> matchRecord = {
      "match_id": DateTime.now().millisecondsSinceEpoch.toString(), "date": DateTime.now().toIso8601String(),
      "match_duration": _formatTime(totalSecondsElapsed), "scoreRed": scoreRed, "scoreWhite": scoreWhite,
      "events": List.from(matchEvents), "players": {"red": List.from(teamRed), "white": List.from(teamWhite)},
    };

    final prefs = await SharedPreferences.getInstance();
    final String historyKey = 'match_history_${widget.tournamentId}';
    List<dynamic> history = [];
    try { if (prefs.containsKey(historyKey)) history = jsonDecode(prefs.getString(historyKey)!); } catch (e) { history = []; }
    history.add(matchRecord);
    await prefs.setString(historyKey, jsonEncode(history));

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Partida salva no Histórico!"), backgroundColor: Colors.green, duration: Duration(seconds: 2)));

    bool isTie = scoreRed == scoreWhite; bool redWon = scoreRed > scoreWhite;
    List<Map<String, dynamic>> suggestedLeavers = []; String popupTitle = ""; String popupMessage = ""; Color popupColor = AppColors.textWhite;

    if (isTie) {
      redWinStreak = 0; whiteWinStreak = 0;
      suggestedLeavers.addAll(teamRed); suggestedLeavers.addAll(teamWhite); suggestedLeavers.shuffle(Random());
      popupTitle = "Empate!"; popupMessage = "Sugestão do Sistema:\nAmbos os times saem."; popupColor = Colors.orangeAccent;
    } else {
      _playVictorySound();
      if (redWon) {
        redWinStreak++; whiteWinStreak = 0;
        if (winLimit > 0 && redWinStreak >= winLimit) { suggestedLeavers.addAll(teamRed); suggestedLeavers.addAll(teamWhite); suggestedLeavers.shuffle(Random()); redWinStreak = 0; popupTitle = "🔥 VERMELHO INVICTO!"; popupMessage = "Vermelho ganhou $winLimit seguidas!\nSugestão: TODOS saem da quadra."; popupColor = Colors.redAccent; }
        else { suggestedLeavers.addAll(teamWhite); popupTitle = "Vitória do VERMELHO!"; popupMessage = winLimit > 0 ? "Sugestão: Branco sai.\n(Sequência do Vermelho: $redWinStreak/$winLimit)" : "Sugestão: Branco sai.\n(Vitórias seguidas: $redWinStreak)"; popupColor = Colors.redAccent; }
      } else {
        whiteWinStreak++; redWinStreak = 0;
        if (winLimit > 0 && whiteWinStreak >= winLimit) { suggestedLeavers.addAll(teamRed); suggestedLeavers.addAll(teamWhite); suggestedLeavers.shuffle(Random()); whiteWinStreak = 0; popupTitle = "🔥 BRANCO INVICTO!"; popupMessage = "Branco ganhou $winLimit seguidas!\nSugestão: TODOS saem da quadra."; popupColor = Colors.white; }
        else { suggestedLeavers.addAll(teamRed); popupTitle = "Vitória do BRANCO!"; popupMessage = winLimit > 0 ? "Sugestão: Vermelho sai.\n(Sequência do Branco: $whiteWinStreak/$winLimit)" : "Sugestão: Vermelho sai.\n(Vitórias seguidas: $whiteWinStreak)"; popupColor = Colors.white; }
      }
    }

    if (!mounted) return;
    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false, 
        child: AlertDialog(
          backgroundColor: AppColors.headerBlue, title: Text(popupTitle, style: TextStyle(color: popupColor, fontSize: 22, fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.emoji_events, color: Colors.amber, size: 60), const SizedBox(height: 16), Text("Placar Final: $scoreRed x $scoreWhite", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 16), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)), child: Text(popupMessage, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center))]),
          actions: [TextButton(onPressed: () { Navigator.pop(ctx); _showManualExitDialog(); }, child: const Text("Alterar na Mão", style: TextStyle(color: Colors.white54, fontSize: 14))), TextButton(onPressed: () { Navigator.pop(ctx); _processMatchExit(suggestedLeavers); }, child: const Text("Confirmar >>", style: TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold, fontSize: 16)))],
        ),
      ),
    );
  }

  void _showManualExitDialog() {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.headerBlue, title: const Text("Intervenção Manual", style: TextStyle(color: Colors.white)), content: const Text("Quem deve sair de campo?", style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(child: const Text("Vermelho", style: TextStyle(color: Colors.redAccent)), onPressed: () { Navigator.pop(ctx); _processMatchExit(List.from(teamRed)); }),
            TextButton(child: const Text("Branco", style: TextStyle(color: Colors.white)), onPressed: () { Navigator.pop(ctx); _processMatchExit(List.from(teamWhite)); }),
            TextButton(child: const Text("Ambos", style: TextStyle(color: Colors.orangeAccent)), onPressed: () { Navigator.pop(ctx); List<Map<String, dynamic>> both = []; both.addAll(teamRed); both.addAll(teamWhite); both.shuffle(Random()); _processMatchExit(both); }),
          ],
        ),
      ),
    );
  }

  void _processMatchExit(List<Map<String, dynamic>> leavers) {
    setState(() {
      bool redIsLeaving = teamRed.any((p) => leavers.any((l) => _pid(l) == _pid(p)));
      bool whiteIsLeaving = teamWhite.any((p) => leavers.any((l) => _pid(l) == _pid(p)));
      if (redIsLeaving) redWinStreak = 0; if (whiteIsLeaving) whiteWinStreak = 0;
      
      for (var p in leavers) {
        int index = presentPlayers.indexWhere((element) => _pid(element) == _pid(p));
        if (index != -1) { var player = presentPlayers.removeAt(index); presentPlayers.add(player); }
      }

      List<Map<String, dynamic>> entering = []; int needed = leavers.length;
      for (var p in presentPlayers) {
        if (entering.length >= needed) break;
        final id = _pid(p);
        if (!teamRed.any((t) => _pid(t) == id) && !teamWhite.any((t) => _pid(t) == id)) entering.add(p);
      }

      teamRed.removeWhere((p) => leavers.any((l) => _pid(l) == _pid(p)));
      teamWhite.removeWhere((p) => leavers.any((l) => _pid(l) == _pid(p)));

      // --- MÁGICA DO BALANCEAMENTO AQUI TAMBÉM ---
      List<Map<String, dynamic>> pool = List.from(entering);
      pool.sort((a, b) => ((b['rating'] ?? 5.0) as num).compareTo((a['rating'] ?? 5.0) as num));
      
      double sumRed = teamRed.fold(0.0, (s, p) => s + ((p['rating'] ?? 5.0) as num).toDouble());
      double sumWhite = teamWhite.fold(0.0, (s, p) => s + ((p['rating'] ?? 5.0) as num).toDouble());

      for (var p in pool) {
        if (teamRed.length < widget.totalPlayers && teamWhite.length < widget.totalPlayers) {
          if (sumRed <= sumWhite) { 
            teamRed.add(p); 
            sumRed += ((p['rating'] ?? 5.0) as num).toDouble(); 
          } else { 
            teamWhite.add(p); 
            sumWhite += ((p['rating'] ?? 5.0) as num).toDouble(); 
          }
        } else if (teamRed.length < widget.totalPlayers) {
          teamRed.add(p); 
          sumRed += ((p['rating'] ?? 5.0) as num).toDouble();
        } else if (teamWhite.length < widget.totalPlayers) {
          teamWhite.add(p); 
          sumWhite += ((p['rating'] ?? 5.0) as num).toDouble();
        }
      }

      isMatchRunning = false; isOvertime = false; scoreRed = 0; scoreWhite = 0; matchEvents.clear(); _secondsPlayedBeforePause = 0; _lastStartTime = null;

      _saveMatchState();
      _showLeaversPopup(leavers, entering);
    });
  }

  void _showLeaversPopup(List<Map<String, dynamic>> leavers, List<Map<String, dynamic>> entering) {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.deepBlue, title: const Text("Saindo de Campo", style: TextStyle(color: Colors.redAccent)),
          content: SizedBox(width: double.maxFinite, child: ListView.builder(shrinkWrap: true, itemCount: leavers.length, itemBuilder: (c, i) => ListTile(dense: true, leading: const Icon(Icons.arrow_downward, color: Colors.redAccent), title: Text(leavers[i]['name'], style: const TextStyle(color: Colors.redAccent, fontSize: 16))))),
          actions: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.white24), onPressed: () { Navigator.pop(ctx); if (entering.isNotEmpty) _showEnteringPlayersPopup(entering); }, child: const Text("Ver Quem Entrou >>", style: TextStyle(color: Colors.white)))],
        ),
      ),
    );
  }

  void _playVictorySound() async {
    List<String> sounds = ['audio/vitoria1.mp3', 'audio/vitoria2.mp3', 'audio/vitoria3.mp3'];
    String randomSound = sounds[Random().nextInt(sounds.length)];
    try { await _audioPlayer.play(AssetSource(randomSound)); } catch (e) { }
  }

  void _showEnteringPlayersPopup(List<Map<String, dynamic>> entering) {
    if (entering.isEmpty) return;
    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.deepBlue, title: const Text("Entrando em Campo", style: TextStyle(color: Colors.greenAccent)),
          content: SizedBox(width: double.maxFinite, child: ListView.builder(shrinkWrap: true, itemCount: entering.length, itemBuilder: (c, i) => ListTile(dense: true, leading: const Icon(Icons.arrow_upward, color: Colors.greenAccent), title: Text(entering[i]['name'], style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold))))),
          actions: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: () => Navigator.pop(ctx), child: const Text("OK", style: TextStyle(color: Colors.white)))],
        ),
      ),
    );
  }
}
