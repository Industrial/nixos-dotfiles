--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
--
--  All Rights Reserved
----------------------------------------------------------------------------]]

-- Modifier-click on the world map to add a waypoint.

local addonName, addon = ...
local TomTom = addon
local L = addon.L
addon.private = addon.private or {}
local private = addon.private

-- worldmap.clickcreate turns the module on. Its defaults are in
-- core/settings.lua, because the world map pins own the namespace defaults.
local module = {
    settingsKey = "worldmap",
    enableSetting = {"worldmap", "clickcreate"},
}
-- The click handler sits in WorldMapFrame, where the gamepad interface
-- would find it (docs/gamepad/findings.md). There is no gamepad version.
function module:IsAvailable()
    return not TomTom:IsGamepadUI()
end

private.AddModule(module, "MapClick")

local verifyFuncs = {
    ["A"] = function(alt, ctrl, shift) return alt and not (ctrl or shift) end,
    ["C"] = function(alt, ctrl, shift) return ctrl and not (alt or shift) end,
    ["S"] = function(alt, ctrl, shift) return shift and not (alt or ctrl) end,
    ["AC"] = function(alt, ctrl, shift) return (alt and ctrl) and not (shift) end,
    ["AS"] = function(alt, ctrl, shift) return (alt and shift) and not (ctrl) end,
    ["CS"] = function(alt, ctrl, shift) return (ctrl and shift) and not (alt) end,
    ["ACS"] = function(alt, ctrl, shift) return alt and ctrl and shift end,
}

private.AddSettingsSection{
    page = "worldmap", pageName = L["World Map"], pageOrder = 30, order = 20,
    settingsKey = "worldmap",
    header = L["Create waypoints from the map"],
    rows = {
        {type = "toggle", key = "clickcreate", name = L["Allow control-right clicking on map to create new waypoint"]},
        {type = "select", key = "create_modifier", name = L["Create note modifier"],
         tooltip = L["This setting changes the modifier used by TomTom when right-clicking on the world map to create a waypoint"],
         values = {
             ["A"] = "Alt",
             ["C"] = "Ctrl",
             ["S"] = "Shift",
             ["AC"] = "Alt-Ctrl",
             ["AS"] = "Alt-Shift",
             ["CS"] = "Ctrl-Shift",
             ["ACS"] = "Alt-Ctrl-Shift",
         }},
    },
}

-- Thanks to Nevcariel for the help with this one!
function addon:CreateWorldMapClickHandler()
    if self.worldMapClickHandler then
        return self.worldMapClickHandler
    end
    self.worldMapClickHandler = CreateFrame("Frame", addonName .. "WorldMapClickHandler", WorldMapFrame.ScrollContainer)

    local handler = self.worldMapClickHandler
    handler:SetAllPoints()

    handler.UpdatePassThrough = function(self)
        local alt, ctrl, shift = IsAltKeyDown(), IsControlKeyDown(), IsShiftKeyDown()

        local modKey = TomTom.db.profile.worldmap.create_modifier
        if modKey and verifyFuncs[modKey] and verifyFuncs[modKey](alt, ctrl, shift) then
            if self.SetPassThroughButtons and not InCombatLockdown() then
                self:SetPassThroughButtons("LeftButton", "MiddleButton", "Button4", "Button5")
            end

            self:Show()
        else
            if self.SetPassThroughButtons and not InCombatLockdown() then
                self:SetPassThroughButtons("LeftButton", "RightButton", "MiddleButton", "Button4", "Button5")
            end

            self:Hide()
        end
    end

    handler:SetScript("OnEvent", handler.UpdatePassThrough)

    handler:SetScript("OnUpdate", function(self, elapsed)
            handler:UpdatePassThrough()
    end)

    return handler
end

-- The handler shows only while the modifier is down, and the modifier event
-- shows it. Without the event it stays hidden and takes no clicks.
local function OnMouseUp()
    addon:AddWaypointFromMapClick()
end

-- Blizzard's gamepad navigation finds a hidden frame with an OnMouseUp
-- script, so the script exists only while the module runs.
function module:OnEnable()
    local handler = TomTom:CreateWorldMapClickHandler()
    handler:SetScript("OnMouseUp", OnMouseUp)
    handler:RegisterEvent("MODIFIER_STATE_CHANGED")
    handler:UpdatePassThrough()
end

function module:OnDisable()
    local handler = TomTom.worldMapClickHandler
    handler:UnregisterEvent("MODIFIER_STATE_CHANGED")
    handler:SetScript("OnMouseUp", nil)
    handler:Hide()
end

function addon:AddWaypointFromMapClick()
    local m = WorldMapFrame.mapID
    local x,y = WorldMapFrame:GetNormalizedCursorPosition()

    if not m or m == 0 then
        return
    end

    TomTom:AddWaypoint(m, x, y, { title = L["TomTom waypoint"], from="TomTom/wm"})
end
