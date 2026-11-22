local _, notesNS = ...

-- Where a note applies: the situations this client can detect (Active), the
-- tags a note can carry on this client (Options), and whether a note
-- applies now (Applies). Tags are { type, id, name }.
local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns or notesNS.tooOld then return end

local L = ns.L
local Caps = ns.Caps or {}
local MapUtils = ns.MapUtils

local Ctx = {}
notesNS.Context = Ctx

local tostring, pairs, ipairs, type = tostring, pairs, ipairs, type
local sfind, slower, sformat = string.find, string.lower, string.format
local issecret = _G.issecretvalue or function() return false end

local function Key(entry) return tostring(entry.type) .. ":" .. tostring(entry.id) end
Ctx.Key = Key

-- What each kind of tag is called in the picker, and how surely a match of
-- it picks a note (higher first).
local KINDS = {
    uistate = { "NOTES_KIND_WINDOW", 9 }, dungeon = { "LFG_TYPE_DUNGEON", 8 }, raid = { "RAID", 8 },
    instance = { "NOTES_KIND_INSTANCE", 8 }, player = { "PLAYER", 7 }, map = { "ZONE", 6 },
    mythicplus = { "NOTES_KIND_GAME", 5 }, pvp = { "NOTES_KIND_GAME", 5 }, warmode = { "NOTES_KIND_GAME", 4 },
    group = { "GROUP", 4 }, spec = { "SPECIALIZATION", 4 }, role = { "ROLE", 4 },
    class = { "NOTES_KIND_MY_CLASS", 3 }, faction = { "FACTION", 2 }, character = { "CHARACTER", 2 },
    duel = { "NOTES_KIND_DOING", 7 }, combat = { "NOTES_KIND_DOING", 6 }, resting = { "NOTES_KIND_DOING", 3 },
    duelclass = { "NOTES_KIND_OPPONENT", 7 }, targetclass = { "NOTES_KIND_TARGET", 6 },
}

local function Text(key)
    local g = _G[key]
    if type(g) == "string" then return g end
    return L[key]
end

function Ctx.KindLabel(entry)
    if entry.type == "map" and entry.continent then return Text("CONTINENT") end
    local k = KINDS[entry.type]
    return k and Text(k[1]) or tostring(entry.type)
end

function Ctx.Priority(entry)
    local k = KINDS[entry.type]
    return k and k[2] or 1
end

