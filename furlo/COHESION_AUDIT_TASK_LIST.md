# Full-App Cohesion Audit — Task List

Order of execution. One commit per item (message prefix `Item N:`). `flutter analyze` and
`flutter test` must exit 0 — with exit codes **captured**, not inferred — before every commit.
**Approval of this list is required before the first code edit.**

Baseline for reference: analyze 0 issues / test 247 passed (both exit 0), after the B0 repair.

---

## Phase 0 — gate repair (done, uncommitted)

- [x] B0. Fix the missing `.dart` in the `shared_preferences` import at
      `test/species_dropdown_theme_test.dart:6` — analyze 2 errors → 0; test 1 load-failure → 0
      failures. Untracked sibling-thread file; one token changed, nothing else.

## Phase 1 — visible cohesion (highest gain per unit effort)

- [x] 1. **B1 typography & token residue.** — `cb1eeab`. ADAPTED: the survey found only **2** real
      UI `fontSize` literals (`pet_onboarding:411,436`); the rest were `pw.TextStyle` in the PDF
      export document, a separate medium. Also removed a dead `Inter` reference that turned out not
      to exist. Guard test added and proven to fail on a planted violation.
- [x] 2. **B3 cross-feature consistency matrix.** — `c5beab6`. Closed C-032 (feeding card →
      `RecordCard`), C-031 (one shared `AppChoiceChip`), C-018 (home empty state), C-040 (pill
      radius token), plus feeding's duplicate empty state. C-030 and C-041 were already satisfied
      in the tree. PARTIAL: per-feature cells for date pickers, sort order, filters and save
      feedback were not systematically filled.
- [ ] 3. **B4 terminology & copy unification.** **NOT EXECUTED.** One error-message family (~21 sites, C-042), one
      dialog-title casing (C-021), plain `Save` (C-043), drop the support-code line (C-009),
      `Add vaccination` residue, and the full terminology table (pet / feeding / vaccination /
      weight / vet / health record / sign in). Wording only — no logic.
- [x] 4. **B5 responsive + text-scale sweep (the big unverified gap).** — `9e35a0e`. 15 screens ×
      {375, 768, 1440} × {1.0, 1.3, 2.0} = 135 combinations, all green. Found and fixed a real
      **Home 2.0-scale overflow** at every width. PARTIAL: forcing each screen's
      loading/empty/error/data branch was not done, `Complete profile` is absent from the sweep,
      and browser verification of authed screens stays blocked.

## Phase 2 — correctness

- [ ] 5. **B2 error-handling triage.** Classify all 51 `catch (_)` sites into handled /
      handled-but-silent / ignorable. Any silent swallow on a user-facing path gets a surfaced
      message or a `logAppDiagnostic` call. Grep-assert no raw `e.toString()` reaches the UI.
- [ ] 6. **B8 navigation & flow integrity.** Verify all 14 screens reachable and exitable by app
      bar back, gesture, and browser back. Fix any pop that returns nothing to a caller that
      expects a result. Add unsaved-changes guards to multi-field forms. Prevent stacked dialogs
      on double-tap.
- [ ] 7. **B10 web/platform safety.** Confirm every platform call sits behind `kIsWeb` or a
      conditional import; exercise the failure paths (picker unavailable, share refused, download
      blocked, notifications unsupported, URL rejected) and assert each degrades to clear copy.
      Cold-load the web build with Firebase unreachable.
- [ ] 8. **B9 data & persistence integrity.** Every model round-trips (unicode, emoji,
      whitespace-only, very long, nullable). Cascade delete leaves no orphan. Timezone/DST and
      "today" boundaries produce no off-by-one-day. Prove the v10 `onUpgrade` path is additive.
      Web quota-exceeded and corrupt-JSON recover without data loss or a throw. Second account
      sees only its own data.
- [ ] 9. **B7 forms & validation cohesion.** Build the input table, then unify validators,
      `maxLength`, and keyboard hints (C-025) across auth + all record dialogs; make submit
      idempotent; keep input on a failed save.

## Phase 3 — hardening

- [ ] 10. **B6 accessibility & contrast.** `semanticLabel`/`Tooltip` on every icon-only control
      (C-044), 48dp tap targets, contrast recomputed on the current palette, focus visible and
      tab order visual on web, text-scale 2.0 re-verified on the densest screens.
- [ ] 11. **B11 perf & jank, measured.** Narrow the whole-object `FurloState` watches (F-014);
      capture a before/after rebuild count or frame timing for each change; delete the instrument.
- [ ] 12. **B12 test-depth backfill.** Cover the branches this audit touched and the untested
      error/empty/web/migration paths; assert tests are deterministic (no wall clock, no real
      timers, no cross-test state).

## Phase 4 — reporting

- [ ] 13. **B13 report.** Write `docs/full-app-cohesion-audit-report.md`: findings register, the
      filled consistency matrix, the terminology table, the **14×8 sign-off matrix**, and the
      verification log with the verified-by-running vs read-only split and every blocked check.

## Status at end of session (2026-10-12)

**Executed: items 1, 2 and 4.** Everything else in Phase 1 and all of Phases 2–4 is
**NOT EXECUTED** — no claim of passing is made for them. Full detail, evidence and the
verified grid are in [docs/full-app-cohesion-audit-report.md](docs/full-app-cohesion-audit-report.md).

Commits: `98aa74c` checkpoint · `c7c27cd` housekeeping format · `f9d3757` prompt/plan/task list ·
`cb1eeab` item 1 · `c5beab6` item 2 · `9e35a0e` item 4.

## Verification gates

- [ ] After each item: `dart format`, analyze + test exit 0 (counts recorded), one local commit.
- [ ] After Phase 1: browser pass on the signed-out surface at 375px and 1440px, console and
      network inspected; authed screens evidenced by the sweep test.
- [ ] Before finishing: re-run the full sweep, re-run analyze + test, confirm no raw color or
      font-size literals outside `app_theme.dart`, and confirm the sign-off matrix has no
      unexplained ❌.
- [ ] Report honestly: anything not executed is **blocked with a cause**, never a claimed pass.

## Out of scope (recorded, not done)

- C-026 / N-005 file-size extraction (`pet_repository.dart` 1735 lines, `app.dart` 836) —
  architectural, not cohesion.
- Any feature work. Any new dependency. Any destructive migration.
