local _, ns = ...

local Filters = ns.Filters
local Utils = ns.Utils

local CreateFrame = CreateFrame
local UIParent = UIParent
local ipairs = Utils.ipairs
local type = Utils.type













function Filters:BuildCheckboxOptionsPopup(sub, StylePopup, CHECK_SIZE)
    local ROW_H = 22
    local PAD = 6
    local popup = CreateFrame("Frame", "EasyFind" .. sub.key .. "OptionsPopup", UIParent, "BackdropTemplate")
    popup:SetFrameStrata("TOOLTIP")
    StylePopup(popup)
    popup:EnableMouse(true)
    popup:Hide()

    local function Resolve(v)
        if type(v) == "function" then return v() end
        return v
    end



    local measure = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    measure:Hide()
    local widest = 0
    for _, def in ipairs(sub.checkboxOptions) do
        for _, c in ipairs(def.choice or { def }) do
            measure:SetText(Resolve(c.label or c.header) or "")
            widest = math.max(widest, measure:GetStringWidth() or 0)
        end
    end
    local WIDTH = math.ceil(PAD * 2 + 4 + CHECK_SIZE + 4 + widest + 10)

    local rows = {}
    local y = -PAD
    local HEADER_H, SEP_H = 18, 9
    for _, def in ipairs(sub.checkboxOptions) do
        if def.separator then
            local line = popup:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(1, 1, 1, 0.12)
            line:SetHeight(1)
            line:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD + 4, y - 4)
            line:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -(PAD + 4), y - 4)
            y = y - SEP_H
        elseif def.header then
            local caption = popup:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
            caption:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD + 4, y - 4)
            caption:SetText(Resolve(def.header) or "")
            y = y - HEADER_H
        elseif def.choice then
            for _, c in ipairs(def.choice) do
                local row = CreateFrame("Button", nil, popup)
                row:SetSize(WIDTH - PAD * 2, ROW_H)
                row:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, y)
                local dot = row:CreateTexture(nil, "ARTWORK")
                dot:SetSize(CHECK_SIZE, CHECK_SIZE)
                dot:SetPoint("LEFT", 4, 0)
                local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                text:SetPoint("LEFT", dot, "RIGHT", 4, 0)
                text:SetPoint("RIGHT", row, "RIGHT", -2, 0)
                text:SetJustifyH("LEFT")
                text:SetWordWrap(false)
                row._label, row._dot, row.def, row.choiceDef, row.value = text, dot, c, def, c.value
                Utils.InstallMenuRowHighlight(row)
                row:SetScript("OnClick", function(self)
                    ns.Extensions.Run(def.set, self.value)
                    for i = 1, #rows do
                        if rows[i].choiceDef == def then
                            rows[i]._dot:SetTexture(rows[i].value == self.value and ns.RADIO_ON_TEX or ns.RADIO_OFF_TEX)
                        end
                    end
                end)
                if c.tooltip then
                    Utils.AttachDelayedTooltip(row, "ANCHOR_RIGHT", function()
                        return Resolve(c.label), Resolve(c.tooltip)
                    end)
                end
                rows[#rows + 1] = row
                y = y - ROW_H
            end
        else
        local row = CreateFrame("CheckButton", nil, popup)
        row:SetSize(WIDTH - PAD * 2, ROW_H)
        row:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, y)
        Utils.SetCheckboxTextures(row, CHECK_SIZE)
        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", row:GetNormalTexture(), "RIGHT", 4, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(false)
        row._label = text
        Utils.InstallMenuRowHighlight(row)
        row.def = def
        row:SetScript("OnClick", function(self)
            local value = self:GetChecked() and true or false
            if def.set then
                ns.Extensions.Run(def.set, value)
            else
                EasyFind.db[def.dbKey] = value
            end
            if def.onChange then def.onChange(value) end
        end)
        if def.tooltip then
            Utils.AttachDelayedTooltip(row, "ANCHOR_RIGHT", function()
                return Resolve(def.label), Resolve(def.tooltip)
            end)
        end
        rows[#rows + 1] = row
        y = y - ROW_H
        end
    end
    popup:SetSize(WIDTH, -y + PAD)

    local function sync()
        for i = 1, #rows do
            local def = rows[i].def
            rows[i]._label:SetText(Resolve(def.label) or "")
            if rows[i].choiceDef then
                local ok, value = ns.Extensions.Run(rows[i].choiceDef.get)
                rows[i]._dot:SetTexture(ok and value == rows[i].value and ns.RADIO_ON_TEX or ns.RADIO_OFF_TEX)
            elseif def.get then
                local ok, on = ns.Extensions.Run(def.get)
                rows[i]:SetChecked(ok and on and true or false)
            else
                rows[i]:SetChecked(EasyFind.db[def.dbKey] ~= false)
            end
        end
    end
    return popup, sync
end





function Filters:AttachListFlyout(row, dropdown, opt, ctx)
    local ROW_H, CHECK, PAD = ctx.rowHeight, ctx.checkSize, 8
    local root = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    root:SetFrameStrata("TOOLTIP")
    ctx.StylePopup(root)
    root:EnableMouse(true)
    root:Hide()
    ctx.dropdownGuardFrames[#ctx.dropdownGuardFrames + 1] = root

    local function Switches()
        local t = EasyFind.db[opt.flyoutDbTable]
        if type(t) ~= "table" then
            t = {}
            EasyFind.db[opt.flyoutDbTable] = t
        end
        return t
    end

    local pool = {}
    local function GetRow(i)
        local r = pool[i]
        if r then return r end
        r = CreateFrame("CheckButton", nil, root)
        r:SetSize(150, ROW_H)
        r:SetHitRectInsets(0, 0, 0, 0)
        Utils.SetCheckboxTextures(r, CHECK)
        local label = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", r:GetNormalTexture(), "RIGHT", 4, 0)
        label:SetPoint("RIGHT", r, "RIGHT", -4, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        r._label = label
        Utils.InstallMenuRowHighlight(r)
        r:SetScript("OnClick", function(self)
            Switches()[self._key] = Utils.OffOrNil(self:GetChecked())
            Filters:RerunActiveSearch()
        end)
        pool[i] = r
        return r
    end

    local function Layout()
        local list = opt.flyoutList() or {}
        local switches = Switches()
        local y, contentW = -PAD, 0
        for i = 1, #list do
            local r = GetRow(i)
            r._key = list[i].key
            r._label:SetText(list[i].label)
            r:SetChecked(switches[list[i].key] ~= false)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", PAD, y)
            r:Show()
            y = y - ROW_H
            local w = Utils.FlyoutRowContentWidth(r, CHECK + 4)
            if w > contentW then contentW = w end
        end
        for i = #list + 1, #pool do pool[i]:Hide() end
        local w = Utils.FlyoutWidthFor(contentW, PAD)
        for i = 1, #list do pool[i]:SetWidth(w - PAD * 2) end
        root:SetSize(w, -y + PAD)
    end
    root._efSync = Layout

    local hover = Utils.AttachHoverPopup(row, root, {
        onShow = function()
            ctx.SetActiveFlyout(root)
            Layout()
            root:SetScale(EasyFind.db.uiSearchScale or 1.0)
            Utils.OpenFlyoutBeside(root, row, 4)
            root:Show()
        end,
    })
    row.ShowFlyoutPopup = hover.Show
    ctx.AddPopupKeyboardNav(root, function()
        local rows = {}
        for i = 1, #pool do if pool[i]:IsShown() then rows[#rows + 1] = pool[i] end end
        return rows
    end)
    Filters.AttachOutsideClickClose(root, { onHide = function(self) ctx.ClearActiveFlyout(self) end })
    dropdown:HookScript("OnHide", function() root:Hide() end)
end
