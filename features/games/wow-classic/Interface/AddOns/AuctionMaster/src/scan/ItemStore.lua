local addonName, AM = ...

-- Prices per item aggregated from the latest full scan, kept in the saved variables
-- (the faction object "items", keyed by itemDbKey, see AM.ItemDbKey) so that they survive a relog. Storing
-- every single auction instead would bloat the saved variables.
--
-- The faction object "marketPrices" (itemDbKey -> { price, priceAt, avgCount, avgCountAt } as an array, avgCountAt only if it differs from priceAt)
-- additionally holds a time-weighted market price per item and the time-weighted average
-- quantity listed per scan. Unlike "items", an entry here survives scans where the item
-- currently has no auctions, since it blends in rather than replaces: the price is kept, the
-- average count blends in a count of 0, so it falls for items that are rarely listed.
local ItemStore = {}
AM.ItemStore = ItemStore

-- Entries of "items" are positional arrays { lowPrice, count, stacks }: without the field names the saved
-- variables are about a quarter of the size and each entry needs half the memory.
local LOW, COUNT, STACKS = 1, 2, 3

-- Keys used to be the itemId (a number) and are now itemDbKeys (strings). A stored table is brought in line once
-- per session, on first access: a numeric key becomes the string of the itemId where that is still a valid key (most
-- items), and the data of items that need more than their itemId (equipment, battle pets) is removed, as it mixed
-- items that are not the same. Where the key rules change (ItemDbKey.RULES_REVISION), the string keys are checked once
-- more and just the ones that no longer fit are removed. Recognized by the shape of the keys, so it works from any
-- earlier version and does nothing on data that is in line already.
local function KeyRevisions()
  return AM.Database.GetFactionObject("itemDbKeyRevisions")
end

