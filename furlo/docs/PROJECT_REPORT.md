# Furlo Project Report

## 1. Summary

Furlo is a Flutter pet health and care tracker with screens for pet profiles, care records, reminders, and settings (`lib/screens/`). It has separate SQLite and SharedPreferences-backed web pet repositories (`lib/repositories/pet_repository.dart`). The proposal's nine core feature areas have corresponding screens or UI, but the profile data-clear flow and camera capture are absent (`lib/screens/settings/profile_screen.dart`, `lib/screens/pets/pet_onboarding_screen.dart`). In the current verification run, `flutter analyze` passed, all 99 tests passed across 29 test files, and `flutter build web` succeeded; real-device and browser-interaction behavior remains [unverified].

## 2. Features

| Feature | Status (Built / Partial / Not built) | Screens | Key files | Notes and storage |
|---|---|---|---|---|
| Pet onboarding | Partial | Onboarding, Add/Edit Pet (`lib/screens/pets/pet_onboarding_screen.dart`) | `lib/models/pet.dart`, `lib/utils/pet_file_image.dart` | Name and species validation, first-letter capitalization, optional breed/birthdate, and gallery photo picking are implemented. The proposal's camera capture is not present; birthdate is optional. Pet rows/photos: SQLite `pets` on native; SharedPreferences `furlo.pets` on web (`lib/repositories/pet_repository.dart`). |
| Pet list/home | Built | Home (`lib/screens/home/home_screen.dart`) | `lib/models/pet.dart`, `lib/providers/furlo_state.dart` | Pet cards, reminders, quick actions, and bottom navigation are implemented. Pets use SQLite `pets` on native and `furlo.pets` on web; reminders read their feature collections (`lib/repositories/pet_repository.dart`, `lib/providers/home_reminders_provider.dart`). |
| Feeding | Built | Feeding (`lib/screens/feeding/feeding_screen.dart`) | `lib/models/feeding_entry.dart` | Add/edit/delete, mark-fed completion, repeat schedules, and reminders are implemented. SQLite `feeding_schedules` on native; SharedPreferences `furlo.feeding_schedules` on web (`lib/repositories/pet_repository.dart`). |
| Vaccinations | Built | Vaccinations, vaccination form (`lib/screens/vaccinations/vaccination_screen.dart`) | `lib/models/vaccination.dart` | Add/edit/delete, completion, status-derived filters, and status pills are present. Add action is exposed in the empty state or FAB depending on whether records exist (`lib/screens/vaccinations/vaccination_screen.dart`). SQLite `vaccinations` on native; SharedPreferences `furlo.vaccinations` on web (`lib/repositories/pet_repository.dart`). |
| Health records | Built | Health Records, form (`lib/screens/health/health_records_screen.dart`) | `lib/models/health_record.dart` | CRUD, validation, medication reminder toggle, and frequency fields are implemented. SQLite `health_records` on native; SharedPreferences `furlo.health_records` on web (`lib/repositories/pet_repository.dart`). |
| Vet contacts | Built | Vet Contacts, Vet Form, Vet Details (`lib/screens/vets/vet_contacts_screen.dart`) | `lib/models/vet.dart` | CRUD, pet associations, appointment dates, delete confirmation, and call action are implemented. SQLite `vets`/`vet_pets` on native; SharedPreferences `furlo.vets`/`furlo.vet_links` on web (`lib/repositories/pet_repository.dart`). |
| Weight tracking | Built | Weight Tracking, entry form (`lib/screens/weight/weight_tracking_screen.dart`) | `lib/models/weight_log.dart` | Add/edit/delete, chart, history, and positive-weight validation are implemented. SQLite `weight_logs` on native; SharedPreferences `furlo.weight_logs` on web (`lib/repositories/pet_repository.dart`). |
| Profile settings | Partial | Profile & Settings (`lib/screens/settings/profile_screen.dart`) | `lib/repositories/app_settings_repository.dart` | Display name persists in SharedPreferences under `profile.display_name` on supported platforms. The profile screen does not expose a clear-all-data confirmation or action (`lib/screens/settings/profile_screen.dart`). No sign-in UI is claimed. |
| Notifications | Built | Notifications, Notification Settings (`lib/screens/settings/notifications_screen.dart`) | `lib/services/notifications_service.dart`, `lib/providers/notification_settings_provider.dart` | Six saved toggles use SharedPreferences keys `notification.enabled.*`; permission-request state is also saved there (`lib/repositories/notification_settings_repository.dart`). A permission flow on native platforms and a web no-op notification service are implemented. Actual notification delivery is [unverified]. |

