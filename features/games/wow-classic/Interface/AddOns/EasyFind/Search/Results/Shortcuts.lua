local _, ns = ...

local Search = ns.Search
local Shortcuts = ns.ResultShortcuts
local Filters = ns.Filters
local Icons = ns.ResultIcons
local Utils = ns.Utils

local ClickButton = Utils.ClickButton
local mmin, mmax, mfloor = Utils.mmin, Utils.mmax, Utils.mfloor
local MAX_BUTTON_POOL = 100
Shortcuts.RESULT_SHORTCUT = Shortcuts.RESULT_SHORTCUT or {
    max = 9,
    width = 34,
    iconSize = 14,
    rightPad = 0,
    gap = -4,
    icon = "Interface\\AddOns\\EasyFind\\textures\\alt-key",
}
local RESULT_SHORTCUT = Shortcuts.RESULT_SHORTCUT
local IsAltKeyDown = IsAltKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsShiftKeyDown = IsShiftKeyDown
local InCombatLockdown = InCombatLockdown
local resultShortcutFrame
local resultsFrame

local function ShouldShowResultShortcutHints()
    return not (EasyFind and EasyFind.db and EasyFind.db.showResultShortcutHints == false)
end

function Shortcuts:ShouldShowResultShortcutHints()
    return ShouldShowResultShortcutHints()
end

local shortcutBindOwner
local function RefreshShortcutFrames()
    resultShortcutFrame = Shortcuts._resultShortcutFrame
    shortcutBindOwner = Shortcuts._shortcutBindOwner
    resultsFrame = Search:GetResultsFrame()
end

function Shortcuts:GetResultShortcutIndex(key)
    local frame = Search:GetResultsFrame()
    if not frame or not frame:IsShown() then return nil end
    if not IsAltKeyDown or not IsAltKeyDown() then return nil end
    if (IsControlKeyDown and IsControlKeyDown())
       or (IsShiftKeyDown and IsShiftKeyDown()) then
        return nil
    end
    local digit = tonumber(key)
    if not digit then
        digit = tonumber((key or ""):match("^NUMPAD([1-8])$"))
    end
    if digit and digit >= 1 and digit <= RESULT_SHORTCUT.max then
        return digit
    end
    return nil
end

function Shortcuts:LayoutResultShortcut(row)
    if not (row and row.shortcutGroup) then return end
    local scale = EasyFind.db.fontSize or 1.0
    local extra = mmax(0, scale - 1.0)
    local numberW = mmax(9, mfloor(8 * scale + 5))
    local groupW = mmax(RESULT_SHORTCUT.width, RESULT_SHORTCUT.iconSize + numberW + 14 + mfloor(extra * 12 + 0.5))
    local rightPad = RESULT_SHORTCUT.rightPad + mfloor(extra * 14 + 0.5)
    local groupH = mmax(16, mfloor(16 * mmin(scale, 1.35) + 0.5))

    row.shortcutGroup:ClearAllPoints()
    row.shortcutGroup:SetPoint("RIGHT", row, "RIGHT", -rightPad, 0)
    row.shortcutGroup:SetSize(groupW, groupH)

    if row.shortcutNumberText then
        row.shortcutNumberText:ClearAllPoints()
        row.shortcutNumberText:SetPoint("RIGHT", row.shortcutGroup, "RIGHT", 0, 0)
        row.shortcutNumberText:SetWidth(numberW)
        row.shortcutNumberText:SetJustifyH("RIGHT")
        if row.shortcutNumberText.SetWordWrap then row.shortcutNumberText:SetWordWrap(false) end
        if row.shortcutNumberText.SetNonSpaceWrap then row.shortcutNumberText:SetNonSpaceWrap(false) end
        if row.shortcutNumberText.SetMaxLines then row.shortcutNumberText:SetMaxLines(1) end
    end
    if row.shortcutAltIcon and row.shortcutNumberText then
        row.shortcutAltIcon:ClearAllPoints()
        row.shortcutAltIcon:SetSize(RESULT_SHORTCUT.iconSize, RESULT_SHORTCUT.iconSize)
        row.shortcutAltIcon:SetPoint("RIGHT", row.shortcutNumberText, "LEFT", 2, 0)
    end
