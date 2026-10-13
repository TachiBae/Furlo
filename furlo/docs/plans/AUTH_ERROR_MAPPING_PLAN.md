# Plan: Stop collapsing real auth failures into "Something went wrong"

## Diagnosis context (verified by running, 2026-10-11)
Live-site auth gates are healthy: API-key referrer ✓, Firebase authorized domains ✓,
email/password provider ✓, Google provider ✓ (all probed from the live origin).

What remains is visibility: [firebase_auth_service.dart:14-22](lib/services/firebase_auth_service.dart)
maps only 7 Firebase codes; **everything else — including `invalid-credential`, the code
returned for wrong password OR an email with no password account (email-enumeration
protection makes both identical) — falls through to `unknown` → "Something went wrong.
Please try again."** The same generic text hides `user-disabled`, `popup-blocked`, etc.

## Change (single file + tests)
In `_mapFirebaseException` / the code map, add:
- `'invalid-credential'`, `'wrong-password'` → `AuthErrorCode.invalidCredentials`
  → "Check your email and password, then try again." (accurate for both causes)
- `'user-disabled'` → `AuthErrorCode.userNotFound`
  → "No account was found for those credentials." (closest existing copy; disabled
  accounts must not be confirmed explicitly)
- `'popup-blocked'`, `'popup-closed-by-user'` → `AuthErrorCode.cancelled`
  → "Sign-in was cancelled."

No enum changes, no new strings, no other files.

## Tests
- Extend the auth mapping tests: each new Firebase code maps to its AuthErrorCode and
  renders the expected message; unknown codes still fall back to the generic message.
- `flutter analyze --no-pub` and full `flutter test` must pass (currently 203 tests).

## Deploy & verify
- Commit + push → CI builds/deploys → live probe with dummy credentials still returns
  `INVALID_LOGIN_CREDENTIALS` (gate behavior unchanged), and the user-visible copy for
  that failure becomes the specific message on the live site.
