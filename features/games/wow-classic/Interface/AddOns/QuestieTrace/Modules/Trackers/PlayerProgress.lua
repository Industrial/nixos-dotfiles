---@type QuestieTraceCore
local Core = QuestieTraceCore

---------------------------------------------------------------------------
-- WoW API return schemas (for trace analyzer display labels)
---------------------------------------------------------------------------
-- UnitXP("player")    -> number xp
-- UnitXPMax("player") -> number xpToLevel
-- GetXPExhaustion()   -> number? restedXP  -- nil when not rested
-- GetMoney()          -> number copper
--
-- Sampled at capture start and on every event below. Every stream is
-- change-only, and a failed call is skipped.
---------------------------------------------------------------------------

---@type FunctionStreamEntry[]?, FunctionStreamEntry[]?, FunctionStreamEntry[]?, FunctionStreamEntry[]?
local xpStream, xpMaxStream, restedStream, moneyStream

---Append an API's answer to its stream if it differs from the last entry.
---@param stream FunctionStreamEntry[]
---@param t number
---@param tp number
---@param fn function
---@param ... any Arguments for fn
local function Sample(stream, t, tp, fn, ...)
  local ok, value = pcall(fn, ...)
  if not ok then return end
  local previous = stream[#stream]
  if not previous or previous.v ~= value then
    stream[#stream + 1] = { t = t, tp = tp, v = value }
  end
end

---@param capture CaptureState
local function SampleProgress(capture)
  if not xpStream or not xpMaxStream or not restedStream or not moneyStream then return end
  local t = GetTime() - capture.startedAt
  local tp = GetTimePreciseSec() - capture.startedAtPrecise

  Sample(xpStream, t, tp, UnitXP, "player")
  Sample(xpMaxStream, t, tp, UnitXPMax, "player")
  Sample(restedStream, t, tp, GetXPExhaustion)
  Sample(moneyStream, t, tp, GetMoney)
end

Core.RegisterTracker({
  events = {
    "PLAYER_ENTERING_WORLD",
    "PLAYER_XP_UPDATE",
    "PLAYER_LEVEL_UP",
    "UPDATE_EXHAUSTION",
    "PLAYER_MONEY",
  },

  ---@param capture CaptureState
  Init = function(capture)
    local functions = capture.session.functions
    xpStream, xpMaxStream, restedStream, moneyStream = {}, {}, {}, {}
    functions["UnitXP"] = { ["player"] = xpStream }
    functions["UnitXPMax"] = { ["player"] = xpMaxStream }
    functions["GetXPExhaustion"] = restedStream
    functions["GetMoney"] = moneyStream
    SampleProgress(capture)
  end,

  ---@param capture CaptureState
  OnEvent = function(capture)
    SampleProgress(capture)
  end,
})
