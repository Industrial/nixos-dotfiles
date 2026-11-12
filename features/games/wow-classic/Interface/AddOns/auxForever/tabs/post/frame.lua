select(2, ...) 'aux.tabs.post'

local aux = require 'aux'
local info = require 'aux.util.info'
local money = require 'aux.util.money'
local gui = require 'aux.gui'
local listing = require 'aux.gui.listing'
local item_listing = require 'aux.gui.item_listing'
local search_tab = require 'aux.tabs.search'

frame = CreateFrame('Frame', nil, aux.frame)
frame:SetAllPoints(aux.frame.body)
frame:SetScript('OnUpdate', on_update)
frame:Hide()

frame.content = CreateFrame('Frame', nil, frame)
frame.content:SetPoint('TOP', frame, 'TOP', 0, -8)
frame.content:SetPoint('BOTTOMLEFT', aux.frame.content, 'BOTTOMLEFT', 0, 0)
frame.content:SetPoint('BOTTOMRIGHT', aux.frame.content, 'BOTTOMRIGHT', 0, 0)

frame.inventory = gui.panel(frame.content)
frame.inventory:SetWidth(212)
frame.inventory:SetPoint('TOPLEFT', 0, 0)
frame.inventory:SetPoint('BOTTOMLEFT', 0, 0)

frame.parameters = gui.panel(frame.content)
frame.parameters:SetHeight(214)
frame.parameters:SetPoint('TOPLEFT', frame.inventory, 'TOPRIGHT', 2.5, 0)
frame.parameters:SetPoint('TOPRIGHT', 0, 0)

-- Forever: the listings fill the height under the parameters, which grew with the window
frame.bid_listing = gui.panel(frame.content)
frame.bid_listing:SetPoint('TOPLEFT', frame.parameters, 'BOTTOMLEFT', 0, -2.5)
frame.bid_listing:SetPoint('BOTTOMLEFT', frame.inventory, 'BOTTOMRIGHT', 2.5, 0)
frame.bid_listing:Hide()

frame.buyout_listing = gui.panel(frame.content)
frame.buyout_listing:SetPoint('TOPLEFT', frame.parameters, 'BOTTOMLEFT', 0, -2.5)
frame.buyout_listing:SetPoint('BOTTOMLEFT', frame.inventory, 'BOTTOMRIGHT', 2.5, 0)
frame.buyout_listing:SetPoint('BOTTOMRIGHT', 0, 0)

do
    local checkbox = gui.checkbox(frame.inventory)
    checkbox:SetPoint('TOPLEFT', 49, -15)
    checkbox:SetScript('OnClick', function()
        refresh = true
    end)
    local label = gui.label(checkbox, gui.font_size.small)
    label:SetPoint('LEFT', checkbox, 'RIGHT', 4, 1)
    label:SetText('Show hidden items')
    show_hidden_checkbox = checkbox
end

gui.horizontal_line(frame.inventory, -45)

do
	local f = CreateFrame('Frame', nil, frame.inventory)
	f:SetPoint('TOPLEFT', 0, -51)
	f:SetPoint('BOTTOMRIGHT', 0, 0)
	inventory_listing = item_listing.new(
		f,
	    function(self, button)
	        if button == 'LeftButton' then
	            update_item(self.item_record)
	        elseif button == 'RightButton' then
	            aux.set_tab(1)
	            search_tab.set_filter(strlower(info.item(self.item_record.item_id).name) .. '/exact')
	            search_tab.execute(nil, false)
	        end
	    end,
	    function(item_record)
	        return item_record == selected_item
	    end
	)
end

bid_listing = listing.new(frame.bid_listing)
bid_listing:SetSelection(function(data)
	return selected_item and (data.record == get_bid_selection() or data.record.historical_value and get_bid_selection() and get_bid_selection().historical_value)
end)
-- auxForever (0.5, docs/clicks.md): the price lists follow the click standard. Click a price to use
-- it, click the chosen one again to let go of it; right-click searches the item like every other
-- row in aux. (Right-click used to clear the price and double-click set the quantity.)
function M.search_selected_item()
	-- the name is read first: leaving the Post tab clears selected_item (0.5 build 1 error)
	local name = selected_item and selected_item.name
	if name then
		aux.set_tab(1)
		search_tab.set_filter(strlower(name) .. '/exact')
		search_tab.execute(nil, false)
	end
