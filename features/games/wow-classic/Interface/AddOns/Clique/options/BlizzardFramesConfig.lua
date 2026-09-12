--[[-------------------------------------------------------------------
--  Clique - Copyright 2006-2024 - James N. Whitehead II
-------------------------------------------------------------------]] ---

local addonName = select(1, ...)

---@class CliqueAddon: AddonCore
local addon = select(2, ...)
local L = addon.L

--[[---------------------------------------------------------------------------
--  Options panel definition
---------------------------------------------------------------------------]]--

local panel = CreateFrame("Frame")
panel:Hide()

panel.name = L["Blizzard Frame Options"]
panel.parent = addonName

addon.optpanels["BLIZZFRAMES"] = panel

function panel:OnCommit()
    panel.okay()
end

function panel:OnDefault()
end

function panel:OnRefresh ()
    panel.refresh()
end

panel:SetScript("OnShow", function(self)
    if not panel.initialized then
        panel:CreateOptions()
        panel.refresh()
    end
end)

local function make_checkbox(name, label)
    local frame = CreateFrame("CheckButton", "CliqueOptionsBlizzFrame" .. name, panel, "UICheckButtonTemplate")
    frame.text = _G[frame:GetName() .. "Text"]
    frame.type = "checkbox"
    frame.text:SetText(label)
    return frame
end

local function make_label(name, template)
    local label = panel:CreateFontString("CliqueOptionsBlizzFrame" .. name, "OVERLAY", template)
    label:SetWidth(panel:GetWidth())
    label:SetJustifyH("LEFT")
    label.type = "label"
    return label
end

function panel:CreateOptions()
    panel.initialized = true

    local bits = {}
    self.intro = make_label("Intro", "GameFontHighlightSmall")
    self.intro:SetText(L["These options control whether or not Clique automatically registers certain Blizzard-created frames for binding. Changes made to these settings will not take effect until the user interface is reloaded."])
    self.intro:SetPoint("RIGHT")
    self.intro:SetJustifyV("TOP")
    self.intro:SetHeight(40)

    self.statusBarFix = make_checkbox("statusBarFix", L["Fix issue with health and power bars"])
    self.PlayerFrame = make_checkbox("PlayerFrame", L["Player frame"])
    self.PetFrame = make_checkbox("PetFrame", L["Player's pet frame"])
    self.TargetFrame = make_checkbox("TargetFrame", L["Player's target frame"])
    self.TargetFrameToT = make_checkbox("TargetFrameToT", L["Target of target frame"])
    self.party = make_checkbox("Party", L["Party member frames"])
    self.compactraid = make_checkbox("CompactRaid", L["Compact raid frames"])
    self.boss = make_checkbox("BossTarget", L["Boss target frames"])

    self.FocusFrame = make_checkbox("FocusFrame", L["Player's focus frame"])
    self.FocusFrameToT = make_checkbox("FocusFrameToT", L["Target of focus frame"])
    self.arena = make_checkbox("ArenaEnemy", L["Arena enemy frames"])

    table.insert(bits, self.intro)
    table.insert(bits, self.statusBarFix)
    table.insert(bits, self.PlayerFrame)
    table.insert(bits, self.PetFrame)
    table.insert(bits, self.TargetFrame)
    table.insert(bits, self.TargetFrameToT)

    -- No focus frames in Classic
    table.insert(bits, self.FocusFrame)
    table.insert(bits, self.FocusFrameToT)

    -- Arena comes in in retail
    table.insert(bits, self.arena)

    -- Group these together
    bits[1]:SetPoint("TOPLEFT", 5, -5)

    for i = 2, #bits, 1 do
        bits[i]:SetPoint("TOPLEFT", bits[i-1], "BOTTOMLEFT", 0, 0)
    end

    local last = bits[#bits]

    table.wipe(bits)
    table.insert(bits, self.party)
    table.insert(bits, self.compactraid)
    table.insert(bits, self.boss)

    bits[1]:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -15)

    for i = 2, #bits, 1 do
        bits[i]:SetPoint("TOPLEFT", bits[i-1], "BOTTOMLEFT", 0, 0)
    end
end

function panel.refresh()
    xpcall(function()
    if not panel.initialized then
        panel:CreateOptions()
    end

    local opt = addon.settings.blizzframes

    panel.statusBarFix:SetChecked(opt.statusBarFix)
    panel.PlayerFrame:SetChecked(opt.PlayerFrame)
    panel.PetFrame:SetChecked(opt.PetFrame)
    panel.TargetFrame:SetChecked(opt.TargetFrame)
    panel.TargetFrameToT:SetChecked(opt.TargetFrameToT)

    if not addon:ProjectIsClassic() then
        panel.FocusFrame:SetChecked(opt.FocusFrame)
        panel.FocusFrameToT:SetChecked(opt.FocusFrameToT)
    end

    if addon:ProjectIsRetail() then
        panel.arena:SetChecked(opt.arena)
    end

    panel.party:SetChecked(opt.party)
    panel.compactraid:SetChecked(opt.compactraid)
    panel.boss:SetChecked(opt.boss)
    end, geterrorhandler())
end

function panel.okay()
    xpcall(function()
    if not panel.initialized then return end

    local opt = addon.settings.blizzframes

    opt.statusBarFix = not not panel.statusBarFix:GetChecked()
    opt.PlayerFrame = not not panel.PlayerFrame:GetChecked()
    opt.PetFrame = not not panel.PetFrame:GetChecked()
    opt.TargetFrame = not not panel.TargetFrame:GetChecked()
    opt.TargetFrameToT = not not panel.TargetFrameToT:GetChecked()

    if not addon:ProjectIsClassic() then
        opt.FocusFrame = not not panel.FocusFrame:GetChecked()
        opt.FocusFrameToT = not not panel.FocusFrameToT:GetChecked()
    end

    if addon:ProjectIsRetail() then
        opt.arena = not not panel.arena:GetChecked()
    end

    opt.party = not not panel.party:GetChecked()
    opt.compactraid = not not panel.compactraid:GetChecked()
    opt.boss = not not panel.boss:GetChecked()
    end, geterrorhandler())
end

if addon.optpanels.useRedirect then
    if Settings and Settings.RegisterVerticalLayoutSubcategory then
        local category = Settings.RegisterVerticalLayoutSubcategory(addon.optpanels.ABOUT.category, L["Blizzard Frame Options"])
        Settings.RegisterInitializer(category, CreateSettingsListSectionHeaderInitializer(
            L["These options have moved into the main Clique config window."]
        ))
        Settings.RegisterInitializer(category, CreateSettingsButtonInitializer(
            L["Blizzard Frame Options"], L["Open"],
            function() addon:OpenBlizzFramesPage() end,
            nil, false
        ))
    end
else
    if Settings and Settings.RegisterCanvasLayoutSubcategory then
        local category, layout = Settings.RegisterCanvasLayoutSubcategory(addon.optpanels.ABOUT.category, addon.optpanels.BLIZZFRAMES, addon.optpanels.BLIZZFRAMES.name)
        addon.optpanels.BLIZZFRAMES.category = category
        addon.optpanels.BLIZZFRAMES.layout = layout
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel, addon.optpanels.ABOUT)
    end
end
