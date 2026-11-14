import '../../../domain/repositories/session_arrivals_repository.dart';

class TokenSessionArrivalsRepository implements SessionArrivalsRepository {
  const TokenSessionArrivalsRepository();

  @override
  Future<List<Map<String, dynamic>>> getArrivals(String sessionId) async {
    return const [];
  }

  @override
  Future<Map<String, List<String>>> getPlayerIdsBySessions(
    List<String> sessionIds,
  ) async {
    return const {};
  }

  @override
  Future<void> replaceArrivals(
    String sessionId,
    List<Map<String, dynamic>> players,
  ) {
    throw UnsupportedError('Site somente leitura');
  }
}
