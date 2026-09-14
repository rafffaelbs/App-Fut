import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/group_model.dart';
import '../models/player_model.dart';
import '../models/group_member_model.dart';
import 'group_members_repository.dart';

/// Groups repository integrated with Supabase PostgreSQL.
class GroupsRepository {
  final SupabaseClient _client;
  final GroupMembersRepository _membrosRepo;

  GroupsRepository({
    SupabaseClient? client,
    GroupMembersRepository? membrosRepo,
  })  : _client = client ?? supabase,
        _membrosRepo = membrosRepo ?? GroupMembersRepository(client: client);

  /// Returns groups that the authenticated user is a part of or created.
  Future<List<GroupModel>> getMeusGrupos() async {
    final currentUserId = SupabaseConfig.currentUserId;

    if (currentUserId == null) {
      final response = await _client.from('groups').select().order('created_at');
      return (response as List)
          .whereType<Map>()
          .map((item) => GroupModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    // 1. Groups created by the user
    final criadorResponse = await _client
        .from('groups')
        .select()
        .eq('creator_id', currentUserId);

    final Set<String> groupIds = {};
    final List<GroupModel> result = [];

    for (final item in (criadorResponse as List)) {
      final grupo = GroupModel.fromMap(Map<String, dynamic>.from(item));
      groupIds.add(grupo.id);
      result.add(grupo);
    }

    // 2. Groups where user is a member
    final membroResponse = await _client
        .from('group_members')
        .select('groups(*), players!inner(user_id)')
        .eq('players.user_id', currentUserId);

    for (final item in (membroResponse as List)) {
      if (item is Map && item['groups'] is Map) {
        final grupo = GroupModel.fromMap(Map<String, dynamic>.from(item['groups']));
        if (!groupIds.contains(grupo.id)) {
          groupIds.add(grupo.id);
          result.add(grupo);
        }
      }
    }

    return result;
  }

  /// Creates a new group.
  Future<GroupModel> criarGrupo({
    required String nome,
    String? adminPlayerName,
  }) async {
    final currentUserId = SupabaseConfig.currentUserId;

    // 1. Insert group
    final grupoResp = await _client
        .from('groups')
        .insert({
          'name': nome.trim(),
          'creator_id': currentUserId,
        })
        .select()
        .single();

    final grupo = GroupModel.fromMap(Map<String, dynamic>.from(grupoResp));

    if (currentUserId != null) {
      final jogadorExistente = await _client
          .from('players')
          .select()
          .eq('user_id', currentUserId)
          .maybeSingle();

      String adminJogadorId;
      if (jogadorExistente != null) {
        adminJogadorId = jogadorExistente['id'].toString();
      } else {
        final novoJogadorResp = await _client
            .from('players')
            .insert({
              'user_id': currentUserId,
              'name': adminPlayerName?.trim().isNotEmpty == true
                  ? adminPlayerName!.trim()
                  : 'Administrador',
            })
            .select()
            .single();
        final novoJogador =
            PlayerModel.fromMap(Map<String, dynamic>.from(novoJogadorResp));
        adminJogadorId = novoJogador.id;
      }

      await _client.from('group_members').insert({
        'group_id': grupo.id,
        'player_id': adminJogadorId,
        'role': GroupMemberModel.roleAdmin,
      });
    }

    await _client.from('seasons').insert({
      'group_id': grupo.id,
      'name': 'Temporada 1',
      'is_active': true,
    });

    return grupo;
  }

  /// Updates the group name
  Future<GroupModel> atualizarGrupo(GroupModel grupo) async {
    final isAdmin = await _membrosRepo.isCurrentUserAdmin(grupo.id);
    if (!isAdmin) {
      throw Exception('Access denied: Only administrators can edit the group.');
    }

    final response = await _client
        .from('groups')
        .update({'name': grupo.nome.trim()})
        .eq('id', grupo.id)
        .select()
        .single();

    return GroupModel.fromMap(Map<String, dynamic>.from(response));
  }

  /// Deletes a group
  Future<void> deletarGrupo(String groupId) async {
    final isAdmin = await _membrosRepo.isCurrentUserAdmin(groupId);
    if (!isAdmin) {
      throw Exception('Access denied: Only administrators can delete the group.');
    }

    await _client.from('groups').delete().eq('id', groupId);
  }
}
