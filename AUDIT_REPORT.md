# Furlo Audit Report

Paths are relative to `furlo/` unless they start with `../` or name a repo-root file. Line numbers are from commit `ca77b3b` on `fix/ui-audit`. Findings come from reading the code. The tool results in section 5 come from actually running the tools. Anything not checked at runtime is marked [unverified].

## 1. Summary

**Branch audited:** `fix/ui-audit`, at HEAD `ca77b3b` ("Item 9: give every form field one shared input table").

**Important context:** this branch is no longer a local-only sqflite app. `createPetRepository()` always returns `FirestorePetRepository` (`lib/repositories/pet_repository.dart:55`). Firebase Auth (email and Google), the complete-profile step and the cloud pet photos are already merged here. The sqflite and SharedPreferences repositories are now only read by the one-time legacy import. `../AGENTS.md`, `../README.md:142` and `docs/PROJECT_REPORT.md` still describe the old local-only design.

**Overall health:**
1. Builds cleanly: `flutter analyze` reports no issues and all 295 tests pass across 65 files.
2. Theme discipline is strong: no hardcoded UI colors outside `lib/utils/app_theme.dart`, and every screen reads `context.appColors`.
3. The data layer moved to Firestore, but the tests did not follow: the production repository has zero direct tests. Every repository test runs against `WebPetRepository`.
4. Three real logic bugs: the legacy import can drop or overwrite records, Weekly/Custom feeding reminders fire every day, and the record providers notify listeners after they have been disposed.
5. The structure is workable but top-heavy: `pet_repository.dart` (1,772 lines), `home_screen.dart` (1,165) and `app.dart` (834) each carry several responsibilities.

**Top 5 fixes, ranked by impact:**
1. **Stop the legacy import from colliding on IDs.** It shares one `copiedIds` set across two local stores that both number their IDs from 1. Pets get skipped and child records get overwritten in Firestore (`lib/services/legacy_local_migration.dart:144`, `:227`). See D1.
2. **Guard `HealthRecordsProvider`, `VaccinationsProvider` and `WeightTrackingProvider` against notify-after-dispose.** Leaving one of those screens before its load finishes throws in debug and on web (`lib/providers/vaccinations_provider.dart:57`). See Q1.
3. **Add direct tests for `FirestorePetRepository`.** This is the system of record and it is untested (`lib/repositories/pet_repository.dart:1329`). See T1.
4. **Schedule Weekly/Custom feeding reminders only on the selected days.** Right now they repeat daily (`lib/services/notifications_service.dart:550`). See Q2.
5. **Make pet save idempotent when the local photo write fails.** The Firestore write succeeds, the photo write throws, and tapping Save again creates a duplicate pet (`lib/repositories/pet_repository.dart:1417`, `lib/screens/pets/pet_onboarding_screen.dart:283`). See Q4.

## 2. Feature inventory

Status key: **Working** = complete in code and covered by tests. **Partial** = works, but with a gap or bug. **Stubbed** = placeholder only. **Dead code** = exists but is unreachable from the UI. **Absent** = not in code.

