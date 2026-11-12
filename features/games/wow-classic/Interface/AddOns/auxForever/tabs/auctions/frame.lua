select(2, ...) 'aux.tabs.auctions'

local aux = require 'aux'
local info = require 'aux.util.info'
local money = require 'aux.util.money'
local sort_util = require 'aux.util.sort'
local gui = require 'aux.gui'
local auction_listing = require 'aux.gui.auction_listing'
local search_tab = require 'aux.tabs.search'

-- auxForever (0.4): the Auctions tab from the approved mockup: Check prices and a summary on the
-- left, Cancel undercut on the right, each auction's price against the cheapest other seller.

frame = CreateFrame('Frame', nil, aux.frame)
frame:SetAllPoints(aux.frame.body)
frame:SetScript('OnUpdate', on_update)
frame:Hide()

frame.listing = gui.panel(frame)
frame.listing:SetPoint('TOPLEFT', aux.frame.content, 'TOPLEFT', 0, 0)
frame.listing:SetPoint('BOTTOMRIGHT', aux.frame.content, 'BOTTOMRIGHT', 0, 0)

local STATUS_RANK = {undercut = 1, tied = 2, unchecked = 3, lowest = 4, bid = 5, ['no buyout'] = 6, cancelling = 7, cancelled = 7, sold = 8}

local function status_text(record)
    local status, amount, lowest = auction_status(record)
    if status == 'undercut' then
        return aux.color.red('Undercut by ' .. money.to_string(amount, true, nil, nil, true))
    elseif status == 'tied' then
        return aux.color.orange('Tied with ' .. amount .. (amount == 1 and ' other' or ' others'))
    elseif status == 'lowest' then
        return aux.color.green(lowest and 'Lowest' or 'Only one listed')
    elseif status == 'sold' then
        return aux.color.blue('Sold, money in the mail')
    elseif status == 'cancelled' then
        return aux.color.label.enabled('Cancelled, comes by mail')
    elseif status == 'cancelling' then
        return aux.color.label.enabled('Cancelling...')
    elseif status == 'bid' then
        return aux.color.yellow('Has a bid')
    elseif status == 'no buyout' then
        return aux.color.label.enabled('Bid only')
    end
    return aux.color.label.enabled('Not checked')
end

M.columns = {
    auction_listing.requirement_column(),
    auction_listing.item_level_column(),
    {
        title = 'Item',
        width = .28,
        init = auction_listing.item_column_init,
        fill = auction_listing.item_column_fill,
        cmp = function(a, b, desc)
            return sort_util.compare(a.name, b.name, desc)
        end,
    },
    {
        title = 'Qty',
        width = .06,
        align = 'CENTER',
        fill = function(cell, record)
            cell.text:SetText(record.count or 1)
        end,
        cmp = function(a, b, desc)
            return sort_util.compare(a.count or 1, b.count or 1, desc)
        end,
    },
    {
        title = 'Time\nLeft',
        width = .05,
        align = 'CENTER',
        fill = function(cell, record)
            cell.text:SetText(record.sale_status == 1 and '-' or auction_listing.time_left(record.duration or 0) or '?')
        end,
        cmp = function(a, b, desc)
            return sort_util.compare(a.duration or 0, b.duration or 0, desc)
        end,
    },
    {
        title = 'Your price\n(per item)',
        width = .13,
        align = 'RIGHT',
        fill = function(cell, record)
            local price = ceil(record.unit_buyout_price or 0)
            cell.text:SetText(price > 0 and money.to_string(price, true) or '---')
        end,
        cmp = function(a, b, desc)
            return sort_util.compare(a.unit_buyout_price or 0, b.unit_buyout_price or 0, desc)
        end,
    },
    {
        title = 'Lowest other\n(per item)',
        width = .13,
        align = 'RIGHT',
        fill = function(cell, record)
            local status, _, lowest = auction_status(record)
            if lowest then
                cell.text:SetText(money.to_string(lowest, true))
            elseif status == 'lowest' then
                cell.text:SetText(aux.color.label.enabled('none'))
            else
                cell.text:SetText('')
            end
        end,
        cmp = function(a, b, desc)
            return sort_util.compare(select(3, auction_status(a)) or 0, select(3, auction_status(b)) or 0, desc)
        end,
    },
    {
        title = 'Status',
        width = .2,
        align = 'CENTER',
        fill = function(cell, record)
            cell.text:SetText(status_text(record))
        end,
        cmp = function(a, b, desc)
            return sort_util.compare(STATUS_RANK[auction_status(a)] or 9, STATUS_RANK[auction_status(b)] or 9, desc)
        end,
    },
}

