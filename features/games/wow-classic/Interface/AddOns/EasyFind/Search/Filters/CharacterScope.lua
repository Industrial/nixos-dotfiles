local _, ns = ...

local Filters = ns.Filters
local Utils = ns.Utils

local pairs = Utils.pairs
local tsort = Utils.tsort
local CreateFrame = CreateFrame
local UIParent = UIParent

local ROW_H = 20
local MAX_VISIBLE_ROWS = 10

local function ByLabel(a, b) return a.label < b.label end

local function ClassColorStr(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not c then return "" end
    return ("|cff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255)
end

local function Colored(label, class)
    local color = ClassColorStr(class)
    if color == "" then return label end
    return color .. label .. "|r"
end





local function CollectDefs(getChars)
    local playerClass = select(2, UnitClass("player"))
    local defs = {
        { value = "all", label = _G["ALL"] or ns.L["BANK_SCOPE_ALL"] },
        { value = "current", label = ns.PlayerName() or "?", class = playerClass },
    }

    local chars = getChars and getChars()
    if type(chars) ~= "table" then return defs end

    local currentKey = ns.CurrentCharacterKey()
    local others = {}
    for charKey, record in pairs(chars) do
        if charKey ~= currentKey and type(record) == "table" then
            others[#others + 1] = {
                value = charKey,
                label = record.name or charKey,
                class = record.class,
            }
        end
    end
    tsort(others, ByLabel)
    for i = 1, #others do defs[#defs + 1] = others[i] end
    return defs
end








function Filters:BuildCharacterScopeSelector(opts)
    local getChars = opts.getChars
    local getValue = opts.getValue
    local setValue = opts.setValue

    local popup = CreateFrame("Frame", opts.name, UIParent, "BackdropTemplate")
    popup:SetFrameStrata("TOOLTIP")
    opts.stylePopup(popup)
    popup:EnableMouse(true)
    popup:EnableMouseWheel(true)
    popup:Hide()

    local rows = {}
    local defs = {}
    local scrollOffset = 0
    local setLabel
    local Refresh

    local function MaxOffset()
        local overflow = #defs - MAX_VISIBLE_ROWS
        return overflow > 0 and overflow or 0
    end

    local thumb = popup:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(0.5, 0.5, 0.5, 0.6)
    thumb:SetWidth(3)
    thumb:Hide()

    local function PaintRows()
        local value = getValue()
        local visible = #defs < MAX_VISIBLE_ROWS and #defs or MAX_VISIBLE_ROWS
        for i = 1, visible do
            local def = defs[i + scrollOffset]
            local row = rows[i]
            row._value = def.value
            row._label:SetText(Colored(def.label, def.class))
            row._radio:SetTexture(def.value == value and ns.RADIO_ON_TEX or ns.RADIO_OFF_TEX)
            row:Show()
        end
        for i = visible + 1, #rows do rows[i]:Hide() end

        local maxOffset = MaxOffset()
        if maxOffset == 0 then
            thumb:Hide()
            return
        end
        local trackH = visible * ROW_H
        local thumbH = trackH * visible / #defs
        thumb:SetHeight(thumbH)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -3,
            -6 - (trackH - thumbH) * scrollOffset / maxOffset)
        thumb:Show()
    end

    local function AcquireRow(index)
        local row = rows[index]
        if row then return row end
        row = CreateFrame("Button", nil, popup)
        row:SetSize(140, ROW_H)
        row:SetPoint("TOPLEFT", popup, "TOPLEFT", 8, -6 - (index - 1) * ROW_H)

        local radio = row:CreateTexture(nil, "ARTWORK")
        radio:SetSize(14, 14)
        radio:SetPoint("LEFT", 0, 0)
        radio:SetTexture(ns.RADIO_OFF_TEX)

        local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        ns.ShadeText(label)
        label:SetPoint("LEFT", radio, "RIGHT", 4, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)

        row._radio = radio
        row._label = label
        Utils.InstallMenuRowHighlight(row)
        row:SetScript("OnClick", function(self)
            setValue(self._value)
            popup:Hide()
            Refresh()
            if opts.onChange then opts.onChange() end
        end)
        rows[index] = row
        return row
    end

    popup:SetScript("OnMouseWheel", function(_, delta)
        local maxOffset = MaxOffset()
        if maxOffset == 0 then return end
        local next = scrollOffset - delta
        if next < 0 then next = 0 elseif next > maxOffset then next = maxOffset end
        if next == scrollOffset then return end
        scrollOffset = next
        PaintRows()
    end)



    local function Rebuild()
        defs = CollectDefs(getChars)
        local value = getValue()
        scrollOffset = 0
        for i = 1, #defs do
            if defs[i].value == value and i > MAX_VISIBLE_ROWS then
                scrollOffset = i - MAX_VISIBLE_ROWS
            end
        end

        local visible = #defs < MAX_VISIBLE_ROWS and #defs or MAX_VISIBLE_ROWS
        local contentW = 0
        for i = 1, visible do
            local row = AcquireRow(i)
            row._label:SetText(Colored(defs[i].label, defs[i].class))
            local w = Utils.FlyoutRowContentWidth(row, 14 + 4)
            if w > contentW then contentW = w end
        end
        local popupW = Utils.FlyoutWidthFor(contentW, 8)
        for i = 1, visible do rows[i]:SetWidth(popupW - 16) end
        popup:SetSize(popupW, visible * ROW_H + 12)
        PaintRows()
    end

    local btn
    btn, setLabel = Utils.CreateDropdownButton({
        parent = opts.parent,
        x = opts.x or 0,
        y = opts.y or 0,
        width = opts.width,
        height = opts.height or 27,
        popup = popup,
        layout = function()
            Rebuild()
            if btn then popup:SetFrameLevel(btn:GetFrameLevel() + 20) end
        end,
        getScale = opts.getScale or function() return EasyFind.db.uiSearchScale or 1.0 end,
        guardFrames = opts.guardFrames,
    })




    if opts.branchPopups then
        opts.branchPopups[#opts.branchPopups + 1] = popup
    end

    Refresh = function()
        local value = getValue()
        if value == "all" then
            setLabel(_G["ALL"] or ns.L["BANK_SCOPE_ALL"])
            return
        end
        if value == "current" then
            setLabel(Colored(ns.PlayerName() or "?", select(2, UnitClass("player"))))
            return
        end
        local chars = getChars and getChars()
        local record = type(chars) == "table" and chars[value]
        if record then
            setLabel(Colored(record.name or value, record.class))
            return
        end


        setLabel(Colored(ns.PlayerName() or "?", select(2, UnitClass("player"))))
    end
    Refresh()

    return { button = btn, popup = popup, Refresh = Refresh }
end
