--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2026 - James N. Whitehead II
-------------------------------------------------------------------]] ---

-- The binding editor. Bind-sets are shown as Where/Units/When/Specialization
-- controls; see "Edit page controls and saved bind-sets" in docs/bindings.md.

---@class CliqueAddon: AddonCore
local addon = select(2, ...)
local L = addon.L

---@class BindingConfig
local config = addon:GetBindingConfig()

local page = {}

-- Globals used in this file
local PlaySound = PlaySound
local SOUNDKIT = SOUNDKIT

local pageMode = {
    EDIT = "edit",
    NEW = "new",
}

local WHERE_TEXT = addon.BindSetChoiceText.where
local UNITS_TEXT = addon.BindSetChoiceText.units
local WHEN_TEXT = addon.BindSetChoiceText.when

local WHERE_TOOLTIPS = {
    frames = L["Works when the mouse is over a unit frame that Clique manages."],
    anyunit = L["The action goes to the unit under the mouse: on unit frames, nameplates, or characters in the world. With no unit under the mouse, nothing happens, even for spells that need no target. On unit frames, a 'Unit frames' binding on the same key is preferred."],
    anywhere = L["Works like an action bar key. The mouse can be anywhere, and the spell uses your current target. A mouse click on a unit frame uses that frame's unit. On unit frames, a 'Unit frames' binding on the same key is preferred. Use this for spells you do not want on an action bar. Do not use the same key for an 'Any unit under the mouse' binding."],
}

-- The old edit page's names, so players can find their bind-sets
local WHERE_BIND_SETS = { frames = "default", anyunit = "hovercast", anywhere = "global" }

local UNITS_ANYWHERE_TOOLTIP = L["'Anywhere' bindings use your current target and/or self-cast rules, so they cannot differentiate between friendly or hostile units."]
local LAST_SPEC_TOOLTIP = L["To use this binding in every specialization, select All."]

local CONTROL_SIZE = 22
local CONTROL_INDENT = 10

function config:GetEditPage()
    return page
end

function page:Show()
    page.frame:Show()
end

function page:IsShown()
    return page.frame:IsShown()
end

function page:Hide()
    page.frame:Hide()
end

local function Control_OnEnter(control)
    local text = control.tooltip
    if not control:IsEnabled() then
        text = control.disabledTooltip or text
    end
    if text then
        config.ui.tooltip:SetOwner(control, "ANCHOR_RIGHT")
        if control.tooltipTitle then
            config.ui.tooltip:AddLine(control.tooltipTitle, 1, 1, 1)
        end
        config.ui.tooltip:AddLine(text, nil, nil, nil, true)
        config.ui.tooltip:Show()
    end
end

local function Control_OnLeave()
    config.ui.tooltip:Hide()
end

-- The result area shows one line; the tooltip has all of them
local function Result_OnEnter(result)
    local tooltip = config.ui.tooltip
    tooltip:SetOwner(result, "ANCHOR_TOP")
    for idx, line in ipairs(result.lines) do
        if idx == 1 then
            tooltip:AddLine(line)
        else
            tooltip:AddLine(line, 1, 1, 1, true)
        end
    end
    tooltip:Show()
end

local function PreviousSets_OnEnter(previous)
    local tooltip = config.ui.tooltip
    tooltip:SetOwner(previous, "ANCHOR_RIGHT")
    tooltip:AddLine(previous.Text:GetText(), 1, 1, 1, true)
    tooltip:Show()
end

local function CreateHeading(parent, text)
    local heading = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetJustifyH("LEFT")
    heading:SetText(text)
    return heading
end

-- The radial tick from the modern dropdown menus; older clients may lack its atlas
local function RadioTemplate()
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("common-dropdown-tickradial") then
        return "UIRadialButtonTemplate"
    end
    return "UIRadioButtonTemplate"
end

