local addonName, AM = ...

-- Building blocks of the main window and its views (see AM.MainWindow): boxes, buttons and a scrolling list
-- that only creates the rows which are visible. Colors come from AM.Theme.ui.
AM.Widgets = {}
local Widgets = AM.Widgets

local WHITE = "Interface\\Buttons\\WHITE8X8"
local UI = AM.Theme.ui

local function Rgb(color)
  return color[1], color[2], color[3]
end

-- The letters texture fills almost its whole square and is centred in it, the logo ring would cut it: draw it
-- smaller, centred on the parent.
-- scale: share of the logo's size; shiftX to the right and shiftY up, as a share of the letters' size.
local LETTERS = { scale = 0.7, shiftX = 0.06, shiftY = 0.06 }
local LETTERS_CLASSIC = { scale = 0.8, shiftX = 0.04, shiftY = 0.04 }

function Widgets.PlaceLetters(texture, parent, size)
  local config = AM.Client.IsClassic() and LETTERS_CLASSIC or LETTERS
  local letters = size * config.scale
  texture:SetSize(letters, letters)
  texture:SetPoint("CENTER", parent, "CENTER", config.shiftX * letters, config.shiftY * letters)
end

-- The round background (dark and bright orange) of the logo, in its square, shifted and scaled like the letters.
local BACKGROUND_SCALE = 1
local BACKGROUND_SHIFT_X = 0 -- share of the background's size, to the right
local BACKGROUND_SHIFT_Y = 0 -- up

function Widgets.PlaceBackground(texture, parent, size)
  local background = size * BACKGROUND_SCALE
  texture:SetSize(background, background)
  texture:SetPoint("CENTER", parent, "CENTER", BACKGROUND_SHIFT_X * background, BACKGROUND_SHIFT_Y * background)
end

-- Wraps the text in a color given as hex ("ffd200").
function Widgets.Color(hex, text)
  return "|cff" .. hex .. text .. "|r"
end

-- A frame with a flat background and a 1 pixel border.
function Widgets.CreateBox(parent, background, border)
  local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  box:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  box:SetBackdropColor(Rgb(background))
  box:SetBackdropBorderColor(Rgb(border))
  return box
end

-- The dark, sunken panel that holds lists.
function Widgets.CreatePanel(parent)
  return Widgets.CreateBox(parent, UI.sunken, UI.black)
end

function Widgets.CreateText(parent, template, justify)
  local text = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall")
  text:SetJustifyH(justify or "LEFT")
  return text
end

-- Paints the texture with a horizontal gradient from left to right.
function Widgets.GradientH(texture, left, right)
  texture:SetColorTexture(1, 1, 1, 1)
  if texture.SetGradientAlpha then
    texture:SetGradientAlpha("HORIZONTAL", left[1], left[2], left[3], 1, right[1], right[2], right[3], 1)
  else
    texture:SetGradient("HORIZONTAL", CreateColor(left[1], left[2], left[3], 1),
      CreateColor(right[1], right[2], right[3], 1))
  end
end

-- A flat button drawn by us, for where the game's button does not fit (small square buttons) or is missing.
-- red is the main action of a view, else it is a quiet dark button.
local function CreateFlatButton(parent, text, red, onClick)
  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  button:SetHeight(22)
  button:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  if red then
    button:SetBackdropColor(Rgb(UI.red[2]))
    button:SetBackdropBorderColor(0, 0, 0)
  else
    button:SetBackdropColor(Rgb(UI.button))
    button:SetBackdropBorderColor(Rgb(UI.buttonBorder))
  end
  button:SetHighlightTexture(WHITE)
  button:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.1)
  button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  button.text:SetPoint("CENTER")
  function button:SetLabel(label, padding)
    self.text:SetText(label)
    self:SetWidth(self.text:GetStringWidth() + 2 * (padding or 12))
  end
  button:SetScript("OnDisable", function(self)
    self.text:SetTextColor(0.5, 0.5, 0.5)
  end)
  button:SetScript("OnEnable", function(self)
    self.text:SetTextColor(1, 0.82, 0)
  end)
  button:SetLabel(text or "")
  if onClick then
    button:SetScript("OnClick", onClick)
  end
  return button
end

