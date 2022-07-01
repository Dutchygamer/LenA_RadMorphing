ScriptName LenARM:LenARM_RadPurgeScript extends ActiveMagicEffect

LenARM_Main Property LenARM_Main Auto
Actor Property PlayerRef Auto Const
Message Property LenARM_RadPurgeSuccessMessage Auto
Message Property LenARM_PurgeInPAMessage Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
    ; when in Power Armor don't reset morphs
	If (PlayerRef.IsInPowerArmor())
        LenARM_PurgeInPAMessage.Show()
		return
	EndIf

    LenARM_RadPurgeSuccessMessage.Show()
    LenARM_Main.ResetMorphs()
EndEvent