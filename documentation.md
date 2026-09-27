# Documentation guide (what your docs must contain)

Your Documentation Update is graded in week 1 and again in week 2. Documentation is not an afterthought: a reader who has never seen your app should be able to understand what it is, get it running, and use it, from your docs alone. Keep your documentation in your project repository's `README.md` (and link it, or a copy, from your workspace `project/`).

Your documentation must contain these sections. Aim for clear and complete, not long.

## 1. Overview

Furlo is a Flutter mobile application designed to help pet owners manage and care for their pets in one place. It is intended for individuals who want an organized, simple way to track pet information, routines, and daily care activities.

## 2. Setup and installation

Follow these steps in order to get the app running from a clean setup:

- Flutter and Dart versions used for this project: Flutter SDK version compatible with the project configuration in `pubspec.yaml`, and Dart SDK as managed by the Flutter toolchain used in the workspace.
- Clone the repository from the project source.
- Open the project folder in a terminal.
- Run:

  ```bash
  flutter pub get
  ```

- If the app depends on platform-specific setup, complete the required steps for the device target you are using (for example Android/iOS/web). This project is a Flutter app and may require Android SDK, Xcode, or Chrome/Web dependencies depending on the selected platform.
- If any backend or API configuration is required, add it to environment config or app constants using placeholder values. Do not commit real secrets or API keys. Example placeholder:

  ```text
  API_BASE_URL=https://your-api-url.example.com
  ```

## 3. How to run it

From the project root, run:

```bash
flutter run
```

If you want to run in a specific browser/device target, use an explicit target such as:

```bash
flutter run -d chrome
```

When the app runs successfully, the reader should see the app launch on the selected target with the main onboarding or home screen loaded.

## 4. Features and usage

The app currently includes features for pet management and a dashboard/home experience.

Primary user flow:

1. Launch the app.
2. View the home/dashboard screen.
3. Add a pet from the pet setup or management flow.
4. Continue through the app to manage and view pet-related information.
5. Navigate through the main screens using the app's available UI flow.

Main screens and usage:

- Home screen/dashboard: the landing area for users after app start, showing the primary summary and navigation entry point.
- Add pet flow: allows the user to create a new pet profile and save relevant information.
- Settings and related screens: support app configuration and user preferences as the project expands.

## 5. Project structure

A short map of the main project layout is below:

- `lib/` contains the application code.
- `lib/main.dart` is the app entry point.
- `lib/app.dart` defines the application structure and root configuration.
- `lib/screens/` contains screen-level UI, including dashboards, settings, and feature pages.
- `lib/models/` stores data models used by the app.
- `lib/providers/` holds state management and app-level provider logic.
- `lib/repositories/` contains data access or backend abstraction code.
- `lib/services/` contains service-layer logic.
- `lib/widgets/` contains reusable UI components.
- `lib/utils/` contains helpers and shared utilities.

## 6. Screenshots

At least one screenshot should be included for each screen in the app. For this iteration, include screenshots of:

- the home dashboard screen
- the add pet screen
- any settings or navigation screens that exist in the current build

Example placeholder:

```text
![Home dashboard screenshot](docs/screenshots/home-dashboard.png)
![Add pet screenshot](docs/screenshots/add-pet.png)
```

Use the actual image files in the repository under `docs/screenshots/` when available.

## 7. Known issues and next steps

This version is still an incremental build and is not yet feature-complete. Known areas to improve include:

- polishing the pet creation flow and validation
- expanding the dashboard with more meaningful data and actions
- improving integration between screens and app state
- adding additional feature screens and user workflows before final delivery

The next steps are to complete the main app workflow, improve usability, and verify the experience across target devices.

## How it is graded

See `rubrics.md` in this unit for the exact point breakdown. In short: your setup and run steps must actually work (that is the largest share), your feature and usage docs must match what the app really does, and screenshots plus clear writing carry the rest.

## Security checklist (from week 2)

From week 2 your documentation also includes a completed `SECURITY-CHECKLIST.md` in your workspace `project/` folder. Copy `security-checklist-template.md` from this unit and fill it in.

Every row is answered Yes, No or N/A, with one line of evidence in your own words. "N/A" is a correct answer when it is true, and it needs its reason written next to it. Fill it in before you make your repository public, not after, because that is the point of it. It is worth 3 of the 15 points in week 2.

## AI usage

Your repository must also carry an `AI-USAGE.md` and a credit line in the README. That file is graded separately, as your finals badge, and it is worth 100 points; see the `finals-badge` unit for what goes in it. For your weekly Documentation Update all that is checked is that the file exists and is current, so start it in week 1 and keep it up as you go.
