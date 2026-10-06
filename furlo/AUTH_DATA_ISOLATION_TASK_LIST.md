# Task List: UID-isolated local pet data and reminders

- [x] Inspect the dirty worktree, current branch, partial patches, Firebase target metadata, and available devices.
- [x] Repair UID-scope token generation and repository construction; preserve unscoped legacy stores.
- [x] Ensure add/edit/profile/vet/notification flows retain and pass the active UID.
- [x] Make notification preference changes, IDs, scheduling, and cleanup user-owned and race-safe.
- [x] Scope account-local profile settings and remove sensitive exception/stack logging.
- [x] Add tests for UID data/settings isolation, untouched legacy data, notification ownership, and session changes.
- [x] Run formatter, analyzer, focused tests, and the complete Flutter test suite.
- [ ] Run the web app and inspect changed screens at 375px and 1440px (blocked: browser/dev-client Firebase setup; see [web UI verification](web-ui-verification.md)).
- [ ] Determine whether the configured Firebase project is explicitly a test target; run real provider scenarios only with confirmed test credentials and available platform targets (blocked: project not confirmed as a test target; no credentials/devices available).
- [x] Record final changed files, executed checks, observed UI, and any platform/auth limitations in [web UI verification](web-ui-verification.md).
