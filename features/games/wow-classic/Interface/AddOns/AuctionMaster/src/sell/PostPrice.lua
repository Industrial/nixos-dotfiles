local addonName, AM = ...

-- The game fills the price of its sell form with the cheapest auction. Where the Sell tab advises to auction the
-- item, the form gets the price we would post at instead (AM.ItemSearch.PostPrice, which skips the few cheapest
-- listings; the market price plus the margin where nobody lists the item). The listings of the form itself are used,
-- so this agrees with them even where the panel's last search is older. A price or an auction the player chose is left
-- alone, as is any item whose hint is not "Auction": there is no price we stand behind then.

local installed = false

-- Selects the row of the list (scrolled into view) for which matches(row) is true. The game's own selection sets the
-- price of the form and highlights the row.
local function Select(list, matches)
  -- Fresh results reach the scroll box on the list's next update only, and scrolling fails before. Doing the list's
  -- own refresh now (what its next update would do) makes waiting unnecessary.
  if not list.ScrollBox:HasDataProvider() then
    list:RefreshScrollFrame()
  end
  if not list.ScrollBox:HasDataProvider() then
    return
  end
  list:SetSelectedEntryByCondition(matches, true)
end

-- No listing at all, and the price is still the one the game put there: the form gets the price for no competition.
-- Only once the search is complete, an empty result while the game restarts a search says nothing.
local function SetNoCompetitionPrice(frame, itemDbKey, item, complete)
  if not complete or frame.PriceInput:GetAmount() ~= frame:GetDefaultPrice() then
    return
  end
  local price = AM.SellPanel.NoCompetitionPrice(itemDbKey)
  local advice = price and AM.SellPanel.Advise(itemDbKey, item, price)
  AM.DebugLog.Log("postprice", "%s: no listings, no-competition price %s, advice %s", itemDbKey, price, advice)
  if advice == "ah" then
    -- the server refuses some prices with copper, whole silver always works
    frame.PriceInput:SetAmount(math.max(100, math.floor(price / 100 + 0.5) * 100))
  end
end

-- listed are the { price, count } of the form's listings. Returns the price to select, nil if nothing is to be changed.
local function PriceToSelect(frame, itemDbKey, item, listed)
  local price = AM.ItemSearch.PostPrice(listed)
  -- only where the game picked the price from the list itself, and not yet the one we want
  if not price or not frame:GetSearchResultPrice() or price == frame:GetSearchResultPrice() then
    return nil
  end
  local advice = AM.SellPanel.Advise(itemDbKey, item, price)
  AM.DebugLog.Log("postprice", "%s: post price %s, game selected %s, advice %s", itemDbKey, price,
    frame:GetSearchResultPrice(), advice)
  return advice == "ah" and price or nil
end

-- Where the game does not fill the price itself (ShouldAutoPopulatePrice is false, nothing gets selected), the row at
-- our price is selected, as long as the player has not typed a price. matches(row) finds the row for a price.
local function SelectOwnPrice(frame, list, itemDbKey, item, listed, matches)
  local price = AM.ItemSearch.PostPrice(listed)
  if price and frame.PriceInput:GetAmount() == frame:GetDefaultPrice() and AM.SellPanel.Advise(itemDbKey, item, price) == "ah" then
    Select(list, function(row)
      return matches(row, price)
    end)
  end
end

local function UpdateCommodities(frame)
  local item = frame:GetItem()
  if not (item and item:IsValid()) then
    return
  end
  local itemId = C_Item.GetItemID(item)
  -- commodities are plain items
  local itemDbKey = AM.ItemDbKey.ForItem(itemId)
  if not itemDbKey then
    return
  end
  local listed = {}
  for index = 1, C_AuctionHouse.GetNumCommoditySearchResults(itemId) do
    local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemId, index)
    if result and result.quantity > 0 then
      listed[#listed + 1] = { price = result.unitPrice, count = result.quantity }
    end
  end
  if #listed == 0 then
    SetNoCompetitionPrice(frame, itemDbKey, item, C_AuctionHouse.HasFullCommoditySearchResults(itemId))
    return
  end
  if not C_AuctionHouse.ShouldAutoPopulatePrice() then
    SelectOwnPrice(frame, frame:GetCommoditiesSellList(), itemDbKey, item, listed, function(row, price)
      return row.unitPrice == price
    end)
    return
  end
  local price = PriceToSelect(frame, itemDbKey, item, listed)
  if price then
    Select(frame:GetCommoditiesSellList(), function(row)
      return row.unitPrice == price
    end)
  end
end

local function UpdateItems(frame)
  local item, key = frame:GetItem(), frame.listDisplayedItemKey
  if not (item and item:IsValid() and key) then
    return
  end
  -- Of the item's own key only (equipment of another level is another item), whatever the game lists. Not
  -- known while the item data is not loaded: nothing is changed then.
  local itemDbKey = AM.ItemDbKey.FromLocation(item)
  if not itemDbKey then
    return
  end
  local function IsSameItem(ahItemKey)
    return ahItemKey ~= nil and AM.ItemDbKey.FromAhItemKey(ahItemKey) == itemDbKey
  end
  local total, listed = C_AuctionHouse.GetNumItemSearchResults(key), {}
  for index = 1, total do
    local result = C_AuctionHouse.GetItemSearchResultInfo(key, index)
    local listing = result and IsSameItem(result.itemKey) and AM.ItemSearch.GetItemListing(result)
    if listing then
      listed[#listed + 1] = listing
    end
  end
  if #listed == 0 then
    -- no auction of this item, however many of other levels the game lists
    SetNoCompetitionPrice(frame, itemDbKey, item, C_AuctionHouse.HasFullItemSearchResults(key))
    return
  end
  if not C_AuctionHouse.ShouldAutoPopulatePrice() then
    SelectOwnPrice(frame, frame:GetItemSellList(), itemDbKey, item, listed, function(row, price)
      return row.buyoutAmount == price and IsSameItem(row.itemKey)
    end)
    return
  end
  local price = PriceToSelect(frame, itemDbKey, item, listed)
  if price then
    Select(frame:GetItemSellList(), function(row)
      return row.buyoutAmount == price and IsSameItem(row.itemKey)
    end)
  end
end

-- The auction house is load on demand: hooked the first time it opens.
local function Install()
  local house = AuctionHouseFrame
  if installed or not house then
    return
  end
  local commodities, items = house.CommoditiesSellFrame, house.ItemSellFrame
  if not (commodities and items) then
    return
  end
  installed = true
  hooksecurefunc(commodities, "UpdatePriceSelection", UpdateCommodities)
  hooksecurefunc(items, "UpdatePriceSelection", UpdateItems)
end

local events = CreateFrame("Frame")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:SetScript("OnEvent", Install)
