local _, ns = ...

local MapSearch = ns.MapSearch
local Utils = ns.Utils
local Search = ns.MapSearchSearch
local L = ns.L

local pairs, ipairs = Utils.pairs, Utils.ipairs
local tinsert, tsort, tremove = Utils.tinsert, Utils.tsort, Utils.tremove
local slower = Utils.slower
local mmin, mmax = Utils.mmin, Utils.mmax
local wipe = wipe

local GetBestMapForUnit = C_Map.GetBestMapForUnit

local GetCategoryIcon = Search.GetCategoryIcon
local GetMapPinKey = Search.GetMapPinKey
local FlightPathsEnabledAnywhere = Search.FlightPathsEnabledAnywhere
local WipeScratchTables = Search.WipeScratchTables
local GetNameLower = Search.GetNameLower
local PreparePOI = Search.PreparePOI
local POICouldMatch = Search.POICouldMatch
local BuildEntranceLookup = Search.BuildEntranceLookup
local EnrichZoneWithEntrance = Search.EnrichZoneWithEntrance
local AppendLocalSearchSources = Search.AppendLocalSearchSources
local AppendWorldStaticLocations = Search.AppendWorldStaticLocations
local AppendZoneSearchResults = Search.AppendZoneSearchResults
local AppendGlobalInstanceSearchSources = Search.AppendGlobalInstanceSearchSources
local AppendAlwaysFindableLocations = Search.AppendAlwaysFindableLocations
local AppendSubzones = Search.AppendSubzones
local ReleaseGlobalMapCaches = Search.ReleaseGlobalMapCaches
local CollectMapGarbage = Search.CollectMapGarbage

local reuseAllPOIs = Search.reuseAllPOIs
local reuseZoneNames = Search.reuseZoneNames
local reuseExistingNames = Search.reuseExistingNames
local reuseFilteredResults = Search.reuseFilteredResults
local reusePinnedKeys = Search.reusePinnedKeys
local reusePinned = Search.reusePinned
local reuseFiltered = Search.reuseFiltered
local reuseSearchResults = Search.reuseSearchResults
local reuseSearchSeen = Search.reuseSearchSeen
local reuseSearchDuplicates = Search.reuseSearchDuplicates
local reuseUISearchPOIs = Search.reuseUISearchPOIs
local reuseUISearchExistingNames = Search.reuseUISearchExistingNames
local reuseUISearchZoneNames = Search.reuseUISearchZoneNames
local reuseUISearchFiltered = Search.reuseUISearchFiltered
local reuseUISearchResults = Search.reuseUISearchResults
local reuseUISearchResultData = Search.reuseUISearchResultData
local reuseFreshRows = Search.reuseFreshRows
local reuseUIFreshRows = Search.reuseUIFreshRows
local reuseUIScored = Search.reuseUIScored
local reuseUICategoryRows = Search.reuseUICategoryRows
local reuseUICategoryData = Search.reuseUICategoryData
local reuseUIHereEntrances = {}
local UI_MAP_RESULT_CAP = Search.UI_MAP_RESULT_CAP

local function RequestUISearchGlobalInstances(self)
    if not self.RequestGlobalInstanceCache then return end
    if Search.uiGlobalInstanceRefreshPending then
        self:RequestGlobalInstanceCache()
        return
    end

    Search.uiGlobalInstanceRefreshPending = true
    self:RequestGlobalInstanceCache(function(ready)
        Search.uiGlobalInstanceRefreshPending = nil
        if ready and ns.MapSearch.ResetSearchPoisCache then ns.MapSearch.ResetSearchPoisCache() end
        if ready and ns.Search and ns.Search.RefreshActiveSearch then
            ns.Search:RefreshActiveSearch()
        end
    end)
end



local function ProviderSpots(p, d)
    local ok, list = pcall(p.places, d)
    if not (ok and type(list) == "table") then return nil end
    local spots
    for i = 1, #list do
        local s = list[i]
        if type(s) == "table" and s.mapID and s.x and s.y then
            local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(s.mapID)
            spots = spots or {}
            spots[#spots + 1] = { name = d.name, category = p.category, icon = s.icon or d.icon, providerRow = d,
                mapID = s.mapID, coordMapID = s.mapID, x = s.x, y = s.y, step = s.step, destName = s.name,
                zoneName = info and info.name or nil }
        end
    end
    return spots
end
MapSearch.ProviderSpots = ProviderSpots

local function AnySpotOn(spots, mapID)
    for i = 1, #spots do
        if spots[i].coordMapID == mapID then return true end
    end
    return false
end







