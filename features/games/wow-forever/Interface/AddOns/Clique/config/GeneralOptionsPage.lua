--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2024 - James N. Whitehead II
-------------------------------------------------------------------]] ---

---@class CliqueAddon: AddonCore
local addon = select(2, ...)
local L = addon.L

---@class BindingConfig
local config = addon:GetBindingConfig()

local page = {}

function config:GetGeneralOptionsPage()
    return page
end

local CLICK_DIRECTIONS = {
    { value = "down", label = L["Down"] },
    { value = "up",   label = L["Up"] },
    { value = "both", label = L["Both Up/Down"] },
}

local function clickDirectionLabel(value)
    for _, option in ipairs(CLICK_DIRECTIONS) do
        if option.value == value then
            return option.label
        end
    end
    return value
end

local function applyClickDirection()
    addon:UpdateRegisteredClicks()
    addon:UpdateGlobalButtonClicks()
    addon:FireMessage("BINDINGS_CHANGED")
end

local function buildClickDirectionMenu(_, rootDescription)
    local settings = addon.settings
    for _, option in ipairs(CLICK_DIRECTIONS) do
        rootDescription:CreateRadio(option.label,
            function() return settings.clickDirection == option.value end,
            function()
                settings.clickDirection = option.value
                applyClickDirection()
            end)
    end
end

local TOOLTIP_ANCHORS = {
    "ANCHOR_TOPLEFT",
    "ANCHOR_TOP",
    "ANCHOR_TOPRIGHT",
    "ANCHOR_LEFT",
    "ANCHOR_RIGHT",
    "ANCHOR_BOTTOMLEFT",
    "ANCHOR_BOTTOM",
    "ANCHOR_BOTTOMRIGHT",
    "ANCHOR_CURSOR",
}

local function makeSettingToggle(key, applyFn)
    return function(_, checked)
        addon.settings[key] = checked
        applyFn()
    end
end

local function buildTooltipAnchorMenu(_, rootDescription)
    local settings = addon.settings
    for _, anchor in ipairs(TOOLTIP_ANCHORS) do
        rootDescription:CreateRadio(anchor,
            function() return settings.tooltipAnchor == anchor end,
            function()
                settings.tooltipAnchor = anchor
            end)
    end
end

function page:Show()
    page.frame:ClearAllPoints()
    page.frame:SetAllPoints(config.ui)
    page.frame:Show()
    page:Refresh()
end

function page:Hide()
    page.frame:Hide()
    page.frame:ClearAllPoints()
    page.frame:SetPoint("RIGHT", UIParent, "LEFT", 0, 0)
end

function page:IsShown()
    return page.frame:IsShown()
end

function page:Initialize()
    if page.initialized then
        return
    end

    page.initialized = true
    page.frame = CreateFrame("Frame", "CliqueConfigUIBindingFrameGeneralOptionsPage", config.ui)
    local frame = page.frame

    frame:SetAllPoints()
    frame:Hide()

    frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -60)
    frame.title:SetText(L["General Options"])

    frame.backButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.backButton:SetText(L["Back"])
    frame.backButton:SetHeight(23)
    frame.backButton:SetWidth(120)
    frame.backButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 5)
    frame.backButton:SetScript("OnClick", function()
        config:SwitchToBrowsePage()
    end)

    frame.dataProvider, frame.listContainer = config:CreateSettingsList(frame,
        { frame, "TOPLEFT", 10, -90 },
        { frame, "BOTTOMRIGHT", -30, 40 },
        { backdrop = false })

    addon:RegisterMessage("BINDINGS_CHANGED", page.OnBindingsChanged)
end

function page.OnBindingsChanged()
    local self = page
    if self:IsShown() then
        self:Refresh()
    end
end

function page:Refresh()
    local frame = page.frame
    local dataProvider = frame.dataProvider
    dataProvider:Flush()

    local settings = addon.settings

    dataProvider:Insert({
        rowType     = "dropdown",
        label       = L["Trigger bindings on:"],
        buttonText  = clickDirectionLabel(settings.clickDirection),
        menuBuilder = buildClickDirectionMenu,
    })

    dataProvider:Insert({
        label    = L["Disable all bindings when in housing edit mode"],
        checked  = settings.disableInHousing,
        onToggle = makeSettingToggle("disableInHousing", function()
            addon:HouseEditorModeChanged()
        end),
    })

    dataProvider:Insert({
        label    = L["Enable GamePad binding support"],
        checked  = settings.enableGamePad,
        onToggle = makeSettingToggle("enableGamePad", function()
            addon:UpdateRegisteredClicks()
            addon:FireMessage("BINDINGS_CHANGED")
        end),
    })

    dataProvider:Insert({
        label    = L["Show binding tooltip on unit frames"],
        checked  = settings.showBindingTooltip,
        onToggle = function(_, checked)
            settings.showBindingTooltip = checked
            C_Timer.After(0, function() page:Refresh() end)
        end,
    })

    dataProvider:Insert({
        rowType     = "dropdown",
        label       = L["Tooltip anchor:"],
        buttonText  = settings.tooltipAnchor,
        enabled     = settings.showBindingTooltip,
        menuBuilder = buildTooltipAnchorMenu,
    })

    dataProvider:Insert({
        label    = L["Attempt to fix the issue introduced in 4.3 with casting on dead targets"],
        checked  = settings.stopcastingfix,
        onToggle = makeSettingToggle("stopcastingfix", function()
            addon:FireMessage("BINDINGS_CHANGED")
        end),
    })

    dataProvider:Insert({
        label    = L["Don't show warnings for missing target/menu actions"],
        tooltip  = L["This option permanently dismisses the warning on the Clique config page that shows when the menu and target actions haven't been bound, but has no action other than hiding that message"],
        checked  = settings.dismissTargetMenuWarning,
        onToggle = makeSettingToggle("dismissTargetMenuWarning", function()
            addon:FireMessage("BINDINGS_CHANGED")
        end),
    })
end
