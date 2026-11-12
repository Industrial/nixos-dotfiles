local addonName, AM = ...

-- The player's own running auctions and how many items are listed
-- cheaper than each of them. The count comes from a search of the item, like any search in the auction house; the
-- answers are stored by AM.ItemSearch as well, this module only reads them. The queries are throttled like those of
-- AM.SellScan. Data and actions only, the view is AM.AuctionsView.
AM.OwnAuctions = {}
local OwnAuctions = AM.OwnAuctions

local PAUSE = 0.7 -- seconds between the answer to a search and the next query
local RETRY = 0.25 -- seconds to wait for the game's message system
local ANSWER_TIMEOUT = 5

local running = false
local scanId = 0
local queue, done, current = {}, 0, nil
local states = {} -- auctionId -> { ahead (nil: unknown), atLeast, price (per item, nil: unknown), time }

-- How many items are listed cheaper than the price, not counting the player's own listings. listings are
-- { price (per item), count (1 for a single item), own (a listing of the player) } in any order; full is true if they
-- are all the listings there are. Returns the number and whether it is only a lower bound: not all listings were
-- loaded and none of the loaded ones is as expensive as the price, so more cheaper ones may follow.
-- ordered is true if the listings come in the order they are bought in (the last listed of a price is bought first,
-- commodities and single items alike): then the listings of the same price before the player's own one are ahead as well.
function OwnAuctions.CountAhead(listings, price, full, ordered)
  local ahead, reachedPrice, ownReached = 0, false, false
  for _, listing in ipairs(listings) do
    if listing.price >= price then
      reachedPrice = true
    end
    if listing.price == price and listing.own then
      ownReached = true
    elseif listing.price < price and not listing.own then
      ahead = ahead + listing.count
    elseif ordered and listing.price == price and not ownReached then
      ahead = ahead + listing.count
    end
  end
  return ahead, not full and not reachedPrice
end

