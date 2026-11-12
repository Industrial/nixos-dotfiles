local addonName, AM = ...

-- Searches the auctions of every item that can be sold, one after the other, so the Sell tab can tell what each
-- of them brings now (the results are stored by AM.ItemSearch like any search). The server throttles the search
-- queries and disconnects a client that sends too many: a query is only sent once the game says its message system
-- is ready, after the answer to the last one and a short pause. Data and actions only, the button is in SellPanel.
AM.SellScan = {}
local SellScan = AM.SellScan

-- The server allows 100 searches per minute: with the pause and the answer time of a query this stays well below.
local PAUSE = 0.7 -- seconds between the answer to a search and the next query
local RETRY = 0.25 -- seconds to wait for the game's message system
local ANSWER_TIMEOUT = 5 -- an item nobody sells gets no answer at all

local running = false
local scanId = 0
local queue, done, current = {}, 0, nil
local formUsed, formBefore = false, nil -- the game's sell form was used to search, and what it held before
local searched = {} -- itemDbKey -> time of the last search seen (also the game's own), nothing listed or not

local searchedEmpty = {} -- itemId -> time of the last search that came back without any auction

-- True if the item was searched recently, whether anything was listed or not.
function SellScan.IsSearched(itemDbKey)
  local at = searched[itemDbKey]
  local emptyAt = searchedEmpty[AM.ItemDbKey.GetItemId(itemDbKey)]
  at = math.max(at or 0, emptyAt or 0)
  return at > 0 and time() - at <= AM.ItemSearch.CACHE_SECONDS
end

local function IsCurrent(itemDbKey)
  return AM.ItemSearch.GetSellPrice(itemDbKey) ~= nil or SellScan.IsSearched(itemDbKey)
end

-- entries are { itemId, itemDbKey, location, ignored } as the Sell tab lists them, ignored ones are skipped. True if all of them were searched recently.
function SellScan.IsDone(entries)
  for _, entry in ipairs(entries) do
    if not entry.ignored and not IsCurrent(entry.itemDbKey) then
      return false
    end
  end
  return true
end

function SellScan.IsRunning()
  return running
end

-- Items searched so far and in all while a scan runs.
function SellScan.GetProgress()
  return done, #queue
end

-- The item in the game's sell form, nil if there is none.
local function GetFormItem()
  local house = AuctionHouseFrame
  for _, name in ipairs({ "ItemSellFrame", "CommoditiesSellFrame" }) do
    local frame = house and house[name]
    local location = frame and frame.GetItem and frame:GetItem()
    if location and location:IsValid() then
      return location
    end
  end
end

local function Finish()
  AM.DebugLog.Log("sellscan", "finished after %d of %d", done, #queue)
  running = false
  scanId = scanId + 1
  current = nil
  -- the form shows what the player had in it before the scan again
  local house = AuctionHouseFrame
  if formUsed and house and house:IsShown() then
    if formBefore and formBefore:IsValid() then
      house:SetPostItem(formBefore)
    else
      house:ClearPostItem()
    end
  end
  formUsed, formBefore = false, nil
  AM.Portrait.StopAnimate("sell")
  AM.Events.Fire("SELL_SCAN_CHANGED")
end

local SendNext

-- The answer to the current query came, or none will: on to the next one.
local function Advance(token)
  if current ~= token then
    return
  end
  current = nil
  searched[token.itemDbKey] = time()
  done = done + 1
  AM.DebugLog.Log("sellscan", "item %s done (%d of %d)", token.itemDbKey, done, #queue)
  AM.Events.Fire("SELL_SCAN_CHANGED")
  local id = scanId
  if token.form then
    -- the form is emptied again as soon as it has answered, once the game has handled the event itself
    C_Timer.After(0, function()
      if id == scanId and AuctionHouseFrame then
        AuctionHouseFrame:ClearPostItem()
      end
    end)
  end
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
  local item = queue[done + 1]
  if not item then
    Finish()
    return
  end
  -- the full scan keeps the server busy: searches would stay unanswered and count as "nothing listed"
  if AM.Scan.IsRunning() or not C_AuctionHouse.IsThrottledMessageSystemReady() then
    C_Timer.After(RETRY, function()
      if id == scanId then
        SendNext()
      end
    end)
    return
  end
  local token = { itemId = item.itemId, itemDbKey = item.itemDbKey, form = item.equipment }
  current = token
  AM.DebugLog.Log("sellscan", "search item %s (%d of %d) via %s", item.itemDbKey, done + 1, #queue,
    item.equipment and "sell form" or "query")
  -- like the game's sell form: item searches (equipment, pets) are sorted by buyout then bid, commodities get no sort
  local sorts = {}
  if C_AuctionHouse.GetItemCommodityStatus(item.location) == Enum.ItemCommodityStatus.Item then
    sorts = {
      { sortOrder = Enum.AuctionHouseSortOrder.Buyout, reverseSort = false },
      { sortOrder = Enum.AuctionHouseSortOrder.Bid, reverseSort = false },
    }
  end
  if item.equipment then
    -- The game searches equipment without item level (to compare it with similar items) and lists every
    -- level; the server stays silent to the same query sent from here. So the item is put into the game's own sell
    -- form, as a click does, and the form sends it. What is found is stored per level (ItemSearch).
    formUsed = true
    AuctionHouseFrame:SetPostItem(item.location)
  else
    C_AuctionHouse.SendSearchQuery(item.ahItemKey, sorts, false)
  end
  C_Timer.After(ANSWER_TIMEOUT, function()
    if id == scanId then
      Advance(token)
    end
  end)
end

-- Starts searching the entries that have no recent search yet, all of them if rescan is set.
function SellScan.Start(entries, rescan)
  if running or AM.Scan.IsRunning() or not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then
    return
  end
  queue, done = {}, 0
  formBefore = GetFormItem()
  for _, entry in ipairs(entries) do
    local ahItemKey = not entry.ignored and (rescan or not IsCurrent(entry.itemDbKey)) and C_AuctionHouse.GetItemKeyFromItem(entry.location)
    if ahItemKey then
      local info = C_AuctionHouse.GetItemKeyInfo(ahItemKey)
      local equipment = info and info.isEquipment
      if not info then
        -- the game has no key info for an item it has not looked at yet: told by its class then
        local classId = select(6, C_Item.GetItemInfoInstant(entry.itemId))
        equipment = classId == Enum.ItemClass.Weapon or classId == Enum.ItemClass.Armor
      end
      queue[#queue + 1] = {
        itemId = entry.itemId, itemDbKey = entry.itemDbKey, ahItemKey = ahItemKey, location = entry.location, equipment = equipment,
      }
    end
  end
  if #queue == 0 then
    return
  end
  running = true
  scanId = scanId + 1
  AM.DebugLog.Log("sellscan", "start with %d items", #queue)
  AM.Portrait.StartAnimate("sell")
  AM.Events.Fire("SELL_SCAN_CHANGED")
  SendNext()
end

-- Any answer to the search of an item answers it, whichever variants it listed; what the search of an item found no
-- auction of is marked as searched when the item is done.
AM.Events.Register("ITEM_SEARCHED", function(itemDbKey, itemId)
  searched[itemDbKey] = time()
  if current and current.itemId == itemId then
    Advance(current)
  end
end)

-- A search the player did (the game's sell form) found nothing listed: the item counts as searched, so its row says
-- "Price unknown" instead of asking for a scan.
AM.Events.Register("ITEM_SEARCH_EMPTY", function(itemId)
  searchedEmpty[itemId] = time()
  if current and current.itemId == itemId then
    -- the scan does not wait for its timeout: Advance marks the item and redraws
    Advance(current)
  else
    AM.Events.Fire("SELL_SCAN_CHANGED")
  end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("AUCTION_HOUSE_CLOSED")
events:SetScript("OnEvent", function()
  if running then
    Finish()
  end
end)
