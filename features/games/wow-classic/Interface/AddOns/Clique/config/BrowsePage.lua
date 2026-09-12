--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2024 - James N. Whitehead II
-------------------------------------------------------------------]] ---

---@class CliqueAddon: AddonCore
local addon = select(2, ...)
local L = addon.L

local libMacros = addon.macroCatalog

---@class BindingConfig
local config = addon:GetBindingConfig()

-- Globals used in this file
local BLACK_FONT_COLOR = BLACK_FONT_COLOR
local DARKGRAY_COLOR = DARKGRAY_COLOR

local CreateDataProvider = CreateDataProvider
local CreateScrollBoxListLinearView = CreateScrollBoxListLinearView
local ScrollUtil = ScrollUtil

local page = {}

function config:GetBrowsePage()
    return page
end

function page:Show()
    page.frame:ClearAllPoints()
    page.frame:SetAllPoints(config.ui)
    page.frame:Show()
    config.BrowsePage:UPDATE_BROWSE_PAGE()
end

function page:IsShown()
    return page.frame:IsShown()
end

function page:Hide()
    page.frame:Hide()
    page.frame:ClearAllPoints()
    page.frame:SetPoint("RIGHT", UIParent, "LEFT", 0, 0)
end

function page:Initialize()
    if page.initialized then
        return
    end

    page.initialized = true
    page.frame = CreateFrame("Frame", "CliqueConfigUIBindingFrameBrowsePage", config.ui)
    local frame = page.frame

    frame:SetAllPoints()

    frame.AddButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.AddButton:SetText(L["Add Binding"])
    frame.AddButton:SetHeight(23)
    frame.AddButton:SetWidth(120)
    frame.AddButton:ClearAllPoints()
    frame.AddButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 5)
    frame.AddButton:SetScript("OnClick", function(button)
        -- We want to create a new binding
        config:SwitchToEditPage(nil, true)
    end)

    frame.EditButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.EditButton:SetText(L["Edit Binding"])
    frame.EditButton:SetHeight(23)
    frame.EditButton:SetWidth(120)
    frame.EditButton:ClearAllPoints()
    frame.EditButton:SetPoint("LEFT", frame.AddButton, "RIGHT", 0, 0)
    frame.EditButton:Disable()
    frame.EditButton:SetScript("OnClick", function(button)
        -- Send the selected binding to the edit page
        config:SwitchToEditPage(page.selectedBind, false)
    end)

    frame.QuickbindMode = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.QuickbindMode:SetText(L["Quickbind Mode"])
    frame.QuickbindMode:SetHeight(23)
    frame.QuickbindMode:SetWidth(140)
    frame.QuickbindMode:ClearAllPoints()
    frame.QuickbindMode:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 5)

    -- Glow box for being in QuickbindMode
    frame.quickBindHelpBox = CreateFrame("Frame", nil, frame, "GlowBoxTemplate")
    frame.quickBindHelpBox:SetWidth(300)
    frame.quickBindHelpBox:SetHeight(75)
    frame.quickBindHelpBox:ClearAllPoints()
    frame.quickBindHelpBox:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 5)
    frame.quickBindHelpBox.Text = frame.quickBindHelpBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.quickBindHelpBox.Text:SetJustifyH("LEFT")
    frame.quickBindHelpBox.Text:SetJustifyV("MIDDLE")
    frame.quickBindHelpBox.Text:SetPoint("TOPLEFT", 10, -5)
    frame.quickBindHelpBox.Text:SetPoint("BOTTOMRIGHT", -10, 5)

    local addBindingHelpText = L["You are in quick-bind mode. Mouse over spells and macros in the catalog window to quickly bind and add actions. You can use any combinmation of alt, control and shift with your clicks and key-presses"]
    frame.quickBindHelpBox.Text:SetText(addBindingHelpText)
    frame.quickBindHelpBox:SetFrameStrata("HIGH")
    frame.quickBindHelpBox:Hide()

    frame.QuickbindMode:SetScript("OnClick", function(self, button)
        if config:InQuickbindMode() then
            frame.quickBindHelpBox:Hide()
            self:SetText(L["Quickbind Mode"])
            config:ToggleQuickbind(false)
        else
            frame.quickBindHelpBox:Show()
            self:SetText(L["End Quickbind"])
            config:ToggleQuickbind(true)
        end
    end)

    frame.background = CreateFrame("Frame", "CliqueConfigUIBrowseScrollBackground", frame, "TooltipBackdropTemplate")
    frame.background:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 4, 520)
    frame.background:SetPoint("BOTTOMRIGHT", -31, 50)
    frame.background:SetFrameLevel(2)

    local bgColor = BLACK_FONT_COLOR
    local bgAlpha = 1
    local bgR, bgG, bgB = bgColor:GetRGB()
    frame.background:SetBackdropColor(bgR, bgG, bgB, bgAlpha)

    local bgBorderColor = DARKGRAY_COLOR
    local borderR, borderG, borderB = bgBorderColor:GetRGB()
    local borderAlpha = 1
    frame.background:SetBackdropBorderColor(borderR, borderG, borderB, borderAlpha)

    frame.scrollFrame = CreateFrame("Frame", "CliqueConfigUIScrollFrame", frame.background, "WowScrollBoxList")
    frame.scrollFrame:ClearAllPoints()
    frame.scrollFrame:SetPoint("TOPLEFT", 5, -5)
    frame.scrollFrame:SetPoint("BOTTOMRIGHT", -5, 0)

    frame.scrollbar = CreateFrame("EventFrame", "CliqueConfigUIScrollBar", frame, "MinimalScrollBar")
    frame.scrollbar:ClearAllPoints()
    frame.scrollbar:SetPoint("TOPLEFT", frame.background, "TOPRIGHT", 10, 0)
    frame.scrollbar:SetPoint("BOTTOMLEFT", frame.background, "BOTTOMRIGHT", 10, 0)

    -- Shown when something in the bind config conflicts with Clique (addon:GetActiveBindConfigWarning).
    frame.bindConfigWarning = CreateFrame("Button", nil, frame, "TooltipBackdropTemplate")
    local warning = frame.bindConfigWarning
    warning:SetHeight(28)
    warning:SetPoint("BOTTOMLEFT", frame.background, "TOPLEFT", 5, 4)
    warning:SetPoint("BOTTOMRIGHT", frame.background, "TOPRIGHT", -5, 4)
    warning:SetFrameLevel(frame.background:GetFrameLevel() + 5)
    warning:Hide()

    warning:SetBackdropColor(0.25, 0.05, 0.05, 0.95)
    warning:SetBackdropBorderColor(0.9, 0.15, 0.15, 1)

    warning.text = warning:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    warning.text:SetPoint("LEFT", warning, "LEFT", 10, 0)
    warning.text:SetPoint("RIGHT", warning, "RIGHT", -10, 0)
    warning.text:SetJustifyH("LEFT")
    page.alertIcon = CreateSimpleTextureMarkup([[Interface\DialogFrame\UI-Dialog-Icon-AlertNew]], 14, 14)
    warning.text:SetTextColor(1, 0.45, 0.4)

    warning:SetScript("OnEnter", function(btn)
        local descriptor = btn.descriptor
        if not descriptor then return end

        local tooltip = config.ui.tooltip
        tooltip:SetOwner(btn, "ANCHOR_BOTTOM")
        tooltip:SetText(descriptor.title, 1, 0.82, 0)
        for _, line in ipairs(descriptor.lines or {}) do
            tooltip:AddLine(line, 1, 1, 1, true)
        end
        if descriptor.actionText then
            tooltip:AddLine(" ")
            tooltip:AddLine(descriptor.actionText, 0, 0.7, 0.95, true)
        end
        tooltip:Show()
    end)
    warning:SetScript("OnLeave", function()
        config.ui.tooltip:Hide()
    end)
    warning:SetScript("OnClick", function(btn)
        if btn.descriptor and btn.descriptor.onClick then
            btn.descriptor.onClick()
        end
    end)

    frame.dataProvider = CreateDataProvider()

    local dataProvider = frame.dataProvider
    local scrollView = CreateScrollBoxListLinearView()

    ScrollUtil.InitScrollBoxListWithScrollBar(frame.scrollFrame, frame.scrollbar, scrollView)
    scrollView:SetElementInitializer("CliqueBindingTemplate", function(button, data)
        page:InitializeBindingRow(button, data)
    end)
    scrollView:SetDataProvider(dataProvider)

    -- Options button
    frame.OptionsButton = CreateFrame("DropdownButton", nil, frame, "WowStyle1FilterDropdownTemplate")
    local optionsButton = frame.OptionsButton

    optionsButton:ClearAllPoints()
    optionsButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -40)
    optionsButton:SetWidth(93)
    optionsButton:SetHeight(22)
    optionsButton:SetText(L["Options"])

    optionsButton:SetupMenu(function(_, rootDescription)
        rootDescription:CreateRadio(L["Sort by name"], function()
            return page:GetSortOrder() == "name"
        end, function()
            page:ChangeSortOrder("name")
        end)
        rootDescription:CreateRadio(L["Sort by binding key"], function()
            return page:GetSortOrder() == "key"
        end, function()
            page:ChangeSortOrder("key")
        end)
        rootDescription:CreateDivider()
        rootDescription:CreateButton(L["Open Clique Options"], function()
            if Settings then
                Settings.OpenToCategory(addon.optpanels.ABOUT.category:GetID())
            else
                InterfaceOptionsFrame_OpenToCategory("Clique")
            end
        end)
        rootDescription:CreateButton(self:LabelWithGearPrefix(L["General Options"]), function()
            config:SwitchToGeneralOptionsPage()
        end)
        rootDescription:CreateButton(self:LabelWithGearPrefix(L["Blizzard Frame Options"]), function()
            config:SwitchToBlizzFramesPage()
        end)
        rootDescription:CreateButton(self:LabelWithGearPrefix(L["Frame Denylist"]), function()
            config:SwitchToDenylistPage()
        end)
        rootDescription:CreateButton(self:LabelWithGearPrefix(L["Profile Management"]), function()
            config:SwitchToProfilePage()
        end)
        rootDescription:CreateDivider()
        rootDescription:CreateButton(self:ChangelogMenuLabel(L["What's New"]), function()
            config:SwitchToChangelogPage()
        end)
    end)

    frame.SearchBox = CreateFrame("EditBox", "CliqueConfigUIBrowseSearch", frame, "SearchBoxTemplate")
    local searchBox = frame.SearchBox

    searchBox:SetHeight(22)
    searchBox:SetWidth(285)
    searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 60, -40)
    page:EnableSearch()

    page:UPDATE_BROWSE_PAGE()
    addon:RegisterMessage("BINDINGS_CHANGED", function()
        if page:IsShown() then
            page:UPDATE_BROWSE_PAGE()
        end
    end)
    addon:RegisterMessage("MACROS_UPDATED", function()
        libMacros:InvalidateNameCache()
        if page:IsShown() then
            page:UPDATE_BROWSE_PAGE()
        end
    end)
