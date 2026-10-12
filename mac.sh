#!/bin/bash
# Capital Energy fleet bootstrap - Mac. Version: see VERSION in this repository.
# Paste ONE line into Terminal (the email from M has it):
#   curl -fsSL https://raw.githubusercontent.com/cptlenergy/fleet-bootstrap/main/mac.sh | bash
# It installs the tools, signs you in to GitHub and Claude Code (your browser opens),
# copies the Capital Energy corpus to ~/CapitalEnergy/corpus, and hands over to the
# member kit inside it. Safe to run again: it skips whatever is already done.
# It deletes nothing. It never touches files outside ~/CapitalEnergy, the tools it
# installs, and your Claude Code settings.
set -u
ORG="cptlenergy"; CORPUS="Capital_Energy"; CE_HOME="$HOME/CapitalEnergy"
BV="1.0.0"
step() { echo ""; echo "==== $*"; }
ok() { echo "  OK    $*"; }
note() { echo "  NOTE  $*"; }
stop() { echo ""; echo "STOPPED: $*"; echo "Nothing is broken. Fix the one thing above, then paste the same line again."; exit 1; }
pause() { printf "  %s" "$1" > /dev/tty; read -r _ < /dev/tty; }

main() {
echo "Capital Energy - setting up this Mac for the AI fleet (bootstrap $BV)"
echo "About 15 to 30 minutes. You will be asked for this Mac's password once, and your"
echo "browser will open three times for sign-ins. Keep this window open until it says DONE."

step "1 of 7 - checking this Mac"
MAJ="$(sw_vers -productVersion | cut -d. -f1)"
[ "$MAJ" -ge 13 ] 2>/dev/null || stop "this Mac runs macOS $(sw_vers -productVersion); Claude Code needs macOS 13 or newer (Apple menu > System Settings > General > Software Update)."
ok "macOS $(sw_vers -productVersion) on $(scutil --get ComputerName 2>/dev/null)"

step "2 of 7 - tools (git, GitHub, tmux, ttyd, Claude Code, Chrome, the Claude app)"
for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)" && break; done
if ! command -v brew >/dev/null 2>&1; then
  echo "  Homebrew (the Mac's package installer) is not here yet - installing it."
  echo "  Type this Mac's password when asked (nothing shows while you type), then press Enter."
  sudo -v < /dev/tty || stop "the password was not accepted."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" < /dev/null \
    || stop "Homebrew did not install."
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)" && break; done
  grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null || echo "eval \"\$($(command -v brew) shellenv)\"" >> "$HOME/.zprofile"
fi
BREW_OK=0
if command -v brew >/dev/null 2>&1 && [ -w "$(brew --prefix)/bin" ]; then BREW_OK=1; ok "Homebrew ready"
elif command -v brew >/dev/null 2>&1; then note "Homebrew belongs to another account on this Mac - using the tools it already installed"; fi
mkdir -p "$HOME/.local/bin"; export PATH="$HOME/.local/bin:$PATH"
grep -q '.local/bin' "$HOME/.zprofile" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zprofile"
for t in git gh tmux ttyd; do
  if command -v "$t" >/dev/null 2>&1; then ok "$t present"
  elif [ "$BREW_OK" = 1 ]; then brew install --quiet "$t" >/dev/null 2>&1 && ok "$t installed" || stop "Homebrew could not install $t."
  elif [ "$t" = gh ]; then
    ARCH="$(uname -m)"; [ "$ARCH" = arm64 ] || ARCH=amd64
    U="$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | sed -nE "s/.*\"browser_download_url\": \"([^\"]*macOS_${ARCH}\.zip)\".*/\1/p" | head -n 1)"
    [ -n "$U" ] || stop "could not find the GitHub command-line tool to download."
    T="$(mktemp -d)"; curl -fsSL "$U" -o "$T/gh.zip" && (cd "$T" && unzip -q gh.zip) && cp "$T"/gh_*/bin/gh "$HOME/.local/bin/gh" \
      && ok "gh installed for this account" || stop "could not install the GitHub command-line tool."
  else
    stop "$t is missing and Homebrew here belongs to another account. Ask that account to run: brew install $t"
  fi
done
if [ ! -d "/Applications/Google Chrome.app" ]; then
  [ "$BREW_OK" = 1 ] && brew install --quiet --cask google-chrome >/dev/null 2>&1 && ok "Google Chrome installed" \
    || { note "Google Chrome is not installed - the download page opens; install it, then come back"; open "https://www.google.com/chrome/"; pause "Press Enter when Chrome is installed. "; }
