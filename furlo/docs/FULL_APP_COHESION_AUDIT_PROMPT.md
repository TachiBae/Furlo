# Prompt — Furlo full-app cohesion audit (every screen, every path)

Copy everything between the horizontal rules into a fresh session to run this audit.

---

## Mission

Audit the **entire Furlo Flutter app** end to end — from individual text tokens and one-line
validators up to whole flows (auth → pet onboarding → home → per-feature CRUD → settings →
export) — and then **fix** what you find. The goal is one coherent product: consistent look,
consistent behavior, consistent copy, no dead ends, no thrown exceptions, no silent data loss.
Reduce bugs and errors; do not add features.

You are expected to find 30+ real issues. Zero findings means you did not look hard enough.

---

## Non-negotiable project rules

- The app lives in `./furlo`. Run every flutter command from `./furlo`; all `lib/` and `test/`
  paths are relative to `./furlo`. Commit from the repo root.
- Provider for state. `PetRepository` is sqflite on mobile and SharedPreferences on web,
  switched by `kIsWeb`. All data access goes through the repository — no screen touches
  storage, SharedPreferences, sqflite, or Firestore directly.
- Dark theme tokens only (`AppPalette`: Wondrous Wisteria / Succulent Lime / Black Rock).
  **Never hardcode a `Color(0x...)`, `Colors.*`, or font/spacing literal in a screen or widget.**
- Single user, local-first. No secrets. Never run destructive migrations on existing data.
- Don't refactor unrelated code. No new dependencies.
- Add tests for new logic. `flutter analyze` and `flutter test` must pass before you finish.
- **The app is graded on web** (`flutter run -d web-server`) inside `device_preview`. No screen
  may throw on web. Web is the platform that matters most.
- Ask before deleting files, pushing, resetting, or anything that removes data. `pub get`,
  `analyze`, `test`, `run`, and reading are pre-authorized.

---

## Phase 0 — Inventory before you form opinions

Produce a factual inventory, not a summary of the docs:

1. **Read the existing records first** so you don't re-litigate settled issues or contradict
   verified results: [docs/ui-audit-report.md](docs/ui-audit-report.md),
   [docs/app-health-report.md](docs/app-health-report.md),
   [docs/design-cohesion-final-report.md](docs/design-cohesion-final-report.md),
   [web-ui-verification.md](../web-ui-verification.md), plus the `*_PLAN.md` /
   `*_TASK_LIST.md` files in `./furlo`. Any finding still open there is in scope; anything
   closed needs a *fresh test* before you reopen it.
2. Enumerate every screen (`lib/screens/**`), widget (`lib/widgets/**`), provider
   (`lib/providers/**`), repository (`lib/repositories/**`), service (`lib/services/**`), and
   util (`lib/utils/**`) with its line count and its public surface.
3. List every navigation edge: which screen pushes/pops which, every `MaterialPageRoute`,
   `Navigator.pushReplacement`, named route, `showDialog`, `showModalBottomSheet`, and every
   tab in the home shell. Find unreachable screens (no inbound edge) and dead ends
   (no outbound edge / no `AppBar` back).
4. List every user-visible string and classify it (title, label, hint, error, empty state,
   confirm, toast). You need this for the terminology check in Track 12.
5. List every persisted field and the exact key/column it lands in, for both the sqflite and
   SharedPreferences code paths.
6. Record the baseline: `flutter analyze`, `flutter test` (with pass/fail counts), and the
   web-server URL you will use. Do not change code until the baseline is captured.

---

## Execution order (respect it)

1. **Deliver an Implementation Plan and a Task List as markdown artifacts in `./furlo`, then
   stop and wait for approval.** The plan names every file you expect to touch and every fix
   batch; the task list is the ordered checklist.
2. After approval, work one item at a time. After each item: `dart format`, `flutter analyze`,
   `flutter test`, then **commit locally** (`Item N: <what changed>`).
3. Track every deferred or rejected finding in the report with a reason. Do not silently drop.

---

## The audit tracks

For every track: **search for the violation, read the surrounding code, then fix at the source
or add the missing case.** A track is only "done" when you have either changed code or recorded a
verified finding that no change is needed.

### Track 1 — Design tokens & visual cohesion
- Grep for `Color(0x`, `Colors\.`, `Color.from`, raw `fontSize:`, `EdgeInsets.all(` with magic
  pixel values, `BorderRadius.circular(<literal>)`, `SizedBox(height: <literal>)` outside
  `app_theme.dart`. Every one is a candidate; judge each on whether it should be a token.
