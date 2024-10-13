; HOW THIS MOD STARTS:
; You have the compiled LenARM:LenARM_Main.psx in your FO4/Data/Scripts folder.
; You have the LenA_RadMorphing.esp enabled in your mod loader.
; The .esp triggers the quest on game load, which in return runs this script file as it were an actual quest.
; With the generic OnQuestInit() and OnQuestShutdown() entry points we do the remaining setup and start the actual logic.
Scriptname LenARM:LenARM_Main extends Quest

;TODO de resterende wijzigingen van LenAnderson:
;https://github.com/LenAnderson/LenA_RadMorphing/compare/4cccf04..334a699

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

float UpdateDelay

float LowRadsThreshold
float MediumRadsThreshold
float HighRadsThreshold

float CurrentRads

; [OBSOLETE]
bool HasDoctorOnlySliders
float TotalRads

; has the player reached the max on all sliderSets? this includes additive morphing if these are limited
bool HasReachedMaxMorphs

bool EnablePopping
int PopStates
bool PopShouldParalyze
int PopStripState
bool PopUseFullSounds
; how many pop warnings have we displayed
int PopWarnings
bool IsPopping

bool TutorialDisplayed_DroppedClothes = false
bool TutorialDisplayed_MaxedOutMorphs = false
bool TutorialDisplayed_Popped = false

; does player have bloating suit equipped?
bool hasBloatingSuitEquipped = false
bool canGiveBloatingSuitAmmo = true

; does player have (or has had) molecow disease?
bool hasHadMoleCowDisease = false
; does player have nipple blockers equipped?
bool hasNippleBlockers = false

; do we want to force a morphs update during next run even if there has been no rads changes?
bool forceUpdate = false

Actor:WornItem[] PoppingUnequippedItems

; [OBSOLETE]
int MaxRadiationMultiplier

bool EnableRadsPerks
int CurrentRadsPerk
int CurrentBalloonsPerk

; HeliumBalloon shenenigens
int carriedBalloons = 0

FormList DD_FL_All

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
	Sound Property LenARM_SwellPopSound Auto Const
	Sound Property LenARM_PrePopSound Auto Const
	Sound Property LenARM_PrePopMessySound Auto Const
	Sound Property LenARM_PopSound Auto Const
	Sound Property LenARM_PopMessySound Auto Const
	Sound Property LenARM_PurgeFailSound Auto Const
	Sound Property LenARM_FullGroanSound Auto Const
	Sound Property LenARM_BloatSuitMilkSound Auto Const
	Sound Property LenARM_BalloonTriggerSound Auto Const
	Sound Property LenARM_NPCPopComment Auto Const

	Message Property LenARM_DropClothesMessage Auto
	Message Property LenARM_MaxedOutMorphsMessage Auto
	Message Property LenARM_MaxedOutMorphsWithPoppingMessage Auto
	Message Property LenARM_PopWarning0Message Auto
	Message Property LenARM_PopWarning1Message Auto
	Message Property LenARM_PopWarning2Message Auto
	Message Property LenARM_PopMessage Auto
	Message Property LenARM_RadPurgeFailureMessage Auto
	Message Property LenARM_RadPurgePopFailureMessage Auto
	Message Property LenARM_RadPurgeSuccessMessage Auto
	Message Property LenARM_Tutorial_DropClothesMessage Auto
	Message Property LenARM_Tutorial_MaxedOutMorphsMessage Auto
	Message Property LenARM_Tutorial_MaxedOutMorphsWithPoppingMessage Auto
	Message Property LenARM_Tutorial_PoppedMessage Auto
	Message Property LenARM_BloatingAgentInjectedMessage Auto
	Message Property LenARM_BloatingAgentMissingMessage Auto
	Message Property LenARM_BloatingSuitMissingMessage Auto
	Message Property LenARM_MoleCowMilkTriggerMessage Auto
	Message Property LenARM_BalloonTriggerMessage Auto

	Perk[] Property RadsPerkArray Auto
	Perk Property RadsPerkFull Auto
	
	Perk[] Property BalloonsPerkArray Auto

	ActorValue Property ParalysisAV Auto Const
	ActorValue Property LuckAV Auto Const
	Potion Property GlowingOneBlood Auto Const
	Potion Property PoppedPotion Auto Const	
	Potion Property ResetMorphsExperimentalPotion Auto Const	
	Potion Property ResetMorphsPotion Auto Const
	Potion Property ResetRadsPotion Auto Const
	Potion Property BloatSuitInjectAgent Auto Const
	Potion Property BloatSuitPoppedNPCBuff Auto Const

	Spell Property MoleCowMilkSpell Auto Const
	MagicEffect Property LenARM_MS19MoleratEffect Auto Const
	
	Form Property BloatNPCPopExplosion Auto
	Form Property BloatGrenadeExplosion Auto
	Form Property BloatingSuit Auto
	
	Ammo Property ThirstZapperBloatAmmo Auto Const
	Ammo Property ThirstZapperBloatAmmo_Concentrated Auto Const	
	
	FormList Property MoleCowMilkTriggers Auto
	FormList Property NippleBlockers Auto
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
	return "DG 0.8.0.0"; 2024-09-06 10:10 UTC+2
EndFunction

; ------------------------
; On equipping / ingestion of an item, check if we must do something with it
; ------------------------
Event Actor.OnItemEquipped(Actor akSender, Form akBaseObject, ObjectReference akReference)
	If (PlayerRef.IsInPowerArmor())
		return
	EndIf

	; only check if we need to unequip anything when we equip clothing or armor and are not in power armor
	If (akBaseObject as Armor)
		; if player didn't had any nipple blockers equipped but now has, set the bool to true
		if (!hasNippleBlockers && NippleBlockers.Find(akBaseObject) > -1)
			;Note("nippleblocker found")
			hasNippleBlockers = true

			; force update morphs on next run
			forceUpdate = true
		endif

		; Log("Actor.OnItemEquipped: " + akBaseObject.GetName() + " (" + akBaseObject.GetSlotMask() + ")")
		Utility.Wait(1.0)
		TriggerUnequipSlots()
	endif

	; if player doesn't had molecow disease yet but has the magic effect, set the bool to true
	if (hasHadMoleCowDisease == false && PlayerRef.HasMagicEffect(LenARM_MS19MoleratEffect))
		hasHadMoleCowDisease = true
	endif

	; when ingesting consumable check if we're suffering from molecow disease and it is one of the triggers
	if (akBaseObject as Potion && PlayerRef.HasMagicEffect(LenARM_MS19MoleratEffect) && MoleCowMilkTriggers.Find(akBaseObject) > -1)
		LenARM_MoleCowMilkTriggerMessage.Show()
		MoleCowMilkSpell.Cast(PlayerRef as ObjectReference, PlayerRef as ObjectReference)
	endif
EndEvent

