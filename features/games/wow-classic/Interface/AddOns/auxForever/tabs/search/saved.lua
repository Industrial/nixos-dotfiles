select(2, ...) 'aux.tabs.search'

local aux = require 'aux'
local filter_util = require 'aux.util.filter'
local gui = require 'aux.gui'

StaticPopupDialogs.AUX_REMOVE_FAVORITE_CONFIRMATION = {
    text = 'Are you sure you want to remove this search from your favorites?',
    button1 = 'Yes',
    button2 = 'No',
    showAlert = 1,
    timeout = 0,
    hideOnEscape = 1,
    preferredIndex = STATICPOPUP_NUMDIALOGS,
    OnAccept = function(self, index)
        tremove(favorite_searches, index)
        update_search_listings()
    end
}

StaticPopupDialogs.AUX_RENAME_FAVORITE = {
    text = 'Enter name for filter:\n%s',
    button1 = 'Accept',
    button2 = 'Cancel',
	maxLetters = 50,
    hasEditBox = 1,
    editBoxWidth = editBoxWidth ,
    timeout = 0,
    hideOnEscape = 1,
    preferredIndex = STATICPOPUP_NUMDIALOGS,
    OnShow = function(self, data)
        self.editBox:SetText(data.filter_name or data.prettified)
        self.editBox:SetFocus()
        self.editBox:HighlightText()
    end,
    OnHide = function(self)
        self.editBox:SetText('')
    end,
    OnAccept = function(self, data)
        local text = self.editBox:GetText()
        data.filter_name = text and text ~= '' and text or data.prettified
        update_search_listings()
    end,
    EditBoxOnEnterPressed = function(self, data)
        local text = self:GetText()
        data.filter_name = text and text ~= '' and text or data.prettified
        self:GetParent():Hide()
        update_search_listings()
    end,
    EditBoxOnEscapePressed = function(self, data)
        self:SetText('')
        self:GetParent():Hide()
    end,
}

dragged_search = nil

function aux.event.AUX_LOADED()
	recent_searches, favorite_searches = aux.realm_data.recent_searches, aux.realm_data.favorite_searches
end

function update_search_listings()
	local favorite_search_rows = {}
	for i = 1, #favorite_searches do
		local search = favorite_searches[i]
        local name = search.recipe and recipe_entry_name(search) or search.filter_name or strsub(search.prettified, 1, 250)
		tinsert(favorite_search_rows, {
			cols = {{ value = search.alert and aux.color.red'X' or '' }, { value = name }},
			search = search,
			index = i,
        })
	end
	favorite_searches_listing:SetData(favorite_search_rows)

	local recent_search_rows = {}
	for i = 1, #recent_searches do
		local search = recent_searches[i]
		local name = search.recipe and recipe_entry_name(search) or strsub(search.prettified, 1, 250)
		tinsert(recent_search_rows, {
			cols = {{ value = name }},
			search = search,
			index = i,
        })
	end
	recent_searches_listing:SetData(recent_search_rows)
end

function new_recent_search(filter_string, prettified, recipe)
	for i = #recent_searches, 1, -1 do
		if recent_searches[i].filter_string == filter_string then
			tremove(recent_searches, i)
		end
	end
	tinsert(recent_searches, 1, {
		filter_string = filter_string,
		prettified = prettified,
		recipe = recipe,
    })
	while #recent_searches > 50 do
		tremove(recent_searches)
	end
	update_search_listings()
end

-- auxForever (0.5, docs/clicks.md): Simon's clicks stay, and the tooltip now lists them
do
	local sep = gui.HINT_SEPARATOR
	RECENT_HINT = 'Click: run' .. sep .. 'Shift-click: put in the search bar' .. sep .. 'Shift-right-click: add to the search bar' .. sep .. 'Right-click: add to favorites'
	FAVORITE_HINT = 'Click: run' .. sep .. 'Shift-click: put in the search bar' .. sep .. 'Shift-right-click: add to the search bar' .. sep .. 'Right-click: remove' .. sep .. 'Ctrl-right-click: rename' .. sep .. 'Alt-click: alert on or off' .. sep .. 'Alt-drag: reorder'
end

