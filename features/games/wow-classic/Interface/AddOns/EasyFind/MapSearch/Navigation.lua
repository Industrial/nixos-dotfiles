local _, ns = ...

local MapSearch = ns.MapSearch
local Utils = ns.Utils
local SetPortraitTextureFromCreatureDisplayID = _G.SetPortraitTextureFromCreatureDisplayID
local L = ns.L
local MapUtils = ns.MapUtils
local MapFrames = ns.MapSearchFrames
local DebugPrint = Utils.DebugPrint

local ipairs = Utils.ipairs
local tsort = Utils.tsort
local pcall = Utils.pcall

local YELLOW_HIGHLIGHT = ns.YELLOW_HIGHLIGHT
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local GameTooltip_Hide = GameTooltip_Hide
local hooksecurefunc = hooksecurefunc

local GetMapInfo = C_Map.GetMapInfo
local GetBestMapForUnit = C_Map.GetBestMapForUnit
local GetMapRectOnMap = C_Map.GetMapRectOnMap
local SetUserWaypoint = C_Map.SetUserWaypoint
local HasUserWaypoint = C_Map.HasUserWaypoint
local ClearUserWaypoint = C_Map.ClearUserWaypoint
local GetDungeonEntrancesForMap = ns.GetDungeonEntrancesForMap
local SetSuperTrackedVignette = C_SuperTrack and C_SuperTrack.SetSuperTrackedVignette


local WAYPOINTS = SetUserWaypoint ~= nil and C_SuperTrack ~= nil and UiMapPoint ~= nil
MapSearch.HasGameWaypoint = WAYPOINTS
local IsOrphanZone = MapUtils.IsOrphanZone

local function PinYAsc(a, b)
    return (a.y or 0) < (b.y or 0)
end

local GetCategoryIcon = MapSearch.GetCategoryIcon

local highlightFrame
local indicatorFrame
local waypointPin
local pinHoverClearsOverride = nil
local activePinState = nil
local routeEndPinned = false
local efTrackedVignetteGUID = nil
local efPlacedWaypoint = false


local efPoint




local efSettingWaypoint = false





local OpenWorldMap = C_Map.OpenWorldMap
local turnAfterFight
local fightWatch = CreateFrame("Frame")
function MapSearch.TurnMap(mapID)
    if not (mapID and WorldMapFrame) then return false end
    if InCombatLockdown() then
        turnAfterFight = mapID
        fightWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
        return false
    end
    if OpenWorldMap then
        OpenWorldMap(mapID)
    else
        WorldMapFrame:SetMapID(mapID)
    end
    return true
end





function MapSearch.OpenMap(mapID)
    if WorldMapFrame and WorldMapFrame:IsShown() then
        if mapID and WorldMapFrame:GetMapID() ~= mapID then return MapSearch.TurnMap(mapID) end
        return true
    end
    if OpenWorldMap and not InCombatLockdown() then OpenWorldMap(mapID) end
    if not (WorldMapFrame and WorldMapFrame:IsShown()) and ToggleWorldMap then
        ToggleWorldMap()
        if mapID and WorldMapFrame and WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() ~= mapID then
            MapSearch.TurnMap(mapID)
        end
    end
    return WorldMapFrame ~= nil and WorldMapFrame:IsShown()
end

fightWatch:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local mapID = turnAfterFight
    turnAfterFight = nil
    if mapID and WorldMapFrame:IsShown() then MapSearch.TurnMap(mapID) end
end)




local WAYPOINT_WAIT_ORDER = { "clear", "place", "quest", "vignette", "track" }
local waypointWaits = {}
function MapSearch.WaypointChange(kind, fn)
    if kind ~= "clear" and WorldMapFrame and WorldMapFrame:IsShown() then
        waypointWaits[kind] = fn
        return
    end
    waypointWaits[kind] = nil
    fn()
end
function MapSearch.DropWaypointChange(kind) waypointWaits[kind] = nil end
local function RunWaypointWaits()
    for _, kind in ipairs(WAYPOINT_WAIT_ORDER) do
        local fn = waypointWaits[kind]
        waypointWaits[kind] = nil
        if fn then fn() end
    end
end




local function EFPlaceWaypoint(point, after)
    if not WAYPOINTS then return end
    MapSearch.WaypointChange("place", function()
        efSettingWaypoint = true
        efPlacedWaypoint = true
        SetUserWaypoint(point)
        efSettingWaypoint = false
        local wp = C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
        efPoint = wp and wp.position and { wp.uiMapID, wp.position.x, wp.position.y } or nil
        if after then after() end
    end)
end


local function StillOurs()
    local wp = efPoint and C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
    return wp ~= nil and wp.position ~= nil and wp.uiMapID == efPoint[1]
        and math.abs(wp.position.x - efPoint[2]) < 0.0005 and math.abs(wp.position.y - efPoint[3]) < 0.0005
end
MapSearch._StillOurs = StillOurs



local function PinMarks(point)
    local s = activePinState
    if not (s and point and s.mapID == point[1]) then return false end
    local function Near(x, y) return x ~= nil and math.abs(x - point[2]) < 0.001 and math.abs(y - point[3]) < 0.001 end
    if Near(s.x, s.y) then return true end
    for _, spot in ipairs(s.instances or {}) do
        if Near(spot.x, spot.y) then return true end
    end
    return false
end

local function EFPlaceWaypointAt(mapID, x, y, after)
    if WAYPOINTS then EFPlaceWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y), after) end
end

local function TrackWaypoint(on)
    if WAYPOINTS then MapSearch.WaypointChange("track", function() C_SuperTrack.SetSuperTrackedUserWaypoint(on) end) end
