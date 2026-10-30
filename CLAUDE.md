# Family Finances Tracker: notes for Claude

A household budget and net-worth web app, hosted on GitHub Pages from this repo. Read `PROGRESS.md` before
changing code: it covers the architecture, data model, definitions and design system.

## Who you're working with

The person using you probably isn't a developer and may be new to the terminal.
- Explain each command in plain English before running it, and say what it changes.
- Keep replies short. Lead with what you did or what they need to do next.
- Never ask for their PIN or GitHub token, and stop them if they start to paste one.

## Hard rules

1. **This repo is public.** Never commit unencrypted data: backup files (`*backup*.json`), exports, CSVs,
   screenshots of real numbers, the PIN or the token. Run `git status` and check every file before committing.
2. **Never edit `ledger.json` by hand.** It's the encrypted data; only the app writes it.
3. **Pull first.** The app commits to this repo every time someone saves, so the local copy goes out of date
   quickly. Run `git pull --rebase` before starting work and again before pushing. Never force-push.
4. **Keep existing data working.** If you add or rename a field, give it a default in `L.normalise`
   (`js/core.js`) so ledgers saved before the change still open. Don't remove fields people may have data in.
5. **No build step, no frameworks.** Plain HTML/CSS/JS with classic `<script>` tags. Keep `js/model.js` free
   of browser APIs: the reminder Action (`.github/reminders/remind.mjs`) runs it in Node.
6. **Use the design tokens** at the top of `style.css` for colours, so dark and light themes both work.
   No horizontal scrolling at phone width (390px).

## Making a change

1. `git pull --rebase`.
2. Make the change.
3. **Test it with the demo** (made-up data, nothing touches GitHub): from this folder run
   `python3 -m http.server 8765` (Windows: `python -m http.server 8765`; if Python is missing, ask before
   installing it with `winget install Python.Python.3.12`). Open http://localhost:8765/, tap
   **Log in to the demo**, name `test demo`, PIN `123456`. Check every page you touched, at phone width too.
4. **Bump the version** in `index.html`: change every `?v=x.y.z` to the next number, so phones load the new code.
5. Show the person what changed and ask before committing. Then commit with a clear message,
   `git pull --rebase`, and `git push`. The live app updates in 1–2 minutes.
6. To undo a change that's live: `git revert <commit>` and push (never rewrite history).

## Where things are

| File | What it does |
|---|---|
| `js/config.js` | App name, header title, public reminder key |
| `js/core.js` | Encryption, GitHub saving, `L.normalise`, "Start from a later year" |
| `js/model.js` | Every number the screens show (months of cover, trends, projections) |
| `js/views.js` | The five pages and their charts |
| `js/app.js` | Settings, the first-run guide (`TOUR`), notifications, start-up |
| `js/demo.js` | The made-up demo household |
| `style.css` | Design tokens and layout |
| `.github/workflows/` | Monthly check-in reminders and the monthly backup |
