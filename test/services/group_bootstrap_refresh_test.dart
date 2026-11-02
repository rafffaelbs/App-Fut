import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_do_fut/models/player_model.dart';
import 'package:app_do_fut/services/group_bootstrap.dart';
import 'package:app_do_fut/utils/rating_calculator.dart';
import '../helpers/test_app_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GroupBootstrap.refreshLocalSnapshot', () {
    const groupId = 'test-group-1';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('refaz o snapshot a partir do repositório preservando ratings anteriores', () async {
      final prefs = await SharedPreferences.getInstance();

      // Snapshot inicial com jogador p1 tendo nota 8.8
      final initialSnapshot = [
        {
          'id': 'p1',
          'name': 'Jogador 1 Antigo',
          'rating': 8.8,
          'overall': 88,
        }
      ];
      await prefs.setString('players_$groupId', jsonEncode(initialSnapshot));

      // Repositório agora tem p1 (renomeado) e p2 (novo)
      final repoPlayers = [
        const PlayerModel(id: 'p1', name: 'Jogador 1 Renomeado'),
        const PlayerModel(id: 'p2', name: 'Jogador 2 Novo'),
      ];
      final fakeRepo = StubPlayersRepository(players: repoPlayers);
      setupTestAppServices(players: fakeRepo);

      final success = await GroupBootstrap.refreshLocalSnapshot(groupId);
      expect(success, isTrue);

      final savedRaw = prefs.getString('players_$groupId');
      expect(savedRaw, isNotNull);
      final List savedList = jsonDecode(savedRaw!);
      expect(savedList.length, equals(2));

      final p1Map = savedList.firstWhere((p) => p['id'] == 'p1');
      expect(p1Map['name'], equals('Jogador 1 Renomeado'));
      expect(p1Map['rating'], equals(8.8)); // Preservou rating anterior!
      expect(p1Map['overall'], isNotNull);

      final p2Map = savedList.firstWhere((p) => p['id'] == 'p2');
      expect(p2Map['name'], equals('Jogador 2 Novo'));
      expect(p2Map['rating'], equals(kRatingBase)); // Usou base
      expect(p2Map['overall'], isNotNull);
    });

    test('retorna false e não estoura erro se repositório falhar', () async {
      final fakeRepo = StubPlayersRepository(shouldThrow: true);
      setupTestAppServices(players: fakeRepo);

      final success = await GroupBootstrap.refreshLocalSnapshot(groupId);
      expect(success, isFalse);
    });

    test('respeita allowEmpty: false (retorna false) e allowEmpty: true (salva lista vazia)', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('players_$groupId', jsonEncode([
        {'id': 'p1', 'name': 'P1', 'rating': 7.0, 'overall': 70}
      ]));

      final emptyRepo = StubPlayersRepository(players: []);
      setupTestAppServices(players: emptyRepo);

      // allowEmpty: false (padrão) -> não sobrescreve com vazio e retorna false
      final resFalse = await GroupBootstrap.refreshLocalSnapshot(groupId, allowEmpty: false);
      expect(resFalse, isFalse);
      expect(prefs.getString('players_$groupId'), isNotNull);

      // allowEmpty: true -> aceita lista vazia e retorna true
      final resTrue = await GroupBootstrap.refreshLocalSnapshot(groupId, allowEmpty: true);
      expect(resTrue, isTrue);
      expect(prefs.getString('players_$groupId'), equals('[]'));
    });
  });
}
