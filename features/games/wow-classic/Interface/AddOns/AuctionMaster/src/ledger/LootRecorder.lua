local addonName, AM = ...

-- Feeds the ledger with looted items (doc/notes/ledger.md, "Loot"), read only: every read of the loot window
-- (LOOT_READY, LOOT_OPENED) goes into LedgerLoot, every LOOT_SLOT_CLEARED of an item slot it books is booked with
-- Ledger.BookLoot. Mob loot, skinning, gathering and fishing all come through the loot window; quest rewards, mail,
-- crafts and purchases never do. A slot the master looter gives to someone else is not booked; items won by a group
-- roll are not booked (they do not come through the player's own slots).
-- A loot window of a disenchant books no loot: at LOOT_CLOSED its item and the materials taken are booked with
-- Ledger.BookDisenchant.
--
-- While the debug log is on, it also writes what looting brings (lines "loot probe"), kept for the cases not seen yet
-- (opened containers, group loot):
--   - the player's casts (spell id and name; gathering is a cast on the node or corpse)
--   - LOOT_READY / LOOT_OPENED with every slot of the loot window (item, count, type, sources, fishing)
--   - LOOT_SLOT_CLEARED, LOOT_CLOSED, CHAT_MSG_LOOT, CHAT_MSG_MONEY, CHAT_MSG_CURRENCY, ITEM_PUSH
--   - quest rewards, trades, the mailbox opening and closing
--   - disenchanting (seen on Forever, kept for the cases not seen yet): the bag items locked during the cast and the
--     GUID of the item a loot window came from
--   - after each BAG_UPDATE_DELAYED, what changed in the bags (itemId and the difference), so every item that arrives
--     shows, however it came
-- Nothing is changed.

local Log = function(...)
  AM.DebugLog.Log("ledger", ...)
end

local BIND_TYPE_INDEX = 14 -- of C_Item.GetItemInfo

-- Recording ---------------------------------------------------------------------------------------------

-- Disenchanting (doc/notes/ledger.md, "Disenchanting"): on Forever the cast succeeds in the same frame as the loot
-- window opens, and the window names the item as its source (a GUID of type Item, still known to
-- C_Item.GetItemLinkByGUID). An opened container has an item as its source too, so a window is a disenchant's only
-- right after a disenchant cast.
local DISENCHANT_WINDOW = 2
local disenchantedAt -- GetTime() of the player's last disenchant cast that succeeded, until a loot window closes

-- The link of the item disenchanted when the loot window open now is a disenchant's, nil otherwise.
local function DisenchantedItem(count)
  if not disenchantedAt or GetTime() - disenchantedAt > DISENCHANT_WINDOW or not GetLootSourceInfo then
    return nil
  end
  for slot = 1, count do
    local source = GetLootSourceInfo(slot)
    if type(source) == "string" and source:find("^Item") then
      local link = C_Item.GetItemLinkByGUID and C_Item.GetItemLinkByGUID(source)
      if link then
        return link
      end
      Log("disenchant: item %s not known, booked as loot", source)
      return nil
    end
  end
  Log("disenchant: loot window without an item as source, booked as loot")
end

-- Books the disenchant of a loot window that closed: the item and the materials taken (links and counts), each
-- material with what one sells for now.
local function BookDisenchant(link, taken)
  local guid = UnitGUID("player")
  local materials = {}
  for _, entry in ipairs(taken) do
    local key, reason = AM.ItemDbKey.FromLink(entry.link)
    if key then
      materials[#materials + 1] = { item = key, count = entry.count, value = AM.RecipeCost.GetSellValue(key) }
    else
      Log("disenchant material not booked: %s x%s, %s", entry.link, entry.count, reason)
    end
  end
  local item, reason = AM.ItemDbKey.FromLink(link)
  if item and AM.Ledger.BookDisenchant(guid, item, 1, materials) then
    return
  end
  -- the item is not known: the materials go into stock as loot, as without a disenchant
  Log("disenchant of %s not booked (%s), materials booked as loot", link, tostring(reason))
  for _, material in ipairs(materials) do
    AM.Ledger.BookLoot(guid, material.item, material.count)
  end
end

-- Hands the loot window as it is now to LedgerLoot.
local function ReadWindow()
  local count = GetNumLootItems() or 0
  local infos = {}
  for slot = 1, count do
    local _, _, quantity, _, quality, _, isQuestItem = GetLootSlotInfo(slot)
    local link = GetLootSlotLink(slot)
    local bindType
    if link then
      bindType = select(BIND_TYPE_INDEX, C_Item.GetItemInfo(link))
      if bindType == nil and C_Item.RequestLoadItemDataByID then
        -- the next read of the window may know it
        C_Item.RequestLoadItemDataByID(link)
      end
    end
    infos[slot] = { type = GetLootSlotType(slot), link = link, count = quantity, quality = quality,
      quest = isQuestItem, bindType = bindType }
  end
  AM.LedgerLoot.Read(infos, count, DisenchantedItem(count))
end

local function OnSlotCleared(slot)
  local link, count = AM.LedgerLoot.Cleared(slot)
  if not link then
    return
  end
  local item, reason = AM.ItemDbKey.FromLink(link)
  if not item then
    Log("loot not booked: %s x%s, %s", link, count, reason)
    return
  end
  AM.Ledger.BookLoot(UnitGUID("player"), item, count)
end

-- Master loot: a slot given to another player clears too, it is not the player's loot.
if type(GiveMasterLoot) == "function" then
  hooksecurefunc("GiveMasterLoot", function(slot, candidate)
    local name = GetMasterLootCandidate and GetMasterLootCandidate(slot, candidate)
    if name ~= UnitName("player") then
      AM.LedgerLoot.Given(slot)
    end
  end)
end

local recorder = CreateFrame("Frame")
for _, event in ipairs({ "LOOT_READY", "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_CLOSED" }) do
  recorder:RegisterEvent(event)
end
recorder:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
recorder:SetScript("OnEvent", function(_, event, slot, _, spellId)
  local ok, err = pcall(function()
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
      if AM.Disenchant and spellId == AM.Disenchant.SPELL_ID then
        disenchantedAt = GetTime()
      end
    elseif event == "LOOT_SLOT_CLEARED" then
      OnSlotCleared(slot)
    elseif event == "LOOT_CLOSED" then
      disenchantedAt = nil
      local link, taken = AM.LedgerLoot.Close()
      if link then
        BookDisenchant(link, taken)
      end
    else
      ReadWindow()
    end
  end)
  if not ok then
    Log("loot %s not read: %s", event, err)
  end
end)

-- Probe -------------------------------------------------------------------------------------------------

-- The bags of the player, itemId -> count (bank not included).
local function ReadBags()
  local counts = {}
  local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
  for bag = 0, last do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID then
        counts[info.itemID] = (counts[info.itemID] or 0) + (info.stackCount or 1)
      end
    end
  end
  return counts
end

local bags -- the counts read last, nil until the first read while the log is on

-- What changed in the bags since the last read, as "itemId+n itemId-n", sorted by itemId; nil when nothing did.
local function BagChanges()
  local now = ReadBags()
  local before = bags
  bags = now
  if not before then
    return nil
  end
  local changes = {}
  for itemId, count in pairs(now) do
    if count ~= (before[itemId] or 0) then
      changes[#changes + 1] = { itemId, count - (before[itemId] or 0) }
    end
  end
  for itemId, count in pairs(before) do
    if not now[itemId] then
      changes[#changes + 1] = { itemId, -count }
    end
  end
  if #changes == 0 then
    return nil
  end
  table.sort(changes, function(a, b) return a[1] < b[1] end)
  local parts = {}
  for index, change in ipairs(changes) do
    parts[index] = string.format("%d%+d", change[1], change[2])
  end
  return table.concat(parts, " ")
end

local function Try(func, ...)
  if type(func) == "function" then
    return func(...)
  end
end

-- The type of a GUID ("Creature", "GameObject", "Item", ...) and its id (npc or object id), from "Type-0-...-id-spawn".
local function DescribeGuid(guid)
  if type(guid) ~= "string" then
    return tostring(guid)
  end
  local kind = guid:match("^(%a+)")
  local id = select(6, strsplit("-", guid))
  return string.format("%s:%s", tostring(kind), tostring(id))
end

-- Every slot of the open loot window: type, item link or name, count, quality, quest item, and where it came from
-- (GetLootSourceInfo: pairs of GUID and count, several when loot of more corpses is merged).
local function LogLootWindow(event, ...)
  Log("loot probe %s %s, fishing %s, slots %s", event, AM.DebugLog.DescribeAll(...), tostring(Try(IsFishingLoot)),
    tostring(Try(GetNumLootItems)))
  for slot = 1, Try(GetNumLootItems) or 0 do
    local _, name, quantity, currencyId, quality, locked, isQuestItem = GetLootSlotInfo(slot)
    local sources = { Try(GetLootSourceInfo, slot) }
    local from = {}
    for index = 1, #sources, 2 do
      from[#from + 1] = DescribeGuid(sources[index]) .. "x" .. tostring(sources[index + 1])
      local source = sources[index]
      if type(source) == "string" and source:find("^Item") then
        -- a disenchanted item: is it still known by its GUID?
        from[#from] = string.format("%s (%s, item %s, %s)", from[#from], source,
          tostring(Try(C_Item.GetItemIDByGUID, source)), tostring(Try(C_Item.GetItemLinkByGUID, source)))
      end
    end
    Log("loot probe slot %s: type %s, %s x%s, currency %s, quality %s, locked %s, quest %s, from %s", slot,
      tostring(Try(GetLootSlotType, slot)), tostring(Try(GetLootSlotLink, slot) or name), tostring(quantity),
      tostring(currencyId), tostring(quality), tostring(locked), tostring(isQuestItem), table.concat(from, " "))
  end
end

-- Disenchanting (doc/notes/ledger.md, "Disenchanting"): the cast events do not name the item, so the probe writes
-- what may tell it: the bag items locked at each step of a disenchant cast, ITEM_LOCK_CHANGED for WATCH_DISENCHANT
-- seconds after it was sent, and the GUID of the item a loot window came from. Never hooks bag item use
-- (UseContainerItem, PickupContainerItem): that tainted the game's item use before (commit 1999ddd).
local WATCH_DISENCHANT = 10
local disenchantSent -- when the last disenchant was sent

local function IsDisenchant(spellId)
  return AM.Disenchant and spellId == AM.Disenchant.SPELL_ID
end

local function DescribeSlot(bag, slot)
  local info = bag and slot and C_Container.GetContainerItemInfo(bag, slot)
  if not info then
    return string.format("%s/%s empty", tostring(bag), tostring(slot))
  end
  return string.format("%s/%s %s x%s locked %s", bag, slot, tostring(info.hyperlink or info.itemID),
    tostring(info.stackCount), tostring(info.isLocked))
end

local function LockedItems()
  local parts = {}
  local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
  for bag = 0, last do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.isLocked then
        parts[#parts + 1] = DescribeSlot(bag, slot)
      end
    end
  end
  return #parts > 0 and table.concat(parts, ", ") or "none"
end

local EVENTS = {
  "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "ITEM_LOCK_CHANGED",
  "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
  "LOOT_READY", "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_CLOSED", "LOOT_BIND_CONFIRM",
  "CHAT_MSG_LOOT", "CHAT_MSG_MONEY", "CHAT_MSG_CURRENCY", "ITEM_PUSH", "BAG_UPDATE_DELAYED",
  "QUEST_TURNED_IN", "QUEST_LOOT_RECEIVED", "TRADE_SHOW", "TRADE_ACCEPT_UPDATE", "TRADE_CLOSED",
  "MAIL_SHOW", "MAIL_CLOSED", "SHOW_LOOT_TOAST", "ENCOUNTER_LOOT_RECEIVED",
}

local frame = CreateFrame("Frame")
for _, event in ipairs(EVENTS) do
  pcall(frame.RegisterEvent, frame, event)
end

frame:SetScript("OnEvent", function(_, event, ...)
  if not AM.DebugLog.IsEnabled() then
    bags = nil
    return
  end
  local ok, err = pcall(function(...)
    if event:find("^UNIT_SPELLCAST") then
      if ... ~= "player" then
        return
      end
      -- SENT: unit, target name, castGUID, spellID; the others: unit, castGUID, spellID
      local spellId = event == "UNIT_SPELLCAST_SENT" and select(4, ...) or select(3, ...)
      if (event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_STOP") and not IsDisenchant(spellId) then
        return
      end
      local info = spellId and C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellId)
      local name = info and info.name or (GetSpellInfo and spellId and GetSpellInfo(spellId))
      Log("loot probe %s spell %s (%s) %s", event, tostring(spellId), tostring(name), AM.DebugLog.DescribeAll(...))
      if IsDisenchant(spellId) then
        if event == "UNIT_SPELLCAST_SENT" then
          disenchantSent = GetTime()
        end
        Log("loot probe disenchant %s, locked %s", event, LockedItems())
      end
    elseif event == "ITEM_LOCK_CHANGED" then
      if disenchantSent and GetTime() - disenchantSent <= WATCH_DISENCHANT then
        local bag, slot = ...
        Log("loot probe ITEM_LOCK_CHANGED %s", slot and DescribeSlot(bag, slot) or ("equipped " .. tostring(bag)))
      end
    elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
      LogLootWindow(event, ...)
    elseif event == "BAG_UPDATE_DELAYED" then
      local changes = BagChanges()
      if changes then
        Log("loot probe bags %s", changes)
      end
    else
      Log("loot probe %s %s", event, AM.DebugLog.DescribeAll(...))
    end
  end, ...)
  if not ok then
    Log("loot probe %s failed: %s", event, err)
  end
end)
