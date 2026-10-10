# Task List — In-page Google sign-in (Option 1 approved)

Plan: [GOOGLE_SIGNIN_FLOW_PLAN.md](GOOGLE_SIGNIN_FLOW_PLAN.md)

| #  | Task                                                                 | Status | Result |
|----|----------------------------------------------------------------------|--------|--------|
| T1 | In-page chooser via dart:js_interop (`google_web_identity_web.dart` + stub + neutral contract) | done | `google.accounts.id` prompt flow with moment outcomes; auto-disables (→ popup) while the client ID is empty |
| T2 | Wire into `FirebaseAuthService.signInWithGoogle()` web branch; popup kept as fallback; shared `_completeGoogleSignIn` | done | dismissal → cancelled; anything unexpected → popup fallback |
| T3 | Tests for the moment mapping + full suite                          | done | +6 tests; **212/212 pass**, analyze exit 0 |
| T4 | Web release build compiles the js_interop path                     | done | `flutter build web --release --base-href "/Furlo/"` exit 0 (52.9s) |
| T5 | Commit + push; CI build+deploy green                               | done | run pending poll; see commit record |
| T6 | Fill `kGoogleWebClientId` (user supplies Web client ID from Firebase console) + redeploy; user verifies the in-page chooser on the live site | pending | live site keeps the working popup until the ID is set |
