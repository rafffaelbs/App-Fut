import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_do_fut/data/prefs/prefs_match_history_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrefsMatchHistoryStore tests', () {
    test('chave ausente x chave com lista vazia', () async {
      SharedPreferences.setMockInitialValues({
        'match_history_sess-empty': jsonEncode([]),
      });
      final store = PrefsMatchHistoryStore();

      // Chave ausente
      expect(await store.hasSession('sess-absent'), isFalse);
      final absentResult = await store.readSession('sess-absent');
      expect(absentResult, isEmpty);

      // Chave com lista vazia
      expect(await store.hasSession('sess-empty'), isTrue);
      final emptyResult = await store.readSession('sess-empty');
      expect(emptyResult, isEmpty);
    });

    test('adicionar duas vezes e ler preserva a ordem exata', () async {
      SharedPreferences.setMockInitialValues({});
      final store = PrefsMatchHistoryStore();

      await store.appendToSession('sess-1', {'id': 'match-first', 'order': 1});
      await store.appendToSession('sess-1', {'id': 'match-second', 'order': 2});

      expect(await store.hasSession('sess-1'), isTrue);
      final result = await store.readSession('sess-1');
      expect(result, hasLength(2));
      expect(result[0]['id'], equals('match-first'));
      expect(result[0]['order'], equals(1));
      expect(result[1]['id'], equals('match-second'));
      expect(result[1]['order'], equals(2));
    });

    test('JSON inválido retorna lista vazia e appendToSession recupera com segurança', () async {
      SharedPreferences.setMockInitialValues({
        'match_history_sess-corrupt': '{invalid-json-string-not-a-list',
      });
      final store = PrefsMatchHistoryStore();

      expect(await store.hasSession('sess-corrupt'), isTrue);
      final result = await store.readSession('sess-corrupt');
      expect(result, isEmpty);

      // Ao adicionar, deve tratar o erro e salvar nova lista válida
      await store.appendToSession('sess-corrupt', {'id': 'match-recovered'});
      final recovered = await store.readSession('sess-corrupt');
      expect(recovered, hasLength(1));
      expect(recovered[0]['id'], equals('match-recovered'));
    });

    test('item que não é Map é descartado na leitura', () async {
      SharedPreferences.setMockInitialValues({
        'match_history_sess-mixed': jsonEncode([
          'string_item',
          42,
          {'id': 'valid-match-1', 'scoreRed': 2, 'scoreWhite': 1},
          null,
          true,
          {'id': 'valid-match-2', 'scoreRed': 0, 'scoreWhite': 0},
        ]),
      });
      final store = PrefsMatchHistoryStore();

      expect(await store.hasSession('sess-mixed'), isTrue);
      final result = await store.readSession('sess-mixed');
      expect(result, hasLength(2));
      expect(result[0]['id'], equals('valid-match-1'));
      expect(result[0]['scoreRed'], equals(2));
      expect(result[1]['id'], equals('valid-match-2'));
      expect(result[1]['scoreRed'], equals(0));
    });

    test('nome exato da chave no SharedPreferences segue match_history_<sessionId>', () async {
      SharedPreferences.setMockInitialValues({});
      final store = PrefsMatchHistoryStore();

      await store.appendToSession('sess-xyz-99', {'id': 'm-test', 'scoreRed': 3});

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('match_history_sess-xyz-99'), isTrue);
      expect(PrefsMatchHistoryStore.keyFor('sess-xyz-99'), equals('match_history_sess-xyz-99'));

      final raw = prefs.getString('match_history_sess-xyz-99');
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as List;
      expect(decoded.first['scoreRed'], equals(3));
    });
  });
}
