ScriptName Fragments:LenARM:LenARM_KitanaMaskPerk extends Perk hidden const

Spell Property BloatSpell Auto Const
Spell Property DamageAPSpell Auto Const
ActorValue property NPCBloatImmunity auto const
Sound Property LenARM_InjectSound Auto Const

Function Fragment_Entry_00(ObjectReference akTargetRef, Actor akActor)
    Actor akTarget = akTargetRef as Actor     
    ; when in Power Armor, dead or immune to bloating don't morph
    ;TODO indien moomilk agent + legendary skip dan ook => ABLegendaryBloatScript gaat dat handlen
	If (akTarget.IsInPowerArmor() || akTarget.IsDead() || ((akTarget.getValue(NPCBloatImmunity) as bool) == true))
		return
	EndIf
    
    Actor PlayerRef = game.GetPlayer()

	int sex = akTarget.GetLeveledActorBase().GetSex()

    ; for now only work on females
    if (sex == 1)
        ; damage player ActionPoints ('cost' to use)
        DamageAPSpell.cast(PlayerRef)
		LenARM_InjectSound.Play(akTarget)

        Utility.Wait(1.0)

        ; start bloating NPC
        BloatSpell.cast(akTarget)
    endif
EndFunction