local _, ns = ...

local SecureAttributes = {}
ns.ResultSecureAttributes = SecureAttributes

local Icons = ns.ResultIcons
local Handlers = ns.ResultHandlers
local Utils = ns.Utils
local SecureOpeners = ns.SecureOpeners

local InCombatLockdown = InCombatLockdown
local GetMacroInfo = GetMacroInfo
local GetMacroIndexByName = GetMacroIndexByName



local SPELLBOOK_PANEL = "playerSpells"




local function SetSteer(resultRow, steerTab)



    if resultRow._efSteerTab == steerTab and not resultRow._efReleaseMacro then return end





    Utils.SafeCallMethod(resultRow, "SetAttribute", "pressAndHoldAction", steerTab and true or nil)
    Utils.SafeCallMethod(resultRow, "SetAttribute", "*typerelease1", steerTab and "click" or nil)
    Utils.SafeCallMethod(resultRow, "SetAttribute", "*clickbutton1", steerTab)
    resultRow._efSteerTab = steerTab
    resultRow._efReleaseMacro = nil
end









local function SetReleaseMacro(resultRow, macrotext)
    Utils.SafeCallMethod(resultRow, "SetAttribute", "pressAndHoldAction", true)
    Utils.SafeCallMethod(resultRow, "SetAttribute", "*typerelease1", "macro")
    Utils.SafeCallMethod(resultRow, "SetAttribute", "macrotext", macrotext)
    if resultRow._lastAttrKey == "macrotext" then
        resultRow._lastAttrVal = macrotext
    end
    resultRow._efReleaseMacro = true
end





local function DisarmAction(resultRow)
    if resultRow._lastAttrKey then
        Utils.SafeCallMethod(resultRow, "SetAttribute", resultRow._lastAttrKey, nil)
    end
    Utils.SafeCallMethod(resultRow, "SetAttribute", "type", nil)
    resultRow._lastAttrType = nil
    resultRow._lastAttrKey = nil
    resultRow._lastAttrVal = nil
end

function SecureAttributes.Apply(resultRow, data)
    if InCombatLockdown() then return end








    if not resultRow._efUseOnKeyDown then
        Utils.SafeCallMethod(resultRow, "SetAttribute", "useOnKeyDown", true)
        resultRow._efUseOnKeyDown = true
    end

    resultRow._efSwappedToOpen = nil





    local openKey = data and SecureOpeners and SecureOpeners.OpenKeyForData(data)

    local newType, newKey, newVal
    if data and data.settingVariable and ns.ResultRows.IsBarToggle(data.settingVariable) then

        newType, newKey, newVal = "macro", "macrotext", ns.ResultRows.BarRedrawMacro()
    elseif data and data.toyItemID and not data.isToyboxOnly then



        newType, newKey, newVal = "toy", "toy", data.toyItemID
    elseif data and data.mountID and Icons:IsMountSummonable(data) then
        newType, newKey, newVal = "macro", "macrotext", "/cancelform [form]"
    elseif data and data.outfitID then


        local outfitIndex = Handlers:GetOutfitSecureIndex(data)
        if outfitIndex then
            newType, newKey, newVal = "outfit", "outfit-index", outfitIndex
        end
    elseif data and data.spellID and data.category ~= "Talent"
           and not Icons:IsSpellbookOnlyAbility(data) then



        newType, newKey, newVal = "spell", "spell", data.spellName or data.spellID
    elseif data and data.itemID and data.category == "Bag"
           and not Handlers:IsRemoteStoredItem(data)
           and Handlers:GetBagItemActionKind(data) ~= "show" then
        newType, newKey, newVal = "item", "item", data.name
    elseif data and data.macroIndex and data.category == "Macro" then
        local body = data.macroBody
        if (not body or body == "") and GetMacroInfo then



            local idx = GetMacroIndexByName and data.name
                and GetMacroIndexByName(data.name) or 0
            if not idx or idx == 0 then idx = data.macroIndex end
            local _, _, liveBody = GetMacroInfo(idx)
            body = liveBody
        end
        if body and body ~= "" then
            newType, newKey, newVal = "macro", "macrotext", body
        end
    elseif data and data.slashCommand then
        newType, newKey, newVal = "macro", "macrotext", data.slashCommand
    elseif SecureOpeners and SecureOpeners.ReplacementMacro(data) then
        newType, newKey, newVal = "macro", "macrotext", SecureOpeners.ReplacementMacro(data)
    elseif openKey then


        local openMacro = SecureOpeners.GetOpenMacro(openKey)
        if openMacro then











            local steerTab = SecureOpeners.GetSteerTabButton(openKey, data)
            local tabClick = steerTab
                and SecureOpeners.GetClickChainMacro(steerTab, 1)
            if tabClick then
                openMacro = openMacro .. "\n" .. tabClick
            end
            newType, newKey, newVal = "macro", "macrotext", openMacro
        elseif Handlers.GetSpellbookNavPlan then






            local plan, planReason = Handlers.GetSpellbookNavPlan(data)
            if plan and plan.step == "page" then
                newVal = SecureOpeners.GetClickChainMacro(plan.button, plan.presses)
            elseif plan and plan.step == "category" then
                newVal = SecureOpeners.GetClickChainMacro(plan.button, 1)
            elseif planReason == "spellbook not shown" then


                local steerTab = SecureOpeners.GetSteerTabButton(openKey, data)
                newVal = steerTab
                    and SecureOpeners.GetClickChainMacro(steerTab, 1) or nil
            end
            if newVal then
                newType, newKey = "macro", "macrotext"
            end
        end
    end







    do
        local steerTab = openKey and SecureOpeners.GetSteerTabButton(openKey, data) or nil



        if steerTab and SecureOpeners.IsTabButtonSelected(openKey, steerTab) then
            steerTab = nil
        end
        SetSteer(resultRow, steerTab)
    end

    if resultRow._lastAttrType == newType
       and resultRow._lastAttrKey == newKey
       and resultRow._lastAttrVal == newVal then
        return
    end

    if resultRow._lastAttrKey then
        Utils.SafeCallMethod(resultRow, "SetAttribute", resultRow._lastAttrKey, nil)
    end
    Utils.SafeCallMethod(resultRow, "SetAttribute", "type", newType)
    if newKey then
        Utils.SafeCallMethod(resultRow, "SetAttribute", newKey, newVal)
    end
    resultRow._lastAttrType = newType
    resultRow._lastAttrKey  = newKey
    resultRow._lastAttrVal  = newVal
