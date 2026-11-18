local addonName, AM = ...

-- Keeps the ledger's stock in line with what the characters really hold (doc/notes/ledger.md, "Loot", item 33), read
-- only: units that left without an event (eaten, equipped, destroyed, used for a quest) are booked as used up with
-- Ledger.ReconcileStock.
--
-- Held is what all characters of this auction house carry as last seen (AM.Inventory: bags and bank; the bank only
-- changes while it is open, so its picture stays true) and their mail as far as known (AM.Mailbox, mail sent to one of
-- them included), on Retail the warband bank too; the ledger adds the open auctions. A shortfall can only come from the
-- logged in character, as the others cannot change while offline.
--
-- It only compares when nothing is on its way: DELAY seconds after the last change of the bags, and never while a
-- window that moves items is open (merchant: its sales are booked when it closes; mailbox, auction house, bank, guild
-- bank, trade, loot window), by its frame being shown or by its open event without a close event (for addons that
-- replace the frame; at most BUSY_TIMEOUT, as a close event can be missing). Not covered: the guild bank (an item put there counts as used up).

local DELAY = 10

-- the windows that move items, by the events that open and close them
local OPENS = {
  MERCHANT_SHOW = "merchant", MAIL_SHOW = "mail", AUCTION_HOUSE_SHOW = "auction", BANKFRAME_OPENED = "bank",
  GUILDBANKFRAME_OPENED = "guildbank", TRADE_SHOW = "trade", LOOT_OPENED = "loot",
}
local CLOSES = {
  MERCHANT_CLOSED = "merchant", MAIL_CLOSED = "mail", AUCTION_HOUSE_CLOSED = "auction", BANKFRAME_CLOSED = "bank",
  GUILDBANKFRAME_CLOSED = "guildbank", TRADE_CLOSED = "trade", LOOT_CLOSED = "loot",
}

-- the game's frames of these windows: shown means busy, whatever the events said
local FRAMES = { "MerchantFrame", "MailFrame", "AuctionHouseFrame", "BankFrame", "GuildBankFrame", "TradeFrame",
  "LootFrame" }
-- a window whose close event never came (seen on Forever: no MAIL_CLOSED after the mailbox) blocks only this long,
-- unless its frame is still shown
local BUSY_TIMEOUT = 300

local busy = {} -- name -> when the window opened, for the windows open now by their events
local timer

local function IsBusy()
  for _, name in ipairs(FRAMES) do
    local frame = _G[name]
    if frame and frame.IsShown and frame:IsShown() then
      return true
    end
  end
  local now = GetTime()
  for name, since in pairs(busy) do
    if now - since > BUSY_TIMEOUT then
      busy[name] = nil
    else
      return true
    end
  end
  return false
end

-- How many of the item all characters hold outside the auction house, as far as known.
local function Held(itemId)
  local itemIds = { itemId }
  local total = 0
  for guid in pairs(AM.Characters.GetHouseGuids()) do
    total = total + AM.Inventory.GetCount(guid, itemId) + AM.Mailbox.GetCount(guid, itemIds)
  end
  -- the warband bank (Retail), the same for every character: once
  local _, _, account = AM.Inventory.GetLive(itemIds)
  return total + (account or 0)
end

local Schedule

local function Reconcile()
  timer = nil
  if IsBusy() then
    -- try again later: a window may close without an event
    Schedule()
    return
  end
  local guid = UnitGUID("player")
  -- the bags of the logged in character must be known, else everything would look gone
  local _, _, known = AM.Inventory.GetStored(guid, {})
  if not known then
    AM.DebugLog.Log("ledger", "stock not reconciled: bags not known")
    return
  end
  AM.Ledger.ReconcileStock(guid, Held)
end

function Schedule()
  if timer then
    timer:Cancel()
  end
  timer = C_Timer.NewTimer(DELAY, function()
    local ok, err = pcall(Reconcile)
    if not ok then
      AM.DebugLog.Log("ledger", "stock not reconciled: %s", err)
    end
  end)
end

local frame = CreateFrame("Frame")
for _, events in ipairs({ OPENS, CLOSES }) do
  for event in pairs(events) do
    pcall(frame.RegisterEvent, frame, event)
  end
end
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(_, event)
  if OPENS[event] then
    busy[OPENS[event]] = GetTime()
  elseif CLOSES[event] then
    busy[CLOSES[event]] = nil
  end
  -- every change starts the wait again; Reconcile waits on while a window is open
  Schedule()
end)
