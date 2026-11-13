--[[
	Auctioneer
	Version: 2.5.6733 (SwimmingSeadragon)
	Revision: $Id: CoreMain.lua 6733 2022-01-25 11:42:44Z none $
	URL: http://auctioneeraddon.com/

	This is an addon for World of Warcraft that adds statistical history to the auction data that is collected
	when the auction is scanned, so that you can easily determine what price
	you will be able to sell an item for at auction or at a vendor whenever you
	mouse-over an item in the game

	License:
		This program is free software; you can redistribute it and/or
		modify it under the terms of the GNU General Public License
		as published by the Free Software Foundation; either version 2
		of the License, or (at your option) any later version.

		This program is distributed in the hope that it will be useful,
		but WITHOUT ANY WARRANTY; without even the implied warranty of
		MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
		GNU General Public License for more details.

		You should have received a copy of the GNU General Public License
		along with this program(see GPL.txt); if not, write to the Free Software
		Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

	Note:
		This AddOn's source code is specifically designed to work with
		World of Warcraft's interpreted AddOn system.
		You have an implicit license to use this AddOn with these facilities
		since that is its designated purpose as per:
		http://www.fsf.org/licensing/licenses/gpl-faq.html#InterpreterIncompat
]]


--[[
	See CoreAPI.lua for a description of the modules API
]]
local AucAdvanced = AucAdvanced
if not AucAdvanced then return end
AucAdvanced.CoreFileCheckIn("CoreMain")

-- WoW Forever-only build: the modern C_AuctionHouse Auction House is always
-- in use. Kept as a public field so modules and third-party code can query it.
AucAdvanced.IsRetailAH = true

-- Compatibility shim: AuctionFrameTab_OnClick doesn't exist in retail
if not AuctionFrameTab_OnClick then
	AuctionFrameTab_OnClick = function() end
end

-- Compatibility shim: GetItemInfo may not exist in WoW Forever (replaced by C_Item.GetItemInfo)
if not GetItemInfo then
	if C_Item and C_Item.GetItemInfo then
		GetItemInfo = function(item)
			return C_Item.GetItemInfo(item)
		end
	else
		-- Fallback: return nil for all values so code doesn't crash
		GetItemInfo = function()
			return nil
		end
	end
end

-- Compatibility shim: GetItemCount may not exist in WoW Forever (replaced by C_Item.GetItemCount)
if not GetItemCount and C_Item and C_Item.GetItemCount then
	GetItemCount = function(item, ...)
		return C_Item.GetItemCount(item, ...)
	end
end

-- Compatibility shims: globals removed on modern clients, restored through
-- their namespaced equivalents. These are real replacements: the caller gets
-- the value/behaviour it expects, not a nil guard or a no-op stub.
if not GetItemIcon and C_Item then
	GetItemIcon = C_Item.GetItemIconByID
end
if not GetAddOnMetadata and C_AddOns then
	GetAddOnMetadata = C_AddOns.GetAddOnMetadata
end
if not GetContainerNumSlots and C_Container then
	GetContainerNumSlots = C_Container.GetContainerNumSlots
end
if not GetSpellLink and C_Spell then
	GetSpellLink = C_Spell.GetSpellLink
end
if not GetSpellSubtext and C_Spell then
	GetSpellSubtext = C_Spell.GetSpellSubtext
end
if not GetSpellInfo and C_Spell and C_Spell.GetSpellInfo then
	-- C_Spell.GetSpellInfo returns a SpellInfo table; the legacy global
	-- returned name, rank, icon, castTime, minRange, maxRange, spellID.
	-- Accept both shapes so the shim is correct on either API revision.
	GetSpellInfo = function(spell, ...)
		local a, b, c, d, e, f, g = C_Spell.GetSpellInfo(spell, ...)
		if type(a) == "table" then
			local i = a
			return i.name, nil, i.iconID, i.castTime, i.minRange, i.maxRange, i.spellID
		end
		return a, b, c, d, e, f, g
	end
end
if not GetMerchantItemInfo and C_MerchantFrame and C_MerchantFrame.GetItemInfo then
	-- C_MerchantFrame.GetItemInfo returns a MerchantItemInfo table; Auctioneer's
	-- callers expect the legacy tuple name, texture, price, quantity,
	-- numAvailable, isUsable, extendedCost.
	GetMerchantItemInfo = function(index)
		local info = C_MerchantFrame.GetItemInfo(index)
		if not info then return nil end
		return info.name, info.texture, info.price, info.stackCount,
			info.numAvailable, info.isUsable, info.hasExtendedCost
	end
