local addonName, AM = ...

-- Which auction house is open. Forever and Classic have a neutral auction house (Booty Bay, Gadgetzan, Everlook),
-- shared by both factions and with auctions of its own, apart from the faction's. Its auctions are never stored: the
-- stored prices are those of the faction's auction house. It is told by the auctioneer when the auction house opens:
-- the faction's auctioneers belong to Horde or Alliance, the neutral ones to no faction (Booty Bay answers nil).
-- Not on Retail: whether its neutral auction house still has auctions of its own is not known.
AM.AuctionHouse = {}
local AuctionHouse = AM.AuctionHouse

-- Of the auction house opened last, kept after it closed for answers that arrive late.
local neutral = false

-- True if the auctioneer's faction (UnitFactionGroup) is that of a neutral auction house: neither Horde nor Alliance.
function AuctionHouse.IsNeutralFaction(faction)
  return faction ~= "Horde" and faction ~= "Alliance"
end

function AuctionHouse.IsNeutral()
  return neutral
end

local function OnShow()
  neutral = false
  if not AM.Client.IsRetail() and UnitExists("npc") then
    neutral = AuctionHouse.IsNeutralFaction(UnitFactionGroup("npc"))
  end
  AM.DebugLog.Log("game", "neutral auction house: %s", tostring(neutral))
end

local events = CreateFrame("Frame")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:SetScript("OnEvent", OnShow)
