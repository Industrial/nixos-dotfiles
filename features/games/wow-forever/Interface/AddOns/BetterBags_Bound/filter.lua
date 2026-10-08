---@class ns
local addon = select(2, ...)

-- BetterBags namespace
-----------------------------------------------------------
---@class BetterBags: AceAddon
local BetterBags = LibStub('AceAddon-3.0'):GetAddon("BetterBags")

---@class Categories: AceModule
---@field GetCategoryByName fun(self: Categories, name: string): CustomCategoryFilter|nil
---@field RemoveItemFromCategory fun(self: Categories, itemID: number, category?: string): nil
---@field RegisterCategoryFunction fun(self: Categories, name: string, fn: fun(data: ItemData): string|nil): nil
local Categories = BetterBags:GetModule('Categories')

---@class Events: AceModule
local Events = BetterBags:GetModule('Events')

---@class Database: AceModule
---@field GetItemCategoryByItemID fun(self: Database, itemID: number): CustomCategoryFilter|nil
local Database = BetterBags:GetModule('Database')

-- Use the L:G() function to get the localized string.
---@class Localization: AceModule
local L = BetterBags:GetModule('Localization')

---@class Constants: AceModule
---@field BINDING_SCOPE BindingScopes
---@field BAG_KIND table<string, BagKind>
local Constants = BetterBags:GetModule('Constants')

local Scope = Constants.BINDING_SCOPE

-- Our own record of what we filed each item under, keyed by item ID and holding the
-- unlocalized category key. BetterBags tracks the same thing, but only on a field its
-- Categories module marks private, so we keep our own rather than reach into it.
---@type table<number, string>
addon.itemCategories = {}

-- Stripped from release builds by the packager, leaving the no-op behind.
---@param fmt string
---@param ... any
local function debugPrint(fmt, ...) end
--[==[@debug@
debugPrint = function(fmt, ...)
	print("BBBound: " .. fmt:format(...))
end
--@end-debug@]==]

-- Lua API
-----------------------------------------------------------
local _G = _G
local math_min = math.min
local string_find = string.find

---@param inputString string
---@param patterns string[]
---@return boolean|nil
local function str_matchm(inputString, patterns)
	for i = 1, #patterns do
		if string_find(inputString, patterns[i], 1, true) then
			return true
		end
	end
	return nil
end

-- WoW API
-----------------------------------------------------------
local CreateFrame = CreateFrame
local C_TooltipInfo_GetBagItem = C_TooltipInfo and C_TooltipInfo.GetBagItem

-- Equip locations GetItemInfo reports for items that cannot be worn. We read that field
-- rather than ask C_Item.IsEquippableItem: during BetterBags' login sweep on 12.1 that call
-- answers false for every bag item, by ID and by link alike, while GetItemInfo is already
-- returning names and equip locations for the same items. BetterBags caches a nil verdict per
-- item ID for the session, so one wrong answer at login hides the item until reload.
---@type table<string, boolean>
local NON_EQUIP_LOCATIONS = {
	[""] = true,
	INVTYPE_NON_EQUIP = true,
	INVTYPE_NON_EQUIP_IGNORE = true,
}

-----------------------------------------------------------
-- Filter Setup
-----------------------------------------------------------
local BOP_STRINGS = { ITEM_SOULBOUND, ITEM_BIND_ON_PICKUP }
local BOA_STRINGS = { ITEM_ACCOUNTBOUND, ITEM_BNETACCOUNTBOUND, ITEM_BIND_TO_ACCOUNT, ITEM_BIND_TO_BNETACCOUNT }
local WUE_STRINGS = { ITEM_ACCOUNTBOUND_UNTIL_EQUIP, ITEM_BIND_TO_ACCOUNT_UNTIL_EQUIP }

-- Identifies the binding line in C_TooltipInfo data. Retail only. The line carries a
-- `bonding` boolean rather than an Enum.TooltipDataItemBinding value, so the localized
-- leftText is still the only thing that names which binding it is.
local ITEM_BINDING_LINE = Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemBinding

