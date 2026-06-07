# Microsoft 365 PowerShell Module Installer - Service-Based Architecture

A scalable, JSON-driven installer for Microsoft 365 / Azure PowerShell modules, organised by the
service each module manages (Authentication, Identity, Exchange, Teams, SharePoint, Security,
Reporting, Power Platform, Azure, Development). v3 also bootstraps a full developer workstation
(dev tools + VS Code extensions + environment) via an optional menu option / switch.

> **v3 is the current entry point:** `Install-ModulesSimple-v3.ps1`. The older `Install-ModulesSimple.ps1`
> and `Install-ModulesSimple-v2.ps1` are retained for reference.

---

## What's in this repo

| File | Purpose |
|------|---------|
| `Install-ModulesSimple-v3.ps1` | **Current** module installer (interactive menu, profiles, silent mode, workstation option) |
| `Modules-Config.json` | Module catalogue: services, modules, profiles, settings |
| `Setup-Workstation.ps1` | Workstation bootstrap: winget tools + VS Code extensions + git/gh/env, then the module installer |
| `workstation-config.json` | Workstation manifest (winget IDs, VS Code extension IDs, environment) - **no secrets** |
| `workstation.local.json` | *Optional, git-ignored* - your machine/org overrides (git identity, enterprise host) |
| `Install-ModulesSimple-v2.ps1`, `Install-ModulesSimple.ps1` | Previous versions (reference) |
| `Intune Deployment Guide.md` | Legacy silent-mode notes for MDM/Intune |

---

## Quick Start

### Interactive menu (recommended)
```powershell
.\Install-ModulesSimple-v3.ps1
```
The menu lists every profile defined in `Modules-Config.json`, plus **Custom Configuration**,
**Workstation Setup**, **Remove All Modules**, and **Exit**.

### Direct profile
```powershell
.\Install-ModulesSimple-v3.ps1 -Profile security
.\Install-ModulesSimple-v3.ps1 -Profile iso27001
.\Install-ModulesSimple-v3.ps1 -Profile devworkstation
```

### Specific services only
```powershell
.\Install-ModulesSimple-v3.ps1 -EnableServices "authentication,identity,exchange"
```

### Silent (automation)
```powershell
.\Install-ModulesSimple-v3.ps1 -Silent                 # installs settings.defaultProfile
.\Install-ModulesSimple-v3.ps1 -Silent -Profile basic  # explicit profile wins
```

### Full developer workstation
```powershell
.\Install-ModulesSimple-v3.ps1 -Workstation
# or run the bootstrap directly:
.\Setup-Workstation.ps1
```

---

## Profiles

| Profile | Services | Use case |
|---------|----------|----------|
| `basic` | auth, identity, exchange, teams, sharepoint, reporting | Day-to-day M365 admin |
| `security` | basic + security | Security administrator |
| `iso27001` | auth, identity, exchange, devicemanagement, security, azure, development, reporting | ISO 27001 evidence collection |
| `devworkstation` | auth, identity, exchange, azure, development, reporting | **Developer workstation (PowerShell layer)** |
| `developer` | basic + development | Script development |
| `enterprise` | all services | Full M365 + Azure |

Valid profiles are read **from the config** at runtime - add your own under `profiles` and it appears
in the menu and `-Profile` automatically.

