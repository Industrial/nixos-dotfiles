-- AddOn namespace.
-----------------------------------------------------------------------
local ADDON_NAME, private = ...
local LibStub = _G.LibStub

local RSContainerDB = private.NewLib("RareScannerContainerDB")

-- RareScanner database libraries
local RSMapDB = private.ImportLib("RareScannerMapDB")
local RSProfessionDB = private.ImportLib("RareScannerProfessionDB")

-- Locales
local AL = LibStub("AceLocale-3.0"):GetLocale("RareScanner");

-- RareScanner libraries
local RSLogger = private.ImportLib("RareScannerLogger")
local RSUtils = private.ImportLib("RareScannerUtils")
local RSConstants = private.ImportLib("RareScannerConstants")
local RSTimeUtils = private.ImportLib("RareScannerTimeUtils")

---============================================================================
-- Opened containers database
---============================================================================

function RSContainerDB.InitContainerOpenedDB()
	if (not private.dbchar.containers_opened) then
		private.dbchar.containers_opened = {}
	end
end

function RSContainerDB.GetAllContainersOpenedRespawnTimes()
	return private.dbchar.containers_opened
end

function RSContainerDB.IsContainerOpened(containerID)
	if (containerID and private.dbchar.containers_opened[containerID]) then
		return true;
	end

	return false
end

function RSContainerDB.GetContainerOpenedRespawnTime(containerID)
	if (RSContainerDB.IsContainerOpened(containerID)) then
		return private.dbchar.containers_opened[containerID]
	end

	return 0
end

function RSContainerDB.SetContainerOpened(containerID, respawnTime)
	if (containerID) then
		if (not respawnTime) then
			private.dbchar.containers_opened[containerID] = RSConstants.ETERNAL_OPENED
		else
			private.dbchar.containers_opened[containerID] = respawnTime
		end
	end
end

function RSContainerDB.DeleteContainerOpened(containerID)
	if (containerID) then
		private.dbchar.containers_opened[containerID] = nil
	end
end

---============================================================================
-- Times opened database
---============================================================================

local previousOpenedGuids = {}

function RSContainerDB.IncreaseTimesOpened(containerGUID)
	if (not containerGUID) then
		return
	end
	
	local _, _, _, _, _, id = strsplit("-", containerGUID)
	local containerID = id and tonumber(id) or nil
	
	if (not containerID) then
		return
	end
	
	if (not private.dbglobal.container_counters) then
		private.dbglobal.container_counters = {}
	end
	
	-- Avoid registering the same open twice
	if (previousOpenedGuids[containerGUID]) then
		return
	end
	
	private.dbglobal.container_counters[containerID] = (private.dbglobal.container_counters[containerID] or 0) + 1
	previousOpenedGuids[containerGUID] = true
	
	C_Timer.After(60, function()
		previousOpenedGuids[containerGUID] = nil
	end)
end

function RSContainerDB.GetTimesOpened(containerID)
	if (not containerID or not private.dbglobal.container_counters) then
		return 0
	end

	return private.dbglobal.container_counters[containerID] or 0
end

---============================================================================
-- Container internal database
----- Stores containers information included with the addon
---============================================================================

function RSContainerDB.GetAllInternalContainerInfo()
	return private.CONTAINER_INFO
end

function RSContainerDB.GetContainerIDsByMapID(mapID)
	return RSMapDB.GetEntitiesByMapID(mapID, RSConstants.MAP_ENTITY_CONTAINER)
end

function RSContainerDB.GetInternalContainerInfo(containerID)
	if (containerID) then
		return private.CONTAINER_INFO[containerID]
	end

	return nil
end

