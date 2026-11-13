local addonName, AM = ...
local L = AM.L

AM.Scan = {}
local Scan = AM.Scan

-- The server allows one successful ReplicateItems call per 15 minutes, account-wide.
-- There is no API to query that state, so the time of the last scan is kept in the
-- (account-wide) saved variables. A call during the throttle is silently ignored and
-- never fires an event, so lastScan is recorded optimistically on every call, not just
-- on success, or a throttled call would go unnoticed and could be retried indefinitely.
-- The time shown to the user is therefore a separate value, lastSuccess, which is only
-- set once the items were read and stored, to the time that scan was started.
--
-- The response of a busy auction house can take a while (seen: about 1 s on Forever, 17 s for 250000 auctions on
-- Retail), but sometimes it never comes: the first call after a long break has been seen to get no answer, and such a
-- lost call still counts for the 15 minutes, every call before they are over is ignored. After ResponseTimeout()
-- seconds the scan is reported as not answered and stops showing as running, but it keeps listening: an answer that
-- arrives later is still used, with a message. The 15 minutes stay counted from the lost call; there is no retry of
-- its own, the scan button (AM.ScanButton) shows when the next scan is possible.
--
-- The addon only starts a scan by itself when the auction house opens if the player switched that on in the options
-- (Scan.IsAutoEnabled), AUTO_DELAY seconds after it opened; otherwise every scan is started with the scan button.
local THROTTLE_SECONDS = 15 * 60
local READY_WAIT = 30
local READY_POLL = 0.5
local READY_SETTLE = 1

-- A full scan can contain a hundred thousand auctions, so they are read in slices spread over several frames to not
-- freeze the game: a slice ends once it has used this many milliseconds (checked every CHECK_EVERY auctions), so the
-- rest of the interface keeps running at a playable frame rate.
local SLICE_MS = 4
local CHECK_EVERY = 100

local IDLE, WAITING, READING, TIMED_OUT = 0, 1, 2, 3

local state = IDLE
local scanId = 0
local startTime = nil
local readCount, readTotal = 0, 0 -- auctions read so far and in all, while READING
local requestedAt = nil -- time() of the last ReplicateItems call
local manual = false -- the player started the running scan (a click), not the addon by itself: see AM.Chat

local events = CreateFrame("Frame")
local loadEvents = CreateFrame("Frame") -- listens for item data only while a scan waits for it
local loading -- while a scan waits for item data: see StartLoading

local function Finish(count)
  state = IDLE
  loading = nil
  loadEvents:UnregisterAllEvents()
  events:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE")
  events:UnregisterEvent("AUCTION_HOUSE_CLOSED")
  AM.Portrait.StopAnimate()
  AM.DebugLog.Log("scan", "finished, %s auctions read", count)
  if count then
    AM.Print(L["SCAN_FINISHED"]:format(count, GetTime() - startTime), "detailed")
  end
  AM.MainWindow.Refresh()
  AM.Events.Fire("SCAN_CHANGED")
end

-- The throttle (lastScan) is account-wide like the server's, lastSuccess belongs to the auction house that was scanned.
local function GetState()
  return AM.Database.GetGlobalObject("scan")
end

-- The scan state of the current auction house. lastSuccess used to be account-wide: it is taken over by the first
-- auction house that asks and has stored auctions, the one that took the data of that scan over (see
-- Database.GetFactionObject). One without auctions was never scanned.
local function GetHouseState()
  local house = AM.Database.GetFactionObject("scan")
  local global = GetState()
  if house.lastSuccess == nil and global.lastSuccess ~= nil and AM.ItemStore.HasScan() then
    house.lastSuccess, global.lastSuccess = global.lastSuccess, nil
  end
  return house
end

-- When the last full scan of the current auction house was started that stored its items, nil if there was none.
function Scan.GetLastSuccess()
  return GetHouseState().lastSuccess
end

local function IsThrottled()
  local last = GetState().lastScan
  return last ~= nil and time() - last < THROTTLE_SECONDS
end

