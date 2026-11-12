local addonName, AM = ...

-- What lies in the mailboxes of the characters of this faction, kept in the faction object "mail": GUID ->
-- { items, sentAt }, items being a map of itemId to the amount. The mailbox can only be read while it is open, so what
-- is known of it is built from three sources:
--   * the open mailbox of the current character: this is the truth and replaces everything assumed before;
--   * a commodity bought at the auction house: it arrives in the mailbox of the current character;
--   * a mail sent to another character of ours: the items are in its mailbox.
-- The last two are assumptions (sentAt: since when) until that character opens its mailbox, and are dropped after the
-- 30 days a mail lasts, as it may have expired or been returned unseen. Bags and bank are in Inventory.lua.
local Mailbox = {}
AM.Mailbox = Mailbox

local MAIL_LIFETIME = 30 * 24 * 3600
local MAX_ATTACHMENTS = ATTACHMENTS_MAX_RECEIVE or 16
local mailOpen = false
local purchase -- { itemId, quantity } of the commodity purchase waiting for its result
local sending -- { guid, items } of the mail waiting for its result
local draft = {} -- the attachments of the mail being written, itemId -> amount

local function GetEntry(guid, create)
  local mail = AM.Database.GetFactionObject("mail")
  local entry = mail[guid]
  if not entry and create then
    entry = { items = {} }
    mail[guid] = entry
  end
  if entry and entry.sentAt and time() - entry.sentAt > MAIL_LIFETIME then
    entry.items = {}
    entry.sentAt = nil
  end
  return entry
end

-- Items on their way to the mailbox of the character, not seen there yet.
local function AddItems(guid, items)
  local entry = GetEntry(guid, true)
  for itemId, count in pairs(items) do
    entry.items[itemId] = (entry.items[itemId] or 0) + count
  end
  entry.sentAt = entry.sentAt or time()
  AM.Events.Fire("MAIL_CHANGED")
end

-- How many of the item (all the qualities in itemIds) the character has in its mailbox, as far as known.
function Mailbox.GetCount(guid, itemIds)
  local entry = GetEntry(guid)
  local total = 0
  for _, itemId in ipairs(itemIds) do
    total = total + (entry and entry.items[itemId] or 0)
  end
  return total
end

-- Forgets a character (deleted).
function Mailbox.ForgetCharacter(guid)
  AM.Database.GetFactionObject("mail")[guid] = nil
end

-- The attachments of all mails in the open mailbox as itemId -> amount.
local function ReadInbox()
  local counts = {}
  for mailIndex = 1, (GetInboxNumItems()) do
    local hasItem = select(8, GetInboxHeaderInfo(mailIndex))
    for attachment = 1, hasItem and MAX_ATTACHMENTS or 0 do
      local _, itemId, _, count = GetInboxItem(mailIndex, attachment)
      if itemId then
        counts[itemId] = (counts[itemId] or 0) + (count or 1)
      end
    end
  end
  return counts
end

local function SameCounts(a, b)
  for itemId, count in pairs(a) do
    if b[itemId] ~= count then
      return false
    end
  end
  for itemId in pairs(b) do
    if not a[itemId] then
      return false
    end
  end
  return true
end

-- What is in the open mailbox is the truth, whatever was assumed before about sent or bought items.
local function ScanInbox()
  local entry = GetEntry(UnitGUID("player"), true)
  local items = ReadInbox()
  local changed = not SameCounts(items, entry.items)
  entry.items = items
  entry.sentAt = nil
  if changed then
    AM.Events.Fire("MAIL_CHANGED")
  end
end

-- Lower case without spaces and hyphens, so that "Name-Realm", "Name Realm" and "name realm" are the same.
local function Normalize(text)
  return (text or ""):gsub("[%s%-]", ""):lower()
end

-- The GUID of the character the recipient of a mail is, nil if it is none of the characters AuctionMaster knows. The
-- recipient is the name with its realm ("Name-Realm"; on Forever the game reports the surname where the realm would
-- be and the mail frame shows "Name Surname"), or the name alone: then a character of the own realm, or else one of a
-- connected realm if only one known character has that name.
local function FindRecipient(recipient)
  local wanted = Normalize(recipient)
  local own = Normalize(GetNormalizedRealmName())
  local byName
  for guid, character in pairs(AM.Database.GetGlobalObject("characters")) do
    if type(character) == "table" and character.name then
      local name, realm = Normalize(character.name), Normalize(character.realm)
      if wanted == name .. realm then
        return guid
      elseif wanted == name then
        if realm == own then
          return guid
        end
        byName = byName == nil and guid or false -- false: the name is ambiguous
      end
    end
  end
  return byName or nil
end

-- The items attached to the mail being written as itemId -> amount.
local function ReadAttachments()
  local counts = {}
  for slot = 1, ATTACHMENTS_MAX_SEND or 12 do
    local _, itemId, _, count = GetSendMailItem(slot)
    if itemId then
      counts[itemId] = (counts[itemId] or 0) + (count or 1)
    end
  end
  return counts
end

-- Called when a mail is sent: remembers who gets what until the game says whether it went out. The attachments are
-- taken from the mail as it was last written if the game has already emptied the slots.
local function OnSendMail(recipient)
  local guid = FindRecipient(recipient and strtrim(recipient))
  local items = ReadAttachments()
  if not next(items) then
    items = draft
  end
  sending = guid and next(items) and { guid = guid, items = items } or nil
end

if GetInboxNumItems and GetInboxItem and GetInboxHeaderInfo then
  local frame = CreateFrame("Frame")
  -- not every client has every event, and registering an unknown one is an error
  for _, event in ipairs({ "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE", "MAIL_SEND_INFO_UPDATE", "MAIL_SEND_SUCCESS",
    "MAIL_FAILED",
    "COMMODITY_PURCHASE_SUCCEEDED", "COMMODITY_PURCHASE_FAILED" }) do
    pcall(frame.RegisterEvent, frame, event)
  end
  if SendMail and GetSendMailItem then
    hooksecurefunc("SendMail", OnSendMail)
  end
  -- The purchase is confirmed with item and amount, the result comes as a separate event without them.
  if C_AuctionHouse and C_AuctionHouse.ConfirmCommoditiesPurchase then
    hooksecurefunc(C_AuctionHouse, "ConfirmCommoditiesPurchase", function(itemId, quantity)
      purchase = { itemId = itemId, quantity = quantity }
    end)
  end
  frame:SetScript("OnEvent", function(_, event)
    if event == "MAIL_SHOW" then
      mailOpen = true
    elseif event == "MAIL_CLOSED" then
      mailOpen = false
    elseif event == "MAIL_INBOX_UPDATE" then
      -- not on MAIL_SHOW: the inbox may not be loaded yet and would look empty
      if mailOpen then
        ScanInbox()
      end
    elseif event == "MAIL_SEND_INFO_UPDATE" then
      -- the attachments of the mail being written changed (also empties it after a send, which comes after the hook)
      draft = ReadAttachments()
    elseif event == "MAIL_SEND_SUCCESS" then
      local mail = sending
      sending = nil
      draft = {}
      if mail then
        AddItems(mail.guid, mail.items)
      end
    elseif event == "MAIL_FAILED" then
      sending = nil
    else -- the result of a commodity purchase
      local bought = purchase
      purchase = nil
      if bought and event == "COMMODITY_PURCHASE_SUCCEEDED" then
        AddItems(UnitGUID("player"), { [bought.itemId] = bought.quantity })
      end
    end
  end)
end
