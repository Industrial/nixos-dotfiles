-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local LibStub = _G.LibStub
local ADDON_NAME, private = ...

local RSEventHandler = private.NewLib("RareScannerEventHandler")

-- RareScanner database libraries
local RSConfigDB = private.ImportLib("RareScannerConfigDB")
local RSGeneralDB = private.ImportLib("RareScannerGeneralDB")
local RSMapDB = private.ImportLib("RareScannerMapDB")
local RSNpcDB = private.ImportLib("RareScannerNpcDB")
local RSDragonGlyphDB = private.ImportLib("RareScannerDragonGlyphDB")
local RSContainerDB = private.ImportLib("RareScannerContainerDB")
local RSCollectionsDB = private.ImportLib("RareScannerCollectionsDB")
local RSAchievementDB = private.ImportLib("RareScannerAchievementDB")

-- RareScanner services
local RSButtonHandler = private.ImportLib("RareScannerButtonHandler")
local RSMinimap = private.ImportLib("RareScannerMinimap")
local RSEntityStateHandler = private.ImportLib("RareScannerEntityStateHandler")
local RareScannerBlizzardMapProvider
local RSMacro = private.ImportLib("RareScannerMacro")

-- RareScanner internal libraries
local RSConstants = private.ImportLib("RareScannerConstants")
local RSLogger = private.ImportLib("RareScannerLogger")
local RSUtils = private.ImportLib("RareScannerUtils")
local RSRoutines = private.ImportLib("RareScannerRoutines")


---============================================================================
-- Handle entities without vignette
---============================================================================

local function HandleEntityWithoutVignette(rareScannerButton, unitID, trackingSystem)
	if (not unitID) then
		return
	end
	
	local unitGuid = UnitGUID(unitID)
	if (issecretvalue(unitGuid) or not unitGuid) then
		return
	end
	
	local unitType, _, _, _, _, entityID = strsplit("-", unitGuid)
	if (unitType == "Creature" or unitType == "Vehicle") then
		local npcID = entityID and tonumber(entityID) or nil
		
		-- Ignore if friendly
		if (RSUtils.Contains(RSConstants.IGNORED_FRIENDLY_NPCS, npcID) and UnitIsFriend("player", unitID)) then
			RSLogger:PrintDebugMessage(string.format("Ignorado[%s] por ser amistoso.", npcID))
			return
		end
		
		-- If its a supported NPC and its not killed
		if ((RSGeneralDB.GetAlreadyFoundEntity(npcID, RSConstants.NPC_VIGNETTE) or RSNpcDB.GetInternalNpcInfo(npcID)) and not UnitIsDead(unitID)) then
			local nameplateUnitName, _ = UnitName(unitID)
			if (issecretvalue(nameplateUnitName) or not nameplateUnitName or nameplateUnitName == UNKNOWNOBJECT) then
				nameplateUnitName = RSNpcDB.GetNpcName(npcID)
			end
			
			local mapID = C_Map.GetBestMapForUnit("player")
			if (not mapID) then
				return
			end
			
			local x, y = RSNpcDB.GetBestInternalNpcCoordinates(npcID, mapID)
			rareScannerButton:SimulateRareFound(npcID, unitGuid, nameplateUnitName, x, y, RSConstants.NPC_VIGNETTE, trackingSystem)
		end
	elseif (unitType == "Object" or unitType == "GameObject") then
		local containerID = entityID and tonumber(entityID) or nil
		if (not containerID) then
			return
		end

		local containerName = UnitName(unitID)
		local containerDbName = RSContainerDB.GetContainerName(containerID)
		-- If the container didn't have a vignette this is the last chance to get the name
		if (containerName and not issecretvalue(containerName) and containerName ~= UNKNOWNOBJECT and containerDbName ~= containerName) then
			RSContainerDB.SetContainerName(containerID, containerName)
		end
		
		-- If it's a supported container and not completed/opened
		if (RSGeneralDB.GetAlreadyFoundEntity(containerID, RSConstants.CONTAINER_VIGNETTE) or RSContainerDB.GetInternalContainerInfo(containerID)) then
			-- Don't trigger if it's already opened and user ignores completed entities
			if (RSConfigDB.IsIgnoringCompletedEntities() and RSContainerDB.IsContainerOpened(containerID)) then
				return
			end
			
			local mapID = C_Map.GetBestMapForUnit("player")
			if (not mapID) then
				return
			end
			
			local x, y = RSContainerDB.GetBestInternalContainerCoordinates(containerID, mapID)
			local finalContainerName = (containerName and not issecretvalue(containerName) and containerName ~= UNKNOWNOBJECT) and containerName or containerDbName or AL["CONTAINER"]
			rareScannerButton:SimulateRareFound(containerID, unitGuid, finalContainerName, x, y, RSConstants.CONTAINER_VIGNETTE, trackingSystem)
		end
	end
end

---============================================================================
-- Event: VIGNETTE_MINIMAP_UPDATED
-- Fired when a vignette appears in the minimap
---============================================================================

local function OnVignetteMinimapUpdated(rareScannerButton, vignetteID)
	-- Get viggnette data
	local vignetteInfo = C_VignetteInfo.GetVignetteInfo(vignetteID)
	if (not vignetteInfo) then
		return
	else
		vignetteInfo.id = vignetteID
		RSButtonHandler.AddAlert(rareScannerButton, vignetteInfo)
	end
