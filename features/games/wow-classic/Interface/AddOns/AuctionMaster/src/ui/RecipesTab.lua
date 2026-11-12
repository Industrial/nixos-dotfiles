local addonName, AM = ...
local L = AM.L

-- The "Recipes" view of the main window: every recipe the characters of the faction know with cost, value
-- and profit at the prices of the latest scan, an advice what to do with it, and the details of the
-- selected recipe, which are an attachment beside the auction house. The data comes from AM.RecipeList. The filters and the sort order are kept in the
-- global object "mainWindow".
local Widgets = AM.Widgets
local UI = AM.Theme.ui
local WHITE = "Interface\\Buttons\\WHITE8X8"

local ROW_HEIGHT = AM.Native.ROW_HEIGHT -- as in the lists of the auction house
local DETAIL_WIDTH = 278
local MENU_MAX_HEIGHT = 400 -- of a dropdown menu before it scrolls
-- Columns from the right edge of a row: width of each. The name takes up the rest.
local COLUMN_ORDER = { "inAH", "profit", "market", "lowest", "cost", "crafter" }
-- wide enough for prices in the font of the auction house's rows (14 pt)
local COLUMN_WIDTH = { inAH = 44, profit = 100, market = 96, lowest = 96, cost = 90, crafter = 90 }
local COLUMN_GAP = 6
local COLUMN_PADDING = 8
local SORT_KEYS = { cost = "COL_COST", lowest = "COL_LOWEST", market = "COL_MARKET", profit = "COL_PROFIT", inAH = "COL_IN_AH" }

local ADVICE_COLOR = { craft = UI.gold, low = UI.muted, loss = UI.loss, none = UI.muted }
-- Fill and border of the advice box, by meaning: green when crafting pays, red on a loss, neutral otherwise.
local ADVICE_BOX = {
  craft = { { 0.09, 0.15, 0.10, 1 }, { 0.18, 0.42, 0.23, 1 } },
  loss = { { 0.16, 0.08, 0.08, 1 }, { 0.48, 0.16, 0.16, 1 } },
}
local ADVICE_TEXT ={ craft = "ADVICE_CRAFT", low = "ADVICE_LOW", loss = "ADVICE_LOSS", none = "ADVICE_NONE" }
local SOURCE_TEXT = { auction = "SRC_AUCTION", vendor = "SRC_VENDOR", crafted = "SRC_CRAFTED" }

local panel
local entries, characters, professions, builtVersion = {}, {}, {}, -1
local visible = {}
local selectedKey
local closedKey -- the recipe whose details were closed last, to open them again with the handle
local quantities = {} -- per entry key
local flash
local ui = {}

local function GetSettings()
  return AM.Database.GetGlobalObject("mainWindow")
end

-- On/off filters that are on until the user switches them off (saved as false then).
local FILTER_DEFAULT_ON = { hideRare = true }

local function IsFilterOn(settings, key)
  local value = settings[key]
  if value == nil then
    return FILTER_DEFAULT_ON[key] or false
  end
  return value
end

-- Redraws the view shown (RecipeList has been invalidated by its own listener, which registered earlier).
local function RefreshWindow()
  AM.MainWindow.Refresh()
end
AM.Events.Register("PRICES_CHANGED", RefreshWindow)
AM.Events.Register("CRAFTERS_CHANGED", RefreshWindow)

local function EnsureBuilt()
  if builtVersion ~= AM.RecipeList.version then
    builtVersion = AM.RecipeList.version
    entries, characters, professions = AM.RecipeList.Build()
  end
end

local function Muted(text)
  return Widgets.Color(UI.muted, text)
end

local function Money(copper)
  return copper and AM.FormatMoney(copper) or Muted("--")
end

local function SignedMoney(copper)
  if not copper then
    return Muted("--")
  elseif copper < 0 then
    return Widgets.Color(UI.loss, "-" .. AM.FormatMoney(-copper))
  end
  return Widgets.Color(UI.gain, "+" .. AM.FormatMoney(copper))
