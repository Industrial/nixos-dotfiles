---@type QuestieTraceCore
local Core = QuestieTraceCore
---@type fun(num: number?, decimals: number?): number?
local Round = Core.Round
---@type fun(...): PackedArgs
local PackArgs = Core.PackArgs
---@type fun(t1: any, t2: any, ignore_mt: boolean?, visited: table?): boolean
local DeepCompare = Core.DeepCompare

local C_After = C_Timer.After

---------------------------------------------------------------------------
-- WoW API return schemas (for trace analyzer display labels)
---------------------------------------------------------------------------
-- GetZoneText()    -> string text
-- GetSubZoneText() -> string text
-- GetRealZoneText() -> string text
--
-- C_Map.GetBestMapForUnit(unit)              -> number? uiMapID
-- C_Map.GetPlayerMapPosition(uiMapID, unit)  -> vector2? position  -- stored as {x, y}
--
-- IsInInstance()    -> boolean inInstance,
--                      string  instanceType  -- "none"|"party"|"raid"|"pvp"|"arena"
--
-- GetInstanceInfo() -> string  name,
--                      string  instanceType,
--                      number  difficultyID,
--                      string  difficultyName,
--                      number  maxPlayers,
--                      number  dynamicDifficulty,
--                      boolean isDynamic,
--                      number  instanceID,
--                      number  instanceGroupSize,
--                      number  LfgDungeonID
--
-- IsIndoors()       -> boolean indoors  -- sampled with the position, so a step
--                                          into a building is caught even without
--                                          ZONE_CHANGED_INDOORS
--
-- GetPlayerFacing() is not recorded: it is restricted in instances and would
-- add about as many entries as the position stream itself. Replay derives the
-- heading from consecutive C_Map.GetPlayerMapPosition samples.
--
-- C_MapExplorationInfo.GetExploredMapTextures(uiMapID) -> UiMapExplorationInfo[]?
--   Keyed by the player's best map ID. Sampled when that map changes and on
--   MAP_EXPLORATION_UPDATED, never on timer ticks alone. Maps without
--   exploration overlays (cities, instances) return nothing, stored as nil.
---------------------------------------------------------------------------

---@type number
local POSITION_DECIMALS = 4
---@type number
local TIMER_INTERVAL = 0.20

-- Stream references (set during Init)
---@type FunctionStreamEntry[], FunctionStreamEntry[], FunctionStreamEntry[]
local streamZone, streamSubZone, streamRealZone
---@type FunctionStreamEntry[], FunctionStreamEntry[]
local streamMapID, streamPosition
---@type FunctionStreamEntry[], FunctionStreamEntry[], FunctionStreamEntry[]
local streamInstance, streamInstanceInfo, streamIndoors
---@type table<number, FunctionStreamEntry[]>? Nil when the client lacks C_MapExplorationInfo.
local exploredMapStreams

