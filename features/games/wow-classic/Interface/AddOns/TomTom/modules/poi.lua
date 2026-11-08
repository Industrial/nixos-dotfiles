--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
--
--  All Rights Reserved
----------------------------------------------------------------------------]]

-- Automatic quest objective waypoints (docs/quest-objectives.md). The module
-- keeps one temporary waypoint on the quest objective that the player works
-- on. It picks its target source by the functions that the client has, not
-- by the project ID. It changes no CVar and no selected quest.

local _, addon = ...
local TomTom = addon
local L = addon.L
local hbd = addon.hbd
addon.private = addon.private or {}
local private = addon.private

--[[--------------------------------------------------------------------------
--  Capabilities
----------------------------------------------------------------------------]]

-- Retail and Forever: Blizzard's super-tracked quest and its routed step.
local hasSuperTrack = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID
    and C_QuestLog and C_QuestLog.GetNextWaypoint and true or false

-- Blizzard's own world map shows quest objective markers from Wrath on.
-- Before that, the game gives no quest positions (QD4).
local function ClientHasQuestPOIData()
    if C_SuperTrack then
        return true
    end
    if ClassicExpansionAtLeast and LE_EXPANSION_WRATH_OF_THE_LICH_KING then
        return ClassicExpansionAtLeast(LE_EXPANSION_WRATH_OF_THE_LICH_KING) and true or false
    end
    return false
end

local hasClosest = C_QuestLog and C_QuestLog.GetQuestsOnMap and ClientHasQuestPOIData() or false

local module = {
    settingsKey = "poi",
    -- Kaliel's Tracker writes poi.setClosest (integrations.md 3.2).
    enableSetting = {"poi", "setClosest"},
    defaults = {
        setClosest = false,
        arrival = 0,
        target = "supertracked",
    },
}

function module:IsAvailable()
    return hasSuperTrack or hasClosest
end

private.AddModule(module, "QuestObjectives")

local function IsAvailable()
    return module:IsAvailable()
end

private.AddSettingsSection{
    page = "poi", pageName = L["Quest Objectives"], pageOrder = 50, order = 10,
    settingsKey = "poi",
    available = IsAvailable,
    suppress = "poi",
    feature = {
        name = L["Enable automatic quest objective waypoints"],
        tooltip = L["Keeps a waypoint on the quest objective that you work on. The quest waypoint takes the waypoint arrow only when the arrow has no other waypoint."],
        path = "poi.setClosest",
    },
    rows = {
        {type = "text", text = L["TomTom can be configured to set waypoints for the quest objectives that are shown in the watch frame and on the world map.  These options can be used to configure these options."]},
        {type = "range", key = "arrival", name = L["\"Arrival Distance\""],
         tooltip = L["This setting will control the distance at which the waypoint arrow switches to a downwards arrow, indicating you have arrived at your destination"],
         min = 0, max = 150, step = 5},
    },
}

-- Only where both sources exist.
private.AddSettingsSection{
    page = "poi", pageName = L["Quest Objectives"], pageOrder = 50, order = 11,
    settingsKey = "poi",
    available = function() return hasSuperTrack and hasClosest end,
    suppress = "poi",
    rows = {
        {type = "select", key = "target", name = L["Quest to follow"],
         tooltip = L["The super-tracked quest follows Blizzard's own quest arrow, with its route through portals and zone exits. The closest quest uses the watched quest with the closest objective."],
         values = {
             supertracked = L["Super-tracked quest"],
             closest = L["Closest watched quest"],
         },
         sorting = {"supertracked", "closest"}},
    },
}

private.AddSettingsSection{
    page = "poi", pageName = L["Quest Objectives"], pageOrder = 50, order = 10,
    settingsKey = "poi",
    available = function() return not IsAvailable() end,
    rows = {
        {type = "text", text = L["Quest objective positions are not available on this game version."]},
    },
}

--[[--------------------------------------------------------------------------
--  Quest data
----------------------------------------------------------------------------]]

local function FormatTitle(title, complete, routeText)
    title = title or L["Unknown waypoint"]
    if complete then
        title = L["Turn in: %s"]:format(title)
    end
    if routeText and routeText ~= "" then
        title = title .. "\n" .. routeText
    end
    return title
end

-- The position of a quest in GetQuestsOnMap, first on the player's map,
-- then on the quest's own map. The x and y are on the map that was asked.
local function QuestPosition(questID, playerMap)
    -- true: the quest's own map, not the map of its routed step. Clients
    -- without the argument ignore it.
    local questMap = GetQuestUiMapID and GetQuestUiMapID(questID, true)
    for _, mapID in ipairs({playerMap or 0, questMap or 0}) do
        if mapID > 0 then
            for _, info in ipairs(C_QuestLog.GetQuestsOnMap(mapID) or {}) do
                if info.questID == questID and info.x and info.y then
                    return mapID, info.x, info.y
                end
            end
        end
    end
end

