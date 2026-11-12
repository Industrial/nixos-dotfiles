local addonName, AM = ...

-- The shopping list for the objective tracker of the game (ObjectiveTracker.lua on the clients with the newer tracker,
-- WatchFrameTracker.lua on those with the older WatchFrame). This file holds what both show and tells them to redraw:
-- a flat list of the items all crafters' lists need (the filter of the Buy tab does not apply), summed up over their
-- recipes, as "have/need name" lines. Nothing of the game's own tracking (tracked recipes) is read or written, the
-- lists are our own.
AM.ShoppingTracker = {}
local ShoppingTracker = AM.ShoppingTracker
local ShoppingList = AM.ShoppingList

local views = {} -- functions redrawing a tracker, registered by the files that know one
local entries
local dirty = true
local refreshPending = false
local waitingForNames = false -- a line shows "..." for an item that is not cached yet

-- A view registers a function that makes the game's tracker lay itself out again.
function ShoppingTracker.RegisterView(refresh)
  views[#views + 1] = refresh
end

-- The items as { itemId, text, done, missing }, the ones still needed first, none if the list has no recipes.
function ShoppingTracker.GetEntries()
  if not dirty and entries then
    return entries
  end
  dirty = false
  waitingForNames = false
  entries = {}
  local model = ShoppingList.BuildCombinedModel(ShoppingList.GetAllLists())
  for _, group in ipairs({ model.needed, model.done }) do
    for _, item in ipairs(group) do
      local name = ShoppingList.GetItemDetails(item.itemId)
      waitingForNames = waitingForNames or name == nil
      local done = item.have >= item.need
      local icon = not done and ShoppingList.GetSourceIcon(item) or ""
      entries[#entries + 1] = { itemId = item.itemId, itemIds = item.itemIds, crafters = item.crafters,
        text = item.owned .. "/" .. item.need .. " " .. icon .. (name or "..."),
        done = done, missing = math.max(1, item.need - item.have) }
    end
  end
  return entries
end

-- unseen: the character was not played with this version, so what it carries is not known
local function AddCharacter(name, class, counts, unseen)
  local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  GameTooltip:AddLine(name, color and color.r or 1, color and color.g or 1, color and color.b or 1)
  local shown = false
  for _, count in ipairs(counts) do
    if count[2] > 0 then
      GameTooltip:AddDoubleLine("  " .. count[1], count[2], 0.8, 0.8, 0.8, 1, 1, 1)
      shown = true
    end
  end
  if unseen then
    GameTooltip:AddLine("  " .. AM.L["TRACKER_NOT_SEEN"], 0.5, 0.5, 0.5)
  elseif not shown then
    GameTooltip:AddLine("  " .. AM.L["TRACKER_NONE"], 0.5, 0.5, 0.5)
  end
end

-- Tooltip of a line: where the item is, for the current character and the crafters whose lists need it. The
-- crafters are shown as last seen, a crafter not played with this version yet is "not seen yet" instead of 0.
function ShoppingTracker.ShowTooltip(owner, entry)
  local L = AM.L
  local name, quality = ShoppingList.GetItemDetails(entry.itemId)
  local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
  GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
  GameTooltip:SetText(name or "...", color and color.r or 1, color and color.g or 1, color and color.b or 1)
  local player = UnitGUID("player")
  local bags, bank, account = AM.Inventory.GetLive(entry.itemIds)
  AddCharacter(UnitName("player"), select(2, UnitClass("player")), { { L["TRACKER_BAGS"], bags },
    { L["TRACKER_BANK"], bank }, { L["TRACKER_WARBAND_BANK"], account },
    { L["TRACKER_MAIL"], AM.Mailbox.GetCount(player, entry.itemIds) } })
  for _, guid in ipairs(entry.crafters) do
    if guid ~= player then
      local crafter = ShoppingList.GetCrafter(guid)
      local storedBags, storedBank, seen = AM.Inventory.GetStored(guid, entry.itemIds)
      local storedMail = AM.Mailbox.GetCount(guid, entry.itemIds)
      if seen then
        AddCharacter(crafter.name, crafter.class, { { L["TRACKER_BAGS"], storedBags }, { L["TRACKER_BANK"], storedBank },
          { L["TRACKER_MAIL"], storedMail } })
      else
        -- bags and bank are not known, the mail is what was sent to the crafter
        AddCharacter(crafter.name, crafter.class, { { L["TRACKER_MAIL"], storedMail } }, true)
      end
    end
  end
  GameTooltip:Show()
end

-- Something the lines depend on changed: the next layout of the trackers builds them again.
function ShoppingTracker.Update()
  dirty = true
  for _, refresh in ipairs(views) do
    refresh()
  end
end

-- Right click on the tracker's list: a menu with "Clear list" that asks before it empties all crafters' lists (the
-- tracker shows them all). Without the menu API of the game (Classic) the question comes directly.
function ShoppingTracker.OpenMenu(owner)
  local lists = ShoppingList.GetAllLists()
  local function Ask()
    StaticPopup_Show("AUCTIONMASTER_CLEAR_ALL_LISTS", nil, nil, lists)
  end
  if MenuUtil and MenuUtil.CreateContextMenu then
    MenuUtil.CreateContextMenu(owner, function(_, root)
      root:CreateButton(AM.L["SHOPPING_CLEAR"], Ask)
    end)
  else
    Ask()
  end
end

-- Bags and item names change in bursts, so redraw once for all of them.
local function UpdateSoon()
  if refreshPending then
    return
  end
  refreshPending = true
  C_Timer.After(0.2, function()
    refreshPending = false
    ShoppingTracker.Update()
  end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:SetScript("OnEvent", function(_, event)
  -- item data arrives all the time, it only matters while a name is missing
  if event == "BAG_UPDATE_DELAYED" or waitingForNames then
    UpdateSoon()
  end
end)

AM.Events.Register("PRICES_CHANGED", ShoppingTracker.Update)
AM.Events.Register("CRAFTERS_CHANGED", ShoppingTracker.Update)
