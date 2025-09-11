# Microsoft 365 PowerShell Module Installer - Service-Based Architecture

## Overview

This installer uses a scalable, service-based organization that mirrors how Microsoft 365 services are actually structured. Instead of arbitrary categories, modules are organized by the services they manage, making it intuitive and future-proof.

## Scalable Architecture Benefits

### Service-Based Organization
Modules are grouped by the Microsoft 365 service they manage:
- **Authentication** - Core authentication modules
- **Identity** - User and directory management  
- **Exchange** - Email and calendar administration
- **Teams** - Microsoft Teams management
- **SharePoint** - SharePoint Online administration
- **Security** - Security alerts and compliance
- **Reporting** - Analytics and data visualization
- **Power Platform** - Power Apps, Automate, BI
- **Azure** - Azure service integration
- **Development** - Development and automation tools

### Priority-Based Installation
Services install in logical order based on dependencies:
1. Authentication (required first)
2. Identity (users/groups)
3. Core services (Exchange, Teams, SharePoint)
4. Specialized services (Security, Power Platform)

### Predefined Profiles
Common combinations for different admin roles:

| Profile | Services Included | Use Case |
|---------|------------------|----------|
| `basic` | Authentication, Identity, Exchange, Teams, SharePoint, Reporting | Day-to-day M365 admin |
| `security` | Basic + Security/Compliance | Security administrator |
| `power` | Authentication, Identity, Power Platform, Reporting | Power Platform admin |
| `developer` | Basic + Development tools | Script development |
| `enterprise` | All services | Full enterprise admin |

## Quick Start

### Interactive Menu (Recommended for New Users)
```powershell
.\Install-Modules-Simple.ps1
```
When run without parameters, the script displays an interactive menu:
```
================================================================================
   MICROSOFT 365 POWERSHELL MODULE INSTALLER
            Select Installation Profile
================================================================================

  [1] Basic Administrator
      Essential modules for day-to-day Microsoft 365 administration
      Services: 6 (authentication, identity, exchange, teams, sharepoint, reporting)
      Modules: ~10 modules will be installed

  [2] Security Administrator  
      Core modules plus security and compliance tools
      Services: 7 (authentication, identity, exchange, teams, sharepoint, security, reporting)
      Modules: ~13 modules will be installed

  [3] Power Platform Administrator
      Core modules plus Power Platform administration
      Services: 4 (authentication, identity, powerplatform, reporting)
      Modules: ~8 modules will be installed

  [4] Developer/Automation
      Core modules plus development and automation tools
      Services: 7 (authentication, identity, exchange, teams, sharepoint, development, reporting)
      Modules: ~13 modules will be installed

  [5] Enterprise Administrator
      All modules for comprehensive Microsoft 365 and Azure management
      Services: 10 (all services)
      Modules: ~25 modules will be installed

  [6] Custom Configuration
      Use your customized JSON configuration settings
      Services: Based on 'enabled' settings in modules-config.json

  [7] Exit
      Cancel installation and exit

Select an option [1-7]:
```

### Direct Profile Usage (Advanced Users)
```powershell
# Basic Microsoft 365 administration
.\Install-Modules-Simple.ps1 -Profile basic

# Security administrator
.\Install-Modules-Simple.ps1 -Profile security

# Power Platform administrator  
.\Install-Modules-Simple.ps1 -Profile power

# Full enterprise setup
.\Install-Modules-Simple.ps1 -Profile enterprise
```

### Custom Service Selection
```powershell
# Only authentication and identity
.\Install-Modules-Simple.ps1 -EnableServices "authentication,identity"

# Exchange and Teams only
.\Install-Modules-Simple.ps1 -EnableServices "authentication,exchange,teams"
```

## Service Details

### 🔐 Authentication & Core
**Essential for all Microsoft 365 operations**
- Microsoft.Graph.Authentication (required)
- MSAL.PS (advanced authentication scenarios)

### 👥 Identity & Directory Management  
**User, group, and directory administration**
- Microsoft.Graph.Users (user management)
- Microsoft.Graph.Groups (group management)
- Microsoft.Graph.Identity.DirectoryManagement (directory roles)
- Microsoft.Graph.Applications (app registrations)

### 📧 Exchange Online
**Email, calendar, and Exchange administration**
- ExchangeOnlineManagement (complete Exchange management)

### 💬 Microsoft Teams
**Teams administration and management**
- MicrosoftTeams (Teams admin module)
- Microsoft.Graph.Teams (Graph API access)

### 🌐 SharePoint Online
**SharePoint sites, lists, and content management**
- PnP.PowerShell (modern, recommended)
- Microsoft.Graph.Sites (Graph API access)
- Microsoft.Online.SharePoint.PowerShell (legacy)

### 🔒 Security & Compliance
**Security alerts, policies, and compliance features**
- Microsoft.Graph.Security (security center)
- Microsoft.Graph.Identity.SignIns (conditional access)
- Microsoft.Graph.Identity.Governance (PIM, access reviews)

### 📊 Reporting & Analytics
**Usage reports, analytics, and data visualization**
- Microsoft.Graph.Reports (M365 usage reports)
- ImportExcel (Excel file manipulation)
- PSWriteWord (Word document generation)
- PSWriteHTML (HTML report generation)

