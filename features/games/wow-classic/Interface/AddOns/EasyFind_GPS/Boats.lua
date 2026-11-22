-- Boats, zeppelins, skyships and the ferry: when each leaves. One ride
-- fixes a route's place in its loop on this realm (the moment it left a
-- stop); every departure after follows from the route's timetable
-- (ns.GPSData.routes: its loop, and when it leaves each stop).
local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns or select(2, ...).tooOld then return end

local Boats = {}
ns.GPSBoats = Boats

local DOCK_YD = 60               -- a stop this close is where one boards or lands
local CARRIED_YD = 8             -- moved this far in a sample without walking: aboard
local NEAR_YD = 300              -- watched this close to a stop, and while aboard
local ABOARD_YD = 40             -- a docked boat's deck lies this close to where it is boarded
local SAME_STOP_YD = 10          -- a stop this close to a boarding spot is that spot
local SAMPLE_SECONDS = 1
local STILL_SAMPLES = 3          -- not carried this long: landed
local STALE_SECONDS = 6 * 3600   -- a sighting this old no longer times a route


local ticker, last, ride, still

local function Routes() return ns.GPSData and ns.GPSData.routes end

local function Store()
    local db = EasyFind.db
    if not db then return nil end
    local realm = GetRealmName and GetRealmName() or "?"
    db.gpsBoats = db.gpsBoats or {}
    db.gpsBoats[realm] = db.gpsBoats[realm] or {}
    return db.gpsBoats[realm]
end

local function Here()
    local m = C_Map.GetBestMapForUnit("player")
    if not m then return nil end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, m, "player")
    if not (ok and pos) then return nil end
    local ok2, ci, wp = pcall(C_Map.GetWorldPosFromMapPos, m, pos)
    if not (ok2 and wp) then return nil end
    local x, y = wp:GetXY()
    return ci, x, y
end

-- Every (route, stop) within r yards of a spot: { { route, stop }, ... }.
local function StopsNear(ci, x, y, r)
    local out = {}
    for id, route in pairs(Routes() or {}) do
        for s, st in ipairs(route.stops) do
            if st.ci == ci and (st.wx - x) ^ 2 + (st.wy - y) ^ 2 <= r * r then out[#out + 1] = { id, s } end
        end
    end
    return out
end

local function Stop()
    if ticker then ticker:Cancel() end
    ticker, last, ride, still = nil, nil, nil, 0
end

-- Landed at a stop: the route that runs from where the ride began to here,
-- its loop placed by the moment it left.
local function Landed(ci, x, y)
    local here = StopsNear(ci, x, y, DOCK_YD)
    local store = Store()
    for _, from in ipairs(ride.from) do
        for _, to in ipairs(here) do
            local route = Routes()[from[1]]
            if from[1] == to[1] and from[2] ~= to[2] and store then
                store[from[1]] = { epoch = ride.left - route.stops[from[2]].at, seen = ride.left }
                return
            end
        end
    end
end

local function Sample()
    local ci, x, y = Here()
    if not ci then return end
    local walking = IsPlayerMoving and IsPlayerMoving()
    local carried = last and last.ci == ci and not walking
        and (x - last.x) ^ 2 + (y - last.y) ^ 2 >= CARRIED_YD * CARRIED_YD
    if carried and not ride and last then
        local from = StopsNear(last.ci, last.x, last.y, DOCK_YD)
        if #from > 0 then
            ride = { from = from, left = GetServerTime() - SAMPLE_SECONDS / 2, ci = last.ci, x = last.x, y = last.y }
        end
    end
    if ride then
        if carried then
            still = 0
        else
            still = still + 1
            if still >= STILL_SAMPLES then
                Landed(ci, x, y)
                ride = nil
            end
        end
    end
    last = { ci = ci, x = x, y = y }
    -- Off watch once far from every stop and not aboard.
    if not ride and #StopsNear(ci, x, y, NEAR_YD) == 0 then Stop() end
end

local function Watch()
    if ticker then return end
    local ci, x, y = Here()
    if not ci or #StopsNear(ci, x, y, NEAR_YD) == 0 then return end
    still = 0
    ticker = C_Timer.NewTicker(SAMPLE_SECONDS, Sample)
end

-- Carried by a boat since it left a stop.
function Boats.Carried() return ride ~= nil end

-- Carried off from the dock at (bci, bx, by): the ride left nearer it than
-- any other stop (a tower's other zeppelin is another ride).
local function LeftFrom(bci, bx, by)
    if not (ride.x and bx) then return true end
    if ride.ci ~= bci then return false end
    local d = (bx - ride.x) ^ 2 + (by - ride.y) ^ 2
    for _, s in ipairs(StopsNear(ride.ci, ride.x, ride.y, DOCK_YD)) do
        local st = Routes()[s[1]].stops[s[2]]
        if (st.wx - ride.x) ^ 2 + (st.wy - ride.y) ^ 2 < d and (st.wx - bx) ^ 2 + (st.wy - by) ^ 2 > SAME_STOP_YD ^ 2 then
            return false
        end
    end
    return true
end

-- On board at (ci, x, y), its boarding spot at (bci, bx, by): carried by it,
-- or standing beside that spot where the walking grid has only open water
-- (the deck of a boat at the dock), not swimming nor falling.
function Boats.Aboard(ci, x, y, bci, bx, by)
    if ride then return LeftFrom(bci, bx, by) end
    if not (ci and bx and ci == bci) or (bx - x) ^ 2 + (by - y) ^ 2 > ABOARD_YD * ABOARD_YD then return false end
    if (IsSwimming and IsSwimming()) or (IsFalling and IsFalling()) then return false end
    local Nav = ns.GPSNav
    return Nav and Nav.OpenWater and Nav.OpenWater(ci, x, y) or false
end

-- Seconds one waits at a route's stop on arriving there arriveIn seconds
-- from now, until it next leaves; nil while no recent ride has timed it.
function Boats.WaitAt(routeID, stop, arriveIn)
    local route = Routes() and Routes()[routeID]
    local store = EasyFind.db and EasyFind.db.gpsBoats and EasyFind.db.gpsBoats[GetRealmName and GetRealmName() or "?"]
    local seen = store and store[routeID]
    local st = route and route.stops[stop]
    if not (seen and st) then return nil end
    local now = GetServerTime()
    if now - seen.seen > STALE_SECONDS then return nil end
    return (seen.epoch + st.at - (now + (arriveIn or 0))) % route.period
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_INDOORS")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:SetScript("OnEvent", function() Watch() end)

Boats._Sample = Sample   -- tests
