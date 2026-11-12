select(2, ...) 'aux.tabs.sniper'

local aux = require 'aux'
local info = require 'aux.util.info'
local money = require 'aux.util.money'
local scan = require 'aux.core.scan'
local history = require 'aux.core.history'
local buy_bar = require 'aux.gui.buy_bar'

local tab = aux.tab 'Sniper'

-- auxForever: the Sniper. It reads the item list of the whole auction house again and again (one
-- round took 8.5 seconds for 7718 items on Forever, Tyler's /aux debug list, 2026-10-04) and lists
-- the items whose lowest price is a deal. The list only knows each item's lowest price, which may
-- be a bid, so an item that looks like a deal is opened (one request) to check its real auctions.
-- Only checked auctions are listed, and they are what the buy bar buys.
-- It runs only while its tab is open: the Sniper, searches and posting share the game's request
-- limit. Closing the tab holds it; closing the auction house stops it.

AUCTION_CUT = .05 -- the auction house cut, as on the Post tab
MIN_DAYS = 3 -- days of price history needed before a price can be a deal against the usual price
ROUND_PAUSE = 2.5 -- seconds between rounds: less garbage and fewer requests than 1s, deals still quick (Tyler)
MAX_DEALS = 100
ALERT_GAP = 10 -- seconds: at most one sound per this long, however many deals turn up
-- 0.8.2 (FB-028): a deal read this many seconds ago or less goes straight to the buy bar when
-- clicked, without reading its auctions again (one request less between the sound and the purchase;
-- a player reported over 30 seconds). Buying still never spends more than shown: a trade good's
-- price is confirmed only at or below it, and an item's auction has a fixed buyout.
FRESH_SECONDS = 15

running = false -- Start was pressed
active = false -- a round is under way
round = 0
last_count, last_seconds = nil, nil
deals = {} -- one record per item: the cheapest checked auction, with deal_* fields

local known = {} -- item key text -> the lowest price already judged
-- 0.8.2 (FB-036): item key text -> {market, at}: today's market as last read (market_now), so the
-- next rounds do not open an item again and again while its price only moves along a flat market
local markets = {}
MARKET_MEMORY = 15 * 60 -- seconds a read market is trusted for that
local seen_items = {} -- during a round: item key text -> lowest price on the list
-- 0.8.2 build 2 (FB-036, Swiftwren's Invoker's Cord): during a round, item ID -> the list's entry for
-- a gear version (an item key with a suffix number), or a list of them when one ID has several.
-- Versions of one name have the same stats (docs/forever-auction-house.md), so when one is opened as
-- a possible deal, the others are read too and count toward today's market. One table every round.
local versions = {}
-- 0.8.2 build 3 (review H-008, finding 2): price key -> today's market from the last Full scan, the
-- same rule as market_now with the cheapest price left out (rest_market), so the round's check on the
-- item list need not open an item whose price is the normal one. It replaced price history's latest
-- price, which counts the cheapest listing as the market for items with 40 units or fewer (a snipe
-- already up during the Full scan was hidden all day) and was rewritten by the Sniper's own reads.
local scan_markets = {}
local scan_markets_at -- GetTime() of the Full scan they come from
SCAN_MARKET_TRUST = 2 * 60 * 60 -- seconds a Full scan's markets are trusted for that
local next_round_at
local last_alert -- GetTime() of the last sound
local checked -- the selected deal, as the buy bar shows it
local show_deal -- the buy bar for a deal (below, with the buying)

-- 0.8.2 build 7 (H-009 and H-010, Tyler: "I find it very jarring that we stop the entire search when
-- someone highlights something"): only a live gear deal holds the rounds while it is selected. Its
-- purchase is taken from the item's latest search (Tyler, 0.4.1: Buy did nothing after the rounds
-- had searched other items), so no other search may run between its read and the click. Trade
-- goods are bought by item ID and the buy bar asks the server for a price first (rounds searched
-- other items while they were bought in 0.4.1, and that worked), and a gone deal cannot be bought:
-- with those selected the rounds go on.
local function holding()
    return checked and not checked.commodity and not checked.deal_gone
end

-- the item key text of the selected deal while it can still be bought: the rounds do not open it
-- again, which would put a new record in its place and drop the player's selection (H-010, finding 1)
local function selected_live_key()
    return checked and not checked.deal_gone and checked.deal_key
end
checking = nil -- during a round: {done, total} possible deals being opened
deals_changed = false -- the table is redrawn soon (throttled) while a round finds deals

-- The deal rule. unit_price: lowest price per item; usual: the usual price (nil without history);
-- vendor: what a vendor pays for one; days: days of price history; percent, min_profit: the
-- player's settings. Returns why it is a deal ('vendor' or 'usual'), the profit per item and the
-- percent of the usual price; nil when it is not a deal.
-- Below vendor price is a deal without any history (a sure profit). Otherwise the price must be at
-- most percent of the usual price and the usual price must rest on MIN_DAYS days of history, so a
-- thin price history does not fake deals. Either way the profit per item (after the auction house
-- cut when reselling) must be at least min_profit, which hides trivial finds.
-- The usual price used here is never below the vendor price.
-- 0.8.2 (FB-036, reported by Swiftwren): market is today's market for the item, from its listings
-- just read (market_now; nil when they say nothing). The usual price is a slow average of past days,
-- and after Forever launched prices fell faster than it follows: a material listed by hundreds at
-- one price showed as "4% of usual", and a "deal" bought there could only be relisted at a loss.
-- When today's market is lower, the deal is judged against it instead, and the reason is 'market'.
function M.judge(unit_price, usual, vendor, days, percent, min_profit, market)
    vendor = vendor or 0
    if not unit_price or unit_price <= 0 then
        return
    end
    local reference = usual and usual > 0 and max(usual, vendor) or nil
    if vendor > 0 and unit_price < vendor then
        if vendor - unit_price >= min_profit then
            return 'vendor', vendor - unit_price, reference and aux.round(100 * unit_price / reference) or nil
        end
        return
    end
    if not reference or (days or 0) < MIN_DAYS then
        return
    end
    local reason = 'usual'
    if market and market > 0 and max(market, vendor) < reference then
        reference, reason = max(market, vendor), 'market'
    end
    local profit = floor(reference * (1 - AUCTION_CUT)) - unit_price
    local pct = 100 * unit_price / reference
    if pct <= percent and profit >= min_profit then
        return reason, profit, aux.round(pct)
    end
end

-- 0.8.2 (FB-036): today's market for one item, from its listings. The units at the cheapest price
-- are the possible deal; the market is what the units above it ask: the middle price of their
-- cheapest quarter (MARKET_NOW_SHARE). Hundreds listed just above the cheapest price make that the
-- market; a few cheap units next to a normal market do not (price history's market price uses the
-- cheapest 5%, where 2 cheap units in a small listing already set it).
-- Review H-008 (Gemini, docs/reviews/2026-11-09-sniper-0.8.2.md):
-- - finding 1: a price that 3 or more sellers ask is the market, whatever is listed above it. It
--   was only checked when nothing was listed above, so 80 units from 6 sellers at 2s 10c next to one
--   at 22s were a "deal".
-- - finding 4: fewer than 3 units above the cheapest price are not a market. Two cheap listings 1c
--   apart, nothing else, hid a deal that adding 100 units at the usual price showed.
-- cheapest: the cheapest unit price; sellers: how many sellers ask it (0 when not known); others:
-- {price, units} of the units above it, any order (sorted here); total: their units. nil when the
-- listings say nothing more: one cheap auction alone is judged against the usual price, as before.
MARKET_NOW_SHARE = .25
MARKET_SELLERS = 3
MARKET_MIN_UNITS = 3
function M.rest_market(cheapest, sellers, others, total)
    if sellers >= MARKET_SELLERS then
        return cheapest
    end
    if total < MARKET_MIN_UNITS then
        return
    end
    sort(others, function(a, b) return a.price < b.price end)
    local middle = ceil(max(1, ceil(total * MARKET_NOW_SHARE)) / 2)
    local seen = 0
    for _, other in ipairs(others) do
        seen = seen + other.units
        if seen >= middle then
            return other.price
        end
    end
end

-- today's market from records just read (one item, every version of its name read; the player's own
-- left out). Costs no request: the Sniper reads a candidate's auctions anyway.
function M.market_now(records)
    local cheapest
    for _, record in ipairs(records or empty) do
        if not record.own and (record.buyout_price or 0) > 0 then
            local unit = ceil(record.unit_buyout_price)
            if not cheapest or unit < cheapest then
                cheapest = unit
            end
        end
    end
    if not cheapest then
        return
    end
    local others, total, sellers = {}, 0, 0
    for _, record in ipairs(records) do
        if not record.own and (record.buyout_price or 0) > 0 then
            local unit = ceil(record.unit_buyout_price)
            if unit > cheapest then
                local units = history.record_units(record)
                tinsert(others, {price = unit, units = units})
                total = total + units
            else
                sellers = sellers + max(1, record.seller_count or 1)
            end
        end
    end
    return rest_market(cheapest, sellers, others, total)
