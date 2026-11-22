local _, chatNS = ...

local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not (ns and ns.Utils) or chatNS.tooOld then return end

-- The list's own entries over the chats: All (every chat's lines in time
-- order), and in a Game folder System (the game's lines that are not
-- chat) and Combat Log (the game's own window, shown in ours while chosen;
-- nothing of it is kept).
local Views = {}
chatNS.Views = Views

local UI = chatNS.UI
local Utils = ns.Utils
local time, GetTime = time, GetTime
local tremove, tsort, wipe = table.remove, table.sort, wipe
local issecretvalue = _G.issecretvalue

local ALL, SYSTEM, COMBAT, GAME = "view:all", "view:system", "view:combat", "view:game"
local CHANNELS = "view:channels"
Views.ALL, Views.SYSTEM, Views.COMBAT, Views.GAME, Views.CHANNELS = ALL, SYSTEM, COMBAT, GAME, CHANNELS

-- All holds the newest this many lines.
local ALL_MAX = 1000

local function ChatDB()
    EasyFindChatDB = type(EasyFindChatDB) == "table" and EasyFindChatDB or {}
    return EasyFindChatDB
end

-- Each entry's icon, kept on its own.
local function ViewIcons()
    local db = ChatDB()
    db.viewIcons = type(db.viewIcons) == "table" and db.viewIcons or {}
    return db.viewIcons
end

function Views:SetIcon(key, icon)
    ViewIcons()[key] = icon
end

local all = { key = ALL, kind = "all", label = "All", source = "Every chat", messages = {} }
local combat = { key = COMBAT, kind = "combat", label = "Combat Log", source = "The game's combat log" }

-- Kept with the chats, outside their list: never sorted, capped or deleted.
local function SystemConvo()
    local store = UI:GetChatConversationStore()
    local sys = type(store.system) == "table" and store.system or {}
    store.system = sys
    if type(sys.messages) ~= "table" then sys.messages = {} end
    sys.key, sys.kind, sys.label, sys.source = SYSTEM, "system", "System", "Game messages"
    return sys
end

-- System and Combat Log as one unit, opening beside the list as a
-- folder does; the numbered channels in no folder likewise.
local gameFolder = { name = "Game" }
local channelsFolder = { name = "Channels" }

function Views:Folder(fid)
    if fid == GAME then return gameFolder end
    return fid == CHANNELS and channelsFolder or nil
end

local function CombatLogListed()
    return ChatDB().showCombatLog ~= false and _G.COMBATLOG ~= nil
end

function Views:IsView(key)
    return key == ALL or key == SYSTEM or key == COMBAT
end

