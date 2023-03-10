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
    endif
EndEvent