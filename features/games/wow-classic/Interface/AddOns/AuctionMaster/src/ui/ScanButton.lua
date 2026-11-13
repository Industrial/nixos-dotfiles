local addonName, AM = ...
local L = AM.L

-- The one button of the full scan, at the same place on every tab of the auction house (Buy, Sell, Auctions and our
-- own window): right of the gold display at the bottom. Beside it the progress while a scan runs ("45%"), else how
-- long ago the last scan was. A message (a call without an answer) takes the place of the age only for MESSAGE_SECONDS. Greyed out while a scan runs and until the server allows the next one (the tooltip says
-- when).
-- Our window covers the strip right of the gold display with its footer: while it is shown, the button is moved onto
-- that footer, else it would be hidden below it.
AM.ScanButton = {}
local ScanButton = AM.ScanButton
local Widgets = AM.Widgets

local UI = AM.Theme.ui

local GAP = 6 -- from the gold display: 2 past the edge of the frame around it (4), as tight as the game packs its footer
local STATUS_GAP = 6
local STATUS_WIDTH = 130 -- fixed, so what stands right of it does not move with the text
local BUTTON_PADDING = 12
local LEVEL_ABOVE = 100 -- above the frames of the game's views, below its border (500)
local MESSAGE_SECONDS = 5

local holder, button, status
local message, messageUntil -- a short message shown instead of the age, until GetTime() reaches messageUntil
local timedOut = false -- the state of the last update, to show "No answer" once when it happens

local function LastSuccess()
  return AM.Scan.GetLastSuccess()
end

-- "Last scan: just now", else the age in its largest unit: "Last scan: 12 Min ago", "Last scan: 3 Hr ago".
local function FormatAge(timestamp)
  local age = time() - timestamp
  if age < 60 then
    return L["SCAN_BUTTON_NOW"]
  end
  return L["SCAN_BUTTON_AGO"]:format(SecondsToTime(age, true, false, 1))
end

local function CanStart()
  return not AM.Scan.IsRunning() and AM.Scan.GetWaitSeconds() <= 0
end

local function UpdateTooltip()
  GameTooltip:SetOwner(button, "ANCHOR_TOP")
  GameTooltip:SetText(L["SCAN_BUTTON"], 1, 1, 1)
  GameTooltip:AddLine(L["SCAN_BUTTON_TOOLTIP"], nil, nil, nil, true)
  if AM.Scan.HasTimedOut() then
    GameTooltip:AddLine(L["SCAN_BUTTON_NO_ANSWER_TOOLTIP"], 1, 0.33, 0.33, true)
  end
  local wait = AM.Scan.GetWaitSeconds()
  if not AM.Scan.IsRunning() and wait > 0 then
    GameTooltip:AddLine(L["SCAN_BUTTON_NEXT"]:format(date("%H:%M", time() + wait)), 1, 1, 1, true)
  end
  GameTooltip:Show()
end

-- Shows the (colored) text beside the button for a few seconds instead of the age.
local function ShowMessage(text)
  message, messageUntil = text, GetTime() + MESSAGE_SECONDS
end

function ScanButton.Update()
  if not holder then
    return
  end
  local nowTimedOut = AM.Scan.HasTimedOut()
  if nowTimedOut and not timedOut then
    ShowMessage(Widgets.Color(UI.loss, L["SCAN_BUTTON_NO_ANSWER"]))
  end
  timedOut = nowTimedOut
  local percent = AM.Scan.GetPercent()
  local last = LastSuccess()
  if message and GetTime() >= messageUntil then
    message = nil
  end
  if percent then
    status:SetText(Widgets.Color(UI.gold, ("%d%%"):format(percent)))
  elseif message then
    status:SetText(message)
  elseif last then
    status:SetText(Widgets.Color(UI.text, FormatAge(last)))
  else
    status:SetText(Widgets.Color(UI.muted, L["SCAN_BUTTON_NEVER"]))
  end
  button:SetEnabled(CanStart())
  if GameTooltip:GetOwner() == button and GameTooltip:IsShown() then
    UpdateTooltip()
  end
end

-- The frame holding the button and the text beside it, for what is placed right of it (the strip of the Auctions view).
function ScanButton.GetFrame()
  return holder
end

-- On the auction house, or on the footer of our window while that is shown (see the top of the file).
local function Place()
  local footer = AM.MainWindow.IsShown() and AM.MainWindow.GetFooter()
  local parent = footer or AuctionHouseFrame
  if holder:GetParent() ~= parent then
    holder:SetParent(parent)
  end
  holder:SetFrameStrata(parent:GetFrameStrata())
  if footer then
    -- above the footer whatever its level: it is taken above everything of the auction house, often 500 and more,
    -- and a cap below 500 would put the button under the footer's background
    holder:SetFrameLevel(footer:GetFrameLevel() + 10)
  else
    holder:SetFrameLevel(math.min(parent:GetFrameLevel() + LEVEL_ABOVE, 499))
  end
end

local function Create()
  local house = AuctionHouseFrame
  holder = CreateFrame("Frame", nil, house)
  local money = house.MoneyFrameBorder
  if money then
    holder:SetPoint("LEFT", money, "RIGHT", GAP, 0)
  else
    holder:SetPoint("BOTTOMLEFT", house, "BOTTOMLEFT", 190, 4)
  end
  holder:SetHeight(22)

  button = Widgets.CreateButton(holder, L["SCAN_BUTTON"], false, function()
    AM.Scan.Start(true)
  end)
  button:SetLabel(L["SCAN_BUTTON"], BUTTON_PADDING)
  button:SetPoint("LEFT")
  button:SetMotionScriptsWhileDisabled(true) -- else a greyed out button shows no tooltip
  button:SetScript("OnEnter", UpdateTooltip)
  button:SetScript("OnLeave", GameTooltip_Hide)

  status = Widgets.CreateText(holder, "GameFontHighlightSmall")
  status:SetPoint("LEFT", button, "RIGHT", STATUS_GAP, 0)
  status:SetWidth(STATUS_WIDTH)
  status:SetWordWrap(false)
  holder:SetWidth(button:GetWidth() + STATUS_GAP + STATUS_WIDTH)

  -- the percentage follows the reading, the age and the countdown follow the clock
  local elapsed = 0
  holder:SetScript("OnUpdate", function(_, seconds)
    elapsed = elapsed + seconds
    if elapsed >= (AM.Scan.IsRunning() and 0.2 or 1) then
      elapsed = 0
      ScanButton.Update()
    end
  end)
  Place()
end

-- The auction house is load on demand: the button is added the first time it opens.
local events = CreateFrame("Frame")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:SetScript("OnEvent", function()
  if not holder and AuctionHouseFrame then
    Create()
  end
  ScanButton.Update()
end)

AM.Events.Register("SCAN_CHANGED", ScanButton.Update)
AM.Events.Register("MAIN_WINDOW_VISIBILITY", function()
  if holder then
    Place()
  end
end)
