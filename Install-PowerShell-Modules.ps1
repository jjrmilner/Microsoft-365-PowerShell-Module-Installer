#Requires -Version 5.1

<#
.SYNOPSIS
    Simplified Microsoft 365 PowerShell Module Installer with JSON Configuration

.DESCRIPTION
    A streamlined script that installs Microsoft 365 PowerShell modules based on a JSON configuration file.
    Users can easily enable/disable module categories or individual modules by editing the JSON file.

.PARAMETER ConfigFile
    Path to the JSON configuration file (default: modules-config.json)

.PARAMETER EnableCategories
    Comma-separated list of category names to enable (overrides JSON enabled settings)
    Example: "core,enterprise" or "core,powerplatform,azure"

.PARAMETER Force
    Force reinstall existing modules (skips existence check)

.PARAMETER Interactive
    Show configuration and prompt for confirmation before installation

.PARAMETER FixGraphVersions
    Automatically fix Microsoft Graph module version conflicts.

.EXAMPLE
    .\Install-ModulesSimple.ps1
    # Shows an interactive menu to select from predefined profiles

.EXAMPLE
    .\Install-ModulesSimple.ps1 -Profile security
    # Uses security profile directly (bypasses menu)

.EXAMPLE
    .\Install-ModulesSimple.ps1 -EnableServices "authentication,identity,exchange"
    # Installs only specified services regardless of profile

.EXAMPLE
    .\Install-ModulesSimple.ps1 -Interactive
    # Shows what will be installed and asks for confirmation (works with menu or parameters)

.EXAMPLE
    .\Install-ModulesSimple.ps1 -Silent
    # Silent mode for Intune deployment - auto-upgrades to PS7 and installs enterprise profile

.EXAMPLE
    .\Install-ModulesSimple.ps1 -Silent -Profile basic
    # Silent mode with specific profile (overrides default enterprise profile)

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
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Path to JSON configuration file")]
    [string]$ConfigFile = "modules-config.json",
    
    [Parameter(HelpMessage = "Comma-separated list of services to enable")]
    [string]$EnableServices,
    
    [Parameter(HelpMessage = "Predefined profile to use (basic, security, power, developer, enterprise)")]
    [string]$Profile,
    
    [Parameter(HelpMessage = "Force reinstall existing modules")]
    [switch]$Force,
    
    [Parameter(HelpMessage = "Interactive mode with confirmation prompts")]
    [switch]$Interactive,
    
    [Parameter(HelpMessage = "Fix Microsoft Graph module version conflicts")]
    [switch]$FixGraphVersions,
    
    [Parameter(HelpMessage = "Silent mode for automated deployment - auto-upgrades to PS7 and installs enterprise profile")]
    [switch]$Silent
)

# Colour configuration
$Colors = @{
    Header = 'Cyan'
    Success = 'Green'
    Warning = 'Yellow'
    Error = 'Red'
    Info = 'White'
    Progress = 'Magenta'
}

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White',
        [switch]$NoNewline
    )
    
    $params = @{
        Object = $Message
        ForegroundColor = $Color
    }
    
    if ($NoNewline) {
        $params.NoNewline = $true
    }
    
    Write-Host @params
}

