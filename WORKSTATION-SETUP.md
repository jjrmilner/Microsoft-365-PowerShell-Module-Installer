# Workstation Setup — Component Guide

A first-principles explanation of the **workstation bootstrap** in this repo: what each component is,
the problem it solves, how it works, and how the pieces compose. This is the *non-PowerShell* layer —
for the PowerShell **module** layer (services, profiles, `Modules-Config.json`) see the [README](README.md).

---

## 1. Why there are two layers

A working developer machine needs two fundamentally different kinds of things, and they do **not**
share a package manager, an idempotency model, or a failure mode:

| | **Workstation layer** (this guide) | **Module layer** ([README](README.md)) |
|---|---|---|
| Installs | Native apps + shell/app configuration | PowerShell modules |
| Package manager | `winget`, `code --install-extension`, `git`, registry | PowerShell Gallery (`Install-Module` / `Install-PSResource`) |
| Examples | Git, PowerShell 7, .NET, Node, Python, Terraform, Azure CLI, VS Code, git identity, `$PROFILE` | `Microsoft.Graph.*`, `Az.*`, `ExchangeOnlineManagement`, `Pester` |
| Lives in | `Setup-Workstation.ps1` + `workstation-config.json` | `Install-ModulesSimple-v3.ps1` + `Modules-Config.json` |

Keeping them separate means each layer can be run, tested, and reasoned about on its own — and the
workstation layer can **hand off** to the module layer as its final step instead of duplicating it.

> **Two ways this repo is used.** Standalone (`Setup-Workstation.ps1` on your own machine), *or* as the
> PowerShell-module provider for the larger GMS **workstation-setup** repo, which handles its own
> superset of the non-PowerShell layer (incl. Claude config) and calls
> `Install-ModulesSimple-v3.ps1 -Profile devworkstation` for the modules. The `devworkstation` profile
> exists precisely so that hand-off is a one-liner.

---

## 2. Component map

| File | Role |
|------|------|
| [`Setup-Workstation.ps1`](Setup-Workstation.ps1) | **Orchestrator.** Reads the manifest and runs the bootstrap steps in order, then hands off to the module installer. |
| [`workstation-config.json`](workstation-config.json) | **Manifest.** Declares *what* to install/configure (winget IDs, VS Code extension IDs, environment). Public-safe — **no secrets**. |
| `workstation.local.json` | **Local override.** *Optional, git-ignored.* Your machine/org specifics (git identity, enterprise GitHub host) that override the public placeholders. |
| [`Setup-ConsoleFont.ps1`](Setup-ConsoleFont.ps1) | **Opt-in console-font fix.** Makes Oh My Posh / Nerd Font glyphs render in the classic console host (conhost). |
| [`Install-ModulesSimple-v3.ps1`](Install-ModulesSimple-v3.ps1) | The module-layer installer the bootstrap calls at the end. |

The orchestrator is **declarative over the manifest**: to change what gets installed you edit the JSON,
not the script. The script is the *engine*; the JSON is the *recipe*.

---

## 3. The orchestrator — `Setup-Workstation.ps1`

```powershell
.\Setup-Workstation.ps1                 # full bootstrap: tools + extensions + env + modules
.\Setup-Workstation.ps1 -SkipModules    # everything except the PowerShell module install
.\Setup-Workstation.ps1 -ConsoleFont    # also run the opt-in console-font fix
.\Setup-Workstation.ps1 -WhatIf         # dry-run: show what would change, change nothing
.\Setup-Workstation.ps1 -ConfigFile path\to\other.json
```

It is **idempotent** — every step checks "is this already present/correct?" before acting, so re-running
is safe and fast. It runs these steps in order:

1. **winget packages** — install the native tool-chain (§6).
2. **VS Code extensions** — install the editor extension set (§7).
3. **PowerShell environment** — trust PSGallery, set execution policy (§8).
4. **git configuration** — identity, default branch, `git lfs install` (§8).
5. **GitHub CLI** — target host + auth status, optional `GH_HOST` (§8).
6. **Console font** *(only if `-ConsoleFont` or `consoleFont.enabled`)* — §9.
7. **PowerShell modules** *(unless `-SkipModules`)* — hand off to the installer (§10).
8. **Manual follow-ups** — print the secrets checklist (§11).

