-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local ADDON_NAME, private = ...

-- Locales
local AL = LibStub("AceLocale-3.0"):GetLocale("RareScanner");

-- RareScanner database libraries
local RSGeneralDB = private.ImportLib("RareScannerGeneralDB")
local RSConfigDB = private.ImportLib("RareScannerConfigDB")

-- RareScanner services
local RSMinimap = private.ImportLib("RareScannerMinimap")
local RSProvider = private.ImportLib("RareScannerProvider")
local RSTooltip = private.ImportLib("RareScannerTooltip")

RSSearchMixin = { };

function RSSearchMixin:OnLoad()
	self.EditBox:SetAutoFocus(false);

	self.EditBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus();
	end)

	-- Clears previous session searches
	RSGeneralDB.ClearWorldMapTextFilter()
end

function RSSearchMixin:OnShow()
	-- Toggle showing
	if (not RSConfigDB.IsShowingWorldMapSearcher()) then
		self.EditBox:SetText("")
		RSGeneralDB.SetWorldMapTextFilter(nil)
		self.EditBox:Hide()
		return
	end
	self.EditBox:Show()

	-- Clean on hide
	if (RSConfigDB.IsClearingWorldMapSearcher()) then
		self.EditBox:SetText("")
		RSGeneralDB.SetWorldMapTextFilter(nil)
	end

	self.EditBox:ClearFocus();
end

RSSearchBoxMixin = { };

function RSSearchBoxMixin:OnEnterPressed()
	self:RefreshAll()
end

function RSSearchBoxMixin:OnMouseEnter()
	local tooltip = RSTooltip.Tooltip
	tooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip_SetTitle(tooltip, AL["MAP_SEARCHER_TOOLTIP_TITLE"]);
	GameTooltip_AddNormalLine(tooltip, AL["MAP_SEARCHER_TOOLTIP_DESC"]);
	tooltip:Show();
end

function RSSearchBoxMixin:OnMouseLeave()
	local tooltip = RSTooltip.Tooltip
	tooltip:Hide();
end

function RSSearchBoxMixin:OnMouseDown()
	self:SetText("")
	self:RefreshAll()
end

function RSSearchBoxMixin:Clean()
	self:SetText("")
	self:RefreshAll()
end

function RSSearchBoxMixin:RefreshAll()
	self:ClearFocus();
	RSGeneralDB.SetWorldMapTextFilter(self:GetText())
	RSProvider.RefreshAllDataProviders()
	RSMinimap.RefreshAllData(true)
end
