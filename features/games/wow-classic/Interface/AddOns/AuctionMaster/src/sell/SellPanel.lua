local addonName, AM = ...
local L = AM.L

-- The items in your bags on the Sell tab of the auction house: a panel beside it (see Attachment.lua) that slides
-- out while the game's sell view is shown and our own window is not. One row per item (stacks of all bags added up)
-- with what it nets at the auction house after the cut, what the stack is worth and a hint what to do with it:
-- sell it at the auction house, to a vendor, keep it as a reagent of a recipe that pays, or hold it while the
-- auction house pays far less than the market value. Without a recent search of an item (AM.SellScan) nothing is
-- known about it and the hint says to scan. A click puts the item into the game's sell form. Items the game does not let you auction are left out.
AM.SellPanel = {}
local SellPanel = AM.SellPanel
local Widgets = AM.Widgets
local Native = AM.Native
local UI = AM.Theme.ui

local WIDTH = 360
local PADDING = 8
local GAP = 6
local ROW_HEIGHT = 34
local ICON_SIZE = 26
local TOTAL_WIDTH = 100
local FOOTER_HEIGHT = 22
local FOOTER_PAD = 0 -- below the footer: as in the auction house, the buttons fill the narrow strip below the list
local SELL_PRICE_INDEX = 11
local HOLD_BELOW = 0.7 -- the price to post at is less than this share of the market value: hold the item
local SCAN_PADDING = 10
local LIST_TOP = 50 -- where the list starts below the top of the panel: level with the table of the auction house's Create Auction view
local KEEP_MIN_RECIPES = 5 -- a reagent of this many recipes is not advised to a vendor, even where none of them pays
local DEPOSIT_DURATION = 2 -- of the game's durations (12, 24, 48 hours) the middle one

local TIP_COLOR = { ah = UI.gain, vendor = UI.gold, disenchant = UI.gain, keep = UI.crafter, hold = UI.warn, none = UI.muted, scan = UI.muted, ignored = UI.muted }
-- Order of the hints in the list, items without one come last.
local TIP_ORDER = { "ah", "disenchant", "vendor", "hold", "keep", "none", "scan", "ignored" }
local TIP_RANK = {}
for rank, tip in ipairs(TIP_ORDER) do
  TIP_RANK[tip] = rank
end
local TIP_TEXT = { ah = "SELL_TIP_AH", vendor = "SELL_TIP_VENDOR", disenchant = "SELL_TIP_DISENCHANT", keep = "SELL_TIP_KEEP", hold = "SELL_TIP_HOLD", none = "SELL_TIP_NONE", scan = "SELL_TIP_SCAN", ignored = "SELL_TIP_IGNORED" }

local ui
local installed = false
local dismissed = false -- closed by the player, until the sell view is entered again
local refreshPending = false
local settling = false -- the full scan just ended
local rowOrder -- itemDbKey -> place in the list as last sorted
local entries = {} -- as of the last redraw, what the scan button searches
local keepVersion, keepItems = -1, {} -- reagents of recipes that pay, as of the recipe list version
local loggedRows = {} -- itemDbKey -> the debug log line last written for its row

-- The sell views of the game (an item, a commodity). Not the token, it is not in the bags.
local function IsSellMode()
  local house = AuctionHouseFrame
  local modes = AuctionHouseFrameDisplayMode
  if not (house and house:IsShown() and house.GetDisplayMode and modes) then
    return false
  end
  local mode = house:GetDisplayMode()
  return mode ~= nil and (mode == modes.ItemSell or mode == modes.CommoditiesSell)
end

-- The key of the item in the game's sell form, nil if there is none.
local function GetPostedItemDbKey()
  local house = AuctionHouseFrame
  for _, name in ipairs({ "ItemSellFrame", "CommoditiesSellFrame" }) do
    local frame = house[name]
    local location = frame and frame.GetItem and frame:GetItem()
    if location and location:IsValid() then
      return (AM.ItemDbKey.FromLocation(location))
    end
  end
end