end
if not CanSendAuctionQuery and C_AuctionHouse and C_AuctionHouse.IsThrottledMessageSystemReady then
	CanSendAuctionQuery = function()
		local ready = C_AuctionHouse.IsThrottledMessageSystemReady()
		return ready, ready
	end
end
if not CancelSell and C_AuctionHouse then
	CancelSell = C_AuctionHouse.CancelSell
end

-- Compatibility shim: GetItemQualityColor may not exist in WoW Forever
if not GetItemQualityColor then
	local qualityColors = {
		[0] = {0.62, 0.62, 0.62, "ff9d9d9d"}, -- Poor
		[1] = {1.0, 1.0, 1.0, "ffffffff"},     -- Common
		[2] = {0.12, 1.0, 0.0, "ff1eff00"},    -- Uncommon
		[3] = {0.0, 0.44, 0.87, "ff0070dd"},   -- Rare
		[4] = {0.64, 0.21, 0.93, "ffa335ee"},  -- Epic
		[5] = {1.0, 0.50, 0.0, "ffff8000"},    -- Legendary
		[6] = {0.90, 0.80, 0.50, "ffe6cc80"},  -- Artifact
		[7] = {0.0, 0.8, 1.0, "ff00ccff"},     -- Heirloom
		[8] = {0.0, 0.8, 1.0, "ff00ccff"},     -- WoW Token
	}
	GetItemQualityColor = function(quality)
		local c = qualityColors[quality] or qualityColors[1]
		return c[1], c[2], c[3], c[4]
	end
end

-- Compatibility shim: GetDetailedItemLevelInfo was removed on modern clients.
-- Informant and Enchantrix both call it from tooltip/disenchant paths; a nil
-- return is safe because all call sites guard with "if effLevel then".
if not GetDetailedItemLevelInfo then
	GetDetailedItemLevelInfo = (C_Item and C_Item.GetDetailedItemLevelInfo) or function() return nil end
end

-- Compatibility shim: AuctionFrameMoneyFrame doesn't exist in retail
if not AuctionFrameMoneyFrame then
	AuctionFrameMoneyFrame = CreateFrame("Frame", "AuctionFrameMoneyFrame", UIParent)
	AuctionFrameMoneyFrame:Hide()
	AuctionFrameMoneyFrame.Show = function() end
	AuctionFrameMoneyFrame.Hide = function() end
end

-- Compatibility shim: Classic texture globals don't exist in retail
if not AuctionFrameTopLeft then
	AuctionFrameTopLeft = UIParent:CreateTexture("AuctionFrameTopLeft", "ARTWORK")
	AuctionFrameTopLeft:SetTexture(0)
	AuctionFrameTopLeft:Hide()
	AuctionFrameTop = UIParent:CreateTexture("AuctionFrameTop", "ARTWORK")
	AuctionFrameTop:SetTexture(0)
	AuctionFrameTop:Hide()
	AuctionFrameTopRight = UIParent:CreateTexture("AuctionFrameTopRight", "ARTWORK")
	AuctionFrameTopRight:SetTexture(0)
	AuctionFrameTopRight:Hide()
	AuctionFrameBotLeft = UIParent:CreateTexture("AuctionFrameBotLeft", "ARTWORK")
	AuctionFrameBotLeft:SetTexture(0)
	AuctionFrameBotLeft:Hide()
	AuctionFrameBot = UIParent:CreateTexture("AuctionFrameBot", "ARTWORK")
	AuctionFrameBot:SetTexture(0)
	AuctionFrameBot:Hide()
	AuctionFrameBotRight = UIParent:CreateTexture("AuctionFrameBotRight", "ARTWORK")
	AuctionFrameBotRight:SetTexture(0)
	AuctionFrameBotRight:Hide()
end

-- Compatibility shim: WoW Forever removed GetAuctionItemInfo but kept C_AuctionHouse
if not GetAuctionItemInfo and C_AuctionHouse then
	GetAuctionItemInfo = function(listType, index)
		if listType == "list" then
			return C_AuctionHouse.GetReplicateItemInfo(index)
		elseif listType == "owner" then
			local info = C_AuctionHouse.GetOwnedAuctionInfo(index)
			if info then
				local itemKey = info.itemKey or {}
				return info.itemLink, nil, info.quantity, (info.status == 0 and 1) or 0, true, 0, nil,
					info.bidAmount or 0, 0, info.buyoutAmount or 0, info.bidAmount or 0,
					info.bidder, nil, nil, nil, info.status or 0, itemKey.itemID or 0, true
			end
		end
		return nil
	end
