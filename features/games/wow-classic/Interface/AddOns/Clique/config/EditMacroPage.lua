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
local CreateAnchor = CreateAnchor
local CreateScrollBoxListGridView = CreateScrollBoxListGridView
local GetMacroIcons = GetMacroIcons
local GetMacroItemIcons = GetMacroItemIcons

function config:GetEditMacroPage()
    return page
end

function page:Show()
    page.frame:Show()
end

function page:Hide()
    page.frame:Hide()
end

function page:Initialize()
    if page.initialized then
        return
    end

    page.initialized = true

    page.frame = CreateFrame("Frame", "CliqueConfigUIBindingFrameEditMacroPage", config.ui)
    local frame = page.frame

    frame:SetAllPoints()
    frame:Hide()

    frame.SaveButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.SaveButton:SetText(L["Okay"])
    frame.SaveButton:SetHeight(23)
    frame.SaveButton:SetWidth(120)
    frame.SaveButton:ClearAllPoints()
    frame.SaveButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 5)
    frame.SaveButton:SetScript("OnClick", function(self, button)
        local macrotext, icon = page:GetMacrotextIcon()
        config:SendEditMacroToEditPage(macrotext, icon)
        page:ResetPage()
        config:CloseToEditPage()
    end)

    frame.CancelButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.CancelButton:SetText(L["Cancel"])
    frame.CancelButton:SetHeight(23)
    frame.CancelButton:SetWidth(120)
    frame.CancelButton:ClearAllPoints()
    frame.CancelButton:SetPoint("RIGHT", frame.SaveButton, "LEFT", 0, 0)
    frame.CancelButton:SetScript("OnClick", function(button)
        page:ResetPage()
        config:CloseToEditPage()
    end)

    -- BindSummary
    frame.bindSummary = CreateFrame("Button", nil, frame, "CliqueBindingSummaryTemplate")
    frame.bindSummary:SetWidth(200)
    frame.bindSummary:SetHeight(100)
    frame.bindSummary.Icon:SetTexture(4635266)
    frame.bindSummary.Name:SetText(L["Run custom macro"])
    frame.bindSummary.Text:SetText("")
    frame.bindSummary.BindingText:SetText("")

    -- Tweak the bindSummary text so we can show the macro
    frame.bindSummary.Text:SetWidth(300)
    frame.bindSummary.Text:SetHeight(100)
    frame.bindSummary.Text:SetJustifyV("BOTTOM")
    frame.bindSummary.Text:SetWordWrap(true)
    frame.bindSummary.Text:SetMaxLines(5)

    frame.bindSummary:ClearAllPoints()
    frame.bindSummary:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -65)
    frame.bindSummary:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -15, -65)

    -- Macro icons
    frame.background = CreateFrame("Frame", "CliqueConfigUIEditMacroIconBackground", frame, "TooltipBackdropTemplate")
    frame.background:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 15, 260)
    frame.background:SetPoint("BOTTOMRIGHT", -31, 40)

    frame.iconScrollFrame = CreateFrame("Frame", nil, frame.background, "WowScrollBoxList")
    local scrollFrame = frame.iconScrollFrame
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", -5, 0)

    scrollFrame.scrollbar = CreateFrame("EventFrame", nil, frame, "MinimalScrollBar")
    scrollFrame.scrollbar:ClearAllPoints()
    scrollFrame.scrollbar:SetPoint("TOPLEFT", frame.background, "TOPRIGHT", 10, 0)
    scrollFrame.scrollbar:SetPoint("BOTTOMLEFT", frame.background, "BOTTOMRIGHT", 10, 0)

    frame.dataProvider = page:GetIconDataProvider()
    local dataProvider = frame.dataProvider

    local stride = 10
    local top = 5
    local bottom = 5
    local left = 5
    local right = 5
    local horizontalSpacing = 10
    local verticalSpacing = 10
    local scrollView = CreateScrollBoxListGridView(stride, top, bottom, left, right, horizontalSpacing, verticalSpacing)

    scrollView:SetElementInitializer("CliqueMacroIconTemplate", function(button, data)
        page:MacroIconButton_Initializer(button, data)
    end)
    scrollView:SetDataProvider(dataProvider)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollFrame, scrollFrame.scrollbar, scrollView)

    -- Edit box
    frame.EditBox = CreateFrame("Frame", nil, frame, "CliqueScrollingEditBoxTemplate")
    local editBox = frame.EditBox

    editBox:SetPoint("BOTTOMLEFT", frame.background, "TOPLEFT", 0, 10)
    editBox:SetWidth(435)
    editBox:SetHeight(85)

    local label = L["Create a custom macro using the text box below. You may need to specify the target of any actions using the 'mouseover' unit, which will be the unit that you click on. For example:\n\n/cast [target=mouseover] Regrowth\n/cast [@mouseover] Regrowth\n/cast [@cursor] Blizzard"]
    editBox.Label = editBox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    editBox.Label:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 0, 5)
    editBox.Label:SetPoint("BOTTOMRIGHT", editBox, "TOPRIGHT", 0, 5)
    editBox.Label:SetWordWrap(true)
    editBox.Label:SetMaxLines(9)
    editBox.Label:SetJustifyV("BOTTOM")
    editBox.Label:SetJustifyH("LEFT")
    editBox.Label:SetText(label)

    local function OnTextChanged(o, editBox, userChanged)
        local text = editBox:GetText()
        if userChanged then
            page:UpdateText(text)
        end
    end

    editBox.ScrollingEditBox:RegisterCallback("OnTextChanged", OnTextChanged, editBox)

    local scrollBox = editBox.ScrollingEditBox:GetScrollBox()
    ScrollUtil.RegisterScrollBoxWithScrollBar(scrollBox, editBox.ScrollBar)

    local scrollBoxAnchorsWithBar = {
        CreateAnchor("TOPLEFT", editBox.ScrollingEditBox, "TOPLEFT", 0, 0),
        CreateAnchor("BOTTOMRIGHT", editBox.ScrollingEditBox, "BOTTOMRIGHT", -18, -1),
    }
    local scrollBoxAnchorsWithoutBar = {
        scrollBoxAnchorsWithBar[1],
        CreateAnchor("BOTTOMRIGHT", editBox.ScrollingEditBox, "BOTTOMRIGHT", -2, -1),
    }
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, editBox.ScrollBar, scrollBoxAnchorsWithBar, scrollBoxAnchorsWithoutBar)
end

