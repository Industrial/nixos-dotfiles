local addonName, AM = ...

-- Dispatches registered callbacks whenever GameTooltip is filled with an item, wherever
-- it comes from (bags, bank, auction house, item links, ...), via TooltipDataProcessor.
-- Any file that wants to add something to item tooltips just calls
-- AM.Tooltip.AddItemCallback and doesn't need to know about the underlying API.
--
-- TooltipDataProcessor doesn't fire on some clients (e.g. WoW Forever,
-- confirmed by testing). Dispatch is exposed on the module table so a game-type-specific
-- override (see srcClassic/tooltip/Tooltip.lua) can feed it items from a different hook on
-- clients where that's needed, without duplicating the guard/callback-list logic here.
AM.Tooltip = {}
local Tooltip = AM.Tooltip

local callbacks = {}

-- Registers callback(tooltip, itemId, location, count, itemDbKey) to run on every item tooltip fill.
-- location is the item's ItemLocation when it's a bag/bank item, nil otherwise. count is
-- the number of items the tooltip stands for when that is known without a location (the
-- quantity of a recipe reagent), nil otherwise. itemDbKey is the key of the market data of the hovered item (see
-- AM.ItemDbKey), nil where it cannot be told: the item data is not loaded yet, or the tooltip is of an item that stands
-- for any level (the result of a recipe for equipment). Callers show no auction data then. A tooltip owner that stands for a single item sets tooltip.AM_Count = 1
-- while it shows it, so no stack lines are added.
function Tooltip.AddItemCallback(callback)
  callbacks[#callbacks + 1] = callback
end

-- Adds a line with a left and a right text. Lines are reused across fills and keep the font of whatever was on that row
-- before, so the font is set explicitly. SetFontObject also resets the text color, so the colors are applied after it.
function Tooltip.AddDoubleLine(tooltip, left, right, leftColor, rightColor)
  GameTooltip_AddColoredDoubleLine(tooltip, left, right, leftColor, rightColor)
  local index = tooltip:NumLines()
  local leftLine = _G[tooltip:GetName() .. "TextLeft" .. index]
  local rightLine = _G[tooltip:GetName() .. "TextRight" .. index]
  leftLine:SetFontObject(GameTooltipText)
  rightLine:SetFontObject(GameTooltipText)
  leftLine:SetTextColor(leftColor:GetRGB())
  rightLine:SetTextColor(rightColor:GetRGB())
end

-- The location of the hovered item, only known for bag/bank items (whose item buttons
-- expose GetBagID/GetID for this). Other item buttons (e.g. recipe reagents) share the
-- mixin but have no bag.
local function GetBagLocation(tooltip)
  local owner = tooltip:GetOwner()
  local bagId = owner and owner.GetBagID and owner:GetBagID()
  if bagId then
    local location = ItemLocation:CreateFromBagAndSlot(bagId, owner:GetID())
    if C_Item.DoesItemExist(location) then
      return location
    end
  end
  return nil
end

-- The quantity a recipe needs of the hovered reagent, nil if the tooltip is not one.
local function GetReagentCount(tooltip)
  local info = tooltip.processingInfo
  if not (info and info.getterName == "GetRecipeReagentItem" and info.getterArgs) then
    return nil
  end
  local recipeId, dataSlotIndex = unpack(info.getterArgs)
  local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeId, false)
  for _, slot in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
    if slot.dataSlotIndex == dataSlotIndex then
      return slot.quantityRequired
    end
  end
  return nil
end

-- The tooltip getters that build their item from an id and not from a real item: the link in their data is a stand-in
-- (the same bonus ID for every level). For an auction house row its item level says nothing, for the result of a recipe
-- it is the level the game shows in the tooltip (checked on Retail), so that getter is not in this list.
local STAND_IN_GETTERS = { GetItemKey = true, GetRecipeReagentItem = true }

-- The link of the item a recipe item makes: the data of a recipe's tooltip carries it instead of the recipe's own link.
-- Nil for every other item and for tooltips that already are of the made item.
local function GetCraftedLink(itemId, data)
  local link = data and data.hyperlink
  local linkId = link and C_Item.GetItemInfoInstant(link)
  if linkId and linkId ~= itemId and select(6, C_Item.GetItemInfoInstant(itemId)) == Enum.ItemClass.Recipe then
    return link
  end
  return nil
end

-- The key of the hovered item, from the best source the tooltip has: the arguments of a row of the auction house (they
-- are the item key of the row), the bag slot, the link. Nil and the reason if there is none.
local function ResolveItemDbKey(tooltip, itemId, location, link, data)
  local info = tooltip.processingInfo
  local getter = info and info.getterName
  local args = info and info.getterArgs
  if getter == "GetItemKey" and args then
    return AM.ItemDbKey.Build(args[1], args[2])
  elseif location then
    return AM.ItemDbKey.FromLocation(location)
  end
  -- The link of a recipe's data is the one of the item it makes, not the recipe's.
  link = link or (not STAND_IN_GETTERS[getter] and not GetCraftedLink(itemId, data) and data and data.hyperlink) or nil
  if link then
    return AM.ItemDbKey.FromLink(link)
  end
  return AM.ItemDbKey.ForItem(itemId)
