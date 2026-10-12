# Capital Energy fleet bootstrap

Public on purpose: these two files only install tools and sign a Capital Energy employee
in; they carry no company information. Everything company-specific lives in the private
corpus and arrives only after the GitHub sign-in proves the person belongs to the
`cptlenergy` organization.

**On a Mac** — open Terminal (Command-Space, type Terminal, Return), paste, press Return:

```
curl -fsSL https://raw.githubusercontent.com/cptlenergy/fleet-bootstrap/main/mac.sh | bash
```

**On Windows** — open PowerShell (Start, type PowerShell, Return), paste, press Enter:

```
irm https://raw.githubusercontent.com/cptlenergy/fleet-bootstrap/main/windows.ps1 | iex
```

Both are safe to run again; they skip what is done and delete nothing.

## Version and changes

Version: see `VERSION`.

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-10-12 | First version: Mac and Windows bootstraps for the member kit 1.0.0. |
