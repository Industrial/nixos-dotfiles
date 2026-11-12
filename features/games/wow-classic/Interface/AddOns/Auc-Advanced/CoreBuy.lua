--[[
	Auctioneer
	Version: 2.5.6733 (SwimmingSeadragon)
	Revision: $Id: CoreBuy.lua 6733 2022-01-25 11:42:44Z none $
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
--]]

--[[
	Auctioneer Purchasing Engine.

	This code helps modules that need to purchase things to do so in an extremely easy and
	queueable fashion.
]]
if not AucAdvanced then return end
AucAdvanced.CoreFileCheckIn("CoreBuy")
local coremodule, _, private = AucAdvanced.GetCoreModule("CoreBuy", nil, true)
if not coremodule then return end -- Someone has explicitely broken us
local lib = AucAdvanced.Buy
lib.Private = private

local aucPrint,decode,_,_,replicate,_,get,set,default,debugPrint,fill,L = AucAdvanced.GetModuleLocals()
local Const = AucAdvanced.Const
local highlight = "|cffff7f3f"

local ITEMRETRYDELAY = 0.25
local ITEMRETRYMAX = 10 / ITEMRETRYDELAY

local ErrorText = {
	NoPrice = "No price provided",
	PriceInteger = "Price must be a whole number",
	PriceLow = "Price must be at least 1c",
	MoneyLow = "You do not have enough money",
	PriceMinBid = "Price cannot be less than the minimum bid",
	PriceBuyout = "Price cannot be more that the buyout",
	OwnAuction = "You cannot bid on your own auction",
	InvalidLink = "Link is invalid",
	InvalidSeller = "Seller name is invalid",
	InvalidCount = "Count is invalid",
	InvalidMinbid = "Minimum bid is invalid",
	InvalidBuyout = "Buyout is invalid",
	NoItem = "Unable to retrieve info for this item",
	NoPet = "Unable to retrieve info for this pet",
	NoRetailBuyAPI = "AH purchase API unavailable on this client",
}
-- lib.GetErrorText shall be expected to always return a string
function lib.GetErrorText(code)
	if not code then
		return "No error"
	end
	local text = ErrorText[code]
	if text then
		return text
	end
	code = tostring(code)
	debugPrint("Error code without matching ErrorText: "..code, "CorePost", "Unknown Errorcode", "Warning")
	return "Unknown Errorcode ("..code..")"
end

private.BuyRequests = {}
private.PendingBids = {}
--private.Searching = nil
--private.lastPrompt = nil
private.lastQueue = 0
function private.QueueReport()
	local queuelen = #private.BuyRequests
	local prompt = private.CurRequest
	if queuelen ~= private.lastQueue or prompt ~= private.lastPrompt then
		private.lastQueue = queuelen
		private.lastPrompt = prompt
		AucAdvanced.SendProcessorMessage("buyqueue", prompt and queuelen+1 or queuelen) -- quick'n'dirty "queue count"
	end
end
function private.QueueInsert(request, pos)
	if pos and pos <= #private.BuyRequests then
		tinsert(private.BuyRequests, pos, request)
	else
		tinsert(private.BuyRequests, request)
	end
	private.QueueReport()
end
function private.QueueRemove(index)
	if private.BuyRequests[index] then
		local removed = tremove(private.BuyRequests, index)
		private.QueueReport()
		return removed
	end
end
function private.QueueReorder(indexfrom, indexto)
	-- removes the request at position indexfrom and reinserts it at position indexto
	-- when indexto > indexfrom, be aware that the remove operation reindexes the table positions after indexfrom, before the reinsert occurs
	local queuelen = #private.BuyRequests
	if queuelen < 2 then return end
	indexfrom = indexfrom or 1
	if not indexto or indexto > queuelen then
		indexto = queuelen
	end
	if indexfrom == indexto then return end
	local request = tremove(private.BuyRequests, indexfrom)
	if not request then return end
	tinsert(private.BuyRequests, indexto, request)
	private.QueueReport()
	return true
end
function private.QueueFind(key, value, lastindex)
	-- search the queue for a request where the entry [key] matches value, and return the index
	-- lastindex is optional, used to continue a search from after the last item found
	lastindex = lastindex or 0
	for index = lastindex + 1, #private.BuyRequests do
		local request = private.BuyRequests[index]
		if request[key] == value then
			return index
		end
	end
end

--[[
	GetQueueStatus returns:
	number of items in queue
	total cost of items in queue
	string showing link and number of items if Prompt is open, nil otherwise
	cost of item(s) in Prompt, or 0 if closed
--]]
function lib.GetQueueStatus()
	local queuelen = #private.BuyRequests
	local queuecost = 0
	for i, request in ipairs(private.BuyRequests) do
		queuecost = queuecost + request.price
	end
	local prompt = private.Prompt:IsShown() and private.CurRequest.count.."x "..private.CurRequest.link
	local promptcost = prompt and private.CurRequest.price or 0

	return queuelen, queuecost, prompt, promptcost
end

--[[
	Securely clears the Buy Request queue
	if prompt is true, cancels the Buy Prompt (without sending a "bidcancelled" message)
--]]
function lib.CancelBuyQueue(prompt)
	if prompt and private.Prompt:IsShown() then
		private.HidePrompt(true) -- silent
	end
	private.Searching = nil
	wipe(private.BuyRequests)
	private.QueueReport()
end

--[[
	Add an auction to the Buy Queue:
	AucAdvanced.Buy.QueueBuy(link, seller, count, minbid, buyout, price, reason, nosearch)
	This is the main entry point for the lib, and so contains the most parameter checks
	link = (string) 'sanitized' link
	seller = (string, optional) name of seller
	count = (number) stack count
	minbid = (number) original min bid
	buyout = (number) buyout price
	price = (number) price to pay
	reason = (string, optional) reason to display in the buy prompt dialog
	nosearch = (boolean, optional) flag specifying that the auction is on the current page - if not found there, no search will be triggered
	Auctioneer will buy the first auction it sees fitting the specifics at price.
	If item cannot be found on Auctionhouse, will output a warning message to chat
]]
local function QueueBuyErrorHelper(link, reason)
	aucPrint(format("%sAuctioneer: Unable to buy |r%s%s: %s", highlight, link, highlight, ErrorText[reason] or "Unknown")) -- need to highlight before and after the link
	return false, reason
