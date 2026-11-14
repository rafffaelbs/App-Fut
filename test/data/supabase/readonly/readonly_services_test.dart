import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/data/supabase/readonly/readonly_services.dart';

void main() {
  group('NullAuthService', () {
    const auth = NullAuthService();

    test('sempre deslogado e sem usuário', () {
      expect(auth.isSignedIn, isFalse);
      expect(auth.currentUserId, isNull);
      expect(auth.currentUserEmail, isNull);
      expect(auth.signedInChanges, emitsDone);
    });

    test('ações de login lançam UnsupportedError e signOut completa', () async {
      expect(() => auth.signIn('a@b.com', '123'), throwsA(isA<UnsupportedError>()));
      expect(() => auth.signUp('a@b.com', '123'), throwsA(isA<UnsupportedError>()));
      await auth.signOut(); // no-op sem exceção
    });
  });

  group('ReadonlyPermissionService', () {
    const permissions = ReadonlyPermissionService();

    test('isAdmin é sempre false', () async {
      expect(await permissions.isAdmin('grp-1'), isFalse);
      expect(await permissions.isAdmin('any-group'), isFalse);
    });

    test('requireAdmin lança Exception', () {
      expect(
        () => permissions.requireAdmin('grp-1'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Acesso negado: somente administradores.'),
        )),
      );

      expect(
        () => permissions.requireAdmin('grp-1', 'Mensagem customizada'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Mensagem customizada'),
        )),
      );
    });
  });

  group('ReadonlyMatchOutbox', () {
    final outbox = ReadonlyMatchOutbox();

    test('sem partidas pendentes ou com falha', () async {
      expect(outbox.pending.value, 0);
      expect(outbox.failed.value, 0);
      expect(outbox.lastError.value, isNull);
      expect(await outbox.failedJobs(), isEmpty);
    });

    test('enqueue lança UnsupportedError', () {
      expect(() => outbox.enqueue({}), throwsA(isA<UnsupportedError>()));
    });

    test('métodos de sincronização e flush são no-op sem erro', () async {
      await outbox.flush();
      await outbox.refreshCounts();
      await outbox.retryFailed('mat-1');
      await outbox.discardFailed('mat-1');
    });
  });

  group('EmptyMatchHistoryStore', () {
    const store = EmptyMatchHistoryStore();

    test('sempre vazio para leitura', () async {
      expect(await store.hasSession('sess-1'), isFalse);
      expect(await store.readSession('sess-1'), isEmpty);
    });

    test('appendToSession lança UnsupportedError', () {
      expect(
        () => store.appendToSession('sess-1', {}),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('EmptyCustomBadgesRepository', () {
    const repo = EmptyCustomBadgesRepository();

    test('sempre vazio para leitura', () async {
      expect(await repo.hasCustomBadges('grp-1'), isFalse);
      expect(await repo.getCustomBadges('grp-1'), isEmpty);
    });

    test('saveCustomBadges lança UnsupportedError', () {
      expect(
        () => repo.saveCustomBadges('grp-1', []),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('NoopActionLogsRepository', () {
    const logs = NoopActionLogsRepository();

    test('log executa sem lançar exceção', () async {
      await logs.log(groupId: 'grp-1', action: 'badge_grant');
    });
  });
}
