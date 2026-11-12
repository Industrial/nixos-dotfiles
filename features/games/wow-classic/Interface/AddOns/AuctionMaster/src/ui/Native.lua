local _, AM = ...

-- The looks of the game's own auction house for the windows of the addon: its templates, atlases and fonts instead
-- of textures and colors of ours. What they are, their sizes and where they exist is written down in
-- doc/interface/ (style.md of each client). Every piece checks what the client has and settles for something plain
-- where it lacks it, so a missing atlas never raises an error.
AM.Native = {}
local Native = AM.Native

local WHITE = "Interface\\Buttons\\WHITE8X8"
local ROCK = "Interface\\FrameGeneral\\UI-Background-Rock" -- the background of the game's frames

local LIST_BACKGROUND = "auctionhouse-background-index" -- dark fill of the lists of the auction house
local STRIPES = { "auctionhouse-rowstripe-1", "auctionhouse-rowstripe-2" }
local ROW_SELECTED = "auctionhouse-ui-row-select"
local ROW_HIGHLIGHT = "auctionhouse-ui-row-highlight"
local SORT_ARROW = "auctionhouse-ui-sortarrow"
local ICON_BORDER = "auctionhouse-itemicon-small-border"

Native.HEADER_HEIGHT = 19 -- of the column headers
Native.ROW_HEIGHT = 20 -- of the rows of a list
Native.PANEL_INSET = 3 -- what the border of an inset panel takes up

local atlasKnown = {}

function Native.HasAtlas(name)
  local known = atlasKnown[name]
  if known == nil then
    known = C_Texture ~= nil and C_Texture.GetAtlasInfo ~= nil and C_Texture.GetAtlasInfo(name) ~= nil
    atlasKnown[name] = known
  end
  return known
end

-- The auction house of Classic clients (Classic) has its own, older skin: textured panels instead of the atlases of
-- the other clients. Only that family defines this function (checked in the game's source, not on all clients yet),
-- and only once the auction house is loaded. Atlases cannot tell the skins apart: they exist on all clients.
function Native.IsClassicSkin()
  return AuctionHouseUtil ~= nil and AuctionHouseUtil.ApplyClassicBackgroundTexture ~= nil
end

-- The named font if the client has it, else the fallback.
function Native.Font(name, fallback)
  return _G[name] and name or fallback
end

-- The font of the numbers and names in the rows of the auction house.
function Native.RowFont()
  return Native.Font("Number14FontWhite", "GameFontHighlightSmall")
end

-- The flat dark color of our windows on Classic skins, in place of the rock.
Native.CLASSIC_BODY = { 0.08, 0.07, 0.065 }

-- Paints the rock of the game's frames over a frame (its own background stays below, in case the texture is missing).
function Native.AddFrameBackground(frame)
  local rock = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
  rock:SetAllPoints()
  rock:SetTexture(ROCK, "REPEAT", "REPEAT")
  rock:SetHorizTile(true)
  rock:SetVertTile(true)
  return rock
end

-- A sunken panel like the lists of the auction house: the game's inset frame, with the dark fill of the lists on
-- it where the client's auction house uses one (on Classic skins the inset's own marble is that fill). Content goes
-- Native.PANEL_INSET inside. darken puts a dark shade over the fill (not on Classic skins, whose marble is dark enough).
function Native.CreateInset(parent, darken)
  local ok, panel = pcall(CreateFrame, "Frame", nil, parent, "InsetFrameTemplate")
  if not ok then
    return AM.Widgets.CreatePanel(parent)
  end
  if darken and not Native.IsClassicSkin() then
    -- where the fill alone is not dark enough for the text
    local shade = panel:CreateTexture(nil, "BACKGROUND", nil, 7) -- above the inset's own background and the fill
    shade:SetPoint("TOPLEFT", Native.PANEL_INSET, -Native.PANEL_INSET)
    shade:SetPoint("BOTTOMRIGHT", -Native.PANEL_INSET, Native.PANEL_INSET)
    shade:SetColorTexture(0.04, 0.03, 0.03, 0.85)
  end
  if not Native.IsClassicSkin() and Native.HasAtlas(LIST_BACKGROUND) then
    local fill = panel:CreateTexture(nil, "BACKGROUND", nil, -4)
    fill:SetPoint("TOPLEFT", Native.PANEL_INSET, -Native.PANEL_INSET)
    fill:SetPoint("BOTTOMRIGHT", -Native.PANEL_INSET, Native.PANEL_INSET)
    fill:SetAtlas(LIST_BACKGROUND, false)
  end
  return panel
end

