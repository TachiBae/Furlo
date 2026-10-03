# Furlo

Furlo is a Flutter-based pet care tracker designed to help pet owners organize important information about their pets in one place. The app is intended to support everyday pet-care tasks such as feeding, health records, weight tracking, vaccinations, and veterinary information through a simple mobile-first interface.

> **Project Status:** Early MVP / Foundation Stage

Furlo is currently in active development. The Flutter application shell, onboarding experience, initial design system, project architecture, and core pet model have been established. Several planned features are still being implemented.

---

## 1. Overview

Furlo is designed for pet owners who want a centralized way to manage their pets' daily care and important records.

The long-term goal is to combine routine tracking, health information, vaccination schedules, weight history, and veterinary details into one application instead of relying on separate notes, calendars, or memory.

### Current Focus

The current development stage focuses on:

- Flutter application foundation
- Onboarding experience
- Reusable UI and design system
- Pet domain model
- Modular application architecture
- Preparation for pet management and care-record features

---

## 2. Setup and Installation

### Prerequisites

Before running Furlo, install the following:

- Flutter SDK
- Dart SDK
- Android Studio or Xcode, depending on the target platform
- VS Code or Android Studio with Flutter support
- A configured Android emulator, iOS simulator, or physical device

### Flutter and Dart Versions

The project was developed using the Flutter and Dart versions installed in the development environment.

Check your installed versions with:

```bash
flutter --version
dart --version
```

> **Note:** Update this section with the exact Flutter and Dart versions used for the final project submission.

### Clone the Repository

Clone the project from its repository:

```bash
git clone <repository-url>
cd furlo
```

Replace `<repository-url>` with the actual Furlo repository URL.

### Install Dependencies

After cloning the project, install the Flutter dependencies:

```bash
flutter pub get
```

### Configuration

The current MVP foundation does not require external API keys or a backend URL to launch the application.

No real API keys, passwords, or other secrets should be committed to the repository.

If external services are introduced in future development, configuration values should be stored using an appropriate environment/configuration system rather than directly inside the source code.

---

## 3. How to Run It

### Run on a Connected Device or Emulator

Start an Android emulator, iOS simulator, or connect a physical device, then run:

```bash
flutter run
```

Flutter will launch the application on the selected device.

### Run in Chrome

For web development, run:

```bash
flutter run -d chrome
```

### Verify the Installation

When the application starts successfully, the Furlo onboarding screen should appear.

The current onboarding experience presents Furlo's pet-care introduction and provides the initial call-to-action for continuing into the application.

> **Current limitation:** The onboarding CTA is currently a placeholder and is not yet connected to the next application screen.

### Development Validation

The following commands can be used to check the project:

```bash
flutter analyze
```

Run the automated tests with:

```bash
flutter test
```

---

## 4. Features and Usage

### 4.1 Onboarding

The first screen users currently encounter is the Furlo onboarding experience.

The screen introduces the application and establishes the visual identity of Furlo. It contains the main call-to-action that will eventually begin the user's pet-management experience.

**Current status:**

- Onboarding UI implemented
- Furlo branding and design applied
- CTA displayed
- Navigation to the next screen is not yet implemented

### 4.2 Pet Management

Pet management is one of the main planned features of Furlo.

The project currently contains the foundation for a `Pet` domain model, which will eventually represent information about individual pets.

The model is intended to support information required by future features such as:

- Pet profile information
- Health records
- Weight history
- Vaccination records
- Veterinary information

**Current status:** Foundation/model stage. The complete pet creation and management flow is still being developed.

### 4.3 Feeding and Routine Tracking

Furlo is planned to provide feeding logs and routine tracking so owners can keep track of regular pet-care activities.

**Current status:** Planned. The complete workflow and persistence logic have not yet been implemented.

### 4.4 Health Records

The application is planned to allow users to maintain health-related records and care notes for their pets.

**Current status:** Planned.

### 4.5 Weight Tracking

Furlo is planned to record pet weight over time and eventually provide a way to view changes and trends.

**Current status:** Planned.

### 4.6 Vaccination Tracking

Vaccination records and due-date reminders are part of the planned MVP.

Users will eventually be able to record vaccinations and keep track of upcoming vaccination requirements.

**Current status:** Planned.

### 4.7 Veterinary Information

Furlo is planned to provide a dedicated area for storing important veterinary information.

This may include vet contact information and other relevant records.

**Current status:** Planned.

### 4.8 Notifications and Reminders

Local notifications are planned for routine care and important dates such as vaccinations.

**Current status:** Service architecture is being prepared, but notification functionality is not yet fully implemented.

---

## 5. Project Structure

Furlo uses a modular Flutter project structure to keep the application's UI, data, state, and services separated.

