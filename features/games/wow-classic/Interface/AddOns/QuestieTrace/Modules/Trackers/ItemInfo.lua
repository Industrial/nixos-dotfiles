---@type QuestieTraceCore
local Core = QuestieTraceCore

---------------------------------------------------------------------------
-- WoW API return schemas (for trace analyzer display labels)
---------------------------------------------------------------------------
-- C_Item.IsItemDataCachedByID(itemID) -> boolean cached
--
-- Stored as functions["C_Item.IsItemDataCachedByID"][itemID], change-only per
-- item, only for items an addon asked about before the client had their data:
-- - false right after the first recorded request of the capture that found
--   the item uncached: a C_Item.GetItemInfo/GetItemInfo call, or
--   C_Item.RequestLoadItemDataByID (which Item:ContinueOnItemLoad uses). The
--   load may have started earlier: before capture start, through a function
--   saved in a local, or by another addon's request refused past the switch;
-- - re-read when GET_ITEM_INFO_RECEIVED or ITEM_DATA_LOAD_RESULT reports the
--   item, so the switch to true is the arrival time. A failed load stays false.
--
-- The first ANY_ADDON_ITEMS streams come from any addon's requests. After that
-- only requests with Questie on the call stack get one, up to
-- MAX_RECORDED_ITEMS, so an auction house scan cannot crowd Questie's items out.
--
-- An item without a stream was cached when first asked about, never asked
-- about, asked about only by name, asked about only by other addons after the
-- first ANY_ADDON_ITEMS streams (a session with that many streams or more
-- reached the switch), or asked about after MAX_RECORDED_ITEMS streams.
-- Addons that saved these functions in a local before capture start are not
-- seen; Questie (v12.0.4 and later) looks C_Item.GetItemInfo up on every call,
-- through QuestieCompat.GetItemInfo.
---------------------------------------------------------------------------

---@type number Streams for any addon's requests. Auction house and collection
--- addons ask about thousands of items, so past this only Questie's get one.
local ANY_ADDON_ITEMS = 500
---@type number Hard cap on streams, Questie's included.
local MAX_RECORDED_ITEMS = 1000
---@type number Stack reads per item for other addons' requests past ANY_ADDON_ITEMS,
--- so an addon polling an item that never loads cannot read the stack all capture.
local STACK_READS_PER_ITEM = 3
---@type number Item IDs fit in 32 bits. A larger number, infinity included, is a junk argument.
local MAX_ITEM_ID = 2147483647

---@type table<number, FunctionStreamEntry[]>?
local cachedStreams
---@type number
local recordedItems = 0
---@type table<number, boolean> Items that are done for this capture: found cached, given a stream,
--- refused STACK_READS_PER_ITEM times, or whose cache check failed. Not saved; one entry per
--- distinct item ID asked about, which auction house scans make many thousands.
local checkedItems = {}
---@type table<number, number> Refused requests per item past ANY_ADDON_ITEMS, this capture.
local refusedItems = {}
---@type CaptureState?
local captureRef
---@type boolean hooksecurefunc hooks cannot be removed, so they are installed once.
local hooked = false

