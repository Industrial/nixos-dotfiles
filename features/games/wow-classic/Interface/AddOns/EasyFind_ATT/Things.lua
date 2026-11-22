-- All The Things in EasyFind's search: its marks on EasyFind's own rows
-- (where a thing comes from, whether the account has it, directions to
-- each source), and rows of its own for what EasyFind does not list (its
-- quests, unless Questie lists them). Its data is read at runtime, never
-- copied.
local _, ns = ...
local API = EasyFind and EasyFind.API
if not (API and API.VERSION == 1) then return end
-- Loaded beside All The Things (OptionalDeps), nothing without it.
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
if not (IsAddOnLoaded and IsAddOnLoaded("AllTheThings")) then return end

local L = ns.L
-- A decorator's @scope and candidates, the way onto EasyFind's own rows, came in API MINOR 6.
if (API.MINOR or 0) < 6 then
    print(string.format("|cff66ccff%s:|r %s", L["EXT_NAME"], L["NEEDS_EASYFIND"]))
    return
end
local KEY = "att"
local QUEST_KEY = "attquests"
-- With Questie's rows (EasyFind [Questie]) ATT lists no quests of its own:
-- its info goes onto the quests Questie shows. Both load first
-- (OptionalDeps), so this reads true.
local QUESTIE = IsAddOnLoaded("Questie") and IsAddOnLoaded("EasyFind_Questie")
local ICON = "Interface\\AddOns\\EasyFind_ATT\\things"
local MAX_SPOTS = 40        -- coordinates read for one source
local MAX_DEPTH = 10        -- parent levels walked
local MAX_SOURCES = 8       -- source lines in a tooltip or menu
local MAX_PROVIDERS = 6     -- creatures and objects looked up for a place
local MAP_WAIT_SECONDS = 0.5
local BUDGET_MS = 2         -- indexing time per frame, kept small: ATT is heavy already
local RETRIES = 6           -- passes over quests the client has not named yet
local RETRY_SECONDS = 2
local REPORTED_ERRORS = 3   -- indexing errors sent to the error frame
local MAX_KEYWORDS = 12

local C_Map, C_Timer, C_MountJournal, C_QuestLog = C_Map, C_Timer, C_MountJournal, C_QuestLog
local sformat, tconcat, tinsert, mhuge, slower = string.format, table.concat, table.insert, math.huge, string.lower
local IsAltKeyDown, debugprofilestop, debugstack, geterrorhandler = IsAltKeyDown, debugprofilestop, debugstack, geterrorhandler
local issecretvalue = issecretvalue

-- ATT's functions, bound when it says it is ready; nil until then.
local A = {}
-- The quest index: one row per quest ATT knows, its group in a side table.
local S = { ready = false, built = false, rows = {}, byKey = {}, groups = {}, pending = {}, mapSets = {}, errors = 0 }

-- Its filter switches, its own beside Questie's.
local DB_VERSION = 1
local function DB()
    EasyFindATTDB = EasyFindATTDB or {}
    local db = EasyFindATTDB
    if db.hideCompleted == nil then db.hideCompleted = true end
    db.infoOff = db.infoOff or {}
    db.dbVersion = DB_VERSION
    return db
end

-- ATT's info by the kind of row it goes on, a switch each; only the kinds
-- this client has rows of (no mount journal on Era). Off leaves the rows.
local INFO_KINDS = {
    { key = "quests", label = L["KIND_QUESTS"] },
    { key = "mounts", label = L["KIND_MOUNTS"], api = "C_MountJournal" },
    { key = "pets", label = L["KIND_PETS"], api = "C_PetJournal" },
    { key = "toys", label = L["KIND_TOYS"], api = "C_ToyBox" },
    { key = "appearances", label = L["KIND_APPEARANCES"], api = "C_TransmogCollection" },
    { key = "heirlooms", label = L["KIND_HEIRLOOMS"], api = "C_Heirloom" },
    { key = "titles", label = L["KIND_TITLES"], api = "GetNumTitles" },
    { key = "achievements", label = L["KIND_ACHIEVEMENTS"], api = "C_AchievementInfo" },
    { key = "decor", label = L["KIND_DECOR"], api = "C_HousingCatalog" },
    { key = "recipes", label = L["KIND_RECIPES"] },
    { key = "items", label = L["KIND_ITEMS"] },
}
local KIND_OF_CATEGORY = {
    Mount = "mounts", Pet = "pets", Toy = "toys", Appearance = "appearances", Heirloom = "heirlooms",
    Title = "titles", Achievement = "achievements", Housing = "decor", Profession = "recipes",
    Item = "items", Loot = "items",
}

