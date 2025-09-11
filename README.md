================================================================================
    MICROSOFT 365 POWERSHELL SETUP - ENHANCED VERSION
                     by JJ Milner
             Compatibility Issue Resolution
                   [AUTOMATED MODE - DEFAULT]
================================================================================

SCRIPT OPTIONS & CURRENT SETTINGS:
--------------------------------------------------------------------------------
Current Settings:
  Installation Scope: CurrentUser
  Automated Mode: Yes (default)
  Interactive Mode: No
  Force Reinstall: No
  Skip Version Check: No
  Include Optional Modules: No
  PowerShell 5.1 Compatible Only: No
  Pause Between Batches: No
  Show Detailed Progress: No

Available Options (for next time):
  -Interactive              Enable prompts and user guidance
  -Force                    Force reinstall of existing modules
  -SkipVersionCheck        Install any available version (faster)
  -Scope AllUsers           Install for all users (requires admin)
  -IncludeOptionalModules   Add large Graph modules (PS7+ recommended)
  -PowerShell5Compatible   Force PS 5.1 mode (skip PS7 upgrade)
  -PauseBetweenBatches      Pause after each batch for review
  -ShowDetailedProgress     Enhanced progress information

Example Commands:
  .\Install-PowerShell-Modules-Automated.ps1
    └─ Default: Automated, PowerShell 7 upgrade, essential modules
  .\Install-PowerShell-Modules-Automated.ps1 -PauseBetweenBatches
    └─ Same as default but pauses for review (recommended for monitoring)
  .\Install-PowerShell-Modules-Automated.ps1 -Interactive -Force
    └─ Interactive mode with forced reinstall
  .\Install-PowerShell-Modules-Automated.ps1 -IncludeOptionalModules -Force
    └─ Include large Graph modules and force reinstall
--------------------------------------------------------------------------------