; ------------------------
; On equipping / ingestion of an item, check if we must do something with it
; ------------------------
Event Actor.OnItemUnequipped(Actor akSender, Form akBaseObject, ObjectReference akReference)
	If (PlayerRef.IsInPowerArmor())
		return
	EndIf

	If (akBaseObject as Armor && hasNippleBlockers && NippleBlockers.Find(akBaseObject) > -1)
		;Note("nippleblocker found")
		hasNippleBlockers = false

		; force update morphs on next run
		forceUpdate = true
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

	;TODO kzie dat LenAnderson hier nog meer doet, naast dat ie het anders heeft opgezet:
	;https://github.com/LenAnderson/LenA_RadMorphing/compare/4cccf04..334a699#diff-cf41e4f3e45042dd90f3c9900096513df3b291d27c44417a55a129897c412ab1
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
	ElseIf (tid == ETimerDelayPop)
		TryPop()
	ElseIf (tid == ETimerBloatSuit)
		BloatSuitGiveAmmo()
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

		; get duration from MCM
		UpdateDelay = MCM.GetModSettingFloat("LenA_RadMorphing", "fUpdateDelay:General")
		
		; get radiation threshold (currently used for morph sounds)
		; the division by 1000 is needed as rads run from 0 to 1, while the MCM settings are in displayed rads for player's convenience
		LowRadsThreshold = MCM.GetModSettingFloat("LenA_RadMorphing", "fLowRadsThreshold:General") / 1000.0
		MediumRadsThreshold = MCM.GetModSettingFloat("LenA_RadMorphing", "fMediumRadsThreshold:General") / 1000.0
		HighRadsThreshold = MCM.GetModSettingFloat("LenA_RadMorphing", "fHighRadsThreshold:General") / 1000.0

		EnablePopping = MCM.GetModSettingBool("LenA_RadMorphing", "bEnablePopping:General")
		PopStates = MCM.GetModSettingInt("LenA_RadMorphing", "iPopStates:General")
		PopShouldParalyze = MCM.GetModSettingBool("LenA_RadMorphing", "bPopShouldParalyze:General")
		PopStripState = MCM.GetModSettingInt("LenA_RadMorphing", "iPopStripState:General")
		PopUseFullSounds = MCM.GetModSettingBool("LenA_RadMorphing", "bPopUseFullSounds:General")

		MaxRadiationMultiplier = MCM.GetModSettingInt("LenA_RadMorphing", "iMaxRadiationMultiplier:General")
		
		EnableRadsPerks = MCM.GetModSettingBool("LenA_RadMorphing", "bEnableRadsPerks:General")

		; check for DD
		If (Game.IsPluginInstalled("Devious Devices.esm"))
			Log("found DD")
			DD_FL_All = Game.getFormFromFile(0x0905E95B, "Devious Devices.esm") as FormList
		EndIf

		; start listening for equipping items
		RegisterForRemoteEvent(PlayerRef, "OnItemEquipped")
		RegisterForRemoteEvent(PlayerRef, "OnItemUnequipped")

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

		; set up lists
		PoppingUnequippedItems = new Actor:WornItem[0]

		; reset unequip stack
		UnequipStackSize = 0

		; reapply base morphs for the doctor-only reset morphs
		int idxSet = 0
		While (idxSet < SliderSets.Length)
			SliderSet sliderSet = SliderSets[idxSet]
			;TODO hier ook bepalen wat de laagste min slider is
			;TODO hier ook bepalen wat de hoogste max slider is

			If (GetOnlyDoctorCanReset(sliderSet) && GetIsAdditive(sliderSet))
				HasDoctorOnlySliders = true
				if (sliderSet.BaseMorph > 0)
					Log("reload sliderset " + idxSet)
					SetMorphs(idxSet, sliderSet, sliderSet.BaseMorph)
				endif
			endif

			idxSet += 1
		EndWhile

		; when we don't use sliders that are doctor-only reset, reset the totalRads and possible radperks
		if (!HasDoctorOnlySliders)			
			TotalRads = 0
			CurrentRadsPerk = 0
		endif

		BodyGen.UpdateMorphs(PlayerRef)

		; recalculate the rad perks when enabed
		if (EnableRadsPerks)			
			ApplyRadsPerk()		
			ApplyBalloonsPerk()
		; else clear any existing perks
		Else
			ClearAllRadsPerks(PlayerRef)
			ClearAllBalloonsPerks(PlayerRef)
		endif

		; start timer
		TimerMorphTick()

		BloatSuitGiveAmmo()

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

		; stop timers
		CancelTimer(ETimerMorphTick)
		CancelTimer(ETimerBloatSuit)
	
		; stop listening for equipping items
		UnregisterForRemoteEvent(PlayerRef, "OnItemEquipped")
		
		; stop listening for combat state changes
		UnregisterForRemoteEvent(PlayerRef, "OnCombatStateChanged")
	
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
		; 	SliderSet sliderSet = SliderSets[idxSet]
		; 	If (GetOnlyDoctorCanReset(sliderSet)&& GetIsAdditive(sliderSet))
		; 		sliderSet.BaseMorph = sliderSet.CurrentMorph
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
EndFunction

; ------------------------
; Radiation detection and what not. Doesn't work with god mode (TGM), but works fine with invulnerability mode (TIM).
; ------------------------
float Function GetNewRads()
	float newRads = PlayerRef.GetValue(Rads)
	return newRads / 1000
EndFunction