## 3. Data storage

On native/mobile, `createPetRepository()` selects `SqlitePetRepository`; database setup enables foreign keys (`lib/repositories/pet_repository.dart`). SQLite tables are `pets`, `feeding_schedules`, `vaccinations`, `health_records`, `vets`, `vet_pets`, and `weight_logs` (`lib/repositories/pet_repository.dart`). Profile display name and six notification toggles are stored by SharedPreferences repositories (`lib/repositories/app_settings_repository.dart`, `lib/repositories/notification_settings_repository.dart`).

| Collection | Native storage | Web storage |
|---|---|---|
| Pet | SQLite `pets` | SharedPreferences `furlo.pets` |
| Feeding schedule | SQLite `feeding_schedules` | SharedPreferences `furlo.feeding_schedules` |
| Vaccination | SQLite `vaccinations` | SharedPreferences `furlo.vaccinations` |
| Health record | SQLite `health_records` | SharedPreferences `furlo.health_records` |
| Vet | SQLite `vets` | SharedPreferences `furlo.vets` |
| Vet-pet association | SQLite `vet_pets` | SharedPreferences `furlo.vet_links` |
| Weight log | SQLite `weight_logs` | SharedPreferences `furlo.weight_logs` |
| Notification toggles | SharedPreferences `notification.enabled.*` | SharedPreferences `notification.enabled.*` |
| Profile display name | SharedPreferences `profile.display_name` | SharedPreferences `profile.display_name` |

On web, `createPetRepository()` selects `WebPetRepository`, which stores collections in SharedPreferences string lists under `furlo.pets`, `furlo.feeding_schedules`, `furlo.vaccinations`, `furlo.health_records`, `furlo.vets`, `furlo.vet_links`, and `furlo.weight_logs` (`lib/repositories/pet_repository.dart`). Notification settings use SharedPreferences keys; an in-memory fallback is present (`lib/repositories/notification_settings_repository.dart`). The web repository manually removes feeding schedules, vaccinations, health records, vet links, and weight logs when a pet is deleted; deleting a pet keeps its vet contact, matching SQLite foreign-key cascade behavior for the vet link (`lib/repositories/pet_repository.dart`; `test/web_persistence_test.dart`).

`pubspec.yaml` sets Dart SDK constraint `^3.12.2`. Direct dependencies are Flutter SDK, `device_preview`, `provider`, `cupertino_icons`, `image_picker`, `path`, `shared_preferences`, `sqflite`, `url_launcher`, `fl_chart`, `flutter_local_notifications`, `timezone`, `pdf`, `share_plus`, `font_awesome_flutter`, `file_picker`, and `web`; dev dependencies are `flutter_test` and `flutter_lints` (`pubspec.yaml`).

## 4. Added feature

PDF care-summary export uses `pdf` to generate bytes with bundled Noto Sans regular and bold fonts (`assets/fonts/NotoSans-Regular.ttf`, `assets/fonts/NotoSans-Bold.ttf`, `lib/services/export_service.dart`). Web Download PDF starts a browser download; on phones Save PDF opens the system save dialog and Share opens the share sheet. Generated filenames follow `furlo-<sanitized-pet-name>-summary-YYYY-MM-DD.pdf` (`lib/services/export_service.dart`). The source converts supplementary-plane characters such as emoji to `?`; visual glyph coverage and actual platform handoff remain [unverified].

## 5. Changes from the proposal