end

local function ReplaceRightPointToShortcut(row, frame)
    local shortcut = row and row.shortcutGroup
    if not shortcut or not frame or not frame.GetNumPoints then return false end
    local count = frame:GetNumPoints()
    if count == 0 then return false end

    local points = {}
    local changed = false
    for i = 1, count do
        local point, relTo, relPoint, xOfs, yOfs = frame:GetPoint(i)
        if point == "RIGHT" and relTo == row and relPoint == "RIGHT" then
            points[i] = { point, shortcut, "LEFT", -RESULT_SHORTCUT.gap, yOfs or 0 }
            changed = true
        else
            points[i] = { point, relTo, relPoint, xOfs or 0, yOfs or 0 }
        end
    end
    if not changed then return false end

    frame:ClearAllPoints()
    for i = 1, #points do
        local p = points[i]
        if p[2] then
            frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
        else
            frame:SetPoint(p[1], p[4], p[5])
        end
    end
    return true
end

local function RestoreRightPointFromShortcut(row, frame, xOfs)
    local shortcut = row and row.shortcutGroup
    if not shortcut or not frame or not frame.GetNumPoints then return false end
    local count = frame:GetNumPoints()
    if count == 0 then return false end

    local points = {}
    local changed = false
    for i = 1, count do
        local point, relTo, relPoint, oldX, yOfs = frame:GetPoint(i)
        if point == "RIGHT" and relTo == shortcut and relPoint == "LEFT" then
            points[i] = { point, row, "RIGHT", xOfs or -8, yOfs or 0 }
            changed = true
        else
            points[i] = { point, relTo, relPoint, oldX or 0, yOfs or 0 }
        end
    end
    if not changed then return false end

    frame:ClearAllPoints()
    for i = 1, #points do
        local p = points[i]
        if p[2] then
            frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
        else
            frame:SetPoint(p[1], p[4], p[5])
        end
    end
    return true
end

local function RestoreResultShortcutGutter(row)
    if not row or not row.shortcutGroup then return end
    RestoreRightPointFromShortcut(row, row.icon, -5)
    RestoreRightPointFromShortcut(row, row.iconLetter, -5)
    RestoreRightPointFromShortcut(row, row.amountText, -8)
    RestoreRightPointFromShortcut(row, row.decorText, -8)
    RestoreRightPointFromShortcut(row, row.settingState, -8)
    RestoreRightPointFromShortcut(row, row.settingSliderGroup, -6)
    RestoreRightPointFromShortcut(row, row.settingKeybindGroup, -6)
    RestoreRightPointFromShortcut(row, row.settingDropdownGroup, -6)
    RestoreRightPointFromShortcut(row, row.repBar, -6)
    RestoreRightPointFromShortcut(row, row.pinToggle, -8)
    RestoreRightPointFromShortcut(row, row.text, -8)
    RestoreRightPointFromShortcut(row, row.pathSubtext, -8)
end

local function ApplyResultShortcutGutter(row)
    if not row or not row.shortcutGroup then return end
    if Search.LayoutResultShortcut then
        Search:LayoutResultShortcut(row)
    end

    ReplaceRightPointToShortcut(row, row.icon)
    ReplaceRightPointToShortcut(row, row.iconLetter)
    ReplaceRightPointToShortcut(row, row.amountText)
    ReplaceRightPointToShortcut(row, row.decorText)
    ReplaceRightPointToShortcut(row, row.settingState)
    ReplaceRightPointToShortcut(row, row.settingSliderGroup)
    ReplaceRightPointToShortcut(row, row.settingKeybindGroup)
    ReplaceRightPointToShortcut(row, row.settingDropdownGroup)
    ReplaceRightPointToShortcut(row, row.repBar)
    ReplaceRightPointToShortcut(row, row.pinToggle)
    ReplaceRightPointToShortcut(row, row.text)
    ReplaceRightPointToShortcut(row, row.pathSubtext)
