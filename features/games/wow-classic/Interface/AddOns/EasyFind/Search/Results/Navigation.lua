local _, ns = ...

local Search = ns.Search
local Results = ns.Results
local Rows = ns.ResultRows
local Icons = ns.ResultIcons
local Handlers = ns.ResultHandlers
local Utils = ns.Utils
local Calculator = ns.Calculator
local History = ns.SearchHistory
local L = ns.L
local UIPins = ns.UIPins
local GOLD_COLOR = ns.GOLD_COLOR

local ipairs = Utils.ipairs
local mmax, mfloor = math.max, math.floor
local PORTRAIT_ALPHA_MASK = ns.PORTRAIT_ALPHA_MASK
local wipe = wipe
local StaticPopup_Visible = StaticPopup_Visible
local StaticPopup_Show = StaticPopup_Show

local MAX_BUTTON_POOL = 100
local GetAllPins = UIPins.GetAll
local pinnedOnlyEntries = {}






local navEnterBound

local function ResultsFrame()
    return Search:GetResultsFrame()
end

local function ResultsShownForSweep()
    local rf = ResultsFrame()
    return rf and rf:IsShown() or false
end

local function TrimAfterUISearch()
    if ns.Database and ns.Database.TrimSearchMemory then
        ns.Database:TrimSearchMemory()
    end
    if ns.MapSearch and ns.MapSearch.TrimSearchMemory then
        ns.MapSearch:TrimSearchMemory()
    end
end

local function CollapsedNodes()
    return Results._collapsedNodes
end



function Results:NextSettingDropdownValue(data, direction)
    if not data or not data.settingVariable then return nil end


    local var = data.dropdownVariable or data.settingVariable
    local opts = data.settingOptions
    if not opts and ns.BlizzOptionsSearch and ns.BlizzOptionsSearch.GetOptionsForVariable then
        opts = ns.BlizzOptionsSearch.GetOptionsForVariable(var)
        if opts then data.settingOptions = opts end
    end
    if not opts or #opts == 0 then return nil end

    local curVal = Rows:ReadSettingVariable(var)

    local curIdx
    for i = 1, #opts do
        local v = opts[i].value
        if v == curVal or tostring(v) == tostring(curVal) then
            curIdx = i
            break
        end
    end
    local n = #opts
    local step = direction or 1
    local nextIdx = ((curIdx or 1) - 1 + step) % n + 1
    return var, opts[nextIdx].value
end





function Results:CycleSettingDropdown(data, direction)
    local var, nextVal = self:NextSettingDropdownValue(data, direction)
    if not var or not Rows:WriteSettingVariable(var, nextVal) then return false end

    Search:RefreshResults()
    if Search:GetSearchFrame() and Search:GetSearchFrame().editBox
       and not (Search:GetNavFrame() and Search:GetNavFrame():IsKeyboardEnabled()) then
        Search:GetSearchFrame().editBox.blockFocus = nil
        Search:GetSearchFrame().editBox:SetFocus()
    end
    return true
end


function Results:SetSettingDropdownValue(data, value, written)
    if not data or not data.settingVariable then return false end
    if not written and not Rows:WriteSettingVariable(data.dropdownVariable or data.settingVariable, value) then
        return false
    end
    Search:RefreshResults()
    if Search:GetSearchFrame() and Search:GetSearchFrame().editBox
       and not (Search:GetNavFrame() and Search:GetNavFrame():IsKeyboardEnabled()) then
        Search:GetSearchFrame().editBox.blockFocus = nil
        Search:GetSearchFrame().editBox:SetFocus()
    end
    return true
end





function Results:OpenSettingNoClose(data)
    if not data or not data.steps or not data.steps[1] then return end
    if ns.BlizzOptionsSearch then
        ns.BlizzOptionsSearch:HandleStep(data.steps[1])
    end


    Search:RefreshResults()
end











local FILTER_POPUP_NAMES = {
    "EasyFindAsClassPopup",
    "EasyFindAsOptionsPopup",
    "EasyFindLootOptionsPopup",
    "EasyFindMountOptionsPopup",
    "EasyFindMountSourcePopup",
    "EasyFindDiffPopup",
    "EasyFindSpecPopup",
    "EasyFindSpecFlyout",
    "EasyFindSpecSubFlyout",
}

