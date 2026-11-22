


local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns or select(2, ...).stale then return end

local Wizard = {}
ns.Wizard = Wizard
Wizard.FEATURES_PAGE = 2

local Utils = ns.Utils
local L = ns.L
local SafeAfter = Utils.SafeAfter

local CreateFrame   = CreateFrame
local UIParent      = UIParent
local InCombatLockdown = InCombatLockdown
local GetBindingKey = GetBindingKey

local GOLD       = ns.GOLD_COLOR

local WIZ_W, WIZ_H = 544, 436
local TUTORIAL_IMAGE_MAX_W = 516
local TUTORIAL_IMAGE_MAX_H = 240
local TOGGLE_ACTION = "EASYFIND_TOGGLE_FOCUS"
local MAP_ACTION    = "EASYFIND_MAP_FOCUS"

local PANEL_BG_ALPHA = 0.97
local TEXT_PRIM      = ns.TEXT_PRIMARY
local TEXT_BODY      = ns.TEXT_BODY
local TEXT_DIM       = ns.TEXT_DIM
local TUTORIAL_IMAGE_TINT = 1.0

local function TutorialTexCoord(contentW, contentH, canvasW, canvasH)
    return { 0, contentW / canvasW, 0, contentH / canvasH }
end



local DOT_FILLED = "Interface\\AddOns\\EasyFind\\textures\\FilterButtonCircle"


local GAUNTLET_CURSOR_TEX = 6116532
local GAUNTLET_CURSOR_TEXCOORD = { 0.0, 0.24, 0.0, 0.42 }

if ns.Caps and ns.Caps.classic then
    GAUNTLET_CURSOR_TEX = "Interface\\CURSOR\\Point"
    GAUNTLET_CURSOR_TEXCOORD = { 0, 1, 0, 1 }
end
local SEARCH_TUTORIAL_SLIDES = {
    {
        image = "Interface\\AddOns\\EasyFind\\Onboarding\\Images\\tutorial-search-gearstats-hires",
        caps = "journal",
        texCoord = TutorialTexCoord(908, 420, 1024, 512),
        w = 454, h = 210,
        text = L["TUT_SLIDE_SEARCH_INTRO"],

        hoverRings = {
            ["hl:altnum"] = { x = 428, y = 104, w = 42, h = 22 },
        },
    },
    {
        image = "Interface\\AddOns\\EasyFind\\Onboarding\\Images\\tutorial-search-pets-hires",
        caps = "pets",
        texCoord = TutorialTexCoord(908, 420, 1024, 512),
        w = 454, h = 210,
        text = L["TUT_SLIDE_ALT_NUMBERS"],

        overlay = {
            tex = GAUNTLET_CURSOR_TEX,
            texCoord = GAUNTLET_CURSOR_TEXCOORD,
            size = 30,
            ox = 300, oy = 140,
        },
    },
    {
        image = "Interface\\AddOns\\EasyFind\\Onboarding\\Images\\tutorial-search-rowmenu-hires",
        texCoord = TutorialTexCoord(908, 420, 1024, 512),
        w = 454, h = 210,
        text = L["TUT_SLIDE_PINNING"],

        overlay = {
            tex = GAUNTLET_CURSOR_TEX,
            texCoord = GAUNTLET_CURSOR_TEXCOORD,
            size = 30,
            ox = 272, oy = 112,
        },
    },
    {
        image = "Interface\\AddOns\\EasyFind\\Onboarding\\Images\\tutorial-search-shortkey-hires",
        texCoord = TutorialTexCoord(908, 420, 1024, 512),
        w = 454, h = 210,
        text = L["TUT_SLIDE_SHORTKEYS"],

        overlay = {
            tex = GAUNTLET_CURSOR_TEX,
            texCoord = GAUNTLET_CURSOR_TEXCOORD,
            size = 30,
            ox = 328, oy = 151,
        },
    },
    {
        image = "Interface\\AddOns\\EasyFind\\Onboarding\\Images\\tutorial-search-wowhead-hires",
        texCoord = TutorialTexCoord(908, 420, 1024, 512),
        w = 454, h = 210,
        text = L["TUT_SLIDE_WOWHEAD"],

        overlay = {
            tex = GAUNTLET_CURSOR_TEX,
            texCoord = GAUNTLET_CURSOR_TEXCOORD,
            size = 30,
            ox = 368, oy = 188,
        },
    },
    {
        image = "Interface\\AddOns\\EasyFind\\Onboarding\\Images\\tutorial-search-sendlink-hires",
        texCoord = TutorialTexCoord(908, 420, 1024, 512),
        w = 454, h = 210,
        text = L["TUT_SLIDE_SEND_LINK"],

        overlay = {
            tex = GAUNTLET_CURSOR_TEX,
            texCoord = GAUNTLET_CURSOR_TEXCOORD,
            size = 30,
            ox = 280, oy = 108,
        },
    },
    {
        image = "Interface\\AddOns\\EasyFind\\Onboarding\\Images\\tutorial-search-filters-hires",
        texCoord = TutorialTexCoord(908, 420, 1024, 512),
        w = 454, h = 210,
        text = L["TUT_SLIDE_FILTER_MENU"],

        overlay = {
            tex = GAUNTLET_CURSOR_TEX,
            texCoord = GAUNTLET_CURSOR_TEXCOORD,
            size = 34,
            ox = 362, oy = 12,
        },
    },
    {
        image = "Interface\\AddOns\\EasyFind\\Onboarding\\Images\\tutorial-search-quickfilters-hires",
        texCoord = TutorialTexCoord(908, 420, 1024, 512),
        w = 454, h = 210,
        text = L["TUT_SLIDE_AT_PREFIX"],
    },
    {
        image = "Interface\\AddOns\\EasyFind\\Onboarding\\Images\\tutorial-search-currency-hires",
        caps = "currencies",
        texCoord = TutorialTexCoord(908, 420, 1024, 512),
        w = 454, h = 210,
        text = L["TUT_SLIDE_CURRENCY_REP"],

        overlay = {
            tex = GAUNTLET_CURSOR_TEX,
            texCoord = GAUNTLET_CURSOR_TEXCOORD,
            size = 28,
            ox = 286, oy = 219,
        },
    },
    {
        image = "Interface\\AddOns\\EasyFind\\Onboarding\\Images\\tutorial-search-macros-hires",
        texCoord = TutorialTexCoord(908, 420, 1024, 512),
        w = 454, h = 210,
        text = L["TUT_SLIDE_MACROS"],

        overlay = {
            tex = GAUNTLET_CURSOR_TEX,
            texCoord = GAUNTLET_CURSOR_TEXCOORD,
            size = 30,
            ox = 285, oy = 180,
        },
    },
}
local USE_TUTORIAL_SLIDES = {
    {
        image = "Interface\\AddOns\\EasyFind\\Onboarding\\Images\\tutorial-use-gear-outfit-title-hires",
        caps = "outfits",
        texCoord = TutorialTexCoord(908, 420, 1024, 512),
        w = 454, h = 210,
        text = L["TUT_SLIDE_USE_GEAR_OUTFIT_TITLE"],
    },
    {
        image = "Interface\\AddOns\\EasyFind\\Onboarding\\Images\\tutorial-use-mounts-hires",
        caps = "mounts",
        texCoord = TutorialTexCoord(908, 420, 1024, 512),
        w = 454, h = 210,
        text = L["TUT_SLIDE_USE_MOUNTS"],

        overlay = {
            tex = GAUNTLET_CURSOR_TEX,
            texCoord = GAUNTLET_CURSOR_TEXCOORD,
            size = 30,
            ox = 375, oy = 92,
        },
    },
    {
        image = "Interface\\AddOns\\EasyFind\\Onboarding\\Images\\tutorial-use-macros-abilities-hires",
        texCoord = TutorialTexCoord(908, 420, 1024, 512),
        w = 454, h = 210,
        text = L["TUT_SLIDE_USE_MACROS_ABILITIES"],
    },
    {
        image = "Interface\\AddOns\\EasyFind\\Onboarding\\Images\\tutorial-use-toys-commands-hires",
        caps = "toys",
        texCoord = TutorialTexCoord(908, 420, 1024, 512),
        w = 454, h = 210,
        text = L["TUT_SLIDE_USE_TOYS_COMMANDS"],
    },
    {
        image = "Interface\\AddOns\\EasyFind\\Onboarding\\Images\\tutorial-search-settings-hires",
        texCoord = TutorialTexCoord(908, 420, 1024, 512),
        w = 454, h = 210,
        text = L["TUT_SLIDE_INLINE_SETTINGS"],
    },
}



local CARDS_PER_SLIDE = 6
local BUILT_IN_CARDS = {
    { title = L["UITREE_CALCULATOR"], icon = ns.CALCULATOR_ICON_TEX, blurb = L["EXT_CARD_CALCULATOR"] },
    { title = L["ICON_SEARCH_APP"], icon = ns.ICON_SEARCH_ICON_TEX, blurb = L["EXT_CARD_ICONSEARCH"], caps = "iconSearch" },
    { title = L["FILTER_SNIPPETS"], icon = ns.SNIPPET_ICON_TEX, blurb = L["EXT_CARD_SNIPPETS"] },
    { title = L["FILTER_CLIPBOARD"], icon = ns.CLIPBOARD_ICON_TEX, blurb = L["EXT_CARD_CLIPBOARD"] },
    { title = L["FILTER_QUICKLISTS"], icon = ns.QUICKLIST_ICON_TEX, blurb = L["EXT_CARD_QUICKLISTS"] },
}

