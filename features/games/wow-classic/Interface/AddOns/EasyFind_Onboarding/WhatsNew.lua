

local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns or select(2, ...).stale then return end

local Onboarding = ns.Onboarding
local L = ns.L
local Utils = ns.Utils

local CreateFrame = CreateFrame
local UIParent = UIParent
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local mmax, mmin, mceil, mfloor = math.max, math.min, math.ceil, math.floor

local GOLD     = ns.GOLD_COLOR
local TEXT_BODY = ns.TEXT_BODY
local TEXT_DIM  = ns.TEXT_DIM
local PANEL_BG_ALPHA = 0.97



local WN_MIN_W = 340
local WN_MAX_W = 470
local WN_PAD_X = 22
local WN_PAD_TOP = 22
local WN_PAD_BOTTOM = 18
local WN_TITLE_GAP = 6
local WN_BODY_GAP = 18
local WN_BTN_GAP = 14
local WN_BTN_MIN_W = 130
local WN_BTN_H = 22
local WN_BTN_TEXT_PAD = 24
local WN_BODY_MAX_H = 280
local WN_WHEEL = 28





local HEARTHSTONE_ITEM_ID = 6948
local function BodyText()
    local name = GetItemInfo and GetItemInfo(HEARTHSTONE_ITEM_ID)
    return Utils.sformat(L["WHATSNEW_BODY"], name or "Hearthstone")
end

local frame






local BULLET = "|cffFFD100\226\128\162|r"
local SHOWME_TOKEN = "{showme:([%w_]+)}"
local WN_BLOCK_GAP = 10
local WN_TITLE_BODY_GAP = 4

