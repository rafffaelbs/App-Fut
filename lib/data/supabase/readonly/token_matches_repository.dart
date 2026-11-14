import '../../../domain/repositories/matches_repository.dart';
import '../../../models/match_event_model.dart';
import '../../../models/match_model.dart';
import 'snapshot_source.dart';

class TokenMatchesRepository implements MatchesRepository {
  final SnapshotSource _source;

  TokenMatchesRepository(this._source);

  @override
  Future<List<MatchModel>> getMatchesBySession(String sessionId) async {
    final list = _source.cachedMatches
        .where((m) => m.sessionId == sessionId)
        .toList();
    list.sort((a, b) => (b.startTime ?? b.timestamp).compareTo(a.startTime ?? a.timestamp));
    return list;
  }

  @override
  Future<List<MatchModel>> getMatchesByGroup(String groupId) async {
    final list = List<MatchModel>.from(_source.cachedMatches);
    list.sort((a, b) => (b.startTime ?? b.timestamp).compareTo(a.startTime ?? a.timestamp));
    return list;
  }

  @override
  Future<void> savePendingMatch({
    required String matchId,
    required Map<String, dynamic> match,
    required List<Map<String, dynamic>> lineups,
    required List<Map<String, dynamic>> events,
    bool isRetry = false,
  }) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<MatchModel> updatePartialMatch({
    required String matchId,
    required int teamAScore,
    required int teamBScore,
    required List<MatchEventModel> events,
  }) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<void> deleteMatch(String matchId) {
    throw UnsupportedError('Site somente leitura');
  }
}
