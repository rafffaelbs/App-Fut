import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../domain/services/permission_service.dart';

class SupabasePermissionService implements PermissionService {
  final SupabaseClient? _providedClient;

  SupabasePermissionService({SupabaseClient? client})
      : _providedClient = client;

  SupabaseClient get _client => _providedClient ?? SupabaseConfig.client;

  @override
  Future<bool> isAdmin(String groupId) async {
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
    final memberResp = await _client
        .from('group_members')
        .select('*, players!inner(*)')
        .eq('group_id', groupId)
        .eq('players.creator_id', currentUserId)
        .maybeSingle();

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
