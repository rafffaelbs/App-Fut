import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/app/app_services.dart';
import 'package:app_do_fut/domain/repositories/player_account_repository.dart';
import 'package:app_do_fut/domain/services/auth_service.dart';
import 'package:app_do_fut/domain/services/match_outbox.dart';
import 'package:app_do_fut/main_personal.dart';
import 'package:app_do_fut/models/player_model.dart';
import 'package:app_do_fut/screens/complete_profile_screen.dart';
import 'helpers/test_app_services.dart';

class FakePlayerAccountRepository implements PlayerAccountRepository {
  bool shouldThrowOnClaim = false;
  bool shouldThrowOnGetPlayers = false;
  List<PlayerModel> players = [];

  @override
  Future<List<PlayerModel>> claimGhostProfiles() async {
    if (shouldThrowOnClaim) {
      throw Exception('Network error during claimGhostProfiles');
    }
    return [];
  }

  @override
  Future<List<PlayerModel>> getMyPlayers() async {
    if (shouldThrowOnGetPlayers) {
      throw Exception('Network error during getMyPlayers');
    }
    return players;
  }
}

class FakeAuthService implements AuthService {
  bool signedIn = true;
  String? userId = 'user-123';
  String? userEmail = 'user@test.com';
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  String? get currentUserId => userId;

  @override
  String? get currentUserEmail => userEmail;

  @override
  bool get isSignedIn => signedIn;

  @override
  Stream<bool> get signedInChanges => _controller.stream;

  void emitSignedIn(bool value) {
    signedIn = value;
    _controller.add(value);
  }

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signOut() async {
    signedIn = false;
    userId = null;
    userEmail = null;
    _controller.add(false);
  }

  @override
  Future<void> signUp(String email, String password) async {}
}

class FakeOutbox implements MatchOutbox {
  final ValueNotifier<int> _pending = ValueNotifier<int>(0);
  final ValueNotifier<int> _failed = ValueNotifier<int>(0);
  final ValueNotifier<String?> _lastError = ValueNotifier<String?>(null);

  int refreshCountsCalls = 0;
  int flushCalls = 0;
  bool throwOnRefresh = false;
  bool throwOnFlush = false;

  void setPending(int count) {
    _pending.value = count;
  }

  void setFailed(int count) {
    _failed.value = count;
  }

  @override
  ValueListenable<int> get pending => _pending;

  @override
  ValueListenable<int> get failed => _failed;

  @override
  ValueListenable<String?> get lastError => _lastError;

  @override
  Future<void> enqueue(Map<String, dynamic> job) async {}

  @override
  Future<void> refreshCounts() async {
    refreshCountsCalls++;
    if (throwOnRefresh) {
      throw Exception('Error in refreshCounts');
    }
  }

