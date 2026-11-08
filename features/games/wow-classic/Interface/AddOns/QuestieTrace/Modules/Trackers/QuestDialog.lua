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
-- C_GossipInfo.GetOptions()         -> GossipOptionUIInfo[]
--
-- GetGossipAvailableQuests() -> repeated legacy 7-tuples:
--   title, questLevel, isTrivial, frequency, repeatable, isLegendary, isIgnored
-- GetGossipActiveQuests() -> repeated legacy 6-tuples:
--   title, questLevel, isTrivial, isComplete, isLegendary, isIgnored
--
-- GetActiveTitle(index)        -> title, isComplete
-- GetAvailableTitle(index)     -> title
-- GetAvailableQuestInfo(index) -> isTrivial, frequency, isRepeatable, isLegendary, questID, isImportant
--   Blizzard's Forever UI also reads isMeta, questInfoID (Gethe/wow-ui-source `forever` @ 9437644,
--   1.60.1 (70338), Blizzard_UIPanels_Game/Mainline/QuestFrame.lua:390); not verified in-client.
--   Older clients may return fewer values.
-- GetActiveQuestID(index)      -> questID (Forever only, undocumented)
--
-- Quest dialog rewards and requirements (QUEST_DETAIL/PROGRESS/COMPLETE):
-- GetNumQuestRewards(), GetNumQuestItems(), GetNumQuestCurrencies() -> number count
-- GetQuestItemInfo(type, index) -> name, texture, count, quality, isUsable, itemID, ...
--   type is "choice" (1..GetNumQuestChoices), "reward" (1..GetNumQuestRewards) or
--   "required" (1..GetNumQuestItems); stored as functions[key][type][index].
-- GetQuestItemLink(type, index) -> string? itemLink
-- GetRewardMoney(), GetQuestMoneyToGet() -> number copper
-- GetRewardTitle()              -> string? title
-- GetRewardSkillPoints()        -> skillName, skillIcon, skillPoints (all nil when none)
-- GetSuggestedGroupSize()       -> number size (0 when none)
-- QuestGetAutoAccept()          -> boolean
-- GetQuestBackgroundMaterial()  -> string? material (nil = default parchment)
--
-- Reward currencies, on clients that have these APIs (Mists' quest frame reads
-- them; feature-detected, so absent APIs record nothing):
-- GetNumRewardCurrencies(), GetMaxRewardCurrencies() -> number count
-- GetQuestCurrencyInfo("reward", index) -> name, texture, count, quality
-- GetQuestCurrencyID("reward", index)   -> number? currencyID
--   read for index 1..GetMaxRewardCurrencies(); stored as functions[key]["reward"][index].
--
-- Quest flags, keyed by quest ID (Forever only):
-- IsBreadcrumbQuest(questID)                        -> isBreadcrumb (undocumented)
-- C_QuestLine.GetQuestLineInfo(questID)             -> QuestLineInfo?
-- C_QuestInfoSystem.GetQuestClassification(questID) -> Enum.QuestClassification
---------------------------------------------------------------------------

---@type number[]
local SAMPLE_DELAYS = { 0, 0.10, 0.35, 0.55, 0.75, 1.00 }

---@class QuestDialogStreamDef
---@field key string
---@field getter fun(): boolean, any

---@class QuestFlagStreamDef
---@field key string
---@field fn function Called with a quest ID as its only argument

---@type table<string, FunctionStream>
local functions
---@type table<string, any>
local previousValues
---@type table<string, boolean>
local availableFlatStreams
---@type number
local maxActiveQuestCount = 0
---@type number
local maxAvailableQuestCount = 0
---@type number
local delayedSampleToken = 0 -- Invalidates pending delayed samples when dialog/gossip state changes.

---Return whether a nested table function exists.
---@param namespace table?
---@param functionName string
---@return boolean
local function HasMethod(namespace, functionName)
  return type(namespace) == "table" and type(namespace[functionName]) == "function"
end

---Call a function with pcall and return all results packed, without the pcall status.
---@param fn function?
---@param ... any Native API arguments
---@return boolean ok
---@return PackedArgs? results
local function SafePackedCall(fn, ...)
  if type(fn) ~= "function" then return false, nil end

  ---@type PackedArgs
  local packed = PackArgs(pcall(fn, ...))
  if not packed[1] then return false, nil end

  ---@type PackedArgs
  local results = { n = packed.n - 1 }
  for i = 2, packed.n do
    results[i - 1] = packed[i]
  end
  return true, results