local function CreateRadio(parent, text, onSelect)
    local radio = CreateFrame("CheckButton", nil, parent, RadioTemplate())
    -- The template sizes its art to the atlas; match the spec checkboxes instead
    radio:SetSize(CONTROL_SIZE, CONTROL_SIZE)
    for _, texture in ipairs({ radio:GetNormalTexture(), radio:GetHighlightTexture(), radio:GetCheckedTexture() }) do
        texture:ClearAllPoints()
        texture:SetAllPoints()
    end
    radio.text:SetFontObject("GameFontHighlight")
    radio.text:SetText(text)
    radio:SetHitRectInsets(0, -(radio.text:GetStringWidth() + 5), 0, 0)
    radio:SetMotionScriptsWhileDisabled(true)
    radio:SetScript("OnEnter", Control_OnEnter)
    radio:SetScript("OnLeave", Control_OnLeave)
    radio:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        onSelect()
    end)
    return radio
end

local function CreateRadioRow(parent, heading, entries, onSelect)
    local radios = {}
    for idx, entry in ipairs(entries) do
        local radio = CreateRadio(parent, entry.text, function() onSelect(entry.value) end)
        if idx == 1 then
            radio:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", CONTROL_INDENT, -3)
        else
            radio:SetPoint("LEFT", radios[idx - 1].text, "RIGHT", 15, 0)
        end
        radio.value = entry.value
        radios[idx] = radio
    end
    return radios
end

local function CreateInfoIcon(parent, anchor, tooltipTitle, tooltip)
    local icon = CreateFrame("Button", nil, parent)
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", anchor, "RIGHT", 4, 0)
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    icon.texture:SetTexture("Interface\\FriendsFrame\\InformationIcon")
    icon.tooltipTitle = tooltipTitle
    icon.tooltip = tooltip
    icon:SetScript("OnEnter", Control_OnEnter)
    icon:SetScript("OnLeave", Control_OnLeave)
    return icon
end

