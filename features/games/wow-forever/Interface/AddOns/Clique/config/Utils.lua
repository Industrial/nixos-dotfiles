--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2024 - James N. Whitehead II
-------------------------------------------------------------------]] ---

---@class CliqueAddon: AddonCore
local addon = select(2, ...)

local libCatalog = addon.catalog
local libActions = addon.actionCatalog
local libSpellbook = addon.spellbookCatalog
local libMacros = addon.macroCatalog

---@class BindingConfig
local config = addon:GetBindingConfig()

-- Globals used in this file
local GetMouseFoci = GetMouseFoci
local GetMouseFocus = GetMouseFocus

function config:IsInMouseFocus(frame)
    if GetMouseFoci then
        for idx, focus in ipairs(GetMouseFoci()) do
            if focus == frame then
                return true
            end
        end
        return false
    else
        return GetMouseFocus() == frame
    end
end

-- Return a table that contains the action attributes for an entry
-- from the action catalog keyed by entryType and entryId
function config:GetActionAttributes(entryType, entryId)
    local draft = {}

    -- Now set the new attributes from the new entry
    if entryType == libCatalog.entryType.Spell or entryType == libCatalog.entryType.Pet then
        local spellName, texture = libSpellbook:GetSpellNameTexture(entryId)
        local spellSubName = libSpellbook:GetSpellSubName(entryId)

        if spellSubName == "" then
            spellSubName = nil
        end

        draft.type = "spell"
        draft.spell = spellName
        draft.spellSubName = spellSubName
        draft.icon = texture
    elseif entryType == libCatalog.entryType.Macro then
        local name, icon, body = libMacros:GetMacroNameIconBody(entryId)

        draft.type = "macro"
        draft.macro = name
        draft.icon = icon
    elseif entryType == libCatalog.entryType.Action then
        local name, icon, atype, unit, payload = libActions:GetNameIconTypeUnit(entryId)

        draft.type = atype
        draft.icon = icon
        if unit then draft.unit = unit end
        if atype == "item" and payload then draft.item = payload end
        if atype == "macro" and payload then draft.macrotext = payload end
    end

    return draft
end

-- Remove the action information from a bind table
function config:RemoveActionFromBinding(bind)
    if bind.type == "target" then
        -- nothing extra to remove
    elseif bind.type == "menu" then
        -- nothing extra to remove
    elseif bind.type == "spell" then
        bind.spell = nil
        bind.spellSubName = nil
    elseif bind.type == "macro" then
        bind.macrotext = nil
        bind.macro = nil
    elseif bind.type == "item" then
        bind.item = nil
    end

    bind.icon = nil
    bind.type = nil
    bind.unit = nil
end

-- Copy the action information from bind to dest
function config:CopyActionFromTo(bind, dest)
    if bind.type == "target" then
        -- nothing extra to copy
    elseif bind.type == "menu" then
        -- nothing extra to copy
    elseif bind.type == "spell" then
        dest.spell = bind.spell
        dest.spellSubName = bind.spellSubName
    elseif bind.type == "macro" then
        dest.macro = bind.macro
        dest.macrotext = bind.macrotext
    elseif bind.type == "item" then
        dest.item = bind.item
    end

    dest.icon = bind.icon
    dest.type = bind.type
    dest.unit = bind.unit
end

-- Shared checkbox scroll list infrastructure, used by BlizzFramesConfigPage
-- and DenylistPage.

local CHECKBOX_ROW_HEIGHT = 34

local function CheckboxRow_OnClick(btn)
    local checked = not not btn:GetChecked()
    btn.data.checked = checked
    PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF, "UI")
    btn.data.onToggle(btn.data.key, checked)
end

