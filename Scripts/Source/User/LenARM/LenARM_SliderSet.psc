Scriptname LenARM:LenARM_SliderSet extends Quest

; ------------------------
; ------------------------
; Quest input params

Group LenARM
	LenARM_Debug Property LenARM_Debug Auto Const
	LenARM_Util Property LenARM_Util Auto Const
EndGroup


; ------------------------
; ------------------------
; variables

SliderSet[] SliderSets

; flattened two-dimensional array[idxSliderSet][idxSliderName]
string[] SliderNames

; flattened two-dimensional array[idxSliderSet][idxSlot]
int[] UnequipSlots

; flattened two-dimensional array[idxSliderSet][idxSliderName]
float[] OriginalMorphs


; ------------------------
; ------------------------
; Structs

Struct SliderSet
	bool IsUsed

	; MCM values
	string SliderName
	float TargetMorph
	; [OBSOLETE], always 0
	float ThresholdMin
	; [OBSOLETE], always 100
	float ThresholdMax
	string UnequipSlot
	float ThresholdUnequip
	bool OnlyDoctorCanReset
	; [OBSOLETE], always true
	bool IsAdditive
	; [OBSOLETE], always true
	bool HasAdditiveLimit
	float AdditiveLimit
	bool ExcludeFromPopping
	; END: MCM values

	int NumberOfSliderNames
	int NumberOfUnequipSlots

	float BaseMorph
	float CurrentMorph
		
	bool IsMaxedOut
EndStruct


; ------------------------
; ------------------------
; methods

; For some reason doc comments from the first function after variable declarations are not picked up.
Function DummyFunction()
EndFunction


;
; Get the list of all SliderSets.
;
SliderSet[] Function GetAllSliderSets()
	; LenARM_Debug.TechnicalNote("GetAllSliderSets")
	return SliderSets
EndFunction

;
; Get SliderSet with id @idxSliderSet
;
SliderSet Function GetSliderSet(int idxSliderSet)
	return SliderSets[idxSliderSet]
EndFunction

;
; Get the list of all SliderNames
;
string[] Function GetAllSliderNames()
	return SliderNames
EndFunction

;
; Get SliderNames with id @idxSlider
;
string Function GetSliderName(int idxSlider)
	return SliderNames[idxSlider]
EndFunction


;
; Read the slider sets from the MCM config, and store them into the local variables.
; Will perform the initial local variables setup if these are not yet initialized.
; Will cleanup no longer existing slider sets if these existed in the local variables but are no longer in the MCM config.
;
Function LoadSliderSets(int numberOfSliderSets, Actor playerRef)
	LenARM_Debug.TechnicalNote("LoadSliderSets")
	; LenARM_Debug.Log("LoadSliderSets")
	; create arrays if not exist
	If (!SliderSets)
		SliderSets = new SliderSet[numberOfSliderSets]
	EndIf
	If (!SliderNames)
		SliderNames = new string[0]
	EndIf
	If (!UnequipSlots)
		UnequipSlots = new int[0]
	EndIf
	If (!OriginalMorphs)
		OriginalMorphs = new float[0]
	EndIf
	
	; get slider sets
	int idxSet = 0
	While (idxSet < numberOfSliderSets)
		SliderSet oldSet = SliderSets[idxSet]
		SliderSet newSet = SliderSet_Constructor(idxSet)
		SliderSets[idxSet] = newSet

		; when we found an existing sliderSet, reuse the BaseMorph, CurrentMorph and IsMaxedOut
		If (oldSet)
			newSet.BaseMorph = oldSet.BaseMorph
			newSet.CurrentMorph = oldSet.CurrentMorph
			newSet.IsMaxedOut = oldSet.IsMaxedOut
		EndIf
		
		; populate flattened arrays
		int sliderNameOffset = SliderSet_GetSliderNameOffset(idxSet)
		If (newSet.IsUsed)
			string[] names = LenARM_Util.StringSplit(newSet.SliderName, "|")
			int idxSlider = 0
			While (idxSlider < newSet.NumberOfSliderNames)
				float morph = BodyGen.GetMorph(playerRef, True, names[idxSlider], None)
				int currentIndex = sliderNameOffset + idxSlider
				If (!oldSet || idxSlider >= oldSet.NumberOfSliderNames)
					; insert into array
					SliderNames.Insert(names[idxSlider], currentIndex)
					OriginalMorphs.Insert(morph, currentIndex)
				Else
					; replace item
					SliderNames[currentIndex] = names[idxSlider]
					OriginalMorphs[currentIndex] = morph
				EndIf
				idxSlider += 1
			EndWhile
		EndIf
		; remove unused items
		If (oldSet && newSet.NumberOfSliderNames < oldSet.NumberOfSliderNames)
			SliderNames.Remove(sliderNameOffset + newSet.NumberOfSliderNames, oldSet.NumberOfSliderNames - newSet.NumberOfSliderNames)
		EndIf

		int unequipSlotOffset = SliderSet_GetUnequipSlotOffset(idxSet)
		If (newSet.IsUsed && newSet.NumberOfUnequipSlots > 0)
			string[] slots = LenARM_Util.StringSplit(newSet.UnequipSlot, "|")
			int idxSlot = 0
			While (idxSlot < newSet.NumberOfUnequipSlots)
				int currentIndex = unequipSlotOffset + idxSlot
				If (!oldSet || idxSlot >= oldSet.NumberOfUnequipSlots)
					; insert into array
					UnequipSlots.Insert(slots[idxSlot] as int, currentIndex)
				Else
					; replace item
					UnequipSlots[currentIndex] = slots[idxSlot] as int
				EndIf
				idxSlot += 1
			EndWhile
		EndIf
		; remove unused items
		If (oldSet && newSet.NumberOfUnequipSlots < oldSet.NumberOfUnequipSlots)
			UnequipSlots.Remove(unequipSlotOffset + newSet.NumberOfUnequipSlots, oldSet.NumberOfUnequipSlots - newSet.NumberOfUnequipSlots)
		EndIf
		idxSet += 1
	EndWhile
