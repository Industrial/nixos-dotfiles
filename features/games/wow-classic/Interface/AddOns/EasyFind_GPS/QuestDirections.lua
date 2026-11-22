local ns = EasyFind and EasyFind._ns
if not ns or select(2, ...).tooOld then return end
local GPS = ns.GPS
if not GPS then return end
local L, Utils = ns.L, ns.Utils

-- Directions from the game's own menus (Menu.ModifyMenu): to log quests
-- from its quest menus, and to NPCs and group members from its unit
-- menus; and log quests as search rows. Era and TBC place no quest.

local QL = C_QuestLog
local GetQuestUiMapID = GetQuestUiMapID
local ICON_TURN_IN, ICON_IN_PROGRESS = 132048, 365195

-- Where the game puts a quest in the log: its mark on its own map, else
-- the next waypoint on the way there; nil where it gives none.
local function QuestSpot(questID)
    local mapID = GetQuestUiMapID and GetQuestUiMapID(questID)
    if mapID and mapID > 0 and QL.GetQuestsOnMap then
        for _, q in ipairs(QL.GetQuestsOnMap(mapID) or {}) do
            if q.questID == questID and q.x and q.y then return mapID, q.x, q.y end
        end
    end
    if QL.GetNextWaypoint then
        local wMap, x, y = QL.GetNextWaypoint(questID)
        if wMap and x and y then return wMap, x, y end
    end
    return nil
end
GPS.QuestSpot = QuestSpot

