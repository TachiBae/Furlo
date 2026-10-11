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

- [ ] 1. **B1 typography & token residue.** Replace the 6 raw `fontSize:` literals with
      `AppTypography` tokens (weight ×5, `pet_onboarding:411,436`, `home` 10/9). Remove the dead
      `Inter` family. Style `destructiveButton` on danger tokens and point confirms at it. Raise
      `contentPadding` 14→16. Add a test that fails on any raw `fontSize:` outside `app_theme.dart`.
- [ ] 2. **B3 cross-feature consistency matrix.** Fill the matrix (pet selector, date picker,
      delete confirm, save feedback, empty state, error+retry, list layout, sort, filter,
      pull-to-refresh, overdue indicator) for all 7 features, then close the minority cells:
      C-032 feeding card → `RecordCard`, C-030 shared delete confirm, C-031 shared chips,
      C-041 one weight formatter, C-018 home empty state, C-034 heading color, C-040 radius.
- [ ] 3. **B4 terminology & copy unification.** One error-message family (~21 sites, C-042), one
      dialog-title casing (C-021), plain `Save` (C-043), drop the support-code line (C-009),
      `Add vaccination` residue, and the full terminology table (pet / feeding / vaccination /
      weight / vet / health record / sign in). Wording only — no logic.
- [ ] 4. **B5 responsive + text-scale sweep (the big unverified gap).** Add the sweep test:
      14 screens × {375, 768, 1440} × {1.0, 1.3, 2.0}, zero overflow, forcing each screen's
      loading/empty/error/data branch. Then fix every overflow it finds, incl. the three known
      fixed heights (`record_components:47,93`, `pet_profile:510`) and the C-019 clamp.
      Verify signed-out screens in the browser at 375px and 1440px as well.

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
