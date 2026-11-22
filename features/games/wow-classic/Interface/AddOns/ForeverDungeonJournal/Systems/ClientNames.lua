-- ForeverDungeonJournal: boss and dungeon names from the game client (2.0.3).
--
-- The game client knows every creature's and every instance's name in its own
-- language. On a non-English client, at login, the journal asks it:
--   * bosses:   the creature tooltip of the boss's NPC ID
--               (C_TooltipInfo.GetHyperlink "unit:Creature-...-<npcID>-...")
--   * dungeons: GetRealZoneText(<instance ID>)
-- and uses those names in the journal and the Dungeon Tracker, so they are
-- exactly what the player sees in the game (also for dungeons and bosses with
-- no translation in the addon). Names the client doesn't have cached yet are
-- asked again a little later. What it learned is kept for the next login.
-- Entries that aren't one creature ("The Seven", "Morphaz & Hazzas") keep the
-- addon's own translation.
local _, FDJ = ...
FDJ = FDJ or _G.ForeverDungeonJournal_NS

local LOCALE_KEY = {
    deDE = "deDE", frFR = "frFR", esES = "esES", esMX = "esES", ruRU = "ruRU",
    itIT = "itIT", ptBR = "ptBR", koKR = "koKR", zhCN = "zhCN", zhTW = "zhTW",
}
local GROUP_ENTRIES = { ["The Seven"] = true, ["The Lost Dwarves"] = true }
local BATCH, STEP = 20, 0.1          -- tooltips per step, seconds between steps
local RETRY = { 30, 120 }            -- seconds after login: ask again for the rest

local function Plain(v)
    if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
    return v
end

local function ClientKey()
    local loc = type(GetLocale) == "function" and GetLocale() or "enUS"
    return LOCALE_KEY[loc], loc
end

local function Content(key)
    FDJ.ContentLocales = FDJ.ContentLocales or {}
    local c = FDJ.ContentLocales[key]
    if type(c) ~= "table" then c = {} FDJ.ContentLocales[key] = c end
    if type(c.bosses) ~= "table" then c.bosses = {} end
    if type(c.dungeons) ~= "table" then c.dungeons = {} end
    return c
end

local function Saved(loc)
    ForeverDungeonJournalDB = ForeverDungeonJournalDB or {}
    local db = ForeverDungeonJournalDB
    if type(db.clientNames) ~= "table" then db.clientNames = {} end
    local s = db.clientNames[loc]
    if type(s) ~= "table" then s = {} db.clientNames[loc] = s end
    if type(s.bosses) ~= "table" then s.bosses = {} end
    if type(s.dungeons) ~= "table" then s.dungeons = {} end
    return s
end

-- A journal boss named after one creature.
local function SingleCreature(name)
    return type(name) == "string" and not GROUP_ENTRIES[name]
        and not name:find(" & ", 1, true) and not name:find(" and ", 1, true) and not name:find("/", 1, true)
end

local function GoodName(name)
    name = Plain(name)
    if type(name) ~= "string" or name == "" then return nil end
    if name == UNKNOWNOBJECT or name == UNKNOWN or name == RETRIEVING_DATA or name == RETRIEVING_ITEM_INFO then return nil end
    return name
end

-- The creature's name from its tooltip; nil until the client has it cached.
local scanTip
local function CreatureName(npc)
    local link = ("unit:Creature-0-0-0-0-%d-0000000000"):format(npc)
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
        local line = ok and type(data) == "table" and type(data.lines) == "table" and data.lines[1]
        if type(line) == "table" then
            if line.leftText == nil and TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, line) end
            return GoodName(line.leftText)
        end
        return nil
    end
    if not CreateFrame then return nil end
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "ForeverDungeonJournalNameScan", UIParent, "GameTooltipTemplate")
    end
    local ok = pcall(function()
        scanTip:SetOwner(UIParent, "ANCHOR_NONE")
        scanTip:ClearLines()
        scanTip:SetHyperlink(link)
    end)
    local fs = ok and _G["ForeverDungeonJournalNameScanTextLeft1"]
    local name = fs and fs.GetText and GoodName(fs:GetText())
    scanTip:Hide()
    return name
end

local function ApplyBoss(c, b, name)
    if SingleCreature(b.name) then c.bosses[b.name] = name end
    if FDJ.RunLog and FDJ.RunLog.AddAlias then pcall(FDJ.RunLog.AddAlias, b.npcID, name) end
