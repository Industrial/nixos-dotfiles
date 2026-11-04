-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local LibStub = _G.LibStub
local RareScanner = LibStub("AceAddon-3.0"):GetAddon("RareScanner")
local ADDON_NAME, private = ...

-- RareScanner database libraries
local RSNpcDB = private.ImportLib("RareScannerNpcDB")
local RSContainerDB = private.ImportLib("RareScannerContainerDB")
local RSEventDB = private.ImportLib("RareScannerEventDB")
local RSGeneralDB = private.ImportLib("RareScannerGeneralDB")
local RSConfigDB = private.ImportLib("RareScannerConfigDB")
local RSGuideDB = private.ImportLib("RareScannerGuideDB")

-- RareScanner service libraries
local RSMinimap = private.ImportLib("RareScannerMinimap")
local RSTooltip = private.ImportLib("RareScannerTooltip")
local RSProvider = private.ImportLib("RareScannerProvider")

-- RareScanner services
local RSGuidePOI = private.ImportLib("RareScannerGuidePOI")
local RSWaypoints = private.ImportLib("RareScannerWaypoints")
local RSEntityStateHandler = private.ImportLib("RareScannerEntityStateHandler")

-- RareScanner general libraries
local RSUtils = private.ImportLib("RareScannerUtils")
local RSConstants = private.ImportLib("RareScannerConstants")

RSEntityPinMixin = CreateFromMixins(RSPinMixin);

function RSEntityPinMixin:OnLoad()
	RSPinMixin.OnLoad(self)
	self:SetScalingLimits(1, 0.75, 1.0);
end

function RSEntityPinMixin:OnAcquired(POI, dataProvider)
	RSPinMixin.OnAcquired(self, POI, dataProvider)
	self:SetFrameLevel(self:GetParent():GetFrameLevel() + 100)
	self.Texture:SetTexture(POI.Texture)
	local scale = RSConfigDB.GetIconsWorldMapScale()
	self.Texture:SetScale(scale)
	self.IconTexture:SetAtlas(POI.iconAtlas)
	self.HighlightRing:SetScale(scale)
	self.HighlightRing:SetVertexColor(1, 0.85, 0.2, 1)
	self:UpdateHighlight()
end

function RSEntityPinMixin:OnMouseEnter()
	RSTooltip.ShowSimpleTooltip(self)
end

function RSEntityPinMixin:OnMouseLeave()
	if (RSTooltip.HideTooltip(self.tooltip)) then
		self.tooltip = nil
	end
end

function RSEntityPinMixin:OnMouseDown(button)
	if (not self.POI) then
		return
	end
	
	local entityID = self.POI.entityID
	if (button == "LeftButton") then		
		--Filter/unfilter
		if (IsShiftKeyDown() and IsAltKeyDown()) then
			if (self.POI.isNpc) then
				if (RSConfigDB.GetDefaultNpcFilter() == RSConstants.ENTITY_FILTER_ALERTS) then
					RSConfigDB.SetNpcFiltered(entityID, RSConstants.ENTITY_FILTER_ALL)
				else
					RSConfigDB.SetNpcFiltered(entityID)
				end
				self:Hide();
			elseif (self.POI.isContainer) then
				if (RSConfigDB.GetDefaultContainerFilter() == RSConstants.ENTITY_FILTER_ALERTS) then
					RSConfigDB.SetContainerFiltered(entityID, RSConstants.ENTITY_FILTER_ALL)
				else
					RSConfigDB.SetContainerFiltered(entityID)
				end
				self:Hide();
			elseif (self.POI.isEvent) then
				if (RSConfigDB.GetDefaultEventFilter() == RSConstants.ENTITY_FILTER_ALERTS) then
					RSConfigDB.SetEventFiltered(entityID, RSConstants.ENTITY_FILTER_ALL)
				else
					RSConfigDB.SetEventFiltered(entityID)
				end
				self:Hide();
			end
			RSProvider.RefreshAllDataProviders()
			RSMinimap.RefreshEntityState(entityID)
		-- Toggle overlay
		elseif (not IsShiftKeyDown() and not IsAltKeyDown() and not IsControlKeyDown()) then
			-- If overlay showing then hide it
			local overlayInfo = RSGeneralDB.GetOverlayActive(entityID)
			if (overlayInfo) then
				for pin in self:GetMap():EnumeratePinsByTemplate("RSOverlayTemplate") do
					if (pin:GetEntityID() == entityID) then
						self:GetMap():RemovePin(pin)
					end
				end
				RSGeneralDB.RemoveOverlayActive(entityID)
				RSMinimap.RemoveOverlay(entityID)
			else
				self:ShowOverlay()
			end
		end
	elseif (button == "RightButton") then		
		-- Add waypoint
		if (IsShiftKeyDown()) then
			RSWaypoints.AddWorldMapWaypoint(self.POI.mapID, self.POI.x, self.POI.y, self.POI.name)
		-- Toggle guide
		elseif (not IsShiftKeyDown() and not IsAltKeyDown() and not IsControlKeyDown()) then
			-- If guide showing then hide it
			local guideEntityID = RSGeneralDB.GetGuideActive()
			if (guideEntityID) then
				self:GetMap():RemoveAllPinsByTemplate("RSGuideTemplate");
				if (guideEntityID ~= entityID) then
					self:ShowGuide(self.POI.mapID)
				else
					RSGeneralDB.RemoveGuideActive()
					RSMinimap.RemoveGuide(entityID)
				end
			else
				self:ShowGuide(self.POI.mapID)
			end
			
			-- Hide the tooltip
			if (RSTooltip.HideTooltip(self.tooltip)) then
				self.tooltip = nil
			end
		end
	end
