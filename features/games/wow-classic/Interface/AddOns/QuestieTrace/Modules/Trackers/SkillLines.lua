---@type QuestieTraceCore
local Core = QuestieTraceCore
---@type fun(...): PackedArgs
local PackArgs = Core.PackArgs
---@type fun(t1: any, t2: any, ignore_mt: boolean?, visited: table?): boolean
local DeepCompare = Core.DeepCompare

---------------------------------------------------------------------------
-- WoW API return schemas (for trace analyzer display labels)
---------------------------------------------------------------------------
-- Each API below is probed and recorded independently, only when it
-- actually exists on the current client. There is no synthesized fallback:
-- clients without GetNumSkillLines/GetSkillLineInfo simply produce no
-- entries for those two streams, rather than fabricated rows derived from
-- professions or trade-skill data.
--
-- GetNumSkillLines() -> number numberOfSkillLines
--
-- GetSkillLineInfo(index) -> string skillName,
--                            number header,
--                            number isExpanded,
--                            number skillRank,
--                            number numTempPoints,
--                            number skillModifier,
--                            number skillMaxRank,
--                            number isAbandonable,
--                            number stepCost,
--                            number rankCost,
--                            number minLevel,
--                            number skillCostType,
--                            string skillDescription
--
-- GetProfessions() -> number prof1,
--                     number prof2,
--                     number archaeology,
--                     number fishing,
--                     number cooking
--
-- GetProfessionInfo(index) -> string name,
--                             string icon,
--                             number skillLevel,
--                             number maxSkillLevel,
--                             number numAbilities,
--                             number spelloffset,
--                             number skillLine,
--                             number skillModifier,
--                             number specializationIndex,
--                             number specializationOffset
--
-- C_TradeSkillUI.GetAllProfessionTradeSkillLines() -> number[] skillLineIDs
-- C_TradeSkillUI.GetTradeSkillLineInfoByID(skillLineID) -> table info (raw)
---------------------------------------------------------------------------

---@type table<string, FunctionStreamEntry[]|table<string|number, FunctionStreamEntry[]>>
local functions
---@type table<number, PackedArgs?>
local prevSkillLineInfo
---@type table<number, PackedArgs?>
local prevProfessionInfo
---@type table<number, table?>
local prevTradeSkillLineInfo
---@type table<number, boolean>
local knownSkillLineIndices
---@type table<number, boolean>
local knownProfessionIndices
---@type table<number, boolean>
local knownTradeSkillLineIds
---@type boolean
local expandingSkillHeaders

--- Expand all skill headers so all visible rows can be sampled.
local function ExpandAllSkillHeaders()
  if type(ExpandSkillHeader) ~= "function" then return end

  expandingSkillHeaders = true
  ExpandSkillHeader(0)
  expandingSkillHeaders = false
end

---Safely call a function and return the first result.
---@param fn function?
---@param ... any
---@return boolean ok
---@return any value
local function SafeScalarCall(fn, ...)
  if type(fn) ~= "function" then return false, nil end
  local ok, value = pcall(fn, ...)
  if not ok then return false, nil end
  return true, value
end

---Safely call a function and pack all returned values.
---@param fn function?
---@param ... any
---@return boolean ok
---@return PackedArgs? value
local function SafePackedCall(fn, ...)
  if type(fn) ~= "function" then return false, nil end
  local packed = PackArgs(pcall(fn, ...))
  if not packed[1] then return false, nil end

  local out = { n = packed.n - 1 }
  for i = 2, packed.n do
    out[i - 1] = packed[i]
  end
  return true, out
end

