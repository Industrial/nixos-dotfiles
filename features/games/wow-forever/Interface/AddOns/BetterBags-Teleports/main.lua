-- Variables --
---@class BetterBags: AceAddon
local BetterBags = LibStub('AceAddon-3.0'):GetAddon("BetterBags")
assert(BetterBags, "BetterBags - Teleports requires BetterBags")

---@class Categories: AceModule
local Categories = BetterBags:GetModule('Categories')

---@class Localization: AceModule
local L = BetterBags:GetModule('Localization')

---@class Teleporters: AceModule
local Teleporters = BetterBags:NewModule('Teleporters')

---@class AceDB-3.0: AceModule
local AceDB = LibStub("AceDB-3.0")

---@class Config: AceModule
local Config = BetterBags:GetModule('Config')

---@class Context: AceModule
local Context = BetterBags:GetModule('Context')

---@class Events: AceModule
local Events = BetterBags:GetModule('Events')

---@type string, AddonNS
local _, addon = ...

local _, _, _, interfaceVersion = GetBuildInfo()

local defaults = {
    profile = {}
}
local configOptions

-- Get the game version
-- WoW: Forever (Camelot) reports WOW_PROJECT_MAINLINE, but its content is vanilla-based.
-- It is flagged by data/forever.lua, which only BetterBags-Teleports_Camelot.toc loads.
addon.data.isForever = addon.isForever == true
addon.data.isRetail  = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and not addon.data.isForever
addon.data.isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
addon.data.isTBC     = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
addon.data.isWotLK   = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC
addon.data.isCata    = WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC
addon.data.isMists   = WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC

-- Every addon.data table, in load order. Each client's .toc decides which data files
-- (and therefore which of these tables) exist; missing ones are skipped.
local sections = {
    "classic", "tbc", "wotlk", "cata", "mists", "wod", "legion",
    "bfa", "sl", "df", "tww", "midnight", "forever",
}

-- Kill the category from different plugin.
if TUTORIAL_TITLE31 then
    Categories:WipeCategory(Context:New('BBTeleporters_DeleteCategory'),TUTORIAL_TITLE31)
end

-- Make an empty table to store item data in...
local teleporters = {}

local function refreshTeleports()
    Teleporters:clearTeleportCategory()
    Teleporters:hydrateTeleportersTable()
    Teleporters:addTeleportersToCategory()
    local ctx = Context:New('BBTeleporters_RefreshAll')
    Events:SendMessage(ctx, 'bags/FullRefreshAll')
end

-- Forever keeps the vanilla mage portal reagents, so it gets the same reagent option.
local isClassicEra = addon.data.isClassic or addon.data.isTBC or addon.data.isWotLK or addon.data.isCata or addon.data.isForever

if isClassicEra then
    defaults.profile = {
        enablePortalReagents = false,
    }
end

local args = {
    forceRefreshTeleports = {
        type = "execute",
        name = L:G("Force Refresh"),
        desc = L:G("This will forcibly refresh the Teleporters category."),
        func = refreshTeleports,
    },
}

if isClassicEra then
    args.addReagentsToCategory = {
        type = "toggle",
        name = L:G("Add Reagents"),
        desc = L:G("This will add the mage reagents for portals to the Teleporters category."),
        get = function()
            return Teleporters.db.profile.enablePortalReagents
        end,
        set = function(_, value)
            Teleporters.db.profile.enablePortalReagents = value
            refreshTeleports()
        end,
    }

    configOptions = {
        classicOptions = {
            name = L:G("Classic Options"),
            type = "group",
            order = 1,
            inline = true,
            args = args,
        },
    }
else
    configOptions = {
        retailOptions = {
            name = L:G("Options"),
            type = "group",
            order = 1,
            inline = true,
            args = args,
        },
    }
end

function Teleporters:addTeleportersConfig()
    if not Config or not configOptions then
        print("Failed to load configurations for Teleporters plugin.")
        return
    end

    Config:AddPluginConfig("Teleporters", configOptions)
end

function Teleporters:clearTeleportCategory()
    Categories:WipeCategory(Context:New('BBTeleporters_DeleteCategory'),L:G("Teleporters"))
end

function Teleporters:hydrateTeleportersTable()
    -- Clear the table of items if needed.
    table.wipe(teleporters)

    -- Helper for batch insert. Entries may carry:
    --   condition    = function returning true when the item should be added
    --   minInterface = lowest interface version the item exists in (for items patched in later)
    local function loadSet(data)
        -- Each .toc only loads the data files its client needs, so tables can be missing.
        if not data then return end
        for _, v in ipairs(data) do
            if (not v.condition or v.condition())
                and (not v.minInterface or interfaceVersion >= v.minInterface) then
                table.insert(teleporters, v[1])
            end
        end
    end

    if isClassicEra and Teleporters.db.profile.enablePortalReagents then
        -- Add the reagents for mage portals to the teleporters category.
        loadSet(addon.data.enablePortalReagents)
    end

    for _, section in ipairs(sections) do
        loadSet(addon.data[section])
    end
end

function Teleporters:addTeleportersToCategory()
    local ctx = Context:New('BBTeleporters_AddItemToCategory')
    local categoryName = L:G("Teleporters")
    -- Loop through list of teleporters and add to category.
    for _, itemID in ipairs(teleporters) do
        Categories:AddItemToCategory(ctx, itemID, categoryName)
    end
end

-- On plugin load, wipe the Categories we've added
function Teleporters:OnInitialize()
    self.db = AceDB:New("BetterBags_TeleportersDB", defaults)
    self.db:SetProfile("global")

    self:addTeleportersConfig()
    self:clearTeleportCategory()
    self:hydrateTeleportersTable()
    self:addTeleportersToCategory()
end
