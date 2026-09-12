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
function addon:IsTabard(itemInfo)
    return itemInfo.itemEquipLoc == "INVTYPE_TABARD"
end

--@param data ItemData
function addon:GetTabardCategory(data)
	if (addon:IsTabard(data.itemInfo)) then
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
    categories:RegisterCategoryFunction("TabardCategoryFilter", function(data)
        return nil
    end)

    --@param data ItemData
    categoriesWithPriority:RegisterCategoryFunction(L["CATEGORY_NAME"], "TabardCategoryFilter", function(data)
        return addon:GetTabardCategory(data)
    end)
else
    --@param data ItemData
    categories:RegisterCategoryFunction("TabardCategoryFilter", function(data)
        return addon:GetTabardCategory(data)
    end)
end
