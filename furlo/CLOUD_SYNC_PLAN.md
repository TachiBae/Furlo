# Implementation Plan: Store app data in the cloud instead of locally

## Goal

Care records and settings are written to the signed-in account's Firestore data, not to
device storage. Local sqflite/SharedPreferences stop being the system of record.

## Decisions confirmed by the user

1. **Firestore only, no cache** — disable Firestore's persistent (on-disk/IndexedDB) cache.
   Reads and writes need a connection; nothing is persisted to the device by the SDK.
2. **Migrate existing local records once** — copy rows already on the device into the
   account's cloud data on first session after the change. Local files are left in place.
3. **Everything, settings included** — care records *and* notification/app settings move to
   per-user cloud documents.

## Current state

- All care data goes through `PetRepository` (`lib/repositories/pet_repository.dart`):
  `SqlitePetRepository` on native, `WebPetRepository` on web, selected by `kIsWeb` at
  `createPetRepository(storageScope: uid)` (line 48). Interface is 35 methods.
- `SharedPreferencesNotificationSettingsRepository` and
  `SharedPreferencesAppSettingsRepository` are constructed directly in `app.dart:250`,
  `home_screen.dart:45`, `pet_profile_screen.dart:119`, `feeding_screen.dart:642`.
- Firestore today holds one collection only: `accountMetadata/{uid}.requiresFirstPet`
  (`lib/services/account_onboarding_repository.dart`), behind the deny-all rules in
  `furlo/firestore.rules`.
- Models use nullable `int` ids and int foreign keys (`petId`), so every screen and test
  depends on that shape.
- 25 test files call `SharedPreferences.setMockInitialValues`.
- `clearAllData()` has no production caller; it is exercised by `clear_all_data_test.dart`.

## Proposed design

### 1. Firestore layout (per signed-in account)

```
users/{uid}/pets/{petId}
users/{uid}/feedingSchedules/{id}
users/{uid}/healthRecords/{id}
users/{uid}/vaccinations/{id}
users/{uid}/vets/{id}
users/{uid}/vetLinks/{vetId}_{petId}      # mirrors VetPetAssociation 1:1
users/{uid}/weightLogs/{id}
users/{uid}/petPhotos/{petId}             # photoPath moved out of the pet doc, see Risks
users/{uid}/settings/app                   # displayName
users/{uid}/settings/notifications         # enabled map
users/{uid}/settings/meta                  # migration marker + schema version
```

Document ids are the existing `int` ids rendered as strings (`pets/3`). Field names come
straight from each model's `toMap()` so model code does not change.

### 2. Keep the domain interface unchanged

`PetRepository`, `NotificationSettingsRepository` and `AppSettingsRepository` keep their
exact method signatures. Only their implementations are replaced, which leaves every
screen, provider and model untouched. `int` ids are preserved by allocating
`max(existing ids) + 1` before each insert — the same rule `WebPetRepository` already uses
today.

### 3. A small cloud seam so the logic is testable without new packages

```dart
abstract interface class CloudDocumentStore {
  Future<Map<String, Object?>?> read(String path);
  Future<void> write(String path, Map<String, Object?> data, {bool merge});
  Future<List<CloudDocument>> query(String collection, {...});
  Future<void> delete(String path);
  Future<void> deleteCollection(String collection);
}
```

`FirestoreCloudStore` wraps `FirebaseFirestore`; `InMemoryCloudStore` is a hand-written
test double in `test/helpers/`. New implementations (`FirestorePetRepository`,
`FirestoreNotificationSettingsRepository`, `FirestoreAppSettingsRepository`) take a
`CloudDocumentStore` plus `uid`.

Rationale: `fake_cloud_firestore` would be a new dependency, which this project does not
allow, and tests must still assert real paths, id allocation and cascade behaviour.

### 4. Turn the cache off

In `main()`, immediately after `Firebase.initializeApp` and before any repository is
created:

```dart
FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
```

`Settings` documents that settings must be set before any other Firestore method runs, so
this cannot move later.

### 5. One-time local → cloud migration

- Runs inside `_AuthGateState._startSession(uid)` before `furloState.load()`.
- Guarded by `users/{uid}/settings/meta.localMigratedAt`; also skipped when the cloud
  `pets` collection is already non-empty, so it cannot duplicate data on re-run.
- Reads legacy data through the existing `SqlitePetRepository` / `WebPetRepository`
  **read-only** (`getPets`, `getFeedingSchedules`, …), writes to the cloud with ids
  preserved.