local function ParseFeatures(text)
    local features, current = {}, nil
    for line in (text .. "\n"):gmatch("(.-)\n") do
        if line:sub(1, #BULLET) == BULLET then
            local showme = line:match(SHOWME_TOKEN)
            line = line:gsub("%s*{showme:[%w_]+}", "")
            current = { title = line, lines = {}, showme = showme }
            features[#features + 1] = current
        else
            if not current then
                current = { lines = {} }
                features[#features + 1] = current
            end
            current.lines[#current.lines + 1] = line
        end
    end
    return features
end

local function EnsureBlock(blocks, i)
    local b = blocks.pool[i]
    if b then return b end
    b = {}
    b.title = blocks:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.title:SetJustifyH("LEFT")
    b.title:SetTextColor(Utils.RGB(TEXT_BODY, 1))
    b.body = blocks:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.body:SetJustifyH("LEFT")
    b.body:SetJustifyV("TOP")
    b.body:SetSpacing(4)
    b.body:SetTextColor(Utils.RGB(TEXT_BODY, 1))
    b.btn = ns.CreateModernButton(blocks, L["WHATSNEW_SHOW_ME"], 60, 18)
    b.btn:SetSize(mceil(b.btn._label:GetStringWidth()) + 16, 18)
    b.btn:SetScript("OnClick", function(self)
        local id = self._showme
        local f = frame
        if not (id and ns.ShowMe and f) then return end




        if ns.ShowMe:IsPlaying() then ns.ShowMe:Stop() end
        f._reshow = true
        f:Hide()
        ns.ShowMe:Play(id, function()
            if f._reshow then
                f._reshow = nil
                f:Show()
            end
        end)
    end)
    blocks.pool[i] = b
    return b
end






local function Hex(c)
    return string.format("%02x%02x%02x", mfloor(c[1] * 255 + 0.5), mfloor(c[2] * 255 + 0.5), mfloor(c[3] * 255 + 0.5))
end
local function ForTheme(text)
    local theme = ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
    if not (text and theme and theme.lightTheme) then return text end
    return (text:gsub("|c[fF][fF]([%x][%x][%x][%x][%x][%x])", function(rgb)
        rgb = rgb:lower()
        if rgb == "ffffff" then return "|cff" .. Hex(theme.pathColorHover) end
        if rgb == "999999" then return "|cff" .. Hex(theme.textFaint) end
        if rgb == "ffd100" then return "|cff" .. Hex(theme.accent) end
    end))
end

local function RenderFeatures(blocks, features)
    local y = 0
    for i, feat in ipairs(features) do
        local b = EnsureBlock(blocks, i)
        local hasTitle = feat.title ~= nil
        b.title:ClearAllPoints()
        b.title:SetText(ForTheme(feat.title) or "")
        b.title:SetShown(hasTitle)
        local offer = hasTitle and feat.showme and ns.ShowMe and ns.ShowMe:Has(feat.showme)
        b.btn._showme = offer and feat.showme or nil
        b.btn:SetShown(offer and true or false)
        if hasTitle then
            b.title:SetPoint("TOPLEFT", blocks, "TOPLEFT", 0, -y)
            b.btn:ClearAllPoints()
            b.btn:SetPoint("LEFT", b.title, "RIGHT", 10, 0)
            y = y + mceil(b.title:GetStringHeight()) + WN_TITLE_BODY_GAP
        end
        b.body:ClearAllPoints()
        b.body:SetPoint("TOPLEFT", blocks, "TOPLEFT", 0, -y)
        b.body:SetPoint("RIGHT", blocks, "RIGHT", 0, 0)
        b.body:SetText(ForTheme(table.concat(feat.lines, "\n")))
        b.body:SetShown(#feat.lines > 0)
        if #feat.lines > 0 then y = y + mceil(b.body:GetStringHeight()) end
        y = y + WN_BLOCK_GAP
    end
    for i = #features + 1, #blocks.pool do
        local b = blocks.pool[i]
        b.title:Hide()
        b.body:Hide()
        b.btn:Hide()
    end
    y = mmax(1, y - WN_BLOCK_GAP)
    blocks:SetHeight(y)
    return y
end

function Onboarding:ShowWhatsNew(version)
    if frame and frame:IsShown() then return end

    if not frame then
        local f = CreateFrame("Frame", "EasyFindWhatsNew", UIParent)
        f:SetSize(WN_MAX_W, 280)
        f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetFrameLevel(220)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:SetClampedToScreen(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        frame = f

        ns.StyleWizardPanel(f, PANEL_BG_ALPHA)

        local closeBtn = ns.CreateCloseX(f)
        closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
        closeBtn:SetScript("OnClick", function() f:Hide() end)

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", f, "TOP", 0, -WN_PAD_TOP)
        title:SetText(L["WHATSNEW_TITLE"])
        title:SetTextColor(Utils.RGB(GOLD, 1))
        f._title = title

        local verText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        verText:SetPoint("TOP", title, "BOTTOM", 0, -WN_TITLE_GAP)
        verText:SetTextColor(Utils.RGB(TEXT_DIM, 1))
        f._verText = verText



        local scroll = CreateFrame("ScrollFrame", nil, f)
        scroll:SetPoint("TOPLEFT", f, "TOPLEFT", WN_PAD_X, 0)
        scroll:SetPoint("TOPRIGHT", f, "TOPRIGHT", -WN_PAD_X, 0)
        scroll:SetHeight(1)
        local blocks = CreateFrame("Frame", nil, scroll)
        blocks:SetSize(WN_MAX_W - WN_PAD_X * 2, 1)
        blocks.pool = {}
        scroll:SetScrollChild(blocks)
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function(self, delta)
            local most = mmax(0, blocks:GetHeight() - self:GetHeight())
            self:SetVerticalScroll(mmin(most, mmax(0, self:GetVerticalScroll() - delta * WN_WHEEL)))
        end)
        f._scroll, f._blocks = scroll, blocks
        local bar = Utils.CreateMinimalScrollBar(scroll, f, { moreBelow = true })
        bar:ClearAllPoints()
        bar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 14, -2)
        bar:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 14, 2)
        f._bar = bar





        local changelogLink = CreateFrame("Button", nil, f)
        local changelogText = changelogLink:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        changelogText:SetPoint("CENTER")
        changelogText:SetText(L["WHATSNEW_CHANGELOG_LINK"])
        changelogText:SetTextColor(Utils.RGB(GOLD, 1))
        changelogLink:SetSize(changelogText:GetStringWidth() + 8, 16)
        changelogLink:SetPoint("TOP", scroll, "BOTTOM", 0, -10)
        local copyHint = changelogLink:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        copyHint:SetPoint("LEFT", changelogText, "RIGHT", 6, 0)
        copyHint:Hide()
        changelogLink._efCopyText = ns.GITHUB_CHANGELOG_URL
        changelogLink._efCopyHint = copyHint
        changelogLink:SetScript("OnEnter", function(self)
            changelogText:SetTextColor(1, 1, 1)
            copyHint:SetText("Ctrl+C")
            copyHint:SetTextColor(Utils.RGB(TEXT_DIM, 1))
            copyHint:Show()
            if ns.RowCopy then ns.RowCopy:OnRowHover(self) end
        end)
        changelogLink:SetScript("OnLeave", function()
            changelogText:SetTextColor(Utils.RGB(GOLD, 1))
            copyHint:Hide()
            if ns.RowCopy then ns.RowCopy:OnRowHover(nil) end
        end)
        changelogLink:SetScript("OnClick", function(self)
            if ns.RowCopy then ns.RowCopy:ArmFor(self) end
        end)
        if ns.RowCopy and ns.RowCopy.RegisterHoverScanner then
            ns.RowCopy:RegisterHoverScanner(function()
                if changelogLink:IsVisible() and changelogLink:IsMouseOver() then
                    return changelogLink
                end
                return nil
            end)
        end
        f:HookScript("OnHide", function()
            if ns.RowCopy then ns.RowCopy:OnRowHover(nil) end
        end)
        f._changelogLink = changelogLink

        local okBtn = ns.CreateModernButton(f, L["WHATSNEW_GOT_IT"], WN_BTN_MIN_W, WN_BTN_H)
        okBtn:SetPoint("TOP", changelogLink, "BOTTOM", 0, -WN_BTN_GAP)
        okBtn:SetScript("OnClick", function() f:Hide() end)
        f._okBtn = okBtn

        okBtn:SetSize(mmax(WN_BTN_MIN_W,
            mceil(okBtn._label:GetStringWidth()) + WN_BTN_TEXT_PAD), WN_BTN_H)
    end

    local versionLabel = version or ns.version or "?"
    frame._verText:SetText("v" .. versionLabel)

    local features = ParseFeatures(BodyText())
    local blocks = frame._blocks
    RenderFeatures(blocks, features)
    local probe = { frame._title, frame._verText }
    for i = 1, #features do
        probe[#probe + 1] = blocks.pool[i].title
        probe[#probe + 1] = blocks.pool[i].body
    end
    local contentW = Utils.MaxContentWidth(probe)
    frame:SetWidth(mmax(WN_MIN_W, mmin(WN_MAX_W, mceil(contentW) + WN_PAD_X * 2)))

    local titleH = frame._title:GetStringHeight()
    local verH = frame._verText:GetStringHeight()
    local bodyTopOffset = WN_PAD_TOP + titleH + WN_TITLE_GAP + verH + WN_BODY_GAP
    local scroll = frame._scroll
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", WN_PAD_X, -bodyTopOffset)
    scroll:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -WN_PAD_X, -bodyTopOffset)
    blocks:SetWidth(frame:GetWidth() - WN_PAD_X * 2)
    local bodyH = RenderFeatures(blocks, features)
    local boxH = mmin(bodyH, WN_BODY_MAX_H)
    scroll:SetHeight(boxH)
    scroll:SetVerticalScroll(0)
    local bar = frame._bar
    if bodyH > boxH then
        bar:Show()
        bar:UpdateThumb(bodyH, boxH)
    else
        bar:Hide()
    end

    local total = bodyTopOffset + boxH + 10 + 16
        + WN_BTN_GAP + WN_BTN_H + WN_PAD_BOTTOM
    frame:SetHeight(total)
    frame:Show()
end
