select(2, ...) 'aux.util.scan'

local info = require 'aux.util.info'
local filter_util = require 'aux.util.filter'

-- Forever: auctions are bought by auction ID, so Classic aux's "find the auction again" scan
-- (M.find / M.test) is no longer needed.

function M.item_query(item_id, first_page, last_page)
	local item_info = info.item(item_id)
    if item_info then
        local query = filter_util.query(item_info.name .. '/exact')
        query.blizzard_query.first_page = first_page
        query.blizzard_query.last_page = last_page
        return { validator = query.validator, blizzard_query = query.blizzard_query }
    end
end
