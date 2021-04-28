; HOW THIS MOD STARTS:
; You have the compiled LenARM:LenARM_Main.psx in your FO4/Data/Scripts folder.
; You have the LenA_RadMorphing.esp enabled in your mod loader.
; The .esp triggers the quest on game load, which in return runs this script file as it were an actual quest.
; With the generic OnQuestInit() and OnQuestShutdown() entry points we do the remaining setup and start the actual logic.
Scriptname LenARM:LenARM_Main extends Quest

;GENERIC TO FIX LIST
;-see if the whole update process can be made faster / more efficient
;  -work with integers instead of floats for easier calculations (might mean making new local variables, aka can be tricky)
;-update companions again (see TODO: companions)
;-unequip sometimes doesn't actually unequip the clothing / armor
;-TimedBasedMorphs now looks for the actual received radiation for basicly everything. This is most likely the reason why the FakeRads logic is buggy
;  -things like MorphSounds still seem to look at the actual received rads instead of the FakeRads when you use FakeRads
;  -might also explain why god-mode together with FakeRads doesn't seem to apply any morphs anymore
;-don't play MorphSounds when none of the sliders should effect companions

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

; has the player reached the max on all sliderSets? this includes additive morphing if these are limited
bool HasReachedMaxMorphs

; how many pop warnings have we displayed
int PopWarnings

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
	;TODO kan weg
	Spell Property Paralyze Auto Const	
	;TODO kan weg
	ActorValue Property ParalysisAV Auto Const
	;TODO kan weg
	Idle Property RagdollIdle Auto Const
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

string Function GetVersion()
	return "0.7.1"; Thu Dec 17 09:11:27 CET 2020
EndFunction

; ------------------------
; On equipping of an item, check if it should get unequipped
; ------------------------
Event Actor.OnItemEquipped(Actor akSender, Form akBaseObject, ObjectReference akReference)
	; only check if we need to unequip anything when we equip clothing or armor and are not in power armor
	; this will break the hacky "unequip weapon slots" logic some people use tho...
	If (!PlayerRef.IsInPowerArmor() && akBaseObject as Armor)
		Log("Actor.OnItemEquipped: " + akBaseObject.GetName() + " (" + akBaseObject.GetSlotMask() + ")")
		Utility.Wait(1.0)
		TriggerUnequipSlots()
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
	If (DialogueGenericDoctors.DoctorJustCuredRads == 1)
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
			Debug.MessageBox(msg)
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
				SetCompanionMorphs(idxSet, set.BaseMorph, set.ApplyCompanion)
			EndIf
			idxSet += 1
		EndWhile
		ApplyAllCompanionMorphs()
		BodyGen.UpdateMorphs(PlayerRef)

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
		Debug.MessageBox("Rad Morphing is currently disabled. You can enable it in MCM > Rad Morphing > Enable Rad Morphing")
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
;TODO deze is obsolete? wordt nergens gebruikt zover ik zie? de andere worden wel gebruikt
;kijk in de .esp voor je hem nuked!
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
	;TODO disabled
	;/Log("OnPlayerSleepStart: afSleepStartTime=" + afSleepStartTime + ";  afDesiredSleepEndTime=" + afDesiredSleepEndTime + ";  akBed=" + akBed)
	;Actor[] allCompanions = Game.GetPlayerFollowers() as Actor[]
	;Log("  followers on sleep start: " + allCompanions)
	;TODO companions
	; update companions (companions cannot be found on sleep stop)
	UpdateCompanions()/;
EndEvent

Event OnPlayerSleepStop(bool abInterrupted, ObjectReference akBed)
	;TODO disabled
	;/Log("OnPlayerSleepStop: abInterrupted=" + abInterrupted + ";  akBed=" + akBed)
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
		;TODO companions
		;ApplyAllCompanionMorphs()
		TriggerUnequipSlots()
	EndIf/;
