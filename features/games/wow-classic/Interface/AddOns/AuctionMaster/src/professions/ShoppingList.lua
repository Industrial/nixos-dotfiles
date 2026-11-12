local addonName, AM = ...

-- The data and the actions of the shopping lists; they are shown in the panel of the Buy tab (ShoppingPanel.lua) and
-- in the objective tracker (tracker/).
-- There is one list per crafter,
-- a character of the faction (kept by its GUID): a recipe is added to the list of the character that makes it,
-- the reagents of its recipes are summed up and compared with what the character using the window carries. The
-- recipes are stored together with their name, icon and reagents as of adding them: the classic profession API
-- only answers while the profession window is open.
-- The global object "shoppingList" holds the lists, "shoppingPanel" the state of the view (collapsed
-- sections), so that it can be reset without losing the lists.
AM.ShoppingList = {}
local ShoppingList = AM.ShoppingList

-- Lists from before they belonged to crafters are moved to the character that can make the recipes, else to
-- the current one. Recipes of the same id are merged.
local function Migrate(data)
  local old = data.lists
  data.lists = nil
  data.activeId, data.nextId = nil, nil
  if not old then
    return
  end
  data.crafters = data.crafters or {}
  local player = UnitGUID("player")
  for _, oldList in ipairs(old) do
    for _, entry in ipairs(oldList.recipes or {}) do
      local guid = player
      for _, known in ipairs(entry.outputItemId and AM.ProfessionScanner.GetRecipes(entry.outputItemId) or {}) do
        if known.id == entry.id and not tContains(known.crafters, player) then
          guid = known.crafters[1]
        end
      end
      local list = data.crafters[guid]
      if not list then
        list = { guid = guid, recipes = {} }
        data.crafters[guid] = list
      end
      local merged
      for _, existing in ipairs(list.recipes) do
        if existing.id == entry.id then
          existing.qty = existing.qty + entry.qty
          merged = true
        end
      end
      if not merged then
        list.recipes[#list.recipes + 1] = entry
      end
    end
  end
end

function ShoppingList.GetData()
  local data = AM.Database.GetGlobalObject("shoppingList")
  if data.lists then
    Migrate(data)
  end
  return data
end
local GetData = ShoppingList.GetData

function ShoppingList.GetView()
  return AM.Database.GetGlobalObject("shoppingPanel")
end

-- The list of the crafter, made when it is first asked for.
function ShoppingList.GetList(guid)
  local data = GetData()
  data.crafters = data.crafters or {}
  local list = data.crafters[guid]
  if not list then
    list = { guid = guid, recipes = {} }
    data.crafters[guid] = list
  end
  return list
end
local GetList = ShoppingList.GetList

-- The characters that have a list: all that know a recipe of this faction, those with recipes on their list and
-- the current one, each { guid, name, class (file name, may be nil), count (recipes on the list) }, sorted by name.
-- Ignored characters are left out (their lists are kept for when they are not), the current one is never.
function ShoppingList.GetCrafters()
  local characters = AM.Database.GetGlobalObject("characters")
  local guids = { [UnitGUID("player")] = true }
  for guid, list in pairs(GetData().crafters or {}) do
    if #list.recipes > 0 and not AM.ProfessionScanner.IsCharacterIgnored(guid) then
      guids[guid] = true
    end
  end
  for _, recipes in pairs(AM.Database.GetFactionObject("recipes")) do
    for _, recipe in ipairs(recipes) do
      for _, guid in ipairs(AM.ProfessionScanner.GetActiveCrafters(recipe)) do
        guids[guid] = true
      end
    end
  end
  local crafters = {}
  for guid in pairs(guids) do
    local character = characters[guid]
    -- an earlier version stored the bare name instead of a table
    if type(character) == "table" then
      local list = GetData().crafters and GetData().crafters[guid]
      crafters[#crafters + 1] = { guid = guid, name = AM.RecipeList.GetCharacterName(character),
        class = character.class, count = list and #list.recipes or 0 }
    end
  end
  table.sort(crafters, function(a, b)
    return a.name < b.name
  end)
  return crafters
end

-- Name and class of a crafter as { guid, name, class }.
function ShoppingList.GetCrafter(guid)
  local character = AM.Database.GetGlobalObject("characters")[guid]
  if type(character) == "table" then
    return { guid = guid, name = AM.RecipeList.GetCharacterName(character), class = character.class }
  end
  return { guid = guid, name = UNKNOWN }
end

-- The crafter whose list the views are limited to, nil for all lists. One that has no recipes any more (or is
-- ignored or deleted) is dropped.
function ShoppingList.GetFilter()
  local data = GetData()
  local chosen = data.activeGuid
  local list = chosen and data.crafters and data.crafters[chosen]
  if chosen and not (list and #list.recipes > 0 and not AM.ProfessionScanner.IsCharacterIgnored(chosen)) then
    data.activeGuid = nil
  end
  return data.activeGuid
end

-- The lists that the views show: the one of the crafter chosen, else all lists with recipes (the current character
-- first, then by name). The list of the current character if there is none.
function ShoppingList.GetShownLists()
  local chosen = ShoppingList.GetFilter()
  if chosen then
    return { GetList(chosen) }
  end
  return ShoppingList.GetAllLists()
end

-- All lists with recipes (the current character first, then by name), regardless of the filter. The list of the
-- current character if there is none.
function ShoppingList.GetAllLists()
  local data = GetData()
  local lists = {}
  for _, crafter in ipairs(ShoppingList.GetCrafters()) do
    if crafter.count > 0 then
      lists[#lists + 1] = { list = data.crafters[crafter.guid], own = crafter.guid == UnitGUID("player") }
    end
  end
  table.sort(lists, function(a, b)
    return a.own and not b.own
  end)
  for i, entry in ipairs(lists) do
    lists[i] = entry.list
  end
  if #lists == 0 then
    lists[1] = GetList(UnitGUID("player"))
  end
  return lists
end

-- Limits the views to the list of the crafter, nil shows all lists.
function ShoppingList.SelectCrafter(guid)
  GetData().activeGuid = guid
  ShoppingList.Refresh()
end

-- Retail has the schematic API, the classic clients the older TradeSkill functions.
function ShoppingList.IsRetail()
  return C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic and Enum.CraftingReagentType
end
local IsRetail = ShoppingList.IsRetail

-- False for a window that shows the recipes of someone else: a linked profession, a guild member's or an NPC's.
function ShoppingList.IsOwnCrafting()
  for _, name in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsNPCCrafting" }) do
    local check = C_TradeSkillUI and C_TradeSkillUI[name] or _G[name]
    if check and check() then
      return false
    end
  end
  return true
end

function ShoppingList.IsSupported()
  return IsRetail() or GetNumTradeSkills
end

-- What the current character owns of the item (all its qualities): bags, bank and account bank as the game counts them,
-- plus what waits in the mail (bought at the auction house or seen in the mailbox).
local function CountLive(itemIds)
  local getCount = C_Item.GetItemCount or GetItemCount
  local count = AM.Mailbox.GetCount(UnitGUID("player"), itemIds)
  for _, itemId in ipairs(itemIds) do
    count = count + getCount(itemId, true, false, true, true)
  end
  return count
end

-- What the crafter carries of the item (bags, bank, mail), as last seen when played. 0 for the current character,
-- who is counted by CountLive.
local function CountStored(itemIds, guid)
  if guid == UnitGUID("player") then
    return 0
  end
  local count = AM.Mailbox.GetCount(guid, itemIds)
  for _, itemId in ipairs(itemIds) do
    count = count + AM.Inventory.GetCount(guid, itemId)
  end
  return count
end

-- Owned by the current character plus the crafter of the list.
local function CountOwned(itemIds, guid)
  return CountLive(itemIds) + CountStored(itemIds, guid)
end

-- The most characters whose stock is counted for one item (the current one, the crafters of the lists and the others
-- added below).
local MAX_CHARACTERS = 5

-- Adds the stock of other known characters while the need is not covered, the biggest stock first, so that as few as
-- possible are needed, up to MAX_CHARACTERS together with the ones in counted (guid -> true: already part of owned).
-- Ignored characters are left out. Returns the new owned and the GUIDs added.
local function AddOtherStock(itemIds, owned, need, counted)
  local used = {}
  if owned >= need then
    return owned, used
  end
  local numCounted = 0
  for _ in pairs(counted) do
    numCounted = numCounted + 1
  end
  local candidates = {}
  for guid in pairs(AM.Database.GetGlobalObject("characters")) do
    if not counted[guid] and not AM.ProfessionScanner.IsCharacterIgnored(guid) then
      local stock = CountStored(itemIds, guid)
      if stock > 0 then
        candidates[#candidates + 1] = { guid = guid, stock = stock }
      end
    end
  end
  table.sort(candidates, function(a, b)
    if a.stock ~= b.stock then
      return a.stock > b.stock
    end
    return a.guid < b.guid
  end)
  for _, candidate in ipairs(candidates) do
    if owned >= need or numCounted + #used >= MAX_CHARACTERS then
      break
    end
    owned = owned + candidate.stock
    used[#used + 1] = candidate.guid
  end
  return owned, used
end

-- Name and quality of an item are nil until it is cached.
-- Where a missing item is cheapest to get, as a texture string to put in front of its name: the gossip icons of the
-- auctioneer and the vendor. Empty for an item that has no known source.
local SOURCE_ICONS = {
  auction = "Interface\\GossipFrame\\AuctioneerGossipIcon",
  vendor = "Interface\\GossipFrame\\VendorGossipIcon",
}

-- size: height of the icon in pixels, 0 for the height of the text
function ShoppingList.GetSourceIcon(item, size)
  local texture = SOURCE_ICONS[item.source]
  return texture and ("|T" .. texture .. ":" .. (size or 0) .. "|t ") or ""
end

function ShoppingList.GetItemDetails(itemId)
  local name, _, quality = C_Item.GetItemInfo(itemId)
  if not name and C_Item.RequestLoadItemDataByID then
    C_Item.RequestLoadItemDataByID(itemId)
  end
  return name, quality, select(5, C_Item.GetItemInfoInstant(itemId))
end

-- Name of a recipe in the language of the client now, looked up by its ids; the name stored with the entry
-- (the language it was added in) is only the fallback while the game cannot tell yet.
function ShoppingList.GetRecipeName(entry)
  local name
  if type(entry.id) == "number" then
    name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(entry.id)
      or GetSpellInfo and (GetSpellInfo(entry.id))
  end
  if not name and entry.outputItemId then
    name = (ShoppingList.GetItemDetails(entry.outputItemId))
  end
  return name or entry.name
end

-- The recipes as { id, name, icon, reagents } read from the open profession window, reagents being
-- { itemId, itemIds, quantity }. Reagents with several qualities (retail) are one entry, owned
-- quantities of all qualities count. Return nil if there is no craftable recipe.
function ShoppingList.ReadRetailRecipe(recipeId)
  local info = C_TradeSkillUI.GetRecipeInfo(recipeId)
  local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeId, false)
  if not info or not schematic then
    return nil
  end
  local reagents = {}
  for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
    local first = slot.reagents and slot.reagents[1]
    if slot.reagentType == Enum.CraftingReagentType.Basic and first and first.itemID then
      local itemIds = {}
      for _, reagent in ipairs(slot.reagents) do
        itemIds[#itemIds + 1] = reagent.itemID
      end
      reagents[#reagents + 1] = { itemId = first.itemID, itemIds = itemIds, quantity = slot.quantityRequired }
    end
  end
  local baseInfo = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
  return { id = recipeId, name = info.name, icon = info.icon, skillLine = baseInfo and baseInfo.professionID,
    professionName = baseInfo and baseInfo.professionName,
    professionIcon = baseInfo and baseInfo.professionID and C_TradeSkillUI.GetTradeSkillTexture
      and C_TradeSkillUI.GetTradeSkillTexture(baseInfo.professionID),
    outputItemId = schematic.outputItemID, reagents = reagents,
    outputCount = ((schematic.quantityMin or 1) + (schematic.quantityMax or 1)) / 2 }
end

-- Reads the recipe at index of the open profession window, the selected one if omitted.
function ShoppingList.ReadClassicRecipe(index)
  index = index or GetTradeSkillSelectionIndex()
  local name, skillType = GetTradeSkillInfo(index)
  if not name or skillType == "header" or skillType == "subheader" then
    return nil
  end
  local reagents = {}
  for i = 1, GetTradeSkillNumReagents(index) do
    local link = GetTradeSkillReagentItemLink(index, i)
    local itemId = link and tonumber(link:match("item:(%d+)"))
    local quantity = select(3, GetTradeSkillReagentInfo(index, i))
    if itemId then
      reagents[#reagents + 1] = { itemId = itemId, itemIds = { itemId }, quantity = quantity }
    end
  end
  local recipeLink = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(index)
  local itemLink = GetTradeSkillItemLink and GetTradeSkillItemLink(index)
  local minMade, maxMade = 1, 1
  if GetTradeSkillNumMade then
    minMade, maxMade = GetTradeSkillNumMade(index)
  end
  local profession = GetTradeSkillLine()
  local skillLine, professionIcon
  if GetProfessions then
    for _, slot in pairs({ GetProfessions() }) do
      local professionName, icon, _, _, _, _, line = GetProfessionInfo(slot)
      if professionName == profession then
        skillLine, professionIcon = line, icon
      end
    end
  end
  return { id = recipeLink and tonumber(recipeLink:match("enchant:(%d+)")) or name, name = name,
    icon = GetTradeSkillIcon(index), profession = profession, skillLine = skillLine, professionName = profession,
    professionIcon = professionIcon, reagents = reagents,
    outputItemId = itemLink and tonumber(itemLink:match("item:(%d+)")),
    outputCount = ((minMade or 1) + (maxMade or 1)) / 2 }
end

-- Crafted reagents of crafted reagents are followed this deep.
local MAX_CRAFT_DEPTH = 4

-- A reagent to buy is worth a hint when another character of the faction can craft it at least this much
-- cheaper (a fraction of the price).
local CRAFT_HINT_SAVING = 0.15

-- The other character that crafts the item clearly cheaper than the owner of the list can get it:
-- { guid, saving (fraction of buy.price) }, nil if there is none.
local function FindCheaperCrafter(itemId, buy, ownerGuid)
  local best
  -- no owner given means the current character
  local seen = { [ownerGuid or UnitGUID("player")] = true }
  for _, recipe in ipairs(AM.ProfessionScanner.GetRecipes(itemId)) do
    for _, guid in ipairs(recipe.crafters) do
      if not seen[guid] then
        seen[guid] = true
        local crafted = AM.RecipeCost.GetBuyPrice(itemId, guid)
        if crafted and crafted.source == "crafted" then
          local saving = 1 - crafted.price / buy.price
          if saving >= CRAFT_HINT_SAVING and (not best or saving > best.saving) then
            best = { guid = guid, saving = saving }
          end
        end
      end
    end
  end
  return best
end

-- Adds what the missing items cost at the auction house (item.price, nil if unknown or if the item is crafted,
-- in which case its own reagents are bought), model.toBuy, and the profit of the recipes, model.profit (nil if
-- no recipe has one).
local function AddPrices(model, crafter)
  model.toBuy = 0
  for _, item in ipairs(model.items) do
    local buy = AM.RecipeCost.GetBuyPrice(item.itemId, crafter)
    if buy and buy.source ~= "crafted" and item.need > item.have then
      item.source = buy.source
      item.price = buy.price * (item.need - item.have)
      model.toBuy = model.toBuy + item.price
      item.craftHint = FindCheaperCrafter(item.itemId, buy, crafter)
    end
  end
  model.profit = nil
  for _, recipe in ipairs(model.recipes) do
    if recipe.profit then
      model.profit = (model.profit or 0) + recipe.profit
    end
  end
end

-- Sums up the reagents of all recipes of the list. A recipe is ready when it can be crafted from what is
-- owned, recipes higher in the list claim the reagents first.
function ShoppingList.BuildModel(list)
  -- intermediates: recipes crafted on the way for the reagents that are cheaper to craft than to buy
  local model = { recipes = {}, intermediates = {}, items = {}, needed = {}, done = {}, totalNeed = 0, totalHave = 0 }
  local itemsById = {}
  local intermediatesById = {}
  local ownedLeft = {} -- owned amount of crafted reagents not claimed by a craft yet
  for index, entry in ipairs(list.recipes) do
    local recipe = { index = index, guid = list.guid, crafterName = ShoppingList.GetCrafter(list.guid).name,
      id = entry.id, qty = entry.qty, name = ShoppingList.GetRecipeName(entry), icon = entry.icon,
      skillLine = entry.skillLine, profession = entry.profession, outputItemId = entry.outputItemId, reagents = {} }
    local result = AM.RecipeCost.Calculate({ id = entry.id, outputItemId = entry.outputItemId,
      outputCount = entry.outputCount, reagents = entry.reagents }, list.guid)
    recipe.profit = result.profit and result.profit * entry.qty
    -- owners are the recipes that list the reagent as a line: this one, plus the intermediate ones it is
    -- crafted through
    local function AddLine(owner, item, need)
      local line = owner.byItem[item]
      if line then
        line.need = line.need + need
      else
        line = { item = item, need = need }
        owner.byItem[item] = line
        owner.recipe.reagents[#owner.recipe.reagents + 1] = line
      end
    end
    -- Adds need of the reagent. One that is cheaper crafted by a known recipe than bought is not an item to
    -- get: the recipe goes to the intermediate ones and its reagents are added instead, for as many crafts as
    -- the owned amount does not cover, recursively. visited guards against cycles.
    local function AddReagent(reagent, need, visited, depth, owners)
      local itemId = reagent.itemId
      if depth < MAX_CRAFT_DEPTH and not visited[itemId] then
        -- only a recipe the owner of the list knows: another character crafts it, not this one
        local sub
        for _, known in ipairs(AM.ProfessionScanner.GetRecipes(itemId)) do
          if AM.RecipeCost.IsCraftedBy(known, list.guid) then
            sub = known
            break
          end
        end
        local buy = sub and AM.RecipeCost.GetBuyPrice(itemId, list.guid)
        if buy and buy.source == "crafted" then
          local owned = ownedLeft[itemId] or CountOwned(reagent.itemIds or { itemId }, list.guid)
          local used = math.min(owned, need)
          ownedLeft[itemId] = owned - used
          local crafts = math.ceil((need - used) / math.max(sub.outputCount or 1, 1))
          if crafts > 0 then
            local intermediate = intermediatesById[itemId]
            if not intermediate then
              intermediate = { recipe = { id = sub.id, qty = 0, outputItemId = itemId, intermediate = true,
                reagents = {} }, byItem = {} }
              intermediatesById[itemId] = intermediate
              model.intermediates[#model.intermediates + 1] = intermediate.recipe
            end
            intermediate.recipe.qty = intermediate.recipe.qty + crafts
            intermediate.recipe.missing = (intermediate.recipe.missing or 0) + need - used
            local nested = { intermediate }
            for _, owner in ipairs(owners) do
              nested[#nested + 1] = owner
            end
            visited[itemId] = true
            for _, subReagent in ipairs(sub.reagents) do
              AddReagent(subReagent, subReagent.quantity * crafts, visited, depth + 1, nested)
            end
            visited[itemId] = nil
            return
          end
        end
      end
      local item = itemsById[itemId]
      if not item then
        local itemIds = reagent.itemIds or { itemId }
        item = { itemId = itemId, itemIds = itemIds, crafters = { list.guid }, need = 0,
          owned = CountOwned(itemIds, list.guid) }
        itemsById[itemId] = item
        model.items[#model.items + 1] = item
      end
      item.need = item.need + need
      for _, owner in ipairs(owners) do
        AddLine(owner, item, need)
      end
    end
    local top = { recipe = recipe, byItem = {} }
    for _, reagent in ipairs(entry.reagents) do
      AddReagent(reagent, reagent.quantity * entry.qty, { [entry.outputItemId or 0] = true }, 0, { top })
    end
    model.recipes[#model.recipes + 1] = recipe
  end

  local pool = {}
  for _, item in ipairs(model.items) do
    -- what the current character and the crafter own may not cover it: other characters' stock helps out
    local extra
    item.owned, extra = AddOtherStock(item.itemIds, item.owned, item.need,
      { [UnitGUID("player")] = true, [list.guid] = true })
    for _, guid in ipairs(extra) do
      item.crafters[#item.crafters + 1] = guid
    end
    pool[item.itemId] = item.owned
    item.have = math.min(item.owned, item.need)
    model.totalNeed = model.totalNeed + item.need
    model.totalHave = model.totalHave + item.have
    table.insert(item.have >= item.need and model.done or model.needed, item)
  end
  for _, recipe in ipairs(model.recipes) do
    recipe.ready = #recipe.reagents > 0
    for _, reagent in ipairs(recipe.reagents) do
      recipe.ready = recipe.ready and pool[reagent.item.itemId] >= reagent.need
    end
    if recipe.ready then
      for _, reagent in ipairs(recipe.reagents) do
        pool[reagent.item.itemId] = pool[reagent.item.itemId] - reagent.need
      end
    end
  end
  -- an intermediate recipe is ready when what it needs is owned, without claiming it from the others
  for _, recipe in ipairs(model.intermediates) do
    recipe.name = C_Item.GetItemInfo(recipe.outputItemId) or "..."
    recipe.icon = select(5, C_Item.GetItemInfoInstant(recipe.outputItemId))
    recipe.ready = #recipe.reagents > 0
    for _, reagent in ipairs(recipe.reagents) do
      recipe.ready = recipe.ready and reagent.item.owned >= reagent.need
    end
  end
  AddPrices(model, list.guid)
  return model
end

-- The model of several lists as one: the recipes one after the other, the intermediate products and the reagents
-- summed up. What is owned is counted once, so it covers the need of all lists together.
function ShoppingList.BuildCombinedModel(lists)
  if #lists == 1 then
    return ShoppingList.BuildModel(lists[1])
  end
  local model = { recipes = {}, intermediates = {}, items = {}, needed = {}, done = {}, totalNeed = 0, totalHave = 0,
    toBuy = 0 }
  local itemsById, intermediatesById = {}, {}
  for _, list in ipairs(lists) do
    local single = ShoppingList.BuildModel(list)
    for _, recipe in ipairs(single.recipes) do
      model.recipes[#model.recipes + 1] = recipe
      if recipe.profit then
        model.profit = (model.profit or 0) + recipe.profit
      end
    end
    for _, recipe in ipairs(single.intermediates) do
      local merged = intermediatesById[recipe.outputItemId]
      if merged then
        merged.qty = merged.qty + recipe.qty
        merged.missing = (merged.missing or 0) + (recipe.missing or 0)
        merged.ready = merged.ready and recipe.ready
      else
        merged = { id = recipe.id, qty = recipe.qty, name = recipe.name, icon = recipe.icon,
          outputItemId = recipe.outputItemId, intermediate = true, ready = recipe.ready,
          missing = recipe.missing, reagents = {} }
        intermediatesById[recipe.outputItemId] = merged
        model.intermediates[#model.intermediates + 1] = merged
      end
    end
    for _, item in ipairs(single.items) do
      local merged = itemsById[item.itemId]
      if not merged then
        -- the bags of the current character are counted once for all lists
        merged = { itemId = item.itemId, itemIds = item.itemIds, crafters = {}, need = 0,
          owned = CountLive(item.itemIds), craftHint = item.craftHint }
        itemsById[item.itemId] = merged
        model.items[#model.items + 1] = merged
      end
      merged.crafters[#merged.crafters + 1] = list.guid
      merged.need = merged.need + item.need
      -- what a crafter carries only covers the need of its own list
      merged.owned = merged.owned + math.min(CountStored(item.itemIds, list.guid), item.need)
      if item.price and not merged.unitPrice then
        merged.unitPrice = item.price / math.max(item.need - item.have, 1)
        merged.source = item.source
      end
    end
  end
  for _, item in ipairs(model.items) do
    local counted = { [UnitGUID("player")] = true }
    for _, guid in ipairs(item.crafters) do
      counted[guid] = true
    end
    local extra
    item.owned, extra = AddOtherStock(item.itemIds, item.owned, item.need, counted)
    for _, guid in ipairs(extra) do
      item.crafters[#item.crafters + 1] = guid
    end
    item.have = math.min(item.owned, item.need)
    model.totalNeed = model.totalNeed + item.need
    model.totalHave = model.totalHave + item.have
    if item.unitPrice and item.need > item.have then
      item.price = item.unitPrice * (item.need - item.have)
      model.toBuy = model.toBuy + item.price
    end
    table.insert(item.have >= item.need and model.done or model.needed, item)
  end
  return model
end

-- Opens the profession window of the recipe, or the one used last if there is none. Only retail
-- selects the recipe itself.
function ShoppingList.OpenProfession(recipe)
  local data = GetData()
  if IsRetail() then
    if recipe then
      C_TradeSkillUI.OpenRecipe(recipe.id)
    else
      local skillLine = data.skillLine
      if not skillLine and GetProfessions then
        -- nothing added yet: the first profession of the character
        local first = GetProfessions()
        skillLine = first and select(7, GetProfessionInfo(first))
      end
      if not (ProfessionsFrame and ProfessionsFrame:IsShown()) and skillLine then
        C_TradeSkillUI.OpenTradeSkill(skillLine)
      end
    end
    return
  end
  local profession = recipe and recipe.profession or data.profession
  if not profession and GetProfessions then
    profession = GetProfessionInfo(GetProfessions())
  end
  if profession then
    CastSpellByName(profession)
  end
end

-- Click on a recipe: opens its profession page if the auction house is closed and the
-- current character can craft the item, else searches the item in the auction house.
function ShoppingList.ClickRecipeIcon(recipe, itemId)
  itemId = itemId or recipe.outputItemId
  if not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) and itemId
    and ShoppingList.GetOwnRecipe(itemId) then
    ShoppingList.OpenProfession(recipe)
    return
  end
  ShoppingList.SearchItemName(itemId, recipe.name)
end

-- The recipe making the item that the current character knows, nil if there is none.
function ShoppingList.GetOwnRecipe(itemId)
  local player = UnitGUID("player")
  for _, known in ipairs(AM.ProfessionScanner.GetRecipes(itemId)) do
    for _, guid in ipairs(known.crafters) do
      if guid == player then
        return known
      end
    end
  end
end

-- Click on an ingredient: opens the profession page of its recipe if the auction house is closed and
-- the current character can craft it, else searches it in the auction house.
function ShoppingList.ClickItem(itemId, quantity)
  local known = not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) and ShoppingList.GetOwnRecipe(itemId)
  if known then
    ShoppingList.OpenProfession(known)
  else
    ShoppingList.SearchItem(itemId, quantity)
  end
end

function ShoppingList.ChangeQuantity(recipe, delta)
  local entry = GetList(recipe.guid).recipes[recipe.index]
  entry.qty = math.max(1, entry.qty + delta)
  ShoppingList.Refresh()
end

function ShoppingList.RemoveRecipe(recipe)
  table.remove(GetList(recipe.guid).recipes, recipe.index)
  ShoppingList.Refresh()
end

-- Whether the recipe is on the list of the current character.
function ShoppingList.HasRecipe(recipeId)
  for _, entry in ipairs(GetList(UnitGUID("player")).recipes) do
    if entry.id == recipeId then
      return true
    end
  end
  return false
end

-- Takes the recipe off the list of the current character, whatever its quantity.
function ShoppingList.RemoveRecipeById(recipeId)
  local recipes = GetList(UnitGUID("player")).recipes
  for index = #recipes, 1, -1 do
    if recipes[index].id == recipeId then
      table.remove(recipes, index)
    end
  end
  ShoppingList.Refresh()
end

-- A craft of the current character: takes one off the quantity of the recipe on its list, the recipe goes when it
-- reaches 0. Nothing happens for a spell that is not on the list.
function ShoppingList.RecordCraft(recipeId)
  local recipes = GetList(UnitGUID("player")).recipes
  for index, entry in ipairs(recipes) do
    if entry.id == recipeId then
      entry.qty = entry.qty - 1
      if entry.qty <= 0 then
        table.remove(recipes, index)
      end
      ShoppingList.Refresh()
      return
    end
  end
end

local craftWatcher = CreateFrame("Frame")
craftWatcher:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
craftWatcher:SetScript("OnEvent", function(_, _, _, _, spellId)
  ShoppingList.RecordCraft(spellId)
end)

-- Empties the lists of their recipes.
function ShoppingList.ClearLists(lists)
  for _, list in ipairs(lists) do
    list.recipes = {}
  end
  ShoppingList.Refresh()
end

-- Forgets a deleted character: its list, its name and its recipes. Never the current character.
function ShoppingList.RemoveCrafter(guid)
  if guid == UnitGUID("player") then
    return
  end
  local data = GetData()
  if data.crafters then
    data.crafters[guid] = nil
  end
  if data.activeGuid == guid then
    data.activeGuid = nil
  end
  AM.Database.GetGlobalObject("characters")[guid] = nil
  AM.ProfessionScanner.ForgetCharacter(guid)
  AM.Inventory.ForgetCharacter(guid)
  AM.Mailbox.ForgetCharacter(guid)
  AM.Events.Fire("CRAFTERS_CHANGED")
end

local pendingItemId
-- The ingredient searched last, which the lists highlight.
local searchedItemId

function ShoppingList.GetSearchedItem()
  return searchedItemId
end
-- { itemId, quantity } to enter in the buy view of a commodity once it is selected
local pendingQuantity

-- Enters the wanted quantity through Blizzard's own event, so the input and the price follow.
local function ApplyPendingQuantity()
  local pending = pendingQuantity
  local buyFrame = AuctionHouseFrame and AuctionHouseFrame.CommoditiesBuyFrame
  if not (pending and buyFrame and buyFrame:IsShown() and buyFrame:GetItemID() == pending.itemId) then
    return
  end
  AuctionHouseFrame:TriggerEvent(AuctionHouseFrameMixin.Event.CommoditiesQuantitySelectionChanged, pending.quantity)
end

-- The quantity is reset to 1 when the item is selected and again when its auctions arrive.
local quantityApplier = CreateFrame("Frame")
quantityApplier:RegisterEvent("COMMODITY_SEARCH_RESULTS_RECEIVED")
quantityApplier:SetScript("OnEvent", function()
  -- after the handlers of the game's frames, which mark the results as loaded
  C_Timer.After(0, function()
    ApplyPendingQuantity()
    pendingQuantity = nil
  end)
end)

local itemInfoWaiter = CreateFrame("Frame")
itemInfoWaiter:SetScript("OnEvent", function(self)
  self:UnregisterEvent("ITEM_KEY_ITEM_INFO_RECEIVED")
  local itemId = pendingItemId
  pendingItemId = nil
  if itemId then
    AM.ShoppingList.SearchItem(itemId, pendingQuantity and pendingQuantity.quantity)
  end
end)

-- Opens the buy tab of an open auction house with the item selected.
function AM.ShoppingList.SearchItem(itemId, quantity)
  if not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then
    return
  end
  pendingQuantity = quantity and { itemId = itemId, quantity = quantity } or nil
  searchedItemId = itemId
  -- Blizzard's SelectBrowseResult needs the item key info, which is requested from the server
  -- by the first call and arrives with ITEM_KEY_ITEM_INFO_RECEIVED. Retry once it is there.
  if not C_AuctionHouse.GetItemKeyInfo(C_AuctionHouse.MakeItemKey(itemId)) then
    pendingItemId = itemId
    itemInfoWaiter:RegisterEvent("ITEM_KEY_ITEM_INFO_RECEIVED")
    return
  end
  local buyTab = AuctionHouseFrame.BuyTab or AuctionHouseFrameBuyTab
  if buyTab then
    buyTab:Click()
  end
  -- Clicking the tab does nothing while it is shown already, e.g. with the item of the last click
  -- open. Selecting the next item on top of that stalls, so go back to the browse view first.
  if AuctionHouseFrameDisplayMode and AuctionHouseFrame.SetDisplayMode then
    AuctionHouseFrame:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy)
  end
  -- minPrice is what Blizzard shows until the results are loaded, it must not be nil.
  AuctionHouseFrame:SelectBrowseResult({ itemKey = C_AuctionHouse.MakeItemKey(itemId), minPrice = 0 })
  ApplyPendingQuantity()
  -- the search box still shows the last search, not the item that is selected now
  local searchBox = AuctionHouseFrame.SearchBar and AuctionHouseFrame.SearchBar.SearchBox
  local name = C_Item.GetItemInfo(itemId)
  if searchBox and name then
    searchBox:SetText(name)
  end
  ShoppingList.Refresh()
end

-- Searches the buy tab of an open auction house by the name of the item. Unlike SearchItem this also
-- finds gear, whose browse results are keyed by item level and so cannot be selected by item id.
function AM.ShoppingList.SearchItemName(itemId, fallbackName)
  if not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then
    return
  end
  local name = itemId and C_Item.GetItemInfo(itemId) or fallbackName
  local searchBar = AuctionHouseFrame.SearchBar
  if not name then
    return
  end
  local buyTab = AuctionHouseFrame.BuyTab or AuctionHouseFrameBuyTab
  if buyTab then
    buyTab:Click()
  end
  if AuctionHouseFrameDisplayMode and AuctionHouseFrame.SetDisplayMode then
    AuctionHouseFrame:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy)
  end
  if searchBar and searchBar.SearchBox then
    searchBar.SearchBox:SetText(name)
    searchBar:StartSearch()
  elseif itemId then
    AM.ShoppingList.SearchItem(itemId)
  end
end

-- Redraws the views of the lists that are shown: the tab of the main window, the panel of the Buy tab, the recipes
-- of the profession window and the objective tracker.
function ShoppingList.Refresh()
  AM.MainWindow.Refresh()
  AM.ShoppingPanel.Update()
  AM.CraftPanel.Update()
  AM.CraftList.Update()
  AM.ShoppingTracker.Update()
  AM.ProfessionsFrame.UpdateRemove()
end

-- the mailbox changed or something was bought or sent (the bags have their own event)
AM.Events.Register("MAIL_CHANGED", ShoppingList.Refresh)

-- Adds count times the recipe to the list of the crafter (the current character if omitted), to the quantity if
-- it is on the list already. The list is shown from then on.
function ShoppingList.AddRecipe(recipe, count, guid)
  local data = GetData()
  data.skillLine = recipe.skillLine or data.skillLine
  data.profession = recipe.profession or data.profession
  guid = guid or UnitGUID("player")
  -- the list that is added to has to be shown
  if data.activeGuid and data.activeGuid ~= guid then
    data.activeGuid = nil
  end
  local list = GetList(guid)
  local found
  for _, entry in ipairs(list.recipes) do
    if entry.id == recipe.id then
      entry.qty = entry.qty + count
      found = true
    end
  end
  if not found then
    list.recipes[#list.recipes + 1] = {
      id = recipe.id, qty = count, name = recipe.name, icon = recipe.icon, reagents = recipe.reagents,
      outputItemId = recipe.outputItemId, outputCount = recipe.outputCount, skillLine = recipe.skillLine,
      profession = recipe.profession,
    }
  end
  ShoppingList.Refresh()
end

ShoppingList.mode = IsRetail() and "retail" or (GetNumTradeSkills and "classic") or "unsupported"
