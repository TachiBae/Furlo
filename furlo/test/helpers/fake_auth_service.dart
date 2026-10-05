import 'dart:async';

import 'package:furlo/services/auth_service.dart';

class FakeAuthService implements AuthService {
  FakeAuthService({AuthUser? initialUser}) : _user = initialUser;

  AuthUser? _user;
  final StreamController<AuthUser?> _changes =
      StreamController<AuthUser?>.broadcast(sync: true);
  AuthException? _nextSignInException;
  AuthException? _nextRegisterException;

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

  void setUser(AuthUser? user) {
    _user = user;
    _changes.add(user);
  }

  void failNextSignIn(AuthException exception) {
    _nextSignInException = exception;
  }

  void failNextRegister(AuthException exception) {
    _nextRegisterException = exception;
  }

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    calls.add('signInWithEmail');
    final failure = _nextSignInException;
    _nextSignInException = null;
    if (failure != null) throw failure;
    final user = AuthUser(uid: 'fake-user', email: email, displayName: null);
    setUser(user);
    return user;
  }

  @override
  Future<AuthUser> registerWithEmail(String email, String password) async {
    calls.add('registerWithEmail');
    final failure = _nextRegisterException;
    _nextRegisterException = null;
    if (failure != null) throw failure;
    final user = AuthUser(uid: 'fake-user', email: email, displayName: null);
    setUser(user);
    return user;
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    calls.add('signInWithGoogle');
    final user = AuthUser(
      uid: 'fake-google-user',
      email: null,
      displayName: null,
    );
    setUser(user);
    return user;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    calls.add('sendPasswordReset');
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    setUser(null);
  }

  Future<void> dispose() => _changes.close();
}
