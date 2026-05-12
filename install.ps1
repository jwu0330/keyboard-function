#Requires -RunAsAdministrator
<#
    install.ps1 — register kanata as a Windows scheduled task.

    Prerequisites (one-time, manual):
      1. Install the Interception driver:
         https://github.com/oblitum/Interception/releases
         Extract, open an admin cmd in the extracted folder, run:
             install-interception.exe /install
         Reboot.

      2. Download kanata_wintercept.exe:
         https://github.com/jtroo/kanata/releases (latest)
         Place it next to this script.

    Then run this script from an elevated PowerShell:
        powershell -ExecutionPolicy Bypass -File .\install.ps1
#>

param(
    [string]$KanataExe  = (Join-Path $PSScriptRoot 'kanata_wintercept.exe'),
    [string]$ConfigFile = (Join-Path $PSScriptRoot 'kanata.kbd'),
    [string]$TaskName   = 'KanataKeyboardRemap',
    # Skip the kanata --check step. Useful when Interception driver is installed
    # but not yet loaded (i.e. you have not rebooted since installing it), since
    # --check tries to open the driver and would fail before reboot.
    [switch]$SkipConfigCheck
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $KanataExe)) {
    Write-Host "kanata_wintercept.exe not found at:" -ForegroundColor Red
    Write-Host "    $KanataExe"
    Write-Host ""
    Write-Host "Step 1 - Install Interception driver (one-time, requires reboot):" -ForegroundColor Yellow
    Write-Host "    https://github.com/oblitum/Interception/releases"
    Write-Host ""
    Write-Host "Step 2 - Download kanata_wintercept.exe and place it next to this script:" -ForegroundColor Yellow
    Write-Host "    https://github.com/jtroo/kanata/releases"
    Write-Host "    Save to: $PSScriptRoot"
    Write-Host ""
    Write-Host "Step 3 - Re-run this script as Administrator."
    exit 1
}

if (-not (Test-Path $ConfigFile)) {
    Write-Host "Config file not found: $ConfigFile" -ForegroundColor Red
    exit 1
}

if ($SkipConfigCheck) {
    Write-Host "[1/4] Skipping kanata --check (SkipConfigCheck set)." -ForegroundColor Yellow
} else {
    Write-Host "[1/4] Validating kanata config..." -ForegroundColor Cyan
    & $KanataExe --cfg $ConfigFile --check
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Config validation failed. Fix kanata.kbd and re-run." -ForegroundColor Red
        Write-Host "(If the driver is installed but not yet loaded, re-run with -SkipConfigCheck.)" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "      OK." -ForegroundColor Green
}

Write-Host "[2/4] Removing previous task (if any)..." -ForegroundColor Cyan
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "      Removed: $TaskName" -ForegroundColor Green
} else {
    Write-Host "      No previous task." -ForegroundColor Green
}

Write-Host "[3/4] Registering scheduled task..." -ForegroundColor Cyan

$action = New-ScheduledTaskAction `
    -Execute $KanataExe `
    -Argument "--cfg `"$ConfigFile`""

# Resolve the current user via WindowsIdentity. On workgroup machines
# $env:USERDOMAIN can be "WORKGROUP", which is not a valid security
# authority and breaks Register-ScheduledTask. .Name returns the proper
# COMPUTERNAME\user or DOMAIN\user form.
$currentUser = ([Security.Principal.WindowsIdentity]::GetCurrent()).Name

$trigger = New-ScheduledTaskTrigger -AtLogOn -User $currentUser

$principal = New-ScheduledTaskPrincipal `
    -UserId $currentUser `
    -LogonType Interactive `
    -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 999 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -MultipleInstances IgnoreNew

# Remove the default 72h execution time limit so kanata can run indefinitely.
$settings.ExecutionTimeLimit = 'PT0S'

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description 'Kanata keyboard remap: Space + WASD -> arrow keys' | Out-Null

Write-Host "      Registered: $TaskName" -ForegroundColor Green

Write-Host "[4/4] Starting task..." -ForegroundColor Cyan
Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 2
$state = (Get-ScheduledTask -TaskName $TaskName).State
Write-Host "      State: $state" -ForegroundColor Green

Write-Host ""
Write-Host "Done. Test it: hold Space + tap W / A / S / D." -ForegroundColor Green
Write-Host ""
Write-Host "Management commands:" -ForegroundColor Cyan
Write-Host "    Start  :  Start-ScheduledTask  -TaskName $TaskName"
Write-Host "    Stop   :  Stop-ScheduledTask   -TaskName $TaskName"
Write-Host "    Status :  Get-ScheduledTask    -TaskName $TaskName"
Write-Host "    Remove :  .\uninstall.ps1"
