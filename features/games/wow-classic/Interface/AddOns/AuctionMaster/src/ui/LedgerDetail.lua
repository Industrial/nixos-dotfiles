local addonName, AM = ...
local L = AM.L

-- The details of the item selected in the ledger view (LedgerTab.lua), beside the auction house: gold, quantities and
-- its latest events, like the recipe details.
local Widgets = AM.Widgets
local Native = AM.Native
local UI = AM.Theme.ui
local View = AM.LedgerView
local ui = View.ui
local state = View.state

local Ledger = AM.Ledger
local TYPE_LABEL = View.TYPE_LABEL
local VIEW_JOURNAL = View.VIEW_JOURNAL

local DETAIL_WIDTH = 278 -- as the recipe details
local DETAIL_EVENTS = 6 -- the latest events of the selected item shown in its details

-- "14:32" today, else the short date and the time.
local function ShortTime(at)
  local day, today = date("*t", at), date("*t", time())
  local clock = date("%H:%M", at)
  if day.year == today.year and day.month == today.month and day.day == today.day then
    return clock
  end
  return View.ShortDate(at) .. " " .. clock
end

-- The rows of the detail list for the totals of an item: gold, quantities, its latest events.
local function BuildDetailItems(totals)
  local items = {}
  local function Line(label, value)
    items[#items + 1] = { height = 18, kind = "line", label = L[label], value = value }
  end
  local function Header(label)
    items[#items + 1] = { height = 24, kind = "header", label = L[label] }
  end

  -- a value of nothing reads "--" here: it did not happen in the range (the unknown deposits keep their "?")
  local none = View.Muted("--")
  local function Count(count)
    return count > 0 and count or none
  end

  Line("LEDGER_DETAIL_REVENUE", totals.revenue > 0 and AM.FormatMoney(totals.revenue) or none)
  Line("LEDGER_DETAIL_FEES", totals.fees > 0 and ("-" .. AM.FormatMoney(totals.fees)) or none)
  local lost
  if totals.lostDeposits > 0 then
    lost = View.Loss(totals.lostDeposits) .. View.Incomplete(totals)
  elseif totals.unknownLosses > 0 then
    lost = View.Muted("?")
  else
    lost = none
  end
  Line("LEDGER_DETAIL_LOST", lost)
  Line("LEDGER_DETAIL_COST", totals.cost > 0 and ("-" .. AM.FormatMoney(totals.cost)) or none)
  items[#items + 1] = { height = 7, kind = "separator" }
  local moved = totals.revenue > 0 or totals.fees > 0 or totals.lostDeposits > 0 or totals.unknownLosses > 0
    or totals.cost > 0
  Line("LEDGER_DETAIL_NET", moved and (View.Signed(totals.net) .. View.Incomplete(totals)) or none)
  -- of the sales at the auction house (merchants pay their own fixed price)
  Line("LEDGER_DETAIL_AVERAGE", totals.soldCount > 0
    and AM.FormatMoney(math.floor((totals.revenue - totals.vendorRevenue) / totals.soldCount)) or none)

  -- items, not auctions: a stack of 20 counts 20, as in the list
  Header("LEDGER_DETAIL_ITEMS")
  -- with what was paid: for the purchases in the range, for the stock now
  local function Paid(count, copper)
    return count > 0 and (count .. View.Muted(" · " .. View.Money(copper))) or none
  end
  Line("LEDGER_DETAIL_RATE", totals.sellRate and View.Percent(totals.sellRate) or none)
  Line("LEDGER_DETAIL_BOUGHT", Paid(totals.boughtCount - totals.vendorBoughtCount, totals.spent - totals.vendorSpent))
  if totals.vendorBoughtCount > 0 then
    Line("LEDGER_DETAIL_VENDOR_BOUGHT", Paid(totals.vendorBoughtCount, totals.vendorSpent))
  end
  if totals.craftedCount > 0 then
    Line("LEDGER_DETAIL_CRAFTED", Paid(totals.craftedCount, totals.craftCost))
  end
  if totals.disenchantedCount > 0 then
    Line("LEDGER_DETAIL_DISENCHANTED", Paid(totals.disenchantedCount, totals.disenchantCost))
  end
  if totals.fromDisenchantCount > 0 then
    Line("LEDGER_DETAIL_FROM_DISENCHANT", Paid(totals.fromDisenchantCount, totals.fromDisenchantCost))
  end
  if totals.lootedCount > 0 then
    Line("LEDGER_DETAIL_LOOTED", totals.lootedCount)
  end
  if totals.usedUpCount > 0 then
    Line("LEDGER_DETAIL_USED_UP", Paid(totals.usedUpCount, totals.usedUpCost))
  end
  if totals.usedCount > 0 then
    Line("LEDGER_DETAIL_USED", totals.usedCount)
  end
  Line("LEDGER_DETAIL_POSTED", Count(totals.createdCount))
  Line("LEDGER_DETAIL_SOLD", Count(totals.soldCount))
  if totals.vendorSoldCount > 0 then
    Line("LEDGER_DETAIL_VENDOR_SOLD", Paid(totals.vendorSoldCount, totals.vendorRevenue))
  end
  if totals.uncostedCount > 0 then
    Line("LEDGER_DETAIL_UNCOSTED", totals.uncostedCount)
  end
  Line("LEDGER_DETAIL_CANCELED", Count(totals.canceledCount))
  Line("LEDGER_DETAIL_EXPIRED", Count(totals.expiredCount))
  if totals.unknownCount > 0 then
    Line("LEDGER_DETAIL_UNKNOWN", totals.unknownCount)
  end
  Line("LEDGER_DETAIL_OPEN", Count(totals.openCount))
  Line("LEDGER_DETAIL_STOCK", Paid(totals.stockCount, totals.stock))

  Header("LEDGER_DETAIL_RECENT")
  local days = Ledger.GetJournal(View.GetRange().from(time()), nil, View.GetSettings().ledgerWho, function(_, item)
    return item == totals.item
  end)
  local shown = 0
  for _, day in ipairs(days) do
    for _, event in ipairs(day.entries) do
      if shown < DETAIL_EVENTS then
        shown = shown + 1
        local net = event.net and View.Signed(event.net) or (event.unknown and View.Muted("?") or "")
        items[#items + 1] = { height = 18, kind = "event", label = View.Muted(ShortTime(event.time)) .. "  "
          .. L[TYPE_LABEL[event.type]] .. View.Muted(" x" .. event.count), value = net }
      end
    end
  end
  if shown == 0 then
    items[#items + 1] = { height = 18, kind = "event", label = View.Muted(L["LEDGER_DETAIL_NO_EVENTS"]), value = "" }
  end
  return items
end

local function CreateDetailRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  -- the content keeps clear of the edges of the sunken panel
  local content = CreateFrame("Frame", nil, row)
  content:SetPoint("TOPLEFT", 8, 0)
  content:SetPoint("BOTTOMRIGHT", -8, 0)
  row.label = Widgets.CreateText(content, "GameFontNormal")
  row.label:SetWordWrap(false)
  row.value = Widgets.CreateText(content, "GameFontHighlight", "RIGHT")
  row.value:SetPoint("RIGHT")
  row.line = content:CreateTexture(nil, "BORDER")
  row.line:SetHeight(1)
  row.line:SetPoint("BOTTOMLEFT", 0, 2)
  row.line:SetPoint("BOTTOMRIGHT", 0, 2)
  return row
end

local function SetupDetailRow(row, item)
  row.label:ClearAllPoints()
  row.label:SetShown(item.kind ~= "separator")
  row.value:SetShown(item.kind == "line" or item.kind == "event")
  row.line:SetShown(item.kind == "header" or item.kind == "separator")
  row.label:SetFontObject(item.kind == "event" and "GameFontHighlight" or "GameFontNormal")
  if item.kind == "header" then
    row.label:SetPoint("BOTTOMLEFT", 0, 6)
    row.line:SetColorTexture(unpack(UI.buttonBorder))
  else
    row.label:SetPoint("LEFT")
    row.label:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
    row.line:SetColorTexture(0.17, 0.16, 0.18)
  end
  row.label:SetText(item.label or "")
  row.value:SetText(item.value or "")
end

-- The Journal with the search set to the selected item's name.
local function ShowInJournal()
  local name = ui.detail.itemName
  if name then
    View.GetSettings().ledgerView = "journal"
    ui.search:SetText(name) -- refreshes when the text changes
    View.Refresh()
  end
end

local function CreateDetail()
  -- beside the auction house, like the recipe details. The close button closes the details.
  ui.attachment = AM.Attachment.Create(L["DETAIL_TITLE"], DETAIL_WIDTH, function()
    state.closedKey = state.selectedKey
    state.selectedKey = nil
    View.Refresh()
  end, nil, function()
    state.selectedKey = state.closedKey
    View.Refresh()
  end, true)
  local body = ui.attachment.body
  ui.detail = body
  -- the item sits in a sunken panel like the list below it
  local header = Native.CreateInset(body, true)
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
  body.range = Widgets.CreateText(header, "GameFontHighlightSmall")
  body.range:SetPoint("BOTTOMLEFT", body.icon, "BOTTOMRIGHT", 10, 2)
  body.range:SetPoint("RIGHT", -9, 0)
  body.range:SetWordWrap(false)

  local FOOTER = 24 -- the button in the strip below the list, as narrow as the auction house's
  body.list = AM.Attachment.CreateList(body, 70, FOOTER, CreateDetailRow, SetupDetailRow)
  local button = Widgets.CreateButton(body, L["LEDGER_SHOW_JOURNAL"], false, ShowInJournal)
  button:ClearAllPoints()
  button:SetPoint("BOTTOMLEFT", 8, -1)
  button:SetPoint("BOTTOMRIGHT", -8, -1)
  button:SetHeight(20)
  body.button = button
end

-- The details of the selected item, in every view; in the Journal without the button that leads there.
local function UpdateDetail(view)
  local totals = nil
  if state.selectedKey then
    totals = state.details[state.selectedKey]
  end
  ui.attachment.SetShown(totals ~= nil)
  if not totals then
    ui.attachment.SetHandle(state.closedKey ~= nil and state.details[state.closedKey] ~= nil)
    return
  end
  state.closedKey = nil
  ui.attachment.SetHandle(false)
  ui.attachment.Place()
  local body, item = ui.detail, state.lookupItem(totals.item)
  body.icon:SetTexture(item.icon)
  local color = ITEM_QUALITY_COLORS[item.quality or 1] or ITEM_QUALITY_COLORS[1]
  body.name:SetTextColor(color.r, color.g, color.b)
  body.name:SetText(item.name or "...")
  body.itemName = item.name
  local who = View.GetSettings().ledgerWho
  body.range:SetText(L[View.GetRange().label] .. (who and (" · " .. View.CharacterName(who)) or ""))
  body.list.SetItems(BuildDetailItems(totals))
  body.button:SetEnabled(item.name ~= nil)
  body.button:SetShown(view ~= VIEW_JOURNAL)
end

View.CreateDetail = CreateDetail
View.UpdateDetail = UpdateDetail
