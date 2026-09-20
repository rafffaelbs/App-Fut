import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/supabase_config.dart';
import '../models/player_model.dart';
import '../models/player_badge_model.dart';
import '../services/cache_store.dart';

/// Players repository integrated with Supabase PostgreSQL.
class PlayersRepository {
  final SupabaseClient _client;
  final CacheStore _cache;
  static const _uuid = Uuid();

  PlayersRepository({SupabaseClient? client, CacheStore? cache})
      : _client = client ?? supabase,
        _cache = cache ?? CacheStore();

  /// Returns every player linked to a given group.
  ///
  /// Supabase is always the source of truth. The local cache only kicks in
  /// if the network call fails (e.g. no connection) -- in that case we
  /// return the last known good result instead of an empty list.
  Future<List<PlayerModel>> getPlayersByGroup(String groupId) async {
    final cacheKey = 'players:group:$groupId';

    try {
      final response = await _client
          .from('group_members')
          .select('players(*)')
          .eq('group_id', groupId);

      final List<Map<String, dynamic>> rawPlayers = [];
      for (final item in (response as List)) {
        if (item is Map && item['players'] is Map) {
          rawPlayers.add(Map<String, dynamic>.from(item['players']));
        }
      }

      if (rawPlayers.isNotEmpty) {
        await _cache.write(cacheKey, rawPlayers);
        return rawPlayers.map((m) => PlayerModel.fromMap(m)).toList();
      }
    } catch (_) {
      // Network/query failure: fall back to the cache below instead of throwing.
      final cached = await _cache.read(cacheKey);
      if (cached != null) {
        return cached.asMapList().map((m) => PlayerModel.fromMap(m)).toList();
      }
    }

    // Fallback: fetch every row from `players` if group_members is empty.
    try {
      final response = await _client.from('players').select();
      final rawPlayers = (response as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      await _cache.write(cacheKey, rawPlayers);
      return rawPlayers.map((m) => PlayerModel.fromMap(m)).toList();
    } catch (_) {
      final cached = await _cache.read(cacheKey);
      if (cached != null) {
        return cached.asMapList().map((m) => PlayerModel.fromMap(m)).toList();
      }
      return [];
    }
  }

  /// Creates a "Ghost Player" (no linked user account yet).
  Future<PlayerModel> createGhostPlayer({
    required String groupId,
    required String name,
    String? avatarUrl,
    List<PlayerBadgeModel> badges = const [],
  }) async {
    final insertPayload = <String, dynamic>{
      'id': _uuid.v4(),
      'creator_id': null,
      'name': name.trim(),
    };

    final playerResp = await _client
        .from('players')
        .insert(insertPayload)
        .select()
        .single();

    final player = PlayerModel.fromMap(Map<String, dynamic>.from(playerResp));

    await _client.from('group_members').insert({
      'group_id': groupId,
      'player_id': player.id,
      'role': 'member',
    });

    return player;
  }

  /// Creates or links a player to a user account.
  Future<PlayerModel> createPlayerWithUser({
    required String groupId,
    required String userId,
    required String name,
    String? avatarUrl,
    List<PlayerBadgeModel> badges = const [],
    String role = 'member',
  }) async {
    final insertPayload = <String, dynamic>{
      'id': _uuid.v4(),
      'creator_id': userId,
      'name': name.trim(),
    };

    final playerResp = await _client
        .from('players')
        .insert(insertPayload)
        .select()
        .single();

    final player = PlayerModel.fromMap(Map<String, dynamic>.from(playerResp));

    await _client.from('group_members').insert({
      'group_id': groupId,
      'player_id': player.id,
      'role': role,
    });

    return player;
  }

  /// Updates a player's data.
  Future<PlayerModel> updatePlayer(PlayerModel player) async {
    final updatePayload = <String, dynamic>{
      'name': player.name.trim(),
      'icon': player.icon,
      'badges': player.manualBadges.map((b) => b.toMap()).toList(),
    };

    final response = await _client
        .from('players')
        .update(updatePayload)
        .eq('id', player.id)
        .select()
        .single();

    return PlayerModel.fromMap(Map<String, dynamic>.from(response));
  }

  /// Unlinks a player from a group.
  Future<void> removePlayerFromGroup({
    required String groupId,
    required String playerId,
  }) async {
    await _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('player_id', playerId);
  }

  /// Sets/updates the linking email of a "ghost" player (no login yet).
  /// Once that person signs up or logs in with the same email, the profile
  /// gets automatically linked (see 004_auth_and_permissions.sql).
  Future<PlayerModel> linkEmailToPlayer({
    required String playerId,
    required String email,
  }) async {
    final response = await _client
        .from('players')
        .update({'email': email.trim().toLowerCase()})
        .eq('id', playerId)
        .select()
        .single();
    return PlayerModel.fromMap(Map<String, dynamic>.from(response));
  }

  /// Call this right after login/signup: automatically links the current
  /// user to any "ghost" player that already has their email saved.
  Future<List<PlayerModel>> claimGhostProfiles() async {
    final response = await _client.rpc('claim_ghost_profile');
    return (response as List)
        .whereType<Map>()
        .map((e) => PlayerModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Returns the player(s) already linked to the current authenticated account.
  Future<List<PlayerModel>> getMyPlayers() async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return [];
    final response = await _client.from('players').select().eq('creator_id', currentUserId);
    return (response as List)
        .whereType<Map>()
        .map((e) => PlayerModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Fetches a specific player by its internal UUID.
  Future<PlayerModel?> getPlayerById(String playerId) async {
    final response = await _client
        .from('players')
        .select()
        .eq('id', playerId)
        .maybeSingle();

    if (response == null) return null;
    return PlayerModel.fromMap(Map<String, dynamic>.from(response));
  }
}
