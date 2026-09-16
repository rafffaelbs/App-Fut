import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/player_model.dart';
import '../models/player_badge_model.dart';
import '../services/cache_store.dart';

/// Repositório de Jogadores integrado ao Supabase PostgreSQL.
class PlayersRepository {
  final SupabaseClient _client;
  final CacheStore _cache;

  PlayersRepository({SupabaseClient? client, CacheStore? cache})
      : _client = client ?? supabase,
        _cache = cache ?? CacheStore();

  /// Retorna todos os jogadores vinculados a um determinado grupo.
  ///
  /// Supabase é sempre a fonte de verdade. O cache local só entra em jogo
  /// se a chamada de rede falhar (ex: sem conexão) — nesse caso devolvemos
  /// o último resultado bom conhecido em vez de uma lista vazia.
  Future<List<PlayerModel>> getJogadoresDoGrupo(String groupId) async {
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
      // Falha de rede/consulta: cai para o cache abaixo em vez de propagar.
      final cached = await _cache.read(cacheKey);
      if (cached != null) {
        return cached.asMapList().map((m) => PlayerModel.fromMap(m)).toList();
      }
    }

    // Fallback: Busca todos os jogadores da tabela `players` se group_members estiver vazio
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

  Future<List<PlayerModel>> getPlayersByGroup(String groupId) =>
      getJogadoresDoGrupo(groupId);

  /// Cria um "Jogador Fantasma":
  Future<PlayerModel> criarJogadorFantasma({
    required String groupId,
    required String nome,
    String? avatarUrl,
    List<PlayerBadgeModel> badges = const [],
  }) async {
    final insertPayload = <String, dynamic>{
      'creator_id': null,
      'name': nome.trim(),
    };

    final jogadorResp = await _client
        .from('players')
        .insert(insertPayload)
        .select()
        .single();

    final jogador = PlayerModel.fromMap(Map<String, dynamic>.from(jogadorResp));

    await _client.from('group_members').insert({
      'group_id': groupId,
      'player_id': jogador.id,
      'role': 'membro',
    });

    return jogador;
  }

  /// Cria ou vincula um jogador com uma conta de usuário.
  Future<PlayerModel> criarJogadorComUsuario({
    required String groupId,
    required String userId,
    required String nome,
    String? avatarUrl,
    List<PlayerBadgeModel> badges = const [],
    String papel = 'membro',
  }) async {
    final insertPayload = <String, dynamic>{
      'creator_id': userId,
      'name': nome.trim(),
    };

    final jogadorResp = await _client
        .from('players')
        .insert(insertPayload)
        .select()
        .single();

    final jogador = PlayerModel.fromMap(Map<String, dynamic>.from(jogadorResp));

    await _client.from('group_members').insert({
      'group_id': groupId,
      'player_id': jogador.id,
      'role': papel,
    });

    return jogador;
  }

  /// Atualiza os dados de um jogador.
  Future<PlayerModel> atualizarJogador(PlayerModel jogador) async {
    final updatePayload = <String, dynamic>{
      'name': jogador.name.trim(),
      'icon': jogador.icon,
      'badges': jogador.manualBadges.map((b) => b.toMap()).toList(),
    };

    final response = await _client
        .from('players')
        .update(updatePayload)
        .eq('id', jogador.id)
        .select()
        .single();

    return PlayerModel.fromMap(Map<String, dynamic>.from(response));
  }

  /// Desvincula um jogador do grupo.
  Future<void> removerJogadorDoGrupo({
    required String groupId,
    required String jogadorId,
  }) async {
    await _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('player_id', jogadorId);
  }

  /// Busca um jogador específico pelo seu UUID interno.
  Future<PlayerModel?> getJogadorPorId(String jogadorId) async {
    final response = await _client
        .from('players')
        .select()
        .eq('id', jogadorId)
        .maybeSingle();

    if (response == null) return null;
    return PlayerModel.fromMap(Map<String, dynamic>.from(response));
  }
}