end

local function price_click(is_selected, set_selection, row_data, button)
	if button == 'RightButton' then
		search_selected_item()
	elseif is_selected(row_data) then
		set_selection()
	else
		set_selection(row_data.record)
	end
	refresh = true
end

local function price_hint(is_selected)
	return function(st, row_data)
		GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
		gui.add_click_hint(GameTooltip, (is_selected(row_data) and 'Click again: let go of this price' or 'Click: use this price') .. gui.HINT_SEPARATOR .. 'Right-click: search', true)
		GameTooltip:Show()
	end
end

local function hide_hint()
	GameTooltip:Hide()
end

local function bid_selected(data)
	return selected_item and (data.record == get_bid_selection() or data.record.historical_value and get_bid_selection() and get_bid_selection().historical_value) and true or false
end
bid_listing:SetHandler('OnClick', function(table, row_data, column, button)
	price_click(bid_selected, set_bid_selection, row_data, button)
	if button ~= 'RightButton' then
		price_hint(bid_selected)(table, row_data)
	end
end)
bid_listing:SetHandler('OnEnter', price_hint(bid_selected))
bid_listing:SetHandler('OnLeave', hide_hint)

buyout_listing = listing.new(frame.buyout_listing)
-- auxForever: same structure as the other tables: units for sale (aux's Auctions and Stack Size
-- in one), time left, price, and its share of the usual price
buyout_listing:SetColInfo{
    {name='For sale', width=.18, align='CENTER'},
    {name='Time Left', width=.17, align='CENTER'},
    {name='Auction Buyout (per item)', width=.45, align='RIGHT'},
    {name='% of usual', width=.2, align='CENTER'},
}
buyout_listing:SetSelection(function(data)
	return selected_item and (data.record == get_buyout_selection() or data.record.historical_value and get_buyout_selection() and get_buyout_selection().historical_value)
end)
local function buyout_selected(data)
	return selected_item and (data.record == get_buyout_selection() or data.record.historical_value and get_buyout_selection() and get_buyout_selection().historical_value) and true or false
end
buyout_listing:SetHandler('OnClick', function(table, row_data, column, button)
	price_click(buyout_selected, set_buyout_selection, row_data, button)
	if button ~= 'RightButton' then
		price_hint(buyout_selected)(table, row_data)
	end
end)
buyout_listing:SetHandler('OnEnter', price_hint(buyout_selected))
buyout_listing:SetHandler('OnLeave', hide_hint)

-- auxForever (0.6, option A of the Post panel mockup, Tyler 2026-10-09): three columns. Left, what
-- is posted: the item, Count or Quantity, Duration, the post message and Hide from this list.
-- Middle, the price: Match lowest / Undercut with ?, narrow price fields with "% of usual" as plain
-- text, and a note on how the price was chosen. Right, a receipt: total, the auction house cut,
-- what you get, the vendor comparison (a red warning when a vendor pays more), the deposit, Post.
-- The widgets keep the names the posting logic in core.lua uses.
AUCTION_CUT = .05 -- the auction house keeps 5% of a sale
local LEFT_X = 12 -- the left column
local COUNT_X, DURATION_X = 99, 72 -- where the Count field and the Duration buttons start
local PRICE_X = 247 -- the middle column
local FIELD_X, FIELD_W = PRICE_X + 68, 104 -- the price fields
local USUAL_X = FIELD_X + FIELD_W + 8 -- the % of usual, left of the middle divider
local RECEIPT_X, RECEIPT_W = -264, 252 -- the right column, from the panel's right edge
local ROW1, ROW2 = -58, -90
local PRICE_ROW1, PRICE_ROW2 = -62, -96
local HEADER_Y = PRICE_ROW1 + 6 -- the bottom of PER ITEM, clear of the first field
-- for the layout test: the smallest window (1000 wide) leaves the panel about 777 wide (build 7:
-- the % column ran into the divider there, and PER ITEM into the first field)
M.price_layout = {usual_x = USUAL_X, divider_from_right = RECEIPT_X - 14, header_y = HEADER_Y, first_row = PRICE_ROW1}