end




function SecureAttributes.ApplyAtClick(resultRow, data)
    if SecureOpeners then
        SecureOpeners.EnsureLoaded(SecureOpeners.OpenKeyForData(data))
    end
    SecureAttributes.Apply(resultRow, data)
end



function SecureAttributes.FlipBarAtPress(data)
    if InCombatLockdown() or not (data and data.settingVariable) then return nil end
    local Rows = ns.ResultRows
    if not Rows.IsBarToggle(data.settingVariable) then return nil end
    return Rows.FlipBarToggle(data.settingVariable)
end


function SecureAttributes.Clear(resultRow)
    DisarmAction(resultRow)
    resultRow._efSwappedToOpen = nil
    SetSteer(resultRow, nil)
end




function SecureAttributes.ActsOnRelease(button, data)
    return button._efSwappedToOpen
        or (data and SecureOpeners and SecureOpeners.OpenKeyForData(data))
        or nil
end







function SecureAttributes.SwapToPanelOpen(resultRow)
    DisarmAction(resultRow)
    if not SecureOpeners then return end

    local Replacement = ns.SearchOpeners and ns.SearchOpeners.Replacement
    if Replacement and Replacement("spellBook") then
        local openMacro = SecureOpeners.ReplacementOpenMacro("spellBook")
        if openMacro then
            Utils.SafeCallMethod(resultRow, "SetAttribute", "type", "macro")
            Utils.SafeCallMethod(resultRow, "SetAttribute", "macrotext", openMacro)
            resultRow._lastAttrType = "macro"
            resultRow._lastAttrKey = "macrotext"
            resultRow._lastAttrVal = openMacro
        end
        return
    end
    SecureOpeners.EnsureLoaded(SPELLBOOK_PANEL)
    local defaultTab = SecureOpeners.GetDefaultTabButton(SPELLBOOK_PANEL)
    local steerTab = defaultTab
    if steerTab and SecureOpeners.IsTabButtonSelected(SPELLBOOK_PANEL, steerTab) then
        steerTab = nil
    end
    SetSteer(resultRow, steerTab)
    local openMacro = SecureOpeners.GetOpenMacro(SPELLBOOK_PANEL)
    if openMacro then


        local tabClick = defaultTab
            and SecureOpeners.GetClickChainMacro(defaultTab, 1)
        if tabClick then
            openMacro = openMacro .. "\n" .. tabClick
        end
        Utils.SafeCallMethod(resultRow, "SetAttribute", "type", "macro")
        Utils.SafeCallMethod(resultRow, "SetAttribute", "macrotext", openMacro)
        resultRow._lastAttrType = "macro"
        resultRow._lastAttrKey = "macrotext"
        resultRow._lastAttrVal = openMacro
    elseif Handlers.GetSpellbookNavPlan then



        local navPlan = Handlers.GetSpellbookNavPlan(resultRow.data)
        if navPlan and navPlan.step == "page" then
            local chain = SecureOpeners.GetClickChainMacro(navPlan.button, navPlan.presses)
            if chain then
                Utils.SafeCallMethod(resultRow, "SetAttribute", "type", "macro")
                Utils.SafeCallMethod(resultRow, "SetAttribute", "macrotext", chain)
                resultRow._lastAttrType = "macro"
                resultRow._lastAttrKey = "macrotext"
                resultRow._lastAttrVal = chain
                resultRow._efSwappedToOpen = SPELLBOOK_PANEL
                return
            end
        elseif navPlan and navPlan.step == "category" then
            SetSteer(resultRow, navPlan.button)
            resultRow._efSwappedToOpen = SPELLBOOK_PANEL
            return
        end
    end


    resultRow._efSwappedToOpen = SPELLBOOK_PANEL
end













function SecureAttributes.ArmSteerLate(resultRow)
    local data = resultRow.data
    if not (SecureOpeners and data) then return end
    local openKey = SecureOpeners.OpenKeyForData(data) or resultRow._efSwappedToOpen
    if not openKey then return end

    if Handlers.GetSpellbookNavPlan then
        local plan = Handlers.GetSpellbookNavPlan(data)
        if plan and plan.step == "page" then
            local chain = SecureOpeners.GetClickChainMacro(plan.button, plan.presses)
            if chain then
                SetReleaseMacro(resultRow, chain)
                return
            end
        elseif plan and plan.step == "category" then
            SetSteer(resultRow, plan.button)
            return
        end
    end

    local steerTab = resultRow._efSteerTab
    if steerTab then
        if SecureOpeners.IsTabButtonSelected(openKey, steerTab) then
            SetSteer(resultRow, nil)
        end
        return
    end
    steerTab = resultRow._efSwappedToOpen
        and SecureOpeners.GetDefaultTabButton(openKey)
        or SecureOpeners.GetSteerTabButton(openKey, data)
    if steerTab and not SecureOpeners.IsTabButtonSelected(openKey, steerTab) then
        SetSteer(resultRow, steerTab)
    end
end
