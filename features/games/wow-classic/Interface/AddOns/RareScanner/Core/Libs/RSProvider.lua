-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local LibStub = _G.LibStub
local ADDON_NAME, private = ...

local RSProvider = private.NewLib("RareScannerProvider")

local RSWorldMap = private.ImportLib("RareScannerWorldMap")
local RareScannerBlizzardMapProvider

local providers = {}

function RSProvider.DropDataProvider(provider)
	if (provider) then
		WorldMapFrame:RemoveDataProvider(provider)
		provider:OnHide() --fixes https://legacy.curseforge.com/wow/addons/rarescanner/issues/339
	end
end

function RSProvider.AddDataProvider(provider)
	if (provider) then
		providers[provider] = true
		RSWorldMap:AddDataProvider(provider);
	end
end

function RSProvider.RefreshAllDataProviders()
	for dp, _ in pairs(providers) do
		dp:RefreshAllData()
	end
	if (not RareScannerBlizzardMapProvider) then
		RareScannerBlizzardMapProvider = private.ImportLib("RareScannerBlizzardMapProvider")
	end
	
	RareScannerBlizzardMapProvider:RefreshAllData()
	
	local RSRoute = private.ImportLib("RareScannerRoute")
	RSRoute.OnMapEntitiesChanged()
end