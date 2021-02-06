; HOW THIS MOD STARTS:
; You have the compiled LenARM:LenARM_Main.psx in your FO4/Data/Scripts folder.
; You have the LenA_RadMorphing.esp enabled in your mod loader.
; The .esp triggers the quest on game load, which in return runs this script file as it were an actual quest.
; With the generic OnQuestInit() and OnQuestShutdown() entry points we do the remaining setup and start the actual logic.
Scriptname LenARM:LenARM_Main extends Quest

;GENERIC TO FIX LIST
;-on restart of the mod, morphsounds can get triggered (?)
;-see if the whole update process can be made faster / more efficient
;  -work with integers instead of floats for easier calculations (might mean making new local variables, aka can be tricky)
;-update companions again (see TODO: companions)
;-check issue with body-covering clothing which also cover the armor slots (ie Hazmat suit), that when on reaching an armor slot unequipment threshold, the unequip logic gets triggered for each additional rad intake beyond that point
;  -the way to do this is first have a normal outfit + armor equipped, reach the armor unequip threshold, and then equip a body-covering outfit
;  -note that for now it seems to be an issue with just the hazmat suit; other body-covering clothes that block armor don't have the issue
;  -sounds like it has issues detecting what slot is covered, and keeps trying to unequip the body-covering clothing while it technically doesn't occupy the slot
;  -might be the Armor Slot Precedence thing described here: https://www.creationkit.com/fallout4/index.php?title=GetWornItem_-_Actor


; ------------------------
; All the local variables the mod uses.
; Do not rename these without a very good reason; you will break the current active ingame scripts and clutter up the savegame with unused variables.
; ------------------------
SliderSet[] SliderSets

; flattened two-dimensional array[idxSliderSet][idxSliderName]
string[] SliderNames

; flattened two-dimensional array[idxSliderSet][idxSlot]
int[] UnequipSlots

; flattened two-dimensional array[idxSliderSet][idxSliderName]
float[] OriginalMorphs

; flattened array[idxCompanion][idxSliderSet][idxSliderName]
float[] OriginalCompanionMorphs

Actor[] CurrentCompanions

int UpdateType
float UpdateDelay
int RadsDetectionType
float RandomRadsLower
float RandomRadsUpper

float LowRadsThreshold
float MediumRadsThreshold
float HighRadsThreshold

float CurrentRads
float FakeRads
bool TakeFakeRads

int RestartStackSize
int UnequipStackSize

int ForgetStateCalledByUserCount
bool IsForgetStateBusy

bool IsShuttingDown

string Version
; ------------------------

; ------------------------
; Register the .esp Quest properties so we can act on them
; ------------------------
Group Properties
	Actor Property PlayerRef Auto Const

	Keyword Property kwMorph Auto Const

	ActorValue Property Rads Auto Const

	; Base Game
	Scene Property DoctorMedicineScene03_AllDone Auto Const
	; Far Harbor
	Scene Property DLC03DialogueFarHarbor_TeddyFinished Auto Const
	Scene Property DialogueNucleusArchemist_GreetScene03_AllDone Auto Const
	Scene Property DLC03AcadiaDialogueAsterPostExamScene Auto Const
	; Nuka World
	Scene Property DLC04SettlementDoctor_EndScene Auto Const

	GenericDoctorsScript Property DialogueGenericDoctors Auto Const

	Sound Property LenARM_DropClothesSound Auto Const
	Sound Property LenARM_MorphSound Auto Const
	Sound Property LenARM_MorphSound_Med Auto Const
	Sound Property LenARM_MorphSound_High Auto Const

	Faction Property CurrentCompanionFaction Auto Const
	Faction Property PlayerAllyFation Auto Const

	Potion Property GlowingOneBlood Auto Const
EndGroup
; ------------------------

; ------------------------
; Register all generic Quest public events / entry points to setup, start and stop the actual mod
; ------------------------
Event OnQuestInit()
	Log("OnQuestInit")
	RegisterForRemoteEvent(PlayerRef, "OnPlayerLoadGame")
	RegisterForExternalEvent("OnMCMSettingChange|LenA_RadMorphing", "OnMCMSettingChange")
	Startup()
EndEvent

Event OnQuestShutdown()
	Log("OnQuestShutdown")
	Shutdown()
EndEvent
; ------------------------

; ------------------------
; On savegame loaded, check for mod updates based on version
; ------------------------
Event Actor.OnPlayerLoadGame(Actor akSender)
	Log("Actor.OnPlayerLoadGame: " + akSender)
	PerformUpdateIfNecessary()
EndEvent

Function OnMCMSettingChange(string modName, string id)
	Log("OnMCMSettingChange: " + modName + "; " + id)
	If (LL_Fourplay.StringSubstring(id, 0, 1) == "s")
		string value = MCM.GetModSettingString(modName, id)
		If (LL_Fourplay.StringSubstring(value, 0, 1) == " ")
			string msg = "The value you have just changed has leading whitespace:\n\n'" + value + "'"
			Debug.MessageBox(msg)
		EndIf
	EndIf
	Restart()
EndFunction
; ------------------------


string Function GetVersion()
	return "0.7.1"; Thu Dec 17 09:11:27 CET 2020
EndFunction














;
; utility functions
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


float Function Clamp(float value, float limit1, float limit2)
	float lower = Math.Min(limit1, limit2)
	float upper = Math.Max(limit1, limit2)
	return Math.Min(Math.Max(value, lower), upper)
EndFunction
;
; END: utility functions






