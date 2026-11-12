local addonName, AM = ...
local L = AM.L

-- Retail and Forever: the recipes of the shopping list of the current character that belong to the open profession are
-- pinned on top of the recipe list of the profession window, in a category of their own that folds like the game's
-- ones, with the amount to craft behind the name (the intermediate products first). A click selects the recipe as in any
-- other category. It is built the way the game builds its "Favorites" category: a node of the data provider of the list,
-- holding copies of the recipes (favoritesInstance), so the game keeps selecting and scrolling as it does for those.
-- Below it sits a second category with the cheap ways to level the profession (Leveling.lua), with the cost of the
-- reagents at the right and an icon after it for what to do with the result.
-- Classic has another list and gets a pinned group (CraftPanel.lua).
AM.CraftList = {}
local CraftList = AM.CraftList
local ShoppingList = AM.ShoppingList

-- The game remembers which categories are folded by id; -1 is its Favorites. The game's groups start at its Favorites (0),
-- ours are above, the shopping list first.
local SHOPPING = { id = -2, group = -2 }
local LEVELING = { id = -3, group = -1 }
local TIP_SIZE = 14
local NAME_OFFSET = 40 -- where the name starts in a row, if the game has not laid it out yet
local LOGO = "|TInterface\\AddOns\\AuctionMaster\\assets\\logo:14:14:0:0|t "

local installed = false

local function GetPage()
  return ProfessionsFrame and ProfessionsFrame.CraftingPage
end