| Feature | Status | Location | Notes |
|---|---|---|---|
| Email sign-in / register / password reset | Working | `lib/screens/auth/sign_in_screen.dart`, `create_account_screen.dart`, `forgot_password_screen.dart`, `lib/services/firebase_auth_service.dart` | Firebase error codes map to friendly messages (`firebase_auth_service.dart:13`). Covered by `test/auth_screens_test.dart` and `test/auth_service_test.dart`. Real Firebase calls are [unverified]. |
| Google sign-in | Partial | `lib/services/firebase_auth_service.dart:137`, `lib/services/google_web_identity_web.dart` | Web tries the in-page chooser, then falls back to a popup. Native uses `google_sign_in`. Only tested against a fake; a real sign-in is [unverified]. |
| Complete-profile step | Working | `lib/screens/auth/complete_profile_screen.dart` | Links a password and sets the full and display names. The display name goes to both local prefs and Firestore, but only the local copy is ever read back (D4). |
| Auth gate / per-account session | Working | `lib/app.dart:131` | Generation counter guards session switches. Covered by `test/auth_gate_test.dart` and `test/user_data_scope_test.dart`. |
| Legacy local → cloud import (with consent) | Partial | `lib/services/legacy_local_migration.dart`, `lib/app.dart:445` | Copies are non-destructive and resumable, but IDs collide across the two local stores (D1), and vets with no linked pets are dropped (D2). |
| Pet add / edit (onboarding) | Partial | `lib/screens/pets/pet_onboarding_screen.dart` | Validation, breed picker, unsaved-changes guard. Gallery only (`:232`); the camera capture from the proposal is absent. Save can duplicate a pet (Q4). |
| Pet profile, delete, PDF export | Working | `lib/screens/pets/pet_profile_screen.dart`, `lib/services/export_service.dart` | Deleting a pet cascades to its records in Firestore (`pet_repository.dart:1434`). Export covered by `test/export_service_test.dart`. |
| Home dashboard + Today's Reminders | Partial | `lib/screens/home/home_screen.dart`, `lib/providers/home_reminders_provider.dart` | Reminders go stale after you edit records (Q6), and each load costs about N×(5+M) Firestore reads (Q5). |
| Feeding schedules | Partial | `lib/screens/feeding/feeding_screen.dart`, `lib/models/feeding_entry.dart` | CRUD, mark-fed and one-time schedules work. Reminders ignore Weekly/Custom days (Q2). |
| Vaccinations | Working | `lib/screens/vaccinations/vaccination_screen.dart`, `lib/models/vaccination.dart` | Status is derived from dates. Every future date shows as "due soon", and a record with no due date shows as "completed" (U6). |
| Health records + medication reminders | Working | `lib/screens/health/health_records_screen.dart` | Daily, weekly and monthly medication reminders. |
| Vet contacts + vet↔pet links + appointments | Working | `lib/screens/vets/vet_contacts_screen.dart` | Firestore `vetLinks` replaces the `vet_pets` join table. The detail screen's appointment and delete actions have no error handling (Q3). |
| Weight tracking + chart | Working | `lib/screens/weight/weight_tracking_screen.dart` | `fl_chart` chart, positive-weight validation. |
| Local notifications (native) | Partial | `lib/services/notifications_service.dart` | Scheduling logic exists but the orchestration is untested (T4). Delivery on a device is [unverified]. |
| Notifications on web | Stubbed (by design) | `lib/services/notifications_service.dart:40` | `NoOpNotificationService` plus an informational banner on the settings screen. |
| Notification settings | Working | `lib/screens/settings/notifications_screen.dart`, `lib/providers/notification_settings_provider.dart` | Six toggles, stored in SharedPreferences per account. |
| Theme: Default / Light / Dark | Working | `lib/utils/app_theme.dart` | Saved under `app.theme_mode` and restored at startup. Covered by `test/theme_smoke_test.dart` and `test/theme_token_guard_test.dart`. |
| Profile & settings (display name, theme, sign-out) | Partial | `lib/screens/settings/profile_screen.dart` | The display name is stored on the device only (D4). |
| Clear all data | Dead code | `lib/repositories/pet_repository.dart:150`, `:670`, `:1444` | Implemented in all three repositories, but nothing in `lib/` calls `clearAllData()`. Still open from PROJECT_REPORT. |
| Cloud pet photos | Partial | `lib/repositories/pet_repository.dart:1297`, `:1732` | Stored as a base64 data URI inside the pet document (cap 600 KB), not in Firebase Storage. Oversized photos silently stay on the device (D5). |
| Cloud data sync (Firestore) | Working, untested | `lib/repositories/pet_repository.dart:1329`, `firestore.rules` | Owner-only rules restricted per field. No direct tests (T1). |
| Vet account type | Absent | — | No role field or vet-specific code on this branch. |
| Gemini features (stretch) | Absent | — | No Gemini or AI client code in `lib/`. |
| Device preview frame | Working | `lib/main.dart:39` | Always on for web. |

**Earlier audit (`docs/PROJECT_REPORT.md`):** none of the claims I checked are marked fixed while still broken, but the report is stale:
- It says pets are stored in SQLite on native and SharedPreferences on web, and that accounts are not built (§3, §5 "Auth", §9). Both are now false; see section 1.
- It reports 99 tests across 29 files. There are now 295 tests across 65 files.
- Its open items 3, 6 and 7 are still open:
  - No camera capture (`pet_onboarding_screen.dart:232`).
  - No clear-all-data UI.
  - `applicationId = "com.example.furlo"` and debug release signing (`android/app/build.gradle.kts:23`, `:36`).
