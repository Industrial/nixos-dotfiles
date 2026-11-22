local _, ns = ...

local Filters = ns.Filters
local Utils = ns.Utils

local ipairs = Utils.ipairs
local select = Utils.select
local tsort = Utils.tsort
local SetFlyoutRowEnabled = Utils.SetFlyoutRowEnabled
local CreateFrame = CreateFrame
local UIParent = UIParent

local HEIRLOOM_SOURCE_FALLBACK_LABELS = {
    [1] = "Drop",
    [2] = "Quest",
    [3] = "Vendor",
    [4] = "World Event",
}

local function HeirloomSourceLabel(sourceType)
    return _G["HEIRLOOM_SOURCE_" .. tostring(sourceType)]
        or _G["BATTLE_PET_SOURCE_" .. tostring(sourceType)]
        or HEIRLOOM_SOURCE_FALLBACK_LABELS[sourceType]
        or ("Source " .. tostring(sourceType))
end

local function SortHeirloomSourceDefs(a, b)
    if a.sourceType ~= b.sourceType then return a.sourceType < b.sourceType end
    return a.label < b.label
end

local cachedHeirloomSourceDefs
local function CollectHeirloomSourceDefs()
    if cachedHeirloomSourceDefs then return cachedHeirloomSourceDefs end
    local seen, defs = {}, {}
    if C_Heirloom and C_Heirloom.GetHeirloomItemIDs and C_Heirloom.GetHeirloomInfo then
        local ids = C_Heirloom.GetHeirloomItemIDs()
        if type(ids) == "table" then
            for i = 1, #ids do
                local sourceType = select(6, C_Heirloom.GetHeirloomInfo(ids[i]))
                if sourceType and sourceType > 0 and not seen[sourceType] then
                    seen[sourceType] = true
                    defs[#defs + 1] = { sourceType = sourceType, label = HeirloomSourceLabel(sourceType) }
                end
            end
        end
    end
    tsort(defs, SortHeirloomSourceDefs)


    if #defs > 0 then cachedHeirloomSourceDefs = defs end
    return defs
end

function Filters:BuildHeirloomOptionsPopup(StylePopup, CHECK_SIZE, dropdownGuardFrames)
    local OPTIONS_WIDTH = 160
    local SOURCE_WIDTH = 170
    local ROW_H = 22
    local PAD = 6

    local function InstallMenuRowHighlight(row)
        Utils.InstallMenuRowHighlight(row)
    end

    local function ChainEnabled()
        local uiFilters = EasyFind.db.uiSearchFilters
        return uiFilters.collections ~= false and uiFilters.heirlooms ~= false
    end

    local optionsPopup = CreateFrame("Frame", "EasyFindHeirloomOptionsPopup", UIParent, "BackdropTemplate")
    optionsPopup:SetFrameStrata("TOOLTIP")
    StylePopup(optionsPopup)
    optionsPopup:EnableMouse(true)
    optionsPopup:Hide()



    local CLASS_BTN_H = 27
    local CLASS_GAP = 4
    local classSel = Filters:BuildClassSpecSelector({
        parent = optionsPopup,
        x = PAD, y = -PAD,
        width = ns.CLASS_SELECTOR_BTN_W,
        hasSpec = true,
        stylePopup = StylePopup,
        guardFrames = dropdownGuardFrames,
        getScale = function() return EasyFind.db.uiSearchScale or 1.0 end,
        getFilter = function() return EasyFind.db.heirloomFilter end,
        setFilter = function(v) EasyFind.db.heirloomFilter = v end,
        onChange = function() Filters:ApplyFilterSelection("heirlooms") end,
    })

    local function EnsureSourceFilters()
        EasyFind.db.heirloomSourceFilters = EasyFind.db.heirloomSourceFilters or {}
        return EasyFind.db.heirloomSourceFilters
    end

    local function CreateCheckRow(def, y)
        local row = CreateFrame("CheckButton", nil, optionsPopup)
        row:SetSize(OPTIONS_WIDTH - PAD * 2, ROW_H)
        row:SetPoint("TOPLEFT", optionsPopup, "TOPLEFT", PAD, y)
        Utils.SetCheckboxTextures(row, CHECK_SIZE)
        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", row:GetNormalTexture(), "RIGHT", 4, 0)
        text:SetText(def.label)
        row._label = text
        InstallMenuRowHighlight(row)
        row.dbKey = def.dbKey
        row:SetScript("OnClick", function(self)
            EasyFind.db[self.dbKey] = self:GetChecked() and true or false
            Filters:ApplyFilterSelection("heirlooms")
        end)
        return row
    end

    local rows = {}
    local y = -PAD - CLASS_BTN_H - CLASS_GAP
    local filterDefs = {
        { dbKey = "heirloomFilterCollected",    label = _G["COLLECTED"] or "Collected" },
        { dbKey = "heirloomFilterNotCollected", label = _G["NOT_COLLECTED"] or "Not Collected" },
    }
    for _, def in ipairs(filterDefs) do
        rows[#rows + 1] = CreateCheckRow(def, y)
        y = y - ROW_H
    end

    local sourcesRow = CreateFrame("Button", nil, optionsPopup)
    sourcesRow:SetSize(OPTIONS_WIDTH - PAD * 2, ROW_H)
    sourcesRow:SetPoint("TOPLEFT", optionsPopup, "TOPLEFT", PAD, y)
    local sourcesText = sourcesRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sourcesText:SetPoint("LEFT", 14, 0)
    sourcesText:SetText(_G["SOURCES"] or "Sources")
    local sourceChev = sourcesRow:CreateTexture(nil, "OVERLAY")
    Utils.SetChevronTexture(sourceChev)
    sourceChev:SetSize(CHECK_SIZE, CHECK_SIZE)
    sourceChev:SetPoint("RIGHT", -4, 0)
    sourcesRow._label = sourcesText
    sourcesRow._chev = sourceChev
    InstallMenuRowHighlight(sourcesRow)

    local contentW = 0
    for i = 1, #rows do
        local w = Utils.FlyoutRowContentWidth(rows[i], CHECK_SIZE + 4)
        if w > contentW then contentW = w end
    end
    local srcW = Utils.FlyoutRowContentWidth(sourcesRow, 14, nil, CHECK_SIZE)
    if srcW > contentW then contentW = srcW end

    if ns.CLASS_SELECTOR_BTN_W > contentW then contentW = ns.CLASS_SELECTOR_BTN_W end
    local popupW = Utils.FlyoutWidthFor(contentW, PAD)
    for i = 1, #rows do rows[i]:SetWidth(popupW - PAD * 2) end
    sourcesRow:SetWidth(popupW - PAD * 2)
    optionsPopup:SetSize(popupW, PAD * 2 + CLASS_BTN_H + CLASS_GAP + #filterDefs * ROW_H + ROW_H)

    local sourceFlyout, LayoutSourceFlyout = Filters:BuildSourceFlyout({
        name = "EasyFindHeirloomSourcePopup",
        stylePopup = StylePopup,
        checkSize = CHECK_SIZE,
        width = SOURCE_WIDTH,
        frameLevel = optionsPopup:GetFrameLevel() + 20,
        getShowLevel = function() return optionsPopup:GetFrameLevel() + 10 end,
        getScale = function() return optionsPopup:GetScale() end,
        sourcesRow = sourcesRow,
        collectDefs = CollectHeirloomSourceDefs,
        defField = "sourceType",
        getFilters = EnsureSourceFilters,
        chainEnabled = ChainEnabled,
        applyKey = "heirlooms",
    })

    local function SyncOptions()
        local chainEnabled = ChainEnabled()
        if classSel then
            classSel.Refresh()
            SetFlyoutRowEnabled(classSel.button, chainEnabled)
        end
        for _, row in ipairs(rows) do
            row:SetChecked(EasyFind.db[row.dbKey] ~= false)
            SetFlyoutRowEnabled(row, chainEnabled)
        end
        SetFlyoutRowEnabled(sourcesRow, chainEnabled)
        LayoutSourceFlyout()
    end

    optionsPopup:HookScript("OnHide", function()
        sourceFlyout:Hide()
        if classSel.popup then classSel.popup:Hide() end
    end)
    return optionsPopup, SyncOptions, sourceFlyout
end
