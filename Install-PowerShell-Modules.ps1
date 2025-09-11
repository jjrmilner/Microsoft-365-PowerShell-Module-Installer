#Requires -Version 5.1
<#
.SYNOPSIS
    Microsoft 365 PowerShell Module Setup Script with Issue Resolution
    
.DESCRIPTION
    Enhanced version that resolves common installation issues:
    - PowerShell version compatibility checks
    - Function capacity management for large Graph modules
    - Alternative modules for version conflicts
    - Memory optimization for module loading
    - Automated installation without prompts

.PARAMETER Force
    Forces reinstallation of modules even if they already exist.

.PARAMETER SkipVersionCheck
    Skips checking for the latest module versions and installs any available version.

.PARAMETER Scope
    Installation scope for modules. Default is 'CurrentUser' (recommended).

.PARAMETER IncludeOptionalModules
    Includes additional optional modules for advanced scenarios.

.PARAMETER PowerShell5Compatible
    Use PowerShell 5.1 compatible modules only.

.PARAMETER Automated
    Fully automated installation without prompts. This is the DEFAULT behavior.
    The script will automatically trust PSGallery and install modules without user interaction.

.PARAMETER Interactive
    Switch to interactive mode with prompts and user guidance.
    Use this if you want to see prompts and have control over each installation step.

.LICENSE
    Licensed under the Apache License, Version 2.0 (the "Apache License");
    you may not use this file except in compliance with the Apache License.
    You may obtain a copy of the Apache License at:
        http://www.apache.org/licenses/LICENSE-2.0

    This Software is provided under the Apache License with the following
    Commons Clause Restriction:

    "The license granted herein does not include, and the Apache License
    does not grant to you, the right to Sell the Software. For purposes of
    this restriction, “Sell” means practicing any or all of the rights
    granted to you under the Apache License to provide to third parties,
    for a fee or other consideration (including without limitation fees for
    hosting, consulting, implementation, or support services related to the
    Software), a product or service whose value derives, entirely or
    substantially, from the functionality of the Software. Any license notice
    or attribution required by the Apache License must also include this
    Commons Clause Restriction."

    For paid/professional use cases prohibited above, obtain a commercial
    license from Global Micro Solutions (Pty) Ltd: licensing@globalmicro.co.za

    .WARRANTY
    Distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
    either express or implied. See the Apache License for the specific language
    governing permissions and limitations under the License.


.AUTHOR
    JJ Milner
    Blog: https://jjrmilner.substack.com

.NOTES
    Author: JJ Milner
    Version: 1.2.0 - Enhanced with Automation
    Created: January 2025
    
    Fixes: PnP.PowerShell version requirements, Graph module function limits, automated installation
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Forces reinstallation of modules even if they already exist")]
    [switch]$Force,
    
    [Parameter(HelpMessage = "Skips checking for the latest module versions")]
    [switch]$SkipVersionCheck,
    
    [Parameter(HelpMessage = "Installation scope for modules")]
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser',
    
    [Parameter(HelpMessage = "Includes additional optional modules for advanced scenarios")]
    [switch]$IncludeOptionalModules,
    
    [Parameter(HelpMessage = "Use PowerShell 5.1 compatible modules only")]
    [switch]$PowerShell5Compatible,
    
    [Parameter(HelpMessage = "Fully automated installation without prompts (default behavior)")]
    [switch]$Automated = $true,
    
    [Parameter(HelpMessage = "Interactive mode with prompts and user guidance")]
    [switch]$Interactive,
    
    [Parameter(HelpMessage = "Internal parameter - indicates script was restarted in PowerShell 7")]
    [switch]$PowerShell7Restart,
    
    [Parameter(HelpMessage = "Pause after each batch to review progress")]
    [switch]$PauseBetweenBatches,
    
    [Parameter(HelpMessage = "Show detailed progress with module counts and status")]
    [switch]$ShowDetailedProgress
)

# Handle parameter logic - Interactive overrides default Automated behavior
if ($Interactive) {
    $Automated = $false
    Write-Host "[INTERACTIVE MODE] User requested interactive installation" -ForegroundColor Yellow
} else {
    # Automated is default, but show it clearly
    if ($PowerShell7Restart) {
        Write-Host "[AUTOMATED MODE] Restarted in PowerShell 7 for optimal experience" -ForegroundColor Green
    } else {
        Write-Host "[AUTOMATED MODE] Default behavior - checking for PowerShell 7 upgrade" -ForegroundColor Green
    }
}

# Enhanced module definitions with version compatibility
$RequiredModules = @{
    # Microsoft Graph PowerShell SDK (Core) - Essential for all Entra ID operations
    'Microsoft.Graph.Authentication' = '2.0.0'
    'Microsoft.Graph.Users' = '2.0.0'
    'Microsoft.Graph.Groups' = '2.0.0' 
    'Microsoft.Graph.Identity.SignIns' = '2.0.0'
    'Microsoft.Graph.Identity.DirectoryManagement' = '2.0.0'
    'Microsoft.Graph.Reports' = '2.0.0'
    'Microsoft.Graph.Security' = '2.0.0'
    
    # Service-Specific Modules - Direct service connections
    'ExchangeOnlineManagement' = '3.0.0'        # Exchange Online & Security/Compliance
    'MicrosoftTeams' = '5.0.0'                  # Teams administration
    
    # Export and Document Creation - Professional reporting capabilities
    'ImportExcel' = '7.0.0'                     # Excel files without Office
    'PSWriteWord' = '1.0.0'                     # Word documents without Office
}

# PowerShell 5.1 Compatible modules (alternatives for problematic modules)
$PowerShell5Modules = @{
    # Use older SharePoint module that works with PS 5.1
    'SharePointPnPPowerShellOnline' = '3.29.0'  # Legacy but PS 5.1 compatible
}

# Large Graph modules that may cause function capacity issues
$LargeGraphModules = @{
    'Microsoft.Graph.Sites' = '2.0.0'           # SharePoint sites via Graph
    'Microsoft.Graph.Teams' = '2.0.0'           # Teams via Graph  
    'Microsoft.Graph.Files' = '2.0.0'           # OneDrive, SharePoint files
    'Microsoft.Graph.DeviceManagement' = '2.0.0' # Intune device management
    'Microsoft.Graph.Compliance' = '2.0.0'      # Purview compliance features
}

