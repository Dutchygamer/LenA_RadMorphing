; HOW THIS MOD STARTS:
; You have the compiled LenARM:LenARM_Main.psx in your FO4/Data/Scripts folder.
; You have the LenA_RadMorphing.esp enabled in your mod loader.
; The .esp triggers the quest on game load, which in return runs this script file as it were an actual quest.
; With the generic OnQuestInit() and OnQuestShutdown() entry points we do the remaining setup and start the actual logic.

; Note that while the mod supports morphing companions, the Timer-based performance will drop the more companions and sliders you have.
; With one companion this is already slightly noticable, but with two or more you will see multiple-second delays between morphs.
Scriptname LenARM:LenARM_Main extends Quest

;GENERIC TO FIX LIST
;-see if the whole update process can be made faster / more efficient
;  -work with integers instead of floats for easier calculations (might mean making new local variables, aka can be tricky)
;-update companions again (see TODO: companions)
;-TimedBasedMorphs now looks for the actual received radiation for basicly everything. This is most likely the reason why the FakeRads logic is buggy
;  -things like MorphSounds still seem to look at the actual received rads instead of the FakeRads when you use FakeRads
;  -might also explain why god-mode together with FakeRads doesn't seem to apply any morphs anymore

;TODO Ada gets seen as a female companion. Doesn't do morphs, but does play sounds

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

bool HasDoctorOnlySliders
float TotalRads

; has the player reached the max on all sliderSets? this includes additive morphing if these are limited
bool HasReachedMaxMorphs

bool EnablePopping
int PopStates
bool PopShouldParalyze
; how many pop warnings have we displayed
int PopWarnings
bool IsPopping

int MaxRadiationMultiplier

bool EnableRadsPerks
int CurrentRadsPerk

bool SlidersEffectFemaleCompanions
bool SlidersEffectMaleCompanions

int RestartStackSize
int UnequipStackSize

int ForgetStateCalledByUserCount
bool IsForgetStateBusy

bool IsShuttingDown
bool IsStartingUp

string Version

; ------------------------
; Register the .esp Quest properties so we can act on them
; ------------------------
Group Properties
	Actor Property PlayerRef Auto Const

	Keyword Property kwMorph Auto Const

	ActorValue Property Rads Auto Const

	; Base Game
	Scene Property DoctorMedicineScene03_AllDone Auto Const
	GenericDoctorsScript Property DialogueGenericDoctors Auto Const
	; Far Harbor
	Scene Property DLC03DialogueFarHarbor_TeddyFinished Auto Const
	Scene Property DialogueNucleusArchemist_GreetScene03_AllDone Auto Const
	Scene Property DLC03AcadiaDialogueAsterPostExamScene Auto Const
	GenericDoctorsScript Property DLC03CoA_DialogueNucleusArchemist Auto Const
	GenericDoctorsScript Property DLC03DialogueFarHarbor Auto Const
	GenericDoctorsScript Property DLC03AcadiaDialogue Auto Const
	; Nuka World
	Scene Property DLC04SettlementDoctor_EndScene Auto Const
	GenericDoctorsScript Property DLC04SettlementDoctor Auto Const

	Sound Property LenARM_DropClothesSound Auto Const
	Sound Property LenARM_MorphSound Auto Const
	Sound Property LenARM_MorphSound_Med Auto Const
	Sound Property LenARM_MorphSound_High Auto Const
	Sound Property LenARM_FullSound Auto Const
	Sound Property LenARM_SwellSound Auto Const
	Sound Property LenARM_PrePopSound Auto Const
	Sound Property LenARM_PopSound Auto Const

	Faction Property CurrentCompanionFaction Auto Const
	Faction Property PlayerAllyFation Auto Const

	Potion Property GlowingOneBlood Auto Const

	Perk[] Property RadsPerkArray Auto

	ActorValue Property ParalysisAV Auto Const
	ActorValue Property LuckAV Auto Const
	Potion Property PoppedPotion Auto Const	
	Potion Property ResetMorphsExperimentalPotion Auto Const	
	Potion Property ResetMorphsPotion Auto Const
	Potion Property ResetRadsPotion Auto Const	
EndGroup

; ------------------------
; Register all generic Quest public events / entry points related to setup, start and stop the actual mod
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
; On savegame loaded, check for mod updates based on version
; ------------------------
Event Actor.OnPlayerLoadGame(Actor akSender)
	Log("Actor.OnPlayerLoadGame: " + akSender)
	PerformUpdateIfNecessary()
EndEvent

Function PerformUpdateIfNecessary()
	Log("PerformUpdateIfNecessary: " + Version + " != " + GetVersion() + " -> " + (Version != GetVersion()))
	If (Version != GetVersion())
		Log("  update")
		MessageBox("Updating Rad Morphing Redux from version " + Version + " to " + GetVersion())
		Shutdown()
		While (IsShuttingDown)
			Utility.Wait(1.0)
		EndWhile
		ForgetState()
		Version = GetVersion()
		MessageBox("Rad Morphing Redux has been updated to version " + Version + ".")
	Else
		Log("  no update")
	EndIf
EndFunction

string Function GetVersion()
	return "0.7.1"; Thu Dec 17 09:11:27 CET 2020
EndFunction

; ------------------------
; On equipping / ingestion of an item, check if we must do something with it
; ------------------------
Event Actor.OnItemEquipped(Actor akSender, Form akBaseObject, ObjectReference akReference)
	If (PlayerRef.IsInPowerArmor())
		return
	EndIf

	; only check if we need to unequip anything when we equip clothing or armor and are not in power armor
	; this will break the hacky "unequip weapon slots" logic some people use tho...
	If (akBaseObject as Armor)
		Log("Actor.OnItemEquipped: " + akBaseObject.GetName() + " (" + akBaseObject.GetSlotMask() + ")")
		Utility.Wait(1.0)
		TriggerUnequipSlots()
	endif

	;TODO kijken of we dit niet via aparte scripts die specifiek voor de potions zijn kunnen laten lopen
	;moet je wel uitzoeken of / hoe je scripts vanuit een andere script aan kan roepen...
	; if we ingest potions, check if it is one of the mod-specific drugs
	If (akBaseObject as Potion)	

		;TODO eigenlijk moeten beide van te voren kijken of je niet in Power Armor it
		; nu doet ie alleen de check indien je gaat poppen, maar gaat anders wel de morphs resetten
		; vermoed dat dat issues oplevert

		; ingested reset morphs potion => reset the morphs
		if (akBaseObject.GetFormID() == ResetMorphsPotion.GetFormID())
			Note("My body goes back to normal")
			ResetMorphs()
		; ingested experimental reset morphs potion => chance to reset the morphs, else pop
		elseIf (akBaseObject.GetFormID() == ResetMorphsExperimentalPotion.GetFormID())
			; base 50% chance to trigger
			bool shouldPop = ShouldPop(5)
		
			if (shouldPop)
				; perform the actual popping if enabled in config and not currently in Power Armor
				if (EnablePopping && !PlayerRef.IsInPowerArmor())
					Note("This doesn't feel good")
					LenARM_MorphSound.Play(PlayerRef)
					Utility.Wait(1.0)
					Pop()
				; else only apply the popped debuffs on the player
				else
					Note("It worked, but I feel weak")
					PlayerRef.EquipItem(PoppedPotion, abSilent = true)
				endif
			Else
				Note("My body goes back to normal")
				ResetMorphs()					
			endIf
		endif
	endif
