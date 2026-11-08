---@type QuestieTraceCore
local Core = QuestieTraceCore

---------------------------------------------------------------------------
-- WoW API return schemas (for trace analyzer display labels)
---------------------------------------------------------------------------
-- UnitLevel(unit)           -> number (or -1 for "??")
-- UnitClassification(unit)  -> string ("normal", "elite", "rare", "rareelite", "worldboss", "trivial", "minus")
-- UnitReaction(unit, unit)  -> number 1..8 (or nil)
-- UnitSubName (synthetic)   -> string: NPC title line ("Innkeeper") from
--   TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, func),
--   i.e. the line after the UnitName line unless it is the level line.
--   "" when the NPC has no title. mouseover only, Modern/Forever only.
---------------------------------------------------------------------------

---@type string[]
local TOKENS = { "target", "mouseover" }

-- Stream references (set during Init)
---@type table<string, FunctionStreamEntry[]>?
local levelStreams
---@type table<string, FunctionStreamEntry[]>?
local classificationStreams
---@type table<string, FunctionStreamEntry[]>?
local reactionStreams
---@type FunctionStreamEntry[]?
local subNameStream
---@type CaptureState?
local currentCapture
---@type boolean
local unitTooltipProcessorRegistered = false

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

---Sample UnitLevel, UnitClassification, and UnitReaction for all tokens.
---@param t number Session-relative GetTime()
---@param tp number Session-relative GetTimePreciseSec()
local function SampleAll(t, tp)
  if not levelStreams or not classificationStreams or not reactionStreams then return end

  for _, token in ipairs(TOKENS) do
    -- Guard: only sample non-player creatures
    if UnitExists(token) and not UnitIsPlayer(token) then
      -- UnitLevel (scalar number). -1 indicates "??" (unknown/skull).
      local levelOk, level = SafeScalarCall(UnitLevel, token)
      if levelOk and level ~= nil then
        ---@type FunctionStreamEntry[]
        local levelStream = levelStreams[token]
        ---@type FunctionStreamEntry?
        local prevLevel = levelStream[#levelStream]
        if not prevLevel or prevLevel.v ~= level then
          levelStream[#levelStream + 1] = { t = t, tp = tp, v = level }
        end
      end

      -- UnitClassification (scalar string). Returns nil for non-existent units.
      local classOk, class = SafeScalarCall(UnitClassification, token)
      if classOk and class ~= nil then
        ---@type FunctionStreamEntry[]
        local classStream = classificationStreams[token]
        ---@type FunctionStreamEntry?
        local prevClass = classStream[#classStream]
        if not prevClass or prevClass.v ~= class then
          classStream[#classStream + 1] = { t = t, tp = tp, v = class }
        end
      end

      -- UnitReaction (scalar number 1..8). Native argument order: UnitReaction("player", token).
      local reactionOk, reaction = SafeScalarCall(UnitReaction, "player", token)
      if reactionOk and reaction ~= nil then
        ---@type FunctionStreamEntry[]
        local reactionStream = reactionStreams[token]
        ---@type FunctionStreamEntry?
        local prevReaction = reactionStream[#reactionStream]
        if not prevReaction or prevReaction.v ~= reaction then
          reactionStream[#reactionStream + 1] = { t = t, tp = tp, v = reaction }
        end
      end
    end
  end
end

---Safely get a string value from a possibly-secret (tainted) value.
---@param value any
---@return string?
local function SafeString(value)
  if type(value) ~= "string" then return nil end
  if issecretvalue and issecretvalue(value) then return nil end
  return value
end

---Whether a tooltip line is the localized "Level %s ..." line.
---@param text string
---@return boolean
local function IsLevelLine(text)
  local template = type(TOOLTIP_UNIT_LEVEL) == "string" and TOOLTIP_UNIT_LEVEL or "Level %s"
  local prefix, suffix = template:match("^(.-)%%s(.*)$")
  if not prefix then return false end
  if prefix ~= "" then
    return text:sub(1, #prefix) == prefix
  end
  return suffix ~= "" and text:find(suffix, 1, true) ~= nil
end

---Extract the NPC title from unit tooltip data.
---@param tooltipData TooltipData
---@return string? subName "" when the NPC has no title, nil when unreadable
local function ExtractSubName(tooltipData)
  local lines = tooltipData.lines
  if not lines then return nil end
  for i = 1, #lines do
    if lines[i] and lines[i].type == Enum.TooltipDataLineType.UnitName then
      local nextLine = lines[i + 1]
      if not nextLine then return "" end
      if nextLine.type == Enum.TooltipDataLineType.UnitOwner then return "" end
      local text = SafeString(nextLine.leftText)
      if not text then return nil end
      if Enum.TooltipDataLineType.UnitLevel then
        if nextLine.type == Enum.TooltipDataLineType.UnitLevel then return "" end
      elseif IsLevelLine(text) then
        return ""
      end
      return Core.SanitizeText(text)
    end
  end
  return nil
end

---TooltipDataProcessor post-call for unit tooltips.
---@param _ any tooltip (unused)
---@param tooltipData TooltipData?
local function SampleSubName(_, tooltipData)
  local capture = currentCapture
  if not subNameStream or not capture or not tooltipData then return end
  local guid = tooltipData.guid
  if Core.ParseGUIDKind(guid) ~= "npc" then return end

  -- Unit tooltips are hover-driven (world and unit frames), so only mouseover is tracked.
  local token = "mouseover"
  if not UnitExists(token) or UnitIsPlayer(token) or UnitPlayerControlled(token) then return end
  if UnitGUID(token) ~= guid then return end

  local subName = ExtractSubName(tooltipData)
  if subName == nil then return end
  local stream = subNameStream
  local prev = stream[#stream]
  if not prev or prev.v ~= subName then
    stream[#stream + 1] = {
      t = GetTime() - capture.startedAt,
      tp = GetTimePreciseSec() - capture.startedAtPrecise,
      v = subName,
    }
  end
end

---Register the TooltipDataProcessor unit hook (Modern/Forever only).
local function RegisterUnitTooltipProcessor()
  if unitTooltipProcessorRegistered then return end
  if not TooltipDataProcessor or not TooltipDataProcessor.AddTooltipPostCall then return end
  if not Enum or not Enum.TooltipDataType or not Enum.TooltipDataType.Unit then return end
  if not Enum.TooltipDataLineType then return end
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, SampleSubName)
  unitTooltipProcessorRegistered = true
end

Core.RegisterTracker({
  events = {
    "PLAYER_TARGET_CHANGED",
    "UPDATE_MOUSEOVER_UNIT",
  },

  ---@param capture CaptureState
  Init = function(capture)
    ---@type table<string, FunctionStreamEntry[]|table<string|number, FunctionStreamEntry[]>>
    local functions = capture.session.functions
    if not functions["UnitLevel"] then functions["UnitLevel"] = {} end
    if not functions["UnitClassification"] then functions["UnitClassification"] = {} end
    if not functions["UnitReaction"] then functions["UnitReaction"] = {} end
    if not functions["UnitReaction"]["player"] then functions["UnitReaction"]["player"] = {} end
    if not functions["UnitSubName"] then functions["UnitSubName"] = {} end
    functions["UnitSubName"]["mouseover"] = {}
    subNameStream = functions["UnitSubName"]["mouseover"]

    levelStreams = {}
    classificationStreams = {}
    reactionStreams = {}
    for _, token in ipairs(TOKENS) do
      functions["UnitLevel"][token] = {}
      functions["UnitClassification"][token] = {}
      functions["UnitReaction"]["player"][token] = {}
      levelStreams[token] = functions["UnitLevel"][token]
      classificationStreams[token] = functions["UnitClassification"][token]
      reactionStreams[token] = functions["UnitReaction"]["player"][token]
    end

    currentCapture = capture
    RegisterUnitTooltipProcessor()

    -- Initial sample at t=0
    SampleAll(0, 0)
  end,

  ---@param _ CaptureState
  OnCaptureStopped = function(_)
    currentCapture = nil
  end,

  ---@param capture CaptureState
  ---@param _event string
  OnEvent = function(capture, _event)
    ---@type number
    local t  = GetTime() - capture.startedAt
    ---@type number
    local tp = GetTimePreciseSec() - capture.startedAtPrecise
    SampleAll(t, tp)
  end,
})