; ------------------------
; Timer-based morphs
; ------------------------
Function TimerMorphTick()
	; if player is currently popping, we are starting up, player is in Power Armor or player is dead, restart timer and do nothing
	if (IsPopping || IsStartingUp || PlayerRef.IsInPowerArmor() || PlayerRef.IsDead())		
		StartTimer(UpdateDelay, ETimerMorphTick)
		return
	endif

	; setup the raw morphs percentage
	float rawMorphInput = 0

	; modify raw morphs percentage by carried balloons
	float balloonsMorph = CheckCarriedBalloons()
	rawMorphInput += balloonsMorph

	; get the player's current Rads
	; note that the rads run from 0 to 1, with 1 equaling 1000 displayed rads
	float newRads = GetNewRads()

	; modify raw morphs percentage by current rads
	rawMorphInput += newRads

	;TODO theorie is dat door rawMorphInput te gebruiken ipv newRads je dan morphs van beide kan optellen
	; Note("total rads: " + newRads + " + balloons: " + balloonsMorph + " = raw morph input: " + rawMorphInput)

	; if rads haven't changed, restart timer and do nothing
	; skipped if have forceUpdate = true
	If (!forceUpdate && newRads == CurrentRads)
		StartTimer(UpdateDelay, ETimerMorphTick)
		return
	endif

	; calculate the amount of rads taken
	; the longer the timer interval, the larger this will be
	float radsDifference = newRads - CurrentRads
	Log("rads taken: " + (radsDifference * 1000))
	
	CurrentRads = newRads

	; when we have no doctor-only reset sliders, TotalRads should always match our current rads
	if (!HasDoctorOnlySliders)
		TotalRads = newRads
	; if we do have doctor-only reset sliders, only update TotalRads if it is an increase in rads
	elseif (radsDifference > 0)
		TotalRads += radsDifference
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

		; only use sliderSets which have actual entries
		If (sliderSet.NumberOfSliderNames > 0)
			float calculatedMorphPercentage = CalculateMorphPercentage(newRads, sliderSet)

			; only try to apply the morphs if either
			; - the new morph is larger then the slider's current morph
			; - the new morph is unequal to the slider's current morph when slider isn't doctor-only reset
			; - we want to force update the morphs
			; all on one line as Papyrus doesn't understand newLines in if conditions apparently...
			If (calculatedMorphPercentage > sliderSet.CurrentMorph || (!GetOnlyDoctorCanReset(sliderSet) && calculatedMorphPercentage != sliderSet.CurrentMorph) || forceUpdate)
				; by default the morph we will apply is the calculated morph, with the max morph being 1.0
				; both will get modified if we have additive morphs enabled for this sliderSet
				float morphPercentage = calculatedMorphPercentage
				float maxMorphPercentage = 1.0

				; when we have additive morphs active for this slider, add the BaseMorph to the calculated morph
				; limit this to the lower of the calculated morph and the additive morph limit when we use additive morph limit
				If (GetIsAdditive(sliderSet))
					morphPercentage += sliderSet.BaseMorph
					If (GetHasAdditiveLimit(sliderSet))
						maxMorphPercentage = (1.0 + GetAdditiveLimit(sliderSet))
						morphPercentage = Math.Min(morphPercentage, maxMorphPercentage)
					EndIf
				EndIf
				
				;Log("    test " + idxSet + " morphPercentage: " + morphPercentage + "; maxMorphPercentage: " + maxMorphPercentage+ "; HasReachedMaxMorphs: " + HasReachedMaxMorphs+ "; sliderSet.OnlyDoctorCanReset: " + sliderSet.OnlyDoctorCanReset + "; sliderSet.IsMaxedOut: " + sliderSet.IsMaxedOut + "; radsDifference: " + radsDifference)

				; when we have an additive slider with no limit, apply the morphs without further checks
				if (GetIsAdditive(sliderSet)&& !GetHasAdditiveLimit(sliderSet))
					changedMorphs = SetMorphsAndReturnTrue(idxSet, sliderSet, morphPercentage)
				; when we have a limited slider, only actually apply the morphs if they are less then/equal to our max allowed morphs and either:
				ElseIf (morphPercentage <= maxMorphPercentage)
					; - sliderSet is doctor-only reset and the sliderset isn't maxed out
					if (GetOnlyDoctorCanReset(sliderSet) && !sliderSet.IsMaxedOut)
						changedMorphs = SetMorphsAndReturnTrue(idxSet, sliderSet, morphPercentage)
						
						; when the morphs are maxed out, set this on the sliderSet
						if (morphPercentage == maxMorphPercentage)
							sliderSet.IsMaxedOut = true
						; when the morphs are not maxed out, set this on the sliderSet
						else
							sliderSet.IsMaxedOut = false
						endif								
					; - sliderSet is not doctor-only reset and either the sliderset isn't maxed out or the rads are negative
					; the only difference here is that we also want affect the global HasReachedMaxMorphs variable in this case
					elseif (!GetOnlyDoctorCanReset(sliderSet) && (!sliderSet.IsMaxedOut || radsDifference < 0))
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
			ElseIf (GetIsAdditive(sliderSet))
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
			CalculateAndPlayMorphSound(PlayerRef, radsDifference)
		endif
		TriggerUnequipSlots()
	endif

	; when we have reached max morphs and have taken positive rads, perform additional actions
	If (maxedOutMorphs && radsDifference > 0)
		; when not yet displayed the max morphs, display the message and set the global variable that we have displayed the max morphs message
		; also play a sound effect if we have it
		if (!HasReachedMaxMorphs)
			if (!IsStartingUp)
				if (EnablePopping)
					LenARM_MaxedOutMorphsWithPoppingMessage.Show()
				else
					LenARM_MaxedOutMorphsMessage.Show()
				endif
				PlayMorphSound(PlayerRef, 4)
			endif
			HasReachedMaxMorphs = true

			if (!TutorialDisplayed_MaxedOutMorphs)
				TutorialDisplayed_MaxedOutMorphs = true
				if (EnablePopping)
					LenARM_Tutorial_MaxedOutMorphsWithPoppingMessage.ShowAsHelpMessage("LenARM_Tutorial_MaxedOutMorphsWithPoppingMessage", 8, 0, 1)
				else
					LenARM_Tutorial_MaxedOutMorphsMessage.ShowAsHelpMessage("LenARM_Tutorial_MaxedOutMorphsMessage", 8, 0, 1)
				endif
			endif
		
		; when popping is enabled, randomly on taking rads increase the PopWarnings
		; when PopWarnings eventually has reached three, 'pop' the player
		Elseif (EnablePopping && !IsStartingUp)
			CheckPopWarnings()
		endif
	EndIf

	; reset forceUpdate to false when it was true
	if (forceUpdate)
		forceUpdate = false
	endif

	; recalculate which radsPerk to apply when enabled
	; do after we have updated everything else
	if (EnableRadsPerks)
		ApplyRadsPerk()
		ApplyBalloonsPerk()
	endif

	; only restart the timer if we aren't shutting down, so it doesn't try to perform updates when the mod is in the process of stopping
	If (!IsShuttingDown)
		StartTimer(UpdateDelay, ETimerMorphTick)
	endif
EndFunction

float Function CheckCarriedBalloons()
	if (!hasHadMoleCowDisease)
		return 0
	; when player has (or has had) molecow disease check our carried balloons
	else
		;TODO je kan ook kijken of de ESP erin hangt
		;Game.IsPluginInstalled("xxx.esp")
		; get amount of carried balloons from HeliumBalloon.esp
		; float result = 0

		int newCarriedBalloons = (Game.GetFormFromFile(0x027858, "HeliumBalloon.esp") as GlobalVariable).getValueInt()
		if (carriedBalloons != newCarriedBalloons) 
			; we are interested in the carried balloons in intervals of 10
			int currentCount = (carriedBalloons / 10)
			int newCount = (newCarriedBalloons / 10)

			;result = carriedBalloons / 10

			; always force a morphs update when the carried balloon count changes
			; this goes both ways (carrying both more or less balloons then currently)
			if (currentCount != newCount)
				forceUpdate = true
			endif

			; when we carry more balloons then before display a message
			if (newCount > currentCount)
				LenARM_BalloonTriggerMessage.Show()
				LenARM_BalloonTriggerSound.Play(PlayerRef)
			endif

			carriedBalloons = newCarriedBalloons
		endif
		
		;if (forceUpdate)
		return carriedBalloons * 0.002
		;else
		;	return 0
		;endif
	endif
EndFunction

; ------------------------
; Slider set overrides
; ------------------------

;TODO voor nu werken deze zoals eerst; kmoet al die bool (en float) vars erin hangen samen met de enum, en in de configs hangen
bool Function GetOnlyDoctorCanReset(SliderSet sliderSet)
	; If (OverrideOnlyDoctorCanReset != EOverrideBoolNoOverride)
	; 	return OverrideOnlyDoctorCanReset == EOverrideBoolTrue
	; Else
		return sliderSet.OnlyDoctorCanReset
	; EndIf