  @override
  Future<void> flush() async {
    flushCalls++;
    if (throwOnFlush) {
      throw Exception('Network error in flush');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> failedJobs() async => [];

  @override
  Future<void> retryFailed(String matchId) async {}

  @override
  Future<void> discardFailed(String matchId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Parte A: checkUserProfile (decisão de perfil offline/online)', () {
    late FakePlayerAccountRepository fakeAccounts;

    setUp(() {
      fakeAccounts = FakePlayerAccountRepository();
    });

    test('retorna failed (e NÃO noProfile) quando claimGhostProfiles lança exceção', () async {
      fakeAccounts.shouldThrowOnClaim = true;
      final result = await checkUserProfile(playerAccounts: fakeAccounts);
      expect(result, ProfileCheckResult.failed);
      expect(result, isNot(ProfileCheckResult.noProfile));
    });

    test('retorna failed (e NÃO noProfile) quando getMyPlayers lança exceção', () async {
      fakeAccounts.shouldThrowOnGetPlayers = true;
      final result = await checkUserProfile(playerAccounts: fakeAccounts);
      expect(result, ProfileCheckResult.failed);
      expect(result, isNot(ProfileCheckResult.noProfile));
    });

    test('retorna noProfile quando ambas as chamadas sucedem e não há jogadores', () async {
      fakeAccounts.players = [];
      final result = await checkUserProfile(playerAccounts: fakeAccounts);
      expect(result, ProfileCheckResult.noProfile);
    });

    test('retorna hasProfile quando getMyPlayers retorna jogadores vinculados', () async {
      fakeAccounts.players = [
        PlayerModel(id: 'p1', name: 'Jogador Teste'),
      ];
      final result = await checkUserProfile(playerAccounts: fakeAccounts);
      expect(result, ProfileCheckResult.hasProfile);
    });
  });

  group('Parte B: triggerOutboxFlush', () {
    late FakeAuthService fakeAuth;
    late FakeOutbox fakeOutbox;

    setUp(() {
      fakeAuth = FakeAuthService();
      fakeOutbox = FakeOutbox();
    });

    test('chama flush quando logado e pending > 0', () async {
      fakeAuth.signedIn = true;
      fakeOutbox.setPending(3);

      await triggerOutboxFlush(auth: fakeAuth, outbox: fakeOutbox);

      expect(fakeOutbox.refreshCountsCalls, 1);
      expect(fakeOutbox.flushCalls, 1);
    });

    test('NÃO chama flush quando deslogado, mesmo com pending > 0', () async {
      fakeAuth.signedIn = false;
      fakeOutbox.setPending(3);

      await triggerOutboxFlush(auth: fakeAuth, outbox: fakeOutbox);

      expect(fakeOutbox.refreshCountsCalls, 1);
      expect(fakeOutbox.flushCalls, 0);
    });

    test('NÃO chama flush quando logado mas pending == 0', () async {
      fakeAuth.signedIn = true;
      fakeOutbox.setPending(0);

      await triggerOutboxFlush(auth: fakeAuth, outbox: fakeOutbox);

      expect(fakeOutbox.refreshCountsCalls, 1);
      expect(fakeOutbox.flushCalls, 0);
    });

    test('engole erros de refreshCounts e flush sem propagar exceção', () async {
      fakeAuth.signedIn = true;
      fakeOutbox.setPending(2);
      fakeOutbox.throwOnFlush = true;

      // Não deve lançar exceção
      await triggerOutboxFlush(auth: fakeAuth, outbox: fakeOutbox);
      expect(fakeOutbox.flushCalls, 1);

      fakeOutbox.throwOnRefresh = true;
      await triggerOutboxFlush(auth: fakeAuth, outbox: fakeOutbox);
      expect(fakeOutbox.refreshCountsCalls, 2);
    });
  });

  group('Parte B: WidgetsBindingObserver (AuthGate no ciclo de vida)', () {
    late FakeAuthService fakeAuth;
    late FakeOutbox fakeOutbox;

    setUp(() {
      fakeAuth = FakeAuthService();
      fakeOutbox = FakeOutbox();
      setupTestAppServices(
        auth: fakeAuth,
      );
      // Injeta fakeOutbox nos AppServices
      AppServices.instance = AppServices(
        features: AppServices.instance.features,
        groups: AppServices.instance.groups,
        members: AppServices.instance.members,
        seasons: AppServices.instance.seasons,
        players: AppServices.instance.players,
        playerAccounts: AppServices.instance.playerAccounts,
        sessions: AppServices.instance.sessions,
        matches: AppServices.instance.matches,
        sessionArrivals: AppServices.instance.sessionArrivals,
        actionLogs: AppServices.instance.actionLogs,
        auth: fakeAuth,
        permissions: AppServices.instance.permissions,
        outbox: fakeOutbox,
        matchHistory: AppServices.instance.matchHistory,
        customBadges: AppServices.instance.customBadges,
      );
    });

    testWidgets('AppLifecycleState.resumed dispara flush quando logado e pending > 0', (tester) async {
      fakeAuth.signedIn = true;
      fakeAuth.userId = 'user-123';
      fakeOutbox.setPending(2);

      await tester.pumpWidget(
        const MaterialApp(home: AuthGate()),
      );
      await tester.pump();

      final initialFlushCalls = fakeOutbox.flushCalls;

      // Simula retomada do background
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(fakeOutbox.flushCalls, greaterThan(initialFlushCalls));
    });

    testWidgets('AppLifecycleState.resumed NÃO dispara flush quando deslogado', (tester) async {
      fakeAuth.signedIn = false;
      fakeAuth.userId = null;
      fakeOutbox.setPending(2);

      await tester.pumpWidget(
        const MaterialApp(home: AuthGate()),
      );
      await tester.pump();

      final initialFlushCalls = fakeOutbox.flushCalls;

      // Simula retomada do background
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(fakeOutbox.flushCalls, initialFlushCalls);
    });

    testWidgets('AppLifecycleState.resumed NÃO dispara flush quando logado e pending == 0', (tester) async {
      fakeAuth.signedIn = true;
      fakeAuth.userId = 'user-123';
      fakeOutbox.setPending(0);

      await tester.pumpWidget(
        const MaterialApp(home: AuthGate()),
      );
      await tester.pump();

      final initialFlushCalls = fakeOutbox.flushCalls;

      // Simula retomada do background
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(fakeOutbox.flushCalls, initialFlushCalls);
    });
  });

  group('Parte A: _ProfileCheck telas renderizadas conforme ProfileCheckResult', () {
    late FakeAuthService fakeAuth;
    late FakePlayerAccountRepository fakeAccounts;

    setUp(() {
      fakeAuth = FakeAuthService()..signedIn = true..userId = 'user-123';
      fakeAccounts = FakePlayerAccountRepository();
      setupTestAppServices(
        auth: fakeAuth,
        playerAccounts: fakeAccounts,
      );
    });

    testWidgets('quando consulta dá erro (failed), renderiza HomePage e NÃO CompleteProfileScreen', (tester) async {
      fakeAccounts.shouldThrowOnClaim = true;

      await tester.pumpWidget(
        const MaterialApp(home: AuthGate()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CompleteProfileScreen), findsNothing,
          reason: 'failed NÃO deve exibir CompleteProfileScreen');
      expect(find.byType(HomePage), findsOneWidget,
          reason: 'failed deve exibir HomePage');
    });

    testWidgets('quando consulta volta vazia (noProfile), renderiza CompleteProfileScreen', (tester) async {
      fakeAccounts.players = [];

      await tester.pumpWidget(
        const MaterialApp(home: AuthGate()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CompleteProfileScreen), findsOneWidget,
          reason: 'noProfile deve exibir CompleteProfileScreen');
      expect(find.byType(HomePage), findsNothing);
    });

    testWidgets('quando consulta encontra jogador (hasProfile), renderiza HomePage', (tester) async {
      fakeAccounts.players = [PlayerModel(id: 'p1', name: 'Jogador Teste')];

      await tester.pumpWidget(
        const MaterialApp(home: AuthGate()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget,
          reason: 'hasProfile deve exibir HomePage');
      expect(find.byType(CompleteProfileScreen), findsNothing);
    });
  });
}

