local ADDON, chatNS = ...

local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not (ns and ns.Utils) or chatNS.tooOld then return end

-- The messenger's own table in the core's namespace: the search UI once
-- lived under ns.UI; the methods below are the chat's alone.
local UI = ns.UI or {}
ns.UI = UI
local Utils = ns.Utils

local CreateFrame = CreateFrame
local UIParent = UIParent
local wipe = wipe
local strtrim = strtrim
local time = time
local xpcall = xpcall
local type = type
local tostring = tostring
local pairs = pairs
local math = math
local GetCurrentKeyBoardFocus = GetCurrentKeyBoardFocus
local GetCursorPosition = GetCursorPosition
local GetTime = GetTime
local IsMouseButtonDown = IsMouseButtonDown
local IsControlKeyDown = IsControlKeyDown
local IsShiftKeyDown = IsShiftKeyDown
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local UnitGUID = UnitGUID
local UnitName = UnitName
local GetNormalizedRealmName = GetNormalizedRealmName
local C_ChatInfo = C_ChatInfo
local BNGetNumFriends = BNGetNumFriends
local BNGetFriendInfo = BNGetFriendInfo
local GetNumFriends = GetNumFriends
local GetFriendInfo = GetFriendInfo
local C_FriendList = C_FriendList
local C_BattleNet = C_BattleNet

local sfind, slower = Utils.sfind, Utils.slower
local tinsert, tconcat, tremove, tsort = Utils.tinsert, Utils.tconcat, Utils.tremove, Utils.tsort
local mmin, mmax = Utils.mmin, Utils.mmax

chatNS.UI = UI
ns.Chat = chatNS
chatNS.ICON_TEX = "Interface\\AddOns\\EasyFind_Chat\\textures\\chat-icon"

local function GetSearchFrame()
    local search = ns.Search
    return (search and search.GetSearchFrame and search:GetSearchFrame()) or _G["EasyFindSearchFrame"]
end

-- The small round buttons wear the calculator's chrome, kept in the core;
-- remembered so a theme change repaints them at rest, not only on hover.
UI._chatStyled = setmetatable({}, { __mode = "k" })
function UI:StyleCalculatorButton(btn, height)
    local calc = ns.Calculator
    if calc and calc.StyleCalculatorButton then calc:StyleCalculatorButton(btn, height) end
    UI._chatStyled[btn] = true
end

-- The longest cut at or under n bytes that ends between two characters.
local function CharBoundary(text, n)
    while n > 0 do
        local b = text:byte(n + 1)
        if not b or b < 0x80 or b >= 0xC0 then return n end
        n = n - 1
    end
    return 0
end

-- A cut inside a color code (|cAARRGGBB or |r) steps back before it.
local function EscapeBoundary(text, n)
    local bar = text:sub(1, n):match(".*()|")
    if not bar then return n end
    local code = text:sub(bar + 1, bar + 1)
    if (code == "c" and n < bar + 9) or (code == "r" and n == bar) then return bar - 1 end
    return n
end

-- The text cut with "..." to fit; fs._efFullText keeps the whole of a cut one
-- (AttachClippedTip shows it on hover).
local function SetClippedText(fs, text)
    if not fs then return end
    fs:SetText(text or "")
    fs._efFullText, fs._efSourceText = nil, text
    if not text or text == "" then return end
    local left, right = fs:GetLeft(), fs:GetRight()
    local maxW
    if left and right and right > left then
        maxW = right - left
    else
        maxW = fs:GetWidth() or 0
    end
    if not maxW or maxW <= 0 then return end
    local getW = fs.GetUnboundedStringWidth
    local strW = getW and fs:GetUnboundedStringWidth() or fs:GetStringWidth() or 0
    if strW <= maxW then return end
    -- The longest prefix that fits, found by halving, cut only between
    -- whole UTF-8 characters so a non-Latin name never ends in half a glyph.
    local lo, hi = 0, #text - 1
    while lo < hi do
        local cut = EscapeBoundary(text, CharBoundary(text, math.floor((lo + hi + 1) / 2)))
        if cut <= lo then cut = lo + 1 end
        fs:SetText(text:sub(1, cut) .. "...")
        local w = getW and fs:GetUnboundedStringWidth() or fs:GetStringWidth() or 0
        if w <= maxW then lo = cut else hi = cut - 1 end
    end
    fs:SetText(text:sub(1, EscapeBoundary(text, CharBoundary(text, lo))) .. "...")
    fs._efFullText = text
end

UI._chatComposer = {
    channel = "SAY",
    recipients = {},
    recipientLookup = {},
    friendEntries = {},
    -- Battle.net: this session's ID of a chat with no BattleTag.
    bnSessionIDs = {},
    suggestions = {},
    suggestionIndex = 1,
    showAllContacts = nil,
    CHANNELS = {
        { key = "SAY",           label = "Say",           chatType = "SAY" },
        { key = "PARTY",         label = "Party",         chatType = "PARTY" },
        { key = "RAID",          label = "Raid",          chatType = "RAID" },
        { key = "INSTANCE_CHAT", label = "Instance",      chatType = "INSTANCE_CHAT" },
        { key = "GUILD",         label = "Guild",         chatType = "GUILD" },
        { key = "YELL",          label = "Yell",          chatType = "YELL" },
        { key = "WHISPER",       label = "Whisper",       chatType = "WHISPER", needsRecipients = true },
    },
}

local CHAT_MESSAGE_MAX_CHARS = (ns and ns.CHAT_MESSAGE_MAX_CHARS) or 255
-- The client chat box's whole-text cap (ChatFrameEditBox.xml bytes="1280").
local CHAT_EDIT_MAX_BYTES = 1280
local CHAT_FONT_SCALE_STEP = 0.10
local CHAT_FONT_SCALE_MIN = 0.85
local CHAT_FONT_SCALE_MAX = 1.35
local CHAT_WINDOW_HEADER_H = 40
local CHAT_TITLE_FOLDED_H = 20
local CHAT_LOCK_TEX = "Interface\\AddOns\\EasyFind_Chat\\textures\\chat-lock"
local CHAT_UNLOCK_TEX = "Interface\\AddOns\\EasyFind_Chat\\textures\\chat-unlock"
local CHAT_PIN_TEX = "Interface\\AddOns\\EasyFind_Chat\\textures\\chat-pin"
local CHAT_CHECK_TEX = "Interface\\Buttons\\UI-CheckBox-Check"
local CHAT_MUTED_TEX = "Interface\\AddOns\\EasyFind_Chat\\textures\\chat-muted"
local CHAT_SIDEBAR_DEFAULT_W = 178
local CHAT_SIDEBAR_MIN_W = 138
local CHAT_SIDEBAR_MAX_W = 260
local CHAT_SIDEBAR_COLLAPSED_W = 34
local CHAT_ACCENT = { 1, 0.82, 0.36 }
local CHAT_OUTLINE_COLOR = { 0.36, 0.36, 0.39 }
local CHAT_SEPARATOR_COLOR = { 0.42, 0.42, 0.46 }
local CHAT_QUOTE_INSET = 8      -- the quote's bar and the gap to its words
local CHAT_DELETE_HOVER_COLOR = { 1, 0.36, 0.30 }
local CHAT_DELETE_ICON_COLOR = { 0.72, 0.72, 0.75 }
local CHAT_COUNTER_MAX_COLOR = { 1.00, 0.36, 0.30 }
local CHAT_COUNTER_WARN_COLOR = { 1.00, 0.78, 0.28 }
local CHAT_SUGGESTION_SELECTED_FILL = { 0.15, 0.15, 0.17, 0.90 }
local CHAT_RECIPIENT_PALETTE = {
    { 0.76, 0.28, 0.55 },
    { 0.86, 0.38, 0.30 },
    { 0.83, 0.55, 0.22 },
    { 0.48, 0.62, 0.26 },
    { 0.24, 0.58, 0.52 },
    { 0.25, 0.49, 0.78 },
    { 0.46, 0.38, 0.78 },
    { 0.63, 0.34, 0.72 },
}

local function ChatDB()
    EasyFindChatDB = type(EasyFindChatDB) == "table" and EasyFindChatDB or {}
    return EasyFindChatDB
end

local function GetChatRetentionSettings()
    return chatNS.Store and chatNS.Store:Settings() or nil
end

-- A light theme's palette (the window's, a studio theme's too), else nil.
-- Every light color is mixed from it, so each light theme gets the look in
-- its own colors and none needs fixing alone (2026-10-27: no grays, no
-- white boxes).
local function ChatLight()
    local frame = UI._chatComposer and UI._chatComposer.frame
    local p = (ns.ThemePaletteOf and frame and ns.ThemePaletteOf(frame)) or ns.ACTIVE_UI_PALETTE
    return (p and p.light and p.windowFill and p.accent) and p or nil
end

local function MixRGB(a, b, t)
    return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
end

-- A color (a class's, a link's) on a light theme's tint: its hue kept and
-- its saturation lifted a little, darkened only as far as it must to read
-- there (3:1); one that reads already stays as the game paints it. No hue
-- (priest white, a gray item): nil, the caller's navy. A flat x0.55 had
-- dragged every class to the same mud (2026-10-27).
local ChatInk
do
    local CONTRAST = 3
    local function Lin(c) return c <= 0.03928 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
    local function Luma(r, g, b) return 0.2126 * Lin(r) + 0.7152 * Lin(g) + 0.0722 * Lin(b) end
    local function ToHSL(r, g, b)
        local hi, lo = math.max(r, g, b), math.min(r, g, b)
        local l, d = (hi + lo) / 2, hi - lo
        if d < 1e-6 then return 0, 0, l end
        local s = l > 0.5 and d / (2 - hi - lo) or d / (hi + lo)
        local h
        if hi == r then h = (g - b) / d % 6 elseif hi == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
        return h / 6, s, l
    end
    local function FromHSL(h, s, l)
        local q = l < 0.5 and l * (1 + s) or l + s - l * s
        local p = 2 * l - q
        local function Part(x)
            x = x % 1
            if x < 1 / 6 then return p + (q - p) * 6 * x end
            if x < 1 / 2 then return q end
            if x < 2 / 3 then return p + (q - p) * (2 / 3 - x) * 6 end
            return p
        end
        return Part(h + 1 / 3), Part(h), Part(h - 1 / 3)
    end
    local memo = {}
    function ChatInk(r, g, b, bgR, bgG, bgB)
        local key = string.format("%.3f%.3f%.3f/%.3f%.3f%.3f", r, g, b, bgR, bgG, bgB)
        local hit = memo[key]
        if hit then return hit[1], hit[2], hit[3] end
        local bgL = Luma(bgR, bgG, bgB) + 0.05
        local function Reads(cr, cg, cb) return bgL / (Luma(cr, cg, cb) + 0.05) >= CONTRAST end
        local out
        if Reads(r, g, b) then
            out = { r, g, b }
        else
            local h, s, l = ToHSL(r, g, b)
            if s >= 0.12 then
                s = math.min(1, s * 1.15)
                local lo, hi = 0, l
                for _ = 1, 14 do
                    local mid = (lo + hi) / 2
                    if Reads(FromHSL(h, s, mid)) then lo = mid else hi = mid end
                end
                out = { FromHSL(h, s, lo) }
            else
                out = false
            end
        end
        memo[key] = out
        if out then return out[1], out[2], out[3] end
        return nil
    end
end

-- Theme leaf on dark fills, the darker hover accent on light fills, like
-- ns.TooltipTextColor; the fallback matches the old hardcoded gray.
local function ChatTextColor()
    local theme = ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
    if theme and theme.lightTheme then
        local c = theme.pathColorHover or theme.leafColor
        if c then return c[1], c[2], c[3] end
    end
    local c = theme and theme.leafColor
    if c then return c[1], c[2], c[3] end
    return 0.92, 0.92, 0.94
end

local chatThemedTexts = {}
local chatInputShells = {}

local function PaintChatThemedText(fs)
    local r, g, b = ChatTextColor()
    local a = fs._chatTextAlpha or 1
    local light = ChatLight()
    if light then
        -- Light: words on the accent white; glyphs and dim words in the
        -- theme's faint ink at full strength (the cog read too dark).
        if fs._chatOnAccent then
            r, g, b, a = 1, 1, 1, 1
        elseif light.textFaint and (not fs.SetTextColor or a < 1) then
            local c = light.textFaint
            r, g, b, a = c[1], c[2], c[3], 1
        end
    elseif fs._chatInput then
        r, g, b, a = 0.96, 0.96, 0.96, 1
    end
    -- Glyph textures (the window lock, its grip) take the same ink.
    if fs.SetTextColor then
        fs:SetTextColor(r, g, b, a)
    else
        fs:SetVertexColor(r, g, b, a)
    end
end

-- A glyph's button lights it on hover on a light theme: the leaf color.
local glyphHover = setmetatable({}, { __mode = "k" })
local function HookGlyphHover(glyph)
    local button = glyph.GetParent and glyph:GetParent()
    if not (button and button.HookScript and button.GetObjectType and button:GetObjectType() == "Button") then return end
    if not glyphHover[button] then
        glyphHover[button] = {}
        -- A frame later: the build sets the button's own OnEnter after its
        -- glyph, and a SetScript drops a hook made before it.
        C_Timer.After(0, function()
            button:HookScript("OnEnter", function(self)
                local light = ChatLight()
                local c = light and light.leafColor
                if not c then return end
                for g in pairs(glyphHover[self]) do g:SetVertexColor(c[1], c[2], c[3], 1) end
            end)
            button:HookScript("OnLeave", function(self)
                for g in pairs(glyphHover[self]) do PaintChatThemedText(g) end
            end)
        end)
    end
    glyphHover[button][glyph] = true
end

local function RegisterChatThemedText(fs, alpha)
    fs._efOwnColor = true
    fs._chatTextAlpha = alpha
    chatThemedTexts[#chatThemedTexts + 1] = fs
    PaintChatThemedText(fs)
    if not fs.SetTextColor then HookGlyphHover(fs) end
end
chatNS.RegisterThemedText = RegisterChatThemedText
chatNS.TextColor = ChatTextColor

-- A cog says settings by itself: no tooltip, a glow on the cog on hover.
local function AddCogGlow(button, size)
    local glow = button:CreateTexture(nil, "HIGHLIGHT")
    if not (ns.COG_ICON_TEX and glow:SetTexture(ns.COG_ICON_TEX)) then
        glow:SetAtlas("QuestLog-icon-setting", false)
        glow:SetDesaturated(true)
    end
    glow:SetSize(size, size)
    glow:SetPoint("CENTER")
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.7)
end

-- A chat's own icon over its letter (Avatars.lua).
local function PaintAvatar(bg, letter, convo)
    local avatars = chatNS.Avatars
    if avatars then avatars:Paint(bg, letter, convo) else letter:Show() end
end

-- Chrome tints derive from the ACTIVE palette's own windowFill/accent at
-- paint time, so every surface carries the theme hue on every theme. The
-- shared slot tables (PANEL_CARD_FILL, EDITBOX_INSET_FILL, ...) are fixed
-- near-blacks on dark themes and only palette-derived on light ones --
-- routing through them painted flat black chrome onto a galaxy-blue window.
local CHAT_SURFACES = {
    sidebar  = { mul = 0.55 },
    inset    = { mul = 0.38 },
    row      = { mul = 0.85, add = 0.02 },
    bubbleIn = { mul = 1.00, add = 0.08 },
    chip     = { mul = 1.20, add = 0.06 },
}

local CHAT_LIGHT_TINTS = { sidebar = 0.16, row = 0.16, bubbleIn = 0.22, chip = 0.22 }
local function ChatSurfaceColor(kind)
    local light = ChatLight()
    if light then
        if kind == "inset" then return MixRGB(light.windowFillTop or light.windowFill, { 1, 1, 1 }, 0.6) end
        return MixRGB(light.windowFill, light.accent, CHAT_LIGHT_TINTS[kind] or 0.3)
    end
    local theme = ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
    if theme and theme.lightTheme then
        -- Light themes: the live slots are already palette-derived.
        local slot
        if kind == "sidebar" or kind == "bubbleIn" then slot = ns.PANEL_CARD_FILL
        elseif kind == "inset" then slot = ns.EDITBOX_INSET_FILL
        else slot = ns.BTN_FILL_PRESSED end
        if slot then return slot[1], slot[2], slot[3] end
    end
    local pal = ns.ACTIVE_UI_PALETTE
    local base = pal and pal.windowFill or { 0.06, 0.06, 0.07 }
    local s = CHAT_SURFACES[kind] or CHAT_SURFACES.row
    local mul, add = s.mul, s.add or 0
    return mmin(base[1] * mul + add, 1), mmin(base[2] * mul + add, 1),
        mmin(base[3] * mul + add, 1)
end

-- Accent surfaces (selected conversation, outgoing bubble): the theme's own
-- accent driven dark enough to carry light text; light themes keep the
-- inverted NAV pill slot.
local function ChatAccentColor()
    local light = ChatLight()
    if light then return MixRGB(light.windowFill, light.accent, 0.48) end
    local theme = ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
    if theme and theme.lightTheme then
        local c = ns.NAV_SELECTED_FILL
        if c then return c[1], c[2], c[3] end
    end
    local pal = ns.ACTIVE_UI_PALETTE
    local accent = pal and pal.accent or { 0.25, 0.50, 0.90 }
    return accent[1] * 0.42, accent[2] * 0.42, accent[3] * 0.42
end

-- Interactive accents (drag line, resize arrows, hover tints, selected
-- suggestion text) wear the theme accent at full strength; light themes
-- take the darker hover text color so the accent stays visible.
local function ChatAccentGlyphColor()
    local theme = ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
    if theme and theme.lightTheme then
        local c = theme.pathColorHover or theme.leafColor
        if c then return c[1], c[2], c[3] end
    end
    local pal = ns.ACTIVE_UI_PALETTE
    local accent = pal and pal.accent
    if accent then return accent[1], accent[2], accent[3] end
    return CHAT_ACCENT[1], CHAT_ACCENT[2], CHAT_ACCENT[3]
end

-- Over a Classic tree the chat wears Notes' cards: the side panel clear,
-- chats and their bubbles a dark wash, a bubble pale under the mouse.
local CHAT_TREE_WASH = { sidebar = 0, row = 0.55, bubbleIn = 0.55 }
local CHAT_TREE_HOVER = { 0.34, 0.34, 0.34, 0.65 }
local function ChatOnTree()
    return ns.ClassicTreeShown and ns.ClassicTreeShown() or false
end

local function PaintChatSurface(frame, kind, alpha)
    local wash = CHAT_TREE_WASH[kind]
    if wash and ChatOnTree() then
        ns.SetRoundedRectFill(frame, 0, 0, 0, wash, true)
        return
    end
    local r, g, b = ChatSurfaceColor(kind)
    ns.SetRoundedRectFill(frame, r, g, b, alpha or 1, true)
end

local function PaintChatAccentSurface(frame, alpha)
    local r, g, b = ChatAccentColor()
    ns.SetRoundedRectFill(frame, r, g, b, alpha or 1, true)
end

local function PaintChatInputSurface(shell)
    local r, g, b = ChatSurfaceColor("inset")
    if shell.ringInset then
        local pal = ns.ACTIVE_UI_PALETTE
        local line = pal and pal.separator or CHAT_OUTLINE_COLOR
        local ring = (ChatLight() and pal and pal.borderColor) or { line[1], line[2], line[3], 0.7 }
        ns.PaintRingedWell(shell, ring, { r, g, b, 1 })
        return
    end
    ns.SetRoundedRectFill(shell, r, g, b, shell._chatFillAlpha or 1, true)
end

local function PaintChatInputHover(shell)
    local r, g, b = ChatSurfaceColor("inset")
    ns.SetRoundedRectFill(shell, mmin(r + 0.05, 1), mmin(g + 0.05, 1),
        mmin(b + 0.06, 1), 1, true)
end

-- A bubble's words show in the plain line they were measured with, the
-- sender in class colors. The copy box over it holds the same words plain
-- (a copy comes out clean) in the same font and width and stays clear, so a
-- click changes nothing and a selection's gray lands on the words shown.
local function ShowBubbleWords(row)
    local r, g, b = row.linkText:GetTextColor()
    row.copyBox:SetTextColor(r, g, b, 0)
    row.linkText:Show()
end

local function LightChatTheme()
    local theme = ns.Results and ns.Results.GetActiveTheme and ns.Results:GetActiveTheme()
    return theme and theme.lightTheme and theme or nil
end

-- A bubble's fill: ours the accent, theirs the incoming surface (on a
-- light theme the window's fill toward its accent, ours deeper).
-- A message that names you: the incoming bubble warmed toward gold.
local CHAT_MENTION_TINT = { 0.95, 0.74, 0.22 }

local function ChatBubbleColor(paint)
    if paint == "mention" then return MixRGB({ ChatSurfaceColor("bubbleIn") }, CHAT_MENTION_TINT, 0.3) end
    if paint ~= "accent" then return ChatSurfaceColor("bubbleIn") end
    return ChatAccentColor()
end

-- Over the row where it shows: one cut by the list's edge reads a cursor
-- past that edge as over it, and kept its hover lit.
local function ChatRowHovered(row)
    return row:IsMouseOver() and not (row.list and not row.list:IsMouseOver())
end

-- A bubble at rest wears its own fill; under the cursor a step lighter,
-- the same lift the input takes, since a bubble answers a right-click.
local function PaintChatRowRest(row)
    if row._chatPaint == "bubbleIn" and ChatOnTree() then
        ns.SetRoundedRectFill(row, 0, 0, 0, CHAT_TREE_WASH.bubbleIn, true)
    else
        local r, g, b = ChatBubbleColor(row._chatPaint)
        ns.SetRoundedRectFill(row, r, g, b, 0.96, true)
    end
    if row._timeOnHover and row.time then row.time:Hide() end
end

-- Under the cursor a step off: lighter on a dark theme, darker on a light one.
local function PaintChatRowHover(row)
    local r, g, b = ChatBubbleColor(row._chatPaint)
    if row._chatPaint == "bubbleIn" and ChatOnTree() then
        local c = CHAT_TREE_HOVER
        ns.SetRoundedRectFill(row, c[1], c[2], c[3], c[4], true)
    elseif LightChatTheme() then
        ns.SetRoundedRectFill(row, mmax(r - 0.05, 0), mmax(g - 0.05, 0), mmax(b - 0.04, 0), 1, true)
    else
        ns.SetRoundedRectFill(row, mmin(r + 0.05, 1), mmin(g + 0.05, 1), mmin(b + 0.06, 1), 1, true)
    end
    if row._timeOnHover and row.time then row.time:Show() end
end

local function PaintChatSuggestionSelection(bg)
    local washR, washG, washB = ns.RowWashColor()
    if washR then
        ns.SetRoundedRectFill(bg, washR, washG, washB, ns.RowWashAlpha(), true)
    else
        ns.SetRoundedRectFill(bg, CHAT_SUGGESTION_SELECTED_FILL[1], CHAT_SUGGESTION_SELECTED_FILL[2],
            CHAT_SUGGESTION_SELECTED_FILL[3], CHAT_SUGGESTION_SELECTED_FILL[4], true)
    end
end

local function ShowChatTipDelayed(region, anchor, text)
    if not (region and text) then return end
    region._tipToken = (region._tipToken or 0) + 1
    local token = region._tipToken
    Utils.SafeAfter(ns.TOOLTIP_HOVER_DELAY or 0.4, function()
        if region._tipToken ~= token then return end
        if not (region:IsShown() and region:IsMouseOver()) then return end
        ns.ShowHintTooltip(region, anchor or "ANCHOR_TOP", nil, text)
    end)
end

local function HideChatTip(region)
    if region then region._tipToken = (region._tipToken or 0) + 1 end
    ns.HideHintTooltip()
end

-- A name cut short with "..." shows whole on hover. The hover box takes no
-- clicks: the title bar under it still drags the window.
local function AttachClippedTip(fs, parent, level)
    local tip = CreateFrame("Frame", nil, parent)
    tip:SetAllPoints(fs)
    tip:SetFrameLevel(level)
    if tip.SetMouseClickEnabled then
        tip:SetMouseMotionEnabled(true)
        tip:SetMouseClickEnabled(false)
    end
    tip:SetScript("OnEnter", function(self)
        if fs:IsVisible() and fs._efFullText then ShowChatTipDelayed(self, "ANCHOR_BOTTOM", fs._efFullText) end
    end)
    tip:SetScript("OnLeave", HideChatTip)
    return tip
end

-- A frame and all it holds moved to a level, each child one above its parent.
local function RaiseChatFrameTree(frame, level)
    frame:SetFrameLevel(level)
    for i = 1, select("#", frame:GetChildren()) do
        RaiseChatFrameTree(select(i, frame:GetChildren()), level + 1)
    end
end

local function CompareChatFriendEntries(a, b)
    if (a.priority or 9) ~= (b.priority or 9) then
        return (a.priority or 9) < (b.priority or 9)
    end
    return slower(a.label or "") < slower(b.label or "")
end

local function CompareChatSuggestions(a, b)
    if a._chatSuggestScore ~= b._chatSuggestScore then
        return a._chatSuggestScore < b._chatSuggestScore
    end
    return slower(a.label or "") < slower(b.label or "")
end

local function CompareChatMessagesByTime(a, b)
    return (a.time or 0) < (b.time or 0)
end

local chatOrderSortStore
local function CompareChatOrderRecency(a, b)
    local ca, cb = chatOrderSortStore.byKey[a], chatOrderSortStore.byKey[b]
    return ((ca and ca.lastTime) or 0) > ((cb and cb.lastTime) or 0)
end

-- Messenger-sent messages record at dispatch (keeping forward metadata the
-- echo events lack); the server's echo of that same send must NOT record a
-- second copy. Marks pair with echoes by text, counted, with a short
-- expiry -- external sends (typed in the default chat box) carry no mark
-- and still record from their echo.
local echoSuppress = {}

local function MarkOwnEcho(text)
    local mark = echoSuppress[text]
    if mark then
        mark.count = mark.count + 1
        mark.at = GetTime()
    else
        echoSuppress[text] = { count = 1, at = GetTime() }
    end
end

local function ConsumeOwnEcho(text)
    local mark = echoSuppress[text]
    if not mark then return false end
    if GetTime() - mark.at > 6 then
        echoSuppress[text] = nil
        return false
    end
    mark.count = mark.count - 1
    if mark.count <= 0 then echoSuppress[text] = nil end
    return true
end

local function ChatRecipientEntrySent(entry)
    MarkOwnEcho(entry.text)
    UI:AddChatConversationForRecipient(entry.efRecipient, entry.text, true, entry.efMeta)
end

local function ChatChannelEntrySent(entry)
    MarkOwnEcho(entry.text)
    UI:AddChatConversationForChannel(entry.efChannelDef, entry.text, true, entry.efMeta)
end

local function ChatReplyEntrySent(entry)
    MarkOwnEcho(entry.text)
    local convo = entry.efConvo
    UI:AddChatConversationMessage(entry.efConvoKey, convo.label, convo.kind, entry.text, true,
        convo.source, nil, entry.efMeta)
end

local function ChatComposeBNEntrySent(entry)
    MarkOwnEcho(entry.text)
    UI:RecordChatBNWhisper(entry.text, entry.presenceID, entry.efLabel, true, nil)
end

local function ChatComposePlayerEntrySent(entry)
    MarkOwnEcho(entry.text)
    UI:RecordChatPlayerWhisper(entry.text, entry.target, true, nil)
end

-- Sending chat is not protected, in combat too: a line goes out at once
-- through the calls the client's own chat box makes.
local function DispatchChatEntry(entry)
    if entry.kind == "bn" then
        if not (entry.presenceID and C_BattleNet and C_BattleNet.SendWhisper) then return false end
        return (pcall(C_BattleNet.SendWhisper, entry.presenceID, entry.text))
    end
    if not (C_ChatInfo and C_ChatInfo.SendChatMessage) then return false end
    return (pcall(C_ChatInfo.SendChatMessage, entry.text, entry.channel, entry.language, entry.target))
end

-- True when the line went out. It is recorded in entry.onSent, so history
-- never claims a message that was not sent.
local function SendChatEntry(entry)
    if type(entry) ~= "table" or not entry.text or entry.text == "" then return false end
    if not DispatchChatEntry(entry) then return false end
    if entry.onSent then xpcall(entry.onSent, geterrorhandler(), entry) end
    return true
end

local function ChatSidebarResizeOnUpdate(handle)
    UI:UpdateChatSidebarResize(handle)
end

-- The window's border (Extensions > Chat): the theme's own frame art
-- where it has one (the default), the line, or none.
function UI:GetChatWindowBorder()
    local pick = ChatDB().windowBorder
    if pick then return pick end
    return ns.ThemeHasChrome and ns.ThemeHasChrome() and "iron" or "off"
end

function UI:ApplyChatWindowLook()
    local frame = UI._chatComposer.frame
    if not frame then return end
    local art = ChatDB().windowBorder == nil
    frame._efForeverSurface, frame._efClassicSurface = art or nil, art or nil
    frame._efSkinOff = (not art) or nil
    ns.ApplyThemeFill(frame)
    local dressed = frame._efSkin ~= nil
    ns.SetRoundedRectRingShown(frame, ChatDB().windowBorder == "line" and not dressed)
    ns.SetRoundedRectBarHeight(frame, dressed and 2 or 16)
end

-- Send on a light theme: the accent, solid, a step lighter under the
-- mouse. Dark themes keep the button fill.
function UI:PaintChatSendButton(button, hovered)
    local light = ChatLight()
    if not light then return end
    local a, k = light.accent, hovered and 0.12 or 0
    ns.SetRoundedRectFill(button, a[1] + (1 - a[1]) * k, a[2] + (1 - a[2]) * k, a[3] + (1 - a[3]) * k, 1, true)
end

local function RefreshChatTheme()
    local frame = UI._chatComposer.frame
    if not frame then return end
    UI:ApplyChatWindowLook()
    local calc = ns.Calculator
    if calc and calc.ThemeFillCalcControl then
        for btn in pairs(UI._chatStyled) do
            if not btn:IsMouseOver() then calc:ThemeFillCalcControl(btn, ns.BTN_FILL_NORMAL, 0.095, 0.095, 0.108) end
        end
    end
    for i = 1, #chatInputShells do
        PaintChatInputSurface(chatInputShells[i])
    end
    for i = 1, #chatThemedTexts do
        PaintChatThemedText(chatThemedTexts[i])
    end
    local view = frame.messengerView
    if view and view.replyButton then
        UI:PaintChatSendButton(view.replyButton, view.replyButton:IsMouseOver())
        if view.replyCounter then view.replyCounter:SetAlpha(ChatLight() and 1 or 0.82) end
    end
    ns.RetintMenuSeparators(frame)
    UI:RefreshChatSuggestionSelection()
    -- Palette-derived chrome (sidebar, accent glyphs) repaints directly;
    -- rows and bubbles repaint through the messenger refresh, which
    -- re-derives their fills.
    if view and view.sidebar then
        PaintChatSurface(view.sidebar, "sidebar", 1)
    end
    if view and view.sidebarResizeHandle and view.sidebarResizeHandle.line then
        view.sidebarResizeHandle.line:SetVertexColor(ChatAccentGlyphColor())
    end
    local cursor = UI._chatComposer.sidebarResizeCursor
    if cursor then
        cursor.leftArrow:SetVertexColor(ChatAccentGlyphColor())
        cursor.rightArrow:SetVertexColor(ChatAccentGlyphColor())
    end
    UI:RefreshChatMessenger()
end

function UI:GetChatFontScale()
    local c = UI._chatComposer
    if type(c.fontScale) ~= "number" then
        local dbScale = ChatDB().fontScale
        c.fontScale = type(dbScale) == "number" and dbScale or 1
    end
    if c.fontScale < CHAT_FONT_SCALE_MIN then c.fontScale = CHAT_FONT_SCALE_MIN end
    if c.fontScale > CHAT_FONT_SCALE_MAX then c.fontScale = CHAT_FONT_SCALE_MAX end
    return c.fontScale
end

function UI:RegisterChatFontRegion(region)
    if not (region and region.GetFont and region.SetFont) then return end
    if region._easyFindChatFontBase then return end

    local font, size, flags = region:GetFont()
    if not (font and size) then return end

    region._easyFindChatFontBase = { font = font, size = size, flags = flags }
    local c = UI._chatComposer
    c.fontRegions = c.fontRegions or {}
    c.fontRegions[#c.fontRegions + 1] = region
    self:ApplyChatFontRegion(region)
end

function UI:RegisterChatFrameFonts(frame)
    if not frame then return end
    self:RegisterChatFontRegion(frame)

    -- An edit box's words line follows the box: registered on its own it
    -- took the scale twice (16 under a box at 13).
    local editBox = frame.GetObjectType and frame:GetObjectType() == "EditBox"
    if frame.GetRegions and not editBox then
        for i = 1, select("#", frame:GetRegions()) do
            self:RegisterChatFontRegion(select(i, frame:GetRegions()))
        end
    end

    if frame.GetChildren then
        for i = 1, select("#", frame:GetChildren()) do
            self:RegisterChatFrameFonts(select(i, frame:GetChildren()))
        end
    end
end

-- The chat's typeface (Extensions > Chat): its own pick, else EasyFind's.
local function ChatFontPath(fallback)
    local pick = ChatDB().font
    if pick == "Default" then return fallback end
    if pick then return ns.GetFontChoicePath and ns.GetFontChoicePath(pick) or fallback end
    return ns.GetAddonFontPath and ns.GetAddonFontPath("regular", fallback) or fallback
end

-- The header's own size; until set, it follows Text size.
function UI:GetChatHeaderFontScale()
    local scale = ChatDB().headerFontScale
    if type(scale) ~= "number" then return self:GetChatFontScale() end
    return mmax(CHAT_FONT_SCALE_MIN, mmin(CHAT_FONT_SCALE_MAX, scale))
end

function UI:SetChatHeaderFontScale(scale)
    scale = math.floor(mmax(CHAT_FONT_SCALE_MIN, mmin(CHAT_FONT_SCALE_MAX, scale)) * 100 + 0.5) / 100
    if math.abs(scale - self:GetChatHeaderFontScale()) < 0.001 and ChatDB().headerFontScale then return end
    ChatDB().headerFontScale = scale
    self:ApplyChatFontScale()
end

function UI:ApplyChatFontRegion(region)
    local base = region and region._easyFindChatFontBase
    if not base then return end
    -- In whole percents: 1.05 * 10 is 10.4999 in floats, and rounded down
    -- the bubbles kept their size while the bigger text grew.
    local scale = region._efChatHeaderFont and self:GetChatHeaderFontScale() or self:GetChatFontScale()
    local percent = math.floor(scale * 100 + 0.5)
    local size = math.floor((base.size * percent + 50) / 100 + 1e-6)
    if size < 8 then size = 8 end
    if not region:SetFont(ChatFontPath(base.font), size, base.flags) then
        region:SetFont(base.font, size, base.flags)
    end
end

function UI:ApplyChatFontScale()
    self:ForgetChatMeasures()
    if chatNS.Views then chatNS.Views:RefontCombatLog() end
    local regions = UI._chatComposer.fontRegions
    if regions then
        for i = 1, #regions do
            self:ApplyChatFontRegion(regions[i])
        end
    end
    self:LayoutChatComposer()
    self:RefreshChatComposerRecipients()
    self:RefreshChatRecipientSuggestions()
    self:LayoutChatMessengerChrome()
    self:RefreshChatMessenger()
    -- The options page's numbers follow Ctrl and + or -.
    local sizeRow = UI._chatComposer.textSizeRow
    if sizeRow then sizeRow:SetValue(math.floor(self:GetChatFontScale() * 100 + 0.5)) end
    local headerRow = UI._chatComposer.headerSizeRow
    if headerRow then headerRow:SetValue(math.floor(self:GetChatHeaderFontScale() * 100 + 0.5)) end
end

function UI:SetChatFontScale(scale)
    scale = math.floor(mmax(CHAT_FONT_SCALE_MIN, mmin(CHAT_FONT_SCALE_MAX, scale)) * 100 + 0.5) / 100
    if math.abs(scale - self:GetChatFontScale()) < 0.001 then return end
    UI._chatComposer.fontScale = scale
    ChatDB().fontScale = scale
    self:ApplyChatFontScale()
end

function UI:AdjustChatFontScale(delta)
    self:SetChatFontScale(self:GetChatFontScale() + (delta or 0) * CHAT_FONT_SCALE_STEP)
    return true
end

function UI:HandleChatFontScaleKey(owner, key)
    if not (IsControlKeyDown and IsControlKeyDown()) then return false end
    key = tostring(key or ""):upper()
    if key == "+" or key == "=" or key == "NUMPADPLUS" or key == "PLUS" then
        self:AdjustChatFontScale(1)
        Utils.SafeCallMethod(owner, "SetPropagateKeyboardInput", false)
        return true
    elseif key == "-" or key == "_" or key == "NUMPADMINUS" or key == "MINUS" then
        self:AdjustChatFontScale(-1)
        Utils.SafeCallMethod(owner, "SetPropagateKeyboardInput", false)
        return true
    end
    return false
end

-- Ctrl and + or - with no box of ours focused: while Ctrl is held over
-- the window (out of combat) a hidden box takes the focus, as Ctrl+C on a
-- bubble does. Any other key, Ctrl let go, Escape or combat: it lets go.
function UI:InstallChatKeyCatcher(frame)
    local catcher = CreateFrame("EditBox", nil, frame)
    catcher:SetAutoFocus(false)
    catcher:EnableMouse(false)
    catcher:SetSize(1, 1)
    catcher:SetPoint("TOPLEFT")
    catcher:SetAlpha(0)
    local function Release()
        catcher:SetScript("OnUpdate", nil)
        if catcher:HasFocus() then catcher:ClearFocus() end
    end
    -- Ctrl let go while another box held the focus never reaches the keys
    -- below, and a focus handed back after it must not stay.
    local function Watch()
        if not IsControlKeyDown() or InCombatLockdown() then Release() end
    end
    catcher:SetScript("OnEditFocusGained", function()
        if not IsControlKeyDown() or InCombatLockdown() then
            Release()
            return
        end
        catcher:SetScript("OnUpdate", Watch)
    end)
    catcher:SetScript("OnEditFocusLost", function() catcher:SetScript("OnUpdate", nil) end)
    Utils.ReleaseFocusOnOutsideClick(catcher)
    catcher:SetScript("OnKeyDown", function(self, key)
        if key == "LCTRL" or key == "RCTRL" or UI:HandleChatFontScaleKey(self, key) then return end
        UI:HandleChatFindKey(self, key)
        Release()
    end)
    catcher:SetScript("OnKeyUp", function(_, key)
        if key == "LCTRL" or key == "RCTRL" then Release() end
    end)
    catcher:SetScript("OnEscapePressed", Release)
    catcher:SetScript("OnEvent", function(_, event, key, state)
        if event == "PLAYER_REGEN_DISABLED" then
            Release()
        elseif (key == "LCTRL" or key == "RCTRL") and state == 1 and not InCombatLockdown()
                and frame:IsMouseOver() and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()) then
            catcher:SetFocus()
        end
    end)
    local function Listen()
        catcher:RegisterEvent("MODIFIER_STATE_CHANGED")
        catcher:RegisterEvent("PLAYER_REGEN_DISABLED")
    end
    frame:HookScript("OnShow", Listen)
    frame:HookScript("OnHide", function()
        catcher:UnregisterAllEvents()
        Release()
    end)
    if frame:IsShown() then Listen() end
    -- Ctrl held over a bubble arms the copy box, which then has the keys.
    if ns.RowCopy and ns.RowCopy.RegisterKeyHandler then
        ns.RowCopy:RegisterKeyHandler(function(key)
            return frame:IsVisible() and frame:IsMouseOver() and UI:HandleChatFontScaleKey(nil, key) or false
        end)
    end
end

function UI:HandleChatFontScaleWheel(owner, delta)
    if not (IsControlKeyDown and IsControlKeyDown()) then return false end
    if not delta or delta == 0 then return false end

    self:AdjustChatFontScale(delta > 0 and 1 or -1)
    return true
end

function UI:InstallChatFontScaleWheel(frame)
    if not frame or frame._easyFindChatWheelInstalled then return end
    local original = frame.GetScript and frame:GetScript("OnMouseWheel")
    if frame.EnableMouseWheel then frame:EnableMouseWheel(true) end
    frame:SetScript("OnMouseWheel", function(self, delta)
        if UI:HandleChatFontScaleWheel(self, delta) then return end
        if original then original(self, delta) end
    end)
    frame._easyFindChatWheelInstalled = true
end

function UI:HandleChatClipboardKey(owner, key)
    if not (IsControlKeyDown and IsControlKeyDown()) then return false end
    key = tostring(key or ""):upper()
    if key ~= "C" then return false end

    Utils.SafeCallMethod(owner, "SetPropagateKeyboardInput", false)
    return true
end

-- Ctrl+C over a message copies it whole, through the search bar's copy
-- (RowCopy): Ctrl-down on a focused box of ours arms it (the game reports
-- no Ctrl edge while a box has focus), the hover scan finds the bubble.
function UI:ArmChatHoveredCopy(box, key)
    if (key == "LCTRL" or key == "RCTRL") and box:HasFocus() and ns.RowCopy and ns.RowCopy.ArmHovered then
        ns.RowCopy:ArmHovered()
    end
end

-- The bubble under the mouse, unless its own text has the focus (a part of
-- it selected copies just that, natively).
function UI:GetChatHoveredMessageRow()
    local frame = UI._chatComposer.frame
    local view = frame and frame:IsVisible() and frame.messengerView
    if not (view and view.messageRows) then return nil end
    local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    local head = view.headerNameTarget
    if head and head:IsVisible() and head._efCopyText and head:IsMouseOver() then return head end
    for i = 1, #view.messageRows do
        local row = view.messageRows[i]
        if row:IsShown() and row.message and row._efCopyText and ChatRowHovered(row) then
            if focus == row.copyBox then return nil end
            local name = row.nameTarget
            if name and name:IsShown() and name._efCopyText and name:IsMouseOver() then return name end
            return row
        end
    end
    return nil
end

function UI:GetChatFontLineHeight(region, fallback)
    local size = fallback or 12
    if region and region.GetFont then
        local _, fontSize = region:GetFont()
        if fontSize then size = fontSize end
    end
    return mmax(10, math.floor(size + 3.5))
end

local CHAT_EVENT_CHANNELS = {
    CHAT_MSG_SAY = { key = "SAY", label = "Say" },
    CHAT_MSG_YELL = { key = "YELL", label = "Yell" },
    CHAT_MSG_PARTY = { key = "PARTY", label = "Party" },
    CHAT_MSG_PARTY_LEADER = { key = "PARTY", label = "Party" },
    CHAT_MSG_RAID = { key = "RAID", label = "Raid" },
    CHAT_MSG_RAID_LEADER = { key = "RAID", label = "Raid" },
    CHAT_MSG_RAID_WARNING = { key = "RAID", label = "Raid" },
    CHAT_MSG_INSTANCE_CHAT = { key = "INSTANCE_CHAT", label = "Instance" },
    CHAT_MSG_INSTANCE_CHAT_LEADER = { key = "INSTANCE_CHAT", label = "Instance" },
    CHAT_MSG_GUILD = { key = "GUILD", label = "Guild" },
    CHAT_MSG_OFFICER = { key = "OFFICER", label = "Officer" },
}

local CHAT_TYPE_CHANNELS = {
    SAY = CHAT_EVENT_CHANNELS.CHAT_MSG_SAY,
    YELL = CHAT_EVENT_CHANNELS.CHAT_MSG_YELL,
    PARTY = CHAT_EVENT_CHANNELS.CHAT_MSG_PARTY,
    PARTY_LEADER = CHAT_EVENT_CHANNELS.CHAT_MSG_PARTY,
    RAID = CHAT_EVENT_CHANNELS.CHAT_MSG_RAID,
    RAID_LEADER = CHAT_EVENT_CHANNELS.CHAT_MSG_RAID,
    RAID_WARNING = CHAT_EVENT_CHANNELS.CHAT_MSG_RAID,
    INSTANCE_CHAT = CHAT_EVENT_CHANNELS.CHAT_MSG_INSTANCE_CHAT,
    INSTANCE_CHAT_LEADER = CHAT_EVENT_CHANNELS.CHAT_MSG_INSTANCE_CHAT,
    GUILD = CHAT_EVENT_CHANNELS.CHAT_MSG_GUILD,
    OFFICER = CHAT_EVENT_CHANNELS.CHAT_MSG_OFFICER,
}


function UI:GetChatChannelDef(key)
    key = key or UI._chatComposer.channel
    for i = 1, #UI._chatComposer.CHANNELS do
        local def = UI._chatComposer.CHANNELS[i]
        if def.key == key then return def end
    end
    return UI._chatComposer.CHANNELS[1]
end

function UI:CloseSearchForChatComposer()
    local searchFrame = GetSearchFrame()
    if searchFrame and searchFrame.editBox then
        local editBox = searchFrame.editBox
        if editBox.ResetPendingSearch then editBox:ResetPendingSearch() end
        editBox:SetText("")
        editBox:ClearFocus()
        if editBox.placeholder then editBox.placeholder:Show() end
    end
    -- These are EasyFind search-bar methods. They lived on the monolithic UI
    -- object this file was written against; the module refactor moved them onto
    -- ns.Filters / ns.Search / ns.Results, so calling them on self (the shared
    -- UI namespace) hit nil and crashed opening the composer. Guarded because
    -- this reaches across into another addon.
    if ns.Filters then
        if ns.Filters.ClearQuickFilter then ns.Filters:ClearQuickFilter(false) end
        if ns.Filters.HideQuickFilterSuggestions then ns.Filters:HideQuickFilterSuggestions() end
    end
    if searchFrame and searchFrame:IsShown() then
        if ns.Search and ns.Search.Hide then ns.Search:Hide() end
    elseif ns.Results and ns.Results.HideResults then
        ns.Results:HideResults()
    end
end

function UI:SetChatComposerStatus(text, r, g, b)
    local frame = UI._chatComposer.frame
    if not (frame and frame.statusText) then return end
    frame.statusText:SetText(text or "")
    if r then
        frame.statusText:SetTextColor(r, g, b, 1)
    else
        local tr, tg, tb = ChatTextColor()
        frame.statusText:SetTextColor(tr, tg, tb, 0.85)
    end
end

-- A preview line reads an EasyFind link as its name, not its wire form.
function UI:GetChatPreviewText(text)
    local links = ns.ResultLinks
    if links and links.Linkify then text = links:Linkify(tostring(text or "")) end
    return self:GetPlainChatLabel(text)
end

function UI:GetPlainChatLabel(label)
    label = tostring(label or "")
    label = label:gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")
        :gsub("|H.-|h(.-)|h", "%1")
        :gsub("|A.-|a", "")
        :gsub("|T.-|t", "")
        :gsub("|K.-|k", "")
    return strtrim(label)
end

function UI:GetFirstChatInitialCandidate(...)
    for i = 1, select("#", ...) do
        local initial = self:GetChatInitialFromText(select(i, ...))
        if initial then return initial end
    end
    return nil
end

function UI:GetChatPlayerShortName(label)
    label = self:GetPlainChatLabel(label)
    if label == "" then return "" end
    -- On WoW Forever the part after the dash is the surname, never the
    -- realm: it stays, as "First Surname".
    if ns.Caps and ns.Caps.forever then
        local first, surname = label:match("^([^%-]+)%-(.+)$")
        return first and (first .. " " .. surname) or label
    end
    return label:match("^([^%-]+)%-.+$") or label
end

function UI:GetChatRecipientInitial(...)
    return self:GetFirstChatInitialCandidate(...) or "?"
end

-- One whole UTF-8 character, so a non-Latin initial is never half a glyph.
local UTF8_CHAR = "([%z\1-\127\194-\244][\128-\191]*)"

function UI:GetChatInitialFromText(label)
    local raw = tostring(label or "")
    local protectedTail = raw:match("|K.-|k%s*([%w])") or raw:match("|K.-|k%s*" .. UTF8_CHAR)
    if protectedTail then return protectedTail:upper() end

    label = self:GetPlainChatLabel(raw)
    if label == "" then return nil end
    local initial = label:match("^%s*([%w])") or label:match("^%s*" .. UTF8_CHAR)
    return initial and initial:upper() or nil
end

function UI:GetChatRecipientColor(seed)
    seed = tostring(seed or "")
    local hash = 0
    for i = 1, #seed do
        hash = (hash * 33 + seed:byte(i)) % 9973
    end
    local c = CHAT_RECIPIENT_PALETTE[(hash % #CHAT_RECIPIENT_PALETTE) + 1]
    return c[1], c[2], c[3]
end

function UI:InsertChatEditNewLine(editBox)
    if not editBox then return end
    local text = editBox:GetText() or ""
    local cursor = editBox:GetCursorPosition() or #text
    editBox:SetText(text:sub(1, cursor) .. "\n" .. text:sub(cursor + 1))
    editBox:SetCursorPosition(cursor + 1)
end

function UI:GetChatMessageLines(raw)
    raw = tostring(raw or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    local lines = {}
    for line in (raw .. "\n"):gmatch("(.-)\n") do
        line = strtrim(line or "")
        if line ~= "" then lines[#lines + 1] = line end
    end
    return lines
end

function UI:GetChatEditMeasureFontString(region)
    if not (region and region.GetFont) then return nil end
    -- A font string has no CreateFontString: its meter lives on its parent.
    local host = region.CreateFontString and region or (region.GetParent and region:GetParent())
    if not (host and host.CreateFontString) then return nil end
    local meter = region._easyFindChatMeter
    if not meter then
        meter = host:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        meter:Hide()
        if meter.SetWordWrap then meter:SetWordWrap(true) end
        if meter.SetNonSpaceWrap then meter:SetNonSpaceWrap(true) end
        region._easyFindChatMeter = meter
    end
    local font, size, flags = region:GetFont()
    if font and size then meter:SetFont(font, size, flags) end
    return meter
end

-- The same words in the same font measure the same every redraw: kept per
-- font and width, so a redraw re-measures only what is new. A dragged edge
-- redraws ten times a second and measured every bubble each time.
local measured, measuredCount = {}, 0
local function MeasureBucket(region, width)
    local font, size, flags = region:GetFont()
    local key = (font or "") .. (size or 0) .. (flags or "") .. "|" .. (width or 0)
    local bucket = measured[key]
    if not bucket then
        bucket = {}
        measured[key] = bucket
    end
    return bucket
end

local function Remember(bucket, text, value)
    measuredCount = measuredCount + 1
    if measuredCount > 4000 then
        wipe(measured)
        measuredCount = 0
    end
    bucket[text] = value
end

function UI:ForgetChatMeasures()
    wipe(measured)
    measuredCount = 0
end

function UI:GetChatWrappedTextMetrics(region, text, maxWidth)
    text = tostring(text or "")
    if not region then return self:MeasureChatWrappedText(region, text, maxWidth) end
    local bucket = MeasureBucket(region, mmax(1, maxWidth or 1))
    local hit = bucket[text]
    if hit then return hit[1], hit[2], hit[3], hit[4] end
    local lines, height, lineHeight, widest = self:MeasureChatWrappedText(region, text, maxWidth)
    if lineHeight and lineHeight > 0 then Remember(bucket, text, { lines, height, lineHeight, widest }) end
    return lines, height, lineHeight, widest
end

function UI:MeasureChatWrappedText(region, text, maxWidth)
    local meter = self:GetChatEditMeasureFontString(region)
    local fallbackLineHeight = self:GetChatFontLineHeight(region, 12)
    text = tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    maxWidth = mmax(1, maxWidth or 1)

    if not meter then
        return 1, fallbackLineHeight, fallbackLineHeight, maxWidth
    end

    if meter.SetWordWrap then meter:SetWordWrap(true) end
    if meter.SetNonSpaceWrap then meter:SetNonSpaceWrap(true) end

    meter:SetWidth(4096)
    meter:SetText("Ag")
    local lineHeight = meter.GetStringHeight and meter:GetStringHeight() or fallbackLineHeight
    lineHeight = mmax(1, lineHeight or fallbackLineHeight)

    local trailingNewlines = 0
    do
        local i = #text
        while i > 0 and text:sub(i, i) == "\n" do
            trailingNewlines = trailingNewlines + 1
            i = i - 1
        end
    end

    local probe = (trailingNewlines > 0) and text:sub(1, #text - trailingNewlines) or text
    if probe == "" then probe = " " end

    meter:SetWidth(maxWidth)
    meter:SetText(probe)
    local rawHeight = (meter.GetStringHeight and meter:GetStringHeight()) or lineHeight
    rawHeight = mmax(lineHeight, rawHeight)

    local rawLines = rawHeight / lineHeight
    local visibleLines = math.ceil(rawLines - 0.05)
    if visibleLines < 1 then visibleLines = 1 end
    local totalLines = visibleLines + trailingNewlines
    local renderedHeight = totalLines * lineHeight

    local widest = 0
    if meter.SetWordWrap then meter:SetWordWrap(false) end
    if meter.SetNonSpaceWrap then meter:SetNonSpaceWrap(false) end
    local getter = meter.GetUnboundedStringWidth or meter.GetStringWidth
    local _, fontSize = meter:GetFont()
    for line in (text .. "\n"):gmatch("(.-)\n") do
        if line ~= "" then
            meter:SetWidth(4096)
            meter:SetText(line)
            local w = getter and getter(meter) or 0
            if w <= 0 then w = #line * (fontSize or 12) * 0.62 end
            widest = mmax(widest, w)
        end
    end
    if meter.SetWordWrap then meter:SetWordWrap(true) end
    if meter.SetNonSpaceWrap then meter:SetNonSpaceWrap(true) end

    return totalLines, math.ceil(renderedHeight), lineHeight, math.ceil(widest)
end

function UI:QueueChatReplyInputLayout()
    local c = UI._chatComposer
    if c.replyLayoutQueued then return end
    c.replyLayoutQueued = true
    if Utils.SafeAfter then
        Utils.SafeAfter(0, function()
            UI._chatComposer.replyLayoutQueued = nil
            UI:LayoutChatReplyInput()
        end)
    else
        c.replyLayoutQueued = nil
        self:LayoutChatReplyInput()
    end
end

function UI:GetChatMeasuredTextWidth(region, text)
    text = tostring(text or "")
    if text == "" or not region then return self:MeasureChatTextWidth(region, text) end
    local bucket = MeasureBucket(region, 0)
    local hit = bucket[text]
    if hit then return hit end
    local width = self:MeasureChatTextWidth(region, text)
    if width > 0 then Remember(bucket, text, width) end
    return width
end

function UI:MeasureChatTextWidth(region, text)
    local meter = self:GetChatEditMeasureFontString(region)
    if not meter then return 0 end

    text = tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    if text == "" then return 0 end

    if meter.SetWordWrap then meter:SetWordWrap(false) end
    if meter.SetNonSpaceWrap then meter:SetNonSpaceWrap(false) end
    local _, fontSize = meter:GetFont()
    local maxWidth = 0
    local getter = meter.GetUnboundedStringWidth or meter.GetStringWidth
    for line in (text .. "\n"):gmatch("(.-)\n") do
        if line ~= "" then
            meter:SetWidth(4096)
            meter:SetText(line)
            local width = getter and getter(meter) or 0
            if width <= 0 then
                width = #line * (fontSize or 12) * 0.62
            end
            maxWidth = mmax(maxWidth, width)
        end
    end
    if meter.SetWordWrap then meter:SetWordWrap(true) end
    if meter.SetNonSpaceWrap then meter:SetNonSpaceWrap(true) end
    return maxWidth or 0
end

function UI:StyleChatComposerInputSurface(frame, radius, fillAlpha)
    if not frame then return end
    if not frame.combinedBorder then
        ns.CreateRoundedRectBorder(frame)
    end
    ns.SetRoundedRectBarHeight(frame, radius or 8)
    ns.SetRoundedRectBorderBgAlpha(frame, 1)
    frame._chatFillAlpha = fillAlpha or 1
    if not frame._chatInputShellRegistered then
        frame._chatInputShellRegistered = true
        chatInputShells[#chatInputShells + 1] = frame
    end
    PaintChatInputSurface(frame)
    ns.SetRoundedRectBorderEdgeShown(frame, false)
end

-- An input with a 1 px ring round its inset. Its words and buttons go
-- on the returned inset, which covers the shell.
function UI:StyleChatInputWell(frame, radius)
    ns.CreateRingedWell(frame, (radius or 8) / 2)
    chatInputShells[#chatInputShells + 1] = frame
    PaintChatInputSurface(frame)
    return frame.ringInset
end

function UI:SetChatSubtleOutline(frame, shown, alpha)
    if not frame then return end
    if not frame.combinedBorder then ns.CreateRoundedRectBorder(frame) end
    ns.SetRoundedRectBorderColor(frame, CHAT_OUTLINE_COLOR[1], CHAT_OUTLINE_COLOR[2],
        CHAT_OUTLINE_COLOR[3], alpha or 0.68, true)
    ns.SetRoundedRectBorderEdgeShown(frame, shown and true or false)
end

-- What the server counts: visible bytes, links as their shown name.
function UI:GetChatTextLength(editBox)
    return #self:GetPlainChatLabel(editBox and editBox:GetText() or "")
end

function UI:UpdateChatCharCounter(editBox, counter, maxChars)
    if not (editBox and counter) then return end
    maxChars = maxChars or CHAT_MESSAGE_MAX_CHARS
    local length = self:GetChatTextLength(editBox)
    counter:SetText(length .. "/" .. maxChars)
    if length >= maxChars then
        counter:SetTextColor(Utils.RGB(CHAT_COUNTER_MAX_COLOR, 1))
    elseif length >= maxChars * 0.85 then
        counter:SetTextColor(Utils.RGB(CHAT_COUNTER_WARN_COLOR, 1))
    else
        PaintChatThemedText(counter)
    end
end

function UI:SetChatEditMaxLetters(editBox, maxChars)
    if not editBox then return end
    maxChars = mmax(1, mmin(CHAT_MESSAGE_MAX_CHARS, maxChars or CHAT_MESSAGE_MAX_CHARS))
    if editBox._chatMaxLetters ~= maxChars then
        -- The client chat box's own limits: visible bytes, room for links.
        if editBox.SetVisibleTextByteLimit then
            editBox:SetMaxBytes(CHAT_EDIT_MAX_BYTES)
            editBox:SetVisibleTextByteLimit(maxChars)
        elseif editBox.SetMaxLetters then
            editBox:SetMaxLetters(maxChars)
        end
        editBox._chatMaxLetters = maxChars
    end
    -- A limit that shrank under typed plain text (a reply's quote) cuts it
    -- between characters; text with links is left to the box's own limit.
    local text = editBox:GetText() or ""
    if #text > maxChars and not sfind(text, "|", 1, true) then
        local cursor = editBox:GetCursorPosition() or #text
        text = text:sub(1, CharBoundary(text, maxChars))
        editBox:SetText(text)
        editBox:SetCursorPosition(mmin(cursor, #text))
    end
end

function UI:GetChatSidebarWidth()
    local width = tonumber(ChatDB().sidebarWidth) or CHAT_SIDEBAR_DEFAULT_W
    return mmax(CHAT_SIDEBAR_MIN_W, mmin(CHAT_SIDEBAR_MAX_W, width))
end

function UI:IsChatSidebarCollapsed()
    return ChatDB().sidebarCollapsed == true
end

function UI:SetChatSidebarCollapsed(collapsed)
    ChatDB().sidebarCollapsed = collapsed and true or nil
    if collapsed then
        UI._chatComposer.sidebarResizing = nil
        UI._chatComposer.sidebarLiveWidth = nil
        self:HideChatSidebarResizeCursor()
    end
    self:LayoutChatMessengerChrome()
    self:RefreshChatMessenger()
end

function UI:ToggleChatSidebarCollapsed()
    self:SetChatSidebarCollapsed(not self:IsChatSidebarCollapsed())
end

-- The collapsed sidebar's search, opened beside its icons; clear takes the
-- filter with it.
function UI:SetChatSidebarSearchOpen(open, clear)
    local view = UI._chatComposer.frame and UI._chatComposer.frame.messengerView
    if not view then return end
    if not open and view.sidebarSearchOpen then view._sidebarSearchClosedAt = GetTime() end
    view.sidebarSearchOpen = open or nil
    if not open then
        if view.searchEditBox:HasFocus() then view.searchEditBox:ClearFocus() end
        if clear and view.searchEditBox:GetText() ~= "" then view.searchEditBox:SetText("") end
    end
    self:LayoutChatMessengerChrome()
    if open then self:FocusChatEditBox(view.searchEditBox) end
end

-- The lens: the click that took the box's focus away just closed it.
function UI:ToggleChatSidebarSearch()
    local view = UI._chatComposer.frame and UI._chatComposer.frame.messengerView
    if not view then return end
    if view._sidebarSearchClosedAt and GetTime() - view._sidebarSearchClosedAt < 0.3 then return end
    self:SetChatSidebarSearchOpen(not view.sidebarSearchOpen)
end

function UI:SetChatSidebarWidth(width, persist)
    local frame = UI._chatComposer.frame
    local view = frame and frame.messengerView
    if not (view and view.sidebar) then return end

    width = mmax(CHAT_SIDEBAR_MIN_W, mmin(CHAT_SIDEBAR_MAX_W, width or CHAT_SIDEBAR_DEFAULT_W))
    if not self:IsChatSidebarCollapsed() then
        view.sidebar:SetWidth(width)
    end
    -- Mid-drag widths live here; LayoutChatMessengerChrome reads this before
    -- the persisted value, otherwise every layout pass snaps the sidebar back
    -- to the DB width and the drag visibly does nothing.
    if persist then
        ChatDB().sidebarWidth = width
        UI._chatComposer.sidebarLiveWidth = nil
    else
        UI._chatComposer.sidebarLiveWidth = width
    end
    self:LayoutChatMessengerChrome()
    if persist then self:RefreshChatMessenger() else self:QueueChatMessengerRefresh() end
end

-- One redraw at most every tenth of a second for a burst (an edge dragged,
-- a command's output and System lines): each measures every bubble, and
-- two a frame sent the CPU up. A dragged frame still follows every frame.
function UI:QueueChatMessengerRefresh()
    local c = UI._chatComposer
    if c.refreshQueued then return end
    c.refreshQueued = true
    Utils.SafeAfter(0.1, function()
        c.refreshQueued = nil
        UI:RefreshChatMessenger()
    end)
end

function UI:EnsureChatSidebarResizeCursor()
    local cursor = UI._chatComposer.sidebarResizeCursor
    if cursor then return cursor end

    cursor = CreateFrame("Frame", nil, UIParent)
    UI._chatComposer.sidebarResizeCursor = cursor
    cursor:SetSize(24, 24)
    cursor:SetFrameStrata("TOOLTIP")
    cursor:SetFrameLevel(1200)
    cursor:EnableMouse(false)
    -- The same flat chevron every flyout wears, mirrored into a "<>" pair;
    -- the old sprite-sheet crop read blurry next to the rest of the chrome.
    cursor.leftArrow = cursor:CreateTexture(nil, "OVERLAY")
    cursor.leftArrow:SetSize(11, 11)
    cursor.leftArrow:SetPoint("RIGHT", cursor, "CENTER", -2, 0)
    cursor.leftArrow:SetTexture(ns.FILTER_ARROW_TEX)
    cursor.leftArrow:SetRotation(-math.pi / 2)
    cursor.rightArrow = cursor:CreateTexture(nil, "OVERLAY")
    cursor.rightArrow:SetSize(11, 11)
    cursor.rightArrow:SetPoint("LEFT", cursor, "CENTER", 2, 0)
    cursor.rightArrow:SetTexture(ns.FILTER_ARROW_TEX)
    cursor.rightArrow:SetRotation(math.pi / 2)
    cursor.leftArrow:SetVertexColor(ChatAccentGlyphColor())
    cursor.rightArrow:SetVertexColor(ChatAccentGlyphColor())
    cursor:Hide()
    return cursor
end

function UI:PositionChatSidebarResizeCursor()
    local cursor = self:EnsureChatSidebarResizeCursor()
    if not (cursor and GetCursorPosition and UIParent) then return end
    local _, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1
    local frame = UI._chatComposer.frame
    local view = frame and frame.messengerView
    local handle = view and view.sidebarResizeHandle
    local x
    if handle and handle.line and handle.line.GetCenter then
        local rawX = handle.line:GetCenter()
        local regionScale = handle.line.GetEffectiveScale and handle.line:GetEffectiveScale()
            or (handle.GetEffectiveScale and handle:GetEffectiveScale()) or scale
        if rawX then x = rawX * regionScale / scale end
    end
    if not x and handle and handle.GetCenter then
        local rawX = handle:GetCenter()
        local regionScale = handle.GetEffectiveScale and handle:GetEffectiveScale() or scale
        if rawX then x = rawX * regionScale / scale end
    end
    if not x and view and view.sidebar and view.sidebar.GetRight then
        local rawX = view.sidebar:GetRight()
        local regionScale = view.sidebar.GetEffectiveScale and view.sidebar:GetEffectiveScale() or scale
        if rawX then x = rawX * regionScale / scale end
    end
    if not x then
        local cursorX = GetCursorPosition()
        x = cursorX / scale
    end
    cursor:ClearAllPoints()
    cursor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y / scale)
end

function UI:ShowChatSidebarResizeCursor()
    local cursor = self:EnsureChatSidebarResizeCursor()
    self:PositionChatSidebarResizeCursor()
    cursor:Show()
end

function UI:HideChatSidebarResizeCursor()
    local cursor = UI._chatComposer.sidebarResizeCursor
    if cursor then cursor:Hide() end
end

function UI:StartChatSidebarResize(handle)
    local frame = UI._chatComposer.frame
    local view = frame and frame.messengerView
    if not (view and view.sidebar and handle and GetCursorPosition) then return end
    if self:IsChatSidebarCollapsed() then return end

    local x = GetCursorPosition()
    local scale = handle:GetEffectiveScale() or 1
    UI._chatComposer.sidebarResizing = true
    UI._chatComposer.sidebarResizeStartX = x / scale
    UI._chatComposer.sidebarResizeStartW = view.sidebar:GetWidth() or self:GetChatSidebarWidth()
    self:ShowChatSidebarResizeCursor()
    Utils.SafeOnUpdate(handle, ChatSidebarResizeOnUpdate)
end

function UI:StopChatSidebarResize(handle)
    local frame = UI._chatComposer.frame
    local view = frame and frame.messengerView
    if view and view.sidebar then
        self:SetChatSidebarWidth(view.sidebar:GetWidth(), true)
    end
    UI._chatComposer.sidebarResizing = nil
    if handle and handle.line then handle.line:Hide() end
    if handle and handle:IsMouseOver() then
        if handle.line then handle.line:Show() end
        self:ShowChatSidebarResizeCursor()
        Utils.SafeOnUpdate(handle, ChatSidebarResizeOnUpdate)
    else
        self:HideChatSidebarResizeCursor()
        if handle then Utils.SafeOnUpdate(handle, nil) end
    end
end

function UI:UpdateChatSidebarResize(handle)
    if not UI._chatComposer.sidebarResizing then
        self:PositionChatSidebarResizeCursor()
        return
    end
    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
        self:StopChatSidebarResize(handle)
        return
    end
    if not (handle and GetCursorPosition) then return end
    local x = GetCursorPosition()
    local scale = handle:GetEffectiveScale() or 1
    local delta = (x / scale) - (UI._chatComposer.sidebarResizeStartX or 0)
    self:SetChatSidebarWidth((UI._chatComposer.sidebarResizeStartW or CHAT_SIDEBAR_DEFAULT_W) + delta, false)
    self:PositionChatSidebarResizeCursor()
end

function UI:IsChatFrameEditBox(editBox)
    local frame = UI._chatComposer.frame
    if not (frame and editBox) then return false end
    if editBox == frame.targetEditBox or editBox == frame.messageEditBox then return true end
    local view = frame.messengerView
    if view and editBox == view.searchEditBox then return true end
    if view and editBox == view.filterEditBox then return true end
    if view and editBox == view.replyEditBox then return true end
    if view and editBox == view.headerRecipientEdit then return true end
    if view and view.messageRows then
        for i = 1, #view.messageRows do
            if editBox == view.messageRows[i].copyBox then return true end
        end
    end
    return false
end

function UI:ClearChatMessageCopyFocus(except)
    local frame = UI._chatComposer.frame
    local view = frame and frame.messengerView
    if not (view and view.messageRows) then return end
    for i = 1, #view.messageRows do
        local box = view.messageRows[i].copyBox
        if box and box ~= except and box.HasFocus and box:HasFocus() then
            box:HighlightText(0, 0)
            box:SetCursorPosition(0)
            box:ClearFocus()
        end
    end
end

function UI:SelectChatMessageRowText(row)
    local box = row and row.copyBox
    if not box then return false end

    self:ClearChatMessageCopyFocus(box)
    box:SetFocus()
    box:SetCursorPosition(0)
    box:HighlightText(0, -1)
    if Utils.SafeAfter then
        Utils.SafeAfter(0, function()
            if box:IsShown() and box:GetText() == (box._chatText or "") then
                box:SetFocus()
                box:SetCursorPosition(0)
                box:HighlightText(0, -1)
            end
        end)
    end
    return true
end

function UI:HandleChatMessageRowMouseDown(row, button)
    if button ~= "LeftButton" then return false end
    -- A link bubble has no copy box up to select in (Copy Message still does).
    if not row.copyBox:IsShown() then return false end

    local now = GetTime and GetTime() or time()
    if row._lastLeftClickAt and now - row._lastLeftClickAt <= 0.35 then
        row._lastLeftClickAt = nil
        return self:SelectChatMessageRowText(row)
    end
    row._lastLeftClickAt = now
    return false
end

function UI:FocusChatEditBox(editBox)
    if not editBox then return end
    local view = UI._chatComposer.frame and UI._chatComposer.frame.messengerView
    if view and editBox == view.replyEditBox then self:ShowChatLine() end
    self:ClearChatMessageCopyFocus(editBox)
    if editBox.SetFocus then editBox:SetFocus() end
end

function UI:ClearFocusedChatEditBox()
    local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if not focus or focus:IsForbidden() or not self:IsChatFrameEditBox(focus) then return false end

    local frame = UI._chatComposer.frame
    local recipientEdit = self:GetActiveRecipientContext()
    if focus == recipientEdit and frame.suggestionMenu and frame.suggestionMenu:IsShown() then
        UI._chatComposer.showAllContacts = nil
        frame.suggestionMenu:Hide()
    end

    if focus.HighlightText then focus:HighlightText(0, 0) end
    if focus.SetCursorPosition then focus:SetCursorPosition(0) end
    if focus.ClearFocus then focus:ClearFocus() end
    return true
end

function UI:CopyChatMessageText(text)
    text = tostring(text or "")
    if text == "" then return false end

    local clipboard = _G and _G.C_Clipboard
    if clipboard then
        local ok, result
        if clipboard.SetClipboardText then
            ok, result = xpcall(clipboard.SetClipboardText, Utils.ErrorHandler, text)
        end
        if ok and result ~= false then
            return true
        end
        if clipboard.SetClipboard then
            ok, result = xpcall(clipboard.SetClipboard, Utils.ErrorHandler, text)
        end
        if ok and result ~= false then
            return true
        end
    end

    ns.CopyToClipboard(text)
    return true
end

function UI:GetChatReplyBannerText()
    local pending = UI._chatComposer.pendingReply
    if not (pending and pending.text) then return nil end
    if pending.key ~= UI._chatComposer.selectedConversationKey then return nil end
    return 'Replying to "' .. self:TrimChatQuotedText(pending.text, 64) .. '"'
end

function UI:CancelChatReply()
    UI._chatComposer.pendingReply = nil
    self:LayoutChatReplyInput()
end

-- How the message box shows: "full" (Send and the count beside it),
-- "compact" (one line) or "enter" (hidden until Enter, with the takeover).
function UI:GetChatInputStyle()
    return ChatDB().inputStyle or "full"
end

-- The message line as the style has it: Send and the count in Full only;
-- hidden until Enter, the line only while open.
function UI:SyncChatReplyLine(view)
    local style = self:GetChatInputStyle()
    local canType = view._chatCanType == true
    -- The game's own line in ours (GameLine.lua): our box steps aside.
    local game = UI._chatComposer.gameLine == true
    view.replyShell:SetShown(game or (canType and (style ~= "enter" or UI._chatComposer.lineOpen == true)))
    view.replyEditBox:SetShown(not game)
    view.replyButton:SetShown(canType and style == "full")
    if view.replyCounter then view.replyCounter:SetShown(canType and style == "full") end
    self:LayoutChatReplyInput()
end

function UI:ShowChatLine()
    if self:GetChatInputStyle() ~= "enter" then return end
    UI._chatComposer.lineOpen = true
    local view = UI._chatComposer.frame and UI._chatComposer.frame.messengerView
    if view then self:SyncChatReplyLine(view) end
end

function UI:CloseChatLine()
    if not UI._chatComposer.lineOpen then return end
    UI._chatComposer.lineOpen = nil
    local view = UI._chatComposer.frame and UI._chatComposer.frame.messengerView
    if not view then return end
    if view.replyEditBox:HasFocus() then view.replyEditBox:ClearFocus() end
    self:SyncChatReplyLine(view)
end

-- Enter with the takeover: the window opens if closed and the line shows
-- from its foot, focused; with no chat yet, a new one.
function UI:OpenChatLine()
    if chatNS.GameLine and chatNS.GameLine:Focus() then return end
    if not chatNS:IsOpen() then self:OpenChatComposer() end
    local frame = UI._chatComposer.frame
    if not frame then return end
    if frame.chatMode ~= "messenger" then self:ShowChatMessengerView() end
    UI._chatComposer.lineOpen = true
    if not (UI._chatComposer.selectedConversationKey or UI._chatComposer.composeInPlace) then
        self:BeginChatComposeInPlace()
        return
    end
    -- All and System have no chat of their own: the game's line, as it
    -- last was, typed in here.
    local views = chatNS.Views
    if views and views:IsView(UI._chatComposer.selectedConversationKey) and ChatDB().takeover == true then
        self:HandChatLineToGame(frame.messengerView.replyEditBox, "")
        return
    end
    self:FocusChatEditBox(frame.messengerView.replyEditBox)
end

-- Enter in the message box sends; hidden until Enter, the line then
-- closes as the game's does, an empty one too.
function UI:SubmitChatReplyLine(editBox)
    local sent = self:SendChatMessengerReply()
    if sent or strtrim(editBox:GetText() or "") == "" then self:CloseChatLine() end
end

-- With the takeover a slash command goes to the game's own box, which
-- GameLine.lua brings into this line: it runs the protected ones (/cast) a
-- box of ours cannot.
function UI:HandChatLineToGame(editBox, text)
    editBox:SetText("")
    if editBox:HasFocus() then editBox:ClearFocus() end
    local open = ChatFrameUtil and ChatFrameUtil.OpenChat or _G["ChatFrame_OpenChat"]
    if open then open(text) end
end

function UI:LayoutChatReplyInput()
    local frame = UI._chatComposer.frame
    local view = frame and frame.messengerView
    if not (view and view.replyShell and view.replyEditBox and view.replyButton and view.messageScroll) then return end

    local replyMax = self:GetChatReplyInputLimit()
    self:SetChatEditMaxLetters(view.replyEditBox, replyMax)
    self:UpdateChatCharCounter(view.replyEditBox, view.replyCounter, replyMax)

    local style = self:GetChatInputStyle()
    local oneRow = style ~= "full"
    local padTop, padBottom = 10, 10
    if oneRow then padTop, padBottom = 4, 4 end
    local padLeft, padRight = 10, 10
    local buttonW = oneRow and 0 or (view._chatReplyButtonWidth or 56)
    local buttonGap = oneRow and 0 or 6
    local detailW = view.detail and view.detail:GetWidth() or 0
    local shellW = mmax(120, detailW - buttonW - buttonGap)
    local textW = mmax(40, shellW - padLeft - padRight)
    local rawText = view.replyEditBox:GetText() or ""
    -- The box measures itself: held by its top and width only, a multi-line
    -- box grows to its words, and that size change lays this out again.
    local textHeight = math.ceil(mmax(self:GetChatFontLineHeight(view.replyEditBox, 12),
        view.replyEditBox:GetHeight() or 0))
    local height = textHeight + padTop + padBottom
    if oneRow then height = mmax(22, height) end
    local counterH = mmax(12, self:GetChatFontLineHeight(view.replyCounter, 10))
    local counterGap = 2
    local buttonH = mmax(16, height - counterH - counterGap)
    local bannerText = self:GetChatReplyBannerText()
    local bannerH = 0
    local bannerGap = 0
    if bannerText and view.replyShell:IsShown() then
        bannerH = mmax(22, self:GetChatFontLineHeight(view.replyBannerText, 10) + 10)
        bannerGap = 6
    end

    view.replyShell:ClearAllPoints()
    view.replyShell:SetPoint("BOTTOMLEFT", view.detail, "BOTTOMLEFT", 0, 0)
    view.replyShell:SetPoint("BOTTOMRIGHT", view.detail, "BOTTOMRIGHT", -(buttonW + buttonGap), 0)
    view.replyShell:SetHeight(height)

    view.replyButton:ClearAllPoints()
    view.replyButton:SetPoint("TOPLEFT", view.replyShell, "TOPRIGHT", 6, 0)
    view.replyButton:SetWidth(buttonW)
    view.replyButton:SetHeight(buttonH)

    if view.replyCounter then
        view.replyCounter:ClearAllPoints()
        view.replyCounter:SetPoint("TOP", view.replyButton, "BOTTOM", 0, -counterGap)
        view.replyCounter:SetWidth(buttonW)
        view.replyCounter:SetHeight(counterH)
        view.replyCounter:SetJustifyH("CENTER")
    end

    if view.replyBanner then
        if bannerText and bannerH > 0 then
            view.replyBanner:ClearAllPoints()
            view.replyBanner:SetPoint("BOTTOMLEFT", view.replyShell, "TOPLEFT", 0, bannerGap)
            view.replyBanner:SetPoint("BOTTOMRIGHT", view.replyShell, "TOPRIGHT", 0, bannerGap)
            view.replyBanner:SetHeight(bannerH)
            if view.replyBannerText then view.replyBannerText:SetText(bannerText) end
            view.replyBanner:Show()
        else
            view.replyBanner:Hide()
        end
    end

    view.replyEditBox:ClearAllPoints()
    view.replyEditBox:SetPoint("TOPLEFT", view.replyShell, "TOPLEFT", padLeft, -padTop)
    view.replyEditBox:SetWidth(textW)
    if view.replyEditBox.SetTextInsets then view.replyEditBox:SetTextInsets(0, 0, 0, 0) end
    if view.replyEditBox.SetJustifyV then
        view.replyEditBox:SetJustifyV("TOP")
    end
    if view.replyPlaceholder then
        view.replyPlaceholder:ClearAllPoints()
        view.replyPlaceholder:SetPoint("TOPLEFT", view.replyShell, "TOPLEFT", padLeft, -padTop)
        view.replyPlaceholder:SetPoint("BOTTOMRIGHT", view.replyShell, "BOTTOMRIGHT", -padRight, padBottom)
        if view.replyPlaceholder.SetJustifyV then view.replyPlaceholder:SetJustifyV("TOP") end
        view.replyPlaceholder:SetShown(rawText == "" and not UI._chatComposer.gameLine)
    end

    self:UpdateChatCharCounter(view.replyEditBox, view.replyCounter, replyMax)
    UI._chatComposer.layoutingReplyInput = true
    view.messageScroll:ClearAllPoints()
    view.messageScroll:SetPoint("TOPLEFT", view.detail, "TOPLEFT", 0, -(view._chatHeaderHeight or 40))
    local reserve = height + bannerH + bannerGap + 8
    if style == "enter" and not UI._chatComposer.lineOpen then reserve = 0 end
    view.messageScroll:SetPoint("BOTTOMRIGHT", view.detail, "BOTTOMRIGHT", 0, reserve)
    UI._chatComposer.layoutingReplyInput = nil
    self:UpdateChatMessageScrollBar()
end

function UI:AddChatRecipient(kind, id, name, label, initialLabel)
    kind = kind or "player"
    id = id or name
    label = label or name or tostring(id or "")
    if label == "" or not id then return false end

    local lookupID = id
    local displayLabel = label
    if kind == "player" then
        -- Identity keeps the realm-qualified name; only the shown label is short.
        displayLabel = self:GetChatPlayerShortName(label)
        lookupID = self:GetPlainChatLabel(id)
        if lookupID == "" then lookupID = tostring(id) end
    elseif kind == "bn" then
        displayLabel = self:GetPlainChatLabel(label)
        lookupID = id or (displayLabel ~= "" and displayLabel or label)
    end

    local key = kind .. ":" .. slower(tostring(lookupID))
    local c = UI._chatComposer
    if c.recipientLookup[key] then return false end
    c.recipientLookup[key] = true
    c.recipients[#c.recipients + 1] = {
        kind = kind,
        id = id,
        name = name or label,
        label = displayLabel ~= "" and displayLabel or label,
        initialLabel = initialLabel or name or label,
        key = key,
    }
    self:RefreshChatComposerRecipients()
    self:RefreshChatRecipientSuggestions()
    return true
end

function UI:RemoveChatRecipient(key)
    if not key then return false end
    local c = UI._chatComposer
    for i = 1, #c.recipients do
        if c.recipients[i].key == key then
            c.recipientLookup[key] = nil
            tremove(c.recipients, i)
            self:RefreshChatComposerRecipients()
            self:RefreshChatRecipientSuggestions()
            return true
        end
    end
    return false
end

function UI:RemoveLastChatRecipient()
    local c = UI._chatComposer
    local recipient = c.recipients[#c.recipients]
    return recipient and self:RemoveChatRecipient(recipient.key) or false
end

function UI:ClearChatRecipients()
    local c = UI._chatComposer
    wipe(c.recipients)
    wipe(c.recipientLookup)
    self:RefreshChatComposerRecipients()
    self:RefreshChatRecipientSuggestions()
end

function UI:AddChatFriendEntry(kind, id, label, name, source, subtext, online, priority, searchExtra, battleTag)
    if not id or not label or label == "" then return end
    local entries = UI._chatComposer.friendEntries
    local lookupID = id
    local displayLabel = label
    if kind == "player" then
        displayLabel = self:GetChatPlayerShortName(label)
        lookupID = self:GetPlainChatLabel(id)
        if lookupID == "" then lookupID = tostring(id) end
    elseif kind == "bn" then
        displayLabel = self:GetPlainChatLabel(label)
        lookupID = id or (displayLabel ~= "" and displayLabel or label)
    end
    local key = kind .. ":" .. slower(tostring(lookupID))
    for i = 1, #entries do
        if entries[i].key == key then return end
    end
    online = online ~= false
    source = source or "Contact"
    subtext = subtext or source
    entries[#entries + 1] = {
        kind = kind,
        id = id,
        label = displayLabel ~= "" and displayLabel or label,
        name = name or label,
        initial = self:GetFirstChatInitialCandidate(displayLabel, name, searchExtra, subtext, label),
        initialLabel = self:GetPlainChatLabel(displayLabel) ~= "" and displayLabel
            or self:GetPlainChatLabel(name) ~= "" and name
            or self:GetPlainChatLabel(searchExtra) ~= "" and searchExtra
            or nil,
        key = key,
        nameLower = slower(label or ""),
        source = source,
        subtext = subtext,
        online = online,
        priority = priority or (online and 1 or 4),
        searchText = slower((label or "") .. " " .. (name or "") .. " "
            .. source .. " " .. subtext .. " " .. (searchExtra or "")),
        battleTag = (kind == "bn") and battleTag or nil,
    }
end

function UI:RefreshChatFriendEntries()
    local entries = UI._chatComposer.friendEntries
    wipe(entries)

    if C_FriendList and C_FriendList.ShowFriends then
        xpcall(C_FriendList.ShowFriends, Utils.ErrorHandler)
    end

    if C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
        local count = C_FriendList.GetNumFriends()
        for i = 1, count or 0 do
            local ok, info = xpcall(C_FriendList.GetFriendInfoByIndex, Utils.ErrorHandler, i)
            if ok and info and info.name then
                local online = info.connected and true or false
                local subtext = online and (info.area or "Online") or "Offline"
                self:AddChatFriendEntry("player", info.name, info.name, info.name,
                    "WoW Friend", subtext, online, online and 1 or 5, info.note)
            end
        end
    elseif GetNumFriends and GetFriendInfo then
        local count = GetNumFriends()
        for i = 1, count or 0 do
            local ok, name, _, _, area, connected, _, note = xpcall(GetFriendInfo, Utils.ErrorHandler, i)
            if ok and name then
                local online = connected and true or false
                local subtext = online and (area or "Online") or "Offline"
                self:AddChatFriendEntry("player", name, name, name,
                    "WoW Friend", subtext, online, online and 1 or 5, note)
            end
        end
    end

    local bnTotal
    if C_BattleNet and C_BattleNet.GetNumFriends then
        local ok, total = xpcall(C_BattleNet.GetNumFriends, Utils.ErrorHandler)
        if ok then bnTotal = total end
    elseif BNGetNumFriends then
        local ok, total = xpcall(BNGetNumFriends, Utils.ErrorHandler)
        if ok then bnTotal = total end
    end

    if C_BattleNet and C_BattleNet.GetFriendAccountInfo and bnTotal then
        for i = 1, bnTotal or 0 do
            local ok, accountInfo = xpcall(C_BattleNet.GetFriendAccountInfo, Utils.ErrorHandler, i)
            if ok and accountInfo then
                local id = accountInfo.bnetAccountID or accountInfo.accountID
                    or accountInfo.presenceID or accountInfo.battleTag or accountInfo.accountName
                local label = accountInfo.accountName or accountInfo.battleTag
                    or accountInfo.displayName or ("Battle.net " .. i)
                local online = accountInfo.isOnline
                local extra = accountInfo.battleTag or ""
                local subtext = "Battle.net"
                local game = accountInfo.gameAccountInfo
                local gameCharacterName
                if C_BattleNet.GetFriendNumGameAccounts and C_BattleNet.GetFriendGameAccountInfo then
                    local gok, gameCount = xpcall(C_BattleNet.GetFriendNumGameAccounts, Utils.ErrorHandler, i)
                    if gok and gameCount and gameCount > 0 then
                        for gi = 1, gameCount do
                            local giOk, gameInfo = xpcall(C_BattleNet.GetFriendGameAccountInfo, Utils.ErrorHandler, i, gi)
                            if giOk and gameInfo and gameInfo.isOnline then
                                game = gameInfo
                                break
                            end
                        end
                    end
                end
                if game then
                    online = online or game.isOnline
                    local char = game.characterName
                    local realm = game.realmName
                    local client = game.clientProgram or game.client
                    if char and char ~= "" then
                        gameCharacterName = char
                        subtext = "Battle.net - " .. char .. (realm and realm ~= "" and ("-" .. realm) or "")
                        extra = extra .. " " .. char .. " " .. (realm or "")
                    elseif client and client ~= "" then
                        subtext = "Battle.net - " .. client
                        extra = extra .. " " .. client
                    end
                end
                if id then
                    self:AddChatFriendEntry("bn", id, label, gameCharacterName
                        or accountInfo.accountName or accountInfo.battleTag or label,
                        "Battle.net", online and subtext or "Battle.net - Offline",
                        online and true or false, online and 2 or 6, gameCharacterName or extra,
                        accountInfo.battleTag)
                end
            end
        end
    end

    if BNGetNumFriends and BNGetFriendInfo then
        local total = BNGetNumFriends()
        for i = 1, total or 0 do
            local ok, presenceID, accountName, battleTag, _, _, _, client, isOnline =
                xpcall(BNGetFriendInfo, Utils.ErrorHandler, i)
            if ok and presenceID then
                local label = accountName or battleTag or ("Battle.net " .. i)
                if battleTag and battleTag ~= "" and battleTag ~= label then
                    label = label .. " (" .. battleTag .. ")"
                end
                local subtext = "Battle.net"
                if client and client ~= "" then
                    subtext = subtext .. " - " .. client
                end
                self:AddChatFriendEntry("bn", presenceID, label, accountName or battleTag or label,
                    "Battle.net", isOnline and subtext or "Battle.net - Offline",
                    isOnline and true or false, isOnline and 2 or 6, battleTag, battleTag)
            end
        end
    end

    tsort(entries, CompareChatFriendEntries)
end

function UI:ScoreChatContact(entry, query)
    if not entry then return nil end
    query = slower(strtrim(query or ""))
    if query == "" then
        return (entry.priority or 9) * 100
    end

    local queryWords
    if sfind(query, " ", 1, true) then
        queryWords = {}
        for w in query:gmatch("%S+") do queryWords[#queryWords + 1] = w end
    end

    local nameScore = ns.Database and ns.Database.ScoreName
        and ns.Database:ScoreName(entry.nameLower or slower(entry.label or ""), query, #query, queryWords)
        or 0
    if nameScore and nameScore > 0 then
        return (1000 - nameScore) + (entry.priority or 9)
    end

    local searchScore = ns.Database and ns.Database.ScoreName
        and ns.Database:ScoreName(entry.searchText or "", query, #query, queryWords)
        or 0
    if searchScore and searchScore > 0 then
        return (1200 - searchScore) + (entry.priority or 9)
    end

    return nil
end

function UI:FindChatFriendEntryForText(text)
    text = slower(strtrim(text or ""))
    if text == "" then return nil end
    local prefix
    local entries = UI._chatComposer.friendEntries
    for i = 1, #entries do
        local entry = entries[i]
        if not UI._chatComposer.recipientLookup[entry.key] then
            local label = slower(entry.label or "")
            local name = slower(entry.name or "")
            if label == text or name == text then
                return entry
            elseif not prefix and (sfind(label, text, 1, true) == 1 or sfind(name, text, 1, true) == 1) then
                prefix = entry
            end
        end
    end
    return prefix
end

function UI:AddChatRecipientFromEntry(entry)
    if not entry then return false end
    return self:AddChatRecipient(entry.kind, entry.id, entry.name, entry.label, entry.initialLabel)
end

function UI:AddChatRecipientFromText(text)
    text = strtrim(text or "")
    if text == "" then return false end
    local entry = self:FindChatFriendEntryForText(text)
    if entry then
        return self:AddChatRecipientFromEntry(entry)
    end
    return self:AddChatRecipient("player", text, text, text)
end

function UI:AddManualChatRecipients(raw)
    raw = strtrim(raw or "")
    if raw == "" then return false end
    local added = false
    -- Commas and semicolons part names; spaces may sit inside one.
    for token in raw:gmatch("[^,;]+") do
        token = strtrim(token)
        if token ~= "" and self:AddChatRecipientFromText(token) then
            added = true
        end
    end
    return added
end

-- The compose view's target field and the messenger's in-place To: field
-- share ONE recipient machine (suggestions, chips, multi-send). Whichever
-- shell is on screen is the active context; every consumer below resolves
-- through here instead of hardcoding the compose widgets.
function UI:GetActiveRecipientContext()
    local frame = UI._chatComposer.frame
    if not frame then return nil end
    local view = frame.messengerView
    if UI._chatComposer.composeInPlace and view and view.headerRecipientShell
       and view.headerRecipientShell:IsShown() then
        return view.headerRecipientEdit, view.headerRecipientShell
    end
    return frame.targetEditBox, frame.targetShell
end

-- Extensions > Chat: the chat's own button hides while the window is open.
function UI:SyncChatButtonHidden()
    local EB = ns.ExtensionButtons
    if not (EB and EB.SetAppButtonsHidden) then return end
    local frame = UI._chatComposer.frame
    EB:SetAppButtonsHidden("chat", ChatDB().hideButtonWhileOpen == true and frame ~= nil and frame:IsShown())
end

-- Slash words a To: field takes as a place, not a name: the client's own
-- (every locale's), and the English short forms beside them.
local CHAT_COMMAND_TOKENS = {
    SAY = "SAY", YELL = "YELL", PARTY = "PARTY", RAID = "RAID", RAID_WARNING = "RAID",
    INSTANCE_CHAT = "INSTANCE_CHAT", GUILD = "GUILD", OFFICER = "OFFICER", WHISPER = "WHISPER",
}
local CHAT_COMMAND_ENGLISH = {
    ["/s"] = "SAY", ["/say"] = "SAY", ["/y"] = "YELL", ["/yell"] = "YELL", ["/sh"] = "YELL", ["/shout"] = "YELL",
    ["/p"] = "PARTY", ["/party"] = "PARTY", ["/ra"] = "RAID", ["/raid"] = "RAID", ["/rw"] = "RAID",
    ["/i"] = "INSTANCE_CHAT", ["/instance"] = "INSTANCE_CHAT", ["/g"] = "GUILD", ["/guild"] = "GUILD",
    ["/o"] = "OFFICER", ["/officer"] = "OFFICER",
    ["/w"] = "WHISPER", ["/whisper"] = "WHISPER", ["/t"] = "WHISPER", ["/tell"] = "WHISPER",
}
local chatCommands
local function ChatCommandKind(cmd)
    if not chatCommands then
        chatCommands = {}
        for word, kind in pairs(CHAT_COMMAND_ENGLISH) do chatCommands[word] = kind end
        for token, kind in pairs(CHAT_COMMAND_TOKENS) do
            for i = 1, 10 do
                local word = _G["SLASH_" .. token .. i]
                if type(word) == "string" then chatCommands[slower(word)] = kind end
            end
        end
    end
    return chatCommands[slower(cmd)]
end

-- A numbered or named channel (/1, /trade): the conversation key, name and
-- index of a joined one, or nil.
function UI:ChatChannelForCommand(cmd)
    local number = tonumber(cmd:sub(2))
    local wanted = slower(cmd:sub(2))
    local list = GetChannelList and { GetChannelList() } or {}
    for i = 1, #list, 3 do
        local index, baseName, disabled = list[i], list[i + 1], list[i + 2]
        local name = type(baseName) == "string" and self:GetPlainChatLabel(baseName) or ""
        name = name:match("^(.-)%s+%-%s+") or name
        if name ~= "" and not disabled and (index == number or slower(name) == wanted) then
            return self:GetChatConversationKey("channel", "#" .. name, name), name, index
        end
    end
    return nil
end

-- /say, /trade or /1 typed where a name goes: that room's chat opens with
-- what was written so far in its box. /w Name stays a whisper to Name.
-- True when the words were a place; a name to whisper comes back second.
function UI:GoToChatCommand(typed)
    local cmd, rest = typed:match("^(/%S+)%s*(.-)%s*$")
    if not cmd then return false end
    local kind = ChatCommandKind(cmd)
    if kind == "WHISPER" then return false, rest ~= "" and rest or nil end
    local store = self:GetChatConversationStore()
    local key, label, index, source
    local def = kind and CHAT_TYPE_CHANNELS[kind]
    if def then
        key, label, source = self:GetChatConversationKey("channel", def.key, def.label), def.label, def.label
    else
        key, label, index = self:ChatChannelForCommand(cmd)
        source = "Channel"
    end
    if not key then return false end
    local convo = store.byKey[key]
    if not convo then
        convo = { key = key, messages = {}, label = label, kind = "channel", source = source }
        store.byKey[key] = convo
        store.order[#store.order + 1] = key
    end
    if index then convo.channelIndex = index end
    local view = UI._chatComposer.frame and UI._chatComposer.frame.messengerView
    local words = view and view.replyEditBox and view.replyEditBox:GetText() or ""
    local c = UI._chatComposer
    wipe(c.recipients)
    wipe(c.recipientLookup)
    c.composeInPlace = nil
    self:SaveChatDraftForKey(key, words)
    self:SelectChatConversation(key)
    if view and view.replyEditBox then self:FocusChatEditBox(view.replyEditBox) end
    return true
end

function UI:ConsumeChatRecipientInput(preferSuggestion)
    local frame = UI._chatComposer.frame
    local activeEdit = self:GetActiveRecipientContext()
    if not (frame and activeEdit) then return false end

    local entry
    if preferSuggestion and frame.suggestionMenu and frame.suggestionMenu:IsShown() then
        entry = UI._chatComposer.suggestions[UI._chatComposer.suggestionIndex or 1]
    end

    local consumed
    if entry then
        consumed = self:AddChatRecipientFromEntry(entry)
    else
        local typed = strtrim(activeEdit:GetText() or "")
        if typed:sub(1, 1) == "/" then
            local went, name = self:GoToChatCommand(typed)
            if went then
                UI._chatComposer.suppressTargetText = true
                activeEdit:SetText("")
                UI._chatComposer.suppressTargetText = nil
                return true
            end
            -- /w Name: Name; any other slash word is not a name.
            if not name then return false end
            typed = name
        end
        consumed = self:AddManualChatRecipients(typed)
    end

    if consumed then
        UI._chatComposer.showAllContacts = nil
        UI._chatComposer.suppressTargetText = true
        activeEdit:SetText("")
        activeEdit:SetCursorPosition(0)
        UI._chatComposer.suppressTargetText = nil
        self:SetChatComposerStatus("")
        self:RefreshChatComposerRecipients()
        self:RefreshChatRecipientSuggestions()
    end
    return consumed
end

function UI:HandleChatRecipientTextChanged()
    local frame = UI._chatComposer.frame
    local activeEdit = self:GetActiveRecipientContext()
    if not (frame and activeEdit) then return end
    if UI._chatComposer.suppressTargetText then return end

    UI._chatComposer.showAllContacts = nil
    local raw = activeEdit:GetText() or ""
    -- "Name: words": Name is the recipient and the words start the message
    -- (a character name has no colon). A slash command keeps its own path.
    local colonName, words = raw:match("^%s*([^:/][^:]-)%s*:%s?(.*)$")
    if colonName and self:AddManualChatRecipients(colonName) then
        UI._chatComposer.suppressTargetText = true
        activeEdit:SetText("")
        UI._chatComposer.suppressTargetText = nil
        local view = frame.messengerView
        local box = activeEdit == (view and view.headerRecipientEdit) and view.replyEditBox or frame.messageEditBox
        self:RefreshChatComposerRecipients()
        self:RefreshChatRecipientSuggestions()
        if box then
            box:SetText((box:GetText() or "") .. words)
            self:FocusChatEditBox(box)
            box:SetCursorPosition(#(box:GetText() or ""))
        end
        return
    end
    local lastSep
    for pos in raw:gmatch("()[,;]") do
        lastSep = pos
    end
    if lastSep then
        local complete = raw:sub(1, lastSep - 1)
        local tail = strtrim(raw:sub(lastSep + 1) or "")
        self:AddManualChatRecipients(complete)
        UI._chatComposer.suppressTargetText = true
        activeEdit:SetText(tail)
        activeEdit:SetCursorPosition(#tail)
        UI._chatComposer.suppressTargetText = nil
    end

    self:RefreshChatComposerRecipients()
    self:RefreshChatRecipientSuggestions()
end

function UI:RefreshChatSuggestionSelection()
    local frame = UI._chatComposer.frame
    if not (frame and frame.suggestionButtons) then return end
    local selected = UI._chatComposer.suggestionIndex or 1
    for i = 1, #frame.suggestionButtons do
        local button = frame.suggestionButtons[i]
        local active = button:IsShown() and i == selected
        if active then PaintChatSuggestionSelection(button.bg) end
        button.bg:SetShown(active)
        if active then
            button.text:SetTextColor(ChatAccentGlyphColor())
            if button.subtext then button.subtext:SetTextColor(0.74, 0.68, 0.52, 1) end
        else
            PaintChatThemedText(button.text)
            if button.subtext and button.entry then
                button.subtext:SetTextColor(button.entry.online == false and 0.48 or 0.62,
                    button.entry.online == false and 0.48 or 0.62,
                    button.entry.online == false and 0.50 or 0.65, 1)
            end
        end
    end
end

function UI:NavigateChatRecipientSuggestion(delta)
    local c = UI._chatComposer
    local count = #c.suggestions
    if count == 0 then return false end
    c.suggestionIndex = ((c.suggestionIndex or 1) + delta - 1) % count + 1
    self:RefreshChatSuggestionSelection()
    return true
end

function UI:RefreshChatRecipientSuggestions()
    local frame = UI._chatComposer.frame
    local activeEdit, activeShell = self:GetActiveRecipientContext()
    if not (frame and frame.suggestionMenu and activeEdit) then return end

    -- The in-place To: field is always a whisper; the compose view defers to
    -- its channel selector.
    local needsRecipients = true
    if activeEdit == frame.targetEditBox then
        local def = self:GetChatChannelDef()
        needsRecipients = def.needsRecipients and true or false
    end
    local query = strtrim(activeEdit:GetText() or "")
    local showAll = UI._chatComposer.showAllContacts and true or false
    local shouldShow = needsRecipients and (query ~= "" or showAll)
    local suggestions = UI._chatComposer.suggestions
    wipe(suggestions)

    if shouldShow then
        if #UI._chatComposer.friendEntries == 0 then
            self:RefreshChatFriendEntries()
        end
        local q = slower(query)
        local entries = UI._chatComposer.friendEntries
        for i = 1, #entries do
            local entry = entries[i]
            if not UI._chatComposer.recipientLookup[entry.key] then
                local score = showAll and ((entry.priority or 9) * 100) or self:ScoreChatContact(entry, q)
                if score then
                    entry._chatSuggestScore = score
                    suggestions[#suggestions + 1] = entry
                end
            end
        end
        tsort(suggestions, CompareChatSuggestions)
        if q ~= "" and not showAll then
            local manualKey = "player:" .. q
            if not UI._chatComposer.recipientLookup[manualKey] then
                suggestions[#suggestions + 1] = {
                    kind = "player",
                    id = query,
                    name = query,
                    label = query,
                    key = manualKey,
                    source = "Manual",
                    subtext = "Use typed name",
                    online = true,
                    _chatSuggestScore = 999,
                }
            end
        end
    end

    local maxSuggestions = #frame.suggestionButtons
    for i = #suggestions, maxSuggestions + 1, -1 do
        suggestions[i] = nil
    end
    UI._chatComposer.suggestionIndex = mmin(UI._chatComposer.suggestionIndex or 1, mmax(#suggestions, 1))

    for i = 1, #frame.suggestionButtons do
        local button = frame.suggestionButtons[i]
        local entry = suggestions[i]
        if entry then
            button.entry = entry
            button.initial:SetText(entry.initial
                or self:GetChatRecipientInitial(entry.initialLabel, entry.label, entry.name or entry.key))
            button.text:SetText(entry.label)
            if button.initialBg then
                -- Seed through the conversation key so a contact's icon color
                -- matches an existing conversation with them (entry keys skip
                -- realm qualification; conversation keys do not).
                local convoKey = self:GetChatConversationKey(entry.kind, entry.id, entry.name or entry.label)
                local r, g, b = self:GetChatRecipientColor(convoKey)
                ns.SetRoundedRectFill(button.initialBg, r, g, b, 1, true)
                PaintAvatar(button.initialBg, button.initial, self:GetChatConversationStore().byKey[convoKey])
            end
            if button.subtext then
                button.subtext:SetText(entry.subtext or entry.source or "")
                button.subtext:SetTextColor(entry.online == false and 0.48 or 0.62,
                    entry.online == false and 0.48 or 0.62,
                    entry.online == false and 0.50 or 0.65, 1)
            end
            button:Show()
        else
            button.entry = nil
            button:Hide()
        end
    end
    -- The menu drops under whichever To: shell owns the query.
    if activeShell and #suggestions > 0 then
        frame.suggestionMenu:ClearAllPoints()
        frame.suggestionMenu:SetPoint("TOPLEFT", activeShell, "BOTTOMLEFT", 0, -4)
        frame.suggestionMenu:SetPoint("RIGHT", activeShell, "RIGHT", 0, 0)
    end
    frame.suggestionMenu:SetShown(#suggestions > 0)
    self:RefreshChatSuggestionSelection()
end

function UI:EnsureChatRecipientChip(frame, index)
    frame.recipientChips = frame.recipientChips or {}
    local chip = frame.recipientChips[index]
    if chip then return chip end

    chip = CreateFrame("Button", nil, frame.targetShell)
    frame.recipientChips[index] = chip
    chip:SetSize(24, 24)
    ns.CreateRoundedRectBorder(chip)
    ns.SetRoundedRectBarHeight(chip, 24)
    ns.SetRoundedRectBorderBgAlpha(chip, 1)
    ns.SetRoundedRectBorderEdgeShown(chip, false)
    ns.SetRoundedRectFill(chip, 0.16, 0.16, 0.18, 1, true)
    chip.text = chip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chip.text:SetPoint("CENTER", 0, 0)
    chip.text:SetTextColor(1, 1, 1, 1)
    if chip.text.SetDrawLayer then chip.text:SetDrawLayer("OVERLAY", 7) end
    chip:SetScript("OnEnter", function(self)
        ns.SetRoundedRectFill(self,
            mmin((self.normalR or 0.16) + 0.08, 1),
            mmin((self.normalG or 0.16) + 0.08, 1),
            mmin((self.normalB or 0.18) + 0.08, 1), 1, true)
        if self.fullLabel then
            ShowChatTipDelayed(self, "ANCHOR_TOP", self.fullLabel .. "\nClick to remove")
        end
    end)
    chip:SetScript("OnLeave", function(self)
        ns.SetRoundedRectFill(self, self.normalR or 0.16, self.normalG or 0.16, self.normalB or 0.18, 1, true)
        HideChatTip(self)
    end)
    chip:SetScript("OnClick", function(self)
        UI:RemoveChatRecipient(self.recipientKey)
        -- The To: field the chip sits in: the compose view's or the header's.
        local edit = UI:GetActiveRecipientContext()
        if edit then edit:SetFocus() end
    end)
    ns.ShadeText(chip)
    return chip
end

function UI:EnsureChatRecipientOverflowChip(frame)
    if frame.recipientOverflowChip then return frame.recipientOverflowChip end
    local chip = self:EnsureChatRecipientChip(frame, 99)
    frame.recipientOverflowChip = chip
    chip:SetScript("OnClick", nil)
    chip:SetScript("OnEnter", function(self)
        ns.SetRoundedRectFill(self,
            mmin((self.normalR or 0.20) + 0.08, 1),
            mmin((self.normalG or 0.20) + 0.08, 1),
            mmin((self.normalB or 0.23) + 0.08, 1), 1, true)
        if self.fullLabel then
            ShowChatTipDelayed(self, "ANCHOR_TOP", self.fullLabel)
        end
    end)
    chip:SetScript("OnLeave", function(self)
        ns.SetRoundedRectFill(self, self.normalR or 0.20, self.normalG or 0.20, self.normalB or 0.23, 1, true)
        HideChatTip(self)
    end)
    return chip
end

function UI:RefreshChatComposerRecipients()
    local frame = UI._chatComposer.frame
    local activeEdit, activeShell = self:GetActiveRecipientContext()
    if not (frame and activeShell and activeEdit) then return end
    local view = frame.messengerView
    local inHeader = view and activeShell == view.headerRecipientShell

    local chips = frame.recipientChips or {}
    for i = 1, #chips do chips[i]:Hide() end

    local c = UI._chatComposer
    local chipLineH = self:GetChatFontLineHeight(frame.recipientChips and frame.recipientChips[1]
        and frame.recipientChips[1].text, 12)
    local chipSize = mmax(24, chipLineH + 10)
    local chipStep = chipSize + 4
    local shellW = activeShell:GetWidth() or 360
    local maxVisible = mmax(1, mmin(8, math.floor((shellW - 92) / chipStep)))
    -- The header To: field starts its chips after the "To:" label.
    local x = 8
    if inHeader and view.headerRecipientToLabel then
        x = 10 + (view.headerRecipientToLabel:GetStringWidth() or 20) + 8
    end
    local visible = mmin(#c.recipients, maxVisible)
    for i = 1, visible do
        local recipient = c.recipients[i]
        local chip = self:EnsureChatRecipientChip(frame, i)
        chip:SetSize(chipSize, chipSize)
        ns.SetRoundedRectBarHeight(chip, chipSize)
        chip.recipientKey = recipient.key
        chip.fullLabel = recipient.label
        chip.text:SetText(self:GetChatRecipientInitial(recipient.initialLabel, recipient.label,
            recipient.name or recipient.key))
        chip.normalR, chip.normalG, chip.normalB = self:GetChatRecipientColor(
            self:GetChatConversationKey(recipient.kind, recipient.id, recipient.name or recipient.label))
        ns.SetRoundedRectFill(chip, chip.normalR, chip.normalG, chip.normalB, 1, true)
        chip:ClearAllPoints()
        chip:SetParent(activeShell)
        chip:SetFrameLevel(activeShell:GetFrameLevel() + 2)
        chip:SetPoint("LEFT", activeShell, "LEFT", x, 0)
        chip:Show()
        x = x + chipStep
    end

    if #c.recipients > maxVisible then
        local hidden = #c.recipients - maxVisible
        local chip = self:EnsureChatRecipientOverflowChip(frame)
        local labels = {}
        for i = maxVisible + 1, #c.recipients do
            labels[#labels + 1] = c.recipients[i].label
        end
        chip.recipientKey = nil
        chip.fullLabel = tconcat(labels, ", ")
        chip.text:SetText("+" .. hidden)
        chip.normalR, chip.normalG, chip.normalB = ChatSurfaceColor("chip")
        ns.SetRoundedRectFill(chip, chip.normalR, chip.normalG, chip.normalB, 1, true)
        chip:ClearAllPoints()
        chip:SetParent(activeShell)
        chip:SetFrameLevel(activeShell:GetFrameLevel() + 2)
        chip:SetPoint("LEFT", activeShell, "LEFT", x, 0)
        chip:SetSize(chipSize + 6, chipSize)
        ns.SetRoundedRectBarHeight(chip, chipSize)
        chip:Show()
        x = x + chipStep + 6
    elseif frame.recipientOverflowChip then
        frame.recipientOverflowChip:Hide()
    end

    local maxInputLeft = mmax(120, shellW - 108)
    local inputLeft = mmin(x + 2, maxInputLeft)
    activeEdit:ClearAllPoints()
    activeEdit:SetPoint("LEFT", activeShell, "LEFT", inputLeft, 0)
    if not inHeader and frame.targetDropdownButton then
        activeEdit:SetPoint("RIGHT", frame.targetDropdownButton, "LEFT", -4, 0)
    else
        activeEdit:SetPoint("RIGHT", activeShell, "RIGHT", inHeader and -10 or -8, 0)
    end
    if inHeader then
        if view.headerRecipientPlaceholder then
            view.headerRecipientPlaceholder:ClearAllPoints()
            view.headerRecipientPlaceholder:SetPoint("LEFT", activeEdit, "LEFT", 0, 0)
            view.headerRecipientPlaceholder:SetShown(#c.recipients == 0
                and (activeEdit:GetText() or "") == "")
        end
    elseif frame.targetPlaceholder then
        frame.targetPlaceholder:SetShown(#c.recipients == 0 and (activeEdit:GetText() or "") == "")
    end
    self:RefreshChatComposerSendState()
end

function UI:RefreshChatComposerSendState()
    local frame = UI._chatComposer.frame
    if not frame or not frame.sendButton then return end
    self:UpdateChatCharCounter(frame.messageEditBox, frame.messageCounter)
    local message = frame.messageEditBox and strtrim(frame.messageEditBox:GetText() or "") or ""
    local def = self:GetChatChannelDef()
    local ready = message ~= "" and ((not def.needsRecipients) or #UI._chatComposer.recipients > 0)
    if ready then
        frame.sendButton:Enable()
        frame.sendButton:SetAlpha(1)
    else
        frame.sendButton:Disable()
        frame.sendButton:SetAlpha(0.50)
    end
end

function UI:LayoutChatComposer()
    local frame = UI._chatComposer.frame
    if not frame then return end
    local form = frame._chatForm or {}
    -- The labels a column as wide as the widest, the fields one width to
    -- the window's right at the margin its left has.
    local pad, labelGap, rowGap = form.pad or 16, form.labelGap or 10, form.rowGap or 6
    local labelW = 0
    for _, label in ipairs({ frame.chatLabel, frame.targetLabel, frame.messageLabel }) do
        local w = label.GetUnboundedStringWidth and label:GetUnboundedStringWidth() or label:GetStringWidth()
        labelW = mmax(labelW, w or 0)
    end
    local labelRightX = pad + math.ceil(labelW)
    local fieldLeftX = labelRightX + labelGap
    local fieldHeight = mmax(form.fieldHeight or 26, self:GetChatFontLineHeight(frame.channelText, 14) + 10)
    local formTopY = form.formTopY or 52
    local def = self:GetChatChannelDef()
    local showTargets = def.needsRecipients
    frame.channelButton:ClearAllPoints()
    frame.channelButton:SetPoint("TOPLEFT", frame, "TOPLEFT", fieldLeftX, -formTopY)
    frame.channelButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, -formTopY)
    frame.channelButton:SetHeight(fieldHeight)
    local send = frame.sendButton
    if send then send:SetWidth(math.ceil(send.text:GetStringWidth() or 80) + 24) end
    frame.chatLabel:ClearAllPoints()
    frame.chatLabel:SetPoint("RIGHT", frame.channelButton, "LEFT", -labelGap, 0)
    local targetTop = -formTopY - fieldHeight - rowGap
    frame.targetPanel:ClearAllPoints()
    frame.targetPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", fieldLeftX, targetTop)
    frame.targetPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, targetTop)
    frame.targetPanel:SetHeight(fieldHeight)
    if frame.targetEditBox then frame.targetEditBox:SetHeight(mmax(18, fieldHeight - 6)) end
    frame.targetLabel:SetShown(showTargets)
    frame.targetPanel:SetShown(showTargets)
    if frame.suggestionMenu and not showTargets then frame.suggestionMenu:Hide() end
    frame.targetLabel:ClearAllPoints()
    frame.targetLabel:SetPoint("RIGHT", frame.targetPanel, "LEFT", -labelGap, 0)
    frame.messageLabel:ClearAllPoints()
    frame.messageShell:ClearAllPoints()
    local messageTop = showTargets and (targetTop - fieldHeight - rowGap) or targetTop
    -- The label level with the box's first line.
    frame.messageLabel:SetPoint("TOPRIGHT", frame, "TOPLEFT", labelRightX, messageTop - 10)
    frame.messageShell:SetPoint("TOPLEFT", frame, "TOPLEFT", fieldLeftX, messageTop)
    frame.messageShell:SetPoint("RIGHT", frame, "RIGHT", -pad, 0)
    frame.messageShell:SetPoint("BOTTOM", frame.footer, "TOP", 0, 8)
end

function UI:RefreshChatComposerChannel()
    local frame = UI._chatComposer.frame
    if not frame then return end
    local def = self:GetChatChannelDef()
    frame.channelText:SetText(def.label)
    self:LayoutChatComposer()
    self:RefreshChatComposerSendState()
    self:RefreshChatRecipientSuggestions()
end

function UI:ToggleChatChannelMenu()
    local frame = UI._chatComposer.frame
    if not frame then return end
    if frame.channelMenu:IsShown() then
        frame.channelMenu:Hide()
        return
    end
    if frame.suggestionMenu then frame.suggestionMenu:Hide() end
    frame.channelMenu:Show()
end

function UI:ToggleChatContactDropdown()
    local frame = UI._chatComposer.frame
    if not (frame and frame.targetEditBox) then return end
    UI._chatComposer.showAllContacts = not UI._chatComposer.showAllContacts
    if UI._chatComposer.showAllContacts then
        self:RefreshChatFriendEntries()
        if frame.channelMenu then frame.channelMenu:Hide() end
        frame.targetEditBox:SetFocus()
    end
    self:RefreshChatRecipientSuggestions()
end

function UI:GetChatConversationStore()
    -- Shaped and re-keyed once per store table: keys made after are canonical
    -- already (GetChatConversationKey), so no pass runs per incoming line.
    local checked = UI._chatComposer.checkedStore
    if checked and type(EasyFindChatDB) == "table" and EasyFindChatDB.conversations == checked then
        return checked
    end
    EasyFindChatDB = type(EasyFindChatDB) == "table" and EasyFindChatDB or {}
    EasyFindChatDB.conversations = type(EasyFindChatDB.conversations) == "table"
        and EasyFindChatDB.conversations or {}
    local store = EasyFindChatDB.conversations
    store.order = type(store.order) == "table" and store.order or {}
    store.byKey = type(store.byKey) == "table" and store.byKey or {}
    store.folders = type(store.folders) == "table" and store.folders or {}
    store.chars = type(store.chars) == "table" and store.chars or {}
    self:CanonicalizeChatConversationStore(store)
    UI._chatComposer.checkedStore = store
    return store
end

function UI:GetChatDraftStore()
    EasyFindChatDB = type(EasyFindChatDB) == "table" and EasyFindChatDB or {}
    EasyFindChatDB.drafts = type(EasyFindChatDB.drafts) == "table" and EasyFindChatDB.drafts or {}
    return EasyFindChatDB.drafts
end

function UI:SaveChatDraftForKey(key, text)
    if not key then return end
    local drafts = self:GetChatDraftStore()
    text = tostring(text or "")
    drafts[key] = text ~= "" and text or nil
end

-- Drafts named in the chat list: on unless turned off.
function UI:ShowsChatDrafts()
    return ChatDB().showDrafts ~= false
end

function UI:SaveCurrentChatReplyDraft()
    local frame = UI._chatComposer.frame
    local view = frame and frame.messengerView
    if not (view and view.replyEditBox) then return end
    self:SaveChatDraftForKey(UI._chatComposer.selectedConversationKey, view.replyEditBox:GetText() or "")
end

function UI:LoadChatDraftForKey(key)
    local frame = UI._chatComposer.frame
    local view = frame and frame.messengerView
    if not (view and view.replyEditBox) then return end
    local drafts = self:GetChatDraftStore()
    local text = key and drafts[key] or ""
    if view.replyEditBox:GetText() ~= (text or "") then
        UI._chatComposer.loadingReplyDraft = true
        view.replyEditBox:SetText(text or "")
        view.replyEditBox:SetCursorPosition(#(text or ""))
        UI._chatComposer.loadingReplyDraft = nil
    end
end

function UI:GetChatConversationKey(kind, id, label)
    kind = kind or "player"
    id = id or label or "unknown"
    if kind == "player" then
        -- Realm-qualified identity: two same-named players on different realms
        -- must not collapse into one conversation. Display shortens, keys do not.
        -- Bare names are same-realm by definition (whisper targets without a
        -- realm resolve locally), so they get the player's own realm appended;
        -- incoming event authors arrive already qualified and land on the same
        -- key, and canonicalization migrates old short-keyed conversations.
        id = self:GetPlainChatLabel(id)
        if id == "" then id = self:GetPlainChatLabel(label) end
        if id ~= "" and not sfind(id, "-", 1, true) then
            local realm = GetNormalizedRealmName and GetNormalizedRealmName()
            if realm and realm ~= "" then id = id .. "-" .. realm end
        end
    elseif kind == "bn" then
        local cleanID = self:GetPlainChatLabel(id)
        if cleanID ~= "" then id = cleanID end
        if not id or id == "" or id == "unknown" then
            local cleanLabel = self:GetPlainChatLabel(label)
            id = cleanLabel ~= "" and cleanLabel or label or "Battle.net"
        end
    end
    return kind .. ":" .. slower(tostring(id))
end

function UI:GetCanonicalChatConversationKey(key, convo)
    if not convo then return key end
    if convo.kind == "player" then
        local keyID = key and tostring(key):match("^player:(.+)$")
        -- A key naming its realm keeps it: rebuilt from a bare targetName it
        -- would take the realm logged in now and merge two people.
        if keyID and sfind(keyID, "-", 1, true) then return key end
        return self:GetChatConversationKey("player", convo.targetName or convo.label or keyID or key, convo.label)
    elseif convo.kind == "bn" then
        -- By BattleTag. One with none is a past session's unless this
        -- session made it: its ID is another friend's now.
        local tag = convo.battleTag
        if type(tag) == "string" and tag ~= "" then return "bn:" .. slower(tag) end
        local keyID = tostring(key):match("^bn:(.+)$") or tostring(key)
        if UI._chatComposer.bnSessionIDs[key] or keyID:find("^past:") then return key end
        return "bn:past:" .. tostring(convo.lastTime or 0) .. ":" .. keyID
    elseif convo.kind == "channel" then
        local keyID = key and tostring(key):match("^channel:(.+)$")
        return self:GetChatConversationKey("channel", keyID or convo.label or convo.source or key, convo.label)
    end
    return key
end

function UI:MergeChatConversation(target, source)
    if not (target and source and target ~= source) then return target end
    target.kind = target.kind or source.kind
    target.source = target.source or source.source
    target.label = target.label or source.label
    target.targetID = target.targetID or source.targetID
    target.battleTag = target.battleTag or source.battleTag
    target.targetName = target.targetName or source.targetName
    target.initialLabel = target.initialLabel or source.initialLabel
    target.icon = target.icon or source.icon
    target.legacy = target.legacy or source.legacy
    if type(source.chars) == "table" then
        target.chars = type(target.chars) == "table" and target.chars or {}
        for index in pairs(source.chars) do target.chars[index] = true end
    end
    target.hideUnread = target.hideUnread or source.hideUnread
    target.unread = not target.hideUnread and (target.unread or 0) + (source.unread or 0) or 0

    local merged, seen = {}, {}
    local function addMessages(messages)
        if type(messages) ~= "table" then return end
        for i = 1, #messages do
            local msg = messages[i]
            if msg and msg.text then
                local sig = tostring(msg.time or "") .. "\t" .. tostring(msg.outgoing and 1 or 0)
                    .. "\t" .. tostring(msg.text)
                if not seen[sig] then
                    seen[sig] = true
                    merged[#merged + 1] = msg
                end
            end
        end
    end
    local wasTrimmed = (type(target.messages) == "table" and target.messages.trimmed)
        or (type(source.messages) == "table" and source.messages.trimmed) or nil
    addMessages(target.messages)
    addMessages(source.messages)
    tsort(merged, CompareChatMessagesByTime)
    local retention = GetChatRetentionSettings()
    local maxMessages = retention and retention.maxMessagesPerConversation
    while maxMessages and #merged > maxMessages do
        tremove(merged, 1)
        wasTrimmed = true
    end
    merged.trimmed = wasTrimmed
    target.messages = merged

    local last = merged[#merged]
    if last then
        target.lastMessage = last.text
        target.lastTime = last.time
    elseif (source.lastTime or 0) > (target.lastTime or 0) then
        target.lastMessage = source.lastMessage
        target.lastTime = source.lastTime
    end
    return target
end

function UI:RebuildChatConversationOrder(store)
    wipe(store.order)
    for key in pairs(store.byKey) do
        store.byKey[key].key = key
        tinsert(store.order, key)
    end
    chatOrderSortStore = store
    tsort(store.order, CompareChatOrderRecency)
    chatOrderSortStore = nil
end

function UI:CanonicalizeChatConversationStore(store)
    if not (store and store.byKey) or UI._chatComposer.canonicalizingConversations then return end
    UI._chatComposer.canonicalizingConversations = true

    -- Renames are collected first: adding keys during pairs() is undefined.
    local renames
    for key, convo in pairs(store.byKey) do
        if type(convo) == "table" and convo.kind == "bn" and not UI._chatComposer.bnSessionIDs[key] then
            self:CleanChatBNConversation(convo)
        end
        local canonicalKey = self:GetCanonicalChatConversationKey(key, convo)
        if canonicalKey and canonicalKey ~= key then
            renames = renames or {}
            renames[#renames + 1] = { key, convo, canonicalKey }
        end
    end
    local changed = false
    local drafts = ChatDB().drafts
    for i = 1, renames and #renames or 0 do
        local key, convo, canonicalKey = renames[i][1], renames[i][2], renames[i][3]
        if store.byKey[key] == convo then
            local target = store.byKey[canonicalKey]
            if target then
                self:MergeChatConversation(target, convo)
            else
                store.byKey[canonicalKey] = convo
                convo.key = canonicalKey
            end
            store.byKey[key] = nil
            if drafts and drafts[key] and not drafts[canonicalKey] then
                drafts[canonicalKey] = drafts[key]
                drafts[key] = nil
            end
            if UI._chatComposer.selectedConversationKey == key then
                UI._chatComposer.selectedConversationKey = canonicalKey
            end
            changed = true
        end
    end
    if changed then
        self:RebuildChatConversationOrder(store)
        if chatNS.Views then chatNS.Views:Forget() end
    end
    UI._chatComposer.canonicalizingConversations = nil
end

function UI:GetChatPlayerName()
    -- The core's name carries the surname on WoW Forever.
    if ns.PlayerName then
        local full = ns.PlayerName()
        if full and full ~= "" then return full end
    end
    if not UnitName then return nil end
    local name = UnitName("player")
    return name and self:GetChatPlayerShortName(name) or nil
end

-- The class token (MAGE) a chat event's GUID belongs to, or nil; a value
-- the client keeps secret is never read.
local issecretvalue = issecretvalue
function UI:GetChatClassOfGUID(guid)
    if not (guid and GetPlayerInfoByGUID) or (issecretvalue and issecretvalue(guid)) or guid == "" then return nil end
    local ok, _, token = pcall(GetPlayerInfoByGUID, guid)
    if not ok or (issecretvalue and issecretvalue(token)) or type(token) ~= "string" or token == "" then return nil end
    return token
end

function UI:GetChatPlayerClass()
    if UnitClassBase then return UnitClassBase("player") end
    return UnitClass and select(2, UnitClass("player")) or nil
end

-- A name in its class's color (Extensions > Chat), else as it was.
function UI:WrapChatClassName(name, token)
    if not (name and token) or ChatDB().classColors == false then return name end
    local c = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(token))
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[token])
    if not c then return name end
    local r, g, b = c.r, c.g, c.b
    -- A light theme: each class in its own hue, dark enough for its bubble.
    if ChatLight() then
        local br, bg, bb = ChatSurfaceColor("bubbleIn")
        local ir, ig, ib = ChatInk(r, g, b, br, bg, bb)
        if ir then r, g, b = ir, ig, ib else r, g, b = ChatTextColor() end
    end
    local function Hex(v) return math.floor(v * 255 + 0.5) end
    return string.format("|cff%02x%02x%02x%s|r", Hex(r), Hex(g), Hex(b), name)
end

function UI:IsChatAuthorPlayer(author, guid)
    -- A readable GUID decides: a same-named player elsewhere is not us.
    if guid and UnitGUID and not (issecretvalue and issecretvalue(guid)) and guid ~= "" then
        return guid == UnitGUID("player")
    end
    local playerName = self:GetChatPlayerName()
    if not (playerName and author) then return false end
    return self:GetChatPlayerShortName(author) == playerName
end

function UI:RecordChatChannelMessage(def, text, outgoing, timestamp, author, class)
    if not def then return false end
    local key = self:GetChatConversationKey("channel", def.key, def.label)
    local senderLabel = outgoing and (self:GetChatPlayerName() or "You")
        or self:GetChatPlayerShortName(author or def.label)
    self:AddChatConversationMessage(key, def.label, "channel", text, outgoing, def.label, timestamp, {
        senderLabel = senderLabel ~= "" and senderLabel or def.label,
        senderName = not outgoing and author or nil,
        senderClass = outgoing and self:GetChatPlayerClass() or class,
    })
    return true
end

function UI:RecordChatPlayerWhisper(text, targetName, outgoing, timestamp, class)
    targetName = self:GetPlainChatLabel(targetName or "")
    if targetName == "" then targetName = outgoing and "Whisper" or "Unknown" end
    local key = self:GetChatConversationKey("player", targetName, targetName)
    local convo = self:AddChatConversationMessage(key, targetName, "player", text, outgoing, "Whisper", timestamp, {
        senderLabel = outgoing and (self:GetChatPlayerName() or "You") or self:GetChatPlayerShortName(targetName),
    })
    if convo then
        convo.targetName = targetName
        -- Either way the GUID is the other player's.
        if class then convo.class = class end
    end
    return true
end

-- A Battle.net friend's ID and name token change hands at each login: a
-- chat is kept by BattleTag, and both are read from the friend list.
function UI:GetChatBNBattleTag(id)
    if not (id and C_BattleNet and C_BattleNet.GetAccountInfoByID) then return nil end
    local ok, info = xpcall(C_BattleNet.GetAccountInfoByID, Utils.ErrorHandler, tonumber(id) or id)
    local tag = ok and info and info.battleTag
    if type(tag) ~= "string" or (issecretvalue and issecretvalue(tag)) or tag == "" then return nil end
    return tag
end

-- "Name#1234" without its number: the friend's name as plain text.
function UI:GetChatBNTagName(battleTag)
    if type(battleTag) ~= "string" then return nil end
    local name = battleTag:match("^(.-)#%d+$") or battleTag
    return name ~= "" and name or nil
end

-- The friend the account lists under a BattleTag now, or nil. The index
-- map is read again when the list moved under it.
function UI:GetChatBNFriendByTag(battleTag)
    local bn = C_BattleNet
    if type(battleTag) ~= "string" or battleTag == ""
        or not (bn and bn.GetFriendAccountInfo and bn.GetNumFriends) then return nil end
    local c, want = UI._chatComposer, slower(battleTag)
    for _ = 1, 2 do
        local map = c.bnFriendIndex
        if not map then
            map = {}
            local ok, total = xpcall(bn.GetNumFriends, Utils.ErrorHandler)
            for i = 1, (ok and total) or 0 do
                local okInfo, info = xpcall(bn.GetFriendAccountInfo, Utils.ErrorHandler, i)
                local tag = okInfo and info and info.battleTag
                if type(tag) == "string" and not (issecretvalue and issecretvalue(tag)) and tag ~= "" then
                    map[slower(tag)] = i
                end
            end
            c.bnFriendIndex = map
        end
        local index = map[want]
        if not index then return nil end
        local ok, info = xpcall(bn.GetFriendAccountInfo, Utils.ErrorHandler, index)
        local tag = ok and info and info.battleTag
        if type(tag) == "string" and not (issecretvalue and issecretvalue(tag)) and slower(tag) == want then
            return info
        end
        c.bnFriendIndex = nil
    end
    return nil
end

-- A Battle.net chat's key: the friend's BattleTag. With none readable
-- the session's ID stands in, for this session only.
function UI:GetChatBNConversationKey(id, battleTag)
    battleTag = battleTag or self:GetChatBNBattleTag(id)
    if battleTag then return "bn:" .. slower(battleTag), battleTag end
    local key = "bn:session:" .. slower(tostring(id or "unknown"))
    if id then UI._chatComposer.bnSessionIDs[key] = id end
    return key, nil
end

-- The friend's ID this session; nil once they are off the friend list.
function UI:GetChatBNAccountID(convo, key)
    if not convo then return nil end
    local tag = convo.battleTag
    if type(tag) == "string" and tag ~= "" then
        local info = self:GetChatBNFriendByTag(tag)
        return info and info.bnetAccountID or nil
    end
    return UI._chatComposer.bnSessionIDs[key or convo.key]
end

-- The character a friend is on, by their ID this session.
function UI:GetChatBNCharacterName(id)
    if not (id and C_BattleNet and C_BattleNet.GetAccountInfoByID) then return nil end
    local ok, info = xpcall(C_BattleNet.GetAccountInfoByID, Utils.ErrorHandler, tonumber(id) or id)
    local game = ok and info and info.gameAccountInfo
    local name = game and game.characterName
    if type(name) ~= "string" or (issecretvalue and issecretvalue(name)) or name == "" then return nil end
    return name
end

-- A saved Battle.net chat keeps nothing of its session: the ID and the
-- name token name other friends after a login.
function UI:CleanChatBNConversation(convo)
    convo.targetID, convo.initial = nil, nil
    local name = self:GetChatBNTagName(convo.battleTag)
    if name then
        convo.label = name
    elseif self:GetPlainChatLabel(convo.label or "") == "" then
        convo.label = "Battle.net"
    end
    if convo.initialLabel and self:GetPlainChatLabel(convo.initialLabel) == "" then convo.initialLabel = nil end
end

function UI:GetChatConversationDisplayLabel(convo, key)
    if not convo then return nil end
    if type(convo.customLabel) == "string" and convo.customLabel ~= "" then return convo.customLabel end

    local label = convo.label or key or "Conversation"
    if convo.kind == "player" then
        local short = self:GetChatPlayerShortName(label)
        if short ~= "" then return short end
        return label
    end
    if convo.kind == "bn" then
        -- This session's name token, never a saved one.
        local info = self:GetChatBNFriendInfo(convo, key)
        local token = info and info.accountName
        if type(token) == "string" and not (issecretvalue and issecretvalue(token)) and token ~= "" then
            return token
        end
        return self:GetChatBNTagName(convo.battleTag) or label
    end
    return label
end

-- A chat's name as plain text (sorting, search, copies). A Battle.net
-- name token reads as nothing, so that chat's is its BattleTag's name.
function UI:GetChatConversationPlainLabel(convo, key)
    if not convo then return "" end
    local plain = self:GetPlainChatLabel(self:GetChatConversationDisplayLabel(convo, key) or "")
    if plain == "" and convo.kind == "bn" then
        plain = self:GetChatBNTagName(convo.battleTag) or self:GetPlainChatLabel(convo.label or "")
    end
    return plain
end

function UI:GetChatConversationInitial(convo, key, label)
    if convo and convo.kind == "bn" then
        local info = self:GetChatBNFriendInfo(convo, key)
        local game = info and info.gameAccountInfo
        local character = game and game.characterName
        if type(character) ~= "string" or (issecretvalue and issecretvalue(character)) then character = nil end
        return self:GetChatRecipientInitial(character, convo.initialLabel,
            self:GetChatBNTagName(convo.battleTag), convo.label)
    end
    if convo then
        return self:GetChatRecipientInitial(convo.initialLabel, label or convo.label, convo.targetName)
    end
    return self:GetChatRecipientInitial(label or key)
end

function UI:RecordChatBNWhisper(text, id, label, outgoing, timestamp)
    if issecretvalue and issecretvalue(id) then id = nil end
    local key, battleTag = self:GetChatBNConversationKey(id)
    local name = self:GetChatBNTagName(battleTag)
    if not name then
        name = self:GetPlainChatLabel(label or "")
        if name == "" then name = "Battle.net" end
    end
    local convo = self:AddChatConversationMessage(key, name, "bn", text, outgoing, "Battle.net", timestamp, {
        senderLabel = outgoing and (self:GetChatPlayerName() or "You") or name,
    })
    if convo then
        convo.battleTag = battleTag or convo.battleTag
        convo.targetID = nil
        convo.initialLabel = self:GetChatBNCharacterName(id) or convo.initialLabel or name
    end
    return true
end

function UI:TouchChatConversation(key, label, kind, source)
    if not key then return nil end
    local store = self:GetChatConversationStore()
    local convo = store.byKey[key]
    if not convo then
        convo = { key = key, messages = {} }
        store.byKey[key] = convo
    end
    convo.label = label or convo.label or key
    convo.kind = kind or convo.kind or "player"
    convo.source = source or convo.source or convo.kind

    for i = #store.order, 1, -1 do
        if store.order[i] == key then
            tremove(store.order, i)
            break
        end
    end
    tinsert(store.order, 1, key)

    local retention = GetChatRetentionSettings()
    local maxConvos = retention and retention.maxConversations
    -- Past the cap the oldest chat goes, never a pinned, foldered or renamed one.
    local i = #store.order
    while maxConvos and #store.order > maxConvos and i > 1 do
        local oldKey = store.order[i]
        local old = store.byKey[oldKey]
        if not (old and (old.pinned or old.folder or old.customLabel)) then
            tremove(store.order, i)
            store.byKey[oldKey] = nil
            local drafts = ChatDB().drafts
            if drafts then drafts[oldKey] = nil end
        end
        i = i - 1
    end
    return convo
end

-- Messages that name you: on unless turned off.
function UI:ShowsChatMentions()
    return ChatDB().mentions ~= false
end

local function IsWordByte(b)
    return (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b >= 128
end

-- Your character's name whole, in any case, not inside a longer word.
function UI:ChatTextNamesMe(text)
    local me = UnitName and UnitName("player")
    if type(me) ~= "string" or me == "" or (issecretvalue and issecretvalue(text)) then return false end
    local hay, needle = slower(text), slower(me)
    local from = 1
    while true do
        local s, e = sfind(hay, needle, from, true)
        if not s then return false end
        local before, after = hay:byte(s - 1), hay:byte(e + 1)
        if not (before and IsWordByte(before)) and not (after and IsWordByte(after)) then return true end
        from = e + 1
    end
end

-- A chat's unread messages that named you; counted from its last read, so
-- every way of reading it clears them.
function UI:GetChatMentionCount(convo)
    local unread = convo and tonumber(convo.unread) or 0
    if unread == 0 or not self:ShowsChatMentions() then return 0 end
    return mmin(tonumber(convo.mentions) or 0, unread)
end

-- Lines hidden from addons in a boss fight, M+ or PvP match (secret
-- values): held by ID, recorded at their own time once the lockdown ends.
-- time: the held line's while it is recorded.
local heldChat = { lines = {} }

function UI:AddChatConversationMessage(key, label, kind, text, outgoing, source, timestamp, meta)
    text = tostring(text or "")
    if text == "" then return end
    -- In a group or channel; a whisper is yours already.
    local mention = not outgoing and kind == "channel" and self:ShowsChatMentions() and self:ChatTextNamesMe(text) or nil

    local convo = self:TouchChatConversation(key, label, kind, source)
    if not convo then return end
    local messages = convo.messages
    if type(messages) ~= "table" then
        messages = {}
        convo.messages = messages
    end
    local when = timestamp or heldChat.time or time()
    -- Sent from this window in the fight: here already.
    if heldChat.time and outgoing then
        for i = #messages, mmax(1, #messages - 10), -1 do
            local m = messages[i]
            if m.outgoing and m.text == text and math.abs((m.time or 0) - when) <= 30 then return convo end
        end
    end
    local displayText = meta and meta.displayText or nil
    convo.flipMade = nil
    messages[#messages + 1] = {
        text = text,
        displayText = displayText,
        outgoing = outgoing and true or false,
        time = when,
        senderLabel = meta and meta.senderLabel or (outgoing and (self:GetChatPlayerName() or "You") or label),
        -- The author as the game sent it (realm and all): what a whisper targets.
        senderName = meta and meta.senderName or nil,
        senderClass = meta and meta.senderClass or nil,
        replyTo = meta and meta.replyTo or nil,
        forwardedFrom = meta and meta.forwardedFrom or nil,
        mention = mention,
        char = self:GetChatCharacterIndex(),
    }
    local heardOn = messages[#messages].char
    if heardOn then
        convo.chars = type(convo.chars) == "table" and convo.chars or {}
        convo.chars[heardOn] = true
    end
    self:NoteChatSpeaker(messages[#messages])
    if chatNS.Views then chatNS.Views:Heard(messages[#messages], convo) end
    convo.lastMessage = displayText or text
    convo.lastTime = when
    -- Unread unless it is in view: the window up on this chat. Closed, the
    -- chat last open counts like any other.
    local frame = UI._chatComposer.frame
    local inView = frame and frame:IsVisible() and UI._chatComposer.selectedConversationKey == key
    if not outgoing and not inView then
        -- Its count hidden: nothing counted, so nothing shows anywhere. A
        -- mention counts and sounds through a hidden count and a mute.
        if not convo.hideUnread or mention then
            if (convo.unread or 0) == 0 then convo.mentions = nil end
            convo.unread = (convo.unread or 0) + 1
            if mention then convo.mentions = (convo.mentions or 0) + 1 end
            self:UpdateChatUnreadBadge()
        end
        if mention or not self:IsChatConversationMuted(key) then self:PlayChatMessageSound() end
    end

    local retention = GetChatRetentionSettings()
    local maxMessages = retention and retention.maxMessagesPerConversation
    -- Past the cap the oldest goes, never a pinned one.
    local cut = 1
    while maxMessages and #messages > maxMessages do
        while messages[cut] and messages[cut].pinned do cut = cut + 1 end
        if cut >= #messages then break end
        tremove(messages, cut)
        -- Marks where history was cut: the messenger draws a rule above the
        -- oldest kept message so the gap reads as retention, not data loss.
        messages.trimmed = true
    end

    self:RefreshChatMessenger()
    -- A busy channel must not rebuild the chat search rows per line: with
    -- the bar closed they go stale and refill when it opens.
    local db = ns.Database
    local bar = ns.Search and ns.Search.GetSearchFrame and ns.Search:GetSearchFrame()
    if db and bar and bar:IsShown() then
        EasyFind.API.RefreshSearchProvider("chat")
    elseif db and db.MarkDynamicCategoryDirty then
        db:MarkDynamicCategoryDirty("chat")
    end
    return convo
end

function UI:AddChatConversationForRecipient(recipient, text, outgoing, meta)
    if not recipient then return end
    if recipient.kind == "bn" then
        local key, battleTag = self:GetChatBNConversationKey(recipient.id)
        local name = self:GetChatBNTagName(battleTag) or self:GetPlainChatLabel(recipient.label or "")
        if name == "" then name = "Battle.net" end
        local convo = self:AddChatConversationMessage(key, name, "bn", text, outgoing, "Battle.net", nil, meta)
        if convo then
            convo.battleTag = battleTag or convo.battleTag
            convo.initialLabel = self:GetChatBNCharacterName(recipient.id) or convo.initialLabel or name
        end
        return
    end
    local key = self:GetChatConversationKey(recipient.kind, recipient.name or recipient.id, recipient.label)
    local convo = self:AddChatConversationMessage(key, recipient.label or recipient.name, recipient.kind, text, outgoing, "Whisper", nil, meta)
    if convo then
        convo.targetID = recipient.id
        convo.targetName = recipient.name
        convo.initialLabel = recipient.initialLabel or recipient.name or recipient.label or convo.initialLabel
    end
end

function UI:AddChatConversationForChannel(def, text, outgoing, meta)
    if not def then return end
    local key = self:GetChatConversationKey("channel", def.key, def.label)
    self:AddChatConversationMessage(key, def.label, "channel", text, outgoing, def.label, nil, meta)
end

-- Away and busy replies to a whisper, and whispers that never arrived: a
-- setting, on unless turned off.
function UI:ShowsChatDeliveryNotices()
    return ChatDB().deliveryNotices ~= false
end

local function Secret(v) return issecretvalue and issecretvalue(v) end

-- Their away or busy reply, a gray line in the whisper's chat; each whisper
-- brings it again, shown once while it stays the same.
function UI:NoteChatAwayReply(event, text, author)
    if not self:ShowsChatDeliveryNotices() or Secret(text) or Secret(author) then return end
    local name = self:GetPlainChatLabel(author or "")
    if name == "" then return end
    local key = self:GetChatConversationKey("player", name, name)
    if not self:GetChatConversationStore().byKey[key] then return end
    local fmt = event == "CHAT_MSG_AFK" and (_G["CHAT_AFK_GET"] or "%s is Away From Keyboard: ")
        or (_G["CHAT_DND_GET"] or "%s does not wish to be disturbed: ")
    local line = fmt:format(self:GetChatPlayerShortName(name)) .. (text or "")
    local notes = UI._chatComposer.notes and UI._chatComposer.notes[key]
    local last = notes and notes[#notes]
    if last and last.text == line and time() - last.time < 300 then return end
    self:AddChatNote(key, line)
end

-- The newest whisper sent in the last moments, marked as never arrived
-- (kept with it: the reason under its bubble).
local function MarkChatUndelivered(convo, reason)
    local messages = convo and convo.messages
    if type(messages) ~= "table" then return end
    for i = #messages, mmax(1, #messages - 10), -1 do
        local msg = messages[i]
        if msg.outgoing and not msg.failed then
            if time() - (msg.time or 0) <= 15 then
                msg.failed = reason
                UI:QueueChatMessengerRefresh()
            end
            return
        end
    end
end

-- The game's "No player named 'X' is currently playing." names who.
local notFoundPattern
function UI:NoteChatSystemLine(text)
    local fmt = _G["ERR_CHAT_PLAYER_NOT_FOUND_S"]
    if not (fmt and type(text) == "string" and self:ShowsChatDeliveryNotices()) or Secret(text) then return end
    if not notFoundPattern then
        local escaped = fmt:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
        notFoundPattern = "^" .. escaped:gsub("%%%%s", "(.+)") .. "$"
    end
    local name = text:match(notFoundPattern)
    if not name then return end
    name = self:GetPlainChatLabel(name)
    MarkChatUndelivered(self:GetChatConversationStore().byKey[self:GetChatConversationKey("player", name, name)], text)
end

-- A Battle.net whisper to a friend gone offline.
function UI:NoteChatBNUndeliverable(presenceID)
    if not self:ShowsChatDeliveryNotices() or Secret(presenceID) then return end
    local convo = self:GetChatConversationStore().byKey[(self:GetChatBNConversationKey(presenceID))]
    if convo then MarkChatUndelivered(convo, _G["BN_WHISPER_UNDELIVERABLE"] or "Your friend is offline.") end
end

-- The client reads held lines plainly again once the lockdown ends.
function heldChat.Record()
    if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then return end
    heldChat.watch:UnregisterAllEvents()
    local lines = heldChat.lines
    heldChat.lines = {}
    for i = 1, #lines do
        local h = lines[i]
        -- A line the client let go of throws.
        local okText, text = pcall(C_ChatInfo.GetChatLineText, h.lineID)
        local okName, author = pcall(C_ChatInfo.GetChatLineSenderName, h.lineID)
        local okGUID, guid = pcall(C_ChatInfo.GetChatLineSenderGUID, h.lineID)
        if okText and okName and type(text) == "string" and not Secret(text) and not Secret(author) then
            if not okGUID or Secret(guid) then guid = nil end
            heldChat.time = h.time
            xpcall(UI.HandleChatMessageEvent, geterrorhandler(), UI, h.event, text, author, "", "", author,
                "", 0, h.channelIndex, h.baseName, 0, h.lineID, guid)
            heldChat.time = nil
        end
    end
end

-- A Battle.net line's friend is hidden too, with no lookup to find them
-- after: it shows in the game's chat alone.
function UI:HoldChatSecretLine(event, ...)
    local lineID = select(11, ...)
    if type(lineID) ~= "number" or Secret(lineID) or event == "CHAT_MSG_BN_WHISPER"
        or event == "CHAT_MSG_BN_WHISPER_INFORM" then return end
    local channelIndex, baseName = select(8, ...)
    heldChat.lines[#heldChat.lines + 1] = { event = event, lineID = lineID, time = time(),
        channelIndex = not Secret(channelIndex) and channelIndex or nil,
        baseName = not Secret(baseName) and baseName or nil }
    if not heldChat.watch then
        heldChat.watch = CreateFrame("Frame")
        -- After the dispatch: no restriction reads active during it.
        heldChat.watch:SetScript("OnEvent", function() Utils.SafeAfter(0.5, heldChat.Record) end)
    end
    Utils.RegisterEventIfValid(heldChat.watch, "ADDON_RESTRICTION_STATE_CHANGED")
end

function UI:HandleChatMessageEvent(event, ...)
    local message = ...
    local author = select(2, ...)
    local target = select(5, ...)
    local guid = select(12, ...)
    local presenceID = select(13, ...)
    if event == "CHAT_MSG_AFK" or event == "CHAT_MSG_DND" then return self:NoteChatAwayReply(event, message, author) end
    if event == "CHAT_MSG_SYSTEM" then return self:NoteChatSystemLine(message) end
    if event == "BN_CHAT_WHISPER_UNDELIVERABLE" then return self:NoteChatBNUndeliverable(message) end
    if Secret(message) or Secret(author) then return self:HoldChatSecretLine(event, ...) end
    if not message or message == "" then return end

    if event == "CHAT_MSG_WHISPER" then
        return self:RecordChatPlayerWhisper(message, author or target, false, nil, self:GetChatClassOfGUID(guid))
    elseif event == "CHAT_MSG_WHISPER_INFORM" then
        if ConsumeOwnEcho(message) then return end
        return self:RecordChatPlayerWhisper(message, author or target, true, nil, self:GetChatClassOfGUID(guid))
    elseif event == "CHAT_MSG_BN_WHISPER" then
        return self:RecordChatBNWhisper(message, presenceID, author or target, false)
    elseif event == "CHAT_MSG_BN_WHISPER_INFORM" then
        if ConsumeOwnEcho(message) then return end
        return self:RecordChatBNWhisper(message, presenceID, author or target, true)
    end

    if event == "CHAT_MSG_CHANNEL" then
        return self:RecordChatNumberedChannelMessage(message, author, guid, select(8, ...), select(9, ...))
    end

    local def = CHAT_EVENT_CHANNELS[event]
    if def then
        local outgoing = self:IsChatAuthorPlayer(author, guid)
        if outgoing and ConsumeOwnEcho(message) then return end
        return self:RecordChatChannelMessage(def, message, outgoing, nil, author, self:GetChatClassOfGUID(guid))
    end
end

-- General, Trade and the other numbered channels: one conversation per
-- channel name ("Trade - City" files under Trade). The last index seen is
-- where a typed message goes.
function UI:RecordChatNumberedChannelMessage(text, author, guid, channelIndex, baseName)
    local name = self:GetPlainChatLabel(baseName or "")
    name = name:match("^(.-)%s+%-%s+") or name
    if name == "" then return false end
    local outgoing = self:IsChatAuthorPlayer(author, guid)
    if outgoing and ConsumeOwnEcho(text) then return false end
    local senderLabel = outgoing and (self:GetChatPlayerName() or "You") or self:GetChatPlayerShortName(author or name)
    local key = self:GetChatConversationKey("channel", "#" .. name, name)
    local convo = self:AddChatConversationMessage(key, name, "channel", text, outgoing, "Channel", nil, {
        senderLabel = senderLabel ~= "" and senderLabel or name,
        senderName = not outgoing and author or nil,
        senderClass = outgoing and self:GetChatPlayerClass() or self:GetChatClassOfGUID(guid),
    })
    if convo and channelIndex then convo.channelIndex = channelIndex end
    return true
end

-- The public rooms: Say, Yell and the numbered channels (General, Trade).
function UI:IsChatPublicRoom(key)
    return key == "channel:say" or key == "channel:yell" or (type(key) == "string" and key:sub(1, 9) == "channel:#")
end

-- Muted: its unread still counts in the list, never on the chat icon. A
-- chat's own choice (its menu) wins; else only whispers start unmuted.
function UI:IsChatConversationMuted(key)
    local store = self:GetChatConversationStore()
    local convo = store and store.byKey[key]
    if convo and convo.muted ~= nil then return convo.muted == true end
    if self:IsChatPublicRoom(key) then return ChatDB().mutePublicRooms ~= false end
    -- Party, raid, instance, guild and officer chat.
    return type(key) == "string" and key:sub(1, 8) == "channel:" and ChatDB().muteGroups ~= false
end

-- On unless turned off in Extensions > Chat.

-- The list's order (the sort button): "recent" (latest activity, the
-- store's own order), "unread" (unread first, then recent) or "name".
-- The list filter's groups, each chat in one by its key.
local CHAT_FILTERS = {
    { key = "whispers", label = "Whispers" },
    { key = "guild", label = "Guild" },
    { key = "group", label = "Party and raid" },
    { key = "nearby", label = "Say and yell" },
    { key = "channels", label = "Channels" },
}

local function ChatFilterGroup(key)
    if key:sub(1, 7) == "player:" or key:sub(1, 3) == "bn:" then return "whispers" end
    if key == "channel:guild" or key == "channel:officer" then return "guild" end
    if key == "channel:party" or key == "channel:raid" or key == "channel:instance_chat" then return "group" end
    if key == "channel:say" or key == "channel:yell" then return "nearby" end
    if key:sub(1, 9) == "channel:#" then return "channels" end
    return nil
end

function UI:GetChatFilterGroup(key)
    return ChatFilterGroup(key)
end

-- Chats of the groups the filter hides leave the list.
function UI:FilterChatOrder(order)
    local hidden = ChatDB().hiddenGroups
    if not hidden then return order end
    local shown = {}
    for i = 1, #order do
        local group = ChatFilterGroup(order[i])
        if not (group and hidden[group]) then shown[#shown + 1] = order[i] end
    end
    return shown
end

-- A check per group, several at once: the menu stays open while they change.
function UI:ShowChatFilterMenu(anchor)
    local function Rows()
        local hidden = ChatDB().hiddenGroups
        local rows = {}
        for _, f in ipairs(CHAT_FILTERS) do
            rows[#rows + 1] = { text = f.label, keepOpen = true,
                icon = not (hidden and hidden[f.key]) and CHAT_CHECK_TEX or nil,
                onClick = function()
                    local set = ChatDB().hiddenGroups or {}
                    set[f.key] = not set[f.key] or nil
                    ChatDB().hiddenGroups = next(set) and set or nil
                    UI:RefreshChatMessenger()
                end }
        end
        return rows
    end
    Utils.ShowCursorMenu("EasyFindChatFilterMenu", Rows(), {
        strata = "TOOLTIP", level = 100, rowHeight = 22, iconSide = "left", rowsProvider = Rows,
        anchorFrame = anchor, point = "TOPLEFT", relativePoint = "BOTTOMLEFT", offsetX = 0, offsetY = -4,
    })
end

-- The characters chats were heard on: store.chars lists their keys, a
-- message keeps its index (msg.char), a chat the set (convo.chars).
local charIndex
local function CharIndexOf(store, key)
    local chars = store.chars
    for i = 1, #chars do
        if chars[i] == key then return i end
    end
    chars[#chars + 1] = key
    return #chars
end

function UI:GetChatCharacterIndex()
    if charIndex then return charIndex end
    local name = ns.PlayerName and ns.PlayerName()
    if type(name) ~= "string" or name == "" or name == _G["UNKNOWNOBJECT"] then return nil end
    charIndex = CharIndexOf(self:GetChatConversationStore(), ns.CurrentCharacterKey())
    self:AttributeLegacyChats()
    return charIndex
end

-- The account's characters EasyFind has seen (its bag and bank caches, the
-- chat's own list), by the name chat showed for them.
local function CharacterKeysByName(store)
    local byName = {}
    local function Add(key)
        local name = type(key) == "string" and key:match("^(.*)%-[^%-]*$")
        if not name then return end
        local list = byName[name] or {}
        byName[name] = list
        for i = 1, #list do
            if list[i] == key then return end
        end
        list[#list + 1] = key
    end
    local db = EasyFind.db or {}
    for _, cache in ipairs({ db.bagCache, db.bankCache }) do
        local chars = type(cache) == "table" and cache.chars
        for key in pairs(type(chars) == "table" and chars or {}) do Add(key) end
    end
    for i = 1, #store.chars do Add(store.chars[i]) end
    return byName
end

-- Chats from before characters were kept, once per store: an outgoing line
-- names its character when only one of the account's has that name; a
-- whisper chat whose outgoing lines all came from one character is that
-- character's.
function UI:AttributeLegacyChats()
    local store = self:GetChatConversationStore()
    if store.legacyAttributed then return end
    store.legacyAttributed = true
    local byName = CharacterKeysByName(store)
    for _, convo in pairs(store.byKey) do
        local messages = convo.legacy and convo.messages
        if type(messages) == "table" then
            for i = 1, #messages do
                local msg = messages[i]
                if msg.outgoing and not msg.char then
                    local keys = byName[self:GetPlainChatLabel(msg.senderLabel or "")]
                    if keys and #keys == 1 then
                        msg.char = CharIndexOf(store, keys[1])
                        convo.chars = type(convo.chars) == "table" and convo.chars or {}
                        convo.chars[msg.char] = true
                    end
                end
            end
            local only
            for index in pairs(type(convo.chars) == "table" and convo.chars or {}) do
                if only then
                    only = false
                    break
                end
                only = index
            end
            if only and (convo.kind == "player" or convo.kind == "bn") then
                for i = 1, #messages do messages[i].char = messages[i].char or only end
                convo.legacy = nil
            end
        end
    end
end

-- Whose chats show: this character's unless another, or all (nil), was
-- picked this session.
function UI:GetChatCharacterView()
    local pick = UI._chatComposer.charView
    if pick == "all" then return nil end
    return pick or self:GetChatCharacterIndex()
end

-- A character's name for the picker: the key's name, with its realm when
-- another character shares the name.
function UI:GetChatCharacterLabel(index)
    local chars = self:GetChatConversationStore().chars
    local key = chars[index] or "?"
    local name = key:match("^(.*)%-[^%-]*$") or key
    for i = 1, #chars do
        if i ~= index and (chars[i]:match("^(.*)%-[^%-]*$") or chars[i]) == name then return key end
    end
    return name
end

-- The character's chats; one from before (legacy) or with no line yet
-- shows for all.
function UI:FilterChatOrderByCharacter(order, store)
    local pick = self:GetChatCharacterView()
    if not pick then return order end
    local shown = {}
    for i = 1, #order do
        local convo = store.byKey[order[i]]
        if not convo or convo.legacy or not convo.chars or convo.chars[pick]
           or #(convo.messages or {}) == 0 then
            shown[#shown + 1] = order[i]
        end
    end
    return shown
end

-- A shared chat (a channel heard on two characters) keeps the picked
-- one's lines and those from before.
function UI:FilterChatMessagesByCharacter(convo, messages)
    local pick = self:GetChatCharacterView()
    if not (pick and messages and convo and convo.chars) then return messages end
    local other = false
    for index in pairs(convo.chars) do
        if index ~= pick then
            other = true
            break
        end
    end
    if not other then return messages end
    local kept = {}
    for i = 1, #messages do
        local msg = messages[i]
        if msg and (msg.char == nil or msg.char == pick) then kept[#kept + 1] = msg end
    end
    return kept
end

function UI:ShowChatCharacterMenu(anchor)
    local chars = self:GetChatConversationStore().chars
    local pick = self:GetChatCharacterView()
    local own = self:GetChatCharacterIndex()
    local function Choose(value)
        UI._chatComposer.charView = value
        UI:RefreshChatMessenger()
        UI:UpdateChatUnreadBadge()
    end
    local rows = { { text = "All characters", icon = not pick and CHAT_CHECK_TEX or nil,
        onClick = function() Choose("all") end } }
    local order = {}
    for i = 1, #chars do order[#order + 1] = i end
    table.sort(order, function(a, b)
        if (a == own) ~= (b == own) then return a == own end
        return slower(self:GetChatCharacterLabel(a)) < slower(self:GetChatCharacterLabel(b))
    end)
    for _, index in ipairs(order) do
        rows[#rows + 1] = { text = self:GetChatCharacterLabel(index), icon = pick == index and CHAT_CHECK_TEX or nil,
            onClick = function() Choose(index ~= own and index or nil) end }
    end
    Utils.ShowCursorMenu("EasyFindChatCharacterMenu", rows, {
        strata = "TOOLTIP", level = 100, rowHeight = 22, iconSide = "left",
        anchorFrame = anchor, point = "TOPLEFT", relativePoint = "BOTTOMLEFT", offsetX = 0, offsetY = -2,
    })
end

local CHAT_SORTS = {
    { key = "recent", label = "Recent activity" },
    { key = "unread", label = "Unread first" },
    { key = "name", label = "Name (A to Z)" },
}

function UI:SortChatOrder(order, store)
    local mode = ChatDB().sortMode
    if mode ~= "unread" and mode ~= "name" then return order end
    local rank, labels = {}, {}
    for i = 1, #order do
        rank[order[i]] = i
        if mode == "name" then
            local convo = store.byKey[order[i]]
            local plain = self:GetChatConversationPlainLabel(convo, order[i])
            labels[order[i]] = slower(plain ~= "" and plain or order[i])
        end
    end
    local sorted = {}
    for i = 1, #order do sorted[i] = order[i] end
    table.sort(sorted, function(a, b)
        if mode == "unread" then
            local ua = ((store.byKey[a] and store.byKey[a].unread) or 0) > 0
            local ub = ((store.byKey[b] and store.byKey[b].unread) or 0) > 0
            if ua ~= ub then return ua end
        elseif labels[a] ~= labels[b] then
            return labels[a] < labels[b]
        end
        return rank[a] < rank[b]
    end)
    return sorted
end

function UI:ShowChatSortMenu(anchor)
    local current = ChatDB().sortMode or "recent"
    local rows = {}
    for _, s in ipairs(CHAT_SORTS) do
        rows[#rows + 1] = { text = s.label, icon = s.key == current and CHAT_CHECK_TEX or nil, onClick = function()
            ChatDB().sortMode = s.key ~= "recent" and s.key or nil
            UI:RefreshChatMessenger()
        end }
    end
    Utils.ShowCursorMenu("EasyFindChatSortMenu", rows, {
        strata = "TOOLTIP", level = 100, rowHeight = 22, iconSide = "left",
        anchorFrame = anchor, point = "TOPLEFT", relativePoint = "BOTTOMLEFT", offsetX = 0, offsetY = -4,
    })
end

-- Pinned conversations first, each group in its own order.
function UI:PinChatOrder(order, store)
    local pinned, rest = {}, {}
    for i = 1, #order do
        local convo = store.byKey[order[i]]
        if convo and convo.pinned then pinned[#pinned + 1] = order[i] else rest[#rest + 1] = order[i] end
    end
    if #pinned == 0 then return order end
    for i = 1, #rest do pinned[#pinned + 1] = rest[i] end
    return pinned
end

-- The sidebar as shown: a folder takes the place of its first chat in the
-- current order, its chats opening beside it; a search lists chats alone.
-- Numbered channels in no folder and not pinned go apart, to Channels.
function UI:BuildChatSidebarEntries(order, store, searchActive)
    local folders = store.folders
    local entries, placed, channels = {}, {}, {}
    local grouped = not searchActive and chatNS.Views ~= nil
    for i = 1, #order do
        local convo = store.byKey[order[i]]
        local fid = not searchActive and convo and convo.folder
        local folder = fid and folders[fid]
        if not folder and grouped and convo and not convo.pinned and ChatFilterGroup(order[i]) == "channels" then
            channels[#channels + 1] = order[i]
        elseif not folder then
            entries[#entries + 1] = { key = order[i] }
        elseif not placed[fid] then
            placed[fid] = true
            local members = {}
            for j = i, #order do
                local c = store.byKey[order[j]]
                if c and c.folder == fid then members[#members + 1] = order[j] end
            end
            entries[#entries + 1] = { folder = fid, members = members }
        end
    end
    return entries, channels
end

-- A folder row: the accent while it holds the open chat, a step lighter
-- while its chats show beside it.
local function PaintChatFolderRow(row)
    if row.holdsSelected then return PaintChatAccentSurface(row) end
    if row.flyoutOpen or row.hovering then return UI:PaintChatListRowHover(row) end
    PaintChatSurface(row, "row")
end

-- A list row under the cursor, or a folder's with its chats out: a step
-- off the row fill, as a hovered bubble is.
function UI:PaintChatListRowHover(row)
    if ChatOnTree() then
        local c = CHAT_TREE_HOVER
        ns.SetRoundedRectFill(row, c[1], c[2], c[3], c[4], true)
        return
    end
    local r, g, b = ChatSurfaceColor("row")
    if LightChatTheme() then
        ns.SetRoundedRectFill(row, mmax(r - 0.05, 0), mmax(g - 0.05, 0), mmax(b - 0.04, 0), 1, true)
    else
        ns.SetRoundedRectFill(row, mmin(r + 0.05, 1), mmin(g + 0.05, 1), mmin(b + 0.06, 1), 1, true)
    end
end

-- The row's fill for its state: selected, under the cursor, or plain.
function UI:RepaintChatListRow(row)
    if row.folderID then return PaintChatFolderRow(row) end
    if row.isSelected then return PaintChatAccentSurface(row) end
    if row.hovering then return self:PaintChatListRowHover(row) end
    PaintChatSurface(row, "row")
end

-- A folder's row: its name, its chats' names, the newest time among them
-- and their unread together (gray when every one of them is muted).
function UI:FillChatFolderRow(row, fid, entry, store, collapsed, selectedKey)
    local views = chatNS.Views
    local folder = store.folders[fid] or (views and views:Folder(fid))
    local names, newest, unread, loud = {}, nil, 0, false
    row.holdsSelected = nil
    for _, key in ipairs(entry.members) do
        local convo = store.byKey[key] or (views and views:Get(key))
        if key == selectedKey then row.holdsSelected = true end
        if convo then
            names[#names + 1] = self:GetChatConversationPlainLabel(convo, key)
            if convo.lastTime and (not newest or convo.lastTime > newest) then newest = convo.lastTime end
            unread = unread + (convo.unread or 0)
            -- Gray only while every chat with unread is muted and none names you.
            if (convo.unread or 0) > 0 and (not self:IsChatConversationMuted(key) or self:GetChatMentionCount(convo) > 0) then
                loud = true
            end
        end
    end
    row.conversationKey = nil
    row.folderMembers = entry.members
    row.flyoutOpen = self:GetOpenChatFolder() == fid or nil
    row.tipLabel = folder.name
    row.name:SetShown(not collapsed)
    row.preview:SetShown(not collapsed)
    row.time:Hide()
    row.pin:Hide()
    row.muted:Hide()
    row.deleteButton:Hide()
    row.presenceFrame:Hide()
    row.initial:SetText(self:GetChatConversationInitial(nil, nil, folder.name))
    ns.SetRoundedRectFill(row.initialBg, 0.36, 0.38, 0.44, 1, true)
    PaintAvatar(row.initialBg, row.initial, nil)
    -- Its first chats' avatars inside its circle.
    local cluster = row._clusterMembers or {}
    row._clusterMembers = cluster
    wipe(cluster)
    for _, key in ipairs(entry.members) do
        local convo = store.byKey[key] or (views and views:Get(key))
        if convo then
            local r, g, b = self:GetChatRecipientColor(key)
            cluster[#cluster + 1] = { convo = convo, r = r, g = g, b = b,
                initial = self:GetChatConversationInitial(convo, key, self:GetChatConversationDisplayLabel(convo, key)) }
            if #cluster == 3 then break end
        end
    end
    if chatNS.Avatars then chatNS.Avatars:PaintCluster(row.initialBg, row.initial, cluster, 0.36, 0.38, 0.44) end
    row.name:ClearAllPoints()
    row.name:SetPoint("TOPLEFT", row.initialBg, "TOPRIGHT", 7, -1)
    row.name:SetWidth(mmax(1, (row:GetWidth() or 0) - 7 - (row.initialBg:GetWidth() or 24) - 7 - 24))
    SetClippedText(row.name, folder.name)
    SetClippedText(row.preview, table.concat(names, ", "))
    row.chevron:SetRotation(math.pi / 2)
    row.chevron:SetShown(not collapsed)
    -- The badge's own red (none given), as the chat button wears it; gray muted.
    local ur, ug, ub
    if not loud then ur, ug, ub = 0.42, 0.42, 0.46 end
    row.unreadCount, row.unreadR, row.unreadG, row.unreadB = unread, ur, ug, ub
    row.unread:SetCount(unread, ur, ug, ub)
    PaintChatFolderRow(row)
end

local function ChatMessengerView()
    local frame = UI._chatComposer.frame
    return frame and frame.messengerView
end

-- A folder's chats open beside the list, as a menu's flyout does: one at
-- a time, shut by Esc, a click outside or a chat picked in it.
function UI:EnsureChatFolderFlyout(view)
    if view.folderFlyout then return view.folderFlyout end
    local flyout = CreateFrame("Frame", nil, view)
    view.folderFlyout = flyout
    flyout:Hide()
    flyout:EnableMouse(true)
    ns.CreateRoundedRectBorder(flyout)
    ns.SetRoundedRectBarHeight(flyout, 10)
    ns.SetRoundedRectBorderBgAlpha(flyout, 1)
    flyout.rows = {}
    flyout:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
    flyout:SetScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        -- Hidden with the window: shut, not back on its next show.
        if self:IsShown() then self:Hide() end
        local owner, fid = self.owner, self.fid
        self.owner, self.fid = nil, nil
        if owner and owner.folderID == fid then
            owner.flyoutOpen = nil
            PaintChatFolderRow(owner)
        end
    end)
    -- Its own folder row answers its click; a menu, the icon grid or a
    -- question opened from a row in it is part of it.
    flyout:SetScript("OnEvent", function(self)
        if self:IsMouseOver() or (self.owner and self.owner:IsMouseOver()) or Utils.IsCursorMenuMouseOver() then return end
        local grid, dialog = _G.EasyFindChatIconPicker, _G.EasyFindThemedDialog
        if grid and grid:IsShown() and grid:IsMouseOver() then return end
        if dialog and dialog:IsShown() and dialog:IsMouseOver() then return end
        self:Hide()
    end)
    flyout:SetScript("OnMouseWheel", function(self, delta)
        self.offset = mmax(0, (self.offset or 0) - delta)
        UI:FillChatFolderFlyout(view)
    end)
    self:InstallChatFontScaleWheel(flyout)
    -- A press on it is not outside to the search bar's closer.
    Utils.RegisterClickGuard(flyout)
    -- After its own scripts: SetScript drops the hooks this adds.
    Utils.AttachEscClose(flyout)
    return flyout
end

function UI:GetOpenChatFolder()
    local view = ChatMessengerView()
    local flyout = view and view.folderFlyout
    return flyout and flyout:IsShown() and flyout.fid or nil
end

function UI:OpenChatFolderFlyout(view, row)
    local flyout = self:EnsureChatFolderFlyout(view)
    local old = flyout.owner
    if old and old ~= row and old.folderID == flyout.fid then
        old.flyoutOpen = nil
        PaintChatFolderRow(old)
    end
    flyout.fid, flyout.owner, flyout.offset = row.folderID, row, 0
    row.flyoutOpen = true
    -- The collapsed sidebar's name tip sits where the chats open.
    HideChatTip(row)
    flyout:Show()
    self:FillChatFolderFlyout(view)
    PaintChatFolderRow(row)
end

-- A folder row's click: its chats beside it, or shut when they show.
function UI:ToggleChatFolderFlyout(row)
    local view = ChatMessengerView()
    if not (view and row.folderID) then return end
    if self:GetOpenChatFolder() == row.folderID then return view.folderFlyout:Hide() end
    self:OpenChatFolderFlyout(view, row)
end

-- With another folder's chats out, a hover moves them over as a menu does.
function UI:HoverChatFolderRow(row)
    local view = ChatMessengerView()
    local open = self:GetOpenChatFolder()
    if view and open and open ~= row.folderID then self:OpenChatFolderFlyout(view, row) end
end

function UI:CloseChatFolderFlyout()
    local view = ChatMessengerView()
    if view and view.folderFlyout then view.folderFlyout:Hide() end
end

-- The open folder's chats, filled as the list's rows are, beside its row
-- and inside the window; shut with the row (scrolled off, a search, the
-- folder emptied).
function UI:FillChatFolderFlyout(view)
    local flyout = view.folderFlyout
    if not (flyout and flyout:IsShown()) then return end
    local owner
    for _, row in ipairs(view.conversationRows or {}) do
        if row:IsShown() and row.folderID == flyout.fid then
            owner = row
            break
        end
    end
    -- The game chats' row at the foot opens its members too.
    local foot = view.gameRow
    if not owner and foot and foot:IsShown() and foot.folderID == flyout.fid then owner = foot end
    local members = owner and owner.folderMembers
    if not (members and members[1]) then return flyout:Hide() end
    flyout.owner = owner
    local store, views = self:GetChatConversationStore(), chatNS.Views
    local selectedKey = UI._chatComposer.selectedConversationKey
    local spec = view._sidebarRow or { h = 32, gap = 3, icon = 24 }
    local step, pad = spec.h + spec.gap, 6
    -- As many as the window holds; the wheel scrolls through the rest.
    local room = mmax(1, math.floor(((view:GetHeight() or 0) - pad * 2 + spec.gap) / step))
    local count = mmin(#members, room)
    local offset = mmax(0, mmin(flyout.offset or 0, #members - count))
    flyout.offset = offset
    local width = self:GetChatSidebarWidth() - 12
    while #flyout.rows < count do
        local row = self:CreateChatListRow(flyout)
        row.inFlyout = true
        flyout.rows[#flyout.rows + 1] = row
    end
    for i, row in ipairs(flyout.rows) do
        local key = i <= count and members[offset + i] or nil
        local isView = views ~= nil and views:IsView(key)
        local convo = key and (store.byKey[key] or (isView and views:Get(key))) or nil
        row.isView = isView or nil
        if convo then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", flyout, "TOPLEFT", pad, -pad - (i - 1) * step)
            row:SetSize(width, spec.h)
            row.initialBg:SetSize(spec.icon, spec.icon)
            ns.SetRoundedRectBarHeight(row.initialBg, spec.icon)
            self:FillChatConversationRow(row, key, convo, nil, key == selectedKey, false)
            row:Show()
        else
            row.conversationKey = nil
            row.deleteButton:Hide()
            row:Hide()
        end
    end
    local height = pad * 2 + count * spec.h + (count - 1) * spec.gap
    flyout:SetSize(width + pad * 2, height)
    -- Its first chat level with the folder's row, lifted to stay inside.
    local top, bottom = owner:GetTop(), view:GetBottom()
    local lift = (top and bottom) and mmax(0, height - (top + pad - bottom)) or 0
    local right, edge = owner:GetRight(), view.sidebar and view.sidebar:GetRight()
    local x = ((right and edge) and (edge - right) or 6) + 4
    flyout:ClearAllPoints()
    flyout:SetPoint("TOPLEFT", owner, "TOPRIGHT", x, pad + lift)
    flyout:SetFrameLevel(view:GetFrameLevel() + 40)
    -- Opaque over the messages, on a Classic tree too.
    local r, g, b = ChatSurfaceColor("sidebar")
    ns.SetRoundedRectFill(flyout, r, g, b, 1, true)
    self:SetChatSubtleOutline(flyout, true)
end

local function NewChatFolder(store, name)
    store.nextFolder = (store.nextFolder or 0) + 1
    local fid = "f" .. store.nextFolder
    store.folders[fid] = { name = name }
    return fid
end

-- Asks a folder's name; the answer goes to done(name) unless empty.
local function AskChatFolderName(prompt, current, done)
    ns.ShowThemedDialog({
        text = prompt, hasEditBox = true, editBoxDefault = current, maxLetters = 24,
        acceptText = _G["ACCEPT"] or "Accept",
        onAccept = function(value)
            local name = strtrim(value or "")
            if name ~= "" then done(name) end
        end,
    })
end

-- A folder's own menu: rename, mark its chats read, or let them go back
-- to the list.
function UI:ShowChatFolderMenu(fid)
    local store = self:GetChatConversationStore()
    local folder = store.folders[fid]
    if not folder then return end
    local function Changed()
        self:UpdateChatUnreadBadge()
        self:RefreshChatMessenger()
    end
    Utils.ShowCursorMenu("EasyFindChatFolderMenu", {
        { text = "Rename", onClick = function()
            AskChatFolderName("Rename the folder", folder.name, function(name)
                folder.name = name
                Changed()
            end)
        end },
        { text = "Mark all as read", onClick = function()
            for _, convo in pairs(store.byKey) do
                if convo.folder == fid then convo.unread, convo.markedUnread = 0, nil end
            end
            Changed()
        end },
        { text = "Delete folder", onClick = function()
            for _, convo in pairs(store.byKey) do
                if convo.folder == fid then convo.folder = nil end
            end
            store.folders[fid] = nil
            Changed()
        end },
    }, { strata = "TOOLTIP", level = 100, rowHeight = 22, offsetX = 4, offsetY = -4 })
end

-- A chat's folder rows: each folder (a check on its own), a new one, and
-- out of the one it is in.
function UI:BuildChatFolderRows(convo, changed)
    local store = self:GetChatConversationStore()
    local ids = {}
    for fid in pairs(store.folders) do ids[#ids + 1] = fid end
    table.sort(ids, function(a, b) return slower(store.folders[a].name) < slower(store.folders[b].name) end)
    local rows = {}
    for _, fid in ipairs(ids) do
        rows[#rows + 1] = { text = store.folders[fid].name, icon = convo.folder == fid and CHAT_CHECK_TEX or nil,
            onClick = function()
                convo.folder = fid
                changed()
            end }
    end
    rows[#rows + 1] = { text = "New folder...", onClick = function()
        AskChatFolderName("Name the new folder", "", function(name)
            convo.folder = NewChatFolder(store, name)
            changed()
        end)
    end }
    return rows
end

-- Right-click on a conversation: pin, mute, hide its count, mark read or
-- unread, delete.
function UI:ShowChatConversationMenu(key)
    local store = self:GetChatConversationStore()
    local convo = key and store.byKey[key]
    if not convo then return end
    local function Changed()
        self:UpdateChatUnreadBadge()
        self:RefreshChatMessenger()
    end
    local rows = {
        { text = convo.pinned and "Unpin" or "Pin to top", onClick = function()
            convo.pinned = not convo.pinned or nil
            Changed()
        end },
        { text = self:IsChatConversationMuted(key) and "Unmute" or "Mute", onClick = function()
            convo.muted = not UI:IsChatConversationMuted(key)
            Changed()
        end },
        { text = convo.hideUnread and "Show unread count" or "Hide unread count", onClick = function()
            convo.hideUnread = not convo.hideUnread or nil
            if convo.hideUnread then convo.unread, convo.markedUnread = 0, nil end
            Changed()
        end },
    }
    -- Marked unread, the chat keeps its mark while in view, until it is
    -- selected again (as chat apps keep it). Its count hidden: no marks.
    if not convo.hideUnread and (convo.unread or 0) > 0 then
        rows[#rows + 1] = { text = "Mark as read", onClick = function()
            convo.unread, convo.markedUnread = 0, nil
            Changed()
        end }
    elseif not convo.hideUnread then
        rows[#rows + 1] = { text = "Mark as unread", onClick = function()
            convo.unread, convo.markedUnread, convo.mentions = 1, true, nil
            Changed()
        end }
    end
    -- A name of the player's choosing; the chat stays the person's (or the
    -- room's), so their next message still lands here. Empty: back to theirs.
    rows[#rows + 1] = { text = "Rename", onClick = function()
        ns.ShowThemedDialog({
            text = "Rename this chat", hasEditBox = true, maxLetters = 32,
            editBoxDefault = convo.customLabel or self:GetChatConversationPlainLabel(convo, key),
            acceptText = _G["ACCEPT"] or "Accept",
            onAccept = function(value)
                local name = strtrim(value or "")
                convo.customLabel = name ~= "" and name or nil
                Changed()
            end,
        })
    end }
    rows[#rows + 1] = { text = "Change icon", onClick = function()
        if chatNS.Avatars then chatNS.Avatars:OpenPicker(key) end
    end }
    rows[#rows + 1] = { text = "Add to folder", submenu = self:BuildChatFolderRows(convo, Changed) }
    if convo.folder and store.folders[convo.folder] then
        rows[#rows + 1] = { text = "Remove from folder", onClick = function()
            convo.folder = nil
            Changed()
        end }
    end
    rows[#rows + 1] = { text = "Copy Chat", onClick = function()
        if ns.CopyToClipboard then ns.CopyToClipboard(UI:BuildChatTranscript(key)) end
    end }
    rows[#rows + 1] = { text = "Delete Chat", onClick = function() UI:DeleteChatConversation(key) end }
    Utils.ShowCursorMenu("EasyFindChatConversationMenu", rows, {
        strata = "TOOLTIP", level = 100, rowHeight = 22, offsetX = 4, offsetY = -4,
    })
end

-- A conversation as plain text: its name, a heading for each day, then a
-- line per message, "[4:23 PM] Name: text".
function UI:BuildChatTranscript(key)
    local store = self:GetChatConversationStore()
    local convo = key and store.byKey[key]
    if not convo then return "" end
    local lines = { self:GetChatConversationPlainLabel(convo, key) }
    local lastDay
    for _, msg in ipairs(convo.messages or {}) do
        local day = msg.time and date("%A, %B %d, %Y", msg.time)
        if day and day ~= lastDay then
            lines[#lines + 1] = ""
            lines[#lines + 1] = day
            lastDay = day
        end
        local text = self:GetChatMessageDisplayText(msg) or ""
        if Utils.ClipboardSafeText then text = Utils.ClipboardSafeText(text) end
        local who = self:GetPlainChatLabel(msg.senderLabel or (msg.outgoing and (self:GetChatPlayerName() or "You")) or "")
        lines[#lines + 1] = string.format("[%s] %s%s", self:FormatChatBubbleTime(msg.time),
            who ~= "" and (who .. ": ") or "", text)
    end
    return table.concat(lines, "\n")
end

-- Extensions > Chat in the options.
function UI:OpenChatSettings()
    EasyFind.API.OpenSettings("chat")
end

-- The message sound (Extensions > Chat): a client sound kit by name, or
-- none. At most one a moment, so a burst of lines rings once.
local CHAT_SOUNDS = {
    { key = "none", label = "None" },
    { key = "TELL_MESSAGE", label = "Whisper" },
    { key = "UI_BNET_TOAST", label = "Battle.net" },
    { key = "MAP_PING", label = "Ping" },
    { key = "READY_CHECK", label = "Ready check" },
    { key = "IG_PLAYER_INVITE", label = "Invite" },
    { key = "IG_QUEST_LIST_COMPLETE", label = "Quest done" },
    { key = "RAID_WARNING", label = "Raid warning" },
}
UI.CHAT_SOUNDS = CHAT_SOUNDS
local lastChatSoundAt = 0

function UI:PlayChatSoundKey(key)
    local id = key and SOUNDKIT and SOUNDKIT[key]
    if id and PlaySound then PlaySound(id, "Master") end
end

function UI:PlayChatMessageSound()
    local key = ChatDB().messageSound
    if not key or key == "none" then return end
    local now = GetTime and GetTime() or 0
    if now - lastChatSoundAt < 1.5 then return end
    lastChatSoundAt = now
    self:PlayChatSoundKey(key)
end

function UI:MarkAllChatsRead()
    local store = self:GetChatConversationStore()
    for _, convo in pairs(store and store.byKey or {}) do convo.unread, convo.markedUnread = 0, nil end
    self:UpdateChatUnreadBadge()
    self:RefreshChatMessenger()
end

EasyFind.API.RegisterExtension({
    id = "chat", name = ns.L["APP_CHAT"], description = ns.L["APP_DESC_CHAT"],
    icon = chatNS.ICON_TEX, experimental = ns.L["CHAT_EXP_TT"], keywords = { "chat" },
    loadInCombat = true,
    open = function() return chatNS:Open() end,
    close = function() chatNS:Close() end,
    isOpen = function() return chatNS:IsOpen() end,
    menu = function()
        return { { kind = "action", label = "Mark all as read", onClick = function() UI:MarkAllChatsRead() end } }
    end,
})
-- A message started in the messenger: text, to that conversation if a
-- key is given, else a new one.
EasyFind.API.RegisterAction("chat", "compose", function(text, key) return chatNS:ComposeWith(key, text) end)
-- Its conversations, newest first, as { key, label }.
EasyFind.API.RegisterAction("chat", "conversations", function() return chatNS:ListConversations() end)

-- "Show chats" on a player's menus (their portrait, a chat name, the
-- rosters): the chats they have lines in, theirs alone, through the
-- sidebar search (from:Name), their whispers open first. The client runs
-- additions like this securely (Menu.ModifyMenu).
local PLAYER_MENUS = {
    "PLAYER", "PARTY", "RAID_PLAYER", "RAID", "FRIEND", "FRIEND_OFFLINE", "ENEMY_PLAYER",
    "GUILD", "GUILD_OFFLINE", "COMMUNITIES_GUILD_MEMBER", "COMMUNITIES_WOW_MEMBER",
    "CHAT_ROSTER", "TARGET", "FOCUS", "RECENT_ALLY", "RECENT_ALLY_OFFLINE",
}

-- A name's first word, lowered: "Veed-Realm" and "Veed Surname" are veed.
local function FirstName(name)
    return type(name) == "string" and slower(name):match("^([^%-%s]+)") or nil
end

-- Who has lines in the store, by first name; built on the first ask, kept
-- as messages arrive, dropped as a chat goes.
local speakerIndex
local function IndexSpeaker(msg)
    local label, name = FirstName(msg.senderLabel), FirstName(msg.senderName)
    if label then speakerIndex[label] = true end
    if name then speakerIndex[name] = true end
end
function UI:NoteChatSpeaker(msg)
    if speakerIndex and msg then IndexSpeaker(msg) end
end
function UI:ForgetChatSpeakers() speakerIndex = nil end
function UI:HasChatLinesFrom(name)
    if not speakerIndex then
        speakerIndex = {}
        for _, convo in pairs(self:GetChatConversationStore().byKey) do
            local messages = convo.messages or {}
            for i = 1, #messages do IndexSpeaker(messages[i]) end
        end
    end
    local first = FirstName(name)
    return first ~= nil and speakerIndex[first] == true
end

function chatNS:ShowPlayerChats(name)
    local first = type(name) == "string" and name:match("^([^%-%s]+)")
    if not first then return end
    UI:OpenChatComposer()
    local frame = UI._chatComposer.frame
    local view = frame and frame.messengerView
    if not (view and view.searchEditBox) then return end
    local lowered = slower(first)
    for key, convo in pairs(UI:GetChatConversationStore().byKey) do
        if convo.kind == "player" and FirstName(convo.targetName or convo.label) == lowered then
            UI._chatComposer.selectedConversationKey = key
            break
        end
    end
    UI:CloseChatMessageFilter(true)
    view.searchEditBox:SetText("from:" .. first)
end

local issecretname = _G.issecretvalue or function() return false end
local function MenuPlayerName(contextData)
    if not contextData then return nil end
    local unit = contextData.unit
    if unit and UnitExists(unit) then
        if not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then return nil end
        local name = UnitName(unit)
        if type(name) ~= "string" or issecretname(name) then return nil end
        return name
    end
    local name = contextData.name
    if type(name) ~= "string" or name == "" or issecretname(name) then return nil end
    return name
end

local function AddShowChats(_, root, contextData)
    local name = MenuPlayerName(contextData)
    if not (name and UI:HasChatLinesFrom(name)) then return end
    root:CreateDivider()
    root:CreateButton("Show chats", function() chatNS:ShowPlayerChats(name) end)
end

if Menu and Menu.ModifyMenu then
    for i = 1, #PLAYER_MENUS do Menu.ModifyMenu("MENU_UNIT_" .. PLAYER_MENUS[i], AddShowChats) end
end

-- The conversations and messages a search finds; a click opens the
-- messenger there.
-- Its conversations, and its messages only when asked: a row for every
-- message crowded other searches out.
EasyFind.API.RegisterSearchProvider({
    key = "chat", category = "Chat", extension = "chat",
    label = ns.L["APP_CHAT"], icon = chatNS.ICON_TEX,
    words = { "chat", "message", "messages", "whisper", "whispers", "conversation" },
    rows = function() return chatNS:BuildSearchData() end,
    select = function(row) chatNS:OpenConversation(row.chatKey, row.chatMessageIndex) end,
    options = {
        { label = ns.L["CHAT_OPT_CHATS"], tooltip = ns.L["CHAT_OPT_CHATS_TT"],
          get = function() return ChatDB().findChats ~= false end,
          set = function(on)
              ChatDB().findChats = Utils.OffOrNil(on)
              EasyFind.API.RefreshSearchProvider("chat")
          end },
        { label = ns.L["CHAT_OPT_MESSAGES"], tooltip = ns.L["CHAT_OPT_MESSAGES_TT"],
          get = function() return ChatDB().findMessages == true end,
          set = function(on)
              ChatDB().findMessages = on or nil
              EasyFind.API.RefreshSearchProvider("chat")
          end },
    },
})

-- The chat icon's badge: messages unread across the chats the list shows,
-- the picked character's. A muted chat adds only the messages that named you.
function UI:UpdateChatUnreadBadge()
    local total = 0
    local store = self:GetChatConversationStore()
    if ChatDB().showBadge ~= false and store then
        local order = self:FilterChatOrderByCharacter(store.order or {}, store)
        for i = 1, #order do
            local key = order[i]
            local convo = store.byKey[key]
            if convo and self:IsChatConversationMuted(key) then
                total = total + self:GetChatMentionCount(convo)
            elseif convo then
                total = total + (tonumber(convo.unread) or 0)
            end
        end
    end
    EasyFind.API.SetBadge("chat", total)
end

-- Every setting of the page back to its default; the conversations stay.
function UI:ResetChatSettings()
    local db = ChatDB()
    for _, key in ipairs({ "showAll", "showCombatLog", "classColors", "mutePublicRooms", "muteGroups", "escCloses",
                           "hideButtonWhileOpen", "headerOneLine", "headerInTitle", "inlineSender",
                           "windowBorder", "timePlacement", "messageSound", "font", "fontScale", "showBadge",
                           "showClock", "headerFontScale", "deliveryNotices", "mentions", "showDrafts", "pins",
                           "messageAvatars", "classIcons", "randomIcons", "newDivider", "newestButton", "webLinks" }) do
        db[key] = nil
    end
    local retention = GetChatRetentionSettings()
    if retention then retention.retentionDays, retention.maxMessagesPerConversation = nil, nil end
    UI._chatComposer.fontScale = nil
    if db.takeover then self:SetChatTakeover(false) end
    self:SetChatInputStyle("full")
    self:SetChatChannelRecording(true)
    if Utils.RefreshEscArm then Utils.RefreshEscArm() end
    self:SyncChatButtonHidden()
    self:LayoutChatMessengerChrome()
    self:ApplyChatWindowLook()
    self:ApplyChatFontScale()
    self:UpdateChatUnreadBadge()
    self:RefreshChatMessenger()
end

function UI:IsChatChannelRecording()
    return ChatDB().recordChannels ~= false
end

function UI:SetChatChannelRecording(on)
    ChatDB().recordChannels = Utils.OffOrNil(on)
    local eventFrame = UI._chatComposer.eventFrame
    if not eventFrame then return end
    if on then
        eventFrame:RegisterEvent("CHAT_MSG_CHANNEL")
        self:ListJoinedChatChannels()
    else
        eventFrame:UnregisterEvent("CHAT_MSG_CHANNEL")
    end
end

-- The numbered channels joined, as conversations from the start (at the
-- list's end, not its top), so General or Trade opens and takes typing
-- before anyone has spoken there.
function UI:ListJoinedChatChannels()
    if not (self:IsChatChannelRecording() and GetChannelList) then return end
    local store = self:GetChatConversationStore()
    local list = { GetChannelList() }
    local added = false
    for i = 1, #list, 3 do
        local index, baseName, disabled = list[i], list[i + 1], list[i + 2]
        local name = type(baseName) == "string" and self:GetPlainChatLabel(baseName) or ""
        name = name:match("^(.-)%s+%-%s+") or name
        if type(index) == "number" and name ~= "" and not disabled then
            local key = self:GetChatConversationKey("channel", "#" .. name, name)
            local convo = store.byKey[key]
            if not convo then
                convo = { key = key, messages = {}, label = name, kind = "channel", source = "Channel" }
                store.byKey[key] = convo
                store.order[#store.order + 1] = key
                added = true
            end
            convo.channelIndex = index
        end
    end
    if added then self:RefreshChatMessenger() end
end

function UI:RegisterChatComposerEvents()
    if UI._chatComposer.eventsRegistered then return end
    UI._chatComposer.eventsRegistered = true
    local events = {
        "CHAT_MSG_WHISPER",
        "CHAT_MSG_WHISPER_INFORM",
        "CHAT_MSG_BN_WHISPER",
        "CHAT_MSG_BN_WHISPER_INFORM",
        "CHAT_MSG_SAY",
        "CHAT_MSG_YELL",
        "CHAT_MSG_PARTY",
        "CHAT_MSG_PARTY_LEADER",
        "CHAT_MSG_RAID",
        "CHAT_MSG_RAID_LEADER",
        "CHAT_MSG_RAID_WARNING",
        "CHAT_MSG_INSTANCE_CHAT",
        "CHAT_MSG_INSTANCE_CHAT_LEADER",
        "CHAT_MSG_GUILD",
        "CHAT_MSG_OFFICER",
        "CHAT_MSG_AFK",
        "CHAT_MSG_DND",
        "CHAT_MSG_SYSTEM",
    }
    local eventFrame = CreateFrame("Frame")
    UI._chatComposer.eventFrame = eventFrame
    for i = 1, #events do
        eventFrame:RegisterEvent(events[i])
    end
    Utils.RegisterEventIfValid(eventFrame, "BN_CHAT_WHISPER_UNDELIVERABLE")
    if self:IsChatChannelRecording() then eventFrame:RegisterEvent("CHAT_MSG_CHANNEL") end
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        xpcall(UI.HandleChatMessageEvent, geterrorhandler(), UI, event, ...)
    end)
    local channelList = CreateFrame("Frame")
    channelList:RegisterEvent("PLAYER_ENTERING_WORLD")
    channelList:RegisterEvent("CHANNEL_UI_UPDATE")
    channelList:SetScript("OnEvent", function()
        xpcall(UI.ListJoinedChatChannels, Utils.ErrorHandler, UI)
    end)
end

function UI:SendChatComposerMessage()
    local frame = UI._chatComposer.frame
    if not frame then return false end
    local rawMessage = strtrim(frame.messageEditBox:GetText() or "")
    local lines = self:GetChatMessageLines(rawMessage)
    if #lines == 0 then
        self:SetChatComposerStatus("Enter a message.", 0.95, 0.36, 0.30)
        self:RefreshChatComposerSendState()
        return false
    end

    local def = self:GetChatChannelDef()
    if def.needsRecipients then
        if frame.targetEditBox and strtrim(frame.targetEditBox:GetText() or "") ~= "" then
            self:ConsumeChatRecipientInput(false)
        end
        if #UI._chatComposer.recipients == 0 then
            self:SetChatComposerStatus("Add at least one whisper target.", 0.95, 0.36, 0.30)
            self:RefreshChatComposerSendState()
            return false
        end
        local sentTargets = 0
        local sentMessages = 0
        for i = 1, #UI._chatComposer.recipients do
            local recipient = UI._chatComposer.recipients[i]
            local sentToRecipient = false
            for li = 1, #lines do
                local line = lines[li]
                local entry
                if recipient.kind == "bn" then
                    entry = { kind = "bn", presenceID = recipient.id, text = line }
                else
                    entry = { text = line, channel = "WHISPER", target = recipient.name }
                end
                entry.efRecipient = recipient
                entry.efMeta = self:GetChatForwardSendMeta(line)
                entry.onSent = ChatRecipientEntrySent
                if SendChatEntry(entry) then
                    sentToRecipient = true
                    sentMessages = sentMessages + 1
                end
            end
            if sentToRecipient then sentTargets = sentTargets + 1 end
        end
        if sentTargets > 0 then
            UI._chatComposer.pendingForward = nil
            frame.messageEditBox:SetText("")
            self:SetChatComposerStatus("Sent " .. sentMessages .. " message"
                .. (sentMessages == 1 and "" or "s") .. " to " .. sentTargets
                .. " target" .. (sentTargets == 1 and "." or "s."), 0.48, 1.0, 0.62)
            self:RefreshChatComposerSendState()
            return true
        end
        self:SetChatComposerStatus("No messages were sent.", 0.95, 0.36, 0.30)
        return false
    end

    if def.key == "PARTY" and IsInGroup and not IsInGroup() then
        self:SetChatComposerStatus("You are not in a party.", 0.95, 0.36, 0.30)
        return false
    elseif def.key == "RAID" and IsInRaid and not IsInRaid() then
        self:SetChatComposerStatus("You are not in a raid.", 0.95, 0.36, 0.30)
        return false
    end

    local sentMessages = 0
    for i = 1, #lines do
        local line = lines[i]
        local entry = { text = line, channel = def.chatType }
        entry.efChannelDef = def
        entry.efMeta = self:GetChatForwardSendMeta(line)
        entry.onSent = ChatChannelEntrySent
        if SendChatEntry(entry) then sentMessages = sentMessages + 1 end
    end
    if sentMessages > 0 then
        UI._chatComposer.pendingForward = nil
        frame.messageEditBox:SetText("")
        self:SetChatComposerStatus("Sent " .. sentMessages .. " message"
            .. (sentMessages == 1 and "" or "s") .. " to " .. def.label .. ".", 0.48, 1.0, 0.62)
        self:RefreshChatComposerSendState()
        return true
    end
    self:SetChatComposerStatus("Message failed.", 0.95, 0.36, 0.30)
    return false
end

function UI:StyleChatComposerSelect(button)
    self:StyleChatComposerInputSurface(button, 8, 0.98)
    button:SetScript("OnEnter", PaintChatInputHover)
    button:SetScript("OnLeave", PaintChatInputSurface)
end

-- The time of day as the game's clock shows it: its 24-hour setting, its
-- own AM and PM.
local function ClockText(timestamp)
    local t = date("*t", timestamp)
    if GetCVarBool and GetCVarBool("timeMgrUseMilitaryTime") then return ("%02d:%02d"):format(t.hour, t.min) end
    local half = t.hour < 12 and (_G["TIMEMANAGER_AM"] or "AM") or (_G["TIMEMANAGER_PM"] or "PM")
    return ("%d:%02d %s"):format((t.hour + 11) % 12 + 1, t.min, half)
end

function UI:FormatChatConversationTime(timestamp)
    if not timestamp then return "" end
    local now = time()
    local todayKey = date("%Y-%m-%d", now)
    local messageKey = date("%Y-%m-%d", timestamp)
    if messageKey == todayKey then
        return ClockText(timestamp)
    end

    local todayParts = date("*t", now)
    local messageParts = date("*t", timestamp)
    todayParts.hour, todayParts.min, todayParts.sec = 0, 0, 0
    messageParts.hour, messageParts.min, messageParts.sec = 0, 0, 0
    local dayDiff = math.floor(((time(todayParts) or now) - (time(messageParts) or timestamp)) / 86400 + 0.5)
    if dayDiff > 0 and dayDiff < 7 then
        return date("%a", timestamp)
    end
    if date("%Y", timestamp) == date("%Y", now) then
        return date("%B ", timestamp) .. tostring(tonumber(date("%d", timestamp)) or date("%d", timestamp))
    end
    return date("%m/%d/%y", timestamp)
end

-- A bubble's time: the day is the divider above it.
function UI:FormatChatBubbleTime(timestamp)
    if not timestamp then return "" end
    return ClockText(timestamp)
end

function UI:SetChatConversationRowTime(row, text)
    if not (row and row.time) then return end

    text = tostring(text or "")
    row.time:SetText(text)
    local getter = row.time.GetUnboundedStringWidth or row.time.GetStringWidth
    local width = getter and getter(row.time) or 0
    row.time:SetWidth(mmax(48, math.ceil(width + 6)))
end

function UI:GetChatMessageDayKey(timestamp)
    return date("%Y-%m-%d", timestamp or time())
end

function UI:FormatChatMessageDay(timestamp)
    timestamp = timestamp or time()
    local key = self:GetChatMessageDayKey(timestamp)
    local today = self:GetChatMessageDayKey(time())
    local yesterday = self:GetChatMessageDayKey(time() - 86400)
    if key == today then return "Today" end
    if key == yesterday then return "Yesterday" end
    if date("%Y", timestamp) == date("%Y") then
        return date("%b %d", timestamp)
    end
    return date("%b %d, %Y", timestamp)
end

function UI:GetChatMessageDisplayText(msg)
    return tostring((msg and (msg.displayText or msg.text)) or "")
end

-- What a bubble quotes: a reply carries the message it answers, a forward
-- its sender. Our own messages keep that as metadata; another messenger's
-- arrive as wire text in our own form, read back once and kept.
function UI:GetChatMessageQuote(msg)
    if not msg then return nil end
    if msg.quote then return msg.quote end
    if msg.replyTo and msg.replyTo.text then
        local sender = self:GetPlainChatLabel(msg.replyTo.senderLabel or "")
        return { sender = sender ~= "" and sender or "Unknown", text = self:TrimChatQuotedText(msg.replyTo.text, 140) }
    end
    if msg.forwardedFrom then
        local sender = self:GetPlainChatLabel(msg.forwardedFrom.senderLabel or "")
        return { sender = sender ~= "" and sender or "Unknown", forward = true }
    end
    if msg.outgoing or msg.displayText then return nil end
    local text = tostring(msg.text or "")
    local quoted, body = text:match('^In reply to your: "(.-)": (.*)$')
    if quoted then
        msg.displayText = body
        msg.quote = { sender = self:GetChatPlayerName() or "You", text = quoted }
        return msg.quote
    end
    local sender, rest = text:match("^From ([^:]+): (.*)$")
    if sender then
        msg.displayText = rest
        msg.quote = { sender = sender, forward = true }
        return msg.quote
    end
    return nil
end

function UI:GetChatMessageSenderLabel(convo, msg, key)
    local label = msg and msg.senderLabel
    label = self:GetPlainChatLabel(label or "")
    if label ~= "" then return label end
    if msg and msg.outgoing then return self:GetChatPlayerName() or "You" end
    if convo then
        label = self:GetChatConversationPlainLabel(convo, key)
        if label ~= "" then return label end
    end
    return "Unknown"
end

function UI:TrimChatQuotedText(text, maxLen)
    text = self:GetPlainChatLabel(text or ""):gsub("%s+", " ")
    maxLen = maxLen or 80
    if #text <= maxLen then return text end
    return text:sub(1, CharBoundary(text, mmax(1, maxLen - 3))) .. "..."
end

function UI:GetChatReplyQuote(ref)
    return self:TrimChatQuotedText(ref and ref.text or "", 96)
end

function UI:GetChatReplyWirePrefix(ref)
    return 'In reply to your: "' .. self:GetChatReplyQuote(ref) .. '": '
end

function UI:GetChatReplyInputLimit()
    local pending = UI._chatComposer.pendingReply
    if not (pending and pending.text) then return CHAT_MESSAGE_MAX_CHARS end
    if pending.key ~= UI._chatComposer.selectedConversationKey then return CHAT_MESSAGE_MAX_CHARS end
    return mmax(1, CHAT_MESSAGE_MAX_CHARS - #self:GetChatReplyWirePrefix(pending))
end

function UI:BuildChatMessageRef(convo, msg, key)
    if not msg then return nil end
    local text = self:GetChatMessageDisplayText(msg)
    if text == "" then return nil end
    return {
        text = text,
        senderLabel = self:GetChatMessageSenderLabel(convo, msg, key),
    }
end

function UI:BuildChatReplyWireText(ref, message)
    message = tostring(message or "")
    local prefix = self:GetChatReplyWirePrefix(ref)
    local maxMessage = mmax(0, CHAT_MESSAGE_MAX_CHARS - #prefix)
    -- Links count by their shown name; the box already kept them in bounds.
    if #message > maxMessage and not sfind(message, "|", 1, true) then
        message = message:sub(1, CharBoundary(message, maxMessage))
    end
    return prefix .. message
end

function UI:BuildChatForwardWireText(ref)
    local sender = self:GetPlainChatLabel(ref and ref.senderLabel or "") or ""
    if sender == "" then sender = "Unknown" end
    local prefix = "From " .. sender .. ": "
    local maxMessage = CHAT_MESSAGE_MAX_CHARS - #prefix
    local message = self:TrimChatQuotedText(ref and ref.text or "", mmax(12, maxMessage))
    local wire = prefix .. message
    if #wire > CHAT_MESSAGE_MAX_CHARS then
        wire = wire:sub(1, CharBoundary(wire, CHAT_MESSAGE_MAX_CHARS))
    end
    return wire
end

function UI:UpdateChatMessageScrollBar(contentH, viewH)
    local frame = UI._chatComposer.frame
    local view = frame and frame.messengerView
    if not (view and view.messageScrollBar and view.messageScrollBar.UpdateThumb) then return end
    contentH = contentH or (view.messageChild and view.messageChild:GetHeight()) or 0
    viewH = viewH or (view.messageScroll and view.messageScroll:GetHeight()) or 0
    if contentH > viewH + 1 then
        view.messageScrollBar:Show()
        view.messageScrollBar:UpdateThumb(contentH, viewH)
    else
        if view.messageScroll then view.messageScroll:SetVerticalScroll(0) end
        view.messageScrollBar:Hide()
    end
end

function UI:EnsureChatMessageRow(view, index)
    view.messageRows = view.messageRows or {}
    local row = view.messageRows[index]
    if row then return row end

    row = CreateFrame("Frame", nil, view.messageChild)
    view.messageRows[index] = row
    row.list = view.messageScroll
    row:EnableMouse(true)
    ns.CreateRoundedRectBorder(row)
    ns.SetRoundedRectBarHeight(row, 9)
    ns.SetRoundedRectBorderBgAlpha(row, 1)
    self:SetChatSubtleOutline(row, false)
    row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.meta:SetJustifyH("LEFT")
    row.meta:SetWordWrap(false)
    if row.meta.SetMaxLines then row.meta:SetMaxLines(1) end
    -- The speaker's name as a Ctrl+C target of its own, laid over the drawn
    -- name each render; it takes no mouse, the bubble keeps its clicks.
    row.nameTarget = CreateFrame("Frame", nil, row)
    row.nameTarget:Hide()
    -- The quote block: an accent bar, the quoted sender's name, the
    -- quoted words dimmed under it; the bubble's own words follow below.
    local quote = CreateFrame("Frame", nil, row)
    quote.bar = quote:CreateTexture(nil, "ARTWORK")
    quote.bar:SetWidth(2)
    quote.bar:SetPoint("TOPLEFT", quote, "TOPLEFT", 0, 0)
    quote.bar:SetPoint("BOTTOMLEFT", quote, "BOTTOMLEFT", 0, 0)
    quote.name = quote:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    quote.name:SetJustifyH("LEFT")
    quote.name:SetWordWrap(false)
    quote.name:SetPoint("TOPLEFT", quote, "TOPLEFT", CHAT_QUOTE_INSET, 0)
    quote.name:SetPoint("RIGHT", quote, "RIGHT", 0, 0)
    quote.text = quote:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    quote.text:SetJustifyH("LEFT")
    quote.text:SetJustifyV("TOP")
    quote.text:SetWordWrap(true)
    if quote.text.SetMaxLines then quote.text:SetMaxLines(2) end
    quote.text:SetPoint("TOPLEFT", quote.name, "BOTTOMLEFT", 0, -1)
    quote.text:SetPoint("RIGHT", quote, "RIGHT", 0, 0)
    quote:Hide()
    row.quote = quote
    row.copyBox = CreateFrame("EditBox", nil, row)
    row.copyBox:SetAutoFocus(false)
    row.copyBox:SetMultiLine(true)
    row.copyBox:SetFontObject(GameFontHighlightSmall)
    row.copyBox:SetTextColor(1, 1, 1, 1)
    row.copyBox:SetJustifyH("LEFT")
    row.copyBox:SetJustifyV("TOP")
    if row.copyBox.SetWordWrap then row.copyBox:SetWordWrap(true) end
    if row.copyBox.SetNonSpaceWrap then row.copyBox:SetNonSpaceWrap(true) end
    if row.copyBox.SetTextInsets then row.copyBox:SetTextInsets(0, 0, 0, 0) end
    if row.copyBox.SetCursorColor then row.copyBox:SetCursorColor(1, 1, 1, 0) end
    if row.copyBox.SetBlinkSpeed then row.copyBox:SetBlinkSpeed(0) end
    -- Its own words stay clear over the plain line: a selection only tints them.
    if row.copyBox.SetHighlightColor then row.copyBox:SetHighlightColor(0.5, 0.5, 0.5, 0.4) end
    row.copyBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput and self:GetText() ~= (self._chatText or "") then
            self:SetText(self._chatText or "")
            self:HighlightText()
        end
    end)
    row.copyBox:SetScript("OnChar", function(self)
        if self:GetText() ~= (self._chatText or "") then
            self:SetText(self._chatText or "")
            self:HighlightText()
        end
    end)
    row.copyBox:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then return end
        if UI:HandleChatMessageRowMouseDown(row, button) then return end
        UI:ClearChatMessageCopyFocus(self)
        self:SetFocus()
    end)
    row.copyBox:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            -- A right-click is the menu, never a selection.
            self:HighlightText(0, 0)
            self:ClearFocus()
            UI:ShowChatMessageMenu(row)
        end
    end)
    row.copyBox:SetScript("OnEditFocusGained", function(self)
        -- A box takes focus on any click: a right-click (the menu) is not a
        -- selection, so the words stay drawn as they were.
        if IsMouseButtonDown and IsMouseButtonDown("RightButton") then
            Utils.SafeAfter(0, function()
                self:HighlightText(0, 0)
                self:ClearFocus()
            end)
            return
        end
        UI:ClearChatMessageCopyFocus(self)
        if self.SetCursorColor then self:SetCursorColor(1, 1, 1, 0) end
        ShowBubbleWords(row)
    end)
    row.copyBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        self:SetCursorPosition(0)
        ShowBubbleWords(row)
    end)
    Utils.ReleaseFocusOnOutsideClick(row.copyBox)
    row.copyBox:SetScript("OnKeyDown", function(self, key)
        UI:ArmChatHoveredCopy(self, key)
        if UI:HandleChatFontScaleKey(self, key) then return end
        if UI:HandleChatClipboardKey(self, key) then return end
        if UI:HandleChatFindKey(self, key) then return end
        Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", true)
    end)
    row.copyBox:SetScript("OnEscapePressed", function()
        UI:ClearFocusedChatEditBox()
    end)
    -- The text box covers most of the bubble: its hover counts as the row's.
    row.copyBox:SetScript("OnEnter", function()
        if row.message then
            PaintChatRowHover(row)
            UI:ShowChatBubbleTip(row)
            UI:ShowChatJump(row)
        end
    end)
    row.copyBox:SetScript("OnLeave", function()
        if row.message and not ChatRowHovered(row) then
            PaintChatRowRest(row)
            UI:HideChatBubbleTip(row)
        end
        UI:HideChatJump(row)
    end)
    row:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            UI:ShowChatMessageMenu(row)
        end
    end)
    row:SetScript("OnMouseDown", function(_, button)
        UI:HandleChatMessageRowMouseDown(row, button)
    end)
    row:SetScript("OnEnter", function(self)
        if self.message then
            PaintChatRowHover(self)
            UI:ShowChatBubbleTip(self)
            UI:ShowChatJump(self)
        end
    end)
    row:SetScript("OnLeave", function(self)
        if self.message and not ChatRowHovered(self) then
            PaintChatRowRest(self)
            UI:HideChatBubbleTip(self)
        end
        UI:HideChatJump(self)
    end)
    row.text = row.copyBox
    -- The name's target over the text box, so it feels the mouse; its
    -- clicks fall through to the bubble. Hovered, the name lights as
    -- selected text does, behind its letters: Ctrl+C takes it.
    local nameTarget = row.nameTarget
    nameTarget:SetFrameLevel(row.copyBox:GetFrameLevel() + 2)
    if nameTarget.SetMouseClickEnabled then
        nameTarget:SetMouseMotionEnabled(true)
        nameTarget:SetMouseClickEnabled(false)
    end
    row.nameHighlight = row:CreateTexture(nil, "ARTWORK")
    row.nameHighlight:SetPoint("TOPLEFT", nameTarget, "TOPLEFT", -1, 1)
    row.nameHighlight:SetPoint("BOTTOMRIGHT", nameTarget, "BOTTOMRIGHT", 1, -1)
    row.nameHighlight:SetColorTexture(0.5, 0.5, 0.5, 0.4)
    row.nameHighlight:Hide()
    -- Over the name only the name lights; the bubble's own hover returns
    -- on its words.
    nameTarget:SetScript("OnEnter", function()
        row.nameHighlight:Show()
        if row.message then PaintChatRowRest(row) end
    end)
    nameTarget:SetScript("OnLeave", function()
        row.nameHighlight:Hide()
        if row.message and ChatRowHovered(row) then PaintChatRowHover(row) end
    end)
    -- A link (EasyFind's, an item, a spell) needs a plain font string to
    -- click: a bubble carrying one shows its words here instead of the box.
    row.linkText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.linkText:SetJustifyH("LEFT")
    row.linkText:SetJustifyV("TOP")
    row.linkText:SetWordWrap(true)
    if row.linkText.SetNonSpaceWrap then row.linkText:SetNonSpaceWrap(true) end
    row.linkText:Hide()
    if ns.ResultLinks and ns.ResultLinks.AttachHyperlinks then ns.ResultLinks:AttachHyperlinks(row) end
    -- A web address: a left click copies it, a right click is the bubble's menu.
    local gameClick = row:GetScript("OnHyperlinkClick")
    row:SetScript("OnHyperlinkClick", function(self, link, text, button)
        local url = type(link) == "string" and link:match("^url:(.+)$")
        if not url then
            if gameClick then gameClick(self, link, text, button) end
            return
        end
        if button == "RightButton" then
            UI:ShowChatMessageMenu(self)
        else
            UI:CopyChatMessageText(url)
        end
    end)
    row:HookScript("OnHyperlinkEnter", function(self, link)
        local url = type(link) == "string" and link:match("^url:(.+)$")
        if not url then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText(url, 1, 1, 1, 1, true)
        GameTooltip:AddLine("Click to copy", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    row.time = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    do
        local font, size, flags = row.time:GetFont()
        if font and size then row.time:SetFont(font, mmax(8, size - 1), flags) end
    end
    -- A pinned message's pin, outside its far top corner.
    row.pinMark = row:CreateTexture(nil, "OVERLAY")
    row.pinMark:SetTexture(CHAT_PIN_TEX)
    row.pinMark:SetSize(11, 11)
    RegisterChatThemedText(row.pinMark, 0.7)
    row.pinMark:Hide()
    -- The speaker's circle beside a room's bubble (Extensions > Chat).
    local avatar = CreateFrame("Frame", nil, row)
    avatar:Hide()
    avatar:SetSize(24, 24)
    ns.CreateRoundedRectBorder(avatar)
    ns.SetRoundedRectBarHeight(avatar, 24)
    ns.SetRoundedRectBorderBgAlpha(avatar, 1)
    ns.SetRoundedRectBorderEdgeShown(avatar, false)
    avatar.letter = avatar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    RegisterChatThemedText(avatar.letter)
    avatar.letter:SetPoint("CENTER")
    if avatar.letter.SetDrawLayer then avatar.letter:SetDrawLayer("OVERLAY", 7) end
    row.avatar = avatar
    row.time:SetWidth(52)
    row.time:SetJustifyH("RIGHT")
    row.time:SetWordWrap(false)
    if row.time.SetMaxLines then row.time:SetMaxLines(1) end
    row:Hide()
    self:RegisterChatFrameFonts(row)
    ns.ShadeText(row)
    return row
end

function UI:EnsureChatDateRow(view, index)
    view.dateRows = view.dateRows or {}
    local row = view.dateRows[index]
    if row then return row end

    row = CreateFrame("Frame", nil, view.messageChild)
    view.dateRows[index] = row
    row.leftLine = row:CreateTexture(nil, "ARTWORK")
    row.leftLine:SetHeight(1)
    row.leftLine:SetColorTexture(Utils.RGB(CHAT_SEPARATOR_COLOR, 0.34))
    row.rightLine = row:CreateTexture(nil, "ARTWORK")
    row.rightLine:SetHeight(1)
    row.rightLine:SetColorTexture(Utils.RGB(CHAT_SEPARATOR_COLOR, 0.34))
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.text:SetPoint("CENTER", row, "CENTER")
    RegisterChatThemedText(row.text, 0.8)
    local mainFrame = UI._chatComposer.frame
    if mainFrame then
        mainFrame._efThemeSeps = mainFrame._efThemeSeps or {}
        local seps = mainFrame._efThemeSeps
        seps[#seps + 1] = row.leftLine
        seps[#seps + 1] = row.rightLine
        ns.RetintMenuSeparators(mainFrame)
    end
    row.leftLine:SetPoint("LEFT", row, "LEFT", 14, 0)
    row.leftLine:SetPoint("RIGHT", row.text, "LEFT", -8, 0)
    row.rightLine:SetPoint("LEFT", row.text, "RIGHT", 8, 0)
    row.rightLine:SetPoint("RIGHT", row, "RIGHT", -14, 0)
    row:Hide()
    self:RegisterChatFrameFonts(row)
    ns.ShadeText(row)
    return row
end

function UI:EnsureChatNoteRow(view, index)
    view.noteRows = view.noteRows or {}
    local row = view.noteRows[index]
    if row then return row end

    row = CreateFrame("Frame", nil, view.messageChild)
    view.noteRows[index] = row
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 14, 0)
    row.text:SetPoint("TOPRIGHT", row, "TOPRIGHT", -14, 0)
    row.text:SetJustifyH("CENTER")
    row.text:SetWordWrap(true)
    RegisterChatThemedText(row.text, 0.8)
    row:Hide()
    self:RegisterChatFrameFonts(row)
    ns.ShadeText(row)
    return row
end

-- Where the title bar names the open conversation: nil, "folded" (the
-- folded strip only) or "always" (saved as true before the choice).
function UI:GetChatConversationInTitle()
    local where = ChatDB().headerInTitle
    if where == true then return "always" end
    return where
end

-- The open conversation named in the title bar (an option) in place of
-- its header; not while composing, nor with the title bar folded.
function UI:IsChatHeaderInTitle()
    local frame = UI._chatComposer.frame
    local db = ChatDB()
    local key = UI._chatComposer.selectedConversationKey
    return self:GetChatConversationInTitle() == "always" and frame ~= nil and frame.titleFold ~= nil
        and frame.chatMode ~= "compose" and not UI._chatComposer.composeInPlace and db.titleFolded ~= true
        and key ~= nil and self:GetChatConversationStore().byKey[key] ~= nil
end

-- The folded strip names the open conversation (the same option).
function UI:IsChatConversationInFoldedTitle()
    local frame = UI._chatComposer.frame
    return self:GetChatConversationInTitle() ~= nil and frame ~= nil and frame.chatMode ~= "compose"
        and not UI._chatComposer.composeInPlace and ChatDB().titleFolded == true
end

-- What the title bar's text stops short of: the clock, else the arrow.
function UI:GetChatTitleRightEdge(frame)
    if ChatDB().showClock ~= false and frame.titleClock then return frame.titleClock end
    return frame.titleFold
end

function UI:LayoutChatMessengerChrome()
    local frame = UI._chatComposer.frame
    local view = frame and frame.messengerView
    if not view then return end

    local collapsed = self:IsChatSidebarCollapsed()
    local sidebarW = collapsed and CHAT_SIDEBAR_COLLAPSED_W
        or UI._chatComposer.sidebarLiveWidth or self:GetChatSidebarWidth()
    if view.sidebar then view.sidebar:SetWidth(sidebarW) end
    if view.detail and view.sidebar then
        view.detail:ClearAllPoints()
        view.detail:SetPoint("TOPLEFT", view.sidebar, "TOPRIGHT", collapsed and 6 or 8, 0)
        view.detail:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT")
    end
    if view.sidebarCollapseButton then
        view.sidebarCollapseButton:ClearAllPoints()
        view.sidebarCollapseButton:SetPoint(collapsed and "TOP" or "TOPRIGHT", view.sidebar,
            collapsed and "TOP" or "TOPRIGHT", collapsed and 0 or -10, -9)
        -- Arrow points right to expand when collapsed, left to collapse when open.
        if view.sidebarCollapseButton.arrow then
            view.sidebarCollapseButton.arrow:SetRotation(collapsed and (math.pi / 2) or (-math.pi / 2))
        end
        view.sidebarCollapseButton:Show()
    end
    if view.sidebarResizeHandle then
        view.sidebarResizeHandle:SetShown(not collapsed)
        view.sidebarResizeHandle:EnableMouse(not collapsed)
        if collapsed and view.sidebarResizeHandle.line then view.sidebarResizeHandle.line:Hide() end
    end
    if view.composeButton then
        view.composeButton:ClearAllPoints()
        view.composeButton:SetPoint("TOPRIGHT", view.sidebar, "TOPRIGHT", -36, -9)
        view.composeButton:SetShown(not collapsed)
    end
    if view.filterButton then view.filterButton:SetShown(not collapsed) end
    if view.sortButton then view.sortButton:SetShown(not collapsed) end

    local buttonH = view.composeButton and view.composeButton:GetHeight() or 22
    local searchLineH = self:GetChatFontLineHeight(view.searchEditBox, 12)
    local searchH = mmax(22, searchLineH + 8)
    local searchTop = 9 + buttonH + 3
    if not collapsed then view.sidebarSearchOpen = nil end
    local popped = view.sidebarSearchOpen == true
    local lens = view.sidebarSearchButton
    local collapsedTop = 9 + buttonH + 8
    if lens then
        lens:ClearAllPoints()
        lens:SetPoint("TOP", view.sidebarCollapseButton, "BOTTOM", 0, -4)
        lens:SetShown(collapsed)
        -- Lit while a search filters the icons, open or not.
        if popped or self:GetChatMessengerSearchQuery() ~= "" then
            lens.glyph:SetVertexColor(ChatAccentGlyphColor())
        else
            lens.glyph:SetVertexColor(0.9, 0.9, 0.92, 1)
        end
        if collapsed then collapsedTop = collapsedTop + 4 + lens:GetHeight() end
    end
    local shell = view.searchShell
    if shell then
        shell:ClearAllPoints()
        if collapsed and not popped then
            shell:Hide()
        elseif popped then
            -- Over the chat beside it, as wide as in the open sidebar.
            shell:SetPoint("LEFT", lens, "RIGHT", 6, 0)
            shell:SetWidth(mmin(220, self:GetChatSidebarWidth() - 16))
            shell:SetHeight(searchH)
            shell:Show()
        else
            shell:SetPoint("TOPLEFT", view.sidebar, "TOPLEFT", 8, -searchTop)
            shell:SetPoint("RIGHT", view.sidebar, "RIGHT", -8, 0)
            shell:SetHeight(searchH)
            shell:Show()
        end
        if shell._efPopped ~= popped then
            shell._efPopped = popped
            RaiseChatFrameTree(shell, popped and view:GetFrameLevel() + 30 or view.sidebar:GetFrameLevel() + 1)
        end
    end
    if view.searchEditBox then view.searchEditBox:SetHeight(searchLineH + 2) end
    local pick = view.charPickButton
    local picking = pick and not collapsed
    local pickH = 0
    if pick then
        pick:SetShown(picking)
        if picking then
            pickH = mmax(20, self:GetChatFontLineHeight(pick.text, 10) + 8)
            pick:ClearAllPoints()
            pick:SetPoint("TOPLEFT", view.sidebar, "TOPLEFT", 8, -(searchTop + searchH + 4))
            pick:SetPoint("RIGHT", view.sidebar, "RIGHT", -8, 0)
            pick:SetHeight(pickH)
            local shownChar = self:GetChatCharacterView()
            pick.text:SetText(shownChar and self:GetChatCharacterLabel(shownChar) or "All characters")
            pickH = pickH + 4
        end
    end

    local firstRow = view.conversationRows and view.conversationRows[1]
    local rowNameH = self:GetChatFontLineHeight(firstRow and firstRow.name, 12)
    local rowPreviewH = self:GetChatFontLineHeight(firstRow and firstRow.preview, 10)
    local rowH = mmax(32, rowNameH + rowPreviewH + 11)
    local rowGap = mmax(3, math.floor(3 * self:GetChatFontScale() + 0.5))
    local rowIcon = mmax(24, mmin(rowH - 8, rowNameH + 12))
    local rowStart = searchTop + searchH + 8 + pickH
    -- A folder's flyout lays its rows out as the open list does.
    view._sidebarRow = { h = rowH, gap = rowGap, icon = rowIcon }
    -- The game chats' row at the foot, a rule above it: the list ends above
    -- the rule. A filled panel keeps its 6 px inset at the bottom, as at
    -- its sides.
    local collapsedIcon = CHAT_SIDEBAR_COLLAPSED_W - 10
    local inset = ChatOnTree() and 0 or 6
    local footRowH = collapsed and (collapsedIcon + 4) or rowH
    local foot = footRowH + 2 * rowGap + 1
    -- As many whole rows as the sidebar holds, and one more the clip cuts
    -- at the rule, so the list reads as going on; the wheel scrolls the rest.
    if view.conversationRows then
        local step, top = rowH + rowGap, rowStart
        if collapsed then
            step, top = CHAT_SIDEBAR_COLLAPSED_W - 6 + rowGap, collapsedTop
        end
        local pad = inset + foot
        local whole = mmax(1, math.floor(((view.sidebar:GetHeight() or 0) - top - pad + rowGap) / step))
        local fit = whole + 1
        view.conversationFit, view.conversationWhole = fit, whole
        view._sidebarFit = { top = top, step = step, gap = rowGap, pad = pad }
        local clip = view.listClip
        clip:ClearAllPoints()
        clip:SetPoint("TOPLEFT", view.sidebar, "TOPLEFT", 0, -top)
        clip:SetPoint("BOTTOMRIGHT", view.sidebar, "BOTTOMRIGHT", 0, pad)
        while #view.conversationRows < fit do self:CreateChatConversationRow(view) end
    end
    if view.gameRow then
        local row, rule = view.gameRow, view.gameRule
        row.initialBg:ClearAllPoints()
        row.unread:ClearAllPoints()
        row:ClearAllPoints()
        rule:ClearAllPoints()
        if collapsed then
            row:SetSize(collapsedIcon + 4, collapsedIcon + 4)
            row:SetPoint("BOTTOM", view.sidebar, "BOTTOM", 0, inset)
            row.initialBg:SetSize(collapsedIcon, collapsedIcon)
            ns.SetRoundedRectBarHeight(row.initialBg, collapsedIcon)
            row.initialBg:SetPoint("CENTER")
            row.unread:SetPoint("CENTER", row.initialBg, "TOPRIGHT", -2, -2)
            rule:SetPoint("BOTTOMLEFT", view.sidebar, "BOTTOMLEFT", 8, inset + footRowH + rowGap)
            rule:SetPoint("BOTTOMRIGHT", view.sidebar, "BOTTOMRIGHT", -8, inset + footRowH + rowGap)
        else
            row:SetHeight(rowH)
            row:SetPoint("BOTTOMLEFT", view.sidebar, "BOTTOMLEFT", 6, inset)
            row:SetPoint("RIGHT", view.sidebar, "RIGHT", -6, 0)
            row.initialBg:SetSize(rowIcon, rowIcon)
            ns.SetRoundedRectBarHeight(row.initialBg, rowIcon)
            row.initialBg:SetPoint("LEFT", row, "LEFT", 7, 0)
            row.unread:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 4)
            rule:SetPoint("BOTTOMLEFT", view.sidebar, "BOTTOMLEFT", 12, inset + footRowH + rowGap)
            rule:SetPoint("BOTTOMRIGHT", view.sidebar, "BOTTOMRIGHT", -12, inset + footRowH + rowGap)
        end
    end
    if view.conversationRows then
        for i = 1, #view.conversationRows do
            local row = view.conversationRows[i]
            row.initialBg:ClearAllPoints()
            row.unread:ClearAllPoints()
            if collapsed then
                local iconSize = CHAT_SIDEBAR_COLLAPSED_W - 10
                row.deleteButton:Hide()
                row:SetHeight(iconSize + 4)
                row:ClearAllPoints()
                row:SetPoint("TOP", view.listClip, "TOP", 0, -(i - 1) * (iconSize + 4 + rowGap))
                row:SetWidth(iconSize + 4)
                row.initialBg:SetSize(iconSize, iconSize)
                ns.SetRoundedRectBarHeight(row.initialBg, iconSize)
                row.initialBg:SetPoint("CENTER")
                row.unread:SetPoint("CENTER", row.initialBg, "TOPRIGHT", -2, -2)
            else
                row:SetHeight(rowH)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", view.listClip, "TOPLEFT", 6, -(i - 1) * (rowH + rowGap))
                row:SetPoint("RIGHT", view.listClip, "RIGHT", -6, 0)
                row.initialBg:SetSize(rowIcon, rowIcon)
                ns.SetRoundedRectBarHeight(row.initialBg, rowIcon)
                row.initialBg:SetPoint("LEFT", row, "LEFT", 7, 0)
                row.unread:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 4)
            end
        end
    end

    -- Folded (its arrow) the header gives its height to the messages, the
    -- window keeping its size; one line puts the type after the name. A new
    -- message keeps it open for its To: field.
    local headerDB = ChatDB()
    local inTitle = self:IsChatHeaderInTitle()
    local folded = headerDB.headerFolded == true and not UI._chatComposer.composeInPlace and not inTitle
    local oneLine = headerDB.headerOneLine == true or inTitle
    local headerNameH = self:GetChatFontLineHeight(view.headerName, 14)
    local headerSubH = self:GetChatFontLineHeight(view.headerSubtext, 10)
    local iconSize
    if inTitle then
        view._chatHeaderHeight = 4
        iconSize = 22
    elseif folded then
        view._chatHeaderHeight = 18
    elseif oneLine then
        view._chatHeaderHeight = mmax(28, headerNameH + 8)
        iconSize = mmax(22, headerNameH + 4)
    else
        view._chatHeaderHeight = mmax(40, headerNameH + headerSubH + 11)
        iconSize = mmax(28, headerNameH + 12)
    end
    -- In the title bar the initial and name sit after the cog, on the view
    -- like the cog, so the new-message form hides them with it.
    local holder = inTitle and view or view.detail
    if view.headerName:GetParent() ~= holder then
        view.headerInitialBg:SetParent(holder)
        view.headerName:SetParent(holder)
    end
    view.headerInitialBg:ClearAllPoints()
    if inTitle then
        view.headerInitialBg:SetPoint("LEFT", view.settingsButton, "RIGHT", 7, 0)
    else
        view.headerInitialBg:SetPoint("TOPLEFT", view.detail, "TOPLEFT", 8, -4)
    end
    if view.headerInitialBg and iconSize then
        view.headerInitialBg:SetSize(iconSize, iconSize)
        ns.SetRoundedRectBarHeight(view.headerInitialBg, iconSize)
    end
    view.headerName:ClearAllPoints()
    if oneLine then
        view.headerName:SetPoint("LEFT", view.headerInitialBg, "RIGHT", inTitle and 7 or 9, 0)
    else
        view.headerName:SetPoint("TOPLEFT", view.headerInitialBg, "TOPRIGHT", 9, -1)
    end
    if inTitle then
        view.headerName:SetPoint("RIGHT", self:GetChatTitleRightEdge(frame), "LEFT", -8, 0)
    else
        local iconW = view.headerInitialBg:GetWidth() or 28
        view.headerName:SetWidth(mmax(20, (view.detail:GetWidth() or 0) - 8 - iconW - 9 - 26))
    end
    if view.headerFold then
        view.headerFold:SetShown(not UI._chatComposer.composeInPlace and not inTitle)
        view.headerFold.glyph:SetRotation(folded and 0 or math.pi)
    end
    if view.title then view.title:SetShown(not inTitle and headerDB.titleFolded ~= true) end
    if view.titleExp then view.titleExp:SetShown(view.title:IsShown()) end
    view._headerInTitle = inTitle

    local firstMessage = view.messageRows and view.messageRows[1]
    local messageLineH = self:GetChatFontLineHeight(firstMessage and firstMessage.copyBox, 12)
    view._chatMessageRowHeight = mmax(28, messageLineH + 12)
    view._chatMessageMetaHeight = mmax(14, self:GetChatFontLineHeight(firstMessage and firstMessage.meta, 10) + 2)
    view._chatMessageGap = mmax(5, math.floor(5 * self:GetChatFontScale() + 0.5))
    local firstDate = view.dateRows and view.dateRows[1]
    view._chatDateRowHeight = mmax(18, self:GetChatFontLineHeight(firstDate and firstDate.text, 10) + 6)
    view._chatDateGap = mmax(4, math.floor(4 * self:GetChatFontScale() + 0.5))
    view._chatReplyButtonWidth = mmax(56, self:GetChatFontLineHeight(view.replyButton and view.replyButton.text, 12) * 4)

    if view.messageScroll and view.messageChild then
        view.messageChild:SetWidth(view.messageScroll:GetWidth() or 0)
    end
    self:LayoutChatReplyInput()
end

-- A whisper that never arrived: its reason in red under it, one line per
-- message for as long as the message lives (the render keeps its place by it).
local undeliveredNotes = setmetatable({}, { __mode = "k" })
local function UndeliveredNote(msg)
    local note = undeliveredNotes[msg]
    if not note then
        note = { text = "|cffff6b6bNot delivered:|r " .. tostring(msg.failed), time = msg.time }
        undeliveredNotes[msg] = note
    end
    return note
end

-- Speakers' circles beside a room's messages: a setting, off unless on.
function UI:ShowsChatMessageAvatars()
    return ChatDB().messageAvatars == true
end

-- A speaker's circle: the chat with them when it is a person's (its icon,
-- color and letter), else one made the same way from their name.
local speakerConvo = { kind = "player", speaker = true }
function UI:PaintChatSpeakerAvatar(avatar, msg, source)
    local convo, key, letter
    if source.kind ~= "channel" then
        convo, key = source, source.key
        letter = self:GetChatConversationInitial(convo, key, self:GetChatConversationDisplayLabel(convo, key))
    else
        local name = msg.senderName or msg.senderLabel or ""
        local short = self:GetChatPlayerShortName(name)
        key = self:GetChatConversationKey("player", name, short)
        convo = self:GetChatConversationStore().byKey[key]
        if not convo then
            convo = speakerConvo
            convo.key, convo.class = key, msg.senderClass
        end
        letter = self:GetChatRecipientInitial(short)
    end
    avatar.letter:SetText(letter)
    local r, g, b = self:GetChatRecipientColor(key)
    ns.SetRoundedRectFill(avatar, r, g, b, 1, true)
    PaintAvatar(avatar, avatar.letter, convo)
end

function UI:BuildChatMessageRenderItems(messages, notes)
    local items = {}
    local previousDay
    local showFailed = self:ShowsChatDeliveryNotices()
    local function Add(entry, isNote)
        local day = self:GetChatMessageDayKey(entry and entry.time)
        if day ~= previousDay then
            items[#items + 1] = { kind = "date", time = entry and entry.time }
            previousDay = day
        end
        items[#items + 1] = isNote and { kind = "note", note = entry } or { kind = "message", message = entry }
        if not isNote and entry and entry.failed and showFailed then
            items[#items + 1] = { kind = "note", note = UndeliveredNote(entry) }
        end
    end
    local n = 1
    for i = 1, #(messages or {}) do
        local msg = messages[i]
        while notes and notes[n] and msg and notes[n].time < (msg.time or 0) do
            Add(notes[n], true)
            n = n + 1
        end
        Add(msg)
    end
    while notes and notes[n] do
        Add(notes[n], true)
        n = n + 1
    end
    return items
end

-- A command's output (GameLine.lua): a gray line in the chat it was typed
-- in, kept for the session only.
function UI:AddChatNote(key, text)
    if not key or text == "" then return end
    local notes = UI._chatComposer.notes or {}
    UI._chatComposer.notes = notes
    local list = notes[key] or {}
    notes[key] = list
    list[#list + 1] = { text = text, time = time() }
    if #list > 100 then tremove(list, 1) end
    self:QueueChatMessengerRefresh()
end

-- A link's color on a light theme's tint: its hue kept, dark enough for
-- the deeper bubble (ours), so it reads on both; no hue, the navy.
local function DarkenChatLinks(text)
    local br, bg, bb = ChatAccentColor()
    return (text:gsub("|c(%x%x)(%x%x)(%x%x)(%x%x)", function(alpha, rh, gh, bh)
        local r, g, b = tonumber(rh, 16) / 255, tonumber(gh, 16) / 255, tonumber(bh, 16) / 255
        local ir, ig, ib = ChatInk(r, g, b, br, bg, bb)
        if not ir then ir, ig, ib = ChatTextColor() end
        return string.format("|c%s%02x%02x%02x", alpha, math.floor(ir * 255 + 0.5),
            math.floor(ig * 255 + 0.5), math.floor(ib * 255 + 0.5))
    end))
end

-- Web addresses as links (a click copies them: the game opens no browser).
-- A word is one with a scheme, a www., or a known ending before its path;
-- words inside a game link or a color code stay as they are.
local Web = {}
Web.ENDINGS = {
    com = true, net = true, org = true, io = true, gg = true, tv = true, me = true, co = true, uk = true,
    de = true, fr = true, eu = true, us = true, ca = true, info = true, app = true, dev = true, ly = true,
    be = true, nl = true, ru = true, es = true, it = true, pl = true, se = true, au = true, xyz = true,
    gl = true, cc = true, edu = true, gov = true, link = true,
}
function Web.Address(word)
    if sfind(word, "|", 1, true) then return nil end
    local head, url, tail = word:match("^([%(%[<\"']*)(.-)([%.,;:!%?%)%]>\"']*)$")
    if url == "" then return nil end
    if url:match("^https?://[%w%-]") or url:match("^www%.[%w%-]+%.%a") then return url, head, tail end
    local domain = url:match("^([%w%-]+%.[%w%-%.]*%a)")
    local ending = domain and domain:match("%.(%a+)$")
    if ending and Web.ENDINGS[slower(ending)] then
        local rest = url:sub(#domain + 1)
        if rest == "" or rest:sub(1, 1) == "/" then return url, head, tail end
    end
    return nil
end

function Web.LinkWord(word)
    local url, head, tail = Web.Address(word)
    if not url then return word end
    return head .. "|cff5aa9ff|Hurl:" .. url .. "|h" .. url .. "|h|r" .. tail
end

function Web.LinkAll(text)
    if not (sfind(text, ".", 1, true)) then return text end
    return (text:gsub("%S+", Web.LinkWord))
end

function Web.First(text)
    for word in tostring(text or ""):gmatch("%S+") do
        local url = Web.Address(word)
        if url then return url end
    end
    return nil
end

-- Web addresses as links: a setting, on unless turned off.
function UI:ShowsChatWebLinks() return ChatDB().webLinks ~= false end

-- Only the newest messages are laid out, a few screens' worth: a whole long
-- channel cost 80 ms a switch (2026-10-27). Scrolling near the top lays out
-- more; a Jump target and the message at the top of a read view stay in.
local CHAT_RENDER_STEP = 30
local function ChatRenderFirst(items, count, top, jumpTo)
    local first = #items + 1
    if top then
        for i = #items, 1, -1 do
            if items[i].message == top or items[i].note == top then
                first = i
                break
            end
        end
    end
    if first > #items then
        local seen = 0
        for i = #items, 1, -1 do
            if items[i].kind == "message" then
                seen = seen + 1
                if seen > count then break end
            end
            first = i
        end
    end
    if jumpTo then
        for i = 1, first - 1 do
            if items[i].message == jumpTo then
                first = mmax(1, i - 4)
                break
            end
        end
    end
    -- A day's rule stays with its first message.
    if first > 1 and items[first - 1].kind == "date" then first = first - 1 end
    return mmin(first, mmax(1, #items))
end

function UI:RenderMoreChatHistory(view)
    local args = view._chatRenderArgs
    if not (args and (view._chatRenderedFrom or 1) > 1) then return end
    if args.key ~= UI._chatComposer.selectedConversationKey then return end
    view._chatRenderCount = (view._chatRenderCount or CHAT_RENDER_STEP) + CHAT_RENDER_STEP
    view._chatRenderTop = nil
    view._chatFromBottom = (view.messageScroll:GetVerticalScrollRange() or 0) - (view.messageScroll:GetVerticalScroll() or 0)
    self:RenderChatMessages(view, args.messages, args.key, args.notes)
end

function UI:QueueMoreChatHistory(view)
    if view._chatMorePending then return end
    view._chatMorePending = true
    C_Timer.After(0, function()
        view._chatMorePending = nil
        UI:RenderMoreChatHistory(view)
    end)
end

function UI:RenderChatMessages(view, messages, selectedKey, notes)
    if not (view and view.messageScroll and view.messageChild) then return end

    local oldKey = view._lastRenderedConversationKey
    local oldRange = view.messageScroll:GetVerticalScrollRange() or 0
    local oldScroll = view.messageScroll:GetVerticalScroll() or 0
    local stickToBottom = selectedKey ~= oldKey or oldRange <= 1 or oldScroll >= oldRange - 4
    view._lastRenderedConversationKey = selectedKey
    -- In a channel the speaker changes: incoming bubbles name them.
    local channelConvo = type(selectedKey) == "string" and selectedKey:sub(1, 8) == "channel:"
    local views = chatNS.Views
    local allView = views ~= nil and selectedKey == views.ALL
    local inlineSender = ChatDB().inlineSender ~= false
    -- Renamed, a chat with a person names them on their bubbles.
    local shownConvo = selectedKey and self:GetChatConversationStore().byKey[selectedKey]
    local renamedWith = shownConvo and shownConvo.customLabel and (shownConvo.kind == "player" or shownConvo.kind == "bn")
        and self:GetChatPlayerShortName(shownConvo.targetName or shownConvo.label or "") or nil
    if renamedWith == "" then renamedWith = nil end

    local items = self:BuildChatMessageRenderItems(messages, notes)
    -- More laid out above (a scroll up): as many again. At the bottom, the
    -- newest; reading higher, from the same top message.
    local morePass = view._chatFromBottom ~= nil
    if not morePass and (stickToBottom or selectedKey ~= oldKey) then
        view._chatRenderCount, view._chatRenderTop = CHAT_RENDER_STEP, nil
    end
    -- The first message unread when the chat opened: the New rule above it.
    local since = UI._chatComposer.newSince
    local divider = since and since.key == selectedKey and not view._chatJumpable
        and self:ShowsChatNewDivider() and since.msg or nil
    local dividerPlaced = false
    local first = ChatRenderFirst(items, view._chatRenderCount or CHAT_RENDER_STEP,
        not morePass and view._chatRenderTop or nil, UI._chatComposer.jumpTo or divider)
    view._chatRenderedFrom = first
    local top = items[first] and (items[first].message or items[first].note)
        or (items[first + 1] and (items[first + 1].message or items[first + 1].note))
    view._chatRenderTop = top
    local shownMessages = 0
    for i = first, #items do
        if items[i].kind == "message" then shownMessages = shownMessages + 1 end
    end
    view._chatRenderCount = mmax(shownMessages, CHAT_RENDER_STEP)
    view._chatRenderArgs = { messages = messages, key = selectedKey, notes = notes }
    local y = 0
    -- Retention cut rule: older messages were trimmed above this point.
    -- Same separator treatment as the window's header line.
    if view.retentionCut then view.retentionCut:Hide() end
    if type(messages) == "table" and messages.trimmed and first == 1 then
        if not view.retentionCut then
            local cut = view.messageChild:CreateTexture(nil, "OVERLAY")
            cut:SetHeight(1)
            cut:SetColorTexture(Utils.RGB(CHAT_SEPARATOR_COLOR, 0.35))
            view.retentionCut = cut
            local ownerFrame = UI._chatComposer.frame
            if ownerFrame and ownerFrame._efThemeSeps then
                ownerFrame._efThemeSeps[#ownerFrame._efThemeSeps + 1] = cut
                ns.RetintMenuSeparators(ownerFrame)
            end
        end
        view.retentionCut:ClearAllPoints()
        view.retentionCut:SetPoint("TOPLEFT", view.messageChild, "TOPLEFT", 6, -3)
        view.retentionCut:SetPoint("TOPRIGHT", view.messageChild, "TOPRIGHT", -6, -3)
        view.retentionCut:Show()
        y = y + 8
    end
    local placedRows = {}
    local messageIndex = 0
    local dateIndex = 0
    local noteIndex = 0
    local childW = view.messageScroll:GetWidth() or 0
    local rowGap = view._chatMessageGap or 5
    local metaH = view._chatMessageMetaHeight or 14
    local dateH = view._chatDateRowHeight or 18
    local dateGap = view._chatDateGap or 4
    local edgePad = 3
    local rightScrollGutter = 5
    -- The far side's gap shrinks with a narrow window, or bubbles had no room.
    local baseIndent = mmin(112, math.floor(childW * 0.22))
    local timeGap = 4
    local bubblePadX = 9
    local bubblePadY = 6
    local metaGap = 2

    -- Where a bubble's time sits (Extensions > Chat): in a column beside it
    -- (the default), in its corner, or in the corner while hovered.
    local timeMode = ChatDB().timePlacement or "beside"
    local timeBeside = timeMode == "beside"
    local timeTip = timeMode == "tooltip"
    local timeInlineGap = 8
    local lightInk = ChatLight() ~= nil
    local pinsOn = chatNS.Pins ~= nil and chatNS.Pins:Enabled()
    local webLinks = self:ShowsChatWebLinks()
    -- In a room others' bubbles wear the speaker's circle (Extensions >
    -- Chat), on the first of each run; their bubbles keep one column.
    local avatarSize = 0
    if (channelConvo or allView) and self:ShowsChatMessageAvatars() then
        avatarSize = mmax(18, self:GetChatFontLineHeight(self:EnsureChatMessageRow(view, 1).copyBox, 12) + 8)
    end
    local avatarGap = 5
    local avatarRoom = avatarSize > 0 and (avatarSize + avatarGap) or 0
    local runSpeaker
    -- A narrowed list's bubbles keep a strip at their foot for Jump: the
    -- button sits inside the bubble, over no words.
    local jumpRoom, jumpMinW = 0, 0
    if view._chatJumpable then
        local jump = self:EnsureChatJumpButton(view)
        jumpRoom, jumpMinW = jump:GetHeight() + 2, jump:GetWidth() + 8
    end
    -- Beside: one column for every bubble, as wide as the widest label, so
    -- every bubble edge lines up.
    local timeW = 0
    local timeProbe
    for i = first, timeBeside and #items or 0 do
        local msg = items[i].message
        if msg then
            timeProbe = timeProbe or self:EnsureChatMessageRow(view, 1).time
            local label = self:FormatChatBubbleTime(msg.time)
            timeW = mmax(timeW, self:GetChatMeasuredTextWidth(timeProbe, label))
        end
    end
    timeW = math.ceil(timeW + 2)

    for i = first, #items do
        local item = items[i]
        if item.kind == "date" then
            dateIndex = dateIndex + 1
            local row = self:EnsureChatDateRow(view, dateIndex)
            row:SetHeight(dateH)
            row.text:SetText(self:FormatChatMessageDay(item.time))
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", view.messageChild, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", view.messageChild, "TOPRIGHT", 0, -y)
            row:Show()
            placedRows[#placedRows + 1] = {
                row = row,
                y = y,
                date = true,
            }
            y = y + dateH + dateGap
            runSpeaker = nil
        elseif item.kind == "note" then
            noteIndex = noteIndex + 1
            local row = self:EnsureChatNoteRow(view, noteIndex)
            local _, noteH = self:GetChatWrappedTextMetrics(row.text, item.note.text, mmax(40, childW - 28))
            noteH = math.ceil(noteH)
            row:SetHeight(noteH)
            row.text:SetText(item.note.text)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", view.messageChild, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", view.messageChild, "TOPRIGHT", 0, -y)
            row:Show()
            placedRows[#placedRows + 1] = { row = row, y = y, date = true }
            y = y + noteH + dateGap
            runSpeaker = nil
        else
            local msg = item.message
            if msg and msg == divider then
                local rule = self:EnsureChatNewDivider(view)
                rule:SetHeight(dateH)
                rule:ClearAllPoints()
                rule:SetPoint("TOPLEFT", view.messageChild, "TOPLEFT", 0, -y)
                rule:SetPoint("TOPRIGHT", view.messageChild, "TOPRIGHT", 0, -y)
                rule:Show()
                placedRows[#placedRows + 1] = { row = rule, y = y, date = true }
                y = y + dateH + dateGap
                runSpeaker = nil
                dividerPlaced = true
            end
            if msg then
                messageIndex = messageIndex + 1
                local row = self:EnsureChatMessageRow(view, messageIndex)
                row.message = msg
                local quote = self:GetChatMessageQuote(msg)
                local metaLine = not msg.outgoing and ((channelConvo and msg.senderLabel) or renamedWith) or nil
                -- All: the room or person a line came from, the name in its
                -- class color.
                local metaShown, metaPre, metaName, metaFull
                if allView then
                    local post, class
                    metaPre, metaName, post, class, metaFull = views:AllMeta(msg)
                    metaLine = (metaPre or metaName) and ((metaPre or "") .. (metaName or "") .. (post or "")) or nil
                    metaShown = metaLine and ((metaPre or "")
                        .. (metaName and self:WrapChatClassName(metaName, class) or "") .. (post or ""))
                end
                local msgText = self:GetChatMessageDisplayText(msg)
                row._efCopyText = Utils.ClipboardSafeText and Utils.ClipboardSafeText(msgText) or msgText
                local links = ns.ResultLinks
                local linked = links and links.Linkify and links:Linkify(msgText) or msgText
                if webLinks then linked = Web.LinkAll(linked) end
                local hasLink = sfind(linked, "|H", 1, true) ~= nil
                if hasLink and lightInk then linked = DarkenChatLinks(linked) end
                local shownText = hasLink and linked or msgText
                -- One line (a setting): the speaker's name opens the words.
                local boxText = msgText
                local sender, inline = metaLine, metaLine and inlineSender
                if metaLine and inlineSender then
                    shownText = (metaShown or self:WrapChatClassName(metaLine, msg.senderClass)) .. ": " .. shownText
                    boxText = self:GetPlainChatLabel(metaLine) .. ": " .. msgText
                    metaLine = nil
                end
                local quoteName = quote and (quote.forward and ("Forwarded from " .. quote.sender) or quote.sender) or nil
                -- Before the text: a pooled label keeps its old side otherwise.
                row.time:SetJustifyH((timeBeside and msg.outgoing) and "LEFT" or "RIGHT")
                row.time:SetText(self:FormatChatBubbleTime(msg.time))

                local sideReserve = timeBeside and (timeW + timeGap) or 0
                local oppositeIndent = mmax(edgePad, baseIndent - sideReserve)
                local leftOffset = msg.outgoing and oppositeIndent or (edgePad + sideReserve + avatarRoom)
                local rightOffset = msg.outgoing and (edgePad + rightScrollGutter + sideReserve) or oppositeIndent
                local maxBubbleW = mmax(40, childW - leftOffset - rightOffset)
                local naturalTextW = self:GetChatMeasuredTextWidth(row.copyBox, shownText)
                local naturalMetaW = metaLine and self:GetChatMeasuredTextWidth(row.meta, metaLine) or 0
                local maxTextW = mmax(8, maxBubbleW - bubblePadX * 2)
                -- The quote's name and words widen the bubble too, the words
                -- up to the bubble's cap, where they wrap.
                local quoteNameW = quote and (self:GetChatMeasuredTextWidth(row.quote.name, quoteName) + CHAT_QUOTE_INSET) or 0
                local quoteTextW = (quote and quote.text) and
                    mmin(maxTextW, self:GetChatMeasuredTextWidth(row.quote.text, quote.text) + CHAT_QUOTE_INSET) or 0
                -- 1px rounding guard only: the text is left-justified inside
                -- symmetric insets, so every extra slack pixel shows up as
                -- lopsided right-side padding (8px here read as clearly off).
                local textWidthSlack = 1
                -- Inside: the time ends the text's line when one line holds
                -- both, else it takes a line of its own under the text.
                local ownTimeW = 0
                if not timeBeside and not timeTip then
                    ownTimeW = math.ceil(self:GetChatMeasuredTextWidth(row.time, row.time:GetText()) + 1)
                end
                local timeOwnLine = false
                local inlineW = naturalTextW
                if not timeBeside and not timeTip then
                    local oneLine = not sfind(shownText, "\n", 1, true)
                        and naturalTextW + timeInlineGap + ownTimeW <= maxTextW
                    if oneLine then
                        inlineW = naturalTextW + timeInlineGap + ownTimeW
                    else
                        timeOwnLine = true
                    end
                end
                local measuredTextW = mmax(1, math.ceil(mmax(inlineW, naturalMetaW, quoteNameW, quoteTextW))) + textWidthSlack
                local textW = mmin(maxTextW, measuredTextW)
                local bubbleW = mmax(jumpMinW, math.ceil(textW + bubblePadX * 2))

                local _, textH = self:GetChatWrappedTextMetrics(row.copyBox, shownText, mmax(8, textW))
                textH = mmax(1, math.ceil(textH))
                -- Wrapped: the time still ends the last line when it fits
                -- there (a blank its width added does not add a line).
                if timeOwnLine then
                    local spacer = string.format("|TInterface\\Buttons\\WHITE8X8:1:%d|t", timeInlineGap + ownTimeW)
                    local _, withH = self:GetChatWrappedTextMetrics(row.copyBox, shownText .. spacer, mmax(8, textW))
                    if math.ceil(withH) <= textH then timeOwnLine = false end
                end
                local timeLineH = timeOwnLine and self:GetChatFontLineHeight(row.time, 10) or 0
                local bottomPad = bubblePadY + timeLineH + jumpRoom
                local quoteH = 0
                if quote then
                    local nameH = self:GetChatFontLineHeight(row.quote.name, 12)
                    quoteH = nameH
                    if quote.text then
                        local _, qh = self:GetChatWrappedTextMetrics(row.quote.text, quote.text, mmax(8, textW - CHAT_QUOTE_INSET))
                        local lineH = row.quote.text:GetStringHeight() or 11
                        quoteH = quoteH + 1 + mmin(math.ceil(qh), math.ceil(lineH * 2) + 2)
                    end
                    quoteH = quoteH + 2
                end
                local thisRowH = math.ceil(bubblePadY + (metaLine and (metaH + metaGap) or 0)
                    + (quote and (quoteH + metaGap + 2) or 0) + textH + bottomPad)
                row:SetSize(bubbleW, thisRowH)
                row.copyBox:ClearAllPoints()
                if quote then
                    row.meta:Hide()
                    row.quote.name:SetText(quoteName)
                    row.quote.text:SetText(quote.text or "")
                    row.quote.text:SetShown(quote.text ~= nil)
                    row.quote:ClearAllPoints()
                    row.quote:SetPoint("TOPLEFT", row, "TOPLEFT", bubblePadX, -bubblePadY)
                    row.quote:SetPoint("RIGHT", row, "RIGHT", -bubblePadX, 0)
                    row.quote:SetHeight(quoteH)
                    row.quote:Show()
                    row.copyBox:SetPoint("TOPLEFT", row.quote, "BOTTOMLEFT", 0, -(metaGap + 2))
                    row.copyBox:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -bubblePadX, bottomPad)
                elseif metaLine then
                    row.quote:Hide()
                    row.meta:SetText(metaShown or self:WrapChatClassName(metaLine, msg.senderClass))
                    row.meta:ClearAllPoints()
                    row.meta:SetPoint("TOPLEFT", row, "TOPLEFT", bubblePadX, -bubblePadY)
                    row.meta:SetPoint("RIGHT", row, "RIGHT", -bubblePadX, 0)
                    row.meta:SetHeight(metaH)
                    row.meta:Show()
                    row.copyBox:SetPoint("TOPLEFT", row.meta, "BOTTOMLEFT", 0, -metaGap)
                    row.copyBox:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -bubblePadX, bottomPad)
                else
                    row.meta:Hide()
                    row.quote:Hide()
                    row.copyBox:SetPoint("TOPLEFT", row, "TOPLEFT", bubblePadX, -bubblePadY)
                    row.copyBox:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -bubblePadX, bottomPad)
                end
                if row.copyBox.SetJustifyV then
                    row.copyBox:SetJustifyV("TOP")
                end
                row.copyBox._chatText = boxText
                if not (row.copyBox.HasFocus and row.copyBox:HasFocus()) then
                    row.copyBox:SetText(boxText)
                    row.copyBox:HighlightText(0, 0)
                    row.copyBox:SetCursorPosition(0)
                elseif row.copyBox:GetText() ~= boxText then
                    row.copyBox:SetText(boxText)
                end
                -- Ctrl+C over the speaker's name copies the name: their whole
                -- name, as the player menu's Copy Character Name has it.
                local nameTarget = row.nameTarget
                nameTarget:ClearAllPoints()
                if sender and (inline or row.meta:IsShown()) and (metaName or not allView) then
                    local full = metaFull or (channelConvo and (msg.senderName or sender))
                        or (shownConvo and shownConvo.targetName) or sender
                    nameTarget._efCopyText = self:GetPlainChatLabel(full)
                    -- In All the name follows its room's tag.
                    local nameX = metaPre and self:GetChatMeasuredTextWidth(inline and row.copyBox or row.meta, metaPre) or 0
                    if inline then
                        nameTarget:SetPoint("TOPLEFT", row.copyBox, "TOPLEFT", nameX, 0)
                        nameTarget:SetSize(mmax(1, self:GetChatMeasuredTextWidth(row.copyBox,
                            self:GetPlainChatLabel(metaName or sender))), self:GetChatFontLineHeight(row.copyBox))
                    elseif metaName then
                        nameTarget:SetPoint("TOPLEFT", row.meta, "TOPLEFT", nameX, 0)
                        nameTarget:SetSize(mmax(1, self:GetChatMeasuredTextWidth(row.meta, self:GetPlainChatLabel(metaName))), metaH)
                    else
                        nameTarget:SetPoint("TOPLEFT", row.meta, "TOPLEFT")
                        nameTarget:SetSize(mmax(1, mmin(row.meta:GetStringWidth() or 0, row.meta:GetWidth() or 0)), metaH)
                    end
                    nameTarget:Show()
                else
                    nameTarget._efCopyText = nil
                    nameTarget:Hide()
                    row.nameHighlight:Hide()
                end
                -- Width from the box, height from the words: never cut short.
                local font, size, flags = row.copyBox:GetFont()
                if font and size then row.linkText:SetFont(font, size, flags) end
                row.linkText:ClearAllPoints()
                row.linkText:SetPoint("TOPLEFT", row.copyBox, "TOPLEFT")
                row.linkText:SetPoint("TOPRIGHT", row.copyBox, "TOPRIGHT")
                row.linkText:SetText(shownText)
                -- A link needs the plain line to click: no box over it.
                row.copyBox:SetShown(not hasLink)
                row:ClearAllPoints()
                if msg.outgoing then
                    row:SetPoint("TOPRIGHT", view.messageChild, "TOPRIGHT", -rightOffset, -y)
                else
                    row:SetPoint("TOPLEFT", view.messageChild, "TOPLEFT", leftOffset, -y)
                end
                placedRows[#placedRows + 1] = {
                    row = row,
                    y = y,
                    outgoing = msg.outgoing,
                    leftOffset = leftOffset,
                    rightOffset = rightOffset,
                }
                row.time:ClearAllPoints()
                if timeBeside then
                    row.time:SetWidth(timeW)
                    if msg.outgoing then
                        row.time:SetPoint("LEFT", row, "RIGHT", timeGap, 0)
                    else
                        row.time:SetPoint("RIGHT", row, "LEFT", -(timeGap + avatarRoom), 0)
                    end
                else
                    row.time:SetWidth(ownTimeW)
                    row.time:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -bubblePadX, bubblePadY + jumpRoom)
                end
                row.pinMark:ClearAllPoints()
                if msg.outgoing then
                    row.pinMark:SetPoint("RIGHT", row, "TOPLEFT", -3, -9)
                else
                    row.pinMark:SetPoint("LEFT", row, "TOPRIGHT", 3, -9)
                end
                row.pinMark:SetShown(pinsOn and msg.pinned == true)
                local speakerAt = avatarSize > 0 and not msg.outgoing
                    and (allView and views:SourceOf(msg) or shownConvo) or nil
                if speakerAt and speakerAt.kind == "system" then speakerAt = nil end
                local speaker = speakerAt and (speakerAt.kind ~= "channel" and speakerAt.key
                    or msg.senderName or msg.senderLabel) or nil
                local newRun = speaker ~= nil and speaker ~= runSpeaker
                runSpeaker = speaker
                if newRun then
                    row.avatar:SetSize(avatarSize, avatarSize)
                    ns.SetRoundedRectBarHeight(row.avatar, avatarSize)
                    row.avatar:ClearAllPoints()
                    row.avatar:SetPoint("TOPRIGHT", row, "TOPLEFT", -avatarGap, 0)
                    self:PaintChatSpeakerAvatar(row.avatar, msg, speakerAt)
                end
                row.avatar:SetShown(newRun)
                row._timeOnHover = timeMode == "hover"
                row.time:SetShown(not timeTip and (timeMode ~= "hover" or ChatRowHovered(row)))
                row._chatPaint = msg.outgoing and "accent"
                    or (msg.mention and self:ShowsChatMentions() and "mention") or "bubbleIn"
                PaintChatRowRest(row)
                -- Light themes carry light bubble fills (the NAV pill model
                -- inverts), so bubble text flips to the theme's dark text.
                local bubbleTheme = ns.Results and ns.Results.GetActiveTheme
                    and ns.Results:GetActiveTheme()
                local faint = bubbleTheme and bubbleTheme.lightTheme and bubbleTheme.textFaint
                if faint then
                    row.time:SetTextColor(faint[1], faint[2], faint[3], 1)
                elseif timeBeside then
                    row.time:SetTextColor(0.5, 0.5, 0.5, 1)
                else
                    row.time:SetTextColor(1, 1, 1, msg.outgoing and 0.72 or 0.55)
                end
                if bubbleTheme and bubbleTheme.lightTheme then
                    local tr, tg, tb = ChatTextColor()
                    row.text:SetTextColor(tr, tg, tb, 1)
                    row.linkText:SetTextColor(tr, tg, tb, 1)
                    row.meta:SetTextColor(tr, tg, tb, 0.72)
                    row.quote.name:SetTextColor(tr, tg, tb, 1)
                    row.quote.text:SetTextColor(tr, tg, tb, 0.72)
                    row.quote.bar:SetColorTexture(tr, tg, tb, 0.8)
                else
                    row.text:SetTextColor(1, 1, 1, 1)
                    row.linkText:SetTextColor(1, 1, 1, 1)
                    row.meta:SetTextColor(0.64, 0.64, 0.68, 1)
                    row.quote.name:SetTextColor(1, 1, 1, 1)
                    row.quote.text:SetTextColor(0.78, 0.78, 0.82, 1)
                    if msg.outgoing then
                        row.quote.bar:SetColorTexture(1, 1, 1, 0.8)
                    else
                        local ar, ag, ab = ChatAccentColor()
                        row.quote.bar:SetColorTexture(ar, ag, ab, 1)
                    end
                end
                ShowBubbleWords(row)
                row:Show()
                y = y + thisRowH + rowGap
            end
        end
    end

    for i = messageIndex + 1, #(view.messageRows or {}) do
        view.messageRows[i].message = nil
        view.messageRows[i]:Hide()
    end
    if view.jumpButton then view.jumpButton:Hide() end
    for i = dateIndex + 1, #(view.dateRows or {}) do view.dateRows[i]:Hide() end
    for i = noteIndex + 1, #(view.noteRows or {}) do view.noteRows[i]:Hide() end
    if view.newDivider and not dividerPlaced then view.newDivider:Hide() end

    -- Others' lines come in below while reading higher: the newest button
    -- counts them.
    local count = type(messages) == "table" and #messages or 0
    local seen = view._chatLastMessage
    if selectedKey ~= oldKey or view._chatJumpable then
        view._chatNewBelow = 0
    elseif not stickToBottom and seen and messages[count] ~= seen then
        for i = count, mmax(1, count - 50), -1 do
            if messages[i] == seen then break end
            if not messages[i].outgoing then view._chatNewBelow = (view._chatNewBelow or 0) + 1 end
        end
    end
    view._chatLastMessage = count > 0 and messages[count] or nil

    local viewH = view.messageScroll:GetHeight() or 0
    local contentH = mmax(viewH, y)
    view.messageChild:SetSize(childW, contentH)
    local topPad = mmax(0, viewH - y)
    if topPad > 0 then
        for i = 1, #placedRows do
            local placed = placedRows[i]
            local row = placed.row
            row:ClearAllPoints()
            if placed.date then
                row:SetPoint("TOPLEFT", view.messageChild, "TOPLEFT", 0, -(placed.y + topPad))
                row:SetPoint("TOPRIGHT", view.messageChild, "TOPRIGHT", 0, -(placed.y + topPad))
            elseif placed.outgoing then
                row:SetPoint("TOPRIGHT", view.messageChild, "TOPRIGHT",
                    -placed.rightOffset, -(placed.y + topPad))
            else
                row:SetPoint("TOPLEFT", view.messageChild, "TOPLEFT",
                    placed.leftOffset, -(placed.y + topPad))
            end
        end
    end
    local range = mmax(0, contentH - viewH)
    local scrollTo = stickToBottom and range or mmin(oldScroll, range)
    if morePass then
        -- Older messages laid out above: the view keeps its place.
        scrollTo = mmax(0, range - view._chatFromBottom)
        view._chatFromBottom = nil
    end
    local jumpTo = UI._chatComposer.jumpTo
    if jumpTo then
        UI._chatComposer.jumpTo = nil
        for i = 1, #placedRows do
            local placed = placedRows[i]
            if placed.row.message == jumpTo then
                local rowH = placed.row:GetHeight() or 0
                scrollTo = mmax(0, mmin(range, placed.y + topPad - (viewH - rowH) / 2))
                self:FlashChatMessageRow(placed.row, jumpTo)
                break
            end
        end
    end
    view.messageScroll:SetVerticalScroll(scrollTo)
    self:UpdateChatMessageScrollBar(contentH, viewH)
    self:UpdateChatNewestButton(view, range - scrollTo)
    -- Too little to scroll toward the older ones: more now.
    if first > 1 and y < viewH * 2 then self:QueueMoreChatHistory(view) end
end

-- The New rule and the newest button: settings, on unless turned off.
function UI:ShowsChatNewDivider() return ChatDB().newDivider ~= false end
function UI:ShowsChatNewestButton() return ChatDB().newestButton ~= false end

-- A chat about to be read with unread lines: its first unread one, where
-- the New rule goes while the chat stays open.
function UI:NoteChatNewSince(key, convo)
    local unread = convo and tonumber(convo.unread) or 0
    local messages = convo and convo.messages
    if unread <= 0 or type(messages) ~= "table" then return end
    local found = 0
    for i = #messages, 1, -1 do
        if not messages[i].outgoing then
            found = found + 1
            if found == unread then
                UI._chatComposer.newSince = { key = key, msg = messages[i] }
                return
            end
        end
    end
end

-- The rule above the first unread line: red, as a missed message reads.
function UI:EnsureChatNewDivider(view)
    if view.newDivider then return view.newDivider end
    local rule = CreateFrame("Frame", nil, view.messageChild)
    view.newDivider = rule
    rule:Hide()
    rule.text = rule:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rule.text:SetPoint("CENTER")
    rule.text:SetText("New messages")
    rule.text:SetTextColor(1, 0.42, 0.42, 1)
    rule.leftLine = rule:CreateTexture(nil, "ARTWORK")
    rule.leftLine:SetHeight(1)
    rule.leftLine:SetColorTexture(1, 0.42, 0.42, 0.7)
    rule.leftLine:SetPoint("LEFT", rule, "LEFT", 14, 0)
    rule.leftLine:SetPoint("RIGHT", rule.text, "LEFT", -8, 0)
    rule.rightLine = rule:CreateTexture(nil, "ARTWORK")
    rule.rightLine:SetHeight(1)
    rule.rightLine:SetColorTexture(1, 0.42, 0.42, 0.7)
    rule.rightLine:SetPoint("LEFT", rule.text, "RIGHT", 8, 0)
    rule.rightLine:SetPoint("RIGHT", rule, "RIGHT", -14, 0)
    self:RegisterChatFrameFonts(rule)
    ns.ShadeText(rule)
    return rule
end

-- Shown while the view sits more than half a screen above the newest.
-- below: the layout's own distance; the frame's range lags a frame behind
-- a relaid child (a short chat opened read the long one's and showed it).
function UI:UpdateChatNewestButton(view, below)
    local button = view and view.newestButton
    if not button then return end
    local scroll = view.messageScroll
    below = below or (scroll:GetVerticalScrollRange() or 0) - (scroll:GetVerticalScroll() or 0)
    local show = self:ShowsChatNewestButton() and below > mmax(40, (scroll:GetHeight() or 0) * 0.5)
    if not show then view._chatNewBelow = 0 end
    button.count:SetCount(view._chatNewBelow or 0)
    button:SetShown(show)
end

function UI:ScrollChatToNewest()
    local view = ChatMessengerView()
    if not view then return end
    view._chatNewBelow = 0
    view.messageScroll:SetVerticalScroll(view.messageScroll:GetVerticalScrollRange() or 0)
    self:UpdateChatNewestButton(view)
end

-- A message's searchable text, stripped and lowered once per session
-- instead of on every keystroke; redone if the stored text changes.
local searchTextOf = setmetatable({}, { __mode = "k" })
local searchPlainOf = setmetatable({}, { __mode = "k" })
local function MessageSearchText(msg)
    local text = msg.text or ""
    if searchTextOf[msg] ~= text then
        searchTextOf[msg] = text
        searchPlainOf[msg] = slower(UI:GetPlainChatLabel(text))
    end
    return searchPlainOf[msg]
end

function UI:ChatSearchTextMatches(text, query, queryWords, plain)
    text = plain or slower(self:GetPlainChatLabel(text or ""))
    if text == "" or query == "" then return false end
    if sfind(text, query, 1, true) then return true end
    if ns.Database and ns.Database.ScoreName then
        local score = ns.Database:ScoreName(text, query, #query, queryWords)
        return score and score > 0
    end
    return false
end

function UI:GetChatMessengerSearchQuery()
    local frame = UI._chatComposer.frame
    local view = frame and frame.messengerView
    if not (view and view.searchEditBox) then return "" end
    return slower(strtrim(view.searchEditBox:GetText() or ""))
end

function UI:BuildChatMessengerSearchResults(store, query)
    local order = store and store.order or {}
    query = strtrim(query or "")
    if query == "" then return order, nil, nil end
    -- from:Name: the chats that speaker has lines in, narrowed to those.
    if sfind(query, "from:", 1, true) then
        local visibleOrder, messagesByKey, previewByKey = {}, {}, {}
        for oi = 1, #order do
            local key = order[oi]
            local convo = store.byKey[key]
            local matched = convo and convo.messages and self:FilterChatMessages(convo.messages, query)
            if matched and #matched > 0 then
                visibleOrder[#visibleOrder + 1] = key
                messagesByKey[key] = matched
                previewByKey[key] = matched[#matched].text
            end
        end
        return visibleOrder, messagesByKey, previewByKey
    end

    local queryWords
    if sfind(query, " ", 1, true) then
        queryWords = {}
        for word in query:gmatch("%S+") do queryWords[#queryWords + 1] = word end
    end

    local visibleOrder = {}
    local messagesByKey = {}
    local previewByKey = {}
    local byKey = store.byKey or {}
    for oi = 1, #order do
        local key = order[oi]
        local convo = byKey[key]
        if convo then
            local convoMatches = self:ChatSearchTextMatches(convo.label, query, queryWords)
                or self:ChatSearchTextMatches(convo.source, query, queryWords)
            local matchedMessages
            local messages = convo.messages or {}
            for mi = 1, #messages do
                local msg = messages[mi]
                if msg and self:ChatSearchTextMatches(nil, query, queryWords, MessageSearchText(msg)) then
                    matchedMessages = matchedMessages or {}
                    matchedMessages[#matchedMessages + 1] = msg
                end
            end
            if convoMatches or matchedMessages then
                visibleOrder[#visibleOrder + 1] = key
                if matchedMessages then
                    messagesByKey[key] = matchedMessages
                    previewByKey[key] = matchedMessages[#matchedMessages].text
                else
                    previewByKey[key] = convo.lastMessage
                end
            end
        end
    end
    return visibleOrder, messagesByKey, previewByKey
end

function UI:ChatOrderContainsKey(order, key)
    if not key then return false end
    for i = 1, #order do
        if order[i] == key then return true end
    end
    return false
end

-- A speaker's name lowered; stripped only when it carries a code.
local function PlainSpeaker(text)
    text = text or ""
    if sfind(text, "|", 1, true) then text = UI:GetPlainChatLabel(text) end
    return slower(text)
end

-- A message's speaker: the shown name and the full one.
local function MessageSpeakers(msg)
    return PlainSpeaker(msg.senderLabel), PlainSpeaker(msg.senderName)
end

local function SpeakerStarts(msg, prefix)
    local label, name = MessageSpeakers(msg)
    return sfind(label, prefix, 1, true) == 1 or sfind(name, prefix, 1, true) == 1
end

-- The open chat's filter: from:Name (or from:"Two Words") keeps one
-- speaker's lines; other words match the words or the speaker.
function UI:FilterChatMessages(messages, filter)
    -- An open quote runs to the end while the name is typed.
    local from = filter:match('from:"([^"]+)"?') or filter:match("from:([^%s\"]+)")
    local rest = strtrim((filter:gsub('from:"[^"]*"?', " "):gsub("from:%S*", " ")))
    local queryWords
    if sfind(rest, " ", 1, true) then
        queryWords = {}
        for word in rest:gmatch("%S+") do queryWords[#queryWords + 1] = word end
    end
    local out = {}
    for i = 1, #messages do
        local msg = messages[i]
        if msg and (not from or SpeakerStarts(msg, from))
           and (rest == "" or SpeakerStarts(msg, rest)
                or self:ChatSearchTextMatches(nil, rest, queryWords, MessageSearchText(msg))) then
            out[#out + 1] = msg
        end
    end
    return out
end

function UI:GetChatMessageFilter()
    local frame = UI._chatComposer.frame
    local view = frame and frame.messengerView
    if not (view and view.filterOpen and view.filterEditBox) then return "" end
    return slower(strtrim(view.filterEditBox:GetText() or ""))
end

-- Opened by Ctrl+F, its glyph, or a speaker's menu row (text given).
function UI:OpenChatMessageFilter(text)
    local frame = UI._chatComposer.frame
    local view = frame and frame.messengerView
    if not (view and view.filterEditBox) then return end
    view.filterOpen = true
    if text then
        view._filterQuiet = true
        view.filterEditBox:SetText(text)
        view._filterQuiet = nil
    end
    self:RefreshChatMessenger()
    -- A frame late: the key that opened it must not type into it.
    Utils.SafeAfter(0, function()
        if not view.filterShell:IsShown() then return end
        UI:FocusChatEditBox(view.filterEditBox)
        view.filterEditBox:HighlightText()
    end)
end

-- quiet: the caller redraws.
function UI:CloseChatMessageFilter(quiet)
    local frame = UI._chatComposer.frame
    local view = frame and frame.messengerView
    if not (view and view.filterOpen) then return end
    view.filterOpen = nil
    view._filterQuiet = true
    view.filterEditBox:SetText("")
    view._filterQuiet = nil
    view.filterEditBox:ClearFocus()
    if not quiet then self:RefreshChatMessenger() end
end

-- Ctrl+F in the chat's own boxes, and from the Ctrl catcher over the
-- window: the open chat's filter.
function UI:HandleChatFindKey(_, key)
    if key ~= "F" or not IsControlKeyDown() then return false end
    local frame = UI._chatComposer.frame
    local view = frame and frame.messengerView
    if not (view and frame.chatMode == "messenger" and view:IsVisible()) then return false end
    if UI._chatComposer.composeInPlace or not UI._chatComposer.selectedConversationKey then return false end
    self:OpenChatMessageFilter()
    return true
end

-- The filter box (its glyph while closed) at the header's right, left of
-- its fold arrow, or of the title bar's clock or arrow with the header in
-- it; the name gives it the room.
function UI:LayoutChatMessageFilter(view, available)
    local frame = UI._chatComposer.frame
    local shell, button = view.filterShell, view.messageFilterButton
    if not (shell and button) then return end
    local inTitle = view._headerInTitle == true
    local open = available and view.filterOpen == true
    local holder = inTitle and view or view.detail
    local anchor = inTitle and self:GetChatTitleRightEdge(frame) or view.headerFold
    if shell:GetParent() ~= holder then
        shell:SetParent(holder)
        button:SetParent(holder)
    end
    shell:SetFrameLevel(holder:GetFrameLevel() + 7)
    button:SetFrameLevel(holder:GetFrameLevel() + 6)
    shell:SetShown(open)
    button:SetShown(available and not open)
    local detailW = view.detail:GetWidth() or 0
    local shellW = mmin(200, mmax(110, math.floor(detailW * 0.42)))
    shell:SetWidth(shellW)
    shell:ClearAllPoints()
    shell:SetPoint("RIGHT", anchor, "LEFT", -4, 0)
    button:ClearAllPoints()
    button:SetPoint("RIGHT", anchor, "LEFT", -2, 0)
    -- The pin, while the chat has pins: left of the filter.
    local pins = view.pinsButton
    local pinned = pins and available and chatNS.Pins
        and chatNS.Pins:Count(UI._chatComposer.selectedConversationKey) > 0 or false
    if pins then
        if pins:GetParent() ~= holder then pins:SetParent(holder) end
        pins:SetFrameLevel(holder:GetFrameLevel() + 6)
        pins:ClearAllPoints()
        pins:SetPoint("RIGHT", open and shell or button, "LEFT", -2, 0)
        pins:SetShown(pinned)
    end
    if inTitle then
        local edge = (pinned and pins) or (open and shell) or (available and button) or anchor
        view.headerName:SetPoint("RIGHT", edge, "LEFT", -8, 0)
    else
        local used = open and (shellW + 4) or (available and (button:GetWidth() + 2) or 0)
        if pinned then used = used + pins:GetWidth() + 2 end
        local iconW = view.headerInitialBg:GetWidth() or 28
        view.headerName:SetWidth(mmax(20, detailW - 8 - iconW - 9 - 26 - used))
    end
end

-- The filter's box, hidden until Ctrl+F, and the glyph that opens it.
function UI:CreateChatMessageFilter(view, detail)
    local button = CreateFrame("Button", nil, detail)
    view.messageFilterButton = button
    button:SetSize(16, 16)
    button.glyph = button:CreateTexture(nil, "OVERLAY")
    button.glyph:SetTexture(ns.SEARCH_ICON_TEX)
    button.glyph:SetSize(12, 12)
    button.glyph:SetPoint("CENTER")
    RegisterChatThemedText(button.glyph, 0.75)
    button:SetScript("OnClick", function() UI:OpenChatMessageFilter() end)
    button:SetScript("OnEnter", function(self) ShowChatTipDelayed(self, "ANCHOR_TOP", "Filter messages (Ctrl+F)") end)
    button:SetScript("OnLeave", function(self) HideChatTip(self) end)
    button:Hide()

    local shell = CreateFrame("Frame", nil, detail)
    view.filterShell = shell
    shell:SetHeight(20)
    local well = self:StyleChatInputWell(shell, 7)
    shell:EnableMouse(true)
    shell:SetScript("OnMouseDown", function() UI:FocusChatEditBox(view.filterEditBox) end)
    shell:Hide()
    local placeholder = well:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", shell, "LEFT", 8, 0)
    placeholder:SetPoint("RIGHT", shell, "RIGHT", -22, 0)
    placeholder:SetJustifyH("LEFT")
    placeholder:SetWordWrap(false)
    placeholder:SetText("Filter")
    RegisterChatThemedText(placeholder, 0.5)
    -- Clears the words, then (empty) closes the filter.
    local clear = ns.CreateCloseX(well, 14)
    clear:SetPoint("RIGHT", shell, "RIGHT", -4, 0)
    clear:SetScript("OnClick", function()
        if (view.filterEditBox:GetText() or "") ~= "" then
            view.filterEditBox:SetText("")
            UI:FocusChatEditBox(view.filterEditBox)
        else
            UI:CloseChatMessageFilter()
        end
    end)
    local box = CreateFrame("EditBox", nil, well)
    view.filterEditBox = box
    box:SetPoint("LEFT", shell, "LEFT", 8, 0)
    box:SetPoint("RIGHT", clear, "LEFT", -4, 0)
    box:SetHeight(18)
    box:SetAutoFocus(false)
    box:SetFontObject(GameFontHighlightSmall)
    box._chatInput = true
    RegisterChatThemedText(box)
    RegisterChatThemedText(box)
    if box.SetTextInsets then box:SetTextInsets(0, 0, 0, 0) end
    box:SetScript("OnTextChanged", function(self)
        placeholder:SetShown((self:GetText() or "") == "")
        if not view._filterQuiet then UI:RefreshChatMessenger() end
    end)
    box:SetScript("OnEditFocusGained", function() UI:ClearChatMessageCopyFocus() end)
    Utils.ReleaseFocusOnOutsideClick(box)
    -- Esc empties it, then closes it.
    box:SetScript("OnEscapePressed", function(self)
        if (self:GetText() or "") ~= "" then self:SetText("") else UI:CloseChatMessageFilter() end
    end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnKeyDown", function(self, key)
        UI:ArmChatHoveredCopy(self, key)
        if key == "F" and IsControlKeyDown() then self:HighlightText() end
    end)
end

-- Jump: back to the whole chat at this message, the search and the filter
-- cleared, as if scrolled to it.
function UI:JumpToChatMessage(msg)
    local frame = UI._chatComposer.frame
    local view = frame and frame.messengerView
    if not (view and msg) then return end
    UI._chatComposer.jumpTo = msg
    self:CloseChatMessageFilter(true)
    if view.searchEditBox and (view.searchEditBox:GetText() or "") ~= "" then
        view.searchEditBox:SetText("")
    else
        self:RefreshChatMessenger()
    end
end

-- One Jump for the list, on the bubble under the mouse.
function UI:EnsureChatJumpButton(view)
    local jump = view.jumpButton
    if jump then return jump end
    jump = ns.CreateModernButton(view.messageChild, "", 40, 18)
    view.jumpButton = jump
    jump:SetText("Jump")
    jump:SetWidth(math.ceil(jump._label:GetUnboundedStringWidth()) + 16)
    jump:SetFrameLevel(view.messageChild:GetFrameLevel() + 40)
    jump:SetHitRectInsets(-4, -4, -4, -4)
    jump:SetScript("OnClick", function(self) UI:JumpToChatMessage(self.row and self.row.message) end)
    jump:HookScript("OnLeave", function(self) if self.row then UI:HideChatJump(self.row) end end)
    jump:Hide()
    return jump
end

function UI:ShowChatJump(row)
    local view = UI._chatComposer.frame and UI._chatComposer.frame.messengerView
    if not (row.message and view and view._chatJumpable) then return end
    local jump = self:EnsureChatJumpButton(view)
    jump.row = row
    jump:ClearAllPoints()
    -- In the bubble's foot strip: outside it, the gap to the button ended
    -- the hover before a click (IsMouseOver skips hit insets).
    jump:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 3)
    jump:Show()
end

function UI:HideChatJump(row)
    local view = UI._chatComposer.frame and UI._chatComposer.frame.messengerView
    local jump = view and view.jumpButton
    if not jump or jump.row ~= row then return end
    if not (ChatRowHovered(row) or jump:IsMouseOver()) then jump:Hide() end
end

function UI:SelectChatConversation(key)
    local left = UI._chatComposer.selectedConversationKey
    if chatNS.Views and key == chatNS.Views.COMBAT then chatNS.Views:NoteCameFrom(left) end
    -- Chat to chat the chrome stays as it is: only leaving a new message's
    -- view changes it.
    local keepChrome = not UI._chatComposer.composeInPlace
    self:SaveCurrentChatReplyDraft()
    UI._chatComposer.composeInPlace = nil
    if UI._chatComposer.selectedConversationKey ~= key then
        UI._chatComposer.pendingReply = nil
        self:CloseChatMessageFilter(true)
    end
    UI._chatComposer.selectedConversationKey = key
    local store = self:GetChatConversationStore()
    local convo = key and store.byKey[key] or nil
    if left ~= key then UI._chatComposer.newSince = nil end
    self:NoteChatNewSince(key, convo)
    if convo then convo.unread, convo.markedUnread = 0, nil end
    self:UpdateChatUnreadBadge()
    self:LoadChatDraftForKey(key)
    UI._chatComposer.keepChrome = keepChrome or nil
    self:RefreshChatMessenger()
    UI._chatComposer.keepChrome = nil
    if left and left ~= key then self:DropEmptyFlipConversation(left) end
end

function UI:DeleteChatConversation(key)
    if not key then return false end
    local store = self:GetChatConversationStore()
    if not store.byKey[key] then return false end
    store.byKey[key] = nil
    if chatNS.Views then chatNS.Views:Forget() end
    self:ForgetChatSpeakers()
    EasyFind.API.RefreshSearchProvider("chat")
    for i = #store.order, 1, -1 do
        if store.order[i] == key then
            tremove(store.order, i)
            break
        end
    end
    if UI._chatComposer.selectedConversationKey == key then
        UI._chatComposer.selectedConversationKey = store.order[1]
    end
    self:SaveChatDraftForKey(key, "")
    self:LoadChatDraftForKey(UI._chatComposer.selectedConversationKey)
    self:RefreshChatMessenger()
    return true
end

function UI:StartChatReplyToMessage(convo, msg, key)
    local ref = self:BuildChatMessageRef(convo, msg, key)
    if not ref then return false end
    UI._chatComposer.pendingReply = ref
    UI._chatComposer.pendingReply.key = key
    local frame = UI._chatComposer.frame
    local view = frame and frame.messengerView
    if view and view.replyEditBox then
        self:LayoutChatReplyInput()
        view.replyEditBox:SetFocus()
    end
    return true
end

function UI:StartChatForwardMessage(convo, msg, key)
    local ref = self:BuildChatMessageRef(convo, msg, key)
    if not ref then return false end
    local sendText = self:BuildChatForwardWireText(ref)
    UI._chatComposer.channel = "WHISPER"
    self:ShowChatComposeView(true)
    UI._chatComposer.pendingForward = {
        text = ref.text,
        senderLabel = ref.senderLabel,
        sendText = sendText,
    }
    local frame = UI._chatComposer.frame
    if frame and frame.messageEditBox then
        frame.messageEditBox:SetText(sendText)
        frame.messageEditBox:SetCursorPosition(#sendText)
    end
    self:RefreshChatComposerChannel()
    self:RefreshChatComposerSendState()
    return true
end

function UI:GetChatForwardSendMeta(line)
    local pending = UI._chatComposer.pendingForward
    if not (pending and pending.sendText == line) then return nil end
    return {
        displayText = pending.text,
        forwardedFrom = {
            senderLabel = pending.senderLabel,
            text = pending.text,
        },
        senderLabel = self:GetChatPlayerName() or "You",
    }
end

-- Hovering a bubble shows what it does not show itself, in one tooltip:
-- a note on the speaker (their name, then the note, as their tooltip in
-- the world has it) and, when times live here, the day and time. Battle.net
-- friends carry no character name to look a note up by.
function UI:ShowChatBubbleTip(row)
    local msg = row.message
    if not msg then return end
    local stamp = (ChatDB().timePlacement or "beside") == "tooltip" and msg.time
        and (self:FormatChatMessageDay(msg.time) .. ", " .. self:FormatChatBubbleTime(msg.time)) or nil
    local sender, playerKey
    if not msg.outgoing and EasyFind.API.HasAction("notes", "hasUnitNote") and ns.NotesPlayerKey then
        local key = UI._chatComposer.selectedConversationKey
        local convo = key and self:GetChatConversationStore().byKey[key]
            or (chatNS.Views and chatNS.Views:SourceOf(msg))
        sender = msg.senderName or (convo and convo.kind == "player" and (convo.targetName or convo.label))
        playerKey = sender and ns.NotesPlayerKey(self:GetPlainChatLabel(sender))
        if playerKey and not EasyFind.API.CallAction("notes", "hasUnitNote", "player", playerKey) then
            playerKey = nil
        end
    end
    if not (stamp or playerKey) then return end
    GameTooltip:SetOwner(row, msg.outgoing and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
    if playerKey then
        GameTooltip:SetText(self:GetChatPlayerShortName(sender), 1, 1, 1)
        if stamp then GameTooltip:AddLine(stamp, 0.7, 0.7, 0.7) end
        EasyFind.API.CallAction("notes", "addUnitNoteLines", GameTooltip, "player", playerKey)
    else
        GameTooltip:SetText(stamp, 1, 1, 1)
    end
    GameTooltip:Show()
    row._bubbleTip = true
end

function UI:HideChatBubbleTip(row)
    if not row._bubbleTip then return end
    row._bubbleTip = nil
    if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
end

function UI:ShowChatMessageMenu(row)
    if not (row and row.message) then return end
    local key = UI._chatComposer.selectedConversationKey
    local store = self:GetChatConversationStore()
    local convo = key and store.byKey[key] or nil
    local msg = row.message
    -- All acts on the chat a line came from; System on its own.
    local views = chatNS.Views
    local fromAll = views ~= nil and key == views.ALL
    if fromAll then
        convo = views:SourceOf(msg)
        key = convo and convo.key
    elseif views and key == views.SYSTEM then
        convo = views:Get(key)
    end
    if not convo then return end
    local copyText = self:GetChatMessageDisplayText(msg)
    local rows = {
        { text = "Copy Message", onClick = function() UI:CopyChatMessageText(copyText) end },
    }
    local url = self:ShowsChatWebLinks() and Web.First(copyText)
    if url then rows[#rows + 1] = { text = "Copy Link", onClick = function() UI:CopyChatMessageText(url) end } end
    if convo.kind == "player" or convo.kind == "bn" then
        rows[#rows + 1] = { text = "Reply", onClick = function()
            if fromAll then UI:SelectChatConversation(key) end
            UI:StartChatReplyToMessage(convo, msg, key)
        end }
    end
    rows[#rows + 1] = { text = "Forward", onClick = function() UI:StartChatForwardMessage(convo, msg, key) end }
    local pins = chatNS.Pins
    if pins and pins:Enabled() and key and store.byKey[key] == convo then
        rows[#rows + 1] = { text = msg.pinned and "Unpin Message" or "Pin Message",
            onClick = function() pins:TogglePin(msg) end }
    end
    -- An EasyFind link in it: a macro that runs the link.
    local links = ns.ResultLinks
    local linkKey, linkName
    if links and links.FirstLink then linkKey, linkName = links:FirstLink(copyText) end
    if linkKey then
        rows[#rows + 1] = { text = ns.L["CTX_CREATE_MACRO"], tooltip = ns.L["CTX_CREATE_MACRO_TT"],
            onClick = function() links:CreateMacro(linkKey, linkName) end }
    end
    -- One speaker's lines through the filter, which shows how it is done.
    local speaker = self:GetPlainChatLabel(msg.senderLabel or "")
    if speaker ~= "" then
        local token = sfind(speaker, " ", 1, true) and ('from:"' .. speaker .. '"') or ("from:" .. speaker)
        rows[#rows + 1] = { text = ("Show only %s's messages"):format(speaker),
            onClick = function() UI:OpenChatMessageFilter(token) end }
    end
    -- Someone else's line: whisper them from a channel, or ask them to the group.
    if not msg.outgoing then
        local sender
        if convo.kind == "channel" then
            sender = msg.senderName or msg.senderLabel
        elseif convo.kind == "player" then
            sender = convo.targetName or convo.label
        end
        if sender and sender ~= "" then
            if convo.kind == "channel" then
                rows[#rows + 1] = { text = _G["WHISPER"] or "Whisper", onClick = function() UI:StartChatWhisperWith(sender) end }
            end
            rows[#rows + 1] = { text = _G["INVITE"] or "Invite", onClick = function() UI:InviteChatSender(sender) end }
            local view = UI._chatComposer.frame and UI._chatComposer.frame.messengerView
            local head = view and view.headerNameTarget
            local hit = row.nameTarget:IsShown() and row.nameTarget
                or (head and head:IsVisible() and head._efCopyText and head) or nil
            self:AddChatPlayerMenuRows(rows, sender, hit)
        end
    end
    Utils.ShowCursorMenu("EasyFindChatMessageMenu", rows, {
        strata = "TOOLTIP",
        level = 100,
        rowHeight = 22,
        offsetX = 4,
        offsetY = -4,
    })
end

-- Copy Character Name points at the name it copies: a hint over it, and
-- while the cursor is on the name Ctrl+C takes it. The hint goes with the
-- copy, Esc or a click.
local nameHint = {}
local function CloseNameHint()
    local holder = nameHint.holder
    if not (holder and holder:IsShown()) then return end
    holder:Hide()
    if nameHint.hit then ns.HideHintTooltip(nameHint.hit) end
    Utils.DisarmClipboardBox(true, nameHint.client)
    nameHint.hit, nameHint.name, nameHint.armed = nil, nil, nil
end
nameHint.client = {
    OnCopied = function()
        local hit = nameHint.hit
        -- The native copy ends on this key event: let go a frame later.
        Utils.SafeAfter(0, function()
            CloseNameHint()
            if hit and hit:IsVisible() and Utils.FlashCopied then Utils.FlashCopied(hit) end
        end)
    end,
    HoldsFocus = function() return nameHint.armed == true and nameHint.hit ~= nil and nameHint.hit:IsMouseOver() end,
    OnDisarm = function() nameHint.armed = nil end,
    OnKey = function(key)
        if key == "ESCAPE" then return CloseNameHint() end
        Utils.DisarmClipboardBox(true, nameHint.client)
    end,
}

local function EnsureNameHint()
    if nameHint.holder then return nameHint.holder end
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:Hide()
    holder:SetScript("OnShow", function(self)
        self._shownAt = GetTime()
        self:RegisterEvent("GLOBAL_MOUSE_DOWN")
    end)
    holder:SetScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
    -- The press that chose the menu row arrives here too: a short grace.
    holder:SetScript("OnEvent", function(self)
        if GetTime() - (self._shownAt or 0) >= 0.05 then CloseNameHint() end
    end)
    holder:SetScript("OnUpdate", function()
        local hit = nameHint.hit
        if not (hit and hit:IsVisible()) then return CloseNameHint() end
        if hit:IsMouseOver() then
            if not nameHint.armed then
                nameHint.armed = true
                Utils.ArmClipboardBox(nameHint.name, nil, nameHint.client)
            end
        elseif nameHint.armed then
            Utils.DisarmClipboardBox(true, nameHint.client)
        end
    end)
    if ns.AttachEscClose then ns.AttachEscClose(holder, CloseNameHint) end
    nameHint.holder = holder
    return holder
end

function UI:ShowChatNameCopyHint(hit, name)
    CloseNameHint()
    local holder = EnsureNameHint()
    nameHint.hit, nameHint.name = hit, name
    ns.ShowHintTooltip(hit, "ANCHOR_TOP", nil, rawget(ns.L, "CHAT_HOVER_COPY_NAME") or "Hover name and Ctrl+C.")
    holder:Show()
end

-- A player's menu entries, as the game's own player menu has them: copy
-- the name, add a friend, ignore, and EasyFind's note on them. hit: the
-- name's frame on screen, where Copy Character Name points.
function UI:AddChatPlayerMenuRows(rows, sender, hit)
    local name = self:GetPlainChatLabel(sender)
    if name == "" then return end
    rows[#rows + 1] = { text = _G["COPY_CHARACTER_NAME"] or "Copy Character Name", tooltip = ns.L["CHAT_COPY_NAME_TT"],
        onClick = function()
            if hit then
                UI:ShowChatNameCopyHint(hit, name)
            elseif ns.CopyToClipboard then
                ns.CopyToClipboard(name)
            end
        end }
    local FL = C_FriendList
    if FL and FL.AddFriend then
        rows[#rows + 1] = { text = _G["ADD_FRIEND"] or "Add Friend", onClick = function() FL.AddFriend(name) end }
    end
    if FL and FL.AddIgnore then
        local ignored = FL.IsIgnored and FL.IsIgnored(name)
        rows[#rows + 1] = { text = ignored and "Unignore" or (_G["IGNORE"] or "Ignore"), onClick = function()
            if ignored and FL.DelIgnore then FL.DelIgnore(name) else FL.AddIgnore(name) end
        end }
    end
    local key = ns.NotesPlayerKey and ns.NotesPlayerKey(name)
    if key and ns.IsCompanionLoadable and ns.IsCompanionLoadable("EasyFind_Notes") then
        local entry = { type = "player", id = key, name = name:match("^([^%-]+)") or name }
        local has = EasyFind.API.HasAction("notes", "findUnitNote")
            and EasyFind.API.CallAction("notes", "findUnitNote", entry)
        rows[#rows + 1] = { text = has and ns.L["NOTES_OPEN_NOTE"] or ns.L["NOTES_MAKE_NOTE"], onClick = function()
            EasyFind.API.CallAction("notes", "openUnitNote", entry)
        end }
    end
end

-- Opens (or starts) the whisper conversation with a channel speaker, the
-- input focused.
function UI:StartChatWhisperWith(name)
    local short = self:GetChatPlayerShortName(name)
    local key = self:GetChatConversationKey("player", name, short)
    local convo = self:TouchChatConversation(key, short, "player", "Whisper")
    if not convo then return end
    convo.targetName = convo.targetName or name
    self:SelectChatConversation(key)
    local view = UI._chatComposer.frame and UI._chatComposer.frame.messengerView
    if view and view.replyEditBox then self:FocusChatEditBox(view.replyEditBox) end
end

function UI:InviteChatSender(name)
    local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or _G["InviteUnit"]
    if invite then invite(name) end
end

function UI:SendChatMessengerReply()
    local frame = UI._chatComposer.frame
    local view = frame and frame.messengerView
    local editBox = view and view.replyEditBox
    if not editBox then return false end
    local text = strtrim(editBox:GetText() or "")
    local lines = self:GetChatMessageLines(text)
    if #lines == 0 then return false end

    if UI._chatComposer.composeInPlace then
        return self:SendChatComposeInPlaceMessage(view, lines, editBox)
    end

    local store = self:GetChatConversationStore()
    local key = UI._chatComposer.selectedConversationKey
    local convo = key and store.byKey[key] or nil
    if not convo then return false end
    local sent = 0
    local pendingReply = UI._chatComposer.pendingReply
    if pendingReply and pendingReply.key ~= key then pendingReply = nil end
    for i = 1, #lines do
        local line = lines[i]
        -- The quote rides the first line only; the rest send plain.
        local reply = i == 1 and pendingReply or nil
        local sendLine = reply and self:BuildChatReplyWireText(reply, line) or line
        local meta = reply and {
            displayText = line,
            senderLabel = self:GetChatPlayerName() or "You",
            replyTo = {
                senderLabel = reply.senderLabel,
                text = reply.text,
            },
        } or nil
        local entry
        if convo.kind == "bn" then
            local id = self:GetChatBNAccountID(convo, key)
            if id then
                entry = { kind = "bn", presenceID = id, text = sendLine }
            elseif i == 1 and _G["UIErrorsFrame"] then
                -- Off the friend list: the client's own line for it.
                local refusal = _G["BN_UNABLE_TO_RESOLVE_NAME"] or "Unable to whisper '%s'. Battle.net may be unavailable."
                _G["UIErrorsFrame"]:AddMessage(refusal:format(self:GetChatConversationPlainLabel(convo, key)), 1, 0.1, 0.1)
            end
        elseif convo.kind == "player" then
            entry = { text = sendLine, channel = "WHISPER", target = convo.targetName or convo.label }
        elseif convo.kind == "channel" then
            local def = CHAT_TYPE_CHANNELS[(key:match("^channel:(.+)$") or ""):upper()]
            if def then
                entry = { text = sendLine, channel = def.key }
            elseif convo.channelIndex then
                entry = { text = sendLine, channel = "CHANNEL", target = convo.channelIndex }
            end
        end
        if entry then
            entry.efConvoKey = key
            entry.efConvo = convo
            entry.efMeta = meta
            entry.onSent = ChatReplyEntrySent
            if SendChatEntry(entry) then sent = sent + 1 end
        end
    end
    if sent > 0 then
        UI._chatComposer.pendingReply = nil
        self:SaveChatDraftForKey(key, "")
        editBox:SetText("")
        self:LayoutChatReplyInput()
        return true
    end
    return false
end

-- A numbered channel's number now, by its name: numbers move between
-- sessions and joins.
function UI:GetChatChannelNumber(name)
    if not (GetChannelList and name) then return nil end
    local list = { GetChannelList() }
    for i = 1, #list, 3 do
        local base = type(list[i + 1]) == "string" and self:GetPlainChatLabel(list[i + 1]) or ""
        if (base:match("^(.-)%s+%-%s+") or base) == name and not list[i + 2] then return list[i] end
    end
    return nil
end

-- The game's chat type for a conversation, as its own line takes one: the
-- type and its target (a channel's number, a whisper's name).
function UI:GetChatConversationChatType(key)
    local convo = key and self:GetChatConversationStore().byKey[key]
    if not convo then return nil end
    if convo.kind == "player" then return "WHISPER", convo.targetName or convo.label end
    if convo.kind == "bn" then
        local info = self:GetChatBNFriendInfo(convo, key)
        local name = info and info.accountName
        if not name then return nil end
        return "BN_WHISPER", name
    end
    if convo.kind ~= "channel" then return nil end
    local def = CHAT_TYPE_CHANNELS[(key:match("^channel:(.+)$") or ""):upper()]
    if def then return def.key end
    local number = self:GetChatChannelNumber(convo.label) or convo.channelIndex
    if not number then return nil end
    return "CHANNEL", number
end

-- The other way: the conversation a chat type and its target are,
-- made as a message would make it when there is none yet. One made here
-- is marked until its first message: left empty, it goes.
function UI:TouchChatConversationForChatType(chatType, target)
    local key, label, kind, source, convo, bnTag
    local def = chatType and CHAT_TYPE_CHANNELS[chatType]
    if def then
        key, label, kind, source = self:GetChatConversationKey("channel", def.key, def.label), def.label, "channel", def.label
    elseif chatType == "WHISPER" and type(target) == "string" and target ~= "" then
        label = self:GetChatPlayerShortName(target)
        key, kind, source = self:GetChatConversationKey("player", target, label), "player", "Whisper"
    elseif chatType == "BN_WHISPER" and target then
        local id = BNet_GetBNetIDAccount and BNet_GetBNetIDAccount(target)
        if not id then return nil end
        key, bnTag = self:GetChatBNConversationKey(id)
        label = self:GetChatBNTagName(bnTag) or "Battle.net"
        kind, source = "bn", "Battle.net"
    elseif chatType == "CHANNEL" and target and GetChannelName then
        local _, channelName = GetChannelName(target)
        local name = type(channelName) == "string" and self:GetPlainChatLabel(channelName) or ""
        name = name:match("^(.-)%s+%-%s+") or name
        if name == "" then return nil end
        key, label, kind, source = self:GetChatConversationKey("channel", "#" .. name, name), name, "channel", "Channel"
    else
        return nil
    end
    local made = self:GetChatConversationStore().byKey[key] == nil
    convo = self:TouchChatConversation(key, label, kind, source)
    if not convo then return nil end
    if made then convo.flipMade = true end
    if kind == "player" then convo.targetName = convo.targetName or target end
    if kind == "bn" then convo.battleTag = bnTag or convo.battleTag end
    return key
end

-- A chat the line made, still without a message.
function UI:IsChatConversationFlipEmpty(key)
    local convo = key and self:GetChatConversationStore().byKey[key]
    return convo ~= nil and convo.flipMade == true and #(convo.messages or {}) == 0
end

-- Left empty (another chat chosen, the window closed, the line let go): it
-- goes, its draft with it.
function UI:DropEmptyFlipConversation(key)
    if self:IsChatConversationFlipEmpty(key) then self:DeleteChatConversation(key) end
end

-- At load: one left empty when the game last closed.
function UI:DropEmptyFlipConversations()
    local keys = {}
    for key in pairs(self:GetChatConversationStore().byKey) do
        if self:IsChatConversationFlipEmpty(key) then keys[#keys + 1] = key end
    end
    for i = 1, #keys do self:DeleteChatConversation(keys[i]) end
end

function UI:SendChatComposeInPlaceMessage(view, lines, editBox)
    -- Sweep any half-typed name into the chip set, then fan the message out
    -- to every chip -- the same multi-recipient model as the compose view.
    local c = UI._chatComposer
    if view.headerRecipientEdit and strtrim(view.headerRecipientEdit:GetText() or "") ~= "" then
        self:ConsumeChatRecipientInput(false)
    end
    if #c.recipients == 0 then
        if view.headerRecipientEdit then self:FocusChatEditBox(view.headerRecipientEdit) end
        return false
    end

    local sent = 0
    local firstKey
    for r = 1, #c.recipients do
        local recipient = c.recipients[r]
        local kind = recipient.kind
        local sentToRecipient = false
        for i = 1, #lines do
            local line = lines[i]
            local entry
            if kind == "bn" then
                entry = { kind = "bn", presenceID = recipient.id, text = line,
                    efLabel = recipient.label, onSent = ChatComposeBNEntrySent }
            else
                local target = recipient.name or recipient.id
                entry = { text = line, channel = "WHISPER", target = target,
                    onSent = ChatComposePlayerEntrySent }
            end
            if entry and SendChatEntry(entry) then
                sent = sent + 1
                sentToRecipient = true
            end
        end
        if sentToRecipient and not firstKey then
            if kind == "bn" then
                firstKey = self:GetChatBNConversationKey(recipient.id)
            else
                local target = recipient.name or recipient.id
                firstKey = self:GetChatConversationKey("player", target, target)
            end
        end
    end
    if sent == 0 then return false end

    if editBox then editBox:SetText("") end
    if view.headerRecipientEdit then view.headerRecipientEdit:SetText("") end
    wipe(c.recipients)
    wipe(c.recipientLookup)
    UI._chatComposer.composeInPlace = nil
    self:RefreshChatComposerRecipients()
    if firstKey then self:SelectChatConversation(firstKey) end
    return true
end

function UI:BeginChatComposeInPlace()
    local frame = self:EnsureChatComposerFrame()
    if frame.chatMode ~= "messenger" then
        self:ShowChatMessengerView()
    end
    self:SaveCurrentChatReplyDraft()
    UI._chatComposer.composeInPlace = true
    UI._chatComposer.selectedConversationKey = nil
    UI._chatComposer.pendingReply = nil
    -- Fresh compose: no recipients carried over from the compose view.
    wipe(UI._chatComposer.recipients)
    wipe(UI._chatComposer.recipientLookup)
    local view = frame.messengerView
    if view then
        if view.replyEditBox then view.replyEditBox:SetText("") end
        if view.headerRecipientEdit then view.headerRecipientEdit:SetText("") end
        view._loadedDraftKey = nil
    end
    self:RefreshChatMessenger()
    if view and view.headerRecipientEdit then
        self:FocusChatEditBox(view.headerRecipientEdit)
        self:RefreshChatComposerRecipients()
        self:RefreshChatRecipientSuggestions()
    end
end

-- A chat's row, in the list or a folder's flyout: its avatar, name and
-- last line, the time, pin and bell, and the unread count.
function UI:FillChatConversationRow(row, key, convo, preview, selected, collapsed)
    local label = self:GetChatConversationDisplayLabel(convo, key)
    row.conversationKey = key
    row.tipLabel = label
    row.name:SetShown(not collapsed)
    row.preview:SetShown(not collapsed)
    row.time:SetShown(not collapsed)
    row.initial:SetText(self:GetChatConversationInitial(convo, key, label))
    local r, g, b = self:GetChatRecipientColor(key)
    ns.SetRoundedRectFill(row.initialBg, r, g, b, 1, true)
    PaintAvatar(row.initialBg, row.initial, convo)
    self:SetChatConversationRowTime(row, self:FormatChatConversationTime(convo.lastTime))
    -- Pin, then bell, right to left before the time, on the time's line:
    -- placed from the row's corner, so a chat with no time yet (no
    -- messages) keeps them on that line.
    local pinned = convo.pinned == true and not collapsed
    local muted = self:IsChatConversationMuted(key)
    local nameLeft = 7 + (row.initialBg:GetWidth() or 24) + 7
    local iconsW = (pinned and 14 or 0) + ((muted and not collapsed) and 14 or 0)
    local timeW = math.ceil(row.time:GetStringWidth() or 0)
    -- Too narrow for both: the time gives way to the name.
    if timeW > 0 and (row:GetWidth() or 0) - nameLeft - iconsW - timeW - 10 < 40 then
        row.time:SetText("")
        timeW = 0
    end
    local lineMid = -(3 + self:GetChatFontLineHeight(row.time, 10) / 2)
    local x = -(6 + timeW + (timeW > 0 and 4 or 0))
    row.pin:ClearAllPoints()
    row.pin:SetPoint("RIGHT", row, "TOPRIGHT", x, lineMid)
    row.pin:SetShown(pinned)
    if pinned then x = x - 11 - 3 end
    row.muted:ClearAllPoints()
    row.muted:SetPoint("RIGHT", row, "TOPRIGHT", x, lineMid)
    row.muted:SetShown(muted and not collapsed)
    if muted and not collapsed then x = x - 11 - 3 end
    -- Its top-left and a width: one line tall, the preview under it.
    row.name:ClearAllPoints()
    row.name:SetPoint("TOPLEFT", row.initialBg, "TOPRIGHT", 7, -1)
    row.name:SetWidth(mmax(1, (row:GetWidth() or 0) - nameLeft + x - 2))
    SetClippedText(row.name, self:WrapChatClassName(label or "Conversation", convo.kind == "player" and convo.class))
    -- An unsent message waits in another chat: it shows in place of the last
    -- one, as a phone's messenger lists it.
    local draft = not preview and not selected and self:ShowsChatDrafts() and self:GetChatDraftStore()[key]
    if draft then
        SetClippedText(row.preview, "|cffff6b6bDraft:|r " .. self:GetChatPreviewText(draft))
    else
        SetClippedText(row.preview, self:GetChatPreviewText(preview or convo.lastMessage))
    end
    -- The badge's own red (none given), as the chat button wears it; gray muted.
    local ur, ug, ub
    if muted and self:GetChatMentionCount(convo) == 0 then ur, ug, ub = 0.42, 0.42, 0.46 end
    row.unreadCount, row.unreadR, row.unreadG, row.unreadB = convo.unread or 0, ur, ug, ub
    local deleting = row.hovering and not collapsed and not row.isView
    row.unread:SetCount(not deleting and row.unreadCount or 0, ur, ug, ub)
    row.deleteButton:SetShown(deleting and true or false)
    row.isSelected = selected and true or false
    self:RepaintChatListRow(row)
    row.collapsedLayout, row.presenceText = collapsed, self:GetPlainChatLabel(label or "")
    self:PlaceChatRowPresence(row, convo, key)
end

-- The other side's presence, a disc right of the name in the header:
-- green online, yellow away, red busy, gray offline, none when no list
-- knows them. A character is looked up in the friends list, then the
-- guild roster; a Battle.net friend by their account.
local PRESENCE_DISC = "Interface\\AddOns\\EasyFind\\textures\\FilterButtonCircle"
local PRESENCE_COLOR = { online = { 0.30, 0.80, 0.36 }, away = { 0.95, 0.76, 0.22 },
                         busy = { 0.88, 0.30, 0.28 }, offline = { 0.46, 0.46, 0.50 } }
local PRESENCE_RIM = { 0.06, 0.05, 0.08 }
local guildPresence = {}

local function PresenceOf(online, afk, dnd)
    if not online then return "offline" end
    if dnd then return "busy" end
    if afk then return "away" end
    return "online"
end

function UI:ReadChatGuildPresence()
    wipe(guildPresence)
    if not (IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo) then return end
    for i = 1, GetNumGuildMembers() or 0 do
        local name, _, _, _, _, _, _, _, online, status = GetGuildRosterInfo(i)
        local first = FirstName(name)
        if first then guildPresence[first] = PresenceOf(online, status == 1, status == 2) end
    end
end

function UI:GetChatPresence(convo, key)
    if not convo then return nil end
    if convo.kind == "player" then
        local name = convo.targetName or convo.label
        if not name then return nil end
        if C_FriendList and C_FriendList.GetFriendInfo then
            local ok, info = xpcall(C_FriendList.GetFriendInfo, Utils.ErrorHandler, name)
            if not (ok and info) then
                ok, info = xpcall(C_FriendList.GetFriendInfo, Utils.ErrorHandler, name:match("^[^%-]+") or name)
            end
            if ok and info then return PresenceOf(info.connected, info.afk, info.dnd) end
        end
        return guildPresence[FirstName(name) or ""]
    elseif convo.kind == "bn" then
        local info = self:GetChatBNFriendInfo(convo, key)
        if not info then return nil end
        local game = info.gameAccountInfo
        return PresenceOf(info.isOnline or (game and game.isOnline), info.isAFK or (game and game.isGameAFK),
            info.isDND or (game and game.isGameBusy))
    end
    return nil
end

-- A Battle.net chat's friend as the account lists them now: by BattleTag,
-- else (a chat with none) by the ID this session gave it.
function UI:GetChatBNFriendInfo(convo, key)
    local info = self:GetChatBNFriendByTag(convo.battleTag)
    if info then return info end
    local id = self:GetChatBNAccountID(convo, key)
    if not (id and C_BattleNet and C_BattleNet.GetAccountInfoByID) then return nil end
    local ok, byID = xpcall(C_BattleNet.GetAccountInfoByID, Utils.ErrorHandler, id)
    return ok and byID or nil
end

function UI:UpdateChatHeaderPresence(view, convo, key, plainText)
    local state = convo and view.headerName:IsShown() and self:GetChatPresence(convo, key) or nil
    local color = state and PRESENCE_COLOR[state]
    view._presenceKey, view._presenceText = key, plainText
    view.headerPresenceRim:SetShown(color ~= nil)
    view.headerPresence:SetShown(color ~= nil)
    if not color then return end
    local d = mmax(7, math.floor(self:GetChatFontLineHeight(view.headerName, 14) * 0.6 + 0.5))
    view.headerPresence:SetSize(d, d)
    view.headerPresenceRim:SetSize(d + 2, d + 2)
    -- After the name as drawn, inside the name's room when it is clipped.
    local room = view.headerName:GetWidth() or 0
    local textW = mmin(self:GetChatMeasuredTextWidth(view.headerName, plainText), mmax(0, room - d - 8))
    view.headerPresenceRim:ClearAllPoints()
    view.headerPresenceRim:SetPoint("LEFT", view.headerName, "LEFT", textW + 6, 0)
    view.headerPresence:SetVertexColor(color[1], color[2], color[3], 1)
    view.headerPresenceRim:SetVertexColor(PRESENCE_RIM[1], PRESENCE_RIM[2], PRESENCE_RIM[3], 0.9)
end

-- A sidebar row's disc: the icon's upper right corner collapsed (an unread
-- badge there takes the corner), after the name otherwise.
function UI:PlaceChatRowPresence(row, convo, key)
    local state = convo and self:GetChatPresence(convo, key)
    local color = state and PRESENCE_COLOR[state]
    local collapsed = row.collapsedLayout
    if collapsed and (row.unreadCount or 0) > 0 then color = nil end
    row.presenceFrame:SetShown(color ~= nil)
    if not color then return end
    local d = collapsed and 9 or mmax(6, math.floor(self:GetChatFontLineHeight(row.name, 12) * 0.55 + 0.5))
    row.presence:SetSize(d, d)
    row.presenceRim:SetSize(d + 2, d + 2)
    row.presenceFrame:SetSize(d + 2, d + 2)
    row.presenceFrame:ClearAllPoints()
    if collapsed then
        row.presenceFrame:SetPoint("CENTER", row.initialBg, "TOPRIGHT", -2, -2)
    else
        local room = row.name:GetWidth() or 0
        local textW = mmin(self:GetChatMeasuredTextWidth(row.name, row.presenceText or ""), mmax(0, room - d - 6))
        row.presenceFrame:SetPoint("LEFT", row.name, "LEFT", textW + 5, 0)
    end
    row.presence:SetVertexColor(color[1], color[2], color[3], 1)
    row.presenceRim:SetVertexColor(PRESENCE_RIM[1], PRESENCE_RIM[2], PRESENCE_RIM[3], 0.9)
end

-- A friend or guild member's state changed: the discs alone, the header's
-- and the rows'.
function UI:RefreshChatPresence()
    local frame = UI._chatComposer.frame
    local view = frame and frame.messengerView
    if not (view and view.headerPresence and view:IsVisible()) then return end
    local store = self:GetChatConversationStore()
    local key = view._presenceKey
    self:UpdateChatHeaderPresence(view, key and store.byKey[key], key, view._presenceText or "")
    for i = 1, #(view.conversationRows or {}) do
        local row = view.conversationRows[i]
        local rowKey = row:IsShown() and row.conversationKey
        local convo = rowKey and store.byKey[rowKey]
        if convo then self:PlaceChatRowPresence(row, convo, rowKey) end
    end
end

function UI:RefreshChatMessenger()
    local frame = UI._chatComposer.frame
    local view = frame and frame.messengerView
    if not view then return end
    if not view:IsVisible() then
        view._stale = true
        return
    end
    -- Re-entry guard by frame stamp: a pass that errors blocks only its frame.
    local now = GetTime()
    if UI._chatComposer.refreshingMessenger == now then return end
    UI._chatComposer.refreshingMessenger = now

    if not UI._chatComposer.keepChrome then self:LayoutChatMessengerChrome() end
    local store = self:GetChatConversationStore()
    local searchQuery = self:GetChatMessengerSearchQuery()
    local searchActive = searchQuery ~= ""
    local order, matchedMessagesByKey, previewByKey = self:BuildChatMessengerSearchResults(store, searchQuery)
    if not searchActive then order = self:PinChatOrder(self:SortChatOrder(order, store), store) end
    order = self:FilterChatOrderByCharacter(self:FilterChatOrder(order), store)
    local hiddenGroups = 0
    for _ in pairs(ChatDB().hiddenGroups or {}) do hiddenGroups = hiddenGroups + 1 end
    local filtering = hiddenGroups > 0
    if view.filterButton then view.filterButton.count:SetCount(hiddenGroups, 0.10, 0.10, 0.12) end
    local sidebarCollapsed = self:IsChatSidebarCollapsed()
    local composeInPlace = UI._chatComposer.composeInPlace == true
    local selectedKey = UI._chatComposer.selectedConversationKey
    local previousSelectedKey = selectedKey
    local views = chatNS.Views
    local keepView = views and not searchActive and views:IsView(selectedKey) and views:Selectable(selectedKey)
    if composeInPlace then
        selectedKey = nil
    elseif not keepView then
        if not order[1] then
            selectedKey = nil
        elseif (not selectedKey or not store.byKey[selectedKey] or not self:ChatOrderContainsKey(order, selectedKey)) then
            selectedKey = order[1]
        end
    end
    if selectedKey ~= previousSelectedKey then
        self:SaveCurrentChatReplyDraft()
        self:CloseChatMessageFilter(true)
    end
    UI._chatComposer.selectedConversationKey = selectedKey
    -- In view now: read.
    local inView = selectedKey and store.byKey[selectedKey]
    if inView and (inView.unread or 0) > 0 and frame:IsVisible() and not inView.markedUnread then
        self:NoteChatNewSince(selectedKey, inView)
        inView.unread = 0
        self:UpdateChatUnreadBadge()
    end
    if selectedKey ~= previousSelectedKey or view._loadedDraftKey ~= selectedKey then
        self:LoadChatDraftForKey(selectedKey)
        view._loadedDraftKey = selectedKey
    end

    local entries, channels = self:BuildChatSidebarEntries(order, store, searchActive)
    -- The game's chats (All, the channels, System, the combat log) as one
    -- group at the list's foot, apart from the chats that scroll; a search
    -- lists chats alone.
    local gameEntry = views and not searchActive and views:BottomEntry(channels) or nil
    local gameRow = view.gameRow
    if gameRow then
        if gameEntry then
            gameRow.folderID, gameRow.isView = gameEntry.folder, nil
            gameRow.chevron:Hide()
            self:FillChatFolderRow(gameRow, gameEntry.folder, gameEntry, store, sidebarCollapsed, selectedKey)
            gameRow:Show()
        else
            gameRow.folderMembers = nil
            gameRow:Hide()
        end
        view.gameRule:SetShown(gameEntry ~= nil)
    end
    -- A new search starts at the top; a newly selected chat (or its folder)
    -- scrolls into view.
    local fit = view.conversationFit or #view.conversationRows
    local whole = view.conversationWhole or fit
    if view._sidebarQuery ~= searchQuery then
        view._sidebarQuery = searchQuery
        view.conversationOffset = 0
    end
    local offset = view.conversationOffset or 0
    if selectedKey ~= previousSelectedKey and selectedKey then
        for i = 1, #entries do
            local members = entries[i].members
            if entries[i].key == selectedKey or (members and self:ChatOrderContainsKey(members, selectedKey)) then
                if i <= offset then offset = i - 1 elseif i > offset + whole then offset = i - whole end
                break
            end
        end
    end
    offset = mmax(0, mmin(offset, #entries - whole))
    view.conversationOffset = offset
    for i = 1, #view.conversationRows do
        local row = view.conversationRows[i]
        local entry = i <= fit and entries[offset + i] or nil
        local key = entry and entry.key
        local isView = views ~= nil and views:IsView(key)
        local convo = key and (store.byKey[key] or (isView and views:Get(key))) or nil
        row.folderID = entry and entry.folder or nil
        row.isView = isView or nil
        row.chevron:Hide()
        if row.folderID then
            self:FillChatFolderRow(row, row.folderID, entry, store, sidebarCollapsed, selectedKey)
            row:Show()
        elseif convo then
            self:FillChatConversationRow(row, key, convo, previewByKey and previewByKey[key], key == selectedKey,
                sidebarCollapsed)
            row:Show()
        else
            row.conversationKey = nil
            row.deleteButton:Hide()
            row:Hide()
        end
    end
    self:FillChatFolderFlyout(view)

    local selected = (not composeInPlace) and selectedKey
        and (store.byKey[selectedKey] or (views and views:Get(selectedKey))) or nil
    local selectedLabel = selected and self:GetChatConversationDisplayLabel(selected, selectedKey) or nil
    if view.headerRecipientShell then
        view.headerRecipientShell:SetShown(composeInPlace)
    end
    -- The header's place follows the conversation now chosen.
    if self:IsChatHeaderInTitle() ~= (view._headerInTitle == true) then self:LayoutChatMessengerChrome() end
    local inTitle = view._headerInTitle == true
    local headerFolded = ChatDB().headerFolded == true and not composeInPlace and not inTitle
    local headerOneLine = ChatDB().headerOneLine == true or inTitle
    view.headerName:SetShown(not composeInPlace and not headerFolded)
    view.headerSubtext:SetShown(not composeInPlace and not headerFolded and not headerOneLine)
    if composeInPlace then
        view.empty:SetText("New message")
        view.empty:Show()
    else
        view.empty:SetText(searchActive and "No matching messages"
            or (filtering and "No chats pass the filter") or "No conversations yet")
        view.empty:SetShown(selected == nil)
    end
    -- Renamed: the type line still says whose chat it is.
    local headerType = selected and (selected.source or "") or ""
    if selected and selected.customLabel then
        local own = selected.kind == "player" and self:GetChatPlayerShortName(selected.targetName or selected.label or "")
            or self:GetPlainChatLabel(selected.label or "")
        if own ~= "" then headerType = headerType ~= "" and (headerType .. " with " .. own) or own end
    end
    local headerText = selected and self:WrapChatClassName(selectedLabel or "No Conversation",
        selected.kind == "player" and not selected.customLabel and selected.class) or "No Conversation"
    if headerOneLine and headerType ~= "" then headerText = headerText .. "|cff9a9a9a: " .. headerType .. "|r" end
    self:LayoutChatMessageFilter(view, selected ~= nil and not composeInPlace)
    if chatNS.Pins then chatNS.Pins:Sync(not composeInPlace and selectedKey or nil) end
    SetClippedText(view.headerName, headerText)
    view.headerSubtext:SetText(headerType)
    local foldedTitle = frame.foldedTitle
    if foldedTitle then
        local named = selected ~= nil and self:IsChatConversationInFoldedTitle()
        foldedTitle:SetShown(named)
        if named then
            local stripText = headerText
            if not headerOneLine and headerType ~= "" then stripText = stripText .. "|cff9a9a9a: " .. headerType .. "|r" end
            SetClippedText(foldedTitle, stripText)
        end
    end
    self:UpdateChatHeaderPresence(view, selected, selectedKey, self:GetPlainChatLabel(headerText))
    local nameHit = view.headerNameTarget
    local person = selected ~= nil and selected.kind == "player" and not composeInPlace and not headerFolded
    nameHit._efCopyText = person and self:GetPlainChatLabel(selected.targetName or selected.label or "") or nil
    if person then
        local labelW = self:GetChatMeasuredTextWidth(view.headerName, self:GetPlainChatLabel(selectedLabel or ""))
        nameHit:SetSize(mmax(1, mmin(labelW, view.headerName:GetWidth() or labelW)),
            self:GetChatFontLineHeight(view.headerName, 14))
    end
    nameHit:SetShown(person)
    if selected then
        view.headerInitial:SetText(self:GetChatConversationInitial(selected, selectedKey, selectedLabel))
        local r, g, b = self:GetChatRecipientColor(selectedKey)
        ns.SetRoundedRectFill(view.headerInitialBg, r, g, b, 1, true)
        PaintAvatar(view.headerInitialBg, view.headerInitial, selected)
    end
    view.headerInitialBg.conversationKey = selected and selectedKey or nil
    view.headerInitialBg:SetShown(selected ~= nil and not composeInPlace and not headerFolded)
    view._chatCanType = composeInPlace or (selected ~= nil and not (views and not views:CanType(selectedKey)))
    self:SyncChatReplyLine(view)

    local matched = matchedMessagesByKey and matchedMessagesByKey[selectedKey]
    local messages = (not composeInPlace) and selected and (matched or selected.messages) or nil
    messages = self:FilterChatMessagesByCharacter(selected, messages)
    local filter = messages and self:GetChatMessageFilter() or ""
    if filter ~= "" then messages = self:FilterChatMessages(messages, filter) end
    -- A narrowed list offers Jump on its bubbles.
    view._chatJumpable = messages ~= nil and (matched ~= nil or filter ~= "")
    local notes = not view._chatJumpable and UI._chatComposer.notes
    self:RenderChatMessages(view, messages, selectedKey, notes and notes[selectedKey] or nil)
    if views then views:SyncCombatLog() end
    UI._chatComposer.refreshingMessenger = nil
end

function UI:ShowChatMessengerView()
    local frame = self:EnsureChatComposerFrame()
    frame.chatMode = "messenger"
    if frame.composeElements then
        for i = 1, #frame.composeElements do frame.composeElements[i]:Hide() end
    end
    if frame.channelMenu then frame.channelMenu:Hide() end
    if frame.suggestionMenu then frame.suggestionMenu:Hide() end
    if frame.messengerView then frame.messengerView:Show() end
    local view = frame.messengerView
    if view and view.title then
        view.title:ClearAllPoints()
        view.title:SetPoint("LEFT", view.settingsButton, "RIGHT", 7, 0)
    end
    self:ApplyChatTitleFold(frame)
    self:RefreshChatMessenger()
end

-- The title bar folded (its arrow) is a thin strip keeping the X and the
-- arrow; the chat below takes the room, the window keeping its size. The
-- new-message form keeps the full bar.
function UI:ApplyChatTitleFold(frame)
    local folded = ChatDB().titleFolded == true and frame.chatMode ~= "compose"
    local top = folded and CHAT_TITLE_FOLDED_H or CHAT_WINDOW_HEADER_H
    local view = frame.messengerView
    if view then
        view:ClearAllPoints()
        view:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -(top + 2))
        view:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
        if view.title then view.title:SetShown(not folded) end
        if view.titleExp then view.titleExp:SetShown(not folded) end
        if view.settingsButton then view.settingsButton:SetShown(not folded) end
    end
    frame.headerLine:ClearAllPoints()
    frame.headerLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -top)
    frame.headerLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -top)
    frame.lockButton:SetShown(not folded)
    frame.closeButton:ClearAllPoints()
    -- Folded, the X and cog sit 4 px clear of the ring line, not on it.
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, folded and -2 or -10)
    local cog = frame.foldedSettingsButton
    if cog then
        cog:ClearAllPoints()
        cog:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -3)
        cog:SetShown(folded)
    end
    local fold = frame.titleFold
    fold:ClearAllPoints()
    if folded then
        fold:SetPoint("RIGHT", frame.closeButton, "LEFT", -4, 0)
    else
        fold:SetPoint("RIGHT", frame.lockButton, "LEFT", -6, 0)
    end
    fold.glyph:SetRotation(folded and 0 or math.pi)
    local clock = frame.titleClock
    clock:ClearAllPoints()
    clock:SetPoint("RIGHT", fold, "LEFT", folded and -6 or -8, 0)
    local foldedTitle = frame.foldedTitle
    foldedTitle:ClearAllPoints()
    foldedTitle:SetPoint("LEFT", cog, "RIGHT", 6, 0)
    foldedTitle:SetPoint("RIGHT", self:GetChatTitleRightEdge(frame), "LEFT", -8, 0)
    if not folded then foldedTitle:Hide() end
    self:LayoutChatClock(frame)
end

-- The title bar's names, cut again to the width a resize leaves them.
function UI:ReclipChatTitleText(frame)
    local view = frame.messengerView
    if view and view._headerInTitle and view.headerName:IsShown() then
        SetClippedText(view.headerName, view.headerName._efSourceText)
    end
    local strip = frame.foldedTitle
    if strip and strip:IsShown() then SetClippedText(strip, strip._efSourceText) end
end

-- The clock: the time each minute while the window shows, sized for the
-- widest time so a new minute never moves the name beside it. It steps
-- aside where the window is too narrow for it and the brand.
function UI:LayoutChatClock(frame)
    local clock = frame.titleClock
    if frame.clockTimer then
        frame.clockTimer:Cancel()
        frame.clockTimer = nil
    end
    if ChatDB().showClock == false or not frame:IsShown() then
        clock:Hide()
        return
    end
    local widest = 0
    for _, half in ipairs({ _G["TIMEMANAGER_AM"] or "AM", _G["TIMEMANAGER_PM"] or "PM" }) do
        clock:SetText(GetCVarBool and GetCVarBool("timeMgrUseMilitaryTime") and "00:00" or ("00:00 " .. half))
        widest = mmax(widest, clock:GetStringWidth())
    end
    clock:SetWidth(widest + 1)
    local now = time()
    clock:SetText(self:FormatChatBubbleTime(now))
    local view = frame.messengerView
    local brand = view and view.titleExp and view.titleExp:IsShown() and view.titleExp
        or (view and view.title and view.title:IsShown() and view.title) or nil
    local right, brandRight = clock:GetRight(), brand and brand:GetRight()
    clock:SetShown(not (right and brandRight and right - clock:GetWidth() < brandRight + 8))
    frame.clockTimer = C_Timer.NewTimer(60 - now % 60, function() UI:LayoutChatClock(frame) end)
end

function UI:ShowChatComposeView(reset)
    local frame = self:EnsureChatComposerFrame()
    frame.chatMode = "compose"
    self:ApplyChatTitleFold(frame)
    if frame.messengerView then frame.messengerView:Hide() end
    if frame.composeElements then
        for i = 1, #frame.composeElements do frame.composeElements[i]:Show() end
    end
    -- The brand clears the back button that sits in its corner here.
    local title = frame.messengerView and frame.messengerView.title
    if title and frame.composeBackButton then
        title:ClearAllPoints()
        title:SetPoint("LEFT", frame.composeBackButton, "RIGHT", 6, 0)
    end
    if reset then
        UI._chatComposer.pendingForward = nil
        UI._chatComposer.pendingReply = nil
        self:ClearChatRecipients()
        if frame.messageEditBox then frame.messageEditBox:SetText("") end
        if frame.targetEditBox then frame.targetEditBox:SetText("") end
        self:SetChatComposerStatus("")
    end
    self:RefreshChatComposerChannel()
    self:RefreshChatComposerRecipients()
    -- A frame late: the key that opened the window must not type into it.
    local def = self:GetChatChannelDef()
    local box = (def.needsRecipients and frame.targetEditBox) or frame.messageEditBox
    if box then
        Utils.SafeAfter(0, function()
            if frame:IsShown() and frame.chatMode == "compose" then box:SetFocus() end
        end)
    end
end

-- One sidebar row: the builder makes eight, the layout more when a taller
-- sidebar holds them.
function UI:CreateChatConversationRow(view)
    local clip = view.listClip
    local i = #view.conversationRows + 1
    local row = self:CreateChatListRow(clip)
    view.conversationRows[i] = row
    row:SetPoint("TOPLEFT", clip, "TOPLEFT", 6, -(i - 1) * 34)
    row:SetPoint("RIGHT", clip, "RIGHT", -6, 0)
    return row
end

-- A chat's row, in the list or a folder's flyout.
function UI:CreateChatListRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(32)
    ns.CreateRoundedRectBorder(row)
    ns.SetRoundedRectBarHeight(row, 8)
    ns.SetRoundedRectBorderBgAlpha(row, 1)
    -- Borderless fill, matching the options panel buttons; selection
    -- reads through the accent fill alone.
    self:SetChatSubtleOutline(row, false)
    PaintChatSurface(row, "row", 1)
    row.initialBg = CreateFrame("Frame", nil, row)
    row.initialBg:SetSize(24, 24)
    row.initialBg:SetPoint("LEFT", row, "LEFT", 7, 0)
    ns.CreateRoundedRectBorder(row.initialBg)
    ns.SetRoundedRectBarHeight(row.initialBg, 24)
    ns.SetRoundedRectBorderBgAlpha(row.initialBg, 1)
    ns.SetRoundedRectBorderEdgeShown(row.initialBg, false)
    row.initial = row.initialBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    RegisterChatThemedText(row.initial)
    row.initial:SetPoint("CENTER", row.initialBg, "CENTER")
    if row.initial.SetDrawLayer then row.initial:SetDrawLayer("OVERLAY", 7) end
    row.time = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.time:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -3)
    row.time:SetWidth(48)
    row.time:SetJustifyH("RIGHT")
    row.time:SetWordWrap(false)
    -- A folder row's arrow: its chats open to the right.
    row.chevron = row:CreateTexture(nil, "OVERLAY")
    row.chevron:SetTexture(ns.FILTER_ARROW_TEX)
    row.chevron:SetSize(11, 11)
    row.chevron:SetPoint("TOPRIGHT", row, "TOPRIGHT", -7, -5)
    RegisterChatThemedText(row.chevron, 0.8)
    row.chevron:Hide()
    -- Pinned: a pushpin just left of the time.
    row.pin = row:CreateTexture(nil, "OVERLAY")
    row.pin:SetTexture(CHAT_PIN_TEX)
    row.pin:SetSize(11, 11)
    RegisterChatThemedText(row.pin, 0.7)
    row.pin:Hide()
    -- Muted: a bell struck through, left of the pin or the time.
    row.muted = row:CreateTexture(nil, "OVERLAY")
    row.muted:SetTexture(CHAT_MUTED_TEX)
    row.muted:SetSize(11, 11)
    RegisterChatThemedText(row.muted, 0.7)
    row.muted:Hide()
    if row.time.SetNonSpaceWrap then row.time:SetNonSpaceWrap(false) end
    if row.time.SetMaxLines then row.time:SetMaxLines(1) end
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.name:SetPoint("TOPLEFT", row.initialBg, "TOPRIGHT", 7, -1)
    row.name:SetPoint("RIGHT", row.time, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    if row.name.SetMaxLines then row.name:SetMaxLines(1) end
    row.preview = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.preview:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -1)
    row.preview:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.preview:SetJustifyH("LEFT")
    row.preview:SetWordWrap(false)
    -- Unread: a count pill under the time, as chat apps mark a thread.
    row.unread = ns.CreateCountBadge(row, 16)
    row.unread:SetFrameLevel(row:GetFrameLevel() + 4)
    row.unread:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 4)
    -- The other side's presence: the icon's upper right corner collapsed,
    -- after the name otherwise (UI:PlaceChatRowPresence).
    row.presenceFrame = CreateFrame("Frame", nil, row)
    row.presenceFrame:SetFrameLevel(row:GetFrameLevel() + 5)
    row.presenceFrame:Hide()
    row.presenceRim = row.presenceFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    row.presenceRim:SetTexture(PRESENCE_DISC)
    row.presenceRim:SetPoint("CENTER")
    row.presence = row.presenceFrame:CreateTexture(nil, "OVERLAY", nil, 2)
    row.presence:SetTexture(PRESENCE_DISC)
    row.presence:SetPoint("CENTER")
    -- The trash glyph the notes window wears, at its size.
    row.deleteButton = CreateFrame("Button", nil, row)
    row.deleteButton:SetSize(22, 22)
    row.deleteButton:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 1)
    row.deleteButton:SetFrameLevel(row:GetFrameLevel() + 6)
    row.deleteButton.icon = row.deleteButton:CreateTexture(nil, "OVERLAY")
    row.deleteButton.icon:SetSize(14, 14)
    row.deleteButton.icon:SetPoint("CENTER")
    row.deleteButton.icon:SetTexture("Interface\\AddOns\\EasyFind_Notes\\Images\\trash")
    row.deleteButton.icon:SetDesaturated(true)
    row.deleteButton.icon:SetVertexColor(Utils.RGB(CHAT_DELETE_ICON_COLOR, 0.90))
    row.deleteButton:Hide()
    row:SetScript("OnEnter", function(self)
        self.hovering = true
        UI:RepaintChatListRow(self)
        if self.folderID then UI:HoverChatFolderRow(self) end
        if UI:IsChatSidebarCollapsed() and not self.inFlyout then
            -- No name tip over an open folder's chats: they open where it shows.
            if self.tipLabel and not UI:GetOpenChatFolder() then ShowChatTipDelayed(self, "ANCHOR_RIGHT", self.tipLabel) end
        elseif self.conversationKey and not self.isView then
            self.deleteButton:Show()
            self.unread:Hide()
        end
    end)
    row:SetScript("OnLeave", function(self)
        HideChatTip(self)
        self.hovering = false
        UI:RepaintChatListRow(self)
        if not self.deleteButton:IsMouseOver() then
            self.deleteButton:Hide()
            self.unread:SetCount(self.unreadCount, self.unreadR, self.unreadG, self.unreadB)
        end
    end)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if self.folderID then
            if button == "RightButton" then UI:ShowChatFolderMenu(self.folderID) else UI:ToggleChatFolderFlyout(self) end
            return
        end
        local menu = button == "RightButton"
        -- A chat picked in a folder's flyout shuts it.
        if not menu then UI:CloseChatFolderFlyout() end
        if self.isView then
            local views = chatNS.Views
            if menu then return views:ShowMenu(self.conversationKey) end
            local back = views.cameFrom
            if self.conversationKey == views.COMBAT and UI._chatComposer.selectedConversationKey == views.COMBAT
                and back and (UI:GetChatConversationStore().byKey[back] or views:Selectable(back)) then
                UI:SelectChatConversation(back)
            else
                UI:SelectChatConversation(self.conversationKey)
            end
            return
        end
        if menu then
            if chatNS.Avatars and (self.inFlyout or not UI:IsChatSidebarCollapsed()) and self.initialBg:IsMouseOver() then
                chatNS.Avatars:OpenPicker(self.conversationKey, self.initialBg)
            else
                UI:ShowChatConversationMenu(self.conversationKey)
            end
            return
        end
        UI:SelectChatConversation(self.conversationKey)
        -- Picked from the collapsed sidebar's search: the search is done.
        if UI:IsChatSidebarCollapsed() and UI:GetChatMessengerSearchQuery() ~= "" then
            UI:SetChatSidebarSearchOpen(false, true)
        end
    end)
    row.deleteButton:SetScript("OnEnter", function(self)
        row.hovering = true
        UI:RepaintChatListRow(row)
        self.icon:SetVertexColor(Utils.RGB(CHAT_DELETE_HOVER_COLOR, 1))
        self:Show()
        ShowChatTipDelayed(self, "ANCHOR_TOP", "Delete Chat")
    end)
    row.deleteButton:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(Utils.RGB(CHAT_DELETE_ICON_COLOR, 0.90))
        HideChatTip(self)
        if not row:IsMouseOver() then
            row.hovering = false
            UI:RepaintChatListRow(row)
            self:Hide()
        end
    end)
    row.deleteButton:SetScript("OnClick", function()
        UI:DeleteChatConversation(row.conversationKey)
    end)
    row:Hide()
    self:RegisterChatFrameFonts(row)
    ns.ShadeText(row)
    return row
end

function UI:CreateChatMessengerView(frame)
    if frame.messengerView then return frame.messengerView end

    local view = CreateFrame("Frame", nil, frame)
    frame.messengerView = view
    view:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -(CHAT_WINDOW_HEADER_H + 2))
    view:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    view:Hide()
    -- Redraws asked for while hidden wait for the next show (comp-chat-1).
    view:HookScript("OnShow", function(self)
        if self._stale then
            self._stale = nil
            UI:RefreshChatMessenger()
        end
    end)

    local sidebar = CreateFrame("Frame", nil, view)
    view.sidebar = sidebar
    sidebar:SetPoint("TOPLEFT")
    sidebar:SetPoint("BOTTOMLEFT")
    sidebar:SetWidth(self:GetChatSidebarWidth())
    ns.CreateRoundedRectBorder(sidebar)
    ns.SetRoundedRectBarHeight(sidebar, 10)
    ns.SetRoundedRectBorderBgAlpha(sidebar, 1)
    ns.SetRoundedRectBorderEdgeShown(sidebar, false)
    PaintChatSurface(sidebar, "sidebar", 1)
    -- Counted as the layout counts: rows past a new bottom hide at once (a
    -- fast resize outruns the redraw); a new count lays the list out again,
    -- so a sidebar grown since (the window's saved size) fills its room.
    sidebar:SetScript("OnSizeChanged", function(_, _, height)
        local f = view._sidebarFit
        local rows = view.conversationRows
        if not (f and rows and height) then return end
        local fit = mmax(1, math.floor((height - f.top - f.pad + f.gap) / f.step)) + 1
        for i = fit + 1, #rows do rows[i]:Hide() end
        if fit ~= view.conversationFit then UI:QueueChatMessengerRefresh() end
    end)

    local resizeHandle = CreateFrame("Button", nil, sidebar)
    view.sidebarResizeHandle = resizeHandle
    resizeHandle:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 5, -2)
    resizeHandle:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 5, 2)
    resizeHandle:SetWidth(10)
    resizeHandle:SetFrameLevel(sidebar:GetFrameLevel() + 20)
    resizeHandle:EnableMouse(true)
    resizeHandle.line = resizeHandle:CreateTexture(nil, "OVERLAY")
    resizeHandle.line:SetTexture("Interface\\Buttons\\WHITE8x8")
    resizeHandle.line:SetPoint("TOP", resizeHandle, "TOP", 0, -6)
    resizeHandle.line:SetPoint("BOTTOM", resizeHandle, "BOTTOM", 0, 6)
    resizeHandle.line:SetWidth(1)
    resizeHandle.line:SetVertexColor(ChatAccentGlyphColor())
    resizeHandle.line:Hide()
    resizeHandle:SetScript("OnEnter", function(self)
        self.line:Show()
        UI:ShowChatSidebarResizeCursor()
        Utils.SafeOnUpdate(self, ChatSidebarResizeOnUpdate)
    end)
    resizeHandle:SetScript("OnLeave", function(self)
        if UI._chatComposer.sidebarResizing then return end
        self.line:Hide()
        UI:HideChatSidebarResizeCursor()
        Utils.SafeOnUpdate(self, nil)
    end)
    resizeHandle:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        self.line:Show()
        UI:StartChatSidebarResize(self)
    end)
    resizeHandle:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" then return end
        UI:StopChatSidebarResize(self)
    end)

    -- Brand label lives in the WINDOW banner (true top-left, above the
    -- header line), not inside the sidebar. Brand name stays literal in
    -- every locale.
    local ownerFrame = view:GetParent()
    local title = ownerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    view.title = title
    title:SetPoint("TOPLEFT", ownerFrame, "TOPLEFT", 18, -12)
    title:SetText("EasyChat")
    RegisterChatThemedText(title)
    -- Experimental: the EXP badge rides the brand's corner.
    view.titleExp = ns.CreateFeatureTag(ownerFrame, "exp", ns.L["TAG_EXP_TITLE"], ns.L["CHAT_EXP_TT"], true)
    ns.SuperscriptTag(view.titleExp, title)

    local compose = CreateFrame("Button", nil, sidebar)
    view.composeButton = compose
    compose:SetSize(22, 22)
    compose:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -10, -9)
    self:StyleCalculatorButton(compose, 22)
    -- Two bars, not a "+" character: a glyph sits off center in its box.
    for k = 1, 2 do
        local bar = compose:CreateTexture(nil, "OVERLAY")
        bar:SetColorTexture(1, 1, 1, 1)
        bar:SetPoint("CENTER")
        if k == 1 then bar:SetSize(10, 2) else bar:SetSize(2, 10) end
        RegisterChatThemedText(bar)
    end
    compose:SetScript("OnClick", function() UI:BeginChatComposeInPlace() end)

    -- The settings cog opens the window's top left, the title after it.
    -- On the view, so the new-message view's back button has the corner.
    local settings = CreateFrame("Button", nil, view)
    view.settingsButton = settings
    settings:SetSize(22, 22)
    settings:SetPoint("TOPLEFT", ownerFrame, "TOPLEFT", 12, -10)
    title:ClearAllPoints()
    title:SetPoint("LEFT", settings, "RIGHT", 7, 0)
    self:StyleCalculatorButton(settings, 22)
    settings.glyph = settings:CreateTexture(nil, "OVERLAY")
    -- A new file shows only after a client restart: the game's gear till then.
    if not (ns.COG_ICON_TEX and settings.glyph:SetTexture(ns.COG_ICON_TEX)) then
        settings.glyph:SetAtlas("QuestLog-icon-setting", false)
        settings.glyph:SetDesaturated(true)
    end
    settings.glyph:SetSize(14, 14)
    settings.glyph:SetPoint("CENTER")
    RegisterChatThemedText(settings.glyph)
    AddCogGlow(settings, 14)
    settings:SetScript("OnClick", function() UI:OpenChatSettings() end)

    -- A funnel: the search bar's triangle over a drawn stem.
    local filter = CreateFrame("Button", nil, sidebar)
    view.filterButton = filter
    filter:SetSize(22, 22)
    filter:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 10, -9)
    self:StyleCalculatorButton(filter, 22)
    local cone = filter:CreateTexture(nil, "OVERLAY")
    cone:SetTexture(ns.FILTER_ARROW_TEX)
    cone:SetSize(15, 15)
    cone:SetPoint("CENTER", 0, 2)
    local stem = filter:CreateTexture(nil, "OVERLAY")
    stem:SetColorTexture(1, 1, 1, 1)
    stem:SetSize(3, 5)
    stem:SetPoint("TOP", cone, "CENTER", 0, -2)
    RegisterChatThemedText(cone)
    RegisterChatThemedText(stem)
    -- How many groups it hides, dark so it reads on the gold button.
    filter.count = ns.CreateCountBadge(filter, 12)
    filter.count:SetFrameLevel(filter:GetFrameLevel() + 4)
    filter.count:SetPoint("CENTER", filter, "TOPRIGHT", -2, -2)
    filter:SetScript("OnClick", function(self) UI:ShowChatFilterMenu(self) end)
    filter:HookScript("OnEnter", function(self) ShowChatTipDelayed(self, "ANCHOR_TOP", "Filter chats") end)
    filter:HookScript("OnLeave", function(self) HideChatTip(self) end)

    local sortButton = CreateFrame("Button", nil, sidebar)
    view.sortButton = sortButton
    sortButton:SetSize(22, 22)
    sortButton:SetPoint("LEFT", filter, "RIGHT", 6, 0)
    self:StyleCalculatorButton(sortButton, 22)
    sortButton.glyph = sortButton:CreateTexture(nil, "OVERLAY")
    sortButton.glyph:SetTexture(ns.SORT_ICON_TEX)
    sortButton.glyph:SetSize(13, 13)
    sortButton.glyph:SetPoint("CENTER")
    RegisterChatThemedText(sortButton.glyph)
    sortButton:SetScript("OnClick", function(self) UI:ShowChatSortMenu(self) end)
    sortButton:HookScript("OnEnter", function(self) ShowChatTipDelayed(self, "ANCHOR_TOP", "Sort chats") end)
    sortButton:HookScript("OnLeave", function(self) HideChatTip(self) end)

    local collapse = CreateFrame("Button", nil, sidebar)
    view.sidebarCollapseButton = collapse
    collapse:SetSize(22, 22)
    collapse:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -10, -9)
    self:StyleCalculatorButton(collapse, 22)
    collapse.arrow = collapse:CreateTexture(nil, "OVERLAY")
    collapse.arrow:SetTexture(ns.FILTER_ARROW_TEX)
    collapse.arrow:SetSize(9, 9)
    collapse.arrow:SetPoint("CENTER")
    collapse.arrow:SetRotation(-math.pi / 2)
    collapse.arrow:SetVertexColor(0.9, 0.9, 0.92, 1)
    collapse:SetScript("OnClick", function() UI:ToggleChatSidebarCollapsed() end)

    -- Collapsed, a lens under the arrow opens the search beside the icons.
    local lens = CreateFrame("Button", nil, sidebar)
    view.sidebarSearchButton = lens
    lens:SetSize(22, 22)
    self:StyleCalculatorButton(lens, 22)
    lens.glyph = lens:CreateTexture(nil, "OVERLAY")
    lens.glyph:SetTexture(ns.SEARCH_ICON_TEX)
    lens.glyph:SetSize(12, 12)
    lens.glyph:SetPoint("CENTER")
    lens:SetScript("OnClick", function() UI:ToggleChatSidebarSearch() end)
    lens:SetScript("OnEnter", function(self) ShowChatTipDelayed(self, "ANCHOR_RIGHT", "Search chats") end)
    lens:SetScript("OnLeave", function(self) HideChatTip(self) end)
    lens:Hide()

    -- Whose chats show: this character's, another's, or all.
    local charPick = CreateFrame("Button", nil, sidebar)
    view.charPickButton = charPick
    charPick:SetHeight(20)
    local pickWell = self:StyleChatInputWell(charPick, 7)
    charPick.text = pickWell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    charPick.text:SetPoint("LEFT", charPick, "LEFT", 9, 0)
    charPick.text:SetPoint("RIGHT", charPick, "RIGHT", -20, 0)
    charPick.text:SetJustifyH("LEFT")
    charPick.text:SetWordWrap(false)
    RegisterChatThemedText(charPick.text, 0.85)
    charPick.arrow = pickWell:CreateTexture(nil, "OVERLAY")
    charPick.arrow:SetTexture(ns.FILTER_ARROW_TEX)
    charPick.arrow:SetSize(9, 9)
    charPick.arrow:SetPoint("RIGHT", charPick, "RIGHT", -7, 0)
    RegisterChatThemedText(charPick.arrow, 0.75)
    charPick:SetScript("OnClick", function(self) UI:ShowChatCharacterMenu(self) end)
    charPick:SetScript("OnEnter", function(self) ShowChatTipDelayed(self, "ANCHOR_TOP", "Whose chats show") end)
    charPick:SetScript("OnLeave", function(self) HideChatTip(self) end)
    charPick:Hide()

    local searchShell = CreateFrame("Frame", nil, sidebar)
    view.searchShell = searchShell
    searchShell:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 8, -34)
    searchShell:SetPoint("RIGHT", sidebar, "RIGHT", -8, 0)
    searchShell:SetHeight(22)
    local searchWell = self:StyleChatInputWell(searchShell, 7)
    searchShell:EnableMouse(true)
    searchShell:SetScript("OnMouseDown", function()
        UI:FocusChatEditBox(view.searchEditBox)
    end)

    view.searchPlaceholder = searchWell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    view.searchPlaceholder:SetPoint("LEFT", searchShell, "LEFT", 9, 0)
    view.searchPlaceholder:SetText("Search")
    RegisterChatThemedText(view.searchPlaceholder, 0.5)

    local searchClear = CreateFrame("Button", nil, searchWell)
    view.searchClearButton = searchClear
    searchClear:SetSize(16, 16)
    searchClear:SetPoint("RIGHT", searchShell, "RIGHT", -5, 0)
    local function makeSearchClearStroke()
        local tex = searchClear:CreateTexture(nil, "OVERLAY")
        tex:SetTexture("Interface\\Buttons\\WHITE8x8")
        tex:SetSize(10, 1.25)
        tex:SetPoint("CENTER")
        return tex
    end
    local clearStroke1 = makeSearchClearStroke(); clearStroke1:SetRotation(math.pi / 4)
    local clearStroke2 = makeSearchClearStroke(); clearStroke2:SetRotation(-math.pi / 4)
    local function setSearchClearColor(r, g, b)
        clearStroke1:SetVertexColor(r, g, b, 1)
        clearStroke2:SetVertexColor(r, g, b, 1)
    end
    setSearchClearColor(0.58, 0.58, 0.60)
    searchClear:SetScript("OnEnter", function() setSearchClearColor(ChatAccentGlyphColor()) end)
    searchClear:SetScript("OnLeave", function() setSearchClearColor(0.58, 0.58, 0.60) end)
    searchClear:SetScript("OnClick", function()
        view.searchEditBox:SetText("")
        UI:FocusChatEditBox(view.searchEditBox)
        UI:RefreshChatMessenger()
    end)
    searchClear:Hide()

    view.searchEditBox = CreateFrame("EditBox", nil, searchWell)
    view.searchEditBox:SetPoint("LEFT", searchShell, "LEFT", 9, 0)
    view.searchEditBox:SetPoint("RIGHT", searchClear, "LEFT", -4, 0)
    view.searchEditBox:SetHeight(18)
    view.searchEditBox:SetAutoFocus(false)
    view.searchEditBox:SetFontObject(GameFontHighlightSmall)
    view.searchEditBox._chatInput = true
    RegisterChatThemedText(view.searchEditBox)
    RegisterChatThemedText(view.searchEditBox)
    if view.searchEditBox.SetTextInsets then view.searchEditBox:SetTextInsets(0, 0, 0, 0) end
    view.searchEditBox:SetScript("OnTextChanged", function(self)
        local hasText = (self:GetText() or "") ~= ""
        view.searchPlaceholder:SetShown(not hasText)
        view.searchClearButton:SetShown(hasText)
        UI:RefreshChatMessenger()
    end)
    view.searchEditBox:SetScript("OnEditFocusGained", function()
        UI:ClearChatMessageCopyFocus()
    end)
    -- Popped out of the collapsed sidebar: Esc clears it, Enter keeps the
    -- chat it opened, and leaving it closes it with the filter kept.
    view.searchEditBox:SetScript("OnEscapePressed", function()
        if view.sidebarSearchOpen then return UI:SetChatSidebarSearchOpen(false, true) end
        UI:ClearFocusedChatEditBox()
    end)
    view.searchEditBox:SetScript("OnEnterPressed", function(self)
        if view.sidebarSearchOpen then return UI:SetChatSidebarSearchOpen(false, true) end
        self:ClearFocus()
    end)
    view.searchEditBox:SetScript("OnEditFocusLost", function()
        if view.sidebarSearchOpen then UI:SetChatSidebarSearchOpen(false) end
    end)
    Utils.ReleaseFocusOnOutsideClick(view.searchEditBox)
    view.searchEditBox:SetScript("OnKeyDown", function(self, key)
        if UI:HandleChatFontScaleKey(self, key) then return end
        if UI:HandleChatClipboardKey(self, key) then return end
        Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
    end)

    -- The chats' rows live in a clip ending above the rule: the row the
    -- room cuts shows its top, so the list reads as going on.
    local listClip = CreateFrame("Frame", nil, sidebar)
    listClip:SetClipsChildren(true)
    listClip:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, -64)
    listClip:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 0, 0)
    view.listClip = listClip
    view.conversationRows = {}
    for _ = 1, 8 do self:CreateChatConversationRow(view) end
    -- The game's chats, one group at the list's foot under a rule.
    view.gameRow = self:CreateChatListRow(sidebar)
    view.gameRow:Hide()
    local rule = sidebar:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    -- Plain on the sidebar's darker fill, where the window's 0.35 line vanished.
    rule:SetColorTexture(Utils.RGB(CHAT_SEPARATOR_COLOR, 0.7))
    rule:Hide()
    view.gameRule = rule

    local detail = CreateFrame("Frame", nil, view)
    view.detail = detail
    detail:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 8, 0)
    detail:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT")

    view.headerInitialBg = CreateFrame("Frame", nil, detail)
    view.headerInitialBg:SetSize(28, 28)
    view.headerInitialBg:SetPoint("TOPLEFT", detail, "TOPLEFT", 8, -4)
    ns.CreateRoundedRectBorder(view.headerInitialBg)
    ns.SetRoundedRectBarHeight(view.headerInitialBg, 28)
    ns.SetRoundedRectBorderBgAlpha(view.headerInitialBg, 1)
    ns.SetRoundedRectBorderEdgeShown(view.headerInitialBg, false)
    view.headerInitial = view.headerInitialBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    RegisterChatThemedText(view.headerInitial)
    view.headerInitial:SetPoint("CENTER", view.headerInitialBg, "CENTER")
    if view.headerInitial.SetDrawLayer then view.headerInitial:SetDrawLayer("OVERLAY", 7) end
    view.headerInitialBg:EnableMouse(true)
    view.headerInitialBg:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and self.conversationKey and chatNS.Avatars then
            HideChatTip(self)
            chatNS.Avatars:OpenPicker(self.conversationKey, self)
        end
    end)
    view.headerInitialBg:SetScript("OnEnter", function(self)
        if self.conversationKey then ShowChatTipDelayed(self, "ANCHOR_BOTTOM", "Right-click to change the icon") end
    end)
    view.headerInitialBg:SetScript("OnLeave", HideChatTip)
    view.headerName = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    view.headerName:SetPoint("TOPLEFT", view.headerInitialBg, "TOPRIGHT", 9, -1)
    view.headerName:SetPoint("RIGHT", detail, "RIGHT", -8, 0)
    RegisterChatThemedText(view.headerName)
    view.headerName:SetJustifyH("LEFT")
    view.headerName:SetWordWrap(false)
    -- A person's name in the header: hovered, Ctrl+C copies it. No mouse of
    -- its own, so the header's clicks stay the header's.
    view.headerNameTarget = CreateFrame("Frame", nil, detail)
    view.headerNameTarget:SetPoint("LEFT", view.headerName, "LEFT")
    view.headerNameTarget:Hide()
    if view.headerName.SetMaxLines then view.headerName:SetMaxLines(1) end
    AttachClippedTip(view.headerName, view, detail:GetFrameLevel() + 5)
    view.headerSubtext = detail:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    -- Header text size scales these, not Text size (ApplyChatFontRegion).
    view.headerInitial._efChatHeaderFont, view.headerName._efChatHeaderFont = true, true
    view.headerSubtext._efChatHeaderFont = true
    view.headerSubtext:SetPoint("TOPLEFT", view.headerName, "BOTTOMLEFT", 0, -1)
    view.headerSubtext:SetPoint("RIGHT", detail, "RIGHT", -26, 0)
    view.headerPresenceRim = detail:CreateTexture(nil, "OVERLAY", nil, 1)
    view.headerPresenceRim:SetTexture(PRESENCE_DISC)
    view.headerPresenceRim:Hide()
    view.headerPresence = detail:CreateTexture(nil, "OVERLAY", nil, 2)
    view.headerPresence:SetTexture(PRESENCE_DISC)
    view.headerPresence:SetPoint("CENTER", view.headerPresenceRim, "CENTER")
    view.headerPresence:Hide()
    -- Folds the header away for the messages, and back.
    local fold = CreateFrame("Button", nil, detail)
    view.headerFold = fold
    fold:SetSize(16, 16)
    fold:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -4, -2)
    fold:SetFrameLevel(detail:GetFrameLevel() + 6)
    fold.glyph = fold:CreateTexture(nil, "OVERLAY")
    fold.glyph:SetTexture(ns.FILTER_ARROW_TEX)
    fold.glyph:SetSize(12, 12)
    fold.glyph:SetPoint("CENTER")
    RegisterChatThemedText(fold.glyph, 0.75)
    fold:SetScript("OnClick", function()
        ChatDB().headerFolded = not ChatDB().headerFolded or nil
        UI:RefreshChatMessenger()
    end)
    fold:SetScript("OnEnter", function(self)
        ShowChatTipDelayed(self, "ANCHOR_TOP", ChatDB().headerFolded and "Show the header" or "Fold the header")
    end)
    fold:SetScript("OnLeave", function(self) HideChatTip(self) end)
    self:CreateChatMessageFilter(view, detail)
    if chatNS.Pins then chatNS.Pins:CreateHeaderButton(view, detail) end
    view.headerSubtext:SetJustifyH("LEFT")
    view.headerSubtext:SetWordWrap(false)
    if view.headerSubtext.SetMaxLines then view.headerSubtext:SetMaxLines(1) end

    -- in-place compose: an editable "To:" field shown where the name normally sits
    view.headerRecipientShell = CreateFrame("Frame", nil, detail)
    view.headerRecipientShell:SetPoint("TOPLEFT", detail, "TOPLEFT", 6, -6)
    view.headerRecipientShell:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -8, -6)
    view.headerRecipientShell:SetHeight(28)
    view.headerRecipientShell:SetFrameLevel(detail:GetFrameLevel() + 8)
    self:StyleChatComposerInputSurface(view.headerRecipientShell, 8, 0.98)
    view.headerRecipientShell:EnableMouse(true)
    view.headerRecipientShell:SetScript("OnMouseDown", function()
        UI:FocusChatEditBox(view.headerRecipientEdit)
    end)
    view.headerRecipientShell:Hide()

    local toLabel = view.headerRecipientShell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    view.headerRecipientToLabel = toLabel
    toLabel:SetPoint("LEFT", view.headerRecipientShell, "LEFT", 10, 0)
    toLabel:SetText("To:")
    RegisterChatThemedText(toLabel, 0.85)

    view.headerRecipientEdit = CreateFrame("EditBox", nil, view.headerRecipientShell)
    view.headerRecipientEdit:SetPoint("LEFT", toLabel, "RIGHT", 6, 0)
    view.headerRecipientEdit:SetPoint("RIGHT", view.headerRecipientShell, "RIGHT", -10, 0)
    view.headerRecipientEdit:SetHeight(20)
    view.headerRecipientEdit:SetAutoFocus(false)
    view.headerRecipientEdit:SetFontObject(GameFontHighlightSmall)
    view.headerRecipientEdit._chatInput = true
    RegisterChatThemedText(view.headerRecipientEdit)
    RegisterChatThemedText(view.headerRecipientEdit)
    if view.headerRecipientEdit.SetTextInsets then view.headerRecipientEdit:SetTextInsets(0, 0, 0, 0) end
    view.headerRecipientPlaceholder = view.headerRecipientShell:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    view.headerRecipientPlaceholder:SetPoint("LEFT", view.headerRecipientEdit, "LEFT", 0, 0)
    view.headerRecipientPlaceholder:SetText("Name or BattleTag")
    RegisterChatThemedText(view.headerRecipientPlaceholder, 0.5)
    -- Same email-style recipient machine the compose view runs: live friend
    -- suggestions while typing, Enter/Tab picks into a chip, comma splits,
    -- multiple recipients condense with an overflow chip.
    view.headerRecipientEdit:SetScript("OnTextChanged", function()
        UI:HandleChatRecipientTextChanged()
    end)
    view.headerRecipientEdit:SetScript("OnEditFocusGained", function(self)
        UI:ClearChatMessageCopyFocus(self)
        UI:RefreshChatFriendEntries()
        UI:RefreshChatRecipientSuggestions()
    end)
    Utils.ReleaseFocusOnOutsideClick(view.headerRecipientEdit)
    view.headerRecipientEdit:SetScript("OnEnterPressed", function()
        if not UI:ConsumeChatRecipientInput(true) and view.replyEditBox then
            UI:FocusChatEditBox(view.replyEditBox)
        end
    end)
    view.headerRecipientEdit:SetScript("OnTabPressed", function()
        if not UI:ConsumeChatRecipientInput(true) and view.replyEditBox then
            UI:FocusChatEditBox(view.replyEditBox)
        end
    end)
    view.headerRecipientEdit:SetScript("OnEscapePressed", function()
        UI:ClearFocusedChatEditBox()
    end)
    view.headerRecipientEdit:SetScript("OnKeyDown", function(self, key)
        if UI:HandleChatFontScaleKey(self, key) then return end
        if UI:HandleChatClipboardKey(self, key) then return end
        if key == "UP" then
            UI:NavigateChatRecipientSuggestion(-1)
        elseif key == "DOWN" then
            UI:NavigateChatRecipientSuggestion(1)
        elseif key == "BACKSPACE" and (self:GetText() or "") == "" then
            UI:RemoveLastChatRecipient()
        end
        Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
    end)

    view.messageScroll = CreateFrame("ScrollFrame", nil, detail)
    view.messageScroll:SetFrameLevel(detail:GetFrameLevel() + 1)
    view.messageScroll:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -40)
    view.messageScroll:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", 0, 52)
    view.messageScroll:EnableMouseWheel(true)
    view.messageChild = CreateFrame("Frame", nil, view.messageScroll)
    view.messageChild:SetSize(1, 1)
    view.messageScroll:SetScrollChild(view.messageChild)
    view.messageScrollBar = ns.Utils.CreateMinimalScrollBar(view.messageScroll, detail)
    view.messageScrollBar:ClearAllPoints()
    view.messageScrollBar:SetPoint("TOPRIGHT", view.messageScroll, "TOPRIGHT", -4, -4)
    view.messageScrollBar:SetPoint("BOTTOMRIGHT", view.messageScroll, "BOTTOMRIGHT", -4, 4)
    -- Scrolled up from the newest: a button back down, counting what came in.
    local newest = CreateFrame("Button", nil, detail)
    view.newestButton = newest
    newest:Hide()
    newest:SetSize(26, 26)
    newest:SetFrameLevel(view.messageScroll:GetFrameLevel() + 30)
    newest:SetPoint("BOTTOMRIGHT", view.messageScroll, "BOTTOMRIGHT", -16, 8)
    self:StyleCalculatorButton(newest, 26)
    newest.glyph = newest:CreateTexture(nil, "OVERLAY")
    newest.glyph:SetTexture(ns.FILTER_ARROW_TEX)
    newest.glyph:SetSize(11, 11)
    newest.glyph:SetPoint("CENTER", 0, -1)
    RegisterChatThemedText(newest.glyph)
    newest.count = ns.CreateCountBadge(newest, 12)
    newest.count:SetFrameLevel(newest:GetFrameLevel() + 4)
    newest.count:SetPoint("CENTER", newest, "TOPRIGHT", -2, -2)
    newest:SetScript("OnClick", function() UI:ScrollChatToNewest() end)
    newest:HookScript("OnEnter", function(self) ShowChatTipDelayed(self, "ANCHOR_TOP", "Jump to newest") end)
    newest:HookScript("OnLeave", function(self) HideChatTip(self) end)
    view.messageScroll:HookScript("OnVerticalScroll", function(_, offset)
        UI:UpdateChatMessageScrollBar()
        UI:UpdateChatNewestButton(view)
        -- Near the top with older messages not laid out: lay them out.
        if (offset or 0) < 40 and (view._chatRenderedFrom or 1) > 1 then UI:QueueMoreChatHistory(view) end
    end)
    -- The range settling after a layout: the button answers to the true one.
    view.messageScroll:HookScript("OnScrollRangeChanged", function() UI:UpdateChatNewestButton(view) end)
    view.messageRows = {}
    view.dateRows = {}
    self:EnsureChatMessageRow(view, 1)
    self:EnsureChatDateRow(view, 1)

    view.empty = detail:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    view.empty:SetPoint("CENTER", view.messageScroll, "CENTER", 0, 18)
    view.empty:SetText("No conversations yet")

    view.replyBanner = CreateFrame("Frame", nil, detail)
    view.replyBanner:SetFrameLevel(detail:GetFrameLevel() + 19)
    self:StyleChatComposerInputSurface(view.replyBanner, 8, 0.98)
    view.replyBanner:EnableMouse(true)
    view.replyBannerText = view.replyBanner:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    view.replyBannerText:SetPoint("LEFT", view.replyBanner, "LEFT", 10, 0)
    view.replyBannerText:SetPoint("RIGHT", view.replyBanner, "RIGHT", -30, 0)
    view.replyBannerText:SetJustifyH("LEFT")
    view.replyBannerText:SetWordWrap(false)
    if view.replyBannerText.SetMaxLines then view.replyBannerText:SetMaxLines(1) end
    view.replyBannerClose = CreateFrame("Button", nil, view.replyBanner)
    view.replyBannerClose:SetSize(18, 18)
    view.replyBannerClose:SetPoint("RIGHT", view.replyBanner, "RIGHT", -5, 0)
    view.replyBannerClose.text = view.replyBannerClose:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    view.replyBannerClose.text:SetPoint("CENTER", 0, 1)
    view.replyBannerClose.text:SetText("x")
    view.replyBannerClose:SetScript("OnClick", function()
        UI:CancelChatReply()
    end)
    view.replyBanner:Hide()

    view.replyShell = CreateFrame("Frame", nil, detail)
    view.replyShell:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 0, 0)
    view.replyShell:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -62, 0)
    view.replyShell:SetHeight(30)
    view.replyShell:SetFrameLevel(detail:GetFrameLevel() + 20)
    local replyWell = self:StyleChatInputWell(view.replyShell, 8)
    view.replyShell:EnableMouse(true)
    view.replyShell:SetScript("OnMouseDown", function()
        UI:FocusChatEditBox(view.replyEditBox)
    end)
    view.replyEditBox = CreateFrame("EditBox", nil, view.replyShell)
    view.replyEditBox:SetPoint("TOPLEFT", view.replyShell, "TOPLEFT", 10, -10)
    view.replyEditBox:SetPoint("BOTTOMRIGHT", view.replyShell, "BOTTOMRIGHT", -7, 10)
    view.replyEditBox:SetFrameLevel(view.replyShell:GetFrameLevel() + 2)
    view.replyEditBox:SetAutoFocus(false)
    view.replyEditBox:SetMultiLine(true)
    view.replyEditBox:SetScript("OnSizeChanged", function() UI:QueueChatReplyInputLayout() end)
    UI:SetChatEditMaxLetters(view.replyEditBox, CHAT_MESSAGE_MAX_CHARS)
    view.replyEditBox:SetFontObject(GameFontHighlightSmall)
    view.replyEditBox._chatInput = true
    RegisterChatThemedText(view.replyEditBox)
    view.replyEditBox:SetJustifyH("LEFT")
    if view.replyEditBox.SetJustifyV then view.replyEditBox:SetJustifyV("TOP") end
    if view.replyEditBox.SetWordWrap then view.replyEditBox:SetWordWrap(true) end
    if view.replyEditBox.SetNonSpaceWrap then view.replyEditBox:SetNonSpaceWrap(true) end
    if view.replyEditBox.SetTextInsets then view.replyEditBox:SetTextInsets(0, 0, 0, 0) end
    if view.replyEditBox.SetCursorColor then view.replyEditBox:SetCursorColor(1, 1, 1, 1) end
    view.replyPlaceholder = replyWell:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    view.replyPlaceholder:SetPoint("TOPLEFT", view.replyShell, "TOPLEFT", 10, -10)
    view.replyPlaceholder:SetPoint("RIGHT", view.replyShell, "RIGHT", -10, 0)
    view.replyPlaceholder:SetText("Type a message...")
    RegisterChatThemedText(view.replyPlaceholder, 0.5)
    view.replyPlaceholder:SetJustifyH("LEFT")
    view.replyPlaceholder:SetWordWrap(false)
    view.replyCounter = detail:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    view.replyCounter:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -2, 0)
    view.replyCounter:SetJustifyH("CENTER")
    view.replyCounter:SetText("0/" .. CHAT_MESSAGE_MAX_CHARS)
    RegisterChatThemedText(view.replyCounter, 0.75)
    view.replyCounter:SetAlpha(ChatLight() and 1 or 0.82)
    if view.replyCounter.SetDrawLayer then view.replyCounter:SetDrawLayer("OVERLAY", 7) end
    view.replyEditBox:SetScript("OnTextChanged", function(self, userInput)
        local typed = self:GetText() or ""
        local inAll = chatNS.Views and UI._chatComposer.selectedConversationKey == chatNS.Views.ALL
        if userInput and ((ChatDB().takeover and typed:sub(1, 1) == "/") or (inAll and typed ~= "")) then
            UI:HandChatLineToGame(self, typed)
            return
        end
        if view.replyPlaceholder then
            view.replyPlaceholder:SetShown((view.replyEditBox:GetText() or "") == "")
        end
        if not UI._chatComposer.loadingReplyDraft then
            UI:SaveChatDraftForKey(UI._chatComposer.selectedConversationKey, view.replyEditBox:GetText() or "")
        end
        UI:UpdateChatCharCounter(view.replyEditBox, view.replyCounter, UI:GetChatReplyInputLimit())
        UI:QueueChatReplyInputLayout()
    end)
    view.replyEditBox:SetScript("OnEditFocusGained", function(self)
        UI:ClearChatMessageCopyFocus(self)
    end)
    view.replyEditBox:SetScript("OnEnterPressed", function(self)
        if IsShiftKeyDown and IsShiftKeyDown() then
            UI:InsertChatEditNewLine(self)
        else
            UI:SubmitChatReplyLine(self)
        end
    end)
    view.replyEditBox:SetScript("OnKeyDown", function(self, key)
        if UI:HandleChatFontScaleKey(self, key) then return end
        if UI:HandleChatClipboardKey(self, key) then return end
        if key == "ENTER" then
            if IsShiftKeyDown and IsShiftKeyDown() then
                UI:InsertChatEditNewLine(self)
            else
                UI:SubmitChatReplyLine(self)
            end
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
            return
        end
        Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
    end)
    view.replyEditBox:SetScript("OnEscapePressed", function()
        UI:ClearFocusedChatEditBox()
        UI:CloseChatLine()
    end)
    -- Hidden until Enter, an empty line goes with the focus.
    view.replyEditBox:SetScript("OnEditFocusLost", function(self)
        if (self:GetText() or "") == "" then UI:CloseChatLine() end
    end)
    Utils.ReleaseFocusOnOutsideClick(view.replyEditBox)
    -- After the last SetScript: a later SetScript("OnTextChanged") would
    -- wipe the hook this installs.
    EasyFind.API.CallAction("snippets", "attachExpansion", view.replyEditBox)

    view.replyButton = CreateFrame("Button", nil, detail)
    view.replyButton:SetSize(56, 30)
    view.replyButton:SetPoint("TOPLEFT", view.replyShell, "TOPRIGHT", 6, 0)
    view.replyButton:SetFrameLevel(view.replyShell:GetFrameLevel() + 1)
    self:StyleCalculatorButton(view.replyButton, 30)
    view.replyButton.text = view.replyButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    view.replyButton.text._chatOnAccent = true
    RegisterChatThemedText(view.replyButton.text)
    view.replyButton.text:SetPoint("CENTER")
    view.replyButton.text:SetText("Send")
    view.replyButton:HookScript("OnEnter", function(self) UI:PaintChatSendButton(self, true) end)
    view.replyButton:HookScript("OnLeave", function(self) UI:PaintChatSendButton(self, false) end)
    self:PaintChatSendButton(view.replyButton, false)
    view.replyButton:SetScript("OnClick", function() UI:SendChatMessengerReply() end)
    view.messageScroll:SetScript("OnSizeChanged", function()
        if UI._chatComposer.layoutingReplyInput then
            UI:UpdateChatMessageScrollBar()
            return
        end
        local grip = UI._chatComposer.frame and UI._chatComposer.frame.resizeGrip
        if UI._chatComposer.sidebarResizing or (grip and grip.sizing) then
            UI:QueueChatMessengerRefresh()
        else
            UI:RefreshChatMessenger()
        end
    end)

    self:InstallChatFontScaleWheel(view)
    sidebar:SetScript("OnMouseWheel", function(_, delta)
        view.conversationOffset = mmax(0, (view.conversationOffset or 0) - delta)
        UI:RefreshChatMessenger()
    end)
    self:InstallChatFontScaleWheel(sidebar)
    self:InstallChatFontScaleWheel(view.composeButton)
    self:InstallChatFontScaleWheel(view.sidebarCollapseButton)
    self:InstallChatFontScaleWheel(detail)
    self:InstallChatFontScaleWheel(searchShell)
    self:InstallChatFontScaleWheel(view.searchEditBox)
    self:InstallChatFontScaleWheel(view.searchClearButton)
    self:InstallChatFontScaleWheel(view.messageScroll)
    self:InstallChatFontScaleWheel(view.messageScrollBar)
    self:InstallChatFontScaleWheel(view.replyShell)
    self:InstallChatFontScaleWheel(view.replyEditBox)
    self:InstallChatFontScaleWheel(view.replyButton)
    self:InstallChatFontScaleWheel(view.replyBanner)
    for _, box in ipairs({ view.searchEditBox, view.headerRecipientEdit, view.replyEditBox }) do
        box:HookScript("OnKeyDown", function(b, key) UI:ArmChatHoveredCopy(b, key) end)
        box:HookScript("OnKeyDown", function(b, key) UI:HandleChatFindKey(b, key) end)
    end

    return view
end

function UI:EnsureChatComposerFrame()
    local frame = UI._chatComposer.frame
    if frame then return frame end

    local CHAT_W, CHAT_H = 544, 408
    -- The new-message form: placed by LayoutChatComposer from these.
    local FORM_PAD = 16
    local LABEL_GAP = 10
    local FIELD_H = 26
    local FIELD_LEFT_X = 90
    local FORM_TOP_Y = CHAT_WINDOW_HEADER_H + 12
    local FOOTER_H = 29

    frame = CreateFrame("Frame", "EasyFindChatComposerFrame", UIParent)
    -- Its Classic frame at a window's full weight.
    frame._efClassicStyle = "window"
    -- Built hidden: a new frame starts shown, so its first open ran no OnShow.
    frame:Hide()
    UI._chatComposer.frame = frame
    -- Small enough to sit in the game's chat corner.
    local minW, minH, maxW, maxH = 280, 180, CHAT_W * 2, CHAT_H * 2
    local db = ChatDB()
    frame:SetSize(mmax(minW, mmin(maxW, tonumber(db.windowWidth) or CHAT_W)),
        mmax(minH, mmin(maxH, tonumber(db.windowHeight) or CHAT_H)))
    frame:SetScale(0.88)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(880)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    -- Moves only while unlocked (the lock beside the X); the place is read
    -- before the stop, which can leave the frame with no points.
    frame:SetScript("OnDragStart", function()
        if not ChatDB().windowUnlocked then return end
        -- Held by its top-left where it shows, as the grip does: moved from
        -- its center anchor in its own 0.88 scale, the first drag jumped.
        local left, top = frame:GetLeft(), frame:GetTop()
        if left and top then
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
        frame:StartMoving()
    end)
    frame:SetScript("OnDragStop", function()
        local x, y = frame:GetCenter()
        frame:StopMovingOrSizing()
        -- With the game's line in ours (GameLine.lua) the stop leaves no points.
        if x and y and frame:GetNumPoints() == 0 then frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y) end
        if x and y and ChatDB().windowUnlocked then ChatDB().windowCenter = { x, y } end
    end)
    frame._chatForm = {
        pad = FORM_PAD,
        labelGap = LABEL_GAP,
        rowGap = 6,
        fieldHeight = FIELD_H,
        formTopY = FORM_TOP_Y,
    }
    ns.CreateRoundedRectBorder(frame)
    ns.SetRoundedRectBarHeight(frame, 16)
    ns.SetRoundedRectBorderBgAlpha(frame, 0.97)
    self:ApplyChatWindowLook()

    local headerLine = frame:CreateTexture(nil, "BORDER")
    headerLine:SetHeight(1)
    headerLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -CHAT_WINDOW_HEADER_H)
    headerLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -CHAT_WINDOW_HEADER_H)
    headerLine:SetColorTexture(Utils.RGB(CHAT_SEPARATOR_COLOR, 0.35))
    frame._efThemeSeps = { headerLine }
    frame.headerLine = headerLine
    ns.RetintMenuSeparators(frame)

    local close = ns.CreateCloseX(frame, 18)
    frame.closeButton = close
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    close:SetScript("OnClick", function() frame:Hide() end)

    -- The lock left of the X: unlocked, the corner grip resizes the window.
    local lock = CreateFrame("Button", nil, frame)
    frame.lockButton = lock
    lock:SetSize(22, 22)
    lock:SetPoint("RIGHT", close, "LEFT", -8, 0)
    self:StyleCalculatorButton(lock, 22)
    lock.glyph = lock:CreateTexture(nil, "OVERLAY")
    lock.glyph:SetSize(14, 14)
    lock.glyph:SetPoint("CENTER")
    RegisterChatThemedText(lock.glyph)
    -- Folds the title bar away for the chat, and back.
    local titleFold = CreateFrame("Button", nil, frame)
    frame.titleFold = titleFold
    titleFold:SetSize(16, 16)
    titleFold:SetFrameLevel(frame:GetFrameLevel() + 6)
    titleFold.glyph = titleFold:CreateTexture(nil, "OVERLAY")
    titleFold.glyph:SetTexture(ns.FILTER_ARROW_TEX)
    titleFold.glyph:SetSize(12, 12)
    titleFold.glyph:SetPoint("CENTER")
    RegisterChatThemedText(titleFold.glyph, 0.75)
    titleFold:SetScript("OnClick", function()
        ChatDB().titleFolded = not ChatDB().titleFolded or nil
        UI:ApplyChatTitleFold(frame)
        UI:RefreshChatMessenger()
    end)
    titleFold:SetScript("OnEnter", function(self)
        ShowChatTipDelayed(self, "ANCHOR_TOP", ChatDB().titleFolded and "Show the title bar" or "Fold the title bar")
    end)
    titleFold:SetScript("OnLeave", function(self) HideChatTip(self) end)
    local clock = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.titleClock = clock
    clock:SetJustifyH("RIGHT")
    clock:SetWordWrap(false)
    RegisterChatThemedText(clock, 0.75)
    clock:Hide()
    -- Folded, the strip can name the open conversation (an option).
    local foldedTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.foldedTitle = foldedTitle
    foldedTitle:SetJustifyH("LEFT")
    foldedTitle:SetWordWrap(false)
    RegisterChatThemedText(foldedTitle)
    foldedTitle:Hide()
    AttachClippedTip(foldedTitle, frame, frame:GetFrameLevel() + 6)
    -- Folded, the strip keeps the settings cog in its corner, bare as its
    -- arrow and X.
    local foldedCog = CreateFrame("Button", nil, frame)
    frame.foldedSettingsButton = foldedCog
    foldedCog:SetSize(16, 16)
    foldedCog:SetFrameLevel(frame:GetFrameLevel() + 6)
    foldedCog.glyph = foldedCog:CreateTexture(nil, "OVERLAY")
    if not (ns.COG_ICON_TEX and foldedCog.glyph:SetTexture(ns.COG_ICON_TEX)) then
        foldedCog.glyph:SetAtlas("QuestLog-icon-setting", false)
        foldedCog.glyph:SetDesaturated(true)
    end
    foldedCog.glyph:SetSize(12, 12)
    foldedCog.glyph:SetPoint("CENTER")
    RegisterChatThemedText(foldedCog.glyph, 0.75)
    AddCogGlow(foldedCog, 12)
    foldedCog:SetScript("OnClick", function() UI:OpenChatSettings() end)
    foldedCog:Hide()
    local grip = CreateFrame("Button", nil, frame)
    grip:Hide()
    frame.resizeGrip = grip
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    grip:SetFrameLevel(frame:GetFrameLevel() + 40)
    grip.tex = grip:CreateTexture(nil, "OVERLAY")
    grip.tex:SetAllPoints()
    grip.tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    RegisterChatThemedText(grip.tex, 0.8)
    -- Unseen until the pointer finds it, as the notes window's; lit in the
    -- accent while there.
    grip:SetAlpha(0)
    grip:SetScript("OnEnter", function()
        grip:SetAlpha(1)
        grip.tex:SetVertexColor(ChatAccentGlyphColor())
    end)
    grip:SetScript("OnLeave", function()
        if grip.sizing then return end
        grip:SetAlpha(0)
        PaintChatThemedText(grip.tex)
    end)
    -- Sized by hand from the press, as the sidebar is: StartSizing right
    -- after the window took its corner anchor could jump it to full size.
    local function StopGripSizing()
        if not grip.sizing then return end
        grip.sizing = nil
        Utils.SafeOnUpdate(grip, nil)
        if not grip:IsMouseOver() then
            grip:SetAlpha(0)
            PaintChatThemedText(grip.tex)
        end
        local x, y = frame:GetCenter()
        local saved = ChatDB()
        saved.windowWidth = math.floor(frame:GetWidth() + 0.5)
        saved.windowHeight = math.floor(frame:GetHeight() + 0.5)
        if x and y then saved.windowCenter = { x, y } end
    end
    local function GripOnUpdate()
        if not IsMouseButtonDown("LeftButton") then
            StopGripSizing()
            return
        end
        local x, y = GetCursorPosition()
        local scale = frame:GetEffectiveScale()
        frame:SetSize(mmax(minW, mmin(maxW, grip.startW + x / scale - grip.startX)),
            mmax(minH, mmin(maxH, grip.startH - (y / scale - grip.startY))))
    end
    grip:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        -- Sizing keeps the anchor still: placed by its center (the saved
        -- spot), the window would grow from both sides and jump. The top-
        -- left corner holds instead.
        local left, top = frame:GetLeft(), frame:GetTop()
        if left and top then
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
        local x, y = GetCursorPosition()
        local scale = frame:GetEffectiveScale()
        grip.startX, grip.startY = x / scale, y / scale
        grip.startW, grip.startH = frame:GetWidth(), frame:GetHeight()
        grip.sizing = true
        Utils.SafeOnUpdate(grip, GripOnUpdate)
    end)
    grip:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then StopGripSizing() end
    end)
    local function LockTip()
        return ChatDB().windowUnlocked and "Lock in place" or "Unlock to move and resize"
    end
    local function SyncLock()
        local unlocked = ChatDB().windowUnlocked == true
        lock.glyph:SetTexture(unlocked and CHAT_UNLOCK_TEX or CHAT_LOCK_TEX)
        grip:SetShown(unlocked)
    end
    lock:SetScript("OnClick", function()
        ChatDB().windowUnlocked = not ChatDB().windowUnlocked or nil
        SyncLock()
        HideChatTip(lock)
        ShowChatTipDelayed(lock, "ANCHOR_TOP", LockTip())
    end)
    lock:HookScript("OnEnter", function() ShowChatTipDelayed(lock, "ANCHOR_TOP", LockTip()) end)
    lock:HookScript("OnLeave", function() HideChatTip(lock) end)
    SyncLock()

    local backButton = CreateFrame("Button", nil, frame)
    frame.composeBackButton = backButton
    backButton:SetSize(22, 22)
    backButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    self:StyleCalculatorButton(backButton, 22)
    -- Custom flyout triangle (pointing left for "back"), matching the arrows
    -- EasyFind uses everywhere, instead of a plain "<" character.
    backButton.arrow = backButton:CreateTexture(nil, "OVERLAY")
    backButton.arrow:SetTexture(ns.FILTER_ARROW_TEX)
    backButton.arrow:SetSize(9, 9)
    backButton.arrow:SetPoint("CENTER")
    backButton.arrow:SetRotation(-math.pi / 2)
    backButton.arrow:SetVertexColor(0.9, 0.9, 0.92, 1)
    backButton:SetScript("OnClick", function()
        UI:ShowChatMessengerView()
    end)

    local chatLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.chatLabel = chatLabel
    chatLabel:SetText("Chat")
    RegisterChatThemedText(chatLabel, 0.85)

    local channelButton = CreateFrame("Button", nil, frame)
    frame.channelButton = channelButton
    channelButton:SetPoint("TOPLEFT", frame, "TOPLEFT", FIELD_LEFT_X, -FORM_TOP_Y)
    channelButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -FORM_PAD, -FORM_TOP_Y)
    channelButton:SetHeight(FIELD_H)
    self:StyleChatComposerSelect(channelButton)
    channelButton:SetScript("OnClick", function() UI:ToggleChatChannelMenu() end)
    chatLabel:SetPoint("RIGHT", channelButton, "LEFT", -LABEL_GAP, 0)

    local channelText = channelButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.channelText = channelText
    channelText:SetPoint("LEFT", channelButton, "LEFT", 14, 0)
    channelText:SetPoint("RIGHT", channelButton, "RIGHT", -32, 0)
    channelText:SetJustifyH("LEFT")

    local caret = channelButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    caret:SetPoint("RIGHT", channelButton, "RIGHT", -14, 0)
    caret:SetText("v")
    RegisterChatThemedText(caret, 0.9)

    local targetLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.targetLabel = targetLabel
    targetLabel:SetText("To")
    RegisterChatThemedText(targetLabel, 0.85)

    local targetPanel = CreateFrame("Frame", nil, frame)
    frame.targetPanel = targetPanel
    targetPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", FIELD_LEFT_X, -(FORM_TOP_Y + FIELD_H + 8))
    targetPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -FORM_PAD, -(FORM_TOP_Y + FIELD_H + 8))
    targetPanel:SetHeight(FIELD_H)
    targetLabel:SetPoint("RIGHT", targetPanel, "LEFT", -LABEL_GAP, 0)

    local targetShell = CreateFrame("Frame", nil, targetPanel)
    frame.targetShell = targetShell
    targetShell:SetAllPoints(targetPanel)
    self:StyleChatComposerInputSurface(targetShell, 8, 0.98)
    targetShell:EnableMouse(true)

    local targetPlaceholder = targetShell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.targetPlaceholder = targetPlaceholder
    targetPlaceholder:SetPoint("LEFT", targetShell, "LEFT", 10, 0)
    targetPlaceholder:SetText("Name or BattleTag")
    RegisterChatThemedText(targetPlaceholder, 0.5)

    local targetEdit = CreateFrame("EditBox", nil, targetShell)
    frame.targetEditBox = targetEdit
    targetEdit:SetPoint("LEFT", targetShell, "LEFT", 10, 0)
    targetEdit:SetPoint("RIGHT", targetShell, "RIGHT", -32, 0)
    targetEdit:SetHeight(20)
    targetEdit:SetAutoFocus(false)
    targetEdit:SetFontObject(GameFontHighlightSmall)
    targetEdit._chatInput = true
    RegisterChatThemedText(targetEdit)
    RegisterChatThemedText(targetEdit)
    targetShell:SetScript("OnMouseDown", function()
        UI:FocusChatEditBox(targetEdit)
    end)

    local targetDropdown = CreateFrame("Button", nil, targetShell)
    frame.targetDropdownButton = targetDropdown
    targetDropdown:SetSize(22, 22)
    targetDropdown:SetPoint("RIGHT", targetShell, "RIGHT", -5, 0)
    targetDropdown.text = targetDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    targetDropdown.text:SetPoint("CENTER", 0, 1)
    targetDropdown.text:SetText("v")
    RegisterChatThemedText(targetDropdown.text, 0.9)
    targetDropdown:SetScript("OnEnter", function(self) self.text:SetTextColor(ChatAccentGlyphColor()) end)
    targetDropdown:SetScript("OnLeave", function(self) PaintChatThemedText(self.text) end)
    targetDropdown:SetScript("OnClick", function()
        UI:ToggleChatContactDropdown()
    end)

    targetEdit:SetScript("OnTextChanged", function()
        UI:HandleChatRecipientTextChanged()
    end)
    targetEdit:SetScript("OnEnterPressed", function()
        UI:ConsumeChatRecipientInput(true)
    end)
    targetEdit:SetScript("OnTabPressed", function()
        UI:ConsumeChatRecipientInput(true)
    end)
    targetEdit:SetScript("OnEscapePressed", function()
        UI:ClearFocusedChatEditBox()
    end)
    targetEdit:SetScript("OnEditFocusGained", function()
        if frame.channelMenu then frame.channelMenu:Hide() end
        UI:RefreshChatFriendEntries()
        UI:RefreshChatRecipientSuggestions()
    end)
    Utils.ReleaseFocusOnOutsideClick(targetEdit)
    targetEdit:SetScript("OnKeyDown", function(self, key)
        if UI:HandleChatFontScaleKey(self, key) then return end
        if UI:HandleChatClipboardKey(self, key) then return end
        if key == "UP" then
            UI:NavigateChatRecipientSuggestion(-1)
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
            return
        elseif key == "DOWN" then
            UI:NavigateChatRecipientSuggestion(1)
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
            return
        elseif key == "TAB" then
            UI:ConsumeChatRecipientInput(true)
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
            return
        elseif key == "BACKSPACE" and (self:GetText() or "") == "" then
            UI:RemoveLastChatRecipient()
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
            return
        end
        Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
    end)

    local messageLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.messageLabel = messageLabel
    messageLabel:SetText("Message")
    RegisterChatThemedText(messageLabel, 0.85)

    local messageShell = CreateFrame("Frame", nil, frame)
    frame.messageShell = messageShell
    self:StyleChatComposerInputSurface(messageShell, 8, 0.96)
    messageShell:EnableMouse(true)

    local messageEdit = CreateFrame("EditBox", nil, messageShell)
    frame.messageEditBox = messageEdit
    messageEdit:SetPoint("TOPLEFT", messageShell, "TOPLEFT", 10, -10)
    messageEdit:SetPoint("BOTTOMRIGHT", messageShell, "BOTTOMRIGHT", -7, 10)
    messageEdit:SetAutoFocus(false)
    messageEdit:SetMultiLine(true)
    UI:SetChatEditMaxLetters(messageEdit, CHAT_MESSAGE_MAX_CHARS)
    messageEdit:SetFontObject(GameFontHighlightSmall)
    messageEdit._chatInput = true
    RegisterChatThemedText(messageEdit)
    messageEdit:SetJustifyH("LEFT")
    messageEdit:SetJustifyV("TOP")
    if messageEdit.SetTextInsets then messageEdit:SetTextInsets(0, 3, 0, 0) end
    messageShell:SetScript("OnMouseDown", function()
        UI:FocusChatEditBox(messageEdit)
    end)
    frame.messageCounter = messageShell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.messageCounter:SetPoint("BOTTOMRIGHT", messageShell, "BOTTOMRIGHT", -12, 7)
    frame.messageCounter:SetJustifyH("RIGHT")
    frame.messageCounter:SetText("0/" .. CHAT_MESSAGE_MAX_CHARS)
    RegisterChatThemedText(frame.messageCounter, 0.75)
    frame.messageCounter:SetAlpha(0.82)
    messageEdit:SetScript("OnTextChanged", function()
        UI:UpdateChatCharCounter(messageEdit, frame.messageCounter)
        UI:RefreshChatComposerSendState()
    end)
    messageEdit:SetScript("OnEditFocusGained", function()
        if frame.suggestionMenu then frame.suggestionMenu:Hide() end
    end)
    Utils.ReleaseFocusOnOutsideClick(messageEdit)
    messageEdit:SetScript("OnEscapePressed", function()
        UI:ClearFocusedChatEditBox()
    end)
    messageEdit:SetScript("OnKeyDown", function(self, key)
        if UI:HandleChatFontScaleKey(self, key) then return end
        if UI:HandleChatClipboardKey(self, key) then return end
        if key == "ENTER" and IsShiftKeyDown and IsShiftKeyDown() then
            UI:InsertChatEditNewLine(self)
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
            return
        elseif key == "ENTER" and IsControlKeyDown and IsControlKeyDown() then
            UI:SendChatComposerMessage()
            Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
            return
        end
        Utils.SafeCallMethod(self, "SetPropagateKeyboardInput", false)
    end)
    if ns.Snippets then ns.Snippets.AttachExpansion(messageEdit) end

    local footer = CreateFrame("Frame", nil, frame)
    frame.footer = footer
    footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 5, 5)
    footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)
    footer:SetHeight(FOOTER_H)
    self:StyleChatComposerInputSurface(footer, 12, 1)

    local footerIcon = footer:CreateTexture(nil, "ARTWORK")
    footerIcon:SetSize(20, 20)
    footerIcon:SetPoint("LEFT", footer, "LEFT", 12, 0)
    footerIcon:SetTexture("Interface\\FriendsFrame\\UI-Toast-ChatInviteIcon")

    local footerTitle = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footerTitle:SetPoint("LEFT", footerIcon, "RIGHT", 10, 0)
    footerTitle:SetText("Send Message")
    RegisterChatThemedText(footerTitle, 0.9)

    local statusText = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.statusText = statusText
    statusText:SetPoint("LEFT", footerTitle, "RIGHT", 12, 0)
    statusText:SetJustifyH("LEFT")
    statusText:SetWordWrap(false)
    if statusText.SetMaxLines then statusText:SetMaxLines(1) end

    local sendButton = CreateFrame("Button", nil, footer)
    frame.sendButton = sendButton
    sendButton:SetHeight(20)
    sendButton:SetPoint("RIGHT", footer, "RIGHT", -9, 0)
    self:StyleCalculatorButton(sendButton, 20)
    sendButton.text = sendButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sendButton.text:SetPoint("CENTER")
    sendButton.text:SetText("Send Message")
    statusText:SetPoint("RIGHT", sendButton, "LEFT", -12, 0)
    sendButton.text:SetTextColor(1, 1, 1, 1)
    sendButton:SetScript("OnClick", function() UI:SendChatComposerMessage() end)

    local channelMenu = CreateFrame("Frame", nil, frame)
    frame.channelMenu = channelMenu
    channelMenu:SetPoint("TOPLEFT", channelButton, "BOTTOMLEFT", 0, -4)
    channelMenu:SetPoint("RIGHT", channelButton, "RIGHT", 0, 0)
    channelMenu:SetHeight(7 * 26 + 8)
    channelMenu:SetFrameLevel(frame:GetFrameLevel() + 15)
    channelMenu:EnableMouse(true)
    ns.StyleMenuPanel(channelMenu)
    Utils.AttachOutsideClickClose(channelMenu, channelButton)
    channelMenu:Hide()

    for i = 1, #UI._chatComposer.CHANNELS do
        local def = UI._chatComposer.CHANNELS[i]
        local button = CreateFrame("Button", nil, channelMenu)
        button:SetHeight(24)
        button:SetPoint("TOPLEFT", channelMenu, "TOPLEFT", 5, -4 - (i - 1) * 26)
        button:SetPoint("RIGHT", channelMenu, "RIGHT", -5, 0)
        button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.text:SetPoint("LEFT", button, "LEFT", 8, 0)
        button.text:SetText(def.label)
        RegisterChatThemedText(button.text)
        button:SetScript("OnEnter", function(self) self.text:SetTextColor(ChatAccentGlyphColor()) end)
        button:SetScript("OnLeave", function(self) PaintChatThemedText(self.text) end)
        button:SetScript("OnClick", function()
            UI._chatComposer.channel = def.key
            channelMenu:Hide()
            UI:SetChatComposerStatus("")
            UI:RefreshChatComposerChannel()
            if def.needsRecipients then
                targetEdit:SetFocus()
            else
                messageEdit:SetFocus()
            end
        end)
    end

    local suggestionMenu = CreateFrame("Frame", nil, frame)
    frame.suggestionMenu = suggestionMenu
    suggestionMenu:SetPoint("TOPLEFT", targetShell, "BOTTOMLEFT", 0, -4)
    suggestionMenu:SetPoint("RIGHT", targetShell, "RIGHT", 0, 0)
    suggestionMenu:SetHeight(6 * 34 + 8)
    suggestionMenu:SetFrameLevel(frame:GetFrameLevel() + 15)
    suggestionMenu:EnableMouse(true)
    ns.StyleMenuPanel(suggestionMenu)
    Utils.AttachOutsideClickClose(suggestionMenu, targetShell)
    suggestionMenu:HookScript("OnHide", function()
        UI._chatComposer.showAllContacts = nil
    end)
    suggestionMenu:Hide()
    frame.suggestionButtons = {}

    for i = 1, 6 do
        local button = CreateFrame("Button", nil, suggestionMenu)
        frame.suggestionButtons[i] = button
        button:SetHeight(32)
        button:SetPoint("TOPLEFT", suggestionMenu, "TOPLEFT", 5, -4 - (i - 1) * 34)
        button:SetPoint("RIGHT", suggestionMenu, "RIGHT", -5, 0)
        -- Selection wash is the same rounded pill every menu row wears, sitting
        -- between the menu fill and the row's regions (lift the row so a band
        -- exists for it; equal level = the parent fill wins).
        if button:GetFrameLevel() <= suggestionMenu:GetFrameLevel() + 1 then
            button:SetFrameLevel(suggestionMenu:GetFrameLevel() + 2)
        end
        button.bg = CreateFrame("Frame", nil, button)
        button.bg:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button.bg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        button.bg:SetFrameLevel(button:GetFrameLevel() - 1)
        ns.CreateRoundedRectBorder(button.bg)
        ns.SetRoundedRectBorderShown(button.bg, true)
        ns.SetRoundedRectRingShown(button.bg, false)
        ns.SetRoundedRectBarHeight(button.bg, 22)
        PaintChatSuggestionSelection(button.bg)
        button.bg:Hide()
        button.initialBg = CreateFrame("Frame", nil, button)
        button.initialBg:SetSize(22, 22)
        button.initialBg:SetPoint("LEFT", button, "LEFT", 8, 0)
        ns.CreateRoundedRectBorder(button.initialBg)
        ns.SetRoundedRectBarHeight(button.initialBg, 22)
        ns.SetRoundedRectBorderBgAlpha(button.initialBg, 1)
        ns.SetRoundedRectBorderEdgeShown(button.initialBg, false)
        PaintChatSurface(button.initialBg, "chip", 1)
        button.initial = button.initialBg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        button.initial:SetPoint("CENTER", button.initialBg, "CENTER", 0, 0)
        button.initial:SetTextColor(1, 1, 1, 1)
        -- Row colors are owned by RefreshChatSuggestionSelection (selection gold
        -- vs theme text) and the online/offline subtext grays; the menu-wide
        -- retint must not repaint them.
        button.initial._efOwnColor = true
        if button.initial.SetDrawLayer then button.initial:SetDrawLayer("OVERLAY", 7) end
        button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.text._efOwnColor = true
        button.text:SetPoint("TOPLEFT", button.initialBg, "TOPRIGHT", 8, -2)
        button.text:SetPoint("RIGHT", button, "RIGHT", -8, 0)
        button.text:SetJustifyH("LEFT")
        button.text:SetWordWrap(false)
        if button.text.SetMaxLines then button.text:SetMaxLines(1) end
        button.subtext = button:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        button.subtext._efOwnColor = true
        button.subtext:SetPoint("TOPLEFT", button.text, "BOTTOMLEFT", 0, -1)
        button.subtext:SetPoint("RIGHT", button, "RIGHT", -8, 0)
        button.subtext:SetJustifyH("LEFT")
        button.subtext:SetWordWrap(false)
        if button.subtext.SetMaxLines then button.subtext:SetMaxLines(1) end
        button:SetScript("OnEnter", function(self)
            UI._chatComposer.suggestionIndex = i
            UI:RefreshChatSuggestionSelection()
        end)
        button:SetScript("OnClick", function(self)
            if not self.entry then return end
            -- Consume through the shared recipient machine so the ACTIVE To:
            -- box (compose or messenger in-place) is the one cleared and
            -- refocused; clearing targetEdit here left the typed text behind
            -- in the messenger's field.
            UI._chatComposer.suggestionIndex = i
            UI:ConsumeChatRecipientInput(true)
            suggestionMenu:Hide()
            local activeEdit = UI:GetActiveRecipientContext()
            if activeEdit then activeEdit:SetFocus() end
        end)
        button:Hide()
    end

    frame:SetScript("OnHide", function()
        UI._chatComposer.newSince = nil
        UI:SaveCurrentChatReplyDraft()
        UI:DropEmptyFlipConversation(UI._chatComposer.selectedConversationKey)
        UI._chatComposer.showAllContacts = nil
        UI._chatComposer.sidebarResizing = nil
        UI:HideChatSidebarResizeCursor()
        if frame.messengerView and frame.messengerView.sidebarResizeHandle then
            Utils.SafeOnUpdate(frame.messengerView.sidebarResizeHandle, nil)
            if frame.messengerView.sidebarResizeHandle.line then
                frame.messengerView.sidebarResizeHandle.line:Hide()
            end
        end
        channelMenu:Hide()
        suggestionMenu:Hide()
    end)

    -- ESC closes the chat window when nothing has keyboard focus, through
    -- EasyFind's own ESC dispatch (never UISpecialFrames, which the game
    -- walks): menus first, then the window, if the setting (off by default)
    -- lets it. An open game window (talents, a bag) takes ESC first.
    local function MenuOpen() return channelMenu:IsShown() or suggestionMenu:IsShown() end
    Utils.AttachEscClose(frame, function()
        if channelMenu:IsShown() then channelMenu:Hide() return true end
        if suggestionMenu:IsShown() then suggestionMenu:Hide() return true end
        if ChatDB().escCloses ~= true then return false end
        frame:Hide()
        return true
    end, function() return ChatDB().escCloses == true or MenuOpen() end, { yields = true })
    frame:HookScript("OnShow", function() UI:SyncChatButtonHidden() end)
    frame:HookScript("OnHide", function() UI:SyncChatButtonHidden() end)
    -- The clock ticks only while the window shows.
    frame:HookScript("OnShow", function() UI:LayoutChatClock(frame) end)
    frame:HookScript("OnHide", function() UI:LayoutChatClock(frame) end)
    frame:HookScript("OnSizeChanged", function()
        UI:LayoutChatClock(frame)
        UI:ReclipChatTitleText(frame)
    end)

    ns.RegisterThemeCallback(RefreshChatTheme)

    frame.composeElements = {
        backButton,
        chatLabel,
        channelButton,
        targetLabel,
        targetPanel,
        messageLabel,
        messageShell,
        footer,
    }
    self:CreateChatMessengerView(frame)
    self:InstallChatFontScaleWheel(frame)
    self:InstallChatFontScaleWheel(close)
    self:InstallChatFontScaleWheel(backButton)
    self:InstallChatFontScaleWheel(channelButton)
    self:InstallChatFontScaleWheel(targetShell)
    self:InstallChatFontScaleWheel(targetEdit)
    self:InstallChatFontScaleWheel(targetDropdown)
    self:InstallChatFontScaleWheel(messageShell)
    self:InstallChatFontScaleWheel(messageEdit)
    self:InstallChatFontScaleWheel(footer)
    self:InstallChatFontScaleWheel(sendButton)
    self:InstallChatFontScaleWheel(channelMenu)
    self:InstallChatFontScaleWheel(suggestionMenu)
    for _, box in ipairs({ targetEdit, messageEdit }) do
        box:HookScript("OnKeyDown", function(b, key) UI:ArmChatHoveredCopy(b, key) end)
    end
    self:RegisterChatFrameFonts(frame)
    self:InstallChatKeyCatcher(frame)
    self:ApplyChatFontScale()
    self:RefreshChatComposerChannel()
    self:RefreshChatComposerRecipients()
    frame:Hide()
    return frame
end

function UI:OpenChatComposer()
    self:CloseSearchForChatComposer()
    local frame = self:EnsureChatComposerFrame()
    frame:ClearAllPoints()
    local center = ChatDB().windowCenter
    if type(center) == "table" and tonumber(center[1]) and tonumber(center[2]) then
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", center[1], center[2])
    else
        frame:SetPoint("CENTER")
    end
    frame:Show()
    frame:Raise()
    self:RefreshChatFriendEntries()
    self:SetChatComposerStatus("")
    self:ShowChatMessengerView()
    if Utils.SafeAfter then
        Utils.SafeAfter(0.25, function()
            if frame:IsShown() then
                UI:RefreshChatFriendEntries()
                UI:RefreshChatMessenger()
            end
        end)
    end
    return true
end


function chatNS:Open(initialChannel)
    if initialChannel and UI._chatComposer then
        UI._chatComposer.channel = initialChannel
        UI:OpenChatComposer()
        UI:ShowChatComposeView()
        return true
    end
    return UI:OpenChatComposer()
end

function chatNS:Close()
    local frame = UI._chatComposer and UI._chatComposer.frame
    if frame then frame:Hide() end
end

function chatNS:IsOpen()
    local frame = UI._chatComposer and UI._chatComposer.frame
    return frame ~= nil and frame:IsShown()
end

-- The threads as the sidebar lists them: key and label, for the bar's
-- Send menu.
function chatNS:ListConversations()
    local store = UI:GetChatConversationStore()
    local out = {}
    for _, key in ipairs(store.order) do
        local convo = store.byKey[key]
        if convo then
            out[#out + 1] = { key = key, label = UI:GetChatConversationPlainLabel(convo, key) }
        end
    end
    return out
end

-- The bar's rows: every thread, and every message in it when the filter's
-- Messages switch is on, found by the words or the name; a row opens the
-- thread at that message.
function chatNS:BuildSearchData()
    local store = UI:GetChatConversationStore()
    local out = {}
    local slower = string.lower
    local db = ChatDB()
    local threads, withMessages = db.findChats ~= false, db.findMessages == true
    for _, key in ipairs(store.order) do
        local convo = store.byKey[key]
        if convo then
            local label = UI:GetChatConversationPlainLabel(convo, key)
            local last = convo.lastMessage and UI:TrimChatQuotedText(convo.lastMessage, 60) or nil
            if threads then
                out[#out + 1] = {
                    name = label, nameLower = slower(label), category = "Chat",
                    keywordsLower = { "chat", "conversation", "whisper", last and slower(last) or "" },
                    searchCommandDesc = last,
                    icon = chatNS.ICON_TEX, chatKey = key,
                }
            end
            local messages = withMessages and convo.messages or {}
            for i = 1, #messages do
                local msg = messages[i]
                local text = UI:TrimChatQuotedText(UI:GetChatMessageDisplayText(msg), 90)
                if text ~= "" then
                    local sender = UI:GetPlainChatLabel(msg.senderLabel or "")
                    out[#out + 1] = {
                        name = text, nameLower = slower(text), category = "Chat",
                        keywordsLower = { "chat", "message", slower(label), slower(sender) },
                        searchCommandDesc = (sender ~= "" and (sender .. ", ") or "") .. UI:FormatChatConversationTime(msg.time),
                        icon = chatNS.ICON_TEX, chatKey = key, chatMessageIndex = i,
                    }
                end
            end
        end
    end
    return out
end

-- The messenger at a thread; with a message index, scrolled to that
-- message once the rows have their places.
-- The message a search result opened: its bubble pulses twice in the accent
-- (lighter on the accent bubbles), so the eye lands on it. A pooled row that
-- moved on to another message stops pulsing.
function UI:FlashChatMessageRow(row, msg)
    local token = (row._flashToken or 0) + 1
    row._flashToken = token
    local function Step(i)
        if row._flashToken ~= token or row.message ~= msg or not row:IsShown() then return end
        if i % 2 == 1 then
            local r, g, b = ChatAccentColor()
            if row._chatPaint == "accent" then r, g, b = mmin(r + 0.22, 1), mmin(g + 0.22, 1), mmin(b + 0.22, 1) end
            ns.SetRoundedRectFill(row, r, g, b, 1, true)
        else
            PaintChatRowRest(row)
        end
        if i < 4 then Utils.SafeAfter(0.28, function() Step(i + 1) end) end
    end
    Step(1)
end

function chatNS:OpenConversation(key, messageIndex)
    UI:OpenChatComposer()
    UI:SelectChatConversation(key)
    local store = UI:GetChatConversationStore()
    local convo = store.byKey[key]
    local msg = convo and convo.messages and messageIndex and convo.messages[messageIndex]
    if not msg then return true end
    Utils.SafeAfter(0, function()
        local frame = UI._chatComposer.frame
        local view = frame and frame.messengerView
        if not (view and view.messageScroll and view.messageChild and view.messageRows) then return end
        for _, row in ipairs(view.messageRows) do
            local childTop, rowTop = view.messageChild:GetTop(), row:GetTop()
            if row.message == msg and childTop and rowTop then
                local most = math.max(0, (view.messageChild:GetHeight() or 0) - (view.messageScroll:GetHeight() or 0))
                view.messageScroll:SetVerticalScroll(math.max(0, math.min(most, childTop - rowTop - 24)))
                UI:UpdateChatMessageScrollBar()
                UI:FlashChatMessageRow(row, msg)
                break
            end
        end
    end)
    return true
end

-- Words put into a thread's reply box, or into a fresh composer when no
-- thread is named: the bar's results come here.
function chatNS:ComposeWith(key, text)
    text = tostring(text or "")
    UI:OpenChatComposer()
    if key then
        UI:SelectChatConversation(key)
        local frame = UI._chatComposer.frame
        local box = frame and frame.messengerView and frame.messengerView.replyEditBox
        if box then
            box:SetText(text)
            box:SetCursorPosition(#text)
            UI:FocusChatEditBox(box)
        end
    else
        UI:ShowChatComposeView(true)
        local frame = UI._chatComposer.frame
        if frame and frame.messageEditBox then
            frame.messageEditBox:SetText(text)
            frame.messageEditBox:SetCursorPosition(#text)
        end
    end
    return true
end

-- Retention and schema run once, at load, before any conversation is read.
-- Purging on write would put this work in the path of every incoming
-- whisper, which is the one place it must never be.
if chatNS.Store then
    chatNS.Store:Init()
end

-- Messages are heard from load on; nothing waits on an event to record.
UI:RegisterChatComposerEvents()

-- Saved chats load after these files run: the channel switch, the badge
-- and the takeover read them once they are in. EasyFind loads this addon
-- inside its own ADDON_LOADED, whose nested one for us never arrives:
-- login, or the next frame of a load after it, sets up too. Once.
local setupDone
local function Setup()
    if setupDone then return end
    setupDone = true
    -- Its search switches were EasyFind's while it came inside EasyFind.
    local old, db = EasyFind.db, ChatDB()
    if old and db.findChats == nil and old.chatFindChats == false then db.findChats = false end
    if old and db.findMessages == nil and old.chatFindMessages == true then db.findMessages = true end
    UI:SetChatChannelRecording(UI:IsChatChannelRecording())
    UI:UpdateChatUnreadBadge()
    UI:ApplyChatTakeover(true)
    UI:DropEmptyFlipConversations()
end

local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:RegisterEvent("PLAYER_LOGIN")
loadFrame:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON then return end
        self:UnregisterEvent(event)
        Setup()
        if IsLoggedIn() then UI:OpenChatTakeover() end
        return
    end
    self:UnregisterAllEvents()
    Setup()
    UI:OpenChatTakeover()
end)
if IsLoggedIn() then
    C_Timer.After(0, function()
        Setup()
        UI:OpenChatTakeover()
    end)
end

-- Presence changes redraw the header's disc; the guild roster is asked
-- for once, so its updates come for the rest of the session.
local presenceFrame = CreateFrame("Frame")
for _, event in ipairs({ "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE",
                         "BN_FRIEND_ACCOUNT_OFFLINE", "BN_FRIEND_LIST_SIZE_CHANGED", "BN_CONNECTED",
                         "BN_DISCONNECTED", "GUILD_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do
    Utils.RegisterEventIfValid(presenceFrame, event)
end
presenceFrame:SetScript("OnEvent", function(_, event)
    -- Friends by BattleTag: the list's order moved.
    if event ~= "FRIENDLIST_UPDATE" and event ~= "GUILD_ROSTER_UPDATE" and event ~= "BN_FRIEND_INFO_CHANGED" then
        UI._chatComposer.bnFriendIndex = nil
    end
    if event == "PLAYER_ENTERING_WORLD" then
        local ask = C_GuildInfo and C_GuildInfo.GuildRoster or GuildRoster
        if ask and IsInGuild and IsInGuild() then xpcall(ask, Utils.ErrorHandler) end
        -- The character is known now: the badge counts this character's chats.
        UI:UpdateChatUnreadBadge()
        return
    end
    if event == "GUILD_ROSTER_UPDATE" then UI:ReadChatGuildPresence() end
    xpcall(UI.RefreshChatPresence, Utils.ErrorHandler, UI)
end)

if ns.RowCopy and ns.RowCopy.RegisterHoverScanner then
    ns.RowCopy:RegisterHoverScanner(function() return UI:GetChatHoveredMessageRow() end)
end

-- The takeover: the keys bound to the game's Open Chat open this line
-- instead, an override kept while it is on (out of combat).
local lineKeysOwner = CreateFrame("Frame")
local lineButton = CreateFrame("Button", "EasyFindChatOpenLineButton", UIParent)
lineButton:Hide()
lineButton:RegisterForClicks("AnyDown", "AnyUp")
local lineDown
lineButton:SetScript("OnClick", function(_, _, down)
    -- On the press; on the release only when no press came through.
    if down or not lineDown then UI:OpenChatLine() end
    lineDown = down
end)
-- Set again whenever a key is not ours: the game's bindings load after
-- this, and an override set before they do was gone after a reload.
local function ApplyChatLineKeys()
    if InCombatLockdown() then
        lineKeysOwner:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    local keys = ChatDB().takeover == true and { GetBindingKey("OPENCHAT") } or {}
    local ours = true
    for i = 1, #keys do
        local action = GetBindingAction and GetBindingAction(keys[i], true)
        if not (type(action) == "string" and action:find("EasyFindChatOpenLineButton", 1, true)) then ours = false end
    end
    if ours and #keys > 0 then return end
    ClearOverrideBindings(lineKeysOwner)
    for i = 1, #keys do
        SetOverrideBindingClick(lineKeysOwner, false, keys[i], "EasyFindChatOpenLineButton")
    end
end
lineKeysOwner:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then self:UnregisterEvent(event) end
    ApplyChatLineKeys()
end)

function UI:SetChatInputStyle(style)
    if style == "enter" and ChatDB().takeover ~= true then return end
    ChatDB().inputStyle = style ~= "full" and style or nil
    UI._chatComposer.lineOpen = nil
    ApplyChatLineKeys()
    self:RefreshChatMessenger()
end

-- The takeover: the game's chat hidden (EasyFind's Toggle Chat Frame) and
-- this window open at login. A login with it off leaves the game's chat as
-- it was; turning it off shows it again.
function UI:ApplyChatTakeover(atLogin)
    local on = ChatDB().takeover == true
    local hidden = EasyFind.db and EasyFind.db.chatFramesHidden == true
    if EasyFind.db and on ~= hidden and (on or not atLogin) then EasyFind:ToggleChatFrames() end
    if not on and chatNS.Views then chatNS.Views:SettleCombatLog() end
    lineKeysOwner:RegisterEvent("UPDATE_BINDINGS")
    lineKeysOwner:RegisterEvent("PLAYER_ENTERING_WORLD")
    ApplyChatLineKeys()
    if chatNS.GameLine then chatNS.GameLine:Apply(on) end
end

function UI:OpenChatTakeover()
    if ChatDB().takeover == true and not chatNS:IsOpen() then chatNS:Open() end
end

function UI:SetChatTakeover(on)
    ChatDB().takeover = on or nil
    if not on and ChatDB().inputStyle == "enter" then ChatDB().inputStyle = nil end
    UI._chatComposer.lineOpen = nil
    self:ApplyChatTakeover(false)
    self:OpenChatTakeover()
    self:RefreshChatMessenger()
end

-- Extensions > Chat as data, in page order: the page's controls and the
-- search bar's rows both read it. Cheap: no frames, no loads.
local function ChatSettingsRows()
    local OffOrNil = ns.Utils.OffOrNil
    local function Percent(scale) return math.floor(scale * 100 + 0.5) end
    local function Check(name, get, set, tooltip)
        return { name = name, control = { kind = "check", get = get, set = set, tooltip = tooltip } }
    end
    local function Choice(name, choices, get, set, tooltip, default)
        return { name = name, control = { kind = "choice", choices = choices, get = get, set = set,
            tooltip = tooltip, default = default } }
    end
    local rows = {
        Check("Use as the game's chat",
            function() return ChatDB().takeover == true end,
            function(on) UI:SetChatTakeover(on) end,
            "Hides the game's chat windows and opens this one at every login."),
        Check("Keep the game's channels",
            function() return UI:IsChatChannelRecording() end,
            function(on) UI:SetChatChannelRecording(on) end,
            "Each numbered channel gets a conversation, kept by the limits below."),
        Check("Show the All chat",
            function() return ChatDB().showAll ~= false end,
            function(on)
                ChatDB().showAll = OffOrNil(on)
                UI:RefreshChatMessenger()
            end,
            "A chat at the top of the list with every chat's messages in time order."),
        Check("Show the Combat Log entry",
            function() return ChatDB().showCombatLog ~= false end,
            function(on)
                ChatDB().showCombatLog = OffOrNil(on)
                UI:RefreshChatMessenger()
            end,
            "The game's own combat log, shown in this window while picked."),
        Check("Color names by class",
            function() return ChatDB().classColors ~= false end,
            function(on)
                ChatDB().classColors = OffOrNil(on)
                UI:RefreshChatMessenger()
            end,
            "A player's name takes their class color once the game has told us the class."),
        Check("Mute Say, Yell, channels",
            function() return ChatDB().mutePublicRooms ~= false end,
            function(on)
                ChatDB().mutePublicRooms = OffOrNil(on)
                UI:UpdateChatUnreadBadge()
                UI:RefreshChatMessenger()
            end,
            "Their new messages count in the list but not on the chat icon. Right-click a chat to change it alone."),
        Check("Mute group and guild chat",
            function() return ChatDB().muteGroups ~= false end,
            function(on)
                ChatDB().muteGroups = OffOrNil(on)
                UI:UpdateChatUnreadBadge()
                UI:RefreshChatMessenger()
            end,
            "Off, party, raid and guild messages count on the chat icon and play the message sound."),
        Check("Close chat with Esc",
            function() return ChatDB().escCloses == true end,
            function(on)
                ChatDB().escCloses = on or nil
                if Utils.RefreshEscArm then Utils.RefreshEscArm() end
            end,
            "Off, Esc leaves the window open. Its X and its button still close it."),
        Check("Hide button while open",
            function() return ChatDB().hideButtonWhileOpen == true end,
            function(on)
                ChatDB().hideButtonWhileOpen = on or nil
                UI:SyncChatButtonHidden()
            end,
            "The chat's extension button steps aside while the window shows."),
        Check("Unread count on button",
            function() return ChatDB().showBadge ~= false end,
            function(on)
                ChatDB().showBadge = OffOrNil(on)
                UI:UpdateChatUnreadBadge()
            end,
            "The red count on the chat button. Off, the button never shows one."),
        Check("Name and type on one line",
            function() return ChatDB().headerOneLine == true end,
            function(on)
                ChatDB().headerOneLine = on or nil
                UI:LayoutChatMessengerChrome()
                UI:RefreshChatMessenger()
            end,
            "The header shows \"General: Channel\" on a single line, for a shorter header."),
        Choice("Conversation in the title bar", {
                { label = _G["OFF"] or "Off", value = "off" },
                { label = "When folded", value = "folded" },
                { label = "Always", value = "always" },
            },
            function() return UI:GetChatConversationInTitle() or "off" end,
            function(v)
                ChatDB().headerInTitle = v ~= "off" and v or nil
                UI:RefreshChatMessenger()
            end,
            "The title bar names the open conversation, folded or always."
                .. " Always, it replaces EasyChat and the header, leaving more room for messages.", "off"),
        Check("Away and failed whispers",
            function() return UI:ShowsChatDeliveryNotices() end,
            function(on)
                ChatDB().deliveryNotices = OffOrNil(on)
                UI:RefreshChatMessenger()
            end,
            "A whisper's away or busy reply shows in its chat, and a whisper that never arrived says so."),
        Check("Highlight my name",
            function() return UI:ShowsChatMentions() end,
            function(on)
                ChatDB().mentions = OffOrNil(on)
                UI:UpdateChatUnreadBadge()
                UI:RefreshChatMessenger()
            end,
            "In a group or channel, a message with your name stands out, and counts and sounds even when the chat is muted."),
        Check("Drafts in the chat list",
            function() return UI:ShowsChatDrafts() end,
            function(on)
                ChatDB().showDrafts = OffOrNil(on)
                UI:RefreshChatMessenger()
            end,
            "A chat with a message you have not sent yet shows it in the list as a draft."),
        Check("Pinned messages",
            function() return ChatDB().pins ~= false end,
            function(on)
                ChatDB().pins = OffOrNil(on)
                UI:RefreshChatMessenger()
            end,
            "Right-click a message to pin it. The pin in the chat's header lists them, each with Jump."),
        Check("Avatars beside messages",
            function() return UI:ShowsChatMessageAvatars() end,
            function(on)
                ChatDB().messageAvatars = on or nil
                UI:RefreshChatMessenger()
            end,
            "In groups, channels and All, each speaker's avatar sits beside their messages."),
        Check("Class icons for players",
            function() return ChatDB().classIcons == true end,
            function(on)
                ChatDB().classIcons = on or nil
                UI:RefreshChatMessenger()
            end,
            "A player's avatar shows their class until you pick an icon for them."),
        Check("Random icons for chats",
            function() return ChatDB().randomIcons == true end,
            function(on)
                ChatDB().randomIcons = on or nil
                UI:RefreshChatMessenger()
            end,
            "Each chat without a picked icon gets a random one, kept as its own."),
        Check("New messages divider",
            function() return UI:ShowsChatNewDivider() end,
            function(on)
                ChatDB().newDivider = OffOrNil(on)
                UI:RefreshChatMessenger()
            end,
            "Opening a chat with unread messages, a red line marks where they start."),
        Check("Jump to newest button",
            function() return UI:ShowsChatNewestButton() end,
            function(on)
                ChatDB().newestButton = OffOrNil(on)
                UI:RefreshChatMessenger()
            end,
            "Scrolled up, a button takes you back to the newest message and counts new ones."),
        Check("Web links",
            function() return UI:ShowsChatWebLinks() end,
            function(on)
                ChatDB().webLinks = OffOrNil(on)
                UI:RefreshChatMessenger()
            end,
            "Web addresses in messages show as links. Click one to copy it."),
        Check("Clock in the title bar",
            function() return ChatDB().showClock ~= false end,
            function(on)
                ChatDB().showClock = OffOrNil(on)
                local frame = UI._chatComposer.frame
                if frame then UI:ApplyChatTitleFold(frame) end
                UI:RefreshChatMessenger()
            end,
            "The time of day beside the title bar's arrow."),
        Check("Names before their words",
            function() return ChatDB().inlineSender ~= false end,
            function(on)
                ChatDB().inlineSender = OffOrNil(on)
                UI:RefreshChatMessenger()
            end,
            "In channels a message reads \"Name: words\" on one line, not with the name above it."),
        Choice("Chat style", {
                { label = "Full", value = "full" },
                { label = "Compact", value = "compact" },
                { label = "Hidden until Enter", value = "enter",
                    disabled = function() return ChatDB().takeover ~= true end },
            },
            function() return UI:GetChatInputStyle() end,
            function(v) UI:SetChatInputStyle(v) end,
            "Full has Send and a count beside the box, Compact is one line."
                .. " Hidden until Enter needs Use as the game's chat.", "full"),
        Choice("Window border", {
                { label = _G["OFF"] or "Off", value = "off" },
                { label = ns.L["GPS_BORDER_LINE"], value = "line" },
                { label = ns.L["GPS_BORDER_IRON"], value = "iron",
                    disabled = function() return not (ns.ThemeHasChrome and ns.ThemeHasChrome()) end },
            },
            function() return UI:GetChatWindowBorder() end,
            function(v)
                ChatDB().windowBorder = v ~= "iron" and v or nil
                UI:ApplyChatWindowLook()
            end,
            "Iron border is the Classic and Forever themes' own frame.", "iron"),
        Choice("Message times", {
                { label = "Inside the bubble", value = "inside" },
                { label = "Beside the bubble", value = "beside" },
                { label = "On hover", value = "hover" },
                { label = "In a tooltip", value = "tooltip" },
            },
            function() return ChatDB().timePlacement or "beside" end,
            function(v)
                ChatDB().timePlacement = v ~= "beside" and v or nil
                UI:RefreshChatMessenger()
            end,
            "Where each message shows when it was sent.", "beside"),
    }
    local soundChoices = {}
    for _, s in ipairs(UI.CHAT_SOUNDS) do soundChoices[#soundChoices + 1] = { label = s.label, value = s.key } end
    rows[#rows + 1] = Choice("Message sound", soundChoices,
        function() return ChatDB().messageSound or "none" end,
        function(v)
            ChatDB().messageSound = v ~= "none" and v or nil
            UI:PlayChatSoundKey(v)
        end,
        "Plays for new messages in chats that are not muted.", "none")
    local fontChoices = { { label = "Same as EasyFind", value = "inherit" } }
    for _, name in ipairs(ns.FONT_CHOICES or {}) do
        fontChoices[#fontChoices + 1] = { label = name == "Default" and (_G["DEFAULT"] or "Default") or name, value = name }
    end
    rows[#rows + 1] = Choice("Font", fontChoices,
        function() return ChatDB().font or "inherit" end,
        function(v)
            ChatDB().font = v ~= "inherit" and v or nil
            UI:ApplyChatFontScale()
        end,
        "The typeface of the chat window's text.", "inherit")
    rows[#rows + 1] = { name = "Text size (%)", control = { kind = "slider",
        min = Percent(CHAT_FONT_SCALE_MIN), max = Percent(CHAT_FONT_SCALE_MAX), step = Percent(CHAT_FONT_SCALE_STEP),
        get = function() return Percent(UI:GetChatFontScale()) end,
        set = function(v) UI:SetChatFontScale(v / 100) end,
        tooltip = "Ctrl and + or - in the chat window step it too." } }
    rows[#rows + 1] = { name = "Header text size (%)", control = { kind = "slider",
        min = Percent(CHAT_FONT_SCALE_MIN), max = Percent(CHAT_FONT_SCALE_MAX), step = Percent(CHAT_FONT_SCALE_STEP),
        get = function() return Percent(UI:GetChatHeaderFontScale()) end,
        set = function(v) UI:SetChatHeaderFontScale(v / 100) end,
        tooltip = "The open chat's name, in the header or the title bar. It follows Text size until you change it." } }
    local retention = GetChatRetentionSettings()
    if not retention then return rows end
    local dayChoices = {}
    for _, d in ipairs({ 7, 30, 60, 90 }) do dayChoices[#dayChoices + 1] = { label = d .. " days", value = d } end
    dayChoices[#dayChoices + 1] = { label = "Forever", value = 0 }
    rows[#rows + 1] = Choice("Keep messages for", dayChoices,
        function() return tonumber(retention.retentionDays) or 60 end,
        function(v) retention.retentionDays = v end,
        "Older messages go at the next login.", 60)
    local countChoices = {}
    for _, n in ipairs({ 100, 200, 400, 1000 }) do
        countChoices[#countChoices + 1] = { label = tostring(n), value = n }
    end
    rows[#rows + 1] = Choice("Messages per conversation", countChoices,
        function() return tonumber(retention.maxMessagesPerConversation) or 400 end,
        function(v) retention.maxMessagesPerConversation = v end,
        "The oldest go first once a conversation is full.", 400)
    return rows
end

-- The page: the switches in two columns, the choices full-width below.
local function BuildChatSettingsPage(page, kit)
    local hint = kit.Title(page, ns.L["APP_CHAT"] or "Chat",
        "Whispers, Say, Party, Raid, Guild and the rest keep a conversation each.")
    local row = {}
    for _, r in ipairs(ChatSettingsRows()) do row[r.name] = r.control end
    local function Choice(name)
        local c = row[name]
        return kit.Choice(page, name, c.choices, c.get, c.set, c.tooltip, c.default)
    end
    -- The switches in two columns across the page (one where the kit has
    -- no row width yet), the choices full-width under the left column.
    local width = page:GetParent() and page:GetParent():GetWidth() or 0
    if width < 1 then width = kit.ROW_WIDTH end
    local colW = (EasyFind.API.MINOR or 0) >= 3 and math.floor((width - 16) / 2) or nil
    local names = { "Use as the game's chat", "Keep the game's channels", "Show the All chat",
        "Show the Combat Log entry", "Color names by class", "Mute Say, Yell, channels", "Close chat with Esc",
        "Hide button while open", "Unread count on button", "Name and type on one line", "Clock in the title bar",
        "Names before their words", "Away and failed whispers", "Highlight my name", "Drafts in the chat list",
        "Pinned messages", "Avatars beside messages", "Class icons for players", "Random icons for chats",
        "New messages divider", "Jump to newest button", "Web links" }
    local boxes, leftLast = {}, nil
    for i, name in ipairs(names) do
        local c = row[name]
        local box = kit.Checkbox(page, name, c.get, c.set, c.tooltip, colW)
        if i == 1 then
            box:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
        elseif colW and i % 2 == 0 then
            box:SetPoint("TOPLEFT", boxes[i - 1], "TOPLEFT", colW + 8, 0)
        else
            box:SetPoint("TOPLEFT", colW and boxes[i - 2] or boxes[i - 1], "BOTTOMLEFT", 0, 0)
        end
        boxes[i] = box
        if not colW or i % 2 == 1 then leftLast = box end
    end
    local takeover = boxes[1]
    local times = Choice("Message times")
    local inTitle = Choice("Conversation in the title bar")
    inTitle:SetPoint("TOPLEFT", leftLast, "BOTTOMLEFT", -8, -8)
    local style = Choice("Chat style")
    style:SetPoint("TOPLEFT", inTitle, "BOTTOMLEFT", 0, -4)
    -- Turning the takeover off takes Hidden until Enter with it.
    takeover:HookScript("OnClick", function() style:SetValue(UI:GetChatInputStyle()) end)
    local border = Choice("Window border")
    border:SetPoint("TOPLEFT", style, "BOTTOMLEFT", 0, -4)
    times:SetPoint("TOPLEFT", border, "BOTTOMLEFT", 0, -4)
    local sound = Choice("Message sound")
    sound:SetPoint("TOPLEFT", times, "BOTTOMLEFT", 0, -4)
    local font = Choice("Font")
    font:SetPoint("TOPLEFT", sound, "BOTTOMLEFT", 0, -4)
    local sz = row["Text size (%)"]
    local size = kit.Stepper(page, "Text size (%)", sz.min, sz.max, sz.step, sz.get, sz.set, sz.tooltip,
        font:GetWidth())
    size:SetPoint("TOPLEFT", font, "BOTTOMLEFT", 0, -4)
    UI._chatComposer.textSizeRow = size
    local hs = row["Header text size (%)"]
    local headerSize = kit.Stepper(page, "Header text size (%)", hs.min, hs.max, hs.step, hs.get, hs.set, hs.tooltip,
        font:GetWidth())
    headerSize:SetPoint("TOPLEFT", size, "BOTTOMLEFT", 0, -4)
    UI._chatComposer.headerSizeRow = headerSize
    if not row["Keep messages for"] then return end
    local days = Choice("Keep messages for")
    days:SetPoint("TOPLEFT", headerSize, "BOTTOMLEFT", 0, -4)
    local count = Choice("Messages per conversation")
    count:SetPoint("TOPLEFT", days, "BOTTOMLEFT", 0, -4)
end

EasyFind.API.RegisterExtension({ id = "chat", settings = BuildChatSettingsPage, settingsRows = ChatSettingsRows,
    resetSettings = function() UI:ResetChatSettings() end })