end

-- Resets the once-per-fill guard below whenever the tooltip moves on to a new item (or is
-- hidden), so the next fill can dispatch again.
GameTooltip:HookScript("OnTooltipCleared", function(tooltip)
  tooltip.AM_Dispatched = nil
end)

-- Runs all registered callbacks for itemId, at most once per tooltip fill. Public so a
-- game-type-specific override can feed it from a different hook (see
-- srcClassic/tooltip/Tooltip.lua), with the item link if it has one; guarded here so that stays safe even if some client fires
-- both TooltipDataProcessor and an override's hook for the same fill.
local function Dispatch(tooltip, itemId, link, data)
  if tooltip.AM_Dispatched then
    return
  end
  tooltip.AM_Dispatched = true

  local location = GetBagLocation(tooltip)
  local count = tooltip.AM_Count or GetReagentCount(tooltip)
  local itemDbKey, reason = ResolveItemDbKey(tooltip, itemId, location, link, data)
  if AM.DebugLog.IsEnabled() then
    local info = tooltip.processingInfo
    AM.DebugLog.Log("tooltip", "item %d via %s -> %s", itemId, info and info.getterName or "?",
      itemDbKey or ("no key: " .. tostring(reason)))
  end
  for _, callback in ipairs(callbacks) do
    callback(tooltip, itemId, location, count, itemDbKey)
  end
  tooltip:Show()
end
Tooltip.Dispatch = Dispatch

local petCallbacks = {}

-- Registers callback(tooltip, itemDbKey) to run whenever the battle pet tooltip is filled (the auction house rows and
-- links of pets). That is a frame of its own (BattlePetTooltip, not GameTooltip) and no TooltipDataProcessor fills it;
-- it only has AddLine(text, r, g, b, wrap).
function Tooltip.AddPetCallback(callback)
  petCallbacks[#petCallbacks + 1] = callback
end

-- Adds a line with a left and a right text to the battle pet tooltip, which has no double lines: the left text is a line
-- of the tooltip, the right one a right-aligned text of ours on the same row. The tooltip releases its own lines
-- whenever it is filled anew, so ours are hidden again by ResetPetRightTexts (called before the callbacks).
function Tooltip.AddPetDoubleLine(tooltip, left, right, leftColor, rightColor)
  tooltip:AddLine(left, leftColor.r, leftColor.g, leftColor.b)
  local line = tooltip.textLineAnchor
  if not line then
    return
  end
  local used = (tooltip.AM_RightUsed or 0) + 1
  tooltip.AM_RightUsed = used
  tooltip.AM_RightTexts = tooltip.AM_RightTexts or {}
  local text = tooltip.AM_RightTexts[used]
  if not text then
    text = tooltip:CreateFontString(nil, "ARTWORK", "GameTooltipText")
    text:SetJustifyH("RIGHT")
    tooltip.AM_RightTexts[used] = text
  end
  text:ClearAllPoints()
  text:SetPoint("TOP", line, "TOP")
  text:SetPoint("RIGHT", tooltip, "RIGHT", -10, 0)
  text:SetText(right)
  text:SetTextColor(rightColor.r, rightColor.g, rightColor.b)
  text:Show()
end

local function ResetPetRightTexts(tooltip)
  for _, text in ipairs(tooltip.AM_RightTexts or {}) do
    text:Hide()
  end
  tooltip.AM_RightUsed = 0
end

if BattlePetToolTip_Show then
  hooksecurefunc("BattlePetToolTip_Show", function(speciesId)
    if not (speciesId and speciesId > 0 and BattlePetTooltip) then
      return
    end
    local itemDbKey = AM.ItemDbKey.Build(AM.ItemDbKey.PET_CAGE, nil, speciesId)
    ResetPetRightTexts(BattlePetTooltip)
    for _, callback in ipairs(petCallbacks) do
      callback(BattlePetTooltip, itemDbKey)
    end
    -- The game's AddLine adds the height of a line right after setting its text, before a wrapping line has its
    -- final height, so the frame can end up shorter than its lines (more so with our lines among them). Once the
    -- lines are laid out, let the frame grow to the bottom of the last one.
    C_Timer.After(0, function()
      local last = BattlePetTooltip.textLineAnchor
      if BattlePetTooltip:IsShown() and last and last.GetStringHeight and last:GetBottom() and BattlePetTooltip:GetTop() then
        local needed = BattlePetTooltip:GetTop() - last:GetBottom() + 10
        if needed > BattlePetTooltip:GetHeight() then
          BattlePetTooltip:SetHeight(needed)
        end
      end
    end)
  end)
end

if TooltipDataProcessor and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if tooltip == GameTooltip and data and data.id then
      Dispatch(tooltip, data.id, nil, data)
    end
  end)
end
