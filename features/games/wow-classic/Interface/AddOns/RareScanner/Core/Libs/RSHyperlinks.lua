-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local ADDON_NAME, private = ...

local LibTime = LibStub("LibTime-1.0")

local RSHyperlinks = private.NewLib("RareScannerHyperlinks")

-- Locales
local AL = LibStub("AceLocale-3.0"):GetLocale("RareScanner");

-- RareScanner database libraries
local RSNpcDB = private.ImportLib("RareScannerNpcDB")
local RSContainerDB = private.ImportLib("RareScannerContainerDB")
local RSEventDB = private.ImportLib("RareScannerEventDB")
local RSGeneralDB = private.ImportLib("RareScannerGeneralDB")
local RSConfigDB = private.ImportLib("RareScannerConfigDB")

-- RareScanner libraries
local RSConstants = private.ImportLib("RareScannerConstants")
local RSUtils = private.ImportLib("RareScannerUtils")
local RSLogger = private.ImportLib("RareScannerLogger")

-- RareScanner services
local RSNpcPOI = private.ImportLib("RareScannerNpcPOI")
local RSContainerPOI = private.ImportLib("RareScannerContainerPOI")
local RSEventPOI = private.ImportLib("RareScannerEventPOI")
local RSTooltip = private.ImportLib("RareScannerTooltip")
local RSProvider = private.ImportLib("RareScannerProvider")
local RSMinimap = private.ImportLib("RareScannerMinimap")
local RSWaypoints = private.ImportLib("RareScannerWaypoints")

-- Types
local NPC_TYPE = "1";
local CONTAINER_TYPE = "2";
local EVENT_TYPE = "3";

local pin = {}

function RSHyperlinks.GetEntityHyperLink(entityID, name)	
	if (RSNpcDB.GetInternalNpcInfo(entityID)) then
		local npcName = name and name or RSNpcDB.GetNpcName(entityID)
		local alreadyFound = RSGeneralDB.GetAlreadyFoundEntity(entityID, RSConstants.NPC_VIGNETTE)
		if (not alreadyFound) then
			return
		end
		return string.format("|cff%s|Haddon:RareScanner:%s:%s:%s:%s:%s:%s|h[%s]|h|r", RSConfigDB.GetChatLinkColorNpc(), NPC_TYPE, entityID, alreadyFound.mapID, RSUtils.FixCoord(alreadyFound.coordX), RSUtils.FixCoord(alreadyFound.coordY), alreadyFound.foundTime, npcName)
	-- Container
	elseif (RSContainerDB.GetInternalContainerInfo(entityID)) then
		local containerName = name and name or RSContainerDB.GetContainerName(entityID)
		local alreadyFound = RSGeneralDB.GetAlreadyFoundEntity(entityID, RSConstants.CONTAINER_VIGNETTE)
		if (not alreadyFound) then
			return
		end
		return string.format("|cff%s|Haddon:RareScanner:%s:%s:%s:%s:%s:%s|h[%s]|h|r", RSConfigDB.GetChatLinkColorContainer(), CONTAINER_TYPE, entityID, alreadyFound.mapID, RSUtils.FixCoord(alreadyFound.coordX), RSUtils.FixCoord(alreadyFound.coordY), alreadyFound.foundTime, containerName)
	-- Event
	elseif (RSEventDB.GetInternalEventInfo(entityID)) then
		local eventName = name and name or RSEventDB.GetEventName(entityID)
		local alreadyFound = RSGeneralDB.GetAlreadyFoundEntity(entityID, RSConstants.EVENT_VIGNETTE)
		if (not alreadyFound) then
			return
		end
		return string.format("|cff%s|Haddon:RareScanner:%s:%s:%s:%s:%s:%s|h[%s]|h|r", RSConfigDB.GetChatLinkColorEvent(), EVENT_TYPE, entityID, alreadyFound.mapID, RSUtils.FixCoord(alreadyFound.coordX), RSUtils.FixCoord(alreadyFound.coordY), alreadyFound.foundTime, eventName)
	end
end

local function GetGeneralChatID()
	local general = EnumerateServerChannels()
	local channels = {GetChannelList()}
	for i = 1, #channels do
		local id, name, disabled = channels[i], channels[i+1], channels[i+2]
		if (name == general and not disabled) then
			return id
		end
	end
end

