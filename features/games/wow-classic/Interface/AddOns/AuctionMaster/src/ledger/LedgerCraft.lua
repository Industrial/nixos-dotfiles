local addonName, AM = ...

-- Plain data, no game calls: the craft the player started and what each craft of it uses up, for the ledger
-- (doc/notes/ledger.md, "Crafting"). Kept in memory only.
--
-- A click on Create (C_TradeSkillUI.CraftRecipe) starts crafts of one recipe (Start). Every craft that went through
-- brings one TRADE_SKILL_ITEM_CRAFTED_RESULT (Result); an interrupted one brings none and uses up nothing. The
-- reagents of a craft come from the recipe: each basic slot its count, of the item the slot holds, or of the items the
-- call passed for it (a slot with several qualities); optional slots only what the call passed.
AM.LedgerCraft = {}
local LedgerCraft = AM.LedgerCraft

-- The crafts are forgotten when no result came for this long (a craft takes seconds).
local TIMEOUT = 60

local pending -- { output, reagents, casts, at }

-- What one craft uses up: slots { dataSlotIndex, basic, quantity, itemIds } from the recipe, passed the reagents the
-- call passed { dataSlotIndex, itemId, quantity }. Returns a list of { itemId, count }, each item once; nil and the
-- reason when a basic slot holds several items and the call did not say which (nothing is guessed).
function LedgerCraft.ReagentsOf(slots, passed)
  local bySlot = {}
  for _, reagent in ipairs(passed or {}) do
    if reagent.dataSlotIndex and reagent.itemId and reagent.quantity and reagent.quantity > 0 then
      local list = bySlot[reagent.dataSlotIndex] or {}
      bySlot[reagent.dataSlotIndex] = list
      list[#list + 1] = reagent
    end
  end
  local list, byItem = {}, {}
  local function Add(itemId, count)
    local entry = byItem[itemId]
    if entry then
      entry.count = entry.count + count
    else
      entry = { itemId = itemId, count = count }
      byItem[itemId] = entry
      list[#list + 1] = entry
    end
  end
  for index, slot in ipairs(slots) do
    local given = slot.dataSlotIndex and bySlot[slot.dataSlotIndex]
    if given then
      for _, reagent in ipairs(given) do
        Add(reagent.itemId, reagent.quantity)
      end
    elseif slot.basic then
      if #slot.itemIds ~= 1 or not slot.quantity or slot.quantity <= 0 then
        return nil, "slot " .. index .. ": " .. #slot.itemIds .. " items, none passed"
      end
      Add(slot.itemIds[1], slot.quantity)
    end
  end
  if #list == 0 then
    return nil, "no reagents"
  end
  return list
end

-- The player starts casts crafts of the item outputItemId, each using up reagents (ReagentsOf), at `now`. Replaces the
-- crafts started before (whatever of them did not go through was interrupted).
function LedgerCraft.Start(outputItemId, reagents, casts, now)
  pending = { output = outputItemId, reagents = reagents, casts = casts or 1, at = now }
end

-- The crafts started before are over: a craft the ledger does not track (enchanting, an order) started.
function LedgerCraft.Stop()
  pending = nil
end

-- A craft brought itemId at `now`: the reagents it used up (a copy), nil if it is none of the crafts started.
function LedgerCraft.Result(itemId, now)
  if pending and now - pending.at > TIMEOUT then
    pending = nil
  end
  if not pending or pending.output ~= itemId then
    return nil
  end
  pending.casts = pending.casts - 1
  pending.at = now
  local reagents = {}
  for index, reagent in ipairs(pending.reagents) do
    reagents[index] = { itemId = reagent.itemId, count = reagent.count }
  end
  if pending.casts <= 0 then
    pending = nil
  end
  return reagents
end
