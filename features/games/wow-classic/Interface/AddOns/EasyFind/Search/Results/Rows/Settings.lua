local _, ns = ...

local Search = ns.Search
local Results = ns.Results
local Rows = ns.ResultRows

local sformat, unpack = ns.Utils.sformat, ns.Utils.unpack
local GetActionBarToggles, SetActionBarToggles = GetActionBarToggles, SetActionBarToggles
local GetActionBarPage = C_ActionBar and C_ActionBar.GetActionBarPage
local CreateFrame, UIParent, InCombatLockdown = CreateFrame, UIParent, InCombatLockdown



local BAR_TOGGLE_INDEX = {
    PROXY_SHOW_ACTIONBAR_2 = 1, PROXY_SHOW_ACTIONBAR_3 = 2, PROXY_SHOW_ACTIONBAR_4 = 3,
    PROXY_SHOW_ACTIONBAR_5 = 4, PROXY_SHOW_ACTIONBAR_6 = 5, PROXY_SHOW_ACTIONBAR_7 = 6,
    PROXY_SHOW_ACTIONBAR_8 = 7,
}





local SECURE_OPTIONS = {
    PROXY_STATUS_TEXT = {
        ["1"] = "/console statusTextDisplay NUMERIC\n/console statusText 1",
        ["2"] = "/console statusTextDisplay PERCENT\n/console statusText 1",
        ["3"] = "/console statusTextDisplay BOTH\n/console statusText 1",
        ["4"] = "/console statusTextDisplay NONE\n/console statusText 0",
    },
}

function Rows.SecureOptionMacro(variable, value)
    local macros = SECURE_OPTIONS[variable]
    return macros and macros[tostring(value)] or nil
end




local optionPad
local hookedTargets = setmetatable({}, { __mode = "k" })

local function HideOptionPad()
    if not (optionPad and optionPad:IsShown()) or InCombatLockdown() then return end
    local target = optionPad.target
    if target and target.UnlockHighlight then target:UnlockHighlight() end
    optionPad:Hide()
    optionPad:ClearAllPoints()
    optionPad.target, optionPad.after = nil, nil
end
Rows.HideOptionPad = HideOptionPad


function Rows.ArmOptionPad(target, variable, value, after)
    local macro = Rows.SecureOptionMacro(variable, value)
    if not macro or InCombatLockdown() then return false end
    if not optionPad then

        optionPad = CreateFrame("Button", "EasyFindSettingOptionPad", UIParent, "SecureActionButtonTemplate")
        optionPad:RegisterForClicks("LeftButtonUp")
        optionPad:SetAttribute("useOnKeyDown", false)
        optionPad:SetAttribute("type", "macro")
        optionPad:SetScript("PostClick", function(self)
            if self.after then self.after() end
        end)
        optionPad:SetScript("OnLeave", HideOptionPad)
        ns.Utils.RegisterClickGuard(optionPad)
        local combat = CreateFrame("Frame")
        combat:RegisterEvent("PLAYER_REGEN_DISABLED")
        combat:SetScript("OnEvent", HideOptionPad)
        optionPad:Hide()
    end
    if not hookedTargets[target] then
        hookedTargets[target] = true
        target:HookScript("OnHide", function(self)
            if optionPad.target == self then HideOptionPad() end
        end)
    end
    if optionPad.target and optionPad.target ~= target and optionPad.target.UnlockHighlight then
        optionPad.target:UnlockHighlight()
    end
    optionPad:ClearAllPoints()
    optionPad:SetAllPoints(target)
    optionPad:SetFrameStrata(target:GetFrameStrata())
    optionPad:SetFrameLevel(target:GetFrameLevel() + 2)
    optionPad:SetAttribute("macrotext", macro)
    optionPad.target, optionPad.after = target, after
    if target.LockHighlight then target:LockHighlight() end
    optionPad:Show()
    return true
end




local customSettings = {}
function Rows:RegisterCustomSetting(variable, control) customSettings[variable] = control end


function Rows:CustomSetting(variable) return variable and customSettings[variable] or nil end

local function ReadSettingVariable(variable)
    local custom = customSettings[variable]
    if custom then
        local ok, value = pcall(custom.get)
        if ok then return value end
        return nil
    end
    do
        local settObj = ns.Utils.FindSetting(variable)
        if settObj and settObj.GetValue then
            local vok, value = pcall(settObj.GetValue, settObj)
            if vok then return value end
        end
    end
    if GetCVar then
        local ok, value = pcall(GetCVar, variable)
        if ok then return value end
    end
end

