---@class BetterBags: AceAddon
local addon = LibStub("AceAddon-3.0"):GetAddon("BetterBags")

---@class Categories: AceModule
local categories = addon:GetModule("Categories")

---@class Config: AceModule
local config = addon:GetModule("Config")

---@type Events: AceModule
local Events = addon:GetModule('Events')

---@type Context: AceModule
local Context = addon:GetModule('Context')

-- Localization
local L = _G.L or {Get = function(self, key) return key end}

----------------------------------
-- This is where the magic happens
----------------------------------

-- Color Categories
local colorPrefix_Default = "|cffa5a5ff"
local colorPrefix_Remix = "|cff1DDB7F"
local colorPrefix_20thAnniversary = "|cff1dc7db"
local resetColor = "|r"

-- Category Mapping
local categoryMappings = {
    {list = Database.Noblegarden, category = colorPrefix_Default .. L:Get("Noblegarden") .. resetColor},
    {list = Database.Darkmoonfaire, category = colorPrefix_Default .. L:Get("Darkmoon Faire") .. resetColor},
    {list = Database.LunarFestival, category = colorPrefix_Default .. L:Get("Lunar Festival") .. resetColor},
    {list = Database.MidsummerFireFestival, category = colorPrefix_Default .. L:Get("Midsummer Fire Festival") .. resetColor},
    {list = Database.Brewfest, category = colorPrefix_Default .. L:Get("Brewfest") .. resetColor},
    {list = Database.WoWRemix, category = colorPrefix_Remix .. L:Get("Remix") .. resetColor},
    {list = Database.WoWRemixCache, category = colorPrefix_Remix .. L:Get("Remix: Cache") .. resetColor},
    {list = Database.WoWRemixArtifact, category = colorPrefix_Remix .. L:Get("Remix: Artifact") .. resetColor},
    {list = Database.WoWRemixReputation, category = colorPrefix_Remix .. L:Get("Remix: Reputation") .. resetColor},
    {list = Database.WoWRemixBuff, category = colorPrefix_Remix .. L:Get("Remix: Buff") .. resetColor},
    {list = Database.RadiantEchoes, category = colorPrefix_Default .. L:Get("Radiant Echoes") .. resetColor},
    {list = Database.WoW20thAnniversary, category = colorPrefix_20thAnniversary .. L:Get("20th Anniversary") .. resetColor},
    {list = Database.HallowsEnd, category = colorPrefix_Default .. L:Get("Hallow's End") .. resetColor},
    {list = Database.FeastOfWinterVeil, category = colorPrefix_Default .. L:Get("Feast of Winter Veil") .. resetColor},
    {list = Database.LoveIsInTheAir, category = colorPrefix_Default .. L:Get("Love is in the Air") .. resetColor},
    {list = Database.WindsOfMysteriousFortune, category = colorPrefix_Default .. L:Get("Winds of Mysterious Fortune") .. resetColor}, 
    {list = Database.DastardlyDuos, category = colorPrefix_Default .. L:Get("Dastardly Duos") .. resetColor}, 
    {list = Database.AGreedyEmissary, category = colorPrefix_Default .. L:Get("A Greedy Emissary") .. resetColor}, 
}

-- Database to store category states
BetterBagsDB = BetterBagsDB or {}
BetterBagsDB.categories = BetterBagsDB.categories or {}

-- Initialize default category states
for _, mapping in ipairs(categoryMappings) do
    if BetterBagsDB.categories[mapping.category] == nil then
        BetterBagsDB.categories[mapping.category] = true
    end
end

-- Function to update categories based on their state
function updateCategories()
    for _, mapping in ipairs(categoryMappings) do
        local catName = mapping.category
        local isEnabled = BetterBagsDB.categories[catName]

        for _, itemID in ipairs(mapping.list) do
            if isEnabled then
                categories:AddItemToCategory(itemID, catName)
            else
                categories:RemoveItemFromCategory(itemID, catName)
            end
        end
    end
end

-- Function to toggle a category
local function toggleCategory(catName, value)
    BetterBagsDB.categories[catName] = value
    updateCategories()  -- Update categories

    -- Force a full refresh of the bags
    if Events and Context then
        local ctx = Context:New('BBWorldEvents_RefreshItem')  -- Create a new context
        Events:SendMessage(ctx, 'bags/FullRefreshAll')  -- Refresh all bags
    end
end

-- User interface
local options = {
    EventCategories = {
        type = "group",
        name = "World Events",  -- Group name
        order = 1,              -- Display order
        inline = true,          -- Display inline (without a separate frame)
        args = {}               -- Arguments (options)
    }
}

-- Add options for each category
for _, mapping in ipairs(categoryMappings) do
    local categoryName = mapping.category
    options.EventCategories.args[categoryName] = {
        type = "toggle",
        name = categoryName,
        desc = "Enable or disable this category",
        order = 10,  -- Display order of options
        get = function() return BetterBagsDB.categories[categoryName] or false end,
        set = function(_, value) toggleCategory(categoryName, value) end
    }
end

-- Add configuration to BetterBags
config:AddPluginConfig("World Events", options)

-- Initial category update
updateCategories()
