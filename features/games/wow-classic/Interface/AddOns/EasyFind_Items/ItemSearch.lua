

local EasyFind = EasyFind
local ns = EasyFind and EasyFind._ns
if not ns or select(2, ...).stale then return end






local ItemSearch = {}
ns.ItemSearch = ItemSearch

local Utils = ns.Utils
local sfind, ssub = Utils.sfind, Utils.ssub
local sbyte, sgmatch = string.byte, string.gmatch
local slower = Utils.slower or string.lower
local pairs = Utils.pairs or pairs
local tonumber = tonumber
local CreateFrame = CreateFrame
local C_Item = C_Item
local strtrim = strtrim

local wipe = wipe
local SliceCheckpoint = Utils.SliceCheckpoint

local MIN_QUERY = 3
local SCAN_CAP = 250
local KEEP = 32
local REMEMBER = 2048


local NOT_PREFIX_MAX = 135



local WORD_BYTE = { [39] = true }
for b = 48, 57 do WORD_BYTE[b] = true end
for b = 65, 90 do WORD_BYTE[b] = true end
for b = 97, 122 do WORD_BYTE[b] = true end

local blob, blobLen


local leads



local BUCKETS = {
    armor      = { 4 },
    weapon     = { 2 },
    consumable = { 0 },
    tradegoods = { 7, 5 },
    recipe     = { 9 },
    gem        = { 3 },
    quest      = { 12 },
    housing    = { 20 },
    glyph      = { 16 },
    container  = { 1 },
    misc       = { 15, 8, 13, 6, 10, 17, 18, 19 },
}
ns.CATALOG_TYPE_BUCKETS = BUCKETS





local classDisabled, qualityTier, filtersActive, filtersReady

function ItemSearch:RefreshFilters()
    local db = EasyFind and EasyFind.db
    local typeFilters = db and db.catalogTypeFilters
    classDisabled = {}
    local anyDisabled = false
    for key, classes in pairs(BUCKETS) do
        if typeFilters and typeFilters[key] == false then
            anyDisabled = true
            for i = 1, #classes do classDisabled[classes[i]] = true end
        end
    end
    qualityTier = (db and db.catalogQualityTier) or 0
    filtersActive = anyDisabled or qualityTier > 0
    filtersReady = true
end



local pendingLoads, attemptedLoads, loadListener, refreshTimer
local pendingCount = 0

local function ScheduleCatalogRefresh()
    if refreshTimer then return end
    refreshTimer = true
    Utils.SafeAfter(0.15, function()
        refreshTimer = nil




        if ns.Results and ns.Results.IsResultsScrollBusy
           and ns.Results:IsResultsScrollBusy() then
            ScheduleCatalogRefresh()
            return
        end
        local Search = ns.Search
        local sf = Search and Search.GetSearchFrame and Search:GetSearchFrame()
        local eb = sf and sf.editBox
        if not eb then return end
        local full = eb:GetText() or ""
        local cursor = eb:GetCursorPosition() or #full
        local typed = strtrim(ssub(full, 1, cursor))
        if typed ~= "" then Search:OnSearchTextChanged(typed, true) end
    end)
end


function ItemSearch:IsResolvable(itemID)
    if not itemID then return false end
    if not (C_Item and C_Item.GetItemInfoInstant) then return true end
    return C_Item.GetItemInfoInstant(itemID) ~= nil
end

function ItemSearch:NoteUncachedItem(itemID)
    if not itemID then return end


    attemptedLoads = attemptedLoads or {}
    if attemptedLoads[itemID] then return end
    attemptedLoads[itemID] = true
    pendingLoads = pendingLoads or {}
    pendingLoads[itemID] = true


    pendingCount = pendingCount + 1
    if not loadListener then
        loadListener = CreateFrame("Frame")
        loadListener:SetScript("OnEvent", function(_, _, loadedID, success)
            if pendingLoads and pendingLoads[loadedID] then
                pendingLoads[loadedID] = nil
                pendingCount = pendingCount - 1
                if pendingCount <= 0 then
                    pendingCount = 0
                    loadListener:UnregisterEvent("ITEM_DATA_LOAD_RESULT")
                end

                if success ~= false then ScheduleCatalogRefresh() end
            end
        end)
    end
    if pendingCount == 1 then
        loadListener:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    end
    if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
end

local function EnsureBlob()
    if blob then return blob end
    blob = ns.ITEM_SEARCH_BLOB
    if type(blob) ~= "string" then blob = nil; return nil end
    blobLen = #blob
    return blob
