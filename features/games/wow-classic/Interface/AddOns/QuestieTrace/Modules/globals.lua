QuestieTraceCore = QuestieTraceCore or {}

---@class QuestieTraceCore
local Core = QuestieTraceCore

---------------------------------------------------------------------------
-- Shared type definitions (used across all trackers)
---------------------------------------------------------------------------

---@class FunctionStreamEntry
---@field t number Relative time from GetTime()
---@field tp number Relative time from GetTimePreciseSec()
---@field v any The value at this point in time

---A stored API stream leaf or nested parameter map.
---Parameterless APIs store the leaf array directly. Parameterized APIs nest by
---native argument order until the final value is a FunctionStreamEntry[] leaf;
---for example `GetQuestLogRewardInfo(index, questID)` is stored as
---`functions["GetQuestLogRewardInfo"][index][questID]`.
---@alias FunctionStream FunctionStreamEntry[]|table<string|number, FunctionStream>

---@class EventRecord
---@field t number Relative time from GetTime()
---@field tp number Relative time from GetTimePreciseSec()
---@field e string Event name
---@field a PackedArgs Event arguments

---@class PackedArgs
---@field n number Number of arguments
---@field [number] any Positional arguments

---@class DeltaStreamEntry
---@field t number Relative time from GetTime()
---@field tp number Relative time from GetTimePreciseSec()
---@field add number[]? Added IDs
---@field remove number[]? Removed IDs

---@class DeltaStream
---@field t number Initial timestamp
---@field tp number Initial precise timestamp
---@field initial number[] Initial set of IDs
---@field delta DeltaStreamEntry[] Ordered delta entries

---@class SessionRecord
---@field schemaVersion number
---@field recordingContractVersion number? 1 = observed raw API streams; absent = legacy/unknown.
---@field buildInfo PackedArgs? Raw GetBuildInfo() at capture start (schema 15+): version, build, date, interfaceVersion, ...
---@field name string?
---@field startedAt number
---@field startedAtPrecise number
---@field stoppedAt number?
---@field stoppedAtPrecise number?
---@field duration number?
---@field durationPrecise number?
---@field events EventRecord[]
---@field functions table<string, FunctionStream>
---@field functionsDelta table<string, DeltaStream>
---@field frameUpdates FunctionStreamEntry[]? Addon frame updates that start the session or end a gap (schema 15+); v = seconds since the previous one.

--- A saved session as stored in QuestieTraceCharacter.sessions: the full
--- SessionRecord encoded like the export string, plus metadata readable
--- without decoding. Older plain-table saves are encoded at login.
---@class EncodedSessionRecord
---@field name string?
---@field schemaVersion number
---@field duration number?
---@field eventCount number
---@field encoded string Core.EncodeExportPayload(session)

---@class CaptureState
---@field active boolean
---@field token number
---@field startedAt number?
---@field startedAtPrecise number?
---@field session SessionRecord?

---@class TrackerDef
---@field events string[]?
---@field Init fun(capture: CaptureState)?
---@field OnEvent fun(capture: CaptureState, event: string, ...)?
---@field OnCaptureStopped fun(capture: CaptureState)?

---@class DumpDef
---@field key string
---@field helpText string?
---@field slashCommands string[]?
---@field events string[]?
---@field Run fun(event: string?, ...): (boolean?, string?)

---@class StatusData
---@field captureState "running"|"stopped_unsaved"|"idle"
---@field isRunning boolean
---@field sessionName string
---@field eventCount number
---@field canSave boolean
---@field sessionDuration number? Duration in seconds, only when running

---@class EventCategory
---@field name string
---@field events string[]

---@class MapRectData
---@field minX number
---@field maxX number
---@field minY number
---@field maxY number

---@class QuestieTraceMapEntry
---@field name string
---@field parentMapID number
---@field mapType number
---@field children number[]
---@field rect MapRectData?

---@class MapHierarchyDumpData
---@field schemaVersion number
---@field capturedAt string
---@field fallbackWorldMapID number
---@field rootSeeds number[]
---@field topUiMapIDs number[]
---@field mapsWithChildren number[]
---@field maps table<number, QuestieTraceMapEntry>
---@field rectOnMap table<number, table<number, MapRectData>>

---@class QuestieTraceDumpsData
---@field schemaVersion number
---@field dumps table<string, any>

---------------------------------------------------------------------------
-- Deep compare
---------------------------------------------------------------------------

