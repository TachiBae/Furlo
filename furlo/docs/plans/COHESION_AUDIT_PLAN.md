# Full-App Cohesion Audit — Implementation Plan

Branch: `fix/ui-audit` · Date: 2026-10-12 · Source: [docs/FULL_APP_COHESION_AUDIT_PROMPT.md](docs/FULL_APP_COHESION_AUDIT_PROMPT.md)
Predecessors: [docs/ui-audit-report.md](docs/ui-audit-report.md) (F-001–F-026),
[docs/design-cohesion-final-report.md](docs/design-cohesion-final-report.md) (C-018–C-045),
[docs/app-health-report.md](docs/app-health-report.md) (H-*/M-*/NFRs).

---

## 0. Phase 0 baseline (already executed)

| Gate | Result |
|---|---|
| `flutter analyze` | **0 issues**, exit 0 — *after* a Phase 0 repair (below) |
| `flutter test` | **247 passed, 0 failed**, exit 0 |
| Pre-repair `flutter analyze` | 2 errors: `test/species_dropdown_theme_test.dart:6` imported `package:shared_preferences/shared_preferences` (no `.dart`) |
| Pre-repair `flutter test` | 246 passed, 1 failed — that file failed to *load* |
| Repair | Added the missing `.dart` to the import in the untracked `test/species_dropdown_theme_test.dart` |

This file is **untracked** (`??`) — a sibling thread's in-flight artifact, not committed work. The
one-token fix converted a loading failure into a passing test and made the gate green. No other
line in that file was touched. **Blocker B0 is closed**; the change is left uncommitted alongside
the other threads' pending hunks.

### Already-closed findings (do not re-fix, re-verify only)

Spot-checked in the working tree this session: `showBadge: true` → 0 hits (F-006 fixed);
`width: 420` → 0 hits (F-019 fixed); `Add vaccine'` → 0 hits (F-021 partially, `Add vaccination` ×2
remains); `appColors.warning|info` → 0 hits (F-023 fixed); `RefreshIndicator` now present on all 5
record screens incl. weight/vets/feeding (F-015 fixed); `maxLength` 6 sites (F-012 fixed);
`_formatDate` down from ×4 to ×3 in lib (F-013 partially fixed).

### Live defects confirmed by fresh Phase 0 evidence

| New ID | Sev | Evidence |
|---|---|---|
| N-001 | Med | Raw `fontSize:` literals off the token scale: 6 sites (`pet_onboarding_screen.dart:411,436` = 12; `home_screen.dart` = 10 and 9; `weight_tracking_screen.dart` ×5 incl. 9) — F-011 only partially landed |
| N-002 | Low | Dead `Inter` font family still referenced ×1 in `lib` though pubspec's `fonts:` block is commented out — F-022 regressed or was only partially removed |
| N-003 | Med | `catch (_) {` appears **51×** in `lib`; spot-checks show most continue to a real handler, but the set is untriaged — some sites may swallow silently (Track 10) |
| N-004 | Low | `_formatDate` still duplicated ×3 across record screens (F-013 residue) |
| N-005 | Advisory | `lib/app.dart` is **836 lines** (structurally up from ~400 when it was last reviewed) and `pet_repository.dart` is **1735**; 6 lib files exceed 600 lines |
| N-006 | Info | Raw `Color(0x…)`/`Colors.*` outside `app_theme.dart` is limited to `Colors.transparent` (home:504, pet_onboarding:464 — benign) and `PdfColors` in the export service's *document* palette (separate medium, intentional). Track 1's token rule holds. |

---

## 1. Ground rules (unchanged from the project's standing rules)

- All data access through the repository; no screen touches sqflite/SharedPreferences/Firestore.
- Dark theme tokens only — `AppPalette` / `AppSpacing` / `AppRadius` / `AppTypography`. Never a raw color.
- No new dependencies. No destructive migrations. No unrelated refactors.
- No lint suppressions, no `// ignore:`, no skipped tests, no weakened assertions.
- Every behavior change gets a test. `flutter analyze` and `flutter test` must exit 0 (exit codes
  captured explicitly, never inferred from a piped tail) before each commit.
- One commit per item, message prefix `Item N:`. Ask before deleting files, pushing, or resetting.

## 2. The verification constraint this plan exists to solve

Both predecessor audits left their runtime checks `[unverified]`, for a documented reason: the
shared browser preview cannot reach **auth-gated** screens without credentials, and the debug
`web-server` dev client previously failed to render (see [web-ui-verification.md](web-ui-verification.md)).
So this plan makes a **widget-test viewport sweep the primary instrument** for authed screens:

- A sweep test renders every one of the 14 screens at **375×667, 768×1024, 1440×900** and at
  **text scale 1.0 / 1.3 / 2.0**, asserting zero overflow, and forcing each screen's
  loading / empty / error / data branch where reachable.
- The browser stays the instrument for the **signed-out** surface (sign-in, create account, forgot
  password, complete profile, auth gate, cloud-setup failure) at 375px and 1440px.
- `tool/screenshot_harness.dart` is inspected first and reused for capture rather than duplicated.
- Any check that still cannot be executed is recorded as **blocked with its cause**, never as passing.

## 3. Batches (ordered; no two batches touch the same file)

Ordered so the most visible cohesion lands first, then the largest unverified gap, then
correctness, then hardening.