EndFunction

bool Function GetIsAdditive(SliderSet sliderSet)
	; If (OverrideIsAdditive != EOverrideBoolNoOverride)
	; 	return OverrideIsAdditive == EOverrideBoolTrue
	; Else
		return sliderSet.IsAdditive
	; EndIf
EndFunction

bool Function GetHasAdditiveLimit(SliderSet sliderSet)
	; If (OverrideHasAdditiveLimit != EOverrideBoolNoOverride)
	; 	return OverrideHasAdditiveLimit == EOverrideBoolTrue
	; Else
		return sliderSet.HasAdditiveLimit
	; EndIf
EndFunction

float Function GetAdditiveLimit(SliderSet sliderSet)
	; If (OverrideHasAdditiveLimit != EOverrideBoolNoOverride)
	; 	return OverrideAdditiveLimit
	; Else
		return sliderSet.AdditiveLimit
	; EndIf
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
	float morphBonus = 0.0

	; apply permanent breast size increase for various reasons (can stack)
	if (SliderNames[idxSlider] == "DoubleMelon")
		; player has (or has had) molecow disease
		if (hasHadMoleCowDisease)
			morphBonus += 0.25	

			; player also carries many balloons
			if (carriedBalloons >= 10)
				; for each 10 more balloons the buff becomes larger
				float balloonBonus = 0.125 * (carriedBalloons / 10)

				morphBonus += balloonBonus
			endif
		endif
		; player has bloating suit equipped
		if (hasBloatingSuitEquipped)
			morphBonus += 0.1	
		endif
		; player has nipple piercing equipped
		if (hasNippleBlockers)
			morphBonus += 0.1
		endif
	endif

	return (OriginalMorphs[idxSlider] + morphBonus + (morphPercentage * targetMorph))
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

	; reset the total rads
	TotalRads = 0

	; reset the rad perks
	ClearAllRadsPerks(PlayerRef)

	; reset saved morphs in SliderSets
	int idxSet = 0
	While (idxSet < SliderSets.Length)
		SliderSet sliderSet = SliderSets[idxSet]
		sliderSet.BaseMorph = 0.0
		sliderSet.CurrentMorph = 0.0
		sliderSet.IsMaxedOut = false
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
EndFunction