end

--[[ Retail (C_AuctionHouse) purchases
	The replicate list has no auction IDs, so the classic
	PlaceAuctionBid("list", index, price) path can never buy anything. Instead
	we query the one item we want and place the bid with the auctionID from the
	search results. This also avoids StartScan() kicking off a full GetAll scan.
]]
private.RetailBuy = { request = nil, itemID = nil, itemKey = nil }

local function RetailBuyAPIAvailable()
	local c = C_AuctionHouse
	return c and c.SendSearchQuery and c.GetNumItemSearchResults
		and c.GetItemSearchResultInfo and c.PlaceBid
end

local function RetailItemKey(itemID)
	if C_AuctionHouse.MakeItemKey then
		return C_AuctionHouse.MakeItemKey(itemID)
	end
	return { itemID = itemID, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 }
end

function private.StartRetailBuy(request)
	if not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then
		return QueueBuyErrorHelper(request.link, "NoRetailBuyAPI")
	end
	if not RetailBuyAPIAvailable() then
		return QueueBuyErrorHelper(request.link, "NoRetailBuyAPI")
	end
	local itemString = request.link:match("|H([^|]+)|h") or request.link
	local _, id = strsplit(":", itemString)
	local itemID = tonumber(id)
	if not itemID then
		return QueueBuyErrorHelper(request.link, "InvalidLink")
	end
	local itemKey = RetailItemKey(itemID)
	private.RetailBuy.request = request
	private.RetailBuy.itemID = itemID
	private.RetailBuy.itemKey = itemKey
	private.RetailBuy.waited = 0
	private.RetailBuy.poll = 0
	private.updateFrame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
	private.updateFrame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
	local ok, err = pcall(C_AuctionHouse.SendSearchQuery, itemKey, {}, false)
	if not ok then
		private.updateFrame:UnregisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
		private.updateFrame:UnregisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
		private.RetailBuy.request = nil
		aucPrint("Auctioneer: AH item search failed: "..tostring(err))
		return false, "NoRetailBuyAPI"
	end
	-- Also poll for results: some clients do not deliver the named search
	-- events (or deliver different payloads) for throttled queries.
	private.updateFrame:Show()
	return true
end

function private.RetailProcessResults()
	local rb = private.RetailBuy
	if not rb.request then return end
	local c = C_AuctionHouse
	if c.GetNumCommoditySearchResults then
		local ok, n = pcall(c.GetNumCommoditySearchResults, rb.itemID)
		if ok and (n or 0) > 0 then
			private.OnRetailCommodityResults(rb.itemID)
			return
		end
	end
	if c.GetNumItemSearchResults and rb.itemKey then
		local ok, n = pcall(c.GetNumItemSearchResults, rb.itemKey)
		if ok and (n or 0) > 0 then
			private.OnRetailSearchResults(rb.itemKey)
			return
		end
	end
end

function private.OnRetailSearchResults(itemKey)
	local rb = private.RetailBuy
	local req = rb.request
	if not req then return end
	itemKey = itemKey or rb.itemKey
	local n = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
	local match
	for i = 1, n do
		local r = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
		if r and r.auctionID and not r.containsOwnerItem then
			if (r.quantity or 0) == req.count
				and (r.buyoutAmount or 0) == req.buyout then
				match = r
				break
			end
		end
	end
	rb.request = nil
	private.updateFrame:UnregisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
	private.updateFrame:UnregisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
	private.updateFrame:Hide()
	if not match then
		aucPrint("Auctioneer: No matching auction found for "..req.link.." (search results: "..n..")")
		return
	end
	req.auctionID = match.auctionID
	req.index = 0
	req.retailBuyout = match.buyoutAmount or 0
	-- A "bid" must never be submitted at the buyout price: on the modern AH
	-- C_AuctionHouse.PlaceBid(auctionID, buyoutAmount) completes a purchase.
	-- Rebuild the bid amount from the auction's live price state rather than
	-- trusting the (possibly stale or buyout-capped) scan price.
	if req.isbid then
		local buyout = req.retailBuyout
		local minBid = match.minBid or 0
		local bidAmount = req.price
		if minBid > 0 and bidAmount < minBid then
			bidAmount = minBid
		end
		-- WoW Forever stores AH prices in whole gold only; a bid carrying
		-- silver/copper is silently rejected by PlaceBid. Only round up when
		-- the result is still a valid bid strictly below the buyout.
		if C_AuctionHouse.SupportsCopperValues and not C_AuctionHouse.SupportsCopperValues() then
			local GOLD = 10000
			local rounded = math.ceil(bidAmount / GOLD) * GOLD
			if (buyout <= 0 or rounded < buyout) and rounded >= minBid then
				bidAmount = rounded
			end
		end
		if buyout > 0 and bidAmount >= buyout then
			aucPrint("Auctioneer: Cannot bid on "..req.link..": the minimum bid has reached the buyout price. Use Buyout instead.")
			return
		end
		req.price = bidAmount
	end
	local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(req.link)
	req.texture = texture
	private.PromptPurchase(req)
end