end

---============================================================================
-- Event: VIGNETTES_UPDATED
-- Fired when a vignette appears in the worldmap
---============================================================================

local function OnVignettesUpdated(rareScannerButton)
	if (not RSConfigDB.IsScanningWorldMapVignettes()) then
		return
	end

	local vignetteGUIDs = C_VignetteInfo.GetVignettes();
	for _, vignetteGUID in ipairs(vignetteGUIDs) do
		local vignetteInfo = C_VignetteInfo.GetVignetteInfo(vignetteGUID);
		if (vignetteInfo and vignetteInfo.onWorldMap) then
			vignetteInfo.id = vignetteGUID
			RSButtonHandler.AddAlert(rareScannerButton, vignetteInfo)
		end
	end
end

---============================================================================
-- Event: NAME_PLATE_UNIT_ADDED
-- Fired when a nameplate appears
---============================================================================

local function OnNamePlateUnitAdded(rareScannerButton, namePlateID)
	local unitIsPlayer = UnitIsUnit("player", namePlateID)
	if (namePlateID and not issecretvalue(unitIsPlayer) and not unitIsPlayer) then
		HandleEntityWithoutVignette(rareScannerButton, namePlateID, RSConstants.TRACKING_SYSTEM.NAMEPLATE_MOUSEOVER)
	end
end

---============================================================================
-- Event: UPDATE_MOUSEOVER_UNIT
-- Fired when mouseovering a unit
---============================================================================

local function OnUpdateMouseoverUnit(rareScannerButton)
	local unitIsPlayer = UnitIsUnit("player", "mouseover")
	local unitIsDead = UnitIsDead("mouseover")
	if (not issecretvalue(unitIsPlayer) and not unitIsPlayer and not issecretvalue(unitIsDead) and not unitIsDead) then
		HandleEntityWithoutVignette(rareScannerButton, "mouseover", RSConstants.TRACKING_SYSTEM.NAMEPLATE_MOUSEOVER)
	end
end

---============================================================================
-- Event: PLAYER_REGEN_ENABLED
-- Fired when the player leaves combat
---============================================================================

local function OnPlayerRegenEnabled(rareScannerButton)
	if (rareScannerButton.pendingToShow) then
		rareScannerButton.pendingToShow = nil
		rareScannerButton.pendingToHide = nil -- just in case it was pending too
		rareScannerButton:ShowButton()
	elseif (rareScannerButton.pendingToHide) then
		rareScannerButton.pendingToHide = nil
		rareScannerButton:HideButton()
	end
end

---============================================================================
-- Event: PARTY_KILL
-- Fired when a NPC dies
---============================================================================

local function OnPartyKill(attackerUnitguid, targetGUID)
	if (not issecretvalue(targetGUID) and targetGUID) then
		local npcID = C_CreatureInfo.GetCreatureID(targetGUID)
		if (not npcID) then
			return
		end
		
		local npcInfo = RSNpcDB.GetInternalNpcInfo(npcID)
		if (npcInfo) then
			RSEntityStateHandler.SetDeadNpc(npcID)
			RSNpcDB.IncreaseTimesKilled(targetGUID)
		end
	end
end

---============================================================================
-- Event: PLAYER_TARGET_CHANGED
-- Fired when changing the target
---============================================================================

local function OnPlayerTargetChanged(rareScannerButton)
	local unitExists = UnitExists("target")
	local unitIsPlayer = UnitIsUnit("player", "target")
	local unitIsDead = UnitIsDead("target")
	if (not issecretvalue(unitExists) and unitExists and not issecretvalue(unitIsPlayer) and not unitIsPlayer and not issecretvalue(unitIsDead) and not unitIsDead) then
		HandleEntityWithoutVignette(rareScannerButton, "target", RSConstants.TRACKING_SYSTEM.UNIT_TARGET)
		
		-- Update coordinates if the NPC doesnt have a vignette
		local targetUid = UnitGUID("target")
		if (not issecretvalue(targetUid) and not InCombatLockdown()) then
			local npcID = C_CreatureInfo.GetCreatureID(targetUid)
			local npcInfo = npcID and RSNpcDB.GetInternalNpcInfo(npcID)
			
			if (npcInfo and CheckInteractDistance("target", 4)) then
				local playerMapID = C_Map.GetBestMapForUnit("player")
				if (playerMapID and (RSMapDB.IsZoneWithoutVignette(playerMapID) or npcInfo.noVignette)) then
					RSGeneralDB.UpdateAlreadyFoundEntityPlayerPosition(npcID, RSConstants.NPC_VIGNETTE)
				end
			end
		end
	end
end

---============================================================================
-- Event: PLAYER_SOFT_INTERACT_CHANGED
-- Fired when soft interact unit changes
---============================================================================

local function OnPlayerSoftInteractChanged(rareScannerButton)
	if (not RSConfigDB.IsScanningSoftInteract()) then
		return
	end

	local unitExists = UnitExists("softinteract")
	local unitIsPlayer = UnitIsUnit("player", "softinteract")
	local unitIsDead = UnitIsDead("softinteract")
	if (not issecretvalue(unitExists) and unitExists and not issecretvalue(unitIsPlayer) and not unitIsPlayer and not issecretvalue(unitIsDead) and not unitIsDead) then
		HandleEntityWithoutVignette(rareScannerButton, "softinteract", RSConstants.TRACKING_SYSTEM.SOFT_INTERACT)
	end