end


local function RecordAt(s)
    local e = sfind(blob, "\n", s, true) or (blobLen + 1)
    local from = s - 100
    if from < 1 then from = 1 end
    local lastNL, p = nil, from
    while true do
        local nl = sfind(blob, "\n", p, true)
        if not nl or nl >= s then break end
        lastNL, p = nl, nl + 1
    end
    local start = lastNL and (lastNL + 1) or (from == 1 and 1 or from)
    return start, e - 1
end



local keep, kept = {}, 0
local out = {}
local dataByID = setmetatable({}, { __mode = "v" })
local seenIDs = {}


local lastQl, lastComplete = nil, false
local prevRecs, curRecs = { s = {}, n = 0 }, { s = {}, n = 0 }

local function Beats(score, nameLower, e)
    if score ~= e.score then return score > e.score end
    local other = e.data.name
    if #nameLower ~= #other then return #nameLower < #other end
    return nameLower < other
end



local function Record(rStart, rEnd, ql, qLen, scoreName)
    local t1 = sfind(blob, "\t", rStart, true)
    if not (t1 and t1 <= rEnd) then return end
    local nameLower = ssub(blob, rStart, t1 - 1)
    local t2 = sfind(blob, "\t", t1 + 1, true)
    local t3 = t2 and sfind(blob, "\t", t2 + 1, true)
    local itemID = tonumber(ssub(blob, t1 + 1, (t2 or (rEnd + 1)) - 1))
    local quality = t2 and tonumber(ssub(blob, t2 + 1, (t3 or (rEnd + 1)) - 1))


    if filtersActive and t3 then
        local t4 = sfind(blob, "\t", t3 + 1, true)
        local t5 = t4 and sfind(blob, "\t", t4 + 1, true)
        if t5 then
            local t6 = sfind(blob, "\t", t5 + 1, true)
            local class = tonumber(ssub(blob, t5 + 1, (t6 or (rEnd + 1)) - 1))
            if class and classDisabled[class] then
                return
            elseif qualityTier > 0 and t6 then
                local qt = tonumber(ssub(blob, t6 + 1, rEnd))
                if qt and qt > 0 and qt ~= qualityTier then return end
            end
        end
    end
    if not itemID or seenIDs[itemID] then return end
    local score = scoreName and scoreName(nameLower, ql, qLen)
    if not (score and score > 0) then return end
    seenIDs[itemID] = true
    local e
    if kept < KEEP then
        kept = kept + 1
        e = keep[kept]
        if not e then
            e = {}
            keep[kept] = e
        end
    else
        e = keep[KEEP]
        if not Beats(score, nameLower, e) then return end
    end
    local at = kept
    while at > 1 and Beats(score, nameLower, keep[at - 1]) do
        keep[at] = keep[at - 1]
        at = at - 1
    end
    keep[at] = e
    e.score = score
    local d = dataByID[itemID]
    if not d then
        d = { itemID = itemID, catalogItem = true, lookupRow = true, category = "Item",
              name = nameLower,
              nameLower = nameLower, quality = quality }
        dataByID[itemID] = d
    end
    e.data = d
end


local function LineEnd(s)
    local e = sfind(blob, "\n", s, true)
    return e and e - 1 or blobLen
end


local function LineStartAt(p)
    if p <= 1 then return 1 end
    local e = sfind(blob, "\n", p - 1, true)
    return e and e < blobLen and e + 1 or nil
end


local function BeforeQuery(p, q, qLen)
    for i = 1, qLen do
        local a, b = sbyte(blob, p + i - 1), sbyte(q, i)
        if not a then return true end
        if a ~= b then return a < b end
    end
    return false
end



local function FirstLineFrom(q, qLen)
    local lo, hi = 1, blobLen + 1
    while lo < hi do
        local mid = lo + (hi - lo - (hi - lo) % 2) / 2
        local L = LineStartAt(mid)
        if L and BeforeQuery(L, q, qLen) then lo = mid + 1 else hi = mid end
    end
    return LineStartAt(lo)
end


local function RecordRun(L, q, qLen, ql, scoreName, n)
    local qlLen = #ql
    while L and ssub(blob, L, L + qLen - 1) == q do
        local e = LineEnd(L)
        Record(L, e, ql, qlLen, scoreName)
        L = e + 2 <= blobLen and e + 2 or nil
        n = n + 1
        if n % 64 == 0 then SliceCheckpoint() end
    end
    return n
