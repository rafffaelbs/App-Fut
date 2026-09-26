/// Represents an achievement/badge assigned to a player.
class PlayerBadgeModel {
  final String? id;
  final String icon;
  final String title;
  final String? desc;

  const PlayerBadgeModel({
    this.id,
    required this.icon,
    required this.title,
    this.desc,
  });

  factory PlayerBadgeModel.fromMap(Map<String, dynamic> map) {
    return PlayerBadgeModel(
      id: map['id']?.toString(),
      icon: map['icon']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      desc: map['desc']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'icon': icon,
      'title': title,
      if (desc != null) 'desc': desc,
    };
  }

  PlayerBadgeModel copyWith({
    String? id,
    String? icon,
    String? title,
    String? desc,
  }) {
    return PlayerBadgeModel(
      id: id ?? this.id,
      icon: icon ?? this.icon,
      title: title ?? this.title,
      desc: desc ?? this.desc,
    );
  }

  @override
  String toString() => 'PlayerBadgeModel(id: $id, title: $title, icon: $icon)';
}
