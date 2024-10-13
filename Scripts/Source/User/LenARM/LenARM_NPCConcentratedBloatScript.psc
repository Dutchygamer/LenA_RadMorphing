ScriptName LenARM:LenARM_NPCConcentratedBloatScript extends ActiveMagicEffect

LenARM_Main Property LenARM_Main Auto
actorValue property NPCBloatStage auto	
actorValue property NPCBloatImmunity auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
    ; when in Power Armor, dead or immune to bloating don't morph
	If (akTarget.IsInPowerArmor() || akTarget.IsDead() || ((akTarget.getValue(NPCBloatImmunity) as bool) == true))
		return
	EndIf
    
	int sex = akTarget.GetLeveledActorBase().GetSex()
    int StageToAdd = 6

    ; for now only work on females
    if (sex == LenARM_Main.ESexFemale)     
        ; make ourselves immune to further bloating until we are done
        akTarget.SetValue(NPCBloatImmunity, 1)

        int currentBloatStage = (akTarget.getValue(NPCBloatStage) as int)
        int expectedBloatStage = currentBloatStage + StageToAdd
        akTarget.SetValue(NPCBloatStage, expectedBloatStage)

        ; for concentrated we explicetly set `isConcentrated` to true
        LenARM_Main.BloatActor(akTarget, currentBloatStage, StageToAdd, true)

        ; if not dead by now (ie messy popped), do some additional actions
        if (!akTarget.IsDead())
            ; after popping, keep us paralyzed for a bit
            akTarget.SetValue(NPCBloatStage, 0)

            ; wait a bit before taking away our immunity
            Utility.Wait(1)
            akTarget.SetValue(NPCBloatImmunity, 0)
            ; unparalyze the npc after a bit, but do leave them open for renewed bloating
            Utility.Wait(9)
            LenARM_Main.UnParalyzeActor(akTarget)
        endif
    endif
EndEvent