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

local db
local defaults = {
    profile = {}
}
local configOptions

-- Get the game version
addon.data.isRetail  = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
addon.data.isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
addon.data.isTBC     = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
addon.data.isWotLK   = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC
addon.data.isCata    = WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC
addon.data.isMists   = WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC

-- “Or above” helpers for gating
local isMistsOrAbove   = addon.data.isMists   or addon.data.isRetail
local isCataOrAbove    = addon.data.isCata    or addon.data.isMists or addon.data.isRetail
local isWotLKOrAbove   = addon.data.isWotLK   or addon.data.isCata  or addon.data.isMists or addon.data.isRetail
local isTBCOrAbove     = addon.data.isTBC     or addon.data.isWotLK or addon.data.isCata  or addon.data.isMists or addon.data.isRetail
local isClassicOrAbove = addon.data.isClassic or addon.data.isTBC   or addon.data.isWotLK or addon.data.isCata  or addon.data.isMists or addon.data.isRetail

-- Kill the category from different plugin.
Categories:WipeCategory(Context:New('BBTeleporters_DeleteCategory'),TUTORIAL_TITLE31)

-- Make an empty table to store item data in...
local teleporters = {}

local function refreshTeleports()
    Teleporters:clearTeleportCategory()
    Teleporters:hydrateTeleportersTable()
    Teleporters:addTeleportersToCategory()
    local ctx = Context:New('BBTeleporters_RefreshAll')
    Events:SendMessage(ctx, 'bags/FullRefreshAll')
end

local isClassicEra = addon.data.isClassic or addon.data.isTBC or addon.data.isWotLK or addon.data.isCata

if isClassicEra then
    defaults.profile = {
        enablePortalReagents = false,
    }
end

local args = {
    forceRefreshTeleports = {
        type = "execute",
        name = "Force Refresh",
        desc = "This will forcibly refresh the Teleporters category.",
        func = refreshTeleports,
    },
}

if isClassicEra then
    args.addReagentsToCategory = {
        type = "toggle",
        name = "Add Reagents",
        desc = "This will add the mage reagents for portals to the Teleporters category.",
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

    -- Helper for batch insert
    local function loadSet(data)
        for _, v in ipairs(data) do
            if not v.condition or v.condition() then
                table.insert(teleporters, v[1])
            end
        end
    end

    if (isClassicEra) and db.enablePortalReagents then
        -- Add the reagents for mage portals to the teleporters category.
        loadSet(addon.data.enablePortalReagents)
    end

    -- Section Vanilla
    if isClassicOrAbove then
        loadSet(addon.data.classic)
    end
    -- Section TBC
    if isTBCOrAbove then
        loadSet(addon.data.tbc)
    end
    -- Section WotLK
    if isWotLKOrAbove then
        loadSet(addon.data.wotlk)
    end
    -- Section Cataclysm
    if isCataOrAbove then
        loadSet(addon.data.cata)
    end
    -- Section Mists
    if isMistsOrAbove then
        loadSet(addon.data.mists)
    end
    -- Section WoD
    if addon.data.isRetail then
        loadSet(addon.data.wod)
    end
    -- Section Legion
    if addon.data.isRetail then
        loadSet(addon.data.legion)
    end
    -- Section BFA
    if addon.data.isRetail then
        loadSet(addon.data.bfa)
    end
    -- Section Shadowlands
    if addon.data.isRetail then
        loadSet(addon.data.sl)
    end
    -- Section Dragonflight
    if addon.data.isRetail then
        loadSet(addon.data.df)
    end
    -- Section The War Within
    if addon.data.isRetail then
        loadSet(addon.data.tww)
    end
    -- Section Midnight
    if addon.data.isRetail then
        loadSet(addon.data.midnight)
    end
    if interfaceVersion >= 120002 then
        loadSet(addon.data.patchContent)
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
    db = self.db.profile

    self:addTeleportersConfig()
    self:clearTeleportCategory()
    self:hydrateTeleportersTable()
    self:addTeleportersToCategory()
end
