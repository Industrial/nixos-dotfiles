local _, ns = ...

local Results = ns.Results
local Shortcuts = ns.ResultShortcuts

local TOOLTIP_BORDER = ns.TOOLTIP_BORDER

local THEMES = {}

function Results:ApplySearchWindowFill(frame)
    if not frame then return end
    ns.ApplyThemeFill(frame)
end

THEMES["Modern"] = {
    rowHeight       = 20,
    indentPx        = 20,
    lineWidth       = 2,
    resultsWidth    = 350,
    resultsPadTop   = 8,
    resultsPadBot   = 8,
    resultsPadLeft  = 12,
    btnWidth        = 366,
    iconSize        = 15,
    pathIconSize    = 13,
    pathFont        = ns.SEARCHBAR_FONT,
    leafFont        = ns.LEAF_FONT,
    pathColor       = {0.65, 0.60, 0.55, 1.0},
    pathColorHover  = {1.0, 1.0, 1.0, 1.0},
    leafColor       = {0.9, 0.9, 0.9},
    chromeGlyph     = {1.0, 1.0, 1.0},
    mutedGlyph      = {0.58, 0.58, 0.58, 0.85},
    textFaint       = {0.5, 0.5, 0.5},
    showTreeLines   = false,
    indentColors    = {
        {0.85, 0.65, 0.15, 0.80},
        {0.85, 0.65, 0.15, 0.80},
        {0.85, 0.65, 0.15, 0.80},
        {0.85, 0.65, 0.15, 0.80},
        {0.85, 0.65, 0.15, 0.80},
        {0.85, 0.65, 0.15, 0.80},
    },
    expandIcon      = "Interface\\Buttons\\UI-PlusButton-Up",
    collapseIcon    = "Interface\\Buttons\\UI-MinusButton-Up",
    highlightTex    = "Interface\\QuestFrame\\UI-QuestTitleHighlight",
    selectionColor  = {0.25, 0.5, 0.9, 0.35},
    showHeaderBar   = false,
    showHeaderTab   = false,
    headerTabAtlas  = "QuestLog-tab",
    headerHighlightAlpha = 0.40,
    expandAtlas     = "QuestLog-icon-expand",
    collapseAtlas   = "QuestLog-icon-shrink",
    toggleNormalAlpha = 0.60,
    toggleHoverAlpha  = 1.0,
    showSeparators  = false,
    separatorColor  = {0.5, 0.45, 0.3, 0.35},
    resultsBackdrop = {
        edgeFile = TOOLTIP_BORDER,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    },
    resultsBgAtlas          = "QuestLog-main-background",
    resultsBackdropColor       = {0.12, 0.10, 0.08, 0.95},
    resultsBackdropBorderColor = {0.50, 0.48, 0.45, 1.0},
    searchBarRounded = true,
}

function Results:GetActiveTheme()
    return THEMES["Modern"]
end







ns.UI_THEME_ORDER = { "Black", "Midnight", "Ocean", "Amethyst", "Crimson", "Flame", "Forever", "Classic", "Sky", "Linen", "Mint", "Rose" }


local FOREVER_GLYPH = {0.80, 0.66, 0.30, 0.90}

