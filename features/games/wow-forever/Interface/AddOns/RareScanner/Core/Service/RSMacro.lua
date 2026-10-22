-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local LibStub = _G.LibStub
local ADDON_NAME, private = ...

-- Locales
local AL = LibStub("AceLocale-3.0"):GetLocale("RareScanner");

local RSMacro = private.NewLib("RareScannerMacro")

-- RareScanner database libraries
local RSConfigDB = private.ImportLib("RareScannerConfigDB")
local RSNpcDB = private.ImportLib("RareScannerNpcDB")
local RSMapDB = private.ImportLib("RareScannerMapDB")

-- RareScanner services
local RSMap = private.ImportLib("RareScannerMap")

-- RareScanner internal libraries
local RSConstants = private.ImportLib("RareScannerConstants")
local RSUtils = private.ImportLib("RareScannerUtils")
local RSLogger = private.ImportLib("RareScannerLogger")

---============================================================================
-- Create Macro functions
---============================================================================

local lastPlayerMapID, lastPlayerX, lastPlayerY
local nearbyNpcIDs
local macroTooLong = true
local macro
local isMoving = false
local lastMacroBody = nil

function RSMacro.SetIsMoving(value)
	isMoving = value
end

function RSMacro.IsAvailableMacroSlot()
	local numAccount, numCharacter = GetNumMacros()
	if (RSConfigDB.IsScanningWithMacroPerChar()) then
		return numCharacter < (_G.MAX_CHARACTER_MACROS or 30)
	else
		return numAccount < (_G.MAX_ACCOUNT_MACROS or 120)
	end
end

function RSMacro.CreateMacro()
	if (not RSConfigDB.IsScanningWithMacro()) then
		return
	end
	
	if (InCombatLockdown()) then
		return
	end
	
	if (not GetMacroInfo(RSConstants.RARESCANNER_MACRO_NAME)) then
		local perChar = RSConfigDB.IsScanningWithMacroPerChar()
		CreateMacro(RSConstants.RARESCANNER_MACRO_NAME, GetFileIDFromPath(RSConstants.RARESCANNER_MACRO_ICON), "", perChar)
		RSLogger:PrintMessage(string.format(AL["ENABLE_SCAN_MACRO_CREATED"], RSConstants.RARESCANNER_MACRO_NAME, string.format("|T%s:14|t", RSConstants.RARESCANNER_MACRO_ICON)))
	end
end

function RSMacro.DeleteMacro()	
	if (not InCombatLockdown()) then
		while (GetMacroInfo(RSConstants.RARESCANNER_MACRO_NAME)) do
			DeleteMacro(RSConstants.RARESCANNER_MACRO_NAME)
		end
	end
end

---============================================================================
-- Update Macro functions
---============================================================================

local function RefreshNpcIDs(mapID)
	lastPlayerMapID = mapID
	
	-- Search only for NPCs without vignette
	if (not RSMapDB.IsZoneWithoutVignette(mapID)) then
		nearbyNpcIDs = RSNpcDB.GetNpcIDsByMapID(mapID, true)
	-- Search for everything
	else
		nearbyNpcIDs = RSNpcDB.GetNpcIDsByMapID(mapID)
	end
end

local function GetNotFilteredNpcName(npcID)
	-- Filtered
	if (RSConfigDB.IsNpcFiltered(npcID) or RSConfigDB.IsNpcFilteredOnlyAlerts(npcID)) then
		return nil
	end
	
	-- Part of a disabled event
	if (RSNpcDB.IsDisabledEvent(npcID)) then
		return nil
	end
	
	return RSNpcDB.GetNpcName(npcID)
end

local function IsNpcNearby(npcID, mapID, playerx, playery)
	if (playerx and playery) then
		local npcInfo = RSNpcDB.GetInternalNpcInfoByMapID(npcID, mapID)
		if (not npcInfo) then
			return false
		end
		
		if (npcInfo.overlay) then
			for _, coordinates in ipairs (npcInfo.overlay) do
				local xo, yo = strsplit("-", coordinates)
				local distanceYards = RSUtils.GetDistanceInYards(mapID, playerx, playery, RSUtils.FixCoord(xo), RSUtils.FixCoord(yo))
				if (distanceYards > 0 and distanceYards <= RSConstants.RARESCANNER_MACRO_TARGET_DISTANCE_YARDS) then
					return true
				end
			end
		else
			local distanceYards = RSUtils.GetDistanceInYards(mapID, playerx, playery, npcInfo.x, npcInfo.y)
			if (distanceYards > 0 and distanceYards <= RSConstants.RARESCANNER_MACRO_TARGET_DISTANCE_YARDS) then
				return true
			end
		end
	end
	
	return false
end