EndEvent

; ------------------------
; Upon entering and exiting the doctor scenes, reset the morphs
; ------------------------
Event Scene.OnBegin(Scene akSender)
	float radsBeforeDoc = PlayerRef.GetValue(Rads)
	Log("Scene.OnBegin: " + akSender + " (rads: " + radsBeforeDoc + ")")
EndEvent

Event Scene.OnEnd(Scene akSender)
	float radsNow = PlayerRef.GetValue(Rads)
	Log("Scene.OnEnd: " + akSender + " (rads: " + radsNow + ")")

	; as the base game uses different quests for Doctors then for the Doctors from the DLC, we must check each seperate quest sadly
	If (DialogueGenericDoctors.DoctorJustCuredRads == 1 || DLC03CoA_DialogueNucleusArchemist.DoctorJustCuredRads == 1 || DLC03DialogueFarHarbor.DoctorJustCuredRads == 1 || DLC03AcadiaDialogue.DoctorJustCuredRads == 1 || DLC04SettlementDoctor.DoctorJustCuredRads == 1)
		ResetMorphs()
	EndIf
EndEvent

; ------------------------
; Setup the various times this mod can use
; ------------------------
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

; ------------------------
; On MCM change, check if the settings are valid, and restart the mod if this is the case
; ------------------------
Function OnMCMSettingChange(string modName, string id)
	Log("OnMCMSettingChange: " + modName + "; " + id)
	If (LL_Fourplay.StringSubstring(id, 0, 1) == "s")
		string value = MCM.GetModSettingString(modName, id)
		If (LL_Fourplay.StringSubstring(value, 0, 1) == " ")
			string msg = "The value you have just changed has leading whitespace:\n\n'" + value + "'"
			MessageBox(msg)
		EndIf
	EndIf
	Restart()
EndFunction

; ------------------------
; Start / shutdown / reset of the mod
; ------------------------
Function Startup()
	Log("Startup")
	If (MCM.GetModSettingBool("LenA_RadMorphing", "bIsEnabled:General") && !IsStartingUp)
		Log("  is enabled")
		IsStartingUp = true

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

		EnablePopping = MCM.GetModSettingBool("LenA_RadMorphing", "bEnablePopping:General")
		PopStates = MCM.GetModSettingInt("LenA_RadMorphing", "iPopStates:General")
		PopShouldParalyze = MCM.GetModSettingBool("LenA_RadMorphing", "bPopShouldParalyze:General")

		MaxRadiationMultiplier = MCM.GetModSettingInt("LenA_RadMorphing", "iMaxRadiationMultiplier:General")
		
		EnableRadsPerks = MCM.GetModSettingBool("LenA_RadMorphing", "bEnableRadsPerks:General")

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

		; reapply base morphs for the doctor-only reset morphs
		int idxSet = 0
		While (idxSet < SliderSets.Length)
			SliderSet set = SliderSets[idxSet]
			;TODO hier ook bepalen wat de laagste min slider is
			;TODO hier ook bepalen wat de hoogste max slider is

			If (set.OnlyDoctorCanReset && set.IsAdditive)
				HasDoctorOnlySliders = true
				if (set.BaseMorph > 0)
					Log("reload sliderset " + idxSet)
					SetMorphs(idxSet, set, set.BaseMorph)
					SetCompanionMorphs(idxSet, set.BaseMorph, set.ApplyCompanion)
				endif
			endif

			; store whether we have sliders which should effect companions of a specific sex
			If (!SlidersEffectFemaleCompanions && (set.ApplyCompanion == EApplyCompanionFemale || set.ApplyCompanion == EApplyCompanionAll))
				SlidersEffectFemaleCompanions = true
			endif
			If (!SlidersEffectFemaleCompanions && (set.ApplyCompanion == EApplyCompanionMale || set.ApplyCompanion == EApplyCompanionAll))
				SlidersEffectMaleCompanions = true
			endif

			idxSet += 1
		EndWhile

		; when we don't use sliders that are doctor-only reset, reset the totalRads and possible radperks
		if (!HasDoctorOnlySliders)			
			TotalRads = 0
			CurrentRadsPerk = 0
		endif

		ApplyAllCompanionMorphs()
		BodyGen.UpdateMorphs(PlayerRef)

		; recalculate the rad perks when enabed
		if (EnableRadsPerks)			
			ApplyRadsPerk()
		; else clear any existing perks
		Else
			ClearAllRadsPerks()
		endif

		If (UpdateType == EUpdateTypeImmediately)
			; start timer
			TimerMorphTick()
		ElseIf (UpdateType == EUpdateTypeOnSleep)
			; listen for sleep events
			RegisterForPlayerSleep()
		EndIf

		IsStartingUp = false
		Log("Startup complete")
	ElseIf (MCM.GetModSettingBool("LenA_RadMorphing", "bWarnDisabled:General"))
		Log("  is disabled, with warning")
		MessageBox("Rad Morphing is currently disabled. You can enable it in MCM > Rad Morphing > Enable Rad Morphing")
	Else
		Log("  is disabled, no warning")
	EndIf
