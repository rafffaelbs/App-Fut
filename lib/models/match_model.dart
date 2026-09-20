import 'package:collection/collection.dart';
import 'match_lineup_model.dart';
import 'match_event_model.dart';
import 'player_model.dart';

class MatchPlayers {
  final List<PlayerModel> red;
  final List<PlayerModel> white;
  final PlayerModel? gkRed;
  final PlayerModel? gkWhite;

  const MatchPlayers({
    this.red = const [],
    this.white = const [],
    this.gkRed,
    this.gkWhite,
  });

  factory MatchPlayers.fromLineups(List<MatchLineupModel> lineups) {
    final red = lineups.where((l) => l.isTeamA && l.player != null).map((l) => l.player!).toList();
    final white = lineups.where((l) => l.isTeamB && l.player != null).map((l) => l.player!).toList();
    final gkRed = lineups.where((l) => l.isTeamA && l.isGoalkeeper && l.player != null).map((l) => l.player!).firstOrNull;
    final gkWhite = lineups.where((l) => l.isTeamB && l.isGoalkeeper && l.player != null).map((l) => l.player!).firstOrNull;
    return MatchPlayers(red: red, white: white, gkRed: gkRed, gkWhite: gkWhite);
  }
}

class MatchModel {
  final String id;
  final String sessionId;
  final String? status;
  final DateTime? startTime;
  final DateTime? endTime;
  final int teamAScore;
  final int teamBScore;
  final int? durationSeconds; // Real elapsed time, direct from DB column (pauses already discounted)
  
  // Legacy / Relational fields
  final List<MatchLineupModel> lineups;
  final List<MatchEventModel> events;
  
  // Custom or dynamic fields
  final MatchPlayers? customPlayers; // To keep legacy players if lineups are empty

  const MatchModel({
    required this.id,
    required this.sessionId,
    this.status,
    this.startTime,
    this.endTime,
    this.teamAScore = 0,
    this.teamBScore = 0,
    this.durationSeconds,
    this.lineups = const [],
    this.events = const [],
    this.customPlayers,
  });

  // UI Backwards Compatibility Getters
  int get scoreRed => teamAScore;
  int get scoreWhite => teamBScore;
  bool get isDraw => teamAScore == teamBScore;
  bool get redWon => teamAScore > teamBScore;
  bool get whiteWon => teamBScore > teamAScore;
  
  // Map legacy matchDuration
  String? get matchDuration {
    final secs = resolvedDurationSeconds;
    if (secs != null) {
      return '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
    }
    return null;
  }
  
  DateTime? get dateTime => startTime;
  DateTime get timestamp => startTime ?? DateTime.now(); // Backwards compatibility
  // Prefer the real duration column (accounts for pauses); fall back to
  // start/end diff only for old rows that never had duration_seconds set.
  int? get resolvedDurationSeconds =>
      durationSeconds ??
      (startTime != null && endTime != null
          ? endTime!.difference(startTime!).inSeconds
          : null);
  
  MatchPlayers get players {
    if (customPlayers != null) return customPlayers!;
    return MatchPlayers.fromLineups(lineups);
  }
  

  factory MatchModel.fromMap(Map<String, dynamic> map) {
    List<MatchLineupModel> parsedLineups = [];
    final rawLineups = map['match_lineups'] ?? map['escalacao_partida'];
    if (rawLineups is List) {
      parsedLineups = rawLineups
          .whereType<Map>()
          .map((item) => MatchLineupModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    List<MatchEventModel> parsedEvents = [];
    final rawEvents = map['match_events'] ?? map['eventos_partida'];
    if (rawEvents is List) {
      parsedEvents = rawEvents
          .whereType<Map>()
          .map((item) => MatchEventModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    return MatchModel(
      id: map['id']?.toString() ?? '',
      sessionId: map['session_id']?.toString() ?? map['sessao_id']?.toString() ?? '',
      status: map['status']?.toString(),
      startTime: map['played_at'] != null
          ? DateTime.tryParse(map['played_at'].toString())
          : (map['start_time'] != null
              ? DateTime.tryParse(map['start_time'].toString())
              : (map['timestamp'] != null
                  ? DateTime.tryParse(map['timestamp'].toString())
                  : null)),
      endTime: map['end_time'] != null
          ? DateTime.tryParse(map['end_time'].toString())
          : null,
      durationSeconds: map['duration_seconds'] != null
          ? int.tryParse(map['duration_seconds'].toString())
          : null,
      teamAScore: map['team_a_score'] != null
          ? int.tryParse(map['team_a_score'].toString()) ?? 0
          : (map['score_red'] != null
              ? int.tryParse(map['score_red'].toString()) ?? 0
              : 0),
      teamBScore: map['team_b_score'] != null
          ? int.tryParse(map['team_b_score'].toString()) ?? 0
          : (map['score_white'] != null
              ? int.tryParse(map['score_white'].toString()) ?? 0
              : 0),
      lineups: parsedLineups,
      events: parsedEvents,
    );
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    final data = <String, dynamic>{
      'session_id': sessionId,
      'status': status,
      if (startTime != null) 'start_time': startTime!.toIso8601String(),
      'team_a_score': teamAScore,
      'team_b_score': teamBScore,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
    };
    if (includeId && id.isNotEmpty) {
      data['id'] = id;
    }
    return data;
  }

  MatchModel copyWith({
    String? id,
    String? sessionId,
    String? status,
    DateTime? startTime,
    DateTime? endTime,
    int? teamAScore,
    int? teamBScore,
    int? durationSeconds,
    List<MatchLineupModel>? lineups,
    List<MatchEventModel>? events,
    MatchPlayers? customPlayers,
  }) {
    return MatchModel(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      teamAScore: teamAScore ?? this.teamAScore,
      teamBScore: teamBScore ?? this.teamBScore,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      lineups: lineups ?? this.lineups,
      events: events ?? this.events,
      customPlayers: customPlayers ?? this.customPlayers,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MatchModel(id: $id, score: $teamAScore x $teamBScore, sessionId: $sessionId)';
}