function Remove-AllModules {
    param([object]$Config)
    
    Write-ColorOutput "`n$('='*80)" -Color $Colors.Error
    Write-ColorOutput "   MODULE CLEANUP - REMOVE ALL MODULES" -Color $Colors.Error
    Write-ColorOutput "            *** DESTRUCTIVE OPERATION ***" -Color $Colors.Error
    Write-ColorOutput $('='*80) -Color $Colors.Error
    
    Write-ColorOutput "`nThis will remove ALL PowerShell modules from the current user scope:" -Color $Colors.Warning
    Write-ColorOutput "- All Microsoft Graph modules" -Color $Colors.Info
    Write-ColorOutput "- Exchange Online Management" -Color $Colors.Info
    Write-ColorOutput "- Microsoft Teams" -Color $Colors.Info
    Write-ColorOutput "- PnP PowerShell" -Color $Colors.Info
    Write-ColorOutput "- Azure modules (if installed)" -Color $Colors.Info
    Write-ColorOutput "- Power Platform modules (if installed)" -Color $Colors.Info
    Write-ColorOutput "- Utility modules (ImportExcel, PSWriteWord, etc.)" -Color $Colors.Info
    
    Write-ColorOutput "`nWARNING: This cannot be undone! You will need to reinstall modules afterwards." -Color $Colors.Error
    Write-ColorOutput "`nType 'DELETE ALL MODULES' to confirm (case sensitive): " -Color $Colors.Error -NoNewline
    $confirmation = Read-Host
    
    if ($confirmation -eq 'DELETE ALL MODULES') {
        Write-ColorOutput "`nProceeding with module removal..." -Color $Colors.Warning
        
        # Build a list of all modules from the configuration
        $allModules = @()
        foreach ($serviceProperty in $Config.services.PSObject.Properties) {
            $service = $serviceProperty.Value
            foreach ($moduleProperty in $service.modules.PSObject.Properties) {
                $allModules += $moduleProperty.Name
            }
        }
        
        # Add specific wildcard searches for common module families
        $wildcardSearches = @(
            'Microsoft.Graph.*',
            'Az.*',
            'Microsoft.PowerApps.*',
            'Microsoft.Xrm.*'
        )
        
        # Find modules using wildcard searches
        foreach ($wildcardPattern in $wildcardSearches) {
            try {
                $foundModules = Get-InstalledModule -Name $wildcardPattern -ErrorAction SilentlyContinue
                foreach ($foundModule in $foundModules) {
                    $allModules += $foundModule.Name
                }
            } catch {
                # Wildcard search failed, skip
            }
        }
        
        # Add additional specific modules that might not be in config
        $additionalModules = @(
            'SharePointPnPPowerShellOnline',
            'Microsoft.Online.SharePoint.PowerShell'
        )
        
        $allModules += $additionalModules
        $allModules = $allModules | Sort-Object -Unique
        
        Write-ColorOutput "`nFound $($allModules.Count) unique modules to process" -Color $Colors.Info
        
        $removedCount = 0
        $errorCount = 0
        $skippedCount = 0
        
        Write-ColorOutput "`nRemoving modules..." -Color $Colors.Progress
        
        foreach ($moduleName in $allModules) {
            try {
                # Skip wildcard patterns in removal phase
                if ($moduleName -like '*.*') {
                    continue
                }
                
                Write-ColorOutput "`nProcessing: $moduleName" -Color $Colors.Info
                
                # Method 1: Try Get-InstalledModule (PowerShell Gallery modules)
                $installedModules = Get-InstalledModule -Name $moduleName -AllVersions -ErrorAction SilentlyContinue
                
                if ($installedModules) {
                    foreach ($module in $installedModules) {
                        Write-ColorOutput "  Removing $($module.Name) v$($module.Version) (PowerShell Gallery)..." -Color $Colors.Progress
                        try {
                            Uninstall-Module -Name $module.Name -RequiredVersion $module.Version -Force -ErrorAction Stop
                            $removedCount++
                            Write-ColorOutput "    [+] Removed successfully" -Color $Colors.Success
                        } catch {
                            Write-ColorOutput "    [!] Failed: $($_.Exception.Message)" -Color $Colors.Warning
                            $errorCount++
                        }
                    }
                } else {
                    # Method 2: Check if module exists via Get-Module -ListAvailable
                    $availableModules = Get-Module -Name $moduleName -ListAvailable -ErrorAction SilentlyContinue
                    
                    if ($availableModules) {
                        Write-ColorOutput "  Found $($availableModules.Count) version(s) via ListAvailable" -Color $Colors.Info
                        
                        # Try to remove using Uninstall-Module without version
                        try {
                            Write-ColorOutput "  Attempting removal without version specification..." -Color $Colors.Progress
                            Uninstall-Module -Name $moduleName -Force -AllVersions -ErrorAction Stop
                            $removedCount++
                            Write-ColorOutput "    [+] Removed successfully" -Color $Colors.Success
                        } catch {
                            # Method 3: Try manual removal from module paths
                            Write-ColorOutput "    [!] Standard removal failed, trying manual cleanup..." -Color $Colors.Warning
                            
                            $manualRemovalSuccess = $false
                            foreach ($module in $availableModules) {
                                try {
                                    $modulePath = Split-Path $module.ModuleBase -Parent
                                    if ($modulePath -and (Test-Path $modulePath)) {
                                        # Only remove if it's in user scope to be safe
                                        if ($modulePath -like "*$env:USERNAME*" -or $modulePath -like "*Documents*") {
                                            Write-ColorOutput "    Removing module folder: $modulePath" -Color $Colors.Progress
                                            Remove-Item -Path $modulePath -Recurse -Force -ErrorAction Stop
                                            $removedCount++
                                            $manualRemovalSuccess = $true
                                            Write-ColorOutput "    [+] Manual removal successful" -Color $Colors.Success
                                        } else {
                                            Write-ColorOutput "    [!] Skipping system-scope module at: $modulePath" -Color $Colors.Warning
                                        }
                                    }
                                } catch {
                                    Write-ColorOutput "    [!] Manual removal failed: $($_.Exception.Message)" -Color $Colors.Warning
                                }
                            }
                            
                            if (-not $manualRemovalSuccess) {
                                $errorCount++
                            }
                        }
                    } else {
                        Write-ColorOutput "  [SKIP] Module not found on system" -Color $Colors.Info
                        $skippedCount++
                    }
                }
            } catch {
                Write-ColorOutput "  [!] Error processing $moduleName`: $($_.Exception.Message)" -Color $Colors.Error
                $errorCount++
            }
        }
        
        # Also try to remove modules that might be loaded
        Write-ColorOutput "`nRemoving loaded modules from session..." -Color $Colors.Progress
        $loadedModules = Get-Module | Where-Object { 
            $_.Name -like "Microsoft.Graph*" -or 
            $_.Name -like "Az.*" -or 
            $_.Name -eq "ExchangeOnlineManagement" -or 
            $_.Name -eq "MicrosoftTeams" -or 
            $_.Name -like "PnP.*"
        }
        
        foreach ($module in $loadedModules) {
            try {
                Write-ColorOutput "  Unloading $($module.Name)..." -Color $Colors.Progress
                Remove-Module $module.Name -Force
            } catch {
                Write-ColorOutput "  [!] Could not unload $($module.Name)" -Color $Colors.Warning
            }
        }
        
        Write-ColorOutput "`n$('='*80)" -Color $Colors.Header
        Write-ColorOutput "MODULE CLEANUP RESULTS" -Color $Colors.Header
        Write-ColorOutput $('='*80) -Color $Colors.Header
        Write-ColorOutput "Modules removed: $removedCount" -Color $(if ($removedCount -gt 0) { $Colors.Success } else { $Colors.Info })
        Write-ColorOutput "Modules skipped (not found): $skippedCount" -Color $Colors.Info
        Write-ColorOutput "Errors encountered: $errorCount" -Color $(if ($errorCount -gt 0) { $Colors.Warning } else { $Colors.Success })
        
        if ($removedCount -gt 0) {
            Write-ColorOutput "`nCleanup completed successfully!" -Color $Colors.Success
            Write-ColorOutput "- $removedCount modules were removed from your system" -Color $Colors.Success
            Write-ColorOutput "- Restart PowerShell session for clean environment" -Color $Colors.Info
            Write-ColorOutput "- To reinstall modules, run this script again and select your profile" -Color $Colors.Info
        } elseif ($skippedCount -gt 0) {
            Write-ColorOutput "`nNo modules were found to remove." -Color $Colors.Info
            Write-ColorOutput "This could mean:" -Color $Colors.Info
            Write-ColorOutput "- Modules are not installed in current user scope" -Color $Colors.Info
            Write-ColorOutput "- Modules were installed via different methods" -Color $Colors.Info
            Write-ColorOutput "- System already clean" -Color $Colors.Info
        } else {
            Write-ColorOutput "`nNo modules were processed." -Color $Colors.Warning
        }
        
        if ($errorCount -gt 0) {
            Write-ColorOutput "`nSome modules could not be removed automatically." -Color $Colors.Warning
            Write-ColorOutput "This is normal for:" -Color $Colors.Info
            Write-ColorOutput "- System-installed modules (require admin privileges)" -Color $Colors.Info
            Write-ColorOutput "- Modules installed via MSI or other installers" -Color $Colors.Info
            Write-ColorOutput "- Dependency-locked modules" -Color $Colors.Info
        }
        
        Write-ColorOutput $('='*80) -Color $Colors.Header
        
    } else {
        Write-ColorOutput "`nCleanup cancelled - confirmation text did not match" -Color $Colors.Info
        return $false
    }
    
    return $true
}

