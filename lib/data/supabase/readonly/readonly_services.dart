import 'package:flutter/foundation.dart';
import '../../../domain/repositories/action_logs_repository.dart';
import '../../../domain/repositories/custom_badges_repository.dart';
import '../../../domain/repositories/match_history_store.dart';
import '../../../domain/services/auth_service.dart';
import '../../../domain/services/match_outbox.dart';
import '../../../domain/services/permission_service.dart';

class NullAuthService implements AuthService {
  const NullAuthService();

  @override
  String? get currentUserId => null;

  @override
  String? get currentUserEmail => null;

  @override
  bool get isSignedIn => false;

  @override
  Stream<bool> get signedInChanges => const Stream.empty();

  @override
  Future<void> signIn(String email, String password) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<void> signUp(String email, String password) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<void> signOut() async {}
}

class ReadonlyPermissionService implements PermissionService {
  const ReadonlyPermissionService();

  @override
  Future<bool> isAdmin(String groupId) async => false;

  @override
  Future<void> requireAdmin(String groupId, [String? message]) async {
    throw Exception(message ?? 'Acesso negado: somente administradores.');
  }
}

class ReadonlyMatchOutbox implements MatchOutbox {
  final ValueNotifier<int> _pending = ValueNotifier<int>(0);
  final ValueNotifier<int> _failed = ValueNotifier<int>(0);
  final ValueNotifier<String?> _lastError = ValueNotifier<String?>(null);

  @override
  ValueListenable<int> get pending => _pending;

  @override
  ValueListenable<int> get failed => _failed;

  @override
  ValueListenable<String?> get lastError => _lastError;

  @override
  Future<void> enqueue(Map<String, dynamic> job) {
    throw UnsupportedError('Site somente leitura');
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> refreshCounts() async {}

  @override
  Future<List<Map<String, dynamic>>> failedJobs() async => const [];

  @override
  Future<void> retryFailed(String matchId) async {}

  @override
  Future<void> discardFailed(String matchId) async {}
}

class EmptyMatchHistoryStore implements MatchHistoryStore {
  const EmptyMatchHistoryStore();

  @override
  Future<bool> hasSession(String sessionId) async => false;

  @override
  Future<List<Map<String, dynamic>>> readSession(String sessionId) async => const [];

  @override
  Future<void> appendToSession(String sessionId, Map<String, dynamic> record) {
    throw UnsupportedError('Site somente leitura');
  }
}

class EmptyCustomBadgesRepository implements CustomBadgesRepository {
  const EmptyCustomBadgesRepository();

  @override
  Future<bool> hasCustomBadges(String groupId) async => false;

  @override
  Future<List<Map<String, dynamic>>> getCustomBadges(String groupId) async => const [];

  @override
  Future<void> saveCustomBadges(String groupId, List<Map<String, dynamic>> badges) {
    throw UnsupportedError('Site somente leitura');
  }
}

class NoopActionLogsRepository implements ActionLogsRepository {
  const NoopActionLogsRepository();

  @override
  Future<void> log({
    required String groupId,
    required String action,
    String? targetPlayerId,
    Map<String, dynamic> details = const {},
  }) async {}
}
