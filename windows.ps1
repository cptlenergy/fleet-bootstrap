# Capital Energy fleet bootstrap - Windows. Version: see VERSION in this repository.
# Paste ONE line into Windows PowerShell (the email from M has it):
#   irm https://raw.githubusercontent.com/cptlenergy/fleet-bootstrap/main/windows.ps1 | iex
# It asks Windows for permission once (click Yes), installs the tools and the Linux part
# of Windows (WSL - it may restart the computer once and then carry on by itself after you
# log in), signs you in to GitHub and Claude Code (your browser opens), copies the Capital
# Energy corpus to C:\Users\<you>\CapitalEnergy\corpus and hands over to the member kit.
# It says what it is doing at every step and prints a line at least every 15 seconds while
# anything slow runs. Everything it shows is also written to a setup log, which is copied
# into the person's work repository at the end.
# Safe to run again: it skips whatever is already done. It deletes nothing.
param([int]$Phase = 1)
$ErrorActionPreference = 'Stop'
$BV = '1.0.1'
$Org = 'cptlenergy'; $Corpus = 'Capital_Energy'
$Url = 'https://raw.githubusercontent.com/cptlenergy/fleet-bootstrap/main/windows.ps1'
$State = Join-Path $env:LOCALAPPDATA 'CapitalEnergy'
$Self = Join-Path $State 'bootstrap_windows.ps1'
$LogDir = Join-Path $State 'setup_logs'
$CeHome = Join-Path $env:USERPROFILE 'CapitalEnergy'
$env:WSL_UTF8 = '1'

