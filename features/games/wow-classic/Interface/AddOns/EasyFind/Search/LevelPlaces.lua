local _, ns = ...






local LevelPlaces = {}
ns.LevelPlaces = LevelPlaces

local Utils, L = ns.Utils, ns.L
local ipairs = Utils.ipairs
local sformat, slower, tsort = Utils.sformat, Utils.slower, Utils.tsort


local PAST_DROPS = 3

local REQ_GAP = 5

local WORDS = { level = true, lvl = true }
WORDS[slower(_G["LEVEL"] or "level")] = true


function LevelPlaces.Query(text)
    if type(text) ~= "string" then return nil end
    local Caps = ns.Caps
    if not (Caps and (Caps.forever or Caps.era or Caps.tbc)) then return nil end
    local word, level = slower(text):match("^%s*(%S+)%s+(%d+)%s*$")
    level = word and WORDS[word] and tonumber(level)
    return level and level >= 1 and level <= 80 and level or nil
end


local dropLevels
local function DropLevels()
    if dropLevels then return dropLevels end
    dropLevels = {}
    local Gear = ns.Upgrades and ns.Upgrades.Gear
    for _, boss in ipairs(Gear and ns.STATIC_LOOT or {}) do
        local range = dropLevels[boss.inst] or {}
        dropLevels[boss.inst] = range
        for _, list in ipairs({ boss.items or {}, boss.heroic or {} }) do
            for _, itemID in ipairs(list) do
                local ilvl, req = Gear(itemID)
                if ilvl and req == 0 then req = ilvl - REQ_GAP end
                if req and req > 0 then
                    if not range.lo or req < range.lo then range.lo = req end
                    if not range.hi or req > range.hi then range.hi = req end
                end
            end
        end
    end
    return dropLevels
end

local function RangeText(lo, hi)
    if lo == hi then return sformat(_G["UNIT_LEVEL_TEMPLATE"] or L["CHAR_LEVEL_FMT"], lo) end
    return sformat(L["LEVEL_RANGE_FMT"], lo, hi)
end

local function RowLess(a, b)
    if a.fitLo ~= b.fitLo then return a.fitLo < b.fitLo end
    return a.name < b.name
end

local function Row(poi, lo, hi)
    local row = ns.MapSearch.UIRowOf(poi)
    row.fitLo, row.noPin, row.noLearn = lo, true, true
    row.matchNote = RangeText(lo, hi)
    return row
end


local function Zones(level)
    local MapSearch = ns.MapSearch
    local zones = MapSearch and MapSearch.BuildWorldZoneCache and MapSearch:BuildWorldZoneCache()
    local ranges = ns.ZONE_LEVELS
    if not (zones and ranges) then return nil end
    local out, seen = {}, {}
    for _, zone in ipairs(zones) do
        local range = ranges[zone.mapID]
        if range and not seen[zone.name] and range[1] <= level and level <= range[2] then
            seen[zone.name] = true
            out[#out + 1] = Row({ name = zone.name, category = "zone", isZone = true, zoneMapID = zone.mapID,
                                  zoneMapType = zone.mapType, icon = ns.ZONE_ICON, pathPrefix = zone.parentName },
                                range[1], range[2])
        end
    end
    tsort(out, RowLess)
    return out
end


local function Instances(level, wantRaid)
    local out, seen = {}, {}
    local levels = DropLevels()
    for _, e in ipairs(ns.FOREVER_INSTANCES or {}) do
        local range = levels[e.id]
        if not seen[e.id] and (e.raid or false) == wantRaid and range and range.lo
           and range.lo <= level and level <= range.hi + PAST_DROPS then
            seen[e.id] = true
            local name = GetRealZoneText and GetRealZoneText(e.id)
            local category = e.raid and "raid" or "dungeon"
            local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(e.m)
            out[#out + 1] = Row({ name = (name and name ~= "") and name or e.n, category = category, isZone = true,
                                  isDungeonEntrance = true, zoneMapID = e.m, entranceMapID = e.m, entranceX = e.x,
                                  entranceY = e.y, entranceCategory = category, pathPrefix = info and info.name },
                                range.lo, range.hi)
        end
    end
    tsort(out, RowLess)
    return out
end


function LevelPlaces.Lists(level)
    return Zones(level) or {}, Instances(level, false), Instances(level, true)
end

local entries = {}

local function SetEntry(n, data)
    local e = entries[n] or {}
    entries[n] = e
    e.name, e.depth, e.isPathNode, e.isMatch, e.isPinned, e.isFlat, e.data = data.name, 0, false, true, false, true, data
    e.isSectionHeader = false
end

local function SetHeader(n, name)
    local e = entries[n] or {}
    entries[n] = e
    e.name, e.depth, e.isPathNode, e.isMatch, e.isPinned, e.isFlat, e.data = name, 0, false, false, false, true, nil
    e.isSectionHeader = true
end

function LevelPlaces:Show(level)
    local zones, dungeons, raids = LevelPlaces.Lists(level)
    local sections = {
        { _G["ZONES"] or "Zones", zones },
        { _G["DUNGEONS"] or "Dungeons", dungeons },
        { _G["RAIDS"] or "Raids", raids },
    }
    local n = 0
    for _, section in ipairs(sections) do
        if #section[2] > 0 then
            n = n + 1
            SetHeader(n, section[1])
            for _, row in ipairs(section[2]) do
                n = n + 1
                SetEntry(n, row)
            end
        end
    end
    if n == 0 then
        n = 1
        SetEntry(1, { name = _G["BROWSE_NO_RESULTS"] or L["CHAR_NO_MATCH"], category = "Character", noPin = true,
                      noLearn = true, noMenu = true, lookupRow = true })
    end
    for i = n + 1, #entries do entries[i] = nil end
    ns.Results:ShowHierarchicalResults(entries)
end
