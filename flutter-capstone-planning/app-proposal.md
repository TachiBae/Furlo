## App name

**Furlo: Pet Health & Care Tracker**

(Unchanged from prelim — "Furlo" was settled on during wireframe iteration as the working title and it stuck; no reason to change it now.)

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
| 1 | Pet onboarding | keep | `TextFormField`, `image_picker` for photo, `Form` + validation, `Navigator.push` to Home | [YOUR INPUT NEEDED — hours] |
| 2 | Pet list/home | keep | `ListView.builder` (pet cards row), `Card`, `BottomNavigationBar`, `GestureDetector` for pet card tap | [YOUR INPUT NEEDED — hours] |
| 3 | Feeding | keep | `ListView.builder`, `Checkbox`/status toggle, `sqflite` query + `Provider` for done-today state, local notification schedule via `flutter_local_notifications` | [YOUR INPUT NEEDED — hours] |
| 4 | Vaccinations | keep | `ListView.builder`, `showDatePicker` (date given / next due), status pill widget, `sqflite` CRUD | [YOUR INPUT NEEDED — hours] |
| 5 | Health records | keep | `ListView.builder`, `DropdownButton` (record type), conditional `Switch` + frequency field for medication entries, `sqflite` CRUD | [YOUR INPUT NEEDED — hours] |
| 6 | Vet contacts | keep | `ListView.builder`, many-to-many join table in `sqflite`, `showDialog` for delete confirmation, `url_launcher` for the Call button | [YOUR INPUT NEEDED — hours] |
| 7 | Weight tracking | keep | `ListView.builder`, a chart package (e.g. `fl_chart`) for the trend line, `sqflite` CRUD | [YOUR INPUT NEEDED — hours] |
| 8 | Profile/account | keep | `ListView` of `ListTile`s, `SharedPreferences` or `sqflite` for settings values | [YOUR INPUT NEEDED — hours] |
| 9 | Notifications | keep | `flutter_local_notifications`, per-type `Switch` list, permission request flow | [YOUR INPUT NEEDED — hours] |

**Total: [YOUR INPUT NEEDED — sum the hours above and compare against hours actually left in the term. If it doesn't fit, cut something to stretch now.]**

Rules followed: every row names real widgets, not "a nice interface." If after totaling this the number doesn't fit your remaining weeks, the honest move is to demote one of #7 (Weight tracking) or #6 (Vet contacts) to stretch — they're the two features with no dependency from any other screen, so cutting either doesn't break the rest of the app. That's a suggestion, not a decision I can make for you — you know your actual pace from m4a4/m5a5.

## Stretch goals

1. Authentication — account creation, login, forgot-password. *(Carried over from prelim. Wireframes already show the full flow — Sign In, Create Account, Forgot Password, Verify Identity, Create New Password — so this is designed but explicitly optional for MVP; the app opens directly into onboarding/home without it.)*
2. [YOUR INPUT NEEDED — did anything from the table above get demoted here after you filled in real hours?]
3.

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
- **Have I tried it yet?** [YOUR INPUT NEEDED — did you do the one-hour spike from page 6? If yes, say what happened (did `sqflite` init cleanly, any package conflicts with `image_picker`/`flutter_local_notifications`, etc.). If not yet, name a date.]

## NEW: One thing I want to add that the course did not teach

[YOUR INPUT NEEDED — pick one and answer honestly:]
- **Package:**
- **Runs where you develop? (check platform table):**
- **If it doesn't run on web:** how the app still opens and clicks through in a browser without it, and how you'll demo the real thing (sample data + phone recording).
- **Core feature or stretch goal?**

*(A natural candidate given your interests: the app already needs local notifications for reminders — `flutter_local_notifications` doesn't run in a browser, so this section could just document that gap, since it's already core, not "new." If you want something genuinely new, a candidate that fits the app's theme: a simple photo attachment on health records via `image_picker`, or `fl_chart` for the weight trend line already shown in the wireframe. Your call — write what you actually plan to try.)*

## NEW: How my project runs when someone else opens it

- **Keeping the `device_preview` wrapper:** [YOUR INPUT NEEDED — yes/no, and if no, why]
- **Runs in a browser with `flutter run -d web-server`, every screen reachable:** [YOUR INPUT NEEDED — yes / not yet, and what's missing. Likely candidate for "not yet": local notifications and `image_picker` camera capture both behave differently or are unavailable on web — note the fallback plan.]
- **Anything needing real hardware degrades to sample data instead of crashing:** [YOUR INPUT NEEDED — camera/photo picker and notification permissions are the two hardware-adjacent features here; confirm your fallback.]
- **Public repo, own GitHub account — anything needing a key, password, or real personal data?** Furlo's MVP as scoped (local `sqflite`, no auth, no cloud) needs **no API keys or secrets** to run. If authentication (stretch goal) gets built, and if it uses any third-party service, that's the point a `.env` + repo secrets setup becomes necessary. [YOUR INPUT NEEDED — confirm your GitHub username/repo plan and whether you're building auth for real or leaving it as UI-only wireframes.]

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

- **The risk I named last time — notifications firing while the app is closed:** [YOUR INPUT NEEDED — bigger or smaller after building m4/m5? Did you touch `flutter_local_notifications` at all yet?] First step to reduce it: [YOUR INPUT NEEDED — a concrete next step + a date].
- **A new risk I did not see before:** The vet–pet many-to-many relationship (`vet_pets` join table) is the one piece of schema more complex than anything in m4a4/m5a5 — most of that coursework was single-table CRUD. Getting the join queries right (showing a vet's associated pets, filtering vet contacts by pet, editing associations later) is a real risk if `sqflite` raw SQL joins haven't been practiced yet. First step to reduce it: [YOUR INPUT NEEDED — a concrete next step + a date, e.g. "build the vet_pets schema and one join query in isolation by <date>, before wiring it into the UI"].

## What changed, and why

| Section | Prelim said | Now says | Why it changed |
|---|---|---|---|
| Data model | Vet contact/association described in prose | Vet–pet relationship made explicit as its own `vet_pets` join table with `sqflite` types named | [YOUR INPUT NEEDED — tie this to something concrete, e.g. "wireframe QA passes surfaced that vet-pet is genuinely many-to-many, and sqflite needs that as a real join table, not a nested field"] |
| Storage | Not specified (prelim didn't require it) | `sqflite`, defended against `shared_preferences`/Firebase/Supabase | New requirement in this worksheet — reasoning above |
| [YOUR INPUT NEEDED] | | | [Add rows for anything you're actually cutting/re-scoping once you fill in real hour estimates above — that table is where most of the grading weight sits, so it needs your own build experience, not mine.] |

*(If, after filling in real hours, nothing substantive changed — say that explicitly and defend it: what did building m4a4/m5a5 confirm was right about the original plan? That's a legitimate answer but it needs to point at something you actually did.)*

---

**Before submitting:** every `[YOUR INPUT NEEDED]` above needs your own numbers/decisions — that's intentional. The grading rubric weights the persistence reasoning and the change log most heavily, and both are supposed to reflect what you personally learned building m4a4/m5a5, which I can't know for you.