end

-- usual price, vendor price, days of history; nil when the client has not loaded the item yet
-- Runs for every item whose price changed (all of them in the first round), so it builds no tables:
-- the vendor price straight from the game, the history from its cache.
-- auxForever (0.6, Tyler): the Sniper is for making money, so
-- - gray (poor) items are never a deal: "gray items definitely cannot be in the sniper". They get
--   no usual price and no vendor price, so judge finds nothing, below vendor price included.
-- - the days counted are days of complete looks only (history.value_and_complete_days), so a usual
--   price resting on a few old asking prices cannot make a deal.
POOR = 0
function M.item_facts(key, item_id)
    local name, _, quality, _, _, _, _, _, _, _, sell_price = GetItemInfo(item_id)
    if not name then
        -- the game drops item data now and then; aux's own saved item list still has the vendor price
        info.request_item(item_id)
        local saved = info.item_info(item_id)
        if not saved then
            return
        end
        quality, sell_price = saved.quality, saved.sell_price
    end
    if quality == POOR then
        return nil, 0, 0
    end
    local usual, days = history.value_and_complete_days(key)
    if days > history_days then
        history_days = days
    end
    return usual, sell_price or 0, days
end

-- auxForever (0.6 build 9, Tyler): the most days of complete looks any item has, seen while judging
-- items (no extra work), and whether a whole round has been judged, so the notice below can say how
-- far the price history is from MIN_DAYS
history_days, history_days_known = 0, false
STALE_SECONDS = 2 * 24 * 60 * 60

