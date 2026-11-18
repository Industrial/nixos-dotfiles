local addonName, AM = ...

-- Feeds the ledger with crafts (doc/notes/ledger.md, "Crafting"), read only (hooks after the call): the hook on
-- C_TradeSkillUI.CraftRecipe reads what one craft of the recipe uses up into LedgerCraft, and every
-- TRADE_SKILL_ITEM_CRAFTED_RESULT of it is booked with Ledger.BookCraft. Enchanting (no item made), salvaging and
-- recrafting are not booked. Classic (DoTradeSkill, no result event) is not booked yet either.
--
-- While the debug log is on, it also writes what a craft brings (lines "craft probe"): the calls, the recipe, then for
-- WATCH seconds the craft and cast events, loot lines and the bag counts of the reagents and the output, to check the
-- cases not seen yet (several items made, optional reagents, Classic).

local Log = function(...)
  AM.DebugLog.Log("ledger", ...)
end

local BASIC = Enum.CraftingReagentType and Enum.CraftingReagentType.Basic

-- Probe -------------------------------------------------------------------------------------------------

local WATCH = 30
local watched -- { itemIds, at }: the reagent and output items to count in the bags

local function Counts(itemIds)
  local parts = {}
  for _, itemId in ipairs(itemIds) do
    parts[#parts + 1] = itemId .. "=" .. tostring(C_Item.GetItemCount(itemId, false))
  end
  return table.concat(parts, " ")
end

-- Every field of a flat table as "key=value", nested tables as their size.
local function Fields(value)
  if type(value) ~= "table" then
    return tostring(value)
  end
  local parts = {}
  for key, field in pairs(value) do
    if type(field) == "table" then
      local size = 0
      for _ in pairs(field) do size = size + 1 end
      parts[#parts + 1] = tostring(key) .. "={" .. size .. "}"
    else
      parts[#parts + 1] = tostring(key) .. "=" .. tostring(field)
    end
  end
  table.sort(parts)
  return table.concat(parts, " ")
end

local function Watch(label, itemIds)
  watched = { itemIds = itemIds, at = time() }
  Log("craft probe %s: bags before %s", label, Counts(itemIds))
end

local function Watching()
  if watched and time() - watched.at > WATCH then
    watched = nil
  end
  return watched ~= nil
end

-- Recipe ------------------------------------------------------------------------------------------------

-- The slots of a recipe as LedgerCraft takes them, its output item and all items of it (for the probe); nil if the
-- game has no schematic.
local function ReadSchematic(recipeId)
  local schematic = C_TradeSkillUI.GetRecipeSchematic and C_TradeSkillUI.GetRecipeSchematic(recipeId, false)
  if not schematic then
    return nil
  end
  local slots, itemIds, described = {}, {}, {}
  for index, slot in ipairs(schematic.reagentSlotSchematics or {}) do
    local ids = {}
    for _, reagent in ipairs(slot.reagents or {}) do
      if reagent.itemID then
        ids[#ids + 1] = reagent.itemID
        itemIds[#itemIds + 1] = reagent.itemID
      end
    end
    slots[#slots + 1] = { dataSlotIndex = slot.dataSlotIndex, basic = slot.reagentType == BASIC,
      quantity = slot.quantityRequired, itemIds = ids }
    described[#described + 1] = string.format("%d:slot %s type %s x%s items %s", index, tostring(slot.dataSlotIndex),
      tostring(slot.reagentType), tostring(slot.quantityRequired), table.concat(ids, "/"))
  end
  if schematic.outputItemID then
    itemIds[#itemIds + 1] = schematic.outputItemID
  end
  if AM.DebugLog.IsEnabled() then
    Log("craft probe recipe %s: output %s x%s-%s, type %s, slots %s", recipeId, tostring(schematic.outputItemID),
      tostring(schematic.quantityMin), tostring(schematic.quantityMax), tostring(schematic.recipeType),
      table.concat(described, ", "))
  end
  return slots, schematic.outputItemID, itemIds
end

-- The reagents a craft call passed (the ones the player picked for a slot), as LedgerCraft takes them.
local function ReadPassed(reagents)
  local passed = {}
  for _, info in ipairs(type(reagents) == "table" and reagents or {}) do
    local reagent = info.reagent or info
    passed[#passed + 1] = { dataSlotIndex = info.dataSlotIndex, itemId = reagent.itemID, quantity = info.quantity }
  end
  return passed
end

local function DescribePassed(passed)
  local parts = {}
  for _, reagent in ipairs(passed) do
    parts[#parts + 1] = string.format("%s:%s x%s", tostring(reagent.dataSlotIndex), tostring(reagent.itemId),
      tostring(reagent.quantity))
  end
  return "{" .. table.concat(parts, ", ") .. "}"
end

-- Hooks -------------------------------------------------------------------------------------------------

local function OnCraftRecipe(recipeId, numCasts, reagents, recipeLevel, orderId, concentration)
  local passed = ReadPassed(reagents)
  Log("craft asked for: recipe %s casts %s reagents %s level %s order %s concentration %s", tostring(recipeId),
    tostring(numCasts), DescribePassed(passed), tostring(recipeLevel), tostring(orderId), tostring(concentration))
  local slots, output, itemIds = ReadSchematic(recipeId)
  if AM.DebugLog.IsEnabled() and itemIds then
    Watch("CraftRecipe", itemIds)
  end
  -- a craft for someone else's order uses (some of) their reagents: not booked
  if not slots or not output or orderId then
    AM.LedgerCraft.Stop()
    Log("craft of recipe %s not tracked: schematic %s output %s order %s", tostring(recipeId), tostring(slots ~= nil),
      tostring(output), tostring(orderId))
    return
  end
  local used, reason = AM.LedgerCraft.ReagentsOf(slots, passed)
  if not used then
    AM.LedgerCraft.Stop()
    Log("craft of recipe %s not tracked: %s", tostring(recipeId), reason)
    return
  end
  AM.LedgerCraft.Start(output, used, numCasts or 1, time())
end

if C_TradeSkillUI and C_TradeSkillUI.CraftRecipe then
  hooksecurefunc(C_TradeSkillUI, "CraftRecipe", function(...)
    local ok, err = pcall(OnCraftRecipe, ...)
    if not ok then
      Log("craft not read: %s", err)
    end
  end)
end

-- Not booked; logged for the probe and so a stale craft of another recipe cannot take their results.
for _, name in ipairs({ "CraftEnchant", "CraftSalvage", "RecraftRecipe" }) do
  if C_TradeSkillUI and type(C_TradeSkillUI[name]) == "function" then
    hooksecurefunc(C_TradeSkillUI, name, function(recipeId, numCasts, ...)
      pcall(function(...)
        AM.LedgerCraft.Stop()
        Log("craft probe %s: recipe %s casts %s args %s", name, tostring(recipeId), tostring(numCasts),
          AM.DebugLog.DescribeAll(...))
        if AM.DebugLog.IsEnabled() then
          local _, _, itemIds = ReadSchematic(recipeId)
          Watch(name, itemIds or {})
        end
      end, ...)
    end)
  end
end

-- Classic: DoTradeSkill(index, repeatCount) on the recipe of the open profession window. Only the probe for now.
if DoTradeSkill and GetTradeSkillInfo then
  hooksecurefunc("DoTradeSkill", function(index, repeatCount)
    if not AM.DebugLog.IsEnabled() then
      return
    end
    pcall(function()
      local recipe = AM.ShoppingList.ReadClassicRecipe(index)
      local itemIds, parts = {}, {}
      for _, reagent in ipairs(recipe and recipe.reagents or {}) do
        itemIds[#itemIds + 1] = reagent.itemId
        parts[#parts + 1] = reagent.itemId .. " x" .. tostring(reagent.quantity)
      end
      if recipe and recipe.outputItemId then
        itemIds[#itemIds + 1] = recipe.outputItemId
      end
      Log("craft probe DoTradeSkill: index %s repeat %s, recipe %s, output %s, reagents %s", tostring(index),
        tostring(repeatCount), recipe and recipe.name or "nil", recipe and tostring(recipe.outputItemId) or "nil",
        table.concat(parts, ", "))
      Watch("DoTradeSkill", itemIds)
    end)
  end)
end

-- Events ------------------------------------------------------------------------------------------------

-- A craft went through: books it with what one craft of the recipe uses up. The item from the result's link (an
-- equipment key needs its item level), the reagents by their itemID (reagents are no equipment).
local function OnCraftedResult(data)
  if type(data) ~= "table" or not data.itemID or data.isEnchant then
    return
  end
  local used = AM.LedgerCraft.Result(data.itemID, time())
  if not used then
    Log("crafted %s x%s: not started by a tracked craft", tostring(data.itemID), tostring(data.quantity))
    return
  end
  local reagents = {}
  for index, reagent in ipairs(used) do
    reagents[index] = { item = AM.ItemDbKey.ForItem(reagent.itemId), count = reagent.count }
  end
  local item = data.hyperlink and AM.ItemDbKey.FromLink(data.hyperlink) or AM.ItemDbKey.ForItem(data.itemID)
  AM.Ledger.BookCraft(UnitGUID("player"), item, data.quantity, reagents)
end

local frame = CreateFrame("Frame")
for _, event in ipairs({ "TRADE_SKILL_CRAFT_BEGIN", "TRADE_SKILL_ITEM_CRAFTED_RESULT", "UPDATE_TRADESKILL_CAST_STOPPED",
  "TRADE_SKILL_CURRENCY_REWARD_RESULT", "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED",
  "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_STOP", "CHAT_MSG_LOOT", "ITEM_PUSH",
  "BAG_UPDATE_DELAYED", "UI_ERROR_MESSAGE" }) do
  pcall(frame.RegisterEvent, frame, event)
end

frame:SetScript("OnEvent", function(_, event, ...)
  if event == "TRADE_SKILL_ITEM_CRAFTED_RESULT" then
    local ok, err = pcall(OnCraftedResult, ...)
    if not ok then
      Log("crafted result not read: %s", err)
    end
  end
  if not AM.DebugLog.IsEnabled() or not Watching() then
    return
  end
  pcall(function(...)
    if event:find("^UNIT_SPELLCAST") then
      if ... ~= "player" then
        return
      end
      Log("craft probe %s %s", event, AM.DebugLog.DescribeAll(...))
    elseif event == "TRADE_SKILL_ITEM_CRAFTED_RESULT" or event == "TRADE_SKILL_CURRENCY_REWARD_RESULT" then
      Log("craft probe %s %s", event, Fields(...))
    elseif event == "BAG_UPDATE_DELAYED" then
      Log("craft probe bags now %s", Counts(watched.itemIds))
    else
      Log("craft probe %s %s", event, AM.DebugLog.DescribeAll(...))
    end
    watched.at = time()
  end, ...)
end)
