--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2024 - James N. Whitehead II
-------------------------------------------------------------------]] ---

---@class CliqueAddon: AddonCore
local addon = select(2, ...)
local L = addon.L

---@class BindingConfig
local config = addon:GetBindingConfig()

local page = {}

-- Globals used in this file
local PlaySound = PlaySound
local SOUNDKIT = SOUNDKIT

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
    frame.SaveButton:SetWidth(120)
    frame.SaveButton:ClearAllPoints()
    frame.SaveButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 5)
    frame.SaveButton:SetScript("OnClick", function(self, button)
        page:SaveButton_OnClick(self, button)
    end)

    frame.CancelButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.CancelButton:SetText(L["Cancel"])
    frame.CancelButton:SetHeight(23)
    frame.CancelButton:SetWidth(120)
    frame.CancelButton:ClearAllPoints()
    frame.CancelButton:SetPoint("RIGHT", frame.SaveButton, "LEFT", 0, 0)
    frame.CancelButton:SetScript("OnClick", function(self, button)
        page:CancelButton_OnClick(self, button)
    end)

    frame.RemoveRankButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.RemoveRankButton:SetText(L["Remove rank/school"])
    frame.RemoveRankButton:SetHeight(23)
    frame.RemoveRankButton:SetWidth(200)
    frame.RemoveRankButton:ClearAllPoints()
    frame.RemoveRankButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 5)
    frame.RemoveRankButton:Hide()
    frame.RemoveRankButton:SetScript("OnClick", function(self, button)
        page:RemoveRankButton_OnClick(self, button)
    end)

    frame.bindSummary = CreateFrame("Button", nil, frame, "CliqueBindingSummaryTemplate")
    frame.bindSummary:SetWidth(200)
    frame.bindSummary:SetHeight(100)
    frame.bindSummary.Icon:SetTexture(132212)
    frame.bindSummary.Name:SetText("Name")
    frame.bindSummary.Text:SetText("Some text")
    frame.bindSummary.BindingText:SetText("Binding text")

    frame.bindSummary:ClearAllPoints()
    frame.bindSummary:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -65)
    frame.bindSummary:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -15, -65)

    frame.changeBinding = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.changeBinding:SetText(L["Change binding"])
    frame.changeBinding:ClearAllPoints()
    frame.changeBinding:SetPoint("TOPRIGHT", frame.bindSummary, "BOTTOMRIGHT", 0, -5)
    frame.changeBinding:SetWidth(150)
    frame.changeBinding:SetHeight(32)
    frame.changeBinding.border = frame.changeBinding:CreateTexture(nil, "OVERLAY")
    frame.changeBinding.border:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
    frame.changeBinding.border:SetTexCoord(0, 0.625, 0, 0.6875)
    frame.changeBinding.border:SetBlendMode("ADD")
    frame.changeBinding.border:SetAllPoints()
    frame.changeBinding.border:Hide()

    -- Glow box for when changing a binding
    frame.changeBindingArrow = CreateFrame("Frame", nil, frame, "GlowBoxArrowTemplate")
    frame.changeBindingArrow:ClearAllPoints()
    frame.changeBindingArrow:SetPoint("TOP", frame.changeBinding, "BOTTOM", -10, -2)

    frame.changeBindingHelpBox = CreateFrame("Frame", nil, frame.changeBindingArrow, "GlowBoxTemplate")
    frame.changeBindingHelpBox:SetWidth(250)
    frame.changeBindingHelpBox:SetHeight(120)
    frame.changeBindingHelpBox:ClearAllPoints()
    frame.changeBindingHelpBox:SetPoint("TOPLEFT", frame.changeBindingArrow, "BOTTOMLEFT", 0, -5)
    frame.changeBindingHelpBox.Text = frame.changeBindingHelpBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.changeBindingHelpBox.Text:SetJustifyH("LEFT")
    frame.changeBindingHelpBox.Text:SetJustifyV("MIDDLE")
    frame.changeBindingHelpBox.Text:SetPoint("TOPLEFT", 10, -5)
    frame.changeBindingHelpBox.Text:SetPoint("BOTTOMRIGHT", -10, 5)

    local changeBindingHelptext = L["You are in binding capture mode! You can either click with your mouse or press a key on your keyboard to set a binding. You can modify the binding by holding down a combination of the alt, control and shift keys on your keyboard."]
    frame.changeBindingHelpBox.Text:SetText(changeBindingHelptext)
    frame.changeBindingHelpBox:SetFrameStrata("HIGH")
    frame.changeBindingArrow:Hide()

    -- Glow box for when creating a new binding
    frame.addBindingHelpBox = CreateFrame("Frame", nil, frame.bindSummary, "GlowBoxTemplate")
    frame.addBindingHelpBox:SetWidth(300)
    frame.addBindingHelpBox:SetHeight(75)
    frame.addBindingHelpBox:ClearAllPoints()
    frame.addBindingHelpBox:SetPoint("TOPLEFT", frame, "TOPRIGHT", 10, -5)
    frame.addBindingHelpBox.Text = frame.addBindingHelpBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.addBindingHelpBox.Text:SetJustifyH("LEFT")
    frame.addBindingHelpBox.Text:SetJustifyV("MIDDLE")
    frame.addBindingHelpBox.Text:SetPoint("TOPLEFT", 10, -5)
    frame.addBindingHelpBox.Text:SetPoint("BOTTOMRIGHT", -10, 5)

    local addBindingHelpText = L["Select a spell or macro using the window to the right, and use the Change binding button to set a click or key binding. The binding behaviour can be configured using the settings below."]
    frame.addBindingHelpBox.Text:SetText(addBindingHelpText)
    frame.addBindingHelpBox:SetFrameStrata("HIGH")
    frame.addBindingHelpBox:Show()

    frame.changeBinding:RegisterForClicks("AnyDown")
    page:ChangeBindingButton_Initialize(frame.changeBinding)

    frame.editMacro = CreateFrame("Button", nil, frame, "UIMenuButtonStretchTemplate")
    frame.editMacro:SetText(L["Edit Macro"])
    frame.editMacro:ClearAllPoints()
    frame.editMacro:SetPoint("TOPLEFT", frame.changeBinding, "BOTTOMLEFT", 0, -5)
    frame.editMacro:SetWidth(125)

    frame.editMacro:SetScript("OnClick", function(button)
        local macrotext = page.draftBinding.macrotext
        local icon = page.draftBinding.icon

        config:SwitchToEditMacroPage(macrotext, icon)
    end)

    local bindConfigData = {
        -- [1]: Default bind-set
        {
            name = "Default",
            key = "default",
            label = L["Active on unit frames (|cffffd100default|r)"],
            tooltipTitle = L["Clique: 'default' binding-set"],
            tooltip = L["A binding that belongs to the 'default' binding-set will always be active on your unit frames, unless you override it with another binding."],
        },
        -- [2]: OOC bind-set
        {
            name = "OOC",
            key = "ooc",
            label = L["Only cast when out-of-combat (|cffffd100ooc|r)"],
            tooltipTitle = L["Clique: 'ooc' binding-set"],
            tooltip = L["A binding that belongs to the 'ooc' binding-set will only be active when the player is out-of-combat, regardless of the other binding-sets this binding belongs to. As soon as the player enters combat, these bindings will no longer be active, so be careful when choosing this binding-set for any spells you use frequently."],
        },
        -- [3]: Friend bind-set
        {
            name = "Friend",
            key = "friend",
            label = L["Only cast on friendly units (|cffffd100friend|r)"],
            tooltipTitle = L["Clique: 'friend' binding-set"],
            tooltip = L["A binding that belongs to the 'friend' binding-set will only be active when clicking on unit frames that display friendly units, i.e. those you can heal and assist. If you click on a unit that you cannot heal or assist, nothing will happen."],
        },
        -- [4]: Enemy bind-set
        {
            name = "Enemy",
            key = "enemy",
            label = L["Only cast on enemy units (|cffffd100enemy|r)"],
            tooltipTitle = L["Clique: 'enemy' binding-set"],
            tooltip = L["A binding that belongs to the 'enemy' binding-set will always be active when clicking on unit frames that display enemy units, i.e. those you can attack. If you click on a unit that you cannot attack, nothing will happen."],
        },
        -- [5]: Hovercast bind-set
        {
            name = "Hovercast",
            key = "hovercast",
            label = L["Only active when mouse is over a unit (|cffffd100hovercast|r)"],
            tooltipTitle = L["Clique: 'hovercast' binding-set"],
            tooltip = L["A binding that belongs to the 'hovercast' binding-set is active whenever the mouse is over a unit frame, or a character in the 3D world. This allows you to use 'hovercasting', where you hover over a unit in the world and press a key to cast a spell on them. These bindings are also active over unit frames."],
        },
        -- [6]: Global bind-set
        {
            name = "Global",
            key = "global",
            label = L["Always active, will override game bindings (|cffffd100global|r)"],
            tooltipTitle = L["Clique: 'global' binding-set"],
            tooltip = L["A binding that belongs to the 'global' binding-set is always active. If the spell requires a target, you will be given the 'casting hand', otherwise the spell will be cast. If the spell is an AOE spell, you will be given the ground targeting circle."],
        },
    }

    if addon:PlayerHasMultiTalentSpecs() then
        for idx = 1, addon:GetNumTalentSpecs() do
            local name = "Spec" .. idx
            local key = name:lower()
            local specName = addon:GetTalentSpecName(idx)
            local label = L["Active for talent spec: %s (|cffffd100%s|r)"]:format(specName, key)
            table.insert(bindConfigData, {
                name = name,
                key = key,
                label = label,
                tooltipTitle = L["Clique: Talent binding-set for '%s'"]:format(specName),
                tooltip = L["A binding that belongs to this binding-set is only active when the player has the given talent specialization active"],
            })
        end
    end

    local bindSets = {}
    for idx, entry in ipairs(bindConfigData) do
        table.insert(bindSets, page:CreateBindSetCheckbox(frame, entry.name, entry.label, entry.tooltipTitle, entry.tooltip))
    end

    for idx, entry in ipairs(bindSets) do
        if idx == 1 then
            entry:ClearAllPoints()
            entry:SetPoint("TOPLEFT", frame.bindSummary, "BOTTOMLEFT", 5, -25)
        else
            entry:ClearAllPoints()
            entry:SetPoint("TOPLEFT", bindSets[idx-1], "BOTTOMLEFT", 0, -5)
        end
    end

    page.bindSetFrames = {}
    for idx, entry in ipairs(bindSets) do
        local key = entry.key:lower()
        page.bindSetFrames[key] = entry
    end
