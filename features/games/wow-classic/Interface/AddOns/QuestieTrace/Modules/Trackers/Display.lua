---@type QuestieTraceCore
local Core = QuestieTraceCore
---@type fun(...): PackedArgs
local PackArgs = Core.PackArgs
---@type fun(t1: any, t2: any, ignore_mt: boolean?, visited: table?): boolean
local DeepCompare = Core.DeepCompare

---------------------------------------------------------------------------
-- WoW API return schemas (for trace analyzer display labels)
---------------------------------------------------------------------------
-- GetPhysicalScreenSize() -> number width, number height  -- pixels, packed
-- UIParent:GetScale()     -> number scale                 -- key "UIParent:GetScale"
-- GetScreenWidth()        -> number width                 -- UIParent units
-- GetScreenHeight()       -> number height                -- UIParent units
-- GetCVar(name)           -> string? value                -- functions["GetCVar"][lowercase name],
--                                                            RECORDED_CVARS only
--
-- Sampled at capture start and on PLAYER_ENTERING_WORLD, UI_SCALE_CHANGED,
-- DISPLAY_SIZE_CHANGED and CVAR_UPDATE. Every stream is change-only.
---------------------------------------------------------------------------

---Privacy: the only CVars whose values are recorded. Some CVars hold account,
---realm or character identifiers, so this is an allowlist of display and
---quest UI settings. A CVar a client lacks records nil.
---@type string[]
local RECORDED_CVARS = {
  "useUiScale",
  "uiScale",
  "questPOI",
  "autoQuestWatch",
  "autoQuestProgress",
  "miniWorldMap",
  "mapFade",
  "rotateMinimap",
  "minimapZoom",
  "minimapInsideZoom", -- Questie compares it with minimapZoom for minimap icon tooltips
  "instantQuestText",  -- Questie's options read it
  "displayQuestID",    -- Questie reads it with GetCVarBool; nil on Forever 1.60.1
  "closedInfoFrames",  -- bitfield string of the first-time help tips the player closed
}

---@type table<string, FunctionStream>
local functions
---@type CaptureState?
local captureRef

---Append an observed value to a stream if it differs from the stream's last entry.
---@param stream FunctionStreamEntry[]
---@param t number
---@param tp number
---@param value any
local function AppendIfChanged(stream, t, tp, value)
  local previous = stream[#stream]
  if not previous or not DeepCompare(value, previous.v) then
    stream[#stream + 1] = { t = t, tp = tp, v = value }
  end
end

---Get or create a parameterless stream. Screen streams are created on their
---first successful call, so an API the client lacks leaves no stream behind.
---@param key string
---@return FunctionStreamEntry[]
local function FlatStream(key)
  local stream = functions[key] or {}
  functions[key] = stream
  ---@cast stream FunctionStreamEntry[]
  return stream
end

---Sample the screen geometry and the recorded UI CVars.
---@param capture CaptureState
local function SampleDisplay(capture)
  local t = GetTime() - capture.startedAt
  local tp = GetTimePreciseSec() - capture.startedAtPrecise

  -- Screen geometry
  if type(GetPhysicalScreenSize) == "function" then
    local packed = PackArgs(pcall(GetPhysicalScreenSize))
    if packed[1] then
      AppendIfChanged(FlatStream("GetPhysicalScreenSize"), t, tp, PackArgs(unpack(packed, 2, packed.n)))
    end
  end
  if UIParent then
    local ok, scale = pcall(UIParent.GetScale, UIParent)
    if ok then AppendIfChanged(FlatStream("UIParent:GetScale"), t, tp, scale) end
  end
  for _, key in ipairs({ "GetScreenWidth", "GetScreenHeight" }) do
    local fn = _G[key]
    if type(fn) == "function" then
      local ok, value = pcall(fn)
      if ok then AppendIfChanged(FlatStream(key), t, tp, value) end
    end
  end

  -- UI settings. CVar names are case-insensitive (Questie's libraries ask for
  -- both "uiScale" and "uiscale"), so streams are keyed by the lowercase name.
  if type(GetCVar) == "function" then
    local cvarStreams = functions["GetCVar"] or {}
    functions["GetCVar"] = cvarStreams
    ---@cast cvarStreams table<string, FunctionStreamEntry[]>
    for _, name in ipairs(RECORDED_CVARS) do
      local ok, value = pcall(GetCVar, name)
      if ok then
        local key = name:lower()
        local stream = cvarStreams[key] or {}
        cvarStreams[key] = stream
        AppendIfChanged(stream, t, tp, value)
      end
    end
  end
end

---------------------------------------------------------------------------
-- Private CVar frame
-- CVAR_UPDATE fires for every CVar, and its first argument is the CVar name or
-- an event name passed to SetCVar (e.g. "QUEST_POI" for questPOI). Any update
-- re-reads the allowlisted CVars; the event itself is never recorded, so the
-- names and values of other CVars stay out of the trace.
---------------------------------------------------------------------------

---@type Frame
local cvarFrame = CreateFrame("Frame")
cvarFrame:RegisterEvent("CVAR_UPDATE")
cvarFrame:SetScript("OnEvent", function()
  if not captureRef or not captureRef.active then return end
  SampleDisplay(captureRef)
end)

Core.RegisterTracker({
  events = {
    "PLAYER_ENTERING_WORLD",
    "UI_SCALE_CHANGED",
    "DISPLAY_SIZE_CHANGED",
  },

  ---@param capture CaptureState
  Init = function(capture)
    functions = capture.session.functions
    captureRef = capture
    SampleDisplay(capture)
  end,

  ---@param capture CaptureState
  OnEvent = function(capture)
    SampleDisplay(capture)
  end,
})
