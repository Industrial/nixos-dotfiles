-- HandyNotes' map pins in EasyFind, read as its own map reads them: a pin
-- EasyFind lists adds to EasyFind's row, any other is a row of its own.
local _, ns = ...
local API = EasyFind and EasyFind.API
if not (API and API.VERSION == 1) then return end

local L = ns.L
-- Loaded beside HandyNotes (OptionalDeps), nothing without it.
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
if not (IsAddOnLoaded and IsAddOnLoaded("HandyNotes")) then return end

-- HasRow and HasCreature say which pins EasyFind lists itself; MINOR 7
-- lets its marked rows share @hn and our words, and places our rows.
if (API.MINOR or 0) < 7 then
    local notice = CreateFrame("Frame")
    notice:RegisterEvent("PLAYER_LOGIN")
    notice:SetScript("OnEvent", function()
        notice:UnregisterEvent("PLAYER_LOGIN")
        print("|cff66ccff" .. L["EXT_NAME"] .. ":|r " .. L["NEEDS_NEWER"])
    end)
    return
end
local KEY = "handynotes"
local ICON = "Interface\\AddOns\\EasyFind_HandyNotes\\map"
local COSMIC, AZEROTH = 946, 947
local WALK_MS = 4                          -- each frame's share of the pin walk
local RESOLVE_WAIT, RESOLVE_TRIES = 2, 3   -- names the server has not sent yet
local REWALK_WAIT = 3                      -- after a plugin says its pins changed
local LOGIN_WALK_WAIT = 3                  -- after login's own loading
local NAME_FIELDS = { "label", "name", "title", "text", "desc" }
local NOTE_FIELDS = { "description", "note", "desc" }
-- A node's own word for what it is ("auctioneers", "Herbalism", "rare").
local KIND_FIELDS = { "category", "group", "type", "profession", "description" }
local KIND_MAX = 40   -- longer text is a note, not a kind

local C_Map, C_Item, C_QuestLog, C_Spell, C_CurrencyInfo, C_Timer, C_AddOns =
      C_Map, C_Item, C_QuestLog, C_Spell, C_CurrencyInfo, C_Timer, C_AddOns
local IsShiftKeyDown, CreateVector2D, GetTime, debugprofilestop = IsShiftKeyDown, CreateVector2D, GetTime, debugprofilestop
local sformat, tsort, floor, wipe = string.format, table.sort, math.floor, wipe
local issecretvalue = issecretvalue or function(_) return false end
-- Era, TBC and Mists: the classic quest title and faction calls, an NPC's
-- name from a hidden tooltip, no user waypoints or map pin links.
local QuestTitle = C_QuestLog.GetTitleForQuestID or C_QuestLog.GetQuestInfo
local RequestQuest = C_QuestLog.RequestLoadQuestByID
local FactionData = C_Reputation and C_Reputation.GetFactionDataByID
local TooltipLink = C_TooltipInfo and C_TooltipInfo.GetHyperlink
local WAYPOINTS = C_Map.SetUserWaypoint ~= nil and C_SuperTrack ~= nil
-- In a chat lockdown plugins read the calendar and more as secrets.
local InLockdown = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown or function() return false end
local RESTRICTION = "ADDON_RESTRICTION_STATE_CHANGED"
local RESTRICTION_EVENT = C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid(RESTRICTION)

-- Module state: HandyNotes once bound, the map list, per plugin its own
-- rows and the pins EasyFind lists, what to walk again.
local H = { ready = false, index = {}, lookup = {}, decor = {}, titles = {}, zones = {}, zoneOf = {}, npcs = {},
            dirty = {}, all = true, gens = {} }
local events = CreateFrame("Frame")

local function DB()
    EasyFindHandyNotesDB = EasyFindHandyNotesDB or {}
    return EasyFindHandyNotesDB
end

local function ErrorHandler(err)
    geterrorhandler()(err .. "\n" .. debugstack(2))
end

-- ==== names ================================================================

local function Strip(s)
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
             :gsub("\n", ", "):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function TooltipTitle(link)
    if TooltipLink then
        local data = TooltipLink(link)
        local line = data and data.lines and data.lines[1]
        return line and line.leftText
    end
    local scan = H.scan
    if not scan then
        scan = CreateFrame("GameTooltip", "EasyFindHandyNotesScan", nil, "GameTooltipTemplate")
        H.scan = scan
    end
    scan:SetOwner(WorldFrame, "ANCHOR_NONE")
    scan:SetHyperlink(link)
    local line = _G["EasyFindHandyNotesScanTextLeft1"]
    local text = scan:NumLines() > 0 and line and line:GetText() or nil
    scan:Hide()
    return text