--- Append a value to a parameterized stream only when it changed.
---@param funcName string
---@param key number
---@param prev table<number, any>
---@param t number
---@param tp number
---@param value any
local function AppendPackedIfChanged(funcName, key, prev, t, tp, value)
  local old = prev[key]
  ---@type boolean
  local changed

  if old == nil and value == nil then
    changed = functions[funcName][key] == nil or #functions[funcName][key] == 0
  elseif old == nil or value == nil then
    changed = true
  else
    changed = not DeepCompare(old, value)
  end

  if not changed then return end

  local stream = functions[funcName][key]
  if not stream then
    stream = {}
    functions[funcName][key] = stream
  end
  stream[#stream + 1] = { t = t, tp = tp, v = value }
  prev[key] = value
end

--- Append a scalar to a parameterless stream when it changed.
---@param stream FunctionStreamEntry[]
---@param t number
---@param tp number
---@param value any
local function AppendScalarIfChanged(stream, t, tp, value)
  local prev = stream[#stream]
  if not prev or prev.v ~= value then
    stream[#stream + 1] = { t = t, tp = tp, v = value }
  end
end

--- Append a tuple to a parameterless stream when it changed.
---@param stream FunctionStreamEntry[]
---@param t number
---@param tp number
---@param value PackedArgs
local function AppendTupleIfChanged(stream, t, tp, value)
  local prev = stream[#stream]
  if not prev or not DeepCompare(prev.v, value) then
    stream[#stream + 1] = { t = t, tp = tp, v = value }
  end
end

--- Sample GetNumSkillLines/GetSkillLineInfo. No-op when GetNumSkillLines
--- doesn't exist on this client -- there is no synthesized fallback.
---@param t number
---@param tp number
local function SampleSkillLines(t, tp)
  if type(GetNumSkillLines) ~= "function" then return end

  local numOk, numSkillLines = SafeScalarCall(GetNumSkillLines)
  if numOk then
    AppendScalarIfChanged(functions["GetNumSkillLines"], t, tp, numSkillLines)
  end

  if type(GetSkillLineInfo) ~= "function" then return end

  ---@type table<number, boolean>
  local seenSkillLineIndices = {}
  if type(numSkillLines) == "number" then
    for index = 1, numSkillLines do
      local ok, value = SafePackedCall(GetSkillLineInfo, index)
      if ok and value then
        seenSkillLineIndices[index] = true
        knownSkillLineIndices[index] = true
        AppendPackedIfChanged("GetSkillLineInfo", index, prevSkillLineInfo, t, tp, value)
      end
    end
  end

  for index in pairs(knownSkillLineIndices) do
    if not seenSkillLineIndices[index] then
      local ok, value = SafePackedCall(GetSkillLineInfo, index)
      if ok and value then
        AppendPackedIfChanged("GetSkillLineInfo", index, prevSkillLineInfo, t, tp, value)
      end
    end
  end
end

--- Sample GetProfessions/GetProfessionInfo. No-op when GetProfessions
--- doesn't exist on this client.
---@param t number
---@param tp number
local function SampleProfessions(t, tp)
  if type(GetProfessions) ~= "function" then return end

  local professions = PackArgs(GetProfessions())
  AppendTupleIfChanged(functions["GetProfessions"], t, tp, professions)

  if type(GetProfessionInfo) ~= "function" then return end

  ---@type table<number, boolean>
  local seenProfessionIndices = {}
  for i = 1, professions.n do
    local professionIndex = professions[i]
    if type(professionIndex) == "number" then
      seenProfessionIndices[professionIndex] = true
      knownProfessionIndices[professionIndex] = true
      local value = PackArgs(GetProfessionInfo(professionIndex))
      AppendPackedIfChanged("GetProfessionInfo", professionIndex, prevProfessionInfo, t, tp, value)
    end
  end

  for professionIndex in pairs(knownProfessionIndices) do
    if not seenProfessionIndices[professionIndex] then
      local ok, value = SafePackedCall(GetProfessionInfo, professionIndex)
      if ok and value then
        AppendPackedIfChanged("GetProfessionInfo", professionIndex, prevProfessionInfo, t, tp, value)
      end
    end
  end
end

--- Sample C_TradeSkillUI profession trade-skill lines. This is an
--- independent raw API tracked whenever it exists, not a fallback for
--- GetNumSkillLines/GetSkillLineInfo.
---@param t number
---@param tp number
local function SampleTradeSkillLines(t, tp)
  if type(C_TradeSkillUI) ~= "table"
      or type(C_TradeSkillUI.GetAllProfessionTradeSkillLines) ~= "function"
      or type(C_TradeSkillUI.GetTradeSkillLineInfoByID) ~= "function" then
    return
  end

  local ok, skillLineIDs = SafeScalarCall(C_TradeSkillUI.GetAllProfessionTradeSkillLines)
  if not ok or type(skillLineIDs) ~= "table" then return end

  local stream = functions["C_TradeSkillUI.GetAllProfessionTradeSkillLines"]
  local prev = stream[#stream]
  if not prev or not DeepCompare(prev.v, skillLineIDs) then
    ---@type number[]
    local copy = {}
    for i = 1, #skillLineIDs do copy[i] = skillLineIDs[i] end
    stream[#stream + 1] = { t = t, tp = tp, v = copy }
  end

  ---@type table<number, boolean>
  local seenSkillLineIds = {}
  for _, skillLineID in ipairs(skillLineIDs) do
    seenSkillLineIds[skillLineID] = true
    knownTradeSkillLineIds[skillLineID] = true
    local infoOk, info = SafeScalarCall(C_TradeSkillUI.GetTradeSkillLineInfoByID, skillLineID)
    if infoOk and info then
      AppendPackedIfChanged("C_TradeSkillUI.GetTradeSkillLineInfoByID", skillLineID, prevTradeSkillLineInfo, t, tp, info)
    end
  end

  for skillLineID in pairs(knownTradeSkillLineIds) do
    if not seenSkillLineIds[skillLineID] then
      local infoOk, info = SafeScalarCall(C_TradeSkillUI.GetTradeSkillLineInfoByID, skillLineID)
      if infoOk and info then
        AppendPackedIfChanged("C_TradeSkillUI.GetTradeSkillLineInfoByID", skillLineID, prevTradeSkillLineInfo, t, tp, info)
      end
    end
  end
end

--- Sample the skill window, profession, and trade-skill-line APIs.
---@param capture CaptureState
local function SampleSkills(capture)
  if not functions then return end

  ExpandAllSkillHeaders()

  ---@type number
  local t = GetTime() - capture.startedAt
  ---@type number
  local tp = GetTimePreciseSec() - capture.startedAtPrecise

  SampleSkillLines(t, tp)
  SampleProfessions(t, tp)
  SampleTradeSkillLines(t, tp)
end

Core.RegisterTracker({
  events = {
    "SKILL_LINES_CHANGED",
    "PLAYER_ENTERING_WORLD",
    "SPELLS_CHANGED",
  },

  ---@param capture CaptureState
  Init = function(capture)
    functions = capture.session.functions
    prevSkillLineInfo = {}
    prevProfessionInfo = {}
    prevTradeSkillLineInfo = {}
    knownSkillLineIndices = {}
    knownProfessionIndices = {}
    knownTradeSkillLineIds = {}
    expandingSkillHeaders = false

    if type(GetNumSkillLines) == "function" then
      functions["GetNumSkillLines"] = {}
    end
    if type(GetSkillLineInfo) == "function" then
      functions["GetSkillLineInfo"] = {}
    end
    if type(GetProfessions) == "function" then
      functions["GetProfessions"] = {}
    end
    if type(GetProfessionInfo) == "function" then
      functions["GetProfessionInfo"] = {}
    end
    if type(C_TradeSkillUI) == "table"
        and type(C_TradeSkillUI.GetAllProfessionTradeSkillLines) == "function"
        and type(C_TradeSkillUI.GetTradeSkillLineInfoByID) == "function" then
      functions["C_TradeSkillUI.GetAllProfessionTradeSkillLines"] = {}
      functions["C_TradeSkillUI.GetTradeSkillLineInfoByID"] = {}
    end

    SampleSkills(capture)
  end,

  ---@param capture CaptureState
  ---@param event string
  OnEvent = function(capture, event)
    if event == "SKILL_LINES_CHANGED" and expandingSkillHeaders then
      return
    end
    SampleSkills(capture)
  end,
})
