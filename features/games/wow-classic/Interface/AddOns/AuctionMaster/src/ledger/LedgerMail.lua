local addonName, AM = ...

-- Books the auction mails when the player takes them (doc/notes/ledger.md, "Booking mails on take"): keeps the latest
-- picture of the auction mails in the inbox and the takes asked for, and tells which takes went through. Plain data
-- only, no game calls; LedgerRecorder.lua reads the inbox and hooks the takes.
--
-- A mail as read from the inbox:
--   sold     { kind = "sold", itemName, count, price, deposit, fee, sentAt }
--   expired  { kind = "expired", item, count (attached), subjectCount (nil for a single item), sentAt }
--   canceled { kind = "canceled", ... } as expired (the item of a canceled auction comes back the same way)
--   bought   { kind = "bought", item, count (attached), boughtCount (the invoice's), price (paid), sentAt }: a won
--            auction. Its mail stays in the inbox once the item is taken, so a take is told by the attachments going.
AM.LedgerMail = {}
local LedgerMail = AM.LedgerMail

-- How long the auction house's mails stay in the inbox; the days left count down from here.
local MAIL_DAYS = 30
local DAY = 24 * 3600

-- The auction mails of the inbox as last read, by index; nil while the mailbox is closed.
local picture

-- The takes asked for and not confirmed yet, oldest first: { mail, before }, before being how many mails like it were
-- whole in the inbox. Kept for the session, so a take answered after the mailbox closed is settled on the next read.
local pending = {}

-- When the mail was sent, in Unix seconds; nil without the days left.
function LedgerMail.SendTime(now, daysLeft)
  if not daysLeft then
    return nil
  end
  return math.floor(now - (MAIL_DAYS - daysLeft) * DAY + 0.5)
end

-- The item name and count of an auction mail's subject ("auction expired", "auction cancelled"); count is nil for a
-- single item. nil if the subject is not of that format. format: the game's subject text with "%s" for the item.
function LedgerMail.ParseSubject(subject, format)
  if not subject or not format then
    return nil
  end
  local pattern = format:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("%%%%s", "(.+)", 1)
  local name = subject:match("^" .. pattern .. "$")
  if not name then
    return nil
  end
  local base, count = name:match("^(.-) %((%d+)%)$")
  if base then
    return base, tonumber(count)
  end
  return name
end

-- Two mails of the same kind and contents. Only what cannot change while a mail sits in the inbox: not the money (held
-- back for a while after a sale) and not the attachments of an expired or won mail (taken one stack at a time).
local function Same(a, b)
  if a.kind ~= b.kind then
    return false
  end
  if a.kind == "sold" then
    return a.itemName == b.itemName and a.count == b.count and a.price == b.price and a.deposit == b.deposit
      and a.fee == b.fee
  end
  if a.kind == "bought" then
    return a.item == b.item and a.boughtCount == b.boughtCount and a.price == b.price
  end
  return a.item == b.item and a.subjectCount == b.subjectCount
end

-- Not taken from yet. A sold mail goes in one take; an expired one is whole while it holds all the subject names, a
-- won one while it holds all that was bought.
local function Whole(mail)
  if mail.kind == "sold" then
    return true
  end
  local all = mail.kind == "bought" and mail.boughtCount or mail.subjectCount
  return (mail.count or 0) > 0 and (not all or mail.count >= all)
end

-- mails: by inbox index, with holes for the mails that are not auction mails.
local function CountWhole(mails, mail)
  local count = 0
  for _, other in pairs(mails) do
    if Same(other, mail) and Whole(other) then
      count = count + 1
    end
  end
  return count
end

-- The player asked to take (from) the mail at this index of the inbox. Only a whole auction mail can be booked: a take
-- from a mail already started was booked with the first one.
function LedgerMail.NoteTake(index)
  local mail = picture and picture[index]
  if mail and Whole(mail) then
    pending[#pending + 1] = { mail = mail, before = CountWhole(picture, mail) }
  end
end

-- The inbox was read again: returns the mails whose take went through, each to be booked once. A take went through
-- when fewer mails like it are whole than at the take; the others wait for the next read. mails: the auction mails by
-- inbox index, other mails left out (holes).
function LedgerMail.Update(mails)
  local confirmed, kept = {}, {}
  for _, take in ipairs(pending) do
    local settled = 0
    for _, done in ipairs(confirmed) do
      if Same(done, take.mail) then
        settled = settled + 1
      end
    end
    local after = CountWhole(mails, take.mail)
    if after < take.before - settled then
      confirmed[#confirmed + 1] = take.mail
    else
      take.before = after
      kept[#kept + 1] = take
    end
  end
  pending = kept
  picture = mails
  return confirmed
end

-- The mailbox closed: no picture until the next read, the takes asked for stay.
function LedgerMail.Close()
  picture = nil
end
