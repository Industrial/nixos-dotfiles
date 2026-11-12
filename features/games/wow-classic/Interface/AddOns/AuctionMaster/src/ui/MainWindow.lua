local addonName, AM = ...
local L = AM.L

-- The main window of the addon: a view of its own inside the auction house. It has a tab next to the tabs of the
-- game (Buy, Sell, Auctions) and, when that is clicked, covers the content of the auction house frame; a click on one
-- of the game's tabs, a search or closing the auction house hides it again. Nothing of the game's tab system is
-- replaced: the tab is a button of ours, the game's frame is only hooked after the fact and its tab state and title
-- are put back when our view goes away.
-- The views register themselves with MainWindow.RegisterTab, the first one is the default:
--   id       short name, saved as the view shown last
--   label    key of the text in the locale files, shown on the button that switches to it
--   create   function(parent) returning the panel of the view, called once when the window is built
--   refresh  function() redrawing the panel, called when the view is shown and when data changes
-- A view may place frames of its own beside the auction house (the recipe details do), as children of its panel.
-- The global object "mainWindow" holds all state of the window and its views (view shown last, the filters of
-- the recipes view), so that one reset clears it.
AM.MainWindow = {}
local MainWindow = AM.MainWindow
local Widgets = AM.Widgets

local UI = AM.Theme.ui

local BORDER_INSET = 7 -- border of the auction house frame
local SIDE_INSET = 4 -- how far our window reaches into it on the left and right, to cover its inner edge
local TITLE_HEIGHT = 23 -- its title bar
local FOOTER_HEIGHT = 32
local FOOTER_OVERHANG = 3 -- how far the footer strip reaches into the border of the auction house
local PORTRAIT_INSET = 36-- The auction house puts its own content at low frame levels above the frame, and its border far above (500).
-- Ours is between: above the frames of its own content and of the details beside it, which slide out from behind it,
-- and below its border.
local FRAME_LEVEL = 200
local TAB_LOGO = "Interface\\AddOns\\" .. addonName .. "\\assets\\logo"
local TAB_PADDING, TAB_MIN_WIDTH = 20, 70 -- of the game's tabs of the auction house
local TAB_GAP = 8-- between our tab and the game's, if their own gap cannot be measured
-- The auction house's own tab templates come first so that our tab looks like its neighbours (the generic panel
-- template looks wrong on Classic); the first one the client knows is used.
local TAB_TEMPLATES = { "AuctionHouseFrameDisplayModeTabTemplate", "AuctionHouseFrameTabTemplate",
  "PanelTabButtonTemplate", "CharacterFrameTabButtonTemplate" }

local views = {}
local frame, content, footerFrame, footerText, switchButton
local activeView
local tabButton
local savedTab, savedTitle -- what the auction house showed before our view, put back when it goes away

local function GetState()
  return AM.Database.GetGlobalObject("mainWindow")
end

