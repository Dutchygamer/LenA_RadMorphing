Scriptname LenARM:LenARM_BloatNPC extends Quest

; ------------------------
; ------------------------
; Quest input params

Group LenARM
	LenARM_Perks Property LenARM_Perks Auto Const
	LenARM_Util Property LenARM_Util Auto Const
	LenARM_Debug Property LenARM_Debug Auto Const
	LenARM_SFX Property LenARM_SFX Auto Const
	LenARM_SliderSet Property LenARM_SliderSet Auto Const
	LenARM:LenARM_Main Property LenARM_Main Auto Const
EndGroup


Group Properties
	Actor Property PlayerRef Auto Const
	
	; dummy keyword for BodyMorphs; never gets set
	Keyword Property kwMorph Auto Const

	Keyword property ActorTypeBloatingAgent auto
	; Keyword property ArmorTypeBloatingSuit auto
	
	Form Property BloatNPCPopExplosion Auto
	Form Property BloatGrenadeExplosion Auto
	; ; [OBSOLETE]
	; Form Property BloatingSuit Auto
	; Form Property KitanaMask Auto
    
	Ammo Property ThirstZapperBloatAmmo Auto Const
	Ammo Property ThirstZapperBloatAmmo_Concentrated Auto Const		
EndGroup


; ------------------------
; ------------------------
; variables

int maxNPCBloatStages = 5
int popNPCBloatStage = 6 ; should be maxNPCBloatStages + 1

; from MCM
int PopStates
int PopStripState
bool ForceNPCBloatPopping


; ------------------------
; ------------------------
; Enums

Group EnumNPCBloatType
	int Property EBloatTypeNormal = 1 Auto Const
	int Property EBloatTypeConcentrated = 2 Auto Const
	int Property EBloatTypeMessy = 3 Auto Const
	int Property EBloatTypeLegendary = 4 Auto Const
EndGroup


; ------------------------
; ------------------------
; methods

; For some reason doc comments from the first function after variable declarations are not picked up.
Function DummyFunction()
EndFunction


;
; Bloats @akTarget with @toAdd stages. Minor chance of messy bloat-popping
;
Function BloatActor(Actor akTarget, int currentBloatStage, int toAdd)
	BloatActor_Internal(akTarget, currentBloatStage, toAdd, EBloatTypeNormal)
EndFunction
;
; Bloats @akTarget with @toAdd stages. Major chance of messy bloat-popping
;
Function BloatActorConcentrated(Actor akTarget, int currentBloatStage, int toAdd)
	BloatActor_Internal(akTarget, currentBloatStage, toAdd, EBloatTypeConcentrated)
EndFunction
;
; Bloats @akTarget with @toAdd stages. 100% chance of messy bloat-popping
;
Function BloatActorMessy(Actor akTarget, int currentBloatStage, int toAdd)
	BloatActor_Internal(akTarget, currentBloatStage, toAdd, EBloatTypeMessy)
EndFunction
;
; Bloats @akTarget with @toAdd stages. 100% of legendary bloat-popping
;
Function BloatActorLegendary(Actor akTarget, int currentBloatStage, int toAdd)
	BloatActor_Internal(akTarget, currentBloatStage, toAdd, EBloatTypeLegendary)
EndFunction

; 
; Increase all sliders by a percentage multiplied with the input for the given actor.
; Intended for use on NPCs.
; 
Function BloatActor_Internal(Actor akTarget, int currentBloatStage, int toAdd, int bloatType)
	; don't bloat actor that is dead
	if (akTarget.IsDead())
		return
	endif

	; load directly from MCM
	PopStates = MCM.GetModSettingInt("LenA_RadMorphing", "iPopStates:General")
	PopStripState = MCM.GetModSettingInt("LenA_RadMorphing", "iPopStripState:General")
	ForceNPCBloatPopping = MCM.GetModSettingBool("LenA_RadMorphing", "bForceNPCBloatPopping:General")

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
		LenARM_Util.ParalyzeActor(akTarget)
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


