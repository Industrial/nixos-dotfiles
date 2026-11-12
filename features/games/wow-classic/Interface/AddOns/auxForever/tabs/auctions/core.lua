select(2, ...) 'aux.tabs.auctions'

local aux = require 'aux'
local scan = require 'aux.core.scan'
local scan_util = require 'aux.util.scan'

local tab = aux.tab 'Auctions'

-- Forever: the list comes from C_AuctionHouse.QueryOwnedAuctions and auctions are cancelled by ID.

function aux.event.AUX_LOADED()
    aux.event_listener('OWNED_AUCTIONS_UPDATED', function()
        refresh = true
    end)
    -- 0.7.1 (FB-016): a cancel counts once the auction house confirms it
    aux.event_listener('AUCTION_CANCELED', function(auction_id)
        if auction_id and cancelling[auction_id] then
            cancelling[auction_id] = nil
            cancelled[auction_id] = true
        end
        if aux.frame:IsShown() then
            aux.query_owned_auctions()
        end
    end)
    for _, event in ipairs{'AUCTION_HOUSE_AUCTION_CREATED', 'AUCTION_HOUSE_AUCTIONS_EXPIRED'} do
        aux.event_listener(event, function()
            if aux.frame:IsShown() then
                aux.query_owned_auctions()
            end
        end)
    end
end

function tab.OPEN()
    frame:Show()
    aux.query_owned_auctions()
    refresh = true
    -- prices are checked once the list is in, unless a check is recent
    auto_check = true
end

function tab.CLOSE()
    listing:SetSelectedRecord()
    frame:Hide()
end

function M.scan_auctions()
    local auctions, present = {}, {}
    for _, auction in scan.owner_auctions() do
        tinsert(auctions, auction)
        present[auction.auction_id or 0] = true
    end
    for id in pairs(cancelled) do
        if not present[id] then
            cancelled[id] = nil
        end
    end
    -- an auction that left your list while its cancel was waiting is gone: nothing more to say
    for id in pairs(cancelling) do
        if not present[id] then
            cancelling[id] = nil
        end
    end
    listing:SetDatabase(auctions)
end

-- auxForever (0.4): undercut check. Each item you sell is read once (about half a second per
-- item, only when the tab opens or Check prices is pressed, never in the background). For each
-- item it keeps the cheapest price of other sellers and how many other sellers list it at each
-- price. Another seller at your price ("tied") is shown, but only a lower price counts as undercut
-- (aux matches the lowest price by default; who sells first at one price is E6, Unknown).
CHECK_AGAIN = 120 -- seconds before opening the tab checks again by itself

checks = {} -- item key text -> {lowest = cheapest other seller per item, at_price = {[price] = other sellers}}
checking = nil -- {done, total} while a check runs
checked_at = nil
cancelled = {} -- auction IDs the auction house confirmed cancelled, until the list no longer has them
-- auxForever (0.7.1, FB-016): a cancel sent but not yet confirmed. aux used to say "Cancelled"
-- as soon as it was sent; a cancel the server refused or never answered still read cancelled.
cancelling = {} -- auction ID -> GetTime() when the cancel was sent
CANCEL_TIMEOUT = 10 -- seconds without an answer before the row goes back to its status

local function key_text(item_key)
    return scan.item_key_string(item_key)
end

-- the price key an auction is checked under (info.price_key): gear with an ending by its name
local function check_key(record)
    return record.price_key or (record.item_search_key and key_text(record.item_search_key)) or record.item_id .. ':0'
end