end

---============================================================================
-- Event: LOOT_OPENED
-- Fired when looting some entity
---============================================================================

local function RecordLoot(i, entityID, isNpc, isContainer)
	local itemLink = GetLootSlotLink(i)
	if (itemLink) then
		local _, _, _, lootType, id = string.find(itemLink, "|cnIQ?(%d*):|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")
		if (lootType == "item") then
		local itemID = id and tonumber(id) or nil
			if (isContainer) then
				RSContainerDB.AddItemToContainerLootFound(entityID, itemID)
			elseif (isNpc) then
				RSNpcDB.AddItemToNpcLootFound(entityID, itemID)
			end
		end
	end
end

local function OnLootOpened()
	local numItems = GetNumLootItems()
	if (not numItems or numItems <= 0) then
		return
	end

	local looted = false
	for i = 1, numItems do
		if (LootSlotHasItem(i)) then
			local destGUID = GetLootSourceInfo(i)
			local unitType, _, _, _, _, id = strsplit("-", destGUID)

			-- If the loot comes from a container that we support
			if (unitType == "GameObject") then
				local containerID = id and tonumber(id) or nil
				RSLogger:PrintDebugMessage(string.format("Abierto [%s].", containerID or ""))

				-- We support all the containers with vignette plus those ones that are part of achievements (without vignette)
				if (RSGeneralDB.GetAlreadyFoundEntity(containerID, RSConstants.CONTAINER_VIGNETTE) or RSContainerDB.GetInternalContainerInfo(containerID)) then
					if (not looted) then
						-- Check if we have the Container in our database but the addon didnt detect it
						-- This will happend in the case where the container doesnt have a vignette
						if (not RSGeneralDB.GetAlreadyFoundEntity(containerID, RSConstants.CONTAINER_VIGNETTE)) then
							RSGeneralDB.AddAlreadyFoundContainerWithoutVignette(containerID)
						else
							RSGeneralDB.UpdateAlreadyFoundEntityPlayerPosition(containerID, RSConstants.CONTAINER_VIGNETTE)
						end
					
						RSEntityStateHandler.SetContainerOpen(containerID)
						RSContainerDB.IncreaseTimesOpened(destGUID)
						looted = true
					end

					-- Records the loot obtained
					RecordLoot(i, containerID, false, true)
				end
			-- If the loot comes from a creature that we support
			elseif (unitType == "Creature") then
				local npcID = id and tonumber(id) or nil
				
				-- If its a supported NPC
				if (RSGeneralDB.GetAlreadyFoundEntity(npcID, RSConstants.NPC_VIGNETTE) or RSNpcDB.GetInternalNpcInfo(npcID)) then
					if (not looted) then
						RSGeneralDB.UpdateAlreadyFoundEntityPlayerPosition(npcID, RSConstants.NPC_VIGNETTE)
						RSEntityStateHandler.SetDeadNpc(npcID)
						RSNpcDB.IncreaseTimesKilled(destGUID)
						looted = true
					end
					
					-- Records the loot obtained
					RecordLoot(i, npcID, false, true)
				end
			end
		end
	end
end

---============================================================================
-- Event: CHAT_MSG_MONSTER_EMOTE
-- Event: CHAT_MSG_MONSTER_YELL
-- Fired when a monster emotes (red/brown message on chat)
---============================================================================
local function SimulateRareFound(rareScannerButton, npcID, mapID, name)
	if (RSNpcDB.GetInternalNpcInfo(npcID)) then
		local x, y = RSNpcDB.GetBestInternalNpcCoordinates(npcID, mapID)
		if (not x or not y) then
			x, y = RSNpcDB.GetInternalNpcCoordinates(npcID, mapID)
		end
		if (not x or not y) then
			return
		end
		
		rareScannerButton:SimulateRareFound(npcID, nil, name, x, y, RSConstants.NPC_VIGNETTE, RSConstants.TRACKING_SYSTEM.CHAT_EMOTE)
	end
end

local function OnChatMsgMonster(rareScannerButton, message, name, guid)
	-- If not disabled
	if (not RSConfigDB.IsScanningChatAlerts()) then
		return
	end
	
	if (issecretvalue(message)) then
		return
	end
	
	RSLogger:PrintDebugMessage(string.format("CHAT_MSG_MONSTER: [MESSAGE:%s]", message))
	
	local mapID = C_Map.GetBestMapForUnit("player")
	if (not mapID) then
		return
	end
	
	RSLogger:PrintDebugMessage(string.format("CHAT_MSG_MONSTER: [MAPID:%s]", mapID))
	
	-- Try to analyze the GUID
	if (guid) then
		RSLogger:PrintDebugMessage(string.format("CHAT_MSG_MONSTER: [GUID:%s]", guid))
		
		local npcID = C_CreatureInfo.GetCreatureID(guid)
		if (npcID) then
			local finalNpcID = RSNpcDB.GetFinalNpcID(npcID)
			SimulateRareFound(rareScannerButton, finalNpcID, mapID, RSNpcDB.GetNpcName(finalNpcID))
			return
		end
	end
	
	-- Try to analyze the Name
	if (name) then
		RSLogger:PrintDebugMessage(string.format("CHAT_MSG_MONSTER: [NAME:%s]", name))
		
		local npcID = RSNpcDB.GetNpcId(name, mapID)
		if (npcID) then
			SimulateRareFound(rareScannerButton, npcID, mapID, name)
			return
		end
	end
	
	-- Otherwise analyze the message
	if (mapID == RSConstants.MECHAGON_MAPID or mapID == RSConstants.RINGING_DEEPS or mapID == RSConstants.AZJ_KAHET1 or mapID == RSConstants.AZJ_KAHET2 or mapID == RSConstants.AZJ_KAHET3 or mapID == RSConstants.AZJ_KAHET4) then
		for msg, npcID in pairs(private.MONSTER_EMOTE) do
			if (RSUtils.Contains(message, msg)) then
				RSLogger:PrintDebugMessage(string.format("CHAT_MSG_MONSTER: [FOUND:%s]", npcID))
				SimulateRareFound(rareScannerButton, npcID, mapID, RSNpcDB.GetNpcName(npcID))
				return
			end
		end
	end