# Color coding for output
$Colors = @{
    Header = 'Cyan'
    Success = 'Green'
    Warning = 'Yellow'
    Error = 'Red'
    Info = 'White'
    Progress = 'White'  # Changed from Magenta for better readability on black background
}

function Show-ScriptOptions {
    Write-ColorOutput "`nSCRIPT OPTIONS & CURRENT SETTINGS:" -Color $Colors.Header
    Write-ColorOutput $('-'*80) -Color $Colors.Header
    
    # Current settings
    Write-ColorOutput "Current Settings:" -Color $Colors.Info
    Write-ColorOutput "  Installation Scope: $Scope" -Color $Colors.Success
    Write-ColorOutput "  Automated Mode: $(if ($Automated) { 'Yes (default)' } else { 'No' })" -Color $Colors.Success
    Write-ColorOutput "  Interactive Mode: $(if ($Interactive) { 'Yes' } else { 'No' })" -Color $Colors.Success
    Write-ColorOutput "  Force Reinstall: $(if ($Force) { 'Yes' } else { 'No' })" -Color $Colors.Success
    Write-ColorOutput "  Skip Version Check: $(if ($SkipVersionCheck) { 'Yes' } else { 'No' })" -Color $Colors.Success
    Write-ColorOutput "  Include Optional Modules: $(if ($IncludeOptionalModules) { 'Yes' } else { 'No' })" -Color $Colors.Success
    Write-ColorOutput "  PowerShell 5.1 Compatible Only: $(if ($PowerShell5Compatible) { 'Yes' } else { 'No' })" -Color $Colors.Success
    Write-ColorOutput "  Pause Between Batches: $(if ($PauseBetweenBatches) { 'Yes' } else { 'No' })" -Color $Colors.Success
    Write-ColorOutput "  Show Detailed Progress: $(if ($ShowDetailedProgress) { 'Yes' } else { 'No' })" -Color $Colors.Success
    
    Write-ColorOutput "`nAvailable Options (for next time):" -Color $Colors.Header
    Write-ColorOutput "  -Interactive" -Color $Colors.Warning -NoNewline
    Write-ColorOutput "              Enable prompts and user guidance" -Color $Colors.Info
    Write-ColorOutput "  -Force" -Color $Colors.Warning -NoNewline
    Write-ColorOutput "                    Force reinstall of existing modules" -Color $Colors.Info
    Write-ColorOutput "  -SkipVersionCheck" -Color $Colors.Warning -NoNewline
    Write-ColorOutput "        Install any available version (faster)" -Color $Colors.Info
    Write-ColorOutput "  -Scope AllUsers" -Color $Colors.Warning -NoNewline
    Write-ColorOutput "           Install for all users (requires admin)" -Color $Colors.Info
    Write-ColorOutput "  -IncludeOptionalModules" -Color $Colors.Warning -NoNewline
    Write-ColorOutput "   Add large Graph modules (PS7+ recommended)" -Color $Colors.Info
    Write-ColorOutput "  -PowerShell5Compatible" -Color $Colors.Warning -NoNewline
    Write-ColorOutput "   Force PS 5.1 mode (skip PS7 upgrade)" -Color $Colors.Info
    Write-ColorOutput "  -PauseBetweenBatches" -Color $Colors.Warning -NoNewline
    Write-ColorOutput "      Pause after each batch for review" -Color $Colors.Info
    Write-ColorOutput "  -ShowDetailedProgress" -Color $Colors.Warning -NoNewline
    Write-ColorOutput "     Enhanced progress information" -Color $Colors.Info
    
    Write-ColorOutput "`nExample Commands:" -Color $Colors.Header
    Write-ColorOutput "  .\Install-PowerShell-Modules-Automated.ps1" -Color $Colors.Success
    Write-ColorOutput "    └─ Default: Automated, PowerShell 7 upgrade, essential modules" -Color $Colors.Info
    Write-ColorOutput "  .\Install-PowerShell-Modules-Automated.ps1 -PauseBetweenBatches" -Color $Colors.Success
    Write-ColorOutput "    └─ Same as default but pauses for review (recommended for monitoring)" -Color $Colors.Info
    Write-ColorOutput "  .\Install-PowerShell-Modules-Automated.ps1 -Interactive -Force" -Color $Colors.Success
    Write-ColorOutput "    └─ Interactive mode with forced reinstall" -Color $Colors.Info
    Write-ColorOutput "  .\Install-PowerShell-Modules-Automated.ps1 -IncludeOptionalModules -Force" -Color $Colors.Success
    Write-ColorOutput "    └─ Include large Graph modules and force reinstall" -Color $Colors.Info
    
    Write-ColorOutput $('-'*80) -Color $Colors.Header
}

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White',
        [switch]$NoNewline
    )
    
    if ($NoNewline) {
        Write-Host $Message -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Set-RepositoryTrust {
    Write-ColorOutput "`nConfiguring PowerShell Gallery repository..." -Color $Colors.Info
    
    try {
        # Check current repository policy
        $psGallery = Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue
        
        if ($psGallery) {
            Write-ColorOutput "Current PSGallery InstallationPolicy: $($psGallery.InstallationPolicy)" -Color $Colors.Info
            
            if ($psGallery.InstallationPolicy -eq 'Untrusted') {
                if ($Automated) {
                    Write-ColorOutput "[AUTOMATED] Setting PSGallery as Trusted to eliminate prompts..." -Color $Colors.Warning
                    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
                    
                    # Verify the change
                    $updated = Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue
                    if ($updated -and $updated.InstallationPolicy -eq 'Trusted') {
                        Write-ColorOutput "[+] SUCCESS: PSGallery is now Trusted - no prompts will appear" -Color $Colors.Success
                    } else {
                        Write-ColorOutput "[!] WARNING: Could not verify repository trust change" -Color $Colors.Warning
                    }
                } else {
                    Write-ColorOutput "[INTERACTIVE] PSGallery is currently Untrusted." -Color $Colors.Warning
                    Write-ColorOutput "You will be prompted for each module installation." -Color $Colors.Warning
                    Write-ColorOutput "`nTo eliminate prompts, choose one of these options:" -Color $Colors.Info
                    Write-ColorOutput "  1. Re-run with: -Automated (will set repository as trusted)" -Color $Colors.Success
                    Write-ColorOutput "  2. Manually run: Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted" -Color $Colors.Success
                    Write-ColorOutput "  3. Answer 'A' (Yes to All) when prompted during installation" -Color $Colors.Success
                }
            } else {
                Write-ColorOutput "[+] PSGallery is already trusted - no prompts expected" -Color $Colors.Success
            }
        } else {
            Write-ColorOutput "[!] PSGallery repository not found - using default settings" -Color $Colors.Warning
            if ($Automated) {
                Write-ColorOutput "[AUTOMATED] Will attempt to force installations to bypass prompts" -Color $Colors.Info
            }
        }
    }
    catch {
        Write-ColorOutput "[!] Could not configure repository: $($_.Exception.Message)" -Color $Colors.Error
        if ($Automated) {
            Write-ColorOutput "[AUTOMATED] Will use Force parameter to bypass prompts" -Color $Colors.Warning
        } else {
            Write-ColorOutput "Continuing with installation - you may see prompts..." -Color $Colors.Warning
        }
    }
}

function Test-PowerShellCompatibility {
    Write-ColorOutput "`nChecking PowerShell compatibility..." -Color $Colors.Info
    
    $psVersion = $PSVersionTable.PSVersion
    Write-ColorOutput "PowerShell Version: $($psVersion.ToString())" -Color $Colors.Info
    Write-ColorOutput "PowerShell Edition: $($PSVersionTable.PSEdition)" -Color $Colors.Info
    
    # Check if running Windows PowerShell 5.1
    $isWindowsPowerShell = $PSVersionTable.PSEdition -eq 'Desktop'
    $isPowerShell7Plus = $psVersion.Major -ge 7
    
    if ($isWindowsPowerShell) {
        Write-ColorOutput "[COMPATIBILITY MODE] Running Windows PowerShell 5.1" -Color $Colors.Warning
        Write-ColorOutput "Function capacity limit: 4096 (restrictive)" -Color $Colors.Warning
        
        # Check if PowerShell 7 is available
        $ps7Available = Test-PowerShell7Availability
        
        if ($ps7Available.IsInstalled) {
            Write-ColorOutput "[UPGRADE AVAILABLE] PowerShell 7 is installed: $($ps7Available.Version)" -Color $Colors.Success
            
            if ($Automated -and -not $Interactive) {
                Write-ColorOutput "[AUTO-UPGRADE] Switching to PowerShell 7 for optimal experience..." -Color $Colors.Success
                Restart-InPowerShell7
                return # This line won't execute as the script will restart
            } else {
                Write-ColorOutput "`nWould you like to restart this script in PowerShell 7? (Y/N)" -Color $Colors.Info
                Write-ColorOutput "Benefits: 16x higher function limits, all modern modules, better performance" -Color $Colors.Success
                $choice = Read-Host "Enter choice"
                if ($choice -eq 'Y' -or $choice -eq 'y') {
                    Restart-InPowerShell7
                    return
                }
            }
        } else {
            Write-ColorOutput "[UPGRADE RECOMMENDED] PowerShell 7 not found" -Color $Colors.Warning
            
            if ($Automated -and -not $Interactive) {
                Write-ColorOutput "[AUTO-INSTALL] Installing PowerShell 7 for optimal experience..." -Color $Colors.Success
                $installResult = Install-PowerShell7
                if ($installResult) {
                    Write-ColorOutput "[AUTO-UPGRADE] Restarting in PowerShell 7..." -Color $Colors.Success
                    Restart-InPowerShell7
                    return
                }
            } else {
                Write-ColorOutput "`nWould you like to install PowerShell 7 for the best experience? (Y/N)" -Color $Colors.Info
                Write-ColorOutput "Benefits: 16x higher function limits, all modern modules, better performance" -Color $Colors.Success
                Write-ColorOutput "Installation: Automatic via winget (keeps PowerShell 5.1 alongside)" -Color $Colors.Info
                $choice = Read-Host "Enter choice"
                if ($choice -eq 'Y' -or $choice -eq 'y') {
                    $installResult = Install-PowerShell7
                    if ($installResult) {
                        Write-ColorOutput "`nPowerShell 7 installed! Restart script in PowerShell 7? (Y/N)" -Color $Colors.Success
                        $restartChoice = Read-Host "Enter choice"
                        if ($restartChoice -eq 'Y' -or $restartChoice -eq 'y') {
                            Restart-InPowerShell7
                            return
                        }
                    }
                }
            }
        }
        
        Write-ColorOutput "`nContinuing with PowerShell 5.1 compatibility mode..." -Color $Colors.Info
        $script:PowerShell5Compatible = $true
    } else {
        Write-ColorOutput "[OPTIMAL ENVIRONMENT] Running PowerShell Core/7+" -Color $Colors.Success
        Write-ColorOutput "Function capacity limit: 65,000+ (virtually unlimited)" -Color $Colors.Success
    }
    
    return @{
        Version = $psVersion
        IsWindowsPowerShell = $isWindowsPowerShell
        IsPowerShell7Plus = $isPowerShell7Plus
    }
}

function Test-PowerShell7Availability {
    $ps7Paths = @(
        "${env:ProgramFiles}\PowerShell\7\pwsh.exe",
        "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe",
        "$env:LOCALAPPDATA\Microsoft\powershell\pwsh.exe"
    )
    
    foreach ($path in $ps7Paths) {
        if (Test-Path $path) {
            try {
                $version = & $path -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
                return @{
                    IsInstalled = $true
                    Path = $path
                    Version = $version
                }
            }
            catch {
                continue
            }
        }
    }
    
    # Also check if pwsh is in PATH
    try {
        $version = & pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>$null
        if ($version) {
            return @{
                IsInstalled = $true
                Path = 'pwsh'
                Version = $version
            }
        }
    }
    catch {
        # pwsh not in PATH
    }
    
    return @{
        IsInstalled = $false
        Path = $null
        Version = $null
    }
}

function Install-PowerShell7 {
    Write-ColorOutput "`nInstalling PowerShell 7..." -Color $Colors.Header
    
    try {
        # Check if winget is available
        $wingetAvailable = Get-Command winget -ErrorAction SilentlyContinue
        
        if ($wingetAvailable) {
            Write-ColorOutput "Installing PowerShell 7 via winget..." -Color $Colors.Info
            $process = Start-Process -FilePath "winget" -ArgumentList "install", "Microsoft.PowerShell", "--silent", "--accept-package-agreements", "--accept-source-agreements" -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0) {
                Write-ColorOutput "[+] PowerShell 7 installed successfully via winget" -Color $Colors.Success
                return $true
            } else {
                Write-ColorOutput "[!] Winget installation failed, trying alternative method..." -Color $Colors.Warning
            }
        } else {
            Write-ColorOutput "Winget not available, using alternative installation method..." -Color $Colors.Info
        }
        
        # Alternative: Download and install MSI
        Write-ColorOutput "Downloading PowerShell 7 installer..." -Color $Colors.Info
        $downloadUrl = "https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7-win-x64.msi"
        $installerPath = "$env:TEMP\PowerShell-7-win-x64.msi"
        
        # Download installer
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($downloadUrl, $installerPath)
        
        if (Test-Path $installerPath) {
            Write-ColorOutput "Installing PowerShell 7 from MSI..." -Color $Colors.Info
            $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$installerPath`"", "/quiet", "/norestart" -Wait -PassThru
            
            if ($process.ExitCode -eq 0) {
                Write-ColorOutput "[+] PowerShell 7 installed successfully via MSI" -Color $Colors.Success
                Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
                return $true
            } else {
                Write-ColorOutput "[!] MSI installation failed" -Color $Colors.Error
                Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
            }
        } else {
            Write-ColorOutput "[!] Could not download PowerShell 7 installer" -Color $Colors.Error
        }
        
    }
    catch {
        Write-ColorOutput "[!] PowerShell 7 installation failed: $($_.Exception.Message)" -Color $Colors.Error
    }
    
    Write-ColorOutput "`nManual installation instructions:" -Color $Colors.Info
    Write-ColorOutput "1. Install winget: https://aka.ms/getwinget" -Color $Colors.Success
    Write-ColorOutput "2. Run: winget install Microsoft.PowerShell" -Color $Colors.Success
    Write-ColorOutput "3. Or download from: https://github.com/PowerShell/PowerShell/releases" -Color $Colors.Success
    
    return $false
}

function Restart-InPowerShell7 {
    Write-ColorOutput "`nRestarting script in PowerShell 7..." -Color $Colors.Success
    
    $ps7Info = Test-PowerShell7Availability
    if (-not $ps7Info.IsInstalled) {
        Write-ColorOutput "[!] PowerShell 7 not found after installation attempt" -Color $Colors.Error
        return
    }
    
    # Build arguments to pass to PowerShell 7
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) {
        $scriptPath = $MyInvocation.MyCommand.Path
    }
    if (-not $scriptPath) {
        Write-ColorOutput "[!] Could not determine script path for restart" -Color $Colors.Error
        Write-ColorOutput "Please manually run the script in PowerShell 7:" -Color $Colors.Info
        Write-ColorOutput "  pwsh" -Color $Colors.Success
        Write-ColorOutput "  .\Install-PowerShell-Modules-Automated.ps1" -Color $Colors.Success
        return
    }
    
    $currentArgs = @()
    
    # Preserve current parameters
    if ($Force) { $currentArgs += '-Force' }
    if ($SkipVersionCheck) { $currentArgs += '-SkipVersionCheck' }
    if ($Scope -ne 'CurrentUser') { $currentArgs += "-Scope", $Scope }
    if ($IncludeOptionalModules) { $currentArgs += '-IncludeOptionalModules' }
    if ($PowerShell5Compatible) { $currentArgs += '-PowerShell5Compatible' }
    if ($Interactive) { $currentArgs += '-Interactive' }
    
    # Add special parameter to indicate this is a restart
    $currentArgs += '-PowerShell7Restart'
    
    $argumentString = ($currentArgs -join ' ')
    
    Write-ColorOutput "Executing: $($ps7Info.Path) -File `"$scriptPath`" $argumentString" -Color $Colors.Info
    
    try {
        # Start PowerShell 7 with the same script and parameters
        Start-Process -FilePath $ps7Info.Path -ArgumentList "-File", "`"$scriptPath`"", $argumentString -Wait
        Write-ColorOutput "`n[SUCCESS] Script completed in PowerShell 7" -Color $Colors.Success
        exit 0
    }
    catch {
        Write-ColorOutput "[!] Failed to restart in PowerShell 7: $($_.Exception.Message)" -Color $Colors.Error
        Write-ColorOutput "`nManual restart instructions:" -Color $Colors.Info
        Write-ColorOutput "1. Open PowerShell 7: pwsh" -Color $Colors.Success
        Write-ColorOutput "2. Navigate to script location" -Color $Colors.Success
        Write-ColorOutput "3. Run: .\Install-PowerShell-Modules-Automated.ps1" -Color $Colors.Success
    }
}

