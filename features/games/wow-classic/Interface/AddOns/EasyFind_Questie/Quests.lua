-- Questie's quests as EasyFind search rows: found by name, a click asks
-- EasyFind's GPS for directions to the giver, the objectives or the turn-in.
-- Quest data is read from Questie at runtime, never copied.
local _, ns = ...
local API = EasyFind and EasyFind.API
if not (API and API.VERSION == 1) then return end

local L = ns.L
-- The Show choice, gray marks and the rows' GPS button came in API MINOR 1.
if (API.MINOR or 0) < 1 then
    print("|cff66ccff" .. L["EXT_NAME"] .. ":|r " .. L["NEEDS_EASYFIND"])
    return
end
-- Loaded beside Questie (OptionalDeps), nothing without it.
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
if not (IsAddOnLoaded and IsAddOnLoaded("Questie")) then return end
local KEY = "questie"
local ICON = "Interface\\AddOns\\EasyFind_Questie\\quest"
local MAX_SOURCES = 12    -- drop sources read for an item objective
-- The game's quest marks: ! to pick up, ? in the log (gray until done), a
-- check once turned in (the ready-check mark).
local ICON_AVAILABLE, ICON_TURN_IN, ICON_IN_PROGRESS, ICON_DONE = 132049, 132048, 365195, 136814

local C_QuestLog, C_Map = C_QuestLog, C_Map
local IsShiftKeyDown, IsAltKeyDown, IsControlKeyDown = IsShiftKeyDown, IsAltKeyDown, IsControlKeyDown
local sformat, mhuge, tconcat = string.format, math.huge, table.concat

-- The quest log by client: retail and Forever answer through C_QuestLog;
-- Era, Anniversary and Mists keep the log-index calls (C_QuestLog.IsComplete
-- is nil there and every row died on it, 2026-10-28).
local function LogIndex(id)
    if C_QuestLog.GetLogIndexForQuestID then return C_QuestLog.GetLogIndexForQuestID(id) end
    local index = GetQuestLogIndexByID and GetQuestLogIndexByID(id)
    return index and index > 0 and index or nil
end

local function IsDone(id)
    if C_QuestLog.IsComplete then return C_QuestLog.IsComplete(id) end
    local index = LogIndex(id)
    if not index then return false end
    local isComplete = select(6, GetQuestLogTitle(index))
    return isComplete ~= nil and isComplete > 0
end

local function IsWatched(id)
    if C_QuestLog.GetQuestWatchType then return C_QuestLog.GetQuestWatchType(id) ~= nil end
    local index = LogIndex(id)
    return index ~= nil and IsQuestWatched(index) and true or false
end

local function SetWatched(id, on)
    if C_QuestLog.AddQuestWatch then
        if on then C_QuestLog.AddQuestWatch(id, Enum.QuestWatchType and Enum.QuestWatchType.Manual)
        else C_QuestLog.RemoveQuestWatch(id) end
        return
    end
    local index = LogIndex(id)
    if not index then return end
    if on then AddQuestWatch(index) else RemoveQuestWatch(index) end
end

-- The quest chosen in the log, true when it could be.
local function SelectInLog(id)
    if C_QuestLog.SetSelectedQuest then
        C_QuestLog.SetSelectedQuest(id)
        return true
    end
    local index = LogIndex(id)
    if index and SelectQuestLogEntry then
        SelectQuestLogEntry(index)
        return true
    end
    return false
end

-- Questie's modules, bound when it says it is ready; nil until then.
local Q = {}
local ready = false

-- dbVersion 2: the three state switches became one Show choice.
local function DB()
    EasyFindQuestieDB = EasyFindQuestieDB or {}
    local db = EasyFindQuestieDB
    if (db.dbVersion or 1) < 2 then
        if db.inLog then db.show = "inLog"
        elseif db.available then db.show = "available"
        elseif db.hideDone == false then db.show = "all" end
        db.inLog, db.available, db.hideDone = nil, nil, nil
        db.dbVersion = 2
    end
    return db
end

-- ==== Questie ================================================================

local function Bind()
    local Loader = QuestieLoader
    if not (Loader and Loader.ImportModule) then return false end
    local QDB = Loader:ImportModule("QuestieDB")
    local Zones = Loader:ImportModule("ZoneDB")
    if type(QDB) ~= "table" or type(Zones) ~= "table" then return false end
    local need = { "QueryQuestSingle", "QueryNPCSingle", "QueryObjectSingle", "QueryItemSingle", "GetQuest", "IsDoable" }
    for i = 1, #need do
        if type(QDB[need[i]]) ~= "function" then return false end
    end
    if type(QDB.QuestPointers) ~= "table" or type(Zones.GetUiMapIdByAreaId) ~= "function" then return false end
    Q.db, Q.zones = QDB, Zones
    -- The tracker's own actions, for the row menu; each probed when used.
    Q.tracker, Q.quest, Q.trackerFrame = Loader:ImportModule("TrackerUtils"), Loader:ImportModule("QuestieQuest"), Loader:ImportModule("QuestieTracker")
    return true
end

local function QuestName(id)
    local name = Q.db.QueryQuestSingle(id, "name")
    return type(name) == "string" and name ~= "" and name or nil
end

local function MapOfArea(areaId)
    return areaId and areaId > 0 and Q.zones:GetUiMapIdByAreaId(areaId) or nil
