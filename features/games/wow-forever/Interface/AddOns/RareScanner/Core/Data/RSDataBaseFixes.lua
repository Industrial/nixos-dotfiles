-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local ADDON_NAME, private = ...

local RSDataBaseFixes = private.NewLib("RareScannerDataBaseFixes")

-- RareScanner database libraries
local RSConfigDB = private.ImportLib("RareScannerConfigDB")
local RSNpcDB = private.ImportLib("RareScannerNpcDB")

-- RareScanner internal libraries
local RSConstants = private.ImportLib("RareScannerConstants")
local RSLogger = private.ImportLib("RareScannerLogger")
local RSUtils = private.ImportLib("RareScannerUtils")
local RSRoutines = private.ImportLib("RareScannerRoutines")

-- Version constants for database fixes
local FIX_ALREADY_FOUND_VERSION = 214
local FIX_COLLECTIONS_HASHMAP_VERSION = 231

---============================================================================
-- Collections Hashmap Migration (12.1.0 / DB version 231)
---============================================================================
local function MigrateListToHashmap(tbl)
	if (not tbl or type(tbl) ~= "table") then
		return {}
	end
	-- If it is an old array indexed by number (e.g., tbl[1] ~= nil)
	if (tbl[1] ~= nil) then
		local hashmap = {}
		for _, id in ipairs(tbl) do
			if (id) then
				hashmap[id] = true
			end
		end
		return hashmap
	end
	return tbl
end

local function FixCollectionsHashmap()
	private.dbglobal.not_colleted_toys = MigrateListToHashmap(private.dbglobal.not_colleted_toys)
	private.dbglobal.not_colleted_pets_ids = MigrateListToHashmap(private.dbglobal.not_colleted_pets_ids)
	private.dbglobal.not_colleted_mounts_ids = MigrateListToHashmap(private.dbglobal.not_colleted_mounts_ids)
	private.dbglobal.not_colleted_drakewatchers = MigrateListToHashmap(private.dbglobal.not_colleted_drakewatchers)
	private.dbglobal.not_colleted_decors = MigrateListToHashmap(private.dbglobal.not_colleted_decors)
	RSLogger:PrintDebugMessage("RSDataBaseFixes: Colecciones migradas a hashmap.")
end