-- The quests in the log, { questID, title, level, done } each.
local function LogQuests()
    local out = {}
    if QL.GetNumQuestLogEntries and QL.GetInfo then
        for i = 1, QL.GetNumQuestLogEntries() do
            local info = QL.GetInfo(i)
            if info and not info.isHeader and not info.isHidden and info.questID and info.questID > 0 then
                out[#out + 1] = { questID = info.questID, title = info.title, level = info.level,
                                  done = QL.IsComplete and QL.IsComplete(info.questID) or false }
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        for i = 1, GetNumQuestLogEntries() do
            local title, level, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
            if title and not isHeader and questID and questID > 0 then
                out[#out + 1] = { questID = questID, title = title, level = level, done = (isComplete or 0) > 0 }
            end
        end
    end
    return out
end

local function QuestTitle(questID)
    local title = QL.GetTitleForQuestID and QL.GetTitleForQuestID(questID)
    if title then return title end
    for _, q in ipairs(LogQuests()) do
        if q.questID == questID then return q.title end
    end
    return nil
end

local KEY = "logQuests"

-- category: the provider's, so the route's end pin draws the mark in its well.
local function Destination(questID)
    local mapID, x, y = QuestSpot(questID)
    if not mapID then return nil end
    local done = QL.IsComplete and QL.IsComplete(questID)
    local dest = { name = QuestTitle(questID) or L["APP_GPS"], mapID = mapID, x = x, y = y,
                   icon = done and ICON_TURN_IN or ICON_IN_PROGRESS, category = KEY,
                   questMark = done and "turnin" or nil, questID = questID }
    return GPS:CanNavigate(dest) and dest or nil
end

local function Navigate(dest, opts)
    EasyFind.API.CallAction("gps", "navigate", dest, opts or { popout = true })
end

-- A log quest's way for a quest menu of another tracker: what "navigate"
-- takes, nil off the log or where the game places it nowhere.
if EasyFind.API.RegisterAction then
    EasyFind.API.RegisterAction("gps", "questDestination", function(questID)
        if type(questID) ~= "number" or not (QL.IsOnQuest and QL.IsOnQuest(questID)) then return nil end
        return Destination(questID)
    end)
end

-- ==== the client's quest menus ===============================================

local function AddDirections(root, questID)
    if not (questID and QL.IsOnQuest and QL.IsOnQuest(questID)) then return end
    local dest = Destination(questID)
    if not dest then return end
    root:CreateDivider()
    root:CreateButton(L["GPS_MENU_EASYFIND_DIRECTIONS"], function() Navigate(dest) end)
end

-- The quest a frame under the cursor stands for (a tracker block's id, a
-- log title's questID): the tracker's menu belongs to the whole tracker.
local function QuestUnderCursor()
    local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
    for i = 1, #foci do
        local f, depth = foci[i], 0
        while f and depth < 6 and not f:IsForbidden() do
            local id = f.questID or f.id
            if type(id) == "number" and QL.IsOnQuest and QL.IsOnQuest(id) then return id end
            f, depth = f.GetParent and f:GetParent(), depth + 1
        end
    end
    return nil
end

if Menu and Menu.ModifyMenu then
    Menu.ModifyMenu("MENU_QUEST_OBJECTIVE_TRACKER", function(_, root)
        AddDirections(root, QuestUnderCursor())
    end)
    Menu.ModifyMenu("MENU_QUEST_MAP_LOG_TITLE", function(owner, root)
        AddDirections(root, owner and type(owner.questID) == "number" and owner.questID or QuestUnderCursor())
    end)
    -- Mists Classic's watch list: the line knows its watch index.
    Menu.ModifyMenu("MENU_WATCH_FRAME_LINK", function(owner, root)
        if not (owner and owner.type == "QUEST" and owner.index and GetQuestIndexForWatch and GetQuestLogTitle) then return end
        local logIndex = GetQuestIndexForWatch(owner.index)
        AddDirections(root, logIndex and select(8, GetQuestLogTitle(logIndex)))
    end)
end

-- ==== the client's unit menus =================================================

-- An NPC to the spot its search row shows (typing its name and taking its
-- GPS button), a party or raid member followed as it moves. Other
-- players: the client gives no spot.
if Menu and Menu.ModifyMenu then
    local FOLLOW_SECONDS, FOLLOW_YARDS = 3, 25
    local UnitDirections = {}
    ns.GPSUnitDirections = UnitDirections

    local function Plain(v)
        if issecretvalue and issecretvalue(v) then return false end
        return v ~= nil
    end

    local function NpcID(unit)
        local guid = UnitGUID(unit)
        if not Plain(guid) then return nil end
        local kind, _, _, _, _, id = strsplit("-", guid)
        if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
        return tonumber(id)
    end

    -- A group member's map and spot on it, or nil (an instance, a client
    -- that withholds it).
    local function MemberSpot(unit)
        local m = C_Map.GetBestMapForUnit(unit)
        local pos = Plain(m) and C_Map.GetPlayerMapPosition(m, unit)
        if not pos then return nil end
        local x, y = pos:GetXY()
        if not (Plain(x) and Plain(y)) then return nil end
        return m, x, y
    end

    local function World(m, x, y)
        local ci, w = C_Map.GetWorldPosFromMapPos(m, CreateVector2D(x, y))
        if not w then return nil end
        return ci, w:GetXY()
    end

    local function UnitOfGUID(guid)
        local raid = IsInRaid()
        local prefix = raid and "raid" or "party"
        for i = 1, raid and GetNumGroupMembers() or 4 do
            if UnitGUID(prefix .. i) == guid then return prefix .. i end
        end
        return nil
    end

    local follow   -- { guid, name, ticker }

    local function StopFollowing()
        if follow and follow.ticker then follow.ticker:Cancel() end
        follow = nil
    end

    -- Every few seconds: the member's spot, and a new route once it is far
    -- from the route's end. Ends when the route is another's or gone, or
    -- the member left the group.
    local function Tick()
        if not follow or GPS:IsPlanning() then return end
        local route = GPS.CurrentRoute and GPS.CurrentRoute()
        if not (route and route.dest and route.dest.followGUID == follow.guid) then return StopFollowing() end
        local unit = UnitOfGUID(follow.guid)
        if not unit then return StopFollowing() end
        local m, x, y = MemberSpot(unit)
        if not m then return end
        local ci, wx, wy = World(m, x, y)
        local dci, dx, dy = World(route.dest.mapID, route.dest.x, route.dest.y)
        if ci and dci and (ci ~= dci or (wx - dx) ^ 2 + (wy - dy) ^ 2 > FOLLOW_YARDS ^ 2) then
            Navigate({ name = follow.name, mapID = m, x = x, y = y, followGUID = follow.guid }, { quiet = true })
        end
    end
    UnitDirections._Tick = Tick   -- tests

    local function Follow(guid, name)
        StopFollowing()
        local unit = UnitOfGUID(guid)
        local m, x, y
        if unit then m, x, y = MemberSpot(unit) end
        if not m then return end
        follow = { guid = guid, name = name }
        Navigate({ name = name, mapID = m, x = x, y = y, followGUID = guid })
        follow.ticker = C_Timer.NewTicker(FOLLOW_SECONDS, Tick)
    end

    -- Show on map: the member's zone on the world map, EasyFind's highlight
    -- and indicator on them, moving with them till the map closes.
    local SHOW_EVERY = 0.1
    local shown = {}   -- guid, box, ind, ticker

    local function Unshow()
        if shown.ticker then shown.ticker:Cancel() end
        shown.ticker, shown.guid = nil, nil
        if shown.box then
            shown.box:Hide()
            shown.ind:Hide()
        end
    end

    -- On whatever map the world map shows that holds them (their zone, its
    -- continent); hidden on one that does not.
    local function PlaceShown()
        local map = WorldMapFrame:IsShown() and WorldMapFrame:GetMapID()
        local unit = map and UnitOfGUID(shown.guid)
        if not unit then return Unshow() end
        local pos = C_Map.GetPlayerMapPosition(map, unit)
        local x, y
        if pos then x, y = pos:GetXY() end
        local box, ind = shown.box, shown.ind
        if not (Plain(x) and Plain(y)) then
            box:Hide()
            ind:Hide()
            return
        end
        local canvas = box:GetParent()
        local scale = EasyFind.db and EasyFind.db.iconScale or 0.8
        local size, arrow = ns.UIToCanvas(ns.HIGHLIGHT_SIZE) * scale, ns.UIToCanvas(ns.ICON_SIZE) * scale
        box:SetSize(size, size)
        box:ClearAllPoints()
        box:SetPoint("CENTER", canvas, "TOPLEFT", x * canvas:GetWidth(), -y * canvas:GetHeight())
        ns.MapSearch:ResizeHighlightBorders(box)
        ind:SetSize(arrow, arrow)
        if ind.glow then
            local glow = ns.UIToCanvas(ns.ICON_GLOW_SIZE) * scale
            ind.glow:SetSize(glow, glow)
        end
        ind:ClearAllPoints()
        ind:SetPoint("BOTTOM", box, "TOP", 0, 2)
        if not box:IsShown() then
            ns.MapSearch:ApplyHighlightStyle(box)
            box:Show()
            ind:Show()
        end
    end

    local function ShowOnMap(guid)
        Unshow()
        local unit = UnitOfGUID(guid)
        local m = unit and MemberSpot(unit)
        if not (m and EasyFind.API.OpenMap and EasyFind.API.OpenMap(m)) then return end
        if not shown.box then
            local canvas, Frames = WorldMapFrame.ScrollContainer.Child, ns.MapSearchFrames
            shown.box = Frames.CreateHighlightBox(nil, canvas, { strata = "TOOLTIP", level = 1998, hidden = true,
                                                                 color = ns.YELLOW_HIGHLIGHT })
            shown.ind = Frames.CreateIndicatorFrame(nil, canvas, { strata = "TOOLTIP", level = 2001, size = ns.ICON_SIZE })
            shown.ind:Hide()
        end
        shown.guid = guid
        PlaceShown()
        shown.ticker = C_Timer.NewTicker(SHOW_EVERY, PlaceShown)
    end
    UnitDirections._PlaceShown = PlaceShown   -- tests

    local function AddUnitDirections(root, contextData)
        local unit = contextData and contextData.unit
        if not (unit and UnitExists(unit)) then return end
        if UnitIsPlayer(unit) then
            if UnitIsUnit(unit, "player") or not (UnitInParty(unit) or UnitInRaid(unit)) then return end
            local guid, name = UnitGUID(unit), UnitName(unit)
            if not (Plain(guid) and Plain(name) and MemberSpot(unit)) then return end
            root:CreateDivider()
            root:CreateButton(L["GPS_MENU_EASYFIND_DIRECTIONS"], function() Follow(guid, name) end)
            root:CreateButton(L["GPS_MENU_SHOW_ON_MAP"], function() ShowOnMap(guid) end)
            return
        end
        local id = NpcID(unit)
        local spot = id and ns.Npcs and ns.Npcs.SpotOfID and ns.Npcs.SpotOfID(id)
        if not spot then return end
        root:CreateDivider()
        root:CreateButton(L["GPS_MENU_EASYFIND_DIRECTIONS"], function() Navigate(spot) end)
    end

    for _, which in ipairs({ "TARGET", "FOCUS", "BOSS", "PARTY", "RAID_PLAYER", "RAID" }) do
        Menu.ModifyMenu("MENU_UNIT_" .. which, function(_, root, contextData) AddUnitDirections(root, contextData) end)
    end
end

-- ==== the log's quests as search rows ========================================

-- Only where the client places quests, and not beside the Questie
-- extension's rows, which list these quests already.
local function Questie()
    local loadable = C_AddOns and C_AddOns.IsAddOnLoadable and C_AddOns.IsAddOnLoadable("EasyFind_Questie")
    return loadable and true or false
end
if not (GetQuestUiMapID or QL.GetNextWaypoint) or Questie() then return end

local function Rows()
    local out = {}
    for _, q in ipairs(LogQuests()) do
        out[#out + 1] = {
            name = q.title, questID = q.questID, inLog = true,
            icon = q.done and ICON_TURN_IN or ICON_IN_PROGRESS,
            searchCommandDesc = q.level and q.level > 0 and string.format(L["GPS_QUEST_LEVEL_FMT"], q.level) or nil,
        }
    end
    return out
end

local function OpenLog(questID)
    if QuestMapFrame_OpenToQuestDetails then
        QuestMapFrame_OpenToQuestDetails(questID)
    elseif ToggleQuestLog then
        ToggleQuestLog()
    end
end

EasyFind.API.RegisterSearchProvider({
    key = KEY,
    label = QUESTS_LABEL or "Quests",
    extension = "gps",
    words = { "quest", "quests" },
    -- The game's small "?" is lost in the map's art on its pin.
    iconWell = true,
    rows = Rows,
    place = function(row) return row.questID and Destination(row.questID) or nil end,
    select = function(row)
        if IsAltKeyDown() then return OpenLog(row.questID) end
        local dest = Destination(row.questID)
        if dest then return Navigate(dest) end
        OpenLog(row.questID)
    end,
    hint = function(row)
        return { click = Destination(row.questID) and L["GPS_MENU_DIRECTIONS"] or (QUEST_LOG or "Quest log"),
                 alt = QUEST_LOG or "Quest log" }
    end,
    browse = function() return true end,
})

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function() EasyFind.API.RefreshSearchProvider(KEY) end)
for _, event in ipairs({ "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN" }) do
    Utils.RegisterEventIfValid(events, event)
end
