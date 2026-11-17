select(2, ...) 'aux.tabs.search'

local auction_listing = require 'aux.gui.auction_listing'
local aux = require 'aux'
local info = require 'aux.util.info'
local filter_util = require 'aux.util.filter'
local scan = require 'aux.core.scan'
local buy_bar = require 'aux.gui.buy_bar'
local money = require 'aux.util.money'
local gui = require 'aux.gui'

StaticPopupDialogs.AUX_SCAN_ALERT = {
    text = 'One of your alert queries matched!',
    button1 = 'Ok',
    showAlert = 1,
    timeout = 0,
    hideOnEscape = 1,
    preferredIndex = STATICPOPUP_NUMDIALOGS,
}

-- 1234567 as "1,234,567"
local function thousands(n)
    local text = tostring(n)
    while true do
        local done
        text, done = gsub(text, '^(%d+)(%d%d%d)', '%1,%2')
        if done == 0 then return text end
    end
end

-- how many auctions a search keeps for its table. More than this and every redraw (sorting and
-- grouping them) costs the player frame rate; the rest is still read for prices.
M.TABLE_LIMIT = 2000

-- 0.8.2.1 build 6 (outside review S-08, Tyler, 2026-11-11: "yes"). On Forever one popular piece of
-- gear can be hundreds of auctions at one price (Linen Belt: 585 sellers at 1s), each a record, all
-- shown as one row. A Full search for linen filled the table's 2,000 with a few such items and the
-- items read later did not show. A search now keeps at most FOLD_KEEP real auctions per price row
-- and only counts the rest ("folded"): the row still says how many are for sale and from how many
-- sellers, and buying it buys one of the kept auctions, at the price shown. When a row is down to
-- fewer than REFILL_AT kept auctions while more are counted, its item is read again.
-- Trade goods come one record per price already and are never folded; nor are auctions without a
-- buyout (each keeps its row), the player's own, or ones the player bid on.
M.FOLD_KEEP = 20
M.REFILL_AT = 5

local function foldable(record)
    return not (record.commodity or record.fast or record.own or record.high_bidder or record.contains_own)
        and (record.buyout_price or 0) > 0
end

local function fold_key(record)
    return record.item_search_key and scan.item_key_string(record.item_search_key) or record.item_key or ''
end

