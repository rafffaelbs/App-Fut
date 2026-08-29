import 'json_parsers.dart';

class MatchEvent {
  static const String typeGoal = 'goal';
  static const String typeOwnGoal = 'own_goal';
  static const String typeYellowCard = 'yellow_card';
  static const String typeRedCard = 'red_card';

  final String type;
  final String? team;
  final String? player;
  final String? playerId;
  final String? assist;
  final String? assistId;
  final String? time;

  const MatchEvent({
    required this.type,
    this.team,
    this.player,
    this.playerId,
    this.assist,
    this.assistId,
    this.time,
  });

  /// Cria um [MatchEvent] a partir do JSON salvo em `match_history_{tId}`
  /// (sub-array `events`).
  ///
  /// Compatível com as chaves legadas:
  /// `type`, `team`, `player`, `playerId`, `assist`, `assistId`, `time`.
  factory MatchEvent.fromJson(Map<String, dynamic> json) {
    return MatchEvent(
      type: parseString(json['type']) ?? '',
      team: parseString(json['team']),
      player: parseString(json['player']),
      playerId: parseString(json['playerId']),
      assist: parseString(json['assist']),
      assistId: parseString(json['assistId']),
      time: parseString(json['time']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      if (team != null) 'team': team,
      if (player != null) 'player': player,
      if (playerId != null) 'playerId': playerId,
      if (assist != null) 'assist': assist,
      if (assistId != null) 'assistId': assistId,
      if (time != null) 'time': time,
    };
  }

  /// Id do jogador responsável pelo evento, priorizando `playerId`
  /// (chave nova) e caindo para `player` (nome legado).
  String get resolvedPlayerId {
    final String? explicitId = playerId;
    if (explicitId != null && explicitId.trim().isNotEmpty) return explicitId;
    return player?.toString() ?? '';
  }

  /// Id do assistente, priorizando `assistId` e caindo para `assist`.
  String get resolvedAssistId {
    final String? explicitId = assistId;
    if (explicitId != null && explicitId.trim().isNotEmpty) return explicitId;
    return assist?.toString() ?? '';
  }

  bool get isGoal => type == typeGoal;
  bool get isOwnGoal => type == typeOwnGoal;
  bool get isYellowCard => type == typeYellowCard;
  bool get isRedCard => type == typeRedCard;
}