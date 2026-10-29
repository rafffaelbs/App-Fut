import '../../models/group_member_model.dart';
import '../../models/group_model.dart';

abstract class MembershipRepository {
  Future<List<GroupMemberModel>> getMembers(String groupId);

  Future<GroupMemberModel?> getMyMembership(String groupId);

  Future<void> promoteToAdmin({
    required String groupId,
    required String playerId,
  });

  Future<void> demoteToMember({
    required String groupId,
    required String playerId,
  });

  Future<GroupModel?> findGroupByCode(String code);

  Future<void> requestToJoin({
    required String inviteCode,
    required String desiredName,
  });

  Future<List<Map<String, dynamic>>> listPendingRequests(String groupId);

  Future<void> approveRequest(String requestId, {String? existingPlayerId});

  Future<void> rejectRequest(String requestId);
}
