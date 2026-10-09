# GitHub Pages Deployment — Task List

Plan: `DEPLOY_PLAN.md` · **Approved this session — trigger branch: `fix/ui-audit`.**

- [x] T0 — Approval: plan + **branch choice** (user chose `fix/ui-audit`)
- [x] T1 — Local dry build: `flutter build web --release --base-href "/Furlo/"` from
      `furlo/`; exit 0 (44.6s); `build/web/main.dart.js` present; `index.html` carries
      `href="/Furlo/"` and loads via `flutter_bootstrap.js`
- [x] T2 — Create `.github/workflows/deploy-pages.yml` (repo root; flutter 3.44.6;
      working-directory `furlo`; artifact `furlo/build/web`; `actions/deploy-pages@v4`)
- [x] T3 — Commit workflow + docs; push the chosen branch (approved)
- [ ] T4 — User: enable Pages (Settings → Pages → Source: GitHub Actions) and add
      `tachibae.github.io` to Firebase authorized domains; then verify live:
      `https://tachibae.github.io/Furlo/` loads, `main.dart.js` 200, sign-in works

## Branch choice (part of T0)

| Option | Effect |
|---|---|
| **A — trigger on `fix/ui-audit` (recommended)** | Deploys the current best build (audit pass + Phase 1) with zero merge; switch the trigger to `main` later when you merge |
| B — merge `fix/ui-audit` → `main` first, then trigger on `main` | One clean history; needs your OK for the merge + push of `main` |

## Verification record

| Check | Result |
|---|---|
| T1 local build exit code + artifacts | **PASS** — exit 0, 44.6s, `main.dart.js` + `/Furlo/` base-href verified in `build/web` (45 MB) |
| T2 workflow file committed (hash) | `77cd5e9` |
| T3 push result | **PASS** — `e85aea1..77cd5e9` pushed to `origin/fix/ui-audit`, exit 0 |
| CI run (first push) | **build: SUCCESS** · **deploy: FAILED** at `actions/deploy-pages@v4` — expected: Pages source not yet set to "GitHub Actions". Run: https://github.com/TachiBae/Furlo/actions/runs/37969172928 |
| T4 live URL + sign-in | **blocked on user toggles** — enable Pages (Settings → Pages → Source: GitHub Actions), then re-run failed jobs (artifact from the successful build is reused); add `tachibae.github.io` to Firebase authorized domains for sign-in |
