import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_do_fut/data/supabase/readonly/snapshot_source.dart';

void main() {
  group('SnapshotSource tests', () {
    test('carrega UMA vez e guarda JSON e modelos em memória', () async {
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
      expect(source.cachedGroup?.name, 'Fut do INF');
      expect(source.seasons.length, 1);
      expect(source.sessions.length, 1);
      expect(source.players.length, 2);
      expect(source.cachedPlayers.length, 2);
      expect(source.members.length, 2);
      expect(source.matches.length, 1);
      expect(source.cachedMatches.length, 1);
      expect(source.lineups.length, 1);
      expect(source.events.length, 1);

      // Segunda chamada não incrementa callCount (lê da memória)
      final data2 = await source.load();
      expect(callCount, 1);
      expect(identical(data1, data2), isTrue);

      // Instâncias de modelos mantidas em memória
      expect(identical(source.cachedPlayers, source.cachedPlayers), isTrue);
      expect(identical(source.cachedMatches, source.cachedMatches), isTrue);

      // refresh() força nova chamada
      await source.refresh();
      expect(callCount, 2);
    });

    test('P0001 e invalid_link viram InvalidLinkException', () async {
      final sourceP0001 = SnapshotSource(
        token: 'token_p0001',
        rpcCaller: (token) async {
          throw const PostgrestException(
            message: 'Erro desconhecido',
            code: 'P0001',
          );
        },
      );
      expect(
        () => sourceP0001.load(),
        throwsA(isA<InvalidLinkException>()),
      );

      final sourceMessage = SnapshotSource(
        token: 'token_msg',
        rpcCaller: (token) async {
          throw const PostgrestException(
            message: 'error: invalid_link for token',
            code: '42501',
          );
        },
      );
      expect(
        () => sourceMessage.load(),
        throwsA(isA<InvalidLinkException>()),
      );
    });

    test('erro de rede ou timeout NÃO vira InvalidLinkException', () async {
      final sourceTimeout = SnapshotSource(
        token: 'token_timeout',
        rpcCaller: (token) async {
          throw TimeoutException('Tempo esgotado');
        },
      );
      expect(
        () => sourceTimeout.load(),
        throwsA(isA<TimeoutException>()),
      );

      final sourceNetwork = SnapshotSource(
        token: 'token_net',
        rpcCaller: (token) async {
          throw Exception('Failed host lookup: db.supabase.co');
        },
      );
      expect(
        () => sourceNetwork.load(),
        throwsA(isA<Exception>().having(
          (e) => e is InvalidLinkException,
          'não é InvalidLinkException',
          isFalse,
        )),
      );
    });

    test('sanitização profunda: email, creator_id, invite_code, sync_code e goal_sound_url nunca chegam aos modelos', () async {
      final source = SnapshotSource(
        token: 'token_sanitized',
        initialData: {
          'group': {
            'id': 'g1',
            'name': 'Grupo Secreto',
            'creator_id': 'admin-uuid-123',
            'invite_code': 'INVITE999',
            'sync_code': 'SYNC-CODE-000',
          },
          'players': [
            {
              'id': 'p1',
              'name': 'Jogador Teste',
              'email': 'secreto@email.com',
              'creator_id': 'admin-uuid-123',
              'goal_sound_url': 'https://storage/som.mp3',
            }
          ],
          'matches': [
            {
              'id': 'm1',
              'group_id': 'g1',
              'session_id': 's1',
              'creator_id': 'admin-uuid-123',
            }
          ],
          'lineups': [],
          'events': [],
        },
      );

      // No mapa sanitizado bruto:
      final rawGroup = source.group!;
      expect(rawGroup.containsKey('creator_id'), isFalse);
      expect(rawGroup.containsKey('invite_code'), isFalse);
      expect(rawGroup.containsKey('sync_code'), isFalse);

      final rawPlayer = source.players.first as Map;
      expect(rawPlayer.containsKey('email'), isFalse);
      expect(rawPlayer.containsKey('creator_id'), isFalse);
      expect(rawPlayer.containsKey('goal_sound_url'), isFalse);

      // Nos modelos convertidos:
      final groupModel = source.cachedGroup!;
      expect(groupModel.creatorId, isNull);
      expect(groupModel.inviteCode, isNull);

      final playerModel = source.cachedPlayers.first;
      expect(playerModel.email, isNull);
      expect(playerModel.creatorId, isNull);
      expect(playerModel.goalSoundUrl, isNull);
    });

    test('JSON com campos faltando não quebra a conversão de modelos', () async {
      final source = SnapshotSource(
        token: 'token_sparse',
        initialData: {
          'group': {'id': 'g-sparse', 'name': 'Grupo Mínimo'},
          'players': [
            {'id': 'p-sparse', 'name': 'Apenas Nome'}
          ],
          'matches': [
            {'id': 'm-sparse'}
          ],
          // sem seasons, sessions, members, lineups, events
        },
      );

      expect(source.cachedGroup?.id, 'g-sparse');
      expect(source.cachedPlayers.length, 1);
      expect(source.cachedPlayers.first.name, 'Apenas Nome');
      expect(source.cachedMatches.length, 1);
      expect(source.cachedMatches.first.id, 'm-sparse');
      expect(source.seasons, isEmpty);
      expect(source.sessions, isEmpty);
      expect(source.members, isEmpty);
    });

    test('lança StateError quando SupabaseClient é nulo e rpcCaller é nulo', () async {
      final source = SnapshotSource(token: 'any_token');
      expect(() => source.load(), throwsStateError);
    });
  });
}
