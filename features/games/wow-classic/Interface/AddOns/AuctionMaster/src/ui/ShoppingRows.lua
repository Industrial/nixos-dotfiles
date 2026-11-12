local addonName, AM = ...
local L = AM.L

-- The parts of the shopping list of the Buy tab (see ShoppingPanel.lua): the rows of the recipes and of the
-- reagents and the bar with the crafter. The data is in professions/ShoppingList.lua.
AM.ShoppingRows = {}
local Rows = AM.ShoppingRows
local Widgets = AM.Widgets
local ShoppingList = AM.ShoppingList
local UI = AM.Theme.ui

local WHITE = "Interface\\Buttons\\WHITE8X8"
local CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local READY_COLOR = { 0.1, 1, 0.1 }
local CHECK_ICON = "|TInterface\\Buttons\\UI-CheckBox-Check:14:14:0:0|t "
local COUNT_WIDTH = 48
local STEP_WIDTH = 24

Rows.HEIGHT = { recipe = 26, header = 24, message = 40, line = 24, priceLine = 38 }

-- Icon of the class of a character, a question mark if the class is not known.
function Rows.SetClassIcon(texture, class)
  local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
  if coords then
    texture:SetTexture(CLASS_ICONS)
    texture:SetTexCoord(unpack(coords))
  else
    texture:SetTexture(UNKNOWN_ICON)
    texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  end
end

-- Rows ---------------------------------------------------------------------------------------------

-- The arrow of the game's quantity spinner, kind is "PrevPage" or "NextPage".
local function CreateArrowButton(row, kind, tooltip, onClick)
  local button = CreateFrame("Button", nil, row)
  button:SetSize(23, 22)
  local path = "Interface\\Buttons\\UI-SpellbookIcon-" .. kind
  button:SetNormalTexture(path .. "-Up")
  button:SetPushedTexture(path .. "-Down")
  button:SetDisabledTexture(path .. "-Disabled")
  button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  button:SetScript("OnClick", onClick)
  Widgets.SetTooltip(button, tooltip)
  return button
end

