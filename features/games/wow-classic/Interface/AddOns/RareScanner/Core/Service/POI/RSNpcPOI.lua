-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local ADDON_NAME, private = ...

local RSNpcPOI = private.NewLib("RareScannerNpcPOI")

-- RareScanner database libraries
local RSNpcDB = private.ImportLib("RareScannerNpcDB")
local RSGeneralDB = private.ImportLib("RareScannerGeneralDB")
local RSAchievementDB = private.ImportLib("RareScannerAchievementDB")
local RSConfigDB = private.ImportLib("RareScannerConfigDB")
local RSMapDB = private.ImportLib("RareScannerMapDB")
local RSProfessionDB = private.ImportLib("RareScannerProfessionDB")

-- RareScanner internal libraries
local RSConstants = private.ImportLib("RareScannerConstants")
local RSLogger = private.ImportLib("RareScannerLogger")
local RSTimeUtils = private.ImportLib("RareScannerTimeUtils")
local RSUtils = private.ImportLib("RareScannerUtils")

-- RareScanner services
local RSRecentlySeenTracker = private.ImportLib("RareScannerRecentlySeenTracker")


---============================================================================
-- Dreamsurge NPCs POIs
---- NPCs that are part of a dreamsurge event (Dragonflight)
---============================================================================

local function findClosestSpot(npcID, mapID, poiX, poiY)
	local mapNpcInfo = RSNpcDB.GetInternalNpcInfoByMapID(npcID, mapID)
	if (not mapNpcInfo or not mapNpcInfo.overlay) then
		return poiX, poiY
	end

	local minDistance = nil
	local bestX, bestY = nil, nil

	for _, coordinatePair in ipairs(mapNpcInfo.overlay) do
		local coordx, coordy = strsplit("-", coordinatePair)
		local distance = RSUtils.DistanceBetweenCoords(coordx, poiX, coordy, poiY)
		if (distance and distance > 0.01) then
			if (not minDistance or distance < minDistance) then
				minDistance = distance
				bestX = coordx
				bestY = coordy
			end
		end
	end

	if (bestX and bestY) then
		return bestX, bestY
	end

	return poiX, poiY
end

local function GetMinieventXY(npcID, mapID, atlasName)
	local areaPOIs = GetAreaPOIsForPlayerByMapIDCached(mapID);
  	for _, areaPoiID in ipairs(areaPOIs) do
    	local poiInfo = C_AreaPoiInfo.GetAreaPOIInfo(mapID, areaPoiID);
    	if (poiInfo) then
	    	local isPrimaryMapForPOI = poiInfo.isPrimaryMapForPOI
    		local x, y = poiInfo.position:GetXY()
	    	
	  		if (isPrimaryMapForPOI and poiInfo.atlasName == atlasName) then
		      	return findClosestSpot(npcID, mapID, x, y)
	    	end
	    end
	end
end

---============================================================================
-- Storm invasion NPCs POIs
---- NPCs that are part of a storm invasion event (Dragonflight)
---============================================================================

local function GetStormInvasionAtlasName(minieventID)
	if (not minieventID) then
		return nil
	end
	
	if (minieventID == RSConstants.DRAGONFLIGHT_STORM_INVASTION_FIRE_MINIEVENT) then
    	return RSConstants.FIRE_STORM_ATLAS 
  	elseif (minieventID == RSConstants.DRAGONFLIGHT_STORM_INVASTION_WATER_MINIEVENT) then
    	return RSConstants.WATER_STORM_ATLAS 
  	elseif (minieventID == RSConstants.DRAGONFLIGHT_STORM_INVASTION_EARTH_MINIEVENT) then
    	return RSConstants.EARTH_STORM_ATLAS 
  	elseif (minieventID == RSConstants.DRAGONFLIGHT_STORM_INVASTION_AIR_MINIEVENT) then
    	return RSConstants.AIR_STORM_ATLAS
  	end
  
  	return nil
end

