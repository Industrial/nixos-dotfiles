local _, ns = ...

local Filters = ns.Filters
local Utils = ns.Utils

local ipairs = Utils.ipairs
local CreateFrame = CreateFrame
local UIParent = UIParent



local function SourceLabel(sourceType)
    return _G["BATTLE_PET_SOURCE_" .. tostring(sourceType)]
        or ("Source " .. tostring(sourceType))
end

local cachedToySourceDefs
local function CollectToySourceDefs()
    if cachedToySourceDefs then return cachedToySourceDefs end
    local defs = {}
    for i = 1, 12 do
        defs[#defs + 1] = { sourceType = i, label = SourceLabel(i) }
    end
    cachedToySourceDefs = defs
    return defs
end

local cachedToyExpansionDefs
local function CollectToyExpansionDefs()
    if cachedToyExpansionDefs then return cachedToyExpansionDefs end
    local defs = {}



    local maxExp = (GetNumExpansions and GetNumExpansions()) or 11
    for i = 0, maxExp do
        local name = _G["EXPANSION_NAME" .. i]
        if type(name) == "string" and name ~= "" then
            defs[#defs + 1] = { expansion = i, label = name }
        end
    end
    cachedToyExpansionDefs = defs
    return defs
end

function Filters:BuildToyOptionsPopup(StylePopup, CHECK_SIZE, dropdownGuardFrames)
    local OPTIONS_WIDTH = 160
    local FLYOUT_WIDTH = 180
    local ROW_H = 22
    local PAD = 6

    local function ChainEnabled()
        local uiFilters = EasyFind.db.uiSearchFilters
        return uiFilters.collections ~= false and uiFilters.toys ~= false
    end

    local optionsPopup = CreateFrame("Frame", "EasyFindToyOptionsPopup", UIParent, "BackdropTemplate")
    optionsPopup:SetFrameStrata("TOOLTIP")
    StylePopup(optionsPopup)
    optionsPopup:EnableMouse(true)
    optionsPopup:Hide()

    local function EnsureSourceFilters()
        EasyFind.db.toySourceFilters = EasyFind.db.toySourceFilters or {}
        return EasyFind.db.toySourceFilters
    end
    local function EnsureExpansionFilters()
        EasyFind.db.toyExpansionFilters = EasyFind.db.toyExpansionFilters or {}
        return EasyFind.db.toyExpansionFilters
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
        Utils.InstallMenuRowHighlight(row)
        row.dbKey = def.dbKey
        row:SetScript("OnClick", function(self)
            EasyFind.db[self.dbKey] = self:GetChecked() and true or false
            Filters:ApplyFilterSelection("toys")
        end)
        return row
    end

    local rows = {}
    local y = -PAD


    local filterDefs = {
        { dbKey = "toyFilterCollected",    label = _G["COLLECTED"] or "Collected" },
        { dbKey = "toyFilterNotCollected", label = _G["NOT_COLLECTED"] or "Not Collected" },
        { dbKey = "toyFilterUnusable",     label = _G["MOUNT_JOURNAL_FILTER_UNUSABLE"] or "Unusable" },
    }
    for _, def in ipairs(filterDefs) do
        rows[#rows + 1] = CreateCheckRow(def, y)
        y = y - ROW_H
    end

    local function CreateFlyoutRow(labelText, y2)
        local row = CreateFrame("Button", nil, optionsPopup)
        row:SetSize(OPTIONS_WIDTH - PAD * 2, ROW_H)
        row:SetPoint("TOPLEFT", optionsPopup, "TOPLEFT", PAD, y2)
        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", 14, 0)
        text:SetText(labelText)
        local chev = row:CreateTexture(nil, "OVERLAY")
        Utils.SetChevronTexture(chev)
        chev:SetSize(CHECK_SIZE, CHECK_SIZE)
        chev:SetPoint("RIGHT", -4, 0)
        row._label = text
        row._chev = chev
        Utils.InstallMenuRowHighlight(row)
        return row
    end

    local sourcesRow = CreateFlyoutRow(_G["SOURCES"] or "Sources", y)
    y = y - ROW_H
    local expansionsRow = CreateFlyoutRow(_G["EXPANSION_FILTER_TEXT"] or "Expansion", y)

    local contentW = 0
    for i = 1, #rows do
        local w = Utils.FlyoutRowContentWidth(rows[i], CHECK_SIZE + 4)
        if w > contentW then contentW = w end
    end
    local srcW = Utils.FlyoutRowContentWidth(sourcesRow, 14, nil, CHECK_SIZE)
    if srcW > contentW then contentW = srcW end
    local expW = Utils.FlyoutRowContentWidth(expansionsRow, 14, nil, CHECK_SIZE)
    if expW > contentW then contentW = expW end
    local popupW = Utils.FlyoutWidthFor(contentW, PAD)
    for i = 1, #rows do rows[i]:SetWidth(popupW - PAD * 2) end
    sourcesRow:SetWidth(popupW - PAD * 2)
    expansionsRow:SetWidth(popupW - PAD * 2)
    optionsPopup:SetSize(popupW, PAD * 2 + (#filterDefs + 2) * ROW_H)

    local sourceFlyout = Filters:BuildSourceFlyout({
        name = "EasyFindToySourcePopup",
        stylePopup = StylePopup,
        checkSize = CHECK_SIZE,
        width = FLYOUT_WIDTH,
        frameLevel = optionsPopup:GetFrameLevel() + 2 * Utils.MENU_LEVEL_STEP,
        getShowLevel = function() return optionsPopup:GetFrameLevel() + Utils.MENU_LEVEL_STEP end,
        getScale = function() return optionsPopup:GetScale() end,
        guardFrames = dropdownGuardFrames,
        sourcesRow = sourcesRow,
        collectDefs = CollectToySourceDefs,
        defField = "sourceType",
        getFilters = EnsureSourceFilters,
        chainEnabled = ChainEnabled,
        applyKey = "toys",
    })

    local expansionFlyout = Filters:BuildSourceFlyout({
        name = "EasyFindToyExpansionPopup",
        stylePopup = StylePopup,
        checkSize = CHECK_SIZE,
        width = FLYOUT_WIDTH,
        frameLevel = optionsPopup:GetFrameLevel() + 2 * Utils.MENU_LEVEL_STEP,
        getShowLevel = function() return optionsPopup:GetFrameLevel() + Utils.MENU_LEVEL_STEP end,
        getScale = function() return optionsPopup:GetScale() end,
        guardFrames = dropdownGuardFrames,
        sourcesRow = expansionsRow,
        collectDefs = CollectToyExpansionDefs,
        defField = "expansion",
        getFilters = EnsureExpansionFilters,
        chainEnabled = ChainEnabled,
        applyKey = "toys",
    })



    sourcesRow:HookScript("OnEnter", function() expansionFlyout:Hide() end)
    expansionsRow:HookScript("OnEnter", function() sourceFlyout:Hide() end)

    local function SyncOptions()
        local chainEnabled = ChainEnabled()
        for _, row in ipairs(rows) do
            row:SetChecked(EasyFind.db[row.dbKey] ~= false)
            Utils.SetFlyoutRowEnabled(row, chainEnabled)
        end
        Utils.SetFlyoutRowEnabled(sourcesRow, chainEnabled)
        Utils.SetFlyoutRowEnabled(expansionsRow, chainEnabled)
    end

    optionsPopup:HookScript("OnHide", function()
        sourceFlyout:Hide()
        expansionFlyout:Hide()
    end)
    return optionsPopup, SyncOptions, sourceFlyout, expansionFlyout
end
