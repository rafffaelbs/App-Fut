import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_do_fut/data/prefs/prefs_match_history_store.dart';
import 'package:app_do_fut/domain/repositories/matches_repository.dart';
import 'package:app_do_fut/domain/repositories/players_repository.dart';
import 'package:app_do_fut/models/match_event_model.dart';
import 'package:app_do_fut/models/match_lineup_model.dart';
import 'package:app_do_fut/models/match_model.dart';
import 'package:app_do_fut/models/player_badge_model.dart';
import 'package:app_do_fut/models/player_model.dart';
import 'package:app_do_fut/utils/overall_calculator.dart';
import 'package:app_do_fut/utils/stats_calculator.dart';

class FakeMatchesRepository implements MatchesRepository {
  final List<MatchModel> matches;
  final bool shouldThrow;

  FakeMatchesRepository({
    this.matches = const [],
    this.shouldThrow = false,
  });

  @override
  Future<List<MatchModel>> getMatchesByGroup(String groupId) async {
    if (shouldThrow) {
      throw Exception('Simulated network error');
    }
    return matches;
  }

  @override
  Future<List<MatchModel>> getMatchesBySession(String sessionId) async => [];

  @override
  Future<void> savePendingMatch({
    required String matchId,
    required Map<String, dynamic> match,
    required List<Map<String, dynamic>> lineups,
    required List<Map<String, dynamic>> events,
    bool isRetry = false,
  }) async {}

