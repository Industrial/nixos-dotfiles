local addonName, AM = ...
local L = AM.L

AM.Portrait = {}
local Portrait = AM.Portrait

local ASSETS = "Interface\\AddOns\\" .. addonName .. "\\assets\\"
local SIZE = 55
local RING_SIZE = 72
local BLINK_INTERVAL = 1.5 -- seconds from bright to dark
local MIN_LOGO_ALPHA = 0.15
local SWEEP_SECONDS = 1.5 -- from one end of the title bar to the other
local SWEEP_WIDTH = 140
local BAR_RING_OVERLAP = 10 -- the game's ring is smaller than the one we draw: the bar starts this much inside it
local SWEEP_OVERSHOOT = 20-- how far the light runs past the left end of the bar, which its faded edge hides
local SWEEP_ALPHA = 0.45
local SWEEP_LIGHT = 1 -- the light runs from white (logo bright) ...
local SWEEP_DIM = 0.6 -- ... to light grey (logo dark)

local button
local scanTicker
local panels = {} -- frames of the attachments, in the order created
local animating = {} -- who wants the logo to blink: "scan" (the full scan, the default), "sell"

local function UpdateTooltip(owner)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetText(addonName, 1, 1, 1)
  if AM.Scan.IsRunning() then
    GameTooltip:AddLine(L["TOOLTIP_SCAN_RUNNING"]:format(math.floor(GetTime() - AM.Scan.GetStartTime())))
  end
  GameTooltip:Show()
end

local function HideDefaultPortrait(parent)
  if parent.PortraitContainer then
    parent.PortraitContainer:Hide()
  end
end

