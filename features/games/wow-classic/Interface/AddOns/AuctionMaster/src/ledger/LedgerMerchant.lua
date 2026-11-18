local addonName, AM = ...

-- Plain data, no game calls: what the player trades with a merchant during one visit, for the ledger
-- (doc/notes/ledger.md, "Vendor"). Kept in memory only.
--
-- Sales: the game puts every item sold to a merchant into its buyback list, however it was sold (a right click, a drag,
-- an addon selling junk). The recorder hands the list in on every change (Update); an entry that came in is a sale. The
-- list holds 12 entries, the oldest falls out when a 13th comes in, which is no buyback. A buyback is noted by the hook
-- on BuybackItem (NoteBuyback) and confirmed when its entry left the list. The sales wait until the visit ends (Close):
-- an item bought back in the same visit was never sold.
--
-- Purchases: noted by the hook on BuyMerchantItem (NoteBuy) and confirmed when the money goes down by their price
-- (MoneyChanged); a purchase the game refuses (bags full) takes no money and is dropped after BUY_TIMEOUT.
--
-- An entry of the buyback list: { key, item, count, price, junk }, key telling apart entries that are not the same
-- (link, count and price), price what the merchant paid for the stack.
AM.LedgerMerchant = {}
local LedgerMerchant = AM.LedgerMerchant

-- A purchase whose money did not go within this many seconds was refused.
local BUY_TIMEOUT = 10

local picture = {} -- the buyback list as last seen
local sales = {} -- the sales of this visit, oldest first: { item, count, price, junk, at }
local buybacks = {} -- the buybacks asked for and not confirmed yet, by key: how many
local purchases = {} -- the purchases asked for whose money did not go yet, oldest first: { item, count, price, at }

local function CountByKey(list)
  local counts = {}
  for _, entry in ipairs(list) do
    counts[entry.key] = (counts[entry.key] or 0) + 1
  end
  return counts
end

-- The entry with this key, the last one in the list (the newest).
local function Find(list, key)
  for index = #list, 1, -1 do
    if list[index].key == key then
      return list[index]
    end
  end
end

-- A visit starts: list is the buyback list now (what was sold before belongs to earlier visits).
function LedgerMerchant.Open(list)
  picture = list
  sales, buybacks = {}, {}
end

-- The player asks to buy back entry `index` of the buyback list.
function LedgerMerchant.NoteBuyback(index)
  local entry = picture[index]
  if entry then
    buybacks[entry.key] = (buybacks[entry.key] or 0) + 1
  end
end

-- The buyback list changed to list (at `now`). Entries that came in are sales of this visit. An entry that left after a
-- buyback asked for it takes back the newest sale of it in this visit; returns the buybacks of items sold in an earlier
-- visit (already booked), each { item, count, price }, to be booked as purchases.
function LedgerMerchant.Update(list, now)
  local before, after = CountByKey(picture), CountByKey(list)
  local boughtBack = {}
  for key, count in pairs(after) do
    for _ = 1, count - (before[key] or 0) do
      local entry = Find(list, key)
      sales[#sales + 1] = { item = entry.item, count = entry.count, price = entry.price, junk = entry.junk, at = now }
    end
  end
  for key, count in pairs(before) do
    for _ = 1, count - (after[key] or 0) do
      -- an entry that left without a buyback fell out of the full list
      if (buybacks[key] or 0) > 0 then
        buybacks[key] = buybacks[key] - 1
        local entry = Find(picture, key)
        local taken = false
        for index = #sales, 1, -1 do
          local sale = sales[index]
          if sale.item == entry.item and sale.count == entry.count and sale.price == entry.price then
            table.remove(sales, index)
            taken = true
            break
          end
        end
        if not taken then
          boughtBack[#boughtBack + 1] = { item = entry.item, count = entry.count, price = entry.price }
        end
      end
    end
  end
  picture = list
  return boughtBack
end

-- The player asks to buy count of the item for price (copper for all of them) at `now`.
function LedgerMerchant.NoteBuy(item, count, price, now)
  purchases[#purchases + 1] = { item = item, count = count, price = price, at = now }
end

-- The money went from `before` to `after` at `now`. Returns the purchases it paid for, oldest first: as many of the
-- waiting ones, in order, as the money that went covers (what is left was something else, a repair). Purchases waiting
-- longer than BUY_TIMEOUT are dropped.
function LedgerMerchant.MoneyChanged(before, after, now)
  while purchases[1] and now - purchases[1].at > BUY_TIMEOUT do
    table.remove(purchases, 1)
  end
  local paid = {}
  local spent = before - after
  while purchases[1] and spent >= purchases[1].price do
    local purchase = table.remove(purchases, 1)
    spent = spent - purchase.price
    paid[#paid + 1] = purchase
  end
  return paid
end

-- The visit ends: returns its sales, oldest first, and forgets them. A second call returns nothing. Purchases still
-- waiting for their money stay (it may come after the merchant closed).
function LedgerMerchant.Close()
  local done = sales
  picture, sales, buybacks = {}, {}, {}
  return done
end
