import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_do_fut/data/supabase/cache_store.dart';
import 'package:app_do_fut/data/supabase/groups_repository.dart';
import 'package:app_do_fut/models/group_model.dart';
import 'package:app_do_fut/domain/services/permission_service.dart';

class FakePermissionService implements PermissionService {
  @override
  Future<bool> isAdmin(String groupId) async => true;

  @override
  Future<void> requireAdmin(String groupId, [String? message]) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CacheStore cache;
  late FakePermissionService permissions;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cache = CacheStore();
    permissions = FakePermissionService();
  });

  group('SupabaseGroupsRepository cache fallback', () {
    test('(a) getMyGroups devolve o cache quando a rede falha', () async {
      String? currentUserId = 'user-a';
      bool networkDown = false;

      final repo = SupabaseGroupsRepository(
        cache: cache,
        permissions: permissions,
        currentUserIdProvider: () => currentUserId,
        remoteFetcher: (userId) async {
          if (networkDown) {
            throw Exception('Falha de rede simulada');
          }
          return [
            const GroupModel(id: 'g1', name: 'Pelada de Terça', creatorId: 'user-a'),
          ];
        },
      );

      // 1. Chamada online bem-sucedida popula o cache
      final onlineGroups = await repo.getMyGroups();
      expect(onlineGroups.length, 1);
      expect(onlineGroups.first.name, 'Pelada de Terça');
      expect(repo.lastLoadFromCache, isFalse);

      // 2. Queda de rede
      networkDown = true;
      final cachedGroups = await repo.getMyGroups();
      expect(cachedGroups.length, 1);
      expect(cachedGroups.first.id, 'g1');
      expect(cachedGroups.first.name, 'Pelada de Terça');
      expect(repo.lastLoadFromCache, isTrue);
    });

    test('(b) o cache de um usuário não aparece para outro', () async {
      String? currentUserId = 'user-1';
      bool networkDown = false;

      final repo = SupabaseGroupsRepository(
        cache: cache,
        permissions: permissions,
        currentUserIdProvider: () => currentUserId,
        remoteFetcher: (userId) async {
          if (networkDown) {
            throw Exception('Falha de rede simulada');
          }
          if (userId == 'user-1') {
            return [
              const GroupModel(id: 'g-user1', name: 'Grupo do User 1', creatorId: 'user-1'),
            ];
          }
          return [];
        },
      );

      // user-1 carrega com sucesso e salva em groups:my:user-1
      await repo.getMyGroups();

      // Troca para user-2 com rede indisponível
      currentUserId = 'user-2';
      networkDown = true;

      // user-2 não deve enxergar o cache de user-1
      expect(
        () => repo.getMyGroups(),
        throwsA(isA<Exception>()),
      );
      expect(repo.lastLoadFromCache, isFalse);
    });

    test('(c) createGroup/deleteGroup invalidam o cache', () async {
      String? currentUserId = 'user-c';
      bool networkDown = false;

      final repo = SupabaseGroupsRepository(
        cache: cache,
        permissions: permissions,
        currentUserIdProvider: () => currentUserId,
        remoteFetcher: (userId) async {
          if (networkDown) {
            throw Exception('Falha de rede simulada');
          }
          return [
            const GroupModel(id: 'g-initial', name: 'Grupo Inicial', creatorId: 'user-c'),
          ];
        },
        createGroupRemote: ({
          required String name,
          String? adminPlayerName,
          required String currentUserId,
        }) async {
          return GroupModel(id: 'g-new', name: name, creatorId: currentUserId);
        },
        deleteGroupRemote: (groupId) async {},
      );

      // 1. Popula cache
      await repo.getMyGroups();
      final cachedBeforeCreate = await cache.read('groups:my:user-c');
      expect(cachedBeforeCreate, isNotNull);

      // 2. createGroup bem-sucedido invalida o cache
      await repo.createGroup(name: 'Novo Grupo');
      final cachedAfterCreate = await cache.read('groups:my:user-c');
      expect(cachedAfterCreate, isNull, reason: 'createGroup deve invalidar o cache');

      networkDown = true;
      expect(() => repo.getMyGroups(), throwsA(isA<Exception>()));
      networkDown = false;

      // 3. Popula cache de novo
      await repo.getMyGroups();
      final cachedBeforeDelete = await cache.read('groups:my:user-c');
      expect(cachedBeforeDelete, isNotNull);

      // 4. deleteGroup bem-sucedido invalida o cache
      await repo.deleteGroup('g-initial');
      final cachedAfterDelete = await cache.read('groups:my:user-c');
      expect(cachedAfterDelete, isNull, reason: 'deleteGroup deve invalidar o cache');

      networkDown = true;
      expect(() => repo.getMyGroups(), throwsA(isA<Exception>()));
    });

    test('(d) a sinalização de origem fica true só quando veio do cache', () async {
      String? currentUserId = 'user-d';
      bool networkDown = false;

      final repo = SupabaseGroupsRepository(
        cache: cache,
        permissions: permissions,
        currentUserIdProvider: () => currentUserId,
        remoteFetcher: (userId) async {
          if (networkDown) {
            throw Exception('Sem conexão');
          }
          return [
            const GroupModel(id: 'g-d', name: 'Grupo D', creatorId: 'user-d'),
          ];
        },
      );

      // Inicialmente é false
      expect(repo.lastLoadFromCache, isFalse);

      // Após sucesso online, continua false
      await repo.getMyGroups();
      expect(repo.lastLoadFromCache, isFalse);

      // Após falha de rede com cache presente, torna-se true
      networkDown = true;
      await repo.getMyGroups();
      expect(repo.lastLoadFromCache, isTrue);

      // Volta a rede: torna-se false novamente
      networkDown = false;
      await repo.getMyGroups();
      expect(repo.lastLoadFromCache, isFalse);
    });

    test('sem usuário logado, não grava e não usa cache', () async {
      String? currentUserId; // null
      bool networkDown = false;

      final repo = SupabaseGroupsRepository(
        cache: cache,
        permissions: permissions,
        currentUserIdProvider: () => currentUserId,
        remoteFetcher: (userId) async {
          if (networkDown) {
            throw Exception('Falha de rede');
          }
          return [
            const GroupModel(id: 'g-anon', name: 'Grupo Anon'),
          ];
        },
      );

      // Sem usuário, getMyGroups não usa cache
      final prefs = await SharedPreferences.getInstance();
      await repo.getMyGroups();

      final cacheKeys = prefs.getKeys().where((k) => k.startsWith('cache:groups:my:'));
      expect(cacheKeys, isEmpty, reason: 'Sem usuário logado não deve gravar cache');

      networkDown = true;
      expect(() => repo.getMyGroups(), throwsA(isA<Exception>()));
      expect(repo.lastLoadFromCache, isFalse);
    });
  });
}
