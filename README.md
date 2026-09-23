# Furlo

Furlo is a Flutter-powered pet care tracker designed to help pet owners keep daily routines, health records, vaccination schedules, and veterinary information in one place.

The app is built to simplify the everyday management of pet care by combining feeding reminders, health tracking, weight logs, vaccination records, and vet contact management into a single, easy-to-use mobile experience.

## Why Furlo?

Pet parents often keep important information in scattered notes, calendars, and memory. Furlo brings those details together in a focused and organized system so owners can stay proactive and reduce missed care tasks.

## Key Features

- Pet onboarding and profile management
- Feeding logs and routine tracking
- Vaccination tracking and due-date reminders
- Health records and care notes
- Weight history and trend monitoring
- Vet contact management
- Local notifications for reminders
- Clean, mobile-first dashboard experience

## Current Project Status

This project is in its early MVP phase and is being structured for feature-driven development. The app shell is ready, with the foundation in place for expanding into the full pet care workflow.

## Tech Stack

- Flutter
- Dart
- Material Design
- Local persistence with SQLite-style app architecture patterns
- Notification support for reminder workflows

## Project Structure

```text
furlo/
├── android/               # Android platform configuration
├── ios/                   # iOS platform configuration
├── lib/
│   ├── app.dart           # App entry and app shell
│   ├── main.dart          # Application bootstrap
│   ├── models/            # Data models for pets, records, etc.
│   ├── providers/         # State management
│   ├── repositories/     # Data access layer
│   ├── screens/          # Feature screens
│   ├── services/         # Notifications/export services
│   ├── utils/            # Shared utilities and styling
│   └── widgets/          # Reusable UI components
├── test/                  # Automated tests
├── analysis_options.yaml  # Linting configuration
├── pubspec.yaml           # Flutter package metadata and dependencies
├── README.md              # Project documentation
└── .gitignore
```

## Getting Started

### Prerequisites

Before running the app, make sure you have the following installed:

- Flutter SDK
- Dart SDK
- Android Studio or Xcode depending on your target platform
- VS Code or Android Studio with Flutter support

### Installation

1. Clone the repository:

```bash
git clone <repository-url>
cd furlo
```

2. Install dependencies:

```bash
flutter pub get
```

3. Run the app:
   V

```bash
flutter run
```

### Common Development Commands

```bash
flutter analyze
flutter test
flutter run -d chrome
flutter build apk
flutter build ios
```

## App Architecture

The app follows a modular Flutter structure centered around:

- Models for core domain entities such as pets, feeding entries, vaccinations, and vet records
- Repositories for consistent data access and persistence logic
- Providers for shared application state
- Screens for feature-specific user flows
- Services for background and reminder functionality

This structure allows the app to scale cleanly as new features are added without mixing domain logic into UI code.

## Planned Roadmap

### MVP

- Pet onboarding
- Pet dashboard and list views
- Feeding history and reminders
- Vaccination tracking
- Health record management
- Vet information storage
- Weight tracking
- Notification settings

### Future Enhancements

- Exporting records
- Improved charting and reporting
- More advanced reminder scheduling
- Shared household workflows
- Design refinements and accessibility improvements

## Contributing

Contributions are welcome. If you want to help improve Furlo:

1. Fork the project
2. Create a feature branch
3. Make your changes
4. Run tests and validation
5. Submit a pull request with a clear summary

## License

This project is licensed under the terms of the repository license. Please review the license file before using or distributing the project.

## Contact

For questions, ideas, or collaboration opportunities, please reach out through the project repository or the active development channel for the team.

---

Furlo is designed to make pet care more consistent, organized, and stress-free for everyday owners.
