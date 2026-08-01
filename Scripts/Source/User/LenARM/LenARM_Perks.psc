Scriptname LenARM:LenARM_Perks extends Quest

; ------------------------
; ------------------------
; Quest input params

Group Properties
	Perk[] Property RadsPerkArray Auto
	Perk Property RadsPerkFull Auto
	
	Perk[] Property BalloonsPerkArray Auto
EndGroup

; ------------------------
; ------------------------
; methods

; For some reason doc comments from the first function after variable declarations are not picked up.
Function DummyFunction()
EndFunction


;
; Gets the current RadsPerk 'level' of @akTarget
;
int Function GetCurrentRadsPerkLevel(Actor akTarget)
    int i = 0
    While (i <= 4)
		; when akTarget has the radsPerk, return its id
        If (akTarget.HasPerk(RadsPerkArray[i]))
			return i
        EndIf
        i += 1
    EndWhile
	
	; fallback in case we actor has no radsPerk
	return 0
EndFunction

;
; Adds RadsPerk with 'level' @perkLevel to @akTarget
;
Function ApplyRadsPerk(Actor akTarget, int perkLevel)
	akTarget.AddPerk(RadsPerkArray[perkLevel])	
EndFunction

;
; Adds Full RadsPerk to @akTarget
;
Function ApplyRadsPerkMax(Actor akTarget)
	akTarget.AddPerk(RadsPerkFull)	
EndFunction

; 
; Loops through all possible RadsPerks, removing those that are active on @akTarget if they don't match @newPerkLevel.
; Does not apply the matching RadsPerk, you must do that manually.
; Use @newPerkLevel -1 to clear all RadPerks from @akTarget.
; 
Function ClearOldRadsPerks(Actor akTarget, int newPerkLevel)
    int i = 0
	; loop through the standard perks, remove when not matching new perk level
	;TODO kan je niet gewoon RadsPerkArray.Length doen?
    While (i <= 4)
        If (i != newPerkLevel && akTarget.HasPerk(RadsPerkArray[i]))
			; Log("Removing radsperk of level " + i)
			akTarget.RemovePerk(RadsPerkArray[i])
        EndIf
        i += 1
    EndWhile
	
	; remove the full perk when not matching full perk level
	if (newPerkLevel != 5)
		akTarget.RemovePerk(RadsPerkFull)
	endif
	
	; if (newPerkLevel > -1)
    ; 	Log("RadsPerk Level " + newPerkLevel + " applied")    
	; endif
EndFunction

;
; Clears all RadsPerks from @akTarget
;
Function ClearAllRadsPerks(Actor akTarget)
    ClearOldRadsPerks(akTarget, -1)
EndFunction


;
; Adds BalloonsPerk with 'level' @perkLevel to @akTarget
;
Function ApplyBalloonsPerk(Actor akTarget, int perkLevel)
	akTarget.AddPerk(BalloonsPerkArray[perkLevel])	
EndFunction

; 
; Loops through all possible BalloonsPerks, removing those that are active on @akTarget if they don't match @newPerkLevel.
; Does not apply the matching BalloonsPerk, you must do that manually.
; Use @newPerkLevel -1 to clear all BalloonsPerks from @akTarget.
; 
Function ClearOldBalloonsPerks(Actor akTarget, int newPerkLevel)
    int i = 0	
	; loop through the standard perks, remove when not matching new perk level
	;TODO kan je niet gewoon BalloonsPerkArray.Length doen?
    While (i <= 3)
        If (i != newPerkLevel && akTarget.HasPerk(BalloonsPerkArray[i]))
			; Log("Removing radsperk of level " + i)
			akTarget.RemovePerk(BalloonsPerkArray[i])
        EndIf
        i += 1
    EndWhile
EndFunction

;
; Clears all BalloonsPerks from @akTarget
;
Function ClearAllBalloonsPerks(Actor akTarget)
    ClearOldBalloonsPerks(akTarget, -1)
EndFunction
