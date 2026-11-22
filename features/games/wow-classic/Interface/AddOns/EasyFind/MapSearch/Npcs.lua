


local _, ns = ...

local MapSearch = ns.MapSearch
local Search = ns.MapSearchSearch
if not (MapSearch and Search and Search.PreparePOI) then return end

local sbyte, schar, sfind, slower, sgmatch, ssub = string.byte, string.char, string.find, string.lower, string.gmatch, string.sub
local sformat = string.format
local mfloor, mmin, mmax, mceil = math.floor, math.min, math.max, math.ceil
local tsort, tconcat = table.sort, table.concat
local band, bor, lshift = bit.band, bit.bor, bit.lshift
local ZONE_ABBREVIATIONS = ns.MapUtils and ns.MapUtils.ZONE_ABBREVIATIONS or {}
local PreparePOI = Search.PreparePOI
local SliceCheckpoint = ns.Utils and ns.Utils.SliceCheckpoint or function() end

local MIN_QUERY = 3
local MAX_ROWS = 60
local TOWN_RADIUS2 = 300 ^ 2
local GRID = 4096
local DANGER_LEVELS = 3
local RED_LEVELS = 5
local SKULL_LEVELS = 10
local ZONE_LEVELS = 5
local DEADLY_STEP = 16
local TILE = 1600 / 3
local CELL = TILE / 4
local ORIGIN = 32 * TILE
local WEAPON = 2


local ROLE_GROUP = { quest = 1, vendor = 2 + 256, trainer = 4, flight = 8, services = 16 + 32 + 64 + 128 }



local SERVICES = {
    { bits = 2, en = "vendor vendors merchant seller sell sells buy shop", key = "NPC_WORDS_VENDOR" },
    { bits = 256, en = "repair", key = "NPC_WORDS_REPAIR" },
    { bits = 512, en = "food drink water", key = "NPC_WORDS_FOOD" },
    { bits = 1024, en = "ammo arrows bullets restock", key = "NPC_WORDS_AMMO" },
    { bits = 2048, en = "reagents restock", key = "NPC_WORDS_REAGENTS" },
    { bits = 8, en = "flight", key = "NPC_WORDS_FLIGHT" },
    { bits = 16, en = "inn innkeeper", key = "NPC_WORDS_INN" },
    { bits = 32, en = "bank banker", key = "NPC_WORDS_BANK" },
    { bits = 64, en = "auction auctioneer", key = "NPC_WORDS_AUCTION" },
    { bits = 128, en = "stable", key = "NPC_WORDS_STABLE" },
    { bits = 4096, en = "class trainer", key = "NPC_WORDS_CLASS_TRAINER" },
    { bits = 4, en = "trainer trainers", key = "NPC_WORDS_TRAINER" },
}


local CRAFTSMEN = {
    alchemy = "alchemist", blacksmithing = "blacksmith", enchanting = "enchanter", engineering = "engineer",
    herbalism = "herbalist", inscription = "scribe", jewelcrafting = "jewelcrafter",
    leatherworking = "leatherworker", mining = "miner", skinning = "skinner", tailoring = "tailor",
    cooking = "cook", fishing = "fisherman",
}
local function Craftsman(word)
    if #word < 4 then return nil end
    for craft, title in pairs(CRAFTSMEN) do
        if sfind(craft, word, 1, true) == 1 then return title end
    end
    return nil
end


local CLASS_TRAINER = 4096

local VENDOR = 2
local FAR = math.huge






local N = {
    n = nil,
    rec = "", spots = "", kinds = "", titleIdx = "",
    names = "", low = "", at = "", enNames = nil, enLow = nil, enAt = nil,
    titleName = {}, titleLow = {}, titleEnglish = {}, titleLowEnglish = {}, classTitle = {},
    spotCi = {}, spotWx = {}, spotWy = {}, planes = {}, mapNames = {},
    pois = setmetatable({}, { __mode = "v" }),
    hits = {}, top = {}, score = {}, words = {}, wordBits = {}, wordCraft = {}, spot = {}, near = {}, retailEntrance = {},
    mark = {}, cand = {}, titleHit = {}, gen = 0, hitLow = {}, hitEn = {}, scan = {}, len = {},
    titleAt = "", titleCreatures = "", roleIds = {},


    wordRole = {}, wordPlace = {}, hadPlace = {}, placeHit = {}, placeWordsOf = {}, placeList = {}, placeWords = {}, askWords = {}, mapSet = {},



    goodsN = nil, goodsText = "", goodsLow = "", goodsAt = "", goodsEnText = nil, goodsEnLow = nil, goodsEnAt = nil,
    goodsTypes = "", goodsListAt = "", goodsLists = "", sells = "", vendors = "",
    listHit = {}, itemScore = {}, matched = {}, sold = {}, goodsCand = {}, goodsSeen = {},


    typeName = {}, typeLow = {}, typeScore = {}, soldType = {},

    bestItem = nil, byItem = {},

    sellersOnly = nil,
    ROLE_GROUPS = { "quest", "vendor", "trainer", "flight", "services", "other" },

    decoratorWords = true,
}
ns.Npcs = N


N.data = ns.NPC_DATA



do
    local data = N.data
    if data and data.names and data.titleName then
        data.namesLow = slower(data.names)
        data.goodsNamesLow = data.goodsNames and slower(data.goodsNames)
        data.localNamesLow = data.localNames and slower(data.localNames)
        data.localGoodsLow = data.localGoods and slower(data.localGoods)
        local english, own = data.titleName, data.localTitleName
        if own and #own == #english then
            local en, enLow = {}, {}
            for t = 1, #english do
                if english[t] ~= own[t] then en[t], enLow[t] = english[t], slower(english[t]) end
            end
            data.titleName, data.titleEnglish, data.titleLowEnglish = own, en, enLow
        end
        local low = {}
        for t = 1, #data.titleName do low[t] = slower(data.titleName[t]) end
        data.titleLow = low
    end
end




local REC, SPOT = 12, 7
local function U16(s, p)
    local a, b = sbyte(s, p, p + 1)
    return a + b * 256
end
local function U24(s, p)
    local a, b, c = sbyte(s, p, p + 2)
    return a + b * 256 + c * 65536
end

local function At(s, i)
    return U24(s, i * 3 - 2)
end



local function LineStarts(text)
    if not text then return nil end
    local out, n, p = {}, 0, 1
    while true do
        local q = sfind(text, "\n", p, true)
        if not q then break end
        local v = q + 1
        n = n + 1
        out[n] = schar(v % 256, mfloor(v / 256) % 256, mfloor(v / 65536))
        p = v
        if n % 2048 == 0 then SliceCheckpoint() end
    end
    return tconcat(out)
end
N.LineStarts = LineStarts



do
    local function Warm()
        local data = N.data
        if not data or N.n then return end
        local Utils = ns.Utils
        local run = Utils and Utils.RunSliced or function(fn) fn() end
        run(function()
            if N.n then return end
            data.nameAt = data.nameAt or LineStarts(data.names)
            data.localNameAt = data.localNameAt or LineStarts(data.localNames)
            data.goodsNameAt = data.goodsNameAt or LineStarts(data.goodsNames)
            data.localGoodsAt = data.localGoodsAt or LineStarts(data.localGoods)
        end, function() end, 4, "npc line starts")
    end
    N.Warm = Warm
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()

        MapSearch.AppendNpcRows, MapSearch.NpcKindQuery = N.Append, N.KindQuery
        if ns.Utils and ns.Utils.SafeAfter then ns.Utils.SafeAfter(3, Warm) else Warm() end
    end)
