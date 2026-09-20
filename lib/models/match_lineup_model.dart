import 'player_model.dart';

class MatchLineupModel {
  static const String teamA = 'Team A';
  static const String teamB = 'Team B';

  final int? id;
  final String matchId;
  final String playerId;
  final String team;
  final bool isGoalkeeper;
  final double? rating;
  final PlayerModel? player;

  const MatchLineupModel({
    this.id,
    required this.matchId,
    required this.playerId,
    required this.team,
    this.isGoalkeeper = false,
    this.rating,
    this.player,
  });

  bool get isTeamA => team == teamA || team.toLowerCase() == "vermelho" || team.toLowerCase() == "red";
  bool get isTeamB => team == teamB || team.toLowerCase() == "branco" || team.toLowerCase() == "white";

  bool get isRed => isTeamA;
  bool get isWhite => isTeamB;

  factory MatchLineupModel.fromMap(Map<String, dynamic> map) {
    PlayerModel? playerObj;
    if (map["players"] is Map) {
      playerObj = PlayerModel.fromJson(Map<String, dynamic>.from(map["players"]));
    } else if (map["jogadores"] is Map) {
      playerObj = PlayerModel.fromJson(Map<String, dynamic>.from(map["jogadores"]));
    }

    return MatchLineupModel(
      id: map["id"] != null ? int.tryParse(map["id"].toString()) : null,
      matchId: map["match_id"]?.toString() ?? map["partida_id"]?.toString() ?? "",
      playerId: map["player_id"]?.toString() ?? map["jogador_id"]?.toString() ?? "",
      team: map["team"]?.toString() ?? map["time"]?.toString() ?? teamA,
      isGoalkeeper: map["is_goalkeeper"] == true || map["is_goleiro"] == true,
      rating: map["rating_snapshot"] != null
          ? double.tryParse(map["rating_snapshot"].toString())
          : (map["rating"] != null
              ? double.tryParse(map["rating"].toString())
              : (map["nota_partida"] != null
                  ? double.tryParse(map["nota_partida"].toString())
                  : null)),
      player: playerObj,
    );
  }

  Map<String, dynamic> toMap({bool includeId = false}) {
    final data = <String, dynamic>{
      "match_id": matchId,
      "player_id": playerId,
      "team": isTeamA ? "red" : "white",
      "is_goalkeeper": isGoalkeeper,
      if (rating != null) "rating_snapshot": rating,
    };
    if (includeId && id != null) {
      data["id"] = id;
    }
    return data;
  }

  MatchLineupModel copyWith({
    int? id,
    String? matchId,
    String? playerId,
    String? team,
    bool? isGoalkeeper,
    double? rating,
    PlayerModel? player,
  }) {
    return MatchLineupModel(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      playerId: playerId ?? this.playerId,
      team: team ?? this.team,
      isGoalkeeper: isGoalkeeper ?? this.isGoalkeeper,
      rating: rating ?? this.rating,
      player: player ?? this.player,
    );
  }
}
