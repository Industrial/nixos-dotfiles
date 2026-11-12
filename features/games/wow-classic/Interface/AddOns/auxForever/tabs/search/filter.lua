select(2, ...) 'aux.tabs.search'

local aux = require 'aux'
local info = require 'aux.util.info'
local money = require 'aux.util.money'
local filter_util = require 'aux.util.filter'

-- auxForever: the Filter Builder. The left side ("Which items") is the part of a search the auction
-- house itself understands; the right side ("Only show auctions where") is aux's post filter, kept
-- here as a tree of conditions and groups. A group matches All (and) or Any (or) of its items, and
-- any condition or group can be negated (not), which is exactly aux's and/or/not language. The
-- builder and the search bar stay in sync: editing the form rewrites the search bar, and the form
-- is loaded from the search bar when the builder opens or the search bar is typed in.

-- Every post filter, in the order of the "+ Condition" menu. words: how "In words" reads it.
M.CONDITIONS = {
    {group = 'Price', key = 'price', label = 'Price per item', op = 'at most', hint = 'Buyout for one item', words = 'price per item is at most %s'},
    {group = 'Price', key = 'bid-price', label = 'Bid per item', op = 'at most', hint = 'Current bid for one item', words = 'bid per item is at most %s'},
    {group = 'Price', key = 'percent', label = '% of usual price', op = 'at most', unit = '%', hint = 'Buyout compared with price history', words = 'buyout is at most %s%% of the usual price'},
    {group = 'Price', key = 'bid-percent', label = 'Bid % of usual', op = 'at most', unit = '%', hint = 'Bid compared with price history', words = 'bid is at most %s%% of the usual price'},
    {group = 'Profit', key = 'profit', label = 'Below usual price by', op = 'at least', hint = 'Usual value minus buyout', words = 'buyout is at least %s below the usual price'},
    {group = 'Profit', key = 'bid-profit', label = 'Bid below usual by', op = 'at least', hint = 'Usual value minus bid', words = 'bid is at least %s below the usual price'},
    {group = 'Profit', key = 'vendor-profit', label = 'Vendor pays more by', op = 'at least', hint = 'Buy, then sell to a vendor', words = 'a vendor pays at least %s more than the buyout'},
    {group = 'Profit', key = 'bid-vendor-profit', label = 'Vendor pays more than bid', op = 'by', hint = 'Win the bid, sell to a vendor', words = 'a vendor pays at least %s more than the bid'},
    {group = 'Profit', key = 'disenchant-profit', label = 'Disenchants for more by', op = 'at least', hint = 'Disenchant value minus buyout', words = 'disenchanting is worth at least %s more than the buyout'},
    {group = 'Profit', key = 'bid-disenchant-profit', label = 'Disenchants above bid', op = 'by', hint = 'Disenchant value minus bid', words = 'disenchanting is worth at least %s more than the bid'},
    {group = 'Item', key = 'rarity', label = 'Rarity', op = 'is', hint = 'Exactly this rarity', words = 'rarity is %s'},
    {group = 'Item', key = 'min-level', label = 'Required level', op = 'at least', hint = 'Checked on each result', words = 'required level is at least %s'},
    {group = 'Item', key = 'max-level', label = 'Required level', op = 'at most', hint = 'Checked on each result', words = 'required level is at most %s'},
    {group = 'Item', key = 'tooltip', label = 'Tooltip', op = 'contains', hint = 'e.g. +3 Stamina, Unique', words = 'tooltip contains "%s"'},
    {group = 'Item', key = 'item', label = 'Item', op = 'is', hint = 'One exact item', words = 'item is %s'},
    {group = 'Item', key = 'utilizable', label = 'Usable, not learned yet', op = '', hint = 'Recipes and more you can still learn', words = 'you can use it and have not learned it'},
    {group = 'Auction', key = 'left', label = 'Time left', op = 'is', hint = 'Time left band of the auction', words = 'time left is %s'},
    {group = 'Auction', key = 'seller', label = 'Seller', op = 'is', hint = 'Shown for gear on Forever', words = 'seller is %s'},
}
M.CONDITION_GROUPS = {'Price', 'Profit', 'Item', 'Auction'}

