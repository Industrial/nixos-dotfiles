QuestieTraceCore = QuestieTraceCore or {}

---@class QuestieTraceCore
local Core = QuestieTraceCore

---------------------------------------------------------------------------
-- Public API for other addons, exposed as the global `QuestieTraceAPI.v1`.
-- Nothing in here can grant consent or start a capture without it.
---------------------------------------------------------------------------

---@class QuestieTraceAPIv1
local v1 = {}

--- Returns the data collection consent state.
---@return "granted"|"declined"|"unset"
function v1.GetConsentState()
  local settings = QuestieTrace and QuestieTrace.settings
  local consent = settings and settings.dataCollectionConsent
  if consent == true then
    return "granted"
  elseif consent == false then
    return "declined"
  end
  return "unset"
end

---@return boolean
function v1.IsCaptureRunning()
  return Core.GetCaptureState() == "running"
end

--- Asks the user for consent. Accepting the prompt starts a capture.
function v1.ShowConsentPrompt()
  Core.ShowConsentPrompt()
end

--- Starts a new capture. Does nothing unless consent was explicitly granted.
--- Returns false until QuestieTrace initialized on PLAYER_LOGIN; it then starts automatically if consent is granted.
---@return boolean isRunning Whether a capture is running afterwards.
function v1.StartCapture()
  if (not Core.IsReady()) or v1.GetConsentState() ~= "granted" then
    return false
  end
  if (not v1.IsCaptureRunning()) then
    -- Preserve a stopped session before starting the next one.
    Core.SaveCapture()
    Core.StartCapture()
  end
  return v1.IsCaptureRunning()
end

function v1.StopCapture()
  Core.StopCapture()
end

function v1.ShowExportWindow()
  Core.ShowExportWindow()
end

QuestieTraceAPI = { v1 = v1 }