-- A button with a text, the game's own (the one of the auction house's "Search" and "Create Auction"). The
-- unused argument is where the main action of a view used to be marked: the game's button has a single look.
-- button:SetLabel(text) sets the text and sizes the button to it.
function Widgets.CreateButton(parent, text, _, onClick, template)
  local ok, button = pcall(CreateFrame, "Button", nil, parent, template or "UIPanelButtonTemplate")
  if not ok and template then
    ok, button = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
  end
  if not ok then
    return CreateFlatButton(parent, text, false, onClick)
  end
  button:SetHeight(22)
  function button:SetLabel(label, padding)
    self:SetText(label)
    self:SetWidth(self:GetFontString():GetStringWidth() + 2 * (padding or 12))
  end
  button:SetLabel(text or "")
  if onClick then
    button:SetScript("OnClick", onClick)
  end
  return button
end

-- A button for a secondary action: the game's grey one where the client has it (Retail), else the usual one.
-- Its text is yellow like the auction house's "Filter" button.
function Widgets.CreateSecondaryButton(parent, text, onClick)
  local button = Widgets.CreateButton(parent, text, false, onClick, "UIPanelButtonGrayTemplate")
  button:SetNormalFontObject(GameFontNormal)
  button:SetHighlightFontObject(GameFontHighlight)
  button:SetDisabledFontObject(GameFontDisable)
  return button
end

-- A small square button with a text such as "+" or "x".
function Widgets.CreateIconButton(parent, text, size, onClick)
  local button = CreateFlatButton(parent, text, false, onClick)
  button:SetSize(size or 22, size or 22)
  return button
end

-- A small, muted "×" without a background that brightens under the cursor, for removing an entry of a list.
function Widgets.CreateRemoveButton(parent, tooltip, onClick)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(16, 16)
  local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  text:SetPoint("CENTER", 0, 1)
  text:SetText("×")
  text:SetTextColor(0.3, 0.3, 0.3)
  button:SetScript("OnEnter", function(self)
    text:SetTextColor(0.55, 0.55, 0.55)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(tooltip, 1, 1, 1)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    text:SetTextColor(0.3, 0.3, 0.3)
    GameTooltip_Hide()
  end)
  button:SetScript("OnClick", onClick)
  return button
end

-- A bar filled with the ember gradient on a dark track. With framed, the track is a very dark version of
-- the ember color and the bar has a dark brown border (the header bar); otherwise it is plain.
function Widgets.CreateProgressBar(parent, height, framed)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetHeight(height)
  bar:SetStatusBarTexture(WHITE)
  Widgets.GradientH(bar:GetStatusBarTexture(), UI.emberStart, UI.emberEnd)
  local track = bar:CreateTexture(nil, "BACKGROUND")
  track:SetAllPoints()
  if not framed then
    track:SetColorTexture(0.04, 0.04, 0.04, 1)
    return bar
  end
  local dim = 0.12
  track:SetColorTexture((UI.emberStart[1] + UI.emberEnd[1]) / 2 * dim, (UI.emberStart[2] + UI.emberEnd[2]) / 2 * dim,
    (UI.emberStart[3] + UI.emberEnd[3]) / 2 * dim, 1)
  local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
  border:SetAllPoints()
  border:SetFrameLevel(bar:GetFrameLevel() + 1)
  border:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
  border:SetBackdropBorderColor(0.2, 0.14, 0.09)
  return bar
end

-- Shows a one line tooltip while the cursor is over the frame.
function Widgets.SetTooltip(frame, text)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(type(text) == "function" and text() or text, 1, 1, 1)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", GameTooltip_Hide)
end

-- A mouse zone over the icon and the name of a list row, so the item tooltip does not pop up while the
-- cursor is anywhere else on the row. Clicks go on to the row. onEnter(row) and onLeave(row) are called
-- with the row; hover.Fit(icon, name) stretches the zone over the icon and the text of the name (only the icon if
-- name is omitted).
function Widgets.CreateItemHover(row, onEnter, onLeave)
  local hover = CreateFrame("Button", nil, row)
  hover:SetScript("OnClick", function(_, mouseButton)
    row:Click(mouseButton)
  end)
  hover:SetScript("OnEnter", function()
    onEnter(row)
  end)
  hover:SetScript("OnLeave", function()
    onLeave(row)
  end)
  function hover.Fit(icon, name)
    hover:ClearAllPoints()
    hover:SetPoint("TOP", row, "TOP")
    hover:SetPoint("BOTTOM", row, "BOTTOM")
    hover:SetPoint("LEFT", icon, "LEFT")
    if not name then
      hover:SetPoint("RIGHT", icon, "RIGHT")
      return
    end
    local width = name:GetStringWidth()
    local available = name:GetWidth()
    hover:SetPoint("RIGHT", name, "LEFT", available > 0 and math.min(width, available) or width, 0)
  end
  return hover