function Get-CompatibleModules {
    param([hashtable]$PSInfo)
    
    $AllModules = $RequiredModules.Clone()
    
    if ($PSInfo.IsWindowsPowerShell -or $PowerShell5Compatible) {
        Write-ColorOutput "`nApplying PowerShell 5.1 compatibility adjustments..." -Color $Colors.Warning
        
        # Add PowerShell 5.1 compatible SharePoint module
        foreach ($module in $PowerShell5Modules.GetEnumerator()) {
            $AllModules[$module.Key] = $module.Value
            Write-ColorOutput "  [+] Added $($module.Key) (PowerShell 5.1 compatible)" -Color $Colors.Success
        }
        
        # Reduce large Graph modules to prevent function capacity issues
        Write-ColorOutput "  [!] Reducing Graph modules to prevent function capacity limits" -Color $Colors.Warning
        foreach ($module in $LargeGraphModules.Keys) {
            if ($AllModules.ContainsKey($module)) {
                $AllModules.Remove($module)
                Write-ColorOutput "    - Excluded $module (will install separately if needed)" -Color $Colors.Info
            }
        }
    } else {
        # PowerShell 7+ - include modern PnP module
        $AllModules['PnP.PowerShell'] = '2.0.0'
        
        # Include optional large modules if requested
        if ($IncludeOptionalModules) {
            foreach ($module in $LargeGraphModules.GetEnumerator()) {
                $AllModules[$module.Key] = $module.Value
            }
        }
    }
    
    return $AllModules
}

