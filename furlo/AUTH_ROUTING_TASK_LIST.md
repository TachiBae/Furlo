# Task List: Account-aware authentication routing

- [x] Review current auth gate, registration flow, onboarding, Add Pet save path, tests, and worktree state.
- [x] Create the implementation plan artifact without editing application code.
- [x] Create this task-list artifact before application-code edits.
- [x] Confirm first-time Google users follow the new-account flow.
- [x] Confirm first-pet state must synchronize across devices.
- [x] Obtain approval and add local strict UID-only Firestore rules permitting own metadata reads/writes.
- [x] Implement cross-device first-pet routing and return-to-sign-in registration behavior.
- [x] Add tests for returning users with pets, existing users without pets, email/Google new-account signup then first sign-in/add-pet, and subsequent sign-in.
- [x] Run formatter, `flutter analyze`, focused auth/routing tests, and full `flutter test`.
- [x] Review the scoped behavior and preserve unrelated dirty worktree changes.
- [x] Run the web app and inspect the sign-in screen at 375px and 1440px; authenticated and Add Pet browser flows could not be exercised without live Firebase credentials. The webdev injected-client error was observed.
