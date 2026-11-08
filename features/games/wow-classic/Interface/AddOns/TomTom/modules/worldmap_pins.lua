--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
--
--  All Rights Reserved
----------------------------------------------------------------------------]]

-- The world map pins of the active waypoints. A pin frame exists only while
-- its pin shows: a hidden or turned-off pin goes back to the pool and out
-- of HereBeDragons, so the map cannot show it again on a refresh (B20).

local _, addon = ...
local TomTom = addon
local L = addon.L
local hbd = addon.hbd
local hbdp = LibStub("HereBeDragons-Pins-2.0")
addon.private = addon.private or {}
local private = addon.private

-- The worldmap namespace also holds the map click settings
-- (modules/map_click.lua); their defaults are in core/settings.lua.
local module = {
    settingsKey = "worldmap",
    defaults = {
        enable = true,
        tooltip = true,
        otherzone = true,
        menu = true,
        default_iconsize = 16,
        default_icon = "Interface\\AddOns\\TomTom\\Images\\GoldGreenDot",
        theme = "modern-green",
    },
}
-- Off while the gamepad interface is on (docs/gamepad/findings.md).
function module:IsAvailable()
    return not TomTom:IsGamepadUI()
end

private.AddModule(module, "WorldMapPins")

-- HBD_PINS_WORLDMAP_SHOW_WORLD: the zone, its continent and the world map.
local SHOW_ON_WORLD = 3

local pins = {}  -- uid -> frame
local pool = {}

local function DotTexture()
    return addon.waypointThemeRegistry:GetThemeDotTexture(TomTom.profile.worldmap.theme)
end

private.AddSettingsSection{
    page = "worldmap", pageName = L["World Map"], pageOrder = 30, order = 10,
    settingsKey = "worldmap",
    feature = {name = L["Enable world map waypoints"]},
    rows = {
        {type = "text", text = L["TomTom can display multiple waypoints on the world map.  These options control the display of these waypoints"]},
        {type = "toggle", key = "otherzone", name = L["Display waypoints from other zones"],
         tooltip = L["TomTom can hide waypoints in other zones, this setting toggles that functionality"]},
        {type = "toggle", key = "tooltip", name = L["Enable mouseover tooltips"],
         tooltip = L["TomTom can display a tooltip containing information about waypoints, when they are moused over.  This setting toggles that functionality"]},
        {type = "toggle", key = "menu", name = L["Enable the right-click contextual menu"],
         tooltip = L["Enables a menu when right-clicking on a waypoint allowing you to clear or remove waypoints"]},
        {type = "header", name = L["Themes"]},
        {type = "text", text = L["There are a few different themes that you can apply to the waypoints, use this section to configure."]},
        {type = "select", key = "theme", name = L["Theme"],
         tooltip = L["You can customize the display of the waypoints with a variety of themes."],
         values = private.WaypointThemeValues,
         sorting = addon.waypointThemeRegistry:GetThemeConfigOptionsSorting()},
        {type = "preview", watch = {"theme"},
         imageFunc = function() return {texture = DotTexture(), width = 20, height = 20} end},
        {type = "range", key = "default_iconsize", name = L["World Map Icon Size"],
         tooltip = L["This setting allows you to control the default size of the world map icon"],
         min = 4, max = 64, step = 2},
    },
}

--[[--------------------------------------------------------------------------
--  Pin frames
----------------------------------------------------------------------------]]

-- A pin frame is inside WorldMapFrame only while HereBeDragons shows it.
-- Blizzard's gamepad navigation finds any button in WorldMapFrame, also a
-- hidden one, so the idle frames stay here (HereBeDragons puts released
-- frames on UIParent too).
local holder = CreateFrame("Frame", nil, UIParent)
holder:Hide()

