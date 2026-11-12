local addonName, AM = ...

-- WoW Forever has interface versions 16xxx. A game type gate in the .toc did not work here,
-- retail loaded the file gated for camelot as well.
local isForever = select(4, GetBuildInfo()) >= 16000 and select(4, GetBuildInfo()) < 17000

-- Classic has darker title bars than retail.
local TITLE_LIGHTEN = AM.Client.IsClassic() and 0.03 or 0.09

local function Hex(value)
  return { bit.rshift(value, 16) / 255, bit.band(bit.rshift(value, 8), 255) / 255, bit.band(value, 255) / 255 }
end

-- Everything that makes the addon windows look like the auction house of the game type. The
-- defaults match retail, the values for Forever are the ones the addon started with. Files
-- read their looks from here instead of checking the game type themselves. A surface is
-- { color } or, with a gradient, { top, bottom }; Theme.Fill paints it.
AM.Theme = {
  titleBar = isForever and { 0.125, 0.07, 0.04 } or { 0.17, 0.165, 0.16 },
  titleFont = "GameFontNormal",
  -- Vertical offset of the small logo (and with it the title) in the title bar of our frames, from the middle of
  -- the game's title container: its title bar sits differently in each client.
  titleLogoOffset = isForever and -0.5 or -1,
  titleLogoInset = isForever and 12 or 8, -- and its distance from the left edge of the title bar
  -- Lines below the title bar from top to bottom, together 2 pixels high.
  titleDivider = isForever
    and { { height = 2, color = { 0.98, 0.45, 0 } } }
    or { { height = 1, color = { 0.05, 0.05, 0.05 } }, { height = 1, color = { 0.38, 0.37, 0.35 } } },
  window = isForever and { 0.2, 0.176, 0.16 } or Hex(0x34302c),
  border = isForever and { 0.51, 0.37, 0.2 } or Hex(0x65625c),
  -- The sunken panel holding the lists.
  panel = isForever and { color = { 0.1, 0.086, 0.07 } } or { top = Hex(0x0d0c0b), bottom = Hex(0x1a1714) },
  sectionHeader = isForever and { color = { 0.13, 0.07, 0.03 } } or { top = Hex(0x312c29), bottom = Hex(0x221d19) },
  -- Light line on top of a section header.
  sectionEdge = not isForever and Hex(0x544845) or nil,
  selected = isForever and { 0.29, 0.14, 0.05 } or { 0.24, 0.22, 0.2 },
  -- Backgrounds of the item rows, plain and striped (r, g, b, alpha).
  itemRow = isForever and { 0.09, 0.09, 0.09, 1 } or { 1, 1, 1, 0 },
  itemRowStripe = isForever and { 0.12, 0.12, 0.12, 1 } or { 1, 1, 1, 0.04 },
  progressFill = isForever and { 0.98, 0.6, 0 } or { 0.82, 0.42, 0.06 },
  progressTrack = isForever and { 0.04, 0.04, 0.04 } or Hex(0x0d0c0b),
  itemBarHeight = isForever and 6 or 4,
  -- Collected items: Forever crosses the name out in its quality color and keeps the bar,
  -- retail mutes the row and shows a check instead of the bar.
  mutedCollected = not isForever,
  quantityFont = isForever and "GameFontNormalSmall" or "GameFontHighlightSmall",
  -- Retail has the grey button of the auction house ("Filter").
  button = isForever and "UIPanelButtonTemplate" or "UIMenuButtonStretchTemplate",
}

-- Colors of the main window and its tabs (see AM.MainWindow), the same on every client: the brown
-- frame with gold text and the ember accent. Text colors are also given as |cff hex for strings.
AM.Theme.ui = {
  border = Hex(0x835e33),
  body = Hex(0x332d29),
  sunken = Hex(0x1a1612),
  black = { 0, 0, 0 },
  rowEven = Hex(0x171717),
  rowOdd = Hex(0x1f1f1f),
  selected = Hex(0x4b230e),
  header = Hex(0x211107),
  sectionHeader = Hex(0x2b2b2b),
  input = Hex(0x161311),
  button = Hex(0x1c1c1c),
  buttonBorder = Hex(0x5d4d3f),
  red = { Hex(0x5a0000), Hex(0x6b0408) },
  emberStart = Hex(0xf85200),
  emberEnd = Hex(0xfeb800),
  gold = "ffd200",
  text = "e2dcd6",
  muted = "a0a0a0",
  loss = "ff5555",
  warn = "ff8000",
  gain = "1aff1a",
  crafter = "9596f2",
}

local function SetGradient(texture, top, bottom)
  if texture.SetGradientAlpha then
    texture:SetGradientAlpha("VERTICAL", bottom[1], bottom[2], bottom[3], 1, top[1], top[2], top[3], 1)
  else
    texture:SetGradient("VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], 1),
      CreateColor(top[1], top[2], top[3], 1))
  end
end

-- Paints a texture with a surface of the theme.
function AM.Theme.Fill(texture, surface)
  if surface.color then
    texture:SetColorTexture(unpack(surface.color))
  else
    texture:SetColorTexture(1, 1, 1, 1)
    SetGradient(texture, surface.top, surface.bottom)
  end
end

-- Creates a button of the theme's button template, the plain one if the client lacks it.
function AM.Theme.CreateButton(parent)
  local ok, button = pcall(CreateFrame, "Button", nil, parent, AM.Theme.button)
  return ok and button or CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
end

-- Fills the background of a title bar: the stone look of the Blizzard title bars on retail,
-- the plain titleBar color on Forever.
function AM.Theme.ApplyTitleBar(texture)
  if isForever then
    texture:SetColorTexture(unpack(AM.Theme.titleBar))
    return
  end
  if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("_UI-Frame-TitleTileBg") then
    texture:SetAtlas("_UI-Frame-TitleTileBg")
    texture:SetHorizTile(true)
  else
    texture:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", "REPEAT", "REPEAT")
    texture:SetHorizTile(true)
    texture:SetVertTile(true)
  end
  -- The textures come out darker than the Blizzard title bars, so a faint additive layer
  -- lightens them.
  local layer, sublevel = texture:GetDrawLayer()
  local lighten = texture:GetParent():CreateTexture(nil, layer, nil, math.min((sublevel or 0) + 1, 7))
  lighten:SetAllPoints(texture)
  lighten:SetColorTexture(1, 1, 1, TITLE_LIGHTEN)
  lighten:SetBlendMode("ADD")
end
