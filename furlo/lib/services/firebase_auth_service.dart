import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import 'account_onboarding_repository.dart';
import 'auth_service.dart';
import 'google_identity_provider.dart';

AuthErrorCode mapFirebaseAuthErrorCode(String code) => switch (code) {
  'invalid-credential' ||
  'wrong-password' ||
  'invalid-email' => AuthErrorCode.invalidCredentials,
  'user-not-found' ||
  'user-disabled' => AuthErrorCode.userNotFound,
  'email-already-in-use' ||
  'account-exists-with-different-credential' => AuthErrorCode.emailInUse,
  'weak-password' => AuthErrorCode.weakPassword,
  'network-request-failed' => AuthErrorCode.networkError,
  'too-many-requests' => AuthErrorCode.tooManyRequests,
  'popup-closed-by-user' ||
  'cancelled-popup-request' => AuthErrorCode.cancelled,
  'popup-blocked' => AuthErrorCode.popupBlocked,
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
    GoogleIdentityProvider? googleIdentity,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _accountOnboardingRepository =
           accountOnboardingRepository ??
           FirestoreAccountOnboardingRepository(),
       _googleIdentity = googleIdentity ?? GoogleSignInIdentityProvider();

  final FirebaseAuth _auth;
  final AccountOnboardingRepository _accountOnboardingRepository;
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
      } catch (_) {
        await _auth.signOut();
        throw const AuthException(code: AuthErrorCode.networkError);
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
        final credential = await _auth.signInWithPopup(
          buildGoogleWebAuthProvider(),
        );
        final user = _requireUser(credential.user);
        final isNewAccount = credential.additionalUserInfo?.isNewUser ?? false;
        if (isNewAccount) {
          try {
            await markNewAccountForFirstPet(user.uid);
          } catch (_) {
            await _auth.signOut();
            throw const AuthException(code: AuthErrorCode.networkError);
          }
        }
        return AuthResult(user: user, isNewAccount: isNewAccount);
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
      final user = _requireUser(userCredential.user);
      final isNewAccount =
          userCredential.additionalUserInfo?.isNewUser ?? false;
      if (isNewAccount) {
        try {
          await markNewAccountForFirstPet(user.uid);
        } catch (_) {
          await _auth.signOut();
          throw const AuthException(code: AuthErrorCode.networkError);
        }
      }
      return AuthResult(user: user, isNewAccount: isNewAccount);
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

  AuthException _mapFirebaseException(FirebaseAuthException error) {
    final code = mapFirebaseAuthErrorCode(error.code);
    return AuthException(code: code);
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
