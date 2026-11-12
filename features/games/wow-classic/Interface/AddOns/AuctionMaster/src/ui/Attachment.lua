local _, AM = ...

-- A panel beside the auction house, on its right, or on its left where the screen has no room: the game's frame
-- (like the auction house itself) that slides out from behind it. The details of the Recipes view, the shopping list
-- of the Buy tab and the recipes to craft beside a profession window are such panels. Everything a panel puts in is a child of attachment.body.
--   local attachment = AM.Attachment.Create(title, contentWidth, onClose, host, onOpen, scrollStrip)
--   scrollStrip              the look of the browse view: no dark box around the content, header and footer on the leather,
--                            lists made with Attachment.CreateList (sunken, scroll bar beside it in the leather)
--   host                     the frame it comes out from behind, the auction house if omitted
--   onOpen                   called when the handle is clicked; the owner opens the panel again
--   attachment.SetHandle(b)  shows a button in the title bar of the host (left of the cogwheel) while the panel is closed, to open it again
--   attachment.body          frame to build the content in (inside the inset of the panel)
--   attachment.SetShown(b)   slides it in or out; calls come often, only a change of the state does anything
--   attachment.Sync()        shows it at once in the state wanted (the owner was shown again), without sliding
--   attachment.Hide()        hides it at once, the state wanted stays (the owner was hidden)
AM.Attachment = {}
local Attachment = AM.Attachment
local Widgets = AM.Widgets

local PADDING = 4 -- leather between the border of the frame and the content
local FRAME_BORDER = 7 -- border of the game's frame
local SLIDE_TIME = 0.2
local ARROW_RIGHT = "common-icon-forwardarrow"
local ARROW_LEFT = "common-icon-backarrow"
local OFFSET = -6 -- overlap with the auction house
local SIDE = 8 -- leather left of a list
local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }

