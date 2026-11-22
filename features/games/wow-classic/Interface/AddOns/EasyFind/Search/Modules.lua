



































local _, ns = ...

local function EnsureModule(name)
    local module = ns[name]
    if not module then
        module = {}
        ns[name] = module
    end
    return module
end

local MODULE_NAMES = {
    "Search",
    "SearchFocus",
    "SearchHistory",
    "SearchOpeners",
    "SearchProviders",
    "Filters",
    "Calculator",
    "SearchCommands",
    "Results",
    "ResultRows",
    "ResultRender",
    "ResultHandlers",
    "ResultIcons",
    "ResultText",
    "ResultTooltips",
    "ResultShortcuts",
    "OptionsSurface",
    "Onboarding",
    "Guide",
}

local modules = {}
for i = 1, #MODULE_NAMES do
    modules[i] = EnsureModule(MODULE_NAMES[i])
end
local Search = modules[1]

local function FindModuleValue(t, key)
    for i = 1, #modules do
        local value = rawget(modules[i], key)
        if value ~= nil then






            rawset(t, key, value)
            return value
        end
    end
    return nil
end

for i = 1, #modules do
    if modules[i] ~= Search and not getmetatable(modules[i]) then
        setmetatable(modules[i], { __index = FindModuleValue })
    end
end

if not getmetatable(Search) then
    setmetatable(Search, { __index = FindModuleValue })
end








local Calculator = ns.Calculator
local mmin = ns.Utils.mmin

function Calculator:SetCalculatorRoundedFill(frame, r, g, b, a, br, bg, bb, ba)
    ns.SetRoundedRectFill(frame, r, g, b, a, true)
    ns.SetRoundedRectBorderColor(frame, br or 0.30, bg or 0.30, bb or 0.32, ba or 0.85, true)
end

function Calculator:HideCalculatorRoundedBorder(frame)
    ns.SetRoundedRectBorderEdgeShown(frame, false)
end



function Calculator:ThemeFillCalcControl(frame, tbl, fallbackR, fallbackG, fallbackB)
    if tbl then
        self:SetCalculatorRoundedFill(frame, tbl[1], tbl[2], tbl[3], 1)
    else
        self:SetCalculatorRoundedFill(frame, fallbackR, fallbackG, fallbackB, 1)
    end
end



Calculator._styledButtons = setmetatable({}, { __mode = "k" })

function Calculator:StyleCalculatorButton(btn, height)
    if not btn then return end
    if not btn.combinedBorder then
        ns.CreateRoundedRectBorder(btn)
    end
    ns.SetRoundedRectBarHeight(btn, mmin(height or btn:GetHeight() or 22, 10))
    ns.SetRoundedRectBorderBgAlpha(btn, 1)
    self:HideCalculatorRoundedBorder(btn)
    Calculator._styledButtons[btn] = true
    self:ThemeFillCalcControl(btn, ns.BTN_FILL_NORMAL, 0.095, 0.095, 0.108)
    btn:SetScript("OnEnter", function(self)
        if self:IsEnabled() then
            Calculator:ThemeFillCalcControl(self, ns.BTN_FILL_HOVER, 0.155, 0.155, 0.172)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if self:IsEnabled() then
            Calculator:ThemeFillCalcControl(self, ns.BTN_FILL_NORMAL, 0.095, 0.095, 0.108)
        end
    end)
    btn:SetScript("OnMouseDown", function(self)
        if self:IsEnabled() then
            Calculator:ThemeFillCalcControl(self, ns.BTN_FILL_PRESSED, 0.065, 0.065, 0.078)
        end
    end)
    btn:SetScript("OnMouseUp", function(self)
        if not self:IsEnabled() then return end
        if self:IsMouseOver() then
            Calculator:ThemeFillCalcControl(self, ns.BTN_FILL_HOVER, 0.155, 0.155, 0.172)
        else
            Calculator:ThemeFillCalcControl(self, ns.BTN_FILL_NORMAL, 0.095, 0.095, 0.108)
        end
    end)
end






function Calculator:ArmCalculatorPartFromRow() end
function Calculator:ArmCalculatorResultForData() end
function Calculator:ArmCalculatorResultFromRow() end
function Calculator:ArmCalculatorSelectionForKeyboard() end
function Calculator:ClearCalculatorCopyHighlight() end
function Calculator:ConfirmCalculatorCopied() end
function Calculator:EvaluateCalculatorExpression() end
function Calculator:GetCalculatorLauncherMatch() end
function Calculator:HandleCalculatorCopyConfirmKey() end
function Calculator:HandleCalculatorCopyKey() end
function Calculator:HandleCalculatorOpenShortcut() end
function Calculator:HandleCalculatorPasteIntoSearch() end
function Calculator:HoverCalculatorTarget() end
function Calculator:IsCalculatorCopyConfirmKey() end
function Calculator:IsCalculatorCopyKey() end
function Calculator:OpenCalculator() end
function Calculator:RearmActiveCalculatorCopy() end
function Calculator:ReleaseCalculatorCopyBox() end
function Calculator:RestoreCalculatorTarget() end
function Calculator:SetCalculatorCopyHighlight() end






local INTENTIONAL_DUPLICATE_KEYS = {
    IsBossResultData = true,
    AbbrevBinding = true,
    SetClippedText = true,
}

