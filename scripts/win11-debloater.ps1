<#
.SYNOPSIS
  Windows 11 debloater script with safe defaults and optional destructive actions.
.DESCRIPTION
  Removes selected Appx packages (installed and provisioned), disables telemetry
  and consumer experiences, and turns off suggestions. Uses -WhatIf and -Confirm
  support for safe previewing. Run in an elevated PowerShell session.
.EXAMPLE
  .\win11-debloater.ps1 -WhatIf
.EXAMPLE
  .\win11-debloater.ps1 -RemoveOneDrive -RemoveCortana -Confirm
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [switch]$Gui,
  [switch]$RevertPolicies,
  [switch]$RestoreApps,
  [switch]$RemoveOneDrive,
  [switch]$RemoveCortana,
  [switch]$RemoveTeamsConsumer,
  [switch]$RemoveWidgets,
  [switch]$DisableTelemetry,
  [switch]$DisableSuggestions,
  [switch]$RemoveBloatApps
)

Set-StrictMode -Version Latest

function Write-Section {
  param([string]$Title)
  Write-Host "\n=== $Title ===" -ForegroundColor Cyan
}

function Remove-AppxByName {
  param([string]$Pattern)

  $installed = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like $Pattern }
  foreach ($pkg in $installed) {
    if ($PSCmdlet.ShouldProcess($pkg.Name, 'Remove installed Appx package')) {
      Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
    }
  }

  $provisioned = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $Pattern }
  foreach ($prov in $provisioned) {
    if ($PSCmdlet.ShouldProcess($prov.DisplayName, 'Remove provisioned Appx package')) {
      Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction SilentlyContinue
    }
  }
}

function Set-RegistryValue {
  param(
    [string]$Path,
    [string]$Name,
    [int]$Value
  )

  if ($PSCmdlet.ShouldProcess("$Path\\$Name", "Set registry value to $Value")) {
    if (-not (Test-Path $Path)) {
      New-Item -Path $Path -Force | Out-Null
    }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force | Out-Null
  }
}

function Remove-RegistryValue {
  param(
    [string]$Path,
    [string]$Name
  )

  if ($PSCmdlet.ShouldProcess("$Path\\$Name", 'Remove registry value')) {
    if (Test-Path $Path) {
      Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
      if (-not (Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue)) {
        Remove-Item -Path $Path -ErrorAction SilentlyContinue
      }
    }
  }
}

function Revert-PolicyChanges {
  Write-Section 'Reverting policy changes'
  Remove-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' -Name 'AllowNewsAndInterests'
  Remove-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry'
  Remove-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'DisableEnterpriseAuthProxy'
  Remove-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableConsumerAccountStateContent'
  Remove-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableCloudOptimizedContent'
  Remove-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableWindowsConsumerFeatures'
}

function Restore-AppxPackages {
  Write-Section 'Restoring bundled apps (best effort)'

  $knownApps = @(
    @{ Name = 'Microsoft.BingNews'; Winget = '9WZDNCRFJ3Q2' },
    @{ Name = 'Microsoft.BingWeather'; Winget = '9WZDNCRFJ3Q1' },
    @{ Name = 'Microsoft.GamingApp'; Winget = '9MWPM2CQNLHN' },
    @{ Name = 'Microsoft.GetHelp'; Winget = '9PKDZBMV1H3T' },
    @{ Name = 'Microsoft.Getstarted'; Winget = '9WZDNCRFJ3Q5' },
    @{ Name = 'Microsoft.Microsoft3DViewer'; Winget = '9NBLGGH42THS' },
    @{ Name = 'Microsoft.MicrosoftOfficeHub'; Winget = '9WZDNCRD29V9' },
    @{ Name = 'Microsoft.MicrosoftSolitaireCollection'; Winget = '9WZDNCRFHWD2' },
    @{ Name = 'Microsoft.MixedReality.Portal'; Winget = '9NG1H8B3ZC7M' },
    @{ Name = 'Microsoft.MSPaint'; Winget = '9PCFS5B6T72H' },
    @{ Name = 'Microsoft.People'; Winget = '9NBLGGH10PG8' },
    @{ Name = 'Microsoft.PowerAutomateDesktop'; Winget = '9NFTCH6J7FHV' },
    @{ Name = 'Microsoft.SkypeApp'; Winget = '9WZDNCRFJ364' },
    @{ Name = 'Microsoft.Todos'; Winget = '9NBLGGH5R558' },
    @{ Name = 'Microsoft.Wallet'; Winget = '9WZDNCRFJ3QW' },
    @{ Name = 'Microsoft.Whiteboard'; Winget = '9MSPC6MP8FM4' },
    @{ Name = 'Microsoft.WindowsFeedbackHub'; Winget = '9NBLGGH4R32N' },
    @{ Name = 'Microsoft.WindowsMaps'; Winget = '9WZDNCRFJ3Q8' },
    @{ Name = 'Microsoft.YourPhone'; Winget = '9NMPJ99VJBWV' },
    @{ Name = 'Microsoft.ZuneMusic'; Winget = '9WZDNCRFJ3PT' },
    @{ Name = 'Microsoft.ZuneVideo'; Winget = '9WZDNCRFJ3P2' }
  )

  $wingetPath = Get-Command winget -ErrorAction SilentlyContinue

  foreach ($app in $knownApps) {
    $installed = Get-AppxPackage -AllUsers | Where-Object { $_.Name -eq $app.Name }
    if ($installed) {
      foreach ($pkg in $installed) {
        $manifest = Join-Path $pkg.InstallLocation 'AppxManifest.xml'
        if (Test-Path $manifest) {
          if ($PSCmdlet.ShouldProcess($pkg.Name, 'Re-register Appx package')) {
            Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction SilentlyContinue
          }
        }
      }
      continue
    }

    if ($wingetPath) {
      if ($PSCmdlet.ShouldProcess($app.Name, 'Install from Microsoft Store via winget')) {
        Start-Process -FilePath $wingetPath.Source -ArgumentList @('install', '--source', 'msstore', '--id', $app.Winget, '--accept-package-agreements', '--accept-source-agreements') -Wait
      }
    } else {
      Write-Host "winget not available; reinstall $($app.Name) from Microsoft Store if needed." -ForegroundColor Yellow
    }
  }
}

