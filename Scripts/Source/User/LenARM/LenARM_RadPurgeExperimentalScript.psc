ScriptName LenARM:LenARM_RadPurgeExperimentalScript extends ActiveMagicEffect

LenARM_Main Property LenARM_Main Auto
Actor Property PlayerRef Auto Const
Message Property LenARM_RadPurgeFailureMessage Auto
Message Property LenARM_RadPurgePopFailureMessage Auto
Message Property LenARM_RadPurgeSuccessMessage Auto
Message Property LenARM_PurgeInPAMessage Auto
Sound Property LenARM_PurgeFailSound Auto Const
Potion Property PoppedPotion Auto Const	

Event OnEffectStart(Actor akTarget, Actor akCaster)
    ; base 50% chance to trigger
    bool shouldPop = LenARM_Main.ShouldPop(5)

    if (shouldPop)
        ; bloat player followed by popping if enabled in config
        if (LenARM_Main.IsPoppingEnabled())
            LenARM_RadPurgePopFailureMessage.Show()
            LenARM_PurgeFailSound.Play(PlayerRef)
            LenARM_Main.RadPurgeFailSelfMorphAndPop()
        ; else bloat player and apply the popped debuffs on the player
        else            
            LenARM_RadPurgeFailureMessage.Show()
            PlayerRef.EquipItem(PoppedPotion, abSilent = true)
            LenARM_Main.RadPurgeFailSelfMorph()
        endif
    Else
        LenARM_RadPurgeSuccessMessage.Show()
        LenARM_Main.ResetMorphs()					
    endIf
EndEvent