--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2024 - James N. Whitehead II
-------------------------------------------------------------------]] ---

---@class CliqueAddon: AddonCore
local addon = select(2, ...)
local L = addon.L

local libCatalog = addon.catalog
local libActions = addon.actionCatalog
local libSpellbook = addon.spellbookCatalog
local libMacros = addon.macroCatalog

---@class BindingConfig
local config = {}

-- Mutually exclusive content pages — only one visible at a time
local exclusivePages = {}

function config:HideOtherPages(except)
    for _, p in ipairs(exclusivePages) do
        if p ~= except then
            p:Hide()
        end
    end
end

function config:SwitchToPage(p)
    config:HideOtherPages(p)
    p:Show()
end

function addon:GetBindingConfig()
    return config
end

function addon:ShowBindingConfig()
    if InCombatLockdown() then
        addon:Printf(L["Clique config UI can't be opened while you are in combat."])
        return
    end

    -- The Settings panel must be closed before ShowUIPanel will display a left-area panel
    if SettingsPanel and SettingsPanel:IsShown() then
        HideUIPanel(SettingsPanel)
    end

    config:Initialize()
    config:InitializeLayout()

    if addon:ShouldAutoShowChangelog() then
        config:SwitchToChangelogPage()
    else
        config:SwitchToBrowsePage()
    end
    ShowUIPanel(CliqueUIBindingFrame)
end

function addon:OpenGeneralOptionsPage()
    addon:ShowBindingConfig()
    config:SwitchToGeneralOptionsPage()
end

function addon:OpenBlizzFramesPage()
    addon:ShowBindingConfig()
    config:SwitchToBlizzFramesPage()
end

function addon:OpenDenylistPage()
    addon:ShowBindingConfig()
    config:SwitchToDenylistPage()
end

function config:Initialize()
    if CliqueUIBindingFrame then
        return CliqueUIBindingFrame
    end

    -- Create the placeholder frame which will be initialized later
    local configUI = CreateFrame("Frame", "CliqueUIBindingFrame", UIParent, "PortraitFrameTemplate")
    configUI:SetHeight(620)
    configUI:SetWidth(480)
    configUI:SetToplevel(true)
    configUI:EnableMouse(true)
    configUI:SetMovable(true)
    configUI:Hide()

    -- Register the UIPanelLayout attributes for the panel window
    configUI:SetAttribute("UIPanelLayout-defined", true)
    configUI:SetAttribute("UIPanelLayout-enabled", true)
    configUI:SetAttribute("UIPanelLayout-area", "left")
    configUI:SetAttribute("UIPanelLayout-pushable", 5)
    configUI:SetAttribute("UIPanelLayout-whileDead", true)

    config.ui = configUI

    return configUI
end

--[[-------------------------------------------------------------------
--  Configuration Panel Layout
-------------------------------------------------------------------]] ---

function config:InitializeLayout()
    local ui = config.ui

    -- Only initialize once
    if ui.initialized then
        return
    end

    ui.initialized = true

    ui:RegisterForDrag("LeftButton")
    ui:SetScript("OnDragStart", ui.StartMoving)
    ui:SetScript("OnDragStop", ui.StopMovingOrSizing)

    local version = L["Clique-%s"]:format(tostring(addon.version))

    -- Classic doesn't have these containers
    if ui.PortraitContainer and ui.TitleContainer then
        ui.PortraitContainer.portrait:SetTexture("Interface\\AddOns\\Clique\\images\\icon_circle_128")
        ui.TitleContainer.TitleText:SetText(version)
    else
        ui.portrait:SetTexture("Interface\\AddOns\\Clique\\images\\icon_circle_128")
        ui.TitleText:SetText(version)
    end

    ui.tooltip = CreateFrame("GameTooltip", "CliqueConfigUITooltip", ui, "GameTooltipTemplate")
    ui.tooltip:Hide()

    -- Create all the pages and windows
    config.BrowsePage = config:GetBrowsePage()
    config.EditPage = config:GetEditPage()
    config.EditMacroPage = config:GetEditMacroPage()
    config.CatalogWindow = config:GetActionCatalogWindow()
    config.BlizzFramesPage = config:GetBlizzFramesPage()
    config.DenylistPage = config:GetDenylistPage()
    config.GeneralOptionsPage = config:GetGeneralOptionsPage()
    config.ProfilePage = config:GetProfilePage()
    config.ChangelogPage = config:GetChangelogPage()

    -- Initialize their layouts
    config.BrowsePage:Initialize()
    config.EditPage:Initialize()
    config.EditMacroPage:Initialize()
    config.CatalogWindow:Initialize()
    config.BlizzFramesPage:Initialize()
    config.DenylistPage:Initialize()
    config.GeneralOptionsPage:Initialize()
    config.ProfilePage:Initialize()
    config.ChangelogPage:Initialize()

    exclusivePages = {
        config.BrowsePage,
        config.EditPage,
        config.EditMacroPage,
        config.BlizzFramesPage,
        config.DenylistPage,
        config.GeneralOptionsPage,
        config.ProfilePage,
        config.ChangelogPage,
    }
end

function config:SwitchToBrowsePage()
    config:SwitchToPage(config.BrowsePage)
    config.BrowsePage:UPDATE_BROWSE_PAGE()
