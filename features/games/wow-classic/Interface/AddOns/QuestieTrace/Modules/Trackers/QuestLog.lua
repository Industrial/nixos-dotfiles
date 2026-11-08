---@type QuestieTraceCore
local Core = QuestieTraceCore
---@type fun(...): PackedArgs
local PackArgs = Core.PackArgs
---@type fun(t1: any, t2: any, ignore_mt: boolean?, visited: table?): boolean
local DeepCompare = Core.DeepCompare

local C_After = C_Timer.After

---------------------------------------------------------------------------
-- WoW API return schemas (for trace analyzer display labels)
---------------------------------------------------------------------------
-- Quest-log title/tag/completion data is split across several independent
-- raw APIs. Each is probed and recorded only when it actually exists on the
-- current client -- there is no synthesized/normalized composite value.
--
-- C_QuestLog.GetInfo(questLogIndex)      -> table info (raw, as returned by the API)
-- C_QuestLog.GetQuestTagInfo(questID)    -> table? tagInfo (raw)
-- C_QuestLog.IsComplete(questID)         -> boolean isComplete
-- C_QuestLog.IsFailed(questID)           -> boolean isFailed
-- C_QuestLog.GetLogIndexForQuestID(questID) -> number? questLogIndex
--
-- GetQuestLogTitle(questLogIndex)   -> packed 17-value tuple (legacy global,
--                                      only recorded when that global exists)
-- GetQuestLogIndexByID(questID)     -> number questLogIndex (legacy global)
--
-- GetQuestLogQuestText(questLogIndex) -> string questDescription,
--                                        string questObjectives
--
-- GetQuestTagInfo(questID) -> number? tagID,
--                             string? tagName,
--                             number? worldQuestType,
--                             number  rarity,
--                             boolean isElite,
--                             number  tradeskillLineIndex,
--                             unknown displayTimeLeft
--
-- IsQuestComplete(questID)                    -> boolean isComplete
-- HaveQuestData(questID)                       -> boolean hasData
-- C_QuestLog.IsOnQuest(questID)                -> boolean isOnQuest
-- C_QuestLog.GetMaxNumQuestsCanAccept()        -> number maxNumQuestsCanAccept
-- C_QuestLog.IsQuestFlaggedCompleted(questID)  -> boolean isCompleted
-- C_QuestLog.GetQuestObjectives(questID)       -> QuestObjectiveInfo[] objectives
-- GetQuestLogQuestText(questLogIndex)          -> packed quest text tuple keyed by questID
-- GetQuestTimers[questID]                      -> number secondsLeft (derived from GetQuestTimers())
-- GetQuestLogTimeLeft[questID]                 -> number secondsLeft (same derived compatibility value)
-- GetQuestIndexForTimer(timerIndex)            -> number? questLogIndex (raw, keyed by timer slot)
-- GetNumQuestLogRewards(questID)               -> number numRewards
-- GetQuestLogRewardInfo(index, questID)        -> packed reward item tuple
-- GetQuestLogRewardMoney(questID)              -> number money
-- C_QuestLog.GetRequiredMoney(questID)         -> number copper (-1 observed on Forever when none)
-- C_QuestLog.GetQuestTimers()                  -> QuestTimerInfo[] (flat stream; empty table when none)
--
-- Sampled with the native quest-log index but stored by questID, like
-- GetQuestLogQuestText:
-- GetQuestLogCompletionText(questLogIndex)     -> string? completionText (sanitized)
-- GetQuestLogSpecialItemInfo(questLogIndex)    -> packed itemLink, icon, charges, showItemWhenComplete
--                                                 (n = 0 when the quest has no special item)
--
-- QuestLog (custom stream) -> number[] questIDs  -- array of active quest IDs
-- QuestLogZone[questId] -> string? headerTitle -- derived: the quest-log
--                                                 header title immediately
--                                                 preceding this quest
---------------------------------------------------------------------------

---@type number[]
local SAMPLE_DELAYS = { 0, 0.10, 0.35, 0.55, 0.75, 1.00 }

