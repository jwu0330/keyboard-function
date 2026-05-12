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
# Place the mouse-clickable recovery scripts on the user's Desktop. Done
# BEFORE the install step so that even if scheduled-task registration fails,
# the user already has an escape hatch on their Desktop.
Write-Host "[2/4] Placing Start/Stop shortcuts on Desktop..." -ForegroundColor Cyan
$desktop = [Environment]::GetFolderPath('Desktop')
if ($desktop -and (Test-Path $desktop)) {
    # Clean up any legacy .bat files from earlier versions.
    Remove-Item (Join-Path $desktop 'Emergency-Stop-Kanata.bat') -EA SilentlyContinue
    Remove-Item (Join-Path $desktop 'Restart-Kanata.bat')        -EA SilentlyContinue

    # Repo keeps English filenames as the canonical name; on Desktop we
    # deploy with Chinese names so they are immediately readable to the
    # primary user. Build the Chinese names from Unicode code points so
    # this script survives being read by PowerShell 5.1 on a non-UTF-8
    # system codepage (PS 5.1 without a BOM falls back to ANSI / cp950
    # in CJK locales, which would corrupt literal Chinese in the source).
    # 開啟快捷鍵 = U+958B U+555F U+5FEB U+6377 U+9375
    # 關閉快捷鍵 = U+95DC U+9589 U+5FEB U+6377 U+9375
    $startCnName = (-join @([char]0x958B, [char]0x555F, [char]0x5FEB, [char]0x6377, [char]0x9375)) + '.vbs'
    $stopCnName  = (-join @([char]0x95DC, [char]0x9589, [char]0x5FEB, [char]0x6377, [char]0x9375)) + '.vbs'

    Remove-Item (Join-Path $desktop 'Start-Kanata.vbs') -EA SilentlyContinue
    Remove-Item (Join-Path $desktop 'Stop-Kanata.vbs')  -EA SilentlyContinue
    Copy-Item -Path (Join-Path $here 'Start-Kanata.vbs') -Destination (Join-Path $desktop $startCnName) -Force
    Copy-Item -Path (Join-Path $here 'Stop-Kanata.vbs')  -Destination (Join-Path $desktop $stopCnName)  -Force
    Write-Host "      OK -> $desktop" -ForegroundColor Green
} else {
    Write-Host "      Desktop path not resolved; .vbs files left in $here only." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
Write-Host "[3/4] Validating config + registering scheduled task..." -ForegroundColor Cyan
& (Join-Path $here 'install.ps1')
Write-Host "      OK." -ForegroundColor Green

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[4/4] Done — no reboot needed." -ForegroundColor Green
Write-Host "      Test: hold Space + tap W / A / S / D, or Alt + CapsLock."
Write-Host "      Panic button (if something goes wrong):"
Write-Host "          double-click 'Emergency-Stop-Kanata.bat' on your Desktop."