EndFunction

; 
; Setup a new SliderSet from MCM with id @idxSet
; 
SliderSet Function SliderSet_Constructor(int idxSet)
	;LenARM_Debug.Log("SliderSet_Constructor: " + idxSet)
	SliderSet sliderSet = new SliderSet
	sliderSet.SliderName = MCM.GetModSettingString("LenA_RadMorphing", "sSliderName:Slider" + idxSet)
	If (sliderSet.SliderName != "")
		sliderSet.IsUsed = true
		sliderSet.TargetMorph = MCM.GetModSettingFloat("LenA_RadMorphing", "fTargetMorph:Slider" + idxSet) / 100.0
		sliderSet.ThresholdMin = MCM.GetModSettingFloat("LenA_RadMorphing", "fThresholdMin:Slider" + idxSet) / 100.0
		sliderSet.ThresholdMax = MCM.GetModSettingFloat("LenA_RadMorphing", "fThresholdMax:Slider" + idxSet) / 100.0
		sliderSet.UnequipSlot = MCM.GetModSettingString("LenA_RadMorphing", "sUnequipSlot:Slider" + idxSet)
		sliderSet.ThresholdUnequip = MCM.GetModSettingFloat("LenA_RadMorphing", "fThresholdUnequip:Slider" + idxSet) / 100.0
		sliderSet.OnlyDoctorCanReset = MCM.GetModSettingBool("LenA_RadMorphing", "bOnlyDoctorCanReset:Slider" + idxSet)
		sliderSet.IsAdditive = MCM.GetModSettingBool("LenA_RadMorphing", "bIsAdditive:Slider" + idxSet)
		sliderSet.HasAdditiveLimit = MCM.GetModSettingBool("LenA_RadMorphing", "bHasAdditiveLimit:Slider" + idxSet)
		sliderSet.AdditiveLimit = MCM.GetModSettingFloat("LenA_RadMorphing", "fAdditiveLimit:Slider" + idxSet) / 100.0
		sliderSet.ExcludeFromPopping = MCM.GetModSettingBool("LenA_RadMorphing", "bExcludeFromPopping:Slider" + idxSet)

		string[] names = LenARM_Util.StringSplit(sliderSet.SliderName, "|")
		sliderSet.NumberOfSliderNames = names.Length

		If (sliderSet.UnequipSlot != "")
			string[] slots = LenARM_Util.StringSplit(sliderSet.UnequipSlot, "|")
			sliderSet.NumberOfUnequipSlots = slots.Length
		Else
			sliderSet.NumberOfUnequipSlots = 0
		EndIf
	Else
		sliderSet.IsUsed = false
	EndIf

	;LenARM_Debug.Log("  " + set)
	return sliderSet
EndFunction


; 
; Get the slider name offset for SliderSet id @idxSet
; 
int Function SliderSet_GetSliderNameOffset(int idxSet)
	int offset = 0
	int index = 0
	While (index < idxSet)
		offset += SliderSets[index].NumberOfSliderNames
		index += 1
	EndWhile
	return offset
EndFunction
; 
; Get the unequip slot offset for SliderSet id @idxSet
; 
int Function SliderSet_GetUnequipSlotOffset(int idxSet)
	int offset = 0
	int index = 0
	While (index < idxSet)
		offset += SliderSets[index].NumberOfUnequipSlots
		index += 1
	EndWhile
	return offset
EndFunction



;
; Reset saved morphs in all SliderSets
;
Function ResetSliderSetMorphs()
	int idxSet = 0
	While (idxSet < SliderSets.Length)
		SliderSet sliderSet = SliderSets[idxSet]
		sliderSet.BaseMorph = 0.0
		sliderSet.CurrentMorph = 0.0
		sliderSet.IsMaxedOut = false
		idxSet += 1
	EndWhile
EndFunction

;
; Reset stored variables
;
Function ResetVariables()
	SliderSets = none
	SliderNames = none
	UnequipSlots = none

	OriginalMorphs = none
EndFunction





;TODO voor nu werken deze zoals eerst; kmoet al die bool (en float) vars erin hangen samen met de enum, en in de configs hangen
bool Function GetOnlyDoctorCanReset(LenARM_SliderSet:SliderSet sliderSet)
	; If (OverrideOnlyDoctorCanReset != EOverrideBoolNoOverride)
	; 	return OverrideOnlyDoctorCanReset == EOverrideBoolTrue
	; Else
		return sliderSet.OnlyDoctorCanReset
	; EndIf
EndFunction

bool Function GetIsAdditive(LenARM_SliderSet:SliderSet sliderSet)
	; If (OverrideIsAdditive != EOverrideBoolNoOverride)
	; 	return OverrideIsAdditive == EOverrideBoolTrue
	; Else
		return sliderSet.IsAdditive
	; EndIf
EndFunction

bool Function GetHasAdditiveLimit(LenARM_SliderSet:SliderSet sliderSet)
	; If (OverrideHasAdditiveLimit != EOverrideBoolNoOverride)
	; 	return OverrideHasAdditiveLimit == EOverrideBoolTrue
	; Else
		return sliderSet.HasAdditiveLimit
	; EndIf
EndFunction

float Function GetAdditiveLimit(LenARM_SliderSet:SliderSet sliderSet)
	; If (OverrideHasAdditiveLimit != EOverrideBoolNoOverride)
	; 	return OverrideAdditiveLimit
	; Else
		return sliderSet.AdditiveLimit
	; EndIf
EndFunction



