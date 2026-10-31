import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/group_member_model.dart';
import '../models/group_model.dart';

import '../domain/services/permission_service.dart';
import 'supabase_service.dart';

/// Repository responsible for the `group_members` table.
class GroupMembersRepository {
  final SupabaseClient _client;
  final PermissionService _permissions;

  GroupMembersRepository({
    SupabaseClient? client,
    PermissionService? permissions,
  })  : _client = client ?? supabase,
        _permissions = permissions ?? SupabaseService.permissions;

  /// Returns all members of a group, including their Player data.
  Future<List<GroupMemberModel>> getMembers(String groupId) async {
    final response = await _client
        .from('group_members')
        .select('*, players(*)')
        .eq('group_id', groupId)
        .order('joined_at', ascending: true);

    return (response as List)
        .whereType<Map>()
        .map((item) => GroupMemberModel.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Returns the member record corresponding to the currently authenticated user in the group.
  Future<GroupMemberModel?> getMyMembership(String groupId) async {
    final currentUserId = SupabaseConfig.currentUserId;
    if (currentUserId == null) return null;

    final response = await _client
        .from('group_members')
        .select('*, players!inner(*)')
        .eq('group_id', groupId)
        .eq('players.creator_id', currentUserId)
        .maybeSingle();

    if (response == null) return null;
    return GroupMemberModel.fromMap(Map<String, dynamic>.from(response));
  }

  /// Promotes a player to 'admin'.
  Future<void> promoteToAdmin({
    required String groupId,
    required String playerId,
  }) async {
    await _permissions.requireAdmin(
      groupId,
      'Access denied: Only administrators can promote other users to admin.',
    );

    await _client
        .from('group_members')
        .update({'role': GroupMemberModel.roleAdmin})
        .eq('group_id', groupId)
        .eq('player_id', playerId);
  }

  /// Demotes a player to a common 'member'.
  Future<void> demoteToMember({
    required String groupId,
    required String playerId,
  }) async {
    await _permissions.requireAdmin(
      groupId,
      'Access denied: Only administrators can change member roles.',
    );

    await _client
        .from('group_members')
        .update({'role': GroupMemberModel.roleMember})
        .eq('group_id', groupId)
        .eq('player_id', playerId);
  }

  /// Adds an existing player as a member of the group.
  Future<GroupMemberModel> addMember({
    required String groupId,
    required String playerId,
    String role = GroupMemberModel.roleMember,
  }) async {
    final response = await _client
        .from('group_members')
        .insert({
          'group_id': groupId,
          'player_id': playerId,
          'role': role,
        })
        .select('*, players(*)')
        .single();

    return GroupMemberModel.fromMap(Map<String, dynamic>.from(response));
  }

  /// Removes a player from the group.
  Future<void> removeMember({
    required String groupId,
    required String playerId,
  }) async {
    await _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('player_id', playerId);
  }

  // ---------------------------------------------------------------
  // Join-by-code flow (pending admin approval)
  // ---------------------------------------------------------------

  /// Looks up a group by its invite code (used before creating the request,
  /// so the UI can show "Você está solicitando entrada em <name>").
  /// Usa uma função RPC (SECURITY DEFINER) em vez de um `select` direto,
  /// porque a RLS da tabela `groups` só libera leitura pra quem já é
  /// membro -- e quem está entrando ainda não é.
  Future<GroupModel?> findGroupByCode(String code) async {
    final response = await _client
        .rpc('find_group_by_invite_code', params: {'code': code.trim().toUpperCase()});

    final list = (response as List?) ?? [];
    if (list.isEmpty) return null;
    return GroupModel.fromMap(Map<String, dynamic>.from(list.first as Map));
  }

  /// Sends a join request for the currently authenticated user.
  Future<void> requestToJoin({
    required String inviteCode,
    required String desiredName,
  }) async {
    final currentUserId = SupabaseConfig.currentUserId;
    if (currentUserId == null) {
      throw Exception('Você precisa estar logado para solicitar entrada em um grupo.');
    }

    final group = await findGroupByCode(inviteCode);
    if (group == null) {
      throw Exception('Código de convite inválido.');
    }

    await _client.from('group_join_requests').insert({
      'group_id': group.id,
      'user_id': currentUserId,
      'requested_name': desiredName.trim(),
    });
  }

  /// Pending join requests for a group (admin-only view; enforced by RLS).
  Future<List<Map<String, dynamic>>> listPendingRequests(String groupId) async {
    final response = await _client
        .from('group_join_requests')
        .select()
        .eq('group_id', groupId)
        .eq('status', 'pending')
        .order('created_at');
    return (response as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Approves a request, optionally linking it to an existing "ghost" player
  /// instead of creating a brand new one.
  Future<void> approveRequest(String requestId, {String? existingPlayerId}) async {
    await _client.rpc('approve_join_request', params: {
      'request_id': requestId,
      'existing_player_id': existingPlayerId,
    });
  }

  Future<void> rejectRequest(String requestId) async {
    await _client.rpc('reject_join_request', params: {'request_id': requestId});
  }
}
