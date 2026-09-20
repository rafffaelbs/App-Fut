import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/rating_history_model.dart';

class RatingsRepository {
  final SupabaseClient _client;

  RatingsRepository({SupabaseClient? client})
      : _client = client ?? supabase;

  Future<List<RatingHistoryModel>> getPlayerHistoryBySeason({
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

  Future<List<RatingHistoryModel>> getFullPlayerHistory(
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

  Future<Map<String, double>> getLatestRatingsBySeason(
      String seasonId) async {
    final response = await _client
        .from('rating_history')
        .select('*, matches!inner(sessions!inner(season_id))')
        .eq('matches.sessions.season_id', seasonId)
        .order('created_at', ascending: true);

    final Map<String, double> latestRatings = {};
    for (final item in (response as List)) {
      if (item is Map) {
        final pId = item['player_id']?.toString() ?? '';
        final rating = double.tryParse(item['new_rating'].toString()) ?? 6.0;
        if (pId.isNotEmpty) {
          latestRatings[pId] = rating;
        }
      }
    }
    return latestRatings;
  }

  Future<void> recordRatingsBatch(
      List<RatingHistoryModel> records) async {
    if (records.isEmpty) return;

    final batch = records.map((r) => r.toMap(includeId: false)).toList();
    await _client.from('rating_history').insert(batch);
  }
}
