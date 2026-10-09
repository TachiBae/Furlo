# Phase 1 — Task List

Plan: `PHASE1_PLAN.md` · Findings: F-003, F-004, F-024, F-022, F-023
**Awaiting approval before any code edit.**

- [ ] T0 — Produce plan + task list artifacts, get user approval
- [ ] T1 — F-023: remove dead `warning`/`info` tokens from `AppPalette` (app_theme.dart)
- [ ] T2 — F-003 completion: feeding:697 `'Missed / Overdue'` → `'Overdue'` so repeating
      overdue captions render `danger`
- [ ] T3 — Tests: feeding overdue-caption color widget test + status-pill border ≥3:1
      pinning test (all 3 palettes × 3 status colors × surface/bg)
- [ ] T4 — WCAG re-run: recompute the 5 flagged pairs, record old → new ratios
- [ ] T5 — Gates: `dart format`, `flutter analyze --no-pub`,
      `flutter test --no-pub` — exit codes captured, all 0
- [ ] T6 — Browser: `flutter run -d web-server`, verify feeding overdue caption +
      vaccination pill at 375px & 1440px in all three themes, console clean
- [ ] T7 — Commit per item, commit artifacts, `git push origin fix/ui-audit`
      (publishes the 25 already-unpushed commits — approved scope)

## Verification record

| Check | Result |
|---|---|
| T1 grep: zero `warning`/`info` refs remain | pending |
| T3 feeding test fails before T2 / passes after | pending |
| T3 pill-border ratios ≥3:1 (all combos) | pending |
| T4 ratios old → new | pending |
| T5 analyze / test exit codes | pending |
| T6 screens observed at 375/1440 × 3 themes | pending |
| T7 commit hashes + push result | pending |
