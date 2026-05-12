#Requires -RunAsAdministrator
<#
    uninstall.ps1 — remove the kanata scheduled task.
    Note: this only removes the task. It does not uninstall the Interception
    driver or delete kanata_wintercept.exe.
#>

param([string]$TaskName = 'KanataKeyboardRemap')

$ErrorActionPreference = 'Stop'

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $existing) {
    Write-Host "Task '$TaskName' not found. Nothing to do." -ForegroundColor Yellow
    exit 0
}

Write-Host "Stopping task..." -ForegroundColor Cyan
Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

Write-Host "Unregistering task..." -ForegroundColor Cyan
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false

Write-Host "Done." -ForegroundColor Green
Write-Host ""
Write-Host "To fully remove kanata:" -ForegroundColor Yellow
Write-Host "    1. Delete kanata_wintercept.exe from this folder."
Write-Host "    2. (Optional) Uninstall Interception driver:"
Write-Host "       In an admin cmd, from the Interception folder:"
Write-Host "         install-interception.exe /uninstall"
Write-Host "       Then reboot."
