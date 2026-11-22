-- Walking on WoW Forever's baked walking grid (ns.GPSNavData, written by
-- dev/tools/navmesh/pack.py): 4 yd cells, each with its floors, linked
-- where one can really walk. A long walk is searched on the tiles'
-- entrances; only the tiles at its ends, and those a drawn path crosses,
-- are unpacked and searched cell by cell.
local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns or select(2, ...).tooOld then return end

local Nav = {}
ns.GPSNav = Nav
local Floors = ns.GPSFloors   -- stacked city floors (Floors.lua), nil without them

local sbyte, schar, mfloor, msqrt, mhuge, mabs = string.byte, string.char, math.floor, math.sqrt, math.huge, math.abs
local mmax, mmin = math.max, math.min
local tinsert, tremove, tsort, tconcat = table.insert, table.remove, table.sort, table.concat

local TILE = 1600 / 3
local ORIGIN = 32 * TILE
local TILES_KEPT = 32              -- decoded tiles held at once, under 0.1 MB each
local SNAP_CELLS = 6               -- a point off the grid takes a floor this many cells away
local REACH_KEPT = 256             -- end points whose tile search is kept
local LANDMARKS_USED = 3           -- of the data's landmarks, the most telling for a walk
local WALKS_KEPT = 512             -- walk costs kept
local MARKS_KEPT = 2048            -- points whose landmark distances are kept
-- Walking weights, the same in dev/tools/navmesh/grid.py: swimming at the
-- game's swim speed against running; off the road costs what the road does.
local SWIM_WEIGHT = 7.0 / 4.72
local OFF_ROAD_WEIGHT = 1.0
-- Staying on roads (Nav.SetRoads): a road up to this many times longer than
-- the way off it is still the way; the data carries tile costs for it.
local OFF_ROAD_STRICT = 3.0
local DIAG = 1.41421356
local LINE_CELLS = 8    -- a drawn walk's longest straight step (32 yd), kept cheap to check
local RELAX_YARDS, RELAX_TRIES = 40, 48   -- how far a bend at a tile's edge may move, how many points it tries
local function CandLess(a, b) return a[1] < b[1] end
local offRoad, roadsOnly = OFF_ROAD_WEIGHT, false
-- Ground to go around (Nav.SetDanger): a yard there costs its weight to
-- choose, its time the same. { [continent] = { [danger cell] = weight } }
local dangerSet
local quartersOf = {}      -- per cells a side: each row's quarter of the tile
-- The highest drop walks take, in yards: nil the safe height each
-- continent's data was built with, else a character's own (Nav.SetDropLimit),
-- math.huge for one who lands safely from any height.
local dropLimit
-- The settings walks come out under, as one number: the danger set's
-- id, the roads switch and the drop limit. The same settings give the same
-- epoch again, so ways kept under it hold good once a trial under others
-- is over.
local dangerIds = setmetatable({}, { __mode = "k" })
local dangerIdNext = 1
local function Epoch()
    local id = 0
    if dangerSet then
        id = dangerIds[dangerSet]
        if not id then
            id, dangerIdNext = dangerIdNext, dangerIdNext + 1
            dangerIds[dangerSet] = id
        end
    end
    local level = dropLimit == nil and 0 or (dropLimit == mhuge and 2 or 1)
    return (id * 2 + (roadsOnly and 1 or 0)) * 3 + level
end
Nav.epoch = 0

-- Inside GPS's planner (yieldCo, the plan's coroutine, while it runs the
-- route engine; sliceEnd, this frame's budget) the searches give the frame
-- back once the budget is spent. Anywhere else they run straight through.
local corunning, coyield = coroutine.running, coroutine.yield
local function Pause()
    local co = Nav.yieldCo
    if co and Nav.sliceEnd and corunning() == co and debugprofilestop() > Nav.sliceEnd then coyield() end
end
Nav.Pause = Pause

-- Unpacking -----------------------------------------------------------------

local function Unpack(s)
    local E = C_EncodingUtil
    local method = Enum and Enum.CompressionMethod and Enum.CompressionMethod.Deflate or 0
    return E.DecompressString(E.DecodeBase64(s), method)
end

-- What every walk reads first ships read in place (dev/tools/navmesh/
-- layout.py): base 40, lowest digit first, over the printable bytes that
-- are no letter, quote or backslash.
local D40 = {}
do
    local d = 0
    for b = 33, 126 do
        if b ~= 34 and b ~= 92 and not (b >= 65 and b <= 90) and not (b >= 97 and b <= 122) then
            D40[b], d = d, d + 1
        end
    end
end

-- Entrance side node (side 1 of entrance e is node 2e - 1, side 2 node 2e)
-- as one number: its tile key, cell and floor packed.
local function SideV(sides, node)
    local p = node * 9 - 8
    local k1, k2, k3, c1, c2, c3, f1, f2, f3 = sbyte(sides, p, p + 8)
    return (D40[k1] + D40[k2] * 40 + D40[k3] * 1600) * 4294967296
        + (D40[c1] + D40[c2] * 40 + D40[c3] * 1600) * 131072 + D40[f1] + D40[f2] * 40 + D40[f3] * 1600
end

-- The ground entrance side node lies on (dev/tools/navmesh/ground.py): no
-- walk joins two grounds.
local function GroundOf(grounds, node)
    local p = node + node % 2 - 1
    local a, b = sbyte(grounds, p, p + 1)
    return D40[a] + D40[b] * 40
end

local function Reader(s, at)
    local pos = at or 1
    local function u()
        local v, mul = 0, 1
        while true do
            local b = sbyte(s, pos)
            pos = pos + 1
            if b < 128 then return v + b * mul end
            v = v + (b - 128) * mul
            mul = mul * 128
        end
    end
    local function i()
        local v = u()
        if v % 2 == 1 then return -(v + 1) / 2 end
        return v / 2
    end
    return u, i
end

local worlds = {}
Nav._worlds = worlds   -- dev tools

local function World(ci)
    local w = worlds[ci]
    if w then return w end
    local data = ns.GPSNavData and ns.GPSNavData[ci]
    if not data then return nil end
    w = { ci = ci, data = data, N = data.cells, cell = data.cell, tiles = {}, order = {}, costs = {},
          reach = {}, reachN = 0, walks = {}, walksN = 0, marks = {}, marksN = 0, danger = {}, shelf = {} }
    worlds[ci] = w
    return w
end

-- Tile key of a world point, and the tile's south-east corner.
local function TileOf(x, y)
    local tx, ty = mfloor((ORIGIN - y) / TILE), mfloor((ORIGIN - x) / TILE)
    return tx * 64 + ty, ORIGIN - ty * TILE - TILE, ORIGIN - tx * TILE - TILE
end
Nav.TileOf = TileOf

-- Bytes from..to of s appended to out from index at: read in runs, not one
-- call a byte.
local RUN = 4000
local function Bytes(s, from, to, out, at)
    local i = from
    while i <= to do
        local j = mmin(to, i + RUN - 1)
        local run = { sbyte(s, i, j) }
        for k = 1, j - i + 1 do out[at + k - 1] = run[k] end
        at = at + (j - i + 1)
        i = j + 1
    end
    return out
end

local BIT = { [0] = 1, 2, 4, 8, 16, 32, 64, 128 }

