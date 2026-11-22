

local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns or select(2, ...).stale then return end








local Search = ns.Search
local Results = ns.Results
local Render = ns.ResultRender
local Utils = ns.Utils
local IconSearch = ns.IconSearch
local L = ns.L

local mceil, mfloor, mmax = Utils.mceil, Utils.mfloor, Utils.mmax
local sformat = Utils.sformat
local InCombatLockdown = InCombatLockdown
local hooksecurefunc = hooksecurefunc

local CELL_GAP = 4


local SIDE_PAD = 10


local TEXT_STRIP_EXTRA = 14
local host, page, cells
local gridCols, gridRows = 0, 0
local rowH = 1
local filtered = {}
local filteredN = 0
local lastQuery
local rowOffset = 0


local menuCell





local navIndex = 0



local SPELL_NAMES_SHOWN = 3
local function IconTooltip(cellBtn)
    if not cellBtn.iconName then return end
    local body = tostring(cellBtn.iconID)
    local spellNames = IconSearch:GetSpellNames(cellBtn.iconIndex, SPELL_NAMES_SHOWN)
    if spellNames then body = body .. "\n" .. spellNames end
    ns.ShowHintTooltip(cellBtn, "ANCHOR_RIGHT", cellBtn.iconName, body, L["COPY_HINT"])
end

local function OnCellEnter(cellBtn)
    IconTooltip(cellBtn)
    if ns.RowCopy then ns.RowCopy:OnRowHover(cellBtn) end
end

local function OnCellLeave(cellBtn)
    ns.HideHintTooltip(cellBtn)
    if ns.RowCopy then ns.RowCopy:OnRowHover(nil) end
end




if ns.RowCopy and ns.RowCopy.RegisterHoverScanner then
    ns.RowCopy:RegisterHoverScanner(function()
        if not (host and host:IsVisible() and cells) then return nil end
        for i = 1, #cells do
            local cellBtn = cells[i]
            if cellBtn:IsShown() and cellBtn.iconID and cellBtn:IsMouseOver() then
                return cellBtn
            end
        end
        return nil
    end)
end

local function CreateMacroWithIcon(iconID, withTooltip)


    if InCombatLockdown() then return end
    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_MacroUI")
    end
    if not CreateMacro then return end





    local body = withTooltip and "#showtooltip\n" or ""






    local function TryCreateMacro(name)
        local ok, idx = pcall(CreateMacro, name, iconID, body, nil)
        if ok and idx then return idx end
        ok, idx = pcall(CreateMacro, name, iconID, body, true)
        if ok and idx then return idx end
        return nil
    end
    local idx = TryCreateMacro(" ") or TryCreateMacro(_G["MACRO"] or "Macro")
    if ns.ResultHandlers and ns.ResultHandlers.FinishResultSelection then
        ns.ResultHandlers:FinishResultSelection()
    end
    if ShowMacroFrame then
        pcall(ShowMacroFrame)
    end


    if idx and MacroFrame then
        if MacroFrame.SelectMacro then
            pcall(MacroFrame.SelectMacro, MacroFrame, idx)
        elseif _G["MacroFrame_SelectMacro"] then
            pcall(_G["MacroFrame_SelectMacro"], idx)
        end
    end
end



local Repaint

local function ShowCellMenu(cellBtn, keyboardMode)
    local iconID, iconName = cellBtn.iconID, cellBtn.iconName
    if not iconID then return end
    local rows = {
        { text = L["CTX_COPY_ICON_ID"], copy = tostring(iconID),
          tooltip = L["COPY_ROW_TT"], tooltipNote = L["COPY_ROW_TT_CELL"] },
        { text = L["CTX_COPY_ICON_NAME"], copy = iconName or "", tooltip = L["COPY_ROW_TT"] },
        { text = L["CTX_COPY_ICON_PATH"], copy = "Interface\\Icons\\" .. (iconName or ""),
          tooltip = L["COPY_ROW_TT"] },
        { text = L["CTX_CREATE_MACRO_ICON"], onClick = function()
            CreateMacroWithIcon(iconID)
        end },
        { text = L["CTX_CREATE_MACRO_ICON_TT"], onClick = function()
            CreateMacroWithIcon(iconID, true)
        end },
    }



    menuCell = cellBtn
    cellBtn:LockHighlight()







    if keyboardMode then
        Utils.SafeCallMethod(Search:GetNavFrame(), "EnableKeyboard", false)
    end
    Utils.ShowCursorMenu("EasyFindIconCellMenu", rows, {
        scale = EasyFind.db.uiSearchScale or 1.0,
        anchorFrame = keyboardMode and cellBtn or nil,
        keyboardMode = keyboardMode or nil,
        onHide = function()
            if menuCell then
                menuCell:UnlockHighlight()
                menuCell = nil
            end
            if keyboardMode and navIndex > 0
               and Search:GetSearchFrame() and Search:GetSearchFrame():IsShown() then
                Utils.SafeCallMethod(Search:GetNavFrame(), "EnableKeyboard", true)
            end



            if host and host:IsShown() then Repaint() end
        end,
    })
