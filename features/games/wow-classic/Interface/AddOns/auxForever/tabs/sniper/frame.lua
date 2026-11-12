select(2, ...) 'aux.tabs.sniper'

local aux = require 'aux'
local info = require 'aux.util.info'
local money = require 'aux.util.money'
local sort_util = require 'aux.util.sort'
local gui = require 'aux.gui'
local auction_listing = require 'aux.gui.auction_listing'
local buy_bar = require 'aux.gui.buy_bar'
local search_tab = require 'aux.tabs.search'

-- auxForever: the Sniper tab, from the approved mockup: Start / Stop and the round status on the
-- left, the deal rule on the right, the deals in a table with the buy bar under it.

frame = CreateFrame('Frame', nil, aux.frame)
frame:SetAllPoints(aux.frame.body)
frame:SetScript('OnUpdate', function() update() end)
frame:Hide()

frame.listing = gui.panel(frame)
frame.listing:SetAllPoints(aux.frame.content)

frame.listing.list = CreateFrame('Frame', nil, frame.listing)
-- exported for the gamepad: A on a deal moves the focus to the buy bar (gamepad.lua)
M.deals_list = frame.listing.list
frame.listing.list:SetPoint('TOPLEFT', 0, 0)
frame.listing.list:SetPoint('BOTTOMRIGHT', 0, buy_bar.HEIGHT + 4)

local function ago(t)
    local seconds = time() - t
    if seconds < 5 then
        return 'just now'
    elseif seconds < 60 then
        return seconds .. 's ago'
    elseif seconds < 3600 then
        return floor(seconds / 60) .. 'm ago'
    end
    return floor(seconds / 3600) .. 'h ago'
end
M.ago = ago

-- gone deals are shown dimmed
local function dim(record, text)
    return record.deal_gone and aux.color.label.disabled(text) or text
end

local function price_text(record, amount)
    if record.deal_gone then
        -- a deal that is gone: gray numbers, coin letters still in their colors (Tyler, 0.6)
        return money.to_string(amount, true, nil, aux.color.label.disabled)
    end
    return money.to_string(amount, true)
end

-- the price a deal was judged against: what a vendor pays, today's market, or the usual price (shown
-- only when it rests on enough history, as before)
function M.compared_price(record)
    if record.deal_reason == 'vendor' then
        return record.deal_vendor
    elseif record.deal_reason == 'market' then
        return record.deal_market
    end
    return record.deal_usual
end

