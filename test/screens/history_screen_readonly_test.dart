import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_do_fut/app/app_features.dart';
import 'package:app_do_fut/models/match_model.dart';
import 'package:app_do_fut/screens/history_screen.dart';
import '../helpers/test_app_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HistoryScreen - desativação de _showDebugInfo em modo somente leitura', () {
    const groupId = 'group-123';
    const tournamentId = 'session-123';

    final testMatch = MatchModel(
      id: 'match-debug-id',
      sessionId: tournamentId,
      teamAScore: 2,
      teamBScore: 1,
      lineups: const [],
      events: const [],
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('com isReadOnly = true: sem ações de edição e long press NÃO abre _showDebugInfo', (tester) async {
      setupTestAppServices(
        features: const AppFeatures.webReadonly(),
        matches: StubMatchesRepository(matches: [testMatch]),
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

      // Card da partida deve estar visível
      expect(find.text('Vermelho '), findsOneWidget);
      expect(find.text('2 x 1'), findsOneWidget);

      // Nenhuma ação de edição deve aparecer
      expect(find.byIcon(Icons.delete_forever), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);

      // Executa long press no card
      await tester.longPress(find.text('2 x 1'));
      await tester.pumpAndSettle();

      // BottomSheet de debug não deve abrir
      expect(find.text('match_id'), findsNothing);
      expect(find.text('session_id'), findsNothing);
      expect(find.text('match-debug-id'), findsNothing);
    });

    testWidgets('com isReadOnly = false e membro comum (isAdmin = false): sem botões de edição, debug bloqueado, lista e exportar visíveis', (tester) async {
      setupTestAppServices(
        features: const AppFeatures.personal(),
        matches: StubMatchesRepository(matches: [testMatch]),
        permissions: StubPermissionService(adminResult: false),
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

      // Card da partida deve estar visível
      expect(find.text('Vermelho '), findsOneWidget);
      expect(find.text('2 x 1'), findsOneWidget);

      // Botão exportar continua visível para membros
      expect(find.byIcon(Icons.download), findsOneWidget);

      // Ações de alteração não aparecem
      expect(find.byIcon(Icons.delete_forever), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);

      // Executa long press no card: não abre debug
      await tester.longPress(find.text('2 x 1'));
      await tester.pumpAndSettle();

      expect(find.text('match_id'), findsNothing);
      expect(find.text('session_id'), findsNothing);
      expect(find.text('match-debug-id'), findsNothing);
    });

    testWidgets('com isReadOnly = false (personal) e admin (isAdmin = true): ações visíveis e long press abre _showDebugInfo', (tester) async {
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

      // Card da partida deve estar visível
      expect(find.text('Vermelho '), findsOneWidget);
      expect(find.text('2 x 1'), findsOneWidget);

      // Ações de alteração aparecem para o admin
      expect(find.byIcon(Icons.delete_forever), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.download), findsOneWidget);

      // Executa long press no card
      await tester.longPress(find.text('2 x 1'));
      await tester.pumpAndSettle();

      // BottomSheet de debug deve abrir e mostrar os identificadores
      expect(find.text('match_id'), findsOneWidget);
      expect(find.text('session_id'), findsOneWidget);
      expect(find.text('match-debug-id'), findsOneWidget);
    });
  });
}
