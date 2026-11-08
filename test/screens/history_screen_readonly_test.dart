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

    testWidgets('com isReadOnly = true: long press NÃO abre _showDebugInfo', (tester) async {
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

      // Executa long press no card
      await tester.longPress(find.text('2 x 1'));
      await tester.pumpAndSettle();

      // BottomSheet de debug não deve abrir
      expect(find.text('match_id'), findsNothing);
      expect(find.text('session_id'), findsNothing);
      expect(find.text('match-debug-id'), findsNothing);
    });

    testWidgets('com isReadOnly = false (personal): long press abre _showDebugInfo', (tester) async {
      setupTestAppServices(
        features: const AppFeatures.personal(),
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
