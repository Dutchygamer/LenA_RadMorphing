ScriptName LenARM:LenARM_NPCBloatScript extends ActiveMagicEffect

LenARM_Main Property LenARM_Main Auto
actorValue property NPCBloatStage auto	
actorValue property NPCBloatImmunity auto	
int property StageToAdd = 1 auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
    ; when in Power Armor, dead or immune to bloating don't morph
	If (akTarget.IsInPowerArmor() || akTarget.IsDead() || ((akTarget.getValue(NPCBloatImmunity) as bool) == true))
		return
	EndIf
    
	int sex = akTarget.GetLeveledActorBase().GetSex()

    ; for now only work on females
    if (sex == LenARM_Main.ESexFemale)     
        ; make ourselves immune to further bloating until we are done
        akTarget.SetValue(NPCBloatImmunity, 1)

        int currentBloatStage = (akTarget.getValue(NPCBloatStage) as int)
        int expectedBloatStage = currentBloatStage + StageToAdd
        akTarget.SetValue(NPCBloatStage, expectedBloatStage)

        LenARM_Main.BloatActor(akTarget, currentBloatStage, StageToAdd)

        ; after popping, keep us paralyzed for a bit
        if (expectedBloatStage > 5)
            akTarget.SetValue(NPCBloatStage, 0)

            ; wait a bit before taking away our immunity
            Utility.Wait(1)
            akTarget.SetValue(NPCBloatImmunity, 0)
            ; unparalyze the npc after a bit, but do leave them open for renewed bloating
            Utility.Wait(9)
            LenARM_Main.UnParalyzeNPC(akTarget)
        ; else take away our immunity directly
        else
            akTarget.SetValue(NPCBloatImmunity, 0)
        endif
    endif
EndEvent