end

Shortcuts.RestoreResultShortcutGutter = RestoreResultShortcutGutter
Shortcuts.ApplyResultShortcutGutter = ApplyResultShortcutGutter

local function IsShortcutEligibleRow(row)
    return row and row:IsShown() and row.data
        and not row.isPinHeader and not row.isSectionHeader
        and not row.isUnearnedCurrency and not row.lockedReason
        and not row.data.calculatorResult
end






local armedShortcutSig = ""
local desiredShortcuts = {}

local function ClearResultShortcutBindings()
    RefreshShortcutFrames()
    if armedShortcutSig == "" then return end



    if shortcutBindOwner and shortcutBindOwner:IsShown() and not InCombatLockdown() then
        ClearOverrideBindings(shortcutBindOwner)
    end
    armedShortcutSig = ""
end

function Shortcuts:ClearResultShortcutBindings()
    return ClearResultShortcutBindings()
end


function Shortcuts:NoteShortcutBindingsCleared()
    armedShortcutSig = ""
end




local badgedRows = {}
local badgedCount = 0

function Shortcuts:UpdateVisibleResultShortcuts()
    RefreshShortcutFrames()
    local showShortcutHints = ShouldShowResultShortcutHints()

    for i = 1, badgedCount do
        local row = badgedRows[i]
        badgedRows[i] = nil
        row._efShortcutIndex = nil
        row._efShortcutBindingReady = nil
        if row.shortcutNumberText then row.shortcutNumberText:SetText("") end
        if row.shortcutGroup then
            row.shortcutGroup:Hide()
        end
    end
    badgedCount = 0

    if not (resultsFrame and resultsFrame:IsShown()
            and resultsFrame.scrollFrame and resultShortcutFrame) then
        ClearResultShortcutBindings()
        return
    end

    local scrollTop = resultsFrame.scrollFrame:GetVerticalScroll() or 0
    local viewH = resultsFrame.scrollFrame:GetHeight() or 0
    if viewH <= 0 then viewH = resultsFrame:GetHeight() or 0 end
    local scrollBottom = scrollTop + viewH
    local assigned = 0
    wipe(desiredShortcuts)
    local desiredSig = ""
    local theme = ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
    local muted = theme and theme.mutedGlyph


    local a, b = ns.Results:LaidOutRows()
    for i = a, b do
        local row = ns.Results:RowFrame(i)
        if row and IsShortcutEligibleRow(row) then
            local rowTop = row._efContentTop or 0
            local rowBottom = row._efContentBottom or (rowTop + (row:GetHeight() or 0))
            if rowBottom > scrollTop + 0.5 and rowTop < scrollBottom - 0.5 then
                assigned = assigned + 1
                if assigned <= RESULT_SHORTCUT.max then
                    row._efShortcutIndex = assigned
                    badgedCount = badgedCount + 1
                    badgedRows[badgedCount] = row
                    if showShortcutHints and row.shortcutNumberText then
                        row.shortcutNumberText:SetText(tostring(assigned))


                        if muted then
                            row.shortcutNumberText:SetTextColor(muted[1], muted[2], muted[3], muted[4] or 0.85)
                            if row.shortcutAltIcon then
                                row.shortcutAltIcon:SetVertexColor(muted[1], muted[2], muted[3], muted[4] or 0.85)
                            end
                        end
                    end
                    if row.shortcutGroup then
                        row.shortcutGroup:SetShown(showShortcutHints)
                    end
                    if not InCombatLockdown() then
                        local targetName
                        if Icons:IsSecureActionResult(row.data) then
                            targetName = row:GetName()
                            row._efShortcutBindingReady = true
                        else
                            local proxy = resultShortcutFrame.shortcutButtons
                                and resultShortcutFrame.shortcutButtons[assigned]
                            if proxy then
                                proxy._shortcutIndex = assigned
                                targetName = proxy:GetName()
                            end
                        end
                        if targetName then
                            desiredShortcuts[assigned] = targetName
                            desiredSig = desiredSig .. assigned .. "=" .. targetName .. ";"
                        end
                    end
                end
            end
        end
    end

    if not InCombatLockdown() and shortcutBindOwner and shortcutBindOwner:IsShown()
       and desiredSig ~= armedShortcutSig then
        if armedShortcutSig ~= "" then
            ClearOverrideBindings(shortcutBindOwner)
        end
        for idx, targetName in pairs(desiredShortcuts) do
            SetOverrideBindingClick(shortcutBindOwner, true, "ALT-" .. idx, targetName, "LeftButton")
            SetOverrideBindingClick(shortcutBindOwner, true, "ALT-NUMPAD" .. idx, targetName, "LeftButton")
        end
        armedShortcutSig = desiredSig
    end