---Re-read whether an item's data has arrived.
---@param capture CaptureState
---@param stream FunctionStreamEntry[]
---@param itemID number
local function SampleCached(capture, stream, itemID)
  local ok, cached = pcall(C_Item.IsItemDataCachedByID, itemID)
  if not ok then return end
  local previous = stream[#stream]
  if not previous or previous.v ~= cached then
    stream[#stream + 1] = {
      t = GetTime() - capture.startedAt,
      tp = GetTimePreciseSec() - capture.startedAtPrecise,
      v = cached,
    }
  end
end

---The item ID in an item request's argument. Item names resolve only for
---cached items and start no load, so they are skipped.
---@param item any An item ID, numeric string, item link or item name
---@return number? itemID A whole number from 1 to MAX_ITEM_ID; never NaN or infinity
local function ToItemID(item)
  local itemID
  if type(item) == "number" then
    itemID = item
  elseif type(item) == "string" then
    itemID = tonumber(item:match("^(%d+)$") or item:match("item:(%d+)"))
  end
  -- NaN fails every comparison, and infinity the upper bound.
  if itemID and itemID >= 1 and itemID <= MAX_ITEM_ID and itemID % 1 == 0 then
    return itemID
  end
  return nil
end

---Whether Questie's code made the request: the caller, or up to three frames
---above it. That covers Questie's QuestieCompat.GetItemInfo wrapper and
---Blizzard's Item:ContinueOnItemLoad called from Questie.
---@return boolean
local function IsQuestieOnStack()
  -- Level 1 is this function, 2 the hook, 3 hooksecurefunc's C wrapper and 4
  -- the caller; each hook another addon installs on the same function later
  -- adds a C frame. Each frame read costs about 2.5 µs in Forever 1.60.1, so
  -- only four are read. Forever prints the full file path, however long, as
  -- "[Interface/AddOns/Questie/Modules/QuestieCompat.lua]:566: in function ...";
  -- the separators of other clients are unverified, so both are accepted.
  return debugstack(4, 4, 0):find("AddOns[/\\]Questie[/\\]") ~= nil
end

---Post-hook on every addon's item data requests. The original call has
---already run, so an uncached item is now loading.
---@param item any
local function OnItemDataRequest(item)
  local capture = captureRef
  if not capture or not capture.active or not cachedStreams then return end
  if recordedItems >= MAX_RECORDED_ITEMS then return end
  if issecretvalue and issecretvalue(item) then return end

  local itemID = ToItemID(item)
  if not itemID or checkedItems[itemID] then return end

  local ok, cached = pcall(C_Item.IsItemDataCachedByID, itemID)
  if not ok or cached then
    checkedItems[itemID] = true
    return
  end
  if recordedItems >= ANY_ADDON_ITEMS and not IsQuestieOnStack() then
    -- Another addon's request leaves the item unchecked, so Questie asking
    -- for it while it still loads gets a stream, until the read limit.
    local refusals = (refusedItems[itemID] or 0) + 1
    refusedItems[itemID] = refusals
    if refusals >= STACK_READS_PER_ITEM then
      checkedItems[itemID] = true
    end
    return
  end

  checkedItems[itemID] = true
  recordedItems = recordedItems + 1
  cachedStreams[itemID] = {
    { t = GetTime() - capture.startedAt, tp = GetTimePreciseSec() - capture.startedAtPrecise, v = false },
  }
end

---------------------------------------------------------------------------
-- Private item data frame
-- Each load reports through the event matching its request: Forever 1.60.1
-- fired only GET_ITEM_INFO_RECEIVED after GetItemInfo, and only
-- ITEM_DATA_LOAD_RESULT after RequestLoadItemDataByID. Both fire for every
-- item any addon or tooltip loads, so they are private triggers: only items
-- with a stream are re-read, and the events are never recorded.
---------------------------------------------------------------------------

---@type Frame
local receivedFrame = CreateFrame("Frame")
receivedFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
receivedFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
receivedFrame:SetScript("OnEvent", function(_, _, itemID)
  local capture = captureRef
  if not capture or not capture.active or not cachedStreams then return end
  local stream = cachedStreams[itemID]
  if stream then
    SampleCached(capture, stream, itemID)
  end
end)

Core.RegisterTracker({
  ---@param capture CaptureState
  Init = function(capture)
    cachedStreams = nil
    captureRef = nil
    recordedItems = 0
    checkedItems = {}
    refusedItems = {}
    if type(C_Item) ~= "table" or type(C_Item.IsItemDataCachedByID) ~= "function" then return end

    cachedStreams = {}
    capture.session.functions["C_Item.IsItemDataCachedByID"] = cachedStreams
    captureRef = capture

    if not hooked then
      hooked = true
      -- Some clients also have the global (Forever 1.60.1 does not). Each name
      -- gets its own wrapper, so a call through either one runs the hook once.
      if type(C_Item.GetItemInfo) == "function" then
        hooksecurefunc(C_Item, "GetItemInfo", OnItemDataRequest)
      end
      if type(GetItemInfo) == "function" then
        hooksecurefunc("GetItemInfo", OnItemDataRequest)
      end
      if type(C_Item.RequestLoadItemDataByID) == "function" then
        hooksecurefunc(C_Item, "RequestLoadItemDataByID", OnItemDataRequest)
      end
    end
  end,
})
