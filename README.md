# Capital Energy fleet bootstrap

Public on purpose: these two files only install tools and sign a Capital Energy employee
in; they carry no company information. Everything company-specific lives in the private
corpus and arrives only after the GitHub sign-in proves the person belongs to the
`cptlenergy` organization.

**On a Mac** — open Terminal (Command-Space, type Terminal, Return), paste, press Return:

```
curl -fsSL https://raw.githubusercontent.com/cptlenergy/fleet-bootstrap/main/mac.sh | bash
```

**On Windows** — copy the line below (the copy button at its right edge). Then click **Start**,
type **PowerShell**, click **Windows PowerShell** (the one without "x86"; the installer moves itself
if the x86 one is used); when the blue window opens, press **Ctrl+V** (no need to click in it), then **Enter**. Click **Yes**
when Windows asks to allow changes.

```
irm https://raw.githubusercontent.com/cptlenergy/fleet-bootstrap/main/windows.ps1 | iex
```

Do not use the Windows key + R "Run" box: Windows Defender blocks a download command pasted there
("Windows cannot access the specified device, path, or file"), as it should — scams ask for it.

**Guided set-up (the way employees are sent):** after accepting the Claude invitation on the
computer, the person opens the Claude app on their phone (iPhone or Android; or claude.ai in
any browser), signs in with their Capital Energy email, and pastes this. Their own Claude then
guides them through everything with [`GUIDE.md`](GUIDE.md), from photos of the screen:

> I'm setting up my Capital Energy company computer. Please be my set-up guide: first read
> https://raw.githubusercontent.com/cptlenergy/fleet-bootstrap/main/GUIDE.md and follow it
> exactly, one step at a time. If you can't open that link, tell me, and I'll open it in my
> browser and paste it to you.

Both set-up lines are safe to run again; they skip what is done and delete nothing. Both say what they are
doing at every step and print a line at least every 15 seconds while anything slow runs; a
full record of the run is kept in a setup log and copied into the person's work repository.

## Version and changes