end

local function MarkResultShortcutActivation(row)
    Shortcuts._resultShortcutActivation = row or true
    Utils.SafeAfter(0.15, function()
        if Shortcuts._resultShortcutActivation == row or Shortcuts._resultShortcutActivation == true then
            Shortcuts._resultShortcutActivation = nil
        end
    end)
end

function Shortcuts:SuppressQuickFilterLeakedText(leakedText)
    local editBox = Search:GetSearchFrame() and Search:GetSearchFrame().editBox
    if not editBox then return end
    leakedText = tostring(leakedText or "")
    if leakedText == "" then return end

    local function clearLeakedText()
        if not (Search:GetSearchFrame() and Search:GetSearchFrame():IsShown() and editBox:IsVisible()) then return end
        if not Filters:GetQuickFilter() then return end
        if (editBox:GetText() or "") ~= leakedText then return end
        if editBox.ResetPendingSearch then editBox:ResetPendingSearch() end
        editBox:SetText("")
        editBox:SetCursorPosition(0)
        editBox.blockFocus = nil
        editBox:SetFocus()
        self:OnSearchTextChanged("", true)
    end

    Utils.SafeAfter(0, clearLeakedText)
    Utils.SafeAfter(0.03, clearLeakedText)
end

function Shortcuts:ActivateVisibleResultShortcut(shortcutIndex)
    if not shortcutIndex then return nil end
    for i = 1, MAX_BUTTON_POOL do
        local row = Search:GetResultButtons()[i]
        if not row then break end
        if row._efShortcutIndex == shortcutIndex and IsShortcutEligibleRow(row) then
            if Icons:IsSecureActionResult(row.data) then
                if row._efShortcutBindingReady then
                    MarkResultShortcutActivation(row)
                    return "binding"
                end
                if not InCombatLockdown() then





                    if ns.SecureOpeners and ns.SecureOpeners.OpenKeyForData(row.data) then
                        return "binding"
                    end
                    MarkResultShortcutActivation(row)
                    if ClickButton(row) then
                        return "handled"
                    end
                    Shortcuts._resultShortcutActivation = nil
                end
                return "binding"
            end
            Search:SetSelectedIndex(row.rowIndex or i)
            Search:SetToggleFocused(false)
            self:UpdateSelectionHighlight(true)
            if row.data and row.data.quickFilterDef then
                self:ApplyQuickFilter(row.data.quickFilterDef, "")
                self:SuppressQuickFilterLeakedText(shortcutIndex)
                return "quickFilter"
            end
            MarkResultShortcutActivation(row)
            self:ActivateResultRow(row, "key")
            Shortcuts._resultShortcutActivation = nil
            return "handled"
        end
    end
    return nil
end
