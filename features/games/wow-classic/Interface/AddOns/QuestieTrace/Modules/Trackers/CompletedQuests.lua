---@type QuestieTraceCore
local Core = QuestieTraceCore

---------------------------------------------------------------------------
-- WoW API return schemas (for trace analyzer display labels)
---------------------------------------------------------------------------
-- C_QuestLog.GetAllCompletedQuestIDs() -> number[] questIDs (raw array)
-- GetQuestsCompleted(table?) -> table questsCompleted  -- keyed by questID -> true
--                                (legacy global)
--
-- Each API is tracked as its own independent DeltaStream (initial set +
-- add/remove deltas over time), only when that real API actually exists.
-- There is no merged/normalized "whichever API is available" value: a
-- client exposing both would get both streams recorded independently.
---------------------------------------------------------------------------

---@type table<string, DeltaStream>
local functionsDelta  -- capture.session.functionsDelta
---@type table<number, boolean>
local currentModernSet -- [questId] = true -- last C_QuestLog.GetAllCompletedQuestIDs set
---@type table<number, boolean>
local currentLegacySet -- [questId] = true -- last legacy GetQuestsCompleted set
---@type number
local currentModernCount
---@type number
local currentLegacyCount
---@type boolean
local fullCompareActive = false -- compare full sets, even when counts match, until the current follow-up chain ends
---@type table<number, boolean>
local legacyCompletedScratch = {}

---------------------------------------------------------------------------
-- API helpers
---------------------------------------------------------------------------

--- Get completed quest IDs from C_QuestLog.GetAllCompletedQuestIDs, unsorted.
---@return number[]? ids Array of completed quest IDs, or nil if the API doesn't exist
local function GetModernCompletedQuestIds()
  if not (C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs) then return nil end

  ---@type number[]
  local ids = {}
  for _, questID in ipairs(C_QuestLog.GetAllCompletedQuestIDs()) do
    ids[#ids + 1] = questID
  end
  return ids
end

--- Get completed quest IDs from the legacy GetQuestsCompleted global, unsorted.
---@return number[]? ids Array of completed quest IDs, or nil if the API doesn't exist
local function GetLegacyCompletedQuestIds()
  if not GetQuestsCompleted then return nil end

  wipe(legacyCompletedScratch)
  ---@type table<number, boolean>?
  local completed = GetQuestsCompleted(legacyCompletedScratch)

  ---@type number[]
  local ids = {}
  if type(completed) == "table" then
    for questId, isCompleted in pairs(completed) do
      if isCompleted == true then
        ids[#ids + 1] = questId
      end
    end
  end
  return ids
end

---------------------------------------------------------------------------
-- Sampling
---------------------------------------------------------------------------

--- Compute add/remove deltas for one completed-quest source against its
--- previous set, and append a delta entry to its own independent stream.
---@param streamKey string
---@param currentSet table<number, boolean>
---@param currentCount number Number of IDs in currentSet
---@param ids number[]? Completed quest IDs from this source, or nil if unavailable
---@param t number
---@param tp number
---@return table<number, boolean> newSet
---@return number newCount
---@return boolean recordedChange
local function SampleCompletedSource(streamKey, currentSet, currentCount, ids, t, tp)
  -- Completed quests are only ever added (or all removed on a reset), so an
  -- unchanged count means an unchanged set; skip rebuilding thousands of IDs.
  if ids == nil then
    return currentSet, currentCount, false
  end
  if #ids == currentCount and (not fullCompareActive) then
    return currentSet, currentCount, false
  end

  ---@type table<number, boolean>
  local newSet = {}
  for i = 1, #ids do newSet[ids[i]] = true end

  ---@type number[], number[]
  local added, removed = {}, {}
  for questId in pairs(newSet) do
    if not currentSet[questId] then
      added[#added + 1] = questId
    end
  end
  for questId in pairs(currentSet) do
    if not newSet[questId] then
      removed[#removed + 1] = questId
    end
  end

  local recordedChange = #added > 0 or #removed > 0
  if recordedChange then
    table.sort(added)
    table.sort(removed)

    ---@type DeltaStreamEntry
    local delta = { t = t, tp = tp }
    if #added > 0 then delta.add = added end
    if #removed > 0 then delta.remove = removed end

    ---@type DeltaStream
    local stream = functionsDelta[streamKey]
    stream.delta[#stream.delta + 1] = delta
  end

  return newSet, #ids, recordedChange
end

--- Sample completed quests from every available source and record delta
--- changes independently for each.
---@param capture CaptureState
---@param chainEnded boolean? True for the last sample of a follow-up chain
---@return boolean recordedChange
local function SampleCompleted(capture, chainEnded)
  ---@type number
  local t  = GetTime() - capture.startedAt
  ---@type number
  local tp = GetTimePreciseSec() - capture.startedAtPrecise

  local modernChanged, legacyChanged
  currentModernSet, currentModernCount, modernChanged = SampleCompletedSource(
    "C_QuestLog.GetAllCompletedQuestIDs", currentModernSet, currentModernCount, GetModernCompletedQuestIds(), t, tp
  )
  currentLegacySet, currentLegacyCount, legacyChanged = SampleCompletedSource(
    "GetQuestsCompleted", currentLegacySet, currentLegacyCount, GetLegacyCompletedQuestIds(), t, tp
  )
  if chainEnded then
    fullCompareActive = false
  end
  return modernChanged or legacyChanged
end

local RequestSample, FollowUp = Core.CreateSampleScheduler(SampleCompleted)

---------------------------------------------------------------------------
-- Tracker registration
---------------------------------------------------------------------------

Core.RegisterTracker({
  events = {
    "QUEST_LOG_UPDATE",
    "QUEST_REMOVED",
    "QUEST_TURNED_IN",
    "PLAYER_ENTERING_WORLD",
  },

  ---@param capture CaptureState
  Init = function(capture)
    functionsDelta = capture.session.functionsDelta
    currentModernSet = {}
    currentLegacySet = {}
    currentModernCount = 0
    currentLegacyCount = 0
    fullCompareActive = false

    local modernIds = GetModernCompletedQuestIds()
    if modernIds then
      table.sort(modernIds)
      currentModernCount = #modernIds
      functionsDelta["C_QuestLog.GetAllCompletedQuestIDs"] = { t = 0, tp = 0, initial = modernIds, delta = {} }
      for i = 1, #modernIds do currentModernSet[modernIds[i]] = true end
    end

    local legacyIds = GetLegacyCompletedQuestIds()
    if legacyIds then
      table.sort(legacyIds)
      currentLegacyCount = #legacyIds
      functionsDelta["GetQuestsCompleted"] = { t = 0, tp = 0, initial = legacyIds, delta = {} }
      for i = 1, #legacyIds do currentLegacySet[legacyIds[i]] = true end
    end

    -- Follow up on the start snapshot in case the completed list is still loading
    FollowUp(capture)
  end,

  ---@param capture CaptureState
  ---@param event string
  OnEvent = function(capture, event)
    -- Every event restarts the follow-up chain, so an open full comparison
    -- carries over to the restarted chain and only ends with its last sample.
    if event == "QUEST_TURNED_IN" or event == "PLAYER_ENTERING_WORLD" then
      fullCompareActive = true
    end
    RequestSample(capture)
  end,
})
