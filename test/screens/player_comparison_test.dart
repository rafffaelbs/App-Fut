import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_do_fut/models/player_model.dart';
import 'package:app_do_fut/screens/player_comparison_screen.dart';
import '../helpers/test_app_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerComparisonScreen busca no repositório quando jogador não está no snapshot', () {
    const groupId = 'test-group-cmp';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('não exibe "Desconhecido" quando o jogador não está no snapshot mas existe no repositório', (tester) async {
      final prefs = await SharedPreferences.getInstance();

      // Snapshot contém apenas o Jogador 1
      final snapshot = [
        {
          'id': 'p1',
          'name': 'Ronaldo Fenômeno',
          'rating': 9.5,
          'overall': 95,
        }
      ];
      await prefs.setString('players_$groupId', jsonEncode(snapshot));

      // Repositório contém Jogador 1 e Jogador 2
      final repoPlayers = [
        const PlayerModel(id: 'p1', name: 'Ronaldo Fenômeno'),
        const PlayerModel(id: 'p2', name: 'Rivaldo'),
      ];
      final fakeRepo = StubPlayersRepository(players: repoPlayers);
      setupTestAppServices(players: fakeRepo);

      await tester.pumpWidget(
        const MaterialApp(
          home: PlayerComparisonScreen(
            groupId: groupId,
            player1Id: 'p1',
            player2Id: 'p2',
          ),
        ),
      );

      // Espera carregamento de dados (_loadData)
      await tester.pumpAndSettle();

      expect(find.text('Ronaldo Fenômeno'), findsOneWidget);
      expect(find.text('Rivaldo'), findsOneWidget);
      expect(find.text('Desconhecido'), findsNothing);
    });

    testWidgets('exibe "Desconhecido" se o jogador não existir nem no snapshot nem no repositório', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('players_$groupId', jsonEncode([]));

      final fakeRepo = StubPlayersRepository(players: []);
      setupTestAppServices(players: fakeRepo);

      await tester.pumpWidget(
        const MaterialApp(
          home: PlayerComparisonScreen(
            groupId: groupId,
            player1Id: 'p1',
            player2Id: 'p999', // inexistente
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Desconhecido'), findsWidgets);
    });
  });
}