;
; SliderSet functions
;
SliderSet Function SliderSet_Constructor(int idxSet)
	Log("SliderSet_Constructor: " + idxSet)
	SliderSet set = new SliderSet
	set.SliderName = MCM.GetModSettingString("LenA_RadMorphing", "sSliderName:Slider" + idxSet)
	If (set.SliderName != "")
		set.IsUsed = true
		set.TargetMorph = MCM.GetModSettingFloat("LenA_RadMorphing", "fTargetMorph:Slider" + idxSet) / 100.0
		set.ThresholdMin = MCM.GetModSettingFloat("LenA_RadMorphing", "fThresholdMin:Slider" + idxSet) / 100.0
		set.ThresholdMax = MCM.GetModSettingFloat("LenA_RadMorphing", "fThresholdMax:Slider" + idxSet) / 100.0
		set.UnequipSlot = MCM.GetModSettingString("LenA_RadMorphing", "sUnequipSlot:Slider" + idxSet)
		set.ThresholdUnequip = MCM.GetModSettingFloat("LenA_RadMorphing", "fThresholdUnequip:Slider" + idxSet) / 100.0
		set.OnlyDoctorCanReset = MCM.GetModSettingBool("LenA_RadMorphing", "bOnlyDoctorCanReset:Slider" + idxSet)
		set.IsAdditive = MCM.GetModSettingBool("LenA_RadMorphing", "bIsAdditive:Slider" + idxSet)
		set.HasAdditiveLimit = MCM.GetModSettingBool("LenA_RadMorphing", "bHasAdditiveLimit:Slider" + idxSet)
		set.AdditiveLimit = MCM.GetModSettingFloat("LenA_RadMorphing", "fAdditiveLimit:Slider" + idxSet) / 100.0
		set.ApplyCompanion = MCM.GetModSettingInt("LenA_RadMorphing", "iApplyCompanion:Slider" + idxSet)

		string[] names = StringSplit(set.SliderName, "|")
		set.NumberOfSliderNames = names.Length

		If (set.UnequipSlot != "")
			string[] slots = StringSplit(set.UnequipSlot, "|")
			set.NumberOfUnequipSlots = slots.Length
		Else
			set.NumberOfUnequipSlots = 0
		EndIf
	Else
		set.IsUsed = false
	EndIf

	;Log("  " + set)
	return set
EndFunction

int Function SliderSet_GetSliderNameOffset(int idxSet)
	int offset = 0
	int index = 0
	While (index < idxSet)
		offset += SliderSets[index].NumberOfSliderNames
		index += 1
	EndWhile
	return offset
EndFunction

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
; END: SliderSet functions




;
; Debug and testing tools
;
Function ForgetState(bool isCalledByUser=false)
	Log("ForgetState: isCalledByUser=" + isCalledByUser + "; ForgetStateCalledByUserCount=" + ForgetStateCalledByUserCount + "; IsForgetStateBusy=" + IsForgetStateBusy)

	If (isCalledByUser && IsForgetStateBusy)
		Log("  show busy warning")
		Debug.MessageBox("This function is already running. Wait until it has completed.")
	ElseIf (isCalledByUser && ForgetStateCalledByUserCount < 1)
		Log("  show warning")
		CancelTimer(ETimerForgetStateCalledByUserTick)
		Debug.MessageBox("<center><b>! WARNING !</b></center><br><br><p align='justify'>This function does not reset this mod's settings.<br>It will reset the mod's state. This includes the record of the original body shape. If your body or your companion's body is currently morphed by this mod you will be stuck with the current shape.</p><br>Click the button again to reset the mod's state.")
		ForgetStateCalledByUserCount = 1
		StartTimer(0.1, ETimerForgetStateCalledByUserTick)
	Else
		Log("  reset state")
		IsForgetStateBusy = true
		If (isCalledByUser)
			CancelTimer(ETimerForgetStateCalledByUserTick)
			ForgetStateCalledByUserCount = 0
			Log("  show reset start message")
			Debug.MessageBox("Rad Morphing Redux is resetting itself. Another message will let you know once the mod is fully reset.")
		EndIf
		Shutdown(false)
		SliderSets = none
		SliderNames = none
		UnequipSlots = none
		OriginalMorphs = none
		OriginalCompanionMorphs = none
		CurrentCompanions = none
		CurrentRads = 0.0
		FakeRads = 0
		TakeFakeRads = false
		Startup()
		IsForgetStateBusy = false
		TechnicalNote("Mod state has been reset")
		If (isCalledByUser)
			Log("  show reset complete message")
			Debug.MessageBox("Rad Morphing Redux has been reset.")
		EndIf
	EndIf
EndFunction

Function ForgetStateCounterReset()
	Log("ForgetStateCounterReset; ForgetStateCalledByUserCount=" + ForgetStateCalledByUserCount)
	ForgetStateCalledByUserCount = 0
EndFunction

Function GiveIrradiatedBlood()
	PlayerRef.AddItem(GlowingOneBlood, 50)
EndFunction
;
; END: Debug and testing tools













Function PerformUpdateIfNecessary()
	Log("PerformUpdateIfNecessary: " + Version + " != " + GetVersion() + " -> " + (Version != GetVersion()))
	If (Version != GetVersion())
		Log("  update")
		Debug.MessageBox("Updating Rad Morphing Redux from version " + Version + " to " + GetVersion())
		Shutdown()
		While (IsShuttingDown)
			Utility.Wait(1.0)
		EndWhile
		ForgetState()
		Version = GetVersion()
		Debug.MessageBox("Rad Morphing Redux has been updated to version " + Version + ".")
	Else
		Log("  no update")
	EndIf
EndFunction




