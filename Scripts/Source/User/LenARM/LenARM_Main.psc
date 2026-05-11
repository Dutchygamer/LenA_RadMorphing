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

;TODO
; HUDFramework plugin
HUDFramework hud
string Property BloatExposure_Widget = "KillCount.swf" AutoReadOnly

float UpdateDelay

float LowRadsThreshold
float MediumRadsThreshold
float HighRadsThreshold

; all three xxxRads range from 0 (0%) to 1000 (100%)
; the current update cycle's morphs difference 
float CurrentRads
; the current update cycle's bonus morphs from other sources that are not rads or balloons
; [Obsolete]
float BonusRads
; the total morphs
float TotalRads


; [OBSOLETE]
bool HasDoctorOnlySliders

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

bool ForceNPCBloatPopping

bool TutorialDisplayed_DroppedClothes = false
bool TutorialDisplayed_MaxedOutMorphs = false
bool TutorialDisplayed_Popped = false
bool TutorialDisplayed_KitanaMask = false

; does player have bloating suit equipped?
;TODO vervang jou door kijken of we LenARM_BloatingSuitPerk hebben
bool hasBloatingSuitEquipped = false
bool canGiveBloatingSuitAmmo = true
int bloatingSuitPopDetectRadius = 1024 ;768

; does player have kitana mask equipped?
;TODO vervang jou door kijken of we LenARM_KitanaMaskPerk hebben
bool hasKitanaMaskEquipped = false
;TODO zou alleen deze om kunnen zetten naar AV...
int kitanaMaskMessyPoppedCount = 0
int poppingExpert1Requirement = 10
int poppingExpert2Requirement = 25
int kitanaMaskPopDetectRadius = 512 ;384

int kitanaMaskSelfMorphTimer = 10
int kitanaMaskSelfMorphMessyTimer = 30

int maxNPCBloatStages = 5
int popNPCBloatStage = 6 ; should be maxNPCBloatStages + 1

;TODO zou deze om kunnen zetten naar AVs...
; does player have (or has had) molecow disease?
bool hasHadMoleCowDisease = false
; does player have nipple blockers equipped?
bool hasNippleBlockers = false
; does player have moomilk addiction?
bool hasMooMilkAddiction = false
; does player have popping expert perk?
bool isPoppingExpert = false
; has player just popped an NPC with Kitana Mask
; aka give puffy nipples
bool hasKitanaMaskPoppedNPC = false

; do we want to force a morphs update during next run even if there has been no rads changes?
bool forceUpdate = false

Actor:WornItem[] PoppingUnequippedItems

; [OBSOLETE]
int MaxRadiationMultiplier

bool EnableRadsPerks
int CurrentRadsPerk
int CurrentBalloonsPerk

; HeliumBalloon shenenigens
;TODO zou alleen deze om kunnen zetten naar AV...
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
	ActorValue Property avBloating Auto Const

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
	Sound Property LenARM_RadPerkSwitchSound Auto Const
	Sound Property LenARM_SwellSound Auto Const
	Sound Property LenARM_SwellPopSound Auto Const
	Sound Property LenARM_PrePopSound Auto Const
	Sound Property LenARM_PrePopMessySound Auto Const
	Sound Property LenARM_PopSound Auto Const
	Sound Property LenARM_PopMessySound Auto Const
	Sound Property LenARM_PurgeFailSound Auto Const
	Sound Property LenARM_FullGroanSound Auto Const
	Sound Property LenARM_BloatSuitMilkSound Auto Const
	Sound Property LenARM_NPCPopComment Auto Const
	Sound Property LenARM_FXBloatHitSound_High Auto Const

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
	Message Property LenARM_Tutorial_BloatingMaskMessage Auto
	Message Property LenARM_BloatingAgentInjectedMessage Auto
	Message Property LenARM_BloatingAgentMissingMessage Auto
	Message Property LenARM_BloatingSuitMissingMessage Auto
	Message Property LenARM_BloatingMask_KillMessage Auto
	Message Property LenARM_BloatingMask_PeriodicMessage Auto
	Message Property LenARM_BloatingMask_UnsafeUnequipMessage Auto
	Message Property LenARM_BloatingMask_SafeUnequipMessage Auto
	Message Property LenARM_MoleCowMilkTriggerMessage Auto
	Message Property LenARM_MoleCow_BalloonPopTriggerMessage Auto
	Message Property LenARM_BalloonTriggerMessage Auto
	Message Property LenARM_PoppingExpertPerkMessage Auto

	Perk[] Property RadsPerkArray Auto
	Perk Property RadsPerkFull Auto
	
	Perk[] Property BalloonsPerkArray Auto
	
	;TODO in geval de lokale bool random wordt unset
	; Perk Property LenARM_BloatSuitPerk Auto Const
	; Perk Property LenARM_KitanaMaskPerk Auto Const

	Perk Property PoppingExpertPerk1 Auto
	Perk Property PoppingExpertPerk2 Auto
	
	ActorValue Property ParalysisAV Auto Const
	ActorValue Property LuckAV Auto Const
	Potion Property GlowingOneBlood Auto Const
	Potion Property PoppedPotion Auto Const	
	Potion Property ResetMorphsExperimentalPotion Auto Const	
	Potion Property ResetMorphsPotion Auto Const
	; [OBSOLETE]
	Potion Property ResetRadsPotion Auto Const
	Potion Property BloatSuitInjectAgent Auto Const
	Potion Property BloatSuitPoppedNPCBuff Auto Const
	Potion Property BloatMaskPoppedNPCBuff Auto Const

	Spell Property MoleCowMilkSpell Auto Const
	MagicEffect Property LenARM_MS19MoleratEffect Auto Const
	MagicEffect Property MooMilkAddictionEffect Auto Const
	MagicEffect Property MS19SurpressantEffect Auto
	
	Keyword property ActorTypeBloatingAgent auto
	Keyword property ArmorTypeBloatingSuit auto
	
	Form Property BloatNPCPopExplosion Auto
	Form Property BloatGrenadeExplosion Auto
	; [OBSOLETE]
	Form Property BloatingSuit Auto
	Form Property KitanaMask Auto
	
	Ammo Property ThirstZapperBloatAmmo Auto Const
	Ammo Property ThirstZapperBloatAmmo_Concentrated Auto Const	
	
	FormList Property MoleCowMilkTriggers Auto
	FormList Property MoleCowBalloonTriggers Auto
	FormList Property NippleBlockers Auto
	FormList Property AutoAddToPlayerInventory Auto
	
	Quest Property MQ102 Auto ; MQ Out of Time
	Quest Property DN050 Auto ; SQ Quality Assurance
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
		If (MQ102.IsStageDone(6))
			AddItemsToPlayerInventory()
		endif
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
	; only check if we need to unequip anything when we equip clothing or armor and are not in power armor
	If (akBaseObject as Armor && !PlayerRef.IsInPowerArmor())
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

	; when ingesting a consumable and player is suffering from molecow disease without having the suppressant active, check if we need to do something
	if (akBaseObject as Potion && PlayerRef.HasMagicEffect(LenARM_MS19MoleratEffect) && !PlayerRef.HasMagicEffect(MS19SurpressantEffect))
		; if consumable is a milk surge trigger, trigger the milk surge effect
		if (MoleCowMilkTriggers.Find(akBaseObject) > -1)
			LenARM_MoleCowMilkTriggerMessage.Show()
			MoleCowMilkSpell.Cast(PlayerRef as ObjectReference, PlayerRef as ObjectReference)
		; if 'consumable' is a balloon popping, trigger the milk surge effect with a different message
		elseif (MoleCowBalloonTriggers.Find(akBaseObject) > -1)
			LenARM_MoleCow_BalloonPopTriggerMessage.Show()
			MoleCowMilkSpell.Cast(PlayerRef as ObjectReference, PlayerRef as ObjectReference)
		endif
	endif
	
	; if player suffers from mooMilk addiction or gets rid of it with meds, adjust the bool
	if (hasMooMilkAddiction == false && PlayerRef.HasMagicEffect(MooMilkAddictionEffect))
		hasMooMilkAddiction = true
	elseif (hasMooMilkAddiction == true && PlayerRef.HasMagicEffect(MooMilkAddictionEffect) == false)
		hasMooMilkAddiction = false
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

	; when unequipping the Kitana mask check if player has messy popped enough NPCs
	if (akBaseObject as Armor && akBaseObject == KitanaMask)
		; TechnicalNote("main script kitana mask unequipped!")
		; if not, re-equip the mask
		if (PlayerRef.HasPerk(PoppingExpertPerk1) == false)
			KitanaMaskSelfMorph_Unequip()
			PlayerRef.EquipItem(KitanaMask)
		; if so, continue with the unequip and reset the counter
		Else
			CancelTimer(ETimerKitanaMask)
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

	;TODO kzie dat LenAnderson hier nog meer doet, naast dat ie het anders heeft opgezet:
	;https://github.com/LenAnderson/LenA_RadMorphing/compare/4cccf04..334a699#diff-cf41e4f3e45042dd90f3c9900096513df3b291d27c44417a55a129897c412ab1
	; reset player morphs when doctor cures player rads
	; as the base game uses different quests for Doctors then for the Doctors from the DLC, we must check each seperate quest sadly
	If (DialogueGenericDoctors.DoctorJustCuredRads == 1 || DLC03CoA_DialogueNucleusArchemist.DoctorJustCuredRads == 1 || DLC03DialogueFarHarbor.DoctorJustCuredRads == 1 || DLC03AcadiaDialogue.DoctorJustCuredRads == 1 || DLC04SettlementDoctor.DoctorJustCuredRads == 1)
		ResetMorphs()
	EndIf

	; reset player mooMilk addiction flag when flag was true and doctor cures player addictions
	; as the base game uses different quests for Doctors then for the Doctors from the DLC, we must check each seperate quest sadly
	If (hasMooMilkAddiction && (DialogueGenericDoctors.DoctorJustCuredAddict == 1 || DLC03CoA_DialogueNucleusArchemist.DoctorJustCuredAddict == 1 || DLC03DialogueFarHarbor.DoctorJustCuredAddict == 1 || DLC03AcadiaDialogue.DoctorJustCuredAddict == 1 || DLC04SettlementDoctor.DoctorJustCuredAddict == 1))
		hasMooMilkAddiction = false
	EndIf

