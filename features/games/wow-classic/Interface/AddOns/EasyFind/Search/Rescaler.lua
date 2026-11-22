local _, ns = ...

local Rescaler = {}
ns.Rescaler = Rescaler

local Utils = ns.Utils
local L = ns.L
local sformat = Utils.sformat
local mmax, mmin, mfloor = Utils.mmax, Utils.mmin, Utils.mfloor
local SafeCallMethod = Utils.SafeCallMethod

local GOLD_COLOR = ns.GOLD_COLOR
local TOOLTIP_BORDER = ns.TOOLTIP_BORDER

local SMALL_HIGHLIGHT_FONT = _G["GameFontHighlightSmall"] or _G["GameFontNormalSmall"] or _G["GameFontNormal"]

local MIN_WIDTH = 250
local MAX_WIDTH = 600
local HANDLE_SIZE = 10
local GLOW_OUTSET = 6
local EDGE_HANDLE_INSET = 34
local PREVIEW_ROW_H = 26
local PREVIEW_PAD = 16
local PREVIEW_MAX_ROWS = 24


local MIN_HEIGHT = 40
local MAX_HEIGHT = 700
local MIN_BAR_HEIGHT = 24
local MAX_BAR_HEIGHT = 56
local DEFAULT_BAR_HEIGHT = ns.SEARCHBAR_HEIGHT
local ROWS_DEFAULT = 6

local activeMode = nil
local activeSearchBar = nil
local liveSearchBar = nil
local liveResultsFrame = nil
local liveContainerFrame = nil
local liveState = nil
local backdrop = nil
local barOverlay = nil
local donePanel = nil
local mockSearchBar = nil
local mockWindowFrame = nil
local previewResults = nil

local function GetResultsHeight()
    return (EasyFind.db.uiResultsRows or ROWS_DEFAULT) * ns.Results:GetRowUnitHeight()
end




local function SetResultsHeight(h)
    local unit = ns.Results:GetRowUnitHeight()
    local rows = mfloor(h / unit + 0.5)
    if rows < ns.RESULT_ROWS_MIN then rows = ns.RESULT_ROWS_MIN end
    if rows > ns.RESULT_ROWS_MAX then rows = ns.RESULT_ROWS_MAX end
    EasyFind.db.uiResultsRows = rows
end

local function GetDefaultResultsHeight()
    return ROWS_DEFAULT * ns.Results:GetRowUnitHeight()
end


local function RowsText()
    return tostring(EasyFind.db.uiResultsRows or ROWS_DEFAULT)
end

local function GetSearchBarHeight()

    local h = (ns.Search and ns.Search.GetSearchBarHeight and ns.Search:GetSearchBarHeight())
        or EasyFind.db.uiSearchBarHeight or DEFAULT_BAR_HEIGHT
    return mmax(MIN_BAR_HEIGHT, mmin(MAX_BAR_HEIGHT, h))
end

local function SetSearchBarHeight(h)
    h = mmax(MIN_BAR_HEIGHT, mmin(MAX_BAR_HEIGHT, mfloor(h + 0.5)))
    EasyFind.db.uiSearchBarHeight = h
end

local function GetFontScale()
    return EasyFind.db.fontSize or 1.0
end

local function ClampWidth(v)
    return mmax(MIN_WIDTH, mmin(MAX_WIDTH, v))
end

local function GetUnifiedWindowHeight()
    return GetSearchBarHeight() + GetResultsHeight()
end

local function GetScreenMaxWindowHeight(anchorAbove)
    if not activeSearchBar then return MAX_BAR_HEIGHT + MAX_HEIGHT end
    local available
    if anchorAbove then
        local screenTop = UIParent:GetTop() or UIParent:GetHeight()
        local barBottom = activeSearchBar:GetBottom() or (screenTop / 2)
        available = screenTop - barBottom - 16
    else
        available = (activeSearchBar:GetTop() or (UIParent:GetHeight() / 2)) - 16
    end
    local minTotal = MIN_BAR_HEIGHT + MIN_HEIGHT
    local maxTotal = MAX_BAR_HEIGHT + MAX_HEIGHT
    if available > 0 then
        return mmax(minTotal, mmin(maxTotal, mfloor(available)))
    end
    return maxTotal
end

