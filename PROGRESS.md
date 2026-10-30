# Family Finances Tracker — Project Context

Read this first if you're picking up work on this app in a new session.

## What this is

A whitelabel copy of a private family budget and net-worth tracker. One household views and edits it from
their phones, and it stays in sync through an encrypted file in its GitHub repo.

- **Live app**: `https://<owner>.github.io/<repo>/`
- **Settings for this copy**: `js/config.js` (app name, public reminder key; owner/repo only if not on GitHub Pages)
- **Setup**: `setup/setup.sh` (Mac) or `setup/setup.ps1` (Windows) creates the repo, Pages and secrets.

## Data model (v2 schema)

| Field | What it holds |
|---|---|
| `accounts[]` | `{id, name, bucket: savings/current/asset, tags[], estimate?, archived}` |
| `snapshots[]` | One per month: `{month, date, balances:{accountId: £}, updated:{accountId: date}}`. Imported older months may hold `totals {savings, current}` instead of per-account balances. |
| `tags[]` | User-editable groups of accounts (many-to-many) |
| `budget` | `years[]`, `groups[]`, `lines[]` with `amounts[year]`, `kind` and `payMonths {year: [1–12]}`; `salaries` (reference only) |
| `planHistory` | Optional imported month-by-month plan for past months. Empty unless imported. |
| `coverage`, `scenarios`, `events`, `upcoming`, `house`, `notes` | Months-of-cover adjustments, what-ifs, one-offs, known future items, house project |
| `checklist[month]` | Monthly check-in ticks |
| `push.subs` | Devices with phone reminders on (encrypted like everything else) |

## Whitelabel changes (v1, 2026-10-30)

- Owner and repo come from the GitHub Pages address, so a copy runs on any account without code edits.
- Browser storage keys are prefixed with the repo name, so two copies on one `<owner>.github.io` don't share
  tokens, settings or demo data.
- Reminder public key and app name live in `js/config.js`; `remind.mjs` reads the same file and works out the
  app URL from `GITHUB_REPOSITORY`. The backup workflow names files after the repo and skips missing files.
- **Start from a later year** (Settings): `L.dropYearsBefore(s, year)` in `core.js` deletes snapshots,
  planHistory, checklists, one-offs, past-dated upcoming items and budget years before 1 Jan of `year`.
  If no budget year is left, `year` is added with the latest year's amounts and pay months.
- Fixed: the Planner crashed when no balances had been logged (projection spec had no `controls`).

## Architecture

Plain HTML/CSS/JS with no build step. Classic `<script>` tags (not modules), so the preview
also works from `file://`.

| File | Role |
|---|---|
| `index.html` | Shell: gates (token, PIN), header/nav, modal, toast |
| `style.css` | Tokens for dark (default) and light themes; mobile-first, 12-col grid at ≥900px, bottom nav below 900px |
| `js/core.js` | Encryption (AES-256-GCM, PBKDF2 210k; same envelope as v1), GitHub Contents API, save queue, focus-pull, v1→v2 migration, preview mode |
| `js/model.js` | All derived numbers: timeline (with gap interpolation), change, rolling averages, plan totals, coverage, ladder, tags, year summaries, projection |
| `js/charts.js` | Dependency-free SVG charts: line/stacked area, signed bars + overlay, waterfall, sparkline, html bars. Tooltips, resize-aware |
| `js/app.js` | Formatting, UI prefs, render loop, chart registry, modal, delegated events, settings, boot |
| `js/views.js` | The five pages (Overview, Accounts, Budget, Trends, Planner), chart specs and popups |
| `sw.js` | Service worker. Only shows push notifications and handles taps; no caching |
| `.github/workflows/reminders.yml` + `.github/reminders/remind.mjs` | Scheduled check-in reminders (see below) |

- **Data file**: `ledger.json` (encrypted v2). The v1 file `data.json` is **left untouched** as a backup;
  if `ledger.json` is ever missing, unlock migrates `data.json` automatically.
- **Sync**: last-write-wins; re-reads the `sha` before each PUT, retries once on conflict; pulls on
  focus/visibility if not mid-edit.
- **Rendering**: each page is a pure function of state. Edits commit on `change` (blur) and the page
  redraws straight away, putting focus (and the cursor) back on the field you're in, matched by its
  data-* attributes. Only a text box with unsaved typing delays the redraw. (Before v2.3 any focused
  input, including a just-clicked tick box or dropdown, delayed it, so Planner edits looked like they did nothing.)
- **Generic editing**: `data-edit="field" data-coll="<path>" data-id data-f [data-type=num]` edits any list item;
  `data-act="add|del"` with `data-coll` adds or removes. Paths support `#id` segments, e.g. `scenarios.#s12.items`.

## Preview mode (for trying changes without touching real data)

From the project folder (not `code/`) run `python3 -m http.server 8765`, then open
http://localhost:8765/code/index.html?preview. It loads `../data/ledger-preview.js` (the
unencrypted seed in the private `data/` folder, never committed). Edits stay in that browser's
localStorage; Settings → Reset preview restores the seed.

## Demo mode (v2.4, for showing the app to others)

