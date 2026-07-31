Scriptname LenARM:LenARM_SFX extends Quest

; ------------------------
; ------------------------
; Quest input params

Group Properties
	Sound Property LenARM_DropClothesSound Auto Const
	Sound Property LenARM_MorphSound Auto Const
	Sound Property LenARM_MorphSound_Med Auto Const
	Sound Property LenARM_MorphSound_High Auto Const
	Sound Property LenARM_FullSound Auto Const
	Sound Property LenARM_RadPerkSwitchSound Auto Const
	Sound Property LenARM_SwellSound Auto Const
	Sound Property LenARM_SwellPopSound Auto Const
	Sound Property LenARM_PrePopSound Auto Const
	Sound Property LenARM_PrePopMessySound Auto Const
	Sound Property LenARM_PopSound Auto Const
	Sound Property LenARM_PopMessySound Auto Const
	Sound Property LenARM_PurgeFailSound Auto Const
	Sound Property LenARM_FullGroanSound Auto Const
	Sound Property LenARM_BloatSuitMilkSound Auto Const
	Sound Property LenARM_NPCPopComment Auto Const
	Sound Property LenARM_FXBloatHitSound_High Auto Const
EndGroup


; ------------------------
; ------------------------
; enums

Group EnumSoundEffect
	int Property EMorphSound_Low = 1 Auto Const
	int Property EMorphSound_Medium = 2 Auto Const
	int Property EMorphSound_High = 3 Auto Const
	int Property EMorphSound_Full = 4 Auto Const
	int Property EMorphSound_Swell = 5 Auto Const
	int Property EMorphSound_SwellPop = 6 Auto Const
	int Property EDropClothesSound = 7 Auto Const
	int Property ERadPerkSwitchSound = 8 Auto Const
	int Property EPrePopSound = 9 Auto Const
	int Property EPrePopMessySound = 10 Auto Const
	int Property EPopSound = 11 Auto Const
	int Property EPopMessySound = 12 Auto Const
	int Property EPurgeFailSound = 13 Auto Const
	int Property EFullGroanSound = 14 Auto Const
	int Property EBloatSuitMilkSound = 15 Auto Const
	int Property ENPCPopComment = 16 Auto Const
	int Property EFXBloatHitSound_High = 17 Auto Const
EndGroup


; ------------------------
; ------------------------
; methods

; 
; @akSender plays sound effect with id @soundId
; 
Function ActorPlaySound(Actor akSender, int soundId)
	if (soundId == EMorphSound_Low)
		LenARM_MorphSound.Play(akSender)
	elseif (soundId == EMorphSound_Medium)
		LenARM_MorphSound_Med.Play(akSender)
	elseif (soundId == EMorphSound_High)
		LenARM_MorphSound_High.Play(akSender)
	elseif (soundId == EMorphSound_Full)
		LenARM_FullSound.Play(akSender)

	elseif (soundId == EMorphSound_Swell)
		LenARM_SwellSound.Play(akSender)
	elseif (soundId == EMorphSound_SwellPop)
		LenARM_SwellPopSound.Play(akSender)

	elseif (soundId == EDropClothesSound)
		LenARM_DropClothesSound.Play(akSender)
	elseif (soundId == ERadPerkSwitchSound)
		LenARM_RadPerkSwitchSound.Play(akSender)

	elseif (soundId == EPrePopSound)
		LenARM_PrePopSound.Play(akSender)
	elseif (soundId == EPrePopMessySound)
		LenARM_PrePopMessySound.Play(akSender)
	elseif (soundId == EPopSound)
		LenARM_PopSound.Play(akSender)
	elseif (soundId == EPopMessySound)
		LenARM_PopMessySound.Play(akSender)

	elseif (soundId == EPurgeFailSound)
		LenARM_PurgeFailSound.Play(akSender)
	elseif (soundId == EFullGroanSound)
		LenARM_FullGroanSound.Play(akSender)
	elseif (soundId == EBloatSuitMilkSound)
		LenARM_BloatSuitMilkSound.Play(akSender)
	elseif (soundId == ENPCPopComment)
		LenARM_NPCPopComment.Play(akSender)
	elseif (soundId == EFXBloatHitSound_High)
		LenARM_FXBloatHitSound_High.Play(akSender)
	endif
EndFunction

; 
; @akSender plays sound effect with id @soundId and wait for its completion before continuing
; 
Function ActorPlaySoundAndWait(Actor akSender, int soundId)
	if (soundId == EMorphSound_Low)
		LenARM_MorphSound.PlayAndWait(akSender)
	elseif (soundId == EMorphSound_Medium)
		LenARM_MorphSound_Med.PlayAndWait(akSender)
	elseif (soundId == EMorphSound_High)
		LenARM_MorphSound_High.PlayAndWait(akSender)
	elseif (soundId == EMorphSound_Full)
		LenARM_FullSound.PlayAndWait(akSender)

	elseif (soundId == EMorphSound_Swell)
		LenARM_SwellSound.PlayAndWait(akSender)
	elseif (soundId == EMorphSound_SwellPop)
		LenARM_SwellPopSound.PlayAndWait(akSender)

	elseif (soundId == EDropClothesSound)
		LenARM_DropClothesSound.PlayAndWait(akSender)
	elseif (soundId == ERadPerkSwitchSound)
		LenARM_RadPerkSwitchSound.PlayAndWait(akSender)

	elseif (soundId == EPrePopSound)
		LenARM_PrePopSound.PlayAndWait(akSender)
	elseif (soundId == EPrePopMessySound)
		LenARM_PrePopMessySound.PlayAndWait(akSender)
	elseif (soundId == EPopSound)
		LenARM_PopSound.PlayAndWait(akSender)
	elseif (soundId == EPopMessySound)
		LenARM_PopMessySound.PlayAndWait(akSender)

	elseif (soundId == EPurgeFailSound)
		LenARM_PurgeFailSound.PlayAndWait(akSender)
	elseif (soundId == EFullGroanSound)
		LenARM_FullGroanSound.PlayAndWait(akSender)
	elseif (soundId == EBloatSuitMilkSound)
		LenARM_BloatSuitMilkSound.PlayAndWait(akSender)
	elseif (soundId == ENPCPopComment)
		LenARM_NPCPopComment.PlayAndWait(akSender)
	elseif (soundId == EFXBloatHitSound_High)
		LenARM_FXBloatHitSound_High.PlayAndWait(akSender)
	endif
EndFunction