function RSContainerDB.GetInternalContainerInfoByMapID(containerID, mapID)
	if (containerID and mapID) then
		if (RSContainerDB.IsInternalContainerMultiZone(containerID)) then
			for internalMapID, zoneInfo in pairs (RSContainerDB.GetInternalContainerInfo(containerID).zoneID) do
				if (internalMapID == mapID) then
					local containerInfo = {}
					RSUtils.CloneTable(RSContainerDB.GetInternalContainerInfo(containerID), containerInfo)
					containerInfo.zoneID = internalMapID
					containerInfo.x = zoneInfo.x
					containerInfo.y = zoneInfo.y
					containerInfo.artID = zoneInfo.artID
					containerInfo.overlay = zoneInfo.overlay
					return containerInfo
				end
			end
			
			-- Then check if there is a matching subMapID in the database
			for internalMapID, zoneInfo in pairs (RSContainerDB.GetInternalContainerInfo(containerID).zoneID) do
				if (RSMapDB.IsMapInParentMap(mapID, internalMapID)) then
					local containerInfo = {}
					RSUtils.CloneTable(RSContainerDB.GetInternalContainerInfo(containerID), containerInfo)
					containerInfo.zoneID = internalMapID
					containerInfo.x = zoneInfo.x
					containerInfo.y = zoneInfo.y
					containerInfo.artID = zoneInfo.artID
					containerInfo.overlay = zoneInfo.overlay
					return containerInfo
				end
			end
		elseif (RSContainerDB.IsInternalContainerMonoZone(containerID)) then
			local containerInfo = RSContainerDB.GetInternalContainerInfo(containerID)
			return containerInfo
		end
	end

	return nil
end

function RSContainerDB.GetInternalContainerArtID(containerID, mapID)
	if (containerID and mapID) then
		local containerInfo = RSContainerDB.GetInternalContainerInfoByMapID(containerID, mapID)
		if (containerInfo) then
			return containerInfo.artID
		end
	end

	return nil
end

function RSContainerDB.GetInternalContainerCoordinates(containerID, mapID)
	if (containerID and mapID) then
		local containerInfo = RSContainerDB.GetInternalContainerInfoByMapID(containerID, mapID)
		if (containerInfo) then
			return RSUtils.FixCoord(containerInfo.x), RSUtils.FixCoord(containerInfo.y)
		end
	end

	return nil
end

function RSContainerDB.GetBestInternalContainerCoordinates(containerID, mapID)
	-- Locates players coordinates based in the mapID where it was found
	local playerMapPosition = C_Map.GetPlayerMapPosition(mapID, "player")
	local playerx, playery
	if (playerMapPosition) then
		playerx, playery = playerMapPosition:GetXY()
		
		-- Locates players coordinates based in the best map
		if (not playerx or not playery) then
			local playerMapID = C_Map.GetBestMapForUnit("player")
			playerMapPosition = C_Map.GetPlayerMapPosition(playerMapID, "player")
			if (playerMapPosition) then
				playerx, playery = playerMapPosition:GetXY()
				mapID = playerMapID
			end
		end
	end
	
	-- Locates closest container coordinates to the players
	if (playerx and playery) then
		local overlay = RSContainerDB.GetInternalContainerOverlay(containerID, mapID)
		if (overlay) then
			local distances = {}
			local coords = {}
			for _, coordinates in ipairs (overlay) do
				local xo, yo = strsplit("-", coordinates)
				local distance = RSUtils.DistanceBetweenCoords(playerx, RSUtils.FixCoord(xo), playery, RSUtils.FixCoord(yo));
				if (distance >= 0 and distance <= 0.02) then
					tinsert(distances, distance)
					coords[distance] = {}
					coords[distance].x = xo
					coords[distance].y = yo
				end
			end
			
			-- Get the smallest
			if (RSUtils.GetTableLength(distances) > 0) then
				local minDistance = min(unpack(distances))
				return coords[minDistance].x, coords[minDistance].y
			end
		end
	end
	
	-- Locates internal coordinates
	local x, y = RSContainerDB.GetInternalContainerCoordinates(containerID, mapID)
	if (x and y) then
		return x, y
	-- Otherwise returns players coordinates
	else
		return playerx, playery
	end
end

function RSContainerDB.GetInternalContainerOverlay(containerID, mapID)
	if (containerID and mapID) then
		local containerInfo = RSContainerDB.GetInternalContainerInfoByMapID(containerID, mapID)
		if (containerInfo) then
			return containerInfo.overlay
		end
	end

	return nil
end