# The 64-bit Windows PowerShell. Start search often offers "Windows PowerShell (x86)" first;
# a 32-bit PowerShell cannot see wsl.exe, so the set-up always runs in the 64-bit one.
$Is32on64 = [Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess
if ($Is32on64) { $PS64 = Join-Path $env:windir 'sysnative\WindowsPowerShell\v1.0\powershell.exe' }
else           { $PS64 = Join-Path $env:windir 'System32\WindowsPowerShell\v1.0\powershell.exe' }

function Say($t, $color) { if ($color) { Write-Host $t -ForegroundColor $color } else { Write-Host $t } }
function Step($t) { Say ''; Say "==== $t" Cyan }
function Ok($t)   { Say "  OK    $t" }
function Note($t) { Say "  NOTE  $t" Yellow }
# Keys pressed while the set-up was busy (people press Enter again and again when a screen
# looks stuck) must never answer the next question, so every question starts by throwing
# away whatever was typed ahead.
function Flush-Keys { try { $Host.UI.RawUI.FlushInputBuffer() } catch {}; try { while ([Console]::KeyAvailable) { [void][Console]::ReadKey($true) } } catch {} }
function Ask-Enter([string]$t) { Flush-Keys; Read-Host $t | Out-Null }
# For a step that cannot be undone, Enter alone is not an answer: the person types a word.
function Ask-Word([string]$t, [string]$word) {
    while ($true) { Flush-Keys; $a = Read-Host $t; if ($a.Trim().ToLower() -eq $word) { return } ; Say "  Please type the word $word and press Enter." Yellow }
}
function Stop-Here($t) {
    Say ''; Say "STOPPED: $t" Red
    Say 'Nothing is broken. Fix the one thing above, then paste the same line again.'
    Say "The full record of this run is in the folder $LogDir"
    try { Stop-Transcript | Out-Null } catch {}
    try { $script:SetupMutex.ReleaseMutex() } catch {}
    Ask-Enter 'Press Enter to close this window'
    exit 1
}
# Runs a slow command that asks nothing, with its output going to a log file, and prints a
# line every 15 seconds: how long so far, the normal time, and the command's latest line.
function Run-Long([string]$what, [string]$exe, [string]$argList, [int]$normalMin, [int]$try = 1) {
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
    $name = ($what -replace '[^A-Za-z0-9]+', '_').Trim('_')
    $log = Join-Path $LogDir ('{0:yyyyMMdd_HHmmss}_{1}.log' -f (Get-Date), $name)
    Say "  $what - this usually takes up to $normalMin minute(s)."
    Say '        A line appears here every 15 seconds while it works.'
    $p = Start-Process -FilePath $exe -ArgumentList $argList -NoNewWindow -PassThru `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    $null = $p.Handle   # keeps the exit code readable afterwards
    $t0 = Get-Date
    while (-not $p.WaitForExit(15000)) {
        $el = (Get-Date) - $t0
        $last = ''
        foreach ($f in @($log, "$log.err")) {
            if (Test-Path $f) {
                $l = Get-Content -Tail 5 $f -ErrorAction SilentlyContinue |
                     ForEach-Object { ($_ -replace '[^ -~]', ' ' -replace '\s+', ' ').Trim() } |
                     Where-Object { $_.Length -ge 4 } | Select-Object -Last 1
                if ($l) { $last = $l }
            }
        }
        if ($last.Length -gt 60) { $last = $last.Substring(0, 60) + '...' }
        $msg = '    still working: {0} - {1}:{2:00} so far (normal: up to {3} min)' -f $what, [int][Math]::Floor($el.TotalMinutes), $el.Seconds, $normalMin
        if ($last) { $msg += " - $last" }
        Say $msg
        if ($el.TotalMinutes -gt (2 * $normalMin)) { Say '    (slower than normal; a slow internet connection does this. Keep waiting.)' Yellow }
        if ($el.TotalMinutes -gt (4 * $normalMin)) {
            try { Stop-Process -Id $p.Id -Force } catch {}
            if ($try -eq 1) { Say "    $what seems stuck - stopping it and trying once more." Yellow; return (Run-Long $what $exe $argList $normalMin 2) }
            Stop-Here "$what was stuck twice. Close this window and paste the line again (it carries on where it stopped); if it sticks again, tell M."
        }
    }
    $p.WaitForExit()
    $el = (Get-Date) - $t0
    Say ('    finished in {0}:{1:00}' -f [int][Math]::Floor($el.TotalMinutes), $el.Seconds)
    return $p.ExitCode
}
# Runs one command line inside Ubuntu as the user ce, on THIS console (sign-ins can ask
# questions), and returns only its exit code. The command must not contain double quotes.
function Wsl-Ce([string]$cmd) {
    if ($cmd.Contains('"')) { throw "Wsl-Ce: no double quotes allowed in: $cmd" }
    $p = Start-Process -FilePath 'wsl.exe' -NoNewWindow -Wait -PassThru `
        -ArgumentList ('-d Ubuntu -u ce -- bash -lc "' + $cmd + '"')
    return $p.ExitCode
}
function Wsl-Ce-Long([string]$what, [string]$cmd, [int]$normalMin) {
    if ($cmd.Contains('"')) { throw "Wsl-Ce-Long: no double quotes allowed in: $cmd" }
    return (Run-Long $what 'wsl.exe' ('-d Ubuntu -u ce -- bash -lc "' + $cmd + '"') $normalMin)
}
# After a sign-in in the browser, bring this set-up window back to the front by itself, so the
# person never has to find it (first test: "how are you gonna get [him] back to the window?").
# Windows lets a program take the front only in some cases, so: minimise and restore, ask for the
# front, and if Windows refuses, flash the taskbar button and beep.
function Come-Back([string]$what) {
    try {
        Add-Type -Namespace CE -Name Win -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern System.IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr h, int n);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(System.IntPtr h);
[DllImport("user32.dll")] public static extern System.IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, uint f, System.UIntPtr e);
[StructLayout(LayoutKind.Sequential)] public struct FLASHWINFO { public uint cbSize; public System.IntPtr hwnd; public uint dwFlags; public uint uCount; public uint dwTimeout; }
[DllImport("user32.dll")] public static extern bool FlashWindowEx(ref FLASHWINFO f);
'@ -ErrorAction SilentlyContinue
    } catch {}
    try {
        $h = [CE.Win]::GetConsoleWindow()
        [CE.Win]::ShowWindow($h, 6) | Out-Null    # minimise
        [CE.Win]::ShowWindow($h, 9) | Out-Null    # restore
        [CE.Win]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [CE.Win]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
        [CE.Win]::SetForegroundWindow($h) | Out-Null
        if ([CE.Win]::GetForegroundWindow() -ne $h) {
            $f = New-Object CE.Win+FLASHWINFO
            $f.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($f); $f.hwnd = $h; $f.dwFlags = 15; $f.uCount = 0; $f.dwTimeout = 0
            [CE.Win]::FlashWindowEx([ref]$f) | Out-Null
        }
    } catch {}
    try { [Console]::Beep(880, 200); [Console]::Beep(1100, 200) } catch {}
    Say ''
    Say "  >>> $what is done - welcome back to the set-up window. It carries on by itself now. <<<" Green
}
function To-Wsl([string]$winPath) { (& wsl.exe -d Ubuntu -u root -- wslpath -a ($winPath -replace '\\','/')) -join '' }
function Org-State { ((& wsl.exe -d Ubuntu -u ce -- gh api "user/memberships/orgs/$Org" --jq .state 2>$null) -join '').Trim() }