```text
furlo/
├── android/               # Android platform configuration
├── ios/                   # iOS platform configuration
├── lib/
│   ├── app.dart           # Main application shell and Material configuration
│   ├── main.dart          # Application bootstrap
│   │
│   ├── models/            # Core domain/data models
│   │
│   ├── providers/         # Application state management
│   │
│   ├── repositories/      # Data access and persistence layer
│   │
│   ├── screens/            # Application screens and user flows
│   │
│   ├── services/           # Application services such as notifications
│   │
│   ├── utils/              # Shared utilities and design-related resources
│   │
│   └── widgets/            # Reusable UI components
│
├── test/                   # Automated tests
├── analysis_options.yaml   # Dart/Flutter lint configuration
├── pubspec.yaml            # Dependencies and project metadata
├── README.md               # Project documentation
└── .gitignore              # Git ignore configuration
```

### Architecture

The project is organized around several responsibilities:

**Models**
Represent the application's core data, such as pets and future care records.

**Screens**
Contain the user-facing application screens and feature flows.

**Providers**
Handle shared application state between different parts of the UI.

**Repositories**
Provide a dedicated layer for retrieving and storing application data.

**Services**
Contain functionality that interacts with application-level services, such as notifications.

**Widgets**
Contain reusable UI components that can be shared across multiple screens.

This separation is intended to make Furlo easier to maintain and expand as additional features are implemented.

---

## 6. Screenshots

Screenshots should be added here as the application gains completed screens.

### Current Onboarding Screen

_Add the latest screenshot of the Furlo onboarding screen here._

Example:

```markdown
![Furlo Onboarding Screen](docs/screenshots/onboarding.png)
```

### Screenshot Requirements

Each completed application screen should have a corresponding screenshot in the documentation.

Recommended folder:

```text
docs/
└── screenshots/
    ├── onboarding.png
    ├── dashboard.png
    ├── pet-profile.png
    └── ...
```

As new screens are completed, update this section with their screenshots and a short description of what each screen does.

---

## 7. Known Issues and Next Steps

### Known Issues

The current MVP foundation has several incomplete areas:

- The onboarding CTA does not yet navigate to another screen.
- The main pet dashboard has not yet been fully implemented.
- Pet creation and management workflows are incomplete.
- Repository and persistence logic are currently scaffolded.
- Feeding, health, weight, and vaccination workflows are not yet fully implemented.
- Notification functionality is not yet complete.
- End-to-end user flows are still being connected.
- Automated test coverage is still limited while the application foundation is being established.

### Next Steps

The immediate development priorities are:

1. Connect the onboarding CTA to the next application screen.
2. Build the pet profile and dashboard experience.
3. Implement pet creation and management.
4. Connect providers to the application's data flow.
5. Implement repository and persistence logic.
6. Build feeding and routine tracking.
7. Add health, weight, and vaccination records.
8. Implement veterinary information management.
9. Add local notifications and reminders.
10. Expand automated tests around important models and user flows.
11. Refine the UI using the established design system.
12. Complete the remaining MVP features.

---

## Development Commands

Useful commands for development and validation:

```bash
# Install dependencies
flutter pub get

# Run the application
flutter run

# Run on Chrome
flutter run -d chrome

# Analyze the project
flutter analyze

# Run tests
flutter test

# Build Android APK
flutter build apk

# Build iOS application
flutter build ios
```

---

## Security

Security-related development practices are documented separately in:

```text
project/SECURITY-CHECKLIST.md
```

The checklist should be completed before making the repository public.

The project must not contain:

- API keys
- Passwords
- Authentication secrets
- Private tokens
- Other sensitive credentials

Any future external-service credentials should be provided through appropriate configuration or environment variables.

---

## AI Usage

Furlo's AI-assisted development is documented separately in:

```text
AI-USAGE.md
```

This file records the AI tools used during development and how they contributed to the project.

A corresponding AI usage credit is also maintained in this README.

---

## Roadmap

### Current — Foundation

- [x] Flutter project setup
- [x] Material application shell
- [x] Initial onboarding UI
- [x] Design system and reusable styling
- [x] Initial `Pet` model
- [x] Modular project structure
- [x] MVP roadmap documentation

### Next — Core MVP

- [ ] Onboarding navigation
- [ ] Pet creation
- [ ] Pet profile
- [ ] Pet dashboard
- [ ] Feeding tracking
- [ ] Weight tracking
- [ ] Health records
- [ ] Vaccination records
- [ ] Vet information
- [ ] Local reminders
- [ ] Data persistence
- [ ] Expanded automated testing

### Future

- [ ] Record exporting
- [ ] Improved charts and reporting
- [ ] Advanced reminder scheduling
- [ ] Shared household/pet-care workflows
- [ ] Accessibility improvements
- [ ] Additional UI refinements

---

## License

This project is licensed under the terms of the repository license. Refer to the project's license file for the applicable terms.

---

## Contact

For questions, suggestions, or collaboration regarding Furlo, use the project's repository or the team's active development channel.

---

**Furlo — making pet care more organized, consistent, and manageable.**