local function SetUnifiedWindowHeight(totalH, barRatio, preview, heightBox, anchorAbove)
    local minTotal = MIN_BAR_HEIGHT + MIN_HEIGHT
    local maxTotal = GetScreenMaxWindowHeight(anchorAbove)
    totalH = mmax(minTotal, mmin(maxTotal, mfloor(totalH + 0.5)))

    local ratio = barRatio or (GetSearchBarHeight() / mmax(1, GetUnifiedWindowHeight()))
    local barH = mmax(MIN_BAR_HEIGHT, mmin(MAX_BAR_HEIGHT, totalH * ratio))
    if totalH - barH < MIN_HEIGHT then barH = totalH - MIN_HEIGHT end
    if totalH - barH > MAX_HEIGHT then barH = totalH - MAX_HEIGHT end
    barH = mmax(MIN_BAR_HEIGHT, mmin(MAX_BAR_HEIGHT, barH))

    local resultsH = mmax(MIN_HEIGHT, mmin(MAX_HEIGHT, totalH - barH))
    SetSearchBarHeight(barH)
    SetResultsHeight(resultsH)

    if mockSearchBar and mockSearchBar.SetMockBarHeight then
        mockSearchBar:SetMockBarHeight(GetSearchBarHeight())
    end
    if preview then preview:SetPreviewHeight(GetResultsHeight()) end
    if mockWindowFrame and mockWindowFrame.UpdateLayout then mockWindowFrame:UpdateLayout() end
    if heightBox and not heightBox:HasFocus() then
        heightBox:SetText(mfloor(GetUnifiedWindowHeight() + 0.5))
    end
end


local function RefreshMockLayout()
    if mockSearchBar and mockSearchBar.SetMockBarHeight then
        mockSearchBar:SetMockBarHeight(GetSearchBarHeight())
    end
    if previewResults then previewResults:SetPreviewHeight(GetResultsHeight()) end
    if mockWindowFrame and mockWindowFrame.UpdateLayout then mockWindowFrame:UpdateLayout() end
end



local function GetMaxResultsHeight(anchorAbove)
    return mmax(MIN_HEIGHT, GetScreenMaxWindowHeight(anchorAbove) - GetSearchBarHeight())
end


local function ApplyResultsHeight(resultsH, heightBox, anchorAbove)
    resultsH = mmax(MIN_HEIGHT, mmin(GetMaxResultsHeight(anchorAbove), mfloor(resultsH + 0.5)))
    SetResultsHeight(resultsH)
    RefreshMockLayout()
    if heightBox and not heightBox:HasFocus() then
        heightBox:SetText(RowsText())
    end
end

local function AddResetButton(editBox, onConfirm)
    local btn = CreateFrame("Button", nil, editBox:GetParent())
    btn:SetSize(editBox:GetWidth(), 16)
    btn:SetPoint("TOP", editBox, "BOTTOM", 0, -2)
    btn:SetFrameLevel(editBox:GetFrameLevel() + 1)

    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    text:SetPoint("CENTER")
    text:SetText(_G["RESET"] or "Reset")
    text:SetTextColor(1, 1, 1, 1)

    btn:SetScript("OnEnter", function(self)
        text:SetTextColor(Utils.RGB(GOLD_COLOR, 1))
    end)
    btn:SetScript("OnLeave", function(self)
        text:SetTextColor(1, 1, 1, 1)
    end)
    btn:SetScript("OnClick", function()
        local dialog = StaticPopup_Show("EASYFIND_RESET_FIELD", nil, nil, { callback = onConfirm })
        if dialog then
            dialog:SetFrameStrata("TOOLTIP")
        end
    end)

    editBox.resetBtn = btn
    return btn
end

