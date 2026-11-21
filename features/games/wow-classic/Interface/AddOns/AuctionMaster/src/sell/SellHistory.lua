local addonName, AM = ...
local L = AM.L

-- The history of the item in the game's sell form, at the bottom of the Sell tab's item panel (SellPanel.lua): how
-- your own auctions of it went, from the ledger (AM.Ledger), for every character of this auction house and the whole
-- ledger. Two tabs: Summary (sell rate, a bar of the prices you posted at from the lowest to the highest, colored by
-- how well each range sold, with a stroke at the price in the sell form, average sale price, net per item, fees, lost
-- deposits, where the items came from, last sale) and Ledger (the item's events, filtered by
-- kind, with their net). Nothing is guessed: what the ledger does not know is left out or marked. The tab and the
-- filter shown are kept for the session only.
AM.SellHistory = {}
local SellHistory = AM.SellHistory
local Widgets = AM.Widgets
local Native = AM.Native
local Ledger = AM.Ledger
local UI = AM.Theme.ui
local View = AM.LedgerView

local SIDE = 8 -- leather left of the panel, as the list above it (Attachment.CreateList)
local TAB_STRIP = 30 -- the top tabs hang this far above the panel (their art sits in the lower part of 32)
local PANEL_HEIGHT = 170 -- the eight lines of the Summary and their padding
local LINE_HEIGHT = 18
local PAD = 10
local BAR_HEIGHT = 24 -- the Ledger tab's filter and net above its list
local EVENT_HEIGHT = 18
local DATE_WIDTH = 44
local COUNT_WIDTH = 36
local AMOUNT_WIDTH = 96
local GAP = 6
local PRICE_RANGES = 20 -- the pieces of the price bar
local PRICE_BAR_HEIGHT = 8
local PRICE_LINE = 2 -- the line of the Summary that holds the price bar
local NO_DATA_COLOR = { 0.22, 0.2, 0.18 } -- a range nothing was posted in

local TAB_SUMMARY, TAB_LEDGER = 1, 2

-- The filters of the Ledger tab, by the kinds of event each shows; "all" shows every kind.
local FILTERS = {
  { id = "all", label = "SELL_HISTORY_ALL" },
  { id = "sales", label = "SELL_HISTORY_SALES", types = { Ledger.SOLD, Ledger.VENDOR_SOLD } },
  { id = "returns", label = "SELL_HISTORY_RETURNS", types = { Ledger.CANCELED, Ledger.EXPIRED, Ledger.UNKNOWN } },
  { id = "sources", label = "SELL_HISTORY_SOURCES",
    types = { Ledger.BOUGHT, Ledger.VENDOR_BOUGHT, Ledger.CRAFTED, Ledger.LOOTED } },
}

-- Where the items came from, in the order shown: the count of the summary and its label.
local SOURCES = {
  { count = "craftedCount", label = "LEDGER_TYPE_CRAFTED" },
  { count = "boughtCount", label = "LEDGER_TYPE_BOUGHT" },
  { count = "lootedCount", label = "LEDGER_TYPE_LOOTED" },
  { count = "fromDisenchantCount", label = "SELL_HISTORY_FROM_DISENCHANT" },
}

local ui
local tab = TAB_SUMMARY
local filter = "all"
local shownItem -- itemDbKey of the item shown, nil without one
local summaries -- itemDbKey -> totals of Ledger.GetItemSummaries for the whole ledger; nil until needed again

-- The totals of every item, worked out once per change of the ledger.
local function GetSummaries()
  if not summaries then
    summaries = {}
    for _, totals in ipairs(Ledger.GetItemSummaries()) do
      summaries[totals.item] = totals
    end
  end
  return summaries
end

-- The sell rate of the item (0 to 1) over the whole ledger; nil when none of its auctions has ended yet.
function SellHistory.GetSellRate(itemDbKey)
  local totals = GetSummaries()[itemDbKey]
  return totals and totals.sellRate
end

