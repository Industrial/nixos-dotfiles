local addonName, root = ...;
local L = root.L;

---@class BetterBags_Tabards: AceModule
local addon = LibStub("AceAddon-3.0"):NewAddon(root, addonName, 'AceHook-3.0')

--- BetterBags dependencies
-----------------------------
---@class BetterBags: AceAddon
local BetterBags = LibStub('AceAddon-3.0'):GetAddon("BetterBags")
assert(BetterBags, "BetterBags_Tabards requires BetterBags")
---@class Categories: AceModule
local categories = BetterBags:GetModule('Categories')
-----------------------------

--- Addon core
-----------------------------
addon.eventFrame = CreateFrame("Frame", addonName .. "EventFrame", UIParent)
addon.eventFrame:RegisterEvent("ADDON_LOADED")
addon.eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
        local name = ...;
        if name == addonName then
            addon:OnReady()
        end
    end
end)

function addon:OnReady()
    local categoryAlreadyExists = categories:GetCategoryByName(L["CATEGORY_NAME"])

    if not categoryAlreadyExists then
        categories:CreateCategory({
            name = L["CATEGORY_NAME"],
            save = true,
            itemList = {},
        })
    end
end
