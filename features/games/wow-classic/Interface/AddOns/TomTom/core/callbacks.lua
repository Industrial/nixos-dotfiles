--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
--
--  All Rights Reserved
----------------------------------------------------------------------------]]

-- Public callbacks for other addons (decision D12), through CallbackHandler,
-- with the same interface as AceDB:
--
--   TomTom.RegisterCallback(owner, "WaypointAdded", function(event, uid) end)
--   TomTom.UnregisterCallback(owner, "WaypointAdded")
--
-- Events and their arguments (README.md documents them):
--   WaypointAdded(uid)            AddWaypoint added a new waypoint
--   WaypointRemoved(uid)          RemoveWaypoint removed it, or a reload of
--                                 the waypoints dropped it
--   WaypointsReloaded()           the saved waypoints were loaded again
--   ArrowTargetChanged(uid)       the arrow target changed; uid is nil when
--                                 the arrow has no target
--   ArrowThemeChanged(themeKey)   the arrow theme changed
--   ArrowVisibilityChanged(shown) the arrow showed or hid; shown counts
--                                 only a visible frame with a target or
--                                 a hijack
--   ArrowSettingsApplied(shown)   ShowHideCrazyArrow ran; it can fire with
--                                 no change
--
-- The internal TOMTOM_* messages are not public; they can change.

local _, addon = ...
local TomTom = addon
addon.private = addon.private or {}
local private = addon.private

TomTom.callbacks = LibStub("CallbackHandler-1.0"):New(TomTom)

function private.FireCallback(event, ...)
    TomTom.callbacks:Fire(event, ...)
end

TomTom:RegisterMessage("TOMTOM_ARROW_TARGET_CHANGED", function(_, uid)
    private.FireCallback("ArrowTargetChanged", uid)
end)

TomTom:RegisterMessage("TOMTOM_ARROW_THEME_CHANGED", function(_, themeKey)
    private.FireCallback("ArrowThemeChanged", themeKey)
end)

TomTom:RegisterMessage("TOMTOM_ARROW_VISIBILITY_CHANGED", function(_, shown)
    private.FireCallback("ArrowVisibilityChanged", shown)
end)

TomTom:RegisterMessage("TOMTOM_ARROW_SETTINGS_APPLIED", function(_, shown)
    private.FireCallback("ArrowSettingsApplied", shown)
end)