else ok "Google Chrome present"; fi
if [ ! -d "/Applications/Claude.app" ]; then
  [ "$BREW_OK" = 1 ] && brew install --quiet --cask claude >/dev/null 2>&1 && ok "Claude desktop app installed" \
    || { note "the Claude desktop app is not installed - the download page opens; install it, then come back"; open "https://claude.ai/download"; pause "Press Enter when the Claude app is installed. "; }
else ok "Claude desktop app present"; fi
if ! command -v claude >/dev/null 2>&1; then
  curl -fsSL https://claude.ai/install.sh | bash >/dev/null 2>&1 || stop "Claude Code did not install."
  export PATH="$HOME/.local/bin:$PATH"
fi
command -v claude >/dev/null 2>&1 && ok "Claude Code $(claude --version 2>/dev/null | head -n 1)" || stop "Claude Code is not on this account's PATH."

step "3 of 7 - GitHub sign-in (your browser opens; sign in with your Capital Energy email)"
if gh auth status >/dev/null 2>&1; then ok "already signed in to GitHub"
else
  echo "  Below you will see a one-time code. Press Enter, then in the browser type that code and approve."
  gh auth login --hostname github.com --git-protocol https --web --scopes "read:org,user:email" < /dev/tty \
    || stop "the GitHub sign-in did not finish."
fi
gh auth setup-git >/dev/null 2>&1
S="$(gh api "user/memberships/orgs/$ORG" --jq .state 2>/dev/null)"
if [ "$S" = pending ]; then
  gh api -X PATCH "user/memberships/orgs/$ORG" -f state=active >/dev/null 2>&1
  S="$(gh api "user/memberships/orgs/$ORG" --jq .state 2>/dev/null)"
fi
if [ "$S" != active ]; then
  echo "  Your browser opens the Capital Energy invitation on GitHub. Click the green Join button."
  open "https://github.com/orgs/$ORG/invitation"
  pause "Press Enter after you clicked Join. "
  S="$(gh api "user/memberships/orgs/$ORG" --jq .state 2>/dev/null)"
fi
[ "$S" = active ] && ok "member of the $ORG organization on GitHub" \
  || stop "this GitHub account is not in the $ORG organization yet. The invitation goes to your Capital Energy email; it may not have been sent yet."

step "4 of 7 - Claude Code sign-in (your browser opens; sign in with your Capital Energy email)"
A="$(claude auth status --text 2>&1)"
if ! echo "$A" | grep -qi -e "not logged" -e "not signed" -e "no account" && echo "$A" | grep -q "@"; then ok "Claude Code already signed in"
else
  claude auth login < /dev/tty || stop "the Claude Code sign-in did not finish."
  ok "Claude Code signed in"
fi

step "5 of 7 - the Capital Energy corpus (about 60 MB)"
mkdir -p "$CE_HOME"
if [ -d "$CE_HOME/corpus/.git" ]; then
  git -C "$CE_HOME/corpus" pull --ff-only --quiet && ok "corpus copy updated" || note "the corpus copy could not be updated now; the member kit will report it"
else
  gh repo clone "$ORG/$CORPUS" "$CE_HOME/corpus" -- --quiet || stop "could not copy the corpus from GitHub."
  ok "corpus copied to $CE_HOME/corpus"
fi

step "6 of 7 - the member kit (three privacy questions come up here)"
bash "$CE_HOME/corpus/06_scripts_data/fleet_member/install_member.sh" || stop "the member kit reported a problem (read the lines above)."

step "7 of 7 - finishing"
cp "$CE_HOME/.ce_member/START_PROMPT.md" "$CE_HOME/START_PROMPT.md" 2>/dev/null
pbcopy < "$CE_HOME/.ce_member/START_PROMPT.md" && ok "the start prompt is on your clipboard"
open -a "Claude" 2>/dev/null
open -a "Google Chrome" "https://claude.com/chrome" 2>/dev/null
echo ""
echo "DONE with the automatic part. Three things left, in the Claude app that just opened:"
echo "  1. Sign in with your Capital Energy email."
echo "  2. In Chrome (it opened too), click Add to Chrome for Claude in Chrome, and sign it in the same way."
echo "  3. Back in the Claude app, open the Code tab, choose the folder CapitalEnergy in your home"
echo "     folder, click in the message box, press Command-V and Return. The AI takes it from there."
}
# The whole script is read before anything runs (main is called on the last line),
# so no installer below can swallow the rest of it from the pipe.
main "$@"