handlers = {
	OnClick = function(st, data, _, button)
        if IsAltKeyDown() and st == favorite_searches_listing then
            if data.search.alert then
                data.search.alert = nil
            else
                enable_alert(data.search)
            end
            update_search_listings()
		elseif button == 'LeftButton' and IsShiftKeyDown() then
			set_filter(data.search.filter_string)
		elseif button == 'RightButton' and IsShiftKeyDown() then
			add_filter(data.search.filter_string)
		elseif button == 'LeftButton' then
			set_filter(data.search.filter_string)
			execute()
        elseif button == 'RightButton' and IsControlKeyDown() then
            if st == favorite_searches_listing then
                aux.show_popup('AUX_RENAME_FAVORITE', favorite_searches[data.index].prettified, nil, favorite_searches[data.index])
            end
		elseif button == 'RightButton' then
			if st == recent_searches_listing then
                for _, entry in pairs(favorite_searches) do
                    if entry.filter_string == data.search.filter_string then
                        return
                    end
                end
				tinsert(favorite_searches, 1, data.search)
                update_search_listings()
			elseif st == favorite_searches_listing then
                aux.show_popup('AUX_REMOVE_FAVORITE_CONFIRMATION', nil, nil, data.index)
            end
        end
	end,
    OnMouseDown = function(st, data)
        if st == favorite_searches_listing and IsAltKeyDown() then
            dragged_search = favorite_searches[data.index]
        end
    end,
    OnMouseUp = function(st)
        if st == favorite_searches_listing then
            dragged_search = nil
        end
    end,
    OnEnter = function(st, data)
        if st == favorite_searches_listing and dragged_search then
            for i = #favorite_searches, 1, -1 do
                if favorite_searches[i] == dragged_search then
                    tremove(favorite_searches, i)
                end
            end
            tinsert(favorite_searches, data.index, dragged_search)
            update_search_listings()
        end
		GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
		if data.search.recipe and data.search.recipe.crate then
			GameTooltip:AddLine('Crate: ' .. (data.search.recipe.name or '?'), aux.color.accent.background())
			GameTooltip:AddLine('Searches every bundle and finds the cheapest way to fill it.', 1, 1, 1, true)
			GameTooltip:AddLine(' ')
		elseif data.search.recipe then
			GameTooltip:AddLine('Recipe: ' .. (data.search.recipe.name or '?'), aux.color.accent.background())
			GameTooltip:AddLine('Searches the item and its materials, and adds up the cost.', 1, 1, 1, true)
			GameTooltip:AddLine(' ')
		end
		GameTooltip:AddLine(gsub(data.search.prettified, ';', '\n\n'), 255/255, 254/255, 250/255, true)
		gui.add_click_hint(GameTooltip, st == favorite_searches_listing and FAVORITE_HINT or RECENT_HINT)
		GameTooltip:Show()
	end,
	OnLeave = function()
		GameTooltip:ClearLines()
		GameTooltip:Hide()
	end
}

function get_alert_validator()
	local validators = {}
	for _, search in pairs(favorite_searches) do
		if search.alert then
			local queries, error = filter_util.queries(search.filter_string)
			if queries then
				tinsert(validators, queries[1].validator)
			else
				aux.print('Invalid alert filter:', error)
			end
		end
	end
	return function(record)
		return aux.any(validators, function(validator) return validator(record) end)
	end
end

-- auxForever: an empty search bar is not saved (it used to add an empty search per click), nor a
-- search that is already a favorite. Returns 'saved', 'empty' or 'duplicate' (nil when invalid).
function add_favorite(filter_string)
	filter_string = aux.trim(filter_string or '')
	if filter_string == '' then
		return 'empty'
	end
	for _, entry in ipairs(favorite_searches) do
		if strlower(aux.trim(entry.filter_string)) == strlower(filter_string) then
			return 'duplicate'
		end
	end
	local queries, error = filter_util.queries(filter_string)
	if queries then
		tinsert(favorite_searches, 1, {
			filter_string = filter_string,
			prettified = aux.join(aux.map(queries, function(query) return query.prettified end), ';'),
			recipe = saved_recipe(filter_string),
        })
		update_search_listings()
		return 'saved'
	else
		aux.print('Invalid filter:', error)
	end
end

-- the Favorite buttons: saves and says why when nothing was saved
function save_favorite(filter_string)
	local result = add_favorite(filter_string)
	if result == 'empty' then
		aux.print('Nothing to save: the search bar is empty.')
	elseif result == 'duplicate' then
		aux.print('That search is already a favorite.')
	elseif result == 'saved' then
		aux.print('Saved to favorites.')
	end
	return result
end

function enable_alert(search)
	local queries, error = filter_util.queries(search.filter_string)
	if queries then
		if #queries > 1 then
			aux.print('Error: Alert does not support multi-queries')
		elseif aux.size(queries[1].blizzard_query) > 0 and not filter_util.parse_filter_string(search.filter_string).blizzard.exact then
			aux.print('Error: Alert does not support Blizzard filters')
		else
			search.alert = true
		end
	else
		aux.print('Invalid filter:', error)
	end
end