local function WriteSettingVariable(variable, value)
    if BAR_TOGGLE_INDEX[variable] or SECURE_OPTIONS[variable] then return false end
    local custom = customSettings[variable]
    if custom then return (pcall(custom.set, value)) end




    do
        local settObj = ns.Utils.FindSetting(variable)
        if settObj and settObj.SetValue then





            local writeValue = value
            if settObj.GetVariableType then
                local tok, vtype = pcall(settObj.GetVariableType, settObj)
                if tok and type(vtype) == "string" then
                    if vtype == "number" then
                        writeValue = tonumber(value) or value
                    elseif vtype == "string" then
                        writeValue = tostring(value)
                    elseif vtype == "boolean" then
                        if type(value) == "boolean" then
                            writeValue = value
                        elseif value == "1" or value == 1 or value == "true" then
                            writeValue = true
                        elseif value == "0" or value == 0 or value == "false" then
                            writeValue = false
                        end
                    end
                end
            end
            if pcall(settObj.SetValue, settObj, writeValue) then




                if ns.BlizzOptionsSearch and ns.BlizzOptionsSearch.NotePendingApply then
                    ns.BlizzOptionsSearch:NotePendingApply(variable)
                end


                if settObj.GetValue then
                    local rok, raw = pcall(settObj.GetValue, settObj)
                    if rok and (raw == writeValue or tostring(raw) == tostring(writeValue)) then
                        return true
                    end
                else
                    return true
                end
            end
        end
    end



    if SetCVar then
        local cvarVal
        if type(value) == "boolean" then
            cvarVal = value and "1" or "0"
        else
            cvarVal = tostring(value)
        end
        if pcall(SetCVar, variable, cvarVal) then return true end
    end
    return false
end

function Rows:ReadSettingVariable(variable)
    return ReadSettingVariable(variable)
end

function Rows:WriteSettingVariable(variable, value)
    return WriteSettingVariable(variable, value)
end



local function RefreshResultsKeepFocus()
    Search:RefreshResults()
    if Search:GetSearchFrame() and Search:GetSearchFrame().editBox
       and not (Search:GetNavFrame() and Search:GetNavFrame():IsKeyboardEnabled()) then
        Search:GetSearchFrame().editBox.blockFocus = nil
        Search:GetSearchFrame().editBox:SetFocus()
    end
end



local function ShowSettingState(results, var, isOn)
    if isOn == nil then return end
    local token = { var = var, isOn = isOn }
    results._settingOptimistic = token
    ns.Utils.SafeAfter(0.6, function()
        if results._settingOptimistic == token then results._settingOptimistic = nil end
    end)
end




function Results:ToggleSettingCheckbox(data)
    if not data or not data.settingVariable then return end
    local var = data.settingVariable
    local curVal = Rows:ReadSettingVariable(var)
    local newOn
    if type(curVal) == "boolean" then
        Rows:WriteSettingVariable(var, not curVal)
        newOn = not curVal
    elseif curVal == "1" or curVal == "0" then
        Rows:WriteSettingVariable(var, curVal == "1" and "0" or "1")
        newOn = curVal == "0"
    elseif curVal == "true" or curVal == "false" then
        Rows:WriteSettingVariable(var, curVal == "true" and "false" or "true")
        newOn = curVal == "false"
    elseif curVal == 1 or curVal == 0 then
        Rows:WriteSettingVariable(var, curVal == 1 and 0 or 1)
        newOn = curVal == 0
    end
    ShowSettingState(self, var, newOn)
    RefreshResultsKeepFocus()
end

function Rows.IsBarToggle(variable)
    return BAR_TOGGLE_INDEX[variable] ~= nil
end



function Rows.BarRedrawMacro()
    local page = GetActionBarPage()
    return sformat("/changeactionbar [nocombat] %d\n/changeactionbar [nocombat] %d", page == 1 and 2 or 1, page)
end


function Rows.FlipBarToggle(variable)
    local index = BAR_TOGGLE_INDEX[variable]
    local toggles = { GetActionBarToggles() }
    if not index or index > #toggles then return nil end
    toggles[index] = not toggles[index]
    SetActionBarToggles(unpack(toggles))
    return toggles[index]
end


function Results:ShowBarToggle(variable, isOn)
    ShowSettingState(self, variable, isOn)
    RefreshResultsKeepFocus()
end

local function ActivateSettingResult(data, openMenuHeld)
    if not data then return false end





    if data.settingType == "keybind" and data.bindingAction
       and (not openMenuHeld or data.customToggle)
       and ns.BlizzOptionsSearch
       and ns.BlizzOptionsSearch:PerformBinding(data.bindingAction) then
        RefreshResultsKeepFocus()
        return true
    end

    if data.settingPress and not openMenuHeld then
        xpcall(data.settingPress, ns.Utils.ErrorHandler)
        RefreshResultsKeepFocus()
        return true
    end
    if not data.settingVariable then return false end
    local stype = data.settingType
    if (stype == "checkbox" or stype == "checkboxSlider" or stype == "checkboxDropdown")
       and not openMenuHeld and not BAR_TOGGLE_INDEX[data.settingVariable] then




        Results:ToggleSettingCheckbox(data)
        return true
    end


    return false
end

function Rows:ActivateSettingResult(data, openMenuHeld)
    return ActivateSettingResult(data, openMenuHeld)
end
