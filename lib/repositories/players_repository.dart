import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/supabase_config.dart';
import '../models/player_model.dart';
import '../models/player_badge_model.dart';
import '../services/cache_store.dart';
import 'group_members_repository.dart';
import 'action_logs_repository.dart';

/// Nome do bucket público no Supabase Storage usado para os áudios
/// customizados de comemoração de gol. Precisa existir e ser público
/// para leitura (ver migração 005_goal_audio_and_action_logs.sql).
const String goalSoundsBucket = 'goal-sounds';

/// Players repository integrated with Supabase PostgreSQL.
class PlayersRepository {
  final SupabaseClient _client;
  final CacheStore _cache;
  final GroupMembersRepository _membersRepo;
  final ActionLogsRepository _logs;
  static const _uuid = Uuid();

  PlayersRepository({
    SupabaseClient? client,
    CacheStore? cache,
    GroupMembersRepository? membersRepo,
    ActionLogsRepository? logsRepo,
  })  : _client = client ?? supabase,
        _cache = cache ?? CacheStore(),
        _membersRepo = membersRepo ?? GroupMembersRepository(client: client ?? supabase),
        _logs = logsRepo ?? ActionLogsRepository(client: client ?? supabase);

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
      'manual_badges': player.manualBadges.map((b) => b.toMap()).toList(),
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

  /// Mapeia a extensão do arquivo para um mime type que o Storage aceita
  /// (o bucket só permite os tipos "oficiais" -- "audio/mp3" não é um
  /// mime type válido, por isso o upload de .mp3 tem que ir como audio/mpeg).
  static String _mimeTypeForExtension(String ext) {
    switch (ext.toLowerCase().replaceAll('.', '')) {
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'm4a':
        return 'audio/mp4';
      default:
        return 'audio/mpeg';
    }
  }

  /// Faz upload de um áudio customizado de gol para o Storage e associa
  /// a URL pública ao jogador. Somente admins do grupo podem chamar isso
  /// -- a checagem aqui é só para a UI reagir rápido; a garantia real é
  /// a policy de Storage/RLS (ver 005_goal_audio_and_action_logs.sql).
  Future<PlayerModel> uploadGoalSound({
    required String groupId,
    required String playerId,
    required Uint8List fileBytes,
    required String fileExtension,
  }) async {
    final isAdmin = await _membersRepo.isCurrentUserAdmin(groupId);
    if (!isAdmin) {
      throw Exception('Acesso negado: somente administradores podem definir áudios de gol.');
    }

    final ext = fileExtension.replaceAll('.', '').toLowerCase();
    final path = '$playerId/goal_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage.from(goalSoundsBucket).uploadBinary(
          path,
          fileBytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _mimeTypeForExtension(ext),
          ),
        );

    final publicUrl = _client.storage.from(goalSoundsBucket).getPublicUrl(path);

    final response = await _client
        .from('players')
        .update({'goal_sound_url': publicUrl})
        .eq('id', playerId)
        .select()
        .single();

    final updated = PlayerModel.fromMap(Map<String, dynamic>.from(response));
    await _logs.log(
      groupId: groupId,
      action: ActionLogsRepository.actionGoalSoundSet,
      targetPlayerId: playerId,
      details: {'url': publicUrl},
    );
    return updated;
  }

  /// Remove o áudio customizado de gol de um jogador (volta a usar o som genérico).
  Future<PlayerModel> clearGoalSound({
    required String groupId,
    required String playerId,
  }) async {
    final isAdmin = await _membersRepo.isCurrentUserAdmin(groupId);
    if (!isAdmin) {
      throw Exception('Acesso negado: somente administradores podem remover áudios de gol.');
    }

    final response = await _client
        .from('players')
        .update({'goal_sound_url': null})
        .eq('id', playerId)
        .select()
        .single();

    final updated = PlayerModel.fromMap(Map<String, dynamic>.from(response));
    await _logs.log(
      groupId: groupId,
      action: ActionLogsRepository.actionGoalSoundClear,
      targetPlayerId: playerId,
    );
    return updated;
  }

  /// Valores aceitos para o efeito de nome (mutuamente exclusivos).
  static const List<String> validNameEffects = ['gold', 'silver', 'bronze'];

  /// Define (ou remove, se [effect] for null) o efeito visual do nome de
  /// um jogador. Somente admins do grupo podem chamar isso -- a checagem
  /// aqui é só para a UI reagir rápido; a garantia real é a policy de
  /// RLS (ver 006_player_effects.sql).
  Future<PlayerModel> setNameEffect({
    required String groupId,
    required String playerId,
    required String? effect,
  }) async {
    final isAdmin = await _membersRepo.isCurrentUserAdmin(groupId);
    if (!isAdmin) {
      throw Exception('Acesso negado: somente administradores podem definir efeitos de nome.');
    }
    if (effect != null && !validNameEffects.contains(effect)) {
      throw ArgumentError('Efeito de nome inválido: $effect');
    }

    final response = await _client
        .from('players')
        .update({'name_effect': effect})
        .eq('id', playerId)
        .select()
        .single();

    final updated = PlayerModel.fromMap(Map<String, dynamic>.from(response));
    await _logs.log(
      groupId: groupId,
      action: ActionLogsRepository.actionNameEffectSet,
      targetPlayerId: playerId,
      details: {'effect': effect},
    );
    return updated;
  }

  /// Define/remove o selo de "craque do mês" (só aparece no pódio do ranking).
  /// Somente admins do grupo podem chamar isso.
  Future<PlayerModel> setMonthlyHighlight({
    required String groupId,
    required String playerId,
    required bool value,
  }) async {
    final isAdmin = await _membersRepo.isCurrentUserAdmin(groupId);
    if (!isAdmin) {
      throw Exception('Acesso negado: somente administradores podem definir o selo de craque do mês.');
    }

    final response = await _client
        .from('players')
        .update({'monthly_highlight': value})
        .eq('id', playerId)
        .select()
        .single();

    final updated = PlayerModel.fromMap(Map<String, dynamic>.from(response));
    await _logs.log(
      groupId: groupId,
      action: ActionLogsRepository.actionMonthlyHighlightSet,
      targetPlayerId: playerId,
      details: {'value': value},
    );
    return updated;
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