| Section | Prelim said | Now says | Why it changed |
|---|---|---|---|
| Data model | A `vet_pets` join table should represent many-to-many vet/pet associations (`../flutter-capstone-planning/app-proposal.md`) | SQLite defines `vet_pets`; web stores the corresponding `furlo.vet_links` collection (`lib/repositories/pet_repository.dart`). | Implemented the explicit association model described in the proposal. |
| Storage | Route 1: SQLite on native, web repository selected with `kIsWeb` (`../flutter-capstone-planning/app-proposal.md`) | Both native SQLite and SharedPreferences web implementations exist (`lib/repositories/pet_repository.dart`). | The proposal's web storage fallback is implemented. |
| Web photo behavior | Camera on phone; file picker/sample image on web (`../flutter-capstone-planning/app-proposal.md`) | The form calls `ImagePicker` with `ImageSource.gallery`; there is no camera capture branch. Local file-image loading has a conditional IO/stub export (`lib/screens/pets/pet_onboarding_screen.dart`, `lib/utils/pet_file_image.dart`). | The inspected source supports gallery selection, not the promised camera capture. |
| Added export | PDF plus `share_plus`, intended to work on phone and web (`../flutter-capstone-planning/app-proposal.md`) | The browser downloads the PDF; phones offer Save PDF (`file_picker`) and Share (`lib/services/export_service.dart`). | The browser share fallback did not provide a dependable file-save action. |
| PDF fonts | Not specified | Noto Sans is bundled for PDF text; supplementary-plane characters such as emoji are replaced with `?` (`lib/services/export_service.dart`). | The PDF standard fonts lack Unicode coverage. |
| Theme | Stretch goal: light/dark preference (`../flutter-capstone-planning/app-proposal.md`) | Built; Default, Light, and Dark choices are saved with `shared_preferences` and restored at startup (`lib/utils/app_theme.dart`, `lib/app.dart`). | Theme preference was completed after the MVP. |
| Photo input | Camera on phone, file picker on web (`../flutter-capstone-planning/app-proposal.md`) | Gallery/file picker is used across platforms; camera capture is not built (`lib/screens/pets/pet_onboarding_screen.dart`). | One gallery-selection path is used; camera capture remains outside the app. |
| Dependencies | Not listed in the preliminary proposal | `font_awesome_flutter`, `file_picker`, and `web` are added (`pubspec.yaml`). | Species icons, native PDF saving, and browser download support. |
| Auth | Wireframes only (`../flutter-capstone-planning/app-proposal.md`) | Accounts and sign-in are not built. | Furlo remains a single-device local tracker. |
| Stretch feature beyond proposal core | Export was listed as a stretch feature (`../flutter-capstone-planning/app-proposal.md`) | Pet profile includes “Export care summary” (`lib/screens/pets/pet_profile_screen.dart`). | This implements the selected stretch feature. |
| Pet breed picker | The nine core feature table does not specify a searchable breed catalog (`../flutter-capstone-planning/app-proposal.md`) | Species-specific searchable dog and cat breed lists are defined and used by onboarding (`lib/data/pet_breeds.dart`, `lib/screens/pets/pet_onboarding_screen.dart`). | Searchable breed selection is implemented beyond the listed core-feature requirements. |
| Profile settings | The core feature list calls for profile/settings values stored in SharedPreferences or SQLite (`../flutter-capstone-planning/app-proposal.md`) | The profile screen saves a display name, but no clear-all-data UI appears (`lib/screens/settings/profile_screen.dart`). | Display-name settings are implemented; the profile screen has no user-facing clear-all-data flow. |
| Core feature estimates | The proposal estimates 34 hours for the nine core features plus about 4–6 hours setup (~38–40 hours) (`../flutter-capstone-planning/app-proposal.md`). | Analysis and tests passed, but measured implementation hours are [unverified]. | No time measurement was part of the available code/test evidence. |
| Auth scope | The proposal says auth remains wireframes only (`../flutter-capstone-planning/app-proposal.md`). | Account/sign-in is not assessed, per task scope. | The task explicitly excludes accounts and sign-in. |
| Web notification behavior | Settings screen should remain usable while native notification delivery is unavailable in a browser (`../flutter-capstone-planning/app-proposal.md`) | A web notification service no-op is selected with `kIsWeb`; the settings screen displays a web informational banner (`lib/services/notifications_service.dart`, `lib/screens/settings/notifications_screen.dart`). | Web fallback is implemented; browser execution was not verified. |
| Proposal risks | Notification delivery while the app is closed, native-only SQLite on web, and complexity of the vet–pet join were identified risks (`../flutter-capstone-planning/app-proposal.md`). | A web repository and vet association operations/tests exist (`lib/repositories/pet_repository.dart`, `test/vet_repository_test.dart`, `test/web_persistence_test.dart`). | Web storage and join behavior have code/test coverage; real notification delivery remains [unverified]. |

## 6. Testing

Commands were run from `furlo` during this report task:

- `flutter pub get` — exit code 0; dependencies resolved.
- `flutter analyze` — exit code 0; “No issues found!”.
- `flutter test --reporter expanded` — exit code 0; **99 tests passed, 0 failed** across 29 test files; the runner ended with “All tests passed!”.
- `flutter build web` — exit code 0; web build completed successfully.


Source inventory from the requested `lib` directories:

- Screens (10): `lib/screens/feeding/feeding_screen.dart`, `lib/screens/health/health_records_screen.dart`, `lib/screens/home/home_screen.dart`, `lib/screens/pets/pet_onboarding_screen.dart`, `lib/screens/pets/pet_profile_screen.dart`, `lib/screens/settings/notifications_screen.dart`, `lib/screens/settings/profile_screen.dart`, `lib/screens/vaccinations/vaccination_screen.dart`, `lib/screens/vets/vet_contacts_screen.dart`, `lib/screens/weight/weight_tracking_screen.dart`.
- Services (2): `lib/services/export_service.dart`, `lib/services/notifications_service.dart`.
- Providers (6): `lib/providers/furlo_state.dart`, `lib/providers/health_records_provider.dart`, `lib/providers/home_reminders_provider.dart`, `lib/providers/notification_settings_provider.dart`, `lib/providers/vaccinations_provider.dart`, `lib/providers/weight_tracking_provider.dart`.
- Repositories (3): `lib/repositories/app_settings_repository.dart`, `lib/repositories/notification_settings_repository.dart`, `lib/repositories/pet_repository.dart`.
- Models (6): `lib/models/feeding_entry.dart`, `lib/models/health_record.dart`, `lib/models/pet.dart`, `lib/models/vaccination.dart`, `lib/models/vet.dart`, `lib/models/weight_log.dart`.
- Tests: 29 files and 99 test/testWidgets declarations under `furlo/test`, including short-viewport, theme restoration, and both-theme screen smoke coverage.

Test-file coverage, from test names and assertions:

| Test file | Coverage |
|---|---|
| `test/clear_all_data_test.dart` | Web repository clear-all removes pets and related records. |
| `test/export_service_test.dart` | Export filename and date formatting, summary assembly, missing pet handling, and PDF byte generation. |
| `test/feeding_repository_test.dart` | Web feeding CRUD isolation, one-time date persistence, and daily completion reset. |
| `test/feeding_screen_test.dart` | Feeding schedule create/edit/delete, completion, pet scoping, and one-time schedule behavior. |
| `test/furlo_state_test.dart` | Pet state load/add/update/delete and repository load errors. |
| `test/health_record_repository_test.dart` | Web health record CRUD, sorting, pet scoping, and cascade on pet deletion. |
| `test/health_record_test.dart` | Health record model serialization and medication reminder-field rules. |
| `test/home_reminders_provider_test.dart` | Reminder inclusion, ordering, urgency/date windows, empty results, and result cap. |
| `test/notification_service_test.dart` | Notification IDs and feeding, vaccine, appointment, medication, past-date, and disabled reminder time calculations. |
| `test/notification_settings_clear_test.dart` | Notification settings clear without removing unrelated keys and memory reset. |
| `test/notification_settings_provider_test.dart` | Toggle persistence, denied/granted permission flow, and rescheduling with a fake service. |
| `test/pet_breed_selection_test.dart` | Pet name capitalization and breed filtering across species. |
| `test/pet_delete_cascade_test.dart` | Web pet deletion removes related records and vet links. |
| `test/pet_profile_test.dart` | Pet age label formatting and missing/future dates. |
| `test/profile_settings_test.dart` | Display-name validation and save persistence with a fake settings repository. |
| `test/vaccination_model_test.dart` | Vaccination status derivation and model serialization. |
| `test/vaccination_repository_test.dart` | Web vaccination CRUD and cascade behavior. |
| `test/vaccine_catalog_test.dart` | Species-specific vaccine catalog selection and unknown species. |
| `test/vet_repository_test.dart` | Vet/pet associations, join queries, appointment retention, and deleting vets/pets. |
| `test/vet_validation_test.dart` | Vet model mapping and phone/email validation. |
| `test/web_persistence_test.dart` | Web persistence across repository instances, clear-all, and pet-delete cascades. |
| `test/weight_repository_test.dart` | Web weight CRUD, sorting, scoping, and pet-delete cascade. |
| `test/weight_screen_test.dart` | Weight chart empty, one-entry, and 30-entry rendering. |
| `test/weight_tracking_test.dart` | Weight model, invalid-weight rejection, and change calculations. |
| `test/widget_test.dart` | Startup routes to onboarding without pets and home with a saved pet. |
| `test/short_viewport_overflow_test.dart` | Feeding, vaccination, health, vet, weight, and vet-detail screens at short viewport sizes and text scales. |
| `test/notifications_short_viewport_test.dart` | Notifications empty state at 400×300, two text scales, and both themes. |
| `test/vet_contacts_screen_test.dart` | Vet card reachability by scrolling across data counts, viewport sizes, and text scales; Call tap target. |
| `test/theme_smoke_test.dart` | Saved theme restoration plus all twelve requested screens in light and dark themes. |

