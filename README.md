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
| 1.0.5 | 2026-10-12 | Fourth Windows test (cetest on xps17), M's findings: the privacy question's "type y or n" line showed only after Enter was pressed (the end of a line with no line ending did not show), so every question now ends with a full line, spells out "type the letter y, then press Enter", and is no longer piped through sed; the step heading says one question, not three; Chrome, the Claude app and GitHub's code page are opened as the person through explorer.exe, not as administrator (a Chrome started from the administrator window showed "Profile error occurred", and the administrator Claude app stopped a normal one from opening); the whole-set-up check runs at the very end, after the background services start (run earlier it printed four FAIL lines); the browser-terminal page opens again (its folder name lost its backslashes on the way into Ubuntu); the DONE screen and `GUIDE.md` name every window that opens at the end and what to click. Windows 10 (M, 17:28: "This needs to work on Windows 10 anyway"): on a new Windows account winget appears only after the Store registers it, so the set-up now asks Windows to register it (Microsoft's documented command) before stopping with the Store instruction. |
| 1.0.4 | 2026-10-12 | Third Windows test (cetest on xps17): the Claude Code sign-in opened a Documents folder window instead of the browser, because explorer.exe does not take a link that long, and the link printed in the blue window could not be clicked. Windows now opens a long link through a small Internet-shortcut file in the person's own Capital Energy folder (the browser still runs as the person, not as administrator); a sign-in link other than GitHub's code page is also put on the clipboard, and the window says to paste it into the browser if no tab opens. `GUIDE.md` 1.0.4 to match. |
| 1.0.3 | 2026-10-12 | Windows: the Claude Code sign-in no longer stops on "syntax error near unexpected token `('" (the browser and PATH settings are read from a file inside Ubuntu instead of being sent on the command line). |
| 1.0.2 | 2026-10-12 | The Windows line goes into Windows PowerShell opened from the Start menu, in its own box with a copy button; the Run box is dropped because Windows Defender blocks a download command pasted there (second test, cetest on xps17). `GUIDE.md` 1.0.2 to match. |
| 1.0.1 | 2026-10-12 | From the first Windows test (cetest on xps17): every step names what it does and its normal time; a line every 15 seconds while anything slow runs (time so far, normal time, latest output); a setup log copied into the work repository; Windows relaunches itself in 64-bit PowerShell when started in the x86 one; Windows switches off the console's Select mode for its own window, because a click inside it froze the first test until Esc was pressed; a second run updates the corpus copy (Windows); the GitHub-invitation step names the invitation email and its buttons instead of a page that cannot show an email invitation; the Claude in Chrome page opens in Chrome, not the default browser. Then: the Windows line goes in the Run box; the GitHub sign-in asks no questions and puts its code on the clipboard; the window says what frozen looks like and what to do; a stuck step is stopped and tried once more. Then, from the same test: no false "Failed opening a web browser"; the Claude Code sign-in check fixed; the paste-code step explained; enter-mashing and double runs handled; `GUIDE.md`, the guide for the employee's own Claude, added. |