  @override
  Future<MatchModel> updatePartialMatch({
    required String matchId,
    required int teamAScore,
    required int teamBScore,
    required List<MatchEventModel> events,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteMatch(String matchId) async {}
}

class FakePlayersRepository implements PlayersRepository {
  final List<PlayerModel> players;
  final bool shouldThrow;

  FakePlayersRepository({
    this.players = const [],
    this.shouldThrow = false,
  });

  @override
  Future<List<PlayerModel>> getPlayersByGroup(String groupId) async {
    if (shouldThrow) {
      throw Exception('Simulated players error');
    }
    return players;
  }

  @override
  Future<PlayerModel> createGhostPlayer({
    required String groupId,
    required String name,
    String? avatarUrl,
    List<PlayerBadgeModel> badges = const [],
  }) async =>
      throw UnimplementedError();

  @override
  Future<PlayerModel?> getPlayerById(String playerId) async => null;

  @override
  Future<void> removePlayerFromGroup({
    required String groupId,
    required String playerId,
  }) async {}

  @override
  Future<PlayerModel> setAdvancedStat({
    required String groupId,
    required String playerId,
    required Map<String, dynamic> patch,
  }) async =>
      throw UnimplementedError();

  @override
  Future<PlayerModel> setCommunityAttributes({
    required String groupId,
    required String playerId,
    required CommunityAttributes attributes,
  }) async =>
      throw UnimplementedError();

  @override
  Future<PlayerModel> setGoalSound({
    required String playerId,
    required String? audioFileName,
    String? groupId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<PlayerModel> setMonthlyHighlight({
    required String groupId,
    required String playerId,
    required bool value,
  }) async =>
      throw UnimplementedError();

  @override
  Future<PlayerModel> setNameEffect({
    required String groupId,
    required String playerId,
    required String? effect,
  }) async =>
      throw UnimplementedError();

  @override
  Future<PlayerModel> setPlayerIcon({
    required String playerId,
    required String? iconPath,
  }) async =>
      throw UnimplementedError();

  @override
  Future<PlayerModel> updatePlayer(PlayerModel player, {String? groupId}) async =>
      throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('getAllGroupMatches characterization tests', () {
    test('(a) repositórios respondendo com sucesso', () async {
      SharedPreferences.setMockInitialValues({});

      final matchesRepo = FakeMatchesRepository(
        matches: [
          MatchModel(
            id: 'match-101',
            sessionId: 'session-201',
            startTime: DateTime.parse('2026-05-10T19:00:00.000Z'),
            teamAScore: 3,
            teamBScore: 1,
            lineups: const [
              MatchLineupModel(
                matchId: 'match-101',
                playerId: 'p1',
                team: MatchLineupModel.teamA,
              ),
              MatchLineupModel(
                matchId: 'match-101',
                playerId: 'p2',
                team: MatchLineupModel.teamB,
              ),
            ],
            events: const [
              MatchEventModel(
                matchId: 'match-101',
                playerId: 'p1',
                assistPlayerId: 'p2',
                eventType: 'goal',
                team: 'red',
                minute: '4',
              ),
            ],
          ),
        ],
      );

      final playersRepo = FakePlayersRepository(
        players: const [
          PlayerModel(id: 'p1', name: 'Neymar'),
          PlayerModel(id: 'p2', name: 'Messi'),
        ],
      );

      final result = await getAllGroupMatches(
        'group-alpha',
        matchesRepository: matchesRepo,
        playersRepository: playersRepo,
      );

      expect(result, hasLength(1));
      expect(result.first, equals({
        'id': 'match-101',
        'sessionId': 'session-201',
        'scoreRed': 3,
        'scoreWhite': 1,
        'session_date': '2026-05-10T19:00:00.000Z',
        'date': '2026-05-10T19:00:00.000Z',
        'events': [
          {
            'player': 'p1',
            'playerId': 'p1',
            'assist': 'p2',
            'assistId': 'p2',
            'type': 'goal',
            'time': 'red',
            'minute': '4',
          }
        ],
        'players': {
          'red': [
            {'id': 'p1', 'name': 'Neymar', 'icon': null}
          ],
          'white': [
            {'id': 'p2', 'name': 'Messi', 'icon': null}
          ],
          'gk_red': null,
          'gk_white': null,
        },
        'isExactCurrentSeason': true,
      }));
    });

    test('(b) repositório lançando exceção (cai no fallback do SharedPreferences)', () async {
      SharedPreferences.setMockInitialValues({
        'sessions_group-alpha': jsonEncode([
          {'id': 'session-fb-1', 'timestamp': '2026-04-01T18:00:00.000Z'},
        ]),
        'match_history_session-fb-1': jsonEncode([
          {
            'id': 'm-local-99',
            'scoreRed': 2,
            'scoreWhite': 2,
            'players': {
              'red': [{'id': 'p1', 'name': 'Neymar'}],
              'white': [{'id': 'p2', 'name': 'Messi'}],
            },
          }
        ]),
      });

      final matchesRepo = FakeMatchesRepository(shouldThrow: true);
      final playersRepo = FakePlayersRepository();

      final result = await getAllGroupMatches(
        'group-alpha',
        matchesRepository: matchesRepo,
        playersRepository: playersRepo,
        matchHistoryStore: PrefsMatchHistoryStore(),
      );

      expect(result, hasLength(1));
      expect(result.first, equals({
        'id': 'm-local-99',
        'scoreRed': 2,
        'scoreWhite': 2,
        'session_date': '2026-04-01T18:00:00.000Z',
        'players': {
          'red': [{'id': 'p1', 'name': 'Neymar'}],
          'white': [{'id': 'p2', 'name': 'Messi'}],
        },
      }));
    });

    test('(c) grupo sem partidas', () async {
      SharedPreferences.setMockInitialValues({});

      final matchesRepo = FakeMatchesRepository(matches: []);
      final playersRepo = FakePlayersRepository(players: []);

      final result = await getAllGroupMatches(
        'group-empty',
        matchesRepository: matchesRepo,
        playersRepository: playersRepo,
        matchHistoryStore: PrefsMatchHistoryStore(),
      );

      expect(result, isEmpty);
    });

    test('(d) sessões legadas em sessions_<grupo>/seasons_<grupo>', () async {
      // Duas partidas em sessões diferentes, uma dentro da temporada ativa e outra fora
      SharedPreferences.setMockInitialValues({
        'sessions_group-legacy': jsonEncode([
          {'id': 'sess-active', 'timestamp': '2026-06-15T15:00:00.000Z'},
          {'id': 'sess-old', 'timestamp': '2020-01-01T15:00:00.000Z'},
        ]),
        'seasons_group-legacy': jsonEncode([
          {
            'id': 'season-2026',
            'startDate': '2026-01-01',
            'endDate': '2026-12-31',
            'isPreSeason': false,
          },
        ]),
        'match_history_sess-active': jsonEncode([
          {
            'id': 'm-active-1',
            'scoreRed': 1,
            'scoreWhite': 0,
            'date': '2026-06-15T15:00:00.000Z',
          }
        ]),
        'match_history_sess-old': jsonEncode([
          {
            'id': 'm-old-1',
            'scoreRed': 0,
            'scoreWhite': 1,
            'date': '2020-01-01T15:00:00.000Z',
          }
        ]),
      });

      final matchesRepo = FakeMatchesRepository(shouldThrow: true);
      final playersRepo = FakePlayersRepository();

      final result = await getAllGroupMatches(
        'group-legacy',
        matchesRepository: matchesRepo,
        playersRepository: playersRepo,
        matchHistoryStore: PrefsMatchHistoryStore(),
      );

      // Apenas a partida de 2026 deve ser incluída no filtro de temporada atual
      expect(result, hasLength(1));
      expect(result.first, equals({
        'id': 'm-active-1',
        'scoreRed': 1,
        'scoreWhite': 0,
        'date': '2026-06-15T15:00:00.000Z',
        'session_date': '2026-06-15T15:00:00.000Z',
        'isPreSeasonMatch': false,
        'isExactCurrentSeason': true,
      }));
    });

    test('(e) partida com goleiros (players.gk_red / gk_white)', () async {
      SharedPreferences.setMockInitialValues({});

      final matchesRepo = FakeMatchesRepository(
        matches: [
          MatchModel(
            id: 'match-gk-1',
            sessionId: 'session-gk',
            startTime: DateTime.parse('2026-05-12T19:00:00.000Z'),
            teamAScore: 1,
            teamBScore: 0,
            lineups: const [
              MatchLineupModel(
                matchId: 'match-gk-1',
                playerId: 'line-r',
                team: MatchLineupModel.teamA,
                isGoalkeeper: false,
              ),
              MatchLineupModel(
                matchId: 'match-gk-1',
                playerId: 'line-w',
                team: MatchLineupModel.teamB,
                isGoalkeeper: false,
              ),
              MatchLineupModel(
                matchId: 'match-gk-1',
                playerId: 'gk-r',
                team: MatchLineupModel.teamA,
                isGoalkeeper: true,
              ),
              MatchLineupModel(
                matchId: 'match-gk-1',
                playerId: 'gk-w',
                team: MatchLineupModel.teamB,
                isGoalkeeper: true,
              ),
            ],
            events: const [],
          ),
        ],
      );

      final playersRepo = FakePlayersRepository(
        players: const [
          PlayerModel(id: 'line-r', name: 'Atacante Red'),
          PlayerModel(id: 'line-w', name: 'Atacante White'),
          PlayerModel(id: 'gk-r', name: 'Goleiro Red'),
          PlayerModel(id: 'gk-w', name: 'Goleiro White'),
        ],
      );

      final result = await getAllGroupMatches(
        'group-gk',
        matchesRepository: matchesRepo,
        playersRepository: playersRepo,
      );

      expect(result, hasLength(1));
      final match = result.first as Map<String, dynamic>;
      final players = match['players'] as Map<String, dynamic>;

      expect(players['gk_red'], equals({
        'id': 'gk-r',
        'name': 'Goleiro Red',
        'icon': null,
      }));
      expect(players['gk_white'], equals({
        'id': 'gk-w',
        'name': 'Goleiro White',
        'icon': null,
      }));
      expect(players['red'], equals([
        {'id': 'line-r', 'name': 'Atacante Red', 'icon': null}
      ]));
      expect(players['white'], equals([
        {'id': 'line-w', 'name': 'Atacante White', 'icon': null}
      ]));
    });
  });
}
