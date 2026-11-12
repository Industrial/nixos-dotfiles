select(2, ...) 'aux.util.info'

local aux = require 'aux'
local persistence = require 'aux.util.persistence'

local MIN_ITEM_ID = 1
local MAX_ITEM_ID = 30000

local items_schema = {'tuple', '#', {name='string'}, {link='string'}, {quality='number'}, {level='number'}, {requirement='number'}, {class='string'}, {subclass='string'}, {slot='string'}, {max_stack='number'}, {texture='string'}, {sell_price='number'}}
local merchant_buy_schema = {'tuple', '#', {unit_price='number'}, {limited='boolean'} }

local trading

function aux.event.AUX_LOADED()
    aux.event_listener('GET_ITEM_INFO_RECEIVED', on_get_item_info_received)
    fetch_item_data()

	aux.event_listener('MERCHANT_SHOW', on_merchant_show)
	aux.event_listener('MERCHANT_CLOSED', on_merchant_closed)
	aux.event_listener('MERCHANT_UPDATE', on_merchant_update)
end

do
	local characters = {}
	function M.is_player(name)
		return not not characters[name]
	end
	-- your characters on this realm, each with when it last logged in; one not seen for 30 days is
	-- forgotten. auxForever: dated with time() (the date). aux used GetTime(), the computer's uptime,
	-- so the 30 days did not work; such an old stamp (far below any date) counts as seen today.
	function M.update_characters()
		characters = aux.realm_data.characters
		local now = time()
		for k, v in pairs(characters) do
			if v < 1000000000 then
				characters[k] = now
			elseif now > v + 60 * 60 * 24 * 30 then
				characters[k] = nil
			end
		end
		characters[UnitName'player'] = now
	end
	function aux.event.AUX_LOADED()
		update_characters()

        aux.event_listener('TRADE_SHOW', function()
            trading = true
        end)
        aux.event_listener('TRADE_CLOSED', function()
            trading = false
        end)
	end
end

do
	local incomplete_buy_data
	function on_merchant_show()
		incomplete_buy_data = not merchant_buy_scan()
	end
	function on_merchant_closed()
		incomplete_buy_data = false
	end
	function on_merchant_update()
		if incomplete_buy_data then
			incomplete_buy_data = not merchant_buy_scan()
		end
	end
end

function merchant_loaded()
	for i = 1, GetMerchantNumItems() do
		if not GetMerchantItemLink(i) then
			return false
		end
	end
	return true
end

function M.merchant_buy_info(item_id)
	local buy_info
	if aux.account_data.merchant_buy[item_id] then
		buy_info = persistence.read(merchant_buy_schema, aux.account_data.merchant_buy[item_id])
	end
	return buy_info and buy_info.unit_price, buy_info and buy_info.limited
end

function M.item_info(item_id)
	local data_string = aux.account_data.items[item_id]
	if data_string then
		return aux.copy(persistence.read(items_schema, data_string))
	end
end

function M.item_id(item_name)
	return aux.account_data.item_ids[strlower(item_name)]
end

function merchant_buy_scan()
	local incomplete_data
	for i = 1, GetMerchantNumItems() do
		local _, _, price, count, stock = GetMerchantItemInfo(i)
		local link = GetMerchantItemLink(i)
		if link then
			local item_id = parse_link(link)
			local new_unit_price, new_limited = price / count, stock >= 0
			if aux.account_data.merchant_buy[item_id] then
				local buy_info = persistence.read(merchant_buy_schema, aux.account_data.merchant_buy[item_id])

				local unit_price
				if buy_info.limited and not new_limited then
					unit_price = new_unit_price
				elseif new_limited and not buy_info.limited then
					unit_price = buy_info.unit_price
				else
					unit_price = min(buy_info.unit_price, new_unit_price)
				end

                aux.account_data.merchant_buy[item_id] = persistence.write(merchant_buy_schema, {
					unit_price = unit_price,
					limited = buy_info.limited and new_limited,
                })
			else
				aux.account_data.merchant_buy[item_id] = persistence.write(merchant_buy_schema, {
					unit_price = new_unit_price,
					limited = new_limited,
                })
			end
		else
			incomplete_data = true
		end
	end

	return not incomplete_data