; ------------------------
; Take given chance, subtract player's Luck, roll a dice, and return whether the dice is lower then the chance
; ------------------------
bool Function ShouldPop(int popChance)
	int random = Utility.RandomInt(1, 10)
	int playerLuck = PlayerRef.GetValue(LuckAV) as int

	; player's Luck stat can decrease chance of popping
	; take player luck, subtract 1, divide by 3 while rounding down
	; we do the luck - 1 so a luck of 1 doesn't always give a minimum boost of 1
	; ie luck of 1 becomes 0, luck 3 becomes 1, luck of 10 becomes 3
	int luckMod = ((playerLuck-1) / 3) * -1
	; molecow disease increase chance of popping (breasts are already pre-bloated)
	int moleCowDiseaseMod = hasHadMoleCowDisease as int
	; nipple blockers increase chance of popping (can't lactate easily to relief pressure)
	int nippleBlockersMod = hasNippleBlockers as int
	; carrying more then 30 balloons increase chance of popping (breasts are already pre-bloated)
	int balloonsMod = 0
	if ((carriedBalloons / 10) > 3)
		balloonsMod = 1
	endif

	; bloating suit equipped decrease chance of popping (milkers provide relief)
	int bloatSuitMod = (hasBloatingSuitEquipped as int)*-1

	;Note("luck " + luckMod + "; molecow " + moleCowDiseaseMod + "; nipple " + nippleBlockersMod + "; suit " + bloatSuitMod)

	; base pop chance is X/10, but X can be modified by above modifiers
	; depending on X and modifiers it can become 0 or less, so cap it to a minimum of 1
	int modifiedPopChance = popChance + luckMod + moleCowDiseaseMod + nippleBlockersMod + balloonsMod + bloatSuitMod
	if (modifiedPopChance < 1)
		modifiedPopChance = 1
	endif

	; when the dice value is lower then (modified) pop chance, return true
	; else return false
	bool shouldPop = random <= modifiedPopChance
	return shouldPop
EndFunction

; ------------------------
; Roll a dice whether to increase the PopWarnings by 1, with various effects on a success
; ------------------------
Function CheckPopWarnings()
	;TODO komt hier langs na startup, en kan dus dan popstates increasen
	;komt vermoelijk als je rads hebt als ie startup moet doen => Timer ziet dat als rads increase => triggered deze functie

	; 30% base chance to trigger
	bool shouldPop = ShouldPop(3)

	; when enabled, always play the dedicated sounds even if we don't trigger
	if (PopUseFullSounds)
		LenARM_FullGroanSound.Play(PlayerRef)
	endif

	; when the dice decides we should not pop, return unless when we have a forceUpdate
	; we are already close to popping so any forced update of the morphs triggers the next pop warning
	if (!shouldPop && !forceUpdate)
		return
	endif

	if (PopWarnings == 0)
		LenARM_PopWarning0Message.Show()
		PopWarnings += 1
		ExtendMorphs(0.25, shouldPop = false, soundId = 2)
	ElseIf (PopWarnings == 1)
		LenARM_PopWarning1Message.Show()
		PopWarnings += 1
		ExtendMorphs(0.5, shouldPop = false, soundId = 3)
	ElseIf (PopWarnings == 2)
		LenARM_PopWarning2Message.Show()
		PopWarnings += 1
		ExtendMorphs(0.75, shouldPop = false, soundId = 4)
	Else
		; IsPopping = true
		TryPop()
	endif
EndFunction

; so we can access it from the sub-scripts
bool Function IsPoppingEnabled()
	return EnablePopping
EndFunction

; ------------------------
; Safety net so popping doesn't break NPC conversations or VATS
; ------------------------
Function TryPop()
	var isInVATS = (Game.IsMovementControlsEnabled()) == false
	var isInScene = PlayerRef.IsInScene()
	var isInTrade = Utility.IsInMenuMode()

	; player should not be in VATS, not be in a conversation and not be trading
	If (!isInVATS && !isInScene && !isInTrade)
		Pop()
	; if so, put on the queue and retry after a second
	Else
		StartTimer(1, ETimerDelayPop)
	EndIf
EndFunction

; ------------------------
; Paralyze the player, expand current morphs several times, reset the morphs, apply debuff, and unparalyze the player
; ------------------------
Function Pop()
	; don't pop player that is dead
	if (PlayerRef.IsDead())
		return
	endif

	int currentPopState = 1

	IsPopping = true

	LenARM_PopMessage.Show()
	Log("pop!")

	; force third person camera when we paralyze the player
	if (PopShouldParalyze)
		Game.ForceThirdPerson()							
	endif
	Utility.Wait(0.5)

	; reset rads in case player is in a high-rads zone
	PlayerRef.EquipItem(ResetRadsPotion, abSilent = true)

	; play the full sound for player
	PlayMorphSound(PlayerRef, 4)
	; then paralyse player and then knock them out
	; the order of first paralysing and then knocking out is important, lest you get odd glitches
	if (PopShouldParalyze)
		ParalyzeActor(PlayerRef)
	endif
	Utility.Wait(0.7)

	; gradually increase the morphs and unequip the clothes
	While (currentPopState < PopStates)			
		; stop if player has died
		if (PlayerRef.IsDead())
			return
		endif

		ExtendMorphs(currentPopState, shouldPop = false)

		; for the unequip state we also want to strip all clothes and armor
		If (currentPopState == PopStripState)
			UnequipAll()
		endif

		;Utility.Wait(0.7)
		Utility.Wait(0.3)

		currentPopState += 1
	EndWhile
	
	; stop if player has died
	if (PlayerRef.IsDead())
		return
	endif

	; apply the final morphs, and do the 'pop', resetting all the morphs back to 0
	ExtendMorphs(currentPopState, shouldPop = true)

	; apply the debuffs on the player and reset the player's rads by ingesting the respective potions
	PlayerRef.EquipItem(PoppedPotion, abSilent = true)
	PlayerRef.EquipItem(ResetRadsPotion, abSilent = true)

	; unset the IsPopping flag before we undo the paralysing
	IsPopping = false
		
	if (!TutorialDisplayed_Popped)
		TutorialDisplayed_Popped = true
		LenARM_Tutorial_PoppedMessage.ShowAsHelpMessage("LenARM_Tutorial_PoppedMessage", 8, 0, 1)
	endif
				
	; wait a bit before we can actually stand up again
	if (PopShouldParalyze)
		Utility.Wait(1.5)

		UnParalyzeActor(PlayerRef)

		;TODO make configurabel
		;ReEquipAll()
	endif
EndFunction

; ------------------------
; Increase all sliders by a percentage multiplied with the input for the player, and play the sound with given id (default Swell sound)
; Does not store the updated sliders' CurrentMorphs, as we will call ResetMorphs afterwards anyway
; ------------------------
Function ExtendMorphs(float step,  bool shouldPop, int soundId = 5)
	Log("extending morphs with: " + step)

	; calculate the new morphs multiplier
	float multiplier = CalculateExtendMorphs(step)

	int idxSet = 0
	; apply it to all morphs from slidersets which aren't excluded
	While (idxSet < SliderSets.Length)
		SliderSet sliderSet = SliderSets[idxSet]		
		If (sliderSet.NumberOfSliderNames > 0 && !sliderSet.ExcludeFromPopping)
			SetMorphs(idxSet, sliderSet, multiplier)
		EndIf
		idxSet += 1
	EndWhile
	
	if (shouldPop)
		; apply the final morphs, and do the 'pop', resetting all the morphs back to 0
		; for this situation we do want to wait for the sound effect to finish playing
		BodyGen.UpdateMorphs(PlayerRef)
		LenARM_PrePopSound.PlayAndWait(PlayerRef)
		LenARM_PopSound.Play(PlayerRef)
		ResetMorphs()	
	else
		; then apply the morphs (with sound) to the player
		BodyGen.UpdateMorphs(PlayerRef)
		PlayMorphSound(PlayerRef, soundId)
	endif
EndFunction

float Function CalculateExtendMorphs(float step)	
	; calculate the new morphs multiplier
	float multiplier = 1.0 + (step/8)

	return multiplier
EndFunction


; ------------------------
; Increase all sliders by a percentage multiplied with the input for the given actor.
; Intended for use on NPCs.
; ------------------------
Function BloatActor(Actor akTarget, int currentBloatStage, int toAdd, bool isConcentrated)
	; don't bloat actor that is dead
	if (akTarget.IsDead())
		return
	endif

	; calculate the max bloatStage, limited to 6
	int maxBloatStage = currentBloatStage + toAdd
	if (maxBloatStage > 6)
		maxBloatStage = 6
	endif
	int nextBloatStage = currentBloatStage + 1
	float morphPercentage = 0.2

	; when actor should get bloated to popping, always paralyze first
	if (toAdd > 5)		
		ParalyzeActor(akTarget)
	endIf

	; keep bloating the actor until the bloatStage is equal to expected result
	while (nextBloatStage <= maxBloatStage)
		ApplyBloatStage(akTarget, nextBloatStage, morphPercentage, isConcentrated)
		
		nextBloatStage += 1
	endwhile
EndFunction

Function ApplyBloatStage(Actor akTarget, int nextBloatStage, float morphPercentage, bool isConcentrated = false)
	;TODO zoek na of je dit ergens kan standardizeren, echter heb ik er weinig hoop op
	; de andere twee plekken zijn SetMorphs en SetCompanionMorphs en die doen dingen in die loop specifiek voor player en companions

	; perkLevel is equal to the bloat state 
	int perkLevel = nextBloatStage

	; limit to 5 just in case (we have 5 perks, starting from 0)
    If (perkLevel > 5)
        perkLevel = 5
    EndIf

	; compare current akTarget radsPerk level vs the new level, change perks if needed
	if (GetCurrentRadsPerkLevel(akTarget) != perkLevel)
		ClearOldRadsPerks(akTarget, perkLevel)
		; grab the perk from the array if we aren't on maxed out morphs, else use the dedicated perk
		if (perkLevel != 5)
			akTarget.AddPerk(RadsPerkArray[perkLevel])		
		Else
			akTarget.AddPerk(RadsPerkFull)			
		endif
	endif

	; do a random delay before appying the morphs (and morph sounds) on the akTarget
	; float randomFloat = GetRandomDelay(2,3)
	float randomFloat = GetRandomDelay(1,2)
	Utility.Wait(randomFloat)

	; only apply initial morphs if we are not going to pop
	if (nextBloatStage <= 5)
		SetBloatMorphs(akTarget, morphPercentage, shouldPop = false)
		BodyGen.UpdateMorphs(akTarget)
	endif

	; play the matching sound
	if (perkLevel < 5)
		PlayMorphSound(akTarget, 3)
	elseif (perkLevel == 5 && nextBloatStage == 5)
		PlayMorphSound(akTarget, 4)
	; pop the actor 
	elseif (perkLevel == 5 && nextBloatStage > 5)		
		Utility.Wait(randomFloat)
		BloatPop(akTarget, isConcentrated)
	endif
EndFunction

Function BloatPop(Actor akTarget, bool isConcentrated)
	; when we pop a non-essential hostile enemy, small chance that we pop in a more permanent way
	float messyPopChance = 0.1
	; when hit by concentrated shot the permanent pop chance is much larger
	if (isConcentrated)
		messyPopChance = 0.5
	endif
	bool messyPop = (akTarget != PlayerRef && akTarget.IsHostileToActor(PlayerRef) == true && aktarget.IsEssential() == false && utility.RandomFloat() <= messyPopChance)

	; before we start expanding log the current breasts size
	float npcMorph = BodyGen.GetMorph(akTarget, True, "Breasts", None)
	
	; the bigger the breasts are, the more milk we will add at the end
	; current settings' base morph is 0.5 
	int milkToAdd = 3
	if (npcMorph >= 0.55)
		milkToAdd += 1
	endif
	if (npcMorph >= 0.65)
		milkToAdd += 1
	endif
	if (npcMorph >= 0.80)
		milkToAdd += 1
	endif
	if (npcMorph >= 0.95)
		milkToAdd += 1
	endif
	if (npcMorph >= 1.1)
		milkToAdd += 1
	endif

	; paralyze actor first
	PlayMorphSound(akTarget, 4)
	ParalyzeActor(akTarget)
	
	; add bloating ammo to actor's inventory
	akTarget.AddItem(ThirstZapperBloatAmmo, 1, abSilent = true)

	int currentPopState = 1
	float multiplier = 0.1
	float totalPopMultiplier = 0

	; do a random delay before appying the morphs (and morph sounds) on the akTarget
	float randomFloat = GetRandomDelay(1,2) ;(2,3)
	Utility.Wait(randomFloat)

	int popStatesToUse = PopStates
	; messy pop makes actor bigger as warning for attent player
	if (messyPop)
		popStatesToUse *= 2
		multiplier = 0.15
	endif

	; gradually increase the morphs and unequip the clothes
	While (currentPopState < popStatesToUse)	
		; don't pop actor that is dead
		if (akTarget.IsDead())
			return
		endif
		
		SetBloatMorphs(akTarget, multiplier, shouldPop = true)
		totalPopMultiplier += multiplier
		
		BodyGen.UpdateMorphs(akTarget)
		; play normal swell sound when bloating normally
		if (currentPopState < PopStates)
			PlayMorphSound(akTarget, 5)
		; when we are bloating beyond normal play the alt swell sound 
		else
			PlayMorphSound(akTarget, 6)
		endif

		; add bloating ammo to actor's inventory
		akTarget.AddItem(ThirstZapperBloatAmmo, 1, abSilent = true)

		; for the unequip state we also want to strip all clothes and armor
		If (currentPopState == PopStripState || currentPopState == PopStates )
			UnequipAllNPC(akTarget)
		endif

		Utility.Wait(0.7) ;(0.3) ;(1.0)

		currentPopState += 1
	EndWhile

	; don't pop actor that is dead
	if (akTarget.IsDead())
		return
	endif

	; apply the final morphs, and do the 'pop'
	SetBloatMorphs(akTarget, multiplier, shouldPop = true)				
	totalPopMultiplier += multiplier
	
	BodyGen.UpdateMorphs(akTarget)
	
	; messy pop kills actor and places a grenade explosion
	if (messyPop)
		LenARM_PrePopMessySound.PlayAndWait(akTarget)

		; add some concentrated bloating ammo to actor's inventory when they've been allowed to pop
		; reduce by 3 (capped to min 1) to not give too many freebies
		milkToAdd -= 3
		if (milkToAdd < 1)
			milkToAdd = 1
		endif
		akTarget.AddItem(ThirstZapperBloatAmmo_Concentrated, milkToAdd, abSilent = true)	

		; clear rad perks so we don't keep ambient noise
		ClearAllRadsPerks(akTarget)

		LenARM_PopMessySound.Play(akTarget)
		; spread the joy to nearby NPCs
		akTarget.PlaceAtMe(BloatGrenadeExplosion)	

		; dismember and kill actor
		; sadly no way to give the XP to the player even if we tell the player is the killer
		akTarget.Dismember("Torso", true, true, true)
		akTarget.Kill()
		LenARM_NPCPopComment.Play(PlayerRef)
		
		;LenARM_BloatingAgentInjectedMessage.Show()
		; give player a temp buff if bloating suit is equipped
		if (hasBloatingSuitEquipped)
			PlayerRef.EquipItem(BloatSuitPoppedNPCBuff, abSilent = true)
		endif
	; normal pop keeps actor paralyzed for a bit and places a normal explosion
	else
		LenARM_PrePopSound.PlayAndWait(akTarget)

		; add some more bloating ammo to actor's inventory when they've been allowed to pop
		akTarget.AddItem(ThirstZapperBloatAmmo, milkToAdd, abSilent = true)

		LenARM_PopSound.Play(akTarget)
		; spread the joy to nearby NPCs
		akTarget.PlaceAtMe(BloatNPCPopExplosion)		

		; reset all the morphs back to 0
		; we need to do some calculations so we go back to the original NPC's morphs
		float reset = (1.0 + totalPopMultiplier) * -1

		SetBloatMorphs(akTarget, reset, shouldPop = false)
		BodyGen.UpdateMorphs(akTarget)

		ClearAllRadsPerks(akTarget)
		akTarget.EquipItem(PoppedPotion, abSilent = true)
	endif
EndFunction


Function SetBloatMorphs(Actor akTarget, float morphPercentage, bool shouldPop)	
	int idxSet = 0

	; apply it to all morphs from slidersets which aren't excluded
	While (idxSet < SliderSets.Length)
		SliderSet sliderSet = SliderSets[idxSet]		
		If (sliderSet.NumberOfSliderNames > 0);  && (!shouldPop || (shouldPop && !sliderSet.ExcludeFromPopping)))
			int sliderNameOffset = SliderSet_GetSliderNameOffset(idxSet)
			int idxSlider = sliderNameOffset
			int sex = akTarget.GetLeveledActorBase().GetSex()
			While (idxSlider < sliderNameOffset + sliderSet.NumberOfSliderNames)
				string slider = SliderNames[idxSlider]

				;TODO not the most efficient way tho...	
				float npcMorph = BodyGen.GetMorph(akTarget, True, slider, None)

				float newMorph = npcMorph + (morphPercentage * sliderSet.targetMorph)
				; float newMorph = CalculateMorphs(idxSlider, morphPercentage, sliderSet.TargetMorph)

				; ;TODO debug ding
				; if (slider == "Breasts")
				; 	Log(npcMorph + "; " + morphPercentage + "; " + sliderSet.targetMorph + "; " + newMorph)
				; endif
						
				BodyGen.SetMorph(akTarget, sex==ESexFemale, slider, kwMorph, newMorph)
				idxSlider += 1
			EndWhile
		EndIf
		idxSet += 1
	EndWhile
