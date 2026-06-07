<#
.SYNOPSIS
    Developer workstation bootstrap - non-PowerShell layer (winget tools, VS Code extensions,
    git/gh/PowerShell environment), then hands off to the PowerShell module installer.

.DESCRIPTION
    Companion to Install-ModulesSimple-v2.ps1. Reads workstation-config.json (public, generic)
    and an OPTIONAL git-ignored workstation.local.json (your machine/org specifics: git identity,
    GHE host). Idempotent: re-running skips anything already present.

    Invoked either directly, or from the installer's "Workstation Setup" menu option.

.PARAMETER ConfigFile
    Workstation config (default: workstation-config.json in the script directory).

.PARAMETER SkipModules
    Set up tools/extensions/environment only; do NOT run the PowerShell module installer.

.PARAMETER WhatIf
    Show what would be installed/configured without changing anything.

.EXAMPLE
    .\Setup-Workstation.ps1
.EXAMPLE
    .\Setup-Workstation.ps1 -SkipModules
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigFile = "workstation-config.json",
    [switch]$SkipModules
)

$ErrorActionPreference = 'Stop'
function Info($m){ Write-Host $m -ForegroundColor Cyan }
function Ok($m)  { Write-Host "  [OK]   $m" -ForegroundColor Green }
function Warn($m){ Write-Host "  [WARN] $m" -ForegroundColor Yellow }
function Step($m){ Write-Host "`n=== $m ===" -ForegroundColor Magenta }

# --- locate + load config (with optional local override) ---
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not [IO.Path]::IsPathRooted($ConfigFile)) { $ConfigFile = Join-Path $scriptDir $ConfigFile }
if (-not (Test-Path $ConfigFile)) { throw "Config not found: $ConfigFile" }
$cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json

$localPath = Join-Path $scriptDir ($cfg._localOverrideFile ?? 'workstation.local.json')
$local = $null
if (Test-Path $localPath) { $local = Get-Content $localPath -Raw | ConvertFrom-Json; Info "Loaded local override: $localPath" }

function OverrideOr($localObj, $name, $default) {
    if ($localObj -and $localObj.PSObject.Properties.Name -contains $name -and $localObj.$name) { return $localObj.$name }
    return $default
}

# --- 1. winget packages ---
Step "winget packages"
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Warn "winget not found. Install 'App Installer' from the Microsoft Store, then re-run."
} else {
    foreach ($p in $cfg.tooling.winget) {
        if (-not $p.enabled) { continue }
        $installed = (winget list --id $p.id -e 2>$null) -match [Regex]::Escape($p.id)
        if ($installed) { Ok "$($p.id) already installed"; continue }
        if ($PSCmdlet.ShouldProcess($p.id, "winget install")) {
            Info "  installing $($p.id) - $($p.description)"
            winget install -e --id $p.id --accept-package-agreements --accept-source-agreements --silent | Out-Null
            if ($LASTEXITCODE -eq 0) { Ok $p.id } else { Warn "$($p.id) exit $LASTEXITCODE" }
        }
    }
    foreach ($n in $cfg.tooling._postWinget) { Warn $n }
}

# --- 2. VS Code extensions ---
Step "VS Code extensions"
if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    Warn "'code' CLI not on PATH yet (open a NEW terminal after VS Code installs, then re-run)."
} else {
    $have = (code --list-extensions 2>$null)
    foreach ($id in $cfg.vscodeExtensions.ids) {
        if ($have -contains $id) { Ok "$id already installed"; continue }
        if ($PSCmdlet.ShouldProcess($id, "code --install-extension")) {
            code --install-extension $id --force | Out-Null
            Ok $id
        }
    }
}

