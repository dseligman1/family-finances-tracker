#!/bin/bash
# One-time setup for your own copy of Family Finances Tracker (Mac / Linux).
# Creates your GitHub repo, publishes the app on GitHub Pages, makes the phone-reminder keys and
# saves your PIN + private key as repo secrets, so the reminder and backup Actions work.
#
# Run from the code folder:   bash setup/setup.sh
# Needs: git and the GitHub CLI (gh), logged in. The script checks both and tells you what to do.
# Optional, to skip the questions:  REPO_NAME=my-finances LEDGER_PIN=123456 bash setup/setup.sh
set -euo pipefail
cd "$(dirname "$0")/.."

say(){ printf '\n\033[1;33m%s\033[0m\n' "$1"; }
die(){ printf '\n\033[1;31mStopped: %s\033[0m\n' "$1"; exit 1; }

say "1/6  Checking tools"
command -v git >/dev/null || die "git isn't installed. Run:  xcode-select --install   then run this script again."
command -v gh  >/dev/null || die "The GitHub CLI isn't installed. Run:  brew install gh   (or download it from https://cli.github.com), then run this script again."
command -v openssl >/dev/null || die "openssl is missing (it comes with macOS, so this is unusual)."
gh auth status >/dev/null 2>&1 || { echo "You're not logged in to GitHub yet. A browser window will open to log in."; gh auth login --hostname github.com --git-protocol https --web; }
OWNER=$(gh api user --jq .login) || die "Couldn't read your GitHub username."
echo "GitHub account: $OWNER"

say "2/6  Your repo and PIN"
REPO="${REPO_NAME:-}"
if [ -z "$REPO" ]; then read -r -p "Name for your GitHub repo [family-finances-tracker]: " REPO; fi
REPO="${REPO:-family-finances-tracker}"
[[ "$REPO" =~ ^[A-Za-z0-9._-]+$ ]] || die "Use only letters, numbers, dashes, dots or underscores in the repo name."
if gh repo view "$OWNER/$REPO" >/dev/null 2>&1; then die "$OWNER/$REPO already exists. Pick another name, or delete that repo first."; fi
PIN="${LEDGER_PIN:-}"
if [ -z "$PIN" ]; then
  echo "Choose the PIN that will lock your data. At least 6 characters. There's no way to recover it,"
  echo "so save it in your password manager now. (Nothing shows while you type.)"
  read -r -s -p "PIN: " PIN; echo
  read -r -s -p "Same PIN again: " PIN2; echo
  [ "$PIN" = "$PIN2" ] || die "The two PINs didn't match. Run the script again."
fi
[ ${#PIN} -ge 6 ] || die "The PIN needs at least 6 characters."

say "3/6  Making the phone-reminder keys"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
openssl ecparam -name prime256v1 -genkey -noout -out "$TMP/k.pem" 2>/dev/null
b64u(){ base64 | tr -d '\n=' | tr '+/' '-_'; }
PRIV=$(openssl ec -in "$TMP/k.pem" -outform DER 2>/dev/null | tail -c +8 | head -c 32 | b64u)
PUB=$(openssl ec -in "$TMP/k.pem" -pubout -outform DER 2>/dev/null | tail -c 65 | b64u)
[ ${#PUB} -eq 87 ] && [ ${#PRIV} -eq 43 ] || die "The reminder keys didn't come out right."
sed -i.bak "s|vapidPublicKey: '[^']*'|vapidPublicKey: '$PUB'|" js/config.js && rm -f js/config.js.bak
grep -q "$PUB" js/config.js || die "Couldn't write the public key into js/config.js."
echo "Public key saved in js/config.js. The private key goes straight into a GitHub secret."

say "4/6  Creating $OWNER/$REPO and uploading the app"
[ -d .git ] || git init -q -b main
git add -A
git -c user.name="${GIT_NAME:-$OWNER}" -c user.email="${GIT_EMAIL:-$OWNER@users.noreply.github.com}" commit -q -m "Set up Family Finances Tracker" || true
git branch -M main
gh repo create "$OWNER/$REPO" --public --source=. --remote=origin --push \
  --description "Private family budget and net-worth tracker (data encrypted)" >/dev/null
echo "Uploaded."

say "5/6  Saving secrets for the reminder Action"
gh secret set LEDGER_PIN --repo "$OWNER/$REPO" --body "$PIN"
gh secret set VAPID_PRIVATE_KEY --repo "$OWNER/$REPO" --body "$PRIV"
unset PIN PIN2 PRIV

say "6/6  Switching on GitHub Pages"
gh api -X POST "repos/$OWNER/$REPO/pages" -f "source[branch]=main" -f "source[path]=/" >/dev/null 2>&1 \
  || gh api -X PUT "repos/$OWNER/$REPO/pages" -f "source[branch]=main" -f "source[path]=/" >/dev/null 2>&1 \
  || echo "Couldn't switch Pages on automatically: repo Settings → Pages → Branch: main, folder / (root) → Save."
OWNER_LC=$(echo "$OWNER" | tr '[:upper:]' '[:lower:]')

cat <<EOF

$(printf '\033[1;32m')Done.$(printf '\033[0m')
  App:   https://$OWNER_LC.github.io/$REPO/   (live in 1–2 minutes)
  Repo:  https://github.com/$OWNER/$REPO

Last step, in your browser: make the token the app uses to save.
  1. Open https://github.com/settings/personal-access-tokens/new
  2. Name: $REPO. Expiration: up to a year.
  3. Repository access: Only select repositories → $REPO
  4. Permissions → Repository permissions → Contents: Read and write
  5. Generate, copy the token (github_pat_...), open the app, paste it, then enter your PIN.
     First time: tap "Start an empty ledger".
EOF
