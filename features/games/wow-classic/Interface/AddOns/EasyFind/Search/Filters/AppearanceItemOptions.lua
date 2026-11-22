local _, ns = ...

local Search = ns.Search
local Filters = ns.Filters
local Utils = ns.Utils

local ipairs = Utils.ipairs
local pairs = Utils.pairs
local tsort = Utils.tsort
local SetFlyoutRowEnabled = Utils.SetFlyoutRowEnabled
local CreateFrame = CreateFrame
local UIParent = UIParent



local SLOT_FALLBACK = {
    [1] = _G["INVTYPE_HEAD"] or "Head",
    [2] = _G["INVTYPE_SHOULDER"] or "Shoulder",
    [3] = _G["INVTYPE_CLOAK"] or "Back",
    [4] = _G["INVTYPE_CHEST"] or "Chest",
    [5] = _G["INVTYPE_BODY"] or "Shirt",
    [6] = _G["INVTYPE_TABARD"] or "Tabard",
    [7] = _G["INVTYPE_WRIST"] or "Wrist",
    [8] = _G["INVTYPE_HAND"] or "Hands",
    [9] = _G["INVTYPE_WAIST"] or "Waist",
    [10] = _G["INVTYPE_LEGS"] or "Legs",
    [11] = _G["INVTYPE_FEET"] or "Feet",
}

