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
--             type: Enum.TooltipDataLineType (2 = UnitName; Forever sends the name as 0 = Default)
--             leftText: string
--             rightText: string

---@type CaptureState?
local currentCapture
---@type FunctionStreamEntry[]?
local modernNameStream
---@type FunctionStreamEntry[]?
local modernGUIDStream
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
---The name is the UnitName line when there is one; Forever tags it as a default line
---(type 0) instead, and the name is then the first line, as on every tooltip.
---@param tooltipData TooltipData?
---@return string? name
local function ExtractModernGameObject(tooltipData)
  if (not tooltipData) or (not tooltipData.lines) then
    return nil
  end
  -- Privacy: only world object tooltips. Players and pets are units, never objects.
  if tooltipData.type ~= Enum.TooltipDataType.Object then
    return nil
  end
  if tooltipData.guid ~= nil and Core.ParseGUIDKind(tooltipData.guid) ~= "object" then
    return nil
  end
  local lines = tooltipData.lines

  -- An unreadable (secret/empty) name leaves the name unset rather than guessing
  -- from another line (e.g. a requirement/description line).
  local nameLine = lines[1]
  for i = 1, #lines do
    local line = lines[i]
    if line and line.type == Enum.TooltipDataLineType.UnitName then
      nameLine = line
      break
    end
  end
  if (not nameLine) then
    return nil
  end
  local text = SafeString(nameLine.leftText)
  if text == "" then
    return nil
  end
  -- Player-made objects can carry their owner's name, e.g. "<name>'s Portal".
  return Core.SanitizeText(text)
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

  if (not modernNameStream) or (not modernGUIDStream) then return end

  -- Forever sends object tooltips without a GUID, so a name cannot be tied to an object there yet.
  -- The GUID is still recorded whenever a client provides one, should that change; "" marks a tooltip
  -- without a readable object GUID. Both streams are written together so each name has its GUID at the same t.
  local guid = Core.ParseGUIDKind(tooltipData.guid) == "object" and tooltipData.guid or ""
  local prevName = modernNameStream[#modernNameStream]
  local prevGUID = modernGUIDStream[#modernGUIDStream]
  if prevName and prevName.v == name and prevGUID and prevGUID.v == guid then return end
  modernNameStream[#modernNameStream + 1] = { t = t, tp = tp, v = name }
  modernGUIDStream[#modernGUIDStream + 1] = { t = t, tp = tp, v = guid }
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
    if not functions["GameObjectGUID"] then functions["GameObjectGUID"] = {} end

    modernNameStream = functions["GameObjectName"]
    modernGUIDStream = functions["GameObjectGUID"]

    -- Register TooltipDataProcessor for Modern/Forever
    RegisterTooltipDataProcessor()
  end,

  ---@param _ CaptureState
  OnCaptureStopped = function(_)
    currentCapture = nil
  end,
})
