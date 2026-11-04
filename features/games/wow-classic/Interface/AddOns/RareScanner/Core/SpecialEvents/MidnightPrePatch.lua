-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local LibStub = _G.LibStub
local RareScanner = LibStub("AceAddon-3.0"):GetAddon("RareScanner")
local ADDON_NAME, private = ...

-- Locales
local AL = LibStub("AceLocale-3.0"):GetLocale("RareScanner");

-- RareScanner database libraries
local RSNpcDB = private.ImportLib("RareScannerNpcDB")
local RSGeneralDB = private.ImportLib("RareScannerGeneralDB")
local RSConfigDB = private.ImportLib("RareScannerConfigDB")

-- RareScanner libraries
local RSLogger = private.ImportLib("RareScannerLogger")
local RSUtils = private.ImportLib("RareScannerUtils")
local RSTimeUtils = private.ImportLib("RareScannerTimeUtils")
local RSConstants = private.ImportLib("RareScannerConstants")

-- RareScanner services libraries
local RSTooltip = private.ImportLib("RareScannerTooltip")
local RSEntityStateHandler = private.ImportLib("RareScannerEntityStateHandler")
local RSButtonHandler = private.ImportLib("RareScannerButtonHandler")
local RSCommandLine = private.ImportLib("RareScannerCommandLine")
local RSProvider = private.ImportLib("RareScannerProvider")
local RSWaypoints = private.ImportLib("RareScannerWaypoints")

local RARESCANNERS_CMD = "rs"

-- Next spawn timer
local RARE_CICLE = 5 --in minutes

local NEXT_RESPAWN = (RARE_CICLE * 60) --5 minutes
local MIN_TIME_TO_SKIP_RECALC = (RARE_CICLE * 60) - 30 -- 4.5 minutes
local MAX_TIME_TO_SKIP_RECALC = (RARE_CICLE * 60) + 30 -- 5.5 minutes

local TWO_MINUTES_MIDNIGHT = 42300

-- Twilight Highlands rares order (pre-patch 12.0.0)
local MIDNIGHT_RARES_SPAWNING_ORDER = {246572,246844,246460,246471,246478,246559,246549,237853,237997,246272,246343,246462,246577,246840,246565,246578,246566,246558};

local firstTimeFound = nil
local function GetNextExactSpawnTime()
    local now = C_DateAndTime.GetServerTimeLocal()
	return now + NEXT_RESPAWN
end

local function MidnightPrePatch_CalculateSpawningTimers(npcID)
	local nextSpawningNPC = nil
	if (npcID and RSUtils.Contains(MIDNIGHT_RARES_SPAWNING_ORDER, npcID)) then
		private.dbglobal.midnightSpawningTimers = {}
		local nextSpawning = GetNextExactSpawnTime()
		local initFound = false
		for i, orderNpcID in ipairs (MIDNIGHT_RARES_SPAWNING_ORDER) do
			if (not initFound and orderNpcID == npcID) then
				initFound = true
			elseif (initFound) then
				if (not nextSpawningNPC) then
					nextSpawningNPC = orderNpcID
				end
				private.dbglobal.midnightSpawningTimers[orderNpcID] = nextSpawning
				nextSpawning = nextSpawning + NEXT_RESPAWN
			end
		end

		for i, orderNpcID in ipairs (MIDNIGHT_RARES_SPAWNING_ORDER) do
			if (orderNpcID ~= npcID) then
				if (not nextSpawningNPC) then
					nextSpawningNPC = orderNpcID
				end
				private.dbglobal.midnightSpawningTimers[orderNpcID] = nextSpawning
				nextSpawning = nextSpawning + NEXT_RESPAWN
			else
				break
			end
		end

		private.dbglobal.midnightSpawningTimers[npcID] = nextSpawning
	end

	return nextSpawningNPC
end

