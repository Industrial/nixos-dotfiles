local BetterBags = LibStub("AceAddon-3.0"):GetAddon("BetterBags")
assert(BetterBags, "BetterBags_Hearthstones requires BetterBags")

local categories = BetterBags:GetModule("Categories")
local BL = BetterBags:GetModule("Localization")
local context = BetterBags:GetModule("Context")
local ctx = context:New("BetterBags_Hearthstones")

local _, addon = ...

-- wipe Teleporters and BearLeeAble's Ultimate categories, as they duplicate this category with fewer items
categories:WipeCategory(ctx, BL:G("Teleporters"))
categories:WipeCategory(ctx, BL:G("|cff16A0FFHearthstones|r"))

-- create a category and populate with itemIDs
for itemID in pairs(addon.db) do
	categories:AddItemToCategory(ctx, itemID, BL:G(TUTORIAL_TITLE31))
end