M.columns = {
    {
        title = 'Found',
        width = .09,
        align = 'CENTER',
        fill = function(cell, record)
            if record.deal_gone then
                cell.text:SetText(aux.color.label.disabled(record.deal_bought and 'bought' or 'gone'))
            elseif time() - record.deal_found < 10 then
                cell.text:SetText(aux.color.green(ago(record.deal_found)))
            else
                cell.text:SetText(ago(record.deal_found))
            end
        end,
        cmp = function(a, b, desc)
            -- deals that sold sit below the ones still to buy, whichever way this column is sorted
            if not a.deal_gone ~= not b.deal_gone then
                return a.deal_gone and sort_util.GT or sort_util.LT
            end
            return sort_util.compare(a.deal_found, b.deal_found, desc)
        end,
    },
    auction_listing.requirement_column(),
    auction_listing.item_level_column(),
    {
        title = 'Item',
        width = .28,
        init = auction_listing.item_column_init,
        fill = function(cell, record, ...)
            auction_listing.item_column_fill(cell, record, ...)
            if record.deal_gone then
                cell.text:SetText(aux.color.label.disabled(record.name))
            end
        end,
        cmp = function(a, b, desc)
            return sort_util.compare(a.name, b.name, desc)
        end,
    },
    {
        title = 'For sale',
        width = .07,
        align = 'CENTER',
        fill = function(cell, record)
            local units = record.commodity and record.count or (record.auction_count or 1)
            cell.text:SetText(dim(record, units))
        end,
        cmp = function(a, b, desc)
            return sort_util.compare(a.count * (a.auction_count or 1), b.count * (b.auction_count or 1), desc)
        end,
    },
    {
        title = 'Price each',
        width = .12,
        align = 'RIGHT',
        fill = function(cell, record)
            cell.text:SetText(price_text(record, ceil(record.unit_buyout_price)))
        end,
        cmp = function(a, b, desc)
            return sort_util.compare(a.unit_buyout_price, b.unit_buyout_price, desc)
        end,
    },
    {
        -- review H-008, finding 7: the price the deal was compared with (usual price, today's market or
        -- vendor price, as the Why column says), so price, this, the percent and the profit add up
        title = 'Compared to',
        width = .12,
        align = 'RIGHT',
        fill = function(cell, record)
            local compared = compared_price(record)
            cell.text:SetText(compared and price_text(record, compared) or dim(record, '?'))
        end,
        cmp = function(a, b, desc)
            return sort_util.compare(compared_price(a) or 0, compared_price(b) or 0, desc)
        end,
    },
    {
        title = 'Why',
        width = .13,
        align = 'CENTER',
        fill = function(cell, record)
            -- 0.8.2 (FB-036): 'market' when today's listings put the item below its usual price
            local basis = record.deal_reason == 'market' and ' of market' or ' of usual'
            if record.deal_reason == 'vendor' then
                cell.text:SetText(record.deal_gone and aux.color.label.disabled('below vendor') or aux.color.blue('below vendor'))
            elseif record.deal_gone or not record.deal_percent then
                cell.text:SetText(aux.color.label.disabled((record.deal_percent or '?') .. '%' .. basis))
            else
                -- 0.8.2 build 5 (Tyler: "clean, consistent"): the percent in the colors of the Search
                -- tab's % Hist. Value column and the tooltip's "(67%)"
                cell.text:SetText(gui.percentage_historical(record.deal_percent) .. aux.color.label.enabled(basis))
            end
        end,
        cmp = function(a, b, desc)
            return sort_util.compare(a.deal_percent or 0, b.deal_percent or 0, desc)
        end,
    },
    {
        title = 'Profit each',
        width = .12,
        align = 'RIGHT',
        fill = function(cell, record)
            if record.deal_gone then
                cell.text:SetText(price_text(record, record.deal_profit))
            else
                cell.text:SetText(money.to_string(record.deal_profit, true, nil, aux.color.green))
            end
        end,
        cmp = function(a, b, desc)
            return sort_util.compare(a.deal_profit, b.deal_profit, desc)
        end,
    },
}

listing = auction_listing.new(frame.listing.list, 19, columns)
-- each deal on its own row (0.8, review H-004, finding 4): a gone deal never hides a live one
listing.one_row_each = true
listing.keep_selection_only = true
listing:SetSort(-1)
listing:Reset()
listing:SetHandler('OnClick', function(row, button)
    if button == 'LeftButton' then
        click_deal(row.record)
    elseif button == 'RightButton' then
        aux.set_tab(1)
        search_tab.set_filter(strlower(info.item(row.record.item_id).name) .. '/exact')
        search_tab.execute(nil, false)
    end
end)

do
    local label = gui.label(frame.listing.list, gui.font_size.medium)
    label:SetPoint('CENTER', 0, 0)
    label:SetWidth(600)
    label:SetWordWrap(true) -- two lines; gui.label is one line by default, which cut it to "round..."
    gui.text_color(label, aux.color.label.enabled)
    empty_label = label
end

-- top row: Start / Stop and the status
do
    local btn = gui.button(frame)
    btn:SetPoint('TOPLEFT', 5, -8)
    btn:SetHeight(25)
    btn:SetWidth(90)
    btn:SetScript('OnClick', function()
        if running then stop() else start() end
    end)
    -- exported for the gamepad's Y (gamepad.lua)
    M.run_button = btn
end
do
    local label = gui.label(frame, gui.font_size.medium)
    label:SetPoint('LEFT', run_button, 'RIGHT', 12, 0)
    label:SetJustifyH('LEFT')
    status_label = label