;
; Debug function to show the lowest SliderSet's current value
;
float Function Debug_GetLowestSliderPercentage()
	int idxSet = 0
	float lowestPercentage = 0

	; loop through the slidersets
	While (idxSet < SliderSets.Length)
		SliderSet sliderSet = SliderSets[idxSet]
		
		; only check the slidersets that have actual sliders
		If (sliderSet.NumberOfSliderNames > 0)
			; use sliderSet's currentMorph, unless we are additive, then use baseMorph as well
			float sliderPercentage = sliderSet.CurrentMorph
			If (GetIsAdditive(sliderSet))
				sliderPercentage += sliderSet.BaseMorph
			EndIf

			; limit the percentage to 100% if we get irradiated when already at max
			if (sliderPercentage > 1)
				sliderPercentage = 1
			endIf

			; as we setup lowestPercentage as 0, we want to set it to a value first, else Math.Min will always return 0
			if (lowestPercentage == 0)
				lowestPercentage = sliderPercentage
			else
				lowestPercentage = Math.Min(sliderPercentage, lowestPercentage)
			endif
		endif

		idxSet += 1
	EndWhile	

	return lowestPercentage
EndFunction

; ; 
; ; Calculate the morph percentage for the given sliderSet based on the given rads and the slider's min / max thresholds
; ; 
; float Function CalculateMorphPercentage(float newRads, SliderSet sliderSet)
; 	float morphPercentage = 0.0

; 	; calculate the amount of rads we see as the max (by default 1000, modified by a multiplier)
; 	float maxRads = 1.0 * MaxRadiationMultiplier

; 	; do the same for our min / max threshold
; 	float minThreshold = sliderSet.ThresholdMin * maxRads
; 	float maxThreshold = sliderSet.ThresholdMax * maxRads

; 	If (newRads < minThreshold)
; 		morphPercentage = 0.0
; 	ElseIf (newRads > maxThreshold)
; 		morphPercentage = 1.0
; 	Else
; 		morphPercentage = (newRads - minThreshold) / (maxThreshold - minThreshold)
; 	EndIf
	
; 	;TechnicalNote("rads: " + newRads + "; morph: " + morphPercentage + "; minT: " + minThreshold + "; maxT: " + maxThreshold + "; %: " + MaxRadiationMultiplier)

; 	return morphPercentage
; EndFunction



; ; ------------------------
; ; Calculate the morph for the given sliderSet based on the given morph percentage and target morph
; ; ------------------------
; float Function CalculateMorphs(int idxSlider, float morphPercentage, float targetMorph)
; 	float morphBonus = 0.0
	
; 	string matchingSlider = SliderNames[idxSlider]

; 	; permanent breast size increase
; 	if (matchingSlider == "Breasts")
; 		; player has (or has had) molecow disease
; 		if (hasHadMoleCowDisease)
; 			morphBonus += 0.15

; 			; player also carries balloons
; 			if (carriedBalloons > 0)
; 				morphBonus += 0.1
; 			endif
; 		endif
; 	; permanent nipple perkiness increase
; 	elseif (matchingSlider == "NipplePerkiness" || matchingSlider == "NipplePerk2")
; 		; player has bloating suit equipped
; 		if (hasBloatingSuitEquipped)
; 			morphBonus += 0.3
; 		endif
; 		; player has popped NPC with kitana mask
; 		if (hasKitanaMaskPoppedNPC)
; 			morphBonus += 0.5
; 		endif
; 		; player has nipple piercing equipped
; 		if (hasNippleBlockers)
; 			morphBonus += 0.25
; 		endif
; 	; permanent double melon increase
; 	elseif (matchingSlider == "DoubleMelon")
; 		; player is popping expert
; 		if (isPoppingExpert)
; 			morphBonus += 0.25
; 		endif
; 		; player has mooMilk addiction
; 		if (hasMooMilkAddiction)
; 			morphBonus += 0.5
; 		endif
; 		; player has kitana mask equipped
; 		if (hasKitanaMaskEquipped)
; 			morphBonus += 0.25
; 		endif
; 		; player has balloonsperks
; 		morphBonus += (CurrentBalloonsPerk * 0.1)
; 	endif

; 	return (OriginalMorphs[idxSlider] + morphBonus + (morphPercentage * targetMorph))
; EndFunction

; ; ------------------------
; ; Apply the given sliderSet's morphs to the matching BodyGen sliders
; ; ------------------------
; Function SetMorphs(int idxSet, SliderSet sliderSet, float morphPercentage)
; 	int sliderNameOffset = SliderSet_GetSliderNameOffset(idxSet)
; 	int idxSlider = sliderNameOffset
; 	int sex = PlayerRef.GetLeveledActorBase().GetSex()
; 	While (idxSlider < sliderNameOffset + sliderSet.NumberOfSliderNames)
; 		float newMorph = CalculateMorphs(idxSlider, morphPercentage, sliderSet.TargetMorph)

; 		BodyGen.SetMorph(PlayerRef, sex==ESexFemale, SliderNames[idxSlider], kwMorph, newMorph)
; 		; Log("    setting slider '" + SliderNames[idxSlider] + "' to " + newMorph + " (base value is " + OriginalMorphs[idxSlider] + ") (base morph is " + sliderSet.BaseMorph + ") (target is " + sliderSet.TargetMorph + ")")
		
; 		idxSlider += 1
; 	EndWhile
; EndFunction

; bool Function SetMorphsAndReturnTrue(int idxSet, SliderSet sliderSet, float morphPercentage)
; 	SetMorphs(idxSet, sliderSet, morphPercentage)
; 	return true
; EndFunction

; ; ------------------------
; ; Restore the original BodyGen values for each slider, and set all sliderset's morphs to 0
; ; Will also reset various global bools used on various places
; ; ------------------------
; Function ResetMorphs()
; 	Log("ResetMorphs")
; 	RestoreOriginalMorphs()

; 	; re-enable the display of the max-morphs message
; 	HasReachedMaxMorphs = false;
; 	; reset the pop warnings
; 	PopWarnings = 0

; 	; reset the current and total rads
; 	; we need to reset both else they will start mismatching the next timerMorphTick and give wonky behaviour
; 	CurrentRads = 0
; 	TotalRads = 0