end
MapSearch.TrackWaypoint = TrackWaypoint




function MapSearch:PlaceUserWaypoint(point)
    EFPlaceWaypoint(point)
end

function MapSearch:PlaceUserWaypointAt(mapID, x, y)
    EFPlaceWaypointAt(mapID, x, y)
end








local function PlaceTrackedWaypoint(mapID, x, y, after)
    if not (mapID and x and y) then return end
    if x < 0 or x > 1 or y < 0 or y > 1 then return end
    EFPlaceWaypointAt(mapID, x, y, after)
    if EasyFind.db.autoTrackPins ~= false then
        TrackWaypoint(true)
    end
    MapSearch:RefreshAllClearButtons()
end



local function GPSNavigates()
    return EasyFind.API.CallAction("gps", "mapClickNavigates") and true or false
end



local function RouteEndsHere(self)
    local dest = EasyFind.API.CallAction("gps", "destination")
    if not dest then return false end
    if routeEndPinned then return true, dest end
    if not (dest.x and self.waypointX and dest.mapID == WorldMapFrame:GetMapID()) then return false end
    return math.abs(dest.x - self.waypointX) < 0.005 and math.abs(dest.y - self.waypointY) < 0.005, dest
end

local function PinEnter(self)
    if self.isLocalSearch then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(GPSNavigates() and L["WP_NAVIGATE"] or L["WP_PLACE"])
        GameTooltip:AddLine(L["WP_DISMISS"], 0.6, 0.6, 0.6)
        GameTooltip:Show()
        return
    end
    MapSearch:ClearActivePinState()
    MapSearch:ClearHighlight()

    local ends, dest = RouteEndsHere(self)
    if ends then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(dest.name or "")
        GameTooltip:AddLine(L["WP_DISMISS_ROUTE"], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end
end





local function PinClick(self, button)
    if button == "RightButton" then
        local ends = RouteEndsHere(self)
        MapSearch:ClearAll()
        if ends then EasyFind.API.CallAction("gps", "clear") end
        return
    end
    if button ~= "LeftButton" or not (self.isLocalSearch and self.waypointX and self.waypointY) then return end
    local x, y, cat = self.waypointX, self.waypointY, self.waypointCategory
    local sel = MapSearch._selected

    if activePinState and activePinState.instances then
        MapSearch:ShowWaypointAt(x, y, self.waypointIcon or (sel and sel.icon), cat, nil, self.waypointDisplayID)
    end
    local viewingMapID = WorldMapFrame:GetMapID()
    if not viewingMapID then return end
    if sel and GPSNavigates() and EasyFind.API.CallAction("gps", "navigate", { name = sel.name, mapID = viewingMapID,
            x = x, y = y, icon = sel.icon, category = sel.category or cat, displayID = sel.displayID }) then
        return
    end
    PlaceTrackedWaypoint(viewingMapID, x, y)
end

function MapSearch:HasActivePinState()
    return activePinState ~= nil
end

function MapSearch:SetActivePinState(state)
    activePinState = state
end

function MapSearch:GetActivePinState()
    return activePinState
end

function MapSearch:ClearActivePinState()
    activePinState = nil
    self._savedPinState = nil
end
local loadingScreenFrame = CreateFrame("Frame")
loadingScreenFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
if WAYPOINTS then
    Utils.RegisterEventIfValid(loadingScreenFrame, "USER_WAYPOINT_UPDATED")
    Utils.RegisterEventIfValid(loadingScreenFrame, "SUPER_TRACKING_CHANGED")
    Utils.RegisterEventIfValid(loadingScreenFrame, "NAVIGATION_DESTINATION_REACHED")
end
loadingScreenFrame:SetScript("OnEvent", function(_, event, isInitialLogin, isReloadingUI)
    if event == "NAVIGATION_DESTINATION_REACHED" then


        if EasyFind.db.autoPinClear ~= false and efPlacedWaypoint then
            MapSearch:ClearAll()
        end
        return
    end

    if event == "USER_WAYPOINT_UPDATED" or event == "SUPER_TRACKING_CHANGED" then
        local currentVig = C_SuperTrack.GetSuperTrackedVignette and C_SuperTrack.GetSuperTrackedVignette()
        if efTrackedVignetteGUID and currentVig ~= efTrackedVignetteGUID then
            efTrackedVignetteGUID = nil
        end






        if WAYPOINTS and not HasUserWaypoint() then
            local gone = efPlacedWaypoint and efPoint
            efPlacedWaypoint, efPoint = false, nil


            if gone and PinMarks(gone) then MapSearch:ClearAll() end
        elseif event == "USER_WAYPOINT_UPDATED" and not efSettingWaypoint and not StillOurs() then
            efPlacedWaypoint, efPoint = false, nil
        end


        if efPlacedWaypoint and EasyFind.db.enableMapSearch ~= false
           and EasyFind.db.autoTrackPins ~= false
           and HasUserWaypoint() and not C_SuperTrack.IsSuperTrackingUserWaypoint() then
            if event == "USER_WAYPOINT_UPDATED" then
                TrackWaypoint(true)
                return
            end
            local isTrackingPin = C_SuperTrack.IsSuperTrackingMapPin and C_SuperTrack.IsSuperTrackingMapPin()
            local isTrackingVignette = C_SuperTrack.GetSuperTrackedVignette and C_SuperTrack.GetSuperTrackedVignette() ~= nil
            local isTrackingQuest = C_SuperTrack.IsSuperTrackingQuest and C_SuperTrack.IsSuperTrackingQuest()
            if not isTrackingPin and not isTrackingVignette and not isTrackingQuest then
                TrackWaypoint(true)
                return
            end
        end
        return
    end

    if isInitialLogin or isReloadingUI then
        return
    end

    Utils.SafeAfter(0, function()
        if ns.MapSearch then
            ns.MapSearch:ClearAll()
            ns.MapSearch:ClearZoneHighlight()
        end
        if ns.Highlight then ns.Highlight:ClearAll() end
    end)
end)



local RING_SPAN = 64 / 40


local function ResizeHighlightBorders(frame)
    local bs  = ns.UIToCanvas(4)
    local pad = ns.UIToCanvas(4)
    local ringSize = math.max(frame:GetWidth(), frame:GetHeight()) * RING_SPAN
    frame.ring:SetSize(ringSize, ringSize)


    frame.top:ClearAllPoints()
    frame.top:SetHeight(bs)
    frame.top:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -pad, 0)
    frame.top:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", pad, 0)

    frame.bottom:ClearAllPoints()
    frame.bottom:SetHeight(bs)
    frame.bottom:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -pad, 0)
    frame.bottom:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", pad, 0)

    frame.left:ClearAllPoints()
    frame.left:SetWidth(bs)
    frame.left:SetPoint("TOPLEFT", frame.top, "BOTTOMLEFT", 0, 0)
    frame.left:SetPoint("BOTTOMLEFT", frame.bottom, "TOPLEFT", 0, 0)

    frame.right:ClearAllPoints()
    frame.right:SetWidth(bs)
    frame.right:SetPoint("TOPRIGHT", frame.top, "BOTTOMRIGHT", 0, 0)
    frame.right:SetPoint("BOTTOMRIGHT", frame.bottom, "TOPRIGHT", 0, 0)
