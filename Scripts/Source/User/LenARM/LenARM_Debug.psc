Scriptname LenARM:LenARM_Debug extends Quest

; ------------------------
; ------------------------
; methods

; For some reason doc comments from the first function after variable declarations are not picked up.
Function DummyFunction()
EndFunction

; 
; show a big fat message box in the center of the page, which the player has to click away
;
Function MessageBox(string msg)
	Debug.MessageBox(msg)
	Debug.Trace("[LenARM] " + msg)
	Log(msg)
EndFunction

;
; show a message in the top-left
;
Function Note(string msg)
	Debug.Notification(msg)
	Log(msg)
EndFunction

;
; same as Note only the message gets prefixed with [LenARM]
;
Function TechnicalNote(string msg)
	Debug.Notification("[LenARM] " + msg)
	Log(msg)
EndFunction

;
; write a line to the log prefixed with [LenARM]
;
Function Log(string msg)
	Debug.Trace("[LenARM] " + msg)
EndFunction
