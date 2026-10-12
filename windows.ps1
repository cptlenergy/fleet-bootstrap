# Capital Energy fleet bootstrap - Windows. Version: see VERSION in this repository.
# Paste ONE line into PowerShell (the email from M has it):
#   irm https://raw.githubusercontent.com/cptlenergy/fleet-bootstrap/main/windows.ps1 | iex
# It asks Windows for permission once (click Yes), installs the tools and the Linux part
# of Windows (WSL - it may restart the computer once and then carry on by itself after you
# log in), signs you in to GitHub and Claude Code (your browser opens), copies the Capital
# Energy corpus to C:\Users\<you>\CapitalEnergy\corpus and hands over to the member kit.
# Safe to run again: it skips whatever is already done. It deletes nothing.
param([int]$Phase = 1)
$ErrorActionPreference = 'Stop'
$BV = '1.0.0'
$Org = 'cptlenergy'; $Corpus = 'Capital_Energy'
$Url = 'https://raw.githubusercontent.com/cptlenergy/fleet-bootstrap/main/windows.ps1'
$State = Join-Path $env:LOCALAPPDATA 'CapitalEnergy'
$Self = Join-Path $State 'bootstrap_windows.ps1'
$CeHome = Join-Path $env:USERPROFILE 'CapitalEnergy'
$env:WSL_UTF8 = '1'

function Step($t) { Write-Host ''; Write-Host "==== $t" -ForegroundColor Cyan }
function Ok($t)   { Write-Host "  OK    $t" }
function Note($t) { Write-Host "  NOTE  $t" -ForegroundColor Yellow }
function Stop-Here($t) {
    Write-Host ''; Write-Host "STOPPED: $t" -ForegroundColor Red
    Write-Host 'Nothing is broken. Fix the one thing above, then paste the same line again.'
    Read-Host 'Press Enter to close this window' | Out-Null
    exit 1
}
# Runs one command line inside Ubuntu as the user ce, on THIS console (sign-ins can ask
# questions), and returns only its exit code. The command must not contain double quotes.
function Wsl-Ce([string]$cmd) {
    if ($cmd.Contains('"')) { throw "Wsl-Ce: no double quotes allowed in: $cmd" }
    $p = Start-Process -FilePath 'wsl.exe' -NoNewWindow -Wait -PassThru `
        -ArgumentList ('-d Ubuntu -u ce -- bash -lc "' + $cmd + '"')
    return $p.ExitCode
}
function To-Wsl([string]$winPath) { (& wsl.exe -d Ubuntu -u root -- wslpath -a ($winPath -replace '\\','/')) -join '' }

# ---- keep a copy of this script, then make sure we run with administrator rights ------
New-Item -ItemType Directory -Force -Path $State | Out-Null
if ($PSCommandPath -and (Test-Path $PSCommandPath)) {
    if ($PSCommandPath -ne $Self) { Copy-Item -Force $PSCommandPath $Self }
} else {
    Invoke-RestMethod $Url -OutFile $Self
}
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Write-Host 'Windows will ask for permission to make changes: click Yes.'
    Write-Host 'A new blue window opens - the set-up continues there.'
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$Self`" -Phase $Phase"
    return
}

Write-Host "Capital Energy - setting up this computer for the AI fleet (bootstrap $BV, part $Phase)"
Write-Host 'About 20 to 40 minutes. Your browser will open for three sign-ins.'
Write-Host 'Keep this window open until it says DONE.'