### ⚡ Power Platform
**Power Apps, Power Automate, Power BI administration**
- Microsoft.PowerApps.Administration.PowerShell
- Microsoft.PowerApps.PowerShell
- Microsoft.Xrm.Data.PowerShell (Dataverse)

### ☁️ Azure Integration
**Azure services that integrate with Microsoft 365**
- Az.Accounts (Azure authentication)
- Az.Resources (resource management)
- Az.Storage (storage services)
- Az.KeyVault (secret management)

### 🛠️ Development & Automation
**Tools for PowerShell development and CI/CD**
- PSScriptAnalyzer (code quality)
- Pester (testing framework)
- Posh-Git (Git integration)

## Configuration Customization

### Version Management Strategies

The configuration uses a **balanced approach** that optimizes for both stability and security:

**Core Modules (Pinned for Stability):**
```json
"Microsoft.Graph.Authentication": {
    "version": "2.0.0",  // Core authentication - stability critical
    "description": "Required for all Graph operations",
    "enabled": true,
    "required": true
},
"Microsoft.Graph.Users": {
    "version": "2.0.0",  // Essential identity management
    "description": "User account management and properties",
    "enabled": true
}
```

**Peripheral Modules (Latest for Updates):**
```json
"ExchangeOnlineManagement": {
    "version": "latest",  // Service-specific modules benefit from updates
    "description": "Exchange Online administration",
    "enabled": true
},
"Microsoft.Graph.Security": {
    "version": "latest",  // Security modules need latest threat intelligence
    "description": "Security alerts and incidents",
    "enabled": true
}
```

**Utility Modules (Latest for Features):**
```json
"ImportExcel": {
    "version": "latest",  // Utility modules - new features rarely break
    "description": "Excel file manipulation",
    "enabled": true
}
```

**Balanced Approach Rationale:**
- **Pin core modules** (Authentication, Users, Groups) for environment stability
- **Use "latest" for service modules** (Exchange, Teams, SharePoint) to get improvements
- **Use "latest" for security modules** to get threat intelligence updates
- **Use "latest" for utility modules** (Excel, Word) for new features and bug fixes

**Version Update Behavior:**
- **Pinned modules**: Only update when you change the version number in JSON
- **"Latest" modules**: Automatically update when newer versions are available
- **Mixed versions**: Some modules update while core stability is maintained

### Enable/Disable Entire Services
```json
"teams": {
    "enabled": false,    // Disable all Teams modules
    "modules": { ... }
}
```

### Enable/Disable Individual Modules
```json
"Microsoft.Graph.Teams": {
    "enabled": false,    // Keep Teams admin but disable Graph API
    "version": "2.0.0"
}
```

### Create Custom Profiles
```json
"profiles": {
    "custom_team": {
        "name": "My Team Setup",
        "description": "Custom modules for our team",
        "services": ["authentication", "exchange", "reporting"]
    }
}
```

### Add New Services
```json
"newservice": {
    "name": "New Microsoft Service",
    "description": "Newly released service modules",
    "enabled": false,
    "priority": 11,
    "modules": {
        "Microsoft.NewService.PowerShell": {
            "version": "1.0.0",
            "enabled": true
        }
    }
}
```

## Scalability Features

### Easy Extension
- **New Microsoft services** → Add new service section
- **Service updates** → Update modules within existing services
- **Version management** → Update versions without structural changes

### Logical Organization
- **Service-aligned** → Modules grouped by actual Microsoft 365 services
- **Dependency-aware** → Priority-based installation order
- **Role-based** → Profiles match real administrative roles

### Maintenance Benefits
- **Clear ownership** → Each service section has clear purpose
- **Future-proof** → Structure adapts to new Microsoft services
- **Documentation** → Each module includes purpose and description

## Migration Guide

### From Parameter-Based Script
| Old Method | New Method |
|------------|------------|
| `-IncludeEnterprise` | `-Profile enterprise` |
| `-IncludePowerPlatform` | `-EnableServices "powerplatform"` |
| `-IncludeAll` | `-Profile enterprise` |
| Multiple parameters | Single profile parameter |

### From Category-Based Config
| Old Category | New Services |
|--------------|--------------|
| `core` | `authentication`, `identity`, `exchange`, `teams`, `sharepoint` |
| `enterprise` | `security` |
| `powerplatform` | `powerplatform` |
| `azure` | `azure` |
| `devops` | `development` |

## Best Practices

### Starting Points
- **New to M365**: Use `-Profile basic`
- **Security focus**: Use `-Profile security`  
- **Power Platform**: Use `-Profile power`
- **Custom needs**: Create custom profile in JSON

### Maintenance
- **Version updates**: Update version numbers in JSON
- **New modules**: Add to appropriate service section
- **Deprecations**: Set `"enabled": false` instead of deleting

### Development
- **Testing**: Use `-Interactive` to preview changes
- **Automation**: Use profiles in scripts and CI/CD
- **Documentation**: Leverage built-in descriptions

This service-based architecture makes the system much more maintainable and scales naturally with Microsoft's service evolution.