function Results:CloseFilterDropdownIfOpen()
    if not Search:GetSearchFrame() then return false end
    local closedAny = Utils.HideCursorMenus and Utils.HideCursorMenus() or false
    local dropdown = Search:GetSearchFrame().filterDropdown
    if not dropdown then return closedAny end




    for i = 1, #FILTER_POPUP_NAMES do
        local f = _G[FILTER_POPUP_NAMES[i]]
        if f and f.IsShown and f:IsShown() then
            f:Hide()
            closedAny = true
        end
    end


    if dropdown.flyoutPopups then
        for i = 1, #dropdown.flyoutPopups do
            local popup = dropdown.flyoutPopups[i]
            if popup and popup:IsShown() then
                popup:Hide()
                closedAny = true
            end
        end
    end
    if dropdown.guardFrames then
        for i = 1, #dropdown.guardFrames do
            local guard = dropdown.guardFrames[i]
            if guard and guard:IsShown() then
                guard:Hide()
                closedAny = true
            end
        end
    end
    if dropdown:IsShown() then
        dropdown:Hide()
        closedAny = true
    end
    return closedAny
end







local function FindPopupSlot(popupName)
    for i = 1, 4 do
        local p = _G["StaticPopup" .. i]
        if p and p:IsShown() and p.which == popupName then return p end
    end
    return nil
end





local function LiftPopupStrata(popup)
    if not popup or popup._easyFindStrataLifted then return end
    popup._easyFindStrataLifted = true
    popup._easyFindOriginalStrata = popup:GetFrameStrata()
    popup:SetFrameStrata("TOOLTIP")
    if not popup._easyFindStrataRestoreHooked then
        popup._easyFindStrataRestoreHooked = true
        popup:HookScript("OnHide", function(self)
            if self._easyFindStrataLifted then
                if self._easyFindOriginalStrata then
                    self:SetFrameStrata(self._easyFindOriginalStrata)
                end
                self._easyFindStrataLifted = nil
                self._easyFindOriginalStrata = nil
            end
        end)
    end
end

function Results:FindPopupSlot(popupName)
    return FindPopupSlot(popupName)
end

function Results:LiftPopupStrata(popup)
    return LiftPopupStrata(popup)
end



function Results:ShowUnappliedSettingsPopup()
    if not (ns.BlizzOptionsSearch and ns.BlizzOptionsSearch.GetPendingApplyCount
            and ns.BlizzOptionsSearch:GetPendingApplyCount() > 0) then
        return false
    end
    local already = StaticPopup_Visible
        and StaticPopup_Visible("EASYFIND_UNAPPLIED_SETTINGS")
    if not already and StaticPopup_Show then
        StaticPopup_Show("EASYFIND_UNAPPLIED_SETTINGS")
    end
    LiftPopupStrata(FindPopupSlot("EASYFIND_UNAPPLIED_SETTINGS"))
    return true
end







function Results:ShowEmptyQueryView()
    if ns.Filters and ns.Filters.GetQuickFilter and ns.Filters:GetQuickFilter() then
        Search:OnSearchTextChanged("", true)
    else
        self:ShowPinnedItems()
    end
end

function Results:RequestHideResults()
    if ResultsFrame() and ResultsFrame():IsShown() and self:ShowUnappliedSettingsPopup() then
        return
    end
    self:HideResults()
end

