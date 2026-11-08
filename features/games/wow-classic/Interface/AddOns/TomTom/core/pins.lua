--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
--
--  All Rights Reserved
----------------------------------------------------------------------------]]

-- The parts that the minimap pins and the world map pins share: the
-- waypoint tooltip and the mouse scripts of a pin frame. A pin frame has
-- the fields `uid` and `callbacks` (the `minimap` or `world` part of the
-- waypoint callbacks).

local _, addon = ...
local TomTom = addon
addon.private = addon.private or {}
local private = addon.private
local errorHandler = geterrorhandler()

local tooltip = CreateFrame("GameTooltip", "TomTomTooltip", UIParent, "GameTooltipTemplate")
do
    -- The tooltip_update callbacks change single lines, not the full tooltip.
    local i = 1
    tooltip.lines = {}
    repeat
        local line = _G["TomTomTooltipTextLeft" .. i]
        if line then
            tooltip.lines[i] = line
        end
        i = i + 1
    until not line
end

local tooltipUid, tooltipCallbacks

local function Tooltip_OnUpdate()
    if tooltipCallbacks and tooltipCallbacks.tooltip_update then
        local dist = TomTom:GetDistanceToWaypoint(tooltipUid)
        tooltipCallbacks.tooltip_update("tooltip_update", tooltip, tooltipUid, dist)
    end
end

function private.Pin_OnClick(self, button)
    local data = self.callbacks
    if data and data.onclick then
        xpcall(data.onclick, errorHandler, "onclick", self.uid, self, button)
    end
end

function private.Pin_OnEnter(self)
    local data = self.callbacks
    if not (data and data.tooltip_show) then return end

    local uid = self.uid
    local dist = TomTom:GetDistanceToWaypoint(uid)
    tooltipUid, tooltipCallbacks = uid, data

    -- A hidden UIParent would hide the tooltip with it.
    if UIParent:IsVisible() then
        tooltip:SetParent(UIParent)
    else
        tooltip:SetParent(self)
    end

    tooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    -- Callbacks from other addons may leave the Show() to TomTom, so only an
    -- explicit false keeps the tooltip hidden (B24).
    local _, result = xpcall(data.tooltip_show, errorHandler, "tooltip_show", tooltip, uid, dist)
    if result == false then
        tooltipUid, tooltipCallbacks = nil, nil
        return
    end
    tooltip:Show()

    tooltip:SetScript("OnUpdate", data.tooltip_update and Tooltip_OnUpdate or nil)
end

function private.Pin_OnLeave()
    tooltipUid, tooltipCallbacks = nil, nil
    tooltip:Hide()
end

-- The minimap and world map settings pages share their theme list.
function private.WaypointThemeValues()
    return addon.waypointThemeRegistry:GetThemeConfigOptions()
end
