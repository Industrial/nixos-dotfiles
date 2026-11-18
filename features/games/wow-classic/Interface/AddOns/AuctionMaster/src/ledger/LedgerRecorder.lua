local addonName, AM = ...

-- Feeds the ledger from the game: notes what the player posts (hooks on C_AuctionHouse, read only, nothing is changed)
-- and records the auction once the game confirms it with AUCTION_HOUSE_AUCTION_CREATED; books the auction mails the
-- player takes (sold, won, expired, canceled); reconciles the open auctions with the owned auctions list whenever the game has read it.

if not (C_AuctionHouse and C_AuctionHouse.PostItem and C_AuctionHouse.PostCommodity) then
  return
end

-- What the game charges as deposit for one auction, nil if it cannot say (then the ledger keeps it unknown). For a
-- commodity that is the whole stack; for an item one copy (the game's sell frame asks for all copies at once, the sum).
local function GetDeposit(location, itemId, count, duration, commodity)
  local ok, deposit = pcall(function()
    if commodity then
      return C_AuctionHouse.CalculateCommodityDeposit(itemId, duration, count)
    end
    return C_AuctionHouse.CalculateItemDeposit(location, duration, 1)
  end)
  return ok and deposit or nil
end

-- count and price: those of one auction (price is the total for its stack); auctions: how many the post creates.
local function NotePost(location, duration, count, price, auctions, commodity)
  local ok, err = pcall(function()
    local item = AM.ItemDbKey.FromLocation(location)
    local itemId = item and AM.ItemDbKey.GetItemId(item)
    if not item or not price or not count or not auctions then
      AM.DebugLog.Log("ledger", "post not noted: item %s price %s count %s auctions %s", item, price, count, auctions)
      return
    end
    local deposit = GetDeposit(location, itemId, count, duration, commodity)
    AM.Ledger.NotePost(UnitGUID("player"), item, count, price, deposit, duration, auctions)
  end)
  if not ok then
    AM.DebugLog.Log("ledger", "post not noted: %s", err)
  end
end

-- The quantity of an item is the number of copies posted, one auction each (the game's sell frame shows quantity
-- times buyout as the total), so the buyout is the price of one auction.
local function OnPostItem(location, duration, quantity, bid, buyout)
  NotePost(location, duration, 1, buyout or bid, quantity, false)
end

local function OnPostCommodity(location, duration, quantity, unitPrice)
  NotePost(location, duration, quantity, unitPrice and quantity and unitPrice * quantity, 1, true)
end

-- A post the game warns about (an unusual price) is answered with AUCTION_HOUSE_POST_WARNING instead of an auction; the
-- player's confirmation is sent as a post of its own with the same arguments.
for name, handler in pairs({ PostItem = OnPostItem, ConfirmPostItem = OnPostItem, PostCommodity = OnPostCommodity,
  ConfirmPostCommodity = OnPostCommodity }) do
  if C_AuctionHouse[name] then
    hooksecurefunc(C_AuctionHouse, name, handler)
  end
end

-- Every post is answered in the order the posts were sent: with one AUCTION_HOUSE_AUCTION_CREATED per auction, or with
-- one of the others when it (or the rest of a post of several copies) is not created.
local frame = CreateFrame("Frame")
for _, event in ipairs({ "AUCTION_HOUSE_AUCTION_CREATED", "AUCTION_HOUSE_POST_WARNING", "AUCTION_HOUSE_POST_ERROR",
  "AUCTION_MULTISELL_FAILURE" }) do
  pcall(frame.RegisterEvent, frame, event)
end
-- The auction house mails of the open inbox, written to the debug log once per mail and session, to check what the
-- game reports for sold, canceled and expired auctions (doc/notes/ledger.md). Mails that can be answered come from
-- players and are left out.
local loggedMails = {}
local mailOpen = false
local MAX_ATTACHMENTS = ATTACHMENTS_MAX_RECEIVE or 16

local function LogAuctionMails()
  if not AM.DebugLog.IsEnabled() then
    return
  end
  for index = 1, (GetInboxNumItems()) do
    local _, _, sender, subject, money, _, daysLeft, itemCount, _, wasReturned, _, canReply, _, firstQuantity,
      firstLink = GetInboxHeaderInfo(index)
    local invoiceType, itemName, buyer, bid, buyout, deposit, fee, moneyDelay, etaHour, etaMin, count =
      GetInboxInvoiceInfo(index)
    if invoiceType or not canReply then
      local line = string.format("mail %d from %s \"%s\": money %s, items %s (first %s x%s), returned %s | invoice %s, "
        .. "item %s x%s, buyer %s, bid %s, buyout %s, deposit %s, fee %s, delay %s, eta %s:%s",
        index, tostring(sender), tostring(subject), tostring(money), tostring(itemCount), tostring(firstLink),
        tostring(firstQuantity), tostring(wasReturned), tostring(invoiceType), tostring(itemName), tostring(count),
        tostring(buyer), tostring(bid), tostring(buyout), tostring(deposit), tostring(fee), tostring(moneyDelay),
        tostring(etaHour), tostring(etaMin))
      if not loggedMails[line] then
        loggedMails[line] = true
        AM.DebugLog.Log("ledger", "%s, days left %s", line, daysLeft and string.format("%.4f", daysLeft) or "nil")
      end
    end
  end
end

-- The item and count attached to an expired auction's mail: the item of the first attachment, all its stacks summed.
local function ReadAttachments(index)
  local item, count = nil, 0
  for slot = 1, MAX_ATTACHMENTS do
    local link = GetInboxItemLink(index, slot)
    local key = link and AM.ItemDbKey.FromLink(link)
    if key then
      item = item or key
      if key == item then
        count = count + (select(4, GetInboxItem(index, slot)) or 1)
      end
    end
  end
  return item, count
end

-- The subjects of the mails that bring an auction's item back, by the kind LedgerMail knows them as. A subject the
-- game does not define on a flavor is left out (its mails are then never recognized).
local RETURN_SUBJECTS = {
  { kind = "expired", format = AUCTION_EXPIRED_MAIL_SUBJECT },
  { kind = "canceled", format = AUCTION_REMOVED_MAIL_SUBJECT },
}

-- One mail of the inbox as LedgerMail knows it, nil if it is no mail of a sold, won, expired or canceled auction (or
-- cannot be read). A won mail whose item was taken is nil too: it stays in the inbox, empty.
local function ReadMail(index, now)
  local _, _, _, subject, _, _, daysLeft, hasItem, _, _, _, canReply = GetInboxHeaderInfo(index)
  local sentAt = AM.LedgerMail.SendTime(now, daysLeft)
  local invoiceType, itemName, _, bid, _, deposit, fee, _, _, _, count = GetInboxInvoiceInfo(index)
  if invoiceType == "seller" then
    if itemName and count and bid then
      return { kind = "sold", itemName = itemName, count = count, price = bid, deposit = deposit, fee = fee,
        sentAt = sentAt }
    end
    return nil
  end
  if invoiceType == "buyer" then
    -- the item from the attachment (the invoice has only its name), the count and price paid from the invoice
    local item, attached = ReadAttachments(index)
    if item and count and bid then
      return { kind = "bought", item = item, count = attached, boughtCount = count, price = bid, sentAt = sentAt }
    end
    return nil
  end
  if invoiceType or canReply or not hasItem then
    return nil
  end
  for _, returned in ipairs(RETURN_SUBJECTS) do
    local name, subjectCount = AM.LedgerMail.ParseSubject(subject, returned.format)
    if name then
      local item, attached = ReadAttachments(index)
      if not item then
        return nil
      end
      return { kind = returned.kind, item = item, count = attached, subjectCount = subjectCount, sentAt = sentAt }
    end
  end
  return nil
end

-- The name of an item of the ledger, nil while the game has not loaded it.
local function ItemName(item)
  local itemId = AM.ItemDbKey.GetItemId(item)
  return itemId and (C_Item.GetItemInfo(itemId)) or nil
end

-- Asks the game for the item data of the open auctions, so their names are known by the time a sale mail is taken.
local function LoadOpenItemNames()
  for _, item in ipairs(AM.Ledger.GetOpenItems(UnitGUID("player"))) do
    local itemId = AM.ItemDbKey.GetItemId(item)
    if itemId and C_Item.RequestLoadItemDataByID then
      C_Item.RequestLoadItemDataByID(itemId)
    end
  end
end

-- Reads the auction mails into the picture of LedgerMail and books the mails whose take went through.
local function ReadInbox()
  local guid, now, mails = UnitGUID("player"), time(), {}
  for index = 1, (GetInboxNumItems()) do
    mails[index] = ReadMail(index, now)
  end
  for _, mail in ipairs(AM.LedgerMail.Update(mails)) do
    if mail.kind == "sold" then
      AM.Ledger.BookSale(guid, mail.itemName, mail.count, mail.price, mail.deposit, mail.fee, mail.sentAt, ItemName)
    elseif mail.kind == "bought" then
      AM.Ledger.BookPurchase(guid, mail.item, mail.boughtCount, mail.price, mail.sentAt)
    elseif mail.kind == "canceled" then
      AM.Ledger.BookCancelMail(guid, mail.item, mail.count, mail.sentAt)
    else
      AM.Ledger.BookExpiry(guid, mail.item, mail.count, mail.sentAt)
    end
  end
end

local function NoteTake(index)
  AM.DebugLog.Log("ledger", "take of mail %s asked for", index)
  AM.LedgerMail.NoteTake(index)
end

local canReadMail = GetInboxNumItems and GetInboxHeaderInfo and GetInboxInvoiceInfo and GetInboxItem
  and GetInboxItemLink
for _, event in ipairs(canReadMail and { "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE" } or {}) do
  pcall(frame.RegisterEvent, frame, event)
end

-- The player (or an addon) takes a mail's money or items. After the call, read only: the hook only notes the request,
-- the next inbox update tells whether it went through.
if canReadMail then
  for _, name in ipairs({ "TakeInboxMoney", "TakeInboxItem", "AutoLootMailItem" }) do
    if _G[name] then
      hooksecurefunc(name, function(index)
        pcall(NoteTake, index)
      end)
    end
  end
end

-- The owned auctions list, once the game has all of it (it is queried by the game's own Auctions tab, never by us).
-- The buyout of a commodity is per unit (the list shows 148 for the 12 Geringe Magieessenz posted at 1776), so the
-- price of the stack is buyout times count. A single item's buyout is its price. Whether an item (not a commodity)
-- with a count above 1 in one auction exists, and whether its buyout is the stack or one copy, is not known: its price
-- stays unknown and it is logged. Each auction is logged once per session to check this per flavor.
local loggedOwned = {}

-- The price of an owned auction's whole stack, nil if not known.
local function OwnedPrice(info)
  local buyout, count = info.buyoutAmount, info.quantity
  if not buyout or not count then
    return nil
  end
  if count == 1 then
    return buyout
  end
  local keyInfo = C_AuctionHouse.GetItemKeyInfo(info.itemKey)
  if keyInfo and keyInfo.isCommodity then
    return buyout * count
  end
  local line = string.format("owned auction %s: price unknown, %s x%s buyout %s (%s)", info.auctionID,
    tostring(info.itemLink), count, buyout, keyInfo and "item" or "no item key info")
  if not loggedOwned[line] then
    loggedOwned[line] = true
    AM.DebugLog.Log("ledger", "%s", line)
  end
  return nil
end

local function ReadOwnedAuctions()
  if not (C_AuctionHouse.HasFullOwnedAuctionResults and C_AuctionHouse.HasFullOwnedAuctionResults()) then
    return
  end
  local owned = {}
  for index = 1, C_AuctionHouse.GetNumOwnedAuctions() do
    local info = C_AuctionHouse.GetOwnedAuctionInfo(index)
    if not info then
      AM.DebugLog.Log("ledger", "owned auctions not read: no info for %s", index)
      return
    end
    local item = AM.ItemDbKey.FromLink(info.itemLink) or AM.ItemDbKey.FromAhItemKey(info.itemKey)
    if not item then
      AM.DebugLog.Log("ledger", "owned auctions not read: no item for auction %s", info.auctionID)
      return
    end
    local sold = info.status == Enum.AuctionStatus.Sold
    owned[#owned + 1] = { auctionId = info.auctionID, item = item, count = info.quantity,
      price = OwnedPrice(info), sold = sold }
    local line = string.format("owned auction %s: %s x%s buyout %s bid %s sold %s time left %s/%s", info.auctionID,
      item, info.quantity, tostring(info.buyoutAmount), tostring(info.bidAmount), tostring(sold),
      tostring(info.timeLeftSeconds), tostring(info.timeLeft))
    if not loggedOwned[line] then
      loggedOwned[line] = true
      AM.DebugLog.Log("ledger", "%s", line)
    end
  end
  AM.Ledger.ReconcileOwned(UnitGUID("player"), owned)
end

if C_AuctionHouse.GetNumOwnedAuctions and C_AuctionHouse.GetOwnedAuctionInfo then
  pcall(frame.RegisterEvent, frame, "OWNED_AUCTIONS_UPDATED")
end

-- The player (or an addon) asks to cancel an auction. After the call, read only: the next owned auctions list without
-- it confirms the cancel (Ledger.ReconcileOwned). The game's cancel cost is logged to learn what it means per flavor.
if C_AuctionHouse.CancelAuction then
  hooksecurefunc(C_AuctionHouse, "CancelAuction", function(auctionId)
    pcall(function()
      local cost = C_AuctionHouse.GetCancelCost and C_AuctionHouse.GetCancelCost(auctionId)
      local _, item, count, price, deposit = AM.Ledger.GetOpen(auctionId)
      AM.DebugLog.Log("ledger", "cancel of auction %s asked for: %s x%s price %s deposit %s, cancel cost %s",
        auctionId, item, count, price, deposit, cost)
      AM.Ledger.NoteCancel(auctionId)
    end)
  end)
end

frame:SetScript("OnEvent", function(_, event, auctionId)
  if event == "AUCTION_HOUSE_AUCTION_CREATED" then
    AM.Ledger.ResolveCreated(auctionId)
  elseif event == "OWNED_AUCTIONS_UPDATED" then
    local ok, err = pcall(ReadOwnedAuctions)
    if not ok then
      AM.DebugLog.Log("ledger", "owned auctions not read: %s", err)
    end
  elseif event == "MAIL_SHOW" then
    mailOpen = true
    pcall(LoadOpenItemNames)
  elseif event == "MAIL_CLOSED" then
    mailOpen = false
    AM.LedgerMail.Close()
  elseif event == "MAIL_INBOX_UPDATE" then
    -- not on MAIL_SHOW: the inbox may not be loaded yet
    if mailOpen then
      LogAuctionMails()
      local ok, err = pcall(ReadInbox)
      if not ok then
        AM.DebugLog.Log("ledger", "inbox not read: %s", err)
      end
    end
  else
    AM.Ledger.DropPost()
  end
end)
