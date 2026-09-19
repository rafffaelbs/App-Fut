import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/season_model.dart';
import 'group_members_repository.dart';

/// Repository for Seasons integrated with Supabase PostgreSQL.
class SeasonsRepository {
  final SupabaseClient _client;
  final GroupMembersRepository _membersRepo;

  SeasonsRepository({
    SupabaseClient? client,
    GroupMembersRepository? membersRepo,
  })  : _client = client ?? supabase,
        _membersRepo = membersRepo ?? GroupMembersRepository(client: client);

  /// Lists all seasons for a group.
  Future<List<SeasonModel>> getSeasons(String groupId) async {
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

  /// Returns the active/current season of a group.
  Future<SeasonModel?> getCurrentSeason(String groupId) async {
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
  Future<SeasonModel> createSeason({
    required String groupId,
    required String name,
    DateTime? startDate,
    DateTime? endDate,
    bool isActive = true,
  }) async {
    final isAdmin = await _membersRepo.isCurrentUserAdmin(groupId);
    if (!isAdmin) {
      throw Exception('Access denied: Only administrators can create seasons.');
    }

    if (isActive) {
      await _client
          .from('seasons')
          .update({'is_active': false})
          .eq('group_id', groupId);
    }

    final insertPayload = {
      'group_id': groupId,
      'name': name.trim(),
      'start_date': startDate != null
          ? "${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}"
          : null,
      'end_date': endDate != null
          ? "${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}"
          : null,
      'is_active': isActive,
    };

    final response = await _client
        .from('seasons')
        .insert(insertPayload)
        .select()
        .single();

    return SeasonModel.fromMap(Map<String, dynamic>.from(response));
  }

  /// Updates an existing season.
  Future<SeasonModel> updateSeason(SeasonModel season) async {
    final isAdmin = await _membersRepo.isCurrentUserAdmin(season.groupId);
    if (!isAdmin) {
      throw Exception('Access denied: Only administrators can edit season configurations.');
    }

    if (season.isActive) {
      await _client
          .from('seasons')
          .update({'is_active': false})
          .eq('group_id', season.groupId);
    }

    final response = await _client
        .from('seasons')
        .update(season.toMap(includeId: false))
        .eq('id', season.id)
        .select()
        .single();

    return SeasonModel.fromMap(Map<String, dynamic>.from(response));
  }

  /// Deletes a season.
  Future<void> deleteSeason({
    required String groupId,
    required String seasonId,
  }) async {
    final isAdmin = await _membersRepo.isCurrentUserAdmin(groupId);
    if (!isAdmin) {
      throw Exception('Access denied: Only administrators can delete seasons.');
    }

    await _client.from('seasons').delete().eq('id', seasonId);
  }
}