function Results:HideResults()
    if not Search:GetSearchFrame() then return end
    Search:StopActiveKeybindCapture()
    self:ClearCalculatorCopyHighlight()
    self:ReleaseCalculatorCopyBox()
    self:HideGrids(true)








    local searchFrame = Search:GetSearchFrame()
    local navRepeatActive = searchFrame.IsAltNavRepeatKey
        and searchFrame.IsAltNavRepeatKey()
    if searchFrame.StopKeyRepeat
       and not History:IsPreservingNavRepeat()
       and not navRepeatActive then
        searchFrame.StopKeyRepeat()
    end
    if Search:GetSearchFrame().ClearToolbarFocus then Search:GetSearchFrame().ClearToolbarFocus() end
    Search:ClearResultShortcutBindings()
    if not ResultsFrame() then return end


    Utils.SafeCallMethod(ResultsFrame(), "Hide")




    if Search:GetContainerFrame() then
        Search:GetContainerFrame():ClearAllPoints()
        Search:GetContainerFrame():SetPoint("TOPLEFT",  Search:GetSearchFrame(), "TOPLEFT",  0, 0)
        Search:GetContainerFrame():SetPoint("TOPRIGHT", Search:GetSearchFrame(), "TOPRIGHT", 0, 0)
        Search:GetContainerFrame():SetPoint("BOTTOM",   Search:GetSearchFrame(), "BOTTOM",   0, 0)
        ns.SetRoundedRectDivider(Search:GetContainerFrame(), 0, false)
    end
    if ResultsFrame().pinSeparator then
        ResultsFrame().pinSeparator:Hide()
    end
    if ResultsFrame().categorySeps then
        for _, sep in ipairs(ResultsFrame().categorySeps) do sep:Hide() end
    end
    if ResultsFrame().truncIndicator then
        ResultsFrame().truncIndicator:Hide()
    end
    if ResultsFrame().truncSeparator then
        ResultsFrame().truncSeparator:Hide()
    end
    Results._cachedHierarchical = nil
    self._lastRenderSig = nil



    for i = 1, #Search:GetResultButtons() do
        local row = Search:GetResultButtons()[i]
        if row then
            row.data = nil
            row._efShortcutIndex = nil
            row._efShortcutBindingReady = nil
            row._efContentTop = nil
            row._efContentBottom = nil
            Utils.SafeCallMethod(row, "Hide")
            if row.shortcutGroup then Utils.SafeCallMethod(row.shortcutGroup, "Hide") end
            if row.icon then
                Icons.ClearRowIconLeafIDs(row.icon)
            end
        end
    end
    self.hideAfterCombat = InCombatLockdown() or nil
    self:ResetWindow()
    Search:SetSelectedIndex(0)
    Search:SetToggleFocused(false)
    self:UpdateSelectionHighlight(true, History:IsPreservingNavRepeat())

    if ns.Database and ns.Database.CancelDynamicWarmup then
        ns.Database:CancelDynamicWarmup()
    end




    Utils.NoteSurfaceClosed("uiSearch", ResultsShownForSweep, TrimAfterUISearch)
end

function Results:ShowPinnedItems()
    if not ResultsFrame() then return end
    local pins = GetAllPins()
    local quickFilter = self:GetQuickFilter()


    local last = not quickFilter and ns.Clipboard and ns.Clipboard.LastCopiedRow and ns.Clipboard:LastCopiedRow()
    local here = not quickFilter and ns.Notes and ns.Notes.HereRows and ns.Notes.HereRows()
    if #pins == 0 and not last and not here then
        self:HideResults()
        return
    end

    wipe(CollapsedNodes())
    local entries = pinnedOnlyEntries
    local n = 0
    local function Lead(data)
        n = n + 1
        local e = entries[n] or {}
        entries[n] = e
        e.name, e.depth, e.isPathNode, e.isMatch, e.isPinned, e.isFlat, e.data = data.name, 0, false, true, false, true, data
    end
    if last then Lead(last) end
    if here then
        for i = 1, #here do Lead(here[i]) end
    end
    for _, pin in ipairs(pins) do
        if not quickFilter or self:QuickFilterAllowsData(pin, quickFilter) then
            n = n + 1
            local e = entries[n]
            if not e then
                e = {}
                entries[n] = e
            end
            local data = UIPins.LiveRow(pin)
            e.name = data.name
            e.depth = 0
            e.isPathNode = false
            e.isMatch = true
            e.isPinned = true
            e.isFlat = true
            e.data = data
        end
    end
    if n == 0 then
        self:HideResults()
        return
    end
    for i = n + 1, #entries do
        entries[i] = nil
    end
    self:ShowHierarchicalResults(entries)
end

function Results:SelectFirstResult()

    local shownResults = ResultsFrame()
    local first = shownResults and shownResults:IsShown() and self:RowEntry(1)
    if first and first.data then
        if Rows:ActivateSettingResult(first.data) then return end
        self:SelectResult(first.data)
    end
end

