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
| Vaccinations | Working | `lib/screens/vaccinations/vaccination_screen.dart`, `lib/models/vaccination.dart` | Status is derived from dates. Every future date shows as "due soon", and a record with no due date shows as "completed" (U8). |
| Health records + medication reminders | Working | `lib/screens/health/health_records_screen.dart` | Daily, weekly and monthly medication reminders. |
| Vet contacts + vet↔pet links + appointments | Working | `lib/screens/vets/vet_contacts_screen.dart` | Firestore `vetLinks` replaces the `vet_pets` join table. The detail screen's appointment and delete actions have no error handling (Q3). |
| Weight tracking + chart | Working | `lib/screens/weight/weight_tracking_screen.dart` | `fl_chart` chart, positive-weight validation. |
| Local notifications (native) | Partial | `lib/services/notifications_service.dart` | Scheduling logic exists but the orchestration is untested (T4). Delivery on a device is [unverified]. |
| Notifications on web | Stubbed (by design) | `lib/services/notifications_service.dart:40` | `NoOpNotificationService` plus an informational banner on the settings screen. |
| Notification settings | Working | `lib/screens/settings/notifications_screen.dart`, `lib/providers/notification_settings_provider.dart` | Six toggles, stored in SharedPreferences per account. |
| Theme: Default / Light / Dark | Working | `lib/utils/app_theme.dart` | Saved under `app.theme_mode` and restored at startup. Covered by `test/theme_smoke_test.dart` and `test/theme_token_guard_test.dart`. |
| Profile & settings (display name, theme, sign-out) | Partial | `lib/screens/settings/profile_screen.dart` | The display name is stored on the device only (D4). |
| Clear all data | Dead code | `lib/repositories/pet_repository.dart:150`, `:670`, `:1444` | Implemented in all three repositories, but nothing in `lib/` calls `clearAllData()`. Still open from PROJECT_REPORT. |
| Cloud pet photos | Partial | `lib/repositories/pet_repository.dart:1297`, `:1732` | Stored as a base64 data URI inside the pet document (cap 600 KB), not in Firebase Storage. Oversized photos silently stay on the device (D9). |
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