end

function Repaint()



    page:ClearAllPoints()
    page:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -rowOffset * rowH)
    local base = rowOffset * gridCols



    if menuCell then
        local keptID = filtered[base + menuCell.efCellIndex]
        if not keptID or select(2, IconSearch:GetIcon(keptID)) ~= menuCell.iconID then
            Utils.HideCursorMenus("EasyFindIconCellMenu")
        end
    end
    for i = 1, (gridRows + 1) * gridCols do
        local cellBtn = cells[i]
        local fIdx = filtered[base + i]
        if fIdx then
            local name, id = IconSearch:GetIcon(fIdx)
            cellBtn.iconName, cellBtn.iconID, cellBtn.iconIndex = name, id, fIdx


            cellBtn._efCopyText = tostring(id)
            cellBtn.tex:SetTexture(id)
            cellBtn:Show()
            if cellBtn:IsMouseOver() and ns.IsHintTooltipOwned(cellBtn) then
                IconTooltip(cellBtn)
            end
        else
            cellBtn.iconName, cellBtn.iconID, cellBtn.iconIndex = nil, nil, nil
            cellBtn._efCopyText = nil
            cellBtn:Hide()
        end


        if cellBtn ~= menuCell then
            if navIndex > 0 and base + i == navIndex then
                cellBtn:LockHighlight()
            else
                cellBtn:UnlockHighlight()
            end
        end
    end
    if host.countText then
        host.countText:SetText(sformat("%d/%d", filteredN, IconSearch:GetTotal()))


        if filteredN == 0 then
            host.hintText:SetText(_G["BROWSE_NO_RESULTS"] or "No results found.")
        else
            host.hintText:SetText(L["ICON_GRID_CLICK_HINT"])
        end

        local theme = Results.GetActiveTheme and Results:GetActiveTheme()
        if theme and theme.lightTheme and theme.textFaint then
            host.countText:SetTextColor(theme.textFaint[1], theme.textFaint[2], theme.textFaint[3], 1)
            host.hintText:SetTextColor(theme.textFaint[1], theme.textFaint[2], theme.textFaint[3], 1)
        else
            host.countText:SetTextColor(0.6, 0.6, 0.6, 0.9)
            host.hintText:SetTextColor(0.6, 0.6, 0.6, 0.9)
        end
    end
end



local function OnCellClick(cellBtn)
    if not cellBtn.iconID then return end
    ShowCellMenu(cellBtn)
end