StaticPopupDialogs["EASYFIND_RESET_FIELD"] = {
    text = L["PROMPT_RESET_FIELD"],
    button1 = _G["YES"] or "Yes",
    button2 = _G["NO"] or "No",
    OnAccept = function(self, data)
        if data and data.callback then data.callback() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function CreateDimLabel(parent, anchor, relPoint, xOff, yOff, prefix)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    Utils.ReleaseFocusOnOutsideClick(box)
    box:SetSize(50, 20)
    box:SetAutoFocus(false)
    box:SetMaxLetters(5)
    box:SetJustifyH("CENTER")
    box:SetFontObject(SMALL_HIGHLIGHT_FONT)

    if prefix then
        local pfx = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        pfx:SetPoint(anchor, parent, relPoint, xOff, yOff)
        pfx:SetText(prefix)
        pfx:SetTextColor(Utils.RGB(GOLD_COLOR, 0.7))
        box:SetPoint("LEFT", pfx, "RIGHT", 6, 0)
        box.prefix = pfx
    else
        box:SetPoint(anchor, parent, relPoint, xOff, yOff)
    end

    local suffix = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    suffix:SetPoint("LEFT", box, "RIGHT", 2, 0)
    suffix:SetText("px")
    suffix:SetTextColor(Utils.RGB(GOLD_COLOR, 0.7))
    box.suffix = suffix

    return box
end

local function CreateHandle(parent, point, xOff, yOff, cursor, isHorizontal)
    local handle = CreateFrame("Button", nil, parent)
    handle:SetFrameLevel(parent:GetFrameLevel() + 10)
    if isHorizontal then
        handle:SetSize(HANDLE_SIZE, 1)
        handle:SetPoint("TOP", parent, "TOP", 0, -EDGE_HANDLE_INSET)
        handle:SetPoint("BOTTOM", parent, "BOTTOM", 0, EDGE_HANDLE_INSET)
        if point == "LEFT" then
            handle:SetPoint("LEFT", parent, "LEFT", xOff, 0)
        else
            handle:SetPoint("RIGHT", parent, "RIGHT", xOff, 0)
        end
    else
        handle:SetHeight(HANDLE_SIZE)
        handle:SetPoint("LEFT", parent, "LEFT", EDGE_HANDLE_INSET, 0)
        handle:SetPoint("RIGHT", parent, "RIGHT", -EDGE_HANDLE_INSET, 0)
        handle:SetPoint(point, parent, point, 0, yOff)
    end
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")

    local tex = handle:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetColorTexture(Utils.RGB(GOLD_COLOR, 0))
    handle.hoverTex = tex

    handle:SetScript("OnEnter", function(self)
        self.hoverTex:SetColorTexture(Utils.RGB(GOLD_COLOR, 0.4))
    end)
    handle:SetScript("OnLeave", function(self)
        self.hoverTex:SetColorTexture(Utils.RGB(GOLD_COLOR, 0))
    end)

    return handle
end

local function CreateScaleHandle(parent, point, xOff, yOff, flipH, flipV)
    local handle = CreateFrame("Button", nil, parent)
    handle:SetSize(22, 22)
    handle:SetPoint(point, parent, point, xOff, yOff)
    handle:SetFrameLevel(parent:GetFrameLevel() + 20)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")

    local texLeft = flipH and 1 or 0
    local texRight = flipH and 0 or 1
    local texTop = flipV and 1 or 0
    local texBottom = flipV and 0 or 1

    handle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    handle:GetNormalTexture():SetTexCoord(texLeft, texRight, texTop, texBottom)
    handle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    handle:GetHighlightTexture():SetTexCoord(texLeft, texRight, texTop, texBottom)
    handle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    handle:GetPushedTexture():SetTexCoord(texLeft, texRight, texTop, texBottom)

    return handle
end

local function CreateGlowOverlay(name, parent, target)
    local glow = CreateFrame("Frame", name, parent, "BackdropTemplate")
    glow:SetFrameStrata("FULLSCREEN_DIALOG")
    glow:SetFrameLevel(200)
    glow:EnableMouse(false)

    glow:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = TOOLTIP_BORDER,
        edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    glow:SetBackdropColor(Utils.RGB(GOLD_COLOR, 0.15))
    glow:SetBackdropBorderColor(Utils.RGB(GOLD_COLOR, 1.0))

    return glow
end

local CreateModernButton = ns.CreateModernButton

local function CreatePreviewResults(parent, targetFrame, width, heightPx, anchorAbove, leftAligned, flushDock)
    local fontScale = GetFontScale()
    local rowH = PREVIEW_ROW_H * fontScale
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(190)
    frame:SetWidth(width)
    frame:SetHeight(heightPx)

    local gap = flushDock and 0 or 2
    if leftAligned then
        if anchorAbove then
            frame:SetPoint("BOTTOMLEFT", targetFrame, "TOPLEFT", 0, gap)
        else
            frame:SetPoint("TOPLEFT", targetFrame, "BOTTOMLEFT", 0, -gap)
        end
    else
        if anchorAbove then
            frame:SetPoint("BOTTOM", targetFrame, "TOP", 0, gap)
        else
            frame:SetPoint("TOP", targetFrame, "BOTTOM", 0, -gap)
        end
    end

    if flushDock then
        frame:SetBackdrop(nil)
    else
        frame:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = TOOLTIP_BORDER,
            tile = true, tileSize = 32, edgeSize = 16,
            insets   = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        frame:SetBackdropColor(0.1, 0.1, 0.1, 0.85)
    end
    frame:SetClipsChildren(true)

    local nVisible = mfloor((heightPx - PREVIEW_PAD) / rowH)
    frame.rows = {}
    for i = 1, PREVIEW_MAX_ROWS do
        local row = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        row:SetPoint("LEFT", frame, "LEFT", 12, 0)
        row:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
        local y = -8 - (i - 1) * rowH
        row:SetPoint("TOP", frame, "TOP", 0, y)
        row:SetHeight(rowH)
        row:SetJustifyH("LEFT")
        row:SetJustifyV("TOP")
        row:SetText("|cff666666" .. sformat(L["RESCALE_SAMPLE_RESULT"], i) .. "|r")
        if fontScale ~= 1.0 then
            local path, baseSize, flags = GameFontDisable:GetFont()
            row:SetFont(path, baseSize * fontScale, flags)
        end
        row:SetShown(i <= nVisible)
        frame.rows[i] = row
    end

    frame.SetPreviewHeight = function(self, h)
        h = mmax(MIN_HEIGHT, mmin(MAX_HEIGHT, mfloor(h + 0.5)))
        self:SetHeight(h)
        local scaledRowH = PREVIEW_ROW_H * GetFontScale()
        local nVis = mfloor((h - PREVIEW_PAD) / scaledRowH)
        for i = 1, PREVIEW_MAX_ROWS do
            self.rows[i]:SetShown(i <= nVis)
        end
    end

    frame.UpdatePreviewFont = function(self)
        local scale = GetFontScale()
        local path, baseSize, flags = GameFontDisable:GetFont()
        local scaledRowH = PREVIEW_ROW_H * scale
        local h = GetResultsHeight()
        local nVis = mfloor((h - PREVIEW_PAD) / scaledRowH)
        for i = 1, PREVIEW_MAX_ROWS do
            local row = self.rows[i]
            row:SetFont(path, baseSize * scale, flags)
            row:SetHeight(scaledRowH)
            row:ClearAllPoints()
            row:SetPoint("LEFT", self, "LEFT", 12, 0)
            row:SetPoint("RIGHT", self, "RIGHT", -12, 0)
            row:SetPoint("TOP", self, "TOP", 0, -8 - (i - 1) * scaledRowH)
            row:SetShown(i <= nVis)
        end
        self:SetHeight(h)
    end

    return frame
end

local function CreateMockSearchBar(parent, liveBar, centerX, centerY)
    local barH = GetSearchBarHeight()
    local width = ClampWidth((liveBar and liveBar.GetWidth and liveBar:GetWidth()) or (250 * (EasyFind.db.uiSearchWidth or 1.0)))

    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(190)
    frame:SetSize(width, barH)
    frame:EnableMouse(false)

    local cx, cy = centerX, centerY
    if (not cx or not cy) and liveBar and liveBar.GetCenter then
        cx, cy = liveBar:GetCenter()
    end
    if not cx or not cy then
        local parentW = UIParent:GetWidth() or 0
        local parentH = UIParent:GetHeight() or 0
        cx, cy = parentW / 2, parentH * (2 / 3)
    end
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)

    frame:SetBackdrop(nil)

    local contentSz = barH * (ns.SEARCHBAR_FILL)
    local iconSz = contentSz * (ns.SEARCHBAR_ICON_SCALE)

    local iconHolder = CreateFrame("Frame", nil, frame)
    iconHolder:SetPoint("TOP", frame, "TOP", 0, 0)
    iconHolder:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
    iconHolder:SetPoint("LEFT", frame, "LEFT", 0, 0)
    iconHolder:SetWidth(barH)
    frame.iconHolder = iconHolder

    local icon = iconHolder:CreateTexture(nil, "OVERLAY")
    icon:SetSize(iconSz, iconSz)
    icon:SetPoint("CENTER")
    icon:SetAtlas("common-search-magnifyingglass")
    icon:SetAlpha(0.9)
    frame.searchIcon = icon

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    text:SetPoint("LEFT", iconHolder, "RIGHT", 0, 0)
    text:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    text:SetJustifyH("LEFT")
    text:SetText(_G["SEARCH"] or "Search")
    text:SetTextColor(0.55, 0.55, 0.58, 1)
    frame.placeholder = text

    frame.SetMockBarHeight = function(self, h)
        h = mmax(MIN_BAR_HEIGHT, mmin(MAX_BAR_HEIGHT, h or DEFAULT_BAR_HEIGHT))
        self:SetHeight(h)
        if self.iconHolder then self.iconHolder:SetWidth(h) end
        local contentSz = h * (ns.SEARCHBAR_FILL)
        local iconSz = contentSz * (ns.SEARCHBAR_ICON_SCALE)
        if self.searchIcon then self.searchIcon:SetSize(iconSz, iconSz) end
        if mockWindowFrame and mockWindowFrame.UpdateLayout then mockWindowFrame:UpdateLayout() end
    end

    return frame
