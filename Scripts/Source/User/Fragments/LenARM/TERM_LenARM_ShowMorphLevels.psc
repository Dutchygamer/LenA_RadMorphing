ScriptName Fragments:LenARM:TERM_LenARM_ShowMorphLevels extends Terminal hidden const

LenARM:LenARM_Main Property LenARM_Main Auto Const

Function Fragment_Terminal_01(ObjectReference akTerminalRef)
    float lowestPercentage = LenARM_Main.GetLowestSliderPercentage()
    bool hasHadMoleCowDisease = LenARM_Main.GetHasHadMoleCowDisease()

    string displayText = "No bloating detected!"
    string moleCowTextAddition = " Molecow disease causes gentle lactation."
    if (lowestPercentage > 0 && lowestPercentage < 20)
        displayText = ""
        if (hasHadMoleCowDisease)
            displayText += moleCowTextAddition
        endif
    elseif (lowestPercentage >= 20 && lowestPercentage < 40)
        displayText = ""
        if (hasHadMoleCowDisease)
            displayText += moleCowTextAddition
        endif
    elseif (lowestPercentage >= 40 && lowestPercentage < 60)
        displayText = ""
        if (hasHadMoleCowDisease)
            displayText += moleCowTextAddition
        endif
    elseif (lowestPercentage >= 60 && lowestPercentage < 80)
        displayText = "You are now gently lactating!"
    elseif (lowestPercentage >= 80 && lowestPercentage < 100)
        displayText = "You are now too big to interact with Power Armor!"
    else
        displayText = ""
    endif

	; LenARM_Main.MessageBox("You are " + (lowestPercentage * 100) + "% bloated!")
	LenARM_Main.MessageBox(displayText)
EndFunction