ns.UI_THEME_PALETTES = {
    Black = {
        windowFill = {0.052, 0.052, 0.060},
        pathColor = {0.65, 0.60, 0.55, 1.0},
        pathColorHover = {1.0, 1.0, 1.0, 1.0},
        leafColor = {0.9, 0.9, 0.9},
        chromeGlyph = {1.0, 1.0, 1.0},
        mutedGlyph = {0.58, 0.58, 0.58, 0.85},
        textFaint = {0.50, 0.50, 0.50},
        accent = {0.85, 0.65, 0.15, 0.80},
        controlAccent = {0.17, 0.48, 0.72},
        selection = {0.25, 0.5, 0.9, 0.35},
        separator = {0.5, 0.45, 0.3, 0.35},
        backdropColor = {0.12, 0.10, 0.08, 0.95},
        backdropBorder = {0.50, 0.48, 0.45, 1.0},
    },



    Midnight = {
        windowFill = {0.090, 0.108, 0.355},
        fillTexture = "Interface\\AddOns\\EasyFind\\textures\\CombinedFillGalaxy",




        windowFillBottom = {0.030, 0.050, 0.230},
        windowFillTop = {0.200, 0.105, 0.480},
        pathColor = {0.70, 0.74, 0.90, 1.0},
        pathColorHover = {1.0, 1.0, 1.0, 1.0},
        leafColor = {0.94, 0.95, 1.0},
        chromeGlyph = {1.0, 1.0, 1.0},
        mutedGlyph = {0.66, 0.70, 0.86, 0.85},
        textFaint = {0.52, 0.57, 0.78},
        accent = {0.48, 0.62, 1.0, 0.80},
        selection = {0.34, 0.52, 1.0, 0.35},
        separator = {0.42, 0.48, 0.74, 0.35},
        backdropColor = {0.07, 0.08, 0.22, 0.95},
        backdropBorder = {0.42, 0.48, 0.74, 1.0},
    },
    Ocean = {
        windowFill = {0.055, 0.120, 0.200},

        windowFillBottom = {0.020, 0.050, 0.100},
        windowFillTop = {0.090, 0.190, 0.300},
        pathColor = {0.55, 0.62, 0.72, 1.0},
        pathColorHover = {1.0, 1.0, 1.0, 1.0},
        leafColor = {0.88, 0.92, 0.96},
        chromeGlyph = {1.0, 1.0, 1.0},
        mutedGlyph = {0.58, 0.58, 0.58, 0.85},
        textFaint = {0.40, 0.48, 0.60},
        accent = {0.25, 0.60, 0.95, 0.80},
        selection = {0.25, 0.55, 0.95, 0.35},
        separator = {0.30, 0.45, 0.60, 0.35},
        backdropColor = {0.10, 0.14, 0.21, 0.95},
        backdropBorder = {0.35, 0.45, 0.58, 1.0},
    },
    Amethyst = {
        windowFill = {0.130, 0.055, 0.190},

        windowFillBottom = {0.060, 0.020, 0.100},
        windowFillTop = {0.200, 0.090, 0.280},
        pathColor = {0.68, 0.58, 0.72, 1.0},
        pathColorHover = {1.0, 1.0, 1.0, 1.0},
        leafColor = {0.93, 0.88, 0.95},
        chromeGlyph = {1.0, 1.0, 1.0},
        mutedGlyph = {0.58, 0.58, 0.58, 0.85},
        textFaint = {0.50, 0.42, 0.58},
        accent = {0.72, 0.45, 0.95, 0.80},
        selection = {0.60, 0.35, 0.85, 0.35},
        separator = {0.50, 0.35, 0.60, 0.35},
        backdropColor = {0.16, 0.10, 0.19, 0.95},
        backdropBorder = {0.48, 0.38, 0.55, 1.0},
    },
    Crimson = {
        windowFill = {0.145, 0.045, 0.040},

        windowFillBottom = {0.070, 0.015, 0.030},
        windowFillTop = {0.220, 0.070, 0.050},
        pathColor = {0.72, 0.55, 0.55, 1.0},
        pathColorHover = {1.0, 1.0, 1.0, 1.0},
        leafColor = {0.95, 0.88, 0.88},
        chromeGlyph = {1.0, 1.0, 1.0},
        mutedGlyph = {0.58, 0.58, 0.58, 0.85},
        textFaint = {0.58, 0.42, 0.44},
        accent = {0.90, 0.25, 0.30, 0.80},
        selection = {0.90, 0.25, 0.30, 0.30},
        separator = {0.60, 0.30, 0.32, 0.35},
        backdropColor = {0.17, 0.08, 0.10, 0.95},
        backdropBorder = {0.55, 0.35, 0.36, 1.0},
    },




    Forever = {
        chrome = "forever",
        windowFill = {0.104, 0.089, 0.073},
        fillAtlas = "QuestLog-main-background",

        windowFillBottom = {0.050, 0.046, 0.042},
        windowFillTop = {0.150, 0.128, 0.100},


        pathColor = {1.0, 0.80, 0.22, 1.0},
        pathColorHover = {1.0, 0.95, 0.70, 1.0},
        leafColor = {0.96, 0.93, 0.86},
        chromeGlyph = FOREVER_GLYPH,
        mutedGlyph = FOREVER_GLYPH,
        flatGlyphs = true,
        textFaint = {0.62, 0.53, 0.32},
        accent = {1.0, 0.78, 0.16, 0.90},
        selection = {1.0, 0.78, 0.16, 0.26},
        separator = {0.78, 0.55, 0.30, 0.40},
        backdropColor = {0.10, 0.089, 0.073, 0.95},
        backdropBorder = {0.78, 0.55, 0.30, 1.0},
    },




    Classic = {
        chrome = "classic",


        fillTexture = "Interface\\FrameGeneral\\UI-Background-Marble",
        fillTile = 256,
        windowFill = {0.055, 0.055, 0.105},
        windowFillBottom = {0.035, 0.035, 0.075},
        windowFillTop = {0.075, 0.075, 0.135},


        pathColor = {0.80, 0.76, 0.66, 1.0},
        pathColorHover = {1.0, 1.0, 1.0, 1.0},
        leafColor = {0.96, 0.96, 0.96},
        chromeGlyph = {0.82, 0.82, 0.82},
        mutedGlyph = {0.64, 0.64, 0.64, 0.90},
        textFaint = {0.52, 0.52, 0.50},
        accent = {0.72, 0.68, 0.58, 0.65},
        selection = {0.80, 0.78, 0.70, 0.16},
        separator = {0.58, 0.55, 0.46, 0.35},
        backdropColor = {0.05, 0.05, 0.10, 0.95},

        backdropBorder = {1.0, 1.0, 1.0, 1.0},
    },



    Flame = {
        windowFill = {0.110, 0.055, 0.030},
        windowFillBottom = {0.050, 0.020, 0.010},
        windowFillTop = {0.260, 0.100, 0.030},
        pathColor = {0.82, 0.62, 0.46, 1.0},
        pathColorHover = {1.0, 1.0, 1.0, 1.0},
        leafColor = {0.98, 0.93, 0.86},
        chromeGlyph = {1.0, 1.0, 1.0},
        mutedGlyph = {0.64, 0.54, 0.46, 0.85},
        textFaint = {0.62, 0.46, 0.33},
        accent = {1.0, 0.55, 0.10, 0.80},
        selection = {1.0, 0.50, 0.10, 0.30},
        separator = {0.66, 0.40, 0.20, 0.35},
        backdropColor = {0.16, 0.08, 0.05, 0.95},
        backdropBorder = {0.60, 0.40, 0.28, 1.0},
        beacon = { base = {1.0, 0.50, 0.08}, hot = {1.0, 0.95, 0.75} },
    },
    Sky = {
        light = true,
        windowFill = {0.63, 0.76, 0.88},
        windowFillBottom = {0.58, 0.71, 0.84},
        windowFillTop = {0.68, 0.81, 0.92},
        pathColor = {0.11, 0.23, 0.38, 1.0},
        pathColorHover = {0.05, 0.17, 0.36, 1.0},
        leafColor = {0.10, 0.28, 0.52},
        chromeGlyph = {0.10, 0.28, 0.52},
        mutedGlyph = {0.10, 0.28, 0.52, 1.0},
        textFaint = {0.24, 0.35, 0.48},
        accent = {0.15, 0.45, 0.80, 0.85},
        selection = {0.20, 0.45, 0.85, 0.25},
        separator = {0.25, 0.35, 0.45, 0.30},
        backdropColor = {0.55, 0.69, 0.82, 0.97},
        backdropBorder = {0.40, 0.52, 0.65, 1.0},
    },
    Linen = {
        light = true,
        windowFill = {0.82, 0.82, 0.72},
        windowFillBottom = {0.76, 0.76, 0.65},
        windowFillTop = {0.87, 0.87, 0.78},
        pathColor = {0.26, 0.24, 0.10, 1.0},
        pathColorHover = {0.26, 0.23, 0.07, 1.0},
        leafColor = {0.30, 0.26, 0.08},
        chromeGlyph = {0.30, 0.26, 0.08},
        mutedGlyph = {0.30, 0.26, 0.08, 1.0},
        textFaint = {0.40, 0.38, 0.27},
        accent = {0.55, 0.45, 0.15, 0.85},
        selection = {0.45, 0.40, 0.20, 0.25},
        separator = {0.40, 0.38, 0.28, 0.30},
        backdropColor = {0.75, 0.75, 0.65, 0.97},
        backdropBorder = {0.55, 0.53, 0.44, 1.0},
    },
    Mint = {
        light = true,
        windowFill = {0.68, 0.80, 0.70},
        windowFillBottom = {0.62, 0.75, 0.64},
        windowFillTop = {0.74, 0.85, 0.76},
        pathColor = {0.10, 0.28, 0.15, 1.0},
        pathColorHover = {0.05, 0.26, 0.12, 1.0},
        leafColor = {0.07, 0.34, 0.18},
        chromeGlyph = {0.07, 0.34, 0.18},
        mutedGlyph = {0.07, 0.34, 0.18, 1.0},
        textFaint = {0.24, 0.39, 0.29},
        accent = {0.15, 0.55, 0.30, 0.85},
        selection = {0.18, 0.55, 0.30, 0.25},
        separator = {0.24, 0.38, 0.27, 0.30},
        backdropColor = {0.60, 0.74, 0.63, 0.97},
        backdropBorder = {0.40, 0.56, 0.44, 1.0},
    },
    Rose = {
        light = true,
        windowFill = {0.86, 0.70, 0.76},
        windowFillBottom = {0.80, 0.62, 0.69},
        windowFillTop = {0.91, 0.77, 0.83},
        pathColor = {0.36, 0.13, 0.20, 1.0},
        pathColorHover = {0.37, 0.09, 0.18, 1.0},
        leafColor = {0.44, 0.10, 0.22},
        chromeGlyph = {0.44, 0.10, 0.22},
        mutedGlyph = {0.44, 0.10, 0.22, 1.0},
        textFaint = {0.46, 0.31, 0.37},
        accent = {0.85, 0.30, 0.45, 0.85},
        selection = {0.85, 0.30, 0.45, 0.25},
        separator = {0.55, 0.32, 0.38, 0.30},
        backdropColor = {0.80, 0.63, 0.70, 0.97},
        backdropBorder = {0.65, 0.45, 0.50, 1.0},
    },
}

