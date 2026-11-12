select(2, ...) 'aux.core.slash'

local aux = require 'aux'
local post = require 'aux.tabs.post'
local info = require 'aux.util.info'
local scan = require 'aux.core.scan'
local money = require 'aux.util.money'

function status(enabled)
	return (enabled and aux.color.green'on' or aux.color.red'off')
end

-- auxForever: /aux memory. How much memory aux uses, and how many items its price history holds
-- (the part that grows over time). Measured only when asked: updating the game's memory figures
-- takes a moment.
function M.memory_report()
    UpdateAddOnMemoryUsage()
    local kilobytes = GetAddOnMemoryUsage('auxForever') or 0
    local items = 0
    for _ in pairs(aux.faction_data and aux.faction_data.history or empty) do
        items = items + 1
    end
    local text = format('auxForever uses %.1f MB of memory; price history for %d items', kilobytes / 1024, items)
    local known, _, left, done = info.item_list_progress()
    text = text .. format('; item list %d items', known) .. (done and '' or format(', still checking (%d numbers left)', left))
    -- The game's number includes garbage (tables no longer used, such as each Sniper round's item
    -- list) that Lua frees a little at a time. One full cleanup, only when asked (a short pause),
    -- shows what aux really keeps.
    if pcall(collectgarbage, 'collect') then
        UpdateAddOnMemoryUsage()
        text = text .. format('. After a cleanup: %.1f MB; the rest was garbage the game frees over time', (GetAddOnMemoryUsage('auxForever') or 0) / 1024)
    end
    return text
end

-- /aux memory detail: how many entries aux's main stores hold, to find one that keeps growing
function M.memory_detail()
    local known, seen, deals, markets = require('aux.tabs.sniper').memory_counts()
    local cached, today = require('aux.core.history').memory_counts()
    local searches, records = require('aux.tabs.search').memory_counts()
    return {
        format('Sniper: %d items known, %d seen last round, %d deals, %d markets read', known, seen, deals, markets),
        format('History: %d usual prices cached, %d items seen today', cached, today),
        format('Search: %d searches kept, %d result rows', searches, records),
        format('Post: listings kept for %d items', require('aux.tabs.post').memory_counts()),
        format('Tooltips: %d items checked', require('aux.core.tooltip').memory_counts()),
        format('Events: %d listeners, %d running tasks', aux.listener_count(), aux.thread_count()),
    }
end

