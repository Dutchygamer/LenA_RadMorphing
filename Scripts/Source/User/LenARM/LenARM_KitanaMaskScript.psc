Scriptname LenARM:LenARM_KitanaMaskScript extends ObjectReference

Potion Property BloatSuitEquipBuff Auto Const
Potion Property BloatSuitUnequipDebuff Auto Const
LenARM_Main Property LenARM_Main Auto
Perk Property LenARM_MooMilkPerk Auto Const

Event OnEquipped(Actor akActor)
    Actor PlayerActor = game.GetPlayer()
    if akActor == PlayerActor
        LenARM_Main.KitanaMaskEquipped()
        ;PlayerActor.EquipItem(BloatSuitEquipBuff, abSilent = true)
		PlayerActor.AddPerk(LenARM_MooMilkPerk)
    Endif
EndEvent

Event OnUnequipped(Actor akActor)
    Actor PlayerActor = game.GetPlayer()
    if (akActor == PlayerActor)
        LenARM_Main.KitanaMaskUnequipped()
        ;PlayerActor.EquipItem(BloatSuitUnequipDebuff, abSilent = true)
		PlayerActor.RemovePerk(LenARM_MooMilkPerk)
    Endif
EndEvent