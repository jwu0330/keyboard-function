#Requires -RunAsAdministrator
<#
    install.ps1 — register kanata (user-mode / winIOv2) as a scheduled task
    that runs at every logon.

    Why user-mode (RunLevel Limited)?
    - No kernel driver = no BSOD risk, no persistent kernel attack surface.
    - kanata stops cleanly when the process exits — nothing left behind.
    - Same coverage for normal apps (editors, browsers, terminals); only
      elevated apps (Task Manager, UAC dialogs) and a few anti-cheat games
      are out of scope — and those are scenarios where you typically do
      not want a Space+WASD remap active anyway.

    Run this AFTER bootstrap.ps1 has staged kanata_winIOv2.exe and the
    passthru dll next to this script.

    Use -SkipConfigCheck to bypass the `kanata --check` validation pass
    (rarely needed for the user-mode binary).
#>

param(
    [string]$KanataExe  = (Join-Path $PSScriptRoot 'kanata_winIOv2.exe'),
    [string]$ConfigFile = (Join-Path $PSScriptRoot 'kanata.kbd'),
    [string]$TaskName   = 'KanataKeyboardRemap',
    [switch]$SkipConfigCheck
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $KanataExe)) {
    Write-Host "kanata binary not found at:" -ForegroundColor Red
    Write-Host "    $KanataExe"
    Write-Host "Run bootstrap.ps1 first to download it."
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
        exit 1
    }
    Write-Host "      OK." -ForegroundColor Green
}

Write-Host "[2/4] Stopping any running kanata + removing previous task..." -ForegroundColor Cyan
Get-Process kanata* -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "      Killing $($_.Name) (PID $($_.Id))"
    Stop-Process -Id $_.Id -Force
}
Start-Sleep -Milliseconds 500
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "      Removed previous task." -ForegroundColor Green
} else {
    Write-Host "      No previous task." -ForegroundColor Green
}

Write-Host "[3/4] Registering scheduled task (user-mode / Limited)..." -ForegroundColor Cyan

# Resolve user via WindowsIdentity. On workgroup PCs $env:USERDOMAIN may be
# "WORKGROUP", which is not a valid security authority; .Name returns the
# correct COMPUTERNAME\user form.
$currentUser = ([Security.Principal.WindowsIdentity]::GetCurrent()).Name

# Launch kanata via a hidden wscript wrapper rather than directly. kanata's
# console-subsystem binary would otherwise pop up a terminal window when
# the scheduled task spawns it; the .vbs uses WshShell.Run with windowStyle=0
# so no window ever shows.
$launchVbs = Join-Path $PSScriptRoot 'launch-kanata.vbs'
if (-not (Test-Path $launchVbs)) {
    Write-Host "launch-kanata.vbs not found at $launchVbs" -ForegroundColor Red
    exit 1
}

$action = New-ScheduledTaskAction `
    -Execute "$env:WINDIR\System32\wscript.exe" `
    -Argument "`"$launchVbs`""

$trigger = New-ScheduledTaskTrigger -AtLogOn -User $currentUser

# RunLevel Limited intentionally: we WANT kanata to run unelevated so it
# cannot intercept input destined for elevated processes (Task Manager etc.).
# That's the security guarantee that justifies the user-mode choice.
$principal = New-ScheduledTaskPrincipal `
    -UserId $currentUser `
    -LogonType Interactive `
    -RunLevel Limited

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 999 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -MultipleInstances IgnoreNew

$settings.ExecutionTimeLimit = 'PT0S'   # no time limit

Register-ScheduledTask `
    -TaskName  $TaskName `
    -Action    $action `
    -Trigger   $trigger `
    -Principal $principal `
    -Settings  $settings `
    -Description 'Kanata user-mode keyboard remap (Space + WASD -> arrows, winIOv2)' | Out-Null

Write-Host "      Registered: $TaskName" -ForegroundColor Green

Write-Host "[4/4] Starting task..." -ForegroundColor Cyan
Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 3
$proc = Get-Process kanata_winIOv2 -ErrorAction SilentlyContinue
if ($proc) {
    Write-Host "      kanata_winIOv2 running: PID $($proc.Id)" -ForegroundColor Green
} else {
    $info = Get-ScheduledTaskInfo -TaskName $TaskName
    Write-Host ("      Task started but no kanata process. LastResult: 0x{0:X}" -f $info.LastTaskResult) -ForegroundColor Red
}

Write-Host ""
Write-Host "Done. Hold Space + tap W / A / S / D." -ForegroundColor Green
Write-Host ""
Write-Host "Management:" -ForegroundColor Cyan
Write-Host "    Status :  Get-ScheduledTask  -TaskName $TaskName"
Write-Host "    Stop   :  Stop-ScheduledTask -TaskName $TaskName  (admin)"
Write-Host "    Start  :  Start-ScheduledTask -TaskName $TaskName"
Write-Host "    Remove :  .\uninstall.ps1"
