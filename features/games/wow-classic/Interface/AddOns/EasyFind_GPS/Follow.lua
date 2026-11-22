-- EasyFind GPS: the walk being followed.
--
-- The active step's way on foot, from where the step starts, and where
-- along it the player stands. Straying off it, a way from where the
-- player is back onto it a little ahead joins the walk's rest, so the
-- walk keeps its shape; a whole way from here takes over only once it
-- stays clearly faster. The arrow, the map line and the minimap line all
-- read it, taken once a frame at most.
local ns = EasyFind and EasyFind._ns
if not ns or select(2, ...).tooOld then return end
local Follow = {}
ns.GPSFollow = Follow

local msqrt, mmax, mmin, mhuge = math.sqrt, math.max, math.min, math.huge

local OFF_WAY = 20             -- yards off the walk before it is found again
Follow.OFF_WAY = OFF_WAY
local REFIND = 4               -- seconds at least between two findings
-- Off the walk, the way back onto it is asked anew from where the player
-- stands once this far from where it was asked, this often, while off it
-- by this much: it slides along beside a player who keeps off the walk,
-- never back to where it was asked.
local REJOIN_YD, REJOIN_SECONDS, REJOIN_OFF = 5, 1, 3
-- The way back joins the walk far ahead: at least this far, this many
-- times the yards off, at most this far. It then runs into the walk at a
-- shallow angle, the quickest way on from here, not sideways onto it.
local JOIN_AHEAD, JOIN_PER_OFF, JOIN_MAX = 80, 6, 400
local MARGIN_YD = 25           -- a whole way from here takes over only when shorter by this
local BACK, ON = 2, 12         -- stretches searched behind and ahead of the last one matched
local RIDES = { taxi = true, boat = true, ferry = true, zeppelin = true, skyship = true, tram = true }
Follow.RIDES = RIDES
local AT_BUILDING = 40         -- yards from a building's stairs where its step's words lead
local AT_LIFT = 25             -- yards from a lift's shaft where its rider may still be up or down it
local LIFT_IN = 0.25           -- of the way through a lift's shaft: from here its far door is aimed at

-- At the stairs (or the way out) of a building the walking grid cannot
-- enter: the step's words lead from here on, not the arrow or the
-- beacon, however far the climb then goes.
function Follow.AtBuilding(step)
    if not (step and (step.kind == "enter" or step.kind == "leave") and step.go) then return false end
    if step.atBuilding then return true end
    local ci, px, py = ns.GPS.PlayerWorldPos()
    local tci, tx, ty = Follow.World(step.go)
    if ci ~= nil and ci == tci and (tx - px) ^ 2 + (ty - py) ^ 2 <= AT_BUILDING * AT_BUILDING then
        step.atBuilding = true
    end
    return step.atBuilding == true
end

local walk = { seg = 1 }       -- the walk followed: its route, step, end, path, matched stretch, own way (plan)
Follow._walk = walk            -- dev tools
-- The last whole reading, and the one being taken: a reader called while
-- one is taken (the planner redraws every surface as a way is asked of
-- it) gets the last whole one, never a half-built one.
local cur, nxt = {}, {}
local stamp                    -- the GetTime() the last reading was taken at
local axes = {}                -- per continent: north and west as world directions

local function Route() local g = ns.GPS return g and g.CurrentRoute and g.CurrentRoute() end

local function World(p)
    if not p then return nil end
    if p.wx and p.ci then return p.ci, p.wx, p.wy end
    local toWorld = ns.GPSRoute and ns.GPSRoute.WorldPos
    if p.m and toWorld then return toWorld(p.m, p.x, p.y) end
    return nil
end
Follow.World = World

-- Where step i starts: its own start (a ghost's walk, from where it
-- released), the step before's landing, or where the route was planned.
local function StartOf(route, i)
    local own = route.steps[i] and route.steps[i].from
    if own then return World(own) end
    if i > 1 then return World(route.steps[i - 1].arrive) end
    return World(route.from)