EndFunction

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
		;TODO moeten de andere scenes hier ook niet bij staan?
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

		;TODO dis niet goed, want in de timerbased morphs doen we wat funkies met bepalen hoe / wat CurrentMorph is
		;nu schiet ie iedere keer een stuk vooruit als ie dit gedaan heeft, omdat BaseMorph nu te groot wordt opgeslagen
		
		;als we in die timer de BaseMorph updaten indien een rad decrease is, dan is dat niet BaseMorph = CurrentMorph, maar BaseMorph += CurrentMorph - berekende morph percentage
		;die laatste wordt bepaald afhankelijk van flink wat dingen, incl min / max morphs, die MaximumMorphMultiplier, en nog meer
		;...then again, wat we vervolgens opslaan in CurrentMorph is dat berekende percentage...
		;alleen weet je hier vervolgens alleen CurrentMorph, en niet wat verschil was. Dus hier een += van maken maakt probleem groter

		;je zou eigenlijk moeten bijhouden wat percentage verschil was, dan kan je hier die van currentMorph aftrekken en dat op dezelfde manier berekenen
		;dus ala CurrentMorph een veld op die sliderset erbij waarbij je verschil met BaseMorph bijhoudt, en iedere keer update
		;gaat alleen hiervoor nuttig zijn tho...

		
		; ; store the baseMorph of slidersets which are doctor-only reset and are additive
		; ; if we don't do this, then on startup it will load the previous value, which is either 0 if we haven't had a rad decrease, or the value it was on last rad decrease
		; int idxSet = 0
		; While (idxSet < SliderSets.Length)
		; 	SliderSet set = SliderSets[idxSet]
		; 	If (set.OnlyDoctorCanReset && set.IsAdditive)
		; 		set.BaseMorph = set.CurrentMorph
		; 	endif
		; 	idxSet += 1
		; EndWhile

		Shutdown()
		While (IsShuttingDown)
			Utility.Wait(1.0)
		EndWhile
		Startup()
		While (IsStartingUp)
			Utility.Wait(1.0)
		EndWhile
		Log("Restart completed")
	Else
		Log("RestartStackSize: " + RestartStackSize)
	EndIf
	RestartStackSize -= 1
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

		; when we found an existing sliderSet, reuse the BaseMorph, CurrentMorph and IsMaxedOut
		If (oldSet)
			newSet.BaseMorph = oldSet.BaseMorph
			newSet.CurrentMorph = oldSet.CurrentMorph
			newSet.IsMaxedOut = oldSet.IsMaxedOut
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
	RetrieveAllOriginalCompanionMorphs()
EndFunction

; ------------------------
; Radiation detection and what not
; ------------------------
;TODO doesn't seem to trigger with god mode (TGM) on. Works fine with invulnerability mode (TIM) tho
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
; Sleep-based morphs
; ------------------------
Event OnPlayerSleepStart(float afSleepStartTime, float afDesiredSleepEndTime, ObjectReference akBed)
	Log("OnPlayerSleepStart: afSleepStartTime=" + afSleepStartTime + ";  afDesiredSleepEndTime=" + afDesiredSleepEndTime + ";  akBed=" + akBed)
	Actor[] allCompanions = Game.GetPlayerFollowers() as Actor[]
	Log("  followers on sleep start: " + allCompanions)
	; update companions (companions cannot be found on sleep stop)
	UpdateCompanionList()
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
				float newMorph = CalculateMorphPercentage(CurrentRads, sliderSet)
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

; ------------------------
; Timer-based morphs
; ------------------------
Function TimerMorphTick()
	; if player is currently popping, we are starting up, or player is in Power Armor, restart timer and do nothing
	if (IsPopping || IsStartingUp || PlayerRef.IsInPowerArmor())		
		StartTimer(UpdateDelay, ETimerMorphTick)
		return
	endif

	; get the player's current Rads
	; note that the rads run from 0 to 1, with 1 equaling 1000 displayed rads
	float newRads = GetNewRads()

	; if rads haven't changed, restart timer and do nothing
	If (newRads == CurrentRads)
		StartTimer(UpdateDelay, ETimerMorphTick)
		return
	endif

	; calculate the amount of rads taken
	; the longer the timer interval, the larger this will be
	float radsDifference = newRads - CurrentRads
	Log("rads taken: " + (radsDifference * 1000))
	
	CurrentRads = newRads
	; companions
	UpdateCompanionList()

	; when we have no doctor-only reset sliders, TotalRads should always match our current rads
	if (!HasDoctorOnlySliders)
		TotalRads = newRads
	; if we do have doctor-only reset sliders, only update TotalRads if it is an increase in rads
	elseif (radsDifference > 0)
		TotalRads += radsDifference
	endif
	
	; recalculate which radsPerk to apply when enabled
	if (EnableRadsPerks)
		ApplyRadsPerk()
	endif

	int idxSet = 0
	; by default, assume we have no changed morphs for all sliderSets
	bool changedMorphs = false
	; by default, assume we are not at our max morphs for all sliderSets
	bool maxedOutMorphs = false

	int morphableSliders = 0
	int maxedOutSliders = 0

	; check each sliderset whether we need to update the morphs
	While (idxSet < SliderSets.Length)
		SliderSet sliderSet = SliderSets[idxSet]

		;TODO kijken of Papyrus iets ondersteund ala continue in een loop
		;hij herkent continue niet als een valid iets, dus ik betwijfel het

		If (sliderSet.NumberOfSliderNames > 0)
			float calculatedMorphPercentage = CalculateMorphPercentage(newRads, sliderSet)

			; only try to apply the morphs if either
			; -the new morph is larger then the slider's current morph
			; -the new morph is unequal to the slider's current morph when slider isn't doctor-only reset
			If (calculatedMorphPercentage > sliderSet.CurrentMorph || (!sliderSet.OnlyDoctorCanReset && calculatedMorphPercentage != sliderSet.CurrentMorph))
				; by default the morph we will apply is the calculated morph, with the max morph being 1.0
				; both will get modified if we have additive morphs enabled for this sliderSet
				float morphPercentage = calculatedMorphPercentage
				float maxMorphPercentage = 1.0

				; when we have additive morphs active for this slider, add the BaseMorph to the calculated morph
				; limit this to the lower of the calculated morph and the additive morph limit when we use additive morph limit
				If (sliderSet.IsAdditive)
					morphPercentage += sliderSet.BaseMorph
					If (sliderSet.HasAdditiveLimit)
						maxMorphPercentage = (1.0 + sliderSet.AdditiveLimit)
						morphPercentage = Math.Min(morphPercentage, maxMorphPercentage)
					EndIf
				EndIf
				
				;Log("    test " + idxSet + " morphPercentage: " + morphPercentage + "; maxMorphPercentage: " + maxMorphPercentage+ "; HasReachedMaxMorphs: " + HasReachedMaxMorphs+ "; sliderSet.OnlyDoctorCanReset: " + sliderSet.OnlyDoctorCanReset + "; sliderSet.IsMaxedOut: " + sliderSet.IsMaxedOut + "; radsDifference: " + radsDifference)

				; when we have an additive slider with no limit, apply the morphs without further checks
				if (sliderSet.IsAdditive && !sliderSet.HasAdditiveLimit)
					changedMorphs = SetMorphsAndReturnTrue(idxSet, sliderSet, morphPercentage)
				; when we have a limited slider, only actually apply the morphs if they are less then/equal to our max allowed morphs and either:
				ElseIf (morphPercentage <= maxMorphPercentage)
					; -sliderSet is doctor-only reset and the sliderset isn't maxed out
					if (sliderSet.OnlyDoctorCanReset && !sliderSet.IsMaxedOut)
						changedMorphs = SetMorphsAndReturnTrue(idxSet, sliderSet, morphPercentage)
						
						; when the morphs are maxed out, set this on the sliderSet
						if (morphPercentage == maxMorphPercentage)
							sliderSet.IsMaxedOut = true
						; when the morphs are not maxed out, set this on the sliderSet
						else
							sliderSet.IsMaxedOut = false
						endif								
					; -sliderSet is not doctor-only reset and either the sliderset isn't maxed out or the rads are negative
					; the only difference here is that we also want affect the global HasReachedMaxMorphs variable in this case
					elseif (!sliderSet.OnlyDoctorCanReset && (!sliderSet.IsMaxedOut || radsDifference < 0))
						changedMorphs = SetMorphsAndReturnTrue(idxSet, sliderSet, morphPercentage)
						
						; when the morphs are maxed out, set this on the sliderSet
						if (morphPercentage == maxMorphPercentage)
							sliderSet.IsMaxedOut = true
						; when the morphs are not maxed out, set this on the sliderSet, set the global HasReachedMaxMorphs to false
						else
							sliderSet.IsMaxedOut = false
							HasReachedMaxMorphs = false
						endif
					endif
				endif

				; we always want to update the sliderSet's CurrentMorph, no matter if we actually updated the sliderSet's morphs or not
				; eventually we have taken enough total rads we won't enter the containing if-statement						
				sliderSet.CurrentMorph = calculatedMorphPercentage

			; when we have negative morphs and additive sliders, store our current morphs as the new BaseMorph
			; this way when we take further rads, we start of at the previous morphs instead of starting from scratch again
			ElseIf (sliderSet.IsAdditive)
				sliderSet.BaseMorph += sliderSet.CurrentMorph - calculatedMorphPercentage
				sliderSet.CurrentMorph = calculatedMorphPercentage
			EndIf

			; increase morphableSliders with one, and maxedOutSliders with one if the sliderSet is maxed out
			morphableSliders += 1
			if (sliderSet.IsMaxedOut)
				maxedOutSliders += 1
			endif
		EndIf
		idxSet += 1
	EndWhile

	; when all morphable sliderSets are maxed out, set maxedOutMorphs to true
	if (morphableSliders == maxedOutSliders)
		maxedOutMorphs = true
	endif

	Log("    update - changedMorphs: " + changedMorphs + "; maxedOutMorphs: " + maxedOutMorphs + "; radsDifference: " + radsDifference + "; HasReachedMaxMorphs: " + HasReachedMaxMorphs)

	; when at least one of the sliderSets has applied morphs, perform the actual actions
	If (changedMorphs)
		BodyGen.UpdateMorphs(PlayerRef)
		; play morph sound when we haven't reached max morphs yet
		if (!maxedOutMorphs)
			PlayMorphSound(PlayerRef, radsDifference)
		endif
		; when at least one of the sliderSets effects companions, play the morph sound for them as well
		if (SlidersEffectFemaleCompanions || SlidersEffectMaleCompanions)
			ApplyAllCompanionMorphsWithSound(radsDifference)
		endif
		TriggerUnequipSlots()
	endif

	; when we have reached max morphs and have taken positive rads, perform additional actions
	If (maxedOutMorphs && radsDifference > 0)
		; when not yet displayed the max morphs, display the message and set the global variable that we have displayed the max morphs message
		; also play a sound effect if we have it
		if (!HasReachedMaxMorphs)
			if (!IsStartingUp)
				Note("I won't get any bigger")
				LenARM_FullSound.Play(PlayerRef)
				if (SlidersEffectFemaleCompanions || SlidersEffectMaleCompanions)
					PlayCompanionSoundFull()
				endif
			endif
			HasReachedMaxMorphs = true
		
		; when popping is enabled, randomly on taking rads increase the PopWarnings
		; when PopWarnings eventually has reached three, 'pop' the player
		Elseif (EnablePopping && !IsStartingUp)
			CheckPopWarnings()
		endif
	EndIf
	StartTimer(UpdateDelay, ETimerMorphTick)
