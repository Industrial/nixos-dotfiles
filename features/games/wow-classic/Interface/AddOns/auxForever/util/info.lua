select(2, ...) 'aux.util.info'

local aux = require 'aux'

CreateFrame('GameTooltip', 'AuxTooltip', nil, 'GameTooltipTemplate')

-- Forever: posting durations are indices 1-3 into the auction house's duration options.
-- Their lengths are read from the client's own labels (AUCTION_DURATION_ONE..THREE), e.g. "12 Hours".
do
    local fallback = { [1] = 12, [2] = 24, [3] = 48 }
    local labels = { 'AUCTION_DURATION_ONE', 'AUCTION_DURATION_TWO', 'AUCTION_DURATION_THREE' }
    function M.duration_hours(duration_code)
        local label = _G[labels[duration_code] or '']
        local hours = label and tonumber(strmatch(label, '(%d+)'))
        return hours or fallback[duration_code]
    end
end

-- Forever: the auction house reports time left either as a band (Enum.AuctionHouseTimeLeftBand, 0-3)
-- or in seconds. aux keeps the Classic convention of duration codes 1-4 (short .. very long).
function M.duration_from_band(band)
    return band and band + 1
end

-- Short label for a duration code, e.g. '30m', '2h', '12h', '48h' (upper end of the time left band)
function M.time_left_label(duration_code)
    local fallback = { '30m', '2h', '12h', '48h' }
    local ok, _, max_seconds = pcall(C_AuctionHouse.GetTimeLeftBandInfo, duration_code - 1)
    if ok and max_seconds and max_seconds > 0 then
        if max_seconds < 3600 then
            return floor(max_seconds / 60) .. 'm'
        end
        return floor(max_seconds / 3600) .. 'h'
    end
    return fallback[duration_code]
end

function M.duration_from_seconds(seconds)
    if not seconds then return end
    for band = 0, 3 do
        local _, max_seconds = C_AuctionHouse.GetTimeLeftBandInfo(band)
        if max_seconds and seconds <= max_seconds then
            return band + 1
        end
    end
    return 4
end

function M.container_item(bag, slot)
	local link = C_Container.GetContainerItemLink(bag, slot)
    if link then
        local item_id, suffix_id, unique_id, enchant_id = parse_link(link)
        local item_info = item(item_id, suffix_id, unique_id, enchant_id)
        if item_info then -- TODO apparently this can be undefined
            local containerInfo = C_Container.GetContainerItemInfo(bag, slot) -- TODO quality not working?
            local durability, max_durability = C_Container.GetContainerItemDurability(bag, slot)
            local tooltip = tooltip('bag', bag, slot)
            local max_charges = max_item_charges(item_id)
            local charges = max_charges and item_charges(tooltip)
            local auctionable = auctionable(tooltip) and durability == max_durability and charges == max_charges and not containerInfo.hasLoot
            local item_location = ItemLocation:CreateFromBagAndSlot(bag, slot)
            if auction_house_open() and item_location:IsValid() then
                auctionable = C_AuctionHouse.IsSellItemValid(item_location, false)
            end
            if max_charges and not charges then -- TODO find better fix
                return
            end
            return {
                item_id = item_id,
                suffix_id = suffix_id,
                unique_id = unique_id,
                enchant_id = enchant_id,

                link = link,
                item_key = item_id .. ':' .. suffix_id,
                price_key = link_price_key(link),

                name = item_info.name,
                texture = containerInfo.iconFileID,
                level = item_info.level,
                quality = item_info.quality,
                max_stack = item_info.max_stack,

                count = containerInfo.stackCount,
                locked = containerInfo.isLocked,
                readable = containerInfo.isReadable,
                auctionable = auctionable,

                tooltip = tooltip,
                item_location = item_location,
            }
        end
    end
end

do
    local open = false
    function aux.event.AUX_LOADED()
        aux.event_listener('AUCTION_HOUSE_SHOW', function() open = true end)
        aux.event_listener('AUCTION_HOUSE_CLOSED', function() open = false end)
    end
    function M.auction_house_open()
        return open
    end
end

