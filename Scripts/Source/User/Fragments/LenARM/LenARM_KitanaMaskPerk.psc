ScriptName Fragments:LenARM:LenARM_KitanaMaskPerk extends Perk hidden const

Spell Property BloatSpell Auto Const
ActorValue property NPCBloatImmunity auto const
Sound Property LenARM_InjectSound Auto Const

Function Fragment_Entry_00(ObjectReference akTargetRef, Actor akActor)
    Actor akTarget = akTargetRef as Actor     
    ; when in Power Armor, dead or immune to bloating don't morph
	If (akTarget.IsInPowerArmor() || akTarget.IsDead() || ((akTarget.getValue(NPCBloatImmunity) as bool) == true))
		return
	EndIf
    
    Actor PlayerRef = game.GetPlayer()

	int sex = akTarget.GetLeveledActorBase().GetSex()

    ; for now only work on females
    if (sex == 1)
		LenARM_InjectSound.Play(akTarget)

        Utility.Wait(1.0)

        BloatSpell.cast(akTarget)
    endif
EndFunction