import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../domain/services/permission_service.dart';

abstract class PermissionDataSource {
  Future<String?> groupCreatorId(String groupId);
  Future<Map<String, dynamic>?> membershipRow(String groupId, String userId);
}

class SupabasePermissionDataSource implements PermissionDataSource {
  final SupabaseClient? _providedClient;

  SupabasePermissionDataSource({SupabaseClient? client})
      : _providedClient = client;

  SupabaseClient get _client => _providedClient ?? SupabaseConfig.client;

  @override
  Future<String?> groupCreatorId(String groupId) async {
    final groupResp = await _client
        .from('groups')
        .select('creator_id')
        .eq('id', groupId)
        .maybeSingle();

    return groupResp?['creator_id']?.toString();
  }

  @override
  Future<Map<String, dynamic>?> membershipRow(String groupId, String userId) async {
    final memberResp = await _client
        .from('group_members')
        .select('*, players!inner(*)')
        .eq('group_id', groupId)
        .eq('players.creator_id', userId)
        .maybeSingle();

    return memberResp;
  }
}

class SupabasePermissionService implements PermissionService {
  final PermissionDataSource _dataSource;
  final String? Function() _currentUserId;

  SupabasePermissionService({
    PermissionDataSource? dataSource,
    String? Function()? currentUserId,
    SupabaseClient? client,
  })  : _dataSource = dataSource ?? SupabasePermissionDataSource(client: client),
        _currentUserId = currentUserId ?? (() => SupabaseConfig.currentUserId);

  @override
  Future<bool> isAdmin(String groupId) async {
    final currentUserId = _currentUserId();
    if (currentUserId == null) return false;

    // 1. Verify if the user is the creator of the group
    final creatorId = await _dataSource.groupCreatorId(groupId);
    if (creatorId != null && creatorId == currentUserId) {
      return true;
    }

    // 2. Verify the role column in group_members
    final memberResp = await _dataSource.membershipRow(groupId, currentUserId);
    if (memberResp != null) {
      final role = (memberResp['role'] ?? memberResp['papel'])
          ?.toString()
          .trim()
          .toLowerCase();
      if (role == 'admin') return true;
    }

    return false;
  }

  @override
  Future<void> requireAdmin(String groupId, [String? message]) async {
    final hasPermission = await isAdmin(groupId);
    if (!hasPermission) {
      throw Exception(
        message ?? 'Access denied: Only administrators can perform this action.',
      );
    }
  }
}