end

-- Add a gear to clearly identify the options pages
function page:LabelWithGearPrefix(str)
    local prefix = page:GetAtlasString("mechagon-projects", 16, 16)
    if prefix then
        return prefix .. " " .. str
    else
        return str
    end
end

-- Differentiate the changelog entry from the gear-prefixed options pages:
-- a news icon + gold label.
function page:ChangelogMenuLabel(str)
    local label = ("|cffffd200%s|r"):format(str)
    local prefix = page:GetAtlasString("CreditsScreen-Assets-Buttons-Play", 16, 16)
    if prefix then
        return prefix .. " " .. label
    end
    return label
end

function page:GetAtlasString(atlas, w, h)
    if C_Texture and C_Texture.GetAtlasInfo(atlas) then
        return ("|A:%s:%d:%d|a"):format(atlas, w or 0, h or 0)
    end
end

page.bindRows = {}

local BindRowButton_OnClick = function(button)
    page:SelectBindRow(button)
end

local BindRowButton_OnDoubleClick = function(button)
    page:ClearSelectedBindRow()
    page:SelectBindRow(button)
    config:SwitchToEditPage(page.selectedBind, false)
end

local BindRowButton_OnEnter = function(button)
    button.DeleteButton:Show()
    if button.warning then
        config.ui.tooltip:SetOwner(button, "ANCHOR_TOP")
        config.ui.tooltip:AddLine(L["|cffFF4800Ambiguous macro name"])
        config.ui.tooltip:AddLine(button.warning, 1, 1, 1, true)
        config.ui.tooltip:AddLine(" ")
        config.ui.tooltip:AddLine(L["This works best with unique macro names, or you can use the Run Custom Macro action."], 1, 1, 1, true)
        config.ui.tooltip:Show()
    end
