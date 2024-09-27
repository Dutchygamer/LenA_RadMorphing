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

        ; player should not be in VATS, not be in a conversation and not be trading
        If (!isInVATS && !isInScene && !isInTrade)
            CastSpellAndStartTimer()
        ; if so, put on the queue and retry after a second
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
	
        float timer = Utility.RandomFloat(CastTimerInterval_Min, CastTimerInterval_Max)
		startTimer(timer, castTimerId)
	endif
EndFunction

Event OnTimer(int aiTimerID)		
	If (aiTimerID == castTimerId)
		TryCastSpellAndStartTimer()
    ElseIf (aiTimerID == equipDelayTimerId)
		TryCastSpellAndStartTimer()
	EndIf
EndEvent