**Config loading & override.** The script loads `workstation-config.json`, then *optionally* overlays
`workstation.local.json` via `OverrideOr` — a local value wins only if it is present **and** non-empty,
otherwise the public default applies. That is the whole public/local split (§5) in one helper.

**Failure philosophy.** The script runs under `$ErrorActionPreference = 'Stop'`, but the *non-essential*
configuration steps are deliberately **best-effort**: a step that can legitimately fail on a managed
machine (e.g. `Set-ExecutionPolicy` under WDAC) is wrapped so it **warns and continues** rather than
aborting the whole bootstrap. See §12 for the reasoning behind each safety mechanism.

---

## 4. The manifest — `workstation-config.json`

The manifest is split into self-describing sections. Keys beginning with `_` (e.g. `_comment`,
`_note`, `_postWinget`) are **documentation embedded in the data** — the script ignores them, humans
read them. Everything ships public-safe: generic placeholders, never an organisation value or secret.

```jsonc
{
  "tooling":        { "winget": [ { "id", "enabled", "description" } ], "_postWinget": [ ... ] },
  "vscodeExtensions": { "ids": [ "publisher.extension", ... ] },
  "environment": {
    "git":       { "user.name", "user.email", "init.defaultBranch" },
    "githubCli": { "host" },
    "envVars":   { "GH_HOST" },
    "powershell":{ "psGalleryTrust", "executionPolicy" }
  },
  "consoleFont":     { "enabled", "nerdFont", "installOhMyPosh" },
  "moduleInstaller": { "script", "profile", "silent" },
  "secretsChecklist":{ "items": [ ... ] }
}
```

- **`enabled` flags** let you turn any winget package on/off without deleting it (the optional tools —
  Functions Core Tools, Bicep, Docker — ship `enabled: false`).
- **`moduleInstaller`** is the hand-off contract: which installer script, which profile, silent or not.
- **`_publicSafe`** in the file states the rule the file lives by: nothing org-specific or secret goes here.

---

## 5. The local override — `workstation.local.json`