end
Follow.StartOf = StartOf

-- North and west in the client's world coordinates, read off the player's
-- map (up is north, left is west) rather than assumed.
function Follow.Axes(ci)
    local a = axes[ci]
    if a then return a end
    local toWorld = ns.GPSRoute and ns.GPSRoute.WorldPos
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not (toWorld and mapID) then return nil end
    local c0, x0, y0 = toWorld(mapID, 0.5, 0.5)
    local c1, xn, yn = toWorld(mapID, 0.5, 0.4)
    local c2, xw, yw = toWorld(mapID, 0.4, 0.5)
    if not (c0 == ci and c1 == ci and c2 == ci) then return nil end
    local nx, ny, wx, wy = xn - x0, yn - y0, xw - x0, yw - y0
    local ln, lw = msqrt(nx * nx + ny * ny), msqrt(wx * wx + wy * wy)
    if ln == 0 or lw == 0 then return nil end
    a = { nx / ln, ny / ln, wx / lw, wy / lw }
    axes[ci] = a
    return a
end

-- The walk from where it was found, once drawn: the route's own walks
-- by the planner, one from where the player strayed to by GPS.DrawWalk
-- in the planner's slices, asked here and again while it was busy. nil
-- until then; the arrow points straight meanwhile.
local function Drawn(ci, w, tx, ty, near)
    local find = ns.GPSRoute and ns.GPSRoute.WalkPath
    if not find then w.path = false return false end
    local path = find(ci, w.fx, w.fy, tx, ty, true, near)
    if path == nil then
        local now = GetTime()
        if not (w.asked and now - w.asked < REFIND) then
            local draw = ns.GPS.DrawWalk
            w.asked = draw and draw(ci, w.fx, w.fy, tx, ty, near) and now or nil
        end
        return nil
    end
    w.path = path
    return path
end

local function Find(ci, sx, sy, now)
    walk.found, walk.fx, walk.fy, walk.seg, walk.wide, walk.path, walk.asked = now, sx, sy, 1, true, nil, nil
    walk.plan, walk.ref, walk.cand, walk.join, walk.detour, walk.fromStart = nil, nil, nil, nil, nil, nil
    walk.plan = Drawn(ci, walk, walk.tx, walk.ty, walk.near) or nil
end

-- How far through a lift's shaft (x, y) lies along the line of its doors:
-- 0 at the one boarded, 1 at the one it lets off at; nil off this continent.
function Follow.ThroughLift(step, ci, x, y)
    local gci, gx, gy = World(step.go)
    local aci, ax, ay = World(step.arrive)
    if not (gx and ax and gci == ci and aci == ci) then return nil end
    local dx, dy = ax - gx, ay - gy
    local l2 = dx * dx + dy * dy
    if l2 == 0 then return nil end
    return ((x - gx) * dx + (y - gy) * dy) / l2
end

