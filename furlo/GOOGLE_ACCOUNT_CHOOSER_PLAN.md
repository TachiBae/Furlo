# Google Account Chooser — Implementation Plan

## Goal

"Continue with Google" always shows the Google account picker instead of silently
resuming the last account — on every platform — so a new account can be created on
a device that has already signed in.

Decision (user-confirmed): the chooser appears on **every** Google sign-in, both
the "Sign in" and "Create account" screens. `AuthService.signInWithGoogle()`
therefore needs no new parameter — the interface stays unchanged.

## Cause

- **Web** — `signInWithPopup(GoogleAuthProvider())`
  (`lib/services/firebase_auth_service.dart` ~line 96) sends no `prompt`
  parameter, so Google's session auto-selects the active browser account.
- **Mobile** — `GoogleSignIn.instance.authenticate()` (google_sign_in 7.2.0,
  `authenticate({scopeHint})` only) has no prompt option; the platform UI
  (Credential Manager on Android, Google SDK on iOS) silently returns the
  last-used account while the plugin's cached session survives. The service
  clears it only in an explicit `signOut()` (~line 160), so any path that ends a
  session without it leaves the trap in place.

## Changes (all in `lib/services/firebase_auth_service.dart`; no interface change)

1. **Web:** `signInWithPopup(GoogleAuthProvider()
   ..setCustomParameters({'prompt': 'select_account'}))` — forces Google's
   account chooser on every tap.
2. **Mobile:** best-effort `GoogleSignIn.instance.signOut()` after
   `_initializeGoogleSignIn()` and before `authenticate()` inside
   `signInWithGoogle` — clears the cached account so the platform picker shows.
   Failure is non-fatal: sign-in proceeds.
3. **Test seam:** extract Google token acquisition behind a small injectable
   (e.g. `GoogleIdentityProvider` with `clearSession()` and `idToken()`), default
   implementation wrapping `GoogleSignIn.instance`; `FirebaseAuthService` accepts
   an optional override. No new dependencies.
4. **(Conditional fallback)** If Android still silently auto-selects after (2),
   replace the pre-auth cleanup with `disconnect()` — device-verification item.

## Tests

- Ordering: a fake `GoogleIdentityProvider` records calls; assert `clearSession()`
  completes before `idToken()` on the mobile path.
- Web: assert the built `GoogleAuthProvider` carries `prompt: 'select_account'`
  (via its parameters map; if the map is not publicly exposed, this is covered by
  browser verification instead — noted at implementation time).
- All existing auth tests stay green; `AuthService` is unchanged.

## Verification

- `flutter analyze --no-pub`, `flutter test --no-pub`.
- `flutter run -d web-server` + browser at 375px and 1440px (AGENTS.md): both auth
  screens render unchanged; tapping Google opens the account chooser (Google's
  own UI — requires a real Google session in the browser).
- Manual device check: on a device with a previous account, "Create account" →
  Google → the picker appears with "Use another account".

## Risks / notes

- Returning users tap their account once per sign-in (accepted by the chosen scope).
- The `disconnect()` fallback revokes authorization (more consent screens) — used
  only if `signOut()` proves insufficient on Android.
- One Google account maps to exactly one Firebase account: picking the existing
  account always resumes it. "Create a new account with Google" means choosing a
  Google account that has no Furlo account yet (or using email/password). That is
  identity semantics, not a bug.
- The existing behaviour of signing out after a *new* Google account
  (`sign_in_screen.dart`) is untouched — out of scope.
