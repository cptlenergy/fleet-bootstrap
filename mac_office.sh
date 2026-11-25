#!/bin/bash
# Capital Energy OFFICE COMPUTER bootstrap - a Mac that belongs to the company and is run by M's AI
# (a plain fleet Mac, run like the hub: one company account that several people use, their own AIs in their
# own Chrome profiles, the company's Claude seats as builders). Version 0.2.0, 2026-11-25 (0.1.0 the day
# before, never run). Written for Jason's old laptop rebuilt as CE-Office-Macpro (account CEOffice) on M's
# rulings of 2026-11-24 09:59-10:16 and 2026-11-25 03:01-03:53 PST. Not yet run on any Mac.
#
# Paste ONE line into Terminal, in the CEOffice account, right after macOS is freshly set up:
#   curl -fsSL https://raw.githubusercontent.com/cptlenergy/fleet-bootstrap/main/mac_office.sh | bash
#
# It does, in order:
#   A. Homebrew; Jump Desktop Connect (M signs it in with HIS account, so he sees this screen);
#      Tailscale (joins the company network under M's login - M signs it in, or pastes a pre-made
#      Tailscale auth key when this script asks).
#   B. Chrome, the Claude app, Google Drive, git, gh, tmux, ttyd, Claude Code. No sign-ins here:
#      M's AI does those later through the screen and the terminal.
#   POWER. The fleet's desk mode: the Mac never sleeps (lid closed or idle), the display goes off after
#      10 minutes, wake-on-LAN on - the same settings as Ms-MacBook-Pro and the hub.
#   C. This Mac's SSH key and a DOORWAY terminal on the company network, so M's AI can reach this Mac
#      from anywhere without Jump. Then it stops and says so: M lets this Mac in at the hub (one line),
#      and M's AI finishes from the doorway - the company corpus, the nightly jobs, the permanent
#      recorded terminal, the Chrome profiles and the sign-ins (office_fleet_join.sh, inside the corpus).
# Safe to run again at any time: it skips whatever is done and carries on where it stopped.
# It deletes nothing. No password, key or customer information is in this file.
set -u
KEY="$HOME/.ssh/id_ed25519"
LOGDIR="$HOME/Library/Logs/CapitalEnergy"; mkdir -p "$LOGDIR"
LOG="$LOGDIR/$(date +%Y%m%d_%H%M%S)_office_setup.txt"
say() { echo "$*"; echo "$*" >> "$LOG"; }
step() { say ""; say "======== $*"; }
ok() { say "  OK    $*"; }
note() { say "  NOTE  $*"; }
stop() { say ""; say "STOPPED: $*"; say "Nothing is broken. Fix the one thing above, then paste the same line again."; say "If you are not sure, send M a photo of this window. The record of this run is in $LOGDIR"; exit 1; }
flush_keys() { while read -r -t 0.05 -n 1000 _ < /dev/tty 2>/dev/null; do :; done; }
pause() { flush_keys; printf "  %s" "$1" > /dev/tty; read -r _ < /dev/tty; }
ask() { flush_keys; printf "  %s" "$1" > /dev/tty; IFS= read -r REPLY < /dev/tty; }
TSC="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
ts_ip() { [ -x "$TSC" ] && "$TSC" ip -4 2>/dev/null | head -1; }