local function small_button(parent, text, width, size)
    local btn = gui.button(parent, size or gui.font_size.medium)
    gui.set_size(btn, width or 26, 26)
    btn:SetText(text)
    return btn
end

-- a label in front of a row's control, at the left edge of its column
local function caption(parent, anchor, text, x)
    local label = gui.label(parent, gui.font_size.small)
    label:SetPoint('LEFT', anchor, 'LEFT', x, 0)
    label:SetText(text)
    return label
end

local function style_choice(btn, selected)
    gui.style_choice(btn, selected)
end

do
    local btn = gui.button(frame)
    btn:SetPoint('LEFT', aux.status_bar, 'RIGHT', 5, 0)
    btn:SetText('Refresh')
    btn:SetScript('OnClick', refresh_button_click)
    refresh_button = btn
end
do
	item = gui.item(frame.parameters)
    gui.set_size(item, 228, 40) -- stays inside the left column
    item:SetPoint('TOPLEFT', 8, -6)
    item:SetScale(.9)
    item.button:SetScript('OnEnter', function(self)
        if selected_item then
            info.set_tooltip(selected_item.link, self, 'ANCHOR_RIGHT')
        end
    end)
    item.button:SetScript('OnLeave', function()
        GameTooltip:Hide()
    end)
    local function select_cursor_item()
        local type, item_id, item_link = GetCursorInfo()
        if type == 'item' then
            select_item(info.link_price_key(item_link))
            ClearCursor()
        end
    end
    item.button:HookScript('OnReceiveDrag', select_cursor_item)
    item.button:HookScript('OnMouseDown', select_cursor_item)
    item.button:HookScript('OnClick', select_cursor_item)
    item.name:ClearAllPoints()
    item.name:SetPoint('TOPLEFT', item.button, 'TOPRIGHT', 10, -4)
    item.name:SetPoint('RIGHT', item, 'RIGHT', -10, 0)
    item.name:SetFont(gui.font, gui.font_size.large)
    local detail = gui.label(item, gui.font_size.small)
    detail:SetPoint('BOTTOMLEFT', item.button, 'BOTTOMRIGHT', 10, 4)
    item_detail = detail
end
do
    local checkbox = gui.checkbox(frame.parameters)
    checkbox:SetPoint('BOTTOMLEFT', LEFT_X, 12)
    checkbox:SetScript('OnClick', function(self)
        local settings = read_settings()
        settings.hidden = self:GetChecked()
        write_settings(settings)
        refresh = true
    end)
    local label = gui.label(checkbox, gui.font_size.small)
    label:SetPoint('LEFT', checkbox, 'RIGHT', 5, 0)
    label:SetText('Hide from this list')
    hide_checkbox = checkbox
end

-- a number with -, + and Max; everything is a child of the edit box so it shows and hides with it
local function stepper(caption_text)
    local editbox = gui.editbox(frame.parameters)
    gui.set_size(editbox, 44, 26)
    editbox:SetFontSize(17)
    editbox:SetAlignment('CENTER')
    editbox:SetNumeric(true)
    editbox.reset_text = '1'
    editbox.max_value = 1
    local minus = small_button(editbox, '-', 24)
    minus:SetPoint('RIGHT', editbox, 'LEFT', -3, 0)
    minus:SetScript('OnClick', function() editbox:SetNumber(editbox:GetNumber() - 1) end)
    local plus = small_button(editbox, '+', 24)
    plus:SetPoint('LEFT', editbox, 'RIGHT', 3, 0)
    plus:SetScript('OnClick', function() editbox:SetNumber(editbox:GetNumber() + 1) end)
    local max_button = small_button(editbox, 'Max', 38, gui.font_size.small)
    max_button:SetPoint('LEFT', plus, 'RIGHT', 3, 0)
    max_button:SetScript('OnClick', function() editbox:SetNumber(editbox.max_value) end)
    editbox.caption = caption(editbox, minus, caption_text, LEFT_X - (COUNT_X - 27))
    return editbox
