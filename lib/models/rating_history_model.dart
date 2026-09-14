import 'player_model.dart';

class RatingHistoryModel {
  final int? id;
  final String playerId;
  final String matchId;
  final double ratingChange;
  final double newRating;
  final DateTime createdAt;
  final PlayerModel? player;

  const RatingHistoryModel({
    this.id,
    required this.playerId,
    required this.matchId,
    required this.ratingChange,
    required this.newRating,
    required this.createdAt,
    this.player,
  });

  factory RatingHistoryModel.fromMap(Map<String, dynamic> map) {
    PlayerModel? playerObj;
    if (map['players'] is Map) {
      playerObj = PlayerModel.fromJson(Map<String, dynamic>.from(map['players']));
    } else if (map['jogadores'] is Map) {
      playerObj = PlayerModel.fromJson(Map<String, dynamic>.from(map['jogadores']));
    }

    return RatingHistoryModel(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      playerId: map['player_id']?.toString() ?? map['jogador_id']?.toString() ?? '',
      matchId: map['match_id']?.toString() ?? map['partida_id']?.toString() ?? '',
      ratingChange: map['rating_change'] != null
          ? double.tryParse(map['rating_change'].toString()) ?? 0.0
          : (map['mudanca_rating'] != null ? double.tryParse(map['mudanca_rating'].toString()) ?? 0.0 : 0.0),
      newRating: map['new_rating'] != null
          ? double.tryParse(map['new_rating'].toString()) ?? 6.0
          : (map['rating_resultante'] != null ? double.tryParse(map['rating_resultante'].toString()) ?? 6.0 : 6.0),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : (map['timestamp'] != null ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now() : DateTime.now()),
      player: playerObj,
    );
  }

  Map<String, dynamic> toMap({bool includeId = false}) {
    final data = <String, dynamic>{
      'player_id': playerId,
      'match_id': matchId,
      'rating_change': ratingChange,
      'new_rating': newRating,
      'created_at': createdAt.toIso8601String(),
    };
    if (includeId && id != null) {
      data['id'] = id;
    }
    return data;
  }

  RatingHistoryModel copyWith({
    int? id,
    String? playerId,
    String? matchId,
    double? ratingChange,
    double? newRating,
    DateTime? createdAt,
    PlayerModel? player,
  }) {
    return RatingHistoryModel(
      id: id ?? this.id,
      playerId: playerId ?? this.playerId,
      matchId: matchId ?? this.matchId,
      ratingChange: ratingChange ?? this.ratingChange,
      newRating: newRating ?? this.newRating,
      createdAt: createdAt ?? this.createdAt,
      player: player ?? this.player,
    );
  }

  @override
  String toString() =>
      'RatingHistoryModel(playerId: $playerId, newRating: $newRating, change: $ratingChange)';
}