--- Deep compare two values (ignores "timestamp" keys for backwards compat).
---@param t1 any
---@param t2 any
---@param ignore_mt boolean?
---@param visited table<table, table>? Internal cycle-detection table
---@return boolean equal
function Core.DeepCompare(t1, t2, ignore_mt, visited)
  if t1 == t2 then return true end

  local type1, type2 = type(t1), type(t2)
  if type1 ~= type2 then return false end
  if type1 ~= "table" then return false end

  visited = visited or {}
  if visited[t1] and visited[t1] == t2 then return true end
  visited[t1] = t2

  if not ignore_mt then
    local mt1, mt2 = getmetatable(t1), getmetatable(t2)
    if mt1 or mt2 then
      if not Core.DeepCompare(mt1, mt2, ignore_mt, visited) then
        return false
      end
    end
  end

  for key, value in pairs(t1) do
    if t2[key] == nil or not Core.DeepCompare(value, t2[key], ignore_mt, visited) then
      return false
    end
  end

  for key in pairs(t2) do
    if t1[key] == nil then
      return false
    end
  end

  return true
end

---------------------------------------------------------------------------
-- Shared helpers used by multiple trackers
---------------------------------------------------------------------------

--- Pack varargs into a table with n field.
---@param ... any The arguments to pack
---@return PackedArgs
function Core.PackArgs(...)
  local tbl = { ... }
  ---@cast tbl PackedArgs
  tbl.n = select("#", ...)
  return tbl
end

--- Copy a packed-args table (table with n field).
---@param args PackedArgs?
---@return PackedArgs
function Core.CopyPacked(args)
  if type(args) ~= "table" then
    return { n = 0 }
  end
  local out = {}
  local n = args.n or #args
  for i = 1, n do
    out[i] = args[i]
  end
  out.n = n
  return out
end

--- Round a number to the given decimal places.
---@param num number?
---@param decimals number?
---@return number?
function Core.Round(num, decimals)
  if type(num) ~= "number" then return num end
  local mult = 10 ^ (decimals or 0)
  return math.floor(num * mult + 0.5) / mult
end

---------------------------------------------------------------------------
-- Tracker registration
---------------------------------------------------------------------------

---@type table<string, fun(capture: CaptureState, event: string, ...)[]>
Core._trackerCallbacks = {}
---@type TrackerDef[]
Core._trackers = {}

