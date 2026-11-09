import 'package:collection/collection.dart';
import '../../../domain/repositories/sessions_repository.dart';
import '../../../models/session_model.dart';
import 'snapshot_source.dart';

class TokenSessionsRepository implements SessionsRepository {
  final SnapshotSource _source;

  TokenSessionsRepository(this._source);

  @override
  Future<List<SessionModel>> getSessionsByGroup(String groupId) async {
    final list = _source.sessions;
    final sessions = list
        .whereType<Map>()
        .map((m) => SessionModel.fromMap(Map<String, dynamic>.from(m)))
        .where((s) => s.groupId.isEmpty || s.groupId == groupId)
        .toList();

    sessions.sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
    return sessions;
  }

  @override
  Future<SessionModel?> getSessionById(String sessionId) async {
    final list = _source.sessions;
    final raw = list.whereType<Map>().firstWhereOrNull(
          (m) => m['id']?.toString() == sessionId,
        );
    if (raw == null) return null;
    return SessionModel.fromMap(Map<String, dynamic>.from(raw));
  }

  @override
  Future<SessionModel?> getCachedSession(String sessionId) {
    return getSessionById(sessionId);
  }

  @override
  Future<Map<String, dynamic>?> getRuntimeState(String sessionId) async {
    final list = _source.sessions;
    final raw = list.whereType<Map>().firstWhereOrNull(
          (m) => m['id']?.toString() == sessionId,
        );
    if (raw == null) return null;
    return {
      'seconds_played': raw['seconds_played'] ?? 0,
      'is_running': raw['is_running'] ?? false,
      'score_red': raw['score_red'] ?? 0,
      'score_white': raw['score_white'] ?? 0,
      'red_streak': raw['red_streak'] ?? 0,
      'white_streak': raw['white_streak'] ?? 0,
      'is_overtime': raw['is_overtime'] ?? false,
      'started_at': raw['started_at'],
    };
  }

  @override
  Future<SessionModel> createSession(SessionModel session) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<SessionModel> updateSession(SessionModel session) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<void> updateRuntimeState(
    String sessionId, {
    bool? isRunning,
    int? secondsPlayed,
    int? scoreRed,
    int? scoreWhite,
    int? redStreak,
    int? whiteStreak,
    bool? isOvertime,
    DateTime? startedAt,
    String? status,
  }) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<void> deleteSession(String sessionId) {
    throw UnsupportedError('Site somente leitura');
  }
}
