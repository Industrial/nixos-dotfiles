local addonName, AM = ...
local L = AM.L

-- The own auctions in the game's Auctions view, in the game's own window (no panel beside it):
--  * the list of all auctions gets a status per auction (how many items are listed cheaper, once that is more than the
--    limits in the options allow) and a cancel icon where something should be done,
--  * the header of a selected item says the same for that item,
--  * the strip at the bottom has the scan button and a summary.
-- The count behind it comes from searches of the items (AM.OwnAuctions). They start by themselves when the view is
-- entered, as soon as no other scan keeps the auction house busy.
AM.AuctionsView = {}
local AuctionsView = AM.AuctionsView
local Widgets = AM.Widgets
local Native = AM.Native
local UI = AM.Theme.ui

local CANCEL_SIZE = 18
local CANCEL_ICON = "Interface\\PaperDollInfoFrame\\UI-GearManager-LeaveItem-Transparent" -- the circle with a line through it
local GAP = 6
local BAR_HEIGHT = 22
local SCAN_PADDING = 10

local installed = false
local refreshPending = false
local autoPending = false -- the view was entered and its auctions were not searched yet
local bar -- the strip at the bottom
local itemStatus -- the line in the header of a selected item
local listener = {} -- owner of the callbacks on the game's lists
local ResortIfChanged -- below, with the sorting

local function GetAuctionsFrame()
  return AuctionHouseFrame and AuctionHouseFrame.AuctionsFrame
end

local function IsDisplayingBids(frame)
  return frame.IsDisplayingBids ~= nil and frame:IsDisplayingBids()
end

-- The text and color of how far an auction is undercut, nil where it is fine or nothing is to be said.
local function UndercutText(state, severity)
  local number = AM.FormatCount(state.ahead) .. (state.atLeast and "+" or "")
  return Widgets.Color(severity >= 2 and UI.loss or UI.warn, L["AUCTIONS_AHEAD"]:format(number))
end

-- Lines of the list of all auctions -------------------------------------------------------------------------

local function CancelAuction(auctionId)
  if (C_AuctionHouse.GetCancelCost(auctionId) or 0) > 0 then
    -- the game's own confirmation when it costs gold
    StaticPopup_Show("CANCEL_AUCTION", nil, nil, { auctionID = auctionId })
  else
    C_AuctionHouse.CancelAuction(auctionId)
  end
end

local function CreateMark(line)
  local mark = {}
  mark.status = Widgets.CreateText(line, Native.RowFont(), "RIGHT")
  mark.cancel = CreateFrame("Button", nil, line)
  mark.cancel:SetSize(CANCEL_SIZE, CANCEL_SIZE)
  mark.cancel:SetNormalTexture(CANCEL_ICON)
  mark.cancel:SetHighlightTexture(CANCEL_ICON, "ADD")
  mark.cancel:SetScript("OnClick", function()
    if mark.auctionId then
      CancelAuction(mark.auctionId)
    end
  end)
  Widgets.SetTooltip(mark.cancel, AUCTION_HOUSE_CANCEL_AUCTION_BUTTON)
  -- the button takes the mouse from the line, so the line keeps its highlight by hand
  mark.cancel:HookScript("OnEnter", function()
    line.HighlightTexture:Show()
  end)
  mark.cancel:HookScript("OnLeave", function()
    line.HighlightTexture:Hide()
  end)
  return mark
end

-- Where the marks sit on a line of each list: the status and the cancel icon end at the right edge of a cell (the item
-- column of the list of all auctions) or at the left edge of one (the owner column of the list of one item).
local LAYOUTS = {
  all = { cell = 1, from = "RIGHT", to = "RIGHT", x = -4 },
  item = { cell = 5, from = "RIGHT", to = "LEFT", x = -4 },
}

