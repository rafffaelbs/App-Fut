abstract class CustomBadgesRepository {
  Future<bool> hasCustomBadges(String groupId);

  Future<List<Map<String, dynamic>>> getCustomBadges(String groupId);

  Future<void> saveCustomBadges(
    String groupId,
    List<Map<String, dynamic>> badges,
  );
}
