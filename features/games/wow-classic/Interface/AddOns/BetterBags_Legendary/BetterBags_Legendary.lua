local addonName, root = ...;
local L = root.L;

---@class BetterBags_Legendary: AceModule
local addon = LibStub("AceAddon-3.0"):NewAddon(root, addonName, 'AceHook-3.0')

--- BetterBags dependencies
-----------------------------
---@class BetterBags: AceAddon
local BetterBags = LibStub('AceAddon-3.0'):GetAddon("BetterBags")
assert(BetterBags, "BetterBags_Legendary requires BetterBags")
---@class Categories: AceModule
local categories = BetterBags:GetModule('Categories')
---@class Config: AceModule
local config = BetterBags:GetModule('Config')
---@class Context: AceModule
local context = BetterBags:GetModule('Context')
-----------------------------

--- Default config
-----------------------------
addon.context = context:New(L["CATEGORY_NAME"] .. "_Event")
addon.db = {
    independentLegendary = false,
    independentArtifact = false,
    independentHeirloom = false,
    independentToken = false,
}
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

function addon:GetOrCreateBetterBagsCategory(categoryName)
    local categoryAlreadyExists = categories:GetCategoryByName(categoryName)

    if not categoryAlreadyExists then
        categories:CreateCategory({
            name = categoryName,
            save = true,
            itemList = {},
        })
    end

    return categories:GetCategoryByName(categoryName)
end

function addon:OnReady()
    if (type(BetterBags_LegendaryDB) ~= "table") then BetterBags_LegendaryDB = {} end

    -- Update local db with saved variables
    local db = BetterBags_LegendaryDB
    for key in pairs(addon.db) do
        --  If our option is not present, set default value
        if (db[key] == nil) then db[key] = addon.db[key] end
    end
    addon.db = db

    -- Clean category on load
    categories:WipeCategory(addon.context:Copy(), L["CATEGORY_NAME"])

    -- Add addon config to BetterBags
    config:AddPluginConfig(L["CATEGORY_NAME"], addon.options)

    -- Create addon category if it doesn't already exist
    addon:GetOrCreateBetterBagsCategory(L["CATEGORY_NAME"])

    if (addon.db.independentLegendary) then
        addon:GetOrCreateBetterBagsCategory(L["OPTIONS_CAT_LEGENDARY"])
    end

    if (addon.db.independentArtifact) then
        addon:GetOrCreateBetterBagsCategory(L["OPTIONS_CAT_ARTIFACT"])
    end

    if (addon.db.independentHeirloom) then
        addon:GetOrCreateBetterBagsCategory(L["OPTIONS_CAT_HEIRLOOM"])
    end

    if (addon.db.independentToken) then
        addon:GetOrCreateBetterBagsCategory(L["OPTIONS_CAT_TOKEN"])
    end
end
