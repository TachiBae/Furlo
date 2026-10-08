# Implementation Plan — Cloud Pet Photos (per account)

Status: **DRAFT — awaiting approval.** Branch: current `fix/ui-audit` (contains the
`feature/accounts` cloud code; see Task 0 for branch confirmation).

## Goal

Pet profile pictures must be saved to the cloud **per account**, not only on the local
device, so they follow the signed-in account across devices.

## Current behavior (verified by reading code)

- `Pet.photoPath` holds a base64 data URI (created in `pet_onboarding_screen._choosePhoto`
  at `imageQuality: 85`, **no maxWidth**) or a legacy device file path.
- `FirestorePetRepository` already syncs every pet field to Firestore under
  `users/{uid}/…` (the per-account scope), **except the photo**: `_petData` omits it and
  photos go only to `LocalPetPhotoStore` (SharedPreferences, uid-scoped key).
- Rationale in code comments: Firestore documents cap at 1 MB and an un-resized photo
  base64 easily exceeds that.

## Design decision: embed the photo in the pet document (no new dependencies)

Two candidate approaches:

1. **Embed base64 `photo` field in the pet Firestore document**, made small at pick time
   by downscaling. → **chosen.** No new dependency, no bucket/rules changes, rides the
   existing `users/{uid}` scope and security rules, works offline-friendly like the rest
   of the data.
2. Cloud Storage for Firebase (`firebase_storage`) — proper for arbitrary-size media but
   adds a dependency, a storage bucket, and storage rules the user would have to deploy.
   Rejected under the project's "no new dependencies" rule unless the user requests it.

### Changes

1. **Pick-time downscale** — `pet_onboarding_screen._choosePhoto`:
   add `maxWidth: 640, maxHeight: 640` (keep `imageQuality: 85`). A 640px avatar JPEG
   base64s to roughly 50–150 KB. Verified: `image_picker_for_web 3.1.1` implements
   `maxWidth`/`imageQuality` via canvas resize, so this holds on web; mobile uses native
   resize.
2. **Repository cloud field** — `FirestorePetRepository`:
   - New top-level helper `cloudPhotoField(String? photoPath)` → returns the data URI only
     if it is a `data:` URI and its length ≤ **600 KB** (headroom under the 1 MB doc cap);
     returns `null` for legacy file paths and oversized payloads.
   - `_petData` gains `'photo': cloudPhotoField(pet.photoPath)` — `set()` replaces the
     whole document, so an omitted/null value also clears a stale cloud photo.
   - Reads (`getPets`): `photo = doc['photo'] ?? await _photos.read(doc.id)` — cloud
     first, local store as fallback for legacy/oversized photos.
   - Writes (`addPet`/`updatePet`): keep the existing `LocalPetPhotoStore` mirror so
     offline display and legacy fallback keep working; if the payload is over-threshold
     or a file path, it stays local-only and `logAppDiagnostic` records that.
   - `deletePet` already clears both doc and local store (no change).
   - Update the now-stale doc comments ("photos never written to Firestore").
3. **Scope** — no change needed: `storageScope == uid` and the Firestore path
   `users/{uid}` already give per-account isolation; `user_storage_scope.dart` untouched.
   (If "scope" meant widening the task's allowed resources — e.g. adding
   `firebase_storage` — that is explicitly *not* required by this plan.)
4. **Legacy unscoped photos** — `LocalPetPhotoStore.read` gains a fallback to the legacy
   `photo.pet.$petId` key when the scoped key is absent, so photos taken before
   per-account scoping still resolve after sign-in (they then mirror to the scoped key on
   the next save). This is what makes "photo follows the account" true for existing users.

## Out of scope / known limitations

- Legacy photos that are already oversized or file paths cannot be re-encoded to JPEG
  without a new dependency; they remain local-only until the user re-picks a photo (which
  now downscales and therefore syncs).
- No `fake_cloud_firestore` in dev_dependencies, so full Firestore-repository integration
  tests are not added (would require a new dev dependency). Logic is extracted into pure,
  unit-tested helpers; end-to-end behavior is verified in the browser (Task 6).

## Verification gates

- `flutter analyze --no-pub` and `flutter test --no-pub` must exit 0 (captured).
- New unit tests: `cloudPhotoField` threshold/data-URI/file-path rules; local store
  legacy-key fallback; cloud-first/local-fallback merge helper.
- Browser run (`flutter run -d web-server`) per project workflow: add/change a pet photo,
  confirm it renders at 375px and 1440px; clear site storage and reload — pet + photo
  must still render, proving the photo now comes from the account's Firestore data.
- Commit locally per completed task; no push, no file deletions.