function MainWindow.RegisterTab(view)
  views[#views + 1] = view
end

local function FindView(id)
  for _, view in ipairs(views) do
    if view.id == id then
      return view
    end
  end
  return nil
end

-- Space the first row of controls in the top left corner of a view leaves free for the portrait of the auction
-- house, which reaches into the content.
function MainWindow.PortraitInset()
  return PORTRAIT_INSET
end

-- The frame of the window (a child of the auction house frame), once built.
function MainWindow.GetFrame()
  return frame
end

function MainWindow.IsShown()
  return frame ~= nil and frame:IsVisible()
end

-- How long ago the scan was: "less than a minute ago", else in minutes (and hours, days), e.g. "2 min ago".
local function FormatAge(timestamp)
  local age = time() - timestamp
  if age < 60 then
    return L["MAIN_AGO_NOW"]
  end
  return L["MAIN_AGO"]:format(SecondsToTime(age, true))
end

local function CountStacks()
  local count = 0
  AM.ItemStore.ForEach(function(_, _, _, stacks)
    count = count + (stacks or 0)
  end)
  return count
end

local function UpdateFooter()
  local last = AM.Database.GetGlobalObject("scan").lastSuccess
  local text = Widgets.Color(UI.gold, L["MAIN_LAST_SCAN"]) .. " "
  if last then
    text = text .. Widgets.Color(UI.text, FormatAge(last)) .. " |cff835e33·|r " .. AM.FormatCount(CountStacks()) .. " " .. Widgets.Color(UI.text, L["MAIN_AUCTIONS"])
  else
    text = text .. Widgets.Color(UI.text, L["MAIN_NEVER"])
  end
  footerText:SetText(text)
end

function MainWindow.Refresh()
  if not frame or not frame:IsVisible() then
    return
  end
  UpdateFooter()
  if activeView.refresh then
    activeView.refresh()
  end
end

-- The button in the footer leads to the other view; with a single view there is nothing to switch to.
local function GetOtherView()
  if #views < 2 then
    return nil
  end
  return activeView == views[1] and views[2] or views[1]
end

local function UpdateSwitchButton()
  local other = GetOtherView()
  switchButton:SetShown(other ~= nil)
  if other then
    switchButton:SetLabel(L[other.label])
  end
end

function MainWindow.Select(id)
  local view = FindView(id) or views[1]
  activeView = view
  GetState().tab = view.id
  for _, other in ipairs(views) do
    other.panel:SetShown(other == view)
  end
  UpdateSwitchButton()
  MainWindow.Refresh()
end

-- The game's tabs of the auction house. Everything done to them is cosmetic and wrapped, so that a client with
-- other tabs only loses the selection look instead of raising an error.
-- Taken before our own tab exists: the tab templates add every tab to the Tabs of the frame, ours included.
local nativeTabs = {}

local function GetNativeTabs()
  return nativeTabs
end

local function IsNativeTabSelected()
  for _, tab in ipairs(GetNativeTabs()) do
    if not tab:IsEnabled() then
      return true
    end
  end
  return false
end

local function SetTabSelected(tab, selected)
  local select = selected and PanelTemplates_SelectTab or PanelTemplates_DeselectTab
  if select then
    pcall(select, tab)
  end
  -- a UI addon that restyles the tabs keeps the selection it shows on its own
  local skin = AM.Compat.GetSkin(AuctionHouseFrame)
  if skin then
    pcall(skin.SetTabSelection, tab, selected)
  end
end

-- The favorite star of the game's Auctions view sits in a higher strata than our window and would shine through it.
-- It is only made invisible and unclickable while our window is shown, nothing is written onto it.
local starAlpha, starMouse
local function GetStar()
  local auctions = AuctionHouseFrame.AuctionsFrame
  local display = auctions and auctions.ItemDisplay
  return display and display.FavoriteButton
end

local function HideStar()
  local star = GetStar()
  if star and not starAlpha then
    starAlpha, starMouse = star:GetAlpha(), star:IsMouseEnabled()
    star:SetAlpha(0)
    star:EnableMouse(false)
  end
end

local function ShowStar()
  local star = GetStar()
  if star and starAlpha then
    star:SetAlpha(starAlpha)
    star:EnableMouse(starMouse)
  end
  starAlpha, starMouse = nil, nil
end

-- Our view takes the place of the game's: its tab looks selected and the title says whose view it is.
local function TakeOver()
  HideStar()
  savedTab = nil
  for _, tab in ipairs(GetNativeTabs()) do
    if not tab:IsEnabled() then
      savedTab = tab
    end
    SetTabSelected(tab, false)
  end
  SetTabSelected(tabButton, true)
  local title = AuctionHouseFrame.TitleContainer and AuctionHouseFrame.TitleContainer.TitleText
  if title and AuctionHouseFrame.SetTitle then
    savedTitle = title:GetText()
    AuctionHouseFrame:SetTitle(addonName)
  end
end

-- The game selects its own tab when one is clicked (before our hook runs), and only if it was the selected one
-- itself, which does nothing there, does it need to be selected again, together with the title.
local function GiveBack()
  ShowStar()
  SetTabSelected(tabButton, false)
  if savedTab and not IsNativeTabSelected() then
    SetTabSelected(savedTab, true)
  end
  -- the game sets its own title when it switches the view
  local title = AuctionHouseFrame.TitleContainer and AuctionHouseFrame.TitleContainer.TitleText
  if savedTitle and title and title:GetText() == addonName and AuctionHouseFrame.SetTitle then
    AuctionHouseFrame:SetTitle(savedTitle)
  end
  savedTab, savedTitle = nil, nil
end

-- The strip of the game's own footer (gold display, buttons of its views) stays: our window ends above it and the
-- text and the switch button take the free space right of the gold display, over the buttons of the game's view
-- below. The measures are taken from the game's frame, with fallbacks.
local function MeasureNativeFooter(house)
  local height, left = FOOTER_HEIGHT, 175
  local money = house.MoneyFrameBorder
  if money and money:GetTop() and house:GetBottom() then
    height = money:GetTop() - house:GetBottom() + 2
  end
  if money and money:GetRight() and house:GetLeft() then
    left = money:GetRight() - house:GetLeft() - 4
  end
  return height, left
end

-- The highest frame level among the frames of the auction house, not counting the ones of the addon and, if a
-- limit is given, those at or above it.
local function HighestLevel(parent, limit)
  local highest = parent:GetFrameLevel()
  if limit and highest >= limit then
    highest = 0
  end
  for _, child in ipairs({ parent:GetChildren() }) do
    local name = child:GetName()
    if not (name and name:find("^" .. addonName)) then
      highest = math.max(highest, HighestLevel(child, limit))
    end
  end
  return highest
end

local function CreateFooter(house, left)
  -- A child of the auction house, not of our window, so that its level can be above everything of the game's
  -- views (their buttons, e.g. cancel auction, sit at the same height). It does not reach the border and the portrait
  -- of the game, which are above our window. It is shown and hidden with the window.
  local footer = CreateFrame("Frame", nil, house)
  -- the strata one above the auction house as well: the level alone did not cover the cancel button on retail
  local stratas = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
  for index, name in ipairs(stratas) do
    if name == house:GetFrameStrata() and stratas[index + 1] then
      footer:SetFrameStrata(stratas[index + 1])
      break
    end
  end
  footer:SetFrameLevel(HighestLevel(house) + 1)
  footer:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", left + BORDER_INSET - SIDE_INSET, 0)
  -- reaches further to the right and down than our window, to cover the edge of the game's buttons below
  -- as far right as the window above (SIDE_INSET): further in, the inner edge of the game's frame shows beside the strip
  footer:SetPoint("BOTTOMRIGHT", house, "BOTTOMRIGHT", -SIDE_INSET, FOOTER_OVERHANG + 1)
  footer:EnableMouse(true) -- a button of the game's view below is covered
  local background = footer:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints()
  background:SetColorTexture(UI.body[1], UI.body[2], UI.body[3])
  local rock
  if AM.Native.IsClassicSkin() then
    background:SetColorTexture(unpack(AM.Native.CLASSIC_BODY))
  else
    rock = AM.Native.AddFrameBackground(footer)
  end
  footer:Hide()
  footerFrame = footer
  -- A UI addon that restyles the game's windows gives the strip its flat color in place of ours and the rock. The
  -- color stays opaque, whatever the addon's panels are: the buttons of the game's view below must not shine through.
  AM.Compat.OnSkin(house, function(skin)
    local r, g, b = skin.GetPanelColor()
    background:SetColorTexture(r, g, b, 1)
    if rock then
      rock:Hide()
    end
  end)
  footerText = Widgets.CreateText(footer, "GameFontHighlightSmall")
  footerText:SetPoint("LEFT", 8, 0)
  -- the age counts up while the window is open
  local elapsed = 0
  footer:SetScript("OnUpdate", function(_, seconds)
    elapsed = elapsed + seconds
    if elapsed >= 5 then
      elapsed = 0
      UpdateFooter()
    end
  end)

  switchButton = Widgets.CreateButton(footer, "", false, function()
    MainWindow.Select(GetOtherView().id)
  end)
  switchButton:SetPoint("RIGHT", -8, 0)
end

local function CreateWindow()
  local house = AuctionHouseFrame
  local footerHeight, footerLeft = MeasureNativeFooter(house)
  -- no visible border: the game's frame has its own around the content
  frame = Widgets.CreateBox(house, UI.body, UI.body)
  frame:SetBackdropBorderColor(0, 0, 0, 0)
  frame:SetPoint("TOPLEFT", SIDE_INSET, -TITLE_HEIGHT)
  frame:SetPoint("BOTTOMRIGHT", -SIDE_INSET, footerHeight)
  -- Above the frames of the game's views, whose level differs per client (WoW Forever has sub tabs above the fixed
  -- level), but below its border and portrait (level 500 and up), which must stay on top. The frames inside get
  -- their level from this one, so it is set before they are created.
  frame:SetFrameLevel(math.min(HighestLevel(house, 500) + 1, 499))
  if frame:GetFrameLevel() < house:GetFrameLevel() + FRAME_LEVEL then
    frame:SetFrameLevel(house:GetFrameLevel() + FRAME_LEVEL)
  end
  frame:EnableMouse(true) -- the buttons of the auction house below must not be reachable
  if AM.Native.IsClassicSkin() then
    -- the rock does not belong to the auction house of these clients
    frame:SetBackdropColor(unpack(AM.Native.CLASSIC_BODY))
  else
    AM.Native.AddFrameBackground(frame) -- the same rock as the frame of the auction house has
  end
  frame:Hide()
  -- our logo on the portrait slot above the window
  local portrait = _G[addonName .. "Portrait"]
  if portrait and portrait:GetFrameLevel() <= frame:GetFrameLevel() + 100 then
    portrait:SetFrameLevel(math.min(frame:GetFrameLevel() + 100, 499))
  end

  CreateFooter(house, footerLeft)
  content = CreateFrame("Frame", nil, frame)
  content:SetPoint("TOPLEFT", 1, -1)
  content:SetPoint("BOTTOMRIGHT", -1, 1)
  for _, view in ipairs(views) do
    view.panel = view.create(content)
    view.panel:SetAllPoints(content)
    view.panel:Hide()
  end

  frame:SetScript("OnShow", function()
    footerFrame:Show()
    TakeOver()
    AM.Events.Fire("MAIN_WINDOW_VISIBILITY")
  end)
  frame:SetScript("OnHide", function()
    footerFrame:Hide()
    GiveBack()
    AM.Events.Fire("MAIN_WINDOW_VISIBILITY")
  end)
