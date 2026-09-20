import 'player_model.dart';

class MatchEventModel {
  static const String typeGoal = 'goal';
  static const String typeOwnGoal = 'own_goal';
  static const String typeYellowCard = 'yellow_card';
  static const String typeRedCard = 'red_card';

  final int? id;
  final String matchId;
  final String playerId;
  final String? assistPlayerId;
  final String eventType;
  final String? timestamp;
  final String? team;
  final String? minute;
  final PlayerModel? player;
  final PlayerModel? assistPlayer;

  const MatchEventModel({
    this.id,
    required this.matchId,
    required this.playerId,
    this.assistPlayerId,
    required this.eventType,
    this.timestamp,
    this.team,
    this.minute,
    this.player,
    this.assistPlayer,
  });

  bool get isGoal => eventType == typeGoal || eventType.toLowerCase() == 'goal';
  bool get isOwnGoal => eventType == typeOwnGoal || eventType.toLowerCase() == 'own_goal';
  bool get isYellowCard => eventType == typeYellowCard || eventType.toLowerCase() == 'yellow_card';
  bool get isRedCard => eventType == typeRedCard || eventType.toLowerCase() == 'red_card';
  String? get assistJogadorId => assistPlayerId;

  // Legacy compat getters
  PlayerModel? get assistJogador => assistPlayer;
  String? get tempo => minute ?? timestamp;
  String? get time => team;

  factory MatchEventModel.fromMap(Map<String, dynamic> map) {
    PlayerModel? playerObj;
    if (map['players'] is Map) {
      playerObj = PlayerModel.fromJson(Map<String, dynamic>.from(map['players']));
    } else if (map['player'] is Map) {
      playerObj = PlayerModel.fromJson(Map<String, dynamic>.from(map['player']));
    } else if (map['jogador'] is Map) {
      playerObj = PlayerModel.fromJson(Map<String, dynamic>.from(map['jogador']));
    }

    PlayerModel? assistObj;
    if (map['assist_player'] is Map) {
      assistObj = PlayerModel.fromJson(Map<String, dynamic>.from(map['assist_player']));
    } else if (map['assist_jogador'] is Map) {
      assistObj = PlayerModel.fromJson(Map<String, dynamic>.from(map['assist_jogador']));
    }

    final String? rawTime = map['team']?.toString() ?? map['time']?.toString();
    final String? rawMinute = map['event_time']?.toString() ?? map['minute']?.toString() ?? map['tempo']?.toString() ?? map['timestamp']?.toString();
    final String? teamVal = map['team']?.toString() ?? (rawTime == 'red' || rawTime == 'white' ? rawTime : null);

    return MatchEventModel(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      matchId: map['match_id']?.toString() ?? map['partida_id']?.toString() ?? '',
      playerId: map['player_id']?.toString() ?? map['jogador_id']?.toString() ?? '',
      assistPlayerId: map['assist_player_id']?.toString() ?? map['assist_jogador_id']?.toString(),
      eventType: map['event_type']?.toString() ?? map['tipo']?.toString() ?? '',
      timestamp: rawMinute ?? rawTime,
      minute: rawMinute,
      team: teamVal,
      player: playerObj,
      assistPlayer: assistObj,
    );
  }

  Map<String, dynamic> toMap({bool includeId = false}) {
    final data = <String, dynamic>{
      'match_id': matchId,
      'player_id': playerId,
      'assist_player_id': assistPlayerId,
      'event_type': eventType,
      'team': team ?? 'red',
      if (minute != null || timestamp != null) 'event_time': minute ?? timestamp,
    };
    if (includeId && id != null) {
      data['id'] = id;
    }
    return data;
  }

  MatchEventModel copyWith({
    int? id,
    String? matchId,
    String? playerId,
    String? assistPlayerId,
    String? eventType,
    String? timestamp,
    PlayerModel? player,
    PlayerModel? assistPlayer,
  }) {
    return MatchEventModel(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      playerId: playerId ?? this.playerId,
      assistPlayerId: assistPlayerId ?? this.assistPlayerId,
      eventType: eventType ?? this.eventType,
      timestamp: timestamp ?? this.timestamp,
      player: player ?? this.player,
      assistPlayer: assistPlayer ?? this.assistPlayer,
    );
  }

  @override
  String toString() =>
      'MatchEventModel(eventType: $eventType, playerId: $playerId, assistPlayerId: $assistPlayerId, timestamp: $timestamp)';
}