# keep_sudo (from mac_fleet.sh 1.0.15): the Mac forgets the password after about 5 minutes.
KEEP_PID=""
keep_sudo() {
  [ -n "$KEEP_PID" ] && kill -0 "$KEEP_PID" 2>/dev/null && return 0
  ( while kill -0 $$ 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
  KEEP_PID=$!
}
need_sudo() { sudo -n true 2>/dev/null || { say "  This Mac's password (nothing shows while you type), then Return."; sudo -v < /dev/tty || stop "the password was not accepted."; }; keep_sudo; }
brew_env() { for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)" && return 0; done; return 1; }
install_cask() { # name, app path, minutes
  [ -d "$2" ] && { ok "$1 present"; return 0; }
  say "  Installing $1 (usually 1 to $3 minutes; its own messages show below)."
  say "  IF YOU SEE \"Password:\" - type this Mac's password (nothing shows while you type), then Return."
  if brew install --cask "$1" < /dev/tty 2>&1 | tee -a "$LOG"; [ "${PIPESTATUS[0]}" = 0 ]; then ok "$1 installed"
  else note "$1 did not install by itself - M's AI installs it later; the set-up carries on"; fi
}

main() {
trap '[ -n "$KEEP_PID" ] && kill "$KEEP_PID" 2>/dev/null' EXIT
say "Capital Energy - setting up this Mac as the OFFICE COMPUTER (run by M's AI; used by the team)."
say "Parts A, POWER, B and C. Part A needs M's sign-ins (Jump Desktop, Tailscale). At the end it hands over to M's AI."
say "Keep this window open. If it stops, paste the same line again."
[ "$(uname -s)" = Darwin ] || stop "this is for a Mac."
MAJ="$(sw_vers -productVersion | cut -d. -f1)"
[ "$MAJ" -ge 13 ] 2>/dev/null || stop "this Mac runs macOS $(sw_vers -productVersion); it needs macOS 13 or newer."
say "  account: $(whoami)   computer: $(hostname -s)   macOS $(sw_vers -productVersion)"
[ "$(whoami)" = "CEOffice" ] || note "the account is '$(whoami)', not CEOffice (M chose CEOffice, 2026-11-24). Carrying on; tell M."

step "PART A (1 of 4) - Homebrew, the Mac's package installer"
if ! brew_env; then
  say "  Installing it (about 5 minutes; its own messages scroll past below)."
  need_sudo
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" < /dev/null 2>&1 | tee -a "$LOG"
  brew_env || stop "Homebrew did not install."
  grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null || echo "eval \"\$($(command -v brew) shellenv)\"" >> "$HOME/.zprofile"
fi
ok "Homebrew ready"

step "PART A (2 of 4) - Jump Desktop Connect and Tailscale"
# Cask names read with 'brew info --cask' on Ms-MacBook-Pro, 2026-11-21: jump-desktop-connect, tailscale-app.
need_sudo
install_cask jump-desktop-connect "/Applications/Jump Desktop Connect.app" 4
install_cask tailscale-app "/Applications/Tailscale.app" 4

step "PART A (3 of 4) - Jump Desktop Connect: M's screen access"
if [ -d "/Applications/Jump Desktop Connect.app" ]; then
  open -a "Jump Desktop Connect" 2>/dev/null
  say "  Jump Desktop Connect has opened (look in the Dock if you cannot see it)."
  say "    1. Click \"Add a remote access user\" and sign in with M's Jump Desktop account (M types it,"
  say "       at the keyboard or by phone; this is an office computer, so it is M's account, not yours)."
  say "    2. macOS asks to allow it: switch Jump Desktop Connect ON for Screen Recording and for"
  say "       Accessibility (System Settings > Privacy & Security), and Remote Desktop if asked."
  say "       If the Screen Recording list is empty: quit Jump Desktop Connect and open it again."
  say "    3. Missed one? Jump Desktop Connect > Settings > Diagnostics > Check macOS Permissions."
  pause "When Jump is signed in, press Return here (or press Return now and do it afterwards). "
  ok "carrying on"
else note "Jump Desktop Connect is not installed yet - M's AI installs it later"; fi

step "PART A (4 of 4) - Tailscale: the company's private network, under M's login"
if [ -n "$(ts_ip)" ]; then ok "Tailscale is signed in ($(ts_ip))"
elif [ -d "/Applications/Tailscale.app" ]; then
  open -a Tailscale 2>/dev/null
  say "  Tailscale has opened: its icon is in the menu bar at the top right of the screen."
  say "    If macOS asks to allow a VPN configuration or a system extension: Allow."
  say "    (Clicked Don't Allow? Click the Tailscale icon > Quit, open Tailscale again: it asks again.)"
  say "  Two ways to sign it in - M chooses:"
  say "    a) M clicks the Tailscale icon > Log in > Sign in with Google > the company AI account (M knows which)."
  say "    b) M made an auth key in the Tailscale admin page (Settings > Keys): paste it here."
  ask "Paste the auth key and press Return, or just press Return to use way (a): "
  if [ -n "$REPLY" ]; then
    # The Tailscale app's own command line. Untested on the Mac App Store build; tested nowhere yet.
    "$TSC" up --auth-key="$REPLY" --accept-routes 2>&1 | tee -a "$LOG" || note "the auth key was not accepted - use way (a)"
    unset REPLY
  fi
  until [ -n "$(ts_ip)" ]; do
    pause "When Tailscale says Connected, press Return here. "
  done
  ok "Tailscale is signed in ($(ts_ip))"
else note "Tailscale is not installed yet - M's AI installs it later; Part C will wait for it"; fi

step "POWER - desk mode: never sleeps, display off after 10 minutes (as Ms-MacBook-Pro and the hub)"
# The recipe of ce_power_desk_mode.command (corpus root, 2026-08-11; Machine_Environment_Capital_Energy_v2.md section 5).
need_sudo
if pmset -g 2>/dev/null | grep -q "SleepDisabled.*1"; then ok "already in desk mode"
else
  sudo pmset -a disablesleep 1 && sudo pmset -a displaysleep 10 && sudo pmset -a disksleep 0 && sudo pmset -a powernap 0 \
    && sudo pmset -a hibernatemode 0 && sudo pmset -c sleep 0 && sudo pmset -a womp 1 \
    && ok "desk mode set (the 'Disk sleep should be non-zero' advisory is pmset's standard text)" \
    || note "could not set every power setting - M's AI runs ce_power_desk_mode.command later"
fi
note "Screen lock and FileVault are M's choices (the hub: FileVault on, CE_AuthRestart.command for remote restarts) - not changed here."

step "PART B - Chrome, the Claude app, Google Drive, the tools, Claude Code (no sign-ins here)"
brew_env || stop "Homebrew is not on this account's PATH."
need_sudo
for t in git gh tmux ttyd python3; do
  command -v "$t" >/dev/null 2>&1 && ok "$t present" || { say "  Installing $t"; brew install "$t" < /dev/null 2>&1 | tail -3 | tee -a "$LOG"; command -v "$t" >/dev/null 2>&1 || stop "Homebrew could not install $t."; }
done
install_cask google-chrome "/Applications/Google Chrome.app" 5
install_cask claude "/Applications/Claude.app" 5
install_cask google-drive "/Applications/Google Drive.app" 5
if ! command -v claude >/dev/null 2>&1; then
  say "  Installing Claude Code (Anthropic's command-line program)."
  bash -c 'curl -fsSL https://claude.ai/install.sh | bash' 2>&1 | tail -3 | tee -a "$LOG"
  export PATH="$HOME/.local/bin:$PATH"
  command -v claude >/dev/null 2>&1 && ok "Claude Code $(claude --version 2>/dev/null | head -n 1)" || note "Claude Code is not on PATH yet - M's AI finishes it"
else ok "Claude Code $(claude --version 2>/dev/null | head -n 1)"; fi
note "Sign-ins (Chrome, the Claude app, Google Drive, Claude Code, gh) are M's AI's, later, through Jump and the terminal."

step "PART C (1 of 2) - this Mac's key (so the hub never asks it for a password)"
[ -n "$(ts_ip)" ] || stop "Tailscale is not signed in (Part A). Part C needs the company network."
if [ ! -f "$KEY.pub" ]; then
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -N "" -C "$(whoami)@$(hostname -s)" -f "$KEY" >/dev/null 2>&1
  [ -f "$KEY.pub" ] || stop "could not make the key."
  ok "key made - the secret half stays on this Mac and never moves"
else ok "key already here - using it"; fi
FP="$(ssh-keygen -lf "$KEY.pub" 2>/dev/null | awk '{print $2}')"
say "  its fingerprint: $FP"
say "  its public half (M's AI reads this from the doorway terminal below; a photo of this window also works):"
say "  $(cat "$KEY.pub")"

step "PART C (2 of 2) - the DOORWAY: a terminal on the company network, so M's AI can finish from anywhere"
# ttyd serves this shell as a web page on this Mac only (port 7681, loopback); 'tailscale serve' republishes it to the
# company network only. The permanent, recorded terminal (CE_Terminal_Setup.command) replaces this doorway when
# M's AI runs office_fleet_join.sh from the corpus.
if ! pgrep -x ttyd >/dev/null 2>&1; then
  nohup ttyd -p 7681 -i 127.0.0.1 -W zsh -l > "$LOGDIR/doorway_ttyd.log" 2>&1 &
  sleep 2
  pgrep -x ttyd >/dev/null 2>&1 && ok "doorway terminal running on this Mac" || note "the doorway terminal did not start (record: $LOGDIR/doorway_ttyd.log)"
else ok "a terminal is already running on this Mac"; fi
if "$TSC" serve status 2>/dev/null | grep -q 7681; then ok "already published to the company network"
else
  say "  Publishing it to the company network (Tailscale may ask for this Mac's password or an admin click)."
  "$TSC" serve --bg 7681 < /dev/tty 2>&1 | tail -3 | tee -a "$LOG" && ok "published to the company network (its address is this Mac's name on the network; M's AI knows it)" \
    || note "could not publish the doorway - M's AI reaches this Mac through Jump instead"
fi

{ echo "office bootstrap finished $(date '+%Y-%m-%d %H:%M %Z') on $(hostname -s) as $(whoami): key $FP"; } >> "$LOG"
say ""
say "PARTS A, POWER, B AND C ARE DONE. Tell M: \"office ready for the key\" (fingerprint $FP)."
say "From here M's AI finishes through the doorway: M lets this Mac in at the hub (one line on the hub), then the AI"
say "copies the company corpus, installs the nightly jobs and the permanent recorded terminal, the Chrome profiles"
say "and the sign-ins (office_fleet_join.sh, inside the corpus). Nothing more to do in this window; leave it open."
say "The record of this run: $LOG"
}
main "$@"
