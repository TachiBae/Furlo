# Task List: Make the account system work via cloud

Status after implementation. Items marked `[x]` are done and covered by
`flutter analyze` / `flutter test`; items left `[ ]` need a browser or the
Firebase console and were not verifiable in this run.

## Problem 1 — pet data must sync across devices

- [x] Switch models (`Pet`, `FeedingEntry`, `HealthRecord`, `Vaccination`, `Vet`,
      `VetPetAssociation`, `WeightLog`) to String ids / String `petId`.
- [x] Add `FirestorePetRepository implements PetRepository` under `users/{uid}/…`
      (pets, feedings, vaccinations, healthRecords, weightLogs, vets, vetLinks; every child
      carries `pet_id`).
- [x] Implement cascade deletes in `WriteBatch` (pet → children + vetLinks; vet → vetLinks;
      `clearAllData` → whole collections), chunked at 400 ops per commit.
- [x] Choose the repository from auth state in `createPetRepository` (now
      `required String storageScope`); local impls are read-only legacy readers.
- [x] Exclude `photoPath` from the Firestore pet document; keep photos in
      `LocalPetPhotoStore`, device-local and keyed per account.
- [x] Add `users/{uid}/{document=**}` rule to `firestore.rules`, above the deny-all fallback.
- [x] Tests: String id round-trips (existing model tests), photo store isolation.
- [ ] Tests for cascade batching and per-uid path scoping: needs a Firestore double, which
      would be a new dependency. Verified by reading only.

## Problem 2 — a brand-new account must see pre-account data

- [x] `lib/services/legacy_local_migration.dart`: reads unscoped (`furlo.pets`, `furlo.db`)
      and scoped (`furlo.user.<token>.*`) rows, keeps their String ids, writes to
      `users/{uid}/…`.
- [x] Guarded by `MigrationMarker` (`users/{uid}/settings/meta.localMigratedAt`) and by the
      empty-cloud check.
- [x] Never deletes or rewrites local storage.
- [x] Runs at session start before `furloState.load()`; non-fatal on error.
- [x] Tests: runs once, leaves local data intact, preserves ids, skips when the account
      already has cloud pets, a failing marker does not throw.

## Problem 3 — account setup failures must explain themselves

- [x] Replace `catch (_)` in `_loadAccountStatus` with error capture.
- [x] Surface the Firebase error code on the "Your account setup could not be loaded."
      screen (`Cause: …`) and in `logAppDiagnostic`.
- [x] Tests: `permission-denied` and `unavailable` codes are shown, an uncoded error falls
      back to its type, the retry button remains.

## Finish

- [x] `dart format` on touched files.
- [x] `flutter analyze` clean.
- [x] `flutter test` — full suite passes (158 tests).
- [ ] `flutter run -d web-server`: same account on two devices/profiles shares pets
      (problem 1); device with pre-account pets shows them after sign-in (problem 2);
      unpublished rules produce a named cause (problem 3). **Needs a browser — not run.**
- [x] Report files changed, test results, and what was verified by running versus reading.
