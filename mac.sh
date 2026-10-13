#!/bin/bash
# Capital Energy fleet bootstrap - Mac. Version: see VERSION in this repository.
# Paste ONE line into Terminal (the email from M has it):
#   curl -fsSL https://raw.githubusercontent.com/cptlenergy/fleet-bootstrap/main/mac.sh | bash
# It installs the tools, signs you in to GitHub and Claude Code (your browser opens),
# copies the Capital Energy corpus to ~/CapitalEnergy/corpus, and hands over to the
# member kit inside it. Safe to run again: it skips whatever is already done.
# It says what it is doing at every step and prints a line at least every 15 seconds while
# anything slow runs. Everything it shows is also written to a setup log
# (~/Library/Logs/CapitalEnergy/), copied into the person's work repository at the end.
# It deletes nothing. It never touches files outside ~/CapitalEnergy, the tools it
# installs, its log folder, and your Claude Code settings.
set -u
ORG="cptlenergy"; CORPUS="Capital_Energy"; CE_HOME="$HOME/CapitalEnergy"
BV="1.0.6"
LOGDIR="$HOME/Library/Logs/CapitalEnergy"; mkdir -p "$LOGDIR"
LOG="$LOGDIR/$(date +%Y%m%d_%H%M%S)_setup.txt"
say() { echo "$*"; echo "$*" >> "$LOG"; }
step() { say ""; say "==== $*"; }
ok() { say "  OK    $*"; }
note() { say "  NOTE  $*"; }
stop() { say ""; say "STOPPED: $*"; say "Nothing is broken. Fix the one thing above, then paste the same line again."; say "The full record of this run is in $LOGDIR"; exit 1; }
# Keys pressed while the set-up was busy must never answer the next question: throw them away first.
flush_keys() { while read -r -t 0.05 -n 1000 _ < /dev/tty 2>/dev/null; do :; done; }
pause() { flush_keys; printf "  %s" "$1" > /dev/tty; read -r _ < /dev/tty; }
# After a sign-in in the browser, bring Terminal back to the front by itself.
come_back() { osascript -e 'tell application "Terminal" to activate' >/dev/null 2>&1; printf '\a'; say ""; say "  >>> $1 is done - welcome back to the set-up window. It carries on by itself now. <<<"; }
# run_long "what" <normal minutes> command...: runs a slow command that asks nothing, with its
# output in a log file, and prints a line every 15 seconds: time so far, normal time, latest line.
run_long() {
  local what="$1" normal="$2"; shift 2
  local f="$LOGDIR/$(date +%Y%m%d_%H%M%S)_$(echo "$what" | tr -cs 'A-Za-z0-9' '_').log"
  say "  $what - this usually takes up to $normal minute(s)."
  say "        A line appears here every 15 seconds while it works."
  "$@" > "$f" 2>&1 < /dev/null &
  local pid=$! t0=$SECONDS n=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep 1; n=$((n+1))
    if [ $((n % 15)) = 0 ] && kill -0 "$pid" 2>/dev/null; then
      local el=$((SECONDS - t0)) last
      last="$(tail -n 5 "$f" 2>/dev/null | tr -c '[:print:]\n' ' ' | sed 's/  */ /g;s/^ //;s/ $//' | awk 'length >= 4' | tail -n 1 | cut -c1-60)"
      say "    still working: $what - $((el / 60)):$(printf %02d $((el % 60))) so far (normal: up to $normal min)${last:+ - $last}"
      [ "$el" -gt $((normal * 180)) ] && say "    (slower than normal; a slow internet connection does this. Keep waiting.)"
    fi
  done
  wait "$pid"; local rc=$?
  local el=$((SECONDS - t0))
  say "    finished in $((el / 60)):$(printf %02d $((el % 60)))"
  return $rc
}

main() {
# one set-up at a time: pasting the line again while one runs must not start a second
LOCK="$LOGDIR/setup.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  if kill -0 "$(cat "$LOCK/pid" 2>/dev/null)" 2>/dev/null; then
    echo "The Capital Energy set-up is already running in another Terminal window. Use that window."; exit 0
  fi
  echo $$ > "$LOCK/pid"
else
  echo $$ > "$LOCK/pid"
fi
trap 'rm -f "$LOCK/pid"; rmdir "$LOCK" 2>/dev/null' EXIT
say "Capital Energy - setting up this Mac for the AI fleet (bootstrap $BV)"
say "About 15 to 30 minutes. You may be asked for this Mac's password once, and your browser"
say "opens for the sign-ins. Keep this window open until it says DONE."
say "While it works it prints a line at least every 15 seconds. When it needs you, it says so"
say "and waits. If no new line appears for 3 minutes and it is not waiting for you, close this"
say "window and paste the line again - it is safe to repeat and carries on where it stopped."

step "1 of 7 - checking this Mac"
MAJ="$(sw_vers -productVersion | cut -d. -f1)"
[ "$MAJ" -ge 13 ] 2>/dev/null || stop "this Mac runs macOS $(sw_vers -productVersion); Claude Code needs macOS 13 or newer (Apple menu > System Settings > General > Software Update)."
ok "macOS $(sw_vers -productVersion) on $(scutil --get ComputerName 2>/dev/null)"

step "2 of 7 - tools (git, GitHub, tmux, ttyd, Claude Code, Chrome, the Claude app) - about 5 to 15 minutes"
for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)" && break; done
if ! command -v brew >/dev/null 2>&1; then
  say "  Homebrew (the Mac's package installer) is not here yet - installing it (about 5 minutes;"
  say "  its own messages scroll past below)."
  say "  Type this Mac's password when asked (nothing shows while you type), then press Enter."
  sudo -v < /dev/tty || stop "the password was not accepted."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" < /dev/null 2>&1 | tee -a "$LOG"
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)" && break; done
  command -v brew >/dev/null 2>&1 || stop "Homebrew did not install."
  grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null || echo "eval \"\$($(command -v brew) shellenv)\"" >> "$HOME/.zprofile"