end

local function CreateMockWindowFrame(parent, searchBar, preview, anchorAbove)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(188)
    frame:EnableMouse(false)
    if anchorAbove then
        frame:SetPoint("TOPLEFT", preview, "TOPLEFT", 0, 0)
        frame:SetPoint("TOPRIGHT", preview, "TOPRIGHT", 0, 0)
        frame:SetPoint("BOTTOMLEFT", searchBar, "BOTTOMLEFT", 0, 0)
        frame:SetPoint("BOTTOMRIGHT", searchBar, "BOTTOMRIGHT", 0, 0)
    else
        frame:SetPoint("TOPLEFT", searchBar, "TOPLEFT", 0, 0)
        frame:SetPoint("TOPRIGHT", searchBar, "TOPRIGHT", 0, 0)
        frame:SetPoint("BOTTOMLEFT", preview, "BOTTOMLEFT", 0, 0)
        frame:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", 0, 0)
    end
    ns.CreateRoundedRectBorder(frame)
    ns.CreateRoundedRectDivider(frame)
    ns.SetRoundedRectBarHeight(frame, searchBar:GetHeight())
    ns.SetRoundedRectBorderFillColor(frame, Utils.RGB(ns.SEARCH_WINDOW_FILL_COLOR, 1))
    ns.SetRoundedRectBorderBgAlpha(frame, ns.GetSearchWindowAlpha())

    frame.UpdateLayout = function(self)
        local dividerOffset = anchorAbove and preview:GetHeight() or searchBar:GetHeight()
        ns.SetRoundedRectBarHeight(self, searchBar:GetHeight())
        ns.SetRoundedRectDivider(self, dividerOffset, true)
    end
    frame:UpdateLayout()

    return frame