function private.OnRetailCommodityResults(itemID)
	local rb = private.RetailBuy
	local req = rb.request
	if not (req and itemID == rb.itemID) then return end
	rb.request = nil
	private.updateFrame:UnregisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
	private.updateFrame:UnregisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
	private.updateFrame:Hide()
	-- Commodities are unit-price buyouts only on the modern AH. A "Bid"
	-- request must never be silently turned into a purchase.
	if req.isbid then
		aucPrint("Auctioneer: "..req.link.." is a commodity and cannot be bid on. Use Buyout instead.")
		return
	end
	local c = C_AuctionHouse
	if not (c.StartCommoditiesPurchase and c.ConfirmCommoditiesPurchase) then
		aucPrint("Auctioneer: Commodity purchase API unavailable on this client: "..req.link)
		return
	end
	-- Commodities are bought by itemID + quantity at the current lowest
	-- price, not by auctionID. Show the normal prompt and confirm there.
	req.commodityItemID = itemID
	req.commodityQuantity = req.count
	req.commodityMaxPrice = req.price
	req.index = 0
	local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(req.link)
	req.texture = texture
	private.PromptPurchase(req)
end

-- Idempotent completion of a retail commodity purchase. Called from
-- COMMODITY_PURCHASE_SUCCEEDED and from a short timer fallback.
function private.RetailConfirmCommodity()
	local c = private.RetailBuy.commodity
	if not c or c.confirmed then return end
	c.confirmed = true
	private.RetailBuy.commodity = nil
	private.updateFrame:UnregisterEvent("COMMODITY_PURCHASE_SUCCEEDED")
	private.updateFrame:UnregisterEvent("COMMODITY_PURCHASE_FAILED")
	if C_AuctionHouse.ConfirmCommoditiesPurchase then
		C_AuctionHouse.ConfirmCommoditiesPurchase(c.itemID, c.quantity)
	end
end

function lib.QueueBuy(link, seller, count, minbid, buyout, price, reason, nosearch)
	if type(link) ~= "string" then return QueueBuyErrorHelper("\""..tostring(link).."\"", "InvalidLink") end
	if seller ~= nil and type(seller) ~= "string" then return QueueBuyErrorHelper(link, "InvalidSeller") end
	count = tonumber(count)
	if not count or count < 1 then return QueueBuyErrorHelper(link, "InvalidCount") end
	minbid = tonumber(minbid)
	if not minbid or minbid < 0 then return QueueBuyErrorHelper(link, "InvalidMinbid") end -- it is sometimes possible for auctions to report minbid == 0
	buyout = tonumber(buyout)
	if not buyout or buyout < 0 then return QueueBuyErrorHelper(link, "InvalidBuyout") end
	price = tonumber(price)
	local canbuy, problem = lib.CanBuy(price, seller, minbid, buyout)
	if not canbuy then return QueueBuyErrorHelper(link, problem) end
	link = AucAdvanced.SanitizeLink(link)
	if reason then reason = tostring(reason) else reason = "" end
	local isbid = buyout == 0 or price < buyout

	if get("ShowPurchaseDebug") then
		if isbid then
			aucPrint("Auctioneer: Queueing Bid of "..link.." from seller "..tostring(seller).." for "..AucAdvanced.Coins(price))
		else
			aucPrint("Auctioneer: Queueing Buyout of "..link.." from seller "..tostring(seller).." for "..AucAdvanced.Coins(price))
		end
	end

	local request = {
		link = link,
		sellername = seller or "",
		count = count,
		minbid = minbid,
		buyout = buyout,
		price = price,
		reason = reason,
		isbid = isbid,
	}

	-- Forever: C_AuctionHouse item-search purchase path. The classic
	-- query/StartScan pipeline does not exist on this client.
	return private.StartRetailBuy(request)
end

-- Another helper for QueueBuy
-- returns 1 : full success
-- returns false, reason : complete failure (and prints message to chat)
-- returns -1 : retry: waiting for next retry
-- returns -2 : retry: retry just failed, but not yet at max count
function private.SetRequestSearchParams(request)
	-- calculate and store values needed for searching
	local link = request.link
	-- Modern (12.x) links start with a |cnIQ<n>: colour prefix containing a
	-- colon; parse the |H...|h itemString instead of the raw link.
	local itemString = link:match("|H([^|]+)|h") or link
	local lType, itemID, _, petQuality = strsplit(":", itemString)
	itemID = tonumber(itemID)
	if not itemID or itemID == 0 then
		return QueueBuyErrorHelper(link, "InvalidLink")
	end
	lType = lType:sub(-4)
	if lType == "item" then
		local retrytime = request.retrytime
		if retrytime and GetTime() < retrytime then -- too soon to retry, we don't want to spam GetItemInfo too much
			return -1
		end
		local name, _, quality, _, minlevel, _, _, _, _, _, _, classID, subClassID = GetItemInfo(link)
		if not name or name == "" then
			-- may be due to GetItemInfo not always returning info immediately (after WoW 7.0)
			if retrytime then
				local retrycount = (request.retrycount or 0) + 1
				if retrycount > ITEMRETRYMAX then -- tried too many times, give up
					return QueueBuyErrorHelper(link, "NoItem")
				else
					request.retrycount = retrycount
					request.retrytime = GetTime() + ITEMRETRYDELAY -- waiting period bewteen retries
					return -2
				end
			else
				-- if the link looks valid, set up to retry next time
				local checkItemID = tonumber(strmatch(link, "item:(%d+):"))
				if not checkItemID or checkItemID == 0 then
					return QueueBuyErrorHelper(link, "NoItem")
				end
				if get("ShowPurchaseDebug") then
					aucPrint("Auctioneer: Unable to find item info for "..link.." at this time, will try again")
				end
				request.retrytime = GetTime() + ITEMRETRYDELAY -- waiting period bewteen retries
				return -1
			end
		end
		request.itemname = name:lower()
		-- only store uselevel and quality if greater than 0
		if minlevel and minlevel > 0 then request.uselevel = minlevel end
		if quality and quality > 0 then request.quality = quality end
		request.filterData = AucAdvanced.Scan.QueryFilterFromID(classID, subClassID)
		if #request.itemname < 60 then request.exact = true end -- use exact match, except for very long names
	elseif lType == "epet" then -- last 4 characters of "battlepet"
		local quality = tonumber(petQuality)
		local petName, _, petType = C_PetJournal.GetPetInfoBySpeciesID(itemID) -- speciesID = itemID
		if not petType or not petName or petName == "" then
			-- indicates it's not a recognized Pet species
			return QueueBuyErrorHelper(link, "NoPet")
		end
		-- all caged pets should have the default pet name (custom names are removed when caging)
		request.itemname = petName:lower()
		--request.uselevel always nil. only store quality if greater than 0
		if quality and quality > 0 then request.quality = quality end
		request.filterData = AucAdvanced.Scan.QueryFilterFromID(LE_ITEM_CLASS_BATTLEPET, Const.AC_PetType2SubClassID[petType])
		if #request.itemname < 60 then request.exact = true end -- use exact match, except for very long names
	else
		return QueueBuyErrorHelper(link, "InvalidLink")
	end
	return 1 -- signal success
