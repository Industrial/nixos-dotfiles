local _, chatNS = ...

local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not (ns and ns.Utils) or chatNS.tooOld then return end

local Utils = ns.Utils
local pairs, ipairs, type = pairs, ipairs, type
local tsort = table.sort
local time = time

-- Persistence policy for the message store.
--
-- A chat log is the one structure in an addon that grows without bound: every
-- whisper you ever receive, forever. Left alone it becomes exactly what
-- EasyFind's caches became -- megabytes of live Lua tables the client parses at
-- login before a line of our code runs. So retention and a schema version are
-- built in from the start rather than retrofitted after someone reports a 40 MB
-- SavedVariables file.
local Store = {}
chatNS.Store = Store

-- Bump when the stored shape changes. Migrations run in order for every version
-- between the saved one and this one, so a player who skips releases still
-- lands on a valid store.
local SCHEMA_VERSION = 2
Store.SCHEMA_VERSION = SCHEMA_VERSION

local DEFAULTS = {
    -- Messages older than this are dropped at login. 0 = keep forever, which is
    -- offered but not the default: the default has to protect the player who
    -- never opens settings.
    retentionDays = 60,
    -- Hard cap per conversation, applied even inside the retention window. A
    -- single very chatty thread must not be able to dominate the file.
    maxMessagesPerConversation = 400,
    -- Total ceiling across all conversations, as a last backstop.
    maxTotalMessages = 8000,
    -- Conversation-count cap; the UI enforces it when a conversation is touched
    -- so Store stays the single owner of every retention number.
    maxConversations = 50,
}

local function DB()
    EasyFindChatDB = type(EasyFindChatDB) == "table" and EasyFindChatDB or {}
    return EasyFindChatDB
end

function Store:Settings()
    local db = DB()
    db.retention = type(db.retention) == "table" and db.retention or {}
    for key, value in pairs(DEFAULTS) do
        if db.retention[key] == nil then db.retention[key] = value end
    end
    return db.retention
end

-- Migrations are keyed by the version they UPGRADE TO, and each one must be
-- safe to run on a store that is already partially correct: a crash mid-purge
-- leaves the file half-migrated, and the next login has to cope.
local migrations = {}

migrations[1] = function(db)
    -- v1 formalizes what earlier builds wrote implicitly: conversations keyed by
    -- byKey/order, no message timestamps guaranteed. Stamp anything missing a
    -- time so retention has something to compare against, rather than deleting
    -- history we cannot date.
    local store = type(db.conversations) == "table" and db.conversations or nil
    if not store or type(store.byKey) ~= "table" then return end
    local now = time and time() or 0
    for _, convo in pairs(store.byKey) do
        if type(convo) == "table" and type(convo.messages) == "table" then
            for _, msg in ipairs(convo.messages) do
                if type(msg) == "table" and not msg.time then
                    msg.time = now
                end
            end
        end
    end
end

migrations[2] = function(db)
    -- v2: a message keeps the character it was heard on (msg.char). Chats
    -- from before cannot say, so they show for every character.
    local store = type(db.conversations) == "table" and db.conversations or nil
    if not store or type(store.byKey) ~= "table" then return end
    for _, convo in pairs(store.byKey) do
        if type(convo) == "table" and type(convo.messages) == "table" and #convo.messages > 0 then
            convo.legacy = true
        end
    end
end

function Store:Migrate()
    local db = DB()
    local from = tonumber(db.schemaVersion) or 0
    if from >= SCHEMA_VERSION then
        db.schemaVersion = SCHEMA_VERSION
        return false
    end
    for version = from + 1, SCHEMA_VERSION do
        local migrate = migrations[version]
        if migrate then
            -- A failed migration must not brick the addon; the store is left as
            -- it was and the version is not advanced, so the next login retries.
            local ok = xpcall(migrate, Utils.ErrorHandler, db)
            if not ok then return false end
        end
        db.schemaVersion = version
    end
    return true
end

local function MessageCount(convo)
    return (type(convo) == "table" and type(convo.messages) == "table")
        and #convo.messages or 0
end

-- Drops the oldest messages first, in one shift, and marks the thread cut so
-- the window draws its "older messages removed" rule; pinned ones stay.
-- Returns the count.
local function TrimConversation(convo, cutoff, maxMessages)
    local messages = type(convo) == "table" and convo.messages
    if type(messages) ~= "table" then return 0 end
    local n = #messages
    -- Appended in order: what is older than the cutoff is a prefix.
    local keep = 1
    if cutoff > 0 then
        while keep <= n and type(messages[keep]) == "table" and (messages[keep].time or 0) < cutoff do
            keep = keep + 1
        end
    end
    keep = math.max(keep, n - maxMessages + 1)
    if keep <= 1 then return 0 end
    local w = 1
    for i = 1, n do
        local msg = messages[i]
        if i >= keep or (type(msg) == "table" and msg.pinned) then
            messages[w] = msg
            w = w + 1
        end
    end
    for i = w, n do messages[i] = nil end
    local removed = n - w + 1
    if removed > 0 then messages.trimmed = true end
    return removed
end

-- The largest per-thread level whose sum of min(count, level) fits the
-- ceiling, then every thread cut to it. Returns the count removed.
local function TrimToLevel(store, counts, ceiling)
    tsort(counts)
    local level, used, left = 0, 0, #counts
    for i = 1, #counts do
        -- Threads from i on all get the same level; the ones before keep theirs.
        local fit = math.floor((ceiling - used) / left)
        if counts[i] > fit then
            level = fit
            break
        end
        used, left, level = used + counts[i], left - 1, counts[i]
    end
    local removed = 0
    for _, convo in pairs(store.byKey) do
        removed = removed + TrimConversation(convo, 0, math.max(1, level))
    end
    return removed
end

-- Runs at login. Purging on write instead would put this work in the path of
-- every incoming whisper, which is the one place it must never be.
function Store:Purge()
    local db = DB()
    local settings = self:Settings()
    local store = type(db.conversations) == "table" and db.conversations or nil
    if not (store and type(store.byKey) == "table") then return 0 end

    local now = time and time() or 0
    local cutoff = 0
    if (settings.retentionDays or 0) > 0 and now > 0 then
        cutoff = now - (settings.retentionDays * 86400)
    end

    local removed = 0
    for _, convo in pairs(store.byKey) do
        removed = removed + TrimConversation(convo, cutoff,
            settings.maxMessagesPerConversation)
    end
    -- The System chat (Views.lua) keeps to the same limits.
    if type(store.system) == "table" then
        removed = removed + TrimConversation(store.system, cutoff, settings.maxMessagesPerConversation)
    end

    -- Global backstop: every thread over one level L is cut to its newest L,
    -- L the largest that fits the ceiling, so no thread is emptied.
    local total, counts = 0, {}
    for _, convo in pairs(store.byKey) do
        local n = MessageCount(convo)
        total = total + n
        counts[#counts + 1] = n
    end
    if total > settings.maxTotalMessages then
        removed = removed + TrimToLevel(store, counts, settings.maxTotalMessages)
    end

    return removed
end

function Store:Init()
    self:Migrate()
    self:Purge()
end