end

local function WireDimLabel(box, getter, setter)
    box:SetText(mfloor(getter() + 0.5))
    box:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then
            setter(val)
            self:SetText(mfloor(getter() + 0.5))
        end
        self:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText(mfloor(getter() + 0.5))
        self:ClearFocus()
    end)
end

local function SetupWidthDrag(handle, getWidth, setWidth, widthLabel, side)
    handle:SetScript("OnDragStart", function(self)
        self.dragging = true
        local cx = GetCursorPosition()
        self.lastX = cx / UIParent:GetEffectiveScale()
    end)
    handle:SetScript("OnDragStop", function(self)
        self.dragging = false
        self.lastX = nil
    end)
    handle:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local cx = GetCursorPosition()
        cx = cx / UIParent:GetEffectiveScale()
        if self.lastX then
            local dx = cx - self.lastX
            if side == "LEFT" then dx = -dx end

            local newW = ClampWidth(getWidth() + dx * 2)
            setWidth(newW)
            if widthLabel and not widthLabel:HasFocus() then
                widthLabel:SetText(mfloor(newW + 0.5))
            end
        end
        self.lastX = cx
    end)
end

local function SetupHeightDrag(handle, heightBox, anchorAbove)
    handle:SetScript("OnDragStart", function(self)
        self.dragging = true
        local _, cy = GetCursorPosition()
        self.startY = cy / UIParent:GetEffectiveScale()
        self.startResultsH = GetResultsHeight()
    end)
    handle:SetScript("OnDragStop", function(self)
        self.dragging = false
    end)
    handle:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local _, cy = GetCursorPosition()
        cy = cy / UIParent:GetEffectiveScale()
        local dy = self.startY - cy
        if anchorAbove then dy = -dy end
        ApplyResultsHeight(self.startResultsH + dy, heightBox, anchorAbove)
    end)
end

local function SetupCornerDrag(handle, getWidth, setWidth, widthBox, heightBox, anchorAbove)
    handle:SetScript("OnDragStart", function(self)
        self.dragging = true
        local cx, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        self.startX = cx / scale
        self.startY = cy / scale
        self.startWidth = getWidth()
        self.startResultsH = GetResultsHeight()
    end)
    handle:SetScript("OnDragStop", function(self)
        self.dragging = false
    end)
    handle:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local cx, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale

        local newW = ClampWidth(self.startWidth + (cx - self.startX) * 2)
        setWidth(newW)
        if widthBox and not widthBox:HasFocus() then
            widthBox:SetText(mfloor(newW + 0.5))
        end

        local dy = self.startY - cy
        if anchorAbove then dy = -dy end
        ApplyResultsHeight(self.startResultsH + dy, heightBox, anchorAbove)
    end)
end

