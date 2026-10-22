-------------------------------------------------------------------
-- AddOn namespace.
-------------------------------------------------------------------
local LibStub = _G.LibStub
local ADDON_NAME, private = ...

-- RareScanner libraries
local RSTooltip = private.ImportLib("RareScannerTooltip")
local RSTextTags = private.ImportLib("RareScannerTextTags")

RSMinimapPinMixin = {}

function RSMinimapPinMixin:OnEnter()
	RSTooltip.Tooltip:SetOwner(self, "ANCHOR_CURSOR")
	if (self.POI.name) then
		local rawName = (self.POI.tooltip and self.POI.tooltip.rawComment) or self.POI.name
		local name = RSTextTags.ParseText(rawName, function(newName)
			if (newName and self:IsMouseOver() and RSTooltip.Tooltip:IsShown()) then
				self.POI.name = newName
				if (self.POI.tooltip) then
					self.POI.tooltip.comment = newName
				end
				self:OnEnter()
			end
		end)
		self.POI.name = name
		RSTooltip.Tooltip:SetText(name)
	elseif (self.POI.tooltip) then
		if (self.POI.tooltip.title) then
			GameTooltip_SetTitle(RSTooltip.Tooltip, self.POI.tooltip.title);
		end
		if (self.POI.tooltip.comment) then
			local rawComment = self.POI.tooltip.rawComment or self.POI.tooltip.comment
			local comment = RSTextTags.ParseText(rawComment, function(newComment)
				if (newComment and self:IsMouseOver() and RSTooltip.Tooltip:IsShown()) then
					self.POI.tooltip.comment = newComment
					self:OnEnter()
				end
			end)
			self.POI.tooltip.comment = comment
			GameTooltip_AddNormalLine(RSTooltip.Tooltip, comment);
		end
	end
	RSTooltip.Tooltip:Show()
end

function RSMinimapPinMixin:OnLeave()
	RSTooltip.Tooltip:Hide()
end
