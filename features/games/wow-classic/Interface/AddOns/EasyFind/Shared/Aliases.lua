local _, ns = ...








local Aliases = {}
if ns then ns.Aliases = Aliases end

local Utils = ns.Utils
local SearchText = ns.SearchText
local strtrim = strtrim
local sformat = string.format
local mfloor = Utils.mfloor
local sfind = Utils.sfind
local smatch = Utils.smatch
local tinsert = Utils.tinsert
local tsort = Utils.tsort
local time = time





local normalize = SearchText.Normalize



local function PlacelessProviderRow(data)
    if not data or data.x ~= nil then return false end
    local Extensions = ns.Extensions
    return Extensions ~= nil and Extensions.ProviderOf ~= nil and Extensions.ProviderOf(data) ~= nil
end

local function IsMapAliasTarget(data)
    if not data or data.providerRow or PlacelessProviderRow(data) then return false end
    return data.mapSearchResult or data.isZone or data.isDungeonEntrance
        or data.zoneMapID or data.entranceMapID
        or (data.category and (data.x or data.entranceX or data.mapID or data.coordMapID))
end

local function MapAliasKey(data)
    local name = normalize(data.name or "")
    if name == "" then return nil end
    local mapID = data.mapID or data.coordMapID or data.zoneMapID
        or data.entranceMapID or data.parentMapID
        or (WorldMapFrame and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID())
        or 0
    local x = data.x or data.entranceX or 0
    local y = data.y or data.entranceY or 0
    return sformat("map:%s:%d:%s:%d:%d",
        data.category or "location", mapID, name,
        mfloor(x * 10000 + 0.5), mfloor(y * 10000 + 0.5))
end


local function MapRowIcon(category)
    if category == "zone" then return ns.ZONE_ICON end
    return ns.MapSearch and ns.MapSearch.GetCategoryIcon and ns.MapSearch.GetCategoryIcon(category) or nil
end



local function ReconstructMapData(key)
    if type(key) ~= "string" then return nil end
    local body = key:match("^map:(.+)$")
    if not body then return nil end
    local category, mapID, rest = body:match("^([^:]*):(%d+):(.+)$")
    if not category or not rest then return nil end
    local name, xi, yi = rest:match("^(.-):(%d+):(%d+)$")
    if not name then return nil end
    mapID = tonumber(mapID)
    local isZone = category == "zone"

    local properName, mapInfo
    if isZone and mapID then
        mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
        if mapInfo and mapInfo.name and mapInfo.name ~= "" then properName = mapInfo.name end
    elseif mapID and ns.STATIC_LOCATIONS then
        local locs = ns.STATIC_LOCATIONS[mapID]
        if locs then
            local xn, yn = tonumber(xi), tonumber(yi)
            for i = 1, #locs do
                local poi = locs[i]
                if mfloor((poi.x or 0) * 10000 + 0.5) == xn
                   and mfloor((poi.y or 0) * 10000 + 0.5) == yn then
                    properName = poi.name
                    break
                end
            end
        end
    end

    local creature = category == "npc" and ns.Npcs and ns.Npcs.ByName and ns.Npcs.ByName(name)
    local zoneInfo = creature and mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return {
        name = (creature and creature.name) or properName or name,
        nameLower = name,
        category = category,
        icon = MapRowIcon(category),
        mapSearchResult = true,
        mapID = mapID,
        x = tonumber(xi) / 10000,
        y = tonumber(yi) / 10000,
        isZone = isZone or nil,
        zoneMapID = isZone and mapID or nil,
        zoneMapType = mapInfo and mapInfo.mapType or nil,
        zoneParentMapID = mapInfo and mapInfo.parentMapID or nil,
        zoneName = zoneInfo and zoneInfo.name or nil,
        npcID = creature and creature.npcID or nil,
        displayID = creature and creature.displayID or nil,
    }
end



