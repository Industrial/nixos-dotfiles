select(2, ...) 'aux.tabs.bids'

local aux = require 'aux'
local scan = require 'aux.core.scan'

local tab = aux.tab 'Bids'

-- Forever: the list comes from C_AuctionHouse.QueryBids and bids are placed by auction ID.

function aux.event.AUX_LOADED()
    for _, event in ipairs{'BIDS_UPDATED', 'BID_ADDED'} do
        aux.event_listener(event, function()
            refresh = true
        end)
    end
    aux.event_listener('AUCTION_HOUSE_NEW_BID_RECEIVED', function()
        if aux.frame:IsShown() then
            aux.query_bids()
        end
    end)
end

function tab.OPEN()
    frame:Show()
    aux.query_bids()
end

function tab.CLOSE()
    listing:SetSelectedRecord()
    frame:Hide()
end

function M.scan_auctions()
    local auctions = {}
    for _, auction in scan.bidder_auctions() do
        tinsert(auctions, auction)
    end
    listing:SetDatabase(auctions)
end

function place_bid(buyout)
    -- nothing selected (the row was let go or left the list): nothing to bid on. The buttons stayed
    -- lit from the last selection and a click raised an error (outside review 2026-11-10, R-04)
    local selection = listing:GetSelection()
    local record = selection and selection.record
    if not record then
        return
    end
    local amount = buyout and record.buyout_price or record.bid_price
    if not amount or amount <= 0 then
        return
    end
    aux.place_bid(record.auction_id, amount, function()
        aux.query_bids()
    end)
end

-- auxForever: the list follows the game's events; a slow refresh keeps time left current. aux used
-- to run a thread every frame all game long to rebuild it every second.
REFRESH_SECONDS = 10

function on_update()
    if refresh or GetTime() >= (next_refresh or 0) then
        refresh = false
        next_refresh = GetTime() + REFRESH_SECONDS
        scan_auctions()
    end

    if GetTime() < (next_buttons or 0) then
        return
    end
    next_buttons = GetTime() + .2
    local selection = listing:GetSelection()
    if not selection then
        -- the buttons follow the selection: with none, neither can be pressed (R-04)
        bid_button:Disable()
        buyout_button:Disable()
    else
        if aux.bid_in_progress() then
            bid_button:Disable()
            buyout_button:Disable()
            return
        end
        if not selection.record.high_bidder then
            bid_button:Enable()
        else
            bid_button:Disable()
        end
        if selection.record.buyout_price > 0 then
            buyout_button:Enable()
        else
            buyout_button:Disable()
        end
    end
end
