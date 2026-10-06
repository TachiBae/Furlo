# Google Account Chooser — Task List

Approval gate: do not start until `GOOGLE_ACCOUNT_CHOOSER_PLAN.md` is approved.

## Implement

- [x] 1. Web: add `setCustomParameters({'prompt': 'select_account'})` to the `GoogleAuthProvider` used in `signInWithGoogle` (`lib/services/firebase_auth_service.dart`).
- [x] 2. Mobile: best-effort `GoogleSignIn.instance.signOut()` before `authenticate()` inside `signInWithGoogle` (non-fatal on failure; sequence lives in `acquireGoogleIdToken`).
- [x] 3. Extract the `GoogleIdentityProvider` seam (`clearSession()` + `idToken()`) with a default implementation over `GoogleSignIn.instance`; accept an override in `FirebaseAuthService`.
- [x] 4. Tests: ordering test via a fake provider (`clearSession` before `idToken`), non-fatal clear failure, null token passthrough; web provider parameter test for `prompt: 'select_account'` (parameters map is public — asserted directly).

## Verify

- [x] 5. `flutter analyze --no-pub` (No issues found, exit 0) and `flutter test --no-pub` (162 passed, exit 0).
- [x] 6. `flutter run -d web-server` + browser at 375px and 1440px: auth screens verified rendering unchanged in real screenshots (sign-in screen in device_preview at both widths). *(Chooser-on-tap could not be driven here — it needs a signed-in Google session, see item 7.)*
- [ ] 7. Manual device check: "Create account" → Google → picker with "Use another account"; a fresh Google account lands in first-pet onboarding, the old account resumes its data.
- [ ] 8. (Conditional) If Android still auto-selects after item 2: switch the pre-auth cleanup to `disconnect()` and re-run items 5–7.
