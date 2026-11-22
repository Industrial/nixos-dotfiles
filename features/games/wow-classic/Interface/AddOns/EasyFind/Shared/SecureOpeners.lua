local _, ns = ...





















































local SecureOpeners = {}
ns.SecureOpeners = SecureOpeners

local Utils = ns.Utils
local pairs = Utils.pairs
local CreateFrame = CreateFrame
local UIParent = UIParent
local InCombatLockdown = InCombatLockdown
local strrep = string.rep



SecureOpeners.TAB_TALENTS = 2
SecureOpeners.TAB_SPELLBOOK = 3

local PANELS = {
    playerSpells = {
        micro = "PlayerSpellsMicroButton",
        panel = "PlayerSpellsFrame",
        addon = "Blizzard_PlayerSpells",
        defaultTab = SecureOpeners.TAB_SPELLBOOK,
    },
}

for _, spec in pairs(PANELS) do
    spec.openMacroText = "/click " .. spec.micro
    spec.tabButtons = {}
end



local BUTTONFRAME_PANEL = {
    ["PlayerSpellsMicroButton"] = "playerSpells",
}





function SecureOpeners.OpenKeyForData(data)
    if not data then return nil end

    local Replacement = ns.SearchOpeners and ns.SearchOpeners.Replacement
    local talent = data.category == "Talent"
    if Replacement and Replacement(talent and "talents" or "spellBook") then return nil end
    local key = BUTTONFRAME_PANEL[data.buttonFrame]
    if not key and data.spellID and (talent or Utils.IsSpellbookOnlyAbility(data)) then key = "playerSpells" end

    if key and not _G[PANELS[key].micro] then return nil end
    return key
end




local REPLACED_KEYS = { TalentMicroButton = "talents", QuestLogMicroButton = "questLog", LegacyMicroButton = "legacyWindow" }
function SecureOpeners.ReplacementOpenMacro(name)
    local Replacement = ns.SearchOpeners and ns.SearchOpeners.Replacement
    local api = Replacement and Replacement(name)
    if not (api and api.SecureOpener) then return nil end
    local ok, button = pcall(api.SecureOpener, name)
    if not (ok and type(button) == "string" and _G[button]) then return nil end
    local frame = api.GetFrame(name)
    if frame and frame:IsVisible() then return nil end
    return "/click " .. button
end

function SecureOpeners.ReplacementMacro(data)
    if not data then return nil end
    local name
    if data.category == "Talent" then
        name = "talents"
    elseif data.spellID and Utils.IsSpellbookOnlyAbility(data) then
        name = "spellBook"
    else
        name = REPLACED_KEYS[data.buttonFrame]
    end
    return name and SecureOpeners.ReplacementOpenMacro(name)
end

function SecureOpeners.IsPanelShown(key)
    local spec = PANELS[key]
    local panel = spec and _G[spec.panel]
    return panel ~= nil and panel:IsShown()
end





function SecureOpeners.GetOpenMacro(key)
    local spec = PANELS[key]
    if not spec or not _G[spec.micro] then return nil end
    if SecureOpeners.IsPanelShown(key) then return nil end
    return spec.openMacroText
end





function SecureOpeners.EnsureLoaded(key)
    local spec = PANELS[key]
    if not spec or _G[spec.panel] then return end
    Utils.LoadBlizzardAddOn(spec.addon)
end

local function SteerTabIndexFor(spec, data)





    local steps = data.steps
    if steps then
        for i = 1, #steps do
            local step = steps[i]
            if step.waitForFrame == spec.panel and step.tabIndex then
                return step.tabIndex
            end
        end
    end
    if data.category == "Talent" then return SecureOpeners.TAB_TALENTS end
    if data.spellID then return spec.defaultTab end
    return nil
end







function SecureOpeners.GetTabButtonFor(key, tabIndex)
    local spec = PANELS[key]
    if not (spec and tabIndex) then return nil end
    local cached = spec.tabButtons[tabIndex]
    if cached then return cached end
    if not _G[spec.panel] then return nil end
    local highlight = ns.RequestGuide and ns.RequestGuide() or nil
    if not (highlight and highlight.GetTabButton) then return nil end
    local tab = highlight:GetTabButton(spec.panel, tabIndex)
    spec.tabButtons[tabIndex] = tab
    return tab
end

function SecureOpeners.GetSteerTabButton(key, data)
    local spec = PANELS[key]
    if not (spec and data) then return nil end
    return SecureOpeners.GetTabButtonFor(key, SteerTabIndexFor(spec, data))
end



function SecureOpeners.GetDefaultTabButton(key)
    local spec = PANELS[key]
    return spec and SecureOpeners.GetTabButtonFor(key, spec.defaultTab) or nil
end













local clickProxies, clickProxyCount = {}, 0
function SecureOpeners.GetClickChainMacro(targetButton, presses)
    if not (targetButton and presses and presses > 0) then return nil end
    local proxy = clickProxies[targetButton]
    if not proxy then
        if InCombatLockdown() then return nil end
        clickProxyCount = clickProxyCount + 1
        proxy = CreateFrame("Button", "EasyFindClickProxy" .. clickProxyCount,
            UIParent, "SecureActionButtonTemplate")
        proxy:SetSize(1, 1)
        proxy:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -32, 32)
        proxy:EnableMouse(false)
        Utils.SafeCallMethod(proxy, "SetAttribute", "useOnKeyDown", false)
        Utils.SafeCallMethod(proxy, "SetAttribute", "type", "click")
        Utils.SafeCallMethod(proxy, "SetAttribute", "clickbutton", targetButton)
        clickProxies[targetButton] = proxy
    end
    return strrep("/click " .. proxy:GetName() .. "\n", presses)
end





function SecureOpeners.IsTabButtonSelected(key, tabButton)
    local spec = PANELS[key]
    local panel = spec and _G[spec.panel]
    if not (panel and panel.GetTab and tabButton and panel:IsShown()) then
        return false
    end
    local ok, selectedID = pcall(panel.GetTab, panel)
    if not ok or not selectedID then return false end
    if tabButton.GetTabID then
        local ok2, tabID = pcall(tabButton.GetTabID, tabButton)
        if ok2 and tabID then return tabID == selectedID end
    end
    return false
end