function Install-ModulesInBatches {
    param(
        [hashtable]$Modules,
        [hashtable]$PSInfo
    )
    
    # Split modules into batches to avoid function capacity issues
    $coreModules = @{}
    $graphModules = @{}
    $serviceModules = @{}
    
    foreach ($module in $Modules.GetEnumerator()) {
        if ($module.Key -like "Microsoft.Graph.*") {
            $graphModules[$module.Key] = $module.Value
        } elseif ($module.Key -in @('ExchangeOnlineManagement', 'MicrosoftTeams', 'PnP.PowerShell', 'SharePointPnPPowerShellOnline')) {
            $serviceModules[$module.Key] = $module.Value
        } else {
            $coreModules[$module.Key] = $module.Value
        }
    }
    
    $installationResults = @{}
    $totalModules = $Modules.Count
    $processedModules = 0
    
    Write-ColorOutput "`nInstalling modules in optimized batches..." -Color $Colors.Info
    Write-ColorOutput "Total modules to install: $totalModules" -Color $Colors.Info
    Write-ColorOutput "$('='*80)" -Color $Colors.Header
    
    # Batch 1: Core modules (Excel, Word, etc.)
    if ($coreModules.Count -gt 0) {
        Write-ColorOutput "`n[BATCH 1/3] Installing core modules ($($coreModules.Count) modules)..." -Color $Colors.Header
        Write-ColorOutput "Modules: $($coreModules.Keys -join ', ')" -Color $Colors.Info
        Write-ColorOutput $('-'*80) -Color $Colors.Info
        
        $result1 = Install-ModuleBatch -Modules $coreModules -BatchName "Core" -ProcessedCount ([ref]$processedModules) -TotalCount $totalModules
        foreach ($item in $result1.GetEnumerator()) {
            $installationResults[$item.Key] = $item.Value
        }
        
        Show-BatchSummary -BatchName "Core" -Results $result1 -ProcessedCount $processedModules -TotalCount $totalModules
        
        if ($PauseBetweenBatches -or $Interactive) {
            Write-ColorOutput "`nPress Enter to continue to Graph modules batch..." -Color $Colors.Warning
            Read-Host
        } else {
            Start-Sleep -Seconds 2
        }
    }
    
    # Batch 2: Essential Graph modules only
    if ($graphModules.Count -gt 0) {
        Write-ColorOutput "`n[BATCH 2/3] Installing Graph modules ($($graphModules.Count) modules)..." -Color $Colors.Header
        Write-ColorOutput "Modules: $($graphModules.Keys -join ', ')" -Color $Colors.Info
        Write-ColorOutput $('-'*80) -Color $Colors.Info
        
        $essentialGraph = @{}
        $essentialModules = @('Microsoft.Graph.Authentication', 'Microsoft.Graph.Users', 'Microsoft.Graph.Groups')
        foreach ($essential in $essentialModules) {
            if ($graphModules.ContainsKey($essential)) {
                $essentialGraph[$essential] = $graphModules[$essential]
            }
        }
        
        if ($essentialGraph.Count -gt 0) {
            Write-ColorOutput "`n[BATCH 2a] Essential Graph modules first..." -Color $Colors.Header
            $result2 = Install-ModuleBatch -Modules $essentialGraph -BatchName "Essential Graph" -ProcessedCount ([ref]$processedModules) -TotalCount $totalModules
            foreach ($item in $result2.GetEnumerator()) {
                $installationResults[$item.Key] = $item.Value
            }
        }
        
        # Install remaining Graph modules one by one to avoid capacity issues
        $remainingGraph = $graphModules.Clone()
        foreach ($essential in $essentialModules) {
            if ($remainingGraph.ContainsKey($essential)) {
                $remainingGraph.Remove($essential)
            }
        }
        
        if ($remainingGraph.Count -gt 0) {
            Write-ColorOutput "`n[BATCH 2b] Additional Graph modules (individually)..." -Color $Colors.Header
            $remainingCount = 0
            foreach ($module in $remainingGraph.GetEnumerator()) {
                $remainingCount++
                Write-ColorOutput "`n  Installing $remainingCount/$($remainingGraph.Count): $($module.Key)" -Color $Colors.Progress
                
                $singleModule = @{$module.Key = $module.Value}
                $result = Install-ModuleBatch -Modules $singleModule -BatchName "Graph Individual" -ProcessedCount ([ref]$processedModules) -TotalCount $totalModules -SuppressBatchHeader
                foreach ($item in $result.GetEnumerator()) {
                    $installationResults[$item.Key] = $item.Value
                }
                
                # Small delay to prevent overwhelming the system
                Start-Sleep -Seconds 1
            }
        }
        
        $allGraphResults = @{}
        foreach ($item in $installationResults.GetEnumerator()) {
            if ($item.Key -like "Microsoft.Graph.*") {
                $allGraphResults[$item.Key] = $item.Value
            }
        }
        Show-BatchSummary -BatchName "Graph" -Results $allGraphResults -ProcessedCount $processedModules -TotalCount $totalModules
        
        if ($PauseBetweenBatches -or $Interactive) {
            Write-ColorOutput "`nPress Enter to continue to service modules batch..." -Color $Colors.Warning
            Read-Host
        } else {
            Start-Sleep -Seconds 2
        }
    }
    
    # Batch 3: Service-specific modules
    if ($serviceModules.Count -gt 0) {
        Write-ColorOutput "`n[BATCH 3/3] Installing service-specific modules ($($serviceModules.Count) modules)..." -Color $Colors.Header
        Write-ColorOutput "Modules: $($serviceModules.Keys -join ', ')" -Color $Colors.Info
        Write-ColorOutput $('-'*80) -Color $Colors.Info
        
        $result3 = Install-ModuleBatch -Modules $serviceModules -BatchName "Service" -ProcessedCount ([ref]$processedModules) -TotalCount $totalModules
        foreach ($item in $result3.GetEnumerator()) {
            $installationResults[$item.Key] = $item.Value
        }
        
        Show-BatchSummary -BatchName "Service" -Results $result3 -ProcessedCount $processedModules -TotalCount $totalModules
    }
    
    return $installationResults
}

