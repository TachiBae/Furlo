import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'auth_service.dart';
import 'google_web_identity_contract.dart';

/// The Firebase project's **Web OAuth client ID** — Firebase console →
/// Authentication → Sign-in method → Google → "Web client ID"
/// (`738197946630-….apps.googleusercontent.com`).
///
/// Empty disables the in-page chooser; sign-in then falls back to the
/// popup-window flow.
const String kGoogleWebClientId = '';

@JS('google.accounts.id.initialize')
external void _gisInitialize(JSAny options);

@JS('google.accounts.id.prompt')
external void _gisPrompt([JSFunction? momentListener]);

bool _googleIdentitySdkAvailable() {
  final google = globalContext.getProperty<JSObject?>('google'.toJS);
  final accounts = google?.getProperty<JSObject?>('accounts'.toJS);
  final id = accounts?.getProperty<JSObject?>('id'.toJS);
  return id != null;
}

Completer<String?>? _pending;
bool _initialized = false;

/// Runs the in-page Google chooser (One Tap / FedCM dialog — no popup window)
/// and returns the Google ID token.
///
/// Returns `null` when the in-page flow cannot run (SDK missing, nothing
/// displayed, script hiccup) so callers can fall back to the popup flow.
/// Throws [AuthException] with [AuthErrorCode.cancelled] when the user
/// dismisses the chooser.
Future<String?> acquireGoogleWebIdToken() async {
  if (kGoogleWebClientId.isEmpty || !_googleIdentitySdkAvailable()) {
    return null;
  }
  final existing = _pending;
  if (existing != null) {
    // A chooser is already on screen; join it instead of re-prompting.
    return existing.future;
  }
  final completer = Completer<String?>();
  _pending = completer;
  _ensureInitialized();
  try {
    _gisPrompt(_momentListener.toJS);
  } catch (_) {
    _pending = null;
    if (!completer.isCompleted) completer.complete(null);
  }
  return completer.future;
}

void _ensureInitialized() {
  if (_initialized) return;
  final options = JSObject();
  options.setProperty('client_id'.toJS, kGoogleWebClientId.toJS);
  options.setProperty('auto_select'.toJS, false.toJS);
  options.setProperty('cancel_on_tap_outside'.toJS, true.toJS);
  options.setProperty('callback'.toJS, _onCredential.toJS);
  _gisInitialize(options);
  _initialized = true;
}

void _onCredential(JSObject response) {
  final pending = _pending;
  _pending = null;
  if (pending == null || pending.isCompleted) return;
  final jwt = response.getProperty<JSString?>('credential'.toJS)?.toDart;
  if (jwt == null || jwt.isEmpty) {
    pending.complete(null);
  } else {
    pending.complete(jwt);
  }
}

void _momentListener(JSObject moment) {
  final type = moment.getProperty<JSString?>('type'.toJS)?.toDart ?? '';
  final pending = _pending;
  if (pending == null || pending.isCompleted) return;
  switch (gisMomentOutcome(type)) {
    case GisMomentOutcome.shown:
      break;
    case GisMomentOutcome.fallback:
      _pending = null;
      pending.complete(null);
    case GisMomentOutcome.cancel:
      _pending = null;
      pending.completeError(
        const AuthException(code: AuthErrorCode.cancelled),
      );
  }
}
