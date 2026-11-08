--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
--
--  All Rights Reserved
----------------------------------------------------------------------------]]

-- The player's position.

local addonName, addon = ...
local TomTom = addon
local L = addon.L
local hbd = addon.hbd

-- The same rule as InputUtil.IsGamepadUIEnabled(), which only exists on
-- clients with the gamepad interface (Forever, 12.1.7 and later). In that
-- mode Blizzard's secure gamepad code scans every world map pin and every
-- button in WorldMapFrame, and addon frames there taint it
-- (docs/gamepad/findings.md). This is a TomTom method, not AddonCore, until
-- the maintainer moves it to the shared library.
function TomTom:IsGamepadUI()
    local styleAPI = C_InputInterfaceStyle
    if styleAPI and styleAPI.GetCurrentStyle and Enum.InputDeviceInterfaceType then
        return styleAPI.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad
    end
    return false
end

-- Thanks to the user who suggested using the C_Map API to fix some of the
-- previous weirdness that was here
function TomTom:GetCurrentPlayerPosition()
    local playerMapID = C_Map and C_Map.GetBestMapForUnit("player") or nil
    local x, y, mapID = hbd:GetPlayerZonePosition()

    -- If HBD and the WoW API agree on the player map, return the position!
    if x and y and x > 0 and y > 0 and mapID and (playerMapID and mapID == playerMapID) then
        return mapID, x, y
    end

    -- If the WoW API and the HBD map results are different, we fall back to the
    -- WoW API if we have it
    if C_Map and playerMapID then
        local pos = C_Map.GetPlayerMapPosition(playerMapID, "player")
        if pos then
            return playerMapID, pos:GetXY()
        end
    end
end

-- Returns the player's current coordinates without flipping the map or
-- causing any other weirdness. This can and will cause the coordinates to be
-- weird if you zoom the map out to your parent, but there is no way to
-- recover this without changing/setting the map zoom. Deal with it =)
function TomTom:GetCurrentCoords()
    local map, x, y = self:GetCurrentPlayerPosition()
    return x, y
end