- Its note that the Noto Sans license file is missing still holds: `assets/fonts/` contains only the two `.ttf` files.

## 3. Findings

Format: **ID · Severity · File:line.** Problem, then Fix.

### Structure

- **S1 · Medium · `lib/repositories/pet_repository.dart:58`**
  - Problem: One 1,772-line file holds the interface, three implementations (SQLite `:58`, Web `:448`, Firestore `:1329`), the SQL schema helpers, the row mappers, the photo policy (`:1297`) and `LocalPetPhotoStore` (`:1732`).
  - Fix: Split into `pet_repository.dart` (interface and factory), `firestore_pet_repository.dart`, `legacy/sqlite_pet_repository.dart`, `legacy/web_pet_repository.dart`, `pet_photo_store.dart` and `mappers.dart`. Move only; change no logic.
- **S2 · Medium · `lib/app.dart:131`**
  - Problem: `_AuthGate` (about 560 lines of `State`) owns auth listening, session creation, notification startup, legacy-import consent, the setup markers and routing. The business logic is only reachable through widget tests.
  - Fix: Extract a `SessionController` (a `ChangeNotifier`) into `lib/providers/` holding the session and generation logic, and keep `_AuthGate` as a thin router over its state.
- **S3 · Medium · `lib/screens/home/home_screen.dart:27`**
  - Problem: 1,165 lines with 16 classes: the dashboard, bottom bar, pet tiles, reminder tiles, the all-pets screen and quick actions.
  - Fix: Move `_AllPetsScreen` to `screens/pets/all_pets_screen.dart`, and the bottom bar, reminders section and quick actions to `screens/home/widgets/`.
- **S4 · Medium · `lib/providers/health_records_provider.dart:8`, `vaccinations_provider.dart:8`, `weight_tracking_provider.dart:7`**
  - Problem: Three near-identical providers: the same select, refresh, save and delete flow with the same bugs (Q1).
  - Fix: Introduce one generic `PetRecordsProvider<T>` that takes load, save and delete callbacks, and make the three providers thin subclasses.
- **S5 · Medium · `../AGENTS.md:5`, `../README.md:142`, `docs/PROJECT_REPORT.md`**
  - Problem: Project docs still say "local-only", "sqflite on mobile" and "Firebase Auth … not implemented". The code is Firestore with auth.
  - Fix: Update the storage and auth paragraphs in all three to describe the Firestore system of record and the legacy-reader role of sqflite and SharedPreferences.
- **S6 · Low · `lib/services/account_onboarding_repository.dart:1`**
  - Problem: Two repositories (`AccountOnboardingRepository`, `AccountProfileRepository`) live in `services/` even though `repositories/` exists.
  - Fix: Move the file to `lib/repositories/account_repository.dart` and update the imports.
- **S7 · Low · `lib/screens/pets/pet_onboarding_screen.dart:104`**
  - Problem: The file is named for onboarding, but its main class is `AddPetScreen`, which is also the add/edit form.
  - Fix: Rename it to `pet_form_screen.dart`, or split the onboarding intro from the form.
- **S8 · Low · `lib/utils/app_theme.dart:113`**
  - Problem: `ThemeSettings`, a persisted `ChangeNotifier`, lives in `utils/` next to the static tokens.
  - Fix: Move it to `lib/providers/theme_settings.dart` and leave only the palette and tokens in `utils/app_theme.dart`.
- **S9 · Low · `pubspec.yaml:38`**
  - Problem: `cupertino_icons` is declared but never imported (0 hits in `lib/`).
  - Fix: Remove the dependency.
- **S10 · Low · `furlo/` root (`PHASE1_PLAN.md` and 31 other `*_PLAN.md` / `*_TASK*.md` files)**
  - Problem: Thirty-two agent plan and task files sit in the Flutter package root next to `pubspec.yaml`, which buries the real project files.
  - Fix: Move them under `docs/plans/`.
- **S11 · Low · `tool/screenshot_harness.dart:1`**
  - Problem: This is the only source file that `dart format` would change.
  - Fix: Run `dart format tool/`.

### Code Quality

