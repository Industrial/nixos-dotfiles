local addonName, AM = ...

-- Learns the recipes of every profession window that is opened, so that a reagent which can be
-- crafted can be priced by its recipe. The recipes are kept in the faction object "recipes" (keyed
-- by the id of the crafted item, a list as several recipes may make the same item). A recipe is
-- { id, outputCount, reagents, crafters }, crafters being the GUIDs of the characters of this faction
-- that know it. Recipes nobody knows are not kept. The profession APIs only answer while the window is open,
-- and there is nothing to learn from chat messages or events about learning a recipe: the recipe
-- shows up in the window the next time it is opened.
local ProfessionScanner = {}
AM.ProfessionScanner = ProfessionScanner

local SCAN_DELAY = 0.5
local scanPending = false

-- Characters are kept by their GUID, which survives a rename. The global object "characters" maps
-- the GUID to { name, realm, class } (class being the class file, e.g. "MAGE") for showing it.
local function GetCharacter()
  local guid = UnitGUID("player")
  local name, realm = UnitFullName("player")
  if not realm or realm == "" then
    realm = GetNormalizedRealmName()
  end
  AM.Database.GetGlobalObject("characters")[guid] = { name = name, realm = realm, class = select(2, UnitClass("player")) }
  return guid
end

-- A character or single professions of it can be ignored (the global object "ignored": GUID -> { all = true,
-- [skillLine] = true }). Its recipes stay recorded but do not count: the character is no crafter of them, as if
-- it did not know them. Ignoring the whole character also covers recipes that have no profession stored.
local function GetIgnored()
  return AM.Database.GetGlobalObject("ignored")
end

function ProfessionScanner.IsCharacterIgnored(guid)
  local ignored = GetIgnored()[guid]
  return ignored ~= nil and ignored.all == true
end

-- Whether the profession itself is ignored, whatever is set for the character.
function ProfessionScanner.IsProfessionIgnored(guid, skillLine)
  local ignored = GetIgnored()[guid]
  return ignored ~= nil and ignored[skillLine] == true
end

local function SetIgnoredKey(guid, key, ignore)
  local ignored = GetIgnored()
  if ignore then
    ignored[guid] = ignored[guid] or {}
    ignored[guid][key] = true
  elseif ignored[guid] then
    ignored[guid][key] = nil
    if next(ignored[guid]) == nil then
      ignored[guid] = nil
    end
  end
  AM.Events.Fire("CRAFTERS_CHANGED")
end

function ProfessionScanner.SetCharacterIgnored(guid, ignore)
  SetIgnoredKey(guid, "all", ignore)
end

function ProfessionScanner.SetProfessionIgnored(guid, skillLine, ignore)
  SetIgnoredKey(guid, skillLine, ignore)
end

