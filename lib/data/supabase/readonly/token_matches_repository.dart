import '../../../domain/repositories/matches_repository.dart';
import '../../../models/match_event_model.dart';
import '../../../models/match_model.dart';
import 'snapshot_source.dart';

class TokenMatchesRepository implements MatchesRepository {
  final SnapshotSource _source;

  TokenMatchesRepository(this._source);

  List<MatchModel> _buildMatches(bool Function(Map matchMap) filter) {
    final Map<String, Map<String, dynamic>> playersById = {
      for (final p in _source.players.whereType<Map>())
        if (p['id'] != null) p['id'].toString(): Map<String, dynamic>.from(p),
    };

    final Map<String, List<Map<String, dynamic>>> lineupsByMatch = {};
    for (final raw in _source.lineups.whereType<Map>()) {
      final mId = raw['match_id']?.toString();
      if (mId == null) continue;
      final map = Map<String, dynamic>.from(raw);
      if (map['players'] == null && map['jogadores'] == null) {
        final pId = map['player_id']?.toString() ?? map['jogador_id']?.toString();
        if (pId != null && playersById.containsKey(pId)) {
          map['players'] = playersById[pId];
        }
      }
      lineupsByMatch.putIfAbsent(mId, () => []).add(map);
    }

    final Map<String, List<Map<String, dynamic>>> eventsByMatch = {};
    for (final raw in _source.events.whereType<Map>()) {
      final mId = raw['match_id']?.toString();
      if (mId == null) continue;
      final map = Map<String, dynamic>.from(raw);
      if (map['players'] == null && map['player'] == null && map['jogador'] == null) {
        final pId = map['player_id']?.toString() ?? map['jogador_id']?.toString();
        if (pId != null && playersById.containsKey(pId)) {
          map['players'] = playersById[pId];
        }
      }
      if (map['assist_player'] == null && map['assist_jogador'] == null) {
        final aId =
            map['assist_player_id']?.toString() ?? map['assist_jogador_id']?.toString();
        if (aId != null && playersById.containsKey(aId)) {
          map['assist_player'] = playersById[aId];
        }
      }
      eventsByMatch.putIfAbsent(mId, () => []).add(map);
    }

    final List<MatchModel> result = [];
    for (final raw in _source.matches.whereType<Map>()) {
      if (!filter(raw)) continue;
      final mId = raw['id']?.toString() ?? '';
      final matchMap = Map<String, dynamic>.from(raw);

      if (matchMap['match_lineups'] == null && matchMap['escalacao_partida'] == null) {
        matchMap['match_lineups'] = lineupsByMatch[mId] ?? const [];
      }
      if (matchMap['match_events'] == null && matchMap['eventos_partida'] == null) {
        matchMap['match_events'] = eventsByMatch[mId] ?? const [];
      }

      result.add(MatchModel.fromMap(matchMap));
    }

    result.sort((a, b) => (b.startTime ?? b.timestamp).compareTo(a.startTime ?? a.timestamp));
    return result;
  }

  @override
  Future<List<MatchModel>> getMatchesBySession(String sessionId) async {
    return _buildMatches((m) => m['session_id']?.toString() == sessionId);
  }

  @override
  Future<List<MatchModel>> getMatchesByGroup(String groupId) async {
    return _buildMatches((m) {
      final gId = m['group_id']?.toString();
      return gId == null || gId.isEmpty || gId == groupId;
    });
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