local function KindOf(row)
    if row.attQuestID or row.questId then return "quests" end
    return KIND_OF_CATEGORY[row.category]
end

local function InfoOn(row)
    local kind = KindOf(row)
    return kind ~= nil and not DB().infoOff[kind]
end

local function Say(msg)
    print(sformat("|cff66ccff%s:|r %s", L["EXT_NAME"], msg))
end

local function Trace(err)
    S.errors = S.errors + 1
    if S.errors <= REPORTED_ERRORS then geterrorhandler()(err .. "\n" .. debugstack(2)) end
end

-- ==== ATT ===================================================================

local function Bind()
    local app = AllTheThings
    if type(app) ~= "table" then return false end
    local need = { "SearchForField", "SearchForObject", "AddEventHandler" }
    for i = 1, #need do
        if type(app[need[i]]) ~= "function" then return false end
    end
    A.app = app
    A.Object = app.SearchForObject
    A.Container = type(app.GetRawFieldContainer) == "function" and app.GetRawFieldContainer or function() return nil end
    -- The raw read leaves no empty entry behind in ATT's cache.
    A.Field = type(app.GetRawField) == "function" and app.GetRawField or app.SearchForField
    A.Popout = type(app.CreateMiniListForGroup) == "function" and app.CreateMiniListForGroup or nil
    -- ATT's own checks: the character's class and race, and what its
    -- settings count as removed from the game.
    local filters = app.Modules and app.Modules.Filter and app.Modules.Filter.Filters
    local function Filter(name) return filters and type(filters[name]) == "function" and filters[name] or nil end
    A.ForCharacter = Filter("RecursiveDefaultCharacterRequirementsFilter")
    A.Obtainable = Filter("RecursiveUnobtainableFilter")
    local rd = app.Modules and app.Modules.RetrievingData
    A.IsRetrieving = rd and type(rd.IsRetrieving) == "function" and rd.IsRetrieving or nil
    return true
end

-- Text without color codes, links and textures; nil while the client is
-- still sending it, or when it withholds it (a secret string takes no read).
local function Plain(s)
    if type(s) ~= "string" or (issecretvalue and issecretvalue(s) == true) then return nil end
    s = s:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:match("^%s*(.-)%s*$")
    s = s:match("^%[(.*)%]$") or s
    if s == "" or s == RETRIEVING_DATA or (A.IsRetrieving and A.IsRetrieving(s)) then return nil end
    return s
end

local function Name(g)
    return Plain(g.name) or Plain(g.text)
end

local function Parent(g)
    return g.sourceParent or g.parent
end

-- Difficulty rows say nothing about a place: skipped on the way up.
local function Named(g)
    if g.key == "difficultyID" then return nil end
    return Name(g)
end

local function IsPlace(g)
    return g.mapID ~= nil or g.instanceID ~= nil
end

-- "Baron Rivendare, Stratholme": a group's name, then the nearest zone
-- or instance above it when that is another name.
local function Where(g)
    local n = Named(g)
    local p, depth = Parent(g), 0
    while p and depth < MAX_DEPTH and p.key ~= "ROOT" do
        if IsPlace(p) then
            local pn = Named(p)
            if pn and pn ~= n then return n and (n .. ", " .. pn) or pn end
            break
        end
        p, depth = Parent(p), depth + 1
    end
    return n
end

-- What a player can go to: a creature, object, encounter, quest,
-- achievement, zone or instance. ATT's headers and categories ("Reagent")
-- say nothing about where a thing comes from.
local SOURCE_KEYS = { npcID = true, creatureID = true, objectID = true, encounterID = true, questID = true,
                      achievementID = true, mapID = true, instanceID = true }

