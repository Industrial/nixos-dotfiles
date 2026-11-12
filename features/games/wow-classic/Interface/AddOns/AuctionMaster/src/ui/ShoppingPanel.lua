local addonName, AM = ...
local L = AM.L

-- The panel on the Buy tab of the auction house: a panel beside it (see Attachment.lua) that slides out while the
-- game's buy view is shown and our own window is not. It has two tabs: the shopping list, which shows the list of the
-- crafter selected (see ShoppingList.lua and ShoppingRows.lua) with the button that searches the next missing
-- ingredient, and the bargains (see BargainsPanel.lua). The panel is closed with its close button until the buy view
-- is entered the next time.
AM.ShoppingPanel = {}
local ShoppingPanel = AM.ShoppingPanel
local ShoppingList = AM.ShoppingList
local Rows = AM.ShoppingRows
local Widgets = AM.Widgets
local UI = AM.Theme.ui

local WIDTH = 320
local PADDING = 8
local GAP = 6
local FOOTER_HEIGHT = 22
local FOOTER_PAD = 0 -- below the footer: as in the auction house, the buttons fill the narrow strip below the list
local SEARCH_WIDTH = 130
local TAB_HEIGHT = 24

local ui
local installed = false
local dismissed = false -- closed by the player, until the buy view is entered again
local shownGuid -- crafter of the list shown ("all" for all lists), the list is scrolled to the top when it changes
local refreshPending = false

-- The buy views of the game (browsing, an item, a commodity). Not the token, there is nothing to buy with a list.
local function IsBuyMode()
  local house = AuctionHouseFrame
  local modes = AuctionHouseFrameDisplayMode
  if not (house and house:IsShown() and house.GetDisplayMode and modes) then
    return false
  end
  local mode = house:GetDisplayMode()
  return mode ~= nil and (mode == modes.Buy or mode == modes.ItemBuy or mode == modes.CommoditiesBuy)
end

local function HasAnyList()
  for _, crafter in ipairs(ShoppingList.GetCrafters()) do
    if crafter.count > 0 then
      return true
    end
  end
  return false
end

-- The tab shown is kept account-wide: "list" or "bargains". Without a choice the list is shown if there is one.
local function GetTab()
  local tab = AM.Database.GetGlobalObject("bargainsPanel").tab
  if tab then
    return tab
  end
  return HasAnyList() and "list" or "bargains"
end