local function BuildUnifiedWindowOverlay(parent, searchBar, preview, anchorAbove)
    local overlay = CreateGlowOverlay("EasyFindRescaleWindowGlow", parent, searchBar)
    if anchorAbove then
        overlay:SetPoint("TOPLEFT", preview, "TOPLEFT", -GLOW_OUTSET, GLOW_OUTSET)
        overlay:SetPoint("TOPRIGHT", preview, "TOPRIGHT", GLOW_OUTSET, GLOW_OUTSET)
        overlay:SetPoint("BOTTOMLEFT", searchBar, "BOTTOMLEFT", -GLOW_OUTSET, -GLOW_OUTSET)
        overlay:SetPoint("BOTTOMRIGHT", searchBar, "BOTTOMRIGHT", GLOW_OUTSET, -GLOW_OUTSET)
    else
        overlay:SetPoint("TOPLEFT", searchBar, "TOPLEFT", -GLOW_OUTSET, GLOW_OUTSET)
        overlay:SetPoint("TOPRIGHT", searchBar, "TOPRIGHT", GLOW_OUTSET, GLOW_OUTSET)
        overlay:SetPoint("BOTTOMLEFT", preview, "BOTTOMLEFT", -GLOW_OUTSET, -GLOW_OUTSET)
        overlay:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", GLOW_OUTSET, -GLOW_OUTSET)
    end

    local widthBox = CreateDimLabel(overlay, "LEFT", "RIGHT", 8, 0, L["RESCALE_WIDTH"])
    overlay.widthBox = widthBox

    local resizeEdge = anchorAbove and "TOP" or "BOTTOM"
    local cornerPoint = anchorAbove and "TOPRIGHT" or "BOTTOMRIGHT"
    local flipV = anchorAbove

    overlay.leftHandle = CreateHandle(overlay, "LEFT", 0, 0, nil, true)
    overlay.rightHandle = CreateHandle(overlay, "RIGHT", 0, 0, nil, true)
    overlay.heightHandle = CreateHandle(overlay, resizeEdge, 0, 0, nil, false)
    overlay.scaleHandle = CreateScaleHandle(overlay, cornerPoint, 0, 0, false, flipV)

    local heightBox = CreateFrame("EditBox", nil, overlay, "InputBoxTemplate")
    Utils.ReleaseFocusOnOutsideClick(heightBox)
    heightBox:SetSize(50, 20)
    heightBox:SetAutoFocus(false)
    heightBox:SetMaxLetters(3)
    heightBox:SetJustifyH("CENTER")
    heightBox:SetFontObject(SMALL_HIGHLIGHT_FONT)

    local heightPfx = overlay:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    heightPfx:SetText(L["OPT_RESULT_ROWS"])
    heightPfx:SetTextColor(Utils.RGB(GOLD_COLOR, 0.7))
    if anchorAbove then
        heightPfx:SetPoint("BOTTOM", overlay, "TOP", 0, 4)
    else
        heightPfx:SetPoint("TOP", overlay, "BOTTOM", 0, -4)
    end
    heightBox:SetPoint("LEFT", heightPfx, "RIGHT", 6, 0)

    overlay.heightBox = heightBox
    overlay.heightPfx = heightPfx
    overlay.anchorAbove = anchorAbove

    return overlay
end

local function CreateDonePanel(parent)
    local BACK_W = 110
    local DONE_W = 80
    local BTN_GAP = 2
    local BTN_H = 22
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetSize(BACK_W + BTN_GAP + DONE_W, BTN_H)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetFrameLevel(209)

    local backBtn = CreateModernButton(panel, L["RESCALE_BACK_TO_OPTIONS"], BACK_W, BTN_H)
    backBtn:SetPoint("LEFT", panel, "LEFT", 0, 0)
    panel.backBtn = backBtn

    local doneBtn = CreateModernButton(panel, _G["DONE"] or "Done", DONE_W, BTN_H)
    doneBtn:SetPoint("LEFT", backBtn, "RIGHT", BTN_GAP, 0)
    panel.doneBtn = doneBtn

    return panel
end

local function GetOrCreateBackdrop()
    if backdrop then return backdrop end
    backdrop = CreateFrame("Frame", "EasyFindRescaleBackdrop", UIParent)
    backdrop:SetFrameStrata("FULLSCREEN")
    backdrop:SetAllPoints(UIParent)
    backdrop:EnableMouse(false)

    local tex = backdrop:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetColorTexture(0, 0, 0, 0.5)

    local SafeCallMethod = Utils.SafeCallMethod
    backdrop:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            SafeCallMethod(self, "SetPropagateKeyboardInput", false)
            Rescaler:Exit()
        else
            SafeCallMethod(self, "SetPropagateKeyboardInput", true)
        end
    end)


    return backdrop
