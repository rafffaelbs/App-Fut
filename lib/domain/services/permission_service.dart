abstract class PermissionService {
  Future<bool> isAdmin(String groupId);
  Future<void> requireAdmin(String groupId);
}
