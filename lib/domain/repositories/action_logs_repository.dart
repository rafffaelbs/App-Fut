abstract class ActionLogsRepository {
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
  });
}