-- Puts the status and the cancel icon on a line of a list, or takes them off. Only reads the data of the line. In the
-- list of one item only the player's own auctions get them.
local function MarkLine(line, layout)
  local data = line.rowData
  local mark = line.amMark
  local sold = Enum.AuctionStatus and data and data.status == Enum.AuctionStatus.Sold
  local foreign = data and data.containsOwnerItem == false
  local cell = line.cells and line.cells[layout.cell]
  if not data or not data.auctionID or sold or foreign or not cell then
    if mark then
      mark.status:Hide()
      mark.cancel:Hide()
    end
    return
  end
  if not mark then
    mark = CreateMark(line)
    line.amMark = mark
  end
  mark.auctionId = data.auctionID
  local state = AM.OwnAuctions.GetState(data.auctionID)
  local severity = AM.OwnAuctions.GetSeverity(data.auctionID)
  local text, action
  if not state then
    -- not searched yet: it is on its way, or something else keeps the auction house busy
    text = Widgets.Color(UI.muted, AM.OwnAuctions.IsRunning() and "..." or L["SELL_TIP_SCAN"])
  elseif severity and severity >= 1 then
    text, action = UndercutText(state, severity), true
  end
  mark.cancel:ClearAllPoints()
  mark.cancel:SetPoint(layout.from, cell, layout.to, layout.x, 0)
  mark.cancel:SetShown(action == true)
  mark.status:ClearAllPoints()
  if action then
    mark.status:SetPoint("RIGHT", mark.cancel, "LEFT", -GAP, 0)
  else
    mark.status:SetPoint(layout.from, cell, layout.to, layout.x, 0)
  end
  mark.status:SetText(text or "")
  mark.status:SetShown(text ~= nil)
end

local function MarkAllLines()
  local frame = GetAuctionsFrame()
  if not frame then
    return
  end
  for key, layout in pairs(LAYOUTS) do
    local list = frame[key == "all" and "AllAuctionsList" or "ItemList"]
    local box = list and list.ScrollBox
    -- a list builds its view when it is first shown: before that there are no lines
    if box and box.GetView and box:GetView() then
      box:ForEachFrame(function(line)
        MarkLine(line, layout)
      end)
    end
  end
end

-- Header of a selected item ---------------------------------------------------------------------------------

-- The worst undercut among the auctions of the selected item.
local function UpdateItemStatus(frame)
  local display = frame.ItemDisplay
  if not display or not display.Name then
    return
  end
  if not itemStatus then
    itemStatus = Widgets.CreateText(display, "GameFontHighlight")
    itemStatus:SetPoint("LEFT", display.Name, "LEFT", 0, -24)
  end
  local itemKey = frame.GetItemKey and frame:GetItemKey()
  local worstState, worst = nil, 0
  if itemKey and not IsDisplayingBids(frame) then
    for _, entry in ipairs(AM.OwnAuctions.GetAll()) do
      local severity = entry.itemId == itemKey.itemID and AM.OwnAuctions.GetSeverity(entry.auctionId)
      if severity and severity >= 1 and (not worstState or severity > worst) then
        worstState, worst = AM.OwnAuctions.GetState(entry.auctionId), severity
      end
    end
  end
  itemStatus:SetText(worstState and UndercutText(worstState, worst) or "")
end

-- Strip at the bottom --------------------------------------------------------------------------------------

-- Auctions searched and undercut more than the limits allow.
local function CountUndercut(entries)
  local count = 0
  for _, entry in ipairs(entries) do
    local severity = AM.OwnAuctions.GetSeverity(entry.auctionId)
    if severity and severity >= 1 then
      count = count + 1
    end
  end
  return count
end

local function IsBusyElsewhere()
  return AM.Scan.IsRunning() or AM.SellScan.IsRunning()
end

