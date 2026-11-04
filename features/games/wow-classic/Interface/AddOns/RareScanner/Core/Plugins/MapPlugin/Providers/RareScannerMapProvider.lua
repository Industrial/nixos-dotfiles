-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local LibStub = _G.LibStub
local ADDON_NAME, private = ...

-- Locales
local AL = LibStub("AceLocale-3.0"):GetLocale("RareScanner");

-- RareScanner database libraries
local RSGeneralDB = private.ImportLib("RareScannerGeneralDB")
local RSGuideDB = private.ImportLib("RareScannerGuideDB")
local RSContainerDB = private.ImportLib("RareScannerContainerDB")
local RSConfigDB = private.ImportLib("RareScannerConfigDB")
local RSNpcDB = private.ImportLib("RareScannerNpcDB")
local RSEventDB = private.ImportLib("RareScannerEventDB")

-- RareScanner general libraries
local RSLogger = private.ImportLib("RareScannerLogger")
local RSUtils = private.ImportLib("RareScannerUtils")
local RSConstants = private.ImportLib("RareScannerConstants")

-- RareScanner services libraries
local RSMinimap = private.ImportLib("RareScannerMinimap")
local RSMap = private.ImportLib("RareScannerMap")
local RSTooltip = private.ImportLib("RareScannerTooltip")
local RSGuidePOI = private.ImportLib("RareScannerGuidePOI")
local RSRecentlySeenTracker = private.ImportLib("RareScannerRecentlySeenTracker")
local RSRoute = private.ImportLib("RareScannerRoute")

RareScannerDataProviderMixin = CreateFromMixins(RSWorldMapProviderMixin);

--- --------------------------------------------------------------
--- Animations
-- ---------------------------------------------------------------

local function PingAnimation(pin, animation, POI)
    if not animation or not POI.entityID then return end

    animation:Stop()
    animation:SetScript("OnLoop", function(self)
        self.loops = (self.loops or 0) + 1
        if (self.loops >= 3) then
            RSRecentlySeenTracker.DeletePendingAnimation(POI.entityID, POI.mapID, POI.x, POI.y)
            self:Stop()
            self:SetLooping("NONE")
        end
    end)

    if (RSRecentlySeenTracker.ShouldPlayAnimation(POI.entityID, POI.mapID, POI.x, POI.y)) then
        animation.loops = 0
        animation:SetLooping("BOUNCE")
        animation:Play()
    end
end

local function ShowPingForPOIs(pinIterator, configCheck)
    for pin in pinIterator do
        local poiList = pin.POI.POIs or { pin.POI }
        for _, POI in ipairs(poiList) do
            if (configCheck(POI)) then
                PingAnimation(pin, pin.ShowPingAnim, POI)
            end
        end
    end
end

function RareScannerDataProviderMixin:ShowAnimations()
	local templates = { "RSEntityPinTemplate", "RSGroupPinTemplate" }
    local typeChecks = {
        { check = RSConfigDB.IsShowingAnimationForNpcs, field = "isNpc" },
        { check = RSConfigDB.IsShowingAnimationForContainers, field = "isContainer" },
        { check = RSConfigDB.IsShowingAnimationForEvents, field = "isEvent" },
    }

    for _, template in ipairs(templates) do
        local pins = self:GetMap():EnumeratePinsByTemplate(template)
        if (pins) then
	        ShowPingForPOIs(pins, function(poi)
	            for _, t in ipairs(typeChecks) do
	                if (t.check() and poi[t.field]) then
	                    return true
	                end
	            end
	            return false
	        end)
	    end
    end
end

function RareScannerDataProviderMixin:RemoveAllData()
	self:GetMap():RemoveAllPinsByTemplate("RSEntityPinTemplate");
	self:GetMap():RemoveAllPinsByTemplate("RSOverlayTemplate");
	self:GetMap():RemoveAllPinsByTemplate("RSGuideTemplate");
	self:GetMap():RemoveAllPinsByTemplate("RSGroupPinTemplate");
end

function RareScannerDataProviderMixin:ShowGuideLayer(entityID, mapID, parentPin)
	-- Gets the information of the entity
	local guide = nil
	local isNpc = false
	local isContainer = false
	local isEvent = false
	if (RSNpcDB.GetInternalNpcInfo(entityID)) then
		guide = RSGuideDB.GetNpcGuide(entityID, mapID)
		isNpc = true
	elseif (RSContainerDB.GetInternalContainerInfo(entityID)) then
		guide = RSGuideDB.GetContainerGuide(entityID, mapID)
		isContainer = true
	else 
		guide = RSGuideDB.GetEventGuide(entityID, mapID)
		isEvent = true
	end

	if (guide) then
		if (not parentPin and self:GetMap()) then
			for pin in self:GetMap():EnumeratePinsByTemplate("RSEntityPinTemplate") do
				if (pin:IsShown() and pin.POI and pin.POI.entityID == entityID) then
					parentPin = pin
				end
			end
			if (not parentPin) then
				for pin in self:GetMap():EnumeratePinsByTemplate("RSGroupPinTemplate") do
					if (pin:IsShown() and pin.POI and pin.POI.POIs) then
						for _, childPOI in ipairs(pin.POI.POIs) do
							if (childPOI.entityID == entityID) then
								parentPin = pin
							end
						end
					end
				end
			end
		end

		for pinType, info in pairs (guide) do
			local POI = RSGuidePOI.GetGuidePOI(entityID, pinType, info)
			if (not info.questID or not C_QuestLog.IsQuestFlaggedCompleted(info.questID)) then
				local guidePin = self:GetMap():AcquirePin("RSGuideTemplate", POI, parentPin);
				if ((isNpc and not RSNpcDB.IsInternalNpcInMap(entityID, mapID)) or (isContainer and not RSContainerDB.IsInternalContainerInMap(entityID, mapID)) or (isEvent and not RSEventDB.IsInternalEventInMap(entityID, mapID))) then
					guidePin.ShowPingAnim:SetLooping("REPEAT")
					guidePin.ShowPingAnim:Play()
				else
					guidePin.ShowPingAnim:SetLooping("NONE")
					guidePin.ShowPingAnim:Play()
				end
			end
		end
	end
