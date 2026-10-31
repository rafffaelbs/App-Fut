import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Repositório para a tabela `group_action_logs` (auditoria de ações
/// administrativas). Ver 005_goal_audio_and_action_logs.sql.
///
/// Chamadas aqui nunca devem derrubar o fluxo principal: um log que falha
/// não pode impedir a ação em si (por isso os métodos engolem exceções).
class ActionLogsRepository {
  final SupabaseClient _client;

  ActionLogsRepository({SupabaseClient? client}) : _client = client ?? supabase;

  static const String actionBadgeGrant = 'badge_grant';
  static const String actionBadgeRevoke = 'badge_revoke';
  static const String actionGoalSoundSet = 'goal_sound_set';
  static const String actionGoalSoundClear = 'goal_sound_clear';
  static const String actionNameEffectSet = 'name_effect_set';
  static const String actionMonthlyHighlightSet = 'monthly_highlight_set';
  static const String actionCommunityAttributesSet = 'community_attributes_set';
  static const String actionRoleChange = 'role_change';
  static const String actionMemberRemove = 'member_remove';

  Future<void> log({
    required String groupId,
    required String action,
    String? targetPlayerId,
    Map<String, dynamic> details = const {},
  }) async {
    final actorId = SupabaseConfig.currentUserId;
    if (actorId == null) return; // sem sessão, não há o que auditar

    try {
      await _client.from('group_action_logs').insert({
        'group_id': groupId,
        'actor_id': actorId,
        'action': action,
        if (targetPlayerId != null) 'target_player_id': targetPlayerId,
        'details': details,
      });
    } catch (e) {
      // Nunca deixa uma falha de log quebrar a ação principal do usuário.
    }
  }

  /// Retorna os últimos logs do grupo (somente admins conseguem ler, via RLS).
  Future<List<Map<String, dynamic>>> getRecentLogs(
    String groupId, {
    int limit = 100,
  }) async {
    final response = await _client
        .from('group_action_logs')
        .select()
        .eq('group_id', groupId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (response as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Exporta e apaga logs com mais de [olderThanDays] dias (RPC no banco,
  /// só admin pode chamar). Use isso no lembrete mensal de limpeza.
  Future<List<Map<String, dynamic>>> exportAndCleanOldLogs(
    String groupId, {
    int olderThanDays = 30,
  }) async {
    final response = await _client.rpc(
      'export_and_clean_action_logs',
      params: {'p_group_id': groupId, 'p_older_than_days': olderThanDays},
    );
    return (response as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
