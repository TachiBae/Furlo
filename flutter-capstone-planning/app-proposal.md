# 1. Proposal, version 2 — Furlo

---

## App name

**Furlo: Pet Health & Care Tracker**


## The problem, in one sentence

Pet owners juggle feeding, vaccination, health, weight, and vet information from memory or scattered notes, making it easy to miss important care tasks or lose track of a pet's records.

*(Re-checked against "an app for students" drift — this still describes a specific situation: 1–3 pet households, specific data types, specific failure mode of missed/scattered info. No change needed.)*

## Who is this for

- Pet owners managing 1–3 pets at home — an individual tracking their own pet(s), or a small household where multiple people feed/care for the same pet and no one's sure who did it last.
- Today they use memory, a physical notebook, or vet appointment stickers/calendars — nothing centralized, so schedules and records live in different places or different people's heads.

*(Unchanged from prelim.)*

## Core features (MVP), revised

| # | Feature | Still in the MVP? | Flutter pieces it needs | Honest estimate |
|---|---|---|---|---|
| 1 | Pet onboarding | keep | `TextFormField`, `image_picker` for photo, `Form` + validation, `Navigator.push` to Home | 3 hours |
| 2 | Pet list/home | keep | `ListView.builder` (pet cards row), `Card`, `BottomNavigationBar`, `GestureDetector` for pet card tap | 2 hours |
| 3 | Feeding | keep | `ListView.builder`, `Checkbox`/status toggle, `sqflite` query + `Provider` for done-today state, local notification schedule via `flutter_local_notifications` | 5 hours |
| 4 | Vaccinations | keep | `ListView.builder`, `showDatePicker` (date given / next due), status pill widget, `sqflite` CRUD | 4 hours |
| 5 | Health records | keep | `ListView.builder`, `DropdownButton` (record type), conditional `Switch` + frequency field for medication entries, `sqflite` CRUD | 4 hours |
| 6 | Vet contacts | keep | `ListView.builder`, many-to-many join table in `sqflite`, `showDialog` for delete confirmation, `url_launcher` for the Call button | 6 hours |
| 7 | Weight tracking | keep | `ListView.builder`, a chart package (e.g. `fl_chart`) for the trend line, `sqflite` CRUD | 4 hours |
| 8 | Profile/account | keep | `ListView` of `ListTile`s, `SharedPreferences` or `sqflite` for settings values | 2 hours |
| 9 | Notifications | keep | `flutter_local_notifications`, per-type `Switch` list, permission request flow | 4 hours |

**Total: 34 hours for the 9 core screens/features, plus roughly 4–6 hours of one-time setup (repository interface + `sqflite`/Drift schema, `ThemeData` from the design system, base navigation shell) that isn't tied to any single feature. Call it ~38–40 hours total.**

