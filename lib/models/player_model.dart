import 'player_badge_model.dart';

/// Data model for the `players` table in Supabase PostgreSQL.
class PlayerModel {
  final String id;
  final String? creatorId;
  final String name;
  final String? email;
  final DateTime? createdAt;
  
  // Transient properties for UI compatibility
  final String? icon;
  final double? rating;
  final int? totalGames;
  final List<PlayerBadgeModel> manualBadges;
  /// URL (Supabase Storage, bucket `goal-sounds`) do áudio customizado de gol
  /// deste jogador. Null = usa o som genérico padrão do app.
  final String? goalSoundUrl;
  /// Efeito visual aplicado ao nome do jogador em qualquer lugar que ele
  /// apareça. Mutuamente exclusivo: 'gold' | 'silver' | 'bronze' | null.
  final String? nameEffect;
  /// Selo/anel de destaque de "craque do mês", exibido só no pódio do
  /// ranking (top posições).
  final bool monthlyHighlight;

  const PlayerModel({
    required this.id,
    this.creatorId,
    required this.name,
    this.email,
    this.createdAt,
    this.icon,
    this.rating,
    this.totalGames,
    this.manualBadges = const [],
    this.goalSoundUrl,
    this.nameEffect,
    this.monthlyHighlight = false,
  });

  /// Indicates whether this is a "Ghost Player" (created by a user, without their own login).
  bool get isGhost => creatorId == null || creatorId!.trim().isEmpty;

  /// Defensive display name.
  String get displayName => name.trim().isEmpty ? 'Jogador sem nome' : name;

  // Compatibility getters
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
      email: map['email']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      icon: map['icon']?.toString() ?? map['avatar_url']?.toString(),
      rating: map['rating'] != null ? double.tryParse(map['rating'].toString()) : null,
      totalGames: map['totalGames'] != null ? int.tryParse(map['totalGames'].toString()) : null,
      manualBadges: parsedBadges,
      goalSoundUrl: map['goal_sound_url']?.toString(),
      nameEffect: map['name_effect']?.toString(),
      monthlyHighlight: map['monthly_highlight'] == true ||
          map['monthly_highlight']?.toString() == 'true',
    );
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    final data = <String, dynamic>{
      'creator_id': creatorId,
      'name': name,
      'icon': icon,
      'manual_badges': manualBadges.map((b) => b.toMap()).toList(),
      'goal_sound_url': goalSoundUrl,
      'name_effect': nameEffect,
      'monthly_highlight': monthlyHighlight,
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
    String? goalSoundUrl,
    bool clearGoalSoundUrl = false,
    String? nameEffect,
    bool clearNameEffect = false,
    bool? monthlyHighlight,
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
      goalSoundUrl: clearGoalSoundUrl ? null : (goalSoundUrl ?? this.goalSoundUrl),
      nameEffect: clearNameEffect ? null : (nameEffect ?? this.nameEffect),
      monthlyHighlight: monthlyHighlight ?? this.monthlyHighlight,
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