end

---============================================================================
-- Event: QUEST_TURNED_IN
-- Fired when a quest is turned in
---============================================================================

local function OnQuestTurnedIn(rareScannerButton, questID, xpReward, moneyReward)
	RSLogger:PrintDebugMessage(string.format("Misión [%s]. Completada.", questID))
	RSGeneralDB.SetCompletedQuest(questID)

	-- Checks if its an event
	local foundDebug = false
	for eventID, eventInfo in pairs (private.EVENT_INFO) do
		if (eventInfo.questID and RSUtils.Contains(eventInfo.questID, questID)) then
			RSEntityStateHandler.SetEventCompleted(eventID)
			foundDebug = true
			return
		end
	end

	if (RSConstants.DEBUG_MODE and not foundDebug) then
		RSLogger:PrintDebugMessage("DEBUG: Mision completada que no existe en EVENT_QUEST_IDS "..questID)
	end
end

---============================================================================
-- Event: CINEMATIC_START
-- Fired when a cinematic starts
---============================================================================

local function OnCinematicStart(rareScannerButton)
	RSGeneralDB.SetCinematicPlaying(true)

	if (rareScannerButton:IsVisible()) then
		rareScannerButton:HideButton()
	end
end

---============================================================================
-- Event: CINEMATIC_STOP
-- Fired when a cinematic stops
---============================================================================

local function OnCinematicStop(rareScannerButton)
	RSGeneralDB.SetCinematicPlaying(false)
	
	local mapID = C_Map.GetBestMapForUnit("player")
	if (not mapID) then
		return
	end
	
	-- High peaks reproduce a video when you interact with them
	local achievementCriteriaRoutine = RSRoutines.LoopRoutineNew()
	achievementCriteriaRoutine:Init(
		function() return private.ACHIEVEMENT_HIGH_PEAKS end,
		function(context, _, achievementID)
			local parentMapID = mapID
			while (not private.ACHIEVEMENT_ZONE_IDS[parentMapID] and parentMapID) do
				parentMapID = RSMapDB.GetParentMapID(parentMapID)
			end
			
			if (parentMapID and private.ACHIEVEMENT_ZONE_IDS[parentMapID] and RSUtils.Contains(private.ACHIEVEMENT_ZONE_IDS[parentMapID], achievementID)) then
				local found = false
				for _, containerID in ipairs(private.ACHIEVEMENT_TARGET_IDS[achievementID]) do
					if (found) then
						break
					end
					
					if (not RSContainerDB.IsContainerOpened(containerID)) then
						local containerInfo = RSContainerDB.GetInternalContainerInfo(containerID)
						if (containerInfo and containerInfo.questID) then
							for _, questID in ipairs (containerInfo.questID) do
								if (C_QuestLog.IsQuestFlaggedCompleted(questID)) then
									RSLogger:PrintDebugMessage(string.format("Contenedor (high peak) [%s][%s]. Completada mision [%s].", achievementID, containerID, questID))
									RSContainerDB.SetContainerOpened(containerID)
									RSMinimap.RefreshEntityState(containerID)
									found = true
									break
								end
							end	
						end
					end
				end
			end
		end, 
		function(context)
			RSLogger:PrintDebugMessage("OnCinematicStop ejecutado")
		end
	)
	
	achievementCriteriaRoutine:Run()
end

---============================================================================
-- Event: NEW_MOUNT_ADDED
-- Fired when a new mount is added to the collection
---============================================================================

local function OnNewMountAdded(mountID)
	RSCollectionsDB.RemoveNotCollectedMount(mountID, function()
		RSExplorerFrame:Refresh()
	end)
end

---============================================================================
-- Event: NEW_PET_ADDED
-- Fired when a new pet is added to the collection
---============================================================================

local function OnNewPetAdded(petGUID)
	RSCollectionsDB.RemoveNotCollectedPet(petGUID, function()
		RSExplorerFrame:Refresh()
	end)
end

---============================================================================
-- Event: NEW_TOY_ADDED
-- Fired when a new toy is added to the collection
---============================================================================

local function OnNewToyAdded(itemID)
	RSCollectionsDB.RemoveNotCollectedToy(itemID, function()
		RSExplorerFrame:Refresh()
	end)
end

---============================================================================
-- Event: TRANSMOG_COLLECTION_UPDATED
-- Fired when a new appearance is added to the collection
---============================================================================

