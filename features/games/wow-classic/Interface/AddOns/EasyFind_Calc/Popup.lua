local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not (ns and ns.Calculator) then return end

local Search = ns.Search
local Calculator = ns.Calculator
local Results = ns.Results
local Utils = ns.Utils
local L = ns.L

local mmin = Utils.mmin
local pairs = Utils.pairs

local GOLD_COLOR = ns.GOLD_COLOR
local CreateFrame = CreateFrame
local UIParent = UIParent
local IsControlKeyDown = IsControlKeyDown

local function GetSearchFrame()
    return Search:GetSearchFrame()
end

local function GetNavFrame()
    return Search:GetNavFrame()
end

local function GetResultButtons()
    return Search:GetResultButtons()
end





local function CalcThemeFill(frame, tbl, fallbackR, fallbackG, fallbackB)
    Calculator:ThemeFillCalcControl(frame, tbl, fallbackR, fallbackG, fallbackB)
end



function Calculator:PaintCalculatorWell(frame)
    local bf = ns.BTN_FILL_NORMAL or { 0.160, 0.190, 0.250 }
    self:SetCalculatorRoundedFill(frame, bf[1], bf[2], bf[3], 1, 0.28, 0.28, 0.30, 0.75)
end





function Calculator:RestyleCalculatorTheme()
    local frame = Calculator._calculator and Calculator._calculator.popupFrame
    if not frame then return end
    if ns.ApplyThemeFill then ns.ApplyThemeFill(frame) end
    for btn in pairs(Calculator._styledButtons) do
        CalcThemeFill(btn, ns.BTN_FILL_NORMAL, 0.095, 0.095, 0.108)
    end
    if frame.inputShell then self:PaintCalculatorWell(frame.inputShell) end
    if frame.calcGlyph then
        CalcThemeFill(frame.calcGlyph, ns.BTN_FILL_NORMAL, 0.095, 0.095, 0.108)
        if frame.calcGlyph.icon then
            local gc = ns.ChromeGlyphColor()
            frame.calcGlyph.icon:SetVertexColor(gc[1], gc[2], gc[3], 1)
        end
    end
    self:RefreshCalculatorPopup()
end

function Calculator:CreateCalculatorGlyph(parent, size)
    local glyph = CreateFrame("Frame", nil, parent)
    size = size or 22
    glyph:SetSize(size, size)
    ns.CreateRoundedRectBorder(glyph)
    ns.SetRoundedRectBarHeight(glyph, mmin(size, 10))
    ns.SetRoundedRectBorderBgAlpha(glyph, 1)
    self:HideCalculatorRoundedBorder(glyph)
    CalcThemeFill(glyph, ns.BTN_FILL_NORMAL, 0.095, 0.095, 0.108)

    local icon = glyph:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", glyph, "TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", glyph, "BOTTOMRIGHT", -3, 3)
    icon:SetTexture("Interface\\AddOns\\EasyFind\\textures\\calculator-icon")
    icon:SetTexCoord(0, 1, 0, 1)


    icon:SetDesaturated(true)
    local gc = ns.ChromeGlyphColor()
    icon:SetVertexColor(gc[1], gc[2], gc[3], 1)
    glyph.icon = icon
    return glyph
end

function Calculator:RefreshCalculatorPopup()
    local frame = Calculator._calculator.popupFrame
    local editBox = Calculator._calculator.popupEditBox
    if not frame or not editBox then return end

    local raw = editBox:GetText() or ""
    local text = strtrim(raw)
    local submitted = Calculator._calculator.popupSubmitted
        and Calculator._calculator.popupSubmittedText == raw
    local data = text ~= "" and self:EvaluateCalculatorExpression(raw) or nil
    Calculator._calculator.popupData = data
    if Calculator._calculator.activeSource == "calculator"
       and (not data or Calculator._calculator.activeResult ~= data.calculatorResult) then
        self:ClearCalculatorPopupCopyTarget(true)
    end
    if frame.clearInputButton then
        if text ~= "" then
            frame.clearInputButton:Show()
        else
            frame.clearInputButton:Hide()
        end
    end
    if submitted and data then
        frame.resultText:SetText(data.calculatorResultShown or data.calculatorResult)
        if frame.expressionText then frame.expressionText:Hide() end
        frame.resultText:SetTextColor(Utils.RGB(GOLD_COLOR, 1))
        if frame.hintText then frame.hintText:Hide() end
        self:SetCalculatorRoundedFill(frame.resultCard, 0.19, 0.16, 0.10, 0.98, 0.76, 0.56, 0.22, 0.90)
    elseif data then
        frame.resultText:SetText(data.calculatorResultShown or data.calculatorResult)
        if frame.expressionText then frame.expressionText:Hide() end
        frame.resultText:SetTextColor(0.86, 0.86, 0.88, 1)
        if frame.hintText then frame.hintText:Hide() end
        self:PaintCalculatorWell(frame.resultCard)
    else
        frame.resultText:SetText(submitted and text ~= "" and "-" or "")
        if frame.expressionText then frame.expressionText:Hide() end
        frame.resultText:SetTextColor(0.58, 0.58, 0.60, 1)
        if frame.hintText then frame.hintText:Hide() end
        self:PaintCalculatorWell(frame.resultCard)
    end
    self:UpdateCalculatorPopupCopyVisual(data)
end

