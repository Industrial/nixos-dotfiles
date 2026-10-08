-- Variables --
---@class BetterBags: AceAddon
local BetterBags = LibStub('AceAddon-3.0'):GetAddon("BetterBags")
assert(BetterBags, "BetterBags - Appearances requires BetterBags")

---@class Categories: AceModule
local Categories = BetterBags:GetModule('Categories')

---@class Localization: AceModule
local L = BetterBags:GetModule('Localization')

---@class AceDB-3.0: AceModule
local AceDB = LibStub("AceDB-3.0")

---@class Appearances: AceModule
local Appearances = BetterBags:NewModule('Appearances')

---@class Config: AceModule
local Config = BetterBags:GetModule('Config')

---@class Events: AceModule
local Events = BetterBags:GetModule('Events')

---@class Context: AceModule
local Context = BetterBags:GetModule('Context')

local defaults = {
    profile = {
        createLearnable = true,
        createTradeable = true,
        createSellable = true,
        enableSubdivide = false,
        enableItemLocSplit = false,
    },
}

local db

local configOptions = {
    createCategories = {
        name = L:G("Create Categories"),
        type = "group",
        order = 1,
        inline = false,
        args = {
            createLearnable = {
                type = "toggle",
                order = 2,
                name = "Create Learnable",
                desc = "This will create the category 'Mog - Learnable'.",
                get = function(info)
                    return Appearances.db.profile.createLearnable
                end,
                set = function(info, value)
                    Appearances.db.profile.createLearnable = value
                    Appearances:ClearExistingCategories()
                    local ctx = Context:New('BBAppearances_RefreshAll')
                    Events:SendMessage(ctx, 'bags/FullRefreshAll')
                end,
            },
            createTradeable = {
                type = "toggle",
                order = 3,
                name = "Create Tradeable",
                desc = "This will create the category 'Mog - Tradeable'.",
                get = function(info)
                    return Appearances.db.profile.createTradeable
                end,
                set = function(info, value)
                    Appearances.db.profile.createTradeable = value
                    Appearances:ClearExistingCategories()
                    local ctx = Context:New('BBAppearances_RefreshAll')
                    Events:SendMessage(ctx, 'bags/FullRefreshAll')
                end,
            },
            createSellable = {
                type = "toggle",
                order = 4,
                name = "Create Sellable",
                desc = "This will create the category 'Mog - Sellable'.",
                get = function(info)
                    return Appearances.db.profile.createSellable
                end,
                set = function(info, value)
                    Appearances.db.profile.createSellable = value
                    Appearances:ClearExistingCategories()
                    local ctx = Context:New('BBAppearances_RefreshAll')
                    Events:SendMessage(ctx, 'bags/FullRefreshAll')
                end,
            },
        },
    },
    splitGroup = {
        name = L:G("Item Splitting Options"),
        type = "group",
        order = 5,
        inline = true,
        args = {
            splitByType = {
                type = "toggle",
                order = 6,
                name = "Split by Item Type",
                desc = "This will split tradable items into categories based on their type.",
                get = function(info)
                    return Appearances.db.profile.enableSubdivide
                end,
                set = function(info, value)
                    Appearances.db.profile.enableSubdivide = value
                    Appearances:ClearExistingCategories()
                    local ctx = Context:New('BBAppearances_RefreshAll')
                    Events:SendMessage(ctx, 'bags/FullRefreshAll')
                end,
            },
            splitByLoc = {
                type = "toggle",
                order = 7,
                name = "Split by Item Location",
                desc = "This will split tradable items into categories based on their equip slot.",
                get = function(info)
                    return Appearances.db.profile.enableItemLocSplit
                end,
                set = function(info, value)
                    Appearances.db.profile.enableItemLocSplit = value
                    Appearances:ClearExistingCategories()
                    local ctx = Context:New('BBAppearances_RefreshAll')
                    Events:SendMessage(ctx, 'bags/FullRefreshAll')
                end,
            },
            forceRefreshItems = {
                type = "execute",
                order = 8,
                name = "Force Refresh",
                desc = "This will forcibly refresh the Item categories.",
                func = function()
                    Appearances:ClearExistingCategories()
                    local ctx = Context:New('BBAppearances_RefreshAll')
                    Events:SendMessage(ctx, 'bags/FullRefreshAll')
                end,
            },
        },
    },
}

local nonEquippableTypes = {
    ["INVTYPE_NON_EQUIP_IGNORE"] = true,
    ["INVTYPE_TRINKET"] = true,
    ["INVTYPE_FINGER"] = true,
    ["INVTYPE_NECK"] = true,
    ["INVTYPE_BAG"] = true,
    ["INVTYPE_PROFESSION_TOOL"] = true,
    ["INVTYPE_PROFESSION_GEAR"] = true,
}

