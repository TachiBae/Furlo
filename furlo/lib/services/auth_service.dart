import 'package:flutter/foundation.dart';

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
  const AuthResult({required this.user, this.isNewAccount = false});

  final AuthUser user;
  final bool isNewAccount;
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
  unknown,
}

class AuthException implements Exception {
  const AuthException({required this.code});

  final AuthErrorCode code;

  String get message => switch (code) {
    AuthErrorCode.invalidCredentials =>
      'Check your email and password, then try again.',
    AuthErrorCode.userNotFound => 'No account was found for those credentials.',
    AuthErrorCode.emailInUse => 'An account already exists for that email.',
    AuthErrorCode.weakPassword => 'Choose a stronger password and try again.',
    AuthErrorCode.networkError =>
      'Check your internet connection and try again.',
    AuthErrorCode.tooManyRequests =>
      'Too many attempts. Please wait and try again.',
    AuthErrorCode.cancelled => 'Sign-in was cancelled.',
    AuthErrorCode.popupBlocked =>
      'Pop-ups are blocked for this site. Allow them, then try again.',
    AuthErrorCode.unknown => 'Something went wrong. Please try again.',
  };

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
}
