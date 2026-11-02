import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/data/supabase/players_repository.dart';
import 'package:app_do_fut/domain/services/permission_service.dart';
import 'package:app_do_fut/models/player_model.dart';

class MockPermissionService implements PermissionService {
  bool isAdminResult;
  MockPermissionService({this.isAdminResult = false});

  @override
  Future<bool> isAdmin(String groupId) async => isAdminResult;

  @override
  Future<void> requireAdmin(String groupId, [String? message]) async {
    if (!isAdminResult) throw Exception(message ?? 'Acesso negado');
  }
}

void main() {
  group('Regra de permissão para renomear/atualizar jogador (checkPlayerUpdatePermission)', () {
    const groupId = 'group-abc';
    const targetPlayer = PlayerModel(
      id: 'p1',
      creatorId: 'user-owner',
      name: 'Nome Original',
    );

    test('admin do grupo pode renomear qualquer jogador', () async {
      final perms = MockPermissionService(isAdminResult: true);
      const currentUserId = 'user-admin';

      await expectLater(
        checkPlayerUpdatePermission(
          permissions: perms,
          currentUserId: currentUserId,
          groupId: groupId,
          player: targetPlayer,
        ),
        completes,
      );
    });

    test('dono do perfil pode renomear a si mesmo', () async {
      final perms = MockPermissionService(isAdminResult: false);
      const currentUserId = 'user-owner';

      await expectLater(
        checkPlayerUpdatePermission(
          permissions: perms,
          currentUserId: currentUserId,
          groupId: groupId,
          player: targetPlayer,
        ),
        completes,
      );
    });

    test('outro membro (não-admin e não-dono) não pode renomear e recebe erro de permissão', () async {
      final perms = MockPermissionService(isAdminResult: false);
      const currentUserId = 'user-stranger';

      expect(
        () => checkPlayerUpdatePermission(
          permissions: perms,
          currentUserId: currentUserId,
          groupId: groupId,
          player: targetPlayer,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Acesso negado'),
          ),
        ),
      );
    });
  });
}
