-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local ADDON_NAME, private = ...

-- RareScanner libraries
local RSConstants = private.ImportLib("RareScannerConstants")

-- RareScanner database libraries
local RSGeneralDB = private.ImportLib("RareScannerGeneralDB")
local RSConfigDB = private.ImportLib("RareScannerConfigDB")

-- RareScanner service libraries
local RSUtils = private.ImportLib("RareScannerUtils")
local RSMinimap = private.ImportLib("RareScannerMinimap")
local RSTooltip = private.ImportLib("RareScannerTooltip")
local RSTextTags = private.ImportLib("RareScannerTextTags")

RSGuideMixin = CreateFromMixins(RSPinMixin);

function RSGuideMixin:OnLoad()
	RSPinMixin.OnLoad(self)
	self:SetScalingLimits(1, 0.75, 1.0);
end

function RSGuideMixin:OnAcquired(POI, pin)
	RSPinMixin.OnAcquired(self, POI)
	self:SetFrameLevel(self:GetParent():GetFrameLevel() + 50)

	-- Set attributes
	self.pin = pin
	self.Texture:SetTexture(POI.texture)
	self.Texture:SetScale(RSConfigDB.GetIconsWorldMapScale())
end

function RSGuideMixin:GetEntityPin()
	-- Uses parent if receives when added to the world map
	if (self.pin and self.pin:IsShown() and self.pin.POI) then
		if (self.pin.POI.entityID == self.POI.entityID) then
			return self.pin
		elseif (self.pin.POI.POIs) then
			for _, childPOI in ipairs(self.pin.POI.POIs) do
				if (childPOI.entityID == self.POI.entityID) then
					return self.pin
				end
			end
		end
	end

	-- Otherwise look for the parent among the pins in the map
	if (self.POI and self.POI.entityID and self:GetMap()) then
		for pin in self:GetMap():EnumeratePinsByTemplate("RSEntityPinTemplate") do
			if (pin:IsShown() and pin.POI and pin.POI.entityID == self.POI.entityID) then
				self.pin = pin
				return pin
			end
		end

		for pin in self:GetMap():EnumeratePinsByTemplate("RSGroupPinTemplate") do
			if (pin:IsShown() and pin.POI and pin.POI.POIs) then
				for _, childPOI in ipairs(pin.POI.POIs) do
					if (childPOI.entityID == self.POI.entityID) then
						self.pin = pin
						return pin
					end
				end
			end
		end
	end

	return nil
end

function RSGuideMixin:OnMouseEnter()
	if (self.ShowPingAnim:IsPlaying()) then
		self.ShowPingAnim:Stop()
	end
	local targetPin = self:GetEntityPin()
	if (targetPin and not targetPin.ShowPingAnim:IsPlaying() and not targetPin:IsReputationHighlight()) then
		targetPin.ShowPingAnim:Play()
	end
	
	if (self.POI.tooltip) then
		RSTooltip.Tooltip:SetOwner(self, "ANCHOR_CURSOR")

		if (self.POI.tooltip.title) then
			GameTooltip_SetTitle(RSTooltip.Tooltip, self.POI.tooltip.title);
		end

		if (self.POI.tooltip.comment) then
			local rawComment = self.POI.tooltip.rawComment or self.POI.tooltip.comment
			local comment = RSTextTags.ParseText(rawComment, function(newComment)
				if (newComment and self:IsMouseOver() and RSTooltip.Tooltip:IsShown()) then
					self.POI.tooltip.comment = newComment
					self:OnMouseEnter()
				end
			end)
			self.POI.tooltip.comment = comment
			GameTooltip_AddNormalLine(RSTooltip.Tooltip, comment);
		end

		RSTooltip.Tooltip:Show()
	end
end

function RSGuideMixin:OnMouseLeave()
	if (self.POI.tooltip) then
		RSTooltip.Tooltip:Hide()
	end
	local targetPin = self:GetEntityPin()
	if (targetPin and targetPin.ShowPingAnim and targetPin.ShowPingAnim:IsPlaying()) then
		targetPin.ShowPingAnim:Stop();
	end
end

function RSGuideMixin:OnReleased()
	RSPinMixin.OnReleased(self)
	self.pin = nil
end

function RSGuideMixin:OnMouseDown(button)
	if (button == "RightButton") then
		self:GetMap():RemoveAllPinsByTemplate("RSGuideTemplate");
		RSGeneralDB.RemoveGuideActive()

		-- Refresh minimap
		RSMinimap.RefreshAllData(true)
	end
end
