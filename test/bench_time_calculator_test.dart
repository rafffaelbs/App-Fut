import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/utils/bench_time_calculator.dart';
import 'package:app_do_fut/models/match_model.dart';
import 'package:app_do_fut/models/match_lineup_model.dart';

void main() {
  group('BenchTimeCalculator Tests', () {
    final baseTime = DateTime(2026, 10, 24, 10, 0); // 10:00

    test('FinishedMatchInfo extracts player IDs correctly from MatchModel', () {
      final match = MatchModel(
        id: 'm1',
        sessionId: 's1',
        startTime: baseTime,
        durationSeconds: 600, // 10 min -> ends at 10:10
        lineups: [
          MatchLineupModel(matchId: 'm1', playerId: 'p1', team: 'red'),
          MatchLineupModel(matchId: 'm1', playerId: 'p2', team: 'red'),
          MatchLineupModel(matchId: 'm1', playerId: 'p3', team: 'white'),
        ],
      );

      final info = FinishedMatchInfo.fromMatchModel(match);
      expect(info.id, equals('m1'));
      expect(info.endTime, equals(DateTime(2026, 10, 24, 10, 10)));
      expect(info.playerIds, containsAll(['p1', 'p2', 'p3']));
    });

    test('FinishedMatchInfo extracts player IDs from legacy map', () {
      final map = {
        'match_id': 'm2',
        'date': '2026-10-24T10:20:00.000',
        'players': {
          'red': [
            {'id': 'p1', 'name': 'Player 1'},
            {'name': 'Player 2'}, // fallback to name
          ],
          'white': [
            {'id': 'p3', 'name': 'Player 3'},
          ],
          'gk_red': {'id': 'gk1', 'name': 'Goleiro 1'},
          'gk_white': null,
        },
      };

      final info = FinishedMatchInfo.fromMap(map);
      expect(info.id, equals('m2'));
      expect(info.endTime, equals(DateTime(2026, 10, 24, 10, 20)));
      expect(info.playerIds, containsAll(['p1', 'Player 2', 'p3', 'gk1']));
    });

    test('Player who just finished playing: 0 games since, "Acabou de sair"', () {
      final match1 = FinishedMatchInfo(
        id: 'm1',
        endTime: baseTime.add(const Duration(minutes: 10)), // 10:10
        playerIds: {'p1', 'p2'},
      );

      final now = baseTime.add(const Duration(minutes: 10, seconds: 30)); // 10:10:30 (< 1 min)
      final stats = BenchTimeCalculator.calculate(
        playerId: 'p1',
        finishedMatches: [match1],
      );

      expect(stats.hasPlayed, isTrue);
      expect(stats.completedMatchesSinceLastPlayed, equals(0));
      expect(stats.waitingSince, equals(match1.endTime));

      final display = BenchTimeCalculator.formatDisplay(stats, now: now);
      expect(display, equals('Acabou de sair'));
    });

    test('Player who finished playing and 0 matches happened, but some minutes passed', () {
      final match1 = FinishedMatchInfo(
        id: 'm1',
        endTime: baseTime.add(const Duration(minutes: 10)), // 10:10
        playerIds: {'p1'},
      );

      final now = baseTime.add(const Duration(minutes: 15)); // 10:15 (5 min later)
      final stats = BenchTimeCalculator.calculate(
        playerId: 'p1',
        finishedMatches: [match1],
      );

      expect(stats.completedMatchesSinceLastPlayed, equals(0));
      final display = BenchTimeCalculator.formatDisplay(stats, now: now);
      expect(display, equals('No banco há 5 min · 0 jogos'));
    });

    test('Player who played match 1, missed match 2 and 3: 2 games on bench', () {
      final match1 = FinishedMatchInfo(
        id: 'm1',
        endTime: baseTime.add(const Duration(minutes: 10)), // 10:10 (p1 played)
        playerIds: {'p1', 'p2'},
      );
      final match2 = FinishedMatchInfo(
        id: 'm2',
        endTime: baseTime.add(const Duration(minutes: 20)), // 10:20 (p3, p4)
        playerIds: {'p3', 'p4'},
      );
      final match3 = FinishedMatchInfo(
        id: 'm3',
        endTime: baseTime.add(const Duration(minutes: 30)), // 10:30 (p2, p3)
        playerIds: {'p2', 'p3'},
      );

      // Now it is 10:38 (28 minutes since match 1 ended)
      final now = baseTime.add(const Duration(minutes: 38));

      // Test p1 (last played match 1)
      final statsP1 = BenchTimeCalculator.calculate(
        playerId: 'p1',
        finishedMatches: [match1, match2, match3],
      );
      expect(statsP1.hasPlayed, isTrue);
      expect(statsP1.completedMatchesSinceLastPlayed, equals(2));
      expect(statsP1.waitingSince, equals(match1.endTime));
      expect(BenchTimeCalculator.formatDisplay(statsP1, now: now), equals('No banco há 28 min · 2 jogos'));

      // Test p2 (played match 1 and match 3, so last was match 3)
      final statsP2 = BenchTimeCalculator.calculate(
        playerId: 'p2',
        finishedMatches: [match1, match2, match3],
      );
      expect(statsP2.hasPlayed, isTrue);
      expect(statsP2.completedMatchesSinceLastPlayed, equals(0));
      expect(statsP2.waitingSince, equals(match3.endTime));
      expect(BenchTimeCalculator.formatDisplay(statsP2, now: now), equals('No banco há 8 min · 0 jogos'));
    });

    test('Player who has never played any match in the session', () {
      final sessionStart = baseTime; // 10:00
      final match1 = FinishedMatchInfo(
        id: 'm1',
        endTime: baseTime.add(const Duration(minutes: 10)),
        playerIds: {'p1'},
      );
      final match2 = FinishedMatchInfo(
        id: 'm2',
        endTime: baseTime.add(const Duration(minutes: 20)),
        playerIds: {'p1'},
      );

      // Scenario A: No matches finished yet
      final statsZero = BenchTimeCalculator.calculate(
        playerId: 'pNew',
        finishedMatches: [],
        sessionStartTime: sessionStart,
      );
      expect(statsZero.hasPlayed, isFalse);
      expect(statsZero.completedMatchesSinceLastPlayed, equals(0));
      expect(BenchTimeCalculator.formatDisplay(statsZero, now: baseTime.add(const Duration(minutes: 5))), equals('Ainda não jogou'));

      // Scenario B: 2 matches finished, session start known (25 min waiting)
      final statsWithMatches = BenchTimeCalculator.calculate(
        playerId: 'pNew',
        finishedMatches: [match1, match2],
        sessionStartTime: sessionStart,
      );
      expect(statsWithMatches.hasPlayed, isFalse);
      expect(statsWithMatches.completedMatchesSinceLastPlayed, equals(2));
      final now = baseTime.add(const Duration(minutes: 25));
      expect(
        BenchTimeCalculator.formatDisplay(statsWithMatches, now: now),
        equals('No banco há 25 min · 2 jogos (estreia)'),
      );

      // Scenario C: 1 match finished, no session start timestamp available
      final statsNoTime = BenchTimeCalculator.calculate(
        playerId: 'pNew',
        finishedMatches: [match1],
        sessionStartTime: null,
      );
      expect(statsNoTime.hasPlayed, isFalse);
      expect(statsNoTime.completedMatchesSinceLastPlayed, equals(1));
      expect(BenchTimeCalculator.formatDisplay(statsNoTime, now: now), equals('Ainda não jogou · 1 jogo'));
    });

    test('Format duration handles minutes and hours properly', () {
      expect(BenchTimeCalculator.formatDuration(const Duration(seconds: 40)), equals('< 1 min'));
      expect(BenchTimeCalculator.formatDuration(const Duration(minutes: 18)), equals('18 min'));
      expect(BenchTimeCalculator.formatDuration(const Duration(minutes: 65)), equals('1h05'));
      expect(BenchTimeCalculator.formatDuration(const Duration(minutes: 120)), equals('2h00'));
    });
  });
}
