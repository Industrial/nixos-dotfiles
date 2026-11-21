local addonName, AM = ...
local L = AM.L

-- The "Ledger" view of the main window: how the player's own auctions went (AM.Ledger), for a time range and a
-- character. On top the summary figures of the range in one strip of six tiles, below them one of three views,
-- switched by the auction house's own top tabs on their frame: Overview (the net per day as a bar chart and what
-- stands out among the items, facts only), Items (every item with its totals, sorted by net gold: top sellers first,
-- top losers last) and Journal (every event, grouped by day with the day's net; a filter menu picks the kinds of
-- event). Nothing is guessed: a deposit the ledger does not know is marked, never filled in. The time range, the
-- character, the view shown and the kinds of event hidden are kept in the global object "mainWindow" (view filters).
-- A click on an item, a finding or an event opens the item's details beside the auction house (gold, quantities, its
-- latest events), like the recipe details.
-- Plan and design: doc/notes/ledger.md.
-- The Overview is in LedgerOverview.lua, the item details in LedgerDetail.lua; they share AM.LedgerView with this file.
local Widgets = AM.Widgets
local Native = AM.Native
local Ledger = AM.Ledger
local UI = AM.Theme.ui
AM.LedgerView = { ui = {}, state = {} }
local View = AM.LedgerView
local state = View.state
state.details = {}

local ROW_HEIGHT = Native.ROW_HEIGHT
local DAY = 24 * 3600
local TILE_HEIGHT = 46
local TILE_PADDING = 6
-- The net tile is this much wider than the others.
local NET_WEIGHT = 1.6
-- The last tile of the net and what makes it up; after it a wider gap and a stronger line set the other figures apart.
local GROUP_END = 4
local GROUP_GAP = 10
local FILTERS_TOP = 16
local TILES_TOP = 48
-- The top tabs are 32 high with their art in the lower part. As in the Auctions view (list at the tab bottom +2 -1,
-- headers 1 below it), the headers start exactly at the tabs' bottom, so their bright top edge shows as a line below
-- the tabs instead of being covered by them.
local TABS_TOP = TILES_TOP + TILE_HEIGHT
local LIST_TOP = TABS_TOP + 31
local COLUMN_GAP = 6
local COLUMN_PADDING = 8

-- The columns of a list from the right edge of a row: width and header of each. The name takes up the rest.
local ITEM_COLUMNS = {
  order = { "net", "lost", "cost", "revenue", "rate", "unsold", "sold" },
  width = { net = 100, lost = 90, cost = 90, revenue = 96, rate = 44, unsold = 52, sold = 48 },
  title = { net = "LEDGER_COL_NET", lost = "LEDGER_COL_LOST", cost = "LEDGER_COL_COST", revenue = "LEDGER_COL_REVENUE",
    rate = "LEDGER_COL_RATE", unsold = "LEDGER_COL_UNSOLD", sold = "LEDGER_COL_SOLD" },
}
local JOURNAL_COLUMNS = {
  order = { "net", "price", "type" },
  width = { net = 100, price = 96, type = 110 },
  title = { net = "LEDGER_COL_NET", price = "LEDGER_COL_PRICE", type = "LEDGER_COL_TYPE" },
}
-- The journal's time column, left of the item.
local TIME_WIDTH = 38

-- The kinds of event, in the order of the filter menu.
local TYPES = {
  { type = Ledger.CREATED, label = "LEDGER_TYPE_CREATED" },
  { type = Ledger.SOLD, label = "LEDGER_TYPE_SOLD" },
  { type = Ledger.CANCELED, label = "LEDGER_TYPE_CANCELED" },
  { type = Ledger.EXPIRED, label = "LEDGER_TYPE_EXPIRED" },
  { type = Ledger.UNKNOWN, label = "LEDGER_TYPE_UNKNOWN" },
  { type = Ledger.BOUGHT, label = "LEDGER_TYPE_BOUGHT" },
  { type = Ledger.VENDOR_SOLD, label = "LEDGER_TYPE_VENDOR_SOLD" },
  { type = Ledger.VENDOR_BOUGHT, label = "LEDGER_TYPE_VENDOR_BOUGHT" },
  { type = Ledger.JUNK_SOLD, label = "LEDGER_TYPE_JUNK_SOLD" },
  { type = Ledger.CRAFTED, label = "LEDGER_TYPE_CRAFTED" },
  { type = Ledger.DISENCHANTED, label = "LEDGER_TYPE_DISENCHANTED" },
  { type = Ledger.LOOTED, label = "LEDGER_TYPE_LOOTED" },
  { type = Ledger.USED_UP, label = "LEDGER_TYPE_USED_UP" },
}
local TYPE_LABEL = {}
for _, entry in ipairs(TYPES) do
  TYPE_LABEL[entry.type] = entry.label
end

-- the views, also the ids of their tabs, and how each is saved in ledgerView (the Overview is the default)
local VIEW_OVERVIEW, VIEW_ITEMS, VIEW_JOURNAL = 1, 2, 3
local VIEW_SETTING = { [VIEW_ITEMS] = "items", [VIEW_JOURNAL] = "journal" }

local FINDING_HEIGHT = 42

