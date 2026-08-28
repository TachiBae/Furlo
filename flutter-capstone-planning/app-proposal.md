# 1. Proposal, version 2 — Furlo

---

## App name

**Furlo: Pet Health & Care Tracker**

## The problem, in one sentence

Pet owners juggle feeding, vaccination, health, weight, and vet information from memory or scattered notes, making it easy to miss important care tasks or lose track of a pet's records.

## **Who is this for**

- Pet owners managing 1–3 pets at home — an individual tracking their own pet(s), or a small household where multiple people feed/care for the same pet and no one's sure who did it last.
- 
- Today they use memory, a physical notebook, or vet appointment stickers/calendars — nothing centralized, so schedules and records live in different places or different people's heads.

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

**Total: 34 hours for the 9 core features, plus ~4–6 hours of one-time setup (repository interface, `sqflite` schema, theme, navigation shell). Call it ~38–40 hours total.**

Vet contacts (#6) is the one feature worth watching, not for hours but for the join-table complexity in the risks section below; if that risk grows, it's the single feature with no dependents, so it's the cleanest one to demote.

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

- **If two different people install my app, should they see the same data?** **No.** Furlo is a single-device, single-user local tracker for MVP — no login gate by default. Two installs are two independent pet lists.
  
- **Roughly how many records in a realistic week of use:** For a 2-pet household — 2 pet rows, ~14 feeding entries (mostly status flips, not new rows), 0–1 new vaccination rows, 1–2 health record rows, 0–1 new vet contacts, 1–2 weight entries. Call it **15–20 new/updated rows a week**, growing to a few hundred rows over a semester — trivial for a local relational store.
  
- **My choice:** `sqflite` (local SQLite database).
  
- **Why this one and not the others:** The data is inherently relational — a vet can be linked to multiple pets and vice versa (many-to-many join table), and feeding/vaccination/health/weight records all foreign-key against a pet. `shared_preferences` only stores flat key-value pairs, so it can't represent that join table without hand-rolled serialization. Firebase/Supabase solve problems I don't have (multi-device sync, multi-user accounts) at the cost of setup, network dependency, and a secrets story to manage in a public repo. Tradeoff accepted: no cross-device sync or cloud backup unless export is built separately — acceptable for a single person tracking their own pets on their own phone.
  
- **What I save, concretely:**
  - `pets` — id, name, species, breed, birthdate, photo_path
  - `feedings` — id, pet_id (FK), time, frequency, last_fed_at, done_today
  - `vaccinations` — id, pet_id (FK), vaccine_name, date_given, next_due_date, status
  - `health_records` — id, pet_id (FK), title, date, type, notes, reminder_frequency (nullable), reminder_active (nullable)
  - `vets` — id, name, clinic, phone, email, address, notes
  - `vet_pets` join table — vet_id (FK), pet_id (FK), next_appointment_date (nullable)
  - `weight_logs` — id, pet_id (FK), date, weight, notes (nullable)
  - `notification_settings` (or `shared_preferences`) — one toggle per type: daily_feeding, missed_meal, upcoming_vaccine, overdue_vaccine, vet_appointment, medication
    
- **Have I tried it yet?** Not yet — spiking `sqflite` init plus the `kIsWeb` repository swap is first up, targeted for **Aug 30**, so any platform gap is caught early.
  
- **Platform caveat:** `sqflite` does **not** run in a Codespace/web build — native-only, throws `MissingPluginException` in a browser. Since the graded copy runs via `flutter run -d web-server`, storage can't be a single hard-coded `sqflite` call. Two options:
  1. **Repository pattern:** one `PetRepository` interface, backed by `sqflite` on mobile and an in-memory/`shared_preferences` implementation on web, switched via `kIsWeb`.
  2. **Swap to Drift:** same relational model, but runs on web via `sql.js` — more setup now, no platform gap later.
  **Decision: Route 1.** Drift's web setup (`sql.js`, WASM wiring) is overhead for a build whose only job is to demo and get graded, not persist real data long-term. The repository interface is smaller work and doubles as what makes the vet–pet join queries testable in isolation (see risks).

## NEW: One thing I want to add that the course did not teach

Four candidates came out of reviewing the wireframes: export, a vet document/receipt scanner, a vet clinic map, and a Gemini-powered "ask about my pet" chat. I'm committing to export — it's the only one that runs identically on phone and web with no `kIsWeb` fallback needed, and I already have two of those (storage, notifications) to build.

- **Package:** `pdf` to generate the file, paired with `share_plus` to hand it off (share sheet on phone, download on web).
- **Runs where you develop?** Yes — both are pure Dart, no native plugin dependency. No `kIsWeb` branch needed.
- **If it does not run on web:** N/A — it does.
- **Core feature or stretch goal?** Stretch. The app is fully usable without it, and nothing depends on it.

The other three stay on the stretch list, each anchored to an existing wireframe: the receipt scanner extends Health Records' "Add Record" via `image_picker` (same file-picker fallback already used for pet photos); the vet map attaches to the address field on the Vet Details screen, most simply via `url_launcher` opening the phone's native maps app (avoids a second API key); the chat feature is the most open-ended — no wireframe represents it yet, so it needs new screens before it needs a package decision.

## NEW: How my project runs when someone else opens it

- **Keeping the `device_preview` wrapper:** Yes — it's how the grader sees phone-sized screens in a browser. It doesn't simulate hardware (camera, GPS, native storage), which the two items below cover.
  
- **Runs in a browser with `flutter run -d web-server`, every screen reachable:** Not yet — three pieces are native-only and need a web fallback:
  - `sqflite` (all data screens) — repository-swap fix noted above.
  - `image_picker`'s camera capture — file-picker path still works on web; camera on phone, file-picker/sample image on web.
  - `flutter_local_notifications` — native-only; the Notifications *settings* screen still renders and is clickable on web, it just won't fire a reminder. Fine for grading — real behavior shown in the phone recording.
    
- **Anything needing real hardware degrades to sample data instead of crashing:** Yes, per the fallbacks above. All three `kIsWeb` branches are scoped into the same setup pass as the storage spike, by **Aug 30**.
  
- **Public repo, own GitHub account — anything needing a key, password, or real personal data?** Furlo's MVP as scoped (local `sqflite`, no auth, no cloud) needs no API keys or secrets to run. Repo: github.com/TachiBae/furlo. Auth is staying as designed-but-unbuilt wireframes, not wired to a real backend, so no `.env`/repo-secrets setup is needed now. If that changes, the plan is a git-ignored `.env` locally plus the same key as a GitHub repository secret for any deploy step.

## Data the app remembers

| Thing | Fields | Where it is saved |
|---|---|---|
| Pet | name, species, breed, birthdate, photo_path | `sqflite` — `pets` |
| Feeding entry | pet_id, time/frequency, last_fed_at, done_today | `sqflite` — `feedings` |
| Vaccination | pet_id, vaccine_name, date_given, next_due_date, status | `sqflite` — `vaccinations` |
| Health record | pet_id, title, date, type, notes, reminder_frequency, reminder_active | `sqflite` — `health_records` |
| Vet contact | name, clinic, phone, email, address, notes | `sqflite` — `vets` |
| Vet–pet association | vet_id, pet_id, next_appointment_date | `sqflite` — `vet_pets` (join table) |
| Weight log | pet_id, date, weight, notes | `sqflite` — `weight_logs` |
| Notification settings | per-type toggle (6 types) | `sqflite` or `shared_preferences` |
| Profile/account | display name | `shared_preferences` or `sqflite` |

## Screens

1. Splash / Sign In / Create Account *(stretch)*
2. Pet onboarding — Add New Pet
3. Pet list / Home
4. Pet profile
5. Feeding schedule
6. Vaccinations
7. Health records
8. Vet contacts
9. Add Vet / Vet details
10. Weight tracking
11. Add Meal / Add Vaccination / Add Health Record / Add Weight Entry (one add-form per feature)
12. Profile / Settings
13. Notifications (settings)
14. Forgot Password / Verify Identity / Create New Password *(stretch, part of Auth)*

*14 screens total: the 9 core features expand into more screens where a feature needs a separate list, detail, and add-form view (e.g. Vet Contacts → list, Add Vet, Vet Details); 3 screens (1, 14, and the Create Account step) belong to the stretch-goal auth flow only.*

## Risks, revised

- **Risk from last time — notifications firing while the app is closed:** Still real, and slightly bigger now that `flutter_local_notifications` is confirmed native-only alongside `sqflite`. The fix is the same `kIsWeb` fallback pattern already planned for storage, so it's not a new problem to solve. **First step: get one notification firing on a physical/emulated Android device by Sept 13**, after the storage and vet-pet risks below are settled.
  
- **New risk:** `sqflite` doesn't run in a Codespace/web build at all. Storage can't be scattered `sqflite` calls — it needs the repository interface from day one, or retrofitting it later is expensive. **First step: write the `PetRepository` interface and both implementations before building the first data screen, by Aug 30.**
  
- **Second new risk:** the `vet_pets` many-to-many relationship is more complex than anything in m4a4/m5a5, which was mostly single-table CRUD. **First step: build the `vet_pets` schema and one join query in isolation (console output, no UI) by Sept 6**, before wiring it into the Vet Contacts screen.

## What changed, and why

| Section | Prelim said | Now says | Why it changed |
|---|---|---|---|
| Data model | Vet contact/association described in prose | Vet–pet relationship made explicit as its own `vet_pets` join table | Wireframe review (Vet Details screen, associated-pets chips) showed the relationship is genuinely many-to-many in the UI, not just describable in a sentence — needed as a real join table to support filtering vets by pet |
| Storage | Not specified | `sqflite`, defended against `shared_preferences`/Firebase/Supabase | New requirement in this worksheet |
| Core features | 9 features, no hour estimates | Same 9 features, all kept, with widgets + hours named (~38–40 hours) | Re-scored against real Flutter build pace from m4a4/m5a5; |
| Auth | Designed in wireframes, status unclear | Confirmed staying as wireframes only | Scoping decision made explicit once the "public repo secrets" question forced a real answer, rather than leaving it ambiguous |
