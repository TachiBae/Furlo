# UX/UI Audit Fixes — Task List

Order of execution. One commit per item (message prefix `Item N:`). Analyze +
test must exit 0 before every commit. **Approval of this list is required before
the first code edit.**

## Phase 1 — High

- [x] 1. Vet Contacts: try/catch + error state + Retry (vet_contacts_screen.dart:66) — `032e633`
- [x] 2. Feeding: block Weekly/Custom save with 0 days, inline error — `679e1d4`
- [x] 3. Overdue/missed caption color -> >=4.5:1 (home:881, feeding:766, status_pill:19) — `05c6449`
- [x] 4. Delete-pet button label contrast -> >=4.5:1 (pet_profile:237) — `ca534be`
- [x] 5. Home nav: real selection state + badge from real reminder count (home:227, 389) — `3a9f769`

## Phase 2 — Medium

- [x] 6. Friendly copy: drop "Cause:" detail; reword cloud-setup error (app.dart:400, 427) — `71d3c7f` (adapted: account-setup test pins the support code; friendly copy + code kept per user decision)
- [x] 7. Sign-in: non-policy password validator; keep 8-char on register — `b0236ff`
- [x] 8. Forgot-password success message styled as success (auth_screen_support:70) — `455ecf8`
- [x] 9. Font: remove dead 'Inter' reference / use declared bundled font (app_theme:207) — `300f47c`
- [x] 10. Unify AppBar titles at 24 (feeding:525, onboarding:296) — `3060546`
- [x] 11. Raise 10px/9px text to >=12 via AppTypography tokens (home:542, weight:363/388) — `bcfb153`
- [x] 12. Retry buttons on Vaccinations/Health/Weight error states — `81d8402`
- [x] 13. maxLength 40: pet name, vet name, meal name — `40a2d9f`
- [x] 14. Deduplicate: date formatter, InputDecoration builder, _titleCase — `3affd9d`
- [x] 15. Light theme: real accent/warning/info hues, >=4.5:1 — `6c2e999` (adapted: grayscale palette test + dead warning/info tokens; shipped as danger-hue pinning test)
- [x] 16. Responsive: feeding dialog width; fixed-height widgets at 2.0 scale / 400x300 — `b1de6cc`
- [x] 17. Rebuild reduction: lazy quick-action screens; narrow FurloState reads — `c1a3da0`

## Phase 3 — Low

- [x] 18. Copy pass: casing, canceled/cancelled, Add vaccine, subtitles, jargon — `84c1a49`
- [x] 19. Pull-to-refresh on Weight, Vet Contacts, Feeding — `4caaa94`
- [x] 20. Shared delete confirm in Feeding; empty-state CTA; sign-out confirm — `4a5f541`

## Verification gates

- [x] After each phase: analyze + test exit 0 (captured) — final run: analyze 0,
      `flutter test` 190/190 exit 0.
- [x] Web verify at 375/1440, all 3 themes; 400x300 + 2.0 scale for item 16 —
      release `flutter run -d web-server` build: sign-in screen captured at
      375x812 and 1440x900 in Default/Light/Dark plus 400x300; console clean,
      all assets 200. Auth-gated screens (home/feeding/vets/weight/…) cannot be
      reached without credentials — verified by widget tests, including the
      400x300 @ 1.0/1.5/2.0 overflow sweep (browser exposes no text-scale
      control in release mode).
- [x] Re-compute WCAG ratios for the 5 flagged pairs; report new values —
      `python3 wcag_check.py`: all 15 pairs pass (Default 5.18/5.66/5.35,
      Light 6.54/6.00/6.54, Dark 6.01/6.75/6.75; pill borders 3.45–4.26 vs 3.0).
- [x] Final report: files per item, finding -> commit map, read-only vs
      run-verified — delivered in the session thread.
