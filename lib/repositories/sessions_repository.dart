import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/session_model.dart';
import '../services/cache_store.dart';

/// Repository for sessions ("peladas") integrated with Supabase PostgreSQL.
class SessionsRepository {
  final SupabaseClient _client;
  final CacheStore _cache;

  SessionsRepository({SupabaseClient? client, CacheStore? cache})
      : _client = client ?? supabase,
        _cache = cache ?? CacheStore();

  static const Duration _netTimeout = Duration(seconds: 8);

  /// Última versão conhecida da pelada, SEM rede. É o que a tela da partida
  /// usa pra abrir na hora (limite de vitórias, duração, modo de sorteio).
  Future<SessionModel?> getCachedSession(String sessionId) async {
    final cached = await _cache.read('session:$sessionId');
    final v = cached?.value;
    if (v is Map) return SessionModel.fromMap(Map<String, dynamic>.from(v));
    return null;
  }

  Future<void> _cacheRow(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) return;
    await _cache.write('session:$id', row);
  }

  /// Returns a specific session by its id, or null if it doesn't exist.
  Future<SessionModel?> getSessionById(String sessionId) async {
    try {
      final response = await _client
          .from('sessions')
          .select()
          .eq('id', sessionId)
          .maybeSingle()
          .timeout(_netTimeout);

      if (response == null) return null;
      final row = Map<String, dynamic>.from(response);
      await _cacheRow(row);
      return SessionModel.fromMap(row);
    } catch (_) {
      // Sem rede / rede ruim: usa a última versão salva.
      return getCachedSession(sessionId);
    }
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
    final listKey = 'sessions:group:$groupId';
    try {
      final response = await _client
          .from('sessions')
          .select()
          .eq('group_id', groupId)
          .order('session_date', ascending: false)
          .timeout(_netTimeout);

      final rows = (response as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      await _cache.write(listKey, rows);
      for (final r in rows) {
        await _cacheRow(r);
      }
      return rows.map(SessionModel.fromMap).toList();
    } catch (e) {
      final cached = await _cache.read(listKey);
      if (cached != null) {
        return cached.asMapList().map(SessionModel.fromMap).toList();
      }
      rethrow;
    }
  }

  /// Creates a new session linked to a season.
  Future<SessionModel> createSession(SessionModel session) async {
    final response = await _client
        .from('sessions')
        .insert(session.toMap(includeId: true))
        .select()
        .single();

    final row = Map<String, dynamic>.from(response);
    await _cacheRow(row);
    return SessionModel.fromMap(row);
  }

  /// Updates the status, title, or settings of a session.
  Future<SessionModel> updateSession(SessionModel session) async {
    final response = await _client
        .from('sessions')
        .update(session.toMap(includeId: false))
        .eq('id', session.id)
        .select()
        .single();

    // Atualiza o cache NA HORA: era aqui que a tela da partida ficava com o
    // limite de vitórias / duração antigos depois de editar a pelada.
    final row = Map<String, dynamic>.from(response);
    await _cacheRow(row);
    return SessionModel.fromMap(row);
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