EndEvent

; ------------------------
; On new game start give out some things
; ------------------------
Event Quest.OnStageSet(Quest akSender, int auiStageID, int auiItemID)
	If (akSender == MQ102 && auiStageID == 6)
		UnregisterForRemoteEvent(MQ102, "OnStageSet")
		AddItemsToPlayerInventory()
	elseIf (akSender == DN050 && auiStageID == 30)
		UnregisterForRemoteEvent(DN050, "OnStageSet")
		;LenARM_BloatingMask_PeriodicMessage.Show()
		Note("Your breasts start bloating in anticipation!")
		;StartTimer(20, ETimerDN050)
		DN050SelfMorph()
	EndIf
EndEvent

Function AddItemsToPlayerInventory()
	Log("AddItemsToPlayerInventory -> start")
	int i = 0
	While (i < AutoAddToPlayerInventory.GetSize())
		Form AutoAddItem = AutoAddToPlayerInventory.GetAt(i)
		If (PlayerRef.GetItemCount(AutoAddItem) == 0)
			PlayerRef.AddItem(AutoAddItem, 1, False)
			Log("AddItemsToPlayerInventory -> " + AutoAddItem as string + " added")
		EndIf
		i += 1
	EndWhile
	Log("AddItemsToPlayerInventory -> end")
EndFunction

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
	ElseIf (tid == ETimerKitanaMask)
		KitanaMaskSelfMorph_Timer()
	ElseIf (tid == ETimerDN050)
		DN050SelfMorph()
	ElseIf (tid == ETimerNPCPopped)
		ResetHasKitanaMaskPoppedNPC()
	ElseIf (tid == ETimerHUD)
		UpdateHUD()
	EndIf
EndEvent

; ------------------------
; On MCM change, check what has changed and perform actions based on what has changed
; ------------------------
Function OnMCMSettingChange(string modName, string id)
	If (modName == "LenA_RadMorphing")
		; TechnicalNote("OnMCMSettingChange: " + id + " changed")
		Log("OnMCMSettingChange: " + modName + "; " + id)

		; update delay has been changed
		If (id == "fUpdateDelay:General")
			Note("UpdateDelay changes")
			
			MCM_Read_UpdateDelay()
		; radiation thresholds have been changed
		ElseIf (id == "fLowRadsThreshold:General" || id == "fMediumRadsThreshold:General" || id == "fHighRadsThreshold:General")
			Note("RadThreshold changes")

			MCM_Read_RadsThresholds()
		; any of the player popping settings have been changed
		ElseIf (id == "bEnablePopping:General" || id == "iPopStates:General" || id == "bPopShouldParalyze:General" || id == "iPopStripState:General" || id == "bPopUseFullSounds:General")
			Note("Player Popping changes")

			MCM_Read_PlayerPopping()
		; max radiation multiplier has been changed
		ElseIf (id == "iMaxRadiationMultiplier:General")
			Note("Max Radiation mult changes")

			MCM_Read_MaxRadiationMultiplier()
		; rads perks usage has been changed
		ElseIf (id == "bEnableRadsPerks:General")
			Note("Perk changes")

			MCM_Read_RadPerks()
		; any other non-slider config has been changed
		ElseIf (id == "bForceNPCBloatPopping:General")
			Note("Other changes")

			MCM_Read_NPCPopping()
		; sliders config has been changed; this will trigger mod restart
		else
			If (LL_Fourplay.StringSubstring(id, 0, 1) == "s")
				string value = MCM.GetModSettingString(modName, id)
				If (LL_Fourplay.StringSubstring(value, 0, 1) == " ")
					string msg = "The value you have just changed has leading whitespace:\n\n'" + value + "'"
					MessageBox(msg)

				EndIf
			EndIf
			Restart()
		endif
	EndIf
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

		MCM_Read_UpdateDelay()
		MCM_Read_RadsThresholds()
		MCM_Read_PlayerPopping()
		MCM_Read_NPCPopping()
		MCM_Read_MaxRadiationMultiplier()		
		MCM_Read_RadPerks()

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
		
		; start listening for start game quest
		RegisterForRemoteEvent(MQ102, "OnStageSet")
		RegisterForRemoteEvent(DN050, "OnStageSet")

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

		; when we don't use sliders that are doctor-only reset, reset the currentRads, totalRads and possible radperks
		if (!HasDoctorOnlySliders)			
			CurrentRads = 0
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

