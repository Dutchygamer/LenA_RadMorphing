Scriptname LenARM:RadShowerScript extends ObjectReference

Sound Property AMBWaterfallTallLP Auto Const
ObjectReference Property ShowerWater Auto Const
ObjectReference Property WaterPuddle Auto Const
Idle Property ShowerAnimation Auto const
Idle Property LooseIdleStop Auto const
Armor Property FCR_NudeArmor Auto Const

Hazard Property hazardToPlace Auto
ObjectReference Property MyHazard Auto Hidden

bool active = false

;TODO triggered niet?
;oh, script zit nog eens aan dat ding gekoppeld via de placed reference, waar alle andere properties eraan worden geknoopt
;dingen zoals de ShowerWater en WaterPuddle zijn references die handmatig geplaatst zijn
Event OnActivate(ObjectReference akActionRef)
	; If (WaterPuddle.Isdisabled())
	If (active == false)
		; ShowerWater.Enable()
		; WaterPuddle.Enable()
		active = true
		Game.GetPlayer().EquipItem(FCR_NudeArmor, True)
		Game.GetPlayer().PlayIdle(ShowerAnimation)
		; int instanceID = AMBWaterfallTallLP.play(WaterPuddle) 

		if (hazardToPlace)
			; for some reason the hazard only properly spawns when placed at the player's POS (using just PlaceAtMe(hazardToPlace) doesn't do anything)
			MyHazard = Game.GetPlayer().PlaceAtMe(hazardToPlace)
		endif
	else
		; ShowerWater.disable()
		; WaterPuddle.Disable()
		active = false
		; int instanceID = AMBWaterfallTallLP.play(self) 
		; Sound.StopInstance(instanceID)
		Game.GetPlayer().RemoveItem(FCR_NudeArmor)
		Game.GetPlayer().PlayIdle(LooseIdleStop)
		if (MyHazard)
			MyHazard.delete()
		endif
	endif
endevent