local function CreateSpecCheckbox(parent, idx)
    local button = CreateFrame("CheckButton", nil, parent)
    button:SetSize(CONTROL_SIZE, CONTROL_SIZE)
    button:SetNormalAtlas("checkbox-minimal")
    button:SetPushedAtlas("checkbox-minimal")
    button.checkedTexture = button:CreateTexture(nil, "ARTWORK")
    button.checkedTexture:SetAllPoints()
    button.checkedTexture:SetAtlas("checkmark-minimal")
    button:SetCheckedTexture(button.checkedTexture)

    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.text:SetJustifyH("LEFT")
    button.text:SetWordWrap(false)
    button.text:SetPoint("LEFT", button, "RIGHT", 5, 0)
    button.text:SetText(addon:GetTalentSpecName(idx) or L["Spec %d"]:format(idx))
    button:SetHitRectInsets(0, -(button.text:GetStringWidth() + 5), 0, 0)

    button.specIndex = idx
    button:SetMotionScriptsWhileDisabled(true)
    button:SetScript("OnEnter", Control_OnEnter)
    button:SetScript("OnLeave", Control_OnLeave)
    button:SetScript("OnClick", function(btn)
        PlaySound(btn:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        page:ToggleSpec(btn.specIndex, btn:GetChecked())
    end)
    return button
end

-- Greys out a radio or checkbox, and its label
local function SetControlEnabled(control, enabled)
    control:SetEnabled(enabled)
    control:SetAlpha(enabled and 1 or 0.5)
    control.text:SetFontObject(enabled and "GameFontHighlight" or "GameFontDisable")
end

function page:Initialize()
    if page.initialized then
        return
    end

    page.initialized = true

    page.frame = CreateFrame("Frame", "CliqueConfigUIBindingFrameEditPage", config.ui)
    local frame = page.frame

    frame:SetAllPoints()
    frame:Hide()

    frame.SaveButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.SaveButton:SetText(L["Save Binding"])
    frame.SaveButton:SetHeight(23)
    config:FitButtonToText(frame.SaveButton, 120)
    frame.SaveButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 5)
    frame.SaveButton:SetScript("OnClick", function(self, button)
        page:SaveButton_OnClick(self, button)
    end)

    frame.CancelButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.CancelButton:SetText(L["Cancel"])
    frame.CancelButton:SetHeight(23)
    config:FitButtonToText(frame.CancelButton, 120)
    frame.CancelButton:SetPoint("RIGHT", frame.SaveButton, "LEFT", -4, 0)
    frame.CancelButton:SetScript("OnClick", function(self, button)
        page:CancelButton_OnClick(self, button)
    end)

    frame.RemoveRankButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.RemoveRankButton:SetText(L["Remove rank/school"])
    frame.RemoveRankButton:SetHeight(23)
    frame.RemoveRankButton:SetWidth(200)
    frame.RemoveRankButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 5)
    frame.RemoveRankButton:Hide()
    frame.RemoveRankButton:SetScript("OnClick", function(self, button)
        page:RemoveRankButton_OnClick(self, button)
    end)

    frame.bindSummary = CreateFrame("Button", nil, frame, "CliqueBindingSummaryTemplate")
    frame.bindSummary:SetHeight(100)
    frame.bindSummary.Icon:SetTexture(132212)
    frame.bindSummary:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -65)
    frame.bindSummary:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -15, -65)

    frame.changeBinding = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.changeBinding:SetText(L["Change binding"])
    frame.changeBinding:SetPoint("TOPRIGHT", frame.bindSummary, "BOTTOMRIGHT", 0, -5)
    frame.changeBinding:SetWidth(150)
    frame.changeBinding:SetHeight(32)
    frame.changeBinding.border = frame.changeBinding:CreateTexture(nil, "OVERLAY")
    frame.changeBinding.border:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
    frame.changeBinding.border:SetTexCoord(0, 0.625, 0, 0.6875)
    frame.changeBinding.border:SetBlendMode("ADD")
    frame.changeBinding.border:SetAllPoints()
    frame.changeBinding.border:Hide()

    frame.changeBindingArrow = CreateFrame("Frame", nil, frame, "GlowBoxArrowTemplate")
    frame.changeBindingArrow:SetPoint("TOP", frame.changeBinding, "BOTTOM", -10, -2)

    frame.changeBindingHelpBox = CreateFrame("Frame", nil, frame.changeBindingArrow, "GlowBoxTemplate")
    frame.changeBindingHelpBox:SetWidth(250)
    frame.changeBindingHelpBox:SetHeight(120)
    frame.changeBindingHelpBox:SetPoint("TOPLEFT", frame.changeBindingArrow, "BOTTOMLEFT", 0, -5)
    frame.changeBindingHelpBox.Text = frame.changeBindingHelpBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.changeBindingHelpBox.Text:SetJustifyH("LEFT")
    frame.changeBindingHelpBox.Text:SetJustifyV("MIDDLE")
    frame.changeBindingHelpBox.Text:SetPoint("TOPLEFT", 10, -5)
    frame.changeBindingHelpBox.Text:SetPoint("BOTTOMRIGHT", -10, 5)
    frame.changeBindingHelpBox.Text:SetText(L["You are in binding capture mode! You can either click with your mouse or press a key on your keyboard to set a binding. You can modify the binding by holding down a combination of the alt, control and shift keys on your keyboard."])
    frame.changeBindingHelpBox:SetFrameStrata("HIGH")
    frame.changeBindingArrow:Hide()

    frame.addBindingHelpBox = CreateFrame("Frame", nil, frame.bindSummary, "GlowBoxTemplate")
    frame.addBindingHelpBox:SetWidth(300)
    frame.addBindingHelpBox:SetHeight(75)
    frame.addBindingHelpBox:SetPoint("TOPLEFT", frame, "TOPRIGHT", 10, -5)
    frame.addBindingHelpBox.Text = frame.addBindingHelpBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.addBindingHelpBox.Text:SetJustifyH("LEFT")
    frame.addBindingHelpBox.Text:SetJustifyV("MIDDLE")
    frame.addBindingHelpBox.Text:SetPoint("TOPLEFT", 10, -5)
    frame.addBindingHelpBox.Text:SetPoint("BOTTOMRIGHT", -10, 5)
    frame.addBindingHelpBox.Text:SetText(L["Select a spell or macro using the window to the right, and use the Change binding button to set a click or key binding. The binding behaviour can be configured using the settings below."])
    frame.addBindingHelpBox:SetFrameStrata("HIGH")
    frame.addBindingHelpBox:Show()

    frame.changeBinding:RegisterForClicks("AnyDown")
    page:ChangeBindingButton_Initialize(frame.changeBinding)

    frame.editMacro = CreateFrame("Button", nil, frame, "UIMenuButtonStretchTemplate")
    frame.editMacro:SetText(L["Edit Macro"])
    frame.editMacro:SetPoint("TOPLEFT", frame.changeBinding, "BOTTOMLEFT", 0, -5)
    frame.editMacro:SetWidth(125)
    frame.editMacro:SetScript("OnClick", function()
        config:SwitchToEditMacroPage(page.draftBinding.macrotext, page.draftBinding.icon)
    end)

    -- Two lines fit above the Where heading; the tooltip has the full text
    frame.previousSets = CreateFrame("Frame", nil, frame)
    frame.previousSets:SetPoint("TOPLEFT", frame.bindSummary, "BOTTOMLEFT", 5, -10)
    frame.previousSets:SetPoint("RIGHT", frame.changeBinding, "LEFT", -10, 0)
    frame.previousSets:SetHeight(30)
    frame.previousSets.Text = frame.previousSets:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.previousSets.Text:SetAllPoints()
    frame.previousSets.Text:SetJustifyH("LEFT")
    frame.previousSets.Text:SetJustifyV("TOP")
    frame.previousSets.Text:SetMaxLines(2)
    frame.previousSets:EnableMouse(true)
    frame.previousSets:SetScript("OnEnter", PreviousSets_OnEnter)
    frame.previousSets:SetScript("OnLeave", Control_OnLeave)

    page:InitializeControls(frame)
