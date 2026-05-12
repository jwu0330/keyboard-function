#Requires -RunAsAdministrator
<#
    bootstrap.ps1 — one-shot installer for a fresh Windows machine.

    Performs end-to-end setup:
      1. Downloads kanata (windows-binaries-x64.zip) -> extracts kanata_wintercept.exe
      2. Downloads Interception driver (Interception.zip) -> extracts
      3. Runs install-interception.exe /install  (driver activates after reboot)
      4. Registers the kanata scheduled task (install.ps1 -SkipConfigCheck)
      5. Prompts for reboot.

    Usage (in an elevated PowerShell, from the cloned repo folder):
        powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1

    Or as a one-liner (clones repo + runs bootstrap):
        gh repo clone jwu0330/keyboard-function $env:USERPROFILE\keyboard-function;
        Set-Location $env:USERPROFILE\keyboard-function;
        powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1

    Use -NoReboot to skip the interactive reboot prompt (e.g. when invoked
    over SSH where no TTY is attached). You will need to reboot manually.
#>

param(
    [switch]$NoReboot
)

$ErrorActionPreference = 'Stop'
$here    = $PSScriptRoot
$setup   = Join-Path $here '_setup'
$null    = New-Item -ItemType Directory -Force -Path $setup

# ---------------------------------------------------------------------------
Write-Host "[1/5] Downloading kanata (latest)..." -ForegroundColor Cyan
$kanataUrl = 'https://github.com/jtroo/kanata/releases/latest/download/windows-binaries-x64.zip'
$kanataZip = Join-Path $setup 'kanata-windows-x64.zip'
Invoke-WebRequest -Uri $kanataUrl -OutFile $kanataZip -UseBasicParsing

$kanataExtract = Join-Path $setup 'kanata'
if (Test-Path $kanataExtract) { Remove-Item $kanataExtract -Recurse -Force }
Expand-Archive -Path $kanataZip -DestinationPath $kanataExtract -Force

$kanataExe = Get-ChildItem -Path $kanataExtract -Recurse -Filter 'kanata_wintercept.exe' | Select-Object -First 1
if (-not $kanataExe) {
    throw "kanata_wintercept.exe not found inside $kanataZip"
}
Copy-Item -Path $kanataExe.FullName -Destination (Join-Path $here 'kanata_wintercept.exe') -Force
Write-Host "      OK -> $(Join-Path $here 'kanata_wintercept.exe')" -ForegroundColor Green

# ---------------------------------------------------------------------------
Write-Host "[2/5] Downloading Interception driver..." -ForegroundColor Cyan
$icpUrl = 'https://github.com/oblitum/Interception/releases/latest/download/Interception.zip'
$icpZip = Join-Path $setup 'Interception.zip'
Invoke-WebRequest -Uri $icpUrl -OutFile $icpZip -UseBasicParsing

$icpExtract = Join-Path $setup 'Interception'
if (Test-Path $icpExtract) { Remove-Item $icpExtract -Recurse -Force }
Expand-Archive -Path $icpZip -DestinationPath $icpExtract -Force

$icpInst = Get-ChildItem -Path $icpExtract -Recurse -Filter 'install-interception.exe' | Select-Object -First 1
if (-not $icpInst) {
    throw "install-interception.exe not found inside Interception.zip"
}
Write-Host "      OK -> $($icpInst.FullName)" -ForegroundColor Green

# ---------------------------------------------------------------------------
Write-Host "[3/5] Installing Interception driver (active after reboot)..." -ForegroundColor Cyan
Push-Location (Split-Path $icpInst.FullName -Parent)
try {
    & $icpInst.FullName /install
} finally {
    Pop-Location
}
Write-Host "      Driver registered." -ForegroundColor Green

# ---------------------------------------------------------------------------
Write-Host "[4/5] Registering scheduled task..." -ForegroundColor Cyan
& (Join-Path $here 'install.ps1') -SkipConfigCheck
Write-Host "      OK." -ForegroundColor Green

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[5/5] REBOOT REQUIRED." -ForegroundColor Yellow
Write-Host "      The Interception driver only loads at boot. After you reboot"
Write-Host "      and log in, kanata starts automatically and"
Write-Host "      hold Space + W/A/S/D becomes Up/Left/Down/Right."
Write-Host ""
if ($NoReboot) {
    Write-Host "Reboot manually when ready. After reboot, no further action is needed." -ForegroundColor Cyan
} else {
    $ans = Read-Host "Reboot now? (y/N)"
    if ($ans -eq 'y' -or $ans -eq 'Y') {
        Restart-Computer -Force
    } else {
        Write-Host "Reboot later. After reboot, no further action is needed." -ForegroundColor Cyan
    }
}
