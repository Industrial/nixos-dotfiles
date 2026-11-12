local addonName, AM = ...

-- What crafting a recipe costs and what it is worth, from the prices the addon knows. Used by
-- everything that shows it (see RecipeSummary.lua), on every client: the recipe is given as read by
-- ShoppingList.ReadRetailRecipe / ReadClassicRecipe, so nothing here touches a profession window.
AM.RecipeCost = {}
local RecipeCost = AM.RecipeCost

local SELL_PRICE_INDEX = 11
local AH_CUT = 0.05
-- Prices of an older scan are still shown, only greyed out.
local STALE_SECONDS = 24 * 60 * 60

-- The price of one item at the auction house, with the age of the data in seconds. While the item was
-- seen in a scan or search of the last "freshMinutes" (a setting) this is its lowest price, what buying it now
-- costs. Otherwise it is its market value, like the tooltip shows it (the smoothed market price lags
-- behind a recent price change, but a single old listing says little). Nil if the item has no market price.
local function GetAuctionPrice(itemId)
  -- reagents are plain items; equipment has no key without its level, so nothing is known of its price
  local itemDbKey = AM.ItemDbKey.ForItem(itemId)
  local market = itemDbKey and AM.ItemStore.GetMarketPrice(itemDbKey)
  if not market then
    return nil
  end
  local age = time() - market.priceAt
  local lowPrice = AM.ItemStore.Get(itemDbKey)
  if lowPrice and age <= AM.ItemStore.GetNumber("freshMinutes") * 60 then
    return lowPrice, age
  end
  return market.price, age
end
RecipeCost.GetAuctionPrice = GetAuctionPrice
RecipeCost.AH_CUT = AH_CUT

-- What a merchant charges for one item, nil if no merchant selling it is known.
local function GetVendorPrice(itemId)
  return AM.MerchantScanner.GetPrice(itemId) or AM.VendorItems.GetPrice(itemId)
end

-- A reagent that is crafted from reagents that are crafted... stops here, deeper chains are not
-- followed.
local MAX_CRAFT_DEPTH = 4

local GetBuyPrice

-- Set while pricing for one character: only the recipes this character (GUID) knows count as crafting
-- a reagent. Nil means a recipe of any character of the faction does.
local onlyCrafter

-- Whether the character (GUID) knows the stored recipe.
function RecipeCost.IsCraftedBy(recipe, guid)
  for _, crafter in ipairs(recipe.crafters) do
    if crafter == guid then
      return true
    end
  end
  return false
end

-- The cheapest way to buy one of each reagent of the recipe and the oldest auction data used:
-- total, age. Nil if a reagent has no price. visited holds the items being priced right now, those
-- are not crafted again (a recipe may need what another one makes out of it).
local function GetReagentsPrice(reagents, visited, depth)
  local total, age = 0, nil
  for _, reagent in ipairs(reagents) do
    local best
    for _, itemId in ipairs(reagent.itemIds or { reagent.itemId }) do
      local buy = GetBuyPrice(itemId, visited, depth)
      if buy and (not best or buy.price < best.price) then
        best = buy
      end
    end
    if not best then
      return nil
    end
    total = total + best.price * reagent.quantity
    if best.age then
      age = math.max(age or 0, best.age)
    end
  end
  return total, age
end

-- What one of the item costs when crafted by a character of this faction knowing a recipe for it:
-- { price, source = "crafted", age }, the cheapest of the recipes, nil if there is none or a reagent
-- of each has no price.
local function GetCraftPrice(itemId, visited, depth)
  if depth >= MAX_CRAFT_DEPTH or visited[itemId] then
    return nil
  end
  visited[itemId] = true
  local best
  for _, recipe in ipairs(AM.ProfessionScanner.GetRecipes(itemId)) do
    local total, age
    if not onlyCrafter or RecipeCost.IsCraftedBy(recipe, onlyCrafter) then
      total, age = GetReagentsPrice(recipe.reagents, visited, depth + 1)
    end
    if total then
      local price = total / math.max(recipe.outputCount or 1, 1)
      if not best or price < best.price then
        best = { price = price, source = "crafted", age = age }
      end
    end
  end
  visited[itemId] = nil
  return best
end

-- The cheapest way to get one of the item: { price, source = "auction" | "vendor" | "crafted", age },
-- nil if there is no price. On a tie auction wins over vendor, and both over crafting.
function GetBuyPrice(itemId, visited, depth)
  local auction, age = GetAuctionPrice(itemId)
  local vendor = GetVendorPrice(itemId)
  local best
  if auction and (not vendor or auction <= vendor) then
    best = { price = auction, source = "auction", age = age }
  elseif vendor then
    best = { price = vendor, source = "vendor" }
  end
  local crafted = GetCraftPrice(itemId, visited, depth)
  if crafted and (not best or crafted.price < best.price) then
    best = crafted
  end
  return best
