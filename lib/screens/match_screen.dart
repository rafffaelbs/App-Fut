import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/player_identity.dart';
import '../utils/rating_calculator.dart';
import '../utils/overall_calculator.dart';
import '../utils/team_balancer.dart';
import '../utils/roster_utils.dart';
import '../utils/stats_calculator.dart';
import '../services/sync_service.dart';
import '../services/pending_match_queue.dart';
import '../services/group_bootstrap.dart';
import 'package:uuid/uuid.dart';
import '../repositories/supabase_service.dart';
import '../models/session_model.dart';
import '../models/match_lineup_model.dart';
import '../models/match_event_model.dart';

import '../widgets/match/match_scoreboard.dart';
import '../widgets/match/match_player_tile.dart';
import '../widgets/match/tactical_pitch.dart';
import '../widgets/match/match_events_panel.dart';
import '../widgets/shared/player_name_text.dart';
import '../widgets/shared/player_avatar_frame.dart';
import 'draft_screen.dart';

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
  // Player dedicado a sons locais da UI (fim de partida, vitória) -- modo de
  // baixa latência, feito pra assets locais.
  final AudioPlayer _audioPlayer = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
  // Player dedicado exclusivamente ao áudio customizado de gol (URL de rede).
  // Precisa ser uma instância separada e em PlayerMode.mediaPlayer: o modo
  // lowLatency (usado acima) não é confiável pra tocar UrlSource em Android,
  // e compartilhar uma única instância entre asset local e URL de rede é o
  // que causava os áudios "engasgando"/não tocando no mobile.
  final AudioPlayer _goalSoundPlayer = AudioPlayer()..setPlayerMode(PlayerMode.mediaPlayer);

  List<Map<String, dynamic>> allSavedPlayers = [];
  Timer? _siteSyncTimer;
  List<Map<String, dynamic>> presentPlayers = [];
  List<Map<String, dynamic>> teamRed = [];
  List<Map<String, dynamic>> teamWhite = [];

  // Guarda uma "chave" do último sorteio (times, sem levar a cor em conta)
  // pra garantir que o próximo sorteio nunca saia idêntico a ele.
  String? _lastDrawKey;

  Map<String, dynamic>? activeGkRed;
  Map<String, dynamic>? activeGkWhite;
  Map<String, dynamic>? firstGkRed;
  Map<String, dynamic>? firstGkWhite;

  int scoreRed = 0;
  int scoreWhite = 0;
  int redWinStreak = 0;
  int whiteWinStreak = 0;
  bool isMatchRunning = false;
  bool isOvertime = false;
  bool isDraftMode = false;
  int winLimit = 3;
  // Duração da partida vem da pelada (antes era 480s fixos no código).
  int matchDurationSeconds = 8 * 60;
  String streakAction = 'split';
  Timer? _matchTimer;

  int _secondsPlayedBeforePause = 0;
  DateTime? _lastStartTime;

  bool _showTacticalPitch = true;
  bool _requireGk = true;

  int get totalSecondsElapsed {
    if (!isMatchRunning || _lastStartTime == null)
      return _secondsPlayedBeforePause;
    return _secondsPlayedBeforePause +
        DateTime.now().difference(_lastStartTime!).inSeconds;
  }

  List<Map<String, dynamic>> matchEvents = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadMatchState().then((_) => _refreshSessionSettings());
    // Reenvia partidas que ficaram pendentes (ex.: sem internet na última vez).
    PendingMatchQueue.instance.flush();
  }

  @override
  void dispose() {
    _matchTimer?.cancel();
    _cloudSyncDebounce?.cancel();
    // Se ainda havia um sync do site agendado, dispara agora ao sair da tela.
    if (_siteSyncTimer?.isActive == true) {
      _siteSyncTimer!.cancel();
      _triggerBackgroundSync();
    }
    _tabController.dispose();
    _audioPlayer.dispose();
    _goalSoundPlayer.dispose();
    super.dispose();
  }

  bool get _isReadyToStart =>
      teamRed.length == widget.totalPlayers &&
      teamWhite.length == widget.totalPlayers &&
      (!_requireGk || (activeGkRed != null && activeGkWhite != null));

  String _formatTime(int totalSeconds) {
    int min = totalSeconds ~/ 60;
    int sec = totalSeconds % 60;
    return "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
  }

  /// Força média do time = média do OVERALL (0-99) dos jogadores.
  double _calculateTeamRating(List<Map<String, dynamic>> team) {
    if (team.isEmpty) return 0.0;
    double total = 0.0;
    for (var player in team) {
      total += playerOverallOf(player);
    }
    return total / team.length;
  }

  /// Converte um jogador da partida para o formato do balanceador.
  BalancePlayer _balancePlayer(Map<String, dynamic> p) =>
      BalancePlayer(_pid(p), playerOverallOf(p));

  /// Chaves do snapshot que carregam a "força" do jogador (overall + atributos
  /// da comunidade). Copiadas do snapshot do grupo para os jogadores já
  /// presentes, que podem ter sido gravados antes do overall existir.
  static const List<String> _strengthKeys = [
    'rating',
    'overall',
    'community_pac',
    'community_sho',
    'community_pas',
    'community_dri',
    'community_def',
    'community_phy',
    'community_rating_override',
  ];

  void _refreshStrengthFromSnapshot(Map<String, dynamic> p) {
    final saved = allSavedPlayers.firstWhere(
      (dbP) => _pid(dbP) == _pid(p),
      orElse: () => {},
    );
    if (saved.isEmpty) return;
    for (final k in _strengthKeys) {
      if (saved.containsKey(k) && saved[k] != null) p[k] = saved[k];
    }
    p['rating'] ??= kRatingBase;
  }

  String _pid(Map<String, dynamic> player) => playerIdFromObject(player);

  // Várias chamadas seguidas (finalizar + sair + ratings) viravam 3 rodadas
  // completas de ~15 gravações. Agora, se já há uma gravação em andamento,
  // apenas marca que precisa de mais uma (que lê o estado mais recente).
  bool _savingState = false;
  bool _saveStateQueued = false;

  Future<void> _saveMatchState() async {
    if (_savingState) {
      _saveStateQueued = true;
      return;
    }
    _savingState = true;
    try {
      do {
        _saveStateQueued = false;
        await _writeMatchState();
      } while (_saveStateQueued);
    } finally {
      _savingState = false;
    }
  }

  Future<void> _writeMatchState() async {
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

    if (activeGkRed != null) await prefs.setString('active_gk_red_$id', jsonEncode(activeGkRed));
    else await prefs.remove('active_gk_red_$id');
    if (activeGkWhite != null) await prefs.setString('active_gk_white_$id', jsonEncode(activeGkWhite));
    else await prefs.remove('active_gk_white_$id');
    if (firstGkRed != null) await prefs.setString('first_gk_red_$id', jsonEncode(firstGkRed));
    else await prefs.remove('first_gk_red_$id');
    if (firstGkWhite != null) await prefs.setString('first_gk_white_$id', jsonEncode(firstGkWhite));
    else await prefs.remove('first_gk_white_$id');

    _scheduleCloudSync();
  }

  Timer? _cloudSyncDebounce;

  /// Agenda um envio pro Supabase da presença/placar/cronômetro atuais,
  /// com debounce -- várias chamadas seguidas (arrastar jogador, tick do
  /// timer, gol) resultam em um único request depois que as mudanças
  /// pararem por um instante, em vez de martelar a rede a cada setState.
  void _scheduleCloudSync() {
    if (widget.groupId.isEmpty) return;
    _cloudSyncDebounce?.cancel();
    _cloudSyncDebounce = Timer(const Duration(seconds: 5), _syncToCloud);
  }

  /// Envia o estado "rascunho" da pelada (quem chegou, times, goleiros,
  /// placar, cronômetro) pro Supabase, pra sobreviver a troca de
  /// aparelho/reinstalação antes de "Encerrar Partida". Falha
  /// silenciosamente (fica só local) se estiver offline -- o cache local
  /// via SharedPreferences continua sendo a fonte imediata de verdade.
  bool _cloudSyncInFlight = false;

  Future<void> _syncToCloud() async {
    if (widget.groupId.isEmpty || presentPlayers.isEmpty) return;
    // Rede lenta: nunca empilha um sync em cima do outro.
    if (_cloudSyncInFlight) {
      _scheduleCloudSync();
      return;
    }
    _cloudSyncInFlight = true;
    try {
      final redIds = teamRed.map((p) => _pid(p)).toSet();
      final whiteIds = teamWhite.map((p) => _pid(p)).toSet();
      final gkRedId = activeGkRed != null ? _pid(activeGkRed!) : null;
      final gkWhiteId = activeGkWhite != null ? _pid(activeGkWhite!) : null;

      final draft = presentPlayers.map((p) {
        final pid = _pid(p);
        String? team;
        if (redIds.contains(pid)) team = 'red';
        if (whiteIds.contains(pid)) team = 'white';
        return {
          'id': pid,
          'desistiu': p['desistiu'] == true,
          if (team != null) 'team': team,
          if (pid == gkRedId || pid == gkWhiteId) 'is_goalkeeper': true,
        };
      }).toList();

      await SupabaseService.instance.sessionArrivals
          .replaceArrivals(widget.tournamentId, draft)
          .timeout(const Duration(seconds: 10));

      await SupabaseService.instance.sessions.updateRuntimeState(
        widget.tournamentId,
        isRunning: isMatchRunning,
        secondsPlayed: _secondsPlayedBeforePause,
        scoreRed: scoreRed,
        scoreWhite: scoreWhite,
        redStreak: redWinStreak,
        whiteStreak: whiteWinStreak,
        isOvertime: isOvertime,
        startedAt: _lastStartTime,
        status: SessionModel.statusInProgress,
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error syncing session draft to Supabase: $e');
    } finally {
      _cloudSyncInFlight = false;
    }
  }

  Future<void> _loadMatchState() async {
    final prefs = await SharedPreferences.getInstance();
    final String id = widget.tournamentId;

    _showTacticalPitch = prefs.getBool('show_tactical_pitch') ?? true;
    _requireGk = prefs.getBool('require_gk') ?? true;

    final String? dbData = prefs.getString('players_${widget.groupId}');
    if (dbData != null) {
      allSavedPlayers = ensurePlayerIds(
        List<Map<String, dynamic>>.from(jsonDecode(dbData)),
      );
    }
    if (widget.groupId.isNotEmpty) {
      // Estratégia offline-first: elenco + notas vêm do snapshot gravado na
      // entrada do grupo (GroupBootstrap). Abrir a pelada não depende de
      // rede. As notas ficam fixas durante toda a pelada.
      final bool hasSnapshot = await GroupBootstrap.hasLocalSnapshot(widget.groupId);
      if (!hasSnapshot) {
        // Primeira vez neste aparelho: única situação em que esperamos a rede.
        await GroupBootstrap.instance.prefetch(widget.groupId, force: true);
      } else {
        // Já temos tudo localmente; só renova em segundo plano pra próxima.
        unawaited(GroupBootstrap.instance.prefetch(widget.groupId));
      }
      final String? snap = prefs.getString('players_${widget.groupId}');
      if (snap != null) {
        allSavedPlayers = ensurePlayerIds(
          List<Map<String, dynamic>>.from(jsonDecode(snap)),
        );
        for (final p in allSavedPlayers) {
          p['rating'] ??= kRatingBase;
        }
      }
    }

    // Se não existe nada localmente (app reinstalado, storage limpo, ou
    // pelada aberta em outro aparelho), tenta recuperar o "rascunho" salvo
    // no Supabase (session_arrivals + colunas de runtime da session) antes
    // de cair pra listas vazias.
    if (!prefs.containsKey('present_players_$id') && widget.groupId.isNotEmpty) {
      try {
        final arrivals = await SupabaseService.instance.sessionArrivals
            .getArrivals(id);
        if (arrivals.isNotEmpty) {
          Map<String, dynamic> hydrate(Map<String, dynamic> arrival) {
            final pid = arrival['player_id']?.toString() ?? '';
            final base = allSavedPlayers.firstWhere(
              (p) => _pid(p) == pid,
              orElse: () => {'id': pid, 'name': pid},
            );
            final player = Map<String, dynamic>.from(base);
            if (arrival['desistiu'] == true) player['desistiu'] = true;
            return player;
          }

          final recoveredPresent = arrivals.map(hydrate).toList();
          final recoveredRed = arrivals
              .where((a) => a['team'] == 'red')
              .map(hydrate)
              .toList();
          final recoveredWhite = arrivals
              .where((a) => a['team'] == 'white')
              .map(hydrate)
              .toList();

          await prefs.setString(
              'present_players_$id', jsonEncode(recoveredPresent));
          await prefs.setString('team_red_$id', jsonEncode(recoveredRed));
          await prefs.setString('team_white_$id', jsonEncode(recoveredWhite));

          // As colunas de runtime (score/timer/streak) não fazem parte do
          // SessionModel, então busca direto pra não perder esse estado.
          try {
            final raw = await SupabaseService.instance.client
                .from('sessions')
                .select(
                    'seconds_played,is_running,score_red,score_white,red_streak,white_streak,is_overtime,started_at')
                .eq('id', id)
                .maybeSingle();
            if (raw != null) {
              await prefs.setInt(
                  'seconds_played_$id', (raw['seconds_played'] as num?)?.toInt() ?? 0);
              await prefs.setBool('is_running_$id', false);
              await prefs.setInt(
                  'score_red_$id', (raw['score_red'] as num?)?.toInt() ?? 0);
              await prefs.setInt('score_white_$id',
                  (raw['score_white'] as num?)?.toInt() ?? 0);
              await prefs.setInt(
                  'red_streak_$id', (raw['red_streak'] as num?)?.toInt() ?? 0);
              await prefs.setInt('white_streak_$id',
                  (raw['white_streak'] as num?)?.toInt() ?? 0);
              await prefs.setBool(
                  'is_overtime_$id', raw['is_overtime'] == true);
              // O cronômetro nunca volta rodando automaticamente após uma
              // recuperação -- o usuário aperta o play de novo, evitando
              // um `_lastStartTime` de outro aparelho/sessão desatualizado.
              await prefs.remove('start_timestamp_$id');
            }
          } catch (e) {
            debugPrint('Error recovering session runtime state: $e');
          }
        }
      } catch (e) {
        debugPrint('Error recovering session draft from Supabase: $e');
      }
    }

    if (!mounted) return; // usuário já saiu da tela enquanto isso carregava
    // Configurações da pelada (limite de vitórias, duração...) do cache local.
    final SessionModel? cachedSession =
        await SupabaseService.instance.sessions.getCachedSession(widget.tournamentId);
    if (!mounted) return;
    setState(() {
      if (prefs.containsKey('present_players_$id'))
        presentPlayers = ensurePlayerIds(
          List<Map<String, dynamic>>.from(
            jsonDecode(prefs.getString('present_players_$id')!),
          ),
        );
      if (prefs.containsKey('team_red_$id'))
        teamRed = ensurePlayerIds(
          List<Map<String, dynamic>>.from(
            jsonDecode(prefs.getString('team_red_$id')!),
          ),
        );
      if (prefs.containsKey('team_white_$id'))
        teamWhite = ensurePlayerIds(
          List<Map<String, dynamic>>.from(
            jsonDecode(prefs.getString('team_white_$id')!),
          ),
        );
      if (prefs.containsKey('match_events_$id'))
        matchEvents = List<Map<String, dynamic>>.from(
          jsonDecode(prefs.getString('match_events_$id')!),
        );

      int sessionWinLimit = 3;
      final sessionsData = prefs.getString('sessions_${widget.groupId}');
      if (sessionsData != null) {
        // Legado: só vale se não houver nada melhor (cache/Supabase abaixo).
        final List<dynamic> allSessions = jsonDecode(sessionsData);
        final currentSession = allSessions.firstWhere(
          (s) => s['id'] == widget.tournamentId,
          orElse: () => null,
        );
        if (currentSession != null && currentSession is Map) {
          if (currentSession.containsKey('win_limit')) {
            sessionWinLimit = currentSession['win_limit'];
          }
          if (currentSession.containsKey('draft_mode')) {
            isDraftMode = currentSession['draft_mode'];
          }
          if (currentSession.containsKey('streak_action')) {
            streakAction = currentSession['streak_action'];
          }
        }
      }
      winLimit = sessionWinLimit;
      if (cachedSession != null) _applySessionSettings(cachedSession);

      void syncRatings(List<Map<String, dynamic>> list) {
        for (var p in list) {
          _refreshStrengthFromSnapshot(p);
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

      if (prefs.containsKey('active_gk_red_$id')) activeGkRed = Map<String, dynamic>.from(jsonDecode(prefs.getString('active_gk_red_$id')!));
      if (prefs.containsKey('active_gk_white_$id')) activeGkWhite = Map<String, dynamic>.from(jsonDecode(prefs.getString('active_gk_white_$id')!));
      if (prefs.containsKey('first_gk_red_$id')) firstGkRed = Map<String, dynamic>.from(jsonDecode(prefs.getString('first_gk_red_$id')!));
      if (prefs.containsKey('first_gk_white_$id')) firstGkWhite = Map<String, dynamic>.from(jsonDecode(prefs.getString('first_gk_white_$id')!));

      if (activeGkRed != null) _refreshStrengthFromSnapshot(activeGkRed!);
      if (activeGkWhite != null) _refreshStrengthFromSnapshot(activeGkWhite!);

      if (isMatchRunning && _lastStartTime != null) {
        _matchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            if (totalSecondsElapsed >= matchDurationSeconds && !isOvertime) {
              isOvertime = true;
              try {
                _audioPlayer.play(AssetSource('audio/end.mp3'));
              } catch (e) {}
            }
          });
        });
      }
    });
  }

  /// Aplica limite de vitórias, duração, modo de sorteio e ação de sequência
  /// da pelada. Usado ao abrir (cache) e quando o Supabase responde.
  void _applySessionSettings(SessionModel s) {
    winLimit = s.winLimit ?? 0; // null = sem limite
    matchDurationSeconds = (s.durationMinutes ?? 8) * 60;
    streakAction = s.streakAction;
    isDraftMode = s.draftMode;
  }

  /// Em segundo plano, confere se a pelada foi editada (ex.: de 8 pra 7 min,
  /// de 3 pra 2 vitórias) e aplica sem precisar recriar a pelada.
  Future<void> _refreshSessionSettings() async {
    try {
      final fresh =
          await SupabaseService.instance.sessions.getSessionById(widget.tournamentId);
      if (fresh == null || !mounted) return;
      setState(() => _applySessionSettings(fresh));
    } catch (e) {
      debugPrint('Error refreshing session settings: $e');
    }
  }

  bool _disbalanceWarned = false;

  void _startMatch() async {
    // Bola rolando = bom momento pra subir súmulas pendentes em segundo plano.
    PendingMatchQueue.instance.flush();
    if (isMatchRunning) return;
    if (_requireGk && (activeGkRed == null || activeGkWhite == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Os times precisam de goleiros para iniciar a partida"),
        ),
      );
      return;
    }

    if (totalSecondsElapsed == 0 && !_disbalanceWarned) {
      final rRed = _calculateTeamRating(teamRed);
      final rWhite = _calculateTeamRating(teamWhite);
      if ((rRed - rWhite).abs() >= 3.5) {
        _checkAndWarnTeamDisbalance(onProceed: _doStartMatch);
        return;
      }
    }
    _doStartMatch();
  }

  void _doStartMatch() async {
    if (isMatchRunning) return;
    setState(() {
      isMatchRunning = true;
      _lastStartTime = DateTime.now();
    });
    try {
      await _audioPlayer.play(AssetSource('audio/end.mp3'));
    } catch (e) {}
    _saveMatchState();
    _matchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (totalSecondsElapsed >= matchDurationSeconds && !isOvertime) {
          isOvertime = true;
          try {
            _audioPlayer.play(AssetSource('audio/end.mp3'));
          } catch (e) {}
        }
      });
    });
  }

  /// Alerta caso a diferença de força entre os times seja >= 3.5 pontos de Overall.
  /// Oferece a opção de misturar e equilibrar os dois times na hora.
  void _checkAndWarnTeamDisbalance({VoidCallback? onProceed}) {
    if (teamRed.isEmpty || teamWhite.isEmpty || !mounted) {
      onProceed?.call();
      return;
    }
    final rRed = _calculateTeamRating(teamRed);
    final rWhite = _calculateTeamRating(teamWhite);
    final diff = (rRed - rWhite).abs();

    if (diff < 3.5 || _disbalanceWarned) {
      onProceed?.call();
      return;
    }

    _disbalanceWarned = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "Times Desbalanceados",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "A diferença de força entre os times é muito grande: ${diff.toStringAsFixed(1)} pontos (${rRed.toStringAsFixed(1)} vs ${rWhite.toStringAsFixed(1)}).",
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              "Você gostaria de misturar os times para equilibrar a partida?",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onProceed?.call();
            },
            child: const Text("Não, manter assim", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.shuffle_rounded, size: 18),
            label: const Text("Sim, misturar times", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              _rebalanceCurrentTeams();
              onProceed?.call();
            },
          ),
        ],
      ),
    );
  }

  /// Mistura e rebalanceia os times atuais em campo usando o TeamBalancer.
  void _rebalanceCurrentTeams() {
    final pool = [...teamRed, ...teamWhite];
    if (pool.length < 2) return;
    final byId = {for (final p in pool) _pid(p): p};
    final balancePool = pool.map(_balancePlayer).toList();
    final suggestions = TeamBalancer.suggest(
      balancePool,
      count: 1,
      tolerance: 1.0,
      excludeKeys: _lastDrawKey == null ? <String>{} : {_lastDrawKey!},
    );
    if (suggestions.isNotEmpty) {
      _applySplit(suggestions.first, byId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Times misturados e equilibrados com sucesso!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
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
          "Deseja pausar e revisar a Súmula da partida?",
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
              _pauseMatch();
              _showMatchSummary();
            },
            child: const Text(
              "Ver Súmula",
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

  void _editAssistInSummary(int eventIndex, StateSetter setSummaryState) {
    final ev = matchEvents[eventIndex];
    bool isRedTeam = ev['team'] == 'Vermelho';
    List<Map<String, dynamic>> teammates = isRedTeam
        ? List.from(teamRed)
        : List.from(teamWhite);

    teammates.removeWhere((p) => _pid(p) == ev['playerId']);

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text(
          "Editar Assistência",
          style: TextStyle(
            color: AppColors.highlightBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          SimpleDialogOption(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: const Text(
              "Jogada Individual (Remover Assist.)",
              style: TextStyle(color: Colors.redAccent, fontSize: 16),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                matchEvents[eventIndex]['assist'] = null;
                matchEvents[eventIndex]['assistId'] = null;
              });
              _saveMatchState();
              setSummaryState(() {});
            },
          ),
          const Divider(color: Colors.white12),
          ...teammates.map(
            (teammate) => SimpleDialogOption(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              child: PlayerNameText(
                name: teammate['name'].toString(),
                nameEffect: teammate['name_effect']?.toString(),
                style: const TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 16,
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  matchEvents[eventIndex]['assist'] = teammate['name'];
                  matchEvents[eventIndex]['assistId'] = _pid(teammate);
                });
                _saveMatchState();
                setSummaryState(() {});
              },
            ),
          ),
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
              Navigator.pop(ctx);
              _showGoalkeeperSelectionDialog(isRedTeam, (selectedGk) {
                setState(() {
                  matchEvents[eventIndex]['assist'] = selectedGk['name'];
                  matchEvents[eventIndex]['assistId'] = _pid(selectedGk);
                });
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
                  const Text(
                    "Súmula",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "$scoreRed x $scoreWhite",
                    style: const TextStyle(
                      color: AppColors.accentBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.5,
                child: matchEvents.isEmpty
                    ? const Center(
                        child: Text(
                          "Nenhum evento registrado.",
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: matchEvents.length,
                        itemBuilder: (c, i) {
                          final ev = matchEvents[i];
                          IconData icon = Icons.circle;
                          Color iconColor = Colors.grey;
                          if (ev['type'] == 'goal') {
                            icon = Icons.sports_soccer;
                            iconColor = Colors.greenAccent;
                          } else if (ev['type'] == 'own_goal') {
                            icon = Icons.error_outline;
                            iconColor = Colors.redAccent;
                          } else if (ev['type'] == 'yellow_card') {
                            icon = Icons.style;
                            iconColor = Colors.yellow;
                          } else if (ev['type'] == 'red_card') {
                            icon = Icons.style;
                            iconColor = Colors.red;
                          }

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: Icon(icon, color: iconColor, size: 20),
                            title: Text(
                              "${ev['player']} (${ev['team']})",
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              ev['type'] == 'goal'
                                  ? (ev['assist'] != null
                                        ? "Assist: ${ev['assist']}"
                                        : "Individual")
                                  : "",
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (ev['type'] == 'goal')
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.amber,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _editAssistInSummary(i, setDialogState),
                                  ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      var removed = matchEvents.removeAt(i);
                                      bool isRed =
                                          removed['team'] == 'Vermelho';
                                      if (removed['type'] == 'goal') {
                                        if (isRed)
                                          scoreRed = max(0, scoreRed - 1);
                                        else
                                          scoreWhite = max(0, scoreWhite - 1);
                                      } else if (removed['type'] ==
                                          'own_goal') {
                                        if (isRed)
                                          scoreWhite = max(0, scoreWhite - 1);
                                        else
                                          scoreRed = max(0, scoreRed - 1);
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
                  child: const Text(
                    "Voltar ao Jogo",
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _finishMatch();
                  },
                  child: const Text(
                    "Encerrar Partida",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
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

  void _showSorteioOptionsDialog() {
    final int n = widget.totalPlayers * 2;
    final int ativos = activePlayers(presentPlayers).length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text(
          'Sorteio Nivelado',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.people, color: Colors.orangeAccent),
              title: const Text(
                'Sortear todos os jogadores',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                ativos > n
                    ? 'Sorteia $n entre os $ativos presentes (quem desistiu fica de fora) e monta times equilibrados pelo Overall'
                    : 'Distribui os $ativos jogadores (sem os desistentes) em dois times equilibrados pelo Overall',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _sortearTeams(useAllPlayers: true);
              },
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.filter_list, color: Colors.greenAccent),
              title: Text(
                'Sortear os $n primeiros',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Apenas os $n primeiros da chegada serão sorteados (${widget.totalPlayers} por time)',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _sortearTeams(useAllPlayers: false);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  /// Quem entra no sorteio. Desistentes NUNCA entram (um único ponto de
  /// verdade: [activePlayers]).
  List<Map<String, dynamic>> _drawPool({required bool useAllPlayers}) {
    final eligible = activePlayers(presentPlayers);
    final int needed = widget.totalPlayers * 2;
    if (useAllPlayers) {
      final shuffled = List<Map<String, dynamic>>.from(eligible)
        ..shuffle(Random());
      return shuffled.take(needed).toList();
    }
    // Ordem de chegada, sem embaralhar.
    return eligible.take(needed).toList();
  }

  void _sortearTeams({bool useAllPlayers = false}) {
    if (activePlayers(presentPlayers).length < 2) return;
    final pool = _drawPool(useAllPlayers: useAllPlayers);
    if (pool.length < 2) return;
    _showSplitSuggestions(pool);
  }

  /// O balanceador analisa TODAS as divisões possíveis do grupo (até 20
  /// jogadores) e o app oferece 3 sugestões quase igualmente equilibradas
  /// (nunca igual ao último sorteio). Quem decide é o organizador.
  void _showSplitSuggestions(List<Map<String, dynamic>> pool) {
    final byId = {for (final p in pool) _pid(p): p};
    final balancePool = pool.map(_balancePlayer).toList();
    List<SplitResult> suggestions = [];

    void generate() {
      suggestions = TeamBalancer.suggest(
        balancePool,
        count: 3,
        tolerance: 1.0,
        excludeKeys: _lastDrawKey == null ? <String>{} : {_lastDrawKey!},
      );
    }

    generate();
    if (suggestions.isEmpty) return;

    String firstNames(List<BalancePlayer> l) => l
        .map((bp) {
          final p = byId[bp.id]!;
          final first = p['name'].toString().split(' ')[0];
          return '$first ${bp.rating.round()}';
        })
        .join(' · ');

    String quality(double diff) {
      if (diff <= 1.0) return 'Super equilibrado';
      if (diff <= 2.5) return 'Equilibrado';
      return 'Mais ou menos';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AppColors.headerBlue,
          title: const Text(
            'Sugestões de times',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (c, i) {
                final s = suggestions[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.deepBlue,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Opção ${i + 1} · ${quality(s.diff)} (dif. ${s.diff.toStringAsFixed(1)})',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '🔴 Vermelho ${s.meanA.toStringAsFixed(1)}  (${s.eliteA} elite${s.eliteA == 1 ? '' : 's'})',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        firstNames(s.a),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '⚪ Branco ${s.meanB.toStringAsFixed(1)}  (${s.eliteB} elite${s.eliteB == 1 ? '' : 's'})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        firstNames(s.b),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _applySplit(s, byId);
                          },
                          child: const Text('Usar esta'),
                        ),
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
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () => setSt(generate),
              child: const Text('Outras opções'),
            ),
          ],
        ),
      ),
    );
  }

  void _applySplit(SplitResult split, Map<String, Map<String, dynamic>> byId) {
    final red = [for (final bp in split.a) if (byId[bp.id] != null) byId[bp.id]!];
    final white = [for (final bp in split.b) if (byId[bp.id] != null) byId[bp.id]!];
    setState(() {
      teamRed
        ..clear()
        ..addAll(red);
      teamWhite
        ..clear()
        ..addAll(white);
      _lastDrawKey = _splitKey(teamRed, teamWhite);
    });
    _saveMatchState();
  }

  /// Completa as vagas dos dois times com [entering] escolhendo a combinação
  /// mais equilibrada por Overall (considerando quem já está em campo).
  void _fillTeamsBalanced(List<Map<String, dynamic>> entering) {
    final byId = {for (final p in entering) _pid(p): p};
    final res = TeamBalancer.fill(
      stayersA: teamRed.map(_balancePlayer).toList(),
      stayersB: teamWhite.map(_balancePlayer).toList(),
      entering: entering.map(_balancePlayer).toList(),
      capA: max(0, widget.totalPlayers - teamRed.length),
      capB: max(0, widget.totalPlayers - teamWhite.length),
    );
    for (final bp in res.toA) {
      final p = byId[bp.id];
      if (p != null) teamRed.add(p);
    }
    for (final bp in res.toB) {
      final p = byId[bp.id];
      if (p != null) teamWhite.add(p);
    }
  }

  /// Chave única de uma divisão de times, ignorando qual lado é vermelho ou
  /// branco -- duas divisões com os mesmos jogadores só de lado trocado
  /// geram a mesma chave (contam como repetição). Mesmo formato de
  /// [SplitResult.key].
  String _splitKey(List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    final keyA = (a.map(_pid).toList()..sort()).join(',');
    final keyB = (b.map(_pid).toList()..sort()).join(',');
    return keyA.compareTo(keyB) <= 0 ? '$keyA|$keyB' : '$keyB|$keyA';
  }

  void _iniciarTimesDraft() async {
    final eligible = activePlayers(presentPlayers);
    if (eligible.length < 2) return;

    final List<List<Map<String, dynamic>>>? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DraftScreen(
          presentPlayers: List<Map<String, dynamic>>.from(eligible),
          playersPerTeam: widget.totalPlayers,
        ),
      ),
    );

    if (result == null || result.isEmpty) return;

    setState(() {
      teamRed = result.isNotEmpty
          ? List<Map<String, dynamic>>.from(result[0])
          : [];
      teamWhite = result.length > 1
          ? List<Map<String, dynamic>>.from(result[1])
          : [];
    });
    _saveMatchState();
  }

  void _addToTeam(Map<String, dynamic> player, bool isRedTeam) {
    if (player['desistiu'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${player['name']} desistiu e não pode ser escalado.")),
      );
      return;
    }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("O time já está cheio!")));
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
      for (var p in selected)
        if (!presentPlayers.any((e) => _pid(e) == _pid(p)))
          presentPlayers.add(p);
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
      activeGkRed = null;
      activeGkWhite = null;
      firstGkRed = null;
      firstGkWhite = null;
    });
    _saveMatchState();
  }

  void _showGoalkeeperSelectionDialog(
    bool isRedTeam,
    Function(Map<String, dynamic>) onSelected,
  ) {
    final otherGk = isRedTeam ? activeGkWhite : activeGkRed;
    final otherGkId = otherGk != null ? _pid(otherGk) : null;
    final waiting = waitingPlayers(presentPlayers, teamRed, teamWhite, _pid)
        .where((p) => _pid(p) != otherGkId)
        .toList();
    if (waiting.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Não há outros jogadores disponíveis para selecionar como goleiro!",
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

  Map<String, dynamic> _getPlayerMatchStats(
    Map<String, dynamic> player,
    bool isRedTeam,
  ) {
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

    // Status para usar na matemática central
    int status = myScore > oppScore ? 1 : (myScore < oppScore ? -1 : 0);
    int streak = isRedTeam ? redWinStreak : whiteWinStreak;

    // Gol da virada / gol decisivo do fim de jogo -- derivados dos
    // próprios eventos da partida (minuto + placar), sem pedir nada novo.
    final specialGoals = findSpecialGoals(matchEvents);
    final bool scoredComeback = specialGoals.comebackGoalIndex != -1 &&
        matchEvents[specialGoals.comebackGoalIndex]['playerId'] == _pid(player);
    final bool scoredClutch = specialGoals.clutchGoalIndex != -1 &&
        matchEvents[specialGoals.clutchGoalIndex]['playerId'] == _pid(player);

    // USANDO O RATING CALCULATOR AQUI!
    double matchRating = calculateMatchRating(
      status: status,
      goals: goals,
      assists: assists,
      ownGoals: ownGoals,
      teamGoals: myScore,
      conceded: oppScore,
      yellow: yellow,
      red: red,
      teamWinStreak: streak,
      scoredComebackGoal: scoredComeback,
      scoredClutchGoal: scoredClutch,
    );

    return {
      'nota': matchRating.clamp(0.0, 10.0),
      'goals': goals,
      'assists': assists,
      'ownGoals': ownGoals,
      'yellow': yellow,
      'red': red,
      'ga': goals + assists,
    };
  }

  List<Widget> _buildEventIconsList(Map<String, dynamic> stats) {
    List<Widget> icons = [];
    for (int i = 0; i < stats['goals']; i++)
      icons.add(const Text('⚽', style: TextStyle(fontSize: 11)));
    for (int i = 0; i < stats['assists']; i++)
      icons.add(
        const Padding(
          padding: EdgeInsets.only(left: 2),
          child: Icon(Icons.handshake, color: Colors.lightBlueAccent, size: 11),
        ),
      );
    for (int i = 0; i < stats['ownGoals']; i++)
      icons.add(const Text('❌', style: TextStyle(fontSize: 10)));
    for (int i = 0; i < stats['yellow']; i++)
      icons.add(
        Container(
          margin: const EdgeInsets.only(left: 2),
          width: 7,
          height: 10,
          color: Colors.yellow,
        ),
      );
    for (int i = 0; i < stats['red']; i++)
      icons.add(
        Container(
          margin: const EdgeInsets.only(left: 2),
          width: 7,
          height: 10,
          color: Colors.red,
        ),
      );
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
              child: Text(
                "Configurações da Partida",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SwitchListTile(
              activeColor: AppColors.accentBlue,
              title: const Text(
                "Campo tático ou lista",
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                "Ligado: campo tático com cards. Desligado: lista de jogadores",
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              value: _showTacticalPitch,
              onChanged: (val) async {
                await _setShowTacticalPitch(val);
                setModalState(() => _showTacticalPitch = val);
              },
            ),
            SwitchListTile(
              activeColor: AppColors.accentBlue,
              title: const Text(
                "Obrigatório ter goleiro para começar",
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                "Exige que ambos os times tenham goleiros definidos",
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              value: _requireGk,
              onChanged: (val) async {
                setState(() => _requireGk = val);
                setModalState(() => _requireGk = val);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('require_gk', val);
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
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
        title: Text(
          widget.tournamentName,
          style: const TextStyle(
            color: AppColors.textWhite,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: PendingMatchQueue.instance.pending,
            builder: (context, count, _) {
              if (count == 0) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Aguardando envio: $count',
                icon: Badge(
                  label: Text('$count'),
                  child: const Icon(Icons.cloud_upload_outlined),
                ),
                onPressed: _showPendingSyncDialog,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
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
            decoration: const BoxDecoration(
              color: AppColors.headerBlue,
              border: Border(
                bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.textWhite,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.accentBlue,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.8,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.8,
              ),
              tabs: const [
                Tab(text: "CHEGADA"),
                Tab(text: "PARTIDA"),
                Tab(text: "PRÓXIMOS"),
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

  Widget _buildGoalScorers() {
    List<Widget> redScorers = [];
    List<Widget> whiteScorers = [];
    for (var ev in matchEvents) {
      if (ev['type'] == 'goal') {
        if (ev['team'] == 'Vermelho')
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
        else
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
      } else if (ev['type'] == 'own_goal') {
        if (ev['team'] == 'Vermelho')
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
        else
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
    if (redScorers.isEmpty && whiteScorers.isEmpty)
      return const SizedBox.shrink();
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.headerBlue,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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

  Widget _buildOrderArrivalTab() {
    if (presentPlayers.isEmpty)
      return const Center(
        child: Text("Lista vazia.", style: TextStyle(color: AppColors.textMuted)),
      );
    final activePlayers =
        presentPlayers.where((p) => p['desistiu'] != true).toList();
    final desistPlayers =
        presentPlayers.where((p) => p['desistiu'] == true).toList();
    final displayList = [...activePlayers, ...desistPlayers];
    int total = activePlayers.length;
    int times = total ~/ widget.totalPlayers;
    int sobram = total % widget.totalPlayers;
    String resumoText = "👥 $total Presentes | $times Times";
    if (sobram > 0) resumoText += " | Restam $sobram";
    return ReorderableListView(
      padding: const EdgeInsets.all(16),
      header: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Center(
          child: Text(
            resumoText,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          // Jogadores que desistiram ficam fixos na seção final;
          // arrastar não se aplica a eles.
          if (oldIndex >= activePlayers.length) return;
          if (newIndex >= activePlayers.length) {
            newIndex = activePlayers.length - 1;
          }
          final item = activePlayers.removeAt(oldIndex);
          activePlayers.insert(newIndex, item);
          presentPlayers = [...activePlayers, ...desistPlayers];
        });
        _saveMatchState();
      },
      children: [
        for (int i = 0, activeCount = 0; i < displayList.length; i++)
          Builder(
            key: ValueKey(_pid(displayList[i])), // ✅ Mova a key para o filho direto (Builder)
            builder: (context) {
            final bool desistiu = displayList[i]['desistiu'] == true;
            final bool isFirstDesistente =
                desistiu && i == activePlayers.length;
            if (!desistiu) activeCount++;
            final int displayOrder = activeCount;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isFirstDesistente)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 4),
                    child: Row(
                      children: [
                        const Expanded(child: Divider(color: Colors.white24)),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            "DESISTIRAM (${desistPlayers.length})",
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: Colors.white24)),
                      ],
                    ),
                  ),
                Opacity(
              opacity: desistiu ? 0.45 : 1.0,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.headerBlue,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                child: Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomRight,
                    children: [
                      PlayerAvatarFrame(
                        frame: resolvePlayerFrame(displayList[i]),
                        compact: true,
                        isCircular: true,
                        child: CircleAvatar(
                          backgroundColor: AppColors.deepBlue,
                          backgroundImage: displayList[i]['icon'] != null
                              ? AssetImage(displayList[i]['icon'])
                              : null,
                          child: displayList[i]['icon'] == null
                              ? Text(
                                  displayList[i]['name'][0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      if (!desistiu)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.accentBlue,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              "$displayOrder",
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: PlayerNameText(
                          name: displayList[i]['name'].toString(),
                          nameEffect: displayList[i]['name_effect']?.toString(),
                          style: TextStyle(
                            color: desistiu
                                ? Colors.white54
                                : AppColors.textWhite,
                            fontWeight: FontWeight.bold,
                            decoration: desistiu
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (desistiu)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "Desistiu",
                            style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        )
                      else
                        _overallBadge(displayList[i]),
                    ],
                  ),
                  trailing: Icon(
                    desistiu ? Icons.undo : Icons.more_vert,
                    color: desistiu ? Colors.white38 : Colors.white24,
                  ),
                  onTap: () => _showChegadaOptions(displayList[i]),
                ),
              ),
              ),
            ),
              ],
            );
          }),
      ],
    );
  }

  Widget _buildMatchTab() {
    Map<String, Map<String, dynamic>> allStats = {};
    String? motmPlayerId;
    double highestNota = -1;
    int highestGa = -1;
    void checkMotm(Map<String, dynamic> player, Map<String, dynamic> stats) {
      double n = stats['nota'];
      int ga = stats['ga'];
      if (n > highestNota) {
        highestNota = n;
        highestGa = ga;
        motmPlayerId = _pid(player);
      } else if (n == highestNota && n > 7.0) {
        if (ga > highestGa) {
          highestGa = ga;
          motmPlayerId = _pid(player);
        }
      }
    }

    for (var p in teamRed) {
      var s = _getPlayerMatchStats(p, true);
      allStats[_pid(p)] = s;
      checkMotm(p, s);
    }
    for (var p in teamWhite) {
      var s = _getPlayerMatchStats(p, false);
      allStats[_pid(p)] = s;
      checkMotm(p, s);
    }
    if (activeGkRed != null) {
      var s = _getPlayerMatchStats(activeGkRed!, true);
      allStats[_pid(activeGkRed!)] = s;
      checkMotm(activeGkRed!, s);
    }
    if (activeGkWhite != null) {
      var s = _getPlayerMatchStats(activeGkWhite!, false);
      allStats[_pid(activeGkWhite!)] = s;
      checkMotm(activeGkWhite!, s);
    }
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildPitchListToggle(),
          if (redWinStreak > 0 || whiteWinStreak > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text(
                    redWinStreak > 0
                        ? "🔥 Sequência: $redWinStreak${winLimit > 0 ? '/$winLimit' : ''}"
                        : "",
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    whiteWinStreak > 0
                        ? "🔥 Sequência: $whiteWinStreak${winLimit > 0 ? '/$winLimit' : ''}"
                        : "",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          if (_showTacticalPitch)
            TacticalPitch(
              teamSize: widget.totalPlayers,
              teamRed: teamRed,
              teamWhite: teamWhite,
              gkRed: activeGkRed,
              gkWhite: activeGkWhite,
              allStats: allStats,
              motmPlayerId: motmPlayerId,
              onPlayerTap: (player, isRed) {
                if (isMatchRunning) {
                  _showInGameOptions(player, isRed);
                } else {
                  _showRemovePopup(player);
                }
              },
              onGkRedTap: () {
                if (activeGkRed == null) {
                  _showGoalkeeperSelectionDialog(true, (player) {
                    setState(() {
                      activeGkRed = player;
                      firstGkRed ??= player;
                    });
                    _saveMatchState();
                  });
                } else {
                  _showInGameOptions(activeGkRed!, true, isGk: true);
                }
              },
              onGkWhiteTap: () {
                if (activeGkWhite == null) {
                  _showGoalkeeperSelectionDialog(false, (player) {
                    setState(() {
                      activeGkWhite = player;
                      firstGkWhite ??= player;
                    });
                    _saveMatchState();
                  });
                } else {
                  _showInGameOptions(activeGkWhite!, false, isGk: true);
                }
              },
              eventIconsOf: _buildEventIconsList,
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Colors.white10, width: 1),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 12.0, bottom: 8.0),
                          child: Text(
                            "Linha Vermelho",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        ...teamRed.map(
                          (p) => MatchPlayerTile(
                            player: p,
                            isRed: true,
                            matchStats: allStats[_pid(p)]!,
                            onTap: () {
                              if (isMatchRunning) {
                                _showInGameOptions(p, true);
                              } else {
                                _showRemovePopup(p);
                              }
                            },
                            eventIcons: _buildEventIconsList(allStats[_pid(p)]!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 12.0, bottom: 8.0),
                        child: Text(
                          "Linha Branco",
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      ...teamWhite.map(
                        (p) => MatchPlayerTile(
                          player: p,
                          isRed: false,
                          matchStats: allStats[_pid(p)]!,
                          onTap: () {
                            if (isMatchRunning) {
                              _showInGameOptions(p, false);
                            } else {
                              _showRemovePopup(p);
                            }
                          },
                          eventIcons: _buildEventIconsList(allStats[_pid(p)]!),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
              child: Row(
                children: [
                  _buildGkTile(true),
                  const SizedBox(width: 12),
                  _buildGkTile(false),
                ],
              ),
            ),
          ],
          MatchEventsPanel(events: matchEvents),
        ],
      ),
    );
  }

  Widget _buildPitchListToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: _viewModeChip(
              selected: _showTacticalPitch,
              icon: Icons.sports_soccer,
              label: 'Campo tático',
              onTap: () => _setShowTacticalPitch(true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _viewModeChip(
              selected: !_showTacticalPitch,
              icon: Icons.view_list,
              label: 'Lista',
              onTap: () => _setShowTacticalPitch(false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewModeChip({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected
          ? AppColors.accentBlue
          : AppColors.surfaceSubtle,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.accentBlue : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AppColors.textWhite : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.textWhite : AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setShowTacticalPitch(bool value) async {
    if (_showTacticalPitch == value) return;
    setState(() => _showTacticalPitch = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_tactical_pitch', value);
  }

  Widget _buildGkTile(bool isRed) {
    final gk = isRed ? activeGkRed : activeGkWhite;
    final teamColor = isRed ? AppColors.redTeam : AppColors.whiteTeam;
    final borderColor = isRed ? AppColors.redTeam.withValues(alpha: 0.4) : AppColors.borderSubtle;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (gk == null) {
            _showGoalkeeperSelectionDialog(isRed, (player) {
              setState(() {
                if (isRed) {
                  activeGkRed = player;
                  if (firstGkRed == null) firstGkRed = player;
                } else {
                  activeGkWhite = player;
                  if (firstGkWhite == null) firstGkWhite = player;
                }
              });
              _saveMatchState();
            });
          } else {
            _showInGameOptions(gk, isRed, isGk: true);
          }
        },
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.headerBlue,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sports_handball, color: teamColor, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  gk != null ? gk['name'] : "Goleiro",
                  style: TextStyle(
                    color: gk != null ? AppColors.textWhite : AppColors.textMuted,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextTeamsTab() {
    final waiting = waitingPlayers(presentPlayers, teamRed, teamWhite, _pid);
    if (waiting.isEmpty)
      return const Center(
        child: Text(
          "Todos os jogadores estão jogando!",
          style: TextStyle(color: Colors.white38),
        ),
      );
    final int teamSize = widget.totalPlayers;
    return ReorderableListView(
      padding: const EdgeInsets.all(16),
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final playerMoving = waiting[oldIndex];
          presentPlayers.remove(playerMoving);
          int targetMainIndex;
          if (newIndex >= waiting.length - 1) {
            targetMainIndex = presentPlayers.length;
          } else {
            final playerAtTarget = waiting[newIndex];
            targetMainIndex = presentPlayers.indexOf(playerAtTarget);
          }
          if (targetMainIndex > presentPlayers.length)
            targetMainIndex = presentPlayers.length;
          presentPlayers.insert(targetMainIndex, playerMoving);
        });
        _saveMatchState();
      },
      children: _buildIndividualPlayerCards(waiting, teamSize),
    );
  }

  /// Selo com o Overall (0-99) do jogador, na cor da faixa (bronze/prata/ouro/elite).
  Widget _overallBadge(Map<String, dynamic> player) {
    final int ovr = playerOverallOf(player).round();
    final Color c = overallColor(ovr);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Text(
        '$ovr',
        style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  List<Widget> _buildIndividualPlayerCards(
    List<Map<String, dynamic>> waiting,
    int teamSize,
  ) {
    final List<Widget> cards = [];
    final int numCompleteTeams = waiting.length ~/ teamSize;
    final int remainingPlayers = waiting.length % teamSize;
    for (int teamIndex = 0; teamIndex < numCompleteTeams; teamIndex++) {
      final int startIndex = teamIndex * teamSize;
      for (int i = 0; i < teamSize; i++) {
        final playerIndex = startIndex + i;
        cards.add(
          _buildIndividualPlayerCard(
            player: waiting[playerIndex],
            index: playerIndex,
            isCompleteTeam: true,
            isFirstPlayerInTeam: i == 0,
            isLastPlayerInTeam: i == teamSize - 1,
            teamBatch: teamIndex + 1,
          ),
        );
      }
    }
    if (remainingPlayers > 0) {
      final int startIndex = numCompleteTeams * teamSize;
      for (int i = 0; i < remainingPlayers; i++) {
        final playerIndex = startIndex + i;
        cards.add(
          _buildIndividualPlayerCard(
            player: waiting[playerIndex],
            index: playerIndex,
            isCompleteTeam: false,
            isFirstPlayerInTeam: true,
            isLastPlayerInTeam: true,
            teamBatch: 0,
          ),
        );
      }
    }
    return cards;
  }

  Widget _buildIndividualPlayerCard({
    required Map<String, dynamic> player,
    required int index,
    required bool isCompleteTeam,
    required bool isFirstPlayerInTeam,
    required bool isLastPlayerInTeam,
    required int teamBatch,
  }) {
    final iconPath = player['icon'] as String?;
    final rating = playerOverallOf(player);
    Color teamColor = Colors.white12;
    if (isCompleteTeam) {
      if (teamBatch == 1)
        teamColor = AppColors.accentBlue;
      else if (teamBatch == 2)
        teamColor = Colors.orangeAccent;
      else if (teamBatch == 3)
        teamColor = Colors.purpleAccent;
      else
        teamColor = Colors.greenAccent;
    }
    final EdgeInsets margin = EdgeInsets.only(
      bottom: isLastPlayerInTeam ? 16 : 2,
    );
    return Container(
      key: ValueKey(_pid(player)),
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.vertical(
          top: isFirstPlayerInTeam
              ? const Radius.circular(12)
              : const Radius.circular(4),
          bottom: isLastPlayerInTeam
              ? const Radius.circular(12)
              : const Radius.circular(4),
        ),
        border: Border.all(
          color: isCompleteTeam
              ? teamColor.withOpacity(0.6)
              : Colors.white.withOpacity(0.05),
          width: isCompleteTeam ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomRight,
          children: [
            PlayerAvatarFrame(
              frame: resolvePlayerFrame(player),
              compact: true,
              isCircular: true,
              child: CircleAvatar(
                backgroundColor: isCompleteTeam
                    ? teamColor.withOpacity(0.2)
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
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isCompleteTeam ? teamColor : Colors.white30,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  "${index + 1}",
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: PlayerNameText(
                name: player['name'].toString(),
                nameEffect: player['name_effect']?.toString(),
                style: TextStyle(
                  color: isCompleteTeam ? Colors.white : Colors.white70,
                  fontWeight: isCompleteTeam
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (rating > 0) _overallBadge(player),
          ],
        ),
        trailing: const Icon(Icons.drag_handle, color: Colors.white24),
        onTap: () => _showChegadaOptions(player),
      ),
      ),
    );
  }

  void _showChegadaOptions(Map<String, dynamic> player) {
    final bool desistiu = player['desistiu'] == true;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.deepBlue,
      builder: (ctx) => Wrap(
        children: desistiu
            ? [
                ListTile(
                  leading: const Icon(Icons.undo, color: Colors.greenAccent),
                  title: const Text(
                    "Reativar (voltou a jogar)",
                    style: TextStyle(color: Colors.greenAccent),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _reactivatePlayer(player);
                  },
                ),
              ]
            : [
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
          "Ele sai dos times/fila, mas continua na lista (marcado como inativo). Confirmar?",
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
                final String pid = _pid(player);
                teamRed.removeWhere((p) => _pid(p) == pid);
                teamWhite.removeWhere((p) => _pid(p) == pid);
                // Quem desiste também deixa de ser o goleiro em campo. (O
                // `firstGk*` é histórico da partida atual e não é mexido.)
                if (activeGkRed != null && _pid(activeGkRed!) == pid) {
                  activeGkRed = null;
                }
                if (activeGkWhite != null && _pid(activeGkWhite!) == pid) {
                  activeGkWhite = null;
                }
                final idx = presentPlayers.indexWhere(
                  (p) => _pid(p) == pid,
                );
                if (idx != -1) {
                  presentPlayers[idx] = {
                    ...presentPlayers[idx],
                    'desistiu': true,
                  };
                }
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

  void _reactivatePlayer(Map<String, dynamic> player) {
    setState(() {
      final idx = presentPlayers.indexWhere((p) => _pid(p) == _pid(player));
      if (idx != -1) {
        presentPlayers[idx] = {...presentPlayers[idx]}..remove('desistiu');
      }
    });
    _saveMatchState();
  }

  void _showMultiSelectDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final String? dbData = prefs.getString('players_${widget.groupId}');
    if (dbData != null) {
      setState(() {
        allSavedPlayers = List<Map<String, dynamic>>.from(jsonDecode(dbData));
      });
    }
    if (allSavedPlayers.isEmpty && widget.groupId.isNotEmpty) {
      try {
        final fetched = await SupabaseService.instance.players.getPlayersByGroup(widget.groupId);
        if (fetched.isNotEmpty) {
          setState(() {
            allSavedPlayers = fetched
                .map((p) => GroupBootstrap.playerSnapshotMap(
                    p, p.rating ?? kRatingBase))
                .toList();
          });
          await prefs.setString('players_${widget.groupId}', jsonEncode(allSavedPlayers));
        }
      } catch (_) {}
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
            "Você precisa cadastrar jogadores na tela 'Jogadores'.",
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
    String searchQuery = '';
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, st) {
          final available = allSavedPlayers
              .where(
                (p) =>
                    !presentPlayers.any((present) => _pid(present) == _pid(p)),
              )
              .where(
                (p) => p['name'].toString().toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ),
              )
              .toList();
          available.sort(
            (a, b) => (a['name'] as String).toLowerCase().compareTo(
              (b['name'] as String).toLowerCase(),
            ),
          );

          return AlertDialog(
            backgroundColor: AppColors.headerBlue,
            title: const Text(
              "Adicionar Jogadores",
              style: TextStyle(color: AppColors.textWhite),
            ),
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
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white54,
                      ),
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
                        ? const Center(
                            child: Text(
                              "Nenhum jogador encontrado.",
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : ListView.builder(
                            itemCount: available.length,
                            itemBuilder: (c, i) => CheckboxListTile(
                              activeColor: AppColors.accentBlue,
                              checkColor: AppColors.textWhite,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                available[i]['name'],
                                style: const TextStyle(
                                  color: AppColors.textWhite,
                                ),
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
                ],
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
          );
        },
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
          if (!isDraftMode)
            ListTile(
              leading: const Icon(Icons.balance, color: Colors.orangeAccent),
              title: const Text(
                'Sorteio Nivelado',
                style: TextStyle(color: AppColors.textWhite),
              ),
              onTap: () {
                Navigator.pop(c);
                _showSorteioOptionsDialog();
              },
            ),
          if (isDraftMode)
            ListTile(
              leading: const Icon(
                Icons.sports_soccer,
                color: Colors.orangeAccent,
              ),
              title: const Text(
                'Draft — Escolher Times',
                style: TextStyle(color: AppColors.textWhite),
              ),
              onTap: () {
                Navigator.pop(c);
                _iniciarTimesDraft();
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

  void _confirmEventDialog(
    String type,
    Map<String, dynamic> player,
    bool isRedTeam, {
    String? assist,
    String? assistId,
  }) {
    String actionText = "";
    if (type == 'goal') {
      actionText =
          "⚽ GOL: ${player['name']}\n" +
          (assist != null ? "🤝 ASSIST: $assist" : "🏃‍♂️ (Jogada Individual)");
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
        title: const Text(
          "Confirmar Evento?",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          actionText,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentBlue,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _registerEvent(
                type,
                player,
                isRedTeam,
                assist: assist,
                assistId: assistId,
              );
            },
            child: const Text(
              "Lançar",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleGoal(Map<String, dynamic> player, bool isRedTeam) {
    List<Map<String, dynamic>> teammates = isRedTeam
        ? List.from(teamRed)
        : List.from(teamWhite);
    
    // Inclui o goleiro do próprio time se ele não for o autor do gol
    final currentGk = isRedTeam ? activeGkRed : activeGkWhite;
    if (currentGk != null && !teammates.any((p) => _pid(p) == _pid(currentGk))) {
      teammates.add(currentGk);
    }

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
              _confirmEventDialog("goal", player, isRedTeam, assist: null);
            },
          ),
          const Divider(color: Colors.white12),
          ...teammates.map(
            (teammate) => SimpleDialogOption(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              child: PlayerNameText(
                name: teammate['name'].toString(),
                nameEffect: teammate['name_effect']?.toString(),
                style: const TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 16,
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _confirmEventDialog(
                  "goal",
                  player,
                  isRedTeam,
                  assist: teammate['name'],
                  assistId: _pid(teammate),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Toca o som do gol SEM bloquear o placar. Antes, o `await` do áudio
  /// customizado (URL de rede) vinha antes do setState: com internet ruim o
  /// gol demorava segundos pra aparecer. Sem rede / URL lenta -> som padrão.
  Future<void> _playGoalSound(String type, Map<String, dynamic> player) async {
    if (type != "goal" && type != "own_goal") return;
    final String? customSound = player['goal_sound_url']?.toString();
    try {
      if (customSound != null && customSound.isNotEmpty && type == "goal") {
        // Só quem fez o gol de verdade tem seu áudio tocado; gol contra
        // sempre usa o som padrão.
        await _goalSoundPlayer.stop();
        if (customSound.startsWith('http://') || customSound.startsWith('https://')) {
          await _goalSoundPlayer
              .play(UrlSource(customSound))
              .timeout(const Duration(seconds: 4));
        } else {
          await _goalSoundPlayer
              .play(AssetSource('audio/$customSound'))
              .timeout(const Duration(seconds: 4));
        }
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(AssetSource('audio/default_goal.mp3'));
      }
    } catch (e) {
      // Link quebrado, sem internet ou erro: som padrão.
      try {
        await _goalSoundPlayer.stop();
        await _audioPlayer.stop();
        await _audioPlayer.play(AssetSource('audio/default_goal.mp3'));
      } catch (_) {}
    }
  }

  void _registerEvent(
    String type,
    Map<String, dynamic> player,
    bool isRedTeam, {
    String? assist,
    String? assistId,
  }) async {
    // 1) placar e súmula primeiro; 2) áudio em paralelo.
    unawaited(_playGoalSound(type, player));
    setState(() {
      if (type == "goal") {
        if (isRedTeam)
          scoreRed++;
        else
          scoreWhite++;
      } else if (type == "own_goal") {
        if (isRedTeam)
          scoreWhite++;
        else
          scoreRed++;
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
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Evento registrado!"),
          duration: Duration(seconds: 1),
        ),
      );
  }

  void _showInGameOptions(Map<String, dynamic> player, bool isRedTeam, {bool isGk = false}) {
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
            if (isGk)
              ListTile(
                leading: const Icon(
                  Icons.swap_horiz_rounded,
                  color: Colors.orangeAccent,
                ),
                title: const Text(
                  "Trocar Goleiro",
                  style: TextStyle(color: AppColors.textWhite),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showGoalkeeperSelectionDialog(isRedTeam, (selectedGk) {
                    setState(() {
                      if (isRedTeam) activeGkRed = selectedGk;
                      else activeGkWhite = selectedGk;
                    });
                    _saveMatchState();
                  });
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
                _confirmEventDialog("own_goal", player, isRedTeam);
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
                _confirmEventDialog("yellow_card", player, isRedTeam);
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
                _confirmEventDialog("red_card", player, isRedTeam);
              },
            ),
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

  void _finishMatch() async {
    _matchTimer?.cancel();
    // Snapshot ANTES de zerar goleiros/estado: o código antigo montava as
    // escalações do Supabase depois do setState que limpa firstGkRed/White,
    // então o flag is_goalkeeper nunca era gravado.
    final Map<String, dynamic>? gkRedSnap = firstGkRed;
    final Map<String, dynamic>? gkWhiteSnap = firstGkWhite;
    final List<Map<String, dynamic>> redSnap = List.from(teamRed);
    final List<Map<String, dynamic>> whiteSnap = List.from(teamWhite);
    final List<Map<String, dynamic>> eventsSnap = List.from(matchEvents);
    final int redScoreSnap = scoreRed;
    final int whiteScoreSnap = scoreWhite;
    final int durationSnap = totalSecondsElapsed;
    final DateTime startedAtSnap = _lastStartTime ??
        DateTime.now().subtract(Duration(seconds: totalSecondsElapsed));
    final Map<String, dynamic> matchRecord = {
      "match_id": DateTime.now().millisecondsSinceEpoch.toString(),
      "date": DateTime.now().toIso8601String(),
      "match_duration": _formatTime(totalSecondsElapsed),
      "scoreRed": scoreRed,
      "scoreWhite": scoreWhite,
      "events": List.from(matchEvents),
      "players": {
        "red": List.from(teamRed),
        "white": List.from(teamWhite),
        "gk_red": firstGkRed,
        "gk_white": firstGkWhite,
      },
    };

    setState(() {
      activeGkRed = null;
      activeGkWhite = null;
      firstGkRed = null;
      firstGkWhite = null;
    });
    _saveMatchState();

    // --- Persistência: nada aqui espera a rede ---------------------------
    final String matchId = const Uuid().v4();

    final List<Map<String, dynamic>> lineupMaps = [];
    void addLineup(Map<String, dynamic> p, String team, Map<String, dynamic>? gk) {
      final pid = playerIdFromObject(p);
      if (pid.isEmpty) return;
      lineupMaps.add(MatchLineupModel(
        matchId: '',
        playerId: pid,
        team: team,
        isGoalkeeper: gk != null && pid == playerIdFromObject(gk),
      ).toMap(includeId: false)..remove('match_id'));
    }
    for (final p in redSnap) addLineup(p, 'red', gkRedSnap);
    for (final p in whiteSnap) addLineup(p, 'white', gkWhiteSnap);

    final List<Map<String, dynamic>> eventMaps = eventsSnap.map((ev) {
      final pid = eventPlayerId(ev, 'player');
      final astId = eventPlayerId(ev, 'assist');
      // matchEvents guarda "Vermelho"/"Branco" pra exibição; o banco só
      // aceita 'red'/'white'.
      final rawTeam = ev['team']?.toString() ?? '';
      final normalizedTeam = rawTeam == 'Branco' ? 'white' : 'red';
      return MatchEventModel(
        matchId: '',
        playerId: pid,
        assistPlayerId: astId.isNotEmpty ? astId : null,
        eventType: ev['type']?.toString() ?? 'goal',
        team: normalizedTeam,
        minute: ev['time']?.toString(),
      ).toMap(includeId: false)..remove('match_id');
    }).toList();

    // 1 escrita local rápida e o envio vai pra fila (retry automático).
    await PendingMatchQueue.instance.enqueue({
      'match_id': matchId,
      'match': {
        'id': matchId,
        'session_id': widget.tournamentId,
        'group_id': widget.groupId,
        'score_red': redScoreSnap,
        'score_white': whiteScoreSnap,
        'played_at': startedAtSnap.toIso8601String(),
        'duration_seconds': durationSnap,
      },
      'lineups': lineupMaps,
      'events': eventMaps,
    });

    // Backup local do histórico: em segundo plano.
    unawaited(_appendLocalHistory(matchRecord));
    // Notas ficam fixas durante a pelada (snapshot do GroupBootstrap).

    bool isTie = scoreRed == scoreWhite;
    bool redWon = scoreRed > scoreWhite;
    List<Map<String, dynamic>> suggestedLeavers = [];
    String popupTitle = "";
    String popupMessage = "";
    Color popupColor = AppColors.textWhite;

    bool thresholdMet = false;

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
        redWinStreak++; whiteWinStreak = 0;
        if (winLimit > 0 && redWinStreak >= winLimit) { 
            thresholdMet = true;
            suggestedLeavers.addAll(teamRed); suggestedLeavers.addAll(teamWhite); suggestedLeavers.shuffle(Random()); 
            popupTitle = "🔥 VERMELHO INVICTO!"; popupMessage = "Vermelho ganhou $winLimit seguidas!\nAutomação acionada."; popupColor = Colors.redAccent; 
        }
        else { suggestedLeavers.addAll(teamWhite); popupTitle = "Vitória do VERMELHO!"; popupMessage = winLimit > 0 ? "Sugestão: Branco sai.\n(Sequência do Vermelho: $redWinStreak/$winLimit)" : "Sugestão: Branco sai.\n(Vitórias seguidas: $redWinStreak)"; popupColor = Colors.redAccent; }
      } else {
        whiteWinStreak++; redWinStreak = 0;
        if (winLimit > 0 && whiteWinStreak >= winLimit) { 
            thresholdMet = true;
            suggestedLeavers.addAll(teamRed); suggestedLeavers.addAll(teamWhite); suggestedLeavers.shuffle(Random()); 
            popupTitle = "🔥 BRANCO INVICTO!"; popupMessage = "Branco ganhou $winLimit seguidas!\nAutomação acionada."; popupColor = Colors.white; 
        }
        else { suggestedLeavers.addAll(teamRed); popupTitle = "Vitória do BRANCO!"; popupMessage = winLimit > 0 ? "Sugestão: Vermelho sai.\n(Sequência do Branco: $whiteWinStreak/$winLimit)" : "Sugestão: Vermelho sai.\n(Vitórias seguidas: $whiteWinStreak)"; popupColor = Colors.white; }
      }
    }

    _scheduleSiteSync();

    if (thresholdMet) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("$popupTitle Aplicando regra: ${streakAction == 'dual_exit' ? 'Ambos Saem' : 'Dividir Vencedor'}"),
          backgroundColor: popupColor,
          duration: const Duration(seconds: 3),
        ));
      }
      if (streakAction == 'dual_exit') {
        _processMatchExit(suggestedLeavers); // Ambos saem
      } else {
        final winners = redWon ? List<Map<String, dynamic>>.from(teamRed)  : List<Map<String, dynamic>>.from(teamWhite);
        final losers  = redWon ? List<Map<String, dynamic>>.from(teamWhite) : List<Map<String, dynamic>>.from(teamRed);
        _splitWinner(winners, losers);
      }
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.headerBlue,
          title: Text(
            popupTitle,
            style: TextStyle(
              color: popupColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 60),
              const SizedBox(height: 16),
              Text(
                "Placar Final: $scoreRed x $scoreWhite",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
                Navigator.pop(ctx);
                _showManualExitDialog();
              },
              child: const Text(
                "Alterar na Mão",
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ),
            if (!isTie)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  final winners = redWon
                      ? List<Map<String, dynamic>>.from(teamRed)
                      : List<Map<String, dynamic>>.from(teamWhite);
                  final losers = redWon
                      ? List<Map<String, dynamic>>.from(teamWhite)
                      : List<Map<String, dynamic>>.from(teamRed);
                  _splitWinner(winners, losers);
                },
                child: const Text(
                  "Dividir Vencedor",
                  style: TextStyle(
                    color: Colors.purpleAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _processMatchExit(suggestedLeavers);
              },
              child: const Text(
                "Confirmar >>",
                style: TextStyle(
                  color: AppColors.accentBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _appendLocalHistory(Map<String, dynamic> matchRecord) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String historyKey = 'match_history_${widget.tournamentId}';
      List<dynamic> history = [];
      try {
        if (prefs.containsKey(historyKey)) {
          history = jsonDecode(prefs.getString(historyKey)!);
        }
      } catch (_) {
        history = [];
      }
      history.add(matchRecord);
      await prefs.setString(historyKey, jsonEncode(history));
    } catch (e) {
      debugPrint('Error saving local match history: $e');
    }
  }

  /// Agenda o export pesado (site_data/backup) pra DEPOIS do jogo, em vez de
  /// rodar a cada partida finalizada. Espera a fila de upload esvaziar e não
  /// dispara enquanto uma partida está rolando.
  void _scheduleSiteSync() {
    _siteSyncTimer?.cancel();
    _siteSyncTimer = Timer(const Duration(seconds: 90), () {
      if (!mounted) return;
      if (isMatchRunning || PendingMatchQueue.instance.pending.value > 0) {
        _scheduleSiteSync();
        return;
      }
      _triggerBackgroundSync();
    });
  }

  void _showPendingSyncDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text("Sincronização",
            style: TextStyle(color: AppColors.textWhite)),
        content: ValueListenableBuilder<int>(
          valueListenable: PendingMatchQueue.instance.pending,
          builder: (_, count, __) => ValueListenableBuilder<String?>(
            valueListenable: PendingMatchQueue.instance.lastError,
            builder: (_, err, __) => Text(
              count == 0
                  ? "Tudo sincronizado."
                  : "$count partida(s) aguardando envio ao servidor."
                      "${err != null ? '\n\nÚltimo erro: $err' : ''}",
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => PendingMatchQueue.instance.flush(),
            child: const Text("Tentar agora"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Fechar"),
          ),
        ],
      ),
    );
  }

  void _splitWinner(
    List<Map<String, dynamic>> winners,
    List<Map<String, dynamic>> losers,
  ) {
    setState(() {
      // Perdedores saem
      for (var p in losers) {
        int index = presentPlayers.indexWhere((e) => _pid(e) == _pid(p));
        if (index != -1) {
          var player = presentPlayers.removeAt(index);
          presentPlayers.add(player);
        }
      }

      // Divide o time vencedor em duas metades EQUILIBRADAS por Overall
      // (antes era "primeiros pra um lado, últimos pro outro", sem olhar nota).
      final List<Map<String, dynamic>> half1 = [];
      final List<Map<String, dynamic>> half2 = [];
      if (winners.length >= 2) {
        final winnersById = {for (final p in winners) _pid(p): p};
        final split = TeamBalancer.suggest(
          winners.map(_balancePlayer).toList(),
          count: 1,
          tolerance: 1.0,
        ).first;
        for (final bp in split.a) {
          final p = winnersById[bp.id];
          if (p != null) half1.add(p);
        }
        for (final bp in split.b) {
          final p = winnersById[bp.id];
          if (p != null) half2.add(p);
        }
      } else {
        half1.addAll(winners);
      }

      // Calculates how many players are missing on each team
      int neededRed = widget.totalPlayers - half1.length;
      int neededWhite = widget.totalPlayers - half2.length;
      int totalNeeded = neededRed + neededWhite;

      // Gets the players outside (waiting queue)
      final Set<String> winnerIds = winners.map(_pid).toSet();
      final List<Map<String, dynamic>> bench = presentPlayers
          .where((p) {
            final id = _pid(p);
            return p['desistiu'] != true && !winnerIds.contains(id);
          })
          .take(totalNeeded)
          .toList();

      teamRed = List.from(half1);
      teamWhite = List.from(half2);

      // Distribui o banco de forma balanceada (por Overall)
      _fillTeamsBalanced(bench);

      // Reseta sequências
      redWinStreak = 0;
      whiteWinStreak = 0;
      isMatchRunning = false;
      isOvertime = false;
      scoreRed = 0;
      scoreWhite = 0;
      matchEvents.clear();
      _secondsPlayedBeforePause = 0;
      _lastStartTime = null;
      _disbalanceWarned = false;

      _saveMatchState();
      _showLeaversPopup(losers, bench);
    });
  }

  void _showManualExitDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.headerBlue,
          title: const Text(
            "Intervenção Manual",
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            "Quem deve sair de campo?",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              child: const Text(
                "Vermelho Sai",
                style: TextStyle(color: Colors.redAccent),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _processMatchExit(List.from(teamRed));
              },
            ),
            TextButton(
              child: const Text(
                "Branco Sai",
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _processMatchExit(List.from(teamWhite));
              },
            ),
            TextButton(
              child: const Text(
                "Ambos Saem",
                style: TextStyle(color: Colors.orangeAccent),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                List<Map<String, dynamic>> both = [];
                both.addAll(teamRed);
                both.addAll(teamWhite);
                both.shuffle(Random());
                _processMatchExit(both);
              },
            ),
            TextButton(
              child: const Text(
                "Dividir Vencedor",
                style: TextStyle(
                  color: Colors.purpleAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                bool redWon = scoreRed > scoreWhite;
                bool whitWon = scoreWhite > scoreRed;
                if (!redWon && !whitWon) {
                  // Empate: pergunta quem é o "vencedor" a dividir
                  _showChooseWinnerForSplitDialog();
                } else {
                  final winners = redWon
                      ? List<Map<String, dynamic>>.from(teamRed)
                      : List<Map<String, dynamic>>.from(teamWhite);
                  final losers = redWon
                      ? List<Map<String, dynamic>>.from(teamWhite)
                      : List<Map<String, dynamic>>.from(teamRed);
                  _splitWinner(winners, losers);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showChooseWinnerForSplitDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text(
          "Dividir qual time?",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Empate: escolha o time que vai ser dividido.",
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
              _splitWinner(List.from(teamRed), List.from(teamWhite));
            },
          ),
          TextButton(
            child: const Text("Branco", style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(ctx);
              _splitWinner(List.from(teamWhite), List.from(teamRed));
            },
          ),
        ],
      ),
    );
  }

  void _processMatchExit(List<Map<String, dynamic>> leavers) {
    setState(() {
      bool redIsLeaving = teamRed.any(
        (p) => leavers.any((l) => _pid(l) == _pid(p)),
      );
      bool whiteIsLeaving = teamWhite.any(
        (p) => leavers.any((l) => _pid(l) == _pid(p)),
      );
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
        if (p['desistiu'] == true) continue; // quem desistiu nunca entra
        final id = _pid(p);
        if (!teamRed.any((t) => _pid(t) == id) &&
            !teamWhite.any((t) => _pid(t) == id))
          entering.add(p);
      }

      teamRed.removeWhere((p) => leavers.any((l) => _pid(l) == _pid(p)));
      teamWhite.removeWhere((p) => leavers.any((l) => _pid(l) == _pid(p)));

      // --- BALANCEAMENTO por OVERALL ---
      if (isDraftMode) {
        // Modo draft: o organizador escolhe depois; só preenche as vagas.
        for (var p in entering) {
          if (teamRed.length < widget.totalPlayers) {
            teamRed.add(p);
          } else if (teamWhite.length < widget.totalPlayers) {
            teamWhite.add(p);
          }
        }
      } else {
        _fillTeamsBalanced(entering);
      }

      isMatchRunning = false;
      isOvertime = false;
      scoreRed = 0;
      scoreWhite = 0;
      matchEvents.clear();
      _secondsPlayedBeforePause = 0;
      _lastStartTime = null;
      _disbalanceWarned = false;

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
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
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
      ),
    );
  }

  void _playVictorySound() async {
    final sounds = [
      'audio/vitoria1.mp3',
      'audio/vitoria2.mp3',
      'audio/vitoria3.mp3',
    ]..shuffle(Random());
    // Se um arquivo estiver corrompido/incompatível (ex.: Format error no
    // Chrome), tenta o próximo em vez de ficar sem som.
    for (final sound in sounds) {
      try {
        await _audioPlayer.play(AssetSource(sound));
        return;
      } catch (e) {
        debugPrint('Falha ao tocar $sound: $e');
      }
    }
  }

  void _showEnteringPlayersPopup(List<Map<String, dynamic>> entering) {
    if (entering.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
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
              onPressed: () {
                Navigator.pop(ctx);
                _checkAndWarnTeamDisbalance();
              },
              child: const Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _triggerBackgroundSync() async {
    // Fire and forget
    try {
      final syncService = SyncService();
      final String code = await syncService.getOrCreateSyncCode();
      syncService.exportDataToSupabase(code).then((_) async {
        _recordSyncHistory(true);
      }).catchError((e) {
        _recordSyncHistory(false, e.toString());
      });
    } catch (e) {
      _recordSyncHistory(false, e.toString());
    }
  }

  void _recordSyncHistory(bool success, [String? error]) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('sync_history') ?? [];
    final now = DateTime.now().toIso8601String();
    String entry = "$now|$success";
    if (error != null) {
      entry += "|${error.replaceAll('|', ' ')}";
    }
    history.add(entry);
    if (history.length > 50) history.removeAt(0);
    await prefs.setStringList('sync_history', history);
  }
}
