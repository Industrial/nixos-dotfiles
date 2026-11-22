local _, ns = ...

local Filters = ns.Filters
local Utils = ns.Utils
local L = ns.L

local ipairs = Utils.ipairs
local SetFlyoutRowEnabled = Utils.SetFlyoutRowEnabled
local CreateFrame = CreateFrame
local UIParent = UIParent
local wipe = wipe
local mmax, mceil = math.max, math.ceil

local ROW_H = 22
local PAD = 6















function Filters:BuildSourceFlyout(opts)
    local collectDefs = opts.collectDefs
    local defField = opts.defField
    local getFilters = opts.getFilters
    local applyKey = opts.applyKey

    local flyout = CreateFrame("Frame", opts.name, UIParent, "BackdropTemplate")
    flyout:SetFrameStrata("TOOLTIP")
    flyout:SetFrameLevel(opts.frameLevel)
    opts.stylePopup(flyout)
    flyout:EnableMouse(true)
    flyout:Hide()
    if opts.guardFrames then opts.guardFrames[#opts.guardFrames + 1] = flyout end

    local toggleAllRow = CreateFrame("Button", nil, flyout)
    toggleAllRow:SetSize(opts.width - PAD * 2, ROW_H)
    toggleAllRow:SetPoint("TOPLEFT", flyout, "TOPLEFT", PAD, -PAD)
    local toggleAllLabel = toggleAllRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    toggleAllLabel:SetPoint("LEFT", 14, 0)
    toggleAllLabel:SetText(L["FILTER_TOGGLE_ALL"])
    toggleAllRow._label = toggleAllLabel
    Utils.InstallMenuRowHighlight(toggleAllRow)

    local function OnSourceRowClick(self)
        local filters = getFilters()
        if self:GetChecked() then
            filters[self._sourceKey] = nil
        else
            filters[self._sourceKey] = false
        end
        Filters:ApplyFilterSelection(applyKey)
    end

    local sourceRows = {}
    local function Layout()
        local defs = collectDefs()
        local filters = getFilters()
        local chainEnabled = opts.chainEnabled()
        SetFlyoutRowEnabled(toggleAllRow, chainEnabled)
        for i = #sourceRows, #defs + 1, -1 do
            sourceRows[i]:Hide()
        end
        for i, def in ipairs(defs) do
            local row = sourceRows[i]
            if not row then
                row = CreateFrame("CheckButton", nil, flyout)
                row:SetSize(opts.width - PAD * 2, ROW_H)
                Utils.SetCheckboxTextures(row, opts.checkSize)
                row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                row.text:SetPoint("LEFT", row:GetNormalTexture(), "RIGHT", 4, 0)
                row._label = row.text
                Utils.InstallMenuRowHighlight(row)
                row:SetScript("OnClick", OnSourceRowClick)
                sourceRows[i] = row
            end
            row._sourceKey = def[defField]
            row.text:SetText(def.label)
            row:SetChecked(filters[def[defField]] ~= false)
            SetFlyoutRowEnabled(row, chainEnabled)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", flyout, "TOPLEFT", PAD, -(PAD + i * ROW_H))
            row:Show()
        end
        local contentW = mmax(14 + (toggleAllLabel:GetStringWidth() or 0),
            opts.checkSize + 4 + Utils.MaxRowLabelWidth(sourceRows, #defs))
        local flyoutW = mmax(ns.FLYOUT_MIN_WIDTH, mceil(contentW) + PAD * 2 + 8)
        toggleAllRow:SetWidth(flyoutW - PAD * 2)
        for i = 1, #defs do
            sourceRows[i]:SetWidth(flyoutW - PAD * 2)
        end
        flyout:SetSize(flyoutW, PAD * 2 + (1 + #defs) * ROW_H)
        Utils.RefreshMenuRowHighlights(flyout)
    end



    toggleAllRow:SetScript("OnClick", function()
        local defs = collectDefs()
        local filters = getFilters()
        local allUnchecked = true
        for _, def in ipairs(defs) do
            if filters[def[defField]] ~= false then
                allUnchecked = false
                break
            end
        end
        if allUnchecked then
            wipe(filters)
        else
            for _, def in ipairs(defs) do
                filters[def[defField]] = false
            end
        end
        Layout()
        Filters:ApplyFilterSelection(applyKey)
    end)

    Utils.AttachHoverPopup(opts.sourcesRow, flyout, {
        chainGuards = opts.chainGuards,
        onShow = function()
            Layout()
            flyout:SetScale(opts.getScale())
            if opts.getShowLevel then
                flyout:SetFrameLevel(opts.getShowLevel())
            end
            Utils.OpenFlyoutBeside(flyout, opts.sourcesRow, 4)
            flyout:Show()
        end,
    })

    return flyout, Layout
end