EndFunction

; ------------------------
; Calculate the morph percentage for the given sliderSet based on the given rads and the slider's min / max thresholds
; ------------------------
float Function CalculateMorphPercentage(float newRads, SliderSet sliderSet)
	float morphPercentage

	; calculate the amount of rads we see as the max (by default 1000, modified by a multiplier)
	float maxRads = 1.0 * MaxRadiationMultiplier

	; do the same for our min / max threshold
	float minThreshold = sliderSet.ThresholdMin * maxRads
	float maxThreshold = sliderSet.ThresholdMax * maxRads

	If (newRads < minThreshold)
		morphPercentage = 0.0
	ElseIf (newRads > maxThreshold)
		morphPercentage = 1.0
	Else
		morphPercentage = (newRads - minThreshold) / (maxThreshold - minThreshold)
	EndIf
	
	;TechnicalNote("rads: " + newRads + "; morph: " + morphPercentage + "; minT: " + minThreshold + "; maxT: " + maxThreshold + "; %: " + MaxRadiationMultiplier)

	return morphPercentage
EndFunction

; ------------------------
; Calculate the morph for the given sliderSet based on the given morph percentage and target morph
; ------------------------
float Function CalculateMorphs(int idxSlider, float morphPercentage, float targetMorph)
	return (OriginalMorphs[idxSlider] + (morphPercentage * targetMorph))
EndFunction

; ------------------------
; Apply the given sliderSet's morphs to the matching BodyGen sliders
; ------------------------
Function SetMorphs(int idxSet, SliderSet sliderSet, float morphPercentage)
	int sliderNameOffset = SliderSet_GetSliderNameOffset(idxSet)
	int idxSlider = sliderNameOffset
	int sex = PlayerRef.GetLeveledActorBase().GetSex()
	While (idxSlider < sliderNameOffset + sliderSet.NumberOfSliderNames)
		float newMorph = CalculateMorphs(idxSlider, morphPercentage, sliderSet.TargetMorph)

		BodyGen.SetMorph(PlayerRef, sex==ESexFemale, SliderNames[idxSlider], kwMorph, newMorph)
		Log("    setting slider '" + SliderNames[idxSlider] + "' to " + newMorph + " (base value is " + OriginalMorphs[idxSlider] + ") (base morph is " + sliderSet.BaseMorph + ") (target is " + sliderSet.TargetMorph + ")")
		If (sliderSet.ApplyCompanion != EApplyCompanionNone)
			SetCompanionMorphs(idxSlider, morphPercentage * sliderSet.TargetMorph, sliderSet.ApplyCompanion)
		EndIf
		idxSlider += 1
	EndWhile