- **Never deletes or rewrites local storage** — no destructive migration.
- Failure is non-fatal: log via `logAppDiagnostic`, keep the existing local data, and let
  the user retry rather than losing a session.

### 6. Security rules

Add above the deny-all fallback in `furlo/firestore.rules`:

```
match /users/{uid}/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}
```

`accountMetadata` keeps its existing, stricter rule.

### 7. What stays on the device (and why)

- **Theme** (`ThemeSettings`, `app.theme_mode`) — it is loaded in `FurloApp.initState`
  before any account exists, so there is no `uid` to key it by. No cloud write remains for it.
- **Notification scheduling** — `flutter_local_notifications` schedules on the device by
  nature; only the *toggles* move to the cloud (decision 3).
- **Exports** (PDF/share/file_picker) — user-initiated output, not storage.

## Files to change

| File | Change |
| --- | --- |
| `lib/repositories/cloud_document_store.dart` | new seam + `InMemoryCloudStore` lives in tests |
| `lib/repositories/firestore_cloud_store.dart` | new `FirestoreCloudStore` |
| `lib/repositories/pet_repository.dart` | add `FirestorePetRepository`; keep `SqlitePetRepository`/`WebPetRepository` as read-only legacy used by migration |
| `lib/repositories/notification_settings_repository.dart` | add Firestore implementation |
| `lib/repositories/app_settings_repository.dart` | add Firestore implementation |
| `lib/services/local_cloud_migration.dart` | new one-time migrator |
| `lib/main.dart` | disable persistence before any other Firestore call |
| `lib/app.dart` | construct cloud repositories in `_startSession`, run migration |
| `lib/screens/home/home_screen.dart`, `lib/screens/pets/pet_profile_screen.dart`, `lib/screens/feeding/feeding_screen.dart` | swap repository class at the construction sites |
| `furlo/firestore.rules` | per-user `users/{uid}` rule |

No changes to `lib/models/`, `lib/providers/`, or the `PetRepository` interface.

## Verification

1. `dart format` on touched files; `flutter analyze` clean.
2. `flutter test` — all 145 existing tests keep passing. Tests that asserted
   SharedPreferences scoping are retargeted to assert cloud paths via `InMemoryCloudStore`
   (`user_data_scope_test`, `app_settings_scope_test`, `web_persistence_test`,
   `*_repository_test`, `clear_all_data_test`, `pet_delete_cascade_test`).
3. New tests: id allocation, cascade delete of a pet's subcollections, migration copying
   legacy rows exactly once and leaving local storage untouched, rules-shaped path
   scoping per uid.
4. `flutter run -d web-server`, sign in, add a pet, restart the browser, sign in again and
   confirm the pet is still there — this is the acceptance test for the original bug.
5. Confirm in the Firebase console that documents land under `users/{uid}/…` and that no
   new keys appear in SharedPreferences/IndexedDB after a write.

## Safety and scope

- No destructive migration: local databases and preference keys are read, never cleared.
- No new dependencies; `sqflite`/`shared_preferences` stay because migration reads and
  theme still need them.
- `IMPLEMENTATION_PLAN.md` / `TASK_LIST.md` belong to the pending analyzer task and are not
  touched; this work uses its own `CLOUD_SYNC_*` documents.
- Changes stay uncommitted for review.

## Risks

1. **Photos.** `photoPath` holds a base64 `data:` URI (`pet_onboarding_screen.dart:221`,
   quality 85). Firestore caps a document at 1 MB, so a large photo can make the whole pet
   write fail. Plan stores photos in `users/{uid}/petPhotos/{petId}` so the pet record
   survives, and reports a clear error if the photo alone exceeds the cap. Revisit if a
   real photo fails — moving them to Cloud Storage would need a new package.
2. **Offline behaviour.** With persistence off, losing the connection makes reads fail
   rather than fall back to a cache. This matches decision 1 and does not worsen the app's
   existing state, since `main()` already refuses to run without Firebase.
3. **Extra round trips.** `FurloState` re-reads after every mutation, so each save is a
   write plus a query. Acceptable at pet-tracker data volumes; measurable, not guessed at,
   once running.
4. **`permissionWasRequested`** reflects an OS permission, which is per-device. Moving it
   to the cloud means another device inherits it; keep it device-local and move only the
   toggles unless you want it synced too.
