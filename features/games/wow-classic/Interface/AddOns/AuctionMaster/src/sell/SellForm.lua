local addonName, AM = ...
local L = AM.L

-- Our own sell form, laid over the game's sell view (the form and the list of current auctions beside it) while that
-- view is shown and our own window is not. It looks like the game's form but is ours: AuctionMaster never writes into
-- the game's sell frames, as that taints them, and from there the bags (see doc/taint-issue.md). Posting goes through
-- C_AuctionHouse.PostCommodity / PostItem, the searches through C_AuctionHouse as well.
-- The item comes from a click on a row of SellPanel, from a click on a bag item (the game's own code calls its
-- SetPostItem, which is only hooked here) or from dropping it on the item display. The price is the one we would post
-- at (AM.ItemSearch.PostPrice of the listings, the no-competition price where nobody lists the item) until the player
-- types one or clicks a listing (exactly its price, never undercut).
-- Fires the addon event SELL_FORM_CHANGED("item") when the item changes, ("price") when price or quantity change.
AM.SellForm = {}
local SellForm = AM.SellForm
local Widgets = AM.Widgets
local Native = AM.Native
local UI = AM.Theme.ui

-- The duration the player chose (1-3, the game's index); 0 for none yet: the game's own last choice is used then,
-- read from its setting, never written.
AM.Settings.Define("sellDuration", 0)
-- False while the player uses the game's own sell form (the switch in the sell view), for an item ours cannot sell.
AM.Settings.Define("sellForm", true)

function SellForm.IsEnabled()
  return AM.Settings.Get("sellForm") ~= false
end

-- Layout, from the game's sell view (Blizzard_AuctionHouseFrame.xml, Blizzard_AuctionHouseSellFrame.xml)
local SIDE_INSET = 4 -- the game's views start 4 in from the frame's left and right edge
local TITLE_HEIGHT = 23
local FORM_TOP = 69 -- the form's top, below the frame's top
local FORM_WIDTH = 363
local LIST_RIGHT = 5 -- the list ends this far in from the frame's right edge
local FOOTER_HEIGHT = 32 -- fallback for the strip of the gold display
local PAD_LEFT, PAD_TOP = 11, 12
local DISPLAY_WIDTH, DISPLAY_HEIGHT = 342, 72
local ICON_SIZE = 50
local ROW_HEIGHT, ROW_GAP = 30, 15
local LABEL_WIDTH, LABEL_GAP = 93, 18
local POST_WIDTH, POST_LEFT = 194, 74
local LIST_ROW_HEIGHT = 20
local DURATION_WIDTH = 115
local RETRY = 0.25 -- seconds to wait for the game's message system before a search
local MAX_RETRIES = 40
local KEY_RETRY = 0.2 -- the game does not know yet whether the item is a commodity
local MAX_KEY_RETRIES = 10
local ITEM_SORTS = {
  { sortOrder = Enum.AuctionHouseSortOrder.Buyout, reverseSort = false },
  { sortOrder = Enum.AuctionHouseSortOrder.Bid, reverseSort = false },
}

local ui
local installed = false
-- The item in the form: location, itemDbKey, itemId, commodity, equipment, ahItemKey; resultKey: the key the game
-- answered item searches under; listings { price, bid, count, own, level, same } and complete (all results are in).
local item
local quantity = 0
local price = 0
local priceByPlayer = false -- typed or picked from a listing: no longer replaced by our suggestion
local settingPrice = false -- the form itself sets the price box
local searchSerial = 0
local postedAt -- an auction was posted: the form follows the bags once they changed
local picked -- the listing clicked last: the one row shown selected while the price is still its

-- Game texts, with the English as a fallback where a client lacks one.
local function G(name, fallback)
  return _G[name] or fallback
end

local function CopperStep()
  return (C_AuctionHouse.SupportsCopperValues and C_AuctionHouse.SupportsCopperValues()) and 1 or COPPER_PER_SILVER
end

-- Prices the server takes: whole silver where the client does not support copper.
local function RoundPrice(amount)
  local step = CopperStep()
  return math.max(step, math.floor(amount / step + 0.5) * step)
end

local function GetDuration()
  local chosen = AM.Settings.Get("sellDuration")
  if chosen >= 1 and chosen <= 3 then
    return chosen
  end
  local game = tonumber(GetCVar and GetCVar("auctionHouseDurationDropdown"))
  return (game and game >= 1 and game <= 3) and game or 2
end

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

-- A bag slot holding the item of the form: its own location while that still holds it, else the first slot that does.
local function ResolveLocation()
  if not item then
    return nil
  end
  local location = item.location
  if location and location:IsValid() and AM.ItemDbKey.FromLocation(location) == item.itemDbKey then
    return location
  end
  local bags = (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4)
  for bag = 0, bags do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID == item.itemId then
        local candidate = ItemLocation:CreateFromBagAndSlot(bag, slot)
        if AM.ItemDbKey.FromLocation(candidate) == item.itemDbKey and C_AuctionHouse.IsSellItemValid(candidate, false) then
          item.location = candidate
          return candidate
        end
      end
    end
  end
  return nil
end

local function GetMaxQuantity()
  local location = ResolveLocation()
  if not location then
    return 0
  end
  local ok, count = pcall(C_AuctionHouse.GetAvailablePostCount, location)
  return (ok and count) or C_Item.GetStackCount(location) or 1
end

local function GetDeposit()
  local location = ResolveLocation()
  if not location or quantity < 1 then
    return nil
  end
  local ok, deposit = pcall(function()
    if item.commodity then
      return C_AuctionHouse.CalculateCommodityDeposit(item.itemId, GetDuration(), quantity)
    end
    return C_AuctionHouse.CalculateItemDeposit(location, GetDuration(), quantity)
  end)
  deposit = ok and deposit or nil
  if deposit and not C_AuctionHouse.SupportsCopperValues() then
    -- as the game shows it
    deposit = math.ceil(deposit / COPPER_PER_SILVER) * COPPER_PER_SILVER
  end
  return deposit
end

-- Why the post button is disabled, nil if it can post.
local function GetPostProblem(deposit)
  if not (item and ResolveLocation()) then
    return G("AUCTION_HOUSE_SELL_FRAME_ERROR_ITEM", "No item")
  elseif quantity < 1 then
    return G("AUCTION_HOUSE_SELL_FRAME_ERROR_QUANTITY", "No quantity")
  elseif price < 1 then
    return G("AUCTION_HOUSE_SELL_FRAME_ERROR_PRICE", "No price")
  elseif deposit and GetMoney() < deposit then
    return G("AUCTION_HOUSE_SELL_FRAME_ERROR_DEPOSIT", "Not enough money for the deposit")
  elseif not C_AuctionHouse.IsThrottledMessageSystemReady() then
    return G("ERR_GENERIC_THROTTLE", "Busy")
  end
  return nil
end

-- Form ---------------------------------------------------------------------------------------------

local function UpdateTotals()
  if not ui then
    return
  end
  local deposit = GetDeposit()
  local total = quantity * price
  local cut = math.floor(total * AM.RecipeCost.AH_CUT)
  local has = item ~= nil and price > 0 and quantity > 0
  ui.deposit:SetText(deposit and AM.FormatMoney(deposit) or "--")
  ui.total:SetText(has and AM.FormatMoney(total) or "--")
  ui.cut:SetText(has and AM.FormatMoney(cut) or "--")
  ui.net:SetText(has and AM.FormatMoney(total - cut) or "--")
  local problem = GetPostProblem(deposit)
  ui.post:SetEnabled(problem == nil)
  ui.post.problem = problem
  local max = item and GetMaxQuantity() or 0
  ui.max:SetEnabled(quantity < max)
end

local function SetQuantity(value)
  local max = GetMaxQuantity()
  quantity = math.max(0, math.min(math.floor(value or 0), max))
  if ui then
    if ui.quantityBox:GetNumber() ~= quantity or ui.quantityBox:GetText() == "" then
      ui.quantityBox:SetText(quantity > 0 and tostring(quantity) or "")
      ui.quantityBox:SetCursorPosition(0)
    end
  end
  UpdateTotals()
  AM.Events.Fire("SELL_FORM_CHANGED", "price")
end

local function SetPrice(amount, byPlayer)
  price = amount and amount > 0 and RoundPrice(amount) or 0
  priceByPlayer = byPlayer and true or false
  if ui then
    settingPrice = true
    if price > 0 then
      ui.price:SetAmount(price)
    else
      ui.price:Clear()
    end
    settingPrice = false
    if ui.list then
      -- the row of the price is shown selected
      ui.list.Render()
    end
  end
  UpdateTotals()
  AM.Events.Fire("SELL_FORM_CHANGED", "price")
end

-- Our suggestion, from the listings of the item itself (equipment of another level does not count), while the player
-- has not chosen a price: the price to post at, or where nothing is listed at all the no-competition price.
local function SuggestPrice()
  if not item or priceByPlayer then
    return
  end
  local listed = {}
  for _, listing in ipairs(item.listings) do
    if listing.same and listing.price and listing.price > 0 then
      listed[#listed + 1] = { price = listing.price, count = listing.count }
    end
  end
  local suggestion = AM.ItemSearch.PostPrice(listed)
  if not suggestion and #listed == 0 and item.complete then
    local noCompetition = AM.SellPanel.NoCompetitionPrice(item.itemDbKey)
    -- the server refuses some prices with copper, whole silver always works
    suggestion = noCompetition and math.max(COPPER_PER_SILVER, math.floor(noCompetition / COPPER_PER_SILVER + 0.5) * COPPER_PER_SILVER)
  end
  AM.DebugLog.Log("sellform", "%s: %d listings, complete %s, suggested %s", item.itemDbKey, #listed,
    tostring(item.complete), tostring(suggestion))
  if suggestion then
    SetPrice(suggestion, false)
  end
end

-- The icon of the display; nil texture is the empty slot (the game's button shows its own, the fallback a bag slot).
local function SetDisplayIcon(display, texture, quality)
  if display.button then
    SetItemButtonTexture(display.button, texture)
    SetItemButtonQuality(display.button, texture and quality or nil)
    return
  end
  display.icon:SetTexture(texture or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
  display.icon:Show()
  if display.icon.border then
    display.icon.border:Show()
  end
end

local function UpdateDisplay()
  if not ui then
    return
  end
  local display = ui.display
  if not item then
    -- an empty slot with a quiet hint beside it, not a title
    SetDisplayIcon(display, nil)
    display.name:SetFontObject(Native.Font("GameFontDisable", "GameFontNormalSmall"))
    display.name:SetTextColor(0.5, 0.5, 0.5)
    display.name:SetText(L["SELL_FORM_EMPTY"])
    return
  end
  display.name:SetFontObject(Native.Font("SystemFont_Shadow_Large", "GameFontNormalLarge"))
  local name, _, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(item.itemId)
  SetDisplayIcon(display, icon or select(5, C_Item.GetItemInfoInstant(item.itemId)), quality)
  local color = ITEM_QUALITY_COLORS[quality or 1] or ITEM_QUALITY_COLORS[1]
  display.name:SetTextColor(color.r, color.g, color.b)
  display.name:SetText(name or "...")
  ui.priceLabel:SetText(item.commodity and G("AUCTION_HOUSE_UNIT_PRICE_LABEL", "Unit Price")
    or G("AUCTION_HOUSE_BUYOUT_LABEL", "Buyout Price"))
end

-- Listings -------------------------------------------------------------------------------------------

local function ListingItems()
  local items = {}
  for _, listing in ipairs(item and item.listings or {}) do
    items[#items + 1] = { height = LIST_ROW_HEIGHT, listing = listing }
  end
  return items
end

-- The one listing shown selected: the one clicked while the price is its, else the first at the price. Many auctions of
-- equipment share a price, only one row is selected as in the game's list.
local function SelectedListing()
  if price <= 0 or not item then
    return nil
  end
  local first
  for _, listing in ipairs(item.listings) do
    if listing.price == price then
      if listing == picked then
        return listing
      end
      first = first or listing
    end
  end
  return first
end

-- The columns of the game's sell lists (Blizzard_AuctionHouseTableBuilder: GetItemSellListLayout and
-- GetCommoditiesSellListLayout). width nil fills the room left, left and right are the padding inside the cell, a
-- column without header text lies under the header of the one before it.
local function PriceWidth(checkmark)
  if checkmark then
    return PRICE_DISPLAY_WITH_CHECKMARK_WIDTH or 140
  end
  return PRICE_DISPLAY_WIDTH or 120
end

local function ListMode()
  if item and item.commodity then
    return "commodity"
  end
  return item and item.equipment and "equipment" or "item"
end

local function Columns(mode)
  if mode == "commodity" then
    return {
      { key = "unitPrice", width = PriceWidth(true), left = 10, header = G("AUCTION_HOUSE_HEADER_UNIT_PRICE", "Unit Price"),
        sorted = true },
      { key = "quantity", right = 80 },
      { key = "seller", width = 120, left = 10, header = G("AUCTION_HOUSE_HEADER_SELLER", "Seller") },
    }
  end
  local copper = C_AuctionHouse.SupportsCopperValues and C_AuctionHouse.SupportsCopperValues()
  local columns = {
    { key = "bid", width = PriceWidth(false), left = 10, header = G("AUCTION_HOUSE_HEADER_BID_PRICE", "Bid Price") },
    { key = "buyout", left = copper and 20 or 0, header = G("AUCTION_HOUSE_HEADER_BUYOUT_PRICE", "Buyout Price"),
      sorted = true },
  }
  if mode == "equipment" then
    columns[#columns + 1] = { key = "socket", width = 24, right = 10 }
    -- Forever lists by required level and shows no item level (AuctionHouse_ShouldUseRequiredLevel)
    local requiredLevel = AuctionHouse_ShouldUseRequiredLevel ~= nil and AuctionHouse_ShouldUseRequiredLevel()
    if not requiredLevel then
      columns[#columns + 1] = { key = "level", width = 50, left = 10, header = G("ITEM_LEVEL_ABBR", "iLvl") }
    end
  else
    columns[#columns + 1] = { key = "itemQuantity", width = 60, right = 10 }
  end
  return columns
end

-- Where each column lies, as { point of its left edge, x, point of its right edge, x } on the row: the columns before
-- the filling one counted from the left, the ones after it from the right.
local function Spans(columns)
  local fill = #columns + 1
  for index, column in ipairs(columns) do
    if not column.width then
      fill = index
    end
  end
  local spans, x = {}, 0
  for index = 1, fill - 1 do
    spans[index] = { "LEFT", x, "LEFT", x + columns[index].width }
    x = x + columns[index].width
  end
  local fromRight = 0
  for index = #columns, fill + 1, -1 do
    spans[index] = { "RIGHT", -(fromRight + columns[index].width), "RIGHT", -fromRight }
    fromRight = fromRight + columns[index].width
  end
  if columns[fill] then
    spans[fill] = { "LEFT", x, "RIGHT", -fromRight }
  end
  return spans
end

local function Place(region, parent, span, left, right)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", parent, "TOP" .. span[1], span[2] + (left or 0), 0)
  region:SetPoint("BOTTOMRIGHT", parent, "BOTTOM" .. span[3], span[4] - (right or 0), 0)
end

-- The headers of the columns of the item in the form.
local function ApplyColumns()
  local mode = ListMode()
  if ui.mode == mode then
    return
  end
  ui.mode = mode
  ui.columns = Columns(mode)
  ui.spans = Spans(ui.columns)
  for _, button in ipairs(ui.headers) do
    button:Hide()
  end
  local used = 0
  for index, column in ipairs(ui.columns) do
    if column.header then
      local last = index
      while ui.columns[last + 1] and not ui.columns[last + 1].header do
        last = last + 1
      end
      used = used + 1
      local button = ui.headers[used] or Native.CreateHeaderButton(ui.headerStrip, "", false)
      ui.headers[used] = button
      button:SetText(column.header)
      local first, final = ui.spans[index], ui.spans[last]
      -- the headers overlap by 2, as the game's (headerOverlap)
      Place(button, ui.headerStrip, { first[1], first[2], final[3], final[4] + (ui.columns[last + 1] and 2 or 0) })
      Native.SetSortArrow(button, column.sorted and true or false, true)
      button:Show()
    end
  end
end

-- The widest price of a column, so the prices line up on the right as in the game's lists (GetMaxBuyoutWidth).
local function MaxMoneyWidth(field)
  local widest = 0
  if not (ui.measure and ui.measure.SetResizeToFit) then
    return nil
  end
  for _, listing in ipairs(item and item.listings or {}) do
    local amount = listing[field]
    if amount and amount > 0 then
      ui.measure:SetAmount(amount)
      widest = math.max(widest, ui.measure:GetWidth())
    end
  end
  return widest
end

local function UpdateList()
  if not ui then
    return
  end
  ApplyColumns()
  ui.bidWidth, ui.priceWidth = MaxMoneyWidth("bid"), MaxMoneyWidth("price")
  local items = ListingItems()
  ui.list.SetItems(items)
  local available = 0
  for _, listing in ipairs(item and item.listings or {}) do
    available = available + (listing.count or 0)
  end
  ui.available:SetText(available > 0 and G("AUCTION_HOUSE_QUANTITY_AVAILABLE_FORMAT", "%s Available"):format(
    BreakUpLargeNumbers and BreakUpLargeNumbers(available) or available) or "")
  local empty = ""
  if item and #items == 0 then
    empty = item.complete and G("BROWSE_NO_RESULTS", "No results") or G("SEARCHING", "Searching...")
  end
  ui.empty:SetText(empty)
end

local function ReadCommodities()
  local listings = {}
  for index = 1, C_AuctionHouse.GetNumCommoditySearchResults(item.itemId) do
    local result = C_AuctionHouse.GetCommoditySearchResultInfo(item.itemId, index)
    if result and result.quantity > 0 then
      listings[#listings + 1] = { price = result.unitPrice, count = result.quantity, own = result.containsOwnerItem,
        same = true, owners = result.owners, numOwners = result.totalNumberOfOwners, result = result }
    end
  end
  item.listings = listings
  item.complete = C_AuctionHouse.HasFullCommoditySearchResults(item.itemId)
end

local function ReadItems(key)
  local listings = {}
  for index = 1, C_AuctionHouse.GetNumItemSearchResults(key) do
    local result = C_AuctionHouse.GetItemSearchResultInfo(key, index)
    if result then
      local listing = AM.ItemSearch.GetItemListing(result)
      listings[#listings + 1] = {
        price = result.buyoutAmount, bid = result.bidAmount, count = listing and listing.count or result.quantity or 1,
        own = result.containsOwnerItem, level = result.itemKey and result.itemKey.itemLevel,
        socket = result.containsSocketedItem, result = result,
        same = result.itemKey ~= nil and AM.ItemDbKey.FromAhItemKey(result.itemKey) == item.itemDbKey,
      }
    end
  end
  item.listings = listings
  item.complete = C_AuctionHouse.HasFullItemSearchResults(key)
end

local function OnResults()
  UpdateList()
  SuggestPrice()
  UpdateTotals()
end

-- Searches the item's auctions as the game's sell form does: commodities and items by their key, equipment with the
-- sell search (all levels; the server does not answer the plain search for it). Waits for the game's message system.
local function Search(tries)
  if not item then
    return
  end
  local serial = searchSerial
  if not C_AuctionHouse.IsThrottledMessageSystemReady() then
    if (tries or 0) < MAX_RETRIES then
      C_Timer.After(RETRY, function()
        if serial == searchSerial then
          Search((tries or 0) + 1)
        end
      end)
    end
    return
  end
  AM.DebugLog.Log("sellform", "search %s (%s)", item.itemDbKey,
    item.commodity and "commodity" or item.equipment and "equipment" or "item")
  if item.commodity then
    C_AuctionHouse.SendSearchQuery(item.ahItemKey, {}, false)
  elseif item.equipment then
    AM.ItemSearch.SendEquipmentSearch(item.ahItemKey, ITEM_SORTS)
  else
    C_AuctionHouse.SendSearchQuery(item.ahItemKey, ITEM_SORTS, false)
  end
end

local function Clear()
  item = nil
  quantity, price, priceByPlayer = 0, 0, false
  postedAt, picked = nil, nil
  searchSerial = searchSerial + 1
  if ui then
    settingPrice = true
    ui.price:Clear()
    settingPrice = false
    ui.quantityBox:SetText("")
    UpdateDisplay()
    UpdateList()
    SetQuantity(0)
  end
  AM.Events.Fire("SELL_FORM_CHANGED", "item")
end

-- Puts the item at the bag location into the form and searches its auctions. Items the auction house does not take
-- are ignored.
function SellForm.SetItem(location, tries)
  -- with the game's form in use the game takes the item itself; ours never fills the game's form (taint)
  if not SellForm.IsEnabled() then
    return
  end
  if not (location and location:IsValid() and C_AuctionHouse.IsSellItemValid(location, false)) then
    return
  end
  local status = C_AuctionHouse.GetItemCommodityStatus(location)
  if status == Enum.ItemCommodityStatus.Unknown then
    -- the game has not loaded the item yet
    if (tries or 0) < MAX_KEY_RETRIES then
      C_Timer.After(KEY_RETRY, function()
        SellForm.SetItem(location, (tries or 0) + 1)
      end)
    end
    return
  end
  local itemDbKey = AM.ItemDbKey.FromLocation(location)
  local ahItemKey = C_AuctionHouse.GetItemKeyFromItem(location)
  if not (itemDbKey and ahItemKey) then
    return
  end
  local keyInfo = C_AuctionHouse.GetItemKeyInfo(ahItemKey)
  local itemId = C_Item.GetItemID(location)
  local equipment = keyInfo and keyInfo.isEquipment
  if keyInfo == nil then
    local classId = select(6, C_Item.GetItemInfoInstant(itemId))
    equipment = classId == Enum.ItemClass.Weapon or classId == Enum.ItemClass.Armor
  end
  item = {
    location = location, itemDbKey = itemDbKey, itemId = itemId, ahItemKey = ahItemKey,
    commodity = status == Enum.ItemCommodityStatus.Commodity, equipment = equipment and true or false,
    listings = {}, complete = false,
  }
  searchSerial = searchSerial + 1
  priceByPlayer, postedAt, picked = false, nil, nil
  AM.DebugLog.Log("sellform", "item %s (%s)", itemDbKey, item.commodity and "commodity" or "item")
  UpdateDisplay()
  UpdateList()
  SetPrice(0, false)
  -- everything there is of it, as the Sell tab counts it
  SetQuantity(GetMaxQuantity())
  -- our price from the last search of it until the new one answers
  local known = AM.ItemSearch.GetSellPrice(itemDbKey)
  if known then
    SetPrice(known, false)
  end
  AM.Events.Fire("SELL_FORM_CHANGED", "item")
  Search()
end

-- The key of the item in the form, nil if there is none.
function SellForm.GetItemDbKey()
  return item and item.itemDbKey
end

-- The price per item in the form, nil without an item or a price.
function SellForm.GetPrice()
  return item and price > 0 and price or nil
end

local function Post()
  local location = ResolveLocation()
  if not location or GetPostProblem(GetDeposit()) then
    return
  end
  local duration = GetDuration()
  local ok, posted
  if item.commodity then
    ok, posted = pcall(C_AuctionHouse.PostCommodity, location, duration, quantity, price)
  else
    ok, posted = pcall(C_AuctionHouse.PostItem, location, duration, quantity, nil, price)
  end
  AM.DebugLog.Log("sellform", "post %s x%d at %d for duration %d: %s %s", item.itemDbKey, quantity, price, duration,
    tostring(ok), tostring(posted))
  if ok and posted ~= false then
    postedAt = GetTime()
    if SOUNDKIT and SOUNDKIT.LOOT_WINDOW_COIN_SOUND then
      PlaySound(SOUNDKIT.LOOT_WINDOW_COIN_SOUND)
    end
  end
  UpdateTotals()
end

-- After a post, once the bags changed: what is left of the item stays in the form (all of it, at the price chosen),
-- its auctions are searched again; with nothing left the form is emptied.
local function AfterPost()
  if not (item and postedAt) then
    return
  end
  postedAt = nil
  if not ResolveLocation() then
    Clear()
    return
  end
  SetQuantity(GetMaxQuantity())
  searchSerial = searchSerial + 1
  Search()
end

-- Building -------------------------------------------------------------------------------------------

-- The highest frame level among the frames of the auction house below the limit, not counting the addon's named ones.
local function HighestLevel(parent, limit)
  local highest = parent:GetFrameLevel()
  if highest >= limit then
    highest = 0
  end
  for _, child in ipairs({ parent:GetChildren() }) do
    local name = child:GetName()
    if not (name and name:find("^" .. addonName)) then
      highest = math.max(highest, HighestLevel(child, limit))
    end
  end
  return highest
end

-- A row of the form: the label on the left (gold, right aligned, as the game's), the control right of it.
local function CreateFormRow(parent, label)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(FORM_WIDTH - 2 * PAD_LEFT, ROW_HEIGHT)
  row.label = Widgets.CreateText(row, "GameFontNormal", "RIGHT")
  row.label:SetWidth(LABEL_WIDTH)
  row.label:SetPoint("LEFT")
  row.label:SetText(label)
  return row
end

-- A row showing an amount of money.
local function CreateMoneyRow(parent, label)
  local row = CreateFormRow(parent, label)
  local value = Widgets.CreateText(row, "GameFontHighlight")
  value:SetPoint("LEFT", row.label, "RIGHT", LABEL_GAP, 0)
  return row, value
end

local function CreatePriceInput(row)
  local ok, input = pcall(CreateFrame, "Frame", nil, row, "LargeMoneyInputFrameTemplate")
  if ok and input.SetAmount then
    input.useAuctionHouseCopperValue = true
    input:OnLoad() -- again, now that it knows to hide the copper where the client has none
    input:SetSize(190, 33)
  else
    -- a plain box in copper where the client lacks the game's money input
    input = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    input:SetSize(120, 20)
    input:SetNumeric(true)
    input:SetAutoFocus(false)
    function input:SetAmount(amount) self:SetText(tostring(amount)) end
    function input:GetAmount() return self:GetNumber() end
    function input:Clear() self:SetText("") end
    function input:SetOnValueChangedCallback(callback) self:SetScript("OnTextChanged", callback) end
  end
  input:SetPoint("LEFT", row.label, "RIGHT", LABEL_GAP, -2)
  input:SetOnValueChangedCallback(function()
    -- The boxes report changes the form made itself as well, not always right away: only an amount other than the
    -- form's own is the player's.
    local amount = input:GetAmount() or 0
    if settingPrice or amount == price then
      return
    end
    price = amount
    priceByPlayer = true
    if ui and ui.list then
      ui.list.Render()
    end
    UpdateTotals()
    AM.Events.Fire("SELL_FORM_CHANGED", "price")
  end)
  return input
end

local function CreateQuantityInput(row)
  local ok, box = pcall(CreateFrame, "EditBox", nil, row, "LargeInputBoxTemplate")
  if not ok then
    box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
  end
  box:SetSize(134, ok and 33 or 20)
  box:SetNumeric(true)
  box:SetAutoFocus(false)
  box:SetMaxLetters(8)
  local font = Native.Font("PriceFont", "GameFontHighlight")
  if _G[font] then
    box:SetFontObject(_G[font])
  end
  box:SetPoint("LEFT", row.label, "RIGHT", LABEL_GAP, -2)
  box:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
      local max = GetMaxQuantity()
      local value = self:GetNumber()
      if value > max then
        self:SetText(tostring(max))
        value = max
      end
      quantity = value
      UpdateTotals()
      AM.Events.Fire("SELL_FORM_CHANGED", "price")
    end
  end)
  box:SetScript("OnEditFocusLost", function(self)
    if self:GetNumber() < 1 and item then
      SetQuantity(1)
    end
  end)
  box:SetScript("OnEnterPressed", box.ClearFocus)
  box:SetScript("OnEscapePressed", box.ClearFocus)
  return box
end

local function CreateItemDisplay(form)
  local display = CreateFrame("Button", nil, form)
  display:SetSize(DISPLAY_WIDTH, DISPLAY_HEIGHT)
  display:SetPoint("TOPLEFT", PAD_LEFT, -PAD_TOP)
  if Native.HasAtlas("auctionhouse-itemheaderframe") then
    local frame = display:CreateTexture(nil, "BACKGROUND")
    frame:SetAtlas("auctionhouse-itemheaderframe", true)
    frame:SetPoint("CENTER")
  end
  -- the game's own big item button (empty slot, icon mask, quality border) as in its sell form, where the client has it
  local made, button = false, nil
  if SetItemButtonTexture and SetItemButtonQuality then
    made, button = pcall(CreateFrame, "Button", nil, display, "GiantItemButtonTemplate")
  end
  local anchor
  if made then
    button:SetPoint("LEFT", 10, 0)
    display.button = button
    anchor = button
  else
    display.icon = Native.CreateItemIcon(display)
    display.icon:SetSize(ICON_SIZE, ICON_SIZE)
    display.icon:SetPoint("LEFT", 14, 0)
    if display.icon.border then
      -- the border is drawn for a 14 px icon in a 16 px frame, so it grows with the icon
      local size = math.floor(ICON_SIZE * 16 / 14 + 0.5)
      display.icon.border:SetSize(size, size)
    end
    anchor = display.icon
  end
  display.name = Widgets.CreateText(display, Native.Font("SystemFont_Shadow_Large", "GameFontNormalLarge"))
  display.name:SetPoint("LEFT", anchor, "RIGHT", 12, 0)
  display.name:SetPoint("RIGHT", -12, 0)
  display.name:SetHeight(64)
  display.name:SetJustifyV("MIDDLE")
  -- an item dropped on it, or clicked on it from the cursor, goes into the form
  local function TakeCursorItem()
    local location = C_Cursor and C_Cursor.GetCursorItem and C_Cursor.GetCursorItem()
    if location and location:IsValid() then
      ClearCursor()
      SellForm.SetItem(location)
    end
  end
  local function ShowTooltip(self)
    local location = ResolveLocation()
    if location then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink(C_Item.GetItemLink(location) or ("item:" .. item.itemId))
      GameTooltip:Show()
    end
  end
  -- the item button takes the mouse over its own area, so it acts as the rest of the display
  for _, target in ipairs({ display, display.button }) do
    target:SetScript("OnReceiveDrag", TakeCursorItem)
    target:SetScript("OnClick", TakeCursorItem)
    target:SetScript("OnEnter", ShowTooltip)
    target:SetScript("OnLeave", GameTooltip_Hide)
  end
  return display
end

-- The background of a panel of the game's sell view (AuctionHouseBackgroundTemplate): only the inset's border, no
-- marble and no list fill below the atlas, which keeps its own size from the top left (the window's background shows
-- below it). In ARTWORK as the game's: an inset shares its parent's frame level, whose rock (BACKGROUND) would cover it.
local function SetSellBackground(panel, atlas)
  if Native.IsClassicSkin() or not Native.HasAtlas(atlas) then
    return
  end
  if panel.Bg then panel.Bg:Hide() end
  if panel.fill then panel.fill:Hide() end
  local background = panel:CreateTexture(nil, "ARTWORK", nil, -8)
  background:SetAtlas(atlas, true)
  background:SetPoint("TOPLEFT", 3, -3)
end

local function CreateForm(cover)
  local form = Native.CreateInset(cover)
  form:SetPoint("TOPLEFT", 0, -(FORM_TOP - TITLE_HEIGHT))
  form:SetPoint("BOTTOMLEFT")
  form:SetWidth(FORM_WIDTH)
  SetSellBackground(form, "auctionhouse-background-sell-left")
  ui.display = CreateItemDisplay(form)

  local y = -(PAD_TOP + DISPLAY_HEIGHT + 8 + ROW_GAP)
  local function Place(row, gap)
    row:SetPoint("TOPLEFT", PAD_LEFT, y)
    y = y - ROW_HEIGHT - (gap or ROW_GAP)
  end

  -- always shown, as in the game's form: with one or none to post its box stays at that and Max is disabled
  ui.quantityRow = CreateFormRow(form, G("AUCTION_HOUSE_QUANTITY_LABEL", "Quantity"))
  Place(ui.quantityRow)
  ui.quantityBox = CreateQuantityInput(ui.quantityRow)
  ui.max = Widgets.CreateButton(ui.quantityRow, G("AUCTION_HOUSE_MAX_QUANTITY_BUTTON", "Max"), false, function()
    SetQuantity(GetMaxQuantity())
  end)
  ui.max:SetSize(75, 22)
  ui.max:SetPoint("LEFT", ui.quantityBox, "RIGHT", 6, 2)

  local priceRow = CreateFormRow(form, G("AUCTION_HOUSE_UNIT_PRICE_LABEL", "Unit Price"))
  Place(priceRow)
  ui.priceLabel = priceRow.label
  ui.price = CreatePriceInput(priceRow)

  local durationRow = CreateFormRow(form, G("AUCTION_HOUSE_DURATION_LABEL", "Duration"))
  Place(durationRow)
  local duration = Widgets.CreateDropdown(durationRow, DURATION_WIDTH, function(value)
    AM.Settings.Set("sellDuration", value)
    ui.duration.SetChoices(ui.duration.choices, value)
    UpdateTotals()
  end)
  duration.button:SetPoint("LEFT", durationRow.label, "RIGHT", LABEL_GAP + 1, -2)
  duration.SetChoices({
    { value = 1, label = G("AUCTION_DURATION_ONE", "12 Hours") },
    { value = 2, label = G("AUCTION_DURATION_TWO", "24 Hours") },
    { value = 3, label = G("AUCTION_DURATION_THREE", "48 Hours") },
  }, GetDuration())
  ui.duration = duration

  local row
  row, ui.deposit = CreateMoneyRow(form, G("AUCTION_HOUSE_DEPOSIT_LABEL", "Deposit"))
  Place(row)
  row, ui.total = CreateMoneyRow(form, G("AUCTION_HOUSE_TOTAL_PRICE_LABEL", "Total Price"))
  Place(row, 0)
  -- what the sale brings: the cut taken from the total; the deposit comes back with the sale
  row, ui.cut = CreateMoneyRow(form, L["SELL_FORM_CUT"])
  Place(row, 0)
  row, ui.net = CreateMoneyRow(form, L["SELL_FORM_NET"])
  Place(row, ROW_GAP)

  ui.post = Widgets.CreateButton(form, G("AUCTION_HOUSE_POST_BUTTON", "Create Auction"), false, Post)
  ui.post:SetSize(POST_WIDTH, 22)
  ui.post:SetPoint("TOPLEFT", PAD_LEFT + POST_LEFT, y)
  ui.post:SetMotionScriptsWhileDisabled(true)
  ui.post:SetScript("OnEnter", function(self)
    if self.problem then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(self.problem, 1, 0.2, 0.2, 1, true)
      GameTooltip:Show()
    end
  end)
  ui.post:SetScript("OnLeave", GameTooltip_Hide)
end

-- A money display of the game's lists (MoneyDisplayFrameTemplate with the auction house icons and copper rule), our
-- text where the client lacks it. measure: a display that takes the width of its amount, to measure prices with.
local function CreateMoney(parent, measure)
  local ok, money = pcall(CreateFrame, "Frame", nil, parent, "MoneyDisplayFrameTemplate")
  if ok and money.OnLoad then
    -- the template reads these in OnLoad, as the auction house's own (AuctionHouseTableMoneyDisplayTemplate)
    money.useAuctionHouseIcons, money.useAuctionHouseCopperValue, money.resizeToFit = true, true, measure
    money:OnLoad()
    money:SetHeight(16)
    return money
  end
  money = Widgets.CreateText(parent, Native.RowFont(), "RIGHT")
  money:SetHeight(16)
  function money.SetAmount(self, amount)
    self:SetText(AM.FormatMoney(amount))
  end
  return money
end

-- A price cell: the price lined up on the right of the widest one, the check mark of the player's own after it.
local function CreateMoneyCell(row)
  local cell = CreateFrame("Frame", nil, row)
  cell.money = CreateMoney(cell)
  cell.money:SetPoint("LEFT")
  cell.check = cell:CreateTexture(nil, "BACKGROUND")
  cell.check:SetSize(16, 16)
  if Native.HasAtlas("auctionhouse-icon-checkmark") then
    cell.check:SetAtlas("auctionhouse-icon-checkmark")
  else
    cell.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
  end
  cell.check:SetPoint("LEFT", cell.money, "RIGHT", 6, 0)
  return cell
end

local function SetMoneyCell(cell, amount, width, own)
  cell:SetShown(amount ~= nil and amount > 0)
  if not (amount and amount > 0) then
    return
  end
  cell.money:SetAmount(amount)
  -- the money display lines its coins up on its right edge
  cell.money:SetWidth(width and width > 0 and width or 100)
  cell.check:SetShown(own and true or false)
end

local function CreateTextCell(row, font, justify)
  local text = Widgets.CreateText(row, Native.Font(font, Native.RowFont()), justify)
  text:SetWordWrap(false)
  return text
end

local function CreateListRow(parent)
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(LIST_ROW_HEIGHT)
  Native.StyleRow(row)
  row.cells = {
    bid = CreateMoneyCell(row),
    buyout = CreateMoneyCell(row),
    unitPrice = CreateMoneyCell(row),
    quantity = CreateTextCell(row, "PriceFontWhite", "RIGHT"),
    itemQuantity = CreateTextCell(row, "PriceFontWhite", "RIGHT"),
    seller = CreateTextCell(row, "Number13FontGray", "LEFT"),
    level = CreateTextCell(row, "Number13FontWhite", "LEFT"),
    socket = row:CreateTexture(nil, "ARTWORK"),
  }
  if Native.HasAtlas("auctionhouse-icon-socket") then
    row.cells.socket:SetAtlas("auctionhouse-icon-socket", true)
  end
  -- the bids are grey, as in the game's list for bids of others
  if row.cells.bid.money.SetFontAndIconDisabled then
    row.cells.bid.money:SetFontAndIconDisabled(true)
  end
  row:SetScript("OnClick", function(self)
    local listing = self.listing
    if not (listing and listing.price and listing.price > 0) then
      return
    end
    -- its price as it is: no undercutting (see CLAUDE.md)
    AM.DebugLog.Log("sellform", "listing %d picked", listing.price)
    picked = listing
    SetPrice(listing.price, true)
    ui.list.Render()
  end)
  -- as in the game's own sell list: a double-click jumps to the buy tab for that auction
  row:SetScript("OnDoubleClick", function(self)
    if self.listing and self.listing.result then
      AM.DirectBuy.Open(self.listing.result)
    end
  end)
  return row
end

-- The cells of the columns shown, placed on the row; the others hidden.
local function PlaceCells(row)
  for _, cell in pairs(row.cells) do
    cell:Hide()
  end
  row.shown = {}
  for index, column in ipairs(ui.columns) do
    local cell = row.cells[column.key]
    if column.key == "socket" then
      cell:ClearAllPoints()
      cell:SetPoint("LEFT", row, ui.spans[index][1], ui.spans[index][2] + 4, 0)
    else
      Place(cell, row, ui.spans[index], column.left, column.right)
    end
    row.shown[column.key] = cell
  end
  row.mode = ui.mode
end

local function SetupListRow(row, entry, index)
  local listing = entry.listing
  row.listing = listing
  Native.SetRowState(row, index, listing == SelectedListing())
  if row.mode ~= ui.mode then
    PlaceCells(row)
  end
  local cells = row.shown
  if cells.unitPrice then
    SetMoneyCell(cells.unitPrice, listing.price, ui.priceWidth, listing.own)
    cells.quantity:SetText(BreakUpLargeNumbers and BreakUpLargeNumbers(listing.count or 0) or listing.count or 0)
    cells.quantity:Show()
    -- as the game's seller column (AuctionHouseUtil.GetSellersString)
    local owners = listing.owners or {}
    local seller = ""
    if #owners == 1 then
      seller = listing.own and ("|cffffffff" .. G("AUCTION_HOUSE_SELLER_YOU", "You") .. "|r") or owners[1]
    elseif #owners > 1 then
      seller = G("AUCTION_HOUSE_NUM_SELLERS", "%d Sellers"):format(listing.numOwners or #owners)
    end
    cells.seller:SetText(seller)
    cells.seller:Show()
    return
  end
  -- an item: the check mark at the buyout, at the bid only without a buyout
  local hasBuyout = listing.price ~= nil and listing.price > 0
  SetMoneyCell(cells.bid, listing.bid, ui.bidWidth, listing.own and not hasBuyout)
  SetMoneyCell(cells.buyout, listing.price, ui.priceWidth, listing.own)
  if cells.socket then
    cells.socket:SetShown(listing.socket and true or false)
  end
  if cells.level then
    cells.level:SetText(listing.level and tostring(listing.level) or "")
    cells.level:Show()
  end
  if cells.itemQuantity then
    cells.itemQuantity:SetText(listing.count and listing.count > 1
      and (BreakUpLargeNumbers and BreakUpLargeNumbers(listing.count) or tostring(listing.count)) or "")
    cells.itemQuantity:Show()
  end
end

local function CreateList(cover)
  local native = Native.CreateListPanel(cover, true)
  native.frame:SetPoint("TOPLEFT", cover, "TOPLEFT", FORM_WIDTH + 1, -(FORM_TOP - TITLE_HEIGHT))
  native.frame:SetPoint("BOTTOMRIGHT", -(LIST_RIGHT - SIDE_INSET), 0)
  SetSellBackground(native.panel, "auctionhouse-background-sell-right")
  ui.headerStrip = native.header
  ui.headers = {}
  -- measures the widest price of a column, never seen
  ui.measure = CreateMoney(native.frame, true)
  ui.measure:SetPoint("TOPLEFT")
  ui.measure:SetAlpha(0)
  ui.list = Widgets.CreateList(native.body, CreateListRow, SetupListRow)
  ui.list:SetAllPoints(native.body)
  ui.empty = Widgets.CreateText(native.body, "GameFontNormal", "CENTER")
  ui.empty:SetPoint("TOPLEFT", 45, -45)
  ui.empty:SetPoint("TOPRIGHT", -67, -45)
  ui.empty:SetWordWrap(true)

  -- "N Available" and the refresh button above the list, as the game's
  local function Refresh()
    searchSerial = searchSerial + 1
    Search()
  end
  local ok, refresh = pcall(CreateFrame, "Button", nil, cover, "RefreshButtonTemplate")
  if ok then
    refresh:SetScript("OnClick", Refresh)
  else
    refresh = Widgets.CreateIconButton(cover, "R", 22, Refresh)
  end
  refresh:SetSize(22, 22)
  refresh:SetPoint("BOTTOMRIGHT", native.frame, "TOPRIGHT", -8, 4)
  ui.available = Widgets.CreateText(cover, "GameFontNormalSmall", "RIGHT")
  ui.available:SetPoint("RIGHT", refresh, "LEFT", -3, 0)
end

local function SwitchForm(enable)
  if enable == SellForm.IsEnabled() then
    return
  end
  AM.Settings.Set("sellForm", enable)
  AM.DebugLog.Log("sellform", "switched to the %s form", enable and "AuctionMaster" or "game's")
  if not enable and item then
    Clear()
  end
  SellForm.Update()
  AM.SellPanel.Update()
end

local TAB_SHADE = 0.55 -- the art of a tab not selected: the game has no darker variant of the sell tab

-- A tab in the look of the game's "Create Auction" tab above its form (AuctionHouseSellFrameTemplate: the
-- auctionhouse-selltab atlases, label in GameFontNormalSmall), darker while not selected.
local function CreateFormTab(parent, text, onClick)
  local tab = CreateFrame("Button", nil, parent)
  local left = tab:CreateTexture(nil, "ARTWORK")
  left:SetAtlas("auctionhouse-selltab-left", true)
  left:SetPoint("BOTTOMLEFT")
  local label = tab:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  label:SetText(text)
  label:SetPoint("LEFT", left, "RIGHT", 12, 0)
  local middle = tab:CreateTexture(nil, "BORDER")
  middle:SetAtlas("auctionhouse-selltab-middle")
  middle:SetHeight(23)
  middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
  middle:SetPoint("RIGHT", label, "RIGHT", 12, 0)
  local right = tab:CreateTexture(nil, "ARTWORK")
  right:SetAtlas("auctionhouse-selltab-right", true)
  right:SetPoint("TOPLEFT", middle, "TOPRIGHT")
  right:SetPoint("BOTTOMLEFT", middle, "BOTTOMRIGHT")
  tab:SetSize(left:GetWidth() + label:GetStringWidth() + 24 + right:GetWidth(), math.max(left:GetHeight(), 23))
  tab:SetScript("OnClick", onClick)
  local function Paint(hover)
    local shade = tab.selected and 1 or TAB_SHADE
    for _, texture in ipairs({ left, middle, right }) do
      texture:SetVertexColor(shade, shade, shade)
    end
    if tab.selected then
      label:SetFontObject(GameFontNormalSmall)
    else
      label:SetFontObject(hover and GameFontHighlightSmall or GameFontDisableSmall)
    end
  end
  tab:HookScript("OnEnter", function() Paint(true) end)
  tab:HookScript("OnLeave", function() Paint(false) end)
  function tab.SetSelected(selected)
    tab.selected = selected
    Paint(tab:IsMouseOver())
  end
  return tab
end

-- The game's "Create Auction" tab sits where ours are: hidden while ours are shown, as its text would show between
-- them. Blizzard's code never touches these textures (only the XML creates them).
local GAME_TAB_KEYS = { "CreateAuctionTabLeft", "CreateAuctionTabMiddle", "CreateAuctionTabRight", "CreateAuctionLabel" }
local function ShowGameTab(shown)
  local house = AuctionHouseFrame
  for _, frame in pairs({ house.ItemSellFrame, house.CommoditiesSellFrame }) do
    for _, key in ipairs(GAME_TAB_KEYS) do
      if frame[key] then
        frame[key]:SetAlpha(shown and 1 or 0)
      end
    end
  end
end

-- The tabs above the form, where the game has its "Create Auction" tab: our form and the game's, for an item our form
-- cannot sell. The choice is kept. Where the client lacks the tab's art, a button switches instead.
local function CreateSwitch(house, cover)
  local level = math.min(cover:GetFrameLevel() + 10, 499)
  if Native.HasAtlas("auctionhouse-selltab-left") then
    local ours = CreateFormTab(house, L["SELL_FORM_TAB_OURS"], function() SwitchForm(true) end)
    ours:SetFrameLevel(level)
    -- as the game's tab: 42 from the left of the form, 3 into it
    ours:SetPoint("BOTTOMLEFT", house, "TOPLEFT", SIDE_INSET + 42, -(FORM_TOP + 3))
    local game = CreateFormTab(house, L["SELL_FORM_TAB_GAME"], function() SwitchForm(false) end)
    game:SetFrameLevel(level)
    game:SetPoint("BOTTOMLEFT", ours, "BOTTOMRIGHT", 2, 0)
    Widgets.SetTooltip(game, L["SELL_FORM_SWITCH_GAME_TIP"])
    ours:Hide()
    game:Hide()
    ui.tabs = { ours = ours, game = game }
    return
  end
  local switch = Widgets.CreateSecondaryButton(house, L["SELL_FORM_SWITCH_GAME"], function()
    SwitchForm(not SellForm.IsEnabled())
  end)
  switch:SetHeight(20)
  switch:SetFrameLevel(level)
  switch:SetPoint("BOTTOMRIGHT", house, "TOPLEFT", SIDE_INSET + FORM_WIDTH - 6, -(FORM_TOP - 2))
  Widgets.SetTooltip(switch, function()
    return SellForm.IsEnabled() and L["SELL_FORM_SWITCH_GAME_TIP"] or L["SELL_FORM_SWITCH_OURS_TIP"]
  end)
  switch:Hide()
  ui.switch = switch
end

local function Create()
  local house = AuctionHouseFrame
  ui = {}
  local cover = Widgets.CreateBox(house, UI.body, UI.body)
  cover:SetBackdropBorderColor(0, 0, 0, 0)
  -- above the frames of the game's sell view (some at level 350), below its border and portrait (500 and up)
  cover:SetFrameLevel(math.min(HighestLevel(house, 500) + 1, 499))
  cover:EnableMouse(true) -- the game's form below must not be reachable
  if Native.IsClassicSkin() then
    cover:SetBackdropColor(unpack(Native.CLASSIC_BODY))
  else
    Native.AddFrameBackground(cover)
    if Native.HasAtlas("_UI-Frame-TopTileStreaks") then
      -- the dark streaks at the top of the game's frame (PortraitFrameTexturedBaseTemplate), which the cover hides
      local streaks = cover:CreateTexture(nil, "BACKGROUND", nil, 2)
      streaks:SetAtlas("_UI-Frame-TopTileStreaks", true)
      streaks:SetHorizTile(true)
      streaks:SetPoint("TOPLEFT", house, "TOPLEFT", 6, -21)
      streaks:SetPoint("TOPRIGHT", house, "TOPRIGHT", -2, -21)
    end
  end
  cover:Hide()
  ui.cover = cover
  -- our logo on the portrait slot stays above
  local portrait = _G[addonName .. "Portrait"]
  if portrait and portrait:GetFrameLevel() <= cover:GetFrameLevel() then
    portrait:SetFrameLevel(math.min(cover:GetFrameLevel() + 100, 499))
  end
  CreateForm(cover)
  CreateList(cover)
  CreateSwitch(house, cover)
  UpdateDisplay()
  UpdateList()
  if price > 0 then
    SetPrice(price, priceByPlayer)
  end
  SetQuantity(quantity)
end

-- The cover reaches from below the title bar down to the strip of the gold display, which stays the game's.
local function Place()
  local house = AuctionHouseFrame
  local bottom = FOOTER_HEIGHT
  local money = house.MoneyFrameBorder
  if money and money:GetTop() and house:GetBottom() then
    bottom = money:GetTop() - house:GetBottom() + 2
  end
  ui.cover:ClearAllPoints()
  ui.cover:SetPoint("TOPLEFT", SIDE_INSET, -TITLE_HEIGHT)
  ui.cover:SetPoint("BOTTOMRIGHT", -SIDE_INSET, bottom)
end

-- Shows the form over the game's sell view while that is shown and our window is not.
function SellForm.Update()
  if not AuctionHouseFrame then
    return
  end
  local wanted = IsSellMode() and not AM.MainWindow.IsShown()
  if wanted and not ui then
    Create()
  end
  if not ui then
    return
  end
  local enabled = SellForm.IsEnabled()
  if wanted and enabled then
    Place()
    UpdateDisplay()
    UpdateTotals()
  end
  ui.cover:SetShown(wanted and enabled)
  if ui.tabs then
    ui.tabs.ours.SetSelected(enabled)
    ui.tabs.game.SetSelected(not enabled)
    ui.tabs.ours:SetShown(wanted)
    ui.tabs.game:SetShown(wanted)
    ShowGameTab(not wanted)
  else
    ui.switch:SetLabel(enabled and L["SELL_FORM_SWITCH_GAME"] or L["SELL_FORM_SWITCH_OURS"])
    ui.switch:SetShown(wanted)
  end
end

-- The auction house is load on demand: hooked the first time it opens.
local function Install()
  local house = AuctionHouseFrame
  if installed or not house then
    return
  end
  installed = true
  if house.SetDisplayMode then
    hooksecurefunc(house, "SetDisplayMode", SellForm.Update)
  end
  -- a click on a bag item: the game's own code puts it into its form, ours takes it from there (only read)
  if house.SetPostItem then
    hooksecurefunc(house, "SetPostItem", function(_, location)
      SellForm.SetItem(location)
    end)
  end
  house:HookScript("OnShow", SellForm.Update)
end

local events = CreateFrame("Frame")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:RegisterEvent("AUCTION_HOUSE_CLOSED")
events:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
events:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
pcall(events.RegisterEvent, events, "ITEM_SEARCH_RESULTS_ADDED")
events:RegisterEvent("BAG_UPDATE_DELAYED")
pcall(events.RegisterEvent, events, "AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
events:RegisterEvent("PLAYER_MONEY")
events:SetScript("OnEvent", function(_, event, arg)
  if event == "AUCTION_HOUSE_SHOW" then
    Install()
    C_Timer.After(0, SellForm.Update)
  elseif event == "AUCTION_HOUSE_CLOSED" then
    if item then
      Clear()
    end
  elseif not item then
    return
  elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
    if item.commodity and arg == item.itemId then
      ReadCommodities()
      OnResults()
    end
  elseif event == "ITEM_SEARCH_RESULTS_UPDATED" or event == "ITEM_SEARCH_RESULTS_ADDED" then
    if not item.commodity and type(arg) == "table" and arg.itemID == item.itemId then
      item.resultKey = arg
      ReadItems(arg)
      OnResults()
    end
  elseif event == "BAG_UPDATE_DELAYED" then
    if postedAt then
      AfterPost()
    elseif not ResolveLocation() then
      Clear()
    else
      SetQuantity(math.min(quantity, GetMaxQuantity()))
    end
  else
    UpdateTotals()
  end
end)

-- Our own window covers the sell view of the game.
AM.Events.Register("MAIN_WINDOW_VISIBILITY", SellForm.Update)