Function MCM_Read_UpdateDelay()	
	; get duration from MCM
	UpdateDelay = MCM.GetModSettingFloat("LenA_RadMorphing", "fUpdateDelay:General")
EndFunction

Function MCM_Read_RadsThresholds()	
	; get radiation threshold (currently used for morph sounds)
	; the division by 1000 is needed as rads run from 0 to 1, while the MCM settings are in displayed rads for player's convenience
	LowRadsThreshold = MCM.GetModSettingFloat("LenA_RadMorphing", "fLowRadsThreshold:General") / 1000.0
	MediumRadsThreshold = MCM.GetModSettingFloat("LenA_RadMorphing", "fMediumRadsThreshold:General") / 1000.0
	HighRadsThreshold = MCM.GetModSettingFloat("LenA_RadMorphing", "fHighRadsThreshold:General") / 1000.0
EndFunction

Function MCM_Read_PlayerPopping()	
	EnablePopping = MCM.GetModSettingBool("LenA_RadMorphing", "bEnablePopping:General")
	PopStates = MCM.GetModSettingInt("LenA_RadMorphing", "iPopStates:General")
	PopShouldParalyze = MCM.GetModSettingBool("LenA_RadMorphing", "bPopShouldParalyze:General")
	PopStripState = MCM.GetModSettingInt("LenA_RadMorphing", "iPopStripState:General")
	PopUseFullSounds = MCM.GetModSettingBool("LenA_RadMorphing", "bPopUseFullSounds:General")
EndFunction

Function MCM_Read_NPCPopping()	
	ForceNPCBloatPopping = MCM.GetModSettingBool("LenA_RadMorphing", "bForceNPCBloatPopping:General")
EndFunction

Function MCM_Read_MaxRadiationMultiplier()	
	MaxRadiationMultiplier = MCM.GetModSettingInt("LenA_RadMorphing", "iMaxRadiationMultiplier:General")
EndFunction

Function MCM_Read_RadPerks()	
	EnableRadsPerks = MCM.GetModSettingBool("LenA_RadMorphing", "bEnableRadsPerks:General")
EndFunction


Function Shutdown(bool withRestore=true)
	If (!IsShuttingDown)
		Log("Shutdown")
		IsShuttingDown = true

		; stop timers
		CancelTimer(ETimerMorphTick)
		CancelTimer(ETimerBloatSuit)
		CancelTimer(ETimerKitanaMask)
		CancelTimer(ETimerDN050)
		CancelTimer(ETimerNPCPopped)
	
		; stop listening for equipping items
		UnregisterForRemoteEvent(PlayerRef, "OnItemEquipped")
		
		; stop listening for doctor scene
		;TODO moeten de andere scenes hier ook niet bij staan?
		UnregisterForRemoteEvent(DoctorMedicineScene03_AllDone, "OnBegin")
		UnregisterForRemoteEvent(DoctorMedicineScene03_AllDone, "OnEnd")
		
		; stop listening for main quest changes
		UnregisterForRemoteEvent(MQ102, "OnStageSet")
		
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
	; divide rads by 1000 as 1 here equals 1000 displayed rads
	return newRads / 1000
EndFunction

; ------------------------
float Function GetNewBloating()
	float newBloating = (PlayerRef.GetValue(avBloating) as float)
	; divide bloating by 1000 as 1 here equals 1000 displayed 'rads'
	return newBloating / 1000
EndFunction

; ------------------------
bool Function UpdateCarriedBalloons()
	if (!hasHadMoleCowDisease)
		return false
	endif
	; when player has (or has had) molecow disease check our carried balloons
	;TODO je kan ook kijken of de ESP erin hangt
	;Game.IsPluginInstalled("xxx.esp")

	; get amount of carried balloons from HeliumBalloon.esp
	int newCarriedBalloons = (Game.GetFormFromFile(0x027858, "HeliumBalloon.esp") as GlobalVariable).getValueInt()
	if (carriedBalloons != newCarriedBalloons) 
		carriedBalloons = newCarriedBalloons
		return true
	endif
	
	return false
EndFunction

float Function CheckCarriedBalloons()
	if (!hasHadMoleCowDisease)
		return 0
	; when player has (or has had) molecow disease check our carried balloons
	else
		; each balloon is 5 rads worth of morphs
		return carriedBalloons * 0.005
	endif
EndFunction

