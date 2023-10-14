ScriptName LenARM:LenARM_NPCBloatScript extends ActiveMagicEffect

LenARM_Main Property LenARM_Main Auto
actorValue property NPCBloatStage auto
actorValue property NPCBloatQueue auto
actorValue property NPCBloatImmunity auto
int property StageToAdd = 1 auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
    ; when in Power Armor, dead or immune to bloating don't morph
	If (akTarget.IsInPowerArmor() || akTarget.IsDead()); || ((akTarget.getValue(NPCBloatImmunity) as bool) == true))
		return
	EndIf
   
	int sex = akTarget.GetLeveledActorBase().GetSex()

    ; for now only work on females
    if (sex == LenARM_Main.ESexFemale)
        ; check what we have enqueued already
        int currentBloatQueue = (akTarget.getValue(NPCBloatQueue) as int)
        bool shouldTrigger = currentBloatQueue == 0


        ; add the amount of stages to the queue
        ; LenARM_Main.TechnicalNote("current queue: " + currentBloatQueue)
        currentBloatQueue += StageToAdd
        akTarget.SetValue(NPCBloatQueue, currentBloatQueue)
        ; LenARM_Main.TechnicalNote("updated queue: " + currentBloatQueue)
        ; LenARM_Main.TechnicalNote("waiting")
        ; Utility.Wait(3)
        ; LenARM_Main.TechnicalNote("done")

        int currentBloatStage = (akTarget.getValue(NPCBloatStage) as int)
        int expectedBloatStage = currentBloatStage + StageToAdd
        akTarget.SetValue(NPCBloatStage, expectedBloatStage)

        ; LenARM_Main.TechnicalNote("hit! - " + expectedBloatStage)

        ; only trigger the bloat logic when we had nothing enqueued
        ; the idea being that when this logic is already running, it will keep checking the queue on its own
        if (shouldTrigger)
            LenARM_Main.BloatActor(akTarget, currentBloatStage, StageToAdd)
        endif
        ; if (currentBloatQueue > 1)
        ;     LenARM_Main.TechnicalNote("should not trigger action")
        ; else            
        ;     LenARM_Main.TechnicalNote("should trigger action")
        ; endif



        ;TODO original code below
        ; ; make ourselves immune to further bloating until we are done
        ; akTarget.SetValue(NPCBloatImmunity, 1)

        ; int currentBloatStage = (akTarget.getValue(NPCBloatStage) as int)
        ; int expectedBloatStage = currentBloatStage + StageToAdd
        ; akTarget.SetValue(NPCBloatStage, expectedBloatStage)

        ; LenARM_Main.BloatActor(akTarget, currentBloatStage, StageToAdd)

        ; ; after popping, keep us paralyzed for a bit
        ; if (expectedBloatStage > 5)
        ;     akTarget.SetValue(NPCBloatStage, 0)

        ;     ; wait a bit before taking away our immunity
        ;     Utility.Wait(1)
        ;     akTarget.SetValue(NPCBloatImmunity, 0)
        ;     ; unparalyze the npc after a bit, but do leave them open for renewed bloating
        ;     Utility.Wait(9)
        ;     LenARM_Main.UnParalyzeActor(akTarget)
        ; ; else take away our immunity directly
        ; else
        ;     akTarget.SetValue(NPCBloatImmunity, 0)
        ; endif
    endif
EndEvent