-- The GUIDs of the characters that know the stored recipe and have not ignored it. The list of the recipe itself
-- when nothing is ignored.
function ProfessionScanner.GetActiveCrafters(entry)
  if next(GetIgnored()) == nil then
    return entry.crafters
  end
  local skillLine = entry.skillLine
  local active = {}
  for _, guid in ipairs(entry.crafters) do
    if not ProfessionScanner.IsCharacterIgnored(guid)
      and not (skillLine and ProfessionScanner.IsProfessionIgnored(guid, skillLine)) then
      active[#active + 1] = guid
    end
  end
  return #active == #entry.crafters and entry.crafters or active
end

-- The name of a profession in the language of the client. Only the id is a fact; the stored name was written in
-- whatever language the client had when the recipes were read, so it is the fallback for a client without the lookup.
function ProfessionScanner.GetProfessionName(skillLine)
  local name = C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName
    and C_TradeSkillUI.GetTradeSkillDisplayName(skillLine)
  if name and name ~= "" then
    return name
  end
  return AM.Database.GetGlobalObject("professions")[skillLine]
end

-- The characters with recorded recipes and their professions, for managing them: { guid, name, class, ignored,
-- professions = { { skillLine, name, icon, ignored } sorted by name } }, sorted by name. Professions are the ones
-- the recipes are recorded under (those that have a stored name), ignored ones included.
function ProfessionScanner.GetKnownProfessions()
  local characters = AM.Database.GetGlobalObject("characters")
  local names = AM.Database.GetGlobalObject("professions")
  local icons = AM.Database.GetGlobalObject("professionIcons")
  local byGuid, list = {}, {}
  for _, recipes in pairs(AM.Database.GetFactionObject("recipes")) do
    for _, entry in ipairs(recipes) do
      local skillLine = entry.skillLine
      for _, guid in ipairs(entry.crafters) do
        local character = characters[guid]
        if type(character) == "table" then
          local known = byGuid[guid]
          if not known then
            known = { guid = guid, name = AM.RecipeList.GetCharacterName(character), class = character.class,
              ignored = ProfessionScanner.IsCharacterIgnored(guid), professions = {}, seen = {} }
            byGuid[guid] = known
            list[#list + 1] = known
          end
          if skillLine and names[skillLine] and not known.seen[skillLine] then
            known.seen[skillLine] = true
            known.professions[#known.professions + 1] = { skillLine = skillLine,
              name = ProfessionScanner.GetProfessionName(skillLine),
              icon = icons[skillLine], ignored = ProfessionScanner.IsProfessionIgnored(guid, skillLine) }
          end
        end
      end
    end
  end
  for _, known in ipairs(list) do
    known.seen = nil
    table.sort(known.professions, function(a, b)
      return a.name < b.name
    end)
  end
  table.sort(list, function(a, b)
    return a.name < b.name
  end)
  return list
end

-- Windows that show the recipes of someone else (linked, guild member, NPC) say nothing about
-- this character.
local function IsOwnWindow()
  local C = C_TradeSkillUI
  if C then
    return not ((C.IsTradeSkillLinked and C.IsTradeSkillLinked())
      or (C.IsTradeSkillGuild and C.IsTradeSkillGuild())
      or (C.IsNPCCrafting and C.IsNPCCrafting()))
  end
  return not (IsTradeSkillLinked and IsTradeSkillLinked())
end

local function FindEntry(list, id)
  for _, entry in ipairs(list) do
    if entry.id == id then
      return entry
    end
  end
  return nil
end

-- Reagent qualities are only kept where there are several, the single item is the reagent itself.
local function CopyReagents(reagents)
  local copy = {}
  for i, reagent in ipairs(reagents) do
    copy[i] = { itemId = reagent.itemId, quantity = reagent.quantity,
      itemIds = #reagent.itemIds > 1 and reagent.itemIds or nil }
  end
  return copy
end

-- Records that the character knows the recipe, or no longer does when known is false.
local function Record(recipes, recipe, character, known)
  local itemId = recipe.outputItemId
  local list = recipes[itemId]
  local entry = list and FindEntry(list, recipe.id)
  if not known then
    if entry then
      for i = #entry.crafters, 1, -1 do
        if entry.crafters[i] == character then
          table.remove(entry.crafters, i)
        end
      end
    end
    return
  end
  if not entry then
    list = list or {}
    recipes[itemId] = list
    entry = { id = recipe.id, crafters = {} }
    list[#list + 1] = entry
  end
  -- always the latest reading, the number of items made or the reagents may have changed
  entry.outputCount = recipe.outputCount
  if recipe.skillLine and recipe.professionName then
    entry.skillLine = recipe.skillLine
    AM.Database.GetGlobalObject("professions")[recipe.skillLine] = recipe.professionName
    if recipe.professionIcon then
      AM.Database.GetGlobalObject("professionIcons")[recipe.skillLine] = recipe.professionIcon
    end
  end
  entry.reagents = CopyReagents(recipe.reagents)
  for _, name in ipairs(entry.crafters) do
    if name == character then
      return
    end
  end
  entry.crafters[#entry.crafters + 1] = character
end

-- Retail lists all recipes of the profession, known or not, so forgotten ones can be removed too.
local function ScanRetail(recipes, character)
  for _, recipeId in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
    local info = C_TradeSkillUI.GetRecipeInfo(recipeId)
    if info and not info.isRecraft and not info.isSalvageRecipe then
      local recipe = AM.ShoppingList.ReadRetailRecipe(recipeId)
      if recipe and recipe.outputItemId then
        -- the ranks of a recipe are separate recipes that all count as learned, only the highest counts
        local next = info.nextRecipeID and C_TradeSkillUI.GetRecipeInfo(info.nextRecipeID)
        Record(recipes, recipe, character, info.learned and not (next and next.learned))
      end
    end
  end
end

-- Classic lists the known recipes only, and only those the window shows at the moment: the filters
-- and collapsed headers are the player's, they are not changed to see more.
local function ScanClassic(recipes, character)
  for index = 1, GetNumTradeSkills() do
    local recipe = AM.ShoppingList.ReadClassicRecipe(index)
    if recipe and recipe.outputItemId then
      Record(recipes, recipe, character, true)
    end
  end
end

-- Removes the character from the recipes of professions it no longer has. Nothing else notices a dropped
-- profession, as its window cannot be opened any more. Only the current character can be checked, and nothing is
-- removed when the client reports no profession at all (not loaded yet).
function ProfessionScanner.PruneProfessions()
  if not GetProfessions then
    return
  end
  local skillLines, any = {}, false
  for _, slot in pairs({ GetProfessions() }) do
    local skillLine = select(7, GetProfessionInfo(slot))
    if skillLine then
      skillLines[skillLine] = true
      any = true
    end
  end
  if not any then
    return
  end
  local character = UnitGUID("player")
  for _, list in pairs(AM.Database.GetFactionObject("recipes")) do
    for _, entry in ipairs(list) do
      if entry.skillLine and not skillLines[entry.skillLine] then
        for i = #entry.crafters, 1, -1 do
          if entry.crafters[i] == character then
            table.remove(entry.crafters, i)
          end
        end
      end
    end
  end
end

-- Forgets a character (deleted): it is removed from all recipes, and recipes nobody knows any more are dropped.
function ProfessionScanner.ForgetCharacter(guid)
  local recipes = AM.Database.GetFactionObject("recipes")
  for itemId, list in pairs(recipes) do
    for i = #list, 1, -1 do
      local crafters = list[i].crafters
      for j = #crafters, 1, -1 do
        if crafters[j] == guid then
          table.remove(crafters, j)
        end
      end
      if #crafters == 0 then
        table.remove(list, i)
      end
    end
    if #list == 0 then
      recipes[itemId] = nil
    end
  end
  GetIgnored()[guid] = nil
  AM.Disenchant.ForgetCharacter(guid)
end

local function Scan()
  scanPending = false
  if not IsOwnWindow() then
    return
  end
  local recipes = AM.Database.GetFactionObject("recipes")
  local character = GetCharacter()
  if AM.ShoppingList.IsRetail() then
    ScanRetail(recipes, character)
  elseif GetNumTradeSkills then
    ScanClassic(recipes, character)
  end
  ProfessionScanner.PruneProfessions()
  AM.Events.Fire("CRAFTERS_CHANGED")
end

-- Windows send their events in bursts, so scan once for all of them.
local function ScanSoon()
  if scanPending then
    return
  end
  scanPending = true
  C_Timer.After(SCAN_DELAY, Scan)
end

-- Returns the recipes that make the item and are known by at least one character of this faction:
-- { id, outputCount, reagents = { itemId, itemIds (nil for a single item), quantity }, crafters }.
-- Empty if there is none.
function ProfessionScanner.GetRecipes(itemId)
  local known = {}
  for _, entry in ipairs(AM.Database.GetFactionObject("recipes")[itemId] or {}) do
    local crafters = ProfessionScanner.GetActiveCrafters(entry)
    if #crafters > 0 then
      -- without the crafters who ignore it, a copy so that the stored one stays whole
      known[#known + 1] = crafters == entry.crafters and entry or { id = entry.id, outputCount = entry.outputCount,
        reagents = entry.reagents, skillLine = entry.skillLine, crafters = crafters }
    end
  end
  return known
end

if AM.ShoppingList.IsSupported() then
  local frame = CreateFrame("Frame")
  -- not every client has every event, and registering an unknown one is an error
  for _, event in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED",
    "TRADE_SKILL_UPDATE" }) do
    pcall(frame.RegisterEvent, frame, event)
  end
  frame:SetScript("OnEvent", ScanSoon)

  -- a profession dropped since the last time this character played (the skills are known a moment after login)
  local login = CreateFrame("Frame")
  login:RegisterEvent("PLAYER_ENTERING_WORLD")
  login:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    C_Timer.After(5, function()
      ProfessionScanner.PruneProfessions()
      AM.Events.Fire("CRAFTERS_CHANGED")
    end)
  end)
end