if ($Phase -eq 1) {
    Step '1 of 8 - Windows programs (Git, Python, Chrome, the Claude app, Windows Terminal)'
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Stop-Here 'winget (the Windows package installer) is missing. Open the Microsoft Store, search "App Installer", install or update it.'
    }
    $apps = [ordered]@{ 'Git.Git' = 'Git'; 'Python.Python.3.12' = 'Python 3';
                        'Google.Chrome' = 'Google Chrome'; 'Anthropic.Claude' = 'the Claude desktop app';
                        'Microsoft.WindowsTerminal' = 'Windows Terminal' }
    foreach ($id in $apps.Keys) {
        & winget.exe list --id $id -e --accept-source-agreements *> $null
        if ($LASTEXITCODE -eq 0) { Ok "$($apps[$id]) present"; continue }
        & winget.exe install --id $id -e --silent --accept-package-agreements --accept-source-agreements *> $null
        if ($LASTEXITCODE -eq 0) { Ok "$($apps[$id]) installed" }
        else { Note "$($apps[$id]) did not install by itself (winget code $LASTEXITCODE) - the check at the end will say if it matters" }
    }

    Step '2 of 8 - the Linux part of Windows (WSL)'
    & wsl.exe --status *> $null
    if ($LASTEXITCODE -ne 0) {
        & wsl.exe --install --no-distribution
        $ro = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
        New-Item -Force -Path $ro | Out-Null
        Set-ItemProperty -Path $ro -Name 'CE Member Setup' -Value "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Self`" -Phase 2"
        Write-Host ''
        Write-Host 'Windows must restart once to finish installing WSL.' -ForegroundColor Yellow
        Write-Host 'After the restart, log in: the set-up opens again by itself (click Yes when Windows asks).'
        Read-Host 'Save anything open in other programs, then press Enter to restart now' | Out-Null
        Restart-Computer -Force
        return
    }
    Ok 'WSL is ready'
    $Phase = 2
}

if ($Phase -eq 2) {
    Step '3 of 8 - Ubuntu (the Linux system inside Windows)'
    $have = ((& wsl.exe -l -q) -join "`n") -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -eq 'Ubuntu' }
    if (-not $have) {
        & wsl.exe --install -d Ubuntu --no-launch
        if ($LASTEXITCODE -ne 0) { Stop-Here 'Ubuntu did not install (wsl --install -d Ubuntu).' }
    }
    & wsl.exe -d Ubuntu -u root -- true *> $null
    if ($LASTEXITCODE -ne 0) {
        $launcher = Get-Command ubuntu.exe, ubuntu2404.exe, ubuntu2204.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($launcher) { & $launcher.Source install --root }
        & wsl.exe -d Ubuntu -u root -- true *> $null
        if ($LASTEXITCODE -ne 0) { Stop-Here 'Ubuntu is installed but does not start yet. Open Ubuntu from the Start menu once, create any user it asks for, close it, and paste the line again.' }
    }
    Ok 'Ubuntu runs'

    Step '4 of 8 - Linux tools (git, GitHub, tmux, ttyd, Python) and the user "ce"'
    $prep = @'
