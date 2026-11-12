select(2, ...) 'aux.core.api'

local info = require 'aux.util.info'
local history = require 'aux.core.history'

-- auxForever (0.7, FB-012, asked by MDHippie): prices for other addons, in the
-- global AuxForeverAPI. Everything else in aux stays private to its modules. These names and what
-- they return are a promise to other addons: add new functions, never change or remove these.
-- Described for addon authors in docs/api.md. It only works when called: nothing runs per frame.

local api = {}

-- raises when a new function is added, so a caller can check for it
api.version = 1

-- an item link, an item string ("item:2589::::::"), or an item ID (number or digits) as aux's
-- price key ("2589:0"); nil if it is none of these
local function item_key(item)
    if type(item) == 'number' then
        return item > 0 and floor(item) .. ':0' or nil
    elseif type(item) ~= 'string' then
        return
    elseif strmatch(item, '^%d+$') then
        return item .. ':0'
    elseif strfind(item, 'item:%d') then
        return info.link_price_key(item)
    end
end

local function ready(item)
    local key = item_key(item)
    return key and history.loaded() and key or nil
end

-- The market price of the latest complete look at the item, in copper per item, and how many days
-- ago that look was (0: today). The same price aux shows as "Value" in tooltips. nil if aux has no
-- price for it.
function api.GetLatestPrice(item)
    local key = ready(item)
    if not key then return end
    local price, age = history.latest(key)
    if price then
        return price, age
    end
end

-- The usual price over the last days (newer days count more), in copper per item, and how many
-- days ago aux last saw the item. aux uses it to find deals. nil if aux has no price for it.
function api.GetUsualPrice(item)
    local key = ready(item)
    if not key then return end
    local price, age = history.value_and_age(key)
    if price then
        return price, age
    end
end

-- Whether the price history has loaded (it loads with the saved variables, at login)
function api.IsReady()
    return history.loaded()
end

_G.AuxForeverAPI = api
