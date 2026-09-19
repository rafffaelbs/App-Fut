import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Persists the "quem está jogando" state of a session that is still in
/// progress (presença, times parciais e goleiros) incrementally to
/// Supabase, so it survives app restarts, storage cleared, or troca de
/// aparelho -- sem esperar o "Encerrar Partida" (que só grava em `matches`).
///
/// This is intentionally decoupled from `matches`/`match_lineups`: those
/// only exist once a partida is finalizada. `session_arrivals` is the
/// "rascunho" (draft) of quem chegou, times e goleiros enquanto a pelada
/// ainda está rolando.
class SessionArrivalsRepository {
  final SupabaseClient _client;

  SessionArrivalsRepository({SupabaseClient? client})
      : _client = client ?? supabase;

  /// Returns the current draft presence list for a session, ordered by
  /// arrival order.
  Future<List<Map<String, dynamic>>> getArrivals(String sessionId) async {
    final response = await _client
        .from('session_arrivals')
        .select()
        .eq('session_id', sessionId)
        .order('arrival_order', ascending: true);

    return (response as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Replaces the whole draft presence list for a session with [players].
  ///
  /// Each entry in [players] must contain: `id` (player id), `desistiu`
  /// (bool), and optionally `team` ('red'/'white') and `is_goalkeeper`.
  /// The arrival order is taken from the list's own order.
  ///
  /// Uses delete+insert (same pattern as `MatchesRepository`) instead of a
  /// diffed upsert: the full draft list is small (a handful of players)
  /// and this call is already debounced/throttled by the caller, so the
  /// extra round-trip is a non-issue and keeps this dead simple to reason
  /// about.
  Future<void> replaceArrivals(
    String sessionId,
    List<Map<String, dynamic>> players,
  ) async {
    await _client.from('session_arrivals').delete().eq('session_id', sessionId);

    if (players.isEmpty) return;

    final batch = <Map<String, dynamic>>[];
    for (int i = 0; i < players.length; i++) {
      final p = players[i];
      final String? playerId = p['id']?.toString();
      if (playerId == null || playerId.isEmpty) continue;
      batch.add({
        'session_id': sessionId,
        'player_id': playerId,
        'arrival_order': i,
        'desistiu': p['desistiu'] == true,
        if (p['team'] != null) 'team': p['team'],
        if (p['is_goalkeeper'] != null) 'is_goalkeeper': p['is_goalkeeper'],
      });
    }

    if (batch.isNotEmpty) {
      await _client.from('session_arrivals').insert(batch);
    }
  }

  /// Clears the draft presence list -- call once a session is finalized,
  /// since from that point on the record of what happened lives in
  /// `matches`/`match_lineups`.
  Future<void> clearArrivals(String sessionId) async {
    await _client.from('session_arrivals').delete().eq('session_id', sessionId);
  }
}
