-- The journal's own fonts (2.0.8).
--
-- The journal used the game's shared font objects (QuestFont, QuestTitleFont,
-- GameFontNormal, ...). Other addons can rewrite those for the whole UI:
-- ElvUI's "Replace Blizzard Fonts" (General > Fonts) gives them its own font
-- face, size and outline, and on the quest parchment that outline turned the
-- black quest text into an unreadable black smudge (ard, #help, Nov 2026).
--
-- So the journal now draws its text with copies that belong to it, made the
-- same way as the game's: one font per alphabet (roman, korean, simplified and
-- traditional Chinese, russian), so Cyrillic and Asian names still find their
-- glyphs. Nobody else knows these names, so no other addon changes them, and
-- with no such addon installed the journal looks exactly as before.
--
-- The values are the game's own: Blizzard_Fonts_Shared (Fonts.xml,
-- FontStyles.xml, GameFontStyles.xml) of the WoW Forever client, read from
-- https://github.com/Gethe/wow-ui-source (branch "forever").
--
-- Each copy is called "ForeverDJ_" .. the game's name, e.g. ForeverDJ_QuestFont,
-- and is used everywhere the journal used the game's one (font strings, button
-- texts). FDJ.OwnFonts(object) swaps a button or check button made from a
-- Blizzard template (UIPanelButtonTemplate, ...) over to the copies too.

local FDJ = _G.ForeverDungeonJournal_NS
if type(FDJ) ~= "table" then
    local _, ns = ...
    FDJ = ns or {}
    _G.ForeverDungeonJournal_NS = FDJ
end

local PREFIX = "ForeverDJ_"
local ALPHABETS = { "roman", "korean", "simplifiedchinese", "traditionalchinese", "russian" }