function Show-SelectionGui {
  $actions = @(
    @{ Key = 'RevertPolicies'; Label = 'Revert policy changes (telemetry, suggestions, widgets)' },
    @{ Key = 'RestoreApps'; Label = 'Restore removed bundled apps (best effort)' },
    @{ Key = 'RemoveBloatApps'; Label = 'Remove common bundled apps' },
    @{ Key = 'RemoveCortana'; Label = 'Remove Cortana' },
    @{ Key = 'RemoveTeamsConsumer'; Label = 'Remove Teams (consumer)' },
    @{ Key = 'RemoveWidgets'; Label = 'Disable Widgets' },
    @{ Key = 'DisableTelemetry'; Label = 'Disable telemetry and diagnostics' },
    @{ Key = 'DisableSuggestions'; Label = 'Disable suggestions and consumer experiences' },
    @{ Key = 'RemoveOneDrive'; Label = 'Uninstall OneDrive' }
  )

  Add-Type -AssemblyName System.Windows.Forms

  $form = New-Object System.Windows.Forms.Form
  $form.Text = 'Win11 Debloater - Select Actions'
  $form.Width = 520
  $form.Height = 420
  $form.StartPosition = 'CenterScreen'

  $list = New-Object System.Windows.Forms.CheckedListBox
  $list.CheckOnClick = $true
  $list.Width = 480
  $list.Height = 280
  $list.Left = 10
  $list.Top = 10

  foreach ($action in $actions) {
    [void]$list.Items.Add($action.Label, $false)
  }

  $okButton = New-Object System.Windows.Forms.Button
  $okButton.Text = 'OK'
  $okButton.Width = 100
  $okButton.Height = 30
  $okButton.Left = 280
  $okButton.Top = 310
  $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
  $form.AcceptButton = $okButton

  $cancelButton = New-Object System.Windows.Forms.Button
  $cancelButton.Text = 'Cancel'
  $cancelButton.Width = 100
  $cancelButton.Height = 30
  $cancelButton.Left = 390
  $cancelButton.Top = 310
  $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
  $form.CancelButton = $cancelButton

  $note = New-Object System.Windows.Forms.Label
  $note.Text = 'Tip: run with -WhatIf to preview actions safely.'
  $note.Width = 480
  $note.Height = 40
  $note.Left = 10
  $note.Top = 320

  $form.Controls.Add($list)
  $form.Controls.Add($okButton)
  $form.Controls.Add($cancelButton)
  $form.Controls.Add($note)

  $result = $form.ShowDialog()
  if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
    return @()
  }

  $selected = @()
  for ($i = 0; $i -lt $list.Items.Count; $i++) {
    if ($list.GetItemChecked($i)) {
      $selected += $actions[$i].Key
    }
  }

  return $selected
}

Write-Section 'Win11 Debloater'
Write-Host 'Run in an elevated PowerShell session.' -ForegroundColor Yellow

