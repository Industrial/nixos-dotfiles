local addonName, AM = ...

-- Which known recipes of the open profession are the cheap way to level it: the cheapest recipe of each skill-up
-- color (orange, yellow, green), where a worse color is only listed if it costs less than every better one. Only the
-- cost of the reagents counts, never what the result sells for (that is unpredictable); what to do with the result is
-- a hint of its own. A recipe whose reagents have no price is left out, never guessed. The chance of a skill point
-- is not known to the game's API (the thresholds are not exposed), so only the colors rank. No UI: shown by
-- CraftList.lua (Retail, Forever) and CraftPanel.lua (Classic).
AM.Leveling = {}
local Leveling = AM.Leveling

-- Best color first. Grey recipes give no skill point and are never listed.
local COLORS = { "optimal", "medium", "easy" }

-- The cheapest of the candidates { difficulty = "optimal"|"medium"|"easy"|other, cost = copper or nil } per color,
-- the colors from best to worst, kept only if strictly cheaper than all kept before (equal cost keeps the better
-- color). Returns the kept candidates in that order.
function Leveling.Select(candidates)
  local cheapest = {}
  for _, candidate in ipairs(candidates) do
    local color = candidate.difficulty
    local best = cheapest[color]
    if candidate.cost and (not best or candidate.cost < best.cost) then
      cheapest[color] = candidate
    end
  end
  local result, bestSoFar = {}, math.huge
  for _, color in ipairs(COLORS) do
    local candidate = cheapest[color]
    if candidate and candidate.cost < bestSoFar then
      result[#result + 1] = candidate
      bestSoFar = candidate.cost
    end
  end
  return result
end

-- What to do with the result of a craft: "ah", "vendor" or "disenchant" with what it brings (the auction house after
-- the cut, the vendor, or the materials after the cut), "none" where neither is known. calculation is what
-- RecipeCost.Calculate made of the recipe, disenchant what disenchanting the result brings (nil if it cannot be
-- said). The deposit is not counted, as the sell tab does for an item it has not got yet.
function Leveling.GetTip(calculation, disenchant)
  local auction = calculation.gross and math.floor(calculation.gross * (1 - AM.RecipeCost.AH_CUT)) or 0
  local vendor = calculation.vendor or 0
  local best = math.max(auction, vendor)
  if disenchant and disenchant > best then
    return "disenchant", disenchant
  end
  if best <= 0 then
    return "none"
  end
  if vendor >= auction then
    return "vendor", vendor
  end
  return "ah", auction
end

local function GetDisenchantValue(recipe)
  if not (recipe.outputItemId and AM.Disenchant.HasDisenchanter()) then
    return nil
  end
  local value = AM.Disenchant.GetNetValue(recipe.outputItemId)
  return value and value * (recipe.outputCount or 1) or nil
end

-- The candidate of a recipe as read by ShoppingList, nil when the reagents are not all priced.
local function MakeCandidate(recipe, difficulty)
  local calculation = AM.RecipeCost.Calculate(recipe)
  if calculation.incomplete or calculation.cost <= 0 then
    return nil
  end
  local tip, value = Leveling.GetTip(calculation, GetDisenchantValue(recipe))
  return { recipe = recipe, difficulty = difficulty, cost = calculation.cost, tip = tip, tipValue = value }
end

local retailColors
local function GetRetailColor(difficulty)
  if not retailColors then
    local E = Enum.TradeskillRelativeDifficulty
    retailColors = { [E.Optimal] = "optimal", [E.Medium] = "medium", [E.Easy] = "easy" }
  end
  return retailColors[difficulty]
end

-- Retail and Forever: the learned recipes the game says would give a skill point, from all recipes of the open
-- profession.
local function ReadRetail()
  local candidates = {}
  for _, recipeId in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
    local info = C_TradeSkillUI.GetRecipeInfo(recipeId)
    local color = info and info.learned and info.canSkillUp and GetRetailColor(info.relativeDifficulty)
    if color then
      local recipe = AM.ShoppingList.ReadRetailRecipe(recipeId)
      local candidate = recipe and MakeCandidate(recipe, color)
      if candidate then
        candidates[#candidates + 1] = candidate
      end
    end
  end
  return candidates
end

-- Classic: the recipes of the window, which lists only those below an expanded header.
local function ReadClassic()
  local candidates = {}
  for index = 1, GetNumTradeSkills() do
    local _, skillType = GetTradeSkillInfo(index)
    if skillType == "optimal" or skillType == "medium" or skillType == "easy" then
      local recipe = AM.ShoppingList.ReadClassicRecipe(index)
      local candidate = recipe and MakeCandidate(recipe, skillType)
      if candidate then
        candidates[#candidates + 1] = candidate
      end
    end
  end
  return candidates
end

-- Whether the profession windows show the suggestions: on unless switched off in the options (global object
-- "settings").
function Leveling.IsEnabled()
  return AM.Database.GetGlobalObject("settings").leveling ~= false
end

function Leveling.SetEnabled(enabled)
  -- nil is on; not "enabled and nil or false", which is false for both
  local settings = AM.Database.GetGlobalObject("settings")
  if enabled then
    settings.leveling = nil
  else
    settings.leveling = false
  end
  AM.CraftList.Update()
  AM.CraftPanel.Update()
end

-- Whether the open profession is at the highest skill it can reach for now (the cap of its rank on Classic, of the
-- expansion shown on Retail and Forever): no recipe gives a skill point then, though the colors still say so. False
-- where the client does not tell.
function Leveling.IsAtMaximum()
  local level, maximum
  if AM.ShoppingList.IsRetail() then
    local info = C_TradeSkillUI.GetChildProfessionInfo and C_TradeSkillUI.GetChildProfessionInfo()
    if not (info and info.maxSkillLevel and info.maxSkillLevel > 0) then
      info = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
    end
    level, maximum = info and info.skillLevel, info and info.maxSkillLevel
  elseif GetTradeSkillLine then
    local _
    _, level, maximum = GetTradeSkillLine()
  end
  return level ~= nil and maximum ~= nil and maximum > 0 and level >= maximum
end

-- The suggestions for the open profession of the current character, best color first, each
-- { recipe, difficulty, cost (reagents, copper), tip, tipValue }. Empty while switched off, for the recipes of someone
-- else, a profession at its maximum skill or with nothing left to skill up or one without prices.
function Leveling.GetSuggestions()
  if not (Leveling.IsEnabled() and AM.ShoppingList.IsSupported() and AM.ShoppingList.IsOwnCrafting()) then
    return {}
  end
  if Leveling.IsAtMaximum() then
    return {}
  end
  local candidates = AM.ShoppingList.IsRetail() and ReadRetail() or ReadClassic()
  return Leveling.Select(candidates)
end

-- What a suggestion shows after the name of the recipe, per hint: the same words as the sell tab's hints.
Leveling.TIP_ICONS = {
  ah = "Interface\\GossipFrame\\auctioneerGossipIcon",
  vendor = "Interface\\GossipFrame\\VendorGossipIcon",
  disenchant = "Interface\\Icons\\INV_Enchant_Disenchant",
  none = "Interface\\Icons\\INV_Misc_Coin_01", -- shown greyed out, see SetTipIcon
}

-- Puts the icon of the hint on a texture: where nothing is known the coin is greyed out and dimmed.
function Leveling.SetTipIcon(texture, tip)
  texture:SetTexture(Leveling.TIP_ICONS[tip])
  texture:SetDesaturated(tip == "none")
  texture:SetAlpha(tip == "none" and 0.5 or 1)
end
local TIP_TEXT = { ah = "SELL_TIP_AH", vendor = "SELL_TIP_VENDOR", disenchant = "SELL_TIP_DISENCHANT",
  none = "SELL_TIP_NONE" }

-- The tooltip of the hint icon: what to do with the result, what the reagents cost and what the colors mean.
function Leveling.ShowTooltip(anchor, suggestion)
  local L = AM.L
  GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
  GameTooltip:AddLine(suggestion.recipe.name, 1, 0.82, 0)
  GameTooltip:AddDoubleLine(L["LEVELING_COST"], AM.FormatMoney(suggestion.cost), 1, 1, 1, 1, 1, 1)
  local label = L[TIP_TEXT[suggestion.tip]]
  if suggestion.tipValue then
    GameTooltip:AddDoubleLine(L["LEVELING_THEN"] .. " " .. label, AM.FormatMoney(suggestion.tipValue), 1, 1, 1, 1, 1, 1)
  else
    GameTooltip:AddLine(L["LEVELING_THEN"] .. " " .. label, 1, 1, 1)
  end
  GameTooltip:AddLine(L["LEVELING_COLORS"], 0.7, 0.7, 0.7, true)
  GameTooltip:Show()
end