_G.SLASH_AUX1 = '/aux'
_G.SLASH_AUX2 = '/auxforever'
function SlashCmdList.AUX(command)
	if not command then return end
	local arguments = aux.tokenize(command)
    local tooltip_settings = aux.character_data.tooltip
    if arguments[1] == 'scale' and tonumber(arguments[2]) then
	    aux.change_window_scale(tonumber(arguments[2]))
	    aux.print('scale ' .. aux.color.blue(floor(aux.account_data.scale * 100 + .5) .. '%') .. ' (70% to 150%)')
    elseif arguments[1] == 'debug' and arguments[2] == 'list' then
        if not info.auction_house_open() then
            aux.print('Open the auction house first.')
        else
            scan.measure_item_list()
        end
    elseif arguments[1] == 'price' then
        -- auxForever (0.5): /aux price <item link or exact name>
        local target = strmatch(command, '^%s*price%s+(.-)%s*$') or ''
        local item_id, suffix_id
        if strfind(target, 'item:', 1, true) then
            item_id, suffix_id = info.parse_link(target)
        elseif target ~= '' then
            -- a typed full name with its ending works too (0.8, review H-002, finding 6)
            item_id, suffix_id = info.split_ending(target), 0
        end
        if not item_id then
            aux.print('Usage: /aux price followed by an item link (Shift-click the item) or its exact name.')
        else
            local item_info = info.item(item_id)
            aux.print('Price data for ' .. (item_info and item_info.link or ('item ' .. item_id)) .. ':')
            local key = strfind(target, 'item:', 1, true) and info.link_price_key(target) or info.price_key(item_id, target)
            for _, line in ipairs(require('aux.core.history').report(key, function(amount) return money.to_string(amount, true) end)) do
                aux.print('  ' .. line)
            end
        end
    elseif arguments[1] == 'memory' then
        aux.print(memory_report())
        if arguments[2] == 'detail' then
            for _, line in ipairs(memory_detail()) do
                aux.print(line)
            end
        end
    elseif arguments[1] == 'debug' then
        aux.account_data.debug_timing = not aux.account_data.debug_timing
        aux.print('search timing log ' .. status(aux.account_data.debug_timing) .. (aux.account_data.debug_timing and ': a summary prints in chat after each search' or ''))
    elseif arguments[1] == 'ignore' and arguments[2] == 'owner' then
	    aux.account_data.ignore_owner = not aux.account_data.ignore_owner
        aux.print('ignore owner ' .. status(aux.account_data.ignore_owner))
    elseif arguments[1] == 'action' and arguments[2] == 'shortcuts' then
        aux.account_data.action_shortcuts = not aux.account_data.action_shortcuts
        aux.print('action shortcuts ' .. status(aux.account_data.action_shortcuts))
    elseif arguments[1] == 'post' and arguments[2] == 'full' and arguments[3] == 'scan' then
        aux.account_data.post_full_scan = not aux.account_data.post_full_scan
        aux.print('post full scan ' .. status(aux.account_data.post_full_scan))
    elseif arguments[1] == 'post' and arguments[2] == 'bid' then
        aux.account_data.post_bid = ({ unit = 'unit', stack = 'stack' })[arguments[3]]
        post.apply_bid_layout()
        aux.refresh_settings()
	    aux.print('post bid ' .. aux.color.blue(aux.account_data.post_bid or 'off'))
    elseif arguments[1] == 'post' and arguments[2] == 'duration' and post_duration_code(arguments[3]) then
        -- Forever: accepts the hours of the auction house's options (e.g. 12, 24, 48)
        aux.account_data.post_duration = post_duration_code(arguments[3])
        aux.print('post duration ' .. aux.color.blue(info.duration_hours(aux.account_data.post_duration) .. 'h'))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'value' then
	    tooltip_settings.value = not tooltip_settings.value
        aux.print('tooltip value ' .. status(tooltip_settings.value))
    elseif arguments[1] == 'tooltip' and (arguments[2] == 'percent' or arguments[2] == 'usually') then
	    tooltip_settings.usually = not tooltip_settings.usually
        aux.print('tooltip percent of usual ' .. status(tooltip_settings.usually))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'daily' then
	    tooltip_settings.daily = not tooltip_settings.daily
        aux.print('tooltip daily ' .. status(tooltip_settings.daily))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'merchant' and arguments[3] == 'buy' then
	    tooltip_settings.merchant_buy = not tooltip_settings.merchant_buy
        aux.print('tooltip merchant buy ' .. status(tooltip_settings.merchant_buy))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'merchant' and arguments[3] == 'sell' then
	    tooltip_settings.merchant_sell = not tooltip_settings.merchant_sell
        aux.print('tooltip merchant sell ' .. status(tooltip_settings.merchant_sell))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'disenchant' and arguments[3] == 'value' then
	    tooltip_settings.disenchant_value = not tooltip_settings.disenchant_value
        aux.print('tooltip disenchant value ' .. status(tooltip_settings.disenchant_value))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'disenchant' and arguments[3] == 'distribution' then
	    tooltip_settings.disenchant_distribution = not tooltip_settings.disenchant_distribution
        aux.print('tooltip disenchant distribution ' .. status(tooltip_settings.disenchant_distribution))
    elseif arguments[1] == 'tooltip' and arguments[2] == 'money'  and arguments[3] == 'icons' then
	    tooltip_settings.money_icons = not tooltip_settings.money_icons
        aux.print('tooltip money icons ' .. status(tooltip_settings.money_icons))
    elseif arguments[1] == 'clear' and arguments[2] == 'item' and arguments[3] == 'cache' then
	    aux.account_data.items = {}
        aux.account_data.item_ids = {}
        aux.account_data.unused_item_ids = {}
        aux.account_data.auctionable_items = {}
        aux.print('Item cache cleared.')
    elseif arguments[1] == 'opacity' and tonumber(arguments[2]) then
        aux.set_background_opacity(tonumber(arguments[2]) / 100)
        aux.print('background opacity ' .. aux.color.blue(floor(aux.account_data.background_opacity * 100 + .5) .. '%') .. ' (50% to 100%)')
    elseif arguments[1] == 'undercut' then
        if arguments[2] == 'on' or arguments[2] == 'off' then
            post.set_undercut_mode(arguments[2] == 'on')
        end
        -- E6 in docs/forever-auction-house.md: said of the modern auction house, not yet seen on Forever
        aux.print('Undercutting on Forever: on the modern auction house, the newest of several listings at one price is said to sell first. This is not yet confirmed on Forever.')
        aux.print('If it holds, posting at the cheapest price sells just as fast as going below it, and keeps prices from sliding.')
        aux.print('auxForever matches the cheapest price by default. Undercut mode (the goblin on the Post tab) goes one step below it.')
        aux.print('For gear, buyers pick the listing themselves.')
        aux.print('Undercut mode [' .. status(aux.account_data.post_undercut) .. '] - /aux undercut on|off (it starts off each time the auction house opens)')
    elseif arguments[1] == 'clear' and arguments[2] == 'post' then
        aux.faction_data.post = {}
        aux.print('Post data cleared.')
	else
		aux.print('Usage:')
        aux.print('- scale [' .. aux.color.blue(aux.account_data.scale) .. ']')
		aux.print('- ignore owner [' .. status(aux.account_data.ignore_owner) .. ']')
        aux.print('- action shortcuts [' .. status(aux.account_data.action_shortcuts) .. ']')
        aux.print('- post full scan [' .. status(aux.account_data.post_full_scan) .. ']')
        aux.print('- post bid [' .. aux.color.blue(aux.account_data.post_bid or 'off') .. ']')
        aux.print('- post duration [' .. aux.color.blue(info.duration_hours(aux.account_data.post_duration) .. 'h') .. ']')
        aux.print('- undercut [' .. status(aux.account_data.post_undercut) .. ']')
        aux.print('- opacity [' .. aux.color.blue(floor(aux.account_data.background_opacity * 100 + .5) .. '%') .. ']')
		aux.print('- tooltip value [' .. status(tooltip_settings.value) .. ']')
		aux.print('- tooltip percent [' .. status(tooltip_settings.usually) .. ']')
		aux.print('- tooltip daily [' .. status(tooltip_settings.daily) .. ']')
		aux.print('- tooltip merchant buy [' .. status(tooltip_settings.merchant_buy) .. ']')
		aux.print('- tooltip merchant sell [' .. status(tooltip_settings.merchant_sell) .. ']')
		aux.print('- tooltip disenchant value [' .. status(tooltip_settings.disenchant_value) .. ']')
		aux.print('- tooltip disenchant distribution [' .. status(tooltip_settings.disenchant_distribution) .. ']')
        aux.print('- tooltip money icons [' .. status(tooltip_settings.money_icons) .. ']')
		aux.print('- clear item cache')
		aux.print('- debug [' .. status(aux.account_data.debug_timing) .. '] (search timing log)')
		aux.print('- debug list (times the item list of the whole auction house)')
		aux.print('- memory (how much memory aux uses)')
		aux.print('- price <item> (what aux has recorded for an item)')
        aux.print('- clear post')
    end
end

function post_duration_code(hours)
    for code = 1, 3 do
        if tostring(info.duration_hours(code)) == hours then
            return code
        end
    end
end
