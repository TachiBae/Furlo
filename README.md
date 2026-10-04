# Furlo

Furlo is a pet health and care tracker for owners managing one to three pets at home.

> **AI credit:** I used Codebuff for code edits, debugging, and test iteration, with Claude for planning/explanations and some ChatGPT assistance. I reviewed generated work and documented contributions and mistakes in [AI-USAGE.md](AI-USAGE.md).

## Features

Implemented in the Flutter app under `furlo/`:

- **Pet onboarding and profiles** — add/edit pets (species, breed, birth date, optional photo), onboarding gate when no pets exist, per-pet profile with care-record shortcuts and delete
- **Home dashboard** — pet carousel, selected pet context, today’s reminders, quick actions into care screens
- **Feeding** — per-pet feeding schedules (time, frequency, portion, done-today), with optional reminder hooks via the notification service on native platforms
- **Vaccinations** — CRUD, due-date status, vaccine catalog helpers, reminder scheduling on native
- **Health records** — CRUD by type (checkup, medication, illness/injury, surgery, lab test, other), notes, optional medication reminders on native
- **Vet contacts** — vets linked to pets (many-to-many), next appointment per pet, phone launch via `url_launcher`
- **Weight tracking** — weight log CRUD and a trend line chart (`fl_chart`)
- **Notifications** — local notifications on iOS/Android (`flutter_local_notifications`), per-type toggles in settings, reschedule on app start
- **Profile and settings** — display name (`shared_preferences`), notification preferences, delete-all-data
- **Export care summary** — PDF care summary per pet (`pdf`) shared or downloaded (`share_plus`) from the pet profile screen

## Known limitations

- **No account or cloud sync** — single device, local data only; two installs do not share data.
- **Dark theme only** — `MaterialApp` uses `AppTheme.dark`; no in-app light theme toggle.
- **Web storage is split** — `WebPetRepository` persists **pets** and **feeding schedules** in `shared_preferences`; vaccinations, health records, vets, vet–pet links, and weight logs are held **in memory** and are lost on a full page reload.
- **Web notifications** — `NoOpNotificationService`; reminder UI works but nothing is scheduled.
- **Bottom nav “My Pets”** — the tab does not open a separate screen; the pet list lives on the home dashboard (“See all” opens the full list).
- **Stretch goals below** are not implemented.

## Tech stack

- **Flutter / Dart** (SDK `^3.12.2` in `pubspec.yaml`)
- **State:** `provider`
- **Persistence:** `sqflite` (native), `shared_preferences` (settings and partial web storage)
- **UI / utilities:** Material 3, `device_preview` (debug), `image_picker`, `url_launcher`, `fl_chart`
- **Export:** `pdf`, `share_plus`
- **Notifications (native):** `flutter_local_notifications`, `timezone`

## Data storage

All feature screens use the **`PetRepository`** interface. Implementation is chosen at runtime:

```dart
createPetRepository() => kIsWeb ? WebPetRepository() : SqlitePetRepository();
```

- **Mobile (iOS/Android):** SQLite database `furlo.db` via `sqflite`, with foreign keys enabled.
- **Web:** `sqflite` is not used (no plugin). `WebPetRepository` avoids `MissingPluginException` while keeping the same API for demos and tests.

**SQLite tables (native):**

| Table | Purpose |
| --- | --- |
| `pets` | Pet identity, species, breed, birth date, photo path |
| `feeding_schedules` | Feeding times, frequency, done-today, last fed, reminders |
| `vaccinations` | Vaccine name, dates, completion, derived status |
| `health_records` | Title, date, type, notes, optional medication reminder fields |
| `vets` | Clinic contact fields |
| `vet_pets` | Vet–pet link and optional next appointment |
| `weight_logs` | Date, weight, notes |

**Also stored outside SQLite:**

- Notification type toggles and permission flag — `SharedPreferencesNotificationSettingsRepository`
- Display name — `SharedPreferencesAppSettingsRepository`

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

**Device Preview:** In non-release builds, `main.dart` wraps the app in `DevicePreview` (`enabled: !kReleaseMode`). Use the preview toolbar to simulate screen sizes; release builds disable it.

### Quality checks

From `furlo/`:

```bash
flutter analyze
flutter test
```

## Platform notes

| Area | Mobile (iOS/Android) | Web |
| --- | --- | --- |
| Pet / feeding persistence | SQLite | `shared_preferences` |
| Vaccinations, health, vets, weight | SQLite | In-memory (session only) |
| Local notifications | Scheduled | No-op service |
| Export PDF | Share sheet | Download fallback via `share_plus` |
| Vet phone links | `url_launcher` | Browser-dependent |

## Project structure (`furlo/lib/`)

```text
lib/
├── app.dart              # MaterialApp, theme, repository wiring, onboarding entry
├── main.dart             # runApp + DevicePreview wrapper
├── data/                 # Static catalogs (breeds, vaccine names, health record types)
├── models/               # Pet, feeding, vaccination, health, vet, weight types
├── providers/            # Provider ChangeNotifiers (pets, reminders, feature state)
├── repositories/         # PetRepository (+ SQLite / web), settings repositories
├── screens/              # UI by feature (home, pets, feeding, health, vets, …)
├── services/             # Local notifications and PDF export
├── utils/                # Theme, validation, weight helpers, pet photo loading
└── widgets/              # Shared UI (pet card, status pill, buttons, record rows)
```

Other repo paths: `flutter-capstone-planning/` (planning docs, including the original app proposal), platform folders under `furlo/android` and `furlo/ios`.

## Secrets and backend

The MVP needs **no API keys** or backend. Firebase Auth, cloud sync, and multi-user access are **not** implemented.

## Roadmap / stretch goals

From the product proposal; not in the app today:

- Calendar view for vaccinations and vet appointments
- Vet clinic location / map
- Vet document or receipt scanner
- Firebase Auth (or other cloud account)
- Light theme / theme preference
- Weekly care summary
- “Ask about my pet” / AI chat

## License

See [LICENSE](LICENSE) in this repository.
