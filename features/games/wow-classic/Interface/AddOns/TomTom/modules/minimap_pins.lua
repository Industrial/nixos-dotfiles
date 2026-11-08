--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
--
--  All Rights Reserved
----------------------------------------------------------------------------]]

-- The minimap pins of the active waypoints. A pin frame exists only while
-- its pin shows: a hidden or turned-off pin goes back to the pool and out
-- of HereBeDragons, so the library cannot show it again (B20).

local _, addon = ...
local TomTom = addon
local L = addon.L
local hbd = addon.hbd
local hbdp = LibStub("HereBeDragons-Pins-2.0")
addon.private = addon.private or {}
local private = addon.private

local module = {
    settingsKey = "minimap",
    defaults = {
        enable = true,
        otherzone = true,
        tooltip = true,
        menu = true,
        default_iconsize = 16,
        default_icon = "Interface\\AddOns\\TomTom\\Images\\GoldGreenDot",
        theme = "modern-green",
    },
}
private.AddModule(module, "MinimapPins")

local THROTTLE = 0.1
local SQUARE_HALF = math.sqrt(0.5)
local RAD_135 = math.rad(135)

local pins = {}       -- uid -> frame
local pool = {}
local allFrames = {}  -- every frame made, for ReparentMinimap
local parent = Minimap
local frameCount = 0

local function Theme()
    return TomTom.profile.minimap.theme
end

local function DotTexture()
    return addon.waypointThemeRegistry:GetThemeDotTexture(Theme())
end

local function ArrowTexture()
    return addon.waypointThemeRegistry:GetThemeArrowTexture(Theme())
end

local function ArrowSize()
    return addon.waypointThemeRegistry:GetThemeArrowSize(Theme())
end

private.AddSettingsSection{
    page = "minimap", pageName = L["Minimap"], pageOrder = 20,
    settingsKey = "minimap",
    feature = {name = L["Enable minimap waypoints"]},
    rows = {
        {type = "text", text = L["TomTom can display multiple waypoint arrows on the minimap.  These options control the display of these waypoints"]},
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
        -- The text row has one image, so the arrow is texture markup.
        {type = "preview", watch = {"theme"},
         imageFunc = function() return {texture = DotTexture(), width = 20, height = 20} end,
         textFunc = function() return ("|T%s:20:20|t"):format(ArrowTexture()) end},
        {type = "range", key = "default_iconsize", name = L["Minimap Icon Size"],
         tooltip = L["This setting allows you to control the default size of the minimap icon. "],
         min = 4, max = 64, step = 2},
    },
}

-- Minimap addons call ReparentMinimap on each addon that has minimap
-- pins (integrations.md I10), so it exists also while the module is off.
function TomTom:ReparentMinimap(minimap)
    parent = minimap
    for _, frame in ipairs(allFrames) do
        frame:SetParent(minimap)
    end
end

--[[--------------------------------------------------------------------------
--  Pin frames
----------------------------------------------------------------------------]]

local function Pin_OnUpdate(self, elapsed)
    local angle, dist = hbdp:GetVectorToIcon(self)
    if not dist then
        self:Hide()
        return
    end

    self.elapsed = self.elapsed + elapsed
    if self.elapsed < THROTTLE then return end
    self.elapsed = 0

    if hbdp:IsMinimapIconOnEdge(self) then
        self.icon:Hide()
        self.arrow:Show()

        angle = angle + RAD_135
        if GetCVar("rotateMinimap") == "1" then
            angle = angle - GetPlayerFacing()
        end

        local sin, cos = math.sin(angle) * SQUARE_HALF, math.cos(angle) * SQUARE_HALF
        self.arrow:SetTexCoord(0.5-sin, 0.5+cos, 0.5+cos, 0.5+sin, 0.5-cos, 0.5-sin, 0.5+sin, 0.5-cos)
    else
        self.icon:Show()
        self.arrow:Hide()
    end
end

local function CreatePin()
    frameCount = frameCount + 1
    -- Minimap addons find the pins by this global name.
    local frame = CreateFrame("Button", ("TTMinimapButton%d"):format(frameCount), parent)
    frame:SetSize(30, 30)
    frame:RegisterForClicks("RightButtonUp")

    frame.icon = frame:CreateTexture(nil, "OVERLAY")
    frame.icon:SetPoint("CENTER", 0, 0)
    frame.icon:SetBlendMode("BLEND")
    frame.icon:SetTexelSnappingBias(0)
    frame.icon:SetSnapToPixelGrid(false)

    frame.arrow = frame:CreateTexture(nil, "OVERLAY")
    frame.arrow:SetPoint("CENTER", 0, 0)
    frame.arrow:Hide()
    frame.arrow:SetTexelSnappingBias(0)
    frame.arrow:SetSnapToPixelGrid(false)

    frame:SetScript("OnEnter", private.Pin_OnEnter)
    frame:SetScript("OnLeave", private.Pin_OnLeave)
    frame:SetScript("OnClick", private.Pin_OnClick)
    frame:SetScript("OnUpdate", Pin_OnUpdate)

    table.insert(allFrames, frame)
    return frame
end

-- The waypoint can give its own icon; else the theme gives it.
local function ApplyIcon(frame, uid)
    if uid.minimap_displayID then
        SetPortraitTextureFromCreatureDisplayID(frame.icon, uid.minimap_displayID)
    else
        frame.icon:SetTexture(uid.minimap_icon or DotTexture())
    end
    local size = uid.minimap_icon_size or TomTom.profile.minimap.default_iconsize
    frame.icon:SetSize(size, size)

    frame.arrow:SetTexture(uid.minimap_icon or ArrowTexture())
    local arrowSize = ArrowSize()
    frame.arrow:SetSize(arrowSize, arrowSize)
end

-- World coordinates, because HereBeDragons shows a pin added with a map
-- only on that map and its parents: never in another zone, and not in a
-- cave of its zone (B30). The otherzone filter is WantsPin alone.
local function AcquirePin(uid)
    local x, y, instanceID = hbd:GetWorldCoordinatesFromZone(uid[2], uid[3], uid[1])
    if not x then return end
    local frame = table.remove(pool) or CreatePin()
    local display = private.GetWaypointDisplay(uid)
    frame.uid = uid
    frame.callbacks = display.callbacks and display.callbacks.minimap
    -- The first OnUpdate places the icon or the arrow at once.
    frame.elapsed = THROTTLE
    ApplyIcon(frame, uid)
    pins[uid] = frame
    hbdp:AddMinimapIconWorld(TomTom, frame, instanceID, x, y, true)
    return frame
end

local function ReleasePin(uid)
    local frame = pins[uid]
    if not frame then return end
    hbdp:RemoveMinimapIcon(TomTom, frame)
    frame:Hide()
    frame.uid = nil
    frame.callbacks = nil
    pins[uid] = nil
    table.insert(pool, frame)
end

local function WantsPin(uid)
    return module:IsEnabled()
        and private.ShowsPin(uid, "minimap")
        and (TomTom.profile.minimap.otherzone or private.InPlayerZone(uid[1]))
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
    if not TomTom.profile.minimap.otherzone then
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
