-- walknet (2.0.9, M 16 Nov 2026, in Westfall's Dust Plains with the arrow to
-- The Fourth Troll Legend in Stranglethorn, 369 yards away through the
-- mountains: "it's not understanding mountains, it wants me to go through
-- the mountain"). A walk to a place in another zone was a straight line;
-- zone borders are mostly mountains, with few ways through. The arrow now
-- follows the continent's walking net (Data/WalkNet.lua: the walked ways
-- between its towns, passes, bridges and roads) from one zone to the next:
-- it joins the net at the stretch nearest the player, leads from corner to
-- corner along the cheapest way (roads before steep ground and water; a
-- drop or a waterfall only the way it can be walked; the other faction's
-- towns kept clear of) and leaves it at the stretch nearest the place. The
-- yards are the whole way. Inside one zone the straight line stays the way
-- unless the net's way is much longer (a ridge between), and a way begun on
-- the net is followed to its last corner (zone borders do not run along the
-- ridges).
-- Systems/MapMarkers.lua asks FDJ.WalkNetAim where it asks for a city's roads.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

do
    local OFF = 1.5     -- a yard off the net costs this many on it (the straight line there is not known to be clear)
    local NEAR = 300    -- yards: the net is looked for this near first,
    local FAR = 900     -- then this far
    local BUCKET = 250  -- yards: the squares the stretches are sorted into
    local PASSED = 12   -- yards: a corner this near is behind
    local BESIDE = 35   -- yards: this near the stretch after a corner is on it (the corner is behind)
    local ONROAD = 12   -- yards: this near a road's line is on the road
    local LONGER = 1.35 -- inside one zone: the net only when its way is this many times the straight line (and 60 yards) longer
    local CONTINENT_MAP = { [0] = 1415, [1] = 1414 }

    local function Number(v)
        if type(v) ~= "number" then return nil end
        if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
        return v
    end
    local function Yards(ax, ay, bx, by)
        local dx, dy = ax - bx, ay - by
        return math.sqrt(dx * dx + dy * dy)
    end

    -- The zone (its map) at a world position, as the game's continent map tells it.
    local zoneCache, zoneCount = {}, 0
    local function ZoneAt(c, x, y)
        local continentMap = CONTINENT_MAP[c]
        if not continentMap or not (C_Map and type(C_Map.GetMapInfoAtPosition) == "function" and type(C_Map.GetMapPosFromWorldPos) == "function") then return nil end
        local key = c * 100000000 + (math.floor(x / 12) + 3000) * 10000 + math.floor(y / 12) + 3000
        local hit = zoneCache[key]
        if hit ~= nil then return hit or nil end
        local vector = (type(CreateVector2D) == "function" and CreateVector2D(x, y)) or { x = x, y = y }
        local okPos, _, pos = pcall(C_Map.GetMapPosFromWorldPos, c, vector, continentMap)
        local mx, my
        if okPos and type(pos) == "table" then
            mx, my = pos.x, pos.y
            if (mx == nil or my == nil) and pos.GetXY then mx, my = pos:GetXY() end
        end
        local id
        if Number(mx) and Number(my) then
            local okInfo, info = pcall(C_Map.GetMapInfoAtPosition, continentMap, mx, my)
            id = okInfo and type(info) == "table" and Number(info.mapID) or nil
        end
        if not id then return nil end -- (not kept: the game may tell next time)
        if zoneCount > 4000 then zoneCache, zoneCount = {}, 0 end
        zoneCache[key], zoneCount = id, zoneCount + 1
        return id
    end

    -- The continent's net, read from its strings on first use.
    local nets = {}
    local function Net(c)
        local net = nets[c]
        if net ~= nil then return net or nil end
        local data = FDJ.WALKNET and FDJ.WALKNET[c]
        if not data then nets[c] = false return nil end
        local X, Y, n = {}, {}, 0
        for _, chunk in ipairs(data.nodes) do
            for x, y in string.gmatch(chunk, "(-?%d+) (-?%d+) ") do
                n = n + 1
                X[n], Y[n] = tonumber(x), tonumber(y)
            end
        end
        local A, B, L, C, F, m = {}, {}, {}, {}, {}, 0
        local at = {}      -- [node] = { edge, edge, ... }
        local buckets = {} -- [square] = { edge, ... }
        for _, chunk in ipairs(data.edges) do
            for a, b, l, cost, f in string.gmatch(chunk, "(%d+) (%d+) (%d+) (%d+) (%d+) ") do
                a, b = tonumber(a), tonumber(b)
                if X[a] and X[b] then
                    m = m + 1
                    A[m], B[m], L[m], C[m], F[m] = a, b, tonumber(l), tonumber(cost), tonumber(f)
                    at[a] = at[a] or {}
                    at[b] = at[b] or {}
                    at[a][#at[a] + 1] = m
                    at[b][#at[b] + 1] = m
                    local x0, x1 = math.floor(math.min(X[a], X[b]) / BUCKET), math.floor(math.max(X[a], X[b]) / BUCKET)
                    local y0, y1 = math.floor(math.min(Y[a], Y[b]) / BUCKET), math.floor(math.max(Y[a], Y[b]) / BUCKET)
                    for bx = x0, x1 do
                        for by = y0, y1 do
                            local key = bx * 4096 + by
                            local list = buckets[key]
                            if not list then list = {} buckets[key] = list end
                            list[#list + 1] = m
                        end
                    end
                end
            end
        end
        net = { X = X, Y = Y, A = A, B = B, L = L, C = C, F = F, at = at, buckets = buckets, n = n, m = m, mesh = tonumber(data.mesh) }
        nets[c] = net
        FDJ.WALKNET[c] = { nodes = {}, edges = {} } -- the strings are not needed again
        return net
    end

    -- Who walks: 1 Alliance, 2 Horde (3: either's ways, no faction yet).
    local function Side()
        if type(UnitFactionGroup) ~= "function" then return 3 end
        local ok, faction = pcall(UnitFactionGroup, "player")
        if ok and faction == "Alliance" then return 1 end
        if ok and faction == "Horde" then return 2 end
        return 3
    end
    local function Bit(flags, bit) -- bit: 1, 2, 4 or 8
        return math.floor(flags / bit) % 2 == 1
    end

    -- The stretches a place (x, y) can join the net at: those nearest it in
    -- its own zone (the nearest, and the ones not much further).
    -- -> { { d = yards to the stretch, e = edge, t = how far along it (0 at a, 1 at b), x, y = the point on it }, ... }
    local function Joins(net, c, side, x, y, reach)
        local zone = ZoneAt(c, x, y)
        -- nozone (2.0.13, M 18 Nov 2026 on Theramore's pier, the arrow
        -- pointing straight over the water at the Barrens: "it's not
        -- recognizing the dock"): out on a pier the game may name no zone
        -- for the place: the nearest stretches then, whatever their zone
        local X, Y, A, B, F = net.X, net.Y, net.A, net.B, net.F
        local found, seen = {}, {}
        local bx0, bx1 = math.floor((x - reach) / BUCKET), math.floor((x + reach) / BUCKET)
        local by0, by1 = math.floor((y - reach) / BUCKET), math.floor((y + reach) / BUCKET)
        for bx = bx0, bx1 do
            for by = by0, by1 do
                local list = net.buckets[bx * 4096 + by]
                if list then
                    for i = 1, #list do
                        local e = list[i]
                        if not seen[e] then
                            seen[e] = true
                            local f = F[e]
                            if side == 3 or Bit(f, side) then
                                local ax, ay = X[A[e]], Y[A[e]]
                                local dx, dy = X[B[e]] - ax, Y[B[e]] - ay
                                local len2 = dx * dx + dy * dy
                                local t = 0
                                if len2 > 0 then t = math.max(0, math.min(1, ((x - ax) * dx + (y - ay) * dy) / len2)) end
                                local qx, qy = ax + t * dx, ay + t * dy
                                local d = Yards(x, y, qx, qy)
                                if d <= reach then found[#found + 1] = { d = d, e = e, t = t, x = qx, y = qy } end
                            end
                        end
                    end
                end
            end
        end
        table.sort(found, function(p, q) return p.d < q.d end)
        local out, limit = {}, nil
        for i = 1, #found do
            local j = found[i]
            if limit and j.d > limit then break end
            if not zone or ZoneAt(c, j.x, j.y) == zone then
                if not limit then limit = j.d * 1.3 + 40 end
                out[#out + 1] = j
                if #out >= 12 then break end
            end
        end
        return out
    end

    -- From every corner of the net: what the cheapest way to the place
    -- costs (dist), how many yards it is (walk) and its next corner (next;
    -- none: straight to the place from there).
    local fields = {}
    local function Field(net, c, side, tx, ty, plain) -- (openahead: plain = by the yards alone, roads no cheaper)
        for i = 1, #fields do
            local f = fields[i]
            if f.c == c and f.side == side and f.plain == plain and Yards(f.tx, f.ty, tx, ty) < 2 then return f end
        end
        local joins = Joins(net, c, side, tx, ty, NEAR)
        if joins and #joins == 0 then joins = Joins(net, c, side, tx, ty, FAR) end
        local field = { c = c, side = side, tx = tx, ty = ty, plain = plain, dist = {}, walk = {}, next = {} }
        if #fields >= 4 then table.remove(fields, 1) end
        fields[#fields + 1] = field
        if not joins or #joins == 0 then field.none = true return field end
        local A, B, L, C, F, at = net.A, net.B, net.L, net.C, net.F, net.at
        local OFF = OFF
        if plain then C, OFF = L, 1 end
        local dist, walk, nextOf = field.dist, field.walk, field.next
        -- a binary heap of { cost, node }
        local heapCost, heapNode, size = {}, {}, 0
        local function Push(cost, node)
            size = size + 1
            local i = size
            while i > 1 do
                local parent = math.floor(i / 2)
                if heapCost[parent] <= cost then break end
                heapCost[i], heapNode[i] = heapCost[parent], heapNode[parent]
                i = parent
            end
            heapCost[i], heapNode[i] = cost, node
        end
        local function Pop()
            local cost, node = heapCost[1], heapNode[1]
            local lastCost, lastNode = heapCost[size], heapNode[size]
            heapCost[size], heapNode[size] = nil, nil
            size = size - 1
            if size > 0 then
                local i = 1
                while true do
                    local child = i * 2
                    if child > size then break end
                    if child < size and heapCost[child + 1] < heapCost[child] then child = child + 1 end
                    if heapCost[child] >= lastCost then break end
                    heapCost[i], heapNode[i] = heapCost[child], heapNode[child]
                    i = child
                end
                heapCost[i], heapNode[i] = lastCost, lastNode
            end
            return cost, node
        end
        for i = 1, #joins do
            local j = joins[i]
            local e = j.e
            local f = F[e]
            -- from a along the stretch to the point (a -> b walked), from b (b -> a walked)
            if Bit(f, 4) then
                local cost = OFF * j.d + j.t * C[e]
                if not dist[A[e]] or cost < dist[A[e]] then
                    dist[A[e]], walk[A[e]], nextOf[A[e]] = cost, j.d + j.t * L[e], nil
                    Push(cost, A[e])
                end
            end
            if Bit(f, 8) then
                local cost = OFF * j.d + (1 - j.t) * C[e]
                if not dist[B[e]] or cost < dist[B[e]] then
                    dist[B[e]], walk[B[e]], nextOf[B[e]] = cost, j.d + (1 - j.t) * L[e], nil
                    Push(cost, B[e])
                end
            end
        end
        while size > 0 do
            local cost, u = Pop()
            if cost <= dist[u] then
                local list = at[u]
                for i = 1, #list do
                    local e = list[i]
                    local f = F[e]
                    if side == 3 or Bit(f, side) then
                        local v, open
                        if B[e] == u then v, open = A[e], Bit(f, 4) else v, open = B[e], Bit(f, 8) end
                        if open then
                            local to = cost + C[e]
                            if not dist[v] or to < dist[v] then
                                dist[v], walk[v], nextOf[v] = to, walk[u] + L[e], u
                                Push(to, v)
                            end
                        end
                    end
                end
            end
        end
        return field
    end

    -- pullahead (2.1.1, M 20 Nov 2026 on the road through Riverglades'
    -- Bristle Hills, the arrow to Farholde Keep pointing off to the left:
    -- "it wants to find the anchor point ... make it cleaner"): the net's
    -- stretch there runs 20 yards beside the road, so the next corner was
    -- always off to the side. The arrow now looks ahead along the way and
    -- aims at the furthest corner (up to PULL yards walked) whose way there
    -- stays within LANE yards of the straight line to it: on a straight
    -- way it points down the way, at a bend it still turns at the bend.
    -- Not past a stretch that is steep or water (it is walked as it is).
    local PULL, LANE = 160, 18
    local function PullAhead(net, field, node, px, py)
        local X, Y, A, B, L, C, at = net.X, net.Y, net.A, net.B, net.L, net.C, net.at
        local passed = { node }
        local best, cur, walked = node, node, Yards(px, py, X[node], Y[node])
        for _ = 1, 40 do
            local nxt = field.next[cur]
            if not nxt then break end
            local edge
            for _, e in ipairs(at[cur] or {}) do
                if (A[e] == cur and B[e] == nxt) or (B[e] == cur and A[e] == nxt) then edge = e break end
            end
            if not edge then break end
            if L[edge] <= 0 or C[edge] / L[edge] > 1.15 then break end
            walked = walked + L[edge]
            if walked > PULL then break end
            local qx, qy = X[nxt], Y[nxt]
            local dx, dy = qx - px, qy - py
            local len2 = dx * dx + dy * dy
            if len2 <= 0 then break end
            local inLane = true
            for i = 1, #passed do
                local mx, my = X[passed[i]], Y[passed[i]]
                local t = math.max(0, math.min(1, ((mx - px) * dx + (my - py) * dy) / len2))
                if Yards(mx, my, px + t * dx, py + t * dy) > LANE then inLane = false break end
            end
            if not inLane then break end
            best = nxt
            passed[#passed + 1] = nxt
            cur = nxt
        end
        return best
    end

    -- Where the arrow aims on the way from (px, py) to (tx, ty) on continent
    -- c: the next corner of the net and the yards from it to the place; nil
    -- when the straight line is the way (the same zone, no net near, the
    -- last corner passed). memo: a table of the caller's (the arrow's entry)
    -- that keeps the answer while the player has not moved.
    local function Aim(memo, tx, ty, px, py, c)
        if not (Number(tx) and Number(ty) and Number(px) and Number(py)) or not CONTINENT_MAP[c] then return nil end
        local state = memo.walknet
        if state and state.c == c and Yards(state.tx, state.ty, tx, ty) < 2 then
            if Yards(px, py, state.px, state.py) < 4 then return state.aim, state.rest end
        else
            state = { c = c, tx = tx, ty = ty }
            memo.walknet = state
        end
        state.px, state.py, state.aim, state.rest = px, py, nil, nil
        local straight = Yards(px, py, tx, ty)
        local function Off(done) -- straight to the place from here on
            state.on, state.node, state.field = nil, nil, nil
            state.done = done and straight or nil
            return nil
        end
        if straight < 40 then return Off(true) end
        -- the last corner is behind: the straight line, unless the player walks well away again
        if state.done then
            if straight < state.done + 150 then return nil end
            state.done = nil
        end
        local net = Net(c)
        if not net then return nil end
        local X, Y = net.X, net.Y
        local here, there = ZoneAt(c, px, py), ZoneAt(c, tx, ty)
        local node, field = state.node, state.field
        -- openahead (2.0.13, M 18 Nov 2026 in Hillsbrad Fields on the way to
        -- Southshore's gryphon, the arrow leading back to a corner of the
        -- way it had begun at Dalaran: "it's telling me to go back when
        -- there's so much space in front of me ... a bit too strict on your
        -- anchor points"): in the place's own zone, when the shortest walk
        -- along the net (by the yards alone, roads no cheaper) is hardly
        -- longer than the straight line, nothing stands between: the
        -- straight line, also off a way already begun.
        if here and here == there then
            local side = Side()
            local plain = Field(net, c, side, tx, ty, true)
            local joins = not plain.none and Joins(net, c, side, px, py, NEAR) or nil
            local short
            for i = 1, joins and #joins or 0 do
                local j = joins[i]
                local e = j.e
                local f = net.F[e]
                local a, b = plain.walk[net.A[e]], plain.walk[net.B[e]]
                if Bit(f, 8) and a then
                    local w = j.d + j.t * net.L[e] + a
                    if not short or w < short then short = w end
                end
                if Bit(f, 4) and b then
                    local w = j.d + (1 - j.t) * net.L[e] + b
                    if not short or w < short then short = w end
                end
            end
            if short and short < straight * 1.2 + 60 then return Off(true) end
        end
        if node then
            -- A way once begun is kept, corner by corner: the same corner
            -- until it is reached, then the next. Only a player who walks
            -- well away from it is led anew.
            local d = Yards(px, py, X[node], Y[node])
            if d > state.closest + 30 then
                node = nil
            else
                if d < state.closest then state.closest = d end
                -- betterway (2.0.13, M 18 Nov 2026 on the road south of
                -- Nijel's Point, walking on south past the corner the arrow
                -- had begun with: "even after I get out of the road, it's
                -- still sending me back when I'm literally supposed to go
                -- straight forward"): every 15 yards walked, the way from
                -- where the player stands now: when it is shorter than going
                -- on to the kept corner, the arrow takes it.
                if not state.lookX or Yards(px, py, state.lookX, state.lookY) >= 15 then
                    state.lookX, state.lookY = px, py
                    local side = Side()
                    local joins = Joins(net, c, side, px, py, NEAR)
                    local best, fresh, way
                    for i = 1, joins and #joins or 0 do
                        local j = joins[i]
                        local e = j.e
                        local f = net.F[e]
                        local na, nb = net.A[e], net.B[e]
                        if Bit(f, 8) and field.dist[na] then
                            local cost = OFF * j.d + j.t * net.C[e] + field.dist[na]
                            if not best or cost < best then best, fresh, way = cost, na, j.d + j.t * net.L[e] + field.walk[na] end
                        end
                        if Bit(f, 4) and field.dist[nb] then
                            local cost = OFF * j.d + (1 - j.t) * net.C[e] + field.dist[nb]
                            if not best or cost < best then best, fresh, way = cost, nb, j.d + (1 - j.t) * net.L[e] + field.walk[nb] end
                        end
                    end
                    if fresh and fresh ~= node and field.walk[node] and way + 25 < d + field.walk[node] then
                        node = fresh
                        state.closest = Yards(px, py, X[node], Y[node])
                    end
                end
            end
        end
        if not node then
            if not there then return Off() end -- (nozone: the player's own zone not named: led by the net all the same)
            local sameZone = here ~= nil and here == there and not state.on
            local side = Side()
            field = Field(net, c, side, tx, ty)
            if field.none then return Off() end
            local joins = Joins(net, c, side, px, py, NEAR)
            if joins and #joins == 0 then joins = Joins(net, c, side, px, py, FAR) end
            if not joins or #joins == 0 then return Off() end
            local A, B, C, F = net.A, net.B, net.C, net.F
            local dist = field.dist
            local L = net.L
            local best, way, pick
            for i = 1, #joins do
                local j = joins[i]
                local e = j.e
                local f = F[e]
                -- towards a (b -> a walked), towards b (a -> b walked)
                if Bit(f, 8) and dist[A[e]] then
                    local cost = OFF * j.d + j.t * C[e] + dist[A[e]]
                    if not best or cost < best then best, node, way, pick = cost, A[e], j.d + j.t * L[e] + field.walk[A[e]], j end
                end
                if Bit(f, 4) and dist[B[e]] then
                    local cost = OFF * j.d + (1 - j.t) * C[e] + dist[B[e]]
                    if not best or cost < best then best, node, way, pick = cost, B[e], j.d + (1 - j.t) * L[e] + field.walk[B[e]], j end
                end
            end
            if not node then return Off() end
            -- samezone (M 16 Nov 2026, in Stranglethorn with the tablet 425
            -- yards off behind a ridge): inside one zone the straight line
            -- stays the way unless the net's way is much longer, which says
            -- something stands between.
            -- roadnet (M 16 Nov 2026, on Stranglethorn's road: "if I'm on
            -- the road, it obviously should let me follow the road"): not
            -- for a player standing on a road (a stretch the walking maps
            -- price as one): the road is followed.
            local onRoad = pick and pick.d <= ONROAD and L[pick.e] > 0 and C[pick.e] / L[pick.e] <= 0.9
            -- netsane (2.0.13, M 18 Nov 2026, off his hearthstone in
            -- Stormwind's Trade District with the arrow to Archbishop
            -- Benedictus in the Cathedral, 390 yards off: "it keeps telling
            -- me that this npc is 20k yards away and pointing me to the
            -- wrong direction"): the net's nearest stretch to a place can be
            -- one it only reaches the long way round the continent (inside
            -- a building, on another level). A way many times the straight
            -- line is no way round a ridge: the straight line it is.
            if way > straight * 6 + 600 then
                state.node, state.field = nil, nil
                return nil
            end
            if sameZone and not onRoad and way < straight * LONGER + 60 then
                state.node, state.field = nil, nil
                return nil
            end
            state.closest = Yards(px, py, X[node], Y[node])
        end
        -- In the place's own zone: to the way's last corner (zone borders do
        -- not run along the ridges), unless the place is right there.
        if here and here == there and straight < 80 then return Off(true) end
        -- The corners already reached are behind: one the player stands at,
        -- and one the player has gone by (cornerpast, M 16 Nov 2026, riding
        -- down the river into Stranglethorn: "the arrow is basically sending
        -- me back to Westfall" - a corner missed by more than a few yards
        -- stayed the aim): the player is on the stretch after it, nearer its
        -- far end than the corner is.
        local guard = 0
        while guard < 50 do
            local following = field.next[node]
            local fx, fy = tx, ty
            if following then fx, fy = X[following], Y[following] end
            local nx, ny = X[node], Y[node]
            local past = Yards(px, py, nx, ny) <= PASSED
            if not past and Yards(px, py, fx, fy) < Yards(nx, ny, fx, fy) then
                local dx, dy = fx - nx, fy - ny
                local len2 = dx * dx + dy * dy
                local t = 0
                if len2 > 0 then t = math.max(0, math.min(1, ((px - nx) * dx + (py - ny) * dy) / len2)) end
                past = t > 0 and Yards(px, py, nx + t * dx, ny + t * dy) <= BESIDE
            end
            if not past then break end
            if not following then return Off(true) end -- the last corner: straight to the place
            node, guard = following, guard + 1
            state.closest = Yards(px, py, X[node], Y[node])
        end
        state.on, state.node, state.field = true, node, field
        -- openmesh (2.0.13): across open ground (its points, net.mesh on)
        -- the arrow looks up to three points ahead, so it points along
        -- the walk and not at each point in turn.
        local far = node
        if net.mesh then
            for _ = 1, 3 do
                local following = field.next[far]
                if not (following and far >= net.mesh and following >= net.mesh) then break end
                far = following
            end
        end
        local okPull, pulled = pcall(PullAhead, net, field, far, px, py) -- pullahead (2.1.1)
        if okPull and pulled and field.walk[pulled] then far = pulled end
        if far ~= node then
            state.aim, state.rest = { X[far], Y[far] }, field.walk[far]
            return state.aim, state.rest
        end
        state.aim, state.rest = { X[node], Y[node] }, field.walk[node]
        return state.aim, state.rest
    end

    -- walkgrid (2.0.9, M 16 Nov 2026 in the Ruins of Zul'Kunda, the arrow to
    -- The Third Troll Legend 54 yards off behind a wall: "It's just sending
    -- me through walls"). Where a place's ground is known cell by cell
    -- (FDJ.WALKGRIDS in Data/WalkNet.lua: walls, ledges, water) and both the
    -- player and the place are on it, the arrow walks the cells: the
    -- cheapest way from the place to every cell is worked out once, and
    -- the arrow aims at the furthest cell of the player's way that can be
    -- walked to in a straight line (no wall or ledge between), so it leads
    -- round the walls and through the gaps. The place itself in a straight
    -- line: the arrow points at it as always.
    local DIRS = { { 1, 1, 0 }, { 2, -1, 0 }, { 4, 0, 1 }, { 8, 0, -1 }, { 16, 1, 1 }, { 32, 1, -1 }, { 64, -1, 1 }, { 128, -1, -1 } }
    local KIND_COST = { [1] = 1.0, [2] = 0.8, [3] = 1.3, [4] = 2.5, [5] = 1.0, [6] = 3.0 }
    local function HasBit(mask, bit) return math.floor(mask / bit) % 2 == 1 end
    local grids
    local function Grids()
        if grids then return grids end
        grids = {}
        for _, data in ipairs(FDJ.WALKGRIDS or {}) do
            local nx, ny = data.nx, data.ny
            local open, cost = {}, {}
            for i = 1, nx do
                local row, kinds = data.open[i] or "", data.kind[i] or ""
                for j = 1, ny do
                    local idx = (i - 1) * ny + j
                    open[idx] = tonumber(string.sub(row, 2 * j - 1, 2 * j), 16) or 0
                    cost[idx] = KIND_COST[tonumber(string.sub(kinds, j, j)) or 0]
                    if not cost[idx] then open[idx] = 0 end
                end
            end
            -- no step leads off the grid, or onto a cell that cannot be stood on
            for i = 1, nx do
                for j = 1, ny do
                    local idx = (i - 1) * ny + j
                    local mask = open[idx]
                    if mask ~= 0 then
                        for d = 1, 8 do
                            local dir = DIRS[d]
                            if math.floor(mask / dir[1]) % 2 == 1 then
                                local a, b = i + dir[2], j + dir[3]
                                if a < 1 or b < 1 or a > nx or b > ny or open[(a - 1) * ny + b] == 0 then
                                    mask = mask - dir[1]
                                elseif d > 4 then
                                    -- a slanting step past a wall's end (one of the two
                                    -- square ways round closed): walked square instead
                                    local viaX = HasBit(open[idx], dir[2] > 0 and 1 or 2) and HasBit(open[(a - 1) * ny + j] or 0, dir[3] > 0 and 4 or 8)
                                    local viaY = HasBit(open[idx], dir[3] > 0 and 4 or 8) and HasBit(open[(i - 1) * ny + b] or 0, dir[2] > 0 and 1 or 2)
                                    if viaX ~= viaY then mask = mask - dir[1] end
                                end
                            end
                        end
                        open[idx] = mask
                    end
                end
            end
            grids[#grids + 1] = { c = data.continent, x0 = data.x0, y0 = data.y0, cell = data.cell, nx = nx, ny = ny, open = open, cost = cost, fields = {} }
        end
        FDJ.WALKGRIDS = nil -- the strings are not needed again
        return grids
    end
    -- The cell under (x, y): its row, column (from 0); nil off the grid.
    local function CellAt(g, x, y)
        local i, j = math.floor((x - g.x0) / g.cell), math.floor((y - g.y0) / g.cell)
        if i < 0 or j < 0 or i >= g.nx or j >= g.ny then return nil end
        return i, j
    end
    -- A cell that can be stood on at (x, y): its own, else the nearest within three cells.
    local function Stand(g, x, y)
        local i, j = CellAt(g, x, y)
        if not i then return nil end
        if g.open[i * g.ny + j + 1] ~= 0 then return i * g.ny + j + 1 end
        local best, bestD
        for di = -3, 3 do
            for dj = -3, 3 do
                local a, b = i + di, j + dj
                if a >= 0 and b >= 0 and a < g.nx and b < g.ny and g.open[a * g.ny + b + 1] ~= 0 then
                    local d = Yards(x, y, g.x0 + (a + 0.5) * g.cell, g.y0 + (b + 0.5) * g.cell)
                    if not bestD or d < bestD then best, bestD = a * g.ny + b + 1, d end
                end
            end
        end
        return best
    end
    local function Centre(g, idx)
        local i = math.floor((idx - 1) / g.ny)
        local j = idx - 1 - i * g.ny
        return g.x0 + (i + 0.5) * g.cell, g.y0 + (j + 0.5) * g.cell
    end
    -- From the place's cell: the cost and the yards of the cheapest way to every cell that reaches it.
    local function GridField(g, goal)
        for i = 1, #g.fields do
            if g.fields[i].goal == goal then return g.fields[i] end
        end
        local ny, open, cost, cell = g.ny, g.open, g.cost, g.cell
        local dist, walk = { [goal] = 0 }, { [goal] = 0 }
        local heapCost, heapNode, size = { 0 }, { goal }, 1
        while size > 0 do
            local c, u = heapCost[1], heapNode[1]
            local lastCost, lastNode = heapCost[size], heapNode[size]
            heapCost[size], heapNode[size] = nil, nil
            size = size - 1
            if size > 0 then
                local i = 1
                while true do
                    local child = i * 2
                    if child > size then break end
                    if child < size and heapCost[child + 1] < heapCost[child] then child = child + 1 end
                    if heapCost[child] >= lastCost then break end
                    heapCost[i], heapNode[i] = heapCost[child], heapNode[child]
                    i = child
                end
                heapCost[i], heapNode[i] = lastCost, lastNode
            end
            if c <= dist[u] then
                for d = 1, 8 do
                    local dir = DIRS[d]
                    -- the step is walked towards the place: from v onto u (a hop
                    -- down a ledge goes one way only)
                    local v = u - dir[2] * ny - dir[3]
                    if HasBit(open[v] or 0, dir[1]) then
                        local len = (d > 4 and 1.41421356 or 1) * cell
                        local to = c + len * (cost[u] + (cost[v] or 1)) / 2
                        if not dist[v] or to < dist[v] then
                            dist[v], walk[v] = to, walk[u] + len
                            size = size + 1
                            local i = size
                            while i > 1 do
                                local parent = math.floor(i / 2)
                                if heapCost[parent] <= to then break end
                                heapCost[i], heapNode[i] = heapCost[parent], heapNode[parent]
                                i = parent
                            end
                            heapCost[i], heapNode[i] = to, v
                        end
                    end
                end
            end
        end
        local field = { goal = goal, dist = dist, walk = walk }
        if #g.fields >= 4 then table.remove(g.fields, 1) end
        g.fields[#g.fields + 1] = field
        return field
    end
    -- Can the straight line from (ax, ay) to (bx, by) be walked: every
    -- step from cell to cell along it open (a wall's end is not cut).
    local function Clear(g, ax, ay, bx, by)
        local i, j = CellAt(g, ax, ay)
        local ei, ej = CellAt(g, bx, by)
        if not i or not ei then return false end
        local ny, open, cell = g.ny, g.open, g.cell
        if open[i * ny + j + 1] == 0 then return false end
        -- cell by cell along the line (each crossing of a cell's edge is one step north, south, west or east)
        local dx, dy = bx - ax, by - ay
        local si, sj = dx > 0 and 1 or -1, dy > 0 and 1 or -1
        local huge = math.huge
        local tMaxX = dx ~= 0 and ((g.x0 + (i + (dx > 0 and 1 or 0)) * cell) - ax) / dx or huge
        local tMaxY = dy ~= 0 and ((g.y0 + (j + (dy > 0 and 1 or 0)) * cell) - ay) / dy or huge
        local tDX = dx ~= 0 and cell / math.abs(dx) or huge
        local tDY = dy ~= 0 and cell / math.abs(dy) or huge
        local guard = 0
        while (i ~= ei or j ~= ej) and guard < 400 do
            guard = guard + 1
            local mask = open[i * ny + j + 1]
            if tMaxX < tMaxY then
                if not HasBit(mask, si > 0 and 1 or 2) then return false end
                i, tMaxX = i + si, tMaxX + tDX
            else
                if not HasBit(mask, sj > 0 and 4 or 8) then return false end
                j, tMaxY = j + sj, tMaxY + tDY
            end
            if i < 0 or j < 0 or i >= g.nx or j >= ny then return false end
        end
        return i == ei and j == ej
    end
    -- -> handled (the player and the place are on one grid and a way is
    -- known), then the aim { x, y } and the yards from it on; no aim: the
    -- place itself is in a straight line.
    local function GridAim(memo, tx, ty, px, py, c)
        if not (Number(tx) and Number(ty) and Number(px) and Number(py)) then return false end
        local g
        for _, grid in ipairs(Grids()) do
            if grid.c == c and CellAt(grid, px, py) and CellAt(grid, tx, ty) then g = grid break end
        end
        if not g then memo.walkgrid = nil return false end
        local state = memo.walkgrid
        if state and state.g == g and Yards(state.tx, state.ty, tx, ty) < 1 and Yards(state.px, state.py, px, py) < 2 then
            return true, state.aim, state.rest
        end
        local goal, from = Stand(g, tx, ty), Stand(g, px, py)
        if not goal or not from then memo.walkgrid = nil return false end
        local field = GridField(g, goal)
        local dist = field.dist
        if not dist[from] then memo.walkgrid = nil return false end -- no way known from here
        state = { g = g, tx = tx, ty = ty, px = px, py = py }
        memo.walkgrid = state
        -- the player's way, cell by cell (downhill in cost), as far as 80 cells
        local ny, open = g.ny, g.open
        local way, at = {}, from
        for n = 1, 80 do
            if at == goal then break end
            local best, bestD
            local mask = open[at]
            for d = 1, 8 do
                local dir = DIRS[d]
                if HasBit(mask, dir[1]) then
                    local v = at + dir[2] * ny + dir[3]
                    if dist[v] and (not bestD or dist[v] < bestD) then best, bestD = v, dist[v] end
                end
            end
            if not best or bestD >= dist[at] then break end
            at = best
            way[n] = at
        end
        -- from where the player stands (the cell's middle when standing off the ground known)
        local sx, sy = px, py
        local si, sj = CellAt(g, px, py)
        if not si or si * ny + sj + 1 ~= from then sx, sy = Centre(g, from) end
        if at == goal and Clear(g, sx, sy, tx, ty) then return true, nil, nil end
        if at == goal then
            local gx, gy = Centre(g, goal)
            if Clear(g, sx, sy, gx, gy) then return true, nil, nil end
        end
        local aimCell
        for n = #way, 1, -1 do
            local x, y = Centre(g, way[n])
            if Clear(g, sx, sy, x, y) then aimCell = way[n] break end
        end
        aimCell = aimCell or way[1]
        if not aimCell then return true, nil, nil end
        local ax, ay = Centre(g, aimCell)
        state.aim, state.rest = { ax, ay }, field.walk[aimCell]
        return true, state.aim, state.rest
    end

    -- netwalk (2.1.1): the yards of the net's way from (px, py) to (tx, ty)
    -- on continent c, for weighing a flight against it (Systems/MapMarkers.lua,
    -- Plan); nil when the net does not know a way.
    function FDJ.WalkNetYards(px, py, tx, ty, c)
        if not (Number(tx) and Number(ty) and Number(px) and Number(py)) or not CONTINENT_MAP[c] then return nil end
        local ok, yards = pcall(function()
            local net = Net(c)
            if not net then return nil end
            local side = Side()
            local field = Field(net, c, side, tx, ty)
            if field.none then return nil end
            local joins = Joins(net, c, side, px, py, NEAR)
            if joins and #joins == 0 then joins = Joins(net, c, side, px, py, FAR) end
            local A, B, C, F, L, dist = net.A, net.B, net.C, net.F, net.L, field.dist
            local best, way
            for i = 1, joins and #joins or 0 do
                local j = joins[i]
                local e = j.e
                if Bit(F[e], 8) and dist[A[e]] then
                    local cost = OFF * j.d + j.t * C[e] + dist[A[e]]
                    if not best or cost < best then best, way = cost, j.d + j.t * L[e] + field.walk[A[e]] end
                end
                if Bit(F[e], 4) and dist[B[e]] then
                    local cost = OFF * j.d + (1 - j.t) * C[e] + dist[B[e]]
                    if not best or cost < best then best, way = cost, j.d + (1 - j.t) * L[e] + field.walk[B[e]] end
                end
            end
            return way
        end)
        return ok and yards or nil
    end

    -- -> { x, y } (world yards) and the yards from there on, or nil.
    -- gridOnly: a hand-made way's corner is the aim and it is near: only a
    -- place's cells may lead to it (round a wall), not the net.
    function FDJ.WalkNetAim(memo, tx, ty, px, py, continent, gridOnly)
        if type(memo) ~= "table" then return nil end
        local okGrid, handled, aim, rest = pcall(GridAim, memo, tx, ty, px, py, continent)
        if okGrid and handled then return aim, rest end
        if gridOnly then return nil end
        local ok, netAim, netRest = pcall(Aim, memo, tx, ty, px, py, continent)
        if ok and netAim then return netAim, netRest end
        return nil
    end
end