# --- 3. environment: PowerShell gallery / execution policy ---
Step "PowerShell environment"
if ($cfg.environment.powershell.psGalleryTrust -and (Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue).InstallationPolicy -ne 'Trusted') {
    if ($PSCmdlet.ShouldProcess('PSGallery','Set Trusted')) { Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; Ok "PSGallery trusted" }
} else { Ok "PSGallery already trusted (or skipped)" }
$ep = $cfg.environment.powershell.executionPolicy
if ($ep -and $PSCmdlet.ShouldProcess("ExecutionPolicy=$ep (CurrentUser)",'Set')) {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy $ep -Force; Ok "ExecutionPolicy = $ep (CurrentUser)"
}

# --- 4. environment: git ---
Step "git configuration"
$g = $cfg.environment.git
$gitName  = OverrideOr ($local.git) 'user.name'  $g.'user.name'
$gitEmail = OverrideOr ($local.git) 'user.email' $g.'user.email'
if ($gitName -notmatch '^<' -and $PSCmdlet.ShouldProcess("user.name=$gitName",'git config')) { git config --global user.name $gitName;  Ok "git user.name = $gitName" }
else { Warn "git user.name not set (placeholder). Put it in $localPath" }
if ($gitEmail -notmatch '^<' -and $PSCmdlet.ShouldProcess("user.email=$gitEmail",'git config')) { git config --global user.email $gitEmail; Ok "git user.email = $gitEmail" }
else { Warn "git user.email not set (placeholder). Put it in $localPath" }
if ($g.'init.defaultBranch' -and $PSCmdlet.ShouldProcess("init.defaultBranch=$($g.'init.defaultBranch')",'git config')) { git config --global init.defaultBranch $g.'init.defaultBranch' | Out-Null; Ok "init.defaultBranch = $($g.'init.defaultBranch')" }
if ((Get-Command git -ErrorAction SilentlyContinue) -and $PSCmdlet.ShouldProcess('git lfs','install')) { git lfs install 2>$null | Out-Null; Ok "git lfs install" }

# --- 5. environment: GitHub CLI host + optional env var ---
Step "GitHub CLI"
$ghHost = OverrideOr ($local.githubCli) 'host' $cfg.environment.githubCli.host
Info "  target host: $ghHost"
if (Get-Command gh -ErrorAction SilentlyContinue) {
    # gh auth status --hostname X exits 0 only when logged into THAT host (don't grep all hosts)
    $null = gh auth status --hostname $ghHost 2>&1
    if ($LASTEXITCODE -eq 0) { Ok "already authenticated to $ghHost" }
    else { Warn "Not logged in. Run:  gh auth login --hostname $ghHost --git-protocol https" }
} else { Warn "gh not on PATH yet (open a new terminal after install)." }
$ghEnv = OverrideOr ($local.envVars) 'GH_HOST' $cfg.environment.envVars.GH_HOST
if ($ghEnv -and $PSCmdlet.ShouldProcess("GH_HOST=$ghEnv (User env)",'Set')) { [Environment]::SetEnvironmentVariable('GH_HOST',$ghEnv,'User'); Ok "GH_HOST=$ghEnv (User env)" }

# --- 6. hand off to the PowerShell module installer ---
if (-not $SkipModules) {
    Step "PowerShell modules"
    $mi = $cfg.moduleInstaller
    $miPath = Join-Path $scriptDir $mi.script
    if (Test-Path $miPath) {
        $miArgs = @{ Profile = $mi.profile }
        if ($mi.silent) { $miArgs.Silent = $true }
        Info "  running $($mi.script) -Profile $($mi.profile)$(if($mi.silent){' -Silent'})"
        if ($PSCmdlet.ShouldProcess($mi.script,'run module installer')) { & $miPath @miArgs }
    } else { Warn "Module installer not found next to this script: $miPath" }
}

# --- 7. secrets checklist (manual) ---
Step "Manual follow-ups (NO secrets are stored in this repo)"
foreach ($i in $cfg.secretsChecklist.items) { Write-Host "  - $i" -ForegroundColor White }
Info "`nWorkstation setup complete."
