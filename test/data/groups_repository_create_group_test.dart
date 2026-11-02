import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/data/supabase/groups_repository.dart';

void main() {
  group('buildDefaultSeasonPayload', () {
    test('monta payload com id preenchido, uuid válido e campos corretos', () {
      const groupId = 'group-test-123';
      final payload = buildDefaultSeasonPayload(groupId);

      expect(payload['group_id'], equals(groupId));
      expect(payload['name'], equals('Temporada 1'));
      expect(payload['is_active'], isTrue);

      expect(payload.containsKey('id'), isTrue);
      expect(payload['id'], isNotNull);
      final id = payload['id'] as String;
      expect(id, isNotEmpty);

      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      expect(uuidRegex.hasMatch(id), isTrue,
          reason: 'id deve ser um UUID v4 válido');
    });

    test('duas chamadas geram ids diferentes', () {
      final payload1 = buildDefaultSeasonPayload('group-1');
      final payload2 = buildDefaultSeasonPayload('group-2');

      expect(payload1['id'], isNotNull);
      expect(payload2['id'], isNotNull);
      expect(payload1['id'], isNot(equals(payload2['id'])));
    });
  });
}
