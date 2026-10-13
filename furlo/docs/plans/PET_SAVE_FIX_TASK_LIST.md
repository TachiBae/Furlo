# Task List: Fix "saving a pet" failure

- [x] Reproduce the failure and confirm the root cause (FurloState provider scoped inside `home`).
- [x] Provide `FurloState` above the `Navigator` via `MaterialApp.builder` (kept the home/first-pet provider intact).
- [x] Wire `_AuthGate`/`_AuthGateState` to report the active `FurloState` up on session start/reset.
- [x] Change Add Pet save navigation from `pushAndRemoveUntil` to `pop()` so it no longer disposes the session owner.
- [x] Stop notifying listeners from `FurloState` during dispose (fixes a locked-tree crash on teardown).
- [x] Convert `test/save_pet_repro_test.dart` into a passing regression test (dropped the diagnostic case).
- [x] `dart format`, `flutter analyze`, focused tests, and full `flutter test` all pass (145 tests).
- [x] Web: app builds and serves, Firebase initializes cleanly (no builder-change crash). Authenticated dashboard not browser-verified (needs real sign-in; shared browser is on the Firebase Console) — covered by the regression test.