| # | Batch | Tracks | Files | Fixes |
|---|---|---|---|---|
| B1 | Typography & token residue | 1 | `app_theme.dart`, `weight_tracking_screen.dart`, `pet_onboarding_screen.dart`, `home_screen.dart` | N-001 (all 6 raw font sizes → `AppTypography` tokens), N-002 (dead `Inter`), C-029 (`destructiveButton` on danger tokens — 0 usages today), C-038 (contentPadding 14→16) |
| B2 | Error-handling triage | 10 | `providers/*`, `services/*`, `screens/pet_onboarding_screen.dart`, `screens/settings/profile_screen.dart` | N-003: classify all 51 `catch (_)` sites into *handled*, *handled-but-silent* (must surface), *ignorable*; route diagnostics through `logAppDiagnostic`; ban user-visible raw `e.toString()` |
| B3 | Cross-feature consistency matrix | 6 | `feeding_screen.dart`, `vet_contacts_screen.dart`, `pet_profile_screen.dart`, `home_screen.dart`, `record_components.dart` | C-032 (feeding card → `RecordCard`), C-030 (pet-profile delete dialog → shared confirm), C-031 (vet chips → shared recipe), C-041 (one weight formatter), C-018 (home empty state → `RecordEmptyState`), C-034 (section heading color), C-040 (radius 20 → `AppRadius.lgRadius`) |
| B4 | Terminology & copy unification | 12 | wording-only across screens + `app.dart` | C-042 (one error-message family, ~21 sites), C-021 (Title-Case dialog titles), C-043 (plain `Save`), C-009 (drop support-code line), F-021 residue (`Add vaccination` ×2), full terminology table |
| B5 | Responsive + text-scale sweep | 13 | new `test/` sweep + any screen with an overflow | The gap both audits left `[unverified]`: 375/768/1440 × 1.0/1.3/2.0 across all 14 screens; C-019 clamp, C-020 fixed heights (`record_components:47,93`, `pet_profile:510`), C-014 |
| B6 | Accessibility & contrast re-derivation | 8 | all screens with icon-only controls, `app_theme.dart` | C-044 (`semanticLabel`/`Tooltip` on back/close/add/call/share/chevrons), 48dp targets, contrast recomputed on the *current* palette, 2.0-scale re-verify for C-044's screen-reader claims |
| B7 | Forms & validation cohesion | 5 | auth screens, `pet_onboarding_screen.dart`, `vet_contacts_screen.dart`, record dialogs | The Phase 0 input table (field / required / maxLength / validator / keyboardType), C-025 (`keyboardType`/`textInputAction`/`autofocus`), validator wording unification, submit idempotency |
| B8 | Navigation & flow integrity | 2 | `app.dart`, `home_screen.dart` | Unreachable/dead-end screens, return-value contracts on every pop, unsaved-changes guards on multi-field forms, dialog stacking on double-tap, web browser-back mid-flow |
| B9 | Data & persistence integrity | 4 | `pet_repository.dart`, `legacy_local_migration.dart`, `models/*` | Model round-trip incl. unicode/emoji/whitespace/very long, cascade-delete completeness, timezone/DST off-by-one, migration non-destructiveness (schema is at v10 with `onUpgrade` — prove no drop), web quota + corrupt-JSON recovery, second-account isolation |
| B10 | Web/platform safety | 7 | `export_service.dart`, `notifications_service.dart`, `pet_file_image*`, `google_web_identity*` | Every platform API behind `kIsWeb`/conditional import (verified: `pet_file_image.dart` uses a correct conditional export); simulate picker/share/download/notification/URL failure paths; cold web load with Firebase unreachable |
| B11 | Perf & jank (measured) | 9 | `home_screen.dart`, `providers/furlo_state.dart` | F-014/C-027: narrow whole-object `context.watch<FurloState>()` reads; before/after **measured** rebuild counts, instrument removed afterwards |
| B12 | Test-depth backfill | 11 | `test/` | Cover the error/empty/web/migration branches this audit touched; assert determinism (no wall-clock, no real timers) |
| B13 | Reports | all | `docs/` | Consistency matrix, terminology table, 14×8 sign-off matrix, verification log |

**Excluded by design:** C-026 / N-005 file-size extraction (advisory, architectural — out of scope
for a cohesion pass; recorded, not done).

## 4. Severity policy

Fix every Blocker and High. Fix Mediums unless the fix is risky — record the reason for any
Medium or Low left open. C-045 (never use `primaryMuted@0.75` as a sole border) is a standing
advisory checked during B1 and B6, not a change of its own.

## 5. Deliverables

- Two artifacts first (this plan + the task list), **approved before the first code edit**.
- `docs/full-app-cohesion-audit-report.md`: scope & method, the Phase 0 inventory, the findings
  register (`ID | Sev | Track | File:line | Evidence | Fix | Status`), the filled **Track 6
  consistency matrix**, the filled **Track 12 terminology table**, and the payoff artifact — a
  **14 screens × 8 columns sign-off matrix** (loading, empty, error, data, 375px, 1440px,
  themed-colors-only, has-back) where every cell is ✅ / ❌ / blocked.
- A verification log: exact commands, exit codes, URLs, viewport sizes, console observations, and
  an explicit split between *verified by running* and *read only*.
- One local commit per item.

## 6. Definition of done

All Blockers/Highs fixed; every Medium fixed or justified; the sign-off matrix complete with no
unexplained ❌; `flutter analyze` and `flutter test` exit 0 with counts recorded; every UI change
seen at 375px and 1440px by *some* executed instrument; every blocked check named with its cause
rather than claimed as a pass.