end

-- A list of rows below each other, scrolled with the mouse wheel. Only the rows in view exist, so
-- thousands of items cost no more than a screenful. createRow(parent) makes a row (a frame) once,
-- setupRow(row, item, index) fills it for an item, which has to reset everything it uses. Items are
-- tables with their height in item.height. list.SetItems(items) shows new items and keeps the scroll
-- position as far as it fits, list.Render() redraws, list.ScrollToTop() goes back to the first item.
-- barOffset puts the game's scroll bar outside the list (see Attachment.CreateList).
function Widgets.CreateList(parent, createRow, setupRow, barOffset)
  local native = AM.Native.CreateScrollList(parent, createRow, setupRow, barOffset)
  if native then
    return native
  end
  local list = CreateFrame("Frame", nil, parent)
  list:SetClipsChildren(true)
  list:EnableMouseWheel(true)

  local items, tops, total = {}, {}, 0
  local offset = 0
  local pool = {}

  -- thin scroll indicator on the right edge
  local bar = CreateFrame("Frame", nil, list)
  bar:SetFrameLevel(list:GetFrameLevel() + 20)
  bar:SetWidth(3)
  bar:SetPoint("TOPRIGHT", -1, -1)
  bar:SetPoint("BOTTOMRIGHT", -1, 1)
  local thumb = bar:CreateTexture(nil, "OVERLAY")
  thumb:SetColorTexture(Rgb(UI.border))
  thumb:SetWidth(3)

  function list.Render()
    local viewHeight = list:GetHeight()
    offset = math.min(math.max(offset, 0), math.max(total - viewHeight, 0))
    -- keep the rows clear of the scroll indicator
    local inset = total > viewHeight and 8 or 0
    local used = 0
    for i, item in ipairs(items) do
      local top = tops[i]
      if top >= offset + viewHeight then
        break
      end
      if top + item.height > offset then
        used = used + 1
        local row = pool[used]
        if not row then
          row = createRow(list)
          pool[used] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, offset - top)
        row:SetPoint("TOPRIGHT", -inset, offset - top)
        row:SetHeight(item.height)
        row:Show()
        setupRow(row, item, i)
      end
    end
    for i = used + 1, #pool do
      pool[i]:Hide()
    end
    if total > viewHeight and viewHeight > 0 then
      local height = bar:GetHeight()
      local thumbHeight = math.max(height * viewHeight / total, 12)
      thumb:ClearAllPoints()
      thumb:SetPoint("TOP", 0, -(height - thumbHeight) * offset / (total - viewHeight))
      thumb:SetHeight(thumbHeight)
      thumb:Show()
    else
      thumb:Hide()
    end
  end

  function list.SetItems(newItems)
    items = newItems
    total = 0
    for i, item in ipairs(items) do
      tops[i] = total
      total = total + item.height
    end
    list.Render()
  end

  function list.ScrollToTop()
    offset = 0
    list.Render()
  end

  list:SetScript("OnMouseWheel", function(_, delta)
    offset = offset - delta * 48
    list.Render()
  end)
  list:SetScript("OnSizeChanged", list.Render)
  return list
end

local ASSETS = "Interface\\AddOns\\" .. addonName .. "\\assets\\"
local LEATHER_ATLAS = "Legacy-Rewards-Tracker-background" -- background of the legacy window

-- Paints the leather of the legacy window over the whole box, where the client has it. Otherwise the box keeps
-- its own background.
function Widgets.AddLeather(box)
  if C_Texture.GetAtlasInfo(LEATHER_ATLAS) then
    local leather = box:CreateTexture(nil, "BACKGROUND")
    leather:SetAllPoints()
    leather:SetAtlas(LEATHER_ATLAS)
    return leather
  end
end

