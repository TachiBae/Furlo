# Pets Load Fix — Task List

Approval gate: do not start any Fix/Verify item until `PETS_LOAD_FIX_PLAN.md` is approved.
Work cause-first: finish **Diagnose** before choosing Fix B or C. Fix A applies to every cause.

## Diagnose (only you can do these, Firebase console)

> **Diagnosis result (2026-10-07): cause confirmed = rules not published.** The
> deployed rules contained only `accountMetadata/{uid}` + deny-all; the
> `users/{uid}/{document=**}` match was absent → `permission-denied` on
> `getPets()`. → Fix C. Item 2 is moot unless the error persists after publishing.

- [x] 1. Firestore → Rules: check whether the **deployed** rules contain `match /users/{uid}/{document=**}` (above the deny-all fallback). *(finding: absent)*
- [ ] 2. Firestore → Data → `users/<uid>/pets`: open each document and check `name` and `species` are strings and `birthDate` is an ISO-8601 string (or absent). *(skipped — moot; revisit only if the error survives Fix C)*
- [x] 3. Decide the cause: missing `users` match → rules (Fix C). Wrong field types in a doc → parsing (Fix B). Both fine → run a debug build and report what `logAppDiagnostic` prints. *(decided: rules → Fix C)*

## Fix A — surface the real error (applies to every cause)

- [ ] 4. Add a shared `describeError(Object)` helper in `lib/utils/app_diagnostics.dart` (`FirebaseException` → `error.code`, else runtime type) and have `app.dart`'s `_describeError` delegate to it.
- [ ] 5. In `FurloState.load()`'s catch (`lib/providers/furlo_state.dart`), log `Pets could not be loaded: <code>` via `logAppDiagnostic`.
- [ ] 6. On the pets error screen (`_StartupGate`, `lib/app.dart` ~line 466), show `Cause: <code>` beneath the message, matching the account-setup screen (`lib/app.dart` ~line 397).
- [ ] 7. Tests: a failed load surfaces the error code on the pets error screen and logs it.

## Fix B — one bad document cannot kill the list (only if cause 2)

- [ ] 8. Make the pet and child `fromMap` parsers tolerate missing or wrongly typed fields (safe casts); skip malformed documents with a diagnostic instead of failing `getPets()`.
- [ ] 9. Tests: a malformed pet document is skipped and valid documents still load.

## Fix C — publish the rules (only if cause 1, only you can do this)

- [ ] 10. Publish `furlo/firestore.rules` (console Rules tab → paste → Publish, or `firebase deploy --only firestore:rules`). Confirm the deployed text contains **both** the `accountMetadata/{uid}` match and the `users/{uid}/{document=**}` match.

## Verify

- [ ] 11. From `furlo/`: `flutter analyze --no-pub` and `flutter test --no-pub` — both must pass.
- [ ] 12. `flutter run -d web-server`: sign-in loads pets, and at 375px and 1440px the error screen (if it triggers) shows `Cause: <code>`. [Browser agent required — previously blocked in this session.]
- [ ] 13. Same account on a second device or browser: pets appear after sign-in (cross-device sync check).
