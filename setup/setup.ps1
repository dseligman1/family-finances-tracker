# One-time setup for your own copy of Family Finances Tracker (Windows PowerShell).
# Creates your GitHub repo, publishes the app on GitHub Pages, makes the phone-reminder keys and
# saves your PIN + private key as repo secrets, so the reminder and backup Actions work.
#
# Run from the code folder:   powershell -ExecutionPolicy Bypass -File setup\setup.ps1
# Needs: git and the GitHub CLI (gh). Install both with:
#   winget install --id Git.Git -e ; winget install --id GitHub.cli -e
# then close and reopen PowerShell.
# 'Continue', not 'Stop': Windows PowerShell 5.1 treats any stderr from git/gh as an error under 'Stop'.
# Each step checks its own result instead.
$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..')

function Say($m){ Write-Host "`n$m" -ForegroundColor Yellow }
function Die($m){ Write-Host "`nStopped: $m" -ForegroundColor Red; exit 1 }

Say '1/6  Checking tools'
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Die 'git is not installed. Run:  winget install --id Git.Git -e   then reopen PowerShell and run this again.' }
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Die 'The GitHub CLI is not installed. Run:  winget install --id GitHub.cli -e   then reopen PowerShell and run this again.' }
gh auth status *> $null
if ($LASTEXITCODE -ne 0) { Write-Host 'Not logged in to GitHub yet. A browser window will open to log in.'; gh auth login --hostname github.com --git-protocol https --web; if ($LASTEXITCODE -ne 0) { Die 'GitHub login did not finish.' } }
$owner = (gh api user --jq .login).Trim()
Write-Host "GitHub account: $owner"

Say '2/6  Your repo and PIN'
$repo = $env:REPO_NAME
if (-not $repo) { $repo = Read-Host 'Name for your GitHub repo [family-finances-tracker]' }
if (-not $repo) { $repo = 'family-finances-tracker' }
if ($repo -notmatch '^[A-Za-z0-9._-]+$') { Die 'Use only letters, numbers, dashes, dots or underscores in the repo name.' }
gh repo view "$owner/$repo" *> $null
if ($LASTEXITCODE -eq 0) { Die "$owner/$repo already exists. Pick another name, or delete that repo first." }
$pin = $env:LEDGER_PIN
if (-not $pin) {
  Write-Host 'Choose the PIN that will lock your data. At least 6 characters. There is no way to recover it,'
  Write-Host 'so save it in your password manager now.'
  $plain = { param($s) [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)) }
  $pin = & $plain (Read-Host 'PIN' -AsSecureString)
  $pin2 = & $plain (Read-Host 'Same PIN again' -AsSecureString)
  if ($pin -ne $pin2) { Die 'The two PINs did not match. Run the script again.' }
  if ($pin.Length -lt 6) { Die 'The PIN needs at least 6 characters.' }
}
# A PIN passed in LEDGER_PIN (for a test copy) skips the length check; it still can't be empty.
if (-not $pin) { Die 'The PIN cannot be empty.' }

Say '3/6  Making the phone-reminder keys'
function B64U([byte[]]$b){ [Convert]::ToBase64String($b).TrimEnd('=').Replace('+','-').Replace('/','_') }
$ec = [System.Security.Cryptography.ECDsa]::Create([System.Security.Cryptography.ECCurve+NamedCurves]::nistP256)
$p = $ec.ExportParameters($true)
$pub = B64U ([byte[]](@([byte]4) + $p.Q.X + $p.Q.Y))
$priv = B64U $p.D
if ($pub.Length -ne 87 -or $priv.Length -ne 43) { Die 'The reminder keys did not come out right.' }
$cfgPath = Join-Path (Get-Location) 'js\config.js'
$cfg = [IO.File]::ReadAllText($cfgPath) -replace "vapidPublicKey: '[^']*'", "vapidPublicKey: '$pub'"
[IO.File]::WriteAllText($cfgPath, $cfg)
if (-not ([IO.File]::ReadAllText($cfgPath)).Contains($pub)) { Die 'Could not write the public key into js\config.js.' }
Write-Host 'Public key saved in js\config.js. The private key goes straight into a GitHub secret.'

Say "4/6  Creating $owner/$repo and uploading the app"
if (-not (Test-Path .git)) { git init -q -b main }
git add -A
git -c "user.name=$owner" -c "user.email=$owner@users.noreply.github.com" commit -q -m 'Set up Family Finances Tracker' 2>$null
git branch -M main
gh repo create "$owner/$repo" --public --source=. --remote=origin --push --description 'Private family budget and net-worth tracker (data encrypted)' | Out-Null
if ($LASTEXITCODE -ne 0) { Die 'Creating or uploading the repo failed (see the message above).' }
Write-Host 'Uploaded.'

Say '5/6  Saving secrets for the reminder Action'
gh secret set LEDGER_PIN --repo "$owner/$repo" --body "$pin"
gh secret set VAPID_PRIVATE_KEY --repo "$owner/$repo" --body "$priv"
Remove-Variable pin, priv -ErrorAction SilentlyContinue

Say '6/6  Switching on GitHub Pages'
gh api -X POST "repos/$owner/$repo/pages" -f 'source[branch]=main' -f 'source[path]=/' *> $null
if ($LASTEXITCODE -ne 0) { gh api -X PUT "repos/$owner/$repo/pages" -f 'source[branch]=main' -f 'source[path]=/' *> $null }
if ($LASTEXITCODE -ne 0) { Write-Host 'Could not switch Pages on automatically: repo Settings > Pages > Branch: main, folder / (root) > Save.' }
$lc = $owner.ToLower()

Write-Host "`nDone." -ForegroundColor Green
Write-Host "  App:   https://$lc.github.io/$repo/   (live in 1-2 minutes)"
Write-Host "  Repo:  https://github.com/$owner/$repo"
Write-Host @"

Last step, in your browser: make the token the app uses to save.
  1. Open https://github.com/settings/personal-access-tokens/new
  2. Name: $repo. Expiration: up to a year.
  3. Repository access: Only select repositories -> $repo
  4. Permissions -> Repository permissions -> Contents: Read and write
  5. Generate, copy the token (github_pat_...), open the app, paste it, then enter your PIN.
     First time: tap "Start an empty ledger".
"@
