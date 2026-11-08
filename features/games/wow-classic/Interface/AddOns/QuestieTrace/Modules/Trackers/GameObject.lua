---@type QuestieTraceCore
local Core = QuestieTraceCore

---------------------------------------------------------------------------
-- WoW API return schemas (for trace analyzer display labels)
---------------------------------------------------------------------------
-- Forever/Midnight (10.0+):
--   TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, func)
--     func(tooltip, data)
--       data: TooltipData
--         type: Enum.TooltipDataType (4 = Object)
--         guid: WOWGUID
--         lines: TooltipDataLine[]
--           TooltipDataLine:
--             type: Enum.TooltipDataLineType (2 = UnitName)
--             leftText: string
--             rightText: string

---@type CaptureState?
local currentCapture
---@type FunctionStreamEntry[]?
local modernNameStream
---@type boolean
local modernTooltipProcessorRegistered = false

---Safely get a string value from a possibly-secret (tainted) value.
---Returns empty string if the value is nil, not a string, or a secret value.
---@param value any
---@return string
local function SafeString(value)
  if type(value) ~= "string" then return "" end
  if issecretvalue and issecretvalue(value) then return "" end
  return value
end

---Extract object name from Modern TooltipDataProcessor tooltip data.
---@param tooltipData TooltipData?
---@return string? name
local function ExtractModernGameObject(tooltipData)
  if not tooltipData or not tooltipData.lines then return nil end
  local lines = tooltipData.lines

  -- The UnitName line type (2) holds the object's name. If it's missing or
  -- unreadable (secret/empty), leave the name unset rather than guessing
  -- from another line (e.g. a requirement/description line).
  for i = 1, #lines do
    local line = lines[i]
    if line and line.type == Enum.TooltipDataLineType.UnitName then
      local text = SafeString(line.leftText)
      if text ~= "" then
        return text
      end
      return nil
    end
  end

  return nil
end

---Sample Modern TooltipDataProcessor for game object info.
---@param _ any tooltip (unused)
---@param tooltipData TooltipData?
local function SampleModern(_, tooltipData)
  if not currentCapture then return end
  local t = GetTime() - currentCapture.startedAt
  local tp = GetTimePreciseSec() - currentCapture.startedAtPrecise

  local name = ExtractModernGameObject(tooltipData)
  if not name then return end

  if modernNameStream then
    local prev = modernNameStream[#modernNameStream]
    if not prev or prev.v ~= name then
      modernNameStream[#modernNameStream + 1] = { t = t, tp = tp, v = name }
    end
  end
end

---Register TooltipDataProcessor for Modern/Forever game object detection.
local function RegisterTooltipDataProcessor()
  if modernTooltipProcessorRegistered then return end
  if not TooltipDataProcessor or not TooltipDataProcessor.AddTooltipPostCall then return end
  if not Enum or not Enum.TooltipDataType or not Enum.TooltipDataType.Object then return end
  if not Enum.TooltipDataLineType then return end

  -- Register post-call for Object tooltip type (4)
  -- This fires after the tooltip data is prepared for game objects
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, SampleModern)
  modernTooltipProcessorRegistered = true
end

Core.RegisterTracker({
  events = {}, -- No events needed; Modern uses TooltipDataProcessor

  ---@param capture CaptureState
  Init = function(capture)
    currentCapture = capture
    local functions = capture.session.functions

    -- Modern/Forever streams
    if not functions["GameObjectName"] then functions["GameObjectName"] = {} end

    modernNameStream = functions["GameObjectName"]

    -- Register TooltipDataProcessor for Modern/Forever
    RegisterTooltipDataProcessor()
  end,

  ---@param _ CaptureState
  OnCaptureStopped = function(_)
    currentCapture = nil
  end,
})
