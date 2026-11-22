local _, ns = ...

local Search = ns.Search
local Results = ns.Results
local Filters = ns.Filters
local Calculator = ns.Calculator
local SearchHistory = ns.SearchHistory
local OptionsSurface = ns.OptionsSurface
local Icons = ns.ResultIcons
local Handlers = ns.ResultHandlers
local Rows = ns.ResultRows
local Shortcuts = ns.ResultShortcuts
local L = ns.L

local Utils = ns.Utils
local slower = Utils.slower
local mmin, mmax = Utils.mmin, Utils.mmax

local GOLD_COLOR = ns.GOLD_COLOR
local SEARCH_ICON_TEXTURE = ns.SEARCH_ICON_TEX

local CreateFrame        = CreateFrame
local C_Timer            = C_Timer
local UIParent           = UIParent
local GameTooltip        = GameTooltip
local GameTooltip_Hide   = GameTooltip_Hide
local IsShiftKeyDown     = IsShiftKeyDown
local IsMouseButtonDown  = IsMouseButtonDown
local IsAltKeyDown       = IsAltKeyDown
local IsControlKeyDown   = IsControlKeyDown
local InCombatLockdown   = InCombatLockdown

function Search:GetDefaultSearchBarPoint()
    local parentH = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 768
    return "CENTER", "CENTER", 0, parentH / 6
end



local DEFAULT_FONT_SIZE = ns.DEFAULT_FONT_SIZE
function Search:GetSearchBarHeight()
    local fontSize = (EasyFind and EasyFind.db and EasyFind.db.fontSize) or DEFAULT_FONT_SIZE
    return mmax(24, mmin(56, ns.SEARCHBAR_HEIGHT * fontSize / DEFAULT_FONT_SIZE))
end

local searchFrame
local resultsFrame
local selectedIndex = 0
local toggleFocused = false
local navFrame
local activeKeybindBtn





local containerFrame
local resultButtons = {}
local MAX_BUTTON_POOL = 100
local petFavoriteOverrides = {}
local inCombat = false
local selectingResult = false
function Search:GetSearchFrame()
    return searchFrame
end



function Search:RefreshUpdateNotice()
    if resultsFrame and resultsFrame:IsShown() then
        Results:RefreshShownResults()
    end
end

function Search:GetResultsFrame()
    return resultsFrame
end

function Search:SetResultsFrame(frame)
    resultsFrame = frame
end

function Search:GetNavFrame()
    return navFrame
end

function Search:GetResultButtons()
    return resultButtons
end

function Search:GetSelectedIndex()
    return selectedIndex
end

function Search:SetSelectedIndex(index)
    selectedIndex = index or 0
end

function Search:SetToggleFocused(focused)
    toggleFocused = focused and true or false
end

function Search:GetToggleFocused()
    return toggleFocused
end




function Search:GPSKeyFocusRow()
    local row = self._gpsKeyRow
    if not row then return nil end
    if Results:RowFrame(selectedIndex) ~= row or not (row.gpsBtn and row.gpsBtn:IsShown()) then
        self:SetGPSKeyFocus(nil)
        return nil
    end
    return row
end



function Search:SetGPSKeyFocus(row)
    local old = self._gpsKeyRow
    if old == row then return end
    self._gpsKeyRow = row
    local oldBtn = old and old.gpsBtn
    if oldBtn then
        if oldBtn._efKeyGlow then oldBtn._efKeyGlow:Hide() end
        local leave = oldBtn:GetScript("OnLeave")
        if leave and not oldBtn:IsMouseOver() then leave(oldBtn) end
    end
    local btn = row and row.gpsBtn
    if not btn then return end
    if not btn._efKeyGlow then
        local glow = btn:CreateTexture(nil, "OVERLAY")
        glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        glow:SetBlendMode("ADD")
        glow:SetAllPoints()
        btn._efKeyGlow = glow
    end
    btn._efKeyGlow:Show()
    local enter = btn:GetScript("OnEnter")
    if enter then enter(btn) end
end

function Search:GetContainerFrame()
    return containerFrame
end

function Search:SetSelectingResult(selecting)
    selectingResult = selecting and true or false
end

function Search:IsSelectingResult()
    return selectingResult
end

function Search:GetPetFavoriteOverrides()
    return petFavoriteOverrides
end

function Search:GetActiveKeybindButton()
    return activeKeybindBtn
end

function Search:SetActiveKeybindButton(button)
    activeKeybindBtn = button
end

function Search:StopActiveKeybindCapture()
    local button = activeKeybindBtn
    if button and button._stopCapture then
        button._stopCapture(button)
    end
end

function Search:Initialize()
    self:CreateUnearnedTooltip()
    self:CreateSearchFrame()
    self:CreateResultsFrame()

    if resultsFrame then
        resultsFrame:HookScript("OnShow", Utils.RefreshEscArm)
        resultsFrame:HookScript("OnHide", Utils.RefreshEscArm)
    end
    self:RegisterCombatEvents()
    self:HookBlizzardFilterChanges()

    if EasyFind.db.autoHide then
        searchFrame:Hide()
    elseif EasyFind.db.visible ~= false then
        searchFrame:Show()
        if EasyFind.db.smartShow then
            searchFrame.hoverZone:Show()
            searchFrame:SetAlpha(0)
            searchFrame.setSmartShowVisible(false)
        end
    else
        searchFrame:Hide()
        if EasyFind.db.smartShow then
            searchFrame.hoverZone:Show()
        end
    end

    inCombat = InCombatLockdown()
    if inCombat and not (ns.GetVisibilityMode() == ns.VISIBILITY_ALWAYS
            and EasyFind.db.combatHide == false) then
        searchFrame:Hide()
    end

    self:UpdateScale()
    self:UpdateWidth()
    self:UpdateFontSize()







    if ns.BlizzOptionsSearch and ns.BlizzOptionsSearch.EnsureFastGameOptions then
        ns.BlizzOptionsSearch:EnsureFastGameOptions()
    end








    searchFrame.editBox.blockFocus = true
    searchFrame.editBox:ClearFocus()
    Utils.SafeAfter(0, function()
        Utils.SafeAfter(0, function()
            if searchFrame and searchFrame.editBox
                and ns.GetVisibilityMode() ~= ns.VISIBILITY_ALWAYS then
                searchFrame.editBox.blockFocus = nil
                searchFrame.editBox:ClearFocus()
            end
        end)
    end)






    local settleFrame = CreateFrame("Frame")
    settleFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    settleFrame:SetScript("OnEvent", function(self)
        local settleElapsed = 0
        Utils.SafeOnUpdate(self, function(_, elapsed)
            settleElapsed = settleElapsed + (elapsed or 0)
            local editBox = searchFrame and searchFrame.editBox
            if editBox and editBox.blockFocus and editBox:HasFocus() then
                editBox:ClearFocus()
            end



            if editBox and not editBox:HasFocus() then
                Utils.SafeCallMethod(editBox, "SetPropagateKeyboardInput", true)
            end
            if settleElapsed > 2 then
                self:SetScript("OnUpdate", nil)
            end
        end)
    end)



    if not EasyFind.db.tutorialDone then
        Utils.SafeAfter(0.3, function()
            if ns.TutorialOpensItself and not ns.TutorialOpensItself() then
                if ns.OfferTutorialInChat then ns.OfferTutorialInChat() end
                return
            end
            if ns.RequestOnboarding() and ns.Wizard.Show then ns.Wizard:Show() end
        end)
    end

end








function Search:UpdateStackStrata()
    local editBox = searchFrame and searchFrame.editBox
    local active = (resultsFrame and resultsFrame:IsShown())
        or (editBox and editBox:HasFocus())
    local strata = active and "DIALOG" or "LOW"
    if searchFrame then
        searchFrame:SetFrameStrata(strata)
        if searchFrame.toolbarHighlight then
            searchFrame.toolbarHighlight:SetFrameStrata(strata)
        end
    end
    if containerFrame then containerFrame:SetFrameStrata(strata) end
    if resultsFrame then resultsFrame:SetFrameStrata(strata) end
end

function Search:WarmSearchHotPath()





    local i = 0
    local function step()
        if InCombatLockdown() then return end
        for _ = 1, 2 do
            i = i + 1
            if i > 20 then return end
            Results:EnsureResultButton(i)
        end
        Utils.SafeAfter(0, step)
    end
    step()
end





local combatToggledOff = false
local isMovingNow = false
local BAR_DIM_ALPHA = 0.6




local function ApplyAlwaysBarAlpha()
    if not searchFrame or not searchFrame:IsShown() then return end
    if ns.GetVisibilityMode() ~= ns.VISIBILITY_ALWAYS then return end
    local alpha = 1
    if inCombat then
        if combatToggledOff then
            alpha = 0
        elseif EasyFind.db.combatDim and EasyFind.db.combatHide == false then
            alpha = BAR_DIM_ALPHA
        end
    elseif EasyFind.db.moveDim and isMovingNow
        and not (searchFrame.editBox and searchFrame.editBox:HasFocus()) then
        alpha = BAR_DIM_ALPHA
    end
    searchFrame:SetAlpha(alpha)
end

function Search:UpdateMoveDim()
    ApplyAlwaysBarAlpha()
end

local function EnsureCombatShield()
    if searchFrame.combatShield then return searchFrame.combatShield end
    local shield = CreateFrame("Frame", nil, searchFrame)
    shield:SetAllPoints(searchFrame)
    shield:SetFrameLevel(searchFrame:GetFrameLevel() + 40)
    shield:EnableMouse(true)
    shield:Hide()
    searchFrame.combatShield = shield
    return shield
end