function RSHyperlinks.HookHyperLinks()
	hooksecurefunc("SetItemRef", function(link, text, button, chatFrame)
		local linkType, addon, type, entityIDs, mapIDs, x, y, foundTimes = strsplit(":", link)
		if (linkType == "addon" and addon == "RareScanner") then
			local entityID = tonumber(entityIDs)
			
			local name
			if (type == NPC_TYPE) then
				name = RSNpcDB.GetNpcName(entityID)
			elseif (type == CONTAINER_TYPE) then
				name = RSContainerDB.GetContainerName(entityID)
			else
				name = RSEventDB.GetEventName(entityID)
			end
			
			-- Show tooltip
			if (button == "LeftButton") then
				--Filter/unfilter
				if (IsShiftKeyDown() and IsAltKeyDown()) then
--					if (type == NPC_TYPE) then
--						if (RSConfigDB.GetDefaultNpcFilter() == RSConstants.ENTITY_FILTER_ALERTS) then
--							RSConfigDB.SetNpcFiltered(entityID, RSConstants.ENTITY_FILTER_ALL)
--						else
--							RSConfigDB.SetNpcFiltered(entityID)
--						end
--						RSLogger:PrintMessage(AL["DISABLED_SEARCHING_ENTITIE"]..(name and name or entityIDs))
--					elseif (type == CONTAINER_TYPE) then
--						if (RSConfigDB.GetDefaultContainerFilter() == RSConstants.ENTITY_FILTER_ALERTS) then
--							RSConfigDB.SetContainerFiltered(entityID, RSConstants.ENTITY_FILTER_ALL)
--						else
--							RSConfigDB.SetContainerFiltered(entityID)
--						end
--						RSLogger:PrintMessage(AL["DISABLED_SEARCHING_ENTITIE"]..(name and name or entityIDs))
--					elseif (type == EVENT_TYPE) then
--						if (RSConfigDB.GetDefaultEventFilter() == RSConstants.ENTITY_FILTER_ALERTS) then
--							RSConfigDB.SetEventFiltered(entityID, RSConstants.ENTITY_FILTER_ALL)
--						else
--							RSConfigDB.SetEventFiltered(entityID)
--						end
--						RSLogger:PrintMessage(AL["DISABLED_SEARCHING_ENTITIE"]..(name and name or entityIDs))
--					end
--					RSProvider.RefreshAllDataProviders()
--					RSMinimap.RefreshEntityState(entityID)
				-- Show tooltip with info
				else
					local previousPinID = pin.POI and pin.POI.entityID or nil
					-- Data to build the tooltip
					local mapID = tonumber(mapIDs)
					local foundTime = tonumber(foundTimes)
					local alreadyFound = {}
					alreadyFound.mapID = mapID
					alreadyFound.foundTime = foundTime
					alreadyFound.coordX = x
					alreadyFound.coordY = y
					
					-- Show tooltip
					if (type == NPC_TYPE) then
						pin.POI = RSNpcPOI.GetNpcPOI(entityID, mapID, RSNpcDB.GetInternalNpcInfo(entityID), alreadyFound)
					elseif (type == CONTAINER_TYPE) then
						pin.POI = RSContainerPOI.GetContainerPOI(entityID, mapID, RSContainerDB.GetInternalContainerInfo(entityID), alreadyFound)
					elseif (type == EVENT_TYPE) then
						pin.POI = RSEventPOI.GetEventPOI(entityID, mapID, RSEventDB.GetInternalEventInfo(entityID), alreadyFound)
					end
					
					local showTooltip = true
					if (pin.tooltip) then
						RSTooltip.HideTooltip(pin.tooltip, true)
						if (previousPinID and previousPinID == pin.POI.entityID) then
							showTooltip = false
						end
					end
					if (showTooltip) then
						RSTooltip.ShowLinkTooltip(pin, chatFrame)
					end
				end
			elseif (button == "RightButton") then
				-- Add waypoint
				if (not IsShiftKeyDown()) then
					RSWaypoints.AddChatMapWaypoint(mapIDs, x, y, name)
				-- Add waypoint and share in chat
				elseif (IsShiftKeyDown()) then
					RSWaypoints.AddIngameWaypoint(mapIDs, x, y)
					
					local generalID = GetGeneralChatID()
					local waypointHyperlink = C_Map.GetUserWaypointHyperlink()
					if (not generalID or not waypointHyperlink) then
						return
					end
					
					-- Notification without health
					C_ChatInfo.SendChatMessage(string.format(AL["CHAT_NOTIFICATION_RARE"], name, waypointHyperlink), "CHANNEL", nil, generalID)
				end
			end
		end
	end)
end