end

function Rescaler:Enter(mode)
    if activeMode then
        self:Exit()
    end
    if mode ~= "ui" then return end

    activeMode = mode

    liveSearchBar = _G["EasyFindSearchFrame"]
    liveResultsFrame = _G["EasyFindResultsFrame"]
    liveContainerFrame = _G["EasyFindContainerFrame"]

    if not liveSearchBar then
        activeMode = nil
        return
    end

    liveState = {
        searchShown = liveSearchBar:IsShown(),
        searchAlpha = liveSearchBar:GetAlpha(),
        resultsShown = liveResultsFrame and liveResultsFrame:IsShown(),
        containerShown = liveContainerFrame and liveContainerFrame:IsShown(),
    }
    local liveCenterX, liveCenterY = liveSearchBar:GetCenter()
    if liveSearchBar.editBox then
        liveSearchBar.editBox:ClearFocus()
    end
    if liveResultsFrame then liveResultsFrame:Hide() end
    liveSearchBar:Hide()
    if liveContainerFrame then liveContainerFrame:Hide() end

    local function setUiWidth(w)
        w = ClampWidth(w)
        mockSearchBar:SetWidth(w)
        EasyFind.db.uiSearchWidth = w / 250
        EasyFind.db.uiResultsWidth = w
    end

    local getBarWidth = function() return mockSearchBar:GetWidth() end
    local setBarWidth = setUiWidth

    local optPanel = _G["EasyFindOptionsFrame"]
    if optPanel and optPanel:IsShown() then
        optPanel:Hide()
    end

    local bg = GetOrCreateBackdrop()
    bg:Show()
    SafeCallMethod(bg, "EnableKeyboard", true)

    mockSearchBar = CreateMockSearchBar(bg, liveSearchBar, liveCenterX, liveCenterY)
    mockSearchBar:Show()
    activeSearchBar = mockSearchBar

    local resultsAbove = EasyFind.db.uiResultsAbove
    local currentTotal = GetUnifiedWindowHeight()
    local currentRatio = GetSearchBarHeight() / mmax(1, currentTotal)
    SetUnifiedWindowHeight(mmin(currentTotal, GetScreenMaxWindowHeight(resultsAbove)), currentRatio, nil, nil, resultsAbove)
    local previewW = getBarWidth()
    local currentH = GetResultsHeight()
    previewResults = CreatePreviewResults(bg, mockSearchBar, previewW, currentH, resultsAbove, false, true)
    previewResults:Show()
    mockWindowFrame = CreateMockWindowFrame(bg, mockSearchBar, previewResults, resultsAbove)
    previewResults:HookScript("OnSizeChanged", function()
        if mockWindowFrame and mockWindowFrame.UpdateLayout then mockWindowFrame:UpdateLayout() end
    end)

    barOverlay = BuildUnifiedWindowOverlay(bg, mockSearchBar, previewResults, resultsAbove)
    barOverlay:Show()


    local resizeEdge = resultsAbove and barOverlay:GetTop() or barOverlay:GetBottom()
    local screenLimit = resultsAbove and UIParent:GetTop() or 0
    local nearEdge = resultsAbove and (resizeEdge and screenLimit and (screenLimit - resizeEdge) < 40)
        or (not resultsAbove and resizeEdge and resizeEdge < 40)
    if nearEdge then
        barOverlay.heightPfx:ClearAllPoints()
        if resultsAbove then
            barOverlay.heightPfx:SetPoint("TOPLEFT", barOverlay, "TOPLEFT", GLOW_OUTSET + 4, -8)
        else
            barOverlay.heightPfx:SetPoint("BOTTOMLEFT", barOverlay, "BOTTOMLEFT", GLOW_OUTSET + 4, 8)
        end
        barOverlay.heightInside = true
    end

    local function setBarWidthAndPreview(w)
        setBarWidth(w)
        previewResults:SetWidth(mockSearchBar:GetWidth())
    end
    SetupWidthDrag(barOverlay.leftHandle, getBarWidth, setBarWidthAndPreview, barOverlay.widthBox, "LEFT")
    SetupWidthDrag(barOverlay.rightHandle, getBarWidth, setBarWidthAndPreview, barOverlay.widthBox, "RIGHT")
    WireDimLabel(barOverlay.widthBox, getBarWidth, setBarWidthAndPreview)
    AddResetButton(barOverlay.widthBox, function()
        local defW = 250 * 1.54
        setBarWidthAndPreview(defW)
        barOverlay.widthBox:SetText(mfloor(defW + 0.5))
    end)

    barOverlay.heightBox:SetText(RowsText())
    barOverlay.heightBox:SetScript("OnEnterPressed", function(self)
        local rows = tonumber(self:GetText())
        if rows then
            ApplyResultsHeight(rows * ns.Results:GetRowUnitHeight(), nil, resultsAbove)
        end
        self:SetText(RowsText())
        self:ClearFocus()
    end)
    barOverlay.heightBox:SetScript("OnEscapePressed", function(self)
        self:SetText(RowsText())
        self:ClearFocus()
    end)
    local heightReset = AddResetButton(barOverlay.heightBox, function()
        ApplyResultsHeight(GetDefaultResultsHeight(), nil, resultsAbove)
        barOverlay.heightBox:SetText(RowsText())
    end)
    if barOverlay.anchorAbove then
        heightReset:ClearAllPoints()
        heightReset:SetPoint("BOTTOM", barOverlay.heightBox, "TOP", 0, 2)
    end
    if barOverlay.heightInside then
        heightReset:ClearAllPoints()
        if barOverlay.anchorAbove then
            heightReset:SetPoint("TOP", barOverlay.heightBox, "BOTTOM", 0, -2)
        else
            heightReset:SetPoint("BOTTOM", barOverlay.heightBox, "TOP", 0, 2)
        end
    end
    SetupCornerDrag(barOverlay.scaleHandle, getBarWidth, setBarWidthAndPreview, barOverlay.widthBox, barOverlay.heightBox, resultsAbove)
    SetupHeightDrag(barOverlay.heightHandle, barOverlay.heightBox, resultsAbove)

    donePanel = CreateDonePanel(bg)
    donePanel:SetPoint("TOP", barOverlay, "BOTTOM", 0, -50)
    donePanel.doneBtn:SetScript("OnClick", function()
        Rescaler:Exit()
    end)
    donePanel.backBtn:SetScript("OnClick", function()
        Rescaler:Exit(true)
    end)
    donePanel:Show()
