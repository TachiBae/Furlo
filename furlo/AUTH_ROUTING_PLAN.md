# Implementation Plan: Account-aware authentication routing

## Objective
Change Furlo routing to match these flows:
- Returning account signs in → dashboard directly, regardless of whether the account currently has pets.
- Newly registered account → return to sign-in; after its first sign-in, show Add Pet; after the first pet is saved, show the dashboard.
- Subsequent sign-ins → dashboard directly.

## Acceptance criteria
1. A returning user with saved pets lands on the dashboard after sign-in.
2. A returning user with no pets also lands on the dashboard and can add a pet from the dashboard.
3. Successful email registration does not leave the user authenticated in the app; it returns to the sign-in screen.
4. The newly registered account's first successful sign-in routes directly to Add Pet (not the promotional onboarding screen).
5. Saving the first pet takes the user to the dashboard; the account's first-sign-in marker is cleared only after a successful save.
6. Later sign-ins for that account route directly to the dashboard.
7. Pet data and any new first-sign-in marker are account-scoped; legacy data remains untouched.
8. Add regression tests for existing user with pets, existing user with no pets, newly registered user sign-up/sign-in/add-pet flow, and a later sign-in.
9. Preserve unrelated existing modifications and do not alter generated registrants.

## Confirmed decisions
- Apply the new-account flow to both email and Google account creation. A first-time Google account must be detected, marked for first-pet onboarding, signed out, and returned to the sign-in screen.
- Store first-pet onboarding state across devices. Use a per-UID Firestore account metadata document; do not move pet records from local storage or change their existing per-UID local isolation.

## Proposed implementation
1. Preserve existing unrelated worktree changes. Do not edit generated plugin registrants or the earlier generic plan/task artifacts.
2. Update the auth contract to communicate whether registration created a new account, including Firebase Google credential `additionalUserInfo.isNewUser` information.
3. For newly created email or Google accounts, write an account-owned Firestore metadata flag indicating the first pet is still required, then sign out and return to the sign-in route. On any later successful sign-in, read the flag for that UID and route new accounts to Add Pet; existing accounts go directly to HomeScreen even if their local pet list is empty.
4. Clear the first-pet flag only after the first pet is successfully saved. Keep marker operations keyed to the authenticated UID and fail safely rather than treating a failed Firestore read as a returning account.
5. Preserve the dashboard's existing no-pet/add-first-pet affordance and keep pet repository namespaces account-scoped and local-only.
6. Add fake auth/account-metadata test seams and deterministic widget tests for returning users with/without local pets, email registration, first-time Google registration, first pet save, and later sign-in.
7. Format and run focused auth/routing tests, `flutter analyze`, and full `flutter test`. Do not perform Firebase provider operations or write to the configured Firebase project during tests.

## Preconditions / external safety
- `cloud_firestore` is already listed as a project dependency, but verify Firestore setup and security rules before implementation: clients must only read/write the metadata document for their own UID. No Firebase console changes, rules deployment, production data operations, or real auth tests are included in the coding task.
- This requires a Firestore read/write on sign-in and account creation, unlike a device-local marker. The user explicitly chose cross-device persistence. Verify the account-data rules can support it; if rules/configuration are absent, leave the feature safely blocked rather than silently falling back to device-local state.

## Completion and safety notes
Implementation was performed after approval. No destructive data migration, live Firebase auth operation, dependency addition, staging, commit, or push was performed. Local UID-only Firestore rules are configured but were not deployed or emulator-tested. Unrelated worktree edits were preserved.