end

function page:InitializeControls(frame)
    -- Below the Change binding button, beside the Edit Macro button
    local whereHeading = CreateHeading(frame, L["Where the binding is active"])
    whereHeading:SetPoint("TOPLEFT", frame.bindSummary, "BOTTOMLEFT", 5, -45)

    page.whereRadios = {}
    for idx, where in ipairs({ "frames", "anyunit", "anywhere", "disabled" }) do
        local text = WHERE_TEXT[where]
        if WHERE_BIND_SETS[where] then
            text = ("%s (|cffffd100%s|r)"):format(text, WHERE_BIND_SETS[where])
        end
        local radio = CreateRadio(frame, text, function() page:SetChoice("where", where) end)
        if idx == 1 then
            radio:SetPoint("TOPLEFT", whereHeading, "BOTTOMLEFT", CONTROL_INDENT, -3)
        else
            radio:SetPoint("TOPLEFT", page.whereRadios[idx - 1], "BOTTOMLEFT", 0, where == "disabled" and -4 or 0)
        end
        if WHERE_TOOLTIPS[where] then
            radio.tooltipTitle = WHERE_TEXT[where]
            radio.tooltip = WHERE_TOOLTIPS[where]
            CreateInfoIcon(frame, radio.text, WHERE_TEXT[where], WHERE_TOOLTIPS[where])
        end
        radio.value = where
        page.whereRadios[idx] = radio
    end

    local unitsHeading = CreateHeading(frame, L["Which units the binding is active for"])
    unitsHeading:SetPoint("TOPLEFT", page.whereRadios[#page.whereRadios], "BOTTOMLEFT", -CONTROL_INDENT, -8)
    page.unitsRadios = CreateRadioRow(frame, unitsHeading, {
        { value = "all", text = UNITS_TEXT.all },
        { value = "friend", text = UNITS_TEXT.friend },
        { value = "enemy", text = UNITS_TEXT.enemy },
    }, function(value) page:SetChoice("units", value) end)

    local whenHeading = CreateHeading(frame, L["When the binding is active"])
    whenHeading:SetPoint("TOPLEFT", page.unitsRadios[1], "BOTTOMLEFT", -CONTROL_INDENT, -8)
    page.whenRadios = CreateRadioRow(frame, whenHeading, {
        { value = "always", text = WHEN_TEXT.always },
        { value = "ooc", text = WHEN_TEXT.ooc },
        { value = "combat", text = WHEN_TEXT.combat },
    }, function(value) page:SetChoice("when", value) end)

    page.specLabel = CreateHeading(frame, L["Active for talents"])
    page.specLabel:SetPoint("TOPLEFT", page.whenRadios[1], "BOTTOMLEFT", -CONTROL_INDENT, -8)
    page.specRadios = CreateRadioRow(frame, page.specLabel, {
        { value = "all", text = L["All"] },
        { value = "only", text = L["Only:"] },
    }, function(value) page:SetSpecMode(value) end)

    page.specCheckboxes = {}
    page.specRowStart, page.specRowWidth = page.specRadios[1], 0
    page:CreateSpecCheckboxes(addon:GetNumTalentSpecs())

    frame.result = CreateFrame("Frame", nil, frame)
    frame.result:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 15, 34)
    frame.result:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -15, 34)
    frame.result:SetHeight(28)
    frame.result.Background = frame.result:CreateTexture(nil, "BACKGROUND")
    frame.result.Background:SetAllPoints()
    -- The binding summary's background; older clients lack the atlas
    local atlasID = C_Texture and C_Texture.GetAtlasID and C_Texture.GetAtlasID("ClickCastList-ButtonBackground")
    if atlasID and atlasID ~= 0 then
        frame.result.Background:SetAtlas("ClickCastList-ButtonBackground", false)
    end
    frame.result.Text = frame.result:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.result.Text:SetPoint("LEFT", 10, 0)
    frame.result.Text:SetPoint("RIGHT", -10, 0)
    frame.result.Text:SetJustifyH("LEFT")
    frame.result.Text:SetWordWrap(false)
    frame.result:EnableMouse(true)
    frame.result:SetScript("OnEnter", Result_OnEnter)
    frame.result:SetScript("OnLeave", Control_OnLeave)
    frame.result:Hide()
