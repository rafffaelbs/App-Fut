import '../utils/overall_calculator.dart';
import 'cosmetic_effect.dart';
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
  /// Para 'fire' e 'diamond', veja [advancedStats] e [nameEffectFull].
  final String? nameEffect;
  /// Selo/anel de destaque de "craque do mês", exibido só no pódio do
  /// ranking (top posições).
  final bool monthlyHighlight;

  /// Bola de Ouro (melhor da temporada) — coluna `golden_ball`. Enquanto a
  /// migração 001 não rodar, lê o legado `advanced_stats.bola_de_ouro`.
  final bool goldenBall;

  /// Craque do Mês: 0 = sem; 1 a 6 estrelas — coluna `monthly_star_count`.
  /// Enquanto a migração 001 não rodar, deriva de `monthly_highlight` +
  /// `advanced_stats.craque_mes_count`.
  final int monthlyStarCount;

  /// Dados extras armazenados no campo `advanced_stats` (jsonb) do Supabase.
  /// Usado para: efeitos de nome não suportados pelo CHECK do DB (fire, diamond),
  /// craque_mes_count, e futuras extensões sem migração de schema.
  final Map<String, dynamic> advancedStats;

  /// Atributos da comunidade (0-100), votados pela turma e inseridos por um
  /// admin. Todos nulos = jogador ainda sem avaliação da comunidade.
  final int? communityPac;
  final int? communitySho;
  final int? communityPas;
  final int? communityDri;
  final int? communityDef;
  final int? communityPhy;

  /// Quando preenchido, substitui a média dos 6 atributos como Nota da
  /// Comunidade (0-100).
  final double? communityRatingOverride;

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
    this.goldenBall = false,
    this.monthlyStarCount = 0,
    this.advancedStats = const {},
    this.communityPac,
    this.communitySho,
    this.communityPas,
    this.communityDri,
    this.communityDef,
    this.communityPhy,
    this.communityRatingOverride,
  });


  /// Indicates whether this is a "Ghost Player" (created by a user, without their own login).
  bool get isGhost => creatorId == null || creatorId!.trim().isEmpty;

  /// Defensive display name.
  String get displayName => name.trim().isEmpty ? 'Jogador sem nome' : name;

  /// Atributos da comunidade agrupados (usados no cálculo do Overall e no card).
  CommunityAttributes get community => CommunityAttributes(
        pac: communityPac,
        sho: communitySho,
        pas: communityPas,
        dri: communityDri,
        def: communityDef,
        phy: communityPhy,
        ratingOverride: communityRatingOverride,
      );

  // Compatibility getters
  String? get avatarUrl => icon;

  /// Efeito de nome completo, incluindo 'fire' e 'diamond' armazenados em
  /// [advancedStats] (o constraint do banco não permite esses valores em [nameEffect]).
  String? get nameEffectFull {
    final extra = advancedStats['name_effect_extra']?.toString();
    if (extra != null && extra.isNotEmpty) return extra;
    return nameEffect;
  }

  /// Efeito de nome como enum (inclui fire/diamond legados de [advancedStats]).
  CosmeticEffect get cosmeticEffect => CosmeticEffect.fromDb(nameEffectFull);

  /// Número de vezes que o jogador ganhou Craque do Mês (armazenado em [advancedStats]).
  int get craqueDoMesCount =>
      (advancedStats['craque_mes_count'] as num?)?.toInt() ?? 1;

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

    final adv = map['advanced_stats'] is Map
        ? Map<String, dynamic>.from(map['advanced_stats'] as Map)
        : const <String, dynamic>{};
    final monthlyHighlight = map['monthly_highlight'] == true ||
        map['monthly_highlight']?.toString() == 'true';

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
      monthlyHighlight: monthlyHighlight,
      goldenBall: map['golden_ball'] != null
          ? (map['golden_ball'] == true ||
              map['golden_ball']?.toString() == 'true')
          : adv['bola_de_ouro'] == true,
      monthlyStarCount: _starCount(map['monthly_star_count'], monthlyHighlight,
          adv['craque_mes_count']),
      advancedStats: adv,
      communityPac: _asInt(map['community_pac']),
      communitySho: _asInt(map['community_sho']),
      communityPas: _asInt(map['community_pas']),
      communityDri: _asInt(map['community_dri']),
      communityDef: _asInt(map['community_def']),
      communityPhy: _asInt(map['community_phy']),
      communityRatingOverride: map['community_rating_override'] != null
          ? double.tryParse(map['community_rating_override'].toString())
          : null,
    );
  }

  /// Coluna nova tem prioridade; se for 0/ausente, cai no legado
  /// (`monthly_highlight` + `craque_mes_count`, padrão 1 estrela).
  static int _starCount(dynamic column, bool legacyHighlight, dynamic legacyCount) {
    final fromColumn = _asInt(column) ?? 0;
    if (fromColumn > 0) return fromColumn.clamp(0, 6);
    if (!legacyHighlight) return 0;
    return (_asInt(legacyCount) ?? 1).clamp(1, 6);
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }

  /// Colunas `community_*` (para atualizar via PlayersRepository.setCommunityAttributes).
  /// Não entram em [toMap] de propósito: assim nenhum update genérico do
  /// jogador sobrescreve (ou zera) as notas da comunidade sem querer.
  Map<String, dynamic> communityToMap() => {
        'community_pac': communityPac,
        'community_sho': communitySho,
        'community_pas': communityPas,
        'community_dri': communityDri,
        'community_def': communityDef,
        'community_phy': communityPhy,
        'community_rating_override': communityRatingOverride,
      };

  /// Colunas novas de cosméticos (migração 001). Fora de [toMap] de propósito:
  /// enquanto a migração não rodar, um update genérico falharia com coluna
  /// inexistente. Use via PlayersRepository.setCosmetics.
  Map<String, dynamic> cosmeticsToMap() => {
        'golden_ball': goldenBall,
        'name_effect': cosmeticEffect.dbValue,
        'monthly_star_count': monthlyStarCount,
      };

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
    bool? goldenBall,
    int? monthlyStarCount,
    Map<String, dynamic>? advancedStats,
    CommunityAttributes? community,
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
      goldenBall: goldenBall ?? this.goldenBall,
      monthlyStarCount: monthlyStarCount ?? this.monthlyStarCount,
      advancedStats: advancedStats ?? this.advancedStats,
      communityPac: community != null ? community.pac : communityPac,
      communitySho: community != null ? community.sho : communitySho,
      communityPas: community != null ? community.pas : communityPas,
      communityDri: community != null ? community.dri : communityDri,
      communityDef: community != null ? community.def : communityDef,
      communityPhy: community != null ? community.phy : communityPhy,
      communityRatingOverride: community != null
          ? community.ratingOverride
          : communityRatingOverride,
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
