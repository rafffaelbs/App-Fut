import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/supabase_config.dart';
import '../models/match_model.dart';
import '../models/match_lineup_model.dart';
import '../models/match_event_model.dart';
import '../models/rating_history_model.dart';

class MatchesRepository {
  final SupabaseClient _client;
  static const _uuid = Uuid();

  MatchesRepository({SupabaseClient? client})
      : _client = client ?? supabase;

  /// Fetches all matches for a session with lineups (including players) and events
  Future<List<MatchModel>> getMatchesBySession(String sessionId) async {
    try {
      final matchesResp = await _client
          .from("matches")
          .select("*, match_lineups(*, players(*)), match_events(*)")
          .eq("session_id", sessionId)
          .order("played_at", ascending: true);

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
            .order("played_at", ascending: true);

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

  /// Fetches all matches belonging to a group. `matches` already carries its
  /// own group_id column, so there's no need to go through sessions/seasons.
  Future<List<MatchModel>> getMatchesByGroup(String groupId) async {
    try {
      final matchesResp = await _client
          .from("matches")
          .select("*, match_lineups(*, players(*)), match_events(*)")
          .eq("group_id", groupId)
          .order("played_at", ascending: false);

      return (matchesResp as List)
          .map((m) => MatchModel.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Saves a complete match including lineups, events, and rating history
  Future<MatchModel> saveFullMatch({
    required String sessionId,
    required String groupId,
    required int teamAScore,
    required int teamBScore,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    String? status,
    required List<MatchLineupModel> lineups,
    required List<MatchEventModel> events,
    String? seasonId,
    List<RatingHistoryModel> ratingHistory = const [],
  }) async {
    final effectiveStart = startTime ?? DateTime.now();
    // Prefer the real elapsed time tracked by the match screen (already
    // discounts pauses) over deriving it from start/end timestamps.
    final effectiveDuration =
        durationSeconds ?? (endTime != null ? endTime.difference(effectiveStart).inSeconds : null);
    final matchPayload = {
      "id": _uuid.v4(),
      "session_id": sessionId,
      "group_id": groupId,
      "score_red": teamAScore,
      "score_white": teamBScore,
      "played_at": effectiveStart.toIso8601String(),
      if (effectiveDuration != null) "duration_seconds": effectiveDuration,
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
      durationSeconds: effectiveDuration,
      lineups: lineups.map((e) => e.copyWith(matchId: matchId)).toList(),
      events: events.map((ev) => ev.copyWith(matchId: matchId)).toList(),
    );
  }

  Future<MatchModel> updateFullMatch({
    required String matchId,
    required String sessionId,
    required int teamAScore,
    required int teamBScore,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    String? status,
    required List<MatchLineupModel> lineups,
    required List<MatchEventModel> events,
    String? seasonId,
    List<RatingHistoryModel> ratingHistory = const [],
  }) async {
    final effectiveDuration = durationSeconds ??
        ((startTime != null && endTime != null)
            ? endTime.difference(startTime).inSeconds
            : null);
    final matchPayload = {
      "score_red": teamAScore,
      "score_white": teamBScore,
      if (startTime != null) "played_at": startTime.toIso8601String(),
      if (effectiveDuration != null) "duration_seconds": effectiveDuration,
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
      durationSeconds: effectiveDuration,
      lineups: lineups.map((e) => e.copyWith(matchId: matchId)).toList(),
      events: events.map((ev) => ev.copyWith(matchId: matchId)).toList(),
    );
  }

  Future<MatchModel> updatePartialMatch({
    required String matchId,
    required int teamAScore,
    required int teamBScore,
    required List<MatchEventModel> events,
  }) async {
    await _client
        .from("matches")
        .update({"score_red": teamAScore, "score_white": teamBScore})
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

  Future<void> deleteMatch(String matchId) async {
    await _client.from("match_events").delete().eq("match_id", matchId);
    await _client.from("match_lineups").delete().eq("match_id", matchId);
    await _client.from("rating_history").delete().eq("match_id", matchId);
    await _client.from("matches").delete().eq("id", matchId);
  }
}