end

---Call a function with pcall and return its first result.
---@param fn function?
---@param ... any Native API arguments
---@return boolean ok
---@return any value
local function SafeScalarCall(fn, ...)
  local ok, results = SafePackedCall(fn, ...)
  if not ok or not results then return false, nil end
  return true, results[1]
end

---Append a value to a stream if it differs from the previous value.
---@param stream FunctionStreamEntry[]
---@param t number
---@param tp number
---@param key string
---@param value any
local function AppendIfChanged(stream, t, tp, key, value)
  local previous = previousValues[key]
  local changed

  if previous == nil and value == nil then
    changed = #stream == 0
  elseif previous == nil or value == nil then
    changed = true
  elseif type(value) == "table" then
    changed = not DeepCompare(value, previous)
  else
    changed = value ~= previous
  end

  if changed then
    stream[#stream + 1] = { t = t, tp = tp, v = value }
    previousValues[key] = value
  end
end

---Get or create a parameterized function stream.
---@param functionName string
---@param key number
---@return FunctionStreamEntry[]
local function GetOrCreateIndexStream(functionName, key)
  if not functions[functionName] then
    functions[functionName] = {}
  end

  local streams = functions[functionName]
  ---@cast streams table<number, FunctionStreamEntry[]>
  if not streams[key] then
    streams[key] = {}
  end
  return streams[key]
end

---Function keys whose returns hold free-form text that can
---embed a player's own name (e.g. NPC greetings like "Greetings, <name>").
---Quest titles and quest line names are static game data and do not contain
---player names, so they are stored raw. Reward titles are sanitized because
---a character title can be formatted around the player's name.
---@type table<string, boolean>
local SANITIZE_TEXT_FUNCTIONS = {
  ["C_GossipInfo.GetText"] = true,
  GetGreetingText = true,
  GetQuestText = true,
  GetObjectiveText = true,
  GetProgressText = true,
  GetRewardText = true,
  GetRewardTitle = true,
}

---Pass a return value's strings through Core.SanitizeText: a scalar string,
---or every top-level string in a packed tuple or returned table. Tables are
---copied so the API's own table is never modified; non-string fields stay raw.
---@param value any
---@return any sanitized
local function SanitizeReturn(value)
  if type(value) ~= "table" then
    return Core.SanitizeText(value)
  end

  local copy = {}
  for key, field in pairs(value) do
    copy[key] = Core.SanitizeText(field)
  end
  return copy
end

---Sample a stream keyed by its single argument (greeting index or quest ID).
---Failed or absent calls are skipped and create no stream.
---@param t number
---@param tp number
---@param functionName string
---@param fn function?
---@param key number
---@param packed boolean Store all returns as a packed tuple instead of the first return
---@return boolean ok
---@return any value
local function SampleParamStream(t, tp, functionName, fn, key, packed)
  local ok, value
  if packed then
    ok, value = SafePackedCall(fn, key)
  else
    ok, value = SafeScalarCall(fn, key)
  end
  if not ok then return false, nil end

  if SANITIZE_TEXT_FUNCTIONS[functionName] then
    value = SanitizeReturn(value)
  end

  AppendIfChanged(GetOrCreateIndexStream(functionName, key), t, tp, functionName .. ":" .. key, value)
  return true, value
end

---Create a stream only when its getter exists in this client.
---Dialog/gossip APIs vary across Classic flavors; absent APIs intentionally do
---not create empty streams, so replay can distinguish unavailable from nil.
---@param key string
local function EnsureFlatStream(key)
  functions[key] = {}
  availableFlatStreams[key] = true
end

---Sample one parameterless stream.
---@param t number
---@param tp number
---@param def QuestDialogStreamDef
local function SampleFlatStream(t, tp, def)
  if not availableFlatStreams[def.key] then return end

  local ok, value = def.getter()
  if not ok then return end

  if SANITIZE_TEXT_FUNCTIONS[def.key] then
    value = SanitizeReturn(value)
  end

  local stream = functions[def.key]
  ---@cast stream FunctionStreamEntry[]
  AppendIfChanged(stream, t, tp, def.key, value)
end

---@return QuestDialogStreamDef[]
local function BuildFlatStreamDefs()
  ---@type QuestDialogStreamDef[]
  local defs = {}

  if HasMethod(C_GossipInfo, "GetNumAvailableQuests") then
    EnsureFlatStream("C_GossipInfo.GetNumAvailableQuests")
    defs[#defs + 1] = {
      key = "C_GossipInfo.GetNumAvailableQuests",
      getter = function() return SafeScalarCall(C_GossipInfo.GetNumAvailableQuests) end
    }
  end
  if HasMethod(C_GossipInfo, "GetNumActiveQuests") then
    EnsureFlatStream("C_GossipInfo.GetNumActiveQuests")
    defs[#defs + 1] = {
      key = "C_GossipInfo.GetNumActiveQuests",
      getter = function() return SafeScalarCall(C_GossipInfo.GetNumActiveQuests) end
    }
  end
  if HasMethod(C_GossipInfo, "GetText") then
    EnsureFlatStream("C_GossipInfo.GetText")
    defs[#defs + 1] = {
      key = "C_GossipInfo.GetText",
      getter = function() return SafeScalarCall(C_GossipInfo.GetText) end
    }
  end
  if HasMethod(C_GossipInfo, "GetOptions") then
    EnsureFlatStream("C_GossipInfo.GetOptions")
    defs[#defs + 1] = {
      key = "C_GossipInfo.GetOptions",
      getter = function() return SafeScalarCall(C_GossipInfo.GetOptions) end
    }
  end

  ---@type table<string, boolean>
  local scalarFunctions = {
    GetNumGossipAvailableQuests = true,
    GetNumGossipActiveQuests = true,
    GetGreetingText = true,
    GetNumActiveQuests = true,
    GetNumAvailableQuests = true,
    GetQuestID = true,
    GetTitleText = true,
    GetQuestText = true,
    GetObjectiveText = true,
    GetProgressText = true,
    GetRewardText = true,
    GetRewardXP = true,
    IsQuestCompletable = true,
    GetNumQuestChoices = true,
    GetNumQuestRewards = true,
    GetNumQuestItems = true,
    GetNumQuestCurrencies = true,
    GetRewardMoney = true,
    GetQuestMoneyToGet = true,
    GetRewardTitle = true,
    GetSuggestedGroupSize = true,
    QuestGetAutoAccept = true,
    GetQuestBackgroundMaterial = true,
    GetNumRewardCurrencies = true,
    GetMaxRewardCurrencies = true,
  }

  for functionName in pairs(scalarFunctions) do
    local fn = _G[functionName]
    if type(fn) == "function" then
      EnsureFlatStream(functionName)
      defs[#defs + 1] = { key = functionName, getter = function() return SafeScalarCall(fn) end }
    end
  end

  ---@type table<string, boolean>
  local packedFunctions = {
    GetGossipAvailableQuests = true,
    GetGossipActiveQuests = true,
    GetRewardSkillPoints = true,
  }

  for functionName in pairs(packedFunctions) do
    local fn = _G[functionName]
    if type(fn) == "function" then
      EnsureFlatStream(functionName)
      defs[#defs + 1] = { key = functionName, getter = function() return SafePackedCall(fn) end }
    end
  end

  return defs
end

---Resolve the quest-flag APIs this client has. All are Forever-only, so on
---Era the list is empty and no quest flags are sampled.
---@return QuestFlagStreamDef[]
local function BuildQuestFlagDefs()
  ---@type QuestFlagStreamDef[]
  local defs = {}
  if type(IsBreadcrumbQuest) == "function" then
    defs[#defs + 1] = { key = "IsBreadcrumbQuest", fn = IsBreadcrumbQuest }
  end
  if HasMethod(C_QuestLine, "GetQuestLineInfo") then
    defs[#defs + 1] = { key = "C_QuestLine.GetQuestLineInfo", fn = C_QuestLine.GetQuestLineInfo }
  end
  if HasMethod(C_QuestInfoSystem, "GetQuestClassification") then
    defs[#defs + 1] = { key = "C_QuestInfoSystem.GetQuestClassification", fn = C_QuestInfoSystem.GetQuestClassification }
  end
  return defs
end

---@type QuestDialogStreamDef[]
local flatStreamDefs
---@type QuestFlagStreamDef[]
local questFlagDefs

---Return whether an event closes transient dialog/gossip state.
---@param event string
---@return boolean
local function IsCloseEvent(event)
  return event == "GOSSIP_CLOSED" or event == "QUEST_FINISHED"
end

---Add a quest ID to a set, ignoring the 0/nil that dialog APIs return when no quest is shown.
---@param questIDs table<number, boolean>
---@param questID any
local function AddQuestID(questIDs, questID)
  if type(questID) == "number" and questID > 0 then
    questIDs[questID] = true
  end
end

---Sample greeting APIs keyed by active/available quest index.
---Keep the highest counts for this capture so delayed samples retry stale
---indices even when the first shrink probe errors or returns unsettled data.
---Failed calls are skipped; raw streams never receive invented inactive values.
---@param t number
---@param tp number
---@param questIDs table<number, boolean> Receives the quest IDs returned by GetAvailableQuestInfo
local function SampleGreetingStreams(t, tp, questIDs)
  local ok, count = SafeScalarCall(GetNumActiveQuests)
  if ok and type(count) == "number" then
    maxActiveQuestCount = math.max(maxActiveQuestCount, count)
    for index = 1, maxActiveQuestCount do
      SampleParamStream(t, tp, "GetActiveTitle", GetActiveTitle, index, true)
      SampleParamStream(t, tp, "GetActiveQuestID", GetActiveQuestID, index, false)
    end
  end

  ok, count = SafeScalarCall(GetNumAvailableQuests)
  if ok and type(count) == "number" then
    maxAvailableQuestCount = math.max(maxAvailableQuestCount, count)
    for index = 1, maxAvailableQuestCount do
      SampleParamStream(t, tp, "GetAvailableTitle", GetAvailableTitle, index, false)
      local infoOk, info = SampleParamStream(t, tp, "GetAvailableQuestInfo", GetAvailableQuestInfo, index, true)
      if infoOk then
        AddQuestID(questIDs, info[5])
      end
    end
  end
end

---@class QuestListReader
---@field key string Global API name, called as key(itemType, index)
---@field packed boolean Store all returns as a packed tuple instead of the first return

---@type QuestListReader[]
local ITEM_READERS = {
  { key = "GetQuestItemInfo", packed = true },
  { key = "GetQuestItemLink", packed = false },
}
---@type QuestListReader[]
local CURRENCY_READERS = {
  { key = "GetQuestCurrencyInfo", packed = true },
  { key = "GetQuestCurrencyID", packed = false },
}

---Quest dialog lists read per index, each for indices 1..its bound API.
---@type { itemType: "choice"|"reward"|"required", bound: string, readers: QuestListReader[] }[]
local QUEST_DIALOG_LISTS = {
  { itemType = "choice", bound = "GetNumQuestChoices", readers = ITEM_READERS },
  { itemType = "reward", bound = "GetNumQuestRewards", readers = ITEM_READERS },
  { itemType = "required", bound = "GetNumQuestItems", readers = ITEM_READERS },
  -- Mists' quest frame reads reward currencies up to GetMaxRewardCurrencies(),
  -- past GetNumRewardCurrencies() (Wrath/QuestInfo.lua). Classic frames never
  -- read required currencies. Clients without these APIs read nothing.
  { itemType = "reward", bound = "GetMaxRewardCurrencies", readers = CURRENCY_READERS },
}

---Sample a two-argument stream stored in native argument order as
---functions[functionName][itemType][index]. Failed calls are skipped.
---@param t number
---@param tp number
---@param functionName string
---@param fn function?
---@param itemType string
---@param index number
---@param packed boolean Store all returns as a packed tuple instead of the first return
local function SampleQuestItemStream(t, tp, functionName, fn, itemType, index, packed)
  local ok, value
  if packed then
    ok, value = SafePackedCall(fn, itemType, index)
  else
    ok, value = SafeScalarCall(fn, itemType, index)
  end
  if not ok then return end

  local byType = functions[functionName] or {}
  functions[functionName] = byType
  ---@cast byType table<string, table<number, FunctionStreamEntry[]>>
  local byIndex = byType[itemType] or {}
  byType[itemType] = byIndex
  local stream = byIndex[index] or {}
  byIndex[index] = stream

  AppendIfChanged(stream, t, tp, functionName .. ":" .. itemType .. ":" .. index, value)
end

---Sample every item and currency slot the open quest dialog lists: reward
---choices, fixed rewards, required items and reward currencies. Each list is
---read up to the bound Blizzard's quest frame uses, and no further.
---@param t number
---@param tp number
local function SampleQuestItems(t, tp)
  for i = 1, #QUEST_DIALOG_LISTS do
    local list = QUEST_DIALOG_LISTS[i]
    local ok, count = SafeScalarCall(_G[list.bound])
    if ok and type(count) == "number" then
      for index = 1, count do
        for _, reader in ipairs(list.readers) do
          SampleQuestItemStream(t, tp, reader.key, _G[reader.key], list.itemType, index, reader.packed)
        end
      end
    end
  end
end

---Add the current dialog quest and the gossip-offered quests to questIDs.
---These reads only choose which quests get flag samples: GetQuestID is
---recorded by the flat streams, and UnitInteraction records the gossip list.
---@param questIDs table<number, boolean>
local function CollectDialogQuestIDs(questIDs)
  local ok, questID = SafeScalarCall(GetQuestID)
  if ok then
    AddQuestID(questIDs, questID)
  end

  if HasMethod(C_GossipInfo, "GetAvailableQuests") then
    local listOk, available = SafeScalarCall(C_GossipInfo.GetAvailableQuests)
    if listOk and type(available) == "table" then
      for _, info in ipairs(available) do
        if type(info) == "table" then
          AddQuestID(questIDs, info.questID)
        end
      end
    end
  end
end

---Sample every available quest-flag API for each quest ID, change-only per quest.
---@param t number
---@param tp number
---@param questIDs table<number, boolean>
local function SampleQuestFlags(t, tp, questIDs)
  for questID in pairs(questIDs) do
    for i = 1, #questFlagDefs do
      local def = questFlagDefs[i]
      SampleParamStream(t, tp, def.key, def.fn, questID, false)
    end
  end
end

---Sample all quest-dialog streams.
---@param capture CaptureState
---@return number t Session-relative GetTime()
---@return number tp Session-relative GetTimePreciseSec()
local function SampleQuestDialog(capture)
  local t = GetTime() - capture.startedAt
  local tp = GetTimePreciseSec() - capture.startedAtPrecise

  for i = 1, #flatStreamDefs do
    SampleFlatStream(t, tp, flatStreamDefs[i])
  end
  SampleQuestItems(t, tp)

  ---@type table<number, boolean>
  local questIDs = {}
  SampleGreetingStreams(t, tp, questIDs)
  if #questFlagDefs > 0 then
    CollectDialogQuestIDs(questIDs)
    SampleQuestFlags(t, tp, questIDs)
  end

  return t, tp
end

---Schedule staggered re-samples to catch dialog state settling after open/update events.
---Quest and gossip frames may expose incomplete values in the event call stack.
---Close events cancel these pending delayed reads and perform a single observed
---close-state sample instead of writing synthetic reset values.
---@param capture CaptureState
local function ScheduleDelayedSamples(capture)
  delayedSampleToken = delayedSampleToken + 1
  local sampleToken = delayedSampleToken
  local token = capture.token
  for i = 1, #SAMPLE_DELAYS do
    local delay = SAMPLE_DELAYS[i]
    if delay > 0 then
      C_After(delay, function()
        if not capture.active or capture.token ~= token or delayedSampleToken ~= sampleToken then return end
        SampleQuestDialog(capture)
      end)
    end
  end
end

Core.RegisterTracker({
  events = {
    "QUEST_DETAIL",
    "QUEST_PROGRESS",
    "QUEST_COMPLETE",
    "QUEST_FINISHED",
    "QUEST_GREETING",
    "QUEST_ACCEPT_CONFIRM",
    "GOSSIP_SHOW",
    "GOSSIP_CLOSED",
  },

  ---@param capture CaptureState
  Init = function(capture)
    functions = capture.session.functions
    previousValues = {}
    availableFlatStreams = {}
    maxActiveQuestCount = 0
    maxAvailableQuestCount = 0
    delayedSampleToken = 0
    flatStreamDefs = BuildFlatStreamDefs()
    questFlagDefs = BuildQuestFlagDefs()

    SampleQuestDialog(capture)
    ScheduleDelayedSamples(capture)
  end,

  ---@param capture CaptureState
  ---@param event string
  OnEvent = function(capture, event)
    if IsCloseEvent(event) then
      -- Close boundaries are causal sampling points for mutable dialog/gossip
      -- APIs. Cancel pending open/update delayed reads, sample the APIs once,
      -- and record only the observed return values.
      delayedSampleToken = delayedSampleToken + 1
      SampleQuestDialog(capture)
      return
    end

    SampleQuestDialog(capture)
    ScheduleDelayedSamples(capture)
  end,
})
