ScriptName Fragments:LenARM:TERM_LenARM_ShowMorphLevels extends Terminal hidden const

LenARM:LenARM_Main Property LenARM_Main Auto Const

Function Fragment_Terminal_01(ObjectReference akTerminalRef)
    float lowestPercentage = LenARM_Main.GetLowestSliderPercentage()
    bool hasHadMoleCowDisease = LenARM_Main.GetHasHadMoleCowDisease()

    string displayText = "No bloating detected!"
    string moleCowTextAddition = " Molecow disease causes gentle lactation."
    ; TODO onderstaand klopt niet; zit over 90% maar toch krijg ik eerste bericht
    if (lowestPercentage > 0 && lowestPercentage < 0.2)
        displayText = "Your clothes definitely feel tighter then they used to." ;Radmorphed (Puffy) - Your clothes definitely feel tighter then they used to. +1 Charisma
        if (hasHadMoleCowDisease)
            displayText += moleCowTextAddition
        endif
    elseif (lowestPercentage >= 0.2 && lowestPercentage < 0.4)
        displayText = "A new wardrobe might be neccesary in the future." ;Radmorphed (Bulging) - A new wardrobe might be neccesary in the future. +2 Charisma
        if (hasHadMoleCowDisease)
            displayText += moleCowTextAddition
        endif
    elseif (lowestPercentage >= 0.4 && lowestPercentage < 0.6)
        displayText = "You feel more sluggish, but the curves make up for it." ;Radmorphed (Swollen) - You feel more sluggish, but the curves make up for it. +2 Charisma, -1 Agility
        if (hasHadMoleCowDisease)
            displayText += moleCowTextAddition
        endif
    elseif (lowestPercentage >= 0.6 && lowestPercentage < 0.8)
        displayText = "The increased sensitivity makes it harder to focus. You are slowly lactating!" ;Radmorphed (Bloated) - The increased sensitivity makes it harder to focus. +2 Charisma, -1 Agility, -1 Perception, -5 Rad Resist
    elseif (lowestPercentage >= 0.8 && lowestPercentage < 1.0)
        displayText = "You feel like you are nearing your limits, but it feels so good. You are steadily lactating and are too big to interact with Power Armor!" ;Radmorphed (Ballooned) - You feel like you are nearing your limits, but it feels so good. +3 Charisma, -2 Agility, -1 Intelligence, -1 Perception, -10 Rad Resist, Reduced AP Refresh, Blocks Power Armor usage
    else
        displayText = "Your body feels as tight as a drum, which feels wonderful! You are heavily lactating and are too big to interact with Power Armor!" ;Radmorphed (Maxed-out) - Your body feels as tight as a drum, which feels wonderful! +3 Charisma, -3 Agility, -2 Intelligence, -1 Perception, -10 Rad Resist, Reduced AP Refresh, More easy to detect when sneaking, Blocks Power Armor usage
    endif

	; LenARM_Main.MessageBox("You are " + (lowestPercentage * 100) + "% bloated!")
	LenARM_Main.MessageBox(displayText)
EndFunction