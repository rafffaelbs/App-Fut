import '../../../domain/repositories/groups_repository.dart';
import '../../../models/group_model.dart';
import 'snapshot_source.dart';

class TokenGroupsRepository implements GroupsRepository {
  final SnapshotSource _source;

  TokenGroupsRepository(this._source);

  @override
  bool get lastLoadFromCache => false;

  @override
  Future<List<GroupModel>> getMyGroups() async {
    final groupData = _source.group;
    if (groupData == null) {
      return const [];
    }
    return [GroupModel.fromMap(groupData)];
  }

  @override
  Future<GroupModel> createGroup({
    required String name,
    String? adminPlayerName,
  }) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<GroupModel> updateGroup(GroupModel group) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<void> deleteGroup(String groupId) {
    throw UnsupportedError('Site somente leitura');
  }
}