-- The buyout per item in the game's sell form (both forms ask for it per item), nil without an item or a price.
local function GetFormPrice()
  local house = AuctionHouseFrame
  for _, name in ipairs({ "ItemSellFrame", "CommoditiesSellFrame" }) do
    local frame = house and house[name]
    local item = frame and frame:IsShown() and frame.GetItem and frame:GetItem()
    if item and item:IsValid() and frame.PriceInput then
      local amount = frame.PriceInput:GetAmount()
      return amount and amount > 0 and amount or nil
    end
  end
end

-- The text of a tab with nothing to show, placed as the auction house's own "no results" text of its item lists:
-- gold, centered, 45 below the top of the panel.
local function CreateEmptyText(frame, panel)
  local text = Widgets.CreateText(frame, "GameFontNormal", "CENTER")
  text:SetPoint("TOP", panel, "TOP", 0, -45)
  text:SetPoint("LEFT", panel, "LEFT", 20, 0)
  text:SetPoint("RIGHT", panel, "RIGHT", -20, 0)
  text:SetWordWrap(true)
  return text
end

-- Summary ---------------------------------------------------------------------------------------------

local function Muted(text)
  return View.Muted(text)
end

-- "66% · 19 of 29 sold"
local function RateText(sold, ended, color)
  local percent = View.Percent(sold / ended)
  return (color and Widgets.Color(color, percent) or percent)
    .. Muted(" · " .. L["SELL_HISTORY_SOLD_OF"]:format(sold, ended))
end

-- The color of a theme color ("1aff1a") as r, g, b.
local function Rgb(hex)
  return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

-- A range of the price bar: red where nothing sold, green where everything did, in between by the share sold.
local function RangeColor(range)
  local ended = range.sold + range.unsold
  if ended == 0 then
    return unpack(NO_DATA_COLOR)
  end
  local share = range.sold / ended
  local lossR, lossG, lossB = Rgb(UI.loss)
  local gainR, gainG, gainB = Rgb(UI.gain)
  return lossR + (gainR - lossR) * share, lossG + (gainG - lossG) * share, lossB + (gainB - lossB) * share
end

local function ShowRangeTooltip(piece)
  local range = piece.range
  GameTooltip:SetOwner(piece, "ANCHOR_TOP")
  GameTooltip:SetText(AM.FormatMoney(range.from) .. " - " .. AM.FormatMoney(range.to), 1, 1, 1)
  local ended = range.sold + range.unsold
  if ended > 0 then
    GameTooltip:AddLine(L["SELL_HISTORY_SOLD_OF"]:format(range.sold, ended), nil, nil, nil, true)
  else
    GameTooltip:AddLine(L["SELL_HISTORY_RANGE_NONE"], nil, nil, nil, true)
  end
  GameTooltip:Show()
end

