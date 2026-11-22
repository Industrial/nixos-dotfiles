local _, ns = ...

local Search = ns.Search
local Calculator = ns.Calculator
local Results = ns.Results
local Rows = ns.ResultRows
local Shortcuts = ns.ResultShortcuts
local L = ns.L

local CreateFrame = CreateFrame

local RESULT_SHORTCUT = Shortcuts.RESULT_SHORTCUT

local CALC_CARD_BAR_HEIGHT = 12

local function CreateCalcWash(calcCard, r, g, b, a)
    local wash = CreateFrame("Frame", nil, calcCard)
    ns.CreateRoundedRectBorder(wash)
    ns.SetRoundedRectBarHeight(wash, CALC_CARD_BAR_HEIGHT)
    ns.SetRoundedRectRingShown(wash, false)
    ns.SetRoundedRectBorderFillColor(wash, r, g, b, a)
    wash:Hide()
    return wash
end

local function CreateCalcFlash(calcCard)
    local flash = CreateCalcWash(calcCard, 0.48, 1.0, 0.62, 0.35)
    flash.anim = flash:CreateAnimationGroup()
    local flashAlpha = flash.anim:CreateAnimation("Alpha")
    flashAlpha:SetFromAlpha(0.42)
    flashAlpha:SetToAlpha(0)
    flashAlpha:SetDuration(0.42)
    flashAlpha:SetSmoothing("OUT")
    flash.anim:SetScript("OnFinished", function()
        flash:Hide()
    end)
    return flash
end

