--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2026 - James N. Whitehead II
-------------------------------------------------------------------]] ---

---@class CliqueAddon: AddonCore
local addon = select(2, ...)
local L = addon.L

---@class BindingConfig
local config = addon:GetBindingConfig()

local page = {}

function config:GetChangelogPage()
    return page
end

function page:Show()
    page.frame:ClearAllPoints()
    page.frame:SetAllPoints(config.ui)
    page.frame:Show()
    page:Refresh()

    -- Showing the page (manually or auto) clears the "newer than seen" state.
    addon.globalSettings.lastSeenChangelogVersion = addon:GetLatestChangelogVersion()
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
    if page.initialized then return end
    page.initialized = true

    page.frame = CreateFrame("Frame", "CliqueConfigUIBindingFrameChangelogPage", config.ui)
    local frame = page.frame
    frame:SetAllPoints()
    frame:Hide()

    frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -60)
    frame.title:SetText(L["What's New"])

    frame.backButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.backButton:SetText(L["Back"])
    frame.backButton:SetHeight(23)
    frame.backButton:SetWidth(120)
    frame.backButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 5)
    frame.backButton:SetScript("OnClick", function()
        config:SwitchToBrowsePage()
    end)

    frame.dontShow = CreateFrame("CheckButton", nil, frame, "SettingsCheckboxTemplate")
    frame.dontShow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 7)
    frame.dontShow:SetScript("OnClick", function(btn)
        addon.globalSettings.changelogDoNotShow = not not btn:GetChecked()
    end)

    frame.dontShowLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.dontShowLabel:SetPoint("RIGHT", frame.dontShow, "LEFT", -4, 0)
    frame.dontShowLabel:SetJustifyH("RIGHT")
    frame.dontShowLabel:SetText(L["Don't show this automatically"])

    -- Modern WowScrollBox + ScrollingEditBox (same widgets as the macro editor).
    -- The EditBox renders the |cff..|r colouring and lets the user select/copy.
    -- It's display-only: user edits are reverted in OnTextChanged, but selection
    -- and Ctrl-C still work because copying doesn't change the text.
    frame.editBox = CreateFrame("Frame", "CliqueConfigUIChangelogEditBox", frame, "CliqueChangelogEditBoxTemplate")
    frame.editBox:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", -4, -10)
    frame.editBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 40)

    local seb = frame.editBox.ScrollingEditBox
    page.seb = seb

    seb:RegisterCallback("OnTextChanged", function(_, _, userChanged)
        if userChanged then
            seb:SetText(page.displayText or "")
        end
    end, page)

    local scrollBox = seb:GetScrollBox()
    ScrollUtil.RegisterScrollBoxWithScrollBar(scrollBox, frame.editBox.ScrollBar)

    local scrollBoxAnchorsWithBar = {
        CreateAnchor("TOPLEFT", seb, "TOPLEFT", 0, 0),
        CreateAnchor("BOTTOMRIGHT", seb, "BOTTOMRIGHT", -18, -1),
    }
    local scrollBoxAnchorsWithoutBar = {
        scrollBoxAnchorsWithBar[1],
        CreateAnchor("BOTTOMRIGHT", seb, "BOTTOMRIGHT", -2, -1),
    }
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(
        scrollBox, frame.editBox.ScrollBar, scrollBoxAnchorsWithBar, scrollBoxAnchorsWithoutBar)
end

function page:Refresh()
    page.displayText = addon:BuildChangelogText()
    page.seb:SetText(page.displayText)

    page.frame.dontShow:SetChecked(addon.globalSettings.changelogDoNotShow)
end