local function CopySlot(dst, src)
    local n = #src
    if #dst > n then n = #dst end
    for i = 1, n do dst[i] = src[i] end
end





local SET_FILLS = { "SEARCH_WINDOW_FILL_COLOR", "BTN_FILL_NORMAL", "BTN_FILL_HOVER", "BTN_FILL_PRESSED",
    "SECTION_TABLE_FILL", "NAV_SELECTED_FILL", "NAV_HOVER_FILL", "PANEL_CARD_FILL", "EDITBOX_INSET_FILL",
    "LINK_COLOR", "LINK_HOVER", "TEXT_PRIMARY", "TEXT_BODY", "CONTROL_ACCENT" }
local THEME_COLORS = { "pathColor", "pathColorHover", "leafColor", "chromeGlyph", "mutedGlyph", "textFaint",
    "selectionColor", "separatorColor", "resultsBackdropColor", "resultsBackdropBorderColor" }

local sharedSet
local function SharedSet()
    if not sharedSet then
        sharedSet = { theme = THEMES["Modern"], shared = true }
        for i = 1, #SET_FILLS do sharedSet[SET_FILLS[i]] = ns[SET_FILLS[i]] end
    end
    return sharedSet
end


local function NewSet()
    local modern = THEMES["Modern"]
    local theme = setmetatable({ indentColors = {} }, { __index = modern })
    for i = 1, #THEME_COLORS do theme[THEME_COLORS[i]] = {} end
    for i = 1, #modern.indentColors do theme.indentColors[i] = {} end
    local set = { theme = theme }
    for i = 1, #SET_FILLS do
        local live = ns[SET_FILLS[i]]
        set[SET_FILLS[i]] = { live[1], live[2], live[3], live[4] }
    end
    return set
