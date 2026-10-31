import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/supabase/supabase_config.dart';
import '../domain/services/auth_service.dart';
import '../domain/services/permission_service.dart';
import '../data/supabase/supabase_auth_service.dart';
import '../data/supabase/supabase_permission_service.dart';
import '../data/supabase/groups_repository.dart';
import '../data/supabase/players_repository.dart';
import '../data/supabase/group_members_repository.dart';
import '../data/supabase/matches_repository.dart';
import '../data/supabase/ratings_repository.dart';
import '../data/supabase/sessions_repository.dart';
import '../data/supabase/seasons_repository.dart';
import '../data/supabase/session_arrivals_repository.dart';
import '../data/supabase/action_logs_repository.dart';

/// Central service for Supabase integration.
class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();

  factory SupabaseService() => instance;

  static final AuthService auth = SupabaseAuthService();
  static final PermissionService permissions = SupabasePermissionService();

  SupabaseService._internal() {
    client = SupabaseConfig.client;

    // Initialize repositories
    groupMembers = SupabaseGroupMembersRepository(client: client, permissions: permissions);
    actionLogs = SupabaseActionLogsRepository(client: client);
    players = SupabasePlayersRepository(client: client, permissions: permissions, logsRepo: actionLogs);
    groups = SupabaseGroupsRepository(client: client, permissions: permissions);
    seasons = SupabaseSeasonsRepository(client: client, permissions: permissions);
    sessions = SupabaseSessionsRepository(client: client);
    matches = SupabaseMatchesRepository(client: client);
    ratings = SupabaseRatingsRepository(client: client);
    sessionArrivals = SupabaseSessionArrivalsRepository(client: client);
  }

  late final SupabaseClient client;

  late final SupabaseGroupMembersRepository groupMembers;
  late final SupabaseGroupsRepository groups;
  late final SupabaseSeasonsRepository seasons;
  late final SupabasePlayersRepository players;
  late final SupabaseSessionsRepository sessions;
  late final SupabaseMatchesRepository matches;
  late final SupabaseRatingsRepository ratings;
  late final SupabaseSessionArrivalsRepository sessionArrivals;
  late final SupabaseActionLogsRepository actionLogs;
}