-- Beside the lift the step before took: up or down its shaft alike, a way
-- from where the player stands would start on the level he is leaving
-- (Undercity's Ruins, the sewers round): the walk keeps to its own way.
local function AtLift(route, index, ci, px, py)
    local lift = route.steps[index - 1]
    if not (lift and lift.kind == "elevator") then return false end
    local gci, gx, gy = World(lift.go)
    local aci, ax, ay = World(lift.arrive)
    if not (gx and ax and gci == ci and aci == ci) then return false end
    return (px - (gx + ax) / 2) ^ 2 + (py - (gy + ay) / 2) ^ 2 <= AT_LIFT * AT_LIFT
end

-- A walk's nearest point to (x, y), looked for near the stretch w matched
-- last (all of a walk just found): its stretch, the yards along the walk
-- there, how far off, and the point.
local function Nearest(path, x, y, w)
    local pts, cum = path.pts, path.cum
    local bestD, bestSeg, bestAlong, bestX, bestY = mhuge, w.seg, 0, x, y
    local lo, hi = mmax(1, w.seg - BACK), mmin(#pts / 2 - 1, w.seg + ON)
    if w.wide then lo, hi, w.wide = 1, #pts / 2 - 1, false end
    for s = lo, hi do
        local ax, ay = pts[2 * s - 1], pts[2 * s]
        local dx, dy = pts[2 * s + 1] - ax, pts[2 * s + 2] - ay
        local l2 = dx * dx + dy * dy
        local t = l2 > 0 and mmax(0, mmin(1, ((x - ax) * dx + (y - ay) * dy) / l2)) or 0
        local qx, qy = ax + t * dx, ay + t * dy
        local d = msqrt((x - qx) ^ 2 + (y - qy) ^ 2)
        if d < bestD then
            bestD, bestSeg, bestX, bestY = d, s, qx, qy
            bestAlong = cum[s] + t * (cum[s + 1] - cum[s])
        end
    end
    return bestSeg, bestAlong, bestD, bestX, bestY
end

-- Yards of walking left by a way from a point off it: back onto it, then
-- on to its end (its time, swimming slower).
local function Left(path, along, off)
    local len = path.len
    return off + (len > 0 and (path.time or len) * (len - along) / len or 0)
end

-- The way from off the walk to a point on it, then the walk from there:
-- one walk, from where the player is. Its trail: the walk's own way up to
-- abreast of where the player left it, drawn as walked behind it.
local function Stitch(way, path, j)
    local at = j.along
    local pts = {}
    for i = 1, #way.pts do pts[i] = way.pts[i] end
    local s, pc = 1, path.cum
    while s < #pc and pc[s + 1] <= at do s = s + 1 end
    for v = s + 1, #path.pts / 2 do pts[#pts + 1], pts[#pts + 2] = path.pts[2 * v - 1], path.pts[2 * v] end
    local cum, len = { 0 }, 0
    for v = 2, #pts / 2 do
        len = len + msqrt((pts[2 * v - 1] - pts[2 * v - 3]) ^ 2 + (pts[2 * v] - pts[2 * v - 2]) ^ 2)
        cum[v] = len
    end
    local rest = path.len > 0 and (path.time or path.len) * (path.len - at) / path.len or 0
    local jumps
    for k = 1, way.jumps and #way.jumps or 0 do
        jumps = jumps or {}
        jumps[#jumps + 1] = way.jumps[k]
    end
    for k = 1, path.jumps and #path.jumps or 0 do
        local p = path.jumps[k]
        if p.at >= at then
            jumps = jumps or {}
            jumps[#jumps + 1] = { at = p.at - at + way.len, x = p.x, y = p.y, h = p.h }
        end
    end
    local t = 1
    while t < #pc and pc[t + 1] <= j.from do t = t + 1 end
    return { pts = pts, cum = cum, len = len, time = (way.time or way.len) + rest, jumps = jumps,
             trail = { path = path, seg = t, x = j.qx, y = j.qy } }
end

-- Off the walk: the way from here back onto the walk's own way, to a point
-- far ahead on it, drawn in the planner's slices and joined to that way's
-- rest; asked anew as the player moves on, the last one kept until it is
-- drawn. No way there: nothing until moved on. True once joined.
local function Rejoin(ci, px, py, now)
    local plan = walk.plan
    if not plan then return false end
    local j = walk.join
    local gone = j and (j.fx - px) ^ 2 + (j.fy - py) ^ 2
    if j and j.path == false and gone <= OFF_WAY * OFF_WAY then return false end
    local anew = j and gone >= REJOIN_YD * REJOIN_YD and now - j.at >= REJOIN_SECONDS
    if j and j.joined and not anew then return false end
    if not j or j.path == false or anew then
        -- The whole walk searched: a player turned back along it is
        -- abreast of a point well behind the last one matched.
        local ref = walk.ref
        if not ref then ref = { seg = 1 } walk.ref = ref end
        ref.wide = true
        local seg, along, offPlan, qx, qy = Nearest(plan, px, py, ref)
        ref.seg = seg
        local at = mmin(plan.len, along + mmin(JOIN_MAX, mmax(JOIN_AHEAD, JOIN_PER_OFF * offPlan)))
        local jx, jy = Follow.PointAt(plan, at, seg)
        j = { fx = px, fy = py, tx = jx, ty = jy, from = along, qx = qx, qy = qy, along = at, at = now }
        walk.join = j
    end
    local way = j.path
    if way == nil then way = Drawn(ci, j, j.tx, j.ty, nil) end
    if not way then return false end
    walk.path = Stitch(way, plan, j)
    walk.seg, walk.wide, walk.asked, j.joined = 1, true, nil, true
    -- A way back far round (twice the straight line to the join and more):
    -- a whole way from here may do better.
    walk.detour = way.len > 2 * msqrt((j.tx - j.fx) ^ 2 + (j.ty - j.fy) ^ 2) or nil
    return true
end

-- With no way back onto the walk from here, a whole way from here takes
-- over once drawn; from a way back far round, once drawn and clearly
-- shorter than the walk from here. A way no shorter is dropped. True
-- when it took over.
local function Challenge(ci, px, py, now, path, along, off)
    local c = walk.cand
    if not c then
        local j = walk.join
        if not ((j and j.path == false) or walk.detour) or now - walk.found < REFIND then return false end
        c = { fx = px, fy = py, at = now, seg = 1, wide = true }
        walk.cand = c
    end
    local way = c.path
    if way == nil then way = Drawn(ci, c, walk.tx, walk.ty, walk.near) end
    if not way then
        if way == false then walk.cand = nil end
        return false
    end
    local seg, along2, off2 = Nearest(way, px, py, c)
    c.seg = seg
    local j = walk.join
    if (j and j.path == false) or Left(way, along2, off2) < Left(path, along, off) - MARGIN_YD then
        walk.found, walk.fx, walk.fy, walk.seg, walk.wide, walk.path, walk.asked = now, c.fx, c.fy, 1, true, way, nil
        walk.plan, walk.ref, walk.cand, walk.join, walk.detour, walk.fromStart = way, nil, nil, nil, nil, nil
        return true
    end
    if now - c.at >= REFIND and (c.fx - px) ^ 2 + (c.fy - py) ^ 2 > OFF_WAY * OFF_WAY then
        walk.cand, walk.detour = nil, nil
    end
    return false
end

-- The point `along` yards into the walk, searched from stretch s on.
function Follow.PointAt(path, along, s)
    local pts, cum = path.pts, path.cum
    local n = #pts / 2
    if along >= path.len then return pts[2 * n - 1], pts[2 * n] end
    while s < n - 1 and cum[s + 1] < along do s = s + 1 end
    local l = cum[s + 1] - cum[s]
    local t = l > 0 and mmax(0, mmin(1, (along - cum[s]) / l)) or 0
    return pts[2 * s - 1] + t * (pts[2 * s + 1] - pts[2 * s - 1]), pts[2 * s] + t * (pts[2 * s + 2] - pts[2 * s])
end

-- The reading r taken: r.ok once there is something to follow.
local function Take(r, now)
    local route = Route()
    if not (route and route.steps and not route.arrived) then return end
    local index = route.active or 1
    local step = route.steps[index]
    if not step or step.kind == "teleport" or step.noWay or (UnitOnTaxi and UnitOnTaxi("player")) then return end
    if Follow.AtBuilding(step) then return end
    -- Planned from elsewhere: nothing followed until the player reaches its
    -- start (the tick marks it joined); a way to it from him ran wherever
    -- the grid reached the first step (from Brill through Undercity's sewers).
    if route.origin and not route.joined then return end
    local ci, px, py = ns.GPS.PlayerWorldPos()
    local tci, tx, ty = World(step.go or step.arrive)
    -- On board a crossing: what is left is the ride to where it lands.
    local Boats = ns.GPSBoats
    if RIDES[step.kind] and step.arrive and Boats and Boats.Aboard and Boats.Aboard(ci, px, py, tci, tx, ty) then
        tci, tx, ty = World(step.arrive)
    end
    -- In a lift's shaft or out past it the ride is what is left: its far
    -- door, and no way on foot back to the door boarded (from the other
    -- level that way ran out through the sewers).
    local inLift = false
    if step.kind == "elevator" and ci then
        local t = Follow.ThroughLift(step, ci, px, py)
        inLift = t ~= nil and t > LIFT_IN
        if inLift then tci, tx, ty = World(step.arrive) end
    end
    if not (ci and tci == ci and tx) then return end
    r.route, r.index, r.ci, r.px, r.py, r.tx, r.ty = route, index, ci, px, py, tx, ty
    r.straight = msqrt((tx - px) ^ 2 + (ty - py) ^ 2)
    r.ride, r.path = RIDES[step.kind] or inLift, false
    r.ok = true
    if r.ride or step.fly then return end
    local sci, sx, sy = StartOf(route, index)
    local atLift = sci == ci and sx ~= nil and AtLift(route, index, ci, px, py)
    if walk.route ~= route or walk.index ~= index or walk.tx ~= tx or walk.ty ~= ty or (atLift and not walk.fromStart) then
        walk.route, walk.index, walk.tx, walk.ty, walk.near = route, index, tx, ty, step.near
        if sci == ci and sx then
            Find(ci, sx, sy, -mhuge)
            walk.fromStart = true
        else
            Find(ci, px, py, now)
        end
    end
    if atLift and walk.join and walk.plan then
        walk.path, walk.join, walk.cand, walk.detour, walk.wide = walk.plan, nil, nil, nil, true
    end
    local path = walk.path
    if path == nil then
        path = Drawn(ci, walk, walk.tx, walk.ty, walk.near)
        walk.plan = path or nil
    end
    local seg, along, off, qx, qy
    if path then seg, along, off, qx, qy = Nearest(path, px, py, walk) end
    if path == false then
        -- No way from where it was found: found again from here, once moved on.
        if not atLift and now - walk.found > REFIND and (walk.fx - px) ^ 2 + (walk.fy - py) ^ 2 > OFF_WAY * OFF_WAY then
            Find(ci, px, py, now)
            path = walk.path
            if path then seg, along, off, qx, qy = Nearest(path, px, py, walk) end
        end
    elseif path and not atLift then
        if (off > OFF_WAY or (walk.join and off > REJOIN_OFF)) and Rejoin(ci, px, py, now) then
            path = walk.path
            seg, along, off, qx, qy = Nearest(path, px, py, walk)
        end
        if Challenge(ci, px, py, now, path, along, off) then
            path = walk.path
            seg, along, off, qx, qy = Nearest(path, px, py, walk)
        end
    end
    if not path then return end
    walk.seg = seg
    r.path, r.seg, r.along, r.off, r.qx, r.qy, r.trail = path, seg, along, off, qx, qy, path.trail
end

-- The active step as it stands, or nil with nothing to follow (no route,
-- arrived, a spell, on a flight, another continent): the route, index,
-- ci and px, py (the player), tx, ty (the step's spot), straight (yards
-- there), ride (a crossing: tx, ty is where it is boarded), and on a walk
-- its path with seg, along, off and qx, qy (the nearest point on it), and
-- trail (a path stitched from off the walk: the walk's own way behind it,
-- { path, seg, x, y }, up to abreast of where it was left).
-- Taken once a frame; till it is whole, the frame before's stands.
function Follow.Now()
    local now = GetTime()
    if stamp == now then return cur.ok and cur or nil end
    stamp = now
    local r = nxt
    r.ok = false
    Take(r, now)
    nxt, cur = cur, r
    return r.ok and r or nil
end

-- The route was put away: the next reading starts afresh.
function Follow.Reset()
    walk.route, walk.path, stamp = nil, nil, nil
end