# ---- keep a copy of this script, then make sure we run 64-bit and with administrator rights
New-Item -ItemType Directory -Force -Path $State | Out-Null
if ($PSCommandPath -and (Test-Path $PSCommandPath)) {
    if ($PSCommandPath -ne $Self) { Copy-Item -Force $PSCommandPath $Self }
} else {
    Invoke-RestMethod $Url -OutFile $Self
}
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if ($Is32on64 -or -not $admin) {
    # The set-up moves to a new administrator window; this one says so and closes itself,
    # so exactly one window is on screen (the first test: the window seemed to change by itself).
    Say ''
    Say 'Capital Energy set-up: if Windows asks "Do you want to allow this app to make changes", click Yes.' Yellow
    Say 'The set-up then continues in a NEW window titled "Administrator: Windows PowerShell".' Yellow
    Say 'This window closes by itself in 10 seconds.' Yellow
    Start-Process $PS64 -Verb RunAs -ArgumentList "-NoLogo -NoProfile -ExecutionPolicy Bypass -NoExit -File `"$Self`" -Phase $Phase"
    Start-Sleep -Seconds 10
    exit
}

# A click inside a classic console window starts "Select" mode (the title begins with
# "Select"), and Windows then freezes the program at its next line of output until Esc is
# pressed - measured in the first test, 2026-10-12, as a set-up that looked locked up. So
# this window's selection mode is switched off for this window only (nothing is saved).
try {
    Add-Type -Namespace CE -Name Con -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern System.IntPtr GetStdHandle(int h);
[DllImport("kernel32.dll")] public static extern bool GetConsoleMode(System.IntPtr h, out uint m);
[DllImport("kernel32.dll")] public static extern bool SetConsoleMode(System.IntPtr h, uint m);
'@
    $hIn = [CE.Con]::GetStdHandle(-10); $mode = 0
    if ([CE.Con]::GetConsoleMode($hIn, [ref]$mode)) { [void][CE.Con]::SetConsoleMode($hIn, (($mode -band (-bnot 0x40)) -bor 0x80)) }
} catch {}

$script:SetupMutex = New-Object System.Threading.Mutex($false, 'Local\CapitalEnergyMemberSetup')
if (-not $script:SetupMutex.WaitOne(0)) {
    Say ''
    Say 'The Capital Energy set-up is already running in another window. Use that window.' Yellow
    Say '(Look for the window titled CAPITAL ENERGY SET-UP; this one closes in 15 seconds.)' Yellow
    Start-Sleep -Seconds 15
    exit
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Transcript = Join-Path $LogDir ('{0:yyyyMMdd_HHmmss}_setup_part{1}.txt' -f (Get-Date), $Phase)
try { Start-Transcript -Path $Transcript -Append | Out-Null } catch {}

try { $Host.UI.RawUI.WindowTitle = 'CAPITAL ENERGY SET-UP - watch this window, do not click inside it' } catch {}
Say '=====================================================================' Green
Say '  CAPITAL ENERGY SET-UP - this is the window to watch.' Green
Say '  Do not click inside it. Keep it open until it says DONE.' Green
Say '=====================================================================' Green
Say "Capital Energy - setting up this computer for the AI fleet (bootstrap $BV, part $Phase)"
Say 'About 20 to 40 minutes. Your browser will open for the sign-ins.'
Say 'Keep this window open until it says DONE.'
Say 'While it works it prints a line at least every 15 seconds. When it needs you, it says so'
Say 'and waits. If no new line appears for 2 minutes and it is not waiting for you:'
Say '  1. press Esc once (a click inside the window can pause it);'
Say '  2. still nothing after another minute: close this window and paste the line again -'
Say '     it is safe to repeat and carries on where it stopped.'

if ($Phase -eq 1) {
    Step '1 of 8 - Windows programs (Git, Python, Chrome, the Claude app, Windows Terminal) - about 5 to 15 minutes'
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Stop-Here 'winget (the Windows package installer) is missing. Open the Microsoft Store, search "App Installer", install or update it.'
    }
    $apps = [ordered]@{ 'Git.Git' = 'Git'; 'Python.Python.3.12' = 'Python 3';
                        'Google.Chrome' = 'Google Chrome'; 'Anthropic.Claude' = 'the Claude desktop app';
                        'Microsoft.WindowsTerminal' = 'Windows Terminal' }
    $n = 0
    foreach ($id in $apps.Keys) {
        $n++
        $label = "$($apps[$id]) ($n of $($apps.Count))"
        Say "  checking whether $label is already here..."
        $c = Run-Long "checking for $label" 'winget.exe' "list --id $id -e --accept-source-agreements --disable-interactivity" 1
        if ($c -eq 0) { Ok "$label present"; continue }
        $c = Run-Long "installing $label" 'winget.exe' "install --id $id -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity" 5
        if ($c -eq 0) { Ok "$label installed" }
        else { Note "$label did not install by itself (winget code $c) - the check at the end will say if it matters" }
    }

    Step '2 of 8 - the Linux part of Windows (WSL) - about 2 to 10 minutes'
    & wsl.exe --status *> $null
    if ($LASTEXITCODE -ne 0) {
        [void](Run-Long 'installing WSL' 'wsl.exe' '--install --no-distribution' 10)
        $ro = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
        New-Item -Force -Path $ro | Out-Null
        Set-ItemProperty -Path $ro -Name 'CE Member Setup' -Value "`"$PS64`" -NoProfile -ExecutionPolicy Bypass -File `"$Self`" -Phase 2"
        Say ''
        Say 'Windows must restart once to finish installing WSL.' Yellow
        Say 'After the restart, log in: the set-up opens again by itself (click Yes when Windows asks).'
        try { Stop-Transcript | Out-Null } catch {}
        Ask-Word 'Save anything open in other programs, then type the word restart and press Enter' 'restart'
        Restart-Computer -Force
        return
    }
    Ok 'WSL is ready'
    $Phase = 2
}