Rules followed: every row names real widgets, not "a nice interface." At ~38–40 hours, this comfortably fits a one-term project for someone already comfortable with Flutter from m4a4/m5a5 — nothing here needed to be cut to stretch on hours alone. Vet contacts (#6) is the one feature worth watching, not because of hours but because of the join-table complexity flagged in the risks section below; if that risk materializes and eats more time than budgeted, it's the single feature with no dependents, so it's the cleanest one to demote if the term gets tight.

## Stretch goals

1. Multi-user/shared pet care
2. Calendar view for vaccinations/vet appointments
3. Vet clinic location/map
4. Firebase Auth
5. Theme preference (light/dark)
6. Vet document/receipt scanner
7. Pet breed/weight-context tips
8. Weekly care summary
9. "Ask about my pet" chat

## NEW: How my app saves data

- **If two different people install my app, should they see the same data?** **No.** Furlo is a single-device, single-user local tracker for MVP — there's no login gate by default (auth is a stretch goal, and even if built, it authenticates *access*, not *sync*). Two installs are two independent pet lists.
- **Roughly how many records in a realistic week of use:** For a household with 2 pets — 2 pet rows, ~14 feeding entries (2 meals × 2 pets × 7 days, most just status flips on existing rows rather than new rows), 0–1 new vaccination rows, 1–2 health record rows, 0–1 new vet contacts (most weeks: none, they're added once and reused), 1–2 weight entries. Call it **15–20 new/updated rows a week**, growing to a few hundred rows total over a semester of testing — well within what a local relational store handles trivially.
- **My choice:** `sqflite` (local SQLite database).
- **Why this one and not the others:** The data is inherently relational — a vet can be linked to multiple pets and a pet can have multiple vets (explicit many-to-many join table in the proposal), feeding/vaccination/health/weight records all foreign-key against a pet. `shared_preferences` only stores flat key-value pairs, so it can't represent that join table without hand-rolling serialization — more work, not less. Firebase/Supabase solve a problem I don't have (multi-device sync, multi-user accounts) at the cost of setup, network dependency, and a secrets story I'd have to manage in a public repo. The tradeoff I'm accepting: no cross-device sync, no cloud backup unless I build export separately — acceptable because the app is scoped to one person tracking their own pets on their own phone.
- **What I save, concretely:**
  - `pets` table — id, name, species, breed, birthdate, photo_path
  - `feedings` table — id, pet_id (FK), time, frequency, last_fed_at, done_today
  - `vaccinations` table — id, pet_id (FK), vaccine_name, date_given, next_due_date, status
  - `health_records` table — id, pet_id (FK), title, date, type, notes, reminder_frequency (nullable), reminder_active (nullable bool)
  - `vets` table — id, name, clinic, phone, email, address, notes
  - `vet_pets` join table — vet_id (FK), pet_id (FK), next_appointment_date (nullable)
  - `weight_logs` table — id, pet_id (FK), date, weight, notes (nullable)
  - `notification_settings` table (or `shared_preferences` — small enough either works) — one row/key per toggle: daily_feeding, missed_meal, upcoming_vaccine, overdue_vaccine, vet_appointment, medication
- **Have I tried it yet?** Not yet — spiking `sqflite` init plus the `kIsWeb` repository swap is the first thing to do before any screen gets wired to real data, targeted for this week (by **Aug 30**), so the platform gap gets discovered while it's still a one-hour fix and not a rewrite.
- **Platform caveat (from the extending-your-app unit's platform table):** `sqflite` does **not** run in a Codespace/web build — it's native-only and throws `MissingPluginException` the moment it's called in a browser. Since the graded copy runs via `flutter run -d web-server`, `sqflite` can't be the *only* storage path. Two ways to keep the choice and still run everywhere:
  1. **Repository pattern:** write one `PetRepository` interface, back it with `sqflite` on mobile and an in-memory (or `shared_preferences`-backed) implementation on web, switched with `kIsWeb`. The relational schema above stays true to what ships on a phone; the web build runs on sample data for grading/demo purposes, consistent with what page 13 recommends for any hardware-only feature.
  2. **Swap to Drift** (same relational/SQL model as `sqflite`, but built on `sql.js` so it also runs on web with some extra setup) — keeps the schema and defense above nearly word-for-word, trades the platform gap for a bit more setup now.
  **Decision: Route 1, the repository pattern.** Drift's extra web setup (`sql.js`, WASM asset wiring) is real overhead for a feature — the web build — whose only job is to demo cleanly and get graded, not to persist real data long-term. A thin `PetRepository` interface with a mobile and web implementation is a smaller, more contained piece of work, and it's a pattern worth having anyway (it's what makes the vet–pet join queries testable in isolation, per the second risk below).

## NEW: One thing I want to add that the course did not teach

Four candidates came out of reviewing the wireframes against the extending-your-app unit — export, a vet document/receipt scanner, a vet clinic map, and a Gemini-powered "ask about my pet" chat. Export is the one I'm committing to for this section, because it's the only one of the four that runs identically on phone and web with no platform gap to fall back from — the other three all needed a `kIsWeb` workaround, and I've already got two of those (storage, notifications) to build. Documenting a feature that *doesn't* need one felt like the more honest use of this section than adding a third compromise.

- **Package:** `pdf` for generating the export file, paired with `share_plus` to hand it off (share sheet on phone, download on web) rather than writing to a device-specific path.
- **Runs where you develop?** Yes — both packages are pure Dart with no native plugin dependency, so this is the one feature in the whole app that needs no `kIsWeb` branch at all. It runs the same way in the Codespace web build as it will on a phone.
- **If it does not run on web:** N/A — it does.
- **Core feature or stretch goal?** Stretch. The app is fully usable without it, and it has no dependents — nothing else in the MVP needs export to exist first.

The other three stay on the stretch list for now, each with a real anchor already drawn in the wireframes rather than being speculative: the receipt scanner extends the existing Health Records "Add Record" flow via `image_picker` (already in the MVP for pet photos, so the web fallback pattern is identical — file-picker instead of camera); the vet map would attach to the address field already shown on the Vet Details screen, most simply via `url_launcher` opening the phone's native maps app rather than embedding `google_maps_flutter`, to avoid a second API key; and the chat feature is the most open-ended of the four — nothing in the current wireframes represents it yet, so it would need new screens before it needs a package decision.

## NEW: How my project runs when someone else opens it

- **Keeping the `device_preview` wrapper:** Yes — keeping it from the Module 4/5 starters, since it's how the grader sees phone-sized screens, frame, and orientation in a browser. It doesn't simulate hardware (camera, GPS, native storage), which is exactly the gap the two items below cover.
- **Runs in a browser with `flutter run -d web-server`, every screen reachable:** Not yet as scoped — three pieces are native-only per the platform table and will need a web fallback before every screen is reachable in a Codespace:
  - `sqflite` (all data screens) — needs the repository-swap or Drift fix noted in the storage section above.
  - `image_picker`'s camera capture (Add New Pet photo, potentially health record photos) — the file-picker path still works on web, so the fallback is: web uses file-picker/sample image, phone uses live camera.
  - `flutter_local_notifications` — native-only; on web the Notifications *settings* screen (the toggles) still renders and is clickable, it just won't actually fire a reminder in the browser. That's fine for grading — the screen is reachable, the feature's real behavior gets shown in the phone recording per page 13.
- **Anything needing real hardware degrades to sample data instead of crashing:** That's the plan — camera → file-picker/sample photo on web, notifications → toggle UI works but doesn't fire on web, `sqflite` → in-memory/sample data on web via the repository swap decided above. Wiring and confirming all three `kIsWeb` branches is scoped into the same setup pass as the storage spike, by **Aug 30**.
- **Public repo, own GitHub account — anything needing a key, password, or real personal data?** Furlo's MVP as scoped (local `sqflite` + repository pattern, no auth, no cloud) needs **no API keys or secrets** to run. If authentication (stretch goal) gets built for real rather than left as UI-only wireframes, and if it touches any third-party service, that's the point a git-ignored `.env` + repo secrets setup becomes necessary — [YOUR INPUT NEEDED — this one's yours: confirm your GitHub username/repo, since I don't have that, and whether auth is getting built or staying as wireframes].

## Data the app remembers

| Thing | Fields | Where it is saved |
|---|---|---|
| Pet | name, species, breed, birthdate, photo_path | `sqflite` — `pets` table |
| Feeding entry | pet_id, time/frequency, last_fed_at, done_today | `sqflite` — `feedings` table |
| Vaccination | pet_id, vaccine_name, date_given, next_due_date, status | `sqflite` — `vaccinations` table |
| Health record | pet_id, title, date, type, notes, reminder_frequency, reminder_active | `sqflite` — `health_records` table |
| Vet contact | name, clinic, phone, email, address, notes | `sqflite` — `vets` table |
| Vet–pet association | vet_id, pet_id, next_appointment_date | `sqflite` — `vet_pets` join table |
| Weight log | pet_id, date, weight, notes | `sqflite` — `weight_logs` table |
| Notification settings | per-type toggle (6 types) | `sqflite` (`notification_settings`) or `shared_preferences` |
| Profile/account | display name, [YOUR INPUT NEEDED — anything else account-related you're actually building] | `shared_preferences` or `sqflite` |

*(Every field above traces back to the wireframes and the original data model — nothing added or dropped except making the vet–pet relationship's join-table nature explicit, which the prelim already called out.)*

## Screens

1. Splash / Sign In / Create Account *(stretch — designed, optional entry point)*
2. Pet onboarding — Add New Pet
3. Pet list / Home
4. Pet profile
5. Feeding schedule
6. Vaccinations
7. Health records
8. Vet contacts
9. Add Vet / Vet details
10. Weight tracking
11. Add Meal / Add Vaccination / Add Health Record / Add Weight Entry (add-forms, one per feature)
12. Profile / Settings
13. Notifications (settings)
14. Forgot Password / Verify Identity / Create New Password *(stretch, part of Auth)*

*(This matches the wireframe sheet and UX flow diagram exactly — 14 screens including the stretch-goal auth flow, 9 core screens if auth is excluded, consistent with the "11 screens including stretch" count in the prelim.)*

## Risks, revised

- **The risk I named last time — notifications firing while the app is closed:** Still a real risk, and arguably a bit bigger now that the platform table confirms `flutter_local_notifications` is native-only — it joins `sqflite` on the list of things that simply don't run in the web build at all, which wasn't obvious from the prelim. Smaller in one sense: the fix pattern is the same `kIsWeb`-guarded fallback already planned for storage, so it's not a separate problem to solve, just the same pattern applied a second time. **First step: get one notification actually firing on a physical/emulated Android device (not just scheduled in code) by Sept 13**, after the storage and vet-pet risks above are settled, since notifications depend on feeding/vaccination data already existing to have something to remind about.
- **A new risk I did not see before:** `sqflite` — the storage choice defended above — does not run in a Codespace/web build at all (native-only, throws `MissingPluginException` in the browser). Since the graded copy has to run via `flutter run -d web-server` with every screen reachable, storage can't be a single hard-coded `sqflite` call scattered through the widgets; it needs a repository interface swapped between a real `sqflite` implementation (phone) and an in-memory/sample-data implementation (web) from day one. Retrofitting that swap after the data layer is already wired into every screen is the expensive version of this mistake. **First step: write the `PetRepository` interface and both implementations before building the first data screen, by Aug 30.**
- **A second new risk:** the vet–pet many-to-many relationship (`vet_pets` join table) is the one piece of schema more complex than anything in m4a4/m5a5, which was mostly single-table CRUD. Getting the join queries right (a vet's associated pets, filtering contacts by pet, editing associations later) is a risk if joins haven't been practiced yet. **First step: build the `vet_pets` schema and one join query in isolation (print results to console, no UI yet) by Sept 6**, before wiring it into the Vet Contacts screen — same repository pattern from the first risk makes this testable without a UI in the loop.

## What changed, and why

| Section | Prelim said | Now says | Why it changed |
|---|---|---|---|
| Data model | Vet contact/association described in prose | Vet–pet relationship made explicit as its own `vet_pets` join table with `sqflite` types named | Wireframe review (Dr. Sarah Miller detail screen, associated-pets chips) showed vet-pet is genuinely many-to-many in the actual UI, not just describable in a sentence — `sqflite` needs that as a real join table, not a nested field, or the "filter vets by pet" and "edit a vet's assigned pets" features in the prelim can't actually be queried |
| Storage | Not specified (prelim didn't require it) | `sqflite`, defended against `shared_preferences`/Firebase/Supabase | New requirement in this worksheet — reasoning above |
| Core features | 9 features listed with no hour estimates | Same 9 features, all kept, with widgets + hours named (~38–40 hours total) | Re-scored against real Flutter build pace from m4a4/m5a5; total fits the remaining term, so nothing needed to move to stretch on hours alone — the scope was already right-sized |

*(If, after filling in real hours, nothing substantive changed — say that explicitly and defend it: what did building m4a4/m5a5 confirm was right about the original plan? That's a legitimate answer but it needs to point at something you actually did.)*

---

**Before submitting:** every `[YOUR INPUT NEEDED]` above needs your own numbers/decisions — that's intentional. The grading rubric weights the persistence reasoning and the change log most heavily, and both are supposed to reflect what you personally learned building m4a4/m5a5, which I can't know for you.