-- A list area as in the auction house: a strip for the column headers on top and the inset panel below it.
-- Returns { frame, header, body }: the frame to place, the strip to put the headers in and the area for the list.
function Native.CreateListPanel(parent)
  local frame = CreateFrame("Frame", nil, parent)
  local header = CreateFrame("Frame", nil, frame)
  header:SetPoint("TOPLEFT")
  header:SetPoint("TOPRIGHT")
  header:SetHeight(Native.HEADER_HEIGHT)
  local panel = Native.CreateInset(frame)
  panel:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -1)
  panel:SetPoint("BOTTOMRIGHT")
  local body = CreateFrame("Frame", nil, panel)
  body:SetPoint("TOPLEFT", Native.PANEL_INSET, -Native.PANEL_INSET)
  body:SetPoint("BOTTOMRIGHT", -Native.PANEL_INSET, Native.PANEL_INSET)
  return { frame = frame, header = header, body = body }
end

-- Width a list leaves free on its right for the scroll bar: the bar of the auction house of the client plus its gap.
function Native.ScrollGutter()
  return Native.IsClassicSkin() and 34 or 20
end

-- A scrolling list with the game's own scroll box and scroll bar (the minimal bar of the auction house, the classic
-- one on Classic skins). Same use as Widgets.CreateList, which calls this first; returns nil where the client lacks
-- the pieces so the caller can draw its own. Rows are made once per frame by createRow(parent) and fill the frame
-- of the scroll box, setupRow(row, item, index) is called whenever one is shown; items have their height in
-- item.height. barOffset puts the scroll bar that far right of the list instead of inside it, for a list whose
-- panel leaves the bar room outside (see Attachment.Create); the rows then use the full width.
function Native.CreateScrollList(parent, createRow, setupRow, barOffset)
  if not (ScrollUtil and CreateScrollBoxListLinearView and CreateDataProvider) then
    return nil
  end
  local ok, scrollBox = pcall(CreateFrame, "Frame", nil, parent, "WowScrollBoxList")
  if not ok then
    return nil
  end
  local barTemplates = Native.IsClassicSkin() and { "WowClassicScrollBar", "MinimalScrollBar" }
    or { "MinimalScrollBar", "WowClassicScrollBar" }
  local scrollBar
  for _, template in ipairs(barTemplates) do
    local made, bar = pcall(CreateFrame, "EventFrame", nil, parent, template)
    if made then
      scrollBar = bar
      break
    end
  end
  if not scrollBar then
    scrollBox:Hide()
    return nil
  end

  local list = CreateFrame("Frame", nil, parent)
  scrollBox:SetParent(list)
  scrollBar:SetParent(list)
  scrollBox:SetPoint("TOPLEFT")
  scrollBox:SetPoint("BOTTOMRIGHT", barOffset and 0 or -Native.ScrollGutter(), 0)
  scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", barOffset or 8, 0)
  scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", barOffset or 8, 0)

  local view = CreateScrollBoxListLinearView()
  view:SetElementExtentCalculator(function(_, item)
    return item.height
  end)
  view:SetElementFactory(function(factory)
    factory("Frame", function(frame, item)
      if not frame.row then
        frame.row = createRow(frame)
        frame.row:SetAllPoints()
      end
      setupRow(frame.row, item, frame:GetOrderIndex())
    end)
  end)
  ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

  function list.SetItems(items)
    scrollBox:SetDataProvider(CreateDataProvider(items), ScrollBoxConstants.RetainScrollPosition)
  end

  function list.Render()
    scrollBox:ForEachFrame(function(frame, item)
      setupRow(frame.row, item, frame:GetOrderIndex())
    end)
  end

  function list.ScrollToTop()
    scrollBox:ScrollToBegin(true)
  end

  return list
end

-- A column header like the ones of the auction house lists; clickable only if sortable. The text is
-- button:SetText(...), the sort arrow is toggled with Native.SetSortArrow. Falls back to a plain button.
function Native.CreateHeaderButton(parent, text, sortable)
  local ok, button = pcall(CreateFrame, "Button", nil, parent, "ColumnDisplayButtonShortTemplate")
  if not ok then
    button = CreateFrame("Button", nil, parent)
    button:SetNormalFontObject(GameFontNormalSmall)
    button:SetHeight(Native.HEADER_HEIGHT)
  end
  button:SetText(text)
  button:SetEnabled(sortable and true or false)
  local label = button.Text or button:GetFontString()
  if Native.HasAtlas(SORT_ARROW) and label then
    button.arrow = button:CreateTexture(nil, "OVERLAY")
    button.arrow:SetAtlas(SORT_ARROW, true)
    button.arrow:SetPoint("LEFT", label, "RIGHT", 3, 0)
    button.arrow:Hide()
  end
  return button
end

-- Shows the sort arrow of a header: up when ascending, as in the auction house.
function Native.SetSortArrow(button, active, ascending)
  if not button.arrow then
    return
  end
  button.arrow:SetShown(active)
  if active then
    button.arrow:SetTexCoord(0, 1, ascending and 1 or 0, ascending and 0 or 1)
  end
end