end

--[[
	This function will return false, reason if an auction by seller at price cannot be bought
	Else it will return true.
	Note that this will not catch all, but if it says you can't, you can't
	Parameter 'price' is required, all others are optional
]]
function lib.CanBuy(price, seller, minbid, buyout)
	if type(price) ~= "number" then
		return false, "NoPrice"
	elseif floor(price) ~= price then
		return false, "PriceInteger"
	elseif price < 1 then
		return false, "PriceLow"
	elseif GetMoney() < price then
		return false, "MoneyLow"
	elseif minbid and price < minbid then
		return false, "PriceMinBid"
	elseif buyout and buyout > 0 and price > buyout then
		return false, "PriceBuyout"
	elseif seller and AucAdvancedConfig["users."..Const.PlayerRealm.."."..seller] then
		return false, "OwnAuction"
	end
	return true
end

function private.PushSearch()
	if AucAdvanced.Scan.IsPaused() then return end
	local request = private.BuyRequests[1]
	if not request.itemname then -- itemname should have been stored for every request that reaches this point
		if request.nosearch then -- this request should have been removed earlier, extra check just in case
			private.QueueRemove(1)
			return
		end
		-- GetItemInfo sometimes fails after WoW7.0, but will work after a brief wait. Pass through SetRequestSearchParams again
		local result = private.SetRequestSearchParams(request)
		if not result then
			-- a chat message should already have been issued
			private.QueueRemove(1)
			return
		elseif result < 0 then -- needs to be retried
			if result == -2 then
				private.QueueReorder() -- push first request to back of the queue
			end
			return
		end
		if not request.itemname then -- ### extra check, just in case
			geterrorhandler()("CoreBuy: PushSearch unexpectedly found request with no itemname") -- ### debug
			private.QueueRemove(1)
			return
		end
	end
	if GetMoney() < request.price then -- check that player still has enough money
		aucPrint("Auctioneer: Can't buy "..request.link.." : ".."not enough money")
		private.QueueRemove(1)
		return
	end

	local isScanning, isGetAll = AucAdvanced.Scan.IsScanning()
	if (isScanning and isGetAll) then return end -- we must wait on getall, and PushScan failure is too noisy for something fired every frame

	AucAdvanced.Scan.PushScan()
	if AucAdvanced.Scan.IsScanning() then return end -- check that PushScan succeeded

	-- calculate and store the query sig for each buy request currently in the queue
	-- acts as a flag to show that the request existed before the current scan started
	-- (when the scan finishes, only requests with .querysig entries may be deleted)
	for _, req in ipairs(private.BuyRequests) do
		if req.itemname and not req.querysig then
			-- Usage CreateQuerySig(name, minLevel, maxLevel, isUsable, qualityIndex, exactMatch, filterData)
			req.querysig = AucAdvanced.Scan.CreateQuerySig(req.itemname, req.uselevel, req.uselevel, nil, req.quality, req.exact, req.filterData)
		end
	end

	private.Searching = request.querysig
	-- Usage StartScan(name, minUseLevel, maxUseLevel, isUsable, qualityIndex, GetAll, exactMatch, filterData, options)
	AucAdvanced.Scan.StartScan(request.itemname, request.uselevel, request.uselevel, nil, request.quality, nil, request.exact, request.filterData)
end

function private.FinishedSearch(complete, querysig, query)
	if not complete or query.isUsable or not query.name then return end
	for index = #private.BuyRequests, 1, -1 do
		local request = private.BuyRequests[index]
		-- Compare the query sig to the sig(s) calculated during PushSearch
		if request.querysig == querysig then
			-- The auction for this buy request no longer exists on the Auctionhouse
			if request.foundHigh then
				-- we did find a possible matching auction, but we were already the high bidder on it
				aucPrint("Auctioneer: Already the high bidder for auction of "..request.link)
			elseif request.foundInvalid then
				-- we found a possible matching auction, but our bid price was too low
				-- probably means someone else bid on the auction first
				aucPrint("Auctioneer: Bid price too low for auction of "..request.link)
			else
				aucPrint("Auctioneer: Auction for "..request.link.." no longer exists")
			end
			private.QueueRemove(index)
		end
	end
	private.Searching = nil
end

function private.PromptPurchase(thisAuction)
	AucAdvanced.Scan.SetPaused(true)
	private.CurRequest = thisAuction
	private.Prompt:Show()
	if thisAuction.isbid then
		private.Prompt.Text:SetText("Are you sure you want to bid on")
	else
		private.Prompt.Text:SetText("Are you sure you want to buyout")
	end
	if thisAuction.count == 1 then
		private.Prompt.Value:SetText(thisAuction.link.." for "..AucAdvanced.Coins(thisAuction.price,true).."?")
	else
		private.Prompt.Value:SetText(thisAuction.count.."x "..thisAuction.link.." for "..AucAdvanced.Coins(thisAuction.price,true).."?")
	end
	private.Prompt.Item.tex:SetTexture(thisAuction.texture)
	private.Prompt.Reason:SetText(thisAuction.reason)
	local width = private.Prompt.Value:GetStringWidth() or 0
	private.Prompt.Frame:SetWidth(max((width + 70), 400))
	private.QueueReport()