Function Startup()
	Log("Startup")
	If (MCM.GetModSettingBool("LenA_RadMorphing", "bIsEnabled:General"))
		Log("  is enabled")
		CurrentRads = 0

		LoadSliderSets()

		; get update type from MCM
		UpdateType = MCM.GetModSettingInt("LenA_RadMorphing", "iUpdateType:General")

		; get duration from MCM
		UpdateDelay = MCM.GetModSettingFloat("LenA_RadMorphing", "fUpdateDelay:General")
		
		; get radiation detection type from MCM
		RadsDetectionType = MCM.GetModSettingInt("LenA_RadMorphing", "iRadiationDetection:General")
		RandomRadsLower = MCM.GetModSettingFloat("LenA_RadMorphing", "fRandomRadsLower:General")
		RandomRadsUpper = MCM.GetModSettingFloat("LenA_RadMorphing", "fRandomRadsUpper:General")

		; get radiation threshold (currently used for morph sounds)
		; the division by 1000 is needed as rads run from 0 to 1, while the MCM settings are in displayed rads for player's convenience
		LowRadsThreshold = MCM.GetModSettingFloat("LenA_RadMorphing", "fLowRadsThreshold:General") / 1000.0
		MediumRadsThreshold = MCM.GetModSettingFloat("LenA_RadMorphing", "fMediumRadsThreshold:General") / 1000.0
		HighRadsThreshold = MCM.GetModSettingFloat("LenA_RadMorphing", "fHighRadsThreshold:General") / 1000.0

		; start listening for equipping items
		RegisterForRemoteEvent(PlayerRef, "OnItemEquipped")

		; start listening for doctor scene
		RegisterForRemoteEvent(DoctorMedicineScene03_AllDone, "OnBegin")
		RegisterForRemoteEvent(DoctorMedicineScene03_AllDone, "OnEnd")
		RegisterForRemoteEvent(DLC03DialogueFarHarbor_TeddyFinished, "OnBegin")
		RegisterForRemoteEvent(DLC03DialogueFarHarbor_TeddyFinished, "OnEnd")
		RegisterForRemoteEvent(DialogueNucleusArchemist_GreetScene03_AllDone, "OnBegin")
		RegisterForRemoteEvent(DialogueNucleusArchemist_GreetScene03_AllDone, "OnEnd")
		RegisterForRemoteEvent(DLC03AcadiaDialogueAsterPostExamScene, "OnBegin")
		RegisterForRemoteEvent(DLC03AcadiaDialogueAsterPostExamScene, "OnEnd")
		RegisterForRemoteEvent(DLC04SettlementDoctor_EndScene, "OnBegin")
		RegisterForRemoteEvent(DLC04SettlementDoctor_EndScene, "OnEnd")

		If (RadsDetectionType == ERadsDetectionTypeRandom)
			; start listening for rads damage
			RegisterForRadiationDamageEvent(PlayerRef)
			AddFakeRads()
		EndIf

		; set up companions
		CurrentCompanions = new Actor[0]

		; reset unequip stack
		UnequipStackSize = 0

		; reapply base morphs
		int idxSet = 0
		While (idxSet < SliderSets.Length)
			SliderSet set = SliderSets[idxSet]
			If (set.OnlyDoctorCanReset && set.IsAdditive && set.BaseMorph > 0)
				SetMorphs(idxSet, set, set.BaseMorph)
				;TODO companions
				;SetCompanionMorphs(idxSet, set.BaseMorph, set.ApplyCompanion)
			EndIf
			idxSet += 1
		EndWhile
		;TODO companions
		;ApplyAllCompanionMorphs()
		BodyGen.UpdateMorphs(PlayerRef)

		;TODO nalopen waarom ie hier toch ook de morphsounds kan triggeren
		;komt het omdat ie de TimerMorphTick aanroept?
		;echter geluid wat er vervolgens uit komt lijkt niet te kloppen:
		;had reset getriggered toen ik op volle morphs zat, en speelde geluid van tussen Medium en High rads taken...
		; => vermoedelijk pakt ie je huidige rads, en gebruikt dat als het verschil
		; heb je dus al veel rads, dan triggered ie het geluid wat erbij hoort

		If (UpdateType == EUpdateTypeImmediately)
			; start timer
			TimerMorphTick()
		ElseIf (UpdateType == EUpdateTypeOnSleep)
			; listen for sleep events
			RegisterForPlayerSleep()
		EndIf
	ElseIf (MCM.GetModSettingBool("LenA_RadMorphing", "bWarnDisabled:General"))
		Log("  is disabled, with warning")
		Debug.MessageBox("Rad Morphing is currently disabled. You can enable it in MCM > Rad Morphing > Enable Rad Morphing")
	Else
		Log("  is disabled, no warning")
	EndIf
EndFunction

; ------------------------
; Read the slider sets from the MCM config, and store them into the local variables.
; Will perform the initial local variables setup if these are not yet initialized.
; Will cleanup no longer existing slider sets if these existed in the local variables but are no longer in the MCM config.
; ------------------------
Function LoadSliderSets()
	Log("LoadSliderSets")
	; create arrays if not exist
	If (!SliderSets)
		SliderSets = new SliderSet[_NUMBER_OF_SLIDERSETS_]
	EndIf
	If (!SliderNames)
		SliderNames = new string[0]
	EndIf
	If (!UnequipSlots)
		UnequipSlots = new int[0]
	EndIf
	If (!OriginalMorphs)
		OriginalMorphs = new float[0]
		OriginalCompanionMorphs = new float[0]
	EndIf
	
	; get slider sets
	int idxSet = 0
	While (idxSet < _NUMBER_OF_SLIDERSETS_)
		SliderSet oldSet = SliderSets[idxSet]
		SliderSet newSet = SliderSet_Constructor(idxSet)
		SliderSets[idxSet] = newSet

		; when we found an existing sliderSet, reuse the BaseMorph and CurrentMorph
		If (oldSet)
			newSet.BaseMorph = oldSet.BaseMorph
			newSet.CurrentMorph = oldSet.CurrentMorph
		EndIf
		
		; populate flattened arrays
		int sliderNameOffset = SliderSet_GetSliderNameOffset(idxSet)
		If (newSet.IsUsed)
			string[] names = StringSplit(newSet.SliderName, "|")
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
			string[] slots = StringSplit(newSet.UnequipSlot, "|")
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
	;Log("  SliderSets: " + SliderSets)
	;Log("  SliderNames: " + SliderNames)
	;Log("  OriginalMorphs: " + OriginalMorphs)
	;Log("  UnequipSlots: " + UnequipSlots)

	;RetrieveAllOriginalCompanionMorphs()
