local _, ns = ...

local Filters = ns.Filters
local Utils = ns.Utils

local ipairs = Utils.ipairs
local CreateFrame = CreateFrame
local UIParent = UIParent












function Filters:BuildSelectDropdown(opts)
    local options = opts.options
    local getValue = opts.getValue
    local setValue = opts.setValue
    local formatLabel = opts.formatLabel
    local onChange = opts.onChange
    local StylePopup = opts.stylePopup

    local popup = CreateFrame("Frame", opts.name, UIParent, "BackdropTemplate")
    popup:SetFrameStrata("TOOLTIP")
    StylePopup(popup)
    popup:EnableMouse(true)
    popup:Hide()

    local rows = {}
    local setLabel

    local function RefreshRadios(value)
        for _, r in ipairs(rows) do
            r._radio:SetTexture(r._value == value and ns.RADIO_ON_TEX or ns.RADIO_OFF_TEX)
        end
    end

    local py = -6
    for _, def in ipairs(options) do
        local row = CreateFrame("Button", nil, popup)
        row:SetSize(130, 20)
        row:SetPoint("TOPLEFT", 8, py)
        local radio = row:CreateTexture(nil, "ARTWORK")
        radio:SetSize(14, 14)
        radio:SetPoint("LEFT", 0, 0)
        radio:SetTexture(ns.RADIO_OFF_TEX)
        local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        ns.ShadeText(label)
        label:SetPoint("LEFT", radio, "RIGHT", 4, 0)
        label:SetText(def.label)
        row._label = label
        row._radio = radio
        row._value = def.value
        Utils.InstallMenuRowHighlight(row)
        row:SetScript("OnClick", function()
            setValue(def.value)
            RefreshRadios(def.value)
            if setLabel then setLabel(formatLabel(def.value, def.label)) end
            popup:Hide()
            if onChange then onChange() end
        end)
        rows[#rows + 1] = row
        py = py - 20
    end

    local contentW = 0
    for i = 1, #rows do
        local w = Utils.FlyoutRowContentWidth(rows[i], 14 + 4)
        if w > contentW then contentW = w end
    end
    local popupW = Utils.FlyoutWidthFor(contentW, 8)
    for i = 1, #rows do rows[i]:SetWidth(popupW - 16) end
    popup:SetSize(popupW, -py + 6)

    local btn
    btn, setLabel = Utils.CreateDropdownButton({
        parent = opts.parent,
        width = opts.width,
        height = opts.height or 27,
        popup = popup,




        layout = function()
            RefreshRadios(getValue())
            if btn then popup:SetFrameLevel(btn:GetFrameLevel() + 20) end
        end,
        getScale = opts.getScale or function() return EasyFind.db.uiSearchScale or 1.0 end,
        guardFrames = opts.guardFrames,
    })

    if opts.keyboardNav then
        opts.keyboardNav(popup, function() return rows end)
    end

    local function Refresh()
        local v = getValue()
        RefreshRadios(v)
        local optLabel
        for i = 1, #options do
            if options[i].value == v then optLabel = options[i].label end
        end
        setLabel(formatLabel(v, optLabel))
    end
    Refresh()

    return { button = btn, popup = popup, rows = rows, Refresh = Refresh, setLabel = setLabel }
end
