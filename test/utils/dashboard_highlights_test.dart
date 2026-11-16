import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/models/player_model.dart';
import 'package:app_do_fut/models/season_model.dart';
import 'package:app_do_fut/models/session_model.dart';
import 'package:app_do_fut/utils/dashboard_highlights.dart';

Map<String, dynamic> p(String id) => {'id': id, 'name': id, 'icon': null};

Map<String, dynamic> match(
  String sid, {
  List<String> red = const [],
  List<String> white = const [],
  String? gkRed,
  int sr = 1,
  int sw = 0,
  List<Map<String, dynamic>> events = const [],
}) =>
    {
      'sessionId': sid,
      'scoreRed': sr,
      'scoreWhite': sw,
      'events': events,
      'players': {
        'red': red.map(p).toList(),
        'white': white.map(p).toList(),
        'gk_red': gkRed == null ? null : p(gkRed),
        'gk_white': null,
      },
      'isExactCurrentSeason': true,
    };

Map<String, dynamic> goal(String by, [String? assist]) =>
    {'type': 'goal', 'player': by, 'playerId': by, 'assist': assist ?? '', 'assistId': assist ?? ''};

SessionModel sess(String id, DateTime d, {String status = SessionModel.statusFinished}) =>
    SessionModel(id: id, groupId: 'g', title: 'Pelada $id', sessionDate: d, status: status);

List<dynamic> five(String sid, List<Map<String, dynamic>> events, {List<String> red = const ['a', 'b'], String? gk}) =>
    List.generate(5, (i) => match(sid, red: red, white: ['z'], gkRed: gk, events: i == 0 ? events : const []));

