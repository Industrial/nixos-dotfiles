local _, ns = ...



















local Utils = ns.Utils

local CreateFrame = CreateFrame
local UIParent = UIParent
local ipairs = ipairs
local pairs = pairs

local ROW_H = 22
local PAD = 6
local SEP_H = 9
local TITLE_H = 18
local CHECK_SIZE = 16
local BAR_ROOM = 8

local popups = {}

local function EnsurePopup(name)
    local popup = popups[name]
    if popup then return popup end
    popup = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    popup:SetFrameStrata("TOOLTIP")
    popup:SetFrameLevel(9500)
    popup:EnableMouse(true)
    ns.StyleMenuPanel(popup)


    popup.scroll = CreateFrame("ScrollFrame", nil, popup)
    popup.scroll:SetPoint("TOPLEFT", popup, "TOPLEFT", 0, -PAD)
    popup.scroll:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", 0, PAD)
    popup.body = CreateFrame("Frame", nil, popup.scroll)
    popup.body:SetSize(1, 1)
    popup.scroll:SetScrollChild(popup.body)
    popup.bar = Utils.CreateMinimalScrollBar(popup.scroll, popup)
    popup.checkRows, popup.plainRows, popup.seps, popup.titles = {}, {}, {}, {}
    popup.live = {}


    popup.measure = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    popup.measure:Hide()


    popup.MenuFont = function(fs)
        local Results = ns.Results
        if not (Results and Results.SetScaledFont) then return end
        local theme = Results.GetActiveTheme and Results:GetActiveTheme()
        Results:SetScaledFont(fs, (theme and theme.pathFont) or ns.LEAF_FONT)
    end



    Utils.RegisterClickGuard(popup)
    popup:Hide()


    Utils.AttachEscClose(popup)
    popup:HookScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
    popup:HookScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        local fly = self.flyout
        if fly and fly._togglePopup == self and fly:IsShown() then fly:Hide() end
    end)






    popup:SetScript("OnEvent", function(self, event)
        if event ~= "GLOBAL_MOUSE_DOWN" then return end
        if Utils.IsFrameVisiblyMouseOver(self) then return end
        if self.anchor and Utils.IsFrameVisiblyMouseOver(self.anchor) then return end
        if Utils.IsCursorMenuMouseOver and Utils.IsCursorMenuMouseOver() then return end
        self:Hide()
    end)
    popups[name] = popup
    return popup
end



local function FlyoutRows(popup, def)
    local rows = {}
    for i, r in ipairs(type(def.rows) == "function" and def.rows() or def.rows) do
        local onClick = r.onClick
        if onClick and not r.keepOpen then
            local pick = {}
            for k, v in pairs(r) do pick[k] = v end
            pick.onClick = function()
                popup:Hide()
                onClick()
            end
            r = pick
        end
        rows[i] = r
    end
    return rows
end



local function OpenFlyout(popup, row)
    local fly = popup.flyout
    if fly and fly:IsShown() and fly._togglePopup == popup and fly._togglePopupRow == row then return end
    local def = row.def
    fly = Utils.ShowCursorMenu("EasyFindTogglePopupFlyout", FlyoutRows(popup, def), {
        anchorBeside = row, stayOpen = true, scale = popup:GetScale(), iconSide = "left",
        strata = popup:GetFrameStrata(), level = popup:GetFrameLevel() + 20,

        rowsProvider = function() return FlyoutRows(popup, def) end,
    })
    if fly then fly._togglePopup, fly._togglePopupRow = popup, row end
    popup.flyout = fly
end

local function RowEntered(popup, row)
    if row.def and (row.def.kind == "submenu" or row.def.rows) then
        OpenFlyout(popup, row)
        return
    end
    local fly = popup.flyout
    if fly and fly._togglePopup == popup and fly:IsShown() then fly:Hide() end


    local tip = row.def and row.def.tooltip
    if tip then ns.ShowHintTooltip(row, "ANCHOR_RIGHT", row.def.label, tip) end
end

local function RowLeft(popup, row)
    ns.HideHintTooltip(row)
end

