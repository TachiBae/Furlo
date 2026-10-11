# Furlo Full-App Cohesion Audit — Report

Branch: `fix/ui-audit` · Date: 2026-10-12 · Source brief:
[docs/FULL_APP_COHESION_AUDIT_PROMPT.md](FULL_APP_COHESION_AUDIT_PROMPT.md) ·
Plan: [COHESION_AUDIT_PLAN.md](../COHESION_AUDIT_PLAN.md) ·
Task list: [COHESION_AUDIT_TASK_LIST.md](../COHESION_AUDIT_TASK_LIST.md)

**Status: partially executed — items 1, 2 and 4 of 13 are complete and committed. Items 3 and
5–12 were not executed and item 13 (this report) is partial by necessity.** §5 lists exactly
what did not run; nothing in this report claims a check that was not run.

---

## 1. Scope & method

Audited the whole app — design tokens, shared components, navigation, state, repository,
web safety, accessibility, performance, tests and copy — then fixed what was found.

Method: read the three predecessor reports first so settled findings were not re-litigated;
inventory every screen/widget/provider/repository/service with line counts; capture a
`flutter analyze` / `flutter test` baseline **before** touching code; then fix batch by batch,
each with `dart format` + analyze + test + a local commit.

Instruments used: `flutter analyze`, `flutter test`, `dart format`, targeted `rg` scans, and two
new test suites written specifically to close gaps the earlier passes could not reach.

## 2. Baseline

| Gate | Before | After Phase 0 repair |
|---|---|---|
| `flutter analyze` | **2 errors** (exit 1) | 0 issues (exit 0) |
| `flutter test` | 246 passed, **1 failed** (exit 1) | 247 passed (exit 0) |

Both failures came from one malformed import in the **untracked** `test/species_dropdown_theme_test.dart:6`
(`package:shared_preferences/shared_preferences`, missing `.dart`). A red gate makes every later
comparison meaningless, so that one token was fixed first; nothing else in the file was touched.
Owner-approved decision: keep the fix.

**The repo was not clean when this audit began.** 16 files (1,328 insertions) of dormant
uncommitted work from another thread — auth, complete-profile, legacy import — plus 9 untracked
code/test files. With owner approval this was committed as its own checkpoint (`98aa74c`) so the
audit's per-item commits stayed clean and attributable. The combined tree was verified green
(0 analyze issues, 247 passing) immediately before that commit.

## 3. Findings register

New findings from this session's own evidence:

| ID | Sev | Finding | Status |
|---|---|---|---|
| N-001 | Med | Raw `fontSize:` literals off the token scale | **Narrowed, then fixed.** Only **2** sites were real UI (`pet_onboarding_screen.dart:411,436`). The other ~11 are `pw.TextStyle` inside the **PDF export document**, a separate medium. My Phase 0 count of 6 was wrong; corrected here. Fixed in item 1. |
| N-002 | — | "Dead `Inter` font reference still in lib" | **Void — my error.** The grep hit was `horizontalInterval` in the weight chart. F-022 is genuinely fixed. Reported as a false positive rather than quietly dropped. |
| N-003 | Med | `catch (_) {` appears **51×** in `lib`, untriaged as a set | **Open** — item 5 not executed. Spot-checks show most continue to a real handler. |
| N-004 | Low | `_formatDate` still duplicated ×3 (F-013 residue) | **Open** |
| N-005 | Advisory | `lib/app.dart` now **836 lines** (≈400 when last reviewed); `pet_repository.dart` **1735**; 6 lib files > 600 | **Open, out of scope by design** |
| N-006 | Info | Raw `Color(0x…)` outside `app_theme.dart` = **0**; the only raw `Colors.*` usage is `Colors.transparent` ×2 (a "no colour" sentinel) | Verified clean; now enforced by test |

New finding discovered **by running**, not by reading:

| ID | Sev | Finding | Status |
|---|---|---|---|
| N-007 | **High** | **Home overflowed at 2.0 text scale at every width** — the bottom bar and the pet strip used fixed heights (`68`, `150`) that could not fit a scaled label. Both earlier audits flagged fixed heights as `[unverified]`; neither ran the app to confirm. | **Fixed** in item 4 |

Consistency finding fixed in item 2:

| ID | Sev | Finding | Status |
|---|---|---|---|
| N-008 | Med | Feeding was the outlier record screen: its own card container, its own near-duplicate empty state, and the **only chips in the app that never read the palette** — the weekday picker used plain `ChoiceChip`, so it fell back to framework Material colours inside the dark theme. | **Fixed** |

Prior-findings status cross-checked this session: `showBadge: true` → 0 hits (F-006 fixed);
`width: 420` → 0 (F-019 fixed); `appColors.warning|info` → 0 (F-023 fixed); `RefreshIndicator`
present on all 5 record screens (F-015 fixed); `maxLength` 6 sites (F-012 fixed);
`Add vaccine'` → 0 (F-021 partly — `Add vaccination` ×2 remains).

## 4. Executed items

### Item 1 — design-token leaks, and a guard that keeps them out (`cb1eeab`)

