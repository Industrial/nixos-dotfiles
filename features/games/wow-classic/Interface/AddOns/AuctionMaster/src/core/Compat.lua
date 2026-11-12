local _, AM = ...

-- Hooks for UI addons that restyle the game's windows. Those addons keep their own state for what they draw (which tab
-- is selected, the frame art), which our windows cannot change from outside, so where an addon offers a skinning
-- interface our frames are handed to it.
-- The interface of EllesmereUI is there whatever look that addon is set to, so it is used for a frame of the game (the
-- host: the auction house, ...) only where that frame has actually been restyled, i.e. its art is faded out. With the
-- Blizzard look, or the window skin switched off, everything is drawn as without the addon.
--   AM.Compat.OnSkin(host, fn)   fn(skin) runs once the interface is there and the host is restyled, at once if both
--                                are true already; never where that addon is not loaded
--   AM.Compat.GetSkin(host)      the interface, or nil where the host is not restyled
AM.Compat = {}
local Compat = AM.Compat

local skin
local waiting = {} -- { host, fn }

local function IsRestyled(host)
  return host ~= nil and host.NineSlice ~= nil and host.NineSlice:GetAlpha() == 0
end

function Compat.GetSkin(host)
  return skin and IsRestyled(host) and skin or nil
end

function Compat.OnSkin(host, fn)
  if skin then
    if IsRestyled(host) then
      pcall(fn, skin)
    end
  else
    waiting[#waiting + 1] = { host, fn }
  end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  if not (EllesmereUI and EllesmereUI.RegisterSkin) then
    return
  end
  -- an optional extra: whatever the interface of that addon does, a failure stays out of our own code
  pcall(EllesmereUI.RegisterSkin, "AuctionMaster", function(facade)
    skin = facade
    for _, entry in ipairs(waiting) do
      if IsRestyled(entry[1]) then
        pcall(entry[2], facade)
      end
    end
    waiting = {}
  end)
end)
