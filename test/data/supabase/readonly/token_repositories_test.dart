import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/data/supabase/readonly/snapshot_source.dart';
import 'package:app_do_fut/data/supabase/readonly/token_groups_repository.dart';
import 'package:app_do_fut/data/supabase/readonly/token_matches_repository.dart';
import 'package:app_do_fut/data/supabase/readonly/token_membership_repository.dart';
import 'package:app_do_fut/data/supabase/readonly/token_players_repository.dart';
import 'package:app_do_fut/data/supabase/readonly/token_seasons_repository.dart';
import 'package:app_do_fut/data/supabase/readonly/token_session_arrivals_repository.dart';
import 'package:app_do_fut/data/supabase/readonly/token_sessions_repository.dart';
import 'package:app_do_fut/models/group_model.dart';
import 'package:app_do_fut/models/player_model.dart';
import 'package:app_do_fut/models/season_model.dart';
import 'package:app_do_fut/models/session_model.dart';
import 'package:app_do_fut/utils/overall_calculator.dart';

void main() {
  late SnapshotSource source;

  final sampleJson = {
    'group': {
      'id': 'grp-100',
      'name': 'Fut do INF',
      'created_at': '2026-01-01T00:00:00Z',
    },
    'seasons': [
      {
        'id': 'sea-1',
        'group_id': 'grp-100',
        'name': 'Temporada 1',
        'start_date': '2026-01-01',
        'end_date': '2026-06-30',
        'is_active': false,
      },
      {
        'id': 'sea-2',
        'group_id': 'grp-100',
        'name': 'Temporada 2',
        'start_date': '2026-07-01',
        'end_date': '2026-12-31',
        'is_active': true,
      },
    ],
    'sessions': [
      {
        'id': 'sess-1',
        'group_id': 'grp-100',
        'season_id': 'sea-2',
        'title': 'Pelada 01/11',
        'session_date': '2026-11-01T19:00:00Z',
        'status': 'finalizada',
        'player_count': 5,
        'win_limit': 2,
        'seconds_played': 600,
        'is_running': false,
        'score_red': 1,
        'score_white': 0,
        'red_streak': 1,
        'white_streak': 0,
        'is_overtime': false,
        'started_at': '2026-11-01T19:05:00Z',
      },
      {
        'id': 'sess-2',
        'group_id': 'grp-100',
        'season_id': 'sea-2',
        'title': 'Pelada 08/11',
        'session_date': '2026-11-08T19:00:00Z',
        'status': 'finalizada',
        'player_count': 6,
      },
    ],
    'players': [
      {
        'id': 'ply-1',
        'name': 'Enzo',
        'icon': 'https://example.com/enzo.png',
        'rating': 8.5,
        'monthly_highlight': true,
        'name_effect': 'gold',
        'community_pac': 80,
        'community_sho': 85,
        'community_pas': 82,
        'community_dri': 88,
        'community_def': 60,
        'community_phy': 75,
      },
      {
        'id': 'ply-2',
        'name': 'Rafa',
        'icon': null,
        'rating': 7.2,
      },
      {
        'id': 'ply-3',
        'name': 'Goleiro Bruno',
        'icon': null,
        'rating': 8.0,
      },
    ],
    'members': [
      {'player_id': 'ply-1', 'role': 'admin'},
      {'player_id': 'ply-2', 'role': 'member'},
    ],
    'matches': [
      {
        'id': 'mat-1',
        'session_id': 'sess-1',
        'status': 'finished',
        'played_at': '2026-11-01T19:15:00Z',
        'team_a_score': 2,
        'team_b_score': 1,
        'duration_seconds': 360,
      },
      {
        'id': 'mat-2',
        'session_id': 'sess-2',
        'status': 'finished',
        'played_at': '2026-11-08T19:15:00Z',
        'team_a_score': 0,
        'team_b_score': 0,
        'duration_seconds': 300,
      },
    ],
    'lineups': [
      {
        'id': 101,
        'match_id': 'mat-1',
        'player_id': 'ply-1',
        'team': 'red',
        'is_goalkeeper': false,
        'rating_snapshot': 8.5,
      },
      {
        'id': 102,
        'match_id': 'mat-1',
        'player_id': 'ply-2',
        'team': 'white',
        'is_goalkeeper': false,
        'rating_snapshot': 7.2,
      },
      {
        'id': 103,
        'match_id': 'mat-1',
        'player_id': 'ply-3',
        'team': 'red',
        'is_goalkeeper': true,
        'rating_snapshot': 8.0,
      },
    ],
    'events': [
      {
        'id': 201,
        'match_id': 'mat-1',
        'player_id': 'ply-1',
        'assist_player_id': null,
        'event_type': 'goal',
        'minute': '02:30',
        'team': 'red',
      },
    ],
  };

  setUp(() {
    source = SnapshotSource(
      token: 'tok-xyz',
      initialData: Map<String, dynamic>.from(sampleJson),
    );
  });

  group('TokenGroupsRepository', () {
    test('leitura retorna grupo do snapshot', () async {
      final repo = TokenGroupsRepository(source);
      expect(repo.lastLoadFromCache, isFalse);

      final groups = await repo.getMyGroups();
      expect(groups.length, 1);
      expect(groups.first.id, 'grp-100');
      expect(groups.first.name, 'Fut do INF');
    });

    test('métodos de escrita lançam UnsupportedError', () {
      final repo = TokenGroupsRepository(source);
      expect(
        () => repo.createGroup(name: 'Novo'),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => repo.updateGroup(const GroupModel(id: 'grp-100', name: 'Alterado')),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => repo.deleteGroup('grp-100'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('TokenSeasonsRepository', () {
    test('leitura retorna temporadas e temporada ativa', () async {
      final repo = TokenSeasonsRepository(source);
      final seasons = await repo.getSeasons('grp-100');
      expect(seasons.length, 2);
      expect(seasons.map((s) => s.name), containsAll(['Temporada 1', 'Temporada 2']));

      final current = await repo.getCurrentSeason('grp-100');
      expect(current, isNotNull);
      expect(current!.id, 'sea-2');
      expect(current.isActive, isTrue);
    });

    test('métodos de escrita lançam UnsupportedError', () {
      final repo = TokenSeasonsRepository(source);
      expect(
        () => repo.createSeason(groupId: 'grp-100', name: 'Nova'),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => repo.updateSeason(const SeasonModel(id: 'sea-1', groupId: 'grp-100', name: 'Alt')),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => repo.deleteSeason(groupId: 'grp-100', seasonId: 'sea-1'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('TokenSessionsRepository', () {
    test('leitura retorna sessões ordenadas e busca por id', () async {
      final repo = TokenSessionsRepository(source);
      final sessions = await repo.getSessionsByGroup('grp-100');
      expect(sessions.length, 2);
      // Mais recente primeiro (08/11 antes de 01/11)
      expect(sessions.first.id, 'sess-2');
      expect(sessions.last.id, 'sess-1');

      final s1 = await repo.getSessionById('sess-1');
      expect(s1, isNotNull);
      expect(s1!.title, 'Pelada 01/11');

      final cached = await repo.getCachedSession('sess-1');
      expect(cached?.id, 'sess-1');

      final runtime = await repo.getRuntimeState('sess-1');
      expect(runtime, isNotNull);
      expect(runtime!['seconds_played'], 600);
      expect(runtime['score_red'], 1);
    });

    test('métodos de escrita lançam UnsupportedError', () {
      final repo = TokenSessionsRepository(source);
      final dummy = SessionModel(
        id: 'sess-x',
        groupId: 'grp-100',
        title: 'X',
        sessionDate: DateTime.now(),
      );

      expect(() => repo.createSession(dummy), throwsA(isA<UnsupportedError>()));
      expect(() => repo.updateSession(dummy), throwsA(isA<UnsupportedError>()));
      expect(() => repo.updateRuntimeState('sess-1'), throwsA(isA<UnsupportedError>()));
      expect(() => repo.deleteSession('sess-1'), throwsA(isA<UnsupportedError>()));
    });
  });

  group('TokenMatchesRepository', () {
    test('leitura retorna partidas correlacionadas com escalações e eventos', () async {
      final repo = TokenMatchesRepository(source);
      final matchesSession1 = await repo.getMatchesBySession('sess-1');
      expect(matchesSession1.length, 1);

      final m1 = matchesSession1.first;
      expect(m1.id, 'mat-1');
      expect(m1.teamAScore, 2);
      expect(m1.teamBScore, 1);
      expect(m1.lineups.length, 3);
      expect(m1.events.length, 1);

      // Linhas com jogador preenchido
      final redPlayers = m1.players.red;
      expect(redPlayers.length, 2);
      expect(redPlayers.map((p) => p.name), containsAll(['Enzo', 'Goleiro Bruno']));
      expect(m1.players.gkRed?.name, 'Goleiro Bruno');
      expect(m1.players.white.first.name, 'Rafa');

      // Evento de gol
      expect(m1.events.first.eventType, 'goal');
      expect(m1.events.first.player?.name, 'Enzo');

      // Todas as partidas do grupo
      final allMatches = await repo.getMatchesByGroup('grp-100');
      expect(allMatches.length, 2);
    });

    test('métodos de escrita lançam UnsupportedError', () {
      final repo = TokenMatchesRepository(source);
      expect(
        () => repo.savePendingMatch(
          matchId: 'mat-x',
          match: {},
          lineups: [],
          events: [],
        ),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => repo.updatePartialMatch(
          matchId: 'mat-1',
          teamAScore: 1,
          teamBScore: 1,
          events: [],
        ),
        throwsA(isA<UnsupportedError>()),
      );
      expect(() => repo.deleteMatch('mat-1'), throwsA(isA<UnsupportedError>()));
    });
  });

  group('TokenPlayersRepository', () {
    test('leitura retorna elenco e busca por id', () async {
      final repo = TokenPlayersRepository(source);
      final players = await repo.getPlayersByGroup('grp-100');
      expect(players.length, 3);
      expect(players.map((p) => p.name), containsAll(['Enzo', 'Rafa', 'Goleiro Bruno']));

      final p1 = await repo.getPlayerById('ply-1');
      expect(p1, isNotNull);
      expect(p1!.name, 'Enzo');
      expect(p1.monthlyHighlight, isTrue);
      expect(p1.nameEffect, 'gold');

      final claims = await repo.claimGhostProfiles();
      expect(claims, isEmpty);
      final myPlayers = await repo.getMyPlayers();
      expect(myPlayers, isEmpty);
    });

    test('todas as mutações lançam UnsupportedError', () {
      final repo = TokenPlayersRepository(source);
      const dummy = PlayerModel(id: 'ply-1', name: 'Enzo');

      expect(() => repo.createGhostPlayer(groupId: 'grp-100', name: 'Novo'), throwsA(isA<UnsupportedError>()));
      expect(() => repo.updatePlayer(dummy), throwsA(isA<UnsupportedError>()));
      expect(() => repo.setPlayerIcon(playerId: 'ply-1', iconPath: null), throwsA(isA<UnsupportedError>()));
      expect(() => repo.setGoalSound(playerId: 'ply-1', audioFileName: null), throwsA(isA<UnsupportedError>()));
      expect(() => repo.removePlayerFromGroup(groupId: 'grp-100', playerId: 'ply-1'), throwsA(isA<UnsupportedError>()));
      expect(() => repo.setNameEffect(groupId: 'grp-100', playerId: 'ply-1', effect: null), throwsA(isA<UnsupportedError>()));
      expect(() => repo.setMonthlyHighlight(groupId: 'grp-100', playerId: 'ply-1', value: true), throwsA(isA<UnsupportedError>()));
      expect(() => repo.setCommunityAttributes(groupId: 'grp-100', playerId: 'ply-1', attributes: const CommunityAttributes()), throwsA(isA<UnsupportedError>()));
      expect(() => repo.setAdvancedStat(groupId: 'grp-100', playerId: 'ply-1', patch: {}), throwsA(isA<UnsupportedError>()));
    });
  });

  group('TokenMembershipRepository', () {
    test('leitura retorna membros com jogador anexado e myMembership nulo', () async {
      final repo = TokenMembershipRepository(source);
      final members = await repo.getMembers('grp-100');
      expect(members.length, 2);
      expect(members.first.playerId, 'ply-1');
      expect(members.first.role, 'admin');
      expect(members.first.player?.name, 'Enzo');

      final myMembership = await repo.getMyMembership('grp-100');
      expect(myMembership, isNull);
    });

    test('métodos de gestão e escrita lançam UnsupportedError', () {
      final repo = TokenMembershipRepository(source);
      expect(() => repo.promoteToAdmin(groupId: 'grp-100', playerId: 'ply-2'), throwsA(isA<UnsupportedError>()));
      expect(() => repo.demoteToMember(groupId: 'grp-100', playerId: 'ply-1'), throwsA(isA<UnsupportedError>()));
      expect(() => repo.findGroupByCode('ABCDEF'), throwsA(isA<UnsupportedError>()));
      expect(() => repo.requestToJoin(inviteCode: 'ABCDEF', desiredName: 'Fulano'), throwsA(isA<UnsupportedError>()));
      expect(() => repo.listPendingRequests('grp-100'), throwsA(isA<UnsupportedError>()));
      expect(() => repo.approveRequest('req-1'), throwsA(isA<UnsupportedError>()));
      expect(() => repo.rejectRequest('req-1'), throwsA(isA<UnsupportedError>()));
    });
  });

  group('TokenSessionArrivalsRepository', () {
    test('devolve lista e mapa vazios para leitura e bloqueia replace', () async {
      const repo = TokenSessionArrivalsRepository();
      expect(await repo.getArrivals('sess-1'), isEmpty);
      expect(await repo.getPlayerIdsBySessions(['sess-1']), isEmpty);
      expect(
        () => repo.replaceArrivals('sess-1', []),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
