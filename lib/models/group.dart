import 'json_parsers.dart';

class Group {
  final String id;
  final String name;
  final String createdAt;

  const Group({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  /// Cria uma nova [Group] a partir do JSON persistido em `app_groups`.
  ///
  /// Compatível com as chaves legadas: `id`, `name`, `createdAt`.
  /// Campos ausentes recebem fallbacks defensivos.
  factory Group.fromJson(Map<String, dynamic> json) {
    final String? rawId = parseString(json['id']);
    return Group(
      id: rawId != null && rawId.trim().isNotEmpty
          ? rawId
          : _fallbackId(json['name']),
      name: parseString(json['name']) ?? '',
      createdAt: parseString(json['createdAt']) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'createdAt': createdAt,
    };
  }

  static String _fallbackId(dynamic rawName) {
    return 'sem_id_${rawName.toString().hashCode}';
  }

  Group copyWith({
    String? id,
    String? name,
    String? createdAt,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}