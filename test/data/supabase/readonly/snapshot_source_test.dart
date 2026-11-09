import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/data/supabase/readonly/snapshot_source.dart';

void main() {
  group('SnapshotSource tests', () {
    test('carrega UMA vez e guarda JSON em memória', () async {
      int callCount = 0;
      final source = SnapshotSource(
        token: 'valid_token_123',
        rpcCaller: (token) async {
          callCount++;
          return {
            'group': {'id': 'g1', 'name': 'Fut do INF'},
            'seasons': [
              {'id': 's1', 'group_id': 'g1', 'name': '2026.1', 'is_active': true}
            ],
            'sessions': [
              {
                'id': 'sess1',
                'group_id': 'g1',
                'title': 'Pelada #1',
                'session_date': '2026-11-01T20:00:00Z',
              }
            ],
            'players': [
              {'id': 'p1', 'name': 'Enzo'},
              {'id': 'p2', 'name': 'Rafa'}
            ],
            'members': [
              {'player_id': 'p1', 'role': 'admin'},
              {'player_id': 'p2', 'role': 'member'}
            ],
            'matches': [
              {
                'id': 'm1',
                'session_id': 'sess1',
                'team_a_score': 3,
                'team_b_score': 2,
              }
            ],
            'lineups': [
              {
                'id': 1,
                'match_id': 'm1',
                'player_id': 'p1',
                'team': 'red',
                'is_goalkeeper': false,
              }
            ],
            'events': [
              {
                'id': 10,
                'match_id': 'm1',
                'player_id': 'p1',
                'event_type': 'goal',
              }
            ],
          };
        },
      );

      expect(source.hasData, isFalse);

      final data1 = await source.load();
      expect(callCount, 1);
      expect(source.hasData, isTrue);
      expect(source.group?['name'], 'Fut do INF');
      expect(source.seasons.length, 1);
      expect(source.sessions.length, 1);
      expect(source.players.length, 2);
      expect(source.members.length, 2);
      expect(source.matches.length, 1);
      expect(source.lineups.length, 1);
      expect(source.events.length, 1);

      // Segunda chamada não incrementa callCount (lê da memória)
      final data2 = await source.load();
      expect(callCount, 1);
      expect(identical(data1, data2), isTrue);

      // refresh() força nova chamada
      await source.refresh();
      expect(callCount, 2);
    });

    test('lança erro quando token é inválido ou rpc falha', () async {
      final source = SnapshotSource(
        token: 'invalid_token',
        rpcCaller: (token) async {
          throw Exception('invalid_link');
        },
      );

      expect(() => source.load(), throwsA(isA<Exception>()));
    });

    test('lança StateError quando SupabaseClient é nulo e rpcCaller é nulo', () async {
      final source = SnapshotSource(token: 'any_token');
      expect(() => source.load(), throwsStateError);
    });
  });
}
