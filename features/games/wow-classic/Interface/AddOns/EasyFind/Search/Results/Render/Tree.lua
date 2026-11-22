local _, ns = ...

local Results = ns.Results
local Utils = ns.Utils
local Render = ns.ResultRender

local mmax = Utils.mmax
local collapsedNodes = Results._collapsedNodes
local GOLD_COLOR = Render.GOLD_COLOR
local INDENT_COLORS = Render.INDENT_COLORS
local INDENT_PX = Render.INDENT_PX
local LINE_X_OFF = Render.LINE_X_OFF
local SetClippedText = Render.SetClippedText

function Render.TreeLines(resultRow, state, rowIndex, depth)
    local theme = state.theme
    if not theme.showTreeLines or depth <= 0 then return end

    local halfRow = state.rowH * 0.5
    local lineColor = theme.indentColors[depth] or theme.indentColors[1] or INDENT_COLORS[depth]
    local xCenter = (depth - 1) * INDENT_PX + LINE_X_OFF

    resultRow.treeElbow[depth]:SetColorTexture(Utils.RGB(lineColor, 1))
    resultRow.treeElbow[depth]:ClearAllPoints()
    resultRow.treeElbow[depth]:SetPoint("TOP", resultRow, "TOPLEFT", xCenter, 3)
    resultRow.treeElbow[depth]:SetHeight(halfRow + 2)
    resultRow.treeElbow[depth]:Show()

    resultRow.treeBranch[depth]:SetColorTexture(Utils.RGB(lineColor, 1))
    resultRow.treeBranch[depth]:ClearAllPoints()
    resultRow.treeBranch[depth]:SetPoint("LEFT",  resultRow, "TOPLEFT", xCenter - 1, -halfRow)
    resultRow.treeBranch[depth]:SetPoint("RIGHT", resultRow, "TOPLEFT", xCenter + INDENT_PX - LINE_X_OFF, -halfRow)
    resultRow.treeBranch[depth]:Show()

    if not state.isLastChild[rowIndex] then
        resultRow.treeVert[depth]:SetColorTexture(Utils.RGB(lineColor, 1))
        resultRow.treeVert[depth]:ClearAllPoints()
        resultRow.treeVert[depth]:SetPoint("TOP",    resultRow, "TOPLEFT",    xCenter, 3)
        resultRow.treeVert[depth]:SetPoint("BOTTOM", resultRow, "BOTTOMLEFT", xCenter, -1)
        resultRow.treeVert[depth]:Show()
    end

    for ancestorDepth = 1, depth - 1 do
        local stillActive = false
        for j = rowIndex + 1, state.count do
            local siblingDepth = state.visible[j].depth or 0
            if siblingDepth < ancestorDepth then break end
            if siblingDepth == ancestorDepth then stillActive = true; break end
        end
        if stillActive then
            local ancestorColor = theme.indentColors[ancestorDepth]
                or theme.indentColors[1]
                or INDENT_COLORS[ancestorDepth]
            local ancestorX = (ancestorDepth - 1) * INDENT_PX + LINE_X_OFF
            resultRow.treeVert[ancestorDepth]:SetColorTexture(Utils.RGB(ancestorColor, 1))
            resultRow.treeVert[ancestorDepth]:ClearAllPoints()
            resultRow.treeVert[ancestorDepth]:SetPoint("TOP",    resultRow, "TOPLEFT",    ancestorX, 3)
            resultRow.treeVert[ancestorDepth]:SetPoint("BOTTOM", resultRow, "BOTTOMLEFT", ancestorX, -1)
            resultRow.treeVert[ancestorDepth]:Show()
        end
    end
end