-- The line next to the deal count: a warning when the last Full scan is more than two days old
-- (usual prices may be out of date), or, while the price history is too short for deals against
-- the usual price, how far along it is. nil when all is well. A warning, not a lock: below vendor
-- deals need no history, and the game allows a Full scan only once every 15 minutes (Tyler, build 9).
function M.history_notice(now, last_scan, days, known)
    if last_scan and last_scan > 0 and now - last_scan > STALE_SECONDS then
        local ago = floor((now - last_scan) / (24 * 60 * 60))
        return 'Your last Full scan was ' .. ago .. (ago == 1 and ' day' or ' days') .. ' ago. Usual prices may be out of date.', 'stale'
    end
    if (known or not last_scan or last_scan <= 0) and days < MIN_DAYS then
        return 'Deals against the usual price start after ' .. MIN_DAYS .. ' days of Full scans; you have ' .. days .. ' so far.', 'thin'
    end
end

local function settings()
    return aux.account_data.sniper_percent, aux.account_data.sniper_profit
end

function M.judge_record(record, market)
    local usual, vendor, days = item_facts(record.price_key or record.item_key, record.item_id)
    if usual == nil and vendor == nil then
        if not record.deal_key then
            return
        end
        -- a deal already found keeps the facts it was judged with while the game reloads the item
        -- (without this, every deal could vanish from the table at once and come back later)
        usual, vendor, days = record.deal_history, record.deal_vendor, record.deal_days
    end
    local percent, min_profit = settings()
    -- a deal already found is judged again (shown_deals) with the market it was found with
    return judge(ceil(record.unit_buyout_price), usual, vendor, days, percent, min_profit, market or record.deal_market)
end

local function find_deal(key)
    for i, deal in ipairs(deals) do
        if deal.deal_key == key then
            return deal, i
        end
    end
end

-- One sound for a burst of finds: the first round with a loose setting can find dozens of deals,
-- each opened one by one (about half a second each), and a sound per deal played over and over.
function M.alert()
    local now = GetTime()
    if last_alert and now - last_alert < ALERT_GAP then
        return
    end
    last_alert = now
    if aux.account_data.sniper_sound then
        PlaySound(SOUNDKIT.RAID_WARNING or 8959, 'Master')
    end
    if type(FlashClientIcon) == 'function' then
        FlashClientIcon()
    end
end

-- a deal no longer matching the settings (or no longer listed) stays in the list as gone
local function set_gone(deal)
    if deal and not deal.deal_gone then
        deal.deal_gone = true
        deal.deal_gone_at = time()
        deals_changed = true
    end
