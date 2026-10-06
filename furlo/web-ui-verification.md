# Web UI verification — account isolation task

- The requested `flutter run -d web-server` was started and served its page at `http://127.0.0.1:4793/` (HTTP 200). A separate release build was also served locally at `http://127.0.0.1:4871/` to distinguish dev-server tooling from app rendering.
- At the requested 375px preview size, the debug-served page remained blank in the shared Chromium preview. Its console reports a Dart webdev injected-client serializer type error (`_JsonMap` is not a subtype of `List<Object?>`), and the Flutter scene host stays 0×0.
- The release build did render the fixed cloud-setup failure screen in the shared browser. This is because the web Firebase initialization path fails in this environment; it does not render the sign-in form or authenticated app UI.
- Resizing the shared preview to 1440px did not produce an app UI view. The browser panel reports differing inner dimensions/device scale from requested sizes (for example 416 CSS px when requesting 375px), so exact viewport validation could not be established there.
- Result: visual verification of changed screens at both 375px and 1440px is blocked by the shared browser/dev-client setup and Firebase initialization; no success is claimed. Widget tests cover phone-sized auth-screen layout, and `flutter analyze`/`flutter test` pass independently.