function Show-BatchSummary {
    param(
        [string]$BatchName,
        [hashtable]$Results,
        [int]$ProcessedCount,
        [int]$TotalCount
    )
    
    $successCount = ($Results.Values | Where-Object { $_ -eq $true }).Count
    $failCount = ($Results.Values | Where-Object { $_ -eq $false }).Count
    $overallProgress = [math]::Round(($ProcessedCount / $TotalCount) * 100, 1)
    
    Write-ColorOutput "`n$('='*80)" -Color $Colors.Header
    Write-ColorOutput "  $BatchName BATCH SUMMARY" -Color $Colors.Header
    Write-ColorOutput "$('='*80)" -Color $Colors.Header
    Write-ColorOutput "  Modules in batch: $($Results.Count)" -Color $Colors.Info
    Write-ColorOutput "  Successful: $successCount" -Color $Colors.Success
    Write-ColorOutput "  Failed: $failCount" -Color $(if ($failCount -gt 0) { $Colors.Error } else { $Colors.Success })
    Write-ColorOutput "  Overall progress: $ProcessedCount/$TotalCount modules ($overallProgress%)" -Color $Colors.Progress
    
    # Show failed modules if any
    if ($failCount -gt 0) {
        Write-ColorOutput "`n  Failed modules:" -Color $Colors.Error
        foreach ($result in $Results.GetEnumerator()) {
            if ($result.Value -eq $false) {
                Write-ColorOutput "    [!] $($result.Key)" -Color $Colors.Error
            }
        }
    }
    
    # Show successful modules
    Write-ColorOutput "`n  Successfully installed:" -Color $Colors.Success
    foreach ($result in $Results.GetEnumerator()) {
        if ($result.Value -eq $true) {
            Write-ColorOutput "    [+] $($result.Key)" -Color $Colors.Success
        }
    }
    
    Write-ColorOutput "$('='*80)" -Color $Colors.Header
}