function RSContainerDB.IsInternalContainerMultiZone(containerID)
	local containerInfo = RSContainerDB.GetInternalContainerInfo(containerID)
	return containerInfo and type(containerInfo.zoneID) == "table"
end

function RSContainerDB.IsInternalContainerMonoZone(containerID)
	local containerInfo = RSContainerDB.GetInternalContainerInfo(containerID)
	return containerInfo and type(containerInfo.zoneID) ~= "table"
end

function RSContainerDB.IsInternalContainerInMap(containerID, mapID, checkSubzones, ignoreAtlas)
	if (containerID and mapID) then
		if (RSContainerDB.IsInternalContainerMultiZone(containerID)) then
			for internalMapID, internalContainerInfo in pairs(RSContainerDB.GetInternalContainerInfo(containerID).zoneID) do
				if (internalMapID == mapID and (ignoreAtlas or not internalContainerInfo.artID or RSUtils.Contains(internalContainerInfo.artID, C_Map.GetMapArtID(mapID)))) then
					return true;
				elseif (checkSubzones and RSMapDB.IsMapInParentMap(mapID, internalMapID)) then
					return true;
				end
			end
		elseif (RSContainerDB.IsInternalContainerMonoZone(containerID)) then
			local containerInfo = RSContainerDB.GetInternalContainerInfo(containerID)
			if (containerInfo.zoneID == mapID and (ignoreAtlas or not containerInfo.artID or RSUtils.Contains(containerInfo.artID, C_Map.GetMapArtID(mapID)))) then
				return true;
			elseif (checkSubzones and RSMapDB.IsMapInParentMap(mapID, containerInfo.zoneID)) then
				return true;
			end
		end
	end

	return false;
end

function RSContainerDB.IsWorldMap(containerID)
	if (containerID) then
		local containerInfo = RSContainerDB.GetInternalContainerInfo(containerID)
		return containerInfo and containerInfo.worldmap
	end
end

function RSContainerDB.IsDisabledEvent(containerID)
	if (containerID) then
		local containerInfo = RSContainerDB.GetInternalContainerInfo(containerID)
		return containerInfo and containerInfo.event and not RSTimeUtils.IsHolidayEventActive(containerInfo.event)
	end
	
	return false
end

---============================================================================
-- Container Loot internal database
----- Stores Container loot included with the addon
---============================================================================

function RSContainerDB.GetContainerLoot(containerID)
	if (containerID) then
		return RSUtils.JoinTables(RSContainerDB.GetInteralContainerLoot(containerID), RSContainerDB.GetContainerLootFound(containerID))
	end

	return nil
end

function RSContainerDB.GetAllInteralContainerLoot()
	return private.CONTAINER_LOOT
end

function RSContainerDB.GetInteralContainerLoot(containerID)
	if (containerID) then
		return RSContainerDB.GetAllInteralContainerLoot()[containerID]
	end

	return nil
end

---============================================================================
-- Container Loot database
----- Stores Container loot found while playing
---============================================================================

function RSContainerDB.InitContainerLootFoundDB()
	if (not private.dbglobal.containers_loot) then
		private.dbglobal.containers_loot = {}
	end
end

function RSContainerDB.GetAllContainersLootFound()
	return private.dbglobal.containers_loot
end

function RSContainerDB.GetContainerLootFound(containerID)
	if (containerID and private.dbglobal.containers_loot[containerID]) then
		return private.dbglobal.containers_loot[containerID]
	end

	return nil
end

function RSContainerDB.SetContainerLootFound(containerID, loot)
	if (containerID and loot) then
		private.dbglobal.containers_loot[containerID] = loot
	end
end

function RSContainerDB.AddItemToContainerLootFound(containerID, itemID)
	if (containerID and itemID) then
		if (not private.dbglobal.containers_loot[containerID]) then
			private.dbglobal.containers_loot[containerID] = {}
		end

		-- If its in the internal database ignore it
		local internalLoot = RSContainerDB.GetInteralContainerLoot(containerID)
		if (internalLoot and RSUtils.Contains(internalLoot, itemID)) then
			return
		end

		-- If its not in the loot found DB adds it
		if (not RSUtils.Contains(private.dbglobal.containers_loot[containerID], itemID)) then
			tinsert(private.dbglobal.containers_loot[containerID], itemID)
			RSLogger:PrintDebugMessage(string.format("AddItemToContainerLootFound[%s]: Añadido nuevo loot [%s]", containerID, itemID))
		end
	end
