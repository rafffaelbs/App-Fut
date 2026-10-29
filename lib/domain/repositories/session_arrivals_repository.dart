abstract class SessionArrivalsRepository {
  Future<List<Map<String, dynamic>>> getArrivals(String sessionId);

  Future<Map<String, List<String>>> getPlayerIdsBySessions(
    List<String> sessionIds,
  );

  Future<void> replaceArrivals(
    String sessionId,
    List<Map<String, dynamic>> players,
  );
}