fi
BREW_OK=0
if command -v brew >/dev/null 2>&1 && [ -w "$(brew --prefix)/bin" ]; then BREW_OK=1; ok "Homebrew ready"
elif command -v brew >/dev/null 2>&1; then note "Homebrew belongs to another account on this Mac - using the tools it already installed"; fi
mkdir -p "$HOME/.local/bin"; export PATH="$HOME/.local/bin:$PATH"
grep -q '.local/bin' "$HOME/.zprofile" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zprofile"
for t in git gh tmux ttyd; do
  if command -v "$t" >/dev/null 2>&1; then ok "$t present"
  elif [ "$BREW_OK" = 1 ]; then run_long "installing $t" 3 brew install "$t" && ok "$t installed" || stop "Homebrew could not install $t."
  elif [ "$t" = gh ]; then
    ARCH="$(uname -m)"; [ "$ARCH" = arm64 ] || ARCH=amd64
    U="$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | sed -nE "s/.*\"browser_download_url\": \"([^\"]*macOS_${ARCH}\.zip)\".*/\1/p" | head -n 1)"
    [ -n "$U" ] || stop "could not find the GitHub command-line tool to download."
    T="$(mktemp -d)"; run_long "downloading the GitHub command-line tool" 2 curl -fsSL "$U" -o "$T/gh.zip" \
      && (cd "$T" && unzip -q gh.zip) && cp "$T"/gh_*/bin/gh "$HOME/.local/bin/gh" \
      && ok "gh installed for this account" || stop "could not install the GitHub command-line tool."
  else
    stop "$t is missing and Homebrew here belongs to another account. Ask that account to run: brew install $t"
  fi
done
if [ ! -d "/Applications/Google Chrome.app" ]; then
  [ "$BREW_OK" = 1 ] && run_long "installing Google Chrome" 5 brew install --cask google-chrome && ok "Google Chrome installed" \
    || { note "Google Chrome is not installed - the download page opens; install it, then come back"; open "https://www.google.com/chrome/"; pause "Press Enter when Chrome is installed. "; }
else ok "Google Chrome present"; fi
if [ ! -d "/Applications/Claude.app" ]; then
  [ "$BREW_OK" = 1 ] && run_long "installing the Claude desktop app" 5 brew install --cask claude && ok "Claude desktop app installed" \
    || { note "the Claude desktop app is not installed - the download page opens; install it, then come back"; open "https://claude.ai/download"; pause "Press Enter when the Claude app is installed. "; }
else ok "Claude desktop app present"; fi
if ! command -v claude >/dev/null 2>&1; then
  run_long "installing Claude Code" 3 bash -c 'curl -fsSL https://claude.ai/install.sh | bash' || stop "Claude Code did not install."
  export PATH="$HOME/.local/bin:$PATH"
fi
command -v claude >/dev/null 2>&1 && ok "Claude Code $(claude --version 2>/dev/null | head -n 1)" || stop "Claude Code is not on this account's PATH."

step "3 of 7 - GitHub sign-in (your browser opens a new tab; use your Capital Energy email)"
if gh auth status >/dev/null 2>&1; then ok "already signed in to GitHub"
else
  say "  In a moment a browser tab opens on GitHub, asking for a code. The code is already"
  say "  copied for you: click in the first box, press Command-V, click Continue, then the green"
  say "  Authorize button. (If this window says Press Enter, press Return.) This window then comes"
  say "  back to the front by itself."
  ( sleep 3; open "https://github.com/login/device" ) &
  flush_keys
  GH_PROMPT_DISABLED=1 gh auth login --hostname github.com --git-protocol https --web --clipboard --scopes "read:org,user:email" < /dev/tty \
    || stop "the GitHub sign-in did not finish."
  come_back "The GitHub sign-in"
fi
gh auth setup-git >/dev/null 2>&1
S="$(gh api "user/memberships/orgs/$ORG" --jq .state 2>/dev/null)"
if [ "$S" = pending ]; then
  gh api -X PATCH "user/memberships/orgs/$ORG" -f state=active >/dev/null 2>&1
  S="$(gh api "user/memberships/orgs/$ORG" --jq .state 2>/dev/null)"
