---@class BetterBags: AceAddon
local BetterBags = LibStub('AceAddon-3.0'):GetAddon("BetterBags")

---@class Categories: AceModule
local categories = BetterBags:GetModule('Categories')

local addonName, root = ...;
local L = root.L;
local _G = _G

---@class BetterBags_Legendary: AceModule
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

--@param itemInfo ItemData.itemInfo
function addon:IsLegendaryPlus(itemInfo)
    local quality = itemInfo.itemQuality

    return quality and quality >= _G.Enum.ItemQuality.Legendary
end

--@param data ItemData
function addon:GetLegendaryPlusCategory(data)
    if (addon:IsLegendaryPlus(data.itemInfo)) then
        local quality = data.itemInfo.itemQuality

        if (quality) then
            if (BetterBags_LegendaryDB.independentLegendary and quality == _G.Enum.ItemQuality.Legendary) then
                return L["OPTIONS_CAT_LEGENDARY"]
            elseif (BetterBags_LegendaryDB.independentArtifact and quality == _G.Enum.ItemQuality.Artifact) then
                return L["OPTIONS_CAT_ARTIFACT"]
            elseif (BetterBags_LegendaryDB.independentHeirloom and quality == _G.Enum.ItemQuality.Heirloom) then
                return L["OPTIONS_CAT_HEIRLOOM"]
            elseif (BetterBags_LegendaryDB.independentToken and quality == _G.Enum.ItemQuality.WoWToken) then
                return L["OPTIONS_CAT_TOKEN"]
            end
        end

        return L["CATEGORY_NAME"]
    end

    return nil
end

-- Check if the priority addon is available
local BetterBagsPriority = LibStub('AceAddon-3.0'):GetAddon("BetterBags_Priority", true)
local priorityEnabled = BetterBagsPriority ~= nil or false

-- If the priority addon is available, we register the custom category as an empty filter with BetterBags to keep the
-- "enable system" working. The actual filtering will be done by the priority addon
if (priorityEnabled) then
    local categoriesWithPriority = BetterBagsPriority:GetModule('Categories')

    --@param data ItemData
    categories:RegisterCategoryFunction("LegendaryCategoryFilter", function(data)
        return nil
    end)

    --@param data ItemData
    categoriesWithPriority:RegisterCategoryFunction(L["CATEGORY_NAME"], "LegendaryCategoryFilter", function(data)
        return addon:GetLegendaryPlusCategory(data)
    end)
else
    --@param data ItemData
    categories:RegisterCategoryFunction("LegendaryCategoryFilter", function(data)
        return addon:GetLegendaryPlusCategory(data)
    end)
end