function Calculator:InsertCalculatorPopupText(text)
    local editBox = Calculator._calculator.popupEditBox
    if not editBox then return end
    text = tostring(text or "")
    if text == "" then return end

    local current = editBox:GetText() or ""
    local pos = editBox:GetCursorPosition() or #current
    editBox:SetText(current:sub(1, pos) .. text .. current:sub(pos + 1))
    editBox:SetCursorPosition(pos + #text)
    editBox:SetFocus()
    self:RefreshCalculatorPopup()
end

function Calculator:BackspaceCalculatorPopup()
    local editBox = Calculator._calculator.popupEditBox
    if not editBox then return end
    local current = editBox:GetText() or ""
    local pos = editBox:GetCursorPosition() or #current
    if pos <= 0 then return end
    editBox:SetText(current:sub(1, pos - 1) .. current:sub(pos + 1))
    editBox:SetCursorPosition(pos - 1)
    editBox:SetFocus()
    self:RefreshCalculatorPopup()
end

function Calculator:UseCalculatorPopupResult()
    local editBox = Calculator._calculator.popupEditBox
    if not editBox then return false end
    return self:SubmitCalculatorPopupExpression(editBox:GetText() or "")
end

function Calculator:SubmitCalculatorPopupExpression(raw)
    local editBox = Calculator._calculator.popupEditBox
    if not editBox then return false end
    raw = tostring(raw or "")
    raw = raw:gsub("%s*=$", "")
    Calculator._calculator.popupSubmitting = true
    Calculator._calculator.popupSubmitted = true
    Calculator._calculator.popupSubmittedText = raw
    Calculator._calculator.popupData = self:EvaluateCalculatorExpression(raw)
    if editBox:GetText() ~= raw then
        editBox:SetText(raw)
    end
    editBox:SetCursorPosition(#raw)
    editBox:SetFocus()
    Calculator._calculator.popupSubmitting = nil
    self:RefreshCalculatorPopup()
    return Calculator._calculator.popupData and true or false
end

function Calculator:IsCalculatorPopupSubmitKey(key)
    if key == "ENTER" then return true end
    if IsShiftKeyDown and IsShiftKeyDown()
       and (key == "=" or key == "EQUAL" or key == "EQUALS") then
        return false
    end
    return key == "="
        or key == "EQUAL"
        or key == "EQUALS"
        or key == "NUMPADEQUALS"
end

function Calculator:SwallowCalculatorPopupChar(editBox)
    if not editBox then return end
    Utils.SafeCallMethod(editBox, "SetPropagateKeyboardInput", false)
    if not editBox.SetEnabled then return end

    editBox:SetEnabled(false)
    Utils.SafeAfter(0, function()
        local frame = Calculator._calculator.popupFrame
        if frame and frame:IsShown() and editBox:IsVisible() then
            editBox:SetEnabled(true)
            editBox:SetFocus()
            editBox:SetCursorPosition(#(editBox:GetText() or ""))
        end
    end)
end

function Calculator:QueueCalculatorPopupEqualsSubmit(editBox)
    if Calculator._calculator.popupEqualSubmitQueued then return end
    Calculator._calculator.popupEqualSubmitQueued = true
    Utils.SafeAfter(0, function()
        Calculator._calculator.popupEqualSubmitQueued = nil
        local frame = Calculator._calculator.popupFrame
        if not (frame and frame:IsShown() and editBox and editBox:IsVisible()) then return end
        local raw = editBox:GetText() or ""
        if raw:match("%s*=$") then
            Calculator:SubmitCalculatorPopupExpression(raw)
        end
    end)
end

function Calculator:UpdateCalculatorPopupCopyVisual(data)
    local frame = Calculator._calculator.popupFrame
    if not (frame and frame.resultCard and frame.resultText) then return end
    local result = data and data.calculatorResult
    local active = result
        and Calculator._calculator.activeSource == "calculator"
        and Calculator._calculator.activePart == "result"
        and Calculator._calculator.activeResult == result
    local copied = active
        and Calculator._calculator.copyComplete
        and Calculator._calculator.copyCompleteValue == result

    frame.resultText:ClearAllPoints()
    if active then
        frame.resultText:SetPoint("TOPLEFT", frame.resultCard, "TOPLEFT", 12, -8)
        frame.resultText:SetPoint("RIGHT", frame.resultCard, "RIGHT", -12, 0)
        frame.resultText:SetTextColor(
            copied and 0.48 or GOLD_COLOR[1],
            copied and 1.0 or GOLD_COLOR[2],
            copied and 0.62 or GOLD_COLOR[3],
            1)
        if frame.hintText then
            frame.hintText:SetText(copied and L["CALC_PASTE_HINT"] or L["COPY_HINT"])
            frame.hintText:SetTextColor(copied and 0.48 or 0.72, copied and 1.0 or 0.72, copied and 0.62 or 0.72, 1)
            frame.hintText:Show()
        end
        self:SetCalculatorRoundedFill(frame.resultCard, 0.22, 0.18, 0.11, 1, 0.95, 0.72, 0.28, 1)
    else
        frame.resultText:SetPoint("LEFT", frame.resultCard, "LEFT", 12, 0)
        frame.resultText:SetPoint("RIGHT", frame.resultCard, "RIGHT", -12, 0)
    end
end

function Calculator:ClearCalculatorPopupCopyTarget(release)
    if Calculator._calculator.activeSource ~= "calculator" then return end
    Calculator._calculator.activeRow = nil
    Calculator._calculator.activeData = nil
    Calculator._calculator.activeResult = nil
    Calculator._calculator.activePart = nil
    Calculator._calculator.activeSource = nil
    Calculator._calculator.popupArmedSource = nil
    Calculator._calculator.copyComplete = nil
    Calculator._calculator.copyCompleteValue = nil
    Calculator._calculator.copiedData = nil
    Calculator._calculator.copiedPart = nil
    Calculator._calculator.ctrlWasDown = nil
    Calculator._calculator.copyKeyWasDown = nil
    if Calculator._calculator.copyWatcher then
        Calculator._calculator.copyWatcher:Hide()
    end
    if release then
        self:ReleaseCalculatorCopyBox()
    end
end

function Calculator:ArmCalculatorPopupResult(source)
    local data = Calculator._calculator.popupData
    if not data or not data.calculatorResult then return false end
    source = source or "click"
    local result = data.calculatorResult
    local completedHover = source == "hover" and Calculator._calculator.copyComplete
    if source ~= "ctrl" and source ~= "confirm" and not completedHover then
        Calculator._calculator.copyComplete = nil
        Calculator._calculator.copyCompleteValue = nil
    end
    if Calculator._calculator.activeResult ~= result then
        Calculator._calculator.copiedData = nil
        Calculator._calculator.copiedPart = nil
    end
    if source ~= "hover" or ((IsControlKeyDown and IsControlKeyDown()) and not Calculator._calculator.copyComplete) then
        if not self:CopyCalculatorResult(result, "calculator") then
            return false
        end
    end
    Calculator._calculator.activeRow = nil
    Calculator._calculator.activeData = data
    Calculator._calculator.activeResult = result
    Calculator._calculator.activePart = "result"
    Calculator._calculator.activeSource = "calculator"
    Calculator._calculator.popupArmedSource = source
    self:UpdateCalculatorPopupCopyVisual(data)
    self:StartCalculatorCopyWatcher()
    return true
end

function Calculator:RestoreCalculatorPopupFocus()
    local frame = Calculator._calculator.popupFrame
    local editBox = Calculator._calculator.popupEditBox
    if frame and frame:IsShown() and editBox and editBox:IsVisible() then
        editBox:SetFocus()
        editBox:SetCursorPosition(#(editBox:GetText() or ""))
    end
end

function Calculator:EnsureCalculatorFrame()
    local frame = Calculator._calculator.popupFrame
    if frame then return frame end

    local CALC_PAD = 14
    local CALC_BUTTON_W = 40
    local CALC_BUTTON_H = 24
    local CALC_BUTTON_GAP_X = 4
    local CALC_BUTTON_GAP_Y = 4
    local CALC_COLS = 5
    local CALC_W = CALC_PAD * 2
        + CALC_BUTTON_W * CALC_COLS
        + CALC_BUTTON_GAP_X * (CALC_COLS - 1)

    frame = CreateFrame("Frame", "EasyFindCalculatorFrame", UIParent)
    Calculator._calculator.popupFrame = frame
    frame:SetSize(CALC_W, 304)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(900)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    ns.CreateRoundedRectBorder(frame)
    frame._efForeverSurface = true
    frame._efClassicSurface = true
    ns.SetRoundedRectBarHeight(frame, 14)
    ns.SetRoundedRectBorderBgAlpha(frame, 0.98)


    if ns.ApplyThemeFill then
        ns.ApplyThemeFill(frame)
    else
        local calcWF = ns.SEARCH_WINDOW_FILL_COLOR or { 0.055, 0.055, 0.064 }
        self:SetCalculatorRoundedFill(frame, calcWF[1], calcWF[2], calcWF[3], 0.98, 0.30, 0.30, 0.32, 0.95)
    end
    if ns.RegisterThemeCallback then
        ns.RegisterThemeCallback(function()
            Calculator:RestyleCalculatorTheme()
        end)
    end

    local glyph = self:CreateCalculatorGlyph(frame, 22)
    glyph:SetPoint("TOPLEFT", frame, "TOPLEFT", CALC_PAD, -12)
    frame.calcGlyph = glyph

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", glyph, "RIGHT", 8, 0)
    title:SetText(L["UITREE_CALCULATOR"])
    title:SetTextColor(1, 1, 1, 1)

    local close = CreateFrame("Button", nil, frame)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -CALC_PAD, -12)
    local function makeCloseStroke()
        local tex = close:CreateTexture(nil, "OVERLAY")
        tex:SetTexture("Interface\\Buttons\\WHITE8x8")
        tex:SetSize(16, 1.5)
        tex:SetPoint("CENTER")
        return tex
    end
    local closeStroke1 = makeCloseStroke(); closeStroke1:SetRotation(math.pi / 4)
    local closeStroke2 = makeCloseStroke(); closeStroke2:SetRotation(-math.pi / 4)
    local function setCloseColor(r, g, b)
        closeStroke1:SetVertexColor(r, g, b, 1)
        closeStroke2:SetVertexColor(r, g, b, 1)
    end
    setCloseColor(0.55, 0.55, 0.58)
    close:SetScript("OnEnter", function() setCloseColor(1, 1, 1) end)
    close:SetScript("OnLeave", function() setCloseColor(0.55, 0.55, 0.58) end)
    close:SetScript("OnClick", function() frame:Hide() end)

    local inputShell = CreateFrame("Frame", nil, frame)
    inputShell:SetPoint("TOPLEFT", frame, "TOPLEFT", CALC_PAD, -44)
    inputShell:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -CALC_PAD, -44)
    inputShell:SetHeight(38)
    ns.CreateRoundedRectBorder(inputShell)
    ns.SetRoundedRectBarHeight(inputShell, 10)
    ns.SetRoundedRectBorderBgAlpha(inputShell, 1)
    self:PaintCalculatorWell(inputShell)
    frame.inputShell = inputShell

    local clearInput = CreateFrame("Button", nil, inputShell)
    frame.clearInputButton = clearInput
    clearInput:SetSize(18, 18)
    clearInput:SetPoint("RIGHT", inputShell, "RIGHT", -9, 0)
    local function makeClearStroke()
        local tex = clearInput:CreateTexture(nil, "OVERLAY")
        tex:SetTexture("Interface\\Buttons\\WHITE8x8")
        tex:SetSize(12, 1.4)
        tex:SetPoint("CENTER")
        return tex
    end
    local clearStroke1 = makeClearStroke(); clearStroke1:SetRotation(math.pi / 4)
    local clearStroke2 = makeClearStroke(); clearStroke2:SetRotation(-math.pi / 4)
    local function setClearColor(r, g, b)
        clearStroke1:SetVertexColor(r, g, b, 1)
        clearStroke2:SetVertexColor(r, g, b, 1)
    end
    setClearColor(0.58, 0.58, 0.60)
    clearInput:SetScript("OnEnter", function() setClearColor(1, 0.82, 0.36) end)
    clearInput:SetScript("OnLeave", function() setClearColor(0.58, 0.58, 0.60) end)
    clearInput:Hide()

    local editBox = CreateFrame("EditBox", nil, inputShell)
    Utils.ReleaseFocusOnOutsideClick(editBox)
    Calculator._calculator.popupEditBox = editBox
    editBox:SetPoint("LEFT", inputShell, "LEFT", 12, 0)
    editBox:SetPoint("RIGHT", clearInput, "LEFT", -6, 0)
    editBox:SetHeight(30)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlightLarge)
    editBox:SetTextColor(0.96, 0.96, 0.96, 1)
    editBox:SetJustifyH("LEFT")
    editBox:SetScript("OnTextChanged", function(self)
        local raw = self:GetText() or ""
        if raw:match("%s*=$") then
            Calculator:QueueCalculatorPopupEqualsSubmit(self)
            return
        end
        if not Calculator._calculator.popupSubmitting then
            Calculator._calculator.popupSubmitted = nil
            Calculator._calculator.popupSubmittedText = nil
            Calculator._calculator.popupData = nil
        end
        Calculator:RefreshCalculatorPopup()
    end)
    editBox:SetScript("OnEscapePressed", function()
        frame:Hide()
    end)
    editBox:SetScript("OnEnterPressed", function()
        Calculator:UseCalculatorPopupResult()
    end)
    editBox:SetScript("OnKeyDown", function(self, key)
        if Calculator:HandleCalculatorCopyConfirmKey(key) then
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
            return
        end
        if key == "ESCAPE" then
            frame:Hide()
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
            return
        end
        if Calculator:IsCalculatorPopupSubmitKey(key) then
            Calculator:UseCalculatorPopupResult()
            if key ~= "ENTER" then
                Calculator:SwallowCalculatorPopupChar(self)
            else
                Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
            end
            return
        end
        Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
    end)
    clearInput:SetScript("OnClick", function()
        Calculator._calculator.popupSubmitted = nil
        Calculator._calculator.popupSubmittedText = nil
        Calculator._calculator.popupData = nil
        editBox:SetText("")
        editBox:SetFocus()
        Calculator:RefreshCalculatorPopup()
    end)

    local resultCard = CreateFrame("Button", nil, frame)
    frame.resultCard = resultCard
    resultCard:SetPoint("TOPLEFT", inputShell, "BOTTOMLEFT", 0, -8)
    resultCard:SetPoint("TOPRIGHT", inputShell, "BOTTOMRIGHT", 0, -8)
    resultCard:SetHeight(58)
    resultCard:RegisterForClicks("LeftButtonUp")
    ns.CreateRoundedRectBorder(resultCard)
    ns.SetRoundedRectBarHeight(resultCard, 10)
    ns.SetRoundedRectBorderBgAlpha(resultCard, 1)
    self:PaintCalculatorWell(resultCard)

    local expressionText = resultCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.expressionText = expressionText
    expressionText:SetPoint("TOPLEFT", resultCard, "TOPLEFT", 12, -8)
    expressionText:SetPoint("RIGHT", resultCard, "RIGHT", -12, 0)
    expressionText:SetJustifyH("LEFT")
    expressionText:SetTextColor(0.66, 0.66, 0.68, 1)
    expressionText:Hide()

    local resultText = resultCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.resultText = resultText
    resultText:SetPoint("LEFT", resultCard, "LEFT", 12, 0)
    resultText:SetPoint("RIGHT", resultCard, "RIGHT", -12, 0)
    resultText:SetWidth(CALC_W - CALC_PAD * 2 - 16)
    resultText:SetJustifyH("LEFT")
    resultText:SetText("-")

    local hintText = resultCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.hintText = hintText
    hintText:SetPoint("BOTTOMLEFT", resultCard, "BOTTOMLEFT", 12, 10)
    hintText:SetPoint("RIGHT", resultCard, "RIGHT", -12, 0)
    hintText:SetJustifyH("LEFT")
    hintText:SetTextColor(0.54, 0.54, 0.56, 1)
    hintText:Hide()

    resultCard:SetScript("OnEnter", function(self)
        Calculator:ArmCalculatorPopupResult("hover")
    end)
    resultCard:SetScript("OnLeave", function(self)
        if Calculator._calculator.activeSource == "calculator"
           and Calculator._calculator.popupArmedSource == "hover" then
            Calculator:ClearCalculatorPopupCopyTarget(true)
        end
        Calculator:RefreshCalculatorPopup()
    end)
    resultCard:SetScript("OnClick", function()
        Calculator:ArmCalculatorPopupResult("click")
    end)

    local function makeButton(label, insertText)
        local b = CreateFrame("Button", nil, frame)
        b:SetSize(CALC_BUTTON_W, CALC_BUTTON_H)
        Calculator:StyleCalculatorButton(b, CALC_BUTTON_H)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.text:SetPoint("CENTER")
        b.text:SetText(label == "Back" and L["CALC_BACKSPACE"] or label)
        b.text:SetTextColor(0.95, 0.95, 0.95, 1)
        b:HookScript("OnClick", function()
            if label == "C" then
                editBox:SetText("")
                editBox:SetFocus()
            elseif label == "Back" then
                Calculator:BackspaceCalculatorPopup()
            elseif label == "=" then
                Calculator:UseCalculatorPopupResult()
            elseif insertText then
                Calculator:InsertCalculatorPopupText(insertText)
            else
                Calculator:InsertCalculatorPopupText(label)
            end
        end)
        return b
    end

    local rows = {
        { { "sin", "sin(" }, { "cos", "cos(" }, { "tan", "tan(" }, { "(", "(" }, { ")", ")" } },
        { { "7" }, { "8" }, { "9" }, { "/", "/" }, { "C" } },
        { { "4" }, { "5" }, { "6" }, { "*", "*" }, { "Back" } },
        { { "1" }, { "2" }, { "3" }, { "-", "-" }, { "!" } },
        { { "0" }, { "." }, { "=", nil }, { "+", "+" }, { "^", "^" } },
    }
    local gridTop = -154
    for row = 1, #rows do
        for col = 1, #rows[row] do
            local spec = rows[row][col]
            local b = makeButton(spec[1], spec[2])
            b:SetPoint(
                "TOPLEFT", frame, "TOPLEFT",
                CALC_PAD + (col - 1) * (CALC_BUTTON_W + CALC_BUTTON_GAP_X),
                gridTop - (row - 1) * (CALC_BUTTON_H + CALC_BUTTON_GAP_Y)
            )
        end
    end

    frame:SetScript("OnHide", function(self)
        if Calculator._calculator.activeSource == "calculator" then
            Calculator:ClearCalculatorCopyHighlight()
            Calculator:ReleaseCalculatorCopyBox()
        end
        EasyFind.API.NotifyOpenChanged("calculator")
    end)
    frame:SetScript("OnShow", function() EasyFind.API.NotifyOpenChanged("calculator") end)
    frame:Hide()
    self:RefreshCalculatorPopup()
    return frame
end

function Calculator:CloseSearchForCalculator()
    if GetSearchFrame() and GetSearchFrame().editBox then
        local editBox = GetSearchFrame().editBox
        if editBox.ResetPendingSearch then editBox:ResetPendingSearch() end
        editBox:SetText("")
        editBox:ClearFocus()
        if editBox.placeholder then editBox.placeholder:Show() end
    end
    self:ClearQuickFilter(false)
    self:HideQuickFilterSuggestions()
    if GetSearchFrame() and GetSearchFrame():IsShown() then
        self:Hide()
    else
        self:HideResults()
    end
end

function Calculator:OpenCalculator(expression)
    expression = tostring(expression or "")
    self:CloseSearchForCalculator()

    local frame = self:EnsureCalculatorFrame()
    local editBox = Calculator._calculator.popupEditBox
    Calculator._calculator.popupSubmitted = nil
    Calculator._calculator.popupSubmittedText = nil
    Calculator._calculator.popupData = nil
    if editBox then
        editBox:SetText(expression)
        editBox:SetCursorPosition(#expression)
    end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER")
    frame:Show()
    frame:Raise()




    if editBox then
        Utils.SafeAfter(0, function()
            if frame and frame:IsShown() and editBox:IsVisible() then
                editBox:SetFocus()
                editBox:SetCursorPosition(#(editBox:GetText() or ""))
            end
        end)
    end
    self:RefreshCalculatorPopup()
    return true
end

function Calculator:IsCalculatorOpenShortcut(key)
    if key ~= "C" and key ~= "c" then return false end
    if not IsAltKeyDown or not IsAltKeyDown() then return false end
    if (IsControlKeyDown and IsControlKeyDown())
       or (IsShiftKeyDown and IsShiftKeyDown()) then
        return false
    end
    return true
end

function Calculator:HandleCalculatorOpenShortcut(editBox, key)
    if not self:IsCalculatorOpenShortcut(key) then return false end
    local expression = ""
    if editBox and editBox.GetText then
        local text = editBox:GetText() or ""
        local cursor = editBox.GetCursorPosition and editBox:GetCursorPosition() or #text
        expression = text:sub(1, cursor)
    end
    self:OpenCalculator(expression, true)
    return true
end

function Calculator:EnsureCalculatorCopyBox()
    local box = Calculator._calculator.copyBox
    if box then return box end


    box = CreateFrame("EditBox", "EasyFindCalculatorCopyBox", UIParent)
    box:SetSize(1, 1)



    box:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    box:SetAlpha(0)
    box:SetFontObject(GameFontNormal)
    box:SetAutoFocus(false)
    Utils.SafeCallMethod(box, "EnableKeyboard", false)
    box:SetMaxLetters(0)
    box:SetScript("OnKeyDown", function(self, key)
        if Calculator:HandleCalculatorCopyKey(key) then
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
            return
        end
        if Calculator:HandleCalculatorCopyConfirmKey(key) then
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
        end
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", function()
        Calculator._calculator.copyFocused = nil
        if not Calculator._calculator.releasingCopyBox then
            Calculator._calculator.prevFocus = nil
        end
    end)
    Calculator._calculator.copyBox = box
    return box
end

function Calculator:ReleaseCalculatorCopyBox(source)
    if source and Calculator._calculator.copySource ~= source then return end

    Calculator._calculator.copyToken = (Calculator._calculator.copyToken or 0) + 1

    local prev = Calculator._calculator.prevFocus
    local box = Calculator._calculator.copyBox
    local restoreFocus = Calculator._calculator.copyFocused
        or Calculator._calculator.copySource ~= nil
        or Calculator._calculator.prevFocus ~= nil
        or (box and box.HasFocus and box:HasFocus())

    Calculator._calculator.copySource = nil
    Calculator._calculator.releasingCopyBox = true
    if box then
        box:HighlightText(0, 0)
        box:ClearFocus()
    end
    Calculator._calculator.releasingCopyBox = nil
    Calculator._calculator.copyFocused = nil

    Calculator._calculator.prevFocus = nil
    if not restoreFocus then return end
    if not (prev and prev.SetFocus and prev.IsVisible and prev:IsVisible()) then
        prev = GetSearchFrame() and GetSearchFrame().editBox
    end
    if prev and (prev.blockFocus or prev._dragMoving) then
        prev = nil
    end
    if prev and prev.SetFocus and prev.IsVisible and prev:IsVisible() then
        prev:SetFocus()
    end
end

function Calculator:CopyCalculatorResult(result, source)
    if not result or result == "" then return false end

    local box = self:EnsureCalculatorCopyBox()
    if not Calculator._calculator.copyFocused then
        local cur = Utils.KeyboardFocus()
        if cur and cur ~= box then
            Calculator._calculator.prevFocus = cur
        end
    end
    Calculator._calculator.copySource = source or "click"
    box:SetText(result)
    box:SetCursorPosition(0)
    box:HighlightText(0, -1)
    box:SetFocus()
    Calculator._calculator.copyFocused = true

    Calculator._calculator.copyToken = (Calculator._calculator.copyToken or 0) + 1
    local token = Calculator._calculator.copyToken
    Utils.SafeAfter(0, function()
        local copyBox = Calculator._calculator.copyBox
        if Calculator._calculator.copyToken ~= token or not copyBox then return end
        if copyBox:GetText() ~= result then return end
        copyBox:SetFocus()
        copyBox:HighlightText(0, -1)
    end)
    return true
end

function Calculator:RearmActiveCalculatorCopy(source)
    local result = Calculator._calculator.activeResult
    if not result or result == "" then return false end
    if source == "ctrl" and Calculator._calculator.copyComplete then return false end
    local ok = self:CopyCalculatorResult(result, source or "active")
    if ok and source == "ctrl" then
        self:SuspendCalculatorNavForCopy()
    end
    return ok
end

function Calculator:SuspendCalculatorNavForCopy()
    if not GetNavFrame() then return end
    Calculator._calculator.navSuspendedForCopy = GetNavFrame():IsKeyboardEnabled()
    Utils.SafeCallMethod(GetNavFrame(), "EnableKeyboard", false)
end

function Calculator:RestoreSearchFocusAfterCalculatorCopy()
    Calculator._calculator.navSuspendedForCopy = nil
    Search:SetSelectedIndex(0)
    Search:SetToggleFocused(false)
    if GetNavFrame() then
        Utils.SafeCallMethod(GetNavFrame(), "EnableKeyboard", false)
    end

    local editBox = GetSearchFrame() and GetSearchFrame().editBox
    if editBox and editBox.IsVisible and editBox:IsVisible() then
        editBox.blockFocus = nil
        editBox:SetFocus()
        editBox:SetCursorPosition(#(editBox:GetText() or ""))
    end
end

function Calculator:EnsureCalculatorCopyWatcher()
    if Calculator._calculator.copyWatcher then return Calculator._calculator.copyWatcher end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("MODIFIER_STATE_CHANGED")
    frame:Hide()
    frame:SetScript("OnEvent", function(_, _, key, down)
        if not Calculator._calculator.activeData or not Calculator._calculator.activeResult then return end
        if key ~= "LCTRL" and key ~= "RCTRL" then return end

        if down == 1 and IsControlKeyDown and IsControlKeyDown() then
            Calculator._calculator.ctrlWasDown = true
            Calculator:RearmActiveCalculatorCopy("ctrl")
        elseif down == 0 and IsControlKeyDown and not IsControlKeyDown() then
            Calculator._calculator.ctrlWasDown = nil
            Calculator._calculator.copyKeyWasDown = nil
            Calculator:ReleaseCalculatorCopyBox()
        end
    end)
    Utils.SafeOnUpdate(frame, function(self)
        if not Calculator._calculator.activeData or not Calculator._calculator.activeResult then
            Calculator._calculator.ctrlWasDown = nil
            Calculator._calculator.copyKeyWasDown = nil
            self:Hide()
            return
        end

        local ctrlDown = IsControlKeyDown and IsControlKeyDown()
        if ctrlDown and not Calculator._calculator.ctrlWasDown then
            Calculator:RearmActiveCalculatorCopy("ctrl")
        end
        Calculator._calculator.ctrlWasDown = ctrlDown and true or nil

        local copyDown = ctrlDown and IsKeyDown
            and ((IsKeyDown("C") or IsKeyDown("c")) and true or false)
        if copyDown and not Calculator._calculator.copyKeyWasDown then
            Calculator:RearmActiveCalculatorCopy("confirm")
            Utils.SafeAfter(0, function()
                Calculator:ConfirmCalculatorCopied()
            end)
        end
        Calculator._calculator.copyKeyWasDown = copyDown and true or nil
    end)
    Calculator._calculator.copyWatcher = frame
    return frame
end

function Calculator:StartCalculatorCopyWatcher()
    local frame = self:EnsureCalculatorCopyWatcher()
    frame:Show()
end

function Calculator:GetCalculatorPartValue(row, part)
    local data = row and row.data
    if not data or not data.calculatorResult then return nil end
    if part == "expression" then
        return data.calculatorExpression or data.name
    end
    return data.calculatorResult
end

function Calculator:SetCalculatorCopyHighlight(row, part)
    if not row then return end



    local theme = Results.GetActiveTheme and Results:GetActiveTheme()
    local copiedR, copiedG, copiedB = 0.48, 1.0, 0.62
    local hintR, hintG, hintB = 0.72, 0.72, 0.72
    local activeR, activeG, activeB = GOLD_COLOR[1], GOLD_COLOR[2], GOLD_COLOR[3]
    local baseR, baseG, baseB = 0.96, 0.96, 0.96
    if theme and theme.lightTheme then
        copiedR, copiedG, copiedB = 0.05, 0.45, 0.18
        local faint = theme.textFaint or theme.pathColor
        hintR, hintG, hintB = faint[1], faint[2], faint[3]
        local accent = theme.pathColorHover or theme.leafColor
        activeR, activeG, activeB = accent[1], accent[2], accent[3]
        baseR, baseG, baseB = theme.leafColor[1], theme.leafColor[2], theme.leafColor[3]
    end
    local expressionActive = part == "expression"
    local resultActive = part == "result"
    local expressionCopied = expressionActive
        and Calculator._calculator.copiedData == row.data
        and Calculator._calculator.copiedPart == "expression"
    local resultCopied = resultActive
        and Calculator._calculator.copiedData == row.data
        and Calculator._calculator.copiedPart == "result"
    if row.calcExpressionHighlight then
        row.calcExpressionHighlight:SetShown(expressionActive)
    end
    if row.calcResultHighlight then
        row.calcResultHighlight:SetShown(resultActive)
    end
    if row.calcExpressionHint then
        row.calcExpressionHint:SetText(expressionCopied and L["CALC_PASTE_HINT"] or L["COPY_HINT"])
        if expressionCopied then
            row.calcExpressionHint:SetTextColor(copiedR, copiedG, copiedB, 1.0)
        else
            row.calcExpressionHint:SetTextColor(hintR, hintG, hintB, 1.0)
        end
        row.calcExpressionHint:SetShown(expressionActive)
    end
    if row.calcResultHint then
        row.calcResultHint:SetText(resultCopied and L["CALC_PASTE_HINT"] or L["COPY_HINT"])
        if resultCopied then
            row.calcResultHint:SetTextColor(copiedR, copiedG, copiedB, 1.0)
        else
            row.calcResultHint:SetTextColor(hintR, hintG, hintB, 1.0)
        end
        row.calcResultHint:SetShown(resultActive)
    end
    if row.calcExpressionText then
        row.calcExpressionText:ClearAllPoints()
        row.calcExpressionText:SetPoint("LEFT", row.calcCard, "LEFT", 12, expressionActive and 5 or 0)
        row.calcExpressionText:SetPoint("RIGHT", row.calcDivider, "LEFT", -22, expressionActive and 5 or 0)
        if expressionActive then
            row.calcExpressionText:SetTextColor(activeR, activeG, activeB, 1.0)
        else
            row.calcExpressionText:SetTextColor(baseR, baseG, baseB, 1.0)
        end
    end
    if row.calcResultText then
        row.calcResultText:ClearAllPoints()
        row.calcResultText:SetPoint("LEFT", row.calcDivider, "RIGHT", 22, resultActive and 5 or 0)
        row.calcResultText:SetPoint("RIGHT", row.calcCard, "RIGHT", -12, resultActive and 5 or 0)
        if resultActive then
            row.calcResultText:SetTextColor(activeR, activeG, activeB, 1.0)
        else
            row.calcResultText:SetTextColor(baseR, baseG, baseB, 1.0)
        end
    end
end

function Calculator:ClearCalculatorCopyHighlight(row)
    row = row or Calculator._calculator.activeRow
    if row then
        self:SetCalculatorCopyHighlight(row, nil)
    end
    if not row or Calculator._calculator.activeRow == row then
        Calculator._calculator.activeRow = nil
        Calculator._calculator.activeData = nil
        Calculator._calculator.activeResult = nil
        Calculator._calculator.activePart = nil
        Calculator._calculator.activeSource = nil
        Calculator._calculator.copyComplete = nil
        Calculator._calculator.copyCompleteValue = nil
        Calculator._calculator.copiedData = nil
        Calculator._calculator.copiedPart = nil
        if Calculator._calculator.copyWatcher then
            Calculator._calculator.copyWatcher:Hide()
        end
        Calculator._calculator.ctrlWasDown = nil
        Calculator._calculator.copyKeyWasDown = nil
    end
end

function Calculator:ArmCalculatorPartFromRow(row, part, source)
    if not row or not row:IsShown() or not row.data or not row.data.calculatorResult then
        return false
    end
    source = source or "click"
    part = part == "expression" and "expression" or "result"
    local value = self:GetCalculatorPartValue(row, part)
    if not value or value == "" then return false end

    local completedHover = source == "hover" and Calculator._calculator.copyComplete
    if source ~= "ctrl" and source ~= "confirm" and not completedHover then
        Calculator._calculator.copyComplete = nil
        Calculator._calculator.copyCompleteValue = nil
    end
    if Calculator._calculator.activeData ~= row.data or Calculator._calculator.activePart ~= part then
        Calculator._calculator.copiedData = nil
        Calculator._calculator.copiedPart = nil
    end
    if Calculator._calculator.activeRow and Calculator._calculator.activeRow ~= row then
        self:SetCalculatorCopyHighlight(Calculator._calculator.activeRow, nil)
    end
    if source ~= "hover" or ((IsControlKeyDown and IsControlKeyDown()) and not Calculator._calculator.copyComplete) then
        if not self:CopyCalculatorResult(value, source) then
            return false
        end
    end
    Calculator._calculator.activeRow = row
    Calculator._calculator.activeData = row.data
    Calculator._calculator.activeResult = value
    Calculator._calculator.activePart = part
    Calculator._calculator.activeSource = source
    self:SetCalculatorCopyHighlight(row, part)
    self:StartCalculatorCopyWatcher()
    return true
end

function Calculator:ArmCalculatorResultFromRow(row, source)
    return self:ArmCalculatorPartFromRow(row, "result", source or "click")
end

function Calculator:ArmCalculatorResultForData(data, source)
    if not data or not data.calculatorResult then return false end
    for i = 1, #GetResultButtons() do
        local row = GetResultButtons()[i]
        if row and row:IsShown() and row.data == data then
            return self:ArmCalculatorResultFromRow(row, source or "click")
        end
    end
    source = source or "click"
    if self:CopyCalculatorResult(data.calculatorResult, source) then
        Calculator._calculator.activeRow = nil
        Calculator._calculator.activeData = data
        Calculator._calculator.activeResult = data.calculatorResult
        Calculator._calculator.activePart = "result"
        Calculator._calculator.activeSource = source
        Calculator._calculator.copyComplete = nil
        Calculator._calculator.copyCompleteValue = nil
        Calculator._calculator.copiedData = nil
        Calculator._calculator.copiedPart = nil
        self:StartCalculatorCopyWatcher()
        return true
    end
    return false
end

function Calculator:PlayCalculatorCopyFlash(row, part)
    if not row then return end
    local flash = part == "expression" and row.calcExpressionFlash or row.calcResultFlash
    if not flash then return end
    flash:SetAlpha(0.0)
    flash:Show()
    if flash.anim then
        if flash.anim:IsPlaying() then flash.anim:Stop() end
        flash.anim:Play()
    else
        flash:SetAlpha(0.35)
        Utils.SafeAfter(0.35, function()
            if flash then
                flash:SetAlpha(0.0)
                flash:Hide()
            end
        end)
    end
end

function Calculator:ConfirmCalculatorCopied()
    local data = Calculator._calculator.activeData
    local part = Calculator._calculator.activePart
    if not data or (part ~= "expression" and part ~= "result") then return false end
    local popupCopy = Calculator._calculator.activeSource == "calculator"
    self:RearmActiveCalculatorCopy("confirm")

    Calculator._calculator.copiedData = data
    Calculator._calculator.copiedPart = part
    Calculator._calculator.copyComplete = true
    Calculator._calculator.copyCompleteValue = Calculator._calculator.activeResult

    local row = Calculator._calculator.activeRow
    if not (row and row:IsShown() and row.data == data) then
        row = nil
        for i = 1, #GetResultButtons() do
            local candidate = GetResultButtons()[i]
            if candidate and candidate:IsShown() and candidate.data == data then
                row = candidate
                Calculator._calculator.activeRow = candidate
                break
            end
        end
    end

    if row then
        self:SetCalculatorCopyHighlight(row, part)
        self:PlayCalculatorCopyFlash(row, part)
    end
    if popupCopy then
        self:UpdateCalculatorPopupCopyVisual(Calculator._calculator.popupData)
    end
    Utils.SafeAfter(0, function()
        Calculator:ReleaseCalculatorCopyBox("confirm")
        if popupCopy then
            Calculator:RestoreCalculatorPopupFocus()
        else
            Search:RestoreSearchFocusAfterCalculatorCopy()
        end
    end)
    return true
end

function Calculator:RestoreCalculatorTarget(row)
    if row and Calculator._calculator.activeData == row.data and Calculator._calculator.activeSource == "hover" then
        self:ClearCalculatorCopyHighlight(row)
        self:ReleaseCalculatorCopyBox()
    elseif row and Calculator._calculator.activeData == row.data then
        self:SetCalculatorCopyHighlight(row, Calculator._calculator.activePart)
    elseif row then
        self:SetCalculatorCopyHighlight(row, nil)
    end
end

function Calculator:HoverCalculatorTarget(row, part)
    if not row or not row.data or not row.data.calculatorResult then return end
    if Calculator._calculator.activeSource ~= "hover" and Calculator._calculator.activeData then
        self:ClearCalculatorCopyHighlight(Calculator._calculator.activeRow)
        self:ReleaseCalculatorCopyBox()
    end
    self:ArmCalculatorPartFromRow(row, part, "hover")
end

function Calculator:IsCalculatorCopyConfirmKey(key)
    return Calculator._calculator.activeData
        and IsControlKeyDown and IsControlKeyDown()
        and (key == "C" or key == "c")
end

function Calculator:HandleCalculatorCopyConfirmKey(key)
    if not self:IsCalculatorCopyConfirmKey(key) then return false end
    return self:ConfirmCalculatorCopied()
end

function Calculator:IsCalculatorCopyKey(key)
    if not Calculator._calculator.activeData then return false end
    if key == "LEFT" or key == "ARROWLEFT" or key == "RIGHT" or key == "ARROWRIGHT" then
        return true
    end
    return IsAltKeyDown and IsAltKeyDown() and (key == "H" or key == "L")
end

function Calculator:HandleCalculatorCopyKey(key)
    if not self:IsCalculatorCopyKey(key) then return false end
    local row = Calculator._calculator.activeRow
    if not (row and row:IsShown() and row.data == Calculator._calculator.activeData) then
        for i = 1, #GetResultButtons() do
            local candidate = GetResultButtons()[i]
            if candidate and candidate:IsShown() and candidate.data == Calculator._calculator.activeData then
                row = candidate
                Calculator._calculator.activeRow = candidate
                break
            end
        end
    end
    if not row then return true end

    if key == "LEFT" or key == "ARROWLEFT" or key == "H" then
        self:ArmCalculatorPartFromRow(row, "expression", "key")
    else
        self:ArmCalculatorPartFromRow(row, "result", "key")
    end
    return true
end

function Calculator:HandleCalculatorPasteIntoSearch(editBox, key)
    if not editBox or not Calculator._calculator.copyCompleteValue then return false end
    if not (IsControlKeyDown and IsControlKeyDown()) then return false end
    if key ~= "V" and key ~= "v" then return false end

    local expected = Calculator._calculator.copyCompleteValue
    if expected == "" then return false end
    Utils.SafeAfter(0, function()
        if not GetSearchFrame() or GetSearchFrame().editBox ~= editBox then return end
        if not editBox:IsVisible() then return end
        local current = editBox:GetText() or ""
        if current ~= expected and strtrim(current) ~= strtrim(expected) then return end
        if editBox.ResetPendingSearch then editBox:ResetPendingSearch() end
        Results:HideResults()
        editBox:SetFocus()
        editBox:SetCursorPosition(#current)
    end)
    return false
end

function Calculator:ArmCalculatorSelectionForKeyboard(row)
    if not row or not row:IsShown() or not row.data or not row.data.calculatorResult then
        return false
    end
    return self:ArmCalculatorResultFromRow(row, "key")
end


EasyFind.API.RegisterExtension({
    id = "calculator", name = L["UITREE_CALCULATOR"], description = L["APP_DESC_CALCULATOR"],
    icon = ns.CALCULATOR_ICON_TEX, _path = Calculator._calculator.PATH,

    hideFromSearch = true,
    open = function() ns.ResultHandlers:OpenCalculator("") end,
    isOpen = function()
        local frame = Calculator._calculator.popupFrame
        return frame ~= nil and frame:IsShown()
    end,
    close = function()
        local frame = Calculator._calculator.popupFrame
        if frame then frame:Hide() end
    end,
})