EndFunction

bool Function SetMorphsAndReturnTrue(int idxSet, SliderSet sliderSet, float morphPercentage)
	SetMorphs(idxSet, sliderSet, morphPercentage)
	return true
EndFunction

; ------------------------
; Restore the original BodyGen values for each slider, and set all sliderset's morphs to 0
; Will also reset various global bools used on various places
; ------------------------
Function ResetMorphs()
	Log("ResetMorphs")
	RestoreOriginalMorphs()

	; re-enable the display of the max-morphs message
	HasReachedMaxMorphs = false;
	; reset the pop warnings
	PopWarnings = 0

	; reset the fake rads
	FakeRads = 0
	TakeFakeRads = false
	TotalRads = 0

	; reset the rad perks
	ClearAllRadsPerks()

	; reset saved morphs in SliderSets
	int idxSet = 0
	While (idxSet < SliderSets.Length)
		SliderSet set = SliderSets[idxSet]
		set.BaseMorph = 0.0
		set.CurrentMorph = 0.0
		set.IsMaxedOut = false
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

	RestoreAllOriginalCompanionMorphs()
EndFunction

; ------------------------
; Take given chance, subtract player's Luck, roll a dice, and return whether the dice is lower then the chance
; ------------------------
bool Function ShouldPop(int popChance)
	int random = Utility.RandomInt(1, 10)
	int playerLuck = PlayerRef.GetValue(LuckAV) as int

	; divide the player luck by 10, rounding down
	; ie luck of 3 becomes 1, luck of 10 becomes 3
	int roundedLuck = playerLuck / 3

	; base pop chance is X/10, but X can be reduced by the player's Luck stat
	; depending on X it technically can become 0 or less, especially with stat boosters
	int modifiedPopChance = popChance - roundedLuck

	; when the dice value is lower then (modified) pop chance, return true
	; else return false
	bool shouldPop = random <= modifiedPopChance
	return shouldPop
EndFunction

; ------------------------
; Roll a dice whether to increase the PopWarnings by 1, with various effects on a success
; ------------------------
Function CheckPopWarnings()
	; 30% base chance to trigger
	bool shouldPop = ShouldPop(3)

	if (!shouldPop)
		return
	endif

	if (PopWarnings == 0)
		Note("My body still reacts to rads")
		PopWarnings += 1
		LenARM_MorphSound_Med.Play(PlayerRef)
		if (SlidersEffectFemaleCompanions || SlidersEffectMaleCompanions)
			PlayCompanionSoundMedium()
		endif
		; While (idxComp < CurrentCompanions.Length)
		; 	Actor companion = CurrentCompanions[idxComp]
		; 	int sex = companion.GetLeveledActorBase().GetSex()
	
		; 	; only play sounds if there are sliders which effect the companion's sex
		; 	If ((sex == ESexFemale && SlidersEffectFemaleCompanions) || (sex == ESexMale && SlidersEffectMaleCompanions))
		; 		; do a random delay before playing morph sounds on the companion
		; 		float randomFloat = (Utility.RandomInt(2,6) * 0.1) as float
	
		; 		Utility.Wait(randomFloat)
		; 		BodyGen.UpdateMorphs(CurrentCompanions[idxComp])
		; 		LenARM_MorphSound_Med.Play(companion)
		; 	endif
		; 	idxComp += 1
		; EndWhile
	ElseIf (PopWarnings == 1)
		Note("My body feels so tight")
		PopWarnings += 1
		LenARM_MorphSound_High.Play(PlayerRef)
		if (SlidersEffectFemaleCompanions || SlidersEffectMaleCompanions)
			PlayCompanionSoundHigh()
		endif	
	ElseIf (PopWarnings == 2)
		Note("I'm going to pop if I take more rads")
		PopWarnings += 1
		LenARM_FullSound.Play(PlayerRef)
		if (SlidersEffectFemaleCompanions || SlidersEffectMaleCompanions)
			PlayCompanionSoundFull()
		endif	
	Else
		Pop()
	endif
EndFunction

; ------------------------
; Paralyze the player, expand current morphs several times, reset the morphs, apply debuff, and unparalyze the player
; ------------------------
Function Pop()
	int currentPopState = 1
	int unequipState = 3 ;TODO make config in MCM?
	IsPopping = true

	Log("pop!")

	;TODO make it effect companions?

	; force third person camera
	;TODO eigen config
	if (PopShouldParalyze)
		Game.ForceThirdPerson()							
	endif
	Utility.Wait(0.5)

	; reset rads in case player is in a high-rads zone
	PlayerRef.EquipItem(ResetRadsPotion, abSilent = true)

	; play sound, paralyse player and then knock them out
	; the order of first paralysing and then knocking out is important, lest you get odd glitches
	LenARM_FullSound.Play(PlayerRef)
	if (PopShouldParalyze)
		PlayerRef.SetValue(ParalysisAV, 1)
		PlayerRef.PushActorAway(PlayerRef, 0.5)						
	endif
	Utility.Wait(0.7)

	; gradually increase the morphs and unequip the clothes
	While (currentPopState < PopStates)		
		LenARM_SwellSound.Play(PlayerRef)								
		; for the unequip state we don't want to play the swell sound, but unequip the clothes instead
		If (currentPopState != unequipState)
			;LenARM_SwellSound.Play(PlayerRef)
		Else
			UnequipAll()
		endif

		ExtendMorphs(currentPopState)
		Utility.Wait(0.7)

		currentPopState += 1
	EndWhile

	; apply the final morphs, and do the 'pop', resetting all the morphs back to 0
	; for this situation we do want to wait for the sound effect to finish playing
	ExtendMorphs(currentPopState)
	LenARM_PrePopSound.PlayAndWait(PlayerRef)
	LenARM_PopSound.Play(PlayerRef)
	ResetMorphs()	

	; apply the debuffs on the player and reset the player's rads by ingesting the respective potions
	PlayerRef.EquipItem(PoppedPotion, abSilent = true)
	PlayerRef.EquipItem(ResetRadsPotion, abSilent = true)

	; unset the IsPopping flag before we undo the paralysing
	IsPopping = false
				
	; wait a bit before we can actually stand up again
	if (PopShouldParalyze)
		Utility.Wait(1.5)
		PlayerRef.SetValue(ParalysisAV, 0)
	endif
EndFunction

