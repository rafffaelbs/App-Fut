import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/session_model.dart';

/// Repositório de Sessões (Peladas) integrado ao Supabase PostgreSQL.
class SessionsRepository {
  final SupabaseClient _client;

  SessionsRepository({SupabaseClient? client})
      : _client = client ?? supabase;

  /// Retorna uma sessão específica pelo seu id, ou null se não existir.
  Future<SessionModel?> getSessaoPorId(String sessaoId) async {
    final response = await _client
        .from('sessions')
        .select()
        .eq('id', sessaoId)
        .maybeSingle();

    if (response == null) return null;
    return SessionModel.fromMap(Map<String, dynamic>.from(response));
  }

  /// Retorna as sessões de uma determinada temporada.
  Future<List<SessionModel>> getSessoesPorTemporada(String seasonId) async {
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

  /// Retorna as sessões de um grupo, buscando as temporadas do grupo.
  Future<List<SessionModel>> getSessoesPorGrupo(String groupId) async {
    final response = await _client
        .from('sessions')
        .select('*, seasons!inner(group_id)')
        .eq('seasons.group_id', groupId)
        .order('timestamp', ascending: false);

    return (response as List)
        .whereType<Map>()
        .map((item) => SessionModel.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Cria uma nova sessão de pelada vinculada a uma temporada.
  Future<SessionModel> criarSessao(SessionModel sessao) async {
    final response = await _client
        .from('sessions')
        .insert(sessao.toMap(includeId: false))
        .select()
        .single();

    return SessionModel.fromMap(Map<String, dynamic>.from(response));
  }

  /// Atualiza o status, título ou configurações de uma sessão.
  Future<SessionModel> atualizarSessao(SessionModel sessao) async {
    final response = await _client
        .from('sessions')
        .update(sessao.toMap(includeId: false))
        .eq('id', sessao.id)
        .select()
        .single();

    return SessionModel.fromMap(Map<String, dynamic>.from(response));
  }

  /// Finaliza uma sessão de pelada.
  Future<void> finalizarSessao(String sessaoId) async {
    await _client
        .from('sessions')
        .update({'status': SessionModel.statusFinalizada})
        .eq('id', sessaoId);
  }

  /// Exclui uma sessão e suas partidas em cascata.
  Future<void> deletarSessao(String sessaoId) async {
    await _client.from('sessions').delete().eq('id', sessaoId);
  }

  // English method aliases
  Future<List<SessionModel>> getSessionsByGroup(String groupId) =>
      getSessoesPorGrupo(groupId);
  Future<SessionModel?> getSessionById(String id) => getSessaoPorId(id);
  Future<SessionModel> createSession(SessionModel s) => criarSessao(s);
  Future<SessionModel> updateSession(SessionModel s) => atualizarSessao(s);
  Future<void> deleteSession(String id) => deletarSessao(id);
}