end

-- Left to right, wrapping only when a (localized) spec name doesn't fit. Classic
-- clients gain a second spec when the player learns dual spec, so this can run again.
function page:CreateSpecCheckboxes(numSpecs)
    local maxWidth = config.ui:GetWidth() - 60
    for idx = #page.specCheckboxes + 1, numSpecs do
        local checkbox = CreateSpecCheckbox(page.frame, idx)
        local width = CONTROL_SIZE + 5 + checkbox.text:GetStringWidth()
        if idx > 1 and page.specRowWidth + 15 + width <= maxWidth then
            checkbox:SetPoint("LEFT", page.specCheckboxes[idx - 1].text, "RIGHT", 15, 0)
            page.specRowWidth = page.specRowWidth + 15 + width
        else
            checkbox:SetPoint("TOPLEFT", page.specRowStart, "BOTTOMLEFT", 0, -3)
            page.specRowStart, page.specRowWidth = checkbox, width
        end
        page.specCheckboxes[idx] = checkbox
    end
end

local function ChangeBindingButton_OnEnter(self, motion)
    if motion and self.bindMode then
        self:EnableKeyboard(true)
        if addon:IsGamePadEnabled() then
            self:EnableGamePadButton(true)
        end
    end
end

local function ChangeBindingButton_OnLeave(self)
    self:EnableKeyboard(false)
    self:EnableGamePadButton(false)
