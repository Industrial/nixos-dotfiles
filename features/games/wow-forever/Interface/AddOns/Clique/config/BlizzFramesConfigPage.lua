--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2024 - James N. Whitehead II
-------------------------------------------------------------------]] ---

---@class CliqueAddon: AddonCore
local addon = select(2, ...)
local L = addon.L

---@class BindingConfig
local config = addon:GetBindingConfig()

local page = {}

function config:GetBlizzFramesPage()
    return page
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

--[[-------------------------------------------------------------------
--  Page implementation
-------------------------------------------------------------------]] ---

function page:Initialize()
    if page.initialized then
        return
    end

    page.initialized = true
    page.frame = CreateFrame("Frame", "CliqueConfigUIBindingFrameBlizzFramesPage", config.ui)
    local frame = page.frame

    frame:SetAllPoints()
    frame:Hide()

    frame.backButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.backButton:SetText(L["Back"])
    frame.backButton:SetHeight(23)
    frame.backButton:SetWidth(120)
    frame.backButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 5)
    frame.backButton:SetScript("OnClick", function()
        config:SwitchToBrowsePage()
    end)

    frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -60)
    frame.title:SetText(L["Blizzard Frame Options"])

    frame.intro = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.intro:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -8)
    frame.intro:SetPoint("RIGHT", frame, "RIGHT", -15, 0)
    frame.intro:SetJustifyH("LEFT")
    frame.intro:SetJustifyV("TOP")
    frame.intro:SetNonSpaceWrap(true)
    frame.intro:SetHeight(52)
    frame.intro:SetText(L["These options control whether or not Clique automatically registers certain Blizzard-created frames for binding. Changes made to these settings will not take effect until the user interface is reloaded."])

    frame.dataProvider, frame.listContainer = config:CreateCheckboxScrollList(frame,
        { frame, "TOPLEFT", 10, -130 },
        { frame, "BOTTOMRIGHT", -30, 40 },
        { backdrop = false })
end

function page:Refresh()
    local dataProvider = page.frame.dataProvider
    dataProvider:Flush()

    local opt = addon.settings.blizzframes
    local function toggle(key, checked)
        opt[key] = checked
    end

    local items = {
        { key = "statusBarFix",   label = L["Fix issue with health and power bars"] },
        { key = "PlayerFrame",    label = L["Player frame"] },
        { key = "PetFrame",       label = L["Player's pet frame"] },
        { key = "TargetFrame",    label = L["Player's target frame"] },
        { key = "TargetFrameToT", label = L["Target of target frame"] },
        { key = "party",          label = L["Party member frames"] },
        { key = "compactraid",    label = L["Compact raid frames"] },
        { key = "boss",           label = L["Boss target frames"] },
    }

    if not addon:ProjectIsClassic() then
        table.insert(items, { key = "FocusFrame",    label = L["Player's focus frame"] })
        table.insert(items, { key = "FocusFrameToT", label = L["Target of focus frame"] })
    end

    if addon:ProjectIsRetail() then
        table.insert(items, { key = "arena", label = L["Arena enemy frames"] })
    end

    for _, item in ipairs(items) do
        item.checked = not not opt[item.key]
        item.onToggle = toggle
        dataProvider:Insert(item)
    end
end
