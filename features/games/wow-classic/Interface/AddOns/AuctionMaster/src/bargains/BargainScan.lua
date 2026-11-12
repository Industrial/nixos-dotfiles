local addonName, AM = ...

-- Searches the items of all active bargain rules one after the other, so the Bargains tab shows the current state of each
-- (the results are stored by AM.ItemSearch like any search, and Bargains remembers them). Works like SellScan: the server
-- throttles the search queries and disconnects a client that sends too many, so a query is only sent once the game says
-- its message system is ready, after the answer to the last one and a short pause. Data and actions only, the button is
-- in BargainsPanel.
AM.BargainScan = {}
local BargainScan = AM.BargainScan

local PAUSE = 0.7 -- seconds between the answer to a search and the next query
local RETRY = 0.25 -- seconds to wait for the game's message system
local ANSWER_TIMEOUT = 5 -- an item nobody sells gets no answer at all
local DUPLICATE_SECONDS = 5 -- see ItemSearch: an identical result within this time is not announced again

local running = false
local scanId = 0
local queue, done, current = {}, 0, nil

function BargainScan.IsRunning()
  return running
end

-- Items searched so far and in all while a scan runs.
function BargainScan.GetProgress()
  return done, #queue
end

local function Finish()
  AM.DebugLog.Log("bargainscan", "finished after %d of %d", done, #queue)
  running = false
  scanId = scanId + 1
  current = nil
  AM.Portrait.StopAnimate("bargains")
  AM.Events.Fire("BARGAIN_SCAN_CHANGED")
end

local SendNext

-- The answer to the current query came, or none will: on to the next one. Without an answer nothing is listed.
local function Advance(token, answered)
  if current ~= token then
    return
  end
  current = nil
  done = done + 1
  if not answered then
    AM.Bargains.OnNothingListed(token.itemId, token.started - DUPLICATE_SECONDS)
  end
  AM.Events.Fire("BARGAIN_SCAN_CHANGED")
  local id = scanId
  C_Timer.After(PAUSE, function()
    if id == scanId then
      SendNext()
    end
  end)
end

function SendNext()
  if not running then
    return
  end
  local id = scanId
  local itemId = queue[done + 1]
  if not itemId then
    Finish()
    return
  end
  -- the full scan keeps the server busy: searches would stay unanswered and count as "nothing listed"
  if AM.Scan.IsRunning() or AM.SellScan.IsRunning() or not C_AuctionHouse.IsThrottledMessageSystemReady() then
    C_Timer.After(RETRY, function()
      if id == scanId then
        SendNext()
      end
    end)
    return
  end
  local token = { itemId = itemId, started = time() }
  current = token
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
  AM.DebugLog.Log("bargainscan", "search item %d (%d of %d)", itemId, done + 1, #queue)
  C_AuctionHouse.SendSearchQuery(key, sorts, false)
  C_Timer.After(ANSWER_TIMEOUT, function()
    if id == scanId then
      Advance(token, false)
    end
  end)
end

-- Starts searching the items of the active item rules.
function BargainScan.Start()
  if running or AM.Scan.IsRunning() or not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then
    return
  end
  queue, done = {}, 0
  local seen = {}
  for _, rule in ipairs(AM.Bargains.GetRules("item")) do
    if rule.active and not seen[rule.itemId] then
      seen[rule.itemId] = true
      queue[#queue + 1] = rule.itemId
    end
  end
  if #queue == 0 then
    return
  end
  running = true
  scanId = scanId + 1
  AM.DebugLog.Log("bargainscan", "start with %d items", #queue)
  AM.Portrait.StartAnimate("bargains")
  AM.Events.Fire("BARGAIN_SCAN_CHANGED")
  SendNext()
end

function BargainScan.Stop()
  if running then
    Finish()
  end
end

AM.Events.Register("ITEM_SEARCHED", function(_, itemId)
  if current and current.itemId == itemId then
    Advance(current, true)
  end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("AUCTION_HOUSE_CLOSED")
events:SetScript("OnEvent", BargainScan.Stop)
