local _, ns = ...

local Search = ns.Search
local Results = ns.Results
local Rows = ns.ResultRows
local Render = ns.ResultRender
local Shortcuts = ns.ResultShortcuts
local OptionsSurface = ns.OptionsSurface
local Utils = ns.Utils
local L = ns.L

local CreateFrame = CreateFrame
local C_Timer = C_Timer
local GetTime = GetTime
local mfloor = Utils.mfloor

local GOLD_COLOR = ns.GOLD_COLOR
local RESULT_SHORTCUT = Shortcuts.RESULT_SHORTCUT
local resultsFrame
local resultShortcutFrame

function Results:EnsureResultButton(index)
    local row = Search:GetResultButtons()[index]
    if not row then
        row = Rows:CreateResultButton(index)
        Search:GetResultButtons()[index] = row
    end
    return row
end





function Results:RefreshShownResults(bypassRenderCache)
    local frame = Search:GetResultsFrame()
    if not (Results._cachedHierarchical and frame and frame:IsShown()) then return false end
    if bypassRenderCache then



        self._lastRenderSig = false
    end
    self:ShowHierarchicalResults(Results._cachedHierarchical, true)
    return true
end

function Results:CreateResultsFrame()
    resultsFrame = CreateFrame("Frame", "EasyFindResultsFrame", Search:GetSearchFrame(), "BackdropTemplate")
    Search:SetResultsFrame(resultsFrame)
    resultsFrame:SetWidth(380)
    resultsFrame:SetPoint("TOP", Search:GetSearchFrame(), "BOTTOM", 0, 2)
    resultsFrame:SetFrameStrata("LOW")
    resultsFrame:SetFrameLevel(Search:GetSearchFrame():GetFrameLevel() + 1)




    resultsFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 20,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })

    local theme = Results:GetActiveTheme()
    local bgAtlasTex = resultsFrame:CreateTexture(nil, "BACKGROUND", nil, -1)
    bgAtlasTex:SetPoint("TOPLEFT", resultsFrame, "TOPLEFT", 4, -4)
    bgAtlasTex:SetPoint("BOTTOMRIGHT", resultsFrame, "BOTTOMRIGHT", -4, 4)
    if theme.resultsBgAtlas then
        bgAtlasTex:SetAtlas(theme.resultsBgAtlas, false)
    end
    bgAtlasTex:Hide()
    resultsFrame.bgAtlasTex = bgAtlasTex



    local updateFooter = resultsFrame:CreateFontString(nil, "OVERLAY", ns.SEARCHBAR_FONT)
    updateFooter:SetJustifyH("LEFT")
    updateFooter:SetWordWrap(false)
    updateFooter:Hide()
    resultsFrame.updateFooter = updateFooter






    local footerHover = CreateFrame("Frame", nil, resultsFrame)
    footerHover:EnableMouse(true)
    footerHover:Hide()
    footerHover:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")


        if updateFooter.efTruncated then
            GameTooltip:AddLine(updateFooter:GetText() or "", GOLD_COLOR[1], GOLD_COLOR[2], GOLD_COLOR[3], true)
        end
        GameTooltip:AddLine(L["UPDATE_NOTIFY_FOOTER_TT"]:format(L["OPT_TAB_GENERAL_BINDS"]),
            nil, nil, nil, true)
        GameTooltip:Show()
    end)
    footerHover:SetScript("OnLeave", function() GameTooltip:Hide() end)
    resultsFrame.updateFooterHover = footerHover

    resultsFrame:Hide()





    resultsFrame:SetScript("OnShow", function(self)
        self:RegisterEvent("GLOBAL_MOUSE_DOWN")
        Search:UpdateStackStrata()
    end)
    resultsFrame:SetScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        Search:UpdateStackStrata()


        local unearned = ns.ResultTooltips and ns.ResultTooltips:GetUnearnedTooltip()
        if unearned then unearned:Hide() end
    end)
    resultsFrame:SetScript("OnEvent", function(self, event)
        if event ~= "GLOBAL_MOUSE_DOWN" then return end
        if Utils.IsFrameVisiblyMouseOver(self) then return end
        if Search:GetSearchFrame() and Search:GetSearchFrame():IsMouseOver() then return end

        if Utils.IsFrameVisiblyMouseOver(Search.containerFrame) then return end
        if OptionsSurface:IsOptionsSurfaceMouseOver() then return end



        if Utils.IsCursorMenuMouseOver() then return end

        if Utils.IsCursorMenuShown() then return end


        if Utils.IsClickGuardMouseOver() then return end


        if ns.Filters and ns.Filters.IsMouseInFilterChain() then return end


        if Utils.IsMouseOnLauncherButton and Utils.IsMouseOnLauncherButton() then return end
        if ns.NoteApplicationDismissed and ns.CurrentApplicationSurfaceID then
            ns.NoteApplicationDismissed(ns.CurrentApplicationSurfaceID())
        end
        Results:RequestHideResults()
    end)

    local resizeTimer
    resultsFrame:SetScript("OnSizeChanged", function()
        if not resultsFrame:IsShown() or not Results._cachedHierarchical then return end


        if Results:IsGridShown() then return end
        if resizeTimer then resizeTimer:Cancel() end
        resizeTimer = C_Timer.NewTimer(0.02, function()
            resizeTimer = nil
            Render:ShowHierarchicalResults(Results._cachedHierarchical, true)
        end)
    end)



    local scrollFrame = CreateFrame("ScrollFrame", nil, resultsFrame)
    resultsFrame.scrollFrame = scrollFrame

    local quickFilterHelp = resultsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    quickFilterHelp:SetPoint("TOPLEFT", resultsFrame, "TOPLEFT", 12, -8)
    quickFilterHelp:SetPoint("TOPRIGHT", resultsFrame, "TOPRIGHT", -12, -8)
    quickFilterHelp:SetJustifyH("LEFT")
    quickFilterHelp:SetTextColor(0.78, 0.78, 0.80, 1)
    quickFilterHelp:SetText(L["QUICK_FILTER_HELP"])
    quickFilterHelp:Hide()
    resultsFrame.quickFilterHelp = quickFilterHelp

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(scrollChild)
    resultsFrame.scrollChild = scrollChild


    resultsFrame.scrollBar = ns.Utils.CreateMinimalScrollBar(scrollFrame, resultsFrame)





    local lastShortcutBucket
    scrollFrame:HookScript("OnVerticalScroll", function(_, offset)
        local bucket = mfloor((offset or 0) / 12)
        if bucket ~= lastShortcutBucket then
            lastShortcutBucket = bucket


            if not Render.rendering then Render:UpdateWindow() end
            Shortcuts:UpdateVisibleResultShortcuts()
            Render.DrawPendingFaces(scrollFrame)
        end
    end)





    function Results:IsResultsScrollBusy()
        local bar = resultsFrame and resultsFrame.scrollBar
        if not bar then return false end
        if bar._scrollTarget then return true end
        return (GetTime() - (bar._lastActivity or 0)) < 0.25
    end






    local settleWatch = CreateFrame("Frame")



    local function RowUnderCursor()
        local buttons = Search:GetResultButtons()
        for i = 1, (buttons and #buttons or 0) do
            local row = buttons[i]
            if row and row:IsShown() and row:IsMouseOver() then return row end
        end
        return nil
    end
    local function RefireHover()
        if not (resultsFrame:IsShown() and resultsFrame:IsMouseOver()) then return end
        local row = RowUnderCursor()
        local prev = Results._hoverRow
        if prev and prev ~= row then
            local leave = prev:GetScript("OnLeave")
            if leave then leave(prev) end
        end
        if not row then return end
        local enter = row:GetScript("OnEnter")
        if enter then enter(row) end
    end
    local function WatchForSettle()
        if settleWatch:GetScript("OnUpdate") then return end
        settleWatch:SetScript("OnUpdate", function(self)
            if Results:IsResultsScrollBusy() then return end
            self:SetScript("OnUpdate", nil)
            RefireHover()
        end)
    end
    scrollFrame:HookScript("OnVerticalScroll", WatchForSettle)












    local secureClear = not (ns.Caps and ns.Caps.forever)
    local shortcutBindOwner = CreateFrame("Frame", nil, resultsFrame, "SecureHandlerShowHideTemplate")
    if secureClear then shortcutBindOwner:SetAttribute("_onhide", "self:ClearBindings()") end
    shortcutBindOwner:HookScript("OnHide", function(self)



        if ns.Caps and ns.Caps.forever and not InCombatLockdown() then ClearOverrideBindings(self) end
        Shortcuts:NoteShortcutBindingsCleared()
    end)
    Shortcuts._shortcutBindOwner = shortcutBindOwner

    local navBindOwner = CreateFrame("Frame", nil, resultsFrame, "SecureHandlerShowHideTemplate")
    if secureClear then navBindOwner:SetAttribute("_onhide", "self:ClearBindings()") end
    navBindOwner:HookScript("OnHide", function(self)
        if ns.Caps and ns.Caps.forever and not InCombatLockdown() then ClearOverrideBindings(self) end
        if Results.NoteNavBindingCleared then Results:NoteNavBindingCleared() end
    end)
    Results._navBindOwner = navBindOwner

    resultShortcutFrame = CreateFrame("Frame", nil, Search:GetSearchFrame())
    Shortcuts._resultShortcutFrame = resultShortcutFrame
    resultShortcutFrame.shortcutButtons = {}
    for i = 1, RESULT_SHORTCUT.max do
        local proxy = CreateFrame("Button", "EasyFindResultShortcutButton" .. i, resultShortcutFrame)
        proxy._shortcutIndex = i
        proxy:SetScript("OnClick", function(self)
            Shortcuts:ActivateVisibleResultShortcut(self._shortcutIndex)
        end)
        resultShortcutFrame.shortcutButtons[i] = proxy
    end

    local pinSeparator = scrollChild:CreateTexture(nil, "ARTWORK")
    pinSeparator:SetColorTexture(Utils.RGB(GOLD_COLOR, 0.4))
    pinSeparator:SetHeight(1)
    pinSeparator:Hide()
    resultsFrame.pinSeparator = pinSeparator


    local categorySeps = {}
    for sepIdx = 1, 6 do
        local sep = scrollChild:CreateTexture(nil, "ARTWORK")
        sep:SetColorTexture(Utils.RGB(GOLD_COLOR, 0.3))
        sep:SetHeight(1.5)
        sep:Hide()
        categorySeps[sepIdx] = sep
    end
    resultsFrame.categorySeps = categorySeps
end
