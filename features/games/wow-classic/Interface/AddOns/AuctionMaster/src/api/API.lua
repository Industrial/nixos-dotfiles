local addonName, AM = ...

-- The public API for other addons, described in API.md. It only reads: every value comes from AM.ItemStore, which
-- stays the one place that changes the auction and market data. The one global of the addon besides the saved
-- variables and the slash commands is AuctionMaster, and it holds nothing but this table.
AM.API = {}
local API = AM.API
AuctionMaster = { API = API }

-- An item is given as an itemID (a number, or digits in a string: what a pattern match on a link returns) or as a
-- link or item string ("item:2589"), which is what equipment and battle pets need, as their key contains the item
-- level or the species. Anything else, and every item whose key cannot be told, is unknown.
local function KeyOf(item)
  if type(item) == "number" then
    return (AM.ItemDbKey.ForItem(item))
  elseif type(item) == "string" then
    if item:match("^%d+$") then
      return (AM.ItemDbKey.ForItem(tonumber(item)))
    end
    return (AM.ItemDbKey.FromLink(item))
  end
end

function API.GetLowestPrice(item)
  local key = KeyOf(item)
  return key and (AM.ItemStore.Get(key))
end

function API.GetMarketPrice(item)
  local key = KeyOf(item)
  local market = key and AM.ItemStore.GetMarketPrice(key)
  return market and market.price
end

-- The market price entry is stamped with the time of the scan or search that stored the item's latest prices, as
-- long as the item has a price in the latest data. Without a price in the latest data, or without the market price
-- entry (reset by the player), the age is not known.
function API.GetDataAge(item)
  local key = KeyOf(item)
  if not key or not AM.ItemStore.Get(key) then
    return nil
  end
  local market = AM.ItemStore.GetMarketPrice(key)
  return market and math.max(0, time() - market.priceAt)
end

function API.GetAvailableQuantity(item)
  local key = KeyOf(item)
  if not key then
    return nil
  end
  local _, count = AM.ItemStore.Get(key)
  return count
end

-- Several listeners are fine, an unbounded number is a bug of the addon that adds them.
local MAX_LISTENERS = 50
local listeners, isListener = {}, {}

function API.AddDataChangeListener(listener)
  if type(listener) ~= "function" then
    return false
  end
  if isListener[listener] then
    return true
  end
  if #listeners >= MAX_LISTENERS then
    return false
  end
  listeners[#listeners + 1] = listener
  isListener[listener] = true
  return true
end

-- A scan or a search can change the prices several times in a row (a search lists several item levels of an item, one
-- store per level): the listeners are told once, on the next frame.
local pending = false

local function Notify()
  pending = false
  for _, listener in ipairs(listeners) do
    -- One failing listener is reported but does not keep the others from running.
    xpcall(listener, geterrorhandler())
  end
end

AM.Events.Register("PRICES_CHANGED", function()
  if pending or #listeners == 0 then
    return
  end
  pending = true
  C_Timer.After(0, Notify)
end)
