import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/match_model.dart';
import '../models/match_lineup_model.dart';
import '../models/match_event_model.dart';
import '../models/rating_history_model.dart';

class MatchesRepository {
  final SupabaseClient _client;

  MatchesRepository({SupabaseClient? client})
      : _client = client ?? supabase;

  /// Fetches all matches for a session with lineups (including players) and events
  Future<List<MatchModel>> getPartidasPorSessao(String sessionId) async {
    try {
      final matchesResp = await _client
          .from("matches")
          .select("*, match_lineups(*, players(*)), match_events(*)")
          .eq("session_id", sessionId)
          .order("start_time", ascending: true);

      return (matchesResp as List)
          .map((m) => MatchModel.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    } catch (e) {
      // Fallback in case relation syntax fails
      try {
        final matchesResp = await _client
            .from("matches")
            .select()
            .eq("session_id", sessionId)
            .order("start_time", ascending: true);

        final List<MatchModel> results = [];
        for (final m in (matchesResp as List)) {
          final matchMap = Map<String, dynamic>.from(m as Map);
          final matchId = matchMap["id"]?.toString() ?? "";

          final lineupsResp = await _client
              .from("match_lineups")
              .select("*, players(*)")
              .eq("match_id", matchId);

          final eventsResp = await _client
              .from("match_events")
              .select()
              .eq("match_id", matchId);

          matchMap["match_lineups"] = lineupsResp;
          matchMap["match_events"] = eventsResp;
          results.add(MatchModel.fromMap(matchMap));
        }
        return results;
      } catch (err) {
        return [];
      }
    }
  }

  /// Fetches all matches for all sessions belonging to a group
  Future<List<MatchModel>> getPartidasPorGrupo(String groupId) async {
    try {
      final sessions = await _client
          .from("sessions")
          .select("id, seasons!inner(group_id)")
          .eq("seasons.group_id", groupId);

      final sessionIds = (sessions as List)
          .map((s) => s["id"]?.toString())
          .whereType<String>()
          .toList();
      if (sessionIds.isEmpty) return [];

      final matchesResp = await _client
          .from("matches")
          .select("*, match_lineups(*, players(*)), match_events(*)")
          .inFilter("session_id", sessionIds)
          .order("start_time", ascending: false);

      return (matchesResp as List)
          .map((m) => MatchModel.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Saves a complete match including lineups, events, and rating history
  Future<MatchModel> salvarPartidaCompleta({
    required String sessionId,
    required int teamAScore,
    required int teamBScore,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    required List<MatchLineupModel> lineups,
    required List<MatchEventModel> events,
    String? seasonId,
    List<RatingHistoryModel> ratingHistory = const [],
  }) async {
    final matchPayload = {
      "session_id": sessionId,
      "team_a_score": teamAScore,
      "team_b_score": teamBScore,
      "status": status ?? "finished",
      if (startTime != null) "start_time": startTime.toIso8601String(),
    };

    final matchResp = await _client
        .from("matches")
        .insert(matchPayload)
        .select()
        .single();

    final matchId = matchResp["id"]?.toString() ?? "";

    if (lineups.isNotEmpty) {
      final lineupBatch = lineups.map((e) {
        final map = e.toMap(includeId: false);
        map["match_id"] = matchId;
        return map;
      }).toList();
      await _client.from("match_lineups").insert(lineupBatch);
    }

    if (events.isNotEmpty) {
      final eventsBatch = events.map((ev) {
        final map = ev.toMap(includeId: false);
        map["match_id"] = matchId;
        return map;
      }).toList();
      await _client.from("match_events").insert(eventsBatch);
    }

    if (ratingHistory.isNotEmpty) {
      final ratingsBatch = ratingHistory.map((r) {
        final map = r.toMap(includeId: false);
        map["match_id"] = matchId;
        if (seasonId != null) map["season_id"] = seasonId;
        return map;
      }).toList();
      await _client.from("rating_history").insert(ratingsBatch);
    }

    return MatchModel(
      id: matchId,
      sessionId: sessionId,
      startTime: startTime,
      endTime: endTime,
      status: status,
      teamAScore: teamAScore,
      teamBScore: teamBScore,
      lineups: lineups.map((e) => e.copyWith(matchId: matchId)).toList(),
      events: events.map((ev) => ev.copyWith(matchId: matchId)).toList(),
    );
  }

  Future<MatchModel> atualizarPartidaCompleta({
    required String matchId,
    required String sessionId,
    required int teamAScore,
    required int teamBScore,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    required List<MatchLineupModel> lineups,
    required List<MatchEventModel> events,
    String? seasonId,
    List<RatingHistoryModel> ratingHistory = const [],
  }) async {
    final matchPayload = {
      "team_a_score": teamAScore,
      "team_b_score": teamBScore,
      if (status != null) "status": status,
      if (startTime != null) "start_time": startTime.toIso8601String(),
    };

    final matchResp = await _client
        .from("matches")
        .update(matchPayload)
        .eq("id", matchId)
        .select()
        .single();

    if (matchResp.isEmpty) {
      throw Exception("Falha ao atualizar partida no Supabase.");
    }

    await _client.from("match_events").delete().eq("match_id", matchId);
    await _client.from("match_lineups").delete().eq("match_id", matchId);
    await _client.from("rating_history").delete().eq("match_id", matchId);

    if (lineups.isNotEmpty) {
      final lineupBatch = lineups.map((e) {
        final map = e.toMap(includeId: false);
        map["match_id"] = matchId;
        return map;
      }).toList();
      await _client.from("match_lineups").insert(lineupBatch);
    }

    if (events.isNotEmpty) {
      final eventsBatch = events.map((ev) {
        final map = ev.toMap(includeId: false);
        map["match_id"] = matchId;
        return map;
      }).toList();
      await _client.from("match_events").insert(eventsBatch);
    }

    if (ratingHistory.isNotEmpty) {
      final ratingsBatch = ratingHistory.map((r) {
        final map = r.toMap(includeId: false);
        map["match_id"] = matchId;
        if (seasonId != null) map["season_id"] = seasonId;
        return map;
      }).toList();
      await _client.from("rating_history").insert(ratingsBatch);
    }

    return MatchModel(
      id: matchId,
      sessionId: sessionId,
      startTime: startTime,
      endTime: endTime,
      status: status,
      teamAScore: teamAScore,
      teamBScore: teamBScore,
      lineups: lineups.map((e) => e.copyWith(matchId: matchId)).toList(),
      events: events.map((ev) => ev.copyWith(matchId: matchId)).toList(),
    );
  }

  Future<MatchModel> atualizarPartidaParcial({
    required String matchId,
    required int teamAScore,
    required int teamBScore,
    required List<MatchEventModel> events,
  }) async {
    await _client
        .from("matches")
        .update({"team_a_score": teamAScore, "team_b_score": teamBScore})
        .eq("id", matchId);

    await _client.from("match_events").delete().eq("match_id", matchId);

    if (events.isNotEmpty) {
      final eventsBatch = events.map((ev) {
        final map = ev.toMap(includeId: false);
        map["match_id"] = matchId;
        return map;
      }).toList();
      await _client.from("match_events").insert(eventsBatch);
    }

    final matchesResp = await _client
        .from("matches")
        .select("*, match_lineups(*, players(*)), match_events(*)")
        .eq("id", matchId)
        .single();

    return MatchModel.fromMap(Map<String, dynamic>.from(matchesResp));
  }

  Future<void> deletarPartida(String matchId) async {
    await _client.from("match_events").delete().eq("match_id", matchId);
    await _client.from("match_lineups").delete().eq("match_id", matchId);
    await _client.from("rating_history").delete().eq("match_id", matchId);
    await _client.from("matches").delete().eq("id", matchId);
  }
}
