local _, ns = ...

local Utils = ns.Utils
local Render = ns.ResultRender
local Icons = ns.ResultIcons

local tconcat = Utils.tconcat
local InCombatLockdown = InCombatLockdown
local IsMenuBarSpecificIconData = Icons.IsMenuBarSpecificIconData
local IsRightSideIconData = Icons.IsRightSideIconData
local IsBossResultData = Render.IsBossResultData
local INDENT_PX = Render.INDENT_PX
local LINE_X_OFF = Render.LINE_X_OFF
local MAX_DEPTH = Render.MAX_DEPTH

function Render.ApplyFlatResultSizing(resultRow, entry, state)
    if not entry.isFlat or not resultRow.icon or not resultRow.icon:IsShown() then return end

    local data = entry.data
    if IsRightSideIconData(data) then
        local rightSize = state.entryRowH - 18
        if rightSize < (state.theme.iconSize or 16) then
            rightSize = state.theme.iconSize or 16
        end
        if IsMenuBarSpecificIconData(data) then
            rightSize = state.entryRowH - 8
        elseif IsBossResultData(data) then
            rightSize = state.entryRowH - 14
            if rightSize < (state.theme.iconSize or 16) then
                rightSize = state.theme.iconSize or 16
            end
        end
        resultRow.icon:SetSize(rightSize, rightSize)
    else
        resultRow.icon:SetSize(state.entryRowH - 16, state.entryRowH - 16)
    end
end

function Render.ApplyFlatResultAnchoring(resultRow, entry, state)
    local data = entry.data
    if not entry.isFlat or (data and data.calculatorResult) then return end



    if entry.isSectionHeader or entry.isPinHeader then
        if resultRow.pathSubtext then resultRow.pathSubtext:Hide() end
        return
    end

    local catShown = resultRow.flatCatIcon and resultRow.flatCatIcon:IsShown()
    local mainIconOnRight = IsRightSideIconData(data)
    local leftAnchor
    if catShown then
        leftAnchor = resultRow.flatCatIcon
    elseif not mainIconOnRight and resultRow.icon:IsShown() then
        leftAnchor = resultRow.icon
    end

    local rightAnchor, rightOffset
    if resultRow.repBar and resultRow.repBar:IsShown() then

        if mainIconOnRight and resultRow.icon:IsShown() and resultRow.repBar:GetPoint() == "RIGHT" then
            resultRow.repBar:ClearAllPoints()
            resultRow.repBar:SetPoint("RIGHT", resultRow.icon, "LEFT", -4, 0)
        end
        rightAnchor, rightOffset = resultRow.repBar, -4
    elseif resultRow.decorText and resultRow.decorText:IsShown() then
        rightAnchor, rightOffset = resultRow.decorText, -4
    elseif mainIconOnRight and resultRow.icon:IsShown() then

        if resultRow.amountText and resultRow.amountText:IsShown() then
            rightAnchor, rightOffset = resultRow.amountText, -4
        else
            rightAnchor, rightOffset = resultRow.icon, -4
        end
    elseif resultRow.settingSliderGroup and resultRow.settingSliderGroup:IsShown() then
        rightAnchor, rightOffset = resultRow.settingSliderGroup, -4
    elseif resultRow.settingDropdownGroup and resultRow.settingDropdownGroup:IsShown() then
        rightAnchor, rightOffset = resultRow.settingDropdownGroup, -4
    elseif resultRow.settingKeybindGroup and resultRow.settingKeybindGroup:IsShown() then
        rightAnchor, rightOffset = resultRow.settingKeybindGroup, -4
    elseif resultRow.settingState and resultRow.settingState:IsShown() then
        rightAnchor, rightOffset = resultRow.settingState, -4
    elseif resultRow.amountText and resultRow.amountText:IsShown() then
        rightAnchor, rightOffset = resultRow.amountText, -4
    else
        rightAnchor, rightOffset = resultRow, -8
    end

    resultRow.text:ClearAllPoints()
    if leftAnchor then
        resultRow.text:SetPoint("BOTTOMLEFT", leftAnchor, "RIGHT", 6, state.stackHalfGap)
    else
        resultRow.text:SetPoint("BOTTOMLEFT", resultRow, "LEFT", (entry.depth or 0) * state.indPx + 4, state.stackHalfGap)
    end
    if rightAnchor == resultRow then
        resultRow.text:SetPoint("RIGHT", resultRow, "RIGHT", rightOffset, 0)
    else
        resultRow.text:SetPoint("RIGHT", rightAnchor, "LEFT", rightOffset, 0)
    end

    resultRow.pathSubtext:ClearAllPoints()
    resultRow.pathSubtext:SetPoint("TOPLEFT", resultRow.text, "BOTTOMLEFT", 0, -state.stackGap)
    if rightAnchor == resultRow then
        resultRow.pathSubtext:SetPoint("RIGHT", resultRow, "RIGHT", rightOffset, 0)
    else
        resultRow.pathSubtext:SetPoint("RIGHT", rightAnchor, "LEFT", rightOffset, 0)
    end
    resultRow.pathSubtext:Show()