end
if not GetNumAuctionItems and C_AuctionHouse then
	GetNumAuctionItems = function(listType)
		if listType == "list" then
			return C_AuctionHouse.GetNumReplicateItems(), C_AuctionHouse.GetNumReplicateItems()
		elseif listType == "owner" then
			return C_AuctionHouse.GetNumOwnedAuctions(), C_AuctionHouse.GetNumOwnedAuctions()
		end
		return 0, 0
	end
end
if not GetAuctionItemLink and C_AuctionHouse then
	GetAuctionItemLink = function(listType, index)
		if listType == "list" then
			return C_AuctionHouse.GetReplicateItemLink(index)
		elseif listType == "owner" then
			local info = C_AuctionHouse.GetOwnedAuctionInfo(index)
			return info and info.itemLink
		end
		return nil
	end
end

-- Compatibility shim: WoW Forever removed GetAuctionItemTimeLeft (8.3 AH).
-- CoreScan's classic item reader, BeanCounter and CompactUI all call it; on
-- retail an AH tooltip otherwise dies with "attempt to call a nil value" as
-- soon as the player has any owned auctions.
if not GetAuctionItemTimeLeft and C_AuctionHouse then
	GetAuctionItemTimeLeft = function(listType, index)
		if listType == "list" and C_AuctionHouse.GetReplicateItemTimeLeft then
			local band = C_AuctionHouse.GetReplicateItemTimeLeft(index)
			if band then return band end
		elseif listType == "owner" and C_AuctionHouse.GetOwnedAuctionInfo then
			local info = C_AuctionHouse.GetOwnedAuctionInfo(index)
			if info and info.timeLeft then return info.timeLeft end
		end
		return 4 -- unknown / very long (classic fallback)
	end
end

-- Compatibility shim: BrowseSearchButton doesn't exist in retail
-- Many modules call BrowseSearchButton:Show()/Hide()/GetButtonState()
if not BrowseSearchButton then
	BrowseSearchButton = CreateFrame("Frame", "BrowseSearchButton", UIParent)
	BrowseSearchButton:Hide()
	BrowseSearchButton.Show = function() end
	BrowseSearchButton.Hide = function() end
	BrowseSearchButton.GetButtonState = function() return "NORMAL" end
	BrowseSearchButton.SetButtonState = function() end
end

-- Compatibility shim: AuctionFrameBrowse doesn't exist in retail
-- CoreScan.lua sets AuctionFrameBrowse.page and registers/unregisters events
if not AuctionFrameBrowse then
	AuctionFrameBrowse = CreateFrame("Frame", "AuctionFrameBrowse", UIParent)
	AuctionFrameBrowse:Hide()
	AuctionFrameBrowse.page = 0
	AuctionFrameBrowse.selectedCategoryIndex = nil
	AuctionFrameBrowse.selectedSubCategoryIndex = nil
	AuctionFrameBrowse.selectedSubSubCategoryIndex = nil
end

-- Resolves the item currently being sold. Both sell frames derive from
-- AuctionHouseSellFrameMixin, whose :GetItem() returns an ItemLocation (not a
-- data table, which is what the old shims incorrectly assumed).
local function GetRetailSellItemLocation()
	local f = AuctionHouseFrame
	if not f then return nil end
	local loc = f.ItemSellFrame and f.ItemSellFrame:GetItem()
	if loc and loc.IsValid and loc:IsValid() then return loc end
	loc = f.CommoditiesSellFrame and f.CommoditiesSellFrame:GetItem()
	if loc and loc.IsValid and loc:IsValid() then return loc end
	return nil
end

-- Compatibility shim: GetAuctionSellItemInfo may not exist in retail.
-- Rebuild the classic 10-value tuple from the modern sell ItemLocation.
if not GetAuctionSellItemInfo and C_AuctionHouse then
	GetAuctionSellItemInfo = function()
		local loc = GetRetailSellItemLocation()
		if not loc then return nil end
		local link = C_Item.GetItemLink(loc)
		if not link then return nil end
		local name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(link)
		local itemID = C_Item.GetItemID(loc)
		local stack = C_Item.GetStackCount and C_Item.GetStackCount(loc) or 1
		return name, texture, stack, quality, true, 0, 0, stack, stack, itemID
	end
end