; 	; reset any additional Bloating the player had
; 	; works in the same way Doctor heals rads
; 	int RadsToHeal = (PlayerRef.GetValue(avBloating) as int)
; 	PlayerRef.RestoreValue(avBloating, RadsToHeal)

; 	; reset the rad perks
; 	ClearAllRadsPerks(PlayerRef)

; 	; reset saved morphs in SliderSets
; 	int idxSet = 0
; 	While (idxSet < SliderSets.Length)
; 		SliderSet sliderSet = SliderSets[idxSet]
; 		sliderSet.BaseMorph = 0.0
; 		sliderSet.CurrentMorph = 0.0
; 		sliderSet.IsMaxedOut = false
; 		idxSet += 1
; 	EndWhile
; EndFunction

; Function RestoreOriginalMorphs()
; 	Log("RestoreOriginalMorphs")
; 	; restore base values
; 	int i = 0
; 	int sex = PlayerRef.GetLeveledActorBase().GetSex()
; 	While (i < SliderNames.Length)
; 		BodyGen.SetMorph(PlayerRef, sex==ESexFemale, SliderNames[i], kwMorph, OriginalMorphs[i])
; 		i += 1
; 	EndWhile
; 	BodyGen.UpdateMorphs(PlayerRef)
; EndFunction




; ========================================================
; ========================================================
; BLOCK
; ========================================================
; ========================================================



; ; ------------------------
; ; Take given chance, subtract player's Luck, roll a dice, and return whether the dice is lower then the chance
; ; ------------------------
; bool Function ShouldPop(int popChance)
; 	int random = Utility.RandomInt(1, 10)
; 	int playerLuck = PlayerRef.GetValue(LuckAV) as int