; ------------------------
; Timer-based morphs
; ------------------------
Function TimerMorphTick()
	; if player is currently popping, we are starting up or player is dead, restart timer and do nothing
	if (IsPopping || IsStartingUp || PlayerRef.IsDead())
		StartTimer(UpdateDelay, ETimerMorphTick)
		return
	endif

	;TODO debug ding
	if (PlayerRef.IsEquipped(KitanaMask) && !hasKitanaMaskEquipped)
		Note("mask bugged out!")
	endif

	; by default, assume we have no changed morphs for all sliderSets
	bool changedMorphs = false
	; by default, assume we are not at our max morphs for all sliderSets
	bool maxedOutMorphs = false

	; setup the raw morphs percentage
	float rawMorphInput = 0

	; modify raw morphs percentage by player's current Rads
	float newRads = GetNewRads()
	rawMorphInput += newRads

	; modify raw morphs percentage by player's current Bloating
	float newBloating = GetNewBloating()
	rawMorphInput += newBloating

	bool hasCarriedBalloonsChanged = UpdateCarriedBalloons()
	; modify raw morphs percentage by player's carried balloons
	float balloonsMorph = CheckCarriedBalloons()
	rawMorphInput += balloonsMorph

	; recalculate which balloonsPerk to apply when enabled and carried balloons amount has changed.
	; do after we have updated our balloons count but before we abort the function if there is no morphs diff.
	; otherwise there are certain situations where changing amount of balloons doesn't trigger the perks to refresh.
	if (EnableRadsPerks && hasCarriedBalloonsChanged)
		ApplyBalloonsPerk()
	endif

	; check if player has gotten popping expert 2 perk while we haven't set the matching flag.
	; more in case player manually gives perk via console instead of doing it the normal way.
	if (PlayerRef.HasPerk(PoppingExpertPerk2) && isPoppingExpert == false)
		isPoppingExpert = true
	endif

	; if rads haven't changed, restart timer and do nothing
	; skipped if have forceUpdate = true
	If (!forceUpdate && rawMorphInput == CurrentRads)
		StartTimer(UpdateDelay, ETimerMorphTick)
		return
	endif

	; calculate the amount of rads taken
	; the longer the timer interval, the larger this will be
	float radsDifference = rawMorphInput - CurrentRads

	; when we have bloating suit equipped, reduce accumulated bloating by 25%
	if (hasBloatingSuitEquipped)
		;Note("reduced morphs from " + radsDifference + " to " + (radsDifference * 0.75))
		radsDifference = radsDifference * 0.75
	endif
	
	; when already on max morphs and popping is enabled, then any large amount of additional morphs (50 rads worth) will force an update
	; this is only relevant for CheckPopWarnings
	if (maxedOutMorphs && EnablePopping && (radsDifference >= 0.05))
		forceUpdate = true
	endif

	; update our internal storage with the new morphs
	CurrentRads = rawMorphInput

	; TODO de else is de huidige waarheid gezien we alleen doctor only sliders ondersteunen nu
	; when we have no doctor-only reset sliders, TotalRads should always match our current rads
	;if (!HasDoctorOnlySliders)
	;	TotalRads = rawMorphInput
	;; if we do have doctor-only reset sliders, only update TotalRads if it is an increase in rads
	;elseif (radsDifference > 0)
	if (radsDifference > 0)
		TotalRads += radsDifference
	endif
	
	; TODO more debug shenenigens...
	; Log("raw morph input: " + rawMorphInput + "; radsDifference: " + radsDifference + "; CurrentRads: " + CurrentRads + "; TotalRads: " + TotalRads)

	int idxSet = 0

	int morphableSliders = 0
	int maxedOutSliders = 0

	; when player is not in PA calculate and update body morphs.
	; in PA morphs aren't shown so don't go through all the effort to recalculate these.
	if (!PlayerRef.IsInPowerArmor())
		; check each sliderset whether we need to update the morphs
		While (idxSet < SliderSets.Length)
			SliderSet sliderSet = SliderSets[idxSet]

			;TODO kijken of Papyrus iets ondersteund ala continue in een loop
			;hij herkent continue niet als een valid iets, dus ik betwijfel het

			; only use sliderSets which have actual entries
			If (sliderSet.NumberOfSliderNames > 0)
				float calculatedMorphPercentage = CalculateMorphPercentage(rawMorphInput, sliderSet)

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

						; TODO gehele elseif is obsolete!							
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

		; Log("    update - changedMorphs: " + changedMorphs + "; maxedOutMorphs: " + maxedOutMorphs + "; radsDifference: " + radsDifference + "; HasReachedMaxMorphs: " + HasReachedMaxMorphs)

		; when at least one of the sliderSets has applied morphs, perform the actual actions
		If (changedMorphs)
			BodyGen.UpdateMorphs(PlayerRef)
			;TODO eigenlijk wil ik jouw wel doen in PA...
			; play morph sound when we haven't reached max morphs yet
			if (!maxedOutMorphs)
				CalculateAndPlayMorphSound(PlayerRef, radsDifference)
			endif
			TriggerUnequipSlots()
		endif

		; when we have reached max morphs and have either taken positive rads or have a force update, perform additional actions
		If (maxedOutMorphs && (radsDifference > 0 || forceUpdate))
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
	endif

	; reset forceUpdate to false when it was true
	if (forceUpdate)
		forceUpdate = false
	endif

	; recalculate which radsPerk to apply when enabled
	; do after we have updated everything else
	if (EnableRadsPerks)
		bool hasChangedPerk = ApplyRadsPerk()

		; when player has final or maxed-out radsPerk and is in PA, kick them out of PA
		if (hasChangedPerk && PlayerRef.IsInPowerArmor())
			if (CurrentRadsPerk >= 4)
				;TODO message van ergens anders
				Note("PA is too tight!")
				PlayerRef.SwitchtoPowerArmor(none)
				forceUpdate = true
			else
				;TODO message van ergens anders
				Note("PA is growing tighter...")
			endif
		endif
	endif

	; only restart the timer if we aren't shutting down, so it doesn't try to perform updates when the mod is in the process of stopping
	If (!IsShuttingDown)
		StartTimer(UpdateDelay, ETimerMorphTick)
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
	
	string matchingSlider = SliderNames[idxSlider]

	; permanent breast size increase
	if (matchingSlider == "Breasts")
		; player has (or has had) molecow disease
		if (hasHadMoleCowDisease)
			morphBonus += 0.15

			; player also carries balloons
			if (carriedBalloons > 0)
				morphBonus += 0.1
			endif
		endif
	; permanent nipple perkiness increase
	elseif (matchingSlider == "NipplePerkiness" || matchingSlider == "NipplePerk2")
		; player has bloating suit equipped
		if (hasBloatingSuitEquipped)
			morphBonus += 0.3
		endif
		; player has popped NPC with kitana mask
		if (hasKitanaMaskPoppedNPC)
			morphBonus += 0.5
		endif
		; player has nipple piercing equipped
		if (hasNippleBlockers)
			morphBonus += 0.25
		endif
	; permanent double melon increase
	elseif (matchingSlider == "DoubleMelon")
		; player is popping expert
		if (isPoppingExpert)
			morphBonus += 0.25
		endif
		; player has mooMilk addiction
		if (hasMooMilkAddiction)
			morphBonus += 0.5
		endif
		; player has kitana mask equipped
		if (hasKitanaMaskEquipped)
			morphBonus += 0.25
		endif
		; player has balloonsperks
		morphBonus += (CurrentBalloonsPerk * 0.1)
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
		; Log("    setting slider '" + SliderNames[idxSlider] + "' to " + newMorph + " (base value is " + OriginalMorphs[idxSlider] + ") (base morph is " + sliderSet.BaseMorph + ") (target is " + sliderSet.TargetMorph + ")")
		
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

	; reset the current and total rads
	; we need to reset both else they will start mismatching the next timerMorphTick and give wonky behaviour
	CurrentRads = 0
	TotalRads = 0

	; reset any additional Bloating the player had
	; works in the same way Doctor heals rads
	int RadsToHeal = (PlayerRef.GetValue(avBloating) as int)
	PlayerRef.RestoreValue(avBloating, RadsToHeal)

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
	; carrying balloons when having molecow disease increase chance of popping (breasts are even more pre-bloated)
	int balloonsMod = 0
	if (hasHadMoleCowDisease && carriedBalloons > 0)
		balloonsMod = 1
	endif
	; kitana mask equipped increase chance of popping (breasts are already pre-bloated + cursed)
	int kitanaMaskMod = 0
	if (hasKitanaMaskEquipped)
		kitanaMaskMod = 2
	endif

	; bloating suit equipped decrease chance of popping (milkers provide relief)
	int bloatSuitMod = (hasBloatingSuitEquipped as int)*-1

	;Note("luck " + luckMod + "; molecow " + moleCowDiseaseMod + "; nipple " + nippleBlockersMod + "; suit " + bloatSuitMod)

	; base pop chance is X/10, but X can be modified by above modifiers
	; depending on X and modifiers it can become 0 or less, so cap it to a minimum of 1
	int modifiedPopChance = popChance + luckMod + moleCowDiseaseMod + nippleBlockersMod + balloonsMod + kitanaMaskMod + bloatSuitMod
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
	RestorePlayerRads()

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
	RestorePlayerRads()

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

Function RestorePlayerRads()
	int RadsToHeal = (PlayerRef.GetValue(Rads) as int)
	PlayerRef.RestoreValue(Rads, RadsToHeal)
EndFunction