end

local function Planes(p, width, i)
    local rec, n = N.rec, N.n
    local v, mul = 0, 1
    for b = p, p + width - 1 do
        v = v + sbyte(rec, b * n + i) * mul
        mul = mul * 256
    end
    return v
end
local Rec = {
    id = function(i) return Planes(0, 3, i) end,
    flags = function(i) return sbyte(N.rec, 3 * N.n + i) end,
    display = function(i) return Planes(4, 3, i) end,
    first = function(i) return Planes(7, 3, i) end,
    count = function(i) return Planes(10, 2, i) end,
}
local Spot = {
    map = function(k) return U16(N.spots, (k - 1) * SPOT + 1) end,
    xy = function(k) return U24(N.spots, (k - 1) * SPOT + 3) end,
    spawns = function(k) return U16(N.spots, (k - 1) * SPOT + 6) end,
}

local function Kind(i)
    return U24(N.kinds, i * 3 - 2)
end
local function Title(i)
    return U16(N.titleIdx, i * 2 - 1)
end

local function Roles(i)
    local roles = mfloor(Kind(i) / 256)
    if band(roles, 4) ~= 0 and band(roles, CLASS_TRAINER) == 0 and N.classTitle[Title(i)] then
        roles = roles + CLASS_TRAINER
    end
    return roles
end
N.Rec, N.Spot, N.Kind, N.Title = Rec, Spot, Kind, Title


local function LineAt(at, n, p)
    local lo, hi = 1, n
    while lo < hi do
        local mid = mfloor((lo + hi + 1) / 2)
        local a, b, c = sbyte(at, mid * 3 - 2, mid * 3)
        if a + b * 256 + c * 65536 <= p then lo = mid else hi = mid - 1 end
    end
    return lo
end


local function Line(text, at, i)
    return ssub(text, At(at, i), At(at, i + 1) - 2)
end

local function Name(i)
    return Line(N.names, N.at, i)
end


local function EnglishName(i)
    if not N.enNames then return nil end
    local en = Line(N.enNames, N.enAt, i)
    if en == "" or en == Name(i) then return nil end
    return en
end
N.Name = Name



function N.ByName(name)
    if not name or name == "" then return nil end
    if not (N.Load and N.Load()) then return nil end
    local key = "\n" .. string.lower(name) .. "\n"
    local p, at = sfind(N.low, key, 1, true), N.at
    if not p and N.enLow then p, at = sfind(N.enLow, key, 1, true), N.enAt end
    if not p then return nil end
    local i = LineAt(at, N.n, p + 1)
    local display = Rec.display(i)
    return { name = Name(i), npcID = Rec.id(i), displayID = display ~= 0 and display or nil }
end


