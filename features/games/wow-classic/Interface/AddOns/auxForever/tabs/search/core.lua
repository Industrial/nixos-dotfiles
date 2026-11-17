select(2, ...) 'aux.tabs.search'

local aux = require 'aux'
local info = require 'aux.util.info'
local gui = require 'aux.gui'

local tab = aux.tab 'Search'

RESULTS, SAVED, FILTER = aux.enum(3)

function aux.event.AUX_LOADED()
	set_subtab(SAVED)
end

function tab.OPEN()
    frame:Show()
    update_search_listings()
    update_done()
    update_fast_switch()
    resume_held_live()
end

function tab.CLOSE()
    hold_live()
    current_search().table:SetSelectedRecord()
    hide_quick_menu()
    frame:Hide()
    update_done()
end

-- An exact search for an item by its ID: what a right-click on a row does in every tab. Returns
-- false when the game does not know the item (it has dropped the item's data): nothing happens
-- then, where the right-click raised an error (second pass of the outside review, 0.8.2.1).
function M.search_item(item_id)
	local item_info = item_id and info.item(item_id)
	if not item_info then
		return false
	end
	set_filter(strlower(item_info.name) .. '/exact')
	execute(nil, false)
	return true
end

function tab.USE_ITEM(item_id)
	search_item(item_id)
end

function set_subtab(tab)
    -- auxForever (0.6): the open sub tab has the gold outline
    gui.apply_look(search_results_button, tab == RESULTS and 'selected' or 'tab')
    gui.apply_look(saved_searches_button, tab == SAVED and 'selected' or 'tab')
    gui.apply_look(new_filter_button, tab == FILTER and 'selected' or 'tab')
    frame.results:Hide()
    frame.saved:Hide()
    frame.filter:Hide()

    if tab == RESULTS then
        frame.results:Show()
    elseif tab == SAVED then
        frame.saved:Show()
    elseif tab == FILTER then
        frame.filter:Show()
        load_builder()
    end
    update_done()
    update_results_summary(true)
end

function M.set_filter(filter_string)
	search_box:SetFocus()
    search_box:SetText(filter_string)
end

function add_filter(filter_string)
    local old_filter_string = search_box:GetText()
    old_filter_string = aux.trim(old_filter_string)

    if old_filter_string ~= '' then
        old_filter_string = old_filter_string .. ';'
    end

    set_filter(old_filter_string .. filter_string)
end