-- Bytes 1..n of buf onto parts as strings, a few thousand to a call.
local function Chars(buf, n, parts)
    for s = 1, n, RUN do parts[#parts + 1] = schar(unpack(buf, s, mmin(n, s + RUN - 1))) end
end

-- The number at two-byte index i (from 1) of s.
local function U16(s, i)
    local hi, lo = sbyte(s, 2 * i - 1, 2 * i)
    return hi * 256 + lo
end

-- A decoded tile holds strings, a twentieth of what tables did: cf per
-- cell (from 0) its first floor's index, one past the last cell closing
-- the list, and fc per floor its cell, two bytes each; fb per floor a
-- byte: bit 0 swimming, 1 the cell's road, 2-4 the west link, 5-7 the
-- north link; fl the floors' bytes as baked, bit 1 indoors.
local DECODE_RUN = 1000   -- cells a pass reads at once: their floors stay under 4000

local function DecodeTile(w, key)
    local data = w.data
    local s = data.tiles[key]
    if not s then return nil end
    local raw = Unpack(s)
    local N = w.N
    local NN = N * N
    -- The floors counted first: the road bits come after them.
    local f = 0
    for i = 1, NN, RUN do
        local run = { sbyte(raw, i, mmin(NN, i + RUN - 1)) }
        for k = 1, #run do f = f + run[k] end
    end
    -- Road cells: a bit each after the floors, low bit first.
    local road = Bytes(raw, NN + f + 1, NN + f + mfloor((NN + 7) / 8), {}, 0)
    -- Each pass's bytes go to its own buffers and out as strings at its
    -- end: a decode paused in the planner may be overtaken by another.
    local cfBuf, fcBuf, fbBuf, cfParts, fcParts, fbParts = {}, {}, {}, {}, {}, {}
    local g, c = 0, 0
    while c < NN do
        local counts = { sbyte(raw, c + 1, mmin(NN, c + DECODE_RUN)) }
        local sum = 0
        for k = 1, #counts do sum = sum + counts[k] end
        local bytes = { sbyte(raw, NN + g + 1, NN + g + sum) }
        local cn, fn, bn = 0, 0, 0
        for k = 1, #counts do
            local first = g + bn + 1
            cfBuf[cn + 1], cfBuf[cn + 2] = mfloor(first / 256), first % 256
            cn = cn + 2
            local hi, lo = mfloor(c / 256), c % 256
            local rb = road[mfloor(c / 8)]
            local onRoad = (rb and mfloor(rb / BIT[c % 8]) % 2 == 1) and 2 or 0
            for _ = 1, counts[k] do
                bn = bn + 1
                local v = bytes[bn]
                fbBuf[bn] = v - (v % 4 >= 2 and 2 or 0) + onRoad
                fcBuf[fn + 1], fcBuf[fn + 2] = hi, lo
                fn = fn + 2
            end
            c = c + 1
        end
        g = g + bn
        Chars(cfBuf, cn, cfParts)
        Chars(fcBuf, fn, fcParts)
        Chars(fbBuf, bn, fbParts)
        Pause()
    end
    cfParts[#cfParts + 1] = schar(mfloor((f + 1) / 256), (f + 1) % 256)
    local cf, fc = tconcat(cfParts), tconcat(fcParts)
    -- Drops after the road bits, one way off a ledge: drop[g] the floors g
    -- drops to, each with its height in yards after it; dropIn[o] the
    -- floors that drop onto o the same way. nil in a tile without one.
    local drop, dropIn
    local at = NN + f + mfloor((NN + 7) / 8) + 1
    if at <= #raw then
        local u = Reader(raw, at)
        local n = u()
        if n > 0 then
            drop, dropIn = {}, {}
            local step = { [0] = -1, [1] = N, [2] = 1, [3] = -N }   -- east, north, west, south
            for _ = 1, n do
                local from, d, k, h = u(), u(), u(), u() / 2
                local o = U16(cf, U16(fc, from) + step[d] + 1) + k - 1
                local list = drop[from] or {}
                drop[from] = list
                list[#list + 1], list[#list + 2] = o, h
                local into = dropIn[o] or {}
                dropIn[o] = into
                into[#into + 1], into[#into + 2] = from, h
            end
        end
    end
    local tx, ty = mfloor(key / 64), key % 64
    return { key = key, tx = tx, ty = ty, N = N, NN = NN, nf = f, cf = cf, fc = fc,
             fb = tconcat(fbParts), fl = raw:sub(NN + 1, NN + f), sx = ORIGIN - ty * TILE - TILE, sy = ORIGIN - tx * TILE - TILE,
             drop = drop, dropIn = dropIn }
end

-- By a floor's byte: its west link, its north link, its swimming factor
-- and what a yard on it costs to choose; table reads, no arithmetic, in
-- the searches.
local WC, NC, SW, WT = {}, {}, {}, {}
for v = 0, 255 do
    WC[v], NC[v] = mfloor(v / 4) % 8, mfloor(v / 32) % 8
    SW[v] = v % 2 == 1 and SWIM_WEIGHT or 1
end
local function Reweigh()
    for v = 0, 255 do WT[v] = SW[v] * (v % 4 >= 2 and 1 or offRoad) end
end
Reweigh()

-- The floor west (north) of g inside its tile, or nil.
local function WestOf(t, g)
    local k = WC[sbyte(t.fb, g)]
    if k == 0 then return nil end
    local c, N = U16(t.fc, g), t.N
    if c % N == N - 1 then return nil end
    return U16(t.cf, c + 2) + k - 1
end
local function NorthOf(t, g)
    local k = NC[sbyte(t.fb, g)]
    if k == 0 then return nil end
    local c, N = U16(t.fc, g), t.N
    if c >= t.NN - N then return nil end
    return U16(t.cf, c + N + 1) + k - 1
end

-- The floor east (south) of g inside its tile: the first in the cell
-- before (a row before) whose west (north) link is g's rank in its cell.
local function East(t, g)
    local c = U16(t.fc, g)
    if c % t.N == 0 then return nil end
    local cf, fb = t.cf, t.fb
    local first = U16(cf, c + 1)
    local rank = g - first + 1
    for o = U16(cf, c), first - 1 do
        if WC[sbyte(fb, o)] == rank then return o end
    end
    return nil
end
local function South(t, g)
    local c, N = U16(t.fc, g), t.N
    if c < N then return nil end
    local cf, fb = t.cf, t.fb
    local rank = g - U16(cf, c + 1) + 1
    for o = U16(cf, c - N + 1), U16(cf, c - N + 2) - 1 do
        if NC[sbyte(fb, o)] == rank then return o end
    end
    return nil
end

local function Tile(w, key)
    local t = w.tiles[key]
    if t then
        t.at = GetTime()
        return t
    end
    t = DecodeTile(w, key)
    if not t then return nil end
    -- A decode paused in the planner and overtaken by the same tile's on
    -- the main thread keeps that one, or the key sat in order twice and
    -- the next Release read a tile the first pass had dropped.
    local kept = w.tiles[key]
    if kept then
        kept.at = GetTime()
        return kept
    end
    t.at = GetTime()
    w.tiles[key] = t
    local order = w.order
    order[#order + 1] = key
    if #order > TILES_KEPT then
        local old = tremove(order, 1)
        w.tiles[old] = nil
    end
    return t
end

-- World point of floor g's cell.
local function FloorXY(w, t, g)
    local hi, lo = sbyte(t.fc, 2 * g - 1, 2 * g)
    local c = hi * 256 + lo
    local N, cell = w.N, w.cell
    return t.sx + (mfloor(c / N) + 0.5) * cell, t.sy + (c % N + 0.5) * cell
end

local function Rank(t, g) return g - U16(t.cf, U16(t.fc, g) + 1) + 1 end

-- The floor one step from (t, g) in direction d (0 east, 1 north, 2 west,
-- 3 south), maybe in the next tile: tile, floor, or nil.
local function Step(w, t, g, d)
    local N = w.N
    local c = U16(t.fc, g)
    local r, col = mfloor(c / N), c % N
    if d == 2 then
        if col < N - 1 then local o = WestOf(t, g) return o and t, o end
        local k = WC[sbyte(t.fb, g)]
        if k == 0 then return nil end
        local u = Tile(w, t.key - 64)
        if not u then return nil end
        local first = U16(u.cf, r * N + 1)
        if k > U16(u.cf, r * N + 2) - first then return nil end
        return u, first + k - 1
    elseif d == 1 then
        if r < N - 1 then local o = NorthOf(t, g) return o and t, o end
        local k = NC[sbyte(t.fb, g)]
        if k == 0 then return nil end
        local u = Tile(w, t.key - 1)
        if not u then return nil end
        local first = U16(u.cf, col + 1)
        if k > U16(u.cf, col + 2) - first then return nil end
        return u, first + k - 1
    elseif d == 0 then
        if col > 0 then local o = East(t, g) return o and t, o end
        local u = Tile(w, t.key + 64)
        if not u then return nil end
        local cc = r * N + N - 1
        local rank = Rank(t, g)
        for o = U16(u.cf, cc + 1), U16(u.cf, cc + 2) - 1 do
            if WC[sbyte(u.fb, o)] == rank then return u, o end
        end
    else
        if r > 0 then local o = South(t, g) return o and t, o end
        local u = Tile(w, t.key + 1)
        if not u then return nil end
        local cc = (N - 1) * N + col
        local rank = Rank(t, g)
        for o = U16(u.cf, cc + 1), U16(u.cf, cc + 2) - 1 do
            if NC[sbyte(u.fb, o)] == rank then return u, o end
        end
    end
    return nil
end

-- A tile's danger weights by quarter (x quarter * 4 + y quarter + 1, from
-- its low corner), the danger map's cells; nil where it has none.
local function TileDanger(w, key)
    local set = dangerSet and dangerSet[w.ci]
    if not set then return nil end
    local dw = w.danger[key]
    if dw == nil then
        local tx, ty = mfloor(key / 64), key % 64
        dw = false
        for qx = 0, 3 do
            for qy = 0, 3 do
                local weight = set[(tx * 4 + 3 - qy) * 256 + ty * 4 + 3 - qx]
                if weight then
                    dw = dw or { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }
                    dw[qx * 4 + qy + 1] = weight
                end
            end
        end
        w.danger[key] = dw
    end
    return dw or nil
end

-- The mean of a tile's danger weights along a line, its ends in quarters
-- (0 to 4 a side): each quarter's weight by the line's share inside it.
local function LineWeight(dw, ax, ay, bx, by)
    local cx, cy = mmin(3, mmax(0, mfloor(ax))), mmin(3, mmax(0, mfloor(ay)))
    local ex, ey = mmin(3, mmax(0, mfloor(bx))), mmin(3, mmax(0, mfloor(by)))
    if cx == ex and cy == ey then return dw[cx * 4 + cy + 1] end
    local dx, dy = bx - ax, by - ay
    local stepX, stepY = ex > cx and 1 or -1, ey > cy and 1 or -1
    -- Where the line leaves its quarter by x and by y (2: never).
    local nextX = cx ~= ex and (cx + (stepX > 0 and 1 or 0) - ax) / dx or 2
    local nextY = cy ~= ey and (cy + (stepY > 0 and 1 or 0) - ay) / dy or 2
    local at, sum = 0, 0
    while cx ~= ex or cy ~= ey do
        local weight = dw[cx * 4 + cy + 1]
        if nextX < nextY then
            sum, at, cx = sum + (nextX - at) * weight, nextX, cx + stepX
            nextX = cx ~= ex and nextX + stepX / dx or 2
        else
            sum, at, cy = sum + (nextY - at) * weight, nextY, cy + stepY
            nextY = cy ~= ey and nextY + stepY / dy or 2
        end
    end
    return sum + (1 - at) * dw[cx * 4 + cy + 1]
end
Nav._lineWeight = LineWeight

-- Each row's (and column's) quarter of a tile N cells a side.
local function Quarters(N)
    local q = quartersOf[N]
    if not q then
        q = {}
        for i = 0, N - 1 do q[i] = mfloor((i + 0.5) * 4 / N) end
        quartersOf[N] = q
    end
    return q
end

-- Floor g's danger weight in tile t (dw its weights, q its quarters).
local function FloorDanger(t, dw, q, N, g)
    local hi, lo = sbyte(t.fc, 2 * g - 1, 2 * g)
    local c = hi * 256 + lo
    return dw[q[mfloor(c / N)] * 4 + q[c % N] + 1]
end

-- Floor g's danger weight in tile t, 1 where the tile has none.
local function DangerAt(w, t, g)
    local dw = TileDanger(w, t.key)
    return dw and FloorDanger(t, dw, Quarters(w.N), w.N, g) or 1
end

-- Walks come out differently from now on: the ones kept are dropped, and
-- the tiles, which carry their floors' weights.
local function Reset()
    Nav.epoch = Epoch()
    for _, w in pairs(worlds) do
        w.walks, w.walksN, w.reach, w.reachN, w.costs = {}, 0, {}, 0, {}
        w.tiles, w.order, w.marks, w.marksN, w.danger, w.shelf = {}, {}, {}, 0, {}, {}
    end
end

-- The ground walks go around, { [continent] = { [danger cell] = weight } },
-- or nil for none.
function Nav.SetDanger(set)
    if set == dangerSet then return end
    dangerSet = set
    Reset()
end

-- Whether walks keep to roads.
function Nav.SetRoads(on)
    on = on and true or false
    if on == roadsOnly then return end
    roadsOnly = on
    offRoad = on and OFF_ROAD_STRICT or OFF_ROAD_WEIGHT
    Reweigh()
    Reset()
end

-- The highest drop walks may take, in yards (math.huge: any); nil goes
-- back to the safe height each continent's data was built with. The
-- tiles hold every drop with its height. What was found under the old
-- limit is shelved until it comes back: every route is followed by
-- trials under other limits (no jumps, a parachute).
function Nav.SetDropLimit(yards)
    if yards == dropLimit then return end
    local old, new = dropLimit or false, yards or false
    dropLimit = yards
    Nav.epoch = Epoch()
    for _, w in pairs(worlds) do
        w.shelf[old] = { w.walks, w.walksN, w.reach, w.reachN, w.costs, w.marks, w.marksN }
        local set = w.shelf[new] or { {}, 0, {}, 0, {}, {}, 0 }
        w.shelf[new] = nil
        w.walks, w.walksN, w.reach, w.reachN, w.costs, w.marks, w.marksN =
            set[1], set[2], set[3], set[4], set[5], set[6], set[7]
    end
end

local function Limit(w) return dropLimit or w.data.safe or 0 end

-- The heights continent ci's data knows: safe (costs nothing) and survive
-- (the most a full-health character lives through), or nil without drops.
function Nav.DropHeights(ci)
    local data = ns.GPSNavData and ns.GPSNavData[ci]
    if not (data and data.safe and data.safe > 0) then return nil end
    return data.safe, (data.survive and data.survive > 0) and data.survive or nil
end

-- Whether continent ci's data can keep walks to roads.
function Nav.HasRoads(ci)
    local data = ns.GPSNavData and ns.GPSNavData[ci]
    return data ~= nil and data.roads ~= nil
end

-- The most a walk's cost (the yards it is chosen by) exceeds its time by,
-- as a factor: off the road every yard weighs this much more.
function Nav.CostOverTime() return offRoad end

-- A drawn way is pulled straight along what the player sees and walks;
-- the cells it was found through zigzag about this much longer (measured
-- over twelve trips on both continents).
local PULLED = 0.955

-- The floor under (x, y): where a city's floors stack, the one Floors
-- wants (the player's named one, a spawn's height); else indoors an
-- indoor one (a journey's end of unknown height: a cave under its hill),
-- else one outdoors, then ground over water (one stands on the ground
-- beside a swim), else the highest; off the grid the nearest within
-- SNAP_CELLS (or snap).
local function Locate(w, x, y, indoors, snap)
    local key, sx, sy = TileOf(x, y)
    local t = Tile(w, key)
    if not t then return nil end
    local N, cell = w.N, w.cell
    local r0, c0 = mfloor((x - sx) / cell), mfloor((y - sy) / cell)
    local want = Floors and Floors.Want(w.ci, x, y)
    if want and want.inside then indoors = true end
    for ring = 0, snap or SNAP_CELLS do
        local best, bestScore
        for r = r0 - ring, r0 + ring do
            for c = c0 - ring, c0 + ring do
                if (mabs(r - r0) == ring or mabs(c - c0) == ring) and r >= 0 and c >= 0 and r < N and c < N then
                    local cc = r * N + c
                    local first = U16(t.cf, cc + 1)
                    for g = first, U16(t.cf, cc + 2) - 1 do
                        local inside = sbyte(t.fl, g) % 4 >= 2
                        local score = ((indoors and inside) or (not indoors and not inside)) and 100 or 0
                        if sbyte(t.fb, g) % 2 == 0 then score = score + 50 end
                        score = score + (g - first) - ring * 1000
                        if want then score = score + Floors.Score(w.ci, key, cc, g - first, want) end
                        if not bestScore or score > bestScore then best, bestScore = g, score end
                    end
                end
            end
        end
        if best then return t, best end
    end
    return t, nil
end

-- Searching -------------------------------------------------------------------

local Heap = {}
Heap.__index = Heap
local function NewHeap() return setmetatable({ k = {}, v = {}, n = 0 }, Heap) end
function Heap:Push(cost, id)
    local n = self.n + 1
    self.n = n
    local k, v = self.k, self.v
    while n > 1 do
        local parent = mfloor(n / 2)
        if k[parent] <= cost then break end
        k[n], v[n] = k[parent], v[parent]
        n = parent
    end
    k[n], v[n] = cost, id
end
function Heap:Pop()
    local n = self.n
    if n == 0 then return nil end
    local k, v = self.k, self.v
    local topK, topV = k[1], v[1]
    local lastK, lastV = k[n], v[n]
    k[n], v[n] = nil, nil
    n = n - 1
    self.n = n
    local i = 1
    while true do
        local c = i * 2
        if c > n then break end
        if c < n and k[c + 1] < k[c] then c = c + 1 end
        if k[c] >= lastK then break end
        k[i], v[i] = k[c], v[c]
        i = c
    end
    if n > 0 then k[i], v[i] = lastK, lastV end
    return topV, topK
end

-- Straight and diagonal neighbours of g inside its tile: diagonals only
-- where both ways round the corner are open; the drops off it no higher
-- than limit, or with rev the drops onto it (a search from the end back).
local nbScratch, nbLen = {}, {}
local Clear   -- defined with the drawing below
local function TileNeighbours(t, g, bg, rev, limit)
    local cf, fb, N, NN = t.cf, t.fb, t.N, t.NN
    local h, l = sbyte(t.fc, 2 * g - 1, 2 * g)
    local c = h * 256 + l
    -- First floors of the cells around, three to a read: east, this and
    -- west (c - 1 to c + 1), and the same in the rows north and south.
    local eF, cF, wF, neF, nF, nwF, seF, sF, swF
    if c > 0 then
        local a, b, d, e, x, y = sbyte(cf, 2 * c - 1, 2 * c + 4)
        eF, cF, wF = a * 256 + b, d * 256 + e, x * 256 + y
    else
        local d, e, x, y = sbyte(cf, 1, 4)
        cF, wF = d * 256 + e, x * 256 + y
    end
    if c < NN - N then
        local a, b, d, e, x, y = sbyte(cf, 2 * (c + N) - 1, 2 * (c + N) + 4)
        neF, nF, nwF = a * 256 + b, d * 256 + e, x * 256 + y
    end
    if c > N then
        local a, b, d, e, x, y = sbyte(cf, 2 * (c - N) - 1, 2 * (c - N) + 4)
        seF, sF, swF = a * 256 + b, d * 256 + e, x * 256 + y
    elseif c == N then
        local d, e, x, y = sbyte(cf, 1, 4)
        sF, swF = d * 256 + e, x * 256 + y
    end
    local w0, n0
    local k = WC[bg]
    if k > 0 and c % N < N - 1 then w0 = wF + k - 1 end
    k = NC[bg]
    if k > 0 and nF then n0 = nF + k - 1 end
    local n = 0
    if w0 then n = n + 1; nbScratch[n], nbLen[n] = w0, 1 end
    if n0 then n = n + 1; nbScratch[n], nbLen[n] = n0, 1 end
    -- East and south: every floor in the cell before (a row before) whose
    -- west (north) link is g's rank in its cell; the first of each for the
    -- diagonals.
    local rank = g - cF + 1
    local e0, s0
    if c % N > 0 then
        for o = eF, cF - 1 do
            if WC[sbyte(fb, o)] == rank then n = n + 1; nbScratch[n], nbLen[n] = o, 1; e0 = e0 or o end
        end
    end
    if sF then
        for o = sF, swF - 1 do
            if NC[sbyte(fb, o)] == rank then n = n + 1; nbScratch[n], nbLen[n] = o, 1; s0 = s0 or o end
        end
    end
    -- Diagonals, by the links' ranks: the corner cell's floor is the one
    -- both ways round reach, and the straight ways found above keep the
    -- edge checks already made.
    if n0 and w0 then
        local kd = WC[sbyte(fb, n0)]
        if kd > 0 and NC[sbyte(fb, w0)] == kd then n = n + 1; nbScratch[n], nbLen[n] = nwF + kd - 1, DIAG end
    end
    if n0 and e0 then
        local kd = NC[sbyte(fb, e0)]
        if kd > 0 then
            local x = neF + kd - 1
            if WC[sbyte(fb, x)] == n0 - nF + 1 then n = n + 1; nbScratch[n], nbLen[n] = x, DIAG end
        end
    end
    if s0 and w0 then
        local kd = WC[sbyte(fb, s0)]
        if kd > 0 then
            local x = swF + kd - 1
            if NC[sbyte(fb, x)] == w0 - wF + 1 then n = n + 1; nbScratch[n], nbLen[n] = x, DIAG end
        end
    end
    if s0 and e0 then
        local rs, re = s0 - sF + 1, e0 - eF + 1
        for x = seF, sF - 1 do
            local bx = sbyte(fb, x)
            if WC[bx] == rs and NC[bx] == re then n = n + 1; nbScratch[n], nbLen[n] = x, DIAG break end
        end
    end
    local drops = t.drop and (rev and t.dropIn or t.drop)[g]
    if drops then
        for d = 1, #drops, 2 do
            if drops[d + 1] <= limit then n = n + 1; nbScratch[n], nbLen[n] = drops[d], 1 end
        end
    end
    return n
end

-- Reused search tables, no garbage: one set inside the planner, one outside
local function NewScratch()
    return { prev = {}, closed = {}, cost = {}, time = {}, buckets = {}, lists = {}, heap = NewHeap(),
             line = {}, via = {}, viaCost = {}, viaTime = {} }
end
local scratchMain, scratchPlan = NewScratch(), NewScratch()
-- A wiped table keeps its grown size; fresh ones let it go.
function Nav.FreshScratch() scratchMain, scratchPlan = NewScratch(), NewScratch() end
-- One tile's cost, prev and time per floor from g0 (a floor or seed costs).
-- goal: A* to it; want: cell-wide buckets until `left` of them are reached.
-- keep: fresh tables for the caller; rev: costs to reach g0; any: lines.
local function TileSearch(w, t, g0, goal, want, left, keep, rev, any)
    local s = (Nav.yieldCo and corunning() == Nav.yieldCo) and scratchPlan or scratchMain
    local limit = Limit(w)
    local prev, closed = s.prev, s.closed
    wipe(prev)
    wipe(closed)
    local cost, time
    if keep then
        cost, time = {}, {}
    else
        cost, time = s.cost, s.time
        wipe(cost)
        wipe(time)
    end
    local cell = w.cell / 2
    local half = w.cell / 2
    local N = w.N
    local dw = TileDanger(w, t.key)
    local q = dw and Quarters(N)
    local fb = t.fb
    local pops = 0
    if goal then
        local heap = s.heap
        wipe(heap.k)
        wipe(heap.v)
        heap.n = 0
        if type(g0) == "table" then
            for g, c in pairs(g0) do
                cost[g], time[g] = c, c
                heap:Push(c, g)
            end
        else
            cost[g0], time[g0] = 0, 0
            heap:Push(0, g0)
        end
        local gx, gy = FloorXY(w, t, goal)
        -- Lazy Theta*, for drawing only: eight-way steps price every staircase
        -- alike, so a hill was gone round on its longer side.
        local line, via, viaCost, viaTime = s.line, s.via, s.viaCost, s.viaTime
        if any then
            wipe(line)
            wipe(via)
            wipe(viaCost)
            wipe(viaTime)
        end
        while true do
            -- At the loop's top: nbScratch is refilled after, so a search run
            -- while this one waits cannot spoil it.
            pops = pops + 1
            if pops % 64 == 0 then Pause() end
            local g = heap:Pop()
            if not g then break end
            if not closed[g] then
                closed[g] = true
                if any and line[g] then
                    if not Clear(w, t, prev[g], g) then
                        cost[g], prev[g], time[g] = viaCost[g], via[g], viaTime[g]
                    end
                    line[g] = nil
                end
                if g == goal then break end
                local base, bg, tbase = cost[g], sbyte(fb, g), time[g]
                local sg = SW[bg]
                local wg = WT[bg] * (dw and FloorDanger(t, dw, q, N, g) or 1)
                local p = any and prev[g]
                local bp, px, py, wp
                if p then
                    bp = sbyte(fb, p)
                    px, py = FloorXY(w, t, p)
                    wp = WT[bp] * (dw and FloorDanger(t, dw, q, N, p) or 1)
                end
                local n = TileNeighbours(t, g, bg, rev, limit)
                for k = 1, n do
                    local o = nbScratch[k]
                    if not closed[o] then
                        local bo = sbyte(fb, o)
                        local so = SW[bo]
                        local wo = WT[bo] * (dw and FloorDanger(t, dw, q, N, o) or 1)
                        local nc = base + nbLen[k] * cell * (wg + wo)
                        local nt = tbase + nbLen[k] * half * (sg + so)
                        local ox, oy = FloorXY(w, t, o)
                        local lc, lt
                        if p and wp == wo and SW[bp] == so then
                            local d = msqrt((px - ox) ^ 2 + (py - oy) ^ 2) / w.cell
                            if d <= LINE_CELLS then
                                lc = cost[p] + d * cell * (wp + wo)
                                if lc < nc then lt = time[p] + d * half * (SW[bp] + so) else lc = nil end
                            end
                        end
                        local c = lc or nc
                        if not cost[o] or c < cost[o] then
                            if lc then
                                cost[o], prev[o], time[o], line[o] = lc, p, lt, true
                                via[o], viaCost[o], viaTime[o] = g, nc, nt
                            else
                                cost[o], prev[o], time[o] = nc, g, nt
                                if any then line[o] = nil end
                            end
                            heap:Push(c + msqrt((gx - ox) ^ 2 + (gy - oy) ^ 2), o)
                        end
                    end
                end
            end
        end
        return cost, prev, time
    end
    local width = w.cell
    local buckets, lists, lo, hi = s.buckets, s.lists, mhuge, 0
    -- Lists a search ended early left in the buckets go back to the pool.
    for bk, list in pairs(buckets) do
        wipe(list)
        lists[#lists + 1] = list
        buckets[bk] = nil
    end
    local function Put(g, c)
        local b = mfloor(c / width)
        local list = buckets[b]
        if not list then
            list = lists[#lists]
            if list then lists[#lists] = nil else list = {} end
            buckets[b] = list
        end
        list[#list + 1] = g
        if b < lo then lo = b end
        if b > hi then hi = b end
    end
    if type(g0) == "table" then
        for g, c in pairs(g0) do
            cost[g], time[g] = c, c
            Put(g, c)
        end
    else
        cost[g0], time[g0] = 0, 0
        Put(g0, 0)
    end
    local b = lo
    while b <= hi do
        local list = buckets[b]
        local i = 1
        while list and i <= #list do
            local g = list[i]
            i = i + 1
            pops = pops + 1
            if pops % 64 == 0 then Pause() end
            if not closed[g] then
                closed[g] = true
                if want and want[g] then
                    left = left - 1
                    if left == 0 then return cost, prev, time end
                end
                local base, bg, tbase = cost[g], sbyte(fb, g), time[g]
                local sg = SW[bg]
                local wg = WT[bg] * (dw and FloorDanger(t, dw, q, N, g) or 1)
                local n = TileNeighbours(t, g, bg, rev, limit)
                for k = 1, n do
                    local o = nbScratch[k]
                    if not closed[o] then
                        local bo = sbyte(fb, o)
                        local so = SW[bo]
                        local nc = base + nbLen[k] * cell * (wg + WT[bo] * (dw and FloorDanger(t, dw, q, N, o) or 1))
                        if not cost[o] or nc < cost[o] then
                            cost[o], prev[o] = nc, g
                            time[o] = tbase + nbLen[k] * half * (sg + so)
                            Put(o, nc)
                        end
                    end
                end
            end
        end
        if list then
            wipe(list)
            lists[#lists + 1] = list
            buckets[b] = nil
        end
        b = b + 1
    end
    return cost, prev, time
end

local function SideKey(v) return mfloor(v / 4294967296) end
local function SideFloor(v) return v % 131072 end
-- World point of a side's cell.
local function SideXY(w, v)
    local key, c = mfloor(v / 4294967296), mfloor(v / 131072) % 32768
    local tx, ty = mfloor(key / 64), key % 64
    local N, cell = w.N, w.cell
    return ORIGIN - ty * TILE - TILE + (mfloor(c / N) + 0.5) * cell, ORIGIN - tx * TILE - TILE + (c % N + 0.5) * cell
end

-- Stamped with the walk that read them last, so Release lets a tile's
-- go on its own once idle (a route's re-found walks keep the continent
-- in use, and a plan reads hundreds of tiles' costs).
local function TileCosts(w, key)
    local tc = w.costs[key]
    if tc ~= nil then
        if tc then tc.used = w.used or tc.used end
        return tc or nil
    end
    local data = w.data
    local s, scale = data.costs[key], 1
    -- No road table: no road in the tile, its costs at the strict weight.
    if roadsOnly and data.roads then
        if data.roads[key] then s = data.roads[key] else scale = OFF_ROAD_STRICT / OFF_ROAD_WEIGHT end
    end
    if not s then w.costs[key] = false return nil end
    local u, i = Reader(Unpack(s))
    local n = u()
    local sides = data.sides
    local side, at, last = {}, {}, 0
    for k = 1, n do
        last = last + i()
        -- The entrance's side in this tile (ids count from 0 in the data).
        local node = (SideKey(SideV(sides, 2 * last + 1)) == key) and (2 * last + 1) or (2 * last + 2)
        side[k], at[node] = node, k
    end
    local sx, sy = {}, {}
    for k = 1, n do sx[k], sy[k] = SideXY(w, SideV(sides, side[k])) end
    -- Danger: a pair's cost at the mean weight along its line.
    local dw = TileDanger(w, key)
    local qx0, qy0, flat
    if dw then
        local tx, ty = mfloor(key / 64), key % 64
        qx0, qy0 = ORIGIN - ty * TILE - TILE, ORIGIN - tx * TILE - TILE
        -- One weight all over the tile: every line's mean.
        flat = dw[1]
        for k = 2, 16 do
            if dw[k] ~= flat then flat = nil break end
        end
    end
    local function Along(a, b)
        if not dw then return 1 end
        if flat then return flat end
        return LineWeight(dw, (sx[a] - qx0) * 4 / TILE, (sy[a] - qy0) * 4 / TILE,
            (sx[b] - qx0) * 4 / TILE, (sy[b] - qy0) * 4 / TILE)
    end
    -- Each pair's cost by its index in the upper triangle: the straight
    -- line plus the way around, false where no way joins them; and that
    -- way's time, the cost less what leaving roads added, as 127ths of
    -- the way around. A table flagged one way (a drop in the tile) lists
    -- every ordered pair, kept so (ordered, by PairIndex); so is one a
    -- higher drop limit changes, from its level's entries that differ
    -- (costs only: their time is their cost).
    local oneway = u() == 1
    local limit, level = Limit(w), nil
    if not roadsOnly and limit > (data.safe or 0) then
        if limit == mhuge then
            level = (data.anyDrop and data.anyDrop[key]) or (data.hurt and data.hurt[key])
        elseif (data.survive or 0) > 0 and limit >= data.survive then
            level = data.hurt and data.hurt[key]
        end
    end
    local ordered = oneway or level ~= nil
    local cost, time, made = {}, {}, 0
    -- In a tile with danger a pair is weighed along its line when a search
    -- first reads its cost; most pairs never are (59,609 weighed for one
    -- plan, 2026-11-19). Its cost before the weight and its ends wait.
    local base, ends
    if dw then
        base, ends = {}, {}
        setmetatable(cost, { __index = function(t, p)
            local c = base[p]
            if not c then return nil end
            local e = ends[p]
            c = c * Along(mfloor(e / 4096), e % 4096)
            rawset(t, p, c)
            return c
        end })
    end
    local function Weigh(p, c, a, b)
        if base then base[p], ends[p] = c, a * 4096 + b else cost[p] = c end
    end
    -- A tile's pairs run to thousands: a plan gives the frame back among
    -- them (40 to 56 ms planner frames, 2026-11-19).
    local function Pair(a, b, p, q)
        made = made + 1
        if made % 64 == 0 then Pause() end
        local code = u()
        if code == 0 then
            cost[p] = false
            if q then cost[q] = false end
        else
            local off = u()
            local around = (code - 1) / 2
            local c = msqrt((sx[a] - sx[b]) ^ 2 + (sy[a] - sy[b]) ^ 2) + around
            Weigh(p, c * scale, a, b)
            time[p] = c - off / 127 * around
            if q then
                Weigh(q, c * scale, a, b)
                time[q] = time[p]
            end
        end
    end
    if oneway then
        for a = 1, n do
            for b = 1, n do
                if a ~= b then Pair(a, b, (a - 1) * (n - 1) + (b < a and b or b - 1)) end
            end
        end
    elseif ordered then
        for a = 1, n - 1 do
            for b = a + 1, n do Pair(a, b, (a - 1) * (n - 1) + b - 1, (b - 1) * (n - 1) + a) end
        end
    else
        local p = 0
        for a = 1, n - 1 do
            for b = a + 1, n do
                p = p + 1
                Pair(a, b, p)
            end
        end
    end
    if level then
        local du = Reader(Unpack(level))
        local idx = 0
        for j = 1, du() do
            if j % 64 == 0 then Pause() end
            idx = idx + du()
            local code = du()
            local a = mfloor((idx - 1) / (n - 1)) + 1
            local r = idx - (a - 1) * (n - 1)
            local b = r < a and r or r + 1
            if code == 0 then
                if base then base[idx] = nil end
                cost[idx] = false
            else
                local c = msqrt((sx[a] - sx[b]) ^ 2 + (sy[a] - sy[b]) ^ 2) + (code - 1) / 2
                rawset(cost, idx, nil)
                Weigh(idx, c, a, b)
                time[idx] = c
            end
        end
    end
    tc = { side = side, at = at, n = n, cost = cost, time = time, used = w.used, ordered = ordered }
    w.costs[key] = tc
    return tc
end

-- Where the pair from side i to side j of a tile's table sits.
local function PairIndex(tc, i, j)
    local n = tc.n
    if tc.ordered then return (i - 1) * (n - 1) + (j < i and j or j - 1) end
    if j > i then return (i - 1) * n - (i - 1) * i / 2 - i + j end
    return (j - 1) * n - (j - 1) * j / 2 + (i - j)
end

-- Costs and times from floor g of tile t to each entrance side in that
-- tile, out of a tile search's.
local function EntranceCosts(w, t, cost, time)
    local tc = TileCosts(w, t.key)
    local sides = w.data.sides
    local out, outT = {}, {}
    for k = 1, tc and tc.n or 0 do
        local node = tc.side[k]
        local f = SideFloor(SideV(sides, node))
        local c = cost[f]
        if c then out[node], outT[node] = c, time[f] end
    end
    return out, outT
end

-- A kept end, stamped with the walk that read it last: Release lets it
-- go on its own, as a followed route keeps the continent in use.
local function Reach(w, rk)
    local kept = w.reach[rk]
    if kept then kept.used = w.used or kept.used end
    return kept
end
local function KeepReach(w, rk, kept)
    if w.reachN >= REACH_KEPT then w.reach, w.reachN = {}, 0 end
    kept.used = w.used
    w.reach[rk], w.reachN = kept, w.reachN + 1
    return kept
end

-- Kept per floor, as every walk from one spot asks the same; rev: from
-- each side to g.
local function ToEntrances(w, t, g, rev)
    local rk = (t.key * 131072 + g) * 2 + (rev and 1 or 0)
    local kept = Reach(w, rk)
    if kept then return kept[1], kept[2] end
    local tc, sides = TileCosts(w, t.key), w.data.sides
    local want, left = {}, 0
    for k = 1, tc and tc.n or 0 do
        local f = SideFloor(SideV(sides, tc.side[k]))
        if not want[f] then want[f], left = true, left + 1 end
    end
    local cost, _, time = TileSearch(w, t, g, nil, want, left, nil, rev)
    local out, outT = EntranceCosts(w, t, cost, time)
    KeepReach(w, rk, { out, outT })
    return out, outT
end

-- Costs and times to entrance sides as the data bakes them for fixed
-- spots (dev/tools/navmesh/bake_spots.lua): the sides in order, each a
-- step on from the last, with its cost and its time in sixteenths of a
-- yard.
local function Baked(u)
    local out, outT, node = {}, {}, 0
    for _ = 1, u() do
        node = node + u()
        out[node] = u() / 16
        outT[node] = u() / 16
    end
    return out, outT
end

-- A walk's end at (x, y): its tile key, floor and costs (and times) to
-- that tile's entrance sides (rev: from them), from the baked spots where
-- the point is one (no tile decoded then; spotsIn holds the way in where a
-- drop makes it differ), else searched once and kept, as every walk from
-- one end asks the same.
local function End(w, x, y, indoors, rev)
    local data = w.data
    local k = mfloor(x) .. ":" .. mfloor(y)
    -- A baked spot holds the floor picked without Floors' want.
    local s = not indoors and not (Floors and Floors.Want(w.ci, x, y))
        and ((rev and data.spotsIn and data.spotsIn[k]) or (data.spots and data.spots[k]))
    if s then
        local u = Reader(Unpack(s))
        local key, g = u(), u()
        -- Baked without danger: searched where its tile holds some.
        if not TileDanger(w, key) then
            local rk = (key * 131072 + g) * 2 + (rev and 1 or 0)
            local kept = Reach(w, rk) or KeepReach(w, rk, { Baked(u) })
            return key, g, kept[1], kept[2]
        end
    end
    local t, g = Locate(w, x, y, indoors)
    if not g then return nil end
    local out, outT = ToEntrances(w, t, g, rev)
    return t.key, g, out, outT
end

-- An end that is any floor within r yards of (x, y) (a dock or a landing
-- just off the ground), in every tile that circle touches: the costs from
-- the nearest such floor to each entrance side, and per tile key to every
-- floor of that tile; nil without one. Baked for fixed spots (sides only),
-- taken unless the walk starts in a tile the circle touches (fromKey),
-- where the way inside that tile is needed. rev: the costs into the
-- circle instead (nearIn baked where a drop makes them differ).
local function NearEnd(w, x, y, r, fromKey, rev)
    local nk = mfloor(x) .. ":" .. mfloor(y) .. ":" .. r
    local rk = rev and (nk .. "<") or nk
    local kept = Reach(w, rk)
    if kept then return kept[1], kept[2], kept[3], kept[4] end
    local N, cell = w.N, w.cell
    local data = w.data
    local baked = (rev and data.nearIn and data.nearIn[nk]) or (data.near and data.near[nk])
    if baked and fromKey then
        local touches = false
        for _, cx in ipairs({ x - r, x + r }) do
            for _, cy in ipairs({ y - r, y + r }) do
                local key = TileOf(cx, cy)
                if key == fromKey or TileDanger(w, key) then touches = true end
            end
        end
        -- Not kept: only the full search below serves every walk.
        if not touches then
            local out, outT = Baked(Reader(Unpack(baked)))
            return out, outT, nil, nil
        end
    end
    local out, outT, floors, floorsT
    -- Where floors stack, only those at the level wanted (not the ring
    -- over an auction house).
    local want = Floors and Floors.Want(w.ci, x, y)
    for _, cx in ipairs({ x - r, x + r }) do
        for _, cy in ipairs({ y - r, y + r }) do
            local key, sx, sy = TileOf(cx, cy)
            local t = not (floors and floors[key]) and Tile(w, key)
            local seeds
            for row = mmax(0, mfloor((x - r - sx) / cell)), mmin(N - 1, mfloor((x + r - sx) / cell)) do
                for col = mmax(0, mfloor((y - r - sy) / cell)), mmin(N - 1, mfloor((y + r - sy) / cell)) do
                    local cc = row * N + col
                    local first = t and U16(t.cf, cc + 1) or 1
                    for g = first, t and U16(t.cf, cc + 2) - 1 or 0 do
                        local gx, gy = FloorXY(w, t, g)
                        local d = msqrt((gx - x) ^ 2 + (gy - y) ^ 2)
                        if d <= r and (not want or Floors.OnLevel(w.ci, key, cc, g - first, want)) then
                            seeds = seeds or {}
                            seeds[g] = d
                        end
                    end
                end
            end
            if seeds then
                local cost, _, time = TileSearch(w, t, seeds, nil, nil, nil, true, rev)
                floors, floorsT, out, outT = floors or {}, floorsT or {}, out or {}, outT or {}
                floors[key], floorsT[key] = cost, time
                local ec, et = EntranceCosts(w, t, cost, time)
                for node, c in pairs(ec) do
                    if not out[node] or c < out[node] then out[node], outT[node] = c, et[node] end
                end
            end
        end
    end
    if not out then return nil end
    KeepReach(w, rk, { out, outT, floors, floorsT })
    return out, outT, floors, floorsT
end

local function Other(node) return node % 2 == 1 and node + 1 or node - 1 end

local onGround = {}

-- Landmark distances as refine.py bakes them (data.marks): per landmark a
-- string, whole yards to each entrance (its nearer side), 0 unknown. A walk
-- between two sides is at least the difference of their distances from any
-- one landmark.
local function Mark(s, e)
    local a, b, c = sbyte(s, 3 * e - 2, 3 * e)
    return D40[a] + D40[b] * 40 + D40[c] * 1600
end

-- The cheapest way over the entrance sides from fromA's sides to toB's,
-- each with its cost on to the walk's end at (bx, by), or any floor within
-- circle yards of it. A* under the straight line and, for a point end,
-- the landmark bound to the end's nearest side, which holds since every
-- pair cost is at least the way inside the tile. best: a way in hand
-- inside one tile; limit: given up past this many yards; rev: each pair
-- taken the other way round (a walk searched from its end). The cost, the
-- side it ends at (nil for the way in hand) and the sides before each.
local marksPick = {}
local function Search(w, fromA, toB, bx, by, best, limit, circle, rev)
    -- No side leaves a or reaches b (a pit, a ledge): the way in hand only.
    if next(fromA) == nil or next(toB) == nil then return best end
    local sides = w.data.sides
    local alt = not circle and w.data.marks
    -- The landmarks used: those whose bound between the nearest sides of
    -- the two ends is largest, as they tell the most along the way.
    local used, used0, K = {}, {}, 0
    local e0, fin0
    if alt then
        local es, cs = nil, mhuge
        for node, c in pairs(fromA) do
            if c < cs then es, cs = (node + node % 2) / 2, c end
        end
        fin0 = mhuge
        for node, fin in pairs(toB) do
            if fin < fin0 then e0, fin0 = (node + node % 2) / 2, fin end
        end
        -- Whole yards in the data, the nearer side's, and pair costs
        -- rounded to the half yard: a cell and a yard and a quarter of play.
        fin0 = fin0 + w.cell + 1.25
        local n = 0
        for l = 1, #alt do
            local d0, ds = Mark(alt[l], e0), Mark(alt[l], es)
            if d0 > 0 and ds > 0 then
                n = n + 1
                marksPick[n] = l
                marksPick[-l] = d0 > ds and d0 - ds or ds - d0
            end
        end
        for k = n + 1, #marksPick do marksPick[k] = nil end
        tsort(marksPick, function(a, b) return marksPick[-a] > marksPick[-b] end)
        for k = 1, mmin(n, LANDMARKS_USED) do
            K = K + 1
            used[K] = alt[marksPick[k]]
            used0[K] = Mark(used[K], e0)
        end
    end
    local slack = circle or 0
    local hc = {}   -- each side's bound, once a search
    local function H(node)
        local h = hc[node]
        if h then return h end
        local x, y = SideXY(w, SideV(sides, node))
        h = msqrt((bx - x) ^ 2 + (by - y) ^ 2) - slack
        local e = (node + node % 2) / 2
        for l = 1, K do
            local d0, dv = used0[l], Mark(used[l], e)
            if dv > 0 then
                local diff = (d0 > dv and d0 - dv or dv - d0) - fin0
                if diff > h then h = diff end
            end
        end
        if h < 0 then h = 0 end
        hc[node] = h
        return h
    end
    local g, prev, heap = {}, {}, NewHeap()
    for node, c in pairs(fromA) do
        g[node] = c
        heap:Push(c + H(node), node)
    end
    local reached, cut
    local cell = w.cell
    local pops = 0
    while true do
        -- A pop reads a tile's pairs from its side, each weighed for danger
        -- on its first read (TileCosts), where no pause can come.
        pops = pops + 1
        if pops % 8 == 0 then Pause() end
        local node, f = heap:Pop()
        if not node or f >= best then break end
        if limit and f > limit then
            cut = best == mhuge
            break
        end
        local here = g[node]
        -- The landmark bound's rounding makes it uneven from side to side,
        -- so a side may be reached cheaper after it was taken: the cheaper
        -- way is pushed too, and an entry it outdid is passed over here.
        if f <= here + H(node) + 0.001 then
            local fin = toB[node]
            if fin and here + fin < best then best, reached = here + fin, node end
            -- Across the edge to the entrance's other side, then on inside that tile.
            local o = Other(node)
            local c = here + cell
            if not g[o] or c < g[o] then
                g[o], prev[o] = c, node
                heap:Push(c + H(o), o)
            end
            local key = SideKey(SideV(sides, node))
            local tc = TileCosts(w, key)
            if tc then
                local n, side, cost, ordered = tc.n, tc.side, tc.cost, tc.ordered
                local i = tc.at[node]
                local row = (i - 1) * n - (i - 1) * i / 2 - i
                for j = 1, n do
                    if j ~= i then
                        if ordered then
                            c = cost[rev and PairIndex(tc, j, i) or PairIndex(tc, i, j)]
                        elseif j > i then
                            c = cost[row + j]
                        else
                            c = cost[(j - 1) * n - (j - 1) * j / 2 + (i - j)]
                        end
                        if c then
                            o = side[j]
                            c = here + c
                            if not g[o] or c < g[o] then
                                g[o], prev[o] = c, node
                                heap:Push(c + H(o), o)
                            end
                        end
                    end
                end
            end
        end
    end
    return best, reached, prev, cut
end

local function NearKey(x, y, r) return mfloor(x) .. ":" .. mfloor(y) .. ":" .. r end

-- The walk from a to b: cost (running yards), the entrance sides it passes
-- (pairs: leave a tile, enter the next), both ends' tile key and floor,
-- and its time (yards walked, swimming slower): the ends' ways, each
-- pair's along the chain, a cell per crossing. opts.reverse prices the
-- walk from b to a, searched from a (a drop goes one way).
local function Walk(w, ax, ay, bx, by, opts)
    local rev = opts and opts.reverse or nil
    local keyA, ga, fromA, fromAT = End(w, ax, ay, opts and opts.indoorsA, rev)
    if not ga then return nil end
    local near = opts and opts.near
    local keyB, gb, toB, toBT, nearFloors, nearFloorsT
    if near then
        toB, toBT, nearFloors, nearFloorsT = NearEnd(w, bx, by, near, keyA, not rev)
    else
        keyB, gb, toB, toBT = End(w, bx, by, opts and opts.indoorsB, not rev)
    end
    if not toB then return nil end
    local best, bestTime = mhuge, nil
    if nearFloors then
        local inTile = nearFloors[keyA]
        if inTile and inTile[ga] then best, bestTime = inTile[ga], nearFloorsT[keyA][ga] end
    elseif keyA == keyB then
        local cost, _, time = TileSearch(w, Tile(w, keyA), ga, gb, nil, nil, nil, rev)
        if cost[gb] then best, bestTime = cost[gb], time[gb] end
    end
    -- B is reached only on ground A stands on; the grounds join only by
    -- safe drops, so a higher limit searches.
    local grounds = Limit(w) <= (w.data.safe or 0) and w.data.grounds
    if grounds and best == mhuge then
        wipe(onGround)
        for node in pairs(fromA) do onGround[GroundOf(grounds, node)] = true end
        local joined = false
        for node in pairs(toB) do
            if onGround[GroundOf(grounds, node)] then joined = true break end
        end
        if not joined then return nil end
    end
    local reached, prev, cut
    best, reached, prev, cut = Search(w, fromA, toB, bx, by, best, opts and opts.limit, near, rev)
    if best == mhuge then return nil, cut end
    local chain = {}
    local node = reached
    while node do
        tinsert(chain, 1, node)
        node = prev[node]
    end
    local time = bestTime
    if reached then
        time = fromAT[chain[1]] + toBT[reached]
        local sides = w.data.sides
        for k = 1, #chain - 1 do
            local n1, n2 = chain[k], chain[k + 1]
            if n2 == Other(n1) then
                time = time + w.cell
            else
                local tc = TileCosts(w, SideKey(SideV(sides, n1)))
                local i, j = tc.at[n1], tc.at[n2]
                time = time + tc.time[rev and PairIndex(tc, j, i) or PairIndex(tc, i, j)]
            end
        end
    end
    return best, chain, keyA, ga, keyB, gb, time * PULLED
end

-- A point's distance from each landmark: the least, over its tile's
-- sides, of the way to the side (rev: from it, the walk's end) and the
-- side's own; false where unknown. Kept by the point, so every walk
-- between fixed spots is bounded at once.
local function Marks(w, x, y, rev)
    local key = mfloor(x) .. ":" .. mfloor(y) .. (rev and "<" or "")
    local m = w.marks[key]
    if m ~= nil then return m or nil end
    w.used = GetTime()
    if w.marksN >= MARKS_KEPT then w.marks, w.marksN = {}, 0 end
    w.marksN = w.marksN + 1
    local alt = w.data.marks
    local _, _, reach = End(w, x, y, nil, rev)
    if not (alt and reach) then
        w.marks[key] = false
        return nil
    end
    m = {}
    for l = 1, #alt do
        local s, least = alt[l], mhuge
        for node, fin in pairs(reach) do
            local d = Mark(s, (node + node % 2) / 2)
            if d > 0 and fin + d < least then least = fin + d end
        end
        m[l] = least < mhuge and least or false
    end
    w.marks[key] = m
    return m
end

-- What the walk from a to b costs at the least, in running yards, from the
-- landmarks: at least the difference of the ends' distances from any one.
-- Nil without landmarks or an end off the grid.
function Nav.Bound(ci, ax, ay, bx, by)
    local w = World(ci)
    if not w then return nil end
    local ma, mb = Marks(w, ax, ay), Marks(w, bx, by, true)
    if not (ma and mb) then return nil end
    local best, play = 0, w.cell + 1
    for l = 1, #ma do
        local a, b = ma[l], mb[l]
        if a and b then
            local diff = (a > b and a - b or b - a) - play
            if diff > best then best = diff end
        end
    end
    return best
end

-- The ground nearest (x, y), within cells of it in its tile, that leads out
-- of the tile: a goal off the grid (a zone's middle on a peak) stands
-- there. World x, y, or nil.
function Nav.Ground(ci, x, y, cells)
    local w = World(ci)
    if not w then return nil end
    local key, sx, sy = TileOf(x, y)
    local t = Tile(w, key)
    if not t then return nil end
    local N, cell = w.N, w.cell
    local r0, c0 = mfloor((x - sx) / cell), mfloor((y - sy) / cell)
    for ring = 0, cells do
        for r = r0 - ring, r0 + ring do
            for c = c0 - ring, c0 + ring do
                if (mabs(r - r0) == ring or mabs(c - c0) == ring) and r >= 0 and c >= 0 and r < N and c < N then
                    local cc = r * N + c
                    for g = U16(t.cf, cc + 1), U16(t.cf, cc + 2) - 1 do
                        local out = ToEntrances(w, t, g)
                        if out and next(out) then return FloorXY(w, t, g) end
                    end
                end
            end
        end
    end
    return nil
end

-- Whether the cell under (x, y) holds only the water's surface: nothing
-- there to stand on, so one standing still is on a boat's deck.
function Nav.OpenWater(ci, x, y)
    local w = World(ci)
    if not w then return false end
    local key, sx, sy = TileOf(x, y)
    local t = Tile(w, key)
    if not t then return false end
    local cc = mfloor((x - sx) / w.cell) * w.N + mfloor((y - sy) / w.cell)
    local first, past = U16(t.cf, cc + 1), U16(t.cf, cc + 2)
    if past <= first then return false end
    for g = first, past - 1 do
        if sbyte(t.fb, g) % 2 == 0 then return false end
    end
    return true
end

-- For dev/tools/navmesh/bake_spots.lua: a fixed spot's key and costs to
-- its tile's entrance sides, or with near its boarding circle's; rev: the
-- costs from the sides instead.
function Nav.SpotReach(ci, x, y, near, rev)
    local w = World(ci)
    if not w then return nil end
    if near then
        local out, outT = NearEnd(w, x, y, near, nil, rev)
        return NearKey(x, y, near), out, outT
    end
    local t, g = Locate(w, x, y)
    if not g then return nil end
    local out, outT = ToEntrances(w, t, g, rev)
    return t.key, g, out, outT
end

-- A walk as Walk finds it, kept with its chain: the drawing of a priced
-- walk reads the chain instead of searching again. false: no way; beyond:
-- not found within the limit asked.
local BEYOND = { beyond = true }
local function Kept(w, ax, ay, bx, by, opts)
    local key = mfloor(ax / 4) .. ":" .. mfloor(ay / 4) .. ":" .. mfloor(bx / 4) .. ":" .. mfloor(by / 4)
        .. ((opts and opts.indoorsA) and "i" or "") .. ((opts and opts.indoorsB) and "i" or "")
        .. ((opts and opts.limit) and ("L" .. mfloor(opts.limit)) or "")
        .. ((opts and opts.near) and ("N" .. opts.near) or "")
        .. ((opts and opts.reverse) and "R" or "")
    if Floors then key = key .. Floors.Tag(w.ci, ax, ay) .. "|" .. Floors.Tag(w.ci, bx, by) end
    local walk = w.walks[key]
    w.used = GetTime()
    if walk == nil then
        if w.walksN >= WALKS_KEPT then w.walks, w.walksN = {}, 0 end
        local cost, chain, keyA, ga, keyB, gb, time = Walk(w, ax, ay, bx, by, opts)
        walk = cost and { cost, chain, keyA, ga, keyB, gb, time } or (chain and BEYOND) or false
        w.walks[key], w.walksN = walk, w.walksN + 1
    end
    return walk
end

-- Walking cost in running yards from (ax, ay) to (bx, by) on continent ci,
-- or nil (no data there, or no way on foot), then nil and the walk's time
-- (yards walked, swimming slower). opts.indoorsA / indoorsB pick the floor
-- at each end; opts.limit gives up past that many running yards, answering
-- nil, true; opts.near takes any floor within that many yards of b as the
-- end; opts.reverse prices the walk from b to a.
function Nav.Walk(ci, ax, ay, bx, by, opts)
    local w = World(ci)
    if not w then return nil end
    local walk = Kept(w, ax, ay, bx, by, opts)
    if not walk then return nil end
    if walk.beyond then return nil, true end
    return walk[1], nil, walk[7]
end

function Nav.Has(ci) return ns.GPSNavData ~= nil and ns.GPSNavData[ci] ~= nil end
Nav.Ensure = Nav.Has

-- One kept set's tile costs and ends idle for age seconds go: whether
-- any stay, and how many ends went.
local function DropIdle(costs, reach, age, now)
    local stays, gone = false, 0
    for key, tc in pairs(costs) do
        if tc and (tc.used or 0) + age <= now then costs[key] = nil elseif tc then stays = true end
    end
    for rk, kept in pairs(reach) do
        if (kept.used or 0) + age <= now then
            reach[rk], gone = nil, gone + 1
        else
            stays = true
        end
    end
    return stays, gone
end

-- Decoded data idle for age seconds goes: a tile by its last read, a
-- tile's walking costs and a kept end by the last walk that read them,
-- and a continent's kept walks once no walk has asked for them, the
-- shelved ones too. Landmark distances stay: small, and every plan's
-- bounds. True while anything decoded remains.
function Nav.Release(age)
    local now = GetTime()
    local held = false
    for _, w in pairs(worlds) do
        local order = w.order
        for i = #order, 1, -1 do
            local key = order[i]
            local t = w.tiles[key]
            if not t or t.at + age <= now then
                w.tiles[key] = nil
                tremove(order, i)
            end
        end
        if #order > 0 then held = true end
        local stays, gone = DropIdle(w.costs, w.reach, age, now)
        w.reachN = w.reachN - gone
        if stays then held = true end
        for _, set in pairs(w.shelf) do
            stays, gone = DropIdle(set[5], set[3], age, now)
            set[4] = set[4] - gone
            if stays then held = true end
        end
        if w.used then
            if w.used + age <= now then
                w.used = nil
                w.walks, w.walksN, w.reach, w.reachN, w.costs = {}, 0, {}, 0, {}
                for _, set in pairs(w.shelf) do
                    set[1], set[2], set[3], set[4], set[5] = {}, 0, {}, 0, {}
                end
            else
                held = true
            end
        end
    end
    return held
end

-- Drawing ---------------------------------------------------------------------

-- Whether one walks straight from floor a to floor b of tile t: the cells
-- along the line, each reached from the one before by a link, none more
-- dangerous than both ends.
Clear = function(w, t, a, b)
    local N = w.N
    local top = dangerSet and mmax(DangerAt(w, t, a), DangerAt(w, t, b))
    local ca, cb = U16(t.fc, a), U16(t.fc, b)
    local r, c, r1, c1 = mfloor(ca / N), ca % N, mfloor(cb / N), cb % N
    local dr, dc = r1 - r, c1 - c
    local sr, sc = dr > 0 and 1 or -1, dc > 0 and 1 or -1
    local nr, ncl = mabs(dr), mabs(dc)
    local g = a
    -- From dry ground the line may end in water, not cross it.
    local dry = sbyte(t.fb, a) % 2 == 0
    local ir, ic = 0, 0
    while ir < nr or ic < ncl do
        -- Step along whichever axis the line crosses next.
        local stepRow = (0.5 + ir) * ncl < (0.5 + ic) * nr
        if ic >= ncl then stepRow = true elseif ir >= nr then stepRow = false end
        local d
        if stepRow then d = sr > 0 and 1 or 3; ir = ir + 1 else d = sc > 0 and 2 or 0; ic = ic + 1 end
        local u, o = Step(w, t, g, d)
        if not o or u ~= t then return false end
        g = o
        if dry and (ir < nr or ic < ncl) and sbyte(t.fb, g) % 2 == 1 then return false end
        if top and DangerAt(w, t, g) > top then return false end
    end
    return g == b
end

-- Whether one walks straight from floor g of tile t to floor g2 of tile
-- t2, across tiles, as Clear within one.
local function Sees(w, t, g, t2, g2)
    local cell = w.cell
    local top = dangerSet and mmax(DangerAt(w, t, g), DangerAt(w, t2, g2))
    local x0, y0 = FloorXY(w, t, g)
    local x1, y1 = FloorXY(w, t2, g2)
    local nr, ncl = mfloor(mabs(x1 - x0) / cell + 0.5), mfloor(mabs(y1 - y0) / cell + 0.5)
    local alongRow, alongCol = x1 > x0 and 1 or 3, y1 > y0 and 2 or 0
    local dry = sbyte(t.fb, g) % 2 == 0
    local ir, ic = 0, 0
    while ir < nr or ic < ncl do
        local stepRow = (0.5 + ir) * ncl < (0.5 + ic) * nr
        if ic >= ncl then stepRow = true elseif ir >= nr then stepRow = false end
        local d
        if stepRow then d, ir = alongRow, ir + 1 else d, ic = alongCol, ic + 1 end
        t, g = Step(w, t, g, d)
        if not g or (dry and sbyte(t.fb, g) % 2 == 1 and (ir < nr or ic < ncl)) then return false end
        if top and DangerAt(w, t, g) > top then return false end
    end
    return t == t2 and g == g2
end

-- The height of floor g of tile t where its cell's floors stack (Floors'
-- data), nil where it is the only one.
local function FloorHeight(w, t, g)
    if not (Floors and Floors.Height) then return nil end
    local cc = U16(t.fc, g)
    return Floors.Height(w.ci, t.key, cc, g - U16(t.cf, cc + 1))
end

-- A door on the straight walk from floor g of tile t to floor g2 of tile
-- t2: the first floor along it under a roof (inside) or in the open (not),
-- as Sees steps it, with its height where floors stack; the far end where
-- the line cannot be stepped.
local function DoorOn(w, t, g, t2, g2, inside)
    local cell = w.cell
    local x0, y0 = FloorXY(w, t, g)
    local x1, y1 = FloorXY(w, t2, g2)
    local nr, ncl = mfloor(mabs(x1 - x0) / cell + 0.5), mfloor(mabs(y1 - y0) / cell + 0.5)
    local alongRow, alongCol = x1 > x0 and 1 or 3, y1 > y0 and 2 or 0
    local ir, ic = 0, 0
    while ir < nr or ic < ncl do
        local stepRow = (0.5 + ir) * ncl < (0.5 + ic) * nr
        if ic >= ncl then stepRow = true elseif ir >= nr then stepRow = false end
        local d
        if stepRow then d, ir = alongRow, ir + 1 else d, ic = alongCol, ic + 1 end
        t, g = Step(w, t, g, d)
        if not g then break end
        if (sbyte(t.fl, g) % 4 >= 2) == inside then
            local x, y = FloorXY(w, t, g)
            return x, y, FloorHeight(w, t, g)
        end
    end
    return x1, y1, FloorHeight(w, t2, g2)
end

-- Whether one walks straight from (ax, ay) to (bx, by): each cell along
-- the line reached from the one before by a link, across tiles, and none
-- before the last of them water unless the start is. nil off the grid.
function Nav.Straight(ci, ax, ay, bx, by, indoors)
    local w = World(ci)
    if not w then return nil end
    local t, g = Locate(w, ax, ay, indoors, 1)
    if not g then return nil end
    local cell = w.cell
    local x0, y0 = FloorXY(w, t, g)
    local _, sx, sy = TileOf(bx, by)
    local x1 = sx + (mfloor((bx - sx) / cell) + 0.5) * cell
    local y1 = sy + (mfloor((by - sy) / cell) + 0.5) * cell
    local nr, ncl = mfloor(mabs(x1 - x0) / cell + 0.5), mfloor(mabs(y1 - y0) / cell + 0.5)
    local alongRow, alongCol = x1 > x0 and 1 or 3, y1 > y0 and 2 or 0
    local dry = sbyte(t.fb, g) % 2 == 0
    local ir, ic = 0, 0
    while ir < nr or ic < ncl do
        local stepRow = (0.5 + ir) * ncl < (0.5 + ic) * nr
        if ic >= ncl then stepRow = true elseif ir >= nr then stepRow = false end
        local d
        if stepRow then d, ir = alongRow, ir + 1 else d, ic = alongCol, ic + 1 end
        t, g = Step(w, t, g, d)
        if not g or (dry and sbyte(t.fb, g) % 2 == 1 and (ir < nr or ic < ncl)) then return false end
    end
    return true
end

-- Of tile t's floors within r of (x, y), the one a walk from floor g
-- comes to cheapest, its distance from the point added as a near end's
-- seeds have it; nil when none is reached.
local function NearFloor(w, t, g, x, y, r)
    local cost = TileSearch(w, t, g, nil, nil, nil, true)
    local N, cell = w.N, w.cell
    local best, bestC
    for row = mmax(0, mfloor((x - r - t.sx) / cell)), mmin(N - 1, mfloor((x + r - t.sx) / cell)) do
        for col = mmax(0, mfloor((y - r - t.sy) / cell)), mmin(N - 1, mfloor((y + r - t.sy) / cell)) do
            local cc = row * N + col
            for f = U16(t.cf, cc + 1), U16(t.cf, cc + 2) - 1 do
                local fx, fy = FloorXY(w, t, f)
                local c = cost[f] and cost[f] + msqrt((fx - x) ^ 2 + (fy - y) ^ 2)
                if c and (fx - x) ^ 2 + (fy - y) ^ 2 <= r * r and (not bestC or c < bestC) then best, bestC = f, c end
            end
        end
    end
    return best
end

-- Floor path inside tile t from a to b, pulled straight: world points
-- appended to out (their tile and floor to ft, fg, by vertex), and each
-- drop above the safe height it takes onto jumps ({ v = the vertex it
-- lands on, h = its height }). A straight pull never crosses a drop (no
-- link joins its ends), so its landing is a vertex.
local function TilePath(w, t, a, b, out, jumps, ft, fg)
    local _, prev = TileSearch(w, t, a, b, nil, nil, nil, nil, true)
    if a ~= b and not prev[b] then return false end
    local cells = {}
    local g = b
    while g do
        tinsert(cells, 1, g)
        if g == a then break end
        g = prev[g]
    end
    local i = 1
    local safe = w.data.safe or 0
    local function emit(f, k)
        local x, y = FloorXY(w, t, f)
        if not (out[#out - 1] == x and out[#out] == y) then
            out[#out + 1], out[#out + 2] = x, y
            ft[#out / 2], fg[#out / 2] = t, f
        end
        local list = k and t.drop and t.drop[cells[k - 1]]
        for d = 1, list and #list or 0, 2 do
            if list[d] == f and list[d + 1] > safe then jumps[#jumps + 1] = { v = #out / 2, h = list[d + 1] } end
        end
    end
    emit(cells[1])
    local bends = 0
    while i < #cells do
        local j = i + 1
        while j < #cells and Clear(w, t, cells[i], cells[j + 1]) do j = j + 1 end
        emit(cells[j], j)
        i = j
        bends = bends + 1
        if bends % 8 == 0 then Pause() end
    end
    return true
end

-- The walk's points { x1, y1, x2, y2, ... } from a to b, its cost (the
-- yards it was chosen by), its time (yards walked, swimming slower, the
-- same the walk was priced by) and the drops above the safe height it
-- takes ({ v = the vertex it lands on, h = yards }), or nil. Drawn the way
-- it is walked: opts.reverse is for pricing only. Last, after the named
-- floors ({ v, en, name, z }), its doors: from (whether it sets out under
-- a roof) and each place it comes out into the open or goes in ({ v = the
-- vertex its stretch ends at, x, y, z, inside = under a roof from there
-- on }). z: the height of the walk's own floor there where floors stack.
function Nav.Path(ci, ax, ay, bx, by, opts)
    local w = World(ci)
    if not w or (opts and opts.reverse) then return nil end
    local walk = Kept(w, ax, ay, bx, by, opts)
    if not walk or walk.beyond then return nil end
    local cost, chain, keyA, ga, keyB, gb = walk[1], walk[2], walk[3], walk[4], walk[5], walk[6]
    local near = opts and opts.near
    if not (keyB or near) then return nil end
    local sides = w.data.sides
    local out, jumps, ft, fg = { ax, ay }, {}, {}, {}
    local t, g = Tile(w, keyA), ga
    local k = 1
    while k <= #chain do
        local node = chain[k]
        local v = SideV(sides, node)
        if SideKey(v) ~= t.key then return nil end
        if not TilePath(w, t, g, SideFloor(v), out, jumps, ft, fg) then return nil end
        -- Across: the next node is the other side when the walk crosses here.
        local nxt = chain[k + 1]
        if nxt == Other(node) then
            local nv = SideV(sides, nxt)
            t = Tile(w, SideKey(nv))
            g = SideFloor(nv)
            k = k + 2
        else
            g = SideFloor(v)
            k = k + 1
        end
        if not t then return nil end
    end
    if near then
        -- A near end: the floor within reach of b this last tile's walk
        -- comes to cheapest, then on to b.
        gb = NearFloor(w, t, g, bx, by, near)
        if not gb then return nil end
    elseif t.key ~= keyB then
        return nil
    else
        t = Tile(w, keyB)
    end
    if not TilePath(w, t, g, gb, out, jumps, ft, fg) then return nil end
    -- Pulled straight across the tiles too: a walk crosses a tile's edge
    -- at one of its few entrances, a way round where the line is clear.
    local n = #out / 2
    -- Each named floor it enters (a city's sewers), read at its bends.
    local levels, was = {}, nil
    for v = 2, Floors and Floors.LevelName and n or 0 do
        local tv, x, y = ft[v], out[2 * v - 1], out[2 * v]
        local en, name
        local key, sx, sy = TileOf(x, y)
        if tv and key == tv.key then
            local cc = mfloor((x - sx) / w.cell) * w.N + mfloor((y - sy) / w.cell)
            en, name = Floors.LevelName(w.ci, key, cc, fg[v] - U16(tv.cf, cc + 1), x, y)
        end
        if en ~= was then
            if en then levels[#levels + 1] = { v = v, en = en, name = name, z = FloorHeight(w, tv, fg[v]) } end
            was = en
        end
    end
    local landing = {}
    for j = 1, #jumps do landing[jumps[j].v] = true end
    for j = 1, #levels do landing[levels[j].v] = true end
    local keep, checks = { 1 }, 0
    local i = 2
    while i <= n do
        keep[#keep + 1] = i
        local j = i + 1
        while j < n and not landing[j] and ft[i] and ft[j + 1] and Sees(w, ft[i], fg[i], ft[j + 1], fg[j + 1]) do
            j = j + 1
            checks = checks + 1
            if checks % 8 == 0 then Pause() end
        end
        i = j
    end
    if #keep < n then
        local pulled, at = {}, {}
        for v = 1, #keep do
            local o = keep[v]
            pulled[2 * v - 1], pulled[2 * v], at[o] = out[2 * o - 1], out[2 * o], v
        end
        for j = 1, #jumps do jumps[j].v = at[jumps[j].v] end
        for j = 1, #levels do levels[j].v = at[levels[j].v] end
        out = pulled
    end
    -- A walk crosses a tile's edge at one of its few entrances: a bend
    -- there moves to the point near it that shortens the walk most, both
    -- legs still walked straight (it went along a road to an entrance, then
    -- over a hill straight from the start, on Zephras Isle, 2026-11-18).
    local vt, vg = {}, {}
    for v = 1, #keep do vt[v], vg[v] = ft[keep[v]], fg[keep[v]] end
    local cell, cands = w.cell, {}
    for v = 3, #keep - 1 do
        local t0, t1, t2 = vt[v - 1], vt[v], vt[v + 1]
        if t0 and t1 and t2 and (t0 ~= t1 or t1 ~= t2) and not landing[keep[v]] then
            local qx, qy, rx, ry = out[2 * v - 3], out[2 * v - 2], out[2 * v + 1], out[2 * v + 2]
            local cx, cy = out[2 * v - 1], out[2 * v]
            local now = msqrt((qx - cx) ^ 2 + (qy - cy) ^ 2) + msqrt((rx - cx) ^ 2 + (ry - cy) ^ 2) - cell
            wipe(cands)
            for dx = -RELAX_YARDS, RELAX_YARDS, cell do
                for dy = -RELAX_YARDS, RELAX_YARDS, cell do
                    local x, y = cx + dx, cy + dy
                    local d = msqrt((qx - x) ^ 2 + (qy - y) ^ 2) + msqrt((rx - x) ^ 2 + (ry - y) ^ 2)
                    if d < now then cands[#cands + 1] = { d, x, y } end
                end
            end
            table.sort(cands, CandLess)
            for j = 1, mmin(#cands, RELAX_TRIES) do
                local tc, gc = Locate(w, cands[j][2], cands[j][3], nil, 0)
                checks = checks + 1
                if checks % 8 == 0 then Pause() end
                if gc and sbyte(tc.fb, gc) % 2 == sbyte(t1.fb, vg[v]) % 2
                    and Sees(w, t0, vg[v - 1], tc, gc) and Sees(w, tc, gc, t2, vg[v + 1]) then
                    vt[v], vg[v] = tc, gc
                    out[2 * v - 1], out[2 * v] = FloorXY(w, tc, gc)
                    break
                end
            end
        end
    end
    local doors, last
    for v = 1, #keep do
        local tv, gv = vt[v], vg[v]
        if tv and gv then
            local inside = sbyte(tv.fl, gv) % 4 >= 2
            if not doors then
                doors = { from = inside }
            elseif inside ~= (sbyte(vt[last].fl, vg[last]) % 4 >= 2) then
                local x, y, z = DoorOn(w, vt[last], vg[last], tv, gv, inside)
                doors[#doors + 1] = { v = v, x = x, y = y, z = z, inside = inside }
            end
            last = v
        end
    end
    out[#out + 1], out[#out + 2] = bx, by
    return out, cost, walk[7], jumps, levels, doors
end

-- Probe (dev tools, tests): the tile and floor under a point (exact: its
-- own cell only), its cell, and how many of its tile's entrance sides it
-- reaches of how many.
-- Where indoor floors stack with outdoor ones under (x, y) (a cave under a
-- hill, a hall under a roof walked on): whether the floor a walk ending
-- there stops on is indoors. nil where the cell holds only one kind.
function Nav.InsideAt(ci, x, y)
    local w = World(ci)
    if not w then return nil end
    local t, g = Locate(w, x, y, nil, 0)
    if not g then return nil end
    local key, sx, sy = TileOf(x, y)
    if key ~= t.key then return nil end
    local cc = mfloor((x - sx) / w.cell) * w.N + mfloor((y - sy) / w.cell)
    local inside, outside = false, false
    for f = U16(t.cf, cc + 1), U16(t.cf, cc + 2) - 1 do
        if sbyte(t.fl, f) % 4 >= 2 then inside = true else outside = true end
    end
    if not (inside and outside) then return nil end
    return sbyte(t.fl, g) % 4 >= 2
end

function Nav.Probe(ci, x, y, indoors, exact)
    local w = World(ci)
    if not w then return nil end
    local t, g = Locate(w, x, y, indoors, exact and 0 or nil)
    if not g then return t and t.key end
    local reach = ToEntrances(w, t, g)
    local n = 0
    for _ in pairs(reach) do n = n + 1 end
    local tc = TileCosts(w, t.key)
    return t.key, g, U16(t.fc, g), n, tc and tc.n or 0, t.nf
end