; ------------------------
; Increase all sliders by a percentage multiplied with the input
; Does not store the updated sliders' CurrentMorphs, as we will call ResetMorphs afterwards anyway
; ------------------------
Function ExtendMorphs(float step)
	Log("extending morphs with: " + step)
	int idxSet = 0

	; calculate the new morphs multiplier
	float multiplier = 1.0 + (step/8)

	; apply it to all morphs from slidersets which aren't excluded
	While (idxSet < SliderSets.Length)
		SliderSet sliderSet = SliderSets[idxSet]		
		If (sliderSet.NumberOfSliderNames > 0 && !sliderSet.ExcludeFromPopping)
			SetMorphs(idxSet, sliderSet, multiplier)
		EndIf
		idxSet += 1
	EndWhile
	
	; apply all new morphs to the body
	BodyGen.UpdateMorphs(PlayerRef)
EndFunction

; ------------------------
; Check the total accumulated rads, and apply the matching radsPerk to the player
; ------------------------
Function ApplyRadsPerk()
	;TODO wellicht anders perks vervangen door potions

	;TODO doe maar goed nadenken over hoe / wanneer we dit aanroepen als je de config aan / uit zet
	;vermoed nu namelijk dat de perks blijven hangen
	;visa versa als je ze aanzet en je hebt al rads; hij gaat dan pas bij eerstvolgende rads increase updaten

	; when we have 0 rads, clear all existing perks and don't apply a new one
	if (TotalRads == 0)
		ClearAllRadsPerks()
		return
	endif

	;TODO bepaal wat min / max zijn, en vanaf wanneer we dus moeten gaan werken tot wanneer
	;zie ook CalculateMorphPercentage
	; voor nu gebruiken we 0 als min en 1000 als max
	;TODO moet dus ook rekening gaan houden met MaxRadiationMultiplier

	; calculate the perk level
	int perkLevel = ((TotalRads * 1000) / 200) as int

	;Log((TotalRads * 1000) + "; " + ((TotalRads * 1000) / 200) + "; " + perkLevel)

	; limit to 4 just in case (we have 5 perks, starting from 0)
    If (perkLevel > 4)
        perkLevel = 4
    EndIf

	; when we have enough rads that we should have a difference in perk level, change perks
	if (CurrentRadsPerk != perkLevel)
		ClearOldRadsPerks(perkLevel)
		PlayerRef.AddPerk(RadsPerkArray[perkLevel])
		
		CurrentRadsPerk = perkLevel
	endif
EndFunction

; ------------------------
; Loops through all possible radsPerks, removing those that are active if they don't match the newPerkLevel
; Does not apply the matching radsPerk, you must do that manually
; Use -1 to clear all perks
; ------------------------
Function ClearOldRadsPerks(int newPerkLevel)
    int i = 0
    While (i < 5)
        If (i != newPerkLevel && PlayerRef.HasPerk(RadsPerkArray[i]))
            ; If (PlayerRef.HasPerk(RadsPerkArray[i]))
                Log("Removing radsperk of level " + i)
                PlayerRef.RemovePerk(RadsPerkArray[i])
            ; EndIf
        EndIf
        i += 1
    EndWhile
	
	;TODO debug thingy
	if (newPerkLevel > -1)
    	Note("RadsPerk Level " + newPerkLevel + " applied")    
	endif
EndFunction

Function ClearAllRadsPerks()
    ClearOldRadsPerks(-1)
EndFunction

; ------------------------
; All companion related logic, still WiP / broken
; ------------------------

; Function LogCompanionMorphs()
; 	int idx = 0
; 	While (idx < OriginalCompanionMorphs.Length)
; 		float companionMorphs = OriginalCompanionMorphs[idx]
; 		Log(companionMorphs)
; 		idx += 1
; 	EndWhile
; EndFunction

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
		Log("companion " + idxComp)
		Actor companion = CurrentCompanions[idxComp]
		RetrieveOriginalCompanionMorphs(companion)
		idxComp += 1
	EndWhile
EndFunction

Function RetrieveOriginalCompanionMorphs(Actor companion)
	Log("RetrieveOriginalCompanionMorphs: " + companion)
	int idxSlider = 0
	While (idxSlider < SliderNames.Length)
		;Log("sliderset " + idxSlider)
		OriginalCompanionMorphs.Add(BodyGen.GetMorph(companion, True, SliderNames[idxSlider], None))
		idxSlider += 1
	EndWhile
EndFunction

Function SetCompanionMorphs(int idxSlider, float morph, int applyCompanion)
	;Log("SetCompanionMorphs: " + idxSlider + "; " + morph + "; " + applyCompanion)
	int idxComp = 0
	While (idxComp < CurrentCompanions.Length)
		Actor companion = CurrentCompanions[idxComp]
		If (!companion.IsInPowerArmor())			
			int sex = companion.GetLeveledActorBase().GetSex()
			If (applyCompanion == EApplyCompanionAll || (sex == ESexFemale && applyCompanion == EApplyCompanionFemale) || (sex == ESexMale && applyCompanion == EApplyCompanionMale))
				int offsetIdx = SliderNames.Length * idxComp
				float companionMorphs = OriginalCompanionMorphs[offsetIdx + idxSlider]
				float newMorphs = companionMorphs + morph
				;Log("    setting companion(" + companion + ") slider '" + SliderNames[idxSlider] + "' to " + (OriginalCompanionMorphs[offsetIdx + idxSlider] + morph) + " (base value is " + OriginalCompanionMorphs[offsetIdx + idxSlider] + ")")
				BodyGen.SetMorph(companion, sex==ESexFemale, SliderNames[idxSlider], kwMorph, newMorphs)
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
	ApplyAllCompanionMorphsWithSound(0)
EndFunction

Function ApplyAllCompanionMorphsWithSound(float radsDifference)
	Log("ApplyAllCompanionMorphs")
	int idxComp = 0
	While (idxComp < CurrentCompanions.Length)
		Actor companion = CurrentCompanions[idxComp]
		int sex = companion.GetLeveledActorBase().GetSex()

		; only apply the morphs and play sounds if there are sliders which effect the companion's sex
		If ((sex == ESexFemale && SlidersEffectFemaleCompanions) || (sex == ESexMale && SlidersEffectMaleCompanions))
			; do a random delay before appying the morphs (and morph sounds) on the companion
			float randomFloat = (Utility.RandomInt(2,6) * 0.1) as float

			Utility.Wait(randomFloat)
			BodyGen.UpdateMorphs(CurrentCompanions[idxComp])
			PlayMorphSound(CurrentCompanions[idxComp], radsDifference)
		endif
		idxComp += 1
	EndWhile
EndFunction

