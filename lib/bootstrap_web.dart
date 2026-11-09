import 'package:flutter/widgets.dart';

import 'app/app_features.dart';
import 'app/app_services.dart';
import 'data/supabase/readonly/readonly_services.dart';
import 'data/supabase/readonly/snapshot_source.dart';
import 'data/supabase/readonly/token_groups_repository.dart';
import 'data/supabase/readonly/token_matches_repository.dart';
import 'data/supabase/readonly/token_membership_repository.dart';
import 'data/supabase/readonly/token_players_repository.dart';
import 'data/supabase/readonly/token_seasons_repository.dart';
import 'data/supabase/readonly/token_session_arrivals_repository.dart';
import 'data/supabase/readonly/token_sessions_repository.dart';
import 'data/supabase/supabase_config.dart';
import 'models/group_model.dart';

/// Status do resultado da inicialização web.
enum BootstrapWebStatus {
  success,
  invalidLink,
  connectionError,
}

/// Resultado da inicialização web via token.
class BootstrapWebResult {
  final BootstrapWebStatus status;
  final GroupModel? group;
  final SnapshotSource? snapshotSource;

  const BootstrapWebResult._({
    required this.status,
    this.group,
    this.snapshotSource,
  });

  bool get isSuccess => status == BootstrapWebStatus.success;
  bool get isInvalidLink => status == BootstrapWebStatus.invalidLink;
  bool get isConnectionError => status == BootstrapWebStatus.connectionError;

  /// Compatibilidade com checagens booleanas legadas.
  bool get isValid => isSuccess;

  factory BootstrapWebResult.success({
    required GroupModel group,
    required SnapshotSource snapshotSource,
  }) {
    return BootstrapWebResult._(
      status: BootstrapWebStatus.success,
      group: group,
      snapshotSource: snapshotSource,
    );
  }

  factory BootstrapWebResult.invalid() {
    return const BootstrapWebResult._(status: BootstrapWebStatus.invalidLink);
  }

  factory BootstrapWebResult.connectionError() {
    return const BootstrapWebResult._(
      status: BootstrapWebStatus.connectionError,
    );
  }
}

/// Extrai o token de compartilhamento a partir da URL.
///
/// Aceita estritamente o fragmento `#/g/<token>`.
String? extractTokenFromUrl(Uri uri) {
  final fragment = uri.fragment.trim();
  if (fragment.isEmpty) return null;

  var clean = fragment.startsWith('/') ? fragment.substring(1) : fragment;
  if (!clean.startsWith('g/')) return null;

  var token = clean.substring(2);
  if (token.contains('?')) {
    token = token.split('?').first;
  }
  if (token.contains('/')) {
    token = token.split('/').first;
  }
  token = token.trim();
  return token.isNotEmpty ? token : null;
}

/// Inicializa o Supabase, lê o token, carrega o snapshot e monta o [AppServices].
Future<BootstrapWebResult> bootstrapWeb({
  String? tokenOverride,
  SnapshotSource? snapshotSourceOverride,
  bool initializeFlutterBinding = true,
}) async {
  if (initializeFlutterBinding) {
    WidgetsFlutterBinding.ensureInitialized();
  }

  try {
    await SupabaseConfig.initialize();
  } catch (_) {
    debugPrint('Aviso ao inicializar SupabaseConfig.');
  }

  final token = tokenOverride ?? extractTokenFromUrl(Uri.base);
  if (token == null || token.trim().isEmpty) {
    return BootstrapWebResult.invalid();
  }

  try {
    final source = snapshotSourceOverride ??
        SnapshotSource(
          client: SupabaseConfig.client,
          token: token.trim(),
        );

    await source.load();

    final groupData = source.group;
    if (groupData == null) {
      return BootstrapWebResult.invalid();
    }

    final group = source.cachedGroup ?? GroupModel.fromMap(groupData);
    final tokenPlayers = TokenPlayersRepository(source);

    AppServices.instance = AppServices(
      features: const AppFeatures.webReadonly(),
      groups: TokenGroupsRepository(source),
      members: TokenMembershipRepository(source),
      seasons: TokenSeasonsRepository(source),
      players: tokenPlayers,
      playerAccounts: tokenPlayers,
      sessions: TokenSessionsRepository(source),
      matches: TokenMatchesRepository(source),
      sessionArrivals: const TokenSessionArrivalsRepository(),
      actionLogs: const NoopActionLogsRepository(),
      auth: const NullAuthService(),
      permissions: const ReadonlyPermissionService(),
      outbox: ReadonlyMatchOutbox(),
      matchHistory: const EmptyMatchHistoryStore(),
      customBadges: const EmptyCustomBadgesRepository(),
      siteSync: null,
      diagnostics: null,
    );

    return BootstrapWebResult.success(
      group: group,
      snapshotSource: source,
    );
  } on InvalidLinkException {
    debugPrint('Token inválido ou link desativado.');
    return BootstrapWebResult.invalid();
  } catch (_) {
    debugPrint('Falha ao inicializar bootstrapWeb.');
    return BootstrapWebResult.connectionError();
  }
}
