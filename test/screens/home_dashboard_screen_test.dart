import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_do_fut/app/app_features.dart';
import 'package:app_do_fut/models/match_event_model.dart';
import 'package:app_do_fut/models/match_lineup_model.dart';
import 'package:app_do_fut/models/match_model.dart';
import 'package:app_do_fut/models/player_model.dart';
import 'package:app_do_fut/models/session_model.dart';
import 'package:app_do_fut/screens/group_dashboard_screen.dart';
import 'package:app_do_fut/screens/web/home_dashboard_screen.dart';
import 'package:app_do_fut/services/dashboard_store.dart';
import 'package:app_do_fut/services/group_bootstrap.dart';
import '../helpers/test_app_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DashboardStore.instance.reset();
    GroupBootstrap.instance.clearMemorySnapshots();
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: HomeDashboardScreen(groupId: 'g'))));
    // Primeiro quadro: esqueleto/spinner, antes de qualquer cálculo.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // O prefetch usa compute() (isolate): precisa de tempo real no teste.
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('estados vazios: sem peladas', (tester) async {
    setupTestAppServices(features: const AppFeatures.webReadonly());
    await pumpHome(tester);
    expect(find.text('Sem peladas ainda.'), findsOneWidget);
    expect(find.text('Craque do mês (selo oficial)'), findsNothing);
    expect(find.textContaining('Destaque do mês'), findsNWidgets(2));
  });

  testWidgets('cartões com dados: poucos jogos, destaque e última pelada', (tester) async {
    final now = DateTime.now();
    final players = [
      const PlayerModel(id: 'a', name: 'Ana', monthlyHighlight: true),
      const PlayerModel(id: 'b', name: 'Beto'),
    ];
    final matches = [
      for (var i = 0; i < 5; i++)
        MatchModel(
          id: 'm$i',
          sessionId: 's1',
          startTime: now,
          teamAScore: 1,
          teamBScore: 0,
          lineups: const [
            MatchLineupModel(matchId: 'm', playerId: 'a', team: MatchLineupModel.teamA),
            MatchLineupModel(matchId: 'm', playerId: 'b', team: MatchLineupModel.teamB),
          ],
          events: [
            MatchEventModel(matchId: 'm$i', playerId: 'a', eventType: 'goal', team: 'red'),
          ],
        ),
    ];
    setupTestAppServices(
      features: const AppFeatures.webReadonly(),
      players: StubPlayersRepository(players: players),
      matches: StubMatchesRepository(matches: matches),
      sessions: StubSessionsRepository(sessions: [
        SessionModel(id: 's1', groupId: 'g', title: 'Pelada de Terça', sessionDate: DateTime(now.year, now.month, 1, 12)),
      ]),
    );
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpHome(tester);
    expect(find.text('Ana'), findsWidgets);
    expect(find.text('Craque do mês (selo oficial)'), findsOneWidget);
    expect(find.textContaining('Pelada de Terça'), findsOneWidget);
    expect(find.text('Garçom do mês'), findsOneWidget);
  });

  testWidgets('aba Início existe em site (isReadOnly) e no app', (tester) async {
    for (final f in [const AppFeatures.webReadonly(), const AppFeatures.personal()]) {
      setupTestAppServices(features: f);
      await tester.pumpWidget(const MaterialApp(home: GroupDashboardScreen(groupId: 'g', groupName: 'G')));
      await tester.pump();
      expect(find.text('Início'), findsWidgets);
      expect(find.byType(HomeDashboardScreen), findsOneWidget);
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