-- Compatibility shim: GetAuctionDeposit may not exist in retail.
-- duration arrives as the 1-3 auction duration code (already validated by
-- private.GetRequest), which is exactly what the C_AuctionHouse deposit
-- calculators expect. They need a real ItemLocation / itemID, not zeros.
if not GetAuctionDeposit and C_AuctionHouse then
	GetAuctionDeposit = function(duration, minBid, buyoutPrice, count, stackNumber)
		local c = C_AuctionHouse
		local quantity = (tonumber(count) or 1) * (tonumber(stackNumber) or 1)
		local loc = GetRetailSellItemLocation()
		if not loc then return 0 end
		local status = c.GetItemCommodityStatus and c.GetItemCommodityStatus(loc)
		if Enum and Enum.ItemCommodityStatus and status == Enum.ItemCommodityStatus.Commodity then
			local itemID = C_Item.GetItemID(loc)
			if itemID and c.CalculateCommodityDeposit then
				return c.CalculateCommodityDeposit(itemID, duration, quantity) or 0
			end
		end
		if c.CalculateItemDeposit then
			return c.CalculateItemDeposit(loc, duration, quantity) or 0
		end
		return 0
	end
end

-- Compatibility shim: PlaceAuctionBid may not exist in retail. Replicate
-- results expose no auctionID, so route the request through AucAdvanced.Buy,
-- which runs the item search and calls C_AuctionHouse.PlaceBid with the
-- authoritative auctionID from the search results.
if not PlaceAuctionBid and C_AuctionHouse then
	PlaceAuctionBid = function(listType, index, bid)
		local link = C_AuctionHouse.GetReplicateItemLink(index)
		if not link then return end
		local info = {C_AuctionHouse.GetReplicateItemInfo(index)}
		if AucAdvanced.Buy and AucAdvanced.Buy.QueueBuy then
			AucAdvanced.Buy.QueueBuy(link, info[14] or "", info[3] or 1,
				info[8] or 0, info[10] or 0, bid or info[10] or 0, "PlaceAuctionBid")
		end
	end
end

-- Compatibility shim: PostAuction may not exist in retail. Post the item
-- currently in the modern sell frame through the working retail pipeline,
-- instead of returning a stub failure. CoreScan wraps this global to fire
-- "newauc" processors, so it must actually post.
if not PostAuction and C_AuctionHouse then
	PostAuction = function(minBid, buyoutPrice, runTime, count, stackNumber)
		local loc = GetRetailSellItemLocation()
		local link = loc and C_Item.GetItemLink(loc)
		local sig = link and AucAdvanced.API and AucAdvanced.API.GetSigFromLink(link)
		if not sig then return false, "FailSlot" end
		local ok = AucAdvanced.Post.PostAuctionClick(sig, tonumber(count) or 1,
			minBid, buyoutPrice, runTime, tonumber(stackNumber) or 1)
		if not ok then return false, "FailStart" end
		return true
	end
end

if (not AucAdvancedData) then AucAdvancedData = {} end
if (not AucAdvancedLocal) then AucAdvancedLocal = {} end
if (not AucAdvancedConfig) then AucAdvancedConfig = {} end

local _,_,_, internal = AucAdvanced.GetCoreModule(nil, nil, nil, nil, "CoreMain") -- Request access to all internal storage

if (not AucAdvancedData.Stats) then AucAdvancedData.Stats = {} end
if (not AucAdvancedLocal.Stats) then AucAdvancedLocal.Stats = {} end

local tooltip = AucAdvanced.Libraries.TipHelper
local ALTCHATLINKTOOLTIP_OPEN
local ScheduleMessage -- function("event", delay)