function Results:CountVisibleResults()
    local frame = ResultsFrame()
    if not (frame and frame:IsShown()) then return 0 end
    return self:RowCount()
end

function Results:MoveSelection(delta, skipRefocus, keepRepeat)




    if not ResultsFrame() or not ResultsFrame():IsShown() then return false end


    if self:IsGridShown() then
        return self:MoveGridFocus(0, delta)
    end
    local visibleCount = self:CountVisibleResults()
    if visibleCount == 0 then return false end

    local oldIndex = Search:GetSelectedIndex()
    local newIndex = oldIndex + delta
    if EasyFind.db.uiResultsAbove then

        if newIndex > visibleCount then newIndex = 0
        elseif newIndex < 1 then newIndex = 1 end
    else

        if newIndex < 0 then newIndex = 0
        elseif newIndex > visibleCount then newIndex = visibleCount end
    end





    local step = delta > 0 and 1 or -1
    while newIndex >= 1 and newIndex <= visibleCount
          and self:RowEntry(newIndex) and self:RowEntry(newIndex).isSectionHeader
          and not self:RowEntry(newIndex).toggle do
        newIndex = newIndex + step
    end
    if newIndex < 0 then newIndex = 0 end
    if newIndex > visibleCount then newIndex = oldIndex end
    Search:SetSelectedIndex(newIndex)
    Search:SetToggleFocused(false)
    self:UpdateSelectionHighlight(skipRefocus, keepRepeat)
    return newIndex ~= oldIndex
end

function Results:JumpToStart()
    if self:IsGridNavActive() then
        return self:JumpGridFocus(false)
    end
    local visibleCount = self:CountVisibleResults()
    if visibleCount > 0 then

        local first = 1
        while first < visibleCount and self:RowEntry(first) and self:RowEntry(first).isSectionHeader do
            first = first + 1
        end
        Search:SetSelectedIndex(first)
        Search:SetToggleFocused(false)
        self:UpdateSelectionHighlight()
    end
end

function Results:JumpToEnd()
    if self:IsGridNavActive() then
        return self:JumpGridFocus(true)
    end
    local visibleCount = self:CountVisibleResults()
    if visibleCount > 0 then
        Search:SetSelectedIndex(visibleCount)
        Search:SetToggleFocused(false)
        self:UpdateSelectionHighlight()
    end
end

function Results:JumpToNextSection(direction)

    if self:IsGridNavActive() then
        return self:MoveGridFocus(0, direction * 5)
    end
    local visibleCount = self:CountVisibleResults()
    if visibleCount == 0 then return end

    local startIdx = Search:GetSelectedIndex()
    if startIdx == 0 then
        startIdx = direction > 0 and 0 or visibleCount + 1
    end

    local uiSectionStart = 0
    for i = 1, visibleCount do
        local e = self:RowEntry(i)
        if e and not e.isPinHeader and not e.isPinned then
            uiSectionStart = i
            break
        end
    end



    local idx = startIdx + direction
    while idx >= 1 and idx <= visibleCount do
        local e = self:RowEntry(idx)
        if e and (e.isSectionHeader or idx == uiSectionStart) then
            Search:SetSelectedIndex(idx)
            Search:SetToggleFocused(false)
            self:UpdateSelectionHighlight()
            return
        end
        idx = idx + direction
    end
end