- **Q1 · High · `lib/providers/vaccinations_provider.dart:57` (same in `health_records_provider.dart:57`, `weight_tracking_provider.dart:55`)**
  - Problem: Each constructor fires an unawaited `refresh()`. Its `finally` calls `notifyListeners()` with no disposed check, so popping the screen before Firestore answers throws "used after being disposed" in debug and on web. `FurloState` and `HomeRemindersProvider` already have the guard.
  - Fix: Add a `_disposed` flag, set it in `dispose()`, and route every notify through `if (!_disposed) notifyListeners()`. Also ignore stale loads with a generation counter, as `FurloState` does.
- **Q2 · High · `lib/services/notifications_service.dart:550`**
  - Problem: Every repeating feeding schedule is scheduled with `NotificationRepeat.daily`. Weekly/Custom schedules with chosen days (`feeding_screen.dart:241`) fire every day, and "Twice daily" gets one reminder.
  - Fix: For Weekly/Custom, schedule one `NotificationRepeat.weekly` notification per entry in `daysOfWeek`, with an ID like `'$id:$weekday'`. Decide whether "Twice daily" needs a second time or should be removed.
- **Q3 · Medium · `lib/screens/vets/vet_contacts_screen.dart:582`, `:599`**
  - Problem: `_appointment` and `_delete` on the vet detail screen await Firestore writes with no try/catch. Offline or permission errors become unhandled async errors and the user sees nothing.
  - Fix: Wrap both in try/catch, show the same SnackBar pattern the other screens use, and only set `_changed` or pop on success.
- **Q4 · Medium · `lib/repositories/pet_repository.dart:1417`, `:1770`, `lib/screens/pets/pet_onboarding_screen.dart:283`**
  - Problem: `addPet` writes Firestore first, then `LocalPetPhotoStore.write`, and `setString` there is not guarded. If the photo write throws (for example the browser localStorage quota, [unverified at runtime]), the pet already exists but `_newPetSaved` stays false, so tapping Save again adds a duplicate.
  - Fix: Generate the pet ID in the form before the first attempt and pass it in so the retry overwrites. Separately, make the local mirror write best-effort with a try/catch and a log.
- **Q5 · Medium · `lib/providers/home_reminders_provider.dart:263`, `lib/screens/vets/vet_contacts_screen.dart:76`, `lib/services/notifications_service.dart:495`**
  - Problem: N+1 Firestore access patterns:
    - Reminders run 4 queries per pet, and `getVetsForPet` (`pet_repository.dart:1576`) loads every vet each time, then queries links per vet.
    - The vet list calls `getPetsForVet`, which runs a full `getPets()`, once per vet.
    - `rescheduleAll` re-reads everything after every save (`health_records_provider.dart:72`).
  - Fix: Load each collection once per refresh (all feedings, all vets, all links) and group them in memory. Add repository methods for that if needed.
- **Q6 · Medium · `lib/screens/home/home_screen.dart:59`, `:117`**
  - Problem: Reminders reload on every `FurloState` notification, including just selecting a pet (`:177`). But they do not reload when you return from Feeding, Vaccinations or Health (`_open` only reloads the display name, `:122`). Marking a meal fed leaves it in Today's Reminders.
  - Fix: Call `_refreshReminders()` after `_open` returns. Listen only to pet-list changes (`context.select` on `pets`) rather than every notify.
- **Q7 · Low · `lib/providers/notification_settings_provider.dart:12`, `:93`, `lib/screens/settings/notifications_screen.dart:240`**
  - Problem: `ready = load()` and `toggle()` both rethrow, but nobody awaits or catches them. A storage failure becomes an unhandled error, and the reverted switch comes with no message.
  - Fix: Catch at the call site (`onChanged`) and in the constructor, and expose an `error` field the screen renders, as the record providers do.
- **Q8 · Low · `lib/screens/feeding/feeding_screen.dart:240`, `lib/models/feeding_entry.dart:57`**
  - Problem: Feeding frequencies are raw strings compared in three files, with mixed case (`'Weekly'` vs `.toLowerCase() == 'weekly'`).
  - Fix: Add a `FeedingFrequency` constants class (or an enum with a stored string value) next to `FeedingEntry.doesNotRepeat` and use it everywhere.
- **Q9 · Low · `lib/models/pet.dart:2`**
  - Problem: `Pet.id` is nullable even though every repository assigns one, so `pet.id!` is repeated across screens (`vet_contacts_screen.dart:453`, `:591`, `home_screen.dart:102`).
  - Fix: Split the unsaved form value from the persisted `Pet`, or keep nullable but add a `requireId` getter that throws a clear error.