EndFunction
; ------------------------


Function Shutdown(bool withRestore=true)
	If (!IsShuttingDown)
		Log("Shutdown")
		IsShuttingDown = true

		; stop listening for sleep events
		UnregisterForPlayerSleep()
	
		; stop timer
		CancelTimer(ETimerMorphTick)
	
		; stop listening for equipping items
		UnregisterForRemoteEvent(PlayerRef, "OnItemEquipped")
	
		; stop listening for doctor scene
		UnregisterForRemoteEvent(DoctorMedicineScene03_AllDone, "OnBegin")
		UnregisterForRemoteEvent(DoctorMedicineScene03_AllDone, "OnEnd")
		
		If (withRestore)
			StartTimer(Math.Max(UpdateDelay + 0.5, 2.0), ETimerShutdownRestoreMorphs)
		Else
			FinishShutdown()
		EndIf
	EndIf
EndFunction

Function ShutdownRestoreMorphs()
	Log("ShutdownRestoreMorphs")
	; restore base values
	RestoreOriginalMorphs()
	FinishShutdown()
EndFunction

Function FinishShutdown()
	Log("FinishShutdown")
	IsShuttingDown = false
EndFunction


Function Restart()
	RestartStackSize += 1
	Utility.Wait(1.0)
	If (RestartStackSize <= 1)
		Log("Restart")
		Shutdown()
		While (IsShuttingDown)
			Utility.Wait(1.0)
		EndWhile
		Startup()
		Log("Restart completed")
	Else
		Log("RestartStackSize: " + RestartStackSize)
	EndIf
	RestartStackSize -= 1
EndFunction




Event OnTimer(int tid)
	If (tid == ETimerMorphTick)
		TimerMorphTick()
	ElseIf (tid == ETimerForgetStateCalledByUserTick)
		ForgetStateCounterReset()
	ElseIf (tid == ETimerShutdownRestoreMorphs)
		ShutdownRestoreMorphs()
	ElseIf (tid == ETimerUnequipSlots)
		UnequipSlots()
	ElseIf (tid == ETimerFakeRads)
		AddFakeRads()
	EndIf
EndEvent




Event OnPlayerSleepStart(float afSleepStartTime, float afDesiredSleepEndTime, ObjectReference akBed)
	Log("OnPlayerSleepStart: afSleepStartTime=" + afSleepStartTime + ";  afDesiredSleepEndTime=" + afDesiredSleepEndTime + ";  akBed=" + akBed)
	Actor[] allCompanions = Game.GetPlayerFollowers() as Actor[]
	Log("  followers on sleep start: " + allCompanions)
	; update companions (companions cannot be found on sleep stop)
	UpdateCompanions()
EndEvent

Event OnPlayerSleepStop(bool abInterrupted, ObjectReference akBed)
	Log("OnPlayerSleepStop: abInterrupted=" + abInterrupted + ";  akBed=" + akBed)
	Actor[] allCompanions = Game.GetPlayerFollowers() as Actor[]
	Log("  followers on sleep stop: " + allCompanions)
	; get rads
	CurrentRads = GetNewRads()
	If (CurrentRads > 0.0)
		Log("  rads: " + CurrentRads)
		int idxSet = 0
		While (idxSet < SliderSets.Length)
			SliderSet sliderSet = SliderSets[idxSet]
			If (sliderSet.IsUsed)
				Log("  SliderSet " + idxSet)
				; calculate morph from CurrentRads
				float newMorph = GetNewMorph(CurrentRads, sliderSet)
				Log("    morph " + idxSet + ": " + sliderSet.CurrentMorph + " + " + newMorph)
				; add morph to existing morph
				float fullMorph = Math.Min(1.0, sliderSet.CurrentMorph + newMorph)
				; apply morph
				SetMorphs(idxSet, sliderSet, fullMorph)
				sliderSet.CurrentMorph = fullMorph
			EndIf
			idxSet += 1
		EndWhile
		BodyGen.UpdateMorphs(PlayerRef)
		ApplyAllCompanionMorphs()
		TriggerUnequipSlots()
	EndIf
EndEvent




Event Actor.OnItemEquipped(Actor akSender, Form akBaseObject, ObjectReference akReference)
	;TODO get slot number
	;TODO check if slot is allowed
	;TODO if slot is not allowed -> unequip
	;lijkt erop dat GetSlotMask niet overeen komt met de slots die we gebruiken voor unequippen
	;kan over GetSlotMask ook niet echt iets vinden op de CK docs...

	; only check if we need to unequip anything when we equip clothing or armor
	; this will break the hacky "unequip weapon slots" logic some people use tho...
	if (akBaseObject as Armor)
		Log("Actor.OnItemEquipped: " + akBaseObject.GetName() + " (" + akBaseObject.GetSlotMask() + ")")
		Utility.Wait(1.0)
		;TODO dit klapt nu keihard, gooit dikke error genaamd "Unbound scripts cannot start timers"
		;loop na of het nu nog steeds voorkomt nu we gefilterd hebben naar alleen Armor
		TriggerUnequipSlots()
	endif