function Results:UpdateSelectionHighlight(skipRefocus, keepRepeat)






    local sel = Search:GetSelectedIndex()
    if sel > 0 then self:ScrollRowIntoView(sel) end
    local newSelRow = sel > 0 and self:RowFrame(sel) or nil

    if Search.GPSKeyFocusRow then Search:GPSKeyFocusRow() end
    if newSelRow and not Search:GetToggleFocused() then
        if not Handlers:GetActionHint(newSelRow.data) then Handlers:ClearActionHint() end
        Handlers:ApplyActionHint(newSelRow)
    else
        Handlers:ClearActionHint()
    end

    for i = 1, MAX_BUTTON_POOL do
        local resultRow = Search:GetResultButtons()[i]
        if not resultRow then break end
        local isHeaderRow = resultRow.headerTab and resultRow.headerTab:IsShown()
        if resultRow.LockHighlight then
            if resultRow == newSelRow and not isHeaderRow then
                Results:SetRowHighlightLocked(resultRow, true)
            elseif not resultRow._efContextMenuHeld then
                Results:SetRowHighlightLocked(resultRow, false)
            end
        end
        if resultRow.craftGroup then ns.ResultRender.LayoutCraft(resultRow) end
    end
    if sel > 0 then
        if Search:GetSearchFrame().editBox:HasFocus() then
            Search:GetSearchFrame().editBox:ClearFocus()
        end
        Utils.SafeCallMethod(Search:GetNavFrame(), "EnableKeyboard", true)
        if newSelRow and not Search:GetToggleFocused() and newSelRow.data and newSelRow.data.calculatorResult then
            self:ArmCalculatorSelectionForKeyboard(newSelRow)
        elseif Calculator._calculator and Calculator._calculator.activeData then
            Calculator:ClearCalculatorCopyHighlight()
        end
    else
        if Calculator._calculator and Calculator._calculator.activeData then
            Calculator:ClearCalculatorCopyHighlight()
        end
        local wasNavigating = Search:GetNavFrame():IsKeyboardEnabled()
        Utils.SafeCallMethod(Search:GetNavFrame(), "EnableKeyboard", false)





        local searchFrame = Search:GetSearchFrame()
        local navRepeatActive = searchFrame.IsAltNavRepeatKey
            and searchFrame.IsAltNavRepeatKey()
        if not keepRepeat and not navRepeatActive and searchFrame.StopKeyRepeat then
            searchFrame.StopKeyRepeat()
        end
        if wasNavigating and not skipRefocus and not searchFrame.editBox:HasFocus() then
            searchFrame.editBox.blockFocus = nil
            searchFrame.editBox:SetFocus()
        end
    end





    local bindOwner = Results._navBindOwner
    if bindOwner and bindOwner:IsShown() and not InCombatLockdown() then
        local selRow = newSelRow
        local rd = selRow and selRow.data
        local secureRow = rd and Icons:IsSecureActionResult(rd)
        local btnName = secureRow and selRow:GetName() or nil
        if btnName ~= navEnterBound then
            if btnName then
                SetOverrideBindingClick(bindOwner, true, "ENTER", btnName, "LeftButton")
            else
                ClearOverrideBindings(bindOwner)
            end
            navEnterBound = btnName
        end
    end
end


function Results:NoteNavBindingCleared()
    navEnterBound = nil
end

function Results:ActivateResultRow(resultRow, source)
    if not resultRow or not resultRow:IsShown() then return false end
    if resultRow.isSectionHeader then
        local entry = self:RowEntry(resultRow.rowIndex or 0)
        if entry and entry.toggle then entry.toggle(entry) end
        return true
    end
    if resultRow.isUnearnedCurrency or resultRow.lockedReason or resultRow.isPinHeader then
        return true
    end
    if not resultRow.data then return false end

    if resultRow.data.quickFilterDef then
        return self:ApplyQuickFilter(resultRow.data.quickFilterDef, "")
    end
    if resultRow.data.searchCommand then


        local cmd = resultRow.data.searchCommand
        self:FinishResultSelection()
        return self:RunSearchBarCommand("/" .. cmd)
    end
    if resultRow.data.nativeRun then
        local run = resultRow.data.nativeRun
        self:FinishResultSelection()
        run()
        return true
    end
    if resultRow.data.specSetIndex or resultRow.data.loadoutConfigID then
        local specIndex, loadoutID = resultRow.data.specSetIndex,
            resultRow.data.loadoutConfigID
        self:FinishResultSelection()
        if ns.RunTalentSwap then ns.RunTalentSwap(specIndex, loadoutID) end
        return true
    end
    if resultRow.data.quicklistID and ns.Quicklists then
        local listID = resultRow.data.quicklistID
        self:FinishResultSelection()
        ns.Quicklists:OpenSoon(listID)
        return true
    end
    if resultRow.data.calculatorLauncher then
        return self:OpenCalculator("")
    end
    if Rows:ActivateSettingResult(resultRow.data) then return true end
    if resultRow.data.calculatorResult then
        self:ArmCalculatorResultFromRow(resultRow, source or "click")
        return true
    end
    if resultRow.data.copyText then
        if ns.RowCopy then ns.RowCopy:ArmFor(resultRow) end
        return true
    end
    self:SelectResult(resultRow.data)
    return true
