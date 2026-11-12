local addonName, AM = ...

-- Keeps the stats of the latest scan up to date with the searches done in the auction house
-- (browsing an item, selling it): the results are the current auctions of that item.
-- It also works out what the item can be sold for right now (GetSellPrice), kept for this session only.
AM.ItemSearch = {}
local ItemSearch = AM.ItemSearch

-- How long a search counts as current for what to sell an item for (seconds).
ItemSearch.CACHE_SECONDS = 10 * 60

local sellPrices = {} -- itemDbKey -> { price, time }

-- The price to post at, from the listings ({ price, count } per listing, price per item, count 1 if absent, any
-- order): the cheapest items are skipped if there are at most 3 of them (never all) and the next listing costs more
-- than 20% above them. A few cheap items far below the rest are a mistake or about to be bought, many cheap ones (one
-- big stack counts as many) or a small gap are the market. Nil without listings.
function ItemSearch.PostPrice(listed)
  table.sort(listed, function(a, b) return a.price < b.price end)
  local skipped = 0
  for index = 1, #listed - 1 do
    skipped = skipped + (listed[index].count or 1)
    if skipped > 3 then
      break
    end
    if listed[index + 1].price > listed[index].price * 1.2 then
      return listed[index + 1].price
    end
  end
  return listed[1] and listed[1].price
end

-- The listing { price, count } of a result of an item search for PostPrice, nil without a buyout price. The quantity
-- counts: a listing of 100 at one price is the market, not one cheap item to skip.
function ItemSearch.GetItemListing(result)
  local price = result and result.buyoutAmount
  if not (price and price > 0) then
    return nil
  end
  return { price = price, count = math.max(result.quantity or 1, 1) }
end

