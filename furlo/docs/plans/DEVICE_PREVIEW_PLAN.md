# Plan: Phone-frame DevicePreview on the deployed GitHub Pages site

## Goal
`https://tachibae.github.io/Furlo/` renders Furlo **inside the DevicePreview phone frame**
(the same view used for local grading on `flutter run -d web-server`), instead of fullscreen.

## Root cause (verified by reading code)
`furlo/lib/main.dart`:

```dart
runApp(DevicePreview(
  enabled: !kReleaseMode,          // ← disabled whenever kReleaseMode == true
  builder: (context) => FurloApp(...),
));
```

CI builds with `flutter build web --release`, so `kReleaseMode == true` and the frame is
turned off on the deployed site. The package (`device_preview: ^1.3.1`) and the wrapper are
already in place — **only the flag differs** from the local grading view.

## The change (single line, `lib/main.dart`)
```dart
enabled: kIsWeb || !kReleaseMode
```

| Surface | Today | After |
|---|---|---|
| Deployed web (release) | fullscreen | **phone frame ✓ (goal)** |
| Local debug web (`flutter run`) | phone frame | phone frame (unchanged) |
| Debug/profile native | phone frame | phone frame (unchanged) |
| Native release | fullscreen | fullscreen (unchanged) |

Strictly additive: the only behavior that changes is the one requested.

Alternatives considered:
- `enabled: true` — also flips hypothetical native release builds; no benefit for this
  web-only app, changes more than needed.
- Fullscreen default with `?preview=1` opt-in — rejected: the default page itself should
  show the phone.

## No workflow / CI change
The build command stays `flutter build web --release --base-href "/Furlo/"`.

## Risks & mitigations
1. **Toolbar actions (screenshot/replay) rely on debug-only bridges** → may no-op or error
   in release. Mitigation: tested in T4; if any visible control misbehaves, hide it via
   `DevicePreviewToolbarOptions` inside the same change.
2. **Real-phone visitors get a frame around a frame** → the package scales the device to fit;
   acceptable unless you later ask for a desktop-only frame.
3. Input/pointer routing through the preview transform is already proven by local grading use.

## Verification (all must run)
1. `flutter analyze --no-pub` and `flutter test` — pass.
2. `flutter run -d web-server` — sanity at 375/1440 (debug behavior unchanged).
3. `flutter build web --release --base-href "/Furlo/"` then serve `build/web` locally under
   `/Furlo/` → verify in the browser that the **release** output shows the frame at 375 and
   1440, the toolbar device-switcher works, and the console stays clean.
4. Commit + push → CI run green (build **and** deploy) → live site shows the frame
   (HTTP 200 + screenshot).
