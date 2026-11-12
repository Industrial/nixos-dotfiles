select(2, ...) 'aux.tabs.search'

local aux = require 'aux'
local info = require 'aux.util.info'
local completion = require 'aux.util.completion'
local filter_util = require 'aux.util.filter'
local scan = require 'aux.core.scan'
local gui = require 'aux.gui'
local listing = require 'aux.gui.listing'
local auction_listing = require 'aux.gui.auction_listing'
local buy_bar = require 'aux.gui.buy_bar'

FILTER_SPACING = 27
SUBTAB_WIDTH = 150

frame = CreateFrame('Frame', nil, aux.frame)
frame:SetAllPoints(aux.frame.body)
frame:SetScript('OnUpdate', on_update)
frame:Hide()

frame.filter = gui.panel(frame)
frame.filter:SetAllPoints(aux.frame.content)

frame.results = gui.panel(frame)
frame.results:SetAllPoints(aux.frame.content)

-- the results list sits above the buy bar
frame.results.list = CreateFrame('Frame', nil, frame.results)
frame.results.list:SetPoint('TOPLEFT', 0, 0)
frame.results.list:SetPoint('BOTTOMRIGHT', 0, buy_bar.HEIGHT + 4)

frame.saved = CreateFrame('Frame', nil, frame)
frame.saved:SetAllPoints(aux.frame.content)
frame.saved:SetScript('OnUpdate', function()
    -- only while a favorite is being dragged with Alt held
    if dragged_search and not IsAltKeyDown() then
        dragged_search = nil
    end
end)

-- Forever: the two lists share the width, so they follow the window size
frame.saved.favorite = gui.panel(frame.saved)
frame.saved.favorite:SetPoint('TOPLEFT', 0, 0)
frame.saved.favorite:SetPoint('BOTTOMRIGHT', frame.saved, 'BOTTOM', -1.25, 0)

frame.saved.recent = gui.panel(frame.saved)
frame.saved.recent:SetPoint('TOPLEFT', frame.saved, 'TOP', 1.25, 0)
frame.saved.recent:SetPoint('BOTTOMRIGHT', 0, 0)

do
    local btn = gui.button(frame, 25)
    btn:SetPoint('TOPLEFT', 5, -8)
    btn:SetWidth(30)
    btn:SetHeight(25)
    btn:SetText('<')
    btn:SetScript('OnClick', previous_search)
    previous_button = btn
