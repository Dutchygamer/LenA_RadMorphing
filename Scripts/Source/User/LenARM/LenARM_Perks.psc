Scriptname LenARM:LenARM_Perks extends Quest


; ------------------------
; Register the .esp Quest properties so we can act on them
; ------------------------
Group Properties
	Perk[] Property RadsPerkArray Auto
	Perk Property RadsPerkFull Auto
	
	Perk[] Property BalloonsPerkArray Auto
EndGroup


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


Function ApplyRadsPerk(Actor akTarget, int perkLevel)
	akTarget.AddPerk(RadsPerkArray[perkLevel])	
EndFunction
Function ApplyRadsPerkMax(Actor akTarget)
	akTarget.AddPerk(RadsPerkFull)	
EndFunction


; ------------------------
; Loops through all possible radsPerks, removing those that are active on the Actor if they don't match the newPerkLevel.
; Does not apply the matching radsPerk, you must do that manually.
; Use -1 to clear all radPerks from an Actor.
; ------------------------
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

Function ClearAllRadsPerks(Actor akTarget)
    ClearOldRadsPerks(akTarget, -1)
EndFunction





Function ApplyBalloonsPerk(Actor akTarget, int perkLevel)
	akTarget.AddPerk(BalloonsPerkArray[perkLevel])	
EndFunction

; ------------------------
; Loops through all possible balloonsPerks, removing those that are active on the Actor if they don't match the newPerkLevel.
; Does not apply the matching balloonsPerk, you must do that manually.
; Use -1 to clear all balloonsPerks from an Actor.
; ------------------------
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

Function ClearAllBalloonsPerks(Actor akTarget)
    ClearOldBalloonsPerks(akTarget, -1)
EndFunction