; 	; player's Luck stat can decrease chance of popping
; 	; take player luck, subtract 1, divide by 3 while rounding down
; 	; we do the luck - 1 so a luck of 1 doesn't always give a minimum boost of 1
; 	; ie luck of 1 becomes 0, luck 3 becomes 1, luck of 10 becomes 3
; 	int luckMod = ((playerLuck-1) / 3) * -1
; 	; molecow disease increase chance of popping (breasts are already pre-bloated)
; 	int moleCowDiseaseMod = hasHadMoleCowDisease as int
; 	; nipple blockers increase chance of popping (can't lactate easily to relief pressure)
; 	int nippleBlockersMod = hasNippleBlockers as int
; 	; carrying balloons when having molecow disease increase chance of popping (breasts are even more pre-bloated)
; 	int balloonsMod = 0
; 	if (hasHadMoleCowDisease && carriedBalloons > 0)
; 		balloonsMod = 1
; 	endif
; 	; kitana mask equipped increase chance of popping (breasts are already pre-bloated + cursed)
; 	int kitanaMaskMod = 0
; 	if (hasKitanaMaskEquipped)
; 		kitanaMaskMod = 2
; 	endif

; 	; bloating suit equipped decrease chance of popping (milkers provide relief)
; 	int bloatSuitMod = (hasBloatingSuitEquipped as int)*-1

; 	;Note("luck " + luckMod + "; molecow " + moleCowDiseaseMod + "; nipple " + nippleBlockersMod + "; suit " + bloatSuitMod)

; 	; base pop chance is X/10, but X can be modified by above modifiers
; 	; depending on X and modifiers it can become 0 or less, so cap it to a minimum of 1
; 	int modifiedPopChance = popChance + luckMod + moleCowDiseaseMod + nippleBlockersMod + balloonsMod + kitanaMaskMod + bloatSuitMod
; 	if (modifiedPopChance < 1)
; 		modifiedPopChance = 1
; 	endif

; 	; when the dice value is lower then (modified) pop chance, return true
; 	; else return false
; 	bool shouldPop = random <= modifiedPopChance
; 	return shouldPop
; EndFunction

; ; ------------------------
; ; Roll a dice whether to increase the PopWarnings by 1, with various effects on a success
; ; ------------------------
; Function CheckPopWarnings()
; 	;TODO komt hier langs na startup, en kan dus dan popstates increasen
; 	;komt vermoelijk als je rads hebt als ie startup moet doen => Timer ziet dat als rads increase => triggered deze functie

; 	; 30% base chance to trigger
; 	bool shouldPop = ShouldPop(3)

; 	; when enabled, always play the dedicated sounds even if we don't trigger
; 	if (PopUseFullSounds)
; 		LenARM_FullGroanSound.Play(PlayerRef)
; 	endif

; 	; when the dice decides we should not pop, return unless when we have a forceUpdate
; 	; we are already close to popping so any forced update of the morphs triggers the next pop warning
; 	if (!shouldPop && !forceUpdate)
; 		return
; 	endif

; 	if (PopWarnings == 0)
; 		LenARM_PopWarning0Message.Show()
; 		PopWarnings += 1
; 		ExtendMorphs(0.25, shouldPop = false, soundId = 2)
; 	ElseIf (PopWarnings == 1)
; 		LenARM_PopWarning1Message.Show()
; 		PopWarnings += 1
; 		ExtendMorphs(0.5, shouldPop = false, soundId = 3)
; 	ElseIf (PopWarnings == 2)
; 		LenARM_PopWarning2Message.Show()
; 		PopWarnings += 1
; 		ExtendMorphs(0.75, shouldPop = false, soundId = 4)
; 	Else
; 		; IsPopping = true
; 		TryPop()
; 	endif
; EndFunction

; ; so we can access it from the sub-scripts
; bool Function IsPoppingEnabled()
; 	return EnablePopping
; EndFunction

; ; ------------------------
; ; Safety net so popping doesn't break NPC conversations or VATS
; ; ------------------------
; Function TryPop()
; 	var isInVATS = (Game.IsMovementControlsEnabled()) == false
; 	var isInScene = PlayerRef.IsInScene()
; 	var isInTrade = Utility.IsInMenuMode()

; 	; player should not be in VATS, not be in a conversation and not be trading
; 	If (!isInVATS && !isInScene && !isInTrade)
; 		Pop()
; 	; if so, put on the queue and retry after a second
; 	Else
; 		StartTimer(1, ETimerDelayPop)
; 	EndIf
; EndFunction

; ; ------------------------
; ; Paralyze the player, expand current morphs several times, reset the morphs, apply debuff, and unparalyze the player
; ; ------------------------
; Function Pop()
; 	; don't pop player that is dead
; 	if (PlayerRef.IsDead())
; 		return
; 	endif

; 	int currentPopState = 1

; 	IsPopping = true

; 	LenARM_PopMessage.Show()
; 	Log("pop!")

; 	; force third person camera when we paralyze the player
; 	if (PopShouldParalyze)
; 		Game.ForceThirdPerson()							
; 	endif
; 	Utility.Wait(0.5)

; 	; reset rads in case player is in a high-rads zone
; 	RestorePlayerRads()

; 	; play the full sound for player
; 	PlayMorphSound(PlayerRef, 4)
; 	; then paralyse player and then knock them out
; 	; the order of first paralysing and then knocking out is important, lest you get odd glitches
; 	if (PopShouldParalyze)
; 		ParalyzeActor(PlayerRef)
; 	endif
; 	Utility.Wait(0.7)

; 	; gradually increase the morphs and unequip the clothes
; 	While (currentPopState < PopStates)			
; 		; stop if player has died
; 		if (PlayerRef.IsDead())
; 			return
; 		endif

; 		ExtendMorphs(currentPopState, shouldPop = false)

; 		; for the unequip state we also want to strip all clothes and armor
; 		If (currentPopState == PopStripState)
; 			UnequipAll()
; 		endif

; 		;Utility.Wait(0.7)
; 		Utility.Wait(0.3)

; 		currentPopState += 1
; 	EndWhile
	
; 	; stop if player has died
; 	if (PlayerRef.IsDead())
; 		return
; 	endif

; 	; apply the final morphs, and do the 'pop', resetting all the morphs back to 0
; 	ExtendMorphs(currentPopState, shouldPop = true)

; 	; apply the debuffs on the player and reset the player's rads by ingesting the respective potions
; 	PlayerRef.EquipItem(PoppedPotion, abSilent = true)
; 	RestorePlayerRads()

; 	; unset the IsPopping flag before we undo the paralysing
; 	IsPopping = false
		
; 	if (!TutorialDisplayed_Popped)
; 		TutorialDisplayed_Popped = true
; 		LenARM_Tutorial_PoppedMessage.ShowAsHelpMessage("LenARM_Tutorial_PoppedMessage", 8, 0, 1)
; 	endif
				
; 	; wait a bit before we can actually stand up again
; 	if (PopShouldParalyze)
; 		Utility.Wait(1.5)

; 		UnParalyzeActor(PlayerRef)

; 		;TODO make configurabel
; 		;ReEquipAll()
; 	endif
; EndFunction

; Function RestorePlayerRads()
; 	int RadsToHeal = (PlayerRef.GetValue(Rads) as int)
; 	PlayerRef.RestoreValue(Rads, RadsToHeal)
; EndFunction

; ; ------------------------
; ; Increase all sliders by a percentage multiplied with the input for the player, and play the sound with given id (default Swell sound)
; ; Does not store the updated sliders' CurrentMorphs, as we will call ResetMorphs afterwards anyway
; ; ------------------------
; Function ExtendMorphs(float step,  bool shouldPop, int soundId = 5)
; 	; Log("extending morphs with: " + step)

; 	; calculate the new morphs multiplier
; 	float multiplier = CalculateExtendMorphs(step)

; 	int idxSet = 0
; 	; apply it to all morphs from slidersets which aren't excluded
; 	While (idxSet < SliderSets.Length)
; 		SliderSet sliderSet = SliderSets[idxSet]		
; 		If (sliderSet.NumberOfSliderNames > 0 && !sliderSet.ExcludeFromPopping)
; 			SetMorphs(idxSet, sliderSet, multiplier)
; 		EndIf
; 		idxSet += 1
; 	EndWhile
	
; 	if (shouldPop)
; 		; apply the final morphs, and do the 'pop', resetting all the morphs back to 0
; 		; for this situation we do want to wait for the sound effect to finish playing
; 		BodyGen.UpdateMorphs(PlayerRef)
; 		LenARM_PrePopSound.PlayAndWait(PlayerRef)
; 		LenARM_PopSound.Play(PlayerRef)
; 		ResetMorphs()	
; 	else
; 		; then apply the morphs (with sound) to the player
; 		BodyGen.UpdateMorphs(PlayerRef)
; 		PlayMorphSound(PlayerRef, soundId)
; 	endif
; EndFunction

; float Function CalculateExtendMorphs(float step)	
; 	; calculate the new morphs multiplier
; 	float multiplier = 1.0 + (step/8)

; 	return multiplier
; EndFunction


; ; ------------------------
; ; Increase all sliders by a percentage multiplied with the input for the given actor.
; ; Intended for use on NPCs.
; ; ------------------------
; Function BloatActor_Internal(Actor akTarget, int currentBloatStage, int toAdd, int bloatType)
; 	; don't bloat actor that is dead
; 	if (akTarget.IsDead())
; 		return
; 	endif

; 	; calculate the target bloatStage
; 	; -1 means bloat to pop
; 	int targetBloatStage = currentBloatStage
; 	if (toAdd == -1)
; 		targetBloatStage = popNPCBloatStage
; 	else
; 		targetBloatStage += toAdd
; 	endif
; 	; limit to our max
; 	if (targetBloatStage > popNPCBloatStage)
; 		targetBloatStage = popNPCBloatStage
; 	endif

; 	int nextBloatStage = currentBloatStage + 1
; 	float morphPercentage = 0.2

; 	; Note(currentBloatStage + "; " + targetBloatStage)

; 	; when actor should get bloated to popping, always paralyze first (unless legendary or a HalluciGen Agent NPC)
; 	if (toAdd == -1 && bloatType != EBloatTypeLegendary && !akTarget.HasKeyword(ActorTypeBloatingAgent))
; 		ParalyzeActor(akTarget)
; 	endIf

; 	; when bloatType is normal or concentrated keep bloating the actor until the bloatStage is equal to target
; 	if (bloatType <= EBloatTypeConcentrated)
; 		while (nextBloatStage <= targetBloatStage)
; 			; don't bloat actor that is dead
; 			if (akTarget.IsDead())
; 				return
; 			endif

; 			ApplyActorBloatStage(akTarget, nextBloatStage, morphPercentage, bloatType)
			
; 			nextBloatStage += 1
; 		endwhile
; 	; when bloatType is messy or legendary immediately bloat to max and go to popping
; 	else
; 		; calculate the diff between current bloat stage and max and use that as our percentage
; 		int bloatStageDiff = maxNPCBloatStages - currentBloatStage
; 		; Note("current: " + currentBloatStage + "; target: " + targetBloatStage + "; diff: " + bloatStageDiff)
; 		; first bloat to max if we aren't at max yet
; 		if (bloatStageDiff > 0)
; 			float maxMorphPercentage = morphPercentage * bloatStageDiff			
; 			ApplyActorBloatStage(akTarget, maxNPCBloatStages, maxMorphPercentage, bloatType)
; 		endif

; 		; immediately bloat to pop afterwards
; 		ApplyActorBloatStage(akTarget, popNPCBloatStage, morphPercentage, bloatType)
; 	endif
; EndFunction

; ; public endpoints used in the Magic Effect scripts
; Function BloatActor(Actor akTarget, int currentBloatStage, int toAdd)
; 	BloatActor_Internal(akTarget, currentBloatStage, toAdd, EBloatTypeNormal)
; EndFunction
; Function BloatActorConcentrated(Actor akTarget, int currentBloatStage, int toAdd)
; 	BloatActor_Internal(akTarget, currentBloatStage, toAdd, EBloatTypeConcentrated)
; EndFunction
; Function BloatActorMessy(Actor akTarget, int currentBloatStage, int toAdd)
; 	BloatActor_Internal(akTarget, currentBloatStage, toAdd, EBloatTypeMessy)
; EndFunction
; Function BloatActorLegendary(Actor akTarget, int currentBloatStage, int toAdd)
; 	BloatActor_Internal(akTarget, currentBloatStage, toAdd, EBloatTypeLegendary)
; EndFunction


; Function ApplyActorBloatStage(Actor akTarget, int nextBloatStage, float morphPercentage, int bloatType)
; 	; perkLevel is equal to the bloat state 
; 	int perkLevel = nextBloatStage

; 	; limit to 5 just in case (we have 5 perks, starting from 0)
;     If (perkLevel > 5)
;         perkLevel = 5
;     EndIf

; 	; compare current akTarget radsPerk level vs the new level, change perks if needed
; 	if (GetCurrentRadsPerkLevel(akTarget) != perkLevel)
; 		ClearOldRadsPerks(akTarget, perkLevel)
; 		; grab the perk from the array if we aren't on maxed out morphs, else use the dedicated perk
; 		if (perkLevel != 5)
; 			akTarget.AddPerk(RadsPerkArray[perkLevel])		
; 		Else
; 			akTarget.AddPerk(RadsPerkFull)			
; 		endif
; 	endif

; 	; do a random delay before appying the morphs (and morph sounds) on the akTarget
; 	; float randomFloat = GetRandomDelay(2,3)
; 	float randomFloat = GetRandomDelay(1,2)
; 	Utility.Wait(randomFloat)

; 	; only apply initial morphs if we are not going to pop
; 	if (nextBloatStage <= maxNPCBloatStages)
; 		SetBloatMorphs(akTarget, morphPercentage, shouldPop = false)
; 		BodyGen.UpdateMorphs(akTarget)
; 	endif

; 	; play the matching sound
; 	if (perkLevel < maxNPCBloatStages)
; 		PlayMorphSound(akTarget, 3)
; 	elseif (perkLevel == maxNPCBloatStages && nextBloatStage == maxNPCBloatStages)
; 		PlayMorphSound(akTarget, 4)
; 	; pop the actor 
; 	elseif (perkLevel == maxNPCBloatStages && nextBloatStage > maxNPCBloatStages)		
; 		Utility.Wait(randomFloat)
; 		BloatPopActor(akTarget, bloatType)
; 	endif
; EndFunction

; Function BloatPopActor(Actor akTarget, int bloatType)
; 	; pause self-bloat timer
; 	CancelTimer(ETimerKitanaMask)

; 	bool isConcentrated = bloatType == EBloatTypeConcentrated
; 	bool isForcedMessy = bloatType == EBloatTypeMessy
; 	; when bloatpopping a HalluciGen Agent NPC always make it legendary
; 	bool isLegendary = bloatType == EBloatTypeLegendary || akTarget.HasKeyword(ActorTypeBloatingAgent)

; 	; when we pop a non-essential hostile enemy, 10% chance that we pop in a more permanent way
; 	float messyPopChance = 0.1
; 	; when hit by concentrated shot the permanent pop chance is 50%
; 	if (isConcentrated)
; 		messyPopChance = 0.5
; 	; when forced to messy pop then the permanent pop chance is 100%
; 	elseif (isForcedMessy || isLegendary)
; 		messyPopChance = 1
; 	endif

; 	; since IsProtected is only on ActorBase make a quick cast
; 	ActorBase actorBaseTarget = akTarget.GetBaseObject() as ActorBase

; 	bool isHostile = akTarget.IsHostileToActor(PlayerRef) == true
; 	bool isProtected = actorBaseTarget.IsProtected()
; 	bool isEssential = actorBaseTarget.IsEssential()
; 	bool canForcedMessy = (isForcedMessy || isLegendary) && isHostile
; 	; only allow messy pops when:
; 	; - target is not player
; 	; - target is hostile to player
; 	; - target is not protected or essential (game does some very weird things if we messy pop those)
; 	; - random die roll is below our messyPopChance
; 	bool shouldMessyPop = (akTarget != PlayerRef && isHostile && !isProtected && !isEssential && utility.RandomFloat() <= messyPopChance)

; 	; before we start expanding log the current breasts size
; 	float npcMorph = BodyGen.GetMorph(akTarget, True, "Breasts", None)
	
; 	; the bigger the breasts are, the more milk we will add at the end
; 	; current settings' base morph is 0.5 
; 	int milkToAdd = 3
; 	if (npcMorph >= 0.55)
; 		milkToAdd += 1
; 	endif
; 	if (npcMorph >= 0.65)
; 		milkToAdd += 1
; 	endif
; 	if (npcMorph >= 0.80)
; 		milkToAdd += 1
; 	endif
; 	if (npcMorph >= 0.95)
; 		milkToAdd += 1
; 	endif
; 	if (npcMorph >= 1.1)
; 		milkToAdd += 1
; 	endif

; 	; paralyze actor first if not legendary
; 	PlayMorphSound(akTarget, 4)
; 	if (!isLegendary)
; 		ParalyzeActor(akTarget)
; 	endif
	
; 	; add bloating ammo to actor's inventory
; 	akTarget.AddItem(ThirstZapperBloatAmmo, 1, abSilent = true)

; 	int currentPopState = 1
; 	float multiplier = 0.1
; 	float totalPopMultiplier = 0

; 	; do a random delay before appying the morphs (and morph sounds) on the akTarget
; 	float randomFloat = GetRandomDelay(1,2) ;(2,3)
; 	Utility.Wait(randomFloat)

; 	int popStatesToUse = PopStates
; 	bool playAltMorphSound = false

; 	; when we should messy pop we change the amount of states and bloat multipliers
; 	if (shouldMessyPop)
; 		if (canForcedMessy)
; 			playAltMorphSound = true

; 			; forced messy pop bloats actor at normal rate but much larger and immediately strips them
; 			if (!isLegendary)
; 				popStatesToUse = PopStates
; 				multiplier *= 3.5
; 				UnequipAllNPC(akTarget)
; 			; legendary pop bloats actor at normal rate but even larger then forced messy but doesn't strip them
; 			else
; 				popStatesToUse = PopStates
; 				multiplier *= 3.75
; 			endif
; 		; 'normal' messy pop bloats actor twice as long and larger as warning for attent player
; 		else
; 			popStatesToUse *= 2
; 			multiplier *= 1.5
; 		endif
; 	endif

; 	; gradually increase the morphs and unequip the clothes
; 	While (currentPopState < popStatesToUse)	
; 		; don't bloat actor that is dead
; 		if (akTarget.IsDead())
; 			;TODO hier moet kitana mask timer weer gestart worden	
; 			; ; restart self-morph timer when requirements not yet met
; 			; if (hasKitanaMaskEquipped && kitanaMaskMessyPoppedRequirementMet == false)
; 			; 	StartTimer(kitanaMaskSelfMorphTimer, ETimerKitanaMask)
; 			; endif	

; 			; killing legendary bloating enemies will just pop them directly
; 			if (isLegendary)
; 				; we need to do some calculations so we go back to the original NPC's morphs
; 				float reset = (1.0 + totalPopMultiplier) * -1
; 				SetBloatMorphs(akTarget, reset, shouldPop = false)
; 				BloatPopActor_HandleMessy(akTarget, milkToAdd, canForcedMessy, isLegendary)
; 			endif
; 			return
; 		endif
		
; 		SetBloatMorphs(akTarget, multiplier, shouldPop = true)
; 		totalPopMultiplier += multiplier
		
; 		BodyGen.UpdateMorphs(akTarget)
; 		; play normal swell sound when bloating normally
; 		if (currentPopState < PopStates && !playAltMorphSound)
; 			PlayMorphSound(akTarget, 5)
; 		; when we are bloating beyond normal play the alt swell sound 
; 		else
; 			PlayMorphSound(akTarget, 6)
; 		endif

; 		; add bloating ammo to actor's inventory
; 		akTarget.AddItem(ThirstZapperBloatAmmo, 1, abSilent = true)

; 		; for the unequip state we also want to strip all clothes and armor
; 		If (!canForcedMessy && (currentPopState == PopStripState || currentPopState == PopStates))
; 			UnequipAllNPC(akTarget)
; 		endif

; 		Utility.Wait(0.7) ;(0.3) ;(1.0)

; 		currentPopState += 1
; 	EndWhile

; 	; don't pop actor that is dead
; 	if (akTarget.IsDead())
; 		;TODO hier moet kitana mask timer weer gestart worden		
; 		; ; restart self-morph timer when requirements not yet met
; 		; if (hasKitanaMaskEquipped && kitanaMaskMessyPoppedRequirementMet == false)
; 		; 	StartTimer(kitanaMaskSelfMorphTimer, ETimerKitanaMask)
; 		; endif
; 		return
; 	endif

; 	; apply the final morphs, and do the 'pop'
; 	SetBloatMorphs(akTarget, multiplier, shouldPop = true)				
; 	totalPopMultiplier += multiplier
	
; 	BodyGen.UpdateMorphs(akTarget)
	
; 	; we need to do some calculations so we go back to the original NPC's morphs
; 	float reset = (1.0 + totalPopMultiplier) * -1
; 	SetBloatMorphs(akTarget, reset, shouldPop = false)

; 	; messy pop kills actor and places a grenade explosion
; 	if (shouldMessyPop)
; 		BloatPopActor_HandleMessy(akTarget, milkToAdd, canForcedMessy, isLegendary)
; 	; normal pop keeps actor paralyzed for a bit and places a normal explosion
; 	else
; 		BloatPopActor_HandleNormal(akTarget, milkToAdd)
; 	endif
; EndFunction

; ; messy pop kills actor and places a grenade explosion
; Function BloatPopActor_HandleMessy(Actor akTarget, int milkToAdd, bool canForcedMessy, bool isLegendary)
; 	LenARM_PrePopMessySound.PlayAndWait(akTarget)

; 	; add some concentrated bloating ammo to actor's inventory when they've been allowed to pop
; 	; reduce by 3 (capped to min 1) to not give too many freebies
; 	; if forced messy then always only give 1 concentrated as a tradeoff
; 	milkToAdd -= 3
; 	if (milkToAdd < 1 || canForcedMessy)
; 		milkToAdd = 1
; 	endif
; 	akTarget.AddItem(ThirstZapperBloatAmmo_Concentrated, milkToAdd, abSilent = true)	

; 	; clear rad perks so we don't keep ambient noise
; 	ClearAllRadsPerks(akTarget)

; 	LenARM_PopMessySound.Play(akTarget)
; 	; spread the joy to nearby NPCs
; 	akTarget.PlaceAtMe(BloatGrenadeExplosion)	

; 	; reset all the morphs back to 0
; 	; do this for messy bloatpopping too otherwise after respawning the NPC will still have the morphs
; 	BodyGen.UpdateMorphs(akTarget)

; 	; dismember and kill actor
; 	; sadly no way to give the XP to the player even if we tell the player is the killer
; 	akTarget.Dismember("Torso", true, true, true)
; 	akTarget.Kill()

; 	; unparalyze the actor
; 	; do this for messy bloatpopping too otherwise after respawning the NPC will still be paralyzed
; 	if (!isLegendary)
; 		UnParalyzeActor(akTarget)
; 	endif
	
; 	float distanceToPlayer = PlayerRef.GetDistance(akTarget)

; 	; bloat player and give temp buff if kitana mask is equipped and within range
; 	; this takes priority over having the bloating suit equipped as well
; 	if (hasKitanaMaskEquipped)
; 		; always bloat player independent of distance
; 		KitanaMaskSelfMorph_Kill()

; 		if (distanceToPlayer < kitanaMaskPopDetectRadius)
; 			LenARM_NPCPopComment.Play(PlayerRef)
; 			PlayerRef.EquipItem(BloatMaskPoppedNPCBuff, abSilent = true)
; 		endif
; 	; give player a temp buff if bloating suit is equipped and within range
; 	elseif (hasBloatingSuitEquipped && distanceToPlayer < bloatingSuitPopDetectRadius)
; 		LenARM_NPCPopComment.Play(PlayerRef)
; 		PlayerRef.EquipItem(BloatSuitPoppedNPCBuff, abSilent = true)
; 	endif
; EndFunction

; ; normal pop keeps actor paralyzed for a bit and places a normal explosion
; Function BloatPopActor_HandleNormal(Actor akTarget, int milkToAdd)
; 	LenARM_PrePopSound.PlayAndWait(akTarget)

; 	; add some more bloating ammo to actor's inventory when they've been allowed to pop
; 	akTarget.AddItem(ThirstZapperBloatAmmo, milkToAdd, abSilent = true)

; 	LenARM_PopSound.Play(akTarget)
; 	; spread the joy to nearby NPCs
; 	akTarget.PlaceAtMe(BloatNPCPopExplosion)		

; 	; reset all the morphs back to 0
; 	BodyGen.UpdateMorphs(akTarget)

; 	ClearAllRadsPerks(akTarget)
; 	akTarget.EquipItem(PoppedPotion, abSilent = true)
	
; 	; restart self-morph timer when requirements not yet met
; 	if (hasKitanaMaskEquipped && (PlayerRef.HasPerk(PoppingExpertPerk1) == false))
; 		StartTimer(kitanaMaskSelfMorphTimer, ETimerKitanaMask)
; 	endif
; EndFunction


; Function SetBloatMorphs(Actor akTarget, float morphPercentage, bool shouldPop)	
; 	int idxSet = 0

; 	; apply it to all morphs from slidersets which aren't excluded
; 	While (idxSet < SliderSets.Length)
; 		SliderSet sliderSet = SliderSets[idxSet]		
; 		If (sliderSet.NumberOfSliderNames > 0);  && (!shouldPop || (shouldPop && !sliderSet.ExcludeFromPopping)))
; 			int sliderNameOffset = SliderSet_GetSliderNameOffset(idxSet)
; 			int idxSlider = sliderNameOffset
; 			int sex = akTarget.GetLeveledActorBase().GetSex()
; 			While (idxSlider < sliderNameOffset + sliderSet.NumberOfSliderNames)
; 				string slider = SliderNames[idxSlider]