end


local function ApplyHighlightStyle(frame)
    local style = EasyFind.db.mapPinStyle or "glow"
    local box = style == "box"
    frame.top:SetShown(box)
    frame.bottom:SetShown(box)
    frame.left:SetShown(box)
    frame.right:SetShown(box)
    frame.ring:SetShown(style == "glow")
end

function MapSearch:ResizeHighlightBorders(frame)
    ResizeHighlightBorders(frame)
end

function MapSearch:ApplyHighlightStyle(frame)
    ApplyHighlightStyle(frame)
end

function MapSearch:GetMapVisualFrames()
    return waypointPin, highlightFrame, indicatorFrame
end

function MapSearch:SetEasyFindWaypointPlaced(placed)
    efPlacedWaypoint = placed and true or false
end

function MapSearch:CreateHighlightFrame()
    highlightFrame = MapFrames.CreateHighlightBox("EasyFindMapHighlight", WorldMapFrame.ScrollContainer.Child, {
        strata = "TOOLTIP",
        level = 2000,
        size = 64,
        mouse = false,
        hidden = true,
        color = YELLOW_HIGHLIGHT,
        anim = { fromAlpha = 1, toAlpha = 0.4 },
    })


    indicatorFrame = MapFrames.CreateIndicatorFrame("EasyFindMapIndicator", WorldMapFrame.ScrollContainer.Child, {
        strata = "TOOLTIP",
        level = 2000,
        size = ns.ICON_SIZE,
    })

    waypointPin = CreateFrame("Frame", "EasyFindLocationPin", WorldMapFrame.ScrollContainer.Child)
    waypointPin:SetSize(64, 64)
    waypointPin:SetFrameStrata("HIGH")
    waypointPin:SetFrameLevel(2000)
    waypointPin:Hide()

    waypointPin:EnableMouse(true)
    waypointPin:SetScript("OnEnter", PinEnter)
    waypointPin:SetScript("OnLeave", GameTooltip_Hide)
    waypointPin:SetScript("OnMouseUp", PinClick)

    MapFrames.AddWaypointPinVisuals(waypointPin, {
        color = YELLOW_HIGHLIGHT,
        glowSize = 100,
        glowAlpha = 0.8,
        anim = { fromAlpha = 1, toAlpha = 0.3 },
    })

end

local function RestoreActivePinsOnMapShow(self)
    if activePinState then
        local currentMapID = WorldMapFrame:GetMapID()
        local playerMapID = GetBestMapForUnit("player")
        if currentMapID == activePinState.mapID and playerMapID == activePinState.mapID then
            Utils.SafeAfter(0, function()
                if activePinState and activePinState.instances then
                    self:ShowMultipleWaypoints(activePinState.instances)
                elseif activePinState then
                    self:ShowWaypointAt(activePinState.x, activePinState.y,
                        activePinState.icon, activePinState.category, nil, activePinState.displayID)
                end
            end)
        else
            activePinState = nil
        end
    end

    if not activePinState and EasyFind.db.alwaysShowRares then
        Utils.SafeAfter(0, function()
            self:UpdateRareTracking()
        end)
    end
end

local function ClearTransientMapState(self)
    self:ClearHighlight()
    self:ClearZoneHighlight()
    self.pendingWaypoint = nil
end

local function ShowPendingWaypoint(self, waypoint)
    Utils.SafeAfter(0.1, function()
        self:ClearZoneHighlight()




        local pin
        if waypoint.name and self.FindNativePinByName then
            pin = self:FindNativePinByName(waypoint.name)
        end
        if pin and pin:IsShown() then
            self:HighlightPin(pin, waypoint.x, waypoint.y, waypoint.icon, waypoint.category)
        else
            self:ShowWaypointAt(waypoint.x, waypoint.y, waypoint.icon, waypoint.category, nil, waypoint.displayID)
        end
    end)
end

