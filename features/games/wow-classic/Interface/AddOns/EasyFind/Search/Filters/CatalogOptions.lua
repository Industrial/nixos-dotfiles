local _, ns = ...

local Filters = ns.Filters
local Utils = ns.Utils
local L = ns.L

local ipairs = Utils.ipairs
local sformat = Utils.sformat
local CreateFrame = CreateFrame
local UIParent = UIParent
local GetItemClassInfo = (C_Item and C_Item.GetItemClassInfo) or GetItemClassInfo
local CreateAtlasMarkup = CreateAtlasMarkup
local C_Texture = C_Texture




local TYPE_BUCKETS = {
    { key = "armor",      class = 4,  fallback = "Armor" },
    { key = "weapon",     class = 2,  fallback = "Weapons" },
    { key = "consumable", class = 0,  fallback = "Consumable" },
    { key = "tradegoods", class = 7,  fallback = "Trade Goods" },
    { key = "recipe",     class = 9,  fallback = "Recipe" },
    { key = "gem",        class = 3,  fallback = "Gem" },
    { key = "quest",      class = 12, fallback = "Quest" },
    { key = "housing",    class = 20, fallback = "Housing" },
    { key = "glyph",      class = 16, fallback = "Glyph" },
    { key = "container",  class = 1,  fallback = "Container" },
    { key = "misc",       class = 15, fallback = "Miscellaneous" },
}

local function ClassName(classID, fallback)
    local n = GetItemClassInfo and GetItemClassInfo(classID)
    return (type(n) == "string" and n ~= "") and n or fallback
end



local function QualityLabel(tier)
    if tier == 0 then return _G["ALL"] or "All" end
    local atlas = "Professions-Icon-Quality-Tier" .. tier .. "-Small"
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        return CreateAtlasMarkup(atlas, 20, 20)
    end
    return tostring(tier)
end