-- The window on clients whose frame templates (ButtonFrameTemplate on Classic) carry too much of their own
-- decoration behind our content: drawn entirely by us, a flat body with a thin border, a title bar with the
-- title, the close button and the round logo. Same result and fields (CloseButton) as the game's frame below.
local function CreateOwnFrame(title, onMoved, noPortrait, parent)
  local frame = Widgets.CreateBox(parent or UIParent, UI.body, UI.border)
  frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 2 })
  frame:SetBackdropColor(Rgb(UI.body))
  frame:SetBackdropBorderColor(Rgb(UI.border))
  AM.Native.AddFrameBackground(frame) -- the rock of the game's frames over the flat color
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)

  local bar = frame:CreateTexture(nil, "BACKGROUND", nil, 2) -- above the rock
  bar:SetPoint("TOPLEFT", 2, -2)
  bar:SetPoint("TOPRIGHT", -2, -2)
  bar:SetHeight(26)
  AM.Theme.ApplyTitleBar(bar) -- the title bar of the game's frames

  local inner = Widgets.CreateBox(frame, UI.body, UI.black)
  inner:SetPoint("TOPLEFT", 7, -32)
  inner:SetPoint("BOTTOMRIGHT", -7, 7)
  inner:SetBackdropColor(0, 0, 0, 0)
  inner:SetBackdropBorderColor(0, 0, 0, 0)
  local level = inner:GetFrameLevel()

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetSize(26, 26)
  close:SetPoint("TOPRIGHT", -1, -1)
  close:SetFrameLevel(level + 60)
  close:SetScript("OnClick", function()
    frame:Hide()
  end)
  frame.CloseButton = close

  local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  text:SetText(title)
  text:SetPoint("TOP", 0, -8)
  frame.TitleText = text

  -- The window is dragged by its title bar, the close button and the one beside it stay free.
  local drag = CreateFrame("Frame", nil, frame)
  drag:SetPoint("TOPLEFT", 0, 0)
  drag:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -56, -28)
  drag:SetFrameLevel(level + 30)
  drag:EnableMouse(true)
  drag:RegisterForDrag("LeftButton")
  drag:SetScript("OnDragStart", function()
    frame:StartMoving()
  end)
  drag:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    onMoved(frame)
  end)

  local logoFrame = CreateFrame("Frame", nil, frame)
  logoFrame:SetFrameLevel(level + 55)
  logoFrame:EnableMouse(false)
  if noPortrait then
    logoFrame:SetSize(20, 20)
    logoFrame:SetPoint("TOPLEFT", 8, -5)
    local logo = logoFrame:CreateTexture(nil, "ARTWORK")
    logo:SetAllPoints()
    logo:SetTexture(ASSETS .. "logo")
    text:ClearAllPoints()
    text:SetPoint("LEFT", logo, "RIGHT", 6, 0)
  else
    -- the round logo hangs over the top left corner, cut round by a mask
    logoFrame:SetSize(64, 64)
    logoFrame:SetPoint("TOPLEFT", -12, 12)
    local mask = logoFrame:CreateMaskTexture()
    mask:SetAllPoints()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKANDWHITE", "CLAMPTOBLACKANDWHITE")
    for index, name in ipairs({ "portrait_orange_dark", "portrait_orange", "internal\\letters-128" }) do
      local layer = logoFrame:CreateTexture(nil, "ARTWORK", nil, index)
      layer:SetTexture(ASSETS .. name)
      if index == 3 then
        Widgets.PlaceLetters(layer, logoFrame, 64)
      else
        Widgets.PlaceBackground(layer, logoFrame, 64)
      end
      layer:AddMaskTexture(mask)
    end
  end
  return frame, inner
end

