local addonName, AM = ...
local L = AM.L

-- The main window of the addon: views of its own inside the auction house. Each view has a tab next to the tabs of
-- the game (Buy, Sell, Auctions) and, when that is clicked, the window covers the content of the auction house frame;
-- a click on one of the game's tabs, a search or closing the auction house hides it again. Nothing of the game's tab
-- system is replaced: the tabs are buttons of ours, the game's frame is only hooked after the fact and its tab state
-- and title are put back when our view goes away.
-- The views register themselves with MainWindow.RegisterTab, in the order of their tabs; the first one is the default:
--   id       short name, saved as the view shown last
--   label    key of the text in the locale files, shown on its tab
--   create   function(parent) returning the panel of the view, called once when the window is built
--   refresh  function() redrawing the panel, called when the view is shown and when data changes
--   setting  optional: key of a boolean setting (AM.Settings) whether its tab is shown, changed with
--            MainWindow.SetTabShown; a hidden view cannot be selected
-- A view may place frames of its own beside the auction house (the recipe details do), as children of its panel.
-- The global object "mainWindow" holds all state of the window and its views (view shown last, the filters of
-- the recipes view), so that one reset clears it.
AM.MainWindow = {}
local MainWindow = AM.MainWindow
local Widgets = AM.Widgets

local UI = AM.Theme.ui

local CORNER_WIDTH = 10 -- how far the game's corner piece at the top right of the gold display reaches beyond it
local SIDE_INSET = 4 -- how far our window reaches into it on the left and right, to cover its inner edge
local TITLE_HEIGHT = 23 -- its title bar
local FOOTER_HEIGHT = 32
local FOOTER_OVERHANG = 3 -- how far the footer strip reaches into the border of the auction house
local PORTRAIT_INSET = 36-- The auction house puts its own content at low frame levels above the frame, and its border far above (500).
-- Ours is between: above the frames of its own content and of the details beside it, which slide out from behind it,
-- and below its border.
local FRAME_LEVEL = 200
local TAB_PADDING, TAB_MIN_WIDTH = 20, 70 -- of the game's tabs of the auction house
local TAB_GAP = 8 -- between our tabs and the game's, if their own gap cannot be measured
-- The auction house's own tab templates come first so that our tabs look like their neighbours (the generic panel
-- template looks wrong on Classic); the first one the client knows is used.
local TAB_TEMPLATES = { "AuctionHouseFrameDisplayModeTabTemplate", "AuctionHouseFrameTabTemplate",
  "PanelTabButtonTemplate", "CharacterFrameTabButtonTemplate" }

local views = {}
local frame, content, footerFrame
local activeView
local installed
local tabButtons = {} -- view -> its tab
local savedTab, savedTitle -- what the auction house showed before our view, put back when it goes away

local function GetState()
  return AM.Database.GetGlobalObject("mainWindow")
end

function MainWindow.RegisterTab(view)
  views[#views + 1] = view
end

local function IsViewShown(view)
  return not view.setting or AM.Settings.Get(view.setting)
end

local function FindView(id)
  for _, view in ipairs(views) do
    if view.id == id then
      return view
    end
  end
  return nil
end

local function FirstShownView()
  for _, view in ipairs(views) do
    if IsViewShown(view) then
      return view
    end
  end
  return views[1]
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

-- The strip at the bottom of the window, right of the gold display, once built. The scan button (AM.ScanButton) moves
-- onto it while the window is shown.
function MainWindow.GetFooter()
  return footerFrame
end

function MainWindow.Refresh()
  if not frame or not frame:IsVisible() then
    return
  end
  if activeView.refresh then
    activeView.refresh()
  end
end

local SetTabSelected

-- The tab of the view shown looks selected, the others not; none while the window is hidden. shown is passed in:
-- when the auction house closes, our window's OnHide runs while its own IsShown is still true.
local function UpdateTabs(shown)
  for view, button in pairs(tabButtons) do
    SetTabSelected(button, shown and view == activeView)
  end
end

function MainWindow.Select(id)
  local view = FindView(id)
  if not view or not IsViewShown(view) then
    view = FirstShownView()
  end
  activeView = view
  GetState().tab = view.id
  for _, other in ipairs(views) do
    other.panel:SetShown(other == view)
  end
  UpdateTabs(frame ~= nil and frame:IsVisible())
  MainWindow.Refresh()
end

-- The game's tabs of the auction house. Everything done to them is cosmetic and wrapped, so that a client with
-- other tabs only loses the selection look instead of raising an error.
-- Taken before our own tabs exist: the tab templates add every tab to the Tabs of the frame, ours included.
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

function SetTabSelected(tab, selected)
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

-- The frames of the game's views, below our window. Their parts in the strip of the footer (e.g. the cancel button
-- of the Auctions view) would show beside the gold display, so they are made invisible while our window is shown:
-- only their alpha is changed, and given back as it was.
local VIEW_KEYS = { "SearchBar", "CategoriesList", "BrowseResultsFrame", "WoWTokenResults", "CommoditiesBuyFrame",
  "ItemBuyFrame", "ItemSellFrame", "ItemSellList", "CommoditiesSellFrame", "CommoditiesSellList", "WoWTokenSellFrame",
  "AuctionsFrame" }
local viewAlphas -- frame -> its alpha before, while hidden

local function HideViews()
  if viewAlphas then
    return
  end
  viewAlphas = {}
  for _, key in ipairs(VIEW_KEYS) do
    local view = AuctionHouseFrame[key]
    if type(view) == "table" and view.SetAlpha then
      viewAlphas[view] = view:GetAlpha()
      view:SetAlpha(0)
    end
  end
end

local function ShowViews()
  for view, alpha in pairs(viewAlphas or {}) do
    view:SetAlpha(alpha)
  end
  viewAlphas = nil
