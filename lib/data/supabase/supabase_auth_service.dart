import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../domain/services/auth_service.dart';

class SupabaseAuthService implements AuthService {
  final SupabaseClient? _providedClient;

  SupabaseAuthService({SupabaseClient? client}) : _providedClient = client;

  SupabaseClient get _client => _providedClient ?? SupabaseConfig.client;

  User? get currentUser => _client.auth.currentUser;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  Stream<bool> get signedInChanges => _client.auth.onAuthStateChange
      .map((data) => data.session != null)
      .distinct();

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on AuthException catch (e) {
      throw AppAuthException(e.message);
    }
  }

  @override
  Future<void> signUp(String email, String password) async {
    try {
      await _client.auth.signUp(
        email: email.trim(),
        password: password.trim(),
      );
    } on AuthException catch (e) {
      throw AppAuthException(e.message);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw AppAuthException(e.message);
    }
  }
}
