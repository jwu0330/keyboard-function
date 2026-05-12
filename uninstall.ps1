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

Get-Process kanata* -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "Stopping kanata process (PID $($_.Id))..."
    Stop-Process -Id $_.Id -Force
}

Write-Host "Done." -ForegroundColor Green
Write-Host ""
Write-Host "To fully remove kanata:" -ForegroundColor Yellow
Write-Host "    Delete kanata_winIOv2.exe and kanata_passthru_x64.dll from this folder."
Write-Host ""
Write-Host "If you previously experimented with wintercept mode and want to remove" -ForegroundColor Yellow
Write-Host "the Interception kernel driver, run from an admin cmd in the extracted" -ForegroundColor Yellow
Write-Host "Interception folder:" -ForegroundColor Yellow
Write-Host "    install-interception.exe /uninstall"
Write-Host "Then reboot."
