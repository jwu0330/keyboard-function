' Double-click to stop the keyboard remap. Runs hidden — no popup window.
Set sh = CreateObject("WScript.Shell")
sh.Run "cmd /c schtasks /End /TN KanataKeyboardRemap & taskkill /IM kanata_winIOv2.exe /F", 0, True
