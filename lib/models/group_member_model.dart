import 'player_model.dart';

/// Model for the `group_members` table in Supabase PostgreSQL.
class GroupMemberModel {
  static const String roleAdmin = 'admin';
  static const String roleMember = 'member';

  final String id;
  final String groupId;
  final String playerId;
  final String role;
  final DateTime? joinedAt;
  final PlayerModel? player;

  const GroupMemberModel({
    required this.id,
    required this.groupId,
    required this.playerId,
    this.role = roleMember,
    this.joinedAt,
    this.player,
  });

  /// Legacy compat getters
  String get grupoId => groupId;
  String get jogadorId => playerId;
  String get papel => role;
  DateTime? get dataIngresso => joinedAt;
  PlayerModel? get jogador => player;

  /// Indicates if the member has Admin privileges in the group.
  bool get isAdmin => role.trim().toLowerCase() == roleAdmin || role.trim().toLowerCase() == 'admin';

  /// Indicates if it's a common member.
  bool get isMember => role.trim().toLowerCase() == roleMember || role.trim().toLowerCase() == 'membro';

  factory GroupMemberModel.fromMap(Map<String, dynamic> map) {
    PlayerModel? associatedPlayer;
    // Map could still join with 'players' or 'jogadores' depending on how the view is set up,
    // assuming 'players' since everything is migrating to English. 
    // Fallback to 'jogadores' in case the table hasn't been renamed yet in the join.
    if (map['players'] is Map) {
      associatedPlayer =
          PlayerModel.fromMap(Map<String, dynamic>.from(map['players']));
    } else if (map['jogadores'] is Map) {
      associatedPlayer =
          PlayerModel.fromMap(Map<String, dynamic>.from(map['jogadores']));
    }

    // Role migration compat
    String mappedRole = map['role']?.toString().toLowerCase() ?? map['papel']?.toString().toLowerCase() ?? roleMember;
    if (mappedRole == 'membro') mappedRole = roleMember;

    return GroupMemberModel(
      id: map['id']?.toString() ?? '',
      groupId: map['group_id']?.toString() ?? map['grupo_id']?.toString() ?? '',
      playerId: map['player_id']?.toString() ?? map['jogador_id']?.toString() ?? '',
      role: mappedRole,
      joinedAt: map['joined_at'] != null
          ? DateTime.tryParse(map['joined_at'].toString())
          : (map['data_ingresso'] != null ? DateTime.tryParse(map['data_ingresso'].toString()) : null),
      player: associatedPlayer,
    );
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    final data = <String, dynamic>{
      'group_id': groupId,
      'player_id': playerId,
      'role': role,
    };
    if (includeId && id.isNotEmpty) {
      data['id'] = id;
    }
    if (joinedAt != null) {
      data['joined_at'] = joinedAt!.toIso8601String();
    }
    return data;
  }

  GroupMemberModel copyWith({
    String? id,
    String? groupId,
    String? playerId,
    String? role,
    DateTime? joinedAt,
    PlayerModel? player,
  }) {
    return GroupMemberModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      playerId: playerId ?? this.playerId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      player: player ?? this.player,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupMemberModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'GroupMemberModel(id: $id, groupId: $groupId, playerId: $playerId, role: $role)';
}
