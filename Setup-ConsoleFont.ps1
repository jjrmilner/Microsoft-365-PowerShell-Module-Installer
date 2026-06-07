<#
.SYNOPSIS
    Fix Oh My Posh / Nerd Font rendering in the classic Windows console (conhost). Opt-in.

.DESCRIPTION
    Two independent conhost problems break powerline / Nerd Font glyphs:
      1. Code page - a fresh conhost starts on the legacy OEM code page (437/850), not UTF-8,
                     so UTF-8 glyphs (e.g. U+E0B0) get decoded one byte at a time -> mojibake.
      2. Font      - the icon glyphs only exist in a Nerd Font, and conhost filters its font
                     picker to an HKLM allow-list, so a Nerd Font is not selectable until added.
    Windows Terminal handles both automatically - only the $PROFILE UTF-8 lines (step 3) are
    universal. Idempotent. The HKLM allow-list step (step 1) needs elevation; the rest is per-user.

    Hardened vs. a naive fix: the $PROFILE is updated via a NON-DESTRUCTIVE managed block (never
    clobbers an existing profile), the HKLM step is admin-aware (skips with a warning rather than
    failing), the Oh My Posh init line is guarded so it can't error when OMP isn't installed, and
    every write honours -WhatIf.

.PARAMETER NerdFont
    Installed font FAMILY name - must match exactly. Default 'Cascadia Code NF'.

.PARAMETER SkipFontInstall
    Don't winget-install the Nerd Font even if it appears to be missing.

.PARAMETER SkipOhMyPosh
    Don't install Oh My Posh and don't add its init line to the profile (UTF-8 lines only).

.EXAMPLE
    .\Setup-ConsoleFont.ps1
.EXAMPLE
    .\Setup-ConsoleFont.ps1 -WhatIf
.EXAMPLE
    # Add the HKLM allow-list entry too (run elevated):
    Start-Process pwsh -Verb RunAs -ArgumentList '-File','<path>\Setup-ConsoleFont.ps1'
#>
#requires -Version 7
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$NerdFont = 'Cascadia Code NF',
    [switch]$SkipFontInstall,
    [switch]$SkipOhMyPosh
)

function Info($m){ Write-Host $m -ForegroundColor Cyan }
function Ok($m)  { Write-Host "  [OK]   $m" -ForegroundColor Green }
function Warn($m){ Write-Host "  [WARN] $m" -ForegroundColor Yellow }
function Step($m){ Write-Host "`n=== $m ===" -ForegroundColor Magenta }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# --- 0. ensure the Nerd Font (and Oh My Posh) are installed ---
Step "Fonts / tools"
Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
$haveFont = $NerdFont -in ([System.Drawing.FontFamily]::Families.Name)
if ($haveFont) { Ok "$NerdFont already installed" }
elseif ($SkipFontInstall) { Warn "$NerdFont not installed (-SkipFontInstall set)" }
elseif (Get-Command winget -ErrorAction SilentlyContinue) {
    if ($PSCmdlet.ShouldProcess('Microsoft.CascadiaCode', 'winget install')) {
        Info "  installing Cascadia Code (ships the Nerd Font variant '$NerdFont')..."
        winget install -e --id Microsoft.CascadiaCode --accept-package-agreements --accept-source-agreements --silent | Out-Null
        Ok "Cascadia Code install attempted (a Nerd Font may need a sign-out/in to register)"
    }
} else { Warn "winget not found; install '$NerdFont' manually from https://www.nerdfonts.com" }

if (-not $SkipOhMyPosh) {
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) { Ok "Oh My Posh already installed" }
    elseif (Get-Command winget -ErrorAction SilentlyContinue) {
        if ($PSCmdlet.ShouldProcess('JanDeDobbeleer.OhMyPosh', 'winget install')) {
            Info "  installing Oh My Posh..."
            winget install -e --id JanDeDobbeleer.OhMyPosh --accept-package-agreements --accept-source-agreements --silent | Out-Null
            Ok "Oh My Posh install attempted (reopen the shell to get it on PATH)"
        }
    } else { Warn "winget not found; install Oh My Posh manually from https://ohmyposh.dev" }
}