-- The items that are reagents of recipes one of the characters knows: selling them would be a pity. Maps the item to
-- { payCount, payName, otherCount, otherName, seen }: how many distinct recipes (not one per character) use it that pay
-- off (advice "craft") and that do not, the name of the first of each, and the recipes counted.
local function GetKeepItems()
  if keepVersion ~= AM.RecipeList.version then
    keepVersion = AM.RecipeList.version
    keepItems = {}
    for _, entry in ipairs((AM.RecipeList.Build())) do
      local pays = entry.advice == "craft"
      for _, reagent in ipairs(entry.recipe.reagents) do
        local keep = keepItems[reagent.itemId]
        if not keep then
          keep = { payCount = 0, otherCount = 0, seen = {} }
          keepItems[reagent.itemId] = keep
        end
        if not keep.seen[entry.recipeId] then
          keep.seen[entry.recipeId] = true
          local count, name = pays and "payCount" or "otherCount", pays and "payName" or "otherName"
          keep[count] = keep[count] + 1
          keep[name] = keep[name] or entry.name
        end
      end
    end
  end
  return keepItems
end

-- What the game charges as deposit for the whole stack of the entry for the usual duration, nil if it cannot say.
-- Asking the game keeps this right wherever its deposit differs (e.g. a minimum deposit).
local function GetDeposit(entry)
  local ok, deposit = pcall(function()
    if C_AuctionHouse.GetItemCommodityStatus(entry.location) == Enum.ItemCommodityStatus.Commodity then
      return C_AuctionHouse.CalculateCommodityDeposit(entry.itemId, DEPOSIT_DURATION, entry.count)
    end
    return C_AuctionHouse.CalculateItemDeposit(entry.location, DEPOSIT_DURATION, entry.count)
  end)
  return ok and deposit or nil
end

-- What an item nobody lists is asked for: its market value plus the margin of the settings. Nil without a market value.
function SellPanel.NoCompetitionPrice(itemDbKey)
  local market = AM.ItemStore.GetMarketPrice(itemDbKey)
  return market and math.floor(market.price * (1 + AM.SellSettings.GetNumber("noCompetitionMargin") / 100))
end

-- Fills the entry's net, deposit, auction (what the stack brings at the auction house), total, tip (and keepFor) for
-- the price the item would be posted at. entry needs itemId, itemDbKey, count, location and vendor.
local function Assess(entry, price)
  local market = AM.ItemStore.GetMarketPrice(entry.itemDbKey)
  local underpriced = market and price < market.price * HOLD_BELOW
  local keep = GetKeepItems()
  entry.net = math.floor(price * (1 - AM.RecipeCost.AH_CUT))
  entry.deposit = GetDeposit(entry)
  -- the deposit counts against the auction house: for cheap items (and where the game charges a minimum) it can
  -- eat what the auction brings over the vendor
  local auction = entry.net * entry.count - (entry.deposit or 0)
  entry.auction = auction
  local vendor = entry.vendor * entry.count
  entry.total = math.max(auction, vendor)
  if entry.total <= 0 then
    entry.total = nil
  end
  local reagent = keep[entry.itemId]
  local vendorWins = vendor > 0 and vendor >= auction
  -- what its materials would bring, where a character can disenchant it and enough disenchants of it are known; all
  -- stacks of the item are taken to have the level of the first
  local disenchant = AM.Disenchant.HasDisenchanter()
    and AM.Disenchant.GetNetValue(entry.itemId, C_Item.GetCurrentItemLevel(entry.location))
  entry.disenchant = disenchant and disenchant * entry.count
  if reagent and (reagent.payCount > 0 or (vendorWins and reagent.payCount + reagent.otherCount >= KEEP_MIN_RECIPES)) then
    -- of a recipe that pays; or of several recipes where the vendor would be the advice
    entry.tip = "keep"
    entry.keepFor = reagent
  elseif entry.disenchant and entry.disenchant > math.max(auction, vendor) then
    entry.tip = "disenchant"
    entry.total = entry.disenchant
  elseif vendorWins then
    entry.tip = "vendor"
  elseif underpriced then
    entry.tip = "hold"
  else
    entry.tip = "ah"
  end
end

