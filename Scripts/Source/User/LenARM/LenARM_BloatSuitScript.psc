Scriptname LenARM:LenARM_BloatSuitScript extends ObjectReference

LenARM_Main Property LenARM_Main Auto

Event OnEquipped(Actor akActor)
    Actor PlayerActor = game.GetPlayer()
    if akActor == PlayerActor
        LenARM_Main.BloatingSuitEquipped()
    Endif
EndEvent

Event OnUnequipped(Actor akActor)
    Actor PlayerActor = game.GetPlayer()
    if akActor == PlayerActor
        LenARM_Main.BloatingSuitUnequipped()
    Endif
EndEvent