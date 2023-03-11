ScriptName LenARM:LenARM_NPCBloatScript extends ActiveMagicEffect

LenARM_Main Property LenARM_Main Auto
actorValue property NPCBloatStage auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
    ; when in Power Armor don't reset morphs
	If (akTarget.IsInPowerArmor())
		return
	EndIf
    
	int sex = akTarget.GetLeveledActorBase().GetSex()

    ; for now only work on females
    if (sex == LenARM_Main.ESexFemale)        
        int bloatStage = (akTarget.getValue(NPCBloatStage) as int) + 1
        akTarget.SetValue(NPCBloatStage, bloatStage)
        LenARM_Main.BloatActor(akTarget, bloatStage)

        ; after popping, reset bloatStage back to 0
        if (bloatStage > 5)
            akTarget.SetValue(NPCBloatStage, 0)

            ; unparalize the npc after a bit, but do leave them open for renewed bloating
            Utility.Wait(10)
            LenARM_Main.UnParalyzeNPC(akTarget)
        endif
    endif
EndEvent