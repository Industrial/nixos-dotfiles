-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local LibStub = _G.LibStub
local ADDON_NAME, private = ...

local RSWorldMap = private.ImportLib("RareScannerWorldMap")

local RSUtils = private.ImportLib("RareScannerUtils")

RSPinMixin = {}

function RSPinMixin:OnLoad()
	self:EnableMouse(true)
    self:SetMouseClickEnabled(true)
end

function RSPinMixin:OnAcquired(POI, dataProvider)
	self:SetFrameStrata("HIGH")
	self.POI = POI
	self.x = RSUtils.FixCoord(POI.x)
	self.y = RSUtils.FixCoord(POI.y)
    self.dataProvider = dataProvider
	self:UpdateScale()
end

function RSPinMixin:ApplyCurrentPosition()
	if (not self.x or not self.y) then
		return
	end
	
	local mapFrame = RSWorldMap:GetMapFrame()
	local canvas = WorldMapFrame:GetCanvasContainer()

	local width = mapFrame:GetWidth()
	local height = mapFrame:GetHeight()
	local scale = self:GetScale();

	self:ClearAllPoints()
	self:SetPoint("CENTER", mapFrame, "TOPLEFT", (width * self.x) / scale, -(height * self.y) / scale)
end

function RSPinMixin:OnReleased()
	self:ClearAllPoints()
    self:Hide()
    self.POI = nil
    self.dataProvider = nil
end

function RSPinMixin:GetMap()
	return RSWorldMap
end

function RSPinMixin:IsReputationHighlight()
	return false;
end

function RSPinMixin:SetScalingLimits(scaleFactor, startScale, endScale)
	self.scaleFactor = scaleFactor;
	self.startScale = startScale and math.max(startScale, .01) or nil;
	self.endScale = endScale and math.max(endScale, .01) or nil;
end

function RSPinMixin:UpdateScale()
	if (not self.x or not self.y) then
		return
	end
	
	RSWorldMap:WaitForCanvasReady(function(isReady)
		if (not isReady) then
			return
		end
		
		local scale;
		if (self.startScale and self.endScale) then
			local parentScaleFactor = 1.0 / WorldMapFrame:GetCanvasScale();
			scale = parentScaleFactor * Lerp(self.startScale, self.endScale, Saturate(self.scaleFactor * WorldMapFrame:GetCanvasZoomPercent()));
		else
			scale = 1;
		end
		
		self:SetScale(scale);
		self:ApplyCurrentPosition()
	end)
end