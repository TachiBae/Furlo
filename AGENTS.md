The Flutter app lives in ./furlo. Run all flutter commands (pub get, analyze, test, run) from the ./furlo folder. All paths like lib/ and test/ are relative to ./furlo. Commit from the repo root.

Project: Furlo, a Flutter pet health tracker. Provider for state. PetRepository uses sqflite on mobile and a SharedPreferences-backed implementation on web, switched by kIsWeb. Use dark theme tokens only (Wondrous Wisteria, Succulent Lime, Black Rock) and never hardcode colors. Single-user, local-only, no secrets. The app is graded on web (`flutter run -d web-server`) inside device_preview, so no screen may throw on web.

Rules:
- All data access goes through the repository.
- Never run destructive migrations on existing data.
- Don't refactor unrelated code. No new dependencies unless the task allows them.
- Add tests for new logic. `flutter analyze` and `flutter test` must pass before you finish.
- Commit locally after each completed item.

Workflow for every task:
1. Before editing any file, produce an Implementation Plan artifact and a Task List artifact, then wait for my approval.
2. Work only on the task I give you in this session. Don't start other work.
3. For any task that changes UI, run the app with `flutter run -d web-server`, then use the browser agent to verify the changed screens at 375px and 1440px widths. Report what you saw.
4. Ask me before: deleting files, git push, git reset, or any command that removes data. Running pub get, analyze, test, and the app is allowed without asking.
5. Finish with the files changed, test results, and what you verified by running versus only by reading code. Don't claim anything works unless you ran it.