-- Creates a row, to be filled by Rows.Setup.
function Rows.Create(parent)
  local row = CreateFrame("Button", nil, parent)
  row.background = row:CreateTexture(nil, "BACKGROUND")
  row.background:SetAllPoints()
  row.edge = row:CreateTexture(nil, "BORDER")
  row.edge:SetPoint("BOTTOMLEFT")
  row.edge:SetPoint("BOTTOMRIGHT")
  row.edge:SetHeight(1)
  row.edge:SetColorTexture(unpack(UI.buttonBorder))
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  row.name = Widgets.CreateText(row, "GameFontHighlightSmall")
  row.name:SetWordWrap(false)
  row.sub = Widgets.CreateText(row, "GameFontHighlightSmall")
  -- WoW has no strikethrough text, so a line is drawn over the name of collected items
  row.strike = row:CreateTexture(nil, "OVERLAY")
  row.strike:SetHeight(1)
  row.count = Widgets.CreateText(row, "GameFontHighlightSmall", "RIGHT")
  row.price = Widgets.CreateText(row, "GameFontHighlightSmall", "RIGHT")
  row.bar = Widgets.CreateProgressBar(row, 6)
  row.toggle = row:CreateTexture(nil, "ARTWORK")
  row.toggle:SetSize(12, 12)

  row.remove = Widgets.CreateRemoveButton(row, L["SHOPPING_REMOVE"], function()
    ShoppingList.RemoveRecipe(row.recipe)
  end)
  row.inc = CreateArrowButton(row, "NextPage", L["SHOPPING_INCREASE"], function()
    ShoppingList.ChangeQuantity(row.recipe, IsShiftKeyDown() and 5 or 1)
  end)
  row.dec = CreateArrowButton(row, "PrevPage", L["SHOPPING_DECREASE"], function()
    ShoppingList.ChangeQuantity(row.recipe, IsShiftKeyDown() and -5 or -1)
  end)
  row.step = Widgets.CreateText(row, "GameFontHighlightSmall", "CENTER")
  row.step:SetWidth(STEP_WIDTH)

  row:SetScript("OnClick", function(self)
    if self.onClick then
      self.onClick()
    end
  end)
  row.hover = Widgets.CreateItemHover(row, function(self)
    -- the amount still to buy, so the tooltip shows the values of that stack as the one of a bag item does
    GameTooltip.AM_Count = self.itemId and self.stackCount or 1
    if self.itemId then
      GameTooltip:SetOwner(self.icon, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink("item:" .. self.itemId)
      for _, line in ipairs(self.tipLines or {}) do
        GameTooltip:AddDoubleLine(line[1], line[2], 1, 0.82, 0, 1, 1, 1)
      end
      GameTooltip:Show()
    elseif self.recipe and self.recipe.outputItemId then
      -- the crafted item, so the item tooltip of the addon is added
      GameTooltip:SetOwner(self.icon, "ANCHOR_RIGHT")
      GameTooltip.supportsItemComparison = false -- no equipped item next to it, restored on leave
      GameTooltip:SetHyperlink("item:" .. self.recipe.outputItemId)
      if self.recipe.crafterName then
        GameTooltip:AddLine(Widgets.Color(UI.crafter, self.recipe.crafterName))
      end
      GameTooltip:Show()
    end
  end, function()
    GameTooltip.AM_Count = nil
    GameTooltip.supportsItemComparison = true
    GameTooltip_Hide()
  end)
  return row
end

local function ResetRow(row)
  row.icon:Hide()
  row.icon:ClearAllPoints()
  row.name:ClearAllPoints()
  row.sub:Hide()
  row.sub:ClearAllPoints()
  row.count:Hide()
  row.price:Hide()
  row.strike:Hide()
  row.edge:Hide()
  row.bar:Hide()
  row.toggle:Hide()
  row.remove:Hide()
  row.inc:Hide()
  row.dec:Hide()
  row.step:Hide()
  row.onClick = nil
  row.itemId = nil
  row.tipLines = nil
  row.stackCount = nil
  row.recipe = nil
  row.hover:Hide()
  row:EnableMouse(false)
end

local function SetupHeader(row, item)
  row.background:SetColorTexture(unpack(UI.sectionHeader))
  row.edge:Show()
  row.name:SetFontObject(GameFontNormalSmall)
  row.name:SetTextColor(1, 0.82, 0)
  row.name:SetText(item.text)
  if item.onClick then
    row.toggle:SetTexture(item.expanded and "Interface\\Buttons\\UI-MinusButton-Up"
      or "Interface\\Buttons\\UI-PlusButton-Up")
    row.toggle:SetPoint("LEFT", 8, 0)
    row.toggle:Show()
    row.name:SetPoint("LEFT", 24, 0)
    row.onClick = item.onClick
    row:EnableMouse(true)
  else
    row.name:SetPoint("LEFT", 12, 0)
  end
end

local function SetupMessage(row, item)
  row.background:SetColorTexture(0, 0, 0, 0)
  row.name:SetFontObject(GameFontHighlightSmall)
  row.name:SetTextColor(unpack(item.color))
  row.name:SetText(item.text)
  if item.sub then
    row.name:SetPoint("TOPLEFT", 12, -8)
    row.name:SetPoint("RIGHT", -12, 0)
    row.sub:SetText(item.sub)
    row.sub:SetTextColor(0.89, 0.86, 0.84)
    row.sub:SetPoint("TOPLEFT", 12, -24)
    row.sub:Show()
  else
    row.name:SetPoint("LEFT", 12, 0)
    row.name:SetPoint("RIGHT", -12, 0)
  end
end

-- Money with a sign and in the color of a gain or a loss.
local function FormatProfit(copper)
  if copper < 0 then
    return Widgets.Color(UI.loss, "-" .. AM.FormatMoney(-copper))
  end
  return Widgets.Color(UI.gain, "+" .. AM.FormatMoney(copper))
end
Rows.FormatProfit = FormatProfit

local function SetupRecipe(row, item)
  local recipe = item.recipe
  row.recipe = recipe
  -- opens the profession page of the crafted item if the auction house is closed, else searches it
  row.onClick = function()
    if recipe.intermediate and recipe.outputItemId then
      -- selected like an ingredient, so the row is highlighted
      ShoppingList.ClickItem(recipe.outputItemId, recipe.missing)
    else
      ShoppingList.ClickRecipeIcon(recipe)
    end
  end
  row:EnableMouse(true)
  if item.active then
    row.background:SetColorTexture(unpack(UI.selected))
  else
    row.background:SetColorTexture(1, 1, 1, item.stripe and 0.02 or 0)
  end
  row.icon:SetSize(18, 18)
  row.icon:SetPoint("LEFT", 12, 0)
  row.icon:SetTexture(recipe.icon)
  row.icon:SetDesaturated(false)
  row.icon:SetAlpha(1)
  row.icon:Show()
  row.name:SetFontObject(GameFontHighlightSmall)
  if recipe.ready then
    row.name:SetTextColor(unpack(READY_COLOR))
  else
    row.name:SetTextColor(0.89, 0.86, 0.84)
  end
  row.name:SetText((recipe.ready and CHECK_ICON or "") .. recipe.name)
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
  row.name:SetPoint("RIGHT", recipe.intermediate and -(8 + 28) or -108, 0)
  if recipe.outputItemId then
    row.hover:Show()
    row.hover.Fit(row.icon)
  end
  if recipe.intermediate then
    -- crafted on the way, not on the list itself: only the number of crafts
    row.count:ClearAllPoints()
    row.count:SetPoint("RIGHT", -8, 0)
    row.count:SetWidth(28)
    row.count:SetTextColor(1, 1, 1)
    row.count:SetText("×" .. recipe.qty)
    row.count:Show()
    return
  end
  row.remove:ClearAllPoints()
  row.remove:SetPoint("RIGHT", -6, 0)
  row.remove:Show()
  row.inc:ClearAllPoints()
  row.inc:SetPoint("RIGHT", -30, 0)
  row.inc:Show()
  row.step:ClearAllPoints()
  row.step:SetPoint("RIGHT", -54, 0)
  row.step:SetText(recipe.qty)
  row.step:Show()
  row.dec:ClearAllPoints()
  row.dec:SetPoint("RIGHT", -78, 0)
  row.dec:SetEnabled(recipe.qty > 1)
  row.dec:Show()
end

-- "Vendor <price>   Auction <price>" for one item, only with the prices that are known, nil if there is none.
local function GetPriceText(itemId)
  local vendor = AM.MerchantScanner.GetPrice(itemId) or AM.VendorItems.GetPrice(itemId)
  local itemDbKey = AM.ItemDbKey.ForItem(itemId)
  local lowest = itemDbKey and AM.ItemStore.Get(itemDbKey)
  if not vendor and not lowest then
    return nil
  end
  local parts = {}
  if vendor then
    parts[#parts + 1] = L["SHOPPING_PRICE_VENDOR"]:format(AM.FormatMoney(vendor))
  end
  if lowest then
    parts[#parts + 1] = L["SHOPPING_PRICE_AUCTION"]:format(AM.FormatMoney(lowest))
  end
  return table.concat(parts, "    ")
end

-- A reagent: icon, name and what is there of what is needed, and below the name the prices of an item that is still
-- missing. Collected ones are grey with a check mark, the one searched last is highlighted.
local function SetupLine(row, item)
  local reagent, done = item.item, item.done
  row.itemId = reagent.itemId
  row.onClick = function()
    -- what is still missing, not the whole need
    ShoppingList.ClickItem(reagent.itemId, math.max(1, reagent.need - reagent.have))
  end
  row:EnableMouse(true)
  if item.active then
    row.background:SetColorTexture(unpack(UI.selected))
  else
    row.background:SetColorTexture(1, 1, 1, item.stripe and 0.025 or 0)
  end
  row.icon:SetSize(22, 22)
  row.icon:SetPoint("LEFT", 8, 0)
  local name, quality, icon = ShoppingList.GetItemDetails(reagent.itemId)
  row.icon:SetTexture(icon)
  row.icon:SetDesaturated(done)
  row.icon:SetAlpha(done and 0.5 or 1)
  row.icon:Show()
  local color = done and { r = 0.55, g = 0.55, b = 0.55 } or ITEM_QUALITY_COLORS[quality or 1]
  row.name:SetFontObject(GameFontHighlightSmall)
  row.name:SetTextColor(color.r, color.g, color.b)
  row.name:SetText((done and CHECK_ICON or ShoppingList.GetSourceIcon(reagent, 16)) .. (name or "..."))
  local prices = not done and GetPriceText(reagent.itemId)
  if prices then
    -- second line: what one item costs at the vendor and at the auction house, to compare them
    row.name:SetPoint("TOPLEFT", 38, -5)
    row.name:SetPoint("TOPRIGHT", -(8 + COUNT_WIDTH), -5)
    row.sub:SetText(prices)
    row.sub:SetTextColor(0.62, 0.62, 0.62)
    row.sub:SetPoint("TOPLEFT", 38, -20)
    row.sub:Show()
  else
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.name:SetPoint("RIGHT", -(8 + COUNT_WIDTH), 0)
  end
  row.count:ClearAllPoints()
  row.count:SetPoint("RIGHT", -8, 0)
  row.count:SetWidth(COUNT_WIDTH)
  row.count:SetText(reagent.have .. "/" .. reagent.need)
  if done then
    row.count:SetTextColor(0.55, 0.55, 0.55)
  else
    row.count:SetTextColor(1, 1, 1)
  end
  row.count:Show()
  row.stackCount = math.max(1, reagent.need - reagent.have)
  local hint = reagent.craftHint
  if hint and not done then
    row.tipLines = row.tipLines or {}
    row.tipLines[#row.tipLines + 1] = { Widgets.Color(UI.crafter, string.format(L["SHOPPING_CRAFT_HINT"],
      ShoppingList.GetCrafter(hint.guid).name, math.floor(hint.saving * 100 + 0.5))), "" }
  end
  row.hover:Show()
  row.hover.Fit(row.icon)
end

-- Fills a row of Rows.Create for the item of Widgets.CreateList, as made by the Build functions below.
function Rows.Setup(row, item)
  ResetRow(row)
  if item.type == "header" then
    SetupHeader(row, item)
  elseif item.type == "recipe" then
    SetupRecipe(row, item)
  elseif item.type == "line" then
    SetupLine(row, item)
  else
    SetupMessage(row, item)
  end
end

-- The items of the recipes, below a header with their number.
-- With collapsible the header folds the recipes away (kept in the view state).
function Rows.BuildRecipeItems(model, collapsible)
  local height = Rows.HEIGHT
  local data = ShoppingList.GetView()
  local items = { { type = "header", height = height.header,
    text = L["SHOPPING_RECIPES"] .. " (" .. #model.recipes .. ")" } }
  if collapsible then
    items[1].expanded = not data.hideRecipes
    items[1].onClick = function()
      data.hideRecipes = not data.hideRecipes
      ShoppingList.Refresh()
    end
    if data.hideRecipes then
      return items
    end
  end
  if #model.recipes == 0 then
    items[#items + 1] = { type = "message", height = height.message, text = L["SHOPPING_NO_RECIPES"],
      color = { 0.56, 0.56, 0.56 } }
  end
  for i, recipe in ipairs(model.recipes) do
    items[#items + 1] = { type = "recipe", height = height.recipe, recipe = recipe, stripe = i % 2 == 0 }
  end
  if #model.intermediates > 0 then
    items[#items + 1] = { type = "header", height = height.header,
      text = L["SHOPPING_INTERMEDIATE"] .. " (" .. #model.intermediates .. ")" }
    for i, recipe in ipairs(model.intermediates) do
      items[#items + 1] = { type = "recipe", height = height.recipe, recipe = recipe, stripe = i % 2 == 0,
        active = recipe.outputItemId ~= nil and recipe.outputItemId == ShoppingList.GetSearchedItem() }
    end
  end
  return items
end

-- The reagents as single lines: the ones still needed below a header, then the collected ones.
function Rows.BuildLineItems(model)
  local height = Rows.HEIGHT
  local searched = ShoppingList.GetSearchedItem()
  local items = {}
  if #model.needed > 0 then
    items[1] = { type = "header", height = height.header, text = L["SHOPPING_NEEDED"] .. " (" .. #model.needed .. ")" }
  end
  for i, reagent in ipairs(model.needed) do
    items[#items + 1] = { type = "line", height = GetPriceText(reagent.itemId) and height.priceLine or height.line,
      item = reagent, stripe = i % 2 == 0, active = reagent.itemId == searched }
  end
  if #model.items > 0 and #model.needed == 0 then
    items[#items + 1] = { type = "message", height = height.message, text = L["SHOPPING_ALL_DONE"],
      sub = L["SHOPPING_ALL_DONE_HINT"]:format(#model.recipes), color = { 1, 0.82, 0 } }
  end
  for i, reagent in ipairs(model.done) do
    items[#items + 1] = { type = "line", height = height.line, item = reagent, stripe = i % 2 == 0, done = true,
      active = reagent.itemId == searched }
  end
  return items
end

-- Crafter bar --------------------------------------------------------------------------------

local function CreateStepButton(parent, label, tooltip, onClick)
  local button = Widgets.CreateIconButton(parent, label, 22, onClick)
  Widgets.SetTooltip(button, tooltip)
  return button
end

-- The text of a crafter in the dropdown: class icon, name and, in the menu, the number of recipes.
local function ChoiceText(choice, withCount)
  local text = choice.label
  local coords = choice.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[choice.class]
  if coords then
    text = ("|T%s:16:16:0:0:256:256:%d:%d:%d:%d|t "):format(CLASS_ICONS, coords[1] * 256, coords[2] * 256,
      coords[3] * 256, coords[4] * 256) .. text
  end
  if withCount then
    text = text .. " |cff9d9d9d" .. choice.count .. "|r"
  end
  return text
end

-- The crafters whose lists are shown on a single line: a dropdown of the game with all lists and one entry per crafter
-- that has recipes (as the one of the recipes view), and a "..." button with the menu of the list ("Clear list").
-- Rows.CRAFTER_BAR_HEIGHT high, the caller sets the width by two anchors. bar.Update(lists) fills it, bar.listMenu is the
-- menu (to be hidden when the view is).
Rows.CRAFTER_BAR_HEIGHT = 26

function Rows.CreateCrafterBar(parent)
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetHeight(Rows.CRAFTER_BAR_HEIGHT)

  local listMenu = Widgets.CreateBox(bar, UI.sunken, UI.border)
  listMenu:SetFrameStrata("FULLSCREEN_DIALOG") -- above the window and the raised levels of its lists
  listMenu:Hide()
  listMenu:SetSize(120, 26)
  bar.listMenu = listMenu

  local more = CreateStepButton(bar, "...", L["SHOPPING_LIST_MENU_TOOLTIP"], function()
    listMenu:SetShown(not listMenu:IsShown())
  end)
  more:SetPoint("RIGHT")
  listMenu:SetPoint("TOPRIGHT", more, "BOTTOMRIGHT", 0, -2)
  local clear = CreateFrame("Button", nil, listMenu)
  clear:SetPoint("TOPLEFT", 1, -1)
  clear:SetPoint("BOTTOMRIGHT", -1, 1)
  clear:SetHighlightTexture(WHITE)
  clear:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
  clear.text = Widgets.CreateText(clear, "GameFontHighlightSmall")
  clear.text:SetPoint("LEFT", 8, 0)
  clear.text:SetText(L["SHOPPING_CLEAR"])
  clear:SetScript("OnClick", function(self)
    listMenu:Hide()
    local lists = self.lists
    if not lists then
      return
    end
    local any = false
    for _, list in ipairs(lists) do
      any = any or #list.recipes > 0
    end
    if any then
      if #lists == 1 then
        StaticPopup_Show("AUCTIONMASTER_CLEAR_LIST", ShoppingList.GetCrafter(lists[1].guid).name, nil, lists)
      else
        StaticPopup_Show("AUCTIONMASTER_CLEAR_ALL_LISTS", nil, nil, lists)
      end
    end
  end)

  local choices, selected = {}, nil
  local dropdown = CreateFrame("DropdownButton", nil, bar, "WowStyle1DropdownTemplate")
  dropdown:SetPoint("LEFT")
  dropdown:SetPoint("RIGHT", more, "LEFT", -4, 0)
  dropdown:SetSelectionTranslator(function(selection)
    return ChoiceText(selection.data, false)
  end)
  dropdown:SetupMenu(function(_, root)
    for _, choice in ipairs(choices) do
      root:CreateRadio(ChoiceText(choice, true), function()
        return choice.value == selected
      end, function()
        ShoppingList.SelectCrafter(choice.value)
      end, choice)
    end
  end)

  function bar.Update(lists)
    selected = ShoppingList.GetFilter()
    choices = { { label = L["RECIPES_ALL"], count = 0 } }
    for _, crafter in ipairs(ShoppingList.GetCrafters()) do
      if crafter.count > 0 then
        choices[1].count = choices[1].count + crafter.count
        choices[#choices + 1] = { value = crafter.guid, label = Widgets.Color(UI.crafter, crafter.name),
          class = crafter.class, count = crafter.count }
      end
    end
    clear.lists = lists
    dropdown:GenerateMenu()
  end
  return bar
end

-- Footer -------------------------------------------------------------------------------------------

StaticPopupDialogs["AUCTIONMASTER_CLEAR_LIST"] = {
  text = "",
  button1 = YES,
  button2 = NO,
  OnAccept = function(_, lists)
    ShoppingList.ClearLists(lists)
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
}

StaticPopupDialogs["AUCTIONMASTER_CLEAR_ALL_LISTS"] = {
  text = "",
  button1 = YES,
  button2 = NO,
  OnAccept = function(_, lists)
    ShoppingList.ClearLists(lists)
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
}

StaticPopupDialogs["AUCTIONMASTER_REMOVE_CRAFTER"] = {
  text = "",
  button1 = YES,
  button2 = NO,
  OnAccept = function(_, guid)
    ShoppingList.RemoveCrafter(guid)
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
}

-- Asks before a character is removed.
function ShoppingList.ConfirmRemoveCrafter(guid)
  StaticPopup_Show("AUCTIONMASTER_REMOVE_CRAFTER", ShoppingList.GetCrafter(guid).name, nil, guid)
end

-- The language is only known once the saved variables are loaded (see AM.Locale).
AM.Locale.OnReady(function()
  StaticPopupDialogs["AUCTIONMASTER_REMOVE_CRAFTER"].text = L["SHOPPING_CRAFTER_REMOVE_CONFIRM"]
  StaticPopupDialogs["AUCTIONMASTER_CLEAR_LIST"].text = L["SHOPPING_CLEAR_CONFIRM"]
  StaticPopupDialogs["AUCTIONMASTER_CLEAR_ALL_LISTS"].text = L["SHOPPING_CLEAR_ALL_CONFIRM"]
end)