Function ApplyActorBloatStage(Actor akTarget, int nextBloatStage, float morphPercentage, int bloatType)
	; perkLevel is equal to the bloat state 
	int perkLevel = nextBloatStage

	; limit to 5 just in case (we have 5 perks, starting from 0)
    If (perkLevel > 5)
        perkLevel = 5
    EndIf

	; compare current akTarget radsPerk level vs the new level, change perks if needed
	if (LenARM_Perks.GetCurrentRadsPerkLevel(akTarget) != perkLevel)
		LenARM_Perks.ClearOldRadsPerks(akTarget, perkLevel)
		; grab the perk from the array if we aren't on maxed out morphs, else use the dedicated perk
		if (perkLevel != 5)
			LenARM_Perks.ApplyRadsPerk(akTarget, perkLevel)
		Else
			LenARM_Perks.ApplyRadsPerkMax(akTarget)
		endif
	endif

	; do a random delay before appying the morphs (and morph sounds) on the akTarget
	float randomFloat = LenARM_Util.GetRandomDelay(1,2) ;(2,3)
	Utility.Wait(randomFloat)

	; only apply initial morphs if we are not going to pop
	if (nextBloatStage <= maxNPCBloatStages)
		SetBloatMorphs(akTarget, morphPercentage, shouldPop = false)
		BodyGen.UpdateMorphs(akTarget)
	endif

	; play the matching sound
	if (perkLevel < maxNPCBloatStages)
		LenARM_SFX.ActorPlaySound(akTarget, LenARM_SFX.EMorphSound_High)
	elseif (perkLevel == maxNPCBloatStages && nextBloatStage == maxNPCBloatStages)
		LenARM_SFX.ActorPlaySound(akTarget, LenARM_SFX.EMorphSound_Full)
	; pop the actor 
	elseif (perkLevel == maxNPCBloatStages && nextBloatStage > maxNPCBloatStages)		
		Utility.Wait(randomFloat)
		BloatPopActor(akTarget, bloatType)
	endif
EndFunction

Function BloatPopActor(Actor akTarget, int bloatType)
	; pause self-bloat timer
	LenArm_Main.KitanaMaskCancelTimer()

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

	; since IsEssential is only on ActorBase make a quick cast
	ActorBase actorBaseTarget = akTarget.GetBaseObject() as ActorBase

	bool isHostile = akTarget.IsHostileToActor(PlayerRef) == true
	bool isEssential = actorBaseTarget.IsEssential()
	bool canForcedMessy = (isForcedMessy || isLegendary) && isHostile
	; only allow messy pops when:
	; - target is not player
	; - target is hostile to player
	; - target is not essential (protected is fine)
	; - random die roll is below our messyPopChance
	
	bool shouldMessyPop = (akTarget != PlayerRef && isHostile && !isEssential && utility.RandomFloat() <= messyPopChance)
	; messy popping essential NPCs will lead to some very weird things hence we don't support that
	; if you want to messy pop an essential NPC (ie that Hubologist cook from Nuka World) first use console command `setessential <baseid> 0` on them

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
	LenARM_SFX.ActorPlaySound(akTarget, LenARM_SFX.EMorphSound_Full)
	if (!isLegendary)
		LenARM_Util.ParalyzeActor(akTarget)
	endif
	
	; add bloating ammo to actor's inventory
	akTarget.AddItem(ThirstZapperBloatAmmo, 1, abSilent = true)

	int currentPopState = 1
	float multiplier = 1.0/8.0 ;same multiplier as for player
	float totalPopMultiplier = 0

	; do a random delay before appying the morphs (and morph sounds) on the akTarget
	float randomFloat = LenARM_Util.GetRandomDelay(1,2) ;(2,3)
	Utility.Wait(randomFloat)

	int popStatesToUse = PopStates
	bool playAltMorphSound = false

	; when we should messy pop we change the amount of states and bloat multipliers
	if (shouldMessyPop)
		if (canForcedMessy)
			playAltMorphSound = true

			; forced messy pop bloats actor at normal rate but twice as large and immediately strips them
			if (!isLegendary)
				popStatesToUse = PopStates
				multiplier *= 2.0
				UnequipAllNPC(akTarget)
			; legendary pop bloats actor at normal rate but even larger then forced messy but doesn't strip them
			else
				popStatesToUse = PopStates
				multiplier *= 2.5
			endif
		; 'normal' messy pop bloats actor twice as long
		else
			popStatesToUse *= 2
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
			LenARM_SFX.ActorPlaySound(akTarget, LenARM_SFX.EMorphSound_Swell)
		; when we are bloating beyond normal play the alt swell sound 
		else
			LenARM_SFX.ActorPlaySound(akTarget, LenARM_SFX.EMorphSound_SwellPop)
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

