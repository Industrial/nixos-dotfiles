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

local cachedPetSourceDefs
local function CollectPetSourceDefs()
    if cachedPetSourceDefs then return cachedPetSourceDefs end
    local defs = {}
    local n = (C_PetJournal and C_PetJournal.GetNumPetSources
        and C_PetJournal.GetNumPetSources()) or 12
    for i = 1, n do
        defs[#defs + 1] = { sourceType = i, label = SourceLabel(i) }
    end
    cachedPetSourceDefs = defs
    return defs
end



local cachedPetTypeDefs
local function CollectPetTypeDefs()
    if cachedPetTypeDefs then return cachedPetTypeDefs end
    local defs = {}
    local n = (C_PetJournal and C_PetJournal.GetNumPetTypes
        and C_PetJournal.GetNumPetTypes()) or 10
    for i = 1, n do
        local name = _G["BATTLE_PET_NAME_" .. i]
        defs[#defs + 1] = { petType = i, label = name or ("Type " .. i) }
    end
    cachedPetTypeDefs = defs
    return defs
end

function Filters:BuildPetOptionsPopup(StylePopup, CHECK_SIZE, dropdownGuardFrames)
    local OPTIONS_WIDTH = 160
    local FLYOUT_WIDTH = 180
    local ROW_H = 22
    local PAD = 6

    local function ChainEnabled()
        local uiFilters = EasyFind.db.uiSearchFilters
        return uiFilters.collections ~= false and uiFilters.pets ~= false
    end

    local optionsPopup = CreateFrame("Frame", "EasyFindPetOptionsPopup", UIParent, "BackdropTemplate")
    optionsPopup:SetFrameStrata("TOOLTIP")
    StylePopup(optionsPopup)
    optionsPopup:EnableMouse(true)
    optionsPopup:Hide()

    local function EnsureSourceFilters()
        EasyFind.db.petSourceFilters = EasyFind.db.petSourceFilters or {}
        return EasyFind.db.petSourceFilters
    end
    local function EnsureTypeFilters()
        EasyFind.db.petTypeFilters = EasyFind.db.petTypeFilters or {}
        return EasyFind.db.petTypeFilters
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
            Filters:ApplyFilterSelection("pets")
        end)
        return row
    end

    local rows = {}
    local y = -PAD
    local filterDefs = {
        { dbKey = "petFilterCollected",    label = _G["COLLECTED"] or "Collected" },
        { dbKey = "petFilterNotCollected", label = _G["NOT_COLLECTED"] or "Not Collected" },
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
    local typesRow = CreateFlyoutRow(_G["TYPE"] or "Type", y)

    local contentW = 0
    for i = 1, #rows do
        local w = Utils.FlyoutRowContentWidth(rows[i], CHECK_SIZE + 4)
        if w > contentW then contentW = w end
    end
    local srcW = Utils.FlyoutRowContentWidth(sourcesRow, 14, nil, CHECK_SIZE)
    if srcW > contentW then contentW = srcW end
    local typW = Utils.FlyoutRowContentWidth(typesRow, 14, nil, CHECK_SIZE)
    if typW > contentW then contentW = typW end
    local popupW = Utils.FlyoutWidthFor(contentW, PAD)
    for i = 1, #rows do rows[i]:SetWidth(popupW - PAD * 2) end
    sourcesRow:SetWidth(popupW - PAD * 2)
    typesRow:SetWidth(popupW - PAD * 2)
    optionsPopup:SetSize(popupW, PAD * 2 + (#filterDefs + 2) * ROW_H)

    local sourceFlyout = Filters:BuildSourceFlyout({
        name = "EasyFindPetSourcePopup",
        stylePopup = StylePopup,
        checkSize = CHECK_SIZE,
        width = FLYOUT_WIDTH,
        frameLevel = optionsPopup:GetFrameLevel() + 20,
        getShowLevel = function() return optionsPopup:GetFrameLevel() + 10 end,
        getScale = function() return optionsPopup:GetScale() end,
        guardFrames = dropdownGuardFrames,
        sourcesRow = sourcesRow,
        collectDefs = CollectPetSourceDefs,
        defField = "sourceType",
        getFilters = EnsureSourceFilters,
        chainEnabled = ChainEnabled,
        applyKey = "pets",
    })

    local typeFlyout = Filters:BuildSourceFlyout({
        name = "EasyFindPetTypePopup",
        stylePopup = StylePopup,
        checkSize = CHECK_SIZE,
        width = FLYOUT_WIDTH,
        frameLevel = optionsPopup:GetFrameLevel() + 20,
        getShowLevel = function() return optionsPopup:GetFrameLevel() + 10 end,
        getScale = function() return optionsPopup:GetScale() end,
        guardFrames = dropdownGuardFrames,
        sourcesRow = typesRow,
        collectDefs = CollectPetTypeDefs,
        defField = "petType",
        getFilters = EnsureTypeFilters,
        chainEnabled = ChainEnabled,
        applyKey = "pets",
    })

    sourcesRow:HookScript("OnEnter", function() typeFlyout:Hide() end)
    typesRow:HookScript("OnEnter", function() sourceFlyout:Hide() end)

    local function SyncOptions()
        local chainEnabled = ChainEnabled()
        for _, row in ipairs(rows) do
            row:SetChecked(EasyFind.db[row.dbKey] ~= false)
            Utils.SetFlyoutRowEnabled(row, chainEnabled)
        end
        Utils.SetFlyoutRowEnabled(sourcesRow, chainEnabled)
        Utils.SetFlyoutRowEnabled(typesRow, chainEnabled)
    end

    optionsPopup:HookScript("OnHide", function()
        sourceFlyout:Hide()
        typeFlyout:Hide()
    end)
    return optionsPopup, SyncOptions, sourceFlyout, typeFlyout
end