end

function private.HidePrompt(silent)
	private.Prompt:Hide()
	private.CurRequest = nil
	if not silent then
		private.QueueReport()
	end
	AucAdvanced.Scan.SetPaused(false)
end

function lib.ScanPage(startat)
	if #private.BuyRequests == 0 then return end
	if private.CurRequest then return end
	if AucAuctionFrame and AucAuctionFrame:IsShown() then
		local batch = GetNumAuctionItems("list")
		if startat and startat < batch then
			batch = startat
		end
		for ind = batch, 1, -1 do
			local link = GetAuctionItemLink("list", ind)
			link = AucAdvanced.SanitizeLink(link)
			for pos = #private.BuyRequests, 1, -1 do
				local BuyRequest = private.BuyRequests[pos]
				if link == BuyRequest.link then
					local price = BuyRequest.price
					local brSeller = BuyRequest.sellername
					local name, texture, count, _, _, _, _, minBid, minIncrement, buyout, curBid, ishigh, _, owner = GetAuctionItemInfo("list", ind)
					if (not owner or brSeller == "" or owner == brSeller)
					and (count == BuyRequest.count)
					and (minBid == BuyRequest.minbid)
					and (buyout == BuyRequest.buyout) then --found the auction we were looking for
						if ishigh and (not buyout or buyout <= 0 or price < buyout) then
							BuyRequest.foundHigh = true
						elseif price >= curBid + minIncrement or price == buyout then
							BuyRequest.index = ind
							BuyRequest.texture = texture
							private.QueueRemove(pos)
							private.PromptPurchase(BuyRequest)
							return
						else
							BuyRequest.foundInvalid = true
						end
					end
				end
			end
		end
	end
	-- check for nosearch flags
	for pos = #private.BuyRequests, 1, -1 do
		local BuyRequest = private.BuyRequests[pos]
		if BuyRequest.nosearch then
			if startat then
				-- we need to be *certain* the whole page has been scanned before deciding this item is not there.
				-- recurse with no restriction. should only be needed rarely.
				return lib.ScanPage()
			end
			if BuyRequest.foundHigh then
				aucPrint("Auctioneer: Unable to bid on "..BuyRequest.link..". Already the high bidder.")
			elseif BuyRequest.foundInvalid then
				aucPrint("Auctioneer: Unable to bid on "..BuyRequest.link..". Bid price is too low.")
			else
				aucPrint("Auctioneer: Unable to bid on "..BuyRequest.link..". Auction was not found on the current page.")
			end
			private.QueueRemove(pos)
		end
	end
end

--Cancels the current auction
--Also sends out a Callback with a callback string of "<link>;<price>;<count>"
function private.CancelPurchase()
	local CallBackString = strjoin(";", tostringall(private.CurRequest.link, private.CurRequest.price, private.CurRequest.count))
	AucAdvanced.SendProcessorMessage("bidcancelled", CallBackString)
	private.HidePrompt()
	if private.Searching and not private.QueueFind("querysig", private.Searching) then
		private.Searching = nil
	end
	-- Forever: the C_AuctionHouse item-search path has no browsable page to rescan.
end

