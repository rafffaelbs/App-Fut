import '../../../domain/repositories/membership_repository.dart';
import '../../../models/group_member_model.dart';
import '../../../models/group_model.dart';
import 'snapshot_source.dart';

class TokenMembershipRepository implements MembershipRepository {
  final SnapshotSource _source;

  TokenMembershipRepository(this._source);

  @override
  Future<List<GroupMemberModel>> getMembers(String groupId) async {
    final Map<String, Map<String, dynamic>> playersById = {
      for (final p in _source.players.whereType<Map>())
        if (p['id'] != null) p['id'].toString(): Map<String, dynamic>.from(p),
    };

    final membersList = _source.members;
    final List<GroupMemberModel> result = [];

    for (final raw in membersList.whereType<Map>()) {
      final map = Map<String, dynamic>.from(raw);
      final pId = map['player_id']?.toString() ?? map['jogador_id']?.toString();
      if (map['players'] == null && map['jogadores'] == null && pId != null) {
        if (playersById.containsKey(pId)) {
          map['players'] = playersById[pId];
        }
      }
      if (map['group_id'] == null && map['grupo_id'] == null) {
        map['group_id'] = groupId;
      }
      if (map['id'] == null) {
        map['id'] = '$groupId:$pId';
      }
      result.add(GroupMemberModel.fromMap(map));
    }

    return result;
  }

  @override
  Future<GroupMemberModel?> getMyMembership(String groupId) async => null;

  @override
  Future<void> promoteToAdmin({
    required String groupId,
    required String playerId,
  }) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<void> demoteToMember({
    required String groupId,
    required String playerId,
  }) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<GroupModel?> findGroupByCode(String code) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<void> requestToJoin({
    required String inviteCode,
    required String desiredName,
  }) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<List<Map<String, dynamic>>> listPendingRequests(String groupId) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<void> approveRequest(String requestId, {String? existingPlayerId}) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<void> rejectRequest(String requestId) {
    throw UnsupportedError('Site somente leitura');
  }
}