set -e
export DEBIAN_FRONTEND=noninteractive
id ce >/dev/null 2>&1 || useradd -m -s /bin/bash ce
echo 'ce ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ce-member && chmod 440 /etc/sudoers.d/ce-member
apt-get update -qq
apt-get install -y -qq git tmux ttyd python3 curl ca-certificates unzip >/dev/null
if ! command -v gh >/dev/null 2>&1; then
  mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
  chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
  apt-get update -qq && apt-get install -y -qq gh >/dev/null
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
    $out = (& wsl.exe -d Ubuntu -u root -- bash (To-Wsl $prepFile)) -join "`n"
    if ($out -notmatch 'PREP_OK') { Write-Host $out; Stop-Here 'the Linux tools did not install (see the lines above).' }
    if ($out -match 'WSLCONF_CHANGED') { & wsl.exe --terminate Ubuntu *> $null; Start-Sleep -Seconds 3 }
    Ok 'git, gh, tmux, ttyd, python3 installed; user ce ready'

    Step '5 of 8 - Claude Code inside Ubuntu'
    if ((Wsl-Ce 'command -v claude >/dev/null || test -x ~/.local/bin/claude') -ne 0) {
        if ((Wsl-Ce 'curl -fsSL https://claude.ai/install.sh | bash >/dev/null 2>&1') -ne 0) { Stop-Here 'Claude Code did not install inside Ubuntu.' }
    }
    Ok 'Claude Code installed for the workers'

    Step '6 of 8 - sign-ins (your browser opens; use your Capital Energy email each time)'
    $browser = 'export BROWSER=/mnt/c/Windows/explorer.exe'
    if ((Wsl-Ce 'gh auth status >/dev/null 2>&1') -ne 0) {
        Write-Host '  GitHub: below you will see a one-time code. Press Enter, then type that code in the browser and approve.'
        if ((Wsl-Ce "$browser; gh auth login --hostname github.com --git-protocol https --web --scopes read:org,user:email") -ne 0) {
            Stop-Here 'the GitHub sign-in did not finish.' }
    }
    [void](Wsl-Ce 'gh auth setup-git')
    $s = (& wsl.exe -d Ubuntu -u ce -- gh api "user/memberships/orgs/$Org" --jq .state 2>$null) -join ''
    if ($s -eq 'pending') {
        & wsl.exe -d Ubuntu -u ce -- gh api -X PATCH "user/memberships/orgs/$Org" -f state=active *> $null
        $s = (& wsl.exe -d Ubuntu -u ce -- gh api "user/memberships/orgs/$Org" --jq .state 2>$null) -join ''
    }
    if ($s -ne 'active') {
        Write-Host '  Your browser opens the Capital Energy invitation on GitHub. Click the green Join button.'
        Start-Process "https://github.com/orgs/$Org/invitation"
        Read-Host '  Press Enter after you clicked Join' | Out-Null
        $s = (& wsl.exe -d Ubuntu -u ce -- gh api "user/memberships/orgs/$Org" --jq .state 2>$null) -join ''
    }
    if ($s -ne 'active') { Stop-Here "this GitHub account is not in the $Org organization yet. The invitation goes to your Capital Energy email; it may not have been sent yet." }
    Ok "GitHub: member of $Org"
    $a = (Wsl-Ce "A=`$(~/.local/bin/claude auth status --text 2>&1); echo `$A | grep -q @ && ! echo `$A | grep -qi -e 'not logged' -e 'not signed'")
    if ($a -ne 0) {
        Write-Host '  Claude Code: the browser opens; sign in and approve.'
        if ((Wsl-Ce "$browser; ~/.local/bin/claude auth login") -ne 0) { Stop-Here 'the Claude Code sign-in did not finish.' }
    }
    Ok 'Claude Code signed in'

    Step '7 of 8 - the Capital Energy corpus and the member kit (three privacy questions come up here)'
    New-Item -ItemType Directory -Force -Path $CeHome | Out-Null
    $corpusWin = Join-Path $CeHome 'corpus'
    $corpusWsl = To-Wsl $corpusWin
    if (-not (Test-Path (Join-Path $corpusWin '.git'))) {
        if ((Wsl-Ce "gh repo clone $Org/$Corpus '$corpusWsl' -- --quiet") -ne 0) { Stop-Here 'could not copy the corpus from GitHub.' }
    }
    Ok "corpus copied to $corpusWin"
    $kitWsl = "$corpusWsl/06_scripts_data/fleet_member"
    if ((Wsl-Ce "bash '$kitWsl/install_member.sh'") -ne 0) { Stop-Here 'the member kit reported a problem (read the lines above).' }
    $r = (& wsl.exe -d Ubuntu -u root -- bash "$kitWsl/wsl/root_setup.sh") -join "`n"
    Write-Host $r
    if ($r -notmatch 'ROOT_SETUP_OK') { Stop-Here 'the background services did not start (read the lines above).' }

    Step '8 of 8 - finishing on the Windows side'
    $kitWin = Join-Path $corpusWin '06_scripts_data\fleet_member'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kitWin 'wsl\windows_finish.ps1') -KitDir $kitWin
    $sp = Join-Path $CeHome '.ce_member\START_PROMPT.md'
    if (Test-Path $sp) {
        Copy-Item -Force $sp (Join-Path $CeHome 'START_PROMPT.md')
        Get-Content -Raw $sp | Set-Clipboard
        Ok 'the start prompt is on your clipboard'
    }
    $claudeExe = Join-Path $env:LOCALAPPDATA 'AnthropicClaude\claude.exe'
    if (Test-Path $claudeExe) { Start-Process $claudeExe }
    Write-Host ''
    Write-Host 'DONE with the automatic part. Three things left:' -ForegroundColor Green
    Write-Host '  1. In the Claude app, sign in with your Capital Energy email.'
    Write-Host '  2. In Chrome (it opened the Claude in Chrome page), click Add to Chrome and sign it in the same way.'
    Write-Host "  3. In the Claude app, open the Code tab, choose the folder $CeHome,"
    Write-Host '     click in the message box, press Ctrl+V and Enter. The AI takes it from there.'
}
