import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../domain/services/auth_service.dart';
import '../domain/services/permission_service.dart';
import '../data/supabase/supabase_auth_service.dart';
import '../data/supabase/supabase_permission_service.dart';
import 'groups_repository.dart';
import 'players_repository.dart';
import 'group_members_repository.dart';
import 'matches_repository.dart';
import 'ratings_repository.dart';
import 'sessions_repository.dart';
import 'seasons_repository.dart';
import 'session_arrivals_repository.dart';
import 'action_logs_repository.dart';

/// Central service for Supabase integration.
class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();

  factory SupabaseService() => instance;

  static final AuthService auth = SupabaseAuthService();
  static final PermissionService permissions = SupabasePermissionService();

  SupabaseService._internal() {
    client = SupabaseConfig.client;

    // Initialize repositories
    groupMembers = GroupMembersRepository(client: client, permissions: permissions);
    actionLogs = ActionLogsRepository(client: client);
    players = PlayersRepository(client: client, permissions: permissions, logsRepo: actionLogs);
    groups = GroupsRepository(client: client, permissions: permissions);
    seasons = SeasonsRepository(client: client, permissions: permissions);
    sessions = SessionsRepository(client: client);
    matches = MatchesRepository(client: client);
    ratings = RatingsRepository(client: client);
    sessionArrivals = SessionArrivalsRepository(client: client);
  }

  late final SupabaseClient client;

  late final GroupMembersRepository groupMembers;
  late final GroupsRepository groups;
  late final SeasonsRepository seasons;
  late final PlayersRepository players;
  late final SessionsRepository sessions;
  late final MatchesRepository matches;
  late final RatingsRepository ratings;
  late final SessionArrivalsRepository sessionArrivals;
  late final ActionLogsRepository actionLogs;
}