function RSMacro.UpdateMacro(forced)
	if (not RSConfigDB.IsScanningWithMacro()) then
		return
	end
	
	-- Avoid refreshing the macro if the macro UI is open
	if (MacroFrame and MacroFrame:IsVisible()) then
		RSLogger:PrintDebugMessage("No se refresca macro por tener la ventana de macro abierta")
		return
	end
	
	-- Regenerate just in case the player deleted it
	if (not GetMacroInfo(RSConstants.RARESCANNER_MACRO_NAME)) then
		if (RSMacro.IsAvailableMacroSlot()) then
			RSMacro.CreateMacro()
		end
		
		-- Forces to update
		forced = true
	end
	
	-- Refresh NPCID list
	local playerMapID = C_Map.GetBestMapForUnit("player")
	if (not playerMapID) then
		return
	end
	
	-- Cache map to avoid constant updates
	if (forced or not lastPlayerMapID or lastPlayerMapID ~= playerMapID) then
		RefreshNpcIDs(playerMapID)
	-- Don't update if every NPC was added in the previous UPDATE, then dont do anything
	elseif (not macroTooLong) then
		--RSLogger:PrintDebugMessage("No es necesario refrescar la macro porque ha cabido entera")
		return
	-- Don't update if player not moving
	elseif (not isMoving) then
		--RSLogger:PrintDebugMessage("No es necesario refrescar la macro porque no se esta moviendo")
		return
	-- Don't update if the player hasn't moved or didn't move too far
	elseif (lastPlayerX and lastPlayerY) then
		local playerMapPosition = C_Map.GetPlayerMapPosition(playerMapID, "player")
		local playerx, playery
		if (playerMapPosition) then
			playerx, playery = playerMapPosition:GetXY()
		end
		
		if (playerx and playery) then
			local movedYards = RSUtils.GetDistanceInYards(playerMapID, playerx, playery, lastPlayerX, lastPlayerY)
			
			if (movedYards < RSConstants.RARESCANNER_MACRO_UPDATE_NPCS_DISTANCE_YARDS) then
				RSLogger:PrintDebugMessage(string.format("No se refresca macro pues el usuario se ha movido solo [%s yardas]", math.floor(movedYards)))
				return
			end
		end
	-- Don't update because the macro is empty
	else
		return
	end
	
	-- Update target macro
	macro = nil
	if (RSUtils.GetTableLength(nearbyNpcIDs) > 0) then
		macroTooLong = false
		
		-- Try to add every active NPC in the map
		for _, npcID in ipairs(nearbyNpcIDs) do
			local npcName = GetNotFilteredNpcName(npcID)
			if (npcName) then
				if (macro) then
	                macro = string.format('%s\n/targetexact %s', macro, npcName)
	            else
	                macro = string.format('/targetexact %s', npcName)
	            end
	            
	            if (#macro > 255) then
	            	macro = nil
	            	macroTooLong = true
	            	break
	            end
	    	end
		end
		
		-- Try to add every nearby active NPC in the map
		if (macroTooLong) then
			local playerMapPosition = C_Map.GetPlayerMapPosition(playerMapID, "player")
			local playerx, playery
			if (playerMapPosition) then
				playerx, playery = playerMapPosition:GetXY()
			end
			
			if (playerx and playery) then			
				-- Cache position of the player
				lastPlayerX = playerx
				lastPlayerY = playery
				
				for _, npcID in ipairs(nearbyNpcIDs) do
					local npcName = GetNotFilteredNpcName(npcID)
					if (npcName and IsNpcNearby(npcID, playerMapID, playerx, playery)) then
						RSLogger:PrintDebugMessage(string.format("Añadiendo a la macro [%s]", npcName))
						if (macro) then
			                macro = string.format('%s\n/targetexact %s', macro, npcName)
			            else
			                macro = string.format('/targetexact %s', npcName)
			            end
			
						-- If too long removes latest element and stops adding
						if (#macro > 255) then
			                macro = macro:gsub("\n[^\\n]*$", "")
							RSLogger:PrintDebugMessage(string.format("Macro demasiado larga, se recorta [%s]", macro))
			                break
			            end
			    	end
				end
			end
		end
	end
	
	if ((not lastMacroBody and not macro) or (lastMacroBody and macro == lastMacroBody)) then
        -- RSLogger:PrintDebugMessage("La macro no ha cambiado respecto a la última escrita. Se omite.")
        return
    end
		
	-- Refresh macro
	if (not InCombatLockdown()) then
		RSLogger:PrintDebugMessage(string.format("Macro actualizada [%s]", macro or ""))
		EditMacro(RSConstants.RARESCANNER_MACRO_NAME, RSConstants.RARESCANNER_MACRO_NAME, nil, macro or "")
		lastMacroBody = macro
	end
end