# Task List — Cloud Pet Photos

Status: **COMPLETE** (pairs with `CLOUD_PHOTO_PLAN.md`). Approved via ask_questions,
then implemented on `fix/ui-audit`.

- [x] 0. Approved and branch confirmed: stayed on `fix/ui-audit`.
- [x] 1. Repository: `cloudPhotoField` helper + `'photo'` field in `_petData`,
      cloud-first/local-fallback read (`resolvePetPhoto`) in `getPets`, diagnostic log
      for local-only payloads, refreshed photo comments.
- [x] 2. Photo store: legacy-key fallback read in `LocalPetPhotoStore` (repin into scope).
- [x] 3. Picker: `maxWidth: 640, maxHeight: 640` added to `_choosePhoto`.
- [x] 4. Tests: `test/cloud_photo_field_test.dart` (8 tests) + legacy-fallback group
      in `test/pet_photo_store_test.dart` (3 tests).
- [x] 5. Gates: `flutter analyze --no-pub` exit 0 (“No issues found!”);
      `flutter test --no-pub` exit 0 — 201/201 passed.
- [x] 6. Browser verification (web-server :8123): photo add renders at 375 and 1440;
      two full storage wipes (localStorage + sessionStorage + IndexedDB) with fresh
      sign-ins proved both the initial photo and a changed photo reload from Firestore
      (`users/{uid}`); zero console errors; Firestore Listen/channel traffic confirmed.
- [x] 7. Local commit(s) (no push, no deletions).