listing = auction_listing.new(frame.listing, 22, columns)
-- auxForever (0.7.1, FB-015): every auction on its own row, as in Blizzard's list. Folding other
-- prices of an item under one row hid them, and on Forever several posted items are several
-- identical auctions, which the Qty column showed as one.
listing.one_row_each = true
listing:SetSort(3, 8)
listing:Reset()
listing.alt_hint = 'Alt-click: cancel'
listing:SetHandler('OnClick', function(row, button)
	if IsAltKeyDown() and aux.account_data.action_shortcuts then
		if listing:GetSelection() and listing:GetSelection().record == row.record then
            cancel_button:Click()
		end
	elseif button == 'RightButton' then
		aux.set_tab(1)
		search_tab.set_filter(strlower(info.item(row.record.item_id).name) .. '/exact')
		search_tab.execute(nil, false)
	end
end)

-- top row: Check prices and the summary
do
    local btn = gui.button(frame)
    btn:SetPoint('TOPLEFT', 5, -8)
    btn:SetHeight(25)
    btn:SetWidth(110)
    btn:SetText('Check prices')
    btn:SetScript('OnClick', function() check_prices() end)
    check_button = btn
end
do
    local label = gui.label(frame, gui.font_size.medium)
    label:SetPoint('TOPLEFT', check_button, 'TOPRIGHT', 12, 2)
    label:SetJustifyH('LEFT')
    summary_label = label
    local detail = gui.label(frame, gui.font_size.small)
    detail:SetPoint('TOPLEFT', label, 'BOTTOMLEFT', 0, -2)
    detail:SetJustifyH('LEFT')
    gui.text_color(detail, aux.color.label.enabled)
    checked_label = detail
end
-- on the right: Cancel undercut, and which auction it cancels next
do
    local btn = gui.button(frame)
    btn:SetPoint('TOPRIGHT', -5, -8)
    btn:SetHeight(25)
    btn:SetWidth(150)
    btn:SetScript('OnClick', function() cancel_next_undercut() end)
    cancel_undercut_button = btn
    local label = gui.label(frame, gui.font_size.small)
    label:SetPoint('RIGHT', btn, 'LEFT', -10, 0)
    label:SetJustifyH('RIGHT')
    gui.text_color(label, aux.color.label.enabled)
    next_label = label
end

gui.horizontal_line(frame, -40)

do
    local btn = gui.button(frame)
    btn:SetPoint('LEFT', aux.status_bar, 'RIGHT', 5, 0)
    btn:SetText('Cancel')
    btn:Disable()
    btn:SetScript('OnClick', function() cancel_auction() end)
    -- exported for the gamepad's Y (gamepad.lua)
    M.cancel_button = btn
end
do
    -- what the selected auction's status means
    local label = gui.label(frame, gui.font_size.small)
    label:SetPoint('LEFT', cancel_button, 'RIGHT', 10, 0)
    label:SetPoint('RIGHT', aux.frame.content, 'BOTTOMRIGHT', -200, 0)
    label:SetJustifyH('LEFT')
    gui.text_color(label, aux.color.label.enabled)
    selection_label = label
end

local function plural(n, word)
    return n .. ' ' .. word .. (n == 1 and '' or 's')
