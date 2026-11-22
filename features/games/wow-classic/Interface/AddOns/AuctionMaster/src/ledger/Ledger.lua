local addonName, AM = ...

-- The ledger: what happened to the player's auctions and vendor trades and what they cost or earned, kept in the
-- faction object "ledger" (the auction house is per faction). Only this file knows the layout; everything else asks through the readers.
-- Plan and decisions: doc/notes/ledger.md. This is not market data: it never touches ItemStore.
--
--   chars   list of the GUIDs of the characters that have events, an event holds the index
--   events  one positional array per event, in the order booked (slot names below; slots that do not apply stay empty)
--   open    the auctions we know are running, by auction id: { char, item, count, price, deposit, createdAt, duration,
--           missingSince }. An auction adopted from the owned auctions list has no deposit, creation and duration.
--           missingSince: when a full owned auctions list first lacked it (it ended, its mail not taken yet).
--   days    the events older than the days kept (setting "ledgerDays"), combined by Combine into one row per local
--           day, character and item: { start (the day's local midnight), char, item (false for junk), figure, value,
--           figure, value, ... } (figure: the number of its name in FIELDS; figures that are 0 are left out)
--   months  the days older than a year, combined the same way into one row per local month (start: its 1st)
--   stock   the units in stock when the events were combined, the starting stock of CostBasis: item, char, count,
--           price, item, char, ... (oldest first per item)
--
-- All amounts are copper for the whole stack. A deposit that is not known stays empty, it is never guessed.
AM.Ledger = {}
local Ledger = AM.Ledger

-- event types
Ledger.CREATED = 1
Ledger.SOLD = 2
-- canceled and expired: price is what the units that came back were posted for (empty without a buyout, and in events
-- booked before it was stored). Not money that moved: only the price they did not sell at (GetPriceRanges).
Ledger.CANCELED = 3
Ledger.EXPIRED = 4
-- ended without us seeing how (its mail was never taken, or not recognized): neither sold nor lost, left out of Net
Ledger.UNKNOWN = 5
-- bought at the auction house (a buyout or a won bid; price: what was paid for the stack). Not a cost by itself: the
-- units go into stock at that price, and a later sale of the item takes the cost of the oldest units bought.
Ledger.BOUGHT = 6
-- sold to a merchant (price: what the merchant paid for the stack, no fee). Uses up stock like an auction sale.
Ledger.VENDOR_SOLD = 7
-- bought from a merchant for gold (price: what was paid for the stack). Goes into stock like an auction purchase.
Ledger.VENDOR_BOUGHT = 8
-- the junk (poor quality items) sold in one visit to a merchant, summed up: no item, count the items, price the sum
Ledger.JUNK_SOLD = 9
-- crafted: count of the item made from the reagents (slot REAGENTS: itemDbKey, count, itemDbKey, count, ...). No price:
-- the reagents leave stock and what they cost goes with the crafted units (CostBasis). Adds nothing to Net.
Ledger.CRAFTED = 10
-- looted: count of the item taken from a loot window (mob, skinning, gathering, fishing). No price: the units go into
-- stock at no cost, so a later sale takes them as found in stock (at no cost). Adds nothing to Net.
Ledger.LOOTED = 11
-- used up: count of the item that left the characters' holdings without an event (eaten, equipped, destroyed, used
-- for a quest or a craft not booked), found by ReconcileStock. No price: the units leave stock, looted ones (no cost)
-- first, then the oldest; what they cost leaves stock with them, outside Net (not a trading loss).
Ledger.USED_UP = 12
-- disenchanted: count of the item destroyed for materials (slot REAGENTS: itemDbKey, count, ... of the materials, slot
-- VALUES: what one unit of each sold for when booked, nil when any was not known). No price: the units leave stock as a
-- sale would (oldest first) and what they cost goes to the materials, split by value (by count without values). Adds
-- nothing to Net.
Ledger.DISENCHANTED = 13

-- What adds units to stock and what uses them up.
local STOCK_IN = { [Ledger.BOUGHT] = true, [Ledger.VENDOR_BOUGHT] = true, [Ledger.LOOTED] = true }
local STOCK_OUT = { [Ledger.SOLD] = true, [Ledger.VENDOR_SOLD] = true }

-- slots of an event
local TIME, TYPE, CHAR, ITEM, COUNT, PRICE, DEPOSIT, FEE = 1, 2, 3, 4, 5, 6, 7, 8
-- a crafted or disenchanted event has no price, deposit or fee: its lists take those slots, so no gap is stored
local REAGENTS = 6
local VALUES = 7
local HAS_LISTS = { [Ledger.CRAFTED] = true, [Ledger.DISENCHANTED] = true }
-- where the lists were stored before (slots 6 to 8 left empty)
local OLD_REAGENTS, OLD_VALUES = 9, 10

-- price, deposit and fee of an event; nil for an event whose lists take those slots
local function Money(event)
  if HAS_LISTS[event[TYPE]] then
    return nil
  end
  return event[PRICE], event[DEPOSIT], event[FEE]
end

-- slots of an open auction
local OPEN_CHAR, OPEN_ITEM, OPEN_COUNT, OPEN_PRICE, OPEN_DEPOSIT, OPEN_CREATED, OPEN_DURATION = 1, 2, 3, 4, 5, 6, 7
local OPEN_MISSING = 8

-- An auction that ended stays open until its mail is taken. Once it has been missing from the owned auctions for
-- longer than a mail stays in the inbox (30 days, a day more for mails delivered late), it is closed as unknown.
local MISSING_TIMEOUT = 31 * 24 * 3600

-- The game refreshes the owned auctions right after a cancel; a request older than this was not carried out.
local CANCEL_TIMEOUT = 300

-- The auctions the player asked to cancel and when, by auction id. Kept in memory only.
local cancelRequests = {}

-- The player asked the game to cancel this auction. It is booked as canceled once a full owned auctions list without
-- it comes within CANCEL_TIMEOUT (ReconcileOwned); AUCTION_CANCELED cannot confirm it, its payload is not always the
-- auction id on Forever.
function Ledger.NoteCancel(auctionId)
  cancelRequests[auctionId] = time()
end

-- A post the game has not confirmed yet is forgotten after this long.
local POST_TIMEOUT = 60

-- The posts sent to the game that it has not answered yet, oldest first: { guid, item, count, price, deposit,
-- duration, auctions, at }, auctions being how many auctions of it are still to come. Kept in memory only.
local pendingPosts = {}

-- Moves the lists of crafted and disenchanted events stored in slots 9 and 10 (the old shape, recognized by itself)
-- into slots 6 and 7. Idempotent; once per ledger table and session.
local migrated = setmetatable({}, { __mode = "k" })
local function MigrateLists(state)
  if migrated[state] then
    return
  end
  migrated[state] = true
  for _, event in ipairs(state.events) do
    if HAS_LISTS[event[TYPE]] and type(event[OLD_REAGENTS]) == "table" then
      event[REAGENTS], event[VALUES] = event[OLD_REAGENTS], event[OLD_VALUES]
      event[FEE], event[OLD_REAGENTS], event[OLD_VALUES] = nil, nil, nil
    end
  end
end

-- How many days every event is kept as it is (the Journal lists them); older ones are combined (Combine). Global
-- object "settings": a preference of the player, the same for every auction house.
Ledger.KEEP_DAYS = { 30, 60, 90 }
AM.Settings.Define("ledgerDays", 30)

function Ledger.GetKeepDays()
  local days = AM.Settings.Get("ledgerDays")
  for _, allowed in ipairs(Ledger.KEEP_DAYS) do
    if days == allowed then
      return days
    end
  end
  return Ledger.KEEP_DAYS[1]
end

local Combine
-- the ledger tables combined in this session (Combine runs once per table and session, and when the setting changes)
local combined = setmetatable({}, { __mode = "k" })

local function State()
  local state = AM.Database.GetFactionObject("ledger")
  state.chars = state.chars or {}
  state.events = state.events or {}
  state.open = state.open or {}
  state.days = state.days or {}
  state.months = state.months or {}
  state.stock = state.stock or {}
  MigrateLists(state)
  if not combined[state] then
    combined[state] = true
    Combine(state, time())
  end
  return state
end

-- The ledger to book into; nil while the demo is shown (StartDemo): nothing is booked then, so the demo stays as built
-- and nothing real is mixed into it (or lost with it when it is thrown away).
local function Writable()
  local state = State()
  if state.demo then
    return nil
  end
  return state
end

