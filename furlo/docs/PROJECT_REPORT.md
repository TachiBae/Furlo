# Furlo Project Report

## 1. Summary

*Updated 2026-10-14 on branch `feature/five-star`.*

Furlo is a Flutter pet health and care tracker with accounts. Each signed-in account's pets and records live in Cloud Firestore under `users/{uid}` (`lib/repositories/firestore_pet_repository.dart`), protected by owner-only, field-checked rules (`firestore.rules`). The proposal's nine core feature areas are built, plus camera capture on phones, a vaccine timeline, weight trends, notification taps and a Mark fed action, Delete all my data, account deletion and a privacy note. `flutter analyze` reports no issues and all 430 tests pass across 87 test files; a clean release web build starts to the sign-in screen at 375 and 1440 px in headless Chrome. Real-device notification delivery, the camera, and signed-in offline behaviour are [unverified].

## 2. Features

| Feature | Status | Key files | Notes |
|---|---|---|---|
| Accounts | Built | `lib/screens/auth/`, `lib/services/firebase_auth_service.dart`, `lib/providers/session_controller.dart` | Email/password, Google, password reset, complete-profile step, account deletion (re-authenticates first). Real Firebase sign-in is [unverified] in tests (faked). |
| Pet onboarding | Built | `lib/screens/pets/pet_form_screen.dart`, `lib/utils/photo_fit.dart` | Validation, searchable breeds, camera (phones) or library/file picker; photos shrunk to fit the account. |
| Pet list / home | Built | `lib/screens/home/` | Pet tiles, Today's Reminders (refresh on return, Mark fed from the dashboard), quick actions. |
| Feeding | Built | `lib/screens/feeding/feeding_screen.dart`, `lib/models/feeding_entry.dart` | Daily, twice daily (two times), weekly/custom days, one date; reminders only on scheduled days. |
| Vaccinations | Built | `lib/screens/vaccinations/vaccination_screen.dart`, `lib/utils/vaccine_timeline.dart` | Status from dates, filters, per-pet timeline. |
| Health records | Built | `lib/screens/health/health_records_screen.dart` | CRUD, medication reminders. |
| Vet contacts | Built | `lib/screens/vets/vet_contacts_screen.dart` | Vet–pet many-to-many links (`vetLinks`), appointments kept when a vet is edited. |
| Weight tracking | Built | `lib/screens/weight/weight_tracking_screen.dart`, `lib/utils/weight_tracking.dart` | Chart, history, plain-words monthly trend. |
| Profile & settings | Built | `lib/screens/settings/` | Display name on the account, theme, notifications, privacy note, Delete all my data, Delete account. |
| Notifications | Built | `lib/services/notifications_service.dart` | Local reminders on iOS/Android; taps open the right screen; Mark fed action. Delivery on a device is [unverified]. |

## 3. Data storage

`createPetRepository(storageScope: uid)` returns `FirestorePetRepository` for the signed-in account. Collections under `users/{uid}`: `pets`, `feedings`, `vaccinations`, `healthRecords`, `weightLogs`, `vets`, `vetLinks` (the vet–pet join), plus `settings/profile` and `settings/meta`; `accountMetadata/{uid}` holds the first-pet flag. Reads that summarise every pet (reminders, the vet list, reminder scheduling) read each collection once rather than per pet.

On the device, `shared_preferences` keeps notification toggles, the theme, a cached display name and cached pet photos. The earlier on-device stores (`SqlitePetRepository` on mobile, `WebPetRepository` on web, under `lib/repositories/legacy/`) are read only by the one-time, consented import of pre-account data, which never modifies them.

## 4. Added feature

PDF care-summary export uses `pdf` to generate bytes with bundled Noto Sans regular and bold fonts (`assets/fonts/NotoSans-Regular.ttf`, `assets/fonts/NotoSans-Bold.ttf`, `lib/services/export_service.dart`). Web Download PDF starts a browser download; on phones Save PDF opens the system save dialog and Share opens the share sheet. Generated filenames follow `furlo-<sanitized-pet-name>-summary-YYYY-MM-DD.pdf` (`lib/services/export_service.dart`). The source converts supplementary-plane characters such as emoji to `?`; visual glyph coverage and actual platform handoff remain [unverified].

## 5. Changes from the proposal