local function GetStormInvasionXY(npcID, mapID, minieventID)
	local npcStormAtlasName = GetStormInvasionAtlasName(minieventID) 
  	if (not npcStormAtlasName) then
    	return nil
  	end
   
  	local areaPOIs = GetAreaPOIsForPlayerByMapIDCached(mapID);
  	for _, areaPoiID in ipairs(areaPOIs) do
    	local poiInfo = C_AreaPoiInfo.GetAreaPOIInfo(mapID, areaPoiID);
    	if (poiInfo) then
	    	local isPrimaryMapForPOI = poiInfo.isPrimaryMapForPOI
    		local x, y = poiInfo.position:GetXY()
	    	
	    	-- Fix primatyMapForPOI for event in Cobalt Galery and The primalist future
	    	if (not isPrimaryMapForPOI) then
	    		if (mapID == RSConstants.THE_AZURE_SPAN and RSUtils.Round(x, 2) == "0.47" and RSUtils.Round(y, 2) == "0.22") then
	    			isPrimaryMapForPOI = true
	    		elseif (mapID == RSConstants.THE_PRIMALIST_FUTURE) then
	    			isPrimaryMapForPOI = true
	    		end
	    	-- Fix primatyMapForPOI for event in Valdrakken/The primalist future
	    	elseif (mapID == RSConstants.VALDRAKKEN and RSUtils.Round(x, 2) == "0.60" and RSUtils.Round(y, 2) == "0.82") then
    			isPrimaryMapForPOI = false
			end
	    	
	  		if (isPrimaryMapForPOI and poiInfo.atlasName == npcStormAtlasName) then
		      	return findClosestSpot(npcID, mapID, x, y)
	    	end
	    end
	end
end

---============================================================================
-- NPC Map POIs
---- Manage adding NPC icons to the world map and minimap
---============================================================================

function RSNpcPOI.GetNpcPOI(npcID, mapID, npcInfo, alreadyFoundInfo)
	local POI = {}
	POI.entityID = npcID
	POI.isNpc = true
	POI.grouping = true
	POI.name = RSNpcDB.GetNpcName(npcID)
	POI.mapID = mapID	
	POI.foundTime = alreadyFoundInfo and alreadyFoundInfo.foundTime
	POI.isDead = RSNpcDB.IsNpcKilled(npcID)
	POI.isDiscovered = POI.isDead or alreadyFoundInfo ~= nil
	POI.isFriendly = RSNpcDB.IsInternalNpcFriendly(npcID)
	
	if (npcInfo) then
		POI.worldmap = npcInfo.worldmap
		POI.factionID = npcInfo.factionID
		POI.minieventID = npcInfo.minieventID
		POI.custom = npcInfo.custom
		POI.achievementIDs = RSAchievementDB.GetNotCompletedAchievementIDsByMap(npcID, mapID, npcInfo.achievementID, npcInfo.questID, npcInfo.criteria)
	end
	
	-- Coordinates
	if (GetStormInvasionAtlasName(POI.minieventID)) then
    	POI.x, POI.y = GetStormInvasionXY(npcID, mapID, POI.minieventID)
  	elseif (POI.minieventID == RSConstants.DRAGONFLIGHT_DREAMSURGE_MINIEVENT) then
    	POI.x, POI.y = GetMinieventXY(npcID, mapID, RSConstants.DREAMSURGE_ICON_ATLAS)
  	elseif (POI.minieventID == RSConstants.DRAGONFLIGHT_FYRAKK_MINIEVENT) then
    	POI.x, POI.y = GetMinieventXY(npcID, mapID, RSConstants.FYRAKK_ICON_ATLAS)
  	elseif (alreadyFoundInfo and alreadyFoundInfo.mapID == mapID) then
		POI.x = alreadyFoundInfo.coordX
		POI.y = alreadyFoundInfo.coordY
  	else
	  	POI.x, POI.y = RSNpcDB.GetInternalNpcCoordinates(npcID, mapID)
	end
	
	-- Textures
	if (POI.isDead) then
		POI.Texture = RSConstants.BLUE_NPC_TEXTURE
	elseif (POI.isFriendly) then
		POI.Texture = RSConstants.LIGHT_BLUE_NPC_TEXTURE
	elseif (RSRecentlySeenTracker.IsRecentlySeen(npcID, POI.x, POI.y)) then
		POI.Texture = RSConstants.PINK_NPC_TEXTURE
	elseif (POI.custom) then
		POI.Texture = RSConstants.PURPLE_NPC_TEXTURE
	elseif (not POI.isDiscovered) then
		POI.Texture = RSConstants.RED_NPC_TEXTURE
	else
		POI.Texture = RSConstants.NORMAL_NPC_TEXTURE
	end
	
	-- Mini icons
	if (npcInfo and npcInfo.prof) then
		POI.iconAtlas = RSConstants.PROFFESION_ICON_ATLAS
	elseif (POI.minieventID and RSConstants.MINIEVENTS_WORLDMAP_FILTERS[POI.minieventID] and RSConstants.MINIEVENTS_WORLDMAP_FILTERS[POI.minieventID].atlas) then
		POI.iconAtlas = RSConstants.MINIEVENTS_WORLDMAP_FILTERS[POI.minieventID].atlas
	elseif (RSUtils.GetTableLength(POI.achievementIDs) > 0) then
		POI.iconAtlas = RSConstants.ACHIEVEMENT_ICON_ATLAS
	end
	
	return POI
