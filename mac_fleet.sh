#!/bin/bash
# Capital Energy fleet bootstrap - a Mac that is BOTH a core-fleet Mac and its person's own
# (a partner's laptop: Jason's). Version: see VERSION in this repository (first in 1.0.14).
# Paste ONE line into Terminal (the email from M has it):
#   curl -fsSL https://raw.githubusercontent.com/cptlenergy/fleet-bootstrap/main/mac_fleet.sh | bash
#
# It does, in order:
#   A. Homebrew, then Jump Desktop Connect (so M can see this screen and help) and Tailscale
#      (the company's private network). It opens Jump Desktop Connect for you to sign in.
#   B. the ordinary Capital Energy set-up (mac.sh in this repository): the tools, Chrome, the Claude
#      app, Google Drive, your GitHub and Claude Code sign-ins, your own workspace ~/CapitalEnergy.
#   C. the company (fleet) corpus in ~/Cowork/Capital_Energy and the CE Remote Access buttons
#      (member_fleet_join.sh, inside the corpus). Part C needs M once: he lets this Mac in at the
#      hub. The window says when it is waiting for him. (Tailscale is signed in by the person, in
#      Part A, with their own Capital Energy Google account.)
# Safe to run again at any time: it skips whatever is done and carries on where it stopped.
# It deletes nothing. No password, key or customer information is in this file.
set -u
RAW="https://raw.githubusercontent.com/cptlenergy/fleet-bootstrap/main"
CE_HOME="$HOME/CapitalEnergy"
LOGDIR="$HOME/Library/Logs/CapitalEnergy"; mkdir -p "$LOGDIR"
LOG="$LOGDIR/$(date +%Y%m%d_%H%M%S)_fleet_setup.txt"
say() { echo "$*"; echo "$*" >> "$LOG"; }
step() { say ""; say "======== $*"; }
ok() { say "  OK    $*"; }
note() { say "  NOTE  $*"; }
stop() { say ""; say "STOPPED: $*"; say "Nothing is broken. Fix the one thing above, then paste the same line again."; say "If you are not sure, send M a photo of this window. The record of this run is in $LOGDIR"; exit 1; }
flush_keys() { while read -r -t 0.05 -n 1000 _ < /dev/tty 2>/dev/null; do :; done; }
pause() { flush_keys; printf "  %s" "$1" > /dev/tty; read -r _ < /dev/tty; }
# quiet_long "what" <normal minutes> command...: a slow command that asks nothing; a line every 15 s.
quiet_long() {
  local what="$1" normal="$2"; shift 2
  local f="$LOGDIR/$(date +%Y%m%d_%H%M%S)_$(echo "$what" | tr -cs 'A-Za-z0-9' '_').log"
  say "  $what - usually up to $normal minute(s). A line appears every 15 seconds while it works."
  "$@" > "$f" 2>&1 < /dev/null &
  local pid=$! t0=$SECONDS n=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep 1; n=$((n+1))
    [ $((n % 15)) = 0 ] && kill -0 "$pid" 2>/dev/null && say "    still working: $what - $(( (SECONDS - t0) / 60 )):$(printf %02d $(( (SECONDS - t0) % 60 ))) so far"
  done
  wait "$pid"; local rc=$?
  [ "$rc" = 0 ] || { echo "    ($what failed with code $rc; its last lines:)" >> "$LOG"; tail -n 20 "$f" 2>/dev/null | sed 's/^/    | /' >> "$LOG"; }
  return $rc
}

main() {
say "Capital Energy - setting up this Mac: your own workspace AND the company's (fleet set-up)"
say "Three parts. Parts A and B you can do on your own (about 30 to 45 minutes, mostly waiting)."
say "Part C waits for M once (it says when). Keep this window open. If it stops, paste the same line again."
[ "$(uname -s)" = Darwin ] || stop "this is for a Mac."
MAJ="$(sw_vers -productVersion | cut -d. -f1)"
[ "$MAJ" -ge 13 ] 2>/dev/null || stop "this Mac runs macOS $(sw_vers -productVersion); it needs macOS 13 or newer (Apple menu > System Settings > General > Software Update)."

step "PART A (1 of 3) - Homebrew, the Mac's package installer"
for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)" && break; done
if ! command -v brew >/dev/null 2>&1; then
  say "  Installing it (about 5 minutes; its own messages scroll past below)."
  say "  Type this Mac's password when asked (NOTHING SHOWS while you type - that is normal), then press Return."
  sudo -v < /dev/tty || stop "the password was not accepted."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" < /dev/null 2>&1 | tee -a "$LOG"
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)" && break; done
  command -v brew >/dev/null 2>&1 || stop "Homebrew did not install."
  grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null || echo "eval \"\$($(command -v brew) shellenv)\"" >> "$HOME/.zprofile"
