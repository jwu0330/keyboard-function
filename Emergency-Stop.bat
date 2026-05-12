@echo off
:: ============================================================================
:: Emergency stop for kanata. Mouse-clickable; no admin needed; no typing.
:: Use this if the keyboard remap goes haywire and you can't type properly.
:: After running, the keyboard returns to normal Windows behavior immediately.
:: ============================================================================

echo Stopping kanata...
schtasks /End /TN KanataKeyboardRemap >nul 2>&1
taskkill /IM kanata_winIOv2.exe /F >nul 2>&1
taskkill /IM kanata_wintercept.exe /F >nul 2>&1

echo.
echo === Kanata is now stopped. Keyboard is back to normal Windows behavior. ===
echo.
echo Notes:
echo   * Re-login or run Restart-Kanata.bat to bring it back.
echo   * The scheduled task is only "ended" (process killed). It will auto-
echo     start again next time you log in. If you want it to stay off, also
echo     disable the task:
echo         schtasks /Change /TN KanataKeyboardRemap /Disable
echo.
timeout /t 8
