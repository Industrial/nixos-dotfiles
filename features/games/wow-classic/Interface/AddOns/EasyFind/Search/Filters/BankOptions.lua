local _, ns = ...

local Filters = ns.Filters
local Utils = ns.Utils

local CreateFrame = CreateFrame
local UIParent = UIParent




function Filters:BuildStorageScopeFlyout(opts)
    local ROW_H = 22
    local PAD = 6
    local StylePopup = opts.stylePopup
    local CHECK_SIZE = opts.checkSize

    local optionsPopup = CreateFrame("Frame", opts.name, UIParent, "BackdropTemplate")
    optionsPopup:SetFrameStrata("TOOLTIP")
    StylePopup(optionsPopup)
    optionsPopup:EnableMouse(true)
    optionsPopup:Hide()

    local function ChainEnabled()
        local uiFilters = EasyFind.db.uiSearchFilters
        return uiFilters.items ~= false and uiFilters[opts.filterKey] ~= false
    end

    local scopeLabel = optionsPopup:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    scopeLabel:SetPoint("TOPLEFT", optionsPopup, "TOPLEFT", PAD + 2, -PAD)
    scopeLabel:SetText(_G["CHARACTER"] or "Character")





    local branchPopups = { optionsPopup }

    local selector = Filters:BuildCharacterScopeSelector({
        name = opts.selectorName,
        parent = optionsPopup,
        stylePopup = StylePopup,
        width = 150,
        x = PAD,
        y = -PAD - 16,
        branchPopups = branchPopups,
        getChars = opts.getChars,
        getValue = function() return EasyFind.db[opts.dbKey] or "current" end,
        setValue = function(value) EasyFind.db[opts.dbKey] = value end,


        onChange = function() Filters:ApplyFilterSelection(opts.providerKey) end,
        guardFrames = opts.guardFrames,
        getScale = function() return optionsPopup:GetScale() end,
    })

    local hideTipRow = CreateFrame("CheckButton", nil, optionsPopup)
    hideTipRow:SetSize(150, ROW_H)
    hideTipRow:SetPoint("TOPLEFT", optionsPopup, "TOPLEFT", PAD, -PAD - 16 - 27 - 4)
    Utils.SetCheckboxTextures(hideTipRow, CHECK_SIZE)
    local hideTipLabel = hideTipRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    hideTipLabel:SetPoint("LEFT", hideTipRow:GetNormalTexture(), "RIGHT", 4, 0)
    hideTipLabel:SetText(ns.L["FILTER_HIDE_TOOLTIPS"])
    hideTipRow._label = hideTipLabel
    Utils.InstallMenuRowHighlight(hideTipRow)
    hideTipRow:SetScript("OnClick", function(self)
        EasyFind.db.hideTooltips = EasyFind.db.hideTooltips or {}
        EasyFind.db.hideTooltips[opts.filterKey] = self:GetChecked() and true or false
    end)

    local contentW = Utils.FlyoutRowContentWidth(hideTipRow, CHECK_SIZE + 4)
    local labelW = scopeLabel:GetStringWidth() + 4
    if labelW > contentW then contentW = labelW end
    if 150 > contentW then contentW = 150 end
    local popupW = Utils.FlyoutWidthFor(contentW, PAD)
    hideTipRow:SetWidth(popupW - PAD * 2)
    selector.button:SetWidth(popupW - PAD * 2)
    optionsPopup:SetSize(popupW, PAD * 2 + 16 + 27 + 4 + ROW_H)

    local function SyncOptions()
        local chainEnabled = ChainEnabled()
        local ht = EasyFind.db.hideTooltips
        hideTipRow:SetChecked(ht and ht[opts.filterKey] or false)
        Utils.SetFlyoutRowEnabled(hideTipRow, chainEnabled)
        Utils.SetFlyoutRowEnabled(selector.button, chainEnabled)
        selector.Refresh()
    end

    optionsPopup:HookScript("OnHide", function() selector.popup:Hide() end)

    if opts.guardFrames then
        opts.guardFrames[#opts.guardFrames + 1] = optionsPopup
    end
    return optionsPopup, SyncOptions, branchPopups
end

function Filters:BuildBankOptionsPopup(StylePopup, CHECK_SIZE, dropdownGuardFrames)
    return Filters:BuildStorageScopeFlyout({
        name = "EasyFindBankOptionsPopup",
        selectorName = "EasyFindBankScopePopup",
        stylePopup = StylePopup,
        checkSize = CHECK_SIZE,
        guardFrames = dropdownGuardFrames,
        filterKey = "bank",
        providerKey = "bank",
        dbKey = "bankScope",
        getChars = function()
            local cache = EasyFind.db.bankCache
            return cache and cache.chars
        end,
    })
end

function Filters:BuildBagOptionsPopup(StylePopup, CHECK_SIZE, dropdownGuardFrames)
    return Filters:BuildStorageScopeFlyout({
        name = "EasyFindBagOptionsPopup",
        selectorName = "EasyFindBagScopePopup",
        stylePopup = StylePopup,
        checkSize = CHECK_SIZE,
        guardFrames = dropdownGuardFrames,
        filterKey = "bags",
        providerKey = "bags",
        dbKey = "bagScope",
        getChars = function()
            local cache = EasyFind.db.bagCache
            return cache and cache.chars
        end,
    })
end