end
do
    local editbox = stepper('Stack size')
    editbox.change = function(self)
        self:SetNumber(aux.bounded(1, self.max_value, self:GetNumber()))
        quantity_update(true)
    end
    editbox:SetScript('OnTabPressed', function()
        if not IsShiftKeyDown() then
            stack_count_input:SetFocus()
        end
    end)
    stack_size_input = editbox
end
do
    local editbox = stepper('Stacks')
    editbox.change = function(self)
        self:SetNumber(aux.bounded(1, self.max_value, self:GetNumber()))
        quantity_update()
    end
    editbox:SetScript('OnTabPressed', function()
        if IsShiftKeyDown() then
            return
        elseif unit_start_price_input:IsShown() then
            unit_start_price_input:SetFocus()
        else
            unit_buyout_price_input:SetFocus()
        end
    end)
    stack_count_input = editbox
end
do
    -- three buttons in place of the old dropdown; they answer the same calls as the dropdown did
    local holder = CreateFrame('Frame', nil, frame.parameters)
    gui.set_size(holder, 126, 26)
    holder.buttons = {}
    for i = 1, 3 do
        local btn = small_button(holder, '', 40, gui.font_size.small)
        btn:SetPoint('TOPLEFT', (i - 1) * 43, 0)
        btn:SetScript('OnClick', function() holder:SetIndex(i) end)
        holder.buttons[i] = btn
    end
    caption(holder, holder, 'Duration', LEFT_X - DURATION_X)
    function holder:SetOptions()
        for i, btn in ipairs(self.buttons) do
            btn:SetText(info.duration_hours(i) .. 'h')
        end
    end
    function holder:GetIndex()
        return self.index
    end
    function holder:SetIndex(index)
        local changed = index ~= self.index
        self.index = index
        for i, btn in ipairs(self.buttons) do
            style_choice(btn, i == index)
        end
        if changed and self.selection_change then
            self.selection_change()
        end
    end
    function holder:SetFocus() end
    holder.selection_change = function()
        duration_selection_change()
    end
    holder:SetOptions()
    duration_dropdown = holder
end
-- the lines between the three columns
for _, anchor in ipairs{{'TOPLEFT', PRICE_X - 15}, {'TOPRIGHT', RECEIPT_X - 14}} do
    local line = frame.parameters:CreateTexture(nil, 'ARTWORK')
    gui.texture_color(line, aux.color.panel.border)
    line:SetWidth(1)
    line:SetPoint('TOP', frame.parameters, anchor[1], anchor[2], -8)
    line:SetPoint('BOTTOM', frame.parameters, anchor[1] == 'TOPLEFT' and 'BOTTOMLEFT' or 'BOTTOMRIGHT', anchor[2], 8)
end

-- the heading over the price fields
do
    local label = gui.label(frame.parameters, gui.font_size.small)
    label:SetJustifyH('RIGHT')
    label:SetPoint('BOTTOMRIGHT', frame.parameters, 'TOPLEFT', FIELD_X + FIELD_W, HEADER_Y)
    label:SetText('PER ITEM')
    gui.text_color(label, aux.color.label.disabled)
    price_caption = label
