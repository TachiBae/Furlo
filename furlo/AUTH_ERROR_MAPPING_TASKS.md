# Task List — Auth error mapping fix

Plan: [AUTH_ERROR_MAPPING_PLAN.md](AUTH_ERROR_MAPPING_PLAN.md)

| # | Task | Status | Result |
|---|---|---|---|
| T1 | Map the Google-flow codes the user actually hits | done | refined after reading current code: `invalid-credential` was already mapped; added `popup-blocked` → new `popupBlocked` code, `user-disabled` → `userNotFound`, `account-exists-with-different-credential` → `emailInUse`; new enum value + message in both message tables (plan's "no enum changes" relaxed: popup-blocked needed honest copy) |
| T2 | Extend auth mapping tests for the new codes (and fallback) | done | +3 mapping cases in `auth_service_test.dart`; message-list test updated in `auth_screens_test.dart` |
| T3 | `flutter analyze --no-pub` + `flutter test` pass | done | analyze exit 0; **206/206 tests pass** (was 203), exit 0 |
| T4 | Commit + push; CI build+deploy green | pending | |
| T5 | Live verification: user sees the specific message instead of the generic one | pending | |
