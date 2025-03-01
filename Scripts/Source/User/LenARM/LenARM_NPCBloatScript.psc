ScriptName LenARM:LenARM_NPCBloatScript extends ActiveMagicEffect

LenARM_Main Property LenARM_Main Auto
actorValue property NPCBloatStage auto	
actorValue property NPCBloatImmunity auto	
actorValue property NPCConcentratedBloatCount auto
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
        RegisterForRemoteEvent(akCaster, "OnDeath")
        
        ; make ourselves immune to further bloating until we are done
        akTarget.SetValue(NPCBloatImmunity, 1)

        int currentBloatStage = (akTarget.getValue(NPCBloatStage) as int)
        int expectedBloatStage = currentBloatStage + StageToAdd
        akTarget.SetValue(NPCBloatStage, expectedBloatStage)
        
        int concentratedBloatCount = (akTarget.getValue(NPCConcentratedBloatCount) as int)

        ; depending on the params of this magic effect do a different type of bloating
        if (IsConcentrated)
            ; when not popped from two concentrated hits in a row, the third one will make it a messy pop
            if (concentratedBloatCount >= 2)
                LenARM_Main.BloatActorMessy(akTarget, currentBloatStage, StageToAdd)
            else
                LenARM_Main.BloatActorConcentrated(akTarget, currentBloatStage, StageToAdd)
            endif            
        elseif (IsMessy)
            LenARM_Main.BloatActorMessy(akTarget, currentBloatStage, StageToAdd)
        else
            LenARM_Main.BloatActor(akTarget, currentBloatStage, StageToAdd)
        endif

        ; if not dead by now (ie messy popped), do some additional actions
        if (!akTarget.IsDead())

            if (IsConcentrated)
                LenARM_Main.TechnicalNote("concentrated +1")
                akTarget.SetValue(NPCConcentratedBloatCount, (concentratedBloatCount + 1))
            endif

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

; when unloading the actor / actor dies reset a bunch of things so it doesn't get stuck when respawning
Event ObjectReference.OnUnload(ObjectReference akSender)
    Actor akTarget = (akSender as Actor)
    ResetActor(akTarget)
endEvent
Event Actor.OnDeath(Actor akSender, Actor akKiller)
    ResetActor(akSender)
endEvent

Function ResetActor(Actor akTarget)
    self.Dispel()

    ; don't stay paralyzed
    LenARM_Main.UnParalyzeActor(akTarget)
    ; clear overlays
    LenARM_Main.ClearAllRadsPerks(akTarget)    
    ; reset concentratedd bloated counter
    akTarget.SetValue(NPCConcentratedBloatCount, 0)

    RegisterForRemoteEvent(akTarget as ObjectReference, "OnUnload")
    RegisterForRemoteEvent(akTarget, "OnDeath")
EndFunction