end

local function BindSetCheckbox_OnEnter(self, motion)
    if self.tooltip then
        config.ui.tooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.tooltipTitle then
            config.ui.tooltip:AddLine(self.tooltipTitle, 1, 1, 1)
        end
        config.ui.tooltip:AddLine(self.tooltip, nil, nil, nil, true)
        config.ui.tooltip:Show()
    end
end

local function BindSetCheckbox_OnLeave(self, motion)
    config.ui.tooltip:Hide()
end

local function BindSetCheckbox_OnClick(self)
    local checked = self:GetChecked()
    if checked then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    else
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    end

    page:ToggleBindSet(self.key, checked)
end

function page:CreateBindSetCheckbox(parent, key, text, tooltipTitle, tooltip)
    local nameKey = string.format("BindSetCheckButton%s", key)
    local button = CreateFrame("CheckButton", nil, parent)
    parent[nameKey] = button
    button.nameKey = nameKey
    button.key = key
    button.tooltipTitle = tooltipTitle
    button.tooltip = tooltip

    button:SetHeight(29)
    button:SetWidth(30)
    button:SetNormalAtlas("checkbox-minimal")
    button:SetPushedAtlas("checkbox-minimal")

    button.checkedTexture = button:CreateTexture(nil, "ARTWORK")
    button.checkedTexture:SetAllPoints()
    button.checkedTexture:SetAtlas("checkmark-minimal")
    button:SetCheckedTexture(button.checkedTexture)

    button.name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.name:SetJustifyH("LEFT")
    button.name:SetWordWrap(false)
    button.name:ClearAllPoints()
    button.name:SetPoint("LEFT", button, "RIGHT", 5, 0)
    button.name:SetText(text)

    button:SetScript("OnEnter", BindSetCheckbox_OnEnter)
    button:SetScript("OnLeave", BindSetCheckbox_OnLeave)
    button:SetScript("OnClick", BindSetCheckbox_OnClick)

    return button