end

-- Open one item (inside the round) and keep its cheapest auction when it is a deal. price: its
-- lowest price on the list, which counts as judged once the item is open.
function check_item(item_key, key, price, other_keys)
    local records = scan.read_item(item_key)
    if not records then
        known[key] = nil -- no answer: try again next round
        return
    end
    known[key] = price
    -- review H-008, finding 3: the other versions of a gear name are read too, so their real buyouts
    -- and amounts count toward today's market (the item list only knows each one's lowest price,
    -- which may be a bid or the player's own). Only the version opened can be bought from this deal.
    local listed = records
    if other_keys then
        listed = {}
        for _, record in ipairs(records) do tinsert(listed, record) end
        for _, other_key in ipairs(other_keys) do
            for _, record in ipairs(scan.read_item(other_key) or empty) do
                tinsert(listed, record)
            end
        end
    end
    local cheapest
    local tiers = {}
    for _, record in ipairs(records) do
        if not record.own and record.buyout_price > 0 then
            tinsert(tiers, record)
            if not cheapest or record.unit_buyout_price < cheapest.unit_buyout_price then
                cheapest = record
            end
        end
    end
    local old = find_deal(key)
    if not cheapest then
        set_gone(old)
        return
    end
    local market = market_now(listed)
    markets[key] = market and {market = market, at = GetTime()} or nil
    local reason, profit, pct = judge_record(cheapest, market)
    if not reason then
        -- the list showed a bid, or the cheap one sold meanwhile
        set_gone(old)
        return
    end
    sort(tiers, function(a, b) return a.unit_buyout_price < b.unit_buyout_price end)
    -- only the units that are a deal can be bought here: the buy bar offered 20 Ironweb Spider Silk
    -- where 7 were below vendor price and the rest cost more (Tyler, 0.4.1)
    for i = #tiers, 1, -1 do
        if not judge_record(tiers[i], market) then
            tremove(tiers, i)
        end
    end
    -- the usual price is only shown when it rests on enough history to be trusted
    local usual, vendor, days = item_facts(cheapest.price_key or cheapest.item_key, cheapest.item_id)
    cheapest.deal_history, cheapest.deal_vendor, cheapest.deal_days = usual, vendor, days
    if (days or 0) < MIN_DAYS then
        usual = nil
    end
    cheapest.deal_key = key
    cheapest.deal_item_key = item_key -- to read the item again when the deal is selected
    cheapest.deal_reason = reason
    cheapest.deal_market = market
    cheapest.deal_read_at = GetTime()
    cheapest.deal_profit = profit
    cheapest.deal_percent = pct
    cheapest.deal_usual = usual and max(usual, vendor or 0) or nil
    cheapest.deal_tiers = cheapest.commodity and tiers or nil
    local same = old and not old.deal_gone and ceil(old.unit_buyout_price) == ceil(cheapest.unit_buyout_price)
    cheapest.deal_found = same and old.deal_found or time()
    -- a row kept in place while a deal is selected stays there with the new read (H-010, finding 3)
    cheapest.row_pin = old and old.row_pin
    if old then
        tremove(deals, aux.key(deals, old))
    end
    tinsert(deals, cheapest)
    trim_deals()
    deals_changed = true
    if not same then
        alert()
    end
end

-- at most MAX_DEALS, the oldest go first, but never the selected deal or a row kept in place above
-- it (H-010, finding 3: one dropped from above moved the selected row up)
function M.trim_deals()
    local i = 1
    while #deals > MAX_DEALS and deals[i] do
        if deals[i] == checked or deals[i].row_pin then
            i = i + 1
        else
            tremove(deals, i)
        end
    end
end

-- One round's item list: judge every item whose lowest price changed, then open the ones that
-- look like a deal
-- the Full scan's prices of one item -> its market by the Sniper's rule (rest_market, the cheapest
-- price left out; how many sellers ask it is not kept by the scan, so that rule is not used here)
scan.on_full_scan_view(function(at, key, flat)
    if at ~= scan_markets_at then
        aux.wipe(scan_markets)
        scan_markets_at = at
    end
    local cheapest
    for i = 1, #flat, 2 do
        if not cheapest or flat[i] < cheapest then
            cheapest = flat[i]
        end
    end
    if not cheapest then
        return
    end
    local others, total = {}, 0
    for i = 1, #flat, 2 do
        if flat[i] > cheapest then
            tinsert(others, {price = flat[i], units = flat[i + 1]})
            total = total + flat[i + 1]
        end
    end
    scan_markets[key] = rest_market(cheapest, 0, others, total)
end)