end

function Results:ActivateSelected(source)

    if self:IsGridNavActive() then
        if self:ActivateGridFocus() then return end
    end



    local selected = Search:GetSelectedIndex()
    if selected > 0 then
        local resultRow = self:RowFrame(selected)
        if resultRow and resultRow:IsShown() then
            if resultRow.isPathNode and Search:GetToggleFocused() then
                local key = (resultRow.pathNodeName or "") .. "_" .. (resultRow.pathNodeDepth or 0)
                CollapsedNodes()[key] = not CollapsedNodes()[key]
                if Results._cachedHierarchical then
                    local savedIndex = Search:GetSelectedIndex()
                    local savedToggle = Search:GetToggleFocused()
                    self:ShowHierarchicalResults(Results._cachedHierarchical, true)
                    Search:SetSelectedIndex(savedIndex)
                    Search:SetToggleFocused(savedToggle)
                    self:UpdateSelectionHighlight()
                end
            else
                self:ActivateResultRow(resultRow, source or "key")
            end
            return
        end
    end

    self:SelectFirstResult()
end

function Results:UpdateOutfitLockOverlay(resultRow, isLocked)
    if not resultRow.icon then return end
    if not resultRow._lockOverlay then
        local overlay = resultRow:CreateTexture(nil, "OVERLAY")
        overlay:SetTexture("Interface\\AddOns\\EasyFind\\textures\\lock-dashes")
        overlay:SetVertexColor(Utils.RGB(GOLD_COLOR, 1))
        overlay:SetPoint("CENTER", resultRow.icon, "CENTER", 0, 0)
        resultRow._lockOverlay = overlay


        local ag = overlay:CreateAnimationGroup()
        ag:SetLooping("REPEAT")
        local fb = ag:CreateAnimation("FlipBook")
        fb:SetFlipBookRows(8)
        fb:SetFlipBookColumns(4)
        fb:SetFlipBookFrames(32)
        fb:SetDuration(0.9)
        resultRow._lockAnim = ag
    end
    local size = (resultRow.icon:GetWidth() or 16) + 2
    resultRow._lockOverlay:SetSize(size, size)
    resultRow._lockOverlay:SetShown(isLocked)
    if isLocked then
        resultRow._lockAnim:Play()
    else
        resultRow._lockAnim:Stop()
    end
end