function M.condition_info(key)
    for _, c in ipairs(CONDITIONS) do
        if c.key == key then
            return c
        end
    end
    return {key = key, label = key, op = '', hint = '', words = key .. ' %s'}
end

function M.input_type(key)
    local filter = filter_util.filters[key]
    return filter and filter.input_type or ''
end

-- the choices of a condition like Time left or Rarity, or nil
function M.condition_choices(key)
    local input_type = input_type(key)
    return type(input_type) == 'table' and input_type or nil
end

local builder_root = {kind = 'group', mode = 'and', items = {}}
local builder_rest -- other searches in the search bar after a ';', kept as they are
local loading, syncing
local last_written -- the search bar text the builder wrote last

function M.get_builder_root()
    return builder_root
end

function M.new_condition(key)
    return {kind = 'cond', filter = key, value = nil, negated = false}
end

function M.new_group(mode)
    return {kind = 'group', mode = mode or 'and', items = {}, negated = false}
end

-- a condition is complete when its value parses; incomplete ones are left out of the search
function M.condition_complete(node)
    local input_type = input_type(node.filter)
    if input_type == '' then
        return true
    end
    return node.value ~= nil and filter_util.parse_parameter(input_type, strlower(aux.trim(node.value))) ~= nil
end

-- Builds the tree from aux's post filter components (polish notation). An and/or without a count
-- takes everything after it, as in aux's validator; the top level is an implicit "and".
function M.tree_from_post(post)
    local function read(i)
        local c = post[i]
        if not c then
            return nil, i
        end
        if c[1] == 'filter' then
            return {kind = 'cond', filter = c[2], value = c[3], negated = false}, i + 1
        elseif c[2] == 'not' then
            local node, j = read(i + 1)
            if node then
                node.negated = not node.negated
            end
            return node, j
        else
            local group, j = new_group(c[2]), i + 1
            local arity = tonumber(c[3])
            while post[j] and (not arity or #group.items < arity) do
                local node
                node, j = read(j)
                if node then
                    tinsert(group.items, node)
                end
            end
            return group, j
        end
    end
    local root, i = new_group('and'), 1
    while post[i] do
        local node
        node, i = read(i)
        if node then
            tinsert(root.items, node)
        end
    end
    -- "or/a/b" as the whole filter shows as Match Any at the top rather than as one group
    if #root.items == 1 and root.items[1].kind == 'group' and not root.items[1].negated then
        root = root.items[1]
    end
    return root
end

local function value_string(node)
    local input_type = input_type(node.filter)
    local value = strlower(aux.trim(node.value or ''))
    if input_type == 'money' then
        return money.to_string(filter_util.parse_parameter('money', value), nil, true, nil, true)
    end
    return (gsub(value, '[/;]', ''))
end

local function serialize(node)
    local body
    if node.kind == 'cond' then
        if not condition_complete(node) then
            return nil
        end
        body = node.filter
        if input_type(node.filter) ~= '' then
            body = body .. '/' .. value_string(node)
        end
    else
        local parts = {}
        for _, item in ipairs(node.items) do
            tinsert(parts, serialize(item))
        end
        if #parts == 0 then
            return nil
        elseif #parts == 1 then
            body = parts[1]
        else
            -- always with a count: a bare "and" would swallow everything after the group
            body = node.mode .. #parts .. '/' .. table.concat(parts, '/')
        end
    end
    return node.negated and 'not/' .. body or body
end

-- how many items of a group are complete enough to count; All / Any only matters from two
function M.active_count(group)
    local n = 0
    for _, item in ipairs(group.items) do
        if serialize(item) then
            n = n + 1
        end
    end
    return n
end

-- the post filter part of the search text for a tree
function M.post_string(root)
    local parts = {}
    for _, item in ipairs(root.items) do
        tinsert(parts, serialize(item))
    end
    if #parts == 0 then
        return ''
    elseif root.mode == 'or' and #parts > 1 then
        return 'or' .. #parts .. '/' .. table.concat(parts, '/')
    end
    return table.concat(parts, '/')
end

local function display_value(node)
    local input_type = input_type(node.filter)
    if input_type == 'money' then
        return money.to_string(filter_util.parse_parameter('money', strlower(aux.trim(node.value))), nil, true)
    elseif node.filter == 'item' then
        return info.display_name(info.item_id(node.value)) or node.value
    end
    return node.value or ''
end

local function say(node, nested)
    local text
    if node.kind == 'cond' then
        if not condition_complete(node) then
            return nil
        end
        local words = condition_info(node.filter).words
        text = input_type(node.filter) == '' and words or format(words, display_value(node))
        return node.negated and 'NOT ' .. text or text
    end
    local parts = {}
    for _, item in ipairs(node.items) do
        tinsert(parts, say(item, true))
    end
    if #parts == 0 then
        return nil
    end
    text = table.concat(parts, node.mode == 'or' and ' OR ' or ' AND ')
    if node.negated then
        return 'NOT (' .. text .. ')'
    elseif nested and #parts > 1 then
        return '(' .. text .. ')'
    end
    return text
end

-- "In words" for the post filter part, or nil when there is none
function M.post_words(root)
    return say(root, false)
end

function valid_level(str)
	local level = tonumber(str)
	return level and aux.bounded(1, 60, level)
end

blizzard_query = setmetatable({}, {
	__index = function(_, key)
		if key == 'name' then
			return name_input:GetText()
		elseif key == 'exact' then
			return exact_checkbox:GetChecked()
		elseif key == 'min_level' then
			return tonumber(min_level_input:GetText())
		elseif key == 'max_level' then
			return tonumber(max_level_input:GetText())
		elseif key == 'usable' then
			return usable_checkbox:GetChecked()
		elseif key == 'class' then
			local class_index = (class_dropdown:GetIndex() or 0) - 1
			return class_index ~= 0 and class_index or nil
		elseif key == 'subclass' then
			local subclass_index = (subclass_dropdown:GetIndex() or 0) - 1
			return subclass_index ~= 0 and subclass_index or nil
		elseif key == 'slot' then
			local slot_index = (slot_dropdown:GetIndex() or 0) - 1
			return (slot_index or 0) > 0 and slot_index or nil
		elseif key == 'quality' then
			local quality_code = (quality_dropdown:GetIndex() or 1) - 2
			return (quality_code or -1) >= 0 and quality_code or nil
		end
	end,
	__newindex = function(_, key, value)
		if key == 'name' then
			name_input:SetText(value)
		elseif key == 'exact' then
			exact_checkbox:SetChecked(value and true or false)
            exact_update()
		elseif key == 'min_level' then
			min_level_input:SetText(value)
		elseif key == 'max_level' then
			max_level_input:SetText(value)
		elseif key == 'usable' then
			usable_checkbox:SetChecked(value and true or false)
		elseif key == 'class' then
            class_dropdown:SetIndex(value + 1)
		elseif key == 'subclass' then
			subclass_dropdown:SetIndex(value + 1)
		elseif key == 'slot' then
			slot_dropdown:SetIndex(value + 1)
		elseif key == 'quality' then
			quality_dropdown:SetIndex(value + 2)
		end
	end,
})

local function category(class, subclass, slot)
    local c = class and AuctionCategories and AuctionCategories[class]
    local s = c and subclass and c.subCategories and c.subCategories[subclass]
    local t = s and slot and s.subCategories and s.subCategories[slot]
    return c, s, t
end

-- the "Which items" part of the search text
function M.blizzard_string()
	local filter_string

	local function add(part)
		if part then
			filter_string = filter_string and filter_string .. '/' .. part or part
		end
	end

	local name = aux.trim(blizzard_query.name or '')
	if name ~= '' and not aux.index(filter_util.parse_filter_string(name), 'blizzard', 'name') then
		name = filter_util.quote(name)
	end
	add(name ~= '' and name)
	add(name ~= '' and blizzard_query.exact and 'exact')

    if not (name ~= '' and blizzard_query.exact) then
        add(blizzard_query.min_level or blizzard_query.max_level and 1)
        add(blizzard_query.max_level)
        add(blizzard_query.usable and 'usable')

        local c, s, t = category(blizzard_query.class, blizzard_query.subclass, blizzard_query.slot)
        add(c and strlower(c.name))
        add(c and s and strlower(s.name))
        add(c and s and t and strlower(t.name))

        local quality = blizzard_query.quality
        if quality and quality >= 0 then
            add(strlower(_G['ITEM_QUALITY' .. quality .. '_DESC']))
        end
    end

	return filter_string or ''
end

-- "In words" for the "Which items" part
function M.blizzard_words()
    local name = aux.trim(blizzard_query.name or '')
    if name ~= '' and blizzard_query.exact then
        return 'Exactly "' .. name .. '"'
    end
    local kind
    local c, s, t = category(blizzard_query.class, blizzard_query.subclass, blizzard_query.slot)
    if t then
        -- the most specific choice first: "daggers (weapons, one-handed)", "chest (armor, cloth)"
        kind = strlower(t.name) .. ' (' .. strlower(c.name) .. ', ' .. strlower(s.name) .. ')'
    elseif s then
        kind = strlower(s.name) .. ' (' .. strlower(c.name) .. ')'
    elseif c then
        kind = strlower(c.name)
    end
    local parts = {}
    local quality = blizzard_query.quality
    if quality and quality >= 0 then
        tinsert(parts, _G['ITEM_QUALITY' .. quality .. '_DESC'] .. ' or better ' .. (kind or 'items'))
    else
        tinsert(parts, kind and (strupper(strsub(kind, 1, 1)) .. strsub(kind, 2)) or 'All items')
    end
    if name ~= '' then
        tinsert(parts, 'named "' .. name .. '"')
    end
    local min_level, max_level = blizzard_query.min_level, blizzard_query.max_level
    if min_level and max_level then
        tinsert(parts, 'level ' .. min_level .. ' to ' .. max_level)
    elseif min_level then
        tinsert(parts, 'level ' .. min_level .. ' and up')
    elseif max_level then
        tinsert(parts, 'up to level ' .. max_level)
    end
    if blizzard_query.usable then
        tinsert(parts, 'that you can use')
    end
    return table.concat(parts, ', ')
end

-- the whole search the builder describes, without the other searches after a ';'
function M.get_filter_builder_query()
    local blizzard, post = blizzard_string(), post_string(builder_root)
    if blizzard ~= '' and post ~= '' then
        return blizzard .. '/' .. post
    end
    return blizzard .. post
end

function M.builder_words()
    local post = post_words(builder_root)
    return blizzard_words() .. (post and ', where ' .. post or '') .. '.'
end

-- builder -> search bar. Called after every edit in the builder.
function M.sync_builder()
    if loading then
        return
    end
    local text = get_filter_builder_query()
    if builder_rest then
        text = text .. ';' .. builder_rest
    end
    last_written = text
    if search_box:GetText() ~= text then
        syncing = true
        search_box:SetText(text)
        syncing = false
    end
    do (update_builder_words or pass)() end
end

-- search bar -> builder. The first search of the search bar is loaded; others are kept as they are.
-- Returns false and the reason when the text cannot be read.
function M.load_builder()
    if syncing then
        return true
    end
    local text = search_box:GetText() or ''
    -- the search bar still holds what the builder wrote: keep the builder as the player left it
    -- (reading the text back would give the same search, but could flatten a lone group)
    if text == last_written then
        do (update_builder or pass)() end
        return true
    end
    local first, rest = strmatch(text, '^([^;]*);(.*)$')
    first = first or text
    local filter, error = filter_util.parse_filter_string(first)
    if not filter then
        do (show_builder_error or pass)(error) end
        return false, error
    end
    loading = true
    builder_rest = rest
    clear_form()
	for _, component in ipairs(filter.components) do
		if component[1] == 'blizzard' then
			blizzard_query[component[2]] = component[4]
		end
	end
    builder_root = tree_from_post(filter.post)
    loading = false
    do (update_builder or pass)() end
    return true
end

function M.is_syncing()
    return syncing
end

function M.clear_builder()
    loading = true
    builder_rest = nil
    clear_form()
    builder_root = new_group('and')
    loading = false
    sync_builder()
    do (update_builder or pass)() end
end

function clear_form()
	blizzard_query.name = ''
	name_input:ClearFocus()
	blizzard_query.exact = false
	blizzard_query.min_level = ''
	min_level_input:ClearFocus()
	blizzard_query.max_level = ''
	max_level_input:ClearFocus()
	blizzard_query.usable = false
    initialize_class_dropdown()
    initialize_subclass_dropdown()
    initialize_slot_dropdown()
    initialize_quality_dropdown()
end

function exact_update()
    for name in aux.iter('min_level_input', 'max_level_input', 'usable_checkbox', 'class_dropdown', 'subclass_dropdown', 'slot_dropdown', 'quality_dropdown') do
        if blizzard_query.exact then
            _M[name]:Hide()
        else
            _M[name]:Show()
        end
    end
    update_subclass_dropdown()
    update_slot_dropdown()
end

function initialize_class_dropdown()
    local options = {ALL}
    for _, category in ipairs(AuctionCategories or empty) do
        tinsert(options, category.name)
    end
    class_dropdown:SetOptions(options)
    class_dropdown:SetIndex(1)
end

function class_selection_change()
    initialize_subclass_dropdown()
    sync_builder()
end

function initialize_subclass_dropdown()
    local options = {}
    if (blizzard_query.class or 0) > 0 then
        for _, subcategory in ipairs(AuctionCategories[blizzard_query.class].subCategories or empty) do
            tinsert(options, subcategory.name)
        end
    end
    if #options > 0 then
        tinsert(options, 1, ALL)
    end
    subclass_dropdown:SetOptions(options)
    subclass_dropdown:SetIndex(#options > 0 and 1 or nil)
    update_subclass_dropdown(true)
end

function subclass_selection_change()
    initialize_slot_dropdown()
    sync_builder()
end

function update_subclass_dropdown(update_quality_dropdown)
   if class_dropdown:IsShown() and subclass_dropdown:GetIndex() then
        subclass_dropdown:Show()
    else
        subclass_dropdown:Hide()
    end
    if update_quality_dropdown then
        update_quality_dropdown_point()
    end
end

function initialize_slot_dropdown()
    local options = {}
    if (blizzard_query.class or 0) > 0 and (blizzard_query.subclass or 0) > 0 then
        for _, subsubcategory in ipairs(AuctionCategories[blizzard_query.class].subCategories[blizzard_query.subclass].subCategories or empty) do
            tinsert(options, subsubcategory.name)
        end
    end
    if #options > 0 then
        tinsert(options, 1, ALL)
    end
    slot_dropdown:SetOptions(options)
    slot_dropdown:SetIndex(#options > 0 and 1 or nil)
    update_slot_dropdown(true)
end

function update_slot_dropdown(update_quality_dropdown)
    if subclass_dropdown:IsShown() and slot_dropdown:GetIndex() then
        slot_dropdown:Show()
    else
        slot_dropdown:Hide()
    end
    if update_quality_dropdown then
        update_quality_dropdown_point()
    end
end

function initialize_quality_dropdown()
    local options = {ALL}
    for i = 0, 4 do
        tinsert(options, _G['ITEM_QUALITY' .. i .. '_DESC'])
    end

    -- recalculate ITEM_QUALITY_COLORS indexes
    local NEW_ITEM_QUALITY_COLORS = {}
    tinsert(NEW_ITEM_QUALITY_COLORS, {r = 1, g = 1, b = 1}) -- white for 'ALL' option
    for i = 0, #ITEM_QUALITY_COLORS do
        tinsert(NEW_ITEM_QUALITY_COLORS, ITEM_QUALITY_COLORS[i])
    end

    quality_dropdown:SetOptions(options, NEW_ITEM_QUALITY_COLORS)
    quality_dropdown:SetIndex(1)
end

function update_quality_dropdown_point()
    if not subclass_dropdown:IsShown() then
        quality_dropdown:SetPoint('TOPLEFT', class_dropdown, 'BOTTOMLEFT', 0, -FILTER_SPACING)
    else
        if not slot_dropdown:IsShown() then
            quality_dropdown:SetPoint('TOPLEFT', subclass_dropdown, 'BOTTOMLEFT', 0, -FILTER_SPACING)
        else
            quality_dropdown:SetPoint('TOPLEFT', slot_dropdown, 'BOTTOMLEFT', 0, -FILTER_SPACING)
        end
    end
end

function aux.event.AUCTION_HOUSE_LOADED()
    loading = true
    clear_form()
    loading = false
end