local function OnTooltip(calltype, tip, hyperlink, quantity, name, quality)
	if AucDiag then AucDiag("ontooltip") end
	if InCombatLockdown() and not AucAdvanced.Settings.GetSetting("core.tooltip.enableincombat") then
		if AucDiag then AucDiag("combat") end
		return
	end
	if not tip then return end
	local ModTTShow = AucAdvanced.Settings.GetSetting("ModTTShow")
	local skipTooltip = false
	if ModTTShow then
		if ModTTShow == "never" then skipTooltip = true
		elseif ModTTShow == "noalt" and IsAltKeyDown() then skipTooltip = true
		elseif ModTTShow == "alt" and not IsAltKeyDown() then skipTooltip = true
		elseif ModTTShow == "noshift" and IsShiftKeyDown() then skipTooltip = true
		elseif ModTTShow == "shift" and not IsShiftKeyDown() then skipTooltip = true
		elseif ModTTShow == "noctrl" and IsControlKeyDown() then skipTooltip = true
		elseif ModTTShow == "ctrl" and not IsControlKeyDown() then skipTooltip = true
		end
	else
		AucAdvanced.Settings.SetSetting("ModTTShow", "always")
	end
	if skipTooltip then
		if AucDiag then AucDiag("modtt") end
		return
	end

	local decoded = {}
	local linkType = AucAdvanced.DecodeLink(hyperlink, decoded)
	if linkType ~= calltype then -- bad link or mismatched link type
		-- The classic decoder cannot parse modern retail item links. If this is
		-- still plainly an item link, keep going instead of silently dropping
		-- the whole tooltip.
		if calltype ~= "item" or not hyperlink or not tostring(hyperlink):find("item:", 1, true) then
			if AucDiag then AucDiag("decodelink") AucDiag("lastLinkType", tostring(linkType)) end
			return
		end
		if AucDiag then AucDiag("decodelink_bypassed") end
	end
	if AucDiag then AucDiag("passed") end

	-- Check to see if we need to load scandata
	if AucAdvanced.Settings.GetSetting("scandata.tooltip.display") then
		AucAdvanced.Scan.LoadScanData()
	end

	tooltip:SetFrame(tip)
	tooltip:SetColor(0.3, 0.9, 0.8)
	tooltip:SetMoneyAsText(false)
	tooltip:SetEmbed(false)

	local additional = tooltip:GetExtra()
	quantity = tonumber(quantity) or 1
	local saneLink = AucAdvanced.SanitizeLink(hyperlink)
	local serverKey = AucAdvanced.Resources.ServerKeyDisplay
	local modules = AucAdvanced.GetAllModules()
	local L = AucAdvanced.localizations

	if serverKey ~= AucAdvanced.Resources.ServerKeyHome or AucAdvanced.Settings.GetSetting("core.tooltip.showfactionhome") then
		tooltip:AddLine(format("Using data for |cff1fff00%s|r", AucAdvanced.GetServerKeyText(serverKey) or "Unknown"))
	end

	if AucAdvanced.Settings.GetSetting("tooltip.marketprice.show") then
		local market, seen = AucAdvanced.API.GetMarketValue(saneLink, serverKey)

		if not market then
			tooltip:AddLine(L"ADV_Interface_MarketPrice" ..": ".. L"ADV_Tooltip_NotAvailable")--Market Price // Not Available
		else
			if seen and seen > 0 then
				tooltip:AddLine(L"ADV_Interface_MarketPrice" ..": "..format(L"ADV_Tooltip_SeenBrackets", tostring(seen)), market)--Market Price // (seen %s)
			else
				tooltip:AddLine(L"ADV_Interface_MarketPrice", market) --Market Price
			end
			if ((quantity > 1) and AucAdvanced.Settings.GetSetting("tooltip.marketprice.stacksize")) then
				tooltip:AddLine(L"ADV_Interface_MarketPrice" .." x"..tostring(quantity)..": ", market*quantity) --Market Price
			end
		end

		if IsShiftKeyDown() then
			for pos, engineLib in ipairs(modules) do
				if engineLib.GetItemPDF then
					local price
					if engineLib.GetPriceSeen then
						price = engineLib.GetPriceSeen(saneLink, serverKey)
					end
					if not price and engineLib.GetPriceArray then
						local pricearray = engineLib.GetPriceArray(saneLink, serverKey)
						if pricearray then
							price = pricearray.price
						end
					end
					if price and price > 0 then
						local text = format(L"ADV_Interface_Algorithm_Price", engineLib.GetLocalName()) --%s Price
						if quantity == 1 then
							tooltip:AddLine("  "..text..":", price)
						else
							tooltip:AddLine("  "..text.." x"..tostring(quantity)..": ", price*quantity)
						end
					end
				end
			end
		end
	end

	if AucAdvanced.Settings.GetSetting("core.tooltip.depositcost") then
		local durationsetting = AucAdvanced.Settings.GetSetting("core.tooltip.depositduration")
		local duration = AucAdvanced.Post.GetDurationCode(durationsetting) -- ### currently setting is in hours. todo: change all duration settings to proper duration code
		local faction = AucAdvanced.Resources.DisplayFaction

		local deposit = AucAdvanced.Post.GetDepositCost(saneLink, duration, faction, 1)
		if not deposit then
			tooltip:AddLine(L"ADV_Tooltip_UnknownDepositCost", .2, .4, .6)
		else
			local hours = AucAdvanced.Post.AuctionDurationHours(duration) or 0 -- ### Debug: we need to see if duration setting is invalid
			local text = format(L"ADV_Tooltip_HourDepositCost", hours)
			tooltip:AddLine(text..": ", deposit, .8, 1, .6)
			if quantity > 1 and AucAdvanced.Settings.GetSetting("tooltip.marketprice.stacksize") then
				local stackdeposit = AucAdvanced.Post.GetDepositCost(saneLink, duration, faction, quantity)
				if stackdeposit and stackdeposit ~= deposit then
					tooltip:AddLine(text.." x"..tostring(quantity)..": ", stackdeposit, .8, 1, .6)
				end
			end
		end
	end

	if calltype == "item" then
		--[[
		In future there will be support for issuing multiple Processor messages with different serverKeys
		Modules whose tooltip display depends on a serverKey (i.e. most pricing modules) must use the provided serverKey for each message
			if the module does not support that particular serverKey the message should be ignored
		Modules whose tooltip does not depend on serverKey should check the order parameter to ensure they don't duplicate their output in the tooltip
			usually they would only respond when order == 1
		]]
		local order = 1
		AucAdvanced.SendProcessorMessage("itemtooltip", tooltip, hyperlink, serverKey, quantity, decoded, additional, order)

		-- Old-style "tooltip" message - Deprecated
		local extra = AucAdvanced.Replicate(additional) -- replicate it so we don't change the original table
		for k, v in pairs(decoded) do extra[k] = v end
		local cost
		if extra.event == "SetLootItem" then
			cost = extra.price
		elseif extra.event == "SetAuctionItem" then
			cost = extra.bidAmount
			if cost then cost = cost + extra.minIncrement
			else cost = extra.minBid
			end
		end
		AucAdvanced.SendProcessorMessage("tooltip", tooltip, name, hyperlink, quality, quantity, cost, extra)
	-- elseif calltype == "battlepet" then
		-- local serverKey = AucAdvanced.Resources.ServerKey
		-- local order = 1
		-- AucAdvanced.SendProcessorMessage("battlepettooltip", tooltip, hyperlink, serverKey, quantity, decoded, additional, order)
	end
	tooltip:ClearFrame(tip)
