import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/utils/stats_calculator.dart';

void main() {
  group('stats_calculator characterization tests', () {
    group('calculateGlobalStats', () {
      test('case 1: empty history returns empty map', () {
        final result = calculateGlobalStats([]);
        expect(result, isEmpty);
      });

      test('case 2: zero events (pure win/loss by score only)', () {
        final matches = [
          {
            'scoreRed': 2,
            'scoreWhite': 1,
            'events': <Map<String, dynamic>>[],
            'players': {
              'red': [
                {'id': 'r1', 'name': 'Red 1'},
              ],
              'white': [
                {'id': 'w1', 'name': 'White 1'},
              ],
              'gk_red': null,
              'gk_white': null,
            },
            'isExactCurrentSeason': true,
          }
        ];

        final stats = calculateGlobalStats(matches);
        expect(stats.containsKey('r1'), isTrue);
        expect(stats.containsKey('w1'), isTrue);

        final r1 = stats['r1']!;
        expect(r1['games'], equals(1));
        expect(r1['wins'], equals(1));
        expect(r1['draws'], equals(0));
        expect(r1['losses'], equals(0));
        expect(r1['goals'], equals(0));
        expect(r1['assists'], equals(0));
        expect(r1['ga'], equals(0));
        expect((r1['ratings'] as List<double>).length, equals(1));
        // Win with 2-1 (diff 1): base 7.0 + win 0.8 + teamGoalBonus 0.1 - conceded 1 * 0.1 + diff 0.1 = 7.9
        expect(r1['nota'], closeTo(7.3, 1e-4)); // Single game is anchored: (7.0 * 2/3) + (7.9 * 1/3) = 7.3

        final w1 = stats['w1']!;
        expect(w1['games'], equals(1));
        expect(w1['wins'], equals(0));
        expect(w1['draws'], equals(0));
        expect(w1['losses'], equals(1));
        expect(w1['goals'], equals(0));
        expect(w1['assists'], equals(0));
      });

      test('case 3: events processing (goals, assists, own goals, cards)', () {
        final matches = [
          {
            'scoreRed': 3,
            'scoreWhite': 1,
            'events': [
              {'type': 'goal', 'player': 'r1', 'assist': 'r2'},
              {'type': 'goal', 'player': 'r1', 'assist': ''},
              {'type': 'goal', 'player': 'r2', 'assist': 'r1'},
              {'type': 'yellow_card', 'player': 'r1'},
              {'type': 'red_card', 'player': 'w1'},
              {'type': 'goal', 'player': 'w1', 'assist': ''},
              {'type': 'own_goal', 'player': 'w2'},
            ],
            'players': {
              'red': [
                {'id': 'r1', 'name': 'Red 1'},
                {'id': 'r2', 'name': 'Red 2'},
              ],
              'white': [
                {'id': 'w1', 'name': 'White 1'},
                {'id': 'w2', 'name': 'White 2'},
              ],
            },
            'isExactCurrentSeason': true,
          }
        ];

        final stats = calculateGlobalStats(matches);
        final r1 = stats['r1']!;
        expect(r1['goals'], equals(2));
        expect(r1['assists'], equals(1));
        expect(r1['ga'], equals(3));
        expect(r1['yellow'], equals(1));
        expect(r1['red'], equals(0));

        final r2 = stats['r2']!;
        expect(r2['goals'], equals(1));
        expect(r2['assists'], equals(1));
        expect(r2['ga'], equals(2));

        final w1 = stats['w1']!;
        expect(w1['goals'], equals(1));
        expect(w1['red'], equals(1));

        final w2 = stats['w2']!;
        // own_goal is tracked in matchPlayerEvents under 'og', but not added to 'goals'
        expect(w2['goals'], equals(0));
      });

      test('case 4: multiple matches accumulation and draw result', () {
        final matches = [
          // Match 1: Red wins 1-0
          {
            'scoreRed': 1,
            'scoreWhite': 0,
            'events': [
              {'type': 'goal', 'player': 'p1', 'assist': ''},
            ],
            'players': {
              'red': [{'id': 'p1', 'name': 'Player 1'}],
              'white': [{'id': 'p2', 'name': 'Player 2'}],
            },
            'isExactCurrentSeason': true,
          },
          // Match 2: Draw 2-2 (p1 on white, p2 on red)
          {
            'scoreRed': 2,
            'scoreWhite': 2,
            'events': [
              {'type': 'goal', 'player': 'p1', 'assist': ''},
              {'type': 'goal', 'player': 'p2', 'assist': ''},
            ],
            'players': {
              'red': [{'id': 'p2', 'name': 'Player 2'}],
              'white': [{'id': 'p1', 'name': 'Player 1'}],
            },
            'isExactCurrentSeason': true,
          },
        ];

        final stats = calculateGlobalStats(matches);
        final p1 = stats['p1']!;
        expect(p1['games'], equals(2));
        expect(p1['wins'], equals(1));
        expect(p1['draws'], equals(1));
        expect(p1['losses'], equals(0));
        expect(p1['goals'], equals(2));
        expect((p1['ratings'] as List<double>).length, equals(2));

        final p2 = stats['p2']!;
        expect(p2['games'], equals(2));
        expect(p2['wins'], equals(0));
        expect(p2['draws'], equals(1));
        expect(p2['losses'], equals(1));
        expect(p2['goals'], equals(1));
      });

      test('case 5: goalkeepers (gk_red and gk_white) are processed', () {
        // NOTE: In current implementation (lines 321-322), gk_red and gk_white
        // are processed by `processPlayer`, which calls `calculateMatchRating`
        // instead of `calculateGkMatchRating`. Characterizing this behavior:
        final matches = [
          {
            'scoreRed': 1,
            'scoreWhite': 0,
            'events': <Map<String, dynamic>>[],
            'players': {
              'red': <Map<String, dynamic>>[],
              'white': <Map<String, dynamic>>[],
              'gk_red': {'id': 'gk1', 'name': 'Goleiro Red'},
              'gk_white': {'id': 'gk2', 'name': 'Goleiro White'},
            },
            'isExactCurrentSeason': true,
          }
        ];

        final stats = calculateGlobalStats(matches);
        expect(stats.containsKey('gk1'), isTrue);
        expect(stats.containsKey('gk2'), isTrue);

        final gk1 = stats['gk1']!;
        expect(gk1['games'], equals(1));
        expect(gk1['wins'], equals(1));

        final gk2 = stats['gk2']!;
        expect(gk2['games'], equals(1));
        expect(gk2['losses'], equals(1));
      });

      test('case 6: isExactCurrentSeason == false omits game count but still adds ratings', () {
        // NOTE: Lines 293-311 check `isExactCurrentSeason` before incrementing games/wins/goals,
        // BUT ratings are added unconditionally outside the if block!
        final matches = [
          {
            'scoreRed': 2,
            'scoreWhite': 0,
            'events': [
              {'type': 'goal', 'player': 'p1'},
            ],
            'players': {
              'red': [{'id': 'p1', 'name': 'P1'}],
              'white': [{'id': 'p2', 'name': 'P2'}],
            },
            'isExactCurrentSeason': false,
          }
        ];

        final stats = calculateGlobalStats(matches);
        final p1 = stats['p1']!;
        expect(p1['games'], equals(0)); // NOT incremented
        expect(p1['wins'], equals(0));
        expect(p1['goals'], equals(0));
        expect((p1['ratings'] as List<double>).length, equals(1)); // STILL added
        expect((p1['ratings'] as List<double>).first, closeTo(10.0, 1e-4));
        expect(p1['nota'], closeTo(8.0, 1e-4));

        final p2 = stats['p2']!;
        expect(p2['games'], equals(0));
        expect((p2['ratings'] as List<double>).length, equals(1));
        expect((p2['ratings'] as List<double>).first, closeTo(6.1, 1e-4));
        expect(p2['nota'], closeTo(6.7, 1e-4));
      });
    });
  });
}