--- Sample the explored overlays of one map, change-only per map ID.
---@param t number
---@param tp number
---@param mapID number
local function SampleExploredMap(t, tp, mapID)
  if not exploredMapStreams then return end

  local ok, textures = pcall(C_MapExplorationInfo.GetExploredMapTextures, mapID)
  if not ok then return end

  local stream = exploredMapStreams[mapID]
  if not stream then
    stream = {}
    exploredMapStreams[mapID] = stream
  end
  local previous = stream[#stream]
  if not previous or not DeepCompare(textures, previous.v) then
    stream[#stream + 1] = { t = t, tp = tp, v = textures }
  end
end

--- Sample all position-related data and append changed entries to streams.
---@param capture CaptureState
---@param refreshExploredMap boolean? Re-read the current map's explored overlays even if the map is unchanged.
local function SampleAll(capture, refreshExploredMap)
  ---@type number
  local t  = GetTime() - capture.startedAt
  ---@type number
  local tp = GetTimePreciseSec() - capture.startedAtPrecise

  -- Zone texts (parameterless)
  ---@type string
  local zone = GetZoneText()
  if not streamZone[#streamZone] or streamZone[#streamZone].v ~= zone then
    streamZone[#streamZone + 1] = { t = t, tp = tp, v = zone }
  end

  ---@type string
  local subZone = GetSubZoneText()
  if not streamSubZone[#streamSubZone] or streamSubZone[#streamSubZone].v ~= subZone then
    streamSubZone[#streamSubZone + 1] = { t = t, tp = tp, v = subZone }
  end

  ---@type string
  local realZone = GetRealZoneText()
  if not streamRealZone[#streamRealZone] or streamRealZone[#streamRealZone].v ~= realZone then
    streamRealZone[#streamRealZone + 1] = { t = t, tp = tp, v = realZone }
  end

  -- Map ID (parameterized by "player")
  ---@type number?
  local mapID = C_Map.GetBestMapForUnit("player")
  ---@type FunctionStreamEntry?
  local prevMap = streamMapID[#streamMapID]
  local mapChanged = not prevMap or prevMap.v ~= mapID
  if mapChanged then
    streamMapID[#streamMapID + 1] = { t = t, tp = tp, v = mapID }
  end

  -- Explored overlays of the player's map: on arrival, and when exploration changes
  if mapID and (mapChanged or refreshExploredMap) then
    SampleExploredMap(t, tp, mapID)
  end

  -- Position (parameterized by "player")
  ---@type number?, number?
  local x, y = nil, nil
  if mapID then
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if pos then
      x, y = pos:GetXY()
      x = Round(x, POSITION_DECIMALS)
      y = Round(y, POSITION_DECIMALS)
    end
  end

  ---@type FunctionStreamEntry?
  local prevPos = streamPosition[#streamPosition]
  ---@type {x: number, y: number}?
  local posVal = (x and y) and { x = x, y = y } or nil
  ---@type boolean
  local changed
  if not prevPos then
    changed = true
  elseif prevPos.v == nil and posVal == nil then
    changed = false
  elseif prevPos.v == nil or posVal == nil then
    changed = true
  else
    changed = prevPos.v.x ~= posVal.x or prevPos.v.y ~= posVal.y
  end

  if changed then
    streamPosition[#streamPosition + 1] = { t = t, tp = tp, v = posVal }
  end

  -- Instance state (parameterless tuples)
  ---@type PackedArgs
  local instanceData = PackArgs(IsInInstance())
  if not streamInstance[#streamInstance] or not DeepCompare(streamInstance[#streamInstance].v, instanceData) then
    streamInstance[#streamInstance + 1] = { t = t, tp = tp, v = instanceData }
  end

  ---@type PackedArgs
  local instanceInfo = PackArgs(GetInstanceInfo())
  if not streamInstanceInfo[#streamInstanceInfo] or not DeepCompare(streamInstanceInfo[#streamInstanceInfo].v, instanceInfo) then
    streamInstanceInfo[#streamInstanceInfo + 1] = { t = t, tp = tp, v = instanceInfo }
  end

  -- Indoors (the minimap uses smaller radii indoors)
  ---@type boolean
  local indoors = IsIndoors()
  if not streamIndoors[#streamIndoors] or streamIndoors[#streamIndoors].v ~= indoors then
    streamIndoors[#streamIndoors + 1] = { t = t, tp = tp, v = indoors }
  end
end

--- Schedule a repeating timer to sample position data.
---@param capture CaptureState
local function ScheduleTimer(capture)
  ---@type number
  local token = capture.token
  C_After(TIMER_INTERVAL, function()
    if not capture.active or capture.token ~= token then return end
    SampleAll(capture)
    ScheduleTimer(capture)
  end)
end

---------------------------------------------------------------------------
-- Private movement event frame
-- PLAYER_STARTED_MOVING / PLAYER_STOPPED_MOVING are private sampling triggers.
-- They intentionally stay out of the main event stream to avoid trace noise,
-- while still sampling position immediately on movement transitions.
---------------------------------------------------------------------------

---@type CaptureState?
local captureRef

---@type Frame
local movementFrame = CreateFrame("Frame")
movementFrame:RegisterEvent("PLAYER_STARTED_MOVING")
movementFrame:RegisterEvent("PLAYER_STOPPED_MOVING")
movementFrame:SetScript("OnEvent", function()
  if not captureRef or not captureRef.active then return end
  SampleAll(captureRef)
end)

Core.RegisterTracker({
  events = {
    "ZONE_CHANGED",
    "ZONE_CHANGED_NEW_AREA",
    "ZONE_CHANGED_INDOORS",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_ALIVE",
    "MAP_EXPLORATION_UPDATED",
    "PLAYER_MAP_CHANGED",
    "AREA_POIS_UPDATED",
    "NEW_WMO_CHUNK",
    "SPELLS_CHANGED",
  },

  ---@param capture CaptureState
  Init = function(capture)
    captureRef = capture

    ---@type table<string, FunctionStreamEntry[]|table<string|number, FunctionStreamEntry[]>>
    local functions = capture.session.functions

    functions["GetZoneText"]    = {}
    functions["GetSubZoneText"] = {}
    functions["GetRealZoneText"] = {}
    functions["C_Map.GetBestMapForUnit"]    = { ["player"] = {} }
    functions["C_Map.GetPlayerMapPosition"] = { ["player"] = {} }
    functions["IsInInstance"]   = {}
    functions["GetInstanceInfo"] = {}
    functions["IsIndoors"]      = {}

    streamZone     = functions["GetZoneText"]
    streamSubZone  = functions["GetSubZoneText"]
    streamRealZone = functions["GetRealZoneText"]
    streamMapID    = functions["C_Map.GetBestMapForUnit"]["player"]
    streamPosition = functions["C_Map.GetPlayerMapPosition"]["player"]
    streamInstance     = functions["IsInInstance"]
    streamInstanceInfo = functions["GetInstanceInfo"]
    streamIndoors      = functions["IsIndoors"]

    exploredMapStreams = nil
    if type(C_MapExplorationInfo) == "table" and type(C_MapExplorationInfo.GetExploredMapTextures) == "function" then
      exploredMapStreams = {}
      functions["C_MapExplorationInfo.GetExploredMapTextures"] = exploredMapStreams
    end

    -- Initial sample at t=0
    SampleAll(capture)

    -- Start repeating timer
    ScheduleTimer(capture)
  end,

  ---@param capture CaptureState
  ---@param event string
  OnEvent = function(capture, event)
    SampleAll(capture, event == "MAP_EXPLORATION_UPDATED")
  end,

  ---@param capture CaptureState
  OnCaptureStopped = function(capture)
    SampleAll(capture)
    captureRef = nil
  end,
})