EndEvent


Event Scene.OnBegin(Scene akSender)
	float radsBeforeDoc = PlayerRef.GetValue(Rads)
	Log("Scene.OnBegin: " + akSender + " (rads: " + radsBeforeDoc + ")")
EndEvent

Event Scene.OnEnd(Scene akSender)
	float radsNow = PlayerRef.GetValue(Rads)
	Log("Scene.OnEnd: " + akSender + " (rads: " + radsNow + ")")
	If (DialogueGenericDoctors.DoctorJustCuredRads == 1)
		ResetMorphs()
		FakeRads = 0
		TakeFakeRads = false
	EndIf
EndEvent

Event OnRadiationDamage(ObjectReference akTarget, bool abIngested)
	Log("OnRadiationDamage: akTarget=" + akTarget + ";  abIngested=" + abIngested)
	TakeFakeRads = true
EndEvent




float Function GetNewRads()
	float newRads = 0.0
	If (RadsDetectionType == ERadsDetectionTypeRads)
		newRads = PlayerRef.GetValue(Rads)
	ElseIf (RadsDetectionType == ERadsDetectionTypeRandom)
		newRads = FakeRads
	EndIf
	return newRads / 1000
EndFunction




Function AddFakeRads()
	Log("AddFakeRads")
	If (TakeFakeRads)
		; add fake rads
		FakeRads += Utility.RandomFloat(RandomRadsLower, RandomRadsUpper)
		Log("  FakeRads: " + FakeRads)
		TakeFakeRads = false
	EndIf
	; restart timer
	StartTimer(1.0, ETimerFakeRads)
	; re-register event listener
	RegisterForRadiationDamageEvent(PlayerRef)
EndFunction




; ------------------------
; Timer-based morphs
; ------------------------
Function TimerMorphTick()
	; get the player's current Rads
	; note that the rads run from 0 to 1, with 1 equaling 1000 displayed rads
	float newRads = GetNewRads()
	If (newRads != CurrentRads)
		;Log("new rads: " + newRads + " (" + CurrentRads + ")")
		If (!PlayerRef.IsInPowerArmor())
			; calculate the amount of rads taken
			; the longer the timer interval, the larger this will be
			float radsDifference = newRads - CurrentRads;
			Log("rads taken: " + radsDifference);
						
			CurrentRads = newRads
			;TODO companions
			; companions
			;UpdateCompanions()

			; apply morphs
			bool changedMorphs = false
			int idxSet = 0
			While (idxSet < SliderSets.Length)
				SliderSet sliderSet = SliderSets[idxSet]
				If (sliderSet.NumberOfSliderNames > 0)
					;Log("  SliderSet " + idxSet)
					float newMorph = GetNewMorph(newRads, sliderSet)

					;Log("    morph " + idxSet + ": " + sliderSet.CurrentMorph + " -> " + newMorph)

					; only try to apply the morphs if either
					; -the new morph is larger then the slider's current morph
					; -the new morph is unequal to the slider's current morph when slider reset isn't doctor-only
					If (newMorph > sliderSet.CurrentMorph || (!sliderSet.OnlyDoctorCanReset && newMorph != sliderSet.CurrentMorph))
						; by default the morph we will apply is the calculated morph, and the max morph is 1.0
						; both will get modified if we have additive morphs enabled for this sliderSet
						float fullMorph = newMorph
						float maxMorphs = 1.0

						; when we have additive morphs active for this slider, add the BaseMorph to the calculated morph
						; limit this to the lower of calculated morph and the additive morph limit when we use additive morph limit
						If (sliderSet.IsAdditive)
							fullMorph += sliderSet.BaseMorph
							If (sliderSet.HasAdditiveLimit)
								maxMorphs = 1.0 + sliderSet.AdditiveLimit
								fullMorph = Math.Min(fullMorph, maxMorphs)
							EndIf
						EndIf
						
						; only actually apply the morphs if they are less then our max allowed morphs, or when we have no additive morphs limit
						if (fullMorph < maxMorphs || (sliderSet.IsAdditive && !sliderSet.HasAdditiveLimit))
							;Log("    morph " + idxSet + ": " + sliderSet.CurrentMorph + " -> " + newMorph + " -> " + fullMorph)						
							SetMorphs(idxSet, sliderSet, fullMorph)
							changedMorphs = true
						endif

						; we always want to update the sliderSet's CurrentMorph, no matter if we actually updated the sliderSet's morphs or not
						; eventually we have taken enough total rads we won't enter the containing if-statement						
						sliderSet.CurrentMorph = newMorph
						;Log("    setting currentMorph " + idxSet + " to " + sliderSet.CurrentMorph)

					; when we have negative morphs and additive sliders, store our current morphs as the new BaseMorph
					; this way when we take further rads, we start of at the previous morphs instead of starting from scratch again
					ElseIf (sliderSet.IsAdditive)
						sliderSet.BaseMorph += sliderSet.CurrentMorph - newMorph
						;Log("    setting baseMorph " + idxSet + " to " + sliderSet.BaseMorph)
						sliderSet.CurrentMorph = newMorph
						;Log("    setting currentMorph " + idxSet + " to " + sliderSet.CurrentMorph)
					EndIf
				EndIf
				idxSet += 1
			EndWhile
			If (changedMorphs)
				BodyGen.UpdateMorphs(PlayerRef)
				PlayMorphSound(PlayerRef, radsDifference)
				;TODO companions
				;ApplyAllCompanionMorphs()
				TriggerUnequipSlots()
			Else
				;TODO trigger only once until rads have decreased or doctor reset
				;TODO now also triggers on rad decreases
				Note("I won't get any bigger")
			EndIf
		Else
			;Log("skipping due to player in power armor")
		EndIf
	EndIf
	StartTimer(UpdateDelay, ETimerMorphTick)