---

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-ConfigFile` | Path to the JSON config (default `modules-config.json`) |
| `-EnableServices` | Comma-separated service names (overrides profile) |
| `-Profile` (alias of `-InstallProfile`) | Profile to install; valid values come from the config |
| `-Force` | Reinstall even if present |
| `-Interactive` | Confirm before installing |
| `-FixGraphVersions` | Surface Graph version-conflict guidance |
| `-Silent` | No prompts; auto-upgrades to PS7; uses `settings.defaultProfile` |
| `-Workstation` | Run the workstation bootstrap instead of installing modules |

---

## Configuration (`Modules-Config.json`)

Enable/disable a whole service or an individual module with `"enabled": true|false`. Pin a version
or use `"latest"`.

> **Microsoft Graph version rule:** every `Microsoft.Graph.*` sub-module **must** be on the *same*
> version, or PowerShell throws *"Assembly with same name is already loaded"* on import. Keep them
> **all** `"latest"` **or all** pinned to one identical version - never mix. (v3's config ships them
> all on `"latest"`.)

`settings` block (now honoured by v3):

| Setting | Effect |
|---------|--------|
| `defaultProfile` | Profile used by `-Silent` when no `-Profile` is given |
| `defaultScope` | `CurrentUser` (default) or `AllUsers` (falls back to CurrentUser if not elevated) |
| `skipVersionCheck` | Skip the `Find-Module` "is there a newer version" check for `latest` modules |

---

## Workstation Setup (the non-PowerShell layer)

`Setup-Workstation.ps1` reads `workstation-config.json` and is **idempotent** (re-running skips what's
already present). It installs:

- **winget tools:** Git, Git LFS, GitHub CLI, PowerShell 7, .NET SDK, Node.js LTS, Python, Terraform,
  Azure CLI, VS Code (Functions Core Tools / Bicep / Docker optional).
- **VS Code extensions:** the functional set for .NET / Python / PowerShell / Azure / GitHub / Playwright work.
- **Environment:** PSGallery trust, execution policy, `git` identity + `git lfs install`,
  GitHub CLI host, optional `GH_HOST`.
- Then runs `Install-ModulesSimple-v3.ps1 -Profile devworkstation -Silent`.

> **Claude Code** is not a winget package - after Node installs:
> `npm install -g @anthropic-ai/claude-code` (or `irm https://claude.ai/install.ps1 | iex`).

### No secrets in this repo
`workstation-config.json` ships generic placeholders. Put your machine/org specifics (git identity,
enterprise GitHub host) in **`workstation.local.json`** - it's git-ignored. Credentials are never
stored here: `gh auth login`, `claude login`, `az login`, and any auth certificate (`.pfx` into
`Cert:\CurrentUser\My`) are provisioned manually from your own secure store. The bootstrap prints a
checklist of these at the end.

---

## v3 Changes

- **Bug fix:** valid profiles are read from the config, not a hard-coded list - previously selecting
  `iso27001`/`devworkstation` (or any non-default profile) from the menu errored with *"Invalid profile"*.
- `settings.defaultProfile` / `defaultScope` / `skipVersionCheck` are now actually honoured.
- `-Profile` no longer shadows the `$PROFILE` automatic variable (internal `-InstallProfile`, alias `-Profile`).
- New **Workstation Setup** menu option and `-Workstation` switch.
- `-Silent` uses `settings.defaultProfile` (and respects an explicit `-Profile`) instead of hard-coding `enterprise`.
- TLS 1.2 forced on Windows PowerShell 5.1; module-cleanup wildcard matching fixed; PS7 restart prefers
  `$PSCommandPath`; stray debug line removed.

---

## License

**Apache 2.0** (see `LICENSE`) with the **Commons Clause** restriction (see `COMMON-CLAUSE.txt`).
Each source file carries `SPDX-License-Identifier: Apache-2.0 WITH Commons-Clause`.

### FAQ: MSP and Consulting Use
**Q: Can an MSP/consultant use this in a paid engagement?**
- **Allowed:** used internally by the end customer, with the consultant assisting.
- **Not allowed without a commercial licence:** providing a managed service where the tool runs in the
  MSP's own environment, or where the value of the service substantially derives from the tool. That
  meets the Commons Clause definition of "Sell".

**Commercial licence:** licensing@globalmicro.co.za

## Warranty Disclaimer
Distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied. See the Apache-2.0 WITH Commons-Clause License for the governing terms.

## Author
**JJ Milner**
Blog: https://jjrmilner.substack.com
GitHub: https://github.com/jjrmilner