end

local function setColor(dst, r, g, b, a)
    dst[1], dst[2], dst[3] = r, g, b
    if dst[4] ~= nil or a ~= nil then dst[4] = a end
end



local function DeriveSet(palette, set)
    local theme = set.theme
    local fillC = set.SEARCH_WINDOW_FILL_COLOR
    CopySlot(fillC, palette.windowFill)
    CopySlot(theme.pathColor, palette.pathColor)
    CopySlot(theme.pathColorHover, palette.pathColorHover)
    CopySlot(theme.leafColor, palette.leafColor)
    CopySlot(theme.chromeGlyph, palette.chromeGlyph)
    CopySlot(theme.mutedGlyph, palette.mutedGlyph)
    CopySlot(theme.textFaint, palette.textFaint)
    CopySlot(theme.selectionColor, palette.selection)
    CopySlot(theme.separatorColor, palette.separator)
    CopySlot(theme.resultsBackdropColor, palette.backdropColor)
    CopySlot(theme.resultsBackdropBorderColor, palette.backdropBorder)
    for i = 1, #theme.indentColors do
        CopySlot(theme.indentColors[i], palette.accent)
    end
    theme.lightTheme = palette.light or nil
    theme.flatGlyphs = palette.flatGlyphs or nil
    local leaf = theme.leafColor
    if palette.light then

        local function mixDark(dst, f, a)
            setColor(dst,
                leaf[1] * (1 - f) + fillC[1] * f,
                leaf[2] * (1 - f) + fillC[2] * f,
                leaf[3] * (1 - f) + fillC[3] * f, a)
        end
        mixDark(set.BTN_FILL_NORMAL, 0.30)

        mixDark(set.BTN_FILL_HOVER, 0.45)
        mixDark(set.BTN_FILL_PRESSED, 0.18)
        mixDark(set.SECTION_TABLE_FILL, 0.32, 0.92)


        setColor(set.NAV_SELECTED_FILL, fillC[1], fillC[2], fillC[3], 0.95)
        mixDark(set.NAV_HOVER_FILL, 0.45, 0.85)


        setColor(set.PANEL_CARD_FILL, fillC[1] * 0.70, fillC[2] * 0.70, fillC[3] * 0.70)
        setColor(set.EDITBOX_INSET_FILL, fillC[1] * 0.55, fillC[2] * 0.55, fillC[3] * 0.55)

        setColor(set.LINK_COLOR, 0.05, 0.28, 0.58)
        setColor(set.LINK_HOVER, 0.10, 0.40, 0.78)
        local hover = theme.pathColorHover
        setColor(set.TEXT_PRIMARY, hover[1], hover[2], hover[3])
        setColor(set.TEXT_BODY, theme.textFaint[1], theme.textFaint[2], theme.textFaint[3])
    else



        local tint = palette.controlAccent or palette.accent
        local function lift(dst, f, up, a)
            local r = fillC[1] * (1 - f) + tint[1] * f
            local g = fillC[2] * (1 - f) + tint[2] * f
            local b = fillC[3] * (1 - f) + tint[3] * f
            setColor(dst, r + (leaf[1] - r) * up, g + (leaf[2] - g) * up, b + (leaf[3] - b) * up, a)
        end
        lift(set.BTN_FILL_NORMAL, 0.30, 0.08)
        lift(set.BTN_FILL_HOVER, 0.40, 0.16)
        lift(set.BTN_FILL_PRESSED, 0.22, 0.03)


        lift(set.CONTROL_ACCENT, 0.50, 0.08)
        lift(set.NAV_SELECTED_FILL, 0.30, 0.08, 0.95)
        lift(set.NAV_HOVER_FILL, 0.15, 0.04, 0.85)
        setColor(set.SECTION_TABLE_FILL, fillC[1] * 0.85, fillC[2] * 0.85, fillC[3] * 0.85, 0.92)
        setColor(set.PANEL_CARD_FILL, fillC[1] * 0.75, fillC[2] * 0.75, fillC[3] * 0.75)
        setColor(set.EDITBOX_INSET_FILL, fillC[1] * 0.5, fillC[2] * 0.5, fillC[3] * 0.5)
        setColor(set.LINK_COLOR, 0.44, 0.84, 1.0)
        setColor(set.LINK_HOVER, 0.72, 0.94, 1.0)
        setColor(set.TEXT_PRIMARY, 1.00, 0.97, 0.86)
        setColor(set.TEXT_BODY, 0.78, 0.78, 0.80)
    end


    if palette.light then
        local controlAccent = palette.controlAccent or palette.accent
        setColor(set.CONTROL_ACCENT, controlAccent[1], controlAccent[2], controlAccent[3])
    end