--- Register a tracker with the event routing system.
---@param tracker TrackerDef
function Core.RegisterTracker(tracker)
  Core._trackers[#Core._trackers + 1] = tracker
  if tracker.events then
    for _, event in ipairs(tracker.events) do
      if not Core._trackerCallbacks[event] then
        Core._trackerCallbacks[event] = {}
      end
      local cbs = Core._trackerCallbacks[event]
      cbs[#cbs + 1] = tracker.OnEvent
    end
  end
end

---------------------------------------------------------------------------
-- Coalesced re-sampling
---------------------------------------------------------------------------

---@type number[] Follow-up sample offsets (seconds) after the latest request, to catch server lag
Core.RESAMPLE_DELAYS = { 0.10, 0.35, 0.55, 0.75, 1.00 }
local QUIET_SAMPLES_TO_SETTLE = 3

--- Create a scheduler that coalesces bursts of sample requests (e.g. the many
--- quest events fired by a single quest accept).
--- The first request in a frame samples immediately, so intermediate states
--- stay recorded; further requests in the same frame trigger a single extra
--- sample on the next frame. Every request restarts one chain of follow-up
--- samples, which skips ahead to the last delay once consecutive samples
--- recorded nothing.
--- The second return value restarts only the follow-up chain, for callers that
--- just took a sample themselves (e.g. a tracker's start snapshot).
---@param sample fun(capture: CaptureState, chainEnded: boolean?): boolean Returns true when the sample recorded a change; chainEnded is true for the last sample of a follow-up chain
---@return fun(capture: CaptureState) request
---@return fun(capture: CaptureState) followUp
function Core.CreateSampleScheduler(sample)
  local delays = Core.RESAMPLE_DELAYS
  local sampledThisFrame = false
  local requestedAgainThisFrame = false
  local chainGeneration = 0
  ---@type CaptureState?
  local frameCapture
  ---@type number?
  local frameToken

  ---@param capture CaptureState
  ---@param token number
  ---@param generation number
  ---@param step number
  ---@param quietSamples number
  ---@param previousDelay number
  local function ScheduleFollowUp(capture, token, generation, step, quietSamples, previousDelay)
    C_Timer.After(delays[step] - previousDelay, function()
      if generation ~= chainGeneration or (not capture.active) or capture.token ~= token then
        return
      end
      local ok, changed = pcall(sample, capture, step == #delays)
      if ok and changed then
        quietSamples = 0
      else
        quietSamples = quietSamples + 1
      end
      if step < #delays then
        -- Once settled, skip ahead to the last delay so late server data is still caught
        local nextStep = quietSamples < QUIET_SAMPLES_TO_SETTLE and step + 1 or #delays
        ScheduleFollowUp(capture, token, generation, nextStep, quietSamples, delays[step])
      end
      if (not ok) then
        error(changed, 0)
      end
    end)
  end

  ---@param capture CaptureState
  local function RestartFollowUps(capture)
    chainGeneration = chainGeneration + 1
    ScheduleFollowUp(capture, capture.token, chainGeneration, 1, 0, 0)
  end

  local function Request(capture)
    local token = capture.token
    -- A restarted capture must not be suppressed by the previous capture's frame state
    if frameCapture ~= capture or frameToken ~= token then
      sampledThisFrame = false
      requestedAgainThisFrame = false
    end
    frameCapture = capture
    frameToken = token

    RestartFollowUps(capture)

    if sampledThisFrame then
      requestedAgainThisFrame = true
      return
    end

    sampledThisFrame = true
    -- Schedule the frame reset before sampling so a failing sample cannot block later requests
    C_Timer.After(0, function()
      if frameCapture ~= capture or frameToken ~= token then
        return
      end
      sampledThisFrame = false
      if requestedAgainThisFrame then
        requestedAgainThisFrame = false
        if capture.active and capture.token == token then
          sample(capture)
        end
      end
    end)
    sample(capture)
  end

  return Request, RestartFollowUps
end

---------------------------------------------------------------------------
-- Dump registration
---------------------------------------------------------------------------

---@type DumpDef[]
Core._dumps = {}
---@type table<string, DumpDef>
Core._dumpsBySlash = {}
---@type table<string, DumpDef[]>
Core._dumpCallbacks = {}

--- Register a dump provider with optional slash command and event triggers.
---@param dump DumpDef
function Core.RegisterDump(dump)
  if type(dump) ~= "table" or type(dump.key) ~= "string" or type(dump.Run) ~= "function" then
    return
  end

  Core._dumps[#Core._dumps + 1] = dump

  if type(dump.slashCommands) == "table" then
    for i = 1, #dump.slashCommands do
      local slash = string.lower(tostring(dump.slashCommands[i] or ""))
      if slash ~= "" then
        Core._dumpsBySlash[slash] = dump
      end
    end
  end

  if type(dump.events) == "table" then
    for i = 1, #dump.events do
      local event = dump.events[i]
      if type(event) == "string" and event ~= "" then
        if not Core._dumpCallbacks[event] then
          Core._dumpCallbacks[event] = {}
        end
        local callbacks = Core._dumpCallbacks[event]
        callbacks[#callbacks + 1] = dump
      end
    end
  end
end

--- Run dumps registered for a specific event.
---@param event string
---@param ... any
function Core.RunDumpsForEvent(event, ...)
  local callbacks = Core._dumpCallbacks[event]
  if not callbacks then return end
  for i = 1, #callbacks do
    local dump = callbacks[i]
    local ok, err = pcall(dump.Run, event, ...)
    if not ok then
      Core.Debug("Dump failed:", dump.key, err)
    elseif err then
      Core.Debug("Dump warning:", dump.key, err)
    end
  end
end

--- Run a dump via slash command.
---@param action string
---@param ... any
---@return boolean handled
function Core.RunDumpBySlash(action, ...)
  local dump = Core._dumpsBySlash[string.lower(action or "")]
  if not dump then return false end
  local ok, err = pcall(dump.Run, "SLASH", ...)
  if not ok then
    Core.Debug("Dump failed:", dump.key, err)
  elseif err then
    Core.Debug("Dump warning:", dump.key, err)
  end
  return true
end

--- Get additional help lines from registered dump providers.
---@return string[] lines
function Core.GetDumpHelpLines()
  local lines = {}
  for i = 1, #Core._dumps do
    local help = Core._dumps[i].helpText
    if type(help) == "string" and help ~= "" then
      lines[#lines + 1] = help
    end
  end
  table.sort(lines)
  return lines
end

--- Print a debug message if debug mode is enabled.
---@param ... any Values to print
function Core.Debug(...)
  if QuestieTrace and QuestieTrace.settings and QuestieTrace.settings.debug then
    Core.Print("DEBUG:", ...)
  end
end

--- Print an error message, always printed regardless of debug settings.
--- Intended for hard failures such as a Compat wrapper finding no available
--- WoW API to call.
---@param ... any Values to print
function Core.Error(...)
  Core.Print("|cffff0000ERROR:|r", ...)
end

--- Print a message with colored addon name prefix.
--- Usage: Core.Print("message") or Core.Print("msg1", "msg2", ...)
function Core.Print(...)
  local parts = { ... }
  for i, v in ipairs(parts) do
    parts[i] = tostring(v)
  end
  local message = table.concat(parts, " ")
  print("|cFFFFD100QuestieTrace|r: " .. message)
end