end

-- Keyboard input stays off, or the button keeps eating keys (e.g. Escape) while hovered
local function EndBindMode()
    local button = page.frame.changeBinding
    button.bindMode = false
    button.border:Hide()
    button:EnableKeyboard(false)
    button:EnableGamePadButton(false)
    page.frame.changeBindingArrow:Hide()
end

local function ChangeBindingButton_CaptureAndEndBinding(key)
    local captured = addon:GetCapturedKey(key)
    if captured then
        page.draftBinding.key = captured
        EndBindMode()
        page:UpdateEditPage()
    end
end

local function ChangeBindingButton_OnClick(self, button)
    if not self.bindMode then
        self.bindMode = true
        page.frame.changeBindingArrow:Show()
        page.frame.changeBinding.border:Show()
        self:EnableKeyboard(true)
        if addon:IsGamePadEnabled() then
            self:EnableGamePadButton(true)
        end
    else
        ChangeBindingButton_CaptureAndEndBinding(button)
    end
end

local function ChangeBindingButton_OnKeyDown(self, key)
    if self.bindMode then
        ChangeBindingButton_CaptureAndEndBinding(key)
    end
end

local function ChangeBindingButton_OnMouseWheel(self, delta)
    if self.bindMode then
        ChangeBindingButton_CaptureAndEndBinding((delta > 0) and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
    end
end

function page:ChangeBindingButton_Initialize(button)
    button:SetScript("OnEnter", ChangeBindingButton_OnEnter)
    button:SetScript("OnLeave", ChangeBindingButton_OnLeave)
    button:SetScript("OnClick", ChangeBindingButton_OnClick)
    button:SetScript("OnKeyDown", ChangeBindingButton_OnKeyDown)
    button:SetScript("OnMouseWheel", ChangeBindingButton_OnMouseWheel)
    button:SetScript("OnGamePadButtonDown", ChangeBindingButton_OnKeyDown)
    button:EnableKeyboard(false)
    button:EnableGamePadButton(false)
end

function page:ResetPage()
    page.selectedBinding = nil
    page.draftBinding = nil
    page.mode = nil
    page.choices = nil
    EndBindMode()
    page.frame.RemoveRankButton:Hide()
end

-- All edits happen on a copy, so Cancel leaves the saved binding untouched
function page:SetDraftFromTable(bind)
    local draft = {}
    for _, key in ipairs({ "type", "spell", "spellSubName", "macro", "macrotext", "item", "icon", "key", "unit" }) do
        draft[key] = bind[key]
    end
    draft.sets = {}
    for key, value in pairs(bind.sets or {}) do
        draft.sets[key] = value
    end
    page.draftBinding = draft
end

-- The controls show the nearest choices, but the saved bind-sets only change
-- when the player changes a control (see docs/bindings.md)
local function ShowDraft(selectedBinding, mode)
    page.selectedBinding = selectedBinding
    page.mode = mode
    page.choices = addon:GetBindSetChoices(page.draftBinding.sets, addon:GetNumTalentSpecs())
    page:UpdateEditPage()
    page:Show()
end

function page:ShowEditPageNewBinding()
    page:ResetPage()
    page:SetDraftFromTable(config:GetDefaultBindTable())
    ShowDraft(nil, pageMode.NEW)
end

function page:ShowEditPageSelectedBinding(bind)
    page:ResetPage()
    page:SetDraftFromTable(bind)
    ShowDraft(bind, pageMode.EDIT)
end

function page:ApplyChoices()
    page.draftBinding.sets = addon:GetBindSetsFromChoices(page.choices)
    page:UpdateEditPage()
end

-- A click on the selected choice changes nothing; otherwise it would convert
-- the saved bind-sets with no visible change (see docs/bindings.md)
function page:SetChoice(key, value)
    if page.choices[key] == value then
        page:UpdateControls()
        return
    end
    page.choices[key] = value
    page:ApplyChoices()
end

function page:SetSpecMode(mode)
    if (mode == "only") == (next(page.choices.specs) ~= nil) then
        page:UpdateControls()
        return
    end
    if mode == "all" then
        page.choices.specs = {}
    elseif not next(page.choices.specs) then
        page.choices.specs[addon:GetActiveTalentSpec() or 1] = true
    end
    page:ApplyChoices()
end

-- Clearing every checkbox returns to "All"; the last clear one is disabled
function page:ToggleSpec(idx, checked)
    page.choices.specs[idx] = checked and true or nil
    page:ApplyChoices()
end

local function actionChanged(orig, draft)
    return orig.type ~= draft.type or orig.spell ~= draft.spell or orig.spellSubName ~= draft.spellSubName
        or orig.macro ~= draft.macro or orig.macrotext ~= draft.macrotext or orig.item ~= draft.item
        or orig.unit ~= draft.unit
end

local function originalBinding()
    if page.mode == pageMode.EDIT then
        return page.selectedBinding
    end
    return config:GetDefaultBindTable()
end

function page:UpdateEditPage()
    local draft = page.draftBinding
    local orig = originalBinding()
    local changed = L["|cff22ff22Changed|r: %s"]

    local name = L["New Binding"]
    ---@type string|number
    local icon = "Interface\\Icons\\INV_Misc_QuestionMark"
    if draft.type then
        name = addon:GetBindingActionText(draft.type, draft)
        icon = addon:GetBindingIcon(draft)
    end
    local text = next(draft.sets) and addon:GetBindSetsDisplayText(draft) or addon.BindSetChoiceText.where.disabled
    local bindingText = draft.key and addon:GetBindingKeyComboText(draft) or L["No binding set"]

    local dirty = false
    if actionChanged(orig, draft) then
        dirty = true
        name = changed:format(name)
    end
    if not addon:BindSetsEqual(orig.sets, draft.sets) then
        dirty = true
        text = changed:format(text)
    end
    if orig.key ~= draft.key then
        dirty = true
        bindingText = changed:format(bindingText)
    end
    if orig.icon ~= draft.icon then
        dirty = true
    end

    local bindSummary = page.frame.bindSummary
    bindSummary.Name:SetText(name)
    bindSummary.Icon:SetTexture(icon)
    bindSummary.Text:SetText(text)
    bindSummary.BindingText:SetText(bindingText)

    local previous = page.frame.previousSets
    local saved = page.mode == pageMode.EDIT and orig.sets
    if saved and not addon:BindSetsEqual(saved, draft.sets)
        and not addon:BindSetsFitChoices(saved, addon:GetNumTalentSpecs()) then
        previous.Text:SetText(L["Previous bind-sets: %s"]:format(addon:GetBindingInfoText(orig)))
        previous:Show()
    else
        previous:Hide()
    end

    page.frame.RemoveRankButton:SetShown(draft.type == "spell" and draft.spellSubName ~= nil)

    local valid = addon:BindingHasAction(draft) and (draft.key ~= nil)
    page.frame.SaveButton:SetEnabled(dirty and valid)
    page.frame.editMacro:SetShown(draft.type == "macro" and not draft.macro)

    page:UpdateControls()
    page:UpdateResult()
end

local function SetRadioGroup(radios, value, enabled)
    for _, radio in ipairs(radios) do
        radio:SetChecked(enabled ~= "cleared" and radio.value == value)
        SetControlEnabled(radio, enabled == true)
    end
end

function page:UpdateControls()
    local choices = page.choices
    local disabled = choices.where == "disabled"

    for _, radio in ipairs(page.whereRadios) do
        radio:SetChecked(radio.value == choices.where)
    end

    -- "Disabled" clears the other controls on screen only; choices keeps them
    local others = not disabled or "cleared"
    SetRadioGroup(page.unitsRadios, choices.where == "anywhere" and "all" or choices.units,
        disabled and "cleared" or choices.where ~= "anywhere")
    for _, radio in ipairs(page.unitsRadios) do
        radio.disabledTooltip = choices.where == "anywhere" and UNITS_ANYWHERE_TOOLTIP or nil
    end
    SetRadioGroup(page.whenRadios, choices.when, others)

    local numSpecs = addon:GetNumTalentSpecs()
    local showSpecs = numSpecs > 1
    page:CreateSpecCheckboxes(numSpecs)
    page.specLabel:SetShown(showSpecs)
    local only = next(choices.specs) ~= nil
    for _, radio in ipairs(page.specRadios) do
        radio:SetShown(showSpecs)
    end
    SetRadioGroup(page.specRadios, only and "only" or "all", others)

    local selected = 0
    for idx = 1, numSpecs do
        if choices.specs[idx] then
            selected = selected + 1
        end
    end
    for idx, checkbox in ipairs(page.specCheckboxes) do
        checkbox:SetShown(showSpecs and idx <= numSpecs)
        local checked = not disabled and choices.specs[idx] == true
        checkbox:SetChecked(checked)
        local isLastClear = not checked and selected == numSpecs - 1
        SetControlEnabled(checkbox, not disabled and not isLastClear)
        checkbox.disabledTooltip = not disabled and isLastClear and LAST_SPEC_TOOLTIP or nil
    end
end

-- Shows how the draft would interact with the other bindings on its key, before Save
function page:UpdateResult()
    local result = page.frame.result
    local draft = page.draftBinding
    if not (draft.type and draft.key) or page.choices.where == "disabled" then
        result:Hide()
        return
    end

    local list, replaced = {}, false
    for _, entry in ipairs(addon.bindings) do
        if entry == page.selectedBinding then
            list[#list + 1] = draft
            replaced = true
        else
            list[#list + 1] = entry
        end
    end
    if not replaced then
        list[#list + 1] = draft
    end

    local lines = {}
    local status = addon:GetBindingStatuses(list)[draft]
    if status then
        lines[#lines + 1] = addon:GetBindingStatusLabel(status)
        for _, line in ipairs(status.lines) do
            lines[#lines + 1] = line
        end
    end
    for _, line in ipairs(addon:GetPreferredOverLines(list, draft)) do
        lines[#lines + 1] = line
    end

    result.lines = lines
    result.Text:SetText(lines[1])
    result:SetShown(#lines > 0)
end

function page:ChangeBindingAction(entryType, entryId)
    local draft = page.draftBinding
    config:RemoveActionFromBinding(draft)
    local actionAttributes = config:GetActionAttributes(entryType, entryId)
    config:CopyActionFromTo(actionAttributes, draft)
    if actionAttributes.icon then
        draft.icon = actionAttributes.icon
    end
    page:UpdateEditPage()
end

function page:SetMacrotextIcon(macrotext, icon)
    page.draftBinding.macrotext = macrotext
    page.draftBinding.icon = icon
    page:UpdateEditPage()
end

function page:RemoveRankButton_OnClick(self, button)
    page.draftBinding.spellSubName = nil
    page:UpdateEditPage()
end

function page:SaveButton_OnClick(self, button)
    local draft = page.draftBinding

    if page.mode == pageMode.NEW then
        addon:AddBinding(draft)
    else
        local orig = page.selectedBinding
        if actionChanged(orig, draft) then
            config:RemoveActionFromBinding(orig)
            config:CopyActionFromTo(draft, orig)
        end
        orig.sets = {}
        for key, value in pairs(draft.sets) do
            orig.sets[key] = value
        end
        orig.key = draft.key
        orig.icon = draft.icon
    end

    addon:FireMessage("BINDINGS_CHANGED")
    page:ResetPage()
    config:SwitchToBrowsePage()
end

function page:CancelButton_OnClick(self, button)
    page:ResetPage()
    config:SwitchToBrowsePage()
end