; 
; messy pop kills actor and places a grenade explosion
;
Function BloatPopActor_HandleMessy(Actor akTarget, int milkToAdd, bool canForcedMessy, bool isLegendary)
	LenARM_SFX.ActorPlaySoundAndWait(akTarget, LenARM_SFX.EPrePopMessySound)

	; add some concentrated bloating ammo to actor's inventory when they've been allowed to pop
	; reduce by 3 (capped to min 1) to not give too many freebies
	; if forced messy then always only give 1 concentrated as a tradeoff
	int concMilkToAdd = milkToAdd -3
	if (concMilkToAdd < 1 || canForcedMessy)
		concMilkToAdd = 1
	endif
	akTarget.AddItem(ThirstZapperBloatAmmo_Concentrated, concMilkToAdd, abSilent = true)	

	; clear rad perks so we don't keep ambient noise
	LenARM_Perks.ClearAllRadsPerks(akTarget)

	;TODO waarom zit dit niet op de Explosion?
	LenARM_SFX.ActorPlaySound(akTarget, LenARM_SFX.EPopMessySound)
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
		LenARM_Util.UnParalyzeActor(akTarget)
	endif
	
	float distanceToPlayer = PlayerRef.GetDistance(akTarget)
	LenARM_Main.MessyPopNPC_PlayerReward(distanceToPlayer, milkToAdd)
EndFunction

; 
; normal pop keeps actor paralyzed for a bit and places a normal explosion
;
Function BloatPopActor_HandleNormal(Actor akTarget, int milkToAdd)
	LenARM_SFX.ActorPlaySoundAndWait(akTarget, LenARM_SFX.EPrePopSound)

	; add some more bloating ammo to actor's inventory when they've been allowed to pop
	akTarget.AddItem(ThirstZapperBloatAmmo, milkToAdd, abSilent = true)

	LenARM_SFX.ActorPlaySound(akTarget, LenARM_SFX.EPopSound)
	; spread the joy to nearby NPCs
	akTarget.PlaceAtMe(BloatNPCPopExplosion)		

	; reset all the morphs back to 0
	BodyGen.UpdateMorphs(akTarget)

	LenARM_Perks.ClearAllRadsPerks(akTarget)
	
	; restart self-morph timer when requirements not yet met
	LenARM_Main.KitanaMaskRestartTimer()
EndFunction


Function SetBloatMorphs(Actor akTarget, float morphPercentage, bool shouldPop)	
	int idxSet = 0

	LenARM_SliderSet:SliderSet[] currentSliderSets = LenARM_SliderSet.GetAllSliderSets()

	; apply it to all morphs from slidersets which aren't excluded
	While (idxSet < currentSliderSets.Length)
		LenARM_SliderSet:SliderSet sliderSet = currentSliderSets[idxSet]		
		If (sliderSet.NumberOfSliderNames > 0);  && (!shouldPop || (shouldPop && !sliderSet.ExcludeFromPopping)))
			int sliderNameOffset = LenARM_SliderSet.SliderSet_GetSliderNameOffset(idxSet)
			int idxSlider = sliderNameOffset
			int sex = akTarget.GetLeveledActorBase().GetSex()
			While (idxSlider < sliderNameOffset + sliderSet.NumberOfSliderNames)
				string slider = LenARM_SliderSet.GetSliderName(idxSlider)

				float toApplyPercentage = morphPercentage
				;TODO for now hardcoded to half these sliders as these look wonky when large morphed
				if (slider == "PregnancyBelly" || slider == "BigBelly")
					toApplyPercentage = toApplyPercentage / 2.0
				endif

				;TODO not the most efficient way tho...	
				; grab NPC's current morphs for the slider
				float npcMorph = BodyGen.GetMorph(akTarget, True, slider, None)

				; calculate the new morphs based on current morphs + what we need to add
				float newMorph = npcMorph + (toApplyPercentage * sliderSet.targetMorph)
				; float newMorph = CalculateMorphs(idxSlider, morphPercentage, sliderSet.TargetMorph)

				; ;TODO debug ding
				; if (slider == "Breasts")
				; 	D.Log(npcMorph + "; " + morphPercentage + "; " + sliderSet.targetMorph + "; " + newMorph)
				; endif
						
				; set the morphs
				BodyGen.SetMorph(akTarget, sex==ESexFemale, slider, kwMorph, newMorph)

				idxSlider += 1
			EndWhile
		EndIf
		idxSet += 1
	EndWhile
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
		bool isArmor = LenARM_Util.IsItemArmor(item)

		; when item is an armor and we can unequip it, do so
		If (isArmor)
			; LenARM_Debug.Log("  unequipping slot " + slot + " (" + item.item.GetName() + " / " + item.modelName + ")")

			akTarget.UnequipItem(item.item, false, true)
			
			; when the item is no longer equipped and we haven't already unequipped anything (goes across all slots),
			; play the strip sound if available
			If (!found && !akTarget.IsEquipped(item.item))
				LenARM_SFX.ActorPlaySound(akTarget, LenARM_SFX.EDropClothesSound)
				found = true
			EndIf
		EndIf
		
		idxSlot += 1	
	EndWhile
EndFunction

Group EnumSex
	int Property ESexMale = 0 Auto Const
	int Property ESexFemale = 1 Auto Const
EndGroup