local function FillMapRow(entry)
    if not (entry and entry.mapSearchResult) then return entry end
    if not entry.icon or entry.category == "zone" then
        entry.icon = MapRowIcon(entry.category) or entry.icon
    end
    if entry.isZone and entry.zoneMapID and not entry.zoneMapType then
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(entry.zoneMapID)
        if info then
            if entry.name == entry.nameLower and info.name and info.name ~= "" then entry.name = info.name end
            entry.zoneMapType = info.mapType
            entry.zoneParentMapID = entry.zoneParentMapID or info.parentMapID
        end
    end
    return entry
end



local viewCorpus, viewStub
local stubView = setmetatable({}, {
    __index = function(_, key) return viewCorpus:Peek(viewStub, key) end,
})





function Aliases:GetEntryKey(data)
    if not data then return nil end
    local mt = getmetatable(data)
    if mt and mt.__pcCorpus then
        viewCorpus, viewStub = mt.__pcCorpus, data
        data = stubView
    end
    if data.mountID       then return "mount:"          .. data.mountID end
    if data.toyItemID     then return "toy:"            .. data.toyItemID end
    if data.petID         then return "pet:"            .. data.petID end
    if data.outfitID      then return "outfit:"         .. data.outfitID end
    if data.transmogSetID then return "appearanceSet:"  .. data.transmogSetID end
    if data.macroIndex    then return "macro:"          .. data.macroIndex end
    if data.factionID     then return "reputation:"     .. data.factionID end
    if data.achievementID then return "achievement:"    .. data.achievementID end
    if data.itemID and data.category == "Loot" then return "loot:" .. data.itemID end
    if data.catalogItem and data.itemID then return "catalogitem:" .. data.itemID end


    if data.professionRecipeID then return "recipe:" .. data.professionRecipeID end
    if data.noteID         then return "note:"           .. data.noteID end
    if data.quicklistID    then return "quicklist:"      .. data.quicklistID end
    if data.category == "Currency" and data.steps then
        for i = 1, #data.steps do
            local cid = data.steps[i].currencyID
            if cid then return "currency:" .. cid end
        end
    end

    if data.providerRow then return Aliases:GetEntryKey(data.providerRow) end
    if PlacelessProviderRow(data) and data.name then return "ext:" .. data.category .. ":" .. data.name end
    if IsMapAliasTarget(data) then
        return MapAliasKey(data)
    end
    local path = data.path
    if path and #path > 0 then
        return "ui:" .. table.concat(path, ">") .. ">" .. (data.name or "")
    end
    if data.name then return "ui:" .. data.name end
    return nil
end






local keyIndex
local keyIndexLen




local keyMemo = setmetatable({}, { __mode = "k" })

local function MemoKey(entry)
    local k = keyMemo[entry]
    if k == nil then
        k = Aliases:GetEntryKey(entry) or false
        if not IsMapAliasTarget(entry) then keyMemo[entry] = k end
    end
    return k
end





local warming, warmAgain = false, false
local function WarmKeys()
    local sf = ns.Search and ns.Search.GetSearchFrame and ns.Search:GetSearchFrame()
    if not (sf and sf._efProvidersWarmed) then return end
    if warming then
        warmAgain = true
        return
    end
    warming = true
    Utils.SafeAfter(0, function()
        Utils.RunSliced(function()
            repeat
                warmAgain = false
                local data = ns.Database and ns.Database.uiSearchData
                for i = 1, data and #data or 0 do
                    local entry = data[i]
                    if entry and keyMemo[entry] == nil then MemoKey(entry) end
                    if i % 64 == 0 then Utils.SliceCheckpoint() end
                end
            until not warmAgain
        end, function() warming = false end, 2, "aliasIndex")
    end)
end


function Aliases._DebugPeek() return { keyMemo = keyMemo, keyIndex = keyIndex } end

function Aliases:InvalidateKeyIndex()
    keyIndex = nil
    WarmKeys()
end