end

function RareScannerDataProviderMixin:RefreshAllData(fromOnShow)
	self:RemoveAllData()

	local mapID = self:GetMap():GetMapID();
	RSLogger:PrintDebugMessage(string.format("MAPID [%s], ARTID [%s]", mapID, C_Map.GetMapArtID(mapID)))

	-- Loads new pins
	local POIs = RSMap.GetMapPOIs(mapID, true, false)
	if (not POIs) then
		return
	end

	-- Adds all the POIs to the WorldMap
	local currentGuideActive = nil
	for _, POI in ipairs (POIs) do
		-- Skip if an ingame vignette is already showing this entity (on AreaPOIPinTemplate)
		-- Only vignettes on WorldMap are actually shown in this layer
		-- If its a group it doesn't matter, because there are several entities inside
		local filtered = false
		if (POI.isNpc) then
			for pin in WorldMapFrame:EnumeratePinsByTemplate("AreaPOIPinTemplate") do
				if (pin.name == POI.name) then
					RSLogger:PrintDebugMessageEntityID(POI.entityID, string.format("Saltado NPC [%s]: Hay un vignette del juego mostrándolo (AreaPOI).", POI.entityID))
					filtered = true
				end
			end
		end

		-- If the entity is only available when shown in the world map, there is no need to fill the map with useless icons
		if (POI.worldmap) then
			RSLogger:PrintDebugMessageEntityID(POI.entityID, string.format("Saltado NPC [%s]: Solo se muestra cuando aparece en el mapa del mundo.", POI.entityID))
			filtered = true
		elseif (POI.isGroup) then
			for _, subPOI in ipairs(POI.POIs) do
				if (subPOI.isContainer and subPOI.worldmap) then
					filtered = true
					break
				end
			end
		end

		if (not filtered) then
			local pin
			if (POI.isGroup) then
				pin = self:GetMap():AcquirePin("RSGroupPinTemplate", POI, self);

				-- Animates the ping in case the filter is on
				if (RSGeneralDB.GetWorldMapTextFilter()) then
					pin.ShowSearchAnim:Play();
				end

				-- Adds children overlay/guide
				for _, childPOI in ipairs (POI.POIs) do
					-- Adds overlay if active
					-- Avoids adding multiple spots if the entity spawns in multiple places at the same time
					if (RSGeneralDB.HasOverlayActive(childPOI.entityID) and (not currentGuideActive or currentGuideActive ~= childPOI.entityID)) then
						pin:ShowOverlay(childPOI)
						currentGuideActive = childPOI.entityID
					end
				end
			else
				RSLogger:PrintDebugMessageEntityID(POI.entityID, string.format("Mostrando Entidad [%s].", POI.entityID))
				pin = self:GetMap():AcquirePin("RSEntityPinTemplate", POI, self);

				-- Animates the ping in case the filter is on
				if (RSGeneralDB.GetWorldMapTextFilter()) then
					pin.ShowSearchAnim:Play();
				end

				-- Adds overlay if active
				-- Avoids adding multiple spots if the entity spawns in multiple places at the same time
				if (RSGeneralDB.HasOverlayActive(POI.entityID) and (not currentGuideActive or currentGuideActive ~= POI.entityID)) then
					RSLogger:PrintDebugMessageEntityID(POI.entityID, string.format("Mostrando Overlay [%s].", POI.entityID))
					pin:ShowOverlay()
					currentGuideActive = POI.entityID
				end
			end
		end
	end
	
	-- Adds guidance icons to the WorldMap
	if (RSGeneralDB.GetGuideActive()) then
		self:ShowGuideLayer(RSGeneralDB.GetGuideActive(), mapID)
	end
	
	-- Show animations
	if (self:GetMap():GetMapFrame():IsShown()) then
		self:ShowAnimations()
	end

	RSRoute.RefreshRoute()
end

function RareScannerDataProviderMixin:UpdatePinsHighlight()
	for pin in self:GetMap():EnumeratePinsByTemplate("RSEntityPinTemplate") do
		pin:UpdateHighlight()
	end
	for pin in self:GetMap():EnumeratePinsByTemplate("RSGroupPinTemplate") do
		pin:UpdateHighlight()
	end
end