local function MacroIconButton_OnClick(button)
    -- When the user clicks a macro icon, if there is a highlighted
    -- macro icon somewhere, clear that
    if page.selectedButton and page.selectedButton ~= button then
        page.selectedButton.SelectedTexture:Hide()
    end

    button.SelectedTexture:Show()
    page.selectedButton = button
    page.selectedButtonId = button.id

    -- Update bind summary
    page:UpdateIcon(button.id)
end

function page:MacroIconButton_Initializer(button, data)
    if not button.created then
        button.created = true

        button:SetScript("OnClick", MacroIconButton_OnClick)
    end

    button.SelectedTexture:Hide()
    button:SetNormalTexture(data)
    button.id = data

    if page.selectedButtonId and page.selectedButtonId == button.id then
        button.SelectedTexture:Show()
    end
end

function page:ResetPage()
    page.draft = {}

    -- Macro icon that is selected, and corresponding id
    if page.selectedButton then
        page.selectedButton.SelectedTexture:Hide()
    end
    page.selectedButton = nil
    page.selectedButtonId = nil

    page.frame.EditBox.ScrollingEditBox:ClearText()
    page:UpdatePage()
end

function page:GetMacrotextIcon()
    local macrotext = page.draft.text
    local icon = page.draft.icon

    return macrotext, icon
end

function page:UpdateEditBox(text)
    local editbox = page.frame.EditBox
    if text and text ~= "" then
        editbox.ScrollingEditBox:SetText(text)
    else
        editbox.ScrollingEditBox:ClearText()
    end
end

function page:UpdateText(text)
    if not page.draft then
        page.draft = {}
    end
    page.draft.text = text
    page:UpdatePage()
end

function page:UpdateIcon(icon)
    if not page.draft then
        page.draft = {}
    end
    page.draft.icon = icon
    page:UpdatePage()
end

function page:UpdatePage()
    local macrotext = page.draft and page.draft.text or ""
    local icon = page.draft and page.draft.icon or 4635266
    local bindSummary = page.frame.bindSummary

    bindSummary.Text:SetText(macrotext)
    bindSummary.Icon:SetTexture(icon)
end


function page:GetIconDataProvider()
    if not self.iconDataProvider then
        local dataProvider = CreateDataProvider()

        local macroItems = {}
        local macroItemIcons = {}

        GetMacroIcons(macroItems)
        GetMacroItemIcons(macroItemIcons)

        dataProvider:InsertTable(macroItems)
        dataProvider:InsertTable(macroItemIcons)

        self.iconDataProvider = dataProvider
    end

    return self.iconDataProvider
end
