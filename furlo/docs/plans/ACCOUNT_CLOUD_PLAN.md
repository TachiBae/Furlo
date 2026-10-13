# Implementation Plan: Make the account system work via cloud

## Goal

Signed-in users read and write their pets and records in Firestore under `users/{uid}/…`,
so data follows the account across devices. Legacy data already on the device becomes
visible to the account, and account-setup failures report their real cause.

## The three problems being fixed (from the cloud sync report)

| # | Problem | Fix |
| --- | --- | --- |
| 1 | No pet data syncs; everything is device-local (SQLite `furlo_<token>.db` / SharedPreferences `furlo.user.<token>.*`) | Firestore implementation of `PetRepository` under `users/{uid}/…` |
| 2 | A brand-new account sees an empty app; pre-account data at unscoped keys (`furlo.pets`, `furlo.db`) is never read | One-time, non-destructive migration of local rows into the account |
| 3 | `_loadAccountStatus` swallows the error (`catch (_)`) and logs only a fixed string | Capture and surface the real error code |

## Target (measured against)

- Collections under `users/{uid}/`: `pets`, `feedings`, `vaccinations`, `healthRecords`,
  `weightLogs`, `vets`, `vetLinks`; every child document carries `petId`.
- String ids.
- A Firestore implementation of the existing `PetRepository` interface.
- Cascade deletes in batched writes.
- Rules so a user can touch only their own path.
- Theme and notification toggles stay on the device. Photos stay on the device.

This supersedes the unapproved `CLOUD_SYNC_PLAN.md`, which also proposed syncing
notification/app settings and moving photos to Firestore. That is out of scope here.

## Design

### 1. String ids

- `int? id` → `String? id`, `int petId` → `String petId` in `Pet`, `FeedingEntry`,
  `HealthRecord`, `Vaccination`, `Vet`, `VetPetAssociation`, `WeightLog`.
- `fromMap` already tolerates strings (`int.tryParse(map['id']?.toString())`), and `toMap`
  already stringifies; both simplify to plain `String` handling.
- New ids come from Firestore (`collection.doc().id`); no `max + 1` allocation.
- Notifications already accept a non-int: `stableNotificationId(String type, Object
  recordId, {String? scope})` ([notifications_service.dart:49](lib/services/notifications_service.dart#L49))
  hashes a string deterministically. Change `NotificationService.schedule/cancel` to take
  `String id`, and `_appointmentId(int, int)` to take Strings. Nothing else about
  notification ids changes.

### 2. FirestorePetRepository

- `class FirestorePetRepository implements PetRepository`, uid-scoped, all 35 methods.
- Reads are one-time `.get()` (no listeners), matching today's fetch-on-mutate flow.
- Child lookups use `where('petId', isEqualTo: …)`; `getVetsForPet`/`getVetPetAssociations`
  read `vetLinks` and join.
- **Cascade deletes in `WriteBatch`**: deleting a pet batches the pet doc plus every
  `feedings`/`vaccinations`/`healthRecords`/`weightLogs`/`vetLinks` doc for that `petId`;
  `deleteVet` batches the vet doc plus its `vetLinks`. `clearAllData` batches whole
  collections under the user.

### 3. Repository chosen by auth state

`createPetRepository` ([pet_repository.dart:48](lib/repositories/pet_repository.dart#L48))
stops switching on `kIsWeb` and returns `FirestorePetRepository` for the signed-in uid.
`SqlitePetRepository`/`WebPetRepository` stay only as read-only legacy readers for the
migration (and for the tests that still cover them).

### 4. Photos stay on the device

`photoPath` is a base64 `data:` URI and Firestore caps documents at 1 MB, so photos are
not written to Firestore. Keep a device-local photo store keyed by pet id and exclude
`photoPath` from the Firestore pet document.

### 5. Legacy migration (problem 2)

- Runs once per account at session start, before `furloState.load()`.
- Reads rows from **both** legacy stores: unscoped keys (`furlo.pets`, … on web; `furlo.db`
  on native) and the current scoped keys (`furlo.user.<token>.*`), converts int ids to
  Strings, and writes them under `users/{uid}/…`.
- Guarded by `users/{uid}/meta.localMigratedAt` and skipped when the cloud `pets`
  collection is already non-empty, so it can never duplicate data.
- **Never deletes or rewrites local storage** — no destructive migration (repo rule).
- Failure is non-fatal and logged with the real error; the session still starts.

### 6. Error handling (problem 3)

- `_loadAccountStatus` ([app.dart:289](lib/app.dart#L289)) stops using `catch (_)`; it
  records the error and surfaces its code (e.g. `permission-denied`, `unavailable`) on the
  "Your account setup could not be loaded." screen and in diagnostics, so a missing
  database and unpublished rules are distinguishable.
- `logAppDiagnostic` keeps emitting fixed, non-sensitive strings; the error code is a code,
  not payload.

### 7. Rules

Add above the deny-all fallback in [firestore.rules](firestore.rules):

```
match /users/{uid}/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}
```

`accountMetadata` keeps its existing, stricter rule. Deployment of rules is yours to do in
the console — this repo only holds the file.

### 8. What stays on the device

Theme (`app.theme_mode`), notification toggles and the permission-requested flag
(`notification.user.<token>.*`) are unchanged. Photos stay local (§4).

## Files to change

| File | Change |
| --- | --- |
| `lib/models/*.dart` (7 models) | String ids / String `petId` |
| `lib/repositories/pet_repository.dart` | add `FirestorePetRepository`; legacy impls become read-only readers |
| `lib/services/legacy_local_migration.dart` | new one-time migrator |
| `lib/services/notifications_service.dart` | `schedule`/`cancel` take `String id` |
| `lib/main.dart` | nothing (no cache setting needed; reads are one-time) |
| `lib/app.dart` | choose repository by auth state, run migration, surface real error |
| `lib/providers/*`, `lib/screens/*` | id type fallout only |
| `furlo/firestore.rules` | per-user `users/{uid}` rule |
| `test/*` | String ids, Firestore repo tests, migration tests, error-code test |

## Verification

1. `dart format` on touched files; `flutter analyze` clean.
2. `flutter test` — existing 145 tests updated to String ids and still passing.
3. New tests: cascade delete batching, per-uid path scoping, migration runs once and leaves
   local data intact, migration converts int ids, error code is surfaced.
4. `flutter run -d web-server`: sign in on device A, add a pet, sign in on the **same**
   account on device B (or a second profile) and confirm the pet appears. This is the
   acceptance test for problem 1.
5. On a device holding pre-account pets: sign in and confirm they appear (problem 2).
6. With rules unpublished or the database missing: confirm the screen names the cause
   (problem 3).

## Safety and scope

- No destructive migration: local databases and preference keys are read, never cleared.
- No new dependencies.
- `IMPLEMENTATION_PLAN.md` / `TASK_LIST.md` belong to the pending analyzer task and are
  untouched; this work uses `ACCOUNT_CLOUD_*` documents.
- Changes stay uncommitted for your review.

## Risks

1. **Model id change is broad.** String ids touch every screen, provider and test. Mitigated
   by keeping the `PetRepository` interface shape identical apart from id types.
2. **Batched cascade deletes need child queries first.** Deleting a pet is one query plus
   one batch; acceptable at pet-tracker volumes, measured once running.
3. **Migration correctness.** If it runs twice it would duplicate pets; the
   `localMigratedAt` guard plus the empty-cloud check prevents that.
4. **Rules deployment.** The app will fail every cloud read until the new rule is published;
   the problem-3 fix makes that visible instead of silent.