function Filters:BuildCatalogOptionsPopup(StylePopup, CHECK_SIZE, dropdownGuardFrames)
    local ROW_H = 22
    local PAD = 6
    local HEADER_H = 20
    local BTN_H = 27
    local SECTION_GAP = 6

    local function ChainEnabled()
        local uiFilters = EasyFind.db.uiSearchFilters
        return uiFilters.items ~= false and uiFilters.catalog ~= false
    end

    local function EnsureTypeFilters()
        EasyFind.db.catalogTypeFilters = EasyFind.db.catalogTypeFilters or {}
        return EasyFind.db.catalogTypeFilters
    end

    local function ApplyCatalog()


        if ns.ItemSearch and ns.ItemSearch.RefreshFilters then
            ns.ItemSearch:RefreshFilters()
        end
        Filters:RerunActiveSearch()
    end

    local optionsPopup = CreateFrame("Frame", "EasyFindCatalogOptionsPopup", UIParent, "BackdropTemplate")
    optionsPopup:SetFrameStrata("TOOLTIP")
    StylePopup(optionsPopup)
    optionsPopup:EnableMouse(true)
    optionsPopup:Hide()

    local typeRows = {}



    local headers = {}
    local function AddHeader(text, y)
        local h = optionsPopup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        h:SetPoint("TOPLEFT", optionsPopup, "TOPLEFT", PAD + 8, y - 2)
        h:SetText(text)
        ns.ShadeText(h)
        headers[#headers + 1] = h
        return h
    end
    local function RestyleHeaders()
        local theme = ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
        local c
        if theme and theme.lightTheme then
            c = theme.pathColorHover or theme.leafColor
        else
            c = ns.GOLD_COLOR
        end
        if not c then return end
        for i = 1, #headers do headers[i]:SetTextColor(c[1], c[2], c[3], 1) end
    end
    optionsPopup._efOnThemeRestyle = RestyleHeaders

    local function CreateCheckRow(bucketKey, label, y)
        local row = CreateFrame("CheckButton", nil, optionsPopup)
        row:SetSize(100, ROW_H)
        row:SetPoint("TOPLEFT", optionsPopup, "TOPLEFT", PAD, y)
        Utils.SetCheckboxTextures(row, CHECK_SIZE)
        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", row:GetNormalTexture(), "RIGHT", 4, 0)
        text:SetText(label)
        row._label = text
        row._bucket = bucketKey
        Utils.InstallMenuRowHighlight(row)
        row:SetScript("OnClick", function(self)
            EnsureTypeFilters()[bucketKey] = self:GetChecked() and true or false
            ApplyCatalog()
        end)
        return row
    end



    local y = -PAD



    local toggleAllRow = CreateFrame("Button", nil, optionsPopup)
    toggleAllRow:SetSize(100, ROW_H)
    toggleAllRow:SetPoint("TOPLEFT", optionsPopup, "TOPLEFT", PAD, y)
    local toggleAllLabel = toggleAllRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    toggleAllLabel:SetPoint("LEFT", 8, 0)
    toggleAllLabel:SetText(L["FILTER_TOGGLE_ALL"])
    toggleAllRow._label = toggleAllLabel
    Utils.InstallMenuRowHighlight(toggleAllRow)
    toggleAllRow:SetScript("OnClick", function()
        local tf = EnsureTypeFilters()
        local allOn = true
        for _, b in ipairs(TYPE_BUCKETS) do
            if tf[b.key] == false then allOn = false; break end
        end
        for _, b in ipairs(TYPE_BUCKETS) do tf[b.key] = not allOn end
        for i = 1, #typeRows do typeRows[i]:SetChecked(tf[typeRows[i]._bucket] ~= false) end
        ApplyCatalog()
    end)
    y = y - ROW_H

    AddHeader(_G["TYPE"] or "Type", y)
    y = y - HEADER_H

    for _, bucket in ipairs(TYPE_BUCKETS) do
        typeRows[#typeRows + 1] = CreateCheckRow(bucket.key, ClassName(bucket.class, bucket.fallback), y)
        y = y - ROW_H
    end

    y = y - SECTION_GAP
    AddHeader(L["FILTER_ITEM_QUALITY"], y)
    y = y - HEADER_H



    local QUALITY_FMT = L["FILTER_QUALITY_FORMAT"]
    local qualityDrop = Filters:BuildSelectDropdown({
        parent = optionsPopup,
        name = "EasyFindCatalogQualityPopup",
        width = 140,
        options = {
            { value = 0, label = _G["ALL"] or "All" },
            { value = 1, label = QualityLabel(1) },
            { value = 2, label = QualityLabel(2) },
            { value = 3, label = QualityLabel(3) },
        },
        getValue = function() return EasyFind.db.catalogQualityTier or 0 end,
        setValue = function(v) EasyFind.db.catalogQualityTier = v end,
        formatLabel = function(_, optLabel) return sformat(QUALITY_FMT, optLabel or (_G["ALL"] or "All")) end,
        onChange = ApplyCatalog,
        stylePopup = StylePopup,
        guardFrames = dropdownGuardFrames,
    })
    local qualityBtn = qualityDrop.button
    qualityBtn:ClearAllPoints()
    qualityBtn:SetPoint("TOPLEFT", optionsPopup, "TOPLEFT", PAD, y)
    y = y - BTN_H

    local hideTipRow = CreateFrame("CheckButton", nil, optionsPopup)
    hideTipRow:SetSize(100, ROW_H)
    hideTipRow:SetPoint("TOPLEFT", optionsPopup, "TOPLEFT", PAD, y)
    Utils.SetCheckboxTextures(hideTipRow, CHECK_SIZE)
    local hideTipLabel = hideTipRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    hideTipLabel:SetPoint("LEFT", hideTipRow:GetNormalTexture(), "RIGHT", 4, 0)
    hideTipLabel:SetText(ns.L["FILTER_HIDE_TOOLTIPS"])
    hideTipRow._label = hideTipLabel
    Utils.InstallMenuRowHighlight(hideTipRow)
    hideTipRow:SetScript("OnClick", function(self)
        EasyFind.db.hideTooltips = EasyFind.db.hideTooltips or {}
        EasyFind.db.hideTooltips.items = self:GetChecked() and true or false
    end)
    y = y - ROW_H



    local contentW = 0
    for i = 1, #typeRows do
        local w = Utils.FlyoutRowContentWidth(typeRows[i], CHECK_SIZE + 4)
        if w > contentW then contentW = w end
    end
    local tW = Utils.FlyoutRowContentWidth(toggleAllRow, 8)
    if tW > contentW then contentW = tW end
    local hW = Utils.FlyoutRowContentWidth(hideTipRow, CHECK_SIZE + 4)
    if hW > contentW then contentW = hW end
    for i = 1, #headers do
        local hw = 8 + headers[i]:GetStringWidth()
        if hw > contentW then contentW = hw end
    end
    qualityDrop.setLabel(sformat(QUALITY_FMT, QualityLabel(3)))
    local qBtnW = 14 + qualityBtn._label:GetStringWidth() + 2 + 22 + 10
    if qBtnW > contentW then contentW = qBtnW end
    qualityDrop.Refresh()

    local popupW = Utils.FlyoutWidthFor(contentW, PAD)
    for i = 1, #typeRows do typeRows[i]:SetWidth(popupW - PAD * 2) end
    toggleAllRow:SetWidth(popupW - PAD * 2)
    qualityBtn:SetWidth(popupW - PAD * 2)
    hideTipRow:SetWidth(popupW - PAD * 2)
    optionsPopup:SetSize(popupW, -y + PAD)

    RestyleHeaders()

    local function SyncOptions()
        local chainEnabled = ChainEnabled()
        RestyleHeaders()
        qualityDrop.Refresh()
        Utils.SetFlyoutRowEnabled(qualityBtn, chainEnabled)
        Utils.SetFlyoutRowEnabled(toggleAllRow, chainEnabled)
        local ht = EasyFind.db.hideTooltips
        hideTipRow:SetChecked(ht and ht.items or false)
        Utils.SetFlyoutRowEnabled(hideTipRow, chainEnabled)
        local tf = EasyFind.db.catalogTypeFilters or {}
        for i = 1, #typeRows do
            typeRows[i]:SetChecked(tf[typeRows[i]._bucket] ~= false)
            Utils.SetFlyoutRowEnabled(typeRows[i], chainEnabled)
        end
    end

    optionsPopup:HookScript("OnHide", function() qualityDrop.popup:Hide() end)
    return optionsPopup, SyncOptions, qualityDrop.popup
end