local function OnTransmogCollectionUpdated()
	local latestAppearanceID, _ = C_TransmogCollection.GetLatestAppearance();
	RSCollectionsDB.RemoveNotCollectedAppearance(latestAppearanceID, function()
		RSExplorerFrame:Refresh()
	end)
end

---============================================================================
-- Event: HOUSE_DECOR_ADDED_TO_CHEST
-- Fired when a new decor is added to the collection
---============================================================================

local function OnHouseDecorAddedToChest(decorGUID, decorID)
	RSCollectionsDB.RemoveNotCollectedDecor(decorID, function()
		RSExplorerFrame:Refresh()
	end)
end

---============================================================================
-- Event: ACHIEVEMENT_EARNED
-- Fired when a new achievement is earned
---============================================================================

local function OnAchievementEarned(achievementID)
	if (achievementID and RSDragonGlyphDB.GetInternalDragonGlyphInfo(achievementID)) then
		RSLogger:PrintDebugMessage(string.format("Logro de glifo [%s]. Completado.", achievementID))
		RSDragonGlyphDB.SetDragonGlyphCollected(achievementID)
		RSMinimap.HideIcon(achievementID)
	end
end

local function OnAchievementCriteriaEarned(achievementID)
	-- It doesn't update inmediately
	C_Timer.After(0.2, function() 
		local refresh = false;
		for i=1, GetAchievementNumCriteria(achievementID) do
			local _, _, completed = GetAchievementCriteriaInfo(achievementID, i)
		   	if (completed) then
		   		-- If container/NPC
		   		if (private.ACHIEVEMENT_TARGET_IDS[achievementID]) then
					for _, entityID in ipairs(private.ACHIEVEMENT_TARGET_IDS[achievementID]) do
						local containerInfo = RSContainerDB.GetInternalContainerInfo(entityID)
						if (containerInfo) then
							if (containerInfo.criteria == i and not RSContainerDB.IsContainerOpened(entityID)) then
								RSLogger:PrintDebugMessage(string.format("Contenedor con criteria [%s][%s]. Completado.", achievementID, entityID))
								RSContainerDB.SetContainerOpened(entityID)
								RSMinimap.RefreshEntityState(entityID)
								refresh = true
							end
						else
							local npcInfo = RSNpcDB.GetInternalNpcInfo(entityID)
							if (npcInfo) then
								if (npcInfo.criteria == i and not RSNpcDB.IsNpcKilled(entityID)) then
									RSLogger:PrintDebugMessage(string.format("NPC con criteria [%s][%s]. Completado.", achievementID, entityID))
									RSNpcDB.SetNpcKilled(entityID)
									RSMinimap.RefreshEntityState(entityID)
									refresh = true
								end
							end
						end
					end
				elseif (RSDragonGlyphDB.IsDragonGlyph(achievementID)) then
			   		for glyphID, info in pairs (private.DRAGON_GLYPHS) do
						if (info.parent and info.parent == achievementID and info.criteria == i and not RSDragonGlyphDB.GetDragonGlyphCollected(glyphID)) then
							RSLogger:PrintDebugMessage(string.format("Glifo con criteria [%s][%s]. Completado.", achievementID, glyphID))
							RSDragonGlyphDB.SetDragonGlyphCollected(glyphID)
							RSMinimap.HideIcon(glyphID)
							refresh = true
						end
					end
				end
			end
		end
	
		-- Update achievements cache
		if (refresh) then
			RSAchievementDB.RefreshAchievementCache(achievementID)
		end
	end)
end

---============================================================================
-- Event: CRITERIA_EARNED
-- Fired when a part of an achievement is earned
---============================================================================

local function OnCriteriaEarned(parentAchievementID, description)
	if (parentAchievementID) then
		RSLogger:PrintDebugMessage(string.format("Criteria del logro [%s][%s]. Completado.", parentAchievementID, description))
		if (RSUtils.Contains(private.ACHIEVEMENT_WITH_CRITERIA, parentAchievementID)) then
			OnAchievementCriteriaEarned(parentAchievementID)
		elseif (RSDragonGlyphDB.IsDragonGlyph(parentAchievementID)) then
			OnAchievementCriteriaEarned(parentAchievementID) 
		end
	end
end

---============================================================================
-- Event: UNIT_SPELLCAST_SUCCEEDED
-- Fired when a part of an achievement is earned
---============================================================================

local function OnUnitSpellcastSucceeded(unitTarget, castGUID, spellID)
	if (not issecretvalue(spellID) and spellID) then
		--RSLogger:PrintDebugMessage(string.format("Hechizo [%s]. Completado.", spellID))
		-- Drakewatcher
		RSCollectionsDB.RemoveNotCollectedDrakewatcher(spellID, function()
			RSExplorerFrame:Refresh()
		end)
		
		-- Achievements
		if (private.ACHIEVEMENT_SPELL_IDS[spellID]) then
			OnAchievementCriteriaEarned(private.ACHIEVEMENT_SPELL_IDS[spellID])
		end
	end
end

---============================================================================
-- Event: PLAYER_LOGIN
-- Fired when the player logs in the game
---============================================================================