end

local function GetQuality(quality)
  return ITEM_QUALITY_COLORS[quality or 1] or ITEM_QUALITY_COLORS[1]
end

local function ShowItemTooltip(owner, itemId)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetHyperlink("item:" .. itemId)
  GameTooltip:Show()
end

-- Visible entries ------------------------------------------------------------------------------

local function Compare(a, b)
  local settings = GetSettings()
  local key, direction = settings.sortKey or "profit", settings.sortDir or -1
  local x, y = a[key], b[key]
  if x ~= y then
    if x == nil then
      return false
    elseif y == nil then
      return true
    end
    return (x < y) == (direction > 0)
  end
  if a.profit ~= b.profit then
    if a.profit == nil then
      return false
    elseif b.profit == nil then
      return true
    end
    return a.profit > b.profit
  end
  return a.key < b.key
end

local function Filter()
  local settings = GetSettings()
  local query = ui.query or ""
  visible = {}
  for _, entry in ipairs(entries) do
    if (not settings.who or entry.guid == settings.who)
      and (not settings.profession or entry.skillLine == settings.profession)
      and (query == "" or (entry.name and entry.name:lower():find(query, 1, true)))
      and (not IsFilterOn(settings, "hideLoss") or entry.advice ~= "loss")
      and (not IsFilterOn(settings, "hideRare") or not entry.rare) then
      visible[#visible + 1] = entry
    end
  end
  table.sort(visible, Compare)
  local found
  for _, entry in ipairs(visible) do
    found = found or (entry.key == selectedKey and entry)
  end
  selectedKey = found and found.key or nil
end

local function GetSelected()
  for _, entry in ipairs(visible) do
    if entry.key == selectedKey then
      return entry
    end
  end
  return nil
end

-- The recipes to craft, each once even if several characters know it.
local Refresh

-- Puts the entry on the shopping list of its crafter (in the quantity chosen in the detail panel) and selects it,
-- so the confirmation shows up there.
local function AddEntry(entry)
  local quantity = quantities[entry.key] or 1
  AM.ShoppingList.AddRecipe(AM.RecipeList.ToShoppingRecipe(entry), quantity, entry.guid)
  selectedKey = entry.key
  quantities[entry.key] = 1
  flash = { key = entry.key, text = L["DETAIL_ADDED"]:format(quantity) }
  Refresh()
  C_Timer.After(4, function()
    if flash and flash.key == entry.key then
      flash = nil
      if panel:IsVisible() then
        Refresh()
      end
    end
  end)
end

-- List ---------------------------------------------------------------------------------------

local function CreateRow(parent)
  local Native = AM.Native
  local row = CreateFrame("Button", nil, parent)
  Native.StyleRow(row)
  row.icon = Native.CreateItemIcon(row)
  row.icon:SetPoint("LEFT", 8, 0)
  row.name = Widgets.CreateText(row, Native.RowFont())
  row.name:SetWordWrap(false)
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.cells = {}
  local right = COLUMN_PADDING
  for _, column in ipairs(COLUMN_ORDER) do
    local cell = Widgets.CreateText(row, Native.RowFont(), column == "crafter" and "LEFT" or "RIGHT")
    cell:SetWordWrap(false)
    cell:SetWidth(COLUMN_WIDTH[column])
    cell:SetPoint("RIGHT", row, "RIGHT", -right, 0)
    row.cells[column] = cell
    right = right + COLUMN_WIDTH[column] + COLUMN_GAP
  end
  row.name:SetPoint("RIGHT", row, "RIGHT", -right, 0)
  row:SetScript("OnClick", function(self)
    -- a second click on the row closes the details again
    selectedKey = selectedKey ~= self.entry.key and self.entry.key or nil
    Refresh()
  end)
  row.hover = Widgets.CreateItemHover(row, function(self)
    ShowItemTooltip(self.icon, self.entry.itemId)
  end, GameTooltip_Hide)
  return row
end

local function SetupRow(row, item, index)
  local entry = item.entry
  row.entry = entry
  AM.Native.SetRowState(row, index, entry.key == selectedKey)
  row.icon:SetTexture(entry.icon)
  local color = GetQuality(entry.quality)
  row.name:SetTextColor(color.r, color.g, color.b)
  row.name:SetText(entry.name or "...")
  row.hover.Fit(row.icon, row.name)
  local cells = row.cells
  cells.crafter:SetText(Widgets.Color(UI.crafter, entry.crafter))
  cells.cost:SetText(Money(entry.cost))
  cells.lowest:SetText(Money(entry.lowest))
  cells.market:SetText(Money(entry.market))
  cells.profit:SetText(SignedMoney(entry.profit))
  cells.inAH:SetText(entry.inAH .. "x")
end

local function UpdateHeaderMarks()
  local settings = GetSettings()
  local direction = settings.sortDir or -1
  for key, button in pairs(ui.sortButtons) do
    AM.Native.SetSortArrow(button, (settings.sortKey or "profit") == key, direction > 0)
  end
end

local function CreateListPanel()
  local Native = AM.Native
  local native = Native.CreateListPanel(panel)
  native.frame:SetPoint("TOPLEFT", 16, -52)
  native.frame:SetPoint("BOTTOMRIGHT", -16, 16)
  local header = native.header

  -- Headers touch each other like the ones of the auction house: each takes the gap to its neighbour. The name
  -- header takes what the columns leave free. The list sits inside the panel's border, the headers do not.
  local inset = Native.PANEL_INSET + Native.ScrollGutter() -- the list's border and the room of its scroll bar
  local recipeTitle = Native.CreateHeaderButton(header, L["COL_RECIPE"], false)
  recipeTitle:SetPoint("LEFT")
  recipeTitle:SetHeight(Native.HEADER_HEIGHT)
  ui.sortButtons = {}
  local right = COLUMN_PADDING
  for _, column in ipairs(COLUMN_ORDER) do
    local width = COLUMN_WIDTH[column]
    local sortable = SORT_KEYS[column]
    local button = Native.CreateHeaderButton(header, L[sortable or "COL_CRAFTER"], sortable ~= nil)
    button:SetSize(width + COLUMN_GAP, Native.HEADER_HEIGHT)
    button:SetPoint("RIGHT", header, "RIGHT", -(right - COLUMN_GAP / 2) - inset, 0)
    if sortable then
      button:SetScript("OnClick", function()
        local settings = GetSettings()
        if (settings.sortKey or "profit") == column then
          settings.sortDir = -(settings.sortDir or -1)
        else
          settings.sortKey, settings.sortDir = column, -1
        end
        Refresh()
      end)
      ui.sortButtons[column] = button
    end
    right = right + width + COLUMN_GAP
  end
  recipeTitle:SetPoint("RIGHT", header, "RIGHT", -(right - COLUMN_GAP / 2) - inset, 0)

  ui.list = Widgets.CreateList(native.body, CreateRow, SetupRow)
  ui.list:SetAllPoints(native.body)

  ui.empty = Widgets.CreateText(native.body, "GameFontDisableSmall")
  ui.empty:SetPoint("TOPLEFT", 12, -12)
  ui.empty:SetPoint("TOPRIGHT", -12, -12)
  ui.empty:SetWordWrap(true)
end

-- Filters ---------------------------------------------------------------------------

local CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

-- The text of a dropdown choice: icon, label and, in the menu, the number of recipes behind it.
local function ChoiceText(choice, withCount)
  local text = choice.label
  if choice.icon then
    local c = choice.iconCoords
    local icon = c and ("|T%s:16:16:0:0:256:256:%d:%d:%d:%d|t "):format(choice.icon, c[1] * 256, c[2] * 256,
      c[3] * 256, c[4] * 256) or ("|T%s:16|t "):format(choice.icon)
    text = icon .. text
  end
  if withCount and choice.count then
    text = text .. " |cff9d9d9d" .. choice.count .. "|r"
  end
  return text
end

-- A dropdown of the game (WowStyle1DropdownTemplate) with a radio menu. SetChoices takes { value, label, count,
-- icon, iconCoords } entries (the first one, with a nil value, stands for "all") and the selected value; onSelect
-- gets the value picked. dropdown.button is the frame to place.
local function CreateDropdown(width, onSelect)
  local dropdown = { choices = {} }
  local button = CreateFrame("DropdownButton", nil, ui.filters, "WowStyle1DropdownTemplate")
  button:SetWidth(width)
  button:SetSelectionTranslator(function(selection)
    return ChoiceText(selection.data, false)
  end)
  button:SetupMenu(function(_, root)
    for _, choice in ipairs(dropdown.choices) do
      root:CreateRadio(ChoiceText(choice, true), function()
        return choice.value == dropdown.selected
      end, function()
        onSelect(choice.value)
      end, choice)
    end
    root:SetScrollMode(MENU_MAX_HEIGHT)
  end)
  dropdown.button = button

  function dropdown.SetChoices(choices, selected)
    dropdown.choices, dropdown.selected = choices, selected
    button:GenerateMenu()
  end
  return dropdown
end

-- Profession and character dropdowns. A value that has no recipes any more cannot stay selected.
local function UpdateDropdowns()
  local settings = GetSettings()
  if not ui.professionDropdown then
    ui.professionDropdown = CreateDropdown(150, function(value)
      GetSettings().profession = value
      Refresh()
    end)
    ui.professionDropdown.button:SetPoint("LEFT", ui.search, "RIGHT", 12, 0)
    ui.characterDropdown = CreateDropdown(150, function(value)
      GetSettings().who = value
      Refresh()
    end)
    ui.characterDropdown.button:SetPoint("LEFT", ui.professionDropdown.button, "RIGHT", 8, 0)
    ui.charactersButton = AM.CharactersWindow.CreateButton(ui.filters)
    ui.charactersButton:SetPoint("LEFT", ui.characterDropdown.button, "RIGHT", 0, 0)
  end

  local choices, found = { { label = L["RECIPES_ALL_PROFESSIONS"], count = #entries } }, false
  for _, profession in ipairs(professions) do
    choices[#choices + 1] = { value = profession.skillLine, label = profession.name, icon = profession.icon,
      count = profession.count }
    found = found or profession.skillLine == settings.profession
  end
  settings.profession = found and settings.profession or nil
  ui.professionDropdown.SetChoices(choices, settings.profession)

  -- the characters that know recipes of the selected profession, with the number of those
  local counts, total = {}, 0
  for _, entry in ipairs(entries) do
    if not settings.profession or entry.skillLine == settings.profession then
      counts[entry.guid] = (counts[entry.guid] or 0) + 1
      total = total + 1
    end
  end
  choices, found = { { label = L["RECIPES_ALL"], count = total } }, false
  for _, character in ipairs(characters) do
    if counts[character.guid] then
      local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[character.class]
      choices[#choices + 1] = { value = character.guid, label = Widgets.Color(UI.crafter, character.name),
        count = counts[character.guid], icon = coords and CLASS_ICONS or nil, iconCoords = coords }
      found = found or character.guid == settings.who
    end
  end
  table.sort(choices, function(a, b)
    if (a.value == nil) ~= (b.value == nil) then
      return a.value == nil
    elseif a.count ~= b.count then
      return a.count > b.count
    end
    return a.label < b.label
  end)
  settings.who = found and settings.who or nil
  ui.characterDropdown.SetChoices(choices, settings.who)
end

-- The on/off filters, saved by key in the settings.
local TOGGLE_FILTERS = {
  { key = "hideLoss", label = "RECIPES_HIDE_LOSSES" },
  { key = "hideRare", label = "RECIPES_HIDE_RARE" },
}

-- A filter dropdown at the right end of the filter bar with a checkbox per TOGGLE_FILTERS entry. The menu stays open
-- while toggling. The button shows how many filters are on.
local function CreateFilterMenu()
  local button = CreateFrame("DropdownButton", nil, ui.filters, "WowStyle1FilterDropdownTemplate")
  button:SetWidth(110)
  button:SetPoint("RIGHT", 0, 0)
  button:SetupMenu(function(_, root)
    for _, filter in ipairs(TOGGLE_FILTERS) do
      root:CreateCheckbox(L[filter.label], function()
        return IsFilterOn(GetSettings(), filter.key)
      end, function()
        local settings = GetSettings()
        settings[filter.key] = not IsFilterOn(settings, filter.key)
        Refresh()
      end)
    end
  end)

  -- called by Refresh: the button text follows the settings
  function ui.UpdateFilterMenu()
    local settings, active = GetSettings(), 0
    for _, filter in ipairs(TOGGLE_FILTERS) do
      active = active + (IsFilterOn(settings, filter.key) and 1 or 0)
    end
    button:SetText(active > 0 and (L["RECIPES_FILTERS"] .. " (" .. active .. ")") or L["RECIPES_FILTERS"])
  end
end

local function CreateFilters()
  ui.filters =CreateFrame("Frame", nil, panel)
  ui.filters:SetPoint("TOPLEFT", 16, -16)
  ui.filters:SetPoint("TOPRIGHT", -16, -16)
  ui.filters:SetHeight(24)

  local search = CreateFrame("EditBox", nil, ui.filters, "SearchBoxTemplate")
  ui.search = search
  search:SetSize(200, 22)
  search:SetPoint("LEFT", AM.MainWindow.PortraitInset(), 0)
  search:SetAutoFocus(false)
  if search.Instructions then
    search.Instructions:SetText(L["RECIPES_SEARCH"])
  end
  -- HookScript: the template's own scripts show the hint and the clear button
  search:HookScript("OnTextChanged", function(self)
    ui.query = self:GetText():lower()
    if panel:IsVisible() then
      Refresh()
    end
  end)

  CreateFilterMenu()
end

-- Details of the selected recipe --------------------------------------------------------------------

local function GetOwned(itemId)
  return (C_Item.GetItemCount or GetItemCount)(itemId)
end

-- The rows of the detail list for an entry.
local function BuildDetailItems(entry)
  local result = entry.result
  local items = {}
  local function Line(label, value)
    items[#items + 1] = { height = 18, kind = "line", label = label, value = value }
  end
  local function Header(text)
    items[#items + 1] = { height = 24, kind = "header", label = text }
  end

  Line(L["DETAIL_SELLS"], Money(result.gross or result.value))
  if result.fee then
    Line(L["DETAIL_CUT"], Widgets.Color("ffffff", "-") .. Money(result.fee))
  end
  Line(L["DETAIL_COST"], Widgets.Color("ffffff", "-") .. Money(result.cost) .. (result.incomplete and Muted(" ?") or ""))
  items[#items + 1] = { height = 7, kind = "separator" }
  Line(L["DETAIL_PROFIT"], SignedMoney(result.profit))
  local margin = entry.margin
  Line(L["DETAIL_MARGIN"], margin
    and Widgets.Color(margin >= 0 and UI.gain or UI.loss, (margin >= 0 and "+" or "-") .. math.floor(math.abs(margin) * 100 + 0.5) .. "%")
    or Muted("--"))

  local itemDbKey = AM.ItemDbKey.ForCrafted(entry.itemId)
  local lowPrice = itemDbKey and AM.ItemStore.Get(itemDbKey)
  local market = itemDbKey and AM.ItemStore.GetMarketPrice(itemDbKey)
  Header(L["DETAIL_MARKET"])
  Line(L["DETAIL_LOWEST"], Money(lowPrice))
  Line(L["DETAIL_MARKET_VALUE"], Money(market and market.price))
  Line(L["DETAIL_IN_AH"], entry.inAH .. "x")

  Header(L["DETAIL_REAGENTS"])
  for _, reagent in ipairs(result.reagents) do
    local name = C_Item.GetItemInfo(reagent.itemId)
    local source = reagent.source and L[SOURCE_TEXT[reagent.source]] or Muted("--")
    local owned = GetOwned(reagent.itemId)
    if owned > 0 then
      source = source .. " · " .. L["SRC_BAGS"]:format(owned)
    end
    items[#items + 1] = { height = 32, kind = "reagent", itemId = reagent.itemId,
      label = (name or "...") .. " |cffffffffx" .. reagent.quantity .. "|r", sub = source, value = Money(reagent.price),
      icon = select(5, C_Item.GetItemInfoInstant(reagent.itemId)) }
  end
  return items
end

local function AdvicePhrase(entry)
  local advice = entry.advice
  if advice == "craft" then
    return L["ADVICE_WHY_CRAFT"]:format(math.floor(entry.margin * 100 + 0.5))
  elseif advice == "low" then
    return L["ADVICE_WHY_LOW"]:format(math.floor(entry.margin * 100 + 0.5))
  end
  return L[advice == "loss" and "ADVICE_WHY_LOSS" or "ADVICE_WHY_NONE"]
end

local function CreateDetailRow(parent)
  local row = CreateFrame("Button", nil, parent)
  -- the content keeps clear of the edges of the sunken panel
  local content = CreateFrame("Frame", nil, row)
  content:SetPoint("TOPLEFT", 8, 0)
  content:SetPoint("BOTTOMRIGHT", -8, 0)
  row.content = content
  row.label = Widgets.CreateText(content, "GameFontNormal")
  row.value = Widgets.CreateText(content, "GameFontHighlight", "RIGHT")
  row.value:SetPoint("RIGHT")
  row.name = Widgets.CreateText(content, "GameFontHighlight")
  row.name:SetWordWrap(false)
  row.sub = Widgets.CreateText(content, "GameFontDisableSmall")
  row.sub:SetWordWrap(false)
  row.icon = content:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(22, 22)
  row.icon:SetPoint("LEFT")
  row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  row.line = content:CreateTexture(nil, "BORDER")
  row.line:SetHeight(1)
  row.line:SetPoint("BOTTOMLEFT", 0, 2)
  row.line:SetPoint("BOTTOMRIGHT", 0, 2)
  row.hover = Widgets.CreateItemHover(row, function(self)
    ShowItemTooltip(self.icon, self.itemId)
  end, GameTooltip_Hide)
  row.hover:SetAllPoints(row.icon)
  row:SetScript("OnClick", function(self)
    if self.itemId and self.kind == "reagent" then
      AM.ShoppingList.SearchItemName(self.itemId)
    end
  end)

  return row
end

local function SetupDetailRow(row, item)
  row.itemId = item.itemId
  row.kind = item.kind
  row.label:ClearAllPoints()
  row.label:SetShown(item.kind == "line" or item.kind == "header")
  row.value:SetShown(item.kind == "line" or item.kind == "reagent")
  row.name:SetShown(item.kind == "reagent")
  row.sub:SetShown(item.kind == "reagent")
  row.icon:SetShown(item.kind == "reagent")
  row.line:SetShown(item.kind == "header" or item.kind == "separator")
  row.hover:SetShown(item.kind == "reagent")
  if item.kind == "line" then
    row.label:SetPoint("LEFT")
    row.label:SetText(item.label)
    row.value:SetText(item.value)
  elseif item.kind == "header" then
    row.label:SetPoint("BOTTOMLEFT", 0, 6)
    row.label:SetText(item.label)
    row.line:SetColorTexture(unpack(UI.buttonBorder))
  elseif item.kind == "separator" then
    row.line:SetColorTexture(0.17, 0.16, 0.18)
  else
    row.icon:SetTexture(item.icon)
    row.value:SetText(item.value)
    row.name:ClearAllPoints()
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 0)
    row.name:SetPoint("RIGHT", row.content, "RIGHT", -84, 0)
    row.name:SetText(item.label)
    row.sub:ClearAllPoints()
    row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 0)
    row.sub:SetPoint("RIGHT", row.content, "RIGHT", -84, 0)
    row.sub:SetText(item.sub)
  end
end

-- The quantity spinner of the details was changed by the player (not by UpdateDetail setting it).
local function OnQuantityChanged(value)
  local entry = GetSelected()
  if entry and not ui.settingQuantity then
    quantities[entry.key] = value
    flash = nil
    Refresh()
  end
end

local function AddSelected()
  local entry = GetSelected()
  if entry then
    AddEntry(entry)
  end
end

local function CreateDetail()
  -- beside the auction house: the list keeps the whole width of the window. The close button closes the details.
  ui.attachment = AM.Attachment.Create(L["DETAIL_TITLE"], DETAIL_WIDTH, function()
    closedKey = selectedKey
    selectedKey = nil
    Refresh()
  end, nil, function()
    selectedKey = closedKey
    Refresh()
  end, true)
  local body = ui.attachment.body
  ui.detail = body
  -- the recipe sits in a sunken panel like the list below it
  local header = AM.Native.CreateInset(body, true)
  header:SetPoint("TOPLEFT", 8, -6)
  header:SetPoint("TOPRIGHT", -8, -6)
  header:SetHeight(58)
  body.icon = header:CreateTexture(nil, "ARTWORK")
  body.icon:SetSize(40, 40)
  body.icon:SetPoint("LEFT", 9, 0)
  body.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  body.name = Widgets.CreateText(header, "GameFontNormalLarge")
  body.name:SetPoint("TOPLEFT", body.icon, "TOPRIGHT", 10, -2)
  body.name:SetPoint("RIGHT", -9, 0)
  body.name:SetWordWrap(false)
  body.crafter = Widgets.CreateText(header, "GameFontHighlightSmall")
  body.crafter:SetPoint("BOTTOMLEFT", body.icon, "BOTTOMRIGHT", 10, 2)

  -- the recommendation stays in view above the scrolling lines
  local advice = Widgets.CreateBox(body, UI.header, UI.buttonBorder)
  advice:SetPoint("TOPLEFT", 8, -70)
  advice:SetPoint("TOPRIGHT", -8, -70)
  advice:SetHeight(62)
  advice.title = Widgets.CreateText(advice, "GameFontNormal")
  advice.title:SetPoint("TOPLEFT", 10, -8)
  advice.why = Widgets.CreateText(advice, "GameFontHighlight")
  advice.why:SetPoint("TOPLEFT", 10, -28)
  advice.why:SetPoint("BOTTOMRIGHT", -10, 8)
  advice.why:SetWordWrap(true)
  advice.why:SetJustifyV("TOP")
  body.advice = advice

  local FOOTER = 42 -- the quantity above the button, close to the strip below the list of the auction house
  body.list = AM.Attachment.CreateList(body, 70 + 62 + 8, FOOTER, CreateDetailRow, SetupDetailRow)

  local footer = CreateFrame("Frame", nil, body)
  footer:SetPoint("BOTTOMLEFT")
  footer:SetPoint("BOTTOMRIGHT")
  footer:SetHeight(FOOTER)

  local quantityLabel = Widgets.CreateText(footer, "GameFontNormal")
  quantityLabel:SetPoint("TOPLEFT", 8, -5)
  quantityLabel:SetText(L["DETAIL_QUANTITY"])
  -- the game's quantity spinner: input with the arrows left and right of it
  local spinner = CreateFrame("EditBox", nil, footer, "NumericInputSpinnerTemplate")
  spinner:SetSize(40, 20)
  spinner:SetPoint("TOPRIGHT", -46, -2) -- its arrow ends where the list does
  spinner:SetOnValueChangedCallback(function(_, value)
    OnQuantityChanged(value)
  end)
  ui.settingQuantity = true
  spinner:SetMinMaxValues(1, 99)
  ui.settingQuantity = false
  footer.quantity = spinner

  local add = Widgets.CreateButton(footer, L["SHOPPING_ADD_TO_LIST"], true, AddSelected)
  add:ClearAllPoints()
  add:SetPoint("BOTTOMLEFT", 8, -1)
  add:SetPoint("BOTTOMRIGHT", -8, -1)
  add:SetHeight(20) -- the strip below the list is as narrow as the auction house's
  footer.flash = Widgets.CreateText(footer, "GameFontHighlightSmall")
  footer.flash:SetPoint("TOPLEFT", 70, -5)
  body.footer = footer
end

local function UpdateDetail()
  local entry = GetSelected()
  ui.attachment.SetShown(entry ~= nil)
  if entry then
    closedKey = nil
  else
    local closed = false
    for _, candidate in ipairs(visible) do
      closed = closed or candidate.key == closedKey
    end
    ui.attachment.SetHandle(closed)
    return
  end
  ui.attachment.SetHandle(false)
  ui.attachment.Place()
  local body = ui.detail
  body.icon:SetTexture(entry.icon)
  local color = GetQuality(entry.quality)
  body.name:SetTextColor(color.r, color.g, color.b)
  body.name:SetText(entry.name or "...")
  body.crafter:SetText(Widgets.Color(UI.crafter, entry.crafter))
  local advice = body.advice
  advice.title:SetText(L["DETAIL_ADVICE"] .. " " .. Widgets.Color(ADVICE_COLOR[entry.advice], L[ADVICE_TEXT[entry.advice]]))
  advice.why:SetText(AdvicePhrase(entry))
  local colors = ADVICE_BOX[entry.advice]
  advice:SetBackdropColor(unpack(colors and colors[1] or UI.header))
  advice:SetBackdropBorderColor(unpack(colors and colors[2] or UI.buttonBorder))
  body.list.SetItems(BuildDetailItems(entry))
  ui.settingQuantity = true
  body.footer.quantity:SetValue(quantities[entry.key] or 1)
  ui.settingQuantity = false
  body.footer.flash:SetText(flash and flash.key == entry.key and (Widgets.Color(UI.gain, flash.text)) or "")
end

-- Tab ----------------------------------------------------------------------------------------------

function Refresh()
  EnsureBuilt()
  UpdateDropdowns() -- first, it drops a selection that does not exist any more
  Filter()
  local items = {}
  for _, entry in ipairs(visible) do
    items[#items + 1] = { height = ROW_HEIGHT, entry = entry }
  end
  ui.list.SetItems(items)
  ui.empty:SetText(#entries == 0 and L["RECIPES_EMPTY"] or (#visible == 0 and L["RECIPES_NONE"] or ""))
  ui.UpdateFilterMenu()
  UpdateHeaderMarks()
  UpdateDetail()
end

local function Create(parent)
  panel = CreateFrame("Frame", nil, parent)
  -- no half slid details after the panel was hidden in the middle of a slide
  panel:SetScript("OnShow", function()
    ui.attachment.Sync()
  end)
  panel:SetScript("OnHide", function()
    ui.attachment.Hide()
  end)
  CreateFilters()
  CreateListPanel()
  CreateDetail()

  -- Names and sell prices of items arrive late. Recipes of other items are of no interest.
  local pending = false
  panel:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  panel:SetScript("OnEvent", function(_, _, itemId, success)
    if pending or success == false or not AM.Database.GetFactionObject("recipes")[itemId] then
      return
    end
    pending = true
    C_Timer.After(0.5, function()
      pending = false
      AM.RecipeList.Invalidate()
      AM.MainWindow.Refresh()
    end)
  end)
  return panel
end

AM.MainWindow.RegisterTab({
  id = "recipes",
  label = "MAIN_TAB_RECIPES",
  icon = "Interface\\Icons\\INV_Misc_Book_09",
  create = Create,
  refresh = Refresh,
  count = function()
    EnsureBuilt()
    return #entries
  end,
})