-- The price bar in the value area of a line: lowest price, the bar of ranges, highest price; the stroke marks the price
-- in the sell form.
local function CreatePriceBar(line)
  local bar = CreateFrame("Frame", nil, line)
  bar:SetPoint("LEFT", line.label, "RIGHT", GAP, 0)
  bar:SetPoint("RIGHT")
  bar:SetHeight(LINE_HEIGHT)
  bar.low = Widgets.CreateText(bar, "GameFontHighlightSmall")
  bar.low:SetPoint("LEFT")
  bar.high = Widgets.CreateText(bar, "GameFontHighlightSmall", "RIGHT")
  bar.high:SetPoint("RIGHT")
  bar.track = CreateFrame("Frame", nil, bar)
  bar.track:SetPoint("LEFT", bar.low, "RIGHT", 4, 0)
  bar.track:SetPoint("RIGHT", bar.high, "LEFT", -4, 0)
  bar.track:SetHeight(PRICE_BAR_HEIGHT)
  local border = bar.track:CreateTexture(nil, "BACKGROUND")
  border:SetPoint("TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", 1, -1)
  border:SetColorTexture(0, 0, 0, 1)
  bar.pieces = {}
  for index = 1, PRICE_RANGES do
    local piece = CreateFrame("Frame", nil, bar.track)
    piece.texture = piece:CreateTexture(nil, "ARTWORK")
    piece.texture:SetAllPoints()
    piece:SetScript("OnEnter", ShowRangeTooltip)
    piece:SetScript("OnLeave", GameTooltip_Hide)
    piece:EnableMouse(true)
    bar.pieces[index] = piece
  end
  bar.stroke = bar.track:CreateTexture(nil, "OVERLAY")
  bar.stroke:SetSize(2, PRICE_BAR_HEIGHT + 6)
  bar.stroke:SetColorTexture(1, 1, 1, 1)
  -- the pieces share the track's width, which is known once it is laid out
  bar.track:SetScript("OnSizeChanged", function(_, width)
    for index, piece in ipairs(bar.pieces) do
      piece:ClearAllPoints()
      piece:SetPoint("TOPLEFT", width * (index - 1) / PRICE_RANGES, 0)
      piece:SetSize(width / PRICE_RANGES, PRICE_BAR_HEIGHT)
    end
    if bar.Place then
      bar.Place()
    end
  end)
  return bar
end

-- Shows the price ranges of the item (Ledger.GetPriceRanges) and the price in the sell form; false when there are
-- too few prices for a bar.
local function UpdatePriceBar(bar)
  local result = shownItem and Ledger.GetPriceRanges(shownItem, PRICE_RANGES)
  if not result then
    return false
  end
  bar.low:SetText(AM.FormatMoney(result.low))
  bar.high:SetText(AM.FormatMoney(result.high))
  for index, piece in ipairs(bar.pieces) do
    piece.range = result.ranges[index]
    piece.texture:SetColorTexture(RangeColor(piece.range))
  end
  local price = GetFormPrice()
  bar.Place = function()
    bar.stroke:SetShown(price ~= nil)
    if price then
      -- a price beyond the span sits at its end
      local share = math.max(0, math.min(1, (price - result.low) / (result.high - result.low)))
      bar.stroke:ClearAllPoints()
      bar.stroke:SetPoint("CENTER", bar.track, "LEFT", bar.track:GetWidth() * share, 0)
    end
  end
  bar.Place()
  return true
end