local function EntryKeyIndex(data)
    if keyIndex and keyIndexLen == #data then return keyIndex end
    local idx = {}
    for i = 1, #data do
        local entry = data[i]
        local k = MemoKey(entry)
        if k and idx[k] == nil then idx[k] = entry end
    end
    keyIndex = idx
    keyIndexLen = #data
    return idx
end







local keyResolvers = {}

function Aliases:RegisterKeyResolver(prefix, resolver)
    keyResolvers[prefix] = resolver
end


function Aliases:LiveEntryByKey(key)
    local data = key and ns.Database and ns.Database.uiSearchData
    return data and EntryKeyIndex(data)[key] or nil
end

function Aliases:FindEntryByKey(key)
    if not key then return nil end
    local hit = self:LiveEntryByKey(key)
    if hit then return hit end


    if EasyFind and EasyFind.db and EasyFind.db.aliases then
        for _, info in pairs(EasyFind.db.aliases) do
            if info.key == key and info.snapshot then
                return FillMapRow(info.snapshot)
            end
        end
    end
    local prefix = smatch(key, "^([%w_%-]+):")
    local resolver = prefix and keyResolvers[prefix]
    if resolver then
        return resolver(key)
    end
    return nil
end



Aliases:RegisterKeyResolver("map", ReconstructMapData)






function Aliases:BuildSnapshot(data)




    if data and data.catalogItem and data.itemID then
        return {
            itemID = data.itemID,
            catalogItem = true,
            lookupRow = true,
            category = data.category,
            name = data.name,
            nameLower = data.nameLower,
            quality = data.quality,
        }
    end
    if not IsMapAliasTarget(data) then return nil end
    local currentMapID = WorldMapFrame and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    return {
        name = data.name,
        nameLower = data.nameLower,
        category = data.category,
        icon = data.icon,
        mapSearchResult = true,
        mapID = data.mapID or data.coordMapID or data.entranceMapID or data.zoneMapID or currentMapID,
        zoneName = data.zoneName,
        pathPrefix = data.pathPrefix,
        x = data.x, y = data.y,
        keywords = data.keywords,
        isZone = data.isZone,
        zoneMapID = data.zoneMapID,
        zoneMapType = data.zoneMapType,
        zoneParentMapID = data.zoneParentMapID,
        parentMapID = data.parentMapID,
        coordMapID = data.coordMapID,
        entranceMapID = data.entranceMapID,
        entranceX = data.entranceX,
        entranceY = data.entranceY,
        entranceIcon = data.entranceIcon,
        entranceCategory = data.entranceCategory,
        isDungeonEntrance = data.isDungeonEntrance,
        npcID = data.npcID,
        displayID = data.displayID,
    }
end



local function FillCreature(entry)
    if not (entry and entry.category == "npc" and not entry.displayID) then return entry end
    local npcs = ns.Npcs
    local hit = npcs and npcs.ByName and npcs.ByName(entry.nameLower or entry.name)
    if hit then
        entry.name = hit.name
        entry.displayID = hit.displayID
        entry.npcID = entry.npcID or hit.npcID
    end
    return entry
end


local function LiveProviderRow(snapshot)
    local data = ns.Database and ns.Database.uiSearchData
    for i = 1, data and #data or 0 do
        local d = data[i]
        if d.category == snapshot.category and d.name == snapshot.name then return d end
    end
    return nil
end


local function SavedEntry(key, snapshot)
    if snapshot and smatch(key or "", "^map:") and PlacelessProviderRow(snapshot) then
        return LiveProviderRow(snapshot)
    end
    if snapshot and smatch(key or "", "^map:") then return FillMapRow(FillCreature(snapshot)) end
    return FillMapRow(FillCreature(Aliases:FindEntryByKey(key) or snapshot))
end
Aliases.SavedEntry = SavedEntry