end

local BindRowButton_OnLeave = function(button)
    if not config:IsInMouseFocus(button.DeleteButton) then
        button.DeleteButton:Hide()
    end
    config.ui.tooltip:Hide()
end

local BindRowDeleteButton_OnEnter = function(button)
    config.ui.tooltip:SetOwner(button, "ANCHOR_TOP")
    config.ui.tooltip:AddLine(L["Delete this binding"])
    config.ui.tooltip:Show()
end

local BindRowDeleteButton_OnLeave = function(button)
    local deleteButtonHasFocus = config:IsInMouseFocus(button)
    local bindButtonHasFocus = config:IsInMouseFocus(button:GetParent())
    if (not bindButtonHasFocus) or (not deleteButtonHasFocus) then
        button:Hide()
    end
    config.ui.tooltip:Hide()
end

local BindRowDeleteButton_OnClick = function(button)
    local parent = button:GetParent()
    local bind = parent.id
    addon:DeleteBinding(bind)

    page:UPDATE_BROWSE_PAGE()
end

---Initialize a binding row, including behaviour scripts and binding data from the provider
---@param button table the CliqueBindingTemplate row frame
---@param data {id: table, icon: number|string, name: string, text: string, bindingText: string, warning: string?}
function page:InitializeBindingRow(button, data)
    if not button.created then
        table.insert(page.bindRows, button)
        button.created = true

        button:SetPushedAtlas("ClickCastList-ButtonHighlight")
        button:SetScript("OnClick", BindRowButton_OnClick)
        button:SetScript("OnDoubleClick", BindRowButton_OnDoubleClick)
        button:SetScript("OnEnter", BindRowButton_OnEnter)
        button:SetScript("OnLeave", BindRowButton_OnLeave)

        button.DeleteButton:SetScript("OnEnter", BindRowDeleteButton_OnEnter)
        button.DeleteButton:SetScript("OnLeave", BindRowDeleteButton_OnLeave)
        button.DeleteButton:SetScript("OnClick", BindRowDeleteButton_OnClick)
    end

    button.id = data.id
    button.warning = data.warning
    button.Icon:SetTexture(data.icon)
    button.Name:SetText(data.name)
    button.Text:SetText(data.text)
    button.BindingText:SetText(data.bindingText)

    if button.id == page.selectedBind then
        button:SetNormalAtlas("ClickCastList-ButtonHighlight")
    else
        button:ClearNormalTexture()
    end
