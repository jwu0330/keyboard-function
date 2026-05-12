#Requires -RunAsAdministrator
<#
    bootstrap.ps1 — one-shot installer for a fresh Windows machine.

    Default mode is winIOv2 (user-mode keyboard hook via Windows native API).
    No kernel driver, no reboot, no admin token while kanata runs.

    Performs:
      1. Downloads kanata (windows-binaries-x64.zip).
      2. Stages kanata_winIOv2.exe + kanata_passthru_x64.dll next to this
         script.
      3. Calls install.ps1 to register the scheduled task that runs kanata
         at every logon as the current user (RunLevel Limited).

    Usage (elevated PowerShell, from the cloned repo folder):
        powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1

    One-liner from a fresh machine:
        gh repo clone jwu0330/keyboard-function $env:USERPROFILE\keyboard-function;
        Set-Location $env:USERPROFILE\keyboard-function;
        powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1

    -NoReboot:
        Kept for compatibility; user-mode install never asks for a reboot
        anyway. The flag is a no-op in the current default mode.

    Why not the wintercept (kernel) variant?
        The Interception driver (oblitum/Interception) is a kernel module
        last touched in 2018 and is not actively maintained. Using it means
        keeping an unmaintained signed kernel driver loaded at all times,
        which is a persistent attack surface (any admin process can drive
        it to capture keystrokes). winIOv2 gives the same daily-use
        functionality with none of that risk. Trade-off: input from
        elevated apps (Task Manager, UAC dialogs) and some anti-cheat
        games is out of scope — typically scenarios where you do NOT want
        a Space+WASD remap active anyway.
#>

param([switch]$NoReboot)

$ErrorActionPreference = 'Stop'
$here  = $PSScriptRoot
$setup = Join-Path $here '_setup'
$null  = New-Item -ItemType Directory -Force -Path $setup

# ---------------------------------------------------------------------------
Write-Host "[1/3] Downloading kanata (latest Windows release)..." -ForegroundColor Cyan
$kanataUrl = 'https://github.com/jtroo/kanata/releases/latest/download/windows-binaries-x64.zip'
$kanataZip = Join-Path $setup 'kanata-windows-x64.zip'
Invoke-WebRequest -Uri $kanataUrl -OutFile $kanataZip -UseBasicParsing

$kanataExtract = Join-Path $setup 'kanata'
if (Test-Path $kanataExtract) { Remove-Item $kanataExtract -Recurse -Force }
Expand-Archive -Path $kanataZip -DestinationPath $kanataExtract -Force

# Pick: TTY (headless), winIOv2 (user-mode native API), NOT cmd_allowed
# (the *_cmd_allowed_* variants let kanata run shell commands defined in
# the config — our kanata.kbd sets danger-enable-cmd no anyway, but better
# to ship a binary that physically cannot exec arbitrary cmds).
$exeSrc = Get-ChildItem -Path $kanataExtract -Recurse -File `
    -Filter 'kanata_windows_tty_winIOv2_x64.exe' |
    Where-Object { $_.Name -notlike '*cmd_allowed*' } |
    Select-Object -First 1

$dllSrc = Get-ChildItem -Path $kanataExtract -Recurse -File `
    -Filter 'kanata_passthru_x64.dll' | Select-Object -First 1

if (-not $exeSrc) {
    Write-Host "Available binaries in zip:" -ForegroundColor Yellow
    Get-ChildItem $kanataExtract -Recurse -File | Select-Object Name | Format-Table -AutoSize
    throw "kanata_windows_tty_winIOv2_x64.exe not found inside $kanataZip"
}
if (-not $dllSrc) {
    throw "kanata_passthru_x64.dll not found inside $kanataZip"
}

# Free up the exe if it's currently held by a running kanata.
Get-Process kanata* -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "      Stopping running kanata: $($_.Name) (PID $($_.Id))"
    Stop-Process -Id $_.Id -Force
}
Start-Sleep -Milliseconds 500

Copy-Item -Path $exeSrc.FullName -Destination (Join-Path $here 'kanata_winIOv2.exe')        -Force
Copy-Item -Path $dllSrc.FullName -Destination (Join-Path $here 'kanata_passthru_x64.dll')   -Force
Write-Host "      OK." -ForegroundColor Green

# ---------------------------------------------------------------------------
Write-Host "[2/3] Registering scheduled task..." -ForegroundColor Cyan
& (Join-Path $here 'install.ps1') -SkipConfigCheck
Write-Host "      OK." -ForegroundColor Green

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[3/3] Done — no reboot needed." -ForegroundColor Green
Write-Host "      Test: hold Space + tap W / A / S / D in a text field."
