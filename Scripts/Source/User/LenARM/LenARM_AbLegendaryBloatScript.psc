Scriptname LenARM:LenARM_AbLegendaryBloatScript extends ActiveMagicEffect

; -- AbLegendaryScript public props --
SPELL Property LegendaryPowerUp Auto Const
ActorValue Property Health Auto Const
Float Property HealthThreshhold Auto Const
Message Property LegendaryPowerUpMsg Auto Const
Sound Property PowerUpSound Auto Const
bool Property PoweredUp Auto

; -- RobotSelfDestructScript public props --
weapon Property SelfDestructBot Auto Const
SPELL Property crCoreMeltdownCloak01 Auto Const
ActorValue  property SpeedMult Auto const

; -- other public props --
LenARM_Main Property LenARM_Main Auto
actorValue property NPCBloatStage auto	
actorValue property NPCBloatImmunity auto	
weapon property NPCBloatGun auto	

; -- internal props --
int ChaseSpeed = 140
Actor victim

; default state; waiting to trigger legendary effect
auto State Waiting

    Event OnHit(ObjectReference akTarget, ObjectReference akAggressor, Form akSource, Projectile akProjectile, bool abPowerAttack, bool abSneakAttack, bool abBashAttack, bool abHitBlocked, string apMaterial)
        if akTarget.GetValuePercentage(Health) < HealthThreshhold && PoweredUp == false
            LegendaryPowerUp.cast(akTarget, akTarget)
            if (akTarget as Actor).GetCombatTarget() == Game.GetPlayer()
                LegendaryPowerUpMsg.Show()
                PowerUpSound.Play(akTarget)
            endif
            PoweredUp = true
            UnregisterForAllHitEvents()
            goTostate("SelfDestruct")
        else
            RegisterForHitEvent(akTarget)
        endif
    EndEvent

    Event OnEffectFinish(Actor akTarget, Actor akCaster)
        UnregisterForHitEvent(akCaster)
    EndEvent

endState

; legendary effect triggered, selfdestruct mode engaged
state SelfDestruct
    Event OnBeginState(string asOldState)
    	actor selfRef = self.GetTargetActor()
        ;let the actor change states from attacking to give the player a hint something changed
        selfRef.SetValue(SpeedMult, ChaseSpeed) 
        
        startSelfDestructAndWait(selfRef)
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
    if (sex == LenARM_Main.ESexFemale)
	    RegisterForHitEvent(akCaster)     
    endif
EndEvent

;self destruct process start
Function startSelfDestructAndWait(Actor selfRef)
    ; remove bloatgun and force-switch to fake weapon so they run after you
    if(selfRef.IsEquipped(NPCBloatGun))
        selfRef.removeitem(NPCBloatGun, 1, true)
    endif
    selfRef.equipItem(SelfDestructBot, true, true)
    ; add a hazard field
    selfRef.AddSpell(crCoreMeltdownCloak01)
    
    ;TODO set confidence?

    ; make ourselves immune to further bloating until we are done
    selfRef.SetValue(NPCBloatImmunity, 1)

    ; start bloating
    int currentBloatStage = (selfRef.getValue(NPCBloatStage) as int)
    LenARM_Main.BloatActorLegendary(selfRef, currentBloatStage, 6)

endFunction

;Do whatever is necessary to allow the robot to Self-Destruct again.
;Scripts that extend this one will likely need to implement their own variants.
Function ResetSelfDestruct()
    GoToState("Waiting")
    Actor selfRef = self.GetTargetActor()
    selfRef.RemoveSpell(crCoreMeltdownCloak01)
EndFunction



; when done unregister remote events
Event OnEffectFinish(Actor akTarget, Actor akCaster)
	; LenARM_Main.TechnicalNote(""NPCBloatScript finished!")
    UnRegisterForRemoteEvent(akTarget as ObjectReference, "OnUnload")
EndEvent


; when unloading the actor / actor dies reset a bunch of things so it doesn't get stuck when respawning
Event ObjectReference.OnUnload(ObjectReference akSender)
    Actor akTarget = (akSender as Actor)
    ResetActor(akTarget)
endEvent

EVENT OnDying(ACTOR akKiller)
	; LenARM_Main.TechnicalNote("DEAD")
    ResetActor(victim)
ENDEVENT


Function ResetActor(Actor akTarget)
	; LenARM_Main.TechnicalNote("reset!")
    
    ; clear overlays
    LenARM_Main.ClearAllRadsPerks(akTarget)
    ; reset bloating immunity
    akTarget.SetValue(NPCBloatImmunity, 0)

    ; disspell yourself when done with resetting
    self.Dispel()
EndFunction
