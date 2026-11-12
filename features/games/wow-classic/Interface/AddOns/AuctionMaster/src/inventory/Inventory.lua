local addonName, AM = ...

-- What the characters of this faction carry in their bags and bank, so that the shopping list can count the materials
-- of a crafter that is not the character played. Kept in the faction object "inventory": GUID -> { bags, bank }, each
-- a map of itemId to the amount. The bags are read whenever they change; the bank only while it is open, as the game
-- cannot tell what is in it otherwise, so it stays as it was left. The account (warband) bank is not kept: every
-- character sees the same one, the game's own count of the current character already includes it. The mailboxes are
-- in Mailbox.lua.
local Inventory = {}
AM.Inventory = Inventory

local bankOpen = false
local bagIndexes, bankIndexes -- container indexes of this client, found on first use

-- The container indexes differ per client (bank bags, reagent bank, bank tabs), so they are looked up by the names
-- of Enum.BagIndex. Bank containers are the ones with "bank" in the name; the account bank and the keyring are left out.
local function FindContainers()
  bagIndexes, bankIndexes = {}, {}
  for name, index in pairs(Enum.BagIndex or {}) do
    local lower = name:lower()
    if not lower:find("^account") and not lower:find("^keyring") then
      table.insert(lower:find("bank") and bankIndexes or bagIndexes, index)
    end
  end
end

-- The amounts in the containers as itemId -> amount, nil if none of them exists (not available yet or the bank
-- cannot be read).
local function ReadContainers(indexes)
  local counts, slots = {}, 0
  for _, bag in ipairs(indexes) do
    local numSlots = C_Container.GetContainerNumSlots(bag) or 0
    slots = slots + numSlots
    for slot = 1, numSlots do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID then
        counts[info.itemID] = (counts[info.itemID] or 0) + (info.stackCount or 1)
      end
    end
  end
  return slots > 0 and counts or nil
end

local function GetEntry(guid)
  return AM.Database.GetFactionObject("inventory")[guid]
end

-- The events come when the game has finished a change (BAG_UPDATE_DELAYED already sums up a burst), so the
-- containers are read at once: the bank cannot be read any more once it is closed, a delay could miss the last
-- change before that.
local function Scan()
  if not bagIndexes then
    FindContainers()
  end
  local inventory = AM.Database.GetFactionObject("inventory")
  local guid = UnitGUID("player")
  local entry = inventory[guid] or { bags = {}, bank = {} }
  inventory[guid] = entry
  entry.bags = ReadContainers(bagIndexes) or entry.bags
  if bankOpen then
    entry.bank = ReadContainers(bankIndexes) or entry.bank
  end
end

-- The sum of the amounts of the item (all its qualities in itemIds) in the map.
local function Sum(counts, itemIds)
  local total = 0
  for _, itemId in ipairs(itemIds) do
    total = total + (counts[itemId] or 0)
  end
  return total
end

-- How many of the item the character carries (bags and bank), as of the last time the character was played.
function Inventory.GetCount(guid, itemId)
  local entry = GetEntry(guid)
  if not entry then
    return 0
  end
  return (entry.bags[itemId] or 0) + (entry.bank[itemId] or 0)
end

-- Where a character carries the item (all the qualities in itemIds), as last seen: bags, bank, and whether the
-- character has been played with this version (otherwise they are 0 only because they are not known).
function Inventory.GetStored(guid, itemIds)
  local entry = GetEntry(guid)
  if not entry then
    return 0, 0, false
  end
  return Sum(entry.bags, itemIds), Sum(entry.bank, itemIds), true
end

-- Where the current character carries the item, from the game's own count: bags, bank (with the reagent bank),
-- account bank.
function Inventory.GetLive(itemIds)
  local getCount = C_Item.GetItemCount or GetItemCount
  local bags, withBank, all = 0, 0, 0
  for _, itemId in ipairs(itemIds) do
    bags = bags + getCount(itemId, false)
    withBank = withBank + getCount(itemId, true, false, true)
    all = all + getCount(itemId, true, false, true, true)
  end
  return bags, withBank - bags, all - withBank
end

-- Forgets a character (deleted).
function Inventory.ForgetCharacter(guid)
  AM.Database.GetFactionObject("inventory")[guid] = nil
end

if Enum and Enum.BagIndex and C_Container and C_Container.GetContainerItemInfo then
  local frame = CreateFrame("Frame")
  -- not every client has every event, and registering an unknown one is an error
  for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED" }) do
    pcall(frame.RegisterEvent, frame, event)
  end
  frame:SetScript("OnEvent", function(_, event)
    if event == "BANKFRAME_CLOSED" then
      bankOpen = false
      return
    end
    bankOpen = bankOpen or event == "BANKFRAME_OPENED"
    Scan()
  end)
end
