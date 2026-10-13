# UX/UI Audit Fixes — Implementation Plan

Branch: `fix/ui-audit` (off `main` @ a6275aa). Source: the 33-finding UX/UI audit
(0 Blocker, 5 High, 17 Medium, 11 Low). Numbering matches the master prompt.

## Ground rules

- All data access stays through the repository. No new dependencies.
- Dark theme tokens only: `AppPalette` / `AppSpacing` / `AppRadius` / `AppTypography`
  in `lib/utils/app_theme.dart`. Never hardcode a color.
- No destructive migrations. No refactors beyond this list.
- Every behavior change gets a test in `test/`.
- `flutter analyze --no-pub` and `flutter test --no-pub` must exit 0 (capture exit
  codes explicitly) before each commit.
- UI changes: `flutter run -d web-server`, browser-verify changed screens at 375px
  and 1440px, all three themes; spot-check 400x300 and 2.0 text scale for item 16.
- One commit per item; ask before deleting files, `git push`, `git reset`.

## Phase 1 — High (items 1-5)

1. **Vet Contacts load errors** — wrap `_load()` (vet_contacts_screen.dart:66) in
   try/catch; add error state + Retry button reusing the provider-style copy
   ("Vet contacts could not be loaded."). Test: repository throws -> error widget
   shown, retry reloads.
2. **Weekly/Custom feeding with 0 days** — validate `daysOfWeek` non-empty in the
   add/edit dialog (feeding_screen.dart:266-300); inline error under the day chips.
   Test: save Weekly with no days -> blocked; with days -> saves.
3. **Overdue caption contrast (2.87:1 -> 4.5:1+)** — replace `primaryMuted` status
   color at home:881, feeding:766, status_pill:19 with a token that passes in all
   3 themes (default: `danger` or a new `warning`-based token in AppPalette).
   Test: token-level contrast test + existing screen tests keep passing.
4. **Delete-pet button contrast (3.01:1)** — pet_profile:237: dark label on
   `danger` (use existing `textOnDanger` swapped to dark for default theme) or
   darken `danger`; keep >=4.5:1 in all themes. Test: contrast test.
5. **Home bottom-nav state + badge** — stop force-resetting `_activeTab`
   (home:227); screen opens as tab 0 and returns to Home on pop; badge reflects
   actual unread reminder count (home:389), hidden when 0. Tests: tap nav item ->
   route pushed + Home stays selected on return; badge hidden with 0 reminders.

## Phase 2 — Medium (items 6-17)

6. Friendly error copy: app.dart:400 drop "Cause:" detail; app.dart:427 reword
   "Cloud setup..." -> "We couldn't start Furlo. Try again." (keep retry action).
7. Sign-in: use a non-policy password validator (non-empty only) at sign_in:66;
   keep 8-char rule on create-account. Test: short password no longer blocked
   on sign-in, still blocked on register.
8. Forgot-password success message styled success (not `danger`) at
   auth_screen_support:70; parameterize the message color. Test: widget test
   asserts success color token.
9. Font: remove dead `Inter` fontFamily (app_theme:207) and use the bundled
   NotoSans assets if already declared in pubspec, else system default. Verify
   pubspec `flutter: fonts:` declaration first. No new assets.
10. AppBar titles: unify at 24 (remove 18px overrides feeding:525, onboarding:296).
11. Minimum text size 12: nav label 10->12 (home:542), chart axes 9->11
    (weight:363,388); add `AppTypography.navLabel` / keep sizes in tokens.
12. Retry buttons on error states: Vaccinations/Health/Weight (providers expose
    `error`; add onRetry calling `refresh()`).
13. `maxLength` (40) on pet name, vet name, meal name fields; aligned with
    profile display name cap.
14. Deduplicate: shared short-date formatter (health:556, vaccination:566,
    weight:548, vet:500, notifications_service:716), shared InputDecoration
    helper (feeding:480, vaccination:518, health:540, weight:528, vet:424),
    shared `_titleCase` (health:575, vaccination:593). Pure moves; no behavior
    change; existing tests must pass.
15. Light theme semantics: **resolved differently** — urgency (overdue/missed)
    already routes through `danger` after item 3, and Light's danger is red
    (6.54:1). The grayscale test forbids recoloring `accent`, and `warning` /
    `info` are dead tokens (zero references in lib), so recoloring them would
    be invisible. Item 15 ships as a pinning test that Light's danger stays a
    hue while neutrals stay grey.
16. Responsive/scale fixes: feeding dialog width (feeding:141) -> window-relative
    with maxWidth; audit fixed heights (home:366, 890, 280; record_components:32,
    75) for 2.0-scale clipping -> min-height/constraints. Tests: existing
    short-viewport tests extended to 400x300 + textScaleFactor 2.0.
17. Rebuild reduction: build Home quick-action screens lazily (home:1015-1077);
    replace whole-object `context.watch<FurloState>()` with narrower reads/selectors
    at home:255/986, feeding:519, vet:121/342, app:462. Behavior-preserving;
    covered by existing tests.

## Phase 3 — Low (items 18-20)

18. Copy pass (grep-verified): canceled->cancelled (pet_profile:189); unify
    "Add vaccine/vaccination" (vaccination:122/192); sentence-case all Save/Add
    buttons; "Add New Pet"->"Add pet"; onboarding Title Case -> sentence case
    (onboarding:57,85); "fire"/"gear" copy (notifications:146,66); drop setup
    subtitle when editing (feeding:135); auth Furlo/welcome dedupe
    (auth_screen_support:51/62); unify "Missed / Overdue" wording. Update
    affected string-matching tests.
19. Pull-to-refresh: add RefreshIndicator to Weight, Vet Contacts, Feeding
    (mirror Health/Vaccinations).
20. Shared `confirmRecordDelete` in Feeding (feeding:446); CTA on "No pets yet."
    empty (home:992); confirm dialog before Sign out (profile:93).

## Constraints discovered during Phase 1 (from the existing test suite)

- `profile_settings_test.dart` asserts the Light/Dark palettes **remain
  grayscale**. Item 15 as written ("real hues for Light") would break a
  deliberate design constraint — adapt to grayscale-distinguishable urgency
  (weight/shape/contrast steps) or raise with the user before changing it.
- `account_setup_error_test.dart` asserts account-setup failures **show the
  platform error code** ("not a bare message"). Item 6's "drop the Cause:
  detail" conflicts with a deliberate test — adapt: keep the short code for
  diagnostics, reword the surrounding copy, or raise with the user. Never
  weaken an intentional test just to make a change pass.

## Verification protocol (after every phase)

- `flutter analyze --no-pub` and `flutter test --no-pub`, exit codes captured.
- Web run + browser check at 375/1440 in all 3 themes for changed screens.
- Re-run the WCAG computation for the 5 previously flagged color pairs and
  report new ratios.
- Final report: files changed per item, finding-ID -> commit mapping, and an
  explicit list of anything verified only by reading.
