# Microsoft 365 PowerShell Module Installer - Intune Deployment Guide

## Intune PowerShell Script Configuration

### Script Settings
- **Run this script using the logged on credentials**: Yes
- **Enforce script signature check**: No
- **Run script in 64 bit PowerShell Host**: Yes

### Deployment Command
```powershell
# Place both files in same directory on Intune:
# 1. Install-Modules-Simple.ps1
# 2. modules-config.json

# Use this as your PowerShell script content for Intune:
.\Install-Modules-Simple.ps1 -Silent
```

### Alternative Deployment Commands

**Basic Profile (Minimal Modules):**
```powershell
.\Install-Modules-Simple.ps1 -Silent -Profile basic
```

**Security Administrator Profile:**
```powershell
.\Install-Modules-Simple.ps1 -Silent -Profile security
```

**Force Reinstall (Troubleshooting):**
```powershell
.\Install-Modules-Simple.ps1 -Silent -Force
```

### What Happens in Silent Mode

1. **Automatic PowerShell 7 Detection & Upgrade**
   - Detects if PowerShell 7 is available
   - Automatically restarts in PowerShell 7 without user prompt
   - Continues in Windows PowerShell 5.1 if PS7 not available

2. **Automatic Profile Selection**
   - Uses "enterprise" profile by default (comprehensive module set)
   - Can be overridden with -Profile parameter

3. **No User Interaction**
   - Bypasses interactive menu
   - Skips confirmation prompts
   - Installs silently in background

4. **Error Handling**
   - Returns appropriate exit codes for Intune reporting
   - Logs all output for troubleshooting

### Exit Codes

- **0**: Success - All modules installed successfully
- **1**: Error - Configuration file not found or parsing failed
- **Other**: PowerShell error codes from module installation failures

### Modules Installed (Enterprise Profile)

**Authentication & Core:**
- Microsoft.Graph.Authentication v2.0.0
- MSAL.PS v2.0.0

**Identity Management:**
- Microsoft.Graph.Users v2.0.0
- Microsoft.Graph.Groups v2.0.0

**Service Administration:**
- ExchangeOnlineManagement (latest)
- MicrosoftTeams (latest)
- PnP.PowerShell (latest)

**Security & Compliance:**
- Microsoft.Graph.Security (latest)
- Microsoft.Graph.Identity.SignIns (latest)
- Microsoft.Graph.Identity.Governance (latest)

**Reporting & Analytics:**
- Microsoft.Graph.Reports (latest)
- ImportExcel (latest)
- PSWriteWord (latest)

**Power Platform:**
- Microsoft.PowerApps.Administration.PowerShell (latest)
- Microsoft.PowerApps.PowerShell (latest)
- Microsoft.Xrm.Data.PowerShell (latest)

**Azure Integration:**
- Az.Accounts (latest)
- Az.Resources (latest)
- Az.Storage (latest)

**Development Tools:**
- PSScriptAnalyzer (latest)
- Pester (latest)

### Troubleshooting

**Common Issues:**
1. **Execution Policy**: Ensure PowerShell execution policy allows script execution
2. **Internet Access**: Requires access to PowerShell Gallery (https://www.powershellgallery.com)
3. **Module Conflicts**: Use -Force parameter to resolve existing module conflicts

**Testing Before Deployment:**
```powershell
# Test on a single machine first
.\Install-Modules-Simple.ps1 -Silent -Interactive
```

**Cleanup for Testing:**
```powershell
# Remove all modules for clean testing
.\Install-Modules-Simple.ps1
# Select option 7 (Remove All Modules)
```

### Network Requirements

**Required URLs for PowerShell Gallery:**
- https://www.powershellgallery.com
- https://onegetcdn.azureedge.net
- https://go.microsoft.com

**Required for PowerShell 7 Download (if needed):**
- https://github.com/PowerShell/PowerShell/releases

### Security Considerations

- Script installs modules in CurrentUser scope (no admin rights required)
- Uses only official PowerShell Gallery sources
- Validates module signatures automatically
- Supports corporate proxy configurations

### Deployment Timeline

**Typical Installation Time:**
- PowerShell 5.1: 5-10 minutes for enterprise profile
- PowerShell 7: 3-7 minutes for enterprise profile
- Network speed dependent

**Staged Deployment Recommended:**
1. Test group: 5-10 users
2. Pilot group: 50-100 users  
3. Full deployment: All users

### Monitoring & Reporting

**Intune Reporting:**
- Monitor via Intune > Scripts > Install-Modules-Simple
- Check exit codes and execution logs
- Review failed deployments for troubleshooting

**Manual Verification:**
```powershell
# Verify installation on target machine
Get-InstalledModule Microsoft.Graph.*
Get-InstalledModule ExchangeOnlineManagement
Get-InstalledModule MicrosoftTeams
```

This configuration provides a fully automated, silent deployment suitable for enterprise environments via Microsoft Intune.