; 				;TODO not the most efficient way tho...	
; 				float npcMorph = BodyGen.GetMorph(akTarget, True, slider, None)

; 				float newMorph = npcMorph + (morphPercentage * sliderSet.targetMorph)
; 				; float newMorph = CalculateMorphs(idxSlider, morphPercentage, sliderSet.TargetMorph)

; 				; ;TODO debug ding
; 				; if (slider == "Breasts")
; 				; 	Log(npcMorph + "; " + morphPercentage + "; " + sliderSet.targetMorph + "; " + newMorph)
; 				; endif
						
; 				BodyGen.SetMorph(akTarget, sex==ESexFemale, slider, kwMorph, newMorph)
; 				idxSlider += 1
; 			EndWhile
; 		EndIf
; 		idxSet += 1
; 	EndWhile
; EndFunction


Group EnumSex
	int Property ESexMale = 0 Auto Const
	int Property ESexFemale = 1 Auto Const
EndGroup

; Group Constants
; 	int Property _NUMBER_OF_SLIDERSETS_ = 20 Auto Const
; EndGroup

Group EnumNPCBloatType
	int Property EBloatTypeNormal = 1 Auto Const
	int Property EBloatTypeConcentrated = 2 Auto Const
	int Property EBloatTypeMessy = 3 Auto Const
	int Property EBloatTypeLegendary = 4 Auto Const
EndGroup