-- Where a thing comes from: its nearest such parent, placed; nil when ATT
-- files it under categories only.
local function SourceLine(g)
    local p, depth = Parent(g), 0
    while p and depth < MAX_DEPTH and p.key ~= "ROOT" do
        if SOURCE_KEYS[p.key] and Named(p) then return Where(p) end
        p, depth = Parent(p), depth + 1
    end
    return nil
end

-- ATT's own path to a reference: "Dungeons & Raids > Stratholme > Baron Rivendare".
local function SourcePath(g)
    local parts, p, depth = {}, Parent(g), 0
    while p and depth < MAX_DEPTH and p.key ~= "ROOT" do
        local n = Named(p)
        if n then tinsert(parts, 1, n) end
        p, depth = Parent(p), depth + 1
    end
    return #parts > 0 and tconcat(parts, " > ") or nil
end

-- ATT's hidden quest triggers, in their window or flagged on their own
-- (bonus reputation): bookkeeping, not quests. Checked before the name,
-- which some of them cannot build.
local function Hidden(g)
    if g.isHQT then return true end
    local p, depth = g, 0
    while p and depth < MAX_DEPTH do
        if p._hqt then return true end
        p, depth = Parent(p), depth + 1
    end
    return false
end

-- The nearest zone or instance above a group.
local function ZoneOf(g)
    local p, depth = Parent(g), 0
    while p and depth < MAX_DEPTH and p.key ~= "ROOT" do
        if IsPlace(p) then return Named(p) end
        p, depth = Parent(p), depth + 1
    end
    return nil
end

