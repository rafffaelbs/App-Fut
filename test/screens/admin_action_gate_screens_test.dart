import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_do_fut/app/app_features.dart';
import 'package:app_do_fut/models/match_model.dart';
import 'package:app_do_fut/screens/history_screen.dart';
import 'package:app_do_fut/screens/settings_screen.dart';
import 'package:app_do_fut/services/admin_action_gate.dart';
import '../helpers/test_app_services.dart';

class FakeDeviceAuthenticator implements DeviceAuthenticator {
  bool isSupported;
  bool authResult;

  FakeDeviceAuthenticator({
    this.isSupported = true,
    this.authResult = true,
  });

  @override
  Future<bool> isDeviceSupported() async => isSupported;

  @override
  Future<bool> authenticate({required String localizedReason}) async => authResult;
}

class CountingMatchesRepository extends StubMatchesRepository {
  int deleteCalls = 0;

  CountingMatchesRepository({super.matches});

  @override
  Future<void> deleteMatch(String matchId) async {
    deleteCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DeviceAuthenticator originalAuthenticator;

  setUp(() {
    originalAuthenticator = AdminActionGate.instance.authenticator;
    AdminActionGate.instance.resetFailedAttempts();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    AdminActionGate.instance.authenticator = originalAuthenticator;
    AdminActionGate.instance.resetFailedAttempts();
  });

  group('HistoryScreen - confirmação do admin nas ações destrutivas', () {
    const groupId = 'group-123';
    const tournamentId = 'session-123';

    final testMatch = MatchModel(
      id: 'match-test-id',
      sessionId: tournamentId,
      teamAScore: 2,
      teamBScore: 1,
      lineups: const [],
      events: const [],
    );

    testWidgets('Lixeira (Limpar Tudo) com confirmação negada (false) -> repositório não é chamado', (tester) async {
      final fakeAuth = FakeDeviceAuthenticator(authResult: false);
      AdminActionGate.instance.authenticator = fakeAuth;

      final countingRepo = CountingMatchesRepository(matches: [testMatch]);
      setupTestAppServices(
        features: const AppFeatures.personal(),
        matches: countingRepo,
        permissions: StubPermissionService(adminResult: true),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(
            groupId: groupId,
            tournamentId: tournamentId,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Clica no botão da lixeira
      expect(find.byIcon(Icons.delete_forever), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_forever));
      await tester.pumpAndSettle();

      // Como o gate devolveu false, o diálogo "Limpar Tudo?" NÃO é exibido
      expect(find.text('Limpar Tudo?'), findsNothing);
      expect(countingRepo.deleteCalls, equals(0));
    });

    testWidgets('Lixeira (Limpar Tudo) com confirmação aprovada (true) -> abre diálogo e chama deleteMatch', (tester) async {
      final fakeAuth = FakeDeviceAuthenticator(authResult: true);
      AdminActionGate.instance.authenticator = fakeAuth;

      final countingRepo = CountingMatchesRepository(matches: [testMatch]);
      setupTestAppServices(
        features: const AppFeatures.personal(),
        matches: countingRepo,
        permissions: StubPermissionService(adminResult: true),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(
            groupId: groupId,
            tournamentId: tournamentId,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Clica na lixeira
      await tester.tap(find.byIcon(Icons.delete_forever));
      await tester.pumpAndSettle();

      // O diálogo de confirmação abre
      expect(find.text('Limpar Tudo?'), findsOneWidget);

      // Confirma no botão Limpar
      await tester.tap(find.text('Limpar'));
      await tester.pumpAndSettle();

      // O repositório foi chamado
      expect(countingRepo.deleteCalls, equals(1));
    });

    testWidgets('Lápis (Editar partida) com confirmação negada (false) -> não abre tela de edição', (tester) async {
      final fakeAuth = FakeDeviceAuthenticator(authResult: false);
      AdminActionGate.instance.authenticator = fakeAuth;

      setupTestAppServices(
        features: const AppFeatures.personal(),
        matches: StubMatchesRepository(matches: [testMatch]),
        permissions: StubPermissionService(adminResult: true),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(
            groupId: groupId,
            tournamentId: tournamentId,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit), findsOneWidget);
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Como a confirmação falhou, não entra na tela de edição
      expect(find.text('Editar Partida'), findsNothing);
      // E confirma que não existe mais nenhum diálogo de "Acesso Restrito" nem "0101"
      expect(find.text('Acesso Restrito'), findsNothing);
      expect(find.text('0101'), findsNothing);
    });
  });

  group('SettingsScreen - Segurança do administrador', () {
    const groupId = 'group-123';

    testWidgets('Membro comum (isAdmin: false) -> seção de segurança NÃO aparece', (tester) async {
      setupTestAppServices(
        features: const AppFeatures.personal(),
        permissions: StubPermissionService(adminResult: false),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(
            groupId: groupId,
            isAdmin: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('SEGURANÇA DO ADMINISTRADOR'), findsNothing);
      expect(find.text('Usar autenticação do aparelho (recomendado)'), findsNothing);
      expect(find.text('Usar senha'), findsNothing);
    });

    testWidgets('Admin com confirmação negada -> "Usar senha" não abre cadastro de senha', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      AdminActionGate.instance.authenticator = FakeDeviceAuthenticator(authResult: false);
      setupTestAppServices(
        features: const AppFeatures.personal(),
        permissions: StubPermissionService(adminResult: true),
      );

      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen(groupId: groupId, isAdmin: true)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Usar senha'));
      await tester.pumpAndSettle();

      expect(find.text('Criar Senha de Administrador'), findsNothing);
    });

    testWidgets('Admin (isAdmin: true) -> seção aparece e trocar de modo grava no SharedPreferences', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeAuth = FakeDeviceAuthenticator(authResult: true);
      AdminActionGate.instance.authenticator = fakeAuth;

      setupTestAppServices(
        features: const AppFeatures.personal(),
        permissions: StubPermissionService(adminResult: true),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(
            groupId: groupId,
            isAdmin: true,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SEGURANÇA DO ADMINISTRADOR'), findsOneWidget);
      expect(find.text('Usar autenticação do aparelho (recomendado)'), findsOneWidget);
      expect(find.text('Usar senha'), findsOneWidget);

      // Ao clicar em 'Usar senha' sem senha cadastrada, abre diálogo para criar senha
      await tester.tap(find.text('Usar senha'));
      await tester.pumpAndSettle();

      expect(find.text('Criar Senha de Administrador'), findsOneWidget);

      final inputs = find.byType(TextField);
      expect(inputs, findsNWidgets(2));

      await tester.enterText(inputs.at(0), '1234');
      await tester.enterText(inputs.at(1), '1234');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      // Verifica gravação em SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AdminGatePrefs.mode), equals(AdminGatePrefs.modePassword));
      expect(prefs.getString(AdminGatePrefs.passHash), isNotNull);
      expect(prefs.getString(AdminGatePrefs.passSalt), isNotNull);

      // Agora com senha cadastrada, aparece a opção "Trocar senha"
      expect(find.text('Trocar senha'), findsOneWidget);

      // Ao tocar em voltar para 'Usar autenticação do aparelho', pede confirmação
      await tester.tap(find.text('Usar autenticação do aparelho (recomendado)'));
      await tester.pumpAndSettle();

      // O diálogo de confirmação de senha é exibido
      expect(find.text('Confirmar Ação'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(prefs.getString(AdminGatePrefs.mode), equals(AdminGatePrefs.modeDevice));
    });
  });
}