--- Get the category of an item based on its binding info.
--- @param bindingInfo BindingInfo
--- @param bindType? Enum.ItemBind|nil
--- @return string|nil
function addon:GetBindingInfoCategory(bindingInfo, bindType)
	local binding = bindingInfo.binding
	if not binding then return end

	if binding == Scope.SOULBOUND then
		return self.S_BOP
	elseif binding == Scope.BOUND then
		if bindType == Enum.ItemBind.ToWoWAccount or bindType == Enum.ItemBind.ToBnetAccount then
			return self.S_BOA
		end
		return self.S_BOP
	elseif binding == Scope.BOE then
		return self.S_BOE
	elseif binding == Scope.ACCOUNT or binding == Scope.BNET then
		return self.S_BOA
	elseif binding == Scope.WUE then
		return self.S_WUE
	end
end

-- One scanner frame for the lifetime of the session. Sharing it is only safe because we
-- read lines via NumLines() and the template's named TextLeft font strings, which are
-- scoped to whatever the current item populated. Reading GetRegions() instead returns
-- every font string the frame has ever created, so a shorter item reused after a longer
-- one picks up the previous item's text. GameTooltipTemplate is required for the named
-- font strings; SharedTooltipTemplate does not create them.
local scanner

-- Tooltip used for scanning.
local _SCANNER = "AVY_ScannerTooltip"

---@return GameTooltip
local function GetScanner()
	if not scanner then
		scanner = CreateFrame("GameTooltip", _SCANNER, nil, "GameTooltipTemplate")
		scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
	end
	return scanner
end

--- Read the binding out of C_TooltipInfo data, without building a tooltip frame.
---@param bagIndex number
---@param slotIndex number
---@return string|nil
local function ScanTooltipData(bagIndex, slotIndex)
	local tooltipInfo = C_TooltipInfo_GetBagItem(bagIndex, slotIndex)
	if not tooltipInfo or not tooltipInfo.lines then return nil end

	-- An item has at most one binding line. Finding it by type is locale independent
	local lines = tooltipInfo.lines
	for i = 1, #lines do
		local line = lines[i]
		if line.type == ITEM_BINDING_LINE then
			return addon:GetBindString(line.leftText)
		end
	end
	return nil
end

--- Read the binding off a hidden tooltip frame, for clients without C_TooltipInfo.
---@param bagIndex number
---@param slotIndex number
---@return string|nil
local function ScanTooltipFrame(bagIndex, slotIndex)
	local tooltip = GetScanner()
	tooltip:ClearLines()
	if bagIndex == BANK_CONTAINER then
		tooltip:SetInventoryItem("player", BankButtonIDToInvSlotID(slotIndex, nil))
	else
		tooltip:SetBagItem(bagIndex, slotIndex)
	end

	-- Zero lines means the item data was not ready
	local numLines = tooltip:NumLines()
	if numLines == 0 then
		tooltip:Hide()
		return nil
	end

	local category = nil
	-- Capped at 30: on Classic, font strings past line 9 can carry incorrect names.
	for i = 1, math_min(numLines, 30) do
		local fontString = _G[_SCANNER .. "TextLeft" .. i]
		local text = fontString and fontString:GetText()
		if text and text ~= "" then
			category = addon:GetBindString(text)
			if category then break end
		end
	end
	tooltip:Hide()
	return category
end

--- Get the category of an item by inspecting its tooltip.
---@param bagIndex number
---@param slotIndex number
---@return string|nil
function addon:GetItemCategory(bagIndex, slotIndex)
	if self.IsRetail then
		return ScanTooltipData(bagIndex, slotIndex)
	end
	return ScanTooltipFrame(bagIndex, slotIndex)
end

---@param category string|nil
---@return boolean
function addon:CategoryEnabled(category)
	if (category == self.S_BOA) then
		return self.db.enableBoa
	elseif (category == self.S_BOE) then
		return self.db.enableBoe
	elseif (category == self.S_WUE) then
		return self.db.enableWue
	elseif (category == self.S_BOP) then
		return self.db.enableBop
	end
	return false
end

