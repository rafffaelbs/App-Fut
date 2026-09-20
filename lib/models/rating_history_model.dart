import 'player_model.dart';

class RatingHistoryModel {
  final String? id;
  final String playerId;
  final String groupId;
  final String? matchId;
  final double rating;
  final DateTime recordedAt;
  final PlayerModel? player;

  const RatingHistoryModel({
    this.id,
    required this.playerId,
    required this.groupId,
    this.matchId,
    required this.rating,
    required this.recordedAt,
    this.player,
  });

  // Legacy aliases (kept in case any older UI code still reads these).
  double get newRating => rating;
  DateTime get createdAt => recordedAt;

  factory RatingHistoryModel.fromMap(Map<String, dynamic> map) {
    PlayerModel? playerObj;
    if (map['players'] is Map) {
      playerObj = PlayerModel.fromJson(Map<String, dynamic>.from(map['players']));
    } else if (map['jogadores'] is Map) {
      playerObj = PlayerModel.fromJson(Map<String, dynamic>.from(map['jogadores']));
    }

    return RatingHistoryModel(
      id: map['id']?.toString(),
      playerId: map['player_id']?.toString() ?? map['jogador_id']?.toString() ?? '',
      groupId: map['group_id']?.toString() ?? '',
      matchId: map['match_id']?.toString() ?? map['partida_id']?.toString(),
      rating: map['rating'] != null
          ? double.tryParse(map['rating'].toString()) ?? 6.0
          : (map['new_rating'] != null ? double.tryParse(map['new_rating'].toString()) ?? 6.0 : 6.0),
      recordedAt: map['recorded_at'] != null
          ? DateTime.tryParse(map['recorded_at'].toString()) ?? DateTime.now()
          : (map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now()),
      player: playerObj,
    );
  }

  Map<String, dynamic> toMap({bool includeId = false}) {
    final data = <String, dynamic>{
      'player_id': playerId,
      'group_id': groupId,
      'match_id': matchId,
      'rating': rating,
      'recorded_at': recordedAt.toIso8601String(),
    };
    if (includeId && id != null) {
      data['id'] = id;
    }
    return data;
  }

  RatingHistoryModel copyWith({
    String? id,
    String? playerId,
    String? groupId,
    String? matchId,
    double? rating,
    DateTime? recordedAt,
    PlayerModel? player,
  }) {
    return RatingHistoryModel(
      id: id ?? this.id,
      playerId: playerId ?? this.playerId,
      groupId: groupId ?? this.groupId,
      matchId: matchId ?? this.matchId,
      rating: rating ?? this.rating,
      recordedAt: recordedAt ?? this.recordedAt,
      player: player ?? this.player,
    );
  }

  @override
  String toString() =>
      'RatingHistoryModel(playerId: $playerId, rating: $rating)';
}
