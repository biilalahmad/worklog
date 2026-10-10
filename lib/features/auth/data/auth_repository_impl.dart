import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/errors/failure.dart';
import '../domain/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _client;
  AuthRepositoryImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  Stream<bool> watchIsSignedIn() {
    return _client.auth.onAuthStateChange.map((event) => event.session != null);
  }

  @override
  Stream<AuthEvent> watchAuthEvents() {
    return _client.auth.onAuthStateChange.map((state) {
      switch (state.event) {
        case AuthChangeEvent.signedIn:
          return AuthEvent.signedIn;
        case AuthChangeEvent.signedOut:
          return AuthEvent.signedOut;
        case AuthChangeEvent.passwordRecovery:
          return AuthEvent.passwordRecovery;
        default:
          return AuthEvent.other;
      }
    });
  }

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  String? get currentUserEmail => _client.auth.currentUser?.email;

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
      emailRedirectTo: SupabaseConfig.verificationRedirect,
    );
    // With email confirmation ON, Supabase does not error for an
    // already-registered address (anti-enumeration) — it returns a
    // user with an empty identities list. Surface the friendly message.
    final identities = res.user?.identities;
    if (res.user != null && identities != null && identities.isEmpty) {
      throw const Failure(
        'An account with this email already exists. Try logging in instead.',
        code: Failure.codeConflict,
      );
    }
    return SignUpResult(needsVerification: res.session == null);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<bool> signInWithGoogle() async {
    final google = GoogleSignIn(
      serverClientId: SupabaseConfig.googleWebClientId,
    );
    final account = await google.signIn();
    if (account == null) return false; // user cancelled — stay silent
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw const Failure('Google sign-in failed. Please try again.');
    }
    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: auth.accessToken,
    );
    return true;
  }

  @override
  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // Not signed in with Google (or plugin unavailable) — ignore.
    }
    await _client.auth.signOut();
  }

  @override
  Future<void> resendVerification(String email) {
    return _client.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: SupabaseConfig.verificationRedirect,
    );
  }

  @override
  Future<void> requestSecurityCode(
      {required String action, String? email}) async {
    await _invokeSecurity({
      'operation': 'request_code',
      'action': action,
      if (email != null) 'email': email.trim(),
    });
  }

  @override
  Future<SecurityActionTicket> verifySecurityCode({
    required String action,
    required String code,
    String? email,
  }) async {
    final result = await _invokeSecurity({
      'operation': 'verify_code',
      'action': action,
      'code': code.trim(),
      if (email != null) 'email': email.trim(),
    });
    final responseEmail = result['email'];
    final ticket = result['ticket'];
    if (responseEmail is! String || ticket is! String || ticket.length != 72) {
      throw const Failure(
          'The code could not be verified. Request a new code and try again.');
    }
    return SecurityActionTicket(email: responseEmail, value: ticket);
  }

  @override
  Future<void> completeVerifiedAction({
    required String action,
    required String email,
    required String ticket,
    String? newPassword,
    String? currentPassword,
  }) async {
    await _invokeSecurity({
      'operation': 'complete_action',
      'action': action,
      'email': email,
      'ticket': ticket,
      if (newPassword != null) 'newPassword': newPassword,
      if (currentPassword != null) 'currentPassword': currentPassword,
    });
    if (action == 'delete_account') {
      try {
        await _client.auth.signOut(scope: SignOutScope.local);
      } catch (_) {
        // Remote deletion succeeded; local cleanup must not turn that into a
        // retryable failure or send the user back to the verification step.
      }
      try {
        await GoogleSignIn().signOut();
      } catch (_) {
        // The account may not have been signed in with Google.
      }
    }
  }

  Future<Map<String, dynamic>> _invokeSecurity(
      Map<String, dynamic> body) async {
    try {
      final result =
          await _client.functions.invoke('account-security', body: body);
      final rawData = result.data;
      if (rawData is! Map) {
        throw const Failure(
            'The security request returned an invalid response.');
      }
      final data = Map<String, dynamic>.from(rawData);
      final errorCode = data['error'];
      if (errorCode is String) {
        throw Failure(_securityMessage(errorCode), code: errorCode);
      }
      return data;
    } on FunctionException catch (error) {
      final details = error.details;
      final detailMap = details is Map
          ? details
          : details is String
              ? _decodeFunctionDetails(details)
              : null;
      final errorCode = detailMap?['error'];
      if (errorCode is String) {
        throw Failure(_securityMessage(errorCode), code: errorCode);
      }
      if (error.status == 429) {
        throw const Failure(
          Failure.tooManyRequests,
          code: Failure.codeRateLimited,
        );
      }
      throw Failure.from(error);
    }
  }

  Map<String, dynamic>? _decodeFunctionDetails(String details) {
    try {
      final decoded = jsonDecode(details);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  String _securityMessage(String code) => switch (code) {
        'invalid_or_expired_code' =>
          'That code is incorrect, expired, or already used. Request a new code and try again.',
        'code_request_failed' =>
          'We couldn’t send your code right now. Please try again shortly.',
        'rate_limited' => Failure.tooManyRequests,
        'password_reset_request_limit' =>
          'You’ve reached the limit of 7 password reset code requests in 24 hours. Please try again tomorrow.',
        'password_change_request_limit' =>
          'You’ve reached the limit of 7 password-change code requests in 24 hours. Please try again tomorrow.',
        'delete_account_request_limit' =>
          'You’ve reached the limit of 7 account-deletion code requests in 24 hours. Please try again tomorrow.',
        'password_change_limit' =>
          'You’ve reached the limit of 7 password changes in 24 hours. Please try again tomorrow.',
        'authentication_required' =>
          'Please sign in again before changing or deleting your account.',
        'password_policy' =>
          'Use at least 8 characters with one letter and one number (maximum 128 characters).',
        'password_reuse' =>
          'Your new password must be different from your current password.',
        'invalid_current_password' => 'That current password is not correct.',
        'password_verification_unavailable' =>
          'We couldn’t verify your current password right now. Please try again shortly.',
        'account_action_failed' =>
          'The account change could not be completed. Request a new code and try again.',
        _ => 'We couldn’t complete that security request. Please try again.',
      };
}