local duplicateKeyChecker = CreateFrame("Frame")
duplicateKeyChecker:RegisterEvent("PLAYER_LOGIN")
duplicateKeyChecker:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if not (EasyFind and EasyFind.db and EasyFind.db.devMode) then return end
    if not (ns.Utils and ns.Utils.DebugPrint) then return end
    local firstOwner = {}
    for i = 1, #modules do
        for key in pairs(modules[i]) do
            if not INTENTIONAL_DUPLICATE_KEYS[key] then
                if firstOwner[key] then
                    ns.Utils.DebugPrint("Duplicate Search module key '" .. tostring(key)
                        .. "' on " .. firstOwner[key] .. " and " .. MODULE_NAMES[i])
                else
                    firstOwner[key] = MODULE_NAMES[i]
                end
            end
        end
    end
end)










local companionWarned = {}
local function LoadCompanion(addon)
    if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, addon) end
end

local function WarnCompanion(addon, disabledKey)
    if companionWarned[addon] then return end
    companionWarned[addon] = true
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addon) then
        local title = C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addon, "Title") or addon
        EasyFind:Print(ns.L["COMPANION_INCOMPLETE_FMT"]:format(title))
    else
        EasyFind:Print(ns.L[disabledKey])
    end
end

function ns.RequestIconSearch()
    if ns.Results.ShowIconGrid then return true end
    if InCombatLockdown() or not ns.Caps.iconSearch then return false end
    LoadCompanion("EasyFind_Icons")
    if ns.Results.ShowIconGrid then return true end
    WarnCompanion("EasyFind_Icons", "ICON_MODULE_DISABLED")
    return false
end




function ns.RequestNotes()
    if ns.Notes then return true end

    if ns.ExtensionInstalled and not ns.ExtensionInstalled("EasyFind_Notes") then
        if not companionWarned.EasyFind_Notes then
            companionWarned.EasyFind_Notes = true
            ns.TellExtensionGone("EasyFind_Notes")
        end
        return false
    end
    LoadCompanion("EasyFind_Notes")
    if ns.Notes then return true end
    WarnCompanion("EasyFind_Notes", "NOTES_MODULE_DISABLED")
    return false
end


do
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        if not (EasyFind.db and EasyFind.db.notesInUse) then return end
        ns.Utils.SafeAfter(3, function()
            if not ns.Notes and ns.IsCompanionLoadable("EasyFind_Notes") and C_AddOns and C_AddOns.LoadAddOn then
                pcall(C_AddOns.LoadAddOn, "EasyFind_Notes")
            end
        end)
    end)
end




if EventUtil and EventUtil.ContinueOnAddOnLoaded then
    EventUtil.ContinueOnAddOnLoaded("Blizzard_MacroUI", function()
        if EasyFind.db and EasyFind.db.macroPickerSearch == false then return end
        ns.RequestIconSearch()
    end)
end






function ns.RequestItemCatalog(announce)
    if ns.ItemSearch then return true end
    if InCombatLockdown() or not ns.Caps.itemCatalog then return false end
    LoadCompanion("EasyFind_Items")
    if ns.ItemSearch then return true end
    if announce then WarnCompanion("EasyFind_Items", "ITEMS_MODULE_DISABLED") end
    return false
end




function ns.RequestSourceData()
    if ns.SourceData then return true end
    if not ns.Caps.sourceData then return false end
    LoadCompanion("EasyFind_Sources")
    if ns.SourceData then return true end
    WarnCompanion("EasyFind_Sources", "SOURCES_MODULE_DISABLED")
    return false
end




function ns.RequestOptionsPanel()
    if ns.Options then return true end
    LoadCompanion("EasyFind_Options")
    if ns.Options then return true end
    WarnCompanion("EasyFind_Options", "OPTIONS_MODULE_DISABLED")
    return false
end






function ns.RequestSettingsSearch(announce)
    if ns.BlizzOptionsSearch then return true end
    LoadCompanion("EasyFind_Settings")
    if ns.BlizzOptionsSearch then return true end
    if announce then WarnCompanion("EasyFind_Settings", "SETTINGS_MODULE_DISABLED") end
    return false
end





function ns.RequestGuide()
    if ns.Highlight then return ns.Highlight end
    LoadCompanion("EasyFind_Guide")
    if ns.Highlight then return ns.Highlight end
    WarnCompanion("EasyFind_Guide", "GUIDE_MODULE_DISABLED")
    return nil
end






function ns.RequestOnboarding()
    if ns.Wizard then return true end
    LoadCompanion("EasyFind_Onboarding")
    if ns.Wizard then return true end
    WarnCompanion("EasyFind_Onboarding", "ONBOARDING_MODULE_DISABLED")
    return false
end





local COMPANION_CAP = { EasyFind_Items = "itemCatalog", EasyFind_Icons = "iconSearch", EasyFind_Sources = "sourceData" }
function ns.IsCompanionLoadable(name)
    if COMPANION_CAP[name] and ns.Caps[COMPANION_CAP[name]] == false then return false end
    if ns.OldExtensionCopy and ns.OldExtensionCopy(name) then return false end
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name) then return true end
    if not (C_AddOns and C_AddOns.GetAddOnEnableState) then return true end
    local ok, state = pcall(C_AddOns.GetAddOnEnableState, name)
    return ok and (tonumber(state) or 0) > 0
end