if ($Phase -eq 2) {
    Step '3 of 8 - Ubuntu (the Linux system inside Windows) - about 2 to 10 minutes'
    $have = ((& wsl.exe -l -q) -join "`n") -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -eq 'Ubuntu' }
    if (-not $have) {
        $c = Run-Long 'installing Ubuntu' 'wsl.exe' '--install -d Ubuntu --no-launch' 10
        if ($c -ne 0) { Stop-Here 'Ubuntu did not install (wsl --install -d Ubuntu).' }
    }
    & wsl.exe -d Ubuntu -u root -- true *> $null
    if ($LASTEXITCODE -ne 0) {
        $launcher = Get-Command ubuntu.exe, ubuntu2404.exe, ubuntu2204.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($launcher) { [void](Run-Long 'preparing Ubuntu for its first start' $launcher.Source 'install --root' 5) }
        & wsl.exe -d Ubuntu -u root -- true *> $null
        if ($LASTEXITCODE -ne 0) { Stop-Here 'Ubuntu is installed but does not start yet. Open Ubuntu from the Start menu once, create any user it asks for, close it, and paste the line again.' }
    }
    Ok 'Ubuntu runs'

    Step '4 of 8 - Linux tools (git, GitHub, tmux, ttyd, Python) and the user "ce" - about 2 to 8 minutes'
    $prep = @'