function Install-ModuleBatch {
    param(
        [hashtable]$Modules,
        [string]$BatchName,
        [ref]$ProcessedCount,
        [int]$TotalCount,
        [switch]$SuppressBatchHeader
    )
    
    $batchResults = @{}
    $successful = 0
    $failed = 0
    
    foreach ($module in $Modules.GetEnumerator()) {
        $ProcessedCount.Value++
        $progressPercent = [math]::Round(($ProcessedCount.Value / $TotalCount) * 100, 1)
        
        try {
            if (-not $SuppressBatchHeader) {
                Write-ColorOutput "  [$($ProcessedCount.Value)/$TotalCount - $progressPercent%] Installing $($module.Key)..." -Color $Colors.Progress -NoNewline
            } else {
                Write-ColorOutput "    Installing $($module.Key)..." -Color $Colors.Progress -NoNewline
            }
            
            # Check if module is currently loaded and might cause conflicts
            $moduleLoaded = Get-Module -Name $module.Key -ErrorAction SilentlyContinue
            if ($moduleLoaded) {
                Write-ColorOutput " [LOADED]" -Color $Colors.Warning -NoNewline
                # Try to remove the module first to avoid locking issues
                try {
                    Remove-Module -Name $module.Key -Force -ErrorAction SilentlyContinue
                    Write-ColorOutput " [UNLOADED]" -Color $Colors.Info -NoNewline
                }
                catch {
                    # Module removal failed, but continue
                    Write-ColorOutput " [LOCKED]" -Color $Colors.Warning -NoNewline
                }
            }
            
            $installParams = @{
                Name = $module.Key
                Scope = $Scope
                AllowClobber = $true
                ErrorAction = 'Stop'
                WarningAction = 'SilentlyContinue'  # Suppress version warnings
            }
            
            # Handle automation and force parameters properly
            if ($Automated) {
                # In automated mode, force installation to bypass any remaining prompts
                $installParams.Force = $true
                # Also add repository parameter for extra safety
                $installParams.Repository = 'PSGallery'
                Write-ColorOutput " [AUTO]" -Color $Colors.Success -NoNewline
            } elseif ($Force) {
                $installParams.Force = $true
                Write-ColorOutput " [FORCE]" -Color $Colors.Warning -NoNewline
            }
            
            if (-not $SkipVersionCheck) {
                $installParams.MinimumVersion = $module.Value
            }
            
            Install-Module @installParams
            Write-ColorOutput " [+] Success" -Color $Colors.Success
            $batchResults[$module.Key] = $true
            $successful++
        }
        catch {
            $errorMessage = $_.Exception.Message
            
            # Handle specific error types
            if ($errorMessage -like "*currently in use*" -or $errorMessage -like "*Retry the operation after closing*") {
                Write-ColorOutput " [!] Module Locked (continuing with existing version)" -Color $Colors.Warning
                # Treat as success since the module is available, just not updated
                $batchResults[$module.Key] = $true
                $successful++
            }
            elseif ($errorMessage -like "*untrusted repository*" -and $Automated) {
                Write-ColorOutput " [!] Trust Issue (may be normal)" -Color $Colors.Warning
                $batchResults[$module.Key] = $false
                $failed++
            }
            else {
                Write-ColorOutput " [!] Failed: $($_.Exception.Message)" -Color $Colors.Error
                $batchResults[$module.Key] = $false
                $failed++
            }
        }
    }
    
    if (-not $SuppressBatchHeader) {
        Write-ColorOutput "`n  $BatchName batch completed: $successful successful, $failed failed" -Color $Colors.Info
    }
    
    return $batchResults
}