-- name = { color = { r, g, b } (nil: the font's default), shadow = { x, y, r, g, b } (nil: none),
--          <alphabet> = { file, height, flags [, spacing] } }
local FONTS = {
    QuestFont = { color = { 0, 0, 0 }, shadow = nil,
        roman = { "Fonts\\FRIZQT__.TTF", 13, "" },
        korean = { "Fonts\\2002.TTF", 13, "", 3 },
        simplifiedchinese = { "Fonts\\ARKai_T.ttf", 14, "" },
        traditionalchinese = { "Fonts\\bKAI00M.TTF", 14, "" },
        russian = { "Fonts\\FRIZQT___CYR.TTF", 13, "" } },
    QuestTitleFont = { color = { 0, 0, 0 }, shadow = { 1, -1, 0.49, 0.35, 0.05 },
        roman = { "Fonts\\MORPHEUS.ttf", 18, "" },
        korean = { "Fonts\\K_Pagetext.ttf", 17, "" },
        simplifiedchinese = { "Fonts\\ARKai_T.ttf", 17, "" },
        traditionalchinese = { "Fonts\\blei00d.ttf", 17, "" },
        russian = { "Fonts\\MORPHEUS_CYR.TTF", 18, "" } },
    QuestFontNormalSmall = { color = { 0.3, 0.18, 0 }, shadow = nil,
        roman = { "Fonts\\FRIZQT__.TTF", 12, "" },
        korean = { "Fonts\\2002.TTF", 13, "" },
        simplifiedchinese = { "Fonts\\ARKai_T.ttf", 13, "" },
        traditionalchinese = { "Fonts\\blei00d.TTF", 13, "" },
        russian = { "Fonts\\FRIZQT___CYR.TTF", 12, "" } },
    GameFontNormal = { color = { 1, 0.82, 0 }, shadow = { 1, -1, 0, 0, 0 },
        roman = { "Fonts\\FRIZQT__.TTF", 12, "" },
        korean = { "Fonts\\2002.TTF", 12, "" },
        simplifiedchinese = { "Fonts\\ARKai_T.ttf", 15, "" },
        traditionalchinese = { "Fonts\\blei00d.TTF", 15, "" },
        russian = { "Fonts\\FRIZQT___CYR.TTF", 12, "" } },
    GameFontHighlight = { color = { 1, 1, 1 }, shadow = { 1, -1, 0, 0, 0 },
        roman = { "Fonts\\FRIZQT__.TTF", 12, "" },
        korean = { "Fonts\\2002.TTF", 12, "" },
        simplifiedchinese = { "Fonts\\ARKai_T.ttf", 15, "" },
        traditionalchinese = { "Fonts\\blei00d.TTF", 15, "" },
        russian = { "Fonts\\FRIZQT___CYR.TTF", 12, "" } },
    GameFontDisable = { color = { 0.5, 0.5, 0.5 }, shadow = { 1, -1, 0, 0, 0 },
        roman = { "Fonts\\FRIZQT__.TTF", 12, "" },
        korean = { "Fonts\\2002.TTF", 12, "" },
        simplifiedchinese = { "Fonts\\ARKai_T.ttf", 15, "" },
        traditionalchinese = { "Fonts\\blei00d.TTF", 15, "" },
        russian = { "Fonts\\FRIZQT___CYR.TTF", 12, "" } },
    GameFontNormalSmall = { color = { 1, 0.82, 0 }, shadow = { 1, -1, 0, 0, 0 },
        roman = { "Fonts\\FRIZQT__.TTF", 10, "" },
        korean = { "Fonts\\2002.TTF", 11, "" },
        simplifiedchinese = { "Fonts\\ARKai_T.ttf", 15, "" },
        traditionalchinese = { "Fonts\\blei00d.TTF", 15, "" },
        russian = { "Fonts\\FRIZQT___CYR.TTF", 10, "" } },
    GameFontHighlightSmall = { color = { 1, 1, 1 }, shadow = { 1, -1, 0, 0, 0 },
        roman = { "Fonts\\FRIZQT__.TTF", 10, "" },
        korean = { "Fonts\\2002.TTF", 11, "" },
        simplifiedchinese = { "Fonts\\ARKai_T.ttf", 15, "" },
        traditionalchinese = { "Fonts\\blei00d.TTF", 15, "" },
        russian = { "Fonts\\FRIZQT___CYR.TTF", 10, "" } },
    GameFontDisableSmall = { color = { 0.5, 0.5, 0.5 }, shadow = { 1, -1, 0, 0, 0 },
        roman = { "Fonts\\FRIZQT__.TTF", 10, "" },
        korean = { "Fonts\\2002.TTF", 11, "" },
        simplifiedchinese = { "Fonts\\ARKai_T.ttf", 15, "" },
        traditionalchinese = { "Fonts\\blei00d.TTF", 15, "" },
        russian = { "Fonts\\FRIZQT___CYR.TTF", 10, "" } },
    GameFontHighlightMedium = { color = { 1, 1, 1 }, shadow = { 1, -1, 0, 0, 0 },
        roman = { "Fonts\\FRIZQT__.TTF", 14, "" },
        korean = { "Fonts\\2002.TTF", 14, "" },
        simplifiedchinese = { "Fonts\\ARKai_T.ttf", 14, "" },
        traditionalchinese = { "Fonts\\bKAI00M.TTF", 14, "" },
        russian = { "Fonts\\FRIZQT___CYR.TTF", 14, "" } },
    GameFontNormalLarge = { color = { 1, 0.82, 0 }, shadow = { 1, -1, 0, 0, 0 },
        roman = { "Fonts\\FRIZQT__.TTF", 16, "" },
        korean = { "Fonts\\2002.TTF", 14, "" },
        simplifiedchinese = { "Fonts\\ARKai_T.ttf", 17, "" },
        traditionalchinese = { "Fonts\\blei00d.TTF", 17, "" },
        russian = { "Fonts\\FRIZQT___CYR.TTF", 16, "" } },
    GameFontHighlightLarge = { color = { 1, 1, 1 }, shadow = { 1, -1, 0, 0, 0 },
        roman = { "Fonts\\FRIZQT__.TTF", 16, "" },
        korean = { "Fonts\\2002.TTF", 14, "" },
        simplifiedchinese = { "Fonts\\ARKai_T.ttf", 17, "" },
        traditionalchinese = { "Fonts\\blei00d.TTF", 17, "" },
        russian = { "Fonts\\FRIZQT___CYR.TTF", 16, "" } },
    GameFontNormalHuge = { color = { 1, 0.82, 0 }, shadow = { 1, -1, 0, 0, 0 },
        roman = { "Fonts\\FRIZQT__.TTF", 20, "" },
        korean = { "Fonts\\2002.TTF", 20, "" },
        simplifiedchinese = { "Fonts\\ARKai_T.ttf", 20, "" },
        traditionalchinese = { "Fonts\\blei00d.TTF", 20, "" },
        russian = { "Fonts\\FRIZQT___CYR.TTF", 20, "" } },
    GameFontHighlightHuge = { color = { 1, 1, 1 }, shadow = { 1, -1, 0, 0, 0 },
        roman = { "Fonts\\FRIZQT__.TTF", 20, "" },
        korean = { "Fonts\\2002.TTF", 20, "" },
        simplifiedchinese = { "Fonts\\ARKai_T.ttf", 20, "" },
        traditionalchinese = { "Fonts\\blei00d.TTF", 20, "" },
        russian = { "Fonts\\FRIZQT___CYR.TTF", 20, "" } },
    GameFontBlack = { color = { 0, 0, 0 }, shadow = nil,
        roman = { "Fonts\\FRIZQT__.TTF", 12, "" },
        korean = { "Fonts\\2002.TTF", 13, "" },
        simplifiedchinese = { "Fonts\\ARKai_T.ttf", 13, "" },
        traditionalchinese = { "Fonts\\blei00d.TTF", 13, "" },
        russian = { "Fonts\\FRIZQT___CYR.TTF", 12, "" } },
    GameFontBlackTiny = { color = { 0, 0, 0 }, shadow = nil,
        roman = { "Fonts\\FRIZQT__.TTF", 9, "" },
        korean = { "Fonts\\2002.ttf", 10, "" },
        simplifiedchinese = { "Fonts\\ARKai_T.ttf", 9, "" },
        traditionalchinese = { "Fonts\\blei00d.TTF", 9, "" },
        russian = { "Fonts\\FRIZQT___CYR.TTF", 9, "" } },
    SystemFont_Outline = { color = nil, shadow = nil,
        roman = { "Fonts\\FRIZQT__.TTF", 13, "OUTLINE" },
        korean = { "Fonts\\2002.TTF", 13, "OUTLINE" },
        simplifiedchinese = { "Fonts\\ARKai_C.ttf", 15, "OUTLINE" },
        traditionalchinese = { "Fonts\\arheiuhk_bd.TTF", 15, "OUTLINE" },
        russian = { "Fonts\\FRIZQT___CYR.TTF", 13, "OUTLINE" } },
    SystemFont_Shadow_Large_Outline = { color = nil, shadow = { 1, -1, 0, 0, 0 },
        roman = { "Fonts\\FRIZQT__.TTF", 16, "OUTLINE" },
        korean = { "Fonts\\2002.TTF", 14, "OUTLINE" },
        simplifiedchinese = { "Fonts\\ARKai_T.ttf", 17, "OUTLINE" },
        traditionalchinese = { "Fonts\\blei00d.TTF", 17, "OUTLINE" },
        russian = { "Fonts\\FRIZQT___CYR.TTF", 16, "OUTLINE" } },
    -- warnfont (2.1.1, M 20 Nov 2026: the red disclaimers were "a little bit
    -- annoying to read, especially on the steel background"; the outline
    -- "way too hard to read"; then, picked in /dj warnstyle: "I like this
    -- warn style. We can keep this"): the journal's fonts, three sizes up
    -- (the small one two), no outline, no shadow; blue (FDJ.WARNING_COLOR).
    WarningFont = { color = nil, shadow = nil,
        roman = { "Fonts\\FRIZQT__.TTF", 15, "" },
        korean = { "Fonts\\2002.TTF", 15, "" },
        simplifiedchinese = { "Fonts\\ARKai_T.ttf", 18, "" },
        traditionalchinese = { "Fonts\\blei00d.TTF", 18, "" },
        russian = { "Fonts\\FRIZQT___CYR.TTF", 15, "" } },
    WarningFontSmall = { color = nil, shadow = nil,
        roman = { "Fonts\\FRIZQT__.TTF", 13, "" },
        korean = { "Fonts\\2002.TTF", 14, "" },
        simplifiedchinese = { "Fonts\\ARKai_T.ttf", 18, "" },
        traditionalchinese = { "Fonts\\blei00d.TTF", 18, "" },
        russian = { "Fonts\\FRIZQT___CYR.TTF", 13, "" } },
    Number12FontOutline = { color = nil, shadow = nil,
        roman = { "Fonts\\ARIALN.TTF", 12, "OUTLINE" },
        korean = { "Fonts\\2002.TTF", 11, "OUTLINE" },
        simplifiedchinese = { "Fonts\\ARKai_C.TTF", 11, "OUTLINE" },
        traditionalchinese = { "Fonts\\arheiuhk_bd.TTF", 11, "OUTLINE" },
        russian = { "Fonts\\ARIALN.TTF", 12, "OUTLINE" } },
}

FDJ.OWN_FONT_PREFIX = PREFIX
FDJ.OwnFontObjects = FDJ.OwnFontObjects or {}

local function LocaleAlphabet()
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "koKR" then return "korean" end
    if locale == "zhCN" then return "simplifiedchinese" end
    if locale == "zhTW" then return "traditionalchinese" end
    if locale == "ruRU" then return "russian" end
    return "roman"
end

local function Style(font, def, spacing)
    if not font then return end
    if def.color and font.SetTextColor then
        pcall(font.SetTextColor, font, def.color[1], def.color[2], def.color[3], 1)
    end
    if font.SetShadowOffset and font.SetShadowColor then
        local s = def.shadow
        if s then
            pcall(font.SetShadowOffset, font, s[1], s[2])
            pcall(font.SetShadowColor, font, s[3], s[4], s[5], 1)
        else
            pcall(font.SetShadowOffset, font, 0, 0)
        end
    end
    if spacing and font.SetSpacing then pcall(font.SetSpacing, font, spacing) end
end

local function Make(name, def)
    local own = PREFIX .. name
    if _G[own] then return _G[own] end

    local font
    if type(CreateFontFamily) == "function" then
        local members = {}
        for _, alphabet in ipairs(ALPHABETS) do
            local m = def[alphabet]
            members[#members + 1] = { alphabet = alphabet, file = m[1], height = m[2], flags = m[3] }
        end
        local ok, made = pcall(CreateFontFamily, own, members)
        if ok and made then
            font = made
            Style(font, def)
            -- Each alphabet's member gets the same colour and shadow, and its
            -- own letter spacing (Korean quest text has 3).
            if font.GetFontObjectForAlphabet then
                for _, alphabet in ipairs(ALPHABETS) do
                    local okM, member = pcall(font.GetFontObjectForAlphabet, font, alphabet)
                    if okM and member then Style(member, def, def[alphabet][4]) end
                end
            end
        end
    end

    if not font and type(CreateFont) == "function" then
        -- Older clients without font families: one font, the client's alphabet.
        local ok, made = pcall(CreateFont, own)
        if ok and made then
            font = made
            local m = def[LocaleAlphabet()]
            pcall(font.SetFont, font, m[1], m[2], m[3])
            Style(font, def, m[4])
        end
    end

    if font then
        FDJ.OwnFontObjects[name] = font
        _G[own] = font
    end
    return font
end

for name, def in pairs(FONTS) do pcall(Make, name, def) end

-- FDJ.OwnFont("GameFontNormal") -> the journal's copy (or the game's font if
-- the copy could not be made).
function FDJ.OwnFont(name)
    return FDJ.OwnFontObjects[name] or _G[name]
end

-- warnfont: a red disclaimer's font string -> the warning font (small: the
-- small one) and the warning colour. The font strings are kept (weakly) so a
-- change of style reaches the ones on screen.
FDJ.WARNING_COLOR = FDJ.WARNING_COLOR or { 0, 0.129, 1 } -- #0021FF
FDJ.WARNING_COLOR_SMALL = FDJ.WARNING_COLOR_SMALL or { 0, 0.129, 1 }
FDJ.WarningStrings = FDJ.WarningStrings or setmetatable({}, { __mode = "k" })
function FDJ.WarningFont(fontString, small)
    if type(fontString) ~= "table" then return end
    local font = FDJ.OwnFontObjects[small and "WarningFontSmall" or "WarningFont"]
    if font and fontString.SetFontObject then pcall(fontString.SetFontObject, fontString, font) end
    local c = small and FDJ.WARNING_COLOR_SMALL or FDJ.WARNING_COLOR
    if fontString.SetTextColor then pcall(fontString.SetTextColor, fontString, c[1], c[2], c[3]) end
    FDJ.WarningStrings[fontString] = small and "small" or "normal"
end

-- The game's font object -> the journal's copy.
local byBlizzard
local function OwnFor(fontObject)
    if not fontObject then return nil end
    if not byBlizzard then
        byBlizzard = {}
        for name, own in pairs(FDJ.OwnFontObjects) do
            local blizzard = _G[name]
            if blizzard and blizzard ~= own then byBlizzard[blizzard] = own end
        end
    end
    return byBlizzard[fontObject]
end

local function Swap(object, getter, setter)
    if not (object[getter] and object[setter]) then return end
    local ok, current = pcall(object[getter], object)
    local own = ok and OwnFor(current)
    if own then pcall(object[setter], object, own) end
end

-- A button, check button, edit box or font string made from a Blizzard
-- template: its texts switch to the journal's copies of the same fonts.
function FDJ.OwnFonts(object)
    if type(object) ~= "table" then return object end
    Swap(object, "GetNormalFontObject", "SetNormalFontObject")
    Swap(object, "GetHighlightFontObject", "SetHighlightFontObject")
    Swap(object, "GetDisabledFontObject", "SetDisabledFontObject")
    Swap(object, "GetFontObject", "SetFontObject")
    for _, key in ipairs({ "Text", "text" }) do
        local fs = rawget(object, key)
        if type(fs) == "table" and fs ~= object and fs.GetFontObject then
            Swap(fs, "GetFontObject", "SetFontObject")
        end
    end
    return object
end
