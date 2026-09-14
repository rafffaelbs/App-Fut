import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/rating_history_model.dart';

class RatingsRepository {
  final SupabaseClient _client;

  RatingsRepository({SupabaseClient? client})
      : _client = client ?? supabase;

  Future<List<RatingHistoryModel>> getHistoricoJogadorPorTemporada({
    required String playerId,
    required String seasonId,
  }) async {
    final response = await _client
        .from('rating_history')
        .select('*, matches!inner(sessions!inner(season_id))')
        .eq('player_id', playerId)
        .eq('matches.sessions.season_id', seasonId)
        .order('created_at', ascending: true);

    return (response as List)
        .whereType<Map>()
        .map((item) =>
            RatingHistoryModel.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<RatingHistoryModel>> getHistoricoCompletoJogador(
      String playerId) async {
    final response = await _client
        .from('rating_history')
        .select()
        .eq('player_id', playerId)
        .order('created_at', ascending: true);

    return (response as List)
        .whereType<Map>()
        .map((item) =>
            RatingHistoryModel.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, double>> getUltimosRatingsPorTemporada(
      String seasonId) async {
    final response = await _client
        .from('rating_history')
        .select('*, matches!inner(sessions!inner(season_id))')
        .eq('matches.sessions.season_id', seasonId)
        .order('created_at', ascending: true);

    final Map<String, double> ultimosRatings = {};
    for (final item in (response as List)) {
      if (item is Map) {
        final pId = item['player_id']?.toString() ?? '';
        final rating = double.tryParse(item['new_rating'].toString()) ?? 6.0;
        if (pId.isNotEmpty) {
          ultimosRatings[pId] = rating;
        }
      }
    }
    return ultimosRatings;
  }

  Future<void> registrarRatingsEmLote(
      List<RatingHistoryModel> registros) async {
    if (registros.isEmpty) return;

    final batch = registros.map((r) => r.toMap(includeId: false)).toList();
    await _client.from('rating_history').insert(batch);
  }
}