local providerPOIs = setmetatable({}, { __mode = "k" })
local function AppendProviderRows(fresh, query, onlyMap)
    local Extensions, data = ns.Extensions, ns.Database and ns.Database.uiSearchData
    if not (Extensions and Extensions.Providers and data and query and #query >= 2) then return end
    local wanted
    for _, p in pairs(Extensions.Providers.byKey) do
        if p.place or p.places then
            wanted = wanted or {}
            wanted[p.category] = p
        end
    end
    if not wanted then return end
    for i = 1, #data do
        local d = data[i]
        local p = d.category and wanted[d.category]
        if p and d.name then
            local poi = providerPOIs[d]
            if not poi then
                poi = { category = p.category, providerRow = d, placeOf = p.place }
                if p.places then poi.spots = ProviderSpots(p, d) end
                providerPOIs[d] = poi
            end
            local here = not onlyMap or d.mapID == onlyMap
            if onlyMap and poi.spots then here = AnySpotOn(poi.spots, onlyMap) end
            if here then
                if poi.name ~= d.name then poi.name, poi.nameLower, poi.nameNorm, poi.searchMask = d.name, nil, nil, nil end
                if poi.keywords ~= d.keywords then poi.keywords, poi.kwLower, poi.searchMask = d.keywords, nil, nil end
                poi.icon, poi.matchNote, poi.allInstances = d.icon, p.label, nil
                fresh[#fresh + 1] = poi
            end
        end
    end
end




function MapSearch.ResolvePlace(data)
    if not (data and data.placeOf) then return data end
    local now = GetTime()
    if data.placedAt and now - data.placedAt < 5 then return data end
    data.placedAt = now
    local ok, place = pcall(data.placeOf, data.providerRow)
    if ok and type(place) == "table" and place.mapID and place.x and place.y then
        data.mapID, data.coordMapID, data.x, data.y = place.mapID, place.mapID, place.x, place.y
        data.step, data.destName = place.step, place.name
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(place.mapID)
        data.zoneName = info and info.name or nil
    else
        data.mapID, data.coordMapID, data.x, data.y, data.step, data.destName = nil, nil, nil, nil, nil, nil
    end
    return data
end






function MapSearch:BuildResults(text, isGlobal, skipPins)
    local savedGlobalFlag = Search.isGlobalSearch
    Search.isGlobalSearch = isGlobal and true or false





    local zoneMatches = self:SearchZones(text)

    wipe(reuseAllPOIs)
    wipe(reuseZoneNames)
    wipe(reuseFreshRows)
    local allPOIs = reuseAllPOIs
    local zoneNames = reuseZoneNames


    local fresh = reuseFreshRows

    local groupedZones = self:GroupZonesByParent(zoneMatches)
    AppendZoneSearchResults(fresh, zoneNames, groupedZones)







    if isGlobal then
        AppendGlobalInstanceSearchSources(self, allPOIs, zoneNames, fresh)
        AppendAlwaysFindableLocations(self, allPOIs, zoneNames, WorldMapFrame and WorldMapFrame:GetMapID())
        AppendSubzones(self, allPOIs, zoneNames, WorldMapFrame and WorldMapFrame:GetMapID(), text)
        if self.AppendNpcRows then self.AppendNpcRows(fresh, zoneNames, text) end
        AppendProviderRows(fresh, text, nil)

        if FlightPathsEnabledAnywhere() then
            local allFMs = self:ScanAllFlightMasters()
            for i = 1, #allFMs do
                local fm = allFMs[i]
                fm.score = nil
                fm.duplicateKey = nil
                fm.allInstances = nil
                if not zoneNames[GetNameLower(fm)] then
                    allPOIs[#allPOIs + 1] = fm
                end
            end
        end
    else
        wipe(reuseExistingNames)
        local existingNames = reuseExistingNames
        local dungeonEntrances = AppendLocalSearchSources(self, allPOIs, existingNames, zoneNames, nil, false)
        if self.AppendNpcRows then
            self.AppendNpcRows(fresh, existingNames, text, WorldMapFrame and WorldMapFrame:GetMapID())
        end
        AppendProviderRows(fresh, text, WorldMapFrame and WorldMapFrame:GetMapID())

        local entranceLookup = BuildEntranceLookup(dungeonEntrances)
        for _, poi in ipairs(fresh) do
            if poi.isZone and poi.zoneMapID then
                local entrance = entranceLookup[GetNameLower(poi)]
                if entrance then
                    EnrichZoneWithEntrance(poi, entrance)
                end
            end
        end









    end

    local results = self:SearchPOIs(allPOIs, text, fresh)



    local blacklistActive = ns.Blacklist and ns.Blacklist:HasAny()


    if isGlobal then
        local filters = EasyFind.db.globalSearchFilters
        wipe(reuseFilteredResults)
        local filteredResults = reuseFilteredResults
        for _, r in ipairs(results) do
            local dominated = false
            if blacklistActive and ns.Blacklist:Contains(r) then
                dominated = true
            elseif (r.isZone or r.category == "subzone") and filters.zones == false then
                dominated = true
            elseif r.category == "dungeon" and filters.dungeons == false then
                dominated = true
            elseif r.category == "raid" and filters.raids == false then
                dominated = true
            elseif r.category == "delve" and filters.delves == false then
                dominated = true
            end
            if not dominated then
                tinsert(filteredResults, r)
            end
        end
        results = filteredResults
    else



        local filters = EasyFind.db.localSearchFilters
        wipe(reuseFilteredResults)
        local filteredResults = reuseFilteredResults
        for _, r in ipairs(results) do
            if ns.MapSearch.PassesFilter(r, filters)
               and not (blacklistActive and ns.Blacklist:Contains(r)) then
                tinsert(filteredResults, r)
            end
        end
        results = filteredResults
    end



    local pins = not skipPins and EasyFind.db.pinnedMapItems or nil
    if pins and #pins > 0 then
        wipe(reusePinnedKeys)
        wipe(reusePinned)
        local pinnedKeys = reusePinnedKeys
        local pinned = reusePinned

        tinsert(pinned, { isPinHeader = true, name = L["HEADER_PINNED"] })
        if not EasyFind.db.mapPinsCollapsed then
            for _, pin in ipairs(pins) do
                local copy = {}
                for k, v in pairs(pin) do copy[k] = v end
                copy.isPinned = true
                tinsert(pinned, copy)
                pinnedKeys[GetMapPinKey(pin)] = true
            end
        else
            for _, pin in ipairs(pins) do
                pinnedKeys[GetMapPinKey(pin)] = true
            end
        end
        wipe(reuseFiltered)
        local filtered = reuseFiltered
        for _, r in ipairs(results) do
            if not pinnedKeys[GetMapPinKey(r)] then
                tinsert(filtered, r)
            end
        end
        for _, r in ipairs(filtered) do
            tinsert(pinned, r)
        end
        results = pinned
    end

    Search.isGlobalSearch = savedGlobalFlag
    return results
end





local SEARCH_CACHE_MAX = 32
local searchPoisCache = {
    local_  = { entries = {}, order = {}, lastQuery = "", lastCategory = nil },
    global_ = { entries = {}, order = {}, lastQuery = "", lastCategory = nil },
    ui_     = { entries = {}, order = {}, lastQuery = "", lastCategory = nil },
}
local function ResetSearchPoisCache()
    for _, c in pairs(searchPoisCache) do
        wipe(c.entries); wipe(c.order); c.lastQuery = ""; c.lastCategory = nil
    end
end
ns.MapSearch.ResetSearchPoisCache = ResetSearchPoisCache

local function ClearMapSearchScratch()
    WipeScratchTables()
end

function MapSearch:TrimSearchMemory()
    if self.ResetSearchZonesCache then self.ResetSearchZonesCache() end
    ResetSearchPoisCache()
    ReleaseGlobalMapCaches()
    Search.ClearLocalCaches()
    ClearMapSearchScratch()
    CollectMapGarbage()
end

function MapSearch:ReleaseIdleSearchMemory()
    ReleaseGlobalMapCaches()
    Search.ClearLocalCaches()
    ClearMapSearchScratch()
    CollectMapGarbage()
end



local GetPlayerMapPosition, GetWorldPosFromMapPos = C_Map.GetPlayerMapPosition, C_Map.GetWorldPosFromMapPos
local FAR = math.huge
local worldSpots = setmetatable({}, { __mode = "k" })
local nearOf = setmetatable({}, { __mode = "k" })

local function WorldSpot(poi)
    local m, x, y = poi.coordMapID or poi.entranceMapID or poi.mapID, poi.x, poi.y
    if not (m and x and y) then return nil end
    local s = worldSpots[poi]
    if not (s and s.m == m and s.x == x and s.y == y) then
        s = { m = m, x = x, y = y }
        local ok, ci, pos = pcall(GetWorldPosFromMapPos, m, CreateVector2D(x, y))
        if ok and ci and pos then s.ci, s.wx, s.wy = ci, pos:GetXY() end
        worldSpots[poi] = s
    end
    return s.ci, s.wx, s.wy
end



local CLASSIC_CAPITALS = {
    [1453] = "Alliance", [1455] = "Alliance", [1457] = "Alliance", [1947] = "Alliance",
    [1454] = "Horde", [1456] = "Horde", [1458] = "Horde", [1954] = "Horde",
}
local CAPITALS = {
    [84] = "Alliance", [87] = "Alliance", [89] = "Alliance", [103] = "Alliance",
    [85] = "Horde", [88] = "Horde", [90] = "Horde", [110] = "Horde", [998] = "Horde",
}
local UnitFactionGroup = UnitFactionGroup
local playerFaction, capitals


local function Hostile(poi)
    if playerFaction ~= "Alliance" and playerFaction ~= "Horde" then return false end
    if not capitals then
        local Caps = ns.Caps
        capitals = (Caps and (Caps.era or Caps.tbc or Caps.forever)) and CLASSIC_CAPITALS or CAPITALS
    end
    local f = capitals[poi.coordMapID or poi.entranceMapID or poi.mapID]
    return f ~= nil and f ~= playerFaction
end



local function Nearest(poi, pci, px, py)
    local d, enemy, usable = FAR, FAR, false
    local list = poi.allInstances
    for i = 1, list and #list or 1 do
        local spot = list and list[i] or poi
        local hostile = Hostile(spot)
        usable = usable or not hostile
        local ci, wx, wy = WorldSpot(spot)
        if ci == pci then
            local e = (wx - px) ^ 2 + (wy - py) ^ 2
            if hostile then enemy = mmin(enemy, e) else d = mmin(d, e) end
        end
    end
    return usable and d or enemy
end

local playerCI, playerX, playerY
local function TakeDistances(results)
    local m = GetBestMapForUnit("player")
    local pos = m and GetPlayerMapPosition(m, "player")
    local ok, pci, wp
    if pos then ok, pci, wp = pcall(GetWorldPosFromMapPos, m, pos) end
    local px, py
    if ok and pci and wp then px, py = wp:GetXY() else pci = nil end
    playerCI, playerX, playerY = pci, px, py
    playerFaction = UnitFactionGroup and UnitFactionGroup("player")
    for i = 1, #results do
        local r = results[i]
        nearOf[r] = (pci and not r.isZone) and Nearest(r, pci, px, py) or FAR
    end
end




local function NearestInstance(r)
    local list = r.isStatic and r.allInstances
    if not list then return r end
    local best, bd, bh = r, FAR, Hostile(r)
    for i = 1, #list do
        local poi = list[i]
        local hostile, d = Hostile(poi), FAR
        if playerCI then
            local ci, wx, wy = WorldSpot(poi)
            if ci == playerCI then d = (wx - playerX) ^ 2 + (wy - playerY) ^ 2 end
        end
        if (bh and not hostile) or (hostile == bh and d < bd) then best, bd, bh = poi, d, hostile end
    end
    return best
end


local function InZone(r, mapID)
    return (r.entranceMapID or r.zoneMapID or r.mapID) == mapID
end

local function POIResultLess(a, b)
    local sa, sb = a.score or 0, b.score or 0
    if sa == sb then
        if a.isZone and not b.isZone then return true end
        if b.isZone and not a.isZone then return false end
        local da, db = nearOf[a] or FAR, nearOf[b] or FAR
        if da ~= db then return da < db end
        local an, bn = a.name or "", b.name or ""
        if #an ~= #bn then return #an < #bn end
        return an < bn
    end
    return sa > sb
end



local function GetPOIDuplicateKey(poi)
    return (poi.name or "") .. (poi.category or "")
        .. (poi.isZone and (poi.pathPrefix or "") or "")
        .. (poi.npcID and ("#" .. poi.npcID) or "")
end



local function ResolveSearchCache(cache, query, matchedCategory, defaultCandidates)
    local cachedHit = cache.entries[query]
    if cachedHit and cachedHit.matchedCategory == matchedCategory then
        cache.lastQuery = query
        cache.lastCategory = matchedCategory
        return cachedHit, nil, false
    end

    if cache.lastQuery ~= ""
       and #query > #cache.lastQuery
       and query:sub(1, #cache.lastQuery) == cache.lastQuery
       and cache.lastCategory == matchedCategory then
        local previous = cache.entries[cache.lastQuery]
        if previous then
            return nil, previous.pool, true
        end
    end

    return nil, defaultCandidates, false
end

local function ClearCachedCandidateScores(candidates)
    for i = 1, #candidates do
        local poi = candidates[i]
        poi.score, poi.duplicateKey, poi.allInstances = nil, nil, nil
    end
end

local function ScorePOIForQuery(poi, query)
    if poi.isZone and poi.score then return poi.score end

    local score = ns.Database:ScoreName(GetNameLower(poi), query, #query)
    if poi.keywords or poi.decoratorWords then
        if not poi.kwLower then PreparePOI(poi) end
        score = mmax(score, ns.Database:ScoreKeywords(poi.kwLower, query, #query))
    end
    return score
end

local function AddScoredPOI(results, seen, duplicates, poi, key, score)
    local first = seen[key]
    if first then

        local dup = duplicates[key]
        if not dup then
            dup = { first }
            duplicates[key] = dup
        end
        dup[#dup + 1] = poi
        return
    end
    seen[key] = poi
    poi.score = score
    poi.duplicateKey = key
    tinsert(results, poi)
end





local placeFor, placeScope = nil, nil
local mapsInside = {}
local function AddPlaceMaps(set, mapID)
    set[mapID] = true
    local inside = mapsInside[mapID]
    if not inside then
        inside = {}
        for _, child in ipairs(C_Map.GetMapChildrenInfo(mapID, nil, true) or {}) do inside[#inside + 1] = child.mapID end
        mapsInside[mapID] = inside
    end
    for i = 1, #inside do set[inside[i]] = true end
end

local function NameHasWord(nameLower, word)
    for w in nameLower:gmatch("%S+") do
        if w == word then return true end
    end
    return false
end

local function PlaceScope(query)
    if placeFor == query then return placeScope end
    placeFor, placeScope = query, nil
    if not (MapSearch.ZonesNamed and query:find(" ", 1, true)) then return nil end
    local words, isPlace, maps = {}, {}, nil
    for w in query:gmatch("%S+") do words[#words + 1] = w end
    for i = 1, #words do
        local zones = not isPlace[i] and MapSearch:ZonesNamed(words[i])
        for z = 1, zones and #zones or 0 do
            local zone = zones[z]
            isPlace[i] = true
            maps = maps or {}
            AddPlaceMaps(maps, zone.mapID)

            for j = 1, #words do
                if not isPlace[j] and NameHasWord(zone.nameLower or "", words[j]) then isPlace[j] = true end
            end
        end
    end
    local rest = {}
    for i = 1, #words do
        if not isPlace[i] then rest[#rest + 1] = words[i] end
    end
    if not maps or #rest == 0 then return nil end
    placeScope = { query = table.concat(rest, " "), maps = maps }
    return placeScope
end

local function InPlace(poi, place)
    if poi.isZone then return false end
    local m = poi.entranceMapID or poi.zoneMapID or poi.mapID
    return m ~= nil and place.maps[m] == true
end


local function AppendNameMatches(results, seen, duplicates, candidates, query, scoped, place)
    for i, poi in ipairs(candidates) do
        if i % 64 == 0 then Utils.SliceCheckpoint() end

        local rec = scoped and (scoped[poi.category] or scoped["@map"])
        local here = place and InPlace(poi, place)




        if (poi.isZone and poi.score) or POICouldMatch(poi, rec and rec.query or query)
           or (here and POICouldMatch(poi, place.query)) then
            local score = ScorePOIForQuery(poi, query)
            if rec then score = mmax(score, ScorePOIForQuery(poi, rec.query) - 1) end
            if here then score = mmax(score, ScorePOIForQuery(poi, place.query) - 1) end
            if score >= 50 then
                AddScoredPOI(results, seen, duplicates, poi, GetPOIDuplicateKey(poi), score)
            end
        end
    end
end

local function GetCategoryMatchScore(poi, matchedCategory, relatedCategories)
    if poi.category == matchedCategory then return 150 end
    if relatedCategories then
        for _, category in ipairs(relatedCategories) do
            if poi.category == category then return 100 end
        end
    end
    return 0
end


local function AppendCategoryMatches(results, seen, duplicates, pois, matchedCategory, relatedCategories, place)
    if not matchedCategory then return end

    for i, poi in ipairs(pois) do
        if i % 64 == 0 then Utils.SliceCheckpoint() end
        if poi.category and not (place and not InPlace(poi, place)) then
            local key = GetPOIDuplicateKey(poi)
            if not seen[key] then
                local score = GetCategoryMatchScore(poi, matchedCategory, relatedCategories)
                if score > 0 then
                    AddScoredPOI(results, seen, duplicates, poi, key, place and score + 1 or score)
                end
            end
        end
    end
end

local function AttachDuplicateSets(results, duplicates)
    for _, result in ipairs(results) do
        if not result.allInstances and result.duplicateKey and duplicates[result.duplicateKey] then
            result.allInstances = duplicates[result.duplicateKey]
        end
    end
end



local function AttachProviderSpots(results)
    local viewed = not Search.isGlobalSearch and WorldMapFrame and WorldMapFrame:GetMapID()
    for i = 1, #results do
        local r = results[i]
        if r.spots and not r.allInstances then
            r.allInstances = viewed and MapSearch.SpotsOnMap(r.spots, viewed) or r.spots
        end
    end
end




local function StoreSearchResults(cache, query, matchedCategory, results, duplicates)
    if #results == 0 then return end
    local rows, scores, keys, sets, anyDup = {}, {}, {}, {}, false
    for i = 1, #results do
        local r = results[i]
        rows[i], scores[i], keys[i], sets[i] = r, r.score, r.duplicateKey, r.allInstances or false
        if duplicates[r.duplicateKey] then anyDup = true end
    end
    local pool = rows
    if anyDup then
        pool = {}
        for i = 1, #rows do
            local dup = duplicates[keys[i]]
            if dup then
                for j = 1, #dup do pool[#pool + 1] = dup[j] end
            else
                pool[#pool + 1] = rows[i]
            end
        end
    end
    if cache.entries[query] == nil then
        cache.order[#cache.order + 1] = query
        if #cache.order > SEARCH_CACHE_MAX then
            local oldest = tremove(cache.order, 1)
            cache.entries[oldest] = nil
        end
    end
    cache.entries[query] = { matchedCategory = matchedCategory, rows = rows, scores = scores, keys = keys,
                             sets = sets, pool = pool }
end






local mapSteer = {}
function MapSearch:SearchPOIs(pois, query, fresh, cacheKey)
    query = slower(query)
    if ns.Database and ns.Database.NormalizeSearchQuery then
        query = ns.Database:NormalizeSearchQuery(query)
    end
    wipe(reuseSearchResults)
    wipe(reuseSearchSeen)
    wipe(reuseSearchDuplicates)
    local results = reuseSearchResults
    local seen = reuseSearchSeen
    local duplicates = reuseSearchDuplicates

    local matchedCategory = self:GetCategoryMatch(query)
    local relatedCategories = matchedCategory and self:GetRelatedCategories(matchedCategory) or nil


    local Steer = ns.SearchSteer
    local scoped = Steer and Steer.Scope(mapSteer, query) and mapSteer.byCategory or nil
    local place = PlaceScope(query)
    local placeCategory = place and self:GetCategoryMatch(place.query)
    local placeRelated = placeCategory and self:GetRelatedCategories(placeCategory) or nil

    if cacheKey == nil then cacheKey = Search.isGlobalSearch and "global_" or "local_" end
    local cache = cacheKey and searchPoisCache[cacheKey]
    local hit, candidates, narrowed
    if cache then
        hit, candidates, narrowed = ResolveSearchCache(cache, query, matchedCategory, pois)
        if narrowed and (scoped or place) then candidates, narrowed = pois, false end
    else
        candidates = pois
    end
    if hit then
        local rows, scores, keys, sets = hit.rows, hit.scores, hit.keys, hit.sets
        for i = 1, #rows do
            local r = rows[i]
            r.score, r.duplicateKey, r.allInstances = scores[i], keys[i], sets[i] or nil
            results[i], seen[keys[i]] = r, r
        end
    else
        if narrowed then ClearCachedCandidateScores(candidates) end
        AppendNameMatches(results, seen, duplicates, candidates, query, scoped, place)
        AppendCategoryMatches(results, seen, duplicates, pois, placeCategory, placeRelated, place)
        AppendCategoryMatches(results, seen, duplicates, pois, matchedCategory, relatedCategories)
        AttachDuplicateSets(results, duplicates)
        if cache then
            StoreSearchResults(cache, query, matchedCategory, results, duplicates)
            cache.lastQuery = query
            cache.lastCategory = matchedCategory
        end
    end
    if fresh and #fresh > 0 then
        AppendNameMatches(results, seen, duplicates, fresh, query, scoped, place)
        AppendCategoryMatches(results, seen, duplicates, fresh, placeCategory, placeRelated, place)
        AppendCategoryMatches(results, seen, duplicates, fresh, matchedCategory, relatedCategories)
        AttachDuplicateSets(results, duplicates)
        AttachProviderSpots(results)
    end


    TakeDistances(results)
    tsort(results, POIResultLess)
    return results, matchedCategory
end









function MapSearch:IsKindQuery(query)
    query = slower(query or "")
    local _, _, exact = self:GetCategoryMatch(query)
    if exact then return true end
    return self.NpcKindQuery ~= nil and self.NpcKindQuery(query)
end

local splitHere, splitThere = {}, {}
function MapSearch:SplitUIRowsByZone(entries)
    local zone = GetBestMapForUnit("player")
    local info = zone and C_Map.GetMapInfo(zone)
    wipe(splitHere)
    wipe(splitThere)
    local here, there = splitHere, splitThere
    for i = 1, #entries do
        local d = entries[i].data
        if d and zone and (d.mapID == zone or d.zoneMapID == zone) then
            here[#here + 1] = entries[i]
        else
            there[#there + 1] = entries[i]
        end
    end
    local hereLabel = info and info.name and string.format(L["MAP_SECTION_THIS_ZONE_NAMED"], info.name)
        or L["MAP_SECTION_THIS_ZONE"]
    local n = 0
    for _, e in ipairs(here) do
        n = n + 1
        entries[n] = e
        if e.data then e.data.sectionLabel = hereLabel end
    end
    for _, e in ipairs(there) do
        n = n + 1
        entries[n] = e
        if e.data then e.data.sectionLabel = L["MAP_SECTION_ACROSS_WORLD"] end
    end
end



local function FillUIRow(d, r, searchMapID, query, showNear)
    local cat = r.category or "location"
    local near = showNear and nearOf[r]
    d.nearYards = near and near < FAR and near ^ 0.5 or nil
    d.name = r.name
    d.nameLower = GetNameLower(r)
    d.category = cat
    d.icon = r.icon or GetCategoryIcon(cat)
    d.displayID = r.displayID
    d.npcID = r.npcID
    d.spotCount = r.allInstances and #r.allInstances or nil
    d.mapSearchResult = true
    d.mapID = r.mapID or r.zoneMapID or r.entranceMapID or searchMapID
    d.zoneName = r.zoneName or r.pathPrefix
    d.matchNote = r.matchNote
    d.npcTitle = r.npcTitle
    d.soldName = r.soldName
    d.teachesText = r.teachesText
    d.pathPrefix = r.pathPrefix
    d.x = r.x or r.entranceX
    d.y = r.y or r.entranceY

    d.coordMapID = r.x and (r.coordMapID or r.mapID) or r.entranceMapID
    d.keywords = r.keywords
    d.query = query
    d.isZone = nil
    d.zoneMapType = r.zoneMapType
    d.zoneMapID = nil
    d.entranceMapID = nil
    d.entranceX = nil
    d.entranceY = nil
    d.entranceIcon = nil
    d.entranceCategory = nil
    d.isDungeonEntrance = nil
    if r.isZone then
        d.isZone = true
        d.zoneMapID = r.zoneMapID
        d.entranceMapID = r.entranceMapID
        d.entranceX = r.entranceX
        d.entranceY = r.entranceY
        d.entranceIcon = r.entranceIcon
        d.entranceCategory = r.entranceCategory
    end
    if r.isDungeonEntrance then
        d.isDungeonEntrance = true
        if not d.entranceMapID then
            d.entranceMapID = r.entranceMapID
        end
    end
end



function MapSearch.UIRowOf(r)
    local d = {}
    FillUIRow(d, r, r.mapID)
    return d
end



local uiParts = { at = 0 }
MapSearch.uiParts = uiParts
local function WorkClock()
    return debugprofilestop() - Utils.SlicePausedMs()
end
local function Part(name)
    if not debugprofilestop then return end
    local now = WorkClock()
    uiParts[name] = (uiParts[name] or 0) + now - uiParts.at
    uiParts.at = now
end



function MapSearch:SearchForUI(query, filters)
    Search.uiSearchCount = (Search.uiSearchCount or 0) + 1
    Search.uiScoredFor = nil
    if not query or query == "" or #query < 2 then return nil end
    if self.HasWorldZoneCache and not self:HasWorldZoneCache() then return nil end
    uiParts.at = debugprofilestop and WorkClock() or 0




    local searchMapID = GetBestMapForUnit("player") or (WorldMapFrame and WorldMapFrame:GetMapID())





    wipe(reuseUISearchPOIs)
    wipe(reuseUISearchExistingNames)
    wipe(reuseUIFreshRows)
    local pois = reuseUISearchPOIs
    local existingNames = reuseUISearchExistingNames
    local fresh = reuseUIFreshRows

    do


        local entrances = AppendLocalSearchSources(self, pois, existingNames, nil, searchMapID, false)
        AppendWorldStaticLocations(self, pois, existingNames, searchMapID)


        wipe(reuseUIHereEntrances)
        for i = 1, entrances and #entrances or 0 do
            reuseUIHereEntrances[GetNameLower(entrances[i])] = true
        end
    end
    Part("local")




    do
        local savedGlobalFlag = Search.isGlobalSearch
        Search.isGlobalSearch = true
        local zoneMatches = self:SearchZones(query)
        Search.isGlobalSearch = savedGlobalFlag
        local groupedZones = self:GroupZonesByParent(zoneMatches)
        wipe(reuseUISearchZoneNames)
        local zoneNames = reuseUISearchZoneNames

        AppendZoneSearchResults(fresh, zoneNames, groupedZones, existingNames)
        Part("zones")



        if self.HasGlobalInstanceCache and self:HasGlobalInstanceCache() then
            AppendGlobalInstanceSearchSources(self, pois, zoneNames, fresh, reuseUIHereEntrances)
        else
            RequestUISearchGlobalInstances(self)
        end
        Part("instances")
        AppendAlwaysFindableLocations(self, pois, existingNames, searchMapID)
        Part("findable")
        AppendSubzones(self, pois, existingNames, searchMapID, query)
        Part("subzones")
        if self.AppendNpcRows then self.AppendNpcRows(fresh, existingNames, query, nil, searchMapID) end
        Part("creatures")
    end

    if #pois == 0 and #fresh == 0 then return nil end


    local scored, matchedCategory = self:SearchPOIs(pois, query, fresh, "ui_")
    Part("score")
    if not scored or #scored == 0 then return nil end

    wipe(reuseUIScored)
    for i = 1, #scored do reuseUIScored[i] = scored[i] end
    Search.uiScoredFor, Search.uiScoredCategory, Search.uiScoredMapID = query, matchedCategory, searchMapID






    do
        local mtFilters = EasyFind.db.uiMapFilters
        if filters ~= nil then mtFilters = filters or nil end

        local only = EasyFind.db.mapZoneOnly
        local scoped = only ~= nil and next(only) ~= nil
        if mtFilters or scoped then
            wipe(reuseUISearchFiltered)
            local filtered = reuseUISearchFiltered
            local ZoneOnly = ns.MapSearch.ZoneOnly
            for _, r in ipairs(scored) do
                if (not mtFilters or ns.MapSearch.PassesFilter(r, mtFilters))
                   and not (scoped and ZoneOnly(r) and not InZone(r, searchMapID)) then
                    filtered[#filtered + 1] = r
                end
            end
            scored = filtered
            if #scored == 0 then return nil end
        end
    end

    local results = reuseUISearchResults
    local resultCap = mmin(#scored, UI_MAP_RESULT_CAP)
    local kindQuery = self:IsKindQuery(query)
    for ri = 1, resultCap do
        local r = scored[ri]
        local d = reuseUISearchResultData[ri]
        if not d then
            d = {}
            reuseUISearchResultData[ri] = d
        end
        local src = NearestInstance(r)
        FillUIRow(d, src, searchMapID, query, kindQuery)
        if src ~= r and kindQuery then
            local near = nearOf[r]
            d.nearYards = near and near < FAR and near ^ 0.5 or nil
        end
        d.mapRank, d.mapNear = ri, nearOf[r] or FAR
        local out = results[ri]
        if not out then
            out = {}
            results[ri] = out
        end
        out.score = r.score or 50
        out.data = d
    end
    for i = resultCap + 1, #results do
        results[i] = nil
    end
    Part("rows")

    return results
end









local function CategoryCovered(matched, category)
    if not matched then return false end
    if matched == category then return true end
    local related = MapSearch:GetRelatedCategories(matched)
    for i = 1, #related do
        if related[i] == category then return true end
    end
    return false
end




local awayRows, awayRank, awayNear, awayAt, awaySpot = {}, {}, {}, {}, {}
local function AwayLess(a, b)
    local ra, rb = awayRank[a], awayRank[b]
    if ra ~= rb then return ra < rb end
    local da, db = awayNear[a], awayNear[b]
    if da ~= db then return da < db end
    return awayAt[a] < awayAt[b]
end

local function KeepAway(row, spot, near, at)
    awayRows[#awayRows + 1] = row
    awaySpot[row], awayNear[row], awayAt[row] = spot, near, at
    awayRank[row] = Hostile(spot) and 2 or (near < FAR and 0 or 1)
end

local function WipeAway()
    wipe(awayRows)
    wipe(awayRank)
    wipe(awayNear)
    wipe(awayAt)
    wipe(awaySpot)
end


local function CategoryRow(n, spot, near, mapID, text)
    local d = reuseUICategoryData[n]
    if not d then
        d = {}
        reuseUICategoryData[n] = d
    end
    FillUIRow(d, spot, mapID, text, false)
    d.nearYards = near < FAR and near ^ 0.5 or nil
    return d
end





function MapSearch:GetCategoryResultsForUI(category, maxN, respectFilters, localOnly, text)
    if not category then return nil end
    maxN = maxN or 3
    local own = type(respectFilters) == "table" and respectFilters or nil
    if text and Search.uiScoredFor == text and CategoryCovered(Search.uiScoredCategory, category) then
        local filters = own or (respectFilters and EasyFind.db.uiMapFilters)
        local stash, mapID = reuseUIScored, Search.uiScoredMapID
        local playerMapID = GetBestMapForUnit("player")
        wipe(reuseUICategoryRows)
        WipeAway()
        local out, n = reuseUICategoryRows, 0


        for i = 1, #stash do
            local r = stash[i]
            if r.category == category and (not filters or MapSearch.PassesFilter(r, filters)) then
                local spot, near = NearestInstance(r), nearOf[r] or FAR
                if playerMapID ~= nil and (spot.mapID or spot.zoneMapID or spot.entranceMapID or mapID) == playerMapID then
                    if n < maxN then
                        n = n + 1
                        out[n] = CategoryRow(n, spot, near, mapID, text)
                    end
                elseif not localOnly then
                    KeepAway(r, spot, near, i)
                end
            end
        end
        tsort(awayRows, AwayLess)
        for i = 1, #awayRows do
            if n >= maxN then break end
            local r = awayRows[i]
            n = n + 1
            out[n] = CategoryRow(n, awaySpot[r], awayNear[r], mapID, text)
        end
        WipeAway()
        return n > 0 and out or nil
    end
    local catDef = ns.MapSearchData and ns.MapSearchData.CATEGORIES
        and ns.MapSearchData.CATEGORIES[category]
    local canonical = catDef and catDef.keywords and catDef.keywords[1] or category
    local rows
    if respectFilters then
        rows = self:SearchForUI(canonical, own)
    else
        rows = self:SearchForUI(canonical, false)
    end
    if not rows then return nil end




    local playerMapID = GetBestMapForUnit("player")
    wipe(reuseUICategoryRows)
    WipeAway()
    local out, n = reuseUICategoryRows, 0
    for i = 1, #rows do
        local d = rows[i].data
        if d and d.category == category then
            if playerMapID and d.mapID == playerMapID then
                n = n + 1
                out[n] = d
            elseif not localOnly then
                KeepAway(d, d, d.mapNear or FAR, i)
            end
        end
    end
    tsort(awayRows, AwayLess)
    for i = 1, #awayRows do
        if n >= maxN then break end
        n = n + 1
        out[n] = awayRows[i]
    end
    WipeAway()
    for i = n, maxN + 1, -1 do out[i] = nil end
    return n > 0 and out or nil
end




local function CopyRow(src)
    local row = {}
    for k, v in pairs(src) do row[k] = v end
    return row
end



MapSearch.ALL_SHOWN = {}
function MapSearch:PlacesForQuery(text)
    local filters = EasyFind.db.mapTabFilters or MapSearch.ALL_SHOWN

    local pass = {}
    for _, r in ipairs(self:SearchForUI(text, filters) or {}) do pass[#pass + 1] = CopyRow(r.data) end
    local category = ns.MapSearchData and ns.MapSearchData.KEYWORD_TO_CATEGORY
        and ns.MapSearchData.KEYWORD_TO_CATEGORY[slower(text)]
    local localOnly = category and ns.MapSearch.ZoneOnlyForCategory(category) or false
    local out, seen = {}, {}
    local function Add(row)
        local key = (row.nameLower or row.name or "") .. "\1" .. tostring(row.mapID or "")
        if seen[key] then return end
        seen[key] = true
        out[#out + 1] = row
    end
    for _, r in ipairs(category and self:GetCategoryResultsForUI(category, localOnly and 8 or 3, filters, localOnly, text) or {}) do
        Add(CopyRow(r))
    end
    for i = 1, #pass do
        if not (localOnly and pass[i].category == category) then Add(pass[i]) end
    end
    return out
end


MapSearch._peek = MapSearch._peek or {}
function MapSearch._peek.results() return { poiSearches = searchPoisCache } end