EndFunction


Function ParalyzeActor(Actor akTarget)
	akTarget.SetValue(ParalysisAV, 1)
	akTarget.PushActorAway(akTarget, 0.5)	
EndFunction

Function UnParalyzeActor(Actor akTarget)
	akTarget.SetValue(ParalysisAV, 0)
EndFunction

; ------------------------
; Check the total accumulated rads, and apply the matching radsPerk to the player
; ------------------------
Function ApplyRadsPerk()
	; when we have 0 rads, clear all existing perks and don't apply a new one
	if (TotalRads == 0)
		ClearAllRadsPerks(PlayerRef)
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

	; when we are on maxed out morphs, use the final perk
	if (HasReachedMaxMorphs)
		perkLevel = 5
	endif

	; when we have enough rads that we should have a difference in perk level, change perks
	if (CurrentRadsPerk != perkLevel)
		ClearOldRadsPerks(PlayerRef, perkLevel)
		; grab the perk from the array if we aren't on maxed out morphs, else use the dedicated perk
		if (perkLevel != 5)
			PlayerRef.AddPerk(RadsPerkArray[perkLevel])		
		Else
			PlayerRef.AddPerk(RadsPerkFull)			
		endif
		
		CurrentRadsPerk = perkLevel
		; enable bloating suit ammo when we switch perks
		canGiveBloatingSuitAmmo = true
	endif