local function ExtensionSlides()
    local slides = {}
    local function Paged(cards, intro)
        for i = 1, #cards, CARDS_PER_SLIDE do
            local page = {}
            for j = i, math.min(i + CARDS_PER_SLIDE - 1, #cards) do page[#page + 1] = cards[j] end
            slides[#slides + 1] = { cards = page, text = intro }
        end
    end
    local onCurseForge = {}
    for _, e in ipairs(ns.FirstPartyExtensions or {}) do
        if e.title and e.slug and ns.ExtensionRunsHere(e) then onCurseForge[#onCurseForge + 1] = e end
    end
    Paged(onCurseForge, L["TUT_EXT_INTRO"])
    local builtIn = {}
    for _, c in ipairs(BUILT_IN_CARDS) do
        if not (c.caps and ns.Caps and ns.Caps[c.caps] == false) then builtIn[#builtIn + 1] = c end
    end
    Paged(builtIn, L["TUT_EXT_BUILTIN_INTRO"])
    return slides
end
local APPS_TUTORIAL_SLIDES = ExtensionSlides()

local MAP_SEARCH_TUTORIAL_SLIDES = {
    {
        image = "Interface\\AddOns\\EasyFind\\Onboarding\\Images\\tutorial-map-intro-hires",
        texCoord = TutorialTexCoord(908, 420, 1024, 512),
        w = 454, h = 210,
        text = L["TUT_MAP_INTRO_DESC"],
        caps = "mapTabStrip",

        overlay = {
            tex = GAUNTLET_CURSOR_TEX,
            texCoord = GAUNTLET_CURSOR_TEXCOORD,
            size = 30,
            ox = 430, oy = 206,
        },
    },
    {
        image = "Interface\\AddOns\\EasyFind\\Onboarding\\Images\\tutorial-map-zones-hires",
        texCoord = TutorialTexCoord(908, 420, 1024, 512),
        w = 454, h = 210,
        text = L["TUT_MAP_TAB_DESC"],

        overlay = {
            tex = GAUNTLET_CURSOR_TEX,
            texCoord = GAUNTLET_CURSOR_TEXCOORD,
            size = 30,
            ox = 188, oy = 88,
        },
    },
    {
        image = "Interface\\AddOns\\EasyFind\\Onboarding\\Images\\tutorial-map-hover-hires",
        texCoord = TutorialTexCoord(908, 420, 1024, 512),
        w = 454, h = 210,
        text = L["TUT_MAP_HOVER_DESC"],

        overlay = {
            tex = GAUNTLET_CURSOR_TEX,
            texCoord = GAUNTLET_CURSOR_TEXCOORD,
            size = 30,
            ox = 158, oy = 146,
        },
    },
    {
        image = "Interface\\AddOns\\EasyFind\\Onboarding\\Images\\tutorial-map-rares-hires",
        caps = "retail",
        texCoord = TutorialTexCoord(908, 420, 1024, 512),
        w = 454, h = 210,
        text = L["TUT_MAP_RARES_DESC"],


        overlay = {
            tex = GAUNTLET_CURSOR_TEX,
            texCoord = GAUNTLET_CURSOR_TEXCOORD,
            size = 30,
            ox = 240, oy = 145,
        },
    },
    {
        image = "Interface\\AddOns\\EasyFind\\Onboarding\\Images\\tutorial-map-autotrack-hires",
        caps = "retail",
        texCoord = TutorialTexCoord(908, 420, 1024, 512),
        w = 454, h = 210,
        text = L["TUT_MAP_AUTOTRACK_DESC"],

        overlay = {
            tex = GAUNTLET_CURSOR_TEX,
            texCoord = GAUNTLET_CURSOR_TEXCOORD,
            size = 30,
            ox = 195, oy = 176,
        },
    },
    {
        image = "Interface\\AddOns\\EasyFind\\Onboarding\\Images\\tutorial-map-gps-hires",
        texCoord = TutorialTexCoord(908, 420, 1024, 512),
        w = 454, h = 210,
        text = L["TUT_MAP_GPS_DESC"],
    },
}

local function ApplyInter(fs, weight, sizeOverride, flags)
    if ns.RegisterAddonFont then
        ns.RegisterAddonFont(fs, weight, sizeOverride, flags)
    end


    ns.ShadeText(fs)
end

local frame
local pages = {}
local pageIdx = 1
local dots = {}
local backBtn, nextBtn
local featureTiles = {}
local RepaintFeatureTiles


local invertedPills = {}

local function RepaintInvertedPills()
    for i = 1, #invertedPills do
        invertedPills[i]()
    end
end



local themeReplicas = {}

local function RepaintReplicas()
    for i = 1, #themeReplicas do
        themeReplicas[i].RestyleTheme()
    end
end



local RepaintFooter




local themedTexts = {}

local function RegisterThemedText(fs, colorTable)
    fs._efOwnColor = true
    themedTexts[#themedTexts + 1] = { fs = fs, color = colorTable }
end

local function RepaintThemedTexts()
    for i = 1, #themedTexts do
        local entry = themedTexts[i]
        entry.fs:SetTextColor(Utils.RGB(entry.color, 1))
    end
end





local function PillFill(f)
    local pal = ns.ACTIVE_UI_PALETTE
    local top = pal and not pal.light and pal.windowFillTop
    if top then
        local s = f > 0 and 0.85 or f < 0 and 0.55 or 0.70
        return top[1] * s, top[2] * s, top[3] * s
    end
    local fill = f > 0 and ns.BTN_FILL_HOVER or f < 0 and ns.BTN_FILL_PRESSED or ns.BTN_FILL_NORMAL
    return fill[1], fill[2], fill[3]
end



local function KbPillFill(hover)
    local pal = ns.ACTIVE_UI_PALETTE
    local top = pal and not pal.light and pal.windowFillTop
    if not top then return PillFill(hover and 1 or 0) end
    local s, lift = hover and 1.5 or 1.3, hover and 0.08 or 0.05
    return math.min(1, top[1] * s + lift), math.min(1, top[2] * s + lift), math.min(1, top[3] * s + lift)
end





local function ThemeBandFill()
    local pal = ns.ACTIVE_UI_PALETTE
    local top = pal and not pal.light and pal.windowFillTop
    if top then
        return top[1] * 0.45, top[2] * 0.45, top[3] * 0.45
    end
    local card = ns.SECTION_TABLE_FILL
    return card[1], card[2], card[3]
end

local function MakeButton(parent, text, variant, w)
    local b = CreateFrame("Button", nil, parent)
    local h = (variant == "rounded") and 20 or 18
    b:SetSize(w or 96, h)

    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER")
    fs:SetText(text)
    ApplyInter(fs, "semibold", 10)
    b._label = fs

    if variant == "rounded" then
        ns.CreateRoundedRectBorder(b)
        ns.SetRoundedRectBarHeight(b, 8)
        ns.SetRoundedRectBorderBgAlpha(b, 1)

        ns.SetRoundedRectBorderEdgeShown(b, false)



        fs._efOwnColor = true
        local function paintPill(hoverNudge)
            local f = hoverNudge or 0
            local pal = ns.ACTIVE_UI_PALETTE

            if ns.ClassicLook() and ns.PaintRedButton then
                ns.SetRoundedRectBorderShown(b, false)
                ns.PaintRedButton(b, f > 0 and ns.BTN_FILL_HOVER or f < 0 and ns.BTN_FILL_PRESSED or ns.BTN_FILL_NORMAL)
                return
            elseif b._efRedOn and ns.DropRedButton then
                ns.DropRedButton(b)
            end
            if pal and pal.light then
                local theme = ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
                local leaf = (theme and theme.leafColor) or TEXT_PRIM
                ns.SetRoundedRectFill(b,
                    leaf[1] + (1 - leaf[1]) * f,
                    leaf[2] + (1 - leaf[2]) * f,
                    leaf[3] + (1 - leaf[3]) * f, 1, true)
                local windowFill = ns.SEARCH_WINDOW_FILL_COLOR
                fs:SetTextColor(windowFill[1], windowFill[2], windowFill[3], 1)
            else
                local pr, pg, pb = PillFill(f)
                ns.SetRoundedRectFill(b, pr, pg, pb, 1, true)
                fs:SetTextColor(Utils.RGB(TEXT_PRIM, 1))
            end
        end
        paintPill(0)
        invertedPills[#invertedPills + 1] = function() paintPill(0) end
        b:SetScript("OnEnter",     function() paintPill(0.15) end)
        b:SetScript("OnLeave",     function() paintPill(0) end)
        b:SetScript("OnMouseDown", function() paintPill(-0.10) end)
        b:SetScript("OnMouseUp",   function(self)
            paintPill(self:IsMouseOver() and 0.15 or 0)
        end)
        return b
    end

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    b._bg = bg

    local function setVisual(state)
        if variant == "ghost" then
            bg:SetColorTexture(0, 0, 0, 0)

            if state == "hover" or state == "pressed" then
                fs:SetTextColor(Utils.RGB(TEXT_PRIM, 1))
            else
                fs:SetTextColor(Utils.RGB(TEXT_DIM, 1))
            end
            return
        end
        if state == "pressed" then
            bg:SetColorTexture(0.10, 0.10, 0.11, 1)
        elseif state == "hover" then
            bg:SetColorTexture(0.18, 0.18, 0.20, 1)
        else
            bg:SetColorTexture(0.13, 0.13, 0.15, 1)
        end
        if state == "hover" or state == "pressed" then
            fs:SetTextColor(Utils.RGB(TEXT_PRIM, 1))
        else
            fs:SetTextColor(Utils.RGB(TEXT_DIM, 1))
        end
    end
    setVisual("normal")
    if variant == "ghost" then
        fs._efOwnColor = true
        invertedPills[#invertedPills + 1] = function() setVisual("normal") end
    end
    b:SetScript("OnEnter",     function() setVisual("hover") end)
    b:SetScript("OnLeave",     function() setVisual("normal") end)
    b:SetScript("OnMouseDown", function() setVisual("pressed") end)
    b:SetScript("OnMouseUp",   function(self)
        if self:IsMouseOver() then setVisual("hover") else setVisual("normal") end
    end)
    return b
end




local function PaintDots()
    local pal = ns.ACTIVE_UI_PALETTE
    local themed = pal and (pal.light or pal.windowFillTop)
    for idx, d in ipairs(dots) do
        if idx == pageIdx then
            if themed then
                local r, g, b = ns.ThemeSwatchColor(pal)
                if not pal.light then



                    r = math.min(1, r * 1.5 + 0.10)
                    g = math.min(1, g * 1.5 + 0.10)
                    b = math.min(1, b * 1.5 + 0.10)
                end
                d:SetVertexColor(r, g, b)
            else



                d:SetVertexColor(Utils.RGB(TEXT_PRIM, 1))
            end
            d:SetSize(11, 11)
        else
            d:SetVertexColor(0.32, 0.32, 0.36, 1)
            d:SetSize(9, 9)
        end
    end
end

local function ShowPage(i)
    if i < 1 or i > #pages then return end
    pageIdx = i
    for idx, p in ipairs(pages) do
        p:SetShown(idx == i)
    end
    PaintDots()
    RepaintFeatureTiles()
    backBtn:SetShown(i > 1)


    nextBtn:Show()
    if i == #pages then
        nextBtn._label:SetText(L["TUT_BTN_OPEN_BAR"])
    elseif i == 1 then
        nextBtn._label:SetText(L["TUT_BTN_GET_STARTED"])
    else
        nextBtn._label:SetText(L["TUT_BTN_CONTINUE"])
    end
    if pages[i].OnEnter then pages[i].OnEnter() end
end

local function FinishWizard(openBar)
    if not frame then return end
    EasyFind.db.tutorialDone = true
    EasyFind.db.setupComplete = true
    if ns.version then
        EasyFind.db.lastSeenVersion = ns.version
        if ns.version == ns.REVAMPED_TUTORIAL_VERSION then
            EasyFind.db.revampedTutorialVersion = ns.REVAMPED_TUTORIAL_VERSION
        end
    end
    frame:Hide()
    if openBar and ns.Search and ns.Search.Show then
        SafeAfter(0.05, function() ns.Search:Show(true) end)
    end
end

local function MakePage(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints(parent)
    p:Hide()
    return p
end

local function HeaderText(parent, text, font, maxWidth)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormalHuge")
    ApplyInter(fs, "semibold")
    fs:SetText(text)
    fs:SetTextColor(Utils.RGB(TEXT_PRIM, 1))
    RegisterThemedText(fs, TEXT_PRIM)
    if maxWidth and maxWidth > 0 then
        ns.AttachEllipsisToFontString(fs, text, maxWidth)
    end
    return fs
end





local HEADER_MAX_W = WIZ_W - 140




local WELCOME_MAX_W = WIZ_W - 48

local function BodyText(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ApplyInter(fs, "regular")
    fs:SetText(text)
    fs:SetTextColor(Utils.RGB(TEXT_BODY, 1))
    RegisterThemedText(fs, TEXT_BODY)
    fs:SetJustifyH("CENTER")
    fs:SetJustifyV("TOP")
    fs:SetSpacing(4)
    return fs
end

local function FitSize(srcW, srcH, maxW, maxH)
    if not srcW or not srcH or srcW <= 0 or srcH <= 0 then
        return maxW, maxH
    end
    local scale = math.min(maxW / srcW, maxH / srcH)
    return srcW * scale, srcH * scale
end

local function SetTutorialImage(texture, image, texCoord)
    texture:SetTexture(image)
    if texCoord then
        texture:SetTexCoord(unpack(texCoord))
    else
        texture:SetTexCoord(0, 1, 0, 1)
    end
    texture:SetVertexColor(TUTORIAL_IMAGE_TINT, TUTORIAL_IMAGE_TINT, TUTORIAL_IMAGE_TINT, 1)
end

local function BuildPage1(parent)
    local p = MakePage(parent)

    local logo = p:CreateTexture(nil, "OVERLAY")
    logo:SetSize(108, 108)
    logo:SetTexture("Interface\\AddOns\\EasyFind\\textures\\Spyglass")
    logo:SetPoint("TOP", p, "TOP", 0, -40)

    local version = ns.version or (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("EasyFind", "Version")) or "2.0.0"
    local title = HeaderText(p, L["TUT_WELCOME_TITLE"]:format(version), nil, WELCOME_MAX_W)
    title:SetPoint("TOP", logo, "BOTTOM", 0, -22)
    do
        local path, sz, fl = title:GetFont()
        if sz then title:SetFont(path, sz * 1.5, fl or "") end
    end

    local sub = BodyText(p, L["TUT_WELCOME_SUBTITLE"])
    sub:SetPoint("TOP", title, "BOTTOM", 0, -16)
    sub:SetWidth(WIZ_W - 120)
    sub:SetTextColor(Utils.RGB(TEXT_DIM, 1))

    themedTexts[#themedTexts].color = TEXT_DIM

    return p
end

local function FeatureTile(parent, atlas, file, coords, title, desc, onClick)

    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(222, 112)

    local tile = CreateFrame("Button", nil, holder)
    tile:SetSize(222, 112)
    tile:SetPoint("CENTER", holder, "CENTER", 0, 0)
    tile:RegisterForClicks("LeftButtonUp")

    ns.CreateRoundedRectBorder(tile)
    ns.SetRoundedRectBarHeight(tile, 10)
    ns.SetRoundedRectBorderBgAlpha(tile, 0.95)
    local br0, bg0, bb0 = ThemeBandFill()
    ns.SetRoundedRectFill(tile, br0, bg0, bb0, 1, true)
    ns.SetRoundedRectBorderEdgeShown(tile, false)

    tile._efNoAutoRetint = true

    local icon = tile:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("TOPLEFT", tile, "TOPLEFT", 14, -14)
    if atlas then
        icon:SetAtlas(atlas)
    elseif file then
        icon:SetTexture(file)
        if coords then icon:SetTexCoord(unpack(coords)) end
    end

    local fs = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -2)
    fs:SetPoint("RIGHT", tile, "RIGHT", -12, 0)
    fs:SetJustifyH("LEFT")
    ApplyInter(fs, "semibold")
    fs._efOwnColor = true




    ns.MakeEllipsisLabel(fs, title)

    local body = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    body:SetText(desc)
    body:SetTextColor(Utils.RGB(TEXT_BODY, 1))
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetSpacing(2)
    body:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -6)
    body:SetPoint("RIGHT", tile, "RIGHT", -12, 0)
    ApplyInter(body, "regular")
    body._efOwnColor = true


    local hoverGlow = tile:CreateTexture(nil, "ARTWORK", nil, -8)
    hoverGlow:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hoverGlow:SetBlendMode("ADD")
    hoverGlow:SetPoint("TOPLEFT", tile, "TOPLEFT", 4, -4)
    hoverGlow:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -4, 4)
    hoverGlow:SetAlpha(0.5)
    hoverGlow:Hide()

    if onClick then
        tile:SetScript("OnEnter", function(self)
            self:SetScale(1.04)
            hoverGlow:SetShown(ns.ClassicLook())


            local hr, hg, hb = ThemeBandFill()
            ns.SetRoundedRectBorderFillColor(self,
                hr + (1 - hr) * 0.12, hg + (1 - hg) * 0.12, hb + (1 - hb) * 0.12, 1)
        end)
        tile:SetScript("OnLeave", function(self)
            self:SetScale(1.00)
            hoverGlow:Hide()
            local lr, lg, lb = ThemeBandFill()
            ns.SetRoundedRectBorderFillColor(self, lr, lg, lb, 1)
        end)
        tile:SetScript("OnClick", onClick)
    end

    tile.icon = icon
    holder.tile = tile
    featureTiles[#featureTiles + 1] = { tile = tile, title = fs, body = body }
    return holder
end




function RepaintFeatureTiles()
    local pal = ns.ACTIVE_UI_PALETTE
    local light = pal and pal.light
    local br, bg, bb = ThemeBandFill()
    for i = 1, #featureTiles do
        local entry = featureTiles[i]

        entry.tile._efClassicSurface = true
        entry.tile._efClassicStyle = "thin"
        if ns.ApplySkin then ns.ApplySkin(entry.tile) end
        ns.SetRoundedRectBorderFillColor(entry.tile, br, bg, bb, 1)
        if light then


            entry.title:SetTextColor(1, 1, 1, 1)
            entry.body:SetTextColor(1, 1, 1, 1)
        else
            entry.title:SetTextColor(Utils.RGB(TEXT_PRIM, 1))
            entry.body:SetTextColor(Utils.RGB(TEXT_BODY, 1))
        end
    end
end




local CARD_W, CARD_H, CARD_GAP = 156, 132, 10
local CARD_CHECK = "Interface\\Buttons\\UI-CheckBox-Check"

local function ExtensionCard(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(CARD_W, CARD_H)
    local card = CreateFrame("Button", nil, holder)
    card:SetSize(CARD_W, CARD_H)
    card:SetPoint("CENTER", holder, "CENTER", 0, 0)
    card:RegisterForClicks("LeftButtonUp")
    ns.CreateRoundedRectBorder(card)
    ns.SetRoundedRectBarHeight(card, 10)
    ns.SetRoundedRectBorderEdgeShown(card, false)
    card._efNoAutoRetint = true
    card._efClassicSurface = true
    card._efClassicStyle = "thin"

    local well = CreateFrame("Frame", nil, card)
    well:SetSize(38, 38)
    well:SetPoint("TOP", card, "TOP", 0, -10)
    ns.CreateRoundedRectBorder(well)
    ns.SetRoundedRectBorderEdgeShown(well, false)
    well._efNoAutoRetint = true
    local icon = well:CreateTexture(nil, "OVERLAY")
    icon:SetSize(24, 24)
    icon:SetPoint("CENTER")

    local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", well, "BOTTOM", 0, -6)
    title:SetPoint("LEFT", card, "LEFT", 8, 0)
    title:SetPoint("RIGHT", card, "RIGHT", -8, 0)
    title:SetJustifyH("CENTER")
    ApplyInter(title, "semibold", 12)
    title._efOwnColor = true

    local blurb = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    blurb:SetPoint("TOP", title, "BOTTOM", 0, -3)
    blurb:SetPoint("LEFT", card, "LEFT", 10, 0)
    blurb:SetPoint("RIGHT", card, "RIGHT", -10, 0)
    blurb:SetJustifyH("CENTER")
    blurb:SetJustifyV("TOP")
    blurb:SetSpacing(1)
    blurb:SetMaxLines(3)
    ApplyInter(blurb, "regular", 10)
    blurb._efOwnColor = true

    local pill = CreateFrame("Frame", nil, card)
    pill:SetHeight(16)
    pill:SetPoint("BOTTOM", card, "BOTTOM", 0, 8)
    ns.CreateRoundedRectBorder(pill)
    ns.SetRoundedRectBorderEdgeShown(pill, false)
    pill._efNoAutoRetint = true
    local check = pill:CreateTexture(nil, "OVERLAY")
    check:SetTexture(CARD_CHECK)
    check:SetSize(14, 14)
    local pillText = pill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ApplyInter(pillText, "semibold", 10)
    pillText._efOwnColor = true

    local hoverGlow = card:CreateTexture(nil, "ARTWORK", nil, -8)
    hoverGlow:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hoverGlow:SetBlendMode("ADD")
    hoverGlow:SetPoint("TOPLEFT", card, "TOPLEFT", 4, -4)
    hoverGlow:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -4, 4)
    hoverGlow:SetAlpha(0.5)
    hoverGlow:Hide()

    local function Fill(r, g, b, lift)
        ns.SetRoundedRectBorderFillColor(card, r + (1 - r) * lift, g + (1 - g) * lift, b + (1 - b) * lift, 1)
    end

    card:SetScript("OnEnter", function(self)
        if not self.slug then return end
        self:SetScale(1.04)
        hoverGlow:SetShown(ns.ClassicLook())
        local r, g, b = ThemeBandFill()
        Fill(r, g, b, 0.12)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["TUT_EXT_LINK_TT"], 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function(self)
        if not self.slug then return end
        self:SetScale(1.00)
        hoverGlow:Hide()
        local r, g, b = ThemeBandFill()
        Fill(r, g, b, 0)
        GameTooltip:Hide()
    end)
    card:SetScript("OnClick", function(self)
        if self.slug then ns.ShowExtensionPage(self.slug) end
    end)


    function holder:Set(e)
        card:SetScale(1.00)
        hoverGlow:Hide()
        local light = ns.ACTIVE_UI_PALETTE and ns.ACTIVE_UI_PALETTE.light
        if ns.ApplySkin then ns.ApplySkin(card) end
        local r, g, b = ThemeBandFill()
        Fill(r, g, b, 0)
        ns.SetRoundedRectBorderFillColor(well, r * 0.6, g * 0.6, b * 0.6, 1)
        ns.SetRoundedRectBorderFillColor(pill, r * 0.6, g * 0.6, b * 0.6, 1)
        icon:SetTexture(e.icon)
        ns.PaintAppGlyph(icon)
        title:SetText(e.title)
        blurb:SetText(e.blurb)
        if light then
            title:SetTextColor(1, 1, 1, 1)
            blurb:SetTextColor(1, 1, 1, 1)
        else
            title:SetTextColor(Utils.RGB(TEXT_PRIM, 1))
            blurb:SetTextColor(Utils.RGB(TEXT_BODY, 1))
        end

        local have = e.addon and ns.ExtensionInstalled(e.addon)
        card.slug = (e.addon and not have) and e.slug or nil
        check:ClearAllPoints()
        pillText:ClearAllPoints()
        if have then
            check:Show()
            check:SetPoint("LEFT", pill, "LEFT", 5, 0)
            pillText:SetPoint("LEFT", check, "RIGHT", 1, 0)
            pillText:SetText(L["EXT_INSTALLED"])
            pillText:SetTextColor(Utils.RGB(ns.COPIED_COLOR, 1))
            pill:SetWidth(pillText:GetStringWidth() + 28)
        else
            check:Hide()
            pillText:SetPoint("CENTER", pill, "CENTER", 0, 0)
            if e.addon then
                pillText:SetText(L["TUT_EXT_GET"])
                pillText:SetTextColor(Utils.RGB(ns.LINK_COLOR or { 0.44, 0.84, 1.0 }, 1))
            else
                pillText:SetText(L["TUT_EXT_BUILTIN"])
                pillText:SetTextColor(Utils.RGB(TEXT_DIM, 1))
            end
            pill:SetWidth(pillText:GetStringWidth() + 18)
        end
        self:Show()
    end
    return holder
end


local function ExtensionCardGrid(parent)
    local grid = CreateFrame("Frame", nil, parent)
    grid:SetSize(CARD_W * 3 + CARD_GAP * 2, CARD_H * 2 + CARD_GAP)
    local slots = {}
    for i = 1, 6 do
        local c = ExtensionCard(grid)
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        c:SetPoint("TOPLEFT", grid, "TOPLEFT", col * (CARD_W + CARD_GAP), -row * (CARD_H + CARD_GAP))
        slots[i] = c
    end
    function grid:Fill(cards)
        for i = 1, #slots do
            if cards[i] then slots[i]:Set(cards[i]) else slots[i]:Hide() end
        end
    end
    return grid
end






local MAP_TAB_TILE_H = 44
local FOREVER_TABS = ns.Caps and ns.Caps.forever
local function BuildMapSideTabReplica(tile, anchor)
    local silo = tile:CreateTexture(nil, "BACKGROUND")
    silo:SetAtlas(FOREVER_TABS and "QuestLog-tab-side" or "common-sidetab", true)
    local nw, nh = silo:GetSize()
    local scale = (nh and nh > 0) and (MAP_TAB_TILE_H / nh) or 1
    silo:SetSize((nw or 34) * scale, (nh or MAP_TAB_TILE_H) * scale)
    silo:SetPoint("CENTER", anchor, "CENTER", 0, 0)

    local mag = tile:CreateTexture(nil, "ARTWORK")
    mag:SetTexture(ns.GPS_ICON_TEX)
    mag:SetTexCoord(0, 1, 0, 1)
    local magSize = MAP_TAB_TILE_H * 22 / 55
    mag:SetSize(magSize, magSize)
    mag:SetPoint("CENTER", silo, "CENTER", (FOREVER_TABS and 0 or -2) * scale, 0)
    mag:SetVertexColor(Utils.RGB(GOLD))




    local glow = tile:CreateTexture(nil, "OVERLAY")
    glow:SetAtlas(FOREVER_TABS and "QuestLog-Tab-side-Glow-Select" or "common-sidetab-selected", true)
    local gw, gh = glow:GetSize()
    glow:SetSize((gw or 44) * scale, (gh or 55) * scale)
    glow:SetPoint("CENTER", silo, "CENTER", 0, 0)
end



local function BuildMapSideToggleReplica(tile, anchor)
    local size = MAP_TAB_TILE_H * 0.8
    local face = tile:CreateTexture(nil, "BACKGROUND")
    face:SetTexture("Interface\\Buttons\\UI-SquareButton-Up")
    face:SetTexCoord(2 / 32, 29 / 32, 3 / 32, 29 / 32)
    face:SetSize(size, size)
    face:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    local pin = tile:CreateTexture(nil, "ARTWORK")
    pin:SetTexture(ns.GPS_ICON_TEX)
    pin:SetSize(size * 0.55, size * 0.55)
    pin:SetPoint("CENTER", face, "CENTER", 0, 0)
    pin:SetVertexColor(Utils.RGB(GOLD))
end

local function BuildSearchBarReplica(parent, w, h)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(w, h)
    ns.CreateRoundedRectBorder(bar)
    bar._efForeverSurface = true
    bar._efClassicSurface = true
    ns.SetRoundedRectBarHeight(bar, h)



    local iconSz = h * ns.SEARCHBAR_FILL * ns.SEARCHBAR_ICON_SCALE
    local icon = bar:CreateTexture(nil, "OVERLAY")
    icon:SetSize(iconSz, iconSz)
    icon:SetPoint("CENTER", bar, "LEFT", h / 2, 0)
    icon:SetTexture(ns.SEARCH_ICON_TEX)



    local arrow = bar:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(11, 11)
    arrow:SetPoint("CENTER", bar, "RIGHT", -h / 2, 0)
    arrow:SetTexture(ns.FILTER_ARROW_TEX)



    bar.RestyleTheme = function()
        ns.ApplyThemeFill(bar)
        ns.SetRoundedRectBorderBgAlpha(bar, ns.GetSearchWindowAlpha())
        ns.SetRoundedRectRingShown(bar, EasyFind.db and EasyFind.db.windowBorder ~= false)
        local theme = ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
        local glyph = theme and theme.chromeGlyph
        if glyph then
            icon:SetVertexColor(glyph[1], glyph[2], glyph[3], 1)
            arrow:SetBlendMode(ns.ChromeGlyphBlend(theme))
            arrow:SetVertexColor(glyph[1], glyph[2], glyph[3], 1)
        end
    end
    bar.RestyleTheme()
    themeReplicas[#themeReplicas + 1] = bar
    return bar
end

local function BuildPage2(parent)
    local p = MakePage(parent)

    local grid = CreateFrame("Frame", nil, p)
    grid:SetAllPoints(p)

    local title = HeaderText(grid, L["TUT_FEATURES_TITLE"], "GameFontNormalLarge", HEADER_MAX_W)
    title:SetPoint("TOP", grid, "TOP", 0, -28)

    local sub = BodyText(grid, L["TUT_FEATURES_SUBTITLE"])
    sub:SetPoint("TOP", title, "BOTTOM", 0, -6)

    local detailViews = {}



    local function SetFooterNavShown(shown)
        backBtn:SetShown(shown and pageIdx > 1)
        nextBtn:SetShown(shown)
        for i = 1, #dots do dots[i]:SetShown(shown) end
    end

    local function ShowGrid()
        grid:Show()
        for i = 1, #detailViews do detailViews[i]:Hide() end
        SetFooterNavShown(true)
    end

    local function ShowDetail(d)
        grid:Hide()
        for i = 1, #detailViews do detailViews[i]:Hide() end
        d:Show()
        SetFooterNavShown(false)
    end



    local actionsDeck
    local function GoToActionsDeck()
        if actionsDeck then ShowDetail(actionsDeck) end
    end

    local function CreateCarouselDetailView(headerText, slides)

        local Caps = ns.Caps
        if Caps then
            local kept = {}
            for i = 1, #slides do
                local need = slides[i].caps
                if not (need and Caps[need] == false) then kept[#kept + 1] = slides[i] end
            end
            slides = kept
        end
        local d = CreateFrame("Frame", nil, p)
        d:SetAllPoints(p)
        d:Hide()

        local back = MakeButton(d, L["TUT_BTN_BACK_ARROW"], "ghost", 52)
        back:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -10)
        back:SetScript("OnClick", ShowGrid)

        local h = HeaderText(d, headerText, "GameFontNormalLarge", HEADER_MAX_W)
        h:SetPoint("TOP", d, "TOP", 0, -28)

        local image = d:CreateTexture(nil, "ARTWORK")
        image:SetPoint("TOP", h, "BOTTOM", 0, -10)

        local overlayTex = d:CreateTexture(nil, "OVERLAY")
        overlayTex:Hide()



        local hoverRingTex = d:CreateTexture(nil, "OVERLAY")
        hoverRingTex:SetTexture("Interface\\AddOns\\EasyFind\\Onboarding\\Images\\tutorial-ring")
        hoverRingTex:Hide()

        local liveDemo, cardGrid
        for _, s in ipairs(slides) do
            if s.live == "searchbar" then
                liveDemo = BuildSearchBarReplica(d, s.w, s.h)
                liveDemo:SetPoint("TOP", h, "BOTTOM", 0, -48)
                liveDemo:Hide()
                break
            end
        end




        local SLIDE_FLOW_WIDTH = WIZ_W - 104
        local linkDispatch = {
            ["options:aliases"] = function()
                FinishWizard(false)
                if ns.RequestOptionsPanel() and ns.Options and ns.Options.OpenAtAliases then
                    ns.Options:OpenAtAliases()
                end
            end,
            ["wizard:actions"] = function()
                GoToActionsDeck()
            end,
        }
        local slideFlow

        local controls = CreateFrame("Frame", nil, d)
        controls:SetSize(148, 18)


        controls:SetPoint("CENTER", frame, "BOTTOM", 0, 20)
        controls:SetFrameLevel(frame:GetFrameLevel() + 50)

        local prev = MakeButton(controls, "<", "ghost", 26)
        prev:SetPoint("LEFT", controls, "LEFT", 0, 0)

        local next = MakeButton(controls, ">", "ghost", 26)
        next:SetPoint("RIGHT", controls, "RIGHT", 0, 0)

        local counter = controls:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        counter:SetPoint("CENTER", controls, "CENTER", 0, 0)
        counter:SetTextColor(Utils.RGB(TEXT_DIM, 1))
        ApplyInter(counter, "regular", 10)

        local idx = 1
        local function ShowSlide(newIdx)
            local count = #slides
            if count == 0 then return end
            if newIdx < 1 then newIdx = count end
            if newIdx > count then newIdx = 1 end
            idx = newIdx

            local slide = slides[idx]


            h:SetText(slide.title or headerText)
            overlayTex:Hide()
            hoverRingTex:Hide()
            if slideFlow then
                slideFlow:Hide()
                slideFlow:SetParent(nil)
                slideFlow = nil
            end
            local dispatch = linkDispatch
            if slide.hoverRings then
                dispatch = {}
                for id, fn in pairs(linkDispatch) do dispatch[id] = fn end
                for id, ring in pairs(slide.hoverRings) do
                    dispatch[id] = {
                        onEnter = function()
                            hoverRingTex:ClearAllPoints()
                            hoverRingTex:SetPoint("TOPLEFT", image, "TOPLEFT", ring.x, -ring.y)
                            hoverRingTex:SetSize(ring.w, ring.h)
                            hoverRingTex:Show()
                        end,
                        onLeave = function() hoverRingTex:Hide() end,
                    }
                end
            end
            slideFlow = ns.BuildFlowText(d, slide.text or "", {
                width = SLIDE_FLOW_WIDTH,
                font = "GameFontHighlightSmall",
                linkDispatch = dispatch,
                textColor = TEXT_BODY,
                interWeight = "regular",
                interSize = 11,
            })
            slideFlow:ClearAllPoints()
            if cardGrid then cardGrid:Hide() end
            if slide.cards then
                image:Hide()
                if liveDemo then liveDemo:Hide() end
                slideFlow:SetPoint("TOP", h, "BOTTOM", 0, -10)
                cardGrid = cardGrid or ExtensionCardGrid(d)
                cardGrid:ClearAllPoints()
                cardGrid:SetPoint("TOP", slideFlow, "BOTTOM", 0, -12)
                cardGrid:Fill(slide.cards)
                cardGrid:Show()
            elseif slide.live and liveDemo then
                image:Hide()
                liveDemo:Show()
                slideFlow:SetPoint("TOP", liveDemo, "BOTTOM", 0, -16)
            else
                if liveDemo then liveDemo:Hide() end
                image:Show()
                SetTutorialImage(image, slide.image, slide.texCoord)
                local w, hgt = FitSize(slide.w, slide.h, TUTORIAL_IMAGE_MAX_W, TUTORIAL_IMAGE_MAX_H)
                image:SetSize(w, hgt)
                slideFlow:SetPoint("TOP", image, "BOTTOM", 0, -8)
                local ov = slide.overlay
                if ov then
                    overlayTex:SetTexture(ov.tex)
                    overlayTex:SetTexCoord(unpack(ov.texCoord or { 0, 1, 0, 1 }))
                    overlayTex:SetSize(ov.size or 28, ov.size or 28)
                    overlayTex:SetRotation(ov.rotation or 0)
                    overlayTex:ClearAllPoints()
                    overlayTex:SetPoint("TOPLEFT", image, "TOPLEFT", ov.ox or 0, -(ov.oy or 0))
                    overlayTex:Show()
                end
            end
            counter:SetText(idx .. " / " .. count)
        end

        prev:SetScript("OnClick", function() ShowSlide(idx - 1) end)
        next:SetScript("OnClick", function() ShowSlide(idx + 1) end)
        d.OnEnter = function() ShowSlide(idx) end
        ShowSlide(1)

        detailViews[#detailViews + 1] = d
        return d
    end

    local classic = ns.Caps and ns.Caps.classic
    local d1 = CreateCarouselDetailView(L["TUT_FEATURE_SEARCH"], SEARCH_TUTORIAL_SLIDES)
    local d3 = CreateCarouselDetailView(L["TUT_FEATURE_ACTIONS"], USE_TUTORIAL_SLIDES)
    actionsDeck = d3
    local d4 = CreateCarouselDetailView(L["TUT_FEATURE_APPS"], APPS_TUTORIAL_SLIDES)

    local t1 = FeatureTile(grid, nil, "Interface\\AddOns\\EasyFind\\textures\\Spyglass", nil,
        L["TUT_FEATURE_SEARCH"],
        classic and L["TUT_FEATURE_SEARCH_DESC_CLASSIC"] or L["TUT_FEATURE_SEARCH_DESC"],
        function() ShowDetail(d1) end)
    t1:SetPoint("TOPLEFT", grid, "TOPLEFT", 38, -96)

    local d2 = CreateCarouselDetailView(L["TUT_FEATURE_MAP"], MAP_SEARCH_TUTORIAL_SLIDES)
    local t2 = FeatureTile(grid, nil, nil, nil,
        L["TUT_FEATURE_MAP"],
        classic and L["TUT_FEATURE_MAP_DESC_CLASSIC"] or L["TUT_FEATURE_MAP_DESC"],
        function() ShowDetail(d2) end)
    if classic then
        BuildMapSideToggleReplica(t2.tile, t2.tile.icon)
    else
        BuildMapSideTabReplica(t2.tile, t2.tile.icon)
    end
    t2:SetPoint("TOPRIGHT", grid, "TOPRIGHT", -38, -96)


    local t3 = FeatureTile(grid, not classic and "UI-HUD-MicroMenu-SpellbookAbilities-Up" or nil,
        classic and "Interface\\Spellbook\\Spellbook-Icon" or nil, nil,
        L["TUT_FEATURE_ACTIONS"],
        L["TUT_FEATURE_ACTIONS_DESC"],
        function() ShowDetail(d3) end)
    t3:SetPoint("TOPLEFT", grid, "TOPLEFT", 38, -222)

    local t4 = FeatureTile(grid, nil, nil, nil,
        L["TUT_FEATURE_APPS"],
        L["TUT_FEATURE_APPS_DESC"],
        function() ShowDetail(d4) end)



    local waffle = ns.CreateGridGlyph and ns.CreateGridGlyph(t4.tile, 30)
    if waffle then
        waffle:SetPoint("CENTER", t4.tile.icon, "CENTER", 0, 0)
    end
    t4:SetPoint("TOPRIGHT", grid, "TOPRIGHT", -38, -222)

    p.OnEnter = ShowGrid

    return p
end

local kbWidgets = {}
local kbWaitingFor

local function RefreshKbWidget(widget)
    local cur = GetBindingKey(widget.action) or EasyFind:GetAccountKeybind(widget.action)
    widget.btn._label:SetText(cur or _G["NOT_BOUND"] or "Not Bound")
end

local function StopKeybindCapture()
    if not kbWaitingFor then return end
    local widget = kbWaitingFor
    kbWaitingFor = nil
    Utils.DisarmBindingCapture(widget.btn)
    RefreshKbWidget(widget)
end

local function CreateKbWidget(parent, action, label)
    local w = { action = action }

    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    lbl:SetText(label)
    lbl:SetTextColor(Utils.RGB(TEXT_DIM, 1))
    ApplyInter(lbl, "regular")
    w.label = lbl

    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(208, 40)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    w.btn = btn

    ns.CreateRoundedRectBorder(btn)
    ns.SetRoundedRectBarHeight(btn, 40)
    ns.SetRoundedRectBorderBgAlpha(btn, 1)
    ns.SetRoundedRectBorderEdgeShown(btn, false)
    ns.SetRoundedRectBorderFillColor(btn, 0.18, 0.18, 0.20, 1)

    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("CENTER")
    ApplyInter(fs, "semibold")


    fs._efOwnColor = true
    btn._label = fs

    local function setHover(hover)
        local pal = ns.ACTIVE_UI_PALETTE
        if pal and pal.light then
            local theme = ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
            local leaf = (theme and theme.leafColor) or TEXT_PRIM
            local f = hover and 0.15 or 0
            ns.SetRoundedRectBorderFillColor(btn,
                leaf[1] + (1 - leaf[1]) * f,
                leaf[2] + (1 - leaf[2]) * f,
                leaf[3] + (1 - leaf[3]) * f, 1)
            local windowFill = ns.SEARCH_WINDOW_FILL_COLOR
            fs:SetTextColor(windowFill[1], windowFill[2], windowFill[3], 1)
        else
            ns.SetRoundedRectBorderFillColor(btn, KbPillFill(hover))
            fs:SetTextColor(Utils.RGB(TEXT_PRIM, 1))
        end
    end
    setHover(false)
    invertedPills[#invertedPills + 1] = function() setHover(false) end
    btn:SetScript("OnEnter", function() setHover(true) end)
    btn:SetScript("OnLeave", function() setHover(false) end)

    btn:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            EasyFind:SetAccountKeybind(action, nil)
            RefreshKbWidget(w)
            return
        end
        if kbWaitingFor == w then
            StopKeybindCapture()
            return
        end
        StopKeybindCapture()
        kbWaitingFor = w
        self._label:SetText(L["TUT_KB_PRESS_KEY"])
        Utils.ArmBindingCapture(self, function(_, combo)
            if combo ~= "stop" then EasyFind:SetAccountKeybind(action, combo) end
            StopKeybindCapture()
        end)
    end)

    return w
end







local function BuildPageShowMethod(parent)
    local p = MakePage(parent)

    local title = HeaderText(p, L["TUT_SHOWMETHOD_HEADER"], "GameFontNormalLarge", HEADER_MAX_W)
    title:SetPoint("TOP", p, "TOP", 0, -36)

    local sub = BodyText(p, L["TUT_SHOWMETHOD_BODY"])
    sub:SetPoint("TOP", title, "BOTTOM", 0, -10)
    sub:SetWidth(WIZ_W - 100)

    local column = CreateFrame("Frame", nil, p)
    column:SetSize(WIZ_W - 170, 216)
    column:SetPoint("TOP", sub, "BOTTOM", 0, -24)

    local modeRows = {}
    local subChecks = {}

    local function RefreshAll()
        local mode = ns.GetVisibilityMode()
        for i = 1, #modeRows do
            local row = modeRows[i]
            row.radio:SetTexture(mode == row.mode and ns.RADIO_ON_TEX or ns.RADIO_OFF_TEX)
        end
        local isAlways = mode == ns.VISIBILITY_ALWAYS
        for i = 1, #subChecks do
            local line = subChecks[i]
            local enabled = isAlways and (not line.needsCombatShown
                or EasyFind.db.combatHide == false)
            line.check:SetShown(line.getter())
            local dim = enabled and 1 or 0.4
            line.box:SetAlpha(dim)
            line.check:SetAlpha(dim)
            line.lbl:SetAlpha(dim)
            line.enabled = enabled
        end
    end

    local function AddModeRow(mode, labelText, descText, yOffset, rowH)
        local row = CreateFrame("Button", nil, column)
        row:SetSize(column:GetWidth(), rowH)
        row:SetPoint("TOPLEFT", column, "TOPLEFT", 0, yOffset)
        local radio = row:CreateTexture(nil, "ARTWORK")
        radio:SetSize(14, 14)
        radio:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
        radio:SetTexture(ns.RADIO_OFF_TEX)
        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("LEFT", radio, "RIGHT", 6, 0)
        lbl:SetText(labelText)
        ApplyInter(lbl, "regular")
        local desc = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        desc:SetPoint("TOPLEFT", radio, "TOPRIGHT", 6, -18)
        desc:SetWidth(column:GetWidth() - 24)
        desc:SetJustifyH("LEFT")
        desc:SetText(descText)
        desc:SetTextColor(Utils.RGB(TEXT_DIM, 1))
        ApplyInter(desc, "regular")
        row:SetScript("OnClick", function()
            ns.SetVisibilityMode(mode)
            RefreshAll()
        end)
        modeRows[#modeRows + 1] = { mode = mode, radio = radio }
        return row
    end

    local function AddSubCheck(labelText, yOffset, opts)
        local line = CreateFrame("Button", nil, column)
        line:SetSize(column:GetWidth() - 22, 17)
        line:SetPoint("TOPLEFT", column, "TOPLEFT", 22, yOffset)
        local box = line:CreateTexture(nil, "ARTWORK")
        box:SetSize(12, 12)
        box:SetPoint("LEFT", line, "LEFT", 0, 0)
        box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
        box:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local check = line:CreateTexture(nil, "OVERLAY")
        check:SetSize(12, 12)
        check:SetPoint("CENTER", box, "CENTER", 0, 0)
        check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        check:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local lbl = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("LEFT", box, "RIGHT", 4, 0)
        lbl:SetText(labelText)
        ApplyInter(lbl, "regular")
        local entry = {
            box = box, check = check, lbl = lbl,
            getter = opts.getter, needsCombatShown = opts.needsCombatShown,
        }
        line:SetScript("OnClick", function()
            if entry.needsCombatShown and EasyFind.db.combatHide ~= false
                and ns.GetVisibilityMode() == ns.VISIBILITY_ALWAYS then
                return
            end
            opts.setter(not opts.getter())
            ns.SetVisibilityMode(ns.VISIBILITY_ALWAYS)
            RefreshAll()
        end)
        subChecks[#subChecks + 1] = entry
        return line
    end

    AddModeRow(ns.VISIBILITY_AUTO,
        L["OPT_VISIBILITY_AUTOHIDE"] .. " (" .. L["TUT_RECOMMENDED"] .. ")",
        L["OPT_VISIBILITY_AUTOHIDE_TT"], 0, 44)
    AddModeRow(ns.VISIBILITY_SMART,
        L["OPT_VISIBILITY_SMARTSHOW"],
        L["OPT_VISIBILITY_SMARTSHOW_TT"], -48, 44)
    AddModeRow(ns.VISIBILITY_ALWAYS,
        L["OPT_VISIBILITY_ALWAYS"],
        L["OPT_VISIBILITY_ALWAYS_TT"], -96, 44)
    AddSubCheck(L["OPT_COMBAT_HIDE_SHORT"], -152, {
        getter = function() return EasyFind.db.combatHide ~= false end,
        setter = function(v) EasyFind.db.combatHide = v and true or false end,
    })
    AddSubCheck(L["OPT_COMBAT_DIM"], -170, {
        getter = function() return EasyFind.db.combatDim == true end,
        setter = function(v) EasyFind.db.combatDim = v and true or false end,
        needsCombatShown = true,
    })
    AddSubCheck(L["OPT_MOVE_DIM"], -188, {
        getter = function() return EasyFind.db.moveDim == true end,
        setter = function(v)
            EasyFind.db.moveDim = v and true or false
            if ns.Search and ns.Search.UpdateMoveDim then
                ns.Search:UpdateMoveDim()
            end
        end,
    })

    local note = BodyText(p, L["TUT_SHOWMETHOD_NOTE"])
    note:SetPoint("TOP", column, "BOTTOM", 0, -4)
    note:SetWidth(WIZ_W - 100)

    p.OnEnter = RefreshAll

    return p
end

local function BuildPageTheme(parent)
    local p = MakePage(parent)

    local title = HeaderText(p, L["TUT_THEME_HEADER"], "GameFontNormalLarge", HEADER_MAX_W)
    title:SetPoint("TOP", p, "TOP", 0, -22)

    local replica = BuildSearchBarReplica(p, 380, 36)
    replica:SetPoint("TOP", title, "BOTTOM", 0, -24)

    local COLS = 3
    local SWATCH_W, SWATCH_H = 150, 30
    local GAP_X, GAP_Y = 12, 9
    local rowCount = math.ceil(#ns.UI_THEME_ORDER / COLS)
    local grid = CreateFrame("Frame", nil, p)
    grid:SetSize(COLS * SWATCH_W + (COLS - 1) * GAP_X, rowCount * SWATCH_H + (rowCount - 1) * GAP_Y)
    grid:SetPoint("TOP", replica, "BOTTOM", 0, -26)

    local swatches = {}
    local function RefreshSelection()
        local current = (EasyFind.db and EasyFind.db.uiTheme)
            or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.uiTheme) or "Midnight"
        for i = 1, #swatches do
            local swatch = swatches[i]
            swatch.selRing:SetShown(swatch._themeName == current)
        end
    end


    local RepaintWizardTheme

    for i, themeName in ipairs(ns.UI_THEME_ORDER) do
        local pal = ns.UI_THEME_PALETTES[themeName]
        local swatch = CreateFrame("Button", nil, grid)
        swatch:SetSize(SWATCH_W, SWATCH_H)
        local col = (i - 1) % COLS
        local rowIdx = math.floor((i - 1) / COLS)
        swatch:SetPoint("TOPLEFT", grid, "TOPLEFT", col * (SWATCH_W + GAP_X), -rowIdx * (SWATCH_H + GAP_Y))
        swatch._themeName = themeName
        swatch._efNoAutoRetint = true



        local selRing = CreateFrame("Frame", nil, swatch)
        selRing:SetPoint("TOPLEFT", swatch, "TOPLEFT", -2, 2)
        selRing:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", 2, -2)
        selRing:SetFrameLevel(swatch:GetFrameLevel() > 0 and swatch:GetFrameLevel() - 1 or 0)
        selRing._efNoAutoRetint = true
        ns.CreateRoundedRectBorder(selRing)
        ns.SetRoundedRectBarHeight(selRing, 16)
        ns.SetRoundedRectRingShown(selRing, false)
        local accentC = pal.accent or ns.GOLD_COLOR
        ns.SetRoundedRectFill(selRing, accentC[1], accentC[2], accentC[3], 1, true)
        ns.SetRoundedRectBorderBgAlpha(selRing, 1)
        selRing:Hide()
        swatch.selRing = selRing
        ns.CreateRoundedRectBorder(swatch)
        ns.SetRoundedRectBarHeight(swatch, 14)
        ns.SetRoundedRectRingShown(swatch, false)
        local sr, sg, sb = ns.ThemeSwatchColor(pal)
        ns.SetRoundedRectFill(swatch, sr, sg, sb, 1, true)
        ns.SetRoundedRectBorderBgAlpha(swatch, 1)
        local label = swatch:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        ApplyInter(label, "semibold")
        label:SetPoint("CENTER")
        label:SetText(themeName)
        label._efOwnColor = true
        ns.ShadeText(label)
        label:SetTextColor(pal.leafColor[1], pal.leafColor[2], pal.leafColor[3], 1)
        swatch:SetScript("OnClick", function(self)
            EasyFind.db.uiTheme = self._themeName
            if ns.ApplyUITheme then ns.ApplyUITheme(self._themeName) end
            RepaintWizardTheme()
            if p.SyncArtCheck then p.SyncArtCheck() end

            if ns.RepaintOptionsPanelTheme then pcall(ns.RepaintOptionsPanelTheme) end
        end)
        swatches[#swatches + 1] = swatch
    end




    RepaintWizardTheme = function()
        if not (frame and frame:IsShown()) then return end
        ns.StyleWizardPanel(frame, PANEL_BG_ALPHA)
        if RepaintFooter then RepaintFooter() end
        if ns.RetintMenuText then ns.RetintMenuText(frame) end
        RepaintThemedTexts()
        RepaintInvertedPills()
        RepaintFeatureTiles()
        PaintDots()
        RepaintReplicas()
        RefreshSelection()
    end
    ns.RepaintWizardTheme = RepaintWizardTheme



    local borderLine = CreateFrame("Button", nil, p)
    borderLine:SetSize(220, 18)
    borderLine:SetPoint("TOP", grid, "BOTTOM", 0, -14)
    local borderBox = borderLine:CreateTexture(nil, "ARTWORK")
    borderBox:SetSize(14, 14)
    borderBox:SetPoint("LEFT", borderLine, "LEFT", 0, 0)
    borderBox:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
    borderBox:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local borderCheck = borderLine:CreateTexture(nil, "OVERLAY")
    borderCheck:SetSize(14, 14)
    borderCheck:SetPoint("CENTER", borderBox, "CENTER", 0, 0)
    borderCheck:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    borderCheck:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local borderLbl = borderLine:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ApplyInter(borderLbl, "regular")
    borderLbl:SetPoint("LEFT", borderBox, "RIGHT", 5, 0)
    borderLbl:SetText(L["OPT_WINDOW_BORDER"])
    borderLine:SetWidth(19 + borderLbl:GetStringWidth() + 4)
    local function SyncBorderCheck()
        borderCheck:SetShown(EasyFind.db and EasyFind.db.windowBorder ~= false)
    end
    borderLine:SetScript("OnClick", function()
        EasyFind.db.windowBorder = EasyFind.db.windowBorder == false
        if ns.Search and ns.Search.UpdateWindowBorders then
            ns.Search:UpdateWindowBorders()
        end
        if ns.RepaintWizardTheme then ns.RepaintWizardTheme() end
        RepaintReplicas()
        SyncBorderCheck()
        if p.SyncArtCheck then p.SyncArtCheck() end
    end)



    local artLine = CreateFrame("Button", nil, p)
    artLine:SetSize(220, 18)
    artLine:SetPoint("TOP", borderLine, "BOTTOM", 0, -6)
    local artBox = artLine:CreateTexture(nil, "ARTWORK")
    artBox:SetSize(14, 14)
    artBox:SetPoint("LEFT", artLine, "LEFT", 0, 0)
    artBox:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
    artBox:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local artCheck = artLine:CreateTexture(nil, "OVERLAY")
    artCheck:SetSize(14, 14)
    artCheck:SetPoint("CENTER", artBox, "CENTER", 0, 0)
    artCheck:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    artCheck:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local artLbl = artLine:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ApplyInter(artLbl, "regular")
    artLbl:SetPoint("LEFT", artBox, "RIGHT", 5, 0)
    artLbl:SetText(L["OPT_THEME_FRAME_ART"])
    artLine:SetWidth(19 + artLbl:GetStringWidth() + 4)
    local function SyncArtCheck()
        local pal = ns.ACTIVE_UI_PALETTE
        artLine:SetShown(pal ~= nil and pal.chrome ~= nil and EasyFind.db.windowBorder ~= false)
        artCheck:SetShown(EasyFind.db.themeFrameArt ~= false)
    end
    artLine:SetScript("OnClick", function()
        EasyFind.db.themeFrameArt = EasyFind.db.themeFrameArt == false
        if ns.Search and ns.Search.UpdateWindowBorders then
            ns.Search:UpdateWindowBorders()
        end
        if ns.RepaintWizardTheme then ns.RepaintWizardTheme() end
        RepaintReplicas()
        SyncArtCheck()
        if ns.optionsFrame and ns.optionsFrame.RefreshBorderRow then ns.optionsFrame.RefreshBorderRow() end
    end)
    p.SyncArtCheck = SyncArtCheck

    local note = BodyText(p, L["TUT_THEME_RESIZE_NOTE"])
    note:SetPoint("TOP", artLine, "BOTTOM", 0, -14)
    note:SetWidth(WIZ_W - 100)

    p.OnEnter = function()
        RefreshSelection()
        SyncBorderCheck()
        SyncArtCheck()
    end
    SyncBorderCheck()
    SyncArtCheck()

    return p
end

local function BuildPage3(parent)
    local p = MakePage(parent)

    local title = HeaderText(p, L["TUT_KEYBIND_HEADER"], "GameFontNormalLarge", HEADER_MAX_W)
    title:SetPoint("TOP", p, "TOP", 0, -36)

    local sub = BodyText(p, "")
    sub:SetPoint("TOP", title, "BOTTOM", 0, -10)
    sub:SetWidth(WIZ_W - 100)

    local uiKb  = CreateKbWidget(p, TOGGLE_ACTION, L["TUT_KEYBIND_SEARCH_BAR"])
    uiKb.label:SetPoint("BOTTOM", uiKb.btn, "TOP", 0, 6)
    local KB_GROUP_GAP = 44
    local mapKb = CreateKbWidget(p, MAP_ACTION, L["TUT_KEYBIND_MAP_TAB"])
    kbWidgets = { uiKb, mapKb }
    uiKb.btn:SetPoint("BOTTOM", p, "CENTER", 0, KB_GROUP_GAP / 2)
    mapKb.btn:SetPoint("TOP", uiKb.btn, "BOTTOM", 0, -KB_GROUP_GAP)
    mapKb.label:SetPoint("BOTTOM", mapKb.btn, "TOP", 0, 6)

    local hint = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetText(L["TUT_KEYBIND_CAPTURE_HINT"])
    hint:SetTextColor(Utils.RGB(TEXT_DIM, 1))
    hint:SetPoint("BOTTOM", p, "BOTTOM", 0, 22)
    hint:SetWidth(WIZ_W - 100)
    hint:SetJustifyH("CENTER")
    ApplyInter(hint, "regular")

    p.OnEnter = function()
        for i = 1, #kbWidgets do RefreshKbWidget(kbWidgets[i]) end
    end

    p:HookScript("OnHide", StopKeybindCapture)

    return p
end

local BANNER_H = 29
local CLASSIC_EDGE = 14

local function CreateFrameOnce()
    if frame then return frame end

    local f = CreateFrame("Frame", "EasyFindWizard", UIParent)

    f:SetSize(WIZ_W, WIZ_H)
    f:SetScale(0.88)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(220)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    frame = f

    ns.StyleWizardPanel(f, PANEL_BG_ALPHA)


    f:HookScript("OnShow", function(self)
        if RepaintFooter then RepaintFooter() end
        if ns.RetintMenuText then ns.RetintMenuText(self) end
        RepaintThemedTexts()
        RepaintInvertedPills()
        RepaintFeatureTiles()
        PaintDots()
        RepaintReplicas()
    end)

    local closeBtn = ns.CreateCloseX(f)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
    closeBtn:SetScript("OnClick", function() FinishWizard(false) end)

    local pageHost = CreateFrame("Frame", nil, f)
    pageHost:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
    pageHost:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 6 + BANNER_H + 4)

    pages = {
        BuildPage1(pageHost),
        BuildPage2(pageHost),
        BuildPageShowMethod(pageHost),
        BuildPageTheme(pageHost),
        BuildPage3(pageHost),
    }

    local BANNER_INSET = 5
    local footer = CreateFrame("Frame", nil, f)
    footer:SetHeight(BANNER_H)
    ns.CreateRoundedRectBorder(footer)
    ns.SetRoundedRectBarHeight(footer, 12)
    ns.SetRoundedRectBorderBgAlpha(footer, 1)
    ns.SetRoundedRectFill(footer, ns.SECTION_TABLE_FILL[1], ns.SECTION_TABLE_FILL[2], ns.SECTION_TABLE_FILL[3], 1, true)

    ns.SetRoundedRectRingShown(footer, false)
    footer._efControlFillKind = "SECTION_TABLE_FILL"
    footer._efControlFillAlpha = 1
    RepaintFooter = function()
        local fr, fg, fb = ThemeBandFill()
        ns.SetRoundedRectFill(footer, fr, fg, fb, 1, true)


        local classic = ns.IsClassicChrome()
        ns.SetRoundedRectBorderShown(footer, not classic)
        ns.SetRoundedRectRingShown(footer, false)
        if not footer.iron then

            footer.iron = ns.CreateIronLine(f, false)
            footer.iron:SetPoint("TOP", footer, "TOP", 0, 6)
            footer.iron:SetPoint("LEFT", f, "LEFT", 11, 0)
            footer.iron:SetPoint("RIGHT", f, "RIGHT", -12, 0)
        end
        footer.iron:SetShown(classic)
        local inset = classic and CLASSIC_EDGE or BANNER_INSET
        footer:ClearAllPoints()
        footer:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",  inset, inset)
        footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
        pageHost:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, inset + BANNER_H + 4)
        local xPad = classic and CLASSIC_EDGE or 10
        closeBtn:ClearAllPoints()
        closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -xPad, -xPad)
    end
    RepaintFooter()

    local DOT_GAP = 11
    local DOT_SZ  = 7
    local DOT_ACTIVE = 9
    local function OnDotClick(self)
        ShowPage(self._page)
    end
    for i = 1, #pages do


        local dotBtn = CreateFrame("Button", nil, footer)
        dotBtn:SetSize(DOT_SZ + DOT_GAP, BANNER_H)
        dotBtn:SetPoint("LEFT", footer, "LEFT",
            12 + DOT_ACTIVE / 2 + (i - 1) * (DOT_SZ + DOT_GAP) - DOT_GAP / 2, 0)
        dotBtn._page = i
        dotBtn:SetScript("OnClick", OnDotClick)
        local d = dotBtn:CreateTexture(nil, "OVERLAY")
        d:SetSize(DOT_SZ, DOT_SZ)
        d:SetTexture(DOT_FILLED)
        d:SetPoint("CENTER")
        dots[i] = d
    end

    nextBtn = MakeButton(footer, L["TUT_BTN_CONTINUE"], "rounded", 78)
    nextBtn:SetPoint("RIGHT", footer, "RIGHT", -8, 0)

    backBtn = MakeButton(footer, L["TUT_BTN_BACK"], "rounded", 78)
    backBtn:SetPoint("RIGHT", nextBtn, "LEFT", -6, 0)
    backBtn:SetScript("OnClick", function() ShowPage(pageIdx - 1) end)

    nextBtn:SetScript("OnClick", function()
        if pageIdx >= #pages then
            FinishWizard(true)
        else
            ShowPage(pageIdx + 1)
        end
    end)


    Utils.AttachEscClose(f, function() FinishWizard(false) end)

    return f
end

function Wizard:IsShown()
    return frame and frame:IsShown()
end

function Wizard:Show(startPage)

    if InCombatLockdown() then return end
    CreateFrameOnce()
    if ns.Search and ns.Search.Hide then ns.Search:Hide() end
    local page = startPage or 1
    if page > #pages then page = #pages elseif page < 1 then page = 1 end
    pageIdx = page
    frame:Show()






    if RepaintFooter then RepaintFooter() end
    if ns.RetintMenuText then ns.RetintMenuText(frame) end
    RepaintThemedTexts()
    RepaintInvertedPills()
    RepaintReplicas()
    ShowPage(page)
end

function Wizard:Hide()
    if frame then
        frame:Hide()
    end
end
