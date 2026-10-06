import 'package:google_sign_in/google_sign_in.dart';

/// Google identity operations needed for Firebase sign-in.
///
/// Kept behind an interface so the account-picker sequence is testable without
/// the plugin or a Google account.
abstract interface class GoogleIdentityProvider {
  /// Signs out of any cached Google session so the platform shows the account
  /// picker on the next [idToken] call. May throw.
  Future<void> clearSession();

  /// Runs interactive Google sign-in and returns the ID token.
  Future<String?> idToken();
}

/// [GoogleIdentityProvider] backed by the `google_sign_in` plugin.
class GoogleSignInIdentityProvider implements GoogleIdentityProvider {
  GoogleSignInIdentityProvider({GoogleSignIn? signIn})
    : _signIn = signIn ?? GoogleSignIn.instance;

  final GoogleSignIn _signIn;
  static Future<void>? _initialization;

  Future<void> _initialize() => _initialization ??= _signIn.initialize();

  @override
  Future<void> clearSession() async {
    await _initialize();
    await _signIn.signOut();
  }

  @override
  Future<String?> idToken() async {
    await _initialize();
    final account = await _signIn.authenticate();
    return account.authentication.idToken;
  }
}

/// Acquires a Google ID token for Firebase sign-in, forcing the account picker.
///
/// Clearing the cached session first is what stops the platform from silently
/// resuming the last account. That clear is best-effort: a failure there never
/// blocks the sign-in attempt.
Future<String?> acquireGoogleIdToken(GoogleIdentityProvider identity) async {
  try {
    await identity.clearSession();
  } catch (_) {
    // Best-effort; proceed to the interactive sign-in regardless.
  }
  return identity.idToken();
}