- **Log in**: token or PIN screen → "Log in to the demo" → name `test demo`, PIN `123456` (case and
  spacing in the name don't matter). The check is in `app.js` (`demoLogin`); it's a convenience, not
  security, because the repo is public. Real data still needs the token + real PIN.
- **Mode**: login sets `sessionStorage.ledger_demo = 1` and reloads. `L.DEMO` (core.js) is read once at
  load; `L.LOCAL = PREVIEW || DEMO` switches off every GitHub read/write, focus pulls and push
  notifications. Closing the tab ends the demo; Exit demo / Lock clear the flag.
- **Data**: `js/demo.js` → `L.demoState()` builds an invented household for today's date: 10 accounts
  + 2 estimated assets, 36 months of per-account history, this month's check-in 4/10 done, budget
  2 years back to 1 year ahead with pay months, one-offs, upcoming costs, three what-ifs and a loft
  project. Fixed random seed, so every reset gives the same household. Run it through `M` in Node to
  sanity-check numbers (liquid ~£53k → ~£80k, ~15 months of cover).
- **Storage**: edits save to `localStorage["<repo>:demo_state_v1"]`. Reset demo data (demo bar or Settings)
  deletes it. A demo nobody has edited is rebuilt each month so history always runs to today; bump
  `L.DEMO_VERSION` after changing `demo.js` so saved demos are rebuilt.
- **Text**: Trends "About this data" and the net worth subtitle have a demo version.

## Design system

Dark by default: off-black `--bg:#0E0F0B`, yellow accent
`--accent:#E8B83A`, Georgia/Iowan for titles. Light theme keeps the v1 "ledger" palette. Chart
colours are the dataviz skill's validated 8-slot order (`--s1..--s8`): savings = slot 1 (blue),
current = slot 2 (orange), up/down change = blue/red (diverging). Tags default to slots 3+ so they
never clash with savings/current. No horizontal scrolling at any width; wide tables hide
secondary columns below 560px (`.hide-sm`).

## Definitions (one place for each)

- **Months of cover** = (liquid [− slower money] + fund adjustments) ÷ (planning-year fixed + living [+ extras] + cost
  adjustments). The chart over time uses the same denominator for every month; fund adjustments only
  apply to the latest point, so the chart's last point equals the headline. "Slower money" = accounts
  with the tag picked in Planner (default Market-linked); left out only when ticked, and in the chart only
  from the first month with per-account balances.
- **Monthly change** = change in liquid funds. Transfers between own accounts net to zero; "What moved"
  pairs an outflow and inflow within 5% of each other (≥£500) and shows them as a transfer.
- **Plan for a month**: `planHistory` for past months, the budget (with `payMonths`) for now and the future.
  An imported plan spreads every line evenly, so past months also take the pay months set for that year: each such
  line's monthly average moves into its pay months (`timingShift` in model.js); totals per year don't change.
- **Projection**: actual for the last 12 or 24 months (solid), then 24 months dashed along (i) the 6-month
  average trend, (ii) the budget month by month, (iii) the budget plus active what-ifs. Coming up items are added to all three.

## UI patterns

- Multi-series charts take `pills` (tick boxes) instead of a legend. Hidden series are per device in
  `UI.off[chartKey]`, and the y-axis rescales to the visible series.
- Navigation: sidebar ≥1100px; hamburger drawer below that; bottom tab bar below 900px. Theme toggle
  in the header (sun/moon) and in the menu (Dark/Light/Auto).
- Where the money goes (Budget): one bucket ticked → bars split by that bucket's lines (top 7 + Other).
  The line on the right axis is the ticked spend as % of that month's total income (a deliberate
  dual axis; outlier months are clipped and labelled). Tapping a bar opens that month's breakdown
  below the chart: bucket % of income, then each line's % of its bucket.
- Calendar reminder: Settings or menu → "Monthly reminder" downloads a repeating `.ics` (9am on the 1st, nudge
  2 days later). The home-screen icon badge shows accounts left to update where supported.

## Push reminders (v2.2)

- **Device side**: Settings → Phone notifications → "Turn on" asks permission, subscribes with the
  VAPID public key in `js/app.js`, and saves the subscription in `state.push.subs` (so it's encrypted
  in `ledger.json` and shared across devices). iPhone needs iOS 16.4+ and the app opened from the
  home-screen icon; Safari tabs can't receive web push.
- **Sender**: `.github/workflows/reminders.yml` runs at 08:00 and 09:00 UTC daily. `remind.mjs` keeps
  only the run that is 9am in London (BST/GMT), decrypts `ledger.json` with the `LEDGER_PIN` secret,
  loads `js/model.js` in a sandbox and calls `M.checkin(s, thisMonth)`. If the check-in isn't complete
  it pushes "New month…" (1st, nothing started) or "Still to do: …" to every saved device. Logs only
  counts, because Actions logs on a public repo are public.
- **Secrets** (repo Settings → Secrets and variables → Actions): `LEDGER_PIN`, `VAPID_PRIVATE_KEY`.
  Lose the private key → generate a new pair, put the public half in `app.js` and `remind.mjs`,
  and turn notifications on again on each device.
- **Manual run**: Actions tab → Check-in reminders → Run workflow → `test` (send a test now) or
  `check` (normal logic now).
- GitHub can delay scheduled runs by some minutes, and pauses schedules in public repos after 60 days
  without commits (each save is a commit, so monthly use keeps it alive).

## Backups (monthly, automatic)

Every save is already a commit, so `git log ledger.json` holds every version. On top of that,
`.github/workflows/backup.yml` (06:00 UTC on the 7th) saves a Release `backup-YYYY-MM-DD` with
`<repo>-<date>.bundle` (the whole repo, every commit) and `ledger-<date>.json` (encrypted). See the repo's
Releases page. Settings → Download backup also saves an unencrypted copy to the device (keep it private).

**Restore**
- Whole repo: `git clone <repo>-<date>.bundle <repo>` gives a full working copy with history; push it to a
  new or emptied GitHub repo.
- Just the data: copy `ledger-<date>.json` over `ledger.json` in the repo and commit + push. The
  app picks it up on the next unlock. Same PIN as when it was saved.