end

-- Our view takes the place of the game's: the game's tabs look deselected, ours follow the view shown, and the title
-- says whose view it is.
local function TakeOver()
  HideStar()
  HideViews()
  savedTab = nil
  for _, tab in ipairs(GetNativeTabs()) do
    if not tab:IsEnabled() then
      savedTab = tab
    end
    SetTabSelected(tab, false)
  end
  UpdateTabs(true)
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
  ShowViews()
  UpdateTabs(false)
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
-- scan button takes the free space right of the gold display, over the buttons of the game's
-- view below. The measures are taken from the game's frame, with fallbacks.
local function MeasureNativeFooter(house)
  local height, left = FOOTER_HEIGHT, 189
  local money = house.MoneyFrameBorder
  if money and money:GetTop() and house:GetBottom() then
    height = money:GetTop() - house:GetBottom() + 2
  end
  -- the strip starts right of the frame around the gold display and its corner piece, which stay visible
  if money and money:GetRight() and house:GetLeft() then
    left = money:GetRight() - house:GetLeft() + CORNER_WIDTH
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
  footer:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", left - SIDE_INSET, 0)
  -- reaches further to the right and down than our window, to cover the edge of the game's buttons below
  -- as far right as the window above (SIDE_INSET): further in, the inner edge of the game's frame shows beside the strip
  footer:SetPoint("BOTTOMRIGHT", house, "BOTTOMRIGHT", -SIDE_INSET, FOOTER_OVERHANG + 1)
  -- No background: the game's own footer with its frames shows through. The game's view below is made invisible
  -- while our window is shown (HideViews), the strip only keeps its buttons there from being clicked.
  footer:EnableMouse(true)
  footer:Hide()
  footerFrame = footer
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

-- The tab of a view (index: its place among ours), placed by LayoutTabs.
local function CreateTab(view, index)
  local house = AuctionHouseFrame
  local button
  for _, template in ipairs(TAB_TEMPLATES) do
    local ok, created = pcall(CreateFrame, "Button", addonName .. "Tab" .. index, house, template)
    if ok then
      button = created
      break
    end
  end
  if not button then
    -- a client without the tab templates gets a button of ours below the frame
    button = Widgets.CreateButton(house, "", false)
  end
  local label = L[view.label]
  button:SetText(label)
  if button.SetLabel then
    button:SetLabel(label)
  elseif PanelTemplates_TabResize then
    -- the game's tabs size themselves in OnShow with this padding and minimum (AuctionHouseFrameTabMixin), which
    -- ran before the text was set
    pcall(PanelTemplates_TabResize, button, TAB_PADDING, nil, TAB_MIN_WIDTH)
  end
  -- same height as the game's tabs, whatever template was found
  local native = GetNativeTabs()[1]
  local function NativeHeight()
    return native and native.GetHeight and native:GetHeight() or 0
  end
  if NativeHeight() > 0 and math.abs(button:GetHeight() - NativeHeight()) > 1 then
    button:SetHeight(NativeHeight())
  end
  button:SetScript("OnClick", function()
    MainWindow.Show(view.id)
  end)
  SetTabSelected(button, false)
  -- a UI addon that restyles the tabs of the game restyles ours the same way
  AM.Compat.OnSkin(house, function(skin)
    skin.Tab(button)
    if NativeHeight() > 0 then
      button:SetHeight(NativeHeight())
    end
    skin.SetTabSelection(button, not button:IsEnabled())
  end)
  tabButtons[view] = button
  return button
end

local tabGap = TAB_GAP

-- The tabs of the views shown in the order the views registered, after the game's; the others are hidden.
local function LayoutTabs()
  local last = GetNativeTabs()[#GetNativeTabs()]
  for _, view in ipairs(views) do
    local button = tabButtons[view]
    local shown = IsViewShown(view)
    button:SetShown(shown)
    if shown then
      button:ClearAllPoints()
      if last then
        -- by the top edge, so the text keeps the same distance to the frame whatever the heights
        button:SetPoint("TOPLEFT", last, "TOPRIGHT", tabGap, 0)
      else
        -- without the game's tabs, the first one goes below the frame
        button:SetPoint("TOPLEFT", AuctionHouseFrame, "BOTTOMLEFT", 20, 2)
      end
      last = button
    end
  end
end

-- Our tabs, with the same gap as between the game's tabs.
local function CreateTabs()
  local tabs = GetNativeTabs()
  local before, last = tabs[#tabs - 1], tabs[#tabs]
  if before and last and before:GetRight() and last:GetLeft() then
    tabGap = last:GetLeft() - before:GetRight()
  end
  for index, view in ipairs(views) do
    CreateTab(view, index)
  end
  LayoutTabs()
end

function MainWindow.IsTabShown(id)
  local view = FindView(id)
  return view ~= nil and IsViewShown(view)
end

-- Shows or hides the tab of a view with a setting; a view hidden while shown gives way to the first one shown.
function MainWindow.SetTabShown(id, shown)
  local view = FindView(id)
  if not view or not view.setting then
    return
  end
  AM.Settings.Set(view.setting, shown)
  if installed then
    LayoutTabs()
  end
  if frame and activeView == view and not IsViewShown(view) then
    MainWindow.Select(FirstShownView().id)
  end
end

-- The auction house is load on demand: our tab is added the first time it opens.
local function Install()
  if installed or not AuctionHouseFrame then
    return
  end
  installed = true
  for _, tab in ipairs(AuctionHouseFrame.Tabs or {}) do
    nativeTabs[#nativeTabs + 1] = tab
  end
  CreateTabs()
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
    AM.Print(L["MAIN_OPEN_AUCTION_HOUSE"], "quiet")
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
