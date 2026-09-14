/// Representa uma conquista/badge atribuída a um jogador.
class PlayerBadgeModel {
  final String icon;
  final String title;
  final String? desc;

  const PlayerBadgeModel({
    required this.icon,
    required this.title,
    this.desc,
  });

  factory PlayerBadgeModel.fromMap(Map<String, dynamic> map) {
    return PlayerBadgeModel(
      icon: map['icon']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      desc: map['desc']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'icon': icon,
      'title': title,
      if (desc != null) 'desc': desc,
    };
  }

  PlayerBadgeModel copyWith({
    String? icon,
    String? title,
    String? desc,
  }) {
    return PlayerBadgeModel(
      icon: icon ?? this.icon,
      title: title ?? this.title,
      desc: desc ?? this.desc,
    );
  }

  @override
  String toString() => 'PlayerBadgeModel(title: $title, icon: $icon)';
}