function Aliases:Add(aliasText, data)
    if not EasyFind or not EasyFind.db then return false end
    aliasText = strtrim(aliasText or "")
    if aliasText == "" then return false end
    local key = Aliases:GetEntryKey(data)
    if not key then return false end
    if type(EasyFind.db.aliases) ~= "table" then
        EasyFind.db.aliases = {}
    end
    local snapshot = self:BuildSnapshot(data)
    EasyFind.db.aliases[normalize(aliasText)] = {
        text = aliasText,
        key  = key,
        name = data.name or aliasText,
        snapshot = snapshot,
    }
    return true
end

function Aliases:Remove(aliasText)
    if not EasyFind or not EasyFind.db or not EasyFind.db.aliases then return end
    EasyFind.db.aliases[normalize(strtrim(aliasText or ""))] = nil
end





function Aliases:AddCategory(aliasText, category, name)
    if not (EasyFind and EasyFind.db) then return false end
    aliasText = strtrim(aliasText or "")
    if aliasText == "" or not category then return false end
    if type(EasyFind.db.aliases) ~= "table" then
        EasyFind.db.aliases = {}
    end
    EasyFind.db.aliases[normalize(aliasText)] = {
        text = aliasText,
        key  = "mapcat:" .. category,
        name = name or category,
    }
    return true
end



function Aliases:AddByKey(aliasText, key, name)
    if not (EasyFind and EasyFind.db and key) then return false end
    aliasText = strtrim(aliasText or "")
    if aliasText == "" then return false end
    EasyFind.db.aliases = EasyFind.db.aliases or {}
    EasyFind.db.aliases[normalize(aliasText)] = { text = aliasText, key = key, name = name or aliasText }
    return true
end


function Aliases:RemoveByKey(key)
    if not (EasyFind and EasyFind.db and EasyFind.db.aliases and key) then return end
    for storedKey, info in pairs(EasyFind.db.aliases) do
        if info.key == key then EasyFind.db.aliases[storedKey] = nil end
    end
end

function Aliases:ClearAll()
    if not EasyFind or not EasyFind.db then return end
    EasyFind.db.aliases = {}
end

function Aliases:ForEach(cb)
    if not EasyFind or not EasyFind.db or not EasyFind.db.aliases then return end
    for _, info in pairs(EasyFind.db.aliases) do
        cb(info.text, info)
    end
end


