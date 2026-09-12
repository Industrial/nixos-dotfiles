--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2024 - James N. Whitehead II
-------------------------------------------------------------------]] ---

local addonName = select(1, ...)

---@class CliqueAddon: AddonCore
local addon = select(2, ...)
local L = addon.L

local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local Settings = Settings

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

--[[-------------------------------------------------------------------------
--  Addon 'About' Dialog for Interface Options
--
--  Some of this code was taken from/inspired by tekKonfigAboutPanel
--- and it's been moved from AddonCore due to taint issues.
-------------------------------------------------------------------------]]--

local about = CreateFrame("Frame", addonName .. "AboutPanel", InterfaceOptionsFramePanelContainer)
about.name = addonName
about:Hide()

function about.OnShow(frame)
    local fields = {"Version", "Author", "X-Category", "X-License", "X-Email", "X-Website", "X-Credits"}
    local notes = GetAddOnMetadata(addonName, "Notes")

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")

    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(addonName)

    local subtitle = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetHeight(32)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetPoint("RIGHT", about, -32, 0)
    subtitle:SetNonSpaceWrap(true)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetJustifyV("TOP")
    subtitle:SetText(notes)

    local anchor
    for _,field in pairs(fields) do
            local val = GetAddOnMetadata(addonName, field)
            if val then
                    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
                    title:SetWidth(75)
                    if not anchor then title:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -2, -8)
                    else title:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6) end
                    title:SetJustifyH("RIGHT")
                    title:SetText(field:gsub("X%-", ""))

                    local detail = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                    detail:SetPoint("LEFT", title, "RIGHT", 4, 0)
                    detail:SetPoint("RIGHT", -16, 0)
                    detail:SetJustifyH("LEFT")
                    detail:SetText(val)

                    anchor = title
            end
    end

    -- Clear the OnShow so it only happens once
    frame:SetScript("OnShow", nil)
end

addon.optpanels = addon.optpanels or {}
addon.optpanels.ABOUT = about
addon.optpanels.useRedirect = false

about:SetScript("OnShow", about.OnShow)
about:Hide()

if Settings and Settings.RegisterCanvasLayoutCategory then
    local category, layout = Settings.RegisterCanvasLayoutCategory(addon.optpanels.ABOUT, addonName)
    Settings.RegisterAddOnCategory(category)
    addon.optpanels.ABOUT.category = category
    addon.optpanels.ABOUT.layout = layout
elseif InterfaceOptions_AddCategory then
   InterfaceOptions_AddCategory(addon.optpanels.ABOUT)
end

--[[-------------------------------------------------------------------------
--  End Dialog
-------------------------------------------------------------------------]]--

local panel = CreateFrame("Frame")
panel:Hide()

panel.name = L["General Options"]
panel.parent = addonName

function panel:OnCommit()
    panel.okay()
end

function panel:OnDefault()
end

function panel:OnRefresh ()
    panel.refresh()
end

addon.optpanels.GENERAL = panel

panel:SetScript("OnShow", function(self)
    if not panel.initialized then
        panel:CreateOptions()
        panel.refresh()
    end
end)

local function make_checkbox(name, parent)
    local frame = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    frame.text = _G[frame:GetName() .. "Text"]
    frame.type = "checkbox"
    return frame
end

