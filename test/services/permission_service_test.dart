import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/domain/services/permission_service.dart';
import 'package:app_do_fut/domain/services/auth_service.dart';

class FakePermissionService implements PermissionService {
  bool adminResult = false;
  String? lastCheckedGroupId;

  @override
  Future<bool> isAdmin(String groupId) async {
    lastCheckedGroupId = groupId;
    return adminResult;
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

void main() {
  group('PermissionService contract tests', () {
    late FakePermissionService permissionService;

    setUp(() {
      permissionService = FakePermissionService();
    });

    test('requireAdmin completes normally when user is admin', () async {
      permissionService.adminResult = true;

      await expectLater(
        permissionService.requireAdmin('group-123'),
        completes,
      );
      expect(permissionService.lastCheckedGroupId, 'group-123');
    });

    test('requireAdmin throws default exception when user is not admin and no message provided', () async {
      permissionService.adminResult = false;

      expect(
        () => permissionService.requireAdmin('group-123'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Access denied: Only administrators can perform this action.'),
          ),
        ),
      );
      expect(permissionService.lastCheckedGroupId, 'group-123');
    });

    test('requireAdmin throws custom exception message when provided', () async {
      permissionService.adminResult = false;
      const customMsg = 'Access denied: Only administrators can create seasons.';

      expect(
        () => permissionService.requireAdmin('group-123', customMsg),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains(customMsg),
          ),
        ),
      );
    });
  });

  group('AppAuthException tests', () {
    test('formats message correctly in toString', () {
      const exception = AppAuthException('Credenciais inválidas');
      expect(exception.message, 'Credenciais inválidas');
      expect(exception.toString(), 'Credenciais inválidas');
    });
  });
}
