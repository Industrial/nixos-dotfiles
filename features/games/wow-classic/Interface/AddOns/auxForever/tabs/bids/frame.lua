select(2, ...) 'aux.tabs.bids'

local aux = require 'aux'
local info = require 'aux.util.info'
local gui = require 'aux.gui'
local auction_listing = require 'aux.gui.auction_listing'
local search_tab = require 'aux.tabs.search'

frame = CreateFrame('Frame', nil, aux.frame)
frame:SetAllPoints(aux.frame.body)
frame:SetScript('OnUpdate', on_update)
frame:Hide()

frame.listing = gui.panel(frame)
frame.listing:SetPoint('TOP', frame, 'TOP', 0, -8)
frame.listing:SetPoint('BOTTOMLEFT', aux.frame.content, 'BOTTOMLEFT', 0, 0)
frame.listing:SetPoint('BOTTOMRIGHT', aux.frame.content, 'BOTTOMRIGHT', 0, 0)

listing = auction_listing.new(frame.listing, 22, auction_listing.bids_columns)
-- each bid on its own row (0.8, review H-004, finding 1): two bids at one buyout are two auctions
listing.one_row_each = true
listing:SetSort(1, 2, 3, 4, 5, 6, 7, 8, 9)
listing:Reset()
listing.alt_hint = 'Alt-click: buyout  ·  Alt-right-click: bid'
listing:SetHandler('OnClick', function(row, button)
	if IsAltKeyDown() and aux.account_data.action_shortcuts then
		if listing:GetSelection() and listing:GetSelection().record == row.record then
			if button == 'LeftButton' then
				buyout_button:Click()
			elseif button == 'RightButton' then
				bid_button:Click()
			end
		end
	elseif button == 'RightButton' then
		aux.set_tab(1)
		search_tab.set_filter(strlower(info.item(row.record.item_id).name) .. '/exact')
		search_tab.execute(nil, false)
	end
end)

do
    local btn = gui.button(frame)
    btn:SetPoint('LEFT', aux.status_bar, 'RIGHT', 5, 0)
    btn:SetText('Bid')
    btn:Disable()
    btn:SetScript('OnClick', function() place_bid() end)
    bid_button = btn
end
do
    local btn = gui.button(frame)
    btn:SetPoint('TOPLEFT', bid_button, 'TOPRIGHT', 5, 0)
    btn:SetText('Buyout')
    btn:Disable()
    btn:SetScript('OnClick', function() place_bid(true) end)
    -- exported for the gamepad's Y (gamepad.lua)
    M.buyout_button = btn
end