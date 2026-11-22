local _, ns = ...






local Search = ns.Search
local Results = ns.Results
local Render = ns.ResultRender
local Utils = ns.Utils
local Data = ns.CharacterData
local L = ns.L

local mfloor, mmax, mmin = Utils.mfloor, Utils.mmax, Utils.mmin
local sformat = Utils.sformat
local ipairs = Utils.ipairs
local wipe = wipe
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local IsShiftKeyDown, IsControlKeyDown = IsShiftKeyDown, IsControlKeyDown
local InCombatLockdown = InCombatLockdown
local GetItemCooldown = (C_Item and C_Item.GetItemCooldown) or (C_Container and C_Container.GetItemCooldown)
    or GetItemCooldown
local GetContainerItemID = C_Container and C_Container.GetContainerItemID
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local IsDressableItem = (C_Item and C_Item.IsDressableItemByID) or IsDressableItem

local CELL_GAP = 4
local SIDE_PAD = 10
local TEXT_STRIP_EXTRA = 14
local GLOW_TEX = "Interface\\Buttons\\UI-ActionButton-Border"
local CHIP_CLEAR = "  |TInterface\\AddOns\\EasyFind\\textures\\clear-button:0|t"

local host, page, slots
local gridCols, gridRows, rowH = 0, 0, 1


local lines, lineN = {}, 0

local flat, flatHeader, flatOwner = {}, {}, {}
local navFlat, navOfFlat, lineOfFlat = {}, {}, {}
local itemCount, totalCount = 0, 0
local rowOffset = 0
local navIndex = 0
local shownDef, shownQuery, shownPlace

local ownKey
local menuCell
local words, skip = {}, {}



local placeWords
local function PlaceOf(word)
    if not placeWords then
        placeWords = {}
        local function Add(text, place)
            if text and text ~= "" and not text:find("%s") then placeWords[Data.Fold(text)] = place end
        end
        Add("bag", "bags"); Add("bags", "bags"); Add(_G["BAGSLOT"], "bags")
        Add("bank", "bank"); Add(_G["BANK"], "bank")
        Add("warband", "warband"); Add("wb", "warband")
        Add("gear", "gear"); Add("equipped", "gear")
    end
    return placeWords[word]
end

local function AnyMatch(sections, place)
    for _, section in ipairs(sections) do
        for i = 1, #section.cells do
            local cell = section.cells[i]
            if cell and (not place or cell.place == place) and Data.MatchesAll(cell.folded, words, skip) then
                return true
            end
        end
    end
    return false
end



local function ReadQuery(sections, query)
    Data.Words(query, words)
    wipe(skip)
    for i = 1, #words do
        local place = PlaceOf(words[i])
        if place then
            if #words == 1 or not AnyMatch(sections) then
                skip[i] = true
                return place
            end
            return nil
        end
    end
    return nil
end



local function Line(n)
    local line = lines[n]
    if not line then
        line = {}
        lines[n] = line
    end
    line.header, line.hex, line.first, line.count = nil, nil, nil, nil
    return line
end