end

function config:SwitchToBlizzFramesPage()
    config:SwitchToPage(config.BlizzFramesPage)
end

function config:SwitchToDenylistPage()
    config:SwitchToPage(config.DenylistPage)
end

function config:SwitchToGeneralOptionsPage()
    config:SwitchToPage(config.GeneralOptionsPage)
end

function config:SwitchToProfilePage()
    config:SwitchToPage(config.ProfilePage)
end

function config:SwitchToChangelogPage()
    config:SwitchToPage(config.ChangelogPage)
end

-- Open the edit page either with a selected binding, or a blank binding
function config:SwitchToEditPage(selectedBinding, newBinding)
    config:HideOtherPages(config.EditPage)

    if selectedBinding then
        config.EditPage:ShowEditPageSelectedBinding(selectedBinding)
    else
        config.EditPage:ShowEditPageNewBinding()
    end
end

function config:GetDefaultBindTable()
    return {
        sets = {
            ["default"] = true,
        }
    }
end

function config:AddBinding(bind)
    addon:AddBinding(bind)
    addon:FireMessage("BINDINGS_CHANGED")

    local browsePage = config:GetBrowsePage()
    browsePage:UPDATE_BROWSE_PAGE()
end

function config:InQuickbindMode()
    return not not config.quickbinding
end

function config:ToggleQuickbind(enabled)
    config.quickbinding = not not enabled
end

function config:BrowsePageShown()
    return config.BrowsePage:IsShown()
end

function config:EditPageShown()
    return config.EditPage:IsShown()
end

function config:SendActionToNewEditPage(entryType, entryId)
    config:SwitchToEditPage()
    config.EditPage:ChangeBindingAction(entryType, entryId)
end

function config:SendActionToEditPage(entryType, entryId)
    config.EditPage:ChangeBindingAction(entryType, entryId)
end

function config:SwitchToEditMacroPage(macrotext, icon)
    config:SwitchToPage(config.EditMacroPage)
    config.EditMacroPage:ResetPage()
    config.EditMacroPage:UpdateText(macrotext)
    config.EditMacroPage:UpdateEditBox(macrotext)
    config.EditMacroPage:UpdateIcon(icon)
end

function config:SendEditMacroToEditPage(macrotext, icon)
    config.EditPage:SetMacrotextIcon(macrotext, icon)
end

-- Close the edit macro window and go back to the edit page
function config:CloseToEditPage()
    config.EditMacroPage:Hide()
    config.EditPage:Show()
    config.EditPage:UpdateEditPage()
end


local quickbindTooltipExtra = L["You are in quickbind mode, you can use a click or press a key to add a binding"]
local BLUE_COLOR = {r = 0, g = 0.7490196, b = 0.9529412}

function config:ShowTooltip(owner, entryType, entryId)
    local tooltip = config.ui.tooltip

    if (entryType == libCatalog.entryType.Spell or entryType == libCatalog.entryType.Pet) and entryId then
        tooltip:SetOwner(owner, "ANCHOR_TOPLEFT")
        tooltip:SetSpellByID(entryId)
        tooltip:AddLine("")
        tooltip:AddLine("Spell ID: " .. tostring(entryId))
    elseif entryType == libCatalog.entryType.Macro and entryId then
        local name, icon, body = libMacros:GetMacroNameIconBody(entryId)
        local accountMacro = libMacros:IsAccountMacroIndex(entryId)

        local macroType = L["Character Macro"]
        if accountMacro then
            macroType = L["Account Macro"]
        end

        tooltip:SetOwner(owner, "ANCHOR_TOPLEFT")
        tooltip:AddDoubleLine(name, macroType, 1, 1, 1)
        tooltip:AddTexture(icon)
        tooltip:AddLine("\n")
        tooltip:AddLine(body, 1, 1, 1)
        tooltip:AddLine("")
        tooltip:AddLine("Macro Index: " .. tostring(entryId), 0.5, 0.5, 0.5)
    elseif entryType == libCatalog.entryType.Action and entryId then
        local name, icon, atype, unit, payload = libActions:GetNameIconTypeUnit(entryId)

        tooltip:SetOwner(owner, "ANCHOR_TOPLEFT")
        if atype == "item" and payload then
            local slot = tonumber(payload)
            local hasItem = slot and GetInventoryItemID("player", slot)
            if hasItem then
                tooltip:SetInventoryItem("player", slot)
            else
                tooltip:AddLine(name)
                tooltip:AddTexture(icon)
            end
        else
            tooltip:AddLine(name)
            tooltip:AddTexture(icon)
        end
    else
        tooltip:SetOwner(owner, "ANCHOR_TOPLEFT")
        local unknown = L["Unknown binding type '%s'"]:format(tostring(entryType))
        tooltip:AddLine(unknown)
        tooltip:AddTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    if config:InQuickbindMode() then
        tooltip:AddLine("\n")
        tooltip:AddLine(quickbindTooltipExtra, BLUE_COLOR.r, BLUE_COLOR.g, BLUE_COLOR.b, true)
    end

    tooltip:Show()
end

function config:HideTooltip()
    local tooltip = config.ui.tooltip

    tooltip:Hide()
end