; ------------------------
; Increase all sliders by a percentage multiplied with the input for the player, and play the sound with given id (default Swell sound)
; Does not store the updated sliders' CurrentMorphs, as we will call ResetMorphs afterwards anyway
; ------------------------
Function ExtendMorphs(float step,  bool shouldPop, int soundId = 5)
	; Log("extending morphs with: " + step)

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
Function BloatActor_Internal(Actor akTarget, int currentBloatStage, int toAdd, int bloatType)
	; don't bloat actor that is dead
	if (akTarget.IsDead())
		return
	endif

	; calculate the target bloatStage
	; -1 means bloat to pop
	int targetBloatStage = currentBloatStage
	if (toAdd == -1)
		targetBloatStage = popNPCBloatStage
	else
		targetBloatStage += toAdd
	endif
	; limit to our max
	if (targetBloatStage > popNPCBloatStage)
		targetBloatStage = popNPCBloatStage
	endif

	int nextBloatStage = currentBloatStage + 1
	float morphPercentage = 0.2

	; Note(currentBloatStage + "; " + targetBloatStage)

	; when actor should get bloated to popping, always paralyze first (unless legendary or a HalluciGen Agent NPC)
	if (toAdd == -1 && bloatType != EBloatTypeLegendary && !akTarget.HasKeyword(ActorTypeBloatingAgent))
		ParalyzeActor(akTarget)
	endIf

	; when bloatType is normal or concentrated keep bloating the actor until the bloatStage is equal to target
	if (bloatType <= EBloatTypeConcentrated)
		while (nextBloatStage <= targetBloatStage)
			; don't bloat actor that is dead
			if (akTarget.IsDead())
				return
			endif

			ApplyActorBloatStage(akTarget, nextBloatStage, morphPercentage, bloatType)
			
			nextBloatStage += 1
		endwhile
	; when bloatType is messy or legendary immediately bloat to max and go to popping
	else
		; calculate the diff between current bloat stage and max and use that as our percentage
		int bloatStageDiff = maxNPCBloatStages - currentBloatStage
		; Note("current: " + currentBloatStage + "; target: " + targetBloatStage + "; diff: " + bloatStageDiff)
		; first bloat to max if we aren't at max yet
		if (bloatStageDiff > 0)
			float maxMorphPercentage = morphPercentage * bloatStageDiff			
			ApplyActorBloatStage(akTarget, maxNPCBloatStages, maxMorphPercentage, bloatType)
		endif

		; immediately bloat to pop afterwards
		ApplyActorBloatStage(akTarget, popNPCBloatStage, morphPercentage, bloatType)
	endif
EndFunction

; public endpoints used in the Magic Effect scripts
Function BloatActor(Actor akTarget, int currentBloatStage, int toAdd)
	BloatActor_Internal(akTarget, currentBloatStage, toAdd, EBloatTypeNormal)
EndFunction
Function BloatActorConcentrated(Actor akTarget, int currentBloatStage, int toAdd)
	BloatActor_Internal(akTarget, currentBloatStage, toAdd, EBloatTypeConcentrated)
EndFunction
Function BloatActorMessy(Actor akTarget, int currentBloatStage, int toAdd)
	BloatActor_Internal(akTarget, currentBloatStage, toAdd, EBloatTypeMessy)
EndFunction
Function BloatActorLegendary(Actor akTarget, int currentBloatStage, int toAdd)
	BloatActor_Internal(akTarget, currentBloatStage, toAdd, EBloatTypeLegendary)
EndFunction


Function ApplyActorBloatStage(Actor akTarget, int nextBloatStage, float morphPercentage, int bloatType)
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
	if (nextBloatStage <= maxNPCBloatStages)
		SetBloatMorphs(akTarget, morphPercentage, shouldPop = false)
		BodyGen.UpdateMorphs(akTarget)
	endif

	; play the matching sound
	if (perkLevel < maxNPCBloatStages)
		PlayMorphSound(akTarget, 3)
	elseif (perkLevel == maxNPCBloatStages && nextBloatStage == maxNPCBloatStages)
		PlayMorphSound(akTarget, 4)
	; pop the actor 
	elseif (perkLevel == maxNPCBloatStages && nextBloatStage > maxNPCBloatStages)		
		Utility.Wait(randomFloat)
		BloatPopActor(akTarget, bloatType)
	endif
EndFunction

Function BloatPopActor(Actor akTarget, int bloatType)
	; pause self-bloat timer
	CancelTimer(ETimerKitanaMask)

	bool isConcentrated = bloatType == EBloatTypeConcentrated
	bool isForcedMessy = bloatType == EBloatTypeMessy
	; when bloatpopping a HalluciGen Agent NPC always make it legendary
	bool isLegendary = bloatType == EBloatTypeLegendary || akTarget.HasKeyword(ActorTypeBloatingAgent)

	; when we pop a non-essential hostile enemy, 10% chance that we pop in a more permanent way
	float messyPopChance = 0.1

	; when configured to always messy pop NPCs the permanent pop chance is 100%
	; this overrules any other options
	if (ForceNPCBloatPopping)
		messyPopChance = 1
	; when hit by concentrated shot the permanent pop chance is 50%
	elseif (isConcentrated)
		messyPopChance = 0.5
	; when forced to messy pop then the permanent pop chance is 100%
	elseif (isForcedMessy || isLegendary)
		messyPopChance = 1
	endif

	; since IsProtected is only on ActorBase make a quick cast
	ActorBase actorBaseTarget = akTarget.GetBaseObject() as ActorBase

	bool isHostile = akTarget.IsHostileToActor(PlayerRef) == true
	bool isEssential = actorBaseTarget.IsEssential()
	bool canForcedMessy = (isForcedMessy || isLegendary) && isHostile
	; only allow messy pops when:
	; - target is not player
	; - target is hostile to player
	; - target is not essential (game does some very weird things if we messy pop those)
	; - random die roll is below our messyPopChance
	bool shouldMessyPop = (akTarget != PlayerRef && isHostile && !isEssential && utility.RandomFloat() <= messyPopChance)

	; before we start expanding log the current breasts size
	float npcBreastsMorph = BodyGen.GetMorph(akTarget, True, "Breasts", None)
	float npcBreastsNewSHMorph = BodyGen.GetMorph(akTarget, True, "BreastsNewSH", None)
	
	float npcMorph = npcBreastsMorph + (npcBreastsNewSHMorph / 2) 

	; the bigger the breasts are, the more milk we will add at the end
	; logic behind these values:
	; - current settings' Breasts slider target morph is 0.5
	; - base NPC body morphs for Breasts slider vary from 0 to 1, with 0.4 being the 'normal' max and 1 for moomilk agents
	; - base NPC body morphs for BreastsNewSH slider vary from 0 to 0.3, currently only being used by one set
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

	; paralyze actor first if not legendary
	PlayMorphSound(akTarget, 4)
	if (!isLegendary)
		ParalyzeActor(akTarget)
	endif
	
	; add bloating ammo to actor's inventory
	akTarget.AddItem(ThirstZapperBloatAmmo, 1, abSilent = true)

	int currentPopState = 1
	float multiplier = 0.1
	float totalPopMultiplier = 0

	; do a random delay before appying the morphs (and morph sounds) on the akTarget
	float randomFloat = GetRandomDelay(1,2) ;(2,3)
	Utility.Wait(randomFloat)

	int popStatesToUse = PopStates
	bool playAltMorphSound = false

	; when we should messy pop we change the amount of states and bloat multipliers
	if (shouldMessyPop)
		if (canForcedMessy)
			playAltMorphSound = true

			; forced messy pop bloats actor at normal rate but much larger and immediately strips them
			if (!isLegendary)
				popStatesToUse = PopStates
				multiplier *= 3.5
				UnequipAllNPC(akTarget)
			; legendary pop bloats actor at normal rate but even larger then forced messy but doesn't strip them
			else
				popStatesToUse = PopStates
				multiplier *= 3.75
			endif
		; 'normal' messy pop bloats actor twice as long and larger as warning for attent player
		else
			popStatesToUse *= 2
			multiplier *= 1.5
		endif
	endif

	; gradually increase the morphs and unequip the clothes
	While (currentPopState < popStatesToUse)	
		; don't bloat actor that is dead
		if (akTarget.IsDead())
			;TODO hier moet kitana mask timer weer gestart worden	
			; ; restart self-morph timer when requirements not yet met
			; if (hasKitanaMaskEquipped && kitanaMaskMessyPoppedRequirementMet == false)
			; 	StartTimer(kitanaMaskSelfMorphTimer, ETimerKitanaMask)
			; endif	

			; killing legendary bloating enemies will just pop them directly
			if (isLegendary)
				; we need to do some calculations so we go back to the original NPC's morphs
				float reset = (1.0 + totalPopMultiplier) * -1
				SetBloatMorphs(akTarget, reset, shouldPop = false)
				BloatPopActor_HandleMessy(akTarget, milkToAdd, canForcedMessy, isLegendary)
			endif
			return
		endif
		
		SetBloatMorphs(akTarget, multiplier, shouldPop = true)
		totalPopMultiplier += multiplier
		
		BodyGen.UpdateMorphs(akTarget)
		; play normal swell sound when bloating normally
		if (currentPopState < PopStates && !playAltMorphSound)
			PlayMorphSound(akTarget, 5)
		; when we are bloating beyond normal play the alt swell sound 
		else
			PlayMorphSound(akTarget, 6)
		endif

		; add bloating ammo to actor's inventory
		akTarget.AddItem(ThirstZapperBloatAmmo, 1, abSilent = true)

		; for the unequip state we also want to strip all clothes and armor
		If (!canForcedMessy && (currentPopState == PopStripState || currentPopState == PopStates))
			UnequipAllNPC(akTarget)
		endif

		Utility.Wait(0.7) ;(0.3) ;(1.0)

		currentPopState += 1
	EndWhile

	; don't pop actor that is dead
	if (akTarget.IsDead())
		;TODO hier moet kitana mask timer weer gestart worden		
		; ; restart self-morph timer when requirements not yet met
		; if (hasKitanaMaskEquipped && kitanaMaskMessyPoppedRequirementMet == false)
		; 	StartTimer(kitanaMaskSelfMorphTimer, ETimerKitanaMask)
		; endif
		return
	endif

	; apply the final morphs, and do the 'pop'
	SetBloatMorphs(akTarget, multiplier, shouldPop = true)				
	totalPopMultiplier += multiplier
	
	BodyGen.UpdateMorphs(akTarget)
	
	; we need to do some calculations so we go back to the original NPC's morphs
	float reset = (1.0 + totalPopMultiplier) * -1
	SetBloatMorphs(akTarget, reset, shouldPop = false)

	; messy pop kills actor and places a grenade explosion
	if (shouldMessyPop)
		; if actor was protected remove this flag first
		bool isProtected = actorBaseTarget.IsProtected()
		if (isProtected)
			actorBaseTarget.setProtected(false)
		endif
		BloatPopActor_HandleMessy(akTarget, milkToAdd, canForcedMessy, isLegendary)
	; normal pop keeps actor paralyzed for a bit and places a normal explosion
	else
		BloatPopActor_HandleNormal(akTarget, milkToAdd)
	endif
