; WoW Forever hotkeys (AutoHotkey v1.1). bin/link-wow-classic links this folder
; into the Battle.net Wine prefix as C:\Program Files\AutoHotkey\Scripts. Launch
; it from Lutris in that same prefix and runner, so it shares WoW's wineserver;
; a Wine process outside that session cannot see or send keys to WoW.
;
; Keep to one key press = one action: Blizzard allows remapping, not automation.
#NoEnv
#SingleInstance Force
#Persistent
SendMode Input
SetTitleMatchMode 2

TrayTip, AutoHotkey, WoW.ahk loaded (Ctrl+Alt+R reloads`, Ctrl+Alt+Q quits), 5

; Script control: works anywhere.
^!r::Reload
^!q::ExitApp

#IfWinActive World of Warcraft
; Test hotkey: Ctrl+Alt+T shows a message box while WoW has focus.
^!t::MsgBox, 64, AutoHotkey, AutoHotkey can see WoW.
#IfWinActive
