/// Model for the `groups` table in Supabase PostgreSQL.
class GroupModel {
  final String id;
  final String name;
  final String? creatorId;
  final String? inviteCode;
  final DateTime? createdAt;

  const GroupModel({
    required this.id,
    required this.name,
    this.creatorId,
    this.inviteCode,
    this.createdAt,
  });

  /// Getter for legacy UI compatibility if needed.

  factory GroupModel.fromMap(Map<String, dynamic> map) {
    return GroupModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      creatorId: map['creator_id']?.toString(),
      inviteCode: map['invite_code']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    final data = <String, dynamic>{
      'name': name,
      'creator_id': creatorId,
    };
    if (includeId && id.isNotEmpty) {
      data['id'] = id;
    }
    if (createdAt != null) {
      data['created_at'] = createdAt!.toIso8601String();
    }
    return data;
  }

  GroupModel copyWith({
    String? id,
    String? name,
    String? creatorId,
    String? inviteCode,
    DateTime? createdAt,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      creatorId: creatorId ?? this.creatorId,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'GroupModel(id: $id, name: $name)';
}
