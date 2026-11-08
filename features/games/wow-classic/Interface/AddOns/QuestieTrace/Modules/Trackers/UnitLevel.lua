---@type QuestieTraceCore
local Core = QuestieTraceCore

---------------------------------------------------------------------------
-- WoW API return schemas (for trace analyzer display labels)
---------------------------------------------------------------------------
-- UnitLevel(unit)       -> number level
-- GetQuestGreenRange()  -> number greenRange
---------------------------------------------------------------------------

---@type FunctionStreamEntry[]? Shortcut to functions["UnitLevel"]["player"]
local stream

Core.RegisterTracker({
  events = { "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED" },

  ---@param capture CaptureState
  Init = function(capture)
    ---@type number
    local level = UnitLevel("player")
    ---@type table<string, FunctionStreamEntry[]|table<string|number, FunctionStreamEntry[]>>
    local functions = capture.session.functions
    functions["UnitLevel"] = {
      ["player"] = { { t = 0, tp = 0, v = level } },
    }
    stream = functions["UnitLevel"]["player"]
  end,

  ---@param capture CaptureState
  OnEvent = function(capture)
    if not stream then return end
    ---@type number
    local t  = GetTime() - capture.startedAt
    ---@type number
    local tp = GetTimePreciseSec() - capture.startedAtPrecise

    ---@type number
    local level = UnitLevel("player")
    ---@type FunctionStreamEntry?
    local prevLevel = stream[#stream]
    if not prevLevel or prevLevel.v ~= level then
      stream[#stream + 1] = { t = t, tp = tp, v = level }
    end
  end,
})
