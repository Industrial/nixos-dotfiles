local _, ns = ...

local Filters = ns.Filters
local Utils = ns.Utils

local ipairs = Utils.ipairs
local SetFlyoutRowEnabled = Utils.SetFlyoutRowEnabled
local CreateFrame = CreateFrame
local UIParent = UIParent




function Filters:BuildAppearanceSetOptionsPopup(StylePopup, CHECK_SIZE, dropdownGuardFrames, branchPopups)
    local OPTIONS_WIDTH = 160
    local CB_ROW_H = 22
    local PAD = 6

    local optionsPopup = CreateFrame("Frame", "EasyFindAsOptionsPopup", UIParent, "BackdropTemplate")
    optionsPopup:SetFrameStrata("TOOLTIP")
    StylePopup(optionsPopup)
    optionsPopup:EnableMouse(true)
    optionsPopup:Hide()

    if branchPopups then
        branchPopups[#branchPopups + 1] = optionsPopup
    end

    local filterDefs = {
        { dbKey = "appearanceSetCollected",     label = _G["COLLECTED"] or "Collected" },
        { dbKey = "appearanceSetNotCollected",  label = _G["NOT_COLLECTED"] or "Not Collected" },
        { dbKey = "appearanceSetPvE",           label = _G["TRANSMOG_SET_PVE"] or "PvE" },
        { dbKey = "appearanceSetPvP",           label = _G["PVP"] or "PvP" },
    }

    local cbRows = {}
    local cy = -PAD
    for si, def in ipairs(filterDefs) do
        local cbRow = CreateFrame("CheckButton", nil, optionsPopup)
        cbRow:SetSize(OPTIONS_WIDTH - PAD * 2, CB_ROW_H)
        cbRow:SetPoint("TOPLEFT", optionsPopup, "TOPLEFT", PAD, cy)

        Utils.SetCheckboxTextures(cbRow, CHECK_SIZE)

        local cbText = cbRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        cbText:SetPoint("LEFT", cbRow:GetNormalTexture(), "RIGHT", 4, 0)
        cbText:SetText(def.label)
        cbRow._label = cbText

        Utils.InstallMenuRowHighlight(cbRow)

        local val = EasyFind.db[def.dbKey]
        if val == nil then val = true end
        cbRow:SetChecked(val)
        cbRow.dbKey = def.dbKey

        cbRow:SetScript("OnClick", function(self)
            EasyFind.db[def.dbKey] = self:GetChecked()
            Filters:ApplyFilterSelection("transmogSets")
        end)

        cbRows[si] = cbRow
        cy = cy - CB_ROW_H
        if si == 2 then
            local sep = optionsPopup:CreateTexture(nil, "ARTWORK")
            sep:SetHeight(1)
            sep:SetPoint("TOPLEFT", optionsPopup, "TOPLEFT", PAD + 4, cy + 2)
            sep:SetPoint("TOPRIGHT", optionsPopup, "TOPRIGHT", -(PAD + 4), cy + 2)
            sep:SetColorTexture(0.5, 0.5, 0.5, 0.4)
            cy = cy - 6
        end
    end
    local contentW = 0
    for si = 1, #cbRows do
        local w = Utils.FlyoutRowContentWidth(cbRows[si], CHECK_SIZE + 4)
        if w > contentW then contentW = w end
    end
    local popupW = Utils.FlyoutWidthFor(contentW, PAD)
    for si = 1, #cbRows do cbRows[si]:SetWidth(popupW - PAD * 2) end
    optionsPopup:SetSize(popupW, -cy + PAD)


    Filters.AttachOutsideClickClose(optionsPopup)

    local function SyncFromDB()
        local uiFilters = EasyFind.db.uiSearchFilters
        local chainEnabled = uiFilters.collections ~= false and uiFilters.appearances ~= false
            and uiFilters.appearanceSets ~= false
        for _, sr in ipairs(cbRows) do
            if sr.dbKey then
                sr:SetChecked(EasyFind.db[sr.dbKey] ~= false)
            end
            SetFlyoutRowEnabled(sr, chainEnabled)
        end
    end

    return optionsPopup, SyncFromDB
end
