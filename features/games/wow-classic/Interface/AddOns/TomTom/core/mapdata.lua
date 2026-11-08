--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
--
--  All Rights Reserved
----------------------------------------------------------------------------]]

-- Map hierarchy and the zone name table used by /way.

local addonName, addon = ...
local TomTom = addon
local L = addon.L
local hbd = addon.hbd
addon.private = addon.private or {}
local private = addon.private

TomTom.CZWFromMapID = {}
local overrides = {
    [101] = {mapType = Enum.UIMapType.World}, -- Outland
    [125] = {mapType = Enum.UIMapType.Zone}, -- Dalaran
    [126] = {mapType = Enum.UIMapType.Micro},
    [195] = {suffix = "1"}, -- Kaja'mine
    [196] = {suffix = "2"}, -- Kaja'mine
    [197] = {suffix = "3"}, -- Kaja'mine
    [501] = {mapType = Enum.UIMapType.Zone}, -- Dalaran
    [502] = {mapType = Enum.UIMapType.Micro},
    [572] = {mapType = Enum.UIMapType.World}, -- Draenor
    [579] = {suffix = "1"}, -- Lunarfall Excavation
    [580] = {suffix = "2"}, -- Lunarfall Excavation
    [581] = {suffix = "3"}, -- Lunarfall Excavation
    [582] = {mapType = Enum.UIMapType.Zone}, -- Lunarfall
    [585] = {suffix = "1"}, -- Frostwall Mine
    [586] = {suffix = "2"}, -- Frostwall Mine
    [587] = {suffix = "3"}, -- Frostwall Mine
    [590] = {mapType = Enum.UIMapType.Zone}, -- Frostwall
    [625] = {mapType = Enum.UIMapType.Orphan}, -- Dalaran
    [626] = {mapType = Enum.UIMapType.Micro}, -- Dalaran
    [627] = {mapType = Enum.UIMapType.Zone},
    [628] = {mapType = Enum.UIMapType.Micro},
    [629] = {mapType = Enum.UIMapType.Micro},
    [943] = {suffix = FACTION_HORDE}, -- Arathi Highlands
    [1044] = {suffix = FACTION_ALLIANCE},
}

function TomTom:GetCZWFromMapID(m)
    local zone, continent, world, map
    local mapInfo = nil

    if not m then return nil, nil, nil; end

    -- Return the cached CZW
    if TomTom.CZWFromMapID[m] then
        return unpack(TomTom.CZWFromMapID[m])
    end

    map = m -- Save the original map
    repeat
        mapInfo = C_Map.GetMapInfo(m)
        if not mapInfo then
            -- No more parents, return what we have
            TomTom.CZWFromMapID[map] = {continent, zone, world}
            return continent, zone, world
        end
        local mapType = (overrides[m] and overrides[m].mapType) or mapInfo.mapType
        if mapType == Enum.UIMapType.Zone then
            -- Its a zone map
            zone = m
        elseif mapType == Enum.UIMapType.Continent then
            continent = m
        elseif (mapType == Enum.UIMapType.World) or (mapType == Enum.UIMapType.Cosmic) then
            world = m
            continent = continent or m -- Hack for one continent worlds
        end
        m = mapInfo.parentMapID
    until (m == 0)
    TomTom.CZWFromMapID[map] = {continent, zone, world}
    return continent, zone, world
end

TomTom.NameToMapId = {}
local NameToMapId = TomTom.NameToMapId


do
    -- Fetch the names of the zones
    for id in pairs(hbd.mapData) do
        local c,z,w = TomTom:GetCZWFromMapID(id)
        local mapType = (overrides[id] and overrides[id].mapType) or hbd.mapData[id].mapType
        if (mapType == Enum.UIMapType.Zone) or
           (mapType == Enum.UIMapType.Continent) or
           (mapType == Enum.UIMapType.Micro) then
            -- Record only Zone or Continent or Micro maps
            local name = hbd.mapData[id].name
            if (overrides[id] and overrides[id].suffix) then
                name = name .. " " .. overrides[id].suffix
            end
            -- What about some instances?  Do they have coords?  How to test for that case?
            if w then -- It must be in some world to be named and have coords
                if name and NameToMapId[name] then
                    if type(NameToMapId[name]) ~= "table" then
                        -- convert to table
                        NameToMapId[name] = {NameToMapId[name]}
                    end
                    table.insert(NameToMapId[name], id)
                else
                    NameToMapId[name] = id
                end
            end
        end
    end
    -- Handle any duplicates
    local newEntries = {}
    for name, mapID in pairs(NameToMapId) do
        if type(mapID) == "table" then
            NameToMapId[name] = nil
            for idx, mapId in pairs(mapID) do
                local parent = hbd.mapData[mapId].parent
                local parentName = (parent and (parent > 0) and hbd.mapData[parent].name)
                if parentName then
                    -- We rely on the implicit acending order of mapID's so the lowest one wins
                    if not newEntries[name .. ":" .. parentName] then
                        newEntries[name .. ":" .. parentName] = mapId
                    else
                        newEntries[name .. ":" .. tostring(mapId)] = mapId
                    end
                end
            end
        end
    end
    -- Add the de-duplicated entries
    for name, mapID in pairs(newEntries) do
        NameToMapId[name] = mapID
    end
end

-- A dungeon or micro map (a cave, a building, an instance floor) counts as
-- part of the zone above it.
local function ZoneOf(mapID)
    local data = hbd.mapData[mapID]
    while data and (data.mapType == Enum.UIMapType.Dungeon or data.mapType == Enum.UIMapType.Micro) do
        local parent = hbd.mapData[data.parent]
        if not parent or parent.mapType < Enum.UIMapType.Zone then
            break
        end
        mapID, data = data.parent, parent
    end
    return mapID
end

-- For the "Display waypoints from other zones" settings. When the player
-- map is not known, the waypoint counts as in the zone, so that no pin
-- goes away for lack of data.
function private.InPlayerZone(mapID)
    local playerMap = hbd:GetPlayerZone()
    if not playerMap or playerMap == 0 then
        return true
    end
    return ZoneOf(mapID) == ZoneOf(playerMap)
end
