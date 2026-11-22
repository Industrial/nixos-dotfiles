select(2, ...) 'aux.gui.buy_bar'

local aux = require 'aux'
local gui = require 'aux.gui'
local money = require 'aux.util.money'

-- The buy bar sits under the Search results and buys whatever is selected.
--
-- Commodities (stackable trade goods) cannot be bought by row on Forever: whichever row is
-- selected, the game sells the cheapest units first. So for them the bar offers quantities sized
-- to the item's stack (e.g. 1, 5, 10, 20), each showing what it costs, plus a Quantity box that
-- always holds the number being bought (the buttons fill it in, typing changes it; FB-001):
--   1. Buy asks the server for the real price (the click the game needs to start a purchase)
--   2. a server price at or below the cost on the button is bought at once (0.8.2.1 build 7,
--      Tyler: players did not like the Confirm click; it added no safety, see below), or, with
--      "Confirm before buying" on (0.8.2.2), shown on a Confirm button that a second click presses
--   3. a server price above the shown cost is cancelled and the item's listings are re-read
-- The bar starts at 1 (0.8.2.2, FB-050, Tyler): it started at a full stack, and with one click
-- buying, players bought far more than they meant to.
-- Why no Confirm: the safety is step 3, a check aux makes on the server's price before paying,
-- not the second click. The game needs a click to ask for the price (StartCommoditiesPurchase is
-- restricted) but not to confirm it (ConfirmCommoditiesPurchase is not: Blizzard's generated
-- documentation, branch forever), so the confirm is sent when the price arrives.
--
-- Items (gear, bags, ...) are bought one at a time at the price shown on the button, as in
-- Classic aux; a Bid button appears when the auction takes bids. With "Confirm before buying" on,
-- Buy turns into Confirm (and Cancel) and a second click buys.
--
-- After any purchase Buy stays faded for HOLD_SECONDS (0.8.2.2, FB-051, Tremulent: "sometimes
-- getting double buys"). The likely cause (from the code, not seen in game): players used to Buy,
-- then Confirm click twice; once the first click's purchase is done, the second finds Buy lit
-- again and buys a second time.

M.HEIGHT = 58

-- auxForever (0.6, the UI Kit): Buy has the primary look (gold outline), Confirm a green one
local ACCENT = 'primary'
local ACCENT_TEXT = nil
local CONFIRM = 'confirm'
local CONFIRM_TEXT = nil
local INPUT_HOVER = {.42, .42, .42}

local NONE, COMMODITY, ITEM = aux.enum(3)
local IDLE, QUOTING, QUOTED, BUYING = aux.enum(4)

-- a quarter second since 0.8.2.2 build 3 (1 in build 1, half a second in build 2, which Tyler
-- found "still feels too long"). A habitual second click mostly lands while the purchase is still on
-- its way, when Buy is faded anyway; the rest only covers the moment just after it is done.
M.HOLD_SECONDS = .25
local hold_until = 0
-- gear waiting for its Confirm click (0.8.2.2): the record and the price the Confirm button shows
local item_confirm
-- the item a "Bought" message is about: it stays when the next auction of that item is selected
local message_item

local mode = NONE
local state = IDLE
local current
-- 0.8.2.1 (found by the random player of tests/fuzz_test.lua): what the buttons show right now. The
-- bar's texts are drawn ten times a second, and a click acted on the selection as it was at the
-- click: for up to a tenth of a second after the selection (or a price) changed, Buy could show
-- one price and buy at another. A click now only does what its button shows; when the two differ,
-- the bar is drawn again and nothing is sent.
local shown = {}
local update -- draws the bar (defined below, with the shared part)
local listener_ids = {}
local t0
local message, message_color, message_until

local bar, icon, name_label, sub_label, chips, other_input, line1, line2, cancel_button, bid_button, primary_button

-- helpers

local function wipe_shown()
    for k in pairs(shown) do shown[k] = nil end
end

local function kill_listeners()
    for _, id in ipairs(listener_ids) do
        aux.kill_listener(id)
    end
    listener_ids = {}
end

local function listen(event, f)
    tinsert(listener_ids, aux.event_listener(event, f))
end

local function show_message(text, color, seconds)
    message, message_color = text, color or aux.color.text.enabled
    message_until = GetTime() + (seconds or 6)
    message_item = nil
end

-- "Confirm before buying" (Settings, /aux buy confirm), off unless the player turns it on
local function confirm_wanted()
    return aux.account_data and aux.account_data.buy_confirm and true or false
end

local function held()
    return GetTime() < hold_until
end

-- a purchase went through: say so, and keep Buy faded for a moment against a second click
local function bought_message(text1, text2, item_name)
    show_message({text1, text2}, aux.color.green)
    message_item = item_name or current and current.name
    hold_until = GetTime() + HOLD_SECONDS
end

-- runs up to ten times a second; the look is only redrawn when it or the button's state changed
local function style_button(button, look, _, enabled)
    enabled = enabled and true or false
    if button.aux_look == look and button.aux_shown_enabled == enabled then return end
    button.aux_shown_enabled = enabled
    if enabled then button:Enable() else button:Disable() end
    -- painted whenever the look changes: Enable and Disable repaint only when the button's state
    -- changes, so Confirm, then Cancel kept the Confirm green on a Buy button (Tyler, 0.8)
    gui.apply_look(button, look)
end

-- Money for button labels: the coloured g/s/c of money.to_string vanish on the coloured buttons
-- Money for button labels. auxForever (0.6, Tyler): g, s and c always have their coin colors,
-- wherever money is shown; the label's own color is kept for the numbers. (They were plain
-- because the coin colors vanished on 0.5's solid amber buttons; no button is filled that way now.)
local function plain_money(amount)
    return money.to_string(amount, true)
end

local function fit_width(button, min_width)
    button:SetWidth(max(min_width or 80, button:GetFontString():GetStringWidth() + 28))
end

local function set_lines(text1, text2, color2)
    line1:SetText(text1 or '')
    line2:SetText(text2 or '')
    line2:SetTextColor((color2 or aux.color.label.enabled)())
end

-- Quantities offered for a stack size: 1, up to two round numbers below the stack, and the stack
function M.quantities(stack)
    if not stack or stack <= 1 then
        return {}
    end
    local below = {}
    for _, n in ipairs{5, 10, 20, 50, 100, 200, 500} do
        if n < stack then
            tinsert(below, n)
        end
    end
    local quantities = {1}
    for i = max(1, #below - 1), #below do
        tinsert(quantities, below[i])
    end
    tinsert(quantities, stack)
    return quantities
end

-- commodities

-- Cost of the cheapest n units listed: total, highest unit price paid, units actually available
local function estimate(n)
    local total, max_unit, remaining = 0, 0, n
    for _, tier in ipairs(current.tier_list) do
        if remaining <= 0 then break end
        local taken = min(remaining, tier.count)
        total = total + taken * tier.commodity_unit_price
        max_unit = tier.commodity_unit_price
        remaining = remaining - taken
    end
    return total, max_unit, n - remaining
end

local function available()
    local count = 0
    for _, tier in ipairs(current.tier_list) do
        count = count + tier.count
    end
    return count
end

local function quantity()
    return current.quantity or 0
end

local function set_quantity(n)
    if state ~= IDLE then return end
    current.quantity = n
    message = nil
end

local function update_commodity()
    local n = quantity()
    local total, max_unit, count = estimate(n)
    local stock = available()

    sub_label:SetText(stock .. ' for sale' .. ((current.max_stack or 1) > 1 and ' · stack of ' .. current.max_stack or ''))

    for i, chip in ipairs(chips) do
        local amount = current.quantities[i]
        if amount then
            chip:Show()
            local chip_total, _, chip_count = estimate(amount)
            chip.amount:SetText(amount == current.max_stack and amount .. ' stack' or amount)
            chip:SetWidth(amount == current.max_stack and 80 or 64)
            local selected = amount == n
            if chip_count < amount then
                chip.cost:SetText('-')
                chip:Disable()
            else
                chip.cost:SetText(money.to_string(chip_total, true))
                chip:Enable()
            end
            -- the chosen one has the selected look (gold outline), the others the default look; a
            -- chip that cannot be bought keeps its colors and shows '-'
            if selected ~= chip.aux_selected then
                chip.aux_selected = selected
                gui.apply_look(chip, selected and 'selected' or 'default', true)
                if selected then
                    chip.amount:SetTextColor(1, 1, 1)
                    chip.cost:SetTextColor(1, 1, 1)
                else
                    chip.amount:SetTextColor(aux.color.text.enabled())
                    chip.cost:SetTextColor(.75, .75, .75)
                end
            end
        else
            chip:Hide()
        end
    end
    -- auxForever (0.5, FB-001): the box is amber when it holds a number of your own, lighter while
    -- hovered or typed in, so it reads as a place to type
    local custom = not aux.key(current.quantities, n)
    if custom then
        other_input:SetBackdropBorderColor(aux.color.accent.background())
    elseif other_input.focused or other_input.hovered then
        other_input:SetBackdropBorderColor(INPUT_HOVER[1], INPUT_HOVER[2], INPUT_HOVER[3], 1)
    else
        other_input:SetBackdropBorderColor(aux.color.input.border())
    end

    -- the bar redraws every frame: a button hidden and shown again each frame drops any click
    -- that started before the hide, so Cancel is only shown or hidden when that changes
    -- no Cancel since build 7: a price that may be paid is bought the moment it arrives (Escape
    -- in the quantity box still cancels while the price is asked for); with Confirm before buying
    -- on, Cancel stands next to Confirm (0.8.2.2)
    if state == QUOTED then
        if not cancel_button:IsShown() then cancel_button:Show() end
    elseif cancel_button:IsShown() then
        cancel_button:Hide()
    end
    bid_button:Hide()
    if state == IDLE then
        if message and GetTime() < message_until then
            set_lines(message[1], message[2], message_color)
        elseif stock == 0 then
            set_lines('None for sale', 'Only your own auctions are listed')
        elseif n < 1 then
            set_lines('Choose how many to buy')
        elseif count < n then
            set_lines('Only ' .. count .. ' for sale', 'Choose a smaller quantity', aux.color.red)
        else
            set_lines(n .. ' × ' .. current.name .. ' for ' .. money.to_string(total, true), 'Cheapest first · avg ' .. money.to_string(ceil(total / n), true) .. ' · highest ' .. money.to_string(max_unit, true) .. ' each')
        end
        local can_buy = n >= 1 and count == n
        if can_buy and total > GetMoney() then
            can_buy = false
            set_lines(n .. ' × ' .. current.name .. ' for ' .. money.to_string(total, true), 'Not enough money', aux.color.red)
        end
        primary_button:SetText(can_buy and ('Buy ' .. n .. ' for ' .. plain_money(total)) or 'Buy')
        style_button(primary_button, ACCENT, ACCENT_TEXT, can_buy and not held())
        shown.item_id, shown.quantity, shown.total, shown.quote, shown.record = current.item_id, n, total, nil, nil
    elseif state == QUOTING then
        set_lines('Asking the auction house for the price...', 'Nothing is bought yet')
        primary_button:SetText('Getting price...')
        style_button(primary_button, ACCENT, ACCENT_TEXT, false)
    elseif state == QUOTED then
        set_lines('Server price: ' .. money.to_string(current.quote_total, true) .. ' for ' .. current.quote_quantity, 'Nothing is bought until you confirm', aux.color.green)
        primary_button:SetText('Confirm ' .. plain_money(current.quote_total))
        style_button(primary_button, CONFIRM, CONFIRM_TEXT, current.quote_total <= GetMoney())
        shown.item_id, shown.quantity, shown.quote, shown.record = current.item_id, current.quote_quantity, current.quote_total, nil
    elseif state == BUYING then
        set_lines('Buying...', 'Waiting for the auction house')
        primary_button:SetText('Buying...')
        style_button(primary_button, CONFIRM, CONFIRM_TEXT, false)
    end
    fit_width(primary_button, 130)
end

local function reset(text, color)
    kill_listeners()
    if mode == COMMODITY and (state == QUOTING or state == QUOTED) then
        C_AuctionHouse.CancelCommoditiesPurchase()
    end
    state = IDLE
    item_confirm = nil
    if text then
        show_message(text, color)
    end
end

local function request_quote()
    local n = quantity()
    local total, _, count = estimate(n)
    if n < 1 or count < n or total > GetMoney() or held() then return end
    current.quote_quantity, current.estimate = n, total
    state = QUOTING
    t0 = GetTime()
    message = nil

    listen('COMMODITY_PRICE_UPDATED', function(_, quote_total)
        -- QUOTED too: the game can send the price again while Confirm is shown (the old two-click
        -- flow, 0.8.2 and earlier)
        if state ~= QUOTING and state ~= QUOTED then return end
        -- never more than the player saw: the button showed current.estimate when it was pressed
        if quote_total > current.estimate then
            reset({'The price went up to ' .. money.to_string(quote_total, true), 'Nothing was bought. Listings refreshed.'}, aux.color.red)
            update()
            do (current.on_refresh or pass)() end
            return
        elseif quote_total > GetMoney() then
            reset({'Not enough money for ' .. money.to_string(quote_total, true), 'Nothing was bought'}, aux.color.red)
            update()
            return
        end
        current.quote_total = quote_total
        if confirm_wanted() then
            -- Confirm before buying (0.8.2.2): the price waits on the Confirm button
            state = QUOTED
            update()
            return
        end
        -- at or below the price on the button: bought now, with no second click (build 7)
        state = BUYING
        t0 = GetTime()
        update()
        C_AuctionHouse.ConfirmCommoditiesPurchase(current.item_id, current.quote_quantity)
    end)
    listen('COMMODITY_PRICE_UNAVAILABLE', function()
        reset({'That price is no longer available', 'Nothing was bought. Listings refreshed.'}, aux.color.red)
        update()
        do (current.on_refresh or pass)() end
    end)
    listen('COMMODITY_PURCHASE_FAILED', function()
        reset({'The purchase failed', 'Nothing was bought'}, aux.color.red)
        update()
    end)
    listen('AUCTION_HOUSE_SHOW_ERROR', function()
        if state ~= IDLE then
            reset({'The auction house refused the purchase', 'Nothing was bought'}, aux.color.red)
            update()
        end
    end)
    -- 0.8.2.1 (outside review, R-20): the game drops a request sent too soon after another one. The
    -- price request then never got an answer, and the bar said so only after 10 seconds.
    listen('AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED', function()
        if state == QUOTING then
            reset({'The auction house was busy', 'Nothing was bought. Press Buy again.'}, aux.color.red)
            update()
        end
    end)
    listen('COMMODITY_PURCHASE_SUCCEEDED', function()
        if state ~= BUYING then return end
        local bought, paid, on_success = current.quote_quantity, current.quote_total, current.on_success
        kill_listeners()
        state = IDLE
        bought_message('Bought ' .. bought .. ' × ' .. current.name .. ' for ' .. money.to_string(paid, true), 'On the way to your mailbox')
        do (on_success or pass)(bought) end
        -- the purchase can change the selection, which may already have moved the bar on
        if mode == COMMODITY and current then
            current.tier_list = current.tiers()
            update()
        end
    end)

    C_AuctionHouse.StartCommoditiesPurchase(current.item_id, n)
end

-- items

local function can_buy_item()
    local record = current.record
    return not current.busy() and not current.own and not record.own and record.buyout_price > 0 and record.buyout_price <= GetMoney()
end

local function can_bid_item()
    local record = current.record
    return not current.own and not record.own and not record.high_bidder and (record.buyout_price == 0 or record.bid_price < record.buyout_price)
end

local function update_item()
    local record = current.record
    local busy = current.busy()
    -- a row of several sellers at one price holds group_count auctions (0.8, review H-004, finding 5)
    local at_price = record.group_count or record.auction_count or 1
    sub_label:SetText(at_price .. ' at this price')
    for _, chip in ipairs(chips) do chip:Hide() end
    -- a Confirm is only for the auction and price it showed
    if item_confirm and (item_confirm.record ~= record or item_confirm.price ~= record.buyout_price) then
        item_confirm = nil
    end
    -- shown or hidden only when that changes (a button hidden every frame drops clicks)
    if item_confirm then
        if not cancel_button:IsShown() then cancel_button:Show() end
    elseif cancel_button:IsShown() then
        cancel_button:Hide()
    end

    if item_confirm then
        set_lines('1 × ' .. current.name .. ' for ' .. money.to_string(record.buyout_price, true), 'Nothing is bought until you confirm', aux.color.green)
    elseif message and GetTime() < message_until then
        set_lines(message[1], message[2], message_color)
    elseif record.own or current.own then
        set_lines('This is your own auction', 'It cannot be bought or bid on')
    elseif record.buyout_price > 0 then
        set_lines('1 × ' .. current.name .. ' for ' .. money.to_string(record.buyout_price, true), at_price > 1 and 'The next one at this price is selected after buying' or 'The last one at this price')
    else
        set_lines('No buyout price', 'This auction can only be bid on')
    end

    local can_buy = can_buy_item()
    shown.record, shown.buyout, shown.bid, shown.item_id, shown.quote = record, record.buyout_price, record.bid_price, nil, nil
    shown.confirm = item_confirm and true or false
    if item_confirm then
        primary_button:SetText('Confirm ' .. plain_money(record.buyout_price))
        style_button(primary_button, CONFIRM, CONFIRM_TEXT, can_buy)
    else
        primary_button:SetText(record.buyout_price > 0 and ('Buy for ' .. plain_money(record.buyout_price)) or 'Buy')
        style_button(primary_button, ACCENT, ACCENT_TEXT, can_buy and not held())
    end
    fit_width(primary_button, 130)

    if item_confirm then
        -- Cancel takes the Bid button's place while Confirm is shown
        bid_button:Hide()
    elseif can_bid_item() then
        bid_button:Show()
        bid_button:SetText('Bid ' .. plain_money(record.bid_price))
        fit_width(bid_button, 90)
        if busy or record.bid_price > GetMoney() then
            bid_button:Disable()
        else
            bid_button:Enable()
        end
    elseif record.high_bidder then
        bid_button:Show()
        bid_button:SetText('You are the high bidder')
        fit_width(bid_button, 90)
        bid_button:Disable()
    else
        bid_button:Hide()
    end
end

-- shared

local lines_left, lines_x, lines_right

local function place_lines()
    line1:ClearAllPoints()
    line1:SetPoint('TOPLEFT', lines_left, 'TOPRIGHT', lines_x, -4)
    line1:SetPoint('RIGHT', lines_right, 'LEFT', -10, 0)
    line2:ClearAllPoints()
    line2:SetPoint('BOTTOMLEFT', lines_left, 'BOTTOMRIGHT', lines_x, 4)
    line2:SetPoint('RIGHT', lines_right, 'LEFT', -10, 0)
end

local function anchor_lines(left, x)
    lines_left, lines_x = left, x
    place_lines()
end

-- the text uses the room up to the leftmost visible button
local function fit_lines()
    local right = bid_button:IsShown() and bid_button or cancel_button:IsShown() and cancel_button or primary_button
    if right ~= lines_right then
        lines_right = right
        place_lines()
    end
end

function update()
    if mode == NONE then return end
    if mode == COMMODITY then
        update_commodity()
    else
        update_item()
    end
    fit_lines()
end

local function show_common(params)
    icon:SetTexture(params.texture)
    local color = ITEM_QUALITY_COLORS[params.quality or 1] or ITEM_QUALITY_COLORS[1]
    name_label:SetText(params.name or '')
    name_label:SetTextColor(color.r, color.g, color.b)
    for _, widget in ipairs{icon:GetParent(), icon, name_label, sub_label, line1, line2, primary_button} do
        widget:Show()
    end
end

-- params: item_id, name, texture, quality, max_stack, tiers() (the tiers the player can buy,
-- cheapest first), on_success(n), on_refresh(), whole_deal (start at all units offered, up to a stack)
function M.show_commodity(params)
    if mode == COMMODITY and current and current.item_id == params.item_id then
        -- same item (e.g. the table refreshed after a purchase): keep the quantity and any message
        current.tiers, current.on_success, current.on_refresh = params.tiers, params.on_success, params.on_refresh
        current.tier_list = params.tiers()
        update()
        return
    end
    reset()
    message = nil
    mode = COMMODITY
    current = params
    current.tier_list = params.tiers()
    current.quantities = quantities(params.max_stack)
    local last_chip = chips[max(1, min(#chips, #current.quantities))]
    other_input:ClearAllPoints()
    other_input:SetPoint('LEFT', last_chip, 'RIGHT', 6, 0)
    -- 1 by default (0.8.2.2, FB-050), or full stack when Settings > Buying > Default quantity is
    -- set to 'stack' (0.9 build 4, FB-066, user_ivpyccljovcjne72). The Sniper always starts at the
    -- deal's own units (params.whole_deal), up to a stack.
    local want_stack = params.whole_deal or (aux.account_data and aux.account_data.buy_default == 'stack')
    local start = want_stack and max(1, min(params.max_stack or 1, available())) or 1
    current.quantity = start
    other_input:Show()
    other_input:SetText(tostring(start))
    other_input.overlay:SetText(other_input.formatter(other_input:GetText()))
    anchor_lines(other_input, 14)
    show_common(params)
    update()
end

-- params: record, name, texture, quality, own, busy(), on_buy(), on_bid()
function M.show_item(params)
    if mode == COMMODITY then
        reset()
    end
    if not (mode == ITEM and current and current.record == params.record) then
        item_confirm = nil
        -- "Bought ..." stays when the next auction of the same item is selected after a purchase
        if not (message_item and message_item == params.name) then
            message = nil
        end
    end
    mode = ITEM
    current = params
    other_input:Hide()
    anchor_lines(icon:GetParent(), 170)
    show_common(params)
    update()
end

function M.show_message(text1, text2, color)
    show_message({text1, text2}, color)
end

function M.clear()
    reset()
    mode = NONE
    current = nil
    wipe_shown()
    for _, chip in ipairs(chips) do chip:Hide() end
    for _, widget in ipairs{icon:GetParent(), icon, name_label, sub_label, other_input, cancel_button, bid_button, primary_button} do
        widget:Hide()
    end
    -- auxForever: with nothing selected the bar explains itself instead of showing an empty icon
    anchor_lines(icon:GetParent(), -38)
    line1:Show()
    line1:SetText('Select a row to buy it')
    line2:Show()
    line2:SetTextColor(aux.color.label.enabled())
    line2:SetText('Gear: one at a time. Trade goods: cheapest first.')
end

-- 0.9: clear selection and buttons while keeping a fresh bought/status message visible (used when
-- Sniper auto-deselects a bought deal so rounds can resume without wiping "Bought ...").
function M.clear_keeping_message()
    local saved, saved_color = message, message_color
    local keep = saved and GetTime() < message_until
    clear()
    if keep then
        line1:SetText(saved[1] or '')
        line2:SetText(saved[2] or '')
        line2:SetTextColor((saved_color or aux.color.label.enabled)())
    end
end

-- auxForever: a note while there is nothing to buy yet, e.g. while an item's auctions are read
function M.show_note(text1, text2, color)
    clear()
    line1:SetText(text1 or '')
    line2:SetText(text2 or '')
    line2:SetTextColor((color or aux.color.label.enabled)())
end

function M.busy()
    return state ~= IDLE
end

-- buys the selected auction at the price on the button; the tab says when it went through
local function buy_item()
    local name, price = current.name, current.record.buyout_price
    current.on_buy(function()
        bought_message('Bought 1 × ' .. name .. ' for ' .. money.to_string(price, true), 'On the way to your mailbox', name)
    end)
end

-- whether the button shows what a click would do now (see `shown`, at the top)
local function shows_quantity()
    local n = quantity()
    return shown.item_id == current.item_id and shown.quantity == n and shown.total == (estimate(n))
end

function M.primary_click()
    if mode == COMMODITY then
        if state == IDLE and shows_quantity() then
            request_quote()
        elseif state == QUOTED and current.quote_total <= GetMoney() and shown.quote == current.quote_total
                and shown.quantity == current.quote_quantity then
            -- the Confirm click (Confirm before buying on): only the price the button showed
            state = BUYING
            t0 = GetTime()
            C_AuctionHouse.ConfirmCommoditiesPurchase(current.item_id, current.quote_quantity)
        end
    elseif mode == ITEM and can_buy_item() and shown.record == current.record and shown.buyout == current.record.buyout_price then
        if item_confirm then
            if shown.confirm then
                item_confirm = nil
                buy_item()
            end
        elseif not held() and not shown.confirm then
            if confirm_wanted() then
                item_confirm = {record = current.record, price = current.record.buyout_price}
            else
                buy_item()
            end
        end
    end
    update()
end

function M.bid_click()
    if mode == ITEM and can_bid_item() and not current.busy() and current.record.bid_price <= GetMoney()
            and shown.record == current.record and shown.bid == current.record.bid_price then
        current.on_bid()
    end
    update()
end

function M.cancel_click()
    if cancel_button and cancel_button:IsShown() and cancel_button:IsEnabled() then
        reset({'Cancelled', 'Nothing was bought'}, aux.color.label.enabled)
        update()
        return true
    end
    return false
end

-- 0.9 (FB-063, khorrs): keybinds registered in auxForever/Bindings.xml (Options > Keybindings >
-- auxForever). Acts on whichever buy bar (Search or Sniper) is visible while aux is open, ignores
-- presses while typing in an edit box, and keeps Buy and Confirm separate so mashing Buy never
-- accidentally confirms when "Confirm before buying" is on.
_G.BINDING_HEADER_AUXFOREVER = 'auxForever'
_G.BINDING_NAME_AUXFOREVER_BUY = 'Buy'
_G.BINDING_NAME_AUXFOREVER_CONFIRM = 'Confirm purchase'
_G.BINDING_NAME_AUXFOREVER_CANCEL = 'Cancel / decline purchase'
_G.BINDING_NAME_AUXFOREVER_BUY_OR_CONFIRM = 'Buy or confirm'

local function binding_bar_active()
    if not (aux.frame and aux.frame:IsShown() and bar and bar:IsVisible()) then
        return false
    end
    local p = bar:GetParent()
    while p and p ~= aux.frame do
        if p.IsShown and not p:IsShown() then
            return false
        end
        p = p.GetParent and p:GetParent()
    end
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then
        return false
    end
    return true
end

function M.run_binding(action)
    if not binding_bar_active() then
        return false
    end
    if action == 'cancel' then
        return cancel_click()
    end
    if not (primary_button and primary_button:IsShown() and primary_button:IsEnabled()) then
        return false
    end
    local in_confirm = (mode == COMMODITY and state == QUOTED) or (mode == ITEM and item_confirm ~= nil)
    if action == 'buy' then
        if in_confirm then
            return false
        end
        if (mode == COMMODITY and state == IDLE) or (mode == ITEM and not item_confirm) then
            primary_click()
            return true
        end
    elseif action == 'confirm' then
        if in_confirm then
            primary_click()
            return true
        end
    elseif action == 'buy_or_confirm' then
        primary_click()
        return true
    end
    return false
end

_G.AuxForever_RunBinding = function(action)
    return run_binding(action)
end

function M.primary_label()
    return primary_button:GetText()
end

-- the two lines of text next to the buttons (for tests, like primary_label)
function M.lines()
    return line1:GetText(), line2:GetText()
end

function aux.event.CLOSE()
    clear()
end

-- auxForever: the Sniper tab borrows the bar while it is open
local default_parent

function M.attach(parent)
    if bar:GetParent() ~= parent then
        clear()
        bar:SetParent(parent)
        bar:ClearAllPoints()
        bar:SetPoint('BOTTOMLEFT', 0, 0)
        bar:SetPoint('BOTTOMRIGHT', 0, 0)
    end
end

function M.attach_default()
    attach(default_parent)
end

-- Built by the Search tab along the bottom of its results
function M.create(parent)
    default_parent = parent
    bar = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
    M.frame = bar
    -- auxForever (0.6, the UI Kit): no box of its own, a black line above it
    local edge = bar:CreateTexture(nil, 'BORDER')
    gui.texture_color(edge, aux.color.window.border)
    edge:SetPoint('TOPLEFT')
    edge:SetPoint('TOPRIGHT')
    edge:SetHeight(1)
    bar:SetPoint('BOTTOMLEFT', 0, 0)
    bar:SetPoint('BOTTOMRIGHT', 0, 0)
    bar:SetHeight(HEIGHT)
    bar:SetScript('OnHide', function()
        reset()
    end)
    local next_update = 0
    bar:SetScript('OnUpdate', function()
        -- auxForever: ten times a second is plenty for the texts and the quote timer (was every frame)
        if mode == NONE or GetTime() < next_update then return end
        next_update = GetTime() + .1
        -- a quote only lasts a short time; a lost server answer must not leave the bar stuck
        if mode == COMMODITY and state == QUOTED and C_AuctionHouse.GetQuoteDurationRemaining() == 0 then
            -- the server's price only holds for a short time (Confirm before buying on)
            reset({'The price quote expired', 'Nothing was bought'}, aux.color.red)
        elseif mode == COMMODITY and state == QUOTING and GetTime() - t0 > 10 then
            reset({'No answer from the auction house', 'Nothing was bought'}, aux.color.red)
        elseif mode == COMMODITY and state == BUYING and GetTime() - t0 > 10 then
            -- the purchase was confirmed and may still go through on a slow server: saying nothing
            -- was bought could make the player buy again (found with the slow test auction house)
            reset({'No answer from the auction house yet', 'It may still go through: check your mail before buying again'}, aux.color.red)
        end
        update()
    end)

    local icon_frame = CreateFrame('Frame', nil, bar, 'BackdropTemplate')
    gui.set_well_style(icon_frame)
    gui.set_size(icon_frame, 38, 38)
    icon_frame:SetPoint('LEFT', 10, 0)
    icon = icon_frame:CreateTexture(nil, 'ARTWORK')
    icon:SetPoint('TOPLEFT', 2, -2)
    icon:SetPoint('BOTTOMRIGHT', -2, 2)
    icon:SetTexCoord(.08, .92, .08, .92)

    name_label = gui.label(bar, gui.font_size.medium)
    name_label:SetTextColor(1, 1, 1)
    name_label:SetPoint('TOPLEFT', icon_frame, 'TOPRIGHT', 8, -2)
    name_label:SetWidth(150)
    name_label:SetJustifyH('LEFT')

    sub_label = gui.label(bar, gui.font_size.small)
    sub_label:SetPoint('BOTTOMLEFT', icon_frame, 'BOTTOMRIGHT', 8, 2)
    sub_label:SetWidth(150)
    sub_label:SetJustifyH('LEFT')

    chips = {}
    for i = 1, 4 do
        local chip = CreateFrame('Button', nil, bar, 'BackdropTemplate')
        gui.set_content_style(chip)
        gui.add_sheen(chip)
        gui.set_size(chip, 64, 42)
        if i == 1 then
            chip:SetPoint('LEFT', icon_frame, 'RIGHT', 170, 0)
        else
            chip:SetPoint('LEFT', chips[i - 1], 'RIGHT', 1, 0)
        end
        chip.amount = gui.label(chip, gui.font_size.medium)
        chip.amount:SetPoint('TOP', 0, -5)
        gui.text_color(chip.amount, aux.color.text.enabled)
        chip.cost = gui.label(chip, gui.font_size.small)
        chip.cost:SetPoint('BOTTOM', 0, 5)
        local highlight = chip:CreateTexture(nil, 'HIGHLIGHT')
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, .06)
        chip:SetScript('OnClick', function()
            if state == IDLE and current and current.quantities and current.quantities[i] then
                set_quantity(current.quantities[i])
                other_input:SetText(tostring(current.quantities[i]))
                other_input.overlay:SetText(other_input.formatter(other_input:GetText()))
                other_input:ClearFocus()
                update()
            end
        end)
        chip:Hide()
        chips[i] = chip
    end

    -- auxForever (0.5, FB-001): Darkhorse did not see that the gray "Other" box took typing. The box
    -- is now labeled QUANTITY, always shows how many you are buying (the buttons fill it in), sits a
    -- little wider (mockup approved by Tyler; the text cursor mark of the mockup looked like a bug in
    -- game, Tyler build 1, and was removed)
    other_input = gui.editbox(bar)
    other_input:SetPoint('LEFT', chips[4], 'RIGHT', 6, 0)
    other_input:SetWidth(92)
    other_input:SetHeight(42)
    other_input:SetNumeric(true)
    other_input:SetMaxLetters(5)
    other_input:SetAlignment('CENTER')
    other_input:SetFontSize(gui.font_size.large)
    other_input:SetTextInsets(4, 4, 14, 2)
    other_input.overlay:ClearAllPoints()
    other_input.overlay:SetPoint('BOTTOMLEFT', 4, 5)
    other_input.overlay:SetPoint('BOTTOMRIGHT', -4, 5)
    other_input.caption = gui.label(other_input, 10)
    other_input.caption:SetPoint('TOP', 0, -4)
    gui.text_color(other_input.caption, aux.color.label.enabled)
    other_input.caption:SetText('QUANTITY')
    other_input:SetScript('OnEnter', function(self) self.hovered = true end)
    other_input:SetScript('OnLeave', function(self) self.hovered = false end)
    other_input.focus_loss = function(self)
        -- left empty: show the quantity being bought again
        if self:GetText() == '' and current and current.quantity then
            self:SetText(tostring(current.quantity))
        end
    end
    other_input.formatter = function(text)
        return text == '' and aux.color.label.enabled'type' or text
    end
    M.other_input, M.chips, M.sub_label = other_input, chips, sub_label
    other_input.change = function(self)
        if state == IDLE and self:GetText() ~= '' then
            set_quantity(self:GetNumber())
            update()
        end
    end
    -- Enter buys, as the button does (unless the player cleared the box while idle)
    other_input.enter = function()
        if state ~= IDLE or other_input:GetText() ~= '' then
            primary_click()
        end
    end
    other_input.escape = function()
        if state ~= IDLE then
            reset({'Cancelled', 'Nothing was bought'}, aux.color.label.enabled)
        end
    end
    other_input:Hide()

    primary_button = gui.button(bar, gui.font_size.medium)
    primary_button:SetPoint('RIGHT', -10, 0)
    gui.set_size(primary_button, 160, 42)
    primary_button:SetScript('OnClick', function() primary_click() end)
    -- the gamepad's Y presses it on the Search tab (gamepad.lua)
    M.primary_button = primary_button

    cancel_button = gui.button(bar, gui.font_size.medium)
    cancel_button:SetPoint('RIGHT', primary_button, 'LEFT', -6, 0)
    gui.set_size(cancel_button, 80, 42)
    cancel_button:SetText('Cancel')
    cancel_button:SetScript('OnClick', function()
        reset({'Cancelled', 'Nothing was bought'}, aux.color.label.enabled)
        update()
    end)
    cancel_button:Hide()

    bid_button = gui.button(bar, gui.font_size.medium)
    bid_button:SetPoint('RIGHT', primary_button, 'LEFT', -6, 0)
    gui.set_size(bid_button, 90, 42)
    bid_button:SetScript('OnClick', function() bid_click() end)
    bid_button:Hide()
    -- for tests: what the Bid button shows when a bid is sent
    M.bid_button = bid_button

    line1 = gui.label(bar, gui.font_size.medium)
    line1:SetJustifyH('LEFT')
    gui.text_color(line1, aux.color.text.enabled)

    line2 = gui.label(bar, gui.font_size.small)
    line2:SetJustifyH('LEFT')
    lines_right = primary_button
    anchor_lines(icon_frame, 170)

    clear()
end
