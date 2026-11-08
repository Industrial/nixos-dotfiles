---@type QuestieTraceCore
local Core = QuestieTraceCore
---@type fun(...): PackedArgs
local PackArgs = Core.PackArgs
---@type fun(t1: any, t2: any, ignore_mt: boolean?, visited: table?): boolean
local DeepCompare = Core.DeepCompare

---------------------------------------------------------------------------
-- WoW API return schemas (for trace analyzer display labels)
---------------------------------------------------------------------------
-- GetNumLootItems() -> number numLootItems
--
-- GetLootSlotInfo(slot) -> string  lootIcon,
--                          string  lootName,
--                          number  lootQuantity,
--                          number  currencyID,
--                          number  lootQuality,
--                          boolean locked,
--                          boolean isQuestItem,
--                          number  questID,
--                          boolean isActive
--
-- GetLootSourceInfo(slot) -> string guid,
--                            number quantity
--
-- GetLootSlotLink(index) -> string itemLink
--
-- GetLootSlotType(slotIndex) -> number slotType
---------------------------------------------------------------------------

---@class LootSlotStreams
---@field info FunctionStreamEntry[]
---@field source FunctionStreamEntry[]
---@field link FunctionStreamEntry[]
---@field type FunctionStreamEntry[]

-- Stream references (set during Init)
---@type table<string, FunctionStream>
local functions
---@type table<number, LootSlotStreams>? [slot] -> { info=stream, source=stream, link=stream, type=stream }
local lootSlotStreams

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

---Append a scalar value to a stream if it changed.
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

---Append a packed value to a stream if it changed.
---@param stream FunctionStreamEntry[]
---@param t number
---@param tp number
---@param value PackedArgs
local function AppendPackedIfChanged(stream, t, tp, value)
  local prev = stream[#stream]
  if not prev or not DeepCompare(prev.v, value) then
    stream[#stream + 1] = { t = t, tp = tp, v = value }
  end
end

---Ensure stream references exist for a loot slot.
---@param slot number
---@return LootSlotStreams streams
local function GetOrCreateSlotStreams(slot)
  lootSlotStreams = lootSlotStreams or {}
  if not lootSlotStreams[slot] then
    lootSlotStreams[slot] = {
      info = GetOrCreateParamStream("GetLootSlotInfo", slot),
      source = GetOrCreateParamStream("GetLootSourceInfo", slot),
      link = GetOrCreateParamStream("GetLootSlotLink", slot),
      type = GetOrCreateParamStream("GetLootSlotType", slot),
    }
  end
  return lootSlotStreams[slot]
end

---Sample GetNumLootItems and append the observed API return.
---@param t number
---@param tp number
---@return number? itemCount
local function SampleLootCount(t, tp)
  local ok, itemCount = SafeScalarCall(GetNumLootItems)
  if not ok then return nil end

  local countStream = functions["GetNumLootItems"]
  ---@cast countStream FunctionStreamEntry[]
  AppendScalarIfChanged(countStream, t, tp, itemCount)

  if type(itemCount) == "number" then return itemCount end
  return nil
end

---Whether every GUID present in a packed GetLootSourceInfo tuple
---(guid1, qty1, guid2, qty2, ...) is safe to store. Mirrors the allow-list
---used by UnitInteraction.lua: only recognized non-player kinds are kept, so
---a player GUID *or* an unrecognized GUID kind causes the whole tuple to be
---discarded (see AGENTS.md/CLAUDE.md "Privacy": discard if "player" or
---unrecognized).
---@param source PackedArgs?
---@return boolean allowed
local function IsLootSourceAllowed(source)
  if type(source) ~= "table" then return true end
  for i = 1, source.n or 0, 2 do
    ---@type any
    local guid = source[i]
    if guid ~= nil then
      ---@type "player"|"npc"|"object"|"item"|nil
      local kind = Core.ParseGUIDKind(guid)
      if kind ~= "npc" and kind ~= "object" and kind ~= "item" then
        return false
      end
    end
  end
  return true
end

---Probe one loot slot and append successful observed API returns.
---@param t number
---@param tp number
---@param slot number
local function ProbeLootSlot(t, tp, slot)
  local streams = GetOrCreateSlotStreams(slot)

  local infoOk, info = SafePackedCall(GetLootSlotInfo, slot)
  if infoOk and info then
    AppendPackedIfChanged(streams.info, t, tp, info)
  end

  -- Privacy: never record a loot source GUID that belongs to a player, or
  -- to an unrecognized GUID kind.
  local sourceOk, source = SafePackedCall(GetLootSourceInfo, slot)
  if sourceOk and source and IsLootSourceAllowed(source) then
    -- Keep every successful source sample: link and source streams are
    -- correlated by exact timestamp, so an unchanged source must still be
    -- present when the link changes (and vice versa).
    streams.source[#streams.source + 1] = { t = t, tp = tp, v = source }
  end

  local linkOk, link = SafeScalarCall(GetLootSlotLink, slot)
  if linkOk then
    -- Likewise preserve every successful link sample for exact-time matching.
    streams.link[#streams.link + 1] = { t = t, tp = tp, v = link }
  end

  local typeOk, slotType = SafeScalarCall(GetLootSlotType, slot)
  if typeOk then
    AppendScalarIfChanged(streams.type, t, tp, slotType)
  end
end

---Sample current loot slots by calling raw APIs.
---@param capture CaptureState
local function SampleLootOpen(capture)
  local t = GetTime() - capture.startedAt
  local tp = GetTimePreciseSec() - capture.startedAtPrecise
  local itemCount = SampleLootCount(t, tp)
  if not itemCount or itemCount < 1 then return end

  for slot = 1, itemCount do
    ProbeLootSlot(t, tp, slot)
  end
end

---Sample loot APIs at close without inventing inactive values.
---Known slot indices are probed because close is the causal event where raw
---loot APIs may naturally change to nil/zero/error states.
---@param capture CaptureState
local function SampleLootClose(capture)
  local t = GetTime() - capture.startedAt
  local tp = GetTimePreciseSec() - capture.startedAtPrecise
  SampleLootCount(t, tp)

  if lootSlotStreams then
    for slot in pairs(lootSlotStreams) do
      ProbeLootSlot(t, tp, slot)
    end
  end
end

Core.RegisterTracker({
  events = { "LOOT_READY", "LOOT_CLOSED" },

  ---@param capture CaptureState
  Init = function(capture)
    functions = capture.session.functions
    functions["GetNumLootItems"] = {}
    lootSlotStreams = nil

    -- Initial sample stores the observed API return, if the API is available.
    SampleLootCount(0, 0)
  end,

  ---@param capture CaptureState
  ---@param event string
  OnEvent = function(capture, event)
    if event == "LOOT_READY" then
      SampleLootOpen(capture)
    elseif event == "LOOT_CLOSED" then
      SampleLootClose(capture)
    end
  end,
})