-- Order matters. ITEM_ACCOUNTBOUND ("Warbound") and ITEM_BIND_TO_ACCOUNT ("Binds to
-- Warband") are prefixes of their _UNTIL_EQUIP counterparts, so WuE must be tested
-- before BoA or every Warbound-until-equipped item is filed as BoA.
---@param msg string
---@return string|nil
function addon:GetBindString(msg)
	if (msg) then
		if (string_find(msg, ITEM_BIND_ON_EQUIP, 1, true)) then
			return self.S_BOE
		elseif (str_matchm(msg, WUE_STRINGS)) then
			return self.S_WUE
		elseif (str_matchm(msg, BOA_STRINGS)) then
			return self.S_BOA
		elseif (str_matchm(msg, BOP_STRINGS)) then
			return self.S_BOP
		end
	end
end

---@type table<number, BagKind>
local pendingRetries = {}
local retryScheduled = false

---@type table<number, boolean>
local retried = {}

-- Before BetterBags v0.5.2, RemoveItemFromCategory took no category name and deleted the
-- user's saved assignment outright. Skip such items until we require that version.
---@param itemID number
---@return boolean
local function HasSavedAssignment(itemID)
	local saved = Database:GetItemCategoryByItemID(itemID)
	return saved ~= nil and saved.name ~= nil
end

-- BetterBags fills ItemData from GetItemInfo at harvest time and hands it to us frames later,
-- so only the handed fields say whether that lookup had data. A loaded item always has a name.
---@param data ItemData
---@return boolean
local function HarvestedBeforeLoad(data)
	return data.itemInfo.itemName == ""
end

function addon:FlushRetries()
	retryScheduled = false
	local kinds = {}
	local flushed = 0
	for itemID, kind in pairs(pendingRetries) do
		if C_Item.GetItemInfo(itemID) then
			pendingRetries[itemID] = nil
			if not HasSavedAssignment(itemID) then
				-- Unscoped, this drops only the ephemeral assignment and the no-category mark.
				Categories:RemoveItemFromCategory(itemID)
				retried[itemID] = true
				kinds[kind] = true
				flushed = flushed + 1
			end
		end
	end
	debugPrint("retry: cleared %d items", flushed)
	local ctx = self.context:New("Bound_Retry")
	if kinds[Constants.BAG_KIND.BACKPACK] then Events:SendMessage(ctx, "bags/RefreshBackpack") end
	if kinds[Constants.BAG_KIND.BANK] then Events:SendMessage(ctx, "bags/RefreshBank") end
end

--- BetterBags sweeps the bank the moment it opens, without the item-load wait its bag sweeps
--- get, so GetItemInfo can be empty for every bank item on that pass. Any nil we return is
--- cached for the session and keyed by item ID alone, so an item first seen that way stays
--- uncategorised even after it is withdrawn. Come back for it once its data has loaded.
---@param data ItemData
function addon:RetryWhenLoaded(data)
	local itemID = data.itemInfo.itemID
	if retried[itemID] or pendingRetries[itemID] then return end
	pendingRetries[itemID] = data.kind
	Item:CreateFromItemID(itemID):ContinueOnItemLoad(function()
		if retryScheduled then return end
		retryScheduled = true
		-- Never refresh from inside the sweep that asked us.
		C_Timer.After(0, function() addon:FlushRetries() end)
	end)
end

---@param self ns
---@param data ItemData
---@return string|nil
local function Classify(self, data)
	local quality = data.itemInfo.itemQuality
	local bindInfo = data.bindingInfo or {}
	local equippable = not NON_EQUIP_LOCATIONS[data.itemInfo.itemEquipLoc]

	-- Early return for non-equippable if setting enabled
	if (self.db.onlyEquippable and not equippable) then return nil end

	-- Skip non-binding items
	if not bindInfo.binding then return nil end
	if bindInfo.binding == Scope.NONBINDING or bindInfo.binding == Scope.QUEST then return nil end

	-- Skip junk items (gray quality)
	if quality == Enum.ItemQuality.Poor then return nil end

	-- Item qualifies for further categorization
	local category = self:GetBindingInfoCategory(bindInfo, data.itemInfo.bindType)
	if category == nil then category = self:GetItemCategory(data.bagid, data.slotid) end
	if (category ~= nil and self:CategoryEnabled(category)) then
		self.itemCategories[data.itemInfo.itemID] = category
		return L:G(category)
	end

	return nil
end

---@param data ItemData
---@return string|nil
function addon:CategoryFilter(data)
	local category = Classify(self, data)
	if category == nil and HarvestedBeforeLoad(data) then
		self:RetryWhenLoaded(data)
	end
	return category
end

-- ForgetCategory drops our record of every item filed under a category. Call it wherever we
-- ask BetterBags to wipe or delete that same category, so the two stay in step.
---@param category string
function addon:ForgetCategory(category)
	for itemID, filed in pairs(self.itemCategories) do
		if filed == category then
			self.itemCategories[itemID] = nil
		end
	end
end

---@param slot number
function addon:RemoveBindConfirmFromCategory(slot)
	if self.bindConfirm == nil then return end
	if not self.IsRetail then return end

	local id = self.bindConfirm.id
	local itemID = C_Item.GetItemID({ equipmentSlotIndex = slot })
	if (itemID ~= id) then
		debugPrint("slot %d holds %s, not the %s we confirmed", slot, tostring(itemID), tostring(id))
		return
	end

	if HasSavedAssignment(itemID) then
		debugPrint("%d has a saved assignment, leaving it alone", itemID)
		return
	end

	local category = self.itemCategories[itemID]
	if (category ~= self.bindConfirm.category) then
		debugPrint("%d is filed as %s, not the %s we confirmed", itemID, tostring(category),
			tostring(self.bindConfirm.category))
		return
	end

	if (category == self.S_BOE or category == self.S_WUE) then
		-- Scoped from BetterBags v0.5.2; older versions ignore the extra argument. The name has
		-- to be the one we handed them, which is what CategoryFilter returned.
		Categories:RemoveItemFromCategory(itemID, L:G(category))
		self.itemCategories[itemID] = nil
		self.bindConfirm = nil -- Clear the bind confirm
		debugPrint("removed %d from %s", itemID, category)
	end
end

-- Check if the priority addon is available
local BetterBagsPriority = LibStub('AceAddon-3.0'):GetAddon("BetterBags_Priority", true)
local priorityEnabled = BetterBagsPriority ~= nil or false

if (priorityEnabled) then
	---@class PriorityCategories: AceModule
	---@field RegisterCategoryFunction fun(self: PriorityCategories, name: string, filterName: string, fn: fun(data: ItemData): string|nil): nil
	local PriorityCategories = BetterBagsPriority:GetModule('Categories')
	-- this is required because we have multiple categories and can't really register a single function for all of them
	local cat = Categories:GetCategoryByName(L:G("Bound"))
	if not cat then
		Categories:CreateCategory(addon.context:New("Bound_Create_UmbrellaCat"), {
			name = L:G("Bound"),
			itemList = {},
		})
	end

	-- If the priority addon is available, we register the custom category as an empty filter with BetterBags to keep the
	-- "enable system" working. The actual filtering will be done by the priority addon
	Categories:RegisterCategoryFunction("BoEBoAItemsCategoryFilter", function() return nil end)

	-- categoriesWithPriority:RegisterCategoryFunction("YOUR_ADDON_TITLE", "YOUR_FILTER_NAME_HERE", fn)
	PriorityCategories:RegisterCategoryFunction(L:G("Bound"), "BoEBoAItemsCategoryFilter", function(data)
		return addon:CategoryFilter(data)
	end)
else
	-- Use this API to register a function that will be called for every item in the player's bags.
	-- The function you provide will be given an ItemData table, which contains all properties of an item
	-- loaded from the Blizzard API. From here, you can call any custom code you want to analyze the item.
	-- Your function must return a string, which is the category name that the item should be placed in.
	-- If your function returns nil, the item will not be placed in any category.
	-- Results of this function, including nil, are cached, so you do not need to worry about performance
	-- after the first scan.
	-- Your current code goes here to maintain the current behaviour if the priority addon isn't enabled
	Categories:RegisterCategoryFunction("BoEBoAItemsCategoryFilter", function(data)
		return addon:CategoryFilter(data)
	end)
end
