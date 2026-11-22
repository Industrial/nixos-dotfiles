local _, ns = ...

local Filters = ns.Filters
local Utils = ns.Utils

local ipairs = Utils.ipairs
local select = Utils.select
local tsort = Utils.tsort
local SetFlyoutRowEnabled = Utils.SetFlyoutRowEnabled
local CreateFrame = CreateFrame
local UIParent = UIParent

local MOUNT_SOURCE_FALLBACK_LABELS = {
    [1] = "Drop",
    [2] = "Quest",
    [3] = "Vendor",
    [4] = "Profession",
    [5] = "Achievement",
    [6] = "World Event",
    [7] = "Promotion",
    [8] = "Trading Post",
    [9] = "Discovery",
}

local function MountSourceLabel(sourceType)
    return _G["MOUNT_JOURNAL_FILTER_SOURCE_" .. tostring(sourceType)]
        or _G["MOUNT_JOURNAL_FILTER_" .. tostring(sourceType)]
        or _G["BATTLE_PET_SOURCE_" .. tostring(sourceType)]
        or MOUNT_SOURCE_FALLBACK_LABELS[sourceType]
        or ("Source " .. tostring(sourceType))
end

local function SortMountSourceDefs(a, b)
    if a.sourceType ~= b.sourceType then return a.sourceType < b.sourceType end
    return a.label < b.label
end

