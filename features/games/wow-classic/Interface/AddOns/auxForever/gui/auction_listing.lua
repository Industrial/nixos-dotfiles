select(2, ...) 'aux.gui.auction_listing'

local aux = require 'aux'
local info = require 'aux.util.info'
local sort_util = require 'aux.util.sort'
local money = require 'aux.util.money'
local history = require 'aux.core.history'
local gui = require 'aux.gui'
local tooltip = require 'aux.core.tooltip'

-- Forever: prices default to per item. Item rows are single items anyway, and a commodity row's
-- "stack" is everything listed at that price, so its total is rarely what you want to compare.
price_per_unit, percentage_for_bid = true, false

local HEAD_HEIGHT = 27
local HEAD_SPACE = 2

-- Forever: labels come from the auction house's time left bands
-- (colored text is fixed once made, so made again in Classic's colors: gui.themed)
local TIME_LEFT_STRINGS = {}
gui.themed(function()
    TIME_LEFT_STRINGS[1] = aux.color.red(info.time_left_label(1)) -- Short
    TIME_LEFT_STRINGS[2] = aux.color.orange(info.time_left_label(2)) -- Medium
    TIME_LEFT_STRINGS[3] = aux.color.yellow(info.time_left_label(3)) -- Long
    TIME_LEFT_STRINGS[4] = aux.color.blue(info.time_left_label(4)) -- Very Long
end)

-- auxForever (0.8, Tyler, build 7: "Why are we separating these lines?"): which row a record goes
-- in. Gear auctions at one buyout price share a row, whoever sells them and whatever time they have
-- left; the auction house hands them over per seller and time left (four sellers at 11s were four
-- rows). Trade goods come grouped by price already; an auction with no buyout keeps its own row,
-- so different bids never hide behind one (review H-004, finding 2). Tables that list each auction
-- apart (one_row_each: Auctions, Bids, Sniper) do not use it.
function M.price_group(record)
    if record.commodity or record.fast or (record.buyout_price or 0) == 0 then
        return record.search_signature
    end
    return aux.join({record.price_key or record.item_key, record.buyout_price, record.count or 1, record.sale_status or 0,
        info.is_player(record.owner) and 1 or 0, record.high_bidder and 1 or 0}, ':')
end

-- auxForever: Forever names the seller only when one player sells at a row's price
function M.seller_text(record)
    -- 0.8: a row of several sellers' auctions at one price (UpdateRowInfo)
    if (record.group_sellers or 0) > 1 then
        return aux.color.label.enabled(record.group_sellers .. ' sellers')
    elseif info.is_player(record.owner) then
        return aux.color.yellow(record.owner)
    elseif record.owner then
        return record.owner
    elseif (record.seller_count or 0) > 1 then
        return aux.color.label.enabled(record.seller_count .. ' sellers')
    end
    return '?'
end

function M.item_column_init(rt, cell)
    local spacer = CreateFrame('Frame', nil, cell)
    spacer:SetPoint('TOPLEFT', 0, 0)
    spacer:SetHeight(rt.ROW_HEIGHT)
    spacer:SetWidth(1)
    cell.spacer = spacer

    local iconBtn = CreateFrame('Button', nil, cell)
    iconBtn:SetPoint('TOPLEFT', spacer, 'TOPRIGHT')
    iconBtn:SetHeight(rt.ROW_HEIGHT)
    iconBtn:SetWidth(rt.ROW_HEIGHT)
    iconBtn:SetScript('OnEnter', rt.OnIconEnter)
    iconBtn:SetScript('OnLeave', rt.OnIconLeave)
    iconBtn:SetScript('OnClick', rt.OnIconClick)
    iconBtn:SetScript('OnDoubleClick', rt.OnIconDoubleClick)
    local icon = iconBtn:CreateTexture(nil, 'ARTWORK')
    icon:SetPoint('TOPLEFT', 2, -2)
    icon:SetPoint('BOTTOMRIGHT', -2, 2)
    icon:SetTexCoord(.08, .92, .08, .92)

    cell.iconBtn = iconBtn
    cell.icon = icon

    cell.text:ClearAllPoints()
    cell.text:SetPoint('TOPLEFT', iconBtn, 'TOPRIGHT', 2, 0)
    cell.text:SetPoint('BOTTOMRIGHT', 0, 0)
end

function M.item_column_fill(cell, record, _, _, _, indented)
	cell.icon:SetTexture(record.texture)
	if indented then
		cell.spacer:SetWidth(10)
		cell.icon:SetAlpha(.5)
		cell.text:SetAlpha(.7)
	else
		cell.spacer:SetWidth(1)
		cell.icon:SetAlpha(1)
		cell.text:SetAlpha(1)
	end
	if record.fast then
		-- a fast mode row: the item's own name and quality from the item list
		local color = ITEM_QUALITY_COLORS[record.quality or 1]
		cell.text:SetText(color and color.hex and (color.hex .. record.name .. FONT_COLOR_CODE_CLOSE) or record.name)
	else
		cell.text:SetText(gsub(record.link, '[%[%]]', ''))
	end
end

function status_code(record)
    if record.sale_status == 1 then
        return 1
    elseif not record.high_bidder then
        return 2
    else
        return 3
    end
end

-- auxForever (0.7, FB-013): the level an item needs is colored by how far it is from the player's,
-- like quests (Tyler, 2026-10-13): red 5 or more levels above, orange 3 to 4, yellow 1 to 2; green
-- once the player can use it, and gray when far below (outgrown). "Far below" is the level under
-- which Classic's monsters and quests turn gray, as players documented it (Wowpedia, "Mob
-- experience"); nothing is gray up to level 5.
function M.gray_level(player_level)
    if player_level <= 5 then
        return 0
    elseif player_level <= 39 then
        return player_level - floor(player_level / 10) - 5
    end
    return player_level - floor(player_level / 5) - 1
end

function M.requirement_color(requirement, player_level)
    local above = requirement - player_level
    if above >= 5 then
        return aux.color.red
    elseif above >= 3 then
        return aux.color.orange
    elseif above >= 1 then
        return aux.color.yellow
    elseif requirement > gray_level(player_level) then
        return aux.color.green
    end
    return aux.color.trivial
end

-- auxForever: columns shared by the tables. The required level, then the item level (gear only),
-- then the item (0.7, FB-013: "Lvl" read as either). Tyler, build 2: the levels go before the name,
-- so the units for sale after it never sit next to another column of plain numbers; build 4: "Req
-- first always".
function M.requirement_column()
    return {
        title = 'Req',
        width = .03,
        align = 'CENTER',
        fill = function(cell, record)
            local requirement = max(record.requirement or 0, 1)
            -- a Sniper deal that is gone is dimmed
            local color = record.deal_gone and aux.color.label.disabled or requirement_color(requirement, UnitLevel'player')
            cell.text:SetText(color(requirement))
        end,
        cmp = function(record_a, record_b, desc)
            return sort_util.compare(record_a.requirement or 0, record_b.requirement or 0, desc)
        end,
    }
end

function M.item_level_column()
    return {
        title = 'iLvl',
        width = .03,
        align = 'CENTER',
        fill = function(cell, record)
            local item_level = record.item_level or ''
            cell.text:SetText(record.deal_gone and aux.color.label.disabled(item_level) or item_level)
        end,
        cmp = function(record_a, record_b, desc)
            return sort_util.compare(record_a.item_level or 0, record_b.item_level or 0, desc)
        end,
    }
end

-- units: the units on this row (or of all rows of a collapsed item), own_units: the player's
local function quantity_column(title)
    return {
        title = title,
        width = .065,
        align = 'CENTER',
        fill = function(cell, record, units, own_units, expandable)
            local text = units and units > 0 and units or '?'
            text = expandable and aux.color.link(text) or text
            if own_units and own_units > 0 then
                text = text .. ' ' .. aux.color.yellow('(' .. own_units .. ')')
            end
            cell.text:SetText(text)
        end,
        -- an item's row sorts by all of it, as it shows: its first price alone put "18 (1)" below a
        -- 17 (0.8 build 14, Tyler)
        row_cmp = function(row_a, row_b, desc)
            return sort_util.compare(row_a.totalUnits or 0, row_b.totalUnits or 0, desc)
        end,
        -- a row of several auctions at one price sorts by all it holds, as it shows (review H-006, finding 5)
        cmp = function(record_a, record_b, desc)
            return sort_util.compare(record_a.count * (record_a.group_count or record_a.auction_count or 1), record_b.count * (record_b.group_count or record_b.auction_count or 1), desc)
        end,
    }
end

-- auxForever: an auction without a starting bid carries its buyout as the bid price, so it looked
-- biddable at the buyout (Tyler, 0.4.1: "I dont even have the option to bid"); most Forever gear is
-- buyout only. Same rule as the buy bar's Bid button.
function M.biddable(record)
    return record.high_bidder or (record.high_bid or 0) > 0 or (record.buyout_price or 0) == 0 or (record.bid_price or 0) < record.buyout_price
end

M.search_columns = {
    requirement_column(),
    item_level_column(),
    {
        title = 'Item',
        width = .32,
        init = item_column_init,
        fill = item_column_fill,
        cmp = function(record_a, record_b, desc)
            return sort_util.compare(record_a.name, record_b.name, desc)
        end,
    },
    quantity_column('For sale'),
    {
        title = 'Time\nLeft',
        width = .04,
        align = 'CENTER',
        fill = function(cell, record)
            -- auxForever: a fast mode row does not know its auctions yet
            cell.text:SetText(record.fast and '' or TIME_LEFT_STRINGS[record.duration or 0] or '?')
        end,
        cmp = function(record_a, record_b, desc)
            return sort_util.compare(record_a.duration or 0, record_b.duration or 0, desc)
        end,
    },
    {
        title = 'Seller',
        width = .13,
        align = 'CENTER',
        fill = function(cell, record)
            cell.text:SetText(record.fast and '' or seller_text(record))
        end,
        cmp = function(record_a, record_b, desc)
            -- a row of several sellers ("4 sellers") sorts with the other unnamed ones, not by the
            -- name of the one auction it keeps (review H-006, finding 5)
            local owner_a = (record_a.group_sellers or 1) <= 1 and record_a.owner
            local owner_b = (record_b.group_sellers or 1) <= 1 and record_b.owner
            if not owner_a and not owner_b then
                return sort_util.EQ
            elseif not owner_a then
                return sort_util.GT
            elseif not owner_b then
                return sort_util.LT
            else
                return sort_util.compare(owner_a, owner_b, desc)
            end
        end,
    },
    {
        title = {'Auction Bid\n(per item)', 'Auction Bid\n(per stack)'},
        bid = true,
        width = .125,
        align = 'RIGHT',
        toggle = 'price_per_unit',
        fill = function(cell, record)
            -- Forever: commodities cannot be bid on; a fast mode row does not know its bids
            if record.fast then
                cell.text:SetText('')
                return
            elseif record.commodity or not biddable(record) then
                cell.text:SetText('---')
                return
            end
            local price_color
            if record.high_bidder then
	            price_color = aux.color.green
            elseif record.high_bid ~= 0 then
	            price_color = aux.color.orange
            end
            local price
            if record.high_bidder then
                price = price_per_unit and ceil(record.high_bid / record.count) or record.high_bid
            else
                price = price_per_unit and ceil(record.unit_bid_price) or record.bid_price
            end
            cell.text:SetText(money.to_string(price, true, false, price_color))
        end,
        cmp = function(record_a, record_b, desc)
            local price_a
            if record_a.high_bidder then
                price_a = price_per_unit and record_a.high_bid / record_a.count or record_a.high_bid
            else
                price_a = price_per_unit and record_a.unit_bid_price or record_a.bid_price
            end
            local price_b
            if record_b.high_bidder then
                price_b = price_per_unit and record_b.high_bid / record_b.count or record_b.high_bid
            else
                price_b = price_per_unit and record_b.unit_bid_price or record_b.bid_price
            end
            if record_a.high_bidder and not record_b.high_bidder then
	            return sort_util.GT
            elseif record_b.high_bidder and not record_a.high_bidder then
	            return sort_util.LT
            end
            if price_a == price_b then
				if record_a.high_bid == 0 and record_b.high_bid ~= 0 then
		            return sort_util.GT
	            elseif record_b.high_bid == 0 and record_a.high_bid ~= 0 then
		            return sort_util.LT
	            end
            end
            return sort_util.compare(price_a, price_b, desc)
        end,
    },
    {
        title = {'Auction Buyout\n(per item)', 'Auction Buyout\n(per stack)'},
        width = .125,
        align = 'RIGHT',
        toggle = 'price_per_unit',
        fill = function(cell, record)
            local price = price_per_unit and ceil(record.unit_buyout_price) or record.buyout_price
            cell.text:SetText(price > 0 and money.to_string(price, true) or '---')
        end,
        cmp = function(record_a, record_b, desc)
            local price_a = price_per_unit and record_a.unit_buyout_price or record_a.buyout_price
            local price_b = price_per_unit and record_b.unit_buyout_price or record_b.buyout_price
            price_a = price_a > 0 and price_a or (desc and -math.huge or math.huge)
            price_b = price_b > 0 and price_b or (desc and -math.huge or math.huge)

            return sort_util.compare(price_a, price_b, desc)
        end,
    },
    {
        -- 0.8.2 build 6 (Tyler): "% of usual" everywhere (was "% Hist. Value")
        title = {'% of usual\n(bid)', '% of\nusual'},
        width = .08,
        align = 'CENTER',
        toggle = 'percentage_for_bid',
        fill = function(cell, record)
            local primary, secondary = record_percentage(record)
            cell.text:SetText((primary or secondary) and gui.percentage_historical(primary or secondary, not primary) or '?')
        end,
        cmp = function(record_a, record_b, desc)
            local pct_a = record_percentage(record_a) or (desc and -math.huge or math.huge)
            local pct_b = record_percentage(record_b) or (desc and -math.huge or math.huge)
            return sort_util.compare(pct_a, pct_b, desc)
        end,
    },
}

M.auctions_columns = {
    requirement_column(),
    item_level_column(),
    {
        title = 'Item',
        width = .32,
        init = item_column_init,
        fill = item_column_fill,
        cmp = function(record_a, record_b, desc)
            return sort_util.compare(record_a.name, record_b.name, desc)
        end,
    },
    quantity_column('Quantity'),
    {
        title = 'Time\nLeft',
        width = .04,
        align = 'CENTER',
        fill = function(cell, record)
            if record.sale_status == 1 then
                cell.text:SetText('?')
            else
                cell.text:SetText(TIME_LEFT_STRINGS[record.duration or 0] or '?')
            end
        end,
        cmp = function(record_a, record_b, desc)
            if record_a.sale_status == 1 and record_b.sale_status == 1 then
                return sort_util.EQ
            elseif record_a.sale_status == 1 then
                return sort_util.GT
            elseif record_b.sale_status == 1 then
                return sort_util.LT
            else
                return sort_util.compare(record_a.duration, record_b.duration, desc)
            end
        end,
    },
    {
        title = {'Auction Bid\n(per item)', 'Auction Bid\n(per stack)'},
        bid = true,
        width = .125,
        align = 'RIGHT',
        toggle = 'price_per_unit',
        fill = function(cell, record)
            if record.sale_status == 1 and price_per_unit then
                cell.text:SetText('?')
                return
            end
            local price
            if record.high_bidder then
                price = price_per_unit and ceil(record.high_bid / record.count) or record.high_bid
            else
                price = price_per_unit and ceil(record.start_price / record.count) or record.start_price
            end
            cell.text:SetText(money.to_string(price, true))
        end,
        cmp = function(record_a, record_b, desc)
            if price_per_unit then
                if record_a.sale_status == 1 and record_b.sale_status == 1 then
                    return sort_util.EQ
                elseif record_a.sale_status == 1 then
                    return sort_util.GT
                elseif record_b.sale_status == 1 then
                    return sort_util.LT
                end
            end
            local price_a
            if record_a.high_bidder then
                price_a = price_per_unit and record_a.high_bid / record_a.count or record_a.high_bid
            else
                price_a = price_per_unit and record_a.start_price / record_b.count or record_a.start_price
            end
            local price_b
            if record_b.sale_status == 1 and price_per_unit then
                price_b = math.huge
            elseif record_b.high_bidder then
                price_b = price_per_unit and record_b.high_bid / record_b.count or record_b.high_bid
            else
                price_b = price_per_unit and record_b.start_price / record_b.count or record_b.start_price
            end
            return sort_util.compare(price_a, price_b, desc)
        end,
    },
    {
        title = {'Auction Buyout\n(per item)', 'Auction Buyout\n(per stack)'},
        width = .125,
        align = 'RIGHT',
        toggle = 'price_per_unit',
        fill = function(cell, record)
            if record.sale_status == 1 and price_per_unit then
                cell.text:SetText('?')
                return
            end
            local price = price_per_unit and ceil(record.unit_buyout_price) or record.buyout_price
            cell.text:SetText(price > 0 and money.to_string(price, true) or '---')
        end,
        cmp = function(record_a, record_b, desc)
            if price_per_unit then
                if record_a.sale_status == 1 and record_b.sale_status == 1 then
                    return sort_util.EQ
                elseif record_a.sale_status == 1 then
                    return sort_util.GT
                elseif record_b.sale_status == 1 then
                    return sort_util.LT
                end
            end

            local price_a = price_per_unit and record_a.unit_buyout_price or record_a.buyout_price
            local price_b = price_per_unit and record_b.unit_buyout_price or record_b.buyout_price
            price_a = price_a > 0 and price_a or (desc and -math.huge or math.huge)
            price_b = price_b > 0 and price_b or (desc and -math.huge or math.huge)

            return sort_util.compare(price_a, price_b, desc)
        end,
    },
    {
        title = 'Status',
        width = .21,
        align = 'CENTER',
        fill = function(cell, record)
            local text
            if not record.high_bidder then
                text = aux.color.red'No Bids'
            elseif record.sale_status == 1 then
                text = aux.color.blue'Sold: ' .. record.high_bidder
            else
                text = aux.color.green'Bid: ' .. record.high_bidder
            end
            cell.text:SetText(text)
        end,
        cmp = function(record_a, record_b, desc)
            local status_order = sort_util.compare(status_code(record_a), status_code(record_b), desc)
            if status_order ~= sort_util.EQ then
                return status_order
            elseif not record_a.high_bidder and not record_b.high_bidder then
                return sort_util.EQ
            elseif not record_a.high_bidder then
                return sort_util.GT
            elseif not record_b.high_bidder then
                return sort_util.LT
            else
                return sort_util.compare(record_a.high_bidder, record_b.high_bidder, desc)
            end
        end,
    },
}

M.bids_columns = {
    requirement_column(),
    item_level_column(),
    {
        title = 'Item',
        width = .32,
        init = item_column_init,
        fill = item_column_fill,
        cmp = function(record_a, record_b, desc)
            return sort_util.compare(record_a.name, record_b.name, desc)
        end,
    },
    quantity_column('Quantity'),
    {
        title = 'Time\nLeft',
        width = .04,
        align = 'CENTER',
        fill = function(cell, record)
            cell.text:SetText(TIME_LEFT_STRINGS[record.duration or 0] or '?')
        end,
        cmp = function(record_a, record_b, desc)
            return sort_util.compare(record_a.duration, record_b.duration, desc)
        end,
    },
    {
        title = 'Seller',
        width = .13,
        align = 'CENTER',
        fill = function(cell, record)
            cell.text:SetText(seller_text(record))
        end,
        cmp = function(record_a, record_b, desc)
            -- a row of several sellers ("4 sellers") sorts with the other unnamed ones, not by the
            -- name of the one auction it keeps (review H-006, finding 5)
            local owner_a = (record_a.group_sellers or 1) <= 1 and record_a.owner
            local owner_b = (record_b.group_sellers or 1) <= 1 and record_b.owner
            if not owner_a and not owner_b then
                return sort_util.EQ
            elseif not owner_a then
                return sort_util.GT
            elseif not owner_b then
                return sort_util.LT
            else
                return sort_util.compare(owner_a, owner_b, desc)
            end
        end,
    },
    {
        title = {'Auction Bid\n(per item)', 'Auction Bid\n(per stack)'},
        bid = true,
        width = .125,
        align = 'RIGHT',
        toggle = 'price_per_unit',
        fill = function(cell, record)
            local price
            if record.high_bidder then
                price = price_per_unit and ceil(record.high_bid / record.count) or record.high_bid
            else
                price = price_per_unit and ceil(record.unit_bid_price) or record.bid_price
            end
            cell.text:SetText(money.to_string(price))
        end,
        cmp = function(record_a, record_b, desc)
            local price_a
            if record_a.high_bidder then
                price_a = price_per_unit and record_a.high_bid / record_a.count or record_a.high_bid
            else
                price_a = price_per_unit and record_a.unit_bid_price or record_a.bid_price
            end
            local price_b
            if record_b.high_bidder then
                price_b = price_per_unit and record_b.high_bid / record_b.count or record_b.high_bid
            else
                price_b = price_per_unit and record_b.unit_bid_price or record_b.bid_price
            end
            return sort_util.compare(price_a, price_b, desc)
        end,
    },
    {
        title = {'Auction Buyout\n(per item)', 'Auction Buyout\n(per stack)'},
        width = .125,
        align = 'RIGHT',
        toggle = 'price_per_unit',
        fill = function(cell, record)
            local price = price_per_unit and ceil(record.unit_buyout_price) or record.buyout_price
            cell.text:SetText(price > 0 and money.to_string(price, true) or '---')
        end,
        cmp = function(record_a, record_b, desc)
            local price_a = price_per_unit and record_a.unit_buyout_price or record_a.buyout_price
            local price_b = price_per_unit and record_b.unit_buyout_price or record_b.buyout_price
            price_a = price_a > 0 and price_a or (desc and -math.huge or math.huge)
            price_b = price_b > 0 and price_b or (desc and -math.huge or math.huge)

            return sort_util.compare(price_a, price_b, desc)
        end,
    },
    {
        title = 'Status',
        width = .115,
        align = 'CENTER',
        fill = function(cell, record)
            local status
            if record.high_bidder then
                status = aux.color.yellow'High Bidder'
            else
                status = aux.color.red'Outbid'
            end
            cell.text:SetText(status)
        end,
        cmp = function(record_a, record_b, desc)
            return sort_util.compare(record_a.high_bidder and 1 or 0, record_b.high_bidder and 1 or 0, desc)
        end,
    },
}

function record_percentage(record)
    if not record then return end

    local historical_value = history.value(record.price_key or record.item_key) or 0
    if historical_value > 0 then
        if record.unit_buyout_price > 0 or percentage_for_bid then
            local unit_price = percentage_for_bid and record.unit_bid_price or record.unit_buyout_price
            return aux.round(100 * unit_price / historical_value)
        end
        return nil, aux.round(100 * record.unit_bid_price / historical_value)
    end
end

function M.time_left(code)
    return TIME_LEFT_STRINGS[code]
end

local methods = {

    -- auxForever (0.7 build 3, Tyler): after a fast resize the table kept the width of a step
    -- before, so at the smallest window its right columns ran past the edge. Same fix as the lists
    -- in FB-006: the content area's own size event lays the table out with the width it reports
    -- (content_width), and the last column is anchored to the right edge (create_row, M.new). Later
    -- layouts (new rows, a new search) reuse that width instead of measuring, which can lag behind.
    ResizeColumns = function(self, content_width)
        local function column_width(cell)
            return (cell.info.bid and self.hide_bid) and 0 or cell.info.width
        end
        if content_width and content_width > 0 then
            self.content_width = content_width
        end
        local width = self.content_width
        if not width then
            local right, left = self.contentFrame:GetRight(), self.contentFrame:GetLeft()
            if not right or not left then return end
            width = right - left
        end
        -- nothing changed since the last layout: no widget work (a drag resizes every frame)
        local layout = width .. ':' .. tostring(self.hide_bid) .. ':' .. #self.rows
        if layout == self.layout then return end
        self.layout = layout
        local weight = 0
        for _, cell in pairs(self.headCells) do
            weight = weight + column_width(cell)
        end
        weight = width / weight
        for i, cell in pairs(self.headCells) do
            local width = column_width(cell) * weight
            local shown = width > 0
            cell:SetWidth(max(width, .001))
            if shown then cell:Show() else cell:Hide() end
            for _, row in pairs(self.rows) do
                row.cells[i]:SetWidth(max(width, .001))
                if shown then row.cells[i]:Show() else row.cells[i]:Hide() end
            end
        end
    end,

    OnHeadColumnClick = function(self, button)
        local rt = self.rt

        local toggle = rt.headCells[self.columnIndex].info.toggle
        if button == 'RightButton' and toggle then
            _M[toggle] = not _M[toggle]
            for _, cell in pairs(rt.headCells) do
                if cell.info.toggle == toggle then
                    cell:SetText(cell.info.title[_M[toggle] and 1 or 2])
                end
            end
            rt:SetSort()
            return
        end

        local descending = false
        if #rt.sorts > 0 and rt.sorts[1].index == self.columnIndex then
            descending = not rt.sorts[1].descending
        end
        rt:SetSort((descending and -1 or 1) * self.columnIndex)
    end,

    OnIconEnter = function(self)
        local rt = self:GetParent().row.rt
        local row = self:GetParent().row
        if row.record then
	        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
            local key = row.record.browse_key
            if key and GameTooltip.SetItemKey then
                -- auxForever: a fast mode row has no link of its own; this shows its suffix too
                GameTooltip:SetItemKey(key.itemID, key.itemLevel or 0, key.itemSuffix or 0, row.record.requirement or 0)
            else
                GameTooltip:SetHyperlink(row.record.link)
            end
            GameTooltip_ShowCompareItem()
            gui.add_click_hint(GameTooltip, rt:ClickHint(row))
            GameTooltip:Show()
        end
    end,

    -- auxForever (0.5, docs/clicks.md): the clicks of a row, for the gray line at the bottom of its
    -- tooltips. A tab adds its Alt shortcuts with rt.alt_hint (shown only when they are turned on).
    ClickHint = function(self, row)
        local parts = {}
        local selection = self:GetSelection()
        local selected = selection and selection.record == row.record
        if row.record and row.record.fast then
            tinsert(parts, 'Click: see its auctions')
        elseif selected then
            tinsert(parts, 'Click again: let go')
        else
            tinsert(parts, 'Click: select')
        end
        tinsert(parts, 'Right-click: search')
        if not self.rowInfo.single_item then
            if self.expanded[row.expandKey] then
                tinsert(parts, 'Double-click: collapse')
            elseif row.expandable then
                tinsert(parts, 'Double-click: expand')
            end
        end
        if selected and self.alt_hint and aux.account_data.action_shortcuts then
            tinsert(parts, self.alt_hint)
        end
        return table.concat(parts, gui.HINT_SEPARATOR)
    end,

    OnIconLeave = function()
        GameTooltip:Hide()
    end,

    OnEnter = function(self)
        local rt = self.rt
        -- auxForever (0.5): every row says what its clicks do, in one gray line (was: only grouped
        -- and fast rows, in white)
        if self.record then
            GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
            gui.add_click_hint(GameTooltip, rt:ClickHint(self), true)
            GameTooltip:Show()
        end

        self.hover:Show()
    end,

    OnLeave = function(self)
        GameTooltip:Hide()
        self.hover:Hide()
    end,

    OnClick = function(self, button)
        if IsControlKeyDown() or IsShiftKeyDown() then
            HandleModifiedItemClick(self.record.link)
        else
            if button == 'LeftButton' then
                local selection = self.rt:GetSelection()
                if not selection or selection.record ~= self.record then
                    self.rt:SetSelectedRecord(self.record)
                elseif not IsAltKeyDown() then
                    -- auxForever (0.5, docs/clicks.md): clicking the selected row again lets go of
                    -- it, in every table (Alt-click on it is the opt-in buy/cancel shortcut)
                    self.rt:SetSelectedRecord()
                end
                -- the hint line follows the new state
                if GameTooltip:IsShown() and GameTooltip:GetOwner() == UIParent then
                    self.rt.OnEnter(self)
                end
            end
	        do (self.rt.handlers.OnClick or pass)(self, button) end
        end
    end,

    OnDoubleClick = function(self)
        local rt = self.rt
        local expand = not rt.expanded[self.expandKey]

        rt.expanded[self.expandKey] = expand
        rt:UpdateRowInfo()
        rt:UpdateRows()
        if not self.indented then
            rt:SetSelectedRecord(self.record)
        end
    end,

    UpdateRowInfo = function(self)
        aux.wipe(self.rowInfo)
        self.rowInfo.numDisplayRows = 0
        self.isSorted = nil
        self:SetSelectedRecord(nil, true)

	    local records = self.records

        -- 0.8: grouped by price key, so each gear ending is an item of its own (review H-002, finding 3)
        local function group(record) return record.price_key or record.item_key end
        self.rowInfo.single_item = aux.all(records, function(record) return group(record) == group(records[1]) end)

        -- auxForever (0.8, Tyler, build 7: "Why are we separating these lines?"): gear auctions at one
        -- buyout price are one row, whoever sells them and whatever time they have left. The auction
        -- house hands them over per seller and time left; four sellers at 11s were four rows. The row
        -- keeps one real auction behind it (the lowest starting bid), so buying it buys exactly the
        -- price shown; when it is gone the next one moves up. Trade goods come grouped by price
        -- already; the Auctions tab keeps each of your auctions apart (one_row_each).
        local function row_group(record)
            return self.one_row_each and record.search_signature or price_group(record)
        end
        for _, record in ipairs(records) do
            record.price_group, record.group_sellers, record.group_count = row_group(record), nil, nil
        end
        -- within one price, the auction kept for the row is the one with the lowest starting bid, by
        -- value (review H-004, finding 3: compared as text, "1200" came before "200")
        sort(records, function(a, b)
            if a.price_group ~= b.price_group then return a.price_group < b.price_group end
            if (a.bid_price or 0) ~= (b.bid_price or 0) then return (a.bid_price or 0) < (b.bid_price or 0) end
            return a.search_signature < b.search_signature or a.search_signature == b.search_signature and tostring(a) < tostring(b)
        end)

        -- the sellers of the row being built, to say "4 sellers": each named seller once (review H-004,
        -- finding 6: one seller with two time lefts counted twice), unnamed ones by their count
        local sellers, named
        local function start_row(record)
            named = {}
            if record.owner then named[record.owner] = true end
            sellers = max(1, record.seller_count or 1)
        end
        for i = 1, #records do
            local record = records[i]
            local prevRecord = records[i - 1]
            if prevRecord and record.price_group == prevRecord.price_group then
                local child = self.rowInfo[#self.rowInfo].children[#self.rowInfo[#self.rowInfo].children]
                if not record.owner then
                    sellers = sellers + max(1, record.seller_count or 1)
                elseif not named[record.owner] then
                    named[record.owner] = true
                    sellers = sellers + 1
                end
                if sellers > 1 then child.record.group_sellers = sellers end
                -- the same price as the previous row (identical, or another seller or time left), so
                -- it adds to that row's count. Forever: one record can stand for a bucket of identical
                -- auctions (auction_count)
                child.count = child.count + (record.auction_count or 1)
                -- the buy bar says how many the row holds (review H-004, finding 5)
                child.record.group_count = child.count
            elseif not self.rowInfo.single_item and not self.one_row_each and prevRecord and group(record) == group(prevRecord) then
                -- it's the same base item as the previous row so insert a new auction
                start_row(record)
                tinsert(self.rowInfo[#self.rowInfo].children, { count = record.auction_count or 1, record = record })
                if self.expanded[self.rowInfo[#self.rowInfo].expandKey] then
                    self.rowInfo.numDisplayRows = self.rowInfo.numDisplayRows + 1
                end
            else
                -- it's a different base item from the previous row
                start_row(record)
                tinsert(self.rowInfo, { item_key = record.item_key, expandKey = group(record), children = {{ count = record.auction_count or 1, record = record }} })
                self.rowInfo.numDisplayRows = self.rowInfo.numDisplayRows + 1
            end
        end

        -- auxForever: when any price in the table has copper, every price shows all its parts
        local has_copper = false
        for _, record in ipairs(records) do
            for _, amount in ipairs{ceil(record.unit_buyout_price or 0), ceil(record.unit_bid_price or 0), record.buyout_price or 0, record.bid_price or 0} do
                if amount % 100 ~= 0 then
                    has_copper = true
                    break
                end
            end
            if has_copper then break end
        end
        self.has_copper = has_copper

	    -- auxForever: rows show units for sale (see quantity_column), so total units per item
	    for _, v in ipairs(self.rowInfo) do
            local totalUnits, totalPlayerUnits = 0, 0
            for _, childInfo in pairs(v.children) do
                childInfo.units = childInfo.count * (childInfo.record.count or 1)
                totalUnits = totalUnits + childInfo.units
                if info.is_player(childInfo.record.owner) then
                    totalPlayerUnits = totalPlayerUnits + childInfo.units
                end
            end
            v.totalUnits = totalUnits
            v.totalPlayerUnits = totalPlayerUnits
	    end

	    -- auxForever: trade goods cannot be bid on, so the Bid column hides when every row is one
	    local all_commodities = #records > 0
	    for _, record in ipairs(records) do
	        if not (record.commodity or record.is_commodity) then
	            all_commodities = false
	            break
	        end
	    end
	    self.hide_bid = all_commodities
    end,

    UpdateRows = function(self)
	    if self.rowInfo.numDisplayRows > #self.rows then
		    self.contentFrame:SetPoint('BOTTOMRIGHT', -15, 0)
	    else
		    self.contentFrame:SetPoint('BOTTOMRIGHT', 0, 0)
	    end
	    self:ResizeColumns()

	    FauxScrollFrame_Update(self.scrollFrame, self.rowInfo.numDisplayRows, #self.rows, self.ROW_HEIGHT)

	    local maxOffset = max(self.rowInfo.numDisplayRows - #self.rows, 0)
	    if FauxScrollFrame_GetOffset(self.scrollFrame) > maxOffset then
		    FauxScrollFrame_SetOffset(self.scrollFrame, maxOffset)
	    end

        -- auxForever (0.6, the UI Kit): the sorted column's name is white with a gold arrow
        local last_sort = self.sorts[1]
        -- 0.8.2 build 6 (Tyler's test): the width of a two-line title is its longest line; the font
        -- string's own width came out narrower, and the arrow sat on the "%" of "% Hist. Value"
        local function header_text_width(cell)
            local font_string = cell:GetFontString()
            local text = font_string:GetText() or ''
            if not strfind(text, '\n', 1, true) then
                return font_string:GetStringWidth() or 0
            end
            if not cell.measure then
                cell.measure = cell:CreateFontString(nil, 'OVERLAY')
                cell.measure:Hide()
            end
            local font, size, flags = font_string:GetFont()
            if font and size and size > 0 then
                cell.measure:SetFont(font, size, flags)
            end
            local widest = 0
            for line in gmatch(text, '[^\n]+') do
                cell.measure:SetText(line)
                widest = max(widest, cell.measure:GetStringWidth() or 0)
            end
            return widest
        end
        for i, cell in pairs(self.headCells) do
            local sorted = last_sort and last_sort.index == i
            cell:GetFontString():SetTextColor((sorted and aux.color.text.enabled or aux.color.header.text)())
            if sorted then
                local width = header_text_width(cell)
                cell.arrow:ClearAllPoints()
                cell.arrow:SetPoint('RIGHT', cell, 'CENTER', -width / 2 - 3, 0)
                cell.arrow:SetRotation(last_sort.descending and 0 or math.pi)
                cell.arrow:Show()
            else
                cell.arrow:Hide()
            end
        end

        if not self.isSorted then
            local function sort_helper(a, b)

                local record_a, record_b
                if a.children then
                    record_a = a.children[1].record
                    record_b = b.children[1].record
                else
                    record_a = a.record
                    record_b = b.record
                end

                -- 0.8.2 build 7 (H-010, finding 3): rows a tab keeps in place (record.row_pin 1, 2, ...)
                -- stay first in that order, whatever the sort (the Sniper while a deal is selected)
                local pin_a, pin_b = record_a.row_pin, record_b.row_pin
                if pin_a or pin_b then
                    if not pin_b then
                        return true
                    elseif not pin_a then
                        return false
                    elseif pin_a ~= pin_b then
                        return pin_a < pin_b
                    end
                end

                for _, sort in pairs(self.sorts) do
                    local column = self.columns[sort.index]
                    local ordering
                    if a.children and column.row_cmp then
                        ordering = column.row_cmp(a, b, sort.descending)
                    else
                        ordering = column.cmp and column.cmp(record_a, record_b, sort.descending) or sort_util.EQ
                    end

                    if ordering == sort_util.LT then
                        return true
                    elseif ordering == sort_util.GT then
                        return false
                    end
                end

                return tostring(a) < tostring(b)
            end

            for _, v in ipairs(self.rowInfo) do
                sort(v.children, sort_helper)
            end
            sort(self.rowInfo, sort_helper)
            self.isSorted = true
        end

	    for _, row in pairs(self.rows) do
		    row:Hide()
	    end
        local rowIndex = 1 - FauxScrollFrame_GetOffset(self.scrollFrame)
        money.set_full_parts(self.has_copper)
        for _, v in ipairs(self.rowInfo) do
            if self.expanded[v.expandKey] then
                for j, childInfo in ipairs(v.children) do
                    self:SetRowInfo(rowIndex, childInfo.record, childInfo.units, 0, j > 1, false, v.expandKey)
                    rowIndex = rowIndex + 1
                end
            else
                self:SetRowInfo(rowIndex, v.children[1].record, v.totalUnits, #v.children > 1 and v.totalPlayerUnits or 0, false, #v.children > 1, v.expandKey)
                rowIndex = rowIndex + 1
            end
        end
        money.set_full_parts(false)
    end,

    SetRowInfo = function(self, rowIndex, record, units, own_units, indented, expandable, expandKey)
        if rowIndex <= 0 or rowIndex > #self.rows then return end
        local row = self.rows[rowIndex]
        row:Show()
        if self.selected and record.search_signature == self.selected.search_signature then
            row.highlight:Show()
        else
            row.highlight:Hide()
        end

        row.record = record
        row.expandable = expandable
        row.indented = indented
        row.expandKey = expandKey

        for i, column in pairs(self.columns) do
	        column.fill(row.cells[i], record, units, own_units, expandable, indented)
        end
    end,

    SetSelectedRecord = function(self, record, silent)
        self.selected = record
        local selectedData = self:GetSelection()
        self.selected = selectedData and self.selected or nil

        for _, row in pairs(self.rows) do
            if self.selected and row.record and row.record.search_signature == self.selected.search_signature then
                row.highlight:Show()
            else
                row.highlight:Hide()
            end
        end

        if not silent and self.handlers.OnSelectionChanged then
            self.handlers.OnSelectionChanged(self, selectedData or nil)
        end
    end,

    Reset = function(self)
        aux.wipe(self.expanded)
        self:UpdateRowInfo()
        self:UpdateRows()
        self:SetSelectedRecord()
    end,

    SetDatabase = function(self, database)
        if database and database ~= self.records then
            self.records = database
        end

        local prevSelectedIndex
        local prev_selected = self.selected
        if self.selected then
            for i, row in pairs(self.rows) do
                if row:IsVisible() and row.record == self.selected then
                    prevSelectedIndex = i
                end
            end
        end

        self:UpdateRowInfo()
        self:UpdateRows()

        -- auxForever: the same record stays selected while it is still listed. aux reselected by row
        -- position, so new rows above it moved the selection onto another record (Tyler, 0.4.1,
        -- Sniper: "the item I am selecting changes every time a new item is added")
        if not self.selected and prev_selected then
            for _, record in ipairs(self.records or empty) do
                if record == prev_selected then
                    self:SetSelectedRecord(record)
                    break
                end
            end
        end
        -- 0.8: the auction bought was the one a price row kept; the row stays selected with its next
        -- auction, even when a sort moved the row (review H-006, finding 5)
        if not self.selected and prev_selected and prev_selected.price_group then
            for _, info_row in ipairs(self.rowInfo) do
                for _, child in ipairs(info_row.children) do
                    if child.record.price_group == prev_selected.price_group then
                        self:SetSelectedRecord(child.record)
                        break
                    end
                end
                if self.selected then break end
            end
        end
        -- keep_selection_only (the Sniper): every row is another item, so a deal that left the table
        -- (ignored, replaced) leaves nothing selected; the next row was selected and offered to buy
        -- (H-010, finding 3). The Auctions and Bids tabs read their lists anew, as new records, and
        -- keep the selection by row position.
        if not self.selected and prevSelectedIndex and not self.keep_selection_only then
            -- try to select the same row
            local row = self.rows[prevSelectedIndex]
            if row and row:IsVisible() and row.record then
                self:SetSelectedRecord(row.record)
            end
            if not self.selected then
                -- select the first row
                row = self.rows[1]
                if row and row:IsVisible() and row.record then
                    self:SetSelectedRecord(row.record)
                end
            end
        end
    end,

    RemoveAuctionRecord = function(self, record)
        local index = aux.key(self.records, record)
        if index then
            tremove(self.records, index)
        end
        self:SetDatabase()
    end,

    ContainsRecord = function(self, record)
        if aux.key(self.records, record) then
            return true
        end
    end,

    SetSort = function(self, ...)
        for _, v in ipairs{...} do
            for i, sort in ipairs(self.sorts) do
                if sort.index == abs(v) then
                    tremove(self.sorts, i)
                    break
                end
            end
            tinsert(self.sorts, 1, {index=abs(v), descending=v < 0})
        end

        self.isSorted = nil
        self:UpdateRows()
    end,

    SetHandler = function(self, event, handler)
        self.handlers[event] = handler
    end,

    GetSelection = function(self)
        if not self.selected then return end
        local selectedData
        for _, v in ipairs(self.rowInfo) do
            for _, childInfo in pairs(v.children) do
                if childInfo.record.search_signature == self.selected.search_signature then
                    selectedData = childInfo
                    break
                end
            end
        end
        return selectedData
    end,
}

-- Forever: the window can be resized, so a listing has a fixed row height and shows as many rows
-- as fit. Rows are created when first needed and kept for when the window grows again.
local function create_row(rt, i)
    local row = CreateFrame('Button', nil, rt.contentFrame)
    row.rt = rt
    row:SetHeight(rt.ROW_HEIGHT)
    row:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
    row:SetScript('OnEnter', rt.OnEnter)
    row:SetScript('OnLeave', rt.OnLeave)
    row:SetScript('OnClick', rt.OnClick)
    row:SetScript('OnDoubleClick', rt.OnDoubleClick)
    row:SetPoint('TOPLEFT', 0, -(HEAD_HEIGHT + HEAD_SPACE + (i - 1) * rt.ROW_HEIGHT))
    row:SetPoint('TOPRIGHT', 0, -(HEAD_HEIGHT + HEAD_SPACE + (i - 1) * rt.ROW_HEIGHT))
    gui.row_stripe(row, i)
    row.highlight = gui.row_selection(row)
    row.hover = gui.row_hover(row)

    row.cells = {}
    for j, column in ipairs(rt.columns) do
        local cell = CreateFrame('Frame', nil, row)
        local text = cell:CreateFontString()
        cell.text = text
        text:SetFont(gui.font, min(14, rt.ROW_HEIGHT))
        text:SetJustifyH(column.align or 'LEFT')
        text:SetJustifyV('MIDDLE')
        text:SetPoint('TOPLEFT', 1, -1)
        text:SetPoint('BOTTOMRIGHT', -1, 1)
        cell:SetHeight(rt.ROW_HEIGHT)
        cell.rt = rt
        cell.row = row

        if j == 1 then
            cell:SetPoint('TOPLEFT', 0, 0)
        else
            cell:SetPoint('TOPLEFT', row.cells[j - 1], 'TOPRIGHT')
        end
        if j == #rt.columns then
            cell:SetPoint('TOPRIGHT', 0, 0)
        end

        if column.init then
            column.init(rt, cell)
        end

        tinsert(row.cells, cell)
    end

    row:Hide()
    return row
end

local function fit_rows(rt)
    if not rt.all_rows then return end
    local height = rt:GetHeight() or 0
    if height <= 0 then return end
    local count = max(floor((height - HEAD_HEIGHT - HEAD_SPACE) / rt.ROW_HEIGHT), 0)
    if count == #rt.rows then
        rt:ResizeColumns()
        return
    end
    for i = count + 1, #rt.all_rows do
        rt.all_rows[i]:Hide()
    end
    rt.rows = {}
    for i = 1, count do
        rt.all_rows[i] = rt.all_rows[i] or create_row(rt, i)
        rt.rows[i] = rt.all_rows[i]
    end
    rt:ResizeColumns()
    rt:UpdateRows()
end

function M.new(parent, row_height, columns)
    local rt = CreateFrame('Frame', nil, parent)
    rt.columns = columns
    rt.ROW_HEIGHT = row_height
    rt.expanded = {}
    rt.handlers = {}
    rt.sorts = {}
    rt.records = {}
    rt.rowInfo = {numDisplayRows=0}

    for name, func in pairs(methods) do
        rt[name] = func
    end

    rt:SetScript('OnShow', function(self)
        -- the window may have changed size while the table was hidden: measure again
        self.content_width = nil
        fit_rows(self)
        for _, cell in pairs(self.headCells) do
            if cell.info.toggle then
                cell:SetText(cell.info.title[_M[cell.info.toggle] and 1 or 2])
            end
        end
    end)

    local contentFrame = CreateFrame('Frame', nil, rt)
    contentFrame:SetPoint('TOPLEFT', 0, 0)
    contentFrame:SetPoint('BOTTOMRIGHT', 0, 0)
    contentFrame:SetScript('OnSizeChanged', function(_, width)
        rt:ResizeColumns(width)
    end)
    rt.contentFrame = contentFrame

    local scrollFrame = CreateFrame('ScrollFrame', gui.unique_name(), rt, 'FauxScrollFrameTemplate')
    scrollFrame:SetScript('OnVerticalScroll', function(self, offset)
	    FauxScrollFrame_OnVerticalScroll(self, offset, rt.ROW_HEIGHT, function() rt:UpdateRows() end)
    end)
    scrollFrame:SetAllPoints(contentFrame)
    rt.scrollFrame = scrollFrame
    FauxScrollFrame_Update(rt.scrollFrame, 0, 0, rt.ROW_HEIGHT)

    local scrollBar = _G[scrollFrame:GetName() .. 'ScrollBar']
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint('TOPRIGHT', rt, -4, -HEAD_HEIGHT)
    scrollBar:SetPoint('BOTTOMRIGHT', rt, -4, 4)
    scrollBar:SetWidth(10)
    local thumbTex = scrollBar:GetThumbTexture()
    thumbTex:SetPoint('CENTER', 0, 0)
    gui.texture_color(thumbTex, aux.color.scrollbar)
    thumbTex:SetHeight(150)
    thumbTex:SetWidth(6)
    _G[scrollBar:GetName() .. 'ScrollUpButton']:Hide()
    _G[scrollBar:GetName() .. 'ScrollDownButton']:Hide()

    rt.headCells = {}
    for i, column in ipairs(rt.columns) do
        local cell = CreateFrame('Button', nil, rt.contentFrame)
        cell:SetHeight(HEAD_HEIGHT)
        if i == 1 then
            cell:SetPoint('TOPLEFT', 0, 0)
        else
            cell:SetPoint('TOPLEFT', rt.headCells[i - 1], 'TOPRIGHT')
        end
        if i == #rt.columns then
            cell:SetPoint('TOPRIGHT', 0, 0)
        end
        cell.info = column
        cell.rt = rt
        cell.columnIndex = i
        cell:RegisterForClicks('LeftButtonUp', 'RightButtonUp')

        cell:SetScript('OnClick', rt.OnHeadColumnClick)

        local text = cell:CreateFontString()
        text:SetJustifyH('CENTER')
        text:SetFont(gui.font, 12)
        gui.text_color(text, aux.color.header.text)
        cell:SetFontString(text)
        if not column.toggle then cell:SetText(column.title or '') end -- TODO
        text:SetAllPoints()

        -- auxForever (0.6, the UI Kit): a raised plate with a black edge, 1px below the table's top
        gui.set_frame_style(cell, aux.color.header.background, aux.color.window.border, 0, 0, 1, 0, 0)
        gui.add_sheen(cell, .26)
        gui.add_highlight(cell, 0)
        local arrow = cell:CreateTexture(nil, 'OVERLAY')
        arrow:SetTexture([[Interface\AddOns\auxForever\textures\chevron.tga]])
        arrow:SetSize(9, 9)
        gui.vertex_color(arrow, aux.color.accent.background)
        arrow:Hide()
        cell.arrow = arrow

        tinsert(rt.headCells, cell)
    end

    rt.rows = {}
    rt.all_rows = {}
    rt:SetScript('OnSizeChanged', fit_rows)

    rt:SetAllPoints()
    fit_rows(rt)
    rt:ResizeColumns()
    return rt
end