-- The watched quests as {questID, title, complete}.
local function WatchedQuests()
    local quests = {}
    if C_QuestLog.GetQuestIDForQuestWatchIndex then
        local index = 1
        while true do
            local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(index)
            if not questID then break end
            table.insert(quests, {
                questID = questID,
                title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID),
                complete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID),
            })
            index = index + 1
        end
    elseif GetNumQuestWatches and GetQuestIndexForWatch and GetQuestLogTitle then
        for index = 1, GetNumQuestWatches() do
            local logIndex = GetQuestIndexForWatch(index)
            if logIndex then
                local title, _, _, _, _, isComplete, _, questID = GetQuestLogTitle(logIndex)
                if questID then
                    table.insert(quests, {questID = questID, title = title, complete = isComplete == 1})
                end
            end
        end
    end
    return quests
end

local function ClosestTarget(playerMap, px, py)
    local best, bestDistance
    for _, quest in ipairs(WatchedQuests()) do
        local map, x, y = QuestPosition(quest.questID, playerMap)
        local distance = map and hbd:GetZoneDistance(playerMap, px, py, map, x, y)
        if distance and (not bestDistance or distance < bestDistance) then
            best, bestDistance = {map = map, x = x, y = y, quest = quest}, distance
        end
    end
    if best then
        best.title = FormatTitle(best.quest.title, best.quest.complete)
        return best
    end
end

-- World quests and bonus objectives are not in GetQuestsOnMap.
local function TaskQuestPosition(questID, playerMap)
    if not (playerMap and C_TaskQuest and C_TaskQuest.GetQuestLocation) then return nil end
    local x, y = C_TaskQuest.GetQuestLocation(questID, playerMap)
    if x and y then
        return playerMap, x, y
    end
end

local lastWaypoint, lastQuestID

-- A user waypoint closer than this to the quest waypoint is a copy of it.
local MIRROR_YARDS = 5

-- WaypointUI ("Track TomTom waypoints", on by default) copies the arrow
-- target into a Blizzard user waypoint and super-tracks it. The user
-- waypoint then has priority over the quest: Blizzard's arrow follows the
-- copy, and the quest can lose its super-track or its routed step. If
-- TomTom then cleared its waypoint, WaypointUI would clear its copy, the
-- quest would come back, and the two addons would loop. So the module
-- ignores the copy and finds its target as if the copy was not there.
local function FollowsQuestWaypointCopy()
    if not (lastWaypoint and TomTom:IsValidWaypoint(lastWaypoint)) then return false end
    if not (C_SuperTrack.IsSuperTrackingUserWaypoint and C_SuperTrack.IsSuperTrackingUserWaypoint()) then
        return false
    end
    local point = C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
    if not (point and point.position) then return false end
    -- A plain {x, y} table, not a Vector2D: it has no GetXY.
    local position = point.position
    local distance = hbd:GetZoneDistance(lastWaypoint[1], lastWaypoint[2], lastWaypoint[3],
        point.uiMapID, position.x, position.y)
    return distance ~= nil and distance <= MIRROR_YARDS
end

-- Returns the target, or nil and true when Blizzard's arrow follows
-- something that TomTom cannot point at (a map pin, a vignette, or a quest
-- with no position). Then the closest quest would be a different target
-- than Blizzard's arrow, so the caller clears the waypoint instead (QD3).
-- The third value is true when the caller must keep the waypoint as it is.
-- Every call is guarded.
local function SuperTrackedTarget(playerMap)
    local followsCopy = FollowsQuestWaypointCopy()
    local questID = C_SuperTrack.GetSuperTrackedQuestID()
    -- lastQuestID is set only when the waypoint came from a super-tracked
    -- quest, and the copy can have taken that quest's super-track.
    if followsCopy and lastQuestID then
        questID = lastQuestID
    end
    if not questID or questID == 0 then
        if followsCopy then
            return nil, false
        end
        local other = C_SuperTrack.IsSuperTrackingAnything and C_SuperTrack.IsSuperTrackingAnything()
        return nil, other and true or false
    end

    local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
    local complete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID)

    local map, x, y = C_QuestLog.GetNextWaypoint(questID)
    if map and map > 0 and x and y then
        local routeText = C_QuestLog.GetNextWaypointText and C_QuestLog.GetNextWaypointText(questID)
        return {map = map, x = x, y = y, questID = questID, title = FormatTitle(title, complete, routeText)}
    end

    map, x, y = QuestPosition(questID, playerMap)
    if not map then
        map, x, y = TaskQuestPosition(questID, playerMap)
    end
    if map then
        return {map = map, x = x, y = y, questID = questID, title = FormatTitle(title, complete)}
    end
    return nil, true, followsCopy
end

local function UseSuperTracked()
    return hasSuperTrack and (not hasClosest or TomTom.profile.poi.target ~= "closest")
end