EndFunction

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


; ------------------------
; Check the total carried balloons, and apply the matching balloonsPerk to the player
; ------------------------
Function ApplyBalloonsPerk()
	int currentCount = (carriedBalloons / 10)

	; when we have less then 10 balloons, clear all existing perks and don't apply a new one
	if (currentCount < 1)
		ClearAllBalloonsPerks(PlayerRef)
		return
	endif

	; limit to 3 just in case (we have 3 perks)
    If (currentCount > 3)
        currentCount = 3
    EndIf

	; subtract 1 from our count as the Perks start from 0
	int newBalloonsPerk = currentCount -1
	; when we have enough balloons that we should have a difference in perk level, change perks
	if (CurrentBalloonsPerk != newBalloonsPerk)
		ClearOldBalloonsPerks(PlayerRef, newBalloonsPerk)
		; grab the perk from the array if we aren't on maxed out morphs, else use the dedicated perk
		PlayerRef.AddPerk(BalloonsPerkArray[newBalloonsPerk])		
		
		CurrentBalloonsPerk = newBalloonsPerk
	endif
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
    While (i <= 2)
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

float Function GetRandomDelay(int min = 2, int max = 6)
	return (Utility.RandomInt(min,max) * 0.1) as float
EndFunction

; ------------------------
; Check for each slider whether pieces of clothing / armor should get unequipped
; For more info on usage of the slots: https://www.creationkit.com/fallout4/index.php?title=ArmorAddon
; ------------------------
Function UnequipSlots()
	; don't bother unequipping if player is in power armor
	If (PlayerRef.IsInPowerArmor())
		return
	EndIf

	Log("UnequipSlots (stack=" + UnequipStackSize + ")")
	UnequipStackSize += 1
	If (UnequipStackSize <= 1)
		bool found = false

		int idxSet = 0

		; check if we are currently wearing a full-body suit (ie Hazmat suit)
		; the unequip logic has some issues when wearing full-body suits when unequipping any of the armor slots
		; it keeps trying to unequip the item with each call, but keeps on failing because the full-body suit technically both does and doesn't use the slots
		; the workaround is as follows:
		; - first check what we have equipped in slot 3/4 (body) and 11 (torso armor), as it seems full-body suits cover these two slots
		; we check both slot 3 and 4 as the Far Harbor Diving Suit uses slot 4 instead of the usual 3
		; - do both slots have an item, check if the item in slot 11 has no name
		; for whatever awful reason when a piece of clothing covers both the body and the torso armor slots, it lacks a display name for the armor slots
		; - if all of this is true, then we have a full-body suit, and should not try to strip it

		bool hasFullBodyItem = false
		Actor:WornItem itemSlot3 = PlayerRef.GetWornItem(3)
		Actor:WornItem itemSlot4 = PlayerRef.GetWornItem(4)
		Actor:WornItem itemSlot11 = PlayerRef.GetWornItem(11)

		var itemSlot3_Occupied = itemSlot3 != None && itemSlot3.item != None
		var itemSlot4_Occupied = itemSlot4 != None && itemSlot4.item != None
		var itemSlot11_Occupied = itemSlot11 != None && itemSlot11.item != None

		if ((itemSlot3_Occupied || itemSlot4_Occupied) && itemSlot11_Occupied && itemSlot11.item.GetName() == "")
			hasFullBodyItem = true
		EndIf

		Log(hasFullBodyItem)

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
					
					; check if item in the slot is clothes / armor
					bool isArmor = IsItemArmor(item)
					; we can unequip if we currently aren't wearing a full-body suit, or we are wearing a full-body suit and the slot to unequip is slot 3
					bool canUnequip = (item.item && (!hasFullBodyItem || (hasFullBodyItem && UnequipSlots[idxSlot] == 3)))

					; when item is an armor and we can unequip it, do so
					If (isArmor && canUnequip)
						Log("  unequipping slot " + UnequipSlots[idxSlot] + " (" + item.item.GetName() + " / " + item.modelName + ")")

						PlayerRef.UnequipItem(item.item, false, true)

						; when the item is no longer equipped and we haven't already unequipped anything (goes across all sliders and slots),
						; play the strip sound if available and display a notification in top-left
						If (!found && !PlayerRef.IsEquipped(item.item))
							if (!TutorialDisplayed_DroppedClothes)
								TutorialDisplayed_DroppedClothes = true
								LenARM_Tutorial_DropClothesMessage.ShowAsHelpMessage("LenARM_Tutorial_DropClothesMessage", 8, 0, 1)
							else
								LenARM_DropClothesMessage.Show()
							endif
							LenARM_DropClothesSound.Play(PlayerRef)
							found = true
						EndIf
					EndIf

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
	; don't bother unequipping if player is in power armor
	If (PlayerRef.IsInPowerArmor())
		return
	EndIf
	
	Log("UnequipAll")

	bool found = false
	int idxSlot = 0

	; these are all the slots we want to unequip
	int[] allSlots = new int[0]	
	allSlots.Add(3)  ; body
	allSlots.Add(6)  ; [U] Torso
	allSlots.Add(11) ; [A] Torso
	allSlots.Add(12) ; [A] L Arm
	allSlots.Add(13) ; [A] R Arm
	allSlots.Add(14) ; [A] L Leg
	allSlots.Add(15) ; [A] R Leg

	; check for each slot
	While (idxSlot < allSlots.Length)
		int slot = allSlots[idxSlot]
		
		Actor:WornItem item = PlayerRef.GetWornItem(slot)
		
		; check if item in the slot is not an actor or the pipboy
		bool isArmor = IsItemArmor(item)

		; when item is an armor and we can unequip it, do so
		If (isArmor)
			Log("  unequipping slot " + slot + " (" + item.item.GetName() + " / " + item.modelName + ")")

			;TODO make configurabel
			PoppingUnequippedItems.Add(item);
			PlayerRef.UnequipItem(item.item, false, true)
			
			; when the item is no longer equipped and we haven't already unequipped anything (goes across all slots),
			; play the strip sound if available
			If (!found && !PlayerRef.IsEquipped(item.item))
				LenARM_DropClothesSound.Play(PlayerRef)
				found = true
			EndIf
		EndIf
		
		idxSlot += 1	
	EndWhile
	Log("FINISHED UnequipAll")
EndFunction

