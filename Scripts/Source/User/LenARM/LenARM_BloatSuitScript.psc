Scriptname LenARM:LenARM_BloatSuitScript extends ObjectReference

Potion Property BloatSuitEquipBuff Auto Const
Potion Property BloatSuitUnequipDebuff Auto Const
LenARM_Main Property LenARM_Main Auto

Event OnEquipped(Actor akActor)
    Actor PlayerActor = game.GetPlayer()
    if akActor == PlayerActor
        LenARM_Main.BloatingSuitEquipped()
        PlayerActor.EquipItem(BloatSuitEquipBuff, abSilent = true)
    Endif
EndEvent

Event OnUnequipped(Actor akActor)
    Actor PlayerActor = game.GetPlayer()
    if akActor == PlayerActor
        LenARM_Main.BloatingSuitUnequipped()
        PlayerActor.EquipItem(BloatSuitUnequipDebuff, abSilent = true)
    Endif
EndEvent