function Search:RegisterCombatEvents()
    ns.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    ns.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    ns.eventFrame:RegisterEvent("PLAYER_STARTED_MOVING")
    ns.eventFrame:RegisterEvent("PLAYER_STOPPED_MOVING")

    searchFrame.editBox:HookScript("OnEditFocusGained", ApplyAlwaysBarAlpha)
    searchFrame.editBox:HookScript("OnEditFocusLost", ApplyAlwaysBarAlpha)
    searchFrame.editBox:HookScript("OnEditFocusGained", function() Search:UpdateStackStrata() end)
    searchFrame.editBox:HookScript("OnEditFocusLost", function() Search:UpdateStackStrata() end)
    ns.eventFrame:HookScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            inCombat = true
            combatToggledOff = false

            Search:CloseFilterDropdownIfOpen()




            if not (ns.GetVisibilityMode() == ns.VISIBILITY_ALWAYS
                    and EasyFind.db.combatHide == false) then
                searchFrame:Hide()
                searchFrame.hoverZone:Hide()
            else
                EnsureCombatShield():Show()
                ApplyAlwaysBarAlpha()
            end
            Results:HideResults()
            searchFrame.editBox:ClearFocus()
        elseif event == "PLAYER_STARTED_MOVING" then
            isMovingNow = true
            ApplyAlwaysBarAlpha()
            return
        elseif event == "PLAYER_STOPPED_MOVING" then
            isMovingNow = false
            ApplyAlwaysBarAlpha()
            return
        elseif event == "PLAYER_REGEN_ENABLED" then
            inCombat = false
            combatToggledOff = false

            if Results.hideAfterCombat then Results:HideResults() end
            if searchFrame.combatShield then searchFrame.combatShield:Hide() end
            ApplyAlwaysBarAlpha()

            if not EasyFind.db.autoHide then
                if EasyFind.db.visible ~= false then
                    searchFrame:Show()
                    if EasyFind.db.smartShow then
                        searchFrame.hoverZone:Show()
                        searchFrame:SetAlpha(0)
                        searchFrame.setSmartShowVisible(false)
                    end
                elseif EasyFind.db.smartShow then
                    searchFrame.hoverZone:Show()
                end
            end
        end
    end)
end