end

-- Wrappers used to pass through the different parameters provided by the caller in the correct order for OnTooltip
local function OnItemTooltip(tooltip, item, quantity, name, hyperlink, quality, ilvl, rlvl, itype, isubtype, stack, equiploc, texture)
	return OnTooltip("item", tooltip, hyperlink, quantity, name, quality)
end
-- local function OnPetTooltip(tooltip, link, quantity, name, speciesID, breedQuality, level)
	-- return OnTooltip("battlepet", tooltip, link, quantity, name, breedQuality)
-- end

local function HookClickBag(hookParams, returnValue, self, button, ignoreShift)
	if button == "RightButton" and IsAltKeyDown() and AucAdvanced.Settings.GetSetting("clickhook.enable") then
		if AucAuctionFrame and AuctionFrameBrowse and AuctionFrameBrowse:IsVisible() then
			if not BrowseName or not AuctionFrameBrowse_Search then return end
			local bag = self:GetParent():GetID()
			local slot = self:GetID()
			local link = C_Container.GetContainerItemLink(bag, slot)
			if link then
				local itemName
				if link:match("item:%d") then
					itemName = GetItemInfo(link)
				else
					itemName = link:match("|Hbattlepet:[^|]+|h%[(.+)%]")
				end
				if itemName then
					if AuctionFrameBrowse_Reset and BrowseResetButton then
						AuctionFrameBrowse_Reset(BrowseResetButton)
					end
					AuctionFrameBrowse.page = 0
					BrowseName:SetText(itemName)
					AuctionFrameBrowse_Search()
				end
			end
		end
	end
end

local function HookClickLink(self, item, link, button)
	if button == "RightButton" and IsAltKeyDown() and AucAdvanced.Settings.GetSetting("clickhook.enable") then
		if AucAuctionFrame and AuctionFrameBrowse and AuctionFrameBrowse:IsVisible() then
			if not BrowseName or not AuctionFrameBrowse_Search then return end
			local itemName
			if link:match("item:%d") then
				itemName = GetItemInfo(link)
			else
				itemName = link:match("|Hbattlepet:[^|]+|h%[(.+)%]")
			end
			if itemName then
				if AuctionFrameBrowse_Reset and BrowseResetButton then
					AuctionFrameBrowse_Reset(BrowseResetButton)
				end
				AuctionFrameBrowse.page = 0
				BrowseName:SetText(itemName)
				AuctionFrameBrowse_Search()
			end
		end
	end
end