end

function RSContainerDB.RemoveContainerLootFound(containerID)
	if (containerID) then
		private.dbglobal.containers_loot[containerID] = nil
	end
end

---============================================================================
-- Container quest IDs database
----- Stores Containers hidden quest IDs
---============================================================================

function RSContainerDB.InitContainerQuestIdFoundDB()
	if (RSConstants.DEBUG_MODE and not private.dbglobal.container_quest_ids) then
		private.dbglobal.container_quest_ids = {}
	end
end

function RSContainerDB.ResetContainerQuestIdFoundDB()
	if (private.dbglobal.container_quest_ids) then
		if (RSConstants.DEBUG_MODE) then
			private.dbglobal.container_quest_ids = {}
		else
			private.dbglobal.container_quest_ids = nil
		end
	end
end

function RSContainerDB.SetContainerQuestIdFound(containerID, questID)
	if (containerID and questID) then
		private.dbglobal.container_quest_ids[containerID] = { questID }
		RSLogger:PrintDebugMessage(string.format("Contenedor [%s]. Calculado questID [%s]", containerID, questID))
	end
end

function RSContainerDB.GetContainerQuestIdFound(containerID)
	if (containerID and private.dbglobal.container_quest_ids[containerID]) then
		return private.dbglobal.container_quest_ids[containerID]
	end

	return nil
end

function RSContainerDB.RemoveContainerQuestIdFound(containerID)
	if (containerID) then
		private.dbglobal.container_quest_ids[containerID] = nil
	end
end

---============================================================================
-- Containers names database
----- Stores names of containers included with the addon
---============================================================================

function RSContainerDB.InitContainerNamesDB()
	if (not private.dbglobal.object_names) then
		private.dbglobal.object_names = {}
	end

	if (not private.dbglobal.object_names[GetLocale()]) then
		private.dbglobal.object_names[GetLocale()] = {}
	end
end

function RSContainerDB.GetAllContainerNames()
	return private.dbglobal.object_names[GetLocale()]
end

function RSContainerDB.SetContainerName(containerID, name)
	if (containerID and name) then
		private.dbglobal.object_names[GetLocale()][containerID] = name
	end
end