local function CreateBar(frame)
  bar = CreateFrame("Frame", nil, frame)
  local anchor = AuctionHouseFrame.MoneyFrameBorder
  bar:SetPoint("TOPLEFT", anchor or frame, anchor and "TOPRIGHT" or "BOTTOMLEFT", 16, 1)
  if frame.CancelAuctionButton then
    bar:SetPoint("BOTTOMRIGHT", frame.CancelAuctionButton, "BOTTOMLEFT", -GAP, 0)
  else
    bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, -BAR_HEIGHT)
  end
  bar:SetHeight(BAR_HEIGHT)

  bar.scan = Widgets.CreateButton(bar, "", false, function()
    if AM.OwnAuctions.IsRunning() then
      AM.OwnAuctions.Stop()
    else
      AM.OwnAuctions.Start(AM.OwnAuctions.GetAll())
    end
  end)
  bar.scan:SetPoint("RIGHT")
  bar.scan:SetHeight(BAR_HEIGHT - 2)
  Widgets.SetTooltip(bar.scan, L["AUCTIONS_SCAN_TOOLTIP"])

  bar.summary = Widgets.CreateText(bar, "GameFontHighlight")
  bar.summary:SetPoint("LEFT")
  bar.summary:SetPoint("RIGHT", bar.scan, "LEFT", -GAP, 0)
  bar.summary:SetWordWrap(false)
end

