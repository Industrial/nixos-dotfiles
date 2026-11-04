---@type string
local addonName = ...
---@class ns
local addon = select(2, ...)

--[==[@debug@
_G["BBBound"] = addon
--@end-debug@]==]

-- BetterBags namespace
-----------------------------------------------------------
---@class BetterBags: AceAddon
local BetterBags = LibStub('AceAddon-3.0'):GetAddon("BetterBags")
assert(BetterBags, addonName .. " requires BetterBags")

---@class Categories: AceModule
local Categories = BetterBags:GetModule('Categories')

---@class Events: AceModule
local Events = BetterBags:GetModule('Events')

-- Use the L:G() function to get the localized string.
---@class Localization: AceModule
---@field G fun(self: AceModule, key: string): string
local L = BetterBags:GetModule('Localization')

---@class Context: AceModule
---@field New fun(self: AceModule, key: string): Context
---@field Copy fun(self: AceModule): Context
local context = BetterBags:GetModule('Context')

---@class Config: AceModule
---@field AddPluginConfig fun(self: Config, name: string, options: AceConfig.OptionsTable): nil
local Config = BetterBags:GetModule('Config')

addon.ctx = context:New('Bound_Event')
addon.context = context

-- Lua API
-----------------------------------------------------------
local _G = _G

-- WoW API
-----------------------------------------------------------
local CreateFrame = _G.CreateFrame

-- Default settings.
-----------------------------------------------------------
addon.db = {
	enableBop = false,
	enableWue = true,
	enableBoe = true,
	enableBoa = true,
	onlyEquippable = true,
	wipeOnLoad = true,
}

-- Addon Constants
-----------------------------------------------------------
addon.S_BOA = "BoA"
addon.S_BOE = "BoE"
addon.S_WUE = "WuE"
addon.S_BOP = "Soulbound"
addon.IsRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
addon.IsClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
addon.IsBCC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
addon.IsCata = WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC
addon.IsMists = WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC

-- Addon Core
-----------------------------------------------------------
addon.eventFrame = CreateFrame("Frame", addonName .. "EventFrame", UIParent)
addon.eventFrame:RegisterEvent("ADDON_LOADED")

if not addon.IsClassic then -- events are scuffed in Classic
	addon.eventFrame:RegisterEvent("EQUIP_BIND_CONFIRM")
	addon.eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
end

addon.eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		if name == addonName then
			addon.eventFrame:UnregisterEvent("ADDON_LOADED")
			if (type(BetterBags_Bound_SavedVars) ~= "table") then BetterBags_Bound_SavedVars = {} end
			local db = BetterBags_Bound_SavedVars
			for key in pairs(addon.db) do
				--  If our option is not present, set default value
				if (db[key] == nil) then db[key] = addon.db[key] end
				-- Migrate DB for backwards compatibility
				if (db.enableWoe ~= nil) then
					db.enableWue = db.enableWoe
					db.enableWoe = nil
				end
			end
			-- Update our reference so that changed options are saved on logout
			addon.db = db
			-- Wipe categories on load.
			if (addon.db.wipeOnLoad) then
				for _, category in ipairs({ addon.S_BOA, addon.S_BOE, addon.S_WUE }) do
					Categories:WipeCategory(context:New('Bound_OnLoadWipe_' .. category), L:G(category))
					addon:ForgetCategory(category)
				end
			end

			-- Load config only after populating the DB, since BetterBags will cache the get function
			Config:AddPluginConfig(L:G("Bound"), addon.options)
		end
	elseif event == "EQUIP_BIND_CONFIRM" then
		local _, itemLocation = ...
		local bag, slot = itemLocation:GetBagAndSlot()
		local id = C_Item.GetItemID(itemLocation)
		local category = addon:GetItemCategory(bag, slot)
		addon.bindConfirm = { id = id, category = category }
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		local slot, hasCurrent = ...
		-- hasCurrent is false if the slot was just equipped
		if (slot ~= nil and not hasCurrent) then
			addon:RemoveBindConfirmFromCategory(slot)
		end
	end
end)
