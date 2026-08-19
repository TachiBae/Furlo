# App Proposal

## App name
Pet Care Tracker *(working title)*

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
| 5 | Health records | User logs a health event such as a vet visit, medication, or symptom, with a date and notes | App stores the information in a chronological health record for the selected pet |
| 6 | Vet contacts | User adds and views vet contact information, including name, clinic, and phone number | App keeps the pet's veterinary contact information organized and accessible |
| 7 | Weight tracking | User records a pet's weight over time | App stores dated weight entries so the user can review changes in the pet's weight |
| 8 | Profile/account | User views and manages their account/profile information | App provides a dedicated area for account-related information and settings |

## Stretch goals
1. Authentication — account creation, login, and forgot-password flows
2. Notifications — reminders for recurring feeding schedules and upcoming or overdue vaccinations

## Data the app needs to remember
- **Pet** — name, species, breed, birthdate, photo
- **Feeding entry** — pet_id, time/frequency, last fed timestamp, done today (bool)
- **Vaccination** — pet_id, vaccine name, date given, next due date, status (upcoming/overdue/done)
- **Health record** — pet_id, date, type (vet visit/medication/symptom), notes
- **Vet contact** — pet_id (or owner-level), name, clinic, phone
- **Weight log** — pet_id, date, weight value
- **Profile/account** — account/profile information and settings needed by the app

## Screens I will need
1. Pet onboarding — introduce the user to the pet setup process and collect the pet's basic information
2. Pet list/home — all pets and key care information at a glance
3. Pet profile — single pet's details and access to its care features
4. Feeding — feeding schedule and daily feeding status per pet
5. Vaccination log — view and add vaccination records
6. Health records — view and add health records per pet
7. Vet contacts — view and add veterinary contact information
8. Weight tracking — view and add weight entries over time
9. Profile/account — account and profile-related information/settings
10. Authentication *(stretch)* — login, create account, and forgot-password screens
11. Notifications *(stretch)* — reminder settings/status for feeding and vaccination reminders


## One risk
Notifications are the main stretch-goal implementation risk. Reminders need to fire even when the app is closed, which means relying on the phone's operating system notification and scheduling APIs. Recurring reminders such as daily feeding times and future vaccination dates may require additional platform-specific setup beyond the core screens and local data storage.
