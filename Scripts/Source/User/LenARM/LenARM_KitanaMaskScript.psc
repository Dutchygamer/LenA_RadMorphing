Scriptname LenARM:LenARM_KitanaMaskScript extends ObjectReference

LenARM_Main Property LenARM_Main Auto
; OBSOLETE
Potion Property BloatSuitEquipBuff Auto Const
; OBSOLETE
Potion Property BloatSuitUnequipDebuff Auto Const

Perk Property LenARM_MooMilkPerk Auto Const
Sound Property EquipSound Auto Const
Sound Property UnEquipSound Auto Const

Event OnEquipped(Actor akActor)
    Actor PlayerActor = game.GetPlayer()
    if akActor == PlayerActor
        LenARM_Main.KitanaMaskEquipped()
        ; PlayerActor.EquipItem(BloatSuitEquipBuff, abSilent = true)
        EquipSound.Play(PlayerActor)
		PlayerActor.AddPerk(LenARM_MooMilkPerk)
    Endif
EndEvent

Event OnUnequipped(Actor akActor)
    Actor PlayerActor = game.GetPlayer()
    if (akActor == PlayerActor)
        LenARM_Main.KitanaMaskUnequipped()
        ; PlayerActor.EquipItem(BloatSuitUnequipDebuff, abSilent = true)
        UnEquipSound.Play(PlayerActor)
		PlayerActor.RemovePerk(LenARM_MooMilkPerk)
    Endif
EndEvent