Scriptname LenARM:LenARM_Perks extends Quest


; ------------------------
; Register the .esp Quest properties so we can act on them
; ------------------------
Group Properties
	Perk[] Property RadsPerkArray Auto
	Perk Property RadsPerkFull Auto
	
	Perk[] Property BalloonsPerkArray Auto
	
	;TODO in geval de lokale bool random wordt unset
	; Perk Property LenARM_BloatSuitPerk Auto Const
	; Perk Property LenARM_KitanaMaskPerk Auto Const

	; Perk Property PoppingExpertPerk1 Auto
	; Perk Property PoppingExpertPerk2 Auto
	
EndGroup

; ; ------------------------
; ; Check the total accumulated rads, and apply the matching radsPerk to the player.
; ; Returns true if player was wearing torso armor and switched from first perk to higher.
; ; Returns false in all other cases.
; ; ------------------------
; bool Function ApplyRadsPerk()
; 	; when we have 0 rads, clear all existing perks and don't apply a new one
; 	if (TotalRads == 0)
; 		ClearAllRadsPerks(PlayerRef)
; 		return false
; 	endif

; 	;TODO bepaal wat min / max zijn, en vanaf wanneer we dus moeten gaan werken tot wanneer
; 	;zie ook CalculateMorphPercentage
; 	; voor nu gebruiken we 0 als min en 1000 als max
; 	;TODO moet dus ook rekening gaan houden met MaxRadiationMultiplier

; 	; calculate the perk level
; 	int perkLevel = ((TotalRads * 1000) / 200) as int
; 	; keep track of whether we've changed perks
; 	bool hasChanged = false

; 	; Log((TotalRads * 1000) + "; " + ((TotalRads * 1000) / 200) + "; " + perkLevel)
; 	; Log("radsperk; CurrentRads: " + (CurrentRads * 1000) + "; TotalRads: " + (TotalRads * 1000))

; 	; limit to 4 just in case (we have 5 perks, starting from 0)
;     If (perkLevel > 4)
;         perkLevel = 4
;     EndIf

; 	; when we are on maxed out morphs, use the final perk
; 	if (HasReachedMaxMorphs)
; 		perkLevel = 5
; 	endif

; 	; when we have enough rads that we should have a difference in perk level, change perks
; 	if (CurrentRadsPerk != perkLevel)
; 		ClearOldRadsPerks(PlayerRef, perkLevel)
; 		; grab the perk from the array if we aren't on maxed out morphs, else use the dedicated perk
; 		if (perkLevel != 5)
; 			PlayerRef.AddPerk(RadsPerkArray[perkLevel])

; 			; play clothes stretch sound when we have something equipped on the torso and we aren't going from none to first or from final to none
; 			if (HasTorsoEquipped(PlayerRef) && perkLevel != 0 && CurrentRadsPerk != 0)
; 				;Note("stretch sound for perkLevel " + perkLevel + "; CurrentRadsPerk " + CurrentRadsPerk)
; 				LenARM_RadPerkSwitchSound.Play(PlayerRef)
				
; 				; only here set our bool to true
; 				hasChanged = true
; 			endif
; 		Else
; 			PlayerRef.AddPerk(RadsPerkFull)			
; 		endif
		
; 		CurrentRadsPerk = perkLevel
; 		; enable bloating suit ammo when we switch perks
; 		canGiveBloatingSuitAmmo = true		
; 	endif

; 	return hasChanged
; EndFunction

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



; ; ------------------------
; ; Check the total carried balloons, and apply the matching balloonsPerk to the player
; ; ------------------------
; Function ApplyBalloonsPerk()
; 	int currentCount = (carriedBalloons / 10)

; 	; when we have less then 10 balloons, clear all existing perks and don't apply a new one
; 	if (currentCount < 1)
; 		ClearAllBalloonsPerks(PlayerRef)
	
; 		; reset counter as well
; 		CurrentBalloonsPerk = 0
; 		return
; 	endif

; 	; limit to 4 just in case (we have 4 perks)
;     If (currentCount > 4)
;         currentCount = 4
;     EndIf

; 	; when we have enough balloons that we should have a difference in perk level, change perks
; 	if (CurrentBalloonsPerk != currentCount)
; 		; subtract 1 from our count as the Perks start from 0
; 		int newBalloonsPerk = currentCount -1
; 		ClearOldBalloonsPerks(PlayerRef, newBalloonsPerk)
; 		; grab the perk from the array if we aren't on maxed out morphs, else use the dedicated perk
; 		PlayerRef.AddPerk(BalloonsPerkArray[newBalloonsPerk])		
		
; 		CurrentBalloonsPerk = currentCount
; 	endif
; EndFunction

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