- **Q10 · Low · `lib/services/firebase_auth_service.dart:122`**
  - Problem: Auth and migration code uses `debugPrint` with full error objects and stack traces, which also print in release builds, unlike `logAppDiagnostic` (`lib/utils/app_diagnostics.dart:4`).
  - Fix: Route these through `logAppDiagnostic` with an error code only.
- **Q11 · Low · `lib/services/firebase_auth_service.dart:40`**
  - Problem: `requires-recent-login` maps to the generic "Something went wrong", so the user has no way to fix it.
  - Fix: Add an `AuthErrorCode.reauthRequired` with copy that asks the user to sign in again.

### Data Layer

- **D1 · High · `lib/services/legacy_local_migration.dart:144`, `:227`**
  - Problem: One `copiedIds` set spans both local sources (the device-wide and per-account stores), and both number their IDs from 1. In the second store, a pet whose ID repeats one in the first store is skipped entirely. Its child records with repeated IDs are written with `set()` to the same Firestore doc IDs (`pet_repository.dart:1466`) and overwrite the first store's records. Local data survives, but the cloud copy is wrong.
  - Fix: Track copied IDs per source, and give imported records fresh Firestore IDs while keeping a source→new-ID map for children and vet links. Add a test with two sources that both contain ID `"1"` (T3).
- **D2 · Medium · `lib/services/legacy_local_migration.dart:277`**
  - Problem: Vets with no linked pets are skipped (`if (petIds.isEmpty) continue`), so standalone vet contacts are never imported.
  - Fix: Import every vet, with only the links whose pets were copied.
- **D3 · Medium · `lib/repositories/pet_repository.dart:1400`, `:1206`, `lib/models/weight_log.dart:28`**
  - Problem: The Item 8 hardening (skip a damaged row) only covers the web store. In Firestore reads, `_petFromMap`'s `as String` casts and `double.parse` in `WeightLog.fromMap` throw on one malformed doc, and `getPets` then fails the whole list.
  - Fix: Map Firestore docs through the same per-row try-and-skip helper as `_decodeRecords`, and use `tryParse` and null-safe casts in the mappers.
- **D4 · Medium · `lib/repositories/app_settings_repository.dart:53`, `lib/screens/settings/profile_screen.dart:78`**
  - Problem: The display name is read only from device SharedPreferences. `completeProfile` writes it to Firestore (`account_onboarding_repository.dart:106`), but the app never reads it back, and Profile edits never reach the cloud. On a second device the greeting is blank.
  - Fix: Make `users/{uid}/settings/profile.displayName` the source of truth: read it in `HomeScreen` and write it from `ProfileScreen`, keeping prefs only as a cache.
- **D5 · Medium · `lib/repositories/pet_repository.dart:1297`, `:1763`**
  - Problem: Photos above 600 KB silently stay device-only (only a debug log, `:1410`). The local mirror keeps every photo, uncapped, in SharedPreferences, which is localStorage (about 5 MB) on web.
  - Fix: Before saving, re-encode or downscale until the photo is under the cap and tell the user if it still isn't. Longer term, move photos to Firebase Storage (section 6).
- **D6 · Low · `lib/repositories/pet_repository.dart:1400`**
  - Problem: Firestore `getPets()` has no `orderBy`, so pets come back in random doc-ID order. The SQLite store used `id DESC`.
  - Fix: Store a `createdAt` field and `orderBy('createdAt')`. Rules and the field whitelist need the new key.
- **D7 · Low · `lib/repositories/pet_repository.dart:1481`**
  - Problem: The delete methods for feedings, vaccinations, health records and weight logs query every child of the pet just to delete one doc.
  - Fix: Read the single doc, check that its `pet_id` matches, then delete it.
- **D8 · Low · `lib/repositories/pet_repository.dart:1651`**
  - Problem: Firestore `setNextAppointment` upserts and can create a vet link that does not exist. SQLite only updates existing rows (`:349`).
  - Fix: Use `update()`, or check that the link doc exists first, to match the SQLite behavior.
