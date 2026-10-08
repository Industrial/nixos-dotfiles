local addonName, addon = ...

-- Get reference to BetterBags addon
local BetterBags = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
local categories = BetterBags:GetModule('Categories')
local L = BetterBags:GetModule('Localization')
local DF_Knowledge = addon.DF_Knowledge
local TWW_Knowledge = addon.TWW_Knowledge


for _, itemList in pairs({DF_Knowledge}) do
    for _, ItemID in pairs(itemList) do
        categories:AddItemToCategory(ItemID, L:G("DF Crafting Knowledge"))
    end
end

for _, itemList in pairs({TWW_Knowledge}) do
    for _, ItemID in pairs(itemList) do
        categories:AddItemToCategory(ItemID, L:G("TWW Crafting Knowledge"))
    end
end
