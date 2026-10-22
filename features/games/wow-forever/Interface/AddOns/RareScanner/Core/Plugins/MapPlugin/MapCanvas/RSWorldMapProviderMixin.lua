-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local LibStub = _G.LibStub
local ADDON_NAME, private = ...

local RSWorldMap = private.ImportLib("RareScannerWorldMap")

RSWorldMapProviderMixin = {}

function RSWorldMapProviderMixin:OnAdded()
	self:RemoveAllData()
	self:RefreshAllData();
end

function RSWorldMapProviderMixin:OnMapChanged()
	self:RemoveAllData()
	self:RefreshAllData();
end

function RSWorldMapProviderMixin:OnHide()
	self:RemoveAllData()
end

function RSWorldMapProviderMixin:OnShow()
	self:RefreshAllData()
end

function RSWorldMapProviderMixin:RemoveAllData()

end

function RSWorldMapProviderMixin:RefreshAllData(fromOnShow)
	
end

function RSWorldMapProviderMixin:SetBounty(bountyQuestID, bountyFactionID, bountyFrameType)
	local changed = self.bountyQuestID ~= bountyQuestID or self.bountyFactionID ~= bountyFactionID or self.bountyFrameType ~= bountyFrameType;
	if (changed) then
		self.bountyQuestID = bountyQuestID;
		self.bountyFactionID = bountyFactionID;
		self.bountyFrameType = bountyFrameType;
		if (self:GetMap()) then
			self:UpdatePinsHighlight();
		end
	end
end

function RSWorldMapProviderMixin:UpdatePinsHighlight()

end

function RSWorldMapProviderMixin:GetBountyInfo()
	return self.bountyQuestID, self.bountyFactionID, self.bountyFrameType;
end

function RSWorldMapProviderMixin:GetMap()
	return RSWorldMap
end