-- auxForever (0.8, gear versions): gear with a random ending is checked against every listing of
-- its name, as Blizzard's Sell window does: the auction house keeps one name under several versions
-- with the same stats (Ritual Belt of Arcane Protection under four, seen 2026-10-17), and a check of
-- the exact version alone said "Only one listed" with others of the name for sale. Such gear is read
-- with a name search of the item (every version), anything else by its item key as before.
function M.check_prices()
    local keys, item_ids, queries, wanted, seen = {}, {}, {}, {}, {}
    for _, record in ipairs(listing.records or empty) do
        if record.sale_status ~= 1 and record.item_search_key then
            local key = check_key(record)
            if not wanted[key] then
                wanted[key] = true
                if key ~= record.item_id .. ':0' then
                    if not item_ids[record.item_id] then
                        item_ids[record.item_id] = true
                        local query = scan_util.item_query(record.item_id)
                        if query then tinsert(queries, query) end
                    end
                else
                    local k = key_text(record.item_search_key)
                    if not seen[k] then
                        seen[k] = true
                        tinsert(keys, record.item_search_key)
                    end
                end
            end
        end
    end
    if #keys > 0 then
        tinsert(queries, 1, {item_keys = keys})
    end
    if #queries == 0 then
        return
    end
    local found = {}
    -- 0.8 (review H-002, finding 5): a name search reads every version of the item, so how many items
    -- are left is not known in advance; then only the count read so far is shown
    local by_name = #queries - (#keys > 0 and 1 or 0)
    checking = {done = 0, total = by_name == 0 and #keys or nil}
    scan.start{
        type = 'list',
        quiet = true,
        queries = queries,
        on_page_loaded = function()
            if checking then checking.done = checking.done + 1 end
        end,
        on_auction = function(record)
            if record.own then return end
            local k = check_key(record)
            if not wanted[k] then return end
            local price = ceil(record.unit_buyout_price)
            if price <= 0 then return end
            local entry = found[k] or {at_price = {}}
            found[k] = entry
            if not entry.lowest or price < entry.lowest then
                entry.lowest = price
            end
            local mine = record.contains_own or (record.own_count or 0) > 0
            entry.at_price[price] = (entry.at_price[price] or 0) + max(1, (record.seller_count or 1) - (mine and 1 or 0))
        end,
        on_complete = function()
            for key in pairs(wanted) do
                checks[key] = found[key] or {at_price = {}}
            end
            checking = nil
            checked_at = time()
            listing:UpdateRows()
        end,
        on_abort = function()
            checking = nil
        end,
    }
end

-- 'sold', 'cancelled', 'cancelling', 'bid', 'no buyout', 'unchecked', 'undercut' (and by how much),
-- 'tied' (and how many other sellers) or 'lowest'; the cheapest other price as the third value
function M.auction_status(record)
    if record.sale_status == 1 then
        return 'sold'
    elseif cancelled[record.auction_id or 0] then
        return 'cancelled'
    elseif cancelling[record.auction_id or 0] then
        return 'cancelling'
    elseif record.high_bidder then
        return 'bid'
    elseif (record.buyout_price or 0) <= 0 then
        return 'no buyout'
    end
    local check = record.item_search_key and checks[check_key(record)]
    if not check then
        return 'unchecked'
    end
    local price = ceil(record.unit_buyout_price)
    if check.lowest and check.lowest < price then
        return 'undercut', price - check.lowest, check.lowest
    elseif check.at_price[price] then
        return 'tied', check.at_price[price], check.lowest
    end
    return 'lowest', nil, check.lowest
end

-- the auctions in the order the table shows them
local function shown_records()
    local records = {}
    for _, info in ipairs(listing.rowInfo or empty) do
        for _, child in ipairs(info.children or empty) do
            tinsert(records, child.record)
        end
    end
    return records
end

function M.next_undercut()
    for _, record in ipairs(shown_records()) do
        if auction_status(record) == 'undercut' then
            return record
        end
    end
end

function M.status_counts()
    local counts = {total = 0}
    for _, record in ipairs(listing.records or empty) do
        local status = auction_status(record)
        counts[status] = (counts[status] or 0) + 1
        counts.total = counts.total + 1
    end
    return counts
end

do
    local locked = {}

    -- returns true when the cancel was sent
    function M.cancel_auction(record)
        record = record or (listing:GetSelection() or empty).record
        if not record or not record.auction_id or cancelling[record.auction_id] or GetTime() - (locked[record.auction_id] or 0) <= .5 or not C_AuctionHouse.CanCancelAuction(record.auction_id) then
            return
        end
        local cost = C_AuctionHouse.GetCancelCost(record.auction_id) or 0
        if cost > GetMoney() then
            UIErrorsFrame:AddExternalErrorMessage(ERR_NOT_ENOUGH_MONEY)
            return
        end
        C_AuctionHouse.CancelAuction(record.auction_id)
        locked[record.auction_id] = GetTime()
        cancelling[record.auction_id] = GetTime()
        listing:UpdateRows()
        return true
    end
end

-- a cancel with no answer in time: the row shows its real status again, and the player is told
function M.check_cancels()
    for id, sent in pairs(cancelling) do
        if GetTime() - sent >= CANCEL_TIMEOUT then
            cancelling[id] = nil
            local name = 'an auction'
            for _, record in ipairs(listing.records or empty) do
                if record.auction_id == id then
                    name = record.link or record.name
                    break
                end
            end
            aux.print('The auction house did not confirm cancelling ' .. name .. '. If it is still in your list, it is still for sale; select it and press Cancel again.')
            listing:UpdateRows()
            aux.query_owned_auctions()
        end
    end
end

-- Cancel undercut: one auction per click (the game needs a click for each cancel)
function M.cancel_next_undercut()
    local record = next_undercut()
    if record and cancel_auction(record) then
        listing:SetSelectedRecord(record)
    end
end

-- auxForever: the list follows the game's events; a slow refresh keeps time left current. aux used
-- to run a thread every frame all game long to rebuild it every second.
REFRESH_SECONDS = 10

function on_update()
    if refresh or GetTime() >= (next_refresh or 0) then
        refresh = false
        next_refresh = GetTime() + REFRESH_SECONDS
        scan_auctions()
        -- 0.8.2 (FB-037): the check waits while a Full scan runs (it would stop it)
        if auto_check and not scan.is_full_scan() then
            auto_check = false
            -- like the Sniper, the tab in front gets the requests: a search left running elsewhere
            -- stops. A recent check is reused unless an auction (newly posted) was never checked.
            if not checked_at or time() - checked_at >= CHECK_AGAIN or (status_counts().unchecked or 0) > 0 then
                check_prices()
            end
        end
    end

    -- the buttons and status lines, a few times a second
    if GetTime() >= (next_controls or 0) then
        next_controls = GetTime() + .2
        if next(cancelling) then
            check_cancels()
        end
        update_controls()
    end
end
