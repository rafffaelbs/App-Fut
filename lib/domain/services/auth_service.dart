class AppAuthException implements Exception {
  final String message;

  const AppAuthException(this.message);

  @override
  String toString() => message;
}

abstract class AuthService {
  String? get currentUserId;
  String? get currentUserEmail;
  bool get isSignedIn;
  Stream<bool> get signedInChanges;
  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password);
  Future<void> signOut();
}
