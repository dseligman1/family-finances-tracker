# Family Finances Tracker

A private, shared family budget and net-worth tracker. A phone-friendly web app hosted free on GitHub Pages.
Your numbers are stored **encrypted** in this repo as `ledger.json`.

## How it works

- The repo is public, because GitHub Pages on a free account only serves public repos. Your data is never
  stored in plain text: before anything is saved, the app encrypts it in your browser (AES-256-GCM) with a
  key made from your PIN. Anyone browsing the repo sees only unreadable ciphertext.
- Saving is a git commit, so every edit is versioned.
- Opening the app (or switching back to it) pulls the latest version, so everyone in the household stays in sync.

## Set up your own copy

Follow **SETUP-GUIDE.md** in the pack you were given. In short:

1. Install `git` and the GitHub CLI (`gh`), then run `bash setup/setup.sh` (Mac) or
   `powershell -ExecutionPolicy Bypass -File setup\setup.ps1` (Windows) from this folder. It creates your repo,
   switches on GitHub Pages, makes the phone-reminder keys and saves your PIN as a repo secret.
2. Make a fine-grained GitHub token for the repo (Contents: Read and write), open the app, paste it in,
   enter your PIN and tap **Start an empty ledger**.
3. Share the same token and PIN with your partner (via a password manager) so they can use it on their phone.

## Pages

Overview (monthly check-in, headline numbers), Accounts (balances, tags, history), Budget (lines by year,
pay months), Trends (balances, monthly change, plan vs actual, year on year, net worth, months of cover) and
Planner (months of cover, what-ifs, coming up, one-offs, house project).

## Reminders and backups (GitHub Actions)

- **Check-in reminders** (`.github/workflows/reminders.yml`): 9am UK time on the 1st, then daily until the
  month's check-in is done, as a phone notification. Turn it on per device in Settings → Phone notifications.
  On iPhone, add the app to the Home Screen first (Safari → Share → Add to Home Screen). Needs the repo
  secrets `LEDGER_PIN` and `VAPID_PRIVATE_KEY` (the setup script sets both).
- **Monthly backup** (`.github/workflows/backup.yml`): on the 7th, a GitHub Release with the whole repo and the
  encrypted data. Restore: copy `ledger-<date>.json` over `ledger.json` and commit.

If you change your PIN later, update the `LEDGER_PIN` secret too (repo Settings → Secrets and variables → Actions).

## Start from a later year

Settings → **Start from a later year** deletes every check-in, one-off and budget year before the year you
pick. Download a backup first if you might want the old years back.

## Demo

On the token or PIN screen tap **Log in to the demo** (name `test demo`, PIN `123456`). It opens the full app
with a made-up household that stays in your browser. It's a convenience, not security.

## Settings file

`js/config.js` holds the app name and the public reminder key. Owner and repo are read from the address
(`<owner>.github.io/<repo>/`), so nothing else needs editing.

## Local preview

Run `python3 -m http.server 8765` from the folder *above* this repo, then open
`http://localhost:8765/code/index.html?preview`. It reads a private seed file at `../data/ledger-preview.js`
(never committed), and edits stay in the browser.
