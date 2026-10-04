# AI-USAGE.md

## Tools and how I worked

- **Claude (Anthropic, claude.ai chat):** planning the fixes, writing scoped prompts, explaining errors, and git help.
- **A coding agent in Freebuff** with these models: [list only the models you actually selected]. It read the repo, edited files, and ran `flutter analyze` and `flutter test`.
- **My process:** I gave the agent one task at a time, with the files it may change and when to stop and ask. I then ran `flutter analyze` and `flutter test` myself, looked at the app in Chrome, and committed after each step.
- **My honest estimate:** about [X]% of the Flutter code was written by AI and about [Y]% by me. Section 3 shows which part.

Replace every `<hash>` below with a real commit from `git log --oneline`, using the link form
`https://github.com/TachiBae/furlo/commit/<hash>` (confirm this is your repo's address).

---

## 1. How I used AI

**1. Auditing the project for gaps**

- _Asked:_ an inventory of what was built and what was missing, with no code changes.
- _Got:_ a file list and a gap list.
- _Kept / rejected:_ I kept the inventory. I rejected the claim that a health-record form file was missing (see Section 2, case 1).
- _Commit:_ [`<hash>`](link), the first fix that came out of the audit.

**2. Turning the audit into small, scoped prompts**

- _Asked:_ Claude to convert each finding into a prompt with a scope lock, a "must not" list, and a stop-and-ask rule.
- _Got:_ ordered prompts, one task each.
- _Kept / changed:_ I ran them one at a time and added my own checks between them.
- _Commit:_ [`<hash>`](link), the commit where I saved the prompts in the repo (for example `docs/ai-prompts.md`). Remove this entry if you don't save them.

**3. Fixing three failing tests**

- _Asked:_ the agent to fix a filename that lost its spaces, a pet name that wasn't capitalized, and a web delete that left a vaccination behind. It was not allowed to edit the tests.
- _Got:_ whitespace now becomes a hyphen in the filename, the name is capitalized before saving, and the web repository deletes the same child records as the SQLite one.
- _Kept / changed:_ [what you changed or rejected].
- _Commit:_ [`<hash>`](link)

**4. Fixing the onboarding screen overflow**

- _Asked:_ the agent to make the screen scroll without changing how it looks.
- _Got:_ the content wrapped in a scroll view that keeps it centered on tall screens.
- _Kept / changed:_ [what you changed].
- _Commit:_ [`<hash>`](link)

**5. Fixing the "My Pets" tab and the Notifications tile**

- _Asked:_ the agent to make the fourth tab open the pet list and the tile open the settings screen with the toggles.
- _Got:_ two small navigation changes.
- _Kept / changed:_ [what you changed].
- _Commit:_ [`<hash>`](link)

**6. Redesigning the species and breed menus**

- _Asked:_ rounded menus, icons, and a check mark on the selected item.
- _Got:_ the restyle, plus a new icon package for the cat and dog icons.
- _Kept / changed:_ I rejected the first cat icon (Section 2, case 2) and the first breed sheet size (case 3).
- _Commit:_ [`<hash>`](link)

**7. PDF export: save, share, and download**

- _Asked:_ a way to save the care-summary PDF as a file, not only share it.
- _Got:_ a Save PDF option for phones and a separate browser download for web.
- _Kept / changed:_ I replaced the first web approach (Section 2, case 4).
- _Commit:_ [`<hash>`](link)

**8. Quality check with temporary tests**

- _Asked:_ the agent to build the web app, click through every flow with temporary widget tests, and report problems without fixing them.
- _Got:_ a report with 84 passing tests, a vet-list crash, and overflows on short windows.
- _Kept / changed:_ I kept [the tests you kept] and ignored [the findings you decided to skip, and why].
- _Commit:_ [`<hash>`](link), the commit that added the tests I kept.

**9. Writing the project report**

- _Asked:_ a completion report that only states what the code and the commands prove.
- _Got:_ `docs/PROJECT_REPORT.md`, with a blank manual testing log.
- _Kept / changed:_ I [filled in / corrected] [what you did].
- _Commit:_ [`d602cab`](https://github.com/TachiBae/furlo/commit/d602cab)

---

## 2. Where the AI got it wrong

(Three cases are required. Four are listed, so pick the three with the best evidence, or keep all four.)

**Case 1: The audit that contradicted itself**

- _What the AI said:_ the health-record form file was missing, even though the same report listed it among the screens present.
- _Why it was wrong:_ `flutter analyze` reported no issues. If the form class were missing, it would have reported an undefined class.
- _How I caught it:_ I ran `flutter analyze` and searched the code instead of trusting the report.
- _What I did:_ I did not create a duplicate file. I confirmed the form class already existed and supported add and edit.
- _Commit:_ [`<hash>`](link). Because no code changed here, link the commit that records this decision, and consider swapping in a case that changed code.

**Case 2: A cat emoji instead of an icon**

- _What the AI did:_ Flutter's built-in icons have no cat, so the agent used a cat emoji. The label also sat about 10 pixels to the right of the Dog label.
- _Why it was wrong:_ I wanted an icon, not an emoji or picture, and the rows no longer lined up.
- _How I caught it:_ I opened the menu and compared it to the design.
- _What I did:_ I had the agent use a cat icon from an icon-font package and give both icons the same fixed-width slot.
- _Commit:_ [`<hash>`](link)

**Case 3: A menu height that broke a test**

- _What the AI did:_ it capped the breed list at about 300 pixels, and the test looking for "Labrador Retriever" stopped finding it.
- _Why it was wrong:_ the list only builds rows that fit on screen, so the test's target was no longer built.
- _How I caught it:_ `flutter test` failed at the test's line 175, and the agent stopped and reported it instead of editing the test.
- _What I did:_ [describe how you fixed it, for example a taller sheet or a scroll step in the test].
- _Commit:_ [`<hash>`](link)

**Case 4: Saving the PDF on web**

- _What the AI did:_ the new Save PDF button failed on web with a generic "Could not save PDF" message and logged nothing. Then AI advice (from Claude) to reuse the Share path on web was wrong too. In Chrome on a Mac, Share opens the system share sheet (AirDrop, Notes, Messages, Copy) with no way to save a file.
- _Why it was wrong:_ a hidden error and a wrong assumption about what Share does on web.
- _How I caught it:_ I tested it in the browser, read the console, and looked at what Share actually showed.
- _What I did:_ I had the agent add a direct browser download for web and log the real error in the catch block.
- _Commit:_ [`<hash>`](link)

---

## 3. Who wrote what

**How I measured it** (from the repo's top folder):

    git ls-files -- 'furlo/lib/*.dart' | xargs wc -l | tail -1

That gives the total lines of app code. Below I list the files I wrote by hand and their line counts, which should add up to at least a fifth of that total.

| File                               | Lines | Mostly written by | My commit        |
| ---------------------------------- | ----- | ----------------- | ---------------- |
| [path, e.g. `furlo/lib/utils/...`] | [n]   | me                | [`<hash>`](link) |
| [path]                             | [n]   | me                | [`<hash>`](link) |
| [path]                             | [n]   | me                | [`<hash>`](link) |

**Explained in my own words**

_[File or function name]_

- _What it does:_ [two or three sentences, from memory, without looking at the code]
- _How it works:_ [the main idea, for example how it decides a result or what it checks in what order]
- _A choice I made and why:_ [one decision that's mine]
- _If I changed it:_ [what would break, and what you would check]

_(Repeat for each part. Pick parts you could explain out loud if someone asked.)_

---

## README credit (add this to README.md)

> **AI credit:** This project used AI assistance. Claude (Anthropic) helped with planning, prompt writing, and debugging advice, and a coding agent called **"Freebuff"** helped write and test code. I drove the work, ran every check myself, and caught several mistakes, which are documented in `AI-USAGE.md` along with the parts I wrote myself.
