import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/data/supabase/seasons_repository.dart';

void main() {
  group('buildCreateSeasonPayload', () {
    test('monta payload com id preenchido, uuid válido e campos corretos', () {
      const groupId = 'group-test-123';
      final startDate = DateTime(2026, 1, 15);
      final endDate = DateTime(2026, 12, 20);

      final payload = buildCreateSeasonPayload(
        groupId: groupId,
        name: '  Temporada 2026  ',
        startDate: startDate,
        endDate: endDate,
        isActive: true,
      );

      expect(payload['group_id'], equals(groupId));
      expect(payload['name'], equals('Temporada 2026'));
      expect(payload['start_date'], equals('2026-01-15'));
      expect(payload['end_date'], equals('2026-12-20'));
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

    test('trata datas nulas e isActive false corretamente', () {
      const groupId = 'group-456';
      final payload = buildCreateSeasonPayload(
        groupId: groupId,
        name: 'Temporada Sem Datas',
        startDate: null,
        endDate: null,
        isActive: false,
      );

      expect(payload['group_id'], equals(groupId));
      expect(payload['name'], equals('Temporada Sem Datas'));
      expect(payload['start_date'], isNull);
      expect(payload['end_date'], isNull);
      expect(payload['is_active'], isFalse);

      expect(payload.containsKey('id'), isTrue);
      expect(payload['id'], isNotNull);
    });

    test('duas chamadas geram ids diferentes', () {
      final payload1 = buildCreateSeasonPayload(
        groupId: 'group-1',
        name: 'Temp 1',
      );
      final payload2 = buildCreateSeasonPayload(
        groupId: 'group-2',
        name: 'Temp 2',
      );

      expect(payload1['id'], isNotNull);
      expect(payload2['id'], isNotNull);
      expect(payload1['id'], isNot(equals(payload2['id'])));
    });
  });
}