;TODO dis lelijk, maar zover ik ff kon testen kan je geen Sound meegeven als param (je kan Sound.Play vervolgens niet aanroepen)
;kijken of dit toch niet op een of andere manier mogelijk is; dingen zoals Actors kan je wel meegeven als params en dan aanroepen
Function PlayCompanionSoundMedium()
	int idxComp = 0
	While (idxComp < CurrentCompanions.Length)
		Actor companion = CurrentCompanions[idxComp]
		int sex = companion.GetLeveledActorBase().GetSex()

		; only play sounds if there are sliders which effect the companion's sex
		If ((sex == ESexFemale && SlidersEffectFemaleCompanions) || (sex == ESexMale && SlidersEffectMaleCompanions))
			; do a random delay before playing morph sounds on the companion
			float randomFloat = (Utility.RandomInt(2,6) * 0.1) as float

			Utility.Wait(randomFloat)
			BodyGen.UpdateMorphs(CurrentCompanions[idxComp])
			LenARM_MorphSound_Med.Play(companion)
		endif
		idxComp += 1
	EndWhile
EndFunction
Function PlayCompanionSoundHigh()
	int idxComp = 0
	While (idxComp < CurrentCompanions.Length)
		Actor companion = CurrentCompanions[idxComp]
		int sex = companion.GetLeveledActorBase().GetSex()

		; only play sounds if there are sliders which effect the companion's sex
		If ((sex == ESexFemale && SlidersEffectFemaleCompanions) || (sex == ESexMale && SlidersEffectMaleCompanions))
			; do a random delay before playing morph sounds on the companion
			float randomFloat = (Utility.RandomInt(2,6) * 0.1) as float

			Utility.Wait(randomFloat)
			BodyGen.UpdateMorphs(CurrentCompanions[idxComp])
			LenARM_MorphSound_High.Play(companion)
		endif
		idxComp += 1
	EndWhile
EndFunction
Function PlayCompanionSoundFull()
	int idxComp = 0
	While (idxComp < CurrentCompanions.Length)
		Actor companion = CurrentCompanions[idxComp]
		int sex = companion.GetLeveledActorBase().GetSex()

		; only play sounds if there are sliders which effect the companion's sex
		If ((sex == ESexFemale && SlidersEffectFemaleCompanions) || (sex == ESexMale && SlidersEffectMaleCompanions))
			; do a random delay before playing morph sounds on the companion
			float randomFloat = (Utility.RandomInt(2,6) * 0.1) as float

			Utility.Wait(randomFloat)
			BodyGen.UpdateMorphs(CurrentCompanions[idxComp])
			LenARM_FullSound.Play(companion)
		endif
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

Function UpdateCompanionList()
	Log("UpdateCompanionList")
	Actor[] newComps = GetCompanions()
	RemoveDismissedCompanions(newComps)
	AddNewCompanions(newComps)
	Log("  CurrentCompanions: " + CurrentCompanions)
EndFunction

; ------------------------
; Check for each slider whether pieces of clothing / armor should get unequipped
; ------------------------
Function UnequipSlots()
	Log("UnequipSlots (stack=" + UnequipStackSize + ")")
	UnequipStackSize += 1
	If (UnequipStackSize <= 1)
		bool found = false

		bool[] compFound = new bool[CurrentCompanions.Length]
		int idxSet = 0

		; check if we are currently wearing a full-body suit (ie Hazmat suit)
		; the unequip logic has some issues when wearing full-body suits when unequipping any of the armor slots
		; it keeps trying to unequip the item with each call, but keeps on failing because the full-body suit technically both does and doesn't use the slots
		; the workaround is to first check what we have equipped in slot 0 and 3 (as it seems full-body suits cover these two slots)
		; do both slots have an item, and is this the same item, then mark we are wearing a full-body suit
		bool hasFullBodyItem = false
		Actor:WornItem itemSlot0 = PlayerRef.GetWornItem(0)		
		Actor:WornItem itemSlot3 = PlayerRef.GetWornItem(3)
		if (itemSlot0 != None && itemSlot0.item != None && itemSlot3 != None && itemSlot3.item != None && itemSlot0.item == itemSlot3.item)
			hasFullBodyItem = true
		EndIf

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
					
					; check if item in the slot is not an actor or the pipboy
					bool isArmor = (item.item && LL_Fourplay.StringSubstring(item.modelName, 0, 6) != "Actors" && LL_Fourplay.StringSubstring(item.modelName, 0, 6) != "Pipboy")
					; we can unequip if we currently aren't wearing a full-body suit, or we are wearing a full-body suit and the slot to unequip is slot 3
					bool canUnequip = (item.item && (!hasFullBodyItem || (hasFullBodyItem && UnequipSlots[idxSlot] == 3)))

					; when item is an armor and we can unequip it, do so
					If (isArmor && canUnequip)
						Log("  unequipping slot " + UnequipSlots[idxSlot] + " (" + item.item.GetName() + " / " + item.modelName + ")")

						PlayerRef.UnequipItem(item.item, false, true)

						; when the item is no longer equipped and we haven't already unequipped anything (goes across all sliders and slots),
						; play the strip sound if available and display a notification in top-left
						If (!found && !PlayerRef.IsEquipped(item.item))
							Note("It is too tight for me")
							LenARM_DropClothesSound.Play(PlayerRef)
							found = true
						EndIf
					EndIf
					;TODO companions
					; deze fixen is niet zo simpel, als je het netjes wilt doen
					; wat ie nu gaat doen is de oude 'check slot' logica uitvoeren en dan proberen te unequippen
					; gezien dit voor bepaalde armors issues oplevert, zou je in principe het hele isArmor / canUnequip stuk per companion nog eens moeten doen
					; gaat qua performance een bitch worden tho...
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
									LenARM_DropClothesSound.Play(CurrentCompanions[idxComp])
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

Function UnequipAll()
	Log("UnequipAll")

	bool found = false

	bool[] compFound = new bool[CurrentCompanions.Length]
	int idxSlot = 0

	; these are all the slots we want to unequip
	int[] allSlots = new int[0]
	
	allSlots.Add(3)
	allSlots.Add(11)
	allSlots.Add(12)
	allSlots.Add(13)
	allSlots.Add(14)
	allSlots.Add(15)

	; check for each slot
	While (idxSlot < allSlots.Length)
		int slot = allSlots[idxSlot]
		
		Actor:WornItem item = PlayerRef.GetWornItem(slot)
		
		; check if item in the slot is not an actor or the pipboy
		bool isArmor = (item.item && LL_Fourplay.StringSubstring(item.modelName, 0, 6) != "Actors" && LL_Fourplay.StringSubstring(item.modelName, 0, 6) != "Pipboy")

		; when item is an armor and we can unequip it, do so
		If (isArmor)
			Log("  unequipping slot " + slot + " (" + item.item.GetName() + " / " + item.modelName + ")")

			PlayerRef.UnequipItem(item.item, false, true)
			
			; when the item is no longer equipped and we haven't already unequipped anything (goes across all slots),
			; play the strip sound if available
			If (!found && !PlayerRef.IsEquipped(item.item))
				LenARM_DropClothesSound.Play(PlayerRef)
				found = true
			EndIf
		EndIf
		;TODO companions
		; zelfde issue speelt hier als met UnequipSlots voor Companions
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
						LenARM_DropClothesSound.Play(CurrentCompanions[idxComp])
						compFound[idxComp] = true
					EndIf
				EndIf
			EndIf
			idxComp += 1
		EndWhile/;
		idxSlot += 1	
	EndWhile
	Log("FINISHED UnequipAll")
