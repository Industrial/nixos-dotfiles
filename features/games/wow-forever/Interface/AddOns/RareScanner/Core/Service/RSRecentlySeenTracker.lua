-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local ADDON_NAME, private = ...

local RSRecentlySeenTracker = private.NewLib("RareScannerRecentlySeenTracker")

-- RareScanner database libraries
local RSConfigDB = private.ImportLib("RareScannerConfigDB")
local RSNpcDB = private.ImportLib("RareScannerNpcDB")
local RSGeneralDB = private.ImportLib("RareScannerGeneralDB")
local RSContainerDB = private.ImportLib("RareScannerContainerDB")

-- RareScanner internal libraries
local RSConstants = private.ImportLib("RareScannerConstants")
local RSLogger = private.ImportLib("RareScannerLogger")
local RSUtils = private.ImportLib("RareScannerUtils")
local RSTimeUtils = private.ImportLib("RareScannerTimeUtils")
local RSProvider = private.ImportLib("RareScannerProvider")
local RSMinimap

-- Timers
local RESET_RECENTLY_SEEN_TIMER

---============================================================================
-- Tracks notifications
---============================================================================

local recently_seen_entities = {}
local ping_animations = {}
local VIGNETTE_ID_SEPARATOR = "-"

local function InitResetRecentlySeenTimer()
	if (RESET_RECENTLY_SEEN_TIMER) then
		return
	end
	
	RESET_RECENTLY_SEEN_TIMER = C_Timer.NewTicker(RSConstants.CHECK_RESET_RECENTLY_SEEN_TIMER, function()
		if (not RSMinimap) then
			RSMinimap = private.ImportLib("RareScannerMinimap")
		end

		local refreshWorldMap = false
		for entityID, entityInfo in pairs (recently_seen_entities) do
			local currenTime = time()
			
			-- If its an entity that spawns only in one spot
			if (type(entityInfo) == "number") then
				if (currenTime > (entityInfo + RSConstants.RECENTLY_SEEN_RESET_TIMER)) then
					--RSLogger:PrintDebugMessage(string.format("ResetRecentlySeen[%s] (limpiado automatico mono)", entityID))
					recently_seen_entities[entityID] = nil
					RSGeneralDB.DeleteRecentlySeen(entityID)
					RSMinimap.RefreshEntityState(entityID)
					refreshWorldMap = true
				end			
			-- If its an entity that spawns in multiple spots at the same time
			else
				for xy, info in pairs (entityInfo) do
					local RESET_TIMER = RSConstants.RECENTLY_SEEN_RESET_TIMER
					local isInInstance, _ = IsInInstance()
					
					-- In instances keep showing the icons longer
					if (isInInstance) then
						RESET_TIMER = RSConstants.RECENTLY_SEEN_INSTANCE_RESET_TIMER
					end
					
					if (currenTime > (entityInfo[xy].time + RESET_TIMER)) then
						if (RSUtils.GetTableLength(recently_seen_entities[entityID]) == 1) then
							recently_seen_entities[entityID] = nil
							--RSLogger:PrintDebugMessage(string.format("ResetRecentlySeen[%s] (limpiado automtatico multi/last)", entityID))
							RSGeneralDB.DeleteRecentlySeen(entityID)
							RSMinimap.RefreshEntityState(entityID)
							refreshWorldMap = true
							break;
						else
							recently_seen_entities[entityID][xy] = nil
							--RSLogger:PrintDebugMessage(string.format("ResetRecentlySeen[%s] (limpiado automtatico  multi)", entityID))
							RSMinimap.RefreshEntityState(entityID)
							refreshWorldMap = true
						end
					end
				end
			end
		end
		
		if (refreshWorldMap and WorldMapFrame:IsShown()) then
			RSProvider.RefreshAllDataProviders()
		end
	end)
end

