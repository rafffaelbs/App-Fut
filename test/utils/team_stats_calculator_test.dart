import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/models/match_model.dart';
import 'package:app_do_fut/models/match_lineup_model.dart';
import 'package:app_do_fut/models/match_event_model.dart';
import 'package:app_do_fut/utils/team_stats_calculator.dart';

void main() {
  group('TeamStatsCalculator tests', () {
    final match1 = MatchModel(
      id: 'm1',
      sessionId: 's1',
      teamAScore: 3,
      teamBScore: 1,
      lineups: [
        const MatchLineupModel(matchId: 'm1', playerId: 'p1', team: 'red'),
        const MatchLineupModel(matchId: 'm1', playerId: 'p2', team: 'red'),
        const MatchLineupModel(matchId: 'm1', playerId: 'p3', team: 'red'),
        const MatchLineupModel(matchId: 'm1', playerId: 'p4', team: 'white'),
        const MatchLineupModel(matchId: 'm1', playerId: 'p5', team: 'white'),
      ],
      events: [
        const MatchEventModel(matchId: 'm1', playerId: 'p1', eventType: 'goal'),
        const MatchEventModel(matchId: 'm1', playerId: 'p1', eventType: 'goal'),
        const MatchEventModel(matchId: 'm1', playerId: 'p2', eventType: 'goal'),
        const MatchEventModel(matchId: 'm1', playerId: 'p4', eventType: 'goal'),
      ],
    );

    final match2 = MatchModel(
      id: 'm2',
      sessionId: 's1',
      teamAScore: 2,
      teamBScore: 2,
      lineups: [
        const MatchLineupModel(matchId: 'm2', playerId: 'p1', team: 'red'),
        const MatchLineupModel(matchId: 'm2', playerId: 'p2', team: 'red'),
        const MatchLineupModel(matchId: 'm2', playerId: 'p6', team: 'red'),
        const MatchLineupModel(matchId: 'm2', playerId: 'p3', team: 'white'),
        const MatchLineupModel(matchId: 'm2', playerId: 'p4', team: 'white'),
      ],
      events: [
        const MatchEventModel(matchId: 'm2', playerId: 'p1', eventType: 'goal'),
        const MatchEventModel(matchId: 'm2', playerId: 'p2', eventType: 'goal'),
        const MatchEventModel(matchId: 'm2', playerId: 'p3', eventType: 'goal'),
        const MatchEventModel(matchId: 'm2', playerId: 'p4', eventType: 'goal'),
      ],
    );

    final match3 = MatchModel(
      id: 'm3',
      sessionId: 's1',
      teamAScore: 0,
      teamBScore: 2,
      lineups: [
        const MatchLineupModel(matchId: 'm3', playerId: 'p4', team: 'red'),
        const MatchLineupModel(matchId: 'm3', playerId: 'p5', team: 'red'),
        const MatchLineupModel(matchId: 'm3', playerId: 'p1', team: 'white'),
        const MatchLineupModel(matchId: 'm3', playerId: 'p2', team: 'white'),
        const MatchLineupModel(matchId: 'm3', playerId: 'p3', team: 'white'),
      ],
      events: [
        const MatchEventModel(matchId: 'm3', playerId: 'p1', eventType: 'goal'),
        const MatchEventModel(matchId: 'm3', playerId: 'p3', eventType: 'goal'),
      ],
    );

    test('evaluateCustomTeam with trio (p1, p2, p3)', () {
      final matches = [match1, match2, match3];
      // match1: p1, p2, p3 were on red (won 3-1)
      // match2: p1, p2 on red, but p3 on white -> did NOT play together
      // match3: p1, p2, p3 were on white (won 2-0)
      final stats = TeamStatsCalculator.evaluateCustomTeam(['p1', 'p2', 'p3'], matches);

      expect(stats.matches, equals(2));
      expect(stats.wins, equals(2));
      expect(stats.draws, equals(0));
      expect(stats.losses, equals(0));
      expect(stats.winRate, equals(100.0));
      expect(stats.goalsFor, equals(5)); // 3 in m1 + 2 in m3
      expect(stats.goalsAgainst, equals(1)); // 1 in m1 + 0 in m3
      expect(stats.cleanSheets, equals(1)); // m3
      expect(stats.goalDiff, equals(4));
      expect(stats.topScorerId, equals('p1'));
      expect(stats.topScorerGoals, equals(3)); // 2 in m1 + 1 in m3
    });

    test('evaluateCustomTeam when players never played together', () {
      final matches = [match1, match2, match3];
      // p5 and p6 never played on the same team
      final stats = TeamStatsCalculator.evaluateCustomTeam(['p5', 'p6'], matches);

      expect(stats.matches, equals(0));
      expect(stats.wins, equals(0));
      expect(stats.winRate, equals(0.0));
    });

    test('computeBestSessionTeam finds the team with most wins', () {
      final matches = [match1, match2, match3];
      final best = TeamStatsCalculator.computeBestSessionTeam(matches);

      expect(best, isNotNull);
      // [p1, p2, p3] played together in m1 and m3 and won both (2 wins, 0 losses)
      expect(best!.wins, equals(2));
      expect(best.playerIds, containsAll(['p1', 'p2', 'p3']));
    });

    test('computeTopRivalries computes head-to-head stats correctly', () {
      final matches = [match1, match2, match3];
      // p1 vs p4:
      // m1: p1 on red (won 3-1) vs p4 on white -> p1 win
      // m2: p1 on red (2-2) vs p4 on white -> draw
      // m3: p1 on white (won 2-0) vs p4 on red -> p1 win
      final rivalries = TeamStatsCalculator.computeTopRivalries(matches, minMatches: 1);
      final p1vsp4 = rivalries.firstWhere(
        (r) => (r.player1Id == 'p1' && r.player2Id == 'p4') ||
               (r.player1Id == 'p4' && r.player2Id == 'p1'),
      );

      expect(p1vsp4.matchesAgainst, equals(3));
      expect(p1vsp4.draws, equals(1));
      if (p1vsp4.player1Id == 'p1') {
        expect(p1vsp4.p1Wins, equals(2));
        expect(p1vsp4.p2Wins, equals(0));
      } else {
        expect(p1vsp4.p2Wins, equals(2));
        expect(p1vsp4.p1Wins, equals(0));
      }
    });
  });
}