end

function page:ClearSelectedBindRow()
    page.selectedBind = nil
end

---Select or deselect a row in the binding list
---@param button table the CliqueBindingTemplate row frame
function page:SelectBindRow(button)

    -- Toggle the current bind button or set a new one
    if page.selectedBind == button.id then
        page.selectedBind = nil
    else
        page.selectedBind = button.id
    end

    -- Update the highlight textures for all bind rows
    for idx, row in ipairs(page.bindRows) do
        if row.id == page.selectedBind then
            row:SetNormalAtlas("ClickCastList-ButtonHighlight")
        else
            row:ClearNormalTexture()
        end
    end

    -- Enable or disable the 'Edit' button
    if page.selectedBind then
        page.frame.EditButton:Enable()
    else
        page.frame.EditButton:Disable()
    end
end

function page:ChangeSortOrder(key)
    page.sortOrder = key
    page:UPDATE_BROWSE_PAGE()
end

function page:GetSortOrder()
    if not page.sortOrder then
        page.sortOrder = "key"
    end
    return page.sortOrder
end

function page:SetFilterSearchText(text)
    -- Filter by name
    -- strip out non-alpha and space chars
    local filter = text:gsub("[^a-zA-Z0-9%s]", ""):lower()
    page.searchFilter = filter
    page:UPDATE_BROWSE_PAGE()
