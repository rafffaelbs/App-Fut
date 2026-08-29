import 'json_parsers.dart';
import 'match_event.dart';
import 'player.dart';

class MatchPlayers {
  final List<Player> red;
  final List<Player> white;
  final Player? gkRed;
  final Player? gkWhite;

  const MatchPlayers({
    this.red = const [],
    this.white = const [],
    this.gkRed,
    this.gkWhite,
  });

  /// Cria a estrutura `players` de uma partida:
  /// `{red, white, gk_red, gk_white}`.
  factory MatchPlayers.fromJson(Map<String, dynamic> json) {
    return MatchPlayers(
      red: _parseTeam(json['red']),
      white: _parseTeam(json['white']),
      gkRed: _parseSingle(json['gk_red']),
      gkWhite: _parseSingle(json['gk_white']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (red.isNotEmpty) 'red': red.map((p) => p.toJson()).toList(),
      if (white.isNotEmpty) 'white': white.map((p) => p.toJson()).toList(),
      if (gkRed != null) 'gk_red': gkRed!.toJson(),
      if (gkWhite != null) 'gk_white': gkWhite!.toJson(),
    };
  }

  static List<Player> _parseTeam(dynamic value) {
    return parseMapList(value).map(Player.fromJson).toList();
  }

  static Player? _parseSingle(dynamic value) {
    if (value == null) return null;
    if (value is Map) return Player.fromJson(Map<String, dynamic>.from(value));
    final List<Map<String, dynamic>> list = parseMapList(value);
    return list.isEmpty ? null : Player.fromJson(list.first);
  }
}

class Match {
  final String? matchId;
  final String? date;
  final String? sessionDate;
  final String? matchDuration;
  final int scoreRed;
  final int scoreWhite;
  final List<MatchEvent> events;
  final MatchPlayers players;

  const Match({
    this.matchId,
    this.date,
    this.sessionDate,
    this.matchDuration,
    this.scoreRed = 0,
    this.scoreWhite = 0,
    this.events = const [],
    this.players = const MatchPlayers(),
  });

  /// Cria uma partida a partir do JSON persistido em `match_history_{tId}`.
  ///
  /// Compatível com as chaves legadas:
  /// `match_id`, `date`, `session_date`, `match_duration`, `scoreRed`,
  /// `scoreWhite`, `events`, `players`.
  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      matchId: parseString(json['match_id']),
      date: parseString(json['date']),
      sessionDate: parseString(json['session_date']) ?? parseString(json['date']),
      matchDuration: parseString(json['match_duration']),
      scoreRed: parseInt(json['scoreRed']),
      scoreWhite: parseInt(json['scoreWhite']),
      events: parseMapList(json['events']).map(MatchEvent.fromJson).toList(),
      players: json['players'] is Map
          ? MatchPlayers.fromJson(Map<String, dynamic>.from(json['players']))
          : const MatchPlayers(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (matchId != null) 'match_id': matchId,
      if (date != null) 'date': date,
      if (sessionDate != null) 'session_date': sessionDate,
      if (matchDuration != null) 'match_duration': matchDuration,
      'scoreRed': scoreRed,
      'scoreWhite': scoreWhite,
      if (events.isNotEmpty) 'events': events.map((e) => e.toJson()).toList(),
      'players': players.toJson(),
    };
  }

  DateTime? get dateTime {
    final String? raw = sessionDate ?? date;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  bool get isDraw => scoreRed == scoreWhite;
  bool get redWon => scoreRed > scoreWhite;
  bool get whiteWon => scoreWhite > scoreRed;

  Match copyWith({
    String? sessionDate,
  }) {
    return Match(
      matchId: matchId,
      date: date,
      sessionDate: sessionDate ?? this.sessionDate,
      matchDuration: matchDuration,
      scoreRed: scoreRed,
      scoreWhite: scoreWhite,
      events: events,
      players: players,
    );
  }
}