function RSRecentlySeenTracker.AddRecentlySeen(entityID, atlasName, isNavigating)
	if (not entityID) then
		return
	end
	
	if (isNavigating) then
		return
	end
	
	-- Initializes timer
	InitResetRecentlySeenTimer()
	
	local currentTime = time()
	
	-- Extracts info from internal database
	local entityInfo = RSGeneralDB.GetAlreadyFoundEntity(entityID, atlasName)
	if (not entityInfo) then
		return
	end
	
	local shouldAnimate = false
	
	-- If spawning in multiple places at the same time stores also the coordinates
	if (RSNpcDB.IsMultiZoneSpawn(entityID) or RSContainerDB.IsMultiZoneSpawn(entityID)) then
		-- Extracts info from internal database
		if (not recently_seen_entities[entityID]) then
			recently_seen_entities[entityID] = {}
		end
		
		local xy = entityInfo.coordX.."_"..entityInfo.coordY
		recently_seen_entities[entityID][xy] = {}
		recently_seen_entities[entityID][xy].x = entityInfo.coordX
		recently_seen_entities[entityID][xy].y = entityInfo.coordY
		recently_seen_entities[entityID][xy].mapID = entityInfo.mapID
		recently_seen_entities[entityID][xy].atlasName = atlasName
		recently_seen_entities[entityID][xy].time = currentTime
		
		RSGeneralDB.SetRecentlySeen(entityID)
		shouldAnimate = true
		--RSLogger:PrintDebugMessage(string.format("AddRecentlySeen[%s] (multi) [%s]", entityID, RSTimeUtils.TimeStampToClock(currentTime)))
	-- Otherwise stores only the time if it isn't already seen
	elseif (not recently_seen_entities[entityID]) then
		recently_seen_entities[entityID] = currentTime
		RSGeneralDB.SetRecentlySeen(entityID)
		shouldAnimate = true
		--RSLogger:PrintDebugMessage(string.format("AddRecentlySeen[%s] (mono) [%s]", entityID, RSTimeUtils.TimeStampToClock(currentTime)))
	end
	
	-- Adds to the list to show ping animation
	if (shouldAnimate) then
		if ((RSConstants.IsNpcAtlas(atlasName) and RSConfigDB.IsShowingAnimationForNpcs() and RSConfigDB.GetAnimationForNpcs() ~= RSConstants.MAP_ANIMATIONS_ON_CLICK) or 
				(RSConstants.IsContainerAtlas(atlasName) and RSConfigDB.IsShowingAnimationForContainers() and RSConfigDB.GetAnimationForContainers() ~= RSConstants.MAP_ANIMATIONS_ON_CLICK) or
				(RSConstants.IsEventAtlas(atlasName) and RSConfigDB.IsShowingAnimationForEvents() and RSConfigDB.GetAnimationForEvents() ~= RSConstants.MAP_ANIMATIONS_ON_CLICK)) then
			RSRecentlySeenTracker.AddPendingAnimation(entityID, entityInfo.mapID, entityInfo.coordX, entityInfo.coordY)
		end
	end
end

function RSRecentlySeenTracker.RemoveRecentlySeen(entityID)
	local entityInfo = recently_seen_entities[entityID]
	
	if (not entityInfo) then
		--RSLogger:PrintDebugMessage(string.format("RemoveRecentlySeen[%s] (no encontrada la entidad en recently_seen_entities)", entityID))
		return nil
	end
	
	-- If its an entity that spawns only in one spot
	if (type(entityInfo) == "number") then
		--RSLogger:PrintDebugMessage(string.format("RemoveRecentlySeen[%s] (mono)", entityID))
		recently_seen_entities[entityID] = nil
		RSGeneralDB.DeleteRecentlySeen(entityID)
		return nil
	end
	
	-- If its an entity that spawns in multiple spots at the same time
	-- Calculates the distance in yards between all of them and the player in a single pass (0 GC allocations)
	local minDistance = nil
	local bestXY = nil
	local totalEntries = 0

	for xy, info in pairs (entityInfo) do
		totalEntries = totalEntries + 1
		local playerMapPosition = C_Map.GetPlayerMapPosition(info.mapID, "player")
		if (playerMapPosition) then
			local playerX, playerY = playerMapPosition:GetXY()
			local fixX = RSUtils.FixCoord(info.x)
			local fixY = RSUtils.FixCoord(info.y)
			local distanceYards = RSUtils.GetDistanceInYards(info.mapID, playerX, playerY, fixX, fixY)

			-- Fallback: If map world size is not available (distance == 0 but coords differ)
			if (distanceYards == 0 and (playerX ~= fixX or playerY ~= fixY)) then
				local rawDistance = RSUtils.DistanceBetweenCoords(playerX, fixX, playerY, fixY)
				if (rawDistance and rawDistance > 0) then
					distanceYards = rawDistance * 2000
				end
			end

			if (not minDistance or distanceYards < minDistance) then
				minDistance = distanceYards
				bestXY = xy
			end
		end
	end

	-- If for whatever reason it couldnt get the players coordinates it will be empty
	if (not bestXY or not minDistance) then
		--RSLogger:PrintDebugMessage("RemoveRecentlySeen. No se han obtenido las coordenadas del jugador con lo que se desconoce las coordenadas del contenedor")
		return nil
	end

	-- Avoid hiding incorrect icons (player must be close to the container, max 20 yards)
	local MAX_CONTAINER_DISTANCE_YARDS = 10
	if (minDistance > MAX_CONTAINER_DISTANCE_YARDS) then
		RSLogger:PrintDebugMessage(string.format("RemoveRecentlySeen[distancia=%s (yardas)] (No devuelve contenedor por no haberse encontrado uno lo suficientemente cerca)", RSUtils.Round(minDistance, 2)))
		return nil
	else
		RSLogger:PrintDebugMessage(string.format("RemoveRecentlySeen[distancia=%s (yardas)] (Encontrado como el mas cercano)", RSUtils.Round(minDistance, 2)))
	end

	local x, y = strsplit("_", bestXY)
	if (totalEntries == 1) then
		RSLogger:PrintDebugMessage(string.format("RemoveRecentlySeen[%s,x=%s,y=%s] (multi/last)", entityID, x, y))
		recently_seen_entities[entityID] = nil
		RSGeneralDB.DeleteRecentlySeen(entityID)
	else
		RSLogger:PrintDebugMessage(string.format("RemoveRecentlySeen[%s,x=%s,y=%s] (multi)", entityID, x, y))
		recently_seen_entities[entityID][bestXY] = nil
	end

	return x, y