-- today's market as far as the Sniper remembers it, for the round's check on the item list: the
-- market read when the item was last opened (kept MARKET_MEMORY) and the last Full scan's market for
-- its price key (kept SCAN_MARKET_TRUST). The lower counts. Review H-008, finding 5: a remembered
-- market is dropped as soon as the list's lowest price is above it, since the units that made it are
-- gone (a 55c snipe was refused against an 87c wall that had sold out).
local function remembered_market(key, price_key, price)
    local market
    local memory = markets[key]
    if memory then
        if GetTime() - memory.at >= MARKET_MEMORY or price > memory.market then
            markets[key] = nil
        else
            market = memory.market
        end
    end
    local scanned = price_key and scan_markets[price_key]
    if scanned and scan_markets_at and GetTime() - scan_markets_at < SCAN_MARKET_TRUST and price <= scanned then
        market = market and min(market, scanned) or scanned
    end
    return market
end

-- the other versions on this round's list of a gear candidate's name (item keys; nil: none)
local function other_versions(result, price_key)
    local entry = versions[result.itemKey.itemID]
    if type(entry) ~= 'table' or entry.itemKey then
        return
    end
    local keys
    for _, other in ipairs(entry) do
        if other ~= result and info.item_key_price_key(other.itemKey) == price_key then
            keys = keys or {}
            tinsert(keys, other.itemKey)
        end
    end
    return keys
end