-- The icon of an item in a row: small, with the thin border of the auction house. Returns the icon texture; the
-- border is icon.border.
function Native.CreateItemIcon(row)
  local icon = row:CreateTexture(nil, "ARTWORK")
  icon:SetSize(14, 14)
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  if Native.HasAtlas(ICON_BORDER) then
    icon.border = row:CreateTexture(nil, "OVERLAY")
    icon.border:SetSize(16, 16)
    icon.border:SetAtlas(ICON_BORDER, false)
    icon.border:SetPoint("CENTER", icon)
  end
  return icon
end

-- Gives a row the looks of the rows of the auction house: alternating stripes, a glow under the selected row and
-- the glow of the mouse over it. Use Native.SetRowState for every use of the row.
function Native.StyleRow(row)
  row.stripe = row:CreateTexture(nil, "BACKGROUND")
  row.stripe:SetAllPoints()
  row.selectedGlow = row:CreateTexture(nil, "ARTWORK", nil, -2)
  row.selectedGlow:SetAllPoints()
  row.selectedGlow:SetBlendMode("ADD")
  row.selectedGlow:Hide()
  row:SetHighlightTexture(WHITE)
  local highlight = row:GetHighlightTexture()
  highlight:SetBlendMode("ADD")
  if Native.HasAtlas(ROW_HIGHLIGHT) then
    highlight:SetAtlas(ROW_HIGHLIGHT)
  else
    highlight:SetVertexColor(1, 1, 1, 0.06)
  end
  if Native.HasAtlas(ROW_SELECTED) then
    row.selectedGlow:SetAtlas(ROW_SELECTED)
  else
    row.selectedGlow:SetColorTexture(1, 0.82, 0, 0.15)
  end
end

-- index is the position in the list, which decides the stripe.
function Native.SetRowState(row, index, selected)
  local atlas = STRIPES[index % 2 == 1 and 1 or 2]
  if Native.HasAtlas(atlas) then
    row.stripe:SetAtlas(atlas)
  else
    row.stripe:SetColorTexture(1, 1, 1, index % 2 == 1 and 0 or 0.04)
  end
  row.selectedGlow:SetShown(selected)
end

-- A small button for the title bar of the auction house, left of its close button, in the same red art (a small panel
-- button on Classic, whose close button looks different). The symbol is button.icon: set a texture or atlas on it.
-- Anchor it with button:SetPoint("RIGHT", other, "LEFT", Native.TitleButtonNudge(), 0) where other is the close button.
function Native.CreateTitleButton(parent)
  local isClassic = AM.Client.IsClassic()
  local atlasInfo = not isClassic and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("RedButton-Exit")
  local button = CreateFrame("Button", nil, parent, not atlasInfo and "UIPanelButtonTemplate" or nil)
  if atlasInfo then
    button:SetNormalAtlas("RedButton-Exit")
    button:SetPushedAtlas("RedButton-exit-pressed")
    button:SetHighlightAtlas("RedButton-Highlight", "ADD")
  end
  local close = parent.CloseButton
  local size = isClassic and 24 or close and close:GetWidth() or 22
  button:SetSize(size, size)
  -- The frame's border (NineSlice) and title container sit at levels 500-510 and would cover the button.
  button:SetFrameLevel(parent:GetFrameLevel() + 600)
  -- There is no symbol-free version of the close button, so a plain red strip of its art covers the X.
  local cover
  if atlasInfo then
    cover = button:CreateTexture(nil, "ARTWORK", nil, 1)
    cover:SetSize(size * 0.64, size * 0.64)
    cover:SetPoint("CENTER")
    cover:SetTexture(atlasInfo.file or atlasInfo.filename)
    local width = atlasInfo.rightTexCoord - atlasInfo.leftTexCoord
    local height = atlasInfo.bottomTexCoord - atlasInfo.topTexCoord
    cover:SetTexCoord(atlasInfo.leftTexCoord + width * 0.2, atlasInfo.leftTexCoord + width * 0.24,
      atlasInfo.topTexCoord + height * 0.3, atlasInfo.topTexCoord + height * 0.7)
  end
  local icon = button:CreateTexture(nil, "OVERLAY")
  icon:SetSize(size * 0.65, size * 0.65)
  icon:SetPoint("CENTER")
  button.icon = icon
  button:HookScript("OnMouseDown", function()
    icon:SetPoint("CENTER", 1, -1)
    if cover then cover:SetVertexColor(0.75, 0.75, 0.75) end
  end)
  button:HookScript("OnMouseUp", function()
    icon:SetPoint("CENTER")
    if cover then cover:SetVertexColor(1, 1, 1) end
  end)
  return button
end

-- On Classic the close button's art is inset in its frame and sits lower, so buttons next to it are nudged to match.
function Native.TitleButtonNudge()
  return AM.Client.IsClassic() and 6 or 0
end