EndFunction

; messy pop kills actor and places a grenade explosion
Function BloatPopActor_HandleMessy(Actor akTarget, int milkToAdd, bool canForcedMessy, bool isLegendary)
	LenARM_PrePopMessySound.PlayAndWait(akTarget)

	; add some concentrated bloating ammo to actor's inventory when they've been allowed to pop
	; reduce by 3 (capped to min 1) to not give too many freebies
	; if forced messy then always only give 1 concentrated as a tradeoff
	int concMilkToAdd = milkToAdd -3
	if (concMilkToAdd < 1 || canForcedMessy)
		concMilkToAdd = 1
	endif
	akTarget.AddItem(ThirstZapperBloatAmmo_Concentrated, concMilkToAdd, abSilent = true)	

	; clear rad perks so we don't keep ambient noise
	ClearAllRadsPerks(akTarget)

	LenARM_PopMessySound.Play(akTarget)
	; spread the joy to nearby NPCs
	akTarget.PlaceAtMe(BloatGrenadeExplosion)	

	; reset all the morphs back to 0
	; do this for messy bloatpopping too otherwise after respawning the NPC will still have the morphs
	BodyGen.UpdateMorphs(akTarget)

	; dismember and kill actor
	; sadly no way to give the XP to the player even if we tell the player is the killer
	akTarget.Dismember("Torso", true, true, true)
	akTarget.Kill(PlayerRef)

	; unparalyze the actor
	; do this for messy bloatpopping too otherwise after respawning the NPC will still be paralyzed
	if (!isLegendary)
		UnParalyzeActor(akTarget)
	endif
	
	float distanceToPlayer = PlayerRef.GetDistance(akTarget)

	; bloat player and give temp buff if kitana mask is equipped and within range
	; this takes priority over having the bloating suit equipped as well
	if (hasKitanaMaskEquipped)
		; always bloat player independent of distance
		int bloatingAmount = (milkToAdd * 20)
		KitanaMaskSelfMorph_Kill(bloatingAmount)

		if (distanceToPlayer < kitanaMaskPopDetectRadius)
			LenARM_NPCPopComment.Play(PlayerRef)
			PlayerRef.EquipItem(BloatMaskPoppedNPCBuff, abSilent = true)
		endif
	; give player a temp buff if bloating suit is equipped and within range
	elseif (hasBloatingSuitEquipped && distanceToPlayer < bloatingSuitPopDetectRadius)
		LenARM_NPCPopComment.Play(PlayerRef)
		PlayerRef.EquipItem(BloatSuitPoppedNPCBuff, abSilent = true)
	endif
EndFunction

; normal pop keeps actor paralyzed for a bit and places a normal explosion
Function BloatPopActor_HandleNormal(Actor akTarget, int milkToAdd)
	LenARM_PrePopSound.PlayAndWait(akTarget)

	; add some more bloating ammo to actor's inventory when they've been allowed to pop
	akTarget.AddItem(ThirstZapperBloatAmmo, milkToAdd, abSilent = true)

	LenARM_PopSound.Play(akTarget)
	; spread the joy to nearby NPCs
	akTarget.PlaceAtMe(BloatNPCPopExplosion)		

	; reset all the morphs back to 0
	BodyGen.UpdateMorphs(akTarget)

	ClearAllRadsPerks(akTarget)
	akTarget.EquipItem(PoppedPotion, abSilent = true)
	
	; restart self-morph timer when requirements not yet met
	if (hasKitanaMaskEquipped && (PlayerRef.HasPerk(PoppingExpertPerk1) == false))
		StartTimer(kitanaMaskSelfMorphTimer, ETimerKitanaMask)
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
; Check the total accumulated rads, and apply the matching radsPerk to the player.
; Returns true if player was wearing torso armor and switched from first perk to higher.
; Returns false in all other cases.
; ------------------------
bool Function ApplyRadsPerk()
	; when we have 0 rads, clear all existing perks and don't apply a new one
	if (TotalRads == 0)
		ClearAllRadsPerks(PlayerRef)
		return false
	endif

	;TODO bepaal wat min / max zijn, en vanaf wanneer we dus moeten gaan werken tot wanneer
	;zie ook CalculateMorphPercentage
	; voor nu gebruiken we 0 als min en 1000 als max
	;TODO moet dus ook rekening gaan houden met MaxRadiationMultiplier

	; calculate the perk level
	int perkLevel = ((TotalRads * 1000) / 200) as int
	; keep track of whether we've changed perks
	bool hasChanged = false

	; Log((TotalRads * 1000) + "; " + ((TotalRads * 1000) / 200) + "; " + perkLevel)
	; Log("radsperk; CurrentRads: " + (CurrentRads * 1000) + "; TotalRads: " + (TotalRads * 1000))

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

			; play clothes stretch sound when we have something equipped on the torso and we aren't going from none to first or from final to none
			if (HasTorsoEquipped(PlayerRef) && perkLevel != 0 && CurrentRadsPerk != 0)
				;Note("stretch sound for perkLevel " + perkLevel + "; CurrentRadsPerk " + CurrentRadsPerk)
				LenARM_RadPerkSwitchSound.Play(PlayerRef)
				
				; only here set our bool to true
				hasChanged = true
			endif
		Else
			PlayerRef.AddPerk(RadsPerkFull)			
		endif
		
		CurrentRadsPerk = perkLevel
		; enable bloating suit ammo when we switch perks
		canGiveBloatingSuitAmmo = true		
	endif

	return hasChanged
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