fi
TRIES=0
while [ "$S" != active ] && [ "$TRIES" -lt 3 ]; do
  TRIES=$((TRIES+1))
  say ""
  say "  Your GitHub account is not in Capital Energy on GitHub yet. To join:"
  say "    1. Open your Capital Energy email (in a browser tab)."
  say "    2. Find the email from GitHub inviting you to join cptlenergy."
  say "       If you cannot see it, search your mailbox for:  cptlenergy"
  say "    3. Click \"Join @cptlenergy\" in that email."
  say "    4. On the GitHub page that opens, leave \"Ask for a GitHub Copilot seat\" unticked"
  say "       and click the green \"Join cptlenergy\" button."
  pause "Then come back to this window and press Enter. "
  S="$(gh api "user/memberships/orgs/$ORG" --jq .state 2>/dev/null)"
done
[ "$S" = active ] && ok "member of the $ORG organization on GitHub" \
  || stop "this GitHub account is not in the $ORG organization yet. If there is no invitation email from GitHub, tell M: the invitation may not have been sent."

step "4 of 7 - Claude Code sign-in (your browser opens a new tab; use your Capital Energy email)"
A="$(claude auth status --text 2>&1)"
if ! echo "$A" | grep -qi -e "not logged" -e "not signed" -e "no account" && echo "$A" | grep -q "@"; then ok "Claude Code already signed in"
else
  say "  A browser tab opens: sign in with your Capital Energy email and click Authorize."
  say "  This window then comes back to the front by itself."
  flush_keys
  claude auth login < /dev/tty || stop "the Claude Code sign-in did not finish."
  come_back "The Claude Code sign-in"
  ok "Claude Code signed in"
fi

step "5 of 7 - the Capital Energy corpus (about 60 MB)"
mkdir -p "$CE_HOME"
if [ -d "$CE_HOME/corpus/.git" ] && ! git -C "$CE_HOME/corpus" rev-parse --verify -q HEAD >/dev/null; then
  ASIDE="$CE_HOME/corpus_incomplete_$(date +%Y%m%d_%H%M%S)"
  mv "$CE_HOME/corpus" "$ASIDE" && note "an unfinished corpus copy from an earlier run was moved aside to $ASIDE; copying it again"
fi
if [ -d "$CE_HOME/corpus/.git" ]; then
  run_long "updating the corpus copy from GitHub" 3 git -C "$CE_HOME/corpus" pull --ff-only --progress \
    && ok "corpus copy updated" || note "the corpus copy could not be updated now; the member kit will report it"
else
  run_long "copying the corpus from GitHub" 5 gh repo clone "$ORG/$CORPUS" "$CE_HOME/corpus" -- --progress || stop "could not copy the corpus from GitHub."
  ok "corpus copied to $CE_HOME/corpus"
fi

step "6 of 7 - the member kit (one question comes up here: type y or n, then Return)"
flush_keys
bash "$CE_HOME/corpus/06_scripts_data/fleet_member/install_member.sh" 2>&1 | tee -a "$LOG"
[ "${PIPESTATUS[0]}" = 0 ] || stop "the member kit reported a problem (read the lines above)."

step "7 of 7 - finishing"
cp "$CE_HOME/.ce_member/START_PROMPT.md" "$CE_HOME/START_PROMPT.md" 2>/dev/null
pbcopy < "$CE_HOME/.ce_member/START_PROMPT.md" && ok "the start prompt is on your clipboard"
KIT="$CE_HOME/corpus/06_scripts_data/fleet_member"
MACHINE="$(python3 "$KIT/member_config.py" get machine 2>/dev/null)"
if [ -n "$MACHINE" ] && [ -d "$CE_HOME/work/.git" ]; then
  mkdir -p "$CE_HOME/work/logs/setup/$MACHINE"
  ok "setup record will be saved to your work repository"
  cp "$LOGDIR"/* "$CE_HOME/work/logs/setup/$MACHINE/" 2>/dev/null
  run_long "sending the setup record to GitHub" 2 env CE_MEMBER_HOME="$CE_HOME" bash "$KIT/member_sync.sh" \
    && ok "setup record saved" || note "the setup record will go up with the next hourly sync"
fi
open -a "Claude" 2>/dev/null
open -a "Google Chrome" "https://claude.com/chrome" 2>/dev/null
say ""
say "DONE with the automatic part. Three things left:"
say "  Do them one at a time, in this order. Finish 1 before you start 2: two sign-ins at once"
say "  can get in each other's way."
say "  1. The Claude app opened: sign in with your Capital Energy email (Continue with Google)."
say "     If the sign-in keeps coming back: close extra browser tabs, type your Capital Energy"
say "     email in the \"Enter your email\" box, click Continue with email, and type in the code"
say "     that arrives in your email."
say "  2. Google Chrome opened the Claude in Chrome page (Chrome, not Safari): click Add to Chrome,"
say "     then sign it in with your Capital Energy email."
say "  3. In the Claude app, open the Code tab, choose the folder CapitalEnergy in your home"
say "     folder, click in the message box, press Command-V and Return. The AI takes it from there."
}
# The whole script is read before anything runs (main is called on the last line),
# so no installer below can swallow the rest of it from the pipe.
main "$@"
