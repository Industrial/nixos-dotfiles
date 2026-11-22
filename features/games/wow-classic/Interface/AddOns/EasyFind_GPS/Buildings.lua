-- EasyFind GPS: buildings the walking grid cannot enter.
--
-- Stormwind's Wizard's Sanctum: its portal hall is reached up the stairs
-- round the Mage Tower, a teleport at the top of the tower's inner stairs,
-- then a corridor the map files hold no floor for (measured 2026-10-26).
-- A route to a portal there goes to the stairs and says to enter; one from
-- there says to leave. hall: the outline round every portal and landing
-- there, clear of the tower, as world x, y pairs; inside: a spot on the
-- hall's floor at its mouth; stairs: their foot (measured).
local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns then return end
if ns.Caps and ns.Caps.forever then return end
if not ns.GPSData then return end

local SANCTUM = 10523   -- AreaTable: Wizard's Sanctum, in Stormwind City
local stairs = { m = 84, x = 0.4938, y = 0.8819, ci = 0, wx = -9017.4, wy = 864.9 }
local inside = { m = 84, x = 0.4716, y = 0.8925, ci = 0, wx = -9030.1, wy = 903.3 }

local data = ns.GPSData
data.buildings = data.buildings or {}
data.edges = data.edges or {}
table.insert(data.buildings, { area = SANCTUM, ci = 0,
    hall = { -9110, 870, -9110, 1020, -8980, 1020, -8980, 935, -9022, 893, -9045, 870 } })
table.insert(data.edges, { kind = "enter", n = "Wizard's Sanctum", area = SANCTUM, textKey = "GPS_STEP_ENTER_SANCTUM_FMT",
    from = stairs, to = inside, sec = 25, faction = "Alliance" })
table.insert(data.edges, { kind = "leave", n = "Wizard's Sanctum", area = SANCTUM, textKey = "GPS_STEP_LEAVE_SANCTUM_FMT",
    from = inside, to = stairs, sec = 25, faction = "Alliance" })
