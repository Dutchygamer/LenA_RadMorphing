ScriptName Fragments:LenARM:LenARM_MooMilkPerk extends Perk hidden const

;LenARM_Main Property LenARM_Main Auto const
Spell Property BloatSpell Auto Const
;actorValue property NPCBloatStage auto const
ActorValue property NPCBloatImmunity auto const

Ammo Property ThirstZapperBloatAmmo Auto Const

Function Fragment_Entry_00(ObjectReference akTargetRef, Actor akActor)
	Debug.Notification("bim")
    Actor akTarget = akTargetRef as Actor     
    ; when in Power Armor, dead or immune to bloating don't morph
	If (akTarget.IsInPowerArmor() || akTarget.IsDead() || ((akTarget.getValue(NPCBloatImmunity) as bool) == true))
		return
	EndIf
    
    Actor PlayerRef = game.GetPlayer()

    int bloatingAmmoCount = PlayerRef.GetItemCount(ThirstZapperBloatAmmo)
    if (bloatingAmmoCount < 1)
        ;LenARM_BloatingAgentMissingMessage.Show()
        return
    endif

	int sex = akTarget.GetLeveledActorBase().GetSex()

	Debug.Notification("ding")

    ; for now only work on females
    if (sex == 1)             
        
	    Debug.Notification("dong")

        PlayerRef.RemoveItem(ThirstZapperBloatAmmo, 1, abSilent = true)

        ;TODO gaat nog niet helemaal goed, zie logs

        BloatSpell.cast(akTarget)


        ; ; make ourselves immune to further bloating until we are done
        ; akTarget.SetValue(NPCBloatImmunity, 1)

        ; int currentBloatStage = (akTarget.getValue(NPCBloatStage) as int)
        ; int expectedBloatStage = 6
        ; akTarget.SetValue(NPCBloatStage, expectedBloatStage)

        ; LenARM_Main.BloatActor(akTarget, currentBloatStage, expectedBloatStage)

        ; ; after popping, keep us paralyzed for a bit
        ; if (expectedBloatStage > 5)
        ;     akTarget.SetValue(NPCBloatStage, 0)

        ;     ; wait a bit before taking away our immunity
        ;     Utility.Wait(1)
        ;     akTarget.SetValue(NPCBloatImmunity, 0)
        ;     ; unparalyze the npc after a bit, but do leave them open for renewed bloating
        ;     Utility.Wait(9)
        ;     LenARM_Main.UnParalyzeActor(akTarget)
        ; ; else take away our immunity directly
        ; else
        ;     akTarget.SetValue(NPCBloatImmunity, 0)
        ; endif
    endif
EndFunction