import 'package:flutter/foundation.dart';
import 'supabase_permission_service.dart';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'supabase_config.dart';
import 'cache_store.dart';
import '../../models/group_model.dart';
import '../../models/player_model.dart';
import '../../models/group_member_model.dart';
import '../../domain/services/permission_service.dart';
import '../../domain/repositories/groups_repository.dart';

/// Monta o payload para inserção da temporada padrão ao criar um novo grupo.
Map<String, dynamic> buildDefaultSeasonPayload(String groupId) {
  return {
    'id': const Uuid().v4(),
    'group_id': groupId,
    'name': 'Temporada 1',
    'is_active': true,
  };
}

/// Groups repository integrated with Supabase PostgreSQL.
class SupabaseGroupsRepository implements GroupsRepository {
  final SupabaseClient? _customClient;
  final PermissionService _permissions;
  final CacheStore _cache;
  final String? Function()? _currentUserIdProvider;
  final Future<List<GroupModel>> Function(String currentUserId)? _remoteFetcher;
  final Future<GroupModel> Function({
    required String name,
    String? adminPlayerName,
    required String currentUserId,
  })? _createGroupRemote;
  final Future<GroupModel> Function(GroupModel group)? _updateGroupRemote;
  final Future<void> Function(String groupId)? _deleteGroupRemote;

  SupabaseClient get _client => _customClient ?? supabase;

  bool _lastLoadFromCache = false;

  static const Duration _netTimeout = Duration(seconds: 8);

  SupabaseGroupsRepository({
    SupabaseClient? client,
    PermissionService? permissions,
    CacheStore? cache,
    String? Function()? currentUserIdProvider,
    Future<List<GroupModel>> Function(String currentUserId)? remoteFetcher,
    Future<GroupModel> Function({
      required String name,
      String? adminPlayerName,
      required String currentUserId,
    })? createGroupRemote,
    Future<GroupModel> Function(GroupModel group)? updateGroupRemote,
    Future<void> Function(String groupId)? deleteGroupRemote,
  })  : _customClient = client,
        _permissions = permissions ?? SupabasePermissionService(),
        _cache = cache ?? CacheStore(),
        _currentUserIdProvider = currentUserIdProvider,
        _remoteFetcher = remoteFetcher,
        _createGroupRemote = createGroupRemote,
        _updateGroupRemote = updateGroupRemote,
        _deleteGroupRemote = deleteGroupRemote;

  String? get _currentUserId {
    if (_currentUserIdProvider != null) {
      return _currentUserIdProvider();
    }
    try {
      return SupabaseConfig.currentUserId;
    } catch (_) {
      return null;
    }
  }

  @override
  bool get lastLoadFromCache => _lastLoadFromCache;

  Map<String, dynamic> _groupToMap(GroupModel g) => {
    'id': g.id,
    'name': g.name,
    'creator_id': g.creatorId,
    'invite_code': g.inviteCode,
    if (g.createdAt != null) 'created_at': g.createdAt!.toIso8601String(),
  };

