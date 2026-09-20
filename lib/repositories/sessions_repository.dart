import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/session_model.dart';

/// Repository for sessions ("peladas") integrated with Supabase PostgreSQL.
class SessionsRepository {
  final SupabaseClient _client;

  SessionsRepository({SupabaseClient? client})
      : _client = client ?? supabase;

  /// Returns a specific session by its id, or null if it doesn't exist.
  Future<SessionModel?> getSessionById(String sessionId) async {
    final response = await _client
        .from('sessions')
        .select()
        .eq('id', sessionId)
        .maybeSingle();

    if (response == null) return null;
    return SessionModel.fromMap(Map<String, dynamic>.from(response));
  }

  /// Returns the sessions of a given season.
  Future<List<SessionModel>> getSessionsBySeason(String seasonId) async {
    final response = await _client
        .from('sessions')
        .select()
        .eq('season_id', seasonId)
        .order('timestamp', ascending: false);

    return (response as List)
        .whereType<Map>()
        .map((item) => SessionModel.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Returns the sessions of a group, directly via sessions.group_id.
  /// (Previously fetched via seasons!inner(group_id) -- an INNER JOIN that
  /// dropped any session without a season_id, hiding old/imported sessions
  /// that never had a season linked.)
  Future<List<SessionModel>> getSessionsByGroup(String groupId) async {
    final response = await _client
        .from('sessions')
        .select()
        .eq('group_id', groupId)
        .order('session_date', ascending: false);

    return (response as List)
        .whereType<Map>()
        .map((item) => SessionModel.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Creates a new session linked to a season.
  Future<SessionModel> createSession(SessionModel session) async {
    final response = await _client
        .from('sessions')
        .insert(session.toMap(includeId: true))
        .select()
        .single();

    return SessionModel.fromMap(Map<String, dynamic>.from(response));
  }

  /// Updates the status, title, or settings of a session.
  Future<SessionModel> updateSession(SessionModel session) async {
    final response = await _client
        .from('sessions')
        .update(session.toMap(includeId: false))
        .eq('id', session.id)
        .select()
        .single();

    return SessionModel.fromMap(Map<String, dynamic>.from(response));
  }

  /// Incrementally persists the "live" state of a session that is still
  /// rolando -- placar, cronômetro e streaks -- direto nas colunas
  /// correspondentes de `sessions` (is_running, seconds_played, score_red,
  /// score_white, red_streak, white_streak, is_overtime, started_at).
  ///
  /// This intentionally bypasses `SessionModel`/`updateSession` (which
  /// don't carry these runtime fields) and writes only the columns given,
  /// so it's safe to call frequently (debounced) without touching title,
  /// win_limit, etc.
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
  }) async {
    final Map<String, dynamic> data = {
      if (isRunning != null) 'is_running': isRunning,
      if (secondsPlayed != null) 'seconds_played': secondsPlayed,
      if (scoreRed != null) 'score_red': scoreRed,
      if (scoreWhite != null) 'score_white': scoreWhite,
      if (redStreak != null) 'red_streak': redStreak,
      if (whiteStreak != null) 'white_streak': whiteStreak,
      if (isOvertime != null) 'is_overtime': isOvertime,
      if (startedAt != null) 'started_at': startedAt.toIso8601String(),
      if (status != null) 'status': status,
    };
    if (data.isEmpty) return;
    await _client.from('sessions').update(data).eq('id', sessionId);
  }

  /// Marks a session as finished.
  Future<void> finalizeSession(String sessionId) async {
    await _client
        .from('sessions')
        .update({'status': SessionModel.statusFinished})
        .eq('id', sessionId);
  }

  /// Deletes a session and its matches in cascade.
  Future<void> deleteSession(String sessionId) async {
    await _client.from('sessions').delete().eq('id', sessionId);
  }
}