end

function M.summary_text(counts)
    local parts = {}
    for _, entry in ipairs{{'undercut', 'undercut'}, {'tied', 'tied'}, {'lowest', 'lowest'}, {'bid', 'with a bid'}, {'sold', 'sold'}, {'cancelling', 'cancelling'}, {'cancelled', 'cancelled'}} do
        local n = counts[entry[1]]
        if n and n > 0 then
            tinsert(parts, n .. ' ' .. entry[2])
        end
    end
    if counts.total == 0 then
        return 'No auctions'
    end
    return plural(counts.total, 'auction') .. (#parts > 0 and ': ' .. table.concat(parts, ', ') or '')
end

local function selection_text(record)
    local status, amount, lowest = auction_status(record)
    if status == 'undercut' then
        local cost = C_AuctionHouse.GetCancelCost(record.auction_id) or 0
        return 'Someone lists it at ' .. money.to_string(lowest, true) .. '. Cancelling costs ' .. money.to_string(cost, true) .. '; it comes back by mail, then post it again.'
    elseif status == 'tied' then
        return 'Others list it at your price.'
    elseif status == 'lowest' then
        return 'Yours is the cheapest.'
    elseif status == 'sold' then
        return 'The money is in your mailbox.'
    elseif status == 'cancelled' then
        return 'Cancelled. It comes back by mail.'
    elseif status == 'cancelling' then
        return 'Waiting for the auction house to confirm the cancel.'
    elseif status == 'bid' then
        return 'Someone has bid on it.'
    elseif status == 'unchecked' then
        return 'Press Check prices to compare it with other sellers.'
    end
    return ''
end

do
    local last = {}
    local function set(widget, key, text)
        if last[key] ~= text then
            last[key] = text
            widget:SetText(text)
        end
    end
    -- called a few times a second; widgets are only touched when their text changes
    function M.update_controls()
        local counts = status_counts()
        set(summary_label, 'summary', summary_text(counts))
        local checked
        if checking then
            checked = checking.total and format('Checking prices, item %d of %d...', checking.done, checking.total)
                or format('Checking prices, %d read...', checking.done)
        elseif checked_at then
            checked = 'Prices checked ' .. search_tab.time_ago(checked_at) .. ', about half a second per item'
        else
            checked = 'Prices not checked yet'
        end
        set(checked_label, 'checked', checked)

        local next = next_undercut()
        local undercut = counts.undercut or 0
        set(cancel_undercut_button, 'cancel', undercut > 0 and 'Cancel undercut (' .. undercut .. ')' or 'Cancel undercut')
        local next_text = 'None of your auctions is undercut'
        if next then
            local _, _, lowest = auction_status(next)
            local cost = C_AuctionHouse.GetCancelCost(next.auction_id) or 0
            next_text = 'Next: ' .. next.name .. ', yours ' .. money.to_string(ceil(next.unit_buyout_price), true) .. ', lowest ' .. money.to_string(lowest, true) .. ', cancelling costs ' .. money.to_string(cost, true)
        end
        set(next_label, 'next', next_text)
        local can_next = next ~= nil
        if last.can_next ~= can_next then
            last.can_next = can_next
            if can_next then
                cancel_undercut_button:Enable()
                gui.set_primary(cancel_undercut_button)
            else
                cancel_undercut_button:Disable()
                gui.set_default(cancel_undercut_button)
            end
        end

        local selection = listing:GetSelection()
        local record = selection and selection.record
        set(selection_label, 'selection', record and selection_text(record) or '')
        local can_cancel = record and record.sale_status == 0 and record.auction_id and not cancelled[record.auction_id] and not cancelling[record.auction_id] and C_AuctionHouse.CanCancelAuction(record.auction_id) and true or false
        if last.can_cancel ~= can_cancel then
            last.can_cancel = can_cancel
            if can_cancel then cancel_button:Enable() else cancel_button:Disable() end
        end
    end
end
