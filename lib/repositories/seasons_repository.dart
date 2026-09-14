import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/season_model.dart';
import 'group_members_repository.dart';

/// Repository for Seasons integrated with Supabase PostgreSQL.
class SeasonsRepository {
  final SupabaseClient _client;
  final GroupMembersRepository _membrosRepo;

  SeasonsRepository({
    SupabaseClient? client,
    GroupMembersRepository? membrosRepo,
  })  : _client = client ?? supabase,
        _membrosRepo = membrosRepo ?? GroupMembersRepository(client: client);

  /// Lists all seasons for a group.
  Future<List<SeasonModel>> getTemporadas(String groupId) async {
    final response = await _client
        .from('seasons')
        .select()
        .eq('group_id', groupId)
        .order('is_active', ascending: false)
        .order('start_date', ascending: false);

    return (response as List)
        .whereType<Map>()
        .map((item) => SeasonModel.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// English alias for [getTemporadaAtual].
  Future<SeasonModel?> getCurrentSeason(String groupId) =>
      getTemporadaAtual(groupId);

  /// Returns the active/current season of a group.
  Future<SeasonModel?> getTemporadaAtual(String groupId) async {
    final response = await _client
        .from('seasons')
        .select()
        .eq('group_id', groupId)
        .eq('is_active', true)
        .maybeSingle();

    if (response == null) return null;
    return SeasonModel.fromMap(Map<String, dynamic>.from(response));
  }

  /// Creates a new season.
  Future<SeasonModel> criarTemporada({
    required String groupId,
    required String nome,
    DateTime? dataInicio,
    DateTime? dataFim,
    bool isAtual = true,
  }) async {
    final isAdmin = await _membrosRepo.isCurrentUserAdmin(groupId);
    if (!isAdmin) {
      throw Exception('Access denied: Only administrators can create seasons.');
    }

    if (isAtual) {
      await _client
          .from('seasons')
          .update({'is_active': false})
          .eq('group_id', groupId);
    }

    final insertPayload = {
      'group_id': groupId,
      'name': nome.trim(),
      'start_date': dataInicio != null
          ? "${dataInicio.year.toString().padLeft(4, '0')}-${dataInicio.month.toString().padLeft(2, '0')}-${dataInicio.day.toString().padLeft(2, '0')}"
          : null,
      'end_date': dataFim != null
          ? "${dataFim.year.toString().padLeft(4, '0')}-${dataFim.month.toString().padLeft(2, '0')}-${dataFim.day.toString().padLeft(2, '0')}"
          : null,
      'is_active': isAtual,
    };

    final response = await _client
        .from('seasons')
        .insert(insertPayload)
        .select()
        .single();

    return SeasonModel.fromMap(Map<String, dynamic>.from(response));
  }

  /// Updates an existing season.
  Future<SeasonModel> atualizarTemporada(SeasonModel temporada) async {
    final isAdmin = await _membrosRepo.isCurrentUserAdmin(temporada.groupId);
    if (!isAdmin) {
      throw Exception('Access denied: Only administrators can edit season configurations.');
    }

    if (temporada.isActive) {
      await _client
          .from('seasons')
          .update({'is_active': false})
          .eq('group_id', temporada.groupId);
    }

    final response = await _client
        .from('seasons')
        .update(temporada.toMap(includeId: false))
        .eq('id', temporada.id)
        .select()
        .single();

    return SeasonModel.fromMap(Map<String, dynamic>.from(response));
  }

  Future<SeasonModel> createSeason({
    required String groupId,
    required String name,
    DateTime? startDate,
    DateTime? endDate,
    bool isActive = true,
  }) => criarTemporada(
    groupId: groupId,
    nome: name,
    dataInicio: startDate,
    dataFim: endDate,
    isAtual: isActive,
  );

  Future<SeasonModel> updateSeason(SeasonModel season) => atualizarTemporada(season);

  Future<List<SeasonModel>> getSeasons(String groupId) => getTemporadas(groupId);

  /// Deletes a season.
  Future<void> deletarTemporada({
    required String groupId,
    required String temporadaId,
  }) async {
    final isAdmin = await _membrosRepo.isCurrentUserAdmin(groupId);
    if (!isAdmin) {
      throw Exception('Access denied: Only administrators can delete seasons.');
    }

    await _client.from('seasons').delete().eq('id', temporadaId);
  }
}