function check_list(results, seen)
    local percent, min_profit = settings()
    local candidates, candidate_keys = {}, {}
    aux.wipe(versions)
    for i, result in ipairs(results) do
        local price = result.minPrice or 0
        if (result.totalQuantity or 0) > 0 and price > 0 then
            local key = scan.item_key_string(result.itemKey)
            seen[key] = price
            -- gear versions by item ID (a number, no work for the rest; review H-008, finding 8)
            if (result.itemKey.itemSuffix or 0) ~= 0 then
                local id = result.itemKey.itemID
                local entry = versions[id]
                if not entry then
                    versions[id] = result
                elseif entry.itemKey then
                    versions[id] = {entry, result}
                else
                    tinsert(entry, result)
                end
            end
            -- the selected deal is not opened while it can be bought, and not marked judged: the
            -- first round after it is let go opens it (H-010, finding 1)
            if not aux.account_data.sniper_ignored[key] and known[key] ~= price and key ~= selected_live_key() then
                -- 0.8: prices are kept per ending (info.price_key), the list's key is a version
                local price_key = info.item_key_price_key(result.itemKey)
                local usual, vendor, days
                if price_key then usual, vendor, days = item_facts(price_key, result.itemKey.itemID) end
                if usual ~= nil or vendor ~= nil then
                    -- a possible deal counts as judged only once it is opened (check_item): a round
                    -- stopped by a click on a deal left the rest marked judged, never opened, so
                    -- those deals were missed until their price changed (found with the slow test
                    -- auction house)
                    local market = remembered_market(key, price_key, price)
                    if judge(price, usual, vendor, days, percent, min_profit, market) then
                        tinsert(candidates, result)
                        candidate_keys[#candidates] = price_key
                    elseif not (market and judge(price, usual, vendor, days, percent, min_profit)) then
                        -- review H-008, finding 5: an item refused only because of a remembered
                        -- market is judged again next round (that memory may be gone by then);
                        -- one refused against the usual price waits for its price to change
                        known[key] = price
                    end
                end
            end
        end
        if i % 200 == 0 then
            aux.coro_wait()
        end
    end
    -- each one is a request (and one per other version of a gear name): shown as "checking 12
    -- possible deals (3 done)" while it runs
    checking = {done = 0, total = #candidates}
    for i, result in ipairs(candidates) do
        local key = scan.item_key_string(result.itemKey)
        -- selected while the round opened the ones before it
        if key ~= selected_live_key() then
            check_item(result.itemKey, key, result.minPrice, other_versions(result, candidate_keys[i]))
        end
        checking.done = checking.done + 1
    end
    checking = nil
end

-- after a round: a deal whose item is gone from the list, or whose lowest price went up, sold
local function mark_gone(seen)
    local was_gone = checked and checked.deal_gone
    for _, deal in ipairs(deals) do
        local price = seen[deal.deal_key]
        if not price or price > ceil(deal.unit_buyout_price) then
            set_gone(deal)
        end
    end
    -- the rounds go on while a trade good is selected: when it sold meanwhile, the buy bar says so
    -- at once instead of offering it (H-010, finding 1)
    if checked and checked.deal_gone and not was_gone and not buy_bar.busy() and not aux.bid_in_progress() then
        show_deal(checked)
    end
end

function start_round()
    active = true
    next_round_at = nil
    local t0 = GetTime()
    -- one table for every round: a new one per round was 7000+ entries of garbage each time
    aux.wipe(seen_items)
    local seen = seen_items
    scan.start{
        type = 'list',
        quiet = true,
        queries = {{blizzard_query = {}}},
        on_item_list = function(results)
            last_count = #results
            check_list(results, seen)
        end,
        on_complete = function()
            active = false
            checking = nil
            round = round + 1
            history_days_known = true
            last_seconds = GetTime() - t0
            if last_count then
                mark_gone(seen)
            end
            next_round_at = GetTime() + ROUND_PAUSE
            deals_changed = true
        end,
        on_abort = function()
            active = false
            checking = nil
            next_round_at = running and GetTime() + ROUND_PAUSE or nil
        end,
    }
end

function M.start()
    running = true
    next_round_at = GetTime()
    update_controls()
end

function M.stop()
    running = false
    next_round_at = nil
    if active then
        scan.abort()
    end
    active = false
    update_controls()
end

-- the settings changed: every item is judged again
function M.settings_changed()
    aux.wipe(known)
    aux.wipe(markets)
    update_deals()
end

function M.clear_deals()
    aux.wipe(deals)
    update_deals()
end

function M.ignore(record)
    if not record then return end
    aux.account_data.sniper_ignored[record.deal_key] = record.name
    local _, index = find_deal(record.deal_key)
    if index then
        tremove(deals, index)
    end
    update_deals()
end

function M.unignore_all()
    aux.wipe(aux.account_data.sniper_ignored)
    aux.wipe(known)
    update_deals()
end

function M.ignored_count()
    return aux.size(aux.account_data.sniper_ignored)
end

-- The deals shown: those that pass the current settings, gone ones too (a 1c find from a looser
-- setting no longer clutters the list once the profit is set back to 5s)
function M.shown_deals()
    local shown = {}
    for _, deal in ipairs(deals) do
        if judge_record(deal) then
            tinsert(shown, deal)
        end
    end
    return shown
end

-- Whether a redraw now would move the row under the mouse: rows moved under the cursor while Tyler
-- tried to pick one (0.4.1), so the table waited while the mouse was over its rows. The rows only,
-- not the buy bar under them (H-010, finding 3). While a deal is selected, it and the rows above it
-- stay in place (pin_rows), so the mouse may rest there: Tyler, 0.8.2 build 7, "I can hear sounds
-- like new entries should be popping up but they dont show up until I unselect" (the mouse stays on
-- the row just clicked). A row below the selected one can still move, and waits.
function mouse_on_moving_row()
    if not frame.listing.list:IsMouseOver() then
        return false
    elseif not checked then
        return true
    end
    for _, row in pairs(listing.rows) do
        if row.record and row:IsVisible() and row:IsMouseOver() then
            return not row.record.row_pin
        end
    end
    return false -- the header or the empty space under the rows
end

-- every frame while the tab is shown
function M.update()
    -- the Sniper owns the request limit while its tab is open: a search still running elsewhere stops
    if running and (buy_bar.busy() or aux.bid_in_progress() or refreshing or holding()) then
        -- a purchase talks to the auction house too: the round stops, and the next one waits until
        -- the purchase is done; a selected gear deal holds them too (holding, above)
        if active then
            scan.abort()
        end
        next_round_at = GetTime() + ROUND_PAUSE
    elseif running and not active and next_round_at and GetTime() >= next_round_at then
        if scan.is_full_scan() then
            -- 0.8.2 (FB-037): a round would stop the Full scan; the next try is a pause later
            next_round_at = GetTime() + ROUND_PAUSE
        else
            start_round()
        end
    end
    if GetTime() >= (next_controls or 0) then
        next_controls = GetTime() + .2
        update_controls()
    end
    update_selection()
    -- deals found during a round show up at once, at most twice a second, but never move the row
    -- under the mouse (mouse_on_moving_row)
    if deals_changed and GetTime() >= (next_deals or 0) and not mouse_on_moving_row() then
        next_deals = GetTime() + .5
        deals_changed = false
        update_deals()
    end
    -- "found 20s ago" keeps counting
    if GetTime() >= (next_refresh or 0) then
        next_refresh = GetTime() + 1
        listing:UpdateRows()
    end
end

function aux.event.CLOSE()
    running = false
    active = false
    next_round_at = nil
    -- review H-008, finding 5: markets read are for this visit only
    aux.wipe(markets)
end

function tab.OPEN()
    frame:Show()
    buy_bar.attach(frame.listing)
    if running and not active then
        next_round_at = GetTime()
    end
    update_deals()
    update_controls()
end

function tab.CLOSE()
    -- held: the rounds carry on when the tab is open again
    if active or refreshing then
        scan.abort()
    end
    refreshing = nil
    active = false
    next_round_at = nil
    listing:SetSelectedRecord()
    buy_bar.attach_default()
    frame:Hide()
end

-- the status next to Start / Stop
function M.status()
    if not running then
        return 'Stopped', 'Start watches the whole auction house for deals'
    end
    if buy_bar.busy() or aux.bid_in_progress() then
        return 'Watching', 'waits while you buy'
    elseif refreshing then
        return 'Watching', 'checking the selected deal...'
    elseif holding() then
        return 'Holding', 'while this item is selected, so Buy works; click it again to go on'
    end
    local done = round > 0 and format('round %d, %s items in %.1fs', round, last_count or 0, last_seconds or 0) or 'first round'
    if checking and checking.total > 0 then
        return 'Watching', format('%s; checking %d possible %s (%d done)', done, checking.total, checking.total == 1 and 'deal' or 'deals', checking.done)
    elseif round == 0 then
        return 'Watching', 'first round, reading the item list...'
    end
    return 'Watching', format('round %d, %s items in %.1fs', round, last_count or 0, last_seconds or 0)
end

-- buying

refreshing = nil -- the gear deal being read again before it can be bought

-- Tyler, 0.4.1: gear deals could not be bought from the Sniper (the button did nothing), while gear
-- from the Search tab and trade goods from the Sniper could. Likely cause: the rounds search other
-- items between finding a deal and the click, and the auction house takes a purchase of an auction
-- from the latest search of its item. So a selected gear deal is read again first (one request),
-- the rounds hold while a gear deal is selected (holding, at the top), and the purchase itself stays
-- on the player's click.

local show_item_bar, show_commodity_bar

-- Read a deal's item again when it is selected; the buy bar offers it once that answer is in.
-- Gear: the same auction, or another one at the shown price or lower. Trade goods: the units that
-- are still a deal, at today's counts (4 of 5 trade good buys failed with "Internal auction error"
-- on deals found minutes earlier, Tyler, 0.4.1).
local function refresh_deal(record)
    local item_key = record.deal_item_key or record.item_search_key
    -- review H-008, finding 6: gear only when nothing else was searched since (see scan.last_read_is)
    local fresh = record.deal_read_at and GetTime() - record.deal_read_at <= FRESH_SECONDS
        and (record.commodity or scan.last_read_is(item_key))
    if not item_key or fresh then
        if record.commodity then show_commodity_bar(record) else show_item_bar(record) end
        return
    end
    if active then
        scan.abort()
    end
    refreshing = record
    buy_bar.show_note(record.name, record.commodity and 'Checking what is left...' or 'Checking the auction...')
    local fresh = {}
    scan.start{
        type = 'list',
        quiet = true,
        no_view = true,
        queries = {{item_keys = {item_key}}},
        on_auction = function(auction)
            if not auction.own and auction.buyout_price > 0 then
                tinsert(fresh, auction)
            end
        end,
        on_complete = function()
            if refreshing ~= record then return end
            refreshing = nil
            if record.commodity then
                local tiers = {}
                local market = market_now(fresh)
                for _, tier in ipairs(fresh) do
                    if judge_record(tier, market) then
                        tinsert(tiers, tier)
                    end
                end
                sort(tiers, function(a, b) return a.unit_buyout_price < b.unit_buyout_price end)
                if tiers[1] then
                    record.deal_tiers = tiers
                    if checked == record then
                        show_commodity_bar(record)
                    end
                    return
                end
            else
                -- the same auction, or another one at the shown price or lower (never more than shown)
                local found
                for _, auction in ipairs(fresh) do
                    if auction.auction_id == record.auction_id then
                        found = auction
                        break
                    elseif not found and ceil(auction.unit_buyout_price) <= ceil(record.unit_buyout_price) then
                        found = auction
                    end
                end
                if found then
                    record.auction_id = found.auction_id
                    if checked == record then
                        show_item_bar(record)
                    end
                    return
                end
            end
            set_gone(record)
            if checked == record then
                buy_bar.show_note(record.name, 'Sold before you could buy it', aux.color.red)
            end
        end,
        on_abort = function()
            if refreshing == record then
                refreshing = nil
            end
        end,
    }