local function OnPlayerLogin(rareScannerButton)
	local x, y = RSGeneralDB.GetButtonPositionCoordinates()
	if (x and y) then
		rareScannerButton:ClearAllPoints()
		rareScannerButton:SetPoint("BOTTOMLEFT", x, y)
	end

	-- Adds custom chat window
	if (RSConfigDB.GetChatWindowName()) then
		RSLogger:CreateChatFrame(RSConfigDB.GetChatWindowName())
	end
	
	if (RSConfigDB.IsSupportingMapIcons()) then
		C_Timer.After(0, function(self)
			-- Wait until all providers are added
			if (WorldMapFrame:IsEventRegistered("WORLD_MAP_OPEN")) then
				if (not RareScannerBlizzardMapProvider) then
					RareScannerBlizzardMapProvider = private.ImportLib("RareScannerBlizzardMapProvider")
				end
				RareScannerBlizzardMapProvider:AddHooks()
				RSLogger:PrintDebugMessage("Añadidos hooks en iconos del juego.")
			end
		end)
	end
	
	-- Init macro
	RSMacro.CreateMacro()
	
	-- Apply Soft Interact CVars if enabled
	if (RSConfigDB.IsScanningSoftInteract()) then
		RSEventHandler.UpdateSoftInteractCVars(true)
	end
	
	rareScannerButton:UnregisterEvent("PLAYER_LOGIN")
end

function RSEventHandler.UpdateSoftInteractCVars(enable)
	if (enable) then
		-- Save original CVars if not already saved
		if (not RSConfigDB.GetOriginalSoftInteractCVars()) then
			local originalCVars = {
				softTargetInteract = C_CVar.GetCVar("softTargetInteract"),
				SoftTargetInteractArc = C_CVar.GetCVar("SoftTargetInteractArc"),
				SoftTargetInteractRange = C_CVar.GetCVar("SoftTargetInteractRange"),
			}

			RSConfigDB.SetOriginalSoftInteractCVars(originalCVars)
		end

		C_CVar.SetCVar("softTargetInteract", "3")
		C_CVar.SetCVar("SoftTargetInteractArc", "2")
		C_CVar.SetCVar("SoftTargetInteractRange", "30")
	else
		-- Restore original CVars if previously saved
		local originalCVars = RSConfigDB.GetOriginalSoftInteractCVars()
		if (originalCVars and type(originalCVars) == "table") then
			if (originalCVars.softTargetInteract) then
				C_CVar.SetCVar("softTargetInteract", originalCVars.softTargetInteract)
			end

			if (originalCVars.SoftTargetInteractArc) then
				C_CVar.SetCVar("SoftTargetInteractArc", originalCVars.SoftTargetInteractArc)
			end

			if (originalCVars.SoftTargetInteractRange) then
				C_CVar.SetCVar("SoftTargetInteractRange", originalCVars.SoftTargetInteractRange)
			end

			RSConfigDB.SetOriginalSoftInteractCVars(false)
		else
			C_CVar.SetCVar("softTargetInteract", "0")
		end
	end
end

---============================================================================
-- Event: PET_BATTLE_CLOSE
-- Fired when the player closes a pet battle
---============================================================================

local function OnPetBattleClose()
	-- For whatever reason the minimap icons are lost after closing a pet battle, so it forzes to show them again
	RSMinimap.RefreshAllData(true)
end

---============================================================================
-- Event: ITEM_TEXT_CLOSED
-- Fired when a finishing reading a text
---============================================================================

local function OnItemTextClose()
	local mapID = C_Map.GetBestMapForUnit("player")
	
	-- Many achievements require reading an object in the world, so check if the text closed belongs to any of these tracked achievements
	local achievementCriteriaRoutine = RSRoutines.LoopRoutineNew()
	achievementCriteriaRoutine:Init(
		function() return private.ACHIEVEMENT_WITH_CRITERIA end,
		function(context, _, achievementID)
			if (not mapID or (mapID and private.ACHIEVEMENT_ZONE_IDS[mapID] and RSUtils.Contains(private.ACHIEVEMENT_ZONE_IDS[mapID], achievementID))) then
				OnAchievementCriteriaEarned(achievementID)
			end
		end, 
		function(context)
			RSLogger:PrintDebugMessage("OnItemTextClose ejecutado")
		end
	)
	
	achievementCriteriaRoutine:Run()
end

---============================================================================
-- Event: PLAYER_ENTERING_WORLD
-- Fired when a changing a zone
---============================================================================

local function OnPlayerEnteringWorld(rareScannerButton)
	-- Ensure Soft Interact CVars are active if the option is enabled by default
	if (RSConfigDB.IsScanningSoftInteract()) then
		RSEventHandler.UpdateSoftInteractCVars(true)
	end

	if (not RSConfigDB.IsAutohidingInIntances()) then
		return
	end
	
	local isInInstance, instanceType = IsInInstance()
	if (isInInstance) then
		rareScannerButton:HideButton()
	end
end

---============================================================================
-- Event: UNIT_AURA
-- Fired when an aura is executed
---============================================================================

