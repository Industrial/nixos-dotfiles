local addonName, AM = ...

-- What disenchanting an item yields, from the known rules of a client (AddRules, e.g.
-- srcForever/disenchant/ForeverRules.lua). Where there is no rule, nothing is predicted ("No guessing").
AM.Disenchant = {}
local Disenchant = AM.Disenchant

Disenchant.SPELL_ID = 13262

local KINDS = { [Enum.ItemClass.Weapon] = "weapon", [Enum.ItemClass.Armor] = "armor" }
local MIN_QUALITY, MAX_QUALITY = AM.Client.UNCOMMON, Enum.ItemQuality.Epic
-- Never disenchantable, whatever their class and quality.
local NOT_DISENCHANTABLE = { INVTYPE_BODY = true, INVTYPE_TABARD = true }
-- Single items that cannot be disenchanted although their class, slot and quality say so (self crafted wands).
local NOT_DISENCHANTABLE_ITEMS = { [11287] = true, [11288] = true, [11289] = true, [11290] = true }

-- "armor" or "weapon" for an item (id or link) that can be disenchanted, with its quality; nil otherwise or while the
-- item data is not loaded.
function Disenchant.GetKind(item)
  local itemId, _, _, equipLoc, _, classId = C_Item.GetItemInfoInstant(item)
  local kind = classId and KINDS[classId]
  if not kind or NOT_DISENCHANTABLE[equipLoc] or NOT_DISENCHANTABLE_ITEMS[itemId] then
    return nil
  end
  local quality = select(3, C_Item.GetItemInfo(item))
  if quality and quality >= MIN_QUALITY and quality <= MAX_QUALITY then
    return kind, quality
  end
  return nil
end

-- The item level that decides what comes out of a disenchant. Nil while it is not known.
function Disenchant.GetItemLevel(item)
  return (C_Item.GetDetailedItemLevelInfo(item))
end

-- The market price of a material, nil if none is known.
local function GetMaterialPrice(itemId)
  local itemDbKey = AM.ItemDbKey.ForItem(itemId)
  local market = itemDbKey and AM.ItemStore.GetMarketPrice(itemDbKey)
  return market and market.price
end

-- Rules ----------------------------------------------------------------------------------------------------

-- Known rules of a client (see srcForever/disenchant/ForeverRules.lua). rules[kind][quality] = list of { minLevel, maxLevel, outcomes }, an outcome being
-- { itemId, minQuantity, maxQuantity, chance }.
local rules = {}

-- Adds rules from lines of the form "8-15:[itemId,min,max,chance],[itemId,min,max,chance]".
function Disenchant.AddRules(kind, quality, text)
  rules[kind] = rules[kind] or {}
  local list = rules[kind][quality] or {}
  rules[kind][quality] = list
  for minLevel, maxLevel, body in text:gmatch("(%d+)%-(%d+):([^\n]+)") do
    local outcomes = {}
    for itemId, low, high, chance in body:gmatch("%[(%d+),(%d+),(%d+),([%d%.]+)%]") do
      outcomes[#outcomes + 1] = { tonumber(itemId), tonumber(low), tonumber(high), tonumber(chance) }
    end
    list[#list + 1] = { tonumber(minLevel), tonumber(maxLevel), outcomes }
  end
end

-- The outcomes of the rule for the item level, nil if there is none.
local function GetRuleOutcomes(kind, quality, itemLevel)
  local list = rules[kind] and rules[kind][quality]
  for _, rule in ipairs(list or {}) do
    if itemLevel >= rule[1] and itemLevel <= rule[2] then
      return rule[3]
    end
  end
  return nil
end

-- What disenchanting the item (id or link) yields: { outcomes, value, complete }, nil if it cannot be disenchanted or
-- there is no rule for its kind and item level. An outcome is
-- { itemId, chance (0-1), minQuantity, maxQuantity, average, price (nil if unknown) }, the likeliest first. value is the
-- market value of what comes out on average; complete is false while an outcome has no price, the value is then too low.
-- An item of the right kind and level is enough, it is not looked at as an individual.
function Disenchant.GetEstimate(item, itemLevel)
  local kind, quality = Disenchant.GetKind(item)
  itemLevel = itemLevel or Disenchant.GetItemLevel(item)
  if not (kind and itemLevel) then
    return nil
  end
  local outcomes = GetRuleOutcomes(kind, quality, itemLevel)
  if not outcomes then
    return nil
  end
  local estimate = { outcomes = {}, value = 0, complete = true }
  for _, outcome in ipairs(outcomes) do
    local itemId, low, high, chance = unpack(outcome)
    -- the rules only know the range, the quantity within it is taken to be spread evenly
    local average = (low + high) / 2
    local price = GetMaterialPrice(itemId)
    estimate.outcomes[#estimate.outcomes + 1] = { itemId = itemId, chance = chance, minQuantity = low,
      maxQuantity = high, average = average, price = price }
    if price then
      estimate.value = estimate.value + chance * average * price
    else
      estimate.complete = false
    end
  end
  table.sort(estimate.outcomes, function(a, b)
    if a.chance ~= b.chance then
      return a.chance > b.chance
    end
    return a.itemId < b.itemId
  end)
  return estimate
end

-- What disenchanting the item brings after the auction house cut, per item, nil if that cannot be said (no rule, a
-- material without a price).
function Disenchant.GetNetValue(item, itemLevel)
  local estimate = Disenchant.GetEstimate(item, itemLevel)
  if not (estimate and estimate.complete) then
    return nil
  end
  return math.floor(estimate.value * (1 - AM.RecipeCost.AH_CUT))
end

-- Characters that can disenchant ------------------------------------------------------------------------

-- The faction object "disenchanters" holds the GUIDs of the characters that know the Disenchant ability. Only the
-- current character can be asked, the others are remembered from when they last played.
local function GetDisenchanters()
  return AM.Database.GetFactionObject("disenchanters")
end

local function KnowsDisenchant()
  local isKnown = IsPlayerSpell or IsSpellKnown
  return isKnown ~= nil and isKnown(Disenchant.SPELL_ID) == true
end

-- Remembers whether the current character can disenchant. Skipped while the client does not know any spell yet.
function Disenchant.UpdateCharacter()
  local guid = UnitGUID("player")
  if not guid or not (IsPlayerSpell or IsSpellKnown) then
    return
  end
  local known = KnowsDisenchant()
  local disenchanters = GetDisenchanters()
  if known ~= (disenchanters[guid] == true) then
    disenchanters[guid] = known or nil
    AM.Events.Fire("DISENCHANT_CHANGED")
  end
end

-- Whether a character of this faction that is not ignored can disenchant.
function Disenchant.HasDisenchanter()
  for guid in pairs(GetDisenchanters()) do
    if not AM.ProfessionScanner.IsCharacterIgnored(guid) then
      return true
    end
  end
  return false
end

-- Forgets a deleted character.
function Disenchant.ForgetCharacter(guid)
  GetDisenchanters()[guid] = nil
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
for _, event in ipairs({ "SPELLS_CHANGED", "SKILL_LINES_CHANGED" }) do
  -- not every client has every event
  pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_ENTERING_WORLD" then
    self:UnregisterEvent(event)
    -- the spells are known a moment after login
    C_Timer.After(5, Disenchant.UpdateCharacter)
  else
    Disenchant.UpdateCharacter()
  end
end)
