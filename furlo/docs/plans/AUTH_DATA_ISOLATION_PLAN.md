# Implementation Plan: UID-isolated local pet data and reminders

## Goal and acceptance criteria
- Scope every local pet record collection and reminder preference by authenticated Firebase UID on web and native platforms.
- Scope scheduled notification identifiers/payload ownership so signing out or switching users cancels only the outgoing user's reminders.
- Keep the pre-existing unscoped SQLite database, SharedPreferences keys, and scheduled reminders intact; do not import or delete them automatically.
- Sanitize runtime logs so they do not include provider, exception, stack, account, or pet details.
- Preserve auth UI/provider contracts and add regression tests for scoped-vs-legacy isolation and session transitions.
- Run `dart format`, `flutter analyze`, `flutter test`, plus web UI checks at 375px and 1440px.
- Exercise real Firebase email registration/sign-in/reset, Google sign-in, and sign-out on web, Android, and iOS only against an explicitly confirmed test project/account; report unavailable devices/credentials rather than claiming unrun tests.

## Implementation approach
1. Repair existing partial scope changes and ensure every screen reaches UID-scoped repositories/settings.
2. Make database/storage scope tokens deterministic and remove malformed/duplicate declarations.
3. Scope notification IDs and cancellation ownership, including type toggles and account changes.
4. Remove raw exception/stack logging and scope local profile preferences to the signed-in user where they carry account data.
5. Add focused persistence, notification, and session-switch regression coverage.
6. Format, analyze, test, run the app, inspect the screens at the requested widths, and document actual runtime/provider coverage.

## Safety
No destructive migration, legacy-data deletion, account creation against an unconfirmed project, git staging, commit, or push.