-- Equipment is stored per item level (see AM.ItemDbKey), which the game works out from the link, and the link is only
-- there once the item data is loaded. Such an auction waits. Its item is requested once (the request is per item, not
-- per auction) and the game answers with ITEM_DATA_LOAD_RESULT, which resolves all auctions of the item at once, or
-- tells that the item cannot be loaded. An item without an answer is requested again after REREQUEST_SECONDS. The
-- waiting ends when nothing waits any more, after LOAD_TIMEOUT seconds, or when it stalled: the number of auctions
-- waiting fell by less than STALL_SHARE in the last STALL_SECONDS. The items still without data then are left out with
-- all their auctions, a price from some of the auctions of an item would be a wrong one.
local ROUND_SECONDS = 0.5
local REREQUEST_SECONDS = 5
local LOAD_TIMEOUT = 120
local STALL_SECONDS = 15
local STALL_SHARE = 0.01

-- Only itemId, count and the prices are available right away, the other values of
-- GetReplicateItemInfo are loaded lazily by the client and may be nil. The modern
-- auction house has no bidding, an auction only has its buyout price, which is the price
-- here, in copper for the whole stack. A price of 0 means it is not available.
local function ReadItem(index)
  local _, _, count, quality, _, _, _, _, _, price, _, _, _, _, _, _, itemId =
    C_AuctionHouse.GetReplicateItemInfo(index)
  if not itemId or itemId == 0 then
    return nil
  end
  return {
    itemId = itemId,
    count = count,
    price = price,
    index = index,
  }, quality
end

-- Sets the itemDbKey of the auction if it can be built now. True if it is set.
local function ResolveKey(auction)
  if not auction.itemDbKey then
    auction.itemDbKey = AM.ItemDbKey.ForItem(auction.itemId)
  end
  if not auction.itemDbKey then
    auction.itemDbKey = AM.ItemDbKey.FromLink(C_AuctionHouse.GetReplicateItemLink(auction.index))
  end
  return auction.itemDbKey ~= nil
end