local function InitCheckboxRow(frame, data)
    if not frame.checkInitialized then
        frame.checkInitialized = true

        frame.check = CreateFrame("CheckButton", nil, frame)
        frame.check:SetHeight(29)
        frame.check:SetWidth(30)
        frame.check:SetNormalAtlas("checkbox-minimal")
        frame.check:SetPushedAtlas("checkbox-minimal")

        frame.check.checkedTexture = frame.check:CreateTexture(nil, "ARTWORK")
        frame.check.checkedTexture:SetAllPoints()
        frame.check.checkedTexture:SetAtlas("checkmark-minimal")
        frame.check:SetCheckedTexture(frame.check.checkedTexture)

        frame.check:SetPoint("LEFT", frame, "LEFT", 5, 0)
        frame.check:SetScript("OnClick", CheckboxRow_OnClick)

        frame.checkLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frame.checkLabel:SetJustifyH("LEFT")
        frame.checkLabel:SetWordWrap(false)
        frame.checkLabel:SetPoint("LEFT", frame.check, "RIGHT", 5, 0)
        frame.checkLabel:SetPoint("RIGHT", frame, "RIGHT", -5, 0)

        frame:SetScript("OnEnter", function(f)
            if f.data and f.data.tooltip and config.ui and config.ui.tooltip then
                local tip = config.ui.tooltip
                tip:SetOwner(f, "ANCHOR_RIGHT")
                tip:SetText(f.data.tooltip, nil, nil, nil, nil, true)
                tip:Show()
            end
        end)
        frame:SetScript("OnLeave", function()
            if config.ui and config.ui.tooltip then
                config.ui.tooltip:Hide()
            end
        end)
    end

    -- Hide dropdown/editbox widgets if this frame was previously another row type
    if frame.dropInitialized then
        frame.dropLabel:Hide()
        frame.dropdown:Hide()
    end
    if frame.editInitialized then
        frame.editLabel:Hide()
        frame.editbox:Hide()
        frame.editButton:Hide()
    end

    frame.check:Show()
    frame.checkLabel:Show()
    frame.checkLabel:SetText(data.label)
    frame.check:SetChecked(data.checked)
    frame.check.data = data
end

local DROPDOWN_TEXT_MAX = 16
local DROPDOWN_WIDTH    = 200

local function truncateDropdownText(text)
    if #text > DROPDOWN_TEXT_MAX then
        return text:sub(1, DROPDOWN_TEXT_MAX - 2) .. ".."
    end
    return text
end

local function InitDropdownRow(frame, data)
    if not frame.dropInitialized then
        frame.dropInitialized = true

        frame.dropLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frame.dropLabel:SetJustifyH("LEFT")
        frame.dropLabel:SetWordWrap(false)
        frame.dropLabel:SetPoint("LEFT", frame, "LEFT", 5, 0)

        frame.dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1FilterDropdownTemplate")
        frame.dropdown:SetHeight(22)
        frame.dropdown:SetPoint("RIGHT", frame, "RIGHT", -5, 0)
        frame.dropdown:SetPoint("LEFT", frame, "RIGHT", -(DROPDOWN_WIDTH + 5), 0)

        frame.dropLabel:SetPoint("RIGHT", frame.dropdown, "LEFT", -8, 0)
    end

    -- Hide checkbox/editbox widgets if this frame was previously another row type
    if frame.checkInitialized then
        frame.check:Hide()
        frame.checkLabel:Hide()
    end
    if frame.editInitialized then
        frame.editLabel:Hide()
        frame.editbox:Hide()
        frame.editButton:Hide()
    end

    frame.dropLabel:Show()
    frame.dropdown:Show()
    frame.dropLabel:SetText(data.label)
    frame.dropdown:SetText(truncateDropdownText(data.buttonText or ""))
    frame.dropdown:SetupMenu(data.menuBuilder)

    if data.enabled == false then
        frame.dropdown:Disable()
    else
        frame.dropdown:Enable()
    end
end

local EDITBOX_BUTTON_WIDTH = 80
local EDITBOX_INPUT_WIDTH  = 175

local function EditboxRow_OnClick(btn)
    btn.data.onButton(btn:GetParent().editbox, btn)
end

local function EditboxRow_OnTextChanged(editbox, userInput)
    if userInput then
        editbox.data.text = editbox:GetText()
        if editbox.data.onTextChanged then
            editbox.data.onTextChanged(editbox)
        end
    end
end