local slotDefs
local function GetSlotDefs()
    if slotDefs then return slotDefs end
    slotDefs = {}
    local getInfo = C_TransmogCollection and C_TransmogCollection.GetCategoryInfo
    local types = Enum.TransmogCollectionType
    if not types then return slotDefs end
    for _, catID in pairs(types) do
        if type(catID) == "number" and catID > 0 then
            local name
            if getInfo then
                local ok, n = pcall(getInfo, catID)
                if ok and type(n) == "string" and n ~= "" then name = n end
            end
            name = name or SLOT_FALLBACK[catID]
            if name then
                slotDefs[#slotDefs + 1] = { slot = catID, label = name }
            end
        end
    end
    tsort(slotDefs, function(a, b) return a.slot < b.slot end)
    return slotDefs
end

local function CurrentSlot()
    local s = EasyFind.db.appearanceItemSlot
    if s then return s end
    return (Enum.TransmogCollectionType and Enum.TransmogCollectionType.Head) or 1
end

local function SlotLabel(slot)
    for _, def in ipairs(GetSlotDefs()) do
        if def.slot == slot then return def.label end
    end
    return SLOT_FALLBACK[slot] or tostring(slot)
end



local SOURCE_FALLBACK = {
    [1] = "Boss Drop", [2] = "Quest", [3] = "Vendor", [4] = "World Drop",
    [5] = "Achievement", [6] = "Profession", [7] = "Not Available",
    [8] = "Trading Post",
}
local sourceDefs
local function GetSourceDefs()
    if sourceDefs then return sourceDefs end
    sourceDefs = {}
    for i = 1, 12 do
        local name = _G["TRANSMOG_SOURCE_" .. i] or SOURCE_FALLBACK[i]
        if name then sourceDefs[#sourceDefs + 1] = { source = i, label = name } end
    end
    return sourceDefs
end

local function MakeCheckRow(parent, width, rowH, checkSize)
    local row = CreateFrame("CheckButton", nil, parent)
    row:SetSize(width, rowH)
    Utils.SetCheckboxTextures(row, checkSize)
    row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.text:SetPoint("LEFT", row:GetNormalTexture(), "RIGHT", 4, 0)
    row._label = row.text
    Utils.InstallMenuRowHighlight(row)
    return row
end




local CAT_TO_INV_SLOT = ns.Database.CATEGORY_SLOT
local INV_SLOT_TO_CAT = {}
for cat, inv in pairs(CAT_TO_INV_SLOT) do INV_SLOT_TO_CAT[inv] = cat end



local function OnWardrobeSlotClicked(button)
    if EasyFind._appItemSlotSuppress then return end
    local loc = button.transmogLocation
    if type(loc) ~= "table" then return end
    local cat = INV_SLOT_TO_CAT[loc.slotID]
    local db = EasyFind.db
    if not cat or not db or db.appearanceItemSlot == cat then return end
    db.appearanceItemSlot = cat
    if Filters._updateAppItemSlotLabel then Filters._updateAppItemSlotLabel() end
    if ns.Database and ns.Database.RefreshDynamicCategory then
        ns.Database:RefreshDynamicCategory("appearanceItems")
    end
    local frame = Search.GetSearchFrame and Search:GetSearchFrame()
    local editBox = frame and frame.editBox
    if editBox and frame:IsShown() then
        Search:OnSearchTextChanged(Search:GetTypedQuery(), true)
    end
end

local function InstallSlotButtonHooks()
    local wcf = _G["WardrobeCollectionFrame"]
    local sf = wcf and wcf.ItemsCollectionFrame and wcf.ItemsCollectionFrame.SlotsFrame
    if not sf then return end
    for _, child in ipairs({ sf:GetChildren() }) do
        if child.IsObjectType and child:IsObjectType("Button")
           and type(child.transmogLocation) == "table" and not child._efSlotHooked then
            child._efSlotHooked = true
            child:HookScript("OnClick", OnWardrobeSlotClicked)
        end
    end
end




function Filters:EnsureWardrobeItemSlotHooks()
    local wcf = _G["WardrobeCollectionFrame"]
    local icf = wcf and wcf.ItemsCollectionFrame
    if not icf then return end
    if not icf._efSlotShowHooked then
        icf._efSlotShowHooked = true
        icf:HookScript("OnShow", InstallSlotButtonHooks)
    end
    InstallSlotButtonHooks()
end




function Filters:SyncWardrobeItemSlot(catID)
    if type(catID) ~= "number" then return end
    local targetSlot = CAT_TO_INV_SLOT[catID]
    if not targetSlot then return end
    local wcf = _G["WardrobeCollectionFrame"]
    local icf = wcf and wcf.ItemsCollectionFrame
    local sf = icf and icf.SlotsFrame
    if not sf then return end
    Filters:EnsureWardrobeItemSlotHooks()


    for _, child in ipairs({ sf:GetChildren() }) do
        if child.IsObjectType and child:IsObjectType("Button") then
            local loc = child.transmogLocation
            if type(loc) == "table" and loc.slotID == targetSlot
               and (loc.modification == 0 or loc.modification == nil) then
                EasyFind._appItemSlotSuppress = true
                child:Click()
                EasyFind._appItemSlotSuppress = false
                return
            end
        end
    end
end




function Filters:BuildAppearanceItemOptionsPopup(StylePopup, CHECK_SIZE, dropdownGuardFrames, branchPopups)
    local WIDTH = 168
    local ROW_H = 22
    local PAD = 6
    local CLASS_BTN_H = 27


    branchPopups = branchPopups or {}

    local function ChainEnabled()
        local uiFilters = EasyFind.db.uiSearchFilters
        return uiFilters.collections ~= false and uiFilters.appearances ~= false
            and uiFilters.appearanceItems ~= false
    end

    local optionsPopup = CreateFrame("Frame", "EasyFindAppItemOptionsPopup", UIParent, "BackdropTemplate")
    optionsPopup:SetFrameStrata("TOOLTIP")
    StylePopup(optionsPopup)
    optionsPopup:EnableMouse(true)
    optionsPopup:Hide()



    local slotPopup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    slotPopup:SetFrameStrata("TOOLTIP")
    slotPopup:SetFrameLevel(optionsPopup:GetFrameLevel() + 20)
    StylePopup(slotPopup)
    slotPopup:EnableMouse(true)
    slotPopup:Hide()
    local slotRows = {}
    local setSlotLabel
    local function UpdateSlotLabel() if setSlotLabel then setSlotLabel(SlotLabel(CurrentSlot())) end end

    Filters._updateAppItemSlotLabel = UpdateSlotLabel
    local function LayoutSlotPopup()
        local defs = GetSlotDefs()
        local chainEnabled = ChainEnabled()
        local py = -PAD
        for i, def in ipairs(defs) do
            local row = slotRows[i]
            if not row then
                row = CreateFrame("Button", nil, slotPopup)
                row:SetSize(WIDTH - PAD * 2, ROW_H)
                row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                row.text:SetPoint("LEFT", 12, 0)
                row._label = row.text
                Utils.InstallMenuRowHighlight(row)
                row:SetScript("OnClick", function(self)
                    EasyFind.db.appearanceItemSlot = self._slot
                    UpdateSlotLabel()
                    slotPopup:Hide()
                    Filters:SyncWardrobeItemSlot(self._slot)
                    Filters:ApplyFilterSelection("appearanceItems")
                end)
                slotRows[i] = row
            end
            row._slot = def.slot
            row.text:SetText(def.label)
            SetFlyoutRowEnabled(row, chainEnabled)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", slotPopup, "TOPLEFT", PAD, py)
            row:Show()
            py = py - ROW_H
        end
        for i = #defs + 1, #slotRows do slotRows[i]:Hide() end
        local contentW = 0
        for i = 1, #defs do
            local w = Utils.FlyoutRowContentWidth(slotRows[i], 12)
            if w > contentW then contentW = w end
        end
        local popupW = Utils.FlyoutWidthFor(contentW, PAD)
        for i = 1, #defs do slotRows[i]:SetWidth(popupW - PAD * 2) end
        slotPopup:SetSize(popupW, -py + PAD)
    end
    local slotBtn
    slotBtn, setSlotLabel = Utils.CreateDropdownButton({
        parent = optionsPopup, x = PAD, y = -PAD,
        width = WIDTH - PAD * 2, height = CLASS_BTN_H,
        popup = slotPopup, layout = LayoutSlotPopup,
        getScale = function() return EasyFind.db.uiSearchScale or 1.0 end,
        guardFrames = dropdownGuardFrames,
    })



    local filterPopup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    filterPopup:SetFrameStrata("TOOLTIP")
    filterPopup:SetFrameLevel(optionsPopup:GetFrameLevel() + 20)
    StylePopup(filterPopup)
    filterPopup:EnableMouse(true)
    filterPopup:Hide()

    local toggleDefs = {
        { dbKey = "appearanceItemCollected",    label = _G["COLLECTED"] or "Collected",        default = true },
        { dbKey = "appearanceItemNotCollected", label = _G["NOT_COLLECTED"] or "Not Collected", default = false },
        { dbKey = "appearanceItemAllFactions",  label = _G["TRANSMOG_SHOW_ALL_FACTIONS"] or "All Factions",   default = true },
        { dbKey = "appearanceItemAllRaces",     label = _G["TRANSMOG_SHOW_ALL_RACES"] or "All Races",         default = true },
    }
    local toggleRows = {}
    for i, def in ipairs(toggleDefs) do
        local row = MakeCheckRow(filterPopup, WIDTH - PAD * 2, ROW_H, CHECK_SIZE)
        row.text:SetText(def.label)
        row:SetPoint("TOPLEFT", filterPopup, "TOPLEFT", PAD, -(PAD + (i - 1) * ROW_H))
        row.dbKey = def.dbKey
        row.default = def.default
        row:SetScript("OnClick", function(self)
            EasyFind.db[self.dbKey] = self:GetChecked() and true or false
            Filters:ApplyFilterSelection("appearanceItems")
        end)
        toggleRows[i] = row
    end

    local sourcesRow = CreateFrame("Button", nil, filterPopup)
    sourcesRow:SetSize(WIDTH - PAD * 2, ROW_H)
    sourcesRow:SetPoint("TOPLEFT", filterPopup, "TOPLEFT", PAD, -(PAD + #toggleDefs * ROW_H))
    local sourcesText = sourcesRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sourcesText:SetPoint("LEFT", 12, 0)
    sourcesText:SetText(_G["SOURCES"] or "Sources")
    local sourcesChev = sourcesRow:CreateTexture(nil, "OVERLAY")
    Utils.SetChevronTexture(sourcesChev)
    sourcesChev:SetSize(CHECK_SIZE, CHECK_SIZE)
    sourcesChev:SetPoint("RIGHT", -4, 0)
    sourcesRow._label = sourcesText
    sourcesRow._chev = sourcesChev
    Utils.InstallMenuRowHighlight(sourcesRow)
    local filterContentW = 0
    for i = 1, #toggleRows do
        local w = Utils.FlyoutRowContentWidth(toggleRows[i], CHECK_SIZE + 4)
        if w > filterContentW then filterContentW = w end
    end
    local filterSrcW = Utils.FlyoutRowContentWidth(sourcesRow, 12, nil, CHECK_SIZE)
    if filterSrcW > filterContentW then filterContentW = filterSrcW end
    local filterPopupW = Utils.FlyoutWidthFor(filterContentW, PAD)
    for i = 1, #toggleRows do toggleRows[i]:SetWidth(filterPopupW - PAD * 2) end
    sourcesRow:SetWidth(filterPopupW - PAD * 2)
    filterPopup:SetSize(filterPopupW, PAD * 2 + (#toggleDefs + 1) * ROW_H)

    local function SourceFilters()
        EasyFind.db.appearanceItemSourceFilters = EasyFind.db.appearanceItemSourceFilters or {}
        return EasyFind.db.appearanceItemSourceFilters
    end


    local sourceFlyout = Filters:BuildSourceFlyout({
        stylePopup = StylePopup,
        checkSize = CHECK_SIZE,
        width = WIDTH,
        frameLevel = optionsPopup:GetFrameLevel() + 40,
        getScale = function() return EasyFind.db.uiSearchScale or 1.0 end,
        guardFrames = dropdownGuardFrames,
        chainGuards = branchPopups,
        sourcesRow = sourcesRow,
        collectDefs = GetSourceDefs,
        defField = "source",
        getFilters = SourceFilters,
        chainEnabled = ChainEnabled,
        applyKey = "appearanceItems",
    })

    local function SyncFilterToggles()
        local chainEnabled = ChainEnabled()
        for _, row in ipairs(toggleRows) do
            local v = EasyFind.db[row.dbKey]
            if v == nil then v = row.default end
            row:SetChecked(v and true or false)
            SetFlyoutRowEnabled(row, chainEnabled)
        end
        SetFlyoutRowEnabled(sourcesRow, chainEnabled)
    end

    local filterBtn, setFilterLabel = Utils.CreateDropdownButton({
        parent = optionsPopup, x = PAD, y = -(PAD + CLASS_BTN_H + 4),
        width = WIDTH - PAD * 2, height = CLASS_BTN_H,
        popup = filterPopup, layout = SyncFilterToggles,
        getScale = function() return EasyFind.db.uiSearchScale or 1.0 end,
        guardFrames = dropdownGuardFrames,
        extraGuards = { sourceFlyout },
    })
    setFilterLabel(_G["FILTER"] or "Filter")
    filterPopup:HookScript("OnHide", function() sourceFlyout:Hide() end)

    optionsPopup:SetSize(WIDTH, PAD * 2 + (CLASS_BTN_H + 4) * 2 - 4)

    optionsPopup:HookScript("OnHide", function()
        slotPopup:Hide()
        filterPopup:Hide()
        sourceFlyout:Hide()
    end)

    branchPopups[#branchPopups + 1] = optionsPopup
    branchPopups[#branchPopups + 1] = slotPopup
    branchPopups[#branchPopups + 1] = filterPopup
    branchPopups[#branchPopups + 1] = sourceFlyout

    local function SyncFromDB()
        UpdateSlotLabel()
        local chainEnabled = ChainEnabled()
        SetFlyoutRowEnabled(slotBtn, chainEnabled)
        SetFlyoutRowEnabled(filterBtn, chainEnabled)
    end

    UpdateSlotLabel()
    return optionsPopup, SyncFromDB
end





function Filters:BuildAppearanceOptionsPopup(StylePopup, CHECK_SIZE, dropdownGuardFrames)
    local WIDTH = 160
    local ROW_H = 24
    local PAD = 6
    local CLASS_BTN_H = 27
    local CLASS_GAP = 4
    local branchPopups = {}

    local chooser = CreateFrame("Frame", "EasyFindAppChooserPopup", UIParent, "BackdropTemplate")
    chooser:SetFrameStrata("TOOLTIP")
    StylePopup(chooser)
    chooser:EnableMouse(true)
    chooser:Hide()
    branchPopups[#branchPopups + 1] = chooser

    local itemsPopup, syncItems = Filters:BuildAppearanceItemOptionsPopup(
        StylePopup, CHECK_SIZE, dropdownGuardFrames, branchPopups)
    local setsPopup, syncSets = Filters:BuildAppearanceSetOptionsPopup(
        StylePopup, CHECK_SIZE, dropdownGuardFrames, branchPopups)
    itemsPopup:SetFrameLevel(chooser:GetFrameLevel() + Utils.MENU_LEVEL_STEP)
    setsPopup:SetFrameLevel(chooser:GetFrameLevel() + Utils.MENU_LEVEL_STEP)
    if dropdownGuardFrames then
        dropdownGuardFrames[#dropdownGuardFrames + 1] = itemsPopup
        dropdownGuardFrames[#dropdownGuardFrames + 1] = setsPopup
    end




    local classSel = Filters:BuildClassSpecSelector({
        parent = chooser,
        x = PAD, y = -PAD,
        width = ns.CLASS_SELECTOR_BTN_W,
        hasSpec = false,
        stylePopup = StylePopup,
        guardFrames = dropdownGuardFrames,
        getScale = function() return EasyFind.db.uiSearchScale or 1.0 end,
        getFilter = function() return EasyFind.db.appearanceSetClass end,
        setFilter = function(v)
            EasyFind.db.appearanceSetClass = v
            EasyFind.db.appearanceItemClass = v
        end,
        onChange = function() Filters:ApplyFilterSelection("appearanceItems", "transmogSets") end,
    })
    if classSel.popup then branchPopups[#branchPopups + 1] = classSel.popup end

    local rows = {
        { label = _G["ITEMS"] or "Items", popup = itemsPopup, sync = syncItems, filterKey = "appearanceItems" },
        { label = _G["TRANSMOG_TAB_SETS"] or "Sets", popup = setsPopup, sync = syncSets, filterKey = "appearanceSets" },
    }
    local siblingPopups = { itemsPopup, setsPopup }
    local checkRows = {}
    for i, def in ipairs(rows) do
        local row = CreateFrame("CheckButton", nil, chooser)
        row:SetSize(WIDTH - PAD * 2, ROW_H)
        row:SetPoint("TOPLEFT", chooser, "TOPLEFT", PAD,
            -(PAD + CLASS_BTN_H + CLASS_GAP + (i - 1) * ROW_H))
        Utils.SetCheckboxTextures(row, CHECK_SIZE)
        local txt = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        txt:SetPoint("LEFT", row:GetNormalTexture(), "RIGHT", 4, 0)
        txt:SetText(def.label)
        local chev = row:CreateTexture(nil, "OVERLAY")
        Utils.SetChevronTexture(chev)
        chev:SetSize(CHECK_SIZE - 2, CHECK_SIZE - 2)
        chev:SetPoint("RIGHT", -4, 0)
        row._label = txt
        row._chev = chev
        Utils.InstallMenuRowHighlight(row)

        local filterKey = def.filterKey
        row:SetChecked(EasyFind.db.uiSearchFilters[filterKey] ~= false)
        row:SetScript("OnClick", function(self)
            EasyFind.db.uiSearchFilters[filterKey] = self:GetChecked()
            Filters.ResyncShownOptionPopups()
            Filters:RerunActiveSearch()
        end)
        checkRows[i] = { row = row, filterKey = filterKey }

        local p, s = def.popup, def.sync
        p._owningRow = row
        p._efSync = s
        Utils.AttachHoverPopup(row, p, {
            chainGuards = branchPopups,
            onShow = function()
                for _, other in ipairs(siblingPopups) do
                    if other ~= p then other:Hide() end
                end
                s()
                p:SetScale(EasyFind.db.uiSearchScale or 1.0)
                Utils.OpenFlyoutBeside(p, row, 4)
                p:Show()
            end,
        })
    end
    local chooserContentW = 0
    for i = 1, #checkRows do
        local w = Utils.FlyoutRowContentWidth(checkRows[i].row, CHECK_SIZE + 4, nil, CHECK_SIZE - 2)
        if w > chooserContentW then chooserContentW = w end
    end

    if ns.CLASS_SELECTOR_BTN_W > chooserContentW then chooserContentW = ns.CLASS_SELECTOR_BTN_W end
    local chooserW = Utils.FlyoutWidthFor(chooserContentW, PAD)
    for i = 1, #checkRows do checkRows[i].row:SetWidth(chooserW - PAD * 2) end
    chooser:SetSize(chooserW, PAD * 2 + CLASS_BTN_H + CLASS_GAP + #rows * ROW_H)

    chooser:HookScript("OnHide", function()
        itemsPopup:Hide()
        setsPopup:Hide()
        if classSel.popup then classSel.popup:Hide() end
    end)

    local function SyncChooser()
        classSel.Refresh()
        local uiFilters = EasyFind.db.uiSearchFilters
        local chainEnabled = uiFilters.collections ~= false and uiFilters.appearances ~= false
        SetFlyoutRowEnabled(classSel.button, chainEnabled)
        for _, cr in ipairs(checkRows) do
            cr.row:SetChecked(uiFilters[cr.filterKey] ~= false)
            SetFlyoutRowEnabled(cr.row, chainEnabled)
        end
    end
    return chooser, SyncChooser, branchPopups
end