local function HookAltChatLinkTooltip(link, text, button, chatFrame)
	if button == "LeftButton"
	and AucAdvanced.Settings.GetSetting("core.tooltip.altchatlink_leftclick")
	and (link:sub(1, 4) == "item" or link:sub(1, 9) == "battlepet") then
		return ALTCHATLINKTOOLTIP_OPEN
	end
end

local HookAHCalled = false
local function HookAH()
	if HookAHCalled then return end
	HookAHCalled = true
	Stubby.UnregisterAddOnHook("Blizzard_AuctionUI", "Auc-Advanced")
	Stubby.UnregisterAddOnHook("Blizzard_AuctionHouseUI", "Auc-Advanced")
end

local function InitAuctionUI()
	-- Forever-only: expose the modern AH frame under a PRIVATE global.
	-- Never assign the real `AuctionFrame` global: Blizzard's secure
	-- ContainerFrameItemButton_OnClick reads it just before the protected
	-- C_Container.UseContainerItem call. An addon-assigned global taints
	-- that execution path and blocks using/learning items from bags.
	-- Several modules (SimpleAuction, BeanCounter) key off AucAuctionFrame.
	if not AucAuctionFrame and AuctionHouseFrame then
		AucAuctionFrame = AuctionHouseFrame
		if AuctionFrameMoneyFrame and AuctionFrameMoneyFrame.SetParent then
			AuctionFrameMoneyFrame:SetParent(AucAuctionFrame)
		end
	end
	if AuctionFrameBrowse_Update then
		hooksecurefunc("AuctionFrameBrowse_Update", AucAdvanced.API.ListUpdate)
	end
	AucAdvanced.SendProcessorMessage("auctionui")
end

