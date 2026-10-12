enum AuthEvent { signedIn, signedOut, passwordRecovery, other }

class SignUpResult {
  /// True when email confirmation is required before the user can sign in.
  final bool needsVerification;
  /// True when Supabase returned its empty-identities duplicate-email result.
  final bool alreadyRegistered;
  const SignUpResult({
    required this.needsVerification,
    this.alreadyRegistered = false,
  });
}

class SecurityActionTicket {
  final String email;
  final String value;
  const SecurityActionTicket({required this.email, required this.value});
}

abstract class AuthRepository {
  /// Synchronous snapshot — used by the router so a cold start doesn't
  /// flash the login screen while the auth stream warms up.
  bool get isSignedIn;
  Stream<bool> watchIsSignedIn();
  Stream<AuthEvent> watchAuthEvents();

  String? get currentUserId;
  String? get currentUserEmail;

  Future<SignUpResult> signUp(
      {required String email,
      required String password,
      required String displayName});
  Future<void> signIn({required String email, required String password});

  /// Returns false if the user simply cancelled the Google picker
  /// (which is silent — no error message).
  Future<bool> signInWithGoogle();

  Future<void> signOut();
  Future<void> resendVerification(String email);
  Future<void> requestSecurityCode({required String action, String? email});
  Future<SecurityActionTicket> verifySecurityCode({
    required String action,
    required String code,
    String? email,
  });
  Future<void> completeVerifiedAction({
    required String action,
    required String email,
    required String ticket,
    String? newPassword,
    String? currentPassword,
  });
}