local serviceWords
local function ServiceWords()
    if serviceWords then return serviceWords end
    serviceWords = {}
    for _, s in ipairs(SERVICES) do
        local seen = {}
        for w in sgmatch(slower(s.en .. " " .. (ns.L[s.key] or "")), "%S+") do
            if not seen[w] then
                seen[w] = true
                serviceWords[#serviceWords + 1] = { word = w, bits = s.bits }
            end
        end
    end
    return serviceWords
end

local function Unpack(s)
    local E = C_EncodingUtil
    local method = Enum and Enum.CompressionMethod and Enum.CompressionMethod.Deflate or 0
    return E.DecompressString(E.DecodeBase64(s), method)
end



local function Bind()
    local data = N.data
    local rec, at = data and data.rec, data and (data.nameAt or LineStarts(data.names))
    if not (rec and at and data.spots and data.kinds and data.titleIdx and data.names and data.namesLow
            and data.titleAt and data.titleCreatures and data.titleName and data.titleLow) then
        N.n = 0
        return
    end

    local count = mfloor(#rec / REC)
    if #at ~= (count + 1) * 3 then N.n = 0 return end
    N.rec, N.spots, N.kinds, N.titleIdx = rec, data.spots, data.kinds, data.titleIdx
    N.titleAt, N.titleCreatures = data.titleAt, data.titleCreatures

    local own = data.localNames
    local ownAt = data.localNameAt or LineStarts(own)
    if own and ownAt and data.localNamesLow and #ownAt == #at then
        N.names, N.at, N.low = own, ownAt, data.localNamesLow
        N.enNames, N.enAt, N.enLow = data.names, at, data.namesLow
    else
        N.names, N.at, N.low = data.names, at, data.namesLow
    end
    N.roleIds = data.roles or {}
    N.planes = data.planes or {}
    N.titleName, N.titleLow, N.classTitle = data.titleName, data.titleLow, data.classTitle or {}
    N.titleEnglish, N.titleLowEnglish = data.titleEnglish or {}, data.titleLowEnglish or {}
    N.sqLow, N.sqAt, N.sqEnLow, N.sqEnAt = nil, nil, nil, nil
    N.n = count
end

local function Load()
    if not N.n then Bind() end
    return N.n > 0
end
N.Load = Load




local function LoadGoods()
    if N.goodsN then return N.goodsN > 0 end
    local data = N.data
    if not (data and data.goodsTypes and Load()) then N.goodsN = 0 return false end
    local types, text = data.goodsTypes, data.goodsNames
    local at = data.goodsNameAt or LineStarts(text)
    if not (data.goodsListAt and data.goodsLists and data.sells and data.vendors and text and at
            and data.goodsNamesLow) or #at ~= (#types + 1) * 3 then
        N.goodsN = 0
        return false
    end
    N.goodsTypes, N.goodsListAt, N.goodsLists = types, data.goodsListAt, data.goodsLists
    N.sells, N.vendors = data.sells, data.vendors
    local own = data.localGoods
    local ownAt = data.localGoodsAt or LineStarts(own)
    if own and ownAt and data.localGoodsLow and #ownAt == #at then
        N.goodsText, N.goodsAt, N.goodsLow = own, ownAt, data.localGoodsLow
        N.goodsEnText, N.goodsEnAt, N.goodsEnLow = text, at, data.goodsNamesLow
    else
        N.goodsText, N.goodsAt, N.goodsLow = text, at, data.goodsNamesLow
    end
    for _, t in ipairs(data.goodsTypeIds or {}) do
        local name = C_Item.GetItemSubClassInfo(WEAPON, t)
        N.typeName[t], N.typeLow[t] = name, name and name ~= "" and slower(name) or false
    end
    N.goodsN = #types
    return N.goodsN > 0
end
N.LoadGoods = LoadGoods

local function Ready()
    local ok = Load()
    LoadGoods()
    return ok
end


local function GoodsName(j)
    return Line(N.goodsText, N.goodsAt, j)
end
N.GoodsName = GoodsName
local function GoodsEnglishLow(j)
    if not N.goodsEnText then return nil end
    local a, b = At(N.goodsEnAt, j), At(N.goodsEnAt, j + 1) - 2
    if ssub(N.goodsEnText, a, b) == GoodsName(j) then return nil end
    return ssub(N.goodsEnLow, a, b)
end


local function ListSpan(j)
    return At(N.goodsListAt, j), At(N.goodsListAt, j + 1) - 1
end
local function ListOf(o)
    return U16(N.goodsLists, o * 2 + 1)
end


local function Sells(i)
    local l = U16(N.sells, i * 2 - 1)
    return l ~= 0 and l or nil
end


local function GoodsWord(w)
    return not N.wordPlace[w] and band(N.wordBits[w], VENDOR) == 0
end



local function WordsScore(low, alt)
    local words = N.words
    local score, first = 0, true
    for w = 1, #words do
        if GoodsWord(w) then
            local word = words[w]
            local at = sfind(low, word, 1, true)
            local altAt = alt and sfind(alt, word, 1, true)
            if not (at or altAt) then return 0 end
            if first then
                first = false
                local s, pos = at and low or alt, at or altAt
                if pos == 1 then score = 3
                elseif ssub(s, pos - 1, pos - 1) == " " then score = 2
                else score = 1 end
            end
        end
    end
    return score
end


local function MarkLines(blob, at, n, word, mark)
    local p = sfind(blob, word, 1, true)
    while p do
        local i = LineAt(at, n, p)
        mark(i)
        p = sfind(blob, word, At(at, i + 1), true)
    end
end

local function MarkGoods(j)
    if N.goodsSeen[j] ~= N.gen then
        N.goodsSeen[j] = N.gen
        local cand = N.goodsCand
        cand[#cand + 1] = j
    end
end



local function MatchGoods()
    local listHit, itemScore, matched, soldType = N.listHit, N.itemScore, N.matched, N.soldType
    for m = #matched, 1, -1 do
        local a, b = ListSpan(matched[m])
        for o = a, b do listHit[ListOf(o)] = nil end
        itemScore[matched[m]] = nil
        soldType[matched[m]] = nil
        matched[m] = nil
    end
    N.bestItem = nil
    if not LoadGoods() then return false end
    local words = N.words
    local first
    for w = 1, #words do
        if GoodsWord(w) then
            first = words[w]
            break
        end
    end
    if not first then return false end


    N.gen = N.gen + 1
    local cand = N.goodsCand
    for c = #cand, 1, -1 do cand[c] = nil end
    MarkLines(N.goodsLow, N.goodsAt, N.goodsN, first, MarkGoods)
    if N.goodsEnLow then MarkLines(N.goodsEnLow, N.goodsEnAt, N.goodsN, first, MarkGoods) end
    local typeScore, types = N.typeScore, N.goodsTypes
    for t, low in pairs(N.typeLow) do
        typeScore[t] = low and WordsScore(low) or 0
        if typeScore[t] > 0 then
            local byte = schar(t + 1)
            local j = sfind(types, byte, 1, true)
            while j do
                MarkGoods(j)
                j = sfind(types, byte, j + 1, true)
            end
        end
    end
    tsort(cand)
    for c = 1, #cand do
        local j = cand[c]
        local a, b = At(N.goodsAt, j), At(N.goodsAt, j + 1) - 2
        local s = WordsScore(ssub(N.goodsLow, a, b), GoodsEnglishLow(j))


        local t = sbyte(types, j) - 1
        if t >= 0 and typeScore[t] > s then
            s = typeScore[t]
            soldType[j] = t
        end
        if s > 0 then
            itemScore[j] = s
            matched[#matched + 1] = j
            if not N.bestItem or s > itemScore[N.bestItem] then N.bestItem = j end
            local la, lb = ListSpan(j)
            for o = la, lb do
                local l = ListOf(o)
                local best = listHit[l]
                if not best or s > itemScore[best]
                    or (s == itemScore[best] and b - a < At(N.goodsAt, best + 1) - At(N.goodsAt, best) - 2) then
                    listHit[l] = j
                end
            end
        end
    end
    return #matched > 0
end


local entrances
local function Entrance(id)
    if not entrances then
        entrances = {}
        for _, e in ipairs(ns.FOREVER_INSTANCES or {}) do
            if not entrances[e.id] then entrances[e.id] = e end
        end
    end
    return entrances[id]
end



local function RetailEntrance(mapID)
    local kept = N.retailEntrance[mapID]
    if kept ~= nil then return kept or nil end
    local EJ = C_EncounterJournal
    if not (EJ and EJ.GetInstanceForGameMap and EJ_GetInstanceInfo and MapSearch.HasGlobalInstanceCache
            and MapSearch:HasGlobalInstanceCache()) then
        return nil
    end
    N.retailEntrance[mapID] = false
    local jid = EJ.GetInstanceForGameMap(mapID)
    local name = jid and EJ_GetInstanceInfo(jid)
    if not name then return nil end
    for _, e in ipairs(MapSearch:GetGlobalInstanceCache() or {}) do
        if e.name == name and e.entranceMapID and e.x then
            local found = { m = e.entranceMapID, x = e.x, y = e.y, n = name }
            N.retailEntrance[mapID] = found
            return found
        end
    end
    return nil
end


local function SpotPoint(k)
    local m = Spot.map(k)
    if m == 0 then
        local e

        if ns.Caps and ns.Caps.instanceTable then e = Entrance(Spot.xy(k)) else e = RetailEntrance(Spot.xy(k)) end
        if e then return e.m, e.x, e.y, e end
        return nil
    end
    local xy = Spot.xy(k)
    return m, mfloor(xy / GRID) / (GRID - 1), (xy % GRID) / (GRID - 1)
end

local function SpotWorld(k)
    local ci = N.spotCi[k]
    if ci == nil then
        ci = false
        local m, x, y, e = SpotPoint(k)


        local plane = m and not e and N.planes[m]
        if e and e.ci then
            ci, N.spotWx[k], N.spotWy[k] = e.ci, e.wx, e.wy
        elseif plane then
            ci, N.spotWx[k], N.spotWy[k] = plane[1], plane[2] + plane[3] * y, plane[4] + plane[5] * x
        elseif m and C_Map.GetWorldPosFromMapPos and CreateVector2D then
            local ok, c, pos = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(x, y))
            if ok and pos then ci, N.spotWx[k], N.spotWy[k] = c, pos:GetXY() end
        end
        N.spotCi[k] = ci
    end
    return ci, N.spotWx[k], N.spotWy[k]
end





local function SpotRange(i)
    local rec, n = N.rec, N.n
    local first = sbyte(rec, 7 * n + i) + sbyte(rec, 8 * n + i) * 256 + sbyte(rec, 9 * n + i) * 65536
    return first, first + sbyte(rec, 10 * n + i) + sbyte(rec, 11 * n + i) * 256 - 1
end





local byLow, nextSame, byID
local function IndexNames()
    byLow, nextSame = {}, {}
    local low, at, tail = N.low, N.at, {}
    for i = 1, N.n do
        local name = ssub(low, At(at, i), At(at, i + 1) - 2)
        local first = byLow[name]
        if first then
            nextSame[tail[first]] = i
            tail[first] = i
        else
            byLow[name], tail[i] = i, i
        end
    end
end

function N.NamedOn(name, maps)
    if not (type(name) == "string" and name ~= "" and Load()) then return nil end
    if not byLow then IndexNames() end
    local i = byLow[slower(name)]
    while i do
        local first, last = SpotRange(i)
        for k = first, last do
            local m = SpotPoint(k)
            if m and maps[m] then return Rec.id(i) end
        end
        i = nextSame[i]
    end
    return nil
end


local function IndexOfID(npcID)
    if not byID then
        byID = {}
        for i = 1, N.n do byID[Rec.id(i)] = i end
    end
    return byID[npcID]
end

function N.HasID(npcID)
    if not Load() then return false end
    return IndexOfID(npcID) ~= nil
end


function N.NameOfID(npcID)
    if not Load() then return nil end
    local i = IndexOfID(npcID)
    return i and Name(i) or nil
end




local wordedIDs = {}
local function WordedIDs(word)
    local E = ns.Extensions
    if not (E and E.NpcsWithWord) then return nil end
    wipe(wordedIDs)
    E.NpcsWithWord(word, wordedIDs)
    return next(wordedIDs) and wordedIDs or nil
end

local function Worded(i, word)
    local E = ns.Extensions
    local words = E and E.NpcWords and E.NpcWords(Rec.id(i))
    for k = 1, words and #words or 0 do
        if sfind(words[k], word, 1, true) then return true end
    end
    return false
end



local function Within(i, set, pci, px, py, r2)
    local spots = N.spots
    local first, last = SpotRange(i)
    for k = first, last do
        local p = (k - 1) * SPOT + 1
        local a, b = sbyte(spots, p, p + 1)
        if not set or set[a + b * 256] then
            if not r2 then return true end
            local ci, wx, wy = SpotWorld(k)
            if ci == pci and (wx - px) ^ 2 + (wy - py) ^ 2 <= r2 then return true end
        end
    end
    return false
end




function N.TitledNear(title, ci, x, y, r, others)
    if not Load() then return nil end
    local want = slower(title)
    local best, bestD
    for t = 1, #N.titleLow do
        if (N.titleLowEnglish[t] or N.titleLow[t]) == want then
            for o = At(N.titleAt, t) + 1, At(N.titleAt, t + 1) do
                local i = At(N.titleCreatures, o)
                local first, last = SpotRange(i)
                for k = first, last do
                    local sci, wx, wy = SpotWorld(k)
                    local d = sci == ci and wx and (wx - x) ^ 2 + (wy - y) ^ 2
                    if d and d <= r * r and (not bestD or d < bestD) then
                        local mine = true
                        for _, p in ipairs(others or {}) do
                            if (wx - p[1]) ^ 2 + (wy - p[2]) ^ 2 < d then mine = false end
                        end
                        if mine then best, bestD = i, d end
                    end
                end
            end
        end
    end
    return best and Name(best) or nil
end



local function BestSpot(i, set, pci, px, py, r2)
    local best, bestD, most, mostN
    local spots = N.spots
    local first, last = SpotRange(i)
    for k = first, last do
        local p = (k - 1) * SPOT + 1
        local a, b = sbyte(spots, p, p + 1)
        if not set or set[a + b * 256] then
            local d
            if pci then
                local ci, wx, wy = SpotWorld(k)
                if ci == pci then d = (wx - px) ^ 2 + (wy - py) ^ 2 end
            end
            if not r2 or (d and d <= r2) then
                if d and (not bestD or d < bestD) then best, bestD = k, d end
                local s1, s2 = sbyte(spots, p + 5, p + 6)
                local spawns = s1 + s2 * 256
                if not most or spawns > mostN then most, mostN = k, spawns end
            end
        end
    end
    return best or most
end




local function AlongSpot(i, set, along)
    local best, bestSec
    local first = Rec.first(i)
    for k = first, first + Rec.count(i) - 1 do
        if not set or set[Spot.map(k)] then
            local ci, wx, wy = SpotWorld(k)
            local sec = ci and along(ci, wx, wy)
            if sec and (not bestSec or sec < bestSec) then best, bestSec = k, sec end
        end
    end
    return best, bestSec
end

local function PlayerWorld()
    local m = C_Map.GetBestMapForUnit("player")
    if not m then return nil end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, m, "player")
    if not (ok and pos) then return nil end
    local ok2, ci, wp = pcall(C_Map.GetWorldPosFromMapPos, m, pos)
    if not (ok2 and wp) then return nil end
    return ci, wp:GetXY()
end





function N.SpotOfID(npcID)
    if not (npcID and Load()) then return nil end
    local i = IndexOfID(npcID)
    if not i then return nil end
    local pci, px, py = PlayerWorld()
    local k = BestSpot(i, nil, pci, px, py)
    local m, x, y
    if k then m, x, y = SpotPoint(k) end
    if not m then return nil end
    local display = Rec.display(i)
    return { name = Name(i), npcID = Rec.id(i), displayID = display ~= 0 and display or nil,
             mapID = m, x = x, y = y, category = "npc" }
end

local function MapName(m)
    local name = N.mapNames[m]
    if name == nil then
        local info = C_Map.GetMapInfo(m)
        name = info and info.name or false
        N.mapNames[m] = name
    end
    return name or nil
end




local function LineHits(blob, at, n, word, into)
    local p = sfind(blob, word, 1, true)
    while p do
        local i = LineAt(at, n, p)
        into[i] = p
        p = sfind(blob, word, At(at, i + 1), true)
    end
end





local function Joined()
    if N.sqAt == nil then
        local sqLow = (N.low:gsub("[ ']", ""))
        local sqAt = LineStarts(sqLow)
        local sqEnLow, sqEnAt
        if N.enLow then
            sqEnLow = (N.enLow:gsub("[ ']", ""))
            sqEnAt = LineStarts(sqEnLow)
        end
        N.sqLow, N.sqAt, N.sqEnLow, N.sqEnAt = sqLow, sqAt, sqEnLow, sqEnAt
    end
    return N.sqLow, N.sqAt, N.sqEnLow, N.sqEnAt
end




local joinedHits = {}
local function WordHits(word, low, en)
    LineHits(N.low, N.at, N.n, word, low)
    if N.enLow then LineHits(N.enLow, N.enAt, N.n, word, en) end
    if next(low) or next(en) then return end
    local sqLow, sqAt, sqEnLow, sqEnAt = Joined()
    wipe(joinedHits)
    LineHits(sqLow, sqAt, N.n, word, joinedHits)
    for i, p in pairs(joinedHits) do low[i] = At(N.at, i) + (p == At(sqAt, i) and 0 or 1) end
    if sqEnLow then
        wipe(joinedHits)
        LineHits(sqEnLow, sqEnAt, N.n, word, joinedHits)
        for i, p in pairs(joinedHits) do en[i] = At(N.enAt, i) + (p == At(sqEnAt, i) and 0 or 1) end
    end
end



local function NamedByAll()
    local words, hitLow, hitEn = N.words, N.hitLow, N.hitEn
    for w = 1, #words do
        local low, en = hitLow[w], hitEn[w]
        if low then wipe(low) else low = {}; hitLow[w] = low end
        if en then wipe(en) else en = {}; hitEn[w] = en end
        WordHits(words[w], low, en)
    end
    for _, first in ipairs({ hitLow[1], hitEn[1] }) do
        for i in pairs(first) do
            local all = true
            for w = 2, #words do
                if not (hitLow[w][i] or hitEn[w][i]) then all = false break end
            end
            if all then return true end
        end
    end
    return false
end


local function MarkWordHits()
    local words, wordPlace = N.words, N.wordPlace
    for w = 1, #words do
        local low, en = N.hitLow[w], N.hitEn[w]
        if low then wipe(low) else low = {}; N.hitLow[w] = low end
        if en then wipe(en) else en = {}; N.hitEn[w] = en end
        if not wordPlace[w] then WordHits(words[w], low, en) end
    end
end




local function Score(i)
    local words, wordPlace, low, at, enLow, enAt = N.words, N.wordPlace, N.low, N.at, N.enLow, N.enAt
    local wordBits, hitLow, hitEn, allService = N.wordBits, N.hitLow, N.hitEn, N.allService

    local t1, t2 = sbyte(N.titleIdx, i * 2 - 1, i * 2)
    local t = t1 + t2 * 256
    local _, k2, k3 = sbyte(N.kinds, i * 3 - 2, i * 3)
    local roles = k2 + k3 * 256
    if band(roles, 4) ~= 0 and band(roles, CLASS_TRAINER) == 0 and N.classTitle[t] then
        roles = roles + CLASS_TRAINER
    end
    local tlow, tAlt = N.titleLow[t], N.titleLowEnglish[t]
    local score, first = 0, true
    for w = 1, #words do
        if not wordPlace[w] then
            local word = words[w]


            if allService and band(roles, wordBits[w]) == 0 then return 0 end
            local p, blob, lines = hitLow[w][i], low, at
            if not p and enLow then p, blob, lines = hitEn[w][i], enLow, enAt end
            local craft = N.wordCraft[w]
            if not p and not (tlow and sfind(tlow, word, 1, true)) and not (tAlt and sfind(tAlt, word, 1, true))
                and not (craft and ((tlow and sfind(tlow, craft, 1, true)) or (tAlt and sfind(tAlt, craft, 1, true))))
                and band(roles, wordBits[w]) == 0 and not Worded(i, word) then
                return 0
            end
            if first then
                first = false
                local a1, a2, a3
                if p then a1, a2, a3 = sbyte(lines, i * 3 - 2, i * 3) end
                if p and p == a1 + a2 * 256 + a3 * 65536 then score = 3
                elseif p and sbyte(blob, p - 1) == 32 then score = 2
                else score = 1 end
            end
        end
    end
    return score
end


local function HitLess(a, b)
    local sa, sb = N.score[a], N.score[b]
    if sa ~= sb then return sa > sb end
    local na, nb = N.near[a], N.near[b]
    if na ~= nb then return na < nb end
    local la, lb = N.len[a], N.len[b]
    if la ~= lb then return la < lb end
    return a < b
end



local function TopRows(hits, n)
    local top, k = N.top, 0
    for j = 1, n do
        local h = hits[j]
        if k < MAX_ROWS or HitLess(h, top[k]) then
            if k < MAX_ROWS then k = k + 1 end
            local p = k
            while p > 1 and HitLess(h, top[p - 1]) do
                top[p] = top[p - 1]
                p = p - 1
            end
            top[p] = h
        end
    end
    for j = 1, k do hits[j] = top[j] end
end

local function Row(i, k)
    local m, x, y, e = SpotPoint(k)
    if not m then return nil end
    local poi = N.pois[i]
    if not poi then


        local keywords = {}
        local t = Title(i)
        if N.titleName[t] and N.titleName[t] ~= "" then keywords[#keywords + 1] = N.titleName[t] end
        local english = EnglishName(i)
        if english then keywords[#keywords + 1] = english end
        if N.titleEnglish[t] then keywords[#keywords + 1] = N.titleEnglish[t] end
        local roles = Roles(i)
        for _, s in ipairs(ServiceWords()) do
            if band(roles, s.bits) ~= 0 then keywords[#keywords + 1] = s.word end
        end


        local low = N.titleLowEnglish[t] or N.titleLow[t]
        if low then
            for craft, title in pairs(CRAFTSMEN) do
                local p = sfind(low, title, 1, true)
                if p and (p == 1 or not sfind(ssub(low, p - 1, p - 1), "%a")) then
                    keywords[#keywords + 1] = craft
                    break
                end
            end
        end
        local display = Rec.display(i)
        local title = N.titleName[t]
        poi = { name = Name(i), category = "npc", isStatic = true, npcID = Rec.id(i), catalog = true,
                displayID = display ~= 0 and display or nil,

                npcTitle = title and title ~= "" and title or nil,
                keywords = #keywords > 0 and keywords or nil }
        poi.baseKeywords = poi.keywords
        PreparePOI(poi)
        N.pois[i] = poi
    end



    local j = N.sold[i] or nil
    local t = j and N.soldType[j]
    local soldName = j and (t and N.typeName[t] or GoodsName(j)) or nil



    local scoredAs = N.byItem[i] and N.bestItem or nil
    local placeKey, askKey = N.placeKey, N.askKey
    if poi.soldName ~= soldName or poi.placeKey ~= placeKey or poi.askKey ~= askKey or poi.scoredAs ~= scoredAs then
        poi.soldName, poi.placeKey, poi.askKey, poi.scoredAs = soldName, placeKey, askKey, scoredAs
        local keywords = poi.baseKeywords
        if soldName or placeKey or askKey then
            keywords = {}
            local item = scoredAs or j
            if item then
                local it = N.soldType[item]
                keywords[1] = it and N.typeName[it] or GoodsName(item)
                if not it then keywords[2] = GoodsEnglishLow(item) end
            end


            for w = 1, #N.words do
                if N.wordPlace[w] or (askKey and band(N.wordBits[w], VENDOR) ~= 0) then
                    keywords[#keywords + 1] = N.words[w]
                end
            end
            if not scoredAs then
                for w = 1, #(poi.baseKeywords or {}) do keywords[#keywords + 1] = poi.baseKeywords[w] end
            end
        end
        poi.keywords, poi.kwLower, poi.searchMask = keywords, nil, nil
        poi.matchNote = soldName and sformat(ns.L["NPC_SELLS"] or "Sells %s", soldName) or nil
        PreparePOI(poi)
    end
    poi.mapID, poi.coordMapID, poi.x, poi.y = m, m, x, y
    poi.zoneName = e and e.n or MapName(m)
    poi.score, poi.duplicateKey, poi.allInstances = nil, nil, nil
    return poi
end




function N.RowOfID(npcID)
    if not (npcID and Load()) then return nil end
    local i = IndexOfID(npcID)
    if not i then return nil end
    local pci, px, py = PlayerWorld()
    local k = BestSpot(i, nil, pci, px, py)
    local poi = k and Row(i, k)
    if not poi then return nil end
    local row = {}
    for key, v in pairs(poi) do row[key] = v end
    row.soldName, row.matchNote, row.scoredAs, row.keywords = nil, nil, nil, poi.baseKeywords
    return row
end





local function Passes(i, f, horde)
    local kind = Kind(i)
    if f.type and f.type[kind % 16] == false then return false end
    if f.expansion and f.expansion[mfloor(kind / 16) % 16 - 1] == false then return false end
    local roleF = f.role
    if roleF then
        local roles = mfloor(kind / 256)
        if roles == 0 then
            if roleF.other == false then return false end
        else
            local any = false
            for group, bits in pairs(ROLE_GROUP) do
                if roleF[group] ~= false and band(roles, bits) ~= 0 then
                    any = true
                    break
                end
            end
            if not any then return false end
        end
    end
    if f.reaction and f.reaction[mfloor(Rec.flags(i) / (horde and 32 or 8)) % 4] == false then return false end
    return true
end


local function Mark(i)
    if N.mark[i] ~= N.gen then
        N.mark[i] = N.gen
        local cand = N.cand
        cand[#cand + 1] = i
    end
end


local function WordStarts(low, word)
    local p = sfind(low, word, 1, true)
    while p do
        if p == 1 or sbyte(low, p - 1) == 32 then return true end
        p = sfind(low, word, p + 1, true)
    end
    return false
end


local function TitleWord(word)
    local titleLow, titleLowEnglish = N.titleLow, N.titleLowEnglish
    for t = 1, #titleLow do
        if WordStarts(titleLow[t], word) or (titleLowEnglish[t] and WordStarts(titleLowEnglish[t], word)) then
            return true
        end
    end
    return false
end



function N.KindQuery(query)
    if not Ready() then return false end
    local any = false
    for word in sgmatch(slower(query), "%S+") do
        if #word < MIN_QUERY then return false end
        local kind = TitleWord(word)
        if not kind then
            for _, s in ipairs(ServiceWords()) do
                if sfind(s.word, word, 1, true) == 1 then
                    kind = true
                    break
                end
            end
        end
        if not kind then return false end
        any = true
    end
    return any
end



local towns
local function Towns()
    if towns then return towns end
    towns = {}
    local binds = ns.GPSData and ns.GPSData.binds
    if not (binds and C_Map.GetAreaInfo) then return towns end
    for area, p in pairs(binds) do
        local ok, name = pcall(C_Map.GetAreaInfo, area)
        if ok and name and p.ci then
            towns[#towns + 1] = { town = true, low = slower(name), ci = p.ci, wx = p.wx, wy = p.wy }
        end
    end
    return towns
end


local descendants = {}
local function AddMaps(set, m)
    set[m] = true
    local kids = descendants[m]
    if not kids then
        kids = {}
        local ok, list = pcall(C_Map.GetMapChildrenInfo, m, nil, true)
        for _, c in ipairs(ok and list or {}) do kids[#kids + 1] = c.mapID end
        descendants[m] = kids
    end
    for _, c in ipairs(kids) do set[c] = true end
end

local function Named(place, w)
    local hit, wordsOf = N.placeHit, N.placeWordsOf
    if not hit[place] then
        N.placeList[#N.placeList + 1] = place
        hit[place], wordsOf[place] = 0, 0
    end
    hit[place], wordsOf[place] = hit[place] + 1, bor(wordsOf[place], lshift(1, w - 1))
end





local function Places()
    local words, wordRole, wordPlace = N.words, N.wordRole, N.wordPlace
    local hit, wordsOf, list, mapSet = N.placeHit, N.placeWordsOf, N.placeList, N.mapSet
    wipe(hit)
    wipe(wordsOf)
    wipe(mapSet)
    for p = #list, 1, -1 do list[p] = nil end
    local placeWords = 0
    for w = 1, #words do
        local word = words[w]
        if not wordRole[w] then
            local named = false
            local prefix = #word >= 4
            for _, t in ipairs(Towns()) do
                if t.low == word or (prefix and WordStarts(t.low, word)) then
                    Named(t, w)
                    named = true
                end
            end
            local zones = MapSearch.ZonesNamed and MapSearch:ZonesNamed(word)
            for z = 1, zones and #zones or 0 do
                Named(zones[z], w)
                named = true
            end
            if named then placeWords = placeWords + 1 end
        end
    end
    if placeWords == 0 or placeWords == #words then return nil end
    local most = 0
    for p = 1, #list do
        if hit[list[p]] > most then most = hit[list[p]] end
    end
    local town, mask
    for p = 1, #list do
        local place = list[p]
        if hit[place] == most and place.town then
            town = place
            break
        end
    end
    if town then
        mask = wordsOf[town]
    else
        mask = 0
        for p = 1, #list do
            local place = list[p]
            if hit[place] == most then
                AddMaps(mapSet, place.mapID)
                mask = bor(mask, wordsOf[place])

                for w = 1, #words do
                    if not wordRole[w] and #words[w] <= 3 and sfind(place.nameLower or "", words[w] .. " ", 1, true) == 1 then
                        mask = bor(mask, lshift(1, w - 1))
                    end
                end
            end
        end
    end
    for w = 1, #words do wordPlace[w] = band(mask, lshift(1, w - 1)) ~= 0 or nil end
    return town, true
end



local function MarkTitlesAndRoles(titleHit, bits)
    local scan, lists = N.scan, 0
    for c = #scan, 1, -1 do scan[c] = nil end
    local titleAt, titleCreatures = N.titleAt, N.titleCreatures
    local sn = 0
    for t = 1, #N.titleLow do
        if titleHit[t] then
            for o = At(titleAt, t) + 1, At(titleAt, t + 1) do
                local a, b, c = sbyte(titleCreatures, o * 3 - 2, o * 3)
                sn = sn + 1
                scan[sn] = a + b * 256 + c * 65536
            end
            lists = lists + 1
        end
    end
    local role = 1
    while role <= bits do
        if band(bits, role) ~= 0 then
            local ids = N.roleIds[role] or ""
            for o = 1, #ids / 3 do
                local a, b, c = sbyte(ids, o * 3 - 2, o * 3)
                sn = sn + 1
                scan[sn] = a + b * 256 + c * 65536
            end
            lists = lists + 1
            if role == CLASS_TRAINER then
                for t = 1, #N.titleLow do
                    if N.classTitle[t] then
                        for o = At(titleAt, t) + 1, At(titleAt, t + 1) do
                            local i = At(titleCreatures, o)
                            if band(mfloor(Kind(i) / 256), 4) ~= 0 then
                                sn = sn + 1
                                scan[sn] = i
                            end
                        end
                        lists = lists + 1
                    end
                end
            end
        end
        role = role * 2
    end
    if lists > 1 then tsort(scan) end
    for c = 1, #scan do
        Mark(scan[c])
        if c % 512 == 0 then SliceCheckpoint() end
    end
end




local function GoodsNamed(j, low)
    return ssub(N.goodsLow, At(N.goodsAt, j), At(N.goodsAt, j + 1) - 2) == low or GoodsEnglishLow(j) == low
end

local function Keep(set, pci, px, py, r2, goods, f, horde, service)
    local cand, hits, score = N.cand, N.hits, N.score
    local listHit, sold, len, at = N.listHit, N.sold, N.len, N.at
    local n = 0
    for c = 1, #cand do
        local i = cand[c]
        local s = Score(i)



        local l = goods and Sells(i)
        local j = l and listHit[l] or false
        if j and N.itemScore[j] < 2 then j = false end
        if j and N.sellersOnly and not GoodsNamed(j, N.sellersOnly) then j = false end
        local byItem = false
        if s == 0 and j then s, byItem = N.itemScore[N.bestItem], true end
        if s > 0 and (set or r2) and not Within(i, set, pci, px, py, r2) then s = 0 end
        if s > 0 and f and not Passes(i, f, horde) then s = 0 end
        if s > 0 and (service or byItem) and mfloor(sbyte(N.rec, 3 * N.n + i) / (horde and 32 or 8)) % 4 == 2 then
            s = 0
        end
        if s > 0 then
            n = n + 1
            hits[n] = i
            score[i] = s
            sold[i] = j
            local a1, a2, a3, b1, b2, b3 = sbyte(at, i * 3 - 2, i * 3 + 3)
            len[i] = (b1 + b2 * 256 + b3 * 65536) - (a1 + a2 * 256 + a3 * 65536)
            N.byItem[i] = byItem
        end
        if c % 256 == 0 then SliceCheckpoint() end
    end
    for j = #hits, n + 1, -1 do hits[j] = nil end
    return n
end





local function ItemNamedByAll()
    local words, wordPlace, had = N.words, N.wordPlace, N.hadPlace
    for w = 1, #words do had[w], wordPlace[w] = wordPlace[w], nil end
    local named = false
    if MatchGoods() then
        local matched = N.matched
        for m = 1, #matched do
            local j = matched[m]
            local low = ssub(N.goodsLow, At(N.goodsAt, j), At(N.goodsAt, j + 1) - 2)
            local en = GoodsEnglishLow(j)
            local all = true
            for w = 1, #words do
                if GoodsWord(w) and not (WordStarts(low, words[w]) or (en and WordStarts(en, words[w]))) then
                    all = false
                    break
                end
            end
            if all then named = true break end
        end
    end
    for w = 1, #words do wordPlace[w] = had[w] end
    if not named then MatchGoods() end
    return named
end








function N.Append(out, nameSet, query, onlyMap, nearMap, along)
    if not query or #query < MIN_QUERY then return false end

    if along then Load() end
    if not Ready() then return false end
    local words, wordBits, wordRole, wordPlace = N.words, N.wordBits, N.wordRole, N.wordPlace
    for w = #words, 1, -1 do words[w], wordRole[w], wordPlace[w] = nil, nil, nil end
    for word in sgmatch(slower(query), "%S+") do words[#words + 1] = word end
    if #words == 0 then return false end

    local service, allService = false, true
    for w = 1, #words do
        local bits = 0
        if #words[w] >= MIN_QUERY then
            for _, s in ipairs(ServiceWords()) do
                if sfind(s.word, words[w], 1, true) == 1 then bits = bor(bits, s.bits) end
            end
        end
        wordBits[w] = bits
        N.wordCraft[w] = Craftsman(words[w])
        if bits ~= 0 then service = true else allService = false end


        wordRole[w] = bits ~= 0 or (not ZONE_ABBREVIATIONS[words[w]] and TitleWord(words[w]))
            or (#words[w] >= MIN_QUERY and WordedIDs(words[w]) ~= nil)
    end
    N.allService = service and allService

    local sellers = N.sellersOnly
    local town, placed = nil, false
    if not sellers then town, placed = Places() end
    local goods = MatchGoods()
    if placed then




        local plain = NamedByAll() or ItemNamedByAll()
        for w = 1, #words do
            if plain or not (wordPlace[w] or wordRole[w] or goods) then
                placed, town = false, nil
                wipe(N.mapSet)
                for v = 1, #words do wordPlace[v] = nil end
                goods = MatchGoods()
                break
            end
        end
    end
    local placeKey
    if placed then
        local list = N.placeWords
        for p = #list, 1, -1 do list[p] = nil end
        for w = 1, #words do
            if wordPlace[w] then list[#list + 1] = words[w] end
        end
        placeKey = tconcat(list, " ")
    end
    N.placeKey = placeKey

    local askKey
    if goods then
        local list = N.askWords
        for p = #list, 1, -1 do list[p] = nil end
        for w = 1, #words do
            if band(wordBits[w], VENDOR) ~= 0 then list[#list + 1] = words[w] end
        end
        if #list > 0 then askKey = tconcat(list, " ") end
    end
    N.askKey = askKey
    local f = EasyFind.db and EasyFind.db.npcFilters
    local horde = UnitFactionGroup and UnitFactionGroup("player") == "Horde"



    N.gen = N.gen + 1
    local cand = N.cand
    for c = #cand, 1, -1 do cand[c] = nil end
    local lw
    for w = 1, #words do
        if not wordPlace[w] and (not lw or #words[w] > #words[lw]) then lw = w end
    end
    local longest = words[lw]
    if not sellers then
        MarkLines(N.low, N.at, N.n, longest, Mark)
        if N.enLow then MarkLines(N.enLow, N.enAt, N.n, longest, Mark) end

        if #cand == 0 then
            local sqLow, sqAt, sqEnLow, sqEnAt = Joined()
            MarkLines(sqLow, sqAt, N.n, longest, Mark)
            if sqEnLow then MarkLines(sqEnLow, sqEnAt, N.n, longest, Mark) end
        end
        local titleHit, anyTitle, craft = N.titleHit, false, N.wordCraft[lw]
        for t = 1, #N.titleLow do
            local hit = sfind(N.titleLow[t], longest, 1, true)
                or (N.titleLowEnglish[t] and sfind(N.titleLowEnglish[t], longest, 1, true))
                or (craft and (sfind(N.titleLow[t], craft, 1, true)
                    or (N.titleLowEnglish[t] and sfind(N.titleLowEnglish[t], craft, 1, true))))
            titleHit[t] = hit and true or nil
            if hit then anyTitle = true end
        end
        local bits = wordBits[lw]
        if anyTitle or bits ~= 0 then MarkTitlesAndRoles(titleHit, bits) end
        local worded = WordedIDs(longest)
        if worded then
            for npcID in pairs(worded) do
                local i = IndexOfID(npcID)
                if i then Mark(i) end
            end
        end
    end
    if goods then
        local vendors = N.vendors
        for o = 1, #vendors / 3 do Mark(At(vendors, o)) end
    end



    local set, r2, nearOnly
    local pci, px, py
    local mapSet = N.mapSet
    if town then
        pci, px, py, r2 = town.ci, town.wx, town.wy, TOWN_RADIUS2
    else
        pci, px, py = PlayerWorld()
        if next(mapSet) then
            set = mapSet
        elseif onlyMap then
            mapSet[onlyMap] = true
            set = mapSet
        elseif allService and nearMap then
            AddMaps(mapSet, nearMap)
            set, nearOnly = mapSet, true
        end
    end
    MarkWordHits()
    local n = Keep(set, pci, px, py, r2, goods, f, horde, service)
    if n == 0 and nearOnly then
        wipe(mapSet)
        set = nil
        n = Keep(nil, pci, px, py, nil, goods, f, horde, service)
    end
    if n == 0 then return false end
    local hits, spot, near = N.hits, N.spot, N.near
    if along then
        local kept = 0
        for j = 1, n do
            local i = hits[j]
            local k, sec = AlongSpot(i, set, along)
            if k then
                kept = kept + 1
                hits[kept], spot[i], near[i] = i, k, sec
            end
        end
        for j = n, kept + 1, -1 do hits[j] = nil end
        n = kept
        if n == 0 then return false end
    else


        for j = 1, n do
            if j % 256 == 0 then SliceCheckpoint() end
            local i = hits[j]
            local k = BestSpot(i, set, pci, px, py, r2)
            spot[i], near[i] = k, FAR
            if k and pci then
                local ci, wx, wy = SpotWorld(k)
                if ci == pci then near[i] = (wx - px) ^ 2 + (wy - py) ^ 2 end
            end
        end
    end
    TopRows(hits, n)
    for j = 1, mmin(n, MAX_ROWS) do
        if j % 16 == 0 then SliceCheckpoint() end
        local i = hits[j]
        local k = spot[i] or BestSpot(i, set, pci, px, py, r2)
        local poi = k and Row(i, k)
        if poi and not (nameSet and nameSet[poi.nameLower]) then out[#out + 1] = poi end
    end
    return n > MAX_ROWS
end



function N.Sellers(out, name)
    N.sellersOnly = slower(name)
    local ok, err = pcall(N.Append, out, nil, name)
    N.sellersOnly = nil
    if not ok then error(err, 0) end
    return out
end




local wareList, wareAt, wareText

local function Varint(s, p)
    local v, mul = 0, 1
    while true do
        local b = sbyte(s, p)
        p = p + 1
        if b < 128 then return v + b * mul, p end
        v, mul = v + (b - 128) * mul, mul * 128
    end
end

local function LoadWares()
    if wareList ~= nil then return wareList ~= false end
    local s = N.data and N.data.wares
    if not s then
        wareList = false
        return false
    end
    wareList, wareAt, wareText = {}, {}, s
    local count, p = Varint(s, 1)
    local id = 0
    for _ = 1, count do
        local d, list
        d, p = Varint(s, p)
        list, p = Varint(s, p)
        id = id + d
        wareList[id] = list + 1
    end
    count, p = Varint(s, p)
    for k = 1, count do
        wareAt[k] = p
        local items
        items, p = Varint(s, p)
        for _ = 1, items do p = select(2, Varint(s, p)) end
    end
    return true
end


function N.WareCount(npcID)
    if not (npcID and LoadWares()) then return nil end
    local list = wareList[npcID]
    return list and (Varint(wareText, wareAt[list])) or nil
end



function N.Wares(npcID)
    if not (npcID and LoadWares()) then return nil end
    local list = wareList[npcID]
    if not list then return nil end
    local items, p = Varint(wareText, wareAt[list])
    local out, id = {}, 0
    for k = 1, items do
        local d
        d, p = Varint(wareText, p)
        id = id + d
        out[k] = id
    end
    return out
end



function N.FilterChoices()
    if not Load() then return nil end
    local data, types = N.data, {}
    local names = data.types or {}
    for _, id in ipairs(data.kindTypes or {}) do
        if names[id] then types[#types + 1] = { id = id, name = names[id] } end
    end
    tsort(types, function(a, b) return a.name < b.name end)
    local list = {}
    for _, e in ipairs(data.kindExpansions or {}) do list[#list + 1] = e end
    tsort(list, function(a, b) return (a < 0 and 99 or a) < (b < 0 and 99 or b) end)
    return { types = types, expansions = list }
end


local function CellOf(x, y)
    return mfloor((ORIGIN - y) / CELL) * 256 + mfloor((ORIGIN - x) / CELL)
end
N.CellOf = CellOf

local function Reader(s)
    local pos = 1
    return function()
        local v, mul = 0, 1
        while true do
            local b = sbyte(s, pos)
            pos = pos + 1
            if b < 128 then return v + b * mul end
            v = v + (b - 128) * mul
            mul = mul * 128
        end
    end
end




function N.Threats(faction)
    local data = N.data
    if not (data and data.danger) then return nil end
    local horde = faction == "Horde"
    if N.threats and N.threatsHorde == horde then return N.threats end
    local set = {}
    for ci, blob in pairs(data.danger) do
        local ok, raw = pcall(Unpack, blob)
        if ok and raw then
            local u = Reader(raw)
            local cells, last = {}, 0
            for _ = 1, u() do
                last = last + u()
                local alliance, hordeLevel = u(), u()
                local level = horde and hordeLevel or alliance
                if level > 0 then cells[last] = level end
            end
            set[ci] = cells
        end
    end
    N.threats, N.threatsHorde = set, horde
    return set
end





function N.Guards(faction)
    local data = N.data
    if not (data and data.guards) then return nil end
    local bit = faction == "Horde" and 2 or 1
    if N.guardCells and N.guardBit == bit then return N.guardCells end
    local set = {}
    for ci, blob in pairs(data.guards) do
        local ok, raw = pcall(Unpack, blob)
        if ok and raw then
            local u = Reader(raw)
            local cells, last = {}, 0
            for _ = 1, u() do
                last = last + u()
                if mfloor(u() / bit) % 2 == 1 then cells[last] = true end
            end
            set[ci] = cells
        end
    end
    N.guardCells, N.guardBit = set, bit
    return set
end




function N.DangerTiles(level, faction)
    local threats = level and N.Threats(faction)
    if not threats then return nil end
    local key = level .. (faction or "")
    if N.dangerKey == key then return N.dangerSet end
    local set = {}
    for ci, cells in pairs(threats) do
        local out = {}
        for cell, at in pairs(cells) do
            if at >= level + DANGER_LEVELS then out[mfloor(cell / 1024) * 64 + mfloor(cell % 256 / 4)] = true end
        end
        set[ci] = out
    end
    N.dangerKey, N.dangerSet = key, set
    return set
end










local function ZoneLevelCap(ci, wx, wy)
    if not (C_Map and C_Map.GetMapPosFromWorldPos and C_Map.GetMapLevels and CreateVector2D) then return nil end
    local ok, m = pcall(C_Map.GetMapPosFromWorldPos, ci, CreateVector2D(wx, wy))
    if not (ok and m) then return nil end
    local lok, _, maxLevel = pcall(C_Map.GetMapLevels, m)
    if lok and type(maxLevel) == "number" and maxLevel > 0 then return maxLevel + ZONE_LEVELS end
    return nil
end

function N.DeadlyAlong(path, ci, level, faction)
    local threats = level and N.Threats(faction)
    local cells = threats and threats[ci]
    if not (cells and path and path.pts) then return nil end
    local guarded = N.Guards(faction)
    guarded = guarded and guarded[ci]
    local d = path.deadly
    if d and d.level == level and d.ci == ci and d.faction == faction then return d end
    d = { level = level, ci = ci, faction = faction, n = 0 }
    local red, skull = level + RED_LEVELS, level + SKULL_LEVELS
    local pts, cum = path.pts, path.cum
    local cap = ZoneLevelCap(ci, pts[#pts - 1], pts[#pts])
    local inside = false
    for v = 1, #pts / 2 - 1 do
        local ax, ay = pts[2 * v - 1], pts[2 * v]
        local dx, dy = pts[2 * v + 1] - ax, pts[2 * v + 2] - ay
        local len = cum[v + 1] - cum[v]
        local k = mmax(1, mceil(len / DEADLY_STEP))
        for j = 0, k - 1 do
            local t = (j + 0.5) / k
            local cell = CellOf(ax + dx * t, ay + dy * t)
            local at = cells[cell] or 0
            if cap and at > cap then at = 0 end
            local guard = guarded and guarded[cell]
            if guard and not d.guard then
                d.guard, d.gx, d.gy = cum[v] + len * j / k, ax + dx * j / k, ay + dy * j / k
            end
            if (at >= red or guard == true) ~= inside then
                inside = not inside
                d.n = d.n + 1
                d[d.n] = cum[v] + len * j / k
            end
            if at >= skull and not d.skull then
                d.skull, d.sx, d.sy = cum[v] + len * j / k, ax + dx * j / k, ay + dy * j / k
            end
        end
    end
    if inside then
        d.n = d.n + 1
        d[d.n] = path.len
    end
    path.deadly = d
    return d
end

MapSearch.AppendNpcRows = N.Append
MapSearch.NpcKindQuery = N.KindQuery
