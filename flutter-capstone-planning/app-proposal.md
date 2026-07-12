# App Proposal

## App name
Pet Care Tracker *(working title)*

## The problem, in one sentence
Pet owners juggle feeding, deworming, and vaccination schedules from memory or scattered vet stickers/notebooks, and it's easy to lose track of the exact date a shot is due until the vet calls to remind you — or doesn't.

## Who is this for
- Pet owners managing 1–3 pets at home — for example, an individual tracking their own pet(s), or a small household where multiple people feed/care for the same pet and no one's sure who did it last.
- Currently: memory, a physical notebook, or vet appointment stickers/calendars — nothing centralized, so schedules live in different people's heads.

## Core features (MVP)

| # | Feature | What the user does | What happens |
|---|---|---|---|
| 1 | Pet profiles | User adds a pet with name, species/breed, birthdate, photo | App stores the profile and shows it on a pet list/home screen |
| 2 | Feeding schedule | User sets feeding times/frequency for a pet and marks each feeding as done | App shows today's feeding status and resets/tracks it daily |
| 3 | Vaccination reminders | User logs a vaccine with date given and next-due date | App flags upcoming/overdue vaccinations on the home screen |
| 4 | Health records | User logs a health event (vet visit, medication, symptom) with date and notes | App stores it in a chronological log per pet |

## Stretch goals
1. Vet contact list (name, clinic, phone, linked per pet)
2. Weight tracking (log weight over time, simple chart)
3. Grooming schedule/reminders
4. Pet food/treat safety guide — browse a reference list of safe and unsafe foods per species (static bundled data, no user input needed, so it's low-risk to add later without touching core screens/features)

## Data the app needs to remember
- **Pet** — name, species, breed, birthdate, photo
- **Feeding entry** — pet_id, time/frequency, last fed timestamp, done today (bool)
- **Vaccination** — pet_id, vaccine name, date given, next due date, status (upcoming/overdue/done)
- **Health record** — pet_id, date, type (vet visit/medication/symptom), notes
- *(stretch)* **Vet contact** — pet_id (or owner-level), name, clinic, phone
- *(stretch)* **Weight log** — pet_id, date, weight value
- *(stretch)* **Food Reference** — name, species (dog/cat/etc.), safety status (safe/toxic/moderation), notes

## Screens you'll need
1. Pet list (home) — all pets + upcoming reminders at a glance
2. Pet profile — single pet's details
3. Add/Edit pet
4. Feeding schedule (per pet)
5. Vaccination log (per pet, add/view)
6. Health records log (per pet)

## One risk
Reminder notifications — actually getting the app to notify at the right local time (especially recurring ones like "feed daily at 6pm" or "vaccine due in 3 days") is the part most likely to eat time, since it depends on the platform's notification/scheduling APIs rather than just UI and local storage.

 - Explanation: Reminders need to fire even when the app is closed, which means relying on the phone's OS (Android/iOS) to schedule and trigger them,  not just something we control fully in our own code. Getting that to work reliably (especially recurring reminders like "every day at 6pm") takes extra setup beyond the usual screens and database work, so it's the part most likely to take longer than expected.


