import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_do_fut/app/app_features.dart';
import 'package:app_do_fut/domain/services/match_outbox.dart';
import 'package:app_do_fut/main_personal.dart';
import 'package:app_do_fut/models/group_model.dart';
import 'package:flutter/foundation.dart';
import '../helpers/test_app_services.dart';

class _FakeMatchOutbox implements MatchOutbox {
  final ValueNotifier<int> pendingNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> failedNotifier = ValueNotifier<int>(0);
  final ValueNotifier<String?> lastErrorNotifier = ValueNotifier<String?>(null);

  @override
  ValueListenable<int> get pending => pendingNotifier;

  @override
  ValueListenable<int> get failed => failedNotifier;

  @override
  ValueListenable<String?> get lastError => lastErrorNotifier;

  @override
  Future<void> enqueue(Map<String, dynamic> job) async {}

  @override
  Future<void> flush() async {}

  @override
  Future<void> refreshCounts() async {}

  @override
  Future<List<Map<String, dynamic>>> failedJobs() async => [];

  @override
  Future<void> retryFailed(String matchId) async {}

  @override
  Future<void> discardFailed(String matchId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final group1 = GroupModel(id: 'group-admin', name: 'Pelada dos Amigos');
  final group2 = GroupModel(id: 'group-member', name: 'Futebol de Terça');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('HomePage - Menu ⋮ Editar/Excluir do grupo', () {
    testWidgets('membro comum (isAdmin = false): NÃO vê o menu ⋮', (tester) async {
      setupTestAppServices(
        features: const AppFeatures.personal(),
        groups: StubGroupsRepository(groups: [group1]),
        permissions: StubPermissionService(adminResult: false),
        outbox: _FakeMatchOutbox(),
      );

      await tester.pumpWidget(
        const MaterialApp(home: HomePage()),
      );
      await tester.pumpAndSettle();

      // Nome do grupo deve estar visível
      expect(find.text('Pelada dos Amigos'), findsOneWidget);

      // Menu ⋮ não deve aparecer
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('admin (isAdmin = true): vê o menu ⋮ e opções Editar / Excluir', (tester) async {
      setupTestAppServices(
        features: const AppFeatures.personal(),
        groups: StubGroupsRepository(groups: [group1]),
        permissions: StubPermissionService(adminResult: true),
        outbox: _FakeMatchOutbox(),
      );

      await tester.pumpWidget(
        const MaterialApp(home: HomePage()),
      );
      await tester.pumpAndSettle();

      // Nome do grupo e ícone ⋮ devem estar visíveis
      expect(find.text('Pelada dos Amigos'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      // Abre o menu popup
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Opções Editar e Excluir devem aparecer
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Excluir'), findsOneWidget);
    });

    testWidgets('grupos mistos: menu ⋮ só aparece no grupo onde usuário é admin', (tester) async {
      setupTestAppServices(
        features: const AppFeatures.personal(),
        groups: StubGroupsRepository(groups: [group1, group2]),
        permissions: StubPermissionService(
          adminByGroup: {
            'group-admin': true,
            'group-member': false,
          },
        ),
        outbox: _FakeMatchOutbox(),
      );

      await tester.pumpWidget(
        const MaterialApp(home: HomePage()),
      );
      await tester.pumpAndSettle();

      // Ambos os grupos aparecem
      expect(find.text('Pelada dos Amigos'), findsOneWidget);
      expect(find.text('Futebol de Terça'), findsOneWidget);

      // Apenas um ícone ⋮ deve aparecer (no grupo onde é admin)
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('com isReadOnly = true: menu ⋮ NÃO aparece mesmo se admin', (tester) async {
      setupTestAppServices(
        features: const AppFeatures.webReadonly(),
        groups: StubGroupsRepository(groups: [group1]),
        permissions: StubPermissionService(adminResult: true),
        outbox: _FakeMatchOutbox(),
      );

      await tester.pumpWidget(
        const MaterialApp(home: HomePage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pelada dos Amigos'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });
  });
}