end

function Rescaler:Exit(reopenOptions)
    if not activeMode then return end

    if barOverlay then
        if barOverlay.leftHandle then barOverlay.leftHandle:SetScript("OnUpdate", nil) end
        if barOverlay.rightHandle then barOverlay.rightHandle:SetScript("OnUpdate", nil) end
        if barOverlay.heightHandle then barOverlay.heightHandle:SetScript("OnUpdate", nil) end
        if barOverlay.scaleHandle then barOverlay.scaleHandle:SetScript("OnUpdate", nil) end
        barOverlay:Hide()
        barOverlay = nil
    end
    if previewResults then
        previewResults:Hide()
        previewResults = nil
    end
    if mockSearchBar then
        mockSearchBar:Hide()
        mockSearchBar = nil
    end
    if mockWindowFrame then
        mockWindowFrame:Hide()
        mockWindowFrame = nil
    end
    if donePanel then
        donePanel:Hide()
        donePanel = nil
    end
    if backdrop then
        SafeCallMethod(backdrop, "EnableKeyboard", false)
        backdrop:Hide()
    end

    if activeSearchBar then
        activeSearchBar.setupMode = nil
        activeSearchBar = nil
    end

    if liveSearchBar then
        liveSearchBar.setupMode = nil
        liveSearchBar:SetAlpha((liveState and liveState.searchAlpha) or 1)
        if liveState and liveState.searchShown then
            liveSearchBar:Show()
        else
            liveSearchBar:Hide()
        end
    end
    if liveResultsFrame then
        if liveState and liveState.resultsShown then liveResultsFrame:Show()
        else liveResultsFrame:Hide() end
    end
    if liveContainerFrame then
        if liveState and liveState.containerShown then liveContainerFrame:Show()
        else liveContainerFrame:Hide() end
    end

    if ns.Search then
        if ns.Search.UpdateScale then ns.Search:UpdateScale() end
        if ns.Search.UpdateWidth then ns.Search:UpdateWidth() end
        if ns.Search.UpdateSearchBarHeight then ns.Search:UpdateSearchBarHeight() end
        if ns.Search.RefreshResults then ns.Search:RefreshResults() end
    end

    liveSearchBar = nil
    liveResultsFrame = nil
    liveContainerFrame = nil
    liveState = nil
    activeMode = nil

    if reopenOptions then



        if EasyFind.OpenOptions then EasyFind:OpenOptions() end
    end
end

function Rescaler:IsActive()
    return activeMode ~= nil
end
