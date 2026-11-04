import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_do_fut/models/player_model.dart';
import 'package:app_do_fut/models/match_model.dart';
import 'package:app_do_fut/models/match_lineup_model.dart';
import 'package:app_do_fut/models/match_event_model.dart';
import 'package:app_do_fut/screens/ranking_screen.dart';
import '../helpers/test_app_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RankingScreen com snapshot players_<groupId> VAZIO', () {
    const groupId = 'test-group-rank';
    const tournamentId = 'test-session-rank';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('busca o elenco por AppServices.instance.players e não exibe erros', (tester) async {
      // Snapshot VAZIO (sem chave players_test-group-rank no SharedPreferences)
      final repoPlayers = [
        const PlayerModel(id: 'p1', name: 'Zico', rating: 9.0),
        const PlayerModel(id: 'p2', name: 'Sócrates', rating: 8.5),
      ];

      final fakeRepo = StubPlayersRepository(players: repoPlayers);
      final fakeMatchesRepo = StubMatchesRepository(
        matches: [
          MatchModel(
            id: 'm1',
            sessionId: tournamentId,
            teamAScore: 2,
            teamBScore: 1,
            startTime: DateTime(2026, 11, 3),
            lineups: const [
              MatchLineupModel(matchId: 'm1', playerId: 'p1', team: 'red'),
              MatchLineupModel(matchId: 'm1', playerId: 'p2', team: 'white'),
            ],
            events: const [
              MatchEventModel(matchId: 'm1', playerId: 'p1', eventType: 'goal', team: 'red'),
            ],
          ),
        ],
      );

      setupTestAppServices(
        players: fakeRepo,
        matches: fakeMatchesRepo,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RankingScreen(
              groupId: groupId,
              tournamentId: tournamentId,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Zico e Sócrates devem ser renderizados normalmente a partir do repositório
      expect(find.text('Zico'), findsWidgets);
      expect(find.text('Sócrates'), findsWidgets);
    });
  });
}