-- What finds a quest besides its name: the headers above it and what it
-- rewards ("Shadowmourne" finds its questline).
local function Keywords(g)
    local words, p, depth = {}, Parent(g), 0
    while p and depth < MAX_DEPTH and p.key ~= "ROOT" and #words < MAX_KEYWORDS do
        local n = Named(p)
        if n then words[#words + 1] = slower(n) end
        p, depth = Parent(p), depth + 1
    end
    local kids = g.g
    for i = 1, kids and #kids or 0 do
        if #words >= MAX_KEYWORDS then break end
        local kid = kids[i]
        local n = kid.itemID and Name(kid)
        if n then words[#words + 1] = slower(n) end
    end
    return words
end

-- Collected, or for a quest, done.
local function Done(g)
    return (g.saved or g.collected) and true or false
end

-- ==== places ================================================================

-- ATT coordinates ({ [mapID] = { { x, y }, ... } }, map percent) as
-- EasyFind destinations.
local function AddCoords(g, out, label)
    local coords = g.coords
    if type(coords) ~= "table" then return end
    for mapID, list in pairs(coords) do
        if type(mapID) == "number" and type(list) == "table" then
            for i = 1, #list do
                if #out >= MAX_SPOTS then return end
                local c = list[i]
                if type(c) == "table" and type(c[1]) == "number" and type(c[2]) == "number" then
                    out[#out + 1] = { name = label, mapID = mapID, x = c[1] / 100, y = c[2] / 100 }
                end
            end
        end
    end
end

-- Where one reference leads: its own coordinates and its children's,
-- else the first parent's that has any.
local function RefSpots(g, out)
    local before = #out
    local label = Where(g)
    AddCoords(g, out, label)
    local kids = g.g
    for i = 1, kids and #kids or 0 do AddCoords(kids[i], out, label) end
    if #out > before then return end
    local p, depth = Parent(g), 0
    while p and depth < MAX_DEPTH and p.key ~= "ROOT" do
        AddCoords(p, out, Where(p))
        if #out > before then return end
        p, depth = Parent(p), depth + 1
    end
end

local PROVIDER_FIELD = { n = "npcID", o = "objectID" }

-- The creatures and objects a reference names (providers, drops, quest
-- givers), each looked up for its own places.
local function ProviderSpots(g, out)
    local ids, n = {}, 0
    local function Add(field, id)
        if n < MAX_PROVIDERS and type(id) == "number" and id > 0 then
            n = n + 1
            ids[n] = { field, id }
        end
    end
    local providers = g.providers
    for i = 1, type(providers) == "table" and #providers or 0 do
        local p = providers[i]
        if type(p) == "table" and PROVIDER_FIELD[p[1]] then Add(PROVIDER_FIELD[p[1]], p[2]) end
    end
    local parent = Parent(g)
    local lists = { g.crs, g.qgs, parent and parent.crs }
    for l = 1, 3 do
        local list = lists[l]
        for i = 1, type(list) == "table" and #list or 0 do Add("npcID", list[i]) end
    end
    for i = 1, n do
        local groups = A.Object(ids[i][1], ids[i][2], "field", true)
        for j = 1, type(groups) == "table" and #groups or 0 do
            RefSpots(groups[j], out)
            if #out >= MAX_SPOTS then return end
        end
    end
end

-- Where the player stands, as world coordinates on its continent.
local function PlayerWorld()
    local m = C_Map.GetBestMapForUnit("player")
    local pos = m and C_Map.GetPlayerMapPosition(m, "player")
    if not pos then return nil end
    local ci, wp = C_Map.GetWorldPosFromMapPos(m, pos)
    if not wp then return nil end
    local x, y = wp:GetXY()
    return ci, x, y
end

-- The spot nearest the player on its continent, else the first the GPS
-- can reach.
local function Nearest(spots)
    local ci, px, py = PlayerWorld()
    local best, bestD
    for i = 1, #spots do
        local s = spots[i]
        if API.CallAction("gps", "canNavigate", s) ~= false then
            local d = mhuge
            if ci then
                local sci, wp = C_Map.GetWorldPosFromMapPos(s.mapID, CreateVector2D(s.x, s.y))
                if wp and sci == ci then
                    local wx, wy = wp:GetXY()
                    d = (wx - px) ^ 2 + (wy - py) ^ 2
                end
            end
            if not best or d < bestD then best, bestD = s, d end
        end
    end
    return best
end

-- Without the GPS, the game's own waypoint, set once the world map is
-- closed: set under it, the pin's Shift-click share is refused.
local function PlaceWaypoint()
    local dest = S.waypoint
    if not dest then return end
    if WorldMapFrame and WorldMapFrame:IsShown() then return C_Timer.After(MAP_WAIT_SECONDS, PlaceWaypoint) end
    S.waypoint = nil
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(dest.mapID, dest.x, dest.y))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
end

local function Navigate(dest)
    if API.HasAction("gps", "navigate") then
        API.CallAction("gps", "navigate", dest, { popout = true })
    elseif C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(dest.mapID) then
        local waiting = S.waypoint ~= nil
        S.waypoint = dest
        if not waiting then PlaceWaypoint() end
    end
end

-- A spot named for the thing and marked with its icon; the last step's
-- sentence says what stands there ("Travel to Baron Rivendare, Stratholme").
local function Labeled(spot, name, icon)
    if spot.name then spot.step = sformat(L["STEP_FMT"], spot.name) end
    spot.name, spot.icon = name, icon
    return spot
end

local function DestFor(spots, name, icon)
    local dest = Nearest(spots)
    return dest and Labeled(dest, name, icon) or nil
end

-- Every place a thing is found: each reference's coordinates, else the
-- places of what provides it.
local function Spots(key, id)
    local out = {}
    local refs = A.Field(key, id)
    for i = 1, refs and #refs or 0 do
        RefSpots(refs[i], out)
        if #out >= MAX_SPOTS then return out end
    end
    if #out == 0 then
        for i = 1, refs and #refs or 0 do
            ProviderSpots(refs[i], out)
            if #out >= MAX_SPOTS then break end
        end
    end
    return out
end

-- ==== tooltip and menu ======================================================

-- ATT's own popout window for the thing.
local function OpenInATT(g)
    if A.Popout and g then A.Popout(A.app, g) end
end

-- Only what ATT counts toward a collection has a state; a quest says
-- whether it is done.
local function StateLine(g, tt)
    if g.key == "questID" then
        if Done(g) then tt:AddLine(L["COMPLETED"], 0, 1, 0) else tt:AddLine(L["NOT_COMPLETED"], 1, 0.5, 0.5) end
        return
    end
    if not g.collectible then return end
    if g.collected then
        tt:AddLine(L["COLLECTED"], 0, 1, 0)
    else
        tt:AddLine(L["NOT_COLLECTED"], 1, 0.5, 0.5)
    end
end

-- Each distinct source path of the thing's references, up to a cap.
local function SourcePaths(key, id)
    local refs = A.Field(key, id)
    local seen, out = {}, {}
    for i = 1, refs and #refs or 0 do
        local path = SourcePath(refs[i])
        if path and not seen[path] then
            seen[path] = true
            out[#out + 1] = path
            if #out >= MAX_SOURCES then break end
        end
    end
    return out
end

local function SourceLines(paths, tt)
    if #paths == 0 then return end
    tt:AddLine(L["SOURCES"])
    for i = 1, #paths do tt:AddLine(paths[i], 0.8, 0.8, 0.8, true) end
end

-- closes: the search bar steps aside for the window the action opens.
local function Action(label, fn, closes)
    return { kind = "action", label = label, onClick = fn, closes = closes }
end

-- ATT's window on the thing. Directions are the row's GPS button, where a
-- row has a place; never a menu entry.
local function MenuRows(g)
    if not A.Popout then return nil end
    return { Action(L["MENU_OPEN"], function() OpenInATT(g) end, true) }
end

-- ==== its own quest rows ====================================================

-- Fixed at build: whether it is done is read live, on hover.
local function QuestText(zone)
    return zone and sformat(L["QUEST_FMT"], zone) or L["QUEST"]
end

-- A quest's row from its best ATT group; nil while the client has not
-- named it, false when it is no quest of the player's.
local function MakeQuestRow(id)
    local g = A.Object("questID", id, "key")
    if not g or Hidden(g) then return false end
    if A.ForCharacter and not A.ForCharacter(g) then return false end
    if A.Obtainable and not A.Obtainable(g) then return false end
    local name = Name(g)
    if not name then return nil end
    if not SourcePath(g) then return false end
    local zone = ZoneOf(g)
    local words = Keywords(g)
    -- nameLower here: what EasyFind would add itself counts toward the extension.
    -- questId, Questie's own field: where EasyFind sees both rows of one quest.
    local row = { name = name, nameLower = slower(name), key = "questID", id = id, attQuestID = id, questId = id,
                  k = "questID:" .. id, zone = zone,
                  icon = g.icon, keywords = words, keywordsLower = words, searchCommandDesc = QuestText(zone) }
    S.groups[row] = g
    return row
end

local function AddRow(row)
    S.rows[#S.rows + 1] = row
    S.byKey[row.k] = row
end

-- After ATT changes, only the shown rows repaint; the quest rows stay as
-- built (ATT fires this often, and a pass over every quest hitched).
local function Refresh()
    if S.refreshPending or not S.ready then return end
    S.refreshPending = true
    C_Timer.After(0.5, function()
        S.refreshPending = false
        S.mapSets = {}
        API.RefreshRowDecorations()
    end)
end

-- New quest rows, or new switches, reach EasyFind's search.
local function RowsChanged()
    API.RefreshSearchProvider(QUEST_KEY)
end

-- One row per queued quest, a few milliseconds a frame; a newer build
-- ends an older one's chain. Later passes, on the same budget, name the
-- quests the client had not named; the rows reach the search once, when
-- the passes end. Every refresh has EasyFind index all 22,000 quest rows
-- again in the background and save that index (one per pass hitched
-- seven times in half a minute, retail 2026-11-09); one per session also
-- lets the saved index match the next session's rows.
local function Step(gen)
    if gen ~= S.gen then return end
    local t0 = debugprofilestop()
    local queue, n, i = S.queue, #S.queue, S.cursor
    while i <= n do
        local ok, row = xpcall(MakeQuestRow, Trace, queue[i])
        if ok and row then
            AddRow(row)
        elseif ok and row == nil then
            S.pending[#S.pending + 1] = queue[i]
        end
        i = i + 1
        if debugprofilestop() - t0 > BUDGET_MS then break end
    end
    S.cursor = i
    if i <= n then return C_Timer.After(0, function() Step(gen) end) end
    if #S.pending > 0 and S.retries < RETRIES then
        C_Timer.After(RETRY_SECONDS, function()
            if gen ~= S.gen then return end
            S.retries = S.retries + 1
            S.queue, S.pending, S.cursor = S.pending, {}, 1
            Step(gen)
        end)
        return
    end
    S.building, S.built = false, true
    RowsChanged()
end

local function Build()
    S.rows, S.byKey, S.groups, S.pending, S.mapSets = {}, {}, {}, {}, {}
    S.queue, S.cursor, S.retries, S.errors, S.built = {}, 1, 0, 0, false
    S.gen = (S.gen or 0) + 1
    local container = A.Container("questID")
    if type(container) == "table" then
        for id in pairs(container) do S.queue[#S.queue + 1] = id end
    end
    S.building = true
    Step(S.gen)
end

local function QuestGroup(row)
    return S.ready and row.attQuestID and (S.groups[row] or A.Object("questID", row.attQuestID, "key")) or nil
end

-- Where the quest starts; while it is still to be taken, its end wears the
-- game's quest-offer "!" in the GPS.
local function QuestDest(row)
    local dest = DestFor(Spots("questID", row.id), row.name, row.icon)
    local QL = C_QuestLog
    if dest and QL and not (QL.IsOnQuest and QL.IsOnQuest(row.id))
        and not (QL.IsQuestFlaggedCompleted and QL.IsQuestFlaggedCompleted(row.id)) then
        dest.questMark = "offer"
    end
    return dest
end

-- A click asks for directions to where the quest starts; Alt opens ATT's
-- window on it.
local function QuestSelect(row)
    local g = QuestGroup(row)
    if not g then return end
    if IsAltKeyDown() then return OpenInATT(g) end
    local dest = QuestDest(row)
    if dest then Navigate(dest) else Say(sformat(L["NO_PLACE"], row.name)) end
end

local function QuestTooltip(row, tt)
    local g = QuestGroup(row)
    if not g then return false end
    tt:SetText(row.name)
    tt:AddLine(row.zone and sformat(L["QUEST_FMT"], row.zone) or L["QUEST"], 1, 1, 1)
    StateLine(g, tt)
    local paths = SourcePaths("questID", row.id)
    if #paths > 0 then tt:AddLine(" ") end
    SourceLines(paths, tt)
    return true
end

-- ==== EasyFind's rows =======================================================

-- The ATT thing behind a row, by the row's fields: a quest of Questie's or
-- ours, else by the row's category. ATT keys mounts by spell; an
-- appearance row's id is its source.
local function RowThing(row)
    if row.attQuestID then return "questID", row.attQuestID end
    if row.questId then return "questID", row.questId end
    local cat = row.category
    if cat == "Mount" then
        local spell, id = row.spellID, row.mountID
        if not spell and id and C_MountJournal and C_MountJournal.GetMountInfoByID then
            spell = select(2, C_MountJournal.GetMountInfoByID(id))
        end
        return "mountID", spell
    elseif cat == "Pet" then return "speciesID", row.speciesID
    elseif cat == "Toy" then return "toyID", row.toyItemID
    elseif cat == "Appearance" then return "sourceID", row.appearanceItemID
    elseif cat == "Item" or cat == "Loot" then return "itemID", row.itemID
    elseif cat == "Heirloom" then return "itemID", row.heirloomItemID
    elseif cat == "Title" then return "titleID", row.titleID
    elseif cat == "Achievement" then return "achievementID", row.achievementID
    elseif cat == "Profession" then return "recipeID", row.professionRecipeID
    elseif cat == "Housing" and not row.isRoom then return "decorID", row.housingRecordID
    end
    return nil
end

-- ATT's best group for a row, cached until ATT changes.
local decorated = {}
local function Decorated(row)
    local key, id = RowThing(row)
    if not (key and type(id) == "number") then return nil end
    local k = key .. ":" .. id
    local d = decorated[k]
    if d == nil then
        local g = A.Object(key, id, "key") or A.Object(key, id, "field")
        d = g and { g = g, key = key, id = id } or false
        decorated[k] = d
    end
    return d or nil
end

-- The things nested under a map's groups (and its sub maps'), by each
-- group's own key; cached until the zone or ATT changes.
local function MapSet(mapID)
    local set = S.mapSets[mapID]
    if set then return set end
    set = {}
    local seen = {}
    local function Walk(g, depth)
        if depth > MAX_DEPTH or seen[g] then return end
        seen[g] = true
        local key = g.key
        if key and g[key] then set[key .. ":" .. tostring(g[key])] = true end
        local kids = g.g
        for i = 1, kids and #kids or 0 do Walk(kids[i], depth + 1) end
    end
    local results = A.Field("mapID", mapID)
    local root
    for i = 1, results and #results or 0 do
        local r = results[i]
        if r.key == "mapID" and r.mapID == mapID then root = r end
        Walk(r, 0)
    end
    local maps = root and root.maps
    for i = 1, type(maps) == "table" and #maps or 0 do
        if maps[i] ~= mapID then
            local sub = A.Field("mapID", maps[i])
            for j = 1, sub and #sub or 0 do Walk(sub[j], 0) end
        end
    end
    S.mapSets[mapID] = set
    return set
end

-- @att with nothing typed: what is left to get on the map here.
local function Browse(row)
    local d = S.ready and Decorated(row)
    if not d or Done(d.g) then return false end
    local mapID = C_Map.GetBestMapForUnit("player")
    local here = mapID and MapSet(mapID)
    local g = d.g
    return (here and g.key and here[g.key .. ":" .. tostring(g[g.key])]) == true
end

-- The rows it takes, named by field: ATT's own lookup tables, keyed by id.
local function Candidates()
    if not S.ready then return {} end
    local C = A.Container
    local quests = C("questID")
    return {
        spellID = C("mountID"), speciesID = C("speciesID"), toyItemID = C("toyID"),
        appearanceItemID = C("sourceID"), itemID = C("itemID"), heirloomItemID = C("itemID"),
        titleID = C("titleID"), achievementID = C("achievementID"), professionRecipeID = C("recipeID"),
        housingRecordID = C("decorID"), questId = QUESTIE and quests or nil, attQuestID = quests,
    }
end

-- Its own quest rows are in its scope but carry their own tooltip and menu.
local function Own(row)
    return row.attQuestID ~= nil
end

local function RegisterDecorator()
    API.RegisterRowDecorator({
        -- One entry: in the menu itself, with its icon, no flyout of one.
        id = KEY, label = L["EXT_NAME"],
        aliases = { "att", "things" },
        candidates = Candidates,
        browse = Browse,
        applies = function(row) return S.ready and InfoOn(row) and Decorated(row) ~= nil end,
        subtext = function(row)
            if Own(row) or row.questId then return nil end
            local d = S.ready and Decorated(row)
            local from = d and SourceLine(d.g)
            return from and sformat(L["FROM_FMT"], from) or nil
        end,
        tooltip = function(row, _, tt)
            -- ATT already put its own lines on this tooltip (an item's, a
            -- toy's, a mount's): never a second copy.
            if Own(row) or tt.ATT_AttachComplete ~= nil then return end
            local d = S.ready and Decorated(row)
            if not d then return end
            local paths = SourcePaths(d.key, d.id)
            if not d.g.collectible and d.key ~= "questID" and #paths == 0 then return end
            tt:AddLine(" ")
            tt:AddLine(L["EXT_NAME"], 1, 0.82, 0)
            StateLine(d.g, tt)
            SourceLines(paths, tt)
        end,
        menu = function(row)
            if Own(row) then return nil end
            local d = S.ready and Decorated(row)
            if not d then return nil end
            return MenuRows(d.g)
        end,
        -- Uncollected only, for EasyFind's own rows.
        keep = function(row)
            local d = S.ready and Decorated(row)
            if not d or not d.g.collectible then return true end
            return not d.g.collected
        end,
    })
end

-- ==== registration ==========================================================

API.RegisterExtension({
    id = KEY,
    name = L["EXT_NAME"],
    description = L["EXT_DESC"],
    icon = ICON,
    keywords = { "att", "allthethings", "collect", "collection" },
    -- Its button opens @att: what is left to get here.
    scope = KEY,
})

-- At load, so its button finds the @att scope from login; it takes rows
-- once ATT is ready.
RegisterDecorator()

-- The rows EasyFind gets: the built list through the switches.
-- EasyFind 5.4.0 on: the frame goes while the 22,000 quests are checked
-- (one 55 ms frame on retail).
local Checkpoint = API.SliceCheckpoint or function() end

local function Shown()
    local db = DB()
    if db.infoOff.quests then return {} end
    if not (db.hideCompleted or db.nearMe) then return S.rows end
    local mapID = db.nearMe and C_Map.GetBestMapForUnit("player")
    local here = mapID and MapSet(mapID)
    local out = {}
    for i = 1, #S.rows do
        if i % 256 == 0 then Checkpoint() end
        local row = S.rows[i]
        local g = S.groups[row]
        if not (db.hideCompleted and g and Done(g)) and not (db.nearMe and not (here and here[row.k])) then
            out[#out + 1] = row
        end
    end
    return out
end

local function Option(key, label)
    return {
        label = label,
        get = function() return DB()[key] == true end,
        set = function(on)
            -- False stays: nil reads as the default, which is on for one.
            DB()[key] = on == true
            RowsChanged()
        end,
    }
end

local function InfoOption(kind)
    return {
        label = kind.label,
        get = function() return not DB().infoOff[kind.key] end,
        set = function(on)
            DB().infoOff[kind.key] = (not on) or nil
            API.RefreshRowDecorations()
            if kind.key == "quests" then RowsChanged() end
        end,
    }
end

-- Its info switches, then the switches for its own quest rows.
local function Options()
    local out = { { header = L["OPT_INFO_HEADER"] } }
    for i = 1, #INFO_KINDS do
        local kind = INFO_KINDS[i]
        if not kind.api or _G[kind.api] then out[#out + 1] = InfoOption(kind) end
    end
    if not QUESTIE then
        out[#out + 1] = { header = L["OPT_QUESTS_HEADER"] }
        out[#out + 1] = Option("hideCompleted", L["OPT_HIDE_COMPLETED"])
        out[#out + 1] = Option("nearMe", L["OPT_NEAR_ME"])
    end
    return out
end

do
    API.RegisterSearchProvider({
        key = QUEST_KEY,
        label = L["QUESTS"],
        category = L["QUEST"],
        extension = KEY,
        -- Found by plain search: loaded once a search finds little, then
        -- searched every time after.
        lowResults = true,
        -- Its row in the filter menu holds the info switches, so it is there
        -- with Questie too, its quest rows then none.
        options = Options(),
        -- Built the first time EasyFind asks, not at load: nothing to pay
        -- until the search is used.
        rows = function()
            if not S.ready or QUESTIE then return {} end
            if not (S.built or S.building) then
                S.building = true
                C_Timer.After(0, Build)
            end
            return Shown()
        end,
        select = QuestSelect,
        tooltip = QuestTooltip,
        hint = { click = L["HINT_DIRECTIONS"], alt = L["HINT_OPEN"] },
        place = function(row) return QuestGroup(row) and QuestDest(row) or nil end,
        places = function(row)
            if not QuestGroup(row) then return nil end
            local spots = Spots("questID", row.id)
            for i = 1, #spots do Labeled(spots[i], row.name, row.icon) end
            return spots
        end,
        menu = function(row)
            local g = QuestGroup(row)
            return g and MenuRows(g) or nil
        end,
    })
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function()
    S.mapSets = {}
    if DB().nearMe and S.built then RowsChanged() end
end)

local function OnReady()
    if not Bind() then return Say(L["NOT_READY"]) end
    S.ready = true
    local function Changed()
        decorated = {}
        Refresh()
    end
    A.app.AddEventHandler("OnThingCollected", Changed)
    A.app.AddEventHandler("OnRefreshCollectionsDone", Changed)
    A.app.AddEventHandler("OnSettingsNeedsRefresh", Changed)
    events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    API.RefreshRowDecorations()
end

local app = AllTheThings
if type(app) == "table" and type(app.AddEventHandler) == "function" then
    app.AddEventHandler("OnReady", OnReady)
else
    Say(L["NOT_READY"])
end

-- For the dev probe (EasyFind_ATTDev): the walks, the row lookup and the
-- quest row build's steps.
EasyFindATT = ns
ns.S, ns.A = S, A
ns.SourceLine, ns.SourcePath, ns.Where, ns.Decorated, ns.RowThing, ns.MenuRows, ns.MapSet, ns.Build =
    SourceLine, SourcePath, Where, Decorated, RowThing, MenuRows, MapSet, Build
ns.Hidden, ns.Name, ns.ZoneOf, ns.Keywords, ns.MakeQuestRow = Hidden, Name, ZoneOf, Keywords, MakeQuestRow