-- Searches the item after the one searched last, in the order of the list: the intermediate products, then the
-- ingredients (the first one at the start and after the last one). Ingredients are searched for the amount still
-- missing.
local function SearchNext()
  local model = ui.model
  if not model then
    return
  end
  local targets = {}
  for _, recipe in ipairs(model.intermediates) do
    if recipe.outputItemId then
      targets[#targets + 1] = { itemId = recipe.outputItemId, quantity = recipe.missing }
    end
  end
  for _, item in ipairs(model.needed) do
    targets[#targets + 1] = { itemId = item.itemId, quantity = math.max(1, item.need - item.have) }
  end
  if #targets == 0 then
    return
  end
  local index = 1
  for i, target in ipairs(targets) do
    if target.itemId == ShoppingList.GetSearchedItem() then
      index = i % #targets + 1
    end
  end
  ShoppingList.SearchItem(targets[index].itemId, targets[index].quantity)
end

local function Refresh()
  local lists = ShoppingList.GetShownLists()
  local model = ShoppingList.BuildCombinedModel(lists)
  ui.model = model
  ui.bar.Update(lists)
  local items = Rows.BuildRecipeItems(model, true)
  for _, item in ipairs(Rows.BuildLineItems(model)) do
    items[#items + 1] = item
  end
  ui.list.SetItems(items)
  local shown = ShoppingList.GetFilter() or "all"
  if shown ~= shownGuid then
    shownGuid = shown
    ui.list.ScrollToTop()
  end
  ui.toBuy:SetText(Widgets.Color(UI.gold, L["SHOPPING_TO_BUY"]) .. " "
    .. (model.toBuy > 0 and AM.FormatMoney(model.toBuy) or "--"))
  ui.search:SetEnabled(#model.needed > 0)
end

local function SelectTab(tab)
  AM.Database.GetGlobalObject("bargainsPanel").tab = tab
  ShoppingPanel.Update()
end

-- A tab of the strip on top: gold text and an ember line below it while it is the one shown.
local function CreateTab(parent, label, tab)
  local button = CreateFrame("Button", nil, parent)
  button:SetHeight(TAB_HEIGHT)
  button.text = Widgets.CreateText(button, "GameFontNormal", "CENTER")
  button.text:SetPoint("CENTER", 0, 1)
  button.text:SetText(label)
  button:SetWidth(button.text:GetStringWidth() + 24)
  button.line = button:CreateTexture(nil, "ARTWORK")
  button.line:SetPoint("BOTTOMLEFT")
  button.line:SetPoint("BOTTOMRIGHT")
  button.line:SetHeight(2)
  button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
  button:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
  button:SetScript("OnClick", function()
    SelectTab(tab)
  end)
  function button.SetSelected(selected)
    button.line:SetColorTexture(unpack(selected and UI.emberStart or { 0, 0, 0, 0 }))
    if selected then
      button.text:SetTextColor(1, 0.82, 0)
    else
      button.text:SetTextColor(0.89, 0.86, 0.84)
    end
  end
  return button
end

local function Create()
  ui = {}
  ui.attachment = AM.Attachment.Create(L["SHOPPING_TITLE"], WIDTH, function()
    dismissed = true
    ShoppingPanel.Update()
  end, nil, function()
    dismissed = false
    ShoppingPanel.Update()
  end, true)
  local body = ui.attachment.body

  ui.listTab = CreateTab(body, L["SHOPPING_TITLE"], "list")
  ui.listTab:SetPoint("TOPLEFT", PADDING, -PADDING)
  ui.bargainsTab = CreateTab(body, L["BARGAINS_TITLE"], "bargains")
  ui.bargainsTab:SetPoint("LEFT", ui.listTab, "RIGHT", 0, 0)

  -- a thin line across the full width, so the ember line of the selected tab sits on it
  local baseline = body:CreateTexture(nil, "ARTWORK")
  baseline:SetColorTexture(unpack(UI.border))
  baseline:SetHeight(1)
  baseline:SetPoint("TOPLEFT", 0, -(PADDING + TAB_HEIGHT - 1))
  baseline:SetPoint("TOPRIGHT", 0, -(PADDING + TAB_HEIGHT - 1))

  -- the contents of the tabs, one below the strip
  local content = CreateFrame("Frame", nil, body)
  content:SetPoint("TOPLEFT", 0, -(PADDING + TAB_HEIGHT))
  content:SetPoint("BOTTOMRIGHT")
  ui.listView = CreateFrame("Frame", nil, content)
  ui.listView:SetAllPoints()
  ui.bargainsView = CreateFrame("Frame", nil, content)
  ui.bargainsView:SetAllPoints()
  AM.BargainsPanel.Create(ui.bargainsView)
  body = ui.listView

  ui.bar = Rows.CreateCrafterBar(body)
  ui.bar:SetPoint("TOPLEFT", PADDING, -PADDING)
  ui.bar:SetPoint("TOPRIGHT", -PADDING, -PADDING)

  -- the total of what is still to buy and the button that searches the next ingredient
  ui.search = Widgets.CreateButton(body, L["SHOPPING_SEARCH_NEXT"], true, SearchNext)
  ui.search:ClearAllPoints()
  ui.search:SetPoint("BOTTOMRIGHT", -PADDING, FOOTER_PAD - 1)
  ui.search:SetSize(SEARCH_WIDTH, FOOTER_HEIGHT - 2)
  ui.toBuy = Widgets.CreateText(body, "GameFontHighlightSmall")
  ui.toBuy:SetPoint("LEFT", body, "BOTTOMLEFT", PADDING, FOOTER_PAD + FOOTER_HEIGHT / 2 - 2)
  ui.toBuy:SetPoint("RIGHT", ui.search, "LEFT", -GAP, 0)
  ui.toBuy:SetJustifyH("LEFT")

  ui.list = AM.Attachment.CreateList(body, PADDING + Rows.CRAFTER_BAR_HEIGHT + GAP, FOOTER_PAD + FOOTER_HEIGHT,
    Rows.Create, Rows.Setup)

  ui.attachment.frame:SetScript("OnHide", function()
    ui.bar.listMenu:Hide()
  end)
end

-- Shows or hides the panel as the situation asks and redraws it while it is shown. Cheap enough to be called on every
-- change that might matter.
function ShoppingPanel.Update()
  if not AuctionHouseFrame then
    return
  end
  local buy = IsBuyMode()
  if not buy then
    dismissed = false
  end
  local wanted = buy and not dismissed and not AM.MainWindow.IsShown()
  if wanted and not ui then
    Create()
  end
  if not ui then
    return
  end
  ui.attachment.SetShown(wanted)
  ui.attachment.SetHandle(buy and dismissed and not AM.MainWindow.IsShown())
  if wanted then
    ui.attachment.Place()
    local tab = GetTab()
    ui.listTab.SetSelected(tab == "list")
    ui.bargainsTab.SetSelected(tab == "bargains")
    ui.listView:SetShown(tab == "list")
    ui.bargainsView:SetShown(tab == "bargains")
    ui.attachment.SetTitle(tab == "list" and L["SHOPPING_TITLE"] or L["BARGAINS_TITLE"])
    if tab == "list" then
      Refresh()
    else
      AM.BargainsPanel.Update()
    end
  end
end

-- Item names and bags change in bursts, so redraw once for all of them.
local function UpdateSoon()
  if refreshPending or not ui or not ui.attachment.IsWanted() then
    return
  end
  refreshPending = true
  C_Timer.After(0.2, function()
    refreshPending = false
    ShoppingPanel.Update()
  end)
end

-- The auction house is load on demand: hooked the first time it opens.
local function Install()
  if installed or not AuctionHouseFrame then
    return
  end
  installed = true
  if AuctionHouseFrame.SetDisplayMode then
    hooksecurefunc(AuctionHouseFrame, "SetDisplayMode", ShoppingPanel.Update)
  end
  AuctionHouseFrame:HookScript("OnShow", function()
    -- no half slid panel from the last time
    if ui then
      ui.attachment.Sync()
    end
    ShoppingPanel.Update()
  end)
  AuctionHouseFrame:HookScript("OnHide", function()
    dismissed = false
    if ui then
      ui.attachment.SetShown(false)
      ui.attachment.Hide()
    end
  end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:SetScript("OnEvent", function(_, event)
  if event == "AUCTION_HOUSE_SHOW" then
    Install()
    -- the game shows its frame and sets the buy view around this event, the hooks above catch the later ones
    C_Timer.After(0, ShoppingPanel.Update)
  elseif event == "GET_ITEM_INFO_RECEIVED" and AM.Scan.IsRunning() then
    -- the full scan makes the client load the data of thousands of items: the names are drawn once it is done
    return
  else
    UpdateSoon()
  end
end)

-- A scan, a search or a setting changed the prices; a scan or a deleted character changed the crafters.
AM.Events.Register("PRICES_CHANGED", ShoppingPanel.Update)
AM.Events.Register("CRAFTERS_CHANGED", ShoppingPanel.Update)
-- A rule changed or something was found; the full scan running or ended changes its button.
AM.Events.Register("BARGAINS_CHANGED", ShoppingPanel.Update)
AM.Events.Register("SCAN_CHANGED", ShoppingPanel.Update)
AM.Events.Register("BARGAIN_SCAN_CHANGED", ShoppingPanel.Update)
-- Our own window covers the buy view of the game.
AM.Events.Register("MAIN_WINDOW_VISIBILITY", ShoppingPanel.Update)
