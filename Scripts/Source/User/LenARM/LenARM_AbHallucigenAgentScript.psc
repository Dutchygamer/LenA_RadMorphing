Scriptname LenARM:LenARM_AbHallucigenAgentScript extends ActiveMagicEffect

; ------------------------
; ------------------------
; MagicEffect input params

; -- AbLegendaryScript public props --
SPELL Property LegendaryPowerUp Auto Const
ActorValue Property Health Auto Const
Float Property HealthThreshhold Auto Const

; -- RobotSelfDestructScript public props --
weapon Property SelfDestructBot Auto Const
SPELL Property crCoreMeltdownCloak01 Auto Const
ActorValue property SpeedMult Auto const

; -- other public props --
LenARM_BloatNPC Property LenARM_BloatNPC Auto
LenARM_Perks Property LenARM_Perks Auto Const
actorValue property NPCBloatStage auto	
actorValue property NPCBloatImmunity auto	
weapon[] property WeaponsToUnequip auto	
Sound Property HazardSound Auto Const
actorValue property Confidence auto const
CombatStyle Property csBerserker Auto Const
Idle property InjectIdle Auto Const


; ------------------------
; ------------------------
; variables

int ChaseSpeed = 140
Actor victim
int HazardSoundId = 0
float ChanceToBerserk = 0.5 Const
bool PoweredUp = false
; int PopTimerId = 1337


; ------------------------
; ------------------------
; methods

; default state; waiting to trigger legendary effect
auto State Waiting

    Event OnHit(ObjectReference akTarget, ObjectReference akAggressor, Form akSource, Projectile akProjectile, bool abPowerAttack, bool abSneakAttack, bool abBashAttack, bool abHitBlocked, string apMaterial)
        ;TODO NPCBloatStage wordt pas na hit bijgewerkt, check op projectile (en bloat explosions)?
        ; ^ gaat beide niet echt gezien het een magic effect is die het bloaten start
    	; actor selfRef = self.GetTargetActor()
        ; int currentBloatStage = (selfRef.getValue(NPCBloatStage) as int)
	    ; Debug.Notification(currentBloatStage)
        bool forceBloat = false ;currentBloatStage > 3

        if ((akTarget.GetValuePercentage(Health) < HealthThreshhold || forceBloat) && PoweredUp == false)
            
            float ChanceRoll = Utility.RandomFloat(0, 1)

            if (ChanceToBerserk >= ChanceRoll || forceBloat)
                PoweredUp = true
                LegendaryPowerUp.cast(akTarget, akTarget)
                UnregisterForAllHitEvents()
                goTostate("SelfDestruct")
            endif
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

        ;TODO doet niets?
        selfRef.PlayIdle(InjectIdle)
		utility.wait(1)
        selfRef.SetValue(SpeedMult, ChaseSpeed)
        ;TODO kan alleen met Actor als base script
        ; SetCombatStyle(csBerserker)
        selfRef.setValue(confidence, 4) ; go aggressive
                
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
    if (sex == LenARM_BloatNPC.ESexFemale)
	    RegisterForHitEvent(akCaster)     
    endif
EndEvent

;self destruct process start
Function startSelfDestructAndWait(Actor selfRef)
    ; remove all potential NPC weapons and force-switch to fake weapon so they run after you
    bool hasUnequipped = False
    int i = 0
    While (!hasUnequipped && (i < WeaponsToUnequip.Length))        
        if (selfRef.IsEquipped(WeaponsToUnequip[i]))
            selfRef.removeitem(WeaponsToUnequip[i], 1, true)
            hasUnequipped = True
        endif
        i = i + 1
    EndWhile

    selfRef.equipItem(SelfDestructBot, true, true)
    ; add a hazard field
    selfRef.AddSpell(crCoreMeltdownCloak01)
    HazardSoundId = HazardSound.Play(selfRef)

    ; make ourselves immune to further bloating until we are done
    selfRef.SetValue(NPCBloatImmunity, 1)

    ; start bloating
    int currentBloatStage = (selfRef.getValue(NPCBloatStage) as int)
    LenARM_BloatNPC.BloatActorMessy(selfRef, currentBloatStage, 6)
endFunction

; ;Do whatever is necessary to allow the robot to Self-Destruct again.
; ;Scripts that extend this one will likely need to implement their own variants.
; Function ResetSelfDestruct()
;     GoToState("Waiting")
;     Actor selfRef = self.GetTargetActor()
;     selfRef.RemoveSpell(crCoreMeltdownCloak01)
; EndFunction


; Function PopActor()
;     actor selfRef = self.GetTargetActor()

;     ; start bloating
;     int currentBloatStage = (selfRef.getValue(NPCBloatStage) as int)
;     LenARM_BloatNPC.BloatActorLegendary(selfRef, currentBloatStage, 6)
; EndFunction




; when done unregister remote events
Event OnEffectFinish(Actor akTarget, Actor akCaster)
	; LenARM_Debug.TechnicalNote(""NPCBloatScript finished!")
    UnRegisterForRemoteEvent(akTarget as ObjectReference, "OnUnload")
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
    ; reset bloating immunity
    akTarget.SetValue(NPCBloatImmunity, 0)

    if (HazardSoundId != 0)
        Sound.StopInstance(HazardSoundId)
    EndIf 
EndFunction
