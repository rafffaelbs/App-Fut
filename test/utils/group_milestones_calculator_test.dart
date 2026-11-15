import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/models/milestone_update.dart';
import 'package:app_do_fut/models/player_model.dart';
import 'package:app_do_fut/models/season_model.dart';
import 'package:app_do_fut/utils/group_milestones_calculator.dart';

PlayerModel _player(String id, String name) => PlayerModel(
      id: id,
      name: name,
      createdAt: DateTime(2026, 1, 1),
    );

Map<String, dynamic> _match({
  required String id,
  required DateTime date,
  List<String> red = const [],
  List<String> white = const [],
  String? gkRed,
  String? gkWhite,
  int scoreRed = 0,
  int scoreWhite = 0,
  List<Map<String, dynamic>> events = const [],
}) {
  return {
    'id': id,
    'date': date.toIso8601String(),
    'scoreRed': scoreRed,
    'scoreWhite': scoreWhite,
    'events': events,
    'players': {
      'red': red.map((id) => {'id': id, 'name': id}).toList(),
      'white': white.map((id) => {'id': id, 'name': id}).toList(),
      'gk_red': gkRed != null ? {'id': gkRed, 'name': gkRed} : null,
      'gk_white': gkWhite != null ? {'id': gkWhite, 'name': gkWhite} : null,
    },
  };
}

Map<String, dynamic> _goal(String playerId, {String? assistId}) => {
      'type': 'goal',
      'player': playerId,
      'playerId': playerId,
      'assist': assistId ?? '',
      'assistId': assistId ?? '',
    };

