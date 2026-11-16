import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_do_fut/services/admin_action_gate.dart';

class FakeDeviceAuthenticator implements DeviceAuthenticator {
  bool isSupported;
  bool hasLock;
  bool authResult;
  String? lastLocalizedReason;

  FakeDeviceAuthenticator({
    this.isSupported = true,
    this.hasLock = true,
    this.authResult = true,
  });

  @override
  Future<bool> isDeviceSupported() async => isSupported;

  @override
  Future<bool> hasEnrolledBiometricsOrLock() async => hasLock;

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    lastLocalizedReason = localizedReason;
    return authResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdminGateSecurity', () {
    test('generateSalt gera valores aleatórios não vazios de comprimento correto', () {
      final salt1 = AdminGateSecurity.generateSalt();
      final salt2 = AdminGateSecurity.generateSalt();

      expect(salt1.isNotEmpty, isTrue);
      expect(salt2.isNotEmpty, isTrue);
      expect(salt1, isNot(equals(salt2)));
      expect(salt1.length, equals(32)); // 16 bytes em hex = 32 chars
    });

    test('hashPassword gera hash SHA-256 e não contém a senha em texto puro', () {
      const pass = 'senha1234';
      final salt = AdminGateSecurity.generateSalt();
      final hash = AdminGateSecurity.hashPassword(pass, salt);

      expect(hash.length, equals(64)); // SHA-256 = 64 hex chars
      expect(hash.contains(pass), isFalse);

      // Duas senhas iguais com sais diferentes geram hashes diferentes
      final saltB = AdminGateSecurity.generateSalt();
      final hashB = AdminGateSecurity.hashPassword(pass, saltB);
      expect(hash, isNot(equals(hashB)));
    });
  });

  group('confirmAdminAction - Modo Aparelho (Padrão)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('autenticou no aparelho -> ação permitida (retorna true)', (tester) async {
      final fakeAuth = FakeDeviceAuthenticator(isSupported: true, hasLock: true, authResult: true);
      final gate = AdminActionGate(authenticator: fakeAuth);

      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await confirmAdminAction(context, motivo: 'excluir item', gate: gate);
                },
                child: const Text('Testar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Testar'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(fakeAuth.lastLocalizedReason, equals('Confirme para excluir item'));
    });

    testWidgets('falhou ou cancelou autenticação -> ação negada (retorna false)', (tester) async {
      final fakeAuth = FakeDeviceAuthenticator(isSupported: true, hasLock: true, authResult: false);
      final gate = AdminActionGate(authenticator: fakeAuth);

      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await confirmAdminAction(context, motivo: 'excluir item', gate: gate);
                },
                child: const Text('Testar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Testar'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('aparelho sem suporte ou sem bloqueio de tela -> mostra mensagem e retorna false', (tester) async {
      final fakeAuth = FakeDeviceAuthenticator(isSupported: false, hasLock: false, authResult: true);
      final gate = AdminActionGate(authenticator: fakeAuth);

      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await confirmAdminAction(context, motivo: 'excluir item', gate: gate);
                },
                child: const Text('Testar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Testar'));
      await tester.pump(); // Inicia animação do SnackBar

      expect(result, isFalse);
      expect(
        find.text("Ative um bloqueio de tela no celular ou escolha 'Usar senha' nas Configurações"),
        findsOneWidget,
      );
    });
  });

  group('confirmAdminAction - Modo Senha', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        AdminGatePrefs.mode: AdminGatePrefs.modePassword,
      });
    });

    testWidgets('sem senha definida -> avisa para definir nas configurações e devolve false', (tester) async {
      final fakeAuth = FakeDeviceAuthenticator();
      final gate = AdminActionGate(authenticator: fakeAuth);

      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await confirmAdminAction(context, motivo: 'limpar dados', gate: gate);
                },
                child: const Text('Testar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Testar'));
      await tester.pump();

      expect(result, isFalse);
      expect(find.text('Defina a senha nas Configurações'), findsOneWidget);
    });

    testWidgets('senha correta -> retorna true e hash salvo NÃO contém a senha em texto', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final fakeAuth = FakeDeviceAuthenticator();
      final gate = AdminActionGate(authenticator: fakeAuth);

      const pass = '4321';
      await gate.savePassword(pass);

      // Verifica que o hash não contém a senha
      final savedHash = prefs.getString(AdminGatePrefs.passHash);
      expect(savedHash, isNotNull);
      expect(savedHash!.contains(pass), isFalse);

      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await confirmAdminAction(context, motivo: 'limpar dados', gate: gate);
                },
                child: const Text('Testar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Testar'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmar Ação'), findsOneWidget);

      // Digita a senha correta
      await tester.enterText(find.byType(TextField), pass);
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('senha errada -> retorna false e cancelamento do diálogo retorna false', (tester) async {
      final fakeAuth = FakeDeviceAuthenticator();
      final gate = AdminActionGate(authenticator: fakeAuth);
      await gate.savePassword('9999');

      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await confirmAdminAction(context, motivo: 'limpar dados', gate: gate);
                },
                child: const Text('Testar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Testar'));
      await tester.pumpAndSettle();

      // Digita senha errada
      await tester.enterText(find.byType(TextField), '0000');
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      // Erro exibido
      expect(find.textContaining('Senha incorreta'), findsOneWidget);
      expect(gate.failedAttempts, equals(1));

      // Cancela o diálogo
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('5 erros seguidos -> bloqueio de 30s persistente em memória', (tester) async {
      final fakeAuth = FakeDeviceAuthenticator();
      final gate = AdminActionGate(authenticator: fakeAuth);
      await gate.savePassword('9999');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await confirmAdminAction(context, motivo: 'limpar dados', gate: gate);
                },
                child: const Text('Testar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Testar'));
      await tester.pumpAndSettle();

      // Erra 4 vezes
      for (int i = 0; i < 4; i++) {
        await tester.enterText(find.byType(TextField), '123$i');
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();
      }
      expect(gate.failedAttempts, equals(4));
      expect(gate.isLocked, isFalse);

      // 5ª tentativa errada: ativa o bloqueio e fecha o diálogo
      await tester.enterText(find.byType(TextField), '0000');
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(gate.failedAttempts, equals(5));
      expect(gate.isLocked, isTrue);
      expect(find.textContaining('Muitas tentativas incorretas'), findsOneWidget);

      // Tenta abrir novamente: bloqueado imediatamente sem abrir diálogo
      await tester.tap(find.text('Testar'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmar Ação'), findsNothing);
      expect(find.textContaining('Muitas tentativas incorretas'), findsOneWidget);
    });

    testWidgets('esqueci a senha com aparelho válido -> permite redefinir senha', (tester) async {
      final fakeAuth = FakeDeviceAuthenticator(isSupported: true, hasLock: true, authResult: true);
      final gate = AdminActionGate(authenticator: fakeAuth);
      await gate.savePassword('1234');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await confirmAdminAction(context, motivo: 'limpar dados', gate: gate);
                },
                child: const Text('Testar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Testar'));
      await tester.pumpAndSettle();

      // Toca em Esqueci a senha
      await tester.tap(find.text('Esqueci a senha'));
      await tester.pumpAndSettle();

      // Abre diálogo de redefinir senha
      expect(find.text('Redefinir Senha'), findsOneWidget);

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      await tester.enterText(textFields.at(0), '5678');
      await tester.enterText(textFields.at(1), '5678');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      // Verifica se a nova senha foi gravada e funciona
      final ok = await gate.verifyEnteredPassword('5678');
      expect(ok, isTrue);
    });

    testWidgets('esqueci a senha sem bloqueio no aparelho -> avisa que precisa limpar dados', (tester) async {
      final fakeAuth = FakeDeviceAuthenticator(isSupported: false, hasLock: false, authResult: false);
      final gate = AdminActionGate(authenticator: fakeAuth);
      await gate.savePassword('1234');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await confirmAdminAction(context, motivo: 'limpar dados', gate: gate);
                },
                child: const Text('Testar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Testar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Esqueci a senha'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'O aparelho não possui bloqueio de tela configurado. Para redefinir a senha, limpe os dados do aplicativo nas configurações do celular.',
        ),
        findsOneWidget,
      );
    });
  });
}