local function TryShowVisiblePendingEntrance(self, savedPendingZone)
    if not (savedPendingZone and self.pendingWaypoint and self.pendingWaypoint.mapID
            and GetDungeonEntrancesForMap) then
        return false
    end

    local waypoint = self.pendingWaypoint
    local currentMapID = WorldMapFrame:GetMapID()
    if waypoint.mapID == currentMapID then return false end

    local entrances = GetDungeonEntrancesForMap(currentMapID)
    if not entrances then return false end

    local ok, left, right, top, bottom = pcall(GetMapRectOnMap, waypoint.mapID, currentMapID)
    if not (ok and left and right and top and bottom
            and (right - left) > 0 and (bottom - top) > 0) then
        return false
    end

    local projX = left + waypoint.x * (right - left)
    local projY = top + waypoint.y * (bottom - top)
    for _, entrance in ipairs(entrances) do
        if entrance.name and entrance.position then
            local dx = projX - entrance.position.x
            local dy = projY - entrance.position.y
            if (dx * dx + dy * dy) < 0.001 then
                DebugPrint("[EasyFind] OnMapChanged - entrance visible on current map, skipping zone nav")
                self.pendingWaypoint = nil
                self:ClearZoneHighlight()
                ShowPendingWaypoint(self, {
                    x = entrance.position.x,
                    y = entrance.position.y,
                    icon = waypoint.icon,
                    category = waypoint.category,
                })
                return true
            end
        end
    end

    return false
end

local function HandlePendingZoneMapChange(self, savedPendingZone, newMapID, newMapInfo)
    if not savedPendingZone then return false end

    local pendingInfo = GetMapInfo(savedPendingZone)
    local arrivedByName = pendingInfo and newMapInfo and pendingInfo.name == newMapInfo.name
    if newMapID == savedPendingZone or arrivedByName then
        DebugPrint("[EasyFind] OnMapChanged - arrived at target zone:", savedPendingZone)
        if self.pendingWaypoint then
            local waypoint = self.pendingWaypoint
            self.pendingWaypoint = nil
            ShowPendingWaypoint(self, waypoint)
        end
    else
        DebugPrint("[EasyFind] OnMapChanged - reguiding to:", savedPendingZone)
        Utils.SafeAfter(0.1, function()
            self:HighlightZoneOnMap(savedPendingZone)
        end)
    end

    return true
end

local function HandlePendingWaypointMapChange(self)
    if not self.pendingWaypoint then return false end

    local waypoint = self.pendingWaypoint
    self.pendingWaypoint = nil
    DebugPrint("[EasyFind] OnMapChanged - showing pending waypoint at:", waypoint.x, waypoint.y)
    ShowPendingWaypoint(self, waypoint)
    return true
end

local function HandleIdleMapChange(self, newMapID)
    DebugPrint("[EasyFind] OnMapChanged - no pending, clearing highlights")
    if activePinState and activePinState.mapID ~= newMapID then
        activePinState = nil
    end
    self:ClearZoneHighlight()
    if EasyFind.db.alwaysShowRares then
        Utils.SafeAfter(0, function() self:UpdateRareTracking() end)
    end
end

local function HookMapModeChanges(self)
    if not WorldMapFrame.IsMaximized then return end

    local function OnMapModeChange()
        self:UpdateBreadcrumbPosition()
    end
    hooksecurefunc(WorldMapFrame, "Maximize", OnMapModeChange)
    hooksecurefunc(WorldMapFrame, "Minimize", OnMapModeChange)
    WorldMapFrame:HookScript("OnShow", OnMapModeChange)
end

local function RegisterVignetteRefresh()

    if not C_VignetteInfo then return end
    local vignetteFrame = CreateFrame("Frame")
    if not Utils.RegisterEventIfValid(vignetteFrame, "VIGNETTES_UPDATED") then return end
    vignetteFrame:SetScript("OnEvent", function()
        if MapSearch._previewing then return end
        if EasyFind.db.alwaysShowRares then
            MapSearch:UpdateRareTracking()
        end
    end)
end






local hiddenGamePins = setmetatable({}, { __mode = "k" })
local PIN_OVERLAP_PX = 20
local function SyncGameWaypointPin()
    local mx, my
    if efPlacedWaypoint and waypointPin and waypointPin:IsVisible() then
        local x, y = waypointPin:GetCenter()
        local s = waypointPin:GetEffectiveScale()
        if x then mx, my = x * s, y * s end
    end
    for pin in WorldMapFrame:EnumeratePinsByTemplate("WaypointLocationPinTemplate") do
        local x, y = pin:GetCenter()
        local s = pin:GetEffectiveScale()
        local under = mx and x and math.abs(x * s - mx) < PIN_OVERLAP_PX and math.abs(y * s - my) < PIN_OVERLAP_PX
        if under and not hiddenGamePins[pin] then
            hiddenGamePins[pin] = true
            pin:SetAlpha(0)
            pin:EnableMouse(false)
        elseif not under and hiddenGamePins[pin] then
            hiddenGamePins[pin] = nil
            pin:SetAlpha(1)
            pin:EnableMouse(true)
        end
    end
end
MapSearch.SyncGameWaypointPin = SyncGameWaypointPin

