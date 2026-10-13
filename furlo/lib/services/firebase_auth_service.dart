import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../repositories/account_repository.dart';
import 'auth_service.dart';
import 'google_identity_provider.dart';
import 'google_web_identity_stub.dart'
    if (dart.library.js_interop) 'google_web_identity_web.dart';

AuthErrorCode mapFirebaseAuthErrorCode(String code) => switch (code) {
  'invalid-credential' ||
  'wrong-password' ||
  'invalid-email' => AuthErrorCode.invalidCredentials,
  'user-not-found' || 'user-disabled' => AuthErrorCode.userNotFound,
  'email-already-in-use' ||
  'account-exists-with-different-credential' => AuthErrorCode.emailInUse,
  'weak-password' => AuthErrorCode.weakPassword,
  'network-request-failed' => AuthErrorCode.networkError,
  'too-many-requests' => AuthErrorCode.tooManyRequests,
  'popup-closed-by-user' ||
  'cancelled-popup-request' => AuthErrorCode.cancelled,
  'popup-blocked' => AuthErrorCode.popupBlocked,
  'requires-recent-login' => AuthErrorCode.reauthRequired,
  'user-mismatch' => AuthErrorCode.invalidCredentials,
  _ => AuthErrorCode.unknown,
};

/// Maps a credential-link failure to a friendly code, or `null` when the
/// password is already linked and the step should count as done.
///
/// A retry after a half-finished submit must not surface a raw
/// "already linked" failure, so that code is treated as success.
AuthErrorCode? mapLinkPasswordErrorCode(String code) => switch (code) {
  'provider-already-linked' => null,
  'credential-already-in-use' => AuthErrorCode.emailInUse,
  'weak-password' => AuthErrorCode.weakPassword,
  'invalid-credential' ||
  'invalid-verification-code' => AuthErrorCode.invalidCredentials,
  'requires-recent-login' => AuthErrorCode.reauthRequired,
  'too-many-requests' => AuthErrorCode.tooManyRequests,
  'network-request-failed' => AuthErrorCode.networkError,
  _ => AuthErrorCode.unknown,
};

