ScriptName LenARM:LenARM_NPCBloatScript extends ActiveMagicEffect

LenARM_Main Property LenARM_Main Auto
actorValue property NPCBloatStage auto	
actorValue property NPCBloatImmunity auto	
int property StageToAdd = 1 auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
    ; when in Power Armor don't morph
	If (akTarget.IsInPowerArmor())
		return
	EndIf
    ; when immune to bloating don't morph
	If ((akTarget.getValue(NPCBloatImmunity) as bool) == true)
		return
	EndIf
    
	int sex = akTarget.GetLeveledActorBase().GetSex()

    ; for now only work on females
    if (sex == LenARM_Main.ESexFemale)     
        ; make ourselves immune to further bloating until we are done
        akTarget.SetValue(NPCBloatImmunity, 1)

        int bloatStage = (akTarget.getValue(NPCBloatStage) as int) + StageToAdd
        akTarget.SetValue(NPCBloatStage, bloatStage)

        LenARM_Main.BloatActor(akTarget, bloatStage, StageToAdd)

        ; after popping, keep us paralyzed for a bit
        if (bloatStage > 5)
            akTarget.SetValue(NPCBloatStage, 0)

            ; wait a bit before taking away our immunity
            Utility.Wait(1)
            akTarget.SetValue(NPCBloatImmunity, 0)
            ; unparalize the npc after a bit, but do leave them open for renewed bloating
            Utility.Wait(9)
            LenARM_Main.UnParalyzeNPC(akTarget)
        ; else take away our immunity directly
        else
            akTarget.SetValue(NPCBloatImmunity, 0)
        endif
    endif
EndEvent