-- The recipes to craft as the recipe ids in the order shown and the number to craft of each. A recipe that is
-- crafted on the way as well as listed is one entry.
local function ReadPlan()
  local model = ShoppingList.BuildModel(ShoppingList.GetList(UnitGUID("player")))
  local order, amounts = {}, {}
  for _, recipes in ipairs({ model.intermediates, model.recipes }) do
    for _, recipe in ipairs(recipes) do
      if not amounts[recipe.id] then
        order[#order + 1] = recipe.id
        amounts[recipe.id] = 0
      end
      amounts[recipe.id] = amounts[recipe.id] + recipe.qty
    end
  end
  return order, amounts
end

-- The recipes of the list as the game has them, by every recipe id of their levels (a recipe of the list may be a higher
-- level than the one the game lists).
local function FindRecipes(dataProvider)
  local byId = {}
  for _, node in dataProvider:EnumerateEntireRange() do
    local info = node:GetData().recipeInfo
    if info and info.learned and not info.favoritesInstance then
      for _ = 1, 10 do
        byId[info.recipeID] = byId[info.recipeID] or node:GetData().recipeInfo
        info = info.nextRecipeID and C_TradeSkillUI.GetRecipeInfo(info.nextRecipeID)
        if not info then
          break
        end
      end
    end
  end
  return byId
end

-- Takes the category out of the list, if it is in it. Returns whether it was folded, and the recipe that was selected in
-- it.
local function RemoveCategory(page, dataProvider, category)
  local folded, selected
  for _, node in ipairs({ unpack(dataProvider:GetChildrenNodes()) }) do
    local info = node:GetData().categoryInfo
    if info and info.categoryID == category.id then
      folded = node:IsCollapsed()
      for _, child in ipairs(node:GetNodes()) do
        if child:GetData().recipeInfo and page.RecipeList.selectionBehavior:IsElementDataSelected(child) then
          selected = child:GetData().recipeInfo
        end
      end
      dataProvider:Remove(node)
    end
  end
  return folded, selected
end

-- The recipe as the game lists it, by its id; one the list of the selected expansion does not hold comes from the game
-- directly. Nil if the character has not learned it. ids caches the recipe ids of the profession.
local function FindInfo(id, byId, ids)
  local info = byId[id]
  if info then
    return info
  end
  if not ids.list then
    ids.list = {}
    for _, recipeId in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
      ids.list[recipeId] = true
    end
  end
  info = ids.list[id] and C_TradeSkillUI.GetRecipeInfo(id)
  if info and info.learned then
    return Professions.GetFirstRecipe and Professions.GetFirstRecipe(info) or info
  end
  return nil
end

-- Puts a category with the entries { info, amount | suggestion } on top of the list, folded as it was before.
local function InsertCategory(page, dataProvider, category, title, entries, folded)
  local node = dataProvider:Insert({ group = category.group, categoryInfo = { name = LOGO .. title
    .. " (" .. #entries .. ")", uiOrder = -1, group = category.group, categoryID = category.id, AMPinned = true } })
  node:Insert({ topPadding = true, order = -1 })
  for index, entry in ipairs(entries) do
    local copy = CopyTable(entry.info)
    copy.favoritesInstance = true
    -- the suggestions keep their order, the recipes of the shopping list are sorted by the game
    node:Insert({ recipeInfo = copy, order = entry.suggestion and index or 0, AMAmount = entry.amount,
      AMSuggestion = entry.suggestion })
  end
  node:Insert({ bottomPadding = true, order = #entries + 1 })
  if folded == nil then
    local folds = page.GetCollapses and page:GetCollapses()
    folded = folds and folds[category.id]
  end
  if folded then
    node:SetCollapsed(true)
  end
end

-- Puts the categories into the list of the page again, as the shopping list and the profession are now. Called whenever
-- the game fills the list and whenever the shopping list or the prices change.
function CraftList.Update()
  local page = GetPage()
  local dataProvider = page and page.RecipeList and page.RecipeList.ScrollBox:GetDataProvider()
  if not (dataProvider and installed) then
    return
  end
  local shoppingFolded, shoppingSelected = RemoveCategory(page, dataProvider, SHOPPING)
  local levelingFolded, levelingSelected = RemoveCategory(page, dataProvider, LEVELING)
  local selected = shoppingSelected or levelingSelected
  -- not while searching, then the game shows the matches without categories, and not for the recipes of someone else
  if page.RecipeList.SearchBox:HasText() or not ShoppingList.IsOwnCrafting() then
    return
  end
  local order, amounts = ReadPlan()
  local byId = FindRecipes(dataProvider)
  -- The list holds only the recipes of the expansion selected there, the others come from the game directly.
  local ids = {}
  local recipes = {}
  for _, id in ipairs(order) do
    local info = FindInfo(id, byId, ids)
    if info then
      recipes[#recipes + 1] = { info = info, amount = amounts[id] }
    end
  end
  local suggestions = {}
  for _, suggestion in ipairs(AM.Leveling.GetSuggestions()) do
    local info = FindInfo(suggestion.recipe.id, byId, ids)
    if info then
      suggestions[#suggestions + 1] = { info = info, suggestion = suggestion }
    end
  end
  if #recipes == 0 and #suggestions == 0 then
    return
  end

  -- The game's root comparator reads the categoryInfo of both nodes, which its divider of unlearned recipes has not.
  -- table.sort may compare an element with itself, which the game never ran into until there was one more node.
  local root = dataProvider:GetRootNode()
  if root.sortComparator and not root.AMGuarded then
    local sort = root.sortComparator
    root.sortComparator = function(lhs, rhs)
      return lhs ~= rhs and sort(lhs, rhs)
    end
    root.AMGuarded = true
  end
  if #recipes > 0 then
    InsertCategory(page, dataProvider, SHOPPING, L["SHOPPING_TITLE"], recipes, shoppingFolded)
  end
  if #suggestions > 0 then
    InsertCategory(page, dataProvider, LEVELING, L["LEVELING_TITLE"], suggestions, levelingFolded)
  end
  if selected then
    -- the node it was selected in is gone
    page.RecipeList:SelectRecipe(selected)
  end
end

-- The icon at the right of a suggestion, with the tooltip of what to do with the result.
local function GetTipFrame(frame)
  if not frame.AMTip then
    local tip = CreateFrame("Frame", nil, frame)
    tip:SetSize(TIP_SIZE, TIP_SIZE)
    tip:EnableMouse(true)
    tip.icon = tip:CreateTexture(nil, "OVERLAY")
    tip.icon:SetAllPoints()
    tip:SetScript("OnEnter", function(self)
      AM.Leveling.ShowTooltip(self, self.suggestion)
    end)
    tip:SetScript("OnLeave", GameTooltip_Hide)
    frame.AMTip = tip
  end
  return frame.AMTip
end

-- The text at the right of a recipe of the category: the amount to craft, or the cost of the reagents of a suggestion
-- with the icon of what to do with the result after it.
local function OnFrameInitialized(_, frame, node)
  local data = node.GetData and node:GetData()
  local suggestion = data and data.AMSuggestion
  local text = data and (data.AMAmount and "×" .. data.AMAmount
    or suggestion and AM.FormatMoney(suggestion.cost, true))
  if frame.AMTip then
    frame.AMTip:Hide()
  end
  if not text then
    if frame.AMAmount then
      frame.AMAmount:Hide()
    end
    return
  end
  if not frame.AMAmount then
    frame.AMAmount = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  end
  frame.AMAmount:ClearAllPoints()
  if suggestion then
    local tip = GetTipFrame(frame)
    tip.suggestion = suggestion
    AM.Leveling.SetTipIcon(tip.icon, suggestion.tip)
    tip:ClearAllPoints()
    tip:SetPoint("RIGHT", -6, 0)
    tip:Show()
    frame.AMAmount:SetPoint("RIGHT", tip, "LEFT", -4, 0)
  else
    frame.AMAmount:SetPoint("RIGHT", -6, 0)
  end
  frame.AMAmount:SetText(text)
  frame.AMAmount:Show()
  -- keeps the name clear of it, and of the icon
  if frame.Label then
    -- the name starts after the difficulty arrow, not at the left edge of the row
    local left = frame.Label:GetLeft() and frame:GetLeft() and frame.Label:GetLeft() - frame:GetLeft() or NAME_OFFSET
    -- the craftable count (" [2] ") sits behind the name and must stay clear of it too
    local count = frame.Count and frame.Count:IsShown() and frame.Count:GetStringWidth() or 0
    local room = frame:GetWidth() - left - count - frame.AMAmount:GetStringWidth() - (suggestion and TIP_SIZE + 16 or 12)
    frame.Label:SetWidth(math.min(frame.Label:GetWidth(), room))
  end
end

-- The profession window is load on demand: hooked once it exists.
local function Install()
  local page = GetPage()
  local scrollBox = page and page.RecipeList and page.RecipeList.ScrollBox
  if installed or not scrollBox then
    return
  end
  installed = true
  hooksecurefunc(scrollBox, "SetDataProvider", CraftList.Update)
  scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, OnFrameInitialized, CraftList)
  CraftList.Update()
end

if ShoppingList.IsRetail() then
  local events = CreateFrame("Frame")
  events:RegisterEvent("ADDON_LOADED")
  events:RegisterEvent("PLAYER_LOGIN")
  events:SetScript("OnEvent", Install)
  -- the intermediate products depend on the prices
  AM.Events.Register("PRICES_CHANGED", CraftList.Update)
end
