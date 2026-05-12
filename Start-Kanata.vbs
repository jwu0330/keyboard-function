' Double-click to start the keyboard remap. Runs hidden — no popup window.
Set sh = CreateObject("WScript.Shell")
sh.Run "cmd /c schtasks /Run /TN KanataKeyboardRemap", 0, True