end

local function AreaName(areaId)
    local mapID = MapOfArea(areaId)
    local info = mapID and C_Map.GetMapInfo(mapID)
    if info then return info.name end
    return areaId and areaId > 0 and C_Map.GetAreaInfo(areaId) or nil
end

local function Starters(id)
    local by = Q.db.QueryQuestSingle(id, "startedBy")
    if type(by) ~= "table" then return nil end
    return by[1], by[2], by[3]
end

local function Finishers(id)
    local by = Q.db.QueryQuestSingle(id, "finishedBy")
    if type(by) ~= "table" then return nil end
    return by[1], by[2]
end

local function FirstGiver(id)
    local npcs, objects, items = Starters(id)
    if npcs and npcs[1] then return "npc", npcs[1] end
    if objects and objects[1] then return "object", objects[1] end
    if items and items[1] then return "item", items[1] end
    return nil
end

local function EntityName(kind, eid)
    local name
    if kind == "npc" then name = Q.db.QueryNPCSingle(eid, "name")
    elseif kind == "object" then name = Q.db.QueryObjectSingle(eid, "name")
    elseif kind == "item" then name = Q.db.QueryItemSingle(eid, "name") end
    return type(name) == "string" and name or nil
end

-- Where a quest's giver or ender stands: the area, and its name.
local function EntityArea(kind, eid)
    if kind == "npc" then return Q.db.QueryNPCSingle(eid, "zoneID") end
    if kind == "object" then return Q.db.QueryObjectSingle(eid, "zoneID") end
    return nil
end

local function EntityZone(kind, eid)
    return AreaName(EntityArea(kind, eid))
end

-- The map a giver stands on: its first spawn's zone (its own area is a
-- subzone with no map of its own).
local function EntityMap(kind, eid)
    local spawns = kind == "npc" and Q.db.QueryNPCSingle(eid, "spawns")
        or kind == "object" and Q.db.QueryObjectSingle(eid, "spawns")
    if type(spawns) ~= "table" then return nil end
    for areaId in pairs(spawns) do
        local mapID = MapOfArea(areaId)
        if mapID then return mapID end
    end
    return nil
end

-- A quest's zone: its own area, else where its giver stands.
local function ZoneName(id)
    return AreaName(Q.db.QueryQuestSingle(id, "zoneOrSort")) or EntityZone(FirstGiver(id))
end

-- ==== spots =================================================================

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