function Show-ProfileMenu {
    param([object]$Config)
    
    Write-ColorOutput "`n$('='*80)" -Color $Colors.Header
    Write-ColorOutput "   MICROSOFT 365 POWERSHELL MODULE INSTALLER" -Color $Colors.Header
    Write-ColorOutput "            Select Installation Profile" -Color $Colors.Info
    Write-ColorOutput $('='*80) -Color $Colors.Header
    
    $profiles = @()
    $menuIndex = 1
    
    foreach ($profileProperty in $Config.profiles.PSObject.Properties) {
        $profileName = $profileProperty.Name
        $profileConfig = $profileProperty.Value
        
        # Calculate total modules for this profile
        $totalModules = 0
        foreach ($serviceName in $profileConfig.services) {
            $service = $Config.services.$serviceName
            if ($service) {
                foreach ($moduleProperty in $service.modules.PSObject.Properties) {
                    $moduleConfig = $moduleProperty.Value
                    $moduleEnabled = if ($moduleConfig.enabled -ne $null) { $moduleConfig.enabled } else { $true }
                    if ($moduleEnabled) {
                        $totalModules++
                    }
                }
            }
        }
        
        $profiles += @{
            Index = $menuIndex
            Name = $profileName
            DisplayName = $profileConfig.name
            Description = $profileConfig.description
            Services = $profileConfig.services
            ModuleCount = $totalModules
        }
        
        Write-ColorOutput "`n  [$menuIndex] $($profileConfig.name)" -Color $Colors.Success
        Write-ColorOutput "      $($profileConfig.description)" -Color $Colors.Info
        Write-ColorOutput "      Services: $($profileConfig.services.Count) ($($profileConfig.services -join ', '))" -Color $Colors.Progress
        Write-ColorOutput "      Modules: ~$totalModules modules will be installed" -Color $Colors.Progress
        
        $menuIndex++
    }
    
    # Add custom option
    Write-ColorOutput "`n  [$menuIndex] Custom Configuration" -Color $Colors.Warning
    Write-ColorOutput "      Use your customised JSON configuration settings" -Color $Colors.Info
    Write-ColorOutput "      Services: Based on 'enabled' settings in modules-config.json" -Color $Colors.Progress
    
    # Add cleanup option
    $cleanupIndex = $menuIndex + 1
    Write-ColorOutput "`n  [$cleanupIndex] Remove All Modules" -Color $Colors.Error
    Write-ColorOutput "      Completely remove all PowerShell modules (destructive operation)" -Color $Colors.Info
    Write-ColorOutput "      Use this to clean up for fresh installation or troubleshooting" -Color $Colors.Progress
    
    # Add exit option
    $exitIndex = $cleanupIndex + 1
    Write-ColorOutput "`n  [$exitIndex] Exit" -Color $Colors.Error
    Write-ColorOutput "      Cancel installation and exit" -Color $Colors.Info
    
    Write-ColorOutput "`n$('='*80)" -Color $Colors.Header
    Write-ColorOutput "Tip: You can also run with parameters:" -Color $Colors.Info
    Write-ColorOutput "  .\Install-ModulesSimple.ps1 -Profile basic" -Color $Colors.Success
    Write-ColorOutput "  .\Install-ModulesSimple.ps1 -EnableServices \"authentication,identity\"" -Color $Colors.Success
    Write-ColorOutput $('-'*80) -Color $Colors.Header
    
    do {
        Write-ColorOutput "`nSelect an option [1-$exitIndex]: " -Color $Colors.Warning -NoNewline
        $selection = Read-Host
        
        if ($selection -match '^\d+$') {
            $selectionNum = [int]$selection
            
            if ($selectionNum -ge 1 -and $selectionNum -le $profiles.Count) {
                $selectedProfile = $profiles[$selectionNum - 1]
                Write-ColorOutput "`n[+] Selected: $($selectedProfile.DisplayName)" -Color $Colors.Success
                Write-ColorOutput "  This will install approximately $($selectedProfile.ModuleCount) modules" -Color $Colors.Info
                Write-ColorOutput "  Services: $($selectedProfile.Services -join ', ')" -Color $Colors.Info
                return $selectedProfile.Name
            } elseif ($selectionNum -eq $menuIndex) {
                Write-ColorOutput "`n[+] Using custom JSON configuration" -Color $Colors.Success
                return $null # Use default configuration
            } elseif ($selectionNum -eq $cleanupIndex) {
                Write-ColorOutput "`n[!] Starting module cleanup process..." -Color $Colors.Warning
                $cleanupResult = Remove-AllModules -Config $Config
                if ($cleanupResult) {
                    # Cleanup completed, exit the script
                    exit 0
                } else {
                    # Cleanup cancelled, show menu again
                    Write-ColorOutput "`nReturning to main menu..." -Color $Colors.Info
                    Start-Sleep -Seconds 2
                    return Show-ProfileMenu -Config $Config
                }
            } elseif ($selectionNum -eq $exitIndex) {
                Write-ColorOutput "`nInstallation cancelled by user" -Color $Colors.Info
                exit 0
            } else {
                Write-ColorOutput "`n[!] Invalid selection. Please choose a number between 1 and $exitIndex" -Color $Colors.Error
            }
        } else {
            Write-ColorOutput "`n[!] Please enter a valid number" -Color $Colors.Error
        }
    } while ($true)
}

