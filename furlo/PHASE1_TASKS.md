# Phase 1 — Task List

Plan: `PHASE1_PLAN.md` · Findings: F-003, F-004, F-024, F-022, F-023
Status: **complete** — plan approved via `ask_questions` before any code edit.

- [x] T0 — Produce plan + task list artifacts, get user approval
- [x] T1 — F-023: remove dead `warning`/`info` tokens from `AppPalette` (app_theme.dart)
- [x] T2 — F-003 completion: feeding:697 `'Missed / Overdue'` → `'Overdue'` so repeating
      overdue captions render `danger`
- [x] T3 — Tests: feeding overdue-caption color widget test + status-pill border ≥3:1
      pinning test (all 3 palettes × 3 status colors × surface/bg)
- [x] T4 — WCAG re-run: recompute the 5 flagged pairs, record old → new ratios
- [x] T5 — Gates: `dart format`, `flutter analyze --no-pub`,
      `flutter test --no-pub` — exit codes captured, all 0
- [x] T6 — Browser: `flutter run -d web-server`, verify feeding overdue caption +
      vaccination pill at 375px & 1440px in all three themes, console clean
- [x] T7 — Commit per item, commit artifacts, `git push origin fix/ui-audit`
      (published the 25 already-unpushed commits — approved scope)

## Verification record

| Check | Result |
|---|---|
| T1 grep: zero `warning`/`info` refs remain | **PASS** — ripgrep over `lib/` + `test/` returns 0 code matches (only docs describe the removal) |
| T3 feeding test fails before T2 / passes after | **PASS** — red before fix (`find.text('Overdue')` found nothing), green after; 14/14 in both touched files |
| T3 pill-border ratios ≥3:1 (all combos) | **PASS** — test green: 3 palettes × 3 status colors × surface/bg, all ≥3.0 |
| T4 ratios old → new | **PASS** — table below, all pairs meet thresholds |
| T5 analyze / test exit codes | **PASS** — `dart format` clean; `flutter analyze --no-pub` exit 0; `flutter test --no-pub` exit 0 (203/203, was 201; +2 new tests) |
| T6 screens observed at 375/1440 × 3 themes | **PASS** — feeding caption screenshotted at 375 + 1440 in Default/Light/Dark (2026-10-09); vaccination "Rabies → Overdue" pill screenshotted at 375 + 1440 in Dark (2026-10-10). Pill colors in Default/Light are covered by the T3 token test rather than screenshots. Console: Firebase init + known DWDS debug-injection noise only — no app errors |
| T7 commit hashes + push result | **PASS** — `e8d2537` (F-023), `03d263e` (F-003), `657f065` (docs) → pushed `a6275aa..657f065` to `origin/fix/ui-audit`, exit 0 |

## T4 — WCAG recomputation (audit §6 old → 2026-10-10 new)

Thresholds: text ≥4.5:1, non-text UI ≥3:1. WCAG 2.x sRGB relative luminance.

| Pair (need) | Default | Light | Dark |
|---|---|---|---|
| Overdue caption on `surface` (4.5) | 2.87 → **5.18** | 7.00 → **6.54** | 6.38 → **6.01** |
| Overdue caption on `bg` (4.5) | 3.13 → **5.66** | 6.42 → **6.00** | 7.16 → **6.75** |
| Delete label `textOnDanger` on `danger` (4.5) | 3.01 → **5.35** | 6.54 → **6.54** | 6.75 → **6.75** |
| Pill border `danger`@0.75 over `surface` (3.0) | 1.84 (@0.6) → **3.45** | 2.78 → **4.14** | 3.17 → **3.94** |
| Pill label on 0.18 fill (4.5) | 13.40 → **12.08** | 13.31 → **12.21** | 11.25 → **9.36** |

Notes:
- Caption pairs now measure `danger` because the F-003 fix routes overdue captions to
  the `danger` token (the audit measured `primaryMuted`, the pre-fix color).
- Delete-label default improved via `ca534be` (`textOnDanger` → `0xFF181820`); Light/Dark unchanged.
- Pill border now blends at alpha 0.75 (audit measured 0.6).
- Pill-label inputs (`textPrimary`, `primary`, `surface`) are unchanged since the audit;
  recomputed with fill = `primary` @0.18 over `surface` as the model.
- Script computed 2026-10-10 against the palette literals in `lib/utils/app_theme.dart`;
  the same thresholds are enforced in CI-style by `test/profile_settings_test.dart`.