---@type boolean
local recordedChange = false -- set whenever any stream gets a new entry

---@type table<string, FunctionStream>
local functions   -- capture.session.functions
---@type number[]?
local prevQuestLog  -- last QuestLog value (array of quest IDs)
---@type table<string, any>
local prevFlat      -- [funcName] -> last value for flat stream change detection
---@type table<number, table<string, any>>
local prevQuest     -- [questId][funcName] -> last value for change detection
---@type table<string, table<string|number, table<string|number, any>>>
local prevNested    -- Mirrors nested stream parameters for change detection only.
---@type table<number, boolean>
local prevTimedQuestIds -- Timed quest IDs from the previous derived timer sample.
---@type table<number, number>
local prevRewardCounts -- Highest reward index previously captured for each active quest.

---@type table<string, FunctionStreamEntry[]>?
local questAcceptLevelStream -- functions["QuestAcceptLevel"] shortcut

---------------------------------------------------------------------------
-- API helpers (logic preserved from existing implementation)
---------------------------------------------------------------------------

--- Read the questID/isHeader/title of a quest-log row for internal iteration
--- only. This is not a recorded trace value: it exists purely to drive
--- enumeration (which log indices hold quests vs. headers, and which header
--- precedes each quest). The actual raw API results are recorded separately
--- and independently by ProbeQuestLogIndexAndTitle.
---@param questLogIndex number
---@return { questID: number?, isHeader: boolean?, title: string? }? row
local function ReadQuestLogRow(questLogIndex)
  if C_QuestLog and C_QuestLog.GetInfo then
    local info = C_QuestLog.GetInfo(questLogIndex)
    if not info then return nil end
    return { questID = info.questID, isHeader = info.isHeader, title = info.title }
  elseif GetQuestLogTitle then
    local title, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(questLogIndex)
    if not title then return nil end
    return { questID = questID, isHeader = isHeader, title = title }
  end
  return nil
end

--- Get a quest ID at a quest log index.
---@param questLogIndex number
---@return number? questId
local function GetQuestIdAtLogIndex(questLogIndex)
  local row = ReadQuestLogRow(questLogIndex)
  if not row then return nil end
  if row.questID and row.questID > 0 then return row.questID end
  return nil
end

