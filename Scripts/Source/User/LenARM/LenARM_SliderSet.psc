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
