# GitHub Pages Deployment — Implementation Plan

Goal: serve the Furlo Flutter web build free at `https://tachibae.github.io/Furlo/`,
auto-deployed by GitHub Actions on every push. Repo: `github.com/TachiBae/Furlo`.

## Facts verified this session

- Flutter project lives in `furlo/` (subdirectory of the repo root).
- App uses Flutter's default **hash routing** (no `usePathUrlStrategy` anywhere) → no
  SPA/404 rewrite needed on Pages.
- Firebase (`firebase_core`/`firebase_auth`/`cloud_firestore` in `pubspec.yaml`) → the
  hosted domain must be added to Firebase Auth's authorized domains or sign-in fails
  with `auth/unauthorized-domain`.
- Local toolchain: Flutter **3.44.6** stable (pin this in CI for reproducible builds).
- Remote default branch `main` is at `a6275aa` — behind `fix/ui-audit` (which holds the
  20-item audit pass + Phase 1 + docs, all pushed). A `main`-triggered workflow would
  deploy the pre-audit build. **Branch choice is a user decision** (see Task List T0).
- No `.github/` workflows exist yet — net-new.

## Work items (agent)

1. **T1 — Local dry build (validation before committing CI).**
   `cd furlo && flutter build web --release --base-href "/Furlo/"`, exit code captured;
   assert `build/web/main.dart.js` + `index.html` exist and `index.html` references
   `/Furlo/`. This proves the exact CI command before it lands in the workflow.
2. **T2 — Create `.github/workflows/deploy-pages.yml`** at the repo root:
   - Triggers: `push` to the chosen branch + `workflow_dispatch`.
   - Job `build`: checkout → `subosito/flutter-action@v2` with `flutter-version: 3.44.6`,
     `channel: stable`, cache → `flutter pub get` + `flutter build web --release
     --base-href "/Furlo/"` (both `working-directory: furlo`) →
     `actions/upload-pages-artifact@v3` with `path: furlo/build/web`.
   - Job `deploy`: `actions/deploy-pages@v4` with the standard `pages: write` +
     `id-token: write` permissions and `concurrency: pages`.
   - `--base-href "/Furlo/"` is mandatory: project pages serve under `/Furlo/`; without
     it every asset 404s.
3. **T3 — Commit** (one commit, workflow + these docs) **and push** the chosen branch —
   push is authorized only after explicit approval.

## User-side steps (cannot be automated — console toggles only you can flip)

- Repo **Settings → Pages → Build and deployment → Source: GitHub Actions**.
- Firebase console → project → **Authentication → Settings → Authorized domains →
  Add `tachibae.github.io`** (plus a `https://tachibae.github.io/*` referrer entry in
  the Google Cloud API key restrictions, if those are set).
- Then either wait for the push-triggered run or hit **Actions → Deploy to GitHub
  Pages → Run workflow**.

## Verification protocol

- T1 local build green (exit codes captured) before the workflow is committed.
- After push: poll `https://tachibae.github.io/Furlo/` until HTTP 200; confirm
  `main.dart.js` loads (content-type + non-empty) and the app paints; sign-in works
  only after the Firebase domain step — reported explicitly either way.
- Honest reporting: "workflow committed" ≠ "site live"; the live check needs the Pages
  toggle, which only the user can set.

## Constraints honored

No app-code changes · no new dependencies · no migrations · no unrelated refactors ·
token/theme rules untouched · destructive-free · plan approved before any file edit.