local function EnsureHost(resultsFrame)
    if host then return host end
    host = CreateFrame("Frame", "EasyFindIconGrid", resultsFrame.scrollChild)
    host:EnableMouse(true)





    hooksecurefunc("ChatEdit_InsertLink", function(linkText)
        if not (linkText and host and host:IsShown()) then return end
        local ref = linkText:match("|H(%l+:%d+)")
        if not ref then return end
        local searchFrame = Search.GetSearchFrame and Search:GetSearchFrame()
        local editBox = searchFrame and searchFrame.editBox
        if not editBox then return end
        if editBox.ResetPendingSearch then editBox:ResetPendingSearch() end
        editBox:SetText(ref)
        editBox:SetCursorPosition(#ref)
        if editBox.placeholder then editBox.placeholder:Hide() end
        Search:OnSearchTextChanged(ref, true)
    end)



    page = CreateFrame("Frame", nil, host)
    page:SetSize(1, 1)




    host.countText = resultsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    host.countText._efOwnColor = true
    host.countText:Hide()


    host.hintText = resultsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    host.hintText._efOwnColor = true
    host.hintText:Hide()
    resultsFrame.scrollFrame:HookScript("OnVerticalScroll", function(_, offset)
        if not host:IsShown() then return end
        local newOffset = mmax(0, mfloor((offset or 0) / rowH))
        if newOffset ~= rowOffset then
            rowOffset = newOffset
            Repaint()
        end
    end)
    cells = {}
    return host
end

local function EnsureCells(cellSize)


    local need = (gridRows + 1) * gridCols
    for i = 1, need do
        local cellBtn = cells[i]
        if not cellBtn then
            cellBtn = CreateFrame("Button", nil, page)
            cellBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            cellBtn.tex = cellBtn:CreateTexture(nil, "ARTWORK")
            cellBtn.tex:SetAllPoints()
            cellBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            cellBtn:SetScript("OnClick", OnCellClick)
            cellBtn:SetScript("OnEnter", OnCellEnter)
            cellBtn:SetScript("OnLeave", OnCellLeave)
            cells[i] = cellBtn
        end
        local row = mfloor((i - 1) / gridCols)
        local col = (i - 1) % gridCols
        cellBtn.efCellIndex = i
        cellBtn:SetSize(cellSize, cellSize)
        cellBtn:ClearAllPoints()
        cellBtn:SetPoint("TOPLEFT", page, "TOPLEFT",
            col * (cellSize + CELL_GAP), -row * (cellSize + CELL_GAP))
    end
    for i = need + 1, #cells do
        cells[i]:Hide()
    end
end




function Results:ShowIconGrid(query)
    local resultsFrame = Search:GetResultsFrame()
    if not resultsFrame or not IconSearch then return end
    EnsureHost(resultsFrame)





    Results._cachedHierarchical = nil



    if ns.FeatureSpotlight then ns.FeatureSpotlight:Complete("iconSearch30") end

    query = query or ""
    local sameQuery = query == lastQuery
    if not sameQuery then
        filteredN = IconSearch:Filter(query, filtered)
        lastQuery = query
    elseif filteredN == 0 and IconSearch:GetTotal() > 0 then
        filteredN = IconSearch:Filter(query, filtered)
    end



    Results:ClearRowsForGrid(resultsFrame)



    local theme = Results:GetActiveTheme()
    local fontScale = EasyFind.db.fontSize or 1.0
    local padT = mfloor((theme.resultsPadTop or 0) * fontScale + 0.5)
    if padT < (theme.resultsPadTop or 0) then padT = theme.resultsPadTop end
    local padB = mfloor((theme.resultsPadBot or 0) * fontScale + 0.5)
    if padB < (theme.resultsPadBot or 0) then padB = theme.resultsPadBot end
    if resultsFrame.quickFilterHelp then resultsFrame.quickFilterHelp:Hide() end


    local unit = Results:GetRowUnitHeight()
    local cellSize = mmax(24, unit - CELL_GAP)
    local width = resultsFrame:GetWidth() - SIDE_PAD * 2
    gridCols = mmax(1, mfloor((width + CELL_GAP) / (cellSize + CELL_GAP)))
    gridRows = mmax(1, EasyFind.db.uiResultsRows or 6)
    rowH = cellSize + CELL_GAP
    EnsureCells(cellSize)




    local gridH = gridRows * rowH - CELL_GAP
    local totalRows = mceil(filteredN / gridCols)
    local virtualH = mmax(1, totalRows * rowH - CELL_GAP)
    local wasShown = host:IsShown()
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", resultsFrame.scrollChild, "TOPLEFT", SIDE_PAD, 0)
    host:SetSize(width, virtualH)
    host:Show()
    host.countText:Show()
    host.hintText:Show()





    local stripH = padB + TEXT_STRIP_EXTRA




    local gridRight = SIDE_PAD + gridCols * (cellSize + CELL_GAP) - CELL_GAP
    host.hintText:ClearAllPoints()
    host.hintText:SetPoint("LEFT", resultsFrame, "BOTTOMLEFT", SIDE_PAD, stripH / 2)
    host.countText:ClearAllPoints()
    host.countText:SetPoint("RIGHT", resultsFrame, "BOTTOMLEFT", gridRight, stripH / 2)





    Render:ApplyResultsFrameLayout(resultsFrame, virtualH, gridH, padT, stripH,
        0, wasShown and sameQuery)
    rowOffset = mmax(0, mfloor(resultsFrame.scrollFrame:GetVerticalScroll() / rowH))
    Repaint()
end



IconSearch:OnNamesReady(function()
    if not (host and host:IsShown() and lastQuery) then return end
    local n = IconSearch:Filter(lastQuery, filtered)
    if n ~= filteredN then
        filteredN = n
        Results:ShowIconGrid(lastQuery)
    end
end)


local Grid = {}

function Grid.Hide()
    if host and host:IsShown() then
        host:Hide()
        host.countText:Hide()
        host.hintText:Hide()
        lastQuery = nil
        rowOffset = 0
        navIndex = 0
    end
end

function Grid.IsShown()
    return host and host:IsShown() or false
end



function Grid.ReleaseMemory()

    filtered = {}
    filteredN = 0
    lastQuery = nil
    if IconSearch.ReleaseMemory then IconSearch:ReleaseMemory() end
end



function Grid.IsNavActive()
    return navIndex > 0 and host ~= nil and host:IsShown()
end

local function GridNavShow()



    local focusRow = mfloor((navIndex - 1) / gridCols)
    local scrollFrame = Search:GetResultsFrame().scrollFrame
    if focusRow < rowOffset then
        scrollFrame:SetVerticalScroll(focusRow * rowH)
    elseif focusRow > rowOffset + gridRows - 1 then
        scrollFrame:SetVerticalScroll((focusRow - gridRows + 1) * rowH)
    end
    Repaint()
end

function Grid.ExitNav(refocus)
    if navIndex == 0 then return end
    navIndex = 0
    if host and host:IsShown() then Repaint() end
    Utils.SafeCallMethod(Search:GetNavFrame(), "EnableKeyboard", false)
    if refocus then
        local editBox = Search:GetSearchFrame() and Search:GetSearchFrame().editBox
        if editBox and not editBox:HasFocus() then
            editBox.blockFocus = nil
            editBox:SetFocus()
        end
    end
end




function Grid.MoveFocus(dCol, dRow)
    if filteredN == 0 then return false end
    if navIndex == 0 then


        navIndex = rowOffset * gridCols + 1
        if navIndex > filteredN then navIndex = filteredN end
        local editBox = Search:GetSearchFrame() and Search:GetSearchFrame().editBox
        if editBox and editBox:HasFocus() then editBox:ClearFocus() end
        Utils.SafeCallMethod(Search:GetNavFrame(), "EnableKeyboard", true)
        GridNavShow()
        return true
    end
    local target = navIndex + dCol + dRow * gridCols
    if dRow < 0 and target < 1 then
        Grid.ExitNav(true)
        return true
    end
    if target < 1 then target = 1 end
    if target > filteredN then target = filteredN end
    if target == navIndex then return false end
    navIndex = target
    GridNavShow()
    return true
end

function Grid.JumpFocus(toEnd)
    if filteredN == 0 then return end
    navIndex = toEnd and filteredN or 1
    GridNavShow()
end

local function FocusedCell()
    local base = rowOffset * gridCols
    local cellBtn = cells and cells[navIndex - base]
    if cellBtn and cellBtn.iconID then return cellBtn end
    return nil
end


function Grid.ActivateFocus()
    return Grid.OpenFocusMenu()
end



function Grid.ArmFocusCopy()
    if not Grid.IsNavActive() then return false end
    local cellBtn = FocusedCell()
    if not (cellBtn and ns.RowCopy) then return false end
    return ns.RowCopy:ArmFor(cellBtn)
end

function Grid.OpenFocusMenu()
    if not Grid.IsNavActive() then return false end
    local cellBtn = FocusedCell()
    if not cellBtn then return false end
    ShowCellMenu(cellBtn, true)
    return true
end








function Results:OpenIconSearch()
    if Search and Search.Show then Search:Show(false) end
    local searchFrame = Search and Search.GetSearchFrame and Search:GetSearchFrame()
    if not (searchFrame and searchFrame:IsShown()) then return end
    local defs = ns.Filters and ns.Filters.quickFilterOptions
    if not defs then return end
    for i = 1, #defs do
        if defs[i].key == "icons" then
            ns.Filters:ApplyQuickFilter(defs[i], "")
            return
        end
    end
end



EasyFind.API.RegisterExtension({ id = "icons", scope = "icons" })

ns.RegisterResultGrid(Grid)
