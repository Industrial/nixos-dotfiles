---@type QuestieTraceCore
local Core = QuestieTraceCore

---------------------------------------------------------------------------
-- Frame heartbeat: session.frameUpdates
---------------------------------------------------------------------------
-- When the client runs addon frame updates (OnUpdate), as FunctionStreamEntry[]
-- with v = seconds since the previous frame update (since capture start for
-- the first). Records the first FIRST_FRAMES updates after capture start, then
-- only updates that end a gap over GAP_THRESHOLD seconds.
--
-- Together with LOADING_SCREEN_ENABLED/DISABLED, this shows whether addon code
-- runs during loading screens. A gap entry covers [tp - v, tp], so a loading
-- screen longer than GAP_THRESHOLD that ran no frame updates lies inside one,
-- and one that did leaves none. The login loading screen starts before capture
-- start (PLAYER_LOGIN); the first frame updates show whether it runs them.
---------------------------------------------------------------------------

---@type number
local FIRST_FRAMES = 10
---@type number Seconds without a frame update that count as a gap.
local GAP_THRESHOLD = 1

---@type CaptureState?
local captureRef
---@type FunctionStreamEntry[]?
local frameUpdates
---@type number Session-relative GetTimePreciseSec() of the previous frame update.
local lastTp = 0
---@type number
local firstFramesLeft = 0

-- Shown only while capturing, so the per-frame call costs nothing otherwise.
---@type Frame
local heartbeatFrame = CreateFrame("Frame")
heartbeatFrame:Hide()
heartbeatFrame:SetScript("OnUpdate", function()
  local capture = captureRef
  if not capture or not capture.active or not frameUpdates then return end

  local tp = GetTimePreciseSec() - capture.startedAtPrecise
  local sinceLast = tp - lastTp
  lastTp = tp

  local isFirstFrame = firstFramesLeft > 0
  if isFirstFrame then
    firstFramesLeft = firstFramesLeft - 1
  end
  if isFirstFrame or sinceLast > GAP_THRESHOLD then
    frameUpdates[#frameUpdates + 1] = { t = GetTime() - capture.startedAt, tp = tp, v = sinceLast }
  end
end)

Core.RegisterTracker({
  ---@param capture CaptureState
  Init = function(capture)
    frameUpdates = {}
    capture.session.frameUpdates = frameUpdates
    captureRef = capture
    lastTp = 0
    firstFramesLeft = FIRST_FRAMES
    heartbeatFrame:Show()
  end,

  OnCaptureStopped = function()
    heartbeatFrame:Hide()
    captureRef = nil
  end,
})
