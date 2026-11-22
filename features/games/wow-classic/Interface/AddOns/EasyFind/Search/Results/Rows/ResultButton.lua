local _, ns = ...

local Search = ns.Search
local Results = ns.Results
local Rows = ns.ResultRows
local Utils = ns.Utils

local GOLD_COLOR = ns.GOLD_COLOR
local TOOLTIP_BORDER = ns.TOOLTIP_BORDER

local CreateFrame = CreateFrame

local REP_BAR_WIDTH = 100

local INDENT_COLORS = {
    {0.40, 0.85, 1.00, 0.80},
    {1.00, 0.55, 0.10, 0.80},
    {0.55, 1.00, 0.35, 0.80},
    {1.00, 0.40, 0.70, 0.80},
    {0.70, 0.55, 1.00, 0.80},
    {1.00, 0.90, 0.20, 0.80},
}
local INDENT_PX  = 20
local LINE_X_OFF = 10
local LINE_W     = 2
local MAX_DEPTH  = 0

local function ResultsFrame()
    return Search:GetResultsFrame()
end

function Rows:CreateResultButton(index)
    local scrollChild = ResultsFrame().scrollChild
    local resultRow = CreateFrame("Button", "EasyFindResultButton"..index, scrollChild, "SecureActionButtonTemplate")
    resultRow:SetSize(360, 22)
    resultRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, -8 - (index - 1) * 22)




    if ns.Caps.questLogAtlas then
        resultRow:SetHighlightAtlas("QuestLog-quest-glow-yellow")
    else
        resultRow:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    end
    local hlTex = resultRow:GetHighlightTexture()
    if hlTex then hlTex:SetBlendMode("ADD") end





    local separator = resultRow:CreateTexture(nil, "ARTWORK", nil, 0)
    separator:SetColorTexture(0.5, 0.45, 0.3, 0.3)
    separator:SetHeight(1)
    separator:SetPoint("BOTTOMLEFT", resultRow, "BOTTOMLEFT", 4, 0)
    separator:SetPoint("BOTTOMRIGHT", resultRow, "BOTTOMRIGHT", -4, 0)
    separator:Hide()
    resultRow.separator = separator

    resultRow.treeVert   = {}
    resultRow.treeBranch = {}
    resultRow.treeElbow  = {}

    for d = 1, MAX_DEPTH do
        local c = INDENT_COLORS[d]
        local xCenter = (d - 1) * INDENT_PX + LINE_X_OFF

        local vert = resultRow:CreateTexture(nil, "BACKGROUND")
        vert:SetColorTexture(Utils.RGB(c, 1))
        vert:SetWidth(LINE_W)
        vert:SetPoint("TOP",    resultRow, "TOPLEFT",    xCenter, 3)
        vert:SetPoint("BOTTOM", resultRow, "BOTTOMLEFT", xCenter, -1)
        vert:Hide()
        resultRow.treeVert[d] = vert

        local elbow = resultRow:CreateTexture(nil, "BACKGROUND")
        elbow:SetColorTexture(Utils.RGB(c, 1))
        elbow:SetWidth(LINE_W)
        elbow:SetPoint("TOP", resultRow, "TOPLEFT", xCenter, 3)
        elbow:SetHeight(13)
        elbow:Hide()
        resultRow.treeElbow[d] = elbow

        local branch = resultRow:CreateTexture(nil, "BACKGROUND")
        branch:SetColorTexture(Utils.RGB(c, 1))
        branch:SetHeight(LINE_W)
        branch:SetPoint("LEFT",  resultRow, "TOPLEFT", xCenter - 1, -11)
        branch:SetPoint("RIGHT", resultRow, "TOPLEFT", xCenter + INDENT_PX - LINE_X_OFF, -11)
        branch:Hide()
        resultRow.treeBranch[d] = branch
    end

    local icon = resultRow:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", 0, 0)
    resultRow.icon = icon


    local iconCooldown = CreateFrame("Cooldown", nil, resultRow, "CooldownFrameTemplate")
    iconCooldown:SetDrawEdge(true)
    iconCooldown:SetHideCountdownNumbers(true)
    iconCooldown:Hide()
    resultRow.iconCooldown = iconCooldown



    local pinIcon = Utils.CreatePinGlyph(resultRow, 11)
    pinIcon:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", -4, -1)
    pinIcon:Hide()
    resultRow.pinIcon = pinIcon


    local pinToggle = resultRow:CreateTexture(nil, "ARTWORK")
    pinToggle:SetSize(14, 14)
    pinToggle:SetPoint("RIGHT", resultRow, "RIGHT", -8, 0)
    ns.SetQuestLogToggle(pinToggle, false)
    pinToggle:Hide()
    resultRow.pinToggle = pinToggle


    local pinHeaderLine = resultRow:CreateTexture(nil, "ARTWORK")
    pinHeaderLine:SetHeight(1)
    pinHeaderLine:SetColorTexture(Utils.RGB(GOLD_COLOR, 0.4))
    pinHeaderLine:SetPoint("BOTTOMLEFT", resultRow, "BOTTOMLEFT", 0, 0)
    pinHeaderLine:SetPoint("BOTTOMRIGHT", resultRow, "BOTTOMRIGHT", 0, 0)
    pinHeaderLine:Hide()
    resultRow.pinHeaderLine = pinHeaderLine






    local sectionLabelLeft = resultRow:CreateTexture(nil, "ARTWORK")
    sectionLabelLeft:SetHeight(1)
    sectionLabelLeft:SetColorTexture(Utils.RGB(GOLD_COLOR, 0.4))
    sectionLabelLeft:Hide()
    resultRow.sectionLabelLeft = sectionLabelLeft

    local sectionLabelRight = resultRow:CreateTexture(nil, "ARTWORK")
    sectionLabelRight:SetHeight(1)
    sectionLabelRight:SetColorTexture(Utils.RGB(GOLD_COLOR, 0.4))
    sectionLabelRight:Hide()
    resultRow.sectionLabelRight = sectionLabelRight

    local sectionLabelText = resultRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sectionLabelText:SetPoint("CENTER", resultRow, "CENTER", 0, 0)
    sectionLabelText:SetTextColor(Utils.RGB(GOLD_COLOR))
    sectionLabelText:Hide()
    resultRow.sectionLabelText = sectionLabelText


    local amountText = resultRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    amountText:SetPoint("RIGHT", resultRow, "RIGHT", -8, 0)
    amountText:SetJustifyH("RIGHT")
    amountText:SetTextColor(0.9, 0.82, 0.65, 1.0)
    amountText:Hide()
    resultRow.amountText = amountText

    local decorText = resultRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    decorText:SetJustifyH("RIGHT")
    decorText:Hide()
    resultRow.decorText = decorText

    Rows.CreateCalculatorWidgets(resultRow, index)
    Rows.CreateSettingWidgets(resultRow)

    local repBarBackdrop = {
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = TOOLTIP_BORDER,
        tile = true, tileSize = 8, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    }

    local repBar = CreateFrame("Frame", nil, resultRow, BackdropTemplateMixin and "BackdropTemplate")
    repBar:SetSize(REP_BAR_WIDTH, 19)
    repBar:SetPoint("RIGHT", resultRow, "RIGHT", -6, 0)
    if repBar.SetBackdrop then
        repBar:SetBackdrop(repBarBackdrop)
        repBar:SetBackdropColor(0.06, 0.06, 0.06, 1.0)
        repBar:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    end
    repBar:Hide()
    resultRow.repBar = repBar

    local repClip = CreateFrame("Frame", nil, repBar)
    repClip:SetPoint("TOPLEFT", repBar, "TOPLEFT", 0, 0)
    repClip:SetPoint("BOTTOMLEFT", repBar, "BOTTOMLEFT", 0, 0)
    repClip:SetWidth(REP_BAR_WIDTH)
    repClip:SetClipsChildren(true)
    resultRow.repClip = repClip

    local repFill = CreateFrame("Frame", nil, repClip, BackdropTemplateMixin and "BackdropTemplate")
    repFill:SetPoint("TOPLEFT", repBar, "TOPLEFT", 0, 0)
    repFill:SetPoint("BOTTOMRIGHT", repBar, "BOTTOMRIGHT", 0, 0)
    if repFill.SetBackdrop then
        repFill:SetBackdrop(repBarBackdrop)
        repFill:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    end
    resultRow.repFill = repFill



    local repBarTex = repFill:CreateTexture(nil, "ARTWORK")
    repBarTex:SetPoint("TOPLEFT", repFill, "TOPLEFT", 3, -3)
    repBarTex:SetPoint("BOTTOMRIGHT", repFill, "BOTTOMRIGHT", -3, 3)
    repBarTex:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    resultRow.repBarTex = repBarTex


    local repTextOverlay = CreateFrame("Frame", nil, repBar)
    repTextOverlay:SetAllPoints()
    repTextOverlay:SetFrameLevel(repFill:GetFrameLevel() + 3)
    local repBarText = repTextOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    repBarText:SetPoint("CENTER", repBar, "CENTER", 0, 0)
    repBarText:SetTextColor(1.0, 1.0, 1.0, 1.0)
    repBarText:SetShadowOffset(1, -1)
    resultRow.repBarText = repBarText

    local text = resultRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    text:SetPoint("RIGHT", amountText, "LEFT", -4, 0)
    text:SetJustifyH("LEFT")



    text:SetWordWrap(false)
    text:SetNonSpaceWrap(false)
    text:SetMaxLines(1)
    resultRow.text = text




    local pathSubtext = resultRow:CreateFontString(nil, "OVERLAY", ns.LEAF_FONT)
    pathSubtext:SetJustifyH("LEFT")
    pathSubtext:SetWordWrap(false)
    pathSubtext:SetNonSpaceWrap(false)
    pathSubtext:SetMaxLines(1)
    pathSubtext:Hide()
    resultRow.pathSubtext = pathSubtext




    local flatCatIcon = resultRow:CreateTexture(nil, "ARTWORK")
    flatCatIcon:Hide()
    resultRow.flatCatIcon = flatCatIcon




    local createBadge = resultRow:CreateTexture(nil, "OVERLAY", nil, 7)
    createBadge:SetSize(13, 13)
    createBadge:SetTexture("Interface\\AddOns\\EasyFind\\textures\\snippet-create-badge")
    createBadge:SetVertexColor(0.302, 1.0, 0.302, 1)
    createBadge:SetPoint("BOTTOMLEFT", flatCatIcon, "BOTTOMRIGHT", -7, -1)
    createBadge:Hide()
    resultRow.createBadge = createBadge

    local createGlow = resultRow:CreateTexture(nil, "OVERLAY", nil, 6)
    createGlow:SetPoint("CENTER", createBadge, "CENTER", 0, 0)
    createGlow:SetSize(28, 28)
    createGlow:SetAtlas("collections-newglow")
    createGlow:SetVertexColor(0.3, 1.0, 0.35, 0.9)
    createGlow:SetBlendMode("ADD")
    createGlow:Hide()
    resultRow.createGlow = createGlow

    Rows.InstallInteractions(resultRow, index)

    Rows.InstallTooltips(resultRow)

    Results:ApplyResultRowFonts(resultRow)
    resultRow:Hide()
    return resultRow
end
