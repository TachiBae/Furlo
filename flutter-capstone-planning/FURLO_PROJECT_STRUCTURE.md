# Furlo Project Structure Plan

This document captures the recommended project organization for Furlo based on the planning documents in `flutter-capstone-planning` and the current state of the Flutter app.

## Source of truth

- `flutter-capstone-planning/app-proposal.md`
- `flutter-capstone-planning/design-system.md`
- Current working Flutter project in `furlo/`

The app is a local, single-user pet care tracker that keeps records for pets, feeding, vaccinations, health, vet contacts, and weight tracking using a relational local data model. The architecture is intentionally beginner-friendly and practical for a capstone project.

---

## Final directory tree

```text
furlo/
├── README.md
├── analysis_options.yaml
├── pubspec.yaml
├── assets/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── models/
│   │   ├── pet.dart
│   │   ├── feeding_entry.dart
│   │   ├── vaccination.dart
│   │   ├── health_record.dart
│   │   ├── vet.dart
│   │   └── weight_log.dart
│   ├── repositories/
│   │   └── pet_repository.dart
│   ├── screens/
│   │   ├── home/
│   │   │   └── home_screen.dart
│   │   ├── pets/
│   │   │   ├── pet_onboarding_screen.dart
│   │   │   └── pet_profile_screen.dart
│   │   ├── feeding/
│   │   │   └── feeding_screen.dart
│   │   ├── vaccinations/
│   │   │   └── vaccination_screen.dart
│   │   ├── health/
│   │   │   └── health_records_screen.dart
│   │   ├── vets/
│   │   │   └── vet_contacts_screen.dart
│   │   ├── weight/
│   │   │   └── weight_tracking_screen.dart
│   │   └── settings/
│   │       ├── profile_screen.dart
│   │       └── notifications_screen.dart
│   ├── widgets/
│   │   ├── pet_card.dart
│   │   ├── status_pill.dart
│   │   └── primary_button.dart
│   ├── services/
│   │   ├── notifications_service.dart
│   │   └── export_service.dart
│   ├── providers/
│   │   └── furlo_state.dart
│   ├── utils/
│   │   ├── app_theme.dart
│   │   └── constants.dart
│   └── generated files / platform setup files
├── test/
│   └── widget_test.dart
├── android/
├── ios/
├── web/
├── linux/
├── macos/
├── windows/
└── other Flutter generated folders
```

---

## Major folder explanations

### `lib/screens/`
Contains all app screens, organized by feature area. This keeps each domain separate and makes navigation easier to follow.

### `lib/widgets/`
Stores reusable UI components shared across several screens, such as cards, buttons, and status chips. These are based directly on the app design system.

### `lib/models/`
Defines the core data objects used throughout the app. These match the app proposal’s data model for pets, feedings, vaccinations, health records, vets, and weight logs.

### `lib/repositories/`
Holds the data-access contract. The planning document specifically calls for an abstraction around local storage, with a native SQLite implementation and a web-safe fallback strategy.

### `lib/services/`
Contains app-level services for things that are not directly UI, such as notification handling and export functionality.

### `lib/providers/`
Stores app state that may be shared across multiple screens. For this capstone, the state management is intentionally lightweight and straightforward.

### `lib/utils/`
Contains cross-cutting items such as theme configuration, spacing constants, and color definitions that match the design system.

### `assets/`
Reserved for any app images, icons, or visual assets added later.

### `test/`
Used for validation tests and future feature-level test coverage.

---

## Requirement-to-file mapping

| Requirement | Primary file(s) | Responsibility |
|---|---|---|
| Pet onboarding | `lib/screens/pets/pet_onboarding_screen.dart` | Pet data entry and photo workflow |
| Pet list / home | `lib/screens/home/home_screen.dart`, `lib/widgets/pet_card.dart` | Pet overview list and quick access |
| Pet profile | `lib/screens/pets/pet_profile_screen.dart` | Pet detail display and related records |
| Feeding | `lib/screens/feeding/feeding_screen.dart`, `lib/models/feeding_entry.dart` | Feeding records and check-in logic |
| Vaccinations | `lib/screens/vaccinations/vaccination_screen.dart`, `lib/models/vaccination.dart` | Vaccination logs and due-date tracking |
| Health records | `lib/screens/health/health_records_screen.dart`, `lib/models/health_record.dart` | Medical record tracking and reminders |
| Vet contacts | `lib/screens/vets/vet_contacts_screen.dart`, `lib/models/vet.dart` | Vet list, details, and associations |
| Weight tracking | `lib/screens/weight/weight_tracking_screen.dart`, `lib/models/weight_log.dart` | Weight log and chart-ready data |
| Profile / settings | `lib/screens/settings/profile_screen.dart` | User preferences and profile settings |
| Notifications | `lib/screens/settings/notifications_screen.dart`, `lib/services/notifications_service.dart` | Toggle-based alert settings |
| Local data storage | `lib/repositories/pet_repository.dart` | Repository abstraction for SQLite/web-safe storage |
| Theme and style | `lib/utils/app_theme.dart`, `lib/utils/constants.dart` | Colors, spacing, and reusable styling |
| App shell | `lib/app.dart`, `lib/main.dart` | Root application setup |

---

## Notes on architecture decisions

### Local-first SQLite approach
The planning documentation clearly favors SQLite over cloud-first alternatives because:

- the app is local and single-user,
- records are relational,
- a many-to-many vet-to-pet relationship exists,
- Firebase or Supabase would add unnecessary complexity for this project scope.

### Beginner-friendly structure
This setup avoids a heavy enterprise app architecture. It keeps the app organized by responsibility instead of over-engineering state or data flow.

### Web fallback requirement
The planning docs explicitly note that some features are native-only, including SQLite and notifications. The repository layer is therefore the correct place to route between native and web-safe implementations.

---

## Important assumptions / review items

- The app remains single-device and single-user for MVP, matching the planning docs.
- The project is not yet implementing feature behavior; this is organization and scaffolding only.
- The structure may still need additional domain screens or edits as the implementation grows.
- If the course grading expects a running app shell with navigation, that should be added after this structure is confirmed.

---

## Files created or adjusted

- `lib/app.dart`
- `lib/utils/app_theme.dart`
- `lib/main.dart`
- `lib/models/` files
- `lib/repositories/pet_repository.dart`
- `lib/services/notifications_service.dart`
- `lib/services/export_service.dart`
- `lib/providers/furlo_state.dart`
- `lib/widgets/` files
- `lib/screens/` files
- `test/widget_test.dart`

This structure is intentionally prepared for implementation, not full feature coding.
