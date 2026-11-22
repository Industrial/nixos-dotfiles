local _, chatNS = ...

local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not (ns and ns.Utils) or chatNS.tooOld then return end

local Utils = ns.Utils
local type, tonumber, tostring = type, tonumber, tostring
local sformat, smatch = string.format, string.match
local CreateFrame = CreateFrame
local C_ChatInfo = C_ChatInfo
local time = time

-- Peer channel: what two people running this addon can do that they cannot do
-- with anyone else.
--
-- Everything user-visible still degrades to plain chat -- emoji go out as
-- ":smile:", messages as text -- so this channel carries only ENRICHMENT, never
-- content. If it is missing, nothing breaks and nothing is lost; you simply do
-- not see that the other person is typing. That constraint is what keeps the
-- feature honest: a protocol that content depends on would silently split the
-- world into people you can talk to properly and people you cannot.
local Comm = {}
chatNS.Comm = Comm

local PREFIX = "EASYFINDCHAT"
local PROTOCOL = 1

-- Peers we have seen, and when. A peer is forgotten after this long so a stale
-- "is typing" or a since-uninstalled user cannot linger forever.
local PEER_TTL = 15 * 60
local TYPING_TTL = 6

local peers = {}     -- [sender] = { protocol, lastSeen }
local typing = {}    -- [sender] = expiry

local Op = {
    HELLO  = "hello",   -- I have the addon, and this is my protocol version
    TYPING = "typing",  -- I am composing a message to you
    READ   = "read",    -- I have read up to this timestamp
}
Comm.Op = Op

local frame = CreateFrame("Frame")

local function Now()
    return (time and time()) or 0
end

local function Send(op, target, body)
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage and target and target ~= "") then
        return false
    end
    local payload = sformat("%d|%s|%s", PROTOCOL, op, tostring(body or ""))
    -- Whisper-scoped: this never touches a public channel, so it cannot spam
    -- anyone who did not opt into a conversation with us.
    local ok = pcall(C_ChatInfo.SendAddonMessage, PREFIX, payload, "WHISPER", target)
    return ok and true or false
end

-- Announce ourselves when a conversation starts. The reply (if any) is what
-- tells us the other side can light up the richer features.
function Comm:Hello(target)
    return Send(Op.HELLO, target, PROTOCOL)
end

function Comm:Typing(target)
    return Send(Op.TYPING, target, "1")
end

function Comm:MarkRead(target, stamp)
    return Send(Op.READ, target, tonumber(stamp) or Now())
end

function Comm:IsPeer(name)
    local peer = name and peers[name]
    if not peer then return false end
    if Now() - peer.lastSeen > PEER_TTL then
        peers[name] = nil
        return false
    end
    return true
end

function Comm:IsTyping(name)
    local expiry = name and typing[name]
    if not expiry then return false end
    if Now() > expiry then
        typing[name] = nil
        return false
    end
    return true
end

local function Handle(sender, protocol, op, body)
    -- A newer peer must not be able to drive us: we only ever act on ops we
    -- know, and an unknown op from a future version is ignored rather than
    -- guessed at.
    peers[sender] = { protocol = protocol, lastSeen = Now() }

    if op == Op.HELLO then
        -- Answer once so the other side learns about us too, but never answer an
        -- answer: replying to a reply is how two clients ping-pong forever.
        if tostring(body) ~= "ack" then
            Send(Op.HELLO, sender, "ack")
        end
        if Comm.onPeer then xpcall(Comm.onPeer, Utils.ErrorHandler, sender) end
    elseif op == Op.TYPING then
        typing[sender] = Now() + TYPING_TTL
        if Comm.onTyping then xpcall(Comm.onTyping, Utils.ErrorHandler, sender) end
    elseif op == Op.READ then
        if Comm.onRead then
            xpcall(Comm.onRead, Utils.ErrorHandler, sender, tonumber(body) or 0)
        end
    end
end

frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(_, _, prefix, payload, _, sender)
    if prefix ~= PREFIX or type(payload) ~= "string" or not sender then return end
    local protocol, op, body = smatch(payload, "^(%d+)|([%w_]+)|(.*)$")
    protocol = tonumber(protocol)
    if not (protocol and op) then return end
    -- Strip the realm from same-realm senders so the name matches what the
    -- conversation store keys on.
    sender = smatch(sender, "^([^%-]+)") or sender
    Handle(sender, protocol, op, body)
end)

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
end
