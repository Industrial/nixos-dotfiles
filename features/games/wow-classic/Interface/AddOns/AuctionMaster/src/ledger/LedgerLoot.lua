local addonName, AM = ...

-- Plain data, no game calls: the loot window open now and which of its slots the ledger books (doc/notes/ledger.md,
-- "Loot", "Disenchanting"). Kept in memory only.
--
-- The game reads the loot window more than once per opening (LOOT_READY, LOOT_OPENED, LOOT_READY again), so every read
-- is handed in (Read) and replaces what is known of a slot not taken yet. A slot is booked when the game clears it
-- (Cleared), once; a slot given to another player (master loot) is dropped (Given). Closing the window forgets it.
-- A window of a disenchant (the read names the item disenchanted) books no loot: its slots taken are collected and
-- handed out as the disenchant's materials when the window closes (Close).
AM.LedgerLoot = {}
local LedgerLoot = AM.LedgerLoot

-- slot types of GetLootSlotType (Enum.LootSlotType): only items are booked, never coins or currencies
LedgerLoot.SLOT_ITEM = 1
-- item qualities and bind types (C_Item.GetItemInfo) that are not booked: poor quality is junk (loot, sold as junk
-- without an item, see Ledger.JUNK_SOLD), bound items and quest items can never reach the auction house
local POOR = 0
local BIND_ON_PICKUP, BIND_QUEST = 1, 4

local slots = {} -- slot index -> { link, count } of the slots that will be booked when taken
local taken = {} -- slot index -> true for the slots booked or given away in this window
local disenchanted -- link of the item this window's loot came from by a disenchant, nil for other loot
local materials = {} -- { link, count } of the slots of a disenchant's window taken so far

-- Whether a slot is booked when taken: info { type, link, count, quality, quest, bindType } as read from the game.
-- False for coins and currencies, junk, quest items and bound items; also when the bind type is not known yet (the
-- item data is not loaded: nothing is guessed, the next read may know it).
function LedgerLoot.IsBooked(info)
  if not info or info.type ~= LedgerLoot.SLOT_ITEM or not info.link or not info.count or info.count <= 0 then
    return false
  end
  if info.quest or info.quality == POOR or info.bindType == nil then
    return false
  end
  return info.bindType ~= BIND_ON_PICKUP and info.bindType ~= BIND_QUEST
end

-- A read of the loot window: infos by slot index (as for IsBooked; a slot missing or empty is not booked);
-- disenchantedLink: the link of the item disenchanted when the window is the loot of a disenchant (a read that does
-- not know it keeps what an earlier read of the window knew).
function LedgerLoot.Read(infos, count, disenchantedLink)
  disenchanted = disenchanted or disenchantedLink
  for slot = 1, count or 0 do
    if not taken[slot] then
      local info = infos[slot]
      if LedgerLoot.IsBooked(info) then
        slots[slot] = { link = info.link, count = info.count }
      else
        slots[slot] = nil
      end
    end
  end
end

-- The game cleared a slot: returns link and count to book as loot, once; nil when the slot is not booked or belongs
-- to a disenchant (kept for Close then).
function LedgerLoot.Cleared(slot)
  if taken[slot] then
    return nil
  end
  taken[slot] = true
  local entry = slots[slot]
  slots[slot] = nil
  if entry and disenchanted then
    materials[#materials + 1] = entry
    return nil
  end
  if entry then
    return entry.link, entry.count
  end
end

-- A slot was given to another player (master loot): it is not booked when it clears.
function LedgerLoot.Given(slot)
  taken[slot] = true
  slots[slot] = nil
end

-- The loot window closed. Returns the link of the item disenchanted and a list of { link, count } of the materials
-- taken, when the window was a disenchant's and anything was taken; nothing otherwise (also for a second close).
function LedgerLoot.Close()
  local item, list = disenchanted, materials
  slots, taken, disenchanted, materials = {}, {}, nil, {}
  if item and #list > 0 then
    return item, list
  end
end
