import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_do_fut/app/app_features.dart';
import 'package:app_do_fut/screens/tournament_dashboard_screen.dart';
import 'package:app_do_fut/screens/match_screen.dart';
import '../helpers/test_app_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TournamentDashboardScreen - comportamento por flavor/isReadOnly', () {
    const groupId = 'test-group';
    const tournamentId = 'test-tournament';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('com isReadOnly = false (personal): exibe aba Campo e instancia MatchScreen', (tester) async {
      setupTestAppServices(
        features: const AppFeatures.personal(),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TournamentDashboardScreen(
            groupId: groupId,
            tournamentId: tournamentId,
            tournamentName: 'Pelada de Terça',
            totalPlayers: 10,
          ),
        ),
      );

      await tester.pump();

      // Aba campo deve existir na BottomNavigationBar
      expect(find.text('Campo'), findsOneWidget);
      expect(find.text('Ranking'), findsOneWidget);
      expect(find.text('Histórico'), findsOneWidget);

      // MatchScreen deve estar presente na árvore
      expect(find.byType(MatchScreen), findsOneWidget);
    });

    testWidgets('com isReadOnly = true (web_readonly): NÃO exibe aba Campo e NÃO instancia MatchScreen', (tester) async {
      setupTestAppServices(
        features: const AppFeatures.webReadonly(),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TournamentDashboardScreen(
            groupId: groupId,
            tournamentId: tournamentId,
            tournamentName: 'Pelada de Terça',
            totalPlayers: 10,
          ),
        ),
      );

      await tester.pump();

      // Aba Campo NÃO deve existir
      expect(find.text('Campo'), findsNothing);
      expect(find.text('Ranking'), findsOneWidget);
      expect(find.text('Histórico'), findsOneWidget);

      // MatchScreen NÃO deve existir na árvore
      expect(find.byType(MatchScreen), findsNothing);
    });
  });
}