function Test-ModuleImports {
    param([hashtable]$InstalledModules)
    
    Write-ColorOutput "`nTESTING MODULE IMPORTS - DETAILED DIAGNOSTICS..." -Color $Colors.Header
    Write-ColorOutput $('-'*80) -Color $Colors.Header
    
    $importResults = @{}
    $detailedErrors = @{}
    
    foreach ($moduleName in $InstalledModules.Keys) {
        if ($InstalledModules[$moduleName] -eq $true) {
            Write-ColorOutput "`nTesting import: $moduleName" -Color $Colors.Info
            
            try {
                # Get module info first
                $moduleInfo = Get-Module -Name $moduleName -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
                if ($moduleInfo) {
                    Write-ColorOutput "  Found version: $($moduleInfo.Version)" -Color $Colors.Info
                }
                
                # Attempt import with detailed error capture
                Write-ColorOutput "  Attempting import..." -Color $Colors.Progress -NoNewline
                Import-Module $moduleName -Force -ErrorAction Stop -WarningAction SilentlyContinue
                
                # Verify import was successful
                $importedModule = Get-Module -Name $moduleName
                if ($importedModule) {
                    Write-ColorOutput " [+] SUCCESS" -Color $Colors.Success
                    Write-ColorOutput "    Imported version: $($importedModule.Version)" -Color $Colors.Success
                    Write-ColorOutput "    Exported commands: $($importedModule.ExportedCommands.Count)" -Color $Colors.Info
                    $importResults[$moduleName] = $true
                } else {
                    Write-ColorOutput " [!] FAILED - Module not found after import" -Color $Colors.Error
                    $importResults[$moduleName] = $false
                    $detailedErrors[$moduleName] = "Module not found after import attempt"
                }
            }
            catch {
                Write-ColorOutput " [!] FAILED" -Color $Colors.Error
                $importResults[$moduleName] = $false
                $detailedErrors[$moduleName] = $_.Exception.Message
                
                Write-ColorOutput "    ERROR DETAILS:" -Color $Colors.Error
                Write-ColorOutput "    $($_.Exception.Message)" -Color $Colors.Error
                
                # Check for common issues
                if ($_.Exception.Message -like "*function capacity*") {
                    Write-ColorOutput "    DIAGNOSIS: Function capacity exceeded (4096 limit)" -Color $Colors.Warning
                    Write-ColorOutput "    SOLUTION: Import this module individually in a fresh session" -Color $Colors.Info
                } elseif ($_.Exception.Message -like "*PowerShell version*") {
                    Write-ColorOutput "    DIAGNOSIS: PowerShell version incompatibility" -Color $Colors.Warning
                    Write-ColorOutput "    SOLUTION: Upgrade to PowerShell 7+ or use legacy module" -Color $Colors.Info
                }
            }
        } else {
            Write-ColorOutput "`nSkipping $moduleName (installation failed)" -Color $Colors.Warning
            $importResults[$moduleName] = $false
            $detailedErrors[$moduleName] = "Module installation failed"
        }
    }
    
    # Summary of import results
    $successfulImports = ($importResults.Values | Where-Object { $_ -eq $true }).Count
    $failedImports = ($importResults.Values | Where-Object { $_ -eq $false }).Count
    
    Write-ColorOutput "`nIMPORT TEST SUMMARY:" -Color $Colors.Header
    Write-ColorOutput $('-'*80) -Color $Colors.Header
    Write-ColorOutput "  [+] Successful imports: $successfulImports" -Color $Colors.Success
    Write-ColorOutput "  [!] Failed imports: $failedImports" -Color $(if ($failedImports -gt 0) { $Colors.Error } else { $Colors.Success })
    
    return @{
        Results = $importResults
        Errors = $detailedErrors
        SuccessCount = $successfulImports
        FailureCount = $failedImports
    }
}

function Show-CompatibilityReport {
    param([hashtable]$PSInfo)
    
    Write-ColorOutput "`nCOMPATIBILITY REPORT:" -Color $Colors.Header
    Write-ColorOutput $('-'*60) -Color $Colors.Header
    
    if ($PSInfo.IsWindowsPowerShell) {
        Write-ColorOutput "[COMPATIBILITY MODE] Windows PowerShell 5.1 Detected" -Color $Colors.Warning
        Write-ColorOutput "`nAdjustments made for compatibility:" -Color $Colors.Info
        Write-ColorOutput "  [!] Large Graph modules limited to prevent function capacity errors" -Color $Colors.Warning
        Write-ColorOutput "  [+] SharePointPnPPowerShellOnline included (legacy but compatible)" -Color $Colors.Success
        
        if ($Automated) {
            Write-ColorOutput "`n[AUTOMATED MODE] No prompts will be shown during installation" -Color $Colors.Success
        } else {
            Write-ColorOutput "`n[INTERACTIVE MODE] You may see installation prompts" -Color $Colors.Info
            Write-ColorOutput "Use -Automated parameter to avoid prompts" -Color $Colors.Info
        }
    } else {
        Write-ColorOutput "[FULL COMPATIBILITY] PowerShell 7+ Detected" -Color $Colors.Success
        Write-ColorOutput "  [+] All modern modules supported" -Color $Colors.Success
        Write-ColorOutput "  [+] PnP.PowerShell available (latest SharePoint module)" -Color $Colors.Success
    }
}

