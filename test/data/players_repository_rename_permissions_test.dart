import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/data/supabase/players_repository.dart';
import 'package:app_do_fut/domain/services/permission_service.dart';
import 'package:app_do_fut/models/player_model.dart';
import 'package:app_do_fut/models/player_badge_model.dart';

class MockPermissionService implements PermissionService {
  final Set<String> adminGroups;
  bool defaultAdminResult;

  MockPermissionService({
    this.defaultAdminResult = false,
    Set<String>? adminGroups,
  }) : adminGroups = adminGroups ?? {};

  @override
  Future<bool> isAdmin(String groupId) async =>
      adminGroups.contains(groupId) || defaultAdminResult;

  @override
  Future<void> requireAdmin(String groupId, [String? message]) async {
    if (!await isAdmin(groupId)) throw Exception(message ?? 'Acesso negado');
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

    test('admin do grupo com groupId explícito pode renomear', () async {
      final perms = MockPermissionService(adminGroups: {groupId});
      const currentUserId = 'user-admin';
      final updated = targetPlayer.copyWith(name: 'Nome Alterado Admin');

      await expectLater(
        checkPlayerUpdatePermission(
          permissions: perms,
          currentUserId: currentUserId,
          groupId: groupId,
          player: updated,
          getPlayerById: (_) async => targetPlayer,
        ),
        completes,
      );
    });

    test('admin sem groupId pode renomear se for admin em algum grupo do jogador', () async {
      final perms = MockPermissionService(adminGroups: {'group-admin-2'});
      const currentUserId = 'user-admin';
      final updated = targetPlayer.copyWith(name: 'Nome Alterado Admin Sem GroupId');

      await expectLater(
        checkPlayerUpdatePermission(
          permissions: perms,
          currentUserId: currentUserId,
          groupId: null,
          player: updated,
          getPlayerById: (_) async => targetPlayer,
          getPlayerGroupIds: (_) async => ['group-other', 'group-admin-2'],
        ),
        completes,
      );
    });

    test('dono do perfil (vindo do banco) pode renomear a si mesmo', () async {
      final perms = MockPermissionService(defaultAdminResult: false);
      const currentUserId = 'user-owner';
      final updated = const PlayerModel(
        id: 'p1',
        creatorId: null, // mesmo se o objeto passado não trouxer creatorId
        name: 'Nome Novo Dono',
      );

      await expectLater(
        checkPlayerUpdatePermission(
          permissions: perms,
          currentUserId: currentUserId,
          groupId: groupId,
          player: updated,
          getPlayerById: (_) async => targetPlayer,
        ),
        completes,
      );
    });

    test('membro comum sem groupId não pode renomear', () async {
      final perms = MockPermissionService(defaultAdminResult: false);
      const currentUserId = 'user-common';
      final updated = targetPlayer.copyWith(name: 'Tentativa Rename Sem Group');

      expect(
        () => checkPlayerUpdatePermission(
          permissions: perms,
          currentUserId: currentUserId,
          groupId: null,
          player: updated,
          getPlayerById: (_) async => targetPlayer,
          getPlayerGroupIds: (_) async => ['group-other'],
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Acesso negado: somente administradores ou o próprio jogador podem alterar o perfil.'),
          ),
        ),
      );
    });

    test('membro comum com copyWith(creatorId: me) forjado não pode renomear', () async {
      final perms = MockPermissionService(defaultAdminResult: false);
      const currentUserId = 'user-attacker';
      // Forja o creatorId no objeto em memória:
      final forged = targetPlayer.copyWith(
        name: 'Tentativa Forjada',
        creatorId: 'user-attacker',
      );

      expect(
        () => checkPlayerUpdatePermission(
          permissions: perms,
          currentUserId: currentUserId,
          groupId: groupId,
          player: forged,
          getPlayerById: (_) async => targetPlayer, // Banco diz creatorId == 'user-owner'
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Acesso negado: somente administradores ou o próprio jogador podem alterar o perfil.'),
          ),
        ),
      );
    });

    test('outro membro (não-admin e não-dono) não pode renomear e recebe erro de permissão', () async {
      final perms = MockPermissionService(defaultAdminResult: false);
      const currentUserId = 'user-stranger';
      final updated = targetPlayer.copyWith(name: 'Nome Alterado Stranger');

      expect(
        () => checkPlayerUpdatePermission(
          permissions: perms,
          currentUserId: currentUserId,
          groupId: groupId,
          player: updated,
          getPlayerById: (_) async => targetPlayer,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Acesso negado: somente administradores ou o próprio jogador podem alterar o perfil.'),
          ),
        ),
      );
    });

    test('update sem mudar nome passa sem checar permissão de renomear (ex: badges manuais)', () async {
      final perms = MockPermissionService(defaultAdminResult: false);
      const currentUserId = 'user-stranger';
      // Nome idêntico ao do banco, apenas alterando manualBadges:
      final updated = targetPlayer.copyWith(
        manualBadges: [
          const PlayerBadgeModel(
            id: 'b1',
            icon: 'star',
            title: 'Craque da Rodada',
            desc: 'Melhor da rodada',
          ),
        ],
      );

      await expectLater(
        checkPlayerUpdatePermission(
          permissions: perms,
          currentUserId: currentUserId,
          groupId: groupId,
          player: updated,
          getPlayerById: (_) async => targetPlayer,
        ),
        completes,
      );
    });

    test('lança exceção se jogador não for encontrado no banco', () async {
      final perms = MockPermissionService(defaultAdminResult: true);
      expect(
        () => checkPlayerUpdatePermission(
          permissions: perms,
          currentUserId: 'user-admin',
          groupId: groupId,
          player: targetPlayer,
          getPlayerById: (_) async => null,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Jogador não encontrado'),
          ),
        ),
      );
    });
  });
}