| Section | Prelim said | Now says | Why it changed |
|---|---|---|---|
| Data model | A `vet_pets` join table should represent many-to-many vet/pet associations (`../flutter-capstone-planning/app-proposal.md`) | Firestore `vetLinks` documents (one per vet–pet pair) carry the link and next appointment (`lib/repositories/firestore_pet_repository.dart`). | Same many-to-many model, stored in the cloud. |
| Storage | Route 1: SQLite on native, web repository selected with `kIsWeb` (`../flutter-capstone-planning/app-proposal.md`) | Cloud Firestore per account; the local stores remain only as import sources. | Accounts were added, so data follows the account across devices. |
| Web photo behavior | Camera on phone; file picker/sample image on web (`../flutter-capstone-planning/app-proposal.md`) | Camera or library on phones, file picker on web (`lib/screens/pets/pet_form_screen.dart`). | Built as proposed. |
| Added export | PDF plus `share_plus`, intended to work on phone and web (`../flutter-capstone-planning/app-proposal.md`) | The browser downloads the PDF; phones offer Save PDF (`file_picker`) and Share (`lib/services/export_service.dart`). | The browser share fallback did not provide a dependable file-save action. |
| PDF fonts | Not specified | Noto Sans is bundled for PDF text; supplementary-plane characters such as emoji are replaced with `?` (`lib/services/export_service.dart`). | The PDF standard fonts lack Unicode coverage. |
| Theme | Stretch goal: light/dark preference (`../flutter-capstone-planning/app-proposal.md`) | Built; Default, Light, and Dark choices are saved with `shared_preferences` and restored at startup (`lib/utils/app_theme.dart`, `lib/app.dart`). | Theme preference was completed after the MVP. |
| Photo input | Camera on phone, file picker on web (`../flutter-capstone-planning/app-proposal.md`) | Built; photos are shrunk to fit the account (`lib/utils/photo_fit.dart`). | Camera capture added. |
| Dependencies | Not listed in the preliminary proposal | Added: `font_awesome_flutter`, `file_picker`, `web`, the Firebase packages and `google_sign_in`; dev-only `fake_cloud_firestore`. `cupertino_icons` removed (unused). | Icons, PDF saving, browser download, accounts and cloud data, and Firestore tests. |
| Auth | Wireframes only (`../flutter-capstone-planning/app-proposal.md`) | Built: email/password, Google, password reset, complete-profile, account deletion. | Needed for cloud sync across devices. |
| Stretch feature beyond proposal core | Export was listed as a stretch feature (`../flutter-capstone-planning/app-proposal.md`) | Pet profile includes “Export care summary” (`lib/screens/pets/pet_profile_screen.dart`). | This implements the selected stretch feature. |
| Pet breed picker | The nine core feature table does not specify a searchable breed catalog (`../flutter-capstone-planning/app-proposal.md`) | Species-specific searchable dog and cat breed lists are defined and used by onboarding (`lib/data/pet_breeds.dart`, `lib/screens/pets/pet_onboarding_screen.dart`). | Searchable breed selection is implemented beyond the listed core-feature requirements. |
| Profile settings | The core feature list calls for profile/settings values stored in SharedPreferences or SQLite (`../flutter-capstone-planning/app-proposal.md`) | Display name on the account (cached locally); theme and notification settings on the device; Delete all my data and Delete account. | The name follows the account; data deletion is user-facing. |
| Core feature estimates | The proposal estimates 34 hours for the nine core features plus about 4–6 hours setup (~38–40 hours) (`../flutter-capstone-planning/app-proposal.md`). | Analysis and tests passed, but measured implementation hours are [unverified]. | No time measurement was part of the available code/test evidence. |
| Auth scope | The proposal says auth remains wireframes only (`../flutter-capstone-planning/app-proposal.md`). | Accounts are built (see Auth). | Scope grew to support sync. |
| Web notification behavior | Settings screen should remain usable while native notification delivery is unavailable in a browser (`../flutter-capstone-planning/app-proposal.md`) | A web notification service no-op is selected with `kIsWeb`; the settings screen displays a web informational banner (`lib/services/notifications_service.dart`, `lib/screens/settings/notifications_screen.dart`). | Web fallback is implemented; browser execution was not verified. |
| Proposal risks | Notification delivery while the app is closed, native-only SQLite on web, and complexity of the vet–pet join were identified risks (`../flutter-capstone-planning/app-proposal.md`). | Web storage moved to Firestore; the vet–pet join is tested against the real store's API; delivery on a device remains [unverified]. | Risks reduced by the cloud move and tests. |