function RSContainerDB.GetContainerName(containerID)
	if (containerID) then
		-- Fix for Small Somnut showing as Magical Bloom
		if (containerID == 408719) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL[string.format("CONTAINER_%s", containerID)]
			return AL[string.format("CONTAINER_%s", containerID)]
		elseif (private.dbglobal.object_names[GetLocale()][containerID] and private.dbglobal.object_names[GetLocale()][containerID] ~= AL["CONTAINER"]) then
			return private.dbglobal.object_names[GetLocale()][containerID]
		elseif (AL[string.format("CONTAINER_%s", containerID)] ~= string.format("CONTAINER_%s", containerID)) then
			return AL[string.format("CONTAINER_%s", containerID)]
		elseif (RSUtils.Contains(RSConstants.RELIC_CACHE, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["RELIC_CACHE"]
			return AL["RELIC_CACHE"]
		elseif (RSUtils.Contains(RSConstants.PILE_BONES, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["PILE_BONES"]
			return AL["PILE_BONES"]
		elseif (RSUtils.Contains(RSConstants.SHARDHIDE_STASH, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["SHARDHIDE_STASH"]
			return AL["SHARDHIDE_STASH"]
		elseif (RSUtils.Contains(RSConstants.STOLEN_ANIMA_VESSEL, containerID) or RSUtils.Contains(RSConstants.STOLEN_ANIMA_VESSEL_RIFT, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["STOLEN_ANIMA_VESSEL"]
			return AL["STOLEN_ANIMA_VESSEL"]
		elseif (RSUtils.Contains(RSConstants.FIRIM_EXILE_OBJECTS, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["NOTE_FIRIM_EXILE"]
			return AL["NOTE_FIRIM_EXILE"]
		elseif (RSUtils.Contains(RSConstants.RUMBLE_COIN_BAG, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["RUMBLE_COIN_BAG"]
			return AL["RUMBLE_COIN_BAG"]
		elseif (RSUtils.Contains(RSConstants.RUMBLE_FOIL_BAG, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["RUMBLE_FOIL_BAG"]
			return AL["RUMBLE_FOIL_BAG"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_INFESTED_CACHE, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_INFESTED_CACHE"]
			return AL["CONTAINERS_INFESTED_CACHE"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_JANIS_STASH, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_JANIS_STASH"]
			return AL["CONTAINERS_JANIS_STASH"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_BLACK_EMPIRE_CACHE, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_BLACK_EMPIRE_CACHE"]
			return AL["CONTAINERS_BLACK_EMPIRE_CACHE"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_DARKSHORE_CACHE, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_DARKSHORE_CACHE"]
			return AL["CONTAINERS_DARKSHORE_CACHE"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_INVASIVE_MAWSHROOM, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_INVASIVE_MAWSHROOM"]
			return AL["CONTAINERS_INVASIVE_MAWSHROOM"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_LUNARLIGHT_POD, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_LUNARLIGHT_POD"]
			return AL["CONTAINERS_LUNARLIGHT_POD"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_AMATHET_CACHE, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_AMATHET_CACHE"]
			return AL["CONTAINERS_AMATHET_CACHE"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_VOID_SEEPED_CACHE, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_VOID_SEEPED_CACHE"]
			return AL["CONTAINERS_VOID_SEEPED_CACHE"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_LEGION_WAR_SUPPLIES, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_LEGION_WAR_SUPPLIES"]
			return AL["CONTAINERS_LEGION_WAR_SUPPLIES"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_CURIOUS_GRAIN_SACK, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_CURIOUS_GRAIN_SACK"]
			return AL["CONTAINERS_CURIOUS_GRAIN_SACK"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_PUGILISTS_PRIZE, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_PUGILISTS_PRIZE"]
			return AL["CONTAINERS_PUGILISTS_PRIZE"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_SKYWARD_BELL, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_SKYWARD_BELL"]
			return AL["CONTAINERS_SKYWARD_BELL"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_BROKEN_BELL, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_BROKEN_BELL"]
			return AL["CONTAINERS_BROKEN_BELL"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_ENCHANTED_CHEST, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_ENCHANTED_CHEST"]
			return AL["CONTAINERS_ENCHANTED_CHEST"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_TEST_OF_PENITENCE, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_TEST_OF_PENITENCE"]
			return AL["CONTAINERS_TEST_OF_PENITENCE"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_DECAYED_HUSK, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_DECAYED_HUSK"]
			return AL["CONTAINERS_DECAYED_HUSK"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_SECRET_TREASURE, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_SECRET_TREASURE"]
			return AL["CONTAINERS_SECRET_TREASURE"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_MECHANIZED_CHEST, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_MECHANIZED_CHEST"]
			return AL["CONTAINERS_MECHANIZED_CHEST"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_TREASURE_CHEST, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_TREASURE_CHEST"]
			return AL["CONTAINERS_TREASURE_CHEST"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_ARCANE_CHEST, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_ARCANE_CHEST"]
			return AL["CONTAINERS_ARCANE_CHEST"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_EREDAR_WAR_SUPPLIES, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_EREDAR_WAR_SUPPLIES"]
			return AL["CONTAINERS_EREDAR_WAR_SUPPLIES"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_SHIMMERING_ANCIENT_MANA_CLUSTER, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_SHIMMERING_ANCIENT_MANA_CLUSTER"]
			return AL["CONTAINERS_SHIMMERING_ANCIENT_MANA_CLUSTER"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_SPROUTING_GROWTH, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_SPROUTING_GROWTH"]
			return AL["CONTAINERS_SPROUTING_GROWTH"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_BURIED_TREASURE_CHEST, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_BURIED_TREASURE_CHEST"]
			return AL["CONTAINERS_BURIED_TREASURE_CHEST"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_LOOSE_PARTS, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_LOOSE_PARTS"]
			return AL["CONTAINERS_LOOSE_PARTS"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_SMALL_TREASURE_CHEST, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_SMALL_TREASURE_CHEST"]
			return AL["CONTAINERS_SMALL_TREASURE_CHEST"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_FULL_GARRISON_CACHE, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_FULL_GARRISON_CACHE"]
			return AL["CONTAINERS_FULL_GARRISON_CACHE"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_MOGU_PLUNDER, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_MOGU_PLUNDER"]
			return AL["CONTAINERS_MOGU_PLUNDER"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_AMBERED_CACHE, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_AMBERED_CACHE"]
			return AL["CONTAINERS_AMBERED_CACHE"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_SILVER_STRONGBOX, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_SILVER_STRONGBOX"]
			return AL["CONTAINERS_SILVER_STRONGBOX"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_GARRISON_CACHE, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_GARRISON_CACHE"]
			return AL["CONTAINERS_GARRISON_CACHE"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_CURSED_TREASURE, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_CURSED_TREASURE"]
			return AL["CONTAINERS_CURSED_TREASURE"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_RUNEBOUND_COFFER, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_RUNEBOUND_COFFER"]
			return AL["CONTAINERS_RUNEBOUND_COFFER"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_HIDDEN_HOARD, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_HIDDEN_HOARD"]
			return AL["CONTAINERS_HIDDEN_HOARD"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_FAERIE_STASH, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_FAERIE_STASH"]
			return AL["CONTAINERS_FAERIE_STASH"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_A_DAMP_SCROLL, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_A_DAMP_SCROLL"]
			return AL["CONTAINERS_A_DAMP_SCROLL"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_DISTURBED_DIRT, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_DISTURBED_DIRT"]
			return AL["CONTAINERS_DISTURBED_DIRT"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_RIFTBOUND_CACHE, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_RIFTBOUND_CACHE"]
			return AL["CONTAINERS_RIFTBOUND_CACHE"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_GLOWING_ARCANE_TRUNK, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_GLOWING_ARCANE_TRUNK"]
			return AL["CONTAINERS_GLOWING_ARCANE_TRUNK"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_ELIXIR_OF_SHADOW_SIGHT, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_ELIXIR_OF_SHADOW_SIGHT"]
			return AL["CONTAINERS_ELIXIR_OF_SHADOW_SIGHT"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_RIFT_HIDDEN_CACHE, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_RIFT_HIDDEN_CACHE"]
			return AL["CONTAINERS_RIFT_HIDDEN_CACHE"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_DIM_LUNARLIGHT_POD, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_DIM_LUNARLIGHT_POD"]
			return AL["CONTAINERS_DIM_LUNARLIGHT_POD"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_MAGIC_BOUND_CHEST, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_MAGIC_BOUND_CHEST"]
			return AL["CONTAINERS_MAGIC_BOUND_CHEST"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_ANCIENT_EREDAR_CACHE, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_ANCIENT_EREDAR_CACHE"]
			return AL["CONTAINERS_ANCIENT_EREDAR_CACHE"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_NEST_OF_UNUSUAL_MATERIALS, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_NEST_OF_UNUSUAL_MATERIALS"]
			return AL["CONTAINERS_NEST_OF_UNUSUAL_MATERIALS"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_WAR_SUPPLY_CHEST, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_WAR_SUPPLY_CHEST"]
			return AL["CONTAINERS_WAR_SUPPLY_CHEST"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_MAWSWORN_CACHE, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_MAWSWORN_CACHE"]
			return AL["CONTAINERS_MAWSWORN_CACHE"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_HARMONIC_CHEST, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_HARMONIC_CHEST"]
			return AL["CONTAINERS_HARMONIC_CHEST"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_STONEBORN_SATCHEL, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_STONEBORN_SATCHEL"]
			return AL["CONTAINERS_STONEBORN_SATCHEL"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_UNWAKING_ECHO, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_UNWAKING_ECHO"]
			return AL["CONTAINERS_UNWAKING_ECHO"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_DREAMSEED_CACHE, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_DREAMSEED_CACHE"]
			return AL["CONTAINERS_DREAMSEED_CACHE"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_SEAFARER_CACHE, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_SEAFEARER_CACHE"]
			return AL["CONTAINERS_SEAFEARER_CACHE"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_SLIMY_COCOON, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_SLIMY_COCOON"]
			return AL["CONTAINERS_SLIMY_COCOON"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_MUFF_AUTO_LOCKER, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_MUFF_AUTO_LOCKER"]
			return AL["CONTAINERS_MUFF_AUTO_LOCKER"]
		elseif (RSUtils.Contains(private.ACHIEVEMENT_TARGET_IDS[61052], containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["NOTE_CONTAINERS_GLOWING_MOTH"]
			return AL["NOTE_CONTAINERS_GLOWING_MOTH"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_STURDY_CHEST, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_STURDY_CHEST"]
			return AL["CONTAINERS_STURDY_CHEST"]
		elseif (RSUtils.Contains(private.ACHIEVEMENT_TARGET_IDS[62057], containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_HIGH_PEAK"]
			return AL["CONTAINERS_HIGH_PEAK"]
		elseif (RSUtils.Contains(RSConstants.CONTAINERS_FUNERARY_INSCRIPTION, containerID)) then
			private.dbglobal.object_names[GetLocale()][containerID] = AL["CONTAINERS_FUNERARY_INSCRIPTION"]
			return AL["CONTAINERS_FUNERARY_INSCRIPTION"]
		end
	end

	return nil
end

function RSContainerDB.GetActiveContainerIDsWithNamesByMapID(mapID)
	local containerIDs = RSContainerDB.GetContainerIDsByMapID(mapID)
	local containerIDsWithNames = nil
	
	if (RSUtils.GetTableLength(containerIDs) > 0) then
		containerIDsWithNames = {}
		for _, containerID in ipairs(containerIDs) do
			local containerInfo = RSContainerDB.GetInternalContainerInfo(containerID)
			if (containerInfo and containerInfo.prof and not RSProfessionDB.HasPlayerProfession(containerInfo.prof)) then
				-- Wrong profession
			elseif (RSContainerDB.IsDisabledEvent(containerID)) then
				-- World event disabled
			else
				local containerName = RSContainerDB.GetContainerName(containerID)
				if (containerName) then
					containerIDsWithNames[containerID] = string.format("%s (%s)", containerName, containerID)
				else
					containerIDsWithNames[containerID] = tostring(containerID)
				end
			end
		end
		
		return containerIDsWithNames
	end
	
	return containerIDsWithNames
end

---============================================================================
-- Reseteable containers database
---- Stores containers that in theory cannot be opened again, but that they are
---- detected again
---============================================================================

function RSContainerDB.InitReseteableContainersDB()
	if (not private.dbglobal.containers_reseteable) then
		private.dbglobal.containers_reseteable = {}
	end
end

function RSContainerDB.IsContainerReseteable(containerID)
	return containerID and private.dbglobal.containers_reseteable[containerID]
end

function RSContainerDB.SetContainerReseteable(containerID)
	if (containerID) then
		private.dbglobal.containers_reseteable[containerID] = true
	end
end

---============================================================================
-- Containers with multi spawn spots
---============================================================================

function RSContainerDB.IsMultiZoneSpawn(containerID)
	local containerInfo = RSContainerDB.GetInternalContainerInfo(containerID)
	if (containerInfo and containerInfo.repeatable) then
		return true
	end
	
	return false
end

---============================================================================
-- Containers with pre-events
----- Obtains the latest containerID in a chain of pre-events
---============================================================================

function RSContainerDB.GetFinalContainerID(containerPreEventID)
	local containerID = tonumber(containerPreEventID)
	
	-- Container with pre-event
	while (RSConstants.CONTAINERS_WITH_PRE_EVENT[containerID]) do
		containerID = RSConstants.CONTAINERS_WITH_PRE_EVENT[containerID]
	end
	
	return containerID
end