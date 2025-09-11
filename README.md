# Microsoft 365 PowerShell Module Setup Script

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/License-Apache%202.0%20with%20Commons%20Clause-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey.svg)](https://www.microsoft.com/windows/)

**An intelligent, automated PowerShell script that sets up a comprehensive Microsoft 365 administration environment with zero configuration required.**

## 🚀 **Key Features**

- **🤖 Fully Automated** - Zero prompts or manual intervention required by default
- **⚡ PowerShell 7 Auto-Upgrade** - Automatically detects, installs, and switches to PowerShell 7 for optimal performance
- **🧠 Intelligent Compatibility** - Automatically adapts to PowerShell 5.1 limitations when needed
- **📊 Clear Progress Tracking** - Real-time progress indicators with batch summaries
- **🛡️ Function Capacity Management** - Prevents PowerShell 5.1 function limit issues (4096 limit)
- **🔧 Repository Trust Automation** - Automatically configures PowerShell Gallery as trusted
- **📋 Educational Interface** - Shows available options and current settings on every run
- **🎯 Comprehensive Coverage** - Installs all essential Microsoft 365 PowerShell modules

## 📦 **Modules Installed**

### **Essential Modules (Always Installed)**
- **Microsoft Graph SDK**
  - `Microsoft.Graph.Authentication` - Core authentication
  - `Microsoft.Graph.Users` - User management
  - `Microsoft.Graph.Groups` - Group operations
  - `Microsoft.Graph.Identity.SignIns` - Sign-in logs and authentication
  - `Microsoft.Graph.Identity.DirectoryManagement` - Directory operations
  - `Microsoft.Graph.Reports` - Usage and activity reports
  - `Microsoft.Graph.Security` - Security operations

- **Service-Specific Modules**
  - `ExchangeOnlineManagement` - Exchange Online & Security/Compliance
  - `MicrosoftTeams` - Teams administration
  - `SharePointPnPPowerShellOnline` - SharePoint Online (PowerShell 5.1 compatible)
  - `PnP.PowerShell` - Modern SharePoint Online (PowerShell 7+)

- **Productivity & Reporting**
  - `ImportExcel` - Excel file operations without Office
  - `PSWriteWord` - Word document creation without Office

### **Optional Modules (PowerShell 7+ with `-IncludeOptionalModules`)**
- `Microsoft.Graph.Sites` - SharePoint sites via Graph API
- `Microsoft.Graph.Teams` - Teams via Graph API
- `Microsoft.Graph.Files` - OneDrive and SharePoint files
- `Microsoft.Graph.DeviceManagement` - Intune device management
- `Microsoft.Graph.Compliance` - Purview compliance features

## 🎯 **Quick Start**

### **Default Installation (Recommended)**
```powershell
.\Install-PowerShell-Modules-Automated.ps1
```
**What happens:**
- ✅ Detects your PowerShell version
- ✅ Auto-installs PowerShell 7 if missing
- ✅ Restarts script in PowerShell 7 for optimal performance
- ✅ Installs all essential modules without prompts
- ✅ Provides clear progress tracking

### **With Progress Monitoring**
```powershell
.\Install-PowerShell-Modules-Automated.ps1 -PauseBetweenBatches
```
**Perfect for:**
- Watching installation progress
- Reviewing results between batches
- Learning what's being installed

### **Complete Installation**
```powershell
.\Install-PowerShell-Modules-Automated.ps1 -IncludeOptionalModules
```
**Includes:**
- All essential modules
- Large Graph modules (Sites, Teams, Files, etc.)
- Best with PowerShell 7 for no function limits

## 📋 **All Available Options**

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-Automated` | Fully automated installation without prompts | `True` |
| `-Interactive` | Enable prompts and user guidance | `False` |
| `-Force` | Force reinstall of existing modules | `False` |
| `-SkipVersionCheck` | Install any available version (faster) | `False` |
| `-Scope` | Installation scope (`CurrentUser`, `AllUsers`) | `CurrentUser` |
| `-IncludeOptionalModules` | Add large Graph modules | `False` |
| `-PowerShell5Compatible` | Force PowerShell 5.1 mode (skip PS7 upgrade) | `False` |
| `-PauseBetweenBatches` | Pause after each batch for review | `False` |
| `-ShowDetailedProgress` | Enhanced progress information | `False` |

### **Example Commands**

```powershell
# Default: Automated with PowerShell 7 upgrade
.\Install-PowerShell-Modules-Automated.ps1

# Monitoring-friendly with pauses
.\Install-PowerShell-Modules-Automated.ps1 -PauseBetweenBatches

# Interactive mode with forced reinstall
.\Install-PowerShell-Modules-Automated.ps1 -Interactive -Force

# Complete installation with all modules
.\Install-PowerShell-Modules-Automated.ps1 -IncludeOptionalModules -Force

# System-wide installation (requires admin)
.\Install-PowerShell-Modules-Automated.ps1 -Scope AllUsers

# PowerShell 5.1 compatibility mode
.\Install-PowerShell-Modules-Automated.ps1 -PowerShell5Compatible
```

## 🔧 **PowerShell Version Compatibility**

### **PowerShell 7+ (Recommended)**
- ✅ **Function Limit**: 65,000+ (virtually unlimited)
- ✅ **All modules supported**: Including modern PnP.PowerShell
- ✅ **Better performance**: Faster loading and execution
- ✅ **Cross-platform**: Windows, Linux, macOS

### **PowerShell 5.1 (Automatically Handled)**
- ⚠️ **Function Limit**: 4,096 (restrictive)
- ✅ **Compatibility mode**: Uses legacy-compatible modules
- ✅ **Smart module selection**: Excludes large Graph modules
- ✅ **Auto-upgrade option**: Script offers PowerShell 7 installation

## 📊 **Installation Process**

### **Automatic PowerShell 7 Upgrade Flow**
```
PowerShell 5.1 Detected
    ↓
Check for PowerShell 7
    ↓
Auto-install PowerShell 7 (winget/MSI)
    ↓
Restart script in PowerShell 7
    ↓
Install all modules optimally
```

### **Batch Installation Strategy**
```
[BATCH 1/3] Core Modules
├── ImportExcel
└── PSWriteWord

[BATCH 2/3] Graph Modules
├── Microsoft.Graph.Authentication
├── Microsoft.Graph.Users
├── Microsoft.Graph.Groups
├── Microsoft.Graph.Identity.SignIns
├── Microsoft.Graph.Identity.DirectoryManagement
├── Microsoft.Graph.Reports
└── Microsoft.Graph.Security

[BATCH 3/3] Service Modules
├── ExchangeOnlineManagement
├── MicrosoftTeams
└── PnP.PowerShell (PS7) / SharePointPnPPowerShellOnline (PS5.1)
```

## 🛠️ **Troubleshooting**

### **Common Issues**

#### **Function Capacity Exceeded (PowerShell 5.1)**
```
Function capacity 4096 has been exceeded for this scope
```
**Solution:** Let the script auto-upgrade to PowerShell 7, or run:
```powershell
winget install Microsoft.PowerShell
pwsh
.\Install-PowerShell-Modules-Automated.ps1
```

#### **Module Locking Warnings**
```
WARNING: The version 'X.X.X' of module 'PackageManagement' is currently in use
```
**Solution:** This is normal and can be ignored. The script handles this automatically.

#### **Repository Trust Prompts**
```
Are you sure you want to install the modules from 'PSGallery'?
```
**Solution:** Use automated mode (default) or run:
```powershell
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
```

### **Manual PowerShell 7 Installation**
If automatic installation fails:
```powershell
# Option 1: Winget
winget install Microsoft.PowerShell

# Option 2: Direct download
# Visit: https://github.com/PowerShell/PowerShell/releases
```

## 📚 **Post-Installation Usage**

### **Microsoft Graph**
```powershell
Import-Module Microsoft.Graph.Authentication
Connect-MgGraph -Scopes "User.ReadWrite.All"
Get-MgUser -Top 10
```

### **Exchange Online**
```powershell
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline
Get-Mailbox -ResultSize 10
```

### **SharePoint Online**
```powershell
# PowerShell 7
Import-Module PnP.PowerShell
Connect-PnPOnline -Url "https://tenant.sharepoint.com" -Interactive

# PowerShell 5.1
Import-Module SharePointPnPPowerShellOnline
Connect-PnPOnline -Url "https://tenant.sharepoint.com" -Interactive
```

### **Microsoft Teams**
```powershell
Import-Module MicrosoftTeams
Connect-MicrosoftTeams
Get-Team
```

## 🏗️ **Requirements**

- **Operating System**: Windows 10/11 or Windows Server 2016+
- **PowerShell**: 5.1+ (PowerShell 7+ automatically installed if missing)
- **Execution Policy**: `RemoteSigned` or `Unrestricted`
- **Internet Connection**: Required for module downloads
- **Permissions**: 
  - Standard user (for CurrentUser scope)
  - Administrator (for AllUsers scope)

### **Setting Execution Policy**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## 📖 **Script Features Breakdown**

### **🤖 Intelligent Automation**
- **Repository Trust**: Automatically configures PSGallery as trusted
- **Version Detection**: Smart PowerShell version compatibility handling
- **Error Recovery**: Graceful handling of module conflicts and locking
- **Progress Tracking**: Real-time installation progress with percentages

### **🧠 Smart Module Management**
- **Batch Processing**: Modules installed in optimized batches
- **Dependency Handling**: Ensures proper module load order
- **Conflict Resolution**: Handles module locking and version conflicts
- **Memory Optimization**: Prevents function capacity overflow

### **📊 User Experience**
- **Educational Interface**: Shows available options on every run
- **Progress Visibility**: Clear batch summaries and progress indicators
- **Pause Options**: Optional pauses between batches for review
- **Error Explanation**: Detailed error diagnosis and solutions

## 🔒 **Security**

- **Trusted Sources**: Only installs from PowerShell Gallery
- **Code Signing**: Script uses official Microsoft modules
- **Scope Control**: Defaults to CurrentUser (no admin required)
- **No Credentials**: Script doesn't handle or store credentials

## 📄 **License**

This project is licensed under the Apache License 2.0 with Commons Clause - see the [LICENSE](LICENSE) file for details.

### **Commons Clause Restriction**
The Software is provided under the Apache License 2.0, with the additional restriction that you may not sell the software or any derivative work whose value derives substantially from this software.

## 👨‍💻 **Author**

**JJ Milner** - Microsoft 365 Specialist

## 🤝 **Contributing**

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](../../issues).

### **Development Guidelines**
1. Maintain PowerShell 5.1 compatibility
2. Include comprehensive error handling
3. Add progress indicators for long operations
4. Update documentation for new features
5. Test on both PowerShell 5.1 and 7+

## ⭐ **Show Your Support**

Give a ⭐ if this project helped you set up your Microsoft 365 PowerShell environment!

## 📝 **Changelog**

### **v1.2.0** - Enhanced Automation & UX
- ✅ Added automatic PowerShell 7 installation and switching
- ✅ Improved progress tracking with percentages
- ✅ Added pause between batches option
- ✅ Enhanced error handling for module conflicts
- ✅ Added educational options display
- ✅ Improved color scheme for better readability

### **v1.1.0** - Compatibility & Diagnostics
- ✅ Added PowerShell 5.1 function capacity management
- ✅ Enhanced module import diagnostics
- ✅ Added troubleshooting guidance
- ✅ Improved batch installation strategy

### **v1.0.0** - Initial Release
- ✅ Core module installation functionality
- ✅ Basic compatibility detection
- ✅ Repository trust automation

---

## 🔗 **Related Resources**

- [Microsoft Graph PowerShell SDK Documentation](https://docs.microsoft.com/graph/powershell/get-started)
- [Exchange Online PowerShell Documentation](https://docs.microsoft.com/powershell/exchange/)
- [PnP PowerShell Documentation](https://pnp.github.io/powershell/)
- [PowerShell 7 Installation Guide](https://docs.microsoft.com/powershell/scripting/install/installing-powershell)

---

**Happy PowerShell scripting! 🚀**