-- What an assessment worked out, as text for the debug log: the inputs and the hint.
local function Describe(entry, price)
  local market = AM.ItemStore.GetMarketPrice(entry.itemDbKey)
  return ("%s: price %s x%d, vendor %s, net %s, deposit %s, auction %s, market %s, disenchant %s -> %s"):format(
    entry.itemDbKey, tostring(price), entry.count, tostring(entry.vendor), tostring(entry.net), tostring(entry.deposit),
    tostring(entry.auction), tostring(market and market.price), tostring(entry.disenchant), tostring(entry.tip))
end

-- The hint for an item (in the bags, at the location, with the key) that would be posted at the price: "ah", "vendor",
-- "keep" or "hold".
function SellPanel.Advise(itemDbKey, location, price)
  local itemId = AM.ItemDbKey.GetItemId(itemDbKey)
  local entry = { itemId = itemId, itemDbKey = itemDbKey, location = location, count = C_Item.GetStackCount(location) }
  for _, listed in ipairs(entries) do
    if listed.itemDbKey == itemDbKey then
      entry.count = listed.count -- all stacks of the bags, as the list does
    end
  end
  entry.vendor = select(SELL_PRICE_INDEX, C_Item.GetItemInfo(itemId)) or 0
  Assess(entry, price)
  if AM.DebugLog.IsEnabled() then
    AM.DebugLog.Log("advise", "%s", Describe(entry, price))
  end
  return entry.tip
end