## 7. Platform behavior

- Repository selection uses `kIsWeb`: SQLite on native platforms, `WebPetRepository` on web (`lib/repositories/pet_repository.dart`). The web repository uses SharedPreferences; `test/web_persistence_test.dart` covers persistence between instances in the test environment. A real browser run is [unverified].
- Pet photo selection requests the gallery (`ImageSource.gallery`) and catches picker errors (`lib/screens/pets/pet_onboarding_screen.dart`). The proposal's camera capture is absent from the inspected app source. File image access is isolated with a conditional IO/stub export (`lib/utils/pet_file_image.dart`, `lib/utils/pet_file_image_io.dart`, `lib/utils/pet_file_image_stub.dart`). Actual browser picker behavior is [unverified].
- Notification service creation returns `NoOpNotificationService` on web and `LocalNotificationService` otherwise (`lib/services/notifications_service.dart`). Notification settings show a web-only message that reminders fire only on mobile (`lib/screens/settings/notifications_screen.dart`). Native permission and notification delivery are [unverified] because they were not exercised on a device.
- `DevicePreview` wraps `FurloApp` in `main.dart` (`lib/main.dart`).
- PDF export uses bundled Noto Sans; web uses the browser download helper, and native offers file save and share (`lib/services/export_service.dart`). Actual browser download and phone dialogs remain [unverified].

## 8. Known limitations

- Noto Sans is bundled for PDF text; supplementary-plane characters such as emoji are converted to `?` (`lib/services/export_service.dart`). The fonts' license/attribution file was not present in the inspected repository, and visual glyph coverage still needs manual checking.
- `NotificationsScreen`'s empty state now scrolls when its content exceeds the available height and stays centered when it fits; short-height overflow coverage is in `test/notifications_short_viewport_test.dart`.
- The profile screen supports display-name editing and notification preferences but has no clear-all-data control (`lib/screens/settings/profile_screen.dart`). Repository clear-all methods exist and are covered for web, but a user-facing confirmed flow is absent (`lib/repositories/pet_repository.dart`, `test/clear_all_data_test.dart`).
- The proposal's camera capture is not present; only gallery selection is found (`lib/screens/pets/pet_onboarding_screen.dart`).
- TODOs found in source/project files: `android/app/build.gradle.kts:19` (application ID), `android/app/build.gradle.kts:31` (release signing), `linux/flutter/CMakeLists.txt:9` and `windows/flutter/CMakeLists.txt:9` (generated CMake template TODOs). No TODO/FIXME markers were found in Dart files under `lib`.
- [unverified] Real-device notification delivery, native SQLite persistence across actual app restart, browser screen reachability, actual PDF sharing/download, actual visual theme rendering, and real photo-picker operation were not tested in this task.

## 9. Not built

Among the proposal's stretch goals (`../flutter-capstone-planning/app-proposal.md`), these are not implemented in the inspected `lib/` source; no corresponding feature implementation was found:

1. Multi-user/shared pet care.
2. Calendar view for vaccination/vet appointments.
3. Vet clinic map/location UI.
4. Vet document/receipt scanner.
5. Pet breed/weight-context tips.
6. Weekly care summary.

Accounts and an AI assistant are not built. Default, Light, and Dark theme choices are implemented and persisted (`lib/utils/app_theme.dart`).

The pet-photo camera capture mentioned in proposal platform behavior is also not implemented; the form uses gallery selection (`lib/screens/pets/pet_onboarding_screen.dart`).

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

1. Run and manually verify Android/iOS persistence, permission handling, and at least one delivered notification.
2. Run the web app and manually navigate every screen; exercise browser photo selection and PDF download/share.
3. Add or formally de-scope the proposed pet camera-capture behavior.
4. Manually inspect PDF output for accented and unsupported characters; automated tests check PDF generation but not visual glyph rendering.
5. Exercise short-height layouts in a browser or emulator, including Feeding and the scrollable Notifications empty state.
6. Add a confirmed clear-all-data control to Profile & Settings or explicitly remove that promised user-facing behavior from the scope.
7. Replace the Android template application ID and configure release signing before a release build (`android/app/build.gradle.kts`).
8. Complete app-specific TODOs and review generated Linux/Windows CMake template TODOs (`linux/flutter/CMakeLists.txt`, `windows/flutter/CMakeLists.txt`).
