local addonName, AM = ...

-- The recipes of all characters of the faction for the Recipes tab (see RecipesTab.lua): one entry per
-- recipe and character knowing it, with cost, value and profit at the prices of the latest scan. No UI.
AM.RecipeList = {}
local RecipeList = AM.RecipeList

-- A recipe earns less than this share of its reagent cost: not worth the trouble.
local MIN_MARGIN = 0.1

-- Bumped whenever the prices or recipes behind the entries changed, so views know to build them again.
RecipeList.version = 0

function RecipeList.Invalidate()
  RecipeList.version = RecipeList.version + 1
end

AM.Events.Register("PRICES_CHANGED", RecipeList.Invalidate)
AM.Events.Register("CRAFTERS_CHANGED", RecipeList.Invalidate)

-- What to do with a recipe at the current prices: "craft", "low" (margin below MIN_MARGIN), "loss" or
-- "none" (a price is missing).
local function GetAdvice(result)
  if not result.profit then
    return "none"
  elseif result.profit <= 0 then
    return "loss"
  elseif result.cost > 0 and result.profit / result.cost < MIN_MARGIN then
    return "low"
  end
  return "craft"
end

-- The reagents in the shape the shopping list stores them.
local function CopyReagents(reagents)
  local copy = {}
  for i, reagent in ipairs(reagents) do
    copy[i] = { itemId = reagent.itemId, itemIds = reagent.itemIds or { reagent.itemId }, quantity = reagent.quantity }
  end
  return copy
end

function RecipeList.GetCharacterName(character)
  if character.realm and character.realm ~= GetNormalizedRealmName() then
    return character.name .. "-" .. character.realm
  end
  return character.name
end

-- Returns the entries and the characters that know recipes. An entry is
--   key        unique, recipe and character
--   recipeId, itemId (crafted), guid, crafter (name), recipe (the stored recipe)
--   name, icon, quality of the crafted item (name and quality are nil until the item is cached)
--   result     RecipeCost.Calculate of the recipe, cost/lowest/market/profit/margin are taken from it (nil if unknown)
--   inAH       number of auctions of the item in the latest scan
--   advice     see GetAdvice
--   rare       true if the item is listed less than the "rareCount" setting times per scan on average, or never (after a scan)
--   skillLine  id of the profession (nil if not read yet)
-- a character is { guid, name, class (file name, may be nil), count (entries) }, sorted by the number of entries (most first), then by name,
-- and a profession is { skillLine, name, icon (nil if unknown), count (entries) }, sorted by name.
function RecipeList.Build()
  local characters = AM.Database.GetGlobalObject("characters")
  local entries, byGuid = {}, {}
  local hasScan = AM.ItemStore.HasScan()
  -- An item listed on average less often than this per scan (ItemStore's avgCount) is rarely listed.
  local rareCount = AM.ItemStore.GetNumber("rareCount")
  for itemId, recipes in pairs(AM.Database.GetFactionObject("recipes")) do
    local name, _, quality = C_Item.GetItemInfo(itemId)
    if not name and C_Item.RequestLoadItemDataByID then
      C_Item.RequestLoadItemDataByID(itemId)
    end
    local icon = select(5, C_Item.GetItemInfoInstant(itemId))
    local itemDbKey = AM.ItemDbKey.ForCrafted(itemId)
    local _, listedCount
    if itemDbKey then
      _, listedCount = AM.ItemStore.Get(itemDbKey)
    end
    -- An item that no scan has ever listed has no market entry at all: rare, once there is a scan to say so.
    -- A nil average of an existing entry (stored before it was kept) is unknown, not rare.
    local market = itemDbKey and AM.ItemStore.GetMarketPrice(itemDbKey)
    local rare
    if market then
      rare = market.avgCount ~= nil and market.avgCount < rareCount
    else
      rare = hasScan
    end
    for _, recipe in ipairs(recipes) do
      local result
      for _, guid in ipairs(AM.ProfessionScanner.GetActiveCrafters(recipe)) do
        local character = characters[guid]
        -- an earlier version stored the bare name, it is replaced when that character scans again
        if type(character) == "table" then
          result = result or AM.RecipeCost.Calculate({ id = recipe.id, outputItemId = itemId,
            outputCount = recipe.outputCount, reagents = recipe.reagents })
          local entry = byGuid[guid]
          if not entry then
            entry = { guid = guid, name = RecipeList.GetCharacterName(character), class = character.class, count = 0 }
            byGuid[guid] = entry
          end
          entry.count = entry.count + 1
          entries[#entries + 1] = {
            key = recipe.id .. "|" .. guid, recipeId = recipe.id, itemId = itemId, guid = guid,
            crafter = entry.name, skillLine = recipe.skillLine, recipe = recipe, name = name, icon = icon, quality = quality,
            result = result, cost = not result.incomplete and result.cost or nil,
            lowest = result.lowest, market = result.market, profit = result.profit,
            margin = result.profit and result.cost > 0 and result.profit / result.cost or nil,
            inAH = listedCount or 0, advice = GetAdvice(result),
            rare = rare,
          }
        end
      end
    end
  end
  local list = {}
  for _, character in pairs(byGuid) do
    list[#list + 1] = character
  end
  table.sort(list, function(a, b)
    if a.count ~= b.count then
      return a.count > b.count
    end
    return a.name < b.name
  end)
  -- the professions of the entries, sorted by name (recipes read before the profession was stored have none)
  local names = AM.Database.GetGlobalObject("professions")
  local icons = AM.Database.GetGlobalObject("professionIcons")
  local professions, bySkillLine = {}, {}
  for _, entry in ipairs(entries) do
    local skillLine = entry.skillLine
    if skillLine and names[skillLine] then
      local profession = bySkillLine[skillLine]
      if not profession then
        local icon = icons[skillLine] or (C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillTexture
          and C_TradeSkillUI.GetTradeSkillTexture(skillLine))
        profession = { skillLine = skillLine, name = AM.ProfessionScanner.GetProfessionName(skillLine), icon = icon,
          count = 0 }
        bySkillLine[skillLine] = profession
        professions[#professions + 1] = profession
      end
      profession.count = profession.count + 1
    end
  end
  table.sort(professions, function(a, b)
    return a.name < b.name
  end)
  return entries, list, professions
end

-- The recipe of an entry as the shopping list takes it.
function RecipeList.ToShoppingRecipe(entry)
  return { id = entry.recipeId, name = entry.name or ("item:" .. entry.itemId), icon = entry.icon,
    outputItemId = entry.itemId, outputCount = entry.recipe.outputCount, reagents = CopyReagents(entry.recipe.reagents) }
end