end





ns.THEME_SURFACES = ns.THEME_SURFACES or {}
function ns.AddThemeSurface(id, label, opts)
    local entry
    for _, s in ipairs(ns.THEME_SURFACES) do
        if s.id == id then entry = s end
    end
    if not entry then
        entry = { id = id, label = label or id }
        ns.THEME_SURFACES[#ns.THEME_SURFACES + 1] = entry
    elseif label then
        entry.label = label
    end
    for k, v in pairs(opts or {}) do entry[k] = v end
end



local surfaceSets = {}
function ns.ThemeSet(id)
    local palette = ns.ACTIVE_UI_PALETTE
    local own = id and palette and palette.surfaces and palette.surfaces[id]
    if not own then return SharedSet() end
    local set = surfaceSets[id]
    if not set then
        set = NewSet()
        surfaceSets[id] = set
    end
    if set.gen ~= ns.uiThemeGeneration or set.palette ~= own then
        set.palette, set.gen = own, ns.uiThemeGeneration
        DeriveSet(own, set)
    end
    return set
end


function ns.ThemeSurfaceOf(frame)
    local f = frame
    while f do
        local id = f._efSurface
        if id then return id end
        f = f.GetParent and f:GetParent() or nil
    end
end

function ns.ThemeSetOf(frame)
    return ns.ThemeSet(frame and ns.ThemeSurfaceOf(frame))
end


function ns.ThemePaletteOf(frame)
    local set = ns.ThemeSetOf(frame)
    return set.palette or ns.ACTIVE_UI_PALETTE
end

function ns.ApplyUITheme(themeName, skipRepaint)
    local palette = ns.UI_THEME_PALETTES[themeName] or ns.UI_THEME_PALETTES.Black
    local modern = THEMES["Modern"]
    ns.ACTIVE_UI_PALETTE = palette



    local shared = SharedSet()
    shared.palette = palette
    DeriveSet(palette, shared)


    local classic = palette.chrome == "classic" and ns.FrameArtOn()
    modern.searchBarRounded = true
    modern.resultsBgAtlas = classic and nil or "QuestLog-main-background"


    ns.uiThemeGeneration = (ns.uiThemeGeneration or 0) + 1

    if ns.RedressSkins then ns.RedressSkins() end
    if ns.RepaintThemeFills then ns.RepaintThemeFills() end
    if ns.RepaintInputWells then ns.RepaintInputWells() end


    if ns.RestyleShownMenuPanels then
        ns.RestyleShownMenuPanels()
    end


    if not palette.chrome and ns.Search and ns.Search.UpdateWindowBorders then
        ns.Search:UpdateWindowBorders()
    end


    if ns.Utils and ns.Utils.RetintChevrons then
        ns.Utils.RetintChevrons()
    end
    if ns.RestyleModernButtons then ns.RestyleModernButtons() end
    if ns.RestyleCardFills then
        ns.RestyleCardFills()
    end


    if ns.ShadeTextEverywhere then ns.ShadeTextEverywhere() end
    if ns.RetintCogs then ns.RetintCogs() end
    if ns.RetintCloseXs then ns.RetintCloseXs() end
    if ns.RepaintFeatureTags then ns.RepaintFeatureTags() end


    if ns.FireThemeCallbacks then ns.FireThemeCallbacks() end
    if skipRepaint then return end
    if ns.Search then
        if ns.Search.UpdateFontSize then ns.Search:UpdateFontSize() end
        if ns.Search.RefreshResults then ns.Search:RefreshResults() end
    end
end






local function ApplyThemeShadow(fontString)
    local wantLight = (THEMES["Modern"].lightTheme and not ns.ClassicTreeShown()) and true or false
    if fontString._efShadowLight == wantLight then return end
    fontString._efShadowLight = wantLight
    fontString:SetShadowColor(0, 0, 0, wantLight and 0 or 1)
end

local function ScaleFont(fontString, baseFontObject)
    if not fontString then return end
    local obj = _G[baseFontObject]
    if not obj then return end
    local path, baseSize, flags = obj:GetFont()
    if ns.GetAddonFontPath then
        path = ns.GetAddonFontPath(nil, path)
    end
    local size = baseSize * (EasyFind.db.fontSize or 1.0)




    local curPath, curSize, curFlags = fontString:GetFont()
    if curPath ~= path or curSize ~= size or (curFlags or "") ~= (flags or "") then
        fontString:SetFont(path, size, flags)
    end
    ApplyThemeShadow(fontString)
end

function Results:ScaleFont(fontString, baseFontObject)
    return ScaleFont(fontString, baseFontObject)
end

function Results:SetScaledFont(fontString, baseFontObject)
    if not fontString then return end






    local db = EasyFind.db
    local font = db and db.font or "Default"
    local fontSize = db and db.fontSize or 1.0
    if fontString._efSFBase == baseFontObject and fontString._efSFFont == font
       and fontString._efSFSize == fontSize then
        return
    end
    fontString._efSFBase = baseFontObject
    fontString._efSFFont = font
    fontString._efSFSize = fontSize
    fontString:SetFontObject(baseFontObject)

    fontString._efShadowLight = nil
    ScaleFont(fontString, baseFontObject)
end






function Results:UpdateRowWash(row)
    local washR, washG, washB, washA = ns.RowHighlight()
    local wants = washR and (row._efHlLocked or row._efHlHover)
    local hl = row.hoverWash
    if not wants then
        if hl then hl:Hide() end
        return
    end
    if not hl then
        hl = CreateFrame("Frame", nil, row)



        hl:SetPoint("TOP", row, "TOP", 0, 0)
        hl:SetPoint("BOTTOM", row, "BOTTOM", 0, 0)
        local scrollChild = row:GetParent()
        hl:SetPoint("LEFT", scrollChild, "LEFT", 4, 0)


        hl:SetPoint("RIGHT", scrollChild, "RIGHT", -(ns.SCROLLBAR_EDGE_INSET + ns.SCROLLBAR_THUMB_W + 2), 0)
        hl:SetFrameLevel(row:GetFrameLevel() > 0 and row:GetFrameLevel() - 1 or 0)
        ns.CreateRoundedRectBorder(hl)


        ns.SetRoundedRectBorderShown(hl, true)
        ns.SetRoundedRectRingShown(hl, false)
        row.hoverWash = hl
    end



    local rowH = row:GetHeight() or 0
    local barH = 22
    if rowH > 0 and rowH < barH then barH = rowH end
    if hl._efBarH ~= barH then
        hl._efBarH = barH
        ns.SetRoundedRectBarHeight(hl, barH)
    end



    ns.SetRoundedRectFill(hl, washR, washG, washB, washA, true)
    hl:Show()
end



function Results:SetRowHighlightLocked(row, locked)
    row._efHlLocked = locked and true or nil
    if locked then
        if row.LockHighlight then row:LockHighlight() end
    else
        if row.UnlockHighlight then row:UnlockHighlight() end
    end
    Results:UpdateRowWash(row)
end

function Results:ApplyResultRowFonts(row, theme)
    if not row then return end
    theme = theme or Results:GetActiveTheme()


    if row.GetHighlightTexture and row._efHLGen ~= ns.uiThemeGeneration then
        row._efHLGen = ns.uiThemeGeneration
        local hlTex = row:GetHighlightTexture()
        local accent = theme.indentColors and theme.indentColors[1]
        local washActive = ns.RowWashColor() ~= nil
        if hlTex and accent then
            if washActive then




                hlTex:SetAlpha(0)
            else



                hlTex:SetAlpha(1)
                hlTex:SetBlendMode("ADD")
                hlTex:SetVertexColor(1, 1, 1, 1)
            end
        end
        if not washActive and row.hoverWash then
            row.hoverWash:Hide()
        end
    end
    ScaleFont(row.text, theme.leafFont)
    ScaleFont(row.tabText, theme.pathFont)
    ScaleFont(row.sectionLabelText, "GameFontNormalSmall")
    ScaleFont(row.pathSubtext, theme.leafFont)
    ScaleFont(row.amountText, "GameFontNormalSmall")
    ScaleFont(row.decorText, "GameFontNormalSmall")
    ScaleFont(row.calcExpressionText, "GameFontHighlightLarge")
    ScaleFont(row.calcArrowText, "GameFontHighlight")
    ScaleFont(row.calcResultText, "GameFontHighlightLarge")
    ScaleFont(row.calcExpressionHint, "GameFontDisableSmall")
    ScaleFont(row.calcResultHint, "GameFontDisableSmall")
    ScaleFont(row.repBarText, "GameFontNormalSmall")
    ScaleFont(row.settingSliderValue, "GameFontNormalSmall")
    ScaleFont(row.shortcutNumberText, "GameFontDisableSmall")
    if Shortcuts.LayoutResultShortcut then
        Shortcuts:LayoutResultShortcut(row)
    end
end
