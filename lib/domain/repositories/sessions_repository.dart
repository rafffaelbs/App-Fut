import '../../models/session_model.dart';

abstract class SessionsRepository {
  Future<SessionModel?> getCachedSession(String sessionId);

  Future<SessionModel?> getSessionById(String sessionId);

  Future<List<SessionModel>> getSessionsByGroup(String groupId);

  Future<SessionModel> createSession(SessionModel session);

  Future<SessionModel> updateSession(SessionModel session);

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
  });

  Future<void> deleteSession(String sessionId);

  Future<Map<String, dynamic>?> getRuntimeState(String sessionId);
}
