# Phase 1 — Theme, contrast & dead tokens — Implementation Plan

Findings: **F-003, F-004, F-024, F-022, F-023** (from `docs/ui-audit-report.md`)
Branch: `fix/ui-audit` (tracks `origin/fix/ui-audit`, currently **25 unpushed commits**)
Status: **executed** — approved this session; complete 2026-10-10 (see `PHASE1_TASKS.md` verification record)

## Key discovery

The fresh audit verified its findings against `feature/accounts` (tip `a6275aa`), but the
current branch already contains a prior 20-item audit fix pass (`UX_AUDIT_FIXES_PLAN.md`;
commits `05c6449`, `ca534be`, `300f47c`). Actual state of the five Phase-1 findings on
`fix/ui-audit` today:

| Finding | State here | Evidence (verified this session) |
|---|---|---|
| F-003 overdue caption → danger | **Partial — real gap** | `05c6449` mapped `'Missed / Overdue' => danger`, but the item-18 copy pass (`84c1a49`) renamed the switch case to `'Overdue'` (feeding:786) while `_statusFor` still returns `'Missed / Overdue'` for repeating schedules (feeding:697). Repeating overdue → falls to `_` → `textSecondary` grey: contrast passes but the red urgency color is lost. Home (enum → danger) and StatusPill (`'overdue'` → danger) are correct. |
| F-004 delete-label contrast | Fixed | `ca534be`: default `textOnDanger` = `0xFF181820` → ≈5.4:1 on danger; light 6.54; dark ≈6.8. Pinned by the existing test *"overdue status text and danger button labels meet AA contrast"*. |
| F-024 pill border ≥3:1 | Fixed, **unpinned** | `05c6449` raised border alpha 0.6 → 0.75 (commit message claims 3:1 in all themes). No test asserts the border ratio. |
| F-022 dead Inter font | Fixed | `300f47c`; grep for `_fontFamily` / `'Inter'` → no matches in `lib/`. |
| F-023 dead `warning`/`info` tokens | **Not done** | Still defined in `AppPalette` (app_theme.dart:15-16, 33-34, 53-54, 72-73, 90-91); grep confirms zero references in `lib/` and `test/`. |

So Phase 1 = two small code changes (T1, T2), pinning tests (T3), and verification of what
already landed (T4–T6).

## Work items

- **T1 — F-023: remove dead `warning`/`info` tokens.** In `lib/utils/app_theme.dart`:
  remove `required this.warning` / `required this.info` from the constructor, the two
  fields, and the six palette values (3 themes × 2). Only constructions of `AppPalette`
  are the three static palettes; no test constructs one (grep-verified).
- **T2 — F-003 completion: fix the feeding status mismatch.** `feeding_screen.dart:697`:
  `return now.isAfter(scheduled) ? 'Missed / Overdue' : 'Upcoming';` → `'Overdue'`.
  This completes the item-18 wording unification (its other three renames already landed)
  and makes the card switch (`'Overdue' => danger`) match, so repeating overdue renders
  danger again. *Alternative considered:* add a `'Missed / Overdue'` switch case instead —
  rejected because it leaves two wordings for one status, which item 18 set out to unify.
  No test or UI string references `'Missed'` (grep-verified).
- **T3 — tests for new logic.**
  - `test/feeding_screen_test.dart`: new widget test — create a Weekly schedule with a
    past time → the caption `'Overdue'` renders with `AppPalette.defaultTheme.danger`
    (fails before T2, passes after).
  - `test/profile_settings_test.dart`: pinning test for F-024 — status-pill border
    (status color at 0.75 alpha blended over `surface` **and** `bg`) ≥3:1 for every
    palette (default/light/dark) × status color (danger, primary, textSecondary).
- **T4 — WCAG re-run.** Recompute the five flagged pairs from the audit §6 and report
  old → new ratios (contrast helper already exists in `profile_settings_test.dart`).
- **T5 — gates.** `dart format`; `flutter analyze --no-pub`; `flutter test --no-pub`;
  exit codes captured explicitly (Bash `set -o pipefail` if output is filtered).
- **T6 — browser verification.** `flutter run -d web-server`; check the feeding overdue
  caption and a vaccination status pill at **375px and 1440px** in default/light/dark
  themes; console must be clean. Report what was seen.
- **T7 — commits & push.** One commit per item (T1, T2, T3), plan/task artifacts with
  the final commit, then `git push origin fix/ui-audit`.
  **Note: this publishes all 25 currently unpushed commits** (prior audit fixes +
  cloud-photo work), not just Phase 1.

## Constraints honored

No new dependencies · dark-theme tokens only, never hardcoded colors · no migrations ·
no unrelated refactors · tests for new logic · no weakened or skipped tests ·
analyze + test green before finishing · plan artifacts approved before code edits.
