import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/data/supabase/supabase_permission_service.dart';
import 'package:app_do_fut/domain/services/auth_service.dart';

class FakePermissionDataSource implements PermissionDataSource {
  String? creatorId;
  Map<String, dynamic>? memberRow;

  @override
  Future<String?> groupCreatorId(String groupId) async => creatorId;

  @override
  Future<Map<String, dynamic>?> membershipRow(String groupId, String userId) async =>
      memberRow;
}

void main() {
  group('SupabasePermissionService tests with FakePermissionDataSource', () {
    late FakePermissionDataSource fakeDataSource;
    String? currentUserId;
    late SupabasePermissionService permissionService;

    setUp(() {
      fakeDataSource = FakePermissionDataSource();
      currentUserId = 'user-123';
      permissionService = SupabasePermissionService(
        dataSource: fakeDataSource,
        currentUserId: () => currentUserId,
      );
    });

    test('usuário nulo -> false', () async {
      currentUserId = null;
      fakeDataSource.creatorId = 'user-123';
      fakeDataSource.memberRow = {'role': 'admin'};

      final result = await permissionService.isAdmin('group-1');
      expect(result, isFalse);
    });

    test('dono do grupo -> true', () async {
      currentUserId = 'creator-user';
      fakeDataSource.creatorId = 'creator-user';
      fakeDataSource.memberRow = null;

      final result = await permissionService.isAdmin('group-1');
      expect(result, isTrue);
    });

    test("role 'admin' -> true", () async {
      currentUserId = 'user-123';
      fakeDataSource.creatorId = 'other-user';
      fakeDataSource.memberRow = {'role': 'admin'};

      final result = await permissionService.isAdmin('group-1');
      expect(result, isTrue);
    });

    test("role ' Admin ' (com espaços e maiúsculas) -> true", () async {
      currentUserId = 'user-123';
      fakeDataSource.creatorId = 'other-user';
      fakeDataSource.memberRow = {'role': ' Admin '};

      final result = await permissionService.isAdmin('group-1');
      expect(result, isTrue);
    });

    test("campo 'papel' em vez de 'role' -> true", () async {
      currentUserId = 'user-123';
      fakeDataSource.creatorId = 'other-user';
      fakeDataSource.memberRow = {'papel': 'admin'};

      final result = await permissionService.isAdmin('group-1');
      expect(result, isTrue);
    });

    test("role 'member' -> false", () async {
      currentUserId = 'user-123';
      fakeDataSource.creatorId = 'other-user';
      fakeDataSource.memberRow = {'role': 'member'};

      final result = await permissionService.isAdmin('group-1');
      expect(result, isFalse);
    });

    test('sem membership -> false', () async {
      currentUserId = 'user-123';
      fakeDataSource.creatorId = 'other-user';
      fakeDataSource.memberRow = null;

      final result = await permissionService.isAdmin('group-1');
      expect(result, isFalse);
    });

    group('requireAdmin', () {
      test('completes normally when user is admin', () async {
        fakeDataSource.creatorId = 'user-123';

        await expectLater(
          permissionService.requireAdmin('group-1'),
          completes,
        );
      });

      test('usa o default quando omitida mensagem', () async {
        fakeDataSource.creatorId = 'other-user';
        fakeDataSource.memberRow = {'role': 'member'};

        expect(
          () => permissionService.requireAdmin('group-1'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Access denied: Only administrators can perform this action.'),
            ),
          ),
        );
      });

      test('repassa a mensagem exata quando fornecida', () async {
        fakeDataSource.creatorId = 'other-user';
        fakeDataSource.memberRow = {'role': 'member'};
        const customMessage = 'Acesso restrito para administradores deste grupo.';

        expect(
          () => permissionService.requireAdmin('group-1', customMessage),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains(customMessage),
            ),
          ),
        );
      });
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