local function CharIndex(state, guid)
  for index, known in ipairs(state.chars) do
    if known == guid then
      return index
    end
  end
  state.chars[#state.chars + 1] = guid
  return #state.chars
end

-- Adds the "auction created" event of an auction and remembers it as open. An auction we already know is ignored,
-- unless it was only adopted from the owned auctions list (the list came before the game confirmed our post).
function Ledger.RecordCreated(auctionId, guid, item, count, price, deposit, duration)
  local state = Writable()
  if not state then
    return
  end
  local known = state.open[auctionId]
  if known and known[OPEN_CREATED] then
    return
  end
  local now = time()
  local char = CharIndex(state, guid)
  state.events[#state.events + 1] = { now, Ledger.CREATED, char, item, count, price, deposit }
  state.open[auctionId] = { char, item, count, price, deposit, now, duration }
  AM.DebugLog.Log("ledger", "created auction %s: %s x%s price %s deposit %s", auctionId, item, count, price, deposit)
  AM.Events.Fire("LEDGER_CHANGED")
end

-- The oldest post still waiting for its answer; nil if there is none. Posts the game did not answer in time are
-- dropped on the way. The time counts from the last answer, as the auctions of one post come one after the other.
local function OldestPost()
  local now = time()
  while pendingPosts[1] do
    local post = pendingPosts[1]
    if now - post.at <= POST_TIMEOUT then
      return post
    end
    table.remove(pendingPosts, 1)
    AM.DebugLog.Log("ledger", "post of %s x%s dropped: no answer", post.item, post.count)
  end
end

-- The player sent a post to the game. The game answers each post in order: with the auction id of each auction it
-- creates (ResolveCreated), or without an auction (DropPost). A posting addon can send the next post before the
-- answer, so the posts queue up. auctions: how many auctions the post creates (several copies of an item are posted
-- at once as one auction each; count, price and deposit are those of one auction), 1 if not given.
function Ledger.NotePost(guid, item, count, price, deposit, duration, auctions)
  pendingPosts[#pendingPosts + 1] = { guid = guid, item = item, count = count, price = price, deposit = deposit,
    duration = duration, auctions = auctions or 1, at = time() }
end

-- The game created an auction: records it with the oldest post waiting for its answer. False if there was none (a post
-- from before the addon was loaded, or one that took too long): nothing is recorded then, never a guess.
function Ledger.ResolveCreated(auctionId)
  local post = OldestPost()
  if not post then
    AM.DebugLog.Log("ledger", "auction %s created without a post of ours", auctionId)
    return false
  end
  post.auctions = post.auctions - 1
  post.at = time()
  if post.auctions <= 0 then
    table.remove(pendingPosts, 1)
  end
  Ledger.RecordCreated(auctionId, post.guid, post.item, post.count, post.price, post.deposit, post.duration)
  return true
end

-- The game answered the oldest post without creating (the rest of) its auctions: an error, or a warning that asks the
-- player to confirm (the confirmation is a post of its own). False if no post was waiting.
function Ledger.DropPost()
  local post = OldestPost()
  if post then
    table.remove(pendingPosts, 1)
    AM.DebugLog.Log("ledger", "post of %s x%s answered without %s auctions", post.item, post.count, post.auctions)
  end
  return post ~= nil
end

-- A mail's send time is worked out from its days left, a few seconds off: an auction counts as created before the mail
-- when it was created at most this long after it.
local SEND_TIME_SLACK = 30

-- The index of a character that has events, nil for one that has none (and so no auctions).
local function FindChar(state, guid)
  for index, known in ipairs(state.chars) do
    if known == guid then
      return index
    end
  end
end

-- When the auction was created; 0 for an adopted one (creation unknown, it was there before the ledger saw it).
local function Created(open)
  return open[OPEN_CREATED] or 0
end

local function CreatedBefore(open, sentAt)
  return Created(open) <= sentAt + SEND_TIME_SLACK
end

-- Books the sale of an auction mail the player took: against the newest open auction of the character of that item
-- name with the same unit price that still holds the count sold (the auction house sells the last added first). A part
-- sale lowers the auction by what it sold and leaves the rest open. nameOf(itemDbKey) is the item's name, nil if not
-- known yet: such an auction is no candidate. sentAt: when the mail was sent, nil if not known (then now, the time it
-- was sold by). False if no auction matches: nothing is booked then, never a guess.
function Ledger.BookSale(guid, itemName, count, price, deposit, fee, sentAt, nameOf)
  local state = Writable()
  if not state then
    return false
  end
  local char = FindChar(state, guid)
  sentAt = sentAt or time()
  local bestId, best
  for auctionId, open in pairs(state.open) do
    if open[OPEN_CHAR] == char and open[OPEN_PRICE] and count <= open[OPEN_COUNT]
      and price * open[OPEN_COUNT] == open[OPEN_PRICE] * count
      and CreatedBefore(open, sentAt) and nameOf(open[OPEN_ITEM]) == itemName
      and (not best or Created(open) > Created(best)
        or (Created(open) == Created(best) and auctionId > bestId)) then
      bestId, best = auctionId, open
    end
  end
  if not best then
    AM.DebugLog.Log("ledger", "sale of %s x%s for %s: no open auction", itemName, count, price)
    return false
  end
  state.events[#state.events + 1] = { sentAt, Ledger.SOLD, char, best[OPEN_ITEM], count, price, deposit, fee }
  if count >= best[OPEN_COUNT] then
    state.open[bestId] = nil
  else
    best[OPEN_COUNT] = best[OPEN_COUNT] - count
    best[OPEN_PRICE] = best[OPEN_PRICE] - price
    best[OPEN_DEPOSIT] = best[OPEN_DEPOSIT] and deposit and math.max(0, best[OPEN_DEPOSIT] - deposit) or nil
  end
  AM.DebugLog.Log("ledger", "sold auction %s: %s x%s price %s deposit %s fee %s", bestId, best[OPEN_ITEM], count, price,
    deposit, fee)
  AM.Events.Fire("LEDGER_CHANGED")
  return true
end

-- Books a trade of an item that is not an auction (kind), count of the item for price (copper for all of them) by the
-- character guid at `at`, now if not given. False if it is not known what or how much: nothing is booked then.
local function BookTrade(kind, label, guid, item, count, price, at)
  if not item or not count or count <= 0 or not price then
    AM.DebugLog.Log("ledger", "%s not booked: item %s x%s price %s", label, item, count, price)
    return false
  end
  local state = Writable()
  if not state then
    return false
  end
  state.events[#state.events + 1] = { at or time(), kind, CharIndex(state, guid), item, count, price }
  AM.DebugLog.Log("ledger", "%s %s x%s for %s", label, item, count, price)
  AM.Events.Fire("LEDGER_CHANGED")
  return true
end

-- Books a purchase of a won mail the player took: count of the item (itemDbKey) for price (copper paid for all of
-- them) by the character guid, at sentAt (the mail's send time; the game sends it at the purchase), now if not known.
-- False if the mail did not say what or how much: nothing is booked then, never a guess.
function Ledger.BookPurchase(guid, item, count, price, sentAt)
  return BookTrade(Ledger.BOUGHT, "bought", guid, item, count, price, sentAt)
end

-- Books what the character guid sold to a merchant: count of the item (itemDbKey) for price (copper the merchant paid
-- for all of them) at `at` (now if not given). False if it is not known what or how much: nothing is booked then.
function Ledger.BookVendorSale(guid, item, count, price, at)
  return BookTrade(Ledger.VENDOR_SOLD, "sold to vendor", guid, item, count, price, at)
end

-- Books what the character guid bought from a merchant for gold, as BookVendorSale (price: what was paid).
function Ledger.BookVendorPurchase(guid, item, count, price, at)
  return BookTrade(Ledger.VENDOR_BOUGHT, "bought from vendor", guid, item, count, price, at)
end

-- Repeated crafts or disenchants of one item (made one after another, "Create all") are booked as one event when they
-- follow each other within this many seconds.
local MERGE_WINDOW = 120

-- Adds count of the item and its list (itemDbKey, count, ... ; values: what one unit of each sold for, or nil) to the
-- last event if it is of the same kind, character and item and booked at most MERGE_WINDOW before `at`, which then
-- becomes its time. Only the last event, so nothing booked in between changes order. Values must agree (both unknown,
-- or the same value for a material both have) so the split never mixes known and unknown prices. True if merged.
local function MergeIntoLast(state, kind, char, item, count, flat, values, at)
  local last = state.events[#state.events]
  if not last or last[TYPE] ~= kind or last[CHAR] ~= char or last[ITEM] ~= item or at < last[TIME]
    or at - last[TIME] > MERGE_WINDOW or (values == nil) ~= (last[VALUES] == nil) then
    return false
  end
  local list, lastValues = last[REAGENTS], last[VALUES]
  local slotOf = {}
  for slot = 1, #list, 2 do
    slotOf[list[slot]] = slot
  end
  if values then
    for slot = 1, #flat, 2 do
      local own = slotOf[flat[slot]]
      if own and lastValues[(own + 1) / 2] ~= values[(slot + 1) / 2] then
        return false
      end
    end
  end
  for slot = 1, #flat, 2 do
    local own = slotOf[flat[slot]]
    if own then
      list[own + 1] = list[own + 1] + flat[slot + 1]
    else
      list[#list + 1] = flat[slot]
      list[#list + 1] = flat[slot + 1]
      if values then
        lastValues[#lastValues + 1] = values[(slot + 1) / 2]
      end
    end
  end
  last[COUNT] = last[COUNT] + count
  last[TIME] = at
  return true
end

-- Books a craft of the character guid: count of the item (itemDbKey) made from reagents, a list of { item, count }
-- (itemDbKey and how many of it the craft used up), at `at` (now if not given). False if anything of it is not known:
-- nothing is booked then, never a craft with part of its reagents.
function Ledger.BookCraft(guid, item, count, reagents, at)
  local flat = {}
  for _, reagent in ipairs(reagents or {}) do
    if not reagent.item or not reagent.count or reagent.count <= 0 then
      flat = {}
      break
    end
    flat[#flat + 1] = reagent.item
    flat[#flat + 1] = reagent.count
  end
  if not item or not count or count <= 0 or #flat == 0 then
    AM.DebugLog.Log("ledger", "craft not booked: item %s x%s, %s reagents", item, count, #flat / 2)
    return false
  end
  local state = Writable()
  if not state then
    return false
  end
  at = at or time()
  local char = CharIndex(state, guid)
  if not MergeIntoLast(state, Ledger.CRAFTED, char, item, count, flat, nil, at) then
    state.events[#state.events + 1] = { at, Ledger.CRAFTED, char, item, count, flat }
  end
  AM.DebugLog.Log("ledger", "crafted %s x%s from %s", item, count, table.concat(flat, " "))
  AM.Events.Fire("LEDGER_CHANGED")
  return true
end

-- Books a disenchant of the character guid: count of the item (itemDbKey) destroyed for materials, a list of
-- { item, count, value } (itemDbKey, how many of it the loot window gave, what one sells for now in copper, nil when not
-- known), at `at` (now if not given). The values are kept only when every material has one, so the split never rests
-- on part of the prices. False if the item or a material is not known: nothing is booked then.
function Ledger.BookDisenchant(guid, item, count, materials, at)
  local flat, values = {}, {}
  for _, material in ipairs(materials or {}) do
    if not material.item or not material.count or material.count <= 0 then
      flat = {}
      break
    end
    flat[#flat + 1] = material.item
    flat[#flat + 1] = material.count
    if values and type(material.value) == "number" and material.value > 0 then
      values[#values + 1] = material.value
    else
      values = nil
    end
  end
  if not item or not count or count <= 0 or #flat == 0 then
    AM.DebugLog.Log("ledger", "disenchant not booked: item %s x%s, %s materials", item, count, #flat / 2)
    return false
  end
  local state = Writable()
  if not state then
    return false
  end
  at = at or time()
  local char = CharIndex(state, guid)
  if not MergeIntoLast(state, Ledger.DISENCHANTED, char, item, count, flat, values, at) then
    state.events[#state.events + 1] = { at, Ledger.DISENCHANTED, char, item, count, flat, values }
  end
  AM.DebugLog.Log("ledger", "disenchanted %s x%s into %s, values %s", item, count, table.concat(flat, " "),
    values and table.concat(values, " ") or "unknown")
  AM.Events.Fire("LEDGER_CHANGED")
  return true
end

-- Books what the character guid took from a loot window: count of the item (itemDbKey) at `at` (now if not given).
-- False if it is not known what or how many: nothing is booked then.
function Ledger.BookLoot(guid, item, count, at)
  if not item or not count or count <= 0 then
    AM.DebugLog.Log("ledger", "loot not booked: item %s x%s", item, count)
    return false
  end
  local state = Writable()
  if not state then
    return false
  end
  state.events[#state.events + 1] = { at or time(), Ledger.LOOTED, CharIndex(state, guid), item, count }
  AM.DebugLog.Log("ledger", "looted %s x%s", item, count)
  AM.Events.Fire("LEDGER_CHANGED")
  return true
end

-- Books the junk the character guid sold in one visit to a merchant as one event: count items for price (copper, the
-- sum) at `at` (now if not given). Nothing for no junk.
function Ledger.BookJunk(guid, count, price, at)
  if not count or count <= 0 or not price then
    return false
  end
  local state = Writable()
  if not state then
    return false
  end
  state.events[#state.events + 1] = { at or time(), Ledger.JUNK_SOLD, CharIndex(state, guid), nil, count, price }
  AM.DebugLog.Log("ledger", "junk sold: %s items for %s", count, price)
  AM.Events.Fire("LEDGER_CHANGED")
  return true
end

-- The oldest open auction of the character of this item created before sentAt for which fits(open) holds.
local function OldestOpen(state, char, item, sentAt, fits)
  local bestId, best
  for auctionId, open in pairs(state.open) do
    if open[OPEN_CHAR] == char and open[OPEN_ITEM] == item and fits(open) and CreatedBefore(open, sentAt)
      and (not best or Created(open) < Created(best)
        or (Created(open) == Created(best) and auctionId < bestId)) then
      bestId, best = auctionId, open
    end
  end
  return bestId, best
end

-- Books the end of an auction whose mail brought the item back (expired or canceled): against the oldest open auction
-- of the character of exactly this item and count created before the mail was sent (the first posted runs out first),
-- for which fits(open) holds. The deposit left in the auction is lost. Without such an auction, against the oldest one
-- holding more: the rest was sold and its mail is not taken yet. That part loses the deposit a part sale would not give
-- back (a part sale gives back floor(deposit * sold / count)); the rest stays open for its sale. False if none matches.
local function BookReturn(kind, label, guid, item, count, sentAt, fits)
  local state = Writable()
  if not state then
    return false
  end
  local char = FindChar(state, guid)
  sentAt = sentAt or time()
  local bestId, best = OldestOpen(state, char, item, sentAt, function(open)
    return open[OPEN_COUNT] == count and fits(open)
  end)
  if not best then
    bestId, best = OldestOpen(state, char, item, sentAt, function(open)
      return open[OPEN_COUNT] > count and fits(open)
    end)
  end
  if not best then
    AM.DebugLog.Log("ledger", "%s mail of %s x%s: no open auction", label, item, count)
    return false
  end
  local lost = best[OPEN_DEPOSIT]
  -- what the units that came back were posted for (nil without a buyout): the price they did not sell at
  local posted = best[OPEN_PRICE]
  if count >= best[OPEN_COUNT] then
    state.open[bestId] = nil
  else
    local left = best[OPEN_COUNT] - count
    if lost then
      local kept = math.floor(lost * left / best[OPEN_COUNT])
      lost = lost - kept
      best[OPEN_DEPOSIT] = kept
    end
    if posted then
      best[OPEN_PRICE] = math.floor(posted * left / best[OPEN_COUNT] + 0.5)
      posted = posted - best[OPEN_PRICE]
    end
    best[OPEN_COUNT] = left
  end
  state.events[#state.events + 1] = { sentAt, kind, char, item, count, posted, lost }
  AM.DebugLog.Log("ledger", "%s auction %s: %s x%s deposit %s", label, bestId, item, count, lost)
  AM.Events.Fire("LEDGER_CHANGED")
  return true
end

local function Any()
  return true
end

-- Books the expiry of an auction mail the player took (BookReturn). sentAt as for BookSale.
function Ledger.BookExpiry(guid, item, count, sentAt)
  return BookReturn(Ledger.EXPIRED, "expired", guid, item, count, sentAt, Any)
end

-- Books the mail of a canceled auction the player took, the safety net for a cancel the CancelAuction hook missed
-- (BookReturn). Only an auction that went missing from the owned auctions list after the mail was sent matches (the
-- game sends the mail at the cancel, the list without it comes after): one still listed is still running, one missing
-- since before ended earlier and waits for a mail of its own. A cancel booked from the list is no longer open, so its
-- mail books nothing.
function Ledger.BookCancelMail(guid, item, count, sentAt)
  sentAt = sentAt or time()
  return BookReturn(Ledger.CANCELED, "canceled", guid, item, count, sentAt, function(open)
    return open[OPEN_MISSING] ~= nil and open[OPEN_MISSING] >= sentAt - SEND_TIME_SLACK
  end)
end

-- The character's full owned auctions list was read: owned is a list of { auctionId, item, count, price (buyout for
-- the whole stack, nil without one), sold }. A running auction we do not know is adopted (deposit and creation
-- unknown, no event: we did not see it created). An open auction missing from the list that the player asked to cancel
-- is booked as canceled, losing the deposit left in it. Any other missing one has ended; it stays open for its mail
-- and is closed as unknown once missing for longer than a mail stays in the inbox.
function Ledger.ReconcileOwned(guid, owned)
  local state = Writable()
  if not state then
    return
  end
  local now = time()
  local changed = false
  local listed = {}
  for auctionId, at in pairs(cancelRequests) do
    if now - at > CANCEL_TIMEOUT then
      cancelRequests[auctionId] = nil
      AM.DebugLog.Log("ledger", "cancel of auction %s not carried out", auctionId)
    end
  end
  for _, auction in ipairs(owned) do
    listed[auction.auctionId] = true
    local open = state.open[auction.auctionId]
    if open then
      open[OPEN_MISSING] = nil
    elseif not auction.sold then
      state.open[auction.auctionId] = { CharIndex(state, guid), auction.item, auction.count, auction.price }
      changed = true
      AM.DebugLog.Log("ledger", "adopted auction %s: %s x%s price %s", auction.auctionId, auction.item, auction.count,
        auction.price)
    end
  end
  local char = FindChar(state, guid)
  for auctionId, open in pairs(state.open) do
    if open[OPEN_CHAR] == char and not listed[auctionId] then
      if cancelRequests[auctionId] then
        cancelRequests[auctionId] = nil
        state.events[#state.events + 1] = { now, Ledger.CANCELED, char, open[OPEN_ITEM], open[OPEN_COUNT],
          open[OPEN_PRICE], open[OPEN_DEPOSIT] }
        state.open[auctionId] = nil
        changed = true
        AM.DebugLog.Log("ledger", "canceled auction %s: %s x%s deposit %s", auctionId, open[OPEN_ITEM],
          open[OPEN_COUNT], open[OPEN_DEPOSIT])
      elseif not open[OPEN_MISSING] then
        open[OPEN_MISSING] = now
      elseif now - open[OPEN_MISSING] > MISSING_TIMEOUT then
        state.events[#state.events + 1] = { now, Ledger.UNKNOWN, char, open[OPEN_ITEM], open[OPEN_COUNT], nil,
          open[OPEN_DEPOSIT] }
        state.open[auctionId] = nil
        changed = true
        AM.DebugLog.Log("ledger", "auction %s ended unseen: %s x%s deposit %s", auctionId, open[OPEN_ITEM],
          open[OPEN_COUNT], open[OPEN_DEPOSIT])
      end
    end
  end
  if changed then
    AM.Events.Fire("LEDGER_CHANGED")
  end
end

-- The itemDbKeys of the character's open auctions, each once (to have their names loaded before a mail is taken).
function Ledger.GetOpenItems(guid)
  local state = State()
  local char = FindChar(state, guid)
  local items, seen = {}, {}
  for _, open in pairs(state.open) do
    local item = open[OPEN_ITEM]
    if open[OPEN_CHAR] == char and not seen[item] then
      seen[item] = true
      items[#items + 1] = item
    end
  end
  return items
end

-- The cost basis, worked out from all events of all characters of this auction house when read (FIFO): in the order
-- of their times (equal times in the order booked), each purchase (auction house or merchant) adds a lot of its units
-- to the stock of its item, each sale (auction house or merchant) uses up the oldest units of that item in stock.
-- Looted units go into stock at no cost. Canceled and expired auctions leave their units in stock. A craft uses up its
-- reagents the same way and adds a lot of the crafted item at what they cost (also when that is nothing: the crafted
-- units are held all the same). A disenchant uses up its item the same way and adds a lot of each material at its share
-- of that cost. Units without any in stock cost nothing (looted or bought before the ledger saw it).
-- It starts from the stock left when older events were combined (state.stock). With `before`, only the events before
-- that time are taken (Combine).
-- Returns
--   costs      by sale, craft and disenchant event: the cost of the units it used up
--   uncosted   by sale, craft and disenchant event: its units that found none in stock
--   lots       by itemDbKey: the units still in stock, oldest first: { char, count, price } (price: of those units)
--   shares     by disenchant event: the cost each material got, in the order of its materials
local function CostBasis(state, before)
  local events = state.events
  local order = {}
  for index, event in ipairs(events) do
    local kind = event[TYPE]
    if (STOCK_IN[kind] or STOCK_OUT[kind] or kind == Ledger.CRAFTED or kind == Ledger.USED_UP
      or kind == Ledger.DISENCHANTED) and (not before or event[TIME] < before) then
      order[#order + 1] = index
    end
  end
  table.sort(order, function(a, b)
    if events[a][TIME] ~= events[b][TIME] then
      return events[a][TIME] < events[b][TIME]
    end
    return a < b
  end)
  local costs, uncosted, lots, shares = {}, {}, {}, {}
  local function AddLot(item, char, count, price)
    local queue = lots[item]
    if not queue then
      queue = {}
      lots[item] = queue
    end
    queue[#queue + 1] = { char = char, count = count, price = price }
  end
  local stock = state.stock
  for slot = 1, #stock, 4 do
    AddLot(stock[slot], stock[slot + 1], stock[slot + 2], stock[slot + 3])
  end
  -- uses up count units of the item, the oldest first (with freeFirst those at no cost before all others); returns what
  -- they cost and how many found none
  local function Take(item, count, freeFirst)
    local queue = lots[item]
    local left, cost = count, 0
    local index = 1
    while freeFirst and left > 0 and queue and queue[index] do
      local lot = queue[index]
      if lot.price == 0 then
        local taken = math.min(left, lot.count)
        lot.count = lot.count - taken
        left = left - taken
        if lot.count == 0 then
          table.remove(queue, index)
        end
      else
        index = index + 1
      end
    end
    while left > 0 and queue and queue[1] do
      local lot = queue[1]
      local taken = math.min(left, lot.count)
      -- the last units of a lot take what is left of its price, so the parts add up to the price paid
      local part = lot.price
      if taken < lot.count then
        part = math.floor(lot.price * taken / lot.count + 0.5)
      end
      cost = cost + part
      lot.count = lot.count - taken
      lot.price = lot.price - part
      left = left - taken
      if lot.count == 0 then
        table.remove(queue, 1)
      end
    end
    return cost, left
  end
  for _, index in ipairs(order) do
    local event = events[index]
    local kind = event[TYPE]
    if STOCK_IN[kind] then
      AddLot(event[ITEM], event[CHAR], event[COUNT], event[PRICE] or 0)
    elseif kind == Ledger.CRAFTED then
      local cost, left = 0, 0
      local reagents = event[REAGENTS]
      for slot = 1, #reagents, 2 do
        local reagentCost, reagentLeft = Take(reagents[slot], reagents[slot + 1])
        cost, left = cost + reagentCost, left + reagentLeft
      end
      AddLot(event[ITEM], event[CHAR], event[COUNT], cost)
      costs[event], uncosted[event] = cost, left
    elseif kind == Ledger.DISENCHANTED then
      local cost, left = Take(event[ITEM], event[COUNT])
      local materials, values = event[REAGENTS], event[VALUES]
      -- each material's weight: its value (count times what one sold for), its count without values
      local weights, total = {}, 0
      for slot = 1, #materials, 2 do
        local weight = materials[slot + 1] * (values and values[(slot + 1) / 2] or 1)
        weights[#weights + 1] = weight
        total = total + weight
      end
      -- shares rounded on the running sum, so they add up to the cost and none is below 0
      local split, sum, before = {}, 0, 0
      for index, weight in ipairs(weights) do
        sum = sum + weight
        local upTo = math.floor(cost * sum / total + 0.5)
        split[index] = upTo - before
        before = upTo
        AddLot(materials[index * 2 - 1], event[CHAR], materials[index * 2], split[index])
      end
      costs[event], uncosted[event], shares[event] = cost, left, split
    else
      costs[event], uncosted[event] = Take(event[ITEM], event[COUNT], kind == Ledger.USED_UP)
    end
  end
  return costs, uncosted, lots, shares
end

-- Empty totals of the summary figures (see GetSummary).
local function NewTotals()
  return { revenue = 0, fees = 0, lostDeposits = 0, unknownLosses = 0, cost = 0, uncostedCount = 0, soldCount = 0,
    unsoldCount = 0, canceledCount = 0, expiredCount = 0, createdCount = 0, unknownCount = 0, openCount = 0,
    tiedUp = 0, tiedUpUnknown = 0, boughtCount = 0, spent = 0, stockCount = 0, stock = 0, vendorRevenue = 0,
    vendorSoldCount = 0, junkRevenue = 0, junkCount = 0, vendorSpent = 0, vendorBoughtCount = 0, craftedCount = 0,
    craftCost = 0, usedCount = 0, lootedCount = 0, usedUpCount = 0, usedUpCost = 0, disenchantedCount = 0,
    disenchantCost = 0, fromDisenchantCount = 0, fromDisenchantCost = 0 }
end

local function AddEvent(totals, event, basis)
  local kind = event[TYPE]
  if kind == Ledger.CREATED then
    totals.createdCount = totals.createdCount + event[COUNT]
  elseif kind == Ledger.SOLD then
    totals.revenue = totals.revenue + (event[PRICE] or 0)
    totals.fees = totals.fees + (event[FEE] or 0)
    totals.cost = totals.cost + basis.costs[event]
    totals.uncostedCount = totals.uncostedCount + basis.uncosted[event]
    totals.soldCount = totals.soldCount + event[COUNT]
    -- not a figure of the combined rows: only the sales kept as events
    if not totals.lastSold or event[TIME] > totals.lastSold then
      totals.lastSold = event[TIME]
    end
  elseif kind == Ledger.VENDOR_SOLD then
    totals.revenue = totals.revenue + event[PRICE]
    totals.vendorRevenue = totals.vendorRevenue + event[PRICE]
    totals.cost = totals.cost + basis.costs[event]
    totals.uncostedCount = totals.uncostedCount + basis.uncosted[event]
    totals.vendorSoldCount = totals.vendorSoldCount + event[COUNT]
  elseif kind == Ledger.CRAFTED then
    totals.craftedCount = totals.craftedCount + event[COUNT]
    totals.craftCost = totals.craftCost + basis.costs[event]
  elseif kind == Ledger.DISENCHANTED then
    -- its cost moves to the materials: not in Net
    totals.disenchantedCount = totals.disenchantedCount + event[COUNT]
    totals.disenchantCost = totals.disenchantCost + basis.costs[event]
  elseif kind == Ledger.LOOTED then
    totals.lootedCount = totals.lootedCount + event[COUNT]
  elseif kind == Ledger.USED_UP then
    -- left stock outside Net: not a trading loss
    totals.usedUpCount = totals.usedUpCount + event[COUNT]
    totals.usedUpCost = totals.usedUpCost + basis.costs[event]
  elseif kind == Ledger.JUNK_SOLD then
    -- junk is loot, not trading: kept apart, never in revenue or net
    totals.junkRevenue = totals.junkRevenue + event[PRICE]
    totals.junkCount = totals.junkCount + event[COUNT]
  elseif kind == Ledger.BOUGHT or kind == Ledger.VENDOR_BOUGHT then
    totals.boughtCount = totals.boughtCount + event[COUNT]
    totals.spent = totals.spent + event[PRICE]
    if kind == Ledger.VENDOR_BOUGHT then
      totals.vendorBoughtCount = totals.vendorBoughtCount + event[COUNT]
      totals.vendorSpent = totals.vendorSpent + event[PRICE]
    end
  elseif kind == Ledger.CANCELED or kind == Ledger.EXPIRED then
    if event[DEPOSIT] then
      totals.lostDeposits = totals.lostDeposits + event[DEPOSIT]
    else
      totals.unknownLosses = totals.unknownLosses + 1
    end
    totals.unsoldCount = totals.unsoldCount + event[COUNT]
    if kind == Ledger.CANCELED then
      totals.canceledCount = totals.canceledCount + event[COUNT]
    else
      totals.expiredCount = totals.expiredCount + event[COUNT]
    end
  elseif kind == Ledger.UNKNOWN then
    totals.unknownCount = totals.unknownCount + event[COUNT]
  end
end

local function AddOpen(totals, open)
  totals.openCount = totals.openCount + open[OPEN_COUNT]
  if open[OPEN_DEPOSIT] then
    totals.tiedUp = totals.tiedUp + open[OPEN_DEPOSIT]
  else
    totals.tiedUpUnknown = totals.tiedUpUnknown + 1
  end
end

local function AddLot(totals, lot)
  totals.stockCount = totals.stockCount + lot.count
  totals.stock = totals.stock + lot.price
end

local function FinishTotals(totals)
  totals.net = totals.revenue - totals.fees - totals.lostDeposits - totals.cost
  local finished = totals.soldCount + totals.unsoldCount
  if finished > 0 then
    totals.sellRate = totals.soldCount / finished
  end
  return totals
end

-- The figures a combined row holds (the totals the events add to, see GetSummary), by their number in the row. Append
-- only: the numbers are stored.
local FIELDS = { "createdCount", "revenue", "fees", "cost", "uncostedCount", "soldCount", "vendorRevenue",
  "vendorSoldCount", "craftedCount", "craftCost", "disenchantedCount", "disenchantCost", "lootedCount", "usedUpCount",
  "usedUpCost", "junkRevenue", "junkCount", "boughtCount", "spent", "vendorBoughtCount", "vendorSpent",
  "lostDeposits", "unknownLosses", "unsoldCount", "canceledCount", "expiredCount", "unknownCount", "usedCount",
  "fromDisenchantCount", "fromDisenchantCost" }
-- figures only an item's totals have (GetItemSummaries), left out of the totals of all items
local PER_ITEM = { usedCount = true, fromDisenchantCount = true, fromDisenchantCost = true }
-- the figures of events that make an item traded (any event but looted and used up)
local TRADED = { "createdCount", "soldCount", "vendorSoldCount", "unsoldCount", "unknownCount", "boughtCount",
  "craftedCount", "disenchantedCount" }

-- slots of a combined row
local ROW_START, ROW_CHAR, ROW_ITEM, ROW_FIGURES = 1, 2, 3, 4

-- Adds the figures of a combined row to totals; perItem: also those only an item's totals have.
local function AddRow(totals, row, perItem)
  for slot = ROW_FIGURES, #row, 2 do
    local name = FIELDS[row[slot]]
    if name and (perItem or not PER_ITEM[name]) then
      totals[name] = totals[name] + row[slot + 1]
    end
  end
end

-- A combined row of the totals (only their figures that are not 0).
local function NewRow(start, char, item, totals)
  local row = { start, char, item }
  for index, name in ipairs(FIELDS) do
    if totals[name] ~= 0 then
      row[#row + 1] = index
      row[#row + 1] = totals[name]
    end
  end
  return row
end

-- The totals of one combined row alone (FinishTotals: with its net).
local function RowTotals(row)
  local totals = NewTotals()
  AddRow(totals, row, false)
  return FinishTotals(totals)
end

local function RowIsTraded(row)
  local totals = RowTotals(row)
  for _, name in ipairs(TRADED) do
    if totals[name] > 0 then
      return true
    end
  end
  return false
end

-- Adds an event with an item to the totals of the items it touches, TotalsOf(item) handing them out: its own item, and
-- the reagents of a craft (used) and the materials of a disenchant (with the cost they got).
local function SpreadEvent(TotalsOf, event, basis)
  if event[ITEM] then
    local totals = TotalsOf(event[ITEM])
    AddEvent(totals, event, basis)
    if event[TYPE] ~= Ledger.LOOTED and event[TYPE] ~= Ledger.USED_UP then
      totals.traded = true
    end
  end
  if event[TYPE] == Ledger.CRAFTED then
    local reagents = event[REAGENTS]
    for slot = 1, #reagents, 2 do
      local totals = TotalsOf(reagents[slot])
      totals.usedCount = totals.usedCount + reagents[slot + 1]
    end
  elseif event[TYPE] == Ledger.DISENCHANTED then
    local materials, split = event[REAGENTS], basis.shares[event]
    for slot = 1, #materials, 2 do
      local totals = TotalsOf(materials[slot])
      totals.fromDisenchantCount = totals.fromDisenchantCount + materials[slot + 1]
      totals.fromDisenchantCost = totals.fromDisenchantCost + split[(slot + 1) / 2]
    end
  end
end

local DAY = 24 * 3600

-- The local midnight of the day of `at`.
local function DayStart(at)
  local day = date("*t", at)
  return at - day.hour * 3600 - day.min * 60 - day.sec
end

-- The local midnight of the 1st of the month of `at` (by way of a noon, which daylight saving time cannot push into
-- another day).
local function MonthStart(at)
  local start = DayStart(at)
  return DayStart(start - (date("*t", start).day - 1) * DAY + 12 * 3600)
end

-- When the time of a combined row ends: the next day or month.
local function RowEnd(row, monthly)
  if monthly then
    return MonthStart(row[ROW_START] + 32 * DAY)
  end
  return DayStart(row[ROW_START] + DAY + 12 * 3600)
end

-- Calls eachEvent(event, basis) for the events from `from` up to (not including) `to` of the character guid (nil:
-- all), eachOpen(open) for the character's open auctions, eachLot(item, lot), if given, for the units in stock the
-- character bought (all of them now, not limited to the range) and eachRow(row, monthly), if given, for the combined
-- rows of the character whose day or month reaches into the range. basis: { costs, uncosted } of CostBasis. Nothing
-- for a character without events.
local function Collect(from, to, guid, eachEvent, eachOpen, eachLot, eachRow)
  local state = State()
  local char = guid and FindChar(state, guid)
  if guid and not char then
    return
  end
  local costs, uncosted, lots, shares = CostBasis(state)
  local basis = { costs = costs, uncosted = uncosted, shares = shares }
  for _, event in ipairs(state.events) do
    local at = event[TIME]
    if (not char or event[CHAR] == char) and (not from or at >= from) and (not to or at < to) then
      eachEvent(event, basis)
    end
  end
  if eachRow then
    for _, monthly in ipairs({ false, true }) do
      for _, row in ipairs(monthly and state.months or state.days) do
        if (not char or row[ROW_CHAR] == char) and (not to or row[ROW_START] < to)
          and (not from or RowEnd(row, monthly) > from) then
          eachRow(row, monthly)
        end
      end
    end
  end
  for _, open in pairs(state.open) do
    if not char or open[OPEN_CHAR] == char then
      eachOpen(open)
    end
  end
  if eachLot then
    for item, queue in pairs(lots) do
      for _, lot in ipairs(queue) do
        if not char or lot.char == char then
          eachLot(item, lot)
        end
      end
    end
  end
end

-- The summary figures of the events from `from` up to (not including) `to` (Unix seconds, nil for no limit) of the
-- character guid (nil for all characters of this auction house), as a table built for the caller:
--   revenue        the price of everything sold, at the auction house and to merchants (junk not included)
--   vendorRevenue  of it what merchants paid for items (vendorSoldCount: how many)
--   junkRevenue    what merchants paid for junk (junkCount: how many items); loot, not trading: not in revenue or net
--   fees           the auction house fees of those sales
--   lostDeposits   the known deposits of canceled and expired auctions
--   unknownLosses  canceled and expired events whose deposit is not known (left out of lostDeposits and net)
--   cost           what the units sold cost when bought (CostBasis: the oldest units bought first, by any character;
--                  purchases before the range count too); uncostedCount: units sold without a purchase (at no cost)
--   net            revenue - fees - lostDeposits - cost (the profit)
--   craftedCount   items crafted; craftCost: what their reagents cost (moved to the crafted items, not a cost here)
--   usedCount      only per item (GetItemSummaries): items used up as reagents of crafts
--   boughtCount    items bought (auction house and merchants); spent: the price paid for them; vendorBoughtCount
--                  and vendorSpent: of them those bought from merchants
--   lootedCount    items taken from loot windows (they go into stock at no cost)
--   usedUpCount    items that left the holdings without an event (ReconcileStock); usedUpCost: what they cost, which
--                  left stock with them (not part of net)
--   stockCount     items the character bought, looted or crafted that are not sold yet (now, not limited to the time
--                  range); stock: what they cost (tied up, not lost; nothing for looted ones)
--   soldCount      items sold at the auction house; unsoldCount: items that came back, canceledCount + expiredCount; unknownCount: items
--                  of auctions that ended unseen (counted as neither); createdCount: items posted
--   openCount      items in the auctions open now (not limited to the time range; for a part sold commodity the
--                  rest)
--   sellRate       soldCount / (soldCount + unsoldCount), nil when nothing sold or came back
--   lastSold       the time of the latest sale at the auction house among the events kept, nil without one (sales
--                  only in combined days are not dated)
--   tiedUp         the known deposits of the auctions open now (not limited to the time range); tiedUpUnknown: open
--                  auctions whose deposit is not known
function Ledger.GetSummary(from, to, guid)
  local totals = NewTotals()
  Collect(from, to, guid, function(event, basis)
    AddEvent(totals, event, basis)
  end, function(open)
    AddOpen(totals, open)
  end, function(_, lot)
    AddLot(totals, lot)
  end, function(row)
    AddRow(totals, row, false)
  end)
  return FinishTotals(totals)
end

-- The stock now of the character guid (nil for all characters of this auction house): a list built for the caller,
-- one entry per item { item (itemDbKey), count, cost (copper the units cost; nothing for looted ones) }, unsorted.
function Ledger.GetStock(guid)
  local byItem, list = {}, {}
  Collect(nil, nil, guid, function() end, function() end, function(item, lot)
    local entry = byItem[item]
    if not entry then
      entry = { item = item, count = 0, cost = 0 }
      byItem[item] = entry
      list[#list + 1] = entry
    end
    entry.count = entry.count + lot.count
    entry.cost = entry.cost + lot.price
  end)
  return list
end

-- Compares the stock with what the characters really hold and books what is missing as used up, for the character
-- guid (the one logged in, whose actions made it go) at `at` (now if not given). held(itemId) returns how many of the
-- item all characters of this auction house hold outside the auction house (bags, bank, mail), nil when that is not
-- known (nothing is booked then). The units in the open auctions count as held too. All keys of one item (equipment of
-- another level) are compared together; the units missing are taken at no cost first, then the oldest, as CostBasis
-- does when reading the event. Returns how many events were booked.
function Ledger.ReconcileStock(guid, held, at)
  local state = Writable()
  if not state then
    return 0
  end
  local _, _, lots = CostBasis(state)
  local inAuctions = {}
  for _, open in pairs(state.open) do
    local itemId = AM.ItemDbKey.GetItemId(open[OPEN_ITEM])
    if itemId then
      inAuctions[itemId] = (inAuctions[itemId] or 0) + open[OPEN_COUNT]
    end
  end
  -- itemId -> the keys of the item with units in stock, in a fixed order
  local keysOf = {}
  for key, queue in pairs(lots) do
    local itemId = AM.ItemDbKey.GetItemId(key)
    if itemId and #queue > 0 then
      keysOf[itemId] = keysOf[itemId] or {}
      table.insert(keysOf[itemId], key)
    end
  end
  local booked = 0
  for itemId, keys in pairs(keysOf) do
    table.sort(keys)
    local inStock = 0
    for _, key in ipairs(keys) do
      for _, lot in ipairs(lots[key]) do
        inStock = inStock + lot.count
      end
    end
    local holds = held(itemId)
    local missing = holds and inStock - holds - (inAuctions[itemId] or 0) or 0
    if missing > 0 then
      -- how many of each key: the units at no cost first, then the oldest of each key
      local take = {}
      for _, free in ipairs({ true, false }) do
        for _, key in ipairs(keys) do
          for _, lot in ipairs(lots[key]) do
            if missing > 0 and (lot.price == 0) == free then
              local taken = math.min(missing, lot.count)
              take[key] = (take[key] or 0) + taken
              missing = missing - taken
            end
          end
        end
      end
      for _, key in ipairs(keys) do
        if take[key] then
          state.events[#state.events + 1] = { at or time(), Ledger.USED_UP, CharIndex(state, guid), key, take[key] }
          AM.DebugLog.Log("ledger", "used up %s x%s (held %s, in stock %s)", key, take[key], holds, inStock)
          booked = booked + 1
        end
      end
    end
  end
  if booked > 0 then
    AM.Events.Fire("LEDGER_CHANGED")
  end
  return booked
end

-- The summary figures per item (the Items view), as GetSummary for each item with an event in the range or an auction
-- open now or units in stock, each with its itemDbKey as `item` and `traded`: false while only loot happened to it
-- (looted, used as a reagent, in stock at no cost), true for any other event, an open auction or stock that cost gold. Junk has no item and is left out. Sorted by net, the best first (top sellers first, top losers last);
-- equal nets by item.
function Ledger.GetItemSummaries(from, to, guid)
  local byItem, list = {}, {}
  local function TotalsOf(item)
    local totals = byItem[item]
    if not totals then
      totals = NewTotals()
      totals.item = item
      totals.traded = false
      byItem[item] = totals
      list[#list + 1] = totals
    end
    return totals
  end
  Collect(from, to, guid, function(event, basis)
    SpreadEvent(TotalsOf, event, basis)
  end, function(open)
    local totals = TotalsOf(open[OPEN_ITEM])
    AddOpen(totals, open)
    totals.traded = true
  end, function(item, lot)
    local totals = TotalsOf(item)
    AddLot(totals, lot)
    if lot.price > 0 then
      totals.traded = true
    end
  end, function(row)
    if row[ROW_ITEM] then
      local totals = TotalsOf(row[ROW_ITEM])
      AddRow(totals, row, true)
      if RowIsTraded(row) then
        totals.traded = true
      end
    end
  end)
  for _, totals in ipairs(list) do
    FinishTotals(totals)
  end
  table.sort(list, function(a, b)
    if a.net ~= b.net then
      return a.net > b.net
    end
    return a.item < b.item
  end)
  return list
end

-- What an event did to Net: a sale its price less the fee and the cost of its units (basis of CostBasis), a sale to a
-- merchant its price less the cost of its units, a canceled or expired auction minus its deposit; nil for a post (the
-- deposit is only tied up), junk (loot, not trading), a purchase (its units go into stock), a craft or a disenchant (its cost moves to the crafted units or the materials), an auction that ended unseen and a loss whose deposit is not
-- known.
local function EventNet(event, basis)
  local kind = event[TYPE]
  if kind == Ledger.SOLD then
    return (event[PRICE] or 0) - (event[FEE] or 0) - basis.costs[event]
  elseif kind == Ledger.VENDOR_SOLD then
    return event[PRICE] - basis.costs[event]
  elseif (kind == Ledger.CANCELED or kind == Ledger.EXPIRED) and event[DEPOSIT] then
    return -event[DEPOSIT]
  end
  return nil
end

-- The events from `from` up to (not including) `to` of the character guid (nil: all; range and character as in
-- GetSummary) grouped by the local day, for the Journal view. Only the events kept: combined days have no entries. accept(type, itemDbKey), if given, decides which events
-- are taken (itemDbKey nil for junk). A list of days, the newest first, each built for the caller:
--   key            year * 10000 + month * 100 + day (local time)
--   time           the time of its newest event, to name the day
--   net            the sum of the nets of its events; unknownLosses: its losses whose deposit is not known
--   entries        its events, the newest first: { time, type, guid, item, count, price, deposit, fee, cost, net },
--                  cost: of a sale's units (see GetSummary) or of a craft's reagents, net as it counts towards Net
--                  (nil when it does not count, see EventNet), unknown = true for a loss whose deposit is not known,
--                  reagents: of a craft, a list of { item, count }; of a disenchant its materials, each with
--                  the cost it got (`cost`)
function Ledger.GetJournal(from, to, guid, accept)
  local state = State()
  local picked = {}
  local basis
  Collect(from, to, guid, function(event, eventBasis)
    basis = eventBasis
    if not accept or accept(event[TYPE], event[ITEM]) then
      picked[#picked + 1] = event
    end
  end, function() end)
  -- events are stored in the order they were booked; a sale is booked at its mail's time, which can be earlier
  for index, event in ipairs(picked) do
    picked[index] = { event = event, index = index }
  end
  table.sort(picked, function(a, b)
    if a.event[TIME] ~= b.event[TIME] then
      return a.event[TIME] > b.event[TIME]
    end
    return a.index > b.index
  end)
  local days = {}
  for _, entry in ipairs(picked) do
    local event = entry.event
    local at = date("*t", event[TIME])
    local key = at.year * 10000 + at.month * 100 + at.day
    local day = days[#days]
    if not day or day.key ~= key then
      day = { key = key, time = event[TIME], net = 0, unknownLosses = 0, entries = {} }
      days[#days + 1] = day
    end
    local net = EventNet(event, basis)
    local kind = event[TYPE]
    local unknown = (kind == Ledger.CANCELED or kind == Ledger.EXPIRED) and not event[DEPOSIT]
    day.net = day.net + (net or 0)
    if unknown then
      day.unknownLosses = day.unknownLosses + 1
    end
    local reagents
    if kind == Ledger.CRAFTED or kind == Ledger.DISENCHANTED then
      reagents = {}
      for slot = 1, #event[REAGENTS], 2 do
        reagents[#reagents + 1] = { item = event[REAGENTS][slot], count = event[REAGENTS][slot + 1] }
        if kind == Ledger.DISENCHANTED then
          reagents[#reagents].cost = basis.shares[event][(slot + 1) / 2]
        end
      end
    end
    local price, deposit, fee = Money(event)
    day.entries[#day.entries + 1] = { time = event[TIME], type = kind, guid = state.chars[event[CHAR]],
      item = event[ITEM], count = event[COUNT], price = price, deposit = deposit, fee = fee,
      cost = basis.costs[event], net = net, unknown = unknown or nil, reagents = reagents }
  end
  return days
end

-- A range longer than this many days is shown in weeks by GetNetSeries.
local SERIES_MAX_DAYS = 45
-- A range longer than this many days, or one with combined months, is shown in months.
local SERIES_MAX_WEEKS_DAYS = 366

local function DayKey(at)
  local day = date("*t", at)
  return day.year * 10000 + day.month * 100 + day.day
end

-- The net of the events from `from` up to now of the character guid (nil: all; as in GetSummary) per local day, for
-- the Overview's chart. From `from` (nil: the day of the first event in the range) up to today, every day is listed,
-- also one without events (net 0), but never a day before the ledger's first event (of any character): nothing was
-- recorded then, which is not a net of 0. The combined days count as their events did. A range of more than
-- SERIES_MAX_DAYS days is listed in weeks instead, the last one ending today; one of more than SERIES_MAX_WEEKS_DAYS
-- days or with combined months in months. A list, the oldest first, each built for the caller:
--   key            the first day of it, year * 10000 + month * 100 + day (local time)
--   time           a time on that day (its noon), to name it
--   days           how many days it holds (1, or up to 7 for a week; the first week may be shorter; a month's days)
--   month          true for a month
--   net            the sum of the nets of its events (see EventNet); unknownLosses: its losses whose deposit is unknown
-- Empty when there is nothing to show (no start and no event).
function Ledger.GetNetSeries(from, guid)
  local now = time()
  local byKey, byMonth = {}, {}
  local state = State()
  local recorded
  for _, event in ipairs(state.events) do
    recorded = recorded and math.min(recorded, event[TIME]) or event[TIME]
  end
  for _, rows in ipairs({ state.days, state.months }) do
    for _, row in ipairs(rows) do
      recorded = recorded and math.min(recorded, row[ROW_START]) or row[ROW_START]
    end
  end
  if not recorded then
    return {}
  end
  local first = from and math.max(from, recorded)
  local function Add(at, byWhat, key, net, unknownLosses)
    first = first and math.min(first, at) or at
    local bucket = byWhat[key]
    if not bucket then
      bucket = { net = 0, unknownLosses = 0 }
      byWhat[key] = bucket
    end
    bucket.net = bucket.net + net
    bucket.unknownLosses = bucket.unknownLosses + unknownLosses
  end
  local hasMonths = false
  Collect(from, nil, guid, function(event, basis)
    local at = event[TIME]
    if at <= now then
      local kind = event[TYPE]
      local unknown = (kind == Ledger.CANCELED or kind == Ledger.EXPIRED) and not event[DEPOSIT]
      Add(at, byKey, DayKey(at), EventNet(event, basis) or 0, unknown and 1 or 0)
    end
  end, function() end, nil, function(row, monthly)
    local totals = RowTotals(row)
    -- a row reaching into the range from before starts the list on the first day of the range
    local at = math.max(row[ROW_START], from or row[ROW_START])
    if monthly then
      hasMonths = true
      Add(at, byMonth, math.floor(DayKey(row[ROW_START]) / 100), totals.net, totals.unknownLosses)
    else
      Add(at, byKey, DayKey(row[ROW_START]), totals.net, totals.unknownLosses)
    end
  end)
  if not first then
    return {}
  end
  -- walk the days at their noon, which a change to or from daylight saving time cannot push into another day
  local start = date("*t", first)
  local at = first + (12 - start.hour) * 3600 - start.min * 60 - start.sec
  local today = DayKey(now)
  local days = {}
  while true do
    local key = DayKey(at)
    if key > today then
      break
    end
    local day = byKey[key]
    days[#days + 1] = { key = key, time = at, days = 1, net = day and day.net or 0,
      unknownLosses = day and day.unknownLosses or 0 }
    at = at + DAY
  end
  if #days <= SERIES_MAX_DAYS and not hasMonths then
    return days
  end
  if #days > SERIES_MAX_WEEKS_DAYS or hasMonths then
    -- months, each with the combined month of it
    local months = {}
    for _, day in ipairs(days) do
      local key = math.floor(day.key / 100)
      local month = months[#months]
      if not month or month.monthKey ~= key then
        local combinedMonth = byMonth[key]
        month = { monthKey = key, key = day.key, time = day.time, days = 0, month = true,
          net = combinedMonth and combinedMonth.net or 0,
          unknownLosses = combinedMonth and combinedMonth.unknownLosses or 0 }
        months[#months + 1] = month
      end
      month.days = month.days + 1
      month.net = month.net + day.net
      month.unknownLosses = month.unknownLosses + day.unknownLosses
    end
    for _, month in ipairs(months) do
      month.monthKey = nil
    end
    return months
  end
  -- weeks, counted back from today so the last week is a whole one
  local weeks = {}
  local size = #days % 7
  local index = 1
  if size == 0 then
    size = 7
  end
  while index <= #days do
    local week = { key = days[index].key, time = days[index].time, days = 0, net = 0, unknownLosses = 0 }
    for offset = 0, size - 1 do
      local day = days[index + offset]
      week.days = week.days + 1
      week.net = week.net + day.net
      week.unknownLosses = week.unknownLosses + day.unknownLosses
    end
    weeks[#weeks + 1] = week
    index = index + size
    size = 7
  end
  return weeks
end

-- What stands out in the item summaries of GetItemSummaries, for the Overview: facts only, never a guess why. A list
-- in a fixed order, each built for the caller with `kind`, `items` (itemDbKeys, the one that weighs most first) and
-- `gold` (copper; for "unsold" the deposits lost, for "stock" what the units cost):
--   top            the item with the best net above 0; count: sold (auction house and merchants), rate: its sell rate
--   bestseller     the item sold most of those with a net above 0, if that is not the top item and it sold more;
--                  count, rate as for top
--   loss           the item with the worst net below 0 among those that sold (auction house or merchant); count:
--                  sold, unsold: came back
--   unsold         the items that came back without selling once (most deposits lost first); count: came back,
--                  unknownLosses: of those losses whose deposit is unknown
--   stock          the items in stock that cost gold (most gold first); count: their units in stock
-- An entry with nothing to show is left out.
function Ledger.GetFindings(summaries)
  local top, bestseller, loss
  local unsold, stock = {}, {}
  local function Sold(totals)
    return totals.soldCount + totals.vendorSoldCount
  end
  for _, totals in ipairs(summaries) do
    if totals.net > 0 and (not top or totals.net > top.net) then
      top = totals
    end
    if totals.net > 0 and (not bestseller or Sold(totals) > Sold(bestseller)) then
      bestseller = totals
    end
    if Sold(totals) > 0 and totals.net < 0 and (not loss or totals.net < loss.net) then
      loss = totals
    end
    if totals.soldCount == 0 and totals.unsoldCount > 0 then
      unsold[#unsold + 1] = totals
    end
    -- gold tied up: units in stock at no cost (looted) are not part of it
    if totals.stock > 0 then
      stock[#stock + 1] = totals
    end
  end
  local findings = {}
  if top then
    findings[#findings + 1] = { kind = "top", items = { top.item }, gold = top.net, count = Sold(top),
      rate = top.sellRate }
  end
  if bestseller and bestseller ~= top and (not top or Sold(bestseller) > Sold(top)) then
    findings[#findings + 1] = { kind = "bestseller", items = { bestseller.item }, gold = bestseller.net,
      count = Sold(bestseller), rate = bestseller.sellRate }
  end
  if loss then
    findings[#findings + 1] = { kind = "loss", items = { loss.item }, gold = loss.net, count = Sold(loss),
      unsold = loss.unsoldCount }
  end
  -- a group of items: sorted by gold, then count, highest first (equal ones by item, so the order does not change
  -- from one refresh to the next); gold and count the sums of these fields, gold times sign
  local function Group(kind, list, goldField, countField, sign)
    if #list == 0 then
      return
    end
    table.sort(list, function(a, b)
      if a[goldField] ~= b[goldField] then
        return a[goldField] > b[goldField]
      elseif a[countField] ~= b[countField] then
        return a[countField] > b[countField]
      end
      return a.item < b.item
    end)
    local finding = { kind = kind, items = {}, gold = 0, count = 0, unknownLosses = 0 }
    for index, totals in ipairs(list) do
      finding.items[index] = totals.item
      finding.gold = finding.gold + sign * totals[goldField]
      finding.count = finding.count + totals[countField]
      finding.unknownLosses = finding.unknownLosses + totals.unknownLosses
    end
    findings[#findings + 1] = finding
  end
  Group("unsold", unsold, "lostDeposits", "unsoldCount", -1)
  Group("stock", stock, "stock", "stockCount", 1)
  return findings
end

-- Totals by start, character and item for the combined rows of a list, which are added to and then written back
-- (Store). At(start, char, item) hands out the totals of one row, from the row stored if there is one.
local function RowMerger(rows)
  local indexOf, touched = {}, {}
  local function Key(start, char, item)
    return start .. ":" .. char .. ":" .. tostring(item)
  end
  for index, row in ipairs(rows) do
    indexOf[Key(row[ROW_START], row[ROW_CHAR], row[ROW_ITEM])] = index
  end
  local merger = {}
  function merger.At(start, char, item)
    local key = Key(start, char, item)
    local entry = touched[key]
    if not entry then
      entry = { start = start, char = char, item = item, index = indexOf[key], totals = NewTotals() }
      if entry.index then
        AddRow(entry.totals, rows[entry.index], true)
      end
      touched[key] = entry
      touched[#touched + 1] = entry
    end
    return entry.totals
  end
  function merger.Store()
    for _, entry in ipairs(touched) do
      rows[entry.index or #rows + 1] = NewRow(entry.start, entry.char, entry.item, entry.totals)
    end
  end
  return merger
end

-- How old a combined day gets before it is combined into its month.
local MONTHS_AFTER = 365 * DAY

-- Combines the events older than the days kept (GetKeepDays, counted from the start of that day) into the rows of their
-- days, the cost of their units worked out as when they were read, and keeps the stock left after them as the
-- starting stock. Then the days older than a year go into the rows of their months. Only data of this ledger is
-- touched; the totals, the cost basis and the net per day stay as they were. Idempotent: what is combined is gone
-- from the events.
Combine = function(state, now)
  local keep = Ledger.GetKeepDays() * DAY
  local hasOld = false
  for _, event in ipairs(state.events) do
    if event[TIME] < now - keep then
      hasOld = true
      break
    end
  end
  if hasOld then
    local cutoff = DayStart(now - keep)
    local costs, uncosted, lots, shares = CostBasis(state, cutoff)
    local basis = { costs = costs, uncosted = uncosted, shares = shares }
    local merger = RowMerger(state.days)
    local kept, count = {}, 0
    for _, event in ipairs(state.events) do
      if event[TIME] < cutoff then
        local start, char = DayStart(event[TIME]), event[CHAR]
        local function TotalsOf(item)
          return merger.At(start, char, item)
        end
        if event[ITEM] then
          SpreadEvent(TotalsOf, event, basis)
        else
          AddEvent(TotalsOf(false), event, basis)
        end
        count = count + 1
      else
        kept[#kept + 1] = event
      end
    end
    merger.Store()
    state.events = kept
    local stock = {}
    for item, queue in pairs(lots) do
      for _, lot in ipairs(queue) do
        if lot.count > 0 then
          stock[#stock + 1] = item
          stock[#stock + 1] = lot.char
          stock[#stock + 1] = lot.count
          stock[#stock + 1] = lot.price
        end
      end
    end
    state.stock = stock
    AM.DebugLog.Log("ledger", "combined %s events before %s, %s lots in stock", count, cutoff, #stock / 4)
  end
  local hasOldDays = false
  for _, row in ipairs(state.days) do
    if row[ROW_START] < now - MONTHS_AFTER then
      hasOldDays = true
      break
    end
  end
  if hasOldDays then
    local cutoff = DayStart(now - MONTHS_AFTER)
    local merger = RowMerger(state.months)
    local kept = {}
    for _, row in ipairs(state.days) do
      if row[ROW_START] < cutoff then
        AddRow(merger.At(MonthStart(row[ROW_START]), row[ROW_CHAR], row[ROW_ITEM]), row, true)
      else
        kept[#kept + 1] = row
      end
    end
    merger.Store()
    AM.DebugLog.Log("ledger", "combined %s days into months", #state.days - #kept)
    state.days = kept
  end
end

-- Keeps every event for this many days (one of KEEP_DAYS) and combines the older ones right away. Fewer days cannot
-- bring back the events combined.
function Ledger.SetKeepDays(days)
  AM.Settings.Set("ledgerDays", days)
  local state = State()
  Combine(state, time())
  AM.Events.Fire("LEDGER_CHANGED")
end

-- True while the ledger of this auction house holds nothing at all.
function Ledger.IsEmpty()
  local state = State()
  return #state.events == 0 and #state.days == 0 and #state.months == 0
end

-- Clears the ledger of the current auction house: its events, combined days and months, starting stock, open auctions
-- and characters, and the posts and cancels
-- waiting for the game. Nothing else (market prices, other auction houses) is touched. Running auctions are adopted
-- again from the next owned auctions list, without a deposit.
function Ledger.Reset()
  local state = State()
  wipe(state.events)
  wipe(state.open)
  wipe(state.chars)
  wipe(state.days)
  wipe(state.months)
  wipe(state.stock)
  wipe(cancelRequests)
  wipe(pendingPosts)
  AM.Events.Fire("LEDGER_CHANGED")
end

-- Demo mode (hidden developer command "/am demo", LedgerDemo builds the trades): the real ledger of this auction house
-- is moved aside to the faction object "ledgerDemoStash" and a demo ledger (flag `demo`) takes its place until
-- StopDemo moves it back. Nothing is booked while the demo is shown (Writable).
local DEMO_STASH = "ledgerDemoStash"

-- True while this auction house shows the demo ledger.
function Ledger.IsDemo()
  return State().demo == true
end

-- Replaces the ledger with a demo built from trades, booked by the character guid: { at, type (BOUGHT, SOLD or
-- VENDOR_BOUGHT), item, count, price, deposit, fee, createdAt }; a sale also gets its "auction created" event at
-- createdAt. The real ledger is moved aside first, unless the demo is already shown (then only the demo is built anew).
-- False if a stash is there although no demo is shown: it is never overwritten.
function Ledger.StartDemo(guid, trades)
  local Database = AM.Database
  if not Ledger.IsDemo() then
    if Database.HasFactionObject(DEMO_STASH) then
      AM.DebugLog.Log("ledger", "demo not started: a stashed ledger is there already")
      return false
    end
    Database.MoveFactionObject("ledger", DEMO_STASH)
  else
    Database.RemoveFactionObject("ledger")
  end
  local state = State()
  state.demo = true
  local char = CharIndex(state, guid)
  for _, trade in ipairs(trades) do
    if trade.type == Ledger.SOLD then
      state.events[#state.events + 1] = { trade.createdAt, Ledger.CREATED, char, trade.item, trade.count, trade.price,
        trade.deposit }
    end
    state.events[#state.events + 1] = { trade.at, trade.type, char, trade.item, trade.count, trade.price,
      trade.deposit, trade.fee }
  end
  table.sort(state.events, function(a, b)
    return a[TIME] < b[TIME]
  end)
  wipe(cancelRequests)
  wipe(pendingPosts)
  AM.Events.Fire("LEDGER_CHANGED")
  return true
end

-- Throws the demo away and moves the real ledger back. Nothing if no demo is shown.
function Ledger.StopDemo()
  if not Ledger.IsDemo() then
    return
  end
  AM.Database.MoveFactionObject(DEMO_STASH, "ledger")
  wipe(cancelRequests)
  wipe(pendingPosts)
  AM.Events.Fire("LEDGER_CHANGED")
end

-- The GUIDs of the characters that have events in the ledger, in the order they first had one (a copy).
function Ledger.GetCharacters()
  local list = {}
  for index, guid in ipairs(State().chars) do
    list[index] = guid
  end
  return list
end

function Ledger.GetEventCount()
  return #State().events
end

-- time, type, character GUID, itemDbKey, count, price, deposit, fee
function Ledger.GetEvent(index)
  local state = State()
  local event = state.events[index]
  if not event then
    return nil
  end
  return event[TIME], event[TYPE], state.chars[event[CHAR]], event[ITEM], event[COUNT], Money(event)
end

-- How the auctions of the item (itemDbKey, every character of this auction house) did by their price per unit: the
-- span from the lowest to the highest price split into `count` ranges of equal width, each with the units sold and
-- the units that came back (canceled or expired) at a price in it. Only the events kept (combined days have no prices)
-- and returns with a known price (stored since that was added). A table { low, high, ranges = { { from, to, sold,
-- unsold }, ... } } (prices in copper per unit, from/to rounded down, the last range includes high); nil when fewer
-- than two different prices are known: no span to show. Prices more than PRICE_OUTLIER_FACTOR times above or below
-- the median price of the units are left out: a single absurd post would squeeze all the others into one range.
local PRICE_OUTLIER_FACTOR = 5

-- The price per unit that half of the units were posted at or below (points sorted by unit).
local function MedianUnit(points, units)
  local seen = 0
  for _, point in ipairs(points) do
    seen = seen + point.count
    if seen * 2 >= units then
      return point.unit
    end
  end
end

function Ledger.GetPriceRanges(item, count)
  local all = {}
  local units = 0
  for _, event in ipairs(State().events) do
    local kind = event[TYPE]
    if event[ITEM] == item and event[PRICE] and event[COUNT] > 0
      and (kind == Ledger.SOLD or kind == Ledger.CANCELED or kind == Ledger.EXPIRED) then
      all[#all + 1] = { unit = event[PRICE] / event[COUNT], count = event[COUNT], sold = kind == Ledger.SOLD }
      units = units + event[COUNT]
    end
  end
  if #all == 0 then
    return nil
  end
  table.sort(all, function(a, b) return a.unit < b.unit end)
  local median = MedianUnit(all, units)
  local points = {}
  local low, high
  for _, point in ipairs(all) do
    if point.unit <= median * PRICE_OUTLIER_FACTOR and point.unit * PRICE_OUTLIER_FACTOR >= median then
      points[#points + 1] = point
      low = math.min(low or point.unit, point.unit)
      high = math.max(high or point.unit, point.unit)
    end
  end
  if high - low < 1 then
    return nil
  end
  local ranges = {}
  for index = 1, count do
    ranges[index] = { from = math.floor(low + (high - low) * (index - 1) / count),
      to = math.floor(low + (high - low) * index / count), sold = 0, unsold = 0 }
  end
  for _, point in ipairs(points) do
    local index = math.min(count, math.floor((point.unit - low) / (high - low) * count) + 1)
    local range = ranges[index]
    if point.sold then
      range.sold = range.sold + point.count
    else
      range.unsold = range.unsold + point.count
    end
  end
  return { low = math.floor(low), high = math.floor(high), ranges = ranges }
end

-- character GUID, itemDbKey, count, price, deposit, time created, duration of a running auction; nil if unknown.
function Ledger.GetOpen(auctionId)
  local state = State()
  local open = state.open[auctionId]
  if not open then
    return nil
  end
  return state.chars[open[OPEN_CHAR]], open[OPEN_ITEM], open[OPEN_COUNT], open[OPEN_PRICE], open[OPEN_DEPOSIT],
    open[OPEN_CREATED], open[OPEN_DURATION]
end