end

local function CreateTab()
  local house = AuctionHouseFrame
  for _, template in ipairs(TAB_TEMPLATES) do
    local ok, button = pcall(CreateFrame, "Button", addonName .. "Tab", house, template)
    if ok then
      tabButton = button
      break
    end
  end
  if not tabButton then
    -- a client without the tab templates gets a button of ours below the frame
    tabButton = Widgets.CreateButton(house, "", false)
  end
  -- named after the view it opens, like the tabs of the game, with our small logo in front to tell it apart; as
  -- a texture in the text it stays centered and counts for the width of the tab
  local label = "|T" .. TAB_LOGO .. ":14:14|t " .. L[views[1].label]
  tabButton:SetText(label)
  if tabButton.SetLabel then
    tabButton:SetLabel(label)
  elseif PanelTemplates_TabResize then
    -- the game's tabs size themselves in OnShow with this padding and minimum (AuctionHouseFrameTabMixin), which
    -- ran before the text was set
    pcall(PanelTemplates_TabResize, tabButton, TAB_PADDING, nil, TAB_MIN_WIDTH)
  end
  local tabs = GetNativeTabs()
  local last = tabs[#tabs]
  if last then
    -- the same gap as between the tabs of the game
    local gap = TAB_GAP
    local before = tabs[#tabs - 1]
    if before and before:GetRight() and last:GetLeft() then
      gap = last:GetLeft() - before:GetRight()
    end
    -- by the top edge, so the text keeps the same distance to the frame whatever the heights
    tabButton:SetPoint("TOPLEFT", last, "TOPRIGHT", gap, 0)
    -- same height as the game's tabs, whatever template was found
    if last.GetHeight and last:GetHeight() > 0 and math.abs(tabButton:GetHeight() - last:GetHeight()) > 1 then
      tabButton:SetHeight(last:GetHeight())
    end
  else
    tabButton:SetPoint("TOPLEFT", house, "BOTTOMLEFT", 20, 2)
  end
  tabButton:SetScript("OnClick", function()
    MainWindow.Show()
  end)
  SetTabSelected(tabButton, false)
  -- a UI addon that restyles the tabs of the game restyles ours the same way
  AM.Compat.OnSkin(house, function(skin)
    skin.Tab(tabButton)
    local height = last and last:GetHeight() or 0
    if height > 0 then
      tabButton:SetHeight(height)
    end
    skin.SetTabSelection(tabButton, not tabButton:IsEnabled())
  end)
end

-- The auction house is load on demand: our tab is added the first time it opens.
local function Install()
  if tabButton or not AuctionHouseFrame then
    return
  end
  for _, tab in ipairs(AuctionHouseFrame.Tabs or {}) do
    nativeTabs[#nativeTabs + 1] = tab
  end
  CreateTab()
  -- the cogwheel of the options, next to the close button of the auction house
  if AM.Options then
    AM.Options.CreateButton(AuctionHouseFrame)
  end
  -- after the game's own handling: a tab of the game, a search or closing hides our view
  for _, tab in ipairs(GetNativeTabs()) do
    tab:HookScript("OnClick", MainWindow.Hide)
  end
  if AuctionHouseFrame.SetDisplayMode then
    hooksecurefunc(AuctionHouseFrame, "SetDisplayMode", MainWindow.Hide)
  end
  AuctionHouseFrame:HookScript("OnHide", MainWindow.Hide)
end

local function IsAuctionHouseOpen()
  return AuctionHouseFrame ~= nil and AuctionHouseFrame:IsShown()
end

-- Shows the window on the view, the one shown last if there is none given.
function MainWindow.Show(id)
  if not IsAuctionHouseOpen() then
    AM.Print(L["MAIN_OPEN_AUCTION_HOUSE"])
    return
  end
  Install()
  if not frame then
    CreateWindow()
  end
  frame:Show()
  MainWindow.Select(id or GetState().tab)
end

function MainWindow.Hide()
  if frame and frame:IsShown() then
    frame:Hide()
  end
end

-- Hides the window if it shows the view already (any view if none is given), else shows it.
function MainWindow.Toggle(id)
  if MainWindow.IsShown() and (not id or activeView.id == id) then
    MainWindow.Hide()
  else
    MainWindow.Show(id)
  end
end

local events = CreateFrame("Frame")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:SetScript("OnEvent", Install)