-- what a search holds: records (the table's), kept[row] (the real auctions kept for each price
-- row), folded[row][item key] (the auctions only counted: how many, units, sellers, price),
-- folded_seen (their signatures, so Live does not take them for new auctions) and not_shown (units
-- past the table's limit). A Live round fills one of its own and takes it over when it ends.
function M.new_collection()
    return {records = {}, kept = {}, folded = {}, folded_seen = {}}
end

function M.reset_collection(c)
    c.records, c.kept, c.folded, c.folded_seen, c.not_shown = {}, {}, {}, {}, nil
end

local function fold(c, record)
    local row, key = record.fold_group, fold_key(record)
    c.folded[row] = c.folded[row] or {}
    local entry = c.folded[row][key]
    if not entry then
        -- named: auctions per named seller; ids: the auctions counted, to take one off when bought
        entry = {auctions = 0, units = 0, unnamed = 0, named = {}, ids = {}, name = record.name, unit_price = record.unit_buyout_price}
        c.folded[row][key] = entry
    end
    local auctions = record.auction_count or 1
    entry.auctions = entry.auctions + auctions
    entry.units = entry.units + auctions * (record.count or 1)
    if record.owner then
        entry.named[record.owner] = (entry.named[record.owner] or 0) + 1
    else
        entry.unnamed = entry.unnamed + max(1, record.seller_count or 1)
    end
    if record.auction_id then
        entry.ids[record.auction_id] = {auctions, record.owner or max(1, record.seller_count or 1)}
    end
    if record.sniping_signature then
        c.folded_seen[record.sniping_signature] = true
    end
end

local function not_shown(c, record)
    c.not_shown = (c.not_shown or 0) + (record.count or 1) * (record.auction_count or 1)
end

-- one auction read by a search: into the table, counted on its row, or past the table's limit.
-- validator: the search's own check, used again when the row's item is read again (refill)
function M.collect(c, record, validator)
    if not foldable(record) then
        if #c.records < TABLE_LIMIT then
            tinsert(c.records, record)
        else
            not_shown(c, record)
        end
        return
    end
    local row = auction_listing.price_group(record)
    record.fold_group, record.refill_validator = row, validator
    local kept = c.kept[row]
    if kept and (#kept >= FOLD_KEEP or #c.records >= TABLE_LIMIT) then
        -- the row is shown already: count this auction. The row offers the lowest starting bid
        -- of its auctions, so an auction with a lower bid than the highest kept one takes its place.
        local high, high_i
        for i, r in ipairs(kept) do
            if not high or (r.bid_price or 0) > (high.bid_price or 0) then
                high, high_i = r, i
            end
        end
        local index = high and (record.bid_price or 0) < (high.bid_price or 0) and aux.key(c.records, high)
        if index then
            c.records[index], kept[high_i] = record, record
            fold(c, high)
        else
            fold(c, record)
        end
    elseif #c.records < TABLE_LIMIT then
        c.kept[row] = kept or {}
        tinsert(c.kept[row], record)
        tinsert(c.records, record)
    else
        not_shown(c, record)
    end
end

-- the units a search counted without keeping, on rows the table still shows
function M.folded_units(c)
    local units = 0
    for row, entries in pairs(c.folded or empty) do
        if c.kept[row] and #c.kept[row] > 0 then
            for _, entry in pairs(entries) do
                units = units + entry.units
            end
        end
    end
    return units
end

-- the Clear button
function M.clear_results(search)
    while tremove(search.records) do end
    aux.wipe(search.kept)
    aux.wipe(search.folded)
    aux.wipe(search.folded_seen)
    search.not_shown = nil
    search.table:SetDatabase()
end

NORMAL_MODE, LIVE_MODE = {}, {}

mode = nil

bid_enabled = false
buyout_enabled = false

function aux.event.AUX_LOADED()
    new_search(nil, NORMAL_MODE)
end

function update_mode(mode)
    _M.mode = mode
    update_live_button(true)
end

do
    local searches = {}
    local search_index = 1

    function M.clear_selection()
        if searches[search_index] then
            searches[search_index].table:SetSelectedRecord()
        end
    end

    function current_search()
        return searches[search_index]
    end

    -- auxForever: /aux memory detail
    function M.memory_counts()
        local records = 0
        for _, search in ipairs(searches) do
            records = records + #(search.records or empty)
        end
        return #searches, records
    end

    function M.set_nav_enabled(button, enabled)
        if enabled then
            button:Enable()
            button:SetAlpha(1)
        else
            button:Disable()
            button:SetAlpha(.35)
        end
    end

    function update_search(index)
        searches[search_index].table:Hide()
        searches[search_index].table:SetSelectedRecord()

        search_index = index

        searches[search_index].table:Show()

        search_box:SetText(searches[search_index].filter_string or '')
        -- auxForever: the arrows stay in place and fade when there is nowhere to go, so the row
        -- of buttons never shifts
        set_nav_enabled(previous_button, search_index > 1)
        set_nav_enabled(next_button, search_index < #searches)
        mode_button:SetPoint('LEFT', next_button, 'RIGHT', 4, 0)
        update_mode(searches[search_index].mode)
        update_start_stop()
        update_continuation()
        update_done()
    end

    function new_search(filter_string, mode)
        while #searches > search_index do
            tremove(searches)
        end
        local search = new_collection()
        search.filter_string, search.mode = filter_string, mode
        tinsert(searches, search)
        if #searches > 5 then
            tremove(searches, 1)
            tinsert(tables, tremove(tables, 1))
            search_index = 4
        end

        aux.status_bar:update_status(1, 1)

        search.table = tables[#searches]
        search.table:SetSort(1, 2, 3, 4, 5, 6, 7, 8, 9)
        search.table:Reset()
        search.table:SetDatabase(search.records, search.folded)

        update_search(#searches)
    end

    function previous_search()
        search_box:ClearFocus()
        update_search(search_index - 1)
        set_subtab(RESULTS)
    end

    function next_search()
        search_box:ClearFocus()
        update_search(search_index + 1)
        set_subtab(RESULTS)
    end
end

function update_continuation()
    local search = current_search()
    full_button:ClearAllPoints()
    if search.continuation then
        resume_button:SetText(search.mode == LIVE_MODE and 'Resume live' or 'Resume')
        resume_button:SetWidth(search.mode == LIVE_MODE and 100 or 80)
        resume_button:Show()
        full_button:SetPoint('RIGHT', resume_button, 'LEFT', -4, 0)
    else
        resume_button:Hide()
        full_button:SetPoint('RIGHT', start_button, 'LEFT', -4, 0)
    end
    search_box:SetPoint('RIGHT', fast_button, 'LEFT', -4, 0)
end

-- auxForever: the Fast / Full switch next to Search; the choice is kept
function M.set_full_search(full)
    aux.account_data.full_search = full and true or false
    update_fast_switch()
end

function M.update_fast_switch()
    gui.style_choice(fast_button, not aux.account_data.full_search)
    gui.style_choice(full_button, aux.account_data.full_search)
end

function discard_continuation()
    scan.abort()
    current_search().continuation = nil
    update_continuation()
end

function update_start_stop()
    if current_search().active then
        stop_button:Show()
        start_button:Hide()
    else
        start_button:Show()
        stop_button:Hide()
    end
end

-- auxForever: Live mode (aux's real time mode). Forever has no result pages to watch, so a round
-- reads the whole search again and replaces the table with what is listed now. After a round the
-- Live button counts down LIVE_INTERVAL seconds to the next one ("Live 4s"), and says "Updating"
-- during a round. Pause stops it until Resume; leaving the Search tab holds it and coming back
-- carries on. A new auction that matches one of your alert favorites brings up the alert.
LIVE_INTERVAL = 5

live_search = nil

local function reselect(search, signature)
    if not signature then return end
    for _, record in ipairs(search.records) do
        if record.search_signature == signature then
            search.table:SetSelectedRecord(record)
            return
        end
    end
    search.table:SetSelectedRecord()
end

function start_live_scan(query, search)
    search = search or current_search()
    search.live_query = query
    search.live_next = nil
    live_search = search
    update_live_button(true)

    local seen = {}
    for _, record in pairs(search.records) do
        seen[record.sniping_signature] = true
    end
    for signature in pairs(search.folded_seen or empty) do
        seen[signature] = true
    end

    -- the round's own records and counts (S-08), taken over when it ends
    local round = new_collection()
    local alerted
    scan.start {
        type = 'list',
        sort_type = search.sort_type,
        queries = { query },
        fast = search.fast,
        open = search.open,
        on_scan_start = function()
            aux.status_bar:update_status(.9999, .9999)
        end,
        on_auction = function(auction_record)
            if not seen[auction_record.sniping_signature] and (search.alert_validator or pass)(auction_record) and not alerted then
                alerted = true
                aux.show_popup('AUX_SCAN_ALERT')
                if type(FlashClientIcon) == 'function' then
                    FlashClientIcon()
                end
            end
            collect(round, auction_record, query.validator)
        end,
        on_complete = function(result)
            aux.status_bar:update_status(1, 1)
            if result and (result.no_list or result.partial_list) then
                -- 0.8.2.1 (outside review, R-02): a round that got no item list, or part of one,
                -- keeps the table as it is (it emptied it, or dropped the items past the cut); the
                -- next round reads again
            elseif round.not_shown then
                -- the table keeps what it has; said next to the results and once in chat, without
                -- the popup that came up again at every round (build 5)
                if not search.live_too_many then
                    aux.print(format('Live: this search finds more than %s auctions, too many to keep updated. Narrow the search.', thousands(TABLE_LIMIT)))
                end
                search.live_too_many = true
            else
                search.live_too_many = nil
                local selected = search.table.selected and search.table.selected.search_signature
                search.records, search.kept, search.folded, search.folded_seen = round.records, round.kept, round.folded, round.folded_seen
                search.not_shown = nil
                search.table:SetDatabase(search.records, search.folded)
                if current_search() == search then
                    reselect(search, selected)
                end
            end
            search.live_round = (search.live_round or 0) + 1
            -- "updated just now" only for a round that brought the list
            if not (result and (result.no_list or result.partial_list)) then
                search.completed_at = time()
            end
            search.live_next = GetTime() + LIVE_INTERVAL
            update_live_button(true)
        end,
        on_abort = function()
            aux.status_bar:update_status(1, 1)
            search.live_next = nil
            -- stopped on purpose by the code below: a restart, leaving the tab, or Live turned off
            if search.live_restarting or search.live_held or search.live_stopping then
                return
            end
            pause_live(search)
        end,
    }
end

function pause_live(search)
    search.live_next = nil
    search.active = false
    search.continuation = true
    if current_search() == search then
        update_continuation()
    end
    update_start_stop()
    update_live_button(true)
end

-- a round right now (an item was opened, so its auctions show without waiting for the countdown)
function restart_live(search)
    search.live_restarting = true
    if scan.is_scanning() then
        scan.abort()
    end
    search.live_restarting = nil
    start_live_scan(search.live_query, search)
end

-- Live turned off: the search keeps its last results
function stop_live(search)
    search.live_stopping = true
    if scan.is_scanning() and live_search == search then
        scan.abort()
    end
    search.live_stopping = nil
    search.live_next = nil
    search.active = false
    search.continuation = nil
    search.mode = NORMAL_MODE
    search.complete = true
    if live_search == search then
        live_search = nil
    end
    update_continuation()
    update_start_stop()
    update_done()
    update_live_button(true)
end

-- the Pause button
function M.pause()
    local search = current_search()
    if search.mode == LIVE_MODE and search.active then
        if scan.is_scanning() then
            scan.abort()
        end
        if search.active then
            pause_live(search)
        end
    else
        scan.abort()
    end
end

-- the Live button: turning it on runs the search in the box live right away
function M.toggle_live()
    local search = current_search()
    if _M.mode == LIVE_MODE then
        update_mode(NORMAL_MODE)
        if search.mode == LIVE_MODE and (search.active or search.continuation) then
            stop_live(search)
        end
    else
        update_mode(LIVE_MODE)
        if aux.trim(search_box:GetText()) ~= '' and not search.active then
            execute(nil, false, LIVE_MODE)
        end
    end
end

-- leaving the Search tab holds a live search; coming back carries on with a round
function M.hold_live()
    local search = live_search
    if search and search.active and search.mode == LIVE_MODE then
        search.live_held = true
        if scan.is_scanning() then
            scan.abort()
        end
        search.live_next = nil
    end
end

function M.resume_held_live()
    local search = live_search
    if search and search.live_held then
        search.live_held = nil
        if search.active then
            search.live_next = GetTime()
        end
    end
end

-- 'updating', 'waiting' (and the seconds left) or 'paused' for a live search, nil otherwise
function M.live_status(search)
    if not search or search.mode ~= LIVE_MODE then
        return
    elseif search.active then
        if search.live_next then
            return 'waiting', max(0, ceil(search.live_next - GetTime()))
        end
        return 'updating'
    elseif search.continuation then
        return 'paused'
    end
end

do
    local last_text, last_look, next_update
    function M.update_live_button(force)
        if not force and GetTime() < (next_update or 0) then return end
        next_update = GetTime() + .2
        local status, seconds = live_status(current_search())
        local text, look = 'Live', _M.mode == LIVE_MODE and 'on' or 'off'
        if status == 'updating' then
            text, look = 'Updating', 'on'
        elseif status == 'waiting' then
            text, look = 'Live ' .. seconds .. 's', 'on'
        elseif status == 'paused' then
            text, look = 'Paused', 'paused'
        end
        if force or text ~= last_text then
            last_text = text
            mode_button:SetText(text)
        end
        if force or look ~= last_look then
            last_look = look
            -- auxForever (0.6): on is lit like a selected tab, paused like a chosen option
            if look == 'on' then
                gui.set_selected(mode_button, true)
            elseif look == 'paused' then
                gui.style_choice(mode_button, true)
            else
                gui.set_default(mode_button)
            end
        end
    end
end

-- every frame while the Search tab is shown: start the next live round when its countdown ends
local held_for_buying = false

function M.update_live()
    local search = live_search
    -- auxForever: a purchase talks to the auction house too. A live round during a trade good's
    -- price quote ended it with "Internal auction error" (Tyler, 0.4.1), so rounds wait while the
    -- buy bar is buying, and a round under way is held and carries on afterwards.
    local buying = buy_bar.busy() or aux.bid_in_progress()
    if buying and not held_for_buying and search and search.active and search.mode == LIVE_MODE and not search.live_held and scan.is_scanning() then
        held_for_buying = true
        hold_live()
    elseif not buying and held_for_buying then
        held_for_buying = false
        resume_held_live()
    end
    if search and search.active and search.mode == LIVE_MODE and not search.live_held then
        if not search.live_next and not scan.is_scanning() then
            -- "Updating" with no round running (it ended without telling): carry on with a round
            search.live_next = GetTime() + 1
        elseif search.live_next and GetTime() >= search.live_next and not scan.is_scanning() and not buying then
            start_live_scan(search.live_query, search)
        end
    end
    update_live_button()
end

-- auxForever: the status bar turns gold while the results of a finished search are shown, and goes
-- back to normal on a new search, another search in the history, Clear, another sub tab or tab.
function M.update_done()
    local search = current_search()
    aux.status_bar:set_done(frame:IsShown() and frame.results:IsShown() and search and search.complete)
end

-- auxForever: "Search Results 37" on the sub tab, and next to the sub tabs what the results hold:
-- "37 items, 403 for sale, searched 2m ago" for a search over many items, or for one item
-- "11 price levels, 6,180 for sale". The first number is the one on the sub tab.
-- the rows the table shows for these records: one per price (0.8, review H-004, finding 7)
function count_price_levels(records)
    local seen, n = {}, 0
    for _, record in ipairs(records) do
        local group = auction_listing.price_group(record) or record
        if not seen[group] then
            seen[group] = true
            n = n + 1
        end
    end
    return n
end

-- the number on the Search Results sub tab: items, or price levels when all results are one item
function M.results_count(search)
    if not search or not search.records then
        return 0
    end
    local items, item_count, levels = {}, 0, count_price_levels(search.records)
    for _, record in ipairs(search.records) do
        local key = record.price_key or record.item_key or record.item_id or record
        if not items[key] then
            items[key] = true
            item_count = item_count + 1
        end
    end
    return item_count > 1 and item_count or levels
end

function M.results_summary(search)
    if not search or not search.records or #search.records == 0 then
        return nil
    end
    local units, items, item_count = 0, {}, 0
    for _, record in ipairs(search.records) do
        units = units + (record.count or 1) * (record.auction_count or 1)
        local key = record.price_key or record.item_key or record.item_id or record
        if not items[key] then
            items[key] = true
            item_count = item_count + 1
        end
    end
    -- the auctions counted on a row without being kept (S-08)
    units = units + folded_units(search)
    local text
    if item_count > 1 then
        text = thousands(item_count) .. ' items, '
    else
        local levels = count_price_levels(search.records)
        text = thousands(levels) .. (levels == 1 and ' price level, ' or ' price levels, ')
    end
    text = text .. thousands(units) .. ' for sale'
    if search.not_shown then
        text = text .. aux.color.red(', table full: ' .. thousands(search.not_shown) .. ' more not shown')
    elseif search.live_too_many then
        text = text .. aux.color.red(', too many for Live: narrow the search')
    end
    if search.fast then
        text = text .. ', fast'
    elseif search.full_reason then
        text = text .. ', full (uses ' .. search.full_reason .. ')'
    end
    local live, seconds = live_status(search)
    if live == 'waiting' then
        return text .. ', live: updated ' .. (search.completed_at and time_ago(search.completed_at) or 'just now') .. ', next in ' .. seconds .. 's'
    elseif live == 'updating' then
        return text .. ', live: updating'
    elseif live == 'paused' then
        return text .. ', live: paused'
    elseif search.active then
        return text .. ', still searching'
    elseif search.complete and search.completed_at then
        return text .. ', searched ' .. time_ago(search.completed_at) .. (search.incomplete and aux.color.red(', some items missing: search again') or '')
    end
    return text
end

do
    local last_count, last_summary, last_recipe, next_update = nil, nil, nil, 0
    -- every half second: cheap, and only touches the text when it changed
    function M.update_results_summary(force)
        if not force and GetTime() < next_update then return end
        next_update = GetTime() + .5
        local search = current_search()
        local count = results_count(search)
        if count ~= last_count then
            last_count = count
            search_results_button:SetText(count > 0 and 'Search Results  ' .. aux.color.accent.background(thousands(count)) or 'Search Results')
        end
        local summary = frame.results:IsShown() and results_summary(search) or ''
        if summary ~= last_summary then
            last_summary = summary
            results_summary_label:SetText(summary)
        end
        -- a recipe search's cost, in the bottom bar
        local recipe = search and search.recipe and search.records and #search.records > 0 and recipe_summary(search) or ''
        if recipe ~= last_recipe then
            last_recipe = recipe
            recipe_label:SetText(recipe)
        end
    end
end

function start_search(queries, continuation)
    local current_query, current_page, total_queries, start_query, start_page
    local alerted, validator

    local search = current_search()
    search.next_redraw, search.redraw_due = nil, nil
    search.complete = false
    search.incomplete = nil
    search.not_shown = nil
    update_done()

    total_queries = #queries

    if continuation then
        start_query, start_page = unpack(continuation)
        for i = 1, start_query - 1 do
            tremove(queries, 1)
        end
        queries[1].blizzard_query.first_page = (queries[1].blizzard_query.first_page or 0) + start_page - 1
        search.table:SetSelectedRecord()
    else
        start_query, start_page = 1, 1
    end


    scan.start {
        type = 'list',
        sort_type = search.sort_type,
        queries = queries,
        fast = search.fast,
        open = search.open,
        alert_validator = search.alert_validator,
        on_scan_start = function()
            aux.status_bar:update_status(0, 0)
        end,
        on_page_loaded = function(_, total_scan_pages)
            current_page = current_page + 1
            total_scan_pages = total_scan_pages + (start_page - 1)
            total_scan_pages = max(total_scan_pages, 1)
            current_page = min(current_page, total_scan_pages)
            aux.status_bar:update_status(current_page / total_scan_pages, current_query / #queries)
        end,
        -- 0.8.2.1 (outside review, R-12): the table is drawn again at most four times a second while
        -- the search runs, and once when it ends. It was after every item read, and each time sorts
        -- every row: a search of a few hundred items sorted up to 2,000 rows a few hundred times.
        on_page_scanned = function()
            if GetTime() >= (search.next_redraw or 0) then
                search.next_redraw = GetTime() + .25
                search.redraw_due = nil
                search.table:SetDatabase()
            else
                search.redraw_due = true
            end
        end,
        on_start_query = function(index)
            current_query = current_query and current_query + 1 or start_query
            current_page = current_page and 0 or start_page - 1
            -- the search's own check, kept with each row to read its item again (S-08)
            validator = queries[index] and queries[index].validator
        end,
        on_auction = function(auction_record)
            -- once per search, as in Live mode (it was shown again for every matching auction)
            if not alerted and (search.alert_validator or pass)(auction_record) then
                alerted = true
                aux.show_popup('AUX_SCAN_ALERT')
            end
            -- 0.8.2.1 build 5 (Tyler, build 4 test, on the "Table full!" popup of a Full search for
            -- linen: "I had to close this error"): past the table's limit nothing pops up; the line
            -- next to the results says how much is not shown, and chat says it once at the end
            -- 0.8.2.1 build 6 (S-08): gear at one price keeps about 20 auctions and counts the rest
            collect(search, auction_record, validator)
        end,
        on_complete = function(result)
            aux.status_bar:update_status(1, 1)
            search.complete = true
            search.completed_at = time()
            -- 0.8.2.1 (outside review, R-02): said next to the results too, not only in chat
            search.incomplete = result and (result.no_list or result.partial_list) and true or nil
            if search.not_shown then
                aux.print(format('The results table is full (%s auctions). %s more for sale were read for prices but are not shown: narrow the search to see them.',
                    thousands(TABLE_LIMIT), thousands(search.not_shown)))
            end
            if search.redraw_due then
                search.redraw_due = nil
                search.table:SetDatabase()
            end
            update_done()
            remember_search_result(search.filter_string, search.records)

            if current_search() == search and frame.results:IsVisible() and #search.records == 0 then
                set_subtab(SAVED)
            end

            search.active = false
            update_start_stop()

            -- fast mode: an item clicked while the list was loading, or the only item found
            if search.fast then
                local pending = search.pending_open
                search.pending_open = nil
                if not pending and #search.records == 1 and search.records[1].fast then
                    pending = search.records[1]
                end
                if pending and current_search() == search and search.table:ContainsRecord(pending) then
                    open_item(search, pending)
                end
            end
        end,
        on_abort = function()
            aux.status_bar:update_status(1, 1)
            if search.redraw_due then
                search.redraw_due = nil
                search.table:SetDatabase()
            end

            if current_query then
                search.continuation = { current_query, current_page + 1 }
            else
                search.continuation = { start_query, start_page }
            end
            if current_search() == search then
                update_continuation()
            end

            search.active = false
            update_start_stop()
        end,
    }
end

-- auxForever: fast mode reads only the item list (each item once, with its lowest price). A search
-- for one exact item, or one using a condition the list does not have (seller, time left, bid),
-- reads every auction as before; so does every search when Full is chosen. Tooltip text is checked
-- on the list since 0.8.2 (FB-025, util/filter.lua uses_tooltip).
-- Returns whether the search is fast, and why not when a condition is the reason.
function M.fast_choice(queries)
    if aux.account_data.full_search then
        return false
    end
    for _, query in ipairs(queries) do
        if query.full_reason then
            return false, query.full_reason
        elseif query.exact then
            return false
        end
    end
    return true
end

function M.execute(_, resume, mode)
    local mode_given = mode ~= nil

    if resume then
        mode = current_search().mode
    elseif mode == nil then
        mode = _M.mode
    end

    if resume then
        search_box:SetText(current_search().filter_string)
    end
    local filter_string = search_box:GetText()
    -- auxForever: an empty search bar listed the whole auction house up to the table's limit of
    -- 2,000 rows, with a "Table full" popup (Tyler pressed Search by accident, 0.4.1)
    if aux.trim(filter_string) == '' then
        aux.print('Type something to search for.')
        return
    end

    -- auxForever: a new search of any kind ends Live (Tyler, 0.4.1). A saved or recipe search
    -- started while Live was on was refused as a multi-query: the search bar showed the new search
    -- while Live kept updating the old one. Only the Live button itself starts a live search.
    if not resume and not mode_given and mode == LIVE_MODE and current_search() and filter_string ~= current_search().filter_string then
        mode = NORMAL_MODE
        update_mode(NORMAL_MODE)
    end

    local queries, error = filter_util.queries(filter_string)
    if not queries then
        aux.print('Invalid filter:', error)
        return
    elseif mode == LIVE_MODE then
        if #queries > 1 then
            aux.print('Error: The real time mode does not support multi-queries')
            return
        end
    end

    local fast, full_reason = fast_choice(queries)

    if resume and current_search().fast then
        -- a fast list is quick to read again from the start
        resume = false
        local search = current_search()
        reset_collection(search)
        search.table:Reset()
        search.table:SetDatabase(search.records, search.folded)
    elseif resume then
        current_search().table:SetSelectedRecord()
    end
    if not resume then
        -- a recipe search: started from the profession window, or run again from a saved one
        local recipe = take_pending_recipe() or saved_recipe(filter_string)
        local prettified = aux.join(aux.map(aux.copy(queries), function(filter) return filter.prettified end), ';')
        if filter_string ~= current_search().filter_string then
            if current_search().filter_string then
                new_search(filter_string, mode)
            else
                current_search().filter_string = filter_string
            end
            new_recent_search(filter_string, prettified, recipe)
        else
            if recipe then
                new_recent_search(filter_string, prettified, recipe)
            end
            local search = current_search()
            reset_collection(search)
            search.table:Reset()
            search.table:SetDatabase(search.records, search.folded)
        end
        local search = current_search()
        search.mode = mode
        search.fast, search.full_reason = fast, full_reason
        search.open, search.pending_open = {}, nil
        search.recipe = recipe
        if mode ~= LIVE_MODE then
            search.sort_type = 'unitprice'
        end
        search.alert_validator = get_alert_validator()
    end

    local continuation = resume and current_search().continuation
    local search = current_search()
    if live_search and live_search ~= search and live_search.active then
        -- one live search at a time: the old one stops where it is
        stop_live(live_search)
    end
    search.live_stopping = true
    discard_continuation()
    search.live_stopping = nil
    current_search().active = true
    update_start_stop()
    search_box:ClearFocus()
    set_subtab(RESULTS)
    if mode == LIVE_MODE then
        start_live_scan(queries[1])
    else
        start_search(queries, continuation)
    end
end

-- Forever: every record carries its auction ID, so the selected auction can be bought or bid on
-- right away instead of first being found again by a scan as in Classic aux.
-- Item rows are buckets of identical auctions priced per item: Buyout buys one, like buying one
-- single-item auction in Classic. Both are bought from the buy bar under the results (gui/buy_bar.lua).
do
    local checked
    local remove_record

    local function failure(search, record)
        return function(error)
            if error == 'timeout' then
                buy_bar.show_message('No answer from the auction house yet', 'It may still go through: check your mail before buying again', aux.color.red)
            elseif error == Enum.AuctionHouseError.ItemNotFound or error == Enum.AuctionHouseError.ItemNotAvailable then
                remove_record(search, record)
            end
        end
    end

    -- 0.8.2.1 build 6 (S-08): what was just read of one item takes the place of its auctions in the
    -- table and of its counts
    local function replace_key(search, key, fresh)
        local key_string = scan.item_key_string(key)
        for i = #search.records, 1, -1 do
            local record = search.records[i]
            if not record.commodity and record.item_search_key and scan.item_key_string(record.item_search_key) == key_string then
                tremove(search.records, i)
                local kept = record.fold_group and search.kept[record.fold_group]
                local j = kept and aux.key(kept, record)
                if j then tremove(kept, j) end
            end
        end
        for row, entries in pairs(search.folded) do
            entries[key_string] = nil
            if not next(entries) then
                search.folded[row] = nil
            end
        end
        for _, record in ipairs(fresh) do
            collect(search, record, record.refill_validator)
        end
        search.table:SetDatabase()
        -- the row ran out of kept auctions before this read came back (remove_record): select it again
        local row = search.reselect_row
        search.reselect_row = nil
        if row and not search.table.selected and current_search() == search then
            for _, info_row in ipairs(search.table.rowInfo) do
                for _, child in ipairs(info_row.children) do
                    if child.record.price_group == row then
                        search.table:SetSelectedRecord(child.record)
                        return
                    end
                end
            end
        end
    end

    -- A row of folded auctions is down to its last few kept ones: read its item again so the row
    -- keeps real auctions to buy while the count says more are listed. It waits for a search under
    -- way (a new scan would stop it) and for a trade good's quote (a request in between ends it with
    -- "Internal auction error", Tyler, 0.4.1), not for gear purchases: a player buying one after
    -- another always has one on its way, and the row would run out first. aux already reads an item
    -- again after buying from it (sync_bucket). Live rounds read everything again anyway.
    local function refill(search, record)
        local row, key = record.fold_group, record.item_search_key
        search.refilling = search.refilling or {}
        if not key or search.refilling[row] or (search.mode == LIVE_MODE and search.active) then
            return
        end
        search.refilling[row] = true
        local records, validator = search.records, record.refill_validator
        -- only for the search on screen: a read started after the player left the Search tab would
        -- come between another tab's own reads (found by a test that went on to the Sniper)
        local function wanted()
            return search.records == records and current_search() == search and frame:IsShown()
        end
        aux.coro_thread(function()
            local t0 = GetTime()
            while wanted() and (scan.is_scanning() or buy_bar.busy()) and GetTime() - t0 < 30 do
                aux.coro_wait()
            end
            if not wanted() or scan.is_scanning() or buy_bar.busy() then
                search.refilling[row] = nil
                return
            end
            local fresh = {}
            scan.start{
                type = 'list',
                quiet = true,
                no_view = true, -- one version of an item is not a look at the whole item
                queries = {{item_keys = {key}, validator = validator}},
                on_auction = function(auction_record)
                    auction_record.refill_validator = validator
                    tinsert(fresh, auction_record)
                end,
                on_complete = function(result)
                    search.refilling[row] = nil
                    if wanted() and not (result and result.unread) then
                        replace_key(search, key, fresh)
                    end
                end,
                on_abort = function()
                    search.refilling[row] = nil
                end,
            }
        end)
    end

    -- an auction left the table (bought, or gone from the auction house)
    function remove_record(search, record)
        local row = record.fold_group
        if row and not aux.key(search.records, record) then
            -- bought while its item was read again (refill): what was read may hold the same
            -- auction, kept or counted
            for _, other in ipairs(search.records) do
                if other ~= record and other.auction_id == record.auction_id and other.fold_group == row then
                    return remove_record(search, other)
                end
            end
            local entry = search.folded[row] and search.folded[row][fold_key(record)]
            local counted = entry and record.auction_id and entry.ids[record.auction_id]
            if counted then
                entry.ids[record.auction_id] = nil
                entry.auctions = max(0, entry.auctions - counted[1])
                entry.units = max(0, entry.units - counted[1] * (record.count or 1))
                local seller = counted[2]
                if type(seller) == 'string' then
                    entry.named[seller] = (entry.named[seller] or 1) - 1
                    if entry.named[seller] <= 0 then entry.named[seller] = nil end
                else
                    entry.unnamed = max(0, entry.unnamed - seller)
                end
                search.table:SetDatabase()
            end
            return
        end
        local kept = row and search.kept[row]
        local i = kept and aux.key(kept, record)
        if i then
            tremove(kept, i)
        end
        if i and #kept == 0 and search.folded[row] and search.table.selected == record then
            -- the row's last kept auction, with more counted: the row is gone until its item is
            -- read again. Nothing else is selected meanwhile (the next row is another price), and
            -- the row is selected again when the read comes back (replace_key).
            search.reselect_row = row
            search.table:SetSelectedRecord()
            checked = nil
            buy_bar.show_note(record.name, 'Reading more of its auctions...')
        end
        search.table:RemoveAuctionRecord(record)
        if i and #kept < REFILL_AT and search.folded[row] then
            refill(search, record)
        end
    end

    local function same_bucket(result, record)
        return result.itemLink == record.link
            and (result.buyoutAmount or 0) == record.raw_buyout
            and (result.bidAmount or 0) == record.raw_bid
            and not (#result.owners == 1 and result.containsOwnerItem)
    end

    local function find_bucket(record)
        local key = record.item_search_key
        for i = 1, C_AuctionHouse.GetNumItemSearchResults(key) do
            local result = C_AuctionHouse.GetItemSearchResultInfo(key, i)
            if result and same_bucket(result, record) then
                return result
            end
        end
    end

    -- One auction of a bucket was bought (or bid on). The bucket carries on under a new auction
    -- ID, so re-read the item's results to pick it up before the next purchase.
    local function sync_bucket(search, record)
        record.auction_count = record.auction_count - 1
        if record.auction_count <= 0 then
            remove_record(search, record)
            return
        end
        record.syncing = true
        search.table:SetDatabase()
        local key, old_id = record.item_search_key, record.auction_id
        aux.coro_thread(function()
            local updated
            local listener_id = aux.event_listener('ITEM_SEARCH_RESULTS_UPDATED', function(item_key)
                if item_key and item_key.itemID == key.itemID then
                    updated = true
                end
            end)
            local t0 = GetTime()
            while not updated and GetTime() - t0 < 1.5 do
                -- the update may already have arrived before this started listening
                local bucket = find_bucket(record)
                if bucket and bucket.auctionID ~= old_id then
                    updated = true
                    break
                end
                aux.coro_wait()
            end
            if not updated then
                -- the client no longer holds this item's results; ask for them again, once any
                -- search running now has ended (it used to be stopped, so a search started right
                -- after buying was cut off; found with the slow test auction house). The row stays
                -- busy meanwhile, so it cannot be bought at the old auction ID.
                t0 = GetTime()
                while scan.is_scanning() and GetTime() - t0 < 30 do
                    aux.coro_wait()
                end
                while not C_AuctionHouse.IsThrottledMessageSystemReady() do
                    aux.coro_wait()
                end
                C_AuctionHouse.SendSearchQuery(key, {{sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false}}, true)
                t0 = GetTime()
                while not updated and GetTime() - t0 < 5 do
                    aux.coro_wait()
                end
            end
            aux.kill_listener(listener_id)
            local bucket = find_bucket(record)
            record.syncing = nil
            if bucket and (bucket.auctionID ~= old_id or updated) then
                record.auction_id = bucket.auctionID
                record.auction_count = max(1, bucket.quantity or 1)
                search.table:SetDatabase()
            else
                remove_record(search, record)
            end
        end)
    end

    -- The tiers of a commodity the player can buy, cheapest first
    local function commodity_tiers(search, item_id)
        local tiers = {}
        for _, record in ipairs(search.records) do
            if record.commodity and record.item_id == item_id and not record.own then
                tinsert(tiers, record)
            end
        end
        sort(tiers, function(a, b) return a.commodity_unit_price < b.commodity_unit_price end)
        return tiers
    end

    -- A purchase took the cheapest units first, so update the displayed tiers the same way
    local function consume_commodity(search, item_id, quantity)
        local remaining = quantity
        for _, tier in ipairs(commodity_tiers(search, item_id)) do
            if remaining <= 0 then break end
            local taken = min(remaining, tier.count)
            remaining = remaining - taken
            if taken == tier.count then
                local index = aux.key(search.records, tier)
                if index then tremove(search.records, index) end
            else
                info.set_commodity_count(tier, tier.count - taken)
            end
        end
        search.table:SetDatabase()
    end

    -- Re-read the listings of one commodity (after its price went up), replacing its rows
    local function refresh_commodity(search, item_id)
        local fresh = {}
        scan.start{
            type = 'list',
            queries = {{item_keys = {C_AuctionHouse.MakeItemKey(item_id)}}},
            on_auction = function(record)
                tinsert(fresh, record)
            end,
            on_complete = function()
                for i = #search.records, 1, -1 do
                    if search.records[i].commodity and search.records[i].item_id == item_id then
                        tremove(search.records, i)
                    end
                end
                for _, record in ipairs(fresh) do
                    tinsert(search.records, record)
                end
                search.table:SetDatabase()
            end,
        }
    end

    local function show_commodity(search, record)
        local item_info = info.item(record.item_id)
        buy_bar.show_commodity{
            item_id = record.item_id,
            name = record.name,
            texture = record.texture,
            quality = record.quality,
            max_stack = item_info and item_info.max_stack or 1,
            tiers = function() return commodity_tiers(search, record.item_id) end,
            on_success = function(n) consume_commodity(search, record.item_id, n) end,
            on_refresh = function() refresh_commodity(search, record.item_id) end,
        }
    end

    local function show_item(search, record)
        buy_bar.show_item{
            record = record,
            name = record.name,
            texture = record.texture,
            quality = record.quality,
            own = info.is_player(record.owner) or record.own,
            busy = function()
                return record.syncing or aux.bid_in_progress() or not search.table:ContainsRecord(record)
            end,
            on_buy = function()
                aux.place_bid(record.auction_id, record.buyout_price, function()
                    sync_bucket(search, record)
                end, failure(search, record))
            end,
            on_bid = function()
                aux.place_bid(record.auction_id, record.bid_price, function()
                    if record.auction_count and record.auction_count > 1 then
                        sync_bucket(search, record)
                    elseif record.bid_price < record.buyout_price then
                        info.bid_update(record)
                        search.table:SetDatabase()
                    else
                        remove_record(search, record)
                    end
                end, failure(search, record))
            end,
        }
    end

    function find_auction(record)
        local search = current_search()
        checked = record
        if not search.table:ContainsRecord(record) then
            buy_bar.clear()
        elseif record.fast then
            open_item(search, record)
        elseif record.commodity then
            -- Forever: commodities are bought by quantity, whichever row is selected
            show_commodity(search, record)
        else
            show_item(search, record)
        end
    end

    -- auxForever: fast mode. The rows of an opened item replace its list row and stay expanded;
    -- the cheapest one is selected for the buy bar.
    function replace_item(search, fast_record, loaded)
        for i = #search.records, 1, -1 do
            local record = search.records[i]
            if record.fast and record.item_key == fast_record.item_key then
                tremove(search.records, i)
            end
        end
        local cheapest
        for _, record in ipairs(loaded) do
            -- S-08: an opened item's rows keep about 20 auctions each too
            collect(search, record, fast_record.validator)
            if not record.own and record.buyout_price > 0 and (not cheapest or record.unit_buyout_price < cheapest.unit_buyout_price) then
                cheapest = record
            end
        end
        -- the cheapest may have been counted, not kept: select a kept auction of its row
        if cheapest and not aux.key(search.records, cheapest) then
            local kept = cheapest.fold_group and search.kept[cheapest.fold_group]
            cheapest = kept and kept[1]
        end
        if loaded[1] then
            search.table.expanded[loaded[1].price_key or loaded[1].item_key] = true
        end
        search.table:SetDatabase()
        if aux.account_data.debug_timing and cheapest and ceil(cheapest.unit_buyout_price) ~= ceil(fast_record.unit_buyout_price) then
            aux.print(format('Fast list: %s lowest %s, its auctions: %s', fast_record.name, money.to_string(fast_record.unit_buyout_price, true), money.to_string(cheapest.unit_buyout_price, true)))
        end
        if current_search() ~= search then
            return
        end
        if cheapest then
            search.table:SetSelectedRecord(cheapest)
        else
            search.table:SetSelectedRecord()
            checked = nil
            buy_bar.show_note(fast_record.name, 'Nothing left to buy: it sold or was taken down')
        end
    end

    -- auxForever: fast mode. Clicking an item reads its auctions (about half a second).
    function M.open_item(search, record)
        search.open = search.open or {}
        search.open[record.item_key] = true
        buy_bar.show_note(record.name, 'Reading its auctions...')
        if search.mode == LIVE_MODE and search.active then
            restart_live(search)
            return
        elseif search.active then
            -- the item list is still loading; open it when it is done
            search.pending_open = record
            return
        end
        local loaded = {}
        scan.start{
            type = 'list',
            queries = {{item_keys = {record.browse_key}, validator = record.validator}},
            on_auction = function(auction_record)
                tinsert(loaded, auction_record)
            end,
            on_complete = function()
                replace_item(search, record, loaded)
            end,
        }
    end

    function on_update()
        update_live()
        update_results_summary()
        local selection = current_search().table:GetSelection()
        if selection and selection.record ~= checked then
            find_auction(selection.record)
        elseif not selection and checked then
            checked = nil
            buy_bar.clear()
        end
    end
end
