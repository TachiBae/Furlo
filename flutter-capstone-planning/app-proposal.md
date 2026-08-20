# App Proposal

## App name
Furlo: Pet Health & Care Tracker *(working title)*

## The problem, in one sentence
Pet owners juggle feeding, vaccination, health, weight, and vet information from memory or scattered notes, making it easy to miss important care tasks or lose track of a pet's records.

## Who is this for
- Pet owners managing 1–3 pets at home — for example, an individual tracking their own pet(s), or a small household where multiple people feed/care for the same pet and no one's sure who did it last.
- Currently: memory, a physical notebook, or vet appointment stickers/calendars — nothing centralized, so schedules and records can live in different places or different people's heads.

## Core features (MVP)

| # | Feature | What the user does | What happens |
|---|---|---|---|
| 1 | Pet onboarding | User adds a pet and enters basic information such as name, species/breed, birthdate, and photo | App creates the pet profile and adds it to the user's pet list/home screen |
| 2 | Pet profile and pet list/home | User views their pets and selects an individual pet | App shows each pet's key information and provides access to its care records and features |
| 3 | Feeding | User sets feeding times/frequency for a pet and marks each feeding as done | App shows today's feeding status and tracks completed feedings |
| 4 | Vaccinations | User logs a vaccine with the date given and next-due date | App displays vaccination information and identifies upcoming or overdue vaccinations |
| 5 | Health records | User logs a health event such as a vet visit, medication, or symptom, with a title, date, and notes; for medication entries, user can optionally set a reminder schedule (frequency and active/inactive) | App stores the information in a chronological health record for the selected pet, and surfaces active medication entries to the notification system |
| 6 | Vet contacts | User adds a vet's information (name, clinic, phone number) and assigns it to one or more of their pets, optionally with a next appointment date per pet; user can view vets filtered by pet, and edit a vet's assigned pets or appointment date later | App keeps veterinary contact information organized per pet, so a household with different vets per pet (or a shared vet across pets) is represented accurately, and surfaces upcoming appointments to the notification system |
| 7 | Weight tracking | User records a pet's weight over time | App stores dated weight entries so the user can review changes in the pet's weight |
| 8 | Profile/account | User views and manages their account/profile information | App provides a dedicated area for account-related information and settings |
| 9 | Notifications | User enables/disables reminder types (feeding, vaccinations, vet appointments, medications) | App delivers reminders for daily feedings, missed meals, upcoming/overdue vaccinations, vet appointments, and medications |

## Stretch goals
1. Authentication — account creation, login, and forgot-password flows. *For MVP, the app opens directly into onboarding/home with no login gate; if authentication is added, it should sit in front of onboarding as an optional entry point rather than a hard requirement.*

## Data the app needs to remember
- **Pet** — name, species, breed, birthdate, photo
- **Feeding entry** — pet_id, time/frequency, last fed timestamp, done today (bool)
- **Vaccination** — pet_id, vaccine name, date given, next due date, status (upcoming/overdue/done)
- **Health record** — pet_id, title, date, type (vet visit/medication/symptom), notes, reminder_frequency (medication entries only), reminder_active (bool, medication entries only)
- **Vet contact** — vet_id, name, clinic, phone, email, address, notes *(vet-level record, not tied to a single pet)*
- **Vet-pet association** — vet_id, pet_id, next_appointment_date (optional) *(join table; a vet can be linked to multiple pets, and a pet can have multiple vets, e.g. primary + specialist)*
- **Weight log** — pet_id, date, weight value, notes (optional)
- **Profile/account** — account/profile information and settings needed by the app
- **Notification settings** — per-type toggle state (daily feeding, missed meal, upcoming vaccine, overdue vaccine, vet appointment, medication)

## Screens I will need
1. Pet onboarding — introduce the user to the pet setup process and collect the pet's basic information
2. Pet list/home — all pets and key care information at a glance, with quick-action shortcuts to all MVP features (feeding, vaccinations, health records, vet contacts, weight)
3. Pet profile — single pet's details and access to its care features
4. Feeding — feeding schedule and daily feeding status per pet
5. Vaccination log — view and add vaccination records
6. Health records — view and add health records per pet
7. Vet contacts — view (filterable by pet) and add veterinary contact information; add/edit screen includes assigning the vet to one or more pets, and a vet's associated pets can be changed later from its detail view
8. Weight tracking — view and add weight entries over time
9. Profile/account — account and profile-related information/settings
10. Notifications — reminder settings for feeding, vaccination, vet appointment, and medication alerts
11. Authentication *(stretch)* — login, create account, and forgot-password screens


## One risk
Notifications are the main MVP implementation risk. Reminders need to fire even when the app is closed, which means relying on the phone's operating system notification and scheduling APIs. Recurring reminders such as daily feeding times, future vaccination dates, vet appointments, and medication schedules may require additional platform-specific setup beyond the core screens and local data storage.

## Implementation notes
- **Confirmation before destructive actions** — deleting a vet contact and clearing app data must show a confirmation step (e.g. "Are you sure?") before executing, since both are irreversible.
- **Empty states** — since every pet and feature list starts empty after onboarding, Home/Pet list, Feeding, Vaccinations, Health records, Vet contacts, and Weight tracking each need a defined empty state (e.g. "No pets yet — add your first pet" / "No meals logged today") rather than a blank screen.
