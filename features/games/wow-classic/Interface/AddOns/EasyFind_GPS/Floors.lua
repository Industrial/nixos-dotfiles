-- EasyFind GPS: which floor a point stands on where a city's floors stack
-- (Undercity's upper ring over its auction house; the client tells no
-- height). A destination takes the height of the spawn beside it, the
-- player the floor named like the sub-zone the client shows there. In a
-- room elsewhere (an inn's upper floor) only a spawn's floor is known.
-- dev/tools/navmesh/city_floors.py writes the data (Floors_<Client>.lua).
local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns or select(2, ...).tooOld then return end

local Floors = {}
ns.GPSFloors = Floors

local mabs, mfloor, tonumber, ssub = math.abs, math.floor, tonumber, string.sub
local GetSubZoneText, GetZoneText, GetLocale = GetSubZoneText, GetZoneText, GetLocale

local ANCHOR_YARDS = 6        -- a spawn this close gives a point its height
local PLAYER_YARDS = 3        -- a point this close to the player is the player's
local LEVEL_YARDS = 4         -- floors farther apart in height are other levels
local ZONE_NAME = 255         -- a piece with no name: the sub-zone reads as the zone
local Z_WEIGHT = 200          -- Locate's score a yard off the wanted height costs
local NAME_WEIGHT = 3000      -- and the floor named like the player's sub-zone
local NAME_CELLS = 5          -- how far off a floor named like the sub-zone is looked for
local TOLD_KEPT = 256

local tiles = setmetatable({}, { __mode = "v" })   -- decoded, by continent and tile key
local roomTiles = setmetatable({}, { __mode = "v" })
local LEVEL_WORDS = { "upper", "lower", "inside" }
local want = {}                                    -- Want's answer, one at a time
-- Journeys' ends: one with no spawn's height known takes the indoor floor
-- where one stacks under open ground (a cave under its hill).
local goals, goalsN = {}, 0
-- What the client named a spot while the player stood there, kept once he
-- has left: a trip's start keeps its floor (gone, the highest was taken).
local told, toldN = {}, 0

local function Data(ci) return ns.GPSFloorData and ns.GPSFloorData[ci] end

local function City(data, x, y)
    for _, c in ipairs(data.cities) do
        local b = c.box
        if x >= b[1] and x <= b[3] and y >= b[2] and y <= b[4] then return c end
    end
end

-- A tile's stacked cells: cells[cell] its record's place in flat, where
-- flat[at] is the floor count, then height and name per floor.
local function Tile(ci, key)
    local id = ci * 65536 + key
    local t = tiles[id]
    if t then return t end
    local data = Data(ci)
    local s = data and data.cells[key]
    if not s then return nil end
    t = { cells = {}, flat = {} }
    local flat, n, i = t.flat, 0, 1
    while i <= #s do
        local cell, count = tonumber(ssub(s, i, i + 3), 16), tonumber(ssub(s, i + 4, i + 4), 16)
        i = i + 5
        t.cells[cell] = n + 1
        flat[n + 1] = count
        n = n + 1
        for _ = 1, count do
            flat[n + 1], flat[n + 2] = tonumber(ssub(s, i, i + 2), 16) - 2048, tonumber(ssub(s, i + 3, i + 4), 16)
            n, i = n + 2, i + 5
        end
    end
    tiles[id] = t
    return t
end

-- The record of a cell's floors (lowest first), or nil where none stack.
local function Cell(ci, key, cell)
    local t = Tile(ci, key)
    local at = t and t.cells[cell]
    if at then return t.flat, at end
end
Floors.Cell = Cell

-- Height of the rank-th floor (from 0) of a stacked cell, or nil.
function Floors.Height(ci, key, cell, rank)
    local flat, at = Cell(ci, key, cell)
    if flat and rank < flat[at] then return flat[at + 1 + 2 * rank] end
end

local function Named(city, k, sub, zone)
    local locale = GetLocale and GetLocale() or "enUS"
    if k == ZONE_NAME then
        -- A floor named only by its zone: the client must call the place
        -- the city (the hill over a cave shows the land's zone instead),
        -- as the sub-zone, or as the zone with no sub-zone shown.
        local zones = city.zone and (city.zone[locale] or city.zone.enUS)
        if not zones then return sub == "" or sub == zone end
        for i = 1, #zones do
            if zones[i] == sub or (sub == "" and zones[i] == zone) then return true end
        end
        return false
    end
    if k == 0 then return false end
    local names = city.names[locale] or city.names.enUS
    return names[k] == sub
end

local function NearestAnchor(data, x, y)
    local a, best, bz = data.anchors, ANCHOR_YARDS * ANCHOR_YARDS, nil
    for i = 1, #a, 3 do
        local dx, dy = a[i] - x, a[i + 1] - y
        local d = dx * dx + dy * dy
        if d <= best then best, bz = d, a[i + 2] end
    end
    return bz
end

-- The player's spot, read once a frame: a plan asks for every walk's ends.
local spotAt, spotCi, spotX, spotY
local function PlayerSpot()
    local now = GetTime and GetTime() or 0
    if now ~= spotAt then
        local g = ns.GPS
        spotAt = now
        spotCi, spotX, spotY = nil, nil, nil
        if g and g.PlayerWorldPos then spotCi, spotX, spotY = g.PlayerWorldPos() end
    end
    return spotCi, spotX, spotY
end

-- The tile key and cell of a world point on the walking grid.
local function KeyCell(ci, x, y)
    local grid = ns.GPSNavData and ns.GPSNavData[ci]
    local Nav = ns.GPSNav
    if not (grid and Nav and Nav.TileOf) then return nil end
    local key, sx, sy = Nav.TileOf(x, y)
    return key, mfloor((x - sx) / grid.cell) * grid.cells + mfloor((y - sy) / grid.cell)
end

-- Height of the nearest floor named like the sub-zone: the client's names
-- and the model's pieces part a few yards apart.
local function NamedHeight(ci, city, x, y, sub, zone)
    local grid = ns.GPSNavData and ns.GPSNavData[ci]
    if not grid then return nil end
    local land
    for ring = 0, NAME_CELLS do
        for dx = -ring, ring do
            for dy = -ring, ring do
                if mabs(dx) == ring or mabs(dy) == ring then
                    local key, cell = KeyCell(ci, x + dx * grid.cell, y + dy * grid.cell)
                    local flat, at
                    if key then flat, at = Cell(ci, key, cell) end
                    for r = 0, flat and flat[at] - 1 or -1 do
                        local name = flat[at + 2 + 2 * r]
                        if Named(city, name, sub, zone) then return flat[at + 1 + 2 * r] end
                        -- No piece of the city under this floor: the land's.
                        if name == 0 and land == nil then land = flat[at + 1 + 2 * r] end
                    end
                end
            end
        end
    end
    -- The client names no piece of the city where the player stands: he
    -- is on the land over it (the hill over a cave, Tirisfal over the sewers).
    return land
end

-- A tile's room spawns, flat: x, y, height and level each.
local function RoomTile(ci, key, sx, sy)
    local id = ci * 65536 + key
    local r = roomTiles[id]
    if r then return r end
    local data = Data(ci)
    local s = data and data.rooms and data.rooms[key]
    if not s then return nil end
    r = {}
    for i = 1, #s, 13 do
        local n = #r
        r[n + 1] = sx + tonumber(ssub(s, i, i + 3), 16) / 10
        r[n + 2] = sy + tonumber(ssub(s, i + 4, i + 7), 16) / 10
        r[n + 3] = tonumber(ssub(s, i + 8, i + 11), 16) / 10 - 2048
        r[n + 4] = tonumber(ssub(s, i + 12, i + 12), 16)
    end
    roomTiles[id] = r
    return r
end

-- The height and level of the room spawn beside (x, y), or nil.
local function RoomSpawn(ci, x, y)
    local Nav = ns.GPSNav
    if not (Nav and Nav.TileOf) then return nil end
    local key, sx, sy = Nav.TileOf(x, y)
    local r = RoomTile(ci, key, sx, sy)
    if not r then return nil end
    local best, bz, bl = ANCHOR_YARDS * ANCHOR_YARDS, nil, nil
    for i = 1, #r, 4 do
        local d = (r[i] - x) ^ 2 + (r[i + 1] - y) ^ 2
        if d <= best then best, bz, bl = d, r[i + 2], r[i + 3] end
    end
    return bz, bl
end

-- "upper" or "lower": a spawn's floor in a room above or below the ground
-- outside; "inside" indoors under open ground; nil elsewhere or unknown.
function Floors.Level(ci, x, y)
    local _, level = RoomSpawn(ci, x, y)
    return LEVEL_WORDS[level]
end

local function SpotKey(ci, x, y)
    return (ci * 400000 + mfloor(x * 10 + 0.5) + 200000) * 400000 + mfloor(y * 10 + 0.5) + 200000
end

-- The floor a planned walk stood on at a spot it was cut at (the mouth
-- of Undercity's sewers, where one step ends and the next begins), by its
-- height: a walk searched to or from that spot again takes the same
-- floor. Without it the spot was the open ground over the sewers, and the
-- walk to it ran out through the whole tunnel and back over the top, 783
-- yd for 110 (2026-11-19).
local walked = {}
function Floors.Walked(ci, x, y, z)
    walked[SpotKey(ci, x, y)] = z
end

function Floors.ForgetWalked()
    walked = {}
end

-- (x, y) is where a journey ends.
function Floors.Goal(ci, x, y)
    local k = SpotKey(ci, x, y)
    if goals[k] then return end
    if goalsN >= TOLD_KEPT then goals, goalsN = {}, 0 end
    goals[k], goalsN = true, goalsN + 1
end

-- What picks (x, y)'s floor in a stacked city: the player's sub-zone at
-- the player's spot (unless spawnOnly), what it was there once he left,
-- else the height a planned walk stood at there (Floors.Walked), else
-- that of the spawn beside it; nil outside. The answer is reused: read
-- it before the next call.
function Floors.Want(ci, x, y, spawnOnly)
    local data = Data(ci)
    local city = data and City(data, x, y)
    local pci, px, py
    if not spawnOnly then pci, px, py = PlayerSpot() end
    if not city then
        -- A room names no floor: the player's own is not known.
        if pci == ci and px and (px - x) ^ 2 + (py - y) ^ 2 <= PLAYER_YARDS * PLAYER_YARDS then return nil end
        local z = data and (RoomSpawn(ci, x, y) or walked[SpotKey(ci, x, y)])
        if z then
            want.city, want.sub, want.z, want.inside = nil, nil, z, nil
            return want
        end
        if not goals[SpotKey(ci, x, y)] then return nil end
        want.city, want.sub, want.z, want.inside = nil, nil, nil, true
        return want
    end
    if pci == ci and px and (px - x) ^ 2 + (py - y) ^ 2 <= PLAYER_YARDS * PLAYER_YARDS and GetSubZoneText then
        local sub, zone = GetSubZoneText() or "", GetZoneText and GetZoneText() or ""
        local k = SpotKey(ci, x, y)
        local t = told[k]
        if not (t and t.sub == sub and t.zone == zone) then
            if not t then
                if toldN >= TOLD_KEPT then told, toldN = {}, 0 end
                toldN = toldN + 1
            end
            t = { city = city, sub = sub, zone = zone, z = NamedHeight(ci, city, x, y, sub, zone) }
            told[k] = t
        end
        return t
    end
    if not spawnOnly then
        local t = told[SpotKey(ci, x, y)]
        if t then return t end
    end
    want.city, want.sub, want.z, want.inside = city, nil, walked[SpotKey(ci, x, y)] or NearestAnchor(data, x, y), nil
    if want.z then return want end
    return nil
end

-- Locate's score for the rank-th floor of a cell under want: higher for
-- the wanted name, else the wanted height; 0 where the cell does not stack.
function Floors.Score(ci, key, cell, rank, w)
    local flat, at = Cell(ci, key, cell)
    if not (flat and rank < flat[at]) then return 0 end
    local h, k = flat[at + 1 + 2 * rank], flat[at + 2 + 2 * rank]
    if w.sub and Named(w.city, k, w.sub, w.zone) then return NAME_WEIGHT end
    return w.z and -mabs(h - w.z) * Z_WEIGHT or 0
end

-- True unless a floor of a stacked cell lies at another level than want.
function Floors.OnLevel(ci, key, cell, rank, w)
    if not (w and w.z) or w.sub then return true end
    local flat, at = Cell(ci, key, cell)
    if not (flat and rank < flat[at]) then return true end
    return mabs(flat[at + 1 + 2 * rank] - w.z) <= LEVEL_YARDS
end

-- The city's name for the rank-th floor of a stacked cell at (x, y), in
-- English and in the client's language (Undercity's "Sewers"), or nil.
function Floors.LevelName(ci, key, cell, rank, x, y)
    local flat, at = Cell(ci, key, cell)
    if not (flat and rank >= 0 and rank < flat[at]) then return nil end
    local k = flat[at + 2 + 2 * rank]
    if k == 0 or k == ZONE_NAME then return nil end
    local data = Data(ci)
    local city = data and City(data, x, y)
    if not city then return nil end
    local locale = GetLocale and GetLocale() or "enUS"
    return city.names.enUS[k], (city.names[locale] or city.names.enUS)[k]
end

-- A walk's ends as a cache key's tail: walks between the same spots on
-- other floors are other walks.
function Floors.Tag(ci, x, y)
    local w = Floors.Want(ci, x, y)
    if not w then return "" end
    if w.sub then return "s" .. w.sub end
    if w.inside then return "i" end
    return "z" .. mfloor(w.z + 0.5)
end

-- False when the player stands at another level than the spot (tx, ty):
-- the spot's floor (its spawn's height) is not the one the client names
-- the player's sub-zone. True wherever that cannot be told.
function Floors.SameLevel(ci, tx, ty)
    local w = Floors.Want(ci, tx, ty, true)
    local tz, city = w and w.z, w and w.city
    if not tz then return true end
    local key, cell = KeyCell(ci, tx, ty)
    if not key then return true end
    local flat, at = Cell(ci, key, cell)
    if not flat then return true end
    local name, gap = 0, LEVEL_YARDS
    for r = 0, flat[at] - 1 do
        local d = mabs(flat[at + 1 + 2 * r] - tz)
        if d <= gap then name, gap = flat[at + 2 + 2 * r], d end
    end
    if name == 0 or not GetSubZoneText then return true end
    return Named(city, name, GetSubZoneText() or "", GetZoneText and GetZoneText() or "")
end
