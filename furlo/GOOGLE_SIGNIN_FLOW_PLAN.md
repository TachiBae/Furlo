# Plan: In-page Google sign-in (no separate popup window)

## Why a window pops up today
Web Google sign-in uses `_auth.signInWithPopup(...)` in
[firebase_auth_service.dart](lib/services/firebase_auth_service.dart) — Firebase's
default, which opens an OS-level window for the account chooser. Verified working
after the console fixes (the user reached the chooser).

## Options

### Option 1 — In-page Google button via Google Identity Services (recommended)
Replace the popup with GIS rendered in-page (the chooser appears as an anchored
dialog / bottom sheet on mobile, not a separate window), then exchange the returned
ID token via `GoogleAuthProvider.credential(idToken)` → `_auth.signInWithCredential`
— the exact pattern the app already uses for non-web.
- No new dependency (raw `dart:js_interop` against the already-loaded
  `accounts.google.com/gsi/client` script).
- Caveats: Google may show its one-account shortcut first ("Use another account"
  still opens a chooser); GIS UI sits at the browser-viewport level — on desktop
  with the device-preview frame it overlays near the corner rather than literally
  inside the phone bezel (nothing web-side can render Google UI inside the canvas).
- Effort: M (new web identity provider + sign-in screen button wiring + tests).

### Option 2 — Redirect flow (simplest, no window ever)
`signInWithRedirect` + `getRedirectResult` at startup: the whole tab navigates to
Google and back. Works on every mobile browser (iOS Safari auto-uses this path
already). Smallest change, but on desktop the showcase page bounces away from the
device-preview frame during sign-in. Loses the in-frame illusion completely.
- Effort: S.

### Option 3 — Keep the popup (current)
Standard Firebase web behavior; popup-blocked now shows a specific message
(deployed). Best when the site is mostly viewed on desktop, where a window is
familiar. No work.
- Effort: none.

## Recommendation
Option 1 — it matches the request (sign-in UI appears in-page / as a mobile-style
sheet instead of a window) on both desktop and real phones.