local function InitEditboxRow(frame, data)
    if not frame.editInitialized then
        frame.editInitialized = true

        frame.editLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frame.editLabel:SetJustifyH("LEFT")
        frame.editLabel:SetWordWrap(false)
        frame.editLabel:SetPoint("LEFT", frame, "LEFT", 5, 0)

        frame.editButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        frame.editButton:SetHeight(22)
        frame.editButton:SetWidth(EDITBOX_BUTTON_WIDTH)
        frame.editButton:SetPoint("RIGHT", frame, "RIGHT", -5, 0)
        frame.editButton:SetScript("OnClick", EditboxRow_OnClick)

        frame.editbox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        frame.editbox:SetHeight(20)
        frame.editbox:SetPoint("RIGHT", frame.editButton, "LEFT", -5, 0)
        frame.editbox:SetPoint("LEFT", frame, "RIGHT", -(EDITBOX_BUTTON_WIDTH + 10 + EDITBOX_INPUT_WIDTH), 0)
        frame.editbox:SetAutoFocus(false)
        frame.editbox:SetMaxLetters(0)
        frame.editbox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        frame.editbox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        frame.editbox:SetScript("OnEditFocusGained", function(self)
            if self.data and self.data.highlightOnFocus then
                self:HighlightText()
            end
        end)
        frame.editbox:SetScript("OnTextChanged", EditboxRow_OnTextChanged)

        frame.editLabel:SetPoint("RIGHT", frame.editbox, "LEFT", -5, 0)
    end

    -- Hide checkbox/dropdown widgets if this frame was previously another row type
    if frame.checkInitialized then
        frame.check:Hide()
        frame.checkLabel:Hide()
    end
    if frame.dropInitialized then
        frame.dropLabel:Hide()
        frame.dropdown:Hide()
    end

    frame.editLabel:Show()
    frame.editbox:Show()
    frame.editButton:Show()

    frame.editLabel:SetText(data.label)
    frame.editbox:SetText(data.text or "")
    frame.editbox.data = data
    frame.editButton:SetText(data.buttonText or "")
    frame.editButton.data = data

    if data.onInit then
        data.onInit(frame.editbox, frame.editButton)
    end
end

local function InitSettingsRow(frame, data)
    if data.rowType == "dropdown" then
        InitDropdownRow(frame, data)
    elseif data.rowType == "editbox" then
        InitEditboxRow(frame, data)
    else
        InitCheckboxRow(frame, data)
    end
end

function config:CreateSettingsList(parent, topAnchor, bottomAnchor, opts)
    opts = opts or {}

    local template = opts.backdrop and "TooltipBackdropTemplate" or nil
    local container = CreateFrame("Frame", nil, parent, template)
    container:SetPoint("TOPLEFT", unpack(topAnchor))
    container:SetPoint("BOTTOMRIGHT", unpack(bottomAnchor))

    if opts.backdrop then
        container:SetFrameLevel(2)
        local bgR, bgG, bgB = BLACK_FONT_COLOR:GetRGB()
        container:SetBackdropColor(bgR, bgG, bgB, 1)
        local borderR, borderG, borderB = DARKGRAY_COLOR:GetRGB()
        container:SetBackdropBorderColor(borderR, borderG, borderB, 1)
    end

    local scrollBox = CreateFrame("Frame", nil, container, "WowScrollBoxList")
    if opts.backdrop then
        scrollBox:SetPoint("TOPLEFT", 5, -5)
        scrollBox:SetPoint("BOTTOMRIGHT", -5, 5)
    else
        scrollBox:SetAllPoints()
    end

    local scrollBar = CreateFrame("EventFrame", nil, container, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", container, "TOPRIGHT", 10, 0)
    scrollBar:SetPoint("BOTTOMLEFT", container, "BOTTOMRIGHT", 10, 0)

    local dataProvider = CreateDataProvider()
    local scrollView = CreateScrollBoxListLinearView()
    scrollView:SetElementExtent(CHECKBOX_ROW_HEIGHT)
    scrollView:SetElementInitializer("Frame", InitSettingsRow)
    scrollView:SetDataProvider(dataProvider)

    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, scrollView)

    local inset = opts.backdrop and 5 or 0
    local scrollBoxAnchors = {
        CreateAnchor("TOPLEFT",     container, "TOPLEFT",     inset, -inset),
        CreateAnchor("BOTTOMRIGHT", container, "BOTTOMRIGHT", -inset,  inset),
    }
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(
        scrollBox, scrollBar, scrollBoxAnchors, scrollBoxAnchors)

    return dataProvider, container
end

function config:CreateCheckboxScrollList(parent, topAnchor, bottomAnchor, opts)
    return config:CreateSettingsList(parent, topAnchor, bottomAnchor, opts)
end

function addon:DeleteBindingMouseFocus()
    local bind = GetMouseFocus().id
    bind.type = "spell"
    bind.spell = "Dash"
    addon:DeleteBinding(bind)

    local page = config:GetBrowsePage()
    page:UPDATE_BROWSE_PAGE()
end
