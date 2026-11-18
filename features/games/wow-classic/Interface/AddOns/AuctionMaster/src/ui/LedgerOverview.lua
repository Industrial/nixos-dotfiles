local addonName, AM = ...
local L = AM.L

-- The Overview of the ledger view (LedgerTab.lua): the net per day as a bar chart and the findings below it.
local Widgets = AM.Widgets
local Native = AM.Native
local UI = AM.Theme.ui
local View = AM.LedgerView
local ui = View.ui
local state = View.state

local LIST_TOP = View.LIST_TOP
local CHART_HEIGHT = 92
local CHART_PADDING = 10
local CHART_TOP = 26 -- the bars start below the title
local CHART_BOTTOM = 18 -- and end above the dates
local FINDING_NAMES = 3 -- item names a finding shows, the rest are counted
-- the title and the text of each kind of finding (Ledger.GetFindings)
local FINDING_TEXTS = {
  top = { "LEDGER_FINDING_TOP", "LEDGER_FINDING_TOP_TEXT" },
  bestseller = { "LEDGER_FINDING_BESTSELLER", "LEDGER_FINDING_TOP_TEXT" },
  loss = { "LEDGER_FINDING_LOSS", "LEDGER_FINDING_LOSS_TEXT" },
  unsold = { "LEDGER_FINDING_UNSOLD", "LEDGER_FINDING_UNSOLD_TEXT" },
  stock = { "LEDGER_FINDING_STOCK", "LEDGER_FINDING_STOCK_TEXT" },
}

-- A text color of the theme (hex) as a color for a texture.
local function Rgb(hex)
  return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
end

-- A bar is a dark shade of the color of its texts (the bright ones are made for thin text and glare as an area) with
-- an edge in that bright color at its end: the green of the game (GREEN_FONT_COLOR) for gains, red for losses.
local GAIN_FILL, GAIN_EDGE = Rgb("1f8f1f"), Rgb(UI.gain)
local LOSS_FILL, LOSS_EDGE = Rgb("9e2b2b"), Rgb(UI.loss)

-- A bar of the chart: the bar itself and the area over the whole height of its slot that shows its day on hover.
-- The month and year of a time, in the game's month names where the client has them.
local function MonthName(at)
  local day = date("*t", at)
  local names = CALENDAR_FULLDATE_MONTH_NAMES
  if names and names[day.month] then
    return names[day.month] .. " " .. day.year
  end
  return date("%Y-%m", at)
end

local function CreateBar(chart)
  local bar = CreateFrame("Button", nil, chart.area)
  bar.fill = chart.area:CreateTexture(nil, "ARTWORK")
  bar.edge = chart.area:CreateTexture(nil, "ARTWORK", nil, 1)
  bar.edge:SetHeight(1)
  local highlight = bar:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints()
  highlight:SetColorTexture(1, 1, 1, 0.06)
  bar:SetScript("OnEnter", function(self)
    local bucket = self.bucket
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if bucket.month then
      GameTooltip:SetText(MonthName(bucket.time))
    elseif bucket.days > 1 then
      GameTooltip:SetText(L["LEDGER_WEEK_OF"]:format(View.ShortDate(bucket.time)))
    else
      GameTooltip:SetText(View.DayLabel(bucket))
    end
    GameTooltip:AddLine(View.Signed(bucket.net) .. View.Incomplete(bucket))
    GameTooltip:Show()
  end)
  bar:SetScript("OnLeave", GameTooltip_Hide)
  return bar
end

