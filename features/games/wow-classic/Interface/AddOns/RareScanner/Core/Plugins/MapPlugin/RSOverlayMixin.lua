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
local RSMinimap = private.ImportLib("RareScannerMinimap")

-- RareScanner general libraries
local RSUtils = private.ImportLib("RareScannerUtils")
local RSTooltip = private.ImportLib("RareScannerTooltip")

RSOverlayMixin = CreateFromMixins(RSPinMixin);

function RSOverlayMixin:OnLoad()
	RSPinMixin.OnLoad(self)
	self:SetScalingLimits(1, 1.4, 2.5);
end

function RSOverlayMixin:OnAcquired(x, y, r, g, b, pin)
	self:SetFrameStrata("HIGH")
	self:SetFrameLevel(self:GetParent():GetFrameLevel() + 1)

	-- Set attributes
	self.pin = pin
	self.x = RSUtils.FixCoord(x)
	self.y = RSUtils.FixCoord(y)
	self.Texture:SetTexture(RSConstants.OVERLAY_SPOT_TEXTURE)
	self.Texture:SetVertexColor(r, g, b, 0.9)
	self:UpdateScale()
end

function RSOverlayMixin:OnMouseEnter()
	if (not self.pin.ShowPingAnim:IsPlaying() and not self.pin:IsReputationHighlight()) then
		self.pin.ShowPingAnim:Play()
	end

	RSTooltip.Tooltip:SetOwner(self, "ANCHOR_CURSOR")
	
	if (self.pin.POI) then
		RSTooltip.Tooltip:SetText(self.pin.POI.name)
	else
		RSTooltip.Tooltip:SetText(self.pin.name)
	end
	RSTooltip.Tooltip:Show()
end

function RSOverlayMixin:OnMouseLeave()
	if (self.pin.ShowPingAnim and self.pin.ShowPingAnim:IsPlaying()) then
		self.pin.ShowPingAnim:Stop();
	end

	RSTooltip.Tooltip:Hide()
end

function RSOverlayMixin:OnMouseDown(button)
	if (button == "RightButton") then
		for pin in self:GetMap():EnumeratePinsByTemplate("RSOverlayTemplate") do
			if (pin ~= self and pin:GetEntityID() == self:GetEntityID()) then
				self:GetMap():RemovePin(pin)
			end
		end

		self:GetMap():RemovePin(self)
		RSGeneralDB.RemoveOverlayActive(self:GetEntityID())

		-- Refresh minimap
		RSMinimap.RefreshAllData(true)
	end
end

function RSOverlayMixin:GetEntityID()
	if (self.pin.POI) then
		return self.pin.POI.entityID
	else
		return self.pin.entityID
	end
end