EndEvent

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
			;TODO dit moet naar FakeRads kijken als je FakeRads gebruikt
			float radsDifference = newRads - CurrentRads;
			Log("rads taken: " + (radsDifference * 1000));
						
			CurrentRads = newRads
			; companions
			UpdateCompanions()

			int idxSet = 0
			; by default, assume we have no changed morphs for all sliderSets
			bool changedMorphs = false
			; by default, assume we are at our max morphs for all sliderSets
			bool maxedOutMorphs = true
			; by default, assume none of the sliders affect our companions
			bool affectCompanions = false

			; check each sliderset whether we need to update the morphs
			While (idxSet < SliderSets.Length)
				SliderSet sliderSet = SliderSets[idxSet]
				
				if (sliderSet.ApplyCompanion != EApplyCompanionNone && !affectCompanions)
					affectCompanions = true
				endif

				If (sliderSet.NumberOfSliderNames > 0)
					float newMorph = GetNewMorph(newRads, sliderSet)

					; only try to apply the morphs if either
					; -the new morph is larger then the slider's current morph
					; -the new morph is unequal to the slider's current morph when slider isn't doctor-only reset
					If (newMorph > sliderSet.CurrentMorph || (!sliderSet.OnlyDoctorCanReset && newMorph != sliderSet.CurrentMorph))
						; by default the morph we will apply is the calculated morph, with the max morph being 1.0
						; both will get modified if we have additive morphs enabled for this sliderSet
						float fullMorph = newMorph
						float maxMorphs = 1.0

						; when we have additive morphs active for this slider, add the BaseMorph to the calculated morph
						; limit this to the lower of the calculated morph and the additive morph limit when we use additive morph limit
						If (sliderSet.IsAdditive)
							fullMorph += sliderSet.BaseMorph
							If (sliderSet.HasAdditiveLimit)
								maxMorphs = 1.0 + sliderSet.AdditiveLimit
								fullMorph = Math.Min(fullMorph, maxMorphs)
							EndIf
						EndIf
						
						;Log("    test " + idxSet + " fullMorph: " + fullMorph + "; maxMorphs: " + maxMorphs+ "; HasReachedMaxMorphs: " + HasReachedMaxMorphs+ "; sliderSet.OnlyDoctorCanReset: " + sliderSet.OnlyDoctorCanReset + "; sliderSet.IsMaxedOut: " + sliderSet.IsMaxedOut + "; radsDifference: " + radsDifference)

						; when we have an additive slider with no limit, apply the morphs without further checks
						if (sliderSet.IsAdditive && !sliderSet.HasAdditiveLimit)
							changedMorphs = SetMorphsAndReturnTrue(idxSet, sliderSet, fullMorph)
						; when we have a limited slider, only actually apply the morphs if they are less then/equal to our max allowed morphs and either:
						ElseIf (fullMorph <= maxMorphs)
							; -sliderSet is doctor-only reset and the sliderset isn't maxed out
							if (sliderSet.OnlyDoctorCanReset && !sliderSet.IsMaxedOut)
								changedMorphs = SetMorphsAndReturnTrue(idxSet, sliderSet, fullMorph)
								
								; when the morphs are maxed out, set this on the sliderSet
								if (fullMorph == maxMorphs)
									sliderSet.IsMaxedOut = true
								; when the morphs are not maxed out, set this on the sliderSet and set maxedOutMorphs to false
								else
									sliderSet.IsMaxedOut = false
									maxedOutMorphs = false
								endif								
							; -sliderSet is not doctor-only reset and either the sliderset isn't maxed out or the rads are negative
							; the only difference here is that we also want affect the global HasReachedMaxMorphs variable in this case
							elseif (!sliderSet.OnlyDoctorCanReset && (!sliderSet.IsMaxedOut || radsDifference < 0))
								changedMorphs = SetMorphsAndReturnTrue(idxSet, sliderSet, fullMorph)
								
								; when the morphs are maxed out, set this on the sliderSet
								if (fullMorph == maxMorphs)
									sliderSet.IsMaxedOut = true
								; when the morphs are not maxed out, set this on the sliderSet, set maxedOutMorphs to false and set the global HasReachedMaxMorphs to false
								else
									sliderSet.IsMaxedOut = false
									maxedOutMorphs = false
									HasReachedMaxMorphs = false
								endif
							endif
						endif

						; we always want to update the sliderSet's CurrentMorph, no matter if we actually updated the sliderSet's morphs or not
						; eventually we have taken enough total rads we won't enter the containing if-statement						
						sliderSet.CurrentMorph = newMorph

					; when we have negative morphs and additive sliders, store our current morphs as the new BaseMorph
					; this way when we take further rads, we start of at the previous morphs instead of starting from scratch again
					ElseIf (sliderSet.IsAdditive)
						sliderSet.BaseMorph += sliderSet.CurrentMorph - newMorph
						sliderSet.CurrentMorph = newMorph
					EndIf
				EndIf
				idxSet += 1
			EndWhile

			Log("    update - changedMorphs: " + changedMorphs + "; maxedOutMorphs: " + maxedOutMorphs + "; radsDifference: " + radsDifference + "; HasReachedMaxMorphs: " + HasReachedMaxMorphs)

			; when at least one of the sliderSets has applied morphs, perform the actual actions
			If (changedMorphs)
				BodyGen.UpdateMorphs(PlayerRef)
				; play morph sound when we haven't reached max morphs yet
				if (!maxedOutMorphs)
					PlayMorphSound(PlayerRef, radsDifference)
				endif
				; when at least one of the sliderSets affects companion, play the morph sound for them as well
				if (affectCompanions)
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
						; TODO new sound effect
						LenARM_MorphSound_High.Play(PlayerRef)
					endif
					HasReachedMaxMorphs = true
				
				; when popping is enabled, randomly on taking rads increase the PopWarnings
				; when PopWarnings eventually has reached three, 'pop' the player
				; //TODO bouw die config in, voor nu ff disabled zolang het nog WiP is
				Elseif (1 == 1)
					int random = Utility.RandomInt(1, 10)
					int popChance = 0 ;TODO TEMP 3
					bool shouldPop = random >= popChance

					if (shouldPop)
						if (PopWarnings == 0)
							;/Note("My body still reacts to rads")
							PopWarnings += 1
							LenARM_MorphSound.Play(PlayerRef)
						ElseIf (PopWarnings == 1)
							Note("My body feels so tight")
							PopWarnings += 1
							LenARM_MorphSound_Med.Play(PlayerRef)
						ElseIf (PopWarnings == 2)
							Note("I'm going to pop if I take more rads")
							PopWarnings += 1
							LenARM_MorphSound_High.Play(PlayerRef)
						Else/;

							Note("pop!")
							Game.ForceThirdPerson()
							PlayerRef.PushActorAway(PlayerRef, 0.5)
							;TODO this kinda works... shame about the sound pitch change it also applies
							;PlayerRef.SetValue(ParalysisAV, 1)
							;PlayerRef.PlayIdle(RagdollIdle)
							Utility.Wait(0.5)

							int popState = 1
							
							While (popState <= 5)								
								; for step 3 we don't want to play the expand sound, but unequip the clothes instead
								If (popState != 3)
									; TODO new sound effect
									LenARM_MorphSound_High.Play(PlayerRef)
								Else
									UnequipAll()
								endif

								PlayerRef.PushActorAway(PlayerRef, 0.5)
								ExtendMorphs(popState)
								Utility.Wait(0.5)

								popState += 1
							EndWhile


							;/; TODO new sound effect
							LenARM_MorphSound_High.Play(PlayerRef)
							ExtendMorphs(2)
							Utility.Wait(0.5)

							; TODO new sound effect
							LenARM_MorphSound_High.Play(PlayerRef)
							;
							ExtendMorphs(3)
							Utility.Wait(0.5)
							
							; TODO new sound effect
							LenARM_MorphSound_High.Play(PlayerRef)
							ExtendMorphs(4)
							Utility.Wait(0.5)

							; TODO new sound effect
							LenARM_MorphSound_High.Play(PlayerRef)
							ExtendMorphs(5)
							Utility.Wait(0.5)/;

							; TODO new sound effect
							LenARM_MorphSound_High.Play(PlayerRef)
							PlayerRef.PushActorAway(PlayerRef, 0.5)
							ResetMorphs()
							;PlayerRef.SetValue(ParalysisAV, 0)
						endif
					endif
				endif
			EndIf
		;Else
		;	Log("skipping due to player in power armor")
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
; Apply the given sliderSet's morphs to the matching BodyGen sliders
; ------------------------
Function SetMorphs(int idxSet, SliderSet sliderSet, float fullMorph)
	int sliderNameOffset = SliderSet_GetSliderNameOffset(idxSet)
	int idxSlider = sliderNameOffset
	int sex = PlayerRef.GetLeveledActorBase().GetSex()
	While (idxSlider < sliderNameOffset + sliderSet.NumberOfSliderNames)
		BodyGen.SetMorph(PlayerRef, sex==ESexFemale, SliderNames[idxSlider], kwMorph, OriginalMorphs[idxSlider] + fullMorph * sliderSet.TargetMorph)
		Log("    setting slider '" + SliderNames[idxSlider] + "' to " + (OriginalMorphs[idxSlider] + fullMorph * sliderSet.TargetMorph) + " (base value is " + OriginalMorphs[idxSlider] + ") (base morph is " + sliderSet.BaseMorph + ") (target is " + sliderSet.TargetMorph + ")")
		If (sliderSet.ApplyCompanion != EApplyCompanionNone)
			SetCompanionMorphs(idxSlider, fullMorph * sliderSet.TargetMorph, sliderSet.ApplyCompanion)
		EndIf
		idxSlider += 1
	EndWhile
