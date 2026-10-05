import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_service.dart';

AuthErrorCode mapFirebaseAuthErrorCode(String code) => switch (code) {
  'invalid-credential' ||
  'wrong-password' ||
  'invalid-email' => AuthErrorCode.invalidCredentials,
  'user-not-found' => AuthErrorCode.userNotFound,
  'email-already-in-use' => AuthErrorCode.emailInUse,
  'weak-password' => AuthErrorCode.weakPassword,
  'network-request-failed' => AuthErrorCode.networkError,
  'too-many-requests' => AuthErrorCode.tooManyRequests,
  'popup-closed-by-user' ||
  'cancelled-popup-request' => AuthErrorCode.cancelled,
  _ => AuthErrorCode.unknown,
};

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  static Future<void>? _googleSignInInitialization;

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
  Future<AuthUser> registerWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _requireUser(credential.user);
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    }
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    if (kIsWeb) {
      try {
        final credential = await _auth.signInWithPopup(GoogleAuthProvider());
        return _requireUser(credential.user);
      } on FirebaseAuthException catch (error) {
        throw _mapFirebaseException(error);
      }
    }

    try {
      final google = GoogleSignIn.instance;
      await _initializeGoogleSignIn();
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthException(code: AuthErrorCode.unknown);
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _auth.signInWithCredential(credential);
      return _requireUser(userCredential.user);
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
        await _initializeGoogleSignIn();
        await GoogleSignIn.instance.signOut();
      }
      await _auth.signOut();
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    } on GoogleSignInException {
      throw const AuthException(code: AuthErrorCode.unknown);
    }
  }

  Future<void> _initializeGoogleSignIn() =>
      _googleSignInInitialization ??= GoogleSignIn.instance.initialize();

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
