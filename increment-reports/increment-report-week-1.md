# Weekly Increment Report (template)

## Week of: 2026-09-23

## What changed this week

- Established the Furlo Flutter app foundation and app bootstrap with a Material app shell.
- Built the initial onboarding experience for the app, including the pet-care hero screen and CTA flow.
- Added a reusable dark theme and design-token layer for spacing, colors, typography, and button/input styling.
- Created core domain models such as `Pet`, with structure in place for future health, weight, vaccination, and vet records.
- Organized the app into a modular project structure covering screens, models, repositories, providers, services, and utilities.
- Documented the project roadmap and MVP goals in the repository README, clarifying the intended feature set.

## Why

These changes were necessary to turn the concept into a usable MVP foundation. The app needed a consistent design language, a working Flutter shell, and a clear feature structure before building the core record-keeping flows. The onboarding screen and design system give the project a recognizable identity and show the intended user experience, while the model and folder structure support future expansion into feeding, health, weight, and vet management features.

## What broke or what I got stuck on

- The onboarding screen is currently a static placeholder and still has a TODO for screen navigation.
- The app has sections planned for pet care, but the actual user flows are not yet connected end-to-end.
- Persistence, repository logic, and reminder services are still scaffolded rather than fully implemented.
- The project is in an early MVP state, so the main blocker is not a single technical bug but incomplete feature integration across the app.
- There is still a design and architecture decision to be made around how data will be persisted and how screens will be connected once the core flows are built.

## What is left

- Connect the onboarding flow to the next app screen and build the pet profile/dashboard navigation.
- Implement the pet creation and management experience in the screens and providers.
- Build the feeding, weight, vaccination, and health tracking workflows.
- Add repositories and persistence logic to store user data reliably.
- Implement notifications and reminder behavior for routine care tasks.
- Expand the test coverage around core models and key user flows.
- Refine the UI against the design system and complete the remaining MVP features before final delivery.