EndFunction













; ------------------------
; Calculate the new morph for the given sliderSet based on the given rads and the slider's min / max thresholds
; ------------------------
float Function GetNewMorph(float newRads, SliderSet sliderSet)
	float newMorph
	If (newRads < sliderSet.ThresholdMin)
		newMorph = 0.0
	ElseIf (newRads > sliderSet.ThresholdMax)
		newMorph = 1.0
	Else
		newMorph = (newRads - sliderSet.ThresholdMin) / (sliderSet.ThresholdMax - sliderSet.ThresholdMin)
	EndIf
	return newMorph
EndFunction
; ------------------------

; ------------------------
; Apply the given sliderSet's morphs to the matching BodyGen sliders
; ------------------------
Function SetMorphs(int idxSet, SliderSet sliderSet, float fullMorph)
	int sliderNameOffset = SliderSet_GetSliderNameOffset(idxSet)
	int idxSlider = sliderNameOffset
	int sex = PlayerRef.GetLeveledActorBase().GetSex()
	While (idxSlider < sliderNameOffset + sliderSet.NumberOfSliderNames)
		BodyGen.SetMorph(PlayerRef, sex==ESexFemale, SliderNames[idxSlider], kwMorph, OriginalMorphs[idxSlider] + fullMorph * sliderSet.TargetMorph)
		Log("    setting slider '" + SliderNames[idxSlider] + "' to " + (OriginalMorphs[idxSlider] + fullMorph * sliderSet.TargetMorph) + " (base value is " + OriginalMorphs[idxSlider] + ") (base morph is " + sliderSet.BaseMorph + ") (target is " + sliderSet.TargetMorph + ")")
		;TODO companions
		;If (sliderSet.ApplyCompanion != EApplyCompanionNone)
		;	SetCompanionMorphs(idxSlider, fullMorph * sliderSet.TargetMorph, sliderSet.ApplyCompanion)
		;EndIf
		idxSlider += 1
	EndWhile
EndFunction
; ------------------------




; ------------------------
; Restore the original BodyGen values for each slider, and set all morphs to 0
; ------------------------
Function ResetMorphs()
	Log("ResetMorphs")
	RestoreOriginalMorphs()
	; reset saved morphs in SliderSets
	int idxSet = 0
	While (idxSet < SliderSets.Length)
		SliderSet set = SliderSets[idxSet]
		set.BaseMorph = 0.0
		set.CurrentMorph = 0.0
		idxSet += 1
	EndWhile
EndFunction

Function RestoreOriginalMorphs()
	Log("RestoreOriginalMorphs")
	; restore base values
	int i = 0
	int sex = PlayerRef.GetLeveledActorBase().GetSex()
	While (i < SliderNames.Length)
		BodyGen.SetMorph(PlayerRef, sex==ESexFemale, SliderNames[i], kwMorph, OriginalMorphs[i])
		i += 1
	EndWhile
	BodyGen.UpdateMorphs(PlayerRef)

	;RestoreAllOriginalCompanionMorphs()
EndFunction
; ------------------------




Function RestoreAllOriginalCompanionMorphs()
	Log("RestoreAllOriginalCompanionMorphs")
	int idxComp = 0
	While (idxComp < CurrentCompanions.Length)
		Actor companion = CurrentCompanions[idxComp]
		RestoreOriginalCompanionMorphs(companion, idxComp)
		idxComp += 1
	EndWhile
EndFunction

Function RestoreOriginalCompanionMorphs(Actor companion, int idxCompanion)
	Log("RestoreOriginalCompanionMorphs: " + companion + "; " + idxCompanion)
	int offsetIdx = SliderNames.Length * idxCompanion
	int idxSlider = 0
	int sex = companion.GetLeveledActorBase().GetSex()
	While (idxSlider < SliderNames.Length)
		BodyGen.SetMorph(companion, sex==ESexFemale, SliderNames[idxSlider], kwMorph, OriginalCompanionMorphs[offsetIdx + idxSlider])
		idxSlider += 1
	EndWhile
	BodyGen.UpdateMorphs(companion)
EndFunction


Function RetrieveAllOriginalCompanionMorphs()
	Log("RetrieveAllOriginalCompanionMorphs")
	OriginalCompanionMorphs = new float[0]
	int idxComp = 0
	While (idxComp < CurrentCompanions.Length)
		Actor companion = CurrentCompanions[idxComp]
		RetrieveOriginalCompanionMorphs(companion)
		idxComp += 1
	EndWhile
EndFunction

Function RetrieveOriginalCompanionMorphs(Actor companion)
	Log("RetrieveOriginalCompanionMorphs: " + companion)
	int idxSlider = 0
	While (idxSlider < SliderNames.Length)
		OriginalCompanionMorphs.Add(BodyGen.GetMorph(companion, True, SliderNames[idxSlider], None))
		idxSlider += 1
	EndWhile
EndFunction


