# 3. Design System — Pet Care Tracker

**Time: 45 minutes.** A design system is a short, fixed set of decisions -
colors, type, spacing, and reusable pieces - that you make **once** so every
screen looks like it belongs to the same app. Without one, every screen you
build ends up with slightly different blues, paddings, and button shapes.

Use your [wireframes](02-wireframes.md) as the source: only define a
component if a screen actually needs it.

---

## Step A: Color palette (10 min)

Pick **3-5 colors**, no more. Flutter apps built with Material widgets need
at minimum:

| Role | Your color (name or hex) | Used for |
| --- | --- | --- |
| Primary | Wondrous Wisteria — `#A5B2EB` | App bar, section labels, active nav state, primary icons |
| Secondary / accent | Succulent Lime — `#DDDE68` | Primary buttons, "done/on-track" status dots, feeding reminders |
| Background | Black Rock — `#1C1D27` | Screen background (outer canvas behind cards) |
| Surface | Blue Suede Shoes — `#494C65` | Cards, sheets, dialogs, list item rows (pet cards, vaccination rows) |
| Error | Persian Orange — `#DA935D` | Overdue vaccinations, destructive actions, validation errors |
| Text (on background) | `#F4F1EA` | Body text and headings on dark background/surface |

**Supporting note:** `#2B2D3B` (Daemonette Hide-adjacent) sits between
Background and Surface — use it for the phone-frame/screen container
wrapping the surface cards, so there's a subtle depth step:
`#1C1D27` (background) → `#2B2D3B` (screen container) → `#494C65` (card).

Secondary text / muted labels (timestamps, breed names, hints) use
`#9C9FB5`, a lightened tint of the Surface color — not a new palette color,
just a lighter mix of Surface so it still reads on dark.

---

## Step B: Type scale (10 min)

You don't need custom fonts. Decide **3 text sizes** and when each is used -
that's enough for a semester project.

| Style | Size (sp) | Weight | Used for |
| --- | --- | --- | --- |
| Heading | 20sp | Bold | Screen titles ("Hi, Jorel", "Pet Details", "Vaccination") |
| Body | 14sp | Regular | Pet names, list item titles, form labels, button text |
| Caption | 11–12sp | Regular/light | Breed/species tags, timestamps, "due 6pm" / "overdue" pill text |

---

## Step C: Spacing rule (5 min)

Pick **one base unit** (commonly 8px) and use multiples of it everywhere -
padding, gaps between elements, margins. Write your scale:

- Tight spacing (between related items): **8 px** — e.g. gap between pet
  cards in a row, gap between a card's title and subtitle
- Standard spacing (between sections): **16–18 px** — e.g. gap between the
  "Today's reminders" block and the "My pets" section
- Screen edge padding: **20 px** — consistent margin on all screens between
  the screen edge and content

Card corner radius: **14 px** (12 px minimum), used on every card/pill so
rounding reads as one consistent shape language across the app.

---

## Step D: Reusable components (20 min)

Look back through your wireframes (step 2). List every UI piece that shows
up on **more than one screen** - these are your components. Don't invent
ones you don't need.

For each, describe it once (so every screen uses the same version):

| Component | Appears on screens | Looks like | Contains |
| --- | --- | --- | --- |
| Pet avatar card | Home, Pet Details, Add/Edit Pet | Surface (`#494C65`) rounded rect, 14px radius, centered circular avatar (44px, Primary or Error color fill) | avatar circle, pet name (Body), breed/species (Caption) |
| Reminder pill / status card | Home, Feeding Schedule, Vaccination log | Filled rounded rect (14px radius) — Accent lime for on-time/upcoming, Error orange for overdue/due-today | label (Caption), time or status text (Body), colored fill doubles as the status signal |
| List item row | Vaccination log, Feeding Schedule, Health Records | Surface (`#494C65`) rounded rect, 14px radius, flex row: text block left, small 8px status dot right | title (Body), subtitle with pet name + date (Caption), status dot (Accent lime = ok, Error orange = overdue) |
| Section label | Home, Pet Details, all log screens | Plain text, no background, sits above a group of cards | Primary color (`#A5B2EB`), Body weight, small bottom margin (10px) |
| Primary button | Sign up/in, Add/Edit Pet, "Add Vaccination" / "Add Feeding Time" / "Add Record" | Filled rect, Accent lime or Primary wisteria fill, 14px radius, centered Body text in dark text color | button label only |
| Empty state / add card | My pets row (Add pet), any empty list | Dashed border (Primary or Surface tone), transparent fill, centered "+" icon + Caption label | "+" icon, short label ("Add pet") |

---

## What to keep

This page - filled in - is your design reference for the whole semester.
When Flutter starts:
- Your **palette** becomes a `ColorScheme` inside your app's `ThemeData`
  (`primary: #A5B2EB`, `secondary: #DDDE68`, `background: #1C1D27`,
  `surface: #494C65`, `error: #DA935D`, `onBackground/onSurface: #F4F1EA`).
- Your **type scale** becomes a `TextTheme`
  (`headlineSmall: 20sp bold`, `bodyMedium: 14sp regular`,
  `labelSmall/caption: 11–12sp regular`).
- Your **spacing rule** becomes constants you reuse in `EdgeInsets`/`SizedBox`
  (`kSpacingTight = 8.0`, `kSpacingStandard = 16.0`, `kScreenPadding = 20.0`,
  `kCardRadius = 14.0`).
- Each **reusable component** becomes one widget file in a `widgets/` folder,
  built once and used everywhere it appears on your wireframes
  (`pet_avatar_card.dart`, `status_pill.dart`, `log_list_item.dart`,
  `section_label.dart`, `primary_button.dart`, `empty_state_card.dart`).

Keep this file (or a photo of it) - it's the reference you'll open every time
you build a new screen, so every part of your app stays consistent without
you having to re-decide it each time.
