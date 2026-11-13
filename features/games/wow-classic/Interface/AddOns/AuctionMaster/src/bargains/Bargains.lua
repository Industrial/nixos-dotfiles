local addonName, AM = ...
local L = AM.L

-- Bargains: what the player is looking for at a good price. A rule is either a specific item, which is found by
-- searching it in the auction house (the searches of ItemSearch, from the Bargains panel or anywhere else) or by a full
-- scan, or a filter
-- (category, levels, quality), which is matched against every auction of a full scan. The rules are kept in the global
-- object "bargains"; what was found is kept in the faction object "bargainHits" so that it survives until the next scan:
--   filters  ruleId -> list of { itemId, price, count }, the cheapest items that matched (price per item)
--   scannedAt  time of the scan the filter hits are from
--   items    ruleId -> { low, searchedAt }, the lowest price per item when the item was searched last
-- This module only reads the prices, it never changes ItemStore.
--
-- A rule is a table with named fields (there are few of them):
--   id, type ("item" or "filter"), active
--   item:   itemId, and the maximum price either as maxPrice (copper per item) or as percent of the market price
--   filter: maxPrice, classId, subClassId (nil: any), minItemLevel, maxItemLevel, minRequiredLevel, maxRequiredLevel,
--           minQuality (nil: any)
AM.Bargains = {}
local Bargains = AM.Bargains

-- Most items of one filter that are kept: the cheapest ones.
Bargains.MAX_HITS = 50
-- Most items of one filter that are shown as left out (they passed the price and the category only): the cheapest.
Bargains.MAX_LEFT_OUT = 20
-- Most rules per type. Every item rule is one search query of a bargain search (a second or more each, throttled by the
-- server), every filter is checked against every auction of a full scan and keeps its own hits.
Bargains.MAX_ITEM_RULES = 50
Bargains.MAX_FILTER_RULES = 20
-- How long what was found counts: prices change quickly, and after this time a new full scan is possible anyway.
Bargains.MAX_AGE = 15 * 60
-- How long a full scan waits for the client to load the data of items (quality, levels) before the rest is dropped.
local LOAD_SECONDS = 10
local CHECK_SECONDS = 0.5
-- Items per filter that the debug log names as left out (by quality or level), the cheapest ones.
local REJECTED_LOGGED = 60

local function Data()
  local data = AM.Database.GetGlobalObject("bargains")
  data.rules = data.rules or {}
  data.nextId = data.nextId or 1
  return data
end

local function Hits()
  local hits = AM.Database.GetFactionObject("bargainHits")
  hits.filters = hits.filters or {}
  hits.items = hits.items or {}
  hits.leftOut = hits.leftOut or {}
  return hits
end

-- Rules ---------------------------------------------------------------------------------------------