function panel:CreateOptions()
    panel.initialized = true

    local bits = {}

    self.clickDirectionLabel = self:CreateFontString("CliqueOptionsClickDirectionLabel", "OVERLAY", "GameFontNormalSmall")
    self.clickDirectionLabel.type = "label"
    self.clickDirectionLabel:SetText(L["Trigger bindings on:"])

    self.clickDirectionDD = CreateFrame("DropdownButton", "CliqueOptionsClickDirectionDD", self, "WowStyle1DropdownTemplate")
    self.clickDirectionDD.type = "dropdown"
    self.clickDirectionDD:SetWidth(200)
    self.clickDirectionDD:SetHeight(22)
    self.clickDirectionDD:SetupMenu(function(_, rootDescription)
        local settings = addon.settings
        for _, option in ipairs(CLICK_DIRECTIONS) do
            rootDescription:CreateRadio(option.label,
                function() return settings.clickDirection == option.value end,
                function()
                    settings.clickDirection = option.value
                    panel.clickDirectionDD:SetText(option.label)
                    addon:UpdateRegisteredClicks()
                    addon:UpdateGlobalButtonClicks()
                    addon:FireMessage("BINDINGS_CHANGED")
                end)
        end
    end)

    self.disableDuringHousing = make_checkbox("CliqueOptionsDisableDuringHousing", self)
    self.disableDuringHousing.text:SetText(L["Disable all bindings when in housing edit mode"])

    self.enableGamePad = make_checkbox("CliqueOptionsEnableGamePad", self)
    self.enableGamePad.text:SetText(L["Enable GamePad binding support"])

    self.showBindingTooltip = make_checkbox("CliqueOptionsShowBindingTooltip", self)
    self.showBindingTooltip.text:SetText(L["Show binding tooltip on unit frames"])
    self.showBindingTooltip:SetScript("PostClick", function()
        if panel.showBindingTooltip:GetChecked() then
            panel.tooltipAnchorDD:Enable()
        else
            panel.tooltipAnchorDD:Disable()
        end
    end)

    self.tooltipAnchorDD = CreateFrame("DropdownButton", "CliqueOptionsTooltipAnchorDD", self, "WowStyle1DropdownTemplate")
    self.tooltipAnchorDD.type = "dropdown"
    self.tooltipAnchorDD:SetWidth(200)
    self.tooltipAnchorDD:SetHeight(22)
    self.tooltipAnchorDD:SetupMenu(function(_, rootDescription)
        local settings = addon.settings
        for _, anchor in ipairs(TOOLTIP_ANCHORS) do
            rootDescription:CreateRadio(anchor,
                function() return settings.tooltipAnchor == anchor end,
                function()
                    settings.tooltipAnchor = anchor
                    panel.tooltipAnchorDD:SetText(anchor)
                end)
        end
    end)

    self.stopcastingfix = make_checkbox("CliqueOptionsStopCastingFix", self)
    self.stopcastingfix.text:SetText(L["Attempt to fix the issue introduced in 4.3 with casting on dead targets"])

    self.dismissTargetMenuWarning = make_checkbox("CliqueOptionsDismissTargetMenuWarning", self)
    self.dismissTargetMenuWarning.text:SetText(L["Don't show warnings for missing target/menu actions"])
    self.dismissTargetMenuWarning:SetScript("OnEnter", function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["This option permanently dismisses the warning on the Clique config page that shows when the menu and target actions haven't been bound, but has no action other than hiding that message"], nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    self.dismissTargetMenuWarning:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    table.insert(bits, self.clickDirectionLabel)
    table.insert(bits, self.clickDirectionDD)
    table.insert(bits, self.disableDuringHousing)
    table.insert(bits, self.enableGamePad)
    table.insert(bits, self.showBindingTooltip)
    table.insert(bits, self.tooltipAnchorDD)
    table.insert(bits, self.stopcastingfix)
    table.insert(bits, self.dismissTargetMenuWarning)

    bits[1]:SetPoint("TOPLEFT", 5, -5)

    for i = 2, #bits, 1 do
        if bits[i].type == "dropdown" then
            bits[i]:SetPoint("TOPLEFT", bits[i-1], "BOTTOMLEFT", -5, -5)
        else
            bits[i]:SetPoint("TOPLEFT", bits[i-1], "BOTTOMLEFT", 0, -5)
        end
    end
end

-- Update the elements on the panel to the current state
function panel.refresh()
    xpcall(function()

    if not panel.initialized then
        panel:CreateOptions()
    end

    local settings = addon.settings

    panel.clickDirectionDD:SetText(clickDirectionLabel(settings.clickDirection))
    panel.clickDirectionDD:GenerateMenu()
    panel.disableDuringHousing:SetChecked(settings.disableInHousing)
    panel.enableGamePad:SetChecked(settings.enableGamePad)
    panel.showBindingTooltip:SetChecked(settings.showBindingTooltip)
    panel.tooltipAnchorDD:SetText(settings.tooltipAnchor)
    panel.tooltipAnchorDD:GenerateMenu()
    if settings.showBindingTooltip then
        panel.tooltipAnchorDD:Enable()
    else
        panel.tooltipAnchorDD:Disable()
    end
    panel.stopcastingfix:SetChecked(settings.stopcastingfix)
    panel.dismissTargetMenuWarning:SetChecked(settings.dismissTargetMenuWarning)

    end, geterrorhandler())
end

function panel.okay()
    xpcall(function ()

    if not panel.initialized then return end

    local settings = addon.settings

    -- clickDirection applies immediately from the dropdown, so it's not handled here.
    local newDisableInHousing = not not panel.disableDuringHousing:GetChecked()
    local newEnableGamePad = not not panel.enableGamePad:GetChecked()
    local newShowBindingTooltip = not not panel.showBindingTooltip:GetChecked()
    local newStopCasting = not not panel.stopcastingfix:GetChecked()
    local newDismissWarning = not not panel.dismissTargetMenuWarning:GetChecked()

    local gamePadChanged = newEnableGamePad ~= settings.enableGamePad
    local stopCastingChanged = newStopCasting ~= settings.stopcastingfix
    local dismissWarningChanged = newDismissWarning ~= settings.dismissTargetMenuWarning

    settings.disableInHousing = newDisableInHousing
    settings.enableGamePad = newEnableGamePad
    settings.showBindingTooltip = newShowBindingTooltip
    settings.stopcastingfix = newStopCasting
    settings.dismissTargetMenuWarning = newDismissWarning

    addon:HouseEditorModeChanged()

    if gamePadChanged then
        addon:UpdateRegisteredClicks()
    end

    if stopCastingChanged or gamePadChanged or dismissWarningChanged then
        addon:FireMessage("BINDINGS_CHANGED")
    end

    end, geterrorhandler())
end

panel.cancel = panel.refresh

function addon:UpdateOptionsPanel()
    if panel:IsVisible() and panel.initialized then
        panel.refresh()
    end
end

if addon.optpanels.useRedirect then
    if Settings and Settings.RegisterVerticalLayoutSubcategory then
        local category = Settings.RegisterVerticalLayoutSubcategory(addon.optpanels.ABOUT.category, L["General Options"])
        Settings.RegisterInitializer(category, CreateSettingsListSectionHeaderInitializer(
            L["These options have moved into the main Clique config window."]
        ))
        Settings.RegisterInitializer(category, CreateSettingsButtonInitializer(
            L["General Options"], L["Open"],
            function() addon:OpenGeneralOptionsPage() end,
            nil, false
        ))
    end
else
    if Settings and Settings.RegisterCanvasLayoutSubcategory then
        local category, layout = Settings.RegisterCanvasLayoutSubcategory(addon.optpanels.ABOUT.category, addon.optpanels.GENERAL, addon.optpanels.GENERAL.name)
        addon.optpanels.GENERAL.category = category
        addon.optpanels.GENERAL.layout = layout
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel, addon.optpanels.ABOUT)
    end
end