-- Questie's spawns ({ [areaId] = { { x, y }, ... } }, map percent) as
-- EasyFind destinations; instance markers (negative) left out.
local function SpawnSpots(spawns, name, out)
    if type(spawns) ~= "table" then return out end
    for areaId, list in pairs(spawns) do
        local mapID = MapOfArea(areaId)
        if mapID and type(list) == "table" then
            for i = 1, #list do
                local c = list[i]
                if c and c[1] and c[1] >= 0 and c[2] and c[2] >= 0 then
                    out[#out + 1] = { name = name, mapID = mapID, x = c[1] / 100, y = c[2] / 100 }
                end
            end
        end
    end
    return out
end

-- A creature's spots from Questie's spawns.
local function NpcSpots(npcId, out)
    return SpawnSpots(Q.db.QueryNPCSingle(npcId, "spawns"), EntityName("npc", npcId), out)
end

local function ObjectSpots(objectId, out)
    return SpawnSpots(Q.db.QueryObjectSingle(objectId, "spawns"), EntityName("object", objectId), out)
end

local function ListSpots(kind, ids, out, limit)
    if type(ids) ~= "table" then return out end
    for i = 1, limit and math.min(#ids, limit) or #ids do
        if kind == "npc" then NpcSpots(ids[i], out) else ObjectSpots(ids[i], out) end
    end
    return out
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

local function Navigate(dest, step)
    if API.HasAction("gps", "navigate") then
        dest.step = step
        API.CallAction("gps", "navigate", dest, { popout = true })
    elseif C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(dest.mapID) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(dest.mapID, dest.x, dest.y))
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
end

-- The destination is named for the quest and its state ("Cave Mushrooms:
-- pickup"); the last step's sentence says what stands there. Its category
-- is the provider's, so the route's end pin draws the mark in its well.
local function DestFor(spots, questName, nameKey, stepKey, icon)
    local dest = Nearest(spots)
    if not dest then return nil end
    dest.name = sformat(L[nameKey], questName)
    dest.step = L[stepKey]
    dest.icon = icon
    dest.category = KEY
    return dest
end

local function StarterDest(id, questName)
    local npcs, objects = Starters(id)
    return DestFor(ListSpots("object", objects, ListSpots("npc", npcs, {})), questName, "DEST_PICKUP_FMT", "STEP_GIVER", ICON_AVAILABLE)
end

local function FinisherDest(id, questName)
    local npcs, objects = Finishers(id)
    return DestFor(ListSpots("object", objects, ListSpots("npc", npcs, {})), questName, "DEST_TURN_IN_FMT", "STEP_TURN_IN", ICON_TURN_IN)
end

-- The spots an objective is done at, by its kind.
local function ObjectiveSpots(data)
    local out = {}
    local kind = data.Type
    if kind == "monster" then
        NpcSpots(data.Id, out)
    elseif kind == "object" then
        ObjectSpots(data.Id, out)
    elseif kind == "item" then
        ListSpots("npc", Q.db.QueryItemSingle(data.Id, "npcDrops"), out, MAX_SOURCES)
        ListSpots("object", Q.db.QueryItemSingle(data.Id, "objectDrops"), out, MAX_SOURCES)
    elseif kind == "killcredit" then
        ListSpots("npc", data.IdList, out, MAX_SOURCES)
    elseif kind == "event" then
        SpawnSpots(data.Coordinates, data.Text, out)
    end
    return out
end

-- The first objective still open, in Questie's order (matched to the log);
-- the turn-in when none has a place.
local function ObjectiveDest(id, questName)
    local quest = Q.db.GetQuest(id)
    local data = quest and quest.ObjectiveData
    local live = data and data[1] and C_QuestLog.GetQuestObjectives(id)
    for i = 1, data and #data or 0 do
        if not (live and live[i] and live[i].finished) then
            local spots = ObjectiveSpots(data[i])
            if #spots > 0 then return DestFor(spots, questName, "DEST_OBJECTIVE_FMT", "STEP_OBJECTIVE", ICON_IN_PROGRESS) end
        end
    end
    return FinisherDest(id, questName)
end

-- Where a click goes, by the quest's state; nil when nowhere is known.
local function QuestDest(id, questName)
    if C_QuestLog.IsOnQuest(id) then
        if IsDone(id) then return FinisherDest(id, questName) end
        return ObjectiveDest(id, questName)
    end
    return StarterDest(id, questName)
end

-- What each gesture does, by the quest's state.
local function Hint(row)
    local id = row.questId
    if not (ready and id) then return nil end
    local onQuest = C_QuestLog.IsOnQuest(id)
    local click = L["HINT_GIVER"]
    if onQuest then click = IsDone(id) and L["HINT_TURN_IN"] or L["HINT_OBJECTIVE"] end
    local ctrl
    if onQuest then ctrl = IsWatched(id) and L["HINT_UNTRACK"] or L["HINT_TRACK"] end
    return { click = click, shift = L["HINT_LINK"], alt = L["HINT_QUEST_LOG"], ctrl = ctrl }
end

-- The game's quest link: the log's own for a quest in it, built for any other.
local function QuestLink(id, name)
    local link = C_QuestLog.IsOnQuest(id) and GetQuestLink and GetQuestLink(id)
    if link then return link end
    return sformat("|cffffff00|Hquest:%d:%d|h[%s]|h|r", id, Q.db.QueryQuestSingle(id, "questLevel") or 0, name)
end

local function InsertChatLink(link)
    local active = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    if active and active:IsShown() then
        active:Insert(link)
    elseif not (ChatEdit_InsertLink and ChatEdit_InsertLink(link)) and ChatFrame_OpenChat then
        ChatFrame_OpenChat(link)
    end
end

local function OpenQuestLog(id)
    local onQuest = C_QuestLog.IsOnQuest(id)
    if onQuest and QuestMapFrame_OpenToQuestDetails then
        C_QuestLog.SetSelectedQuest(id)
        QuestMapFrame_OpenToQuestDetails(id)
    elseif onQuest and QuestLog_SetSelection and QuestLogFrame and LogIndex(id) then
        -- The classic log: shown, then set to the quest's entry.
        ShowUIPanel(QuestLogFrame)
        QuestLog_SetSelection(LogIndex(id))
    elseif ToggleQuestLog then
        ToggleQuestLog()
    end
end

local function ToggleWatch(id)
    if not C_QuestLog.IsOnQuest(id) then return end
    SetWatched(id, not IsWatched(id))
end

-- Shift links the quest in chat, Alt opens the log to it, Ctrl tracks or
-- untracks it; a plain click asks the GPS.
local function Select(row)
    local id = row.questId
    if not (ready and id) then return end
    if IsShiftKeyDown() then return InsertChatLink(QuestLink(id, row.name)) end
    if IsAltKeyDown() then return OpenQuestLog(id) end
    if IsControlKeyDown() then return ToggleWatch(id) end
    ns.Directions(id, row.name)
end

-- Directions to the quest's current step (the giver, the next objective,
-- the turn-in); said when it has none. A row's plain click, and the entry
-- in Questie's own tracker menu (TrackerMenu.lua).
function ns.Directions(id, name)
    if not ready then return end
    name = name or QuestName(id) or ""
    local dest = QuestDest(id, name)
    if dest then return Navigate(dest, dest.step) end
    local _, _, items = Starters(id)
    if not C_QuestLog.IsOnQuest(id) and items and items[1] then
        print(sformat(L["ITEM_START"], name, EntityName("item", items[1]) or items[1]))
    else
        print(sformat(L["NO_PLACE"], name))
    end
end

-- For the map search and the GPS box: where a pick would go, right now.
local function Place(row)
    if not (ready and row.questId) then return nil end
    return QuestDest(row.questId, row.name)
end

-- ==== the row's Questie menu =================================================

local function Action(label, fn)
    return { kind = "action", label = label, onClick = fn }
end

local function Focused(questId, objectiveIndex)
    local focus = Questie.db and Questie.db.char and Questie.db.char.TrackerFocus
    if objectiveIndex then return focus == questId .. " " .. objectiveIndex end
    return focus == questId
end

local function Unfocus()
    Q.tracker:UnFocus()
    if Q.quest.ToggleNotes then Q.quest:ToggleNotes(true) end
end

-- Questie's per-character tracker tables, written as its own menu writes
-- them; nil when this version keeps them elsewhere.
local function CharTable(name)
    local char = Questie.db and Questie.db.char
    local t = char and char[name]
    return type(t) == "table" and t or nil
end

local function TrackerRedraw()
    if InCombatLockdown() then return end
    if Q.trackerFrame.Update then Q.trackerFrame:Update() end
end

local function MinimizeRow(id)
    local collapsed = CharTable("collapsedQuests")
    if not collapsed then return nil end
    local on = collapsed[id] and true or false
    return Action(on and L["MENU_MAXIMIZE"] or L["MENU_MINIMIZE"], function()
        collapsed[id] = not on
        TrackerRedraw()
    end)
end

-- Hide Icons for the quest (objective nil) or one objective: the flag on
-- Questie's live object and in its saved table, then its icons redraw.
local function HideIconsRow(id, quest, objective)
    local saved = CharTable(objective and "TrackerHiddenObjectives" or "TrackerHiddenQuests")
    local redraw = Q.quest.ToggleQuestNotes
    if not (saved and redraw) then return nil end
    local target = objective or quest
    local key = objective and (id .. " " .. objective.Index) or id
    local hidden = target.HideIcons and true or false
    return Action(hidden and L["MENU_SHOW_ICONS"] or L["MENU_HIDE_ICONS"], function()
        target.HideIcons = (not hidden) or nil
        saved[key] = (not hidden) or nil
        redraw(hidden)
    end)
end

local function LockRow()
    local profile = Questie.db and Questie.db.profile
    local Base = QuestieLoader:ImportModule("TrackerBaseFrame")
    if not (profile and Base.Update) then return nil end
    local locked = profile.trackerLocked and true or false
    return Action(locked and L["MENU_UNLOCK_TRACKER"] or L["MENU_LOCK_TRACKER"], function()
        profile.trackerLocked = not locked
        Base:Update()
    end)
end

local function AbandonPrompt(id)
    if QuestMapQuestOptions_AbandonQuest then return QuestMapQuestOptions_AbandonQuest(id) end
    local setAbandon = C_QuestLog.SetAbandonQuest or SetAbandonQuest
    local abandonName = C_QuestLog.GetAbandonQuestName or GetAbandonQuestName
    if not (setAbandon and abandonName and SelectInLog(id)) then return end
    setAbandon()
    StaticPopup_Show("ABANDON_QUEST", abandonName())
end

-- One objective's flyout: Questie's focus and map, and our GPS to it.
local function ObjectiveMenu(id, quest, objective)
    local rows = {}
    local index = objective.Index
    if Focused(id, index) then
        rows[#rows + 1] = Action(L["MENU_UNFOCUS"], Unfocus)
    elseif Q.tracker.FocusObjective then
        rows[#rows + 1] = Action(L["MENU_FOCUS_OBJECTIVE"], function()
            if Q.tracker:FocusObjective(id, index, objective, quest) and Q.quest.ToggleNotes then Q.quest:ToggleNotes(false) end
        end)
    end
    local data = quest.ObjectiveData and quest.ObjectiveData[index]
    if data then
        rows[#rows + 1] = Action(L["MENU_GPS_OBJECTIVE"], function()
            local dest = DestFor(ObjectiveSpots(data), quest.name, "DEST_OBJECTIVE_FMT", "STEP_OBJECTIVE", ICON_IN_PROGRESS)
            if dest then Navigate(dest, dest.step) else print(sformat(L["NO_PLACE"], objective.Description or quest.name)) end
        end)
    end
    if Q.tracker.ShowObjectiveOnMap then
        rows[#rows + 1] = Action(L["MENU_SHOW_ON_MAP"], function() Q.tracker:ShowObjectiveOnMap(objective) end)
    end
    rows[#rows + 1] = HideIconsRow(id, quest, objective)
    return { kind = "menu", label = objective.Description or tostring(index), rows = rows }
end

-- Questie's tracker menu for the quest, as the row's right-click flyout.
local function QuestieMenu(row)
    local id = row.questId
    if not (ready and id and Questie and Q.tracker) then return nil end
    local rows = {}
    rows[#rows + 1] = Action(L["MENU_LINK_CHAT"], function() InsertChatLink(QuestLink(id, row.name)) end)
    if not C_QuestLog.IsOnQuest(id) then return rows end
    local quest = Q.db.GetQuest(id)
    if not quest then return rows end
    if Focused(id) then
        rows[#rows + 1] = Action(L["MENU_UNFOCUS"], Unfocus)
    elseif Q.tracker.FocusQuest then
        rows[#rows + 1] = Action(L["MENU_FOCUS_QUEST"], function()
            if Q.tracker:FocusQuest(id, quest) and Q.quest.ToggleNotes then Q.quest:ToggleNotes(false) end
        end)
    end
    rows[#rows + 1] = MinimizeRow(id)
    rows[#rows + 1] = HideIconsRow(id, quest)
    if Q.tracker.ShowFinisherOnMap then
        rows[#rows + 1] = Action(L["MENU_SHOW_ON_MAP"], function() Q.tracker:ShowFinisherOnMap(quest) end)
    end
    if Q.tracker.ShowQuestLog then
        rows[#rows + 1] = Action(L["MENU_SHOW_QUEST_LOG"], function() Q.tracker:ShowQuestLog(quest) end)
    end
    if Q.trackerFrame.UntrackQuestId then
        rows[#rows + 1] = Action(L["MENU_UNTRACK"], function() Q.trackerFrame:UntrackQuestId(id) end)
    end
    rows[#rows + 1] = Action(L["MENU_ABANDON"], function() AbandonPrompt(id) end)
    rows[#rows + 1] = LockRow()
    local objectives = quest.Objectives
    if objectives and next(objectives) and not IsDone(id) then
        rows[#rows + 1] = { kind = "separator" }
        for _, objective in pairs(objectives) do
            if objective.Index then rows[#rows + 1] = ObjectiveMenu(id, quest, objective) end
        end
    end
    return rows
end

-- ==== rows ==================================================================

local function Available(id, level)
    local need = Q.db.QueryQuestSingle(id, "requiredLevel")
    if need and need > level then return false end
    return Q.db.IsDoable(id) == true
end

-- Whether the quest starts or plays out on the map the player is on.
local function OnMap(id, mapID)
    if MapOfArea(Q.db.QueryQuestSingle(id, "zoneOrSort")) == mapID then return true end
    local npcs, objects = Starters(id)
    for i = 1, npcs and #npcs or 0 do
        if MapOfArea(Q.db.QueryNPCSingle(npcs[i], "zoneID")) == mapID then return true end
    end
    for i = 1, objects and #objects or 0 do
        if MapOfArea(Q.db.QueryObjectSingle(objects[i], "zoneID")) == mapID then return true end
    end
    return false
end

-- Where the player stands with the quest, as its word's key: in the log,
-- turned in, or whether it can be picked up (and if not, for the level).
local function StateKey(id, onQuest, level, need)
    if onQuest then return IsDone(id) and "STATE_TURN_IN" or "STATE_IN_LOG" end
    if C_QuestLog.IsQuestFlaggedCompleted(id) then return "STATE_DONE" end
    if need and need > level then return "STATE_NEEDS_LEVEL" end
    return Q.db.IsDoable(id) == true and "STATE_AVAILABLE" or "STATE_UNAVAILABLE"
end

-- A quest's zone and giver, the subtext after its state and level.
local function Where(id, zone)
    zone = zone or ZoneName(id)
    local kind, eid = FirstGiver(id)
    local giver = kind and EntityName(kind, eid)
    if zone and giver then return zone .. ", " .. giver end
    return zone or giver
end

local function Compose(key, need, level, where)
    local state = key == "STATE_NEEDS_LEVEL" and sformat(L[key], need) or L[key]
    -- "Needs level 60" says it already: no "Level 60" after it.
    if level and level > 0 and not (key == "STATE_NEEDS_LEVEL" and need == level) then
        local said = sformat(L["LEVEL_FMT"], level)
        where = where and said .. ", " .. where or said
    end
    return where and sformat(L["STATE_SUBTEXT_FMT"], state, where) or state
end

local KEY_ICON = { STATE_TURN_IN = ICON_TURN_IN, STATE_IN_LOG = ICON_IN_PROGRESS, STATE_DONE = ICON_DONE }

-- A row's subtext and the game's mark for its state, gray for a quest the
-- player cannot pick up yet.
local function Paint(row, key, need, level, where)
    row.searchCommandDesc = Compose(key, need, level, where)
    row.icon = KEY_ICON[key] or ICON_AVAILABLE
    row.iconDimmed = (key == "STATE_NEEDS_LEVEL" or key == "STATE_UNAVAILABLE") or nil
end

local function Subtext(id, onQuest, playerLevel)
    local need = Q.db.QueryQuestSingle(id, "requiredLevel")
    return Compose(StateKey(id, onQuest, playerLevel, need), need, Q.db.QueryQuestSingle(id, "questLevel"), Where(id))
end

-- ==== EasyFind links ========================================================

-- A quest row's share key: its id and, from the log, the sender's progress
-- per objective ("1234:2/5,0/1"). The receiver's row carries that progress.
local function ShareKey(row)
    local id = row.questId
    if not (ready and id) then return nil end
    local key = tostring(id)
    local live = C_QuestLog.IsOnQuest(id) and C_QuestLog.GetQuestObjectives(id)
    if live and live[1] then
        local parts = {}
        for i = 1, #live do parts[i] = (live[i].numFulfilled or 0) .. "/" .. (live[i].numRequired or 0) end
        key = key .. ":" .. tconcat(parts, ",")
    end
    return key
end

-- Quests the game names alike that one chain links: each one's part,
-- numbered on the first full pass over Questie's quests; nil until then.
local partOf

-- One name's quests: where Questie's links make each a simple chain, its
-- parts by order. Any fork leaves the name's quests unnumbered.
local function NumberChains(ids)
    local inGroup = {}
    for i = 1, #ids do inGroup[ids[i]] = true end
    local before, after, fork = {}, {}, false
    local function Link(a, b)
        if a == b or not (inGroup[a] and inGroup[b]) or after[a] == b then return end
        if after[a] or before[b] then fork = true return end
        after[a], before[b] = b, a
    end
    for i = 1, #ids do
        local id = ids[i]
        local single = Q.db.QueryQuestSingle(id, "preQuestSingle")
        for j = 1, type(single) == "table" and #single or 0 do Link(single[j], id) end
        local group = Q.db.QueryQuestSingle(id, "preQuestGroup")
        for j = 1, type(group) == "table" and #group or 0 do Link(math.abs(group[j]), id) end
        local nextId = Q.db.QueryQuestSingle(id, "nextQuestInChain")
        if nextId and nextId ~= 0 then Link(id, nextId) end
    end
    if fork then return end
    for i = 1, #ids do
        local at = ids[i]
        if after[at] and not before[at] then
            local n = 0
            while at and not partOf[at] do
                n = n + 1
                partOf[at] = n
                at = after[at]
            end
        end
    end
end

local function Labeled(id, name)
    local part = partOf and partOf[id]
    return part and sformat(L["PART_FMT"], name, part) or name
end

local function ResolveShareKey(tail)
    if not ready then return nil end
    local id, progress = tail:match("^(%d+):?(.*)$")
    id = tonumber(id)
    local name = id and QuestName(id)
    if not name then return nil end
    local needed = Q.db.QueryQuestSingle(id, "requiredLevel")
    local key = StateKey(id, C_QuestLog.IsOnQuest(id), UnitLevel("player"), needed)
    local row = { name = Labeled(id, name), questId = id }
    Paint(row, key, needed, Q.db.QueryQuestSingle(id, "questLevel"), Where(id))
    if progress ~= "" then
        row.shared = {}
        for done, need in progress:gmatch("(%d+)/(%d+)") do
            row.shared[#row.shared + 1] = { tonumber(done), tonumber(need) }
        end
    end
    return row
end

-- Which quests the search lists, by their state.
local SHOW_DEFAULT = "notDone"
local function Shows(show, key)
    if show == "all" then return true end
    if show == "inLog" then return key == "STATE_IN_LOG" or key == "STATE_TURN_IN" end
    if show == "done" then return key == "STATE_DONE" end
    if key == "STATE_DONE" then return false end
    if show == "available" then return key == "STATE_AVAILABLE" end
    return true
end

-- Each quest's row, read from Questie once; a quest update re-reads only
-- states (a full rebuild per update stuttered ~100 ms over 5,000 quests).
local S = {
    rows = {}, need = {}, level = {}, where = {}, key = {}, order = nil,
    queue = nil, at = 1, named = nil,
    passAt = 1, fresh = false, changed = false, force = false, scheduled = false,
    here = nil, near = {},
}
local SLICE_MS, CHECK_EVERY = 4, 50

local function ReadQuest(id)
    local name = QuestName(id)
    if not name then return end
    local had = S.named[name]
    if had == nil then S.named[name] = id
    elseif type(had) == "number" then S.named[name] = { had, id }
    else had[#had + 1] = id end
    local n = #S.rows + 1
    -- The zone's name is a search word too ("ruins of lord quests"); a
    -- dungeon's quests, with no map of their own, stand on their giver's.
    local zone = ZoneName(id)
    S.rows[n] = { name = name, questId = id, keywords = zone and { zone } or nil,
                  mapID = MapOfArea(Q.db.QueryQuestSingle(id, "zoneOrSort")) or EntityMap(FirstGiver(id)) }
    S.need[n] = Q.db.QueryQuestSingle(id, "requiredLevel") or false
    S.level[n] = Q.db.QueryQuestSingle(id, "questLevel") or false
    S.where[n] = Where(id, zone) or false
end

-- Reads Questie's quests for up to budget ms; true once all are read,
-- their parts numbered and their names in order.
local function Warm(budget)
    if S.order then return true end
    if not S.queue then
        S.queue, S.named, S.at = {}, {}, 1
        for id in pairs(Q.db.QuestPointers) do S.queue[#S.queue + 1] = id end
    end
    local stop, queue = debugprofilestop() + budget, S.queue
    while S.at <= #queue do
        ReadQuest(queue[S.at])
        S.at = S.at + 1
        if S.at % CHECK_EVERY == 0 and debugprofilestop() > stop then return false end
    end
    partOf = {}
    for _, ids in pairs(S.named) do
        if type(ids) == "table" then NumberChains(ids) end
    end
    local rows, order = S.rows, {}
    for i = 1, #rows do
        rows[i].name = Labeled(rows[i].questId, rows[i].name)
        order[i] = i
    end
    table.sort(order, function(a, b) return rows[a].name < rows[b].name end)
    S.order, S.queue, S.named = order, nil, nil
    return true
end

-- Re-reads each quest's state for up to budget ms, repainting a row only
-- when its state moved; true once all are read.
local function Pass(budget)
    if S.fresh then return true end
    local stop, level = debugprofilestop() + budget, UnitLevel("player")
    local rows, keys, need = S.rows, S.key, S.need
    local i = S.passAt
    while i <= #rows do
        local row = rows[i]
        local onQuest = C_QuestLog.IsOnQuest(row.questId)
        local key = StateKey(row.questId, onQuest, level, need[i])
        if key ~= keys[i] then
            keys[i] = key
            Paint(row, key, need[i], S.level[i], S.where[i])
            row.inLog = onQuest or nil
            S.changed = true
        end
        i = i + 1
        if i % CHECK_EVERY == 0 and debugprofilestop() > stop then
            S.passAt = i
            return false
        end
    end
    S.passAt, S.fresh = 1, true
    return true
end

-- EasyFind 5.4.0 on: the frame goes between pieces while it builds rows.
local Checkpoint = API.SliceCheckpoint or function() end

local function Rows()
    if not ready then return {} end
    while not Warm(SLICE_MS) do Checkpoint() end
    while not Pass(SLICE_MS) do Checkpoint() end
    S.changed, S.force = false, false
    local db = DB()
    local show = db.show or SHOW_DEFAULT
    local here = db.nearMe and C_Map.GetBestMapForUnit("player") or nil
    if here ~= S.here then S.here, S.near = here, {} end
    -- The log's quests lead, by name: what an empty @quest lists.
    local out, rest = {}, {}
    for k = 1, #S.order do
        if k % 256 == 0 then Checkpoint() end
        local i = S.order[k]
        local row = S.rows[i]
        local keep = Shows(show, S.key[i])
        if keep and here then
            if S.near[i] == nil then S.near[i] = OnMap(row.questId, here) end
            keep = S.near[i]
        end
        if keep then
            if row.inLog then out[#out + 1] = row else rest[#rest + 1] = row end
        end
    end
    for k = 1, #rest do out[#out + 1] = rest[k] end
    return out
end

local function State(id)
    if C_QuestLog.IsOnQuest(id) then
        if IsDone(id) then return L["STATE_TURN_IN"], 0, 1, 0 end
        return L["STATE_IN_LOG"], 1, 0.82, 0
    end
    if C_QuestLog.IsQuestFlaggedCompleted(id) then return L["STATE_DONE"], 0.6, 0.6, 0.6 end
    if Available(id, UnitLevel("player")) then return L["STATE_AVAILABLE"], 0, 1, 0 end
    return nil
end

local function Tooltip(row, tt)
    local id = row.questId
    if not (ready and id) then return false end
    local level = Q.db.QueryQuestSingle(id, "questLevel") or 0
    local color = GetQuestDifficultyColor and GetQuestDifficultyColor(level)
    tt:SetText(row.name, color and color.r or 1, color and color.g or 1, color and color.b or 1)
    local need = Q.db.QueryQuestSingle(id, "requiredLevel")
    if level > 0 then
        if need and need ~= level then
            tt:AddLine(sformat(L["LEVEL_REQ_FMT"], level, need), 1, 1, 1)
        else
            tt:AddLine(sformat(L["LEVEL_FMT"], level), 1, 1, 1)
        end
    end
    local zone = ZoneName(id)
    if zone then tt:AddLine(zone, 1, 1, 1) end
    local kind, eid = FirstGiver(id)
    local giver = kind and EntityName(kind, eid)
    if giver then
        local at = EntityZone(kind, eid)
        tt:AddLine(kind == "item" and sformat(L["STARTS_FROM_ITEM"], giver)
            or at and sformat(L["STARTS_AT_IN_FMT"], giver, at) or sformat(L["STARTS_AT"], giver), 1, 1, 1)
    end
    local npcs, objects = Finishers(id)
    local enderKind, enderId = npcs and npcs[1] and "npc" or objects and objects[1] and "object", npcs and npcs[1] or objects and objects[1]
    local ender = enderKind and EntityName(enderKind, enderId)
    if ender and ender ~= giver then
        local at = EntityZone(enderKind, enderId)
        tt:AddLine(at and sformat(L["ENDS_AT_IN_FMT"], ender, at) or sformat(L["ENDS_AT"], ender), 1, 1, 1)
    end
    local state, r, g, b = State(id)
    if state then tt:AddLine(state, r, g, b) end
    -- A link's row: the sender's progress, against Questie's objectives.
    if row.shared then
        local quest = Q.db.GetQuest(id)
        local data = quest and quest.ObjectiveData or {}
        tt:AddLine(" ")
        tt:AddLine(L["SHARED_PROGRESS"])
        for i = 1, #row.shared do
            local got, goal = row.shared[i][1], row.shared[i][2]
            local text = data[i] and data[i].Text or ""
            local full = goal > 0 and got >= goal
            tt:AddLine(sformat("%d/%d %s", got, goal, text), full and 0.5 or 1, full and 0.5 or 1, full and 0.5 or 1, true)
        end
    end
    local live = C_QuestLog.IsOnQuest(id) and C_QuestLog.GetQuestObjectives(id)
    local text = Q.db.QueryQuestSingle(id, "objectivesText")
    if (live and live[1]) or (type(text) == "table" and text[1]) then
        tt:AddLine(" ")
        tt:AddLine(L["OBJECTIVES"])
        if live and live[1] then
            for i = 1, #live do
                local o = live[i]
                if o.text and o.text ~= "" then
                    if o.finished then tt:AddLine(o.text, 0.5, 0.5, 0.5, true) else tt:AddLine(o.text, 1, 1, 1, true) end
                end
            end
        else
            for i = 1, #text do tt:AddLine(text[i], 0.8, 0.8, 0.8, true) end
        end
    end
    return true
end

-- ==== registration ==========================================================

-- A slice a frame; EasyFind refreshes only when a row moved or the list's
-- rule did (most objective ticks move none).
local function Run()
    if not (Warm(SLICE_MS) and Pass(SLICE_MS)) then
        C_Timer.After(0, Run)
        return
    end
    S.scheduled = false
    if S.changed or S.force then API.RefreshSearchProvider(KEY) end
end

local function Schedule()
    if S.scheduled or not ready then return end
    S.scheduled = true
    C_Timer.After(0.5, Run)
end

-- Questie's quests or the player's level moved: every state is read again.
local function Restate()
    S.fresh, S.passAt = false, 1
    Schedule()
end

-- What the list shows moved (Show, Near me, the zone), the states did not.
local function Relist()
    S.force = true
    Schedule()
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LEVEL_UP" then Restate() else Relist() end
end)

local function WatchZone()
    if DB().nearMe then events:RegisterEvent("ZONE_CHANGED_NEW_AREA") else events:UnregisterEvent("ZONE_CHANGED_NEW_AREA") end
end

-- One state to show (a quest is in only one), and the zone on its own.
local SHOW_CHOICES = {
    { label = L["SHOW_NOT_DONE"], value = "notDone", tooltip = L["SHOW_NOT_DONE_TIP"] },
    { label = L["OPT_AVAILABLE"], value = "available", tooltip = L["OPT_AVAILABLE_TIP"] },
    { label = L["OPT_IN_LOG"], value = "inLog", tooltip = L["OPT_IN_LOG_TIP"] },
    { label = L["SHOW_DONE"], value = "done", tooltip = L["SHOW_DONE_TIP"] },
    { label = L["SHOW_ALL"], value = "all", tooltip = L["SHOW_ALL_TIP"] },
}
local function GetShow() return DB().show or SHOW_DEFAULT end
local function SetShow(value)
    DB().show = value ~= SHOW_DEFAULT and value or nil
    Relist()
end
local function GetNearMe() return DB().nearMe == true end
local function SetNearMe(on)
    DB().nearMe = on or nil
    WatchZone()
    Relist()
end

local function FilterOptions()
    return {
        { header = L["OPT_SHOW"] },
        { choice = SHOW_CHOICES, get = GetShow, set = SetShow },
        { separator = true },
        { label = L["OPT_NEAR_ME"], tooltip = L["OPT_NEAR_ME_TIP"], get = GetNearMe, set = SetNearMe },
    }
end

API.RegisterExtension({
    id = KEY,
    name = L["EXT_NAME"],
    description = L["EXT_DESC"],
    icon = ICON,
    keywords = { "quest", "quests" },
    scope = KEY,
    settings = function(page, kit)
        local below = kit.Title(page, L["EXT_NAME"], L["SETTINGS_HINT"])
        local show = kit.Choice(page, L["OPT_SHOW"], SHOW_CHOICES, GetShow, SetShow, L["OPT_SHOW_TIP"], SHOW_DEFAULT)
        show:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -8)
        local near = kit.Checkbox(page, L["OPT_NEAR_ME"], GetNearMe, SetNearMe, L["OPT_NEAR_ME_TIP"])
        near:SetPoint("TOPLEFT", show, "BOTTOMLEFT", 0, -4)
    end,
})

API.RegisterSearchProvider({
    key = KEY,
    label = L["PROVIDER_LABEL"],
    extension = KEY,
    words = { "quest", "quests" },
    -- A quest's name alone finds it: loaded once a search finds little,
    -- then searched every time after.
    lowResults = true,
    aliases = { "quest", "quests", "questie" },
    -- The game's small "!" and "?" are lost in the map's art on its pin.
    iconWell = true,
    options = FilterOptions(),
    rows = Rows,
    select = Select,
    tooltip = Tooltip,
    hint = Hint,
    -- With nothing typed, the scope lists the quests in the log.
    browse = function(row) return row.inLog == true end,
    -- An EasyFind link names the quest and carries the sender's progress.
    link = { key = ShareKey, resolve = ResolveShareKey },
    -- The map tab and the GPS box route to where a click would go.
    place = Place,
    -- Right-click: Questie's tracker actions, a flyout per objective.
    menu = QuestieMenu,
})

-- Questie's tracker stands in for the game's quest watch: it hides and shows
-- with EasyFind's Toggle Objective Tracker (API MINOR 9), and comes back
-- through Questie's own show, so its rules (instances, nothing tracked) hold.
local function RegisterTracker()
    local base = _G.Questie_BaseFrame
    if not (base and API.RegisterTrackerPiece) then return end
    local tracker = QuestieLoader:ImportModule("QuestieTracker")
    local show = tracker and type(tracker.Show) == "function" and function() tracker:Show() end or nil
    API.RegisterTrackerPiece(base, show)
end

local function OnReady()
    RegisterTracker()
    if not Bind() then
        print("|cff66ccff" .. L["EXT_NAME"] .. ":|r " .. L["NOT_READY"])
        return
    end
    ready = true
    Questie.API.RegisterForQuestUpdates(Restate)
    events:RegisterEvent("PLAYER_LEVEL_UP")
    WatchZone()
    if ns.InstallTrackerMenu then ns.InstallTrackerMenu() end
    Relist()
end

if Questie and Questie.API and Questie.API.RegisterOnReady then
    Questie.API.RegisterOnReady(OnReady)
end

-- For the smoke test: the subtext against a stand-in quest database.
ns.Q, ns.Subtext = Q, Subtext
