abstract class MatchHistoryStore {
  Future<List<Map<String, dynamic>>> readSession(String sessionId);

  Future<void> appendToSession(
    String sessionId,
    Map<String, dynamic> record,
  );
}
