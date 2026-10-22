 -----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local ADDON_NAME, private = ...

local RSWaypoints = private.NewLib("RareScannerWaypoints")

-- RareScanner database libraries
local RSGeneralDB = private.ImportLib("RareScannerGeneralDB")
local RSConfigDB = private.ImportLib("RareScannerConfigDB")

-- RareScanner general libraries
local RSUtils = private.ImportLib("RareScannerUtils")

-- Addons integrations
local RSTomtom = private.ImportLib("RareScannerTomtom")
local RSWaypointUI = private.ImportLib("RareScannerWaypointUI")

---============================================================================
-- Ingame waypoints
---============================================================================

function RSWaypoints.AddIngameWaypoint(mapID, x, y)
	if (mapID and mapID ~= "" and x and y) then
		local fixedX = RSUtils.FixCoord(x)
		local fixedY = RSUtils.FixCoord(y)
		
		if (fixedX and fixedY) then
			C_Map.ClearUserWaypoint();
			C_SuperTrack.SetSuperTrackedUserWaypoint(false);
			
			local uiMapPoint = UiMapPoint.CreateFromCoordinates(mapID, fixedX, fixedY);
			if (uiMapPoint) then
				C_Map.SetUserWaypoint(uiMapPoint);
				C_SuperTrack.SetSuperTrackedUserWaypoint(true);
			end
		end
	end
end

function RSWaypoints.AddChatMapWaypoint(mapID, x, y, name)
	-- Ingame waypoints
	if (RSConfigDB.IsAddingchatIngameWaypoints()) then
		RSWaypoints.AddIngameWaypoint(mapID, x, y)
	end
	
	-- Addons waypoints
	RSTomtom.AddChatWaypoint(mapID, x, y, name)
	RSWaypointUI.AddChatWaypoint(mapID, x, y, name)
end

function RSWaypoints.AddWorldMapWaypoint(mapID, x, y, name)
	-- Ingame waypoints
	if (RSConfigDB.IsAddingWorldMapIngameWaypoints()) then
		RSWaypoints.AddIngameWaypoint(mapID, x, y)
	end
	
	-- Addons waypoints
	RSTomtom.AddWorldMapWaypoint(mapID, x, y, name)
	RSWaypointUI.AddWorldMapWaypoint(mapID, x, y, name)
end

function RSWaypoints.AddAutomaticWaypoint(mapID, x, y, name)
	-- Ingame waypoints
	if (RSConfigDB.IsWaypointsSupportEnabled() and RSConfigDB.IsAddingWaypointsAutomatically()) then
		RSWaypoints.AddIngameWaypoint(mapID, x, y)
	end
	
	-- Addons waypoints
	RSTomtom.AddAutomaticWaypoint(mapID, x, y, name)
	RSWaypointUI.AddAutomaticWaypoint(mapID, x, y, name)
end

function RSWaypoints.AddWaypoint(mapID, x, y, name)
	-- Ingame waypoints
	if (RSConfigDB.IsWaypointsSupportEnabled()) then
		RSWaypoints.AddIngameWaypoint(mapID, x, y)
	end
	
	-- Addons waypoints
	RSTomtom.AddWaypoint(mapID, x, y, name)
	RSWaypointUI.AddWaypoint(mapID, x, y, name)
end

function RSWaypoints.RemoveCurrentWaypoints()
	-- Addons waypoints
	RSTomtom.RemoveCurrentWaypoints()
	RSWaypointUI.RemoveCurrentWaypoints()
end