-- The time ranges to pick from: id (saved), label, and the start of the range for a time.
local RANGES = {
  { id = "today", label = "LEDGER_RANGE_TODAY", from = function(now)
    local day = date("*t", now)
    return time({ year = day.year, month = day.month, day = day.day, hour = 0 })
  end },
  { id = "week", label = "LEDGER_RANGE_WEEK", from = function(now) return now - 7 * DAY end },
  { id = "month", label = "LEDGER_RANGE_MONTH", from = function(now) return now - 30 * DAY end },
  { id = "all", label = "LEDGER_RANGE_ALL", from = function() return nil end },
}
local DEFAULT_RANGE = "month"

local CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
-- the junk sold in one visit to a merchant has no item of its own: a row with the merchant's icon
local JUNK_ICON = "Interface\\GossipFrame\\VendorGossipIcon"


local panel
local ui = View.ui
local visible = {}
local known = {} -- the itemIDs listed, to tell whether arriving item data concerns us
-- the totals of the items whose details the view can show, by itemDbKey, and the item lookup of the last refresh

local function GetSettings()
  return AM.Database.GetGlobalObject("mainWindow")
end

local function GetView()
  for view, setting in pairs(VIEW_SETTING) do
    if GetSettings().ledgerView == setting then
      return view
    end
  end
  return VIEW_OVERVIEW
end

-- The kinds of event the player switched off in the journal (type -> true).
local function GetHidden()
  local settings = GetSettings()
  settings.ledgerHidden = settings.ledgerHidden or {}
  return settings.ledgerHidden
end

local function Muted(text)
  return Widgets.Color(UI.muted, text)
end

-- A sum the ledger knows, also when it is nothing (AM.FormatMoney shows nothing as "--", which means unknown here).
-- With short, gold from 1000 on is shortened ("12.3k"), for a tile too narrow for the full sum.
local function Money(copper, short)
  return copper > 0 and AM.FormatMoney(copper, short) or AM.ZERO_MONEY
end

local function Loss(copper, short)
  return Widgets.Color(UI.loss, "-" .. AM.FormatMoney(copper, short))
end

local function Signed(copper, short)
  if copper > 0 then
    return Widgets.Color(UI.gain, "+" .. AM.FormatMoney(copper, short))
  elseif copper < 0 then
    return Loss(-copper, short)
  end
  return Muted(AM.ZERO_MONEY)
end

-- The marker of a sum that lacks deposits the ledger does not know.
local function Incomplete(totals)
  return totals.unknownLosses > 0 and Muted(" ?") or ""
end

local function Percent(rate)
  return math.floor(rate * 100 + 0.5) .. "%"
end

local function FindRange(id)
  for _, range in ipairs(RANGES) do
    if range.id == id then
      return range
    end
  end
  return nil
end

local function GetRange()
  return FindRange(GetSettings().ledgerRange) or FindRange(DEFAULT_RANGE)
end

-- Name, icon and quality of the item of an itemDbKey; the name is nil until the game has loaded the item.
local function GetItem(itemDbKey)
  local itemId = AM.ItemDbKey.GetItemId(itemDbKey)
  local species = tonumber(itemDbKey:match(":p(%d+)"))
  if species and C_PetJournal and C_PetJournal.GetPetInfoBySpeciesID then
    local name, icon = C_PetJournal.GetPetInfoBySpeciesID(species)
    return itemId, name, icon, nil
  end
  local name, _, quality = C_Item.GetItemInfo(itemId)
  if not name then
    C_Item.RequestLoadItemDataByID(itemId)
  end
  return itemId, name, select(5, C_Item.GetItemInfoInstant(itemId)), quality
end

-- The item of an itemDbKey for a row, looked up once per refresh: { itemId, name, icon, quality, pet }.
local function ItemCache()
  local cache = {}
  return function(itemDbKey)
    local item = cache[itemDbKey]
    if not item then
      local itemId, name, icon, quality = GetItem(itemDbKey)
      item = { itemId = itemId, name = name, icon = icon, quality = quality, pet = itemDbKey:find(":p") ~= nil }
      cache[itemDbKey] = item
      known[itemId] = true
    end
    return item
  end
end

local function Matches(item, query)
  return query == "" or (item.name and item.name:lower():find(query, 1, true)) ~= nil
end

-- The junk row of the journal, as an item of ItemCache (no itemId: no tooltip, no details).
local function JunkItem()
  return { name = L["LEDGER_JUNK"], icon = JUNK_ICON, quality = 0 }
end

-- The name of a character in its color; unknown ones muted.
local function CharacterName(guid)
  local name = AM.Characters.Get(guid)
  if not name then
    return Muted(L["LEDGER_UNKNOWN_CHARACTER"])
  end
  return Widgets.Color(UI.crafter, name)
end

-- The short date of a time, without the year unless asked for.
local function ShortDate(at, withYear)
  local day = date("*t", at)
  if FormatShortDate then
    return FormatShortDate(day.day, day.month, withYear and day.year or nil)
  end
  return date(withYear and "%Y-%m-%d" or "%m-%d", at)
end

