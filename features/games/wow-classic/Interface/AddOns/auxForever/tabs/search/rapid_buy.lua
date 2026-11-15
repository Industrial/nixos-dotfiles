select(2, ...) 'aux.tabs.search'

local aux = require 'aux'
local gui = require 'aux.gui'
local info = require 'aux.util.info'
local money = require 'aux.util.money'
local scan = require 'aux.core.scan'
local buy_bar = require 'aux.gui.buy_bar'

-- auxForever 0.8.4: Rapid Buy, the Search tab's answer to the Sniper's Standing Buy panel
-- (tabs/sniper/standing_buy.lua). It queues every result the search turned up, keeps the cheapest
-- one armed on the buy bar, and buys it on one press, so sweeping a filter no longer means clicking
-- a row, waiting for its auctions, clicking Buy, and finding the next row.
--
-- What it cannot be, and why. Every purchase goes through C_AuctionHouse.PlaceBid (gear) or
-- C_AuctionHouse.StartCommoditiesPurchase (trade goods), and the auction house honours those two
-- only while the game is running code a physical press started: a key, a mouse button, the mouse
-- wheel, a gamepad button. Called from a timer or an event handler they buy nothing at all, and one
-- press is allowed one such call. So aux cannot buy a queue by itself, and nothing here tries to:
-- this panel takes the waiting out of a purchase, not the press. The wheel over the panel is a
-- press, and a flick of it gives far more presses per second than a finger on a button.
--
-- Where the waiting actually was. Clicking a result in fast mode calls open_item (results.lua),
-- which does not read the item at all while a search is running: with Live on it calls
-- restart_live, re-running the whole search, and during a normal search it waits out the entire
-- item list (search.pending_open). That is the few seconds -- a whole round per row, not the one
-- request an item costs. This panel reads items directly instead, one request each, and reads them
-- ahead of the press rather than after it.
--
-- How far ahead it can read. The two kinds of purchase have different physics:
--   * trade goods are bought by item ID against the client's own per-item results, which reading
--     another item does not disturb, so the queue can be read far ahead and a press costs nothing
--   * a gear auction is taken only while that item's own search was the last one the client made
--     (scan.last_read_is, core/scan.lua; the 0.4.1 lesson the Sniper's refresh_deal records), so
--     only the armed item can be hot, and gear costs one request per purchase. That is the floor,
--     and it is the auction house's, not aux's.
-- With "Confirm trade goods for me" on (Settings -> Buying, 0.8.3) a trade good is one press.
--
-- The results table is left exactly as the search built it: the panel keeps its own reads, so fast
-- mode stays fast. Reading through open_item would mark every item open (search.open) and make
-- every later Live round read all of them in full, which is fast mode undone.

local QUEUE_INTERVAL = .2 -- how often the queue is rebuilt and the panel redrawn
local LOOKAHEAD = 12 -- trade goods read ahead of the press
local STALE_SECONDS = 90 -- a read older than this is made again before the item is armed
-- A read that leaves its item still unarmable has answered with something the queue cannot use.
-- After this many in a row the item is passed over for SKIP_SECONDS so the rest of the queue
-- carries on, rather than the same request going out every tick (the Sniper's rule, core.lua).
local FUTILE_READS = 2
local SKIP_SECONDS = 30
local WIDTH = 212
local PANEL_HEIGHT = 150
local TOP_OFFSET = -46 -- under the window's top bar

-- item key text -> {at = when it was read, records = the auctions read}. The panel's own, never the
-- table's: see the note above about search.open.
local loaded = {}
local pending -- the item key text being read right now
local just_read -- the item key text of the read that last came back, until the queue has seen it
local futile = {} -- item key text -> reads in a row that left the item unarmable
local skipped = {} -- item key text -> GetTime() from which the item may be queued again
local want -- the entry the panel wants to read next, nil when it wants nothing
local want_hold -- whether that read is worth holding a Live round for (see rapid_busy)
local armed -- the queue entry the buy bar is armed on
local ours -- the panel armed the bar, rather than the player clicking a row
local next_tick = 0
local queue_length, queue_total = 0, 0

local function on()
    return aux.account_data.search_buy and true or false
end

-- A read is under way, or one is wanted that a Live round is in the way of. results.lua's
-- update_live holds the round while this is true and carries it on afterwards, the same machinery
-- that already holds rounds while the buy bar is buying (a round during a price quote ended it with
-- "Internal auction error", Tyler 0.4.1). Only a first read holds a round: re-reading gear because
-- a round made its search stale would abort the very round that caused it, round after round, so
-- that one waits for the scanner to fall idle instead.
function M.rapid_busy()
    return (pending or (want and want_hold)) and true or false
end

-- the queue --------------------------------------------------------------------------------------

-- The auctions of one item: what the search already read (Full mode reads every auction, so there
-- is nothing to read again), else what this panel read. nil when the item has yet to be read.
local function auctions_of(group)
    if #group.records > 0 then
        return group.records
    end
    local entry = loaded[group.key]
    return entry and entry.records
end

-- Cheapest-first units of a trade good the player can pay for right now, and what they cost. A
-- stack that costs more than the player has is not skipped but cut down to what fits, so a sweep
-- never stalls on one big listing.
local function affordable_units(records, gold)
    local units, total = 0, 0
    for _, tier in ipairs(records) do
        local price, count = tier.commodity_unit_price or 0, tier.count or 0
        if price <= 0 or count <= 0 then
            break
        end
        local take = count
        if total + count * price > gold then
            take = max(0, floor((gold - total) / price))
        end
        units, total = units + take, total + take * price
        if take < count then
            break
        end
    end
    return units, total
end

-- The cheapest gear auction of an item that can be bought outright. Gear is one item per auction,
-- so an item yields one purchase at a time and the next one needs a fresh auction ID anyway.
local function cheapest_auction(records)
    local best
    for _, record in ipairs(records) do
        if not record.own and record.auction_id and (record.buyout_price or 0) > 0
            and (not best or record.unit_buyout_price < best.unit_buyout_price)
        then
            best = record
        end
    end
    return best
end

-- One item of the results, as much as is known about it. Nothing is returned for an item there is
-- no buying: the player's own, bid-only, or more expensive than the player's gold.
local function entry_for(group, gold)
    local records = auctions_of(group)
    local fast = group.fast
    if not records then
        -- not read yet: the fast row knows only the lowest price and how many are for sale, and
        -- that price may be a bid (util/info.lua, browse_record), so it is an estimate and the
        -- queue says so until the item has been read.
        if not fast or (fast.unit_buyout_price or 0) <= 0 or not fast.browse_key then
            return
        end
        return {
            key = group.key,
            item_key = fast.browse_key,
            item_id = fast.item_id,
            validator = fast.validator,
            name = fast.name,
            texture = fast.texture,
            quality = fast.quality,
            commodity = fast.is_commodity and true or false,
            unit_price = fast.unit_buyout_price,
            units = fast.auction_count or 1,
            cost = (fast.auction_count or 1) * fast.unit_buyout_price,
            unread = true,
        }
    end
    local commodity = records[1] and records[1].commodity
    if commodity then
        local tiers = {}
        for _, record in ipairs(records) do
            if not record.own and (record.count or 0) > 0 and (record.commodity_unit_price or 0) > 0 then
                tinsert(tiers, record)
            end
        end
        sort(tiers, function(a, b) return a.commodity_unit_price < b.commodity_unit_price end)
        if not tiers[1] then
            return
        end
        local units, cost = affordable_units(tiers, gold)
        if units < 1 then
            return
        end
        return {
            key = group.key,
            item_key = records[1].item_search_key or C_AuctionHouse.MakeItemKey(records[1].item_id),
            item_id = records[1].item_id,
            -- the search's own conditions, so reading the item again reads it as the search did.
            -- Only a fast row carries them; in Full mode the table's rows are the filtered ones and
            -- a re-read is only there to make the item the client's last search (auctions_of).
            validator = fast and fast.validator,
            name = records[1].name,
            texture = records[1].texture,
            quality = records[1].quality,
            commodity = true,
            tiers = tiers,
            unit_price = tiers[1].commodity_unit_price,
            units = units,
            cost = cost,
        }
    end
    local record = cheapest_auction(records)
    if not record or record.buyout_price > gold then
        return
    end
    return {
        key = group.key,
        item_key = record.item_search_key,
        item_id = record.item_id,
        validator = fast and fast.validator, -- as above
        record = record,
        name = record.name,
        texture = record.texture,
        quality = record.quality,
        commodity = false,
        unit_price = record.unit_buyout_price,
        units = 1,
        cost = record.buyout_price,
        at_price = record.group_count or record.auction_count or 1,
    }
end

-- The results by item: the fast row of an item (if the search is in fast mode) and whatever
-- auctions of it the search read (Full mode). The order they were found in breaks price ties.
local function group_results(search)
    local order, by_key = {}, {}
    for _, record in ipairs(search.records or empty) do
        local group = by_key[record.item_key]
        if not group then
            group = {key = record.item_key, records = {}}
            by_key[record.item_key] = group
            tinsert(order, group)
        end
        if record.fast then
            group.fast = record
        elseif not record.own and not info.is_player(record.owner) then
            tinsert(group.records, record)
        end
    end
    return order
end

-- Everything the search turned up that can still be bought, cheapest per unit first: the search
-- filter is already what the player chose to buy, so within it the best buy is the cheapest one.
-- Ties go to whichever was found first, as the Sniper's queue does.
local function build_queue(search)
    local out, rank = {}, {}
    local gold = GetMoney()
    for i, group in ipairs(group_results(search)) do
        local held = skipped[group.key]
        if held and GetTime() > held then
            skipped[group.key] = nil
            held = nil
        end
        -- A read this old is let go rather than merely re-checked, so the item goes back to being
        -- unread and is read again from scratch. An item whose auctions all sold between the search
        -- and the read answers empty, and an empty answer kept forever would drop it from the queue
        -- until the whole search was run again.
        local data = loaded[group.key]
        if data and GetTime() - data.at > STALE_SECONDS then
            loaded[group.key] = nil
        end
        local entry = not held and entry_for(group, gold)
        if entry then
            rank[entry] = i
            tinsert(out, entry)
        end
    end
    sort(out, function(a, b)
        if a.unit_price ~= b.unit_price then
            return a.unit_price < b.unit_price
        end
        return rank[a] < rank[b]
    end)
    return out
end

-- reading ----------------------------------------------------------------------------------------

-- Whether an item has to be read before it can be armed, and whether that read is worth holding a
-- Live round for.
local function read_needed(entry)
    if entry.unread then
        -- never read, or its read went stale and was let go (build_queue): the player is waiting
        return true, true
    end
    if entry.commodity then
        return false
    end
    -- Gear: the auction house takes the purchase only while this item's own search was the client's
    -- last one, so a round (or a read of the next item) makes an armed gear auction unbuyable. The
    -- key compared is the one the read actually asked with, not the one rebuilt from the answer: a
    -- browse key and a search result's key are the same item but need not be the same table, and
    -- comparing the rebuilt one would never match and would ask again every tick.
    local data = loaded[entry.key]
    return not scan.last_read_is(data and data.item_key or entry.item_key), false
end

-- One item's auctions, one request, without the whole-search detour open_item takes. The scanner is
-- one at a time (core/scan.lua), so this starts only when nothing else is using it; a Live round in
-- the way is held by update_live through rapid_busy and carries on afterwards.
local function read(entry)
    if pending or buy_bar.busy() or aux.bid_in_progress() then
        return
    end
    local search = current_search()
    -- a normal search still loading: reading now would abort it and lose the rest of the list, and
    -- its own rows are moments away
    if search.active and search.mode ~= LIVE_MODE then
        return
    end
    if scan.is_scanning() then
        return -- the Live round being held, or a Full scan: wait for the scanner
    end
    local item_key = entry.item_key
    if not item_key then
        return
    end
    pending = entry.key
    local key, records = entry.key, {}
    scan.start{
        type = 'list',
        quiet = true, -- a sweep says nothing in chat about an item the auction house was slow with
        queries = {{item_keys = {item_key}, validator = entry.validator}},
        on_auction = function(record)
            tinsert(records, record)
        end,
        on_complete = function()
            pending = nil
            loaded[key] = {at = GetTime(), item_key = item_key, records = records}
            just_read = key
            next_tick = 0
        end,
        on_abort = function()
            if pending == key then
                pending = nil
            end
        end,
    }
end

-- buying -----------------------------------------------------------------------------------------

-- A purchase took the cheapest units first, so the panel's own tiers lose them the same way, and so
-- do the table's rows: the table is the search, but it should not go on offering what is sold.
local function consume(search, entry, bought)
    local data = loaded[entry.key]
    local left = bought
    for _, tier in ipairs(data and data.records or empty) do
        if left <= 0 then break end
        local taken = min(left, tier.count or 0)
        left = left - taken
        info.set_commodity_count(tier, (tier.count or 0) - taken)
    end
    if data then
        for i = #data.records, 1, -1 do
            if (data.records[i].count or 0) <= 0 then
                tremove(data.records, i)
            end
        end
    end
    left = bought
    local rows = {}
    for _, record in ipairs(search.records or empty) do
        if record.commodity and record.item_id == entry.item_id and not record.own then
            tinsert(rows, record)
        end
    end
    sort(rows, function(a, b) return a.commodity_unit_price < b.commodity_unit_price end)
    for _, row in ipairs(rows) do
        if left <= 0 then break end
        local taken = min(left, row.count or 0)
        left = left - taken
        if taken >= (row.count or 0) then
            local index = aux.key(search.records, row)
            if index then tremove(search.records, index) end
        else
            info.set_commodity_count(row, row.count - taken)
        end
    end
    search.table:SetDatabase()
end

-- A gear auction was bought (or bid on): the next one at that price carries a new auction ID, so
-- what was read of the item is thrown away and the item is read again before it is armed. This is
-- the one request per gear purchase the auction house's rule costs.
local function drop(search, entry)
    loaded[entry.key] = nil
    if entry.record and search.table:ContainsRecord(entry.record) then
        search.table:RemoveAuctionRecord(entry.record)
    end
    next_tick = 0
end

-- The entry the bar is armed on is shown once, not every tick: show_item rebuilds the bar's lines
-- and show_commodity its quantity chips, and a bar re-styled under a press can drop it. A fresh
-- queue is built every tick, so sameness is judged by item and (for gear) by auction.
local function same_entry(a, b)
    return a and b and a.key == b.key and a.commodity == b.commodity and a.record == b.record
end

local function arm_commodity(entry)
    -- the search this entry came from, not whichever is current when the server answers: a purchase
    -- settles seconds later, and the player may have moved on to another search by then
    local search = current_search()
    local item_info = info.item(entry.item_id)
    buy_bar.show_commodity{
        item_id = entry.item_id,
        name = entry.name,
        texture = entry.texture,
        quality = entry.quality,
        max_stack = item_info and item_info.max_stack or 1,
        tiers = function()
            local data = loaded[entry.key]
            return data and data.records or entry.tiers or {}
        end,
        on_success = function(n)
            consume(search, entry, n)
            next_tick = 0
        end,
        on_refresh = function()
            -- the price went up under the quote: nothing was bought, and what was read is wrong
            loaded[entry.key] = nil
            next_tick = 0
        end,
    }
end

-- Every unit the search matched, not the stack the bar offers by default. Applied on every tick an
-- entry stays armed, because the bar sets its own quantity when it is first shown and because the
-- units left change as a sweep spends gold and buys tiers out.
local function sync_quantity(entry)
    if entry.commodity and buy_bar.buy_quantity() ~= entry.units then
        buy_bar.set_buy_quantity(entry.units)
    end
end

local function arm_item(entry)
    local record = entry.record
    local search = current_search() -- as in arm_commodity: the search this auction came from
    buy_bar.show_item{
        record = record,
        name = entry.name,
        texture = entry.texture,
        quality = entry.quality,
        own = false,
        busy = function()
            return aux.bid_in_progress() or pending ~= nil
        end,
        on_buy = function()
            aux.place_bid(record.auction_id, record.buyout_price, function()
                drop(search, entry)
            end, function(error)
                drop(search, entry)
                if error == 'timeout' then
                    buy_bar.show_message('No answer from the auction house yet', 'It may still go through: check your mail before buying again', aux.color.red)
                end
            end)
        end,
        on_bid = function()
            aux.place_bid(record.auction_id, record.bid_price, function()
                drop(search, entry)
            end, function() drop(search, entry) end)
        end,
    }
end

-- Whether a press right now would buy something. It is the buy bar's own answer, so the panel and
-- the Buy button under the table can never disagree about what is buyable.
local function ready()
    return on() and frame.results:IsVisible() and armed ~= nil and ours and buy_bar.ready()
end

-- Runs inside a hardware event: the key binding, a click on the panel's Buy button, or the wheel
-- over the panel. One purchase, never a loop over the queue -- see the note at the top.
local function fire()
    if not ready() then
        return
    end
    buy_bar.primary_click()
end

-- Keeps the cheapest result armed, and reads the queue ahead of the press.
local function arm()
    local search = current_search()
    local queue = build_queue(search)
    queue_length = #queue
    queue_total = 0
    for _, entry in ipairs(queue) do
        queue_total = queue_total + entry.cost
    end

    -- the player clicked a row themselves: that choice owns the bar, and the panel stands down
    -- until they let it go, exactly as Standing Buy does on the Sniper
    if selected_record() then
        armed, ours, want, want_hold = nil, nil, nil, nil
        return
    end
    -- never while a purchase is under way: the bar is mid-quote or mid-bid, and the entry it is
    -- armed on must not move under it (a trade good's second press confirms the quote)
    if buy_bar.busy() or aux.bid_in_progress() then
        want, want_hold = nil, nil
        return
    end

    local head = queue[1]
    if not head then
        if ours then
            ours = nil
            buy_bar.clear()
        end
        armed, want, want_hold = nil, nil, nil
        return
    end

    local needed, hold = read_needed(head)
    if needed then
        -- the read that just came back left this item still unarmable: its answer is not what the
        -- queue asked for, so after a couple of those the item is passed over for a while
        if just_read == head.key then
            just_read = nil
            futile[head.key] = (futile[head.key] or 0) + 1
            if futile[head.key] > FUTILE_READS then
                futile[head.key], loaded[head.key] = nil, nil
                skipped[head.key] = GetTime() + SKIP_SECONDS
                next_tick = 0
                return
            end
        end
        want, want_hold = head, hold
        read(head)
        if ours and armed then
            buy_bar.show_note(head.name, 'Reading its auctions...')
        end
        armed = nil
        return
    end

    if not same_entry(armed, head) then
        if head.commodity then
            arm_commodity(head)
        else
            arm_item(head)
        end
    end
    armed, ours = head, true
    futile[head.key], just_read = nil, nil
    sync_quantity(head)

    -- Read ahead, but only while a trade good is armed: reading another item would make an armed
    -- gear auction unbuyable (scan.last_read_is), and gear is read one item at a time for that
    -- reason. A trade good's own results survive other reads, so the rest of the queue is read
    -- while the player presses, and each press after the first costs no waiting at all.
    want, want_hold = nil, nil
    if head.commodity then
        for i = 2, min(#queue, LOOKAHEAD) do
            if read_needed(queue[i]) then
                want, want_hold = queue[i], false
                read(queue[i])
                break
            end
        end
    end
end

-- the panel --------------------------------------------------------------------------------------

-- Parented to the Results sub tab through a holder, so leaving the tab (or the sub tab) hides the
-- panel and stops the work below. The panel is placed outside the window; child frames are not
-- clipped to their parent.
local holder = CreateFrame('Frame', nil, frame.results)
holder:SetAllPoints(frame.results)

local panel = gui.panel(holder)
panel:SetFrameStrata('DIALOG')
gui.set_size(panel, WIDTH, PANEL_HEIGHT)
panel:EnableMouse(true)
panel:EnableMouseWheel(true)
panel:SetScript('OnMouseWheel', function() fire() end)
panel:Hide()
M.rapid_buy_panel = panel

-- Beside the window, on whichever side has room. Worked out whenever the panel is drawn, because
-- the window can be moved, resized or scaled at any time.
local function place()
    panel:ClearAllPoints()
    local right = aux.frame:GetRight()
    local scale = aux.frame:GetEffectiveScale()
    local screen = scale > 0 and GetScreenWidth() * UIParent:GetEffectiveScale() / scale or nil
    if right and screen and right + WIDTH + 8 > screen then
        panel:SetPoint('TOPRIGHT', aux.frame, 'TOPLEFT', -6, TOP_OFFSET)
    else
        panel:SetPoint('TOPLEFT', aux.frame, 'TOPRIGHT', 6, TOP_OFFSET)
    end
end
place() -- so the panel has an anchor before it is ever shown

local title = gui.label(panel, gui.font_size.small)
title:SetPoint('TOPLEFT', 10, -10)
gui.themed(function() title:SetText(aux.color.accent.background('RAPID BUY')) end)

local count_label = gui.label(panel, gui.font_size.small)
count_label:SetPoint('TOPRIGHT', -28, -10)
count_label:SetJustifyH('RIGHT')

-- hides the panel; it comes back from Settings or /aux rapid buy
local close_button = gui.button(panel, gui.font_size.small)
gui.set_size(close_button, 16, 16)
close_button:SetPoint('TOPRIGHT', -8, -7)
close_button:SetText('x')
close_button:SetScript('OnClick', function()
    aux.account_data.search_buy = false
    aux.refresh_settings()
end)
close_button:SetScript('OnEnter', function(self)
    GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM')
    GameTooltip:AddLine('Hide Rapid Buy')
    GameTooltip:AddLine('Bring it back in Settings, or with /aux rapid buy.', 1, 1, 1, true)
    GameTooltip:Show()
end)
close_button:SetScript('OnLeave', function() GameTooltip:Hide() end)

local name_label = gui.label(panel, gui.font_size.medium)
name_label:SetPoint('TOPLEFT', 10, -28)
name_label:SetPoint('TOPRIGHT', -10, -28)
name_label:SetJustifyH('LEFT')

local detail_label = gui.label(panel, gui.font_size.small)
detail_label:SetPoint('TOPLEFT', 10, -46)
detail_label:SetPoint('TOPRIGHT', -10, -46)
detail_label:SetJustifyH('LEFT')

local queue_label = gui.label(panel, gui.font_size.small)
queue_label:SetPoint('TOPLEFT', 10, -62)
queue_label:SetPoint('TOPRIGHT', -10, -62)
queue_label:SetJustifyH('LEFT')

local buy_button = gui.button(panel, gui.font_size.medium)
buy_button:SetPoint('TOPLEFT', 10, -80)
buy_button:SetPoint('TOPRIGHT', -10, -80)
buy_button:SetHeight(32)
buy_button:SetScript('OnClick', function() fire() end)
buy_button:SetScript('OnEnter', function(self)
    GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM')
    GameTooltip:AddLine('Buy the armed result')
    GameTooltip:AddLine('One result per press: the auction house takes a purchase only from a real key, click or wheel turn, and only one per press. Press again for the next one in the queue.', 1, 1, 1, true)
    GameTooltip:AddLine('The mouse wheel over this panel buys too, and gives the most presses per second.', .6, .6, .6, true)
    GameTooltip:AddLine('Trade goods are read ahead, so each press costs no waiting. Gear costs one request per purchase: the auction house takes it only while that item was the last one searched.', .6, .6, .6, true)
    GameTooltip:Show()
end)
buy_button:SetScript('OnLeave', function() GameTooltip:Hide() end)
M.rapid_buy_button = buy_button

local hint_label = gui.label(panel, gui.font_size.small)
hint_label:SetPoint('TOPLEFT', 10, -117)
hint_label:SetPoint('TOPRIGHT', -10, -117)
hint_label:SetJustifyH('LEFT')

-- A named button for the key binding: Bindings.xml runs auxForeverRapidBuy:Click('LeftButton') and
-- gui.button makes unnamed frames. Parented to UIParent and always there, so the binding works
-- whatever has focus; fire() is what decides whether there is anything to buy. Off screen and with
-- the mouse turned off, so it is never in the way.
local binding_button = CreateFrame('Button', 'auxForeverRapidBuy', UIParent)
gui.set_size(binding_button, 1, 1)
binding_button:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', -20, 40)
binding_button:EnableMouse(false)
binding_button:SetScript('OnClick', function() fire() end)

_G.BINDING_HEADER_AUXFOREVER = 'auxForever'
_G.BINDING_NAME_AUXFOREVER_RAPID_BUY = 'Rapid Buy (Search)'

local function binding_text()
    local key = GetBindingKey('AUXFOREVER_RAPID_BUY')
    if not key or key == '' then
        return
    end
    local ok, pretty = pcall(GetBindingText, key, 'KEY_')
    return ok and type(pretty) == 'string' and pretty ~= '' and pretty or key
end

local function describe(entry)
    local parts = {}
    if entry.units > 1 then
        tinsert(parts, entry.units .. ' units')
    elseif (entry.at_price or 1) > 1 then
        tinsert(parts, entry.at_price .. ' at this price')
    end
    tinsert(parts, money.to_string(ceil(entry.unit_price), true) .. ' each')
    if entry.unread then
        tinsert(parts, 'lowest listed')
    end
    return aux.color.label.enabled(table.concat(parts, ' · '))
end

local last_label, last_enabled

-- what the button says, and whether a press would do anything
local function button_state()
    if not armed then
        if selected_record() then
            return 'A row is selected', false
        elseif pending then
            return 'Reading...', false
        end
        return 'Nothing to buy', false
    elseif aux.bid_in_progress() then
        return 'Buying...', false
    elseif buy_bar.ready() then
        local total = buy_bar.ready_total() or armed.cost
        return 'Buy ' .. money.to_string(total, true), true
    elseif buy_bar.busy() then
        return 'Buying...', false
    end
    return 'Arming...', false
end

local function draw()
    local more = armed and queue_length - 1 or queue_length
    count_label:SetText(more > 0 and aux.color.label.enabled(more .. ' more') or '')

    if armed then
        local quality = ITEM_QUALITY_COLORS[armed.quality or 1] or ITEM_QUALITY_COLORS[1]
        name_label:SetText(armed.name or '')
        name_label:SetTextColor(quality.r, quality.g, quality.b)
        detail_label:SetText(describe(armed))
    elseif selected_record() then
        name_label:SetText('Row selected')
        name_label:SetTextColor(aux.color.label.enabled())
        detail_label:SetText(aux.color.label.disabled('Click it again to hand the bar back'))
    else
        name_label:SetText(queue_length > 0 and 'Reading the queue...' or 'Nothing to buy')
        name_label:SetTextColor(aux.color.label.enabled())
        detail_label:SetText(aux.color.label.disabled(queue_length > 0
            and 'The cheapest result is being read'
            or (current_search().active and 'Searching...' or 'Nothing in these results can be bought')))
    end

    queue_label:SetText(queue_length > 0
        and aux.color.label.disabled(queue_length .. (queue_length == 1 and ' item' or ' items') .. ' · ' .. money.to_string(queue_total, true) .. ' in all')
        or '')

    local label, enabled = button_state()
    -- redrawn only when it changes: a button re-styled every tick can drop a press under way
    if label ~= last_label then
        last_label = label
        buy_button:SetText(label)
    end
    if enabled ~= last_enabled then
        last_enabled = enabled
        if enabled then
            buy_button:Enable()
            gui.set_primary(buy_button)
        else
            buy_button:Disable()
            gui.set_default(buy_button)
            -- set_primary leaves the label bold; put it back (as the Sniper's Start button does)
            local _, size = buy_button:GetFontString():GetFont()
            buy_button:GetFontString():SetFont(gui.font, size and size > 0 and size or gui.font_size.medium)
        end
    end

    local key = binding_text()
    hint_label:SetText(key
        and aux.color.label.enabled(key) .. aux.color.label.disabled(' · or scroll here')
        or aux.color.label.disabled('No key bound · Key Bindings → auxForever'))
end

holder:SetScript('OnUpdate', function()
    if not on() then
        if panel:IsShown() then
            panel:Hide()
            if ours then
                ours, armed = nil, nil
                buy_bar.clear()
            end
            want, want_hold = nil, nil
        end
        return
    end
    if not panel:IsShown() then
        panel:Show()
    end
    if GetTime() >= next_tick then
        next_tick = GetTime() + QUEUE_INTERVAL
        -- worked out each time rather than once: the window can be moved, resized or scaled at any
        -- moment, and which side of it has room changes with that. Two getters and a SetPoint.
        place()
        arm()
        draw()
    end
end)

-- The moment a purchase settles, the next result is armed rather than waiting out the tick: gear
-- goes through place_bid (aux.on_bid_idle), trade goods answer with their own events.
function aux.event.AUX_LOADED()
    local function poke()
        next_tick = 0
    end
    aux.on_bid_idle(poke)
    aux.event_listener('COMMODITY_PURCHASE_SUCCEEDED', poke)
    aux.event_listener('COMMODITY_PURCHASE_FAILED', poke)
end

-- a new search, or the auction house closing, makes every read worthless
function M.rapid_forget()
    loaded, futile, skipped = {}, {}, {}
    armed, want, want_hold, just_read = nil, nil, nil, nil
    next_tick = 0
end