---============================================================================
-- Main Database Fix Routine Chain Builder
---============================================================================
function RSDataBaseFixes.FixDataBase(routines, previousDbVersion)
	-- Fix collections hashmap (12.1.0)
	if (not previousDbVersion or previousDbVersion < FIX_COLLECTIONS_HASHMAP_VERSION) then
		FixCollectionsHashmap()
	end

	-- Update older container filters system to newer (10.0.5)
	if (RSUtils.GetTableLength(private.db.general.filteredContainers) > 0) then
		if (private.db.containerFilters.filterOnlyMap) then
			RSConfigDB.SetDefaultContainerFilter(RSConstants.ENTITY_FILTER_WORLDMAP)
		elseif (private.db.containerFilters.filterOnlyAlerts) then
			RSConfigDB.SetDefaultContainerFilter(RSConstants.ENTITY_FILTER_ALERTS)
		else
			RSConfigDB.SetDefaultContainerFilter(RSConstants.ENTITY_FILTER_ALL)
		end
		
		local fixContainerFilters = RSRoutines.LoopRoutineNew()
		fixContainerFilters:Init(
			function() return private.db.general.filteredContainers end,
			function(context, containerID, value)
				if (private.db.general.filtersFixed and value == true) then
					RSConfigDB.SetContainerFiltered(containerID)
				elseif (not private.db.general.filtersFixed and value == false) then
					RSConfigDB.SetContainerFiltered(containerID)
				end
			end, 
			function(context)			
				private.db.containerFilters.filterOnlyMap = nil
				private.db.containerFilters.filterOnlyAlerts = nil
				private.db.general.filteredContainers = nil
				RSLogger:PrintDebugMessage("RSDataBaseFixes: Migrados filtros de contenedores")
			end
		)
		table.insert(routines, fixContainerFilters)
	end

	-- Update older npc filters system to newer (10.0.5)
	if (RSUtils.GetTableLength(private.db.general.filteredRares) > 0) then
		if (private.db.rareFilters.filterOnlyMap) then
			RSConfigDB.SetDefaultNpcFilter(RSConstants.ENTITY_FILTER_WORLDMAP)
		else
			RSConfigDB.SetDefaultNpcFilter(RSConstants.ENTITY_FILTER_ALL)
		end
		
		local fixNpcFilters = RSRoutines.LoopRoutineNew()
		fixNpcFilters:Init(
			function() return private.db.general.filteredRares end,
			function(context, npcID, value)
				if (private.db.general.filtersFixed and value == true) then
					RSConfigDB.SetNpcFiltered(npcID)
				elseif (not private.db.general.filtersFixed and value == false) then
					RSConfigDB.SetNpcFiltered(npcID)
				end
			end, 
			function(context)			
				private.db.rareFilters.filterOnlyMap = nil
				private.db.general.filteredRares = nil
				RSLogger:PrintDebugMessage("RSDataBaseFixes: Migrados filtros de NPCs")
			end
		)
		table.insert(routines, fixNpcFilters)
	end

	-- Update older event filters system to newer (10.0.5)
	if (RSUtils.GetTableLength(private.db.general.filteredEvents) > 0) then
		if (private.db.eventFilters.filterOnlyMap) then
			RSConfigDB.SetDefaultEventFilter(RSConstants.ENTITY_FILTER_WORLDMAP)
		else
			RSConfigDB.SetDefaultEventFilter(RSConstants.ENTITY_FILTER_ALL)
		end
		
		local fixEventFilters = RSRoutines.LoopRoutineNew()
		fixEventFilters:Init(
			function() return private.db.general.filteredEvents end,
			function(context, eventID, value)
				if (private.db.general.filtersFixed and value == true) then
					RSConfigDB.SetEventFiltered(eventID)
				elseif (not private.db.general.filtersFixed and value == false) then
					RSConfigDB.SetEventFiltered(eventID)
				end
			end, 
			function(context)			
				private.db.eventFilters.filterOnlyMap = nil
				private.db.general.filteredEvents = nil
				RSLogger:PrintDebugMessage("RSDataBaseFixes: Migrados filtros de Eventos")
			end
		)
		table.insert(routines, fixEventFilters)
	end

	-- Update older zone filters system to newer (10.1.0)
	if (RSUtils.GetTableLength(private.db.general.filteredZones) > 0) then
		if (private.db.zoneFilters.filterOnlyMap) then
			RSConfigDB.SetDefaultZoneFilter(RSConstants.ENTITY_FILTER_WORLDMAP)
		else
			RSConfigDB.SetDefaultZoneFilter(RSConstants.ENTITY_FILTER_ALL)
		end
		
		local fixZoneFilters = RSRoutines.LoopRoutineNew()
		fixZoneFilters:Init(
			function() return private.db.general.filteredZones end,
			function(context, zoneID, value)
				if (private.db.general.filtersFixed and value == true) then
					RSConfigDB.SetZoneFiltered(zoneID)
				elseif (not private.db.general.filtersFixed and value == false) then
					RSConfigDB.SetZoneFiltered(zoneID)
				end
			end, 
			function(context)			
				private.db.zoneFilters.filterOnlyMap = nil
				private.db.general.filteredZones = nil
				RSLogger:PrintDebugMessage("RSDataBaseFixes: Migrados filtros de Zonas")
			end
		)
		table.insert(routines, fixZoneFilters)
	end
	
	-- Update older custom NPCs to newer (10.2.0)
	if (RSUtils.GetTableLength(private.dbglobal.custom_npcs) > 0) then
		local needFix = false
		for customNpcID, customNpcInfo in pairs (private.dbglobal.custom_npcs) do
			if (not private.dbglobal.custom_npcs.custom or not private.dbglobal.custom_npcs.noVignette) then
				needFix = true
				break;
			end
		end
		
		if (needFix) then
			local fixCustomNpcs = RSRoutines.LoopRoutineNew()
			fixCustomNpcs:Init(
				function() return private.dbglobal.custom_npcs end,
				function(context, customNpcID, customNpcInfo)
					customNpcInfo.custom = true
					customNpcInfo.noVignette = true
					customNpcInfo.nameplate = nil
					-- If decimal values (older custom NPCs), transform to newer coord system
					if (type(customNpcInfo.zoneID) == "table") then
						for zoneID, zoneInfo in pairs (customNpcInfo.zoneID) do
							if (zoneID ~= RSConstants.ALL_ZONES_CUSTOM_NPC and zoneInfo.x and zoneInfo.y) then
								customNpcInfo.zoneID[zoneID].x = RSUtils.Rpad(tostring(zoneInfo.x):gsub('(0%.)',''), 4, '0')
								customNpcInfo.zoneID[zoneID].y = RSUtils.Rpad(tostring(zoneInfo.y):gsub('(0%.)',''), 4, '0')
							end
						end
					else
						if (customNpcInfo.zoneID ~= RSConstants.ALL_ZONES_CUSTOM_NPC and customNpcInfo.x and customNpcInfo.y) then
							customNpcInfo.x = RSUtils.Rpad(tostring(customNpcInfo.x):gsub('(0%.)',''), 4, '0')
							customNpcInfo.y = RSUtils.Rpad(tostring(customNpcInfo.y):gsub('(0%.)',''), 4, '0')
						end
					end
					
					private.dbglobal.custom_npcs[customNpcID] = customNpcInfo
				end, 
				function(context)			
					RSLogger:PrintDebugMessage("RSDataBaseFixes: Migrados NPCs personalizados")
				end
			)
			table.insert(routines, fixCustomNpcs)
		end
	end

	-- Split rares_found in entities (rares, containers, events)
	if (not previousDbVersion or previousDbVersion < FIX_ALREADY_FOUND_VERSION) then
		local idsRemove = {}
		local splitAlreadyFoundDB = RSRoutines.LoopRoutineNew()
		splitAlreadyFoundDB:Init(
			function() return private.dbglobal.rares_found end,
			function(context, entityID, entityInfo)
				if (RSConstants.IsContainerAtlas(entityInfo.atlasName)) then
					private.dbglobal.containers_found[entityID] = entityInfo
					tinsert(idsRemove, entityID)
				elseif (RSConstants.IsEventAtlas(entityInfo.atlasName)) then
					private.dbglobal.events_found[entityID] = entityInfo
					tinsert(idsRemove, entityID)
				-- Delete if it doesn't exist in the internal database or is custom
				elseif (not RSNpcDB.GetInternalNpcInfo(entityID) and not RSNpcDB.GetCustomNpcInfo(entityID)) then
					tinsert(idsRemove, entityID)
				end
			end, 
			function(context)
				RSLogger:PrintDebugMessage("RSDataBaseFixes: Dividida alreadyFound DB")
					
				for _, entityID in ipairs(idsRemove) do
					private.dbglobal.rares_found[entityID] = nil
				end
				
				RSLogger:PrintDebugMessage("RSDataBaseFixes: Limpiado alreadyFound (rares) DB")
			end
		)
		table.insert(routines, splitAlreadyFoundDB)
	end
end