-- The same for one auction of single items: what stands before exactly that auction in the list (listings carry the
-- auctionId of the game's result), not counting the player's own. Several auctions of the same price differ that way.
-- Falls back to CountAhead where the auction is not among the listings (commodities, results not loaded).
function OwnAuctions.CountAheadOfAuction(listings, auctionId, price, full, ordered)
  for index, listing in ipairs(listings) do
    if listing.auctionId ~= nil and listing.auctionId == auctionId then
      local ahead = 0
      for before = 1, index - 1 do
        if not listings[before].own then
          ahead = ahead + listings[before].count
        end
      end
      return ahead, false
    end
  end
  return OwnAuctions.CountAhead(listings, price, full, ordered)
end

-- The limits of how bad an undercut is, set in the options (SellSettings): single items by the number of items
-- ahead, stackable items by the share of all listed items that are ahead (percent). Up to the first limit is fine, up to
-- the second a warning, above it too much.
function OwnAuctions.GetLimits(stackable)
  local kind = stackable and "undercutPercent" or "undercutAuctions"
  local ok = AM.SellSettings.GetNumber(kind .. "Ok")
  return { ok, math.max(ok, AM.SellSettings.GetNumber(kind .. "Warn")) }
end

-- 0 (fine), 1 (warning) or 2 (too much) for the count ahead of an auction, by limits as GetLimits returns them. total
-- is the number of items listed in all; without it a stackable item is not rated (nil).
function OwnAuctions.Severity(ahead, total, stackable, limits)
  local value = ahead
  if stackable then
    if not total or total <= 0 then
      return nil
    end
    value = ahead / total * 100
  end
  if value <= limits[1] then
    return 0
  elseif value <= limits[2] then
    return 1
  end
  return 2
end

-- The price per item of a commodity auction. The game reports the buyout and the quantity, and whether the buyout is
-- per item or for all of them is not documented: it is the one of the two that is the price of a listing of the
-- player (ownPrices, price -> true). Nil if neither is.
function OwnAuctions.ResolveUnitPrice(buyout, quantity, ownPrices)
  if not buyout then
    return nil
  end
  if ownPrices[buyout] then
    return buyout
  end
  local unit = buyout / math.max(quantity, 1)
  if unit == math.floor(unit) and ownPrices[unit] then
    return unit
  end
  return nil
end

local function IsCurrent(state)
  return state ~= nil and time() - state.time <= AM.ItemSearch.CACHE_SECONDS
end

-- What the last search found for an auction (see GetAll), nil if there was none within the time a search counts.
function OwnAuctions.GetState(auctionId)
  local state = states[auctionId]
  if IsCurrent(state) then
    return state
  end
end

-- How bad the undercut of an auction is by the limits in the options: 0 (fine), 1 (warning), 2 (too much), nil where
-- it is not known (no current search, or the price of the auction could not be told).
function OwnAuctions.GetSeverity(auctionId)
  local state = OwnAuctions.GetState(auctionId)
  if not state or not state.ahead then
    return nil
  elseif state.ahead == 0 then
    return 0
  end
  return OwnAuctions.Severity(state.ahead, state.total, state.stackable, OwnAuctions.GetLimits(state.stackable))
end

-- The rank of an auction in the list of all auctions, the highest first: too much undercut (4), warning (3), not searched
-- yet (2), fine (1), already sold (0). severity is as GetSeverity returns it.
function OwnAuctions.SortRank(sold, severity)
  if sold then
    return 0
  elseif severity == nil then
    return 2
  end
  return ({ [0] = 1, 3, 4 })[severity] or 2
end

-- The order the list shows its entries in: indexes 1..count by rank (getRank(index)), highest first, entries of the same
-- rank in the order the game gave them, so the sorting chosen in the list's header stays the second criterion.
function OwnAuctions.BuildSortOrder(count, getRank)
  local order, ranks = {}, {}
  for index = 1, count do
    order[index] = index
    ranks[index] = getRank(index)
  end
  table.sort(order, function(a, b)
    if ranks[a] ~= ranks[b] then
      return ranks[a] > ranks[b]
    end
    return a < b
  end)
  return order
end

local function KeyOf(itemKey)
  return table.concat({ itemKey.itemID, itemKey.itemLevel or 0, itemKey.itemSuffix or 0, itemKey.battlePetSpeciesID or 0 }, ":")
end

-- The running auctions of the player: { auctionId, itemId, itemKey, link, quantity, buyout, seconds (left, nil if
-- the game only says a band), band, commodity (nil if the game does not know the item yet) }.
function OwnAuctions.GetAll()
  local list = {}
  local sold = Enum.AuctionStatus and Enum.AuctionStatus.Sold or 1
  for _, info in ipairs(C_AuctionHouse.GetOwnedAuctions() or {}) do
    if info.status ~= sold then
      local keyInfo = C_AuctionHouse.GetItemKeyInfo(info.itemKey)
      list[#list + 1] = {
        auctionId = info.auctionID,
        itemId = info.itemKey.itemID,
        itemKey = info.itemKey,
        link = info.itemLink,
        quantity = info.quantity,
        buyout = info.buyoutAmount,
        seconds = info.timeLeftSeconds,
        band = info.timeLeft,
        commodity = keyInfo and keyInfo.isCommodity,
      }
    end
  end
  return list
end

function OwnAuctions.IsRunning()
  return running
end

-- Items searched so far and in all while a scan runs.
function OwnAuctions.GetProgress()
  return done, #queue
end

local function Finish()
  AM.DebugLog.Log("ownauctions", "finished after %d of %d", done, #queue)
  running = false
  scanId = scanId + 1
  current = nil
  AM.Portrait.StopAnimate("auctions")
  AM.Events.Fire("OWN_AUCTIONS_CHANGED")
end

local SendNext

local function Advance(token)
  if current ~= token then
    return
  end
  current = nil
  done = done + 1
  AM.Events.Fire("OWN_AUCTIONS_CHANGED")
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
  local item = queue[done + 1]
  if not item then
    Finish()
    return
  end
  if AM.Scan.IsRunning() or not C_AuctionHouse.IsThrottledMessageSystemReady() then
    C_Timer.After(RETRY, function()
      if id == scanId then
        SendNext()
      end
    end)
    return
  end
  local token = { key = item.key }
  current = token
  AM.DebugLog.Log("ownauctions", "search %s (%d of %d)", item.key, done + 1, #queue)
  -- like the game's list of an item: single items are sorted by buyout only, so auctions of the same buyout stay in
  -- the order they are bought in (a second sort by bid would reorder them), commodities get no sort
  local sorts = {}
  if not item.commodity then
    sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Buyout, reverseSort = false } }
  end
  -- own auctions are listed apart from the others (true), as the game's list does; merged into one row the player's
  -- auctions would hide the items ahead of them
  C_AuctionHouse.SendSearchQuery(item.itemKey, sorts, true)
  C_Timer.After(ANSWER_TIMEOUT, function()
    if id == scanId then
      Advance(token)
    end
  end)
end

-- The items to search for the auctions: one per item, none whose commodity status is not known yet. With onlyMissing the
-- items of which every auction has a current state (hasState(entry), by default the stored state) are left out.
function OwnAuctions.BuildQueue(entries, onlyMissing, hasState)
  hasState = hasState or function(entry)
    return IsCurrent(states[entry.auctionId])
  end
  local list, byKey = {}, {}
  for _, entry in ipairs(entries) do
    if entry.commodity ~= nil then
      local key = KeyOf(entry.itemKey)
      local item = byKey[key]
      if not item then
        item = { key = key, itemKey = entry.itemKey, commodity = entry.commodity, missing = false }
        byKey[key] = item
        list[#list + 1] = item
      end
      if not hasState(entry) then
        item.missing = true
      end
    end
  end
  if onlyMissing then
    local missing = {}
    for _, item in ipairs(list) do
      if item.missing then
        missing[#missing + 1] = item
      end
    end
    return missing
  end
  return list
end

-- Starts searching the items of all auctions again (only those without a current search with onlyMissing). Returns
-- whether a scan was started.
function OwnAuctions.Start(entries, onlyMissing)
  if running or AM.Scan.IsRunning() or AM.SellScan.IsRunning() or not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then
    return false
  end
  queue, done = OwnAuctions.BuildQueue(entries, onlyMissing), 0
  if #queue == 0 then
    return false
  end
  running = true
  scanId = scanId + 1
  AM.DebugLog.Log("ownauctions", "start with %d items", #queue)
  AM.Portrait.StartAnimate("auctions")
  AM.Events.Fire("OWN_AUCTIONS_CHANGED")
  SendNext()
  return true
end

-- Ends a running scan; the states found so far stay.
function OwnAuctions.Stop()
  if running then
    AM.DebugLog.Log("ownauctions", "stopped after %d of %d", done, #queue)
    Finish()
  end
end

-- The listings of a commodity search, and the prices of the player's own among them.
local function ReadCommodityListings(itemId)
  local listings, ownPrices = {}, {}
  for index = 1, C_AuctionHouse.GetNumCommoditySearchResults(itemId) do
    local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemId, index)
    if result and result.quantity > 0 then
      listings[#listings + 1] = { price = result.unitPrice, count = result.quantity, own = result.containsOwnerItem }
      if result.containsOwnerItem then
        ownPrices[result.unitPrice] = true
      end
    end
  end
  return listings, ownPrices
end

-- The listings of a single item search that are of the item level asked for.
local function ReadItemListings(itemKey, itemLevel)
  local listings = {}
  for index = 1, C_AuctionHouse.GetNumItemSearchResults(itemKey) do
    local result = C_AuctionHouse.GetItemSearchResultInfo(itemKey, index)
    local price = result and result.buyoutAmount
    if price and price > 0 and (itemLevel == 0 or result.itemKey.itemLevel == itemLevel) then
      -- like the game's list: ranked by the price of the whole auction, and all its items count
      listings[#listings + 1] = { price = price, count = math.max(result.quantity or 1, 1), own = result.containsOwnerItem, auctionId = result.auctionID }
    end
  end
  return listings
end

-- A search brought listings for the owned auctions matching the test: works out what is ahead of each. Returns true
-- if it did: the game also fires the event with no results while it restarts a search, which says nothing.
local function OnResults(matches, commodity, readListings)
  local changed = false
  for _, entry in ipairs(OwnAuctions.GetAll()) do
    if matches(entry) then
      local listings, ownPrices, full = readListings(entry)
      if #listings == 0 then
        return false
      end
      local price = entry.buyout
      if commodity then
        price = OwnAuctions.ResolveUnitPrice(entry.buyout, entry.quantity, ownPrices)
      end
      -- stackable: rated by the share of the listed items, otherwise by the number of items ahead
      local state = { price = price, time = time(), total = 0, stackable = commodity or entry.quantity > 1 }
      for _, listing in ipairs(listings) do
        state.total = state.total + listing.count
        state.stackable = state.stackable or listing.count > 1
      end
      if price then
        state.ahead, state.atLeast = OwnAuctions.CountAheadOfAuction(listings, entry.auctionId, price, full, true)
      end
      AM.DebugLog.Log("ownauctions", "auction %d: price %s, %d listings, full %s, ahead %s, scan running %s",
        entry.auctionId, tostring(price), #listings, tostring(full), tostring(state.ahead), tostring(running))
      if AM.DebugLog.IsEnabled() then
        -- the order the listings came in: price x count, "*" for an own one
        local parts = {}
        for index = 1, math.min(#listings, 40) do
          local listing = listings[index]
          parts[#parts + 1] = listing.price .. "x" .. listing.count .. (listing.own and "*" or "")
        end
        AM.DebugLog.Log("ownauctions", "order: %s", table.concat(parts, " "))
      end
      states[entry.auctionId] = state
      changed = true
    end
  end
  if changed then
    AM.Events.Fire("OWN_AUCTIONS_CHANGED")
  end
  return changed
end

local function OnCommodityResults(itemId)
  local found = OnResults(function(entry)
    return entry.itemId == itemId and entry.commodity
  end, true, function()
    local listings, ownPrices = ReadCommodityListings(itemId)
    return listings, ownPrices, true
  end)
  if found and current and current.key:find("^" .. itemId .. ":") then
    Advance(current)
  end
end

local function OnItemResults(itemKey)
  local found = OnResults(function(entry)
    return entry.itemId == itemKey.itemID and entry.commodity == false
  end, false, function(entry)
    return ReadItemListings(itemKey, entry.itemKey.itemLevel or 0), nil, C_AuctionHouse.HasFullItemSearchResults(itemKey)
  end)
  if found and current and current.key:find("^" .. itemKey.itemID .. ":") then
    Advance(current)
  end
end

local events = CreateFrame("Frame")
events:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
events:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
events:RegisterEvent("OWNED_AUCTIONS_UPDATED")
events:RegisterEvent("AUCTION_HOUSE_CLOSED")
events:SetScript("OnEvent", function(_, event, arg)
  if event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
    OnCommodityResults(arg)
  elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
    OnItemResults(arg)
  elseif event == "OWNED_AUCTIONS_UPDATED" then
    AM.Events.Fire("OWN_AUCTIONS_CHANGED")
  elseif running then
    Finish()
  end
end)
