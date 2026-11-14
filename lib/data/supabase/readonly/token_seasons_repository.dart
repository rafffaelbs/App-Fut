import 'package:collection/collection.dart';
import '../../../domain/repositories/seasons_repository.dart';
import '../../../models/season_model.dart';
import 'snapshot_source.dart';

class TokenSeasonsRepository implements SeasonsRepository {
  final SnapshotSource _source;

  TokenSeasonsRepository(this._source);

  @override
  Future<List<SeasonModel>> getSeasons(String groupId) async {
    final list = _source.seasons;
    final seasons = list
        .whereType<Map>()
        .map((m) => SeasonModel.fromMap(Map<String, dynamic>.from(m)))
        .where((s) => s.groupId.isEmpty || s.groupId == groupId)
        .toList();
    return seasons;
  }

  @override
  Future<SeasonModel?> getCurrentSeason(String groupId) async {
    final seasons = await getSeasons(groupId);
    return seasons.firstWhereOrNull((s) => s.isActive) ?? seasons.firstOrNull;
  }

  @override
  Future<SeasonModel> createSeason({
    required String groupId,
    required String name,
    DateTime? startDate,
    DateTime? endDate,
    bool isActive = true,
  }) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<SeasonModel> updateSeason(SeasonModel season) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<void> deleteSeason({
    required String groupId,
    required String seasonId,
  }) {
    throw UnsupportedError('Site somente leitura');
  }
}