if ($Gui) {
  $selectedActions = Show-SelectionGui
  if ($selectedActions.Count -eq 0) {
    Write-Host 'No actions selected. Exiting.' -ForegroundColor Yellow
    return
  }

  $RemoveBloatApps = $selectedActions -contains 'RemoveBloatApps'
  $RemoveCortana = $selectedActions -contains 'RemoveCortana'
  $RemoveTeamsConsumer = $selectedActions -contains 'RemoveTeamsConsumer'
  $RemoveWidgets = $selectedActions -contains 'RemoveWidgets'
  $DisableTelemetry = $selectedActions -contains 'DisableTelemetry'
  $DisableSuggestions = $selectedActions -contains 'DisableSuggestions'
  $RemoveOneDrive = $selectedActions -contains 'RemoveOneDrive'
  $RevertPolicies = $selectedActions -contains 'RevertPolicies'
  $RestoreApps = $selectedActions -contains 'RestoreApps'
}

if ($RevertPolicies) {
  if ($RemoveBloatApps -or $RemoveCortana -or $RemoveTeamsConsumer -or $RemoveWidgets -or $DisableTelemetry -or $DisableSuggestions -or $RemoveOneDrive -or $RestoreApps) {
    Write-Host 'RevertPolicies runs alone; other actions will be skipped.' -ForegroundColor Yellow
  }
  Revert-PolicyChanges
  Write-Section 'Done'
  Write-Host 'Review output above. Reboot is recommended for some changes.' -ForegroundColor Green
  return
}

if ($RestoreApps) {
  if ($RemoveBloatApps -or $RemoveCortana -or $RemoveTeamsConsumer -or $RemoveWidgets -or $DisableTelemetry -or $DisableSuggestions -or $RemoveOneDrive) {
    Write-Host 'RestoreApps runs alone; other actions will be skipped.' -ForegroundColor Yellow
  }
  Restore-AppxPackages
  Write-Section 'Done'
  Write-Host 'Review output above. Reboot is recommended for some changes.' -ForegroundColor Green
  return
}

if ($RemoveBloatApps) {
  Write-Section 'Removing common bloatware Appx packages'

  $bloatPatterns = @(
    'Microsoft.BingNews',
    'Microsoft.BingWeather',
    'Microsoft.GamingApp',
    'Microsoft.GetHelp',
    'Microsoft.Getstarted',
    'Microsoft.Microsoft3DViewer',
    'Microsoft.MicrosoftOfficeHub',
    'Microsoft.MicrosoftSolitaireCollection',
    'Microsoft.MixedReality.Portal',
    'Microsoft.MSPaint',
    'Microsoft.OneConnect',
    'Microsoft.People',
    'Microsoft.PowerAutomateDesktop',
    'Microsoft.SkypeApp',
    'Microsoft.Todos',
    'Microsoft.Wallet',
    'Microsoft.Whiteboard',
    'Microsoft.WindowsFeedbackHub',
    'Microsoft.WindowsMaps',
    'Microsoft.XboxApp',
    'Microsoft.XboxGameOverlay',
    'Microsoft.XboxGamingOverlay',
    'Microsoft.XboxIdentityProvider',
    'Microsoft.XboxSpeechToTextOverlay',
    'Microsoft.YourPhone',
    'Microsoft.ZuneMusic',
    'Microsoft.ZuneVideo'
  )

  foreach ($pattern in $bloatPatterns) {
    Remove-AppxByName -Pattern $pattern
  }
}

if ($RemoveCortana) {
  Write-Section 'Removing Cortana'
  Remove-AppxByName -Pattern 'Microsoft.549981C3F5F10'
}

if ($RemoveTeamsConsumer) {
  Write-Section 'Removing Teams (consumer)'
  Remove-AppxByName -Pattern 'MicrosoftTeams'
}

if ($RemoveWidgets) {
  Write-Section 'Disabling Widgets'
  Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' -Name 'AllowNewsAndInterests' -Value 0
}

if ($DisableTelemetry) {
  Write-Section 'Disabling telemetry and diagnostics'
  Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Value 0
  Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'DisableEnterpriseAuthProxy' -Value 1
}

if ($DisableSuggestions) {
  Write-Section 'Disabling suggestions and consumer experiences'
  Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableConsumerAccountStateContent' -Value 1
  Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableCloudOptimizedContent' -Value 1
  Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableWindowsConsumerFeatures' -Value 1
}

if ($RemoveOneDrive) {
  Write-Section 'Removing OneDrive'
  $oneDriveSetup = "$env:SystemRoot\System32\OneDriveSetup.exe"
  if (Test-Path $oneDriveSetup) {
    if ($PSCmdlet.ShouldProcess($oneDriveSetup, 'Uninstall OneDrive')) {
      Start-Process -FilePath $oneDriveSetup -ArgumentList '/uninstall' -Wait
    }
  } else {
    Write-Host 'OneDriveSetup.exe not found; skipping.' -ForegroundColor Yellow
  }
}

Write-Section 'Done'
Write-Host 'Review output above. Reboot is recommended for some changes.' -ForegroundColor Green