fi
ok "Homebrew ready"

step "PART A (2 of 3) - Jump Desktop Connect and Tailscale"
# Cask names read with 'brew info --cask' on Ms-MacBook-Pro, 2026-11-21: jump-desktop-connect
# (10.15.28) and tailscale-app (1.104.7).
NEED=""
[ -d "/Applications/Jump Desktop Connect.app" ] && ok "Jump Desktop Connect present" || NEED="$NEED jump-desktop-connect"
[ -d "/Applications/Tailscale.app" ] && ok "Tailscale present" || NEED="$NEED tailscale-app"
if [ -n "$NEED" ]; then
  say "  These installers need this Mac's password (nothing shows while you type), then Return."
  sudo -v < /dev/tty || stop "the password was not accepted."
  for c in $NEED; do
    sudo -v < /dev/tty 2>/dev/null
    quiet_long "installing $c" 4 brew install --cask "$c" && ok "$c installed" || note "$c did not install by itself - M installs it with you; the set-up carries on"
  done
fi

step "PART A (3 of 3) - sign in to Jump Desktop Connect (this lets M see your screen and help)"
if [ -d "/Applications/Jump Desktop Connect.app" ]; then
  open -a "Jump Desktop Connect" 2>/dev/null
  say "  Jump Desktop Connect has opened (look in the Dock if you cannot see it)."
  say "    1. Click \"Add a remote access user\" and sign in with YOUR OWN Jump Desktop account."
  say "    2. macOS asks to allow it: switch Jump Desktop Connect ON for Screen Recording and for"
  say "       Accessibility (System Settings > Privacy & Security), and Remote Desktop if asked."
  say "       Only you can flip these switches; type this Mac's password if it asks."
  say "    3. Missed one? Jump Desktop Connect > Settings > Diagnostics > Check macOS Permissions."
  pause "When Jump is signed in, press Return here (or press Return now and do it afterwards). "
  ok "carrying on"
else note "Jump Desktop Connect is not installed yet - M installs it with you"; fi

step "PART A (extra) - sign in to Tailscale (the company's private network)"
TSC="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
if [ -x "$TSC" ] && [ -n "$("$TSC" ip -4 2>/dev/null | head -1)" ]; then ok "Tailscale is signed in"
elif [ -d "/Applications/Tailscale.app" ]; then
  open -a Tailscale 2>/dev/null
  say "  Tailscale has opened: its icon is in the menu bar at the top right of the screen."
  say "    1. If macOS asks to allow a VPN configuration or a system extension: Allow."
  say "    2. Click the Tailscale icon, choose Log in, then Sign in with Google, and use your"
  say "       Capital Energy email - the same sign-in as on your old laptop."
  say "    3. If it says this computer needs approval, text M; carry on here meanwhile."
  pause "When Tailscale says Connected, press Return here (or press Return now and do it afterwards). "
  ok "carrying on"
else note "Tailscale is not installed yet - M installs it with you"; fi

step "PART B - the Capital Energy set-up (your own workspace). It counts its own steps, 1 to 7."
T="$(mktemp -d)"
curl -fsSL "$RAW/mac.sh" -o "$T/mac.sh" || stop "could not download the set-up from GitHub (is the internet working?)."
bash "$T/mac.sh"; B=$?
[ "$B" = 0 ] || stop "the Capital Energy set-up stopped (its own lines above say why). Paste the same line again once that is fixed."
for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)" && break; done
export PATH="$HOME/.local/bin:$PATH"

step "PART C - the company corpus and the CE Remote Access buttons (with M)"
J="$CE_HOME/corpus/06_scripts_data/fleet_member/member_fleet_join.sh"
[ -f "$J" ] || stop "the fleet step is not in this corpus copy yet ($J). Tell M."
bash "$J" 2>&1 | tee -a "$LOG"; C="${PIPESTATUS[0]}"
say ""
if [ "$C" = 0 ]; then
  say "ALL THREE PARTS DONE. The four sign-ins listed above (Claude app, Claude in Chrome, Google Drive,"
  say "your first chat) are still yours to do, one at a time. M tells you when to press CE Remote Access ON."
elif [ "$C" = 3 ]; then
  say "PARTS A AND B ARE DONE. Part C is waiting for M (the line above says for what)."
  say "Text M. When he is ready, paste the same line again: it skips what is done and finishes Part C."
else
  stop "Part C reported a problem (the lines above say what)."
fi
}
# The whole script is read before anything runs (main is called on the last line).
main "$@"
