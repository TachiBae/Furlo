import 'package:flutter/foundation.dart';

import '../utils/app_copy.dart';

@immutable
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    required this.displayName,
  });

  final String uid;
  final String? email;
  final String? displayName;
}

class AuthResult {
  const AuthResult({
    required this.user,
    this.isNewAccount = false,
    this.setupIncomplete = false,
  });

  final AuthUser user;
  final bool isNewAccount;

  /// True when the account itself was created but the first-pet setup write
  /// failed.
  ///
  /// The account exists and the user is signed in, so callers must finish with
  /// a friendly hand-off rather than treating this as a sign-in failure.
  final bool setupIncomplete;
}

enum AuthErrorCode {
  invalidCredentials,
  userNotFound,
  emailInUse,
  weakPassword,
  networkError,
  tooManyRequests,
  cancelled,
  popupBlocked,
  reauthRequired,
  unknown,
}

/// The single source of user-facing copy for an auth failure.
///
/// Lives beside [AuthErrorCode] so the code and its copy cannot drift. The UI
/// helper in `utils/auth_error_messages.dart` delegates here instead of keeping
/// a second copy of this table.
String authErrorText(AuthErrorCode code) => switch (code) {
  AuthErrorCode.invalidCredentials =>
    'Check your email and password, then try again.',
  AuthErrorCode.userNotFound => 'No account was found for those credentials.',
  AuthErrorCode.emailInUse => 'An account already exists for that email.',
  AuthErrorCode.weakPassword => 'Choose a stronger password and try again.',
  // One wording for "check the connection" across auth and data loads.
  AuthErrorCode.networkError => AppCopy.checkConnection,
  AuthErrorCode.tooManyRequests =>
    'Too many attempts. Please wait and try again.',
  AuthErrorCode.cancelled => 'Sign-in was cancelled.',
  AuthErrorCode.popupBlocked =>
    'Pop-ups are blocked for this site. Allow them, then try again.',
  AuthErrorCode.reauthRequired =>
    'For your security, please sign in again, then try once more.',
  AuthErrorCode.unknown => 'Something went wrong. Please try again.',
};

class AuthException implements Exception {
  const AuthException({required this.code});

  final AuthErrorCode code;

  String get message => authErrorText(code);

  @override
  String toString() => 'AuthException: $message';
}

abstract interface class AuthService {
  AuthUser? get currentUser;
  Stream<AuthUser?> get authStateChanges;

  Future<void> markNewAccountForFirstPet(String uid);
  Future<AuthUser> signInWithEmail(String email, String password);
  Future<AuthResult> registerWithEmail(String email, String password);
  Future<AuthResult> signInWithGoogle();
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();

  /// Links an email+password credential to the signed-in account so it can
  /// also be opened by email. Idempotent: a password that is already linked
  /// is reported as success.
  Future<void> linkPassword(String password);

  /// Sets the account's full name as held by the auth provider.
  Future<void> updateFullName(String fullName);

  /// Whether the signed-in account can confirm with a password (otherwise
  /// it confirms with Google).
  bool get signsInWithPassword;

  /// Confirms the signed-in person again, as Firebase requires before
  /// sensitive changes. Uses [password] for password accounts, else Google.
  Future<void> reauthenticate({String? password});

  /// Deletes the signed-in account itself. Call [reauthenticate] first.
  Future<void> deleteAccount();
}