# --- 1. HKLM allow-list (conhost font picker) - REQUIRES ADMIN ---
Step "conhost font allow-list (HKLM)"
if (-not $isAdmin) {
    Warn "Not elevated - skipping the HKLM allow-list. Re-run AS ADMINISTRATOR to add '$NerdFont' to the conhost font picker. (Windows Terminal does not need this.)"
} else {
    $ttPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont'
    $tt = Get-ItemProperty $ttPath
    if ($tt.PSObject.Properties.Value -contains $NerdFont) { Ok "'$NerdFont' already in the allow-list" }
    elseif ($PSCmdlet.ShouldProcess($ttPath, "add '$NerdFont'")) {
        # conhost TrueType keys are named with incrementing zeros: 0, 00, 000, ...
        $n = 0; $name = '0'
        while ($tt.PSObject.Properties.Name -contains $name) { $n++; $name = '0' * ($n + 1) }
        New-ItemProperty -Path $ttPath -Name $name -Value $NerdFont -PropertyType String -Force | Out-Null
        Ok "added '$NerdFont' as key '$name'"
    }
}

# --- 2. HKCU console defaults (font + UTF-8 code page) - per-user, no admin ---
Step "conhost defaults (HKCU)"
if ($PSCmdlet.ShouldProcess('HKCU:\Console', "set FaceName='$NerdFont' + CodePage=65001")) {
    New-Item -Path 'HKCU:\Console' -Force | Out-Null
    Set-ItemProperty 'HKCU:\Console' -Name FaceName   -Value $NerdFont
    Set-ItemProperty 'HKCU:\Console' -Name FontFamily -Value 0x36   -Type DWord  # TrueType + fixed pitch (required or FaceName is ignored)
    Set-ItemProperty 'HKCU:\Console' -Name FontWeight -Value 0x190  -Type DWord  # 400 = normal
    Set-ItemProperty 'HKCU:\Console' -Name CodePage   -Value 0xFDE9 -Type DWord  # 0xFDE9 = 65001 decimal = UTF-8 (kills the mojibake)
    Ok "FaceName=$NerdFont, FontFamily=TrueType, CodePage=65001 (UTF-8)"
}

# --- 3. profile - UTF-8 encoding + Oh My Posh, as a NON-DESTRUCTIVE managed block ---
Step "PowerShell profile (`$PROFILE)"
$marker0 = '# >>> GMS console-font (managed) >>>'
$marker1 = '# <<< GMS console-font (managed) <<<'
$ompLine = if ($SkipOhMyPosh) { '' } else { "`r`n# Oh My Posh prompt (guarded so it can't error when OMP isn't installed)`r`nif (Get-Command oh-my-posh -ErrorAction SilentlyContinue) { oh-my-posh init pwsh | Invoke-Expression }" }
$block = @"
$marker0
# Render UTF-8 so powerline / Nerd Font glyphs (oh-my-posh) display correctly in conhost.
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::InputEncoding  = [System.Text.UTF8Encoding]::new()$ompLine
$marker1
"@

$existing = if (Test-Path $PROFILE) { Get-Content -LiteralPath $PROFILE -Raw } else { '' }
if ($null -eq $existing) { $existing = '' }
$pattern = '(?s)' + [regex]::Escape($marker0) + '.*?' + [regex]::Escape($marker1)
if ($existing -match $pattern) {
    $evaluator = [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $block }   # avoids $-substitution in the replacement
    $merged = [regex]::Replace($existing, $pattern, $evaluator)
    $action = 'updated existing managed block in'
} else {
    $merged = if ([string]::IsNullOrWhiteSpace($existing)) { $block } else { $existing.TrimEnd() + "`r`n`r`n" + $block }
    $action = 'added managed block to'
}

$profileDir = Split-Path -Parent $PROFILE
if ($PSCmdlet.ShouldProcess($PROFILE, 'write UTF-8 / Oh My Posh managed block (preserving existing content)')) {
    if ($profileDir -and -not (Test-Path $profileDir)) { New-Item -ItemType Directory -Force -Path $profileDir | Out-Null }
    Set-Content -LiteralPath $PROFILE -Value $merged -Encoding utf8   # PS7 'utf8' = no BOM
    Ok "$action $PROFILE"
    if ($PROFILE -like '*OneDrive*') { Warn "Note: \$PROFILE lives under OneDrive - it roams with your account." }
}

# --- 4. verify ---
Step "Verify"
$cp = [Console]::OutputEncoding.CodePage
if ($cp -eq 65001) { Ok "[Console]::OutputEncoding.CodePage = 65001 (UTF-8)" }
else { Info "  [Console]::OutputEncoding.CodePage = $cp in THIS session - new windows pick up 65001 from the profile" }
Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
Info "  '$NerdFont' installed: $($NerdFont -in ([System.Drawing.FontFamily]::Families.Name))"
Info "`nDone. Close ALL pwsh windows and open a new one for changes to take effect."
