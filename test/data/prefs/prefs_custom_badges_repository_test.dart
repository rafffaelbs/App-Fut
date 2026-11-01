import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_do_fut/data/prefs/prefs_custom_badges_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrefsCustomBadgesRepository tests', () {
    test('chave ausente retorna lista vazia', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = PrefsCustomBadgesRepository();

      final result = await repo.getCustomBadges('group-absent');
      expect(result, isEmpty);
    });

    test('salvar e ler preserva lista e propriedades das insígnias', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = PrefsCustomBadgesRepository();

      final badges = [
        {'id': 'b-1', 'title': 'Craque do Jogo', 'icon': 'trophy.png'},
        {'id': 'b-2', 'title': 'Paredão', 'icon': 'glove.png'},
      ];

      await repo.saveCustomBadges('grp-1', badges);
      final result = await repo.getCustomBadges('grp-1');

      expect(result, hasLength(2));
      expect(result[0]['id'], equals('b-1'));
      expect(result[0]['title'], equals('Craque do Jogo'));
      expect(result[1]['id'], equals('b-2'));
      expect(result[1]['title'], equals('Paredão'));
    });

    test('JSON inválido retorna lista vazia sem lançar exceção', () async {
      SharedPreferences.setMockInitialValues({
        'custom_badges_grp-corrupt': 'invalid-json-string{corrupt',
      });
      final repo = PrefsCustomBadgesRepository();

      final result = await repo.getCustomBadges('grp-corrupt');
      expect(result, isEmpty);
    });

    test('nome exato da chave no SharedPreferences segue custom_badges_<groupId>', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = PrefsCustomBadgesRepository();

      await repo.saveCustomBadges('grp-test-99', [
        {'id': 'badge-x', 'title': 'Artilheiro'}
      ]);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('custom_badges_grp-test-99'), isTrue);
      expect(PrefsCustomBadgesRepository.keyFor('grp-test-99'), equals('custom_badges_grp-test-99'));

      final raw = prefs.getString('custom_badges_grp-test-99');
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as List;
      expect(decoded.first['id'], equals('badge-x'));
      expect(decoded.first['title'], equals('Artilheiro'));
    });
  });
}