end

local function ChangeBindingButton_OnEnter(self, motion)
    if motion and self.bindMode then
        self:EnableKeyboard(true)
        if addon:IsGamePadEnabled() then
            self:EnableGamePadButton(true)
        end
    end
end

local function ChangeBindingButton_OnLeave(self, motion)
    self:EnableKeyboard(false)
    self:EnableGamePadButton(false)
end

local function ChangeBindingButton_CaptureAndEndBinding(key)
    local captured = addon:GetCapturedKey(key)
    if captured then
        page:ChangeBindingKey(captured)
        page.frame.changeBinding.bindMode = false
        page.frame.changeBindingArrow:Hide()
        page:UpdateEditPage()
        page.frame.changeBinding.border:Hide()
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
        local button = (delta > 0) and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"
        ChangeBindingButton_CaptureAndEndBinding(button)
    end
end

local function ChangeBindingButton_OnGamePadButtonDown(self, key)
    if self.bindMode then
        ChangeBindingButton_CaptureAndEndBinding(key)
    end
end

function page:ChangeBindingButton_Initialize(button)
    button:SetScript("OnEnter", ChangeBindingButton_OnEnter)
    button:SetScript("OnLeave", ChangeBindingButton_OnLeave)
    button:SetScript("OnClick", ChangeBindingButton_OnClick)
    button:SetScript("OnKeyDown", ChangeBindingButton_OnKeyDown)
    button:SetScript("OnMouseWheel", ChangeBindingButton_OnMouseWheel)
    button:SetScript("OnGamePadButtonDown", ChangeBindingButton_OnGamePadButtonDown)
    button:EnableKeyboard(false)
    button:EnableGamePadButton(false)
