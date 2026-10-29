import '../../models/season_model.dart';

abstract class SeasonsRepository {
  Future<List<SeasonModel>> getSeasons(String groupId);

  Future<SeasonModel?> getCurrentSeason(String groupId);

  Future<SeasonModel> createSeason({
    required String groupId,
    required String name,
    DateTime? startDate,
    DateTime? endDate,
    bool isActive = true,
  });

  Future<SeasonModel> updateSeason(SeasonModel season);

  Future<void> deleteSeason({
    required String groupId,
    required String seasonId,
  });
}
