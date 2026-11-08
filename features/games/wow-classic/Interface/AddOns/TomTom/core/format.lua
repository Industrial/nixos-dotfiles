--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
--
--  All Rights Reserved
----------------------------------------------------------------------------]]

-- Formatting helpers shared by the core and the modules.

local addonName, addon = ...
local TomTom = addon
local L = addon.L

-- Internal helpers that the TomTom files share. Not part of the public API.
addon.private = addon.private or {}
local private = addon.private

local RoundCoords

local coord_fmt = "%%.%df, %%.%df"
function RoundCoords(x,y,prec)
    local fmt = coord_fmt:format(prec, prec)
    if not x or not y then
        return "---"
    end
    return fmt:format(x*100, y*100)
end

private.RoundCoords = RoundCoords