function Results:UpdateGearSetSpecBadge(resultRow, specIcon)
    if not resultRow.icon then return end
    if not resultRow._specBadge then




        local badge = resultRow:CreateTexture(nil, "OVERLAY", nil, 7)
        badge:SetPoint("BOTTOMRIGHT", resultRow.icon, "BOTTOMRIGHT", 3, -3)
        resultRow._specBadge = badge

        local badgeMask = resultRow:CreateMaskTexture()
        badgeMask:SetTexture(PORTRAIT_ALPHA_MASK,
            "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        badgeMask:SetAllPoints(badge)
        badge:AddMaskTexture(badgeMask)
    end
    if specIcon then
        local size = mmax(8, mfloor((resultRow.icon:GetWidth() or 16) + 0.5))
        resultRow._specBadge:SetSize(size, size)
        resultRow._specBadge:SetTexture(specIcon)
    end
    resultRow._specBadge:SetShown(specIcon and true or false)
end

function Results:ApplyTransmogBrowseMode()
    if not TransmogFrame then return end

    local hidden = {}
    local outfitCollection = TransmogFrame.OutfitCollection
    if outfitCollection then
        if outfitCollection.PurchaseOutfitButton then
            outfitCollection.PurchaseOutfitButton:Hide()
            hidden[#hidden + 1] = outfitCollection.PurchaseOutfitButton
        end
        if outfitCollection.SaveOutfitButton then
            outfitCollection.SaveOutfitButton:Hide()
            hidden[#hidden + 1] = outfitCollection.SaveOutfitButton
        end
    end
    if outfitCollection and outfitCollection.MoneyFrame then
        outfitCollection.MoneyFrame:Hide()
        hidden[#hidden + 1] = outfitCollection.MoneyFrame
    end

    local wardrobeCollection = TransmogFrame.WardrobeCollection
    local tabHeaders = wardrobeCollection and wardrobeCollection.TabHeaders
    if tabHeaders then

        local situationsLabel = _G["TRANSMOG_TAB_SITUATIONS"] or "Situations"
        for _, tab in ipairs({ tabHeaders:GetChildren() }) do
            if tab.GetText and tab:GetText() == situationsLabel then
                tab:Hide()
                hidden[#hidden + 1] = tab
                break
            end
        end
    end




    local outfitScrollBox = outfitCollection and outfitCollection.OutfitList
        and outfitCollection.OutfitList.ScrollBox
    if outfitScrollBox and outfitScrollBox.EnumerateFrames then
        local function disableOutfitRightClick()
            for _, itemFrame in outfitScrollBox:EnumerateFrames() do
                local outfitBtn = itemFrame.OutfitButton
                if outfitBtn and outfitBtn.RegisterForClicks then
                    outfitBtn:RegisterForClicks("LeftButtonUp")
                end
            end
        end
        disableOutfitRightClick()

        if not outfitScrollBox._efBrowseHooked then
            outfitScrollBox._efBrowseHooked = true
            hooksecurefunc(outfitScrollBox, "Update", function()
                if TransmogFrame._efBrowseMode then
                    disableOutfitRightClick()
                end
            end)
        end
    end
    TransmogFrame._efBrowseMode = true

    TransmogFrame._efHiddenFrames = hidden


    if not TransmogFrame._efBrowseMsg then
        local msg = TransmogFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        msg:SetText(L["TMOG_VENDOR_REQUIRED"])
        msg:SetTextColor(Utils.RGB(GOLD_COLOR))
        msg:SetJustifyH("CENTER")
        TransmogFrame._efBrowseMsg = msg
    end
    local msg = TransmogFrame._efBrowseMsg
    msg:ClearAllPoints()
    local anchor = outfitCollection and outfitCollection.PurchaseOutfitButton
    if anchor then
        msg:SetPoint("TOP", anchor, "TOP", 0, 0)
    elseif outfitCollection then
        msg:SetPoint("BOTTOM", outfitCollection, "BOTTOM", 0, 20)
    else
        msg:SetPoint("BOTTOM", TransmogFrame, "BOTTOM", 0, 30)
    end
    msg:SetWidth((outfitCollection and outfitCollection:GetWidth() - 20) or 280)
    msg:Show()


    if not TransmogFrame._efSituationsMsg then
        local sitMsg = TransmogFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sitMsg:SetText(L["TMOG_VENDOR_SITUATIONS"])
        sitMsg:SetTextColor(Utils.RGB(GOLD_COLOR))
        sitMsg:SetJustifyH("RIGHT")
        TransmogFrame._efSituationsMsg = sitMsg
    end
    local sitMsg = TransmogFrame._efSituationsMsg
    sitMsg:ClearAllPoints()
    if tabHeaders then
        sitMsg:SetPoint("LEFT", tabHeaders, "RIGHT", 8, 6)
    else
        sitMsg:SetPoint("TOPRIGHT", TransmogFrame, "TOPRIGHT", -40, -55)
    end
    sitMsg:Show()


    if not TransmogFrame._efBrowseHooked then
        TransmogFrame._efBrowseHooked = true
        TransmogFrame:HookScript("OnHide", function(self)
            self._efBrowseMode = nil
            if self._efHiddenFrames then
                for _, frame in ipairs(self._efHiddenFrames) do
                    frame:Show()
                end
                self._efHiddenFrames = nil
            end
            if self._efBrowseMsg then
                self._efBrowseMsg:Hide()
            end
            if self._efSituationsMsg then
                self._efSituationsMsg:Hide()
            end
            local oc = self.OutfitCollection
            local sb = oc and oc.OutfitList and oc.OutfitList.ScrollBox
            if sb and sb.EnumerateFrames then
                for _, itemFrame in sb:EnumerateFrames() do
                    local outfitBtn = itemFrame.OutfitButton
                    if outfitBtn and outfitBtn.RegisterForClicks then
                        outfitBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                    end
                end
            end
        end)
    end
end