set -e
export DEBIAN_FRONTEND=noninteractive
id ce >/dev/null 2>&1 || useradd -m -s /bin/bash ce
echo 'ce ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ce-member && chmod 440 /etc/sudoers.d/ce-member
echo "updating the package lists"
apt-get update -qq
echo "installing git tmux ttyd python3 curl"
apt-get install -y -qq git tmux ttyd python3 curl ca-certificates unzip
if ! command -v gh >/dev/null 2>&1; then
  echo "installing the GitHub command-line tool"
  mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
  chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
  apt-get update -qq && apt-get install -y -qq gh
fi
systemctl disable --now ttyd.service >/dev/null 2>&1 || true
W="[boot]
systemd=true

[user]
default=ce

[automount]
options=metadata
"
if [ "$(cat /etc/wsl.conf 2>/dev/null)" != "$(printf '%s' "$W")" ]; then
  [ -f /etc/wsl.conf ] && cp /etc/wsl.conf /etc/wsl.conf.before_member_kit_$(date +%Y%m%d_%H%M%S)
  printf '%s' "$W" > /etc/wsl.conf
  echo WSLCONF_CHANGED
fi
echo PREP_OK
'@
    $prepFile = Join-Path $State 'wsl_prep.sh'
    [IO.File]::WriteAllText($prepFile, ($prep -replace "`r`n", "`n"))
    [void](Run-Long 'installing the Linux tools' 'wsl.exe' ('-d Ubuntu -u root -- bash ' + (To-Wsl $prepFile)) 8)
    $prepLog = Get-ChildItem $LogDir -Filter '*installing_the_Linux_tools.log' | Sort-Object LastWriteTime | Select-Object -Last 1
    $out = if ($prepLog) { Get-Content -Raw $prepLog.FullName } else { '' }
    if ($out -notmatch 'PREP_OK') { Stop-Here "the Linux tools did not install (the record is $($prepLog.FullName))." }
    if ($out -match 'WSLCONF_CHANGED') { & wsl.exe --terminate Ubuntu *> $null; Start-Sleep -Seconds 3 }
    Ok 'git, gh, tmux, ttyd, python3 installed; user ce ready'

    Step '5 of 8 - Claude Code inside Ubuntu - about 1 to 3 minutes'
    if ((Wsl-Ce 'command -v claude >/dev/null || test -x ~/.local/bin/claude') -ne 0) {
        if ((Wsl-Ce-Long 'installing Claude Code' 'curl -fsSL https://claude.ai/install.sh | bash' 3) -ne 0) { Stop-Here 'Claude Code did not install inside Ubuntu.' }
    }
    Ok 'Claude Code installed for the workers'

    Step '6 of 8 - sign-ins (your browser opens a new tab each time; use your Capital Energy email)'
    # Small helpers inside Ubuntu, made once: ce-open opens a web page in Windows' browser and
    # reports success (explorer.exe reports failure even when the page opened: "Failed opening a
    # web browser ... exit status 1" in the first test); the clipboard bridge; the sign-in check.
    $helpers = Join-Path $State 'ce_helpers.sh'
    [IO.File]::WriteAllText($helpers, @'
set -e
mkdir -p ~/.ce_clip/bin
printf '#!/bin/sh\n/mnt/c/Windows/explorer.exe "$1" >/dev/null 2>&1\nexit 0\n' > ~/.ce_clip/bin/ce-open
printf '#!/bin/sh\ncase "$*" in *-o*|*--output*) exit 1;; esac\nexec /mnt/c/Windows/System32/clip.exe\n' > ~/.ce_clip/bin/ce-clip
for n in xclip xsel wl-copy; do cp ~/.ce_clip/bin/ce-clip ~/.ce_clip/bin/$n; done
cat > ~/.ce_clip/bin/ce-claude-signed-in <<'EOS'
#!/bin/sh
out="$(~/.local/bin/claude auth status --text 2>&1)"
echo "$out" | grep -qi -e 'not logged' -e 'not signed' -e 'no account' && exit 1
echo "$out" | grep -q '@' && exit 0
exit 1
EOS
chmod +x ~/.ce_clip/bin/*
echo HELPERS_OK
'@.Replace("`r`n", "`n"))
    [void](Wsl-Ce ("bash '" + (To-Wsl $helpers) + "'"))
    $browser = 'export BROWSER=~/.ce_clip/bin/ce-open PATH=~/.ce_clip/bin:$PATH'
    if ((Wsl-Ce 'gh auth status >/dev/null 2>&1') -ne 0) {
        # No questions from the GitHub tool (its "Authenticate Git with your GitHub credentials?"
        # confused the first test); the one-time code goes onto the Windows clipboard through a
        # small bridge to clip.exe, and this script opens GitHub's code page itself.
        Say '  GitHub sign-in. In a moment:'
        Say '    1. A browser tab opens on GitHub, asking for a code.'
        Say '    2. The code is already copied for you: click in the first box and press Ctrl+V.'
        Say '    3. Click Continue, then the green Authorize button.'
        Say '  (If GitHub asks you to sign in first: Continue with Google, your Capital Energy email.)'
        Say '  Ignore an orange line about credentials saved in plain text: that is normal here.'
        Say '  (If this window says "Press Enter", press Enter.) This window waits until you finish,'
        Say '  then comes back to the front by itself. If it does not: click the blue icon with >_'
        Say '  in the taskbar at the bottom of the screen.'
        Start-Sleep -Seconds 3
        Flush-Keys
        Start-Process 'https://github.com/login/device'
        if ((Wsl-Ce "$browser WAYLAND_DISPLAY= DISPLAY=:0 GH_PROMPT_DISABLED=1; gh auth login --hostname github.com --git-protocol https --web --clipboard --scopes read:org,user:email") -ne 0) {
            Stop-Here 'the GitHub sign-in did not finish.' }
        Come-Back 'The GitHub sign-in'
    }
    [void](Wsl-Ce 'gh auth setup-git')
    $s = Org-State
    if ($s -eq 'pending') {
        & wsl.exe -d Ubuntu -u ce -- gh api -X PATCH "user/memberships/orgs/$Org" -f state=active *> $null
        $s = Org-State
    }
    $tries = 0
    while ($s -ne 'active' -and $tries -lt 3) {
        $tries++
        Say ''
        Say '  Your GitHub account is not in Capital Energy on GitHub yet. To join:' Yellow
        Say '    1. Open your Capital Energy email (in a browser tab).'
        Say '    2. Find the email from GitHub inviting you to join cptlenergy.'
        Say '       If you cannot see it, search your mailbox for:  cptlenergy'
        Say '    3. Click "Join @cptlenergy" in that email.'
        Say '    4. On the GitHub page that opens, leave "Ask for a GitHub Copilot seat" unticked'
        Say '       and click the green "Join cptlenergy" button.'
        Ask-Enter '  Then come back to this window (the blue icon with >_ in the taskbar) and press Enter'
        $s = Org-State
    }
    if ($s -ne 'active') { Stop-Here "this GitHub account is not in the $Org organization yet. If there is no invitation email from GitHub, tell M: the invitation may not have been sent." }
    Ok "GitHub: member of $Org"
    $a = (Wsl-Ce '~/.ce_clip/bin/ce-claude-signed-in')
    if ($a -ne 0) {
        Say '  Claude Code sign-in (the AI that works in the background on this computer):'
        Say '    1. A browser tab opens. Sign in with your Capital Energy email, click Authorize.'
        Say '    2. The page then shows a long code with a Copy button. Click Copy.'
        Say '    3. Come back to this window (the blue icon with >_ in the taskbar), press Ctrl+V'
        Say '       where it says "Paste code here", then Enter.'
        Flush-Keys
        if ((Wsl-Ce "$browser; ~/.local/bin/claude auth login") -ne 0) { Stop-Here 'the Claude Code sign-in did not finish.' }
        Come-Back 'The Claude Code sign-in'
    }
    Ok 'Claude Code signed in'

    Step '7 of 8 - the Capital Energy corpus (about 60 MB) and the member kit (three privacy questions come up here)'
    New-Item -ItemType Directory -Force -Path $CeHome | Out-Null
    $corpusWin = Join-Path $CeHome 'corpus'
    $corpusWsl = To-Wsl $corpusWin
    if ((Test-Path (Join-Path $corpusWin '.git')) -and ((Wsl-Ce "git -C '$corpusWsl' rev-parse --verify -q HEAD >/dev/null") -ne 0)) {
        $aside = "$corpusWin`_incomplete_$(Get-Date -Format yyyyMMdd_HHmmss)"
        Move-Item -LiteralPath $corpusWin -Destination $aside
        Note "an unfinished corpus copy from an earlier run was moved aside to $aside; copying it again"
    }
    if (Test-Path (Join-Path $corpusWin '.git')) {
        if ((Wsl-Ce-Long 'updating the corpus copy from GitHub' "git -C '$corpusWsl' pull --ff-only --progress" 3) -eq 0) { Ok "corpus copy updated ($corpusWin)" }
        else { Note 'the corpus copy could not be updated now; the member kit check will report it' }
    } else {
        if ((Wsl-Ce-Long 'copying the corpus from GitHub' "gh repo clone $Org/$Corpus '$corpusWsl' -- --progress" 5) -ne 0) { Stop-Here 'could not copy the corpus from GitHub.' }
        Ok "corpus copied to $corpusWin"
    }
    $kitWsl = "$corpusWsl/06_scripts_data/fleet_member"
    Flush-Keys
    if ((Wsl-Ce "bash '$kitWsl/install_member.sh'") -ne 0) { Stop-Here 'the member kit reported a problem (read the lines above).' }
    Say '  starting the background services (the hourly sync and the browser terminal)...'
    $r = (& wsl.exe -d Ubuntu -u root -- bash "$kitWsl/wsl/root_setup.sh") -join "`n"
    Say $r
    if ($r -notmatch 'ROOT_SETUP_OK') { Stop-Here 'the background services did not start (read the lines above).' }

    Step '8 of 8 - finishing on the Windows side'
    $kitWin = Join-Path $corpusWin '06_scripts_data\fleet_member'
    & $PS64 -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kitWin 'wsl\windows_finish.ps1') -KitDir $kitWin
    $sp = Join-Path $CeHome '.ce_member\START_PROMPT.md'
    if (Test-Path $sp) {
        Copy-Item -Force $sp (Join-Path $CeHome 'START_PROMPT.md')
        Get-Content -Raw $sp | Set-Clipboard
        Ok 'the start prompt is on your clipboard'
    }
    $claudeExe = Join-Path $env:LOCALAPPDATA 'AnthropicClaude\claude.exe'
    if (Test-Path $claudeExe) { Start-Process $claudeExe }

    # The setup record goes into the work repository, so M's sessions can read what happened.
    try { Stop-Transcript | Out-Null } catch {}
    $machine = ((& wsl.exe -d Ubuntu -u ce -- python3 "$kitWsl/member_config.py" get machine) -join '').Trim()
    if ($machine -and (Test-Path (Join-Path $CeHome 'work\.git'))) {
        $dest = Join-Path $CeHome "work\logs\setup\$machine"
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        Copy-Item -Force (Join-Path $LogDir '*') $dest
        [void](Wsl-Ce-Long 'sending the setup record to GitHub' "bash '$kitWsl/member_sync.sh'" 2)
        Ok 'setup record saved to your work repository'
    }
    try { $script:SetupMutex.ReleaseMutex() } catch {}
    Say ''
    Say 'DONE with the automatic part. Three things left:' Green
    Say '  1. The Claude app opened: sign in with your Capital Energy email (Continue with Google).'
    Say '  2. Google Chrome opened the Claude in Chrome page (Chrome, not Edge): click Add to Chrome,'
    Say '     then sign it in with your Capital Energy email.'
    Say "  3. In the Claude app, open the Code tab, choose the folder $CeHome,"
    Say '     click in the message box, press Ctrl+V and Enter. The AI takes it from there.'
}