local function FindTarget()
    local px, py, playerMap = hbd:GetPlayerZonePosition()
    if UseSuperTracked() then
        local target, followsOther, keep = SuperTrackedTarget(playerMap)
        if target or followsOther then
            return target, keep
        end
    end
    if hasClosest and px and py and playerMap then
        return ClosestTarget(playerMap, px, py)
    end
end

--[[--------------------------------------------------------------------------
--  The waypoint
----------------------------------------------------------------------------]]

local function ClearPOIWaypoint()
    if lastWaypoint then
        TomTom:RemoveWaypoint(lastWaypoint)
        lastWaypoint = nil
    end
    lastQuestID = nil
end

-- The waypoint changes only when the target changes, so a waypoint that
-- the user removed does not come back on the next event.
local function SetPOIWaypoint(target)
    if lastWaypoint and TomTom:WaypointHasSameMapXYTitle(lastWaypoint, target.map, target.x, target.y, target.title) then
        return
    end
    ClearPOIWaypoint()
    lastQuestID = target.questID

    lastWaypoint = TomTom:AddWaypoint(target.map, target.x, target.y, {
        title = target.title,
        persistent = false,
        crazy = false,
        arrivaldistance = TomTom.profile.poi.arrival,
        from = "TomTom/poi",
    })

    -- The quest waypoint takes the arrow only when it is empty (QD1).
    if TomTom:IsCrazyArrowEmpty() then
        TomTom:SetCrazyArrow(lastWaypoint, TomTom.profile.poi.arrival, target.title)
    end
end

local scanning
local function Scan()
    if scanning or not module:IsEnabled() then return end
    scanning = true
    local ok, target, keep = xpcall(FindTarget, geterrorhandler())
    scanning = false
    if not ok or keep then return end

    if target then
        SetPOIWaypoint(target)
    else
        ClearPOIWaypoint()
    end
end

-- The quest events fire many times in a short time. One scan after the
-- delay is sufficient for all of them.
local SCAN_DELAY = 0.5
local scanScheduled
local function ScheduleScan()
    if scanScheduled then return end
    scanScheduled = true
    C_Timer.After(SCAN_DELAY, function()
        scanScheduled = false
        Scan()
    end)
end

--[[--------------------------------------------------------------------------
--  Module
----------------------------------------------------------------------------]]

-- The last two exist only with super-tracking.
local EVENTS = {
    "QUEST_LOG_UPDATE",
    "QUEST_POI_UPDATE",
    "QUEST_WATCH_LIST_CHANGED",
    "SUPER_TRACKING_CHANGED",
    "WAYPOINT_UPDATE",
}

local function IsEventValid(event)
    if C_EventUtils and C_EventUtils.IsEventValid then
        return C_EventUtils.IsEventValid(event)
    end
    return event:find("^QUEST_") ~= nil
end

local registered = {}

-- The closest quest changes as the player moves.
local CLOSEST_INTERVAL = 5
local ticker

local function OnEvent()
    ScheduleScan()
end

function module:PlayerZoneChanged()
    ScheduleScan()
end

-- A reload removes every waypoint that is not saved, also the quest
-- waypoint, so the next scan must add it again.
function module:TOMTOM_WAYPOINTS_RELOADED()
    lastWaypoint, lastQuestID = nil, nil
    ScheduleScan()
end

-- Kaliel's Tracker replaces EnableDisablePOIIntegration and changes
-- poi.setClosest before it calls the original (integrations.md 3.4 item 7),
-- so the module start and stop go through it, and it reads the setting
-- again.
function TomTom:EnableDisablePOIIntegration()
    private.UpdateModule(module)
    if module:IsEnabled() then
        Scan()
    else
        ClearPOIWaypoint()
    end
end

function module:OnEnable()
    for _, event in ipairs(EVENTS) do
        if IsEventValid(event) then
            self:RegisterEvent(event, OnEvent)
            registered[event] = true
        end
    end
    hbd.RegisterCallback(self, "PlayerZoneChanged")
    self:RegisterMessage("TOMTOM_WAYPOINTS_RELOADED")
    if hasClosest then
        ticker = C_Timer.NewTicker(CLOSEST_INTERVAL, ScheduleScan)
    end
    -- Last: the call can turn the module off again.
    TomTom:EnableDisablePOIIntegration()
end

function module:OnDisable()
    for event in pairs(registered) do
        self:UnregisterEvent(event, OnEvent)
        registered[event] = nil
    end
    hbd.UnregisterCallback(self, "PlayerZoneChanged")
    self:UnregisterMessage("TOMTOM_WAYPOINTS_RELOADED")
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    TomTom:EnableDisablePOIIntegration()
end

function module:OnSettingChanged(key)
    if key == "arrival" or key == "target" then
        -- A new arrival distance or source needs a new waypoint.
        ClearPOIWaypoint()
    end
    TomTom:EnableDisablePOIIntegration()
end

function module:OnProfileChanged()
    ClearPOIWaypoint()
    TomTom:EnableDisablePOIIntegration()
end