local function MakeCheckRow(popup)
    local row = CreateFrame("CheckButton", nil, popup.body)
    row:SetHeight(ROW_H)
    Utils.SetCheckboxTextures(row, CHECK_SIZE)
    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row.label:SetPoint("LEFT", row:GetNormalTexture(), "RIGHT", 4, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row._label = row.label
    Utils.InstallMenuRowHighlight(row)
    row:HookScript("OnEnter", function(self) RowEntered(popup, self) end)
    row:HookScript("OnLeave", function(self) RowLeft(popup, self) end)
    row:SetScript("OnClick", function(self)
        local def = self.def
        if not def then return end
        local v = self:GetChecked() and true or false
        if def.set then def.set(v) end
        self:SetChecked(def.get and def.get() and true or false)

        local fly = popup.flyout
        if def.rows and fly and fly:IsShown() and fly._togglePopupRow == self then
            fly:Hide()
            OpenFlyout(popup, self)
        end
    end)
    return row
end

local function MakePlainRow(popup)
    local row = CreateFrame("Button", nil, popup.body)
    row:SetHeight(ROW_H)
    row.bullet = row:CreateTexture(nil, "ARTWORK")
    row.bullet:SetAtlas("common-dropdown-tickradial")
    row.bullet:SetSize(14, 14)
    row.bullet:SetPoint("LEFT", 4, 0)
    row.tick = row:CreateTexture(nil, "OVERLAY")
    row.tick:SetAtlas("common-dropdown-icon-radialtick-yellow")
    row.tick:SetSize(14, 14)
    row.tick:SetPoint("LEFT", 4, 0)
    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row._label = row.label
    row._dimTex = { row.bullet, row.tick }
    Utils.InstallMenuRowHighlight(row)
    row:HookScript("OnEnter", function(self) RowEntered(popup, self) end)
    row:HookScript("OnLeave", function(self) RowLeft(popup, self) end)
    row:SetScript("OnClick", function(self)
        local def = self.def
        if not def then return end
        if def.kind == "submenu" or def.kind == "menu" then
            OpenFlyout(popup, self)
        elseif def.kind == "radio" then
            if def.set then def.set(def.value) end
            ns.RefreshTogglePopup(popup)
        elseif def.kind == "action" then
            popup:Hide()
            if def.onClick then def.onClick() end
        end
    end)
    return row
end



function ns.HideAllTogglePopups()
    local any = false
    for _, popup in pairs(popups) do
        if popup:IsShown() then
            popup:Hide()
            any = true
        end
    end
    return any
end


function ns.HideTogglePopup(name)
    local popup = popups[name]
    if popup and popup:IsShown() then popup:Hide() end
end


function ns.RefreshTogglePopup(popup)
    for _, row in ipairs(popup.live) do
        local def = row.def
        if def then
            if def.kind == "check" then
                row:SetChecked(def.get and def.get() and true or false)
            elseif def.kind == "radio" then
                row.tick:SetShown(def.get and def.get() == def.value)
            end
        end
    end
end

function ns.ShowTogglePopup(name, anchor, defs, opts)
    opts = opts or {}
    local popup = EnsurePopup(name)
    if popup:IsShown() and popup.anchor == anchor then
        popup:Hide()
        return
    end
    popup.anchor = anchor
    for _, r in ipairs(popup.checkRows) do r:Hide() end
    for _, r in ipairs(popup.plainRows) do r:Hide() end
    for _, s in ipairs(popup.seps) do s:Hide() end
    for _, t in ipairs(popup.titles) do t:Hide() end
    local live = popup.live
    for i = #live, 1, -1 do live[i] = nil end


    local widest = 0
    popup.MenuFont(popup.measure)
    for _, def in ipairs(defs) do
        if def.kind ~= "separator" then
            popup.measure:SetText(def.label or "")
            local w = popup.measure:GetStringWidth() or 0
            if def.kind == "submenu" or def.rows then w = w + 18 end
            widest = math.max(widest, w)
        end
    end
    local width = math.max(opts.width or 0, math.ceil(PAD * 2 + 4 + CHECK_SIZE + 6 + widest + 10))
    local contentH = 0
    for _, def in ipairs(defs) do
        contentH = contentH + (def.kind == "separator" and SEP_H or def.kind == "title" and TITLE_H or ROW_H)
    end
    local viewH = math.min(contentH, Utils.MENU_MAX_ROWS * ROW_H)
    local scrolls = contentH > viewH
    if scrolls then width = width + BAR_ROOM end
    local body, right = popup.body, scrolls and -(PAD + BAR_ROOM) or -PAD
    local y, pickedY = 0, nil
    local nCheck, nPlain, nSep, nTitle = 0, 0, 0, 0
    for _, def in ipairs(defs) do
        if def.kind == "separator" then
            nSep = nSep + 1
            local sep = popup.seps[nSep]
            if not sep then
                sep = body:CreateTexture(nil, "ARTWORK")
                sep:SetHeight(1)
                sep:SetColorTexture(1, 1, 1, 0.12)
                popup.seps[nSep] = sep
            end
            sep:ClearAllPoints()
            sep:SetPoint("TOPLEFT", body, "TOPLEFT", PAD + 2, y - SEP_H / 2)
            sep:SetPoint("RIGHT", body, "RIGHT", right - 2, 0)
            sep:Show()
            y = y - SEP_H
        elseif def.kind == "title" then

            nTitle = nTitle + 1
            local fs = popup.titles[nTitle]
            if not fs then
                fs = body:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
                fs:SetJustifyH("LEFT")
                ns.ShadeText(fs)
                fs._efOwnColor = true
                popup.titles[nTitle] = fs
            end
            fs:SetText(def.label or "")
            if ns.TooltipTextColor then fs:SetTextColor(ns.TooltipTextColor()) end
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", body, "TOPLEFT", PAD + 8, y - 3)
            fs:Show()
            y = y - TITLE_H
        else
            local row
            if def.kind == "check" then
                nCheck = nCheck + 1
                row = popup.checkRows[nCheck]
                if not row then
                    row = MakeCheckRow(popup)
                    popup.checkRows[nCheck] = row
                end
                row:SetChecked(def.get and def.get() and true or false)

                row.label:SetPoint("RIGHT", row, "RIGHT", def.rows and -20 or -2, 0)
                if def.rows and not row.chevron then
                    row.chevron = row:CreateTexture(nil, "OVERLAY")
                    row.chevron:SetSize(12, 12)
                    row.chevron:SetPoint("RIGHT", row, "RIGHT", -6, 0)
                    Utils.SetChevronTexture(row.chevron)
                end
                if row.chevron then row.chevron:SetShown(def.rows ~= nil) end
            else
                nPlain = nPlain + 1
                row = popup.plainRows[nPlain]
                if not row then
                    row = MakePlainRow(popup)
                    popup.plainRows[nPlain] = row
                end
                row.label:ClearAllPoints()
                row.label:SetPoint("RIGHT", row, "RIGHT", def.kind == "submenu" and -20 or -2, 0)
                if def.kind == "submenu" and not row.chevron then
                    row.chevron = row:CreateTexture(nil, "OVERLAY")
                    row.chevron:SetSize(12, 12)
                    row.chevron:SetPoint("RIGHT", row, "RIGHT", -6, 0)
                    Utils.SetChevronTexture(row.chevron)
                end
                if row.chevron then row.chevron:SetShown(def.kind == "submenu") end
                if def.kind == "radio" then
                    row.bullet:Show()
                    row.tick:SetShown(def.get and def.get() == def.value)
                    if row.tick:IsShown() and not pickedY then pickedY = -y end
                    row.label:SetPoint("LEFT", row.bullet, "RIGHT", 6, 0)
                else
                    row.bullet:Hide()
                    row.tick:Hide()
                    row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
                end
            end
            row.def = def
            popup.MenuFont(row.label)
            row.label:SetText(def.label or "")
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", body, "TOPLEFT", PAD, y)
            row:SetPoint("RIGHT", body, "RIGHT", right, 0)
            row:Show()
            live[#live + 1] = row
            y = y - ROW_H
        end
    end
    popup:SetSize(width, viewH + PAD * 2)
    body:SetSize(width, contentH)
    popup:SetScale(opts.scale or 1)
    Utils.RefreshMenuRowHighlights(popup, live)
    Utils.OpenFlyoutBeside(popup, anchor, 4)
    if ns.KeepTextShaded then ns.KeepTextShaded(popup) end



    if ns.RetintMenuText then ns.RetintMenuText(popup) end
    popup:Show()

    local scroll = 0
    if scrolls and pickedY and pickedY + ROW_H > viewH then
        scroll = math.min(contentH - viewH, pickedY - (viewH - ROW_H) / 2)
    end
    popup.scroll:SetVerticalScroll(scroll)
    popup.bar:SetShown(scrolls)

    if scrolls then
        popup.bar:UpdateThumb(contentH, viewH)
        popup.bar:NudgeVisible()
    end
    return popup
end
