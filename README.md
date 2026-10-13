# Furlo

Furlo is a pet health and care tracker for owners managing one to three pets at home.

> **AI credit:** I used Codebuff for code edits, debugging, and test iteration, with Claude for planning/explanations and some ChatGPT assistance. I reviewed generated work and documented contributions and mistakes in [AI-USAGE.md](AI-USAGE.md).

## Features

Implemented in the Flutter app under `furlo/`:

- **Accounts** — email/password sign-up and sign-in, Google sign-in, password reset, and a complete-profile step for new Google accounts. Each account's data is private to it.
- **Cloud sync** — pets and every record live in the signed-in account (Cloud Firestore), so they follow you to any device. Pre-account data on a device can be imported once, with consent.
- **Pet onboarding and profiles** — add/edit pets (species, searchable breed, birth date, photo from the camera on phones or from the library/file picker), per-pet profile with care-record shortcuts and delete. Photos are shrunk to fit the account.
- **Home dashboard** — pet carousel, Today's Reminders (refreshes when you return from a screen; mark a meal fed right there), quick actions into care screens
- **Feeding** — per-pet schedules: daily, twice daily (two meal times), weekly or custom days, or one date; portion, mark fed, optional reminders
- **Vaccinations** — CRUD, due-date status, vaccine catalog helpers, and a per-pet timeline of doses given and due
- **Health records** — CRUD by type (checkup, medication, illness/injury, surgery, lab test, other), notes, optional medication reminders
- **Vet contacts** — vets linked to pets (many-to-many), next appointment per pet, phone launch via `url_launcher`
- **Weight tracking** — weight log CRUD, a trend line chart (`fl_chart`) and a plain-words trend ("+0.4 kg in the last month")
- **Notifications** — local notifications on iOS/Android (`flutter_local_notifications`); weekly schedules remind only on their days; tapping a reminder opens the right screen for the right pet; feeding reminders have a Mark fed button
- **Profile and settings** — display name (saved on the account), Default/Light/Dark theme, notification preferences, a privacy note, Delete all my data, and Delete account
- **Export care summary** — PDF care summary per pet with the pet's photo and an "At a glance" section (weight trend, next vaccine, next vet visit). On web, Download PDF saves the file through the browser. On phones, Save PDF opens the system save dialog and Share opens the share sheet. PDF text uses Noto Sans, so accented letters are kept. Emoji and characters the font doesn't contain may appear as `?` or be missing.

## Known limitations

- **Web offline** — the web build asks Firestore for an offline cache; behaviour while signed in and offline has not been verified on a real device. Saves made offline wait for the connection to return before they finish.
- **Web notifications** — `NoOpNotificationService`; reminder settings work but nothing is scheduled in the browser.
- **Firestore rules** — `furlo/firestore.rules` must be deployed for the twice-daily second meal time and for account deletion to fully remove the profile records (until then the app blanks the name fields instead).
- **Bottom nav “My Pets”** — the tab opens the full pet list; there is no separate pets tab screen.
- **Stretch goals below** are not implemented.

## Tech stack

- **Flutter / Dart** (SDK `^3.12.2` in `pubspec.yaml`)
- **State:** `provider`
- **Backend:** Firebase (`firebase_core`, `firebase_auth`, `cloud_firestore`, `google_sign_in`)
- **Device storage:** `shared_preferences` (settings, photo cache); `sqflite` and the web store are read only for the one-time import of pre-account data
- **UI / utilities:** Material 3, `device_preview`, `image_picker`, `url_launcher`, `fl_chart`
- **Export:** `pdf`, `share_plus`, `file_picker`, and `web`
- **Notifications (native):** `flutter_local_notifications`, `timezone`

## Data storage

All feature screens use the **`PetRepository`** interface. Signed-in accounts use Cloud Firestore:

```dart
PetRepository createPetRepository({required String storageScope}) =>
    FirestorePetRepository(uid: storageScope);
```

