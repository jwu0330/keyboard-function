<#
    web-install.ps1
    Designed to be piped from the web for one-paste deploy. Usage:

        irm https://raw.githubusercontent.com/jwu0330/keyboard-function/main/web-install.ps1 | iex

    Self-elevates via UAC, downloads the repo as a zip (no git needed),
    extracts to %USERPROFILE%\keyboard-function, then runs bootstrap.ps1.
#>

$ErrorActionPreference = 'Stop'
$RepoZipUrl = 'https://github.com/jwu0330/keyboard-function/archive/refs/heads/main.zip'
$RerunCmd   = 'irm https://raw.githubusercontent.com/jwu0330/keyboard-function/main/web-install.ps1 | iex'

# ---------------------------------------------------------------------------
# Self-elevate if needed.
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Re-launching as Administrator (UAC prompt will appear)..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList @(
        '-NoProfile', '-NoExit', '-ExecutionPolicy', 'Bypass', '-Command', $RerunCmd
    )
    return
}

Write-Host ""
Write-Host "=== keyboard-function web installer ===" -ForegroundColor Cyan
Write-Host ""

$target     = Join-Path $env:USERPROFILE 'keyboard-function'
$zipFile    = Join-Path $env:TEMP        'kf-main.zip'
$extractDir = Join-Path $env:TEMP        'kf-extract'

# ---------------------------------------------------------------------------
Write-Host "[1/3] Downloading repo from GitHub..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $RepoZipUrl -OutFile $zipFile -UseBasicParsing
Write-Host "      OK." -ForegroundColor Green

# ---------------------------------------------------------------------------
Write-Host "[2/3] Extracting to $target..." -ForegroundColor Cyan
if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
Expand-Archive -Path $zipFile -DestinationPath $extractDir -Force

$inner = Get-ChildItem $extractDir -Directory | Select-Object -First 1
if (-not $inner) {
    throw "Extracted archive does not contain the expected top-level directory."
}

if (Test-Path $target) {
    Write-Host "      Existing $target found — stopping any running kanata + removing it." -ForegroundColor Yellow
    Get-Process kanata* -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 500
    Remove-Item $target -Recurse -Force
}

Move-Item -Path $inner.FullName -Destination $target
Remove-Item $zipFile    -Force                     -ErrorAction SilentlyContinue
Remove-Item $extractDir -Recurse -Force            -ErrorAction SilentlyContinue
Write-Host "      OK." -ForegroundColor Green

# ---------------------------------------------------------------------------
Write-Host "[3/3] Running bootstrap.ps1..." -ForegroundColor Cyan
Set-Location $target
& (Join-Path $target 'bootstrap.ps1')
