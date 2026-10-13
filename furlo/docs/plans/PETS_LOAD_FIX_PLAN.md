# Pets Load Fix — Implementation Plan

## Goal

Make the sign-in flow end at the dashboard with pets loaded, and when a load fails, name the cause instead of showing a fixed string.

## What the screenshot proves

`_StartupGate` (the "Your pets could not be loaded." screen) renders only after
`_accountStatusLoaded` is true and `_accountStatusError` is false (`lib/app.dart`
build order). So `accountMetadata/{uid}` read fine: Firebase initialized, the auth
token is valid, the database exists and is reachable, and the deployed rules allow
`accountMetadata` reads. The failure is specific to `users/{uid}/pets`.

## Cause decision tree

1. **Deployed rules lack `users/{uid}/{document=**}`** → `permission-denied` on
   `getPets()`. Most likely: the rule exists only in the local `firestore.rules`.
   → Fix C (console publish), plus Fix A so the code is visible next time.
2. **A malformed pet document** → `TypeError` in `_petFromMap`
   (`lib/repositories/pet_repository.dart` ~line 1203: hard casts on `name`,
   `species`, `birthDate`). A single bad doc fails the whole list.
   → Fix B, plus Fix A.
3. Network drop / token expiry mid-load → unlikely; the account read succeeded
   moments earlier. Covered by Fix A's error code (`unavailable` /
   `permission-denied`).

## Changes

- **Fix A — visibility.** Shared `describeError` in `lib/utils/app_diagnostics.dart`;
  `FurloState.load()` logs the code; the pets error screen shows `Cause: <code>`,
  mirroring the account-setup screen. Today the error is stored in `_loadError`
  and never logged or displayed.
- **Fix B — tolerant parsing (cause 2 only).** Safe casts in the `fromMap`
  parsers; malformed documents are skipped with a diagnostic, never deleted.
- **Fix C — rules (cause 1 only, user action).** Publish `firestore.rules`; no
  code change.

## Tests

- Error code shown on the pets error screen and logged on load failure (Fix A).
- Malformed doc skipped, valid docs still load (Fix B).

## Verification

`flutter analyze --no-pub`, `flutter test --no-pub`, then
`flutter run -d web-server` with browser checks at 375px and 1440px (AGENTS.md
requirement for UI changes), plus the same-account second-device check.

## Risks

- Skipping malformed docs (Fix B) hides corrupt data silently unless the
  diagnostic is checked; the log line is the safeguard.
- Fix C is invisible to every check in this repo — only the console or a real
  sign-in proves the rules are live.