end

local pageMode = {
    EDIT = "edit",
    NEW = "new",
}

function page:ShowEditPageNewBinding()
    page:ResetPage()

    local draft = config:GetDefaultBindTable()
    page:SetDraftFromTable(draft)
    page.selectedBinding = nil
    page.mode = pageMode.NEW

    page:UpdateEditPage()
    page:Show()
end

function page:ShowEditPageSelectedBinding(bind)
    page:ResetPage()

    page:SetDraftFromTable(bind)
    page.selectedBinding = bind
    page.mode = pageMode.EDIT

    page:UpdateEditPage()
    page:Show()
end

function page:ResetPage()
    -- Reset to default behaviour

    page.selectedBinding = nil
    page.draftBinding = nil
    page.mode = nil

    page.rankRemoved = nil

    -- Visual display for change binding button and binding mode
    page.frame.changeBinding.bindMode = false
    page.frame.changeBindingArrow:Hide()
end

-- All edits happen on the 'draft' binding which then gets moved over
-- when things are saved, this is where we set the initial draft binding
function page:SetDraftFromTable(bind)
    page.draftBinding = {}

    local draft = page.draftBinding
    -- Action attributes
    draft.type  = bind.type
    draft.spell = bind.spell
    draft.spellSubName = bind.spellSubName
    draft.macro = bind.macro
    draft.macrotext = bind.macrotext
    draft.item  = bind.item
    -- Icon, key, unit
    draft.icon = bind.icon
    draft.key = bind.key
    draft.unit = bind.unit
    -- Need to copy sets over
    draft.sets = {}
    for k,v in pairs(bind.sets) do
        draft.sets[k] = v
    end
end

local function tableIsEmpty(tbl)
    for k, v in pairs(tbl) do
        return false
    end
    return true
end

-- Detect if the bind sets have changed between orig and draft
local function bindSetsChanged(orig, draft)
    local osets = orig.sets
    local dsets = draft.sets

    for k, v in pairs(osets) do
        if dsets[k] ~= v then
            return true
        end
    end

    for k, v in pairs(dsets) do
        if osets[k] ~= v then
            return true
        end
    end

    return false
end

-- Detect if the action has changed from orig to draft
local function actionChanged(orig, draft, rankRemoved)
    if orig.type ~= draft.type then
        return true
    elseif orig.spell ~= draft.spell then
        return true
    elseif orig.macro ~= draft.macro then
        return true
    elseif orig.macrotext ~= draft.macrotext then
        return true
    elseif orig.item ~= draft.item then
        return true
    elseif orig.unit ~= draft.unit then
        return true
    elseif rankRemoved and orig.spellSubName ~= nil then
        -- If the original has a rank, but the new had rank removed
        return true
    end

    return false
end

-- Detect if the key binding has changed from orig to draft
local function keyChanged(orig, draft)
    return orig.key ~= draft.key
end

-- Detect if the icon has changed
local function iconChanged(orig, draft)
    return orig.icon ~= draft.icon
end


