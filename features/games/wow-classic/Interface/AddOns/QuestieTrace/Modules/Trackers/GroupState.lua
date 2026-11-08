---@type QuestieTraceCore
local Core = QuestieTraceCore

---------------------------------------------------------------------------
-- WoW API return schemas (for trace analyzer display labels)
---------------------------------------------------------------------------
-- IsInGroup()          -> boolean inGroup
-- GetNumGroupMembers() -> number  numMembers
---------------------------------------------------------------------------

---@type FunctionStreamEntry[]?
local streamInGroup
---@type FunctionStreamEntry[]?
local streamGroupSize

Core.RegisterTracker({
  events = {
    "GROUP_JOINED",
    "GROUP_LEFT",
    "GROUP_ROSTER_UPDATE",
    "PLAYER_ENTERING_WORLD",
    "SPELLS_CHANGED",
  },

  ---@param capture CaptureState
  Init = function(capture)
    ---@type table<string, FunctionStreamEntry[]|table<string|number, FunctionStreamEntry[]>>
    local functions = capture.session.functions
    ---@type boolean
    local inGroup = IsInGroup() and true or false
    ---@type number
    local groupSize = GetNumGroupMembers()

    functions["IsInGroup"]          = { { t = 0, tp = 0, v = inGroup } }
    functions["GetNumGroupMembers"] = { { t = 0, tp = 0, v = groupSize } }

    streamInGroup  = functions["IsInGroup"]
    streamGroupSize = functions["GetNumGroupMembers"]
  end,

  ---@param capture CaptureState
  OnEvent = function(capture)
    if not streamInGroup or not streamGroupSize then return end
    ---@type number
    local t  = GetTime() - capture.startedAt
    ---@type number
    local tp = GetTimePreciseSec() - capture.startedAtPrecise

    ---@type boolean
    local inGroup = IsInGroup() and true or false
    ---@type FunctionStreamEntry?
    local prevGroup = streamInGroup[#streamInGroup]
    if not prevGroup or prevGroup.v ~= inGroup then
      streamInGroup[#streamInGroup + 1] = { t = t, tp = tp, v = inGroup }
    end

    ---@type number
    local groupSize = GetNumGroupMembers()
    ---@type FunctionStreamEntry?
    local prevSize = streamGroupSize[#streamGroupSize]
    if not prevSize or prevSize.v ~= groupSize then
      streamGroupSize[#streamGroupSize + 1] = { t = t, tp = tp, v = groupSize }
    end
  end,
})