- Verify `AppPalette.defaultTheme` / `light` / `dark` are complete and every member is actually
  used (dead tokens are a smell — remove or wire them).
- Check the type scale, spacing rhythm, corner radii, border widths, elevation, and icon sizes
  are drawn from one shared set; the same component (pill, card, list tile, chart, input,
  button) must look identical on every screen.
- Check button hierarchy: exactly one primary action per screen, secondary/tertiary usage
  consistent, destructive actions use `danger`, disabled states use `textDisabled`.
- Check contrast: compute WCAG ratios for text-on-surface, text-on-primary, text-on-accent,
  text-on-danger, and pill borders. Flag anything under 4.5:1 body / 3:1 large or non-text.
- Check status colors (`status_pill.dart`, overdue/due-soon captions) map to the *same* semantic
  meaning everywhere.
- Check no screen renders light-theme or default-Material colors because a widget bypassed the
  palette (e.g. a dropdown, `DatePicker`, `SnackBar`, `Dialog`, text selection handle, or
  `CircularProgressIndicator` using the framework default).

### Track 2 — Navigation & routing cohesion
- Walk every flow both forward and back. Every screen must be reachable, and every screen must
  be exitable by back, swipe, browser back, and the app bar.
- Auth gate: signed-out → sign-in; signed-in-without-profile → complete profile; signed-in →
  home. No route may flash the wrong shell, loop, or render a blank frame.
- Home shell tabs: selected-tab state, preserved scroll per tab, double-tap-to-top if used
  elsewhere, and no tab resetting another tab's state.
- Every `Navigator.pop` must return what the caller expects (apply result vs discard). Look for
  editors that pop without saving and never tell the user.
- Check unsaved-changes interception on multi-field forms (pet onboarding, profile, health
  record, vaccination, vet, feeding, weight). Backing out must not silently discard input.
- Web: browser back must not exit the app mid-flow or kill state; in-page Google sign-in must
  not open a popup that gets blocked.
- Check `showDialog` / bottom sheets are dismissible, scrollable on short viewports, and that
  two dialogs can never stack from a double tap.

### Track 3 — State management & the loading/empty/error triad
- For **every** screen that reads async data, verify all four render paths exist and are
  distinct: loading, loaded-but-empty, loaded-with-data, and error-with-retry. Screens missing
  the error path or the empty CTA are findings.