end

local function IsEventUnlocked(eventQuestIDs)
	for _, questID in ipairs(eventQuestIDs) do
		if (C_TaskQuest.IsActive(questID) or C_QuestLog.IsQuestFlaggedCompleted(questID)) then
			return true
		end
	end
	
	return false
end

local function IsNpcPOIFiltered(npcID, mapID, npcInfo, questTitles, vignetteGUIDs, areaPOIs, onWorldMap, onMinimap)
	local name = RSNpcDB.GetNpcName(npcID)
	local ignoreShowing = onMinimap and RSConfigDB.IsIgnoringWorldMapFiltersOnMinimap()
	
	-- Skip if part of a disabled event
	if (RSNpcDB.IsDisabledEvent(npcID)) then
		RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Parte de un evento desactivado.", npcID))
		return true
	end
	
	-- Skip if active while aura active
	if (npcInfo and npcInfo.spellID and not C_UnitAuras.GetPlayerAuraBySpellID(RSConstants.SEAFURY_TEMPEST_ID)) then
		RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Filtrado porque su evento no esta activo [%s].", npcID, npcInfo.spellID))
		return true
	end
	
	-- Skip if filtering by name in the world map search box
	if (name and RSGeneralDB.GetWorldMapTextFilter() and not RSUtils.Contains(name, RSGeneralDB.GetWorldMapTextFilter())) then
		RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Filtrado por nombre [%s][%s].", npcID, name, RSGeneralDB.GetWorldMapTextFilter()))
		return true
	end

	-- Skip if the entity is filtered
	if (RSConfigDB.IsNpcFiltered(npcID) or RSConfigDB.IsNpcFilteredOnlyWorldmap(npcID)) then
		RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Filtrado en opciones (filtro completo o mapa del mundo).", npcID))
		return true
	end
	
	-- Skip if custom NPC group filtered
	if (npcInfo and npcInfo.group and RSConfigDB.IsCustomNpcGroupFiltered(npcInfo.group) and not ignoreShowing) then
		RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Filtrado grupo.", npcID))
		return true
	end
	
	-- Skip if it requires a renown level
	if (npcInfo and npcInfo.renown and not RSConfigDB.IsShowingRenownRareNPCs() and private.MAP_RENOWN_IDS[mapID] and private.MAP_RENOWN_IDS[mapID].npcs) then
		local factionData = C_MajorFactions.GetMajorFactionData(private.MAP_RENOWN_IDS[mapID].factionID)
		if (factionData and factionData.renownLevel < npcInfo.renown) then
			RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Requiere renown aun sin conseguir.", npcID))
			return true
		end
	end
	
	-- Skip if rare part of a filtered minievent
	local isMinieventWithFilter = false;
	if (npcInfo and npcInfo.minieventID) then
		isMinieventWithFilter = RSConstants.MINIEVENTS_WORLDMAP_FILTERS[npcInfo.minieventID].active
		
		-- Skip if minievent is filtered
		if (RSConfigDB.IsMinieventFiltered(npcInfo.minieventID) and not ignoreShowing) then
			RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Filtrado minievento [%s].", npcID, npcInfo.minieventID))
			return true
		-- Skip if Dreamsurge minievent is not up
		elseif (npcInfo.minieventID == RSConstants.DRAGONFLIGHT_DREAMSURGE_MINIEVENT and not GetMinieventXY(npcID, mapID, RSConstants.DREAMSURGE_ICON_ATLAS)) then
		    RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Investigacion pico onirico que no esta activa.", npcID))
		    return true
		-- Skip if Invasion storm minievent is not up
		elseif (GetStormInvasionAtlasName(npcInfo.minieventID) ~= nil and not GetStormInvasionXY(npcID, mapID, npcInfo.minieventID)) then
		    RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Invasión de tormentas [%s] que no esta activa.", npcID, GetStormInvasionAtlasName(npcInfo.minieventID)))
		    return true
		-- Skip if Fyrakk assault minievent is not up
		elseif (npcInfo.minieventID == RSConstants.DRAGONFLIGHT_FYRAKK_MINIEVENT and not GetMinieventXY(npcID, mapID, RSConstants.FYRAKK_ICON_ATLAS)) then
		    RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Asalto Fyrakk que no esta activo.", npcID))
		    return true
		end
	end
	
	-- Skip if not completed achievement and is filtered
	local isNotCompletedAchievement = false
	if (npcInfo) then
		isNotCompletedAchievement = RSUtils.GetTableLength(RSAchievementDB.GetNotCompletedAchievementIDsByMap(npcID, mapID, npcInfo.achievementID, npcInfo.questID, npcInfo.criteria)) > 0;
		if (not RSConfigDB.IsShowingAchievementRareNPCs() and not ignoreShowing and isNotCompletedAchievement) then
			RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Filtrado NPC con logro.", npcID))
			return true
		end
	end
	
	-- Skip if profession and filtered
	if (npcInfo and not RSConfigDB.IsShowingProfessionRareNPCs() and not ignoreShowing and npcInfo.prof) then
		RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Filtrado NPC de profesion.", npcID))
		return true
	end
	
	-- Skip if other filtered
	if (not RSConfigDB.IsShowingOtherRareNPCs() and not ignoreShowing and not isMinieventWithFilter and not isNotCompletedAchievement and (not npcInfo or not npcInfo.prof)) then
		RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Filtrado otro NPC.", npcID))
		return true
	end

	-- Skip if not showing friendly NPCs and this one is friendly
	if (not RSConfigDB.IsShowingFriendlyNpcs() and not ignoreShowing and RSNpcDB.IsInternalNpcFriendly(npcID)) then
		RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Es amistoso.", npcID))
		return true
	end

	-- Skip if the entity appears only while a quest event is going on and it isnt active
	if (npcInfo and npcInfo.zoneQuestId) then
		local active = false
		for _, questID in ipairs(npcInfo.zoneQuestId) do
			if (C_TaskQuest.IsActive(questID) or C_QuestLog.IsQuestFlaggedCompleted(questID)) then
				active = true
				break
			end
		end

		if (not active) then
			local eventUnlocked = true
			-- If the player haven't unlocked the event associated to the zoneQuestID
			if (mapID == RSConstants.ULDUM_MAPID and not IsEventUnlocked(RSConstants.ULDUM_INVASSION_QUESTS)) then
				eventUnlocked = false
			elseif (mapID == RSConstants.VALLEY_OF_ETERNAL_BLOSSOMS_MAPID and not IsEventUnlocked(RSConstants.VALLEY_BLOSSOMS_INVASSION_QUESTS)) then
				eventUnlocked = false
			end
			
			if (eventUnlocked) then
				RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Evento asociado no esta activo.", npcID))
				return true
			end
		end
	end

	-- Skip if for whatever reason we don't have its name (this shouldnt happend)
	local npcName = RSNpcDB.GetNpcName(npcID)
	if (not npcName) then
		RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Le falta el nombre!.", npcID))
		return true
	end

	-- Skip if this NPC has a world quest active right now
	-- We don't want to show our icon on top of the quest one
	if (RSUtils.Contains(questTitles, npcName)) then
		RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Tiene misión del mundo activa.", npcID))
		return true
	end

	-- A 'not discovered' NPC will be setted as killed when the kill is detected while loading the addon and its questID is completed
	local npcDead = RSNpcDB.IsNpcKilled(npcID)

	-- Skip if dead 
	if (npcDead) then
		-- and not showing dead entities in 'not reseteable' maps
		if (RSConfigDB.IsShowingAlreadyKilledNpcsInReseteableZones() and not RSMapDB.IsReseteableKillMapID(mapID, C_Map.GetMapArtID(mapID))) then
			RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Esta muerto (zona no reseteable).", npcID))
			return true
		--  and not showing dead entities
		elseif (not RSConfigDB.IsShowingAlreadyKilledNpcsInReseteableZones() and not RSConfigDB.IsShowingAlreadyKilledNpcs()) then
			RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Esta muerto.", npcID))
			return true
		end
	end
	
	-- Skip if wrong profession
	if (npcInfo and npcInfo.prof) then
		if (not RSProfessionDB.HasPlayerProfession(npcInfo.prof)) then
			RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Profesión incorrecta.", npcID))
			return true
		end
	end

	-- Skip if an ingame vignette is already showing this entity (on Vignette)
	for _, vignetteGUID in ipairs(vignetteGUIDs) do
		local vignetteInfo = C_VignetteInfo.GetVignetteInfo(vignetteGUID);
		if (vignetteInfo and vignetteInfo.objectGUID) then
			local _, _, _, _, _, vignetteNPCID, _ = strsplit("-", vignetteInfo.objectGUID);
			if (onWorldMap and vignetteInfo.onWorldMap and (tonumber(vignetteNPCID) == npcID or RSNpcDB.GetFinalNpcID(vignetteNPCID) == npcID)) then
				RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Hay un vignette del juego mostrándolo (Vignette onWorldmap).", npcID))
				return true
			end
			if (onMinimap and vignetteInfo.onMinimap and (tonumber(vignetteNPCID) == npcID or RSNpcDB.GetFinalNpcID(vignetteNPCID) == npcID)) then
				RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Hay un vignette del juego mostrándolo (Vignette onMinimap).", npcID))
				return true
			end
			-- If Ancestral Spirit in Forbidden Reach or Loam Scout in Zaralek Cavern, locate real NPC
			if ((tonumber(vignetteNPCID) == RSConstants.FORBIDDEN_REACH_ANCESTRAL_SPIRIT or tonumber(vignetteNPCID) == RSConstants.ZARALEK_CAVERN_LOAM_SCOUT) and npcID == RSNpcDB.GetNpcId(vignetteInfo.name, mapID)) then
				RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Hay un vignette del juego mostrándolo (Espiritú ancestral/Loam scout).", npcID))
				return true
			end
		end
	end
	
	-- Skip if an ingame area POI is already showing this entity
	for _, areaPoiID in ipairs(areaPOIs) do
		local poiInfo = C_AreaPoiInfo.GetAreaPOIInfo(mapID, areaPoiID);
		if (poiInfo) then
			if (RSNpcDB.GetFinalNpcID(areaPoiID) == npcID) then
				RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Hay un area POI del juego mostrándolo.", npcID))
				return true
			end
		end
	end

	return false