end
do
    -- the pricing mode: Match lowest (default) or Undercut with the goblin
    local switch = CreateFrame('Frame', nil, frame.parameters, 'BackdropTemplate')
    -- auxForever (0.6, the UI Kit): a sunken track with one lit option
    gui.set_frame_style(switch, aux.color.status.track, aux.color.input.border)
    gui.set_size(switch, 204, 30)
    switch:SetPoint('TOPLEFT', PRICE_X, -8)
    local match = small_button(switch, 'Match lowest', 98)
    match:SetPoint('LEFT', 2, 0)
    local undercut = small_button(switch, 'Undercut', 100)
    undercut:SetPoint('LEFT', match, 'RIGHT', 2, 0)
    undercut:GetFontString():ClearAllPoints()
    undercut:GetFontString():SetPoint('LEFT', 30, 0)
    undercut:GetFontString():SetPoint('RIGHT', -6, 0)
    local goblin = undercut:CreateTexture(nil, 'ARTWORK')
    goblin:SetTexture([[Interface\AddOns\auxForever\textures\goblin.tga]])
    goblin:SetSize(18, 18)
    goblin:SetPoint('LEFT', 8, 0)
    match:SetScript('OnClick', function() set_undercut_mode(false) end)
    undercut:SetScript('OnClick', function() set_undercut_mode(true) end)
    function switch:SetChecked(on)
        for btn, selected in pairs{[match] = not on, [undercut] = on} do
            gui.style_choice(btn, selected)
            if not selected then
                btn:SetBackdropColor(0, 0, 0, 0)
                btn:SetBackdropBorderColor(0, 0, 0, 0)
            end
        end
        goblin:SetAlpha(on and 1 or .55)
    end
    switch.match_button, switch.undercut_button = match, undercut
    mode_switch = switch

    local help = small_button(frame.parameters, '?', 24, gui.font_size.medium)
    help:SetPoint('LEFT', switch, 'RIGHT', 8, 0)
    help:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
        GameTooltip:AddLine('Match lowest or undercut?')
        -- the newest listing selling first is not confirmed on Forever (E6 in docs/forever-auction-house.md)
        GameTooltip:AddLine('Matching the lowest price keeps prices from sliding. On the modern auction house the newest listing at a price is said to sell first, so matching may sell as fast as going below it. Not yet confirmed on Forever.', 1, 1, 1, true)
        GameTooltip:AddLine('Undercut goes one step below: 1 copper for trade goods, 1 silver for gear. It stays on until the auction house closes, and starts off each time it opens.', 1, 1, 1, true)
        GameTooltip:AddLine('/aux undercut for more', .6, .6, .6)
        GameTooltip:Show()
    end)
    help:SetScript('OnLeave', function() GameTooltip:Hide() end)
end

-- "125%" with "of usual" under it (Tyler, build 9): the price compared with the item's usual
-- (historical) price, beside its field
local function badge(parent)
    local f = CreateFrame('Frame', nil, parent)
    gui.set_size(f, 60, 30)
    local text = gui.label(f, gui.font_size.medium)
    text:SetPoint('TOPLEFT', 0, -1)
    f.text = text
    local under = gui.label(f, gui.font_size.small)
    under:SetPoint('BOTTOMLEFT', 0, 0)
    under:SetText('of usual')
    gui.text_color(under, aux.color.label.disabled)
    f.under = under
    function f:SetText(value)
        if value == '---' then
            text:SetText(aux.color.label.disabled('none'))
        else
            text:SetText(value)
        end
    end
    return f
end

local function price_input(get_price, set_price, on_user_input)
    local editbox = gui.editbox(frame.parameters)
    editbox:SetAlignment('RIGHT')
    editbox:SetFontSize(18)
    editbox:SetTextInsets(8, 9, 3, 3)
    editbox.formatter = function()
        return money.to_string(get_price(), true)
    end
    editbox.change = function(self, is_user_input)
        refresh = true
        if is_user_input then
            keep_player_price()
            on_user_input()
            set_price(money.from_string(self:GetText()) or 0)
        end
    end
    editbox.enter = function(self)
        self:ClearFocus()
    end
    editbox.focus_loss = function(self)
        self:SetText(money.to_string(get_price(), true, nil, nil, true))
    end
    editbox.caption = gui.label(editbox, gui.font_size.small)
    editbox.caption:SetPoint('LEFT', editbox, 'LEFT', PRICE_X - FIELD_X, 0)
    editbox.badge = badge(editbox)
    editbox.badge:SetPoint('LEFT', editbox, 'RIGHT', USUAL_X - FIELD_X - FIELD_W, 0)
    return editbox