end

-- Dungeon names by instance ID. A client that doesn't know an ID may answer
-- with the current zone instead: such answers, and names two IDs share, are
-- not used.
local function LearnDungeons(c, saved)
    if type(GetRealZoneText) ~= "function" then return 0 end
    local here = Plain(select(2, pcall(GetRealZoneText)))
    local found, seen = {}, {}
    for id, key in pairs(FDJ.INSTANCE_ID_TO_DUNGEON or {}) do
        if key ~= "Scarlet Monastery" and FDJ.DB and FDJ.DB[key]
            and not (FDJ.RunLogWingGroups and FDJ.RunLogWingGroups[id]) then
            local ok, name = pcall(GetRealZoneText, id)
            name = ok and GoodName(name)
            if name and name ~= here then
                found[key] = name
                seen[name] = (seen[name] or 0) + 1
            end
        end
    end
    local n = 0
    for key, name in pairs(found) do
        if seen[name] == 1 then
            local entry = c.dungeons[key]
            if type(entry) ~= "table" then entry = {} c.dungeons[key] = entry end
            entry.name = name
            saved.dungeons[key] = name
            n = n + 1
        end
    end
    return n
end

local state = { bosses = 0, dungeons = 0, asked = 0, locale = nil }

local function Queue()
    local q = {}
    for _, d in pairs(FDJ.DB or {}) do
        for _, b in ipairs((type(d) == "table" and d.bosses) or {}) do
            if type(b) == "table" and tonumber(b.npcID) and type(b.name) == "string" and not b.trash and not b.recipeTab then
                q[#q + 1] = b
            end
        end
    end
    return q
end

local function Scan(c, saved, pass)
    local q, i, missing = Queue(), 0, 0
    local function Step()
        for _ = 1, BATCH do
            i = i + 1
            local b = q[i]
            if not b then
                if missing > 0 and RETRY[pass] and C_Timer then
                    C_Timer.After(RETRY[pass], function() Scan(c, saved, pass + 1) end)
                end
                if FDJ.RunLog and FDJ.RunLog.FixAll then pcall(FDJ.RunLog.FixAll) end
                if FDJ.UpdateRunTracker then pcall(FDJ.UpdateRunTracker) end
                return
            end
            if not saved.bosses[b.npcID] or pass == 1 then
                state.asked = state.asked + 1
                local name = CreatureName(b.npcID)
                if name then
                    if saved.bosses[b.npcID] ~= name then saved.bosses[b.npcID] = name end
                    ApplyBoss(c, b, name)
                else
                    missing = missing + 1
                end
            end
        end
        if C_Timer then C_Timer.After(STEP, Step) else Step() end
    end
    Step()
end

local function Count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end

function FDJ.LearnClientNames()
    local key, loc = ClientKey()
    if not key then return false end      -- English client: the journal's own names
    state.locale = loc
    local c, saved = Content(key), Saved(loc)
    -- Last login's names first, so the journal has them right away.
    for _, d in pairs(FDJ.DB or {}) do
        for _, b in ipairs((type(d) == "table" and d.bosses) or {}) do
            local name = type(b) == "table" and tonumber(b.npcID) and saved.bosses[b.npcID]
            if type(name) == "string" then ApplyBoss(c, b, name) end
        end
    end
    for k, name in pairs(saved.dungeons) do
        if FDJ.DB and FDJ.DB[k] and type(name) == "string" then
            local entry = c.dungeons[k]
            if type(entry) ~= "table" then entry = {} c.dungeons[k] = entry end
            entry.name = name
        end
    end
    LearnDungeons(c, saved)
    Scan(c, saved, 1)
    return true
end

-- /dj names: what was learned (for testers).
function FDJ.ClientNamesReport()
    local key, loc = ClientKey()
    if not key then return "English client: the journal uses its own names." end
    local saved = Saved(loc)
    return ("Names from your game client (%s): %d bosses, %d dungeons."):format(loc, Count(saved.bosses), Count(saved.dungeons))
end

local f = CreateFrame and CreateFrame("Frame")
if f then
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
        f:UnregisterEvent("PLAYER_LOGIN")
        if C_Timer and C_Timer.After then
            C_Timer.After(3, function() pcall(FDJ.LearnClientNames) end)
        else
            pcall(FDJ.LearnClientNames)
        end
    end)
end
