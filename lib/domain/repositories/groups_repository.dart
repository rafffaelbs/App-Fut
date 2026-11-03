import '../../models/group_model.dart';

abstract class GroupsRepository {
  bool get lastLoadFromCache;

  Future<List<GroupModel>> getMyGroups();

  Future<GroupModel> createGroup({
    required String name,
    String? adminPlayerName,
  });

  Future<GroupModel> updateGroup(GroupModel group);

  Future<void> deleteGroup(String groupId);
}