local function SourceText(totals)
  local parts = {}
  for _, source in ipairs(SOURCES) do
    local count = totals[source.count]
    if count > 0 then
      parts[#parts + 1] = L[source.label] .. Muted(" " .. count)
    end
  end
  return #parts > 0 and table.concat(parts, Muted(", ")) or Muted("--")
end

local function LastSoldText(totals)
  if totals.lastSold then
    return View.DayLabel({ key = tonumber(date("%Y%m%d", totals.lastSold)), time = totals.lastSold })
  elseif totals.soldCount > 0 then
    -- sold only on days the ledger has combined: no date
    return Muted(L["SELL_HISTORY_OLDER"]:format(Ledger.GetKeepDays()))
  end
  return Muted("--")
end

-- The lines of the Summary: label and value of each.
local function SummaryLines(totals)
  local none = Muted("--")
  local ended = totals.soldCount + totals.unsoldCount
  local units = totals.soldCount + totals.vendorSoldCount
  local lost
  if totals.lostDeposits > 0 then
    lost = View.Loss(totals.lostDeposits) .. View.Incomplete(totals)
  elseif totals.unknownLosses > 0 then
    lost = Muted("?")
  else
    lost = none
  end
  return {
    { "LEDGER_DETAIL_RATE", ended > 0 and RateText(totals.soldCount, ended) or none },
    -- the price bar fills its value area (UpdateSummary); the text shows where there is no bar
    { "SELL_HISTORY_PRICES", Muted(L["SELL_HISTORY_FEW_PRICES"]), "SELL_HISTORY_PRICES_TIP" },
    -- of the sales at the auction house (merchants pay their own fixed price)
    { "LEDGER_DETAIL_AVERAGE", totals.soldCount > 0
      and AM.FormatMoney(math.floor((totals.revenue - totals.vendorRevenue) / totals.soldCount)) or none },
    { "SELL_HISTORY_NET_EACH", units > 0
      and (View.Signed(math.floor(totals.net / units + 0.5)) .. View.Incomplete(totals)) or none,
      "SELL_HISTORY_NET_EACH_TIP" },
    { "LEDGER_DETAIL_FEES", totals.fees > 0 and View.Loss(totals.fees) or none },
    { "LEDGER_DETAIL_LOST", lost },
    { "SELL_HISTORY_SOURCE", SourceText(totals) },
    { "SELL_HISTORY_LAST_SOLD", LastSoldText(totals) },
  }
end

local function CreateSummary(panel)
  local frame = CreateFrame("Frame", nil, panel)
  frame:SetPoint("TOPLEFT", Native.PANEL_INSET + PAD, -(Native.PANEL_INSET + PAD - 2))
  frame:SetPoint("BOTTOMRIGHT", -(Native.PANEL_INSET + PAD), Native.PANEL_INSET)
  frame.lines = {}
  for index = 1, 8 do
    local line = CreateFrame("Frame", nil, frame)
    line:SetPoint("TOPLEFT", 0, -(index - 1) * LINE_HEIGHT)
    line:SetPoint("TOPRIGHT", 0, -(index - 1) * LINE_HEIGHT)
    line:SetHeight(LINE_HEIGHT)
    line.label = Widgets.CreateText(line, "GameFontNormal")
    line.label:SetPoint("LEFT")
    line.value = Widgets.CreateText(line, "GameFontHighlight", "RIGHT")
    line.value:SetPoint("RIGHT")
    line.value:SetPoint("LEFT", line.label, "RIGHT", GAP, 0)
    line.value:SetWordWrap(false)
    line:SetScript("OnEnter", function(self)
      if self.tip then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.label:GetText(), 1, 1, 1)
        GameTooltip:AddLine(L[self.tip], nil, nil, nil, true)
        GameTooltip:Show()
      end
    end)
    line:SetScript("OnLeave", GameTooltip_Hide)
    line:EnableMouse(true)
    frame.lines[index] = line
  end
  frame.prices = CreatePriceBar(frame.lines[PRICE_LINE])
  frame.empty = CreateEmptyText(frame, panel)
  return frame
end

local function UpdateSummary()
  local frame = ui.summary
  local totals = shownItem and GetSummaries()[shownItem]
  local lines = totals and SummaryLines(totals) or {}
  for index, line in ipairs(frame.lines) do
    local entry = lines[index]
    line:SetShown(entry ~= nil)
    if entry then
      line.label:SetText(L[entry[1]])
      line.value:SetText(entry[2])
      line.tip = entry[3]
    end
  end
  local hasBar = totals ~= nil and UpdatePriceBar(frame.prices)
  frame.prices:SetShown(hasBar)
  frame.lines[PRICE_LINE].value:SetShown(not hasBar)
  if not shownItem then
    frame.empty:SetText(L["SELL_HISTORY_NO_ITEM"])
  elseif not totals then
    frame.empty:SetText(L["SELL_HISTORY_NONE"])
  else
    frame.empty:SetText("")
  end
end

-- Ledger ----------------------------------------------------------------------------------------------

local function CreateEventRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row.date = Widgets.CreateText(row, Native.RowFont())
  row.date:SetPoint("LEFT", 6, 0)
  row.date:SetWidth(DATE_WIDTH)
  row.amount = Widgets.CreateText(row, Native.RowFont(), "RIGHT")
  row.amount:SetPoint("RIGHT", -6, 0)
  row.amount:SetWidth(AMOUNT_WIDTH)
  row.count = Widgets.CreateText(row, Native.RowFont(), "RIGHT")
  row.count:SetPoint("RIGHT", row.amount, "LEFT", -GAP, 0)
  row.count:SetWidth(COUNT_WIDTH)
  row.kind = Widgets.CreateText(row, Native.RowFont())
  row.kind:SetPoint("LEFT", row.date, "RIGHT", GAP, 0)
  row.kind:SetPoint("RIGHT", row.count, "LEFT", -GAP, 0)
  row.kind:SetWordWrap(false)
  return row
