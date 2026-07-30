Scriptname LenARM:LenARM_Debug extends Quest

; ------------------------
; Debug helpers for writing to Papyrus logs and displaying info messages ingame
; ------------------------

; show a big fat message box in the center of the page, which the player has to click away
Function MessageBox(string msg)
	Debug.MessageBox(msg)
	Debug.Trace("[LenARM] " + msg)
	Log(msg)
EndFunction

; show a message in the top-left
Function Note(string msg)
	Debug.Notification(msg)
	Log(msg)
EndFunction

; same as Note only the message gets prefixed with [LenARM]
Function TechnicalNote(string msg)
	Debug.Notification("[LenARM] " + msg)
	Log(msg)
EndFunction

; write a line to the log
Function Log(string msg)
	Debug.Trace("[LenARM] " + msg)
EndFunction


; ------------------------
; Debug function to check which slots the current equipped clothes / armor occupies
; ------------------------
Function ShowEquippedClothes(Actor akSender)
	TechnicalNote("ShowEquippedClothes")
	string[] items = new string[0]
	int slot = 0
	While (slot < 62)
		Actor:WornItem item = akSender.GetWornItem(slot)
		If (item != None && item.item != None)
			items.Add(slot + ": " + item.item.GetName())
			; Log("  " + slot + ": " + item.item.GetName() + " (" + item.modelName + ")")
		Else
			; Log("  Slot " + slot + " is empty")
		EndIf
		slot += 1
	EndWhile

	MessageBox(LL_FourPlay.StringJoin(items, "\n"))
EndFunction