Version: see `VERSION`.

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-10-12 | First version: Mac and Windows bootstraps for the member kit 1.0.0. |
| 1.0.8 | 2026-10-13 | First Mac test (M, a second account "CE Standard" on Ms-MacBook-Pro; he guided by phone like Cole will be). Fixed: (1) the Claude Code sign-in crashed at once ("EINVAL: invalid argument, kqueue"): it is now given the window's own terminal device, not /dev/tty, and success is judged by Claude Code's own sign-in status; a crash now stops with "a fault in the set-up, not something you can fix" instead of "fix the one thing above"; (2) the privacy question never waited (it could not open the keyboard: Python refuses /dev/tty opened read-write as one stream): the keyboard is now opened as two streams, typed-ahead keys are thrown away, and with no keyboard at all the folders stay as they were and the window says so; (3) the question is asked on EVERY run of the set-up (M: people will not notice the desktop button), Enter keeps the earlier answer; (4) a second account on one Mac took the first account's browser-terminal port 7681 (lsof sees only the account's own programs) and its CE Terminal opened the FIRST account's shell: a port now counts as taken when anything answers on it, an existing account sharing a port is moved to the next free one when the set-up runs again, the member check fails if the terminal answering is another account's, and the member AI's instructions say to use exactly its own number; (5) the DONE screen names the five desktop buttons (M: people with busy desktops will not see them), gives the terminal number when it is not 7681, and says to open a new Terminal window to use Claude Code by hand; (6) "Use only this one Terminal window". Windows: the DONE screen names the desktop buttons. GUIDE: copy the line from the GitHub page, not Gmail; Mac STOPPED list; the terminal number. |
| 1.0.7 | 2026-10-12 | M, 20:10: how do we get information from someone in another state when an install fails? When the set-up stops, the record of the run now reaches M: sent to the person's work repository on GitHub automatically when it exists already; otherwise the folder holding the record opens (File Explorer or Finder) and the window says to drag its files into a reply to M's set-up email; `GUIDE.md` says which. The 15-second progress lines no longer print long web addresses (they wrapped on the XPS 15). The member AI's instructions gain rule 9: its conversations reach GitHub every hour, so it never writes out the computer's other account names, other people's folders, network addresses or Wi-Fi names (the XPS 15 test, where the member AI listed the computer's administrator accounts). |
| 1.0.6 | 2026-10-12 | Fifth Windows test (cetest on xps15), M's findings: the Claude app's sign-in looped because several sign-ins were open at the same time. The DONE screen on both Windows and Mac now says to do the last three things one at a time, in order, and gives the email-code route for a looping sign-in. `GUIDE.md` 1.0.6: the guiding AI troubleshoots down a ladder before sending anyone to M (it gave up too early in the test), plus new sections on sign-ins and on the pop-ups seen in real tests. Made from a phone session, not from the corpus: the corpus copy at `06_scripts_data/fleet_member/bootstrap` needs the same change before the next publish, or the next publish will undo it. |
| 1.0.5 | 2026-10-12 | Fourth Windows test (cetest on xps17), M's findings: the privacy question's "type y or n" line showed only after Enter was pressed (the end of a line with no line ending did not show), so every question now ends with a full line, spells out "type the letter y, then press Enter", and is no longer piped through sed; the step heading says one question, not three; Chrome, the Claude app and GitHub's code page are opened as the person through explorer.exe, not as administrator (a Chrome started from the administrator window showed "Profile error occurred", and the administrator Claude app stopped a normal one from opening); the whole-set-up check runs at the very end, after the background services start (run earlier it printed four FAIL lines); the browser-terminal page opens again (its folder name lost its backslashes on the way into Ubuntu); the DONE screen and `GUIDE.md` name every window that opens at the end and what to click. Windows 10 (M, 17:28: "This needs to work on Windows 10 anyway"): on a new Windows account winget appears only after the Store registers it, so the set-up now asks Windows to register it (Microsoft's documented command) before stopping with the Store instruction. |
| 1.0.4 | 2026-10-12 | Third Windows test (cetest on xps17): the Claude Code sign-in opened a Documents folder window instead of the browser, because explorer.exe does not take a link that long, and the link printed in the blue window could not be clicked. Windows now opens a long link through a small Internet-shortcut file in the person's own Capital Energy folder (the browser still runs as the person, not as administrator); a sign-in link other than GitHub's code page is also put on the clipboard, and the window says to paste it into the browser if no tab opens. `GUIDE.md` 1.0.4 to match. |
| 1.0.3 | 2026-10-12 | Windows: the Claude Code sign-in no longer stops on "syntax error near unexpected token `('" (the browser and PATH settings are read from a file inside Ubuntu instead of being sent on the command line). |
| 1.0.2 | 2026-10-12 | The Windows line goes into Windows PowerShell opened from the Start menu, in its own box with a copy button; the Run box is dropped because Windows Defender blocks a download command pasted there (second test, cetest on xps17). `GUIDE.md` 1.0.2 to match. |
| 1.0.1 | 2026-10-12 | From the first Windows test (cetest on xps17): every step names what it does and its normal time; a line every 15 seconds while anything slow runs (time so far, normal time, latest output); a setup log copied into the work repository; Windows relaunches itself in 64-bit PowerShell when started in the x86 one; Windows switches off the console's Select mode for its own window, because a click inside it froze the first test until Esc was pressed; a second run updates the corpus copy (Windows); the GitHub-invitation step names the invitation email and its buttons instead of a page that cannot show an email invitation; the Claude in Chrome page opens in Chrome, not the default browser. Then: the Windows line goes in the Run box; the GitHub sign-in asks no questions and puts its code on the clipboard; the window says what frozen looks like and what to do; a stuck step is stopped and tried once more. Then, from the same test: no false "Failed opening a web browser"; the Claude Code sign-in check fixed; the paste-code step explained; enter-mashing and double runs handled; `GUIDE.md`, the guide for the employee's own Claude, added. |
