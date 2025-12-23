Scriptname LenARM:LenARM_MS19CureScript extends ActiveMagicEffect

Message Property LenARM_MoleCow_CureMessage Auto
Perk Property MS19DiseasePerk Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
	Actor PlayerRef = game.getplayer()

	; remove old perk if found
	if (PlayerRef.HasPerk(MS19DiseasePerk))
		LenARM_MoleCow_CureMessage.Show()
		PlayerRef.RemovePerk(MS19DiseasePerk)
	endif
EndEvent