end
do
    -- auxForever: opens the quick search menu (quick.lua)
    local btn = gui.button(frame, 25)
    btn:SetPoint('LEFT', previous_button, 'RIGHT', 4, 0)
    btn:SetWidth(42)
    btn:SetHeight(25)
    local clock = btn:CreateTexture(nil, 'ARTWORK')
    clock:SetTexture([[Interface\AddOns\auxForever\textures\clock.tga]])
    clock:SetSize(16, 16)
    clock:SetPoint('LEFT', 7, 0)
    local chevron = btn:CreateTexture(nil, 'ARTWORK')
    chevron:SetTexture([[Interface\AddOns\auxForever\textures\chevron.tga]])
    chevron:SetSize(11, 11)
    chevron:SetPoint('LEFT', clock, 'RIGHT', 3, 0)
    btn.icons = {clock, chevron}
    btn:SetScript('OnClick', function() toggle_quick_menu() end)
    btn:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM')
        GameTooltip:AddLine('Quick searches')
        GameTooltip:AddLine('Your pinned and recent searches', 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript('OnLeave', function() GameTooltip:Hide() end)
    history_button = btn
end
do
    local btn = gui.button(frame, 25)
    btn:SetPoint('LEFT', history_button, 'RIGHT', 4, 0)
    btn:SetWidth(30)
    btn:SetHeight(25)
    btn:SetText('>')
    btn:SetScript('OnClick', next_search)
    next_button = btn
end
do
    -- auxForever: Live mode. The button shows what it is doing: "Updating" during a round, then a
    -- countdown to the next round ("Live 4s"), or "Paused".
	local btn = gui.button(frame, gui.font_size.small)
	btn:SetHeight(25)
	btn:SetWidth(70)
    btn:SetText('Live')
	btn:SetScript('OnClick', function()
        toggle_live()
	end)
    btn:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM')
        GameTooltip:AddLine('Live')
        GameTooltip:AddLine('Repeats the search every ' .. LIVE_INTERVAL .. ' seconds and shows what is listed now.', 1, 1, 1, true)
        GameTooltip:AddLine('A new auction matching one of your alert favorites brings up an alert.', 1, 1, 1, true)
        GameTooltip:AddLine('It holds while you are on another tab.', 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript('OnLeave', function() GameTooltip:Hide() end)
	mode_button = btn
end
do
    local btn = gui.button(frame)
    btn:SetHeight(25)
    btn:SetPoint('TOPRIGHT', -5, -8)
    btn:SetText('Search')
    gui.set_primary(btn)
    btn:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
    btn:SetScript('OnClick', function(_, button)
        if button == 'RightButton' then
            set_filter(current_search().filter_string)
        end
        execute()
    end)
    start_button = btn
end
do
    local btn = gui.button(frame)
    btn:SetHeight(25)
    btn:SetPoint('TOPRIGHT', -5, -8)
    btn:SetText('Pause')
    btn:SetScript('OnClick', function()
        pause()
    end)
    stop_button = btn
end
do
    local btn = gui.button(frame)
    btn:SetHeight(25)
    btn:SetPoint('RIGHT', start_button, 'LEFT', -4, 0)
    btn:SetText('Resume')
    btn:SetScript('OnClick', function()
        execute(nil, true)
    end)
    resume_button = btn
end
do
    -- auxForever: Fast reads each item once with its lowest price; Full reads every auction
    local function tooltip(self, title, ...)
        GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM')
        GameTooltip:AddLine(title)
        for _, line in ipairs{...} do
            GameTooltip:AddLine(line, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end
    local fast = gui.button(frame, gui.font_size.small)
    fast:SetHeight(25)
    fast:SetWidth(42)
    fast:SetText('Fast')
    fast:SetScript('OnClick', function() set_full_search(false) end)
    fast:SetScript('OnEnter', function(self)
        tooltip(self, 'Fast', 'Lists each item once with its lowest price. Click an item to see its auctions.',
            'Searches for one exact item, or using seller, time left or bid, read every auction anyway.')
    end)
    fast:SetScript('OnLeave', function() GameTooltip:Hide() end)
    fast_button = fast
    local full = gui.button(frame, gui.font_size.small)
    full:SetHeight(25)
    full:SetWidth(42)
    full:SetText('Full')
    fast:SetPoint('RIGHT', full, 'LEFT', -2, 0)
    full:SetScript('OnClick', function() set_full_search(true) end)
    full:SetScript('OnEnter', function(self)
        tooltip(self, 'Full', 'Reads every auction of every item, as aux always did. Slow on big searches.')
    end)
    full:SetScript('OnLeave', function() GameTooltip:Hide() end)
    full_button = full
end
do
	local editbox = gui.editbox(frame)
    editbox:SetPoint('LEFT', mode_button, 'RIGHT', 4, 0)
	editbox.formatter = function(str)
		-- an empty bar stays empty: aux writes an empty search as "<>" (every item), which showed in
		-- the bar after clearing it and clicking elsewhere (Tyler, 0.8 build 7)
		if aux.trim(str or '') == '' then
			return ''
		end
		local queries = filter_util.queries(str)
		return queries and aux.join(aux.map(aux.copy(queries), function(query) return query.prettified end), ';') or aux.color.red(str)
	end
	editbox.complete = completion.complete_filter
    editbox.escape = function(self) self:SetText(current_search().filter_string or '') end
	editbox:SetHeight(25)
	editbox.char = function(self)
        self:complete()
	end
	editbox:SetScript('OnTabPressed', function(self)
        self:HighlightText(0, 0) -- TODO more edit features, shift backspace or something
	end)
	editbox.enter = execute
    local function search_cursor_item()
        local type, item_id = GetCursorInfo()
        if type == 'item' then
            set_filter(strlower(info.item(item_id).name) .. '/exact')
            execute(nil, false)
            ClearCursor()
        end
    end
    editbox:HookScript('OnReceiveDrag', search_cursor_item)
    editbox:HookScript('OnMouseDown', search_cursor_item)
	search_box = editbox
    -- auxForever: a magnifier at the start of the search bar
    local icon = editbox:CreateTexture(nil, 'OVERLAY')
    icon:SetTexture([[Interface\AddOns\auxForever\textures\search.tga]])
    icon:SetSize(14, 14)
    icon:SetPoint('LEFT', 7, 0)
    gui.vertex_color(icon, aux.color.label.enabled)
    editbox:SetTextInsets(26, 1.5, 3, 3)
    editbox.overlay:SetPoint('LEFT', 26, 0)
    search_icon = icon
end
do
    gui.horizontal_line(frame, -40)
end
do
    local btn = gui.button(frame, gui.font_size.medium)
    btn:SetPoint('BOTTOMLEFT', aux.frame.content, 'TOPLEFT', 8, 7)
    btn:SetWidth(SUBTAB_WIDTH)
    btn:SetHeight(26)
    btn:SetText('Search Results')
    btn:SetScript('OnClick', function() set_subtab(RESULTS) end)
    search_results_button = btn
end
do
    local btn = gui.button(frame, gui.font_size.medium)
    btn:SetPoint('TOPLEFT', search_results_button, 'TOPRIGHT', 2, 0)
    btn:SetWidth(SUBTAB_WIDTH)
    btn:SetHeight(26)
    btn:SetText('Saved Searches')
    btn:SetScript('OnClick', function() set_subtab(SAVED) end)
    saved_searches_button = btn
end
do
    local btn = gui.button(frame, gui.font_size.medium)
    btn:SetPoint('TOPLEFT', saved_searches_button, 'TOPRIGHT', 2, 0)
    btn:SetWidth(SUBTAB_WIDTH)
    btn:SetHeight(26)
    btn:SetText('Filter Builder')
    btn:SetScript('OnClick', function() set_subtab(FILTER) end)
    new_filter_button = btn
end
do
    -- auxForever: what the shown results hold, e.g. "11 price levels, 6,180 for sale, searched 2m ago"
    local label = gui.label(frame, gui.font_size.small)
    label:SetPoint('TOPLEFT', new_filter_button, 'TOPRIGHT', 12, 0)
    label:SetPoint('BOTTOMRIGHT', aux.frame.content, 'TOPRIGHT', -10, 8)
    label:SetJustifyH('RIGHT')
    gui.text_color(label, aux.color.label.enabled)
    results_summary_label = label
end
do
    local btn = gui.button(frame.results)
    btn:SetPoint('LEFT', aux.status_bar, 'RIGHT', 5, 0)
    btn:SetText('Clear')
    btn:SetScript('OnClick', function()
        while tremove(current_search().records) do end
        current_search().table:SetDatabase()
        current_search().complete = false
        update_done()
    end)
    clear_button = btn
end
do
    -- auxForever: a recipe search's cost, in the free space of the bottom bar under its results
    -- (it crowded the line next to the sub tabs and was cut off there)
    local label = gui.label(frame.results, gui.font_size.medium)
    label:SetPoint('LEFT', clear_button, 'RIGHT', 14, 0)
    label:SetPoint('RIGHT', aux.credit_label, 'LEFT', -16, 0)
    label:SetJustifyH('LEFT')
    gui.text_color(label, aux.color.label.enabled)
    recipe_label = label
end
buy_bar.create(frame.results)
do
    local btn = gui.button(frame.saved)
    btn:SetPoint('LEFT', aux.status_bar, 'RIGHT', 5, 0)
    btn:SetText('Favorite')
    btn:SetScript('OnClick', function()
        save_favorite(search_box:GetText())
    end)
end
do
    local editbox = gui.editbox(frame.filter)
    editbox.complete_item = completion.complete(function() return aux.account_data.auctionable_items end)
    editbox:SetPoint('TOPLEFT', 14, -FILTER_SPACING - 34)
    editbox:SetWidth(240)
    editbox.char = function(self)
        if blizzard_query.exact then
            self:complete_item()
        end
    end
    editbox.change = function() sync_builder() end
    editbox:SetScript('OnTabPressed', function()
        if not IsShiftKeyDown() then
            if blizzard_query.exact then
                editbox:ClearFocus()
            else
                min_level_input:SetFocus()
            end
        end
    end)
    editbox.enter = function() editbox:ClearFocus() end
    local label = gui.label(editbox, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
    label:SetText('Name')
    name_input = editbox
end
do
    local checkbox = gui.checkbox(frame.filter)
    checkbox:SetPoint('LEFT', name_input, 'RIGHT', 14, 0)
    checkbox:SetScript('OnClick', function()
        exact_update()
        sync_builder()
    end)
    local label = gui.label(checkbox, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', checkbox, 'TOPLEFT', -2, 1)
    label:SetText('Exact')
    exact_checkbox = checkbox
end
do
    local editbox = gui.editbox(frame.filter)
    editbox:SetPoint('TOPLEFT', name_input, 'BOTTOMLEFT', 0, -FILTER_SPACING)
    editbox:SetWidth(100)
    editbox:SetAlignment('CENTER')
    editbox:SetNumeric(true)
    editbox:SetScript('OnTabPressed', function()
        if IsShiftKeyDown() then
            name_input:SetFocus()
        else
            max_level_input:SetFocus()
        end
    end)
    editbox.enter = function() editbox:ClearFocus() end
    editbox.change = function(self)
	    local valid_level = valid_level(self:GetText())
	    if tostring(valid_level) ~= self:GetText() then
            self:SetText(valid_level or '')
	    end
        sync_builder()
    end
    local label = gui.label(editbox, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
    label:SetText('Level, from and to')
    min_level_input = editbox
end
do
    local editbox = gui.editbox(frame.filter)
    editbox:SetPoint('TOPLEFT', min_level_input, 'TOPRIGHT', 22, 0)
    editbox:SetWidth(100)
    editbox:SetAlignment('CENTER')
    editbox:SetNumeric(true)
    editbox:SetScript('OnTabPressed', function()
        if IsShiftKeyDown() then
            min_level_input:SetFocus()
        else
            class_dropdown:SetFocus()
        end
    end)
    editbox.enter = function() editbox:ClearFocus() end
    editbox.change = function(self)
	    local valid_level = valid_level(self:GetText())
	    if tostring(valid_level) ~= self:GetText() then
            self:SetText(valid_level or '')
	    end
        sync_builder()
    end
    local label = gui.label(editbox, gui.font_size.medium)
    label:SetPoint('RIGHT', editbox, 'LEFT', -5, 0)
    label:SetText('to')
    max_level_input = editbox
end
do
    local checkbox = gui.checkbox(frame.filter)
    checkbox:SetPoint('LEFT', max_level_input, 'RIGHT', 14, 0)
    checkbox:SetScript('OnClick', function() sync_builder() end)
    local label = gui.label(checkbox, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', checkbox, 'TOPLEFT', -2, 1)
    label:SetText('I can use')
    usable_checkbox = checkbox
end
do
    local dropdown = gui.dropdown(frame.filter)
    dropdown.selection_change = function() class_selection_change() end
    dropdown.enter = dropdown.ClearFocus
    dropdown:SetPoint('TOPLEFT', min_level_input, 'BOTTOMLEFT', 0, -FILTER_SPACING)
    dropdown:SetWidth(296)
    dropdown:SetScript('OnTabPressed', function()
        if IsShiftKeyDown() then
            max_level_input:SetFocus()
        else
            if subclass_dropdown:IsVisible() then
                subclass_dropdown:SetFocus()
            else
                quality_dropdown:SetFocus()
            end
        end
    end)
    local label = gui.label(dropdown, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, 1)
    label:SetText('Category')
    class_dropdown = dropdown
end
do
    local dropdown = gui.dropdown(frame.filter)
    dropdown.selection_change = function() subclass_selection_change() end
    dropdown.enter = dropdown.ClearFocus
    dropdown:SetPoint('TOPLEFT', class_dropdown, 'BOTTOMLEFT', 0, -FILTER_SPACING)
    dropdown:SetWidth(296)
    dropdown:SetScript('OnTabPressed', function()
        if IsShiftKeyDown() then
            class_dropdown:SetFocus()
        else
            if slot_dropdown:IsVisible() then
                slot_dropdown:SetFocus()
            else
                quality_dropdown:SetFocus()
            end
        end
    end)
    local label = gui.label(dropdown, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, 1)
    label:SetText('Type')
    subclass_dropdown = dropdown
end
do
    local dropdown = gui.dropdown(frame.filter)
    dropdown.selection_change = function() sync_builder() end
    dropdown.enter = dropdown.ClearFocus
    dropdown:SetPoint('TOPLEFT', subclass_dropdown, 'BOTTOMLEFT', 0, -FILTER_SPACING)
    dropdown:SetWidth(296)
    dropdown:SetScript('OnTabPressed', function()
        if IsShiftKeyDown() then
            subclass_dropdown:SetFocus()
        else
            quality_dropdown:SetFocus()
        end
    end)
    local label = gui.label(dropdown, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, 1)
    label:SetText('Slot')
    slot_dropdown = dropdown
end
do
    local dropdown = gui.dropdown(frame.filter)
    dropdown.selection_change = function() sync_builder() end
    dropdown.enter = dropdown.ClearFocus
    dropdown:SetPoint('TOPLEFT', slot_dropdown, 'BOTTOMLEFT', 0, -FILTER_SPACING)
    dropdown:SetWidth(296)
    dropdown:SetScript('OnTabPressed', function()
        if IsShiftKeyDown() then
            if slot_dropdown:IsVisible() then
                slot_dropdown:SetFocus()
            elseif subclass_dropdown:IsVisible() then
                subclass_dropdown:SetFocus()
            else
                class_dropdown:SetFocus()
            end
        else
            dropdown:ClearFocus()
        end
    end)
    local label = gui.label(dropdown, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, 1)
    label:SetText('Rarity, at least')
    quality_dropdown = dropdown
end
gui.vertical_line(frame.filter, 332)
tables = {}
for _ = 1, 5 do
    local table = auction_listing.new(frame.results.list, 19, auction_listing.search_columns)
    table:SetHandler('OnClick', function(row, button)
	    if IsAltKeyDown() and aux.account_data.action_shortcuts then
		    local selection = current_search().table:GetSelection()
		    if selection and selection.record == row.record then
			    if button == 'LeftButton' then
	                buy_bar.primary_click()
	            elseif button == 'RightButton' then
	                buy_bar.bid_click()
			    end
		    end
	    elseif button == 'RightButton' then
		    set_filter(strlower(info.item(row.record.item_id).name) .. '/exact')
		    execute(nil, false)
	    end
    end)
    table:SetHandler('OnSelectionChanged', function(rt, datum)
        -- nothing selected (the selected row clicked again): on_update empties the buy bar
        if not datum then return end
        find_auction(datum.record)
    end)
    table.alt_hint = 'Alt-click: buy' .. gui.HINT_SEPARATOR .. 'Alt-right-click: bid'
    table:Hide()
    tinsert(tables, table)
end

favorite_searches_listing = listing.new(frame.saved.favorite)
favorite_searches_listing:SetColInfo{{name='Alert', width=.07, align='CENTER'}, {name='Favorite Searches', width=.93}}

recent_searches_listing = listing.new(frame.saved.recent)
recent_searches_listing:SetColInfo{{name='Recent Searches', width=1}}

for listing in aux.iter(favorite_searches_listing, recent_searches_listing) do
	for k, v in pairs(handlers) do
		listing:SetHandler(k, v)
	end
end

