local addonName, AM = ...
local L = AM.L

-- The block of three lines (crafting cost, market value, profit) added to the recipe page of the
-- profession windows, styled like their "Reagents:" section. The detail of the calculation is in a
-- tooltip on hover. Which client it is placed in, and where, is up to ProfessionsFrame.lua.
AM.RecipeSummary = {}
local RecipeSummary = AM.RecipeSummary

local WHITE = "Interface\\Buttons\\WHITE8X8"
local GRAY = "|cff808080"
local GREEN = "|cff1eff00"
local RED = "|cffff3333"

-- Money with the sign in front, the profit may be a loss.
local function SignedMoney(copper)
  if copper >= 0 then
    return GREEN .. "+" .. AM.FormatMoney(copper) .. "|r"
  end
  return RED .. "-" .. AM.FormatMoney(-copper) .. "|r"
end

local function Dim(text, stale)
  return stale and (GRAY .. text .. "|r") or text
end

-- Texts of the three lines for a result of RecipeCost.Calculate. A price that is not known shows as
-- "–", and a cost missing a reagent as "≥", so a total never looks complete when it is not.
local function BuildTexts(result)
  local stale = AM.RecipeCost.IsStale(result.age)
  local cost = (result.incomplete and "≥ " or "") .. AM.FormatMoney(result.cost)
  -- The auction price is shown before the cut, which is only taken off in the profit.
  local shown = result.valueSource == "market" and result.gross or result.value
  local value = shown and AM.FormatMoney(shown) or "–"
  local profit = result.profit and SignedMoney(result.profit) or "–"
  local valueLabel = result.valueSource == "vendor" and L["RECIPE_VENDOR_VALUE"]
    or result.basis == "lowest" and L["TOOLTIP_MIN_PRICE"] or L["TOOLTIP_MARKET_VALUE"]
  return { L["RECIPE_COST"], Dim(cost, stale) }, { valueLabel, Dim(value, stale) },
    { L["RECIPE_PROFIT"], result.profit and Dim(profit, stale) or profit }
end

local function AddTooltipLine(label, copper, dim)
  local color = dim and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR
  GameTooltip:AddDoubleLine(label, AM.FormatMoney(copper), color.r, color.g, color.b, color.r, color.g, color.b)
end

-- result is optional, the frame's own otherwise (the info icon passes its parent's).
local function ShowTooltip(self, result)
  result = result or self.result
  if not result or not result.profit then
    return
  end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(L["RECIPE_PROFIT_TITLE"], 1, 0.82, 0)
  if result.valueSource == "market" then
    AddTooltipLine(result.basis == "lowest" and L["RECIPE_TIP_LOWEST"] or L["RECIPE_TIP_MARKET"], result.gross)
    AddTooltipLine(L["RECIPE_TIP_FEE"], result.fee)
  else
    AddTooltipLine(L["RECIPE_TIP_VENDOR_VALUE"], result.value)
  end
  AddTooltipLine(L["RECIPE_TIP_COST"], result.cost)
  if result.valueSource == "market" and result.vendor then
    AddTooltipLine(L["RECIPE_TIP_VENDOR"], result.vendor, true)
  end
  if result.age then
    GameTooltip:AddLine(L["RECIPE_SCAN_AGE"]:format(SecondsToTime(result.age, true)), 0.5, 0.5, 0.5)
  end
  GameTooltip:AddLine(L["RECIPE_TIP_DISCLAIMER"], 1, 0.82, 0, true)
  GameTooltip:Show()
end

-- The "i" next to the profit that opens the calculation tooltip. It is a child of the frame that
-- holds the result, so it shows and hides with it.
local function CreateInfoIcon(parent, size)
  local icon = CreateFrame("Frame", nil, parent)
  icon:SetSize(size, size)
  icon:EnableMouse(true)
  local texture = icon:CreateTexture(nil, "ARTWORK")
  texture:SetAllPoints()
  texture:SetTexture("Interface/common/help-i")
  icon:SetScript("OnEnter", function(self)
    ShowTooltip(self, parent.result)
  end)
  icon:SetScript("OnLeave", GameTooltip_Hide)
  return icon
end

-- Creates the block below nothing in particular: the caller anchors it.
function RecipeSummary.Create(parent)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetHeight(66)
  frame:EnableMouse(true)

  local divider = frame:CreateTexture(nil, "ARTWORK")
  divider:SetPoint("TOPLEFT")
  divider:SetPoint("TOPRIGHT")
  divider:SetHeight(1)
  divider:SetTexture(WHITE)
  divider:SetVertexColor(0.35, 0.28, 0.19, 0.8)

  local labelFont = "GameFontNormal"
  local valueFont = "GameFontHighlight"
  local step = 20
  frame.rows = {}
  for i = 1, 3 do
    local y = -8 - (i - 1) * step
    local label = frame:CreateFontString(nil, "OVERLAY", labelFont)
    label:SetPoint("TOPLEFT", 0, y)
    local value = frame:CreateFontString(nil, "OVERLAY", valueFont)
    value:SetPoint("TOPRIGHT", 0, y)
    value:SetJustifyH("RIGHT")
    frame.rows[i] = { label = label, value = value }
  end

  frame:SetScript("OnEnter", function(self)
    ShowTooltip(self)
  end)
  frame:SetScript("OnLeave", GameTooltip_Hide)
  CreateInfoIcon(frame, 22):SetPoint("LEFT", frame.rows[3].label, "RIGHT", -4, 0)
  frame:Hide()

  -- result is nil to hide the block, e.g. for recipes without reagents.
  function frame:SetResult(result)
    self.result = result
    if not result then
      self:Hide()
      return
    end
    local texts = { BuildTexts(result) }
    for i, row in ipairs(self.rows) do
      row.label:SetText(texts[i][1])
      row.value:SetText(texts[i][2])
    end
    self:Show()
  end
  return frame
end

-- For clients whose recipe page has no room for one block: the three values are separate "Label: value"
-- lines the caller anchors where they fit (market value, crafting cost, profit), each with the same
-- calculation tooltip. The parents are the frames the lines belong to, e.g. so they scroll with the page.
function RecipeSummary.CreateSplit(marketParent, costParent, profitParent)
  local parts = {}
  local function CreatePart(parent)
    local part = CreateFrame("Frame", nil, parent)
    part:SetHeight(14)
    part:EnableMouse(true)
    part.text = part:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    part.text:SetPoint("LEFT")
    part:SetScript("OnEnter", function(self)
      ShowTooltip(self)
    end)
    part:SetScript("OnLeave", GameTooltip_Hide)
    part:Hide()
    return part
  end
  parts.cost = CreatePart(costParent)
  parts.market = CreatePart(marketParent)
  parts.profit = CreatePart(profitParent)
  CreateInfoIcon(parts.profit, 20):SetPoint("LEFT", parts.profit, "RIGHT", -3, 0)

  -- result is nil to hide the lines, e.g. for recipes without reagents.
  function parts.SetResult(result)
    local order = { parts.cost, parts.market, parts.profit }
    local texts = result and { BuildTexts(result) }
    for i, part in ipairs(order) do
      part.result = result
      if texts then
        part.text:SetText(NORMAL_FONT_COLOR:WrapTextInColorCode(texts[i][1]) .. " " .. texts[i][2])
        part:SetWidth(part.text:GetStringWidth())
        part:Show()
      else
        part:Hide()
      end
    end
  end
  return parts
end
