import 'package:collection/collection.dart';
import '../../../domain/repositories/player_account_repository.dart';
import '../../../domain/repositories/players_repository.dart';
import '../../../models/player_badge_model.dart';
import '../../../models/player_model.dart';
import '../../../utils/overall_calculator.dart';
import 'snapshot_source.dart';

class TokenPlayersRepository implements PlayersRepository, PlayerAccountRepository {
  final SnapshotSource _source;

  TokenPlayersRepository(this._source);

  @override
  Future<List<PlayerModel>> getPlayersByGroup(String groupId) async {
    final list = _source.players;
    return list
        .whereType<Map>()
        .map((m) => PlayerModel.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  @override
  Future<PlayerModel?> getPlayerById(String playerId) async {
    final list = _source.players;
    final raw = list.whereType<Map>().firstWhereOrNull(
          (m) => m['id']?.toString() == playerId,
        );
    if (raw == null) return null;
    return PlayerModel.fromMap(Map<String, dynamic>.from(raw));
  }

  // PlayerAccountRepository
  @override
  Future<List<PlayerModel>> claimGhostProfiles() async => const [];

  @override
  Future<List<PlayerModel>> getMyPlayers() async => const [];

  // Mutações lançam UnsupportedError
  @override
  Future<PlayerModel> createGhostPlayer({
    required String groupId,
    required String name,
    String? avatarUrl,
    List<PlayerBadgeModel> badges = const [],
  }) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<PlayerModel> updatePlayer(PlayerModel player, {String? groupId}) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<PlayerModel> setPlayerIcon({
    required String playerId,
    required String? iconPath,
  }) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<PlayerModel> setGoalSound({
    required String playerId,
    required String? audioFileName,
    String? groupId,
  }) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<void> removePlayerFromGroup({
    required String groupId,
    required String playerId,
  }) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<PlayerModel> setNameEffect({
    required String groupId,
    required String playerId,
    required String? effect,
  }) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<PlayerModel> setMonthlyHighlight({
    required String groupId,
    required String playerId,
    required bool value,
  }) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<PlayerModel> setCommunityAttributes({
    required String groupId,
    required String playerId,
    required CommunityAttributes attributes,
  }) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<PlayerModel> setAdvancedStat({
    required String groupId,
    required String playerId,
    required Map<String, dynamic> patch,
  }) {
    throw UnsupportedError('Site somente leitura');
  }
}