- **D9 · Low · `firestore.rules:114`, `lib/models/vaccination.dart:4`**
  - Problem: The rules whitelist exactly the three statuses `deriveVaccinationStatus` can return today. The `upcoming` constant is dead, and adding it later would make every write fail.
  - Fix: Delete `VaccinationStatuses.upcoming`, or add it to the rules list in the same commit. Add a comment in both places pointing at the other.
- **D10 · Low · `lib/repositories/pet_repository.dart:105`**
  - Problem: The legacy SQLite `onOpen` re-runs every `CREATE TABLE IF NOT EXISTS` and the column checks on each open, which duplicates `onCreate`/`onUpgrade` (`:93`). It is harmless, but hides what version each table belongs to now that this store is read-only.
  - Fix: Since the store is only read for import, freeze the schema at version 10, drop the `onOpen` repairs, and document it as read-only. Never add destructive steps.

### UI/UX

- **U1 · Medium · `lib/app.dart:776`, `:781`**
  - Problem: When a reload fails after pets were already loaded, `_LoadErrorBanner` is placed in a bare `Column` above `HomeScreen`'s `Scaffold`. It has no `Material` or `SafeArea` ancestor, so the text inherits the framework's yellow-underline error style and sits under the status bar ([unverified visually]).
  - Fix: Pass the error into `HomeScreen` and render the banner inside its `Scaffold` body, or wrap it in `Material` and `SafeArea`.
- **U2 · Low · `lib/utils/app_theme.dart:52`, `lib/screens/pets/pet_profile_screen.dart:526`**
  - Problem: Default `textDisabled` `#6B697A` on `surface` is 3.2:1, below WCAG AA 4.5:1, and it is used for readable text ("Not provided", the vet appointment "not set" caption at `vet_contacts_screen.dart:686`).
  - Fix: Use `textSecondary` (7.1:1) for placeholder text and keep `textDisabled` for truly disabled controls.
- **U3 · Low · `lib/utils/app_theme.dart:64`**
  - Problem: In Light, `accent` `#404040` against `primary` `#262626` is 1.46:1. Selected states drawn in accent (species picker `pet_onboarding_screen.dart:443`) barely differ from primary text.
  - Fix: Mark selection with a non-color cue as well (a check icon or border weight), or pick a lighter Light `accent`.
- **U4 · Low · `lib/screens/weight/weight_tracking_screen.dart:555`, `lib/screens/vets/vet_contacts_screen.dart:513`, `lib/screens/feeding/feeding_screen.dart:506`**
  - Problem: Form fields override the theme differently: weight and vet forms fill with `surface`, record forms with `surfaceAlt`, and Feeding builds its own full decoration. The fields look different from screen to screen.
  - Fix: Delete the per-screen decorations and rely on `inputDecorationTheme` (`app_theme.dart:386`), or use `recordFormDecoration` everywhere.
- **U5 · Low · `lib/app.dart:86`**
  - Problem: The theme-loading splash always uses the Default palette, so Light users get a dark flash.
  - Fix: Use a neutral splash, or load the theme preference in `main()` before `runApp`.
- **U6 · Low · `lib/models/vaccination.dart:17`, `:27`**
  - Problem: A vaccination with no next due date shows "Completed" even when it isn't marked complete, while still offering "Mark complete". Any future date, even a year out, shows "Due soon". This is intended per `test/vaccination_model_test.dart:49`, but it contradicts the button.
  - Fix: Keep the derivation but show "No due date" when `nextDueDate == null && !isCompleted`, or confirm the design and hide the button in that state.

### Tests

- **T1 · High · `lib/repositories/pet_repository.dart:1329`**
  - Problem: `FirestorePetRepository`, the production store, has no tests. Every repository test uses `WebPetRepository`, so cascades, batches over 400 docs, ID handling and photo fields in the real store are unverified.
  - Fix: Add `fake_cloud_firestore` as a dev dependency (needs your OK per AGENTS.md) and port `test/web_persistence_test.dart`, `test/pet_delete_cascade_test.dart` and `test/vet_repository_test.dart` to run against it.
- **T2 · Medium · `../.github/workflows/deploy-pages.yml:5`**
  - Problem: Every push to `fix/ui-audit` builds and deploys to Pages without running `flutter analyze` or `flutter test`.
  - Fix: Add analyze and test steps before `flutter build web` (`:35`) so a red build never deploys.