local function GetNextMidnightRareNPC(npcID)
    local timers = private.dbglobal.midnightSpawningTimers
    if (not timers or not npcID) then
        return
    end

    -- Sort the list by timers
    local sorted = {}
    for npcID, spawnTime in pairs(timers) do
        table.insert(sorted, {id = npcID, time = spawnTime})
    end
    table.sort(sorted, function(a, b)
        return a.time < b.time
    end)

    -- Find the index in the table
    local currentIndex = nil
    for i, entry in ipairs(sorted) do
        if (entry.id == npcID) then
            currentIndex = i
            break
        end
    end

    if (not currentIndex) then
        return
    end
    
    -- Return next in the list
    local nextIndex = currentIndex + 1
    if (nextIndex > #sorted) then
        nextIndex = 1
    end

    return sorted[nextIndex].id
end

local function MidnightPrePatch_PrintNextSpawn(npcID)
	local nextSpawningNPC = GetNextMidnightRareNPC(npcID)
	if (nextSpawningNPC) then
		local name = RSNpcDB.GetNpcName(nextSpawningNPC)
		if (name) then
			local npcInfo = RSNpcDB.GetInternalNpcInfo(nextSpawningNPC)
			if (npcInfo) then
				local hyperlink = string.format("|cfff7dc6f|Haddon:RareScannerMidnight:%s:%s:%s|h[%s]|h|r", npcInfo.zoneID, npcInfo.x, npcInfo.y, AL["PRE_PATCH_ADD_WAYPOINT"])
				RSLogger:PrintMessage(string.format("%s %s", hyperlink, string.format(AL["PRE_PATCH_NEXTSPAWN"], name)))
			else
				RSLogger:PrintMessage(string.format(AL["PRE_PATCH_NEXTSPAWN"], name))
			end
	
			RSGeneralDB.SetRecentlySeen(nextSpawningNPC)
			
			-- Use the searcher to clear the map and animate only the next spawn icon
			RSGeneralDB.SetWorldMapTextFilter(name)
			RSConfigDB.SetClearingWorldMapSearcher(false)
			RSProvider.RefreshAllDataProviders()
		end
	end
end

local function MidnightPrePatch_AddNextSpawningTimerCell(tooltip, npcID)
	if (private.dbglobal.midnightSpawningTimers and private.dbglobal.midnightSpawningTimers[npcID]) then
		local timeLeft = private.dbglobal.midnightSpawningTimers[npcID] - C_DateAndTime.GetServerTimeLocal()
		if (timeLeft > 0) then
			local line = tooltip:AddLine()
			tooltip:SetCell(line, 1, string.format(AL["PRE_PATCH_SPAWNINGTIMER"], RSUtils.TextColor(RSTimeUtils.TimeStampToClock(timeLeft), "FF8000")), nil, "LEFT", 10)
		end
	end
end

local prevNpc = nil
local lastTimeFound = nil
function RareScanner:MidnightPrePatch_Initialize()
	-- Add hooks wherever we need them
	if (not RSConstants.EVENTS[RSConstants.MIDNIGHT_PRE_PATCH_EVENT]) then
		return
	end

	local original_AddAlert = RSButtonHandler.AddAlert
	function RSButtonHandler.AddAlert(button, vignetteInfo, isNavigating)
		original_AddAlert(button, vignetteInfo, isNavigating)		
		local _, _, _, _, _, id, _ = strsplit("-", vignetteInfo.objectGUID);
		local entityID = tonumber(id)
		
		-- Skip if not a pre-patch rare NPC
		if (not entityID or not RSUtils.Contains(MIDNIGHT_RARES_SPAWNING_ORDER, entityID)) then
			--RSLogger:PrintDebugMessage("No recalcula porque no es rare del evento.")
			return
		end
		
		-- Skip if not found in this session but the timer in the database didn't expire yet or it isn't wrong
		if (not prevNpc and private.dbglobal.midnightSpawningTimers and private.dbglobal.midnightSpawningTimers[entityID] and private.dbglobal.midnightSpawningTimers[entityID] - C_DateAndTime.GetServerTimeLocal() > MIN_TIME_TO_SKIP_RECALC) then
			prevNpc = entityID
			--RSLogger:PrintDebugMessage("No recalcula tiempos porque el tiempo no ha expirado todavia o no se encuentra desfasado.")
			return
		end
		
		-- Skip if not found in the current session or the cooldown didn't expire yet
		if ((prevNpc and prevNpc == entityID) or (lastTimeFound and C_DateAndTime.GetServerTimeLocal() - lastTimeFound >= MAX_TIME_TO_SKIP_RECALC)) then
			--RSLogger:PrintDebugMessage("No recalcula porque este NPC se ha encontrado en esta sesion, o no se le ha encontrado hace mas de 10 minutos.")
			return
		end
		
		if (not prevNpc) then
			RSLogger:PrintMessage(AL["PRE_PATCH_FIRST_FOUND"])
		end
		
		prevNpc = entityID
		lastTimeFound = C_DateAndTime.GetServerTimeLocal()
		MidnightPrePatch_CalculateSpawningTimers(entityID);
	end

	local original_SetDeadNpcByZone = RSEntityStateHandler.SetDeadNpcByZone
	function RSEntityStateHandler.SetDeadNpcByZone(npcID, mapID, loadingAddon)
		original_SetDeadNpcByZone(npcID, mapID, loadingAddon)
		MidnightPrePatch_PrintNextSpawn(npcID)
	end

	local original_AddSpecialEventsLines = RSTooltip.AddSpecialEventsLines
	function RSTooltip.AddSpecialEventsLines(pin, tooltip)
		original_AddSpecialEventsLines(pin, tooltip);
		MidnightPrePatch_AddNextSpawningTimerCell(tooltip, pin.POI.entityID)
	end

	local original_PrintHelp = RSCommandLine.PrintHelp
	function RSCommandLine.PrintHelp()
		original_PrintHelp()
		print("|cFFFBFF00   /"..RARESCANNERS_CMD.." "..RSConstants.CMD_MIDNIGHT_PRE_PATCH.." |cFF00FFFB"..AL["CMD_HELP_MIDNIGHT_PRE_PATCH"])
	end
	
	local original_SlashCommand = RSCommandLine.SlashCommand
	function RSCommandLine.SlashCommand(command, ...)
		if (command == RSConstants.CMD_MIDNIGHT_PRE_PATCH) then
			if (not private.dbglobal.midnightSpawningTimers) then
				RSLogger:PrintMessage(AL["PRE_PATCH_MIDNIGHT_NO_TIMERS"])
				return
			end
			
			local spawnTimers = {}
			for _, npcID in ipairs(MIDNIGHT_RARES_SPAWNING_ORDER) do
				local spawnTime = private.dbglobal.midnightSpawningTimers[npcID]
			    if (spawnTime and spawnTime - C_DateAndTime.GetServerTimeLocal() > 0) then
			        table.insert(spawnTimers, {
			            npcID = npcID,
			            time = spawnTime
			        })
			    end
			end
			
			if (RSUtils.GetTableLength(spawnTimers) > 0) then
				table.sort(spawnTimers, function(a, b)
				    return a.time < b.time
				end)
				
				local achievementNumCriteria = GetAchievementNumCriteria(TWO_MINUTES_MIDNIGHT)				
				for _, spawnTimer in ipairs(spawnTimers) do
					local completed = false
					for i = 1, achievementNumCriteria do
						local criteriaString, _, _completed, _, _, _, _, assetID, _, _, _, _, _ = GetAchievementCriteriaInfo(TWO_MINUTES_MIDNIGHT, i)
						if (assetID == spawnTimer.npcID) then
							completed = _completed
							break
						end
					end
					
					if (completed) then
						RSLogger:PrintMessage(string.format("[%s]: %s", RSTimeUtils.TimeStampToClock(spawnTimer.time, false, true), RSNpcDB.GetNpcName(spawnTimer.npcID)))
					else
						RSLogger:PrintMessage(string.format(AL["PRE_PATCH_MIDNIGHT_MISSING"], RSTimeUtils.TimeStampToClock(spawnTimer.time, false, true), RSNpcDB.GetNpcName(spawnTimer.npcID)))
					end
				end
			else
				RSLogger:PrintMessage(AL["PRE_PATCH_MIDNIGHT_NO_TIMERS"])
			end
		else
			original_SlashCommand(command, ...)
		end
	end

	hooksecurefunc(WorldMapFrame, "Show", function()
		if (WorldMapFrame:IsShown()) then
			RSGeneralDB.SetWorldMapTextFilter(nil)
			RSConfigDB.SetClearingWorldMapSearcher(true)
		end
	end)
	
	hooksecurefunc("SetItemRef", function(link, text, button, chatFrame)
		local linkType, addon, mapID, x, y = strsplit(":", link)
		if (linkType == "addon" and addon == "RareScannerMidnight") then
			 RSWaypoints.AddIngameWaypoint(mapID, x, y)
		end
	end)
end