ScriptName LenARM:LenARM_MagicEffectSoundLoopScript extends ActiveMagicEffect

Sound Property SoundLoop Auto Const

int castTimerId = 2159753
float CastTimerInterval = 30.0

int SoundLoopID

; as the 'easy' way of just playing the sound on effect start kept stopping for various reasons,
; we now just use a timer which manually restarts the sound every 30s
; not that efficient but it works =/

Event OnEffectStart(Actor akTargetRef, Actor akCaster)
	PlaySoundAndStartTimer()
EndEvent

Event OnEffectFinish(Actor akTargetRef, Actor akCaster)
	Sound.StopInstance(SoundLoopID)
EndEvent


Function PlaySoundAndStartTimer()
	 ; is effect still running on a legit object?
	if IsBoundGameObjectAvailable()

		;TODO gooit steeds errors?
		; [11/16/2024 - 11:51:01AM] error: Unable to call GetTargetActor - no native object bound to the script object, or object is of incorrect type
		; stack:
		; 	[Active effect 1 on  (0A00CFE6)].LenARM:LenARM_MagicEffectSoundLoopScript.GetTargetActor() - "<native>" Line ?
		; 	[Active effect 1 on  (0A00CFE6)].LenARM:LenARM_MagicEffectSoundLoopScript.PlaySoundAndStartTimer() - "D:\Program Files\Steam\steamapps\common\Fallout 4\Data\Scripts\Source\User\LenARM\LenARM_MagicEffectSoundLoopScript.psc" Line 26
		; 	[Active effect 1 on  (0A00CFE6)].LenARM:LenARM_MagicEffectSoundLoopScript.OnTimer() - "D:\Program Files\Steam\steamapps\common\Fallout 4\Data\Scripts\Source\User\LenARM\LenARM_MagicEffectSoundLoopScript.psc" Line 44
		actor akTarget = self.GetTargetActor()
		
		 ; nullcheck in case that for some reason we are not a legit object; we're done
		if (!akTarget)
			return
		endif

		 ; nullcheck in case the sound hasn't started yet
		if (SoundLoopID)
			Sound.StopInstance(SoundLoopID)
		endif
		; when actor is dead, don't restart the sound nor the timer; we're done
		if (akTarget.IsDead())
			return
		endif

		SoundLoopID = SoundLoop.Play(akTarget)
		startTimer(CastTimerInterval, castTimerId)
	endif
EndFunction

Event OnTimer(int aiTimerID)		
	If (aiTimerID == castTimerId)
		PlaySoundAndStartTimer()
	EndIf
EndEvent