void main() {
  final players = [
    _player('p1', 'Enzo'),
    _player('p2', 'Gabriel'),
    _player('gk1', 'Paredão'),
  ];

  final season = SeasonModel(
    id: 's2026',
    groupId: 'g1',
    name: 'Temporada 2026',
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2026, 12, 31),
    isActive: true,
  );

  test('histórico vazio retorna lista vazia de marcos', () {
    final updates = computeGroupMilestones(
      allHistory: [],
      sessions: [],
      players: players,
      currentSeason: season,
    );
    expect(updates, isEmpty);
  });

  test('detecta marco de 10 jogos no total e na temporada', () {
    final matches = List.generate(10, (i) {
      return _match(
        id: 'm_$i',
        date: DateTime(2026, 3, 1 + i),
        red: ['p1'],
        white: ['p2'],
        scoreRed: 1,
        scoreWhite: 0,
      );
    });

    final updates = computeGroupMilestones(
      allHistory: matches,
      sessions: [],
      players: players,
      currentSeason: season,
    );

    // Na 10ª partida, Enzo deve alcançar 10 jogos no total e 10 jogos na temporada
    final enzoUpdates = updates.where((u) => u.playerId == 'p1').toList();
    expect(
      enzoUpdates.any((u) => u.type == MilestoneType.gamesTotal && u.value == 10),
      isTrue,
    );
    expect(
      enzoUpdates.any((u) => u.type == MilestoneType.gamesSeason && u.value == 10),
      isTrue,
    );
    expect(enzoUpdates.first.playerName, 'Enzo');
    expect(enzoUpdates.first.title, contains('10 jogos'));
  });

  test('detecta marco de 10 gols e hat-trick na partida', () {
    // 3 partidas anteriores com 3 gols cada (total 9 gols)
    final matches = [
      _match(
        id: 'm_1',
        date: DateTime(2026, 2, 1),
        red: ['p2'],
        scoreRed: 3,
        events: [_goal('p2'), _goal('p2'), _goal('p2')],
      ),
      _match(
        id: 'm_2',
        date: DateTime(2026, 2, 2),
        red: ['p2'],
        scoreRed: 3,
        events: [_goal('p2'), _goal('p2'), _goal('p2')],
      ),
      _match(
        id: 'm_3',
        date: DateTime(2026, 2, 3),
        red: ['p2'],
        scoreRed: 3,
        events: [_goal('p2'), _goal('p2'), _goal('p2')],
      ),
      // 4ª partida: Gabriel faz mais 3 gols (total 12 gols - cruza marca de 10 gols)
      _match(
        id: 'm_4',
        date: DateTime(2026, 2, 4),
        red: ['p2'],
        scoreRed: 3,
        events: [_goal('p2'), _goal('p2'), _goal('p2')],
      ),
    ];

    final updates = computeGroupMilestones(
      allHistory: matches,
      sessions: [],
      players: players,
      currentSeason: season,
    );

    // Deve conter hat-trick
    final hatTricks = updates.where((u) => u.type == MilestoneType.hatTrick).toList();
    expect(hatTricks.isNotEmpty, isTrue);
    expect(hatTricks.first.title, contains('hat-trick'));

    // Deve conter marco de 10 gols
    final goalMilestones = updates.where((u) => u.type == MilestoneType.goalsTotal).toList();
    expect(goalMilestones.isNotEmpty, isTrue);
    expect(goalMilestones.first.value, 10);
    expect(goalMilestones.first.title, contains('Gabriel alcançou 10 gols no total'));
  });

  test('ordena do mais recente para o menos recente', () {
    final matches = [
      _match(
        id: 'm_old',
        date: DateTime(2026, 1, 10),
        red: ['p1'],
        scoreRed: 3,
        events: [_goal('p1'), _goal('p1'), _goal('p1')],
      ),
      _match(
        id: 'm_new',
        date: DateTime(2026, 5, 20),
        red: ['p2'],
        scoreRed: 3,
        events: [_goal('p2'), _goal('p2'), _goal('p2')],
      ),
    ];

    final updates = computeGroupMilestones(
      allHistory: matches,
      sessions: [],
      players: players,
      currentSeason: season,
    );

    expect(updates.length, 2);
    // Mais recente primeiro
    expect(updates[0].date.isAfter(updates[1].date), isTrue);
    expect(updates[0].playerId, 'p2');
    expect(updates[1].playerId, 'p1');
  });

  test('filtra atualizações exclusivas do perfil logado', () {
    final matches = [
      _match(
        id: 'm_1',
        date: DateTime(2026, 4, 1),
        red: ['p1'],
        scoreRed: 3,
        events: [_goal('p1'), _goal('p1'), _goal('p1')],
      ),
      _match(
        id: 'm_2',
        date: DateTime(2026, 4, 2),
        red: ['p2'],
        scoreRed: 3,
        events: [_goal('p2'), _goal('p2'), _goal('p2')],
      ),
    ];

    final allUpdates = computeGroupMilestones(
      allHistory: matches,
      sessions: [],
      players: players,
      currentSeason: season,
    );

    final enzoNotifications = allUpdates.where((u) => u.playerId == 'p1').toList();
    final gabrielNotifications = allUpdates.where((u) => u.playerId == 'p2').toList();

    expect(enzoNotifications.length, 1);
    expect(enzoNotifications.first.playerName, 'Enzo');
    expect(gabrielNotifications.length, 1);
    expect(gabrielNotifications.first.playerName, 'Gabriel');
  });

  test('detecta clean sheet de goleiro', () {
    final matches = List.generate(5, (i) {
      return _match(
        id: 'm_cs_$i',
        date: DateTime(2026, 6, 1 + i),
        red: ['p1'],
        white: ['p2'],
        gkRed: 'gk1',
        scoreRed: 2,
        scoreWhite: 0, // Goleiro gk1 não sofreu gols
      );
    });

    final updates = computeGroupMilestones(
      allHistory: matches,
      sessions: [],
      players: players,
      currentSeason: season,
    );

    final csUpdates = updates.where((u) => u.type == MilestoneType.cleanSheet).toList();
    expect(csUpdates.isNotEmpty, isTrue);
    expect(csUpdates.first.value, 5);
    expect(csUpdates.first.title, contains('Paredão alcançou 5 clean sheets'));
  });
}