-- The game's chats as one group at the list's foot: All, the numbered
-- channels in no folder, System, the combat log.
function Views:BottomEntry(channels)
    local members = {}
    if ChatDB().showAll ~= false then members[#members + 1] = ALL end
    for i = 1, channels and #channels or 0 do members[#members + 1] = channels[i] end
    members[#members + 1] = SYSTEM
    if CombatLogListed() then members[#members + 1] = COMBAT end
    return { folder = GAME, members = members }
end

function Views:Selectable(key)
    if key == ALL then return ChatDB().showAll ~= false end
    if key == COMBAT then return CombatLogListed() end
    return key == SYSTEM
end

-- System and Combat Log are read only.
function Views:CanType(key)
    return key ~= SYSTEM and key ~= COMBAT
end

-- All's lines: each kept with the chat it came from.
local sourceOf = setmetatable({}, { __mode = "k" })
local cache = {}

function Views:SourceOf(msg)
    return msg and sourceOf[msg] or nil
end

local function Visible(msg, pick)
    return not pick or msg.char == nil or msg.char == pick
end

local function Shown(key, hidden)
    local group = hidden and key ~= SYSTEM and UI:GetChatFilterGroup(key)
    return not (group and hidden[group])
end

-- The character shown and the groups the list filter hides: a change of
-- either builds All again.
local function Sig(pick, hidden)
    local parts = {}
    for group in pairs(hidden or {}) do parts[#parts + 1] = group end
    tsort(parts)
    return tostring(pick) .. ":" .. table.concat(parts, ",")
end

-- Newest first from every chat's end, then turned: no sort of thousands.
local function Build(pick, hidden)
    local heads = {}
    local function Add(convo)
        local m = type(convo) == "table" and convo.messages
        if type(m) == "table" and #m > 0 then heads[#heads + 1] = { m, #m, convo } end
    end
    for key, convo in pairs(UI:GetChatConversationStore().byKey) do
        if Shown(key, hidden) then Add(convo) end
    end
    Add(SystemConvo())
    local newest = {}
    while #newest < ALL_MAX do
        local best, bestTime
        for i = 1, #heads do
            local h = heads[i]
            local m = h[1]
            while h[2] >= 1 and not Visible(m[h[2]], pick) do h[2] = h[2] - 1 end
            local msg = h[2] >= 1 and m[h[2]]
            if msg and (not bestTime or (msg.time or 0) > bestTime) then best, bestTime = h, msg.time or 0 end
        end
        if not best then break end
        local msg = best[1][best[2]]
        newest[#newest + 1] = msg
        sourceOf[msg] = best[3]
        best[2] = best[2] - 1
    end
    local list = {}
    for i = #newest, 1, -1 do list[#list + 1] = newest[i] end
    for i = 1, #heads do
        if heads[i][2] >= 1 then list.trimmed = true break end
    end
    return list
end

local function AllMessages()
    local pick = UI:GetChatCharacterView()
    local hidden = ChatDB().hiddenGroups
    local sig = Sig(pick, hidden)
    if not cache.list or cache.sig ~= sig then cache.list, cache.sig = Build(pick, hidden), sig end
    local last = cache.list[#cache.list]
    all.messages = cache.list
    all.lastMessage = last and (last.displayText or last.text) or nil
    all.lastTime = last and last.time or nil
    return cache.list
end

-- A chat deleted or merged: All is built again when next shown.
function Views:Forget()
    cache.list = nil
end

-- A new line anywhere: on All's end while it is built.
function Views:Heard(msg, convo)
    local list = cache.list
    if not (list and msg and convo) then return end
    if not Visible(msg, UI:GetChatCharacterView()) or not Shown(convo.key or "", ChatDB().hiddenGroups) then return end
    list[#list + 1] = msg
    sourceOf[msg] = convo
    local n = #list
    if n > ALL_MAX + 200 then
        local cut = n - ALL_MAX
        for i = cut + 1, n do list[i - cut] = list[i] end
        for i = n - cut + 1, n do list[i] = nil end
        list.trimmed = true
    end
    all.lastMessage, all.lastTime = msg.displayText or msg.text, msg.time
end

function Views:Get(key)
    local obj
    if key == ALL then
        AllMessages()
        obj = all
    elseif key == SYSTEM then
        obj = SystemConvo()
    elseif key == COMBAT then
        combat.lastMessage = "The game's own window"
        obj = combat
    else
        return nil
    end
    obj.icon = ViewIcons()[key]
    return obj
end

-- A line in All names where it came from, as the game's General tab does:
-- the room ("[Guild] Name"), or the person ("Name whispers", "To Name").
-- Returns the words before the name, the name, the words after, the name's
-- class and the whole name to copy.
function Views:AllMeta(msg)
    local src = sourceOf[msg]
    if not src or src.kind == "system" then return nil end
    local label = UI:GetChatConversationPlainLabel(src, src.key)
    if src.kind == "channel" then
        local tag = "[" .. label .. "]"
        if msg.outgoing then return tag end
        return tag .. " ", msg.senderLabel, nil, msg.senderClass, msg.senderName or msg.senderLabel
    end
    local class = msg.senderClass or src.class
    local full = src.targetName or label
    if msg.outgoing then return "To ", label, nil, class, full end
    return nil, msg.senderLabel ~= "" and msg.senderLabel or label, " whispers", class, full
end

-- Right-click: the icon, and Hide for the two a setting shows.
function Views:ShowMenu(key)
    local rows = { { text = "Change icon", onClick = function()
        if chatNS.Avatars then chatNS.Avatars:OpenPicker(key) end
    end } }
    local setting = (key == ALL and "showAll") or (key == COMBAT and "showCombatLog") or nil
    if setting then
        rows[#rows + 1] = { text = _G["HIDE"] or "Hide", onClick = function()
            ChatDB()[setting] = false
            UI:RefreshChatMessenger()
        end }
    end
    Utils.ShowCursorMenu("EasyFindChatConversationMenu", rows, {
        strata = "TOOLTIP", level = 100, rowHeight = 22, offsetX = 4, offsetY = -4,
    })
end

-- System: what the game's chat windows show that is not chat (its
-- replies, help, loot, money, skill, standing, notices, addon messages).
-- A chat line carries its event; these do not. One line shown in two
-- windows is kept once.
function Views:AddSystemLine(text)
    local sys = SystemConvo()
    local messages = sys.messages
    local msg = { text = text, outgoing = false, time = time(), char = UI:GetChatCharacterIndex() }
    messages[#messages + 1] = msg
    if msg.char then
        sys.chars = type(sys.chars) == "table" and sys.chars or {}
        sys.chars[msg.char] = true
    end
    sys.lastMessage, sys.lastTime = text, msg.time
    local retention = chatNS.Store and chatNS.Store:Settings()
    local max = retention and retention.maxMessagesPerConversation or 400
    while #messages > max do
        tremove(messages, 1)
        messages.trimmed = true
    end
    self:Heard(msg, sys)
    UI:QueueChatMessengerRefresh()
end

local seenAt, seenNow = nil, {}
-- A secret line (the client withholds some) is asked about before any
-- compare: comparing one errors.
local function OnChatLine(frame, text, _, _, _, _, _, _, event)
    if event ~= nil or frame == _G.COMBATLOG or type(text) ~= "string"
        or (issecretvalue and issecretvalue(text)) or text == "" then return end
    local now = GetTime()
    if now ~= seenAt then
        seenAt = now
        wipe(seenNow)
    end
    if seenNow[text] then return end
    seenNow[text] = true
    Views:AddSystemLine(text)
end

for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
    local frame = _G["ChatFrame" .. i]
    if frame and frame.AddMessage then hooksecurefunc(frame, "AddMessage", OnChatLine) end
end

-- Combat Log: the game's own window laid over our message area while it is
-- the chosen entry, in our text size, its frame art off; as it is left,
-- its place, size, art and look go back, and it hides unless it showed.
local LOG_ART = { "Background", "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture",
    "LeftTexture", "RightTexture", "BottomTexture", "TopTexture" }
-- Its button strip hangs over our contacts list.
local LOG_PIECES = { "ResizeButton", "buttonFrame", "ScrollToBottomButton" }
local took = { points = {}, art = {}, pieces = {} }
local logDriver = CreateFrame("Frame")
logDriver:Hide()

local function LogArea()
    local frame = UI._chatComposer.frame
    local view = frame and frame.messengerView
    return frame, view and view.messageScroll
end

local LOG_X, LOG_Y = 6, -4

-- Lowered, a frame leaves its children up, and the log's lines are in one:
-- its own come along a step above it at most, theirs as they sit.
local function Relevel(f, level, cap)
    local was, kids, steps = f:GetFrameLevel(), { f:GetChildren() }, {}
    for i = 1, #kids do
        local step = kids[i]:GetFrameLevel() - was
        steps[i] = cap and math.min(step, cap) or step
    end
    f:SetFrameLevel(level)
    for i = 1, #kids do Relevel(kids[i], level + steps[i]) end
end

-- Under the folder flyout and the window's menus, lines and all.
local function Leveled(log, level)
    local lines = log.FontStringContainer
    return log:GetFrameLevel() == level and not (lines and lines:GetFrameLevel() > level + 1)
end

local function PlaceLog(log, frame, area)
    log:ClearAllPoints()
    -- Its scroll bar hangs off its right side.
    log:SetPoint("TOPLEFT", area, "TOPLEFT", LOG_X, LOG_Y)
    log:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -16, 4)
    if log:GetFrameStrata() ~= frame:GetFrameStrata() then log:SetFrameStrata(frame:GetFrameStrata()) end
    local level = frame:GetFrameLevel() + 10
    if not Leveled(log, level) then Relevel(log, level, 1) end
end

local function KeepLogLook()
    for i = 1, #took.art do
        local tex = took.art[i][1]
        if tex:GetAlpha() > 0 then tex:SetAlpha(0) end
    end
    -- The game's fades show them again on hover and new lines.
    for piece in pairs(took.pieces) do
        if piece:IsShown() then piece:Hide() end
    end
end

function Views:CombatLogTaken()
    return took.log ~= nil
end

local function TakeLog()
    local log = _G.COMBATLOG
    local frame, area = LogArea()
    if took.log or not (log and area) then return end
    took.log, took.ever = log, true
    took.shown = log:IsShown()
    wipe(took.points)
    for i = 1, log:GetNumPoints() do took.points[i] = { log:GetPoint(i) } end
    took.strata, took.level = log:GetFrameStrata(), log:GetFrameLevel()
    -- The game's chat frames come forward when clicked or shown: not ours.
    took.toplevel = log:IsToplevel()
    if took.toplevel then log:SetToplevel(false) end
    took.font = { log:GetFont() }
    took.fading = log.GetFading and log:GetFading()
    wipe(took.pieces)
    for _, key in ipairs(LOG_PIECES) do
        local piece = log[key]
        if piece then took.pieces[piece] = piece:IsShown() end
    end
    wipe(took.art)
    local name = log:GetName()
    for _, part in ipairs(LOG_ART) do
        local tex = name and _G[name .. part]
        if tex then took.art[#took.art + 1] = { tex, tex:GetAlpha() } end
    end
    PlaceLog(log, frame, area)
    local view = frame.messengerView
    local font, size, flags = view.replyEditBox:GetFont()
    if font and size then log:SetFont(font, size, flags) end
    if log.SetFading then log:SetFading(false) end
    KeepLogLook()
    -- Shown, it fills again from the game's kept lines.
    if not log:IsShown() then log:Show() end
    logDriver:Show()
end

local function ReleaseLog()
    logDriver:Hide()
    local log = took.log
    if not log then return end
    took.log = nil
    log:ClearAllPoints()
    for i = 1, #took.points do log:SetPoint(unpack(took.points[i])) end
    log:SetFrameStrata(took.strata)
    Relevel(log, took.level, 1)
    if took.toplevel then log:SetToplevel(true) end
    if took.font[1] then log:SetFont(took.font[1], took.font[2], took.font[3]) end
    if log.SetFading and took.fading ~= nil then log:SetFading(took.fading) end
    for i = 1, #took.art do took.art[i][1]:SetAlpha(took.art[i][2]) end
    for piece, shown in pairs(took.pieces) do
        if shown then piece:Show() end
    end
    if not took.shown then log:Hide() end
end

-- Chosen and on screen: in ours; else back.
function Views:SyncCombatLog()
    local _, area = LogArea()
    local want =UI._chatComposer.selectedConversationKey == COMBAT and CombatLogListed()
        and area ~= nil and area:IsVisible()
    if want then TakeLog() else ReleaseLog() end
end

logDriver:SetScript("OnUpdate", function()
    local log = took.log
    local frame, area = LogArea()
    if not (log and area and area:IsVisible() and UI._chatComposer.selectedConversationKey == COMBAT) then
        return ReleaseLog()
    end
    -- The game docks and fades it again on its own, and each dock update
    -- lowers its top by its filter bar: kept ours.
    local _, rel, _, x, y = log:GetPoint(1)
    if rel ~= area or x ~= LOG_X or y ~= LOG_Y or not Leveled(log, frame:GetFrameLevel() + 10) then
        PlaceLog(log, frame, area)
    end
    if not log:IsShown() then log:Show() end
    KeepLogLook()
end)

-- Our text size changed: the log takes it too.
function Views:RefontCombatLog()
    local log = took.log
    local frame = UI._chatComposer.frame
    local box = frame and frame.messengerView and frame.messengerView.replyEditBox
    if not (log and box) then return end
    local font, size, flags = box:GetFont()
    if font and size then log:SetFont(font, size, flags) end
end

-- The game's chat back: a docked log shown since goes behind its tab again,
-- or it would cover the chat.
function Views:SettleCombatLog()
    local log = _G.COMBATLOG
    if not (log and took.ever) or took.log then return end
    local dock = _G.GENERAL_CHAT_DOCK
    if log:IsShown() and log.isDocked and not (dock and dock.selected == log) then log:Hide() end
end

-- Where the Combat Log was opened from: its own row pressed again goes back.
function Views:NoteCameFrom(key)
    if key ~= COMBAT then self.cameFrom = key end
end