end




local GPS_ICON_GAP = 6

local function NavigateFromResults(data)
    local Handlers = ns.ResultHandlers
    if EasyFind.API.CallAction("gps", "navigate", data, { popout = true }) and Handlers and Handlers.FinishResultSelection then
        Handlers:FinishResultSelection()
    end
end

function Render.ApplyGPSButton(resultRow, entry, state)
    local data = entry.data
    local size = state.theme.iconSize or 15
    local btn = data and not (entry.isSectionHeader or entry.isPinHeader or entry.isPathNode)
        and EasyFind.API.CallAction("gps", "rowButton", resultRow, data, size, NavigateFromResults, state.theme.chromeGlyph)
    if not btn then
        if resultRow.gpsBtn then resultRow.gpsBtn:Hide() end
        return
    end
    local icon = resultRow.icon
    btn:ClearAllPoints()
    local edge, edgePoint, x
    if icon:IsShown() and IsRightSideIconData(data) then
        edge, edgePoint, x = icon, "LEFT", -GPS_ICON_GAP
    elseif resultRow.shortcutGroup and Render.ShouldShowShortcutHints() then

        edge, edgePoint, x = resultRow.shortcutGroup, "LEFT", -ns.ResultShortcuts.RESULT_SHORTCUT.gap
    else
        edge, edgePoint, x = resultRow, "RIGHT", -5
    end
    btn:SetPoint("RIGHT", edge, edgePoint, x, 0)


    local decor, decorW = resultRow.decorText, 0
    if decor and decor:IsShown() then
        decor:ClearAllPoints()
        decor:SetPoint("RIGHT", edge, edgePoint, x - size - 6, 0)
        decorW = decor:GetStringWidth() + 6
    end
    resultRow.text:SetPoint("RIGHT", edge, edgePoint, x - size - 4 - decorW, 0)
    if resultRow.pathSubtext:IsShown() then resultRow.pathSubtext:SetPoint("RIGHT", edge, edgePoint, x - size - 4 - decorW, 0) end
end

function Render.ApplyPinnedResultPrefix(resultRow, entry)
    if not entry.isPinned or not resultRow.pinIcon then return end

    resultRow.pinIcon:ClearAllPoints()
    resultRow.pinIcon:SetPoint("RIGHT", resultRow.text, "LEFT", 0, 0)
    resultRow.pinIcon:Show()
    if not entry.isFlat and entry.data and entry.data.path and #entry.data.path > 0 then
        local prefix = tconcat(entry.data.path, " > ")
        Render.SetUnclippedText(resultRow.text, "|cff888888" .. prefix .. " >|r " .. (entry.data.name or ""))
    end
end

function Render.GetResultPendingApply(data)
    local custom = data and ns.ResultRows.CustomSetting and ns.ResultRows:CustomSetting(data.settingVariable)
    if custom then return custom.pending ~= nil and custom.pending() == true end
    if not (data and data.settingVariable and ns.BlizzOptionsSearch
        and ns.BlizzOptionsSearch.HasPendingChange) then
        return false
    end

    local pending = ns.BlizzOptionsSearch:HasPendingChange(data.settingVariable)
    if not pending and data.sliderVariable and data.sliderVariable ~= data.settingVariable then
        pending = ns.BlizzOptionsSearch:HasPendingChange(data.sliderVariable)
    end

    if not pending and data.dropdownVariable and data.dropdownVariable ~= data.settingVariable then
        pending = ns.BlizzOptionsSearch:HasPendingChange(data.dropdownVariable)
    end
    return pending
end

