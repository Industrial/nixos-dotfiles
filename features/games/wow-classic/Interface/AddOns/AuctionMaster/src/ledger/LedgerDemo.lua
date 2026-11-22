local addonName, AM = ...

-- Demo mode of the ledger for recordings (hidden developer command "/am demo on|off"): replaces the ledger of the
-- current auction house with 30 days of made-up trades of a few items, priced around their current auctions and market
-- price, and puts the real ledger back when turned off (Ledger.StartDemo / StopDemo). Never touches market data.
AM.LedgerDemo = {}
local LedgerDemo = AM.LedgerDemo

-- itemId -> { min units per auction trade, max, min units per vendor purchase, max }
local ITEMS = {
  [4306] = { 20, 200, 0, 0 }, -- Silk Cloth
  [4338] = { 20, 200, 0, 0 }, -- Mageweave Cloth
  [4291] = { 0, 0, 5, 20 }, -- Silken Thread
  [8343] = { 0, 0, 5, 20 }, -- Heavy Silken Thread
  [4625] = { 5, 20, 0, 0 }, -- Firebloom
  [3858] = { 20, 200, 0, 0 }, -- Mithril Ore
}

local HOUR = 3600
local DAY = 24 * HOUR
-- the demo stays within the fewest days the ledger keeps every event (Ledger.KEEP_DAYS), so nothing is combined
local SPAN = 29 * DAY
-- the game's cut of a sale and the deposit of a 12 hour auction (share of the merchant's sell price)
local CUT = 0.05
local DEPOSIT_SHARE = 0.15
-- unit prices relative to the item's price: purchases tend to be cheaper than sales
local BUY_LOW, BUY_HIGH = 0.7, 1.0
local SELL_LOW, SELL_HIGH = 0.95, 1.3

local function Between(low, high)
  return low + math.random() * (high - low)
end

local function SellPrice(itemId)
  return select(11, C_Item.GetItemInfo(itemId))
end

-- The unit price the item trades at now: its market price, else its lowest auction; nil if neither is known.
local function AuctionPrice(key)
  local market = AM.ItemStore.GetMarketPrice(key)
  if market and market.price > 0 then
    return market.price
  end
  local low = AM.ItemStore.Get(key)
  return low
end

-- The unit price a merchant sells the item at: as seen at a merchant, else four times its sell price.
local function VendorPrice(itemId)
  local price = AM.MerchantScanner.GetPrice(itemId)
  if price then
    return price
  end
  local sellPrice = SellPrice(itemId)
  return sellPrice and sellPrice > 0 and sellPrice * 4 or nil
end

-- Auction purchases and sales every 6 to 30 hours; a sale only of what was bought before, so every sale has a cost.
local function AddAuctionTrades(trades, key, itemId, minCount, maxCount, now)
  local base = AuctionPrice(key)
  if not base then
    AM.DebugLog.Log("ledger", "demo: no price for %s, left out", key)
    return
  end
  local sellPrice = SellPrice(itemId) or 0
  local stock = 0
  local at = now - SPAN + math.random(0, 12 * HOUR)
  while at < now - HOUR do
    if stock < minCount or math.random() < 0.5 then
      local count = math.random(minCount, maxCount)
      trades[#trades + 1] = { at = at, type = AM.Ledger.BOUGHT, item = key, count = count,
        price = math.floor(base * Between(BUY_LOW, BUY_HIGH) * count) }
      stock = stock + count
    else
      local count = math.random(minCount, math.min(maxCount, stock))
      local price = math.floor(base * Between(SELL_LOW, SELL_HIGH) * count)
      trades[#trades + 1] = { at = at, type = AM.Ledger.SOLD, item = key, count = count, price = price,
        deposit = math.floor(sellPrice * count * DEPOSIT_SHARE), fee = math.floor(price * CUT),
        createdAt = at - math.random(HOUR, 11 * HOUR) }
      stock = stock - count
    end
    at = at + math.random(6 * HOUR, 30 * HOUR)
  end
end

-- Merchant purchases every 2 to 5 days.
local function AddVendorTrades(trades, key, itemId, minCount, maxCount, now)
  local unit = VendorPrice(itemId)
  if not unit then
    AM.DebugLog.Log("ledger", "demo: no vendor price for %s, left out", key)
    return
  end
  local at = now - SPAN + math.random(0, DAY)
  while at < now - HOUR do
    local count = math.random(minCount, maxCount)
    trades[#trades + 1] = { at = at, type = AM.Ledger.VENDOR_BOUGHT, item = key, count = count, price = unit * count }
    at = at + math.random(2 * DAY, 5 * DAY)
  end
end

local function Build()
  local now = time()
  local trades = {}
  for itemId, spec in pairs(ITEMS) do
    local key = AM.ItemDbKey.ForItem(itemId)
    if key then
      if spec[2] > 0 then
        AddAuctionTrades(trades, key, itemId, spec[1], spec[2], now)
      end
      if spec[4] > 0 then
        AddVendorTrades(trades, key, itemId, spec[3], spec[4], now)
      end
    end
  end
  AM.Ledger.StartDemo(UnitGUID("player"), trades)
end

-- Shows the demo ledger (built anew if it is shown already), once the data of every demo item is loaded (sell prices).
function LedgerDemo.Start()
  local waiting = 0
  for itemId in pairs(ITEMS) do
    waiting = waiting + 1
  end
  for itemId in pairs(ITEMS) do
    Item:CreateFromItemID(itemId):ContinueOnItemLoad(function()
      waiting = waiting - 1
      if waiting == 0 then
        Build()
      end
    end)
  end
end

-- Puts the real ledger back.
function LedgerDemo.Stop()
  AM.Ledger.StopDemo()
end