function Search:CreateSearchFrame()
    searchFrame = CreateFrame("Frame", "EasyFindSearchFrame", UIParent, "BackdropTemplate")

    Search.searchFrame = searchFrame
    local barH = self:GetSearchBarHeight()
    searchFrame:SetSize(250, barH)










    searchFrame:SetFrameStrata("LOW")
    searchFrame:SetMovable(true)
    searchFrame:EnableMouse(true)
    searchFrame:SetClampedToScreen(true)

    self:ApplySavedPosition()

    local theme = Results:GetActiveTheme()
    ns.CreateSearchBorder(searchFrame)







    containerFrame = CreateFrame("Frame", "EasyFindContainerFrame", UIParent)
    Search.containerFrame = containerFrame
    containerFrame:SetFrameStrata("LOW")
    containerFrame:SetFrameLevel(math.max(0, searchFrame:GetFrameLevel() - 1))
    containerFrame:SetPoint("TOPLEFT",  searchFrame, "TOPLEFT",  0, 0)
    containerFrame:SetPoint("TOPRIGHT", searchFrame, "TOPRIGHT", 0, 0)
    containerFrame:SetPoint("BOTTOM",   searchFrame, "BOTTOM",   0, 0)
    ns.CreateRoundedRectBorder(containerFrame)
    ns.CreateRoundedRectDivider(containerFrame)
    containerFrame._efForeverSurface = true
    containerFrame._efClassicSurface = true

    containerFrame._efBandDragOwner = searchFrame
    ns.SetRoundedRectBarHeight(containerFrame, searchFrame:GetHeight())
    self:ApplySearchWindowFill(containerFrame)






    searchFrame:HookScript("OnShow", function() containerFrame:Show() end)
    searchFrame:HookScript("OnHide", function() containerFrame:Hide() end)
    hooksecurefunc(searchFrame, "SetAlpha", function(_, a)
        containerFrame:SetAlpha(a or 1)
    end)
    if not searchFrame:IsShown() then containerFrame:Hide() end

    searchFrame:SetBackdrop(nil)




    ns.SetSearchBorderShown(searchFrame, false)





    ns.SetRoundedRectBorderShown(containerFrame, true)
    ns.SetRoundedRectRingShown(containerFrame, EasyFind.db.windowBorder ~= false)
    ns.SetRoundedRectBorderBgAlpha(containerFrame, ns.GetSearchWindowAlpha())


    local contentSz = barH * ns.SEARCHBAR_FILL
    local iconSz = contentSz * ns.SEARCHBAR_ICON_SCALE

    local iconHolder = CreateFrame("Frame", nil, searchFrame)
    iconHolder:SetPoint("TOP", searchFrame, "TOP", 0, 0)
    iconHolder:SetPoint("BOTTOM", searchFrame, "BOTTOM", 0, 0)
    iconHolder:SetPoint("LEFT", searchFrame, "LEFT", 0, 0)
    iconHolder:SetWidth(searchFrame:GetHeight())
    iconHolder:SetFrameLevel(searchFrame:GetFrameLevel() + 10)

    local searchIcon = iconHolder:CreateTexture(nil, "OVERLAY")
    searchIcon:SetSize(iconSz, iconSz)
    searchIcon:SetPoint("CENTER")
    searchIcon:SetTexture(SEARCH_ICON_TEXTURE)
    iconHolder.icon = searchIcon
    searchFrame.searchIcon = searchIcon
    searchFrame.modeBtn = iconHolder
    searchFrame.iconHolder = iconHolder


    local editBox = CreateFrame("EditBox", "EasyFindSearchBox", searchFrame)
    editBox:SetHeight(contentSz)
    editBox:SetPoint("LEFT", iconHolder, "RIGHT", 0, 0)
    editBox:SetPoint("RIGHT", searchFrame, "RIGHT", -8, 0)
    editBox:SetFontObject(ns.SEARCHBAR_FONT)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(50)









    Utils.SafeCallMethod(editBox, "SetPropagateKeyboardInput", true)
    editBox:HookScript("OnEditFocusLost", function(self)
        Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", true)
    end)





    local dragRefreshTicker
    local function StopDragRefresh()
        if dragRefreshTicker then
            dragRefreshTicker:Cancel()
            dragRefreshTicker = nil
        end
        Results:RefreshShownResults()
    end
    local function StartDragRefresh()
        if dragRefreshTicker then return end
        dragRefreshTicker = C_Timer.NewTicker(0.1, function()




            if not IsMouseButtonDown("LeftButton") then
                StopDragRefresh()
                return
            end
            local ok = pcall(function()
                Results:RefreshShownResults()
            end)
            if not ok and dragRefreshTicker then
                dragRefreshTicker:Cancel()
                dragRefreshTicker = nil
            end
        end)
    end




    editBox:HookScript("OnMouseDown", function(self, button)
        if searchFrame.setupMode then
            self.blockFocus = true
            return
        end
        if button ~= "LeftButton" then return end
        if EasyFind.db.lockPosition then return end
        if not IsShiftKeyDown() then return end
        self.blockFocus = true
        self._dragMoving = true
        if self:HasFocus() then self:ClearFocus() end
        searchFrame:StartMoving()
        StartDragRefresh()
    end)
    editBox:HookScript("OnMouseUp", function(self)
        if self._dragMoving and searchFrame:IsMovable() then
            searchFrame:StopMovingOrSizing()
            local point, _, relPoint, x, y = searchFrame:GetPoint()
            EasyFind.db.uiSearchPosition = {point, relPoint, x, y}
            StopDragRefresh()
        end
        self._dragMoving = false
        self.blockFocus = nil
    end)


    local placeholder = editBox:CreateFontString(nil, "ARTWORK", ns.SEARCHBAR_FONT)
    placeholder:SetPoint("LEFT", 2, 0)
    placeholder:SetPoint("RIGHT", editBox, "RIGHT", -2, 0)
    placeholder:SetJustifyH("LEFT")
    placeholder:SetWordWrap(false)
    placeholder:SetTextColor(0.5, 0.5, 0.5, 1.0)
    placeholder:SetText(L["SEARCH_PLACEHOLDER"])
    editBox.placeholder = placeholder

    editBox:SetScript("OnEditFocusGained", function(self)
        if self.blockFocus then






            if self:IsMouseOver() and IsMouseButtonDown("LeftButton")
                and not self._dragMoving and not searchFrame.setupMode then
                self.blockFocus = nil
            else
                self:ClearFocus()
                return
            end
        end



        if self._efClipboardHold then return end
        if selectedIndex > 0 then
            selectedIndex = 0
            toggleFocused = false
            Results:UpdateSelectionHighlight(true)
        end


        if searchFrame.ClearToolbarFocus then searchFrame.ClearToolbarFocus() end




        if not searchFrame._efProvidersWarmed then
            searchFrame._efProvidersWarmed = true
            Search:WarmSearchHotPath()
            if ns.Database and ns.Database.LoadDeferredSyncProvidersStaggered then
                ns.Database:LoadDeferredSyncProvidersStaggered()
            elseif ns.Database and ns.Database.WarmSearchHotPath then
                ns.Database:WarmSearchHotPath()
            end
        end



        if ns.RequestItemCatalog and not ns.ItemSearch and ns.CategoryMap then
            local uiFilters = EasyFind.db and EasyFind.db.uiSearchFilters
            if not (uiFilters and ns.CategoryMap.IsProviderFilterOff(uiFilters, "catalog")) then
                ns.RequestItemCatalog(false)
            end
        end



        if ns.RequestSettingsSearch and ns.CategoryMap then
            local uiFilters = EasyFind.db and EasyFind.db.uiSearchFilters
            local bothOff = uiFilters
                and ns.CategoryMap.IsProviderFilterOff(uiFilters, "gameOptions")
                and ns.CategoryMap.IsProviderFilterOff(uiFilters, "addonOptions")
            if not bothOff and ns.RequestSettingsSearch(false) and ns.BlizzOptionsSearch.EnsurePopulatedAsync then
                ns.BlizzOptionsSearch:EnsurePopulatedAsync(nil)
            end
        end
        local text = self:GetText() or ""
        if text == "" then




            Results:ShowEmptyQueryView()
        else



            self:HighlightText(0, #text)
            self:SetCursorPosition(#text)

            if resultsFrame and not resultsFrame:IsShown() then
                Search:OnSearchTextChanged(text, true)
            end
        end
    end)

    editBox:SetScript("OnEditFocusLost", function(self)

        if selectingResult then return end



        if self._dragMoving then
            self:HighlightText(0, 0)
            return
        end




        if self._efClipboardHold then return end



        if self._menuUnfocus then
            self:HighlightText(0, 0)
            return
        end



        self:HighlightText(0, 0)





        if selectedIndex > 0 then return end
        if Results:IsGridNavActive() then return end




        local onGuard = false
        if resultsFrame and resultsFrame:IsMouseOver() then onGuard = true end
        if not onGuard and OptionsSurface:IsOptionsSurfaceMouseOver() then onGuard = true end
        if not onGuard and Filters.IsMouseInFilterChain() then onGuard = true end
        if not onGuard and Utils.IsClickGuardMouseOver() then onGuard = true end
        if not onGuard and resultsFrame and resultsFrame:IsShown() then
            Results:HideResults()
        end


        if EasyFind.db.smartShow and not onGuard then
            searchFrame.smartShowFadeOut()
        end
        if strtrim(self:GetText()) == "" then
            self:SetText("")
            self.placeholder:Show()



            Utils.SafeAfter(0, function()





                if onGuard then return end
                if selectingResult then return end
                if searchFrame.editBox:HasFocus() then return end
                if navFrame and navFrame:IsKeyboardEnabled() then return end
                if strtrim(searchFrame.editBox:GetText()) ~= "" then return end
                if Results:ConsumeKeepPinnedResultsOpen() and Results:HasPinnedItems() then
                    Results:ShowEmptyQueryView()
                    if searchFrame.editBox.blockFocus then
                        searchFrame.editBox.blockFocus = nil
                    end
                    return
                end

                local sf = _G["EasyFindSpecFlyout"]
                local ssf = _G["EasyFindSpecSubFlyout"]
                if (sf and sf:IsShown()) or (ssf and ssf:IsShown()) then return end
                local dd = _G["EasyFindUIFilterDropdown"]
                if dd and dd:IsShown() then return end
                if OptionsSurface:IsOptionsSurfaceMouseOver() then return end
                Results:HideResults()

                if EasyFind.db.smartShow then
                    searchFrame.smartShowFadeOut()
                end
            end)
        end
    end)

    local lastTypedLen = 0
    local lastSearchTime = 0
    local pendingUISearchText = ""
    local pendingUISearchGrew = false
    local pendingUISearchDue = 0
    local pendingUISearchFrame = CreateFrame("Frame")
    pendingUISearchFrame:Hide()
    Utils.SafeOnUpdate(pendingUISearchFrame, function(self)
        if GetTime() < pendingUISearchDue then return end
        self:Hide()
        local typedNow = pendingUISearchText
        local grew = pendingUISearchGrew
        pendingUISearchText = ""
        pendingUISearchGrew = false
        lastSearchTime = GetTime()
        Search:OnSearchTextChanged(typedNow)
        if grew and editBox.UpdateAutocomplete then
            editBox.UpdateAutocomplete()
        end
    end)
    local function ResetPendingUISearch()
        pendingUISearchFrame:Hide()
        pendingUISearchText = ""
        pendingUISearchGrew = false
        pendingUISearchDue = 0
        lastTypedLen = 0
        SearchHistory:ResetSearchHistory()
    end
    editBox.ResetPendingSearch = ResetPendingUISearch
    local SEARCH_THROTTLE = 0.05
    editBox:SetScript("OnTextChanged", function(self, userInput)
        self.placeholder:SetShown(self:GetText() == "")
        if userInput then
            local restored, restoreText = Utils.ConsumeSuppressedAltNavChar(self)
            if restored then
                self.placeholder:SetShown((restoreText or "") == "")
                return
            end













            local frame = Search:GetSearchFrame()
            if frame and frame.IsAltNavRepeatKey and frame.IsAltNavRepeatKey() then
                local text = self:GetText() or ""
                local lastChar = text:sub(-1):lower()
                if lastChar == "j" or lastChar == "k" then
                    local cleaned = text:sub(1, -2)
                    self:SetText(cleaned)
                    self:SetCursorPosition(#cleaned)
                    self.placeholder:SetShown(cleaned == "")
                    Utils.SuppressNextAltNavChar(self, lastChar)
                end
                return
            end
        end









        if not userInput then
            if self:GetText() == "" and self.ResetPendingSearch then
                self:ResetPendingSearch()
            end
            return
        end
        if self.IsAutocompleteBackspaceStrip and self:IsAutocompleteBackspaceStrip() then return end
        SearchHistory:ResetSearchHistory()
        if Filters:HandleQuickFilterTextChanged(self) then return end





        local cursorPos = self:GetCursorPosition() or #(self:GetText() or "")
        local typedNow = (self:GetText() or ""):sub(1, cursorPos)
        local grew = #typedNow > lastTypedLen
        lastTypedLen = #typedNow
        local elapsed = GetTime() - lastSearchTime
        local delay = elapsed >= SEARCH_THROTTLE and 0 or (SEARCH_THROTTLE - elapsed)
        pendingUISearchText = typedNow
        pendingUISearchGrew = grew
        pendingUISearchDue = GetTime() + delay
        pendingUISearchFrame:Show()
    end)

    editBox:SetScript("OnEnterPressed", function(self)







        if self.StripAutocomplete then self:StripAutocomplete() end
        local typed = strtrim(self:GetText() or "")




        if typed ~= "" and typed:sub(1, 1) ~= "/" then
            SearchHistory:PushSearchHistory(typed)
        end
        SearchHistory:ResetSearchHistory()



        if Results:IsGridShown()
           and not (Results:IsGridNavActive()) then
            Results:MoveGridFocus(0, 1)
            return
        end





        if selectedIndex == 0 then


            local target, firstPinned
            for i = 1, Results:RowCount() do
                local row = Results:RowEntry(i)
                if not row then break end
                if not row.isPinHeader then
                    if row.isPinned then
                        if not firstPinned then firstPinned = i end
                    else
                        target = i
                        break
                    end
                end
            end
            local idx = target or firstPinned
            if not idx then return end
            selectedIndex = idx
            toggleFocused = false
            Results:UpdateSelectionHighlight()
            local row = Results:RowFrame(idx)
            if row and row.data and row.data.calculatorResult then
                Calculator:ArmCalculatorResultFromRow(row, "key")
            end
            return
        end
        Results:ActivateSelected("key")
    end)

    editBox:SetScript("OnEscapePressed", function(_)
        Search:HandleEscape()
    end)













    local StripMarkup = Utils.StripMarkup

    Utils.AttachAutocomplete(editBox, {
        enabled = function() return EasyFind.db.searchAutocomplete ~= false end,
        findCandidate = function(typed)
            if not typed or typed == "" then return nil end
            local lower = typed:lower()
            for i = 1, MAX_BUTTON_POOL do
                local row = resultButtons[i]
                if not row or not row:IsShown() then break end
                local quickDef = row.data and row.data.quickFilterDef
                local quickToken = quickDef and Filters:GetQuickFilterCompletionToken(quickDef, typed)
                if quickToken then
                    return quickToken
                end
                local rawName = row.data and row.data.name
                local nm = StripMarkup(rawName)
                if nm and #nm >= #typed then
                    local prefix = nm:sub(1, #typed):lower()
                    if prefix == lower and nm:lower() ~= lower then
                        return nm
                    end
                end
            end
            return nil
        end,
        backspaceAutocompleteTarget = function(_, typed)
            if not Filters:IsQuickFilterSuggestionsActive() or not typed then return nil end
            if not typed:match("^%s*@" .. Filters.TAG_CHARS .. "*$") then return nil end
            local text = typed:sub(1, -2)
            return text, #text
        end,
        onBackspaceAutocompleteRestored = function(box, text)
            if box and box.placeholder then
                box.placeholder:SetShown((box:GetText() or "") == "")
            end
            if box and box.ResetPendingSearch then
                box:ResetPendingSearch()
            end
            if box and Filters:UpdateQuickFilterSuggestions(box) then
                return
            end
            Search:OnSearchTextChanged(text or "", true)
        end,
        onAccepted = function(text)
            if text and text ~= "" then
                local box = searchFrame and searchFrame.editBox
                if box and text:match("^%s*@" .. Filters.TAG_CHARS .. "+$") and Filters:UpdateQuickFilterSuggestions(box) then
                    return
                end
                Search:OnSearchTextChanged(text, true)
            end
        end,
    })







    if not Search._chatLinkHooked then
        Search._chatLinkHooked = true
        Utils.HookInsertLink(function(text)
            if not text or text == "" then return end
            local box = searchFrame and searchFrame.editBox
            if box and box:IsVisible() and box:HasFocus() then


                local name = text:match("|h%[(.-)%]|h") or text
                box:Insert(name)
            end
        end)
    end

    local filterBtn = CreateFrame("Button", "EasyFindUIFilterButton", searchFrame)
    filterBtn:SetPoint("TOP", searchFrame, "TOP", 0, 0)
    filterBtn:SetPoint("BOTTOM", searchFrame, "BOTTOM", 0, 0)
    filterBtn:SetPoint("RIGHT", searchFrame, "RIGHT", 0, 0)
    filterBtn:SetWidth(searchFrame:GetHeight())


    filterBtn:SetFrameLevel(searchFrame:GetFrameLevel() + 50)

    local filterArrow = filterBtn:CreateTexture(nil, "OVERLAY")
    filterArrow:SetSize(11, 11)



    filterArrow:SetPoint("CENTER", 0, -1)


    filterArrow:SetTexture(ns.FILTER_ARROW_TEX)
    filterArrow:SetBlendMode("ADD")
    filterArrow:SetVertexColor(1, 1, 1)
    filterBtn.arrow = filterArrow

    local filterBtnBg = filterBtn:CreateTexture(nil, "ARTWORK")
    filterBtnBg:SetAllPoints()
    filterBtnBg:SetTexture(796424)
    filterBtnBg:Hide()
    filterBtn.btnBg = filterBtnBg

    filterBtn:SetHighlightTexture(130757)





    if theme.searchBarRounded then









        local innerInset = 6
        filterBtnBg:SetTexture("Interface\\AddOns\\EasyFind\\textures\\filter-glow")
        filterBtnBg:SetVertexColor(1, 1, 1)
        filterBtnBg:SetBlendMode("BLEND")
        filterBtnBg:ClearAllPoints()
        filterBtnBg:SetPoint("TOPLEFT",     filterBtn, "TOPLEFT",      innerInset, -innerInset)
        filterBtnBg:SetPoint("BOTTOMRIGHT", filterBtn, "BOTTOMRIGHT", -innerInset,  innerInset)
        local hl = filterBtn:GetHighlightTexture()
        if hl then hl:SetTexture(nil) end
    end

    local FILTER_TOOLTIP_DELAY = ns.TOOLTIP_HOVER_DELAY
    filterBtn:SetScript("OnEnter", function(self)
        self.btnBg:Show()
        local token = (self._tooltipToken or 0) + 1
        self._tooltipToken = token
        Utils.SafeAfter(FILTER_TOOLTIP_DELAY, function()
            if self._tooltipToken ~= token or not self:IsMouseOver() then return end
            if searchFrame.filterDropdown and searchFrame.filterDropdown:IsShown() then return end
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            ns.ResultTooltips.ApplySearchTooltipScale(GameTooltip)
            GameTooltip:SetText(L["FILTER_RESULTS"])
            GameTooltip:AddLine(L["FILTER_RESULTS_TT"], 1, 1, 1, true)
            GameTooltip:Show()
        end)
    end)
    filterBtn:SetScript("OnLeave", function(self)
        self._tooltipToken = (self._tooltipToken or 0) + 1


        local dd = searchFrame.filterDropdown
        if not self.keyboardFocused and not (dd and dd:IsShown()) then
            self.btnBg:Hide()
        end
        GameTooltip_Hide()
    end)


    filterBtn.SetMenuEngaged = function(self, engaged)
        if engaged then
            self.btnBg:Show()
        elseif not self:IsMouseOver() and not self.keyboardFocused then
            self.btnBg:Hide()
        end
    end
    searchFrame.filterBtn = filterBtn

    editBox:ClearAllPoints()
    editBox:SetPoint("LEFT", iconHolder, "RIGHT", 0, 0)
    editBox:SetPoint("RIGHT", filterBtn, "LEFT", -4, 0)
    self:CreateQuickFilterPill(searchFrame, editBox, iconHolder, filterBtn)
    self:UpdateQuickFilterPill()







    searchFrame:HookScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or IsShiftKeyDown() or self.setupMode then return end
        if (filterBtn and filterBtn:IsMouseOver())
           or (iconHolder and iconHolder:IsMouseOver()) then
            return
        end
        if activeKeybindBtn and activeKeybindBtn._stopCapture then
            activeKeybindBtn._stopCapture(activeKeybindBtn)
        end
        editBox.blockFocus = nil
        editBox:SetFocus()
    end)




    local keyRepeat = Utils.CreateKeyRepeat(searchFrame)
    local StartKeyRepeat = keyRepeat.Start
    local StopKeyRepeat  = keyRepeat.Stop
    searchFrame.StartKeyRepeat = StartKeyRepeat
    searchFrame.StopKeyRepeat  = StopKeyRepeat
    searchFrame.IsRepeatKey    = keyRepeat.IsKey

    local function MoveDown1() Results:MoveSelection(1) end
    local function MoveDown5() Results:MoveSelection(5) end
    local function MoveUp5() Results:MoveSelection(-5) end
    local function GridFocusLeft() Results:MoveGridFocus(-1, 0) end
    local function GridFocusRight() Results:MoveGridFocus(1, 0) end





    local function EnterAboveOrStepUp()



        if selectedIndex == 0
           and not (Results:IsGridNavActive()) then
            Results:JumpToEnd()
        else
            Results:MoveSelection(-1, true, true)
        end
    end




    searchFrame.IsAltNavRepeatKey = function()
        return keyRepeat.IsKey("J") or keyRepeat.IsKey("K")
            or keyRepeat.IsKey("UP") or keyRepeat.IsKey("DOWN")
    end

    local function RefocusEditBoxAfterNav()
        if selectedIndex ~= 0 then return end




        if Results:IsGridNavActive() then return end
        if not searchFrame or not searchFrame:IsShown() then return end
        if not editBox then return end




        if editBox._altNavMaxLettersSaved then
            editBox:SetMaxLetters(editBox._altNavMaxLettersSaved)
            editBox._altNavMaxLettersSaved = nil
        end
        if editBox:HasFocus() then return end
        editBox.blockFocus = nil
        editBox:SetFocus()
    end

    local function StopRepeatAndMaybeRefocus(key)
        key = Utils.NormalizeKey(key)
        if not keyRepeat.IsKey(key) then return end









        if Utils.IsPhysicalKeyDown(key) then return end
        StopKeyRepeat(key)
        RefocusEditBoxAfterNav()
    end






    local function RefocusEditBoxForHistoryNav()
        if not editBox then return end
        if editBox:HasFocus() then return end
        editBox.blockFocus = nil
        editBox:SetFocus()
    end

    local function StepAltJ()
        if SearchHistory:IsSearchHistoryActive() then
            RefocusEditBoxForHistoryNav()
            return SearchHistory:NavigateSearchHistory(-1)
        end
        return Results:MoveSelection(1, true, true)
    end

    local function StepAltK()


        if selectedIndex > 0
           or (Results:IsGridNavActive()) then
            return Results:MoveSelection(-1, true, true)
        end
        RefocusEditBoxForHistoryNav()
        return SearchHistory:NavigateSearchHistory(1)
    end

    local function StartAltNavRepeat(key, step)
        Utils.StartAltNavRepeat(keyRepeat, key, editBox, step, RefocusEditBoxAfterNav)
    end








    editBox:SetScript("OnKeyDown", function(self, key)







        if not self:HasFocus() then
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", true)
            return
        end
        local navKey = key and key:upper() or key


        if IsAltKeyDown() and navKey and navKey:match("^[A-Z]$") then
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
        end
        if IsAltKeyDown() and (navKey == "J" or navKey == "K") then
            Utils.SuppressNextAltNavChar(self, navKey)
        end
        Search:HandleCalculatorPasteIntoSearch(self, key)
        if Search:HandleCalculatorOpenShortcut(self, key) then
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
            return
        end
        if Filters:HandleQuickFilterKeyDown(self, key) then
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
            return
        end

        local shortcutIndex = Shortcuts:GetResultShortcutIndex(key)
        if shortcutIndex then










            Utils.SwallowNextCharInsert(self, tostring(shortcutIndex))
            local shortcutResult = Shortcuts:ActivateVisibleResultShortcut(shortcutIndex)
            if shortcutResult then
                Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", shortcutResult == "binding")
                return
            end
        end

        if ns.ResultRowActions and ns.ResultRowActions.HandleKey(self, key) then
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
            return
        end




        local mod = ""
        if IsAltKeyDown()     then mod = mod .. "ALT-"  end
        if IsControlKeyDown() then mod = mod .. "CTRL-" end
        if IsShiftKeyDown()   then mod = mod .. "SHIFT-" end
        local boundAction = GetBindingAction and GetBindingAction(mod .. key)
        if boundAction and string.sub(boundAction, 1, 9) == "EASYFIND_" then
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", true)
            return
        end
        if self.HasAutocomplete and self:HasAutocomplete() and self.AcceptAutocomplete then
            if key == "RIGHT" or key == "ARROWRIGHT" then
                self:AcceptAutocomplete("right")
                Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
                return
            elseif navKey == "L" and IsAltKeyDown() then
                self:AcceptAutocomplete("alt-l")
                Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
                return
            end
        end




        if key == "TAB" then
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
            if not (self.HasAutocomplete and self:HasAutocomplete()) then





                if Results:IsGridShown()
                   and Results:MoveGridFocus(0, 0) then
                    return
                end
                self._menuUnfocus = true
                self:ClearFocus()
                self._menuUnfocus = nil
                Utils.SafeCallMethod(navFrame, "EnableKeyboard", true)
                if searchFrame.SetToolbarFocus then searchFrame.SetToolbarFocus(1) end
            end
            return
        end





        if key == "ENTER" and self.StripAutocomplete then
            self:StripAutocomplete()
        end






        local isAltJ = IsAltKeyDown() and navKey == "J"
        local isAltK = IsAltKeyDown() and navKey == "K"
        if isAltK or isAltJ then
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)








            if not self._altNavMaxLettersSaved then
                self._altNavMaxLettersSaved = self:GetMaxLetters() or 0
                self:SetMaxLetters(#(self:GetText() or ""))
            end
            StartAltNavRepeat(navKey, isAltK and StepAltK or StepAltJ)
            return
        end

        local isUpHist   = key == "UP"
        local isDownHist = key == "DOWN"
        if isUpHist then
            if SearchHistory:NavigateSearchHistory(1) then
                Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
                return
            end


            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
            return
        elseif isDownHist then
            if SearchHistory:IsSearchHistoryActive() then
                SearchHistory:NavigateSearchHistory(-1)
                Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
                return
            end


        end

        if resultsFrame and resultsFrame:IsShown() and selectedIndex == 0 then




            if EasyFind.db.uiResultsAbove then
                if key == "UP" then StartKeyRepeat("UP", EnterAboveOrStepUp) end
            else
                if key == "DOWN" then StartKeyRepeat("DOWN", MoveDown1) end
            end
        end
        Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
    end)




    editBox:SetScript("OnKeyUp", function(_, key)
        StopRepeatAndMaybeRefocus(key)
    end)

    searchFrame.editBox = editBox


    local toolbarFocus = 0

    local toolbarHighlight = CreateFrame("Frame", nil, UIParent)
    toolbarHighlight:SetFrameStrata("LOW")
    toolbarHighlight:SetFrameLevel(searchFrame:GetFrameLevel() + 100)
    toolbarHighlight:Hide()
    searchFrame.toolbarHighlight = toolbarHighlight
    local tbHL = toolbarHighlight:CreateTexture(nil, "OVERLAY")
    tbHL:SetAllPoints()
    tbHL:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    tbHL:SetBlendMode("ADD")
    tbHL:SetVertexColor(Utils.RGB(GOLD_COLOR, 0.5))
    toolbarHighlight.tex = tbHL

    local TOOLBAR_CONTROLS = { filterBtn }
    local function GetToolbarControls()



        local apps = searchFrame.appsBtn
        if apps and apps:IsShown() then
            TOOLBAR_CONTROLS[1] = apps
            TOOLBAR_CONTROLS[2] = filterBtn
        else
            TOOLBAR_CONTROLS[1] = filterBtn
            TOOLBAR_CONTROLS[2] = nil
        end
        return TOOLBAR_CONTROLS
    end

    local function SetToolbarFocus(idx)
        local prevControls = GetToolbarControls()
        local prevTarget = prevControls[toolbarFocus]
        if prevTarget then
            prevTarget.keyboardFocused = nil
            if prevTarget.btnBg then prevTarget.btnBg:Hide() end
            if prevTarget.UnlockHighlight then prevTarget:UnlockHighlight() end
            if prevTarget.RefreshReveal then prevTarget.RefreshReveal() end
        end
        toolbarFocus = idx
        local controls = GetToolbarControls()
        local target = controls[idx]
        if target then
            target.keyboardFocused = true
            if target.RefreshReveal then target.RefreshReveal() end
            if target.btnBg then
                target.btnBg:Show()
                if target.LockHighlight then target:LockHighlight() end
                toolbarHighlight:Hide()
            elseif target.LockHighlight and target:GetHighlightTexture() then


                target:LockHighlight()
                toolbarHighlight:Hide()
            else
                toolbarHighlight:SetParent(target)
                toolbarHighlight:ClearAllPoints()
                toolbarHighlight:SetAllPoints(target)
                toolbarHighlight:Show()
            end
        else
            toolbarHighlight:Hide()
        end
    end

    local function ClearToolbarFocus()
        local controls = GetToolbarControls()
        local prevTarget = controls[toolbarFocus]
        if prevTarget then
            prevTarget.keyboardFocused = nil
            if prevTarget.btnBg then prevTarget.btnBg:Hide() end
            if prevTarget.UnlockHighlight then prevTarget:UnlockHighlight() end
            if prevTarget.RefreshReveal then prevTarget.RefreshReveal() end
        end
        toolbarFocus = 0
        toolbarHighlight:Hide()
    end
    searchFrame.ClearToolbarFocus = ClearToolbarFocus
    searchFrame.SetToolbarFocus = SetToolbarFocus


    navFrame = CreateFrame("Frame", nil, searchFrame)
    navFrame:SetSize(1, 1)
    Utils.SafeCallMethod(navFrame, "EnableKeyboard", false)
    Utils.SafeCallMethod(navFrame, "SetPropagateKeyboardInput", false)



    local function CycleFocus(reverse)
        if reverse then
            if selectedIndex > 0 and toggleFocused then
                toggleFocused = false
                Results:UpdateSelectionHighlight()
            elseif toolbarFocus > 0 then
                if toolbarFocus == 1 then
                    ClearToolbarFocus()
                    Utils.SafeCallMethod(navFrame, "EnableKeyboard", false)
                    searchFrame.editBox.blockFocus = nil
                    searchFrame.editBox:SetFocus()
                else
                    SetToolbarFocus(toolbarFocus - 1)
                end
            end
        else
            if selectedIndex > 0 and not toggleFocused then
                local row = Results:RowFrame(selectedIndex)
                local hasToggle = row and row.isPathNode and (
                    (row.headerTab and row.headerTab:IsShown()) or
                    (row.isPinHeader and row.pinToggle and row.pinToggle:IsShown())
                )
                if hasToggle then
                    toggleFocused = true
                    Results:UpdateSelectionHighlight()
                end
            elseif toolbarFocus > 0 then
                local controls = GetToolbarControls()
                if toolbarFocus >= #controls then
                    ClearToolbarFocus()
                    Utils.SafeCallMethod(navFrame, "EnableKeyboard", false)
                    searchFrame.editBox.blockFocus = nil
                    searchFrame.editBox:SetFocus()
                else
                    SetToolbarFocus(toolbarFocus + 1)
                end
            end
        end
    end

    local function HandleNavKeyDown(key)
        if Utils.IsModifierKey(key) then return end

        if Search:HandleCalculatorOpenShortcut(searchFrame and searchFrame.editBox, key) then return end
        if Search:HandleCalculatorCopyConfirmKey(key) then return end
        if Search:HandleCalculatorCopyKey(key) then return end

        local alt = IsAltKeyDown()
        local ctrl = IsControlKeyDown()
        local shift = IsShiftKeyDown()





        if ctrl and key == "C" then
            if selectedIndex > 0 and ns.RowCopy then
                ns.RowCopy:ArmFor(Results:RowFrame(selectedIndex), IsShiftKeyDown())
                return
            end
            if Results:ArmGridFocusCopy() then
                return
            end
        end




        if alt and key == "J" then
            if shift then
                Results:JumpToNextSection(1)
            else
                StartAltNavRepeat(key, StepAltJ)
            end
            return
        elseif alt and key == "K" then
            if shift then
                Results:JumpToNextSection(-1)
            else
                StartAltNavRepeat(key, StepAltK)
            end
            return
        elseif alt and key == "L" then


            if Results:IsGridNavActive() then
                Results:MoveGridFocus(1, 0)
            else
                CycleFocus(false)
            end
            return
        elseif alt and key == "H" then
            if Results:IsGridNavActive() then
                Results:MoveGridFocus(-1, 0)
            else
                CycleFocus(true)
            end
            return
        end

        if (key == "LEFT" or key == "RIGHT")
           and Results:IsGridNavActive() then
            StartKeyRepeat(key, key == "LEFT" and GridFocusLeft or GridFocusRight)
            return
        end







        if key == "RIGHT" and selectedIndex > 0 and not toggleFocused then
            local row = Results:RowFrame(selectedIndex)
            if row and Rows.ShowResultContextMenu and Rows:ShowResultContextMenu(row, true) then
                if searchFrame.StopKeyRepeat then searchFrame.StopKeyRepeat() end
            end
            return
        end

        if key == "DOWN" then
            if ctrl then
                Results:JumpToEnd()
            elseif shift then
                Results:JumpToNextSection(1)
            else





                StartKeyRepeat(key, StepAltJ)
            end
        elseif key == "UP" then
            if ctrl then
                Results:JumpToStart()
            elseif shift then
                Results:JumpToNextSection(-1)
            else





                StartKeyRepeat(key, StepAltK)
            end
        elseif key == "SPACE" then











            if selectedIndex > 0 then
                local row = Results:RowFrame(selectedIndex)

                if row and row.isSectionHeader then
                    Results:ActivateResultRow(row, "key")
                    return
                end
                if row then
                    local savedPinHeader    = row.isPinHeader
                    local savedPathName     = row.isPathNode and row.pathNodeName
                    local savedPathDepth    = row.isPathNode and row.pathNodeDepth
                    if row.isPinHeader and row.pinToggle and row.pinToggle:IsShown() then
                        local handler = row.pinToggle:GetScript("OnClick")
                        if handler then handler(row.pinToggle, "LeftButton") end
                    elseif row.toggleBtn and row.toggleBtn:IsShown() then
                        local handler = row.toggleBtn:GetScript("OnClick")
                        if handler then handler(row.toggleBtn, "LeftButton") end
                    end
                    for i = 1, MAX_BUTTON_POOL do
                        local rb = resultButtons[i]
                        if not rb then break end
                        if rb:IsShown() then
                            local match = false
                            if savedPinHeader and rb.isPinHeader then
                                match = true
                            elseif savedPathName and rb.isPathNode
                               and rb.pathNodeName == savedPathName
                               and rb.pathNodeDepth == savedPathDepth then
                                match = true
                            end
                            if match then
                                selectedIndex = i
                                toggleFocused = false
                                Results:UpdateSelectionHighlight()
                                break
                            end
                        end
                    end
                end
            end
            return
        elseif key == "PAGEDOWN" then
            StartKeyRepeat(key, MoveDown5)
        elseif key == "PAGEUP" then
            StartKeyRepeat(key, MoveUp5)
        elseif key == "HOME" then
            Results:JumpToStart()
        elseif key == "END" then
            Results:JumpToEnd()
        elseif key == "TAB" then
            if Filters:IsQuickFilterSuggestionsActive() and Filters:AcceptQuickFilterSuggestion() then
                return
            end


            if not shift and Results:IsGridNavActive() then
                if Results:OpenGridFocusMenu() then
                    if searchFrame.StopKeyRepeat then searchFrame.StopKeyRepeat() end
                    return
                end
            end
            if not shift and selectedIndex > 0 and not toggleFocused then
                local row = Results:RowFrame(selectedIndex)

                if row and row.gpsBtn and row.gpsBtn:IsShown() and not Search:GPSKeyFocusRow() then
                    Search:SetGPSKeyFocus(row)
                    if searchFrame.StopKeyRepeat then searchFrame.StopKeyRepeat() end
                    return
                end
                Search:SetGPSKeyFocus(nil)
                if row and Rows.ShowResultContextMenu and Rows:ShowResultContextMenu(row, true) then
                    if searchFrame.StopKeyRepeat then searchFrame.StopKeyRepeat() end
                    return
                end
            end
            if shift and Search:GPSKeyFocusRow() then
                Search:SetGPSKeyFocus(nil)
                return
            end
            CycleFocus(shift)
        elseif key == "ENTER" then
            local gpsRow = Search:GPSKeyFocusRow()
            if toolbarFocus > 0 then
                local controls = GetToolbarControls()
                local target = controls[toolbarFocus]
                if target then target:Click() end
            elseif gpsRow then
                Search:SetGPSKeyFocus(nil)
                gpsRow.gpsBtn:Click()
            else
                Results:ActivateSelected("key")
            end
        elseif key == "ESCAPE" then






            if toolbarFocus > 0 then
                ClearToolbarFocus()
            end
            Search:SetGPSKeyFocus(nil)
            if selectedIndex > 0 or toggleFocused then
                selectedIndex = 0
                toggleFocused = false
                Results:UpdateSelectionHighlight(true)
            end
            if Results:IsGridNavActive() then
                Results:ExitGridNav(false)
            end
            Utils.SafeCallMethod(navFrame, "EnableKeyboard", false)
            if searchFrame.StopKeyRepeat then searchFrame.StopKeyRepeat() end
            Search:HandleEscape()
        else


            if selectedIndex == 0 and not searchFrame.editBox:HasFocus()
               and not (Results:IsGridNavActive()) then
                Utils.SafeCallMethod(navFrame, "SetPropagateKeyboardInput", true)
                return
            end






            ClearToolbarFocus()
        end
    end

    navFrame:SetScript("OnKeyDown", function(self, key)








        if selectedIndex == 0 and toolbarFocus == 0
            and not (resultsFrame and resultsFrame:IsShown()) then
            Utils.SafeCallMethod(self, "EnableKeyboard", false)
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", true)
            return
        end
        if Search:HandleCalculatorOpenShortcut(searchFrame and searchFrame.editBox, key) then
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
            return
        end
        if ns.ResultRowActions and ns.ResultRowActions.HandleKey(nil, key) then
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
            return
        end

        if Calculator:IsCalculatorCopyConfirmKey(key) then
            Search:RearmActiveCalculatorCopy("confirm")
            Utils.SafeAfter(0, function()
                Search:ConfirmCalculatorCopied()
            end)



            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
            return
        end

        local shortcutIndex = Shortcuts:GetResultShortcutIndex(key)
        if shortcutIndex then
            local shortcutResult = Shortcuts:ActivateVisibleResultShortcut(shortcutIndex)
            if shortcutResult then
                Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", shortcutResult == "binding")
                return
            end
        end





        if key == "ENTER" and selectedIndex > 0 and not InCombatLockdown() then
            local selRow = Results:RowFrame(selectedIndex)
            local rd = selRow and selRow.data

            if rd and Icons:IsSecureActionResult(rd) and not Search:GPSKeyFocusRow() then
                Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", true)
                return
            end
        end




        local consume = false
        if key == "DOWN" or key == "UP" or key == "PAGEDOWN" or key == "PAGEUP"
            or key == "HOME" or key == "END" or key == "TAB" or key == "ENTER"
            or key == "ESCAPE" then
            consume = true
        elseif (key == "LEFT" or key == "RIGHT")
            and Results:IsGridNavActive() then


            consume = true
        elseif key == "RIGHT" and selectedIndex > 0 and not toggleFocused then


            consume = true
        elseif Calculator:IsCalculatorCopyKey(key) then
            consume = true
        elseif key == "C" and IsControlKeyDown() and ns.RowCopy
            and ((selectedIndex > 0 and ns.RowCopy:CanCopy(Results:RowFrame(selectedIndex), IsShiftKeyDown()))
                or (Results:IsGridNavActive())) then
            consume = true
        elseif IsAltKeyDown() and (key == "J" or key == "K" or key == "L" or key == "H") then
            consume = true
        elseif key == "SPACE" then




            local row = selectedIndex > 0 and Results:RowFrame(selectedIndex)
            local hasToggle = row and (
                ((row.isPinHeader or row.isSectionHeader) and row.pinToggle and row.pinToggle:IsShown())
                or (row.toggleBtn and row.toggleBtn:IsShown()))
            if hasToggle then consume = true end
        end
        if consume then
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
            HandleNavKeyDown(key)
        else
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", true)
        end
    end)
    navFrame:SetScript("OnKeyUp", function(_, key)
        StopRepeatAndMaybeRefocus(key)
    end)










    Utils.AttachEscClose(searchFrame, function()
        Search:HandleEscape(true)
    end, function()



        if ns.GetVisibilityMode() ~= ns.VISIBILITY_ALWAYS then return true end
        return Search:HasDismissableEscState()
    end)
    if searchFrame.filterDropdown then
        searchFrame.filterDropdown:HookScript("OnShow", Utils.RefreshEscArm)
        searchFrame.filterDropdown:HookScript("OnHide", Utils.RefreshEscArm)
    end









    searchFrame:RegisterForDrag("LeftButton")
    searchFrame:SetScript("OnDragStart", function(self)
        if EasyFind.db.lockPosition then return end
        self:StartMoving()
        StartDragRefresh()
    end)
    searchFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        EasyFind.db.uiSearchPosition = {point, relPoint, x, y}
        StopDragRefresh()
    end)

    self:UpdateScale()
    self:UpdateOpacity()


    local hoverZone = CreateFrame("Frame", "EasyFindHoverZone", UIParent)
    hoverZone:SetFrameStrata("LOW")
    hoverZone:SetFrameLevel(searchFrame:GetFrameLevel() - 1)
    hoverZone:EnableMouse(true)
    hoverZone:SetSize(340, 76)
    hoverZone:SetPoint("CENTER", searchFrame, "CENTER", 0, 0)
    hoverZone:Hide()
    searchFrame.hoverZone = hoverZone

    local smartShowVisible = false
    local smartShowTimer = nil

    local function SmartShowFadeIn()
        if smartShowTimer then smartShowTimer:Cancel(); smartShowTimer = nil end
        if EasyFind.db.visible == false then return end
        if not smartShowVisible then
            smartShowVisible = true
            UIFrameFadeIn(searchFrame, 0.15, searchFrame:GetAlpha(), 1.0)
            searchFrame:Show()
        end
    end

    local function SmartShowFadeOut()
        if EasyFind.db.visible == false then return end
        if searchFrame.editBox:HasFocus() then return end
        if resultsFrame and resultsFrame:IsShown() then return end

        if searchFrame.resizing then return end
        if smartShowTimer then smartShowTimer:Cancel() end
        smartShowTimer = C_Timer.NewTimer(0.4, function()
            smartShowTimer = nil




            if not EasyFind.db.smartShow then return end
            if searchFrame.editBox:HasFocus() then return end
            if resultsFrame and resultsFrame:IsShown() then return end
            if searchFrame.resizing then return end
            if hoverZone:IsMouseOver() or searchFrame:IsMouseOver() then return end
            smartShowVisible = false
            UIFrameFadeOut(searchFrame, 0.25, searchFrame:GetAlpha(), 0)
            Utils.SafeAfter(0.25, function()
                if not smartShowVisible and EasyFind.db.smartShow then
                    searchFrame:SetAlpha(0)
                end
            end)
        end)
    end

    hoverZone:SetScript("OnEnter", SmartShowFadeIn)
    hoverZone:SetScript("OnLeave", SmartShowFadeOut)
    searchFrame:HookScript("OnEnter", function()
        if EasyFind.db.smartShow then SmartShowFadeIn() end
    end)
    searchFrame:HookScript("OnLeave", function()
        if EasyFind.db.smartShow then SmartShowFadeOut() end
    end)

    searchFrame.smartShowFadeIn = SmartShowFadeIn
    searchFrame.smartShowFadeOut = SmartShowFadeOut
    searchFrame.smartShowVisible = function() return smartShowVisible end
    searchFrame.setSmartShowVisible = function(val) smartShowVisible = val end
    searchFrame.cancelSmartShowTimer = function()
        if smartShowTimer then
            smartShowTimer:Cancel()
            smartShowTimer = nil
        end
    end

    self:CreateUIFilterDropdown(filterBtn, searchFrame, editBox)


    if ns.AppsMenu then ns.AppsMenu:Create(searchFrame, filterBtn) end


    for _, btn in ipairs({ filterBtn, searchFrame.appsBtn }) do
        btn:RegisterForDrag("LeftButton")
        btn:SetScript("OnDragStart", function() searchFrame:GetScript("OnDragStart")(searchFrame) end)
        btn:SetScript("OnDragStop", function() searchFrame:GetScript("OnDragStop")(searchFrame) end)
    end




    local filterDropdown = _G["EasyFindUIFilterDropdown"]
    Utils.InstallBarControlReveal(filterBtn,
        function() return EasyFind.db.showFilterButton ~= false end,
        function() return filterDropdown and filterDropdown:IsShown() end)
    if filterDropdown then
        filterDropdown:HookScript("OnShow", filterBtn.RefreshReveal)
        filterDropdown:HookScript("OnHide", filterBtn.RefreshReveal)
    end






    searchFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    searchFrame:HookScript("OnHide", function()
        Search:HideQuickFilterSuggestions()
    end)
    searchFrame:HookScript("OnEvent", function(self, event)
        if event ~= "GLOBAL_MOUSE_DOWN" then return end
        if not self:IsShown() then return end
        if not EasyFind.db.autoHide then return end



        if EasyFind._minimapClickActive then return end




        if EasyFind._inlineDropdownMenuOpen then return end



        if EasyFind._popupGraceUntil and GetTime() < EasyFind._popupGraceUntil then return end













        local mmBtn = _G["EasyFindMinimapButton"]
        local launchers = ns.brokerLauncherButtons
        local function IsLauncherTarget(frame)
            if not frame then return false end
            if mmBtn and frame == mmBtn then return true end
            return (launchers and launchers[frame]) and true or false
        end
        local foci = Utils.MouseFoci()
        for i = 1, #foci do
            if IsLauncherTarget(foci[i]) then return end
        end
        if self:IsMouseOver() then return end

        if ns.IsMouseOverWithBand and ns.IsMouseOverWithBand(containerFrame) then return end
        if Utils.IsFrameVisiblyMouseOver(resultsFrame) then return end
        if OptionsSurface:IsOptionsSurfaceMouseOver() then return end



        if Utils.IsCursorMenuMouseOver() then return end

        if Utils.IsCursorMenuShown() then return end
        if activeKeybindBtn then return end


        if Filters.IsMouseInFilterChain() then return end


        if Utils.IsClickGuardMouseOver() then return end
        if ns.NoteApplicationDismissed and ns.CurrentApplicationSurfaceID then
            ns.NoteApplicationDismissed(ns.CurrentApplicationSurfaceID())
        end
        Search:Hide()
    end)

end






function Search:Focus()
    if not searchFrame or not searchFrame:IsShown() then return end
    if inCombat then return end

    if searchFrame.editBox:HasFocus() then
        searchFrame.editBox:ClearFocus()
    else

        Utils.SafeAfter(0, function()
            if searchFrame and searchFrame:IsShown() then
                searchFrame.editBox.blockFocus = nil
                searchFrame.editBox:SetFocus()
            end
        end)
    end
end

function Search:Show(andFocus)
    if not searchFrame then return end
    if inCombat then return end
    local wasShown = searchFrame:IsShown()
    if not wasShown and Filters:GetQuickFilter() then
        self:ClearQuickFilter(false)
        if searchFrame.editBox then
            if searchFrame.editBox.ResetPendingSearch then searchFrame.editBox:ResetPendingSearch() end
            searchFrame.editBox:SetText("")
            if searchFrame.editBox.placeholder then searchFrame.editBox.placeholder:Show() end
        end
    end
    searchFrame:Show()
    if not (EasyFind.db.smartShow and not EasyFind.db.autoHide) then
        searchFrame:SetAlpha(1.0)
    end
    EasyFind.db.visible = true
    if EasyFind.db.smartShow and not EasyFind.db.autoHide then
        searchFrame.hoverZone:Show()
        searchFrame.smartShowFadeIn()
        Utils.SafeAfter(1.5, function()
            if EasyFind.db.smartShow then
                searchFrame.smartShowFadeOut()
            end
        end)
    end
    if andFocus or EasyFind.db.autoHide then
        Utils.SafeAfter(0, function()
            if searchFrame:IsShown() then
                searchFrame.editBox.blockFocus = nil
                searchFrame.editBox:SetFocus()
            end
        end)
    end
end

function Search:Hide()
    if not searchFrame then return end
    if ns.Database and ns.Database.CancelDynamicWarmup then
        ns.Database:CancelDynamicWarmup()
    end


    self:CloseFilterDropdownIfOpen()


    Utils.SafeCallMethod(searchFrame, "Hide")
    searchFrame.setSmartShowVisible(false)
    self:HideResults()
    searchFrame.editBox:ClearFocus()
    searchFrame.editBox.placeholder:SetShown(searchFrame.editBox:GetText() == "")
    EasyFind.db.visible = false


    searchFrame.hoverZone:Hide()
end












function Search:HandleEscape(fromUnfocused)


    if ns.ExtensionButtons and ns.ExtensionButtons.CancelDrag
       and ns.ExtensionButtons:CancelDrag() then
        return true
    end


    if ns.HideAllTogglePopups and ns.HideAllTogglePopups() then return true end





    if ns.ClearCarriedItemLink and ns.ClearCarriedItemLink() then return true end
    if not searchFrame or not searchFrame:IsShown() then return false end
    local editBox = searchFrame.editBox











    if searchFrame.StopKeyRepeat then searchFrame.StopKeyRepeat() end
    if editBox and editBox._altNavMaxLettersSaved then
        editBox:SetMaxLetters(editBox._altNavMaxLettersSaved)
        editBox._altNavMaxLettersSaved = nil
    end
    local function Refocus()
        if not editBox then return end





        editBox.blockFocus = nil
        editBox:SetFocus()
        Utils.SafeAfter(0, function()
            if not searchFrame or not searchFrame:IsShown() or not editBox then return end
            if editBox:HasFocus() then return end
            editBox.blockFocus = nil
            editBox:SetFocus()
        end)
        Utils.SafeAfter(0.05, function()
            if not searchFrame or not searchFrame:IsShown() or not editBox then return end
            if editBox:HasFocus() then return end
            editBox.blockFocus = nil
            editBox:SetFocus()
        end)
    end
    self._escClosingMenus = true






    local closedAny = false
    if EasyFind._inlineDropdownMenuOpen and Results and ns.ResultRows
       and ns.ResultRows.HideInlineSettingDropdown then
        closedAny = ns.ResultRows.HideInlineSettingDropdown() and true or false
    end
    if not closedAny and Utils.HideCursorMenus and Utils.HideCursorMenus() then
        closedAny = true
    end
    if not closedAny then
        closedAny = Filters.CloseTopFilterLayer and Filters.CloseTopFilterLayer() or false
    end


    local escSearchFrame = self:GetSearchFrame()
    if not closedAny and escSearchFrame and escSearchFrame.appsDropdown
       and escSearchFrame.appsDropdown:IsShown() then
        escSearchFrame.appsDropdown:Hide()
        closedAny = true
    end
    self._escClosingMenus = nil
    if closedAny then
        if not fromUnfocused then Refocus() end
        return true
    end




    if self:ShowUnappliedSettingsPopup() then return true end
    if fromUnfocused then
        if ns.GetVisibilityMode() == ns.VISIBILITY_ALWAYS then




            if editBox and (editBox:GetText() ~= "" or Filters:GetQuickFilter()) then
                if editBox.ResetPendingSearch then editBox:ResetPendingSearch() end
                editBox:SetText("")
                if editBox.placeholder then editBox.placeholder:Show() end
                self:ClearQuickFilter(false)
                self:HideQuickFilterSuggestions()
                self:OnSearchTextChanged("", true)
                return true
            end



            local hadResults = resultsFrame and resultsFrame:IsShown()
            Results:HideResults()
            return hadResults and true or false
        end
        self:Hide()


        return not searchFrame:IsShown()
    end
    if (editBox and editBox:GetText() ~= "") or Filters:GetQuickFilter() then
        if editBox and editBox.ResetPendingSearch then editBox:ResetPendingSearch() end
        if editBox then
            editBox:SetText("")
            if editBox.placeholder then editBox.placeholder:Show() end
        end
        self:ClearQuickFilter(false)
        self:HideQuickFilterSuggestions()
        Refocus()



        self:OnSearchTextChanged("", true)
        return true
    end
    if ns.GetVisibilityMode() == ns.VISIBILITY_ALWAYS then

        if editBox then editBox:ClearFocus() end
        return true
    end
    self:Hide()
    return not searchFrame:IsShown()
end



function Search:IsEscClosingMenus()
    return self._escClosingMenus
end


function Search:GetKeyNavDebug()
    return {
        navKeyboard = navFrame and navFrame:IsKeyboardEnabled() or false,
        selectedIndex = selectedIndex,
        editBoxFocus = searchFrame and searchFrame.editBox
            and searchFrame.editBox:HasFocus() or false,
        blockFocus = (searchFrame and searchFrame.editBox
            and searchFrame.editBox.blockFocus) and true or false,
    }
end




function Search:HasDismissableEscState()

    if ns.HasCarriedItemLink and ns.HasCarriedItemLink() then return true end
    if searchFrame and searchFrame.filterDropdown
        and searchFrame.filterDropdown:IsShown() then
        return true
    end
    if resultsFrame and resultsFrame:IsShown() then return true end
    local editBox = searchFrame and searchFrame.editBox
    if editBox and editBox:GetText() ~= "" then return true end
    if Filters.GetQuickFilter and Filters:GetQuickFilter() then return true end
    return false
end

function Search:ExpandFactionHeader(headerName)
    local headerNameLower = slower(headerName)
    local i, data = Utils.FindFactionByPredicate(function(d)
        return d.isHeader and d.name and slower(d.name) == headerNameLower
    end)
    if not i then return false end
    if not data.isHeaderExpanded then
        ns.Caps.SetFactionHeaderExpanded(i, true)
    end
    return true
end

function Search:Toggle()
    if not searchFrame then return end
    if inCombat then




        if searchFrame:IsShown() and searchFrame.combatShield
            and searchFrame.combatShield:IsShown() then
            combatToggledOff = not combatToggledOff
            ApplyAlwaysBarAlpha()
        end
        return
    end
    local tuckedBySmartShow = EasyFind.db.autoHide and (searchFrame:GetAlpha() or 1) <= 0.01
    if searchFrame:IsShown() and EasyFind.db.visible ~= false and not tuckedBySmartShow then
        self:Hide()
    else
        self:Show(false)
    end
end

function Search:ToggleFocus()
    if not searchFrame then return end
    if inCombat then return end
    local tuckedBySmartShow = EasyFind.db.autoHide and (searchFrame:GetAlpha() or 1) <= 0.01
    if searchFrame:IsShown() and EasyFind.db.visible ~= false and not tuckedBySmartShow then
        self:Hide()
    else
        self:Show(false)
        Utils.SafeAfter(0, function()
            if searchFrame and searchFrame:IsShown() then
                searchFrame.editBox.blockFocus = nil
                searchFrame.editBox:SetFocus()
            end
        end)
    end
end

function Search:UpdateScale()
    local scale = EasyFind.db.uiSearchScale or 1.0
    if searchFrame then
        searchFrame:SetScale(scale)
    end




    if containerFrame then
        containerFrame:SetScale(scale)
    end
    self:UpdateResultsScale()
end

function Search:UpdateResultsScale()
    if resultsFrame then
        resultsFrame:SetScale(EasyFind.db.uiResultsScale or 1.0)
        self:RefreshResults()
    end
end

function Search:UpdateWidth()
    if searchFrame then
        local w = 250 * (EasyFind.db.uiSearchWidth or 1.0)
        searchFrame:SetWidth(w)
    end
    self:UpdateResultsWidth()
end

function Search:UpdateResultsWidth()
    if resultsFrame then
        local w = EasyFind.db.uiResultsWidth
        if w and w > 1 then
            resultsFrame:SetWidth(w)
        end
    end
end

function Search:RefreshResults()
    local savedIndex = selectedIndex
    local savedToggle = toggleFocused




    if not Results:RefreshShownResults(true) then return end
    if savedIndex > 0 then
        selectedIndex = savedIndex
        toggleFocused = savedToggle
        self:UpdateSelectionHighlight()
    end



    for i = 1, #resultButtons do
        local row = resultButtons[i]
        if Utils.IsFrameVisiblyMouseOver(row) then
            Handlers:ApplyActionHint(row)
            break
        end
    end
end




function Search:RebuildOpenResults()
    if not searchFrame or not searchFrame.editBox then return end
    if not resultsFrame or not resultsFrame:IsShown() then return end
    local text = searchFrame.editBox:GetText()
    if text and text ~= "" then
        self:OnSearchTextChanged(text)
    else
        Results:ShowEmptyQueryView()
    end
end

function Search:UpdateOpacity()
    if not searchFrame then return end
    local alpha = ns.GetSearchWindowAlpha()
    if containerFrame then
        self:ApplySearchWindowFill(containerFrame)
        ns.SetRoundedRectBorderBgAlpha(containerFrame, alpha)
    end
    local filterDropdown = _G["EasyFindUIFilterDropdown"]
    if filterDropdown then
        ns.ApplyMenuOpacity(filterDropdown)
    end
end

function Search:UpdateSearchBarHeight()
    self:UpdateFontSize()
end



function Search:RefreshBarControlReveal()
    if not searchFrame then return end
    if searchFrame.filterBtn and searchFrame.filterBtn.RefreshReveal then
        searchFrame.filterBtn.RefreshReveal()
    end
    if searchFrame.appsBtn and searchFrame.appsBtn.RefreshReveal then
        searchFrame.appsBtn.RefreshReveal()
    end
end








function Search:UpdateWindowBorders()
    local shown = ns.WindowBorderOn()
    if containerFrame then ns.SetRoundedRectRingShown(containerFrame, shown) end
    local dropdown = searchFrame and searchFrame.filterDropdown
    if dropdown then
        ns.SetRoundedRectRingShown(dropdown, shown)
        if dropdown.guardFrames then
            for i = 1, #dropdown.guardFrames do
                ns.SetRoundedRectRingShown(dropdown.guardFrames[i], shown)
            end
        end
    end


    local pal = ns.ACTIVE_UI_PALETTE
    if pal and pal.chrome and ns.ApplyUITheme then
        for name, p in pairs(ns.UI_THEME_PALETTES) do
            if p == pal then ns.ApplyUITheme(name) break end
        end
    end
end

function Search:UpdateSmartShow(forceShow)
    if not searchFrame then return end
    if forceShow == nil then forceShow = true end
    local enabled = EasyFind.db.smartShow
    if enabled then


        EasyFind.db.visible = true
        searchFrame.hoverZone:Show()
        if not inCombat and (forceShow or searchFrame:IsShown()) then
            searchFrame:Show()
            searchFrame.smartShowFadeIn()
            Utils.SafeAfter(1.5, function()
                if EasyFind.db.smartShow then searchFrame.smartShowFadeOut() end
            end)
        end
    else



        searchFrame.hoverZone:Hide()
        if searchFrame.cancelSmartShowTimer then searchFrame.cancelSmartShowTimer() end
        UIFrameFadeRemoveFrame(searchFrame)
        searchFrame.setSmartShowVisible(true)
        searchFrame:SetAlpha(1.0)
        if inCombat then return end






        local wasShown = searchFrame:IsShown()
        searchFrame:Hide()
        if EasyFind.db.visible ~= false and (forceShow or wasShown) then
            searchFrame:Show()
        end
    end
end



function Search:ApplySavedPosition()
    if not searchFrame then return end
    searchFrame:ClearAllPoints()
    local pos = EasyFind.db.uiSearchPosition
    if type(pos) == "table" and pos[1] then
        searchFrame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        local point, relPoint, x, y = self:GetDefaultSearchBarPoint()
        searchFrame:SetPoint(point, UIParent, relPoint, x, y)
    end
end

function Search:ResetPosition()
    if searchFrame then
        searchFrame:ClearAllPoints()
        local point, relPoint, x, y = self:GetDefaultSearchBarPoint()
        searchFrame:SetPoint(point, UIParent, relPoint, x, y)
        EasyFind.db.uiSearchPosition = nil
    end
end

function Search:ResetPositionAndSize()
    if EasyFind and EasyFind.db then
        EasyFind.db.uiSearchPosition = nil
        EasyFind.db.uiSearchScale = 1.0
        EasyFind.db.uiSearchWidth = 1.54
        EasyFind.db.uiSearchBarHeight = ns.SEARCHBAR_HEIGHT
        EasyFind.db.fontSize = DEFAULT_FONT_SIZE
        EasyFind.db.uiResultsScale = 1.0
        EasyFind.db.uiResultsWidth = 350
        EasyFind.db.uiResultsRows = 6
    end
    self:ResetPosition()
    self:UpdateScale()
    self:UpdateWidth()
    self:UpdateSearchBarHeight()
    self:RefreshResults()
end




local function SizeTypedText(editBox)
    for _, region in ipairs({ editBox:GetRegions() }) do
        if region:GetObjectType() == "FontString" and region ~= editBox.placeholder then
            region._efOwnFont = true
            Search:ScaleFont(region, ns.SEARCHBAR_FONT)
        end
    end
end

function Search:UpdateFontSize()
    if not searchFrame then return end

    SizeTypedText(searchFrame.editBox)
    if ns.RegisterAddonFontsIn then ns.RegisterAddonFontsIn(searchFrame) end

    Search:ScaleFont(searchFrame.editBox, ns.SEARCHBAR_FONT)
    Search:ScaleFont(searchFrame.editBox.placeholder, ns.SEARCHBAR_FONT)

    local barH = Search:GetSearchBarHeight()
    local contentSz = barH * ns.SEARCHBAR_FILL
    local iconSz = contentSz * ns.SEARCHBAR_ICON_SCALE
    searchFrame:SetHeight(barH)
    searchFrame.editBox:SetHeight(contentSz)
    searchFrame.searchIcon:SetSize(iconSz, iconSz)
    if searchFrame.modeBtn then
        searchFrame.modeBtn:SetWidth(barH)
    end
    if searchFrame.filterBtn then
        searchFrame.filterBtn:SetWidth(barH)
    end


    if searchFrame.appsBtn then
        searchFrame.appsBtn:SetWidth(barH)
    end

    local theme = Results:GetActiveTheme()
    local alpha = ns.GetSearchWindowAlpha()



    if searchFrame.editBox then
        searchFrame.editBox:SetTextColor(unpack(theme.leafColor))
        searchFrame.editBox:SetShadowColor(0, 0, 0, theme.lightTheme and 0 or 1)


        if searchFrame.editBox.placeholder and theme.textFaint then
            searchFrame.editBox.placeholder:SetTextColor(theme.textFaint[1], theme.textFaint[2], theme.textFaint[3], 1)
        end
    end



    local quickFilterPill = searchFrame.quickFilterPill
    if quickFilterPill then



        Filters:PaintQuickFilterPill(quickFilterPill, quickFilterPill:IsMouseOver())
        if quickFilterPill.text then
            Search:ScaleFont(quickFilterPill.text, "GameFontHighlightSmall")
        end
    end




    local glyph = theme.chromeGlyph
    if glyph then
        if searchFrame.searchIcon then
            searchFrame.searchIcon:SetVertexColor(glyph[1], glyph[2], glyph[3], 1)
        end
        local filterBtn = searchFrame.filterBtn
        if filterBtn and filterBtn.arrow then
            filterBtn.arrow:SetVertexColor(glyph[1], glyph[2], glyph[3], 1)
            filterBtn.arrow:SetBlendMode(ns.ChromeGlyphBlend(theme))
        end


        if ns.AppsMenu and ns.AppsMenu.SetGlyphColor then
            ns.AppsMenu:SetGlyphColor(glyph[1], glyph[2], glyph[3], 1)
        end




        local tbTex = searchFrame.toolbarHighlight and searchFrame.toolbarHighlight.tex
        if tbTex then
            if theme.lightTheme then
                tbTex:SetBlendMode("BLEND")
                tbTex:SetVertexColor(theme.leafColor[1], theme.leafColor[2], theme.leafColor[3], 0.35)
            elseif theme.flatGlyphs then
                tbTex:SetBlendMode("BLEND")
                tbTex:SetVertexColor(glyph[1], glyph[2], glyph[3], 0.5)
            else
                tbTex:SetBlendMode("ADD")
                tbTex:SetVertexColor(Utils.RGB(GOLD_COLOR, 0.5))
            end
        end



        if filterBtn and filterBtn.btnBg and theme.searchBarRounded then
            if theme.lightTheme then
                local windowFill = ns.SEARCH_WINDOW_FILL_COLOR
                filterBtn.btnBg:SetTexture("Interface\\AddOns\\EasyFind\\textures\\FilterButtonCircle")
                filterBtn.btnBg:SetVertexColor(
                    mmin(1, windowFill[1] * 1.12),
                    mmin(1, windowFill[2] * 1.12),
                    mmin(1, windowFill[3] * 1.12), 0.95)
            else
                filterBtn.btnBg:SetTexture("Interface\\AddOns\\EasyFind\\textures\\filter-glow")
                filterBtn.btnBg:SetVertexColor(1, 1, 1, 1)
            end
        end
    end
    if theme.searchBarRounded then
        searchFrame:SetBackdrop(nil)
        if containerFrame then

            ns.SetRoundedRectBorderShown(containerFrame, true)
            ns.SetRoundedRectRingShown(containerFrame, ns.WindowBorderOn())
            ns.SetRoundedRectBarHeight(containerFrame, barH)
            self:ApplySearchWindowFill(containerFrame)
            ns.SetRoundedRectBorderBgAlpha(containerFrame, alpha)


            if resultsFrame and resultsFrame:IsShown() then
                ns.SetRoundedRectDivider(containerFrame, barH, true)
            end
        end
    end

    for i = 1, #resultButtons do
        Results:ApplyResultRowFonts(resultButtons[i], theme)
    end


    Results:RefreshShownResults()
end