function Show-PostInstallationGuidance {
    param([hashtable]$PSInfo)
    
    Write-ColorOutput "`nPOST-INSTALLATION GUIDANCE:" -Color $Colors.Header
    Write-ColorOutput $('-'*60) -Color $Colors.Header
    
    if ($PSInfo.IsWindowsPowerShell) {
        Write-ColorOutput "SharePoint Online Management (PowerShell 5.1):" -Color $Colors.Header
        Write-ColorOutput "  # Legacy SharePoint module" -Color $Colors.Info
        Write-ColorOutput "  Connect-PnPOnline -Url https://tenant.sharepoint.com -Interactive" -Color $Colors.Success
        Write-ColorOutput "  Get-PnPWeb" -Color $Colors.Success
        
        Write-ColorOutput "`nFunction Capacity Management:" -Color $Colors.Header
        Write-ColorOutput "  # If you encounter function capacity errors:" -Color $Colors.Info
        Write-ColorOutput "  Remove-Module Microsoft.Graph.* -Force" -Color $Colors.Warning
        Write-ColorOutput "  Import-Module Microsoft.Graph.Authentication" -Color $Colors.Success
        Write-ColorOutput "  Import-Module Microsoft.Graph.Users" -Color $Colors.Success
    } else {
        Write-ColorOutput "Modern SharePoint Management (PowerShell 7+):" -Color $Colors.Header
        Write-ColorOutput "  Connect-PnPOnline -Url https://tenant.sharepoint.com -Interactive" -Color $Colors.Success
        Write-ColorOutput "  Get-PnPSite" -Color $Colors.Success
    }
    
    Write-ColorOutput "`nRecommended Module Import Order:" -Color $Colors.Header
    Write-ColorOutput "  1. Import-Module Microsoft.Graph.Authentication" -Color $Colors.Success
    Write-ColorOutput "  2. Connect-MgGraph -Scopes 'User.ReadWrite.All'" -Color $Colors.Success
    Write-ColorOutput "  3. Import additional Graph modules as needed" -Color $Colors.Success
    Write-ColorOutput "  4. Connect to service-specific modules (Exchange, Teams)" -Color $Colors.Success
}

#
# MAIN EXECUTION
#

try {
    Write-ColorOutput "$('='*80)" -Color $Colors.Header
    Write-ColorOutput "    MICROSOFT 365 POWERSHELL SETUP - ENHANCED VERSION" -Color $Colors.Header
    Write-ColorOutput "                     by JJ Milner" -Color $Colors.Header
    Write-ColorOutput "             Compatibility Issue Resolution" -Color $Colors.Header
    if ($PowerShell7Restart) {
        Write-ColorOutput "                 [POWERSHELL 7 - OPTIMAL]" -Color $Colors.Success
    } elseif ($Automated) {
        Write-ColorOutput "                   [AUTOMATED MODE - DEFAULT]" -Color $Colors.Success
    } else {
        Write-ColorOutput "                   [INTERACTIVE MODE]" -Color $Colors.Warning
    }
    Write-ColorOutput "$('='*80)" -Color $Colors.Header
    
    # Show current options and available parameters
    Show-ScriptOptions
    
    # Configure repository trust for automated installation
    Set-RepositoryTrust
    
    # Check PowerShell compatibility
    $psInfo = Test-PowerShellCompatibility
    
    # Get compatible module list
    $compatibleModules = Get-CompatibleModules -PSInfo $psInfo
    
    # Show compatibility report
    Show-CompatibilityReport -PSInfo $psInfo
    
    Write-ColorOutput "`nMODULES TO INSTALL:" -Color $Colors.Header
    foreach ($module in $compatibleModules.GetEnumerator()) {
        Write-ColorOutput "  [+] $($module.Key)" -Color $Colors.Success
    }
    
    if (-not $Automated) {
        Write-ColorOutput "`nProceeding with installation in 3 seconds..." -Color $Colors.Info
        Write-ColorOutput "Press Ctrl+C to cancel" -Color $Colors.Warning
        Start-Sleep -Seconds 3
    } else {
        Write-ColorOutput "`n[AUTOMATED] Starting installation immediately..." -Color $Colors.Success
    }
    
    # Install modules in optimized batches
    $results = Install-ModulesInBatches -Modules $compatibleModules -PSInfo $psInfo
    
    # Show installation results
    $totalSuccess = ($results.Values | Where-Object {$_ -eq $true}).Count
    $totalFailed = ($results.Values | Where-Object {$_ -eq $false}).Count
    
    Write-ColorOutput "`nINSTALLATION SUMMARY:" -Color $Colors.Header
    Write-ColorOutput "  [+] Successful: $totalSuccess" -Color $Colors.Success
    Write-ColorOutput "  [!] Failed: $totalFailed" -Color $(if ($totalFailed -gt 0) { $Colors.Error } else { $Colors.Success })
    
    # Test module imports with detailed diagnostics
    if ($totalSuccess -gt 0) {
        $importResults = Test-ModuleImports -InstalledModules $results
        
        if ($importResults.FailureCount -eq 0) {
            Write-ColorOutput "`n[SUCCESS] All modules installed and imported successfully!" -Color $Colors.Success
            Show-PostInstallationGuidance -PSInfo $psInfo
        } else {
            Write-ColorOutput "`n[PARTIAL SUCCESS] $($importResults.SuccessCount) modules working, $($importResults.FailureCount) have import issues" -Color $Colors.Warning
            Write-ColorOutput "See detailed error analysis above for resolution steps." -Color $Colors.Info
            Show-PostInstallationGuidance -PSInfo $psInfo
        }
    } else {
        Write-ColorOutput "`n[INSTALLATION FAILED] No modules were successfully installed" -Color $Colors.Error
    }
    
}
catch {
    Write-ColorOutput "`nCRITICAL ERROR: $($_.Exception.Message)" -Color $Colors.Error
    exit 1
}
finally {
    Write-ColorOutput "`nScript completed at $(Get-Date)" -Color $Colors.Info
    Write-ColorOutput "Microsoft 365 PowerShell Module Setup Script by JJ Milner" -Color $Colors.Info
    
    if ($Automated) {
        Write-ColorOutput "`n[AUTOMATED MODE] Installation completed without prompts (default behavior)" -Color $Colors.Success
    } else {
        Write-ColorOutput "`n[INTERACTIVE MODE] Installation completed with user interaction" -Color $Colors.Info
    }
}