-- The kinds as the user sees them: { label, types }, the types sharing a
-- name (combat, duel, resting are all "doing") under one, by label.
function Ctx.KindList()
    local byLabel, out = {}, {}
    for t in pairs(KINDS) do
        local label = Ctx.KindLabel({ type = t })
        local k = byLabel[label]
        if not k then
            k = { label = label, types = {} }
            byLabel[label] = k
            out[#out + 1] = k
        end
        k.types[#k.types + 1] = t
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

-- Windows the client reports opening and closing.
local WINDOWS = {
    { id = "auctionhouse", label = "NOTES_CTX_AUCTION", open = "AUCTION_HOUSE_SHOW", close = "AUCTION_HOUSE_CLOSED" },
    { id = "merchant", label = "NOTES_CTX_MERCHANT", open = "MERCHANT_SHOW", close = "MERCHANT_CLOSED" },
    { id = "bank", label = "NOTES_CTX_BANK", open = "BANKFRAME_OPENED", close = "BANKFRAME_CLOSED" },
    { id = "mail", label = "NOTES_CTX_MAIL", open = "MAIL_SHOW", close = "MAIL_CLOSED" },
    { id = "profession", label = "NOTES_CTX_PROFESSION", open = "TRADE_SKILL_SHOW", close = "TRADE_SKILL_CLOSE" },
    { id = "trainer", label = "NOTES_CTX_TRAINER", open = "TRAINER_SHOW", close = "TRAINER_CLOSED" },
    { id = "greatvault", label = "NOTES_CTX_VAULT", open = "WEEKLY_REWARDS_SHOW", close = "WEEKLY_REWARDS_HIDE",
      retail = true },
}

local windowOpen = {}
local onChange

-- Notes loads on demand, maybe at an open house: the client's interaction.
local PIM = C_PlayerInteractionManager
if PIM and PIM.IsInteractingWithNpcOfType and Enum.PlayerInteractionType
   and PIM.IsInteractingWithNpcOfType(Enum.PlayerInteractionType.Auctioneer) then
    windowOpen.auctionhouse = true
end

-- Open by the client's events, not a frame: another addon's window can
-- stand in for the client's (TSM keeps the classic AuctionFrame hidden).
function Ctx.WindowOpen(id) return windowOpen[id] == true end

-- A player unit's key and the name it shows, or nil.
function Ctx.UnitPlayer(unit)
    if not (unit and UnitExists and UnitExists(unit) and UnitIsPlayer and UnitIsPlayer(unit)) then return nil end
    local full = GetUnitName and GetUnitName(unit, true)
    if type(full) ~= "string" or issecret(full) then return nil end
    local shown = GetUnitName(unit, false) or full
    return ns.NotesPlayerKey(full), shown
end

-- Detection ---------------------------------------------------------------------

local function Add(list, set, entry, ...)
    if not entry then return end
    list[#list + 1] = entry
    set[Key(entry)] = true
    -- Aliases a tag of an older kind still matches by.
    for i = 1, select("#", ...) do
        local alias = select(i, ...)
        if alias then set[alias] = true end
    end
end

local function AddMaps(list, set)
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local guard = 0
    while mapID and mapID ~= 0 and guard < 10 do
        local info = C_Map.GetMapInfo(mapID)
        if not info or (Enum and Enum.UIMapType and info.mapType <= Enum.UIMapType.World) then break end
        if info.name and info.name ~= "" then
            Add(list, set, { type = "map", id = mapID, name = info.name,
                continent = info.mapType == Enum.UIMapType.Continent or nil })
        end
        mapID = MapUtils and MapUtils.GetParentMapID and MapUtils.GetParentMapID(mapID, info) or info.parentMapID
        guard = guard + 1
    end
end

local function AddInstance(list, set)
    if not (IsInInstance and IsInInstance() and GetInstanceInfo) then return end
    local name, instType, _, _, _, _, _, instanceID = GetInstanceInfo()
    if not (instanceID and name and name ~= "") then return end
    local kind = instType == "party" and "dungeon" or instType == "raid" and "raid" or "instance"
    Add(list, set, { type = kind, id = instanceID, name = name }, "instance:" .. tostring(instanceID))
    if instType == "pvp" or instType == "arena" then
        Add(list, set, { type = "pvp", id = "pvp", name = L["NOTES_CTX_PVP"] })
    end
end

local function AddSelf(list, set)
    local className, classFile = UnitClass("player")
    if classFile then Add(list, set, { type = "class", id = classFile, name = className }) end
    local faction, factionName = UnitFactionGroup("player")
    if faction == "Alliance" or faction == "Horde" then
        Add(list, set, { type = "faction", id = faction, name = factionName or faction })
    end
    Add(list, set, { type = "character", id = ns.CurrentCharacterKey(), name = ns.PlayerName() })
    if Caps.specs and GetSpecialization and GetSpecializationInfo then
        local idx = GetSpecialization()
        if idx then
            local specID, specName, _, _, role = GetSpecializationInfo(idx)
            if specID and specName and specName ~= "" then
                Add(list, set, { type = "spec", id = specID, name = specName })
            end
            if role and _G[role] then Add(list, set, { type = "role", id = role, name = _G[role] }) end
        end
    end
end

local function AddGroup(list, set)
    local id, label = "solo", "NOTES_CTX_SOLO"
    if IsInRaid and IsInRaid() then id, label = "raid", "NOTES_CTX_RAIDGROUP"
    elseif IsInGroup and IsInGroup() then id, label = "party", "NOTES_CTX_PARTY" end
    Add(list, set, { type = "group", id = id, name = L[label] })
end

-- The target (a player or an NPC) and the group.
local function AddUnits(list, set)
    local seen = {}
    local function unit(u)
        local entry = ns.NotesUnitEntry(u)
        local key = entry and Key(entry)
        if key and not seen[key] then
            seen[key] = true
            Add(list, set, entry)
        end
    end
    unit("target")
    local raid = IsInRaid and IsInRaid()
    for i = 1, raid and 40 or 4 do unit((raid and "raid" or "party") .. i) end
    if UnitExists("target") and UnitIsPlayer("target") then
        local className, classFile = UnitClass("target")
        if classFile and not issecret(classFile) then
            Add(list, set, { type = "targetclass", id = classFile, name = sformat(L["NOTES_CTX_TARGET_CLASS_FMT"], className) })
        end
    end
end

-- A duel, from its challenge (sent or received) to its end, with the
-- other player's class when a unit near is them.
local duel
local NEAR = { "target", "focus", "mouseover", "party1", "party2", "party3", "party4" }

-- The first name alone: Forever's units add a surname, a realm follows a dash.
local function Short(name)
    return type(name) == "string" and not issecret(name) and name:match("^[^%s%-]+") or nil
end

local function BeginDuel(name, unit)
    local want = Short(name)
    if not unit and want then
        for _, u in ipairs(NEAR) do
            if UnitExists(u) and UnitIsPlayer(u) and Short(GetUnitName(u, false)) == want then
                unit = u
                break
            end
        end
    end
    local className, classFile
    if unit and UnitExists(unit) then className, classFile = UnitClass(unit) end
    if issecret(classFile) then className, classFile = nil, nil end
    duel = { name = want, class = classFile, className = className }
end

local function AddDoing(list, set)
    if duel then
        Add(list, set, { type = "duel", id = "duel", name = L["NOTES_CTX_DUEL"] })
        if duel.class then
            Add(list, set, { type = "duelclass", id = duel.class,
                name = sformat(L["NOTES_CTX_DUEL_CLASS_FMT"], duel.className or duel.class) })
        end
    end
    if InCombatLockdown and InCombatLockdown() then
        Add(list, set, { type = "combat", id = "combat", name = L["NOTES_CTX_COMBAT"] })
    end
    if IsResting and IsResting() then
        Add(list, set, { type = "resting", id = "resting", name = L["NOTES_CTX_RESTING"] })
    end
end

local function AddGame(list, set)
    if not Caps.retail then return end
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
        Add(list, set, { type = "mythicplus", id = "mplus", name = L["NOTES_CTX_MPLUS"] })
    end
    if C_PvP and C_PvP.IsWarModeActive and C_PvP.IsWarModeActive() then
        Add(list, set, { type = "warmode", id = "warmode", name = Text("PVP_LABEL_WAR_MODE") })
    end
end

-- The situations active now: a list (each once) and a set of their keys,
-- tags of older kinds included.
function Ctx.Active()
    local list, set = {}, {}
    for _, w in ipairs(WINDOWS) do
        if windowOpen[w.id] then Add(list, set, { type = "uistate", id = w.id, name = L[w.label] }) end
    end
    AddInstance(list, set)
    AddMaps(list, set)
    AddUnits(list, set)
    AddGroup(list, set)
    AddSelf(list, set)
    AddGame(list, set)
    AddDoing(list, set)
    return list, set
end

-- Whether a note comes up in the situations of set: one of its own
-- conditions holds, or every condition of one of its rules does. What
-- tooltips it shows on has no part in it.
function Ctx.Applies(note, set)
    if not note then return false end
    local singles = note.appliesIn
    for i = 1, singles and #singles or 0 do
        if set[Key(singles[i])] == true then return true end
    end
    local rules = note.rules
    for r = 1, rules and #rules or 0 do
        local conds = rules[r].conds
        local all = conds ~= nil and #conds > 0
        for c = 1, conds and #conds or 0 do
            if set[Key(conds[c])] ~= true then
                all = false
                break
            end
        end
        if all then return true end
    end
    return false
end

-- Whether a condition holds in set: a single's key, or every part of a combination.
function Ctx.Holds(holder, set)
    local conds = holder.conds
    if conds then
        if #conds == 0 then return false end
        for c = 1, #conds do
            if set[Key(conds[c])] ~= true then return false end
        end
        return true
    end
    return set[Key(holder)] == true
end

-- The condition set to open the notes window (a single, or a combination)
-- that holds now, or nil.
function Ctx.OpensNow(note, set)
    if not note then return nil end
    local singles = note.appliesIn
    for i = 1, singles and #singles or 0 do
        if singles[i].opens and Ctx.Holds(singles[i], set) then return singles[i] end
    end
    local rules = note.rules
    for r = 1, rules and #rules or 0 do
        if rules[r].opens == true and Ctx.Holds(rules[r], set) then return rules[r] end
    end
    return nil
end

function Ctx.AnyOpens(note)
    local singles = note.appliesIn
    for i = 1, singles and #singles or 0 do
        if singles[i].opens then return true end
    end
    local rules = note.rules
    for r = 1, rules and #rules or 0 do
        if rules[r].opens and rules[r].conds and #rules[r].conds > 0 then return true end
    end
    return false
end

-- Options -------------------------------------------------------------------------

local zones
local function Zones()
    if zones then return zones end
    zones = {}
    if not (C_Map and C_Map.GetMapChildrenInfo and MapUtils and MapUtils.WorldRoots) then return zones end
    local roots, rootID = MapUtils.WorldRoots()
    local seen = {}
    local function addMap(info, continent)
        if info and info.mapID and not seen[info.mapID] and info.name and info.name ~= "" then
            seen[info.mapID] = true
            zones[#zones + 1] = { type = "map", id = info.mapID, name = info.name, continent = continent or nil }
        end
    end
    local T = Enum.UIMapType
    local tops = rootID and C_Map.GetMapChildrenInfo(rootID, nil, true) or roots
    for _, info in ipairs(tops or {}) do
        if info.mapType == T.Continent then addMap(info, true)
        elseif info.mapType == T.Zone then addMap(info) end
    end
    return zones
end

local instances
local function Instances()
    if instances then return instances end
    instances = {}
    local seen = {}
    local function addOne(id, name, raid)
        if id and not seen[id] and name and name ~= "" then
            seen[id] = true
            instances[#instances + 1] = { type = raid and "raid" or "dungeon", id = id, name = name }
        end
    end
    if Caps.instanceTable then
        for _, e in ipairs(ns.FOREVER_INSTANCES or {}) do
            local ok, name = pcall(GetRealZoneText, e.id)
            addOne(e.id, (ok and type(name) == "string" and name ~= "") and name or e.n, e.raid)
        end
    else
        local MS = ns.MapSearch
        if not (MS and MS.HasGlobalInstanceCache and MS:HasGlobalInstanceCache()) then
            if MS and MS.RequestGlobalInstanceCache then
                MS:RequestGlobalInstanceCache(function() instances = nil if onChange then onChange("options") end end)
            end
            instances = nil
            return {}
        end
        for _, poi in ipairs(MS:GetGlobalInstanceCache() or {}) do
            addOne(poi.instanceID, poi.name, poi.category == "raid")
        end
    end
    return instances
end

-- Each class three ways: mine, my target's, my duel opponent's.
local function Classes()
    local out = {}
    for id = 1, (GetNumClasses and GetNumClasses() or 0) do
        local name, file = GetClassInfo(id)
        if name and file then
            out[#out + 1] = { type = "class", id = file, name = name }
            out[#out + 1] = { type = "targetclass", id = file, name = sformat(L["NOTES_CTX_TARGET_CLASS_FMT"], name) }
            out[#out + 1] = { type = "duelclass", id = file, name = sformat(L["NOTES_CTX_DUEL_CLASS_FMT"], name) }
        end
    end
    return out
end

-- The client's windows as tags: "Auction House" (a note with it applies
-- there); the open switch on one is the "Auction House open" toggle.
function Ctx.Windows()
    local out = {}
    for _, w in ipairs(WINDOWS) do
        if not w.retail or Caps.retail then out[#out + 1] = { type = "uistate", id = w.id, name = L[w.label] } end
    end
    return out
end

function Ctx.WindowLabel(id)
    for _, w in ipairs(WINDOWS) do
        if w.id == id then return L[w.label] end
    end
    return nil
end

local function Fixed()
    local out = Ctx.Windows()
    out[#out + 1] = { type = "group", id = "solo", name = L["NOTES_CTX_SOLO"] }
    out[#out + 1] = { type = "group", id = "party", name = L["NOTES_CTX_PARTY"] }
    out[#out + 1] = { type = "group", id = "raid", name = L["NOTES_CTX_RAIDGROUP"] }
    out[#out + 1] = { type = "faction", id = "Alliance", name = Text("FACTION_ALLIANCE") or "Alliance" }
    out[#out + 1] = { type = "faction", id = "Horde", name = Text("FACTION_HORDE") or "Horde" }
    out[#out + 1] = { type = "pvp", id = "pvp", name = L["NOTES_CTX_PVP"] }
    out[#out + 1] = { type = "duel", id = "duel", name = L["NOTES_CTX_DUEL"] }
    out[#out + 1] = { type = "combat", id = "combat", name = L["NOTES_CTX_COMBAT"] }
    out[#out + 1] = { type = "resting", id = "resting", name = L["NOTES_CTX_RESTING"] }
    if Caps.specs then
        for _, role in ipairs({ "TANK", "HEALER", "DAMAGER" }) do
            out[#out + 1] = { type = "role", id = role, name = Text(role) }
        end
    end
    if Caps.retail then
        out[#out + 1] = { type = "mythicplus", id = "mplus", name = L["NOTES_CTX_MPLUS"] }
        out[#out + 1] = { type = "warmode", id = "warmode", name = Text("PVP_LABEL_WAR_MODE") }
    end
    return out
end

-- Every tag this client can detect, each once: what is active now first,
-- then the fixed kinds, classes, instances and zones.
function Ctx.Options()
    local out, seen = {}, {}
    local function add(list)
        for i = 1, #list do
            local e = list[i]
            local k = Key(e)
            if not seen[k] then seen[k] = true out[#out + 1] = e end
        end
    end
    add((Ctx.Active()))
    add(Fixed())
    add(Classes())
    add(Instances())
    add(Zones())
    return out
end

-- How well a tag's name matches what was typed: a hit at the start of a
-- word beats one inside it; nil for none.
function Ctx.MatchScore(entry, query)
    if query == "" then return 1 end
    local name = slower(entry.name or tostring(entry.id))
    local s = sfind(name, query, 1, true)
    if not s then return nil end
    local wordStart = s == 1 or name:sub(s - 1, s - 1):match("[%s%-']") ~= nil
    return (wordStart and 2000 or 1000) - s + Ctx.Priority(entry)
end

-- Watching --------------------------------------------------------------------------

local CHANGE_EVENTS = {
    "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "PLAYER_ENTERING_WORLD",
    "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED", "PLAYER_SPECIALIZATION_CHANGED",
    "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "PLAYER_FLAGS_CHANGED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_UPDATE_RESTING", "DUEL_REQUESTED", "DUEL_FINISHED",
}

local watcher = CreateFrame("Frame")
local byEvent = {}
for _, w in ipairs(WINDOWS) do
    byEvent[w.open], byEvent[w.close] = { w.id, true }, { w.id, false }
end
for ev in pairs(byEvent) do pcall(watcher.RegisterEvent, watcher, ev) end
for _, ev in ipairs(CHANGE_EVENTS) do pcall(watcher.RegisterEvent, watcher, ev) end
watcher:SetScript("OnEvent", function(_, event, arg)
    if event == "PLAYER_FLAGS_CHANGED" and arg ~= "player" then return end
    if event == "DUEL_REQUESTED" then
        BeginDuel(arg)
    elseif event == "DUEL_FINISHED" or event == "PLAYER_ENTERING_WORLD" then
        duel = nil
    end
    local w = byEvent[event]
    if w then windowOpen[w[1]] = w[2] or nil end
    if onChange then onChange(event) end
end)

-- A challenge sent: to the target, or to the unit or name given.
if StartDuel then
    hooksecurefunc("StartDuel", function(who)
        local unit = (who == nil or who == "") and "target" or (type(who) == "string" and UnitExists(who) and who) or nil
        BeginDuel(unit and GetUnitName(unit, false) or who, unit)
        if onChange then onChange("DUEL") end
    end)
end

-- fn(event) runs whenever what is active may have changed.
function Ctx.SetOnChange(fn) onChange = fn end
