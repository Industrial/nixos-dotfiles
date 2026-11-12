local addonName, AM = ...
local L = AM.L

-- Additions to the profession frames of the game. They are load on demand, so everything is hooked
-- when the frame exists. The "Add to Shopping List" button and the crafting cost, market value and
-- profit of the selected recipe, laid out per client.
AM.ProfessionsFrame = {}
local ProfessionsFrameModule = AM.ProfessionsFrame

-- Shows the remove button of the recipe page while the selected recipe is on the list (Retail and Forever).
local removeUpdaters = {}
function ProfessionsFrameModule.UpdateRemove()
  for _, update in ipairs(removeUpdaters) do
    update()
  end
end

local ShoppingList = AM.ShoppingList

-- A secondary button like the filter button of the profession frame, not the red action button.
local function CreateAddButton(parent, anchor, point, relativePoint, x, y, readRecipe, readCount, readName, label, width)
  local ok, button = pcall(CreateFrame, "Button", nil, parent, "UIMenuButtonStretchTemplate")
  if not ok then
    button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  end
  button:SetSize(width or 150, 24)
  button:SetText(label or L["SHOPPING_ADD_TO_LIST"])
  local color = LIGHTGRAY_FONT_COLOR or GRAY_FONT_COLOR -- same gray as the "Recipe lists" checkbox label
  if color and button:GetFontString() then
    button:GetFontString():SetTextColor(color:GetRGB())
  end
  button:SetPoint(point, anchor, relativePoint, x, y)
  button:SetFrameLevel(parent:GetFrameLevel() + 100) -- the page's other children would cover it
  button:SetScript("OnClick", function()
    local recipe = readRecipe()
    if not recipe then
      return
    end
    local count = readCount()
    ShoppingList.AddRecipe(recipe, count)
    AM.Print(L["SHOPPING_ADDED"]:format(count, recipe.name))
  end)
  button:SetScript("OnEnter", function(self)
    local name = readName()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["SHOPPING_ADD_TO_LIST"], 1, 1, 1)
    if name then
      GameTooltip:AddLine(L["SHOPPING_ADD_TOOLTIP"]:format(readCount(), name), nil, nil, nil, true)
    end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", GameTooltip_Hide)
  return button
end

local RecipeCost = AM.RecipeCost
local RecipeSummary = AM.RecipeSummary

-- The cost updates of the recipe pages that are set up, run again when item data (vendor sell price
-- of the crafted item) arrives. Item data comes in bursts, so once for all of it.
local costUpdaters = {}
local costRefreshPending = false
local itemInfoFrame = CreateFrame("Frame")
itemInfoFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
itemInfoFrame:SetScript("OnEvent", function()
  if costRefreshPending then
    return
  end
  costRefreshPending = true
  C_Timer.After(0.3, function()
    costRefreshPending = false
    for _, update in ipairs(costUpdaters) do
      update()
    end
  end)
end)

-- Where the price starts: level with the left edge of the reagent name, which the game places next to the
-- icon (the name itself if it has one, else an estimate from the icon width).
local function PriceAnchor(slot)
  if slot.Name then
    return slot.Name, "LEFT", 0
  end
  local icon = slot.Button or slot.Icon
  return slot, "LEFT", (icon and icon:GetWidth() or 40) + 10
end

-- Price and where it comes from at the right of a reagent slot, in the free space next to its name.
-- With two columns of reagents that space belongs to the slot of the other column, so the price goes
-- below the name on one line instead.
local function SetReagentPrice(slot, line, twoColumns)
  if not slot.AMPrice then
    slot.AMPrice = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slot.AMSource = slot:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  end
  slot.AMPrice:ClearAllPoints()
  slot.AMSource:ClearAllPoints()
  if twoColumns then
    -- The slot frame spans its whole column and the name is centered next to the icon, so the line
    -- below a two-line name sits a little under the vertical center.
    local relativeTo, relativePoint, x = PriceAnchor(slot)
    slot.AMPrice:SetPoint("TOPLEFT", relativeTo, relativePoint, x, -17)
    slot.AMSource:SetPoint("LEFT", slot.AMPrice, "RIGHT", 4, 0)
  else
    slot.AMPrice:SetPoint("BOTTOMLEFT", slot, "RIGHT", 10, 0)
    slot.AMSource:SetPoint("TOPLEFT", slot, "RIGHT", 10, -1)
  end
  if not line then
    slot.AMPrice:SetText("")
    slot.AMSource:SetText("")
    return
  end
  local text = line.price and AM.FormatMoney(line.price) or "–"
  if line.price and RecipeCost.IsStale(line.age) then
    text = "|cff808080" .. text .. "|r"
  end
  slot.AMPrice:SetText(text)
  slot.AMSource:SetText(line.source == "auction" and L["RECIPE_SOURCE_AUCTION"]
    or line.source == "vendor" and L["RECIPE_SOURCE_VENDOR"]
    or line.source == "crafted" and L["RECIPE_SOURCE_CRAFTED"] or "")
  -- A source that does not fit in the column would be cut off at the edge of the page, so it is left out.
  if twoColumns then
    local needed = slot.AMPrice:GetStringWidth() + 4 + slot.AMSource:GetStringWidth()
    local relativeTo, _, x = PriceAnchor(slot)
    local left = relativeTo.GetLeft and relativeTo:GetLeft()
    local right = slot:GetRight()
    local available = left and right and right - left - x or slot:GetWidth() - 50
    slot.AMSource:SetShown(needed <= available)
  else
    slot.AMSource:Show()
  end
