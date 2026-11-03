import 'package:flutter/foundation.dart';
import 'package:app_do_fut/app/app_features.dart';
import 'package:app_do_fut/app/app_services.dart';
import 'package:app_do_fut/domain/repositories/action_logs_repository.dart';
import 'package:app_do_fut/domain/repositories/custom_badges_repository.dart';
import 'package:app_do_fut/domain/repositories/groups_repository.dart';
import 'package:app_do_fut/domain/repositories/match_history_store.dart';
import 'package:app_do_fut/domain/repositories/matches_repository.dart';
import 'package:app_do_fut/domain/repositories/membership_repository.dart';
import 'package:app_do_fut/domain/repositories/player_account_repository.dart';
import 'package:app_do_fut/domain/repositories/players_repository.dart';
import 'package:app_do_fut/domain/repositories/seasons_repository.dart';
import 'package:app_do_fut/domain/repositories/session_arrivals_repository.dart';
import 'package:app_do_fut/domain/repositories/sessions_repository.dart';
import 'package:app_do_fut/domain/services/auth_service.dart';
import 'package:app_do_fut/domain/services/match_outbox.dart';
import 'package:app_do_fut/domain/services/permission_service.dart';
import 'package:app_do_fut/models/group_member_model.dart';
import 'package:app_do_fut/models/group_model.dart';
import 'package:app_do_fut/models/match_event_model.dart';
import 'package:app_do_fut/models/match_model.dart';
import 'package:app_do_fut/models/player_badge_model.dart';
import 'package:app_do_fut/models/player_model.dart';
import 'package:app_do_fut/models/season_model.dart';
import 'package:app_do_fut/models/session_model.dart';
import 'package:app_do_fut/utils/overall_calculator.dart';

class StubAuthService implements AuthService {
  String? userId;
  String? userEmail;

  StubAuthService({this.userId = 'test-user', this.userEmail = 'test@example.com'});

  @override
  String? get currentUserId => userId;

  @override
  String? get currentUserEmail => userEmail;

  @override
  bool get isSignedIn => userId != null;

  @override
  Stream<bool> get signedInChanges => Stream.value(isSignedIn);

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}

class StubPermissionService implements PermissionService {
  bool adminResult;

  StubPermissionService({this.adminResult = true});

  @override
  Future<bool> isAdmin(String groupId) async => adminResult;

  @override
  Future<void> requireAdmin(String groupId, [String? message]) async {
    if (!adminResult) {
      throw Exception(message ?? 'Acesso negado: requer privilégio de administrador.');
    }
  }
}

class StubPlayersRepository implements PlayersRepository {
  List<PlayerModel> players;
  PlayerModel Function(PlayerModel)? onUpdatePlayer;
  bool shouldThrow;

  StubPlayersRepository({
    this.players = const [],
    this.onUpdatePlayer,
    this.shouldThrow = false,
  });

  @override
  Future<List<PlayerModel>> getPlayersByGroup(String groupId) async {
    if (shouldThrow) throw Exception('Network error');
    return players;
  }

  @override
  Future<PlayerModel> createGhostPlayer({
    required String groupId,
    required String name,
    String? avatarUrl,
    List<PlayerBadgeModel> badges = const [],
  }) async {
    if (shouldThrow) throw Exception('Network error');
    final p = PlayerModel(id: 'ghost-${name.toLowerCase()}', name: name, icon: avatarUrl);
    players = [...players, p];
    return p;
  }

