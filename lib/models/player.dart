import 'json_parsers.dart';

class PlayerBadge {
  final String icon;
  final String title;
  final String? desc;

  const PlayerBadge({
    required this.icon,
    required this.title,
    this.desc,
  });

  /// Badges manuais são persistidos como `{icon, title, desc?}`.
  factory PlayerBadge.fromJson(Map<String, dynamic> json) {
    return PlayerBadge(
      icon: parseString(json['icon']) ?? '',
      title: parseString(json['title']) ?? '',
      desc: parseString(json['desc']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'icon': icon,
      'title': title,
      if (desc != null) 'desc': desc,
    };
  }
}

class Player {
  final String id;
  final String name;
  final String? icon;
  final double? rating;
  final int? totalGames;
  final List<PlayerBadge> manualBadges;

  const Player({
    required this.id,
    required this.name,
    this.icon,
    this.rating,
    this.totalGames,
    this.manualBadges = const [],
  });

  /// Cria um [Player] a partir do JSON persistido em `players_{groupId}`.
  ///
  /// Compatível com as chaves legadas:
  /// `id`, `name`, `icon`, `rating`, `totalGames`, `manual_badges`.
  /// Segue a regra de `player_identity.dart`: id vazio/ausente vira fallback
  /// para `name`.
  factory Player.fromJson(Map<String, dynamic> json) {
    final String? rawId = parseString(json['id']);
    final String rawName = parseString(json['name']) ?? '';
    return Player(
      id: rawId != null && rawId.trim().isNotEmpty ? rawId : rawName,
      name: rawName,
      icon: parseString(json['icon']),
      rating: json['rating'] != null ? parseDouble(json['rating']) : null,
      totalGames: json['totalGames'] != null ? parseInt(json['totalGames']) : null,
      manualBadges: parseMapList(json['manual_badges'])
          .map(PlayerBadge.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      if (icon != null) 'icon': icon,
      if (rating != null) 'rating': rating,
      if (totalGames != null) 'totalGames': totalGames,
      if (manualBadges.isNotEmpty)
        'manual_badges': manualBadges.map((badge) => badge.toJson()).toList(),
    };
  }

  String get displayName => name.isEmpty ? 'Desconhecido' : name;

  Player copyWith({
    String? id,
    String? name,
    String? icon,
    double? rating,
    int? totalGames,
    List<PlayerBadge>? manualBadges,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      rating: rating ?? this.rating,
      totalGames: totalGames ?? this.totalGames,
      manualBadges: manualBadges ?? this.manualBadges,
    );
  }
}