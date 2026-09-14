import 'player_badge_model.dart';

/// Modelo de dados da tabela `players` no Supabase PostgreSQL.
class PlayerModel {
  final String id;
  final String? creatorId;
  final String name;
  final DateTime? createdAt;
  
  // Transient properties for UI compatibility
  final String? icon;
  final double? rating;
  final int? totalGames;
  final List<PlayerBadgeModel> manualBadges;

  const PlayerModel({
    required this.id,
    this.creatorId,
    required this.name,
    this.createdAt,
    this.icon,
    this.rating,
    this.totalGames,
    this.manualBadges = const [],
  });

  /// Indica se é um "Jogador Fantasma" (criado por um usuário, sem login próprio).
  bool get isGhost => creatorId == null || creatorId!.trim().isEmpty;

  /// Nome de exibição defensivo.
  String get displayName => name.trim().isEmpty ? 'Jogador sem nome' : name;

  // Compatibility getters
  String get nome => name;
  String? get avatarUrl => icon;

  factory PlayerModel.fromJson(Map<String, dynamic> json) => PlayerModel.fromMap(json);
  Map<String, dynamic> toJson() => toMap();

  factory PlayerModel.fromMap(Map<String, dynamic> map) {
    List<PlayerBadgeModel> parsedBadges = [];
    final rawBadges = map['manual_badges'] ?? map['badges'];
    if (rawBadges is List) {
      parsedBadges = rawBadges
          .whereType<Map>()
          .map((item) => PlayerBadgeModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    return PlayerModel(
      id: map['id']?.toString() ?? '',
      creatorId: map['creator_id']?.toString(),
      name: map['name']?.toString() ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      icon: map['icon']?.toString() ?? map['avatar_url']?.toString(),
      rating: map['rating'] != null ? double.tryParse(map['rating'].toString()) : null,
      totalGames: map['totalGames'] != null ? int.tryParse(map['totalGames'].toString()) : null,
      manualBadges: parsedBadges,
    );
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    final data = <String, dynamic>{
      'creator_id': creatorId,
      'name': name,
    };
    if (includeId && id.isNotEmpty) {
      data['id'] = id;
    }
    if (createdAt != null) {
      data['created_at'] = createdAt!.toIso8601String();
    }
    return data;
  }

  PlayerModel copyWith({
    String? id,
    String? creatorId,
    String? name,
    DateTime? createdAt,
    String? icon,
    double? rating,
    int? totalGames,
    List<PlayerBadgeModel>? manualBadges,
  }) {
    return PlayerModel(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      icon: icon ?? this.icon,
      rating: rating ?? this.rating,
      totalGames: totalGames ?? this.totalGames,
      manualBadges: manualBadges ?? this.manualBadges,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PlayerModel(id: $id, name: $name)';
}