end

local function NpcName(id)
    local name = H.npcs[id]
    if name then return name end
    name = TooltipTitle("unit:Creature-0-0-0-0-" .. id)
    if issecretvalue(name) or name == nil then return nil end
    if type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then return nil end
    H.npcs[id] = name
    return name
end

-- A criterion under 100 is an index into the achievement, above it an id.
local function CriteriaName(achievement, criterion)
    local ok, text
    if criterion < 100 then
        ok, text = pcall(GetAchievementCriteriaInfo, achievement, criterion)
    else
        ok, text = pcall(GetAchievementCriteriaInfoByID, achievement, criterion)
    end
    if ok and type(text) == "string" and text ~= "" then return text end
    return nil
end

local function AchievementName(id)
    local ok, _, name = pcall(GetAchievementInfo, id)
    return ok and name or nil
end

local function TokenName(what, id, sub, text)
    if what =="npc" then return NpcName(id) or text end
    if what =="item" then
        local name = C_Item.GetItemNameByID(id)
        if not name then C_Item.RequestLoadItemDataByID(id) end
        return name or text
    end
    if what == "quest" or what == "daily" then
        local name = QuestTitle(id)
        if not name and RequestQuest then RequestQuest(id) end
        return name or text
    end
    if what =="spell" then
        local name = C_Spell.GetSpellName(id)
        if not name then C_Spell.RequestLoadSpellData(id) end
        return name or text
    end
    if what =="achievement" then
        if sub then return CriteriaName(id, sub) or text end
        return AchievementName(id) or text
    end
    if what =="currency" then
        local info = C_CurrencyInfo.GetCurrencyInfo(id)
        return info and info.name or text
    end
    if what =="faction" then
        if FactionData then
            local info = FactionData(id)
            return info and info.name or text
        end
        return GetFactionInfoByID and GetFactionInfoByID(id) or text
    end
    if what =="map" then
        local info = C_Map.GetMapInfo(id)
        return info and info.name or text
    end
    if what =="area" then return C_Map.GetAreaInfo(id) or text end
    if what =="pet" and C_PetJournal then return C_PetJournal.GetPetInfoBySpeciesID(id) or text end
    return text
end

-- {kind:id}, {kind:id.sub}, {kind:id:text} become names, {kind:text} its text;
-- also whether a name is still on its way. Nil for a label left empty.
local function Render(label)
    local unresolved = false
    local out = label:gsub("{(%l+):(%d+)%.?(%d*):?([^{}]*)}", function(what, id, sub, text)
        local name = TokenName(what, tonumber(id), tonumber(sub), text ~= "" and text or nil)
        if name then return name end
        unresolved = true
        return ""
    end)
    out = Strip((out:gsub("{%l+:([^{}]*)}", "%1")))
    return out ~= "" and out or nil, unresolved
end

local function Get(node, key) return node[key] end

-- A plugin's node may answer a field through a getter that throws.
local function Field(node, key)
    local ok, value = pcall(Get, node, key)
    if ok then return value end
    return nil
end

-- A loot entry: an item id, or a table holding it ({ id }, { 1234, mount = ... }).
local function LootItem(entry)
    if type(entry) == "table" then entry = entry.id or entry[1] end
    return type(entry) == "number" and entry or nil
end

local function ItemName(id)
    local name = C_Item.GetItemNameByID(id)
    if not name then C_Item.RequestLoadItemDataByID(id) end
    return name
end

