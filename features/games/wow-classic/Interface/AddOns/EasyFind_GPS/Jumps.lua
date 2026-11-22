-- Jumping down: what lets this character land from any height, and so how
-- high a drop its walks may take. Spells, items and auras from the client's
-- data (feather fall aura on the spell); a reagent where the client asks one.
local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns or select(2, ...).tooOld then return end

local Jumps = {}
ns.GPSJumps = Jumps

local L = ns.L
local sformat, mfloor, mhuge = string.format, math.floor, math.huge
local issecret = _G.issecretvalue or function() return false end
local C_Spell, C_Item, C_Container = C_Spell, C_Item, C_Container

-- Slow fall, cast at the top: Slow Fall and Levitate (a Light Feather on
-- WoW Forever).
local SLOW_FALL_SPELLS = { 130, 1706 }
local FOREVER_REAGENT = { [130] = 17056, [1706] = 17056 }
-- Immunity, cast at the top and lasting the fall: Divine Shield, Ice Block.
local IMMUNE_SPELLS = { 642, 1020, 11958, 27619 }
-- Slow fall from an item: worn ones are used from their slot.
local SLOW_FALL_ITEMS = {
    { id = 260810, worn = true },    -- SAF-T Disposable Parachute
    { id = 10518, worn = true },     -- Parachute Cloak
    { id = 275729, worn = true },    -- Rusty Propeller Blade
    { id = 10684 },                  -- Colossal Parachute
    { id = 274616 },                 -- Aetherstill Spirits
}
-- What an auction house can sell to a character with none of the above.
Jumps.SHOP_ITEM = 260810
-- The shop tip shows when the item saves at least this many seconds.
local SHOP_MIN_SAVE = 60

local function Ready(start, duration)
    if issecret(start) or issecret(duration) then return false end
    return not (start and duration and start > 0 and duration > 1.5)
end

local function SpellReady(id)
    if not (IsPlayerSpell and IsPlayerSpell(id)) then return false end
    local info = C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(id)
    return not info or Ready(info.startTime, info.duration)
end