bool Function HasTorsoEquipped(Actor akTarget)
	; in PA always return true
	If (akTarget.IsInPowerArmor())
		return true
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
		; include bloating suit in this check
		bool isArmor = IsItemArmor(item, true)

		; when item is an armor mark as such
		If (isArmor && !found)
			found = true
		EndIf
		
		idxSlot += 1	
	EndWhile

	return found
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
	
		; reset counter as well
		CurrentBalloonsPerk = 0
		return
	endif

	; limit to 4 just in case (we have 4 perks)
    If (currentCount > 4)
        currentCount = 4
    EndIf

	; when we have enough balloons that we should have a difference in perk level, change perks
	if (CurrentBalloonsPerk != currentCount)
		; subtract 1 from our count as the Perks start from 0
		int newBalloonsPerk = currentCount -1
		ClearOldBalloonsPerks(PlayerRef, newBalloonsPerk)
		; grab the perk from the array if we aren't on maxed out morphs, else use the dedicated perk
		PlayerRef.AddPerk(BalloonsPerkArray[newBalloonsPerk])		
		
		CurrentBalloonsPerk = currentCount
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

	; Log("UnequipSlots (stack=" + UnequipStackSize + ")")
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

		; Log(hasFullBodyItem)

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
	; Log("FINISHED UnequipSlots")
EndFunction

Function TriggerUnequipSlots()
	; Log("TriggerUnequipSlots")
	StartTimer(0.1, ETimerUnequipSlots)
EndFunction

Function UnequipAll()
	; don't bother unequipping if player is in power armor
	If (PlayerRef.IsInPowerArmor())
		return
	EndIf
	
	; Log("UnequipAll")

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
			; Log("  unequipping slot " + slot + " (" + item.item.GetName() + " / " + item.modelName + ")")

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
	; Log("FINISHED UnequipAll")
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
			; Log("  unequipping slot " + slot + " (" + item.item.GetName() + " / " + item.modelName + ")")

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

bool Function IsItemArmor(Actor:WornItem item, bool includeBloatingSuit = false)
	;return (item.item && LL_Fourplay.StringSubstring(item.modelName, 0, 6) != "Actors" && LL_Fourplay.StringSubstring(item.modelName, 0, 6) != "Pipboy")

	; sanity check
	if (!item.item)
		return false
	endif
	; ignore milking armor when we should not include it
	if (!includeBloatingSuit && item.item.HasKeyword(ArmorTypeBloatingSuit))
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
		; Log("  minimum rads taken")
	; everything between LowRadsThreshold and MediumRadsThreshold rads taken
	elseif (radsDifference <= MediumRadsThreshold)
		; Log("  medium rads taken")
		PlayMorphSound(akSender, 1)
	; everything between MediumRadsThreshold and HighRadsThreshold rads taken
	elseif (radsDifference <= HighRadsThreshold)
		; Log("  high rads taken")
		PlayMorphSound(akSender, 2)
	; everything above HighRadsThreshold rads taken
	elseif (radsDifference > HighRadsThreshold)
		; Log("  very high rads taken")
		PlayMorphSound(akSender, 3)
	endif
EndFunction

; ------------------------
; Bloating Suit inject bloating agent action
; ------------------------
Function SuitInjectBloatingAgent()
	If (PlayerRef.WornHasKeyword(ArmorTypeBloatingSuit))
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

;TODO kunnen we deze slimmer maken dat deze alleen loopt als je daadwerkelijk bloat suit equipped hebt, ipv altijd?
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


Function KitanaMaskEquipped()
	; TechnicalNote("mask equipped!")
	hasKitanaMaskEquipped = true

	if (PlayerRef.HasPerk(PoppingExpertPerk1) == false)
		if (TutorialDisplayed_KitanaMask == false)
			LenARM_Tutorial_BloatingMaskMessage.ShowAsHelpMessage("LenARM_Tutorial_BloatingMaskMessage", 8, 0, 1)
			TutorialDisplayed_KitanaMask = true
		endif

		; 100 rads worth of bloating
		PlayerRef.DamageValue(avBloating, 100)
		LenARM_FXBloatHitSound_High.Play(PlayerRef)
		
		KitanaMask_TriggerPuffyNipples_NoTimer()
		StartTimer(kitanaMaskSelfMorphTimer, ETimerKitanaMask)
	endif
	
	; force update morphs on next run
	forceUpdate = true
EndFunction

Function KitanaMaskUnequipped()
	; TechnicalNote("mask unequipped!")
	hasKitanaMaskEquipped = false

	; force update morphs on next run
	forceUpdate = true
	
	; cancel timer is handled in OnItemUnequipped due to additional logic
EndFunction

Function KitanaMaskSelfMorph_Timer()
	; escape in case the player has gotten the perk in the mean time
	; do reset puffy nipples first
	if (PlayerRef.HasPerk(PoppingExpertPerk1))
		ResetHasKitanaMaskPoppedNPC()
		return
	endif

	LenARM_BloatingMask_PeriodicMessage.Show()
	; 50 rads worth of bloating
	PlayerRef.DamageValue(avBloating, 50)
	LenARM_FXBloatHitSound_High.Play(PlayerRef)
	
	; skip puffy nipples as we already have that when we get here
	
	StartTimer(kitanaMaskSelfMorphTimer, ETimerKitanaMask)
	
	; force update morphs on next run
	forceUpdate = true
EndFunction

Function KitanaMaskSelfMorph_Unequip()
	LenARM_BloatingMask_UnsafeUnequipMessage.Show()
	; 50 rads worth of bloating
	PlayerRef.DamageValue(avBloating, 50)
	LenARM_FXBloatHitSound_High.Play(PlayerRef)
	
	; skip puffy nipples as we already have that when we get here

	; force update morphs on next run
	forceUpdate = true
EndFunction

