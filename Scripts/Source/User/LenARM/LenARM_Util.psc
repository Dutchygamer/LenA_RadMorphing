Scriptname LenARM:LenARM_Util extends Quest

; ------------------------
; ------------------------
; Quest input params

Group LenARM
	LenARM_Debug Property LenARM_Debug Auto
EndGroup

Group Properties
	ActorValue Property ParalysisAV Auto Const
	Keyword property ArmorTypeUnstrippable auto
EndGroup

; ------------------------
; ------------------------
; variables

FormList DD_FL_All


; ------------------------
; ------------------------
; methods

; For some reason doc comments from the first function after variable declarations are not picked up.
Function DummyFunction()
EndFunction


;
; Split string @target into array at @delimiter
;
string[] Function StringSplit(string target, string delimiter)
	;Log("splitting '" + target + "' with '" + delimiter + "'")
	string[] result = new string[0]
	string current = target
	int idx = LL_Fourplay.StringFind(current, delimiter)
	;Log("split idx: " + idx + " current: '" + current + "'")
	While (idx > -1 && current)
		result.Add(LL_Fourplay.StringSubstring(current, 0, idx))
		current = LL_Fourplay.StringSubstring(current, idx+1)
		idx = LL_Fourplay.StringFind(current, delimiter)
		;Log("split idx: " + idx + " current: '" + current + "'")
	EndWhile
	If (current)
		result.Add(current)
	EndIf
	;Log("split result: " + result)
	return result
EndFunction

;
; Clamp @value between @limit1 and @limit2
;
float Function Clamp(float value, float limit1, float limit2)
	float lower = Math.Min(limit1, limit2)
	float upper = Math.Max(limit1, limit2)
	return Math.Min(Math.Max(value, lower), upper)
EndFunction

;
; Get a random float value between @min and @max
; When no params given @min is 2 and @max is 6
;
float Function GetRandomDelay(int min = 2, int max = 6)
	return (Utility.RandomInt(min,max) * 0.1) as float
EndFunction


;
; Initialized DD_FL_All FormList with @value
;
Function Init_DD_FL_All(FormList value)
	DD_FL_All = value
EndFunction


;
; Checks if @akTarget has Torso armor equipped
;
bool Function HasTorsoEquipped(Actor akTarget)
	; in PA always return false
	If (akTarget.IsInPowerArmor())
		return false
	EndIf

	bool found = false
	int idxSlot = 0

	; these are all the slots we want to unequip
	int[] allSlots = new int[0]	
	allSlots.Add(3)  ; body
	allSlots.Add(11) ; chest armor

	; check for each slot
	While (idxSlot < allSlots.Length && !found)
		int slot = allSlots[idxSlot]
		
		Actor:WornItem item = akTarget.GetWornItem(slot)
		
		; check if item in the slot is not an actor or the pipboy
		; include unstrippable items in this check
		bool isArmor = IsItemArmor_Internal(item, true)

		; when item is an armor and we can unequip it, do so
		If (isArmor && !found)
			found = true
		EndIf
		
		idxSlot += 1	
	EndWhile

	return found
EndFunction

;
; Checks if @item is an armor piece
; PipBoy, actors and DD items are ignored
;
bool Function IsItemArmor(Actor:WornItem item)
	return IsItemArmor_Internal(item, false)
EndFunction

;
; Checks if @item is an armor piece
; PipBoy, actors and DD items are ignored
;
bool Function IsItemArmor_Internal(Actor:WornItem item, bool includeUnstrippable)
	;return (item.item && LL_Fourplay.StringSubstring(item.modelName, 0, 6) != "Actors" && LL_Fourplay.StringSubstring(item.modelName, 0, 6) != "Pipboy")

	; sanity check
	if (!item.item)
		return false
	endif
	; ignore unstrippable armor when we should not include it
	if (!includeUnstrippable && item.item.HasKeyword(ArmorTypeUnstrippable))
		return false
	endif
	; ignore equipped actors and the pipboy
	If (LL_Fourplay.StringSubstring(item.modelName, 0, 6) == "Actors" || LL_Fourplay.StringSubstring(item.modelName, 0, 6) == "Pipboy")
		return false
	EndIf
	; ignore DD equipment
	If (DD_FL_All != None && DD_FL_All.Find(item.item) > -1)
		return false
	EndIf

	; anything else is armor
	return true
EndFunction


;
; Paralyzes @akTarget
;
Function ParalyzeActor(Actor akTarget)
	akTarget.SetValue(ParalysisAV, 1)
	akTarget.PushActorAway(akTarget, 0.5)	
EndFunction

;
; Unparalyzes @akTarget
;
Function UnParalyzeActor(Actor akTarget)
	akTarget.SetValue(ParalysisAV, 0)
EndFunction
