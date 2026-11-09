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

/// Resultado da inicialização web via token.
class BootstrapWebResult {
  final bool isValid;
  final GroupModel? group;
  final SnapshotSource? snapshotSource;

  const BootstrapWebResult._({
    required this.isValid,
    this.group,
    this.snapshotSource,
  });

  factory BootstrapWebResult.success({
    required GroupModel group,
    required SnapshotSource snapshotSource,
  }) {
    return BootstrapWebResult._(
      isValid: true,
      group: group,
      snapshotSource: snapshotSource,
    );
  }

  factory BootstrapWebResult.invalid() {
    return const BootstrapWebResult._(isValid: false);
  }
}

/// Extrai o token de compartilhamento a partir da URL.
///
/// Formato preferencial: `https://<site>/#/g/<token>` (Uri.fragment: `/g/<token>` ou `g/<token>`).
/// Fallback: rota direta `https://<site>/g/<token>` (Uri.pathSegments: `['g', '<token>']`).
String? extractTokenFromUrl(Uri uri) {
  final fragment = uri.fragment.trim();
  if (fragment.isNotEmpty) {
    var clean = fragment.startsWith('/') ? fragment.substring(1) : fragment;
    if (clean.contains('?')) {
      clean = clean.split('?').first;
    }
    final parts = clean.split('/');
    if (parts.length >= 2 && parts[0] == 'g' && parts[1].isNotEmpty) {
      return parts[1];
    }
  }

  final segments = uri.pathSegments;
  if (segments.length >= 2 && segments[0] == 'g' && segments[1].isNotEmpty) {
    var token = segments[1];
    if (token.contains('?')) {
      token = token.split('?').first;
    }
    return token;
  }

  return null;
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
  } catch (e) {
    debugPrint('Aviso ao inicializar SupabaseConfig: $e');
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

    final group = GroupModel.fromMap(groupData);
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
  } catch (e) {
    debugPrint('Erro ao inicializar bootstrapWeb com token: $e');
    return BootstrapWebResult.invalid();
  }
}
