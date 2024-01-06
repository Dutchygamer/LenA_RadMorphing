; taken from MS19DiseaseScript with some tweaks of my own
Scriptname LenARM:LenARM_MS19DiseaseScript extends ActiveMagicEffect

Potion Property MS19MoleratPoison Auto Const Mandatory
Spell Property MoleCowMilkSpell Auto Const Mandatory
MagicEffect Property LenARM_MS19MoleratEffect Auto Const Mandatory
Message Property LenARM_MoleCowMilkInfectedMessage Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
	Actor PlayerRef = game.getplayer()

	; inform them of infection and trigger milk surge if first time infected
	if (PlayerRef.HasMagicEffect(LenARM_MS19MoleratEffect) == false)
		LenARM_MoleCowMilkInfectedMessage.Show()
		MoleCowMilkSpell.Cast(PlayerRef as ObjectReference, PlayerRef as ObjectReference)
	endif

	; afterwards give player the disease as default script does
	; do this after above check else that one never gets triggered
	PlayerRef.equipitem(MS19MoleratPoison, false, true)
EndEvent
