abstract class CustomBadgesRepository {
  Future<List<Map<String, dynamic>>> getCustomBadges(String groupId);

  Future<void> saveCustomBadges(
    String groupId,
    List<Map<String, dynamic>> badges,
  );
}