local function ClassHex(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not c then return nil end
    return sformat("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
end

local function Build(sections, query)
    local place = ReadQuery(sections, query)
    shownPlace = place
    local filtering = place ~= nil or #words > 0
    lineN = 0
    wipe(flat); wipe(flatHeader); wipe(flatOwner); wipe(navFlat); wipe(navOfFlat); wipe(lineOfFlat)
    itemCount, totalCount = 0, 0
    for _, section in ipairs(sections) do
        local start = #flat + 1
        for i = 1, #section.cells do
            local cell = section.cells[i]
            totalCount = totalCount + 1
            if not filtering or ((not place or cell.place == place) and Data.MatchesAll(cell.folded, words, skip)) then
                local f = #flat + 1
                flat[f] = cell
                flatHeader[f] = section.header
                flatOwner[f] = section.charKey
                itemCount = itemCount + 1
                navFlat[#navFlat + 1] = f
                navOfFlat[f] = #navFlat
            end
        end
        local count = #flat - start + 1
        if count > 0 then
            lineN = lineN + 1
            local head = Line(lineN)
            head.header = section.header or ""
            head.hex = ClassHex(section.class)
            for c = 0, count - 1, gridCols do
                lineN = lineN + 1
                local line = Line(lineN)
                line.first = start + c
                line.count = mmin(gridCols, count - c)
                for f = line.first, line.first + line.count - 1 do lineOfFlat[f] = lineN end
            end
        end
    end
end



local function CellLink(cell)
    if cell.link then return cell.link end
    return GetItemInfo and select(2, GetItemInfo(cell.itemID)) or nil
end

local function LinkInChat(cell)
    local link = CellLink(cell)
    if not link then return end
    if ChatEdit_InsertLink and ChatEdit_InsertLink(link) then return end
    local open = ChatFrame_OpenChat or (ChatFrameUtil and ChatFrameUtil.OpenChat)
    if open then open(link) end
end

local function TryOn(cell)
    local link = CellLink(cell)
    if link and DressUpItemLink then DressUpItemLink(link) end
end



local function IsOwn(btn)
    local owner = shownDef and shownDef.charKey or flatOwner[btn.flatIndex]
    return owner ~= nil and owner == ownKey
end

local function CellTooltip(btn)
    local cell = btn.cell
    if not cell then return end
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")


    if cell.place == "bags" and cell.bag and IsOwn(btn) and GameTooltip.SetBagItem
       and GetContainerItemID and GetContainerItemID(cell.bag, cell.slot) == cell.itemID then
        GameTooltip:SetBagItem(cell.bag, cell.slot)
    elseif cell.link and GameTooltip.SetHyperlink then
        GameTooltip:SetHyperlink(cell.link)
    elseif GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(cell.itemID)
    else
        GameTooltip:SetText(cell.name or "", 1, 1, 1)
    end
    local where = flatHeader[btn.flatIndex]
    if where and where ~= "" then
        if shownDef and not shownDef.charKey then where = where .. ", " .. Data.PlaceLabel(cell.place) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(where, 1, 0.82, 0)
    end
    GameTooltip:Show()
end

local Repaint

local function ShowCellMenu(btn, keyboardMode)
    local cell = btn.cell
    if not cell then return end
    local link = CellLink(cell)
    local rows = {}
    local sendRows = link and ns.BuildSendLinkRows and ns.BuildSendLinkRows(link)
    if sendRows then
        rows[#rows + 1] = { actionId = "send", text = L["CTX_SEND_LINK"], copy = Utils.ClipboardSafeText(link),
            copyLink = link, copyKey = "Ctrl+C", tooltip = L["COPY_ROW_TT"], submenu = sendRows }
    end
    if link and IsDressableItem and IsDressableItem(cell.itemID) then
        rows[#rows + 1] = { text = L["ITEM_GRID_TRY_ON"], onClick = function() TryOn(cell) end }
    end
    local item = { itemID = cell.itemID, name = cell.name }
    if ns.ItemSources and ns.ItemSources.Available(item) then
        rows[#rows + 1] = { text = L["HINT_SOURCES"], onClick = function() ns.ItemSources:Show(item) end }
    end
    local wowhead = ns.GetWowheadLink and ns.GetWowheadLink({ itemID = cell.itemID, category = "Item" })
    if wowhead then
        rows[#rows + 1] = { text = L["CTX_WOWHEAD"], icon = ns.LINK_ICON_TEX, chromeIcon = true,
            copy = wowhead, tooltip = L["COPY_ROW_TT"] }
    end
    if #rows == 0 then return end
    menuCell = btn
    btn:LockHighlight()
    if keyboardMode then Utils.SafeCallMethod(Search:GetNavFrame(), "EnableKeyboard", false) end
    Utils.ShowCursorMenu("EasyFindItemCellMenu", rows, {
        scale = EasyFind.db.uiSearchScale or 1.0,
        anchorFrame = keyboardMode and btn or nil,
        keyboardMode = keyboardMode or nil,
        onHide = function()
            if menuCell then
                menuCell:UnlockHighlight()
                menuCell = nil
            end
            if keyboardMode and navIndex > 0 and Search:GetSearchFrame() and Search:GetSearchFrame():IsShown() then
                Utils.SafeCallMethod(Search:GetNavFrame(), "EnableKeyboard", true)
            end
            if host and host:IsShown() then Repaint() end
        end,
    })
end

local function OnCellClick(btn, button)
    local cell = btn.cell
    if not cell then return end
    if button == "LeftButton" and IsShiftKeyDown() then
        LinkInChat(cell)
    elseif button == "LeftButton" and IsControlKeyDown() then
        TryOn(cell)
    else
        ShowCellMenu(btn)
    end
end

local function OnCellEnter(btn)
    CellTooltip(btn)
    if ns.RowCopy then ns.RowCopy:OnRowHover(btn) end
end

local usePad

local function OnCellLeave(btn)

    if usePad and usePad.btn == btn and usePad:IsShown() and usePad:IsMouseOver() then return end
    if GameTooltip:IsOwned(btn) then GameTooltip:Hide() end
    if ns.RowCopy then ns.RowCopy:OnRowHover(nil) end
end





local function UsableCell(btn)
    local cell = btn.cell
    if not (cell and cell.place == "bags" and cell.name) then return false end
    if not IsOwn(btn) then return false end
    local Handlers = ns.ResultHandlers
    local kind = Handlers and Handlers.GetBagItemActionKind
        and Handlers:GetBagItemActionKind({ itemID = cell.itemID, category = "Bag" })
    return kind ~= nil and kind ~= "show"
end

local function HidePad()
    if not (usePad and usePad:IsShown()) or InCombatLockdown() then return end
    usePad:Hide()
    usePad:ClearAllPoints()
    usePad.btn = nil
end





local function ArmPad(btn)
    if InCombatLockdown() then return end
    if not usePad then

        usePad = CreateFrame("Button", "EasyFindItemGridUse", UIParent, "SecureActionButtonTemplate")
        usePad:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonUp")
        usePad:SetAttribute("useOnKeyDown", true)
        usePad:SetScript("PreClick", function(self, button, down)
            if button ~= "LeftButton" or not down or InCombatLockdown() then return end

            self:SetAttribute("type", not (IsShiftKeyDown() or IsControlKeyDown()) and "item" or nil)
        end)
        usePad:SetScript("PostClick", function(self, button, down)
            local cellBtn = self.btn
            if not cellBtn then return end
            if button == "RightButton" or (not down and (IsShiftKeyDown() or IsControlKeyDown())) then
                OnCellClick(cellBtn, button)
            elseif down and not (IsShiftKeyDown() or IsControlKeyDown()) then

                Utils.SafeAfter(0.3, function()
                    if shownDef then
                        Data.Invalidate()
                        Results:ShowItemGrid(shownDef, shownQuery)
                    end
                end)
            end
        end)
        usePad:SetScript("OnEnter", function(self) if self.btn then OnCellEnter(self.btn) end end)
        usePad:SetScript("OnLeave", function(self)
            local cellBtn = self.btn
            HidePad()
            if cellBtn then OnCellLeave(cellBtn) end
        end)
        local combat = CreateFrame("Frame")
        combat:SetScript("OnEvent", HidePad)
        combat:RegisterEvent("PLAYER_REGEN_DISABLED")
        usePad:Hide()
    end
    usePad:ClearAllPoints()
    usePad:SetAllPoints(btn)
    usePad:SetFrameStrata(btn:GetFrameStrata())
    usePad:SetFrameLevel(btn:GetFrameLevel() + 2)
    usePad:SetAttribute("type", "item")
    usePad:SetAttribute("item", btn.cell.name)
    usePad.btn = btn
    usePad:Show()
end

local function OnCellHover(btn)
    OnCellEnter(btn)
    if UsableCell(btn) then ArmPad(btn) else HidePad() end
end

if ns.RowCopy and ns.RowCopy.RegisterHoverScanner then
    ns.RowCopy:RegisterHoverScanner(function()
        if not (host and host:IsVisible() and slots) then return nil end
        for _, slot in ipairs(slots) do
            for _, btn in ipairs(slot.cells) do
                if btn:IsShown() and btn.cell and btn:IsMouseOver() then return btn end
            end
        end
        return nil
    end)
end



local function PaintCooldown(btn)
    local cell = btn.cell
    local start, duration, enable
    if cell and GetItemCooldown and IsOwn(btn) then start, duration, enable = GetItemCooldown(cell.itemID) end
    if start and duration and duration > 0 and enable ~= 0 and enable ~= false then
        btn.cooldown:SetCooldown(start, duration)
    else
        btn.cooldown:Clear()
    end
end

local function PaintCell(btn, cell, f)
    btn.flatIndex = f
    btn.cell = cell
    btn.tex:SetTexture(cell.icon or 134400)
    btn.countText:SetText((cell.count or 1) > 1 and cell.count or "")
    local q = cell.quality
    local color = q and q >= 2 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if color then
        btn.glow:SetVertexColor(color.r, color.g, color.b, 0.9)
        btn.glow:Show()
    else
        btn.glow:Hide()
    end
    btn._efCopyText = cell.name
    PaintCooldown(btn)
    btn:Show()
    if btn:IsMouseOver() and GameTooltip:IsOwned(btn) then CellTooltip(btn) end
end

local function HeaderColor(fs)
    local theme = Results.GetActiveTheme and Results:GetActiveTheme()
    local c = theme and theme.pathColor
    if c then fs:SetTextColor(c[1], c[2], c[3], 1) else fs:SetTextColor(1, 0.82, 0, 1) end
end

function Repaint()

    HidePad()
    page:ClearAllPoints()
    page:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -rowOffset * rowH)
    local focusFlat = navIndex > 0 and navFlat[navIndex] or nil
    for s = 1, #slots do
        local slot = slots[s]
        local line = lines[rowOffset + s]
        if s > lineN - rowOffset then line = nil end
        if line and line.header then
            slot.header:SetText((line.hex or "") .. line.header .. (line.hex and "|r" or ""))
            HeaderColor(slot.header)
            slot.header:Show()
        else
            slot.header:Hide()
        end
        for c = 1, #slot.cells do
            local btn = slot.cells[c]
            if line and line.first and c <= line.count then
                local f = line.first + c - 1
                PaintCell(btn, flat[f], f)
                if btn ~= menuCell then
                    if f == focusFlat then btn:LockHighlight() else btn:UnlockHighlight() end
                end
            else
                btn.cell = nil
                btn:Hide()
            end
        end
    end
    local theme = Results.GetActiveTheme and Results:GetActiveTheme()
    local faint = theme and theme.lightTheme and theme.textFaint
    local r, g, b = 0.6, 0.6, 0.6
    if faint then r, g, b = faint[1], faint[2], faint[3] end
    host.countText:SetText(sformat("%d/%d", itemCount, totalCount))
    host.countText:SetTextColor(r, g, b, 0.9)
    if shownPlace then
        host.chip:SetText(Data.PlaceLabel(shownPlace) .. CHIP_CLEAR)
        host.chip:SetWidth((host.chip:GetFontString():GetStringWidth() or 0) + 4)
        host.chip:Show()
        host.hintText:Hide()
    else
        host.chip:Hide()
        if totalCount == 0 then
            host.hintText:SetText(shownDef and shownDef.gridKind == "gear" and L["ITEM_GRID_NO_GEAR"] or L["ITEM_GRID_EMPTY"])
        elseif itemCount == 0 then
            host.hintText:SetText(_G["BROWSE_NO_RESULTS"] or "No results found.")
        else
            host.hintText:SetText(L["ITEM_GRID_HINT"])
        end
        host.hintText:SetTextColor(r, g, b, 0.9)
        host.hintText:Show()
    end
end


local function DropPlaceWord()
    local editBox = Search:GetSearchFrame() and Search:GetSearchFrame().editBox
    if not editBox then return end
    local kept = {}
    for word in (editBox:GetText() or ""):gmatch("%S+") do
        if not PlaceOf(Data.Fold(word)) then kept[#kept + 1] = word end
    end
    local text = table.concat(kept, " ")
    if editBox.ResetPendingSearch then editBox:ResetPendingSearch() end
    editBox:SetText(text)
    editBox:SetCursorPosition(#text)
    Search:OnSearchTextChanged(text, true)
end

local function EnsureHost(resultsFrame)
    if host then return host end
    host = CreateFrame("Frame", "EasyFindItemGrid", resultsFrame.scrollChild)
    host:EnableMouse(true)
    page = CreateFrame("Frame", nil, host)
    page:SetSize(1, 1)
    host.countText = resultsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    host.countText._efOwnColor = true
    host.countText:Hide()
    host.hintText = resultsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    host.hintText._efOwnColor = true
    host.hintText:SetJustifyH("LEFT")
    host.hintText:SetWordWrap(false)
    host.hintText:Hide()
    host.chip = CreateFrame("Button", nil, resultsFrame)
    host.chip:SetHeight(16)
    host.chip:SetNormalFontObject("GameFontHighlightSmall")
    host.chip:SetText(" ")
    host.chip:SetScript("OnClick", DropPlaceWord)
    host.chip:SetScript("OnEnter", function(self) self:GetFontString():SetAlpha(0.7) end)
    host.chip:SetScript("OnLeave", function(self) self:GetFontString():SetAlpha(1) end)
    host.chip:Hide()
    resultsFrame.scrollFrame:HookScript("OnVerticalScroll", function(_, offset)
        if not host:IsShown() then return end
        local newOffset = mmax(0, mfloor((offset or 0) / rowH))
        if newOffset ~= rowOffset then
            rowOffset = newOffset
            Repaint()
        end
    end)
    host:SetScript("OnEvent", function()
        for _, slot in ipairs(slots) do
            for _, btn in ipairs(slot.cells) do
                if btn.cell and btn:IsShown() then PaintCooldown(btn) end
            end
        end
    end)
    slots = {}
    return host
end

local function NewCell(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn.tex = btn:CreateTexture(nil, "ARTWORK")
    btn.tex:SetAllPoints()
    btn.glow = btn:CreateTexture(nil, "OVERLAY")
    btn.glow:SetTexture(GLOW_TEX)
    btn.glow:SetBlendMode("ADD")
    btn.glow:SetPoint("CENTER")
    btn.glow:Hide()

    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints()
    btn.countText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    btn.countText:SetPoint("BOTTOMRIGHT", -1, 1)
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    btn:SetScript("OnClick", OnCellClick)
    btn:SetScript("OnEnter", OnCellHover)

    btn:SetScript("OnHide", function(self) if usePad and usePad.btn == self then HidePad() end end)
    btn:SetScript("OnLeave", OnCellLeave)
    return btn
end



local function EnsureSlots(cellSize)
    for s = 1, gridRows + 1 do
        local slot = slots[s]
        if not slot then
            slot = { cells = {} }
            slot.header = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            slot.header:SetJustifyH("LEFT")
            slot.header:SetWordWrap(false)
            slots[s] = slot
        end
        local y = -(s - 1) * rowH
        slot.header:ClearAllPoints()
        slot.header:SetPoint("TOPLEFT", page, "TOPLEFT", 2, y)
        slot.header:SetPoint("BOTTOMRIGHT", page, "TOPLEFT", gridCols * (cellSize + CELL_GAP) - CELL_GAP, y - cellSize)
        for c = 1, gridCols do
            local btn = slot.cells[c] or NewCell(page)
            slot.cells[c] = btn
            btn:SetSize(cellSize, cellSize)
            btn.glow:SetSize(cellSize * 1.8, cellSize * 1.8)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", page, "TOPLEFT", (c - 1) * (cellSize + CELL_GAP), y)
        end
        for c = gridCols + 1, #slot.cells do slot.cells[c]:Hide() end
    end
    for s = gridRows + 2, #slots do
        slots[s].header:Hide()
        for _, btn in ipairs(slots[s].cells) do btn:Hide() end
    end
end

function Results:ShowItemGrid(def, query)
    local resultsFrame = Search:GetResultsFrame()
    if not (resultsFrame and Data) then return end
    EnsureHost(resultsFrame)
    query = query or ""
    local same = def == shownDef and query == shownQuery
    Results:ClearRowsForGrid(resultsFrame)

    local theme = Results:GetActiveTheme()
    local fontScale = EasyFind.db.fontSize or 1.0
    local padT = mmax(theme.resultsPadTop or 0, mfloor((theme.resultsPadTop or 0) * fontScale + 0.5))
    local padB = mmax(theme.resultsPadBot or 0, mfloor((theme.resultsPadBot or 0) * fontScale + 0.5))

    local cellSize = mmax(24, Results:GetRowUnitHeight() - CELL_GAP)
    local width = resultsFrame:GetWidth() - SIDE_PAD * 2
    gridCols = mmax(1, mfloor((width + CELL_GAP) / (cellSize + CELL_GAP)))
    gridRows = mmax(1, EasyFind.db.uiResultsRows or 6)
    rowH = cellSize + CELL_GAP

    if not same then navIndex = 0 end
    shownDef, shownQuery = def, query
    ownKey = ns.CurrentCharacterKey()
    Build(Data.Sections(def.charKey, def.gridKind), query)
    EnsureSlots(cellSize)

    local gridH = gridRows * rowH - CELL_GAP
    local virtualH = mmax(1, lineN * rowH - CELL_GAP)
    local wasShown = host:IsShown()
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", resultsFrame.scrollChild, "TOPLEFT", SIDE_PAD, 0)
    host:SetSize(width, virtualH)
    host:Show()
    host:RegisterEvent("BAG_UPDATE_COOLDOWN")
    host.countText:Show()

    local stripH = padB + TEXT_STRIP_EXTRA
    local gridRight = SIDE_PAD + gridCols * (cellSize + CELL_GAP) - CELL_GAP
    host.countText:ClearAllPoints()
    host.countText:SetPoint("RIGHT", resultsFrame, "BOTTOMLEFT", gridRight, stripH / 2)
    host.hintText:ClearAllPoints()
    host.hintText:SetPoint("LEFT", resultsFrame, "BOTTOMLEFT", SIDE_PAD, stripH / 2)
    host.hintText:SetPoint("RIGHT", host.countText, "LEFT", -8, 0)
    host.chip:ClearAllPoints()
    host.chip:SetPoint("LEFT", resultsFrame, "BOTTOMLEFT", SIDE_PAD - 2, stripH / 2)

    Render:ApplyResultsFrameLayout(resultsFrame, virtualH, gridH, padT, stripH, 0, wasShown and same)
    rowOffset = mmax(0, mfloor(resultsFrame.scrollFrame:GetVerticalScroll() / rowH))
    Repaint()
end



local Grid = {}

function Grid.IsShown()
    return host ~= nil and host:IsShown()
end

function Grid.Hide()
    if not (host and host:IsShown()) then return end
    HidePad()
    host:UnregisterEvent("BAG_UPDATE_COOLDOWN")
    host:Hide()
    host.countText:Hide()
    host.hintText:Hide()
    host.chip:Hide()
    shownDef, shownQuery = nil, nil
    rowOffset, navIndex = 0, 0
end

function Grid.ReleaseMemory()
    lines, lineN = {}, 0
    flat, flatHeader, flatOwner, navFlat, navOfFlat, lineOfFlat = {}, {}, {}, {}, {}, {}
end

function Grid.IsNavActive()
    return navIndex > 0 and Grid.IsShown()
end

local function ShowFocus()
    local line = lineOfFlat[navFlat[navIndex]] or 1
    local scrollFrame = Search:GetResultsFrame().scrollFrame

    local top = line - 1
    if lines[top] and lines[top].header then top = top - 1 end
    if top < rowOffset then
        scrollFrame:SetVerticalScroll(mmax(0, top) * rowH)
    elseif line > rowOffset + gridRows then
        scrollFrame:SetVerticalScroll((line - gridRows) * rowH)
    end
    Repaint()
end

function Grid.ExitNav(refocus)
    if navIndex == 0 then return end
    navIndex = 0
    if Grid.IsShown() then Repaint() end
    Utils.SafeCallMethod(Search:GetNavFrame(), "EnableKeyboard", false)
    if refocus then
        local editBox = Search:GetSearchFrame() and Search:GetSearchFrame().editBox
        if editBox and not editBox:HasFocus() then
            editBox.blockFocus = nil
            editBox:SetFocus()
        end
    end
end



local function CellNear(lineIndex, col)
    local line = lines[lineIndex]
    if not (line and line.first) then return nil end
    return line.first + mmin(col, line.count - 1)
end

function Grid.MoveFocus(dCol, dRow)
    if #navFlat == 0 then return false end
    if navIndex == 0 then
        navIndex = 1
        for k = 1, #navFlat do
            if (lineOfFlat[navFlat[k]] or 0) > rowOffset then
                navIndex = k
                break
            end
        end
        local editBox = Search:GetSearchFrame() and Search:GetSearchFrame().editBox
        if editBox and editBox:HasFocus() then editBox:ClearFocus() end
        Utils.SafeCallMethod(Search:GetNavFrame(), "EnableKeyboard", true)
        ShowFocus()
        return true
    end
    local target = navIndex
    if dRow ~= 0 then
        local f = navFlat[navIndex]
        local lineIndex = lineOfFlat[f]
        local col = f - lines[lineIndex].first
        local found
        local step = dRow > 0 and 1 or -1
        local moves = dRow > 0 and dRow or -dRow
        local at = lineIndex
        while moves > 0 do
            at = at + step
            if at < 1 then
                if not found then
                    Grid.ExitNav(true)
                    return true
                end
                break
            end
            if at > lineN then break end
            local near = CellNear(at, col)
            if near then
                found = near
                moves = moves - 1
            end
        end
        if found then target = navOfFlat[found] end
    else
        target = mmax(1, mmin(#navFlat, navIndex + dCol))
    end
    if target == navIndex then return false end
    navIndex = target
    ShowFocus()
    return true
end

function Grid.JumpFocus(toEnd)
    if #navFlat == 0 then return end
    navIndex = toEnd and #navFlat or 1
    ShowFocus()
end

local function FocusedButton()
    local f = navIndex > 0 and navFlat[navIndex]
    if not f then return nil end
    for _, slot in ipairs(slots) do
        for _, btn in ipairs(slot.cells) do
            if btn:IsShown() and btn.flatIndex == f and btn.cell then return btn end
        end
    end
    return nil
end

function Grid.OpenFocusMenu()
    if not Grid.IsNavActive() then return false end
    local btn = FocusedButton()
    if not btn then return false end
    ShowCellMenu(btn, true)
    return true
end

function Grid.ActivateFocus()
    return Grid.OpenFocusMenu()
end

function Grid.ArmFocusCopy()
    if not Grid.IsNavActive() then return false end
    local btn = FocusedButton()
    if not (btn and ns.RowCopy) then return false end
    return ns.RowCopy:ArmFor(btn)
end

ns.RegisterResultGrid(Grid)