-- A list as in the auction house, for the body of an attachment made with scrollStrip: a sunken panel from `top` to
-- `bottom` (distances from the body's edges) with the game's scroll bar beside it, in the leather. Returns the list and
-- the panel (to put an empty text on).
function Attachment.CreateList(body, top, bottom, createRow, setupRow)
  local inset = AM.Native.PANEL_INSET
  local panel = AM.Native.CreateInset(body, true)
  panel:SetPoint("TOPLEFT", SIDE, -top)
  panel:SetPoint("BOTTOMRIGHT", -(AM.Native.ScrollGutter() + 2), bottom)
  local list = Widgets.CreateList(panel, createRow, setupRow, inset + 6)
  list:SetPoint("TOPLEFT", inset, -inset)
  list:SetPoint("BOTTOMRIGHT", -inset, inset)
  return list, panel
end

function Attachment.Create(title, contentWidth, onClose, host, onOpen, scrollStrip)
  local house = host or AuctionHouseFrame
  local strip = scrollStrip and 8 or 0 -- the room the strip for the scroll bar takes from the list, see CreateList
  -- It belongs to the host so that it stays below our window in the frame stack and comes out from behind it.
  local frame, inner = Widgets.CreatePortraitFrame(title, function() end, true, house)
  frame:SetMovable(false)
  frame:SetClampedToScreen(false)
  -- One strata below the auction house: as a child it would otherwise draw its title above the title bar of the
  -- auction house while sliding out, instead of staying fully behind it.
  for index, name in ipairs(STRATA) do
    if name == house:GetFrameStrata() and index > 1 then
      frame:SetFrameStrata(STRATA[index - 1])
      break
    end
  end
  frame:SetWidth(contentWidth + 2 * (PADDING + FRAME_BORDER) + strip)
  frame:Hide()
  if not host then
    AM.Portrait.AddPanel(frame) -- the light of the scan passes over its title bar too
  end
  if frame.CloseButton then
    frame.CloseButton:SetScript("OnClick", onClose)
  end
  -- a UI addon that restyles the game's windows restyles the panel like the host
  AM.Compat.OnSkin(house, function(skin)
    skin.Shell(frame)
    if frame.CloseButton then
      skin.CloseButton(frame.CloseButton)
    end
  end)

  local body
  if scrollStrip then
    -- Like the browse view of the auction house: header and footer sit on the leather, only the list is sunken.
    body = CreateFrame("Frame", nil, inner)
    body:SetAllPoints()
  else
    local aside = AM.Native.CreateInset(inner, true)
    aside:SetPoint("TOPLEFT", PADDING, -PADDING)
    aside:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)
    body = CreateFrame("Frame", nil, aside)
    body:SetPoint("TOPLEFT", AM.Native.PANEL_INSET, -AM.Native.PANEL_INSET)
    body:SetPoint("BOTTOMRIGHT", -AM.Native.PANEL_INSET, AM.Native.PANEL_INSET)
  end

  local attachment = { frame = frame, body = body }
  local slide = 0 -- 0 hidden behind the window, 1 out
  local wanted = false
  local handleWanted = false

  -- The handle is a button in the title bar of the host, left of the cogwheel, with an arrow towards the side the panel
  -- comes out. Like the cogwheel it is the red art of the close button.
  local handle = AM.Native.CreateTitleButton(house)
  handle:Hide()
  handle:SetScript("OnClick", function()
    if onOpen then
      onOpen()
    end
  end)
  Widgets.SetTooltip(handle, title)

  local function PlaceHandle(onRight)
    handle.icon:SetAtlas(onRight and ARROW_RIGHT or ARROW_LEFT)
    handle:ClearAllPoints()
    local cogwheel = house.AuctionMasterOptionsButton
    if cogwheel then
      handle:SetPoint("RIGHT", cogwheel, "LEFT", 0, 0)
    elseif house.CloseButton then
      handle:SetPoint("RIGHT", house.CloseButton, "LEFT", AM.Native.TitleButtonNudge(), 0)
    else
      handle:SetPoint("TOPRIGHT", -26, -4)
    end
  end

  local function UpdateHandle()
    handle:SetShown(handleWanted and not wanted and not frame:IsShown())
  end

  local function Place()
    if not house:GetRight() then
      return -- not laid out yet
    end
    local room = (UIParent:GetRight() * UIParent:GetEffectiveScale() - house:GetRight() * house:GetEffectiveScale())
      / house:GetEffectiveScale()
    -- slows down towards the end
    local hidden = (1 - slide) ^ 2 * frame:GetWidth()
    frame:ClearAllPoints()
    PlaceHandle(room >= frame:GetWidth())
    if room >= frame:GetWidth() then
      frame:SetPoint("TOPLEFT", house, "TOPRIGHT", OFFSET - hidden, 0)
      frame:SetPoint("BOTTOMLEFT", house, "BOTTOMRIGHT", OFFSET - hidden, 0)
    else
      frame:SetPoint("TOPRIGHT", house, "TOPLEFT", -OFFSET + hidden, 0)
      frame:SetPoint("BOTTOMRIGHT", house, "BOTTOMLEFT", -OFFSET + hidden, 0)
    end
  end
  attachment.Place = Place

  -- Moves the slide towards the state wanted, a frame at a time.
  local function OnSlide(_, elapsed)
    local target = wanted and 1 or 0
    local step = elapsed / SLIDE_TIME
    slide = target > slide and math.min(slide + step, 1) or math.max(slide - step, 0)
    Place()
    if slide == target then
      frame:SetScript("OnUpdate", nil)
      frame:SetShown(target == 1)
      UpdateHandle()
    end
  end

  function attachment.SetShown(shown)
    if shown == wanted then
      return
    end
    wanted = shown
    UpdateHandle()
    if not shown and not frame:IsShown() then
      return
    end
    Place()
    frame:Show()
    frame:SetScript("OnUpdate", OnSlide)
  end

  function attachment.Sync()
    frame:SetScript("OnUpdate", nil)
    slide = wanted and 1 or 0
    frame:SetShown(wanted)
    if wanted then
      Place()
    end
    UpdateHandle()
  end

  function attachment.SetHandle(shown)
    handleWanted = shown
    if shown then
      Place()
    end
    UpdateHandle()
  end

  function attachment.Hide()
    frame:SetScript("OnUpdate", nil)
    frame:Hide()
    handle:Hide()
  end

  -- Changes the title, for a panel with several tabs.
  function attachment.SetTitle(text)
    if frame.SetTitle then
      frame:SetTitle(text)
    elseif frame.TitleText then
      frame.TitleText:SetText(text)
    end
  end

  function attachment.IsWanted()
    return wanted
  end

  return attachment
end
