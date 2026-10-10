# Task List — DevicePreview phone frame on GitHub Pages

Plan: [DEVICE_PREVIEW_PLAN.md](DEVICE_PREVIEW_PLAN.md)

| # | Task | Status | Result |
|---|---|---|---|
| T1 | Change `enabled:` flag in `lib/main.dart` to `kIsWeb \|\| !kReleaseMode` | done | comment + flag written; `flutter analyze` clean |
| T2 | `flutter analyze --no-pub` + `flutter test` — must pass | done | analyze exit 0 "No issues found"; **203/203 tests pass**, exit 0 |
| T3 | `flutter run -d web-server` sanity check at 375px and 1440px (debug unchanged) | done | frame + toolbar at 1440; frame scales to fit at 375 |
| T4 | `flutter build web --release --base-href "/Furlo/"`; serve `build/web` under `/Furlo/` locally; verify phone frame, toolbar device switch, clean console at 375px and 1440px in the release output | done | build exit 0 (45.0s), bundle 4.58→5.48 MB; frame renders in release at 1440 + toolbar works (Orientation → Landscape → back); 375 portrait fit; console 0 errors, all assets 200 |
| T5 | Commit + push; poll CI run until build **and** deploy are green | done | commit `209016b` pushed; run 38065167506 **completed/success** (build + deploy) |
| T6 | Verify live site shows the frame (HTTP 200 + browser screenshot at 1440px) | done | live site renders iPhone frame + Device toolbar at 1440; console 0 errors, all assets 200 |
| T7 | Final report: files changed, test results, what was verified by running vs reading | done | reported in session |
