local addonName, AM = ...

-- Searches a list of items one after the other (the results are stored by AM.ItemSearch like any search). The server
-- throttles the search queries and disconnects a client that sends too many: a query is only sent once the game says
-- its message system is ready, after the answer to the last one and a short pause. Used by the searches of the bargain
-- items (BargainScan) and of a recipe (RecipesTab); SellScan has its own, as it searches equipment with the sell form.
AM.SearchQueue = {}
local SearchQueue = AM.SearchQueue

-- The server allows 100 searches per minute: with the pause and the answer time of a query this stays well below.
local PAUSE = 0.7 -- seconds between the answer to a search and the next query
local RETRY = 0.25 -- seconds to wait for the game's message system
local ANSWER_TIMEOUT = 5 -- an item nobody sells gets no answer at all

local queues = {} -- every queue created, so one waits while another has a query out

local function OtherBusy(self)
  for _, other in ipairs(queues) do
    if other ~= self and other.current then
      return true
    end
  end
  return false
end

-- A new queue. options: log (debug log category), portrait (key of the portrait animation), event (fired when the
-- queue started, advanced or ended), onNothingListed(itemId, started) (optional: a search without any auction, or
-- without an answer; started is the time() the query was sent), onComplete(started) (optional: every item was
-- searched, started is the time() the queue started; not called when it was stopped).
function SearchQueue.Create(options)
  local self = { items = {}, done = 0, running = false, id = 0 }
  queues[#queues + 1] = self
  local queue = {}

  local function Changed()
    AM.Events.Fire(options.event)
  end

  local function Finish()
    AM.DebugLog.Log(options.log, "finished after %d of %d", self.done, #self.items)
    self.running = false
    self.id = self.id + 1
    self.current = nil
    AM.Portrait.StopAnimate(options.portrait)
    if self.done == #self.items and options.onComplete then
      options.onComplete(self.started)
    end
    Changed()
  end

  local SendNext

  -- The answer to the current query came, or none will: on to the next one.
  local function Advance(token, answered)
    if self.current ~= token then
      return
    end
    self.current = nil
    self.done = self.done + 1
    if not answered and options.onNothingListed then
      options.onNothingListed(token.itemId, token.started)
    end
    Changed()
    local id = self.id
    C_Timer.After(PAUSE, function()
      if id == self.id then
        SendNext()
      end
    end)
  end

  function SendNext()
    if not self.running then
      return
    end
    local id = self.id
    local itemId = self.items[self.done + 1]
    if not itemId then
      Finish()
      return
    end
    -- the full scan keeps the server busy: searches would stay unanswered and count as "nothing listed"
    if AM.Scan.IsRunning() or AM.SellScan.IsRunning() or OtherBusy(self)
      or not C_AuctionHouse.IsThrottledMessageSystemReady() then
      C_Timer.After(RETRY, function()
        if id == self.id then
          SendNext()
        end
      end)
      return
    end
    local token = { itemId = itemId, started = time() }
    self.current = token
    local key = C_AuctionHouse.MakeItemKey(itemId)
    -- like the game: item searches (equipment) are sorted by buyout then bid, commodities get no sort
    local info = C_AuctionHouse.GetItemKeyInfo(key)
    local classId = select(6, C_Item.GetItemInfoInstant(itemId))
    local equipment = info and info.isEquipment or classId == Enum.ItemClass.Weapon or classId == Enum.ItemClass.Armor
    local sorts = {}
    if info and not info.isCommodity or (not info and equipment) then
      sorts = {
        { sortOrder = Enum.AuctionHouseSortOrder.Buyout, reverseSort = false },
        { sortOrder = Enum.AuctionHouseSortOrder.Bid, reverseSort = false },
      }
    end
    AM.DebugLog.Log(options.log, "search item %d (%d of %d)", itemId, self.done + 1, #self.items)
    C_AuctionHouse.SendSearchQuery(key, sorts, false)
    C_Timer.After(ANSWER_TIMEOUT, function()
      if id == self.id then
        Advance(token, false)
      end
    end)
  end

  function queue.IsRunning()
    return self.running
  end

  -- Items searched so far and in all while the queue runs.
  function queue.GetProgress()
    return self.done, #self.items
  end

  -- Starts searching the items (itemIds, each once). False if it cannot start now (already running, a full scan
  -- running, the auction house closed) or there is nothing to search.
  function queue.Start(itemIds)
    if self.running or AM.Scan.IsRunning() or not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then
      return false
    end
    local items, seen = {}, {}
    for _, itemId in ipairs(itemIds) do
      if not seen[itemId] then
        seen[itemId] = true
        items[#items + 1] = itemId
      end
    end
    if #items == 0 then
      return false
    end
    self.items, self.done, self.started = items, 0, time()
    self.running = true
    self.id = self.id + 1
    AM.DebugLog.Log(options.log, "start with %d items", #items)
    AM.Portrait.StartAnimate(options.portrait)
    Changed()
    SendNext()
    return true
  end

  function queue.Stop()
    if self.running then
      Finish()
    end
  end

  AM.Events.Register("ITEM_SEARCHED", function(_, itemId)
    if self.current and self.current.itemId == itemId then
      Advance(self.current, true)
    end
  end)

  -- a complete answer without any auction: nothing listed, no need to wait for the timeout
  AM.Events.Register("ITEM_SEARCH_EMPTY", function(itemId)
    if self.current and self.current.itemId == itemId then
      Advance(self.current, false)
    end
  end)

  local events = CreateFrame("Frame")
  events:RegisterEvent("AUCTION_HOUSE_CLOSED")
  events:SetScript("OnEvent", queue.Stop)

  return queue
end
