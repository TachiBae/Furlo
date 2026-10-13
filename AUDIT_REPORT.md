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
