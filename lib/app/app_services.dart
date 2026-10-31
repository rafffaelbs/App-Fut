import '../domain/repositories/action_logs_repository.dart';
import '../domain/repositories/groups_repository.dart';
import '../domain/repositories/matches_repository.dart';
import '../domain/repositories/membership_repository.dart';
import '../domain/repositories/player_account_repository.dart';
import '../domain/repositories/players_repository.dart';
import '../domain/repositories/seasons_repository.dart';
import '../domain/repositories/session_arrivals_repository.dart';
import '../domain/repositories/sessions_repository.dart';
import '../domain/services/auth_service.dart';
import '../domain/services/permission_service.dart';

/// Guarda as implementações ativas (interfaces) do app.
/// Definido uma vez na inicialização (bootstrap_*.dart).
class AppServices {
  AppServices({
    required this.groups,
    required this.members,
    required this.seasons,
    required this.players,
    required this.playerAccounts,
    required this.sessions,
    required this.matches,
    required this.sessionArrivals,
    required this.actionLogs,
    required this.auth,
    required this.permissions,
    this.outbox,
    this.siteSync,
    this.diagnostics,
  });

  static AppServices? _instance;

  static AppServices get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('AppServices.instance não foi inicializado.');
    }
    return i;
  }

  static set instance(AppServices value) => _instance = value;

  final GroupsRepository groups;
  final MembershipRepository members;
  final SeasonsRepository seasons;
  final PlayersRepository players;
  final PlayerAccountRepository playerAccounts;
  final SessionsRepository sessions;
  final MatchesRepository matches;
  final SessionArrivalsRepository sessionArrivals;
  final ActionLogsRepository actionLogs;
  final AuthService auth;
  final PermissionService permissions;

  // Previstos; serão tipados e preenchidos nas tarefas T3c e T3d
  // (MatchOutbox, SiteSyncService, DiagnosticsService).
  final Object? outbox;
  final Object? siteSync;
  final Object? diagnostics;
}
