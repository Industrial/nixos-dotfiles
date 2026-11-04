-------------------------------------------------------------------
-- AddOn namespace.
-------------------------------------------------------------------
local ADDON_NAME, private = ...

local RSTextTags = private.NewLib("RareScannerTextTags")

-- RareScanner general libraries
local RSUtils = private.ImportLib("RareScannerUtils")
local RSTooltipScanners = private.ImportLib("RareScannerTooltipScanners")

---============================================================================
-- Helpers
---============================================================================

local function TextColor(text, color)
	if (RSUtils and RSUtils.TextColor) then
		return RSUtils.TextColor(text, color)
	end
	return string.format("|cff%s%s|r", color, text)
end

local function ColorizeItem(text, quality)
	if (quality and _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[quality]) then
		local entry = _G.ITEM_QUALITY_COLORS[quality]
		if (entry.color and type(entry.color.WrapTextInColorCode) == "function") then
			return entry.color:WrapTextInColorCode(text)
		elseif (entry.hex) then
			if (string.sub(entry.hex, 1, 2) == "|c") then
				return string.format("%s%s|r", entry.hex, text)
			else
				return TextColor(text, entry.hex)
			end
		end
	end
	return TextColor(text, "FFFFFF")
end

---============================================================================
-- Tag Translation API
---============================================================================

function RSTextTags.GetItemName(itemID, callback)
	return RSTooltipScanners.GetItemName(itemID, callback)
end

function RSTextTags.GetItemQuality(itemID)
	return RSTooltipScanners.GetItemQuality(itemID)
end

function RSTextTags.GetAchievementName(achievementID)
	return RSTooltipScanners.GetAchievementName(achievementID)
end

function RSTextTags.GetNpcName(npcID, callback)
	return RSTooltipScanners.GetNpcName(npcID, callback)
end

function RSTextTags.GetQuestName(questID, callback)
	return RSTooltipScanners.GetQuestName(questID, callback)
end

function RSTextTags.GetSpellName(spellID)
	return RSTooltipScanners.GetSpellName(spellID)
end

function RSTextTags.GetMapName(mapID)
	return RSTooltipScanners.GetMapName(mapID)
end

function RSTextTags.GetAreaName(areaID)
	return RSTooltipScanners.GetAreaName(areaID)
end

---============================================================================
-- Parse text with tags: {item:XX}, {achievement:XX}, {npc:XX}, {quest:XX}, {spell:XX}, {map:XX}, {area:XX}
---============================================================================

function RSTextTags.ParseText(text, callback)
	if (not text or type(text) ~= "string" or text == "") then
		return text
	end

	-- Fast path: if no tags present, return original text immediately
	if (not string.find(text, "{.-}")) then
		return text
	end

	local pendingCallbacks = 0

	local function OnSubLoaded()
		pendingCallbacks = pendingCallbacks - 1
		if (pendingCallbacks <= 0 and callback) then
			callback(RSTextTags.ParseText(text))
		end
	end

	local parsedText = string.gsub(text, "{(%a+)%s*:%s*(%d+)}", function(tagType, idStr)
		local tag = string.lower(tagType)
		local id = tonumber(idStr)
		local replacement = nil

		if (tag == "item") then
			replacement = RSTextTags.GetItemName(id, callback and function(name)
				OnSubLoaded()
			end)
			if (not replacement and callback) then
				pendingCallbacks = pendingCallbacks + 1
			end
			if (replacement and replacement ~= "") then
				local quality = RSTextTags.GetItemQuality(id)
				return ColorizeItem(string.format("[%s]", replacement), quality)
			end
		elseif (tag == "achievement") then
			replacement = RSTextTags.GetAchievementName(id)
			if (replacement and replacement ~= "") then
				return TextColor(string.format("[%s]", replacement), "FFFF00")
			end
		elseif (tag == "quest") then
			replacement = RSTextTags.GetQuestName(id, callback and function(name)
				OnSubLoaded()
			end)
			if (not replacement and callback) then
				pendingCallbacks = pendingCallbacks + 1
			end
			if (replacement and replacement ~= "") then
				return TextColor(string.format("[%s]", replacement), "FFFF00")
			end
		elseif (tag == "spell") then
			replacement = RSTextTags.GetSpellName(id)
			if (replacement and replacement ~= "") then
				return TextColor(string.format("[%s]", replacement), "71D5FF")
			end
		elseif (tag == "npc") then
			replacement = RSTextTags.GetNpcName(id, callback and function(name)
				OnSubLoaded()
			end)
			if (not replacement and callback) then
				pendingCallbacks = pendingCallbacks + 1
			end
			if (replacement and replacement ~= "") then
				return string.format("[%s]", replacement)
			end
		elseif (tag == "map") then
			replacement = RSTextTags.GetMapName(id)
			if (replacement and replacement ~= "") then
				return string.format("[%s]", replacement)
			end
		elseif (tag == "area") then
			replacement = RSTextTags.GetAreaName(id)
			if (replacement and replacement ~= "") then
				return string.format("[%s]", replacement)
			end
		end

		if (replacement and replacement ~= "") then
			return string.format("[%s]", replacement)
		else
			-- If not resolved yet, keep original tag intact
			return string.format("{%s:%s}", tagType, idStr)
		end
	end)

	return parsedText
end