- The last two raw `fontSize` literals in the UI layer moved onto `AppTypography.label`.
- `AppComponents.destructiveButton` (a static field with no palette access) became
  `destructiveButtonFor(AppPalette)`, so confirms can use danger tokens instead of hand-rolling
  colours. Nothing consumed it, so the shape change was free.
- Field `contentPadding` vertical 14 → `AppSpacing.md`, matching the horizontal axis and the scale.
- **New guard test** scans `lib/` and fails on any raw `fontSize` or colour literal escaping
  `app_theme.dart`. The PDF export service is exempt with a written reason: separate medium,
  own page palette. Verified the guard **fails on a planted violation** before removing the probe.

### Item 2 — one card, one empty state, one chip recipe (`c5beab6`)

- New `AppChoiceChip` is now the single chip recipe for the pet selector, the record filter tabs
  and the feeding weekday picker — removing three near-identical chip blocks and fixing the
  unthemed chips.
- Feeding uses `RecordCard` and `RecordEmptyState`; its duplicate `_EmptyFeedingState` widget was
  deleted. Its list-level padding was dropped so the card's own margin governs, as on other screens.
- Home's all-pets empty state now uses the shared `RecordEmptyState` (C-018), gaining an icon and
  dropping the stray period.
- New `AppRadius.pill` token replaced three magic radii (nav highlight `20`, status pill `999`,
  pet avatar `64`) — all were already relying on Flutter's radius clamp to render as capsules.
- Deleted `AppElevation.soft`, which this change orphaned rather than leaving a dead token.
- New tests pin the shared components so a screen cannot quietly grow its own card, empty state or
  unstyled chip. One home test pinned the old `"No pets yet."` copy; it now asserts the shared
  empty state, its title **and** its message — stronger, not weaker.

### Item 4 — responsive sweep, and the overflow it found (`9e35a0e`)

Closes the longest-standing gap in this codebase: both predecessor audits left runtime layout
`[unverified]` because the shared browser cannot reach authenticated screens.

- New `test/responsive_sweep_test.dart`: **15 screens × {375×667, 768×1024, 1440×900} ×
  {1.0, 1.3, 2.0} text scale = 135 combinations**, asserting no screen raises an overflow.
- It collects **every** offender per viewport in one run and names each screen, so the test doubles
  as the per-screen grid in §6.
- It found exactly one offender: **Home at 2.0 scale, at all three widths** (N-007). The bottom bar
  is now sized from the scaled label and the pet strip grows with it, so both follow the user's
  text setting instead of clipping it.
- The sweep demonstrably fails without the fix — that is how the bug was found, not a guess.

## 5. NOT executed

These are **not** done. No claim of passing is made for any of them.

| # | Batch | Why it matters | State |
|---|---|---|---|
| 3 | B4 terminology & copy unification (C-042 one error family ~21 sites, C-021, C-043, C-009) | largest visible copy inconsistency | **not started** |
| 5 | B2 error-handling triage of the 51 `catch (_)` sites (N-003) | silent failures | **not started** |
| 6 | B8 navigation & flow integrity (unsaved-changes guards, dialog stacking, browser back) | dead ends, lost input | **not started** |
| 7 | B10 web/platform safety (failure paths for picker/share/download/notification/URL) | graded on web | **not started** |
| 8 | B9 data & persistence integrity (round-trips, cascades, DST, migration non-destructiveness) | data loss | **not started** |
| 9 | B7 forms & validation cohesion (input table, `keyboardType`, submit idempotency) | inconsistent validation | **not started** |
| 10 | B6 accessibility (`semanticLabel` on icon-only controls, 48dp targets, focus order) | screen-reader users | **not started** |
| 11 | B11 perf & jank (**measured** before/after rebuild counts) | jank | **not started** |
| 12 | B12 test-depth backfill | coverage | partial — 3 new suites were added as part of items 1, 2 and 4 |

Consequently the **Track 12 terminology table** and the **full findings register** promised in the
plan are incomplete and are not reproduced here.

## 6. Responsive sign-off grid (VERIFIED — run, not read)

All 15 screens pass at every viewport and text scale. Verified by
`flutter test test/responsive_sweep_test.dart` → `All tests passed!` (exit 0).

| Screen | 375×667 | 768×1024 | 1440×900 | 1.0 | 1.3 | 2.0 |
|---|---|---|---|---|---|---|
| Home | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ *(was ❌, fixed)* |
| Pet profile | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Pet onboarding | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Feeding | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Vaccinations | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Health records | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Vet contacts | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Vet details | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Weight | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Notifications | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Notification settings | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Profile | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Sign in | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Create account | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Forgot password | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

**Not in the grid: Complete profile** (`lib/screens/auth/complete_profile_screen.dart`). It needs an
`AccountProfileRepository` and no suitable fake was available without inventing one, so adding it to
the sweep would have been guesswork. It is covered at a single viewport by
`complete_profile_test.dart`. This is a real hole in the sweep and is listed as such.

## 7. State-coverage scan (INDICATIVE — must not be read as verified)