end

function page:EnableSearch()
    page.frame.SearchBox:SetScript("OnTextChanged", function(me)
        SearchBoxTemplate_OnTextChanged(me)
        page:SetFilterSearchText(me:GetText())
    end)
end

-- Use the data tables from below to filter
function page:FilterEntry(data)
    if not page.searchFilter then return true end
    local filter = page.searchFilter

    if string.lower(data.name or ""):match(filter) then
        return true
    elseif string.lower(data.text or ""):match(filter) then
        return true
    elseif string.lower(data.bindingText or ""):match(filter) then
        return true
    end

    return false
end


function page:UPDATE_BROWSE_PAGE()
    local dataProvider = page.frame.dataProvider
    dataProvider:Flush()

    local binds = addon.bindings
    local sorted = {}
    for idx, entry in pairs(binds) do
        sorted[#sorted+1] = entry
    end

    local sortOrder = page:GetSortOrder()
    if sortOrder == "key" then
        addon:SortBindingsByKey(sorted)
    elseif sortOrder == "name" then
        addon:SortBindingsByName(sorted)
    end

    -- Send the bindings to the data provider
    local bindingData = {}

    for idx,  bind in ipairs(sorted) do
        local data = {
            id = bind,
            icon = addon:GetBindingIcon(bind),
            name = addon:GetBindingActionText(bind.type, bind),
            text = addon:GetBindingInfoText(bind),
            bindingText = addon:GetBindingKeyComboText(bind),
        }

        -- Good to flag broken bindings here
        if bind.type == "macro" and bind.macro then
            if not libMacros:MacroExistsByName(bind.macro) then
                data.text = L["|cffFF4800No macros with name '%s' exists"]:format(bind.macro)
            elseif libMacros:MacroNameIsAmbiguous(bind.macro) then
                data.text = L["|cffFF4800Ambiguous macro name"]
                data.warning = L["Multiple macros are named '%s'. Which one of them runs is unpredictable."]:format(bind.macro)
            end
        end

        if addon:IsGamePadBinding(bind) and not addon:IsGamePadEnabled() then
            data.text = "|cffFF4800" .. L["Disabled - Gamepad not enabled"] .. "|r"
        end

        if page:FilterEntry(data) then
            table.insert(bindingData, data)
        end
    end

    dataProvider:InsertTable(bindingData)

    page:UpdateBindConfigWarning()
end

function page:UpdateBindConfigWarning()
    local warning = page.frame and page.frame.bindConfigWarning
    if not warning then
        return
    end

    local descriptor = addon:GetActiveBindConfigWarning()
    warning.descriptor = descriptor
    if descriptor then
        warning.text:SetText(page.alertIcon .. " " .. descriptor.title)
    end
    warning:SetShown(descriptor ~= nil)
end
