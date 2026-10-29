import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/utils/rating_calculator.dart';

void main() {
  group('rating_calculator characterization tests', () {
    group('calculateMatchRating', () {
      test('case 1: zero events, neutral draw (status 0, 0-0)', () {
        // Zero events in a 0-0 draw: conceded == 0 && status >= 0 triggers clean sheet bonus (+0.5)
        final rating = calculateMatchRating(
          status: 0,
          goals: 0,
          assists: 0,
          ownGoals: 0,
          teamGoals: 0,
          conceded: 0,
          yellow: 0,
          red: 0,
          teamWinStreak: 0,
        );
        expect(rating, closeTo(7.5, 1e-4));
      });

      test('case 2: win streak scaling (0, 2, 3+ wins)', () {
        // Status 1 (win 2-1): goals 1, win result (+0.8), goal (+1.5), goalDiff (+0.1), teamGoal (+0.1), conceded (-0.1)
        // With streak 0: streakBonus = 0 -> 9.4
        final ratingStreak0 = calculateMatchRating(
          status: 1,
          goals: 1,
          assists: 0,
          ownGoals: 0,
          teamGoals: 2,
          conceded: 1,
          yellow: 0,
          red: 0,
          teamWinStreak: 0,
        );

        // With streak 2: streakBonus = 0.2 -> 9.6
        final ratingStreak2 = calculateMatchRating(
          status: 1,
          goals: 1,
          assists: 0,
          ownGoals: 0,
          teamGoals: 2,
          conceded: 1,
          yellow: 0,
          red: 0,
          teamWinStreak: 2,
        );

        // With streak 3: streakBonus = 0.4 -> 9.8
        final ratingStreak3 = calculateMatchRating(
          status: 1,
          goals: 1,
          assists: 0,
          ownGoals: 0,
          teamGoals: 2,
          conceded: 1,
          yellow: 0,
          red: 0,
          teamWinStreak: 3,
        );

        expect(ratingStreak0, closeTo(9.4, 1e-4));
        expect(ratingStreak2, closeTo(9.6, 1e-4));
        expect(ratingStreak3, closeTo(9.8, 1e-4));
      });

      test('case 3: win streaks in moderate match to observe un-clamped delta', () {
        // To observe exact streak differences without hitting the 10.0 clamp:
        // status 1, teamGoals 2, conceded 1, yellow 1, player did 0 goals/assists
        final rStreak1 = calculateMatchRating(
          status: 1,
          goals: 0,
          assists: 0,
          ownGoals: 0,
          teamGoals: 2,
          conceded: 1,
          yellow: 1,
          red: 0,
          teamWinStreak: 1,
        );
        final rStreak2 = calculateMatchRating(
          status: 1,
          goals: 0,
          assists: 0,
          ownGoals: 0,
          teamGoals: 2,
          conceded: 1,
          yellow: 1,
          red: 0,
          teamWinStreak: 2,
        );
        final rStreak3 = calculateMatchRating(
          status: 1,
          goals: 0,
          assists: 0,
          ownGoals: 0,
          teamGoals: 2,
          conceded: 1,
          yellow: 1,
          red: 0,
          teamWinStreak: 3,
        );

        // Delta for streak 1: base(7.0) + win(0.8) + teamGoalBonus(0.1) - conceded(0.1) - yellow(0.5) + diff(0.1) = 7.4
        expect(rStreak1, closeTo(7.4, 1e-4));
        // Streak 2 adds +0.2 -> 7.6
        expect(rStreak2, closeTo(7.6, 1e-4));
        // Streak 3 adds +0.4 -> 7.8
        expect(rStreak3, closeTo(7.8, 1e-4));
      });

      test('case 4: upper boundary clamp at 10.0', () {
        final rating = calculateMatchRating(
          status: 1,
          goals: 6,
          assists: 4,
          ownGoals: 0,
          teamGoals: 8,
          conceded: 0,
          yellow: 0,
          red: 0,
          teamWinStreak: 5,
          scoredComebackGoal: true,
          scoredClutchGoal: true,
        );
        expect(rating, equals(10.0));
      });

      test('case 5: lower boundary clamp at 0.0', () {
        final rating = calculateMatchRating(
          status: -1,
          goals: 0,
          assists: 0,
          ownGoals: 4,
          teamGoals: 0,
          conceded: 12,
          yellow: 2,
          red: 1,
          teamWinStreak: 0,
        );
        expect(rating, equals(0.0));
      });

      test('case 6: underdog vs favorite pressure multipliers', () {
        // Underdog winning (diff < 0): team 5.0 vs opponent 8.0 (diff = -3.0)
        // factor = (3.0 * 0.15).clamp(0.0, 0.5) = 0.45
        // positiveMultiplier = 1.45, negativeMultiplier = 1.0 / 1.45 (~0.6896)
        final underdogWin = calculateMatchRating(
          status: 1,
          goals: 0,
          assists: 0,
          ownGoals: 0,
          teamGoals: 1,
          conceded: 1,
          yellow: 0,
          red: 0,
          teamWinStreak: 0,
          teamAvgRating: 5.0,
          opponentAvgRating: 8.0,
        );

        // Favorite winning (diff > 0): team 8.0 vs opponent 5.0 (diff = +3.0)
        // factor = 0.45, positiveMultiplier = 1 / 1.45 (~0.6896), negativeMultiplier = 1.45
        final favoriteWin = calculateMatchRating(
          status: 1,
          goals: 0,
          assists: 0,
          ownGoals: 0,
          teamGoals: 1,
          conceded: 1,
          yellow: 0,
          red: 0,
          teamWinStreak: 0,
          teamAvgRating: 8.0,
          opponentAvgRating: 5.0,
        );

        expect(underdogWin, closeTo(8.2360, 1e-4));
        expect(favoriteWin, closeTo(7.4757, 1e-4));
      });

      test('case 7: comeback and clutch special goals bonus', () {
        // Using a 1-1 draw scenario so base is around 7.0 and doesn't hit 10.0 clamp
        final base = calculateMatchRating(
          status: 0,
          goals: 0,
          assists: 0,
          ownGoals: 0,
          teamGoals: 1,
          conceded: 1,
          yellow: 0,
          red: 0,
          teamWinStreak: 0,
          scoredComebackGoal: false,
          scoredClutchGoal: false,
        );

        final withComeback = calculateMatchRating(
          status: 0,
          goals: 0,
          assists: 0,
          ownGoals: 0,
          teamGoals: 1,
          conceded: 1,
          yellow: 0,
          red: 0,
          teamWinStreak: 0,
          scoredComebackGoal: true,
          scoredClutchGoal: false,
        );

        final withBoth = calculateMatchRating(
          status: 0,
          goals: 0,
          assists: 0,
          ownGoals: 0,
          teamGoals: 1,
          conceded: 1,
          yellow: 0,
          red: 0,
          teamWinStreak: 0,
          scoredComebackGoal: true,
          scoredClutchGoal: true,
        );

        expect(base, closeTo(7.0, 1e-4));
        expect(withComeback, closeTo(7.4, 1e-4));
        expect(withBoth, closeTo(8.2, 1e-4));
        expect(withComeback - base, closeTo(0.4, 1e-4)); // kBonusComebackGoal = 0.4
        expect(withBoth - withComeback, closeTo(0.8, 1e-4)); // kBonusClutchGoal = 0.8
      });

      test('case 8: diminishing decay with 2 and 3 goals in neutral draw', () {
        // Neutral draw (status 0) without bonuses that exceed the 10.0 limit.
        // In a 10-10 draw (teamGoals: 10, conceded: 10), neither 2 goals nor 3 goals
        // (even with hat-trick bonus +0.8) hits the 10.0 clamp, so both ratings
        // stay strictly below 10.0 and depend directly on kDiminishingDecay:
        final r2Goals = calculateMatchRating(
          status: 0,
          goals: 2,
          assists: 0,
          ownGoals: 0,
          teamGoals: 10,
          conceded: 10,
          yellow: 0,
          red: 0,
          teamWinStreak: 0,
        );

        final r3Goals = calculateMatchRating(
          status: 0,
          goals: 3,
          assists: 0,
          ownGoals: 0,
          teamGoals: 10,
          conceded: 10,
          yellow: 0,
          red: 0,
          teamWinStreak: 0,
        );

        // Also test 2 goals in a standard 2-2 draw:
        final r2GoalsIn22 = calculateMatchRating(
          status: 0,
          goals: 2,
          assists: 0,
          ownGoals: 0,
          teamGoals: 2,
          conceded: 2,
          yellow: 0,
          red: 0,
          teamWinStreak: 0,
        );

        expect(r2Goals, closeTo(8.5, 1e-4));
        expect(r3Goals, closeTo(9.84, 1e-4));
        expect(r2GoalsIn22, closeTo(9.3, 1e-4));
      });

      test('case 9: diminishing decay with 2 and 3 assists in neutral draw', () {
        // Neutral draw (status 0) without bonuses that exceed the 10.0 limit.
        // In a 3-3 draw (teamGoals: 3, conceded: 3), neither 2 assists nor 3 assists
        // (even with playmaker bonus +0.6) hits the 10.0 clamp:
        final r2Assists = calculateMatchRating(
          status: 0,
          goals: 0,
          assists: 2,
          ownGoals: 0,
          teamGoals: 3,
          conceded: 3,
          yellow: 0,
          red: 0,
          teamWinStreak: 0,
        );

        final r3Assists = calculateMatchRating(
          status: 0,
          goals: 0,
          assists: 3,
          ownGoals: 0,
          teamGoals: 3,
          conceded: 3,
          yellow: 0,
          red: 0,
          teamWinStreak: 0,
        );

        expect(r2Assists, closeTo(8.4, 1e-4));
        expect(r3Assists, closeTo(9.36, 1e-4));
      });
    });

    group('calculateGkMatchRating', () {
      test('case 1: clean sheet win/draw with zero conceded (bonus +0.8)', () {
        final rating = calculateGkMatchRating(
          status: 1,
          goals: 0,
          assists: 0,
          conceded: 0,
          yellow: 0,
          red: 0,
          teamWinStreak: 0,
        );
        // Base 7.0 + cleanSheet 0.8 = 7.8
        expect(rating, closeTo(7.8, 1e-4));
      });

      test('case 2: goalkeeper conceded goals and discipline cards', () {
        final rating = calculateGkMatchRating(
          status: -1,
          goals: 0,
          assists: 0,
          conceded: 3, // -0.3
          yellow: 1,   // -0.5
          red: 0,
          teamWinStreak: 0,
        );
        // Base 7.0 - 0.3 - 0.5 = 6.2
        expect(rating, closeTo(6.2, 1e-4));
      });

      test('case 3: goalkeeper with attacking contributions (goal + assist)', () {
        final rating = calculateGkMatchRating(
          status: 1,
          goals: 1,    // +1.5
          assists: 1,  // +1.0
          conceded: 1, // -0.1
          yellow: 0,
          red: 0,
          teamWinStreak: 0,
        );
        // Base 7.0 + 1.5 + 1.0 - 0.1 = 9.4
        expect(rating, closeTo(9.4, 1e-4));
      });

      test('case 4: goalkeeper upper clamp 10.0', () {
        final rating = calculateGkMatchRating(
          status: 1,
          goals: 3,
          assists: 2,
          conceded: 0,
          yellow: 0,
          red: 0,
          teamWinStreak: 0,
        );
        expect(rating, equals(10.0));
      });

      test('case 5: goalkeeper lower clamp 0.0', () {
        final rating = calculateGkMatchRating(
          status: -1,
          goals: 0,
          assists: 0,
          conceded: 50,
          yellow: 2,
          red: 1,
          teamWinStreak: 0,
        );
        expect(rating, equals(0.0));
      });

      test('case 6: goalkeeper under pressure multiplier (underdog vs favorite)', () {
        // Underdog GK conceding 2 goals
        final underdogGk = calculateGkMatchRating(
          status: -1,
          goals: 0,
          assists: 0,
          conceded: 2,
          yellow: 0,
          red: 0,
          teamWinStreak: 0,
          teamAvgRating: 5.0,
          opponentAvgRating: 8.0,
        );

        // Favorite GK conceding 2 goals
        final favoriteGk = calculateGkMatchRating(
          status: -1,
          goals: 0,
          assists: 0,
          conceded: 2,
          yellow: 0,
          red: 0,
          teamWinStreak: 0,
          teamAvgRating: 8.0,
          opponentAvgRating: 5.0,
        );

        // For underdog, negative multiplier is ~0.6896, penalty is smaller -> higher rating
        expect(underdogGk, closeTo(6.8620, 1e-4));
        // For favorite, negative multiplier is 1.45, penalty is larger -> lower rating
        expect(favoriteGk, closeTo(6.7100, 1e-4));
      });
    });

    group('calculateFinalRating', () {
      test('case 1: empty ratings list returns kRatingBase (7.0)', () {
        expect(calculateFinalRating(ratings: []), equals(7.0));
      });

      test('case 2: anchoring with 1 game (weight = 1/3)', () {
        // 1 game with 10.0: (7.0 * 2/3) + (10.0 * 1/3) = 14/3 + 10/3 = 8.0
        final rating = calculateFinalRating(ratings: [10.0], useEMA: true);
        expect(rating, closeTo(8.0, 1e-4));
      });

      test('case 3: anchoring with 2 games (weight = 2/3)', () {
        // 2 games with [8.0, 10.0]: recentAvg = 9.0
        // (7.0 * 1/3) + (9.0 * 2/3) = 7/3 + 18/3 = 25/3 = 8.3333...
        final rating = calculateFinalRating(ratings: [8.0, 10.0], useEMA: true);
        expect(rating, closeTo(8.3333, 1e-4));
      });

      test('case 4: 5 games (no anchor, length <= kFormWindowGames)', () {
        // Average of 6.0, 7.0, 8.0, 8.5, 9.5 = 39.0 / 5 = 7.8
        final rating = calculateFinalRating(
          ratings: [6.0, 7.0, 8.0, 8.5, 9.5],
          useEMA: true,
        );
        expect(rating, closeTo(7.8, 1e-4));
      });

      test('case 5: more than 12 games with useEMA true vs false', () {
        // 14 games: first 2 are 2.0, remaining 12 are 8.0
        final ratings = [2.0, 2.0, ...List.filled(12, 8.0)];

        // useEMA = true only takes the last 12 (all 8.0) -> 8.0
        final ratingEMA = calculateFinalRating(ratings: ratings, useEMA: true);
        expect(ratingEMA, closeTo(8.0, 1e-4));

        // useEMA = false takes all 14 -> (4 + 96) / 14 = 100 / 14 = 7.142857...
        final ratingSimple = calculateFinalRating(ratings: ratings, useEMA: false);
        expect(ratingSimple, closeTo(7.1428, 1e-4));
      });

      test('case 6: clamp limits (0.0 and 10.0)', () {
        expect(calculateFinalRating(ratings: [0.0, 0.0, 0.0]), equals(0.0));
        expect(calculateFinalRating(ratings: [10.0, 10.0, 10.0]), equals(10.0));
      });
    });

    group('findSpecialGoals', () {
      test('case 1: zero events', () {
        final ctx = findSpecialGoals([]);
        expect(ctx.comebackGoalIndex, equals(-1));
        expect(ctx.clutchGoalIndex, equals(-1));
      });

      test('case 2: comeback goal check with sequential 1-point goals', () {
        // NOTE: In current implementation (lines 385-395), condition
        // `beforeRed < beforeWhite && scoreRed > scoreWhite` is impossible with 1-point goals,
        // so comebackGoalIndex evaluates to -1. Characterizing this actual behavior:
        final events = [
          {'type': 'goal', 'team': 'Branco', 'time': '01:00', 'playerId': 'p1'}, // 0-1
          {'type': 'goal', 'team': 'Vermelho', 'time': '02:00', 'playerId': 'p2'}, // 1-1
          {'type': 'goal', 'team': 'Vermelho', 'time': '03:00', 'playerId': 'p3'}, // 2-1
        ];
        final ctx = findSpecialGoals(events);
        expect(ctx.comebackGoalIndex, equals(-1));
        expect(ctx.clutchGoalIndex, equals(-1)); // at 03:00 out of 8 min (480s), clutchStart = 240s (04:00)
      });

      test('case 3: clutch goal in final window', () {
        final events = [
          {'type': 'goal', 'team': 'Vermelho', 'time': '05:30', 'playerId': 'p1'}, // 1-0 at 330s >= 240s
        ];
        final ctx = findSpecialGoals(events);
        expect(ctx.clutchGoalIndex, equals(0));
      });

      test('case 4: clutch goal at end of game', () {
        final events = [
          {'type': 'goal', 'team': 'Vermelho', 'time': '01:00', 'playerId': 'r1'}, // 1-0
          {'type': 'goal', 'team': 'Branco', 'time': '02:00', 'playerId': 'w1'},   // 1-1
          {'type': 'goal', 'team': 'Branco', 'time': '06:00', 'playerId': 'w2'},   // 1-2
        ];
        final ctx = findSpecialGoals(events);
        expect(ctx.comebackGoalIndex, equals(-1)); // Characterizing current -1 behavior
        expect(ctx.clutchGoalIndex, equals(2));
      });

      test('case 5: own goal events followed by normal goals', () {
        final events = [
          {'type': 'goal', 'team': 'Branco', 'time': '01:00', 'playerId': 'w1'},     // 0-1
          {'type': 'own_goal', 'team': 'Vermelho', 'time': '02:00', 'playerId': 'r1'}, // 0-2 (scored for Branco)
          {'type': 'goal', 'team': 'Vermelho', 'time': '03:00', 'playerId': 'r2'},     // 1-2
          {'type': 'goal', 'team': 'Vermelho', 'time': '04:00', 'playerId': 'r3'},     // 2-2
          {'type': 'goal', 'team': 'Vermelho', 'time': '05:00', 'playerId': 'r4'},     // 3-2
        ];
        final ctx = findSpecialGoals(events);
        expect(ctx.comebackGoalIndex, equals(-1)); // Characterizing current -1 behavior
        expect(ctx.clutchGoalIndex, equals(4)); // at 05:00 (300s >= 240s), diffBefore was 0 <= 1
      });

      test('case 6: blowout at the end is not clutch', () {
        final events = [
          {'type': 'goal', 'team': 'Vermelho', 'time': '01:00', 'playerId': 'r1'}, // 1-0
          {'type': 'goal', 'team': 'Vermelho', 'time': '02:00', 'playerId': 'r2'}, // 2-0
          {'type': 'goal', 'team': 'Vermelho', 'time': '03:00', 'playerId': 'r3'}, // 3-0
          {'type': 'goal', 'team': 'Vermelho', 'time': '07:00', 'playerId': 'r4'}, // 4-0 (diffBefore was 3 > 1)
        ];
        final ctx = findSpecialGoals(events);
        expect(ctx.clutchGoalIndex, equals(-1));
      });
    });

    group('getRatingColor', () {
      test('case 1: rating >= 9.0 -> purpleAccent', () {
        expect(getRatingColor(9.0), equals(Colors.purpleAccent));
        expect(getRatingColor(10.0), equals(Colors.purpleAccent));
      });

      test('case 2: 8.0 <= rating < 9.0 -> green[700]', () {
        expect(getRatingColor(8.0), equals(Colors.green[700]!));
        expect(getRatingColor(8.9), equals(Colors.green[700]!));
      });

      test('case 3: 7.0 <= rating < 8.0 -> green', () {
        expect(getRatingColor(7.0), equals(Colors.green));
        expect(getRatingColor(7.9), equals(Colors.green));
      });

      test('case 4: 6.0 <= rating < 7.0 -> lightGreenAccent', () {
        expect(getRatingColor(6.0), equals(Colors.lightGreenAccent));
        expect(getRatingColor(6.9), equals(Colors.lightGreenAccent));
      });

      test('case 5: 5.0 <= rating < 6.0 -> yellow', () {
        expect(getRatingColor(5.0), equals(Colors.yellow));
        expect(getRatingColor(5.9), equals(Colors.yellow));
      });

      test('case 6: 4.0 <= rating < 5.0 -> orange', () {
        expect(getRatingColor(4.0), equals(Colors.orange));
        expect(getRatingColor(4.9), equals(Colors.orange));
      });

      test('case 7: rating < 4.0 -> red', () {
        expect(getRatingColor(3.9), equals(Colors.red));
        expect(getRatingColor(0.0), equals(Colors.red));
      });
    });

    group('getRatingLabel', () {
      test('case 1: games < 5 is always Estreante', () {
        expect(getRatingLabel(10.0, 0), equals('Estreante'));
        expect(getRatingLabel(9.5, 4), equals('Estreante'));
        expect(getRatingLabel(2.0, 4), equals('Estreante'));
      });

      test('case 2: rating >= 9.0 with games >= 5 -> BallonDor', () {
        expect(getRatingLabel(9.0, 5), equals('BallonDor'));
        expect(getRatingLabel(10.0, 10), equals('BallonDor'));
      });

      test('case 3: 8.0 <= rating < 9.0 with games >= 5 -> Elite', () {
        expect(getRatingLabel(8.0, 5), equals('Elite'));
        expect(getRatingLabel(8.9, 12), equals('Elite'));
      });

      test('case 4: 7.0 <= rating < 8.0 with games >= 5 -> Ótimo', () {
        expect(getRatingLabel(7.0, 5), equals('Ótimo'));
        expect(getRatingLabel(7.9, 20), equals('Ótimo'));
      });

      test('case 5: 6.0 <= rating < 7.0 with games >= 5 -> Bom', () {
        expect(getRatingLabel(6.0, 5), equals('Bom'));
        expect(getRatingLabel(6.9, 5), equals('Bom'));
      });

      test('case 6: 5.0 <= rating < 6.0 with games >= 5 -> Regular', () {
        expect(getRatingLabel(5.0, 5), equals('Regular'));
        expect(getRatingLabel(5.9, 7), equals('Regular'));
      });

      test('case 7: rating < 5.0 with games >= 5 -> Abaixo', () {
        expect(getRatingLabel(4.9, 5), equals('Abaixo'));
        expect(getRatingLabel(0.0, 8), equals('Abaixo'));
      });
    });
  });
}