local function UpdateBar(frame)
  if not bar then
    CreateBar(frame)
  end
  bar:SetShown(not IsDisplayingBids(frame))
  local running = AM.OwnAuctions.IsRunning()
  local entries = AM.OwnAuctions.GetAll()
  local overview = frame.AllAuctionsList ~= nil and frame.AllAuctionsList:IsShown()
  -- with one item selected the game's own refresh button is the way to look again
  bar.scan:SetShown(running or overview)
  if running then
    bar.scan:SetLabel(L["AUCTIONS_STOP"], SCAN_PADDING)
    bar.scan:Enable()
    bar.summary:SetText(Widgets.Color(UI.gold, L["SELL_SCAN_PROGRESS"]:format(AM.OwnAuctions.GetProgress())))
    return
  end
  bar.scan:SetLabel(L["AUCTIONS_SCAN"], SCAN_PADDING)
  bar.scan:SetEnabled(#entries > 0 and not IsBusyElsewhere())
  local undercut = CountUndercut(entries)
  if IsBusyElsewhere() then
    bar.summary:SetText(Widgets.Color(UI.muted, L["AUCTIONS_BUSY"]))
  elseif undercut > 0 then
    bar.summary:SetText(Widgets.Color(UI.loss, L["AUCTIONS_UNDERCUT"]:format(undercut)))
  else
    bar.summary:SetText("")
  end
end

-- Automatic scan ---------------------------------------------------------------------------------------------

-- Searches the auctions that have no current search once per visit of the view, as soon as the auction house is free.
-- Called again by every event that may change one of the conditions.
local function TryAutoScan()
  local frame = GetAuctionsFrame()
  if not autoPending or not frame or not frame:IsShown() or IsDisplayingBids(frame) or AM.MainWindow.IsShown() then
    return
  end
  local entries = AM.OwnAuctions.GetAll()
  if #entries == 0 or IsBusyElsewhere() then
    return -- the auctions are not loaded yet, or the other scan ends first
  end
  autoPending = false
  AM.OwnAuctions.Start(entries, true)
end

function AuctionsView.Update()
  local frame = GetAuctionsFrame()
  if not frame or not frame:IsShown() then
    return
  end
  UpdateBar(frame)
  UpdateItemStatus(frame)
  MarkAllLines()
  ResortIfChanged()
  TryAutoScan()
end

-- Item names and own auctions change in bursts, so redraw once for all of them.
local function UpdateSoon()
  if refreshPending then
    return
  end
  refreshPending = true
  C_Timer.After(0.2, function()
    refreshPending = false
    AuctionsView.Update()
  end)
end

-- Sorting by undercut -------------------------------------------------------------------------------------------

-- The list of all auctions is sorted by the game's server, which knows nothing of the undercut. The list gets its entries
-- through a function: ours hands them out by rank (too much undercut first, then the warnings), the sorting chosen in the
-- header stays the second criterion because entries of one rank keep the game's order.
local sortOrder -- index shown at a position -> index the game gave, as of the last refill of the list

local function EntryRank(getEntry, index)
  local info = getEntry(index)
  local sold = Enum.AuctionStatus and info and info.status == Enum.AuctionStatus.Sold
  return AM.OwnAuctions.SortRank(sold, info and info.auctionID and AM.OwnAuctions.GetSeverity(info.auctionID))
end

local function SameOrder(a, b)
  if not a or not b or #a ~= #b then
    return false
  end
  for index = 1, #a do
    if a[index] ~= b[index] then
      return false
    end
  end
  return true
end

local originalGetEntry, originalGetNumEntries
local resortWanted = false

local function InstallSorting(list)
  if not (list.getEntry and list.getNumEntries and list.SetDataProvider) then
    return
  end
  originalGetEntry, originalGetNumEntries = list.getEntry, list.getNumEntries
  list:SetDataProvider(list.searchStartedFunc, function(index)
    return originalGetEntry(sortOrder and sortOrder[index] or index)
  end, function()
    -- the game asks for the number of entries more often than it refills the list: the order only changes when the
    -- list is to be refilled (resortWanted) or the number of entries differs, else the lines would not match it
    local count = originalGetNumEntries()
    if resortWanted or not sortOrder or #sortOrder ~= count then
      resortWanted = false
      sortOrder = AM.OwnAuctions.BuildSortOrder(count, function(index)
        return EntryRank(originalGetEntry, index)
      end)
    end
    return count
  end, list.hasFullResultsFunc)
end

-- The list is refilled when the ranks changed, not while a scan runs (it would jump under the player's mouse).
function ResortIfChanged()
  local frame = GetAuctionsFrame()
  local list = frame and frame.AllAuctionsList
  if not originalGetEntry or not list or not list:IsShown() or AM.OwnAuctions.IsRunning() then
    return
  end
  local order = AM.OwnAuctions.BuildSortOrder(originalGetNumEntries(), function(index)
    return EntryRank(originalGetEntry, index)
  end)
  if not SameOrder(order, sortOrder) then
    resortWanted = true
    list:DirtyScrollFrame()
  end
end

-- The auction house is load on demand: hooked the first time it opens.
local function Install()
  local frame = GetAuctionsFrame()
  if installed or not frame then
    return
  end
  installed = true
  frame:HookScript("OnShow", function()
    autoPending = true
    AuctionsView.Update()
  end)
  frame:HookScript("OnHide", function()
    autoPending = false
  end)
  if frame.SetDisplayMode then
    hooksecurefunc(frame, "SetDisplayMode", UpdateSoon)
  end
  if frame.SetTab then
    hooksecurefunc(frame, "SetTab", UpdateSoon)
  end
  if frame.AllAuctionsList then
    InstallSorting(frame.AllAuctionsList)
  end
  -- the lines of the lists are reused while scrolling and filled by the game's table builder
  for key, layout in pairs(LAYOUTS) do
    local list = frame[key == "all" and "AllAuctionsList" or "ItemList"]
    local box = list and list.ScrollBox
    if box and box.RegisterCallback and ScrollBoxListMixin and ScrollBoxListMixin.Event then
      box:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, function(_, line)
        MarkLine(line, layout)
        -- the table builder may fill the line after this callback
        C_Timer.After(0, function()
          MarkLine(line, layout)
        end)
      end, listener)
      box:RegisterCallback(ScrollBoxListMixin.Event.OnDataRangeChanged, MarkAllLines, listener)
    end
  end
  AuctionHouseFrame:HookScript("OnHide", function()
    autoPending = false
  end)
  if frame:IsShown() then
    autoPending = true
    UpdateSoon()
  end
end

local events = CreateFrame("Frame")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:SetScript("OnEvent", function(_, event)
  if event == "AUCTION_HOUSE_SHOW" then
    Install()
  else
    UpdateSoon()
  end
end)

-- The auctions changed, or a search told what is ahead of them.
AM.Events.Register("OWN_AUCTIONS_CHANGED", UpdateSoon)
-- Our own window covers the Auctions view of the game, and may uncover it again.
AM.Events.Register("MAIN_WINDOW_VISIBILITY", UpdateSoon)
-- The full scan or the scan of the Sell tab started or ended: the button waits for them.
AM.Events.Register("SCAN_CHANGED", UpdateSoon)
AM.Events.Register("SELL_SCAN_CHANGED", UpdateSoon)
