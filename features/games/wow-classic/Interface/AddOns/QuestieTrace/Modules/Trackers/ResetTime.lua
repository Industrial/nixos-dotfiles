---@type QuestieTraceCore
local Core = QuestieTraceCore
---@type fun(t1: any, t2: any, ignore_mt: boolean?, visited: table?): boolean
local DeepCompare = Core.DeepCompare

---------------------------------------------------------------------------
-- WoW API return schemas (for trace analyzer display labels)
---------------------------------------------------------------------------
-- GetServerTime()     -> number serverTime
-- GetQuestResetTime() -> number nextReset (legacy global)
-- C_DateAndTime.GetSecondsUntilDailyReset() -> number secondsUntilReset
-- C_DateAndTime.GetCurrentCalendarTime() -> CalendarTime { year, month, monthDay, weekday, hour, minute }
--   Realm-local time. Sampled with GetServerTime, so replay can derive the
--   realm's UTC offset from one pair of samples.
---------------------------------------------------------------------------

---@type table<string, FunctionStream>
local functions
---@type table<string, any>
local previousValues

---@class ResetTimeStreamDef
---@field key string Stream key stored in `session.functions`.
---@field fn function Zero-argument WoW API sampled defensively with pcall.

---@type ResetTimeStreamDef[]
local streams

---Append a value to a stream if it changed.
---@param stream FunctionStreamEntry[]
---@param t number
---@param tp number
---@param key string
---@param value any
local function AppendIfChanged(stream, t, tp, key, value)
  local previous = previousValues[key]
  ---@type boolean
  local changed

  if previous == nil and value == nil then
    changed = #stream == 0
  elseif previous == nil or value == nil then
    changed = true
  elseif type(value) == "table" then
    changed = not DeepCompare(value, previous)
  else
    changed = value ~= previous
  end

  if changed then
    stream[#stream + 1] = { t = t, tp = tp, v = value }
    previousValues[key] = value
  end
end

---Create stream definitions for APIs available on this client. Each API is
---probed and recorded independently, only when it actually exists -- there
---is no synthesized/normalized composite value.
---@return ResetTimeStreamDef[]
local function BuildStreams()
  ---@type ResetTimeStreamDef[]
  local defs = {}

  if type(GetServerTime) == "function" then
    functions["GetServerTime"] = {}
    defs[#defs + 1] = { key = "GetServerTime", fn = GetServerTime }
  end

  if type(GetQuestResetTime) == "function" then
    functions["GetQuestResetTime"] = {}
    defs[#defs + 1] = { key = "GetQuestResetTime", fn = GetQuestResetTime }
  end

  if type(C_DateAndTime) == "table" and type(C_DateAndTime.GetSecondsUntilDailyReset) == "function" then
    functions["C_DateAndTime.GetSecondsUntilDailyReset"] = {}
    defs[#defs + 1] = { key = "C_DateAndTime.GetSecondsUntilDailyReset", fn = C_DateAndTime.GetSecondsUntilDailyReset }
  end

  if type(C_DateAndTime) == "table" and type(C_DateAndTime.GetCurrentCalendarTime) == "function" then
    functions["C_DateAndTime.GetCurrentCalendarTime"] = {}
    defs[#defs + 1] = { key = "C_DateAndTime.GetCurrentCalendarTime", fn = C_DateAndTime.GetCurrentCalendarTime }
  end

  return defs
end

---Sample all available reset-time streams.
---These are low-frequency snapshots, not a per-second clock trace. Replay
---consumers that need continuously increasing server time or countdown reset
---semantics should derive them from the nearest sampled value and replay time.
---@param capture CaptureState
local function SampleResetTime(capture)
  local t = GetTime() - capture.startedAt
  local tp = GetTimePreciseSec() - capture.startedAtPrecise

  for i = 1, #streams do
    local def = streams[i]
    local ok, value = pcall(def.fn)
    if ok then
      local stream = functions[def.key]
      ---@cast stream FunctionStreamEntry[]
      AppendIfChanged(stream, t, tp, def.key, value)
    end
  end
end

Core.RegisterTracker({
  events = {
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_LOGOUT",
  },

  ---@param capture CaptureState
  Init = function(capture)
    functions = capture.session.functions
    previousValues = {}
    streams = BuildStreams()

    SampleResetTime(capture)
  end,

  ---@param capture CaptureState
  OnEvent = function(capture)
    SampleResetTime(capture)
  end,
})
