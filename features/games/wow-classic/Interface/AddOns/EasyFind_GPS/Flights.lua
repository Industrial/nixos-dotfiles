-- Flight times measured on this account: each hop between two flight
-- masters, timed from passing one to passing the next. The planner takes
-- them over the estimate from the path's length.
local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns or select(2, ...).tooOld then return end

local Flights = {}
ns.GPSFlights = Flights

local PASS_YD = 60          -- a flight master this close below is passed
local LAND_YD = 120         -- where a flight starts or ends, the master this close
local SAMPLE_SECONDS = 1
local KEEP = 3              -- the last times of a hop kept; their middle one counts

local mfloor, tsort = math.floor, table.sort
local ticker, passes, startedAt

local function Store()
    local db = EasyFind.db
    if not db then return nil end
    db.gpsFlown = db.gpsFlown or {}
    return db.gpsFlown
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

-- The flight master nearest (ci, x, y) within r yards, or nil.
local function NearestNode(ci, x, y, r)
    local nodes = ns.GPSData and ns.GPSData.nodes
    local best, bd = nil, r * r
    for id, n in pairs(nodes or {}) do
        if n.ci == ci and n.wx then
            local d = (n.wx - x) ^ 2 + (n.wy - y) ^ 2
            if d <= bd then best, bd = id, d end
        end
    end
    return best
end

local function Sample()
    if not (UnitOnTaxi and UnitOnTaxi("player")) then return end
    local ci, x, y = Here()
    if not ci then return end
    local id = NearestNode(ci, x, y, PASS_YD)
    if id and passes[#passes].id ~= id then passes[#passes + 1] = { id = id, t = GetTime() } end
end

local function Stop()
    if ticker then ticker:Cancel() end
    ticker = nil
end

local function Start()
    local ci, x, y = Here()
    local from = ci and NearestNode(ci, x, y, LAND_YD)
    if not from then return end
    startedAt = GetTime()
    passes = { { id = from, t = startedAt } }
    Stop()
    ticker = C_Timer.NewTicker(SAMPLE_SECONDS, Sample)
end

-- Landed: each hop flown, its time kept.
local function Land()
    Stop()
    if not passes then return end
    local ci, x, y = Here()
    local to = ci and NearestNode(ci, x, y, LAND_YD)
    if to and passes[#passes].id ~= to then passes[#passes + 1] = { id = to, t = GetTime() } end
    local store = Store()
    for k = 2, store and #passes or 0 do
        local key = passes[k - 1].id .. ">" .. passes[k].id
        local times = store[key] or {}
        times[#times + 1] = mfloor(passes[k].t - passes[k - 1].t + 0.5)
        while #times > KEEP do table.remove(times, 1) end
        store[key] = times
    end
    passes = nil
end

-- Seconds a hop from flight master a to b took on this account, or nil.
function Flights.Seconds(a, b)
    local store = EasyFind.db and EasyFind.db.gpsFlown
    local times = store and store[a .. ">" .. b]
    if not times or #times == 0 then return nil end
    local sorted = {}
    for i = 1, #times do sorted[i] = times[i] end
    tsort(sorted)
    return sorted[mfloor((#sorted + 1) / 2)]
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_CONTROL_LOST")
frame:RegisterEvent("PLAYER_CONTROL_GAINED")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_CONTROL_LOST" then
        -- The client takes control a moment before the flight begins.
        C_Timer.After(0.5, function()
            if UnitOnTaxi and UnitOnTaxi("player") then Start() end
        end)
    elseif passes then
        Land()
    end
end)
