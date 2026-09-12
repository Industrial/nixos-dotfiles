local addonName, root = ...;
local L = root.L;

---@class BetterBags_Legendary: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

--- BetterBags dependencies
-----------------------------
---@class BetterBags: AceAddon
local BetterBags = LibStub('AceAddon-3.0'):GetAddon("BetterBags")
---@class Categories: AceModule
local categories = BetterBags:GetModule('Categories')
---@class Config: AceModule
local config = BetterBags:GetModule('Config')
---@class Events: AceModule
local events = BetterBags:GetModule('Events')
-----------------------------

local debounceTimer
local pendingCategories = {}

local updateSavedVariables = function()
    BetterBags_LegendaryDB = addon.db
end

local updateCategory = function(categoryEnabled, categoryName)
    if debounceTimer then
        debounceTimer:Cancel()
    end

    -- store the latest requested state for this category
    pendingCategories[categoryName] = categoryEnabled

    -- We wait for the value not to be changed for 1 second before refreshing the categories
    debounceTimer = C_Timer.NewTimer(1, function()
        updateSavedVariables()

        -- Process all pending category updates
        for name, enabled in pairs(pendingCategories) do
            if (enabled) then
                addon:GetOrCreateBetterBagsCategory(name)
                categories:WipeCategory(L["CATEGORY_NAME"])
                categories:WipeCategory(name)
            else
                categories:WipeCategory(L["CATEGORY_NAME"])
                categories:WipeCategory(name)
                categories:DeleteCategory(name)
            end
        end

        -- clear the pending table
        for k in pairs(pendingCategories) do
            pendingCategories[k] = nil
        end

        events:SendMessage('bags/FullRefreshAll')
    end)
end

--- Options panel
-----------------------------
addon.options = {
    a = {
        name = function()
            config.configFrame.layout:AddInlineSubSection({
                title = L["OPTIONS_CAT_LEGENDARY"],
                description = L["OPTIONS_DESC"],
            })
        end,
    },
    b = {
        type = "toggle",
        name = L["OPTIONS_CAT_LEGENDARY"],
        get = function() return addon.db.independentLegendary end,
        set = function(_, value)
            addon.db.independentLegendary = value
            updateCategory(value, L["OPTIONS_CAT_LEGENDARY"])
        end
    },
    c = {
        type = "toggle",
        name = L["OPTIONS_CAT_ARTIFACT"],
        get = function() return addon.db.independentArtifact end,
        set = function(_, value)
            addon.db.independentArtifact = value
            updateCategory(value, L["OPTIONS_CAT_ARTIFACT"])
        end
    },
    d = {
        type = "toggle",
        name = L["OPTIONS_CAT_HEIRLOOM"],
        get = function() return addon.db.independentHeirloom end,
        set = function(_, value)
            addon.db.independentHeirloom = value
            updateCategory(value, L["OPTIONS_CAT_HEIRLOOM"])
        end
    },
    e = {
        type = "toggle",
        name = L["OPTIONS_CAT_TOKEN"],
        get = function() return addon.db.independentToken end,
        set = function(_, value)
            addon.db.independentToken = value
            updateCategory(value, L["OPTIONS_CAT_TOKEN"])
        end
    }
}
