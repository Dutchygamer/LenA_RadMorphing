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
	if IsBoundGameObjectAvailable() ; is effect still running on a legit object?
		actor akTarget = self.GetTargetActor()
		if (SoundLoopID) ; nullcheck in case the sound hasn't started yet
			Sound.StopInstance(SoundLoopID)
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
