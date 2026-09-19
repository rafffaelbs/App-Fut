import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/supabase_config.dart';
import '../models/group_model.dart';
import '../models/player_model.dart';
import '../models/group_member_model.dart';
import 'group_members_repository.dart';

/// Groups repository integrated with Supabase PostgreSQL.
class GroupsRepository {
  final SupabaseClient _client;
  final GroupMembersRepository _membersRepo;

  GroupsRepository({
    SupabaseClient? client,
    GroupMembersRepository? membersRepo,
  })  : _client = client ?? supabase,
        _membersRepo = membersRepo ?? GroupMembersRepository(client: client);

  /// Returns groups that the authenticated user is a part of or created.
  Future<List<GroupModel>> getMyGroups() async {
    final currentUserId = SupabaseConfig.currentUserId;

    if (currentUserId == null) {
      final response = await _client.from('groups').select().order('created_at');
      return (response as List)
          .whereType<Map>()
          .map((item) => GroupModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    // 1. Groups created by the user
    final creatorResponse = await _client
        .from('groups')
        .select()
        .eq('creator_id', currentUserId);

    final Set<String> groupIds = {};
    final List<GroupModel> result = [];

    for (final item in (creatorResponse as List)) {
      final group = GroupModel.fromMap(Map<String, dynamic>.from(item));
      groupIds.add(group.id);
      result.add(group);
    }

    // 2. Groups where the user is a member
    final memberResponse = await _client
        .from('group_members')
        .select('groups(*), players!inner(creator_id)')
        .eq('players.creator_id', currentUserId);

    for (final item in (memberResponse as List)) {
      if (item is Map && item['groups'] is Map) {
        final group = GroupModel.fromMap(Map<String, dynamic>.from(item['groups']));
        if (!groupIds.contains(group.id)) {
          groupIds.add(group.id);
          result.add(group);
        }
      }
    }

    return result;
  }

  /// Generates a short, human-friendly invite code (e.g. "K7QX2P").
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I to avoid confusion
    final rnd = Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  /// Creates a new group. The creator automatically becomes its admin.
  Future<GroupModel> createGroup({
    required String name,
    String? adminPlayerName,
  }) async {
    final currentUserId = SupabaseConfig.currentUserId;
    if (currentUserId == null) {
      throw Exception('Você precisa estar logado para criar um grupo.');
    }

    // 1. Insert group
    final groupResp = await _client
        .from('groups')
        .insert({
          'id': 'grupo_${DateTime.now().millisecondsSinceEpoch}',
          'name': name.trim(),
          'creator_id': currentUserId,
          'invite_code': _generateInviteCode(),
        })
        .select()
        .single();

    final group = GroupModel.fromMap(Map<String, dynamic>.from(groupResp));

    if (currentUserId != null) {
      final existingPlayer = await _client
          .from('players')
          .select()
          .eq('creator_id', currentUserId)
          .maybeSingle();

      String adminPlayerId;
      if (existingPlayer != null) {
        adminPlayerId = existingPlayer['id'].toString();
      } else {
        final newPlayerResp = await _client
            .from('players')
            .insert({
              'id': const Uuid().v4(),
              'creator_id': currentUserId,
              'name': adminPlayerName?.trim().isNotEmpty == true
                  ? adminPlayerName!.trim()
                  : 'Administrador',
            })
            .select()
            .single();
        final newPlayer =
            PlayerModel.fromMap(Map<String, dynamic>.from(newPlayerResp));
        adminPlayerId = newPlayer.id;
      }

      await _client.from('group_members').insert({
        'group_id': group.id,
        'player_id': adminPlayerId,
        'role': GroupMemberModel.roleAdmin,
      });
    }

    await _client.from('seasons').insert({
      'group_id': group.id,
      'name': 'Temporada 1',
      'is_active': true,
    });

    return group;
  }

  /// Updates the group name
  Future<GroupModel> updateGroup(GroupModel group) async {
    final isAdmin = await _membersRepo.isCurrentUserAdmin(group.id);
    if (!isAdmin) {
      throw Exception('Access denied: Only administrators can edit the group.');
    }

    final response = await _client
        .from('groups')
        .update({'name': group.name.trim()})
        .eq('id', group.id)
        .select()
        .single();

    return GroupModel.fromMap(Map<String, dynamic>.from(response));
  }

  /// Deletes a group
  Future<void> deleteGroup(String groupId) async {
    final isAdmin = await _membersRepo.isCurrentUserAdmin(groupId);
    if (!isAdmin) {
      throw Exception('Access denied: Only administrators can delete the group.');
    }

    await _client.from('groups').delete().eq('id', groupId);
  }
}