end

local function SetupEventRow(row, item)
  local event = item.event
  row.date:SetText(Muted(View.ShortDate(event.time)))
  row.kind:SetText(View.EventType(event))
  row.count:SetText(event.count or "")
  -- the net it adds; where it adds none, the price or cost as the Journal shows it
  row.amount:SetText(View.EventNet(event) or View.EventPrice(event) or "")
end

local function CreateLedger(panel)
  local frame = CreateFrame("Frame", nil, panel)
  frame:SetPoint("TOPLEFT", Native.PANEL_INSET, -Native.PANEL_INSET)
  frame:SetPoint("BOTTOMRIGHT", -Native.PANEL_INSET, Native.PANEL_INSET)

  frame.filter = Widgets.CreateDropdown(frame, 110, function(value)
    filter = value or "all"
    SellHistory.Refresh()
  end)
  frame.filter.button:SetPoint("TOPLEFT", 4, -3)
  frame.net = Widgets.CreateText(frame, "GameFontHighlight", "RIGHT")
  frame.net:SetPoint("RIGHT", frame, "TOPRIGHT", -8, -BAR_HEIGHT / 2 - 2)

  -- the column titles, small as the game's list headers
  local header = CreateFrame("Frame", nil, frame)
  header:SetPoint("TOPLEFT", 0, -(BAR_HEIGHT + 4))
  header:SetPoint("TOPRIGHT", 0, -(BAR_HEIGHT + 4))
  header:SetHeight(14)
  local titles = CreateEventRow(header)
  titles:SetAllPoints(header)
  for key, label in pairs({ date = "SELL_HISTORY_COL_DATE", kind = "LEDGER_COL_TYPE", count = "SELL_HISTORY_COL_COUNT",
    amount = "LEDGER_COL_NET" }) do
    titles[key]:SetFontObject("GameFontNormalSmall")
    titles[key]:SetText(L[label])
  end

  frame.list = Widgets.CreateList(frame, CreateEventRow, SetupEventRow)
  frame.list:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
  frame.list:SetPoint("BOTTOMRIGHT")
  frame.empty = CreateEmptyText(frame, panel)
  return frame
end