end

function process_item(item_id)
    while trading do
        aux.coro_wait()
    end

    local itemstring = 'item:' .. item_id
    local name, quality = save_item(item_id)
    if name then
        local tooltip = tooltip('link', itemstring)
        if auctionable(tooltip, quality) then
            tinsert(aux.account_data.auctionable_items, strlower(name))
        end
        return true
    end
end

-- writes an item the game knows into aux's item list; returns its name and quality, or nil when
-- the game has not loaded the item yet
function save_item(item_id)
    local name, link, quality, level, requirement, class, subclass, max_stack, slot, texture, sell_price = GetItemInfo('item:' .. item_id)
    if name then
        aux.account_data.item_ids[strlower(name)] = item_id
        aux.account_data.items[item_id] = persistence.write(items_schema, {
            name = name,
            link = link,
            quality = quality,
            level = level,
            requirement = requirement,
            class = class,
            subclass = subclass,
            slot = slot,
            max_stack = max_stack,
            texture = texture,
            sell_price = sell_price,
        })
        return name, quality
    end
end

-- auxForever: an item seen at the auction house joins the item list at once (names for
-- autocompletion, exact searches and /aux price). The walk at login only goes up to item number
-- MAX_ITEM_ID, and Forever adds many items Classic did not have (Tyler, 2026-10-11), whose
-- numbers are likely higher. An item listed at the auction house can be auctioned, so no tooltip
-- is read. Costs one table lookup for an item already known.
function M.learn_item(item_id)
    if not item_id or aux.account_data.items[item_id] then
        return
    end
    local name = GetItemInfo('item:' .. item_id)
    if not name then
        return
    end
    -- another item of the same name is already offered for autocompletion
    local listed = aux.account_data.item_ids[strlower(name)]
    save_item(item_id)
    aux.account_data.unused_item_ids[item_id] = nil
    if not listed then
        tinsert(aux.account_data.auctionable_items, strlower(name))
    end
end

-- aux's item list (names for autocompletion and exact searches): at login, every item number not
-- known yet is asked for once. auxForever: numbers the game itself says do not exist are skipped
-- (each used to cost a server request and 7 frames of waiting at every login), and the walk pauses
-- every 500 numbers, so a list that is already complete costs no single long frame at login.
local function item_exists(item_id)
    if C_Item and C_Item.DoesItemExistByID then
        return C_Item.DoesItemExistByID(item_id)
    end
    return true
end

function fetch_item_data()
    aux.coro_thread(function()
        local items, unused = aux.account_data.items, aux.account_data.unused_item_ids
        for item_id = MIN_ITEM_ID, MAX_ITEM_ID do
            if not items[item_id] and not unused[item_id] and item_exists(item_id) and not process_item(item_id) then
                for i = 1, 7 do
                    aux.coro_wait()
                end
            elseif item_id % 500 == 0 then
                aux.coro_wait()
            end
        end
        item_walk_done = true
    end)
end

-- how far the item list is: items known, numbers known not to be items, numbers left to ask about
function M.item_list_progress()
    local known, unused = 0, 0
    for _ in pairs(aux.account_data.items) do known = known + 1 end
    for _ in pairs(aux.account_data.unused_item_ids) do unused = unused + 1 end
    return known, unused, max(0, MAX_ITEM_ID - MIN_ITEM_ID + 1 - known - unused), item_walk_done
end

function on_get_item_info_received(item_id, success)
    if success then
        aux.coro_thread(function()
            if not aux.account_data.items[item_id] and not aux.account_data.unused_item_ids[item_id] then
                process_item(item_id)
            end
        end)
    else -- TODO if success == nil then
        aux.account_data.unused_item_ids[item_id] = true
    end
end