void main() {
  final oct = DateTime(2026, 10, 10, 20);
  final sessions = [sess('s1', oct)];

  test('mês pela data da pelada: 31/10 à noite fica em outubro', () {
    final s = [sess('s1', DateTime(2026, 10, 31, 23, 30))];
    final h = five('s1', [goal('a')]);
    expect(monthlyHighlight(h, s, '2026-10').map((e) => e.playerId), contains('a'));
    expect(monthlyHighlight(h, s, '2026-11'), isEmpty);
  });

  test('mínimo de 5 partidas', () {
    final h = five('s1', [goal('a')]).take(4).toList();
    expect(monthlyHighlight(h, sessions, '2026-10'), isEmpty);
    expect(matchesInMonth(h, sessions, '2026-10'), 4);
  });

  test('desempate G+A -> gols -> vitórias -> nome', () {
    final h = [
      ...five('s1', [goal('a'), goal('b'), goal('c', 'd')], red: ['a', 'b', 'c', 'd']),
    ];
    // a=1,b=1,c=1,d=assist 1 -> G+A todos 1; gols: a,b,c =1, d=0
    final r = monthlyHighlight(h, sessions, '2026-10');
    expect(r.map((e) => e.playerId), ['a', 'b', 'c']); // empate total -> nome
    final h2 = five('s1', [goal('b', 'a'), goal('b')], red: ['a', 'b']);
    final r2 = monthlyHighlight(h2, sessions, '2026-10');
    expect(r2.first.playerId, 'b'); // G+A 2 vs 1
  });

  test('gol contra ignorado; assistência só em gol', () {
    final h = five('s1', [
      {'type': 'own_goal', 'player': 'a', 'playerId': 'a'},
      {'type': 'yellow_card', 'player': 'a', 'playerId': 'a', 'assist': 'b', 'assistId': 'b'},
    ]);
    final r = monthlyHighlight(h, sessions, '2026-10');
    expect(r.every((e) => e.goals == 0 && e.assists == 0), isTrue);
  });

  test('goleiro excluído', () {
    final h = five('s1', [goal('gk1')], gk: 'gk1');
    final r = monthlyHighlight(h, sessions, '2026-10');
    expect(r.any((e) => e.playerId == 'gk1'), isFalse);
  });

  test('partida sem data/pelada ignorada', () {
    final h = [...five('s1', [goal('a')]), match('', red: ['a']), match('sx', red: ['a'])];
    final r = monthlyHighlight(h, sessions, '2026-10');
    expect(r.firstWhere((e) => e.playerId == 'a').matches, 5);
  });

  test('mês sem dados', () {
    expect(monthlyHighlight(five('s1', []), sessions, '2026-09'), isEmpty);
    expect(topScorerOfMonth(five('s1', []), sessions, '2026-09'), isNull);
    expect(topAssisterOfMonth(five('s1', []), sessions, '2026-09'), isNull);
  });

  test('artilheiro e garçom', () {
    final h = five('s1', [goal('a', 'b'), goal('a', 'b'), goal('b')]);
    expect(topScorerOfMonth(h, sessions, '2026-10')!.playerId, 'a');
    expect(topAssisterOfMonth(h, sessions, '2026-10')!.playerId, 'b');
  });

  test('última pelada com empate de artilheiros e maior goleada', () {
    final h = [
      match('s1', red: ['a'], white: ['b'], sr: 1, sw: 1, events: [goal('a'), goal('b')]),
      match('s1', red: ['a'], white: ['b'], sr: 4, sw: 0, events: []),
    ];
    final r = lastSessionSummary(h, sessions)!;
    expect(r.matches, 2);
    expect(r.totalGoals, 6);
    expect(r.bigWinWinner, 'red');
    expect(r.bigWinRedScore, 4);
    expect(r.topScorers.map((e) => e.playerId), ['a', 'b']);
  });

  test('última pelada: ignora em andamento e sem partidas', () {
    final s = [
      sess('s1', oct),
      sess('s2', DateTime(2026, 11, 1), status: SessionModel.statusInProgress),
      sess('s3', DateTime(2026, 11, 2)),
    ];
    final r = lastSessionSummary([match('s1', red: ['a'])], s)!;
    expect(r.sessionId, 's1');
    expect(lastSessionSummary([], s), isNull);
  });

  test('previousMonthKey vira o ano', () {
    expect(previousMonthKey('2026-01'), '2025-12');
  });

  group('computeGroupOverview', () {
    final playerA = PlayerModel(id: 'a', name: 'Jogador A');
    final playerB = PlayerModel(id: 'b', name: 'Jogador B');
    final playerC = PlayerModel(id: 'c', name: 'Jogador C');
    final season = SeasonModel(
      id: 'season_1',
      groupId: 'g',
      name: 'Temporada 2026',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
    );

    test('vazio retorna zeros', () {
      final ov = computeGroupOverview(
        allHistory: [],
        sessions: [],
        players: [],
        currentSeason: season,
      );
      expect(ov.totalMatches, 0);
      expect(ov.totalSessions, 0);
      expect(ov.totalPlayers, 0);
      expect(ov.activePlayersSeason, 0);
      expect(ov.totalGoals, 0);
      expect(ov.averageGoalsPerMatch, 0.0);
      expect(ov.playerMatches, isEmpty);
      expect(ov.playerSessions, isEmpty);
    });

    test('calcula totais, ativos na temporada (>= 5 jogos) e participações individuais', () {
      final s1 = sess('s1', DateTime(2026, 10, 10));
      final s2 = sess('s2', DateTime(2026, 10, 17));
      final List<SessionModel> sList = [s1, s2];
      final List<PlayerModel> pList = [playerA, playerB, playerC];

      // Partidas em s1: 4 partidas com a, b; 1 com goleiro c
      // Partidas em s2: 2 partidas com a
      final history = [
        match('s1', red: ['a'], white: ['b'], sr: 2, sw: 1),
        match('s1', red: ['a'], white: ['b'], sr: 3, sw: 0),
        match('s1', red: ['a'], white: ['b'], sr: 1, sw: 1),
        match('s1', red: ['a'], white: ['b'], sr: 2, sw: 2),
        match('s1', red: ['a'], white: ['b'], gkRed: 'c', sr: 1, sw: 0),
        match('s2', red: ['a'], white: [], sr: 1, sw: 0),
        match('s2', red: ['a'], white: [], sr: 0, sw: 0),
      ];

      final ov = computeGroupOverview(
        allHistory: history,
        sessions: sList,
        players: pList,
        currentSeason: season,
      );

      // 7 partidas no total
      expect(ov.totalMatches, 7);
      // 2 sessões
      expect(ov.totalSessions, 2);
      // 3 jogadores
      expect(ov.totalPlayers, 3);
      // Gols: 2+1 + 3+0 + 1+1 + 2+2 + 1+0 + 1+0 + 0 = 14 gols
      expect(ov.totalGoals, 14);
      expect(ov.averageGoalsPerMatch, 2.0);

      // Jogos individuais:
      // a jogou em todas as 7 partidas
      expect(ov.playerMatches['a'], 7);
      // b jogou em 5 partidas
      expect(ov.playerMatches['b'], 5);
      // c jogou em 1 partida (como goleiro)
      expect(ov.playerMatches['c'], 1);

      // Sessões individuais:
      // a participou de s1 e s2
      expect(ov.playerSessions['a'], 2);
      // b participou de s1
      expect(ov.playerSessions['b'], 1);
      // c participou de s1
      expect(ov.playerSessions['c'], 1);

      // Ativos na temporada (>= 5 jogos):
      // a tem 7 jogos (ativo)
      // b tem 5 jogos (ativo)
      // c tem 1 jogo (não ativo)
      expect(ov.activePlayersSeason, 2);
    });

    test('partida fora da temporada atual não conta para jogador ativo na temporada', () {
      final sPast = sess('s_past', DateTime(2025, 5, 1));
      final List<SessionModel> sList = [sPast];
      final List<PlayerModel> pList = [playerA];

      // 5 jogos em 2025 (fora da season de 2026)
      final history = List.generate(5, (_) => match('s_past', red: ['a']));

      final ov = computeGroupOverview(
        allHistory: history,
        sessions: sList,
        players: pList,
        currentSeason: season,
      );

      expect(ov.totalMatches, 5);
      expect(ov.playerMatches['a'], 5);
      // Não conta como ativo na temporada atual
      expect(ov.activePlayersSeason, 0);
    });
  });
}