function Aliases:ExportList()
    local out = {}
    if EasyFind and EasyFind.db and EasyFind.db.aliases then
        for _, info in pairs(EasyFind.db.aliases) do
            out[#out + 1] = { text = info.text, key = info.key, name = info.name }
        end
    end
    return out
end


function Aliases:HasAlias(text)
    if not (EasyFind and EasyFind.db and EasyFind.db.aliases) then return false end
    if type(text) ~= "string" then return false end
    return EasyFind.db.aliases[normalize(text)] ~= nil
end

function Aliases:ImportList(list, skipExisting)
    if type(list) ~= "table" or not (EasyFind and EasyFind.db) then return 0 end
    EasyFind.db.aliases = EasyFind.db.aliases or {}
    local n = 0
    for i = 1, #list do
        local r = list[i]
        if r and r.text and strtrim(r.text) ~= "" and r.key then
            local normKey = normalize(r.text)
            if not (skipExisting and EasyFind.db.aliases[normKey]) then
                EasyFind.db.aliases[normKey] = {
                    text = r.text, key = r.key, name = r.name or r.text,
                }
                n = n + 1
            end
        end
    end
    return n
end






local Blacklist = {}
ns.Blacklist = Blacklist



local blacklistCount

function Blacklist:HasAny()
    if blacklistCount == nil then
        local store = EasyFind and EasyFind.db and EasyFind.db.blacklist
        local n = 0
        if type(store) == "table" then
            for _ in pairs(store) do n = n + 1 end
        end
        blacklistCount = n
    end
    return blacklistCount > 0
end




function Blacklist:Contains(data)
    if not data then return false end
    local store = EasyFind and EasyFind.db and EasyFind.db.blacklist
    if not store then return false end
    local key = rawget(data, "_efBLKey")
    if key == nil then
        key = Aliases:GetEntryKey(data) or false
        rawset(data, "_efBLKey", key)
    end
    return key ~= false and store[key] ~= nil
end


function Blacklist:FilterRows(list)
    if not self:HasAny() then return list end
    local kept = 0
    for i = 1, #list do
        local r = list[i]
        if not self:Contains(r.data) then
            kept = kept + 1
            list[kept] = r
        end
    end
    for i = #list, kept + 1, -1 do list[i] = nil end
    return list
end

function Blacklist:Add(data)
    if not (EasyFind and EasyFind.db) then return false end
    local key = Aliases:GetEntryKey(data)
    if not key then return false end
    if type(EasyFind.db.blacklist) ~= "table" then
        EasyFind.db.blacklist = {}
    end
    EasyFind.db.blacklist[key] = { name = data.name or key, category = data.category }
    blacklistCount = nil



    if ns.UIPins and ns.UIPins.IsPinned(data) then
        ns.UIPins.Unpin(data)
    end
    return true
end

function Blacklist:RemoveByKey(key)
    local store = EasyFind and EasyFind.db and EasyFind.db.blacklist
    if not (store and key) then return end
    store[key] = nil
    blacklistCount = nil
end

function Blacklist:ClearAll()
    if not (EasyFind and EasyFind.db) then return end
    EasyFind.db.blacklist = {}
    blacklistCount = nil
end

function Blacklist:ForEach(cb)
    local store = EasyFind and EasyFind.db and EasyFind.db.blacklist
    if not store then return end
    for key, info in pairs(store) do
        cb(key, info)
    end
end



function Blacklist:ExportList()
    local out = {}
    local store = EasyFind and EasyFind.db and EasyFind.db.blacklist
    if store then
        for key, info in pairs(store) do
            out[#out + 1] = { key = key, name = info.name, category = info.category }
        end
    end
    return out
end


function Blacklist:Has(key)
    local store = EasyFind and EasyFind.db and EasyFind.db.blacklist
    return type(store) == "table" and key ~= nil and store[key] ~= nil
end

function Blacklist:ImportList(list, skipExisting)
    if type(list) ~= "table" or not (EasyFind and EasyFind.db) then return 0 end
    if type(EasyFind.db.blacklist) ~= "table" then
        EasyFind.db.blacklist = {}
    end
    local n = 0
    for i = 1, #list do
        local r = list[i]
        if r and r.key then
            if not (skipExisting and EasyFind.db.blacklist[r.key]) then
                EasyFind.db.blacklist[r.key] = { name = r.name or r.key, category = r.category }
                n = n + 1
            end
        end
    end
    blacklistCount = nil
    return n
end















local Learned = {}
ns.Learned = Learned

local LEARN_CAP = 200
local LEARN_PICKS_MAX = 3
local LEARN_HALF_LIFE = 7 * 86400




local function PickScore(p, now)
    local w = p.w or p.n or 1
    local age = now - (p.at or now)
    if age <= 0 then return w end
    return w * 2 ^ (-age / LEARN_HALF_LIFE)
end

local function TrimLearned(store)
    local count = 0
    for _ in pairs(store) do count = count + 1 end
    while count > LEARN_CAP do
        local oldestQuery, oldestAt
        for query, rec in pairs(store) do
            local at = rec.last or rec.at or 0
            if not oldestAt or at < oldestAt then
                oldestAt = at
                oldestQuery = query
            end
        end
        store[oldestQuery] = nil
        count = count - 1
    end
end

function Learned:RecordPick(data, typedQuery)
    if not (EasyFind and EasyFind.db) then return end
    if EasyFind.db.learnFromPicks == false then return end
    local query = normalize(strtrim(typedQuery or ""))
    if query == "" then return end
    local key = Aliases:GetEntryKey(data)
    if not key then return end
    if type(EasyFind.db.queryLearn) ~= "table" then
        EasyFind.db.queryLearn = {}
    end
    local store = EasyFind.db.queryLearn
    local now = time()
    local rec = store[query]


    local picks = {}
    if rec and rec.key then
        picks[1] = { key = rec.key, n = rec.n, at = rec.at, w = rec.w, snapshot = rec.snapshot }
        for i = 1, #(rec.prev or {}) do picks[#picks + 1] = rec.prev[i] end
    end


    local kind = data.mapSearchResult and data.category and ns.MapSearch and ns.MapSearch.IsKindQuery
        and ns.MapSearch:IsKindQuery(query) and data.category
    if kind then
        for i = #picks, 1, -1 do
            local s = picks[i].snapshot
            if picks[i].key ~= key and s and s.mapSearchResult and s.category == kind then
                table.remove(picks, i)
            end
        end
    end
    local made
    for i = 1, #picks do
        if picks[i].key == key then made = picks[i] break end
    end
    if made then
        made.w = PickScore(made, now) + 1
        made.n = (made.n or 0) + 1
        made.at = now
        made.snapshot = Aliases:BuildSnapshot(data) or made.snapshot
    else
        made = { key = key, n = 1, at = now, w = 1, snapshot = Aliases:BuildSnapshot(data) }
        picks[#picks + 1] = made
    end
    tsort(picks, function(a, b)
        local sa, sb = PickScore(a, now), PickScore(b, now)
        if sa ~= sb then return sa > sb end
        if (a.at or 0) ~= (b.at or 0) then return (a.at or 0) > (b.at or 0) end
        return a == made and b ~= made
    end)
    local lead = picks[1]
    local prev
    for i = 2, LEARN_PICKS_MAX do
        if picks[i] then
            prev = prev or {}
            prev[#prev + 1] = picks[i]
        end
    end
    store[query] = { key = lead.key, n = lead.n, at = lead.at, w = lead.w, snapshot = lead.snapshot,
        prev = prev, last = now }
    TrimLearned(store)
end










local LEARN_PREFIX_MIN = 4








local function LearnedStillMatches(entry, queryLower)
    local db = ns.Database
    if not (db and db.ScoreName) then return true end
    local nameLower = (entry.nameLower or entry.name or ""):lower()
    if nameLower == "" then return true end
    local words = {}
    for w in queryLower:gmatch("%S+") do words[#words + 1] = w end
    if db:ScoreName(nameLower, queryLower, #queryLower, words) > 0 then return true end
    local kws = entry.keywordsLower or entry.keywords or entry.kwLower
    if kws and db.ScoreKeywords
       and db:ScoreKeywords(kws, queryLower, #queryLower, words) > 0 then
        return true
    end
    return false
end



local function ResolveRecord(store, queryLower)
    local rec, learnedQuery, typedPast = store[queryLower], queryLower, false
    if not rec and #queryLower >= 2 then
        local bestLen = 0
        for storedQuery, storedRec in pairs(store) do
            local ll, ql = #storedQuery, #queryLower
            if ll > bestLen and ll ~= ql and (ql > ll or ql >= LEARN_PREFIX_MIN) then

                local isPrefix
                if ll < ql then isPrefix = sfind(queryLower, storedQuery, 1, true) == 1
                else isPrefix = sfind(storedQuery, queryLower, 1, true) == 1 end
                if isPrefix then
                    bestLen = ll
                    rec = storedRec
                    learnedQuery = storedQuery
                    typedPast = ql > ll
                end
            end
        end
    end
    if not rec or not rec.key then return nil end
    return rec, learnedQuery, typedPast
end

function Learned:GetBoost(queryLower)
    if not (EasyFind and EasyFind.db) then return nil end
    if EasyFind.db.learnFromPicks == false then return nil end
    local store = EasyFind.db.queryLearn
    if type(store) ~= "table" then return nil end
    local rec, _, typedPast = ResolveRecord(store, queryLower)
    if not rec then return nil end
    local entry = SavedEntry(rec.key, rec.snapshot)
    if entry and typedPast and not LearnedStillMatches(entry, queryLower) then
        return nil
    end

    local extras
    if entry and rec.prev then
        for i = 1, #rec.prev do
            local p = rec.prev[i]
            local e = SavedEntry(p.key, p.snapshot)
            if e and e ~= entry and not (typedPast and not LearnedStillMatches(e, queryLower)) then
                extras = extras or {}
                extras[#extras + 1] = e
            end
        end
    end


    if extras then
        for i = #extras, 1, -1 do
            local e = extras[i]
            if e.available and not e.available() then table.remove(extras, i) end
        end
    end
    if entry and entry.available and not entry.available() then
        entry = extras and table.remove(extras, 1) or nil
    end
    if extras and #extras == 0 then extras = nil end
    return entry, extras
end





function Learned:FindPick(data, typedQuery)
    if not (EasyFind and EasyFind.db) then return nil end
    local store = EasyFind.db.queryLearn
    if type(store) ~= "table" then return nil end
    local key = Aliases:GetEntryKey(data)
    local query = normalize(strtrim(typedQuery or ""))
    if not key or query == "" then return nil end
    local rec, learnedQuery = ResolveRecord(store, query)
    if not rec then return nil end
    if rec.key == key then return learnedQuery end
    for i = 1, #(rec.prev or {}) do
        if rec.prev[i].key == key then return learnedQuery end
    end
    return nil
end





function Learned:Forget(data, typedQuery)
    local learnedQuery = self:FindPick(data, typedQuery)
    if not learnedQuery then return false end
    local store = EasyFind.db.queryLearn
    local rec = store[learnedQuery]
    local key = Aliases:GetEntryKey(data)
    local picks = {}
    if rec.key ~= key then
        picks[1] = { key = rec.key, n = rec.n, at = rec.at, w = rec.w, snapshot = rec.snapshot }
    end
    for i = 1, #(rec.prev or {}) do
        if rec.prev[i].key ~= key then picks[#picks + 1] = rec.prev[i] end
    end
    local lead = picks[1]
    if not lead then
        store[learnedQuery] = nil
        return true
    end
    local prev
    for i = 2, #picks do
        prev = prev or {}
        prev[#prev + 1] = picks[i]
    end
    store[learnedQuery] = { key = lead.key, n = lead.n, at = lead.at, w = lead.w, snapshot = lead.snapshot,
        prev = prev, last = rec.last }
    return true
end

function Learned:ClearAll()
    if EasyFind and EasyFind.db then EasyFind.db.queryLearn = {} end
end

local function ScoreDesc(a, b) return a.score > b.score end















function Aliases:GetMatches(queryLower)
    if not queryLower or queryLower == "" then return nil end
    if not EasyFind or not EasyFind.db or not EasyFind.db.aliases then return nil end
    local db = ns.Database
    if not (db and db.ScoreName) then return nil end
    local qLen = #queryLower
    local out
    for storedKey, info in pairs(EasyFind.db.aliases) do
        local score
        if storedKey == queryLower or qLen >= 2 then
            score = db:ScoreName(storedKey, queryLower, qLen)
        end
        if score and score > 0 then



            local mapCat = info.key and info.key:match("^mapcat:(.+)$")
            local entry
            if mapCat then
                entry = { mapCategoryAlias = mapCat, name = info.name }
            else
                entry = Aliases:FindEntryByKey(info.key)
            end


            if entry and not (entry.available and not entry.available()) then
                out = out or {}
                tinsert(out, { data = entry, alias = info, score = score })
            end
        end
    end
    if out and #out > 1 then tsort(out, ScoreDesc) end
    return out
end

return Aliases