local matchedAuras = {}
local function OnUnitAura(rareScannerButton, updateInfo)
	if (not updateInfo or InCombatLockdown()) then
		return
	end
	
	local added = updateInfo.addedAuras
	if (not added or issecretvalue(added)) then
		return
	end
	
	-- First check if any added aura is tracked by RareScanner before querying map APIs
	wipe(matchedAuras)
	local hasMatchedAuras = false
	for _, info in pairs(added) do
		local spellID = select(1, scrubsecretvalues(info.spellId))
		if (spellID and private.SPELL_IDS_ENTITY[spellID]) then
			hasMatchedAuras = true
			table.insert(matchedAuras, spellID)
		end
	end
	
	if (not hasMatchedAuras) then
		return
	end
	
	local mapID = C_Map.GetBestMapForUnit("player")
	if (not mapID) then
		return
	end
	
	local mapPosition = C_Map.GetPlayerMapPosition(mapID, "player")
	local x, y
	if (mapPosition) then
		x, y = mapPosition:GetXY()
	end
	
	if (not x or not y) then
		return
	end
	
	for _, spellID in ipairs(matchedAuras) do
		RSLogger:PrintDebugMessage(string.format("Aura[%s].", spellID))

		local entityInfo = private.SPELL_IDS_ENTITY[spellID]
		if (entityInfo.isNpc) then
			local finalNpcID = RSNpcDB.GetFinalNpcID(entityInfo.id)
			if (finalNpcID) then
				rareScannerButton:SimulateRareFound(finalNpcID, nil, RSNpcDB.GetNpcName(finalNpcID), x, y, RSConstants.NPC_VIGNETTE, RSConstants.TRACKING_SYSTEM.AURA)
			end
		elseif (entityInfo.isContainer) then
			local finalContainerID = RSContainerDB.GetFinalContainerID(entityInfo.id)
			if (finalContainerID) then
				rareScannerButton:SimulateRareFound(finalContainerID, nil, RSContainerDB.GetContainerName(finalContainerID), x, y, RSConstants.CONTAINER_VIGNETTE, RSConstants.TRACKING_SYSTEM.AURA)
			end
		end
	end
end


---============================================================================
-- Event: DISPLAY_EVENT_TOASTS
-- Fired when an event message is displayed
---============================================================================

local function OnDisplayEventToasts(rareScannerButton)
	-- Only take into account in delves
	if (not C_PartyInfo.IsDelveInProgress()) then
		return
	end
	
	local toastInfo = C_EventToastManager.GetNextToastToDisplay()
	if (toastInfo) then
		if (toastInfo.iconFileID == RSConstants.DUNDUN_EVENT_ICON) then
			local mapID = C_Map.GetBestMapForUnit("player")
			if (not mapID) then
				return
			end
	
			local npcID = RSConstants.DUNDUN_DELVES
			local npcInfo = RSNpcDB.GetInternalNpcInfo(npcID)
			local x, y
			if (not npcInfo.zoneID[mapID]) then
				x = 0
				y = 0
			else
				x = npcInfo.zoneID[mapID].x
				y = npcInfo.zoneID[mapID].y
			end
	
            rareScannerButton:SimulateRareFound(npcID, nil, RSNpcDB.GetNpcName(npcID), x, y, RSConstants.NPC_VIGNETTE, RSConstants.TRACKING_SYSTEM.TOAST_EVENT)
		end
	end
end

---============================================================================
-- Event: PLAYER_STARTED_MOVING
-- Fired when the player starts moving
---============================================================================

local movingTimer

local function OnPlayerStartedMoving()
	if (not RSConfigDB.IsScanningWithMacro()) then
		return
	end
	
	RSMacro.SetIsMoving(true)
		
	if (not movingTimer or movingTimer:IsCancelled()) then
        movingTimer = C_Timer.NewTicker(RSConstants.RARESCANNER_MACRO_REFRESH_TIMER, function()
            RSMacro.UpdateMacro()
        end)
        
        RSMacro.UpdateMacro()
    end
end

---============================================================================
-- Event: PLAYER_STOPPED_MOVING
-- Fired when the player stops moving
---============================================================================

local function OnPlayerStopsMoving()
	RSMacro.SetIsMoving(false)

    if (movingTimer) then
        movingTimer:Cancel()
        movingTimer = nil
    end
    
    RSMacro.UpdateMacro()
end

---============================================================================
-- Event handler
---============================================================================

