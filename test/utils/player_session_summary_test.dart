import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/utils/player_session_summary.dart';
import 'package:app_do_fut/utils/stats_calculator.dart';

Map<String, dynamic> _match({
  required String session,
  required String date,
  required int red,
  required int white,
  List<String> redIds = const [],
  List<String> whiteIds = const [],
  String? gkRed,
  String? gkWhite,
  List<Map<String, dynamic>> events = const [],
  bool? exactSeason,
}) {
  Map<String, dynamic> p(String id) => {'id': id, 'name': id};
  return {
    'sessionId': session,
    'session_date': date,
    'scoreRed': red,
    'scoreWhite': white,
    'events': events,
    'players': {
      'red': redIds.map(p).toList(),
      'white': whiteIds.map(p).toList(),
      'gk_red': gkRed == null ? null : p(gkRed),
      'gk_white': gkWhite == null ? null : p(gkWhite),
    },
    if (exactSeason != null) 'isExactCurrentSeason': exactSeason,
  };
}

Map<String, dynamic> _goal(String scorer, [String assist = '']) => {
      'type': 'goal',
      'player': scorer,
      'playerId': scorer,
      'assist': assist,
      'assistId': assist,
    };

List<dynamic> _history() => [
      // Pelada s1 (10/10): ana ganha 2x1 (1 gol), empata 1x1 (1 assist).
      _match(
        session: 's1', date: '2026-10-10T20:00:00',
        red: 2, white: 1, redIds: ['ana', 'bia'], whiteIds: ['caio'],
        events: [_goal('ana', 'bia'), _goal('bia'), _goal('caio')],
      ),
      _match(
        session: 's1', date: '2026-10-10T20:10:00',
        red: 1, white: 1, redIds: ['bia'], whiteIds: ['ana'],
        events: [_goal('bia'), _goal('caio', 'ana')],
      ),
      // Pelada s2 (17/10): ana perde 0x3 como goleira (gol contra não conta).
      _match(
        session: 's2', date: '2026-10-17T20:00:00',
        red: 0, white: 3, redIds: ['bia'], whiteIds: ['caio'], gkRed: 'ana',
        events: [
          _goal('caio'), _goal('caio'),
          {'type': 'own_goal', 'player': 'ana', 'playerId': 'ana'},
        ],
      ),
      // Pelada s3 (24/10): ana NÃO joga.
      _match(
        session: 's3', date: '2026-10-24T20:00:00',
        red: 1, white: 0, redIds: ['bia'], whiteIds: ['caio'],
        events: [_goal('bia')],
      ),
      // Pelada s4 (31/10): ana joga e faz hat-trick, vence 3x0.
      _match(
        session: 's4', date: '2026-10-31T20:00:00',
        red: 3, white: 0, redIds: ['ana'], whiteIds: ['caio'],
        events: [_goal('ana'), _goal('ana'), _goal('ana', 'bia')],
      ),
    ];

void main() {
  group('summarizePlayerSessions', () {
    test('agrupa por pelada, soma G/A e V/E/D e ordena da mais recente', () {
      final r = summarizePlayerSessions(_history(), 'ana');
      expect(r.map((s) => s.sessionId), ['s4', 's2', 's1']);

      final s1 = r[2];
      expect(s1.goals, 1);
      expect(s1.assists, 1);
      expect(s1.ga, 2);
      expect([s1.wins, s1.draws, s1.losses], [1, 1, 0]);
      expect(s1.date, DateTime.parse('2026-10-10T20:00:00')); // a mais antiga

      final s4 = r[0];
      expect(s4.goals, 3);
      expect(s4.assists, 0);
      expect([s4.wins, s4.draws, s4.losses], [1, 0, 0]);
    });

    test('goleiro conta como jogador comum; gol contra não entra em G/A', () {
      final s2 = summarizePlayerSessions(_history(), 'ana')
          .firstWhere((s) => s.sessionId == 's2');
      expect(s2.matches, 1);
      expect(s2.losses, 1);
      expect(s2.goals, 0);
      expect(s2.assists, 0);
    });

    test('partidas em que o jogador não jogou não contam', () {
      final r = summarizePlayerSessions(_history(), 'ana');
      expect(r.any((s) => s.sessionId == 's3'), isFalse);
    });

    test('jogador sem peladas (ou id vazio) devolve lista vazia', () {
      expect(summarizePlayerSessions(_history(), 'zeca'), isEmpty);
      expect(summarizePlayerSessions(_history(), ''), isEmpty);
      expect(summarizePlayerSessions(const [], 'ana'), isEmpty);
    });

    test('filtro de período (from/to inclusivos)', () {
      final r = summarizePlayerSessions(
        _history(),
        'ana',
        from: DateTime(2026, 10, 15),
        to: DateTime(2026, 10, 31, 23, 59, 59),
      );
      expect(r.map((s) => s.sessionId), ['s4', 's2']);

      final none = summarizePlayerSessions(
        _history(),
        'ana',
        from: DateTime(2026, 11, 1),
      );
      expect(none, isEmpty);
    });

    test('ignora partidas marcadas fora da temporada atual', () {
      final h = [
        ..._history(),
        _match(
          session: 's0', date: '2026-09-01T20:00:00',
          red: 5, white: 0, redIds: ['ana'], whiteIds: ['caio'],
          events: [_goal('ana')], exactSeason: false,
        ),
      ];
      expect(
        summarizePlayerSessions(h, 'ana').any((s) => s.sessionId == 's0'),
        isFalse,
      );
    });

    test('sem sessionId agrupa por dia', () {
      final h = [
        _match(session: '', date: '2026-10-01T20:00:00', red: 1, white: 0,
            redIds: ['ana'], whiteIds: ['caio'], events: [_goal('ana')]),
        _match(session: '', date: '2026-10-01T21:00:00', red: 0, white: 0,
            redIds: ['ana'], whiteIds: ['caio']),
        _match(session: '', date: '2026-10-02T20:00:00', red: 0, white: 1,
            redIds: ['ana'], whiteIds: ['caio']),
      ];
      final r = summarizePlayerSessions(h, 'ana');
      expect(r.length, 2);
      expect(r.first.date, DateTime.parse('2026-10-02T20:00:00'));
      expect(r.last.matches, 2);
    });
  });

  group('consistência com os totais da carta (calculateGlobalStats)', () {
    void expectSameTotals(List<dynamic> history, String id) {
      final list = summarizePlayerSessions(history, id);
      final totals = calculateGlobalStats(history)[id];
      int sum(int Function(PlayerSessionSummary) f) =>
          list.fold(0, (a, s) => a + f(s));

      expect(sum((s) => s.goals), totals?['goals'] ?? 0);
      expect(sum((s) => s.assists), totals?['assists'] ?? 0);
      expect(sum((s) => s.wins), totals?['wins'] ?? 0);
      expect(sum((s) => s.draws), totals?['draws'] ?? 0);
      expect(sum((s) => s.losses), totals?['losses'] ?? 0);
      expect(sum((s) => s.matches), totals?['games'] ?? 0);
    }

    test('histórico completo', () {
      for (final id in ['ana', 'bia', 'caio']) {
        expectSameTotals(_history(), id);
      }
    });

    test('mesmo recorte de período', () {
      final cut = _history()
          .where((m) =>
              DateTime.parse((m as Map)['session_date'] as String)
                  .isAfter(DateTime(2026, 10, 12)))
          .toList();
      for (final id in ['ana', 'bia', 'caio']) {
        expectSameTotals(cut, id);
      }
    });
  });
}