end

function RSEntityPinMixin:ShowOverlay()
	-- Overlay
	local overlay = nil
	if (self.POI.isNpc) then
		overlay = RSNpcDB.GetInternalNpcOverlay(self.POI.entityID, self.POI.mapID)
	elseif (self.POI.isContainer) then
		overlay = RSContainerDB.GetInternalContainerOverlay(self.POI.entityID, self.POI.mapID)
	elseif (self.POI.isEvent) then
		overlay = RSEventDB.GetInternalEventOverlay(self.POI.entityID, self.POI.mapID)
	end

	if (overlay) then
		-- Checks if the overlay is already shown, in which case is already active in the minimap
		local hasOverlayActive = RSGeneralDB.HasOverlayActive(self.POI.entityID);
		
		-- In the worldmap we always have to add it
		local r, g, b, replacedEntityID = RSGeneralDB.AddOverlayActive(self.POI.entityID)

		-- Cleans the replaced overlay
		if (replacedEntityID) then
			for pin in self:GetMap():EnumeratePinsByTemplate("RSOverlayTemplate") do
				if (pin:GetEntityID() == replacedEntityID) then
					self:GetMap():RemovePin(pin)
				end
			end
			
			-- Cleans the replaced overly in the minimap
			RSMinimap.RemoveOverlay(replacedEntityID)
		-- Checks if they are already shown
		else
			for pin in self:GetMap():EnumeratePinsByTemplate("RSOverlayTemplate") do
				if (pin:GetEntityID() == self.POI.entityID) then
					return
				end
			end
		end
		
		-- Adds the new one
		for _, coordinates in ipairs (overlay) do
			local x, y = strsplit("-", coordinates)
			self:GetMap():AcquirePin("RSOverlayTemplate", RSUtils.FixCoord(x), RSUtils.FixCoord(y), r, g, b, self);
		end
		
		-- Adds the new one to the minimap
		if (not hasOverlayActive) then
			RSMinimap.AddOverlay(self.POI.entityID)
		end
	end
end

function RSEntityPinMixin:ShowGuide(mapID)
	-- Guide
	local guide = nil
	if (self.POI.isNpc) then
		guide = RSGuideDB.GetNpcGuide(self.POI.entityID, mapID)
	elseif (self.POI.isContainer) then
		guide = RSGuideDB.GetContainerGuide(self.POI.entityID, mapID)
	else
		guide = RSGuideDB.GetEventGuide(self.POI.entityID, mapID)
	end

	if (guide) then
		for pinType, info in pairs (guide) do
			-- Skip if quest completed
			if (not info.questID or not C_QuestLog.IsQuestFlaggedCompleted(info.questID)) then
				local POI = RSGuidePOI.GetGuidePOI(self.POI.entityID, pinType, info)
				local pin = self:GetMap():AcquirePin("RSGuideTemplate", POI, self);
				pin.ShowPingAnim:Play()
			end
		end
		RSGeneralDB.SetGuideActive(self.POI.entityID)
		RSMinimap.AddGuide(self.POI.entityID)
	end
end

function RSEntityPinMixin:OnReleased()
	RSPinMixin.OnReleased(self)
    
	if (self.HighlightRingAnim:IsPlaying()) then
		self.HighlightRingAnim:Stop()
	end
	self.HighlightRing:Hide()

    if (self.tooltip) then
		RSTooltip.ReleaseTooltip(self.tooltip)
		self.tooltip = nil
	end
end

function RSEntityPinMixin:UpdateHighlight()
	if (self:IsReputationHighlight()) then
		if (not self.HighlightRingAnim:IsPlaying()) then
			self.HighlightRing:Show()
			self.HighlightRingAnim:Play()
		end
	else
		if (self.HighlightRingAnim:IsPlaying()) then
			self.HighlightRingAnim:Stop()
		end
		self.HighlightRing:Hide()
	end
end

function RSEntityPinMixin:IsReputationHighlight()
	if (RSConfigDB.IsHighlightingReputation()) then
		local _, bountyFactionID = self.dataProvider:GetBountyInfo();
		if (bountyFactionID and self.POI.factionID and RSUtils.Contains(self.POI.factionID, bountyFactionID)) then
			return true;
		end
	end

	return false;
end