local function SpellName(id)
    return (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or tostring(id)
end

local function ItemName(id)
    return (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or nil
end

-- The way this character lands safely now: { name, kind = "spell" | "item" |
-- "immune", id, wear = true when the item has to go on first }, or nil.
function Jumps.Helper()
    for _, id in ipairs(SLOW_FALL_SPELLS) do
        local reagent = ns.Caps and ns.Caps.forever and FOREVER_REAGENT[id]
        if SpellReady(id) and (not reagent or (C_Item.GetItemCount(reagent) or 0) > 0) then
            return { kind = "spell", id = id, name = SpellName(id) }
        end
    end
    for _, item in ipairs(SLOW_FALL_ITEMS) do
        if C_Item and (C_Item.GetItemCount(item.id) or 0) > 0 then
            local start, duration = C_Container.GetItemCooldown(item.id)
            if Ready(start, duration) then
                local worn = C_Item.IsEquippedItem and C_Item.IsEquippedItem(item.id)
                return { kind = "item", id = item.id, name = ItemName(item.id) or tostring(item.id),
                         wear = item.worn and not worn or nil }
            end
        end
    end
    for _, id in ipairs(IMMUNE_SPELLS) do
        if SpellReady(id) then return { kind = "immune", id = id, name = SpellName(id) } end
    end
    return nil
end

-- The highest drop this character's walks take on continent ci: any with a
-- way to land safely, else what a full-health character survives, else the
-- safe height (nil).
function Jumps.Limit(ci)
    local Nav = ns.GPSNav
    if not (Nav and Nav.DropHeights) then return nil end
    local safe, survive = Nav.DropHeights(ci or 0)
    if not safe then return nil end
    if Jumps.Helper() then return mhuge end
    return survive
end

-- The name of the shop item, for the tip.
function Jumps.ShopItemName()
    return ItemName(Jumps.SHOP_ITEM) or L["GPS_PARACHUTE"]
end

-- Whether a route's walks jump down a ledge that costs health.
function Jumps.Any(steps)
    for i = 1, #steps do
        if steps[i].jumps then return true end
    end
    return false
end

-- Where a jump is, as the map names it: the nearest of its zone's areas,
-- else a landmark beside it (a city's districts are no areas), else the zone.
local PLACE_AREA_REACH, PLACE_MARK_REACH = 400, 150
Jumps.placeOf = setmetatable({}, { __mode = "k" })
local LANDMARKS = { bank = true, auctionhouse = true, innkeeper = true, flightmaster = true }
function Jumps.PlaceAt(ci, x, y)
    local G, R = ns.GPS, ns.GPSRoute
    local mapID, zoneName
    if G and G.ZoneAt then mapID, zoneName = G.ZoneAt(ci, x, y) end
    if not (mapID and R and R.WorldPos) then return zoneName end
    local function Dist2(m, mx, my)
        local pci, px, py = R.WorldPos(m, mx, my)
        return pci == ci and (px - x) ^ 2 + (py - y) ^ 2 or nil
    end
    local areas = ns.GPSData and ns.GPSData.areas and ns.GPSData.areas[mapID]
    local best, bestD = nil, PLACE_AREA_REACH ^ 2
    for i = 1, areas and #areas or 0, 3 do
        local d = Dist2(mapID, areas[i + 1], areas[i + 2])
        if d and d < bestD then best, bestD = areas[i], d end
    end
    local name = best and C_Map.GetAreaInfo and C_Map.GetAreaInfo(best)
    if name and name ~= "" then return name end
    bestD, name = PLACE_MARK_REACH ^ 2, nil
    for _, loc in ipairs(ns.STATIC_LOCATIONS and ns.STATIC_LOCATIONS[mapID] or {}) do
        local d = LANDMARKS[loc.category] and Dist2(mapID, loc.x, loc.y)
        if d and d < bestD then name, bestD = loc.name, d end
    end
    return name or zoneName
end

-- A walk's highest ledge: the jump, its height, what a full-health
-- character survives there, and the continent.
local function Drop(step)
    local jumps = step and step.jumps
    if not jumps then return nil end
    local top = jumps[1]
    for i = 2, #jumps do
        if jumps[i].h > top.h then top = jumps[i] end
    end
    local Nav = ns.GPSNav
    local ci = step.arrive and step.arrive.ci or 0
    local survive
    if Nav and Nav.DropHeights then survive = select(2, Nav.DropHeights(ci)) end
    return top, top.h, survive, ci
end

-- What lands this character at a walk's ledge, where the drop is past
-- what full health survives; nil where a jump at full health does.
function Jumps.StepHelper(step)
    local _, high, survive = Drop(step)
    if not high then return nil end
    return (not survive or high > survive) and Jumps.Helper() or nil
end

-- What a step's button casts: a teleport's spell or item, else what lands
-- the character at the step's ledge. spellID, itemID, toy.
function Jumps.StepCast(step)
    if not step then return nil end
    if step.kind == "teleport" then return step.spellID, step.itemID, step.toy end
    local helper = Jumps.StepHelper(step)
    if not helper then return nil end
    if helper.kind == "item" then return nil, helper.id end
    return helper.id
end

function Jumps.HasCast(step)
    local spellID, itemID = Jumps.StepCast(step)
    return (spellID or itemID) ~= nil
end

-- A walk that jumps down a ledge says where, and with what lands the
-- character safely when the drop is past what a fall leaves; near the
-- place the highest one is (the map marks each).
function Jumps.StepText(step)
    local top, high, survive, ci = Drop(step)
    if not top then return nil end
    local jumps = step.jumps
    -- By its jump list: a walk split by zone copies its other fields.
    local place = Jumps.placeOf[jumps]
    if place == nil then
        place = top.x and Jumps.PlaceAt(ci, top.x, top.y) or false
        Jumps.placeOf[jumps] = place
    end
    place = place or nil
    local yd = mfloor(high + 0.5)
    local helper = (not survive or high > survive) and Jumps.Helper()
    if helper then
        local key = helper.wear and "GPS_JUMP_WEAR" or "GPS_JUMP_HELPER"
        if place then return sformat(L[key .. "_AT_FMT"], helper.name, place, yd) end
        return sformat(L[key .. "_FMT"], helper.name, yd)
    end
    if place then return sformat(L["GPS_JUMP_AT_FMT"], place, yd) end
    return sformat(L["GPS_JUMP_FMT"], yd)
end

-- With nothing to land safely from any height: what the shop item would
-- save on this route, when that is a minute or more, as { save, name }.
-- A trip of several stops is not tried again.
function Jumps.ShopTip(route)
    local Nav, G = ns.GPSNav, ns.GPS
    local ci = route.from and route.from.ci or 0
    if not (Nav and Nav.DropHeights and Nav.DropHeights(ci) and G and route.total and route.dest) then return nil end
    if (route.stops and #route.stops > 1) or Jumps.Helper() then return nil end
    local _, total = G:BuildRoute(route.dest, nil, route.wayAvoid, true, nil, nil, mhuge)
    if not (total and route.total - total >= SHOP_MIN_SAVE) then return nil end
    return { save = route.total - total, name = Jumps.ShopItemName() }
end
