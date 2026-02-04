# Win11 Debloater

This repo contains a focused, opt-in Windows 11 debloater script. It is designed
for safe previewing with `-WhatIf`, and requires elevation to make changes.

## Quick start

```powershell
# From an elevated PowerShell prompt
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\win11-debloater.ps1 -WhatIf -RemoveBloatApps -DisableTelemetry -DisableSuggestions
```

Or launch the selection GUI:

```powershell
.\scripts\win11-debloater.ps1 -Gui -WhatIf
```

Or use the Python GUI wrapper (recommended for guided selections):

```powershell
python .\scripts\win11-debloater-gui.py
```

Remove the `-WhatIf` flag once you're comfortable with the plan:

```powershell
.\scripts\win11-debloater.ps1 -RemoveBloatApps -DisableTelemetry -DisableSuggestions -Confirm
```

## Options

- `-RemoveBloatApps`: Remove a curated list of common bundled apps.
- `-Gui`: Open a selection window to choose which actions to run.
- `-RevertPolicies`: Revert policy changes made by this script (telemetry, suggestions, widgets).
- `-RestoreApps`: Restore bundled apps removed by this script (best effort, uses winget when available).
- `-RemoveCortana`: Remove Cortana packages.
- `-RemoveTeamsConsumer`: Remove the consumer Teams package.
- `-RemoveWidgets`: Disable Widgets via policy.
- `-DisableTelemetry`: Set telemetry policies to the lowest level.
- `-DisableSuggestions`: Disable consumer experience suggestions.
- `-RemoveOneDrive`: Uninstall OneDrive.

## Notes

- Run in an elevated PowerShell session.
- Rebooting is recommended after changes.
- Use `-WhatIf` to preview all actions safely.
- App restores use `winget` with Microsoft Store IDs when available; if winget is missing, reinstall via Microsoft Store.
