' launch-kanata.vbs
' Internal launcher invoked by the KanataKeyboardRemap scheduled task.
' Spawns kanata_winIOv2.exe with windowStyle=0 (hidden) so no console
' window ever appears, even though kanata is a console-subsystem binary.
' Stays alive while kanata runs (the third arg to Run is True) so the
' scheduled task's RestartCount/RestartInterval can detect kanata crashes
' and re-launch automatically.

Dim folder, sh, Q
Q = Chr(34)
folder = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
Set sh = CreateObject("WScript.Shell")
sh.Run Q & folder & "kanata_winIOv2.exe" & Q & " --cfg " & Q & folder & "kanata.kbd" & Q, 0, True