function MapSearch:HookWorldMap()
    local pinWatch = CreateFrame("Frame")
    local since = 0
    local function WatchPins(_, dt)
        since = since + dt
        if since < 0.05 then return end
        since = 0
        SyncGameWaypointPin()
    end
    WorldMapFrame:HookScript("OnShow", function()
        RestoreActivePinsOnMapShow(self)
        if WAYPOINTS then
            since = 0.05
            pinWatch:SetScript("OnUpdate", WatchPins)
        end
    end)

    WorldMapFrame:HookScript("OnHide", function()
        pinWatch:SetScript("OnUpdate", nil)
        RunWaypointWaits()
        ClearTransientMapState(self)
    end)

    HookMapModeChanges(self)

    hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
        local newMapID = WorldMapFrame:GetMapID()
        local newMapInfo = newMapID and GetMapInfo(newMapID)
        DebugPrint("[EasyFind] OnMapChanged - new map:", newMapInfo and newMapInfo.name or "nil", "ID:", newMapID)
        DebugPrint("[EasyFind] OnMapChanged - pendingZoneHighlight:", self.pendingZoneHighlight)

        local savedPendingZone = self.pendingZoneHighlight

        self:ClearHighlight()
        self:ClearZoneHighlight()

        if self.breadcrumbHighlight then self.breadcrumbHighlight:Hide() end

        if TryShowVisiblePendingEntrance(self, savedPendingZone) then return end
        if HandlePendingZoneMapChange(self, savedPendingZone, newMapID, newMapInfo) then return end
        if HandlePendingWaypointMapChange(self) then return end
        HandleIdleMapChange(self, newMapID)
    end)

    RegisterVignetteRefresh()
end






function MapSearch:NavigateToEntrance(name, x, y, icon, category, targetMapID, directMode, pin)
    local currentMapID = WorldMapFrame:GetMapID()
    local function showAt(px, py)
        local livePin = pin
        if (not livePin or not livePin:IsShown())
           and self.FindNativePinByName and name then
            livePin = self:FindNativePinByName(name)
        end
        if livePin and livePin:IsShown() then
            self:HighlightPin(livePin, px, py, icon, category)
        else
            self:ShowWaypointAt(px, py, icon, category)
        end
    end
    if currentMapID == targetMapID then
        showAt(x, y)
        if directMode then PlaceTrackedWaypoint(targetMapID, x, y) end
        return
    end
    local ex, ey = self:FindEntranceOnMap(name, currentMapID)
    if ex then
        showAt(ex, ey)
        if directMode then PlaceTrackedWaypoint(currentMapID, ex, ey) end
        return
    end
    if IsOrphanZone(targetMapID) or directMode then
        self:ClearZoneHighlight()
        self.pendingWaypoint = {x = x, y = y, icon = icon, category = category, mapID = targetMapID, name = name}
        MapSearch.TurnMap(targetMapID)
        if directMode then PlaceTrackedWaypoint(targetMapID, x, y) end
    else
        self.pendingWaypoint = {x = x, y = y, icon = icon, category = category, mapID = targetMapID, name = name}
        self:HighlightZoneOnMap(targetMapID, name)
    end
end



