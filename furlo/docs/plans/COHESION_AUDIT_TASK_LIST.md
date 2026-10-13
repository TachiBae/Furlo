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
- [x] 3. **B4 terminology & copy unification.** — `7b0169b`. One error-message family, one dialog-title
      casing, plain `Save`, support-code line dropped, `Add vaccination` residue cleared, and the
      terminology table applied from one place. Wording only — no logic. Guard test added.
- [x] 4. **B5 responsive + text-scale sweep (the big unverified gap).** — `9e35a0e`. 15 screens ×
      {375, 768, 1440} × {1.0, 1.3, 2.0} = 135 combinations, all green. Found and fixed a real
      **Home 2.0-scale overflow** at every width. PARTIAL: forcing each screen's
      loading/empty/error/data branch was not done, `Complete profile` is absent from the sweep,
      and browser verification of authed screens stays blocked.

## Phase 2 — correctness

- [x] 5. **B2 error-handling triage.** — `b9a9247`. All 51 `catch (_)` sites classified: 47 already
      handled, 4 bare/comment-only swallows fixed. Guard test asserts no silent, comment-only or
      bare swallow is added later; verified to fail on a planted violation.
- [x] 6. **B8 navigation & flow integrity.** — `b592023`. The pet form (the largest free-text form)
      no longer discards a typed pet on back; it mirrors the vet editor's existing guard. Shared
      discard dialog added. PARTIAL: double-tap dialog stacking and browser-back were not exercised
      at runtime (browser blocked).
- [x] 7. **B10 web/platform safety.** — `4c42139`. Every platform call confirmed behind `kIsWeb` or a
      conditional import; failure paths asserted to degrade to clear copy. `flutter build web
      --release` exit 0; the app's own tests re-run on the real web platform via
      `flutter test --platform chrome` (12/12, then 11/11). Guard test added. BLOCKED: the preview
      webview cannot reach loopback in this environment, so in-browser inspection is not possible.
- [x] 8. **B9 data & persistence integrity.** — `efdf4df`. Round-trip (unicode, emoji, whitespace,
      long, nullable), cascade and date-boundary tests added; found and fixed a real bug where one
      malformed stored row threw `Invalid URL encoding` and took the entire list down. Rows that
      fail to decode *or* to construct are now dropped and reported individually.
      BLOCKED: sqflite/migration paths stay covered by reading only — sqflite has no test binding here.
- [ ] 9. **B7 forms & validation cohesion.** Build the input table, then unify validators,
      `maxLength`, and keyboard hints (C-025) across auth + all record dialogs; make submit
      idempotent; keep input on a failed save.

## Phase 3 — hardening

- [x] 10. **B6 accessibility & contrast.** Guard added over 13 screens × {1.0, 2.0} text scale:
      every icon-only control must carry a tooltip or `semanticLabel`, must meet the 48dp tap
      target, and must render without throwing (a crashed tree would otherwise pass vacuously).
      Found and fixed two real unlabelled controls — the Home first-pet card's add button and the
      Vet Details back button (a custom `leading` discards the AppBar's own localized label).
      Verified by removing each label again and watching the guard fail. `inspected > 0` assertion
      keeps the tap-target check from passing trivially. PARTIAL: focus-visible/tab-order on web
      and a contrast recomputation on the current palette were not part of this item's guard.
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

**Executed: items 1, 2, 3, 4, 5, 6, 7, 8 and 10.** Items 9, 11, 12 and 13 are **NOT EXECUTED** —
no claim of passing is made for them. Full detail, evidence and the verified grid are in
[docs/full-app-cohesion-audit-report.md](docs/full-app-cohesion-audit-report.md).

Commits: `98aa74c` checkpoint · `c7c27cd` housekeeping format · `f9d3757` prompt/plan/task list ·
`cb1eeab` item 1 · `c5beab6` item 2 · `9e35a0e` item 4 · `7b0169b` item 3 · `b9a9247` item 5 ·
`b592023` item 6 · `4c42139` item 7 · `efdf4df` item 8.

## Verification gates

- [x] After each item: `dart format`, analyze + test exit 0 (counts recorded), one local commit.
- [ ] After Phase 1: browser pass on the signed-out surface at 375px and 1440px, console and
      network inspected; authed screens evidenced by the sweep test. **BLOCKED**: the preview
      webview resolves to `chrome-error://chromewebdata/` with zero console and zero network
      entries, so it never reaches a loopback dev server. Substituted real-browser verification
      via `flutter test --platform chrome`.
- [ ] Before finishing: re-run the full sweep, re-run analyze + test, confirm no raw color or
      font-size literals outside `app_theme.dart`, and confirm the sign-off matrix has no
      unexplained ❌.
- [x] Report honestly: anything not executed is **blocked with a cause**, never a claimed pass.

## Out of scope (recorded, not done)

- C-026 / N-005 file-size extraction (`pet_repository.dart` 1735 lines, `app.dart` 836) —
  architectural, not cohesion.
- Any feature work. Any new dependency. Any destructive migration.