end

-- the deal rule, on the right
do
    local btn = gui.button(frame, gui.font_size.small)
    btn:SetPoint('TOPRIGHT', -5, -8)
    btn:SetHeight(25)
    btn:SetWidth(60)
    btn:SetText('Sound')
    btn:SetScript('OnClick', function()
        aux.account_data.sniper_sound = not aux.account_data.sniper_sound
        gui.set_selected(btn, aux.account_data.sniper_sound)
    end)
    sound_button = btn
end
do
    local editbox = gui.editbox(frame)
    editbox:SetPoint('RIGHT', sound_button, 'LEFT', -14, 0)
    editbox:SetWidth(60)
    editbox:SetHeight(25)
    editbox:SetAlignment('CENTER')
    editbox.formatter = function(text)
        return money.from_string(text) and text or aux.color.red(text)
    end
    editbox.change = function(self, user)
        local amount = money.from_string(self:GetText())
        if user and amount then
            aux.account_data.sniper_profit = amount
            settings_changed()
        end
    end
    editbox.enter = function(self) self:ClearFocus() end
    editbox.focus_loss = function(self)
        self:SetText(money.to_string(aux.account_data.sniper_profit, nil, true, nil, true))
    end
    profit_input = editbox
    local label = gui.label(frame, gui.font_size.medium)
    label:SetPoint('RIGHT', editbox, 'LEFT', -6, 0)
    label:SetText('% of usual, profit at least')
    gui.text_color(label, aux.color.label.enabled)
    profit_label = label
end
do
    local editbox = gui.editbox(frame)
    editbox:SetPoint('RIGHT', profit_label, 'LEFT', -6, 0)
    editbox:SetWidth(40)
    editbox:SetHeight(25)
    editbox:SetAlignment('CENTER')
    editbox:SetNumeric(true)
    editbox.change = function(self, user)
        local pct = tonumber(self:GetText())
        if user and pct and pct >= 1 and pct <= 100 then
            aux.account_data.sniper_percent = pct
            settings_changed()
        end
    end
    editbox.enter = function(self) self:ClearFocus() end
    editbox.focus_loss = function(self)
        self:SetText(tostring(aux.account_data.sniper_percent))
    end
    percent_input = editbox
    local label = gui.label(frame, gui.font_size.medium)
    label:SetPoint('RIGHT', editbox, 'LEFT', -6, 0)
    label:SetText('Deal: at most')
    gui.text_color(label, aux.color.label.enabled)
end

gui.horizontal_line(frame, -40)

-- second row: the deals and what to do with them
do
    local label = gui.label(frame, gui.font_size.large)
    label:SetPoint('BOTTOMLEFT', aux.frame.content, 'TOPLEFT', 10, 10)
    label:SetJustifyH('LEFT')
    deals_label = label
end
do
    local btn = gui.button(frame, gui.font_size.small)
    btn:SetPoint('BOTTOMRIGHT', aux.frame.content, 'TOPRIGHT', -10, 6)
    btn:SetHeight(22)
    btn:SetWidth(60)
    btn:SetText('Clear')
    btn:SetScript('OnClick', function() clear_deals() end)
    clear_button = btn
end
do
    local btn = gui.button(frame, gui.font_size.small)
    btn:SetPoint('RIGHT', clear_button, 'LEFT', -5, 0)
    btn:SetHeight(22)
    btn:SetWidth(120)
    btn:SetScript('OnClick', function() unignore_all() end)
    unignore_button = btn