local function MigrateKeys(name, entries)
  local started = debugprofilestop()
  local revisions = KeyRevisions()
  local checkAll = revisions[name] ~= AM.ItemDbKey.RULES_REVISION
  local converted, removed, total = {}, {}, 0
  for key in pairs(entries) do
    total = total + 1
    if type(key) == "number" then
      local newKey = tostring(key)
      if AM.ItemDbKey.Matches(newKey) then
        converted[#converted + 1] = key
      else
        removed[#removed + 1] = key
      end
    elseif checkAll and not AM.ItemDbKey.Matches(key) then
      removed[#removed + 1] = key
    end
  end
  -- changed after the traversal, a table may not get new keys while it is walked
  for _, key in ipairs(removed) do
    entries[key] = nil
  end
  for _, key in ipairs(converted) do
    local newKey = tostring(key)
    if entries[newKey] == nil then
      entries[newKey] = entries[key]
    end
    entries[key] = nil
  end
  revisions[name] = AM.ItemDbKey.RULES_REVISION
  if #converted > 0 or #removed > 0 or checkAll then
    AM.DebugLog.Log("store", "keys of %s checked: %d keys, %d converted, %d removed, %.1f ms", name, total, #converted,
      #removed, debugprofilestop() - started)
  end
end

-- Entries used to be { lowPrice = , count = , stacks = }. Converts whatever of that is left, whichever
-- version of the data it comes from; entries already converted are not touched.
local migrated = {}

local function Items()
  local items = AM.Database.GetFactionObject("items")
  if not migrated[items] then
    migrated[items] = true
    for key, entry in pairs(items) do
      if entry.count or entry.stacks or entry.lowPrice then
        items[key] = { entry.lowPrice, entry.count or 0, entry.stacks or 0 }
      end
    end
    MigrateKeys("items", items)
  end
  return items
end

-- Entries of "marketPrices" are positional arrays { price, priceAt, avgCount, avgCountAt }, for the same
-- reason as the entries of "items". The price and the average count are kept to 6 significant digits, which
-- is far finer than any blend of a scan or search changes them.
-- AVG_COUNT_AT is nil while it equals PRICE_AT, which is the case unless a scan had no priced auction of the item.
local PRICE, PRICE_AT, AVG_COUNT, AVG_COUNT_AT = 1, 2, 3, 4

local function Round(value)
  return tonumber(("%.6g"):format(value))
end

-- Entries used to be { price = , priceAt = , avgCount = , avgCountAt = } (and, even earlier, updatedAt instead
-- of priceAt). Converts whatever of that is left, whichever version of the data it comes from.
local marketMigrated = {}

local function MarketPrices()
  local marketPrices = AM.Database.GetFactionObject("marketPrices")
  if not marketMigrated[marketPrices] then
    marketMigrated[marketPrices] = true
    for key, entry in pairs(marketPrices) do
      if entry.price or entry.priceAt or entry.updatedAt then
        marketPrices[key] = {
          entry.price and Round(entry.price), entry.priceAt or entry.updatedAt or 0,
          entry.avgCount and Round(entry.avgCount), entry.avgCountAt,
        }
      end
    end
    MigrateKeys("marketPrices", marketPrices)
  end
  return marketPrices
end

-- A stored market price left untouched for ROTATION_HOURS hours has ROTATION_WEIGHT of
-- its value overwritten by the newest scan's market price, so a single scan can't swing it but
-- weeks of stale data eventually get flushed out.
local ROTATION_HOURS = 14 * 24
local ROTATION_WEIGHT = 0.99

-- The market price is the price at which this percentage of the offered items are cheaper
-- or equal. Weighting by quantity and looking at the cheap end keeps a few absurdly priced
-- listings from dragging the value up, since they would never sell at that price. The
-- percentage is set per group of item classes, as e.g. materials are listed far more
-- numerously and spread out than gear.
ItemStore.MIN_PERCENT = 1
ItemStore.MAX_PERCENT = 50

-- The groups in the order of the options. An item belongs to the first group that lists its
-- class (Enum.ItemClass name), else to the group without classes.
ItemStore.GROUPS = {
  { id = "equipment", percent = 25, classes = { "Weapon", "Armor" } },
  { id = "materials", percent = 15, classes = { "Tradegoods", "Reagent" } },
  { id = "consumables", percent = 15, classes = { "Consumable", "Gem", "ItemEnhancement" } },
  { id = "other", percent = 25 },
}

local GROUP_OF_CLASS = {}
local FALLBACK_GROUP
for _, group in ipairs(ItemStore.GROUPS) do
  FALLBACK_GROUP = FALLBACK_GROUP or (not group.classes and group) or nil
  for _, name in ipairs(group.classes or {}) do
    local classId = Enum.ItemClass[name]
    if classId then
      GROUP_OF_CLASS[classId] = group
    end
  end
end

-- The class is part of the item's static data, so it is available without the item being
-- loaded by the client.
local function GroupOf(itemDbKey)
  local classId = select(6, C_Item.GetItemInfoInstant(AM.ItemDbKey.GetItemId(itemDbKey)))
  return GROUP_OF_CLASS[classId] or FALLBACK_GROUP
end

local function Settings()
  return AM.Database.GetGlobalObject("marketSettings")
end

-- group is an entry of ItemStore.GROUPS. Returns its configured percentage (1-50).
function ItemStore.GetPercent(group)
  local value = tonumber(Settings()[group.id]) or group.percent
  return math.max(ItemStore.MIN_PERCENT, math.min(ItemStore.MAX_PERCENT, value))
end

function ItemStore.SetPercent(group, value)
  Settings()[group.id] = math.max(ItemStore.MIN_PERCENT, math.min(ItemStore.MAX_PERCENT, math.floor(value)))
end

-- Two more numbers in the same settings, each { default, min, max }: how many minutes old auction data
-- still counts as current (RecipeCost uses the lowest price then, else the market price), and the average
-- quantity listed per scan below which an item counts as rarely listed (RecipeList).
ItemStore.NUMBERS = {
  freshMinutes = { 60, 1, 999 },
  rareCount = { 5, 1, 99 },
}

function ItemStore.GetNumber(key)
  local default, min, max = unpack(ItemStore.NUMBERS[key])
  return math.max(min, math.min(max, tonumber(Settings()[key]) or default))
end

function ItemStore.SetNumber(key, value)
  local _, min, max = unpack(ItemStore.NUMBERS[key])
  Settings()[key] = math.max(min, math.min(max, math.floor(value)))
  AM.Events.Fire("PRICES_CHANGED")
end

-- Back to the default percentage of every group and the default numbers. Only clears AuctionMaster's own
-- market settings.
function ItemStore.ResetPercents()
  wipe(Settings())
  AM.Events.Fire("PRICES_CHANGED")
end

-- Forgets all gathered market prices of the current faction. Only clears AuctionMaster's own faction object
-- "marketPrices"; the prices of the latest scan ("items") stay and feed new market prices from the next scan.
function ItemStore.ResetMarketPrices()
  wipe(MarketPrices())
  AM.Events.Fire("PRICES_CHANGED")
end

-- entries are { price, count } sorted ascending by price. Returns nil if empty.
local function MarketQuantile(entries, percent)
  local total = 0
  for _, entry in ipairs(entries) do
    total = total + entry.count
  end
  local target = total * percent / 100
  local seen = 0
  for _, entry in ipairs(entries) do
    seen = seen + entry.count
    if seen >= target then
      return entry.price
    end
  end
  return nil
end

local function Floor(value)
  return value and math.floor(value)
end

-- All prices are per single item in copper. Auctions without a price are ignored. Returns
-- the stats to store ({ lowPrice, count, stacks } as an array, lowPrice is nil if no auction has a price, count is
-- the total quantity of items in the auctions with a price, stacks the number of these auctions) and this scan's market price of the item, which is
-- only fed into the blended market price and not stored with the scan.
local function Aggregate(auctions)
  local entries = {}
  for _, auction in ipairs(auctions) do
    if auction.count > 0 and auction.price > 0 then
      entries[#entries + 1] = { price = auction.price / auction.count, count = auction.count }
    end
  end
  table.sort(entries, function(a, b) return a.price < b.price end)
  local percent = ItemStore.GetPercent(GroupOf(auctions[1].itemDbKey))

  local quantity = 0
  for _, entry in ipairs(entries) do
    quantity = quantity + entry.count
  end
  local stats = { entries[1] and Floor(entries[1].price), quantity, #entries }
  return stats, Floor(MarketQuantile(entries, percent))
end

-- Blends current into the stored value old, last blended at oldAt, as of now, per the
-- exponential rotation described above. The result is deliberately not rounded.
local function Blend(old, oldAt, current, now)
  local hoursPassed = (now - oldAt) / 3600
  local retention = (1 - ROTATION_WEIGHT) ^ (hoursPassed / ROTATION_HOURS)
  local weight = math.min(1 - retention, 1.0)
  return current * weight + old * (1 - weight)
end

-- Blends this scan's market price and total listed quantity into entry (nil if the item has no
-- entry yet) and returns the entry. currentPrice is nil if no auction has a price: the stored price
-- then stays. An entry without avgCount (stored before it existed) starts at the current quantity.
local function BlendMarketPrice(entry, currentPrice, currentCount, now)
  if not entry then
    return { Round(currentPrice), now, currentCount }
  end

  local avgCountAt = entry[AVG_COUNT_AT] or entry[PRICE_AT]
  entry[AVG_COUNT] = entry[AVG_COUNT] and Round(Blend(entry[AVG_COUNT], avgCountAt, currentCount, now))
    or currentCount
  if currentPrice then
    entry[PRICE] = Round(Blend(entry[PRICE], entry[PRICE_AT], currentPrice, now))
    entry[PRICE_AT] = now
    entry[AVG_COUNT_AT] = nil
  else
    entry[AVG_COUNT_AT] = now
  end
  return entry
end

-- Replaces the stored prices with the result of a new scan, given as a list of auctions
-- ({ itemDbKey, count, price }), and blends the market prices with it.
function ItemStore.Replace(auctions)
  local byItem = {}
  for _, auction in ipairs(auctions) do
    local list = byItem[auction.itemDbKey]
    if not list then
      list = {}
      byItem[auction.itemDbKey] = list
    end
    list[#list + 1] = auction
  end

  local now = time()
  local marketPrices = MarketPrices()
  local items = Items()
  wipe(items)
  for itemDbKey, list in pairs(byItem) do
    local stats, scanMarketPrice = Aggregate(list)
    items[itemDbKey] = stats
    if scanMarketPrice or marketPrices[itemDbKey] then
      marketPrices[itemDbKey] = BlendMarketPrice(marketPrices[itemDbKey], scanMarketPrice, stats[COUNT], now)
    end
  end
  -- Items not listed in this scan keep their price, but their average count falls.
  for itemDbKey, entry in pairs(marketPrices) do
    if not byItem[itemDbKey] then
      BlendMarketPrice(entry, nil, 0, now)
    end
  end
  if AM.DebugLog.IsEnabled() then
    local itemCount = 0
    for _ in pairs(byItem) do
      itemCount = itemCount + 1
    end
    AM.DebugLog.Log("store", "Replace %d auctions of %d items", #auctions, itemCount)
  end
  AM.Events.Fire("PRICES_CHANGED")
end

-- Replaces the stats of a single item (one itemDbKey) with the result of a search for exactly that item (all its
-- auctions, given as for Replace) and blends its market price. Blending by the time passed since
-- the last update keeps frequent searches from outweighing the other data.
function ItemStore.UpdateItem(itemDbKey, auctions)
  assert(type(itemDbKey) == "string", "ItemStore.UpdateItem needs an itemDbKey")
  if #auctions == 0 then
    return
  end
  local debug = AM.DebugLog.IsEnabled()
  local oldLow, oldCount, oldMarket
  if debug then
    oldLow, oldCount = ItemStore.Get(itemDbKey)
    oldMarket = ItemStore.GetMarketPrice(itemDbKey)
  end
  local stats, searchMarketPrice = Aggregate(auctions)
  Items()[itemDbKey] = stats
  local marketPrices = MarketPrices()
  if searchMarketPrice or marketPrices[itemDbKey] then
    marketPrices[itemDbKey] = BlendMarketPrice(marketPrices[itemDbKey], searchMarketPrice, stats[COUNT], time())
  end
  if debug then
    local newMarket = ItemStore.GetMarketPrice(itemDbKey)
    AM.DebugLog.Log("store", "UpdateItem %s: %d auctions, low %s -> %s, count %s -> %s, search market %s, market %s -> %s",
      itemDbKey, #auctions, oldLow, stats[LOW], oldCount, stats[COUNT], searchMarketPrice,
      oldMarket and oldMarket.price, newMarket and newMarket.price)
  end
  AM.Events.Fire("PRICES_CHANGED")
end

-- Removes market prices that haven't been updated for more than ROTATION_HOURS, i.e.
-- items that have had no priced auction in a full rotation, so stale entries for items
-- no longer traded don't linger in the saved variables forever. Called once on addon
-- load rather than after every scan, since a session never runs long enough for entries
-- to go stale within it.
function ItemStore.PruneStaleMarketPrices()
  local marketPrices = MarketPrices()
  local now = time()
  for itemDbKey, entry in pairs(marketPrices) do
    if (now - entry[PRICE_AT]) / 3600 > ROTATION_HOURS then
      marketPrices[itemDbKey] = nil
    end
  end
end

-- Returns lowPrice (nil if no auction has a price), count, stacks for the item, nothing if it was not
-- listed in the latest scan.
function ItemStore.Get(itemDbKey)
  assert(type(itemDbKey) == "string", "ItemStore.Get needs an itemDbKey")
  local stats = Items()[itemDbKey]
  if stats then
    return stats[LOW], stats[COUNT], stats[STACKS]
  end
end

-- True once a scan of this faction's auction house has been stored.
function ItemStore.HasScan()
  return next(Items()) ~= nil
end

-- Calls callback(itemDbKey, lowPrice, count, stacks) for every item of the latest scan.
function ItemStore.ForEach(callback)
  for itemDbKey, stats in pairs(Items()) do
    callback(itemDbKey, stats[LOW], stats[COUNT], stats[STACKS])
  end
end

-- Returns { price, priceAt, avgCount }, the time-weighted market price for the item, nil if it
-- has never had a priced auction. Unlike ItemStore.Get, this persists across scans where
-- the item currently has no auctions. The price is a whole number of copper; internally it is
-- stored unrounded so that many tiny blends (frequent searches) don't get lost to rounding.
-- avgCount is the time-weighted average quantity listed per scan, rounded to one decimal.
function ItemStore.GetMarketPrice(itemDbKey)
  assert(type(itemDbKey) == "string", "ItemStore.GetMarketPrice needs an itemDbKey")
  local entry = MarketPrices()[itemDbKey]
  if not entry then
    return nil
  end
  return {
    price = Floor(entry[PRICE]),
    priceAt = entry[PRICE_AT],
    avgCount = entry[AVG_COUNT] and math.floor(entry[AVG_COUNT] * 10 + 0.5) / 10,
  }
end
