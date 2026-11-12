local addonName, AM = ...

-- Learns what merchants charge for items whenever a merchant window is opened, and keeps
-- the price per single item in copper in the faction object "vendorPrices" (keyed by
-- itemId) and the available count in the faction object "vendorStock" (-1 if unlimited).
-- Only items bought for gold alone are recorded; items that cost tokens or other
-- currencies have no meaningful copper price. Only a lower price replaces a known one, so
-- a reputation discount of any character of the faction is reflected in it.
local MerchantScanner = {}
AM.MerchantScanner = MerchantScanner

-- Returns price, quantity, hasExtendedCost, numAvailable of the merchant item at index, nil
-- if the slot is empty or not purchasable. Retail returns a table, older clients a tuple.
local function GetMerchantItem(index)
  if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
    local info = C_MerchantFrame.GetItemInfo(index)
    if not info or not info.isPurchasable then
      return nil
    end
    return info.price, info.stackCount, info.hasExtendedCost, info.numAvailable
  end

  local _, _, price, quantity, numAvailable, isPurchasable, _, extendedCost = GetMerchantItemInfo(index)
  if not isPurchasable then
    return nil
  end
  return price, quantity, extendedCost, numAvailable
end

local function Scan()
  local prices = AM.Database.GetFactionObject("vendorPrices")
  local stock = AM.Database.GetFactionObject("vendorStock")

  for index = 1, GetMerchantNumItems() do
    local price, quantity, hasExtendedCost, numAvailable = GetMerchantItem(index)
    local link = GetMerchantItemLink(index)
    if link and price and price > 0 and not hasExtendedCost then
      local itemId = C_Item.GetItemInfoInstant(link)
      if itemId then
        local perItem = price / math.max(quantity or 1, 1)
        if not prices[itemId] or perItem < prices[itemId] then
          prices[itemId] = perItem
        end
        -- Unlimited (-1) sticks, as another merchant may offer it without limit; otherwise
        -- the latest count seen wins.
        if stock[itemId] ~= -1 then
          stock[itemId] = numAvailable or -1
        end
      end
    end
  end
end

-- Returns the price per item in copper at which a merchant sells the item, nil if no
-- merchant selling it for gold is known.
function MerchantScanner.GetPrice(itemId)
  return AM.Database.GetFactionObject("vendorPrices")[itemId]
end

-- Returns how many items a merchant had available when last seen, -1 if unlimited, nil if
-- no merchant selling it for gold is known.
function MerchantScanner.GetStock(itemId)
  return AM.Database.GetFactionObject("vendorStock")[itemId]
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_UPDATE")
frame:SetScript("OnEvent", Scan)