Function SetCompanionMorphs(int idxSlider, float morph, int applyCompanion)
	Log("SetCompanionMorphs: " + idxSlider + "; " + morph + "; " + applyCompanion)
	int idxComp = 0
	While (idxComp < CurrentCompanions.Length)
		Actor companion = CurrentCompanions[idxComp]
		int sex = companion.GetLeveledActorBase().GetSex()
		If (!companion.IsInPowerArmor())
			If (applyCompanion == EApplyCompanionAll || (sex == ESexFemale && applyCompanion == EApplyCompanionFemale) || (sex == ESexMale && applyCompanion == EApplyCompanionMale))
				int offsetIdx = SliderNames.Length * idxComp
				Log("    setting companion(" + companion + ") slider '" + SliderNames[idxSlider] + "' to " + (OriginalCompanionMorphs[offsetIdx + idxSlider] + morph) + " (base value is " + OriginalCompanionMorphs[offsetIdx + idxSlider] + ")")
				BodyGen.SetMorph(companion, sex==ESexFemale, SliderNames[idxSlider], kwMorph, OriginalCompanionMorphs[offsetIdx + idxSlider] + morph)
			Else
				Log("    skipping companion slider:  sex=" + sex)
			EndIf
		Else
			Log("    skipping companion(" + companion + ") due to being in power armor")
		EndIf
		idxComp += 1
	EndWhile
EndFunction

Function ApplyAllCompanionMorphs()
	Log("ApplyAllCompanionMorphs")
	int idxComp = 0
	While (idxComp < CurrentCompanions.Length)
		BodyGen.UpdateMorphs(CurrentCompanions[idxComp])
		;TODO companions
		PlayMorphSound(CurrentCompanions[idxComp], 0);TODO die 0 is temp
		idxComp += 1
	EndWhile
EndFunction




Function RemoveDismissedCompanions(Actor[] newCompanions)
	Log("RemoveDismissedCompanions: " + newCompanions)
	int idxOld = CurrentCompanions.Length - 1
	While (idxOld >= 0)
		Actor oldComp = CurrentCompanions[idxOld]
		If (newCompanions.Find(oldComp) == -1)
			Log("  removing companion " + oldComp)
			CurrentCompanions.Remove(idxOld)
			RestoreOriginalCompanionMorphs(oldComp, idxOld)
		EndIf
		idxOld -= 1
	EndWhile
EndFunction

Function AddNewCompanions(Actor[] newCompanions)
	Log("AddNewCompanions: " + newCompanions)
	int idxNew = 0
	While (idxNew < newCompanions.Length)
		Actor newComp = newCompanions[idxNew]
		Log("  looking for " + newComp + " -> " + CurrentCompanions.Find(newComp))
		If (CurrentCompanions.Find(newComp) == -1)
			Log("  adding companion " + newComp)
			CurrentCompanions.Add(newComp)
			RegisterForRemoteEvent(newComp, "OnCompanionDismiss")
			RetrieveOriginalCompanionMorphs(newComp)
		EndIf
		idxNew += 1
	EndWhile
EndFunction

Event Actor.OnCompanionDismiss(Actor akSender)
	Log("Actor.OnCompanionDismiss: " + akSender)
	int idxComp = CurrentCompanions.Find(akSender)
	If (idxComp > -1)
		CurrentCompanions.Remove(idxComp)
		RestoreOriginalCompanionMorphs(akSender, idxComp)
	EndIf
EndEvent

Actor[] Function GetCompanions()
	Log("GetCompanions")
	Actor[] allCompanions = Game.GetPlayerFollowers() as Actor[]
	Log("  allCompanions: " + allCompanions)
	Actor[] filteredCompanions = new Actor[0]
	int idxFilterCompanions = 0
	While (idxFilterCompanions < allCompanions.Length)
		Actor companion = allCompanions[idxFilterCompanions]
		If (companion.IsInFaction(CurrentCompanionFaction) || companion.IsInFaction(PlayerAllyFation))
			filteredCompanions.Add(companion)
		EndIf
		idxFilterCompanions += 1
	EndWhile
	return filteredCompanions
EndFunction

Function UpdateCompanions()
	Log("UpdateCompanions")
	Actor[] newComps = GetCompanions()
	RemoveDismissedCompanions(newComps)
	AddNewCompanions(newComps)
	Log("  CurrentCompanions: " + CurrentCompanions)
EndFunction





Function UnequipSlots()
	Log("UnequipSlots (stack=" + UnequipStackSize + ")")
	UnequipStackSize += 1
	If (UnequipStackSize <= 1)
		bool found = false
		bool[] compFound = new bool[CurrentCompanions.Length]
		int idxSet = 0
		; check for each sliderSet
		While (idxSet < SliderSets.Length)
			SliderSet sliderSet = SliderSets[idxSet]
			; continue when the morphs are larger then the unequip threshold
			If (sliderSet.BaseMorph + sliderSet.CurrentMorph > sliderSet.ThresholdUnequip)
				int unequipSlotOffset = SliderSet_GetUnequipSlotOffset(idxSet)
				int idxSlot = unequipSlotOffset
				; check each slot that should get unequipped
				While (idxSlot < unequipSlotOffset + sliderSet.NumberOfUnequipSlots)
					Actor:WornItem item = PlayerRef.GetWornItem(UnequipSlots[idxSlot])
					; when there is an item in the slot, and said item is not an actor or the pipboy, unequip it
					If (item.item && LL_Fourplay.StringSubstring(item.modelName, 0, 6) != "Actors" && LL_Fourplay.StringSubstring(item.modelName, 0, 6) != "Pipboy")
						Log("  unequipping slot " + UnequipSlots[idxSlot] + " (" + item.item.GetName() + " / " + item.modelName + ")")
						PlayerRef.UnequipItemSlot(UnequipSlots[idxSlot])
						; when the item is no longer equipped and we haven't already unequipped anything (goes across all sliders and slots),
						; play the strip sound if available and display a notification in top-left
						If (!found && !PlayerRef.IsEquipped(item.item))
							;Log("  playing sound")
							LenARM_DropClothesSound.PlayAndWait(PlayerRef)
							Note("It is too tight for me")
							found = true
						EndIf
					EndIf
					;TODO companions
					;/int idxComp = 0
					While (idxComp < CurrentCompanions.Length)
						Actor companion = CurrentCompanions[idxComp]
						int sex = companion.GetLeveledActorBase().GetSex()
						If (sliderSet.ApplyCompanion == EApplyCompanionAll || (sex == ESexFemale && sliderSet.ApplyCompanion == EApplyCompanionFemale) || (sex == ESexMale && sliderSet.ApplyCompanion == EApplyCompanionMale))
							Actor:WornItem compItem = companion.GetWornItem(UnequipSlots[idxSlot])
							If (compItem.item && LL_Fourplay.StringSubstring(compItem.modelName, 0, 6) != "Actors" && LL_Fourplay.StringSubstring(compItem.modelName, 0, 6) != "Pipboy")
								Log("  unequipping companion(" + companion + ") slot " + UnequipSlots[idxSlot] + " (" + compItem.item.GetName() + " / " + compItem.modelName + ")")
								companion.UnequipItem(compItem.item)
								If (!compFound[idxComp] && !companion.IsEquipped(compItem.item))
									Log("  playing companion sound")
									LenARM_DropClothesSound.PlayAndWait(CurrentCompanions[idxComp])
									compFound[idxComp] = true
								EndIf
							EndIf
						EndIf
						idxComp += 1
					EndWhile/;
					idxSlot += 1
				EndWhile
			EndIf
			idxSet += 1
		EndWhile
	EndIf
	UnequipStackSize -= 1
	Log("FINISHED UnequipSlots")
