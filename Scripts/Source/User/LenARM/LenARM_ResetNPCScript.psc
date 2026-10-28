ScriptName LenARM:LenARM_ResetNPCScript extends ActiveMagicEffect

LenARM_BloatNPC Property LenARM_BloatNPC Auto
LenARM_Debug Property LenARM_Debug Auto Const
Actor Property PlayerRef Auto Const

Event OnEffectStart(Actor akTarget, Actor akCaster)
    ; don't work for player for obvious reasons
    if (akTarget == PlayerRef)
        return
    endif

    LenARM_Debug.TechnicalNote("resetting NPC")
    LenARM_BloatNPC.Debug_ResetNPCMorphs(akTarget)
EndEvent