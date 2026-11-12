local addonName, AM = ...

-- The settings of the Sell tab, in the global object "sellSettings" (a number per key, the default where unset).
AM.SellSettings = {}
local SellSettings = AM.SellSettings

-- Each is { default, min, max }.
SellSettings.NUMBERS = {
  -- percent: what an item nobody else lists is asked above its market value
  noCompetitionMargin = { 30, 0, 500 },
  -- Auctions view: how far an undercut counts as fine and as a warning, for single items in auctions ahead and
  -- for commodities in percent of the listed items ahead; above the warning it is too much
  undercutAuctionsOk = { 2, 0, 99 },
  undercutAuctionsWarn = { 3, 0, 99 },
  undercutPercentOk = { 2, 0, 100 },
  undercutPercentWarn = { 5, 0, 100 },
}

function SellSettings.GetNumber(key)
  local default, min, max = unpack(SellSettings.NUMBERS[key])
  return math.max(min, math.min(max, tonumber(AM.Database.GetGlobalObject("sellSettings")[key]) or default))
end

function SellSettings.SetNumber(key, value)
  local _, min, max = unpack(SellSettings.NUMBERS[key])
  AM.Database.GetGlobalObject("sellSettings")[key] = math.max(min, math.min(max, math.floor(value)))
  AM.Events.Fire(key:find("^undercut") and "OWN_AUCTIONS_CHANGED" or "PRICES_CHANGED")
end

-- Items the player never wants to sell, by itemDbKey (the global object "sellIgnored": itemDbKey -> true; equipment of
-- another level is another item). The Sell tab hides them unless the filter "show ignored items" is on (kept in
-- "sellSettings" like the numbers).
-- The list used to be by itemId (a number). On first access a numeric key becomes the itemDbKey of the item where the
-- itemId alone is one (most items); for equipment and battle pets the level or species the player meant is not known,
-- so those entries are dropped (the item can be ignored again). Recognized by the type of the key, so it does nothing
-- on a list that is in line already.
local ignoredMigrated = {}

local function Ignored()
  local ignored = AM.Database.GetGlobalObject("sellIgnored")
  if not ignoredMigrated[ignored] then
    ignoredMigrated[ignored] = true
    local old = {}
    for key in pairs(ignored) do
      if type(key) == "number" then
        old[#old + 1] = key
      end
    end
    for _, itemId in ipairs(old) do
      ignored[itemId] = nil
      local itemDbKey = AM.ItemDbKey.ForItem(itemId)
      if itemDbKey then
        ignored[itemDbKey] = true
      end
    end
  end
  return ignored
end

function SellSettings.IsIgnored(itemDbKey)
  return Ignored()[itemDbKey] == true
end

function SellSettings.SetIgnored(itemDbKey, ignored)
  Ignored()[itemDbKey] = ignored and true or nil
  AM.Events.Fire("SELL_FILTER_CHANGED")
end

function SellSettings.GetShowIgnored()
  return AM.Database.GetGlobalObject("sellSettings").showIgnored == true
end

function SellSettings.SetShowIgnored(show)
  AM.Database.GetGlobalObject("sellSettings").showIgnored = show and true or nil
  AM.Events.Fire("SELL_FILTER_CHANGED")
end

