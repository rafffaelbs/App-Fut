import '../../models/match_event_model.dart';
import '../../models/match_model.dart';

abstract class MatchesRepository {
  Future<List<MatchModel>> getMatchesBySession(String sessionId);

  Future<List<MatchModel>> getMatchesByGroup(String groupId);

  Future<void> savePendingMatch({
    required String matchId,
    required Map<String, dynamic> match,
    required List<Map<String, dynamic>> lineups,
    required List<Map<String, dynamic>> events,
    bool isRetry = false,
  });

  Future<MatchModel> updatePartialMatch({
    required String matchId,
    required int teamAScore,
    required int teamBScore,
    required List<MatchEventModel> events,
  });

  Future<void> deleteMatch(String matchId);
}
