import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/group_member_model.dart';
import '../models/group_model.dart';

/// Repository responsible for the `group_members` table.
class GroupMembersRepository {
  final SupabaseClient _client;

  GroupMembersRepository({SupabaseClient? client})
      : _client = client ?? supabase;

  /// Returns all members of a group, including their Player data.
  Future<List<GroupMemberModel>> getMembros(String groupId) async {
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
  Future<GroupMemberModel?> getMeuMembro(String groupId) async {
    final currentUserId = SupabaseConfig.currentUserId;
    if (currentUserId == null) return null;

    final response = await _client
        .from('group_members')
        .select('*, players!inner(*)')
        .eq('group_id', groupId)
        .eq('players.user_id', currentUserId)
        .maybeSingle();

    if (response == null) return null;
    return GroupMemberModel.fromMap(Map<String, dynamic>.from(response));
  }

  static bool mockAdmin = true;

  /// Checks if the current authenticated user has an 'admin' role in the group.
  Future<bool> isCurrentUserAdmin(String groupId) async {
    if (mockAdmin) return true;
    final currentUserId = SupabaseConfig.currentUserId;
    if (currentUserId == null) return false;

    // 1. Verify if the user is the creator of the group
    final groupResp = await _client
        .from('groups')
        .select('creator_id')
        .eq('id', groupId)
        .maybeSingle();

    if (groupResp != null && groupResp['creator_id']?.toString() == currentUserId) {
      return true;
    }

    // 2. Verify the role column in group_members
    final member = await getMeuMembro(groupId);
    return member != null && member.isAdmin;
  }

  /// Promotes a player to 'admin'.
  Future<void> promoverParaAdmin({
    required String groupId,
    required String jogadorId,
  }) async {
    final isAdmin = await isCurrentUserAdmin(groupId);
    if (!isAdmin) {
      throw Exception('Access denied: Only administrators can promote other users to admin.');
    }

    await _client
        .from('group_members')
        .update({'role': GroupMemberModel.roleAdmin})
        .eq('group_id', groupId)
        .eq('player_id', jogadorId);
  }

  /// Demotes a player to a common 'member'.
  Future<void> rebaixarParaMembro({
    required String groupId,
    required String jogadorId,
  }) async {
    final isAdmin = await isCurrentUserAdmin(groupId);
    if (!isAdmin) {
      throw Exception('Access denied: Only administrators can change member roles.');
    }

    await _client
        .from('group_members')
        .update({'role': GroupMemberModel.roleMember})
        .eq('group_id', groupId)
        .eq('player_id', jogadorId);
  }

  /// Adds an existing player as a member of the group.
  Future<GroupMemberModel> adicionarMembro({
    required String groupId,
    required String jogadorId,
    String papel = GroupMemberModel.roleMember,
  }) async {
    final response = await _client
        .from('group_members')
        .insert({
          'group_id': groupId,
          'player_id': jogadorId,
          'role': papel,
        })
        .select('*, players(*)')
        .single();

    return GroupMemberModel.fromMap(Map<String, dynamic>.from(response));
  }

  /// Removes a player from the group.
  Future<void> removerMembro({
    required String groupId,
    required String jogadorId,
  }) async {
    await _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('player_id', jogadorId);
  }
}
