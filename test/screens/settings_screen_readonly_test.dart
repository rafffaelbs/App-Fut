import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_do_fut/app/app_features.dart';
import 'package:app_do_fut/screens/settings_screen.dart';
import '../helpers/test_app_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsScreen - entradas de gestão e modo somente leitura', () {
    const groupId = 'group-123';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('com isReadOnly = true: NENHUMA entrada de gestão aparece (mesmo com isAdmin = true)', (tester) async {
      setupTestAppServices(
        features: const AppFeatures.webReadonly(),
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
      await tester.pump(const Duration(milliseconds: 50));

      // Confirma que nenhuma entrada de gestão aparece
      expect(find.text('CUSTOMIZAÇÕES & GESTÃO'), findsNothing);
      expect(find.text('Gerenciamento de Customizáveis'), findsNothing);
      expect(find.text('Admin & Debug Cache'), findsNothing);
      expect(find.text('Gerenciar Membros'), findsNothing);
      expect(find.text('Gerenciar Temporadas'), findsNothing);
      expect(find.text('Solicitações de Entrada'), findsNothing);

      // Preferências comuns do app continuam visíveis
      expect(find.text('PREFERÊNCIAS DO APLICATIVO'), findsOneWidget);
    });

    testWidgets('com isReadOnly = false (personal) e isAdmin = true: entradas de gestão aparecem', (tester) async {
      setupTestAppServices(
        features: const AppFeatures.personal(),
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
      await tester.pump(const Duration(milliseconds: 50));

      // Entradas de gestão devem aparecer
      expect(find.text('CUSTOMIZAÇÕES & GESTÃO'), findsOneWidget);
      expect(find.text('Gerenciamento de Customizáveis'), findsOneWidget);
      expect(find.text('Admin & Debug Cache'), findsOneWidget);
      expect(find.text('Gerenciar Membros'), findsOneWidget);
      expect(find.text('Gerenciar Temporadas'), findsOneWidget);
      expect(find.text('Solicitações de Entrada'), findsOneWidget);
    });

    testWidgets('com isReadOnly = false (personal) e isAdmin = false: entradas de gestão NÃO aparecem', (tester) async {
      setupTestAppServices(
        features: const AppFeatures.personal(),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(
            groupId: groupId,
            isAdmin: false,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('CUSTOMIZAÇÕES & GESTÃO'), findsNothing);
      expect(find.text('Gerenciamento de Customizáveis'), findsNothing);
      expect(find.text('Admin & Debug Cache'), findsNothing);
      expect(find.text('Gerenciar Membros'), findsNothing);
      expect(find.text('Gerenciar Temporadas'), findsNothing);
      expect(find.text('Solicitações de Entrada'), findsNothing);
    });
  });
}
