-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local ADDON_NAME, private = ...

local RSRespawnTracker = private.NewLib("RareScannerRespawnTracker")

-- RareScanner database libraries
local RSNpcDB = private.ImportLib("RareScannerNpcDB")
local RSContainerDB = private.ImportLib("RareScannerContainerDB")
local RSEventDB = private.ImportLib("RareScannerEventDB")

-- RareScanner internal libraries
local RSConstants = private.ImportLib("RareScannerConstants")
local RSRoutines = private.ImportLib("RareScannerRoutines")
local RSLogger = private.ImportLib("RareScannerLogger")

-- RareScanner services
local RSEntityStateHandler = private.ImportLib("RareScannerEntityStateHandler")
local RSMinimap = private.ImportLib("RareScannerMinimap")
local RSProvider = private.ImportLib("RareScannerProvider")

-- Timers
local CHECK_RESPAWN_TIMER

---============================================================================
-- Tracks respawning
---============================================================================
		
local function CheckRespawnTimers()
	local routines = {}
	local hasAnyRespawned = false

	local checkRespawnNpcsRoutine = RSRoutines.LoopRoutineNew()
	checkRespawnNpcsRoutine:Init(
		function() return RSNpcDB.GetAllNpcsKilledRespawnTimes() end,
		function(context, npcID, respawnTime)
			local npcInfo = RSNpcDB.GetInternalNpcInfo(npcID)
		
			if (respawnTime > 0 and respawnTime < time()) then
				-- If the associated quest is completed it means that this rare NPC is still dead
				-- It's possible that the quest takes a little bit longer to reset, so check for this NPC later
				local hasRespawn = true
				if (npcInfo and npcInfo.questID) then
					local questCompleted = false
					for _, questID in ipairs (npcInfo.questID) do
						if (npcInfo.onlyWb and C_QuestLog.IsQuestFlaggedCompletedOnAccount(questID)) then
							questCompleted = true
							break
						elseif (not npcInfo.onlyWb and C_QuestLog.IsQuestFlaggedCompleted(questID)) then
							questCompleted = true
							break
						end
					end
					
					if (questCompleted) then
						RSLogger:PrintDebugMessageEntityID(npcID, string.format("CheckRespawnTimers [NPC: %s], sigue muerto acorde a su quest", npcID))
						
						-- If the threshold has already passed (or the reset was hours ago), reschedule for next reset cycle
						if (respawnTime + RSConstants.CHECK_RESPAWN_THRESHOLD < time()) then
							RSEntityStateHandler.SetDeadNpc(npcID, nil, true)
						end
						
						hasRespawn = false
					end
				end
	
				if (hasRespawn) then
					RSLogger:PrintDebugMessageEntityID(npcID, string.format("CheckRespawnTimers [NPC: %s]. Respawn!", npcID))
					RSNpcDB.DeleteNpcKilled(npcID)
					RSMinimap.RefreshEntityState(npcID)
					hasAnyRespawned = true
				end
			end
		end)
	tinsert(routines, checkRespawnNpcsRoutine)

	-- Look for containers that have already respawn
	local checkRespawnContainersRoutine = RSRoutines.LoopRoutineNew()
	checkRespawnContainersRoutine:Init(
		function() return RSContainerDB.GetAllContainersOpenedRespawnTimes() end,
		function(context, containerID, respawnTime)
			local containerInfo = RSContainerDB.GetInternalContainerInfo(containerID)
				
			if (respawnTime > 0 and respawnTime < time()) then
				-- If the associated quest is completed it means that this container is still closed
				-- It's possible that the quest takes a little bit longer to reset, so check for this container later
				local hasRespawn = true
				if (containerInfo and containerInfo.questID) then
					local questCompleted = false
					for _, questID in ipairs (containerInfo.questID) do
						if (containerInfo.onlyWb and C_QuestLog.IsQuestFlaggedCompletedOnAccount(questID)) then
							questCompleted = true
							break
						elseif (not containerInfo.onlyWb and C_QuestLog.IsQuestFlaggedCompleted(questID)) then
							questCompleted = true
							break
						end
					end
					
					if (questCompleted) then
						RSLogger:PrintDebugMessage(string.format("CheckRespawnTimers [Contenedor: %s], sigue cerrado acorde a su quest", containerID))
						
						-- If the threshold has already passed (or the reset was hours ago), reschedule for next reset cycle
						if (respawnTime + RSConstants.CHECK_RESPAWN_THRESHOLD < time()) then
							RSEntityStateHandler.SetContainerOpen(containerID, nil, true)
						end
						
						hasRespawn = false
					end
				end
	
				if (hasRespawn) then
					RSLogger:PrintDebugMessage(string.format("CheckRespawnTimers [Contenedor: %s]. Respawn!", containerID))
					RSContainerDB.DeleteContainerOpened(containerID)
					RSMinimap.RefreshEntityState(containerID)
					hasAnyRespawned = true
				end
			end
		end)
	tinsert(routines, checkRespawnContainersRoutine)

	-- Look for events that have already respawn
	local checkRespawnEventsRoutine = RSRoutines.LoopRoutineNew()
	checkRespawnEventsRoutine:Init(
		function() return RSEventDB.GetAllEventsCompletedRespawnTimes() end,
		function(context, eventID, respawnTime)
			local eventInfo = RSEventDB.GetInternalEventInfo(eventID)
			
			if (respawnTime > 0 and respawnTime < time()) then
				local hasRespawn = true
				if (eventInfo and eventInfo.questID) then
					local questCompleted = false
					for _, questID in ipairs (eventInfo.questID) do
						if (eventInfo.onlyWb and C_QuestLog.IsQuestFlaggedCompletedOnAccount(questID)) then
							questCompleted = true
							break
						elseif (not eventInfo.onlyWb and C_QuestLog.IsQuestFlaggedCompleted(questID)) then
							questCompleted = true
							break
						end
					end
						
					if (questCompleted) then
						RSLogger:PrintDebugMessage(string.format("CheckRespawnTimers [Evento: %s], sigue completo acorde a su quest", eventID))
						
						-- If the threshold has already passed (or the reset was hours ago), reschedule for next reset cycle
						if (respawnTime + RSConstants.CHECK_RESPAWN_THRESHOLD < time()) then
							RSEntityStateHandler.SetEventCompleted(eventID, nil, true)
						end
						
						hasRespawn = false
					end
				end

				if (hasRespawn) then
					RSLogger:PrintDebugMessage(string.format("CheckRespawnTimers [Evento: %s]. Respawn!", eventID))
					RSEventDB.DeleteEventCompleted(eventID)
					RSMinimap.RefreshEntityState(eventID)
					hasAnyRespawned = true
				end
			end
		end)
	tinsert(routines, checkRespawnEventsRoutine)
	
	local chainRoutines = RSRoutines.ChainLoopRoutineNew()
	chainRoutines:Init(routines)
	chainRoutines:Run(function(context)
		if (hasAnyRespawned and WorldMapFrame:IsShown()) then
			RSProvider.RefreshAllDataProviders()
		end
	end)
