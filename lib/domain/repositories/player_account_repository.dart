import '../../models/player_model.dart';

abstract class PlayerAccountRepository {
  Future<List<PlayerModel>> claimGhostProfiles();

  Future<List<PlayerModel>> getMyPlayers();
}