-- Create a hidden tooltip for scanning
local scanTooltip = CreateFrame("GameTooltip", "BindCheckTooltipScanner", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local itemIdsToIgnore = {
    [13289] = true, -- Egan's Blaster
    [49888] = true, -- Shadow's Edge
    [71084] = true, -- Branch of Nordrassil
    [71085] = true, -- Runestaff of Nordrassil
    [77945] = true, -- Fear
    [77946] = true, -- Vengeance
    [77947] = true, -- The Sleeper
    [77948] = true, -- The Dreamer
}

local baseCategories = {
    "Mog - Learnable",
    "Mog - Tradable",
    "Mog - Sellable"
}

local equipLocs = {
    "INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_BODY", "INVTYPE_CHEST", "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET",
    "INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_FINGER", "INVTYPE_TRINKET", "INVTYPE_CLOAK", "INVTYPE_WEAPON", "INVTYPE_SHIELD", "INVTYPE_RANGED",
    "INVTYPE_2HWEAPON", "INVTYPE_TABARD", "INVTYPE_ROBE", "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND", "INVTYPE_HOLDABLE", "INVTYPE_AMMO",
    "INVTYPE_THROWN", "INVTYPE_RANGEDRIGHT", "INVTYPE_RELIC"
}

-- Functions --
-- On plugin load, wipe the categories we've added
function Appearances:OnInitialize()
    self.db = AceDB:New("BetterBags_AppearancesDB", defaults)
    self.db:SetProfile("global")
    db = self.db.profile
    
    self.categoryCache = {}
    self.slotCache = {}
    -- Pre-cache localized slot names to avoid _G lookups later
    for _, equipLoc in ipairs(equipLocs) do
        self.slotCache[equipLoc] = _G[equipLoc]
    end

    self:AddAppearancesConfig()
    self:ClearExistingCategories()
    self:KillOldCategories()
end

-- Kill the subcategories if they exist --
function Appearances:ClearExistingCategories()
    self.categoryCache = {}
    -- Function to wipe categories
    local function wipeCategories(categoryList)
        for _, category in ipairs(categoryList) do
            Categories:WipeCategory(Appearances:WrapCategoryText(category))
            Categories:WipeCategory(L:G(category))
        end
    end

    -- Base categories
    wipeCategories(baseCategories)

    -- Subcategories by weapon and armor
    local function wipeSubCategories(itemClass, minValue, maxValue, prefix)
        for i = minValue, maxValue do
            local name, _ = C_Item.GetItemSubClassInfo(itemClass, i)
            if name then
                wipeCategories({prefix .. " - " .. name})
            end
        end
    end

    wipeSubCategories(Enum.ItemClass.Weapon, Enum.ItemWeaponSubclassMeta.MinValue, Enum.ItemWeaponSubclassMeta.MaxValue, "Mog - Tradable")
    wipeSubCategories(Enum.ItemClass.Armor, Enum.ItemArmorSubclassMeta.MinValue, Enum.ItemArmorSubclassMeta.MaxValue, "Mog - Tradable")

    -- Categories by equip location
    local equipLocCategories = {}
    for _, equipLoc in ipairs(equipLocs) do
        table.insert(equipLocCategories, "Mog - Tradable - " .. self.slotCache[equipLoc])
    end
    wipeCategories(equipLocCategories)

    -- Categories by weapon and armor subtypes and equip locations
    local function wipeCombinedSubCategories(itemClass, minValue, maxValue)
        for i = minValue, maxValue do
            local subType, _ = C_Item.GetItemSubClassInfo(itemClass, i)
            if subType then
                for _, equipLoc in ipairs(equipLocs) do
                    local combinedCategory = "Mog - Tradable - " .. subType .. " - " .. self.slotCache[equipLoc]
                    wipeCategories({combinedCategory})
                end
            end
        end
    end

    wipeCombinedSubCategories(Enum.ItemClass.Weapon, Enum.ItemWeaponSubclassMeta.MinValue, Enum.ItemWeaponSubclassMeta.MaxValue)
    wipeCombinedSubCategories(Enum.ItemClass.Armor, Enum.ItemArmorSubclassMeta.MinValue, Enum.ItemArmorSubclassMeta.MaxValue)
end

function Appearances:KillOldCategories()
    Categories:WipeCategory(L:G("Other Classes"))
    Categories:WipeCategory(L:G("Unknown - Other Classes"))
    Categories:WipeCategory(L:G("Known - BoE"))
    Categories:WipeCategory(L:G("Known - BoP"))
    
    -- Loop through all classes and wipe the categories
    for i = 1, GetNumClasses() do
        local className, _ = GetClassInfo(i)
        Categories:WipeCategory(L:G(className .. " Usable"))
        Categories:WipeCategory(L:G("Unknown - " .. className))
    end
end

-- Function to wrap text in color code
function Appearances:WrapCategoryText(category)
    if not self.categoryCache[category] then
        self.categoryCache[category] = WrapTextInColorCode(L:G(category), "ff00ff00")
    end
    return self.categoryCache[category]
end

-- Function to build category string
function Appearances:BuildCategory(base, subType, equipLoc)
    if db.enableSubdivide and db.enableItemLocSplit then
        return self:WrapCategoryText(base .. " - " .. subType .. " - " .. self.slotCache[equipLoc])
    elseif db.enableSubdivide then
        return self:WrapCategoryText(base .. " - " .. subType)
    elseif db.enableItemLocSplit then
        return self:WrapCategoryText(base .. " - " .. self.slotCache[equipLoc])
    else
        return self:WrapCategoryText(base)
    end
end

-- Debug dump functions
-- @debug@
function Appearances:Dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then
                k = '"' .. k .. '"'
            end
            s = s .. '[' .. k .. '] = ' .. Dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

function Appearances:PrintTable(tbl, indent)
    if not indent then indent = 0 end
    for k, v in pairs(tbl) do
        formatting = string.rep("  ", indent) .. k .. ": "
        if type(v) == "table" then
            print(formatting)
            self:PrintTable(v, indent+1)
        elseif type(v) == 'boolean' then
            print(formatting .. tostring(v))      
        else
            print(formatting .. v)
        end
    end
end
-- @end-debug@

function Appearances:IsEquipabble(itemInfo)
    return not nonEquippableTypes[itemInfo.itemEquipLoc]
end

function Appearances:CanLearnAppearance(data)
    local itemLink = data.itemInfo.itemLink

    local itemAppearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemLink)
    if not sourceID then return nil end

    local _, canCollect = C_TransmogCollection.PlayerCanCollectSource(sourceID)
    if not canCollect then return false end

    if C_TransmogCollection.PlayerHasTransmog(itemAppearanceID) then return false end

    return true