local cachedMountSourceDefs
local function CollectMountSourceDefs()
    if cachedMountSourceDefs then return cachedMountSourceDefs end
    local seen = {}
    local defs = {}
    if C_MountJournal and C_MountJournal.GetMountIDs and C_MountJournal.GetMountInfoByID then
        local mountIDs = C_MountJournal.GetMountIDs()
        if mountIDs then
            for i = 1, #mountIDs do
                local sourceType = select(6, C_MountJournal.GetMountInfoByID(mountIDs[i]))
                if sourceType and sourceType > 0 and not seen[sourceType] then
                    seen[sourceType] = true
                    defs[#defs + 1] = { sourceType = sourceType, label = MountSourceLabel(sourceType) }
                end
            end
        end
    end
    tsort(defs, SortMountSourceDefs)
    cachedMountSourceDefs = defs
    return defs
end

local mountSourceInvalidator
local function EnsureMountSourceInvalidator()
    if mountSourceInvalidator then return end
    mountSourceInvalidator = CreateFrame("Frame")
    mountSourceInvalidator:RegisterEvent("NEW_MOUNT_ADDED")
    mountSourceInvalidator:SetScript("OnEvent", function()
        cachedMountSourceDefs = nil
    end)
end

function Filters:BuildMountOptionsPopup(StylePopup, CHECK_SIZE)
    local OPTIONS_WIDTH = 160
    local SOURCE_WIDTH = 170
    local ROW_H = 22
    local PAD = 6
    local HEADER_H = 20

    local function InstallMenuRowHighlight(row)
        Utils.InstallMenuRowHighlight(row)
    end

    local function ChainEnabled()
        local uiFilters = EasyFind.db.uiSearchFilters
        return uiFilters.collections ~= false and uiFilters.mounts ~= false
    end

    EnsureMountSourceInvalidator()

    local optionsPopup = CreateFrame("Frame", "EasyFindMountOptionsPopup", UIParent, "BackdropTemplate")
    optionsPopup:SetFrameStrata("TOOLTIP")
    StylePopup(optionsPopup)
    optionsPopup:EnableMouse(true)
    optionsPopup:Hide()

    local function EnsureSourceFilters()
        EasyFind.db.mountSourceFilters = EasyFind.db.mountSourceFilters or {}
        return EasyFind.db.mountSourceFilters
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
            Filters:ApplyFilterSelection("mounts")
        end)
        return row
    end

    local rows = {}
    local y = -PAD
    local filterDefs = {
        { dbKey = "mountFilterCollected",    label = _G["COLLECTED"] or "Collected" },
        { dbKey = "mountFilterNotCollected", label = _G["NOT_COLLECTED"] or "Not Collected" },
        { dbKey = "mountFilterUnusable",     label = _G["MOUNT_JOURNAL_FILTER_UNUSABLE"] or "Unusable" },
    }
    for _, def in ipairs(filterDefs) do
        rows[#rows + 1] = CreateCheckRow(def, y)
        y = y - ROW_H
    end

    local typeHeader = optionsPopup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    typeHeader:SetPoint("TOPLEFT", optionsPopup, "TOPLEFT", PAD + 8, y - 2)
    typeHeader:SetText(_G["TYPE"] or "Type")
    ns.ShadeText(typeHeader)


    optionsPopup._efOnThemeRestyle = function()
        local theme = ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
        if theme and theme.lightTheme then
            local c = theme.pathColorHover or theme.leafColor
            typeHeader:SetTextColor(c[1], c[2], c[3], 1)
        else
            typeHeader:SetTextColor(ns.GOLD_COLOR[1], ns.GOLD_COLOR[2], ns.GOLD_COLOR[3], 1)
        end
    end
    optionsPopup._efOnThemeRestyle()
    y = y - HEADER_H

    local typeDefs = {
        { dbKey = "mountTypeGround",    label = _G["MOUNT_JOURNAL_FILTER_GROUND"] or "Ground" },
        { dbKey = "mountTypeFlying",    label = _G["MOUNT_JOURNAL_FILTER_FLYING"] or "Flying" },
        { dbKey = "mountTypeAquatic",   label = _G["MOUNT_JOURNAL_FILTER_AQUATIC"] or "Aquatic" },
        { dbKey = "mountTypeRideAlong", label = _G["MOUNT_JOURNAL_FILTER_RIDEALONG"] or "Ride Along" },
    }
    for _, def in ipairs(typeDefs) do
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
    local headerW = 8 + typeHeader:GetStringWidth()
    if headerW > contentW then contentW = headerW end
    local srcW = Utils.FlyoutRowContentWidth(sourcesRow, 14, nil, CHECK_SIZE)
    if srcW > contentW then contentW = srcW end
    local popupW = Utils.FlyoutWidthFor(contentW, PAD)
    for i = 1, #rows do rows[i]:SetWidth(popupW - PAD * 2) end
    sourcesRow:SetWidth(popupW - PAD * 2)
    optionsPopup:SetSize(popupW, PAD * 2 + #filterDefs * ROW_H + HEADER_H + #typeDefs * ROW_H + ROW_H)

    local sourceFlyout, LayoutSourceFlyout = Filters:BuildSourceFlyout({
        name = "EasyFindMountSourcePopup",
        stylePopup = StylePopup,
        checkSize = CHECK_SIZE,
        width = SOURCE_WIDTH,
        frameLevel = optionsPopup:GetFrameLevel() + 2 * Utils.MENU_LEVEL_STEP,
        getShowLevel = function() return optionsPopup:GetFrameLevel() + Utils.MENU_LEVEL_STEP end,
        getScale = function() return optionsPopup:GetScale() end,
        sourcesRow = sourcesRow,
        collectDefs = CollectMountSourceDefs,
        defField = "sourceType",
        getFilters = EnsureSourceFilters,
        chainEnabled = ChainEnabled,
        applyKey = "mounts",
    })

    local function SyncOptions()
        local chainEnabled = ChainEnabled()
        for _, row in ipairs(rows) do
            row:SetChecked(EasyFind.db[row.dbKey] ~= false)
            SetFlyoutRowEnabled(row, chainEnabled)
        end
        SetFlyoutRowEnabled(sourcesRow, chainEnabled)
        LayoutSourceFlyout()
    end

    optionsPopup:HookScript("OnHide", function() sourceFlyout:Hide() end)
    return optionsPopup, SyncOptions, sourceFlyout
end