end
do
    local btn = gui.button(frame, gui.font_size.small)
    btn:SetPoint('RIGHT', unignore_button, 'LEFT', -5, 0)
    btn:SetHeight(22)
    btn:SetWidth(90)
    btn:SetText('Ignore item')
    btn:SetScript('OnClick', function()
        local selection = listing:GetSelection()
        if selection then
            ignore(selection.record)
        end
    end)
    btn:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM')
        GameTooltip:AddLine('Ignore item')
        GameTooltip:AddLine('The selected item is never shown as a deal again.', 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript('OnLeave', function() GameTooltip:Hide() end)
    ignore_button = btn
end

-- next to the deal count: the price history notice (history_notice) and a Full scan button
do
    local label = gui.label(frame, gui.font_size.small)
    label:SetPoint('LEFT', deals_label, 'RIGHT', 18, 0)
    label:SetJustifyH('LEFT')
    notice_label = label
    local btn = gui.button(frame, gui.font_size.small)
    btn:SetPoint('LEFT', label, 'RIGHT', 8, 0)
    btn:SetHeight(22)
    btn:SetWidth(70)
    btn:SetText('Full scan')
    btn:SetScript('OnClick', function()
        aux.full_scan_button:Click()
    end)
    btn:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM')
        GameTooltip:AddLine('Full scan')
        GameTooltip:AddLine('Records the price of everything on the auction house, like the Full scan button at the top right. The game allows one every 15 minutes.', 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript('OnLeave', function() GameTooltip:Hide() end)
    btn:Hide()
    notice_button = btn
end

-- "2 to buy, 1 gone": a list of only gone deals no longer reads "0 found"
function M.deals_count(shown)
    local open, gone = 0, 0
    for _, deal in ipairs(shown) do
        if deal.deal_gone then gone = gone + 1 else open = open + 1 end
    end
    local text = open .. ' to buy'
    if gone > 0 then
        text = text .. ', ' .. gone .. ' gone'
    end
    return text
end

-- the table follows the deals; called when they change
function M.update_deals()
    local shown = shown_deals()
    listing:SetDatabase(shown)
    deals_label:SetText(aux.color.accent.background('Deals') .. '  ' .. aux.color.label.enabled(deals_count(shown)))
    if #shown > 0 then
        empty_label:SetText('')
    elseif running then
        empty_label:SetText('No deals yet. The whole auction house is checked every round; gray items are left out.\nDeals against the usual price need ' .. MIN_DAYS .. ' days with a Full scan (or a Full search of the item).\nSniper works best with fresh Full scan data.')
    else
        empty_label:SetText('Press Start to watch the whole auction house for deals.')
    end
end

do
    local last_run, last_status, last_ignored, last_notice
    -- the controls follow the state; only touched when something changed
    function M.update_controls()
        if running ~= last_run then
            last_run = running
            run_button:SetText(running and 'Stop' or 'Start')
            if running then
                gui.set_default(run_button)
                local _, size = run_button:GetFontString():GetFont()
                run_button:GetFontString():SetFont(gui.font, size and size > 0 and size or gui.font_size.medium)
            else
                gui.set_primary(run_button)
            end
            update_deals()
        end
        local title, detail = status()
        local text = aux.color.text.enabled(title) .. '   ' .. aux.color.label.enabled(detail)
        if text ~= last_status then
            last_status = text
            status_label:SetText(text)
        end
        -- the price history notice; redrawn, and its button shown or hidden, only when it changes
        local notice, kind = history_notice(time(), aux.account_data.replicate_time, history_days, history_days_known)
        if notice ~= last_notice then
            last_notice = notice
            notice_label:SetText(notice and (kind == 'stale' and aux.color.orange(notice) or aux.color.label.enabled(notice)) or '')
            if notice then notice_button:Show() else notice_button:Hide() end
        end
        local ignored = ignored_count()
        if ignored ~= last_ignored then
            last_ignored = ignored
            unignore_button:SetText(ignored > 0 and 'Unignore all (' .. ignored .. ')' or 'Unignore all')
            if ignored > 0 then unignore_button:Enable() else unignore_button:Disable() end
        end
    end
end

function aux.event.AUX_LOADED()
    percent_input:SetText(tostring(aux.account_data.sniper_percent))
    profit_input:SetText(money.to_string(aux.account_data.sniper_profit, nil, true, nil, true))
    gui.set_selected(sound_button, aux.account_data.sniper_sound)
end