local vignetteUpdatedDelay
local function HandleEvent(rareScannerButton, event, ...) 
	if (event == "PLAYER_LOGIN") then
		OnPlayerLogin(rareScannerButton)
	elseif (event == "VIGNETTE_MINIMAP_UPDATED") then
		OnVignetteMinimapUpdated(rareScannerButton, ...)
	elseif (event == "VIGNETTES_UPDATED") then
		if (not vignetteUpdatedDelay or (vignetteUpdatedDelay - time()) <= 0) then
			vignetteUpdatedDelay = time() + 10
			OnVignettesUpdated(rareScannerButton)
		end
	elseif (event == "NAME_PLATE_UNIT_ADDED") then
		OnNamePlateUnitAdded(rareScannerButton, ...)
	elseif (event == "UPDATE_MOUSEOVER_UNIT") then
		OnUpdateMouseoverUnit(rareScannerButton)
	elseif (event == "PLAYER_REGEN_ENABLED") then
		OnPlayerRegenEnabled(rareScannerButton)
	elseif (event == "PLAYER_TARGET_CHANGED") then
		OnPlayerTargetChanged(rareScannerButton)
	elseif (event == "PLAYER_SOFT_INTERACT_CHANGED") then
		OnPlayerSoftInteractChanged(rareScannerButton)
	elseif (event == "LOOT_OPENED") then
		OnLootOpened()
	elseif (event == "CHAT_MSG_MONSTER_YELL") then
		local message, name, _, _, _, _, _, _, _, _, _, guid = ...
		OnChatMsgMonster(rareScannerButton, message, name, guid)
	elseif (event == "CHAT_MSG_MONSTER_EMOTE") then
		local message, name, _, _, _, _, _, _, _, _, _, guid = ...
		OnChatMsgMonster(rareScannerButton, message, name, guid)
	elseif (event == "CHAT_MSG_MONSTER_SAY") then
		local message, name, _, _, _, _, _, _, _, _, _, guid = ...
		OnChatMsgMonster(rareScannerButton, message, name, guid)
	elseif (event == "QUEST_TURNED_IN") then
		OnQuestTurnedIn(rareScannerButton, ...)
	elseif (event == "CINEMATIC_START") then
		OnCinematicStart(rareScannerButton)
	elseif (event == "CINEMATIC_STOP") then
		OnCinematicStop()
	elseif (event == "NEW_MOUNT_ADDED") then
		OnNewMountAdded(...)
	elseif (event == "NEW_PET_ADDED") then
		OnNewPetAdded(...)
	elseif (event == "NEW_TOY_ADDED") then
		OnNewToyAdded(...)
	elseif (event == "TRANSMOG_COLLECTION_UPDATED") then
		OnTransmogCollectionUpdated()
	elseif (event == "ACHIEVEMENT_EARNED") then
		OnAchievementEarned(...)
	elseif (event == "CRITERIA_EARNED") then
		OnCriteriaEarned(...)
	elseif (event == "UNIT_SPELLCAST_SUCCEEDED") then
		OnUnitSpellcastSucceeded(...)
	elseif (event == "PET_BATTLE_CLOSE") then
		OnPetBattleClose()
	elseif (event == "ITEM_TEXT_CLOSED") then
		OnItemTextClose()
	elseif (event == "HOUSE_DECOR_ADDED_TO_CHEST") then
		OnHouseDecorAddedToChest(...)
	elseif (event == "PLAYER_ENTERING_WORLD") then
		OnPlayerEnteringWorld(rareScannerButton)
	elseif (event == "PLAYER_STARTED_MOVING") then
		OnPlayerStartedMoving()
	elseif (event == "PLAYER_STOPPED_MOVING") then
		OnPlayerStopsMoving()
	elseif (event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS") then
		RSMacro.UpdateMacro(true)
	elseif (event == "DISPLAY_EVENT_TOASTS") then
		OnDisplayEventToasts(rareScannerButton)
	elseif (event == "PARTY_KILL") then
		OnPartyKill(...)
	elseif (event == "UNIT_AURA") then
		local unitTarget, updateInfo = ...
		local cleanUpdateInfo = scrubsecretvalues(updateInfo)
		if (unitTarget == "player" and cleanUpdateInfo) then
			OnUnitAura(rareScannerButton, cleanUpdateInfo)
		end
	end
end

function RSEventHandler.RegisterEvents(rareScannerButton, addon)
	RareScanner = addon
	rareScannerButton:RegisterEvent("PLAYER_LOGIN")
	rareScannerButton:RegisterEvent("VIGNETTE_MINIMAP_UPDATED")
	rareScannerButton:RegisterEvent("VIGNETTES_UPDATED")
	rareScannerButton:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	rareScannerButton:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
	rareScannerButton:RegisterEvent("PLAYER_REGEN_ENABLED")
	rareScannerButton:RegisterEvent("PLAYER_TARGET_CHANGED")
	rareScannerButton:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED")
	rareScannerButton:RegisterEvent("LOOT_OPENED")
	rareScannerButton:RegisterEvent("CINEMATIC_START")
	rareScannerButton:RegisterEvent("CINEMATIC_STOP")
	rareScannerButton:RegisterEvent("CHAT_MSG_MONSTER_YELL")
	rareScannerButton:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
	rareScannerButton:RegisterEvent("CHAT_MSG_MONSTER_SAY")
	rareScannerButton:RegisterEvent("QUEST_TURNED_IN")
	rareScannerButton:RegisterEvent("NEW_MOUNT_ADDED")
	rareScannerButton:RegisterEvent("NEW_PET_ADDED")
	rareScannerButton:RegisterEvent("NEW_TOY_ADDED")
	rareScannerButton:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
	rareScannerButton:RegisterEvent("ACHIEVEMENT_EARNED")
	rareScannerButton:RegisterEvent("CRITERIA_EARNED")
	rareScannerButton:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	rareScannerButton:RegisterEvent("PET_BATTLE_CLOSE")
	rareScannerButton:RegisterEvent("ITEM_TEXT_CLOSED")
	rareScannerButton:RegisterEvent("HOUSE_DECOR_ADDED_TO_CHEST")
	rareScannerButton:RegisterEvent("PLAYER_ENTERING_WORLD")
	rareScannerButton:RegisterEvent("UNIT_AURA")
	rareScannerButton:RegisterEvent("DISPLAY_EVENT_TOASTS")
	rareScannerButton:RegisterEvent("PLAYER_STARTED_MOVING")
	rareScannerButton:RegisterEvent("PLAYER_STOPPED_MOVING")
	rareScannerButton:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	rareScannerButton:RegisterEvent("ZONE_CHANGED")
	rareScannerButton:RegisterEvent("ZONE_CHANGED_INDOORS")
	rareScannerButton:RegisterEvent("PARTY_KILL")

	-- Captures all events
	rareScannerButton:SetScript("OnEvent", function(self, event, ...)
		HandleEvent(self, event, ...) 
	end)
end