end

-- Retail and WoW Forever (the schematic form): a price at every reagent and the summary block below
-- them, in the free space above the buttons. Forever has the "Show in list" row at the bottom and our
-- button row, so the block sits higher there.
local function SetupRetailCost(page)
  local form = page.SchematicForm
  if not form or form.AMSummary then
    return
  end
  local bottom = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and 16 or 41
  local summary = RecipeSummary.Create(form)
  summary:SetPoint("BOTTOMLEFT", form, "BOTTOMLEFT", 16, bottom)
  summary:SetPoint("BOTTOMRIGHT", form, "BOTTOMRIGHT", -16, bottom)
  form.AMSummary = summary

  local function Update()
    local info = form.GetRecipeInfo and form:GetRecipeInfo()
    local recipeId = info and info.recipeID or form.recipeSchematic and form.recipeSchematic.recipeID
    local recipe = recipeId and ShoppingList.ReadRetailRecipe(recipeId)
    local slots = form.reagentSlots and form.reagentSlots[Enum.CraftingReagentType.Basic] or {}
    -- Slot frames are reused between recipes, so one that showed a price as a basic reagent may be an
    -- optional or finishing slot now. Only basic reagents are priced.
    for reagentType, others in pairs(form.reagentSlots or {}) do
      if reagentType ~= Enum.CraftingReagentType.Basic then
        for _, slot in ipairs(others) do
          SetReagentPrice(slot, nil)
        end
      end
    end
    if not recipe or #recipe.reagents == 0 then
      summary:SetResult(nil)
      for _, slot in ipairs(slots) do
        SetReagentPrice(slot, nil)
      end
      return
    end
    local result = RecipeCost.Calculate(recipe)
    summary:SetResult(result)
    local twoColumns = false
    local firstLeft = slots[1] and slots[1]:GetLeft()
    if slots[1] and not firstLeft and not form.AMLayoutRetry then
      -- Not laid out yet, so the columns cannot be told apart: look again next frame.
      form.AMLayoutRetry = true
      C_Timer.After(0, function()
        form.AMLayoutRetry = nil
        if form:IsVisible() then
          form.AMUpdate()
        end
      end)
    end
    for _, slot in ipairs(slots) do
      local left = slot:GetLeft()
      if firstLeft and left and math.abs(left - firstLeft) > 20 then
        twoColumns = true
      end
    end
    for _, slot in ipairs(slots) do
      local schematic = slot.GetReagentSlotSchematic and slot:GetReagentSlotSchematic() or slot.reagentSlotSchematic
      local first = schematic and schematic.reagents and schematic.reagents[1]
      local match
      for _, line in ipairs(result.reagents) do
        if first and line.itemId == first.itemID then
          match = line
        end
      end
      SetReagentPrice(slot, match, twoColumns)
    end
  end
  form.AMUpdate = Update
  costUpdaters[#costUpdaters + 1] = function()
    if form:IsVisible() then
      Update()
    end
  end
  if form.Init then
    hooksecurefunc(form, "Init", Update)
  end
  form:HookScript("OnShow", Update)
end

-- Classic: no room for a price per reagent (their tooltips have it), so the three values sit where the
-- page has space: market value below the recipe name, crafting cost at the right of the "Reagents:"
-- label and profit left of the "Add to Shopping List" button.
local function SetupClassicCost(addButton)
  local content = TradeSkillDetailScrollChildFrame or TradeSkillFrame
  local summary = RecipeSummary.CreateSplit(content, content, TradeSkillFrame)
  -- Market value left-aligned under the recipe name.
  if TradeSkillSkillName then
    summary.market:SetPoint("TOPLEFT", TradeSkillSkillName, "BOTTOMLEFT", 0, -6)
  else
    summary.market:SetPoint("TOPLEFT", content, "TOPLEFT", 50, -26)
  end
  -- Crafting cost on the line of the "Reagents:" label, ending at the right edge of the reagent grid.
  local lastColumn = TradeSkillReagent2 or TradeSkillReagent1
  if lastColumn then
    summary.cost:SetPoint("BOTTOMRIGHT", lastColumn, "TOPRIGHT", 0, 3)
  else
    summary.cost:SetPoint("TOPRIGHT", content, "TOPRIGHT", -5, -80)
  end
  -- Profit on the line of the button, starting at the left edge of the reagent grid.
  local function PlaceProfit()
    local left = TradeSkillReagent1 and TradeSkillReagent1:GetLeft()
    local buttonLeft = addButton:GetLeft()
    summary.profit:ClearAllPoints()
    if left and buttonLeft then
      summary.profit:SetPoint("LEFT", addButton, "LEFT", left - buttonLeft + 2, 0)
    else
      summary.profit:SetPoint("RIGHT", addButton, "LEFT", -8, 0)
    end
  end

  local function Update()
    PlaceProfit()
    local recipe = ShoppingList.ReadClassicRecipe()
    summary.SetResult(recipe and #recipe.reagents > 0 and RecipeCost.Calculate(recipe) or nil)
  end
  costUpdaters[#costUpdaters + 1] = function()
    if TradeSkillFrame:IsVisible() then
      Update()
    end
  end
  if TradeSkillFrame_SetSelection then
    hooksecurefunc("TradeSkillFrame_SetSelection", Update)
  end
  TradeSkillFrame:HookScript("OnShow", Update)
end

-- Retail puts the button next to the create buttons. The page or its buttons may not exist when the
-- frame loads, so it is tried again whenever it is shown.
local function HookRetail()
  if not ProfessionsFrame then
    return
  end
  if not ProfessionsFrame.AMHooked then
    ProfessionsFrame.AMHooked = true
    ProfessionsFrame:HookScript("OnShow", HookRetail)
  end
  local page = ProfessionsFrame.CraftingPage
  if not page or page.AMAddToShoppingList then
    return
  end
  -- Retail: top right of the page. WoW Forever shares the schematic API but not the layout, so there
  -- (and as fallback) it sits above the create button, in the free space at the bottom right.
  local anchor, point, relativePoint, x, y = page, "TOPRIGHT", "TOPRIGHT", -20, -120
  if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
    -- The bottom row is shared with the game's "Track Recipe" checkbox at the right, so the spinner and a short
    -- button start at the left edge of the page's content (the spinner's arrows reach out left of its box), moved
    -- right so the remove button left of the spinner stays inside the content.
    anchor = page.SchematicForm or page
    point, relativePoint, x, y = "BOTTOMLEFT", "BOTTOMLEFT", 137, 12
  end
  local shortLabel = WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE and L["SHOPPING_ADD_SHORT"] or nil
  local spinner
  -- The amount to put on the list: the quantity spinner of the recipes tab, left of the button.
  local function ReadAmount()
    return spinner and math.max(spinner:GetValue() or 1, 1) or 1
  end
  local function GetRecipeInfo()
    local form = page.SchematicForm
    return form and form.GetRecipeInfo and form:GetRecipeInfo()
  end
  local ReadCount = ReadAmount
  page.AMAddToShoppingList = CreateAddButton(page, anchor, point, relativePoint, x, y, function()
    local form = page.SchematicForm
    local info = GetRecipeInfo()
    local recipeId = info and info.recipeID or form and form.recipeSchematic and form.recipeSchematic.recipeID
    return recipeId and ShoppingList.ReadRetailRecipe(recipeId)
  end, ReadCount, function()
    local info = GetRecipeInfo()
    return info and info.name
  end, shortLabel, shortLabel and 100)
  local ok
  ok, spinner = pcall(CreateFrame, "EditBox", nil, page, "NumericInputSpinnerTemplate")
  if ok and spinner then
    spinner:SetSize(40, 20)
    spinner:SetPoint("RIGHT", page.AMAddToShoppingList, "LEFT", -26, 0)
    spinner:SetFrameLevel(page:GetFrameLevel() + 100)
    spinner:SetMinMaxValues(1, 99)
    spinner:SetValue(1)
  else
    spinner = nil
  end

  -- A red x left of the spinner while the selected recipe is on the list.
  local remove = CreateFrame("Button", nil, page, "UIPanelCloseButtonNoScripts")
  remove:SetSize(24, 24)
  remove:SetPoint("RIGHT", spinner or page.AMAddToShoppingList, "LEFT", shortLabel and -30 or -28, 0)
  remove:SetFrameLevel(page:GetFrameLevel() + 100)
  local function ReadRecipeId()
    local form = page.SchematicForm
    local info = GetRecipeInfo()
    return info and info.recipeID or form and form.recipeSchematic and form.recipeSchematic.recipeID
  end
  remove:SetScript("OnClick", function()
    local recipeId = ReadRecipeId()
    local info = GetRecipeInfo()
    if recipeId and ShoppingList.HasRecipe(recipeId) then
      ShoppingList.RemoveRecipeById(recipeId)
      AM.Print(L["SHOPPING_REMOVED"]:format(info and info.name or ""))
    end
  end)
  remove:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["SHOPPING_REMOVE_FROM_LIST"], 1, 1, 1)
    GameTooltip:Show()
  end)
  remove:SetScript("OnLeave", GameTooltip_Hide)
  page.AMRemoveFromShoppingList = remove
  removeUpdaters[#removeUpdaters + 1] = function()
    local recipeId = page:IsVisible() and ReadRecipeId()
    remove:SetShown(recipeId and ShoppingList.HasRecipe(recipeId) or false)
  end

  SetupRetailCost(page)
  local form = page.SchematicForm
  if form then
    if form.Init then
      hooksecurefunc(form, "Init", ProfessionsFrameModule.UpdateRemove)
    end
    form:HookScript("OnShow", ProfessionsFrameModule.UpdateRemove)
  end
  ProfessionsFrameModule.UpdateRemove()
end

-- Classic puts it above the "Create All" button of the TradeSkill frame.
local function HookClassic()
  if not TradeSkillFrame or TradeSkillFrame.AMAddToShoppingList then
    return
  end
  local anchor, point, relativePoint, x = TradeSkillCreateAllButton or TradeSkillFrame, "BOTTOMLEFT", "TOPLEFT", 0
  -- Classic: the frame is narrower, so the button sits at the right, above the close button.
  if WOW_PROJECT_MISTS_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC and TradeSkillCancelButton then
    anchor, point, relativePoint, x = TradeSkillCancelButton, "BOTTOMRIGHT", "TOPRIGHT", -6
  end
  TradeSkillFrame.AMAddToShoppingList = CreateAddButton(TradeSkillFrame, anchor, point, relativePoint, x, 4,
    ShoppingList.ReadClassicRecipe, function()
      return TradeSkillInputBox and math.max(TradeSkillInputBox:GetNumber(), 1) or 1
    end, function()
      return (GetTradeSkillInfo(GetTradeSkillSelectionIndex()))
    end)
  SetupClassicCost(TradeSkillFrame.AMAddToShoppingList)

  -- A red x left of the button while the selected recipe is on the list.
  local remove = CreateFrame("Button", nil, TradeSkillFrame, "UIPanelCloseButtonNoScripts")
  remove:SetSize(24, 24)
  remove:SetPoint("RIGHT", TradeSkillFrame.AMAddToShoppingList, "LEFT", 4, 0)
  remove:SetFrameLevel(TradeSkillFrame:GetFrameLevel() + 100)
  remove:SetScript("OnClick", function()
    local recipe = ShoppingList.ReadClassicRecipe()
    if recipe and ShoppingList.HasRecipe(recipe.id) then
      ShoppingList.RemoveRecipeById(recipe.id)
      AM.Print(L["SHOPPING_REMOVED"]:format(recipe.name))
    end
  end)
  remove:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["SHOPPING_REMOVE_FROM_LIST"], 1, 1, 1)
    GameTooltip:Show()
  end)
  remove:SetScript("OnLeave", GameTooltip_Hide)
  removeUpdaters[#removeUpdaters + 1] = function()
    local recipe = TradeSkillFrame:IsVisible() and ShoppingList.ReadClassicRecipe()
    remove:SetShown(recipe and ShoppingList.HasRecipe(recipe.id) or false)
  end
  if TradeSkillFrame_SetSelection then
    hooksecurefunc("TradeSkillFrame_SetSelection", ProfessionsFrameModule.UpdateRemove)
  end
  TradeSkillFrame:HookScript("OnShow", ProfessionsFrameModule.UpdateRemove)
  ProfessionsFrameModule.UpdateRemove()
end

if ShoppingList.IsSupported() then
  local loader = CreateFrame("Frame")
  loader:RegisterEvent("ADDON_LOADED")
  loader:RegisterEvent("PLAYER_LOGIN")
  loader:SetScript("OnEvent", function()
    if ShoppingList.IsRetail() then
      HookRetail()
    else
      HookClassic()
    end
  end)
end
