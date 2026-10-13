import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:furlo/services/account_onboarding_repository.dart';
import 'package:furlo/services/auth_service.dart';

class FakeAuthService implements AuthService {
  FakeAuthService({
    AuthUser? initialUser,
    this._accountOnboardingRepository,
    this._accountProfileRepository,
  }) : _user = initialUser;

  AuthUser? _user;
  final AccountOnboardingRepository? _accountOnboardingRepository;
  final AccountProfileRepository? _accountProfileRepository;
  final StreamController<AuthUser?> _changes =
      StreamController<AuthUser?>.broadcast(sync: true);
  AuthException? _nextSignInException;
  Object? _nextUnhandledSignInError;
  AuthException? _nextRegisterException;
  AuthException? _nextGoogleException;
  AuthException? _nextResetException;
  AuthException? _nextSignOutException;
  AuthException? _nextLinkPasswordException;
  AuthException? _nextUpdateFullNameException;
  Future<void> Function()? _beforeSignIn;
  Future<void> Function()? _beforeRegister;
  Future<void> Function()? _beforeGoogle;
  Future<void> Function()? _beforeReset;
  Future<void> Function()? _beforeSignOut;
  bool googleCreatesNewAccount = true;

  /// True once [linkPassword] has succeeded, mirroring a linked account.
  bool passwordLinked = false;

  final List<String> calls = [];

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> get authStateChanges =>
      Stream<AuthUser?>.multi((controller) {
        controller.add(_user);
        final subscription = _changes.stream.listen(controller.add);
        controller.onCancel = subscription.cancel;
      });

  @override
  Future<void> markNewAccountForFirstPet(String uid) async {
    await _accountOnboardingRepository?.markFirstPetRequired(uid);
  }

  void setUser(AuthUser? user) {
    _user = user;
    _changes.add(user);
  }

  void failNextSignIn(AuthException exception) {
    _nextSignInException = exception;
  }

  void failNextSignInWith(Object error) {
    _nextUnhandledSignInError = error;
  }

  void failNextRegister(AuthException exception) {
    _nextRegisterException = exception;
  }

  void failNextGoogleSignIn(AuthException exception) {
    _nextGoogleException = exception;
  }

  void failNextPasswordReset(AuthException exception) {
    _nextResetException = exception;
  }

  void failNextSignOut(AuthException exception) {
    _nextSignOutException = exception;
  }

  void failNextLinkPassword(AuthException exception) {
    _nextLinkPasswordException = exception;
  }

  void failNextUpdateFullName(AuthException exception) {
    _nextUpdateFullNameException = exception;
  }

  void beforeNextSignIn(Future<void> Function() callback) {
    _beforeSignIn = callback;
  }

  void beforeNextRegister(Future<void> Function() callback) {
    _beforeRegister = callback;
  }

  void beforeNextGoogle(Future<void> Function() callback) {
    _beforeGoogle = callback;
  }

  void beforeNextReset(Future<void> Function() callback) {
    _beforeReset = callback;
  }

  void beforeNextSignOut(Future<void> Function() callback) {
    _beforeSignOut = callback;
  }

  Future<void> _runBefore(Future<void> Function()? callback) async {
    await callback?.call();
  }

  /// Mirrors `FirebaseAuthService`: a failed first-pet write is logged and
  /// reported as [AuthResult.setupIncomplete] instead of an error.
  Future<bool> _recordFirstPet(String uid) async {
    try {
      await markNewAccountForFirstPet(uid);
      return false;
    } catch (error, stackTrace) {
      debugPrint('Account setup could not be recorded: $error\n$stackTrace');
      return true;
    }
  }

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    calls.add('signInWithEmail');
    final before = _beforeSignIn;
    _beforeSignIn = null;
    await _runBefore(before);
    final failure = _nextSignInException;
    _nextSignInException = null;
    if (failure != null) throw failure;
    final unhandledError = _nextUnhandledSignInError;
    _nextUnhandledSignInError = null;
    if (unhandledError != null) throw unhandledError;
    final user = AuthUser(uid: 'fake-user', email: email, displayName: null);
    setUser(user);
    return user;
  }

  @override
  Future<AuthResult> registerWithEmail(String email, String password) async {
    calls.add('registerWithEmail');
    final before = _beforeRegister;
    _beforeRegister = null;
    await _runBefore(before);
    final failure = _nextRegisterException;
    _nextRegisterException = null;
    if (failure != null) throw failure;
    final user = AuthUser(uid: 'fake-user', email: email, displayName: null);
    setUser(user);
    final setupIncomplete = await _recordFirstPet(user.uid);
    return AuthResult(
      user: user,
      isNewAccount: true,
      setupIncomplete: setupIncomplete,
    );
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    calls.add('signInWithGoogle');
    final before = _beforeGoogle;
    _beforeGoogle = null;
    await _runBefore(before);
    final failure = _nextGoogleException;
    _nextGoogleException = null;
    if (failure != null) throw failure;
    final user = AuthUser(
      uid: 'fake-google-user',
      email: null,
      displayName: null,
    );
    setUser(user);
    var setupIncomplete = false;
    if (googleCreatesNewAccount) {
      setupIncomplete = await _recordFirstPet(user.uid);
      await _accountProfileRepository?.markProfileRequired(user.uid);
    }
    return AuthResult(
      user: user,
      isNewAccount: googleCreatesNewAccount,
      setupIncomplete: setupIncomplete,
    );
  }

  @override
  Future<void> linkPassword(String password) async {
    calls.add('linkPassword');
    final failure = _nextLinkPasswordException;
    _nextLinkPasswordException = null;
    if (failure != null) throw failure;
    // Mirrors the real service: linking a password that is already linked is a
    // success, so a retried submit never fails on "already linked".
    passwordLinked = true;
  }

  @override
  Future<void> updateFullName(String fullName) async {
    calls.add('updateFullName');
    final failure = _nextUpdateFullNameException;
    _nextUpdateFullNameException = null;
    if (failure != null) throw failure;
    final user = _user;
    if (user != null) {
      _user = AuthUser(uid: user.uid, email: user.email, displayName: fullName);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    calls.add('sendPasswordReset');
    final before = _beforeReset;
    _beforeReset = null;
    await _runBefore(before);
    final failure = _nextResetException;
    _nextResetException = null;
    if (failure != null) throw failure;
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    final before = _beforeSignOut;
    _beforeSignOut = null;
    await _runBefore(before);
    final failure = _nextSignOutException;
    _nextSignOutException = null;
    if (failure != null) throw failure;
    setUser(null);
  }

  /// Password the fake accepts in [reauthenticate]; null accepts any.
  String? acceptedPassword;
  bool passwordAccount = true;
  AuthException? nextDeleteException;

  @override
  bool get signsInWithPassword => passwordAccount;

  @override
  Future<void> reauthenticate({String? password}) async {
    calls.add('reauthenticate');
    if (passwordAccount &&
        acceptedPassword != null &&
        password != acceptedPassword) {
      throw const AuthException(code: AuthErrorCode.invalidCredentials);
    }
  }

  @override
  Future<void> deleteAccount() async {
    calls.add('deleteAccount');
    final failure = nextDeleteException;
    nextDeleteException = null;
    if (failure != null) throw failure;
    setUser(null);
  }

  Future<void> dispose() => _changes.close();
}
