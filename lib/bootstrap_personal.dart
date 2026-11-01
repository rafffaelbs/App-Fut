import 'package:flutter/widgets.dart';

import 'app/app_features.dart';
import 'app/app_services.dart';
import 'data/prefs/prefs_custom_badges_repository.dart';
import 'data/prefs/prefs_match_history_store.dart';
import 'data/supabase/action_logs_repository.dart';
import 'data/supabase/group_members_repository.dart';
import 'data/supabase/groups_repository.dart';
import 'data/supabase/matches_repository.dart';
import 'data/supabase/players_repository.dart';
import 'data/supabase/seasons_repository.dart';
import 'data/supabase/session_arrivals_repository.dart';
import 'data/supabase/sessions_repository.dart';
import 'data/supabase/supabase_auth_service.dart';
import 'data/supabase/supabase_config.dart';
import 'data/supabase/supabase_diagnostics_service.dart';
import 'data/supabase/supabase_match_outbox.dart';
import 'data/supabase/supabase_permission_service.dart';
import 'data/supabase/supabase_site_sync_service.dart';

/// Inicializa o Supabase e monta o [AppServices] com as implementações Supabase*.
Future<void> bootstrapPersonal() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();

  final client = SupabaseConfig.client;
  final auth = SupabaseAuthService();
  final permissions = SupabasePermissionService();

  final members = SupabaseGroupMembersRepository(
    client: client,
    permissions: permissions,
  );
  final actionLogs = SupabaseActionLogsRepository(client: client);
  final players = SupabasePlayersRepository(
    client: client,
    permissions: permissions,
    logsRepo: actionLogs,
  );
  final matches = SupabaseMatchesRepository(client: client);
  final outbox = SupabaseMatchOutbox(matchesRepository: matches);
  final diagnostics = SupabaseDiagnosticsService(client: client);
  final siteSync = SupabaseSiteSyncService(
    client: client,
    diagnosticsService: diagnostics,
  );

  final matchHistory = PrefsMatchHistoryStore();
  final customBadges = PrefsCustomBadgesRepository();

  AppServices.instance = AppServices(
    features: const AppFeatures.personal(),
    groups: SupabaseGroupsRepository(client: client, permissions: permissions),
    members: members,
    seasons: SupabaseSeasonsRepository(
      client: client,
      permissions: permissions,
    ),
    players: players,
    playerAccounts: players,
    sessions: SupabaseSessionsRepository(client: client),
    matches: matches,
    sessionArrivals: SupabaseSessionArrivalsRepository(client: client),
    actionLogs: actionLogs,
    auth: auth,
    permissions: permissions,
    outbox: outbox,
    matchHistory: matchHistory,
    customBadges: customBadges,
    siteSync: siteSync,
    diagnostics: diagnostics,
  );
}