-- "Today", "Yesterday" or the weekday and date of a day of the journal.
local function DayLabel(day)
  local today = date("*t", time())
  local yesterday = date("*t", time() - DAY)
  local function Key(at)
    return at.year * 10000 + at.month * 100 + at.day
  end
  if day.key == Key(today) then
    return L["LEDGER_TODAY"]
  elseif day.key == Key(yesterday) then
    return L["LEDGER_YESTERDAY"]
  end
  local shown = ShortDate(day.time, true)
  local weekday = CALENDAR_WEEKDAY_NAMES and CALENDAR_WEEKDAY_NAMES[date("*t", day.time).wday]
  return weekday and (weekday .. ", " .. shown) or shown
end

-- Data ------------------------------------------------------------------------------------------------

-- The characters of the ledger for the dropdown; a selected one that has no events any more is dropped.
local function GetCharacterChoices()
  local settings = GetSettings()
  local choices, found = {}, false
  for _, guid in ipairs(Ledger.GetCharacters()) do
    local name, class = AM.Characters.Get(guid)
    local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    choices[#choices + 1] = { value = guid, label = Widgets.Color(UI.crafter, name or L["LEDGER_UNKNOWN_CHARACTER"]),
      icon = coords and CLASS_ICONS or nil, iconCoords = coords, sortName = name or "" }
    found = found or guid == settings.ledgerWho
  end
  table.sort(choices, function(a, b)
    if a.sortName ~= b.sortName then
      return a.sortName < b.sortName
    end
    return a.value < b.value
  end)
  table.insert(choices, 1, { label = L["RECIPES_ALL"] })
  settings.ledgerWho = found and settings.ledgerWho or nil
  return choices
end