- **T3 · Medium · `test/legacy_local_migration_test.dart:30`**
  - Problem: The migration tests use a single legacy source, so the two-source ID collision (D1) and the vet-only case (D2) are uncovered.
  - Fix: Add cases with two `WebPetRepository` sources that both hold ID `"1"`, and a vet with no linked pets.
- **T4 · Medium · `test/notification_service_test.dart:136`**
  - Problem: Only the pure time calculations are tested. `LocalNotificationService.rescheduleAll` and `_scheduleFeeding` (`notifications_service.dart:514`), where Q2 lives, have no tests.
  - Fix: Inject the plugin behind a small interface and assert the scheduled IDs, times and repeat components for Daily, Weekly and one-time schedules.
- **T5 · Low · `docs/firestore-rules-tests.md:1`**
  - Problem: The rules tests are a manual Rules Playground checklist, so a rules change can't be verified automatically.
  - Fix: Automate them with the Firestore emulator and `@firebase/rules-unit-testing` in a separate script, outside the Flutter package.
- **T6 · Low · `test/record_error_retry_test.dart:13`**
  - Problem: No test pops a record screen while its load is still pending, which is the Q1 failure.
  - Fix: Add a widget test with a repository whose future never completes, pop the route, and assert `tester.takeException()` is null.

## 4. Proposed file structure

The current layer split (`models/`, `providers/`, `repositories/`, `services/`, `screens/`, `widgets/`, `utils/`, `data/`) suits an app this size and should stay. The real problems are three oversized files (S1–S3), repositories filed under `services/` (S6), state kept in `utils/` (S8), and plan files cluttering the package root (S10). All of these are moves; no logic changes.

```
furlo/
├── lib/
│   ├── main.dart
│   ├── app.dart                         # FurloApp + MaterialApp only
│   ├── firebase_options.dart
│   ├── data/                            # static catalogs (unchanged)
│   ├── models/                          # unchanged; + feeding_frequency.dart (Q8)
│   ├── providers/
│   │   ├── furlo_state.dart
│   │   ├── session_controller.dart      # ← _AuthGate logic from app.dart (S2)
│   │   ├── theme_settings.dart          # ← ThemeSettings from utils/app_theme.dart (S8)
│   │   ├── pet_records_provider.dart    # generic base for the 3 record providers (S4)
│   │   ├── health_records_provider.dart
│   │   ├── vaccinations_provider.dart
│   │   ├── weight_tracking_provider.dart
│   │   ├── home_reminders_provider.dart
│   │   └── notification_settings_provider.dart
│   ├── repositories/
│   │   ├── pet_repository.dart          # interface + createPetRepository()
│   │   ├── firestore_pet_repository.dart
│   │   ├── pet_photo_store.dart         # LocalPetPhotoStore + cloudPhotoField
│   │   ├── record_mappers.dart          # _petFromMap, _feedingEntryToMap, decode helpers
│   │   ├── legacy/
│   │   │   ├── sqlite_pet_repository.dart   # read-only, import source
│   │   │   └── web_pet_repository.dart      # read-only, import source
│   │   ├── account_repository.dart      # ← services/account_onboarding_repository.dart (S6)
│   │   ├── app_settings_repository.dart
│   │   └── notification_settings_repository.dart
│   ├── services/                        # auth, notifications, export, migration, google identity
│   ├── screens/
│   │   ├── auth/
│   │   ├── gate/                        # ← _StartupGate, _LegacyImportDialog, error screens from app.dart
│   │   ├── home/
│   │   │   ├── home_screen.dart
│   │   │   └── widgets/                 # bottom bar, reminders section, quick actions, pet tiles (S3)
│   │   ├── pets/
│   │   │   ├── pet_form_screen.dart     # ← pet_onboarding_screen.dart (S7)
│   │   │   ├── all_pets_screen.dart     # ← _AllPetsScreen from home_screen.dart
│   │   │   └── pet_profile_screen.dart
│   │   └── feeding/ health/ settings/ vaccinations/ vets/ weight/   # unchanged
│   ├── widgets/                         # unchanged
│   └── utils/                           # tokens/palette, formatting, validators (no ChangeNotifiers)
├── docs/
│   └── plans/                           # ← the 32 *_PLAN.md / *_TASK*.md files from furlo/ (S10)
└── test/                                # mirror new paths; + firestore_pet_repository_test.dart (T1)
```
