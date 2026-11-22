local _, ns = ...

local MapSearch = ns.MapSearch
local Utils = ns.Utils
local MapSearchData = ns.MapSearchData
local SearchText = ns.SearchText

local pairs, ipairs = Utils.pairs, Utils.ipairs
local tinsert = Utils.tinsert
local sfind = Utils.sfind


local slower = SearchText.Normalize

local CATEGORIES = MapSearchData.CATEGORIES

local wipe = wipe


local GetCategoryIcon = MapSearch.GetCategoryIcon
local GetFilterBucket = MapSearch.GetFilterBucket

local function GetMapPinKey(data)
    return MapSearch:GetMapPinKey(data)
end




local function FlightPathsEnabledAnywhere()
    local db = EasyFind and EasyFind.db
    if not db then return true end
    local tabFilters = db.mapTabFilters
    local barFilters = db.uiMapFilters
    return (tabFilters and tabFilters.flights ~= false)
        or (barFilters and barFilters.flights ~= false)
        or (not tabFilters and not barFilters)
end
local scratchTables = {}
local function NewScratchTable()
    local tbl = {}
    scratchTables[#scratchTables + 1] = tbl
    return tbl
end

local function WipeScratchTables()
    for i = 1, #scratchTables do
        wipe(scratchTables[i])
    end
end


local sgsub = string.gsub


local function normalizeName(name)
    local n = slower(name)
    n = sgsub(n, "%-", " ")
    n = sgsub(n, "%s+", " ")
    return n
end

local function GetNameLower(entry)
    local nameLower = entry.nameLower
    if not nameLower then
        nameLower = slower(entry.name or "")
        entry.nameLower = nameLower
    end
    return nameLower
end

local function GetNameNorm(entry)
    local nameNorm = entry.nameNorm
    if not nameNorm then
        nameNorm = normalizeName(entry.name or "")
        entry.nameNorm = nameNorm
    end
    return nameNorm
end

local SpellNameOf = C_Spell and C_Spell.GetSpellName
    or (GetSpellInfo and function(id) return (GetSpellInfo(id)) end)

local function PreparePOI(entry)
    if not entry then return entry end
    GetNameLower(entry)


    if entry.teaches and not entry.teachesText then
        local names = {}
        local keywords = entry.keywords or {}
        entry.keywords = keywords
        for i = 1, #entry.teaches do
            local name = SpellNameOf and SpellNameOf(entry.teaches[i])
            if name and name ~= "" then
                names[#names + 1] = name
                keywords[#keywords + 1] = name
            end
        end
        entry.teachesText = table.concat(names, ", ")
    end
    local own, given = entry.keywords, entry.decoratorWords
    if (own or given) and not entry.kwLower then
        local kwLower = {}
        for i = 1, own and #own or 0 do
            kwLower[i] = slower(own[i])
        end
        for i = 1, given and #given or 0 do
            kwLower[#kwLower + 1] = given[i]
        end
        entry.kwLower = kwLower
    end
    if entry.isDungeonEntrance then
        GetNameNorm(entry)
    end
    return entry
end



local Extensions = ns.Extensions
local Decorators = Extensions and Extensions.Decorators
local function TakeDecoratorWords(entry)
    local generation = Decorators and Decorators.generation
    if not generation or entry.wordsGeneration == generation then return end
    entry.wordsGeneration = generation
    local words
    if entry.npcID then
        words = Extensions.NpcWords(entry.npcID)
    else
        local mapID = entry.mapID or entry.zoneMapID or entry.entranceMapID
        words = mapID and Extensions.PlaceWords(GetNameLower(entry), mapID) or nil
    end
    if words ~= entry.decoratorWords then
        entry.decoratorWords = words
        entry.kwLower, entry.searchMask = nil, nil
    end
end






local band, bor, lshift = bit.band, bit.bor, bit.lshift
local sbyte = string.byte

local function LetterMask(text)
    local mask = 0
    for i = 1, #text do
        local b = sbyte(text, i)
        if b >= 97 and b <= 122 then
            mask = bor(mask, lshift(1, b - 97))
        end
    end
    return mask
end


local function GetPOIMask(entry)
    TakeDecoratorWords(entry)
    local mask = entry.searchMask
    if mask then return mask end
    mask = LetterMask(GetNameLower(entry))
    if entry.keywords or entry.decoratorWords then
        if not entry.kwLower then PreparePOI(entry) end
        for i = 1, #entry.kwLower do
            mask = bor(mask, LetterMask(entry.kwLower[i]))
        end
    end
    entry.searchMask = mask
    return mask
end



local lastQueryMaskFor, lastQueryMask, prevQueryMaskFor, prevQueryMask
local function QueryLetterMask(query)
    if query == lastQueryMaskFor then return lastQueryMask end
    if query == prevQueryMaskFor then return prevQueryMask end
    prevQueryMaskFor, prevQueryMask = lastQueryMaskFor, lastQueryMask
    lastQueryMaskFor, lastQueryMask = query, LetterMask(query)
    return lastQueryMask
end



local function POICouldMatch(entry, query)
    local qm = QueryLetterMask(query)
    return band(qm, GetPOIMask(entry)) == qm
end

local function PreparePOIList(entries)
    for i = 1, #entries do
        PreparePOI(entries[i])
    end
    return entries
end

local function EnrichZoneWithEntrance(poi, entrance)
    poi.name = entrance.name
    poi.nameLower = GetNameLower(entrance)
    poi.nameNorm = GetNameNorm(entrance)
    poi.kwLower = entrance.kwLower
    poi.entranceX = entrance.x
    poi.entranceY = entrance.y
    poi.entranceMapID = entrance.entranceMapID
    poi.entranceIcon = entrance.icon
    poi.entranceCategory = entrance.category
    poi.category = entrance.category
    poi.icon = entrance.icon
end





local reuseEntranceLookup = {}
local entranceLookupFor, entranceLookupN
local function BuildEntranceLookup(entries)



    if entranceLookupFor == entries and entranceLookupN == #entries then
        return reuseEntranceLookup
    end
    entranceLookupFor, entranceLookupN = entries, #entries
    wipe(reuseEntranceLookup)
    for _, entry in ipairs(entries) do
        if entry.isDungeonEntrance and entry.x and entry.y then
            reuseEntranceLookup[GetNameLower(entry)] = entry
        end
    end
    return reuseEntranceLookup
end

local Search = ns.MapSearchSearch or {}
ns.MapSearchSearch = Search
Search.isGlobalSearch = Search.isGlobalSearch or false

function MapSearch:IsGlobalSearchActive()
    return Search.isGlobalSearch
end
Search.rareTrackCache = Search.rareTrackCache or {}
Search.rareDeadGUIDs = Search.rareDeadGUIDs or {}
Search.rareTrackMapID = Search.rareTrackMapID
MapSearch._rareTrackCache = Search.rareTrackCache
MapSearch._rareDeadGUIDs = Search.rareDeadGUIDs

local reuseAllPOIs = NewScratchTable()
local reuseZoneNames = NewScratchTable()
local reuseExistingNames = NewScratchTable()
local reuseFilteredResults = NewScratchTable()
local reusePinnedKeys = NewScratchTable()
local reusePinned = NewScratchTable()
local reuseFiltered = NewScratchTable()
local reuseSearchResults = NewScratchTable()
local reuseSearchSeen = NewScratchTable()
local reuseSearchDuplicates = NewScratchTable()
local reuseInstanceNameNorm = NewScratchTable()
local reuseUISearchPOIs = NewScratchTable()
local reuseUISearchExistingNames = NewScratchTable()
local reuseUISearchZoneNames = NewScratchTable()
local reuseUISearchFiltered = NewScratchTable()
local reuseUISearchResults = NewScratchTable()
local reuseUISearchResultData = NewScratchTable()
local reuseFreshRows = NewScratchTable()
local reuseUIFreshRows = NewScratchTable()
local reuseUIScored = NewScratchTable()
local reuseUICategoryRows = NewScratchTable()
local reuseUICategoryData = NewScratchTable()
local UI_MAP_RESULT_CAP = 60


local function MatchCategory(query)
    local matchedCategory = nil
    local matchScore = 0
    for catName, catData in pairs(CATEGORIES) do
        for _, keyword in ipairs(catData.keywords) do
            local kw = slower(keyword)
            if kw == query then
                return catName, 100, true
            elseif sfind(kw, query, 1, true) and #query >= 3 then
                local score = #query / #kw * 50
                if score > matchScore then
                    matchScore = score
                    matchedCategory = catName
                end
            end
        end
    end
    return matchedCategory, matchScore, false
end


local categoryMemo, categoryMemoN = {}, 0
function MapSearch:GetCategoryMatch(query)
    query = slower(query):match("^(.-)%s*$")
    if ns.Database and ns.Database.NormalizeSearchQuery then
        query = ns.Database:NormalizeSearchQuery(query)
    end
    local memo = categoryMemo[query]
    if not memo then
        if categoryMemoN >= 128 then
            wipe(categoryMemo)
            categoryMemoN = 0
        end
        local cat, score, exact = MatchCategory(query)
        memo = { cat or false, score, exact }
        categoryMemo[query] = memo
        categoryMemoN = categoryMemoN + 1
    end
    return memo[1] or nil, memo[2], memo[3]
end



local relatedMemo = {}
function MapSearch:GetRelatedCategories(category)
    local related = relatedMemo[category]
    if related then return related end
    related = { category }
    local catData = CATEGORIES[category]
    if catData and catData.parent then
        tinsert(related, catData.parent)
    end
    for catName, data in pairs(CATEGORIES) do
        if data.parent == category then
            tinsert(related, catName)
        end
    end
    relatedMemo[category] = related
    return related
end



Search.GetCategoryIcon = GetCategoryIcon
Search.GetFilterBucket = GetFilterBucket
Search.GetMapPinKey = GetMapPinKey
Search.FlightPathsEnabledAnywhere = FlightPathsEnabledAnywhere
Search.NewScratchTable = NewScratchTable
Search.WipeScratchTables = WipeScratchTables
Search.NormalizeName = normalizeName
Search.GetNameLower = GetNameLower
Search.GetNameNorm = GetNameNorm
Search.PreparePOI = PreparePOI
Search.PreparePOIList = PreparePOIList
Search.POICouldMatch = POICouldMatch
Search.LetterMask = LetterMask
Search.EnrichZoneWithEntrance = EnrichZoneWithEntrance
Search.BuildEntranceLookup = BuildEntranceLookup
Search.reuseAllPOIs = reuseAllPOIs
Search.reuseZoneNames = reuseZoneNames
Search.reuseExistingNames = reuseExistingNames
Search.reuseFilteredResults = reuseFilteredResults
Search.reusePinnedKeys = reusePinnedKeys
Search.reusePinned = reusePinned
Search.reuseFiltered = reuseFiltered
Search.reuseSearchResults = reuseSearchResults
Search.reuseSearchSeen = reuseSearchSeen
Search.reuseSearchDuplicates = reuseSearchDuplicates
Search.reuseInstanceNameNorm = reuseInstanceNameNorm
Search.reuseUISearchPOIs = reuseUISearchPOIs
Search.reuseUISearchExistingNames = reuseUISearchExistingNames
Search.reuseUISearchZoneNames = reuseUISearchZoneNames
Search.reuseUISearchFiltered = reuseUISearchFiltered
Search.reuseUISearchResults = reuseUISearchResults
Search.reuseUISearchResultData = reuseUISearchResultData
Search.reuseFreshRows = reuseFreshRows
Search.reuseUIFreshRows = reuseUIFreshRows
Search.reuseUIScored = reuseUIScored
Search.reuseUICategoryRows = reuseUICategoryRows
Search.reuseUICategoryData = reuseUICategoryData
Search.UI_MAP_RESULT_CAP = UI_MAP_RESULT_CAP




MapSearch._peek = MapSearch._peek or {}
function MapSearch._peek.scratch() return { tables = scratchTables } end