function Rows.CreateCalculatorWidgets(resultRow, index)
    local calcCard = CreateFrame("Frame", nil, resultRow)
    ns.CreateRoundedRectBorder(calcCard)
    ns.SetRoundedRectBarHeight(calcCard, CALC_CARD_BAR_HEIGHT)
    ns.SetRoundedRectBorderFillColor(calcCard, 0.095, 0.095, 0.108, 1)
    ns.SetRoundedRectRingShown(calcCard, false)
    calcCard:Hide()
    resultRow.calcCard = calcCard

    local calcDivider = calcCard:CreateTexture(nil, "ARTWORK")
    calcDivider:SetColorTexture(0.30, 0.30, 0.32, 0)
    calcDivider:SetWidth(1)
    resultRow.calcDivider = calcDivider

    local calcDividerTop = calcCard:CreateTexture(nil, "ARTWORK")
    calcDividerTop:SetColorTexture(0.34, 0.34, 0.36, 0.86)
    calcDividerTop:SetWidth(1)
    calcDividerTop:Hide()
    resultRow.calcDividerTop = calcDividerTop

    local calcDividerBottom = calcCard:CreateTexture(nil, "ARTWORK")
    calcDividerBottom:SetColorTexture(0.34, 0.34, 0.36, 0.86)
    calcDividerBottom:SetWidth(1)
    calcDividerBottom:Hide()
    resultRow.calcDividerBottom = calcDividerBottom

    resultRow.calcExpressionHighlight = CreateCalcWash(calcCard, 1.0, 0.82, 0.22, 0.20)
    resultRow.calcResultHighlight = CreateCalcWash(calcCard, 1.0, 0.82, 0.22, 0.20)
    resultRow.calcExpressionFlash = CreateCalcFlash(calcCard)
    resultRow.calcResultFlash = CreateCalcFlash(calcCard)

    local calcExpressionText = calcCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    calcExpressionText:SetJustifyH("CENTER")
    calcExpressionText:SetWordWrap(false)
    calcExpressionText:SetTextColor(0.96, 0.96, 0.96, 1.0)
    resultRow.calcExpressionText = calcExpressionText

    local calcArrowText = calcCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    calcArrowText:SetText("=")
    calcArrowText:SetTextColor(0.86, 0.86, 0.86, 1.0)
    resultRow.calcArrowText = calcArrowText

    local calcResultText = calcCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    calcResultText:SetJustifyH("CENTER")
    calcResultText:SetWordWrap(false)
    calcResultText:SetTextColor(0.96, 0.96, 0.96, 1.0)
    resultRow.calcResultText = calcResultText

    local calcExpressionHint = calcCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    calcExpressionHint:SetText(L["COPY_HINT"])
    calcExpressionHint:SetJustifyH("CENTER")
    calcExpressionHint:SetTextColor(0.72, 0.72, 0.72, 1.0)
    calcExpressionHint:SetPoint("TOP", calcExpressionText, "BOTTOM", 0, -1)
    calcExpressionHint:Hide()
    resultRow.calcExpressionHint = calcExpressionHint

    local calcResultHint = calcCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    calcResultHint:SetText(L["COPY_HINT"])
    calcResultHint:SetJustifyH("CENTER")
    calcResultHint:SetTextColor(0.72, 0.72, 0.72, 1.0)
    calcResultHint:SetPoint("TOP", calcResultText, "BOTTOM", 0, -1)
    calcResultHint:Hide()
    resultRow.calcResultHint = calcResultHint

    local calcExpressionButton = CreateFrame("Button", nil, calcCard)
    calcExpressionButton:RegisterForClicks("LeftButtonUp")
    calcExpressionButton:SetFrameLevel(resultRow:GetFrameLevel() + 10)
    calcExpressionButton:SetScript("OnEnter", function()
        Calculator:HoverCalculatorTarget(resultRow, "expression")
    end)
    calcExpressionButton:SetScript("OnLeave", function()
        Calculator:RestoreCalculatorTarget(resultRow)
    end)
    calcExpressionButton:SetScript("OnClick", function()
        Search:SetSelectedIndex(index)
        Search:SetToggleFocused(false)
        Results:UpdateSelectionHighlight(true)
        Calculator:ArmCalculatorPartFromRow(resultRow, "expression", "click")
    end)
    calcExpressionButton:Hide()
    resultRow.calcExpressionButton = calcExpressionButton

    local calcResultButton = CreateFrame("Button", nil, calcCard)
    calcResultButton:RegisterForClicks("LeftButtonUp")
    calcResultButton:SetFrameLevel(resultRow:GetFrameLevel() + 10)
    calcResultButton:SetScript("OnEnter", function()
        Calculator:HoverCalculatorTarget(resultRow, "result")
    end)
    calcResultButton:SetScript("OnLeave", function()
        Calculator:RestoreCalculatorTarget(resultRow)
    end)
    calcResultButton:SetScript("OnClick", function()
        Search:SetSelectedIndex(index)
        Search:SetToggleFocused(false)
        Results:UpdateSelectionHighlight(true)
        Calculator:ArmCalculatorPartFromRow(resultRow, "result", "click")
    end)
    calcResultButton:Hide()
    resultRow.calcResultButton = calcResultButton

    local shortcutGroup = CreateFrame("Frame", nil, resultRow)
    shortcutGroup:Hide()
    resultRow.shortcutGroup = shortcutGroup

    local shortcutAltIcon = shortcutGroup:CreateTexture(nil, "OVERLAY")
    shortcutAltIcon:SetTexture(RESULT_SHORTCUT.icon)
    shortcutAltIcon:SetSize(RESULT_SHORTCUT.iconSize, RESULT_SHORTCUT.iconSize)
    shortcutAltIcon:SetVertexColor(0.58, 0.58, 0.58, 0.85)
    resultRow.shortcutAltIcon = shortcutAltIcon

    local shortcutNumberText = shortcutGroup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    shortcutNumberText:SetJustifyH("RIGHT")
    shortcutNumberText:SetTextColor(0.58, 0.58, 0.58, 0.85)
    shortcutNumberText:SetText("")
    resultRow.shortcutNumberText = shortcutNumberText
    Shortcuts:LayoutResultShortcut(resultRow)

end





function Rows.ApplyCalcCardTheme(resultRow)
    local fill = ns.SECTION_TABLE_FILL
    ns.SetRoundedRectBorderFillColor(resultRow.calcCard, fill[1], fill[2], fill[3], 1)
    local theme = Results.GetActiveTheme and Results:GetActiveTheme()
    if theme and theme.lightTheme then
        local leaf = theme.leafColor
        local faint = theme.textFaint or theme.pathColor
        resultRow.calcExpressionText:SetTextColor(leaf[1], leaf[2], leaf[3], 1)
        resultRow.calcResultText:SetTextColor(leaf[1], leaf[2], leaf[3], 1)
        resultRow.calcArrowText:SetTextColor(faint[1], faint[2], faint[3], 1)
        resultRow.calcExpressionHint:SetTextColor(faint[1], faint[2], faint[3], 1)
        resultRow.calcResultHint:SetTextColor(faint[1], faint[2], faint[3], 1)
    else
        resultRow.calcExpressionText:SetTextColor(0.96, 0.96, 0.96, 1)
        resultRow.calcResultText:SetTextColor(0.96, 0.96, 0.96, 1)
        resultRow.calcArrowText:SetTextColor(0.86, 0.86, 0.86, 1)
        resultRow.calcExpressionHint:SetTextColor(0.72, 0.72, 0.72, 1)
        resultRow.calcResultHint:SetTextColor(0.72, 0.72, 0.72, 1)
    end
end

