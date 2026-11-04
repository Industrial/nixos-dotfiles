-----------------------------------------------------------------------
-- AddOn namespace.
-----------------------------------------------------------------------
local ADDON_NAME, private = ...

local RSTooltipScanners = private.NewLib("RareScannerTooltipScanners")

-- RareScanner general libraries
local RSUtils = private.ImportLib("RareScannerUtils")

---============================================================================
-- Helpers
---============================================================================

local function GetRareNamesDB()
	if (not private.dbglobal.rare_names) then
		private.dbglobal.rare_names = {}
	end

	local locale = GetLocale()
	if (not private.dbglobal.rare_names[locale]) then
		private.dbglobal.rare_names[locale] = {}
	end

	return private.dbglobal.rare_names[locale]
end

local function GetQuestNamesDB()
	if (not private.dbglobal.quest_names) then
		private.dbglobal.quest_names = {}
	end

	local locale = GetLocale()
	if (not private.dbglobal.quest_names[locale]) then
		private.dbglobal.quest_names[locale] = {}
	end

	return private.dbglobal.quest_names[locale]
end

---============================================================================
-- NPCs tooltip scanner
---============================================================================
	
function RSTooltipScanners.ScanNpcName(npcID, callback)
	local id = tonumber(npcID)
	if (not id) then
		if (callback) then
			callback()
		end
		return
	end

	local rareNamesDB = GetRareNamesDB()
	local tooltipData = C_TooltipInfo.GetHyperlink('unit:Creature-0-0-0-0-' .. id .. '-0')
	if (tooltipData and tooltipData.lines and tooltipData.lines[1]) then
		local name = tooltipData.lines[1].leftText
		if (name and name ~= "" and not issecretvalue(name)) then
			if (rareNamesDB) then
				rareNamesDB[id] = name
			end

			if (callback) then
				callback(name)
			end

			return
		end
	end

	if (not rareNamesDB[id]) then
		C_Timer.After(1, function()
			RSTooltipScanners.ScanNpcName(id, callback)
		end)
	elseif (callback) then
		callback(rareNamesDB[id])
	end
end

function RSTooltipScanners.GetNpcName(npcID, callback)
	local id = tonumber(npcID)
	if (not id) then
		return nil
	end

	-- 1. Check database cache
	local rareNamesDB = GetRareNamesDB()
	if (rareNamesDB[id]) then
		return rareNamesDB[id]
	end

	-- 2. Try tooltip scan
	local tooltipData = C_TooltipInfo.GetHyperlink('unit:Creature-0-0-0-0-' .. id .. '-0')
	if (tooltipData and tooltipData.lines and tooltipData.lines[1]) then
		local name = tooltipData.lines[1].leftText
		if (name and name ~= "" and not issecretvalue(name)) then
			rareNamesDB[id] = name

			if (callback) then
				callback(name)
			end

			return name
		end
	end

	-- 3. If not cached, trigger background scan
	RSTooltipScanners.ScanNpcName(id, callback)

	return nil
end

---============================================================================
-- Quest tooltip scanner
---============================================================================

local questNamesCache = {}

function RSTooltipScanners.GetQuestName(questID, callback)
	local id = tonumber(questID)
	if (not id) then
		return nil
	end

	if (questNamesCache[id]) then
		return questNamesCache[id]
	end

	local questNamesDB = GetQuestNamesDB()
	if (questNamesDB[id]) then
		questNamesCache[id] = questNamesDB[id]
		return questNamesDB[id]
	end

	-- 1. Try C_QuestLog title
	local title = C_QuestLog.GetTitleForQuestID(id)
	if (title and title ~= "") then
		questNamesCache[id] = title
		if (questNamesDB) then
			questNamesDB[id] = title
		end

		if (callback) then
			callback(title)
		end
		return title
	end

	-- 2. Try tooltip scan
	local tooltipData = C_TooltipInfo.GetHyperlink('quest:' .. id)
	if (tooltipData and tooltipData.lines and tooltipData.lines[1]) then
		local qName = tooltipData.lines[1].leftText
		if (qName and qName ~= "" and not issecretvalue(qName)) then
			questNamesCache[id] = qName
			if (questNamesDB) then
				questNamesDB[id] = qName
			end
			if (callback) then
				callback(qName)
			end
			return qName
		end
	end

	-- 3. Request load from server
	C_QuestLog.RequestLoadQuestByID(id)

	if (callback) then
		local retries = 0
		local function RetryQuest()
			retries = retries + 1
			local qTitle = C_QuestLog.GetTitleForQuestID(id)
			if (qTitle and qTitle ~= "") then
				questNamesCache[id] = qTitle
				questNamesDB[id] = qTitle
				callback(qTitle)
			elseif (retries < 3) then
				C_Timer.After(0.5, RetryQuest)
			else
				callback()
			end
		end

		C_Timer.After(0.5, RetryQuest)
	end

	return nil
end

---============================================================================
-- Item tooltip scanner
---============================================================================

local itemNamesCache = {}
local itemQualityCache = {}