-- The auction house UI is load on demand, so the frame may not exist yet.
local function CreatePortrait()
  local parent = AuctionHouseFrame
  if not parent or button then
    return
  end

  button = CreateFrame("Button", addonName .. "Portrait", parent)
  button:SetSize(SIZE, SIZE)
  button:SetPoint("TOPLEFT", -4, 5)
  -- above the main window, which covers the content of the auction house and reaches under the portrait. Not
  -- SetToplevel: a click would raise it above the ring of the frame border, which must stay on top
  button:SetFrameLevel(parent:GetFrameLevel() + 300)

  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints()
  background:SetTexture(ASSETS .. "portrait_orange_dark")

  local logo = button:CreateTexture(nil, "ARTWORK")
  logo:SetAllPoints()
  logo:SetTexture(ASSETS .. "portrait_orange")
  button.logo = logo

  local letters = button:CreateTexture(nil, "OVERLAY")
  AM.Widgets.PlaceLetters(letters, button, SIZE)
  letters:SetTexture(ASSETS .. "internal\\letters-128")

  -- Where the game's ring is no texture of the frame we can rely on (Classic, where our window covers part of it, or
  -- a UI addon that restyles the window and removes it) we draw a ring of our own below the logo: round discs (a color
  -- texture cut round by a mask) stacked from the outside in: metal, gold edge, dark gap.
  local ring = {}
  local discs = {
    { RING_SIZE, 0.42, 0.41, 0.38 },
    { RING_SIZE - 6, 0.12, 0.11, 0.10 },
    { RING_SIZE - 8, 0.80, 0.64, 0.12 },
    { RING_SIZE - 10, 0.10, 0.09, 0.08 },
  }
  for index, disc in ipairs(discs) do
    local texture = button:CreateTexture(nil, "BACKGROUND", nil, index - 8)
    texture:SetSize(disc[1], disc[1])
    texture:SetPoint("CENTER")
    texture:SetColorTexture(disc[2], disc[3], disc[4], 1)
    local mask = button:CreateMaskTexture()
    mask:SetAllPoints(texture)
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKANDWHITE", "CLAMPTOBLACKANDWHITE")
    texture:AddMaskTexture(mask)
    ring[#ring + 1] = texture
  end
  local function UpdateRing()
    local isClassic = WOW_PROJECT_ID and WOW_PROJECT_MISTS_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC
    -- the frame art is faded out as a whole (alpha 0), the ring being part of it
    local restyled = parent.NineSlice and parent.NineSlice:GetAlpha() == 0
    for _, texture in ipairs(ring) do
      texture:SetShown(isClassic or restyled or false)
    end
  end
  UpdateRing()
  -- the restyling may come after the portrait was created
  parent:HookScript("OnShow", UpdateRing)

  button:SetScript("OnEnter", function(self)
    logo:SetTexture(ASSETS .. "portrait_orange_highlight")
    UpdateTooltip(self)
    if AM.Scan.IsRunning() then
      scanTicker = C_Timer.NewTicker(1, function()
        UpdateTooltip(self)
      end)
    end
  end)
  button:SetScript("OnLeave", function()
    logo:SetTexture(ASSETS .. "portrait_orange")
    GameTooltip:Hide()
    if scanTicker then
      scanTicker:Cancel()
      scanTicker = nil
    end
  end)

  HideDefaultPortrait(parent)
end

-- A horizontal fade from one alpha to the other, with a flat color as fallback where the client has no gradients.
local function SetFade(texture, fromAlpha, toAlpha, level)
  local r, g, b = level, level, level
  texture:SetColorTexture(1, 1, 1, 1) -- a gradient only tints the texture, it needs a plain white one below
  local ok = CreateColor and pcall(texture.SetGradient, texture, "HORIZONTAL",
    CreateColor(r, g, b, fromAlpha), CreateColor(r, g, b, toAlpha))
  if not ok then
    texture:SetColorTexture(r, g, b, (fromAlpha + toAlpha) / 2)
  end
end

-- The bar over the title of the auction house, shown while the logo blinks: a light that sweeps from left to right
-- and back, with the text in the middle. It takes the place of the game's title text meanwhile.
local function CreateScanBar(host)
  local container = host.TitleContainer
  if not container then
    return nil
  end
  local bar = CreateFrame("Frame", nil, container)
  bar:SetAllPoints(container)
  bar:SetFrameLevel(container:GetFrameLevel() + 5)
  bar:SetClipsChildren(true)
  bar:Hide()

  local left = bar:CreateTexture(nil, "ARTWORK")
  local right = bar:CreateTexture(nil, "ARTWORK")
  left:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
  left:SetWidth(SWEEP_WIDTH / 2)
  right:SetPoint("TOPLEFT", left, "TOPRIGHT")
  right:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT")
  right:SetWidth(SWEEP_WIDTH / 2)
  SetFade(left, 0, SWEEP_ALPHA, SWEEP_LIGHT)
  SetFade(right, SWEEP_ALPHA, 0, SWEEP_LIGHT)
  bar.sweep = left
  bar.sweepRight = right

  bar.titles = {}
  bar.container = container
  local text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  text:SetPoint("CENTER", container, "CENTER") -- where the game's title is, whatever the bar covers
  bar.text = text

  -- Some clients have a title text in the container and another on the frame itself, and set the title on one of
  -- them (the one GetTitleText returns), so every one found is hidden.
  for _, title in ipairs({
    host.GetTitleText and host:GetTitleText() or false,
    container.TitleText or false,
    host.TitleText or false,
  }) do
    if title and not tContains(bar.titles, title) then
      bar.titles[#bar.titles + 1] = title
    end
  end
  return bar
end

-- Shows or hides a bar and the title it takes the place of.
local function SetBarShown(bar, show)
  bar:SetShown(show)
  for _, title in ipairs(bar.titles) do
    title:SetAlpha(show and 0 or 1)
  end
  if show then
    bar.text:SetText(L["SCAN_BAR"])
  end
end

-- The panels beside the auction house (AM.Attachment) get a bar as well: it is a child of their title bar and so
-- shows and hides with them.
local function ShowPanelBars(show)
  for _, panel in ipairs(panels) do
    if show and not panel.scanBar then
      panel.scanBar = CreateScanBar(panel) or false
    end
    if panel.scanBar then
      SetBarShown(panel.scanBar, show)
    end
  end
end

function Portrait.AddPanel(panel)
  panels[#panels + 1] = panel
  if button and button.blinkTime then
    ShowPanelBars(true)
  end
end

-- The logo and its ring lie over the left end of the title bar, and the border of the game's frame is above the title
-- bar: the bar of the auction house starts at the edge of the ring and is put above that border, so the light is not
-- cut off by either.
local function PlaceMainBar(bar, host)
  local container = bar.container
  if not (button:GetLeft() and container:GetLeft()) then
    return
  end
  -- negative where the title bar of the game starts right of the ring (there is a piece of the frame between)
  local inset = button:GetLeft() + (SIZE + RING_SIZE) / 2 - BAR_RING_OVERLAP - container:GetLeft()
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", container, "TOPLEFT", inset, 0)
  bar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
  local border = host.NineSlice
  bar:SetFrameLevel(math.max(container:GetFrameLevel() + 5, border and (border:GetFrameLevel() + 1) or 0))
end

local function ShowScanBar(show)
  if not AuctionHouseFrame then
    return
  end
  ShowPanelBars(show)
  if show and not button.bar then
    button.bar = CreateScanBar(AuctionHouseFrame) -- nil where the client has no title container, the logo blinks alone there
  end
  local bar = button.bar
  if not bar then
    return
  end
  SetBarShown(bar, show)
  if show then
    PlaceMainBar(bar, AuctionHouseFrame)
  end
end

-- The light runs over the title bars as if they were one: along the bars from left to right on screen (the auction
-- house, and the panel beside it where one is open), and back the same way. Its color follows the logo.
local function MoveSweep(bars, position, brightness)
  local lit = {}
  for _, bar in ipairs(bars) do
    if bar and bar:IsVisible() and bar:GetLeft() then
      lit[#lit + 1] = bar
    end
  end
  table.sort(lit, function(a, b)
    return a:GetLeft() < b:GetLeft()
  end)
  local total = 0
  for _, bar in ipairs(lit) do
    total = total + bar:GetWidth()
  end
  -- Left end of the light along the strip: from SWEEP_OVERSHOOT left of the strip to where the right end of the light
  -- meets the right end of the strip (the bars cut off what lies outside).
  local lowest = -SWEEP_OVERSHOOT
  local x = lowest + (math.max(total - SWEEP_WIDTH, 0) - lowest) * position
  local start = 0
  for _, bar in ipairs(lit) do
    -- the bars cut off what lies outside of them
    if bar.level ~= brightness then
      bar.level = brightness
      SetFade(bar.sweep, 0, SWEEP_ALPHA, brightness)
      SetFade(bar.sweepRight, SWEEP_ALPHA, 0, brightness)
    end
    bar.sweep:ClearAllPoints()
    bar.sweep:SetPoint("TOPLEFT", bar, "TOPLEFT", x - start, 0)
    bar.sweep:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x - start, 0)
    start = start + bar:GetWidth()
  end
end

-- Triangle wave alpha, same shape as the original AuctionMaster's scan indicator.
local function OnAnimateUpdate(self, elapsed)
  self.blinkTime = self.blinkTime + elapsed
  local triangle = math.fmod(self.blinkTime, BLINK_INTERVAL * 2)
  local offset = math.abs(triangle - BLINK_INTERVAL) / BLINK_INTERVAL
  self.logo:SetAlpha(MIN_LOGO_ALPHA + (1 - MIN_LOGO_ALPHA) * offset)

  local position = math.abs(math.fmod(self.blinkTime, SWEEP_SECONDS * 2) - SWEEP_SECONDS) / SWEEP_SECONDS
  position = position * position * (3 - 2 * position) -- eased at both ends
  local bars = { self.bar }
  for _, panel in ipairs(panels) do
    bars[#bars + 1] = panel.scanBar
  end
  MoveSweep(bars, position, SWEEP_DIM + (SWEEP_LIGHT - SWEEP_DIM) * offset)
end

-- The logo blinks while anyone asked for it (owner: "scan" by default, "sell" for the scan of the items to sell).
function Portrait.StartAnimate(owner)
  animating[owner or "scan"] = true
  if not button or button.blinkTime then
    return
  end
  button.blinkTime = 0
  ShowScanBar(true)
  button:SetScript("OnUpdate", OnAnimateUpdate)
end

function Portrait.StopAnimate(owner)
  animating[owner or "scan"] = nil
  if not button or next(animating) then
    return
  end
  button:SetScript("OnUpdate", nil)
  button.blinkTime = nil
  button.logo:SetAlpha(1)
  ShowScanBar(false)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:SetScript("OnEvent", function(self)
  CreatePortrait()
  if button then
    self:UnregisterAllEvents()
  end
end)