Keyword occurrences per screen. **This is a grep, not a behavioural test.** `home_screen`'s `0` in
the ERROR column is almost certainly a false negative (it has `state.hasError`, which this
case-sensitive pattern misses). Treat these as leads for item 5, not results.

| Screen | load | empty | error | retry | pull-to-refresh | delete |
|---|---|---|---|---|---|---|
| Home | 1 | 8 | 0 ⚠ | 1 | 0 | 0 |
| Pet profile | 2 | 0 | 1 | 1 | 0 | 6 |
| Pet onboarding | 1 | 4 | 0 | 0 | 0 | 0 |
| Feeding | 1 | 8 | 14 | 7 | **1** | 8 |
| Health records | 1 | 14 | 4 | 1 | **1** | 8 |
| Vaccinations | 1 | 6 | 3 | 1 | **1** | 8 |
| Weight | 1 | 8 | 3 | 1 | **1** | 4 |
| Vet contacts | 2 | 9 | 1 | 1 | **1** | 3 |
| Notifications | 1 | 1 | 0 | 0 | 0 | 0 |
| Profile | 1 | 1 | 3 | 0 | 0 | 0 |
| Sign in | 0 | 0 | 0 | 0 | 0 | 0 |
| Create account | 0 | 0 | 0 | 1 | 0 | 0 |
| Forgot password | 0 | 0 | 0 | 0 | 0 | 0 |
| Complete profile | 0 | 0 | 5 | 0 | 0 | 0 |

Confirmed from this scan: pull-to-refresh exists **only on the 5 record screens** — notifications,
profile and pet onboarding have none, which may be correct (no async list) or may not. Worth
confirming in item 6.

## 8. Verification log

Every command below was run in `furlo/`, with the exit status captured explicitly.

| Command | Result |
|---|---|
| `flutter analyze` (baseline) | 2 errors, exit 1 |
| `flutter test` (baseline) | 246 passed, 1 failed, exit 1 |
| `flutter analyze` (after Phase 0 repair) | 0 issues, exit 0 |
| `flutter test` (after Phase 0 repair) | 247 passed, exit 0 |
| `flutter test` (after item 1) | 251 passed, exit 0 |
| `flutter test` (after item 2) | 255 passed, exit 0 |
| `flutter test` (after item 4) | **258 passed, exit 0** |
| `flutter test test/theme_token_guard_test.dart` with a planted violation | **failed as intended**, naming `lib/__guard_probe.dart:2` and `:3`; probe then deleted and the suite re-run green |
| `flutter test test/responsive_sweep_test.dart` before the Home fix | **failed**, `Home @ x2.0: Multiple exceptions`, exit 1 |
| `flutter test test/responsive_sweep_test.dart` after the Home fix | `All tests passed!`, exit 0 |
| `dart format --output=none --set-exit-if-changed <touched files>` | 0 changed, exit 0 |
| `flutter analyze` (final) | 0 issues, exit 0 |

Commits: `98aa74c` checkpoint (owner-approved) · `c7c27cd` housekeeping format ·
`f9d3757` prompt/plan/task list · `cb1eeab` item 1 · `c5beab6` item 2 · `9e35a0e` item 4.

## 9. Verified by running vs read only

**Verified by running:** the analyze/test/format gates at every step; the token guard fails on a
planted violation; the responsive sweep passes for 15 screens × 3 viewports × 3 text scales; the
Home 2.0-scale overflow existed and is fixed; all 258 tests pass.

**Read only (not executed this session):** everything in §5. The state-coverage table in §7 is a
grep, not a behavioural test. The `catch (_)` set (N-003) is unexamined beyond spot-checks.
The consistency matrix's per-feature cells for date pickers, sort order, filters and save feedback
were never systematically filled.

## 10. Blocked / unverified

1. **Browser verification of authenticated screens remains blocked.** The shared Chromium preview
   cannot reach signed-in screens without credentials (owner chose the widget-sweep route instead),
   so no authed screen was *seen* rendered in a browser this session. Layout is evidenced by the
   sweep, which is deterministic but is not a screenshot.
2. **The debug `flutter run -d web-server` dev client previously failed to render** in this
   environment (`_JsonMap is not a subtype of List<Object?>`, host stuck at 0×0 — see
   [web-ui-verification.md](../web-ui-verification.md)). Not re-tested this session.
3. **Complete profile screen** is absent from the responsive sweep (§6).
4. **N-003, N-004, N-005 and all of §5** remain open.

## 11. What I would do next

1. **Item 5 (error triage)** — the 51 `catch (_)` sites are the largest remaining correctness risk
   and the cheapest to triage mechanically.
2. **Item 12 (test backfill)** for the branches touched here, then items 6–8, which carry the
   data-loss and web-crash risk that matters most for a graded web build.
3. **Add Complete profile to the sweep** by introducing a minimal fake `AccountProfileRepository`,
   closing the one hole in an otherwise complete grid.
4. Items 3, 9, 10 and 11 (copy, forms, accessibility, measured perf) are lower risk but highly
   visible; item 10 in particular has no automated coverage at all today.
