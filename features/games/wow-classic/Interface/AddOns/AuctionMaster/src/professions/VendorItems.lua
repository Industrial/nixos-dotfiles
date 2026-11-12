local addonName, AM = ...

-- Items that merchants sell for gold, in unlimited supply. Their price is not stored but
-- derived from the vendor sell price, which merchants buy back at a quarter of what they
-- charge.
local VendorItems = {}
AM.VendorItems = VendorItems

local PRICE_FACTOR = 4
local SELL_PRICE_INDEX = 11

local itemIds = {
  4470, 3371, 4340, 2320, 4364, 2321, 4289, 2678, 4471, 3372, 2692, 6217, 4399, 10284,
  11291, 2880, 2605, 4361, 4291, 2604, 272941, 3713, 4357, 8925, 2324, 273636, 4389, 8343,
  6260, 14256, 3857, 7076, 7082, 17010, 3466, 14341, 8845, 13463, 3358, 8846, 11382, 4404,
  4382, 17012, 2325, 17011, 18567, 8959, 18256, 13464, 238737, 6261, 4342, 10648, 4400,
  10647, 4341, 232454, 10290, 232457, 232456, 232455,
}

local isVendorItem = {}
for _, itemId in ipairs(itemIds) do
  isVendorItem[itemId] = true
end

function VendorItems.IsVendorItem(itemId)
  return isVendorItem[itemId] == true
end

-- Returns the price in copper at which a merchant sells the item, nil if it is not a
-- vendor item or its sell price is not known (yet, the item may not be cached).
function VendorItems.GetPrice(itemId)
  if not isVendorItem[itemId] then
    return nil
  end
  local sellPrice = select(SELL_PRICE_INDEX, C_Item.GetItemInfo(itemId))
  if not sellPrice or sellPrice <= 0 then
    return nil
  end
  return sellPrice * PRICE_FACTOR
end