local function CreatePin()
    local frame = CreateFrame("Button", nil, holder)
    frame:RegisterForClicks("RightButtonUp")
    frame.icon = frame:CreateTexture(nil, "OVERLAY")
    frame.icon:SetAllPoints()
    frame.icon:SetBlendMode("BLEND")
    frame:SetScript("OnEnter", private.Pin_OnEnter)
    frame:SetScript("OnLeave", private.Pin_OnLeave)
    frame:SetScript("OnClick", private.Pin_OnClick)
    return frame
end

-- The waypoint can give its own icon; else the theme gives it.
local function ApplyIcon(frame, uid)
    if uid.worldmap_displayID then
        SetPortraitTextureFromCreatureDisplayID(frame.icon, uid.worldmap_displayID)
    else
        frame.icon:SetTexture(uid.worldmap_icon or DotTexture())
    end
    local size = uid.worldmap_icon_size or TomTom.profile.worldmap.default_iconsize
    frame:SetSize(size, size)
end

local function AcquirePin(uid)
    local frame = table.remove(pool) or CreatePin()
    local display = private.GetWaypointDisplay(uid)
    frame.uid = uid
    frame.callbacks = display.callbacks and display.callbacks.world
    ApplyIcon(frame, uid)
    pins[uid] = frame
    hbdp:AddWorldMapIconMap(TomTom, frame, uid[1], uid[2], uid[3], SHOW_ON_WORLD)
    return frame
end

local function ReleasePin(uid)
    local frame = pins[uid]
    if not frame then return end
    hbdp:RemoveWorldMapIcon(TomTom, frame)
    frame:Hide()
    frame.uid = nil
    frame.callbacks = nil
    pins[uid] = nil
    table.insert(pool, frame)
end

local function WantsPin(uid)
    return module:IsEnabled()
        and private.ShowsPin(uid, "world")
        and (TomTom.profile.worldmap.otherzone or private.InPlayerZone(uid[1]))
end

local function UpdatePin(uid)
    if WantsPin(uid) then
        if not pins[uid] then
            AcquirePin(uid)
        end
    else
        ReleasePin(uid)
    end
end

local function UpdateAllPins()
    for uid in private.IterateActiveWaypoints() do
        UpdatePin(uid)
    end
end

local function ReleaseAllPins()
    for uid in pairs(pins) do
        ReleasePin(uid)
    end
end

--[[--------------------------------------------------------------------------
--  Module
----------------------------------------------------------------------------]]

-- A second SetWaypoint for the same uid can change its icon or callbacks.
function module:TOMTOM_WAYPOINT_ADDED(_, uid)
    ReleasePin(uid)
    UpdatePin(uid)
end

function module:TOMTOM_WAYPOINT_REMOVED(_, uid)
    ReleasePin(uid)
end

function module:TOMTOM_WAYPOINT_VISIBILITY(_, uid)
    UpdatePin(uid)
end

function module:PlayerZoneChanged()
    if not TomTom.profile.worldmap.otherzone then
        UpdateAllPins()
    end
end

function module:OnEnable()
    self:RegisterMessage("TOMTOM_WAYPOINT_ADDED")
    self:RegisterMessage("TOMTOM_WAYPOINT_REMOVED")
    self:RegisterMessage("TOMTOM_WAYPOINT_VISIBILITY")
    hbd.RegisterCallback(self, "PlayerZoneChanged")
    UpdateAllPins()
end

function module:OnDisable()
    self:UnregisterMessage("TOMTOM_WAYPOINT_ADDED")
    self:UnregisterMessage("TOMTOM_WAYPOINT_REMOVED")
    self:UnregisterMessage("TOMTOM_WAYPOINT_VISIBILITY")
    hbd.UnregisterCallback(self, "PlayerZoneChanged")
    ReleaseAllPins()
end

function module:OnSettingChanged(key)
    if key == "theme" or key == "default_iconsize" then
        for uid, frame in pairs(pins) do
            ApplyIcon(frame, uid)
        end
    elseif key == "otherzone" then
        UpdateAllPins()
    end
end

function module:OnProfileChanged()
    for uid, frame in pairs(pins) do
        ApplyIcon(frame, uid)
    end
    UpdateAllPins()
end
