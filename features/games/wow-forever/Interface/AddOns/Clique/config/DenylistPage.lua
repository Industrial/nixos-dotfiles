--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2024 - James N. Whitehead II
-------------------------------------------------------------------]] ---

---@class CliqueAddon: AddonCore
local addon = select(2, ...)
local L = addon.L

---@class BindingConfig
local config = addon:GetBindingConfig()

local page = {}

function config:GetDenylistPage()
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

function page:Initialize()
    if page.initialized then
        return
    end

    page.initialized = true
    page.frame = CreateFrame("Frame", "CliqueConfigUIBindingFrameDenylistPage", config.ui)
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

    frame.selectAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.selectAll:SetText(L["Select All"])
    frame.selectAll:SetHeight(23)
    frame.selectAll:SetWidth(100)
    frame.selectAll:SetPoint("BOTTOMLEFT", frame.backButton, "BOTTOMRIGHT", 5, 0)
    frame.selectAll:SetScript("OnClick", function()
        page:SelectAll(true)
    end)

    frame.selectNone = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.selectNone:SetText(L["Select None"])
    frame.selectNone:SetHeight(23)
    frame.selectNone:SetWidth(100)
    frame.selectNone:SetPoint("BOTTOMLEFT", frame.selectAll, "BOTTOMRIGHT", 5, 0)
    frame.selectNone:SetScript("OnClick", function()
        page:SelectAll(false)
    end)

    frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -60)
    frame.title:SetText(L["Frame Denylist"])

    frame.intro = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.intro:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -8)
    frame.intro:SetPoint("RIGHT", frame, "RIGHT", -15, 0)
    frame.intro:SetJustifyH("LEFT")
    frame.intro:SetJustifyV("TOP")
    frame.intro:SetNonSpaceWrap(true)
    frame.intro:SetHeight(52)
    frame.intro:SetText(L["This panel allows you to deny certain frames from being included for Clique bindings. Any frames that are selected in this list will not be registered. A UI reload is required for denied frames to return to their original bindings."])

    frame.dataProvider, frame.listContainer = config:CreateCheckboxScrollList(frame,
        { frame, "TOPLEFT", 10, -130 },
        { frame, "BOTTOMRIGHT", -30, 40 },
        { backdrop = false })
end

local function toggleDenylist(key, checked)
    if checked then
        addon.settings.blacklist[key] = true
    else
        addon.settings.blacklist[key] = nil
    end
    addon:FireMessage("BLACKLIST_CHANGED")
    addon:ConfirmSettingReload()
end

function page:Refresh()
    local dataProvider = page.frame.dataProvider
    dataProvider:Flush()

    local sorted = {}
    for frame in pairs(addon.ccframes) do
        table.insert(sorted, frame:GetName())
    end
    for name in pairs(addon.hccframes) do
        table.insert(sorted, name)
    end
    table.sort(sorted)

    for _, name in ipairs(sorted) do
        dataProvider:Insert({
            label = name,
            key = name,
            checked = not not addon.settings.blacklist[name],
            onToggle = toggleDenylist,
        })
    end
end

function page:SelectAll(checked)
    local dataProvider = page.frame.dataProvider
    for idx = 1, dataProvider:GetSize() do
        local item = dataProvider:Find(idx)
        if checked then
            addon.settings.blacklist[item.key] = true
        else
            addon.settings.blacklist[item.key] = nil
        end
        dataProvider:ReplaceAtIndex(idx, {
            label = item.label,
            key = item.key,
            checked = checked,
            onToggle = item.onToggle,
        })
    end
    addon:FireMessage("BLACKLIST_CHANGED")
    addon:ConfirmSettingReload()
end