## 6. Testing

Run from `furlo/` on 2026-10-14:

- `flutter analyze` — exit 0, "No issues found!".
- `flutter test` — exit 0, **430 tests passed** across 87 test files.
- `flutter test --platform chrome test/photo_fit_test.dart` — passed (photo shrinking verified on the web engine).
- `flutter build web --release` from a clean checkout — built; in headless Chrome it reaches the sign-in screen at 375 and 1440 px with no console errors.
- `flutter build apk --debug` — built (Android notification action receiver compiles).

Notable coverage added on this branch: the Firestore repository against `fake_cloud_firestore` (CRUD, cascades past the 400-write batch, per-account isolation, vet links, damaged documents), the session controller, feeding reminder planning (weekly days, twice daily), notification taps, provider disposal races, the legacy import's id handling, account deletion order, contrast (WCAG AA) for every palette, and a guard that keeps form fields on the theme's input style.

`tool/ui_capture_test.dart` (not part of `flutter test`) renders real screens at 375 and 1440 px in all three themes for visual review, and writes a sample care-summary PDF.

## 7. Platform behavior

- Data is Cloud Firestore on every platform. Mobile keeps Firestore's offline cache by default; web asks for one at startup (`lib/services/firestore_setup.dart`). Signed-in offline behaviour on web is [unverified].
- Pet photos: camera or library on Android/iOS, file picker on web and desktop; all photos are shrunk to fit the account.
- Notifications: `LocalNotificationService` on mobile (with tap routing and a Mark fed action), `NoOpNotificationService` on web with an informational banner.
- `DevicePreview` wraps the app, always on for web.
- PDF export: browser download on web; save dialog and share sheet on phones.

## 8. Known limitations

- `firestore.rules` must be deployed for twice-daily second meal times to save, and for account deletion to delete (rather than blank) the profile records.
- Real-device notification delivery, the Mark fed action, the camera and Firebase re-authentication were not exercised on a device.
- Saves made while offline wait for the connection before they finish.
- PDF text uses Noto Sans; emoji become `?`. The font licence file is still not bundled.
- Android still uses the template application id and debug signing (`android/app/build.gradle.kts`).

## 9. Not built

From the proposal's stretch goals: multi-user/shared pet care, calendar view, vet map, document/receipt scanner, breed/weight-context tips, weekly summary, and an AI assistant.

## 10. How to run

From the `furlo` project directory:

```sh
flutter pub get
flutter run
```

For the web-server target:

```sh
flutter pub get
flutter run -d web-server
```

## 11. Manual testing log

| Check | Result | Date | Notes |
|---|---|---|---|
| Web run with every screen reachable |  |  |  |
| Android or iOS run with data surviving a full app restart |  |  |  |
| One real notification fired |  |  |  |
| Vet linked to two pets and deleting a vet |  |  |  |
| PDF export on web and phone |  |  |  |
| Validation (empty name, future birthdate, negative weight) |  |  |  |
| Screens at short window height |  |  |  |
| Species and breed menus |  |  |  |
| Vaccination add buttons |  |  |  |

## 12. Screenshots

Screenshots were not captured in this automated run. The image references below list the intended screenshot filenames; add current captures in both themes after manual QA.

![Home](screenshots/home.png)

![Pet profile](screenshots/pet-profile.png)

![Feeding](screenshots/feeding.png)

![Vaccinations](screenshots/vaccinations.png)

![Health records](screenshots/health-records.png)

![Vet contacts](screenshots/vet-contacts.png)

![Weight tracking](screenshots/weight-tracking.png)

![Profile](screenshots/profile.png)

![Notification settings](screenshots/notification-settings.png)

## 13. Open items

1. Deploy `firestore.rules`.
2. On a phone: confirm a delivered reminder, the Mark fed action, the camera, and re-authentication before account deletion.
3. On web while signed in: confirm offline loading.
4. Replace the Android application id and configure release signing.
5. Bundle the Noto Sans licence (SIL OFL) with the font assets.

