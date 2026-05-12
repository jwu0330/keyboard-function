@echo off
:: ============================================================================
:: Restart kanata. Use this after editing kanata.kbd to reload the config,
:: or to bring kanata back after running Emergency-Stop.bat.
:: ============================================================================

echo Stopping any running kanata...
taskkill /IM kanata_winIOv2.exe /F >nul 2>&1
taskkill /IM kanata_wintercept.exe /F >nul 2>&1
schtasks /End /TN KanataKeyboardRemap >nul 2>&1

:: In case the task was disabled (e.g. by user after Emergency-Stop), re-enable.
schtasks /Change /TN KanataKeyboardRemap /Enable >nul 2>&1

timeout /t 1 >nul

echo Starting kanata...
schtasks /Run /TN KanataKeyboardRemap

timeout /t 2 >nul

echo.
echo === Status ===
tasklist /FI "IMAGENAME eq kanata_winIOv2.exe" 2>nul | findstr kanata_winIOv2
if errorlevel 1 (
    echo kanata_winIOv2 is NOT running. Check the scheduled task:
    echo    schtasks /Query /TN KanataKeyboardRemap /V
) else (
    echo kanata_winIOv2 is running. Hold Space + WASD or Alt + CapsLock to test.
)
echo.
timeout /t 5