end

---============================================================================
-- Checks eternal dead entities once per session to fix mistakes
---============================================================================

local function CheckEternalEntities()
	local routines = {}
	local hasAnyEternalRespawned = false

	local checkEternalNpcsRoutine = RSRoutines.LoopRoutineNew()
	checkEternalNpcsRoutine:Init(
		function() return RSNpcDB.GetAllNpcsKilledRespawnTimes() end,
		function(context, npcID, respawnTime)
			if (respawnTime == RSConstants.ETERNAL_DEATH) then
				local npcInfo = RSNpcDB.GetInternalNpcInfo(npcID)
				if (npcInfo and npcInfo.questID and (npcInfo.reset == nil or npcInfo.reset)) then
					local questCompleted = false
					for _, questID in ipairs (npcInfo.questID) do
						if (npcInfo.onlyWb and C_QuestLog.IsQuestFlaggedCompletedOnAccount(questID)) then
							questCompleted = true
							break
						elseif (not npcInfo.onlyWb and C_QuestLog.IsQuestFlaggedCompleted(questID)) then
							questCompleted = true
							break
						end
					end

					if (not questCompleted) then
						RSLogger:PrintDebugMessageEntityID(npcID, string.format("CheckEternalEntities [NPC: %s]. Auto-correccion de ETERNAL_DEATH. Respawn!", npcID))
						RSNpcDB.DeleteNpcKilled(npcID)
						RSMinimap.RefreshEntityState(npcID)
						hasAnyEternalRespawned = true
					end
				end
			end
		end)
	tinsert(routines, checkEternalNpcsRoutine)

	local checkEternalContainersRoutine = RSRoutines.LoopRoutineNew()
	checkEternalContainersRoutine:Init(
		function() return RSContainerDB.GetAllContainersOpenedRespawnTimes() end,
		function(context, containerID, respawnTime)
			if (respawnTime == RSConstants.ETERNAL_OPENED) then
				local containerInfo = RSContainerDB.GetInternalContainerInfo(containerID)
				if (containerInfo and containerInfo.questID and (containerInfo.reset == nil or containerInfo.reset)) then
					local questCompleted = false
					for _, questID in ipairs (containerInfo.questID) do
						if (containerInfo.onlyWb and C_QuestLog.IsQuestFlaggedCompletedOnAccount(questID)) then
							questCompleted = true
							break
						elseif (not containerInfo.onlyWb and C_QuestLog.IsQuestFlaggedCompleted(questID)) then
							questCompleted = true
							break
						end
					end

					if (not questCompleted) then
						RSLogger:PrintDebugMessage(string.format("CheckEternalEntities [Contenedor: %s]. Auto-correccion de ETERNAL_OPENED. Respawn!", containerID))
						RSContainerDB.DeleteContainerOpened(containerID)
						RSMinimap.RefreshEntityState(containerID)
						hasAnyEternalRespawned = true
					end
				end
			end
		end)
	tinsert(routines, checkEternalContainersRoutine)

	local checkEternalEventsRoutine = RSRoutines.LoopRoutineNew()
	checkEternalEventsRoutine:Init(
		function() return RSEventDB.GetAllEventsCompletedRespawnTimes() end,
		function(context, eventID, respawnTime)
			if (respawnTime == RSConstants.ETERNAL_COMPLETED) then
				local eventInfo = RSEventDB.GetInternalEventInfo(eventID)
				if (eventInfo and eventInfo.questID and (eventInfo.reset == nil or eventInfo.reset)) then
					local questCompleted = false
					for _, questID in ipairs (eventInfo.questID) do
						if (eventInfo.onlyWb and C_QuestLog.IsQuestFlaggedCompletedOnAccount(questID)) then
							questCompleted = true
							break
						elseif (not eventInfo.onlyWb and C_QuestLog.IsQuestFlaggedCompleted(questID)) then
							questCompleted = true
							break
						end
					end

					if (not questCompleted) then
						RSLogger:PrintDebugMessage(string.format("CheckEternalEntities [Evento: %s]. Auto-correccion de ETERNAL_COMPLETED. Respawn!", eventID))
						RSEventDB.DeleteEventCompleted(eventID)
						RSMinimap.RefreshEntityState(eventID)
						hasAnyEternalRespawned = true
					end
				end
			end
		end)
	tinsert(routines, checkEternalEventsRoutine)

	local chainRoutines = RSRoutines.ChainLoopRoutineNew()
	chainRoutines:Init(routines)
	chainRoutines:Run(function(context)
		if (hasAnyEternalRespawned and WorldMapFrame:IsShown()) then
			RSProvider.RefreshAllDataProviders()
		end
	end)
end

local isTrackerInitialized = false

function RSRespawnTracker.Init()
	if (isTrackerInitialized) then
		return
	end
	isTrackerInitialized = true

	CheckRespawnTimers()

	if (not CHECK_RESPAWN_TIMER) then
		CHECK_RESPAWN_TIMER = C_Timer.NewTicker(RSConstants.CHECK_RESPAWN_TIMER, function()
			CheckRespawnTimers()
		end)
	end

	-- Check eternal entities ONLY ONCE per session to fix entities tagged dead by mistake
	CheckEternalEntities()
end