function Test-PowerShellVersion {
    Write-ColorOutput "`nChecking PowerShell compatibility..." -Color $Colors.Info
    
    $currentPSVersion = $PSVersionTable.PSVersion
    $currentPSEdition = $PSVersionTable.PSEdition
    
    Write-ColorOutput "Current PowerShell Version: $currentPSVersion" -Color $Colors.Info
    Write-ColorOutput "Current PowerShell Edition: $currentPSEdition" -Color $Colors.Info
    
    # Check if we're running PowerShell 7+
    if ($currentPSVersion.Major -ge 7) {
        Write-ColorOutput "[OPTIMAL] Running PowerShell 7+ - full compatibility enabled" -Color $Colors.Success
        return $true
    } elseif ($currentPSEdition -eq "Core" -and $currentPSVersion.Major -ge 6) {
        Write-ColorOutput "[GOOD] Running PowerShell Core 6+ - most features available" -Color $Colors.Success
        return $true
    } else {
        Write-ColorOutput "[SUBOPTIMAL] Running Windows PowerShell $currentPSVersion" -Color $Colors.Warning
        Write-ColorOutput "Recommendation: Upgrade to PowerShell 7 for best compatibility" -Color $Colors.Warning
        
        # Check if PowerShell 7 is available on the system
        $ps7Path = $null
        $ps7Locations = @(
            "${env:ProgramFiles}\PowerShell\7\pwsh.exe",
            "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe",
            "pwsh.exe"
        )
        
        foreach ($location in $ps7Locations) {
            if ($location -eq "pwsh.exe") {
                # Test if pwsh is in PATH
                try {
                    $null = Get-Command pwsh -ErrorAction Stop
                    $ps7Path = "pwsh"
                    break
                } catch {
                    continue
                }
            } elseif (Test-Path $location) {
                $ps7Path = $location
                break
            }
        }
        
        if ($ps7Path) {
            Write-ColorOutput "`nPowerShell 7 detected at: $ps7Path" -Color $Colors.Success
            
            if ($Silent) {
                Write-ColorOutput "Silent mode: Automatically restarting in PowerShell 7..." -Color $Colors.Warning
                $restartPS7 = $true
            } else {
                Write-ColorOutput "Would you like to restart this script in PowerShell 7? (Y/n): " -Color $Colors.Warning -NoNewline
                $response = Read-Host
                $restartPS7 = $response -notmatch '^[Nn]'
            }
            
            if ($restartPS7) {
                Write-ColorOutput "`nRestarting in PowerShell 7 for optimal experience..." -Color $Colors.Success
                
                # Get the current script path and parameters
                $currentScript = $MyInvocation.ScriptName
                if (-not $currentScript) {
                    $currentScript = $PSCommandPath
                }
                
                if ($currentScript) {
                    # Build parameter string for restart
                    $paramString = ""
                    if ($EnableServices) { $paramString += " -EnableServices `"$EnableServices`"" }
                    if ($Profile) { $paramString += " -Profile $Profile" }
                    if ($Force) { $paramString += " -Force" }
                    if ($Interactive) { $paramString += " -Interactive" }
                    if ($FixGraphVersions) { $paramString += " -FixGraphVersions" }
                    if ($Silent) { $paramString += " -Silent" }
                    
                    Write-ColorOutput "[AUTOMATED MODE] Restarted in PowerShell 7 for optimal experience" -Color $Colors.Header
                    
                    # Start PowerShell 7 with the current script and parameters
                    if ($Silent) {
                        # For silent mode, wait for completion and capture exit code
                        $process = Start-Process -FilePath $ps7Path -ArgumentList "-File `"$currentScript`"$paramString" -Wait -PassThru
                        exit $process.ExitCode
                    } else {
                        Start-Process -FilePath $ps7Path -ArgumentList "-File `"$currentScript`"$paramString" -Wait
                        exit 0
                    }
                } else {
                    Write-ColorOutput "[ERROR] Unable to determine current script path for restart" -Color $Colors.Error
                    if ($Silent) { exit 1 }
                }
            }
        } else {
            Write-ColorOutput "`nPowerShell 7 not found. Download from: https://github.com/PowerShell/PowerShell/releases" -Color $Colors.Info
            Write-ColorOutput "Continuing with current PowerShell version..." -Color $Colors.Warning
        }
        
        return $false
    }
}

function Get-ScriptDirectory {
    if ($PSScriptRoot) {
        return $PSScriptRoot
    } elseif ($MyInvocation.MyCommand.Path) {
        return Split-Path $MyInvocation.MyCommand.Path -Parent
    } else {
        return Get-Location
    }
}

function Load-Configuration {
    param([string]$ConfigPath)
    
    Write-ColorOutput "`nLoading configuration from: $ConfigPath" -Color $Colors.Info
    
    if (-not (Test-Path $ConfigPath)) {
        Write-ColorOutput "[ERROR] Configuration file not found: $ConfigPath" -Color $Colors.Error
        Write-ColorOutput "Please ensure modules-config.json exists in the script directory" -Color $Colors.Warning
        return $null
    }
    
    try {
        $jsonContent = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        Write-ColorOutput "[+] Configuration loaded successfully" -Color $Colors.Success
        return $jsonContent
    } catch {
        Write-ColorOutput "[ERROR] Failed to parse JSON configuration: $($_.Exception.Message)" -Color $Colors.Error
        return $null
    }
}

function Get-EnabledModules {
    param(
        [object]$Config,
        [string]$EnableServicesOverride,
        [string]$ProfileName
    )
    
    $enabledModules = @{}
    $servicesToEnable = @()
    
    # Determine which services to enable
    if ($ProfileName) {
        Write-ColorOutput "`nUsing profile: $ProfileName" -Color $Colors.Header
        $profileConfig = $Config.profiles.$ProfileName
        if ($profileConfig) {
            Write-ColorOutput "  Profile: $($profileConfig.name)" -Color $Colors.Info
            Write-ColorOutput "  Description: $($profileConfig.description)" -Color $Colors.Info
            $servicesToEnable = $profileConfig.services
        } else {
            Write-ColorOutput "[ERROR] Profile '$ProfileName' not found in configuration" -Color $Colors.Error
            return @{}
        }
    } elseif ($EnableServicesOverride) {
        $servicesToEnable = $EnableServicesOverride -split ',' | ForEach-Object { $_.Trim() }
        Write-ColorOutput "`nService override specified: $($servicesToEnable -join ', ')" -Color $Colors.Warning
    } else {
        # Use default enabled services from config
        $servicesToEnable = $Config.services.PSObject.Properties | 
            Where-Object { $_.Value.enabled -eq $true } | 
            ForEach-Object { $_.Name }
        Write-ColorOutput "`nEnabled services from config: $($servicesToEnable -join ', ')" -Color $Colors.Info
    }
    
    # Sort services by priority
    $sortedServices = $servicesToEnable | Sort-Object {
        $serviceConfig = $Config.services.$_
        if ($serviceConfig -and $serviceConfig.priority) {
            return $serviceConfig.priority
        } else {
            return 999
        }
    }
    
    Write-ColorOutput "`nProcessing services in priority order:" -Color $Colors.Header
    
    # Process each enabled service
    foreach ($serviceName in $sortedServices) {
        $service = $Config.services.$serviceName
        if (-not $service) {
            Write-ColorOutput "[WARNING] Service '$serviceName' not found in configuration" -Color $Colors.Warning
            continue
        }
        
        Write-ColorOutput "`n[$($service.priority)] $($service.name)" -Color $Colors.Header
        Write-ColorOutput "  Description: $($service.description)" -Color $Colors.Info
        
        $serviceModuleCount = 0
        foreach ($moduleProperty in $service.modules.PSObject.Properties) {
            $moduleName = $moduleProperty.Name
            $moduleConfig = $moduleProperty.Value
            
            # Check if module is enabled (default to true if not specified)
            $moduleEnabled = if ($moduleConfig.enabled -ne $null) { $moduleConfig.enabled } else { $true }
            
            if ($moduleEnabled) {
                $enabledModules[$moduleName] = $moduleConfig.version
                $requiredText = if ($moduleConfig.required) { " (Required)" } else { "" }
                Write-ColorOutput "    [+] $moduleName v$($moduleConfig.version)$requiredText" -Color $Colors.Success
                if ($moduleConfig.description) {
                    Write-ColorOutput "        $($moduleConfig.description)" -Color $Colors.Info
                }
                $serviceModuleCount++
            } else {
                Write-ColorOutput "    [-] $moduleName (disabled)" -Color $Colors.Warning
            }
        }
        
        Write-ColorOutput "  Modules enabled in this service: $serviceModuleCount" -Color $Colors.Info
    }
    
    return $enabledModules
}

function Show-InstallationSummary {
    param([hashtable]$ModulesToInstall)
    
    Write-ColorOutput "`n$('='*80)" -Color $Colors.Header
    Write-ColorOutput "INSTALLATION SUMMARY" -Color $Colors.Header
    Write-ColorOutput $('='*80) -Color $Colors.Header
    
    Write-ColorOutput "Total modules to process: $($ModulesToInstall.Count)" -Color $Colors.Info
    Write-ColorOutput "`nModules:" -Color $Colors.Header
    
    foreach ($module in $ModulesToInstall.GetEnumerator() | Sort-Object Key) {
        Write-ColorOutput "  [+] $($module.Key) v$($module.Value)" -Color $Colors.Success
    }
    
    Write-ColorOutput $('='*80) -Color $Colors.Header
}

function Install-ModulesSafely {
    param([hashtable]$ModulesToInstall)
    
    Write-ColorOutput "`nStarting module installation..." -Color $Colors.Header
    
    $results = @{}
    $currentCount = 0
    $totalCount = $ModulesToInstall.Count
    
    foreach ($module in $ModulesToInstall.GetEnumerator()) {
        $currentCount++
        $progressPercent = [math]::Round(($currentCount / $totalCount) * 100, 1)
        
        Write-ColorOutput "`n[$currentCount/$totalCount] Processing: $($module.Key)" -Color $Colors.Progress
        
        # Check if module already exists (unless Force is specified)
        $moduleExists = $false
        if (-not $Force) {
            try {
                $existing = Get-InstalledModule -Name $module.Key -ErrorAction SilentlyContinue
                if (-not $existing) {
                    $existing = Get-Module -Name $module.Key -ListAvailable -ErrorAction SilentlyContinue | 
                              Sort-Object Version -Descending | Select-Object -First 1
                }
                
                if ($existing) {
                    # Check if we should skip installation based on version requirements
                    $shouldSkip = $false
                    
                    if ($module.Value -eq "latest") {
                        # For "latest", check if a newer version is available
                        try {
                            Write-ColorOutput "  [CHECK] Checking for newer version than v$($existing.Version)..." -Color $Colors.Info
                            $availableVersion = Find-Module -Name $module.Key -ErrorAction Stop
                            
                            if ($existing.Version -lt $availableVersion.Version) {
                                Write-ColorOutput "  [UPDATE] Installed: v$($existing.Version), Available: v$($availableVersion.Version)" -Color $Colors.Warning
                                # Don't skip - allow update to latest
                            } else {
                                Write-ColorOutput "  [SKIP] Already have latest: v$($existing.Version)" -Color $Colors.Success
                                $shouldSkip = $true
                            }
                        } catch {
                            Write-ColorOutput "  [SKIP] Cannot check latest version - keeping v$($existing.Version)" -Color $Colors.Warning
                            $shouldSkip = $true
                        }
                    } else {
                        # For specific versions, check if installed version meets requirement
                        $requiredVersion = if ($module.Value -and $module.Value -ne '1.0.0') { $module.Value } else { $null }
                        
                        if (-not $requiredVersion -or $existing.Version -ge [version]$requiredVersion) {
                            Write-ColorOutput "  [SKIP] Already installed: v$($existing.Version)" -Color $Colors.Info
                            $shouldSkip = $true
                        } else {
                            Write-ColorOutput "  [UPDATE] Installed: v$($existing.Version), Required: v$requiredVersion" -Color $Colors.Warning
                        }
                    }
                    
                    if ($shouldSkip) {
                        $results[$module.Key] = $true
                        $moduleExists = $true
                    }
                }
            } catch {
                # Continue with installation if check fails
            }
        }
        
        if (-not $moduleExists) {
            try {
                Write-ColorOutput "  [INSTALL] Installing from PowerShell Gallery (CurrentUser scope)..." -Color $Colors.Progress
                
                $installParams = @{
                    Name = $module.Key
                    Scope = 'CurrentUser'
                    Force = $Force
                    AllowClobber = $true
                    ErrorAction = 'Stop'
                    WarningAction = 'SilentlyContinue'
                }
                
                # Check if specific version is required or if we should get latest
                if ($module.Value -and $module.Value -ne "latest" -and $module.Value -ne "1.0.0") {
                    $installParams.RequiredVersion = $module.Value
                    Write-ColorOutput "  Installing specific version: $($module.Value)" -Color $Colors.Info
                } else {
                    Write-ColorOutput "  Installing latest available version" -Color $Colors.Info
                }
                
                Install-Module @installParams
                
                # Get the actually installed version for confirmation
                $installedModule = Get-InstalledModule -Name $module.Key -ErrorAction SilentlyContinue
                if ($installedModule) {
                    Write-ColorOutput "  [SUCCESS] Installed v$($installedModule.Version) in CurrentUser scope" -Color $Colors.Success
                } else {
                    Write-ColorOutput "  [SUCCESS] Installation completed in CurrentUser scope" -Color $Colors.Success
                }
                
                $results[$module.Key] = $true
                
            } catch {
                Write-ColorOutput "  [FAILED] Error: $($_.Exception.Message)" -Color $Colors.Error
                $results[$module.Key] = $false
            }
        }
    }
    
    return $results
}

function Show-FinalResults {
    param([hashtable]$Results)
    
    $successful = ($Results.Values | Where-Object { $_ -eq $true }).Count
    $failed = ($Results.Values | Where-Object { $_ -eq $false }).Count
    
    Write-ColorOutput "`n$('='*80)" -Color $Colors.Header
    Write-ColorOutput "INSTALLATION RESULTS" -Color $Colors.Header
    Write-ColorOutput $('='*80) -Color $Colors.Header
    
    Write-ColorOutput "Successful: $successful" -Color $Colors.Success
    Write-ColorOutput "Failed: $failed" -Color $(if ($failed -gt 0) { $Colors.Error } else { $Colors.Success })
    
    if ($failed -gt 0) {
        Write-ColorOutput "`nFailed modules:" -Color $Colors.Error
        foreach ($result in $Results.GetEnumerator()) {
            if ($result.Value -eq $false) {
                Write-ColorOutput "  [!] $($result.Key)" -Color $Colors.Error
            }
        }
    }
    
    Write-ColorOutput "`nNext Steps:" -Color $Colors.Header
    Write-ColorOutput "1. Restart PowerShell session for optimal performance" -Color $Colors.Success
    Write-ColorOutput "2. Test module imports: Import-Module <ModuleName>" -Color $Colors.Success
    Write-ColorOutput "3. Connect to services: Connect-MgGraph, Connect-ExchangeOnline, etc." -Color $Colors.Success
    
    if ($FixGraphVersions -or $failed -gt 0) {
        Write-ColorOutput "`nTroubleshooting:" -Color $Colors.Warning
        Write-ColorOutput "- For Graph module conflicts: Update-Module Microsoft.Graph -Force" -Color $Colors.Info
        Write-ColorOutput "- For assembly errors: Restart PowerShell session" -Color $Colors.Info
    }
    
    Write-ColorOutput $('='*80) -Color $Colors.Header
}

# Main execution
try {
    Write-ColorOutput $('='*80) -Color $Colors.Header
    Write-ColorOutput "MICROSOFT 365 POWERSHELL MODULE INSTALLER - SIMPLIFIED" -Color $Colors.Header
    Write-ColorOutput "Configuration-driven module management" -Color $Colors.Info
    Write-ColorOutput $('='*80) -Color $Colors.Header
    
    # Check PowerShell version and offer upgrade to PowerShell 7
    $psOptimal = Test-PowerShellVersion
    
    # Resolve configuration file path
    $scriptDir = Get-ScriptDirectory
    if (-not [System.IO.Path]::IsPathRooted($ConfigFile)) {
        $ConfigFile = Join-Path $scriptDir $ConfigFile
    }
    
    # Load configuration
    $config = Load-Configuration -ConfigPath $ConfigFile
    if (-not $config) {
        exit 1
    }
    
    # Check if any parameters were provided, if not show interactive menu (unless Silent mode)
    $parametersProvided = $EnableServices -or $Profile -or $Force -or $Interactive -or $FixGraphVersions -or $Silent
    
    if ($Silent) {
        Write-ColorOutput "Silent mode: Using enterprise profile for comprehensive module installation" -Color $Colors.Info
        $Profile = "enterprise"
    } elseif (-not $parametersProvided) {
        Write-ColorOutput "No parameters provided. Starting interactive mode..." -Color $Colors.Info
        $selectedProfile = Show-ProfileMenu -Config $config
        Write-ColorOutput "[DEBUG] Menu returned profile: '$selectedProfile'" -Color Yellow
        $Profile = $selectedProfile
    }
    
    # Validate profile if provided
    if ($Profile) {
        $validProfiles = @('basic', 'security', 'power', 'developer', 'enterprise')
        if ($Profile -notin $validProfiles) {
            Write-ColorOutput "[ERROR] Invalid profile '$Profile'. Valid profiles are: $($validProfiles -join ', ')" -Color $Colors.Error
            exit 1
        }
        Write-ColorOutput "Using profile: $Profile" -Color $Colors.Info
    }
    
    # Get enabled modules
    $modulesToInstall = Get-EnabledModules -Config $config -EnableServicesOverride $EnableServices -ProfileName $Profile
    
    if ($modulesToInstall.Count -eq 0) {
        Write-ColorOutput "`n[WARNING] No modules are enabled for installation" -Color $Colors.Warning
        Write-ColorOutput "Edit $ConfigFile to enable module categories or use -EnableCategories parameter" -Color $Colors.Info
        exit 0
    }
    
    # Show installation summary
    Show-InstallationSummary -ModulesToInstall $modulesToInstall
    
    # Interactive confirmation (skip in Silent mode)
    if ($Interactive -and -not $Silent) {
        Write-ColorOutput "`nProceed with installation? (y/N): " -Color $Colors.Warning -NoNewline
        $response = Read-Host
        if ($response -notmatch '^[Yy]') {
            Write-ColorOutput "Installation cancelled by user" -Color $Colors.Info
            exit 0
        }
    } elseif ($Silent) {
        Write-ColorOutput "`nSilent mode: Proceeding with automatic installation..." -Color $Colors.Info
    }
    
    # Configure PowerShell Gallery
    Write-ColorOutput "`nConfiguring PowerShell Gallery..." -Color $Colors.Info
    if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Write-ColorOutput "[+] PSGallery set to trusted" -Color $Colors.Success
    } else {
        Write-ColorOutput "[+] PSGallery already trusted" -Color $Colors.Success
    }
    
    # Install modules
    $results = Install-ModulesSafely -ModulesToInstall $modulesToInstall
    
    # Show final results
    Show-FinalResults -Results $results
    
} catch {
    Write-ColorOutput "`n[CRITICAL ERROR] $($_.Exception.Message)" -Color $Colors.Error
    Write-ColorOutput "Stack trace: $($_.ScriptStackTrace)" -Color $Colors.Error
    exit 1

}