-- One entry per item (one itemDbKey: equipment of another level is another item) in the bags that can be put up for
-- auction, sorted by hint (auction house, vendor, keep, none),
-- then by stack value, highest first. An entry is { itemId, itemDbKey, count, location, net (per item after the cut, nil without a price), total (what the
-- stack brings, at the auction house or from the vendor, whichever is more), vendor (per item, 0 if unknown), tip }.
local function BuildEntries()
  local byItem, skipped, entries = {}, {}, {}
  local showIgnored = AM.SellSettings.GetShowIgnored()
  local bags = (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4)
  for bag = 0, bags do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID then
        local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
        local itemDbKey = AM.ItemDbKey.FromLocation(location)
        if not itemDbKey then
          -- the item data is not loaded yet: the item is asked for and shows once it has arrived (ITEM_DATA_LOAD_RESULT)
          C_Item.RequestLoadItemDataByID(info.itemID)
        else
          local entry = byItem[itemDbKey]
          if entry then
            entry.count = entry.count + info.stackCount
          elseif not skipped[itemDbKey] and C_AuctionHouse.IsSellItemValid(location, false) then
            local ignored = AM.SellSettings.IsIgnored(itemDbKey)
            if ignored and not showIgnored then
              skipped[itemDbKey] = true
            else
              entry = {
                itemId = info.itemID, itemDbKey = itemDbKey, count = info.stackCount, location = location, ignored = ignored,
              }
              byItem[itemDbKey] = entry
              entries[#entries + 1] = entry
            end
          end
        end
      end
    end
  end
  for _, entry in ipairs(entries) do
    entry.vendor = select(SELL_PRICE_INDEX, C_Item.GetItemInfo(entry.itemId)) or 0
    -- No advice for an ignored item. Nor where nothing is known: without a recent search of the item the hint says to
    -- scan. Where the search found no auction nothing competes, so the item goes for its market value plus a margin;
    -- without a market value there is no price to name.
    local price = not entry.ignored and AM.ItemSearch.GetSellPrice(entry.itemDbKey)
    if not price and not entry.ignored and AM.SellScan.IsSearched(entry.itemDbKey) then
      price = SellPanel.NoCompetitionPrice(entry.itemDbKey)
    end
    if entry.ignored then
      entry.tip = "ignored"
    elseif price then
      Assess(entry, price)
    else
      entry.tip = AM.SellScan.IsSearched(entry.itemDbKey) and "none" or "scan"
    end
    -- the list is redrawn often: a row is logged when what it shows changed
    if AM.DebugLog.IsEnabled() then
      local text = price and Describe(entry, price) or ("%s: no price -> %s"):format(entry.itemDbKey, entry.tip)
      if loggedRows[entry.itemDbKey] ~= text then
        loggedRows[entry.itemDbKey] = text
        AM.DebugLog.Log("row", "%s", text)
      end
    end
  end
  -- While the scan runs the rows keep their places, so they do not jump around as the hints come in.
  local frozen = AM.SellScan.IsRunning() and rowOrder
  if frozen then
    table.sort(entries, function(a, b)
      local indexA, indexB = frozen[a.itemDbKey] or math.huge, frozen[b.itemDbKey] or math.huge
      if indexA ~= indexB then
        return indexA < indexB
      end
      return a.itemDbKey < b.itemDbKey
    end)
    return entries
  end
  table.sort(entries, function(a, b)
    local rankA, rankB = TIP_RANK[a.tip] or #TIP_ORDER + 1, TIP_RANK[b.tip] or #TIP_ORDER + 1
    if rankA ~= rankB then
      return rankA < rankB
    elseif (a.total == nil) ~= (b.total == nil) then
      return a.total ~= nil
    elseif a.total ~= b.total then
      return a.total > b.total
    end
    return a.itemDbKey < b.itemDbKey
  end)
  rowOrder = {}
  for index, entry in ipairs(entries) do
    rowOrder[entry.itemDbKey] = index
  end
  return entries
end

-- Rows ---------------------------------------------------------------------------------------------

-- Right click on a row: a menu to ignore the item or stop ignoring it. Without the game's menu API (Classic) the click
-- toggles it directly: nothing is lost, the filter shows ignored items again.
function SellPanel.OpenRowMenu(owner, entry)
  local ignored = AM.SellSettings.IsIgnored(entry.itemDbKey)
  local function Toggle()
    AM.SellSettings.SetIgnored(entry.itemDbKey, not ignored)
  end
  if MenuUtil and MenuUtil.CreateContextMenu then
    MenuUtil.CreateContextMenu(owner, function(_, root)
      root:CreateButton(L[ignored and "SELL_UNIGNORE" or "SELL_IGNORE"], Toggle)
    end)
  else
    Toggle()
  end
end

local function CreateRow(parent)
  local row = CreateFrame("Button", nil, parent)
  Native.StyleRow(row)
  row.icon = Native.CreateItemIcon(row)
  row.icon:SetSize(ICON_SIZE, ICON_SIZE)
  row.icon:SetPoint("LEFT", 6, 0)
  if row.icon.border then
    -- the border is drawn for a 14 px icon in a 16 px frame, so it grows with the icon
    local size = math.floor(ICON_SIZE * 16 / 14 + 0.5)
    row.icon.border:SetSize(size, size)
  end
  row.count = Widgets.CreateText(row, "NumberFontNormal", "RIGHT")
  row.count:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", -1, 1)
  row.total = Widgets.CreateText(row, Native.RowFont(), "RIGHT")
  row.total:SetWidth(TOTAL_WIDTH)
  row.total:SetPoint("TOPRIGHT", -8, -3)
  row.name = Widgets.CreateText(row, Native.RowFont())
  row.name:SetWordWrap(false)
  row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 0)
  row.name:SetPoint("RIGHT", row.total, "LEFT", -GAP, 0)
  row.each = Widgets.CreateText(row, "GameFontDisableSmall")
  row.each:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 6, 0)
  row.tip = Widgets.CreateText(row, "GameFontHighlightSmall", "RIGHT")
  row.tip:SetPoint("BOTTOMRIGHT", -8, 3)
  row.each:SetPoint("RIGHT", row.tip, "LEFT", -GAP, 0)
  row.each:SetJustifyH("LEFT")
  row.each:SetWordWrap(false)

  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
      SellPanel.OpenRowMenu(self, self.entry)
      return
    end
    local house = AuctionHouseFrame
    if self.entry and house and house.SetPostItem then
      house:SetPostItem(self.entry.location)
      -- the game offers the one stack selected, the quantity is everything there is of the item
      for _, name in ipairs({ "ItemSellFrame", "CommoditiesSellFrame" }) do
        local frame = house[name]
        local item = frame and frame.GetItem and frame:GetItem()
        if item and item:IsValid() and frame.QuantityInput and frame.QuantityInput:IsShown() then
          local available = C_AuctionHouse.GetAvailablePostCount and C_AuctionHouse.GetAvailablePostCount(item)
          frame.QuantityInput:SetQuantity(available or self.entry.count)
          if frame.UpdatePostState then
            frame:UpdatePostState()
          end
          -- the box was shown in this very frame: without this its text stays scrolled out of view (the game does the same)
          frame.QuantityInput.InputBox:SetCursorPosition(0)
        end
      end
    end
  end)
  row.hover = Widgets.CreateItemHover(row, function(self)
    local entry = self.entry
    -- the whole stack, so the tooltip shows the values of that amount as the one of a bag item does
    GameTooltip.AM_Count = entry.count
    GameTooltip:SetOwner(self.icon, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(C_Item.GetItemLink(entry.location) or ("item:" .. entry.itemId))
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L["SELL_NET"], entry.net and AM.FormatMoney(entry.net) or "--", 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine(L["RECIPE_VENDOR_VALUE"], entry.vendor > 0 and AM.FormatMoney(entry.vendor) or "--",
      1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine(L["SELL_DEPOSIT"], entry.deposit and AM.FormatMoney(entry.deposit) or "--",
      1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["SELL_IGNORE_HINT"], 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
  end, function()
    GameTooltip.AM_Count = nil
    GameTooltip_Hide()
  end)
  -- the value: what it is made of
  row.valueHover = Widgets.CreateItemHover(row, function(self)
    local entry = self.entry
    GameTooltip:SetOwner(self.total, "ANCHOR_LEFT")
    GameTooltip:SetText(L["SELL_VALUE"], 1, 1, 1)
    if entry.auction then
      GameTooltip:AddDoubleLine(L["SELL_VALUE_AH"], AM.FormatMoney(math.max(entry.auction, 0)), 1, 0.82, 0, 1, 1, 1)
      GameTooltip:AddDoubleLine(L["SELL_VALUE_VENDOR"], entry.vendor > 0 and AM.FormatMoney(entry.vendor * entry.count) or "--",
        1, 0.82, 0, 1, 1, 1)
      if entry.disenchant then
        GameTooltip:AddDoubleLine(L["SELL_VALUE_DISENCHANT"], AM.FormatMoney(entry.disenchant), 1, 0.82, 0, 1, 1, 1)
      end
      GameTooltip:AddLine(L["SELL_VALUE_NOTE"], 0.7, 0.7, 0.7, true)
    end
    -- why the hint says what it says
    local reason
    if entry.tip == "keep" then
      local keepFor = entry.keepFor
      if keepFor.payCount == 0 then
        reason = L["SELL_WHY_KEEP_VENDOR"]:format(keepFor.otherCount)
      else
        local others = keepFor.payCount - 1
        reason = others > 0 and L["SELL_WHY_KEEP_MORE"]:format(keepFor.payName, others)
          or L["SELL_WHY_KEEP"]:format(keepFor.payName)
      end
    elseif entry.tip == "hold" then
      reason = L["SELL_WHY_HOLD"]:format(math.floor(HOLD_BELOW * 100))
    elseif entry.tip then
      reason = L["SELL_WHY_" .. strupper(entry.tip)]
    end
    if reason then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(reason, 1, 1, 1, true)
    end
    GameTooltip:Show()
  end, GameTooltip_Hide)
  row.valueHover:ClearAllPoints()
  -- over the value and the hint below it
  row.valueHover:SetPoint("TOPRIGHT", row.total, "TOPRIGHT")
  row.valueHover:SetPoint("BOTTOMLEFT", row.tip, "BOTTOMLEFT", 0, -2)
  return row
end

local function SetupRow(row, item, index)
  local entry = item.entry
  row.entry = entry
  Native.SetRowState(row, index, entry.itemDbKey == item.posted)
  local name, _, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(entry.itemId)
  row.icon:SetTexture(icon or select(5, C_Item.GetItemInfoInstant(entry.itemId)))
  local color = ITEM_QUALITY_COLORS[quality or 1] or ITEM_QUALITY_COLORS[1]
  row.name:SetTextColor(color.r, color.g, color.b)
  row.name:SetText(name or "...")
  -- four digits do not fit on the icon
  row.count:SetText(entry.count >= 1000 and math.floor(entry.count / 1000) .. "k" or entry.count > 1 and entry.count or "")
  row.total:SetText(entry.total and AM.FormatMoney(entry.total) or Widgets.Color(UI.muted, "--"))
  row.each:SetText(entry.net and AM.FormatMoney(entry.net) or Widgets.Color(UI.muted, "--"))
  row.tip:SetText(entry.tip and Widgets.Color(TIP_COLOR[entry.tip], L[TIP_TEXT[entry.tip]]) or "")
  row.hover.Fit(row.icon)
end

-- Panel ----------------------------------------------------------------------------------------------

-- The scan button is active unless there is nothing to scan or the full scan is running, and shows the progress while
-- the scan runs. With every price current it searches all items again.
local function UpdateScanButton()
  local button = ui.scan
  if AM.SellScan.IsRunning() then
    local done, total = AM.SellScan.GetProgress()
    button:SetLabel(L["SELL_SCAN_PROGRESS"]:format(done, total), SCAN_PADDING)
    button:Disable()
    ui.progress:SetMinMaxValues(0, math.max(total, 1))
    ui.progress:SetValue(done)
    ui.progress:Show()
  else
    ui.progress:Hide()
    button:SetLabel(L["SELL_SCAN"], SCAN_PADDING)
    button:SetEnabled(#entries > 0 and not AM.Scan.IsRunning())
  end
end

local function Refresh()
  ui.filter:SetText(AM.SellSettings.GetShowIgnored() and (L["RECIPES_FILTERS"] .. " (1)") or L["RECIPES_FILTERS"])
  -- the full scan keeps the auction house busy: nothing to offer until it is done
  local busy = AM.Scan.IsRunning() or settling
  entries = busy and {} or BuildEntries()
  local posted = GetPostedItemDbKey()
  local items, sum = {}, 0
  for _, entry in ipairs(entries) do
    items[#items + 1] = { height = ROW_HEIGHT, entry = entry, posted = posted }
    sum = sum + (entry.total or 0)
  end
  ui.list.SetItems(items)
  ui.empty:SetText(busy and L["SELL_BUSY"] or #entries == 0 and L["SELL_EMPTY"] or "")
  ui.total:SetText(Widgets.Color(UI.gold, L["SELL_TOTAL"]) .. " " .. (sum > 0 and AM.FormatMoney(sum) or "--"))
  UpdateScanButton()
end

local function Create()
  ui = {}
  ui.attachment = AM.Attachment.Create(L["SELL_TITLE"], WIDTH, function()
    dismissed = true
    SellPanel.Update()
  end, nil, function()
    dismissed = false
    SellPanel.Update()
  end, true)
  local body = ui.attachment.body

  ui.scan = Widgets.CreateButton(body, "", false, function()
    -- searches the items without a current price, all of them once every one has one
    AM.SellScan.Start(entries, AM.SellScan.IsDone(entries))
  end)
  ui.scan:SetPoint("BOTTOMRIGHT", -PADDING, FOOTER_PAD - 1)
  ui.scan:SetHeight(FOOTER_HEIGHT - 2)
  Widgets.SetTooltip(ui.scan, L["SELL_SCAN_TOOLTIP"])

  ui.total = Widgets.CreateText(body, "GameFontHighlightSmall")
  ui.total:SetPoint("LEFT", body, "BOTTOMLEFT", PADDING, FOOTER_PAD + FOOTER_HEIGHT / 2 - 2)
  ui.total:SetPoint("RIGHT", ui.scan, "LEFT", -GAP, 0)
  ui.total:SetJustifyH("LEFT")

  -- along the top of the footer while the scan runs
  ui.progress = Widgets.CreateProgressBar(body, 4, true)
  ui.progress:SetPoint("BOTTOMLEFT", PADDING, FOOTER_PAD + FOOTER_HEIGHT)
  ui.progress:SetPoint("BOTTOMRIGHT", -PADDING, FOOTER_PAD + FOOTER_HEIGHT)
  ui.progress:Hide()

  -- the filter above the list: one checkbox, the button shows when it is on
  local filter = CreateFrame("DropdownButton", nil, body, "WowStyle1FilterDropdownTemplate")
  filter:SetWidth(110)
  filter:SetupMenu(function(_, root)
    root:CreateCheckbox(L["SELL_SHOW_IGNORED"], AM.SellSettings.GetShowIgnored, function()
      AM.SellSettings.SetShowIgnored(not AM.SellSettings.GetShowIgnored())
    end)
  end)
  ui.filter = filter

  local panel
  ui.list, panel = AM.Attachment.CreateList(body, LIST_TOP, FOOTER_PAD + FOOTER_HEIGHT,
    CreateRow, SetupRow)
  filter:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", 0, 2) -- attached to the table
  ui.empty = Widgets.CreateText(panel, "GameFontDisableSmall")
  ui.empty:SetPoint("TOPLEFT", 12, -12)
  ui.empty:SetPoint("TOPRIGHT", -12, -12)
  ui.empty:SetWordWrap(true)
end

-- Shows or hides the panel as the situation asks and redraws it while it is shown. Cheap enough to be called on every
-- change that might matter.
function SellPanel.Update()
  if not AuctionHouseFrame then
    return
  end
  local sell = IsSellMode()
  if not sell then
    dismissed = false
  end
  local wanted = sell and not dismissed and not AM.MainWindow.IsShown()
  if wanted and not ui then
    Create()
  end
  if not ui then
    return
  end
  ui.attachment.SetShown(wanted)
  ui.attachment.SetHandle(sell and dismissed and not AM.MainWindow.IsShown())
  if wanted then
    ui.attachment.Place()
    Refresh()
  end
end

-- Bags and item names change in bursts, so redraw once for all of them.
local function UpdateSoon()
  if refreshPending or not ui or not ui.attachment.IsWanted() then
    return
  end
  refreshPending = true
  -- the full scan makes the client load the data of thousands of items: draw the names less often meanwhile
  C_Timer.After(AM.Scan.IsRunning() and 2 or 0.2, function()
    refreshPending = false
    SellPanel.Update()
  end)
end

-- The auction house is load on demand: hooked the first time it opens.
local function Install()
  if installed or not AuctionHouseFrame then
    return
  end
  installed = true
  if AuctionHouseFrame.SetDisplayMode then
    hooksecurefunc(AuctionHouseFrame, "SetDisplayMode", SellPanel.Update)
  end
  -- the row of the item in the sell form is highlighted
  for _, name in ipairs({ "SetPostItem", "ClearPostItem" }) do
    if AuctionHouseFrame[name] then
      hooksecurefunc(AuctionHouseFrame, name, UpdateSoon)
    end
  end
  AuctionHouseFrame:HookScript("OnShow", function()
    -- no half slid panel from the last time
    if ui then
      ui.attachment.Sync()
    end
    SellPanel.Update()
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
events:RegisterEvent("ITEM_DATA_LOAD_RESULT")
events:SetScript("OnEvent", function(_, event)
  if event == "AUCTION_HOUSE_SHOW" then
    Install()
    -- the game shows its frame and sets the sell view around this event, the hooks above catch the later ones
    C_Timer.After(0, SellPanel.Update)
  else
    UpdateSoon()
  end
end)

-- A scan, a search or a setting changed the prices.
AM.Events.Register("PRICES_CHANGED", UpdateSoon)
-- More disenchants are known, or a character that can disenchant was found.
AM.Events.Register("DISENCHANT_CHANGED", UpdateSoon)
-- Our own window covers the sell view of the game.
AM.Events.Register("MAIN_WINDOW_VISIBILITY", SellPanel.Update)
-- The full scan started or ended.
AM.Events.Register("SCAN_CHANGED", function()
  if not AM.Scan.IsRunning() then
    -- right after the scan the game still reports some bag items as not sellable: the list waits until it has settled
    settling = true
    C_Timer.After(1, function()
      settling = false
      SellPanel.Update()
    end)
  end
  SellPanel.Update()
end)
-- The scan of the items to sell moved on.
AM.Events.Register("SELL_SCAN_CHANGED", function()
  if not (ui and ui.attachment.IsWanted()) then
    return
  end
  if AM.SellScan.IsRunning() then
    UpdateScanButton()
  else
    -- done: the rows are sorted anew
    Refresh()
  end
end)
-- An item was ignored or no longer ignored, or the filter for them changed.
AM.Events.Register("SELL_FILTER_CHANGED", UpdateSoon)
