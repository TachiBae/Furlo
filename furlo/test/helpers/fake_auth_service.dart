import 'dart:async';

import 'package:furlo/services/account_onboarding_repository.dart';
import 'package:furlo/services/auth_service.dart';

class FakeAuthService implements AuthService {
  FakeAuthService({AuthUser? initialUser, this._accountOnboardingRepository})
    : _user = initialUser;

  AuthUser? _user;
  final AccountOnboardingRepository? _accountOnboardingRepository;
  final StreamController<AuthUser?> _changes =
      StreamController<AuthUser?>.broadcast(sync: true);
  AuthException? _nextSignInException;
  Object? _nextUnhandledSignInError;
  AuthException? _nextRegisterException;
  AuthException? _nextGoogleException;
  AuthException? _nextResetException;
  AuthException? _nextSignOutException;
  Future<void> Function()? _beforeSignIn;
  Future<void> Function()? _beforeRegister;
  Future<void> Function()? _beforeGoogle;
  Future<void> Function()? _beforeReset;
  Future<void> Function()? _beforeSignOut;
  bool googleCreatesNewAccount = true;

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
    await markNewAccountForFirstPet(user.uid);
    return AuthResult(user: user, isNewAccount: true);
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
    if (googleCreatesNewAccount) {
      await markNewAccountForFirstPet(user.uid);
    }
    return AuthResult(user: user, isNewAccount: googleCreatesNewAccount);
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

  Future<void> dispose() => _changes.close();
}