Function KitanaMaskSelfMorph_Kill(int bloatingAmount = 100)
	; cap at 150 bloating max
	if (bloatingAmount > 150)
		bloatingAmount = 150
	endif
	;Note(bloatingAmount)

	; bloat player
	PlayerRef.DamageValue(avBloating, bloatingAmount)
	LenARM_FXBloatHitSound_High.Play(PlayerRef)
	kitanaMaskMessyPoppedCount += 1

	; when player has popped enough NPCs to safely unequip mask, give out perk and display special message
	if (kitanaMaskMessyPoppedCount >= poppingExpert1Requirement && (PlayerRef.HasPerk(PoppingExpertPerk1) == false))
		PlayerRef.AddPerk(PoppingExpertPerk1)
		LenARM_BloatingMask_SafeUnequipMessage.ShowAsHelpMessage("LenARM_BloatingMask_SafeUnequipMessage", 8, 0, 1)
	; otherwise display the standard message
	else
		LenARM_BloatingMask_KillMessage.Show()
	endif

	; when player has messy popped a certain amount of NPCs with the mask, give out a perk
	if (kitanaMaskMessyPoppedCount >= poppingExpert2Requirement && PlayerRef.HasPerk(PoppingExpertPerk2) == false)
		PlayerRef.AddPerk(PoppingExpertPerk2)
		LenARM_PoppingExpertPerkMessage.ShowAsHelpMessage("LenARM_PoppingExpertPerkMessage", 8, 0, 1)
		isPoppingExpert = true
	endif
	
	; restart self-morph timer with a larger delay when requirements not yet met
	if (PlayerRef.HasPerk(PoppingExpertPerk1) == false)
		StartTimer(kitanaMaskSelfMorphMessyTimer, ETimerKitanaMask)
		; skip puffy nipples as we already have that when we get here
	else
		; explicitely trigger puffy nipples when we can take off the mask
		KitanaMask_TriggerPuffyNipples()
	endif
	
	; force update morphs on next run
	forceUpdate = true
EndFunction

Function KitanaMask_TriggerPuffyNipples_NoTimer()
	KitanaMask_TriggerPuffyNipples(-1)
EndFunction
Function KitanaMask_TriggerPuffyNipples(int timer = 10)
	; give player puffy nipples for a bit
	hasKitanaMaskPoppedNPC = true
	CancelTimer(ETimerNPCPopped)
	if (timer > 0)
		StartTimer(timer, ETimerNPCPopped)
	endif
EndFunction


Function DN050SelfMorph()
	if (DN050.GetStage() == 30)
		; 20 rads worth of bloating
		PlayerRef.DamageValue(avBloating, 20)
		; LenARM_FullGroanSound.Play(PlayerRef)
		LenARM_FXBloatHitSound_High.Play(PlayerRef)
		; give player puffy nipples for a bit
		hasKitanaMaskPoppedNPC = true
		
		StartTimer(5, ETimerDN050)
	else
		hasKitanaMaskPoppedNPC = false
		;TODO of sloopt dit nu iets?
		; ; force update morphs on next run when not yet maxed out
		; if (!HasReachedMaxMorphs)
		; 	forceUpdate = true
		; endif
	endif
EndFunction

Function ResetHasKitanaMaskPoppedNPC()
	hasKitanaMaskPoppedNPC = false
	;TODO of sloopt dit nu iets?
	; ; force update morphs on next run when not yet maxed out
	; if (!HasReachedMaxMorphs)
	; 	forceUpdate = true
	; endif
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


float Function GetLowestSliderPercentage()
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

	; if (PlayerRef.HasPerk(PoppingExpertPerk2))
	; 	Note("popping expert given!")
	; 	isPoppingExpert = true
	; endif

	; ; Note("DN050 registered")
	; ; RegisterForRemoteEvent(DN050, "OnStageSet")
	
	; ;TODO for now hijacked to activate HUDFramework plugin
	; hud = HUDFramework.GetInstance()
	; If (hud)

	; 	float fX = 500 ;1000
	; 	float fY = 300 ;70

	; 	Note("HUDFramework is installed!")
    ;     ; Register the widget, setting its position to 10, 70 on the screen.
    ;     ; Load the widget automatically after registration, and auto-load it whenever the game loads.
    ;     hud.RegisterWidget(Self as ScriptObject, BloatExposure_Widget, fX, fY, abLoadNow = True, abAutoLoad = True)
    ;     ; hud.RegisterWidget(Self as ScriptObject, BloatExposure_Widget, 10.0, 10.0, abLoadNow = True, abAutoLoad = True)
    ;     hud.SetWidgetPosition(BloatExposure_Widget, 10.0, 70.0)
    ;     hud.SetWidgetScale(BloatExposure_Widget, 1.0, 1.0)
    ;     hud.SetWidgetOpacity(BloatExposure_Widget, 1.0)
	; Else
	; 	Note("HUDFramework is not installed!")
	; EndIf

	float lowestPercentage = GetLowestSliderPercentage()

	;TODO ik dump TotalRads hier ff als test in
	MessageBox((lowestPercentage * 100) + "% ; " + (TotalRads * 1000))
EndFunction


; ------------------------
; HUD Framework shenenigens
; ------------------------
; This function is called by HUDFramework when the widget is loaded.
Function HUD_WidgetLoaded(string asWidget)
    If (asWidget == BloatExposure_Widget)
		; Note("Widget registered!")

		float[] huh = hud.GetWidgetPosition(BloatExposure_Widget)
		Note("Widget registered!" + huh[0] + "; " + huh[1])


		; hud.SetWidgetScale(BloatExposure_Widget, 1, 1, False)
		; hud.SetWidgetPosition(BloatExposure_Widget, 10, 70, False)
		; hud.SetWidgetOpacity(BloatExposure_Widget, 1.0, False)

		int hudValue = (PlayerRef.GetValue(avBloating) as int)

        hud.SendMessage(BloatExposure_Widget, ECommand_UpdateBloat, hudValue)
		
		StartTimer(UpdateDelay, ETimerHUD)
    EndIf
EndFunction

Function UpdateHUD()
	int hudValue = (PlayerRef.GetValue(avBloating) as int)
	
	; Note("enabled: " + hud.IsWidgetLoaded(BloatExposure_Widget) + "; bloat: " + hudValue)
	Note("bloat: " + hudValue)

	hud.SendMessage(BloatExposure_Widget, ECommand_UpdateBloat, hudValue)

	; hud.SendMessage(Self.DEF_w_PA1_identifier, Self.command_stats_update, playerref.GetValue(PPowerArmorHeadCondition), playerref.GetValue(PPowerArmorTorsoCondition), playerref.GetValue(PPowerArmorRightArmCondition), playerref.GetValue(PPowerArmorLeftArmCondition), playerref.GetValue(PPowerArmorRightLegCondition), playerref.GetValue(PPowerArmorLeftLegCondition))

	StartTimer(UpdateDelay, ETimerHUD)
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
			; Log("  " + slot + ": " + item.item.GetName() + " (" + item.modelName + ")")
		Else
			; Log("  Slot " + slot + " is empty")
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

bool Function GetHasHadMoleCowDisease()
	return hasHadMoleCowDisease
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
	Debug.Trace("[LenARM] " + msg)
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
	int Property ETimerKitanaMask = 8 Auto Const
	int Property ETimerDN050 = 9 Auto Const
	int Property ETimerNPCPopped = 10 Auto Const
	int Property ETimerHUD = 99 Auto Const
EndGroup

Group EnumWidgetCommands
	; from KillCount.swf
    int Property ECommand_UpdateBloat = 100 Auto Const
EndGroup

Group EnumSex
	int Property ESexMale = 0 Auto Const
	int Property ESexFemale = 1 Auto Const
EndGroup

Group Constants
	int Property _NUMBER_OF_SLIDERSETS_ = 20 Auto Const
EndGroup

Group EnumNPCBloatType
	int Property EBloatTypeNormal = 1 Auto Const
	int Property EBloatTypeConcentrated = 2 Auto Const
	int Property EBloatTypeMessy = 3 Auto Const
	int Property EBloatTypeLegendary = 4 Auto Const
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