**Problem:** the manifest is committed to a public repo, but a real machine needs *your* git identity and
*your* enterprise GitHub host — which are neither generic nor (in the host's case) something you want in
a public file.

**Solution:** an optional `workstation.local.json` that is **git-ignored** and overlays only the fields
you set. Anything you omit falls back to the public default. Typical contents:

```jsonc
{
  "git":       { "user.name": "Jane Dev", "user.email": "jane@example.com" },
  "githubCli": { "host": "your-org.ghe.com" },
  "envVars":   { "GH_HOST": "your-org.ghe.com" }
}
```

This is why a fresh clone prints `git user.name not set (placeholder)` until you create this file — the
public manifest intentionally ships `"<YOUR NAME>"` placeholders, and the script refuses to apply a
value that still looks like a placeholder (`-notmatch '^<'`).

---

## 6. The winget tooling layer

**Why winget:** it is the built-in Windows package manager (`App Installer`), so the bootstrap has no
external prerequisite, installs system-wide where appropriate, and upgrades cleanly on re-run.

Each entry is installed **non-interactively and idempotently**: the script first asks
`winget list --id <id>` and skips if present; otherwise it runs
`winget install -e --id <id> --accept-package-agreements --accept-source-agreements --disable-interactivity --silent`.
(The flags are not optional — see §12 for why their absence causes hangs/aborts.)

| Package (`id`) | Why it's here |
|----------------|---------------|
| `Git.Git` | Version control — the foundation everything else assumes |
| `GitHub.GitLFS` | Large-file storage; the script also runs `git lfs install` |
| `GitHub.cli` (`gh`) | GitHub / GitHub Enterprise operations, auth, PR automation; also wires itself as git's credential helper |
| `Microsoft.PowerShell` | **PowerShell 7** — the module layer targets PS7 (the M365/Az modules and Pester v5 need it) |
| `Microsoft.DotNet.SDK.9` | .NET builds — container apps, tooling |
| `OpenJS.NodeJS.LTS` | Node.js + npm — JS tooling, MCP servers, and **Claude Code** (`npm i -g @anthropic-ai/claude-code`) |
| `Python.Python.3.13` | Python tooling and automation scripts |
| `Hashicorp.Terraform` | Infrastructure-as-code (the GMS Azure estate is Terraform-managed) |
| `Microsoft.AzureCLI` (`az`) | Azure control plane — login, Key Vault, ACR, resource management |
| `Microsoft.VisualStudioCode` | The editor (and host for the extension set in §7) |
| `Microsoft.Azure.FunctionsCoreTools` · `Microsoft.Bicep` · `Docker.DockerDesktop` | Optional — ship `enabled: false`; flip on when needed |

**`_postWinget` reminders** print after the loop. The key one: **Claude Code is not a winget package** —
after Node installs, run `npm install -g @anthropic-ai/claude-code` (or `irm https://claude.ai/install.ps1 | iex`).

> **Caveat — tools installed outside winget.** If a tool was installed by its own `.exe` (so it shows in
> *Add/Remove Programs* but not under its winget ID), `winget list --id <id>` reports it as missing and the
> script will run `winget install` for it. winget then detects the existing install and upgrades/skips
> silently — harmless, just noisier output. (Seen with Git and Node on machines provisioned by other means.)

---

## 7. The VS Code extensions layer

Installed idempotently via `code --list-extensions` (skip if present) then `code --install-extension <id> --force`.
The set is the **functional** tool-chain for the work this org does — themes and personal-preference
extensions are intentionally omitted. Grouped by purpose:

| Group | Extensions |
|-------|-----------|
| Claude | `anthropic.claude-code` |
| .NET / C# | `ms-dotnettools.csdevkit`, `ms-dotnettools.csharp`, `ms-dotnettools.vscode-dotnet-runtime` |
| PowerShell | `ms-vscode.powershell` |
| Python | `ms-python.python`, `ms-python.vscode-pylance`, `ms-python.debugpy` |
| Test / automation | `ms-playwright.playwright` |
| Azure / IaC | `ms-azuretools.vscode-bicep`, `ms-azuretools.vscode-azureresourcegroups`, `ms-azuretools.vscode-containers` |
| Remote | `ms-vscode-remote.remote-wsl` |
| GitHub | `github.vscode-github-actions`, `github.vscode-pull-request-github`, `eamodio.gitlens` |
| JS / web | `dbaeumer.vscode-eslint`, `esbenp.prettier-vscode`, `ms-vscode.vscode-typescript-next` |
| Developer experience | `usernamehw.errorlens`, `streetsidesoftware.code-spell-checker` |
| Markdown / docs | `yzhang.markdown-all-in-one`, `bierner.markdown-preview-github-styles` |
| Data | `mechatroner.rainbow-csv`, `grapecity.gc-excelviewer`, `zainchen.json` |

If the `code` CLI isn't on `PATH` yet (first VS Code install), the script warns and tells you to reopen a
new terminal and re-run — the rest of the bootstrap still completes.

---

## 8. The environment layer

Three small but important pieces of machine state:

**PowerShell (`environment.powershell`)**
- `psGalleryTrust: true` → marks the PowerShell Gallery as a trusted repository, so the module layer can
  install without an "untrusted repository" prompt.
- `executionPolicy: "RemoteSigned"` (CurrentUser) → set **best-effort**. On a locked-down
  (WDAC / AppLocker / ConstrainedLanguage) machine `Set-ExecutionPolicy` throws a `SecurityException`
  even when the effective policy is already permissive; the script catches that, warns, and continues.

**git (`environment.git`)** — applies `user.name`, `user.email` (from your local override, §5),
`init.defaultBranch`, and runs `git lfs install`. Placeholder values are skipped with a warning.

**GitHub CLI (`environment.githubCli`)** — resolves the target host (public default `github.com`,
override with your GHE host), then checks `gh auth status --hostname <host>`; the exit code is
**host-scoped**, so it reports "logged in" only for *that* host, not any host. It never logs you in —
it prints the exact `gh auth login` command for you to run (login is a manual, credentialed step, §11).
Optionally sets a user-scope `GH_HOST` env var.

---

## 9. The console-font fix — `Setup-ConsoleFont.ps1` (opt-in)

**Problem:** Oh My Posh / powerline prompts use Nerd Font glyphs (e.g. `U+E0B0`). In the **classic
console host (conhost)** two *independent* things break them:

1. **Code page.** A fresh conhost starts on the legacy OEM code page (437/850), so UTF-8 glyphs get
   decoded one byte at a time → mojibake.
2. **Font.** The icon glyphs only exist in a Nerd Font, and conhost filters its font picker to an HKLM
   allow-list — a Nerd Font isn't even selectable until it's added.

**Windows Terminal handles both automatically** — this fix is only for people who still use conhost.
It's **off by default** because it touches the registry, needs admin for one step, and writes to your
`$PROFILE`. Enable with `-ConsoleFont` on the orchestrator, or `consoleFont.enabled: true`.

The script does four idempotent steps:

| Step | What | Scope |
|------|------|-------|
| 0 | winget-install the Nerd Font (`Microsoft.CascadiaCode`) and Oh My Posh, if missing | per-user |
| 1 | Add the Nerd Font to the conhost **HKLM** font allow-list (incrementing `0`,`00`,… keys) | **needs admin** (skips with a warning if not elevated) |
| 2 | Set **HKCU** console defaults: `FaceName`, `FontFamily=TrueType`, `CodePage=65001` (UTF-8) | per-user |
| 3 | Write a **non-destructive managed block** into `$PROFILE` (forces UTF-8 I/O + loads Oh My Posh, guarded so it can't error when OMP is absent) | per-user |
| 4 | Verify and report | — |

The `$PROFILE` write is **non-destructive**: it only replaces the content *between its own markers*
(`# >>> GMS console-font (managed) >>>` … `# <<< … <<<`), preserving everything else, and writes UTF-8
without BOM. Console settings apply to **new** windows only — reopen your shell afterwards.

```powershell
.\Setup-ConsoleFont.ps1            # the fix (run elevated for the HKLM allow-list step)
.\Setup-ConsoleFont.ps1 -WhatIf    # dry-run
.\Setup-ConsoleFont.ps1 -SkipOhMyPosh   # UTF-8 + font only, no Oh My Posh
```

---

## 10. The hand-off to the module layer

Unless `-SkipModules` is given, the last functional step reads `moduleInstaller` from the manifest and runs:

```powershell
& Install-ModulesSimple-v3.ps1 -Profile devworkstation -Silent
```

That installs the PowerShell module set for the `devworkstation` profile — Microsoft Graph (auth, users,
groups, directory management, governance, applications), Exchange Online / IPPS, the Azure `Az.*` modules
the GMS agents use (Accounts, Resources, Storage, Key Vault, Container Registry, Monitor, Operational
Insights), and dev/test tooling (PSScriptAnalyzer, Pester, PSReadLine, Posh-Git). For the full module
catalogue, profiles, and the **Microsoft.Graph same-version rule**, see the [README](README.md).

---

## 11. The secrets model — nothing credential-bearing in the repo

By design, **no secret or credential is stored in this repo or written by the bootstrap.** The setup
configures *where* tools look for credentials, then prints a checklist of the credentialed steps for you
to do manually from your own secure store:

| Manual step | Where the credential actually lives |
|-------------|-------------------------------------|
| `gh auth login` | the `gh` config store (token) |
| `claude login` / OAuth | `~/.claude` |
| App-only auth certificate | `.pfx` imported into `Cert:\CurrentUser\My` from Key Vault / your secure store |
| `az login` | Azure CLI token cache (interactive or service-principal) |
| MCP server tokens / API keys | configured locally per tool |

The only machine-specific *non-secret* values (git identity, GHE host) live in the git-ignored
`workstation.local.json` (§5).

---

## 12. Design principles (and the safety mechanisms that enforce them)

These are the invariants the workstation layer is built on. Several map directly to bugs that *would*
hang or abort an unattended run if the mechanism weren't there.

- **Idempotent.** Every step checks before it acts; re-running is safe and converges.
- **Declarative.** Behaviour is driven by `workstation-config.json`, not by editing the script.
- **Public-safe + local override.** Public manifest ships placeholders; machine/org values go in the
  git-ignored `workstation.local.json`.
- **No secrets.** Credentials are never stored or written — only a manual checklist is printed (§11).
- **Dry-runnable.** `-WhatIf` propagates through every change via `SupportsShouldProcess`.
- **Non-interactive by construction.** Anything that could block waiting for input is forced
  non-interactive, because the bootstrap is meant to run unattended:
  - **winget** calls pass `--accept-source-agreements --disable-interactivity` (plus
    `--accept-package-agreements --silent` for installs). Without these, the first winget query blocks
    *forever* on the interactive **msstore source-agreement** prompt on a machine that has never accepted it.
  - The module installer **bootstraps the NuGet provider** before `Install-Module` so a `-Silent` run
    never stalls on the "install NuGet provider now? [Y/N]" prompt, and pins `Install-Module`
    non-interactive (`-Force` on `-Silent`, `-Repository PSGallery`, `-Confirm:$false`).
- **Native exit codes don't masquerade as fatal errors.** PowerShell 7.4+ defaults
  `$PSNativeCommandUseErrorActionPreference = $true`, which (under `-Stop`) turns *any* non-zero exit from
  a native command into a terminating error. But `winget list` returns non-zero for a not-installed
  package, and `gh auth status` returns non-zero when not logged in — both expected. The scripts set
  `$PSNativeCommandUseErrorActionPreference = $false` and inspect `$LASTEXITCODE` themselves.
- **Non-essential config steps are best-effort.** On a managed machine, `Set-ExecutionPolicy` can throw
  `SecurityException`; the script warns and continues instead of aborting the whole bootstrap.
- **Resilient module install.** If the legacy `Install-Module` fails to extract a package (e.g.
  *"End of Central Directory record could not be found"* — seen when the PowerShell module path is
  redirected into **OneDrive**, or with a corrupt cached `.nupkg`), the installer automatically retries
  via the modern `Install-PSResource` engine, which uses a different download/extract path.

---

## 13. Common scenarios

| Goal | Command |
|------|---------|
| Fresh machine, full bootstrap | `.\Setup-Workstation.ps1` |
| Tools + extensions + env only (no modules) | `.\Setup-Workstation.ps1 -SkipModules` |
| Include the conhost font fix | `.\Setup-Workstation.ps1 -ConsoleFont` |
| See what would change, change nothing | `.\Setup-Workstation.ps1 -WhatIf` |
| Just the module layer | `.\Install-ModulesSimple-v3.ps1 -Profile devworkstation` |
| From the menu | `.\Install-ModulesSimple-v3.ps1` → option **8** (Workstation Setup) |

---

## 14. Troubleshooting

| Symptom | Cause | Resolution |
|---------|-------|------------|
| Hangs at `=== winget packages ===` with no output | winget blocking on the un-accepted **msstore source agreement** | Already handled by `--accept-source-agreements --disable-interactivity`. To clear manually once: run any `winget list --accept-source-agreements`. |
| Aborts instantly at a step that runs `winget`/`gh` | PS 7.4+ turning a benign non-zero native exit into a terminating error | Handled by `$PSNativeCommandUseErrorActionPreference = $false`; if you adapt the script, keep that line. |
| `[CRITICAL ERROR] Security error` at `Set-ExecutionPolicy` | **WDAC / AppLocker / ConstrainedLanguage** lockdown | Expected on managed machines; the step is now best-effort and prints a `[WARN]`. The effective policy is already sufficient. |
| `-Silent` module install stalls on a `Y/N` prompt | NuGet package provider missing → PowerShellGet bootstrap prompt | Handled by the up-front `Install-PackageProvider -Name NuGet` bootstrap. |
| `End of Central Directory record could not be found` installing a module | Corrupt cached `.nupkg`, or module path redirected into **OneDrive** | Handled by the automatic `Install-PSResource` fallback. Manually: `Install-PSResource -Name <mod> -Scope CurrentUser -TrustRepository -Reinstall`. |
| `code` extensions skipped with a warning | VS Code just installed; `code` not on `PATH` yet | Open a **new** terminal and re-run — idempotent, it resumes. |
| Nerd Font glyphs still broken in conhost | Font/code-page settings apply to **new** windows only; HKLM step needs admin | Reopen the shell; for the font picker, re-run `Setup-ConsoleFont.ps1` **elevated**. Windows Terminal needs none of this. |
| `git user.name not set (placeholder)` | No `workstation.local.json`, public manifest ships placeholders | Create `workstation.local.json` (§5) or run `git config --global user.name/​user.email`. |
