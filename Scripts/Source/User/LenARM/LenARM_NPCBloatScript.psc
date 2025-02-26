ScriptName LenARM:LenARM_NPCBloatScript extends ActiveMagicEffect

LenARM_Main Property LenARM_Main Auto
actorValue property NPCBloatStage auto	
actorValue property NPCBloatImmunity auto	
int property StageToAdd = 1 auto
bool property IsConcentrated = false auto
bool property IsMessy = false auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
    ; when in Power Armor, dead or immune to bloating don't morph
	If (akTarget.IsInPowerArmor() || akTarget.IsDead() || ((akTarget.getValue(NPCBloatImmunity) as bool) == true))
		return
	EndIf
    
	int sex = akTarget.GetLeveledActorBase().GetSex()
    ; when concentrated or messy always overwrite stageToAdd to 6 (the max)
    if (IsConcentrated || IsMessy)
        StageToAdd = 6
    endif

    ; for now only work on females
    if (sex == LenARM_Main.ESexFemale)
        RegisterForRemoteEvent(akCaster as ObjectReference, "OnUnload")
        
        ; make ourselves immune to further bloating until we are done
        akTarget.SetValue(NPCBloatImmunity, 1)

        int currentBloatStage = (akTarget.getValue(NPCBloatStage) as int)
        int expectedBloatStage = currentBloatStage + StageToAdd
        akTarget.SetValue(NPCBloatStage, expectedBloatStage)

        ; depending on the params of this magic effect do a different type of bloating
        if (IsConcentrated)
            LenARM_Main.BloatActorConcentrated(akTarget, currentBloatStage, StageToAdd)
        elseif (IsMessy)
            LenARM_Main.BloatActorMessy(akTarget, currentBloatStage, StageToAdd)
        else
            LenARM_Main.BloatActor(akTarget, currentBloatStage, StageToAdd)
        endif

        ; if not dead by now (ie messy popped), do some additional actions
        if (!akTarget.IsDead())
            ; after popping, keep us paralyzed for a bit
            if (expectedBloatStage > 5)
                akTarget.SetValue(NPCBloatStage, 0)

                ; wait a bit before taking away our immunity
                Utility.Wait(1)
                akTarget.SetValue(NPCBloatImmunity, 0)
                ; unparalyze the npc after a bit, but do leave them open for renewed bloating
                Utility.Wait(9)
                LenARM_Main.UnParalyzeActor(akTarget)
            ; else take away our immunity directly
            else
                akTarget.SetValue(NPCBloatImmunity, 0)
            endif
        endif
    endif
EndEvent

; when unloading the actor reset a bunch of things so it doesn't get stuck when respawning
Event ObjectReference.OnUnload(ObjectReference akSender)
    self.Dispel()

    Actor akTarget = (akSender as Actor)

    ; don't stay paralyzed
    LenARM_Main.UnParalyzeActor(akTarget)
    ; clear overlays
    LenARM_Main.ClearAllRadsPerks(akTarget)

    ; (akSender as Actor).stopcombat()
    ; akSender.SetValue(ParalysisAV, 0)
    ; akSender.setValue(Aggression, iPrevAggression)
    ; akSender.setValue(Game.GetConfidenceAV(), iPrevConfidence)
    
endEvent

;TODO doe ook OnDeath?