import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_do_fut/data/prefs/prefs_custom_badges_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrefsCustomBadgesRepository tests', () {
    test('chave ausente x chave com lista vazia', () async {
      SharedPreferences.setMockInitialValues({
        'custom_badges_group-empty': jsonEncode([]),
      });
      final repo = PrefsCustomBadgesRepository();

      // Chave ausente
      expect(await repo.hasCustomBadges('group-absent'), isFalse);
      final absentResult = await repo.getCustomBadges('group-absent');
      expect(absentResult, isEmpty);

      // Chave com lista vazia
      expect(await repo.hasCustomBadges('group-empty'), isTrue);
      final emptyResult = await repo.getCustomBadges('group-empty');
      expect(emptyResult, isEmpty);
    });

    test('salvar e ler preserva lista e propriedades das insígnias', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = PrefsCustomBadgesRepository();

      final badges = [
        {'id': 'b-1', 'title': 'Craque do Jogo', 'icon': 'trophy.png'},
        {'id': 'b-2', 'title': 'Paredão', 'icon': 'glove.png'},
      ];

      await repo.saveCustomBadges('grp-1', badges);
      expect(await repo.hasCustomBadges('grp-1'), isTrue);

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

      expect(await repo.hasCustomBadges('grp-corrupt'), isTrue);
      final result = await repo.getCustomBadges('grp-corrupt');
      expect(result, isEmpty);
    });

    test('item que não é Map é descartado na leitura', () async {
      SharedPreferences.setMockInitialValues({
        'custom_badges_grp-mixed': jsonEncode([
          'string_badge',
          123,
          {'id': 'b-valid-1', 'title': 'Goleador'},
          null,
          true,
          {'id': 'b-valid-2', 'title': 'Melhor Zagueiro'},
        ]),
      });
      final repo = PrefsCustomBadgesRepository();

      expect(await repo.hasCustomBadges('grp-mixed'), isTrue);
      final result = await repo.getCustomBadges('grp-mixed');
      expect(result, hasLength(2));
      expect(result[0]['id'], equals('b-valid-1'));
      expect(result[0]['title'], equals('Goleador'));
      expect(result[1]['id'], equals('b-valid-2'));
      expect(result[1]['title'], equals('Melhor Zagueiro'));
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