EndFunction

; ------------------------
; Play a sound depending on the rads difference and the MCM settings
; ------------------------
Function PlayMorphSound(Actor akSender, float radsDifference)
	; don't try to play sounds on startup
	if (IsStartingUp)
		return
	endif

	; everything below LowRadsThreshold rads taken, including rad decreases (ie RadAway)
	if (radsDifference <= LowRadsThreshold)
		Log("  minimum rads taken")
	; everything between LowRadsThreshold and MediumRadsThreshold rads taken
	elseif (radsDifference <= MediumRadsThreshold)
		Log("  medium rads taken")
		LenARM_MorphSound.Play(akSender)
	; everything between MediumRadsThreshold and HighRadsThreshold rads taken
	elseif (radsDifference <= HighRadsThreshold)
		Log("  high rads taken")
		LenARM_MorphSound_Med.Play(akSender)
	; everything above HighRadsThreshold rads taken
	elseif (radsDifference > HighRadsThreshold)
		Log("  very high rads taken")
		LenARM_MorphSound_High.Play(akSender)
	endif
EndFunction

; ------------------------
; Debug functions from the Debug MCM menu
; ------------------------
Function ForgetState(bool isCalledByUser=false)
	Log("ForgetState: isCalledByUser=" + isCalledByUser + "; ForgetStateCalledByUserCount=" + ForgetStateCalledByUserCount + "; IsForgetStateBusy=" + IsForgetStateBusy)

	; display notice to player that proces is still running
	If (isCalledByUser && IsForgetStateBusy)
		Log("  show busy warning")
		MessageBox("This function is already running. Wait until it has completed.")
	; on first button click, show warning instead of starting proces
	ElseIf (isCalledByUser && ForgetStateCalledByUserCount < 1)
		Log("  show warning")
		CancelTimer(ETimerForgetStateCalledByUserTick)
		MessageBox("<center><b>! WARNING !</b></center><br><br><p align='justify'>This function does not reset this mod's settings.<br>It will reset the mod's state. This includes the record of the original body shape. If your body or your companion's body is currently morphed by this mod you will be stuck with the current shape.</p><br>Click the button again to reset the mod's state.")
		ForgetStateCalledByUserCount = 1
		StartTimer(0.1, ETimerForgetStateCalledByUserTick)
	; on second button click (or called from system), start the proces
	Else
		Log("  reset state")
		IsForgetStateBusy = true

		If (isCalledByUser)
			CancelTimer(ETimerForgetStateCalledByUserTick)
			ForgetStateCalledByUserCount = 0
			Log("  show reset start message")
			MessageBox("Rad Morphing Redux is resetting itself. Another message will let you know once the mod is fully reset.")
		EndIf
		
		; stop timers and unregister events
		Shutdown(false)
		
		; reset the mod's state
		SliderSets = none
		SliderNames = none
		UnequipSlots = none

		OriginalMorphs = none
		OriginalCompanionMorphs = none
		
		CurrentCompanions = none
		
		CurrentRads = 0.0
		FakeRads = 0
		TakeFakeRads = false
		HasReachedMaxMorphs = false
		PopWarnings = 0

		; start the mod up again
		Startup()
		IsForgetStateBusy = false
		TechnicalNote("Mod state has been reset")
		If (isCalledByUser)
			Log("  show reset complete message")
			MessageBox("Rad Morphing Redux has been reset.")
		EndIf
	EndIf
EndFunction

Function ForgetStateCounterReset()
	Log("ForgetStateCounterReset; ForgetStateCalledByUserCount=" + ForgetStateCalledByUserCount)
	ForgetStateCalledByUserCount = 0
EndFunction

Function Debug_ShowLowestSliderPercentage()
	int idxSet = 0
	float lowestPercentage = 0

	; loop through the slidersets
	While (idxSet < SliderSets.Length)
		SliderSet sliderSet = SliderSets[idxSet]
		
		; only check the slidersets that have actual sliders
		If (sliderSet.NumberOfSliderNames > 0)
			; use sliderSet's currentMorph, unless we are additive, then use baseMorph as well
			float sliderPercentage = sliderSet.CurrentMorph
			If (sliderSet.IsAdditive)
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

	;TODO ik dump TotalRads hier ff als test in
	MessageBox((lowestPercentage * 100) + "% ; " + (TotalRads * 1000))
EndFunction

Function Debug_ResetCompanionMorphsArray()
	; in case you have somehow filled the OriginalCompanionMorphs array with 0 values (don't ask how I did it)
	RetrieveAllOriginalCompanionMorphs()
	; LogCompanionMorphs()
	
	MessageBox("Flushed and repopulated companion morphs array")
EndFunction

; ------------------------
; Debug function to check which slots the current equipped clothes / armor occupies
; ------------------------
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

	MessageBox(LL_FourPlay.StringJoin(items, "\n"))
EndFunction

Function GiveIrradiatedBlood()
	PlayerRef.AddItem(GlowingOneBlood, 50)
EndFunction

Function GiveExperimentalMorphDrugs()
	PlayerRef.AddItem(ResetMorphsExperimentalPotion, 1)
EndFunction

Function GiveMorphDrugs()
	PlayerRef.AddItem(ResetMorphsPotion, 1)
EndFunction

; ------------------------
; Helper functions for splitting strings
; ------------------------
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

; ------------------------
; Debug helpers for writing to Papyrus logs and displaying info messages ingame
; ------------------------

; show a big fat message box in the center of the page, which the player has to click away
Function MessageBox(string msg)
	Debug.MessageBox(msg)
	Log(msg)
EndFunction

; show a message in the top-left
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

; write a line to the log
Function Log(string msg)
	Debug.Trace("[LenARM] " + msg)
EndFunction

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
; MCM SliderSet functions / struct
; ------------------------
SliderSet Function SliderSet_Constructor(int idxSet)
	;Log("SliderSet_Constructor: " + idxSet)
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
		set.ExcludeFromPopping = MCM.GetModSettingBool("LenA_RadMorphing", "bExcludeFromPopping:Slider" + idxSet)

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
	bool ExcludeFromPopping
	; END: MCM values

	int NumberOfSliderNames
	int NumberOfUnequipSlots

	float BaseMorph
	float CurrentMorph
		
	bool IsMaxedOut
EndStruct