/// Google provider for web sign-in.
///
/// `prompt: select_account` forces Google's account chooser on every tap
/// instead of silently resuming the browser's active session.
GoogleAuthProvider buildGoogleWebAuthProvider() =>
    GoogleAuthProvider()
      ..setCustomParameters(const {'prompt': 'select_account'});

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    FirebaseAuth? auth,
    AccountOnboardingRepository? accountOnboardingRepository,
    AccountProfileRepository? accountProfileRepository,
    GoogleIdentityProvider? googleIdentity,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _accountOnboardingRepository =
           accountOnboardingRepository ??
           FirestoreAccountOnboardingRepository(),
       _accountProfileRepository =
           accountProfileRepository ?? FirestoreAccountProfileRepository(),
       _googleIdentity = googleIdentity ?? GoogleSignInIdentityProvider();

  final FirebaseAuth _auth;
  final AccountOnboardingRepository _accountOnboardingRepository;
  final AccountProfileRepository _accountProfileRepository;
  final GoogleIdentityProvider _googleIdentity;

  @override
  AuthUser? get currentUser =>
      _auth.currentUser == null ? null : _mapUser(_auth.currentUser!);

  @override
  Stream<AuthUser?> get authStateChanges => _auth.authStateChanges().transform(
    StreamTransformer<User?, AuthUser?>.fromHandlers(
      handleData: (user, sink) =>
          sink.add(user == null ? null : _mapUser(user)),
      handleError: (error, stackTrace, sink) {
        if (error is FirebaseAuthException) {
          sink.addError(_mapFirebaseException(error), stackTrace);
        } else {
          sink.addError(error, stackTrace);
        }
      },
    ),
  );

  @override
  Future<void> markNewAccountForFirstPet(String uid) =>
      _accountOnboardingRepository.markFirstPetRequired(uid);

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _requireUser(credential.user);
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  @override
  Future<AuthResult> registerWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = _requireUser(credential.user);
      try {
        await markNewAccountForFirstPet(user.uid);
      } catch (error, stackTrace) {
        // The account exists; sign out and report it as a hand-off so the
        // retry is a sign-in instead of a duplicate registration.
        debugPrint('Account setup could not be recorded: $error\n$stackTrace');
        await _auth.signOut();
        return AuthResult(
          user: user,
          isNewAccount: true,
          setupIncomplete: true,
        );
      }
      return AuthResult(user: user, isNewAccount: true);
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    if (kIsWeb) {
      try {
        final idToken = await _acquireGoogleWebToken();
        if (idToken == null) {
          final credential = await _auth.signInWithPopup(
            buildGoogleWebAuthProvider(),
          );
          return _completeGoogleSignIn(credential);
        }
        final credential = GoogleAuthProvider.credential(idToken: idToken);
        final userCredential = await _auth.signInWithCredential(credential);
        return _completeGoogleSignIn(userCredential);
      } on FirebaseAuthException catch (error) {
        throw _mapFirebaseException(error);
      }
    }

    try {
      final idToken = await acquireGoogleIdToken(_googleIdentity);
      if (idToken == null) {
        throw const AuthException(code: AuthErrorCode.unknown);
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _auth.signInWithCredential(credential);
      return _completeGoogleSignIn(userCredential);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthException(code: AuthErrorCode.cancelled);
      }
      throw const AuthException(code: AuthErrorCode.unknown);
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(code: AuthErrorCode.unknown);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await _googleIdentity.clearSession();
      }
      await _auth.signOut();
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    } on GoogleSignInException {
      throw const AuthException(code: AuthErrorCode.unknown);
    }
  }

  @override
  Future<void> linkPassword(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw const AuthException(code: AuthErrorCode.unknown);
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    try {
      await user.linkWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      final code = mapLinkPasswordErrorCode(error.code);
      // Already linked: the retry of a half-finished submit succeeds.
      if (code == null) return;
      debugPrint('Password link failed: ${error.code}');
      throw AuthException(code: code);
    }
  }

  @override
  Future<void> updateFullName(String fullName) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException(code: AuthErrorCode.unknown);
    try {
      await user.updateDisplayName(fullName);
    } on FirebaseAuthException catch (error) {
      debugPrint('Full-name update failed: ${error.code}');
      throw _mapFirebaseException(error);
    }
  }

  @override
  bool get signsInWithPassword =>
      _auth.currentUser?.providerData.any(
        (info) => info.providerId == EmailAuthProvider.PROVIDER_ID,
      ) ??
      false;

  @override
  Future<void> reauthenticate({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException(code: AuthErrorCode.unknown);
    try {
      final email = user.email;
      if (password != null && signsInWithPassword && email != null) {
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: email, password: password),
        );
        return;
      }
      if (kIsWeb) {
        await user.reauthenticateWithPopup(buildGoogleWebAuthProvider());
        return;
      }
      final idToken = await acquireGoogleIdToken(_googleIdentity);
      if (idToken == null) {
        throw const AuthException(code: AuthErrorCode.cancelled);
      }
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    } on GoogleSignInException catch (error) {
      throw AuthException(
        code: error.code == GoogleSignInExceptionCode.canceled
            ? AuthErrorCode.cancelled
            : AuthErrorCode.unknown,
      );
    }
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException(code: AuthErrorCode.unknown);
    try {
      await user.delete();
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    }
    if (!kIsWeb) {
      try {
        await _googleIdentity.clearSession();
      } catch (_) {
        // The account is already gone; a stale Google session is harmless.
      }
    }
  }

  AuthException _mapFirebaseException(FirebaseAuthException error) {
    final code = mapFirebaseAuthErrorCode(error.code);
    return AuthException(code: code);
  }

  /// In-page Google chooser when available; `null` falls back to the popup.
  ///
  /// A dismissal inside the in-page chooser propagates as a cancelled
  /// [AuthException]; anything else falls back to the popup-window flow.
  Future<String?> _acquireGoogleWebToken() async {
    try {
      return await acquireGoogleWebIdToken();
    } on AuthException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<AuthResult> _completeGoogleSignIn(UserCredential credential) async {
    final user = _requireUser(credential.user);
    final isNewAccount = credential.additionalUserInfo?.isNewUser ?? false;
    if (isNewAccount) {
      try {
        await markNewAccountForFirstPet(user.uid);
      } catch (error, stackTrace) {
        // Never sign a fresh Google account out silently: it keeps its session
        // and the startup flow picks it up.
        debugPrint('Account setup could not be recorded: $error\n$stackTrace');
        return AuthResult(
          user: user,
          isNewAccount: true,
          setupIncomplete: true,
        );
      }
      try {
        await _accountProfileRepository.markProfileRequired(user.uid);
      } catch (error, stackTrace) {
        // Best-effort: a missing marker is treated as an already-complete
        // profile, so it must never block the sign-in.
        debugPrint(
          'Profile requirement could not be recorded: $error\n$stackTrace',
        );
      }
    }
    return AuthResult(user: user, isNewAccount: isNewAccount);
  }

  AuthUser _requireUser(User? user) {
    if (user == null) {
      throw const AuthException(code: AuthErrorCode.unknown);
    }
    return _mapUser(user);
  }

  AuthUser _mapUser(User user) =>
      AuthUser(uid: user.uid, email: user.email, displayName: user.displayName);
}
