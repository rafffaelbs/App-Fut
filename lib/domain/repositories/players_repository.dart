import '../../models/player_badge_model.dart';
import '../../models/player_model.dart';
import '../../utils/overall_calculator.dart';

abstract class PlayersRepository {
  static const List<String> validNameEffects = ['gold', 'silver', 'bronze'];

  Future<List<PlayerModel>> getPlayersByGroup(String groupId);

  Future<PlayerModel> createGhostPlayer({
    required String groupId,
    required String name,
    String? avatarUrl,
    List<PlayerBadgeModel> badges = const [],
  });

  Future<PlayerModel> updatePlayer(PlayerModel player);

  Future<PlayerModel> setPlayerIcon({
    required String playerId,
    required String? iconPath,
  });

  Future<PlayerModel> setGoalSound({
    required String playerId,
    required String? audioFileName,
    String? groupId,
  });

  Future<void> removePlayerFromGroup({
    required String groupId,
    required String playerId,
  });

  Future<PlayerModel?> getPlayerById(String playerId);

  Future<PlayerModel> setNameEffect({
    required String groupId,
    required String playerId,
    required String? effect,
  });

  Future<PlayerModel> setMonthlyHighlight({
    required String groupId,
    required String playerId,
    required bool value,
  });

  Future<PlayerModel> setCommunityAttributes({
    required String groupId,
    required String playerId,
    required CommunityAttributes attributes,
  });

  Future<PlayerModel> setAdvancedStat({
    required String groupId,
    required String playerId,
    required Map<String, dynamic> patch,
  });
}