function MapSearch.SpotsOnMap(instances, mapID)
    local here = {}
    for i = 1, #instances do
        local s = instances[i]
        local m = s.entranceMapID or s.coordMapID
        if s.x and s.y and (not m or m == mapID) then here[#here + 1] = s end
    end
    return here
end







local function WaypointSpot(data)
    local viewed = WorldMapFrame:GetMapID()
    local ex, ey = data.entranceX or data.x, data.entranceY or data.y
    if data.isDungeonEntrance and data.entranceMapID and ex and ey then return data.entranceMapID, ex, ey end
    if data.isZone then return nil end
    local spots = data.allInstances
    if spots and #spots > 1 then
        spots = MapSearch.SpotsOnMap(spots, viewed)
        local nearest = #spots > 0 and MapSearch:GetNearestInstance(spots, viewed)
        if nearest and nearest.x then return nearest.mapID or viewed, nearest.x, nearest.y end
    end
    local spot = spots and #spots == 1 and spots[1] or data
    if not (spot.x and spot.y) then return nil end
    return spot.coordMapID or viewed, spot.x, spot.y
end
MapSearch._WaypointSpot = WaypointSpot

function MapSearch.WaypointOnly()
    return WAYPOINTS and EasyFind.db.mapWaypointOnly == true
end

function MapSearch:SelectResult(data, directOverride)
    if data and data.placeOf then self.ResolvePlace(data) end
    self._previewing = nil
    self._savedPinState = nil
    self._suppressTextChanged = true
    self._selected = data
    if data then
        DebugPrint("[EasyFind] SelectResult: name=", data.name,
            "isZone=", data.isZone, "zoneMapID=", data.zoneMapID,
            "isDungeonEntrance=", data.isDungeonEntrance,
            "entranceMapID=", data.entranceMapID,
            "entranceX=", data.entranceX, "entranceY=", data.entranceY,
            "x=", data.x, "y=", data.y,
            "currentMap=", WorldMapFrame:GetMapID())


        if data.isZoneParent and data.zoneMapID then
            DebugPrint("[EasyFind] SelectResult -> ZONE PARENT branch, navigating to", data.zoneMapID)
            self:ClearZoneHighlight()
            MapSearch.TurnMap(data.zoneMapID)
            return
        end


        if MapSearch.WaypointOnly() then
            local mapID, x, y = WaypointSpot(data)
            if mapID then
                self:ClearAll()
                self:ClearZoneHighlight()
                if WorldMapFrame:IsShown() and mapID ~= WorldMapFrame:GetMapID() then MapSearch.TurnMap(mapID) end


                if WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() == mapID then
                    self:ShowWaypointAt(x, y, data.icon, data.category, nil, data.displayID)
                end
                PlaceTrackedWaypoint(mapID, x, y, function()
                    activePinState = nil
                    MapSearch:ClearHighlight()
                end)
                return
            end
        end

        local directMode
        if directOverride ~= nil then
            directMode = directOverride
        elseif self:IsGlobalSearchActive() then
            directMode = EasyFind.db.globalMapDirectOpen or false
        else
            directMode = EasyFind.db.localMapDirectOpen or false
        end



        pinHoverClearsOverride = not directMode










        if data.isDungeonEntrance and data.entranceMapID
           and data.entranceX and data.entranceY then
            DebugPrint("[EasyFind] SelectResult -> ENTRANCE-FIRST branch, entranceMapID=", data.entranceMapID)
            self:NavigateToEntrance(data.name, data.entranceX, data.entranceY,
                data.entranceIcon or data.icon, data.entranceCategory or data.category,
                data.entranceMapID, directMode, data.pin)
            return
        end


        if data.isZone and data.zoneMapID then



            if IsOrphanZone(data.zoneMapID) then
                DebugPrint("[EasyFind] SelectResult -> ORPHAN ZONE, snapping directly to", data.zoneMapID)
                self:ClearZoneHighlight()
                MapSearch.TurnMap(data.zoneMapID)
            elseif directMode then





                DebugPrint("[EasyFind] SelectResult -> ZONE DIRECT branch, zoneMapID=", data.zoneMapID)
                self:ClearZoneHighlight()
                MapSearch.TurnMap(data.zoneMapID)
            elseif data.entranceX and data.entranceY and data.entranceMapID then
                DebugPrint("[EasyFind] SelectResult -> ZONE+ENTRANCE branch, entranceMapID=", data.entranceMapID)
                self:NavigateToEntrance(data.name, data.entranceX, data.entranceY, data.entranceIcon, data.entranceCategory, data.entranceMapID, directMode)
            else
                DebugPrint("[EasyFind] SelectResult -> ZONE TEACHING branch, zoneMapID=", data.zoneMapID)
                self:HighlightZoneOnMap(data.zoneMapID, data.name)
            end
            return
        end


        if data.isDungeonEntrance and data.entranceMapID then
            DebugPrint("[EasyFind] SelectResult -> DUNGEON ENTRANCE branch, entranceMapID=", data.entranceMapID)
            self:NavigateToEntrance(data.name, data.x, data.y, data.icon, data.category, data.entranceMapID, directMode, data.pin)
            return
        end




        local spots = data.allInstances
        if spots and #spots > 1 then
            spots = MapSearch.SpotsOnMap(spots, WorldMapFrame:GetMapID())
            if #spots == 0 then spots = { data } end
        end
        local spot = spots and #spots == 1 and spots[1] or data
        local spotMapID = not (spots and #spots > 1) and spot.coordMapID
        if spotMapID and spot.x and spot.y and spotMapID ~= WorldMapFrame:GetMapID() then
            self:ClearHighlight()
            self.pendingWaypoint = { x = spot.x, y = spot.y, icon = spot.icon, category = spot.category,
                mapID = spotMapID, name = data.name, displayID = spot.displayID }
            if directMode or IsOrphanZone(spotMapID) then
                self:ClearZoneHighlight()
                MapSearch.TurnMap(spotMapID)
            else
                self:HighlightZoneOnMap(spotMapID, data.name)
            end
            return
        end

        if spots and #spots > 1 then
            self:ShowMultipleWaypoints(spots)
        elseif spots and #spots == 1 then
            local single = spots[1]
            if single.x and single.y then
                self:ShowWaypointAt(single.x, single.y, single.icon, single.category, nil, single.displayID)
                if single.vignetteGUID and SetSuperTrackedVignette then
                    efTrackedVignetteGUID = single.vignetteGUID
                    MapSearch.WaypointChange("vignette", function() SetSuperTrackedVignette(single.vignetteGUID) end)
                end
            end
        elseif data.pin and data.pin:IsShown() then



            self:HighlightPin(data.pin, data.x, data.y, data.icon, data.category)
        elseif data.x and data.y then

            self:ShowWaypointAt(data.x, data.y, data.icon, data.category, nil, data.displayID)

            if data.vignetteGUID and SetSuperTrackedVignette then
                efTrackedVignetteGUID = data.vignetteGUID
                MapSearch.WaypointChange("vignette", function() SetSuperTrackedVignette(data.vignetteGUID) end)
            end
        elseif data.pin then

            self:HighlightPin(data.pin)
        end


        if not self:IsGlobalSearchActive() and directMode then
            local autoX, autoY, autoMapID
            local viewedMap = WorldMapFrame and WorldMapFrame:GetMapID()
            if spots and #spots > 1 then

                local nearest = self:GetNearestInstance(spots, viewedMap)
                if nearest then
                    autoX, autoY = nearest.x, nearest.y
                    autoMapID = nearest.mapID or viewedMap
                end
            elseif spots and #spots == 1 then
                local single = spots[1]
                autoX, autoY = single.x, single.y
                autoMapID = single.mapID or viewedMap
            elseif data.x and data.y then
                autoX, autoY = data.x, data.y
                autoMapID = data.mapID or viewedMap
            end
            if autoX and autoY and autoMapID then




                PlaceTrackedWaypoint(autoMapID, autoX, autoY)
            end
        end
    end
end


function MapSearch:ShowMultipleWaypoints(instances)
    self:ClearHighlight()


    activePinState = {
        mapID = WorldMapFrame:GetMapID(),
        instances = instances,
        isLocal = not MapSearch:IsGlobalSearchActive(),
    }

    local canvas = WorldMapFrame.ScrollContainer.Child
    if not canvas then return end

    local canvasWidth, canvasHeight = canvas:GetSize()
    local userScale = EasyFind.db.iconScale or 0.8
    local ms = ns.MULTI_SCALE

    local iconSize      = ns.UIToCanvas(ns.PIN_SIZE      * ms) * userScale
    local glowSize      = ns.UIToCanvas(ns.PIN_GLOW_SIZE * ms) * userScale
    local highlightSize = ns.UIToCanvas(ns.HIGHLIGHT_SIZE * ms) * userScale
    local indicatorSize     = ns.UIToCanvas(ns.ICON_SIZE     * ms) * userScale
    local indicatorGlowSize = ns.UIToCanvas(ns.ICON_GLOW_SIZE* ms) * userScale


    if not self.extraPins then
        self.extraPins = {}
    end
    if not self.extraHighlights then
        self.extraHighlights = {}
    end
    if not self.extraIndicators then
        self.extraIndicators = {}
    end


    tsort(instances, PinYAsc)


    for i, instance in ipairs(instances) do
        if instance.x and instance.y then
            local pin, highlight, ind

            local baseLevel = 1998 + i * 3

            if i == 1 then

                pin = waypointPin
                highlight = highlightFrame
                ind = indicatorFrame
            else

                if not self.extraPins[i-1] then
                    local extraPin = CreateFrame("Frame", "EasyFindExtraPin"..(i-1), canvas)
                    extraPin:SetFrameStrata("HIGH")
                    extraPin:SetFrameLevel(1999)
                    MapFrames.AddWaypointPinVisuals(extraPin, {
                        color = YELLOW_HIGHLIGHT,
                        glowAlpha = 0.8,
                        anim = { fromAlpha = 1, toAlpha = 0.3 },
                    })

                    extraPin:EnableMouse(true)
                    extraPin:SetScript("OnEnter", PinEnter)
                    extraPin:SetScript("OnLeave", GameTooltip_Hide)
                    extraPin:SetScript("OnMouseUp", PinClick)

                    self.extraPins[i-1] = extraPin
                end
                pin = self.extraPins[i-1]


                if not self.extraHighlights[i-1] then
                    local extraHighlight = MapFrames.CreateHighlightBox("EasyFindExtraHighlight"..(i-1), canvas, {
                        strata = "HIGH",
                        level = 1998,
                        color = YELLOW_HIGHLIGHT,
                        anim = { fromAlpha = 1, toAlpha = 0.4 },
                    })

                    self.extraHighlights[i-1] = extraHighlight
                end
                highlight = self.extraHighlights[i-1]


                if not self.extraIndicators[i-1] then
                    local extraInd = MapFrames.CreateIndicatorFrame("EasyFindExtraIndicator"..(i-1), canvas, {
                        strata = "HIGH",
                        level = 2001,
                        size = ns.ICON_SIZE,
                    })

                    self.extraIndicators[i-1] = extraInd
                end
                ind = self.extraIndicators[i-1]
            end


            highlight:SetFrameStrata("TOOLTIP")
            pin:SetFrameStrata("TOOLTIP")
            ind:SetFrameStrata("TOOLTIP")
            highlight:SetFrameLevel(baseLevel)
            pin:SetFrameLevel(baseLevel + 1)
            ind:SetFrameLevel(baseLevel + 2)


            pin:SetSize(iconSize, iconSize)
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", canvas, "TOPLEFT", instance.x * canvasWidth, -instance.y * canvasHeight)
            pin.waypointX = instance.x
            pin.waypointY = instance.y
            pin.waypointCategory = instance.category
            pin.waypointIcon = instance.icon
            pin.waypointDisplayID = instance.displayID
            if pinHoverClearsOverride == true then
                pin.isLocalSearch = false
            else
                pin.isLocalSearch = not MapSearch:IsGlobalSearchActive()
            end

            local iconTexture = GetCategoryIcon(instance.category)
            if instance.icon then
                iconTexture = instance.icon
            end
            MapFrames.SetPinIcon(pin, iconTexture, instance.displayID ~= nil, instance.category)

            if instance.displayID and SetPortraitTextureFromCreatureDisplayID then
                SetPortraitTextureFromCreatureDisplayID(pin.icon, instance.displayID)
            end

            if pin.glow then
                pin.glow:SetSize(glowSize, glowSize)
            end

            pin:Show()


            highlight:SetSize(highlightSize, highlightSize)
            highlight:ClearAllPoints()
            highlight:SetPoint("CENTER", pin, "CENTER", 0, 0)
            ResizeHighlightBorders(highlight)
            highlight:Show()
            ApplyHighlightStyle(highlight)


            ind:SetSize(indicatorSize, indicatorSize)
            if ind.glow then
                ind.glow:SetSize(indicatorGlowSize, indicatorGlowSize)
            end
            ind:ClearAllPoints()
            ind:SetPoint("BOTTOM", highlight, "TOP", 0, 2)
            ind:Show()

            if ind.animGroup then
                ind:SetAlpha(1)
                ind.animGroup:Play()
            end
            if EasyFind.db.blinkingPins then
                if pin.animGroup then
                    pin:SetAlpha(1)
                    pin.animGroup:Play()
                end
                if highlight.animGroup then
                    highlight:SetAlpha(1)
                    highlight.animGroup:Play()
                end
            end
        end
    end


    if self.extraPins then
        for j = #instances, #self.extraPins do
            if self.extraPins[j] then self.extraPins[j]:Hide() end
            if self.extraHighlights and self.extraHighlights[j] then self.extraHighlights[j]:Hide() end
            if self.extraIndicators and self.extraIndicators[j] then self.extraIndicators[j]:Hide() end
        end
    end



    if self._previewing then
        waypointPin:EnableMouse(false)
        if self.extraPins then
            for _, ep in ipairs(self.extraPins) do
                if ep:IsShown() then ep:EnableMouse(false) end
            end
        end
    end


    if self.autoTrackNextPin then
        self.autoTrackNextPin = nil
        self:TrackActivePin()
    end
end


function MapSearch:ShowWaypointAt(x, y, icon, category, arrowOnly, displayID)
    if not x or not y then return end
    routeEndPinned = false
    self:ClearHighlight()


    activePinState = {
        mapID = WorldMapFrame:GetMapID(),
        x = x, y = y,
        icon = icon, category = category, displayID = displayID,
        isLocal = not MapSearch:IsGlobalSearchActive(),
        arrowOnly = arrowOnly,
    }

    local canvas = WorldMapFrame.ScrollContainer.Child
    if not canvas then return end

    local canvasWidth, canvasHeight = canvas:GetSize()


    local userScale = EasyFind.db.iconScale or 0.8
    local iconSize      = ns.UIToCanvas(ns.PIN_SIZE)       * userScale
    local glowSize      = ns.UIToCanvas(ns.PIN_GLOW_SIZE)  * userScale
    local highlightSize = ns.UIToCanvas(ns.HIGHLIGHT_SIZE)  * userScale
    local indicatorSize     = ns.UIToCanvas(ns.ICON_SIZE)       * userScale
    local indicatorGlowSize = ns.UIToCanvas(ns.ICON_GLOW_SIZE)  * userScale






    if arrowOnly then
        waypointPin:Hide()
        highlightFrame:Hide()
        indicatorFrame:SetSize(indicatorSize, indicatorSize)
        if indicatorFrame.glow then
            indicatorFrame.glow:SetSize(indicatorGlowSize, indicatorGlowSize)
        end
        indicatorFrame:ClearAllPoints()
        indicatorFrame:SetPoint("BOTTOM", canvas, "TOPLEFT",
            canvasWidth * x, -canvasHeight * y + 2)
        indicatorFrame:SetAlpha(1)
        indicatorFrame:Show()
        if indicatorFrame.animGroup then
            indicatorFrame.animGroup:Stop()
            indicatorFrame.animGroup:Play()
        end
        self:RefreshAllClearButtons()
        return
    end


    waypointPin:SetSize(iconSize, iconSize)
    waypointPin.glow:SetSize(glowSize, glowSize)


    local iconTexture = GetCategoryIcon(category or "unknown")
    if icon then
        iconTexture = icon
    end
    MapFrames.SetPinIcon(waypointPin, iconTexture, displayID ~= nil, category)
    if displayID and SetPortraitTextureFromCreatureDisplayID then
        SetPortraitTextureFromCreatureDisplayID(waypointPin.icon, displayID)
    end
    waypointPin:ClearAllPoints()
    waypointPin:SetPoint("CENTER", canvas, "TOPLEFT", canvasWidth * x, -canvasHeight * y)
    waypointPin.waypointX = x
    waypointPin.waypointY = y
    if pinHoverClearsOverride == true then
        waypointPin.isLocalSearch = false
    else
        waypointPin.isLocalSearch = not MapSearch:IsGlobalSearchActive()
    end
    waypointPin:Show()
    if self._previewing then
        waypointPin:EnableMouse(false)
    end


    highlightFrame:SetSize(highlightSize, highlightSize)
    highlightFrame:ClearAllPoints()
    highlightFrame:SetPoint("CENTER", waypointPin, "CENTER", 0, 0)
    ResizeHighlightBorders(highlightFrame)
    highlightFrame:Show()
    ApplyHighlightStyle(highlightFrame)




    indicatorFrame:SetSize(indicatorSize, indicatorSize)
    indicatorFrame.glow:SetSize(indicatorGlowSize, indicatorGlowSize)
    indicatorFrame:ClearAllPoints()
    indicatorFrame:SetPoint("BOTTOM", highlightFrame, "TOP", 0, 2)
    indicatorFrame:SetAlpha(1)
    indicatorFrame:Show()

    if indicatorFrame.animGroup then
        indicatorFrame.animGroup:Stop()
        indicatorFrame.animGroup:Play()
    end
    if EasyFind.db.blinkingPins then
        if waypointPin.animGroup then waypointPin.animGroup:Play() end
        if highlightFrame.animGroup then highlightFrame.animGroup:Play() end
    end


    if self.autoTrackNextPin then
        self.autoTrackNextPin = nil
        self:TrackActivePin()
    end



    self:RefreshAllClearButtons()
end





function MapSearch:PinRouteEnd(dest, x, y)
    if self._previewing or not (dest and x and y) then return end
    pinHoverClearsOverride = false
    self:ShowWaypointAt(x, y, dest.icon, dest.category, nil, dest.displayID)
    routeEndPinned = true
end


function MapSearch:ClearRouteEnd()
    if not routeEndPinned then return end
    routeEndPinned = false
    self:ClearAll()
end



function MapSearch:HideRouteEnd()
    if not routeEndPinned then return end
    routeEndPinned = false
    activePinState = nil
    self:ClearHighlight()
    self:RefreshAllClearButtons()
end

function MapSearch:RefreshAllClearButtons()
    local frames = {
        _G["EasyFindSearchFrame"],
    }
    for _, f in ipairs(frames) do
        if f and f.UpdateClearButtonVisibility then
            f.UpdateClearButtonVisibility()
        end
    end
end

function MapSearch:ClearAll()
    activePinState = nil
    routeEndPinned = false
    self:ClearHighlight()

    MapSearch.DropWaypointChange("place")

    if efPlacedWaypoint then
        efPlacedWaypoint, efPoint = false, nil
        TrackWaypoint(false)
        if WAYPOINTS then
            MapSearch.WaypointChange("clear", function() if HasUserWaypoint() then ClearUserWaypoint() end end)
        end
    end

    self:RefreshAllClearButtons()
end


function MapSearch:ClearPinAt(mapID, x, y)
    local s = activePinState
    if not (s and s.x and x and s.mapID == mapID) then return end
    if math.abs(s.x - x) > 0.001 or math.abs(s.y - y) > 0.001 then return end
    self:ClearAll()
end