-- Draws the net of each day (or week) of ui.series as a bar, gains up from the zero line, losses down from it.
local function DrawChart(chart)
  local series = ui.series or {}
  local width, height = chart.area:GetWidth(), chart.area:GetHeight()
  local count = #series
  for index = count + 1, #chart.bars do
    chart.bars[index]:Hide()
    chart.bars[index].fill:Hide()
    chart.bars[index].edge:Hide()
  end
  chart.zero:SetShown(count > 0)
  for _, label in pairs(chart.labels) do
    label:SetText("")
  end
  if count == 0 or width <= 0 then
    return
  end
  local unit = "LEDGER_CHART_DAY"
  if series[count].month then
    unit = "LEDGER_CHART_MONTH"
  elseif series[count].days > 1 then
    unit = "LEDGER_CHART_WEEK"
  end
  chart.title:SetText(L[unit])
  local top, bottom = 0, 0
  for _, bucket in ipairs(series) do
    top = math.max(top, bucket.net)
    bottom = math.max(bottom, -bucket.net)
  end
  local range = top + bottom
  -- the zero line, from the top: at the bottom edge while nothing was lost
  local zero = range > 0 and math.floor(height * top / range) or height - 1
  zero = math.min(zero, height - 1)
  chart.zero:ClearAllPoints()
  chart.zero:SetPoint("TOPLEFT", chart.area, "TOPLEFT", 0, -zero)
  chart.zero:SetPoint("TOPRIGHT", chart.area, "TOPRIGHT", 0, -zero)
  local slot = width / count
  local barWidth = slot >= 4 and math.max(1, math.floor(slot * 0.7)) or slot
  for index, bucket in ipairs(series) do
    local bar = chart.bars[index] or CreateBar(chart)
    chart.bars[index] = bar
    bar.bucket = bucket
    local left = (index - 1) * slot
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", chart.area, "TOPLEFT", left, 0)
    bar:SetSize(slot, height)
    bar:Show()
    local fill, edge = bar.fill, bar.edge
    fill:ClearAllPoints()
    edge:ClearAllPoints()
    if bucket.net ~= 0 then
      local barHeight = math.max(1, height * math.abs(bucket.net) / range)
      local x = left + (slot - barWidth) / 2
      -- the edge at the end away from the zero line: on top of a gain, at the bottom of a loss
      if bucket.net > 0 then
        fill:SetColorTexture(unpack(GAIN_FILL))
        edge:SetColorTexture(unpack(GAIN_EDGE))
        fill:SetPoint("BOTTOMLEFT", chart.area, "TOPLEFT", x, -zero)
        edge:SetPoint("TOPLEFT", fill)
        edge:SetPoint("TOPRIGHT", fill)
      else
        fill:SetColorTexture(unpack(LOSS_FILL))
        edge:SetColorTexture(unpack(LOSS_EDGE))
        fill:SetPoint("TOPLEFT", chart.area, "TOPLEFT", x, -zero - 1)
        edge:SetPoint("BOTTOMLEFT", fill)
        edge:SetPoint("BOTTOMRIGHT", fill)
      end
      fill:SetSize(barWidth, barHeight)
      fill:Show()
      edge:Show()
    else
      fill:Hide()
      edge:Hide()
    end
  end
  -- the dates under the first bar, the middle one and the last one (today)
  chart.labels.first:SetText(View.ShortDate(series[1].time))
  chart.labels.last:SetText(L["LEDGER_TODAY"])
  if count >= 5 then
    local middle = math.ceil(count / 2)
    chart.labels.middle:ClearAllPoints()
    chart.labels.middle:SetPoint("TOP", chart.area, "BOTTOMLEFT", (middle - 0.5) * slot, -5)
    chart.labels.middle:SetText(View.ShortDate(series[middle].time))
  end
end

local function CreateChart(parent)
  local chart = CreateFrame("Frame", nil, parent)
  chart.title = Widgets.CreateText(chart, "GameFontNormal")
  chart.title:SetPoint("TOPLEFT", CHART_PADDING, -9)
  chart.area = CreateFrame("Frame", nil, chart)
  chart.area:SetPoint("TOPLEFT", CHART_PADDING, -CHART_TOP)
  chart.area:SetPoint("BOTTOMRIGHT", -CHART_PADDING, CHART_BOTTOM)
  chart.zero = chart.area:CreateTexture(nil, "BORDER")
  chart.zero:SetColorTexture(unpack(UI.buttonBorder))
  chart.zero:SetHeight(1)
  chart.labels = {
    first = Widgets.CreateText(chart, "GameFontDisableSmall"),
    middle = Widgets.CreateText(chart, "GameFontDisableSmall", "CENTER"),
    last = Widgets.CreateText(chart, "GameFontDisableSmall", "RIGHT"),
  }
  chart.labels.first:SetPoint("TOPLEFT", chart.area, "BOTTOMLEFT", 0, -5)
  chart.labels.last:SetPoint("TOPRIGHT", chart.area, "BOTTOMRIGHT", 0, -5)
  chart.bars = {}
  chart:SetScript("OnSizeChanged", function(self)
    DrawChart(self)
  end)
  return chart
end

