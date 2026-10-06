# Task List: Store app data in the cloud instead of locally

Nothing below this line is started. Waiting for approval on `CLOUD_SYNC_PLAN.md`.

- [ ] Confirm the plan with you, including the photo, offline and `permissionWasRequested`
      risk items.
- [ ] Write `furlo/firestore.rules` rule for `users/{uid}/{document=**}`; keep
      `accountMetadata` and the deny-all fallback intact.
- [ ] Add `CloudDocumentStore` seam plus `FirestoreCloudStore`.
- [ ] Add `InMemoryCloudStore` test double under `test/helpers/`.
- [ ] Add `FirestorePetRepository` implementing the unchanged `PetRepository` interface
      (id allocation, cascade delete, `vetLinks` handling, `clearAllData`).
- [ ] Add Firestore implementations of `NotificationSettingsRepository` and
      `AppSettingsRepository`.
- [ ] Disable Firestore persistence in `lib/main.dart` before any other Firestore call.
- [ ] Add `lib/services/local_cloud_migration.dart`: one-time read-only copy of legacy
      local rows, guarded by `settings/meta.localMigratedAt`, never deleting local data.
- [ ] Wire cloud repositories and the migration into `_AuthGateState._startSession`.
- [ ] Swap the three direct `SharedPreferences*Repository` construction sites in
      `home_screen.dart`, `pet_profile_screen.dart`, `feeding_screen.dart`.
- [ ] Retarget tests that assert SharedPreferences scoping to assert cloud paths:
      `user_data_scope_test`, `app_settings_scope_test`, `web_persistence_test`,
      `*_repository_test`, `clear_all_data_test`, `pet_delete_cascade_test`.
- [ ] Add new tests: id allocation, cascade delete, migration runs once and preserves
      local data, per-uid path scoping.
- [ ] `dart format` on touched files.
- [ ] `flutter analyze` clean.
- [ ] `flutter test` — full suite passes.
- [ ] `flutter run -d web-server`; sign in, add a pet, restart the browser, sign in again
      and confirm the pet is still present.
- [ ] Verify in the Firebase console that documents land under `users/{uid}/…` and no new
      device-storage keys are written after a change.
- [ ] Report files changed, test results, and what was verified by running versus reading.