end
do
    local editbox = price_input(get_unit_start_price, set_unit_start_price, function()
        set_bid_selection()
        set_buyout_selection()
    end)
    editbox.caption:SetText('Starting bid')
    editbox:SetScript('OnTabPressed', function()
	    if IsShiftKeyDown() then
		    stack_count_input:SetFocus()
	    else
		    unit_buyout_price_input:SetFocus()
	    end
    end)
    local change = editbox.change
    editbox.change = function(self, is_user_input)
        change(self, is_user_input)
        unit_buyout_price_input.reset_text = self:GetText()
    end
    start_price_percentage = editbox.badge
    unit_start_price_input = editbox
end
do
    local editbox = price_input(get_unit_buyout_price, set_unit_buyout_price, function()
        set_buyout_selection()
    end)
    editbox.caption:SetText('Buyout')
    editbox:SetScript('OnTabPressed', function()
        if IsShiftKeyDown() then
            if unit_start_price_input:IsShown() then
                unit_start_price_input:SetFocus()
            else
                stack_count_input:SetFocus()
            end
        end
    end)
    local change = editbox.change
    editbox.change = function(self, is_user_input)
        change(self, is_user_input)
        unit_start_price_input.reset_text = self:GetText()
    end
    buyout_price_percentage = editbox.badge
    unit_buyout_price_input = editbox
end
do
    -- how the price was chosen; a second line when gear's bid equals its buyout
    local label = gui.label(frame.parameters, gui.font_size.small)
    label:SetJustifyH('LEFT')
    label:SetJustifyV('TOP')
    label:SetWordWrap(true)
    price_note = label
end
do
    -- auxForever (0.5, FB-003): what happened to the last post, or why Post is faded; left column,
    -- under Duration, above the line
    local label = gui.label(frame.parameters, gui.font_size.small)
    label:SetJustifyH('LEFT')
    label:SetJustifyV('TOP')
    -- two lines when needed (a gui.label is one line by default, which cut the text off, build 2)
    label:SetWordWrap(true)
    label:SetPoint('TOPLEFT', frame.parameters, 'TOPLEFT', LEFT_X + 2, ROW2 - 32)
    label:SetPoint('BOTTOMRIGHT', frame.parameters, 'TOPLEFT', PRICE_X - 28, -180)
    post_message = label
end

