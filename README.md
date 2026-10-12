# Capital Energy fleet bootstrap

Public on purpose: these two files only install tools and sign a Capital Energy employee
in; they carry no company information. Everything company-specific lives in the private
corpus and arrives only after the GitHub sign-in proves the person belongs to the
`cptlenergy` organization.

**On a Mac** — open Terminal (Command-Space, type Terminal, Return), paste, press Return:

```
curl -fsSL https://raw.githubusercontent.com/cptlenergy/fleet-bootstrap/main/mac.sh | bash
```

**On Windows** — copy the line below (the copy button at its right edge), then press the
**Windows key and R** together: a small Run box opens. Press **Ctrl+V**, then **Enter**.
Click **Yes** when Windows asks to allow changes.

```
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/cptlenergy/fleet-bootstrap/main/windows.ps1 | iex"
```

(Or, in Windows PowerShell — the one without "x86":
`irm https://raw.githubusercontent.com/cptlenergy/fleet-bootstrap/main/windows.ps1 | iex`)

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
| 1.0.1 | 2026-10-12 | From the first Windows test (cetest on xps17): every step names what it does and its normal time; a line every 15 seconds while anything slow runs (time so far, normal time, latest output); a setup log copied into the work repository; Windows relaunches itself in 64-bit PowerShell when started in the x86 one; Windows switches off the console's Select mode for its own window, because a click inside it froze the first test until Esc was pressed; a second run updates the corpus copy (Windows); the GitHub-invitation step names the invitation email and its buttons instead of a page that cannot show an email invitation; the Claude in Chrome page opens in Chrome, not the default browser. Then: the Windows line goes in the Run box; the GitHub sign-in asks no questions and puts its code on the clipboard; the window says what frozen looks like and what to do; a stuck step is stopped and tried once more. Then, from the same test: no false "Failed opening a web browser"; the Claude Code sign-in check fixed; the paste-code step explained; enter-mashing and double runs handled; `GUIDE.md`, the guide for the employee's own Claude, added. |