- Check providers: no `notifyListeners()` during `build`, no mutation of a list/map handed to
  the UI, `dispose` correctly cancels/clears, and no provider leaked across the auth boundary
  (a previous account's data must not survive sign-out or a user switch).
- Check every `await` is followed by a `mounted` / `context.mounted` guard before using
  `context`, `setState`, or a `ScaffoldMessenger`.
- Look for races: two loads in flight, a refresh overwriting newer data, a load racing a write,
  a delete racing a re-render, double-tap submit firing twice.
- Verify pull-to-refresh exists and actually re-fetches on every data list, and that the
  indicator is themed.
- Verify failures are surfaced once (not three snackbars) and are actionable ("Couldn't load
  vaccinations. Retry").

### Track 4 — Data, repository & persistence integrity
- Confirm the sqflite path and the SharedPreferences path implement the *same* interface and
  the *same* semantics: same ordering, same null/empty handling, same defaults, same cascade.
- Round-trip test every model: create → persist → reload → compare all fields, including
  nullable/optional ones, unicode and emoji in names/notes, very long strings, empty strings,
  leading/trailing whitespace, and duplicate names.
- Delete cascades: deleting a pet must remove its weight logs, feedings, health records,
  vaccinations, and vets — with no orphan rows and no crash if the child list is empty.
- Date/time handling: storage format, timezone, DST boundaries, "today" comparisons computed at
  midnight, future dates, and records dated before the pet's birth. Find off-by-one-day bugs.
- Auth/scope keys: every write is scoped to the current user; signing in as a second account
  shows only that account's data; legacy local data is imported exactly once with consent.
- Migrations: schema version bumps must be additive and non-destructive; existing rows must
  survive. Never change a column type or drop a table on upgrade.
- Web-specific: SharedPreferences storage quota exceeded and corrupted-JSON recovery — the app
  must not throw or silently drop everything without telling the user.
- Check ID generation for collisions after rapid inserts and for stability across reloads.

### Track 5 — Forms & validation cohesion
- Build one table of every input across the app: field, required?, max length, trim?, validator,
  keyboard type, error string. Inconsistencies are findings (same kind of field validated
  differently on two screens).
- Verify: errors appear on blur/submit not on every keystroke; error text is the same wording
  style everywhere; submit is disabled or idempotent while in flight; whitespace-only input is
  rejected; numeric fields reject locale separators, `e`, `+`, negative where invalid, and
  absurd magnitudes; date pickers constrain `firstDate`/`lastDate`.
- Check focus traversal: tapping "next" on the keyboard moves through fields in visual order;
  the last field submits; the keyboard does not cover the field or the submit button on a
  375px-wide, short viewport.
- Check paste and autofill paths, and that a failed save keeps the user's input on screen.

### Track 6 — Cross-feature consistency matrix
Build and fill this table; every row must read identically across every feature:

| Concern | Feeding | Health | Vaccination | Weight | Vets | Pets | Settings |
|---|---|---|---|---|---|---|---|
| Pet selector present & identical | | | | | | | |
| Date/time picker style | | | | | | | |
| Delete confirmation dialog | | | | | | | |
| Save success feedback | | | | | | | |
| Empty state (icon + copy + CTA) | | | | | | | |
| Error state + retry | | | | | | | |
| List item layout & trailing action | | | | | | | |
| Sort order & grouping | | | | | | | |
| Filter/search (or explicit none) | | | | | | | |
| Pull-to-refresh | | | | | | | |
| Overdue/due-soon indicator | | | | | | | |

Any cell that differs from the majority is either fixed or documented with a UX reason.

### Track 7 — Platform & web safety
- Grep for `dart:io`, `File(`, `Platform.is`, `image_picker`, `file_picker`, `url_launcher`,
  `flutter_local_notifications`, `share_plus`, `pdf`, `sqflite`. Each must be behind a
  `kIsWeb` guard or a `*_stub.dart` / `*_web.dart` conditional import. A single unguarded call
  is a blocker: on web it throws and the screen dies.
- Simulate the web failure paths: picker unavailable, share unavailable, download blocked,
  notifications unsupported, external URL refused — every one must degrade to a clear message.
- Check no screen throws when permissions are denied or a platform API returns null.
- Confirm every screen renders on a cold web load with **no** Firebase/network reachable, and
  that an init failure renders a usable screen rather than a spinner forever.

### Track 8 — Accessibility
- Every icon-only control has a semantic label; every image has a label or is explicitly
  decorative.
- Tap targets ≥ 48×48 dp — check pills, chips, close buttons, and list trailing icons.
- Text scale 1.0 → 2.0: no clipped or overflowing text, no fixed-height containers that cut
  content. Test at least the three densest screens.
- Full keyboard traversal on web: Tab order is visual order, focus is always visible, Enter
  activates, Escape dismisses dialogs.
- Screen-reader reading order matches visual order; dialogs move focus in and restore it on
  close.

### Track 9 — Performance & jank
- Check rebuild scope: `Provider.of` vs `context.select`/`watch` narrowed correctly; a
  keystroke in a search box must not rebuild the whole list.
- Check `build` methods for allocation-heavy work (sorting/filtering/formatting per build,
  `DateTime.now()` in build, building large lists without `itemBuilder`).
- Check `const` usage on static widgets, and that long lists are virtualized.
- Check charts (`fl_chart`) and image widgets for redundant repaints and missing size bounds.
- Measure, don't guess: if you claim an improvement, capture a before/after number
  (rebuild count via a temporary counter, or scroll frame timing), then remove the instrument.

### Track 10 — Error handling & observability
- Grep for `catch`, `catch (_)`, `catch (e) {}`, `.catchError`, `!` bang operators, and
  `late` fields. Every swallow is a finding; every bang that can be null is a crash.
- Verify user-facing error copy is specific and actionable, never a raw `e.toString()` and never
  a bare "Something went wrong" where the cause is known.
- Verify logged diagnostics contain no PII and no secrets, and that errors route through the
  existing diagnostics helper (`app_diagnostics.dart`) rather than `print`/`debugPrint` scatter.
- Verify a thrown error in one screen cannot take down the shell — check for an `ErrorWidget`
  boundary and a retry path.

### Track 11 — Test coverage depth
- Map tests to screens/providers/repos. List untested units and untested branches (error paths,
  empty states, web branches, cascade deletes, validators).
- Confirm tests are deterministic: no real network, no real timers, no wall-clock dependency, no
  order dependency, no shared mutable state between tests.
- Add tests for every behavior you changed, and for the top untested branches you find. Prefer
  widget tests that assert the *rendered state* (empty/loading/error/data) over implementation
  detail.
- Verify no test asserts on a hardcoded color string that will drift from the palette.

### Track 12 — Copy & terminology cohesion
- Build the terminology table and enforce one term each: pet vs animal vs companion; feeding vs
  meal vs food; vaccination vs vaccine vs shot; weight vs weigh-in; vet vs veterinarian;
  health record vs medical record; sign in vs log in.
- Check capitalization style (sentence case vs Title Case) is uniform for titles, buttons, and
  labels; no trailing periods on buttons; consistent ellipsis and `…` glyph.
- Check date/time/number formatting goes through `formatting.dart` and renders identically on
  every screen, including age ("2y 3m"), weights with units, and relative dates ("in 3 days",
  "2 days overdue", "Today", "Yesterday").
- Check pluralization ("1 record" / "2 records"), empty-state copy, confirm-dialog verbs
  ("Delete" vs "Remove" — pick one per consequence), and that no placeholder/lorem text ships.

### Track 13 — Responsive layout & overflow
- For each of the 14 screens, verify 375px, 768px, and 1440px widths with no overflow stripe,
  no clipped control, and no horizontal scroll.
- Verify short viewports (e.g. 375×600) don't overflow — this app has history here
  (`short_viewport_overflow_test.dart`); re-check every screen, not just the known ones.
- Verify long content scrolls (keyboard open + long form), safe areas are respected, and
  `device_preview` frames don't cause layout to depend on device metrics.
- Verify 1440px uses the extra space sensibly (constrained content width / columns) rather than
  stretching inputs to full-bleed.

---

## Fix discipline

- Smallest change that removes the class of bug, at the source (shared widget / util / token),
  not a per-screen patch — but never at the cost of a broad refactor.
- No new dependencies. No lint suppressions, no `// ignore:`, no skipped tests, no weakened
  assertions. If a fix seems to require one, stop and raise it.
- Never change persisted data semantics, keys, or column meanings as a side effect of a UI fix.
- Every new behavior gets a test. Every changed string gets checked for the terminology table.

## Verification protocol (per item, before commit)

1. `cd furlo && dart format lib test`
2. `flutter analyze` → must be clean.
3. `flutter test` → must pass; report exact counts before/after.
4. For any UI change: `flutter run -d web-server`, open the app, and verify the changed screens
   at **375px and 1440px**, including the loading/empty/error paths (force them), and report
   exactly what you saw. If the shared browser or dev-client path is broken in this environment
   (this has happened — see [web-ui-verification.md](../web-ui-verification.md)), say so
   explicitly, fall back to a served release build, and mark the check **blocked** rather than
   passing.
5. Check the browser console and network panel for new errors or failed requests after each
   interaction you exercise.
6. Green analysis/tests are not proof of a visual fix. Never write "verified" for something you
   only read.

## Severity rubric

- **Blocker** — throws, loses data, breaks on web, or blocks a core flow.
- **High** — wrong data shown, unrecoverable state, silent failure, or an unguarded platform call.
- **Medium** — inconsistency, missing state, poor copy, a11y/contrast failure, jank.
- **Low** — polish, spacing, dead code/token, microcopy.

Fix all Blockers and Highs. Fix Mediums unless a fix would be risky; record the reason for any
Medium or Low you leave.

## Deliverables

- `furlo/<NAME>_PLAN.md` and `furlo/<NAME>_TASK_LIST.md` — written first, in the repo's existing
  style, and approved before any code change.
- `furlo/docs/full-app-cohesion-audit-report.md` containing:
  - Scope, method, and the Phase 0 inventory.
  - Findings table: `ID | Severity | Area/Track | File:line | Evidence | Fix | Status`.
  - The Track 6 consistency matrix and the Track 12 terminology table, filled in.
  - A **cohesion sign-off matrix**: rows = all 14 screens × columns = {loading, empty, error,
    data, 375px, 1440px, themed-colors-only, has-back}. Every cell ✅/❌/blocked. This is the
    single artifact that answers "is the app cohesive?".
  - Verification log: exact commands, exact results, URLs used, viewport sizes, and console
    observations.
  - Explicit "what I verified by running" vs "what I only read", and every blocked check.
- One local commit per completed item, from the repo root.

## Final report to me

Files changed, per-item test counts, the sign-off matrix, every remaining ❌ or blocked check
with its cause, and a one-paragraph honest assessment of the app's current cohesion. Do not
claim anything works that you did not run.