end

function show_deal(record)
    if record.deal_gone then
        buy_bar.show_note(record.name, record.deal_bought and 'Bought' or 'Gone: sold or relisted')
    else
        refresh_deal(record)
    end
end

function show_commodity_bar(record)
        local item_info = info.item(record.item_id)
        buy_bar.show_commodity{
            item_id = record.item_id,
            name = record.name,
            texture = record.texture,
            quality = record.quality,
            max_stack = item_info and item_info.max_stack or 1,
            tiers = function() return record.deal_gone and {} or record.deal_tiers or {record} end,
            on_success = function(n)
                -- the cheapest units went first; check the item again in the next round
                known[record.deal_key] = nil
                local left, rest = n, {}
                for _, tier in ipairs(record.deal_tiers or {}) do
                    local taken = min(left, tier.count)
                    left = left - taken
                    if taken < tier.count then
                        info.set_commodity_count(tier, tier.count - taken)
                        tinsert(rest, tier)
                    end
                end
                record.deal_tiers = rest
                if not rest[1] or ceil(rest[1].unit_buyout_price) > ceil(record.unit_buyout_price) then
                    -- the deal's own price is bought up: the rounds go on
                    record.deal_bought = true
                    set_gone(record)
                    if checked == record then
                        listing:SetSelectedRecord()
                    end
                end
                update_deals()
            end,
            on_refresh = function()
                known[record.deal_key] = nil
                set_gone(record)
                update_deals()
            end,
        }