-- Actually update all of the elements of the page
function page:UpdateEditPage()
    -- Default values for a new or binding with missing values
    local name = L["New Binding"]
    ---@type string|number
    local icon = "Interface\\Icons\\INV_Misc_QuestionMark"
    local text = L["Not part of any bind-sets"]
    local bindingText = L["No binding set"]

    local draft = page.draftBinding

    if draft.type then
        name = addon:GetBindingActionText(draft.type, draft, page.rankRemoved)
        icon = addon:GetBindingIcon(draft)
    end

    if draft.sets and not tableIsEmpty(draft.sets) then
        text = addon:GetBindingInfoText(draft)
    end

    if draft.key then
        bindingText = addon:GetBindingKeyComboText(draft)
    end

    -- Now check and see if those differ from the original
    local dirty = false

    local orig
    if page.mode == pageMode.EDIT then
        orig = page.selectedBinding
    elseif page.mode == pageMode.NEW then
        orig = config:GetDefaultBindTable()
    end

    if actionChanged(orig, draft, page.rankRemoved) then
        dirty = true
        name = string.format(L["|cff22ff22Changed|r: %s"], name)
    end

    if bindSetsChanged(orig, draft) then
        dirty = true
        text = string.format(L["|cff22ff22Changed|r: %s"], text)
    end

    if keyChanged(orig, draft) then
        dirty = true
        bindingText = string.format(L["|cff22ff22Changed|r: %s"], bindingText)
    end

    if iconChanged(orig, draft) then
        dirty = true
    end

    local bindSummary = page.frame.bindSummary
    bindSummary.Name:SetText(name)
    bindSummary.Icon:SetTexture(icon)
    bindSummary.Text:SetText(text)
    bindSummary.BindingText:SetText(bindingText)

    -- Now update the bind-set checkboxes to reflect what is in draft
    for key, frame in pairs(page.bindSetFrames) do
        local checked = not not draft.sets[key]
        frame:SetChecked(checked)
    end

    -- If the binding is a spell and we have a rank
    if draft.type == "spell" and draft.spellSubName then
        page.frame.RemoveRankButton:Show()
    end

    -- Every "valid" binding needs an action and a key
    local valid = (draft.type ~= nil) and (draft.key ~= nil)

    if dirty and valid then
        page.frame.SaveButton:Enable()
    else
        page.frame.SaveButton:Disable()
    end

    if draft.type == "macro" and not draft.macro then
        -- This is a custom macro binding, so enable the edit button
        page.frame.editMacro:Show()
    else
        page.frame.editMacro:Hide()
    end
end


-- Change the binding action for the current edit page to the new action
-- removing the previous attributes if set
function page:ChangeBindingAction(entryType, entryId)
    local draft = page.draftBinding

    -- Need to remove the current attributes
    config:RemoveActionFromBinding(draft)

    -- Get the action attributes from the catalog entry and copy to draft
    local actionAttributes = config:GetActionAttributes(entryType, entryId)
    config:CopyActionFromTo(actionAttributes, draft)

    if actionAttributes.icon then
        draft.icon = actionAttributes.icon
    end

    page:UpdateEditPage()
end

-- Change the key binding for the current edit page
function page:ChangeBindingKey(key)
    local draft = page.draftBinding
    draft.key = key

    page:UpdateEditPage()
end

function page:SetMacrotextIcon(macrotext, icon)
    local draft = page.draftBinding

    draft.macrotext = macrotext
    draft.icon = icon

    page:UpdateEditPage()
end

function page:RemoveRankButton_OnClick(self, button)
    page.rankRemoved = true
    page:UpdateEditPage()
    self:Hide()
end

function page:ToggleBindSet(key, checked)
    local draft = page.draftBinding
    key = key:lower()

    checked = not not checked
    if checked then
        draft.sets[key] = true
    else
        draft.sets[key] = nil
    end
    page:UpdateEditPage()
end

function page:SaveButton_OnClick(self, button)
    local draft = page.draftBinding

    if page.mode == pageMode.NEW then
        -- Simple case of a new binding, draft should contain the new bind info
        addon:AddBinding(draft)
    else
        -- We are editing an existing binding
        local orig = page.selectedBinding
        if actionChanged(orig, draft, page.rankRemoved) then
            -- Remove previous action information from orig
            config:RemoveActionFromBinding(orig)

            -- Copy the action from draft to orig
            config:CopyActionFromTo(draft, orig)

            if page.rankRemoved then
                orig.spellSubName = nil
            end
        end

        if bindSetsChanged(orig, draft) then
            orig.sets = {}
            for key, value in pairs(draft.sets) do
                orig.sets[key] = value
            end
        end

        if keyChanged(orig, draft) then
            orig.key = draft.key
        end

        if iconChanged(orig, draft) then
            orig.icon = draft.icon
        end
    end

    -- Notify the addon that bindings have changed
    addon:FireMessage("BINDINGS_CHANGED")
    -- Clear the edit page to prevent consistency issues
    page:ResetPage()

    -- Swap back to the browse page
    config:SwitchToBrowsePage()
end

function page:CancelButton_OnClick(self, button)
    page:ResetPage()
    config:SwitchToBrowsePage()
end