  @override
  Future<PlayerModel?> getPlayerById(String playerId) async {
    if (shouldThrow) throw Exception('Network error');
    try {
      return players.firstWhere((p) => p.id == playerId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PlayerModel> updatePlayer(PlayerModel player, {String? groupId}) async {
    if (shouldThrow) throw Exception('Network error');
    if (onUpdatePlayer != null) {
      return onUpdatePlayer!(player);
    }
    players = players.map((p) => p.id == player.id ? player : p).toList();
    return player;
  }

  @override
  Future<void> removePlayerFromGroup({
    required String groupId,
    required String playerId,
  }) async {
    if (shouldThrow) throw Exception('Network error');
    players = players.where((p) => p.id != playerId).toList();
  }

  @override
  Future<PlayerModel> setAdvancedStat({
    required String groupId,
    required String playerId,
    required Map<String, dynamic> patch,
  }) async => throw UnimplementedError();

  @override
  Future<PlayerModel> setCommunityAttributes({
    required String groupId,
    required String playerId,
    required CommunityAttributes attributes,
  }) async => throw UnimplementedError();

  @override
  Future<PlayerModel> setGoalSound({
    required String playerId,
    required String? audioFileName,
    String? groupId,
  }) async => throw UnimplementedError();

  @override
  Future<PlayerModel> setMonthlyHighlight({
    required String groupId,
    required String playerId,
    required bool value,
  }) async => throw UnimplementedError();

  @override
  Future<PlayerModel> setNameEffect({
    required String groupId,
    required String playerId,
    required String? effect,
  }) async => throw UnimplementedError();

  @override
  Future<PlayerModel> setPlayerIcon({
    required String playerId,
    required String? iconPath,
  }) async => throw UnimplementedError();
}

class StubMatchHistoryStore implements MatchHistoryStore {
  @override
  Future<void> appendToSession(String sessionId, Map<String, dynamic> record) async {}

  @override
  Future<bool> hasSession(String sessionId) async => true;

  @override
  Future<List<Map<String, dynamic>>> readSession(String sessionId) async => [];
}

class StubMatchOutbox implements MatchOutbox {
  @override
  Future<void> enqueue(Map<String, dynamic> job) async {}

  @override
  Future<void> flush() async {}

  @override
  Future<void> refreshCounts() async {}

  @override
  ValueListenable<String?> get lastError => ValueNotifier(null);

  @override
  ValueListenable<int> get pending => ValueNotifier(0);

  @override
  ValueListenable<int> get failed => ValueNotifier(0);

  @override
  Future<List<Map<String, dynamic>>> failedJobs() async => [];

  @override
  Future<void> retryFailed(String matchId) async {}

  @override
  Future<void> discardFailed(String matchId) async {}
}

class StubCustomBadgesRepository implements CustomBadgesRepository {
  @override
  Future<List<Map<String, dynamic>>> getCustomBadges(String groupId) async => [];

  @override
  Future<bool> hasCustomBadges(String groupId) async => false;

  @override
  Future<void> saveCustomBadges(String groupId, List<Map<String, dynamic>> badges) async {}
}

class StubGroupsRepository implements GroupsRepository {
  @override
  Future<GroupModel> createGroup({required String name, String? adminPlayerName}) async => throw UnimplementedError();

  @override
  Future<void> deleteGroup(String groupId) async {}

  @override
  Future<List<GroupModel>> getMyGroups() async => [];

  @override
  Future<GroupModel> updateGroup(GroupModel group) async => group;
}

class StubMembershipRepository implements MembershipRepository {
  @override
  Future<void> approveRequest(String requestId, {String? existingPlayerId}) async {}

  @override
  Future<void> demoteToMember({required String groupId, required String playerId}) async {}

  @override
  Future<GroupModel?> findGroupByCode(String code) async => null;

  @override
  Future<List<GroupMemberModel>> getMembers(String groupId) async => [];

  @override
  Future<GroupMemberModel?> getMyMembership(String groupId) async => null;

  @override
  Future<List<Map<String, dynamic>>> listPendingRequests(String groupId) async => [];

  @override
  Future<void> promoteToAdmin({required String groupId, required String playerId}) async {}

  @override
  Future<void> rejectRequest(String requestId) async {}

  @override
  Future<void> requestToJoin({required String inviteCode, required String desiredName}) async {}
}

class StubSeasonsRepository implements SeasonsRepository {
  @override
  Future<SeasonModel> createSeason({required String groupId, required String name, DateTime? startDate, DateTime? endDate, bool isActive = true}) async => throw UnimplementedError();

  @override
  Future<void> deleteSeason({required String groupId, required String seasonId}) async {}

  @override
  Future<SeasonModel?> getCurrentSeason(String groupId) async => null;

  @override
  Future<List<SeasonModel>> getSeasons(String groupId) async => [];

  @override
  Future<SeasonModel> updateSeason(SeasonModel season) async => season;
}

class StubSessionsRepository implements SessionsRepository {
  @override
  Future<SessionModel> createSession(SessionModel session) async => session;

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<SessionModel?> getCachedSession(String sessionId) async => null;

  @override
  Future<Map<String, dynamic>?> getRuntimeState(String sessionId) async => null;

  @override
  Future<SessionModel?> getSessionById(String sessionId) async => null;

  @override
  Future<List<SessionModel>> getSessionsByGroup(String groupId) async => [];

  @override
  Future<void> updateRuntimeState(String sessionId, {bool? isRunning, int? secondsPlayed, int? scoreRed, int? scoreWhite, int? redStreak, int? whiteStreak, bool? isOvertime, DateTime? startedAt, String? status}) async {}

  @override
  Future<SessionModel> updateSession(SessionModel session) async => session;
}

class StubMatchesRepository implements MatchesRepository {
  @override
  Future<void> deleteMatch(String matchId) async {}

  @override
  Future<List<MatchModel>> getMatchesByGroup(String groupId) async => [];

  @override
  Future<List<MatchModel>> getMatchesBySession(String sessionId) async => [];

  @override
  Future<void> savePendingMatch({required String matchId, required Map<String, dynamic> match, required List<Map<String, dynamic>> lineups, required List<Map<String, dynamic>> events, bool isRetry = false}) async {}

  @override
  Future<MatchModel> updatePartialMatch({required String matchId, required int teamAScore, required int teamBScore, required List<MatchEventModel> events}) async => throw UnimplementedError();
}

class StubSessionArrivalsRepository implements SessionArrivalsRepository {
  @override
  Future<List<Map<String, dynamic>>> getArrivals(String sessionId) async => [];

  @override
  Future<Map<String, List<String>>> getPlayerIdsBySessions(List<String> sessionIds) async => {};

  @override
  Future<void> replaceArrivals(String sessionId, List<Map<String, dynamic>> players) async {}
}

class StubActionLogsRepository implements ActionLogsRepository {
  @override
  Future<void> log({required String groupId, required String action, String? targetPlayerId, Map<String, dynamic> details = const {}}) async {}
}

class StubPlayerAccountRepository implements PlayerAccountRepository {
  @override
  Future<List<PlayerModel>> claimGhostProfiles() async => [];

  @override
  Future<List<PlayerModel>> getMyPlayers() async => [];
}

AppServices setupTestAppServices({
  PlayersRepository? players,
  PermissionService? permissions,
  AuthService? auth,
  AppFeatures? features,
  MatchOutbox? outbox,
  PlayerAccountRepository? playerAccounts,
}) {
  final services = AppServices(
    features: features ?? AppFeatures.personal(),
    groups: StubGroupsRepository(),
    members: StubMembershipRepository(),
    seasons: StubSeasonsRepository(),
    players: players ?? StubPlayersRepository(),
    playerAccounts: playerAccounts ?? StubPlayerAccountRepository(),
    sessions: StubSessionsRepository(),
    matches: StubMatchesRepository(),
    sessionArrivals: StubSessionArrivalsRepository(),
    actionLogs: StubActionLogsRepository(),
    auth: auth ?? StubAuthService(),
    permissions: permissions ?? StubPermissionService(),
    outbox: outbox ?? StubMatchOutbox(),
    matchHistory: StubMatchHistoryStore(),
    customBadges: StubCustomBadgesRepository(),
  );
  AppServices.instance = services;
  return services;
}