end

function RSRecentlySeenTracker.IsRecentlySeen(entityID, x, y)
	if (not entityID) then
		return false
	end
	
	-- If it isnt cached in this session check database 
	local entityInfo = recently_seen_entities[entityID]
	if (not entityInfo) then
		return RSGeneralDB.IsRecentlySeen(entityID)
	end
	
	-- If its an entity that spawns only in one spot
	if (type(entityInfo) == "number") then
		return true
	end
	
	-- If its an entity that spawns in multiple spots then check all the coordinates
	for _, info in pairs (entityInfo) do
		if (info.x == x and info.y == y) then
			return true
		end
	end

	-- Otherwise it isnt recently seen
	return false
end

function RSRecentlySeenTracker.GetAllRecentlySeenSpots()
	return recently_seen_entities
end

---============================================================================
-- World map animations for recently seen entities
---============================================================================

function RSRecentlySeenTracker.ShouldPlayAnimation(entityID, mapID, x, y)
	if (not entityID) then
		return false
	end
	
	--RSLogger:PrintDebugMessage(string.format("ShouldPlayAnimation[%s][%s][%s][%s]", entityID, mapID and mapID or "mapID", x and x or "x", y and y or "y"))
	
	local pingAnimationInfo = ping_animations[tonumber(entityID)]
	if (not pingAnimationInfo) then
		return false
	elseif (pingAnimationInfo == true) then
		return true
	end
	
	if (not mapID or not x or not y) then
		return true
	end

	for xy, info in pairs (pingAnimationInfo) do
		if (info.mapID == tostring(mapID) and info.x == tostring(x) and info.y == tostring(y)) then
			--RSLogger:PrintDebugMessage(string.format("ShouldPlayAnimation[%s] (multi) [%s]", entityID, xy))
			return true
		end
	end
	
	return false
end

function RSRecentlySeenTracker.AddPendingAnimation(entityID, mapID, x, y, refreshWorldMap)	
	if (not ping_animations[entityID]) then
		ping_animations[entityID] = {}
	end
	
	--RSLogger:PrintDebugMessage(string.format("AddPendingAnimation[%s][%s][%s][%s]", entityID, mapID and mapID or "mapID", x and x or "x", y and y or "y"))
	
	local multiSpawn = RSNpcDB.IsMultiZoneSpawn(entityID) or RSContainerDB.IsMultiZoneSpawn(entityID)
	
	if (multiSpawn and mapID and mapID ~= "" and x and y) then
		-- In case it couldn't get the map and coordinates the first time
		if (ping_animations[entityID] == true) then
			ping_animations[entityID] = {}
		end
		
		local xy = x.."_"..y		
		ping_animations[entityID][xy] = {}
		ping_animations[entityID][xy].x = RSUtils.tostring(x)
		ping_animations[entityID][xy].y = RSUtils.tostring(y)
		ping_animations[entityID][xy].mapID = RSUtils.tostring(mapID)
	else
		ping_animations[entityID] = true
	end
	
	if (refreshWorldMap and WorldMapFrame:IsShown()) then
		RSProvider.RefreshAllDataProviders()
	end
end

function RSRecentlySeenTracker.DeletePendingAnimation(entityID, mapID, x, y, refreshWorldMap)
	if (not entityID) then
		return
	end
	
	--RSLogger:PrintDebugMessage(string.format("DeletePendingAnimation[%s]", entityID))
	
	local entityIDnumber = tonumber(entityID)
	if (x and y and type(ping_animations[entityIDnumber]) == "table") then
		local xy = x.."_"..y
		if (RSUtils.GetTableLength(ping_animations[entityIDnumber]) == 1) then
			ping_animations[entityIDnumber] = nil
		else
			ping_animations[entityIDnumber][xy] = nil
		end
	else
		ping_animations[entityIDnumber] = nil
	end
end