EndFunction

bool Function SetMorphsAndReturnTrue(int idxSet, SliderSet sliderSet, float fullMorph)
	SetMorphs(idxSet, sliderSet, fullMorph)
	return true
EndFunction

; ------------------------
; Restore the original BodyGen values for each slider, and set all morphs to 0
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

	;RestoreAllOriginalCompanionMorphs()
EndFunction

; ------------------------
; Increase all sliders by a percentage multiplied with the input
; Does not store the updated sliders' CurrentMorphs
; ------------------------
Function ExtendMorphs(float step)
	Log("extending morphs with: " + step)
	int idxSet = 0

	While (idxSet < SliderSets.Length)
		SliderSet sliderSet = SliderSets[idxSet]
		
		If (sliderSet.NumberOfSliderNames > 0)
			;TODO additive in berekening opnemen
			;TODO lijkt nog steeds verkeerd te gaan => loop logs na
			float newMorph = ((sliderSet.TargetMorph * 100.0) * (1.09 * (1 + step/10))) / 100.0

			SetMorphs(idxSet, sliderSet, newMorph)
		EndIf
		idxSet += 1
	EndWhile
	
	BodyGen.UpdateMorphs(PlayerRef)
EndFunction

; ------------------------
; All companion related logic, still WiP / broken
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
	ApplyAllCompanionMorphsWithSound(0)
EndFunction

Function ApplyAllCompanionMorphsWithSound(float radsDifference)
	Log("ApplyAllCompanionMorphs")
	int idxComp = 0
	While (idxComp < CurrentCompanions.Length)
		BodyGen.UpdateMorphs(CurrentCompanions[idxComp])
		PlayMorphSound(CurrentCompanions[idxComp], radsDifference)
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
	
	;TODO this combined with the ResetMorphs at the end seems to cause random crashes for me
	;most likely because I've been toying around with that other skeleton mod...
	;as long as the player doesn't get fully stripped it seems to work fine
	;allSlots.Add(3)
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

	Debug.MessageBox(LL_FourPlay.StringJoin(items, "\n"))
EndFunction

; ------------------------
; Play a sound depending on the rads difference and the MCM settings
; ------------------------
Function PlayMorphSound(Actor akSender, float radsDifference)
	; don't try to play sounds on startup
	if (!IsStartingUp)
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
	endif
EndFunction

; ------------------------
; Debug functions from the Debug MCM menu
; ------------------------
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
	; END: MCM values

	int NumberOfSliderNames
	int NumberOfUnequipSlots

	float BaseMorph
	float CurrentMorph
		
	bool IsMaxedOut
EndStruct