end

function RSNpcPOI.GetMapNpcPOI(npcID, mapID, questTitles, vignetteGUIDs, areaPOIs, onWorldMap, onMinimap, recentlySeenInfo)
	local ignoreShowing = onMinimap and RSConfigDB.IsIgnoringWorldMapFiltersOnMinimap()
	
	-- Skip if not showing NPC icons
	if (not RSConfigDB.IsShowingNpcs() and not ignoreShowing) then
		RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Iconos de NPCs deshabilitado.", npcID))
		return
	end
	
	local alreadyFoundInfo = recentlySeenInfo or RSGeneralDB.GetAlreadyFoundEntity(npcID, RSConstants.NPC_VIGNETTE)
	
	-- Skip if not showing not discovered NPC icons
	if (not RSConfigDB.IsShowingNotDiscoveredNpcs() and not ignoreShowing and not alreadyFoundInfo) then
		return
	end

	local npcInfo = RSNpcDB.GetInternalNpcInfo(npcID)
	
	-- Skip if it was a custom NPC and has being deleted (but for whatever reason it remains in the database)
	if (not npcInfo and not alreadyFoundInfo) then
		RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC N/D [%s]: Era un NPC personalizado y ya no existe.", npcID))
		return
	end

	-- Skip if the entity has been seen before the max amount of time that the player want to see the icon on the map
	-- This filter doesnt apply to dead entities
	if (RSConfigDB.IsMaxSeenTimeFilterEnabled() and alreadyFoundInfo and not RSNpcDB.IsNpcKilled(npcID) and time() - alreadyFoundInfo.foundTime > RSTimeUtils.MinutesToSeconds(RSConfigDB.GetMaxSeenTimeFilter())) then
		RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: Visto hace demasiado tiempo.", npcID))
		return
	end
	
	-- Skip if the entity doesn't have coordinates (for example custom NPCs)
	if (not alreadyFoundInfo) then
		if (not npcInfo.x or not npcInfo.y) then
			local x, y = RSNpcDB.GetInternalNpcCoordinates(npcID, mapID)
			if (not x or not y) then
				RSLogger:PrintDebugMessageEntityID(npcID, string.format("Saltado NPC [%s]: No disponía de coordenadas.", npcID))
				return
			end
		end
	end

	-- Skip if common filters
	if (not IsNpcPOIFiltered(npcID, mapID, npcInfo, questTitles, vignetteGUIDs, areaPOIs, onWorldMap, onMinimap)) then
		return RSNpcPOI.GetNpcPOI(npcID, mapID, npcInfo, alreadyFoundInfo)
	end
end