function RSTooltipScanners.GetItemQuality(itemID)
	local id = tonumber(itemID)
	if (not id) then
		return nil
	end

	if (itemQualityCache[id]) then
		return itemQualityCache[id]
	end

	-- 1. Try C_Item.GetItemQualityByID (modern WoW API)
	if (C_Item and C_Item.GetItemQualityByID) then
		local q = C_Item.GetItemQualityByID(id)
		if (q) then
			itemQualityCache[id] = q
			return q
		end
	end

	-- 2. Try C_Item.GetItemInfo / GetItemInfo
	local q
	if (C_Item and C_Item.GetItemInfo) then
		q = select(3, C_Item.GetItemInfo(id))
	elseif (GetItemInfo) then
		q = select(3, GetItemInfo(id))
	end
	if (q) then
		itemQualityCache[id] = q
		return q
	end

	return nil
end

function RSTooltipScanners.GetItemName(itemID, callback)
	local id = tonumber(itemID)
	if (not id) then
		return nil
	end

	if (itemNamesCache[id] and itemNamesCache[id] ~= RETRIEVING_ITEM_INFO) then
		return itemNamesCache[id]
	end

	-- 1. Try C_Item API
	local itemName, itemQuality
	if (C_Item and C_Item.GetItemInfo) then
		itemName, _, itemQuality = C_Item.GetItemInfo(id)
	elseif (GetItemInfo) then
		itemName, _, itemQuality = GetItemInfo(id)
	end

	if (not itemName or itemName == "" or itemName == RETRIEVING_ITEM_INFO) then
		if (C_Item and C_Item.GetItemNameByID) then
			itemName = C_Item.GetItemNameByID(id)
		end
	end

	if (not itemQuality and C_Item and C_Item.GetItemQualityByID) then
		itemQuality = C_Item.GetItemQualityByID(id)
	end

	if (itemName and itemName ~= "" and itemName ~= RETRIEVING_ITEM_INFO) then
		itemNamesCache[id] = itemName
		if (itemQuality) then
			itemQualityCache[id] = itemQuality
		end

		if (callback) then
			callback(itemName)
		end

		return itemName
	end

	-- 2. Request load from game libraries
	local item = Item:CreateFromItemID(id)
	item:ContinueOnItemLoad(function()
		local name = item:GetItemName()
		local quality = item:GetItemQuality()
		if (quality) then
			itemQualityCache[id] = quality
		end
		if (name and name ~= "" and name ~= RETRIEVING_ITEM_INFO) then
			itemNamesCache[id] = name

			if (callback) then
				callback(name)
			end
		elseif (callback) then
			callback()
		end
	end)

	return nil
end

---============================================================================
-- Achievement scanner
---============================================================================

function RSTooltipScanners.GetAchievementName(achievementID)
	local id = tonumber(achievementID)
	if (not id) then
		return nil
	end

	local _, name = GetAchievementInfo(id)
	if (name and name ~= "") then
		return name
	end

	return nil
end

---============================================================================
-- Spell scanner
---============================================================================

function RSTooltipScanners.GetSpellName(spellID)
	local id = tonumber(spellID)
	if (not id) then
		return nil
	end

	local name = C_Spell.GetSpellName(id)
	if (not name) then
		name = C_Spell.GetSpellInfo(id)
	end

	if (name and name ~= "") then
		return name
	end

	return nil
end

---============================================================================
-- Map & Area scanner
---============================================================================

local mapNamesCache = {}

local RSMapDB
local function GetMapDB()
	if (not RSMapDB) then
		RSMapDB = private.ImportLib("RareScannerMapDB")
	end
	return RSMapDB
end

function RSTooltipScanners.GetMapName(mapID)
	local id = tonumber(mapID)
	if (not id) then
		return nil
	end

	if (mapNamesCache[id]) then
		return mapNamesCache[id]
	end

	local mapDB = GetMapDB()
	local mapName = mapDB.GetMapName(id)
	if (not mapName) then
		local mapInfo = C_Map.GetMapInfo(id)
		if (mapInfo and mapInfo.name and mapInfo.name ~= "") then
			mapName = mapInfo.name
		end
	end

	-- Fallback to AreaTable if an areaID was passed
	if (not mapName) then
		local areaName = RSTooltipScanners.GetAreaName(id)
		if (areaName and areaName ~= "") then
			mapName = areaName
		end
	end

	if (mapName) then
		mapNamesCache[id] = mapName
		return mapName
	end

	return nil
end

local areaNamesCache = {}

function RSTooltipScanners.GetAreaName(areaID)
	local id = tonumber(areaID)
	if (not id) then
		return nil
	end

	if (areaNamesCache[id]) then
		return areaNamesCache[id]
	end

	local areaName = C_Map.GetAreaInfo(id)
	if (areaName and areaName ~= "") then
		areaNamesCache[id] = areaName
		return areaName
	end

	return nil
end

---============================================================================
-- Loot tooltip scanner
---============================================================================

local function ScanItem(tooltipData, value)
	local foundText = false
	
	if (tooltipData and tooltipData.lines) then
		for i=1, #tooltipData.lines do
			if (tooltipData.lines[i]) then	
				local toolTipText = tooltipData.lines[i].leftText
				if (toolTipText and RSUtils.Contains(toolTipText, value)) then
					foundText = true
					break
				end
			end
		end
	end
	
	return foundText
end

function RSTooltipScanners.ScanLootByItemID(itemID, value)
	return ScanItem(C_TooltipInfo.GetItemByID(itemID), value)
end

function RSTooltipScanners.ScanLoot(itemLink, value)
	return ScanItem(C_TooltipInfo.GetHyperlink(itemLink), value)
end
