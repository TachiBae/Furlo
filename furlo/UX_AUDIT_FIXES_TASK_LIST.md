# UX/UI Audit Fixes — Task List

Order of execution. One commit per item (message prefix `Item N:`). Analyze +
test must exit 0 before every commit. **Approval of this list is required before
the first code edit.**

## Phase 1 — High

- [ ] 1. Vet Contacts: try/catch + error state + Retry (vet_contacts_screen.dart:66)
- [ ] 2. Feeding: block Weekly/Custom save with 0 days, inline error
- [ ] 3. Overdue/missed caption color -> >=4.5:1 (home:881, feeding:766, status_pill:19)
- [ ] 4. Delete-pet button label contrast -> >=4.5:1 (pet_profile:237)
- [ ] 5. Home nav: real selection state + badge from real reminder count (home:227, 389)

## Phase 2 — Medium

- [ ] 6. Friendly copy: drop "Cause:" detail; reword cloud-setup error (app.dart:400, 427)
- [ ] 7. Sign-in: non-policy password validator; keep 8-char on register
- [ ] 8. Forgot-password success message styled as success (auth_screen_support:70)
- [ ] 9. Font: remove dead 'Inter' reference / use declared bundled font (app_theme:207)
- [ ] 10. Unify AppBar titles at 24 (feeding:525, onboarding:296)
- [ ] 11. Raise 10px/9px text to >=12 via AppTypography tokens (home:542, weight:363/388)
- [ ] 12. Retry buttons on Vaccinations/Health/Weight error states
- [ ] 13. maxLength 40: pet name, vet name, meal name
- [ ] 14. Deduplicate: date formatter, InputDecoration builder, _titleCase
- [ ] 15. Light theme: real accent/warning/info hues, >=4.5:1
- [ ] 16. Responsive: feeding dialog width; fixed-height widgets at 2.0 scale / 400x300
- [ ] 17. Rebuild reduction: lazy quick-action screens; narrow FurloState reads

## Phase 3 — Low

- [ ] 18. Copy pass: casing, canceled/cancelled, Add vaccine, subtitles, jargon
- [ ] 19. Pull-to-refresh on Weight, Vet Contacts, Feeding
- [ ] 20. Shared delete confirm in Feeding; empty-state CTA; sign-out confirm

## Verification gates

- [ ] After each phase: analyze + test exit 0 (captured)
- [ ] Web verify at 375/1440, all 3 themes; 400x300 + 2.0 scale for item 16
- [ ] Re-compute WCAG ratios for the 5 flagged pairs; report new values
- [ ] Final report: files per item, finding -> commit map, read-only vs run-verified