-- The rules of a type ("item" or "filter"), in the order they were made.
function Bargains.GetRules(ruleType)
  local rules = {}
  for _, rule in ipairs(Data().rules) do
    if rule.type == ruleType then
      rules[#rules + 1] = rule
    end
  end
  return rules
end

function Bargains.GetRule(id)
  for _, rule in ipairs(Data().rules) do
    if rule.id == id then
      return rule
    end
  end
end

function Bargains.HasRules()
  return #Data().rules > 0
end

-- The most rules of a type ("item" or "filter") that can be made.
function Bargains.GetLimit(ruleType)
  return ruleType == "item" and Bargains.MAX_ITEM_RULES or Bargains.MAX_FILTER_RULES
end

-- Whether no new rule of the type can be made. Rules that exist stay, whatever the limit is.
function Bargains.IsFull(ruleType)
  return #Bargains.GetRules(ruleType) >= Bargains.GetLimit(ruleType)
end

-- Saves a rule: a new one if it has no id, else it replaces the rule with that id. What was found for a changed rule
-- is dropped, it was found for the old one. A new rule of a type that is full is not saved (returns nil).
function Bargains.Save(rule)
  local data = Data()
  if not rule.id then
    if Bargains.IsFull(rule.type) then
      return nil
    end
    rule.id = data.nextId
    data.nextId = data.nextId + 1
    data.rules[#data.rules + 1] = rule
  else
    for index, old in ipairs(data.rules) do
      if old.id == rule.id then
        data.rules[index] = rule
      end
    end
    local hits = Hits()
    hits.filters[rule.id] = nil
    hits.items[rule.id] = nil
    hits.leftOut[rule.id] = nil
  end
  AM.Events.Fire("BARGAINS_CHANGED")
  return rule
end

function Bargains.Remove(id)
  local data = Data()
  for index, rule in ipairs(data.rules) do
    if rule.id == id then
      table.remove(data.rules, index)
      break
    end
  end
  local hits = Hits()
  hits.filters[id] = nil
  hits.items[id] = nil
  hits.leftOut[id] = nil
  AM.Events.Fire("BARGAINS_CHANGED")
end

function Bargains.SetActive(id, active)
  local rule = Bargains.GetRule(id)
  if rule then
    rule.active = active
    AM.Events.Fire("BARGAINS_CHANGED")
  end
end

-- The key the prices of the rule's item are stored under; nil for equipment and pets, whose key depends on the single
-- item (a rule only knows the itemID), so their price is unknown here.
local function RuleKey(rule)
  return (AM.ItemDbKey.ForItem(rule.itemId))
end

-- The most one item may cost for the rule (copper), nil where it is not known: a share of the market price needs a
-- market price.
function Bargains.GetMaxPrice(rule)
  if rule.percent then
    local key = RuleKey(rule)
    local market = key and AM.ItemStore.GetMarketPrice(key)
    return market and market.price and math.floor(market.price * rule.percent / 100) or nil
  end
  return rule.maxPrice
end

-- Matching ------------------------------------------------------------------------------------------

local function NeedsDetails(rule)
  return rule.minQuality ~= nil or rule.minItemLevel ~= nil or rule.maxItemLevel ~= nil
    or rule.minRequiredLevel ~= nil or rule.maxRequiredLevel ~= nil
end

-- Whether a value is inside the limits: nil where there are limits and the value is not known.
local function InRange(value, min, max)
  if min == nil and max == nil then
    return true
  elseif value == nil then
    return nil
  end
  return (min == nil or value >= min) and (max == nil or value <= max)
end

-- Combines answers that are true, false or nil (unknown): false if one is false, else nil if one is unknown.
local function All(...)
  local unknown = false
  for i = 1, select("#", ...) do
    local answer = (select(i, ...))
    if answer == false then
      return false
    elseif answer == nil then
      unknown = true
    end
  end
  return not unknown or nil
end

-- Whether an auction of a filter rule matches: true or false, nil if that depends on the quality or the levels of
-- the item and these are not known yet (details is nil). unitPrice is per item; classId and subClassId are those of
-- the item; details is { quality, itemLevel, requiredLevel }, each of them may be nil where it is not known.
function Bargains.Matches(rule, unitPrice, classId, subClassId, details)
  if not rule.maxPrice or unitPrice > rule.maxPrice then
    return false
  end
  if (rule.classId and rule.classId ~= classId) or (rule.subClassId and rule.subClassId ~= subClassId) then
    return false
  end
  if not NeedsDetails(rule) then
    return true
  end
  details = details or {}
  return All(InRange(details.quality, rule.minQuality, nil),
    InRange(details.itemLevel, rule.minItemLevel, rule.maxItemLevel),
    InRange(details.requiredLevel, rule.minRequiredLevel, rule.maxRequiredLevel))
end

local function ReadDetails(itemId)
  local _, _, quality, itemLevel, requiredLevel = C_Item.GetItemInfo(itemId)
  if quality then
    return { quality = quality, itemLevel = itemLevel or 0, requiredLevel = requiredLevel or 0 }
  end
end

-- Full scan ----------------------------------------------------------------------------------------

local scanSerial = 0
local loader = CreateFrame("Frame")

-- Starts collecting the bargains of a scan: returns the collector for Bargains.Collect and Bargains.FinishScan, nil
-- where there is no active filter.
function Bargains.StartScan()
  local rules, highest = {}, 0
  for _, rule in ipairs(Bargains.GetRules("filter")) do
    if rule.active and rule.maxPrice and rule.maxPrice > 0 then
      rules[#rules + 1] = rule
      highest = math.max(highest, rule.maxPrice)
    end
  end
  if #rules == 0 then
    return nil
  end
  return { rules = rules, highest = highest, classes = {}, found = {}, rejected = {} }
end

-- The quality and levels of one auction: the quality is part of the auction. The item level is that of the auction's own
-- item, the one in its link (what the browse list of the game shows and what is bought): the same item is listed with
-- different levels, e.g. 24 and 74, while the item data of the client only knows one. The required level is that of the
-- item, if the client has loaded it.
local function AuctionDetails(itemId, quality, index)
  local base = ReadDetails(itemId)
  local itemLevel
  if index and C_AuctionHouse.GetReplicateItemLink then
    local link = C_AuctionHouse.GetReplicateItemLink(index)
    itemLevel = link and C_Item.GetDetailedItemLevelInfo(link) or nil
  end
  return {
    -- the client reports -1 for an item it has not loaded yet
    quality = quality and quality >= 0 and quality or (base and base.quality),
    itemLevel = itemLevel or (base and base.itemLevel),
    requiredLevel = base and base.requiredLevel,
  }
end

-- Remembers an item that a filter would have found by the quality and levels of the item itself (what the client knows
-- of the item) but not by those of the auction: the cheapest auction of it. An item that fails the item's own data too is
-- no loss, and one whose data is not loaded cannot be told.
local function LeaveOut(collector, rule, itemId, unit, details)
  local base = ReadDetails(itemId)
  local class = collector.classes[itemId]
  if not base or not Bargains.Matches(rule, unit, class[1], class[2], base) then
    return
  end
  local rejected = collector.rejected[rule.id] or {}
  collector.rejected[rule.id] = rejected
  local old = rejected[itemId]
  if not old or unit < old.price then
    rejected[itemId] = { price = unit, quality = details.quality, itemLevel = details.itemLevel,
      requiredLevel = details.requiredLevel }
  end
end

-- One auction of the scan: count items for price (whole stack, copper). quality
-- and index (in the list of the scan) are those of the auction, if known.
function Bargains.Collect(collector, itemId, count, price, quality, index)
  if count <= 0 or price <= 0 then
    return
  end
  local unit = price / count
  if unit > collector.highest then
    return
  end
  local class = collector.classes[itemId]
  if not class then
    local _, _, _, _, _, classId, subClassId = C_Item.GetItemInfoInstant(itemId)
    class = { classId, subClassId }
    collector.classes[itemId] = class
  end
  local details
  for _, rule in ipairs(collector.rules) do
    -- without details the quality and the levels are not checked: nil means they are
    local result = Bargains.Matches(rule, unit, class[1], class[2], nil)
    if result == nil then
      details = details or AuctionDetails(itemId, quality, index)
      result = Bargains.Matches(rule, unit, class[1], class[2], details)
      if result == false then
        LeaveOut(collector, rule, itemId, unit, details)
      end
    end
    if result ~= false then
      local found = collector.found[rule.id]
      if not found then
        found = {}
        collector.found[rule.id] = found
      end
      local entry = found[itemId]
      if not entry then
        entry = { price = unit, count = 0, unknown = result == nil }
        found[itemId] = entry
      end
      entry.price = math.min(entry.price, unit)
      entry.count = entry.count + count
    end
  end
end

local function Store(collector)
  local filters, leftOut = {}, {}
  for _, rule in ipairs(collector.rules) do
    local list = {}
    local candidates, unresolved = 0, 0
    for itemId, entry in pairs(collector.found[rule.id] or {}) do
      candidates = candidates + 1
      if entry.unknown then
        unresolved = unresolved + 1
      else
        list[#list + 1] = { itemId, math.floor(entry.price), entry.count }
      end
    end
    if AM.DebugLog.IsEnabled() then
      local rejected = {}
      for itemId, entry in pairs(collector.rejected[rule.id] or {}) do
        rejected[#rejected + 1] = { itemId, entry }
      end
      table.sort(rejected, function(a, b)
        return a[2].price < b[2].price
      end)
      for index = 1, math.min(#rejected, REJECTED_LOGGED) do
        local entry = rejected[index][2]
        AM.DebugLog.Log("bargains", "filter %d left out: item %d, %d copper, quality %s, item level %s, required level %s",
          rule.id, rejected[index][1], math.floor(entry.price), tostring(entry.quality), tostring(entry.itemLevel),
          tostring(entry.requiredLevel))
      end
    end
    AM.DebugLog.Log("bargains", "filter %d: %d candidates, %d without data, %d kept", rule.id, candidates, unresolved,
      math.min(#list, Bargains.MAX_HITS))
    table.sort(list, function(a, b)
      return a[2] < b[2] or (a[2] == b[2] and a[1] < b[1])
    end)
    for index = #list, Bargains.MAX_HITS + 1, -1 do
      list[index] = nil
    end
    filters[rule.id] = list
    local out = {}
    for itemId, entry in pairs(collector.rejected[rule.id] or {}) do
      -- an item with another auction that matched is a hit (or one of too many), not an item that was left out
      local matched = (collector.found[rule.id] or {})[itemId]
      if not (matched and not matched.unknown) then
        out[#out + 1] = { itemId, math.floor(entry.price), entry.quality, entry.itemLevel, entry.requiredLevel }
      end
    end
    table.sort(out, function(a, b)
      return a[2] < b[2] or (a[2] == b[2] and a[1] < b[1])
    end)
    for index = #out, Bargains.MAX_LEFT_OUT + 1, -1 do
      out[index] = nil
    end
    leftOut[rule.id] = out
  end
  local hits = Hits()
  hits.filters = filters
  hits.leftOut = leftOut
  hits.scannedAt = time()
  AM.DebugLog.Log("bargains", "scan stored, %d filters", #collector.rules)
  AM.Events.Fire("BARGAINS_CHANGED")
end

-- Checks the items whose quality or levels were asked for, as far as the client has them by now.
local function Resolve(collector, requested)
  for _, rule in ipairs(collector.rules) do
    for itemId, entry in pairs(collector.found[rule.id] or {}) do
      if entry.unknown and requested[itemId] then
        local details = ReadDetails(itemId)
        if details then
          local class = collector.classes[itemId]
          entry.unknown = false
          if not Bargains.Matches(rule, entry.price, class[1], class[2], details) then
            LeaveOut(collector, rule, itemId, entry.price, details)
            collector.found[rule.id][itemId] = nil
          end
        end
      end
    end
  end
end

-- The items whose data is still needed: per filter only those among its MAX_HITS cheapest candidates, the dearer
-- ones cannot make it into the list however they turn out. Cheaper candidates that fall away move the next ones up.
local function MissingItems(collector)
  local missing = {}
  for _, rule in ipairs(collector.rules) do
    local list = {}
    for itemId, entry in pairs(collector.found[rule.id] or {}) do
      list[#list + 1] = { itemId, entry }
    end
    table.sort(list, function(x, y)
      return x[2].price < y[2].price or (x[2].price == y[2].price and x[1] < y[1])
    end)
    for index = 1, math.min(#list, Bargains.MAX_HITS) do
      if list[index][2].unknown then
        missing[list[index][1]] = true
      end
    end
  end
  return missing
end

-- Called when the scan has been read completely. Items whose data the client has not loaded yet are asked for, a few
-- at a time and only where they could still end up in a list. The result is stored when nothing is missing any more,
-- or after LOAD_SECONDS without an answer (what is missing then cannot be judged).
function Bargains.FinishScan(collector)
  if not collector then
    return
  end
  scanSerial = scanSerial + 1
  local serial = scanSerial
  local requested, checkPending = {}, false
  local function Done()
    scanSerial = scanSerial + 1
    loader:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    Store(collector)
  end
  local Round
  -- The answers come in bursts of thousands: check once for all of them.
  local function ScheduleCheck()
    if checkPending or serial ~= scanSerial then
      return
    end
    checkPending = true
    C_Timer.After(CHECK_SECONDS, function()
      checkPending = false
      if serial == scanSerial then
        Round()
      end
    end)
  end
  Round = function()
    local asked, missing = false, nil
    -- what the client has is judged at once, which can move the next candidates into the window
    repeat
      Resolve(collector, requested)
      missing = MissingItems(collector)
      local fresh = false
      for itemId in pairs(missing) do
        if not requested[itemId] then
          requested[itemId] = true
          fresh = true
          if not ReadDetails(itemId) then
            asked = true
            C_Item.RequestLoadItemDataByID(itemId)
          end
        end
      end
    until not fresh
    if asked then
      ScheduleCheck() -- items the client already had send no answer
    elseif next(missing) == nil then
      Done()
    end
  end
  loader:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  loader:SetScript("OnEvent", ScheduleCheck)
  C_Timer.After(LOAD_SECONDS, function()
    if serial == scanSerial then
      Resolve(collector, requested)
      Done()
    end
  end)
  Round()
end

-- Results -------------------------------------------------------------------------------------------

-- The items of the last full scan that a filter matched ({ itemId, price, count } cheapest first) and the time of that
-- scan; nil where the filter has not been through a full scan yet.
function Bargains.GetFilterHits(id)
  local hits = Hits()
  local list = hits.filters[id]
  if list and hits.scannedAt and time() - hits.scannedAt <= Bargains.MAX_AGE then
    return list, hits.scannedAt
  end
end

-- The time of the full scan the filter hits are from, nil where there is none or it is older than MAX_AGE.
function Bargains.GetScannedAt()
  local scannedAt = Hits().scannedAt
  if scannedAt and time() - scannedAt <= Bargains.MAX_AGE then
    return scannedAt
  end
end

-- The items of the last full scan that a filter left out because of their quality or levels, although the price and
-- the category matched ({ itemId, price, quality, itemLevel, requiredLevel }, cheapest first), and why.
function Bargains.GetLeftOut(id)
  if Bargains.GetFilterHits(id) then
    return Hits().leftOut[id] or {}
  end
  return {}
end

-- Which limit of the filter an item missed: "quality", "itemLevel" or "requiredLevel" and the value of the item.
function Bargains.WhyLeftOut(rule, entry)
  local quality, itemLevel, requiredLevel = entry[3], entry[4], entry[5]
  if rule.minQuality and quality and quality < rule.minQuality then
    return "quality", quality
  elseif itemLevel and InRange(itemLevel, rule.minItemLevel, rule.maxItemLevel) == false then
    return "itemLevel", itemLevel
  elseif requiredLevel and InRange(requiredLevel, rule.minRequiredLevel, rule.maxRequiredLevel) == false then
    return "requiredLevel", requiredLevel
  end
end

-- What the last search of the item of a rule found: lowest price per item (nil if nothing was listed), the time of the
-- search, whether it is a bargain and the price it had to stay under (nil if that is not known). Nothing if it was not
-- searched.
function Bargains.GetItemResult(rule)
  local entry = Hits().items[rule.id]
  if not entry or time() - entry.searchedAt > Bargains.MAX_AGE then
    return
  end
  local max = Bargains.GetMaxPrice(rule)
  return entry.low, entry.searchedAt, entry.low ~= nil and max ~= nil and entry.low <= max, max
end

-- The search of an item was not answered: nobody lists it. Remembered for the rules of that item, unless a result was
-- stored at or after since (ItemSearch ignores a result identical to the one just before, which gives no answer either).
function Bargains.OnNothingListed(itemId, since)
  local hits = Hits()
  for _, rule in ipairs(Bargains.GetRules("item")) do
    local entry = hits.items[rule.id]
    if rule.itemId == itemId and not (entry and entry.searchedAt >= since) then
      hits.items[rule.id] = { searchedAt = time() }
    end
  end
  AM.Events.Fire("BARGAINS_CHANGED")
end

-- A full scan stored the prices of all items: that is a search of every item of the rules, whatever it found.
function Bargains.OnFullScan()
  local hits = Hits()
  for _, rule in ipairs(Bargains.GetRules("item")) do
    hits.items[rule.id] = { low = RuleKey(rule) and AM.ItemStore.Get(RuleKey(rule)), searchedAt = time() }
  end
  AM.Events.Fire("BARGAINS_CHANGED")
end

-- When the items of the active rules were searched: the time of the oldest search, nil if one of them was not
-- searched yet (or there is none).
function Bargains.GetLastSearched()
  local oldest
  for _, rule in ipairs(Bargains.GetRules("item")) do
    if rule.active then
      local _, searchedAt = Bargains.GetItemResult(rule)
      if not searchedAt then
        return nil
      end
      oldest = math.min(oldest or searchedAt, searchedAt)
    end
  end
  return oldest
end

-- The number of bargains found: items under their maximum price and filters' items.
function Bargains.CountHits()
  local count = 0
  for _, rule in ipairs(Bargains.GetRules("item")) do
    local _, _, hit = Bargains.GetItemResult(rule)
    if rule.active and hit then
      count = count + 1
    end
  end
  for _, rule in ipairs(Bargains.GetRules("filter")) do
    local list = Bargains.GetFilterHits(rule.id)
    if rule.active and list then
      count = count + #list
    end
  end
  return count
end

-- The auctions of an item were searched and stored: remembers its lowest price for the rules of that item.
function Bargains.OnItemSearched(itemDbKey, itemId)
  local low = AM.ItemStore.Get(itemDbKey)
  if not low then
    return
  end
  local hits, changed = Hits(), false
  for _, rule in ipairs(Bargains.GetRules("item")) do
    if rule.itemId == itemId then
      hits.items[rule.id] = { low = low, searchedAt = time() }
      changed = true
    end
  end
  if changed then
    AM.Events.Fire("BARGAINS_CHANGED")
  end
end

AM.Events.Register("ITEM_SEARCHED", Bargains.OnItemSearched)

-- Text -----------------------------------------------------------------------------------------------

-- The name of a rule: the item, or what the filter selects ("Weapons, One-Handed Axes, Item level 10-20").
function Bargains.Describe(rule)
  if rule.type == "item" then
    return (C_Item.GetItemInfo(rule.itemId)) or ("item:" .. rule.itemId)
  end
  local parts = {}
  if rule.classId then
    parts[#parts + 1] = C_Item.GetItemClassInfo(rule.classId) or "?"
    if rule.subClassId then
      parts[#parts + 1] = C_Item.GetItemSubClassInfo(rule.classId, rule.subClassId) or "?"
    end
  else
    parts[#parts + 1] = L["BARGAINS_ANY_CATEGORY"]
  end
  if rule.minItemLevel and rule.maxItemLevel then
    parts[#parts + 1] = L["BARGAINS_LEVEL_RANGE"]:format(rule.minItemLevel, rule.maxItemLevel)
  elseif rule.minItemLevel then
    parts[#parts + 1] = L["BARGAINS_LEVEL_MIN"]:format(rule.minItemLevel)
  elseif rule.maxItemLevel then
    parts[#parts + 1] = L["BARGAINS_LEVEL_MAX"]:format(rule.maxItemLevel)
  end
  return table.concat(parts, ", ")
end
