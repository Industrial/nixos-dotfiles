local addonName, AM = ...

-- Double-clicking a row of the sell list (the competing auctions) or of the list of an item on the Auctions tab
-- jumps to Blizzard's own buy tab for that item. For commodities the clicked row is selected there, so the purchase
-- covers every auction up to it; for a row of the player's own auction, every auction cheaper than it.

AM.DirectBuy = {}
local DirectBuy = AM.DirectBuy

local hooked = false

-- The last row of the buy list that has the price of the clicked row or less.
local function LastRowIndex(itemID, unitPrice)
  local last
  for index = 1, C_AuctionHouse.GetNumCommoditySearchResults(itemID) do
    local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, index)
    if result and result.unitPrice <= unitPrice then
      last = index
    end
  end
  return last
end

local pending -- { itemID, unitPrice } waiting for the buy tab's search results

local searchEvents = CreateFrame("Frame")
searchEvents:SetScript("OnEvent", function(self, _, itemID)
  if not pending or pending.itemID ~= itemID then
    return
  end
  -- The event also fires while Blizzard restarts the search with no results yet, wait for the real ones.
  if C_AuctionHouse.GetNumCommoditySearchResults(itemID) == 0 then
    return
  end
  self:UnregisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
  local wanted = pending
  pending = nil
  -- Blizzard resets the selection while handling this same event, so select our row afterwards, by
  -- clicking it like a user would, which makes Blizzard select the range up to it.
  C_Timer.After(0, function()
    local index = LastRowIndex(wanted.itemID, wanted.unitPrice)
    local scrollBox = AuctionHouseFrame.CommoditiesBuyFrame.ItemList.ScrollBox
    if not index or not scrollBox:HasView() then
      return
    end
    scrollBox:ScrollToElementDataIndex(index)
    local line = scrollBox:FindFrame(scrollBox:FindElementData(index))
    if line then
      line:Click()
    end
  end)
end)

local function Open(rowData)
  local itemKey = rowData.itemKey or (rowData.itemID and C_AuctionHouse.MakeItemKey(rowData.itemID))
  if not itemKey then
    return
  end
  if rowData.unitPrice then
    -- the player's own row cannot be bought: up to the auction before it
    local unitPrice = rowData.containsOwnerItem and rowData.unitPrice - 1 or rowData.unitPrice
    pending = { itemID = itemKey.itemID, unitPrice = unitPrice }
    searchEvents:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
  end
  -- SelectBrowseResult only swaps the shown content, the tab itself has to be switched first.
  local buyTab = AuctionHouseFrame.BuyTab or AuctionHouseFrameBuyTab
  if buyTab then
    buyTab:Click()
  end
  -- Blizzard shows minPrice until the buy tab has loaded its own results.
  local minPrice = rowData.unitPrice or rowData.buyoutAmount or rowData.bidAmount or 0
  AuctionHouseFrame:SelectBrowseResult({ itemKey = itemKey, minPrice = minPrice })
end

local function HookSellList(list)
  if not list then
    return
  end
  -- Rows are recycled and created lazily, so hook each one the first time the mouse is over it.
  -- Hovering always happens before a double-click, which is also when its current data is remembered.
  hooksecurefunc(list, "OnEnterListLine", function(_, line, rowData)
    line.amRowData = rowData
    if not line.amDoubleClickHooked then
      line.amDoubleClickHooked = true
      line:HookScript("OnDoubleClick", function(self)
        if self.amRowData then
          Open(self.amRowData)
        end
      end)
    end
  end)
end

-- The auction house UI is load on demand, so the frame may not exist yet.
local function Hook()
  if hooked or not AuctionHouseFrame then
    return
  end
  hooked = true
  HookSellList(AuctionHouseFrame.CommoditiesSellList)
  HookSellList(AuctionHouseFrame.ItemSellList)
  local auctions = AuctionHouseFrame.AuctionsFrame
  if auctions then
    HookSellList(auctions.CommoditiesList)
    HookSellList(auctions.ItemList)
  end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("AUCTION_HOUSE_SHOW")
loader:SetScript("OnEvent", function(self)
  Hook()
  if hooked then
    self:UnregisterAllEvents()
  end
end)