-- The names of the items of a finding in their quality colors, the ones beyond FINDING_NAMES counted.
local function FindingNames(items)
  local names = {}
  for index = 1, math.min(#items, FINDING_NAMES) do
    local item = items[index]
    local color = ITEM_QUALITY_COLORS[item.quality or 1] or ITEM_QUALITY_COLORS[1]
    names[index] = color.hex .. (item.name or "...") .. "|r"
  end
  local text = table.concat(names, ", ")
  if #items > FINDING_NAMES then
    text = L["LEDGER_AND_MORE"]:format(text, #items - FINDING_NAMES)
  end
  return text
end

-- A finding: the icon of its first item, its title and one line of facts, its gold on the right. A click shows the
-- details of its first item; a finding naming more items than it shows lists all of them on hover.
local function CreateFindingRow(parent)
  local row = CreateFrame("Button", nil, parent)
  Native.StyleRow(row)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(28, 28)
  row.icon:SetPoint("LEFT", 10, 0)
  row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  row.gold = Widgets.CreateText(row, Native.RowFont(), "RIGHT")
  row.gold:SetPoint("RIGHT", -12, 0)
  row.gold:SetWidth(140)
  row.gold:SetWordWrap(false)
  row.title = Widgets.CreateText(row, "GameFontNormal")
  row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, 1)
  row.title:SetPoint("RIGHT", row.gold, "LEFT", -8, 0)
  row.title:SetWordWrap(false)
  row.text = Widgets.CreateText(row, "GameFontHighlightSmall")
  row.text:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 10, 0)
  row.text:SetPoint("RIGHT", row.gold, "LEFT", -8, 0)
  row.text:SetWordWrap(false)
  row:SetScript("OnClick", function(self)
    -- a second click closes the details again
    state.selectedKey = state.selectedKey ~= self.key and self.key or nil
    View.Refresh()
  end)
  row:SetScript("OnEnter", function(self)
    if #self.items <= FINDING_NAMES then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.title:GetText())
    for _, item in ipairs(self.items) do
      local color = ITEM_QUALITY_COLORS[item.quality or 1] or ITEM_QUALITY_COLORS[1]
      GameTooltip:AddLine(item.name or "...", color.r, color.g, color.b)
    end
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", GameTooltip_Hide)
  return row
end

local function SetupFindingRow(row, entry, index)
  local finding = entry.finding
  row.key = finding.items[1]
  row.items = entry.items
  Native.SetRowState(row, index, row.key == state.selectedKey)
  row.icon:SetTexture(entry.items[1].icon)
  local texts = FINDING_TEXTS[finding.kind]
  row.title:SetText(L[texts[1]])
  local names = FindingNames(entry.items)
  local kind = finding.kind
  if kind == "top" or kind == "bestseller" then
    row.text:SetText(L[texts[2]]:format(names, finding.count, finding.rate and View.Percent(finding.rate) or "--"))
  elseif kind == "loss" then
    row.text:SetText(L[texts[2]]:format(names, finding.count, finding.unsold))
  else
    row.text:SetText(L[texts[2]]:format(names, finding.count))
  end
  if kind == "stock" then
    -- tied up, not lost
    row.gold:SetText(View.Money(finding.gold))
  elseif kind == "unsold" and finding.gold < 0 then
    row.gold:SetText(View.Loss(-finding.gold) .. View.Incomplete(finding))
  elseif kind == "unsold" then
    -- no known deposit lost: nothing, or only unknown ones
    row.gold:SetText(View.Muted(finding.unknownLosses > 0 and "?" or AM.ZERO_MONEY))
  else
    row.gold:SetText(View.Signed(finding.gold))
  end
end

-- The Overview in a sunken panel under the top tabs: the chart, a line, the findings.
local function CreateOverview()
  local frame = Native.CreateInset(state.panel, true)
  frame:SetPoint("TOPLEFT", 16, -LIST_TOP)
  frame:SetPoint("BOTTOMRIGHT", -16, -1)
  local body = CreateFrame("Frame", nil, frame)
  body:SetPoint("TOPLEFT", Native.PANEL_INSET, -Native.PANEL_INSET)
  body:SetPoint("BOTTOMRIGHT", -Native.PANEL_INSET, Native.PANEL_INSET)
  local chart = CreateChart(body)
  chart:SetPoint("TOPLEFT")
  chart:SetPoint("TOPRIGHT")
  chart:SetHeight(CHART_HEIGHT)
  local line = body:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(unpack(UI.buttonBorder))
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", chart, "BOTTOMLEFT", CHART_PADDING, 0)
  line:SetPoint("TOPRIGHT", chart, "BOTTOMRIGHT", -CHART_PADDING, 0)
  local list = Widgets.CreateList(body, CreateFindingRow, SetupFindingRow)
  list:SetPoint("TOPLEFT", chart, "BOTTOMLEFT", 0, -4)
  list:SetPoint("BOTTOMRIGHT")
  local empty = Widgets.CreateText(body, "GameFontDisableSmall")
  empty:SetPoint("TOPLEFT", list, "TOPLEFT", 12, -8)
  empty:SetPoint("TOPRIGHT", list, "TOPRIGHT", -12, -8)
  empty:SetWordWrap(true)
  return { frame = frame, list = list, empty = empty, chart = chart }
end

View.CreateOverview = CreateOverview
View.DrawChart = DrawChart