end

-- The cheapest way to get one of the item, see GetBuyPrice, nil if there is no price. With a crafter (GUID)
-- only the recipes that character knows count as crafting it.
function RecipeCost.GetBuyPrice(itemId, crafter)
  onlyCrafter = crafter
  local buy = GetBuyPrice(itemId, {}, 0)
  onlyCrafter = nil
  return buy
end

-- Reagents with several qualities (retail) cost what their cheapest quality does.
local function GetReagentPrice(reagent, visited)
  local best
  for _, itemId in ipairs(reagent.itemIds or { reagent.itemId }) do
    local buy = GetBuyPrice(itemId, visited, 0)
    if buy and (not best or buy.price < best.price) then
      best = buy
    end
  end
  return best
end

-- Returns what the crafted item sells for: { price, source = "market" | "vendor", age } per item,
-- the auction price already reduced by the auction house cut. The auction price is the lowest one
-- of the latest scan (basis "lowest", what it most likely sells for), or the market price (basis
-- "market") while no auction is listed. Nil if there is no price.
local function GetOutputValue(itemId)
  local itemDbKey = AM.ItemDbKey.ForCrafted(itemId)
  local market = itemDbKey and AM.ItemStore.GetMarketPrice(itemDbKey)
  local lowest = itemDbKey and AM.ItemStore.Get(itemDbKey)
  local auction = lowest or (market and market.price)
  local sellPrice = select(SELL_PRICE_INDEX, C_Item.GetItemInfo(itemId))
  local vendor = sellPrice and sellPrice > 0 and sellPrice or nil
  local afterCut = auction and auction * (1 - AH_CUT)
  if afterCut and (not vendor or afterCut >= vendor) then
    return { price = afterCut, source = "market", basis = lowest and "lowest" or "market", gross = auction,
      lowest = lowest, market = market and market.price, vendor = vendor,
      age = market and time() - market.priceAt }
  elseif vendor then
    return { price = vendor, source = "vendor", gross = auction, lowest = lowest,
      market = market and market.price, vendor = vendor }
  end
  return nil
end

function RecipeCost.IsStale(age)
  return age ~= nil and age > STALE_SECONDS
end

-- Returns for one craft of the recipe:
--   reagents  one per reagent { itemId, quantity, price (total, nil if unknown), source ("auction",
--             "vendor" or "crafted" by a known recipe), age }
--   cost      sum of the known reagent prices, incomplete is true if one is unknown
--   count     items made per craft
--   value     what they sell for (nil if unknown or if the recipe makes no known item), valueSource,
--             gross (auction price before the cut), basis ("lowest" or "market", which price gross is),
--             lowest (lowest auction price of them), market (market price of them), fee, vendor (vendor sell price of them)
--   profit    value - cost, nil unless both are known completely
--   age       age in seconds of the oldest auction data used
-- With a crafter (GUID), reagents count as crafted only by the recipes that character knows.
function RecipeCost.Calculate(recipe, crafter)
  onlyCrafter = crafter
  local result = { reagents = {}, cost = 0, incomplete = false, count = recipe.outputCount or 1 }
  local age
  local function Track(itemAge)
    if itemAge then
      age = math.max(age or 0, itemAge)
    end
  end

  -- the item the recipe makes is never crafted as a reagent of itself
  local visited = { [recipe.outputItemId or 0] = true }
  for _, reagent in ipairs(recipe.reagents) do
    local buy = GetReagentPrice(reagent, visited)
    local line = { itemId = reagent.itemId, quantity = reagent.quantity }
    if buy then
      line.price = buy.price * reagent.quantity
      line.source = buy.source
      line.age = buy.age
      result.cost = result.cost + line.price
      Track(buy.age)
    else
      result.incomplete = true
    end
    result.reagents[#result.reagents + 1] = line
  end

  local value = recipe.outputItemId and GetOutputValue(recipe.outputItemId)
  if value then
    local count = result.count
    result.value = value.price * count
    result.valueSource = value.source
    result.basis = value.basis
    result.lowest = value.lowest and value.lowest * count
    result.market = value.market and value.market * count
    result.gross = value.gross and value.gross * count
    result.fee = value.source == "market" and value.gross * AH_CUT * count or nil
    result.vendor = value.vendor and value.vendor * count
    result.valueAge = value.age
    Track(value.age)
    if not result.incomplete then
      result.profit = result.value - result.cost
    end
  end
  onlyCrafter = nil
  result.age = age
  return result
end
