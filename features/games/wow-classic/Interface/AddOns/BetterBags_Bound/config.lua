---@class ns
local addon = select(2, ...)

-- BetterBags namespace
-----------------------------------------------------------
---@class BetterBags: AceAddon
local BetterBags = LibStub('AceAddon-3.0'):GetAddon("BetterBags")

---@class Categories: AceModule
---@field CreateCategory fun(self: Categories, ctx: Context, category: CustomCategoryFilter): nil
---@field DeleteCategory fun(self: Categories, ctx: Context, name: string): nil
---@field WipeCategory fun(self: Categories, ctx: Context, name: string): nil
---@field ReprocessAllItems fun(self: Categories, ctx: Context): nil
local Categories = BetterBags:GetModule('Categories')

---@class Localization: AceModule
local L = BetterBags:GetModule('Localization')

---@class Events: AceModule
---@field SendMessage fun(self: Events, ctx: Context, message: string, ...: any): nil
local Events = BetterBags:GetModule('Events')

---@class Items: AceModule
local Items = BetterBags:GetModule('Items')

addon.options = {
	boundOptions = {
		type = "group",
		name = L:G("BoE & BoA"),
		order = 0,
		inline = true,
		args = {
			enableBoe = {
				type = "toggle",
				order = 0,
				name = L:G("Category: BoE"),
				desc = L:G("If enabled, will categorize BoE items."),
				get = function()
					return addon.db.enableBoe
				end,
				set = function(_, value)
					addon.db.enableBoe = value
					if (addon.db.enableBoe) then
						Categories:CreateCategory(addon.ctx:Copy(), {
							name = L:G(addon.S_BOE),
							itemList = {},
							save = false,
						})
						Categories:ReprocessAllItems(addon.ctx:Copy())
					else
						Categories:DeleteCategory(addon.ctx:Copy(), L:G(addon.S_BOE))
						addon:ForgetCategory(addon.S_BOE)
					end
				end,
			},
			enableWue = {
				type = "toggle",
				order = 1,
				name = L:G("Category: WuE"),
				desc = L:G("If enabled, will categorize WuE items."),
				get = function()
					return addon.db.enableWue
				end,
				set = function(_, value)
					addon.db.enableWue = value
					if (addon.db.enableWue) then
						Categories:CreateCategory(addon.ctx:Copy(), {
							name = L:G(addon.S_WUE),
							itemList = {},
							save = false,
						})
						Categories:ReprocessAllItems(addon.ctx:Copy())
					else
						Categories:DeleteCategory(addon.ctx:Copy(), L:G(addon.S_WUE))
						addon:ForgetCategory(addon.S_WUE)
					end
				end,
			},
			enableBoa = {
				type = "toggle",
				order = 2,
				name = L:G("Category: BoA"),
				desc = L:G("If enabled, will categorize BoA items."),
				get = function()
					return addon.db.enableBoa
				end,
				set = function(_, value)
					addon.db.enableBoa = value
					if (addon.db.enableBoa) then
						Categories:CreateCategory(addon.ctx:Copy(), {
							name = L:G(addon.S_BOA),
							itemList = {},
							save = false,
						})
						Categories:ReprocessAllItems(addon.ctx:Copy())
					else
						Categories:DeleteCategory(addon.ctx:Copy(), L:G(addon.S_BOA))
						addon:ForgetCategory(addon.S_BOA)
					end
				end,
			},
			enableBop = {
				type = "toggle",
				order = 3,
				name = L:G("Category: Soulbound"),
				desc = L:G("If enabled, will categorize BoP items."),
				get = function()
					return addon.db.enableBop
				end,
				set = function(_, value)
					addon.db.enableBop = value
					if (addon.db.enableBop) then
						Categories:CreateCategory(addon.ctx:Copy(), {
							name = L:G(addon.S_BOP),
							itemList = {},
							save = true,
						})
						Categories:ReprocessAllItems(addon.ctx:Copy())
					else
						Categories:DeleteCategory(addon.ctx:Copy(), L:G(addon.S_BOP))
						addon:ForgetCategory(addon.S_BOP)
					end
				end,
			},
			onlyEquippable = {
				type = "toggle",
				width = "full",
				order = 10,
				name = L:G("Only Equippable"),
				desc = L:G("Only categorize equippable items. This prevents a multitude of items from being lumped into \"Warbound\"."),
				get = function()
					return addon.db.onlyEquippable
				end,
				set = function(_, value)
					addon.db.onlyEquippable = value
					if (addon.db.onlyEquippable) then
						for _, category in ipairs({ addon.S_BOA, addon.S_BOE, addon.S_WUE }) do
							Categories:WipeCategory(addon.ctx:Copy(), L:G(category))
							addon:ForgetCategory(category)
						end
						Categories:ReprocessAllItems(addon.ctx:Copy())
					end
				end,
			},
			wipeOnLoad = {
				type = "toggle",
				width = "full",
				order = 20,
				name = L:G("Wipe Categories"),
				desc = L:G("Wipe categories on load. This prevent equipped items from being categorized as Bound still. Only affects the next reload/login."),
				get = function()
					return addon.db.wipeOnLoad
				end,
				set = function(_, value)
					addon.db.wipeOnLoad = value
				end,
			},
		}
	}
}