-- The item summaries of the range whose name matches the search; the details of each of them can be shown.
local function CollectSummaries(from, who, query, lookup)
  local list = {}
  for _, totals in ipairs(Ledger.GetItemSummaries(from, nil, who)) do
    if Matches(lookup(totals.item), query) then
      list[#list + 1] = totals
      state.details[totals.item] = totals
    end
  end
  return list
end

-- The items list: the items that were traded, not those only looted (their details still open from the Journal).
local function CollectItems(from, who, query, lookup)
  for _, totals in ipairs(CollectSummaries(from, who, query, lookup)) do
    if totals.traded then
      visible[#visible + 1] = { height = ROW_HEIGHT, totals = totals, item = lookup(totals.item) }
    end
  end
end

-- The findings of the Overview, among the items the search matches; the chart, like the tiles, takes all of them.
local function CollectOverview(from, who, query, lookup)
  for _, finding in ipairs(Ledger.GetFindings(CollectSummaries(from, who, query, lookup))) do
    local items = {}
    for index, key in ipairs(finding.items) do
      items[index] = lookup(key)
    end
    visible[#visible + 1] = { height = FINDING_HEIGHT, finding = finding, items = items }
  end
  ui.series = Ledger.GetNetSeries(from, who)
end

-- The journal as rows: a row per day, followed by a row per event of that day.
local function CollectJournal(from, who, query, lookup)
  local hidden = GetHidden()
  local days = Ledger.GetJournal(from, nil, who, function(kind, itemDbKey)
    return not hidden[kind] and Matches(itemDbKey and lookup(itemDbKey) or JunkItem(), query)
  end)
  for _, day in ipairs(days) do
    visible[#visible + 1] = { height = ROW_HEIGHT, day = day }
    for _, entry in ipairs(day.entries) do
      visible[#visible + 1] = { height = ROW_HEIGHT, entry = entry,
        item = entry.item and lookup(entry.item) or JunkItem() }
    end
  end
end

local function Collect()
  local settings = GetSettings()
  local from = GetRange().from(time())
  local query = ui.query or ""
  visible, known, state.details = {}, {}, {}
  local lookup = ItemCache()
  state.lookupItem = lookup
  local view = GetView()
  if view == VIEW_JOURNAL then
    CollectJournal(from, settings.ledgerWho, query, lookup)
    CollectSummaries(from, settings.ledgerWho, query, lookup) -- the details of the items of the events
  elseif view == VIEW_OVERVIEW then
    CollectOverview(from, settings.ledgerWho, query, lookup)
  else
    CollectItems(from, settings.ledgerWho, query, lookup)
  end
  -- a selected item that is not listed any more is dropped
  state.selectedKey = state.selectedKey and state.details[state.selectedKey] and state.selectedKey or nil
  return Ledger.GetSummary(from, nil, settings.ledgerWho)
end

-- Summary tiles ---------------------------------------------------------------------------------------

-- A tile is one cell of the summary strip: its label and one figure. On hover it explains the label (hint, a locale
-- key, optional) and shows a detail behind the figure (tile.tooltip). The figures of all tiles stand on one baseline;
-- valueFont makes the lead figure larger.
local function CreateTile(parent, label, hint, valueFont)
  local tile = CreateFrame("Frame", nil, parent)
  tile.label = Widgets.CreateText(tile, "GameFontNormal")
  tile.label:SetPoint("TOPLEFT", TILE_PADDING, -6)
  tile.label:SetPoint("TOPRIGHT", -TILE_PADDING, -6)
  tile.label:SetJustifyH("CENTER")
  tile.label:SetWordWrap(false)
  tile.label:SetText(L[label])
  tile.value = Widgets.CreateText(tile, valueFont or Native.Font("Number15FontWhite", "GameFontHighlight"))
  tile.value:SetPoint("BOTTOMLEFT", TILE_PADDING, 6)
  tile.value:SetPoint("BOTTOMRIGHT", -TILE_PADDING, 6)
  tile.value:SetJustifyH("CENTER")
  tile.value:SetWordWrap(false)
  tile:EnableMouse(true)
  tile:SetScript("OnEnter", function(self)
    if hint then
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:SetText(L[label])
      GameTooltip:AddLine(L[hint], 1, 1, 1, true)
      if self.tooltip then
        GameTooltip:AddLine(self.tooltip, 1, 1, 1, true)
      end
      GameTooltip:Show()
    elseif self.tooltip then
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:SetText(self.tooltip, 1, 1, 1)
      GameTooltip:Show()
    end
  end)
  tile:SetScript("OnLeave", GameTooltip_Hide)
  return tile
end

-- A vertical line between two tiles.
local function CreateDivider(parent, color, width)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(unpack(color))
  line:SetWidth(width)
  return line
end

local function CreateTiles()
  -- one sunken strip for all tiles, split by thin lines, instead of a frame around each
  local strip = Native.CreateInset(panel, true)
  strip:SetPoint("TOPLEFT", 16, -TILES_TOP)
  strip:SetPoint("TOPRIGHT", -16, -TILES_TOP)
  strip:SetHeight(TILE_HEIGHT)
  -- the net leads as the key number, followed by what makes it up: revenue less lost deposits and the cost of the
  -- goods (the fees, always the same share of the revenue, are in the net's tooltip); apart from these, as figures of
  -- another kind, the stock (bought, not sold yet: tied up, not lost) and the sell rate
  ui.tiles = {
    CreateTile(strip, "LEDGER_NET", "LEDGER_NET_HINT", Native.Font("Number18FontWhite", "GameFontHighlightLarge")),
    CreateTile(strip, "LEDGER_REVENUE", "LEDGER_REVENUE_HINT"),
    CreateTile(strip, "LEDGER_LOST", "LEDGER_LOST_HINT"),
    CreateTile(strip, "LEDGER_COST", "LEDGER_COST_HINT"),
    CreateTile(strip, "LEDGER_STOCK", "LEDGER_STOCK_HINT"),
    CreateTile(strip, "LEDGER_RATE"),
  }
  -- the share of the strip's width of each tile: the net is wider
  local weights = { NET_WEIGHT, 1, 1, 1, 1, 1 }
  local dividers = {}
  for index = 1, #ui.tiles - 1 do
    if index == GROUP_END then
      dividers[index] = CreateDivider(strip, UI.border, 2)
    else
      dividers[index] = CreateDivider(strip, UI.buttonBorder, 1)
    end
  end
  strip:SetScript("OnSizeChanged", function(self, width)
    local inner = width - 2 * Native.PANEL_INSET
    local total = 0
    for _, weight in ipairs(weights) do
      total = total + weight
    end
    local unit = (inner - GROUP_GAP) / total
    local left = Native.PANEL_INSET
    for index, tile in ipairs(ui.tiles) do
      local tileWidth = weights[index] * unit
      tile:ClearAllPoints()
      tile:SetPoint("TOPLEFT", left, -Native.PANEL_INSET)
      tile:SetPoint("BOTTOMLEFT", left, Native.PANEL_INSET)
      tile:SetWidth(tileWidth)
      left = left + tileWidth
      local divider = dividers[index]
      if divider then
        -- between the groups the line stands in the middle of a wider gap
        local gap = index == GROUP_END and GROUP_GAP or 0
        divider:ClearAllPoints()
        divider:SetPoint("TOP", self, "TOPLEFT", left + gap / 2, -Native.PANEL_INSET - 4)
        divider:SetPoint("BOTTOM", self, "BOTTOMLEFT", left + gap / 2, Native.PANEL_INSET + 4)
        left = left + gap
      end
    end
    if ui.summary then
      ui.UpdateTiles(ui.summary)
    end
  end)
end

-- The money figures of the tiles, shortened all together when one of them does not fit in full.
local function SetMoneyTiles(summary, short)
  local net, revenue, lost, cost, stock = unpack(ui.tiles)
  revenue.value:SetText(Money(summary.revenue, short))
  cost.value:SetText(summary.cost > 0 and ("-" .. AM.FormatMoney(summary.cost, short)) or AM.ZERO_MONEY)
  lost.value:SetText((summary.lostDeposits > 0 and Loss(summary.lostDeposits, short) or AM.ZERO_MONEY) .. Incomplete(summary))
  net.value:SetText(Signed(summary.net, short) .. Incomplete(summary))
  stock.value:SetText(Money(summary.stock, short))
  for index = 1, 5 do
    if ui.tiles[index].value:IsTruncated() then
      return false
    end
  end
  return true
end

-- The stock tile's tooltip: how many items, what they sell for now (information only, never part of Net) and how many
-- of them have no price that is known now.
local function StockTooltip(count)
  local worth, noPrice = 0, 0
  for _, entry in ipairs(Ledger.GetStock(GetSettings().ledgerWho)) do
    local value = AM.RecipeCost.GetSellValue(entry.item)
    if value then
      worth = worth + value * entry.count
    else
      noPrice = noPrice + entry.count
    end
  end
  local lines = { L["LEDGER_STOCK_OF"]:format(count) }
  if worth > 0 then
    lines[#lines + 1] = L["LEDGER_STOCK_WORTH"]:format(AM.FormatMoney(worth))
  end
  if noPrice > 0 then
    lines[#lines + 1] = L["LEDGER_STOCK_NO_PRICE"]:format(noPrice)
  end
  return table.concat(lines, "\n")
end

function ui.UpdateTiles(summary)
  ui.summary = summary
  local net, revenue, lost, cost, stock, rate = unpack(ui.tiles)
  if not SetMoneyTiles(summary, false) then
    SetMoneyTiles(summary, true)
  end
  cost.tooltip = summary.uncostedCount > 0 and L["LEDGER_COST_UNKNOWN"]:format(summary.uncostedCount) or nil
  -- what of the revenue came from merchants
  local parts = {}
  if summary.vendorRevenue > 0 then
    parts[#parts + 1] = L["LEDGER_REVENUE_VENDOR"]:format(AM.FormatMoney(summary.vendorRevenue))
  end
  revenue.tooltip = #parts > 0 and table.concat(parts, "\n") or nil
  local unknown = summary.unknownLosses > 0 and L["LEDGER_NET_INCOMPLETE"]:format(summary.unknownLosses) or nil
  lost.tooltip = unknown
  net.tooltip = L["LEDGER_NET_FEES"]:format(summary.fees > 0 and ("-" .. AM.FormatMoney(summary.fees)) or AM.ZERO_MONEY)
    .. (unknown and ("\n" .. unknown) or "")
  stock.tooltip = summary.stockCount > 0 and StockTooltip(summary.stockCount) or nil
  if summary.sellRate then
    rate.value:SetText(Percent(summary.sellRate))
    rate.tooltip = L["LEDGER_RATE_OF"]:format(summary.soldCount, summary.soldCount + summary.unsoldCount)
  else
    rate.value:SetText(Muted("--"))
    rate.tooltip = L["LEDGER_RATE_NONE"]
  end
end

-- Lists -----------------------------------------------------------------------------------------------

local function ShowItemTooltip(owner, item)
  if item.pet or not item.itemId then
    return
  end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetHyperlink("item:" .. item.itemId)
  GameTooltip:Show()
end

-- The right-aligned cells of a row, by column; returns how far from the right edge they reach.
local function CreateCells(row, columns)
  row.cells = {}
  local right = COLUMN_PADDING
  for _, column in ipairs(columns.order) do
    local cell = Widgets.CreateText(row, Native.RowFont(), "RIGHT")
    cell:SetWordWrap(false)
    cell:SetWidth(columns.width[column])
    cell:SetPoint("RIGHT", row, "RIGHT", -right, 0)
    row.cells[column] = cell
    right = right + columns.width[column] + COLUMN_GAP
  end
  return right
end

-- Icon and name of the item of a row, left at `left`, up to `right` from the right edge.
local function CreateItemCell(row, left, right)
  row.icon = Native.CreateItemIcon(row)
  row.icon:SetPoint("LEFT", left, 0)
  row.name = Widgets.CreateText(row, Native.RowFont())
  row.name:SetWordWrap(false)
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetPoint("RIGHT", row, "RIGHT", -right, 0)
  row.hover = Widgets.CreateItemHover(row, function(self)
    ShowItemTooltip(self.icon, self.item)
  end, GameTooltip_Hide)
end

local function SetupItemCell(row, item, count)
  row.item = item
  row.icon:SetTexture(item.icon)
  local color = ITEM_QUALITY_COLORS[item.quality or 1] or ITEM_QUALITY_COLORS[1]
  row.name:SetTextColor(color.r, color.g, color.b)
  row.name:SetText((item.name or "...") .. (count and count > 1 and Muted(" x" .. count) or ""))
  row.hover.Fit(row.icon, row.name)
end

local Refresh

local function CreateItemRow(parent)
  local row = CreateFrame("Button", nil, parent)
  Native.StyleRow(row)
  CreateItemCell(row, 8, CreateCells(row, ITEM_COLUMNS))
  row:SetScript("OnClick", function(self)
    -- a second click on the row closes the details again
    state.selectedKey = state.selectedKey ~= self.key and self.key or nil
    Refresh()
  end)
  return row
end

local function SetupItemRow(row, entry, index)
  row.key = entry.totals.item
  Native.SetRowState(row, index, row.key == state.selectedKey)
  SetupItemCell(row, entry.item)
  local totals, cells = entry.totals, row.cells
  cells.sold:SetText(totals.soldCount > 0 and totals.soldCount or Muted("--"))
  cells.unsold:SetText(totals.unsoldCount > 0 and totals.unsoldCount or Muted("--"))
  cells.rate:SetText(totals.sellRate and Percent(totals.sellRate) or Muted("--"))
  -- amounts of nothing stay empty, so the ones that count stand out
  cells.revenue:SetText(totals.revenue > 0 and AM.FormatMoney(totals.revenue) or "")
  cells.cost:SetText(totals.cost > 0 and ("-" .. AM.FormatMoney(totals.cost)) or "")
  cells.lost:SetText((totals.lostDeposits > 0 and Loss(totals.lostDeposits) or "") .. Incomplete(totals))
  cells.net:SetText(Signed(totals.net) .. Incomplete(totals))
end

-- A journal row is either a day (its name and net, in the header font) or an event of that day.
-- The texts of a journal entry (Ledger.GetJournal), also used by the Sell tab's history: its kind (muted where no
-- gold moves), its price and the net it adds (nil where there is none).
local function EventType(event)
  local muted = event.type == Ledger.CREATED or event.type == Ledger.UNKNOWN or event.type == Ledger.CRAFTED
    or event.type == Ledger.LOOTED or event.type == Ledger.USED_UP or event.type == Ledger.DISENCHANTED
  return muted and Muted(L[TYPE_LABEL[event.type]]) or L[TYPE_LABEL[event.type]]
end

local function EventPrice(event)
  -- the price asked for a post, the price paid for a sale or by the player for a purchase; a return's price is only
  -- what it did not sell at
  if event.type ~= Ledger.CANCELED and event.type ~= Ledger.EXPIRED and event.type ~= Ledger.UNKNOWN and event.price then
    return AM.FormatMoney(event.price)
  elseif (event.type == Ledger.CRAFTED or event.type == Ledger.USED_UP or event.type == Ledger.DISENCHANTED)
    and event.cost > 0 then
    -- what the reagents cost, moved to the crafted items, what a disenchanted item cost, moved to its materials, or
    -- what the used up units cost: no price, no net
    return Muted(AM.FormatMoney(event.cost))
  end
end

local function EventNet(event)
  if event.net then
    return Signed(event.net)
  elseif event.unknown then
    return Muted("?")
  end
end

local function CreateJournalRow(parent)
  local row = CreateFrame("Button", nil, parent)
  Native.StyleRow(row)
  row.time = Widgets.CreateText(row, Native.RowFont())
  row.time:SetPoint("LEFT", 8, 0)
  row.time:SetWidth(TIME_WIDTH)
  local right = CreateCells(row, JOURNAL_COLUMNS)
  CreateItemCell(row, 8 + TIME_WIDTH + COLUMN_GAP, right)
  row.dayName = Widgets.CreateText(row, "GameFontNormal")
  row.dayName:SetPoint("LEFT", 8, 0)
  row.dayName:SetPoint("RIGHT", row, "RIGHT", -right, 0)
  row.dayName:SetWordWrap(false)
  row:SetScript("OnClick", function(self)
    -- a second click on an event of the item closes the details again
    state.selectedKey = state.selectedKey ~= self.key and self.key or nil
    Refresh()
  end)
  return row
end

local function SetupJournalRow(row, entry, index)
  local cells = row.cells
  for _, cell in pairs(cells) do
    cell:SetText("")
  end
  local day = entry.day
  -- a day is a heading, not an entry: no stripe, no glow under the mouse
  row:EnableMouse(not day)
  row.stripe:SetShown(not day)
  row.dayName:SetShown(day ~= nil)
  row.time:SetShown(not day)
  row.icon:SetShown(not day)
  if row.icon.border then
    row.icon.border:SetShown(not day)
  end
  row.name:SetShown(not day)
  row.hover:SetShown(not day)
  row.key = entry.entry and entry.entry.item
  -- every event of the selected item is marked
  Native.SetRowState(row, index, row.key ~= nil and row.key == state.selectedKey)
  if day then
    row.dayName:SetText(DayLabel(day))
    cells.net:SetText(Signed(day.net) .. Incomplete(day))
    return
  end
  local event = entry.entry
  row.time:SetText(Muted(date("%H:%M", event.time)))
  SetupItemCell(row, entry.item, event.count)
  cells.type:SetText(EventType(event))
  cells.price:SetText(EventPrice(event) or "")
  cells.net:SetText(EventNet(event) or "")
end

-- How far a header reaches under its left neighbour, as in the auction house (SetColumnHeaderOverlap(2)): the edges of
-- the two meet in one line instead of two.
local HEADER_OVERLAP = 2

-- The column headers of a list, laid out as the game's table builder does: the headers fill the strip from edge to
-- edge (the strip is as wide as the rows), the border between two lies in the middle of the gap between their cells,
-- and each reaches HEADER_OVERLAP under its left neighbour, drawn above it. leftTitle/leftWidth: a column left of the
-- item (the journal's time). The headers do not sort.
local function CreateHeaders(header, columns, leftTitle, leftWidth)
  local count = #columns.order
  -- from left to right, each one level above the one on its left
  local level = header:GetFrameLevel() + 1
  local function Place(button, left, right)
    button:SetFrameLevel(level + left.index)
    button:SetHeight(Native.HEADER_HEIGHT)
    if left.frame then
      button:SetPoint("LEFT", left.frame, "RIGHT", -HEADER_OVERLAP, 0)
    else
      button:SetPoint("LEFT")
    end
    button:SetPoint("RIGHT", header, "RIGHT", -right, 0)
  end
  -- the borders between the headers, as distances from the right edge: border[i] is the left edge of the i-th column
  -- from the right
  local border, right = {}, COLUMN_PADDING
  for index, column in ipairs(columns.order) do
    right = right + columns.width[column]
    border[index] = right + COLUMN_GAP / 2
    right = right + COLUMN_GAP
  end
  local previous = { index = 0 }
  if leftTitle then
    local left = Native.CreateHeaderButton(header, L[leftTitle], false)
    left:SetFrameLevel(level)
    left:SetPoint("LEFT")
    left:SetSize(COLUMN_PADDING + leftWidth + COLUMN_GAP / 2, Native.HEADER_HEIGHT)
    previous = { index = 1, frame = left }
  end
  local itemTitle = Native.CreateHeaderButton(header, L["LEDGER_COL_ITEM"], false)
  Place(itemTitle, previous, border[count])
  previous = { index = previous.index + 1, frame = itemTitle }
  for index = count, 1, -1 do
    local column = columns.order[index]
    local button = Native.CreateHeaderButton(header, L[columns.title[column]], false)
    Place(button, previous, border[index - 1] or 0)
    previous = { index = previous.index + 1, frame = button }
  end
end

-- A list panel down to the bottom edge of the window, laid out as the game's item lists (the Bids list under the top
-- tabs of its Auctions view): the headers on the window's background, the sunken panel below them.
local function CreateListPanel(columns, createRow, setupRow, leftTitle, leftWidth)
  local native = Native.CreateListPanel(panel, true)
  native.frame:SetPoint("TOPLEFT", 16, -LIST_TOP)
  native.frame:SetPoint("BOTTOMRIGHT", -16, -1)
  CreateHeaders(native.header, columns, leftTitle, leftWidth)
  local list = Widgets.CreateList(native.body, createRow, setupRow)
  list:SetAllPoints(native.body)
  local empty = Widgets.CreateText(native.body, "GameFontDisableSmall")
  empty:SetPoint("TOPLEFT", 12, -12)
  empty:SetPoint("TOPRIGHT", -12, -12)
  empty:SetWordWrap(true)
  return { frame = native.frame, list = list, empty = empty }
end

-- Filters ---------------------------------------------------------------------------------------------

-- The journal's filter menu at the right end of the filter bar: a checkbox per kind of event. The menu stays open
-- while toggling; the button shows how many kinds are switched off.
local function CreateTypeMenu()
  local button = CreateFrame("DropdownButton", nil, ui.filters, "WowStyle1FilterDropdownTemplate")
  ui.typeMenu = button
  button:SetWidth(110)
  button:SetPoint("RIGHT", 0, 0)
  button:SetupMenu(function(_, root)
    for _, entry in ipairs(TYPES) do
      root:CreateCheckbox(L[entry.label], function()
        return not GetHidden()[entry.type]
      end, function()
        local hidden = GetHidden()
        hidden[entry.type] = not hidden[entry.type] or nil
        Refresh()
      end)
    end
  end)
end

local function UpdateTypeMenu()
  local off = 0
  for _, entry in ipairs(TYPES) do
    off = off + (GetHidden()[entry.type] and 1 or 0)
  end
  ui.typeMenu:SetText(off > 0 and (L["RECIPES_FILTERS"] .. " (" .. off .. ")") or L["RECIPES_FILTERS"])
  ui.typeMenu:SetShown(GetView() == VIEW_JOURNAL)
end

local function CreateFilters()
  ui.filters = CreateFrame("Frame", nil, panel)
  ui.filters:SetPoint("TOPLEFT", 16, -FILTERS_TOP)
  ui.filters:SetPoint("TOPRIGHT", -16, -FILTERS_TOP)
  ui.filters:SetHeight(24)

  local search = CreateFrame("EditBox", nil, ui.filters, "SearchBoxTemplate")
  ui.search = search
  search:SetSize(200, 22)
  search:SetPoint("LEFT", AM.MainWindow.PortraitInset(), 0)
  search:SetAutoFocus(false)
  if search.Instructions then
    search.Instructions:SetText(L["LEDGER_SEARCH"])
  end
  -- HookScript: the template's own scripts show the hint and the clear button
  search:HookScript("OnTextChanged", function(self)
    ui.query = self:GetText():lower()
    if panel:IsVisible() then
      Refresh()
    end
  end)

  ui.rangeDropdown = Widgets.CreateDropdown(ui.filters, 130, function(value)
    GetSettings().ledgerRange = value
    Refresh()
  end)
  ui.rangeDropdown.button:SetPoint("LEFT", search, "RIGHT", 12, 0)
  ui.characterDropdown = Widgets.CreateDropdown(ui.filters, 150, function(value)
    GetSettings().ledgerWho = value
    Refresh()
  end)
  ui.characterDropdown.button:SetPoint("LEFT", ui.rangeDropdown.button, "RIGHT", 8, 0)
  CreateTypeMenu()
end

local function UpdateFilters()
  local choices = {}
  for _, range in ipairs(RANGES) do
    choices[#choices + 1] = { value = range.id, label = L[range.label] }
  end
  ui.rangeDropdown.SetChoices(choices, GetRange().id)
  ui.characterDropdown.SetChoices(GetCharacterChoices(), GetSettings().ledgerWho)
  UpdateTypeMenu()
end

-- Overview / Items / Journal: the top tabs of the auction house's Auctions view (Auctions / Bids), which handle their
-- own looks (PanelTemplates); the plain top tab where that template is missing.
local function CreateTabs()
  ui.tabs = CreateFrame("Frame", nil, panel)
  ui.tabs:SetPoint("TOPLEFT", 20, -TABS_TOP)
  ui.tabs:SetSize(1, 32)
  for id, label in ipairs({ "LEDGER_VIEW_OVERVIEW", "LEDGER_VIEW_ITEMS", "LEDGER_VIEW_JOURNAL" }) do
    local ok, tab = pcall(CreateFrame, "Button", nil, ui.tabs, "AuctionHouseFrameTopTabTemplate")
    if not ok then
      tab = CreateFrame("Button", nil, ui.tabs, "PanelTopTabButtonTemplate")
    end
    tab:SetID(id)
    tab:SetText(L[label])
    PanelTemplates_TabResize(tab, 20, nil, 70)
    tab:HookScript("OnClick", function(self)
      GetSettings().ledgerView = VIEW_SETTING[self:GetID()]
      Refresh()
    end)
  end
  -- Mainline's tab template lists itself in the parent's Tabs and PanelTemplates_SetNumTabs lines them up; Classic's
  -- does neither, so the tabs are listed and anchored as in its Auctions view (each 3 px into the previous one).
  if not ui.tabs.Tabs then
    ui.tabs.Tabs = { ui.tabs:GetChildren() }
    for i = 2, #ui.tabs.Tabs do
      ui.tabs.Tabs[i]:SetPoint("LEFT", ui.tabs.Tabs[i - 1], "RIGHT", -3, 0)
    end
  end
  ui.tabs.Tabs[1]:SetPoint("TOPLEFT")
  PanelTemplates_SetNumTabs(ui.tabs, #ui.tabs.Tabs)
end

-- View ------------------------------------------------------------------------------------------------

function Refresh()
  UpdateFilters() -- first, it drops a character that has no events any more
  local view = GetView()
  PanelTemplates_SetTab(ui.tabs, view)
  local summary = Collect()
  ui.UpdateTiles(summary)
  local views = { [VIEW_OVERVIEW] = ui.overview, [VIEW_ITEMS] = ui.items, [VIEW_JOURNAL] = ui.journal }
  for id, other in pairs(views) do
    other.frame:SetShown(id == view)
  end
  local shown = views[view]
  shown.list.SetItems(visible)
  if view == VIEW_OVERVIEW then
    View.DrawChart(shown.chart)
  end
  if #visible > 0 then
    shown.empty:SetText("")
  elseif Ledger.IsEmpty() then
    shown.empty:SetText(L["LEDGER_EMPTY"])
  elseif view == VIEW_OVERVIEW and (ui.query or "") == "" then
    -- nothing stands out: the chart says it all
    shown.empty:SetText("")
  else
    shown.empty:SetText(L["LEDGER_NONE"])
  end
  View.UpdateDetail(view)
end

local function Create(parent)
  panel = CreateFrame("Frame", nil, parent)
  state.panel = panel
  -- no half slid details after the panel was hidden in the middle of a slide
  panel:SetScript("OnShow", function()
    ui.attachment.Sync()
  end)
  panel:SetScript("OnHide", function()
    ui.attachment.Hide()
  end)
  CreateFilters()
  CreateTiles()
  ui.overview = View.CreateOverview()
  ui.items = CreateListPanel(ITEM_COLUMNS, CreateItemRow, SetupItemRow)
  ui.journal = CreateListPanel(JOURNAL_COLUMNS, CreateJournalRow, SetupJournalRow, "LEDGER_COL_TIME", TIME_WIDTH)
  -- the tabs over the frame's top edge, as in the Auctions view
  CreateTabs()
  ui.tabs:SetFrameLevel(ui.items.frame:GetFrameLevel() + 10)
  View.CreateDetail()

  -- Item names arrive late; only the items listed are of interest.
  local pending = false
  panel:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  panel:SetScript("OnEvent", function(_, _, itemId, success)
    if pending or success == false or not known[itemId] then
      return
    end
    pending = true
    C_Timer.After(0.5, function()
      pending = false
      if panel:IsVisible() then
        Refresh()
      end
    end)
  end)
  return panel
end

-- what LedgerOverview.lua and LedgerDetail.lua use of this file
View.LIST_TOP, View.TYPE_LABEL, View.VIEW_JOURNAL = LIST_TOP, TYPE_LABEL, VIEW_JOURNAL
View.Refresh, View.GetRange, View.GetSettings, View.CharacterName = Refresh, GetRange, GetSettings, CharacterName
View.Money, View.Loss, View.Signed, View.Muted, View.Percent = Money, Loss, Signed, Muted, Percent
View.Incomplete, View.ShortDate, View.DayLabel = Incomplete, ShortDate, DayLabel
View.EventType, View.EventPrice, View.EventNet = EventType, EventPrice, EventNet

-- only while the view is shown; it is drawn anew when it is shown again
AM.Events.Register("LEDGER_CHANGED", function()
  if panel and panel:IsVisible() then
    Refresh()
  end
end)

-- Whether the tab is shown; hiding it does not stop the bookings, so the ledger is complete when it comes back.
AM.Settings.Define("ledgerTab", true)

AM.MainWindow.RegisterTab({
  id = "ledger",
  label = "MAIN_TAB_LEDGER",
  create = Create,
  refresh = Refresh,
  setting = "ledgerTab",
})