-- The names of what the pin drops, as far as the client knows them; true
-- second when one is still on its way.
local function LootNames(node)
    local loot = Field(node, "loot")
    if type(loot) ~= "table" then return nil, false end
    local names, missing = {}, false
    for i = 1, #loot do
        local id = LootItem(loot[i])
        local name = id and ItemName(id)
        if name then names[#names + 1] = name elseif id then missing = true end
    end
    return names, missing
end

-- A pin without a text field, named from the ids it carries.
local function IdName(node)
    local npc = Field(node, "npc")
    if type(npc) == "number" then
        local name = NpcName(npc)
        return name, name == nil
    end
    local achievement, criterion = Field(node, "achievement"), Field(node, "criteria")
    if type(criterion) == "table" then criterion = criterion[1] end
    if type(achievement) == "number" and type(criterion) == "number" then
        local name = CriteriaName(achievement, criterion)
        if name then return name, false end
    end
    local loot = Field(node, "loot")
    local item = type(loot) == "table" and LootItem(loot[1])
    if item then
        local name = ItemName(item)
        return name, name == nil
    end
    if type(achievement) == "number" then
        local name = AchievementName(achievement)
        if name then return name, false end
    end
    local currency = Field(node, "currency")
    if type(currency) == "number" then
        local info = C_CurrencyInfo.GetCurrencyInfo(currency)
        if info then return info.name, false end
    end
    return nil, false
end

-- The pin's name from the node its plugin keeps behind the coord: its
-- first text field with the tokens rendered, else its ids.
local function NameOf(node)
    for i = 1, #NAME_FIELDS do
        local value = Field(node, NAME_FIELDS[i])
        if type(value) == "string" and value ~= "" then
            if value:find("{", 1, true) then return Render(value) end
            local name = Strip(value)
            if name ~= "" then return name, false end
        end
    end
    return IdName(node)
end

-- Done as the plugin sees it: its own check, else its quests all flagged.
local function IsDone(node)
    local check = Field(node, "IsCompleted")
    if type(check) == "function" then
        local ok, done = pcall(check, node)
        return ok and done == true
    end
    local quest = Field(node, "quest")
    if type(quest) == "number" then return C_QuestLog.IsQuestFlaggedCompleted(quest) end
    if type(quest) == "table" and #quest > 0 then
        for i = 1, #quest do
            if not C_QuestLog.IsQuestFlaggedCompleted(quest[i]) then return false end
        end
        return true
    end
    return false
end

-- ==== HandyNotes ===========================================================

local function Bind()
    local HN = _G.HandyNotes
    if type(HN) ~= "table" or type(HN.plugins) ~= "table" or type(HN.getXY) ~= "function"
       or type(HN.UpdatePluginMap) ~= "function" or type(HN.UpdateWorldMap) ~= "function" then
        return false
    end
    H.hn = HN
    return true
end

local function HandyNotesOn()
    local HN = H.hn
    if type(HN.IsEnabled) ~= "function" then return true end
    return HN:IsEnabled() == true
end

-- The player's own switch for the plugin in HandyNotes' options, read as
-- its map reads it (a default of on for every plugin).
local function PluginShown(name)
    local profile = H.hn.db and H.hn.db.profile
    local enabled = profile and profile.enabledPlugins
    return not enabled or enabled[name] == true
end

-- A plugin registers under a name of its own, its folder often under
-- another; metadata for a missing addon is never asked.
local function AddonTitle(addon)
    return C_AddOns.DoesAddOnExist(addon) and C_AddOns.GetAddOnMetadata(addon, "Title") or nil
end

-- The plugin's name in HandyNotes' own options list.
local function OptionsName(name)
    local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
    if not reg then return nil end
    -- The first fetch validates every plugin's options table, which may throw.
    local ok, opts = pcall(reg.GetOptionsTable, reg, "HandyNotes", "dialog", "EasyFind_HandyNotes")
    local plugins = ok and type(opts) == "table" and type(opts.args) == "table" and opts.args.plugins
    local entry = type(plugins) == "table" and type(plugins.args) == "table" and plugins.args[name]
    local text = type(entry) == "table" and entry.name
    return type(text) == "string" and text ~= "" and text or nil
end

local function PluginTitle(name)
    local title = H.titles[name]
    if title then return title end
    title = OptionsName(name) or AddonTitle(name) or AddonTitle("HandyNotes_" .. name)
    title = title and (Strip(title):gsub("^HandyNotes:%s*", "")) or (name:gsub("^HandyNotes_", ""))
    H.titles[name] = title
    return title
end

local function ZoneName(mapID)
    local name = H.zones[mapID]
    if name then return name end
    local info = C_Map.GetMapInfo(mapID)
    name = info and info.name or "?"
    H.zones[mapID] = name
    return name
end

-- The zone a map belongs to: itself, or its nearest zone above it (a
-- city's cellar, a cave). A continent or anything above has none.
local ZONE = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
local function ZoneOf(mapID)
    local zone = H.zoneOf[mapID]
    if zone ~= nil then return zone end
    zone = false
    local id = mapID
    for _ = 1, 10 do
        local info = id and C_Map.GetMapInfo(id)
        if not info or (info.mapType and info.mapType < ZONE) then break end
        if info.mapType == ZONE then
            zone = id
            break
        end
        id = info.parentMapID
    end
    H.zoneOf[mapID] = zone
    return zone
end

local function SameZone(a, b)
    if a == b then return true end
    local za = ZoneOf(a)
    return za and za == ZoneOf(b) or false
end


-- Every map under both roots: Azeroth's own walk stands where a client
-- answers no children for the cosmic map.
local function MapList()
    if H.maps then return H.maps end
    local list, seen = { COSMIC, AZEROTH }, { [COSMIC] = true, [AZEROTH] = true }
    for _, root in ipairs({ COSMIC, AZEROTH }) do
        local kids = C_Map.GetMapChildrenInfo(root, nil, true)
        for i = 1, kids and #kids or 0 do
            local id = kids[i].mapID
            if not seen[id] then
                seen[id] = true
                list[#list + 1] = id
            end
        end
    end
    H.maps = list
    return list
end

local function EntryKey(mapID, coord)
    return mapID * 100000000 + coord
end

local function IsTexture(v)
    return type(v) == "string" or type(v) == "number"
end

-- The pin's own art: a file, or a cut of one as EasyFind's painter takes it.
local function PinIcon(iconpath)
    if IsTexture(iconpath) then return iconpath end
    if type(iconpath) ~= "table" or not IsTexture(iconpath.icon) then return nil end
    local l, r, t, b = iconpath.tCoordLeft, iconpath.tCoordRight, iconpath.tCoordTop, iconpath.tCoordBottom
    if not l then return iconpath.icon end
    return { file = iconpath.icon, coords = { l, r or 1, t or 0, b or 1 } }
end

local function NpcID(node)
    local id = Field(node, "npcID")
    if type(id) ~= "number" then id = Field(node, "npc") end
    return type(id) == "number" and id or nil
end

local function Entry(plugin, mapID, coord, node, iconpath)
    local name, unresolved = NameOf(node)
    local x, y = H.hn:getXY(coord)
    local e = { name = name, plugin = plugin, mapID = mapID, coord = coord, x = x, y = y, node = node,
                icon = PinIcon(iconpath), npcID = NpcID(node), done = IsDone(node), unresolved = unresolved or nil,
                gen = H.gens[plugin] }
    local continent, pos = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
    if pos then
        e.ci = continent
        e.wx, e.wy = pos:GetXY()
    end
    return e
end

-- One plugin's pins on one map through HandyNotes' own iterator, so its
-- settings apply; the iterator's state holds the node behind each coord.
-- A plugin's own error ends its map, never reported in our name; one gone
-- from HandyNotes since the walk began has no map left.
local function WalkMap(plugin, handler, mapID, out)
    if type(handler) ~= "table" or type(handler.GetNodes2) ~= "function" then return end
    local ok, iter, state, init = pcall(handler.GetNodes2, handler, mapID, false)
    if not ok or type(iter) ~= "function" then return end
    local prev = init
    while true do
        local fine, coord, mapID2, iconpath = pcall(iter, state, prev)
        if not fine or coord == nil then break end
        prev = coord
        -- A zone's pin shown on its continent is indexed from the zone.
        if not (mapID2 and mapID2 ~= mapID) and type(state) == "table" then
            local node = rawget(state, coord)
            if node == nil then
                local data = rawget(state, "data")
                node = type(data) == "table" and rawget(data, coord) or nil
            end
            if type(node) == "table" then out[#out + 1] = Entry(plugin, mapID, coord, node, iconpath) end
        end
    end
end

-- ==== the index ============================================================

local StartWalk

local function Refresh()
    API.RefreshSearchProvider(KEY)
    API.RefreshRowDecorations()
end

local function Push(t, key, e)
    local list = t[key]
    if list then list[#list + 1] = e else t[key] = { e } end
end

-- EasyFind's own row for the pin: the creature's id, true for a place.
local function Listed(e)
    if e.npcID and API.HasCreature(e.npcID) then return e.npcID end
    return e.name ~= nil and API.HasRow(e.name, e.mapID)
end

-- A pin EasyFind lists marks EasyFind's row; any other is a row of ours.
local function Add(e)
    local plugin = e.plugin
    local hit = Listed(e)
    if hit then
        local decor = H.decor[plugin]
        if not decor then
            decor = { byNpc = {}, byName = {} }
            H.decor[plugin] = decor
        end
        if type(hit) == "number" then
            e.rowNpc = hit
            Push(decor.byNpc, hit, e)
        end
        if e.name then Push(decor.byName, e.name:lower(), e) end
        return
    end
    local index = H.index[plugin]
    if not index then
        index = {}
        H.index[plugin] = index
        H.lookup[plugin] = {}
    end
    index[#index + 1] = e
    H.lookup[plugin][EntryKey(e.mapID, e.coord)] = e
end

local function Drop(plugin)
    H.index[plugin], H.lookup[plugin], H.decor[plugin] = nil, nil, nil
end

-- Pins whose name had not arrived: asked again a little later.
local function Resolve(pending, try)
    C_Timer.After(RESOLVE_WAIT, function()
        local left, added = {}, false
        for i = 1, #pending do
            local e = pending[i]
            if e.gen == H.gens[e.plugin] then
                local name, unresolved = NameOf(e.node)
                -- The last try lists a pin under the part of its name known.
                if name and (not unresolved or try == RESOLVE_TRIES) then
                    e.name, e.unresolved = name, nil
                    Add(e)
                    added = true
                elseif unresolved and try < RESOLVE_TRIES then
                    left[#left + 1] = e
                end
            end
        end
        if added then Refresh() end
        if #left > 0 then Resolve(left, try + 1) end
    end)
end

-- The walk's pins into the index, the frame's share at a time (1,800 pins
-- at once held a retail frame 145 ms).
local function Finish(fresh)
    local pending, plugins = {}, {}
    for plugin in pairs(fresh) do plugins[#plugins + 1] = plugin end
    local p, i = 1, 1
    local function Step()
        local deadline = debugprofilestop() + WALK_MS
        while p <= #plugins do
            local plugin = plugins[p]
            local entries = fresh[plugin]
            if i == 1 then Drop(plugin) end
            while i <= #entries do
                local e = entries[i]
                i = i + 1
                -- A creature EasyFind has needs no name of ours: its row has one.
                if e.npcID and API.HasCreature(e.npcID) then
                    Add(e)
                elseif e.unresolved then
                    pending[#pending + 1] = e
                elseif e.name then
                    Add(e)
                end
                if debugprofilestop() >= deadline then return C_Timer.After(0, Step) end
            end
            p, i = p + 1, 1
        end
        H.walking = false
        if #pending > 0 then Resolve(pending, 1) end
        Refresh()
        if H.all or next(H.dirty) then StartWalk() end
    end
    Step()
end

-- A walk held by a chat lockdown goes on once it lifts.
local function Hold(fn)
    H.held = fn
    if RESTRICTION_EVENT then events:RegisterEvent(RESTRICTION) end
end

local function Resume()
    local held = H.held
    if not held or InLockdown() then return end
    H.held = nil
    if RESTRICTION_EVENT then events:UnregisterEvent(RESTRICTION) end
    C_Timer.After(0, held)
end

-- Walks every map for the plugins that need it, one plugin's map at a
-- time until the frame's share is spent (81 plugins ran too long at 60 maps).
StartWalk = function()
    if H.walking or not H.ready then return end
    if InLockdown() then return Hold(StartWalk) end
    local HN = H.hn
    local plugins, fresh = {}, {}
    for name, handler in pairs(HN.plugins) do
        if not PluginShown(name) then
            Drop(name)
        elseif (H.all or H.dirty[name]) and type(handler.GetNodes2) == "function" then
            plugins[#plugins + 1] = name
            fresh[name] = {}
            H.gens[name] = (H.gens[name] or 0) + 1
        end
    end
    H.all = false
    wipe(H.dirty)
    H.walked = true
    if #plugins == 0 then
        Refresh()
        return
    end
    H.walking = true
    local maps, m, p = MapList(), 1, 1
    local function Step()
        if InLockdown() then return Hold(Step) end
        local deadline = debugprofilestop() + WALK_MS
        repeat
            local name = plugins[p]
            xpcall(WalkMap, ErrorHandler, name, HN.plugins[name], maps[m], fresh[name])
            p = p + 1
            if p > #plugins then p, m = 1, m + 1 end
        until m > #maps or debugprofilestop() >= deadline
        if m <= #maps then
            C_Timer.After(0, Step)
        else
            Finish(fresh)
        end
    end
    C_Timer.After(0, Step)
end

local function MarkDirty(plugin)
    if plugin then H.dirty[plugin] = true else H.all = true end
    if H.rewalk or not H.walked then return end
    H.rewalk = true
    C_Timer.After(REWALK_WAIT, function()
        H.rewalk = nil
        StartWalk()
    end)
end

-- ==== rows =================================================================

local function EntryOf(row)
    local lookup = row.plugin and H.lookup[row.plugin]
    return lookup and lookup[EntryKey(row.mapID, row.coord)] or nil
end

-- The same pin drawn on two maps (a zone and its continent) is one row.
local function SpotKey(e)
    if not e.wx then return e.plugin .. "\0" .. e.name .. "\0" .. e.mapID end
    return e.plugin .. "\0" .. e.name .. "\0" .. e.ci .. "\0" .. floor(e.wx / 5) .. "\0" .. floor(e.wy / 5)
end

-- Pins of one name keep one order (EasyFind's saved index matches it).
local function ByName(a, b)
    if a.name ~= b.name then return a.name < b.name end
    if a.plugin ~= b.plugin then return a.plugin < b.plugin end
    if a.mapID ~= b.mapID then return (a.mapID or 0) < (b.mapID or 0) end
    return (a.coord or 0) < (b.coord or 0)
end

-- EasyFind 5.4.0 on: the frame goes while the rows are built.
local Checkpoint = API and API.SliceCheckpoint or function() end

-- What a pin is and drops, as words the search matches with its name:
-- its plugin ("decor vendors"), its own kind, its loot. EasyFind adds its
-- place's words (MINOR 7). Built again while a loot name is on its way.
local function Keywords(e)
    if e.keywords then return e.keywords end
    local words = { PluginTitle(e.plugin):lower() }
    local loot, missing = LootNames(e.node)
    for i = 1, loot and #loot or 0 do words[#words + 1] = loot[i]:lower() end
    for i = 1, #KIND_FIELDS do
        local value = Field(e.node, KIND_FIELDS[i])
        if type(value) == "string" and value ~= "" and #value <= KIND_MAX and not value:find("{", 1, true) then
            -- "primaryProfession" -> "primary profession"
            words[#words + 1] = Strip(value:gsub("(%l)(%u)", "%1 %2")):lower()
        end
    end
    if not missing then e.keywords = words end
    return words
end

-- What the pin drops, under one heading.
local function AddLoot(tt, node)
    local loot = LootNames(node)
    if not loot or #loot == 0 then return false end
    tt:AddLine(L["LOOT"], 1, 0.82, 0)
    for i = 1, #loot do tt:AddLine(loot[i], 1, 1, 1) end
    return true
end

local function Rows()
    if not H.ready or not HandyNotesOn() then return {} end
    Resume()
    if not H.walked then StartWalk() end
    local db = DB()
    local here = db.nearMe and C_Map.GetBestMapForUnit("player") or nil
    local out, seen = {}, {}
    for plugin, entries in pairs(H.index) do
        for i = 1, #entries do
            if i % 64 == 0 then Checkpoint() end
            local e = entries[i]
            local keep = not (db.hideDone and e.done)
            if keep and here then keep = e.mapID == here end
            if keep then
                local key = SpotKey(e)
                if not seen[key] then
                    seen[key] = true
                    out[#out + 1] = { name = e.name, icon = e.icon, mapID = e.mapID, coord = e.coord, plugin = plugin,
                                      keywords = Keywords(e), searchCommandDesc = sformat(L["PIN_FMT"], ZoneName(e.mapID)) }
                end
            end
        end
    end
    tsort(out, ByName)
    return out
end

-- The pin's own icon marks the route's end on the map (a whole file only).
local function Dest(e)
    return { name = e.name, mapID = e.mapID, x = e.x, y = e.y, step = L["STEP_PIN"],
             icon = IsTexture(e.icon) and e.icon or nil }
end

local function Say(text)
    print("|cff66ccff" .. L["EXT_NAME"] .. ":|r " .. text)
end

-- The game's waypoint where the GPS is not installed. Set under an open
-- world map it is rebuilt in our name, so it waits for the map to close.
local function SetWaypoint(dest)
    local map = WorldMapFrame
    if map and map:IsShown() then
        if not H.waitHooked then
            H.waitHooked = true
            map:HookScript("OnHide", function()
                local wait = H.waypointWait
                H.waypointWait = nil
                if wait then SetWaypoint(wait) end
            end)
        end
        H.waypointWait = dest
        return
    end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(dest.mapID, dest.x, dest.y))
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
end

local function Navigate(dest)
    if API.HasAction("gps", "navigate") then
        API.CallAction("gps", "navigate", dest, { popout = true })
    elseif not WAYPOINTS then
        Say(L["NEEDS_GPS"])
    elseif C_Map.CanSetUserWaypointOnMap(dest.mapID) then
        SetWaypoint(dest)
    else
        Say(sformat(L["NO_PLACE"], dest.name))
    end
end

-- The game's own map pin link, as a pin's "Link to chat" sends it.
local function InsertChatLink(e)
    local link = sformat("|cffffff00|Hworldmap:%d:%d:%d|h[%s]|h|r", e.mapID, floor(e.x * 10000 + 0.5),
        floor(e.y * 10000 + 0.5), MAP_PIN_HYPERLINK or e.name)
    local active = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    if active and active:IsShown() then
        active:Insert(link)
    elseif not (ChatEdit_InsertLink and ChatEdit_InsertLink(link)) and ChatFrame_OpenChat then
        ChatFrame_OpenChat(link)
    end
end

local function Select(row)
    local e = EntryOf(row)
    if not e then return end
    if WAYPOINTS and IsShiftKeyDown() then return InsertChatLink(e) end
    Navigate(Dest(e))
end

local function Place(row)
    local e = EntryOf(row)
    return e and Dest(e) or nil
end

-- The plugin's own tooltip for the pin when its node renders one, else
-- the name and its note; the place and the plugin under either.
local function Tooltip(row, tt)
    local e = EntryOf(row)
    if not e then return false end
    local render = Field(e.node, "Render")
    if not (type(render) == "function" and pcall(render, e.node, tt, false)) then
        tt:SetText(e.name)
        local note = Field(e.node, "note") or Field(e.node, "desc")
        local text = type(note) == "string" and Render(note)
        if text then tt:AddLine(text, 1, 1, 1, true) end
        AddLoot(tt, e.node)
    end
    tt:AddLine(sformat("%s  %.1f, %.1f", ZoneName(e.mapID), e.x * 100, e.y * 100), 0.8, 0.8, 0.8)
    tt:AddLine(sformat(L["PLUGIN_FMT"], L["EXT_NAME"], PluginTitle(e.plugin)), 0.6, 0.6, 0.6)
    return true
end

-- ==== EasyFind's rows ======================================================

-- The pin behind one of EasyFind's map rows: by the creature's id, else
-- by name in the row's zone.
local function DecorEntry(row)
    if not H.walked then
        if H.ready then StartWalk() end
        return nil
    end
    local mapID = row.mapID
    if not mapID or not (row.npcID or row.mapSearchResult) or type(row.name) ~= "string" then return nil end
    local npcID, name = row.npcID, nil
    for _, decor in pairs(H.decor) do
        local list = npcID and decor.byNpc[npcID]
        if list then return list[1] end
        name = name or row.name:lower()
        list = decor.byName[name]
        for i = 1, list and #list or 0 do
            if SameZone(list[i].mapID, mapID) then return list[i] end
        end
    end
    return nil
end

-- Text the row already shows or is found by (its name, subtext, an NPC's
-- title among its keywords) is nothing HandyNotes adds.
local function RowKnows(row, text)
    local low = text:lower()
    if low == row.name:lower() then return true end
    local sub = row.searchCommandDesc or row.zoneName
    if type(sub) == "string" and sub:lower():find(low, 1, true) then return true end
    local kws = row.keywordsLower or row.keywords
    for i = 1, type(kws) == "table" and #kws or 0 do
        if type(kws[i]) == "string" and kws[i]:lower() == low then return true end
    end
    return false
end

-- Only what the pin knows and EasyFind's row does not: its notes and its
-- loot, under the plugin's name. Nothing new, nothing added.
local function DecorTooltip(row, _, tt)
    local e = DecorEntry(row)
    if not e then return end
    local notes = {}
    for i = 1, #NOTE_FIELDS do
        local value = Field(e.node, NOTE_FIELDS[i])
        local text = type(value) == "string" and Render(value)
        if text and not RowKnows(row, text) then notes[#notes + 1] = text end
    end
    local loot = LootNames(e.node)
    if #notes == 0 and not (loot and #loot > 0) then return end
    tt:AddLine(sformat(L["PLUGIN_FMT"], L["EXT_NAME"], PluginTitle(e.plugin)), 0.4, 0.8, 1)
    for i = 1, #notes do tt:AddLine(notes[i], 1, 1, 1, true) end
    AddLoot(tt, e.node)
end

-- With nothing typed, the scope lists the pins on the player's map.
local function Browse(row)
    -- One map lookup per listing: GetTime holds still within a frame.
    local now = GetTime()
    if now ~= H.hereAt then
        H.hereAt = now
        local here = C_Map.GetBestMapForUnit("player")
        if here ~= H.hereID then
            H.hereID = here
            local info = here and C_Map.GetMapInfo(here)
            H.hereParent = info and info.parentMapID or nil
        end
    end
    return row.mapID == H.hereID or row.mapID == H.hereParent
end

-- ==== registration =========================================================

local function WatchZone()
    if DB().nearMe then events:RegisterEvent("ZONE_CHANGED_NEW_AREA") else events:UnregisterEvent("ZONE_CHANGED_NEW_AREA") end
end

local function Option(key, label, tip)
    return {
        label = label, tooltip = tip,
        get = function() return DB()[key] == true end,
        set = function(on)
            DB()[key] = on or nil
            WatchZone()
            Refresh()
        end,
    }
end

local OPTIONS = {
    Option("hideDone", L["OPT_HIDE_DONE"], L["OPT_HIDE_DONE_TIP"]),
    Option("nearMe", L["OPT_NEAR_ME"], L["OPT_NEAR_ME_TIP"]),
}

API.RegisterExtension({
    id = KEY,
    name = L["EXT_NAME"],
    description = L["EXT_DESC"],
    icon = ICON,
    keywords = { "handynotes", "pin", "pins" },
    scope = KEY,
    settings = function(page, kit)
        local below = kit.Title(page, L["EXT_NAME"], L["SETTINGS_HINT"])
        for i = 1, #OPTIONS do
            local box = kit.Checkbox(page, OPTIONS[i].label, OPTIONS[i].get, OPTIONS[i].set, OPTIONS[i].tooltip)
            box:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, i == 1 and -8 or -4)
            below = box
        end
    end,
    resetSettings = function()
        wipe(DB())
        WatchZone()
        Refresh()
    end,
})

API.RegisterSearchProvider({
    key = KEY,
    label = L["PROVIDER_LABEL"],
    extension = KEY,
    words = { "pin", "pins", "handynotes" },
    -- Found by name in any search; @hn only narrows to them.
    eager = true,
    aliases = { "pins", "handynotes", "hn" },
    options = OPTIONS,
    rows = Rows,
    select = Select,
    tooltip = Tooltip,
    hint = { click = L["HINT_GPS"], shift = WAYPOINTS and L["HINT_LINK"] or nil },
    place = Place,
    browse = Browse,
})

-- EasyFind's rows the decorator takes, by the creature's id and by name
-- on a map (place and service rows carry no id): asked before applies.
local function Candidates()
    local npcs, names = {}, {}
    for _, decor in pairs(H.decor) do
        for id in pairs(decor.byNpc) do npcs[id] = true end
        for name, list in pairs(decor.byName) do
            local maps = names[name] or {}
            names[name] = maps
            for i = 1, #list do maps[list[i].mapID] = true end
        end
    end
    return { npcID = npcs, name = names }
end

local function Merge(into, words)
    for i = 1, #words do
        local seen = false
        for j = 1, #into do seen = seen or into[j] == words[i] end
        if not seen then into[#into + 1] = words[i] end
    end
end

-- The pins' own words on the EasyFind rows they mark ("decor" finds the
-- decor vendors EasyFind lists): a creature by its id, a place by name@map.
local function Words()
    local npc, name = {}, {}
    for _, decor in pairs(H.decor) do
        for id, list in pairs(decor.byNpc) do
            local into = npc[id] or {}
            npc[id] = into
            for i = 1, #list do Merge(into, Keywords(list[i])) end
        end
        for _, list in pairs(decor.byName) do
            for i = 1, #list do
                local e = list[i]
                if not e.rowNpc then
                    local key = e.name:lower() .. "@" .. e.mapID
                    local into = name[key] or {}
                    name[key] = into
                    Merge(into, Keywords(e))
                end
            end
        end
    end
    return { npc = npc, name = name }
end

-- Its id is the provider's key, so @hn lists both.
API.RegisterRowDecorator({
    id = KEY,
    label = L["EXT_NAME"],
    applies = function(row) return DecorEntry(row) ~= nil end,
    tooltip = DecorTooltip,
    browse = Browse,
    candidates = Candidates,
    words = Words,
})

events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        events:UnregisterEvent("PLAYER_LOGIN")
        if not Bind() then
            Say(L["NOT_READY"])
            return
        end
        H.ready = true
        -- A plugin's pins changed, or HandyNotes redrew everything.
        hooksecurefunc(H.hn, "UpdatePluginMap", function(_, _, plugin) MarkDirty(plugin) end)
        hooksecurefunc(H.hn, "UpdateWorldMap", function() MarkDirty() end)
        WatchZone()
        -- Pins known before the first search, and EasyFind's rows marked.
        C_Timer.After(LOGIN_WALK_WAIT, function()
            if not H.walked then StartWalk() end
        end)
    elseif event == RESTRICTION then
        Resume()
    else
        Refresh()
    end
end)
events:RegisterEvent("PLAYER_LOGIN")
