local addonName, AM = ...
local L = AM.L

-- Adds what disenchanting the item yields to its tooltip, below the market data (this file loads after
-- ItemTooltip.lua): the materials with quantity and chance, and their value. Nothing is shown for items without a
-- known rule (AM.Disenchant.GetEstimate).
local Disenchant = AM.Disenchant

local MUTED = GRAY_FONT_COLOR

local function FormatQuantity(outcome)
  if outcome.minQuantity == outcome.maxQuantity then
    return outcome.minQuantity .. "x"
  end
  return outcome.minQuantity .. "-" .. outcome.maxQuantity .. "x"
end

local function GetIcon(itemId)
  local icon = select(5, C_Item.GetItemInfoInstant(itemId))
  return icon and ("|T%s:12|t "):format(icon) or ""
end

-- The data of a material the client has not seen is requested and shows the next time.
local function GetName(itemId)
  local name = C_Item.GetItemInfo(itemId)
  if not name then
    C_Item.RequestLoadItemDataByID(itemId)
    return "..."
  end
  return name
end

-- Whether item tooltips show the disenchant block: on unless switched off in the options (global object
-- "settings").
function Disenchant.IsTooltipEnabled()
  return AM.Database.GetGlobalObject("settings").disenchantTooltip ~= false
end

function Disenchant.SetTooltipEnabled(enabled)
  -- nil is on; not "(not enabled) and false or nil", which is nil for both
  local settings = AM.Database.GetGlobalObject("settings")
  if enabled then
    settings.disenchantTooltip = nil
  else
    settings.disenchantTooltip = false
  end
end

AM.Tooltip.AddItemCallback(function(tooltip, itemId, location)
  if not Disenchant.IsTooltipEnabled() then
    return
  end
  local item = select(2, tooltip:GetItem()) or itemId
  local estimate = Disenchant.GetEstimate(item, location and C_Item.GetCurrentItemLevel(location) or nil)
  if not estimate then
    return
  end
  local spellIcon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(Disenchant.SPELL_ID)
    or GetSpellTexture and GetSpellTexture(Disenchant.SPELL_ID)
  AM.Tooltip.AddDoubleLine(tooltip, (spellIcon and ("|T%s:14|t "):format(spellIcon) or "") .. L["DISENCHANT_TITLE"],
    estimate.complete and (L["DISENCHANT_ESTIMATE"] .. " " .. AM.FormatMoney(math.floor(estimate.value)))
      or RED_FONT_COLOR:WrapTextInColorCode(L["DISENCHANT_NO_PRICE"]),
    NORMAL_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
  for _, outcome in ipairs(estimate.outcomes) do
    AM.Tooltip.AddDoubleLine(tooltip, GetIcon(outcome.itemId) .. GetName(outcome.itemId),
      ("%s  %s"):format(FormatQuantity(outcome), MUTED:WrapTextInColorCode(("%d%%"):format(math.floor(outcome.chance * 100 + 0.5)))),
      HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
  end
end)