-- Called before ItemStore.UpdateItem, whose PRICES_CHANGED event makes the panels read it.
local function StoreSellPrice(itemDbKey, auctions)
  local price = ItemSearch.PostPrice(auctions)
  if price then
    sellPrices[itemDbKey] = { price, time() }
  end
  if AM.DebugLog.IsEnabled() then
    -- PostPrice sorted the listings: the cheapest few as price x quantity show why it chose its price
    local cheapest = {}
    for index = 1, math.min(#auctions, 4) do
      cheapest[index] = auctions[index].price .. "x" .. (auctions[index].count or 1)
    end
    AM.DebugLog.Log("search", "post price %s: %s from %d listings, cheapest %s", itemDbKey, price, #auctions,
      table.concat(cheapest, " "))
  end
end

-- The game fires the event of a search two or three times within a second for one answer. A result identical to the one
-- processed last for that item, seen within DUPLICATE_SECONDS of it, is that same answer again and is ignored: storing
-- it again would change nothing but make every view redraw. A different result, or the same one later (the stored
-- market price then moves on with the time passed), is processed. What is compared is everything the processing
-- depends on, so nothing that could make a difference is ever skipped.
local DUPLICATE_SECONDS = 5
local processed = {} -- itemDbKey -> { fingerprint, GetTime() } of the result processed last

-- True if this is a repeat of the result just processed. Otherwise remembers it as the one processed last.
local function IsRepeat(itemDbKey, fingerprint)
  local now = GetTime()
  local last = processed[itemDbKey]
  if last and last[1] == fingerprint and now - last[2] < DUPLICATE_SECONDS then
    AM.DebugLog.Log("search", "repeat of the last result of %s ignored", itemDbKey)
    return true
  end
  -- measured from the result processed, not from the repeats, so they cannot keep it alive
  processed[itemDbKey] = { fingerprint, now }
  return false
end

-- What one item can be sold for now (per item in copper), nil if no search of it was seen within CACHE_SECONDS.
function ItemSearch.GetSellPrice(itemDbKey)
  local entry = sellPrices[itemDbKey]
  if entry and time() - entry[2] <= ItemSearch.CACHE_SECONDS then
    return entry[1]
  end
end

-- An answer without any auction says nothing while the game still waits for the rest of it (it fires the event with no
-- results while it restarts a search). The game shows "no items found" when the list is empty and the results are full
-- (HasFull...SearchResults), and so do we. Nothing is stored for it, it only says that the search came back empty.
local function NoteEmpty(itemId, hasFullResults)
  if hasFullResults then
    AM.Events.Fire("ITEM_SEARCH_EMPTY", itemId)
  end
end

local function OnCommodityResults(itemId)
  -- commodities are never equipment or pets: the itemId is the key
  local itemDbKey = AM.ItemDbKey.ForItem(itemId)
  if not itemDbKey then
    return
  end
  local auctions, listed, parts = {}, {}, {}
  for index = 1, C_AuctionHouse.GetNumCommoditySearchResults(itemId) do
    local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemId, index)
    if result and result.quantity > 0 then
      auctions[#auctions + 1] = {
        itemDbKey = itemDbKey,
        count = result.quantity,
        price = result.unitPrice * result.quantity,
      }
      listed[#listed + 1] = { price = result.unitPrice, count = result.quantity }
      parts[#parts + 1] = result.unitPrice .. "x" .. result.quantity
    end
  end
  if #auctions == 0 then
    NoteEmpty(itemId, C_AuctionHouse.HasFullCommoditySearchResults(itemId))
  end
  if IsRepeat(itemDbKey, table.concat(parts, ",")) then
    return
  end
  AM.DebugLog.Log("search", "commodity results %s: %d listings", itemDbKey, #listed)
  -- Blizzard fires the event with no results while it restarts the search, which says nothing.
  StoreSellPrice(itemDbKey, listed)
  AM.ItemStore.UpdateItem(itemDbKey, auctions)
  if #auctions > 0 then
    AM.Events.Fire("ITEM_SEARCHED", itemDbKey, itemId)
  end
end

-- The results of a search are the current auctions of the item: stored like a scan of that one item. A search can list
-- several variants of an item (the game's sell form searches equipment of every level), each result has the item key of
-- its own, so what is stored is the auctions of every itemDbKey found, not of the item.
local function OnItemResults(searchedKey)
  local groups, order = {}, {}
  local skipped = 0
  for index = 1, C_AuctionHouse.GetNumItemSearchResults(searchedKey) do
    local result = C_AuctionHouse.GetItemSearchResultInfo(searchedKey, index)
    local price = result and result.buyoutAmount
    if price and price > 0 then
      local itemDbKey = AM.ItemDbKey.FromAhItemKey(result.itemKey)
      if itemDbKey then
        local group = groups[itemDbKey]
        if not group then
          group = { auctions = {}, parts = {} }
          groups[itemDbKey] = group
          order[#order + 1] = itemDbKey
        end
        group.auctions[#group.auctions + 1] = { itemDbKey = itemDbKey, count = 1, price = price,
          listing = ItemSearch.GetItemListing(result) }
        group.parts[#group.parts + 1] = price .. "x" .. (result.quantity or 1)
      else
        skipped = skipped + 1
      end
    end
  end
  if skipped > 0 then
    AM.DebugLog.Log("search", "item results %d: %d auctions without a key left out", searchedKey.itemID, skipped)
  end
  if #order == 0 and skipped == 0 then
    NoteEmpty(searchedKey.itemID, C_AuctionHouse.HasFullItemSearchResults(searchedKey))
  end
  for _, itemDbKey in ipairs(order) do
    local group = groups[itemDbKey]
    if not IsRepeat(itemDbKey, table.concat(group.parts, ",")) then
      AM.DebugLog.Log("search", "item results %s: %d auctions", itemDbKey, #group.auctions)
      local listed = {}
      for _, auction in ipairs(group.auctions) do
        listed[#listed + 1] = auction.listing
      end
      StoreSellPrice(itemDbKey, listed)
      AM.ItemStore.UpdateItem(itemDbKey, group.auctions)
      AM.Events.Fire("ITEM_SEARCHED", itemDbKey, searchedKey.itemID)
    end
  end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
frame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
frame:SetScript("OnEvent", function(_, event, arg)
  if event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
    OnCommodityResults(arg)
  else
    OnItemResults(arg)
  end
end)
