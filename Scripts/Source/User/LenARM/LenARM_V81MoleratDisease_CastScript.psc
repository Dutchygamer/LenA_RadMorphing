; taken from Hardcore:HC_EncumbranceEffect_CastScript, with some tweaks of my own
Scriptname LenARM:LenARM_V81MoleratDisease_CastScript extends ActiveMagicEffect

Group Data
spell Property SpellToCast const auto mandatory
{HC_EncumbranceEffect_DamagePlayer}

float Property CastTimerInterval_Min = 10.0 const auto
float Property CastTimerInterval_Max = 30.0 const auto
{how often should we cast the spell on the actor}

message Property MessageToDisplay const auto mandatory
message Property Tutorial_MessageToDisplay const auto mandatory

MagicEffect Property MS19SurpressantEffect Auto

EndGroup

int castTimerId = 159763
int equipDelayTimerId = 159764
bool TutorialDisplayed_MilkSurge = false

Event OnEffectStart(Actor akTarget, Actor akCaster) 
    float timer = Utility.RandomFloat(CastTimerInterval_Min, CastTimerInterval_Max)
	startTimer(timer, castTimerId)
EndEvent

Function TryCastSpellAndStartTimer()
	if IsBoundGameObjectAvailable() ;is effect still running on a legit object?
        actor actorRef = GetTargetActor()
        var isInVATS = (Game.IsMovementControlsEnabled()) == false
        var isInScene = actorRef.IsInScene()
        var isInTrade = Utility.IsInMenuMode()
        var isSuppressed = actorRef.HasMagicEffect(MS19SurpressantEffect)

        ; if player has molecow disease surpressant active, restart the timer
        ; this overrules everything else
        if (isSuppressed)
	        Debug.Trace("[LenARM] Milk surge suppressed, restarting timer")
            RestartCastTimer()
        ; if player is not in VATS, not in a conversation and not trading cast the effect
        elseIf (!isInVATS && !isInScene && !isInTrade)
	        Debug.Trace("[LenARM] Timer-based Milk surge triggered!")
            CastSpellAndStartTimer()
        ; otherwise put in the queue and retry after a second
        Else
            StartTimer(1, equipDelayTimerId)
        EndIf
    EndIf
EndFunction

Function CastSpellAndStartTimer()
	if IsBoundGameObjectAvailable() ;is effect still running on a legit object?
		actor actorRef = GetTargetActor()
		SpellToCast.cast(actorRef, actorRef)
        
        if (!TutorialDisplayed_MilkSurge)
            TutorialDisplayed_MilkSurge = true
            Tutorial_MessageToDisplay.ShowAsHelpMessage("Tutorial_MessageToDisplay", 8, 0, 1)
        else
            MessageToDisplay.show()
        endif
	
        RestartCastTimer()
	endif
EndFunction

Function RestartCastTimer()
    float timer = Utility.RandomFloat(CastTimerInterval_Min, CastTimerInterval_Max)
    startTimer(timer, castTimerId)
EndFunction

Event OnTimer(int aiTimerID)		
	If (aiTimerID == castTimerId)
		TryCastSpellAndStartTimer()
    ElseIf (aiTimerID == equipDelayTimerId)
		TryCastSpellAndStartTimer()
	EndIf
EndEvent