function Render.MeasureResultRowHeight(resultRow, entry, state)
    local actualH = resultRow:GetHeight()
    local textObj
    if state.theme.showHeaderTab and entry.isPathNode
       and resultRow.headerTab and resultRow.headerTab:IsShown() then
        textObj = nil
    elseif not entry.isPinHeader then
        textObj = resultRow.text
    end

    if textObj then
        local textHeight = textObj:GetStringHeight()
        local minH = textHeight / ns.SEARCHBAR_FILL
        if minH > actualH then
            actualH = minH
            resultRow:SetHeight(actualH)
            if resultRow.headerTab and resultRow.headerTab:IsShown() then
                resultRow.headerTab:SetHeight(actualH)
            end
            if state.theme.showTreeLines and (entry.depth or 0) > 0 then
                local depth = entry.depth or 0
                local halfRow = actualH * 0.5
                local xCenter = (depth - 1) * INDENT_PX + LINE_X_OFF
                resultRow.treeElbow[depth]:ClearAllPoints()
                resultRow.treeElbow[depth]:SetPoint("TOP", resultRow, "TOPLEFT", xCenter, 3)
                resultRow.treeElbow[depth]:SetHeight(halfRow + 2)
                resultRow.treeBranch[depth]:ClearAllPoints()
                resultRow.treeBranch[depth]:SetPoint("LEFT",  resultRow, "TOPLEFT", xCenter - 1, -halfRow)
                resultRow.treeBranch[depth]:SetPoint("RIGHT", resultRow, "TOPLEFT", xCenter + INDENT_PX - LINE_X_OFF, -halfRow)
            end
        end
    end
    return actualH
end







function Render.ApplyIconVisibility(resultRow, entry)
    if not entry.isFlat then return end
    local mode = EasyFind and EasyFind.db and EasyFind.db.iconVisibility
    if not mode or mode == "all" then return end
    local data = entry.data
    if mode == "general" then
        if resultRow.icon and IsRightSideIconData(data) then
            resultRow.icon:Hide()
        end
    elseif mode == "specific" then
        if resultRow.flatCatIcon then resultRow.flatCatIcon:Hide() end
        if resultRow.icon and not IsRightSideIconData(data) then
            resultRow.icon:Hide()
        end
    end
end




function Render.ApplyOffSpecResultStyle(resultRow, data)
    if not (data and data.isOffSpec) then return end

    if resultRow.icon then
        resultRow.icon:SetVertexColor(0.4, 0.4, 0.4, 1.0)
    end
end

function Render.HideUnusedResultRow(resultRow)
    resultRow:Hide()
    resultRow.isPinHeader = false
    resultRow._efShortcutIndex = nil
    resultRow._efShortcutBindingReady = nil
    resultRow._efContentTop = nil
    resultRow._efContentBottom = nil
    if not InCombatLockdown() then



        ns.ResultSecureAttributes.Clear(resultRow)
        Utils.SafeCallMethod(resultRow, "SetAttribute", "toy", nil)
        Utils.SafeCallMethod(resultRow, "SetAttribute", "action", nil)
        Utils.SafeCallMethod(resultRow, "SetAttribute", "spell", nil)
        Utils.SafeCallMethod(resultRow, "SetAttribute", "macro", nil)
        Utils.SafeCallMethod(resultRow, "SetAttribute", "macrotext", nil)
    end
    if resultRow.headerGrad then resultRow.headerGrad:Hide() end
    if resultRow.headerTab then resultRow.headerTab:Hide() end
    resultRow.separator:Hide()
    resultRow.repBar:Hide()
    if resultRow.flatCatIcon then resultRow.flatCatIcon:Hide() end
    if resultRow.pathSubtext then resultRow.pathSubtext:Hide() end
    if resultRow.calcCard then resultRow.calcCard:Hide() end
    if resultRow.calcDivider then resultRow.calcDivider:Hide() end
    if resultRow.calcDividerTop then resultRow.calcDividerTop:Hide() end
    if resultRow.calcDividerBottom then resultRow.calcDividerBottom:Hide() end
    if resultRow.calcArrowText then resultRow.calcArrowText:Hide() end
    if resultRow.calcExpressionHighlight then resultRow.calcExpressionHighlight:Hide() end
    if resultRow.calcResultHighlight then resultRow.calcResultHighlight:Hide() end
    if resultRow.calcExpressionFlash then resultRow.calcExpressionFlash:Hide() end
    if resultRow.calcResultFlash then resultRow.calcResultFlash:Hide() end
    if resultRow.calcExpressionHint then resultRow.calcExpressionHint:Hide() end
    if resultRow.calcResultHint then resultRow.calcResultHint:Hide() end
    if resultRow.calcExpressionButton then resultRow.calcExpressionButton:Hide() end
    if resultRow.calcResultButton then resultRow.calcResultButton:Hide() end
    if resultRow.shortcutGroup then resultRow.shortcutGroup:Hide() end
    for d = 1, MAX_DEPTH do
        resultRow.treeVert[d]:Hide()
        resultRow.treeElbow[d]:Hide()
        resultRow.treeBranch[d]:Hide()
    end
end
