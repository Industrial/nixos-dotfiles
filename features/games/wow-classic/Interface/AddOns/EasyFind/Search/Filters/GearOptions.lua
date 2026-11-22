



local _, ns = ...

local Filters = ns.Filters
local Utils = ns.Utils
local L = ns.L

local ipairs = Utils.ipairs
local SetFlyoutRowEnabled = Utils.SetFlyoutRowEnabled
local CreateFrame = CreateFrame
local UIParent = UIParent

function Filters:AttachLootOptionsFlyout(row, dropdown, ctx)
    local ROW_HEIGHT = ctx.rowHeight
    local CHECK_SIZE = ctx.checkSize
    local StylePopup = ctx.StylePopup
    local AddPopupKeyboardNav = ctx.AddPopupKeyboardNav
    local SetActiveFlyout = ctx.SetActiveFlyout
    local ClearActiveFlyout = ctx.ClearActiveFlyout
    local dropdownGuardFrames = ctx.dropdownGuardFrames
    local LOOT_POPUP_WIDTH = 184
    local LOOT_POPUP_PAD = 8

    local function InstallMenuRowHighlight(target)
        Utils.InstallMenuRowHighlight(target)
    end

    local lootOptionsPopup = CreateFrame("Frame", "EasyFindLootOptionsPopup", UIParent, "BackdropTemplate")
    lootOptionsPopup:SetFrameStrata("TOOLTIP")
    StylePopup(lootOptionsPopup)
    lootOptionsPopup:EnableMouse(true)
    lootOptionsPopup:Hide()
    row.lootOptionsPopup = lootOptionsPopup
    dropdownGuardFrames[#dropdownGuardFrames + 1] = lootOptionsPopup

    local lootSubDefs = {
        { dbKey = "lootUpgradesOnly", label = L["FILTER_ILVL_UPGRADES_ONLY"] },
        { dbKey = "hideTooltips.loot", label = L["FILTER_HIDE_TOOLTIPS"] },
    }
    local lootSubRows = {}
    for si, sub in ipairs(lootSubDefs) do
        local subRow = CreateFrame("CheckButton", nil, lootOptionsPopup)
        subRow:SetSize(LOOT_POPUP_WIDTH - LOOT_POPUP_PAD * 2, ROW_HEIGHT)
        subRow:SetHitRectInsets(0, 0, 0, 0)

        Utils.SetCheckboxTextures(subRow, CHECK_SIZE)

        local subLabel = subRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        ns.ShadeText(subLabel)
        subLabel:SetPoint("LEFT", subRow:GetNormalTexture(), "RIGHT", 4, 0)
        subLabel:SetText(sub.label)
        subRow._label = subLabel

        InstallMenuRowHighlight(subRow)

        subRow.dbKey = sub.dbKey
        lootSubRows[si] = subRow

        local function resolveDbPath()
            return ns.ResolveDbKey(sub.dbKey)
        end

        subRow:SetScript("OnClick", function(self)
            local tbl, leaf = resolveDbPath()
            tbl[leaf] = self:GetChecked() and true or false
            Filters:RerunActiveSearch()
        end)
        subRow.resolveDbPath = resolveDbPath
    end



    local lootSep = lootOptionsPopup:CreateTexture(nil, "ARTWORK")
    lootSep:SetHeight(1)
    lootSep:SetColorTexture(0.5, 0.5, 0.5, 0.4)
    row.lootSep = lootSep




    local DIFF_LABELS = {
        lfr    = _G["RAID_FINDER"] or "Raid Finder",
        normal = _G["PLAYER_DIFFICULTY1"] or "Normal",
        heroic = _G["PLAYER_DIFFICULTY2"] or "Heroic",
        mythic = _G["PLAYER_DIFFICULTY6"] or "Mythic",
    }

    local DIFF_OPTIONS = {}
    for _, key in ipairs(ns.Caps.lootDifficulties) do
        DIFF_OPTIONS[#DIFF_OPTIONS + 1] = { value = key, label = DIFF_LABELS[key] }
    end
    local hasDifficulty = #DIFF_OPTIONS > 0
    if not hasDifficulty then DIFF_OPTIONS[1] = { value = "normal", label = DIFF_LABELS.normal } end

    local diffSel = Filters:BuildSelectDropdown({
        parent = lootOptionsPopup,
        name = "EasyFindDiffPopup",
        width = LOOT_POPUP_WIDTH - LOOT_POPUP_PAD * 2,
        options = DIFF_OPTIONS,
        getValue = function() return ns.Database.LootDifficulty() end,
        setValue = function(v)
            EasyFind.db.lootDifficulty = v

            EasyFind.API.Fire("loot", "changed")
        end,
        formatLabel = function(_, optLabel) return optLabel or (_G["PLAYER_DIFFICULTY1"] or "Normal") end,
        onChange = function() Filters:ApplyFilterSelection("loot") end,
        stylePopup = StylePopup,
        guardFrames = dropdownGuardFrames,
        keyboardNav = AddPopupKeyboardNav,
    })
    local diffBtn = diffSel.button
    local diffPopup = diffSel.popup
    local diffPopupRows = diffSel.rows
    row.diffBtn = diffBtn
    row.diffPopup = diffPopup
    row.UpdateDiffButtons = diffSel.Refresh



    local function ApplyFilterSelection()
        if ns.Database then
            if ns.Database.RefreshDynamicCategory then
                ns.Database:RefreshDynamicCategory("loot")
            end
            ns.Database:SyncEJLootFilter()
        end
        Filters:RerunActiveSearch()
    end



    local classSel = Filters:BuildClassSpecSelector({
        parent = lootOptionsPopup,
        width = ns.CLASS_SELECTOR_BTN_W,
        popupWidth = 180,
        flyoutWidth = 160,
        popupName = "EasyFindSpecPopup",
        flyoutName = "EasyFindSpecFlyout",
        hasSpec = true,
        stylePopup = StylePopup,
        guardFrames = dropdownGuardFrames,
        keyboardNav = AddPopupKeyboardNav,
        getScale = function() return EasyFind.db.uiSearchScale or 1.0 end,
        getFilter = function() return EasyFind.db.lootFilter end,
        setFilter = function(v) EasyFind.db.lootFilter = v end,
        onChange = ApplyFilterSelection,
    })
    local specSelectRow = classSel.button

    row.specSelectRow = specSelectRow
    row.specSelectLabel = specSelectRow._label
    row.lootSubRows = lootSubRows

    dropdown:HookScript("OnHide", function()
        classSel.flyout:Hide()
        classSel.popup:Hide()
    end)

    local gy = -LOOT_POPUP_PAD
    diffBtn:ClearAllPoints()
    if hasDifficulty then
        diffBtn:SetPoint("TOPLEFT", lootOptionsPopup, "TOPLEFT", LOOT_POPUP_PAD, gy)
        gy = gy - 27 - 4
    else
        diffBtn:Hide()
    end
    specSelectRow:ClearAllPoints()
    specSelectRow:SetPoint("TOPLEFT", lootOptionsPopup, "TOPLEFT", LOOT_POPUP_PAD, gy)
    gy = gy - 27 - 6
    lootSep:ClearAllPoints()
    lootSep:SetPoint("LEFT", lootOptionsPopup, "LEFT", LOOT_POPUP_PAD, 0)
    lootSep:SetPoint("RIGHT", lootOptionsPopup, "RIGHT", -LOOT_POPUP_PAD, 0)
    lootSep:SetPoint("TOP", 0, gy)
    gy = gy - 6
    for _, sr in ipairs(lootSubRows) do
        sr:ClearAllPoints()
        sr:SetPoint("TOPLEFT", lootOptionsPopup, "TOPLEFT", LOOT_POPUP_PAD, gy)
        gy = gy - ROW_HEIGHT
    end
    local contentW = 0
    for i = 1, #lootSubRows do
        local w = Utils.FlyoutRowContentWidth(lootSubRows[i], CHECK_SIZE + 4)
        if w > contentW then contentW = w end
    end


    local diffBtnW = hasDifficulty and (14 + Utils.MaxRowLabelWidth(diffPopupRows) + 2 + 22 + 10) or 0
    if diffBtnW > contentW then contentW = diffBtnW end




    if ns.CLASS_SELECTOR_BTN_W > contentW then contentW = ns.CLASS_SELECTOR_BTN_W end
    local popupW = Utils.FlyoutWidthFor(contentW, LOOT_POPUP_PAD)
    for i = 1, #lootSubRows do lootSubRows[i]:SetWidth(popupW - LOOT_POPUP_PAD * 2) end
    diffBtn:SetWidth(popupW - LOOT_POPUP_PAD * 2)
    specSelectRow:SetWidth(popupW - LOOT_POPUP_PAD * 2)
    lootOptionsPopup:SetSize(popupW, -gy + LOOT_POPUP_PAD)



    local lootHover = Utils.AttachHoverPopup(row, lootOptionsPopup, {
        extraGuards = {
            diffPopup,
            classSel.popup,
            classSel.flyout,
        },
        onShow = function()
            SetActiveFlyout(lootOptionsPopup)
            if row.updateLootToggle then row.updateLootToggle() end
            lootOptionsPopup:SetScale(EasyFind.db.uiSearchScale or 1.0)
            Utils.OpenFlyoutBeside(lootOptionsPopup, row, 4)
            lootOptionsPopup:Show()
        end,
    })
    row.ShowLootOptionsPopup = lootHover.Show


    Filters.AttachOutsideClickClose(lootOptionsPopup, {
        onHide = function(self)
            diffPopup:Hide()
            classSel.popup:Hide()
            classSel.flyout:Hide()
            ClearActiveFlyout(self)
        end,
    })
    dropdown:HookScript("OnHide", function() lootOptionsPopup:Hide() end)

    row.updateLootToggle = function()
        local chainEnabled = EasyFind.db.uiSearchFilters.loot ~= false
        for _, sr in ipairs(lootSubRows) do
            if sr.SetChecked and sr.resolveDbPath then
                local tbl, leaf = sr.resolveDbPath()
                sr:SetChecked(tbl[leaf] == true)
            end
            SetFlyoutRowEnabled(sr, chainEnabled)
        end
        SetFlyoutRowEnabled(diffBtn, chainEnabled)
        SetFlyoutRowEnabled(specSelectRow, chainEnabled)
        classSel.Refresh()
        if row.UpdateDiffButtons then row.UpdateDiffButtons() end
    end
    lootOptionsPopup._efSync = row.updateLootToggle
end