--- Get all quest IDs currently in the quest log, along with the header/zone
--- title that immediately precedes each quest.
---@return number[] questIds Array of quest IDs
---@return table<number, string?> questZones [questId] -> preceding header title
local function GetAllQuestIdsInLog()
  ---@type number[]
  local questIds = {}
  ---@type table<number, string?>
  local questZones = {}
  ---@type string?
  local currentHeaderTitle = nil

  for questLogIndex = 1, 80 do -- Forever allows 40 quests (+40 individual zones)
    local row = ReadQuestLogRow(questLogIndex)
    if not row then
      return questIds, questZones
    end

    if row.isHeader then
      currentHeaderTitle = row.title
    elseif row.questID and row.questID > 0 then
      questIds[#questIds + 1] = row.questID
      questZones[row.questID] = currentHeaderTitle
    end
  end
  return questIds, questZones
end

---------------------------------------------------------------------------
-- Streaming helpers
---------------------------------------------------------------------------

--- Get or create a flat function stream for a given function name.
---@param funcName string
---@return FunctionStreamEntry[]
local function GetOrCreateFlatStream(funcName)
  if not functions[funcName] then
    functions[funcName] = {}
  end
  local stream = functions[funcName]
  ---@cast stream FunctionStreamEntry[]
  return stream
end

--- Get or create a parameterized function stream for a given function name and key.
---@param funcName string
---@param key string|number
---@return FunctionStreamEntry[]
local function GetOrCreateParamStream(funcName, key)
  if not functions[funcName] then
    functions[funcName] = {}
  end
  local streams = functions[funcName]
  ---@cast streams table<string|number, FunctionStreamEntry[]>
  if not streams[key] then
    streams[key] = {}
  end
  return streams[key]
end

---Get or create a two-parameter stream in native API argument order.
---This is the canonical shape for true multi-argument APIs. It avoids composite
---string keys and lets consumers walk `functions[name][arg1][arg2]` generically.
---@param funcName string
---@param key1 string|number First native argument
---@param key2 string|number Second native argument
---@return FunctionStreamEntry[]
local function GetOrCreateNestedParamStream(funcName, key1, key2)
  if not functions[funcName] then
    functions[funcName] = {}
  end

  local firstLevel = functions[funcName]
  ---@cast firstLevel table<string|number, table<string|number, FunctionStreamEntry[]>>
  if not firstLevel[key1] then
    firstLevel[key1] = {}
  end
  if not firstLevel[key1][key2] then
    firstLevel[key1][key2] = {}
  end
  return firstLevel[key1][key2]
end

--- Append a value to a flat stream if it has changed from the previously recorded value.
---@param stream FunctionStreamEntry[]
---@param t number Relative time from GetTime()
---@param tp number Relative time from GetTimePreciseSec()
---@param v any The new value to compare and potentially append
---@param funcName string The function name for change tracking
local function AppendFlatIfChanged(stream, t, tp, v, funcName)
  local prev = prevFlat[funcName]
  ---@type boolean
  local changed

  if prev == nil and v == nil then
    changed = #stream == 0
  elseif prev == nil or v == nil then
    changed = true
  elseif type(v) == "table" then
    changed = not DeepCompare(v, prev)
  else
    changed = v ~= prev
  end

  if changed then
    stream[#stream + 1] = { t = t, tp = tp, v = v }
    recordedChange = true
    prevFlat[funcName] = v
  end
end

--- Append a value to the stream if it has changed from the previously recorded value.
---@param stream FunctionStreamEntry[]
---@param t number Relative time from GetTime()
---@param tp number Relative time from GetTimePreciseSec()
---@param v any The new value to compare and potentially append
---@param questId number The quest ID for change tracking
---@param funcName string The function name for change tracking
local function AppendIfChanged(stream, t, tp, v, questId, funcName)
  ---@type any
  local prev = prevQuest[questId] and prevQuest[questId][funcName]
  ---@type boolean
  local changed

  if prev == nil and v == nil then
    -- Both nil — only changed if this is the first entry for this quest+func
    changed = #stream == 0
  elseif prev == nil or v == nil then
    changed = true
  elseif type(v) == "table" then
    changed = not DeepCompare(v, prev)
  else
    changed = v ~= prev
  end

  if changed then
    stream[#stream + 1] = { t = t, tp = tp, v = v }
    recordedChange = true
    if not prevQuest[questId] then prevQuest[questId] = {} end
    prevQuest[questId][funcName] = v
  end
end

--- Append a value to a nested parameterized stream if it changed.
---@param stream FunctionStreamEntry[]
---@param t number Relative time from GetTime()
---@param tp number Relative time from GetTimePreciseSec()
---@param v any The new value to compare and potentially append
---@param funcName string The function name for change tracking
---@param key1 string|number First native argument
---@param key2 string|number Second native argument
local function AppendNestedIfChanged(stream, t, tp, v, funcName, key1, key2)
  if not prevNested[funcName] then prevNested[funcName] = {} end
  if not prevNested[funcName][key1] then prevNested[funcName][key1] = {} end

  local previous = prevNested[funcName][key1][key2]
  ---@type boolean
  local changed

  if previous == nil and v == nil then
    changed = #stream == 0
  elseif previous == nil or v == nil then
    changed = true
  elseif type(v) == "table" then
    changed = not DeepCompare(v, previous)
  else
    changed = v ~= previous
  end

  if changed then
    stream[#stream + 1] = { t = t, tp = tp, v = v }
    recordedChange = true
    prevNested[funcName][key1][key2] = v
  end
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

--- Recursively sanitize string values in a table using Core.SanitizeText.
---@param tbl table
---@return table sanitized
local function SanitizeTable(tbl)
  if type(tbl) ~= "table" then return tbl end
  for k, v in pairs(tbl) do
    if type(v) == "string" then
      tbl[k] = Core.SanitizeText(v)
    elseif type(v) == "table" then
      tbl[k] = SanitizeTable(v)
    end
  end
  return tbl
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

---Probe one scalar, questId-keyed raw API and append the exact returned value.
---@param funcName string
---@param fn function?
---@param t number
---@param tp number
---@param questId number
local function ProbeQuestScalar(funcName, fn, t, tp, questId)
  local ok, value = SafeScalarCall(fn, questId)
  if ok then
    AppendIfChanged(
      GetOrCreateParamStream(funcName, questId),
      t, tp, value, questId, funcName
    )
  end
end

---Probe one packed, questId-keyed raw API and append the exact returned tuple.
---@param funcName string
---@param fn function?
---@param t number
---@param tp number
---@param questId number
local function ProbeQuestPacked(funcName, fn, t, tp, questId)
  local ok, value = SafePackedCall(fn, questId)
  if ok then
    AppendIfChanged(
      GetOrCreateParamStream(funcName, questId),
      t, tp, value, questId, funcName
    )
  end
end

---Probe reward APIs for a quest ID, including previously observed reward indices.
---These are raw API streams: every stored value comes from a successful API call.
---If a stale index errors after reward count shrinks or after quest removal, the
---trace records no invented value for that failed call.
---@param t number
---@param tp number
---@param questId number
local function ProbeQuestRewards(t, tp, questId)
  local previousRewardCount = prevRewardCounts[questId] or 0
  local currentRewardCount = 0

  local rewardsOk, rewardCount = SafeScalarCall(GetNumQuestLogRewards, questId)
  if rewardsOk then
    AppendIfChanged(
      GetOrCreateParamStream("GetNumQuestLogRewards", questId),
      t, tp, rewardCount, questId, "GetNumQuestLogRewards"
    )
    if type(rewardCount) == "number" then
      currentRewardCount = math.max(0, math.floor(rewardCount))
      if currentRewardCount > previousRewardCount then
        prevRewardCounts[questId] = currentRewardCount
        previousRewardCount = currentRewardCount
      end
    end
  end

  local moneyOk, rewardMoney = SafeScalarCall(GetQuestLogRewardMoney, questId)
  if moneyOk then
    AppendIfChanged(
      GetOrCreateParamStream("GetQuestLogRewardMoney", questId),
      t, tp, rewardMoney, questId, "GetQuestLogRewardMoney"
    )
  end

  local maxRewardIndex = math.max(previousRewardCount, currentRewardCount)
  for rewardIndex = 1, maxRewardIndex do
    local rewardOk, rewardInfo = SafePackedCall(GetQuestLogRewardInfo, rewardIndex, questId)
    if rewardOk then
      AppendNestedIfChanged(
        GetOrCreateNestedParamStream("GetQuestLogRewardInfo", rewardIndex, questId),
        t, tp, rewardInfo, "GetQuestLogRewardInfo", rewardIndex, questId
      )
    end
  end
end

---Probe raw direct questID APIs and append exact observed return values.
---Used both while a quest is active and after it disappears from QuestLog.
---@param t number
---@param tp number
---@param questId number
local function ProbeQuestDirectApis(t, tp, questId)
  ProbeQuestScalar("IsQuestComplete", IsQuestComplete, t, tp, questId)
  ProbeQuestScalar("HaveQuestData", HaveQuestData, t, tp, questId)

  if type(C_QuestLog) == "table" then
    ProbeQuestScalar("C_QuestLog.IsOnQuest", C_QuestLog.IsOnQuest, t, tp, questId)
    ProbeQuestScalar("C_QuestLog.IsQuestFlaggedCompleted", C_QuestLog.IsQuestFlaggedCompleted, t, tp, questId)
    local objOk, objectives = SafeScalarCall(C_QuestLog.GetQuestObjectives, questId)
    if objOk then
      objectives = SanitizeTable(objectives)
      AppendIfChanged(
        GetOrCreateParamStream("C_QuestLog.GetQuestObjectives", questId),
        t, tp, objectives, questId, "C_QuestLog.GetQuestObjectives"
      )
    end
  end

  ProbeQuestPacked("GetQuestTagInfo", GetQuestTagInfo, t, tp, questId)
  ProbeQuestRewards(t, tp, questId)

  if type(C_QuestLog) == "table" then
    ProbeQuestScalar("C_QuestLog.GetRequiredMoney", C_QuestLog.GetRequiredMoney, t, tp, questId)
  end
end

---Probe raw quest-log-index-family APIs for an active quest ID. Each API
---(modern `C_QuestLog.*` and/or legacy globals) is probed and recorded
---independently, only when it actually exists on the current client. There
---is no synthesized composite value -- callers of this data must combine
---whichever raw streams are present themselves.
---@param t number
---@param tp number
---@param questId number
local function ProbeQuestLogIndexAndTitle(t, tp, questId)
  ---@type number?
  local questLogIndex

  if type(C_QuestLog) == "table" and type(C_QuestLog.GetLogIndexForQuestID) == "function" then
    local ok, value = SafeScalarCall(C_QuestLog.GetLogIndexForQuestID, questId)
    if ok then
      AppendIfChanged(
        GetOrCreateParamStream("C_QuestLog.GetLogIndexForQuestID", questId),
        t, tp, value, questId, "C_QuestLog.GetLogIndexForQuestID"
      )
      questLogIndex = value
    end
  end

  if type(GetQuestLogIndexByID) == "function" then
    local ok, value = SafeScalarCall(GetQuestLogIndexByID, questId)
    if ok then
      AppendIfChanged(
        GetOrCreateParamStream("GetQuestLogIndexByID", questId),
        t, tp, value, questId, "GetQuestLogIndexByID"
      )
      questLogIndex = questLogIndex or value
    end
  end

  if not questLogIndex then return end

  if type(C_QuestLog) == "table" then
    if type(C_QuestLog.GetInfo) == "function" then
      local ok, info = SafeScalarCall(C_QuestLog.GetInfo, questLogIndex)
      if ok and info then
        AppendIfChanged(
          GetOrCreateParamStream("C_QuestLog.GetInfo", questId),
          t, tp, info, questId, "C_QuestLog.GetInfo"
        )
      end
    end

    if type(C_QuestLog.GetQuestTagInfo) == "function" then
      local ok, tagInfo = SafeScalarCall(C_QuestLog.GetQuestTagInfo, questId)
      if ok then
        AppendIfChanged(
          GetOrCreateParamStream("C_QuestLog.GetQuestTagInfo", questId),
          t, tp, tagInfo, questId, "C_QuestLog.GetQuestTagInfo"
        )
      end
    end

    if type(C_QuestLog.IsComplete) == "function" then
      local ok, isComplete = SafeScalarCall(C_QuestLog.IsComplete, questId)
      if ok then
        AppendIfChanged(
          GetOrCreateParamStream("C_QuestLog.IsComplete", questId),
          t, tp, isComplete, questId, "C_QuestLog.IsComplete"
        )
      end
    end

    if type(C_QuestLog.IsFailed) == "function" then
      local ok, isFailed = SafeScalarCall(C_QuestLog.IsFailed, questId)
      if ok then
        AppendIfChanged(
          GetOrCreateParamStream("C_QuestLog.IsFailed", questId),
          t, tp, isFailed, questId, "C_QuestLog.IsFailed"
        )
      end
    end
  end

  -- Legacy global -- raw 17-value tuple, only recorded when the global exists.
  if type(GetQuestLogTitle) == "function" then
    local ok, titleTuple = SafePackedCall(GetQuestLogTitle, questLogIndex)
    if ok then
      AppendIfChanged(
        GetOrCreateParamStream("GetQuestLogTitle", questId),
        t, tp, titleTuple, questId, "GetQuestLogTitle"
      )
    end
  end

  -- GetQuestLogQuestText -- tuple (n=2: questDescription, questObjectives)
  local textOk, questTextData = SafePackedCall(GetQuestLogQuestText, questLogIndex)
  if textOk then
    -- Privacy: quest text can embed player names. Sanitize any string values.
    for i = 1, questTextData.n or 0 do
      if type(questTextData[i]) == "string" then
        questTextData[i] = Core.SanitizeText(questTextData[i])
      end
    end
    AppendIfChanged(
      GetOrCreateParamStream("GetQuestLogQuestText", questId),
      t, tp, questTextData, questId, "GetQuestLogQuestText"
    )
  end

  -- GetQuestLogCompletionText -- scalar string; nil until the quest can be turned in
  local completionOk, completionText = SafeScalarCall(GetQuestLogCompletionText, questLogIndex)
  if completionOk then
    -- Privacy: completion text can embed player names.
    AppendIfChanged(
      GetOrCreateParamStream("GetQuestLogCompletionText", questId),
      t, tp, Core.SanitizeText(completionText), questId, "GetQuestLogCompletionText"
    )
  end

  -- GetQuestLogSpecialItemInfo -- packed tuple, empty when the quest has no usable item
  local specialOk, specialItem = SafePackedCall(GetQuestLogSpecialItemInfo, questLogIndex)
  if specialOk then
    AppendIfChanged(
      GetOrCreateParamStream("GetQuestLogSpecialItemInfo", questId),
      t, tp, specialItem, questId, "GetQuestLogSpecialItemInfo"
    )
  end
end

---Probe a removed quest after the current event stack has settled.
---@param capture CaptureState
---@param questId number
local function ProbeRemovedQuestLater(capture, questId)
  if not capture.active or not capture.session then return end
  local t = GetTime() - capture.startedAt
  local tp = GetTimePreciseSec() - capture.startedAtPrecise
  ProbeQuestDirectApis(t, tp, questId)
end

---Schedule post-invalidation probes for a quest that left QuestLog.
---The immediate caller performs the first probe at the removal timestamp; these
---delayed probes capture exact API behavior after Blizzard state settles.
---@param capture CaptureState
---@param questId number
local function SchedulePostInvalidationProbes(capture, questId)
  local token = capture.token
  for i = 1, #SAMPLE_DELAYS do
    local delay = SAMPLE_DELAYS[i]
    if delay > 0 then
      C_After(delay, function()
        if not capture.active or capture.token ~= token then return end
        ProbeRemovedQuestLater(capture, questId)
      end)
    end
  end
end

---Run post-invalidation probes for quests removed from the quest log.
---Raw function streams are not given invented inactive values here. Instead,
---the tracker calls the underlying APIs for the removed quest ID and records
---exactly what those APIs return, immediately and after delayed retries.
---@param capture CaptureState
---@param t number
---@param tp number
---@param currentQuestIds number[]
local function ProbeRemovedQuestState(capture, t, tp, currentQuestIds)
  if not prevQuestLog then return end

  ---@type table<number, boolean>
  local currentSet = {}
  for i = 1, #currentQuestIds do
    currentSet[currentQuestIds[i]] = true
  end

  for i = 1, #prevQuestLog do
    local questId = prevQuestLog[i]
    if not currentSet[questId] then
      ProbeQuestDirectApis(t, tp, questId)
      SchedulePostInvalidationProbes(capture, questId)
    end
  end
end

---Sample native timer varargs and derive questId-keyed compatibility streams.
---Classic timer APIs are not questID-parameterized: `GetQuestTimers()` returns
---timer slots, and `GetQuestIndexForTimer(slot)` maps each slot to the current
---quest log index. We store the resolved seconds under questID so replay callers
---can answer Questie's questID-shaped timer queries without mutating quest-log
---selection via `SelectQuestLogEntry`.
---
---`GetQuestIndexForTimer[slot]` is also recorded raw, change-only, for the
---current slots, so replay can rebuild `GetQuestTimers()` in slot order. The
---number of current slots is the number of quests with a non-nil derived
---`GetQuestTimers[questId]`; slots past it are not read.
---@param t number
---@param tp number
local function SampleQuestTimers(t, tp)
  if type(GetQuestTimers) ~= "function" or type(GetQuestIndexForTimer) ~= "function" then return end

  local ok, timers = SafePackedCall(GetQuestTimers)
  if not ok or not timers then return end

  ---@type table<number, boolean>
  local currentTimedQuestIds = {}

  for timerIndex = 1, timers.n do
    local secondsLeft = timers[timerIndex]
    local indexOk, questLogIndex = SafeScalarCall(GetQuestIndexForTimer, timerIndex)

    -- Raw slot-to-quest-log-index map
    if indexOk then
      local slotStream = GetOrCreateParamStream("GetQuestIndexForTimer", timerIndex)
      local previous = slotStream[#slotStream]
      if not previous or previous.v ~= questLogIndex then
        slotStream[#slotStream + 1] = { t = t, tp = tp, v = questLogIndex }
        recordedChange = true
      end
    end

    -- Derived seconds left, keyed by quest ID
    if indexOk and type(questLogIndex) == "number" then
      local questId = GetQuestIdAtLogIndex(questLogIndex)
      if questId then
        currentTimedQuestIds[questId] = true
        AppendIfChanged(
          GetOrCreateParamStream("GetQuestTimers", questId),
          t, tp, secondsLeft, questId, "GetQuestTimers"
        )
        AppendIfChanged(
          GetOrCreateParamStream("GetQuestLogTimeLeft", questId),
          t, tp, secondsLeft, questId, "GetQuestLogTimeLeft"
        )
      end
    end
  end

  for questId in pairs(prevTimedQuestIds) do
    if not currentTimedQuestIds[questId] then
      AppendIfChanged(
        GetOrCreateParamStream("GetQuestTimers", questId),
        t, tp, nil, questId, "GetQuestTimers"
      )
      AppendIfChanged(
        GetOrCreateParamStream("GetQuestLogTimeLeft", questId),
        t, tp, nil, questId, "GetQuestLogTimeLeft"
      )
    end
  end

  prevTimedQuestIds = currentTimedQuestIds
end

---------------------------------------------------------------------------
-- Core sampling
---------------------------------------------------------------------------

--- Record the quest ID list when it differs from the previous one.
---@param capture CaptureState
---@param t number
---@param tp number
---@param questIds number[]
local function RecordQuestLogMembership(capture, t, tp, questIds)
  -- QuestLog membership discovers which quest IDs are active. When a quest
  -- leaves this list, raw direct questID APIs are probed again rather than
  -- receiving invented inactive values.
  ---@type FunctionStreamEntry[]
  local questLogStream = functions["QuestLog"]
  if not prevQuestLog or not DeepCompare(questIds, prevQuestLog) then
    ProbeRemovedQuestState(capture, t, tp, questIds)

    ---@type number[]
    local copy = {}
    for i = 1, #questIds do copy[i] = questIds[i] end
    questLogStream[#questLogStream + 1] = { t = t, tp = tp, v = copy }
    recordedChange = true
    prevQuestLog = copy
  end
end

--- Sample the entire quest log and record changes.
---@param capture CaptureState
---@return boolean recordedChange
local function SampleQuestLog(capture)
  recordedChange = false
  ---@type number
  local t  = GetTime() - capture.startedAt
  ---@type number
  local tp = GetTimePreciseSec() - capture.startedAtPrecise

  ---@type number[]
  ---@type table<number, string?>
  local questIds, questZones = GetAllQuestIdsInLog()
  RecordQuestLogMembership(capture, t, tp, questIds)

  -- Timer APIs are native parameterless varargs; these questId-keyed streams are
  -- explicit derived compatibility streams, so nil writes for disappeared timer
  -- mappings are schema-level invalidations rather than raw API return values.
  SampleQuestTimers(t, tp)

  -- C_QuestLog.GetMaxNumQuestsCanAccept -- scalar number
  if type(C_QuestLog) == "table" and type(C_QuestLog.GetMaxNumQuestsCanAccept) == "function" then
    local ok, maxQuests = SafeScalarCall(C_QuestLog.GetMaxNumQuestsCanAccept)
    if ok then
      AppendFlatIfChanged(
        GetOrCreateFlatStream("C_QuestLog.GetMaxNumQuestsCanAccept"),
        t, tp, maxQuests, "C_QuestLog.GetMaxNumQuestsCanAccept"
      )
    end
  end

  -- C_QuestLog.GetQuestTimers -- raw table of the modern timer API (Forever).
  -- Seconds left shrink between samples, so a running timer appends on every
  -- quest-log sample; replay derives the countdown in between.
  if type(C_QuestLog) == "table" and type(C_QuestLog.GetQuestTimers) == "function" then
    local ok, questTimers = SafeScalarCall(C_QuestLog.GetQuestTimers)
    if ok then
      AppendFlatIfChanged(
        GetOrCreateFlatStream("C_QuestLog.GetQuestTimers"),
        t, tp, questTimers, "C_QuestLog.GetQuestTimers"
      )
    end
  end

  -- Per-quest functions (parameterized by questId)
  for _, questId in ipairs(questIds) do
    -- Raw direct questID APIs: append only values returned by successful calls.
    ProbeQuestDirectApis(t, tp, questId)

    -- QuestLogZone -- derived: header/zone title preceding this quest
    AppendIfChanged(
      GetOrCreateParamStream("QuestLogZone", questId),
      t, tp, questZones[questId], questId, "QuestLogZone"
    )

    -- Quest-log index, title-family, and text APIs: each raw API is probed
    -- and recorded independently, only when it actually exists.
    ProbeQuestLogIndexAndTitle(t, tp, questId)
  end

  return recordedChange
end

local RequestSample = Core.CreateSampleScheduler(SampleQuestLog)

---------------------------------------------------------------------------
-- Tracker registration
---------------------------------------------------------------------------

Core.RegisterTracker({
  events = {
    "QUEST_LOG_UPDATE",
    "QUEST_ACCEPTED",
    "QUEST_REMOVED",
    "QUEST_TURNED_IN",
    "QUEST_WATCH_UPDATE",
    "UNIT_QUEST_LOG_CHANGED",
    "QUEST_AUTOCOMPLETE",
    "QUEST_POI_UPDATE",
    "QUEST_ITEM_UPDATE",
    "QUEST_LOG_CRITERIA_UPDATE",
    "QUEST_DATA_LOAD_RESULT",
    "QUEST_WATCH_LIST_CHANGED",
    "QUESTLINE_UPDATE",
    "TASK_PROGRESS_UPDATE",
    "PLAYER_ENTERING_WORLD",
    "SPELLS_CHANGED",
  },

  ---@param capture CaptureState
  Init = function(capture)
    functions = capture.session.functions
    functions["QuestLog"] = {}
    functions["QuestAcceptLevel"] = {}
    questAcceptLevelStream = functions["QuestAcceptLevel"]
    prevQuestLog = nil
    prevFlat = {}
    prevQuest = {}
    prevNested = {}
    prevTimedQuestIds = {}
    prevRewardCounts = {}

    -- The quest ID list is recorded synchronously so the stream has a t=0
    -- baseline; the heavier per-quest sampling waits for the next frame.
    RecordQuestLogMembership(capture, 0, 0, (GetAllQuestIdsInLog()))

    -- Initial sample on the next frame: Init can run inside a long export
    -- click handler, and sampling every quest there hits "script ran too long".
    local token = capture.token
    C_After(0, function()
      if not capture.active or capture.token ~= token then return end
      RequestSample(capture)
    end)
  end,

  ---@param capture CaptureState
  ---@param event string
  ---@param ... any
  OnEvent = function(capture, event, ...)
    if event == "QUEST_ACCEPTED" then
      local first, second = ...
      local questId = second
      if not questId and first then
        questId = GetQuestIdAtLogIndex(first)
      end
      if questAcceptLevelStream and type(questId) == "number" and questId > 0 then
        local t = GetTime() - capture.startedAt
        local tp = GetTimePreciseSec() - capture.startedAtPrecise
        local level = UnitLevel("player")
        local stream = questAcceptLevelStream[questId]
        if not stream then
          stream = {}
          questAcceptLevelStream[questId] = stream
        end
        stream[#stream + 1] = { t = t, tp = tp, v = level }
      end
    end

    RequestSample(capture)
  end,
})
