---@type QuestieTraceCore
local Core = QuestieTraceCore

local C_After = C_Timer.After

---------------------------------------------------------------------------
-- WoW API return schemas (for trace analyzer display labels)
---------------------------------------------------------------------------
-- C_Item.GetItemCount(itemID) -> number count  -- bags and equipped items, bank excluded
--
-- Stored as functions["C_Item.GetItemCount"][itemID], change-only per item.
--
-- Questie asks for the counts of quest objective items, but Forever's quest
-- objectives carry no item IDs. The tracker therefore reads every item the
-- player carries (bags, keyring and equipped slots):
-- - at capture start: an item with no entry at t=0 was not carried (count 0);
-- - after bag changes, at most once per RESCAN_DELAY (BAG_UPDATE_DELAYED);
-- - for the item of each ITEM_COUNT_CHANGED, immediately.
-- ITEM_COUNT_CHANGED alone is not enough: Forever skips it for some pickups
-- (often an item's first one), and Era does not have it at all.
---------------------------------------------------------------------------

---@type number Last equipment slot (INVSLOT_LAST_EQUIPPED); slot 0 is the Classic ammo slot.
local LAST_EQUIPPED_SLOT = 19
---@type number Seconds a bag rescan waits, so a burst of bag updates (looting, vendoring) costs one rescan.
local RESCAN_DELAY = 1

---@type table<number, FunctionStreamEntry[]>?
local countStreams
---@type CaptureState?
local captureRef
---@type boolean
local rescanPending = false

---Append the current count of one item if it changed. Failed calls are skipped.
---@param t number
---@param tp number
---@param itemID number
local function SampleItemCount(t, tp, itemID)
  if not countStreams then return end

  local ok, count = pcall(C_Item.GetItemCount, itemID)
  if not ok then return end

  local stream = countStreams[itemID]
  if not stream then
    stream = {}
    countStreams[itemID] = stream
  end
  local previous = stream[#stream]
  if not previous or previous.v ~= count then
    stream[#stream + 1] = { t = t, tp = tp, v = count }
  end
end

---Item IDs in the player's bags, keyring and equipment slots. These reads only
---choose which items get a count sample; they are not recorded themselves.
---@return table<number, boolean> itemIDs
local function CollectCarriedItemIDs()
  ---@type table<number, boolean>
  local itemIDs = {}

  -- Bags and keyring
  if type(C_Container) == "table" then
    ---@type number[]
    local bagIDs = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
      bagIDs[#bagIDs + 1] = bag
    end
    if KEYRING_CONTAINER then
      bagIDs[#bagIDs + 1] = KEYRING_CONTAINER
    end

    for _, bag in ipairs(bagIDs) do
      local slotsOk, numSlots = pcall(C_Container.GetContainerNumSlots, bag)
      if slotsOk and type(numSlots) == "number" then
        for slot = 1, numSlots do
          local itemOk, itemID = pcall(C_Container.GetContainerItemID, bag, slot)
          if itemOk and type(itemID) == "number" then
            itemIDs[itemID] = true
          end
        end
      end
    end
  end

  -- Equipped items, which GetItemCount also counts
  if type(GetInventoryItemID) == "function" then
    for slot = 0, LAST_EQUIPPED_SLOT do
      local itemOk, itemID = pcall(GetInventoryItemID, "player", slot)
      if itemOk and type(itemID) == "number" then
        itemIDs[itemID] = true
      end
    end
  end

  return itemIDs
end

---Sample every carried item, plus every recorded item whose last count was
---above 0, so an item that left the bags is recorded as 0. Items already at 0
---and not carried are skipped: their count cannot have changed.
---@param capture CaptureState
local function SampleCarriedItems(capture)
  if not countStreams then return end
  local t = GetTime() - capture.startedAt
  local tp = GetTimePreciseSec() - capture.startedAtPrecise

  local itemIDs = CollectCarriedItemIDs()
  for itemID, stream in pairs(countStreams) do
    local previous = stream[#stream]
    if previous and previous.v ~= 0 then
      itemIDs[itemID] = true
    end
  end

  for itemID in pairs(itemIDs) do
    SampleItemCount(t, tp, itemID)
  end
end

---------------------------------------------------------------------------
-- Private bag-update frame
-- BAG_UPDATE_DELAYED fires after every bag change, so it is a private
-- sampling trigger and stays out of the recorded event stream.
---------------------------------------------------------------------------

---@type Frame
local bagFrame = CreateFrame("Frame")
bagFrame:RegisterEvent("BAG_UPDATE_DELAYED")
bagFrame:SetScript("OnEvent", function()
  local capture = captureRef
  if not capture or not capture.active or rescanPending then return end

  rescanPending = true
  local token = capture.token
  C_After(RESCAN_DELAY, function()
    rescanPending = false
    if not capture.active or capture.token ~= token then return end
    SampleCarriedItems(capture)
  end)
end)

Core.RegisterTracker({
  events = {
    "ITEM_COUNT_CHANGED",
  },

  ---@param capture CaptureState
  Init = function(capture)
    countStreams = nil
    captureRef = nil
    rescanPending = false
    if type(C_Item) ~= "table" or type(C_Item.GetItemCount) ~= "function" then return end

    countStreams = {}
    capture.session.functions["C_Item.GetItemCount"] = countStreams
    captureRef = capture
    SampleCarriedItems(capture)
  end,

  ---@param capture CaptureState
  ---@param _event string
  ---@param itemID number
  OnEvent = function(capture, _event, itemID)
    if type(itemID) ~= "number" then return end
    local t = GetTime() - capture.startedAt
    local tp = GetTimePreciseSec() - capture.startedAtPrecise
    SampleItemCount(t, tp, itemID)
  end,
})