do
    local btn = gui.button(frame.parameters, gui.font_size.large)
    btn:SetPoint('BOTTOMRIGHT', -12, 10)
    gui.set_size(btn, RECEIPT_W, 30)
    btn:SetText('Post')
    gui.set_primary(btn)
    btn:SetScript('OnClick', post_auction)
    -- auxForever (0.5): hovering a faded Post button says why (Tyler, build 3: "hovering the greyed
    -- out button does nothing"); the same reason is shown in the left column
    btn:SetMotionScriptsWhileDisabled(true)
    btn:SetScript('OnEnter', function(self)
        local reason = disabled_reason()
        if reason and not self:IsEnabled() then
            GameTooltip:SetOwner(self, 'ANCHOR_TOP')
            GameTooltip:AddLine(reason, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btn:SetScript('OnLeave', function() GameTooltip:Hide() end)
    -- exported for the gamepad's Y (gamepad.lua)
    M.post_button = btn
end
-- the receipt: a label on the left of the right column and its amount on the right
do
    local function row(y, size)
        local label = gui.label(frame.parameters, size or gui.font_size.small)
        label:SetPoint('TOPLEFT', frame.parameters, 'TOPRIGHT', RECEIPT_X, y)
        gui.text_color(label, aux.color.label.enabled)
        local amount = gui.label(frame.parameters, size or gui.font_size.medium)
        amount:SetJustifyH('RIGHT')
        amount:SetPoint('TOPRIGHT', frame.parameters, 'TOPRIGHT', -12, y)
        gui.text_color(amount, aux.color.text.enabled)
        return label, amount
    end
    -- "Total, 6 items" and the total
    posting_summary, total_summary = row(-12)
    -- the auction house cut, money going out
    cut_label, cut_summary = row(-32)
    cut_label:SetText('Auction house cut ' .. AUCTION_CUT * 100 .. '%')
    local line = frame.parameters:CreateTexture(nil, 'ARTWORK')
    gui.texture_color(line, aux.color.panel.border)
    line:SetHeight(1)
    line:SetPoint('TOPLEFT', frame.parameters, 'TOPRIGHT', RECEIPT_X, -52)
    line:SetPoint('TOPRIGHT', frame.parameters, 'TOPRIGHT', -12, -52)
    receipt_line = line
    -- what the sale brings in, larger; green, or red when a vendor pays more
    net_label, net_summary = row(-60, gui.font_size.large)
    -- the label a size smaller, moved down so the two sit on one line
    net_label:SetFont(gui.font, gui.font_size.medium)
    net_label:SetPoint('TOPLEFT', frame.parameters, 'TOPRIGHT', RECEIPT_X, -62)
    gui.text_color(net_label, aux.color.text.enabled)
    net_label:SetText('You get')
    -- under it: the amount per item and what a vendor pays, when the auction house pays more
    net_detail = gui.label(frame.parameters, gui.font_size.small)
    net_detail:SetPoint('TOPLEFT', frame.parameters, 'TOPRIGHT', RECEIPT_X, -84)
    net_detail:SetPoint('TOPRIGHT', frame.parameters, 'TOPRIGHT', -12, -84)
    net_detail:SetJustifyH('LEFT')
    gui.text_color(net_detail, aux.color.label.disabled)
    -- Tyler (2026-10-09): when a vendor pays more, players must not miss it; a red box with the
    -- warning triangle in place of the gray line
    local warning = CreateFrame('Frame', nil, frame.parameters, 'BackdropTemplate')
    gui.set_frame_style(warning, function() local r, g, b = aux.color.red(); return r, g, b, .16 end, aux.color.red)
    warning:SetPoint('TOPLEFT', frame.parameters, 'TOPRIGHT', RECEIPT_X, -102)
    warning:SetPoint('TOPRIGHT', frame.parameters, 'TOPRIGHT', -12, -102)
    warning:SetHeight(26)
    local icon = warning:CreateTexture(nil, 'ARTWORK')
    icon:SetTexture([[Interface\AddOns\auxForever\textures\warning.tga]])
    icon:SetSize(20, 20)
    icon:SetPoint('LEFT', 6, 0)
    gui.vertex_color(icon, aux.color.red)
    local text = gui.label(warning, gui.font_size.medium)
    text:SetPoint('LEFT', icon, 'RIGHT', 6, 0)
    gui.text_color(text, aux.color.red)
    text:SetText('Vendor pays more')
    warning.amount = gui.label(warning, gui.font_size.medium)
    warning.amount:SetJustifyH('RIGHT')
    warning.amount:SetPoint('RIGHT', -8, 0)
    gui.text_color(warning.amount, aux.color.text.enabled)
    warning:Hide()
    vendor_warning = warning
    -- the deposit, just above Post: paid now, back if the item sells
    deposit_label, deposit = row(-154)
    gui.text_color(deposit_label, aux.color.label.disabled)
    deposit_label:SetText('Deposit now, back if it sells')
    -- the deposit explained on mouse over (a label cannot take the mouse, so a frame over the row)
    local hover = CreateFrame('Frame', nil, frame.parameters)
    hover:SetPoint('TOPLEFT', deposit_label, 'TOPLEFT')
    hover:SetPoint('BOTTOMRIGHT', deposit, 'BOTTOMRIGHT')
    hover:EnableMouse(true)
    hover:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_TOP')
        GameTooltip:AddLine('Deposit')
        GameTooltip:AddLine('Paid when you post. You get it back when the item sells; it is kept if the auction expires or you cancel it.', 1, 1, 1, true)
        GameTooltip:Show()
    end)
    hover:SetScript('OnLeave', function() GameTooltip:Hide() end)
end

-- trade goods: a quantity and one price; gear: a count, a starting bid and a buyout
function M.layout_parameters(commodity)
    local function at(region, y, x, width)
        region:ClearAllPoints()
        region:SetPoint('TOPLEFT', frame.parameters, 'TOPLEFT', x, y)
        if width then
            region:SetWidth(width)
        end
    end
    at(stack_count_input, ROW1, COUNT_X)
    at(duration_dropdown, ROW2, DURATION_X)
    -- the note fills the middle column, between the two dividers
    local function note(y)
        price_note:ClearAllPoints()
        price_note:SetPoint('TOPLEFT', frame.parameters, 'TOPLEFT', PRICE_X, y)
        price_note:SetPoint('BOTTOMRIGHT', frame.parameters, 'BOTTOMRIGHT', RECEIPT_X - 28, 10)
    end
    if commodity then
        stack_count_input.caption:SetText('Quantity')
        at(unit_buyout_price_input, PRICE_ROW1, FIELD_X, FIELD_W)
        unit_buyout_price_input:SetHeight(32)
        unit_buyout_price_input:SetFontSize(20)
        unit_buyout_price_input.caption:SetText('Price')
        note(PRICE_ROW1 - 40)
    else
        stack_count_input.caption:SetText('Count')
        at(unit_start_price_input, PRICE_ROW1, FIELD_X, FIELD_W)
        unit_start_price_input:SetHeight(28)
        at(unit_buyout_price_input, PRICE_ROW2, FIELD_X, FIELD_W)
        unit_buyout_price_input:SetHeight(28)
        unit_buyout_price_input:SetFontSize(18)
        unit_buyout_price_input.caption:SetText('Buyout')
        note(PRICE_ROW2 - 36)
    end
end
layout_parameters(true)

-- the bid column (/aux post bid, Settings): bids and buyouts side by side, or buyouts alone. Applied
-- at login and again whenever the setting changes (0.6: it used to need a reload).
function M.apply_bid_layout()
    if aux.account_data.post_bid then
        frame.bid_listing:Show()
        bid_listing:SetColInfo{
            {name='For sale', width=.2, align='CENTER'},
            {name='Time\nLeft', width=.15, align='CENTER'},
            {name='Auction Bid\n' .. (aux.account_data.post_bid == 'unit' and '(per item)' or '(per stack)'), width=.43, align='RIGHT'},
            {name='% of\nusual', width=.22, align='CENTER'},
        }
        -- side by side, each half of the space under the parameters
        frame.bid_listing:SetPoint('TOPRIGHT', frame.parameters, 'BOTTOM', -1.25, -2.5)
        frame.buyout_listing:ClearAllPoints()
        frame.buyout_listing:SetPoint('TOPLEFT', frame.parameters, 'BOTTOM', 1.25, -2.5)
        frame.buyout_listing:SetPoint('BOTTOMRIGHT', 0, 0)
        buyout_listing:SetColInfo{
            {name='For sale', width=.2, align='CENTER'},
            {name='Time\nLeft', width=.15, align='CENTER'},
            {name='Auction Buyout\n(per item)', width=.43, align='RIGHT'},
            {name='% of\nusual', width=.22, align='CENTER'},
        }
    else
        frame.bid_listing:Hide()
        frame.buyout_listing:ClearAllPoints()
        frame.buyout_listing:SetPoint('TOPLEFT', frame.parameters, 'BOTTOMLEFT', 0, -2.5)
        frame.buyout_listing:SetPoint('BOTTOMLEFT', frame.inventory, 'BOTTOMRIGHT', 2.5, 0)
        frame.buyout_listing:SetPoint('BOTTOMRIGHT', 0, 0)
        buyout_listing:SetColInfo{
            {name='For sale', width=.18, align='CENTER'},
            {name='Time Left', width=.17, align='CENTER'},
            {name='Auction Buyout (per item)', width=.45, align='RIGHT'},
            {name='% of usual', width=.2, align='CENTER'},
        }
    end
    -- the tables are filled again on the next update
    refresh = true
end

function aux.event.AUX_LOADED()
	mode_switch:SetChecked(aux.account_data.post_undercut)
	apply_bid_layout()
end