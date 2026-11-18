local addonName, AM = ...

-- Feeds the ledger with what the player trades with merchants (read only, nothing is changed): reads the buyback list
-- into LedgerMerchant on every MERCHANT_UPDATE and books the sales of a visit when the merchant closes (items one by
-- one, junk summed up as one event); hooks BuyMerchantItem and BuybackItem and confirms a purchase by the money it
-- took (PLAYER_MONEY). Only gold counts: items that cost tokens or other currencies are left out.

if not (GetNumBuybackItems and GetBuybackItemInfo and GetBuybackItemLink and GetMoney) then
  return
end

local POOR = Enum.ItemQuality and Enum.ItemQuality.Poor or 0

local merchantOpen = false
local money = GetMoney()

-- The buyback list as LedgerMerchant knows it. An entry without link or price (not loaded) is left out.
local function ReadBuyback()
  local list = {}
  for index = 1, GetNumBuybackItems() do
    local _, _, price, count = GetBuybackItemInfo(index)
    local link = GetBuybackItemLink(index)
    if link and price then
      count = count or 1
      local quality = select(3, C_Item.GetItemInfo(link))
      list[#list + 1] = { key = link .. "|" .. count .. "|" .. price, item = AM.ItemDbKey.FromLink(link), count = count,
        price = price, junk = quality == POOR, index = index }
    end
  end
  return list
end

-- The buyback list keeps the game's index of each entry; LedgerMerchant counts the entries it knows.
local function PictureIndex(list, index)
  for position, entry in ipairs(list) do
    if entry.index == index then
      return position
    end
  end
end

local picture = {}

local function Update()
  picture = ReadBuyback()
  for _, entry in ipairs(AM.LedgerMerchant.Update(picture, time())) do
    -- bought back after the visit it was sold in was booked: a purchase at the buyback price
    AM.DebugLog.Log("ledger", "bought back %s x%s for %s, sold in an earlier visit", entry.item, entry.count,
      entry.price)
    AM.Ledger.BookVendorPurchase(UnitGUID("player"), entry.item, entry.count, entry.price)
  end
end

-- Books the sales of the visit: each item for itself, the junk as one sum.
local function Close()
  local guid = UnitGUID("player")
  local junkCount, junkPrice = 0, 0
  for _, sale in ipairs(AM.LedgerMerchant.Close()) do
    if sale.junk then
      junkCount = junkCount + sale.count
      junkPrice = junkPrice + sale.price
    else
      AM.Ledger.BookVendorSale(guid, sale.item, sale.count, sale.price, sale.at)
    end
  end
  AM.Ledger.BookJunk(guid, junkCount, junkPrice)
end

-- After the call, read only: the money it takes confirms it. quantity: items (nil: one stack as the merchant sells it),
-- the price is for a stack.
hooksecurefunc("BuyMerchantItem", function(index, quantity)
  pcall(function()
    local price, stack, extendedCost = AM.MerchantScanner.GetMerchantItem(index)
    local link = GetMerchantItemLink(index)
    stack = math.max(stack or 1, 1)
    quantity = quantity or stack
    if not price or price <= 0 or extendedCost or not link then
      AM.DebugLog.Log("ledger", "vendor purchase not noted: %s price %s extended cost %s", link, price, extendedCost)
      return
    end
    local cost = math.floor(price * quantity / stack + 0.5)
    AM.DebugLog.Log("ledger", "vendor purchase asked for: %s x%s for %s", link, quantity, cost)
    AM.LedgerMerchant.NoteBuy(AM.ItemDbKey.FromLink(link), quantity, cost, time())
  end)
end)

if BuybackItem then
  hooksecurefunc("BuybackItem", function(index)
    pcall(function()
      local position = PictureIndex(picture, index)
      AM.DebugLog.Log("ledger", "buyback of %s asked for", position and picture[position].key or index)
      if position then
        AM.LedgerMerchant.NoteBuyback(position)
      end
    end)
  end)
end

local frame = CreateFrame("Frame")
for _, event in ipairs({ "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED", "PLAYER_MONEY", "PLAYER_LOGOUT" }) do
  pcall(frame.RegisterEvent, frame, event)
end

frame:SetScript("OnEvent", function(_, event)
  local ok, err = pcall(function()
    if event == "MERCHANT_SHOW" then
      merchantOpen = true
      money = GetMoney()
      picture = ReadBuyback()
      AM.LedgerMerchant.Open(picture)
    elseif event == "MERCHANT_UPDATE" then
      if merchantOpen then
        Update()
      end
    elseif event == "PLAYER_MONEY" then
      local now = GetMoney()
      for _, purchase in ipairs(AM.LedgerMerchant.MoneyChanged(money, now, time())) do
        AM.Ledger.BookVendorPurchase(UnitGUID("player"), purchase.item, purchase.count, purchase.price, purchase.at)
      end
      money = now
    elseif merchantOpen then
      -- MERCHANT_CLOSED (it may come twice), or a logout / reload with the merchant still open. After a close the
      -- list is not read again: it may be gone with the merchant, which would look like buybacks. At a logout the
      -- merchant is still there: a sale made just before it may not have brought its MERCHANT_UPDATE yet (seen on
      -- Forever: junk sold 0.4 s before a reload was missing), so the list is read once more while it has entries.
      if event == "PLAYER_LOGOUT" and GetNumBuybackItems() > 0 then
        Update()
      end
      merchantOpen = false
      Close()
    end
  end)
  if not ok then
    AM.DebugLog.Log("ledger", "merchant %s not read: %s", event, err)
  end
end)