end

function show_item_bar(record)
        buy_bar.show_item{
            record = record,
            name = record.name,
            texture = record.texture,
            quality = record.quality,
            own = false,
            busy = function()
                return record.deal_gone or record.deal_bought or aux.bid_in_progress() or refreshing ~= nil
            end,
            on_buy = function()
                aux.place_bid(record.auction_id, record.buyout_price, function()
                    -- the next one at this price has a new auction ID: the next round finds it
                    record.deal_bought = true
                    known[record.deal_key] = nil
                    set_gone(record)
                    update_deals()
                    -- bought: the rounds go on
                    if checked == record then
                        listing:SetSelectedRecord()
                    end
                end, function(error)
                    set_gone(record)
                    update_deals()
                    if error == 'timeout' then
                        buy_bar.show_message('No answer from the auction house yet', 'It may still go through: check your mail before buying again', aux.color.red)
                    end
                end)
            end,
            on_bid = function()
                aux.place_bid(record.auction_id, record.bid_price, function()
                    known[record.deal_key] = nil
                    set_gone(record)
                    update_deals()
                end)
            end,
        }
end

-- a click on the deal that is already selected lets it go, and the rounds go on
function M.click_deal(record)
    if record and record == checked then
        listing:SetSelectedRecord()
    end
end

-- 0.8.2 build 7 (H-010, finding 3): the rounds go on while a deal is selected, so new deals and
-- sold ones change the table. The selected row and every row above it keep their places (row_pin:
-- 1, 2, ..., whatever the table is sorted by; a row above that sells dims where it is), and new
-- deals go in below it. When it is let go, the table sorts as usual again.
local function pin_rows(record)
    for _, deal in ipairs(deals) do
        deal.row_pin = nil
    end
    if not record then
        return
    end
    for i, row in ipairs(listing.rowInfo or empty) do
        local shown = row.children[1].record
        shown.row_pin = i
        if shown == record then
            return
        end
    end
end

function update_selection()
    local selection = listing:GetSelection()
    if selection and selection.record ~= checked then
        checked = selection.record
        pin_rows(checked)
        show_deal(checked)
    elseif not selection and checked then
        checked = nil
        pin_rows()
        deals_changed = true
        buy_bar.clear()
    end
end

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- /aux memory detail: what the Sniper keeps
function M.memory_counts()
    return count(known), count(seen_items), #deals, count(markets) + count(scan_markets)
end