  Future<List<GroupModel>> _fetchRemoteGroups(String currentUserId) async {
    // 1. Groups created by the user
    final creatorResponse = await _client
        .from('groups')
        .select()
        .eq('creator_id', currentUserId)
        .timeout(_netTimeout);

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
        .eq('players.creator_id', currentUserId)
        .timeout(_netTimeout);

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

  /// Returns groups that the authenticated user is a part of or created.
  @override
  Future<List<GroupModel>> getMyGroups() async {
    final currentUserId = _currentUserId;

    if (currentUserId == null) {
      _lastLoadFromCache = false;
      final List<GroupModel> result;
      if (_remoteFetcher != null) {
        result = await _remoteFetcher('');
      } else {
        final response = await _client
            .from('groups')
            .select()
            .order('created_at')
            .timeout(_netTimeout);
        result = (response as List)
            .whereType<Map>()
            .map((item) => GroupModel.fromMap(Map<String, dynamic>.from(item)))
            .toList();
      }
      return result;
    }

    final cacheKey = 'groups:my:$currentUserId';

    try {
      final List<GroupModel> result;
      if (_remoteFetcher != null) {
        result = await _remoteFetcher(currentUserId);
      } else {
        result = await _fetchRemoteGroups(currentUserId);
      }

      _lastLoadFromCache = false;
      await _cache.write(cacheKey, result.map(_groupToMap).toList());
      return result;
    } catch (e) {
      final cached = await _cache.read(cacheKey);
      if (cached != null) {
        _lastLoadFromCache = true;
        return cached.asMapList().map(GroupModel.fromMap).toList();
      }
      _lastLoadFromCache = false;
      rethrow;
    }
  }

  /// Generates a short, human-friendly invite code (e.g. "K7QX2P").
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I to avoid confusion
    final rnd = Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  /// Creates a new group. The creator automatically becomes its admin.
  @override
  Future<GroupModel> createGroup({
    required String name,
    String? adminPlayerName,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw Exception('Você precisa estar logado para criar um grupo.');
    }

    final GroupModel group;
    if (_createGroupRemote != null) {
      group = await _createGroupRemote(
        name: name,
        adminPlayerName: adminPlayerName,
        currentUserId: currentUserId,
      );
    } else {
      group = await _createGroupDefault(
        name: name,
        adminPlayerName: adminPlayerName,
        currentUserId: currentUserId,
      );
    }

    await _cache.invalidate('groups:my:$currentUserId');
    return group;
  }

  Future<GroupModel> _createGroupDefault({
    required String name,
    String? adminPlayerName,
    required String currentUserId,
  }) async {
    String? createdGroupId;
    String? createdPlayerId;
    bool memberCreated = false;
    String? createdSeasonId;

    try {
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
      createdGroupId = group.id;

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
        createdPlayerId = newPlayer.id;
      }

      await _client.from('group_members').insert({
        'group_id': group.id,
        'player_id': adminPlayerId,
        'role': GroupMemberModel.roleAdmin,
      });
      memberCreated = true;

      final seasonPayload = buildDefaultSeasonPayload(group.id);
      createdSeasonId = seasonPayload['id'] as String?;
      await _client.from('seasons').insert(seasonPayload);

      return group;
    } catch (e) {
      // Desfazer somente o que ESTA chamada criou, em ordem inversa
      if (createdSeasonId != null) {
        try {
          await _client.from('seasons').delete().eq('id', createdSeasonId);
        } catch (err) {
          debugPrint('Erro ao desfazer criação de season: $err');
        }
      }

      if (memberCreated && createdGroupId != null) {
        try {
          await _client
              .from('group_members')
              .delete()
              .eq('group_id', createdGroupId);
        } catch (err) {
          debugPrint('Erro ao desfazer criação de group_member: $err');
        }
      }

      if (createdPlayerId != null) {
        try {
          await _client.from('players').delete().eq('id', createdPlayerId);
        } catch (err) {
          debugPrint('Erro ao desfazer criação de player: $err');
        }
      }

      if (createdGroupId != null) {
        try {
          await _client.from('groups').delete().eq('id', createdGroupId);
        } catch (err) {
          debugPrint('Erro ao desfazer criação de group: $err');
        }
      }

      rethrow;
    }
  }

  /// Updates the group name
  @override
  Future<GroupModel> updateGroup(GroupModel group) async {
    await _permissions.requireAdmin(
      group.id,
      'Access denied: Only administrators can edit the group.',
    );

    final GroupModel updated;
    if (_updateGroupRemote != null) {
      updated = await _updateGroupRemote(group);
    } else {
      final response = await _client
          .from('groups')
          .update({'name': group.name.trim()})
          .eq('id', group.id)
          .select()
          .single();
      updated = GroupModel.fromMap(Map<String, dynamic>.from(response));
    }

    final currentUserId = _currentUserId;
    if (currentUserId != null) {
      await _cache.invalidate('groups:my:$currentUserId');
    }

    return updated;
  }

  /// Deletes a group
  @override
  Future<void> deleteGroup(String groupId) async {
    await _permissions.requireAdmin(
      groupId,
      'Access denied: Only administrators can delete the group.',
    );

    if (_deleteGroupRemote != null) {
      await _deleteGroupRemote(groupId);
    } else {
      await _client.from('groups').delete().eq('id', groupId);
    }

    final currentUserId = _currentUserId;
    if (currentUserId != null) {
      await _cache.invalidate('groups:my:$currentUserId');
    }
  }
}