end



local function Leads()
    if leads then return leads end
    leads = {}
    local seen = {}
    local headEnd = FirstLineFrom("a", 1) or (blobLen + 1)
    local L = 1
    while L and L < headEnd do
        local p = L
        local b = sbyte(blob, p)
        while p < headEnd and b ~= 9 and not WORD_BYTE[b] do
            p = p + 1
            b = sbyte(blob, p)
        end
        if p > L then
            local run = ssub(blob, L, p - 1)
            if not seen[run] then
                seen[run] = true
                leads[#leads + 1] = run
            end
        end
        local e = LineEnd(L)
        L = e + 2 <= blobLen and e + 2 or nil
    end
    return leads
end


local midBuf = {}
local scanQl, scanLen, scanScore, prefixDone
local hits, hn, mn, complete
local function KeepBestOut()
    for k = 1, kept do out[k] = keep[k] end
    for k = #out, kept + 1, -1 do out[k] = nil end
end



local function Visit(s)
    if hn < REMEMBER then
        hn = hn + 1
        hits[hn] = s
    else
        complete = false
    end
    local prev = s > 1 and sbyte(blob, s - 1) or 10
    if prev == 10 then
        if not prefixDone then Record(s, LineEnd(s), scanQl, scanLen, scanScore) end
    elseif not WORD_BYTE[prev] then
        local rStart, rEnd = RecordAt(s)
        Record(rStart, rEnd, scanQl, scanLen, scanScore)
    elseif mn < SCAN_CAP then
        mn = mn + 1
        midBuf[mn] = s
    end
end

local function Placed()
    return kept >= KEEP and keep[KEEP].score > NOT_PREFIX_MAX
end





local WORD_HITS, WORD_SCORED = 4000, 256
local wordBuf = {}



local function StartsWordOf(name, w)
    local p = 1
    while true do
        local s = sfind(name, w, p, true)
        if not s then return false end
        if s == 1 or not WORD_BYTE[sbyte(name, s - 1)] then return true end
        p = s + 1
    end
end

local function WordsScore(nameLower, q, qLen)
    return ns.Database:ScoreName(nameLower, q, qLen, wordBuf)
end

local function WordPass(ql, qLen)
    local n, longest = 0, 1
    for w in sgmatch(ql, "%S+") do
        n = n + 1
        wordBuf[n] = w
        if #w > #wordBuf[longest] then longest = n end
    end
    for k = #wordBuf, n + 1, -1 do wordBuf[k] = nil end
    if n < 2 or #wordBuf[longest] < MIN_QUERY then return end
    local w = wordBuf[longest]
    local pos, visited, scored = 1, 0, 0
    while visited < WORD_HITS and scored < WORD_SCORED do
        local s = sfind(blob, w, pos, true)
        if not s then break end
        visited = visited + 1
        local prev = s > 1 and sbyte(blob, s - 1) or 10
        if prev == 10 or not WORD_BYTE[prev] then
            local rStart, rEnd
            if prev == 10 then rStart, rEnd = s, LineEnd(s) else rStart, rEnd = RecordAt(s) end
            local t1 = sfind(blob, "\t", rStart, true)
            local name = ssub(blob, rStart, t1 and t1 - 1 or rEnd)
            local all = true
            for i = 1, n do
                if i ~= longest and not StartsWordOf(name, wordBuf[i]) then
                    all = false
                    break
                end
            end
            if all then
                scored = scored + 1
                Record(rStart, rEnd, ql, qLen, WordsScore)
            end

            pos = rEnd + 2
        else
            pos = s + 1
        end
        if visited % 64 == 0 then SliceCheckpoint() end
    end
end







local TYPO_MIN, TYPO_RUN = 5, 200
local typoBuf = {}

local function TypoScore(nameLower, q, qLen)
    return ns.Database:ScoreName(nameLower, q, qLen, wordBuf)
end

local function TypoPass(ql, qLen)
    local n = 0
    for w in sgmatch(ql, "%S+") do
        n = n + 1
        wordBuf[n] = w
    end
    for k = #wordBuf, n + 1, -1 do wordBuf[k] = nil end
    local first = wordBuf[1]
    if not first or #first < TYPO_MIN then return end
    local P = #first >= 7 and 5 or 4
    typoBuf[1] = ssub(first, 1, P)
    for i = 1, P do

        local swapped = ssub(first, 1, i - 1) .. ssub(first, i + 1, i + 1) .. ssub(first, i, i) .. ssub(first, i + 2, P)
        typoBuf[i + 1] = ssub(swapped, 1, P)
    end
    local runs = P + 1
    if not sfind(first, "'", 1, true) then
        for i = 1, P - 1 do
            runs = runs + 1
            typoBuf[runs] = ssub(first, 1, i) .. "'" .. ssub(first, i + 1, P)
        end
    end
    for k = #typoBuf, runs + 1, -1 do typoBuf[k] = nil end
    for i = 1, runs do
        local p = typoBuf[i]
        local pLen = #p
        local fresh = true
        for j = 1, i - 1 do
            if typoBuf[j] == p then fresh = false end
        end
        if fresh then
            local L, m = FirstLineFrom(p, pLen), 0
            while L and ssub(blob, L, L + pLen - 1) == p and m < TYPO_RUN do
                local e = LineEnd(L)
                Record(L, e, ql, qLen, TypoScore)
                L = e + 2 <= blobLen and e + 2 or nil
                m = m + 1
                if m % 64 == 0 then SliceCheckpoint() end
            end
        end
    end
end

function ItemSearch:Search(query, scoreName)
    if not query or #query < MIN_QUERY then return nil end
    if not EnsureBlob() then return nil end
    if not filtersReady then self:RefreshFilters() end
    local ql = slower(query)
    local qLen = #ql
    wipe(seenIDs)
    kept = 0
    scanQl, scanLen, scanScore, prefixDone = ql, qLen, scoreName, false
    local narrow = lastComplete and lastQl and qLen > #lastQl and ssub(ql, 1, #lastQl) == lastQl


    if not narrow then
        prefixDone = true
        local n = RecordRun(FirstLineFrom(ql, qLen), ql, qLen, ql, scoreName, 0)
        local runs = Leads()
        for k = 1, #runs do
            local q = runs[k] .. ql
            n = RecordRun(FirstLineFrom(q, #q), q, #q, ql, scoreName, n)
        end
        if Placed() then
            lastQl, lastComplete = ql, false
            scanScore = nil
            KeepBestOut()
            return out
        end
    end


    hits, hn, mn, complete = curRecs.s, 0, 0, true
    if narrow then

        local ps, base = prevRecs.s, #lastQl
        for k = 1, prevRecs.n do
            local s = ps[k]
            local i = base + 1
            while i <= qLen and sbyte(blob, s + i - 1) == sbyte(ql, i) do i = i + 1 end
            if i > qLen then Visit(s) end
            if k % 128 == 0 then SliceCheckpoint() end
        end
    else

        local h, mb, wb = hits, midBuf, WORD_BYTE
        local pos, n, hc, mc = 1, 0, 0, 0
        while true do
            local s = sfind(blob, ql, pos, true)
            if not s then break end
            if hc < REMEMBER then
                hc = hc + 1
                h[hc] = s
            end
            local prev = s > 1 and sbyte(blob, s - 1) or 10
            if prev ~= 10 then
                if not wb[prev] then
                    local rStart, rEnd = RecordAt(s)
                    Record(rStart, rEnd, ql, qLen, scoreName)
                elseif mc < SCAN_CAP then
                    mc = mc + 1
                    mb[mc] = s
                end
            elseif not prefixDone then
                Record(s, LineEnd(s), ql, qLen, scoreName)
            end
            pos = s + 1
            n = n + 1
            if n % 64 == 0 then SliceCheckpoint() end
        end
        hn, mn = hc, mc
        if n > REMEMBER then complete = false end
    end

    if not Placed() then
        for k = 1, mn do
            local rStart, rEnd = RecordAt(midBuf[k])
            Record(rStart, rEnd, ql, qLen, scoreName)
            if k % 64 == 0 then SliceCheckpoint() end
        end
    end

    if not Placed() and sfind(ql, " ", 1, true) then WordPass(ql, qLen) end

    if kept == 0 and qLen >= TYPO_MIN then TypoPass(ql, qLen) end
    for k = #midBuf, mn + 1, -1 do midBuf[k] = nil end
    for k = #hits, hn + 1, -1 do hits[k] = nil end
    curRecs.n = hn
    lastQl, lastComplete = ql, complete
    prevRecs, curRecs = curRecs, prevRecs
    scanScore = nil
    KeepBestOut()
    return kept > 0 and out or nil
end



function ItemSearch:_DebugPeek()
    return { blob = blob, attemptedLoads = attemptedLoads, pendingLoads = pendingLoads }
end

return ItemSearch