Function UnequipAllNPC(Actor akTarget)
	; don't bother unequipping if akTarget is in power armor
	If (akTarget.IsInPowerArmor())
		return
	EndIf

	bool found = false
	int idxSlot = 0

	; these are all the slots we want to unequip
	int[] allSlots = new int[0]	
	allSlots.Add(3)  ; body
	allSlots.Add(11) ; chest armor
	allSlots.Add(12) ; arm armor
	allSlots.Add(13) ; arm armor
	allSlots.Add(14) ; leg armor
	allSlots.Add(15) ; leg armor

	; check for each slot
	While (idxSlot < allSlots.Length)
		int slot = allSlots[idxSlot]
		
		Actor:WornItem item = akTarget.GetWornItem(slot)
		
		; check if item in the slot is not an actor or the pipboy
		bool isArmor = IsItemArmor(item)

		; when item is an armor and we can unequip it, do so
		If (isArmor)
			Log("  unequipping slot " + slot + " (" + item.item.GetName() + " / " + item.modelName + ")")

			akTarget.UnequipItem(item.item, false, true)
			
			; when the item is no longer equipped and we haven't already unequipped anything (goes across all slots),
			; play the strip sound if available
			If (!found && !akTarget.IsEquipped(item.item))
				LenARM_DropClothesSound.Play(akTarget)
				found = true
			EndIf
		EndIf
		
		idxSlot += 1	
	EndWhile
EndFunction

bool Function IsItemArmor(Actor:WornItem item)
	;return (item.item && LL_Fourplay.StringSubstring(item.modelName, 0, 6) != "Actors" && LL_Fourplay.StringSubstring(item.modelName, 0, 6) != "Pipboy")

	; sanity check
	if (!item.item)
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

Function ReEquipAll()
	int idxItem = 0
	While (idxItem < PoppingUnequippedItems.Length)
		Actor:WornItem item = PoppingUnequippedItems[idxItem]
		
		PlayerRef.EquipItem(item.item, false, true)

		idxItem += 1
	EndWhile

	PoppingUnequippedItems = new Actor:WornItem[0]
EndFunction

; ------------------------
; Play a sound depending on the rads difference and the MCM settings
; ------------------------
Function CalculateAndPlayMorphSound(Actor akSender, float radsDifference)
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
		PlayMorphSound(akSender, 1)
	; everything between MediumRadsThreshold and HighRadsThreshold rads taken
	elseif (radsDifference <= HighRadsThreshold)
		Log("  high rads taken")
		PlayMorphSound(akSender, 2)
	; everything above HighRadsThreshold rads taken
	elseif (radsDifference > HighRadsThreshold)
		Log("  very high rads taken")
		PlayMorphSound(akSender, 3)
	endif
EndFunction

; ------------------------
; Bloating Suit inject bloating agent action
; ------------------------
Function SuitInjectBloatingAgent()
	If (PlayerRef.IsEquipped(BloatingSuit))
		int bloatingAmmoCount = PlayerRef.GetItemCount(ThirstZapperBloatAmmo)
		if (bloatingAmmoCount > 0)
			LenARM_BloatingAgentInjectedMessage.Show()
			PlayerRef.EquipItem(BloatSuitInjectAgent, abSilent = true)
			PlayerRef.RemoveItem(ThirstZapperBloatAmmo, 1, abSilent = true)
		else
			;TechnicalNote("No Bloating Ammo!")
			LenARM_BloatingAgentMissingMessage.Show()
		endif
	else
		;TechnicalNote("Bloating Outfit not equipped!")
		LenARM_BloatingSuitMissingMessage.Show()
	endif
EndFunction

Function BloatingSuitEquipped()
	;TechnicalNote("Bloating Outfit equipped!")
	hasBloatingSuitEquipped = true
	
	; force update morphs on next run
	forceUpdate = true
EndFunction

Function BloatingSuitUnequipped()
	;TechnicalNote("Bloating Outfit unequipped!")
	hasBloatingSuitEquipped = false
	
	; force update morphs on next run
	forceUpdate = true
EndFunction

Function BloatSuitGiveAmmo()
	if (!hasBloatingSuitEquipped || !canGiveBloatingSuitAmmo)
		StartTimer(5, ETimerBloatSuit)
		return
	endif

	;TechnicalNote("Bloating Outfit gives ammo!")
	if (CurrentRadsPerk > 0)
		LenARM_BloatSuitMilkSound.Play(PlayerRef)
	endif

	; you won't get anything for the first perk, only from second perk onwards
	if (CurrentRadsPerk == 1)
		PlayerRef.AddItem(ThirstZapperBloatAmmo, 2, abSilent = true)
	elseif (CurrentRadsPerk == 2)
		PlayerRef.AddItem(ThirstZapperBloatAmmo, 3, abSilent = true)
	elseif (CurrentRadsPerk == 3)
		PlayerRef.AddItem(ThirstZapperBloatAmmo, 4, abSilent = true)
	elseif (CurrentRadsPerk == 4)
		PlayerRef.AddItem(ThirstZapperBloatAmmo, 5, abSilent = true)
	elseif (CurrentRadsPerk == 5)
		PlayerRef.AddItem(ThirstZapperBloatAmmo_Concentrated, 1, abSilent = true)
	endif

	canGiveBloatingSuitAmmo = false

	; bit longer timer as we don't switch perks often
	StartTimer(5, ETimerBloatSuit)
EndFunction


; ------------------------
; Play a sound depending on the given id
; 1 = MorphSound_Low
; 2 = MorphSound_Medium
; 3 = MorphSound_High
; 4 = MorphSound_Full
; 5 = MorphSound_Swell
; 6 = MorphSound_SwellPop
; ------------------------
;TODO wellicht omzetten naar losse consts en bovenin definieren en dan gebruiken
Function PlayMorphSound(Actor akSender, int soundId)
	if (soundId == 1)
		LenARM_MorphSound.Play(akSender)
	elseif (soundId == 2)
		LenARM_MorphSound_Med.Play(akSender)
	elseif (soundId == 3)
		LenARM_MorphSound_High.Play(akSender)
	elseif (soundId == 4)
		LenARM_FullSound.Play(akSender)
	elseif (soundId == 5)
		LenARM_SwellSound.Play(akSender)
	elseif (soundId == 6)
		LenARM_SwellPopSound.Play(akSender)
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
		MessageBox("<center><b>! WARNING !</b></center><br><br><p align='justify'>This function does not reset this mod's settings.<br>It will reset the mod's state. This includes the record of the original body shape. If your body is currently morphed by this mod you will be stuck with the current shape.</p><br>Click the button again to reset the mod's state.")
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
		
		CurrentRads = 0.0
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

	;TODO ik dump TotalRads hier ff als test in
	MessageBox((lowestPercentage * 100) + "% ; " + (TotalRads * 1000))
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
	; int Property ETimerFakeRads = 5 Auto Const
	int Property ETimerDelayPop = 6 Auto Const
	int Property ETimerBloatSuit = 7 Auto Const
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

		string[] names = StringSplit(sliderSet.SliderName, "|")
		sliderSet.NumberOfSliderNames = names.Length

		If (sliderSet.UnequipSlot != "")
			string[] slots = StringSplit(sliderSet.UnequipSlot, "|")
			sliderSet.NumberOfUnequipSlots = slots.Length
		Else
			sliderSet.NumberOfUnequipSlots = 0
		EndIf
	Else
		sliderSet.IsUsed = false
	EndIf

	;Log("  " + set)
	return sliderSet
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