local _, chatNS = ...

local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not (ns and ns.Utils) or chatNS.tooOld then return end

local pairs, type = pairs, type
local sformat, sgsub, slower = string.format, string.gsub, string.lower

-- Traditional emoji in chat. Deliberately NOT Twitch/Discord meme emotes.
--
-- The single most important decision here: what goes OUT on the wire is the
-- plain text ":smile:", never a texture escape. A player without this addon --
-- which is nearly everyone -- reads ":smile:" and understands it perfectly. Had
-- we sent |T escapes, non-users would see a wall of unreadable garbage, and we
-- would have made everyone else's chat worse to make ours prettier. Rendering
-- happens on the RECEIVING side, for whoever has the addon.
--
-- That also means emoji need no addon-to-addon protocol at all, and they work
-- with every player, in every channel, forever.
local Emotes = {}
chatNS.Emotes = Emotes

local sheet = chatNS.EMOTE_SHEET
if not (sheet and sheet.map) then return end

-- Chat text is ~14px; the |T escape is given an explicit size so an emoji sits
-- on the text baseline instead of stretching the line height.
local DRAW = 16

-- Precomputed |T escape per name. Texcoords come from the grid, so swapping the
-- art for a different set is a file replace plus a regenerated manifest -- no
-- code change.
local escapes = {}
do
    local cols, cell = sheet.columns, sheet.cell
    local sheetW = cols * cell
    local sheetH = sheet.rows * cell
    for name, index in pairs(sheet.map) do
        local col = index % cols
        local row = math.floor(index / cols)
        local left, right = col * cell, (col + 1) * cell
        local top, bottom = row * cell, (row + 1) * cell
        -- |Ttexture:height:width:xOff:yOff:sheetW:sheetH:left:right:top:bottom|t
        escapes[name] = sformat("|T%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d|t",
            sheet.texture, DRAW, DRAW, sheetW, sheetH, left, right, top, bottom)
    end
end

-- Replaces :name: with its texture escape. Unknown names are LEFT ALONE: a
-- message containing a URL with "http://x:y:" or a time like "12:30:" must come
-- through untouched, and silently eating text we do not recognize would be worse
-- than not rendering an emoji.
function Emotes:Render(text)
    if type(text) ~= "string" or not text:find(":", 1, true) then return text end
    return (sgsub(text, "():(%w[%w_+%-]*):()", function(_, name)
        return escapes[slower(name)]
    end))
end

-- Incoming messages only. The filter returns false (do not block) and hands back
-- the rewritten message, which is the documented way to transform chat text
-- without swallowing it.
local CHAT_EVENTS = {
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE",
    "CHAT_MSG_CHANNEL",
}

local function Filter(_, _, message, ...)
    if type(message) ~= "string" then return false end
    local rendered = Emotes:Render(message)
    if rendered == message then return false end
    return false, rendered, ...
end

function Emotes:Install()
    if self.installed then return end
    local addFilter = ChatFrame_AddMessageEventFilter
        or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
    if not addFilter then return end
    self.installed = true
    for i = 1, #CHAT_EVENTS do
        addFilter(CHAT_EVENTS[i], Filter)
    end
end

Emotes:Install()