local function OnLoad(addon)
	if AucAdvanced.ABORTLOAD then
		-- don't try to run if there were load time errors - some internal functions may be missing
		return
	end
	addon = addon:lower()

	-- Check if the actual addon itself is loading
	if addon == "auc-advanced" then
		--updated saved variables format
		internal.Settings.upgradeSavedVariables()

		-- Load the dummy CoreModule
		internal.CoreModule.CoreModuleOnLoad(addon)
	end

	-- Look for a matching module
	local auc, sys, eng = strsplit("-", addon)
	local moduleLib
	if auc == "auc" and sys and eng then
		moduleLib = AucAdvanced.GetModule(sys, eng)
	end
	if not moduleLib then
		moduleLib = internal.Util.GetModuleForName(addon)
	end

	-- Notify the actual module if it exists
	if moduleLib and moduleLib.OnLoad then
		moduleLib.OnLoad(addon)
	end

	-- Notify all processors that an auctioneer addon has loaded
	if moduleLib or (auc == "auc" and sys and #sys > 0) then -- identify names in both "auc-name" and "auc-system-name" formats
		AucAdvanced.SendProcessorMessage("load", addon)
	end

	-- Check all modules' load triggers and pass event to processors
	local modules = AucAdvanced.GetAllModules("LoadTriggers")
	for pos, engineLib in ipairs(modules) do
		if engineLib.LoadTriggers[addon] then
			if (engineLib.OnLoad) then
				engineLib.OnLoad(addon)
			end
		end
	end

	if moduleLib then
		internal.Util.SendModuleCallbacks(moduleLib)
	end

	if addon == "auc-advanced" then
		for pos, module in ipairs(AucAdvanced.EmbeddedModules) do
			-- These embedded modules have also just been loaded
			OnLoad(module)
		end
	end
end

local function OnUnload()
	local modules = AucAdvanced.GetAllModules("OnUnload")
	for pos, engineLib in ipairs(modules) do
		engineLib.OnUnload()
	end
end

local function OnEnteringWorld(frame)
	frame:UnregisterEvent("PLAYER_ENTERING_WORLD") -- we only want the first instance of this event
	OnEnteringWorld = nil
	if AucAdvanced.ABORTLOAD or not AucAdvanced.CORELOADED then
		-- something's gone wrong - abort loading
		-- in most cases an error should have been reported elsewhere, we don't want to generate a new one
		-- but we should give some indication of the problem, so we shall print a short message to chat instead
		-- since we cannot guarantee Auc's print is working, we shall use default print function
		print("Auctioneer load aborted: "..(AucAdvanced.ABORTLOAD or "Core failed to load"))
		return
	end
	AucAdvanced.Print(format("Auctioneer loaded (version %s)", AucAdvanced.Version))

	frame:RegisterEvent("ITEM_LOCK_CHANGED")
	frame:RegisterEvent("BAG_UPDATE")
	frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	frame:RegisterEvent("AUCTION_HOUSE_SHOW")
	-- Following items are for experimental scan processor modifications
	frame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
	frame:RegisterEvent("OWNED_AUCTIONS_UPDATED")

	Stubby.RegisterAddOnHook("Blizzard_AuctionUI", "Auc-Advanced", HookAH)
	Stubby.RegisterAddOnHook("Blizzard_AuctionHouseUI", "Auc-Advanced", HookAH)
	-- Forever: no Stubby hook on ContainerFrameItemButton_OnModifiedClick.
	-- Stubby replaces globals with a tainted wrapper; on the modern AH that
	-- global is never called by Blizzard, so the classic bag-click shortcuts
	-- are dead code and the hook only risks tainting the secure click path.

	for i = 1, NUM_CHAT_WINDOWS do
		local frame = _G["ChatFrame"..i]
		if frame and frame:GetScript("OnHyperlinkClick") then
			frame:HookScript("OnHyperlinkClick", HookClickLink)
		end
	end

	tooltip:Activate()
	tooltip:AddCallback({type = "item", callback = OnItemTooltip}, 600)
	-- tooltip:AddCallback({type = "battlepet", callback = OnPetTooltip}, 600)
	tooltip:AltChatLinkRegister(HookAltChatLinkTooltip)
	ALTCHATLINKTOOLTIP_OPEN = tooltip:AltChatLinkConstants()

	-- CoreResources must be activated first
	internal.Resources.Activate()

	-- send general activate message
	AucAdvanced.SendProcessorMessage("gameactive")
	internal.Util.ResetSPMArray() -- Modules may add Processors entries during 'gameactive', so must flush SPM cache to ensure they don't get missed.

	if AucAdvanced.Settings.GetSetting("scandata.force") then
		AucAdvanced.Scan.LoadScanData()
	end
end

local InitAuctionUIDone = false
local function OnEvent(self, event, arg1, arg2, ...)
	if event == "AUCTION_HOUSE_SHOW" then
		if not HookAHCalled then
			HookAH()
		end
		if not InitAuctionUIDone then
			InitAuctionUIDone = true
			InitAuctionUI()
		end
	elseif event == "AUCTION_ITEM_LIST_UPDATE" then
		internal.Scan.NotifyItemListUpdated()
	elseif event == "AUCTION_OWNED_LIST_UPDATE" then
		internal.Scan.NotifyOwnedListUpdated()
	elseif (event == "ITEM_LOCK_CHANGED" and arg2) or event == "BAG_UPDATE" then
		if arg1 >= 0 and arg1 <= 4 then
			ScheduleMessage("inventory", 0.15) -- collect multiple events for same bag change using a slight delay
		end
	elseif event == "GET_ITEM_INFO_RECEIVED" then
		ScheduleMessage("iteminfoupdate", 0.15)
	elseif event == "ADDON_LOADED" then
		OnLoad(arg1)
	elseif event == "SAVED_VARIABLES_TOO_LARGE" then
		-- (according to wowpedia) if this occurs it will fire immediately after "ADDON_LOADED"
		if arg1 == "auc-advanced" then
			if not AucAdvanced.ABORTLOAD then
				AucAdvanced.ABORTLOAD = "Auctioneer saved variables too large"
			end
		end
		-- only modules with their own save file need to check for this event
		-- they should check for their own name (lowercased) in arg1
		AucAdvanced.SendProcessorMessage("loadfail", arg1, event)
	elseif event == "PLAYER_LOGOUT" then
		OnUnload()
	elseif event == "PLAYER_ENTERING_WORLD" then
		OnEnteringWorld(self)
	end
end

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("SAVED_VARIABLES_TOO_LARGE")
EventFrame:RegisterEvent("PLAYER_LOGOUT")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:SetScript("OnEvent", OnEvent)

do -- ScheduleMessage handler
	local scheduled = {}
	ScheduleMessage = function(event, delay) -- declared local above
		scheduled[event] = GetTime() + delay
	end
	local function OnUpdate(...)
		if not next(scheduled) then return end
		local now = GetTime()
		for event, trigger in pairs(scheduled) do
			if now >= trigger then
				AucAdvanced.SendProcessorMessage(event, trigger)
				scheduled[event] = nil
			end
		end
	end
	EventFrame:SetScript("OnUpdate", OnUpdate)
end


AucAdvanced.RegisterRevision("$URL: Auc-Advanced/CoreMain.lua $", "$Rev: 6733 $")
AucAdvanced.CoreFileCheckOut("CoreMain")