-- The auctions that can be stored: those with a key, and not those of an item of which some auction still lacks its key
-- (unresolved), as the prices of the others would be a wrong picture of what is listed.
function Scan.Storable(items, unresolved)
  local incomplete = {}
  for _, auction in ipairs(unresolved) do
    incomplete[auction.itemId] = true
  end
  local stored = {}
  for _, auction in ipairs(items) do
    if auction.itemDbKey and not incomplete[auction.itemId] then
      stored[#stored + 1] = auction
    end
  end
  return stored
end

local function Store(id, items, unresolved, collector)
  if id ~= scanId then
    return
  end
  local stored = Scan.Storable(items, unresolved)
  AM.DebugLog.Log("scan", "storing %d of %d auctions, %d without item data left out", #stored, #items, #unresolved)
  -- An empty result means there was nothing to read, don't wipe the stored prices.
  if #stored > 0 then
    AM.ItemStore.Replace(stored)
    GetHouseState().lastSuccess = requestedAt -- the start, like the countdown to the next scan
    AM.Bargains.OnFullScan()
    AM.Bargains.FinishScan(collector)
  end
  Finish(#stored)
end

-- True if the waiting has stalled: history holds { time, waiting } per round, and the count fell by less than
-- STALL_SHARE since the newest round that is at least STALL_SECONDS old.
function Scan.IsStalled(history, now, waiting)
  for index = #history, 1, -1 do
    local round = history[index]
    if now - round[1] >= STALL_SECONDS then
      return round[2] - waiting < round[2] * STALL_SHARE
    end
  end
  return false
end

-- For the debug log: why the auctions that never got a key lack it, by class and by cause, and a few examples. The
-- items are { itemId -> list of auctions }, failed the ones the game could not load.
local function DescribeUnresolved(byItem, failed)
  local classes, causes, samples = {}, {}, {}
  local itemCount, auctionCount = 0, 0
  for itemId, list in pairs(byItem) do
    itemCount = itemCount + 1
    auctionCount = auctionCount + #list
    local class = select(6, C_Item.GetItemInfoInstant(itemId)) or -1
    classes[class] = (classes[class] or 0) + #list
    local link = C_AuctionHouse.GetReplicateItemLink(list[1].index)
    local cause = "no answer"
    if failed[itemId] then
      cause = "the game could not load the item"
    elseif link then
      cause = "link without item level"
    end
    causes[cause] = (causes[cause] or 0) + #list
    if #samples < 12 then
      local hasAllInfo = select(18, C_AuctionHouse.GetReplicateItemInfo(list[1].index))
      samples[#samples + 1] = ("%d class %d x%d: %s, hasAllInfo %s, level %s, %s"):format(itemId, class, #list, cause,
        tostring(hasAllInfo), tostring(link and C_Item.GetDetailedItemLevelInfo(link)),
        link and link:match("|Hitem:[^|]*") or "no link")
    end
  end
  AM.DebugLog.Log("scan", "%d auctions of %d items never got item data", auctionCount, itemCount)
  for class, count in pairs(classes) do
    AM.DebugLog.Log("scan", "  class %d: %d auctions", class, count)
  end
  for cause, count in pairs(causes) do
    AM.DebugLog.Log("scan", "  %s: %d auctions", cause, count)
  end
  for _, sample in ipairs(samples) do
    AM.DebugLog.Log("scan", "  example %s", sample)
  end
end

-- Tries to build the keys of the auctions of an item; the ones that got one leave the list.
local function TryItem(load, itemId)
  local list = load.byItem[itemId]
  if not list or load.failed[itemId] then
    return
  end
  local still = {}
  for _, auction in ipairs(list) do
    if not ResolveKey(auction) then
      still[#still + 1] = auction
    end
  end
  load.waiting = load.waiting - (#list - #still)
  load.byItem[itemId] = #still > 0 and still or nil
end

-- The auctions that still have no key, all items together.
local function Unresolved(load)
  local list = {}
  for _, auctions in pairs(load.byItem) do
    for _, auction in ipairs(auctions) do
      list[#list + 1] = auction
    end
  end
  return list
end

local function EndLoading(load, reason)
  loading = nil
  loadEvents:UnregisterAllEvents()
  local unresolved = Unresolved(load)
  AM.DebugLog.Log("scan", "item data: waiting ended after %.1f s (%s), %d requests, %d auctions without", GetTime() - load.start,
    reason, load.requests, #unresolved)
  if #unresolved > 0 and AM.DebugLog.IsEnabled() then
    DescribeUnresolved(load.byItem, load.failed)
  end
  Store(load.id, load.items, unresolved, load.collector)
end

-- One pass over the items that still wait: their keys are tried, the ones without an answer for a while are requested
-- again. Works in slices like the reading, and the next pass starts ROUND_SECONDS after the last one.
local function Round(load)
  if load.id ~= scanId or loading ~= load then
    return
  end
  local order, waiting = load.order, {}
  local position = 1
  local function Slice()
    if load.id ~= scanId or loading ~= load then
      return
    end
    local sliceStart = debugprofilestop()
    local now = GetTime()
    while position <= #order do
      local itemId = order[position]
      TryItem(load, itemId)
      if load.byItem[itemId] and not load.failed[itemId] then
        waiting[#waiting + 1] = itemId
        local requested = load.requestedAt[itemId]
        if not requested or now - requested >= REREQUEST_SECONDS then
          load.requestedAt[itemId] = now
          load.requests = load.requests + 1
          C_Item.RequestLoadItemDataByID(itemId)
        end
      end
      position = position + 1
      if position % CHECK_EVERY == 0 and debugprofilestop() - sliceStart >= SLICE_MS then
        C_Timer.After(0, Slice)
        return
      end
    end
    load.order = waiting
    local waited = now - load.start
    -- one line per five seconds
    if #load.history == 0 or now - load.history[#load.history][1] >= 5 then
      AM.DebugLog.Log("scan", "item data: %d auctions of %d items wait, %d items failed, after %.1f s", load.waiting,
        #waiting, load.failedItems, waited)
    end
    local stalled = Scan.IsStalled(load.history, now, load.waiting)
    load.history[#load.history + 1] = { now, load.waiting }
    if load.waiting <= 0 then
      EndLoading(load, "done")
    elseif waited >= LOAD_TIMEOUT or stalled then
      EndLoading(load, stalled and "no more progress" or "timeout")
    else
      C_Timer.After(ROUND_SECONDS, function()
        Round(load)
      end)
    end
  end
  Slice()
end

-- Waits for the item data of the auctions without a key. pending is the list of those auctions.
local function StartLoading(id, items, pending, collector)
  local load = {
    id = id, items = items, collector = collector, byItem = {}, order = {}, requestedAt = {}, failed = {}, failedItems = 0, history = {},
    waiting = #pending, requests = 0, start = GetTime(),
  }
  for _, auction in ipairs(pending) do
    local list = load.byItem[auction.itemId]
    if not list then
      list = {}
      load.byItem[auction.itemId] = list
      load.order[#load.order + 1] = auction.itemId
    end
    list[#list + 1] = auction
  end
  loading = load
  loadEvents:RegisterEvent("ITEM_DATA_LOAD_RESULT")
  Round(load)
end

loadEvents:SetScript("OnEvent", function(_, _, itemId, success)
  local load = loading
  if not load or not load.byItem[itemId] or load.failed[itemId] then
    return
  end
  if success then
    TryItem(load, itemId)
  else
    -- the game cannot load this item: it is not waited for any more
    load.failed[itemId] = true
    load.failedItems = load.failedItems + 1
    load.waiting = load.waiting - #load.byItem[itemId]
  end
end)

local function ReadBatch(id, items, pending, first, total, collector)
  if id ~= scanId then
    return
  end

  local started = debugprofilestop()
  local last = first - 1
  while last + 1 < total do
    for index = last + 1, math.min(last + CHECK_EVERY, total) - 1 do
      local item, quality = ReadItem(index)
      if item then
        items[#items + 1] = item
        if not ResolveKey(item) then
          pending[#pending + 1] = item
        end
        if collector then
          AM.Bargains.Collect(collector, item.itemId, item.count, item.price, quality, index)
        end
      end
    end
    last = math.min(last + CHECK_EVERY, total) - 1
    readCount = last + 1
    if debugprofilestop() - started >= SLICE_MS then
      break
    end
  end

  if last + 1 < total then
    C_Timer.After(0, function()
      ReadBatch(id, items, pending, last + 1, total, collector)
    end)
  elseif #pending > 0 then
    AM.DebugLog.Log("scan", "read %d auctions, %d wait for item data", #items, #pending)
    StartLoading(id, items, pending, collector)
  else
    Store(id, items, pending, collector)
  end
end

local function OnReplicateUpdate()
  AM.DebugLog.Log("scan", "replicate list ready, state %d, %d items", state, C_AuctionHouse.GetNumReplicateItems())
  if state == TIMED_OUT then
    AM.Print(L["SCAN_LATE_RESPONSE"]:format(GetTime() - startTime), "detailed")
    AM.Portrait.StartAnimate()
  end
  -- The event fires again for every item the client caches while we read them, which
  -- is of no interest here. The first event means the list is complete.
  events:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE")
  local total = C_AuctionHouse.GetNumReplicateItems()
  AM.Print(L["SCAN_READING"], "detailed")
  state = READING
  readCount, readTotal = 0, total
  ReadBatch(scanId, {}, {}, 0, total, AM.Bargains.StartScan())
end

function Scan.IsRunning()
  return state == WAITING or state == READING
end

-- Auctions read so far and in all while a scan reads them, nil until the server has answered.
function Scan.GetProgress()
  if state == READING then
    return readCount, readTotal
  end
end

-- The progress shown for a running scan, 1 to 99: 1 while it waits for the server, then the share of the auctions read
-- (nil read: not answered yet). It stays at 99 until the scan is stored, as the item data can take a while after that.
function Scan.Percent(read, total)
  if not read or not total or total <= 0 then
    return 1
  end
  return math.max(1, math.min(99, math.floor(read / total * 100)))
end

-- The progress of the running scan in percent (see Scan.Percent), nil if none runs.
function Scan.GetPercent()
  if Scan.IsRunning() then
    return Scan.Percent(Scan.GetProgress())
  end
end

-- True while the last call got no answer within the timeout (a late answer is still used).
function Scan.HasTimedOut()
  return state == TIMED_OUT
end

-- Whether the addon starts a scan by itself when the auction house opens (global object "settings", off unless the
-- player switched it on: stored as true or nil).
function Scan.IsAutoEnabled()
  return AM.Database.GetGlobalObject("settings").autoScan == true
end

function Scan.SetAutoEnabled(enabled)
  if enabled then
    AM.Database.GetGlobalObject("settings").autoScan = true
  else
    AM.Database.GetGlobalObject("settings").autoScan = nil
  end
end

-- Seconds until the server allows the next full scan, 0 if it does.
function Scan.GetWaitSeconds()
  local last = GetState().lastScan
  if not last then
    return 0
  end
  return math.max(0, THROTTLE_SECONDS - (time() - last))
end

function Scan.GetStartTime()
  return startTime
end

-- Seconds to wait for the answer before the scan is reported as not answered. Retail answers much later than Forever,
-- with ten times the auctions (see the top of the file); Classic is not measured and uses the Retail value.
local function ResponseTimeout()
  return AM.Client.IsForever() and 20 or 40
end

local function OnTimeout()
  state = TIMED_OUT
  AM.DebugLog.Log("scan", "no response within %d seconds", ResponseTimeout())
  AM.Portrait.StopAnimate()
  AM.MainWindow.Refresh()
  AM.Events.Fire("SCAN_CHANGED")
end

-- manual: the player asked for the scan (a click), so what goes wrong is told at every chat setting.
function Scan.Start(isManual)
  if state ~= IDLE and state ~= TIMED_OUT then
    return
  end

  if IsThrottled() then
    AM.DebugLog.Log("scan", "not started, last scan at %s", GetState().lastScan)
    return
  end

  manual = isManual == true

  state = WAITING
  scanId = scanId + 1
  startTime = GetTime()

  AM.DebugLog.Log("scan", "started")
  AM.Portrait.StartAnimate()
  events:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
  events:RegisterEvent("AUCTION_HOUSE_CLOSED")
  AM.Events.Fire("SCAN_CHANGED")

  -- Right after opening the auction house the game's message system is busy with the game's own requests. The call
  -- waits until the system is ready and READY_SETTLE seconds longer, and is only sent if it is still ready then (all of
  -- it at most READY_WAIT seconds). The response timeout starts with the call.
  local id = scanId
  local waited = 0
  local settled = false
  local function Send()
    if id ~= scanId or state ~= WAITING then
      return
    end
    local ready = C_AuctionHouse.IsThrottledMessageSystemReady()
    if waited < READY_WAIT and (not ready or not settled) then
      -- a pause after the first ready, and again after the system was busy once more in it
      local delay = ready and READY_SETTLE or READY_POLL
      settled = ready
      waited = waited + delay
      C_Timer.After(delay, Send)
      return
    end
    AM.DebugLog.Log("scan", "requesting the list after %.1f s, message system ready: %s", waited, tostring(ready))
    requestedAt = time()
    GetState().lastScan = requestedAt
    C_AuctionHouse.ReplicateItems()
    C_Timer.After(ResponseTimeout(), function()
      if id == scanId and state == WAITING then
        OnTimeout()
      end
    end)
  end
  Send()
end

-- The automatic scan waits AUTO_DELAY seconds after the auction house opened: a call sent sooner has been seen to get
-- no answer, while a click some seconds later worked. It is dropped when the auction house was closed in that time,
-- or opened again (that opening waits for itself: openId).
local AUTO_DELAY = 2
local openId = 0

events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:SetScript("OnEvent", function(_, event)
  if event == "AUCTION_HOUSE_SHOW" then
    openId = openId + 1
    if Scan.IsAutoEnabled() then
      local id = openId
      C_Timer.After(AUTO_DELAY, function()
        if id == openId and AuctionHouseFrame and AuctionHouseFrame:IsShown() then
          Scan.Start()
        end
      end)
    end
  elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
    OnReplicateUpdate()
  else
    -- Invalidates a batch that may still be scheduled.
    scanId = scanId + 1
    AM.DebugLog.Log("scan", "auction house closed in state %d", state)
    local timedOut = state == TIMED_OUT
    Finish()
    if not timedOut then
      AM.Print(L["SCAN_ABORTED"], manual and "quiet" or "detailed")
    end
  end
end)
