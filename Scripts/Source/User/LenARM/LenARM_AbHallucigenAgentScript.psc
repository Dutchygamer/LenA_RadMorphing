Scriptname LenARM:LenARM_AbHallucigenAgentScript extends ActiveMagicEffect

; ------------------------
; ------------------------
; MagicEffect input params

ActorValue Property Health Auto Const
Float Property HealthThreshhold Auto Const
LenARM_BloatNPC Property LenARM_BloatNPC Auto
LenARM_Perks Property LenARM_Perks Auto Const
actorValue property NPCBloatStage auto


; ------------------------
; ------------------------
; variables

Actor victim
float ChanceToBerserk = 0.5 Const
bool PoweredUp = false


; ------------------------
; ------------------------
; methods

; default state; waiting to trigger legendary effect
auto State Waiting

    Event OnHit(ObjectReference akTarget, ObjectReference akAggressor, Form akSource, Projectile akProjectile, bool abPowerAttack, bool abSneakAttack, bool abBashAttack, bool abHitBlocked, string apMaterial)
        ;TODO check of niet al aan bloaten, doe dan niets en re-register ook niet

        if ((akTarget.GetValuePercentage(Health) < HealthThreshhold) && PoweredUp == false)            
            float ChanceRoll = Utility.RandomFloat(0, 1)

            if (ChanceToBerserk >= ChanceRoll)
                PoweredUp = true
                ; LegendaryPowerUp.cast(akTarget, akTarget)
                victim = self.GetTargetActor()
                UnregisterForAllHitEvents()
                goTostate("SelfDestruct")
            endif
        else
            RegisterForHitEvent(akTarget)
        endif
    EndEvent

    Event OnEffectFinish(Actor akTarget, Actor akCaster)
        ; UnregisterForHitEvent(akCaster)
        UnregisterForHitEvent(akCaster)
	    ; UnRegisterForRemoteEvent(akCaster, "OnItemEquipped") ;for hunger effects
    EndEvent

endState

; legendary effect triggered, selfdestruct mode engaged
state SelfDestruct
    Event OnBeginState(string asOldState)
    	actor selfRef = self.GetTargetActor()

        ; start bloating
        int currentBloatStage = (selfRef.getValue(NPCBloatStage) as int)
        ; LenARM_BloatNPC.BloatActorMessy(selfRef, currentBloatStage, 6)
        LenARM_BloatNPC.BloatActorLegendary(selfRef, currentBloatStage, 6)        
    EndEvent    
endState

; ded, do nothing
state Done
    Event OnCripple(ActorValue akActorValue, bool abCrippled)
        ;do nothing
        
    endEvent
endState

;--------------------------------------------------

Event OnEffectStart(Actor akTarget, Actor akCaster)
	int sex = akTarget.GetLeveledActorBase().GetSex()
    ; for now only work on females
    if (sex == LenARM_BloatNPC.ESexFemale)
	    RegisterForHitEvent(akCaster)     
		; RegisterForRemoteEvent(akCaster, "OnItemEquipped") ;for hunger effects
    endif
EndEvent


;TODO waarom doen we dit zowel hiero als in Waiting state?
; when done unregister remote events
Event OnEffectFinish(Actor akTarget, Actor akCaster)
	; LenARM_Debug.TechnicalNote(""NPCBloatScript finished!")
    UnRegisterForRemoteEvent(akTarget as ObjectReference, "OnUnload")
    ; UnregisterForHitEvent(akCaster)
    ; UnRegisterForRemoteEvent(akCaster, "OnItemEquipped") ;for hunger effects
EndEvent


; when unloading the actor / actor dies reset a bunch of things so it doesn't get stuck when respawning
Event ObjectReference.OnUnload(ObjectReference akSender)
    Actor akTarget = (akSender as Actor)
    ResetActor(akTarget)

    ; dispel yourself when done with resetting
    self.Dispel()
endEvent

EVENT OnDying(ACTOR akKiller)
	; LenARM_Debug.TechnicalNote("DEAD")
    ResetActor(victim)
ENDEVENT


Function ResetActor(Actor akTarget)
	; LenARM_Debug.TechnicalNote("reset!")    
    ; clear overlays
    LenARM_Perks.ClearAllRadsPerks(akTarget)
    ;TODO dit kan dus niet gezien akTarget al dood is?
    ; ; reset bloating immunity
    ; akTarget.SetValue(NPCBloatImmunity, 0)

    ; if (HazardSoundId != 0)
    ;     Sound.StopInstance(HazardSoundId)
    ; EndIf 
EndFunction