-- Forever: auction records are built from C_AuctionHouse results instead of GetAuctionItemInfo.
-- They keep the field names of Classic aux so the listings, filters and history work unchanged.
-- See docs/forever-auction-house.md for how the modern auction house reports listings.
-- New fields:
--   auction_id     used to bid/buy directly
--   auction_count  how many identical auctions the record stands for (an item search row is a
--                  bucket of identical auctions, each priced per item)
--   commodity      bought by quantity, cheapest units first
--   item_search_key  the item key the record was searched with (to re-read its bucket)

local record_mt = {
    __index = function(record, key)
        -- the tooltip is only built when a filter actually needs it, which keeps scans fast
        -- 0.8.2 build 6 (FB-025): a fast row of gear with an ending (an item key with a suffix
        -- number) is built from its item key, so the ending's stats are in it: the item's own link
        -- has none of them
        if key == 'tooltip' and record.fast and record.browse_key and (record.browse_key.itemSuffix or 0) ~= 0 then
            local tooltip = tooltip('item_key', record.browse_key, record.requirement)
            rawset(record, 'tooltip', tooltip)
            return tooltip
        elseif key == 'tooltip' and record.link then
            local tooltip = tooltip('link', record.link)
            rawset(record, 'tooltip', tooltip)
            return tooltip
        end
    end,
}

local function player_guid()
    return UnitGUID'player'
end

function M.signatures(record)
    local own = aux.account_data.ignore_owner and (is_player(record.owner) and 0 or 1) or (record.owner or '?')
    -- 0.8 (review H-002, finding 3): the price key, not the suffix field (empty on Forever), so two
    -- endings at the same price never merge into one row
    local version = record.price_key or record.suffix_id
    record.search_signature = aux.join({record.item_id, version, record.enchant_id, record.start_price, record.buyout_price, record.bid_price, record.count, record.sale_status == 1 and 0 or (record.duration or 0), record.high_bidder and 1 or 0, record.sale_status or 0, own}, ':')
    record.sniping_signature = aux.join({record.item_id, version, record.enchant_id, record.start_price, record.buyout_price, record.count, own, record.auction_id or 0}, ':')
end

-- auxForever (0.7): equip slots whose item level means nothing to a player (bags, quivers)
local NO_ITEM_LEVEL = {[''] = true, INVTYPE_NON_EQUIP = true, INVTYPE_NON_EQUIP_IGNORE = true, INVTYPE_BAG = true, INVTYPE_QUIVER = true}