function private.PerformPurchase()
	if not private.CurRequest then return end
	--first, do some Sanity Checking
	local index = private.CurRequest.index
	local price = private.CurRequest.price
	if type(price)~="number" then
		aucPrint(highlight.."Cancelling bid: invalid price: "..type(price)..":"..tostring(price))
		private.HidePrompt()
		return
	elseif type(index) ~= "number" then
		aucPrint(highlight.."Cancelling bid: invalid index: "..type(index)..":"..tostring(index))
		private.HidePrompt()
		return
	end
	-- Retail: place the bid with the auctionID from the item search results.
	-- PlaceBid requires a hardware event, which this is (prompt Buy button).
	if private.CurRequest.auctionID and C_AuctionHouse and C_AuctionHouse.PlaceBid then
		local req = private.CurRequest
		-- Final safety net at the hardware-event call site: never let a bid
		-- reach the buyout, which the modern AH treats as an instant purchase.
		if req.isbid and (req.retailBuyout or 0) > 0 and price >= req.retailBuyout then
			aucPrint("Auctioneer: Refusing to bid on "..req.link.." at or above its buyout price; use Buyout instead.")
			private.HidePrompt()
			return
		end
		req.reason = private.Prompt.Reason:GetText() or ""
		tinsert(private.PendingBids, req)
		if #private.PendingBids == 1 then
			private.updateFrame:RegisterEvent("UI_ERROR_MESSAGE")
		end
		C_AuctionHouse.PlaceBid(req.auctionID, price)
		if #private.PendingBids == 1 then
			private.updateFrame:RegisterEvent("CHAT_MSG_SYSTEM")
		end
		private.HidePrompt()
		return
	end
	-- Retail commodity: start the two-step purchase. StartCommoditiesPurchase
	-- needs a hardware event (this is the prompt's Buy button click);
	-- COMMODITY_PURCHASE_SUCCEEDED then calls ConfirmCommoditiesPurchase.
	if private.CurRequest.commodityItemID and C_AuctionHouse.StartCommoditiesPurchase then
		local req = private.CurRequest
		req.reason = private.Prompt.Reason:GetText() or ""
		private.RetailBuy.commodity = {
			itemID = req.commodityItemID,
			quantity = req.commodityQuantity,
			maxPrice = req.commodityMaxPrice,
			confirmed = false,
		}
		private.updateFrame:RegisterEvent("COMMODITY_PURCHASE_SUCCEEDED")
		private.updateFrame:RegisterEvent("COMMODITY_PURCHASE_FAILED")
		if get("ShowPurchaseDebug") then
			aucPrint("Auctioneer: Starting commodity purchase "..tostring(req.commodityItemID).." x"..tostring(req.commodityQuantity))
		end
		C_AuctionHouse.StartCommoditiesPurchase(req.commodityItemID, req.commodityQuantity)
		-- Some clients never fire COMMODITY_PURCHASE_SUCCEEDED. Confirm after a
		-- short delay as a fallback; RetailConfirmCommodity is idempotent.
		if C_Timer and C_Timer.After then
			C_Timer.After(0.75, private.RetailConfirmCommodity)
		end
		private.HidePrompt()
		return
	end
	local link = GetAuctionItemLink("list", index)
	link = AucAdvanced.SanitizeLink(link)
	local name, texture, count, _, _, _, _, minBid, minIncrement, buyout, curBid = GetAuctionItemInfo("list", index)

	if (private.CurRequest.link ~= link) then
		aucPrint(highlight.."Cancelling bid: "..index.." link does not match")
		private.HidePrompt()
		return
	elseif (price < minBid) then
		aucPrint(highlight.."Cancelling bid: Bid below minimum bid: "..AucAdvanced.Coins(price))
		private.HidePrompt()
		return
	elseif (curBid and curBid > 0 and price < curBid + minIncrement and price < buyout) then -- ### todo: check and fix logic, looks worng here...
		aucPrint(highlight.."Cancelling bid: Already higher bidder")
		private.HidePrompt()
		return
	end
	if get("ShowPurchaseDebug") then
		if buyout > 0 and price >= buyout then
			aucPrint("Auctioneer: Buying out "..link.." for "..AucAdvanced.Coins(price))
		else
			aucPrint("Auctioneer: Bidding on "..link.." for "..AucAdvanced.Coins(price))
		end
	end

	private.CurRequest.reason = private.Prompt.Reason:GetText() or ""
	--Add bid to list of bids we're watching for
	tinsert(private.PendingBids, private.CurRequest)
	--register for the Response events if this is the first pending bid
	local doRegister = #private.PendingBids == 1
	if doRegister then
		-- UI_ERROR_MESSAGE must be registered before first call to PlaceAuctionBid, to trap any errors during that call
		private.updateFrame:RegisterEvent("UI_ERROR_MESSAGE")
	end
	PlaceAuctionBid("list", index, price)
	if doRegister then
		-- CHAT_MSG_SYSTEM must be registered after first call to PlaceAuctionBid,
		-- otherwise BeanCounter will get out of sync and fail to record the reason
		private.updateFrame:RegisterEvent("CHAT_MSG_SYSTEM")
	end

	--get ready for next bid action
	private.HidePrompt()
	if private.Searching and not private.QueueFind("querysig", private.Searching) then
		private.Searching = nil
	end
	lib.ScanPage(index-1)--check the page for any more auctions
end

function private.removePendingBid()
	if (#private.PendingBids > 0) then
		tremove(private.PendingBids, 1)

		--Unregister events if no more bids pending
		if (#private.PendingBids == 0) then
			private.updateFrame:UnregisterEvent("CHAT_MSG_SYSTEM")
			private.updateFrame:UnregisterEvent("UI_ERROR_MESSAGE")
		end
	end
end

function private.onBidAccepted()
	--CallBackString has format "itemlink;seller;count;buyout;price;reason"
	local bid = private.PendingBids[1]
	local CallBackString = strjoin(";", tostringall(bid.link, bid.sellername, bid.count, bid.buyout, bid.price, bid.reason))
	AucAdvanced.SendProcessorMessage("bidplaced", CallBackString)
	private.removePendingBid()
end

--private.onBidFailed(message)
--This function is called when a bid fails
--purpose is to output to chat the reason for the failure, and then pass the Bid on to private.removePendingBid()
--The output may duplicate some client output.  If so, those lines need to be removed.
function private.onBidFailed(message)
	aucPrint(highlight.."Bid Failed: "..message)
	private.removePendingBid()
end

--[[ Timer, Event Handler and Message Processor ]]--

function private.ActivateEvents()
	-- Called when a new auction is queued, or when the Auctionhouse is opened
	if not private.isActivated and #private.BuyRequests > 0 and AucAuctionFrame and AucAuctionFrame:IsShown() then
		private.isActivated = true
		private.updateFrame:Show() -- start timer
	end
end

function private.DeactivateEvents()
	-- Called when there are no items left in the buy requests list, or when the Auctionhouse is closed
	private.Searching = nil
	if private.isActivated then
		private.isActivated = nil
		private.updateFrame:Hide() -- stop timer
	end
end

local function OnUpdate(self, elapsed)
	-- Retail: poll for the search results instead of relying solely on the
	-- named events (which may not fire for throttled queries on this client).
	if private.RetailBuy.request then
		local rb = private.RetailBuy
		rb.waited = (rb.waited or 0) + elapsed
		rb.poll = (rb.poll or 0) + elapsed
		if rb.poll >= 0.25 then
			rb.poll = 0
			private.RetailProcessResults()
		end
		if private.RetailBuy.request and rb.waited > 15 then
			private.RetailBuy.request = nil
			private.updateFrame:UnregisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
			private.updateFrame:UnregisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
			private.updateFrame:Hide()
			local ready = C_AuctionHouse.IsThrottledMessageSystemReady and C_AuctionHouse.IsThrottledMessageSystemReady()
			aucPrint("Auctioneer: AH item search timed out for item "..tostring(rb.itemID).." (throttleReady="..tostring(ready)..")")
		end
		return
	end
	if not (private.Searching or private.CurRequest) then
		if #private.BuyRequests > 0 then
			private.PushSearch()
		else
			private.DeactivateEvents()
		end
	end
end

local function OnEvent(frame, event, message, message2)
	if event == "AUCTION_ITEM_LIST_UPDATE" then
		local request = private.CurRequest
		if request then
			-- We are currently prompting the user to bid on an auction
			-- The Auction Page is supposed to be paused/frozen, but we've just received an AUCTION_ITEM_LIST_UPDATE event
			-- This could be a minor change (e.g. owner name update) or an actual page change
			-- Check if we are still pointing at the right auction
			local index = request.index
			local link = GetAuctionItemLink("list", index)
			link = AucAdvanced.SanitizeLink(link)
			if link == request.link then
				local _, _, count, _, _, _, _, minBid, minIncrement, buyout, curBid, ishigh, _, owner = GetAuctionItemInfo("list", index)
				if count == request.count and minBid == request.minbid and buyout == request.buyout then
					local price = request.price
					local sellername = request.sellername
					if (not owner or sellername == "" or owner == sellername)
					and (price == buyout or (not ishigh and price >= curBid + minIncrement))
					then
						-- Everything matches up as before; no further action
						return
					end
				end
			end
			-- The auction we wanted to bid on is no longer in the same place (page change)
			-- Or something else has changed (outbid?)
			private.HidePrompt(true) -- silent
			private.QueueInsert(request, 1)
		end

		lib.ScanPage()
	elseif event == "ITEM_SEARCH_RESULTS_UPDATED" or event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
		-- Ignore the payload; RetailProcessResults checks both result sets
		-- directly so a differing event payload cannot strand the request.
		private.RetailProcessResults()
	elseif event == "COMMODITY_PRICE_UPDATED" then
		-- Kept for diagnostics only. Cancelling here could abort a valid
		-- purchase when the quoted total is expressed differently from the
		-- scanned buyout, so we no longer register this event.
		if get("ShowPurchaseDebug") then
			aucPrint("Auctioneer: COMMODITY_PRICE_UPDATED "..tostring(message).." / "..tostring(message2))
		end
	elseif event == "COMMODITY_PURCHASE_SUCCEEDED" then
		if get("ShowPurchaseDebug") then
			aucPrint("Auctioneer: COMMODITY_PURCHASE_SUCCEEDED")
		end
		private.RetailConfirmCommodity()
	elseif event == "COMMODITY_PURCHASE_FAILED" then
		local c = private.RetailBuy.commodity
		if c then c.confirmed = true end
		private.RetailBuy.commodity = nil
		private.updateFrame:UnregisterEvent("COMMODITY_PURCHASE_SUCCEEDED")
		private.updateFrame:UnregisterEvent("COMMODITY_PURCHASE_FAILED")
		aucPrint("Auctioneer: Commodity purchase failed (price or quantity changed).")
	elseif event == "CHAT_MSG_SYSTEM" then
		if message == ERR_AUCTION_BID_PLACED then
		 	private.onBidAccepted()
		end
	elseif event == "UI_ERROR_MESSAGE" then
		if (message2 == ERR_ITEM_NOT_FOUND or
			message2 == ERR_NOT_ENOUGH_MONEY or
			message2 == ERR_AUCTION_BID_OWN or
			message2 == ERR_AUCTION_HIGHER_BID or
			message2 == ERR_AUCTION_BID_INCREMENT or
			message2 == ERR_AUCTION_MIN_BID or
			message2 == ERR_ITEM_MAX_COUNT) then
			private.onBidFailed(message2)
		end
	end
end

private.updateFrame = CreateFrame("Frame")
private.updateFrame:SetScript("OnUpdate", OnUpdate)
private.updateFrame:SetScript("OnEvent", OnEvent)
private.updateFrame:Hide()

coremodule.Processors = {
	scanfinish = function(event, scansize, querysig, queryinfo, complete, query, scanstats)
		private.FinishedSearch(complete, querysig, query)
	end,

	auctionopen = function()
		private.ActivateEvents()
	end,

	auctionclose = function()
		local request = private.CurRequest
		if request then -- prompt is open: cancel prompt and requeue auction
			private.HidePrompt(true) -- silent
			private.QueueInsert(request, 1)
		end
		private.DeactivateEvents()
	end,
}

--[[ Prompt Frame ]]--

--this is a anchor frame that never changes size
private.Prompt = CreateFrame("frame", "AucAdvancedBuyPrompt", UIParent)
private.Prompt:Hide()
private.Prompt:SetPoint("TOPRIGHT", "UIParent", "TOPRIGHT", -400, -100)
private.Prompt:SetFrameStrata("DIALOG")
private.Prompt:SetHeight(120)
private.Prompt:SetWidth(400)
private.Prompt:SetMovable(true)
private.Prompt:SetClampedToScreen(true)

--The "graphic" frame and backdrop that we resize. Only thing anchored to it is the item Box
private.Prompt.Frame = CreateFrame("frame", nil, private.Prompt, BackdropTemplateMixin and "BackdropTemplate")
private.Prompt.Frame:SetPoint("CENTER",private.Prompt, "CENTER" )
private.Prompt.Frame:SetFrameLevel(private.Prompt:GetFrameLevel() - 1) -- lower level than parent (backdrop)
private.Prompt.Frame:SetHeight(120)
private.Prompt.Frame:SetWidth(400)
private.Prompt.Frame:SetClampedToScreen(true)
private.Prompt.Frame:SetBackdrop({
	bgFile = "Interface/Tooltips/UI-Tooltip-Background",
	edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
	tile = true, tileSize = 32, edgeSize = 32,
	insets = { left = 9, right = 9, top = 9, bottom = 9 }
})
private.Prompt.Frame:SetBackdropColor(0,0,0,0.8)

-- Helper functions
local function ShowTooltip()
	local link = private.CurRequest.link
	if not link then return end
	if strmatch(link, "|Hitem:") then
		GameTooltip:SetOwner(AuctionFrameCloseButton, "ANCHOR_NONE")
		GameTooltip:SetHyperlink(link)
		GameTooltip:ClearAllPoints()
		GameTooltip:SetPoint("TOPRIGHT", private.Prompt.Item, "TOPLEFT", -10, -20)
	elseif strmatch(link, "|Hbattlepet:") then
		local _, speciesID, level, breedQuality, maxHealth, power, speed, battlePetID = strsplit(":", link)
		BattlePetToolTip_Show(tonumber(speciesID), tonumber(level), tonumber(breedQuality), tonumber(maxHealth), tonumber(power), tonumber(speed), string.gsub(string.gsub(link, "^(.*)%[", ""), "%](.*)$", ""))
		-- somewhat hacky - BattlePetToolTip_Show anchors to GameTooltip's anchor point, but we want to specify our own anchor
		BattlePetTooltip:ClearAllPoints()
		BattlePetTooltip:SetPoint("TOPRIGHT", private.Prompt.Item, "TOPLEFT", -10, -20)
	end
end
local function HideTooltip()
	GameTooltip:Hide()
	if BattlePetTooltip then
		BattlePetTooltip:Hide()
	end
end
local function ClearReasonFocus()
	private.Prompt.Reason:ClearFocus()
end
local function DragStart()
	private.Prompt:StartMoving()
end
local function DragStop()
	private.Prompt:StopMovingOrSizing()
end

private.Prompt.Item = CreateFrame("Button", "AucAdvancedBuyPromptItem", private.Prompt)
private.Prompt.Item:SetNormalTexture("Interface\\Buttons\\UI-Slot-Background")
private.Prompt.Item:GetNormalTexture():SetTexCoord(0,0.640625, 0, 0.640625)
private.Prompt.Item:SetPoint("TOPLEFT", private.Prompt.Frame, "TOPLEFT", 15, -15)
private.Prompt.Item:SetHeight(37)
private.Prompt.Item:SetWidth(37)
private.Prompt.Item:SetScript("OnEnter", ShowTooltip)
private.Prompt.Item:SetScript("OnLeave", HideTooltip)
private.Prompt.Item.tex = private.Prompt.Item:CreateTexture(nil, "OVERLAY")
private.Prompt.Item.tex:SetPoint("TOPLEFT", private.Prompt.Item, "TOPLEFT", 0, 0)
private.Prompt.Item.tex:SetPoint("BOTTOMRIGHT", private.Prompt.Item, "BOTTOMRIGHT", 0, 0)

private.Prompt.Text = private.Prompt:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
private.Prompt.Text:SetPoint("TOPLEFT", private.Prompt, "TOPLEFT", 52, -20)
private.Prompt.Text:SetPoint("TOPRIGHT", private.Prompt, "TOPRIGHT", -15, -20)
private.Prompt.Text:SetJustifyH("CENTER")

private.Prompt.Value = private.Prompt:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
private.Prompt.Value:SetPoint("CENTER", private.Prompt.Frame, "CENTER", 20, 15)

private.Prompt.Reason = CreateFrame("EditBox", "AucAdvancedBuyPromptReason", private.Prompt, "InputBoxTemplate")
private.Prompt.Reason:SetPoint("TOPLEFT", private.Prompt, "TOPLEFT", 150, -55)
private.Prompt.Reason:SetPoint("TOPRIGHT", private.Prompt, "TOPRIGHT", -30, -55)
private.Prompt.Reason:SetHeight(20)
private.Prompt.Reason:SetAutoFocus(false)
private.Prompt.Reason:SetScript("OnEnterPressed", ClearReasonFocus)
private.Prompt.Reason:SetText("")

private.Prompt.Reason.Label = private.Prompt.Reason:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
private.Prompt.Reason.Label:SetPoint("TOPRIGHT", private.Prompt.Reason, "TOPLEFT", 0, 0)
private.Prompt.Reason.Label:SetPoint("TOPLEFT", private.Prompt, "TOPLEFT", 52, -55)
private.Prompt.Reason.Label:SetText("Reason:")
private.Prompt.Reason.Label:SetHeight(15)

private.Prompt.Yes = CreateFrame("Button", "AucAdvancedBuyPromptYes", private.Prompt, "UIPanelButtonTemplate")
private.Prompt.Yes:SetText("Yes")
private.Prompt.Yes:SetSize(90, 24)
private.Prompt.Yes:SetPoint("BOTTOMRIGHT", private.Prompt, "BOTTOMRIGHT", -10, 10)
private.Prompt.Yes:SetScript("OnClick", private.PerformPurchase)

private.Prompt.No = CreateFrame("Button", "AucAdvancedBuyPromptNo", private.Prompt, "UIPanelButtonTemplate")
private.Prompt.No:SetText("Cancel")
private.Prompt.No:SetSize(90, 24)
private.Prompt.No:SetPoint("BOTTOMRIGHT", private.Prompt.Yes, "BOTTOMLEFT", -10, 0)
private.Prompt.No:SetScript("OnClick", private.CancelPurchase)

private.Prompt.DragTop = CreateFrame("Button", nil, private.Prompt)
private.Prompt.DragTop:SetPoint("TOPLEFT", private.Prompt, "TOPLEFT", 10, -5)
private.Prompt.DragTop:SetPoint("TOPRIGHT", private.Prompt, "TOPRIGHT", -10, -5)
private.Prompt.DragTop:SetHeight(6)
private.Prompt.DragTop:SetHighlightTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar")
private.Prompt.DragTop:SetScript("OnMouseDown", DragStart)
private.Prompt.DragTop:SetScript("OnMouseUp", DragStop)

private.Prompt.DragBottom = CreateFrame("Button", nil, private.Prompt)
private.Prompt.DragBottom:SetPoint("BOTTOMLEFT", private.Prompt, "BOTTOMLEFT", 10, 5)
private.Prompt.DragBottom:SetPoint("BOTTOMRIGHT", private.Prompt, "BOTTOMRIGHT", -10, 5)
private.Prompt.DragBottom:SetHeight(6)
private.Prompt.DragBottom:SetHighlightTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar")
private.Prompt.DragBottom:SetScript("OnMouseDown", DragStart)
private.Prompt.DragBottom:SetScript("OnMouseUp", DragStop)

AucAdvanced.RegisterRevision("$URL: Auc-Advanced/CoreBuy.lua $", "$Rev: 6733 $")
AucAdvanced.CoreFileCheckOut("CoreBuy")
