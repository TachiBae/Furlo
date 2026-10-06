import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/services/firebase_auth_service.dart';
import 'package:furlo/services/google_identity_provider.dart';

class _RecordingIdentity implements GoogleIdentityProvider {
  _RecordingIdentity({this.failClear = false});

  final bool failClear;
  final List<String> calls = [];

  @override
  Future<void> clearSession() async {
    calls.add('clearSession');
    if (failClear) throw StateError('sign-out failed');
  }

  @override
  Future<String?> idToken() async {
    calls.add('idToken');
    return 'fake-id-token';
  }
}

class _NullIdentity implements GoogleIdentityProvider {
  @override
  Future<void> clearSession() async {}

  @override
  Future<String?> idToken() async => null;
}

void main() {
  test('clears the cached session before authenticating', () async {
    final identity = _RecordingIdentity();
    final token = await acquireGoogleIdToken(identity);
    expect(token, 'fake-id-token');
    expect(identity.calls, ['clearSession', 'idToken']);
  });

  test('still authenticates when clearing the session fails', () async {
    final identity = _RecordingIdentity(failClear: true);
    final token = await acquireGoogleIdToken(identity);
    expect(token, 'fake-id-token');
    expect(identity.calls, ['clearSession', 'idToken']);
  });

  test('passes a null id token through', () async {
    final identity = _NullIdentity();
    expect(await acquireGoogleIdToken(identity), isNull);
  });

  test('web Google provider forces the account chooser', () {
    final provider = buildGoogleWebAuthProvider();
    expect(provider.parameters['prompt'], 'select_account');
  });
}