local function UpdateLedger()
  local frame = ui.ledger
  local choices, accepted = {}, nil
  for _, entry in ipairs(FILTERS) do
    choices[#choices + 1] = { value = entry.id, label = L[entry.label] }
    if entry.id == filter and entry.types then
      accepted = {}
      for _, kind in ipairs(entry.types) do
        accepted[kind] = true
      end
    end
  end
  frame.filter.SetChoices(choices, filter)

  local items, net, unknown = {}, 0, false
  if shownItem then
    local days = Ledger.GetJournal(nil, nil, nil, function(kind, item)
      return item == shownItem and (not accepted or accepted[kind])
    end)
    for _, day in ipairs(days) do
      net = net + day.net
      unknown = unknown or day.unknownLosses > 0
      for _, event in ipairs(day.entries) do
        items[#items + 1] = { height = EVENT_HEIGHT, event = event }
      end
    end
  end
  frame.list.SetItems(items)
  frame.net:SetText(#items > 0 and (View.Signed(net) .. (unknown and Muted(" ?") or "")) or "")
  if not shownItem then
    frame.empty:SetText(L["SELL_HISTORY_NO_ITEM"])
  elseif #items == 0 then
    frame.empty:SetText(L["SELL_HISTORY_NO_EVENTS"])
  else
    frame.empty:SetText("")
  end
end

-- Section ---------------------------------------------------------------------------------------------

-- Summary / Ledger: the top tabs of the auction house's Auctions view, as the Ledger view of the main window uses.
local function CreateTabs(parent)
  local tabs = CreateFrame("Frame", nil, parent)
  tabs:SetSize(1, 32)
  for id, label in ipairs({ "SELL_HISTORY_SUMMARY", "SELL_HISTORY_LEDGER" }) do
    local ok, button = pcall(CreateFrame, "Button", nil, tabs, "AuctionHouseFrameTopTabTemplate")
    if not ok then
      button = CreateFrame("Button", nil, tabs, "PanelTopTabButtonTemplate")
    end
    button:SetID(id)
    button:SetText(L[label])
    PanelTemplates_TabResize(button, 20, nil, 70)
    button:HookScript("OnClick", function(self)
      tab = self:GetID()
      SellHistory.Refresh()
    end)
  end
  -- Classic's template neither lists nor lines up the tabs itself (see LedgerTab.lua)
  if not tabs.Tabs then
    tabs.Tabs = { tabs:GetChildren() }
    for i = 2, #tabs.Tabs do
      tabs.Tabs[i]:SetPoint("LEFT", tabs.Tabs[i - 1], "RIGHT", -3, 0)
    end
  end
  tabs.Tabs[1]:SetPoint("TOPLEFT")
  PanelTemplates_SetNumTabs(tabs, #tabs.Tabs)
  return tabs
end

-- Builds the section at the bottom of body, `bottom` above its lower edge, as wide as a list made with
-- Attachment.CreateList. Returns how far from the lower edge the section's top (with its tabs) is.
function SellHistory.Create(body, bottom)
  ui = {}
  ui.panel = Native.CreateInset(body, true)
  ui.panel:SetPoint("BOTTOMLEFT", SIDE, bottom)
  ui.panel:SetPoint("BOTTOMRIGHT", -(Native.ScrollGutter() + 2), bottom)
  ui.panel:SetHeight(PANEL_HEIGHT)
  ui.tabs = CreateTabs(body)
  ui.tabs:SetPoint("BOTTOMLEFT", ui.panel, "TOPLEFT", 4, -(32 - TAB_STRIP))
  ui.summary = CreateSummary(ui.panel)
  ui.ledger = CreateLedger(ui.panel)
  return bottom + PANEL_HEIGHT + TAB_STRIP
end

-- Shows the history of the item (itemDbKey, nil for none) in the tab chosen.
function SellHistory.Show(itemDbKey)
  shownItem = itemDbKey
  SellHistory.Refresh()
end

function SellHistory.Refresh()
  if not ui then
    return
  end
  PanelTemplates_SetTab(ui.tabs, tab)
  ui.summary:SetShown(tab == TAB_SUMMARY)
  ui.ledger:SetShown(tab == TAB_LEDGER)
  if tab == TAB_SUMMARY then
    UpdateSummary()
  else
    UpdateLedger()
  end
end

-- The price in the sell form changed: only the Summary's line for it depends on it. The game calls this once per
-- box of gold, silver and copper, so it is redrawn once for all of them.
local pricePending = false
local function PriceChanged()
  if pricePending or not (ui and ui.panel:IsVisible() and tab == TAB_SUMMARY) then
    return
  end
  pricePending = true
  C_Timer.After(0, function()
    pricePending = false
    SellHistory.Refresh()
  end)
end

-- Hooks the sell forms of the auction house (load on demand: called once it exists).
function SellHistory.Install()
  for _, name in ipairs({ "ItemSellFrame", "CommoditiesSellFrame" }) do
    local frame = AuctionHouseFrame[name]
    -- runs on every change of the price, typed or set by the game (the item frame has its own, so per frame)
    if frame and frame.UpdatePostState then
      hooksecurefunc(frame, "UpdatePostState", PriceChanged)
    end
  end
end

-- The ledger changed: the totals are worked out again when next needed.
AM.Events.Register("LEDGER_CHANGED", function()
  summaries = nil
end)