end

function Appearances:CheckItemBindStatus(itemLink)
    -- Optimization: Check standard bind types via API first
    local bindType = select(14, C_Item.GetItemInfo(itemLink))
    if bindType == 1 then return "BoP"
    elseif bindType == 2 then return "BoE"
    elseif bindType == 8 then return "BoA"
    end

    -- Fallback to tooltip scan if API result is inconclusive (e.g. some account bound items)
    scanTooltip:ClearLines()
    scanTooltip:SetHyperlink(itemLink)

    for i = 2, scanTooltip:NumLines() do
        local lineText = _G["BindCheckTooltipScannerTextLeft" .. i]:GetText()
        if lineText then
            if lineText:find(ITEM_BIND_ON_EQUIP) then return "BoE"
            elseif lineText:find(ITEM_BIND_ON_PICKUP) then return "BoP"
            elseif lineText:find(ITEM_ACCOUNTBOUND) or lineText:find(ITEM_BIND_TO_ACCOUNT) or lineText:find(ITEM_BIND_TO_BNETACCOUNT) or lineText:find(ITEM_BNETACCOUNTBOUND) then return "BoA"
            end
        end
    end
    return "None"
end

function Appearances:IsItemIgnored(itemID)
    return itemIdsToIgnore[itemID]
end

function Appearances:AddAppearancesConfig()
    if not Config or not configOptions then
        print("Failed to load configurations for BetterBags - Appearances plugin.")
        return
    end

    Config:AddPluginConfig("Appearances", configOptions)
end

Events:RegisterEvent('TRANSMOG_COLLECTION_SOURCE_ADDED', function()
    Appearances:ClearExistingCategories()
end)

Events:RegisterEvent('TRANSMOG_COLLECTION_SOURCE_REMOVED', function()
    Appearances:ClearExistingCategories()
end)

-- Register the category function
Categories:RegisterCategoryFunction("MogCategorization", function(data)
    -- Exclude non-equipable, legendaries, and artifacts
    if not Appearances:IsEquipabble(data.itemInfo) or data.itemInfo.itemQuality == 6 or data.itemInfo.itemQuality == 5 or Appearances:IsItemIgnored(data.itemInfo.itemID) or C_Heirloom.IsItemHeirloom(data.itemInfo.itemID) then
        return nil
    end

    local bindType = Appearances:CheckItemBindStatus(data.itemInfo.itemLink)
    local canLearn = Appearances:CanLearnAppearance(data)

    -- If the item cannot be learned
    if not canLearn then
        -- Handle BoA items separately, as they are bound but tradable across the account
        if bindType == "BoA" then
            if db.createTradeable then
                return Appearances:BuildCategory("Mog - Tradable", data.itemInfo.itemSubType, data.itemInfo.itemEquipLoc)
            end
        -- Check if the item is bound and not BoA, categorize as "Mog - Sellable"
        elseif data.itemInfo.isBound or bindType == "BoP" then
            if db.createSellable then
                return Appearances:WrapCategoryText("Mog - Sellable")
            end
        elseif bindType == "BoE" then
            -- If the item is BoE and not bound, it's tradable
            if db.createTradeable then
                return Appearances:BuildCategory("Mog - Tradable", data.itemInfo.itemSubType, data.itemInfo.itemEquipLoc)
            end
        end
    elseif canLearn then
        -- If the item's appearance can be learned
        if db.createLearnable then
            return Appearances:WrapCategoryText("Mog - Learnable")
        end
    end
    
    return nil
end)