**Firestore collections, under `users/{uid}/`:**

| Collection | Purpose |
| --- | --- |
| `pets` | Name, species, breed, birth date, photo (small base64 image) |
| `feedings` | Schedule, frequency, days, portion, reminders, last fed (and second meal) |
| `vaccinations` | Vaccine name, dates, completion, derived status |
| `healthRecords` | Title, date, type, notes, optional medication reminder fields |
| `weightLogs` | Date, weight, notes |
| `vets` | Contact fields |
| `vetLinks` | Vet–pet link (the many-to-many join) and next appointment |
| `settings/profile` | Display/full name, setup flags |

`firestore.rules` lets each account read and write only its own documents, field by field.

**On the device:** notification toggles, theme, a cached display name and cached pet photos (`shared_preferences`). The older on-device stores (`SqlitePetRepository`, `WebPetRepository`) are kept only so pre-account data can be imported.

## Getting started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (includes Dart)
- For mobile: Xcode (iOS) and/or Android Studio / SDK (Android)
- For web: Chrome or another browser supported by Flutter web

### Install and run

From the repository root, the app package lives in `furlo/`:

```bash
git clone <repository-url>
cd furlo
flutter pub get
```

**Mobile** (device or emulator connected):

```bash
flutter devices
flutter run
```

**Web** (local HTTP server; URL printed in the terminal):

```bash
flutter run -d web-server
```

You can also use `flutter run -d chrome` for a Chrome instance with Flutter tooling.

**Device Preview:** `main.dart` wraps the app in `DevicePreview`, always on for web and in non-release builds elsewhere. Use the preview toolbar to simulate screen sizes.

### Quality checks

From `furlo/`:

```bash
flutter analyze
flutter test
```

## Platform notes

| Area | Mobile (iOS/Android) | Web |
| --- | --- | --- |
| Pets and all records | Cloud Firestore (offline cache on by default) | Cloud Firestore |
| Pet photo | Camera or library | File picker |
| Local notifications | Scheduled, with tap-to-open and Mark fed | No-op service |
| Export PDF | Save PDF dialog (`file_picker`) or Share sheet | Download through the browser |
| Vet phone links | `url_launcher` | Browser-dependent |

## Project structure (`furlo/lib/`)

```text
lib/
├── app.dart              # MaterialApp, theme, auth gate routing
├── main.dart             # Firebase init, theme preload, runApp + DevicePreview
├── data/                 # Static catalogs (breeds, vaccine names, health record types)
├── models/               # Pet, feeding, vaccination, health, vet, weight types
├── providers/            # ChangeNotifiers: session, pets, record lists, reminders, theme
├── repositories/         # PetRepository + Firestore store (legacy/ holds import sources), account and settings repositories
├── screens/              # UI by feature (auth, home, pets, feeding, health, vets, settings, …)
├── services/             # Auth, notifications, PDF export, legacy import
├── utils/                # Theme tokens, validation, formatting, weight and photo helpers
└── widgets/              # Shared UI (record cards, empty states, skeletons, status pill)
```

Other repo paths: `flutter-capstone-planning/` (planning docs, including the original app proposal), platform folders under `furlo/android` and `furlo/ios`.

## Secrets and backend

The app uses a Firebase project. `lib/firebase_options.dart` holds Firebase's client configuration, which is designed to be public; access is controlled by Firebase Authentication and `firestore.rules`. There are no server secrets in the repository.

## Roadmap / stretch goals

From the product proposal; not in the app today:

- Calendar view for vaccinations and vet appointments
- Vet clinic location / map
- Vet document or receipt scanner

## Not built

- Calendar view
- Vet map
- Receipt scanner
- Multi-user care
- Breed tips
- Weekly summary
- AI assistant

## Font attribution

The bundled PDF font files are Noto Sans. Their license/attribution file was not available in this checkout; confirm the SIL Open Font License against the original font download and include the license with the assets before redistribution.

## License

See [LICENSE](LICENSE) in this repository.