EndFunction

Function TriggerUnequipSlots()
	Log("TriggerUnequipSlots")
	StartTimer(0.1, ETimerUnequipSlots)
EndFunction




Function ShowEquippedClothes()
	TechnicalNote("ShowEquippedClothes")
	string[] items = new string[0]
	int slot = 0
	While (slot < 62)
		Actor:WornItem item = PlayerRef.GetWornItem(slot)
		If (item != None && item.item != None)
			items.Add(slot + ": " + item.item.GetName())
			Log("  " + slot + ": " + item.item.GetName() + " (" + item.modelName + ")")
		Else
			Log("  Slot " + slot + " is empty")
		EndIf
		slot += 1
	EndWhile

	Debug.MessageBox(LL_FourPlay.StringJoin(items, "\n"))
EndFunction

Function PlayMorphSound(Actor akSender, float radsDifference)
	; everything below LowRadsThreshold rads taken, including rad decreases (ie RadAway)
	if (radsDifference <= LowRadsThreshold)
		Log("  minimum rads taken")
	; everything between LowRadsThreshold and MediumRadsThreshold rads taken
	elseif (radsDifference <= MediumRadsThreshold)
		Log("  medium rads taken")
		LenARM_MorphSound.PlayAndWait(akSender)
	; everything between MediumRadsThreshold and HighRadsThreshold rads taken
	elseif (radsDifference <= HighRadsThreshold)
		Log("  high rads taken")
		LenARM_MorphSound_Med.PlayAndWait(akSender)
	; everything above HighRadsThreshold rads taken
	elseif (radsDifference > HighRadsThreshold)
		Log("  very high rads taken")
		LenARM_MorphSound_High.PlayAndWait(akSender)
	endif
EndFunction



; ------------------------
; Debug helpers for writing to Papyrus logs and displaying info messages ingame (top-left)
; ------------------------
Function Note(string msg)
	;TODO je zou dat als zo'n Vaultboy ding linksbovenin moeten kunnen doen; Player Comments doet dat wel bijvoorbeeld
	Debug.Notification(msg)
	Log(msg)
EndFunction
; same as Note only the message gets prefixed with [LenARM]
Function TechnicalNote(string msg)
	Debug.Notification("[LenARM] " + msg)
	Log(msg)
EndFunction
Function Log(string msg)
	Debug.Trace("[LenARM] " + msg)
EndFunction
; ------------------------



; ------------------------
; MCM selector enums
; ------------------------
Group EnumTimerId
	int Property ETimerMorphTick = 1 Auto Const
	int Property ETimerForgetStateCalledByUserTick = 2 Auto Const
	int Property ETimerShutdownRestoreMorphs = 3 Auto Const
	int Property ETimerUnequipSlots = 4 Auto Const
	int Property ETimerFakeRads = 5 Auto Const
EndGroup

Group EnumApplyCompanion
	int Property EApplyCompanionNone = 0 Auto Const
	int Property EApplyCompanionFemale = 1 Auto Const
	int Property EApplyCompanionMale = 2 Auto Const
	int Property EApplyCompanionAll = 3 Auto Const
EndGroup

Group EnumUpdateType
	int Property EUpdateTypeImmediately = 0 Auto Const
	int Property EUpdateTypeOnSleep = 1 Auto Const
EndGroup

Group EnumRadsDetectionType
	int Property ERadsDetectionTypeRads = 0 Auto Const
	int Property ERadsDetectionTypeRandom = 1 Auto Const
EndGroup

Group EnumSex
	int Property ESexMale = 0 Auto Const
	int Property ESexFemale = 1 Auto Const
EndGroup

Group Constants
	int Property _NUMBER_OF_SLIDERSETS_ = 20 Auto Const
EndGroup
; ------------------------

; ------------------------
; MCM Slider class / struct
; ------------------------
Struct SliderSet
	bool IsUsed

	; MCM values
	string SliderName
	float TargetMorph
	float ThresholdMin
	float ThresholdMax
	string UnequipSlot
	float ThresholdUnequip
	bool OnlyDoctorCanReset
	bool IsAdditive
	bool HasAdditiveLimit
	float AdditiveLimit
	int ApplyCompanion
	; END: MCM values

	int NumberOfSliderNames
	int NumberOfUnequipSlots

	float BaseMorph
	float CurrentMorph
EndStruct
; ------------------------