-- Returns name, texture, quality, requirement, usable, link and item level for an item, or nil if
-- the client has not cached it yet. The item level is nil for anything that is not gear (0.7,
-- FB-013: Forever's tooltips do not show it, so the iLvl column is the only place to see it).
function M.item_basics(item_id, link)
    local name, item_link, quality, item_level, requirement, _, _, _, slot, texture = GetItemInfo(link or item_id)
    if name then
        local usable = true
        if C_PlayerInfo and C_PlayerInfo.CanUseItem then
            usable = C_PlayerInfo.CanUseItem(item_id)
        end
        if NO_ITEM_LEVEL[slot or ''] or (item_level or 0) <= 0 then
            item_level = nil
        end
        return name, texture, quality, requirement or 0, usable, item_link, item_level
    end
end

-- the item level of a gear record: the auction house's own item key when it gives one, else the item's
local function key_item_level(key, item_level)
    if item_level and type(key) == 'table' and (key.itemLevel or 0) > 0 then
        return key.itemLevel
    end
    return item_level
end

function M.request_item(item_id)
    if C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(item_id)
    end
end

local function new_record(item_id, link, count)
    local record = setmetatable({}, record_mt)
    local _, suffix_id, unique_id, enchant_id = parse_link(link or '')
    local name, texture, quality, requirement, usable, item_link, item_level = item_basics(item_id, link)
    if not name then return end
    learn_item(item_id)
    link = link or item_link
    record.item_id = item_id
    record.suffix_id = suffix_id
    record.unique_id = unique_id
    record.enchant_id = enchant_id
    record.link = link
    record.item_key = item_id .. ':' .. suffix_id
    -- 0.8 (review H-002, finding 4): the link's own name, ending included, as fast rows have it
    record.name = strmatch(link or '', '|h%[(.-)%]|h') or name
    record.price_key = price_key(item_id, record.name)
    record.texture = texture
    record.quality = quality
    record.requirement = requirement
    record.item_level = item_level
    record.usable = usable
    record.count = count
    return record
end

local function set_prices(record, min_bid, bid_amount, buyout)
    local count = max(record.count, 1)
    min_bid, bid_amount, buyout = min_bid or 0, bid_amount or 0, buyout or 0
    record.high_bid = bid_amount
    record.bid_price = min_bid > 0 and min_bid or buyout
    record.start_price = bid_amount > 0 and bid_amount or record.bid_price
    record.min_increment = bid_amount > 0 and max(0, record.bid_price - bid_amount) or 0
    record.blizzard_bid = bid_amount > 0 and bid_amount or record.bid_price
    record.buyout_price = buyout
    record.unit_blizzard_bid = record.blizzard_bid / count
    record.unit_bid_price = record.bid_price / count
    record.unit_buyout_price = buyout / count
end

-- The player's own entry in an owners list is the string "player"
local function seller(result, own)
    if own then
        return UnitName'player'
    elseif #result.owners == 1 and result.owners[1] ~= 'player' then
        return result.owners[1]
    end
end

-- Same rule as Blizzard's AuctionHouseUtil.IsOwnedAuction: every auction in the row is the player's
local function owned_row(result)
    return (#result.owners == 1 and (result.containsOwnerItem or result.containsAccountItem))
        or (#result.owners == 2 and result.containsOwnerItem and result.containsAccountItem)
        or false
end

-- One row of an item search (C_AuctionHouse.GetItemSearchResultInfo). The row is a bucket of
-- result.quantity identical auctions; its prices are for one item and PlaceBid buys one auction.
function M.item_search_record(result)
    local record = new_record(result.itemKey.itemID, result.itemLink, 1)
    if not record then return end
    record.auction_id = result.auctionID
    record.auction_count = max(1, result.quantity or 1)
    record.item_search_key = result.itemKey
    record.item_level = key_item_level(result.itemKey, record.item_level)
    record.raw_min_bid, record.raw_bid, record.raw_buyout = result.minBid or 0, result.bidAmount or 0, result.buyoutAmount or 0
    set_prices(record, result.minBid, result.bidAmount, result.buyoutAmount)
    record.high_bidder = result.bidder and result.bidder == player_guid() or nil
    record.own = owned_row(result)
    record.contains_own = result.containsOwnerItem or nil
    record.owner = seller(result, record.own)
    record.seller_count = result.totalNumberOfOwners or #result.owners
    record.duration = result.timeLeftSeconds and duration_from_seconds(result.timeLeftSeconds) or duration_from_band(result.timeLeft)
    record.sale_status = 0
    signatures(record)
    return record
end

-- One price tier of a commodity (C_AuctionHouse.GetCommoditySearchResultInfo).
-- Commodities have no bids; buying a quantity always takes the cheapest listings and skips the
-- player's own, so the record's count is what the player can actually buy at this price.
function M.commodity_record(result)
    local available = result.quantity - (result.numOwnerItems or 0)
    local own = available <= 0
    local count = own and result.quantity or available
    local record = new_record(result.itemID, nil, count)
    if not record then return end
    record.commodity = true
    record.auction_id = result.auctionID
    record.commodity_unit_price = result.unitPrice
    set_prices(record, 0, 0, result.unitPrice * count)
    record.own = own
    record.own_count = result.numOwnerItems
    record.owner = seller(result, own)
    record.seller_count = result.totalNumberOfOwners or #result.owners
    record.duration = duration_from_seconds(result.timeLeftSeconds)
    record.sale_status = 0
    signatures(record)
    return record
end

-- auxForever: one item of a browse list (fast mode): only the lowest price and how many are for
-- sale are known, not the single auctions. The row stands for the whole item: count 1 at the lowest
-- price, auction_count the units for sale. Opening it reads the real auctions (tabs/search).
-- Returns nil if the client has not loaded the item yet.
function M.browse_record(result)
    local key = result.itemKey
    local item_id = key.itemID
    local name, texture, quality, requirement, usable, item_link, item_level = item_basics(item_id)
    if not name then return end
    learn_item(item_id)
    local key_info = C_AuctionHouse.GetItemKeyInfo(key)
    local record = setmetatable({}, record_mt)
    record.fast = true
    record.browse_key = key
    record.item_id = item_id
    record.suffix_id = key.itemSuffix or 0
    record.unique_id = 0
    record.enchant_id = 0
    record.link = item_link
    record.item_key = item_id .. ':' .. record.suffix_id
    record.name = type(key_info) == 'table' and key_info.itemName or name
    record.price_key = price_key(item_id, record.name)
    record.texture = type(key_info) == 'table' and key_info.iconFileID or texture
    record.quality = type(key_info) == 'table' and key_info.quality or quality
    record.is_commodity = type(key_info) == 'table' and key_info.isCommodity or nil
    local key_requirement = C_AuctionHouse.GetItemKeyRequiredLevel and C_AuctionHouse.GetItemKeyRequiredLevel(key)
    record.requirement = type(key_requirement) == 'number' and key_requirement > 0 and key_requirement or requirement
    record.item_level = key_item_level(key, item_level)
    record.usable = usable
    record.count = 1
    record.auction_count = max(1, result.totalQuantity or 1)
    set_prices(record, 0, 0, result.minPrice or 0)
    record.contains_own = result.containsOwnerItem or nil
    record.sale_status = 0
    signatures(record)
    return record
end

-- After part of a commodity tier was bought
function M.set_commodity_count(record, count)
    record.count = count
    set_prices(record, 0, 0, record.commodity_unit_price * count)
    signatures(record)
end

-- One listing from a full scan (C_AuctionHouse.GetReplicateItemInfo, 0-based index)
function M.replicate_record(index)
    local name, texture, count, quality, usable, level, _, min_bid, min_increment, buyout_price, bid_amount, high_bidder, _, owner, _, sale_status, item_id, has_all_info = C_AuctionHouse.GetReplicateItemInfo(index)
    if not has_all_info or not item_id then
        return nil, item_id
    end
    local link = C_AuctionHouse.GetReplicateItemLink(index)
    local record = new_record(item_id, link, count)
    if not record then
        return nil, item_id
    end
    set_prices(record, bid_amount > 0 and bid_amount + min_increment or min_bid, bid_amount, buyout_price)
    record.min_increment = min_increment
    record.high_bidder = (high_bidder == true or high_bidder == UnitName'player') or nil
    record.owner = owner
    record.duration = duration_from_band(C_AuctionHouse.GetReplicateItemTimeLeft(index))
    record.sale_status = sale_status
    signatures(record)
    return record
end

-- One of the player's own auctions (C_AuctionHouse.GetOwnedAuctionInfo)
function M.owned_record(owned)
    local item_id = owned.itemKey.itemID
    local record = new_record(item_id, owned.itemLink, owned.quantity)
    if not record then
        request_item(item_id)
        return
    end
    record.auction_id = owned.auctionID
    record.item_search_key = owned.itemKey
    -- like every other modern auction house price, these are per unit
    local quantity = max(1, owned.quantity or 1)
    local buyout = owned.buyoutAmount and owned.buyoutAmount * quantity or 0
    local bid = owned.bidAmount and owned.bidAmount * quantity or 0
    set_prices(record, 0, bid, buyout)
    record.start_price = bid > 0 and bid or buyout
    record.high_bidder = owned.bidder
    record.owner = UnitName'player'
    record.sale_status = owned.status == Enum.AuctionStatus.Sold and 1 or 0
    record.duration = owned.timeLeftSeconds and duration_from_seconds(owned.timeLeftSeconds) or duration_from_band(owned.timeLeft)
    signatures(record)
    -- 0.7.1 (FB-015): identical auctions of your own stay apart, each with its own row and cancel
    record.search_signature = record.search_signature .. ':' .. (owned.auctionID or 0)
    return record
end

-- One auction the player has bid on (C_AuctionHouse.GetBidInfo)
function M.bid_record(bid)
    local item_id = bid.itemKey.itemID
    local record = new_record(item_id, bid.itemLink, 1)
    if not record then
        request_item(item_id)
        return
    end
    record.auction_id = bid.auctionID
    set_prices(record, bid.minBid, bid.bidAmount, bid.buyoutAmount)
    record.high_bidder = bid.bidder and bid.bidder == player_guid() or nil
    record.duration = duration_from_band(bid.timeLeft)
    record.sale_status = 0
    signatures(record)
    return record
end

function M.bid_update(auction_record)
    auction_record.high_bid = auction_record.bid_price
    auction_record.blizzard_bid = auction_record.bid_price
    auction_record.min_increment = max(1, floor(auction_record.bid_price / 100) * 5)
    auction_record.bid_price = auction_record.bid_price + auction_record.min_increment
    auction_record.unit_blizzard_bid = auction_record.blizzard_bid / auction_record.count
    auction_record.unit_bid_price = auction_record.bid_price / auction_record.count
    auction_record.high_bidder = 1
    signatures(auction_record)
end

function M.set_tooltip(itemstring, owner, anchor)
    GameTooltip:SetOwner(owner, anchor)
    GameTooltip:SetHyperlink(itemstring)
end

function M.tooltip_match(entry, tooltip)
    return aux.any(tooltip, function(text)
        return strupper(entry) == strupper(text)
    end)
end

function M.tooltip_find(pattern, tooltip)
    local count = 0
    for _, entry in pairs(tooltip) do
        if strfind(entry, pattern) then
            count = count + 1
        end
    end
    return count
end

function M.display_name(item_id, no_brackets, no_color)
	local item_info = item(item_id)
    if item_info then
        local name = item_info.name
        if not no_brackets then
            name = '[' .. name .. ']'
        end
        if not no_color then
            name = '|c' .. select(4, GetItemQualityColor(item_info.quality)) .. name .. FONT_COLOR_CODE_CLOSE
        end
        return name
    end
end

function M.auctionable(tooltip, quality)
    local status = tooltip[2]
    return (not quality or quality < 6)
            and status ~= ITEM_BIND_ON_PICKUP
            and status ~= ITEM_BIND_QUEST
            and status ~= ITEM_SOULBOUND
            and (not tooltip_match(ITEM_CONJURED, tooltip) or tooltip_find(ITEM_MIN_LEVEL, tooltip) > 1)
end

function M.tooltip(setter, arg1, arg2)
    AuxTooltip:SetOwner(UIParent, 'ANCHOR_NONE')
    AuxTooltip:ClearLines()
    if setter == 'bag' then
	    AuxTooltip:SetBagItem(arg1, arg2)
    elseif setter == 'inventory' then
	    AuxTooltip:SetInventoryItem(arg1, arg2)
    elseif setter == 'link' then
	    AuxTooltip:SetHyperlink(arg1)
    elseif setter == 'item_key' then
        -- 0.8.2 build 6: an auction house item key (arg2: required level), as Blizzard's item list
        -- shows a row with no link of its own, its ending's stats included (Code: Blizzard's
        -- Blizzard_AuctionHouseSharedTemplates.lua, branch forever; aux's own row hover since 0.3)
        if AuxTooltip.SetItemKey then
            AuxTooltip:SetItemKey(arg1.itemID, arg1.itemLevel or 0, arg1.itemSuffix or 0, arg2 or 0)
        end
    end
    local tooltip = {}
    for i = 1, AuxTooltip:NumLines() do
        for side in aux.iter('Left', 'Right') do
            local text = _G['AuxTooltipText' .. side .. i]:GetText()
            if text then
                tinsert(tooltip, text)
            end
        end
    end
    return tooltip
end

do
    local patterns = {}
    for i = 1, 10 do
        patterns[aux.pluralize(format(ITEM_SPELL_CHARGES, i))] = i
    end

	function item_charges(tooltip)
        for _, entry in pairs(tooltip) do
            if patterns[entry] then
                return patterns[entry]
            end
	    end
	end
end

do
	local data = {
		-- wizard oil
		[20744] = 5,
		[20746] = 5,
		[20750] = 5,
		[20749] = 5,

		-- mana oil
		[20745] = 5,
		[20747] = 5,
		[20748] = 5,

		-- discombobulator
		[4388] = 5,

		-- recombobulator
		[4381] = 10,
		[18637] = 10,

        -- deflector
        [4376] = 5,
        [4386] = 5,

		-- ... TODO
	}
	function M.max_item_charges(item_id)
	    return data[item_id]
	end
end

function M.item_key(link)
    local item_id, suffix_id = parse_link(link)
    return item_id .. ':' .. suffix_id
end

-- each item's own name, looked up once per session (a Full scan makes thousands of records)
local base_names = {}

-- the item's own name, without an ending; nil while the game has not loaded it
local function base_name(item_id)
    local base = base_names[item_id]
    if not base then
        base = GetItemInfo(item_id) or (item_info(item_id) or empty).name
        base_names[item_id] = base
    end
    return base
end

-- auxForever (0.8, gear versions): the key aux keeps prices under. Gear with a random ending ("of
-- the Wolf") is priced per ending, as Blizzard's Sell window groups it: on Forever a link's suffix
-- field is empty (Medicine Staff of the Wolf, seen 2026-10-20), so every ending looked alike, and
-- the auction house's own versions of one name have the same stats (two Medicine Staffs of Arcane
-- Protection, seen 2026-10-20), so the name is what tells gear apart. The ending is what the full
-- name adds to the item's own name, in lower case: "4575:of the wolf". Anything else: "4575:0".
function M.price_key(item_id, name)
    if not item_id or item_id <= 0 or type(name) ~= 'string' then
        return (item_id or 0) .. ':0'
    end
    local base = base_name(item_id)
    -- any letter case: a typed name (/aux price) as well as the game's (0.8, review H-002)
    if base and #name > #base and strlower(strsub(name, 1, #base)) == strlower(base) then
        local ending = strlower(aux.trim(strsub(name, #base + 1)))
        if ending ~= '' then
            return item_id .. ':' .. ending
        end
    end
    return (item_id or 0) .. ':0'
end

-- the price key of an auction house item key: its version number does not say the ending, its name
-- does (nil while the game has not loaded the name)
function M.item_key_price_key(key)
    if (key.itemSuffix or 0) == 0 then
        return key.itemID .. ':0'
    end
    -- without the item's own name the ending cannot be told, and "4575:0" would be the wrong item
    -- (review H-006, finding 1): wait, as for a version whose name has not loaded
    if not base_name(key.itemID) then
        request_item(key.itemID)
        return
    end
    local key_info = C_AuctionHouse.GetItemKeyInfo(key)
    return type(key_info) == 'table' and key_info.itemName and price_key(key.itemID, key_info.itemName) or nil
end

-- 0.8 (review H-002): the item behind a typed full name ("Medicine Staff of the Wolf"). aux's item
-- list knows items by their own name only, so if the whole name is not in it, the part before an
-- " of " is tried, the last one first. Returns the item ID and its own name, or nil.
function M.split_ending(name)
    if type(name) ~= 'string' or name == '' then
        return
    end
    local id = item_id(name)
    if id then
        return id, name
    end
    local positions, from = {}, 1
    while true do
        local at = strfind(strlower(name), ' of ', from, true)
        if not at then break end
        tinsert(positions, at)
        from = at + 1
    end
    for i = #positions, 1, -1 do
        local base = strsub(name, 1, positions[i] - 1)
        id = item_id(base)
        if id then
            return id, base
        end
    end
end

-- the price key of a link (its name is the full name, ending included)
function M.link_price_key(link)
    local item_id, _, _, _, name = parse_link(link)
    return price_key(item_id, name)
end

-- item:itemID:enchantID:gem1:gem2:gem3:gem4:suffixID:uniqueID:...
function M.parse_link(link)
    local item_string = strmatch(link, 'item:([%-%d:]*)')
    if not item_string then
        return 0, 0, 0, 0, strmatch(link, '|h%[(.-)%]|h')
    end
    local fields = aux.split(item_string, ':')
    local name = strmatch(link, '|h%[(.-)%]|h')
    return tonumber(fields[1]) or 0, tonumber(fields[7]) or 0, tonumber(fields[8]) or 0, tonumber(fields[2]) or 0, name
end

function M.item(item_id, suffix_id)
    local itemstring = 'item:' .. (item_id or 0) .. '::::::' .. (suffix_id or 0)
    local name, link, quality, level, requirement, class, subclass, max_stack, slot, texture, sell_price = GetItemInfo(itemstring)
    return name and {
        name = name,
        link = link,
        quality = quality,
        level = level,
        requirement = requirement,
        class = class,
        subclass = subclass,
        slot = slot,
        max_stack = max_stack,
        texture = texture,
        sell_price = sell_price
    } or item_info(item_id)
end

function M.category_index(category)
    for i, v in ipairs(AuctionCategories) do
        -- ignoring trailing s because sometimes type and category differ in number
        if gsub(strupper(v.name), 'S$', '') == gsub(strupper(category), 'S$', '') then
            return i, v.name
        end
    end
end

function M.subcategory_index(category_index, subcategory)
    if category_index > 0 then
        for i, v in ipairs(AuctionCategories[category_index].subCategories or empty) do
            if strupper(v.name) == strupper(subcategory) then
                return i, v.name
            end
        end
    end
end

function M.subsubcategory_index(category_index, subcategory_index, subsubcategory)
    if category_index > 0 and subcategory_index > 0 then
        for i, v in ipairs(AuctionCategories[category_index].subCategories[subcategory_index].subCategories or empty) do
            if strupper(v.name) == strupper(subsubcategory) then
                return i, v.name
            end
        end
    end
end

-- 0.8.0.1 (FB-024, reported by GregoryWW): the game's equip location of an item (GetItemInfo's
-- ninth answer) as the inventory type number Forever's auction house categories use
-- (Enum.InventoryType; the numbers in tests/forever_categories.lua)
local INVENTORY_TYPES = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_BODY = 4, INVTYPE_CHEST = 5,
    INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10,
    INVTYPE_FINGER = 11, INVTYPE_TRINKET = 12, INVTYPE_WEAPON = 13, INVTYPE_SHIELD = 14,
    INVTYPE_RANGED = 15, INVTYPE_CLOAK = 16, INVTYPE_2HWEAPON = 17, INVTYPE_BAG = 18,
    INVTYPE_TABARD = 19, INVTYPE_ROBE = 20, INVTYPE_WEAPONMAINHAND = 21, INVTYPE_WEAPONOFFHAND = 22,
    INVTYPE_HOLDABLE = 23, INVTYPE_AMMO = 24, INVTYPE_THROWN = 25, INVTYPE_RANGEDRIGHT = 26,
    INVTYPE_QUIVER = 27, INVTYPE_RELIC = 28,
}

-- The slot of an item in the auction house's categories, found by its equip location
-- ("INVTYPE_CLOAK"), not by name: the game names slots ("Cloak") differently from equip locations,
-- so an exact search never had a slot. Worse, a cloak is cloth armor that Forever files under
-- Armor > Miscellaneous > Cloak (Blizzard's Camelot/Blizzard_AuctionData.lua), so an exact search
-- for one asked for Armor > Cloth, which has no cloaks, and found nothing. Looks in the item's own
-- type first (Cloth > Head), then in its whole category, used only when exactly one slot there
-- holds that equip location. Returns the type and slot numbers; the type unchanged and no slot
-- when nothing fits (weapons, whose slots are weapon types, not equip locations).
function M.inventory_slot(category_index, subcategory_index, equip_location)
    local inventory_type = INVENTORY_TYPES[equip_location or '']
    local category = category_index and AuctionCategories[category_index]
    if not inventory_type or not category then
        return subcategory_index
    end
    local function holds(slot)
        for _, filter in ipairs(slot.filters or empty) do
            if filter.inventoryType == inventory_type then
                return true
            end
        end
    end
    local subcategories = category.subCategories or empty
    local own = subcategory_index and subcategories[subcategory_index]
    for i, slot in ipairs(own and own.subCategories or empty) do
        if holds(slot) then
            return subcategory_index, i
        end
    end
    local found_type, found_slot, count = nil, nil, 0
    for t, subcategory in ipairs(subcategories) do
        for i, slot in ipairs(subcategory.subCategories or empty) do
            if holds(slot) then
                found_type, found_slot, count = t, i, count + 1
            end
        end
    end
    if count == 1 then
        return found_type, found_slot
    end
    return subcategory_index
end

function M.item_quality_index(item_quality)
    for i = 0, 4 do
        local quality = _G['ITEM_QUALITY' .. i .. '_DESC']
        if strupper(item_quality) == strupper(quality) then
            return i, quality
        end
    end
end

-- auxForever: the backpack, the four bags and Forever's reagent bag (bag 5, Enum.BagIndex.ReagentBag
-- in Blizzard's Forever code); Classic aux stopped at bag 4, so reagent bag items never showed
function M.last_bag()
	return max(4, tonumber(NUM_TOTAL_EQUIPPED_BAG_SLOTS) or 5)
end

function M.inventory()
	local bag, slot = 0, 0
	local last = last_bag()
	return function()
		if slot >= C_Container.GetContainerNumSlots(bag) then
			repeat bag = bag + 1 until bag > last or C_Container.GetContainerNumSlots(bag) > 0
			slot = 1
		else
			slot = slot + 1
		end
		if bag <= last then return {bag, slot} end
	end
end