-- Makes a window like the game's own: PortraitFrameTemplate (clients without its nine-slice layout get
-- CreateOwnFrame) with the logo in its portrait slot, whose ring belongs to the frame border and
-- is raised above the content so the content does not cover it. Returns the frame, to be sized, positioned and
-- filled by the caller, and the box inside its border to put the content in. onMoved(frame) is called after the
-- window was dragged by its title. parent is the frame it belongs to (UIParent if omitted). With noPortrait the frame has no portrait slot, only the small logo in the title bar.
function Widgets.CreatePortraitFrame(title, onMoved, noPortrait, parent)
  if not (NineSliceLayouts and NineSliceLayouts.PortraitFrameTemplate) then
    return CreateOwnFrame(title, onMoved, noPortrait, parent)
  end
  local frame = CreateFrame("Frame", nil, parent or UIParent, "PortraitFrameTemplate")
  if noPortrait and ButtonFrameTemplate_HidePortrait then
    ButtonFrameTemplate_HidePortrait(frame)
  end
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  local inner = Widgets.CreateBox(frame, UI.body, UI.border)
  inner:SetPoint("TOPLEFT", 7, -23)
  inner:SetPoint("BOTTOMRIGHT", -7, 7)
  -- the rock of the game's frames instead of a flat color, without our border
  inner:SetBackdropBorderColor(0, 0, 0, 0)
  AM.Native.AddFrameBackground(inner)

  if frame.SetTitle then
    frame:SetTitle(title)
  elseif frame.TitleContainer and frame.TitleContainer.TitleText then
    frame.TitleContainer.TitleText:SetText(title)
  elseif frame.TitleText then
    frame.TitleText:SetText(title)
  end
  local dragTarget = frame.TitleContainer or frame
  if noPortrait and frame.TitleContainer then
    -- Without the portrait the game stretches its title container over the whole title bar, where it takes the
    -- mouse from the buttons. The window is dragged by a frame of our own below them instead.
    frame.TitleContainer:EnableMouse(false)
    dragTarget = CreateFrame("Frame", nil, frame)
    dragTarget:SetPoint("TOPLEFT", 0, 0)
    dragTarget:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -56, -24) -- leaves the close button and the one beside it free
    dragTarget:SetFrameLevel(inner:GetFrameLevel() + 30)
  end
  dragTarget:EnableMouse(true)
  dragTarget:RegisterForDrag("LeftButton")
  dragTarget:SetScript("OnDragStart", function()
    frame:StartMoving()
  end)
  dragTarget:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    onMoved(frame)
  end)
  if frame.CloseButton then
    frame.CloseButton:SetScript("OnClick", function()
      frame:Hide()
    end)
  end
  -- The logo as in the auction house (dark background, logo, letters), cut round by a mask so that the ring of
  -- the frame border covers its edge.
  local container = frame.PortraitContainer
  local portrait = container and container.portrait or (frame.GetPortrait and frame:GetPortrait()) or frame.portrait
  if noPortrait then
    portrait = nil
    -- the small logo in front of the title shows whose window it is
    local titleText = (frame.TitleContainer and frame.TitleContainer.TitleText) or frame.TitleText
    -- on a frame of its own: the game hides the portrait container together with the portrait
    local titleLogo = CreateFrame("Frame", nil, frame)
    -- only as big as the logo: a frame over the whole window would sit on top of the buttons in the title bar
    titleLogo:SetSize(16, 16)
    if frame.TitleContainer then
      -- centered in the title bar, whatever its height; the title follows the logo
      titleLogo:SetPoint("LEFT", frame.TitleContainer, "LEFT", AM.Theme.titleLogoInset, AM.Theme.titleLogoOffset)
    else
      titleLogo:SetPoint("TOPLEFT", frame, "TOPLEFT", 13, -5)
    end
    titleLogo:SetFrameLevel(inner:GetFrameLevel() + 55)
    titleLogo:EnableMouse(false)
    local logo = titleLogo:CreateTexture(nil, "ARTWORK")
    logo:SetAllPoints()
    logo:SetTexture(ASSETS .. "logo")
    if titleText then
      titleText:ClearAllPoints()
      titleText:SetPoint("LEFT", logo, "RIGHT", 6, 0)
      titleText:SetJustifyH("LEFT")
    end
  end
  if portrait then
    portrait:Hide()
    for index, name in ipairs({ "portrait_orange_dark", "portrait_orange", "internal\\letters-128" }) do
      local layer = container:CreateTexture(nil, "ARTWORK", nil, index)
      layer:SetTexture(ASSETS .. name)
      if index == 3 then
        Widgets.PlaceLetters(layer, portrait, (portrait:GetWidth() or 64) - 6)
      else
        Widgets.PlaceBackground(layer, portrait, (portrait:GetWidth() or 64) - 6)
      end
    end
  end
  -- No flat color of ours: the leather of the legacy window where the client has it, else the frame's own
  -- background shows through.
  inner:SetBackdropColor(0, 0, 0, 0)
  inner:SetBackdropBorderColor(0, 0, 0, 0)
  Widgets.AddLeather(inner)
  local level = inner:GetFrameLevel()
  container:SetFrameLevel(level + 40)
  if frame.NineSlice then
    frame.NineSlice:SetFrameLevel(level + 50)
  end
  return frame, inner
end