function Render.ResultHeader(resultRow, entry, state, depth)
    local theme = state.theme
    resultRow._isMatch = entry.isMatch and entry.isPathNode

    if entry.isPinHeader then
        if resultRow.headerTab then resultRow.headerTab:Hide() end
        if resultRow.headerGrad then resultRow.headerGrad:Hide() end
        ns.SetQuestLogToggle(resultRow.pinToggle, false, theme)
        resultRow.pinToggle:Show()
        resultRow.pinHeaderLine:Show()
        resultRow.text:ClearAllPoints()
        resultRow.text:SetPoint("LEFT", resultRow, "LEFT", 2, 0)
        resultRow.text:SetPoint("RIGHT", resultRow.pinToggle, "LEFT", -4, 0)
        Results:SetScaledFont(resultRow.text, theme.pathFont)
        resultRow.text:SetTextColor(0.7, 0.7, 0.7, 1.0)
        SetClippedText(resultRow.text, entry.name)
    elseif entry.isSectionHeader then
        if resultRow.headerTab then resultRow.headerTab:Hide() end
        if resultRow.headerGrad then resultRow.headerGrad:Hide() end



        SetClippedText(resultRow.text, "")
        resultRow.sectionLabelText:SetText(entry.name)
        resultRow.sectionLabelText:Show()
        resultRow.sectionLabelLeft:ClearAllPoints()
        resultRow.sectionLabelLeft:SetPoint("LEFT", resultRow, "LEFT", 6, 0)
        resultRow.sectionLabelLeft:SetPoint("RIGHT", resultRow.sectionLabelText, "LEFT", -6, 0)
        resultRow.sectionLabelLeft:Show()


        local fold = entry.toggle and resultRow.pinToggle
        resultRow.sectionLabelRight:ClearAllPoints()
        resultRow.sectionLabelRight:SetPoint("LEFT", resultRow.sectionLabelText, "RIGHT", 6, 0)
        if fold then
            fold:ClearAllPoints()
            fold:SetPoint("RIGHT", resultRow, "RIGHT", -8, 0)
            ns.SetQuestLogToggle(fold, entry.collapsed == true, theme)
            fold:Show()
            resultRow.sectionLabelRight:SetPoint("RIGHT", fold, "LEFT", -6, 0)
        else
            resultRow.sectionLabelRight:SetPoint("RIGHT", resultRow, "RIGHT", -6, 0)
        end
        resultRow.sectionLabelRight:Show()
    elseif theme.showHeaderTab and entry.isPathNode and resultRow.headerTab then
        local tabInset = depth * state.indPx
        resultRow.headerTab:ClearAllPoints()
        resultRow.headerTab:SetPoint("TOPLEFT", resultRow, "TOPLEFT", tabInset, 0)
        resultRow.headerTab:SetPoint("BOTTOMRIGHT", resultRow, "BOTTOMRIGHT", 0, 0)
        resultRow.headerTab:Show()

        local key = entry.name .. "_" .. depth
        local isCollapsed = collapsedNodes[key]
        ns.SetQuestLogToggle(resultRow.toggleIcon, isCollapsed, theme)
        resultRow.tabText:ClearAllPoints()
        resultRow.tabText:SetPoint("LEFT", resultRow.headerTab, "LEFT", 10, 0)
        resultRow.tabText:SetPoint("RIGHT", resultRow.toggleBtn, "LEFT", -4, 0)
        resultRow.tabText:SetText(entry.name)
        if resultRow._isMatch then
            resultRow.tabText:SetTextColor(Utils.RGB(GOLD_COLOR, 1.0))
        else
            resultRow.tabText:SetTextColor(0.60, 0.58, 0.55, 1.0)
        end
        SetClippedText(resultRow.text, "")
        if resultRow.headerGrad then resultRow.headerGrad:Hide() end
    else
        if resultRow.headerTab then resultRow.headerTab:Hide() end
        local showGrad = theme.showHeaderBar and entry.isPathNode
        if showGrad and resultRow.headerGrad then
            resultRow.headerGrad:SetAllPoints()
            local gradAlpha = mmax(0.25, 0.6 - depth * 0.1)
            resultRow.headerGrad:SetVertexColor(0.35, 0.27, 0.08, gradAlpha)
        end
        if resultRow.headerGrad then resultRow.headerGrad:SetShown(showGrad) end
    end

    if not entry.isPinHeader and theme.showSeparators then
        resultRow.separator:SetColorTexture(unpack(theme.separatorColor))
        resultRow.separator:Show()
    else
        resultRow.separator:Hide()
    end
end
